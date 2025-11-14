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
    A, F, B, C, D, E, H, L, IME, _IME_NEXT, NONE
}

REG16 :: enum(u8) {
    PC, SP, AF, BC, DE, HL, NONE
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
    if val < 0 do ctx.registers[u8(reg)] -= u8(abs(val))
    else do ctx.registers[u8(reg)] += u8(abs(val))
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


}

set_flag :: proc(
    ctx: ^CPU,
    flag: FLAGS,
    state: u8
) {
    bit := u8(1) << (u8(flag) % 8)
    if state != 0x00 do ctx.registers[REG8.F] |= bit     // Set bit
    else do ctx.registers[REG8.F] &= ~bit        // Clear bit
    ctx.registers[REG8.F] &= 0xF0
}

get_flag :: proc(
    ctx: ^CPU,
    flag: FLAGS
) -> (f: u8) {
    bit := u8(1) << (u8(flag) % 8)
    return ctx.registers[REG8.F] & bit != 0x00 ? 0x01 : 0x00
}