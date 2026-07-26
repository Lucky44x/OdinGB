#+private
package cpu

import "core:log"
register_rotation_instructions :: proc "contextless" (table: ^[256]Instruction) {
    register_instruction(table, ins_rrca, "RRCA / RRA", 0b11101111, 0b00001111, allow_override = false)
    register_instruction(table, ins_rlca, "RLCA / RLA", 0b11101111 , 0b00000111, allow_override = false)
}

register_bitwise_instructions_CB :: proc "contextless" (table: ^[256]Instruction) {\
    register_instruction(table, ins_put, "SET / RES b r8", 0b10000000, 0b10000000)
    register_instruction(table, ins_bit, "BIT", 0b11000000, 0b01000000)

    register_instruction(table, ins_rl_r8, "RL / RLC R8", 0b11101000, 0b00000000)
    register_instruction(table, ins_rr_r8, "RR / RRC R8", 0b11101000, 0b00001000)
    register_instruction(table, ins_shift_arithmetic, "SRA / SLA R8", 0b11110000, 0b00100000)

    register_instruction(table, ins_swap, "SWAP r8", 0b11111000, 0b00110000)
    register_instruction(table, ins_shift_right_logical, "SRL r8", 0b11111000, 0b00111000)
}

//==================================================
//              Non-Prefix Rotation operations
//==================================================

/*
    Rotates the value of A right and sets C according to the param:
        1: puts C into the free bit and stores overflow in C
        0: cycles overflow bit back and stores overflow in C
    Mask: 0b11101111
    Vars: 0b000x1111

    Flags:
        Z: Reset
        N: Reset
        H: Reset
        C: A[0]

    Example:
        Circular: 0F
        Normal: 1F
*/
ins_rrca :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    is_circular := opcode & 0x10 == 0

    value := read_r8(cpu, .A)
    b0 := value & 1

    value >>= 1
    value |= is_circular ? (b0 << 7) : (u8(get_flag(cpu, .C)) << 7)

    write_r8(cpu, .A, value)

    set_flag(cpu, .Z, false)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, false)
    set_flag(cpu, .C, b0 != 0)
    return 1
}

/*
    Rotates the value of A left and sets C according to the param:
        1: puts C into the free bit and stores overflow in C
        0: cycles overflow bit back and stores overflow in C
    Mask: 0b11101111
    Vars: 0b000x0111

    Flags:
        Z: Reset
        N: Reset
        H: Reset
        C: A[0]

    Example:
        Circular: 07
        Normal: 17
*/
ins_rlca :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    is_circular := opcode & 0x10 == 0

    value := read_r8(cpu, .A)
    b7 := (value >> 7) & 1

    value <<= 1
    value |= is_circular ? b7 : u8(get_flag(cpu, .C))

    write_r8(cpu, .A, value)

    set_flag(cpu, .Z, false)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, false)
    set_flag(cpu, .C, b7 != 0)
    return 1
}

//==================================================
//              Prefixed Bitwise operations
//==================================================

/*
    Rotates the value of r8 left and sets C according to the param:
        1: puts C into the free bit and stores overflow in C
        0: cycles overflow bit back and stores overflow in C
    Mask: 0b11101000
    Vars: 0b000y0xxx
        x: r8
        y: param

    Flags:
        Z: Reset
        N: Reset
        H: Reset
        C: A[7]

    Example:
        Circular: CB 00
        Normal: CB 10
*/
ins_rl_r8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    is_circular := opcode & 0x10 == 0
    operand := decode_r8_src(opcode)

    value: u8
    if operand == .mem do value = cpu.bus.read(cpu.bus.ctx, read_r16(cpu, .HL))
    else do value = read_r8(cpu, REG_8(operand))

    b7 := (value >> 7) & 1

    value <<= 1
    value |= is_circular ? b7 : u8(get_flag(cpu, .C))

    if operand == .mem do cpu.bus.write(cpu.bus.ctx, read_r16(cpu, .HL), value)
    else do write_r8(cpu, REG_8(operand), value)

    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, false)
    set_flag(cpu, .C, b7 != 0)
    return operand == .mem ? 4 : 2
}

/*
    Rotates the value of r8 right and sets C according to the param:
        1: puts C into the free bit and stores overflow in C
        0: cycles overflow bit back and stores overflow in C
    Mask: 0b11101000
    Vars: 0b000y1xxx
        x: r8
        y: param

    Flags:
        Z: Reset
        N: Reset
        H: Reset
        C: A[0]

    Example:
        Circular: CB 08
        Normal: CB 18
*/
ins_rr_r8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    is_circular := opcode & 0x10 == 0
    operand := decode_r8_src(opcode)

    value: u8
    if operand == .mem do value = cpu.bus.read(cpu.bus.ctx, read_r16(cpu, .HL))
    else do value = read_r8(cpu, REG_8(operand))

    b0 := value & 1

    value >>= 1
    value |= is_circular ? (b0 << 7) : (u8(get_flag(cpu, .C)) << 7)

    if operand == .mem do cpu.bus.write(cpu.bus.ctx, read_r16(cpu, .HL), value)
    else do write_r8(cpu, REG_8(operand), value)

    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, false)
    set_flag(cpu, .C, b0 != 0)
    return operand == .mem ? 4 : 2
}

