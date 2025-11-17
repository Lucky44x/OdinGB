#+feature dynamic-literals
package mmu

import "core:fmt"
import "core:mem"
import "../serial"

IO_REGS :: enum(u16) {
    JOYP = 0xFF00, SB = 0xFF01, SC = 0xFF02, DIV = 0xFF04,
    TIMA = 0xFF05, TMA = 0xFF06, TAC = 0xFF07, IF = 0xFF0F,
    NR10 = 0xFF10, NR11 = 0xFF11, NR12 = 0xFF12, NR13 = 0xFF13,
    NR14 = 0xFF14, NR21 = 0xFF14, NR22 = 0xFF17, NR23 = 0xFF18,
    NR24 = 0xFF19, NR30 = 0xFF1A, NR31 = 0xFF1B, NR32 = 0xFF1C,
    NR33 = 0xFF1D, NR34 = 0xFF1E, NR41 = 0xFF20, NR42 = 0xFF21,
    NR43 = 0xFF22, NR44 = 0xFF23, NR50 = 0xFF24, NR51 = 0xFF25,
    NR52 = 0xFF26, WAVERAM = 0xFF30, LCDC = 0xFF40, STAT = 0xFF41,
    SCY = 0xFF42, SCX = 0xFF43, LY = 0xFF44, LYC = 0xFF45,
    DMA = 0xFF46, BGP = 0xFF47, OBP0 = 0xFF48, OBP1 = 0xFF49,
    WY = 0xFF4A, WX = 0xFF4B, BANK = 0xFF50, IE = 0xFFFF,
    KEY0 = 0xFF4D, KEY1 = 0xFF4D, VBK = 0xFF4F, HDMA1 = 0xFF51,
    HDMA2 = 0xFF52, HDMA3 = 0xFF53, HDMA4 = 0xFF54, HDMA5 = 0xFF55,
    RP = 0xFF56, BCPS = 0xFF68, BCPD = 0xFF69, OCPS = 0xFF6A, OCPD = 0xFF6B,
    OPRI = 0xFF6C, SVBK = 0xFF70, PCM12 = 0xFF76, PCM34 = 0xFF77
}

@(private = "file")
REG_WRITE_MASKS := map[u16]u8 {
    0xFF41 = 0b01111000,
    0xFF44 = 0b00000000,
    0xFF00 = 0b00110000,
}


@(private = "file")
NO_READ_REGS : []u16 : {
    u16(IO_REGS.NR13), u16(IO_REGS.NR23), u16(IO_REGS.NR31), u16(IO_REGS.NR33),
    u16(IO_REGS.NR41), u16(IO_REGS.HDMA1), u16(IO_REGS.HDMA2),
    u16(IO_REGS.HDMA3), u16(IO_REGS.HDMA4), u16(IO_REGS.BANK)
}

@(private = "file")
NO_WRITE_REGS : []u16 : {
    u16(IO_REGS.LY), u16(IO_REGS.PCM12), u16(IO_REGS.PCM34)
}

@(private = "file")
find_in_numeric_array :: proc(
    arr: $T/[]$E,
    element: E
) -> bool {
    // Since Blacklists are ordered/sorted, we can break once we exceed our target_num
    for e in arr {
        if u16(e) > u16(element) do break 
        else if u16(e) == u16(element) do return true
    }
    return false
}

@(private = "package")
io_get_register :: proc(
    ctx: ^MMU,
    $T: typeid,
    reg: IO_REGS
) -> T {
    acOff := u16(reg)
    if u16(reg) == 0xFFFF do acOff = 0xFF80

    p := mem.ptr_offset(ctx.io_registers, acOff)
    return mem.reinterpret_copy(T, p)
}

@(private = "package")
io_get :: proc(
    ctx: ^MMU,
    $T: typeid,
    offset: u16 = 0,
    internal: bool
) -> T {
    acOff := offset
    if offset == 0xFFFF do acOff = 0xFF80

    if find_in_numeric_array(NO_READ_REGS, acOff) do return 0x00

    p := mem.ptr_offset(ctx.io_registers, acOff)
    return mem.reinterpret_copy(T, p)
}

@(private = "package")
io_put :: proc(
    ctx: ^MMU,
    val: $T,
    offset: u16 = 0,
    internal: bool
) {
    acOff := offset
    if offset == 0xFFFF do acOff = 0xFF80

    if find_in_numeric_array(NO_WRITE_REGS, acOff) do return

    // Do specific calls:
    if acOff == 0x50 {
        ctx.banked = true
    }

    dst := mem.ptr_offset(ctx.io_registers, acOff)
    local_val := val
    if !internal {
        //Do write protection
        when T == u8 {
            mask, ok := REG_WRITE_MASKS[acOff + 0xFF00]
            if !ok do mask = 0xFF
            prev_val := mem.reinterpret_copy(T, dst)
            preserved := u8(prev_val) & ~mask
            updated := u8(local_val & mask)
            local_val = preserved | updated
        }
    }

    _ = mem.copy(dst, &local_val, size_of(T))
}

@(private = "package")
do_transfer :: proc(
    ctx: ^MMU,
    flag_byte, data_byte: u8
) {
    fmt.printfln("Attempting-Transfer: %r", rune(data_byte))
    flagMask: u8 = 0x01 << 7
    clockMask: u8 = 0x01
    if flagMask & flag_byte == 0x00 do return
    if clockMask & flag_byte == 0x00 do return
    
    val := flag_byte
    val &= ~flagMask
    io_put(ctx, val, 0x02, true)
    fmt.printfln("Transfer: %r", rune(data_byte))
}

get_bit_flag :: proc(
    ctx: ^MMU,
    addr: u16,
    bit: u8
) -> bool {
    dat: u8 = get(ctx, u8, addr)
    bitmask: u8 = 0x01 << bit
    state := dat & bitmask
    return state == 0x00 ? false : true
}

set_bit_flag :: proc(
    ctx: ^MMU,
    addr: u16,
    bit: u8,
    state: bool
) {
    dat: u8 = get(ctx, u8, addr, true)
    bitmask: u8 = 0x01 << bit
    if state do dat |= bitmask
    else do dat &= ~bitmask
    put(ctx, dat, addr, true)
}