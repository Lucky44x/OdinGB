#+private
#+feature dynamic-literals
package sm83

import "core:flags"
import "base:builtin"
import "core:fmt"
import "../mmu"

/*
    registers all 8-bit arithmetic-instructions

    ONLY USE ONCE AT STARTUP
*/
register_arith8_instructions :: proc() {
    register_instruction("10000xxx", Instruction{ handler=add_A_r8, length=1, name="ADD A r8"})
    register_instruction("10001xxx", Instruction{ handler=adc_A_r8, length=1, name="ADC A r8"})
    register_instruction("10010xxx", Instruction{ handler=sub_A_r8, length=1, name="SUB A r8"})
    register_instruction("10011xxx", Instruction{ handler=sbc_A_r8, length=1, name="SBC A r8"})
    register_instruction("10111xxx", Instruction{ handler=cp_A_r8, length=1, name="CP A r8"})
    register_instruction("00xxx100", Instruction{handler=inc_r8, length=1, name="INC r8"})
    register_instruction("00xxx101", Instruction{handler=inc_r8, length=1, name="DEC r8"})

    register_instruction(0x86, Instruction{ handler=add_A_HLmem, length=1, name="ADD A [HL]"})
    register_instruction(0xC6, Instruction{ handler=add_A_imm8, length=2, name="ADD A imm8"})

    register_instruction(0x8E, Instruction{ handler=adc_A_HLmem, length=1, name="ADC A [HL]"})
    register_instruction(0xCE, Instruction{ handler=adc_A_imm8, length=2, name="ADC A imm8"})

    register_instruction(0x96, Instruction{ handler=sub_A_HLmem, length=1, name="SUB A [HL]"})
    register_instruction(0xD6, Instruction{ handler=sub_A_imm8, length=2, name="SUB A imm8"})

    register_instruction(0x9E, Instruction{ handler=sbc_A_HLmem, length=1, name="SBC A [HL]"})
    register_instruction(0xDE, Instruction{ handler=sbc_A_imm8, length=2, name="SBC A imm8"})

    register_instruction(0xBE, Instruction{ handler=cp_A_HLmem, length=1, name="CP A [HL]"})
    register_instruction(0xFE, Instruction{ handler=cp_A_imm8, length=2, name="CP A imm8"})

    register_instruction(0x34, Instruction{handler=inc_HLmem, length=1, name="INC [HL]"})

    register_instruction(0x35, Instruction{handler=inc_HLmem, length=1, name="DEc [HL]"})

    register_instruction(0x3F, Instruction{handler=ccf, length=1, name="CCF"})
    register_instruction(0x37, Instruction{handler=scf, length=1, name="SCF"})
    register_instruction(0x27, Instruction{handler=daa, length=1, name="DAA"})
    register_instruction(0x2F, Instruction{handler=daa, length=1, name="CPL"})
}

/*
    Add to A, the data in r8

    opc: 0b10000xxx / var
    dur: 1 cycle
    len: 1 byte
    flg: Z = A==0, N = 0, H = carry_per_bit[3], C = carry_per_bit[7]
*/
add_A_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Add to A, the data in [HL]

    opc: 0b10000110 / 0x86
    dur: 1 cycle
    len: 2 byte
    flg: Z = A==0, N = 0, H = carry_per_bit[3], C = carry_per_bit[7]
*/
add_A_HLmem :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Add to A, the data in imm8

    opc: 0b11000110 / 0xC6
    dur: 2 cycle
    len: 2 byte
    flg: Z = A==0, N = 0, H = carry_per_bit[3], C = carry_per_bit[7]
*/
add_A_imm8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Add to A, the data in r8 and the Carry flag

    opc: 0b10001xxx / var
    dur: 1 cycle
    len: 1 byte
    flg: Z = A==0, N = 0, H = carry_per_bit[3], C = carry_per_bit[7]
*/
adc_A_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Add to A, the data in [HL] and the Carry flag

    opc: 0b10001110 / 0x8E
    dur: 2 cycle
    len: 1 byte
    flg: Z = A==0, N = 0, H = carry_per_bit[3], C = carry_per_bit[7]
*/
adc_A_HLmem :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Add to A, the data in imm8 and the Carry flag

    opc: 0b11001110 / 0xCE
    dur: 2 cycle
    len: 2 byte
    flg: Z = A==0, N = 0, H = carry_per_bit[3], C = carry_per_bit[7]
*/
adc_A_imm8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Subtract from A, the data in r8

    opc: 0b10010xxx / var
    dur: 1 cycle
    len: 1 byte
    flg: Z = A==0, N = 0, H = carry_per_bit[3], C = carry_per_bit[7]
