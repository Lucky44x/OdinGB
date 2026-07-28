#+private
#+feature dynamic-literals
package bus

import c "../common"

IO_Registers :: struct {
    data: [128]u8
}

IO_READ_FALLBACK :: proc(ctx: ^IO_Registers) -> u8
IO_WRITE_FALLBACK :: proc(ctx: ^IO_Registers, val: u8)

IO_R_FALLBACKS := map[c.IO_Regs] IO_READ_FALLBACK {
    .JOYP = fb_read_joyp
}

IO_W_FALLBACKS := map[c.IO_Regs] IO_WRITE_FALLBACK {}

IO_READ_MASK := map[c.IO_Regs] u8 {
    .STAT = 0x7F,
    .NR11 = 0xC0, .NR14 = 0x40, .NR21 = 0xC0, .NR24 = 0x40, .NR30 = 0x80,
    .NR32 = 0x60, .NR34 = 0x40, .NR44 = 0x40, .NR52 = 0x8F,
    
    .NR13 = 0x00, .NR23 = 0x00, .NR31 = 0x00, .NR33 = 0x00, .NR41 = 0x00,
    
    //CGB
    .KEY1 = 0x81, .RP = 0xC3,

    // Write-Only
    .HDMA1 = 0x00, .HDMA2 = 0x00, .HDMA3 = 0x00, .HDMA4 = 0x00, .HDMA5 = 0x00,
}

IO_WRITE_MASK := map[c.IO_Regs] u8 {
    .STAT = 0x78,
    .JOYP = 0x30, .NR14 = 0xC7, .NR24 = 0xC7, .NR34 = 0xC7, .NR44 = 0xC0, .NR52 = 0x80,
    //CGB Mode:
    .KEY0 = 0x04, .KEY1 = 0x01, .RP = 0xC1,
    // Read-Only:
    .LY = 0x00, .BANK = 0x00, .PCM12 = 0x00, .PCM34 = 0x00
}

// TODO: Add all masks where needed
IO_BIT_OR_READ := map[c.IO_Regs]u8 {
    .STAT = 0x80,

    .NR11 = 0x3F, .NR14 = 0xBF, .NR21 = 0x3F, 
    .NR24 = 0xBF, .NR30 = 0x7F, .NR32 = 0x9F, 
    .NR34 = 0xBF, .NR44 = 0xBF, .NR52 = 0x70,

    .KEY1 = 0x7E, .VBK  = 0xFE,
}

read_IO_Registers :: proc(
    ctx: ^IO_Registers,
    addr: u16,
    force: bool = false
) -> u8 {
    register := cast(c.IO_Regs)addr

    if !force {
        if register in IO_R_FALLBACKS do return IO_R_FALLBACKS[register](ctx)
        else if register in IO_READ_MASK do return read_IO_Protected(ctx, addr)
    }

    return ctx.data[addr - 0xFF00]
}

write_IO_Registers :: proc(
    ctx: ^IO_Registers,
    addr: u16,
    val: u8,
    force: bool = false
) {
    register := cast(c.IO_Regs)addr

    if !force {
        if register in IO_W_FALLBACKS {
            IO_W_FALLBACKS[register](ctx, val)
            return
        }
        else if register in IO_WRITE_MASK {
            write_IO_Protected(ctx, addr, val)
            return 
        }
    }

    ctx.data[addr - 0xFF00] = val
}

read_IO_Protected :: proc(
    ctx: ^IO_Registers,
    addr: u16,
) -> u8 {
    reg := cast(c.IO_Regs)addr
    mask := IO_READ_MASK[reg] 
    
    val := read_IO_Registers(ctx, addr, force=true)

    read_or: u8 = 0
    if reg in IO_BIT_OR_READ do read_or = IO_BIT_OR_READ[reg]

    return (val & mask) | read_or
}

write_IO_Protected :: proc(
    ctx: ^IO_Registers,
    addr: u16,
    val: u8
) {
    reg := cast(c.IO_Regs)addr
    mask := IO_WRITE_MASK[reg] 
    orig := read_IO_Registers(ctx, addr, force=true)

    maskedVal := val & mask
    maskedOrig := orig & ~mask

    newVal := maskedOrig | maskedVal
    write_IO_Registers(ctx, addr, newVal, force=true)
}

// =========== SPECIAL FALLBACKS FOR IO REGISTERS
fb_read_joyp :: proc(ctx: ^IO_Registers) -> u8 {
    //TODO: Implement joyp logic
    return 0xF // TEMP: All buttons released
}