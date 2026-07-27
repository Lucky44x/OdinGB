#+private
package cpu

import "core:c"
register_arithmetic_8bit_instructions :: proc "contextless" (table: ^[256]Instruction) {
    register_instruction(table, ins_inc_r8, "INC r8", 0b11000111, 0b00000100, 1)
    register_instruction(table, ins_dec_r8, "DEC r8", 0b11000111, 0b00000101, 1)
    register_instruction(table, ins_add_a_r8, "ADD/C A r8", 0b11110000, 0b10000000, 1)
    register_instruction(table, ins_add_a_imm8, "ADD/C A imm8", 0b11110111, 0b11000110, 2)
    register_instruction(table, ins_sub_a_r8, "SUB/C A r8", 0b11110000, 0b10010000, 1)
    register_instruction(table, ins_sub_a_imm8, "SUB/C A imm8", 0b11110111, 0b11010110, 2)
    register_instruction(table, ins_and_a_r8, "AND A r8", 0b11111000, 0b10100000, 1)
    register_instruction(table, ins_and_a_imm8, "AND A imm8", 0xFF, 0xE6, 2, allow_override=false)
    register_instruction(table, ins_xor_a_r8, "XOR A r8", 0b11111000, 0b10101000, 1)
    register_instruction(table, ins_xor_a_imm8, "XOR A imm8", 0xFF, 0xEE, 2, allow_override=false)
    register_instruction(table, ins_or_a_r8, "OR A r8", 0b11111000, 0b10110000, 1)
    register_instruction(table, ins_or_a_imm8, "OR A imm8", 0xFF, 0xF6, 2, allow_override=false)
    register_instruction(table, ins_comp_a_r8, "COMP A r8", 0b11111000, 0b10111000, 1)
    register_instruction(table, ins_comp_a_imm8, "COMP A imm8", 0xFF, 0xFE, 2, allow_override=false)

    register_instruction(table, ins_ccf, "CCF", 0xFF, 0x3F, allow_override=false)
    register_instruction(table, ins_scf, "SCF", 0xFF, 0x37, allow_override=false)
    register_instruction(table, ins_cpl, "CPL", 0xFF, 0x2F, allow_override=false)
    register_instruction(table, ins_daa, "DAA", 0xFF, 0x27, allow_override=false)
}

//==================================================
//              8 BIT Arithmetic operations
//==================================================

/*
    Increment the register r8
    Mask: 11000111
    Vars: 00xxx100
        x: operand r8

    Flags:
        Z: Set if result is zero
        N: Reset
        H: Set if carry from bit 3

    Example: 0x04 -> 00000100 = INC B
*/
ins_inc_r8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r8_dst(opcode)
    original: u8
    if operand == .mem do original = cpu.bus.read(cpu.bus, read_r16(cpu, .HL))
    else do original = read_r8(cpu, REG_8(operand))
    
    value := original + 1
    
    if operand == .mem do cpu.bus.write(cpu.bus, read_r16(cpu, .HL), value)
    else do write_r8(cpu, REG_8(operand), value)

    // Set Flags
    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, carry_per_bit(original, 1, 3))

    return operand == .mem ? 3 : 1
}

/*
    Decrement the register r8
    Mask: 11000111
    Vars: 00xxx101
        x: operand r8
    
    Flags:
        Z: Set if result is zero
        N: Set
        H: Set if carry from bit 3
    
    Example: 0x05 -> 00000101 = DEC B
*/
ins_dec_r8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r8_dst(opcode)
    original: u8
    if operand == .mem do original = cpu.bus.read(cpu.bus, read_r16(cpu, .HL))
    else do original = read_r8(cpu, REG_8(operand))
    
    value := original - 1
    
    if operand == .mem do cpu.bus.write(cpu.bus, read_r16(cpu, .HL), value)
    else do write_r8(cpu, REG_8(operand), value)

    // Set Flags
    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, true)
    set_flag(cpu, .H, borrow_from_bit(original, 1, 3))

    return operand == .mem ? 3 : 1
}