*/
sub_A_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Subtract from A, the data in [HL]

    opc: 0b10010110 / 0x96
    dur: 2 cycle
    len: 1 byte
    flg: Z = A==0, N = 0, H = carry_per_bit[3], C = carry_per_bit[7]
*/
sub_A_HLmem :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Subtract from A, the data in imm8

    opc: 0b11010110 / 0xD6
    dur: 1 cycle
    len: 2 byte
    flg: Z = A==0, N = 0, H = carry_per_bit[3], C = carry_per_bit[7]
*/
sub_A_imm8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Subtract from A, the data in r8 and the Carry flag

    opc: 0b10011xxx /var
    dur: 1 cycle
    len: 1 byte
    flg: Z = A==0, N = 0, H = carry_per_bit[3], C = carry_per_bit[7]
*/
sbc_A_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Subtract from A, the data in [HL] and the Carry flag

    opc: 0b10011110 / 0x9E
    dur: 2 cycle
    len: 1 byte
    flg: Z = A==0, N = 0, H = carry_per_bit[3], C = carry_per_bit[7]
*/
sbc_A_HLmem :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Subtract from A, the data in imm8 and the Carry flag

    opc: 0b11011110 / 0xDE
    dur: 2 cycle
    len: 2 byte
    flg: Z = A==0, N = 0, H = carry_per_bit[3], C = carry_per_bit[7]
*/
sbc_A_imm8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Compare A with r8 and update flags, but discard result

    opc: 0b10111xxx / var
    dur: 2 cycle
    len: 1 byte
    flg: Z = A-r8 == 0, N = 1, H = carry_per_bit[3], C = carry_per_bit[7]
*/
cp_A_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Compare A with r8 and update flags, but discard result

    opc: 0b10111110 / 0xBE
    dur: 2 cycle
    len: 1 byte
    flg: Z = A-[HL] == 0, N = 1, H = carry_per_bit[3], C = carry_per_bit[7]
*/
cp_A_HLmem :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Compare A with imm8 and update flags, but discard result

    opc: 0b11111110 / 0xFE
    dur: 2 cycle
    len: 2 byte
    flg: Z = A-imm8 == 0, N = 1, H = carry_per_bit[3], C = carry_per_bit[7]
*/
cp_A_imm8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Increment Register r8

    opc: 0b00xxx100 / var
    dur: 1 cycle
    len: 1 byte
    flg: Z = r8==0, N = 0, H = carry_per_bit[3]
*/
inc_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Increment [HL]

    opc: 0b00110100 / 0x34
    dur: 3 cycle
    len: 1 byte
    flg: Z = [HL]==0, N = 0, H = carry_per_bit[3]
*/
inc_HLmem :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Decrement r8

    opc: 0b00xxx101 / var
    dur: 1 cycle
    len: 1 byte
    flg: Z = [HL]==0, N = 1, H = carry_per_bit[3]
*/
dec_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    Decrement [HL]

    opc: 0b00110101 / 0x35
    dur: 3 cycle
    len: 1 byte
    flg: Z = [HL]==0, N = 1, H = carry_per_bit[3]
*/
dec_HLmem :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    CCF Complement carry flag

    opc: 0b00111111 / 0x3F
    dur: 1 cycle
    len: 1 byte
    flg: N = 0, H = 0, C = !C
*/
ccf :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    state := get_flag(ctx, FLAGS.CARRY)
    set_flag(ctx, FLAGS.CARRY, 0x01 - state)    // when flag active: 0x01 - 0x01 = 0x00, when not: 0x01 - 0x00 -> 0x01
    set_flag(ctx, FLAGS.SUB, 0x00)
    set_flag(ctx, FLAGS.HCARRY, 0x00)
    return 1
}

/*
    SCF set carry flag

    opc: 0b00110111 / 0x37
    dur: 1 cycle
    len: 1 byte
    flg: N = 0, H = 0, C = 1
*/
scf :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    set_flag(ctx, FLAGS.CARRY, 0x01)
    set_flag(ctx, FLAGS.HCARRY, 0x00)
    set_flag(ctx, FLAGS.SUB, 0x01)
    return 1
}

/*
    DAA Decimal adjust A

    opc: 0b00100111 / 0x27
    dur: 1 cycle
    len: 1 byte
    flg: Z = ?, H = 0, C = ?
*/
daa :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    CPL Complement A

    opc: 0b00101111 / 0x2F
    dur: 1 cycle
    len: 1 byte
    flg: N = 1, H = 1
*/
cpl :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    val := get_register(ctx, REG8.A)
    val = ~val
    set_register(ctx, REG8.A, val)
    set_flag(ctx, FLAGS.SUB, 0x01)
    set_flag(ctx, FLAGS.HCARRY, 0x01)
    return 1
}