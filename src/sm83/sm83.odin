package sm83

import "core:fmt"
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

step :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU
) -> (
    elapsed_cycles: u32
) {
    addr : u16 = get_register(ctx, REG16.PC)
    ins_byte := mmu.get(bus, u8, addr)
    op_handler, op_data := decode_instruction(addr, bus)
    
    if op_handler.length != 0 {
        when ODIN_DEBUG do fmt.printfln("[SM83-STEP] Executing: %#02X - %s", op_data.opbytes[0], op_handler.name)
        defer  delete(op_data.opbytes)
    } else {
        when !ODIN_DEBUG do return 0
    }

    add_register(ctx, REG16.PC, int(op_handler.length))
    cycles := op_handler.handler(ctx, bus, op_data)
    if cycles == 0 do fmt.eprintfln("[SM83-STEP] Error %#02X - %s -> Unimplemented...", op_data.opbytes[0], op_handler.name)
    return cycles
}