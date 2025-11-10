package sm83

import "core:mem"

FLAGS :: enum(u8) {
    ZERO = 7,
    SUB = 6,
    HCARRY = 5,
    CARRY = 4     
}

REG8 :: enum(u8) {
    A = 4, F = 5, B = 6, C = 7, D = 8, E = 9, H = 10, L = 11
}

REG16 :: enum(u8) {
    PC = 0, SP = 2, AF = 4, BC = 6, DE = 8, HL = 10
}

CPU :: struct {
    registers: [^]u8
}

init :: proc(
    ctx: ^CPU
) {
    ctx.registers = make([^]u8, 16)
}

deinit :: proc(
    ctx: ^CPU
) {
    free(ctx.registers)
}

// #region Registers
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
    ctx.registers[u8(reg)] = val
}

set_register_u16 :: proc(
    ctx: ^CPU,
    reg: REG16,
    val: u16
) {
    local_val : u16le = u16le(val)
    dst := mem.ptr_offset(ctx.registers, u8(reg))
    mem.copy(dst, &local_val, size_of(u16le))
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
    return ctx.registers[u8(reg)]
}

get_register_u16 :: proc(
    ctx: ^CPU,
    reg: REG16
) -> (
    val: u16
) {
    dst := mem.ptr_offset(ctx.registers, u8(reg))
    return u16(mem.reinterpret_copy(u16le, dst))
}
// #endregion

set_flag :: proc(
    ctx: ^CPU,
    flag: FLAGS,
    state: bool
) {
    bit := u8(1) << (u8(flag) % 8)
    if state do ctx.registers[REG8.F] |= bit     // Set bit
    else do ctx.registers[REG8.F] &= ~bit        // Clear bit
    ctx.registers[REG8.F] &= 0xF0
}

get_flag :: proc(
    ctx: ^CPU,
    flag: FLAGS
) -> (f: bool) {
    bit := u8(1) << (u8(flag) % 8)
    return ctx.registers[REG8.F] & bit != 0
}

step :: proc(
    ctx: ^CPU
) -> (
    elapsed_cycles: u32
) {
    return 0
}