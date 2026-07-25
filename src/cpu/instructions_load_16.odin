#+private
package cpu

import "core:log"
register_load_instructions_16 :: proc "contextless" (table: ^[256]Instruction) {
    register_instruction(table, ins_ld_r16_m, "LD r16 m", 0b11001111, 0b00000001, 3)
    register_instruction(table, ins_ld_r16mem_a, "LD [r16mem] A", 0b11001111, 0b00000010, 1)
    register_instruction(table, ins_ld_a_r16mem, "LD A [r16mem]", 0b11001111, 0b00001010, 1)
    register_instruction(table, ins_ld_mmem_sp, "LD [imm16] SP", 0xFF, 0x08, 3)
    register_instruction(table, ins_ld_a_mmem, "LD A [imm16]", 0xFF, 0xFA)
    register_instruction(table, ins_ld_mmem_a, "LD [imm16] A", 0xFF, 0xEA)

    register_instruction(table, ins_ld_sp_hl, "LD SP, HL", 0xFF, 0xF9)
    register_instruction(table, ins_ld_hl_sp_e, "LD HL, SP+e", 0xFF, 0xF8)
    register_instruction(table, ins_push_r16, "PUSH r16", 0b11001111, 0b11000101, 1)
    register_instruction(table, ins_pop_r16, "POP r16", 0b11001111, 0b11000001, 1)
}

//==================================================
//              16 BIT Loading operations
//==================================================

/*
    Load the immideate value m into r16
    Mask: 11001111
    Vars: 00xx0001
        x: r16

    Example: 0x11 -> 00010001 = LD DE,imm16
*/
ins_ld_r16_m :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r16(opcode)
    register := convert_op16_to_reg16(operand)

    imm16 := fetch_next_u16(cpu)
    write_r16(cpu, register, imm16)

    return 3;
}

/*
    Load the value of the accumulator into [r16mem]
    Mask: 11001111
    Vars: 00xx0010
        x: r16mem

    Example: 0x02 -> 00000010 = LD [BC], A
*/
ins_ld_r16mem_a :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r16_mem(opcode)
    value := read_r8(cpu, .A)

    write_r16mem(cpu, operand, value)
    return 2;
}

/*
    Load the value of [r16mem] into the accumulator
    Mask: 11001111
    Vars: 00xx1010
        x: r16mem

    Example: 0x1A -> 00011010 = LD A, [DE]
*/
ins_ld_a_r16mem :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r16_mem(opcode)
    value := read_r16mem(cpu, operand)

    write_r8(cpu, .A, value)
    return 2;
}

/*
    Load the value of sp into [immediate 16 bit address]
    Mask: 11111111
    Vars: 00001000

    Example: 0x08 -> 00001000 = LD [imm16], SP
*/
ins_ld_mmem_sp :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    address := fetch_next_u16(cpu)
    sp := read_r16(cpu, .SP)

    cpu.bus.write(cpu.bus.ctx, address, u8(sp & 0xFF))
    cpu.bus.write(cpu.bus.ctx, address + 1, u8(sp >> 8))
    return 5;
}

/*
    Load the value of A into the address specified by imm16
    Mask: 11111111
    Vars: 11101010 -> 0xEA
    
    Flags: -

    Example: 0xEA
*/
ins_ld_mmem_a :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    value := read_r8(cpu, .A)
    addr := fetch_next_u16(cpu)

    cpu.bus.write(cpu.bus.ctx, addr, value)
    return 4
}

/*
    Load the value at the address specified by imm16 into A
    Mask: 11111111
    Vars: 11111101 -> 0xFA
    
    Flags: -

    Example: 0xFA
*/
ins_ld_a_mmem :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    addr := fetch_next_u16(cpu)
    value := cpu.bus.read(cpu.bus.ctx, addr)

    write_r8(cpu, .A, value)
    return 4
}

/*
    Load to sp the data in HL
    Mask: 0xFF
    Vars: 0xF9
    
    Flags: -

    Example: 0xF9
*/
ins_ld_sp_hl :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    value := read_r16(cpu, .HL)
    write_r16(cpu, .SP, value)
    return 1
}

/*
    Load to HL, the data in SP + signed(imm8)
    Mask: 0xFF
    Vars: 0xF8
    
    Flags:
        Z: Reset
        N: Reset
        H: carry_per_bit[3]
        C: carry_per_bit[7]

    Length: 2

    Example: 0xF8
*/
ins_ld_hl_sp_e :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    imm8 := fetch_next_u8(cpu)

    sp := read_r16(cpu, .SP)

    value := i32(sp) + i32(i8(imm8))

    log.infof("%04x + %04x = %04x", i32(sp), i32(imm8), value)
    log.infof("%d + %d = %d", i32(sp), i32(imm8), value)

    write_r16(cpu, .HL, u16(value))

    set_flag(cpu, .Z, false)
    set_flag(cpu, .N, false)
    set_flag(cpu, .H, carry_per_bit_16(sp, u16(imm8), 3))
    set_flag(cpu, .C, carry_per_bit_16(sp, u16(imm8), 7))

    return 3
}

/*
    Decrement SP and write to [SP] the value at r16
    Mask: 0b11001111
    Vars: 0b11xx0101
        x: The stack-value source
    
    Flags: -
    Length: 1

    Example: 0xC5
*/
ins_push_r16 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r16stk(opcode)
    reg := convert_op16stk_to_reg16(operand)

    value := read_r16(cpu, reg)

    dec_r16(cpu, .SP, 2)
    address := read_r16(cpu, .SP)
    bus_write_u16(cpu.bus, address, value)
    return 4
}

/*
    Pop the value of [SP] into r16 and increment SP
    Mask: 0b11001111
    Vars: 0b11xx0001
        x: The stack-value source
    
    Flags: -
    Length: 1

    Example: 0xC1
*/
ins_pop_r16 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r16stk(opcode)
    reg := convert_op16stk_to_reg16(operand)

    address := read_r16(cpu, .SP)
    value := bus_read_u16(cpu.bus, address)
    write_r16(cpu, reg, value)
    inc_r16(cpu, .SP, 2)

    return 3
}