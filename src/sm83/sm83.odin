package sm83

import "core:fmt"
import "../mmu"
import "core:log"

DEBUG_PRINT :: #config(VERBOSE, false)

CPU :: struct {
    running: bool,
    registers: Registers
}

Interrupts :: enum(u8) {
    VBlank = 0,         // Bit 0
    STAT,               // Bit 1
    Timer,              // Bit 2
    Serial,             // Bit 3
    Joypad              // Bit 4
}

init :: proc(
    ctx: ^CPU
) {
    // Initialize Instruction Tables
    init_instructions()

    ctx.running = true
}

deinit :: proc(
    ctx: ^CPU
) {
    //free(ctx.registers)
}

push_stack :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    val: u16
) {
    sp := get_register(ctx, REG16.SP)
    //mmu.put(bus, val, sp - 1)

    hi := u8(val & 0xFF)
    lo := u8(val >> 8) & 0xFF
    mmu.put(bus, lo, sp - 1)
    mmu.put(bus, hi, sp)

    sp -= 0x02
    set_register(ctx, REG16.SP, sp)
}

pop_stack :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU
) -> u16 {
    sp := get_register(ctx, REG16.SP)

    lo := cast(u16)mmu.get(bus, u8, sp + 1)
    hi := cast(u16)mmu.get(bus, u8, sp + 2)
    val := (lo << 8) | hi

    sp += 0x02
    set_register(ctx, REG16.SP, sp)
    return val
}

call_routine :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    addr: u16
) {
    push_stack(ctx, bus, get_register(ctx, REG16.PC))
    set_register(ctx, REG16.PC, addr)
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
    // Immediatly step interrupts
    interrupted, cycles := step_interrupts(ctx, bus)
    if interrupted do return cycles                     // Immediatly skip to next execution-step after returning 5 M-Cycles for interrupt handler

    addr : u16 = get_register(ctx, REG16.PC)
    ins_byte := mmu.get(bus, u8, addr)
    op_handler, op_data := decode_instruction(addr, bus)
    
    if op_handler.length != 0 {
        when DEBUG_PRINT {
            if ins_byte != 0x00 && bus.banked {
                log.infof("[SM83-STEP] Executing: %#02X - %s - len: %i - PC_of_command: %#04X ... DATA:", op_data.opbytes[0], op_handler.name, op_handler.length, get_register(ctx, REG16.PC))
                log.infof("[SM83-STEP] Register State: PC=%#04X  HL=%#04X  A=%#02X  F=%#02X", ctx.registers.PC, get_register_u16(ctx, .HL), ctx.registers.regs[.A], ctx.registers.regs[.F])
                for i in 0 ..< op_handler.length do log.infof(" %#02X ",op_data.opbytes[i])
                log.info("-=-\n")
            }
        }
        defer delete(op_data.opbytes)
    } else {
        when !ODIN_DEBUG do return 0
    }

    if op_handler.handler == nil {
        log.fatalf("[SM83-STEP] HEINOUS ERROR: %#02X : %s could not execute, because Handler is nil?", ins_byte, op_handler.name)
        panic("[SM83 STEP] CRITICAL")
    }

    add_register(ctx, REG16.PC, int(op_handler.length))
    cycles = op_handler.handler(ctx, bus, op_data)
    if cycles == 0 do log.warnf("[SM83-STEP] Error %#02X - %s -> Unimplemented...", op_data.opbytes[0], op_handler.name)
    return cycles
}