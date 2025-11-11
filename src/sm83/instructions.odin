#+private
#+feature dynamic-literals
package sm83

import "core:mem"
import "core:fmt"
import "core:strconv"
import "core:strings"
import "../mmu"

/*
    NOTICE:
        For many instructions, I could have implemented a more "generalized" approach, where r8 = 6 -> remaps to [hl],
        via a target-pointer...

        Alas, I did NOT do this, and instead I have a bunch of specific implementations....

    OPCODE SYNTAX:
    1st Byte -> Opcode

    ABREVIATIONS:
    r8      -> Any 8 Bit register                   (indexed in order) 0=b, 1=c, 2=d, 3=e, 4=h, 5=l, 6=[hl], 7=a
    r16     -> Any 16 Bit register                  (indexed in order) 0=bc, 1=de, 2=hl, 3=sp
    r16stk  -> Any 16 Bit register                  (indexed in order) 0=bc, 1=de, 2-hl, 3=af
    r16mem  -> Any 16 Bit register as memory addr   (indexed in order) 0=bc, 1=de, 2=hl+, 3=hl-
    cond    -> A condition                          (indexed in order) 0=nz, 1=z, 2=nc, 3=c
    b3      -> A 3-Bit bit index
    tgt3    -> rst's target address, divided by 8
    imm8    -> following byte
    imm16   -> following 2 bytes

    REGISTERING HANDLERS:
    constant opcodes -> direct_register(code, instruction)
    variable opcodes -> indirect_register(code, )
*/
// The index table for r8 - !!!! F is used as a standin for [hl]... remember
R8_IDX : []REG8 = { .B, .C, .D, .E, .H, .L, .NONE, .A }
// The index table for r16
R16_IDX : []REG16 = { .BC, .DE, .HL, .SP }
// The index table for r16stk
R16_IDX_S : []REG16 = { .BC, .DE, .HL, .AF }
// The index table for r16mem
R16_IDX_M : []REG16 = { .BC, .DE, .HL, .HL }

eval_condition :: proc(
    ctx: ^CPU,
    cond: u8
) -> bool {
    switch cond {
        case 0: return get_flag(ctx, FLAGS.ZERO) == 0x00
        case 1: return get_flag(ctx, FLAGS.ZERO) != 0x00
        case 2: return get_flag(ctx, FLAGS.CARRY) == 0x00
        case 3: return get_flag(ctx, FLAGS.CARRY) != 0x01
    }
    return false
}

r16m_do_hl_increment_if_needed :: proc(
    ctx: ^CPU,
    idx: u8,
) {
    if idx < 2 do return 
    if idx == 2 do add_register(ctx, REG16.HL, 1)
    else do add_register(ctx, REG16.HL, -1)
}

bu16 :: proc(
    bytes: []u8
) -> u16 {
    if len(bytes) < 2 do return 0x00
    total : u16 = (u16(bytes[len(bytes) - 1]) << 8) | u16(bytes[len(bytes) - 2])
    return total
}

OPCODE_HANDLERS: [256]Instruction
PREFIXED_OPCODES: [256]Instruction

InstructionHandler :: proc(^CPU, ^mmu.MMU, InsData) -> u32

/*
    Only used for registering Instructions at startup
*/
VarInstruction :: struct {
    pattern: string,
    ins: Instruction
}

Instruction :: struct {
    handler: InstructionHandler,
    length: u8,
    name: string
}

InsData :: struct {
    opbytes: []u8,
    x, y, z, a, b: u8
}

init_instructions :: proc() {
    register_load_instructions()
    register_arith8_instructions()
    register_arith16_instructions()
    register_control_instructions()
    register_bitwise_instructions()
    register_shifts_instructions()
    register_misc_instructions()
}

/*
    Parses the given byte, into an instruction and it's accompaniying parameters
*/
decode_instruction :: proc(
    addr: u16,
    ctx_mem: ^mmu.MMU
) -> (ins: Instruction, dat: InsData) {
    dataByte := mmu.get(ctx_mem, u8, addr)
    ins = OPCODE_HANDLERS[dataByte]
    if dataByte == 0xCB {
        dataByte = mmu.get(ctx_mem, u8, addr + 1)
        ins = PREFIXED_OPCODES[dataByte]
    } 
    if ins.length == 0 { when ODIN_DEBUG do fmt.eprintfln("[INSTRUCTION-PARSER] Instruction byte %#02X could not be mapped correctly", dataByte) }

    dat.x = ((dataByte & 0b00110000) >> 4) & 0xFF
    dat.y = ((dataByte & 0b00001100) >> 2) & 0xFF
    dat.z = (dataByte & 0b00000011) & 0xFF

    dat.a = ((dataByte & 0b00111000) >> 3) & 0xFF
    dat.b = (dataByte & 0b00000111) & 0xFF

    dat.opbytes = make([]u8, ins.length)
    for i in 0..<ins.length do dat.opbytes[i] = mmu.get(ctx_mem, u8, addr + u16(i))
    return
}

/*
    Will register the given Instruction with either:
    - A constant opcode-vale (u8)
    - A opcode-range with a pattern (string, example: "01xxxxxx")
*/
register_instruction :: proc {
    register_const_instruction,
    register_var_instruction
}