/*
    Combined Instruction for ADD and ADC (with carry)
    Mask: 11110000
    Vars: 1000yxxx
        x: operand r8
        y: 0 -> ADD, 1 -> ADC
    
    Flags:
        Z: Set if result is zero
        N: Reset
        H: Set if carry from bit 3
        C: Set if carry from bit 7
    
    Example ADD: 0x80 -> 10000000
    Example ADC: 0x88 -> 10001000
*/
ins_add_a_r8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    carry_flag := (opcode & 0x08) != 0

    operand := decode_r8_src(opcode)
    left := read_r8(cpu, .A)
    right, carry_in: u8 = 0, 0

    if operand == .mem do right = cpu.bus.read(cpu.bus, read_r16(cpu, .HL))
    else do right = read_r8(cpu, REG_8(operand))

    if carry_flag do carry_in = (get_flag(cpu, .C) ? 1 : 0)

    result := u16(left) + u16(right) + u16(carry_in)
    value := u8(result)

    write_r8(cpu, .A, value)

    // Set Flags
    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, carry_per_bit(left, right, 3, carry_in))
    set_flag(cpu, .C, carry_per_bit(left, right, 7, carry_in))

    return operand == .mem ? 2 : 1
}

/*
    Add immediate 8-bit value to the accumulator A
    Mask: 11110111
    Vars: 1100x110
        x: 0 -> ADD, 1 -> ADC

    Flags:
        Z: Set if result is zero
        N: Reset
        H: Set if carry from bit 3
        C: Set if carry from bit 7

    Example ADD: 0xC6 -> 11000110
    Example ADC: 0xCE -> 11001110
*/
ins_add_a_imm8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    carry_flag := (opcode & 0x08) != 0

    left := read_r8(cpu, .A)
    right := fetch_next_u8(cpu)

    carry_in: u8 = 0
    if carry_flag do carry_in = (get_flag(cpu, .C) ? 1 : 0)

    result := u16(left) + u16(right) + u16(carry_in)
    value := u8(result)

    write_r8(cpu, .A, value)

    // Set Flags
    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, carry_per_bit(left, right, 3, carry_in))
    set_flag(cpu, .C, carry_per_bit(left, right, 7, carry_in))

    return 2
}

/*
    Subtract r8 from the accumulator A
    Mask: 11110000
    Vars: 1001yxxx
        x: operand r8
        y: 0 -> SUB, 1 -> SBC

    Flags:
        Z: Set if result is zero
        N: Set
        H: Set if carry from bit 3
        C: Set if carry from bit 7

    Example SUB: 0x90 -> 10010000
    Example SBC: 0x98 -> 10011000
*/
ins_sub_a_r8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    carry_flag := (opcode & 0x08) != 0

    operand := decode_r8_src(opcode)
    left := read_r8(cpu, .A)
    right, carry_in: u8 = 0, 0

    if operand == .mem do right = cpu.bus.read(cpu.bus, read_r16(cpu, .HL))
    else do right = read_r8(cpu, REG_8(operand))

    if carry_flag do carry_in = (get_flag(cpu, .C) ? 1 : 0)

    subtrahend := u16(right) + u16(carry_in)
    result := u16(left) - subtrahend
    value := u8(result)

    write_r8(cpu, .A, value)

    // Set Flags
    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, true)
    set_flag(cpu, .H, borrow_from_bit(left, right, 3, carry_in))
    set_flag(cpu, .C, borrow_from_bit(left, right, 7, carry_in))
    return operand == .mem ? 2 : 1
}

/*
    Subtract immediate 8-bit value from the accumulator A
    Mask: 11110111
    Vars: 1101x110
        x: 0 -> SUB, 1 -> SBC

    Flags:
        Z: Set if result is zero
        N: Set
        H: Set if carry from bit 3
        C: Set if carry from bit 7

    Example: 0xD6 -> 11010110
    Example: 0xDE -> 11011110
*/
ins_sub_a_imm8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    carry_flag := (opcode & 0x08) != 0

    left := read_r8(cpu, .A)
    right := fetch_next_u8(cpu)
    carry_in : u8 = 0

    if carry_flag do carry_in = (get_flag(cpu, .C) ? 1 : 0)

    subtrahend := u16(right) + u16(carry_in)
    result := u16(left) - subtrahend
    value := u8(result)

    write_r8(cpu, .A, value)

    // Set Flags
    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, true)
    set_flag(cpu, .H, borrow_from_bit(left, right, 3, carry_in))
    set_flag(cpu, .C, borrow_from_bit(left, right, 7, carry_in))
    return 2
}

