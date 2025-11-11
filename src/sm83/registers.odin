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
    A = 4, F = 5, B = 6, C = 7, D = 8, E = 9, H = 10, L = 11, IME = 12, _IME_NEXT = 13, NONE = 15
}

REG16 :: enum(u8) {
    PC = 0, SP = 2, AF = 4, BC = 6, DE = 8, HL = 10, NONE = 15
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
    local_val := val
    if reg == .F do local_val &= 0xF0

    ctx.registers[u8(reg)] = local_val
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

    local_val : u16 = u16(val)
    if reg == .AF do local_val &= 0xFFF0

    dst := mem.ptr_offset(ctx.registers, u8(reg))

    mem.copy(dst, &local_val, size_of(u16))
    /*
    if reg != .SP do return 
    fmt.printfln("Combined: %#04X", local_val)
    fmt.printfln("First byte in memory: %#02X", ctx.registers[u8(reg)])
    fmt.printfln("Second byte in memory: %#02X", ctx.registers[u8(reg) + 1])
    */
}

/*
    Register functions are deliberatly split rather than polymorphic,
    to avoid accidental 16 bit sets on 8 bit registers for example
*/
get_register :: proc {
    get_register_u8,
    get_register_u16
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

    val = ctx.registers[u8(reg)]
    return 
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

    dst := mem.ptr_offset(ctx.registers, u8(reg))
    val = u16(mem.reinterpret_copy(u16, dst))
    return 
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