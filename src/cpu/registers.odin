package cpu

Registers :: struct {
    // Generic registers
    bytes: [8]u8,

    // Special registers
    sp, pc: u16
}

REG_8 :: enum(u8) {
    B = 0, C = 1, D = 2, E = 3, H = 4, L = 5, A = 6, F = 7
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
    // Special behaviour
    #partial switch(register) {
        case .SP: c.regs.sp = value; return
        case .PC: c.regs.pc = value; return
    }

    hi := u8(value >> 8)
    lo := u8(value)

    // General behaviour
    write_r8(c, REG_8(register), hi)
    write_r8(c, REG_8(u8(register) + 1), lo)
}

write_r8 :: proc(
    c: ^CPU,
    register: REG_8, 
    value: u8
) {
    // Special behaviour
    #partial switch register {
        case .F: c.regs.bytes[register] = value & 0xF0; return
    }

    // General behaviour
    c.regs.bytes[register] = value;
}

read :: proc {
    read_r16,
    read_r8
}

read_r16 :: proc(
    c: ^CPU, 
    register: REG_16
) -> u16 {
    // Special behaviour
    #partial switch(register) {
        case .SP: return c.regs.sp;
        case .PC: return c.regs.pc;
    }

    // General behaviour
    hi := read_r8(c, REG_8(register))
    lo := read_r8(c, REG_8(u8(register) + 1))

    return u16(hi << 8) | u16(lo);
}

read_r8 :: proc(
    c: ^CPU, 
    register: REG_8
) -> u8 {
    return c.regs.bytes[register];
}