/*
    AND r8 with the accumulator A
    Mask: 11111000
    Vars: 10100xxx
        x: operand r8

    Flags:
        Z: Set if result is zero
        N: Reset
        H: Set
        C: Reset

    Example: 0xA0 -> 10100000 = AND A, B
*/
ins_and_a_r8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r8_src(opcode)
    value := read_r8(cpu, .A)
    addend: u8
    if operand == .mem do addend = cpu.bus.read(cpu.bus, read_r16(cpu, .HL))
    else do addend = read_r8(cpu, REG_8(operand))

    value &= addend

    write_r8(cpu, .A, value)

    //Set Flags
    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, true)
    set_flag(cpu, .C, false)

    return operand == .mem ? 2 : 1
}

/*
    AND immediate 8-bit value with the accumulator A
    Mask: 11111111
    Vars: 11100110

    Flags:
        Z: Set if result is zero
        N: Reset
        H: Set
        C: Reset

    Example: 0xE6 -> 11100110 = AND A, imm8
*/
ins_and_a_imm8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    value := read_r8(cpu, .A)
    addend := fetch_next_u8(cpu)
    value &= addend

    write_r8(cpu, .A, value)

    //Set Flags
    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, true)
    set_flag(cpu, .C, false)

    return 2
}

/*
    XOR r8 with the accumulator A
    Mask: 11111000
    Vars: 10101xxx
        x: operand r8

    Flags:
        Z: Set if result is zero
        N: Reset
        H: Reset
        C: Reset
    
    Example: 0xA8 -> 10101000 = XOR A, B
*/
ins_xor_a_r8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r8_src(opcode)
    value := read_r8(cpu, .A)
    addend: u8
    if operand == .mem do addend = cpu.bus.read(cpu.bus, read_r16(cpu, .HL))
    else do addend = read_r8(cpu, REG_8(operand))

    value ~= addend

    write_r8(cpu, .A, value)

    //Set Flags
    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, false)
    set_flag(cpu, .C, false)

    return operand == .mem ? 2 : 1
}

/*
    XOR immediate 8-bit value with the accumulator A
    Mask: 11111111
    Vars: 11101110

    Flags:
        Z: Set if result is zero
        N: Reset
        H: Reset
        C: Reset

    Example: 0xEE -> 11101110 = XOR A, imm8
*/
ins_xor_a_imm8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    value := read_r8(cpu, .A)
    addend := fetch_next_u8(cpu)
    value ~= addend

    write_r8(cpu, .A, value)

    //Set Flags
    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, false)
    set_flag(cpu, .C, false)

    return 2
}

/*
    OR r8 with the accumulator A
    Mask: 11111000
    Vars: 10110xxx
        x: operand r8
    
    Flags:
        Z: Set if result is zero
        N: Reset
        H: Reset
        C: Reset

    Example: 0xB0 -> 10110000 = OR A, B
*/
ins_or_a_r8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r8_src(opcode)
    value := read_r8(cpu, .A)
    addend: u8
    if operand == .mem do addend = cpu.bus.read(cpu.bus, read_r16(cpu, .HL))
    else do addend = read_r8(cpu, REG_8(operand))

    value |= addend

    write_r8(cpu, .A, value)

    //Set Flags
    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, false)
    set_flag(cpu, .C, false)

    return operand == .mem ? 2 : 1
}

