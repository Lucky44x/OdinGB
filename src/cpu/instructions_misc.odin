#+private
package cpu

register_misc_instructions :: proc "contextless" (table: ^[256]Instruction) {
    register_instruction(table, ins_nop, "NOP", 0xFF, 0x00, allow_override = false)
    register_instruction(table, ins_stop, "STP", 0xFF, 0x10, allow_override = false)
    register_instruction(table, ins_halt, "HALT", 0xFF, 0x76, allow_override = false)
    register_instruction(table, ins_ei, "EI", 0xFF, 0xFB, allow_override = false)
    register_instruction(table, ins_di, "DI", 0xFF, 0xF3, allow_override = false)
}

//==================================================
//              MISC operations
//==================================================

/*
    Noop - No Operation
    Mask: 0xFF
    Vars: 0x00

    Flags: -

    Example: 0x00
*/
ins_nop :: proc(cpu: ^CPU, opcode: u8) -> u8 { return 1 }

/*
    Stops system and main clocks
    Mask: 0xFF
    Vars: 0x10

    Flags: -

    Example: 0x10
*/
ins_stop :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    //_ = fetch_next_u8(cpu)
    cpu.state = .Stopped
    return 1
}

/*
    Stops system and main clocks
    Mask: 0xFF
    Vars: 0x76

    Flags: -

    Example: 0x76
*/
ins_halt :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    cpu.state = .Halted
    return 1
}

/*
    Disables interrupts and cancelles any scheduled effects of EI
    Mask: 0xFF
    Vars: 0xF3

    Flags: -

    Example: 0xF3
*/
ins_di :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    cpu.ime = false
    cpu.ime_enable_pending = 0
    return 1
}

/*
    Enables interrupts
    Mask: 0xFF
    Vars: 0xFB

    Flags: -

    Example: 0xFB
*/
ins_ei :: proc(cpu: ^CPU, opcode: u8) -> u8 {
    cpu.ime_enable_pending = 2
    return 1
}