@(private="file")
register_const_instruction :: proc(
    opcode: u8,
    ins: Instruction,
    prefixed: bool = false
) {
    if prefixed { 
        if PREFIXED_OPCODES[opcode].length != 0 {
            //fmt.eprintfln("[INSTRUCTION_REGISTER] Error: Instruction %s - %#02X is trying to override %s - %#02X", ins.name, opcode, OPCODE_HANDLERS[opcode].name, opcode)
            //panic("[ABORT]")
        }
        PREFIXED_OPCODES[opcode] = ins
    }
    else {
        if OPCODE_HANDLERS[opcode].length != 0 {
            //fmt.eprintfln("[INSTRUCTION_REGISTER] Error: Instruction %s - %#02X is trying to override %s - %#02X", ins.name, opcode, OPCODE_HANDLERS[opcode].name, opcode)
            //panic("[ABORT]")
        }
        OPCODE_HANDLERS[opcode] = ins
    }

    when ODIN_DEBUG do fmt.printfln("[INSTRUCTION_REGISTER] Instruction: %s\nRegistered for opcode %#02X\n", ins.name, opcode)
}

@(private="file")
register_var_instruction :: proc(
    pattern: string,
    ins: Instruction,
    prefixed: bool = false
) {
    if !strings.contains_rune(pattern, 'x') {
        when ODIN_DEBUG do fmt.printfln("[INSTRUCTION_REGISTER] WARNING: Could not find any X in provided pattern: %s for instruction %s\nRedirecting to fixed instruction...",pattern, ins.name)
        code, conv_ok := strconv.parse_uint(pattern, 2)
        if !conv_ok {
            when ODIN_DEBUG do fmt.eprintfln("[INSTRUCTION_REGISTER] Instruction:%s\nCould not convert pattern: %s into binary number", ins.name, pattern)
            return
        }
        opcode : u8 = u8(code & 0xFF)
        register_const_instruction(opcode, ins, prefixed)
        return 
    }
    if len(pattern) != 8 {
        when ODIN_DEBUG do fmt.eprintfln("[INSTRUCTION_REGISTER] Instruction: %s\nBad pattern: %s does not fit 8-bit number", ins.name, pattern)
        return
    }

    x_count : uint = uint(strings.count(pattern, "x"))
    x_off : uint = len(pattern) - uint(strings.last_index(pattern, "x")) - 1

    conv_str, alloc := strings.replace_all(pattern, "x", "0")
    defer { if alloc do delete(conv_str) }

    code_orig, conv_ok := strconv.parse_uint(conv_str, 2)
    if !conv_ok {
        when ODIN_DEBUG do fmt.eprintfln("[INSTRUCTION_REGISTER] Instruction: %s\nCould not convert pattern: %s into binary number", ins.name, conv_str)
        return
    }

    max : u8 = (1 << x_count) & 0xFF
    for i in 0..<max {
        insert_num := (i << x_off) & 0xFF
        opcode := u8(code_orig& 0xFF) | insert_num
        register_const_instruction(opcode, ins, prefixed)
    }

    when ODIN_DEBUG do fmt.printfln("[INSTRUCTION_REGISTER] Instruction: %s\nRegistered pattern %s\n", ins.name, pattern)
}

bool_to_u8 :: proc(
    b: bool
) -> u8 {
    return b ? 0x01 : 0x00
}

// ---------- ADD (u8/u16/i8) ----------
add_nums_flags :: proc(numA: $T, numB: T) -> (value: T, z, hc, c: u8) {
    when T == u8 {
        sum   := u16(numA) + u16(numB);
        value  = T(sum & 0xFF);
        c   = bool_to_u8(sum > 0xFF);
        hc  = bool_to_u8(((numA & 0x0F) + (numB & 0x0F)) > 0x0F);
        z   = bool_to_u8(value == 0);
    }

    when T == u16 {
        sum   := u32(numA) + u32(numB);
        value  = T(sum & 0xFFFF);
        c   = bool_to_u8(sum > 0xFFFF);
        hc  = bool_to_u8(((numA & 0x0FFF) + (numB & 0x0FFF)) > 0x0FFF);
        z   = bool_to_u8(value == 0);
    }

    return;
}

// ---------- SUB (u8/u16/i8): A - B ----------
sub_nums_flags :: proc(numA: $T, numB: T) -> (value: T, c, hc, z: u8) {
    when T == u8 {
        diff  := i16(u16(numA)) - i16(u16(numB));
        value  = T(u8(diff & 0xFF));
        c   = bool_to_u8(numA < numB);                       // borrow
        hc  = bool_to_u8((numA & 0x0F) < (numB & 0x0F));     // half-borrow
        z   = bool_to_u8(value == 0);
    }

    when T == u16 {
        diff  := i32(u32(numA)) - i32(u32(numB));
        value  = T(u16(diff & 0xFFFF));
        c   = bool_to_u8(numA < numB);                       // borrow from bit 16
        hc  = bool_to_u8((numA & 0x0FFF) < (numB & 0x0FFF)); // half-borrow from bit 12
        z   = bool_to_u8(value == 0);
    }

    return;
}