/*
    OR immediate 8-bit value with the accumulator A
    Mask: 11111111
    Vars: 11110110

    Flags:
        Z: Set if result is zero
        N: Reset
        H: Reset
        C: Reset

    Example: 0xF6 -> 11110110 = OR A, imm8
*/
ins_or_a_imm8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    value := read_r8(cpu, .A)
    addend := fetch_next_u8(cpu)
    value |= addend

    write_r8(cpu, .A, value)

    //Set Flags
    set_flag(cpu, .Z, value == 0)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, false)
    set_flag(cpu, .C, false)

    return 2
}

/*
    COMP r8 with the accumulator A
    Mask: 11111000
    Vars: 10111xxx
        x: operand r8

    Flags:
        Z: Set if result is zero
        N: Set
        H: Set if carry from bit 3
        C: Set if carry from bit 7
    
    Example: 0xB8 -> 10111000 = COMP A, B
*/
ins_comp_a_r8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r8_src(opcode)
    left := read_r8(cpu, .A)
    right: u8 = 0

    if operand == .mem do right = cpu.bus.read(cpu.bus, read_r16(cpu, .HL))
    else do right = read_r8(cpu, REG_8(operand))

    // Set Flags
    set_flag(cpu, .Z, left == right)
    set_flag(cpu, .N, true)
    set_flag(cpu, .H, borrow_from_bit(left, right, 3))
    set_flag(cpu, .C, borrow_from_bit(left, right, 7))
    return operand == .mem ? 2 : 1
}

/*
    COMP imm8 with the accumulator A
    Mask: 11111111
    Vars: 11111110

    Flags:
        Z: Set if result is zero
        N: Set
        H: Set if carry from bit 3
        C: Set if carry from bit 7

    Length: 2
    
    Example: 0xFE -> 11111110
*/
ins_comp_a_imm8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r8_src(opcode)
    left := read_r8(cpu, .A)
    right := fetch_next_u8(cpu)

    // Set Flags
    set_flag(cpu, .Z, left == right)
    set_flag(cpu, .N, true)
    set_flag(cpu, .H, borrow_from_bit(left, right, 3))
    set_flag(cpu, .C, borrow_from_bit(left, right, 7))
    return 2
}

/*
    Flips the carry flag, and clears the N and H flags
    Mask: 0xFF
    Vars: 0x3F

    Flags:
        N: Reset
        H: Reset
        C: Flip
    
    Example: 0x3F
*/
ins_ccf :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, false)
    set_flag(cpu, .C, !get_flag(cpu, .C))
    return 1;
}

/*
    Sets the carry flag, clears H and N
    Mask: 0xFF
    Vars: 0x37

    Flags:
        N: Reset
        H: Reset
        C: Flip
    
    Example: 0x37
*/
ins_scf :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, false)
    set_flag(cpu, .C, true)
    return 1;
}

/*
    Flips bits of A and sets N and H
    Mask: 0xFF
    Vars: 0x2F

    Flags:
        N: Set
        H: Set
    
    Example: 0x2F
*/
ins_cpl :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    value := read_r8(cpu, .A)
    write_r8(cpu, .A, ~value)

    // Set Flags
    set_flag(cpu, .N, true)
    set_flag(cpu, .H, true)
    return 1;
}

/*
    Decimal Adjust Accumulator for BCD arithmetic
    Mask: 0xFF
    Vars: 0x27

    Flags:
        Z: Set if the adjusted result is zero
        N: Unchanged
        H: Reset
        C: Set if the adjustment produced a carry/borrow, otherwise reset
    
    Example: 0x27
*/
ins_daa :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    offset: u8

    value_a := read_r8(cpu, .A)
    hc := get_flag(cpu, .H)
    carry := get_flag(cpu, .C)
    sub := get_flag(cpu, .N)

    if (!sub && (value_a & 0xF) > 0x09) || hc do offset |= 0x06

    should_carry := false
    if (!sub && value_a > 0x99) || carry {
        offset |= 0x60
        should_carry = true
    }
    
    adjusted: u8
    if sub do adjusted = value_a - offset
    else do adjusted = value_a + offset

    write_r8(cpu, .A, adjusted)

    set_flag(cpu, .Z, adjusted == 0)
    set_flag(cpu, .H, false)
    set_flag(cpu, .C, should_carry)

    return 1;
}
