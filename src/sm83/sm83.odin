package sm83

import "core:sys/valgrind"
import "core:fmt"
import "base:builtin"
import "../mmu"

CPU :: struct {
    registers: [^]u8
}

init :: proc(
    ctx: ^CPU
) {
    // Initialize Instruction Tables
    init_instructions()

    // Make Registers
    ctx.registers = make([^]u8, 16)
}

deinit :: proc(
    ctx: ^CPU
) {
    free(ctx.registers)
}

push_stack :: proc{
    push16,
    push8
}

pop_stack :: proc {
    pop16,
    pop8
}

// --- 8-bit push/pop ---

push8 :: proc(ctx: ^CPU, bus: ^mmu.MMU, b: u8) {
    // SP := SP - 1 ; [SP] = b
    sp := get_register(ctx, REG16.SP)
    mmu.put(bus, b, sp - 1)
    add_register(ctx, REG16.SP, -1)
}

pop8 :: proc(ctx: ^CPU, bus: ^mmu.MMU) -> u8 {
    // b := [SP] ; SP := SP + 1
    sp := get_register(ctx, REG16.SP)
    b  := mmu.get(bus, u8, sp)
    add_register(ctx, REG16.SP, 1)
    return b
}


// --- 16-bit push/pop (SM83 order!) ---
// PUSH: write HIGH first at SP-1, then LOW at (new SP-1)
// POP:  read LOW from SP, then HIGH from SP+1

push16 :: proc(ctx: ^CPU, bus: ^mmu.MMU, v: u16) {
    hi := u8((v >> 8) & 0xFF)
    lo := u8(v & 0xFF)

    // write HI at SP-1
    sp := get_register(ctx, REG16.SP)
    mmu.put(bus, hi, sp - 1)
    add_register(ctx, REG16.SP, -1)

    // write LO at (new SP)-1
    sp = get_register(ctx, REG16.SP)
    mmu.put(bus, lo, sp - 1)
    add_register(ctx, REG16.SP, -1)
}

pop16 :: proc(ctx: ^CPU, bus: ^mmu.MMU, _ignore := false) -> u16 {
    // read LO at SP
    sp := get_register(ctx, REG16.SP)
    lo := mmu.get(bus, u8, sp)
    add_register(ctx, REG16.SP, 1)

    // read HI at (new SP)
    sp = get_register(ctx, REG16.SP)
    hi := mmu.get(bus, u8, sp)
    add_register(ctx, REG16.SP, 1)

    return (u16(hi) << 8) | u16(lo)
}

check_ime_enable :: proc(
    ctx: ^CPU
) {
    if get_register(ctx, REG8._IME_NEXT) != 0x01 do return 
    set_register(ctx, REG8._IME_NEXT, 0x00)
}

step :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU
) -> (
    elapsed_cycles: u32
) {
    check_ime_enable(ctx)

    addr : u16 = get_register(ctx, REG16.PC)
    ins_byte := mmu.get(bus, u8, addr)
    op_handler, op_data := decode_instruction(addr, bus)
    
    if op_handler.length != 0 {
        when ODIN_DEBUG {
            if ins_byte != 0x00 {
                fmt.printfln("[SM83-STEP] Executing: %#02X - %s - len: %i - PC_of_command: %#02X ... DATA:", op_data.opbytes[0], op_handler.name, op_handler.length, get_register(ctx, REG16.PC))
                for i in 0 ..< op_handler.length do fmt.printf(" %#02X ",op_data.opbytes[i])
                fmt.printf("\n")
            }
        }
        defer  delete(op_data.opbytes)
    } else {
        when !ODIN_DEBUG do return 0
    }

    add_register(ctx, REG16.PC, int(op_handler.length))
    cycles := op_handler.handler(ctx, bus, op_data)
    if cycles == 0 do fmt.eprintfln("[SM83-STEP] Error %#02X - %s -> Unimplemented...", op_data.opbytes[0], op_handler.name)
    return cycles * 4
}