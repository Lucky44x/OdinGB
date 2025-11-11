#+private
#+feature dynamic-literals
package sm83

import "base:builtin"
import "core:fmt"
import "../mmu"

/*
    registers all MISC-Instructions

    ONLY USE ONCE AT STARTUP
*/
register_misc_instructions :: proc() {
    register_instruction("10100xxx", Instruction{ handler=halt, length=1, name="HALT"})
    register_instruction("10100xxx", Instruction{ handler=stop, length=1, name="STOP"})
    register_instruction("10100xxx", Instruction{ handler=di, length=1, name="DI"})
    register_instruction("10100xxx", Instruction{ handler=ei, length=1, name="EI"})
    register_instruction("10100xxx", Instruction{ handler=nop, length=1, name="NOP"})
}

/*
    HALT Instruction
    when IME set:
        resumes after HALT instruction once interrupt has been serviced
    when IME is not set, no interrupts pending:
        As soon as Interrupt becomes pending, CPU resumes execution,
        handler Interrupt-does not get called
    when IMME is not set, some Interrupt is pending:
        CPU continues after HALT, but byte after HALT is read twice

    opc: 0b01110110 0x76
    dur: 1 cycle
    len: 1 byte
    flg: -
*/
halt :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    STOP Instruction

    opc: 0b10100xxx / var
    dur: 1 cycle
    len: 1 byte
    flg: -
*/
stop :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    DI Instruction

    opc: 0b11110011 / 0xF3
    dur: 1 cycle
    len: 1 byte
    flg: -
*/
di :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    EI Instruction

    opc: 0b11111011 / 0xFB
    dur: 1 cycle
    len: 1 byte
    flg: -
*/
ei :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    NOP Instruction

    opc: 0b00000000 / 0x00
    dur: 1 cycle
    len: 1 byte
    flg: -
*/
nop :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 1
}