/*
    Shifts the value left or right (depends on param), appends carry to the end and stores the overflow in the carry
    Mask: 0b11110000
    Vars: 0b0010yxxx
        x: r8
        y: 1 -> 

    Flags:
        Z: value == 0
        N: Reset
        H: Reset
        C: overflow != 0

    Example:
        Left: CB 20
        Right: CB 28
*/
ins_shift_arithmetic :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    is_rightshift := opcode & 0x8 != 0
    operand := decode_r8_src(opcode)

    value: u8
    if operand == .mem do value = cpu.bus.read(cpu.bus.ctx, read_r16(cpu, .HL))
    else do value = read_r8(cpu, REG_8(operand))

    overflow := is_rightshift ? value & 1 : (value >> 7) & 1
    if is_rightshift do value >>= 1
    else do value <<= 1

    if is_rightshift do value |= (value & 0x40) << 1 // Duplicate bit 7
    else do value &= 0xFE // Clear bit 0

    if operand == .mem do cpu.bus.write(cpu.bus.ctx, read_r16(cpu, .HL), value)
    else do write_r8(cpu, REG_8(operand), value)

    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, false)
    set_flag(cpu, .C, overflow != 0)
    return operand == .mem ? 4 : 2
}

/*
    Swaps high and low nibbles of the byte inside the specified register
    Mask: 0b11111000
    Vars: 0b00110xxx
        x: r8

    Flags:
        Z: result == 0
        N: Reset
        H: Reset
        C: Reset

    Example: CB 0x30
*/
ins_swap :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r8_src(opcode)

    value: u8
    if operand == .mem do value = cpu.bus.read(cpu.bus.ctx, read_r16(cpu, .HL))
    else do value = read_r8(cpu, REG_8(operand))

    lo := value & 0x0F
    hi := value & 0xF0 >> 4
    value = lo << 4 | hi

    if operand == .mem do cpu.bus.write(cpu.bus.ctx, read_r16(cpu, .HL), value)
    else do write_r8(cpu, REG_8(operand), value)

    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, false)
    set_flag(cpu, .C, false)

    return operand == .mem ? 4 : 2
}

/*
    Shifts the value of r8 right and replaces bit 7 with 0
    Mask: 0b11111000
    Vars: 0b00111xxx
        x: r8

    Flags:
        Z: value == 0
        N: Reset
        H: Reset
        C: overflow != 0

    Example: CB 0x38
*/
ins_shift_right_logical :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r8_src(opcode)

    value: u8
    if operand == .mem do value = cpu.bus.read(cpu.bus.ctx, read_r16(cpu, .HL))
    else do value = read_r8(cpu, REG_8(operand))

    b0 := value & 1
    value >>= 1
    value &= 0x7F // Clear bit 7

    if operand == .mem do cpu.bus.write(cpu.bus.ctx, read_r16(cpu, .HL), value)
    else do write_r8(cpu, REG_8(operand), value)

    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, false)
    set_flag(cpu, .C, b0 != 0)
    
    return operand == .mem ? 4 : 2
}

/*
    Tests bit at index b0 in the register r8
    Mask: 0b11000000
    Vars: 0b01bbbxxx
        b: bit index
        x: r8

    Flags:
        Z: r8[b] == 0
        N: Reset
        H: Set

    Example: CB 0x40
*/
ins_bit :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    bit_index := decode_bits(opcode, 3, 3)
    operand := decode_r8_src(opcode)

    value: u8
    if operand == .mem do value = cpu.bus.read(cpu.bus.ctx, read_r16(cpu, .HL))
    else do value = read_r8(cpu, REG_8(operand))

    bit := (value >> bit_index) & 1

    set_flag(cpu, .Z, bit == 0)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, true)

    return operand == .mem ? 3 : 2
}

/*
    Resets / Sets the bit b in r8 to 0
    Mask: 0b10000000
    Vars: 0b1ybbbxxx
        b: bit index
        x: r8
        y: 1 -> Set bit, 0 -> Reset bit

    Flags: -

    Example:
        Reset: CB 80
        Set: CB C0
*/
ins_put :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    is_set := opcode & 0x40 != 0
    bit_index := decode_bits(opcode, 3, 3)
    operand := decode_r8_src(opcode)

    value: u8
    if operand == .mem do value = cpu.bus.read(cpu.bus.ctx, read_r16(cpu, .HL))
    else do value = read_r8(cpu, REG_8(operand))

    if is_set do value |= (1 << bit_index)
    else do value &= ~(1 << bit_index)

    if operand == .mem do cpu.bus.write(cpu.bus.ctx, read_r16(cpu, .HL), value)
    else do write_r8(cpu, REG_8(operand), value)

    return operand == .mem ? 4 : 2
}
