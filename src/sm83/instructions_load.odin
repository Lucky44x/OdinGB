#+private
#+feature dynamic-literals
package sm83

import "base:builtin"
import "core:fmt"
import "../mmu"

/*
    registers all load-instructions

    ONLY USE ONCE AT STARTUP
*/
register_load_instructions :: proc() {
    register_instruction("01xxxxxx", Instruction{ handler=ld_r8_r8,     length=1, name="LD r8 r8" })
    register_instruction("00xxx110", Instruction{ handler=ld_r8_imm8,   length=2, name="LD r8 imm8" })
    register_instruction("00xx0001", Instruction{ handler=ld_r16_imm16, length=3, name="LD r16 imm16" })
    register_instruction("01xxx110", Instruction{ handler=ld_r8_HLmem,  length=1, name="LD r8 [HL]" })
    register_instruction("01110xxx", Instruction{ handler=ld_HLmem_r8,  length=1, name="LD [HL] r8" })
    register_instruction("00xx1010", Instruction{ handler=ld_A_r16mem,  length=1, name="LD A [r16]" })
    register_instruction("00xx0010", Instruction{ handler=ld_r16mem_A,  length=1, name="LD [r16] A" })
    register_instruction("11xx0101", Instruction{ handler=push_r16,     length=1, name="PUSH r16stk" })
    register_instruction("11xx0001", Instruction{ handler=pop_r16,      length=1, name="POP r16stk" })

    // Register constant opcodes after patterend, so that in doubt, they will overide
    register_instruction(0x36, Instruction{ handler=ld_HLmem_imm8,  length=2, name="LD [HL] imm8" })
    register_instruction(0xFA, Instruction{ handler=ld_A_imm16mem,  length=3, name="LD A [imm16]" })
    register_instruction(0xEA, Instruction{ handler=ld_imm16mem_A,  length=3, name="LD [imm16] A" })
    register_instruction(0xF2, Instruction{ handler=ldh_A_Cmem,     length=1, name="LDH A [C]" })
    register_instruction(0xE2, Instruction{ handler=ldh_Cmem_A,     length=1, name="LDH [C] A" })
    register_instruction(0xF0, Instruction{ handler=ldh_A_imm8mem,  length=2, name="LDH A [imm8]" })
    register_instruction(0xE0, Instruction{ handler=ldh_imm8mem_A,  length=2, name="LDH [imm8] A" })
    register_instruction(0x3A, Instruction{ handler=ldd_A_HLmem,    length=1, name="LD A [HL-]" })
    register_instruction(0x32, Instruction{ handler=ldd_HLmem_A,    length=1, name="LD [HL-] A" })
    register_instruction(0x2A, Instruction{ handler=ldi_A_HLmem,    length=1, name="LD A [HL+]" })
    register_instruction(0x22, Instruction{ handler=ldi_HLmem_A,    length=1, name="LD [HL+] A" })
    register_instruction(0x08, Instruction{ handler=ld_SP_imm16mem, length=3, name="LD SP [imm16]" })
    register_instruction(0xF9, Instruction{ handler=ld_SP_HL,       length=1, name="LD SP HL" })
    register_instruction(0xF8, Instruction{ handler=ld_HL_SPe,      length=2, name="LD HL SP+e" })
}

/*
    Load to r8_1, the data in r8_2

    opc: 0b01xxxyyy / var
    dur: 1 cycle
    len: 1 byte
    flg: -
*/
ld_r8_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    regA := R8_IDX[ins.a]
    regB := R8_IDX[ins.b]

    if regA == regB {
        fmt.printfln("Breakpoint hit:\n CPU DUMP:\n     Registers-8:")
        fmt.printfln("          A: %#02X", get_register_u8(ctx, .A))
        fmt.printfln("          F: %#02X", get_register_u8(ctx, .F))
        fmt.printfln("          B: %#02X", get_register_u8(ctx, .B))
        fmt.printfln("          C: %#02X", get_register_u8(ctx, .C))
        fmt.printfln("          D: %#02X", get_register_u8(ctx, .D))
        fmt.printfln("          E: %#02X", get_register_u8(ctx, .E))
        fmt.printfln("          H: %#02X", get_register_u8(ctx, .H))
        fmt.printfln("          L: %#02X", get_register_u8(ctx, .L))
        fmt.printfln("      Registers-16:")
        fmt.printfln("          AF: %#04X", get_register_u16(ctx, .AF))
        fmt.printfln("          BC: %#04X", get_register_u16(ctx, .BC))
        fmt.printfln("          DE: %#04X", get_register_u16(ctx, .DE))
        fmt.printfln("          HL: %#04X", get_register_u16(ctx, .HL))
        fmt.printfln("          SP: %#04X", get_register_u16(ctx, .SP))
        fmt.printfln("          PC: %#04X", get_register_u16(ctx, .PC))
    }

    set_register(ctx, regA, get_register_u8(ctx, regB))
    return 1
}

