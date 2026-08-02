#+private
package cpu

register_arithmetic_16bit_instructions :: proc "contextless" (table: ^[256]Instruction) {
    register_instruction(table, ins_inc_r16, "INC r16", 0b11001111, 0b00000011)
    register_instruction(table, ins_dec_r16, "DEC r16", 0b11001111, 0b00001011)
    register_instruction(table, ins_add_hl_r16, "ADD HL, r16", 0b11001111, 0b00001001)
    register_instruction(table, ins_add_sp_e, "ADD SP, e8", 0xFF, 0xE8, 2, allow_override=false)
}

//==================================================
//              16 BIT Arithmetic operations
//==================================================

/*
    Increment the register r16
    Mask: 11001111
    Vars: 00xx0011
        x: r16

    Flags: -

    Example: 0x03
*/
ins_inc_r16 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r16(opcode)

    reg := convert_op16_to_reg16(operand)
    inc_r16(cpu, reg)

    return 2
}

/*
    Decrement the register r16
    Mask: 11001111
    Vars: 00xx1011
        x: r16

    Flags: -

    Example: 0x0B
*/
ins_dec_r16 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r16(opcode)

    reg := convert_op16_to_reg16(operand)
    dec_r16(cpu, reg)

    return 2
}

/*
    Add the value of r16 onto HL and apply the according flags:    

    Mask: 11001111
    Vars: 00xx1001
        x: r16

    Flags:
        N: Reset
        H: carry_per_bit[11]
        C: carry_per_bit[15]

    Example: 0x09
*/
ins_add_hl_r16 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r16(opcode)
    reg := convert_op16_to_reg16(operand)

    left := read_r16(cpu, .HL)
    right := read_r16(cpu, reg)

    result := left + right
    write_r16(cpu, .HL, result)

    // Set Flags
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, carry_per_bit_16(left, right, 11))
    set_flag(cpu, .C, carry_per_bit_16(left, right, 15))

    return 2
}

/*
    Add the signed imm8 onto SP

    Mask: 11111111
    Vars: 11101000

    Flags:
        Z: Reset
        N: Reset
        H: carry_per_bit[3]
        C: carry_per_bit[7]

    Example: E8
*/
ins_add_sp_e :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    sp := read_r16(cpu, .SP)
    imm8 := fetch_next_u8(cpu)
    offset := i32(i8(imm8))

    result := u16(i32(sp) + offset)
    write_r16(cpu, .SP, result)

    set_flag(cpu, .Z, false)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, carry_per_bit(u8(sp), imm8, 3))
    set_flag(cpu, .C, carry_per_bit(u8(sp), imm8, 7))

    return 4
}
