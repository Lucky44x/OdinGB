package sm83

import "core:sys/valgrind"
import "core:fmt"
import "base:builtin"
import "../mmu"

CPU :: struct {
    running: bool,
    registers: [^]u8
}

init :: proc(
    ctx: ^CPU
) {
    // Initialize Instruction Tables
    init_instructions()

    // Make Registers
    ctx.registers = make([^]u8, 16)
    ctx.running = true
}

deinit :: proc(
    ctx: ^CPU
) {
    free(ctx.registers)
}

push_stack :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    val: u16
) {
    sp := get_register(ctx, REG16.SP)
    mmu.put(bus, val, sp - 1)
    sp -= 0x02
    set_register(ctx, REG16.SP, sp)
}

pop_stack :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU
) -> u16 {
    sp := get_register(ctx, REG16.SP)
    val := mmu.get(bus, u16, sp + 1)
    sp += 0x02
    set_register(ctx, REG16.SP, sp)
    return val
}

check_ime_enable :: proc(
    ctx: ^CPU
) {
    if get_register(ctx, REG8._IME_NEXT) != 0x01 do return 
    set_register(ctx, REG8._IME_NEXT, 0x00)
    set_register(ctx, REG8.IME, 0x01)
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
                fmt.printfln("[SM83-STEP] Executing: %#02X - %s - len: %i - PC_of_command: %#04X ... DATA:", op_data.opbytes[0], op_handler.name, op_handler.length, get_register(ctx, REG16.PC))
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