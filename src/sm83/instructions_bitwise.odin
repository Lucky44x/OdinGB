#+private
#+feature dynamic-literals
package sm83

import "../mmu"

/*
    registers all 8-bit arithmetic-instructions

    ONLY USE ONCE AT STARTUP
*/
register_bitwise_instructions :: proc() {
    register_instruction("10100xxx", Instruction{ handler=and_A_r8, length=1, name="AND A r8"})
    register_instruction("10101xxx", Instruction{ handler=xor_A_r8, length=1, name="XOR A r8"})
    register_instruction("10110xxx", Instruction{ handler=or_A_r8, length=1, name="OR A r8"})

    register_instruction(0xE6, Instruction{ handler=and_A_imm8, length=2, name="AND A imm8"})

    register_instruction(0xF6, Instruction{ handler=or_A_imm8, length=2, name="OR A imm8"})

    register_instruction(0xEE, Instruction{ handler=xor_A_imm8, length=2, name="XOR A imm8"})
}

/*
    Bitwise AND between A and r8

    opc: 0b10100xxx / var
    dur: 1 cycle
    len: 1 byte
    flg: Z = A == 0, N = 0, H = 1, C = 0
*/
and_A_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    aval: u8 = get_register(ctx, REG8.A)
    reg := R8_IDX[ins.b]
    
    val: u8 = 0
    if reg == .NONE do val = mmu.get(bus, u8, get_register(ctx, REG16.HL))
    else do val = get_register(ctx, reg)

    aval &= val

    set_flag(ctx, FLAGS.ZERO, aval == 0 ? 0x01 : 0x00)
    set_flag(ctx, FLAGS.SUB, 0x00)
    set_flag(ctx, FLAGS.HCARRY, 0x01)
    set_flag(ctx, FLAGS.CARRY, 0x00)

    set_register(ctx, REG8.A, aval)

    return reg == .NONE ? 2 : 1
}

/*
    Bitwise AND between A and imm8

    opc: 0b11100110 / 0xE6
    dur: 2 cycle
    len: 2 byte
    flg: Z = A == 0, N = 0, H = 1, C = 0
*/
and_A_imm8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    aval: u8 = get_register(ctx, REG8.A)
    val: u8 = ins.opbytes[1]

    aval &= val

    set_register(ctx, REG8.A, aval)

    set_flag(ctx, FLAGS.ZERO, aval == 0 ? 0x01 : 0x00)
    set_flag(ctx, FLAGS.SUB, 0x00)
    set_flag(ctx, FLAGS.HCARRY, 0x01)
    set_flag(ctx, FLAGS.CARRY, 0x00)

    return 2
}

/*
    Bitwise OR between A and r8

    opc: 0b10110xxx / var
    dur: 1 cycle
    len: 1 byte
    flg: Z = A == 0, N = 0, H = 0, C = 0
*/
or_A_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    aval: u8 = get_register(ctx, REG8.A)
    reg := R8_IDX[ins.b]
    
    val: u8 = 0
    if reg == .NONE do val = mmu.get(bus, u8, get_register(ctx, REG16.HL))
    else do val = get_register(ctx, reg)
    
    aval |= val

    set_flag(ctx, FLAGS.ZERO, aval == 0 ? 0x01 : 0x00)
    set_flag(ctx, FLAGS.SUB, 0x00)
    set_flag(ctx, FLAGS.HCARRY, 0x00)
    set_flag(ctx, FLAGS.CARRY, 0x00)

    set_register(ctx, REG8.A, aval)

    return reg == .NONE ? 2 : 1
}

/*
    Bitwise OR between A and imm8

    opc: 0b11110110 / 0xF6
    dur: 2 cycle
    len: 2 byte
    flg: Z = A == 0, N = 0, H = 0, C = 0
*/
or_A_imm8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    aval: u8 = get_register(ctx, REG8.A)
    val: u8 = ins.opbytes[1]

    aval |= val

    set_register(ctx, REG8.A, aval)

    set_flag(ctx, FLAGS.ZERO, aval == 0 ? 0x01 : 0x00)
    set_flag(ctx, FLAGS.SUB, 0x00)
    set_flag(ctx, FLAGS.HCARRY, 0x00)
    set_flag(ctx, FLAGS.CARRY, 0x00)

    return 2
}

/*
    Bitwise XOR between A and r8

    opc: 0b10101xxx / var
    dur: 1 cycle
    len: 1 byte
    flg: Z = A == 0, N = 0, H = 0, C = 0
*/
xor_A_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    aval: u8 = get_register(ctx, REG8.A)
    reg := R8_IDX[ins.b]
    
    val: u8 = 0
    if reg == .NONE do val = mmu.get(bus, u8, get_register(ctx, REG16.HL))
    else do val = get_register(ctx, reg)
    
    aval ~= val

    set_flag(ctx, FLAGS.ZERO, aval == 0 ? 0x01 : 0x00)
    set_flag(ctx, FLAGS.SUB, 0x00)
    set_flag(ctx, FLAGS.HCARRY, 0x00)
    set_flag(ctx, FLAGS.CARRY, 0x00)

    set_register(ctx, REG8.A, aval)

    return reg == .NONE ? 2 : 1
}

/*
    Bitwise AND between A and imm8

    opc: 0b11101110 / 0xEE
    dur: 2 cycle
    len: 2 byte
    flg: Z = A == 0, N = 0, H = 0, C = 0
*/
xor_A_imm8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    aval: u8 = get_register(ctx, REG8.A)
    val: u8 = ins.opbytes[1]

    aval ~= val

    set_register(ctx, REG8.A, aval)

    set_flag(ctx, FLAGS.ZERO, aval == 0 ? 0x01 : 0x00)
    set_flag(ctx, FLAGS.SUB, 0x00)
    set_flag(ctx, FLAGS.HCARRY, 0x00)
    set_flag(ctx, FLAGS.CARRY, 0x00)

    return 2
}