#+private
package cpu

register_load_instructions :: proc "contextless" (table: ^[256]Instruction) {
    register_instruction(table, ins_ld_r8_r8, "LD r8 r8", 0b11000000, 0b01000000, 1)
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

    return 1;
}

//==================================================
//              16 BIT Loading operations
//==================================================

/*
    Load the immideate value m into r16
    Mask: 11001111
    Vars: 00xx0000
        x: r16
*/
ins_ld_r16_m :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    return 0;
}

/*
    Load the value of the accumulator into [r16mem]
    Mask: 11001111
    Vars: 00xx0010
        x: r16mem
*/
ins_ld_r16mem_a :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    return 0;
}

/*
    Load the value of [r16mem] into the accumulator
    Mask: 11001111
    Vars: 00xx1010
        x: r16mem
*/
ins_ld_a_r16mem :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    return 0;
}

/*
    Load the value of [imm16] into the register sp
    Mask: 11111111
    Vars: 00001000
*/
ins_ld_mmem_sp :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    return 0;
}