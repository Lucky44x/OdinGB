package mmu

import "core:mem"

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
NO_READ_REGS : []u16 : {
    u16(IO_REGS.NR13), u16(IO_REGS.NR23), u16(IO_REGS.NR31), u16(IO_REGS.NR33),
    u16(IO_REGS.NR41), u16(IO_REGS.BANK), u16(IO_REGS.HDMA1), u16(IO_REGS.HDMA2),
    u16(IO_REGS.HDMA3), u16(IO_REGS.HDMA4)
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
    offset: u16 = 0
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
    offset: u16 = 0
) {
    acOff := offset
    if offset == 0xFFFF do acOff = 0xFF80

    if find_in_numeric_array(NO_WRITE_REGS, acOff) do return

    dst := mem.ptr_offset(ctx.io_registers, acOff)
    value: T = val
    _ = mem.copy(dst, &value, size_of(T))
}