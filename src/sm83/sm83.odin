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

push_stack :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    val: $T
) {
    addr := get_register(ctx, REG16.SP)
    mmu.put(bus, val, addr - (size_of(T) - 1)) // Offset by size_of(T) to the left, makes sure we have enough space for val
    add_register(ctx, REG16.SP, -size_of(T))
}

pop_stack :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    $T: typeid
) -> T {
    addr := get_register(ctx, REG16.SP)
    val := mmu.get(bus, T, addr + 1)        // Offset by 1 byte to the right -> make sure we read the next actual entry
    add_register(ctx, REG16.SP, size_of(T))
    return val
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
        when ODIN_DEBUG do if ins_byte != 0x00 do fmt.printfln("[SM83-STEP] Executing: %#02X - %s", op_data.opbytes[0], op_handler.name)
        defer  delete(op_data.opbytes)
    } else {
        when !ODIN_DEBUG do return 0
    }

    add_register(ctx, REG16.PC, int(op_handler.length))
    cycles := op_handler.handler(ctx, bus, op_data)
    if cycles == 0 do fmt.eprintfln("[SM83-STEP] Error %#02X - %s -> Unimplemented...", op_data.opbytes[0], op_handler.name)
    return cycles
}