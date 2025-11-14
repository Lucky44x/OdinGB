#+feature dynamic-literals
package sm83

import "core:math"
import "core:fmt"
import "core:mem"

FLAGS :: enum(u8) {
    ZERO = 7,
    SUB = 6,
    HCARRY = 5,
    CARRY = 4     
}

REG8 :: enum(u8) {
    A = 0, F = 1, B = 2, C = 3, D = 4, E = 5, H = 6, L = 7, IME, _IME_NEXT, NONE
}

REG16 :: enum(u8) {
    SP, PC, AF = 0, BC = 2, DE = 4, HL = 6, NONE = 8
}

Registers :: struct {
    regs: [REG8]u8,
    SP, PC: u16,

    IME: bool,
    IME_NEXT: bool
}

/*
    Register Math
*/
add_register :: proc {
    add_register_u8,
    add_register_u16
}

add_register_u8 :: proc(
    ctx: ^CPU,
    reg: REG8,
    val: int,
) {
    if val < 0 do ctx.registers.regs[reg] -= u8(abs(val))
    else do ctx.registers.regs[reg] += u8(abs(val))
}

add_register_u16 :: proc(
    ctx: ^CPU,
    reg: REG16,
    val: int,
) {
    prev: u16 = get_register_u16(ctx, reg)
    //fmt.printfln("Reg %i before add: %#04X", reg, prev)
    if val < 0 do prev -= u16(abs(val))
    else do prev += u16(abs(val))
    //fmt.printfln("Reg %i after adding %i: %#04X", reg, val, prev)
    set_register_u16(ctx, reg, prev)
}

/*
    Register functions are deliberatly split rather than polymorphic,
    to avoid accidental 16 bit sets on 8 bit registers for example
*/
set_register :: proc {
    set_register_u8,
    set_register_u16
}

set_register_u8 :: proc(
    ctx: ^CPU,
    reg: REG8,
    val: u8,
) {
    if reg == .NONE {
        when ODIN_DEBUG do fmt.eprintfln("[REGISTER-SETTER] Cannot set 16-Bit Register NONE...")
        return 
    }

    if reg == ._IME_NEXT {
        ctx.registers.IME_NEXT = val != 0x00
        return
    }
    if reg == .IME {
        ctx.registers.IME = val != 0x00
        return
    }

    ctx.registers.regs[reg] = val
}

set_register_u16 :: proc(
    ctx: ^CPU,
    reg: REG16,
    val: u16
) {
    //fmt.printfln("Setting reg %i to %#04X", reg, val)
    if reg == .NONE {
        when ODIN_DEBUG do fmt.eprintfln("[REGISTER-SETTER] Cannot set 16-Bit Register NONE...")
        return 
    }

    if reg == .SP {
        ctx.registers.SP = val
        return 
    }
    if reg == .PC {
        ctx.registers.PC = val
        return 
    }

    lo := u8(val & 0xFF)
    hi := u8(val >> 8) & 0xFF

    if reg == .AF do lo &= 0xF0

    ctx.registers.regs[REG8(reg)] = lo
    ctx.registers.regs[REG8(u8(reg) + 1)] = hi
}

/*
    Register functions are deliberatly split rather than polymorphic,
    to avoid accidental 16 bit sets on 8 bit registers for example

    get_register_daa is ABSOLUTELY misplaced in here, but ey, it works....
*/
get_register :: proc {
    get_register_u8,
    get_register_u16,
    get_register_daa
}

get_register_daa :: proc(
    ctx: ^CPU
) -> (output: u8, shouldCarry: bool) {
    offset := 0
    shouldCarry = false

    regA := get_register(ctx, REG8.A)
    hc := get_flag(ctx, .HCARRY)
    c := get_flag(ctx, .CARRY)
    sub := get_flag(ctx, .SUB)

    if sub == 0 && regA & 0xF > 0x09 || hc == 0x01 do offset |= 0x06
    if sub == 0 && regA > 0x99 || c == 0x01 {
        offset |= 0x60
        shouldCarry = true
    }

    if sub == 0 do output = regA + u8(offset)
    else do output = regA - u8(offset)

    return
}

get_register_u8 :: proc(
    ctx: ^CPU,
    reg: REG8
) -> (
    val: u8
) {
    if reg == .NONE {
        when ODIN_DEBUG do fmt.eprintfln("[REGISTER-GETTER] Cannot get 16-Bit Register NONE...")
        return 0x00
    }
    
    if reg == .IME do return ctx.registers.IME ? 0x01 : 0x00
    if reg == ._IME_NEXT do return ctx.registers.IME_NEXT ? 0x01 : 0x00

    return ctx.registers.regs[reg]
}

get_register_u16 :: proc(
    ctx: ^CPU,
    reg: REG16
) -> (
    val: u16
) {
    if reg == .NONE {
        when ODIN_DEBUG do fmt.eprintfln("[REGISTER-GETTER] Cannot get 16-Bit Register NONE...")
        return 0x00
    }
    if reg == .SP do return ctx.registers.SP
    if reg == .PC do return ctx.registers.PC

    lo := u16(ctx.registers.regs[REG8(reg)] & 0xFF)
    hi := u16((ctx.registers.regs[REG8(u8(reg) + 1)]) & 0xFF)

    return (hi << 8) | lo
}

set_flag :: proc(
    ctx: ^CPU,
    flag: FLAGS,
    state: u8
) {
    bit := u8(1) << (u8(flag) % 8)
    if state != 0x00 do ctx.registers.regs[REG8.F] |= bit     // Set bit
    else do ctx.registers.regs[REG8.F] &= ~bit        // Clear bit
    ctx.registers.regs[REG8.F] &= 0xF0
}

get_flag :: proc(
    ctx: ^CPU,
    flag: FLAGS
) -> (f: u8) {
    bit := u8(1) << (u8(flag) % 8)
    return ctx.registers.regs[REG8.F] & bit != 0x00 ? 0x01 : 0x00
}