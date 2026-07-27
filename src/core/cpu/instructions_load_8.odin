#+private
package cpu

register_load_instructions_8 :: proc "contextless" (table: ^[256]Instruction) {
    register_instruction(table, ins_ld_r8_r8, "LD r8 r8", 0b11000000, 0b01000000, 1)
    register_instruction(table, ins_ld_r8_imm8, "LD r8 imm8", 0b11000110, 0b00000110, 2)

    register_instruction(table, ins_ldh_a_mem, "LDH A [C]", 0xFF, 0xF2, 1, allow_override=false)
    register_instruction(table, ins_ldh_a_mem, "LDH A [N]", 0xFF, 0xF0, 2, allow_override=false)
    register_instruction(table, ins_ldh_mem_a, "LDH [C] A", 0xFF, 0xE2, 1, allow_override=false)
    register_instruction(table, ins_ldh_mem_a, "LDH [N] A", 0xFF, 0xE0, 2, allow_override=false)
}

//==================================================
//              8 BIT Loading operations
//==================================================

/*
    Load the value int r8_2 into r8_1
    Mask: 11000000
    Vars: 01xxxyyy
        x: r8_1
        y: r8_2

    Example: 0x41 -> 01000001 = LD B,C

    EXCEPTION: HALT -> 01110110
*/
ins_ld_r8_r8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    srcValue : u8 = 0
    src := decode_r8_src(opcode)
    dst := decode_r8_dst(opcode)

    if src == .mem do srcValue = cpu.bus.read(cpu.bus, read_r16(cpu, .HL))
    else do srcValue = read_r8(cpu, REG_8(src))

    if dst == .mem do cpu.bus.write(cpu.bus, read_r16(cpu, .HL), srcValue)
    else do write_r8(cpu, REG_8(dst), srcValue)

    return (src == .mem || dst == .mem) ? 2 : 1
}

/*
    Load the immediate 8 bit value into the register r8
    Mask: 11000110
    Vars: 00xxx110
        x: r8
    
    Flags: -

    Example: 0x06
*/
ins_ld_r8_imm8 :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    operand := decode_r8_dst(opcode)
    value := fetch_next_u8(cpu)
    
    if operand == .mem do cpu.bus.write(cpu.bus, read_r16(cpu, .HL), value)
    else do write_r8(cpu, REG_8(operand), value)
    
    return operand == .mem ? 3 : 2
}

/*
    Load the value of [0xFF00 + param] to A
    Mask: 11111101
    Vars: 111100x0
        x: 1 -> [c], 0 -> [n]
    
    Flags: -

    Length:
        [c]: 1
        [n]: 2

    Example:
        [c]: F2
        [n]: F0
*/
ins_ldh_a_mem :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    is_imm := opcode == 0xF0

    addr_off: u16
    if is_imm do addr_off = u16(fetch_next_u8(cpu))
    else do addr_off = u16(read_r8(cpu, .C))

    address := 0xFF00 + addr_off
    value := cpu.bus.read(cpu.bus, address)

    write_r8(cpu, .A, value)

    return is_imm ? 3 : 2
}

/*
    Load the value of A to [0xFF00 + param]
    Mask: 11111101
    Vars: 111000x0
        x: 1 -> [c], 0 -> [n]
    
    Flags: -

    Length:
        [c]: 1
        [n]: 2

    Example:
        [c]: E2
        [n]: E0
*/
ins_ldh_mem_a :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    is_imm := opcode == 0xE0

    addr_off: u16
    if is_imm do addr_off = u16(fetch_next_u8(cpu))
    else do addr_off = u16(read_r8(cpu, .C))

    value := read_r8(cpu, .A)
    address := 0xFF00 + addr_off
    
    cpu.bus.write(cpu.bus, address, value)

    return is_imm ? 3 : 2
}
