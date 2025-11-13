#+private
#+feature dynamic-literals
package sm83

import "base:builtin"
import "core:fmt"
import "../mmu"

/*
    NOTE: For these operations, I DID decide to implement them generic, mapping idx 7 for r8 to [hl]

    Also, all of these instructions are 0xCB-prefixed
*/

/*
    registers all MISC-Instructions

    ONLY USE ONCE AT STARTUP
*/
register_shifts_instructions :: proc() {
    register_instruction("00000xxx", Instruction{ handler=rlc_r8, length=2, name="RlC r8"}, true)
    register_instruction("00001xxx", Instruction{ handler=rrc_r8, length=2, name="RRC r8"}, true)

    register_instruction(0x07, Instruction{ handler=rlc_r8, length=1, name="RlCA"})
    register_instruction(0x0F, Instruction{ handler=rrc_r8, length=1, name="RRCA"})

    register_instruction("00010xxx", Instruction{ handler=rl_r8, length=2, name="RL r8"}, true)
    register_instruction("00011xxx", Instruction{ handler=rr_r8, length=2, name="RR r8"}, true)

    register_instruction(0x17, Instruction{ handler=rl_r8, length=1, name="RLA"})
    register_instruction(0x1F, Instruction{ handler=rr_r8, length=1, name="RRA"})
    
    register_instruction("00100xxx", Instruction{ handler=sla_r8, length=2, name="SLA r8"}, true)
    register_instruction("00101xxx", Instruction{ handler=sra_r8, length=2, name="SRA r8"}, true)
    register_instruction("00110xxx", Instruction{ handler=swap_r8, length=2, name="SWAP r8"}, true)
    register_instruction("00111xxx", Instruction{ handler=srl_r8, length=2, name="SRL r8"}, true)

    register_instruction("01xxxxxx", Instruction{ handler=bit_r8, length=2, name="BIT r8"}, true)
    register_instruction("10xxxxxx", Instruction{ handler=res_r8, length=2, name="RES r8"}, true)
    register_instruction("11xxxxxx", Instruction{ handler=set_r8, length=2, name="SET r8"}, true)
}

/*
    Layout note:
    b7 b6 b5 b4 b3 b2 b1
*/

/*
    RRC Rotate left circular
        bits[0] = bits[7]
        bits[7] = bits[6]
        carry = bits[7]

    opc: 0b00000xxx / var
    dur: 2 cycle (reg) / 4 cycles ([hl])
    len: 2 byte
    flg: 
        Z = (r8 == 0), N = 0, H = 0, C = bits[7]
*/
rlc_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    reg := R8_IDX[ins.b]
    val: u8 = 0
    if reg == .NONE do val = mmu.get(bus, u8, get_register(ctx, REG16.HL))
    else do val = get_register(ctx, reg)

    bit7 : u8 = (val >> 7) & 0x01
    val = (val << 1) & 0xFF
    val |= bit7                 // Since we just shifted, this bit will always be 0, thus |= is appropriate
    
    set_flag(ctx, FLAGS.CARRY, bit7)
    set_flag(ctx, FLAGS.ZERO, val == 0x00 ? 0x01 : 0x00)
    set_flag(ctx, FLAGS.SUB, 0)
    set_flag(ctx, FLAGS.HCARRY, 0)

    if reg == .NONE do mmu.put(bus, val, get_register(ctx, REG16.HL))
    else do set_register(ctx, reg, val)

    return reg == .NONE ? 4 : 2
}

/*
    RRC Rotate right circular
        bits[7] = bits[0]
        bits[0] = bits[1]
        carry = bits[0]

    opc: 0b00001xxx / var
    dur: 2 cycle (reg) / 4 cycles ([hl])
    len: 2 byte
    flg: 
        Z = (r8 == 0), N = 0, H = 0, C = bits[0]
*/
rrc_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    reg := R8_IDX[ins.b]
    val: u8 = 0
    if reg == .NONE do val = mmu.get(bus, u8, get_register(ctx, REG16.HL))
    else do val = get_register(ctx, reg)

    bit0 : u8 = val & 0x01
    val = (val >> 1) & 0xFF
    val |= (bit0 << 7)                 // Since we just shifted, this bit will always be 0, thus |= is appropriate
    
    set_flag(ctx, FLAGS.CARRY, bit0)
    set_flag(ctx, FLAGS.ZERO, val == 0x00 ? 0x01 : 0x00)
    set_flag(ctx, FLAGS.SUB, 0)
    set_flag(ctx, FLAGS.HCARRY, 0)

    if reg == .NONE do mmu.put(bus, val, get_register(ctx, REG16.HL))
    else do set_register(ctx, reg, val)

    return reg == .NONE ? 4 : 2
}

