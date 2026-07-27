package cpu

import "core:sys/info"
import "core:log"
@(private)
Registers :: struct {
    // Generic registers
    bytes: [8]u8,

    // Special registers
    sp, pc: u16
}

REG_8 :: enum(u8) {
    B = 0, C = 1, D = 2, E = 3, H = 4, L = 5, F = 6, A = 7
}

REG_16 :: enum(u8) {
    BC = 0, DE = 2, HL = 4, AF, SP, PC
}

write :: proc {
    write_r16,
    write_r8
}

write_r16 :: proc(
    c: ^CPU, 
    register: REG_16, \
    value: u16
) {
    hi := u8(value >> 8)
    lo := u8(value)

    switch register {
    case .BC:
        write_r8(c, .B, hi)
        write_r8(c, .C, lo)

    case .DE:
        write_r8(c, .D, hi)
        write_r8(c, .E, lo)

    case .HL:
        write_r8(c, .H, hi)
        write_r8(c, .L, lo)

    case .AF:
        write_r8(c, .A, hi)
        write_r8(c, .F, lo)

    case .SP:
        c.regs.sp = value

    case .PC:
        c.regs.pc = value
    }
}

write_r8 :: proc(
    c: ^CPU,
    register: REG_8,
    value: u8,
) {
    if register == .F {
        c.regs.bytes[register] = value & 0xF0
    } else {
        c.regs.bytes[register] = value
    }
}

read :: proc {
    read_r16,
    read_r8
}

read_r16 :: proc(
    c: ^CPU, 
    register: REG_16
) -> u16 {
    hi, lo: u8

    switch register {
    case .BC:
        hi = read_r8(c, .B)
        lo = read_r8(c, .C)

    case .DE:
        hi = read_r8(c, .D)
        lo = read_r8(c, .E)

    case .HL:
        hi = read_r8(c, .H)
        lo = read_r8(c, .L)

    case .AF:
        hi = read_r8(c, .A)
        lo = read_r8(c, .F)

    case .SP:
        return c.regs.sp

    case .PC:
        return c.regs.pc
    }

    return (u16(hi) << 8) | u16(lo)
}

read_r8 :: proc(
    c: ^CPU, 
    register: REG_8
) -> u8 {
    return c.regs.bytes[register];
}

increment :: proc {
    inc_r16,
    inc_r8
}

inc_r16 :: proc(
    c: ^CPU,
    register: REG_16,
    inc: u16 = 1
) -> u16 {
    value := read_r16(c, register)
    value += inc
    write_r16(c, register, value)
    return value
}

inc_r8 :: proc(
    c: ^CPU,
    register: REG_8,
    inc: u8 = 1
) -> u8 {
    value := read_r8(c, register)
    value += inc
    write_r8(c, register, value)
    return value
}

decrement :: proc {
    dec_r16,
    dec_r8
}

dec_r16 :: proc(
    c: ^CPU,
    register: REG_16,
    dec: u16 = 1
) -> u16 {
    value := read_r16(c, register)
    value -= dec
    write_r16(c, register, value)
    return value
}

dec_r8 :: proc(
    c: ^CPU,
    register: REG_8,
    dec: u8 = 1
) -> u8 {
    value := read_r8(c, register)
    value -= dec
    write_r8(c, register, value)
    return value
}