/*
    Load to r8, the value imm8

    opc: 0b00xxx110 / var
    dur: 2 cycle
    len: 2 byte -> op + imm8
    flg: -
*/
ld_r8_imm8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    regA := R8_IDX[ins.a]
    set_register(ctx, regA, ins.opbytes[1])
    return 2
}

/*
    Load to r16, the value imm16

    opc: 0b00xx0001 / var
    dur: 3 cycle
    len: 3 byte -> op + lsb(nn) + msb(nn)
    flg: -
*/
ld_r16_imm16 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    reg := R16_IDX[ins.x]
    total := bu16(ins.opbytes)
    set_register(ctx, reg, total)
    return 3
}

/*
    Load to r8, the value stored at [hl]

    opc: 0b01xxx110 / var
    dur: 2 cycle
    len: 1 byte
    flg: -
*/
ld_r8_HLmem :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    reg := R8_IDX[ins.a]
    val := mmu.get(bus, u8, get_register(ctx, REG16.HL))
    set_register(ctx, reg, val)
    return 2
}

/*
    Store at [hl], the data in register r8

    opc: 0b01110xxx / var
    dur: 2 cycle
    len: 1 byte
    flg: -
*/
ld_HLmem_r8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    reg := R8_IDX[ins.b]
    mmu.put(bus, get_register(ctx, reg), get_register(ctx, REG16.HL))
    return 2
}

/*
    Store at [hl], the value of imm8

    opc: 0b00110110 / 0x36
    dur: 3 cycle
    len: 2 byte -> imm8 + imm8
    flg: -
*/
ld_HLmem_imm8 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    mmu.put(bus, ins.opbytes[1], get_register(ctx, REG16.HL))
    return 3
}

/*
    Load into register A, the data stored at [r16mem]

    opc: 0b00xx1010 / var
    dur: 2 cycle
    len: 1 byte
    flg: -
*/
ld_A_r16mem :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    reg := R16_IDX_M[ins.x]
    set_register(ctx, REG8.A, mmu.get(bus, u8, get_register(ctx, reg)))
    r16m_do_hl_increment_if_needed(ctx, ins.x)
    return 2
}

/*
    Store at [r16mem], the data in register A

    opc: 0b00xx0010 / var
    dur: 2 cycle
    len: 1 byte
    flg: -
*/
ld_r16mem_A :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    reg := R16_IDX_M[ins.x]
    mmu.put(bus, get_register(ctx, REG8.A), get_register(ctx, reg))
    r16m_do_hl_increment_if_needed(ctx, ins.x)
    return 2
}

/*
    Load into reg A, the data stored in [imm16]

    opc: 0b11111010 / 0xFA
    dur: 4 cycle
    len: 3 byte -> op + msb(nn) + lsb(nn)
    flg: -
*/
ld_A_imm16mem :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    addr := bu16(ins.opbytes)
    val := mmu.get(bus, u8, addr)
    set_register(ctx, REG8.A, val)
    return 4
}

/*
    Store at [imm16], the data in register A

    opc: 0b11101010 / 0xEA
    dur: 4 cycle
    len: 3 byte -> op + msb(nn) + lsb(nn)
    flg: -
*/
ld_imm16mem_A :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    addr := bu16(ins.opbytes)
    mmu.put(bus, get_register(ctx, REG8.A), addr)
    return 4
}

/*
    Load into register A, the data stored at [0xFF00 + C] (0xFF00 - 0xFFFF)

    opc: 0b11110010 / 0xF2
    dur: 2 cycle
    len: 1 byte
    flg: -
*/
ldh_A_Cmem :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    addr : u16 = 0xFF00 + u16(get_register(ctx, REG8.C))
    val := mmu.get(bus, u8, addr)
    set_register(ctx, REG8.A, val)
    return 2
}

/*
    Store at [0xFF00 + C] (0xFF00 - 0xFFFF), the data in register A

    opc: 0b11100010 / 0xE2
    dur: 2 cycle
    len: 1 byte
    flg: -
*/
ldh_Cmem_A :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    addr : u16 = 0xFF00 + u16(get_register(ctx, REG8.C))
    val := get_register(ctx, REG8.A)
    mmu.put(bus, val, addr)
    return 2
}