/*
    RR Rotate left
        bits[0] = carry
        carry = bits[7]

    opc: 0b00010xxx / var
    dur: 2 cycle (reg) / 4 cycles ([hl])
    len: 2 byte
    flg: 
        Z = (r8 == 0), N = 0, H = 0, C = bits[7]
*/
rl_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    reg := R8_IDX[ins.b]
    val: u8 = 0
    if reg == .NONE do val = mmu.get(bus, u8, get_register(ctx, REG16.HL))
    else do val = get_register(ctx, reg)

    bit7 : u8 = (val >> 7) & 0x01
    val = (val << 1) & 0xFF
    bitMask_0 := (get_flag(ctx, FLAGS.CARRY) & 0x01)
    val |= bitMask_0
    
    set_flag(ctx, FLAGS.CARRY, bit7)
    set_flag(ctx, FLAGS.ZERO, val == 0x00 ? 0x01 : 0x00)
    set_flag(ctx, FLAGS.SUB, 0)
    set_flag(ctx, FLAGS.HCARRY, 0)

    if reg == .NONE do mmu.put(bus, val, get_register(ctx, REG16.HL))
    else do set_register(ctx, reg, val)

    return reg == .NONE ? 4 : 2
}

/*
    RR Rotate right
        bits[7] = carry
        carry = bits[0]

    opc: 0b00011xxx / var
    dur: 2 cycle (reg) / 4 cycles ([hl])
    len: 2 byte
    flg: 
        Z = (r8 == 0), N = 0, H = 0, C = bits[0]
*/
rr_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    reg := R8_IDX[ins.b]
    val: u8 = 0
    if reg == .NONE do val = mmu.get(bus, u8, get_register(ctx, REG16.HL))
    else do val = get_register(ctx, reg)

    bit0 : u8 = val & 0x01
    val = (val >> 1) & 0xFF
    bitMask_0 := (get_flag(ctx, FLAGS.CARRY) & 0x01) << 7
    val |= bitMask_0
    
    set_flag(ctx, FLAGS.CARRY, bit0)
    set_flag(ctx, FLAGS.ZERO, val == 0x00 ? 0x01 : 0x00)
    set_flag(ctx, FLAGS.SUB, 0)
    set_flag(ctx, FLAGS.HCARRY, 0)

    if reg == .NONE do mmu.put(bus, val, get_register(ctx, REG16.HL))
    else do set_register(ctx, reg, val)

    return reg == .NONE ? 4 : 2
}

/*
    SLA Shift left arithmetic
        bits[0] = 0
        bits[7] = bits[6]
        carry = bits[7]

    opc: 0b00100xxx / var
    dur: 2 cycle (reg) / 4 cycle ([hl])
    len: 2 byte
    flg: 
        Z = (r8 == 0), N = 0, H = 0, C = bits[7]
*/
sla_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    reg := R8_IDX[ins.b]
    val: u8 = 0
    if reg == .NONE do val = mmu.get(bus, u8, get_register(ctx, REG16.HL))
    else do val = get_register(ctx, reg)

    bit7 : u8 = (val >> 7) & 0x01
    val = (val << 1) & 0xFF
    
    set_flag(ctx, FLAGS.CARRY, bit7)
    set_flag(ctx, FLAGS.ZERO, val == 0x00 ? 0x01 : 0x00)
    set_flag(ctx, FLAGS.SUB, 0)
    set_flag(ctx, FLAGS.HCARRY, 0)

    if reg == .NONE do mmu.put(bus, val, get_register(ctx, REG16.HL))
    else do set_register(ctx, reg, val)

    return reg == .NONE ? 4 : 2
}

/*
    SRA Shift right arithmetic
        bits[0] = bits[1] etc..
        carry = bits[0]
        bits[7] = bits[7]

    opc: 0b00101xxx / var
    dur: 2 cycle (reg) / 4 cycle ([hl])
    len: 2 byte
    flg: Z = (r8 == 0), N = 0, H = 0, C = bits[0]
*/
sra_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    reg := R8_IDX[ins.b]
    val: u8 = 0
    if reg == .NONE do val = mmu.get(bus, u8, get_register(ctx, REG16.HL))
    else do val = get_register(ctx, reg)

    bit0 : u8 = val & 0x01
    bit7 : u8 = (val & 0x80)

    val = (val >> 1) & 0xFF
    val |= bit7
    
    set_flag(ctx, FLAGS.CARRY, bit0)
    set_flag(ctx, FLAGS.ZERO, val == 0x00 ? 0x01 : 0x00)
    set_flag(ctx, FLAGS.SUB, 0)
    set_flag(ctx, FLAGS.HCARRY, 0)

    if reg == .NONE do mmu.put(bus, val, get_register(ctx, REG16.HL))
    else do set_register(ctx, reg, val)

    return reg == .NONE ? 4 : 2
}

