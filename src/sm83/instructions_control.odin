#+private
#+feature dynamic-literals
package sm83

import "base:builtin"
import "core:fmt"
import "../mmu"

/*
    registers all Control-Flow-Instructions

    ONLY USE ONCE AT STARTUP
*/
register_control_instructions :: proc() {
    register_instruction("110xx010", Instruction{ handler=jp_CC_imm16, length=3, name="JP CC imm16"})
    register_instruction("001xx000", Instruction{ handler=jp_CC_e, length=2, name="JP CC e"})
    register_instruction("110xx100", Instruction{ handler=call_CC_imm16, length=3, name="CALL CC imm16"})
    register_instruction("110xx000", Instruction{ handler=ret_CC, length=1, name="RET CC"})
    register_instruction("11xxx111", Instruction{ handler=rst_n, length=1, name="RST n"})

    register_instruction(0xC3, Instruction{ handler=jp_imm16, length=3, name="JP imm16"})
    register_instruction(0xE9, Instruction{ handler=jp_HL, length=1, name="JP HL"})
    register_instruction(0x18, Instruction{ handler=jp_e, length=2, name="JP e"})
    register_instruction(0xCD, Instruction{ handler=call_imm16, length=3, name="CALL imm16"})
    register_instruction(0xC9, Instruction{ handler=ret, length=1, name="RET"})
    register_instruction(0xD9, Instruction{ handler=retI, length=1, name="RETI"})
}

/*
    Jump imm16

    opc: 0b110000011 / 0xC3
    dur: 4 cycle
    len: 3 byte
    flg: -
*/
jp_imm16 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    addr := bu16(ins.opbytes)
    set_register(ctx, REG16.PC, addr)
    return 4
}

/*
    Jump to HL

    opc: 0b11101001 / 0xE9
    dur: 1 cycle
    len: 1 byte
    flg: -
*/
jp_HL :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    set_register(ctx, REG16.PC, get_register(ctx, REG16.HL))
    return 1
}

/*
    Jump to imm16 Conditional

    opc: 0b110xx010 / var
    dur: 4 cycle (CC true) 3 (CC false)
    len: 3 byte
    flg: -
*/
jp_CC_imm16 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    cond := (ins.a >> 1) // right-shift a by one to get the marked area
    if !(eval_condition(ctx, cond)) do return 3
    
    //fmt.printfln("Jumping...")
    return jp_imm16(ctx, bus, ins)
}

/*
    Jump to e (Relational jump)

    opc: 0b00011000 / 0x18
    dur: 3 cycle
    len: 2 byte
    flg: -
*/
jp_e :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    e := transmute(i8) ins.opbytes[1]
    ival: i16 = i16(get_register(ctx, REG16.SP)) + i16(e)
    set_register(ctx, REG16.SP, u16(ival))
    return 3
}

/*
    Jump to e (Relational jump) Conditional

    opc: 0b001xx000 / var
    dur: 3 (CC=true) 2 (CC=true) cycle
    len: 2 byte
    flg: -
*/
jp_CC_e :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    cond := (ins.a >> 1) // right-shift a by one to get the marked area
    if !eval_condition(ctx, cond) do return 3
    return jp_e(ctx, bus, ins)
}

/*
    Call a function

    opc: 0b11001101 / 0xCD
    dur: 6 cycle
    len: 3 byte
    flg: -
*/
call_imm16 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    addr := bu16(ins.opbytes)
    push_stack(ctx, bus, get_register(ctx, REG16.PC))
    set_register(ctx, REG16.PC, addr)
    return 6
}

/*
    Call a function Conditional

    opc: 0b110xx100 / var
    dur: 6 cycle (CC true) 3 (CC false)
    len: 3 byte
    flg: -
*/
call_CC_imm16 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    cond := (ins.a >> 1) // right-shift a by one to get the marked area
    if !eval_condition(ctx, cond) do return 3
    return call_imm16(ctx, bus, ins)
}

/*
    Return from a function

    opc: 0b11001001 / 0xC9
    dur: 4 cycle
    len: 1 byte
    flg: -
*/
ret :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    addr := pop_stack(ctx, bus)
    set_register(ctx, REG16.PC, addr)
    return 4
}

/*
    return from a funnction Conditional

    opc: 0b110xx000 / var
    dur: 5 cycle  (CC=true) 2 (CC=false)
    len: 1 byte
    flg: -
*/
ret_CC :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    cond := (ins.a >> 1) // right-shift a by one to get the marked area
    if !eval_condition(ctx, cond) do return 2
    return ret(ctx, bus, ins) + 1
}

/*
    return from interrupt handler

    opc: 0b11011001 / 0xD9
    dur: 4 cycle
    len: 1 byte
    flg: -
*/
retI :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    addr := pop_stack(ctx, bus)
    set_register(ctx, REG16.PC, addr)
    set_register(ctx, REG8.IME, 0x01)   // Set IME = 1
    return 4
}

/*
    Restart

    opc: 0b11xxx111
    dur: 4 cycle
    len: 1 byte
    flg: -
*/
rst_n :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    vec := u16(ins.a << 3) * 8
    push_stack(ctx, bus, get_register(ctx, REG16.SP))
    set_register(ctx, REG16.PC, vec)
    return 4
}