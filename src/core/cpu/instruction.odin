#+private
package cpu

import "core:fmt"
import "core:log"
import "base:runtime"

op_8 :: enum(u8) { b, c, d, e, h, l, mem, a }
op_16 :: enum(u8) { bc, de, hl, sp }
op_16_stk :: enum(u8) { bc, de, hl, af }
op_16_mem :: enum(u8) { bc, de, hlp, hlm }
op_cond :: enum(u8) { nz, z, nc, c }

/*
    b3 -> 3 bit bit index
    tgt3 -> rst target address divided by 8
    imm8 / n -> Immidiate 8 bit
    imm16 / m -> Immediate 16 bit
*/

@(private="file")
InstructionTable: [256]Instruction

@(private="file")
PrefixedTable: [256]Instruction

InstructionHandler :: proc(
    cpu: ^CPU,
    opcode: u8
) -> u8

Instruction :: struct {
    handle: InstructionHandler,
    
    name: string,
    length: u8,
    override: bool
}

@(init)
setup_instruction_table :: proc "contextless"() {
    register_control_instructions(&InstructionTable)
    register_load_instructions_8(&InstructionTable)
    register_load_instructions_16(&InstructionTable)
    register_arithmetic_8bit_instructions(&InstructionTable)
    register_arithmetic_16bit_instructions(&InstructionTable)
    register_rotation_instructions(&InstructionTable)
    register_misc_instructions(&InstructionTable)

    // Register prefixed instructions
    register_bitwise_instructions_CB(&PrefixedTable)
}

decode_bits :: #force_inline proc(opcode: u8, shift: u8, width: u8) -> u8 {
    mask := u8((1 << width) - 1)
    return u8((opcode >> shift) & mask)
}

// Also used to decode opernand-front
decode_r8_dst :: #force_inline proc(opcode: u8) -> op_8 {
    return op_8(decode_bits(opcode, 3, 3))
}

// Also used to decode opernand-back
decode_r8_src :: #force_inline proc(opcode: u8) -> op_8 {
    return op_8(decode_bits(opcode, 0, 3))
}

decode_r16 :: #force_inline proc(opcode: u8) -> op_16 {
    return op_16(decode_bits(opcode, 4, 2))
}

decode_r16stk :: #force_inline proc(opcode: u8) -> op_16_stk {
    return op_16_stk(decode_bits(opcode, 4, 2))
}

decode_r16_mem :: #force_inline proc(opcode: u8) -> op_16_mem {
    return op_16_mem(decode_bits(opcode, 4, 2))
}

decode_condition :: #force_inline proc(opcode: u8) -> op_cond {
    return op_cond(decode_bits(opcode, 3, 2))
}

resolve_condition :: #force_inline proc(cpu: ^CPU, condition: op_cond) -> bool {
    switch condition {
        case .nz: return !get_flag(cpu, .Z)
        case .z: return get_flag(cpu, .Z)
        case .nc: return !get_flag(cpu, .C)
        case .c: return get_flag(cpu, .C)
    }
    return false
}

convert_op16stk_to_reg16 :: #force_inline proc(op: op_16_stk) -> REG_16 {
    switch op {
        case .bc: return .BC
        case .de: return .DE
        case .hl: return .HL
        case .af: return .AF
    }

    return .BC
}

convert_op16_to_reg16 :: #force_inline proc(op: op_16) -> REG_16 {
    switch op {
    case .bc:
        return .BC
    case .de:
        return .DE
    case .hl:
        return .HL
    case .sp:
        return .SP
    }

    return .BC
}

write_r16mem :: proc(cpu: ^CPU, r16mem: op_16_mem, value: u8) {
    switch r16mem {
    case .bc:
        addr := read_r16(cpu, .BC)
        cpu.bus.write(cpu.bus, addr, value)
    case .de:
        addr := read_r16(cpu, .DE)
        cpu.bus.write(cpu.bus, addr, value)
    case .hlp:
        addr := read_r16(cpu, .HL)
        cpu.bus.write(cpu.bus, addr, value)
        inc_r16(cpu, .HL)
    case .hlm:
        addr := read_r16(cpu, .HL)
        cpu.bus.write(cpu.bus, addr, value)
        dec_r16(cpu, .HL)
    }
}

read_r16mem :: proc(cpu: ^CPU, r16mem: op_16_mem) -> u8 {
    switch r16mem {
    case .bc:
        return cpu.bus.read(cpu.bus, read_r16(cpu, .BC))
    case .de:
        return cpu.bus.read(cpu.bus, read_r16(cpu, .DE))
    case .hlp:
        addr := read_r16(cpu, .HL)
        value := cpu.bus.read(cpu.bus, addr)
        inc_r16(cpu, .HL)
        return value
    case .hlm:
        addr := read_r16(cpu, .HL)
        value := cpu.bus.read(cpu.bus, addr)
        dec_r16(cpu, .HL)
        return value
    }

    return 0x00
}

register_instruction :: proc "contextless"(
    table: ^[256]Instruction,
    handler: InstructionHandler,
    name: string,
    mask: u8,
    value: u8,
    length: u8 = 1,
    allow_override := true,
) {
    context = runtime.default_context()

    for opcode_int in 0..<256 {
        opcode := u8(opcode_int)

        if opcode & mask != value {
            continue
        }

        if table[opcode].length > 0 && !table[opcode].override {
            str := fmt.tprintf("Opcode %02X was already previously registered, and previous Handler: %s does not allow overrides", opcode, table[opcode].name)
            assert(false, str)
        }

        table[opcode] = {
            handle = handler,
            name    = name,
            length  = length,
            override = allow_override
        }
    }
}

handle_instruction :: proc(
    cpu: ^CPU,
    opcode: u8
) -> (cycles: u8) {
    fetchedOpcode := opcode
    len := InstructionTable[opcode].length
    if opcode == 0xCB {
        fetchedOpcode = fetch_next_u8(cpu)
        len = PrefixedTable[fetchedOpcode].length
    }

    if len == 0 {
        log.errorf("Could not find instruction handler matching %02X in table...", fetchedOpcode)
        return
    }

    m_cycles: u8
    if opcode == 0xCB do m_cycles = PrefixedTable[fetchedOpcode].handle(cpu, fetchedOpcode)
    else do m_cycles = InstructionTable[fetchedOpcode].handle(cpu, fetchedOpcode)

    return m_cycles
}