/*
    SWAP Swap the high and low nibble of the 8 bit register

    opc: 0b00110xxx / var
    dur: 2 cycle (reg) / 4 cycle ([hl])
    len: 2 byte
    flg: 
        Z = (r8 == 0), N = 0, H = 0, C = 0
*/
swap_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    reg := R8_IDX[ins.b]
    val: u8 = 0
    if reg == .NONE do val = mmu.get(bus, u8, get_register(ctx, REG16.HL))
    else do val = get_register(ctx, reg)

    hi := (val & 0xF0) >> 4
    lo := (val & 0x0F) << 4
    result := hi | lo

    set_flag(ctx, FLAGS.CARRY, 0)
    set_flag(ctx, FLAGS.ZERO, result == 0x00 ? 0x01 : 0x00)
    set_flag(ctx, FLAGS.SUB, 0)
    set_flag(ctx, FLAGS.HCARRY, 0)

    if reg == .NONE do mmu.put(bus, result, get_register(ctx, REG16.HL))
    else do set_register(ctx, reg, result)

    return reg == .NONE ? 4 : 2
}

/*
    SRL Shift right logical
        bits[7] = 0
        carry = bits[0]

    opc: 0x00111xxx / var
    dur: 2 cycle (reg) / 4 cycle ([hl])
    len: 2 byte
    flg: 
        Z = (r8 == 0), N = 0, H = 0, C = bits[0] (rightmost bit of register)
*/
srl_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    reg := R8_IDX[ins.b]
    val: u8 = 0
    if reg == .NONE do val = mmu.get(bus, u8, get_register(ctx, REG16.HL))
    else do val = get_register(ctx, reg)

    bit0 : u8 = val & 0x01
    val = (val >> 1) & 0xFF
    
    set_flag(ctx, FLAGS.CARRY, bit0)
    set_flag(ctx, FLAGS.ZERO, val == 0x00 ? 0x01 : 0x00)
    set_flag(ctx, FLAGS.SUB, 0)
    set_flag(ctx, FLAGS.HCARRY, 0)

    if reg == .NONE do mmu.put(bus, val, get_register(ctx, REG16.HL))
    else do set_register(ctx, reg, val)

    return reg == .NONE ? 4 : 2
}

/*
    BIT, test bit a of r8[b]

    opc: 0b01xxxxxx / var
    dur: 2 cycle (reg) / 3 cycles ([hl])
    len: 2 byte
    flg: 
        Z = (bits[a] == 0), N = 0, H = 1
*/
bit_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    reg := R8_IDX[ins.b]
    val: u8 = 0
    if reg == .NONE do val = mmu.get(bus, u8, get_register(ctx, REG16.HL))
    else do val = get_register(ctx, reg)

    bit: u8 = (val >> ins.a) & 0x01
    
    set_flag(ctx, FLAGS.ZERO, bit == 0 ? 0x01 : 0x00)
    set_flag(ctx, FLAGS.SUB, 0)
    set_flag(ctx, FLAGS.HCARRY, 1)

    return reg == .NONE ? 3 : 2
}

/*
    RES, reset bit a of r8[b] to 0

    opc: 0b10xxxxxx / var
    dur: 2 cycle (reg) / 4 cycle ([hl]=6)
    len: 2 byte
    flg: -
*/
res_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    reg := R8_IDX[ins.b]
    val: u8 = 0
    if reg == .NONE do val = mmu.get(bus, u8, get_register(ctx, REG16.HL))
    else do val = get_register(ctx, reg)

    mask: u8 = (0x01 << ins.a)
    val &= ~mask

    if reg == .NONE do mmu.put(bus, val, get_register(ctx, REG16.HL))
    else do set_register(ctx, reg, val)

    return reg == .NONE ? 4 : 2
}

/*
    SET, set bit a of register r8[b] to 1

    opc: 0b11xxxxxx / var
    dur: 2 cycle (reg) / 4 cycle ([hl]=6)
    len: 2 byte
    flg: -
*/
set_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    reg := R8_IDX[ins.b]
    val: u8 = 0
    if reg == .NONE do val = mmu.get(bus, u8, get_register(ctx, REG16.HL))
    else do val = get_register(ctx, reg)

    mask: u8 = (0x01 << ins.a)
    val |= mask

    if reg == .NONE do mmu.put(bus, val, get_register(ctx, REG16.HL))
    else do set_register(ctx, reg, val)
    
    return reg == .NONE ? 4 : 2
}