/*
    Load into A, the data stored at [0xFF00 + imm8] (0xFF00 - 0xFFFF)

    opc: 0b11110000 / 0xF0
    dur: 3 cycle
    len: 2 byte -> op + imm8
    flg: -
*/
ldh_A_imm8mem :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    addr : u16 = 0xFF00 + u16(ins.opbytes[1])
    val := mmu.get(bus, u8, addr)
    set_register(ctx, REG8.A, val)
    return 3
}

/*
    Store at [0xFF00 + imm8] (0xFF00 - 0xFFFF), the data in register A

    opc: 0b11100000 / 0xE0
    dur: 3 cycle
    len: 2 byte -> op + imm8
    flg: -
*/
ldh_imm8mem_A :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    addr : u16 = 0xFF00 + u16(ins.opbytes[1])
    val := get_register(ctx, REG8.A)
    mmu.put(bus, val, addr)
    return 3
}

/*
    Load into A, the data stored at [HL] and decrement HL

    opc: 0b00111010 / 0x3A
    dur: 2 cycle
    len: 1 byte
    flg: -
*/
ldd_A_HLmem :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    addr := get_register(ctx, REG16.HL)
    val := mmu.get(bus, u8, addr)
    set_register(ctx, REG8.A, val)
    add_register(ctx, REG16.HL, -1)
    return 2
}

/*
    Store at [HL], the data in register A and decrement HL

    opc: 0b00110010 / 0x32
    dur: 2 cycle
    len: 1 byte
    flg: -
*/
ldd_HLmem_A :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    addr := get_register(ctx, REG16.HL)
    val := get_register(ctx, REG8.A)
    mmu.put(bus, val, addr)
    add_register(ctx, REG16.HL, -1)
    return 2
}

/*
    Load into A, the data stored at [HL] and increment HL

    opc: 0b00101010 / 0x2A
    dur: 2 cycle
    len: 1 byte
    flg: -
*/
ldi_A_HLmem :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    addr := get_register(ctx, REG16.HL)
    val := mmu.get(bus, u8, addr)
    set_register(ctx, REG8.A, val)
    add_register(ctx, REG16.HL, 1)
    return 2
}

/*
    Store at [HL], the data in register A and increment HL

    opc: 0b00100010 / 0x22
    dur: 2 cycle
    len: 1 byte
    flg: -
*/
ldi_HLmem_A :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    addr := get_register(ctx, REG16.HL)
    val := get_register(ctx, REG8.A)
    mmu.put(bus, val, addr)
    add_register(ctx, REG16.HL, 1)
    return 2
}

/*
    Store at [imm16], the data in register SP

    opc: 0b00001000 / 0x08
    dur: 5 cycle
    len: 3 byte -> op + lsb(nn) + msb(nn)
    flg: -
*/
ld_SP_imm16mem :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    addr := bu16(ins.opbytes)
    val := get_register(ctx, REG16.SP)
    mmu.put(bus, val, addr)
    return 5
}

/*
    Load into reg SP, the data in register HL

    opc: 0b11111001 / 0xF9
    dur: 2 cycle
    len: 1 byte
    flg: -
*/
ld_SP_HL :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    val := get_register(ctx, REG16.HL)
    set_register(ctx, REG16.SP, val)
    return 2
}

/*
    Load into reg Hl, the data in register SP + signed 8-bit operand e

    opc: 0b11111000 / 0xF8
    dur: 3 cycle
    len: 2 byte -> op + imm8(e)
    flg: Z = 0, N = 0, HC = carry_per_bit[3], C = carry_per_bit[7]
*/
ld_HL_SPe :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    e := transmute(i8) ins.opbytes[1]
    ival: i16 = i16(get_register(ctx, REG16.SP)) + i16(e)
    set_register(ctx, REG16.HL, u16(ival))
   return 3
}

/*
    Push to stack memory, the data in register r16
    (SP - 2)

    opc: 0b11xx0101 / var
    dur: 4 cycle
    len: 1 byte
    flg: -
*/
push_r16 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    reg := R16_IDX_S[ins.x]
    val: u16 = get_register(ctx, reg)
    push_stack(ctx, bus, val)
    return 4
}

/*
    Pop to register r16, the data from the stack
    (SP + 2)

    opc: 0b11xx0001 / var
    dur: 4 cycle
    len: 1 byte
    flg: -
*/
pop_r16 :: proc(
    ctx: ^CPU,
    bus: ^mmu.MMU,
    ins: InsData
) -> (cycles: u32) {
    reg := R16_IDX_S[ins.x]
    val := pop_stack(ctx, bus, u16)
    set_register(ctx, reg, val)
    return 4
}