#+private
#+feature dynamic-literals
package sm83

import "base:builtin"
import "core:fmt"
import "../mmu"

/*
    registers all 8-bit arithmetic-instructions

    ONLY USE ONCE AT STARTUP
*/
register_arith16_instructions :: proc() {
    register_instruction("00xx0011", Instruction{ handler=inc_r16, length=1, name="INC r16"})
    register_instruction("00xx1011", Instruction{ handler=dec_r16, length=1, name="DEC r16"})
    register_instruction("00xx1001", Instruction{ handler=add_HL_r16, length=1, name="ADD HL r16"})
    register_instruction(0xE8, Instruction{ handler=add_SP_e, length=2, name="ADD SP e"})
}

/*
    Increment r16

    opc: 0b00xx0011 / var
    dur: 2 cycle
    len: 1 byte
    flg: -
*/
inc_r16 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    reg := R16_IDX[ins.x]
    add_register(ctx, reg, 1)
    return 2
}

/*
    Decrement r16

    opc: 0b00xx1011 / var
    dur: 2 cycle
    len: 1 byte
    flg: -
*/
dec_r16 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    reg := R16_IDX[ins.x]
    add_register(ctx, reg, -1)
    return 2
}

/*
    Add to HL, the value of r16

    opc: 0b00xx1001 / var
    dur: 2 cycle
    len: 1 byte
    flg: N = 0, H = carry_per_bit[11], C = carry_per_bit[15]
*/
add_HL_r16 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    reg := R16_IDX[ins.x]
    hl := get_register(ctx, REG16.HL)
    val := get_register(ctx, reg)
    result, z, hc, c := add_nums_flags(hl, val)

    set_flag(ctx, FLAGS.SUB, 0x00)
    set_flag(ctx, FLAGS.HCARRY, hc)
    set_flag(ctx, FLAGS.CARRY, z)

    set_register(ctx, REG16.HL, result)
    return 2
}

/*
    Add to SP, the signed 8-Bit value e

    opc: 0b11101000 / 0xE8
    dur: 4 cycle
    len: 2 byte
    flg: Z = 0, N = 0, H = carry_per_bit[3], C = carry_per_bit[7]
*/
add_SP_e :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    val := transmute(i8)ins.opbytes[1]
    sp := i32(get_register(ctx, REG16.SP))
    sum := sp + i32(val)
    set_register(ctx, REG16.SP, u16(sum))
    c := bool_to_u8(sum > 0xFFFF);
    hc := bool_to_u8(((i32(val) & 0x0FFF) + (sp & 0x0FFF)) > 0x0FFF);

    set_flag(ctx, FLAGS.ZERO, 0)
    set_flag(ctx, FLAGS.SUB, 0x00)
    set_flag(ctx, FLAGS.HCARRY, hc)
    set_flag(ctx, FLAGS.CARRY, c)
    return 0
}