#+private
package cpu

register_control_instructions :: proc "contextless" (table: ^[256]Instruction) {
    register_instruction(table, ins_jmp_hl, "JMP HL", 0xFF, 0xE9, allow_override=false)
    register_instruction(table, ins_jmp_m, "JMP m", 0b11100110, 0b11000010, 3)
    register_instruction(table, ins_call_m, "CALL m", 0b11100110, 0b11000100, 3)
    register_instruction(table, ins_jr_e, "JR e", 0b11000111, 0b00000000)
    register_instruction(table, ins_ret, "RET", 0b11100110, 0b11000000)
    register_instruction(table, ins_rst, "RST n", 0b11000111, 0b11000111)
    register_instruction(table, ins_reti, "RETI", 0xFF, 0xD9, allow_override=false)
}

//==================================================
//              Control-Flow operations
//==================================================

/*
    Jumps to the position stored in HL unconditionally
    Mask: 0xFF
    Vars: 0xE9

    Flags: -

    Example: 0xE9
*/
ins_jmp_hl :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    address := read_r16(cpu, .HL)
    write_r16(cpu, .PC, address)
    return 1
}

/*
    Jumps to the immediate position (conditional when y = 1)
    Mask: 0b11100110
    Vars: 0b110xx01y
        x: condition
        y: 1 -> unconditional, 0 -> conditional

    Flags: -

    Example:
        Non-Conditional: 0xC3
        Conditional: 0xC2
*/
ins_jmp_m :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    is_conditional := opcode & 1 == 0
    address := fetch_next_u16(cpu)
    
    jmp := true
    if is_conditional do jmp = resolve_condition(cpu, decode_condition(opcode))

    if !jmp do return 3
    write_r16(cpu, .PC, address)

    return 4
}

/*
    Calls the function at the address of imm16
    Mask: 0b11100110
    Vars: 0b110xx10y
        x: condition
        y: 1 -> unconditional, 0 -> conditional

    Flags: -

    Example:
        Non-Conditional: 0xCD
        Conditional: 0xC4
*/
ins_call_m :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    is_conditional := opcode & 1 == 0
    address := fetch_next_u16(cpu)
    
    jmp := true
    if is_conditional do jmp = resolve_condition(cpu, decode_condition(opcode))

    if !jmp do return 3
    stack_push_SP(cpu, read_r16(cpu, .PC))
    write_r16(cpu, .PC, address)
    return 6
}

/*
    Jump to a relative offset from the current Programm Pointer
    Mask: 0b11000111
    Vars: 0b00yxx000
        x: condition
        y: 1 -> unconditional, 0 -> conditional

    Flags: -

    Example:
        Non-Conditional: 0x18
        Conditional: 0x20
*/
ins_jr_e :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    is_conditional := opcode & 0x20 != 0
    offset := i32(i8(fetch_next_u8(cpu)))

    jmp := true
    if is_conditional do jmp = resolve_condition(cpu, decode_condition(opcode))
    if !jmp do return 2

    pc := i32(read_r16(cpu, .PC)) + offset

    write_r16(cpu, .PC, u16(pc))
    return 3
}

/*
    Returns to the last position on the stack
    Mask: 0b11100110
    Vars: 0b110xx00y
        x: condition
        y: 1 -> unconditional, 0 -> conditional

    Flags: -

    Example:
        Non-Conditional: C9
        Conditional: C0
*/
ins_ret :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    is_conditional := opcode & 1 == 0

    jmp := true
    if is_conditional do jmp = resolve_condition(cpu, decode_condition(opcode))
    if !jmp do return 2

    address := stack_pop_SP(cpu)
    write_r16(cpu, .PC, address)

    return is_conditional ? 5 : 4
}

/*
    Returns to the last position on the stack
    Mask: 0b11000111
    Vars: 0b11xxx111
        x: reset vector

    Flags: -

    Example: DF
*/
ins_rst :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    vec := decode_bits(opcode, 3, 3) * 8
    stack_push_SP(cpu, read_r16(cpu, .PC))
    write_r16(cpu, .PC, u16(vec))
    return 4
}

/*
    Returns from a function, Enables interrupts by setting IME=1
    Mask: 0xFF
    Vars: 0xD9

    Flags: -

    Example: D9
*/
ins_reti :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    addr := stack_pop_SP(cpu)
    write_r16(cpu, .PC, addr)
    // Enables Interrupts
    cpu.ime = true
    return 4
}
