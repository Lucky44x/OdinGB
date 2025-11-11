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
    register_instruction("00000xxx", Instruction{ handler=rlc_r8, length=1, name="RlC r8"}, true)
    register_instruction("00001xxx", Instruction{ handler=rrc_r8, length=1, name="RRC r8"}, true)

    register_instruction("00010xxx", Instruction{ handler=rl_r8, length=1, name="RLA r8"}, true)
    register_instruction("00011xxx", Instruction{ handler=rr_r8, length=1, name="RRA r8"}, true)
    
    register_instruction("00100xxx", Instruction{ handler=sla_r8, length=1, name="SLA r8"}, true)
    register_instruction("00101xxx", Instruction{ handler=sra_r8, length=1, name="SRA r8"}, true)
    register_instruction("00110xxx", Instruction{ handler=swap_r8, length=1, name="SWAP r8"}, true)
    register_instruction("00111xxx", Instruction{ handler=srl_r8, length=1, name="SRL r8"}, true)

    register_instruction("01xxxxxx", Instruction{ handler=bit_r8, length=1, name="BIT r8"}, true)
    register_instruction("10xxxxxx", Instruction{ handler=res_r8, length=1, name="RES r8"}, true)
    register_instruction("11xxxxxx", Instruction{ handler=set_r8, length=1, name="SET r8"}, true)
}

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
    return 0
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
    return 0
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
    return 0
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
    return 0
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
    return 0
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
    return 0
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
    return 0
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
    return 0
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
    return 0
}

/*
    RES, reset bit a of r8[b] to 0

    opc: 0b10xxxxxx / var
    dur: 2 cycle (reg) / 4 cycle ([hl]=7)
    len: 2 byte
    flg: -
*/
res_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}

/*
    SET, set bit a of register r8[b] to 1

    opc: 0b11xxxxxx / var
    dur: 2 cycle (reg) / 4 cycle ([hl]=7)
    len: 2 byte
    flg: -
*/
set_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> u32 {
    return 0
}