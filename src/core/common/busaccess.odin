package common

// P1   == JOYP
// SYS  == KEY0
// SPD  == KEY1
// BGPI == BCPS
// BGPD == BCPD
// OBPI == OCPS
// OBPD == OCPD
// WBK  == SVBK

GB_T_CYCLES_PER_SECOND :: 4194304
GB_M_CYCLES_PER_SECOND :: GB_T_CYCLES_PER_SECOND / 4

IO_Regs :: enum(u16) {
    // Joypad
    JOYP = 0xFF00,

    // Serial
    SB = 0xFF01, SC = 0xFF02,

    // Timer
    DIV  = 0xFF04, TIMA = 0xFF05, TMA  = 0xFF06, TAC  = 0xFF07,

    // Interrupt flags
    IF = 0xFF0F,

    // Sound channel 1
    NR10 = 0xFF10, NR11 = 0xFF11, NR12 = 0xFF12, NR13 = 0xFF13, NR14 = 0xFF14,

    // Sound channel 2
    NR21 = 0xFF16, NR22 = 0xFF17, NR23 = 0xFF18, NR24 = 0xFF19,

    // Sound channel 3
    NR30 = 0xFF1A, NR31 = 0xFF1B, NR32 = 0xFF1C, NR33 = 0xFF1D, NR34 = 0xFF1E,

    // Sound channel 4
    NR41 = 0xFF20, NR42 = 0xFF21, NR43 = 0xFF22, NR44 = 0xFF23,

    // Sound control
    NR50 = 0xFF24, NR51 = 0xFF25, NR52 = 0xFF26,

    // Channel 3 Wave RAM
    WAVE_RAM_0 = 0xFF30, WAVE_RAM_1 = 0xFF31, WAVE_RAM_2 = 0xFF32, WAVE_RAM_3 = 0xFF33, WAVE_RAM_4 = 0xFF34, WAVE_RAM_5 = 0xFF35, 
    WAVE_RAM_6 = 0xFF36, WAVE_RAM_7 = 0xFF37, WAVE_RAM_8 = 0xFF38, WAVE_RAM_9 = 0xFF39, WAVE_RAM_A = 0xFF3A, WAVE_RAM_B = 0xFF3B,
    WAVE_RAM_C = 0xFF3C, WAVE_RAM_D = 0xFF3D, WAVE_RAM_E = 0xFF3E, WAVE_RAM_F = 0xFF3F,

    // LCD / PPU
    LCDC = 0xFF40, STAT = 0xFF41, SCY  = 0xFF42, SCX  = 0xFF43, LY   = 0xFF44, LYC  = 0xFF45, DMA  = 0xFF46, BGP  = 0xFF47,
    OBP0 = 0xFF48, OBP1 = 0xFF49, WY   = 0xFF4A, WX   = 0xFF4B,

    // Game Boy Color
    KEY0 = 0xFF4C, KEY1 = 0xFF4D, VBK  = 0xFF4F,

    // Boot ROM control
    BANK = 0xFF50,

    // Game Boy Color VRAM DMA
    HDMA1 = 0xFF51, HDMA2 = 0xFF52, HDMA3 = 0xFF53,
    HDMA4 = 0xFF54, HDMA5 = 0xFF55,

    // Game Boy Color infrared
    RP = 0xFF56,

    // Game Boy Color palettes
    BCPS = 0xFF68, BCPD = 0xFF69, OCPS = 0xFF6A, OCPD = 0xFF6B,

    // Game Boy Color object priority
    OPRI = 0xFF6C,

    // Game Boy Color WRAM bank
    SVBK = 0xFF70,

    // Game Boy Color audio output
    PCM12 = 0xFF76, PCM34 = 0xFF77,

    // Interrupt enable
    IE = 0xFFFF,
}

Write_Proc :: proc(ctx: ^Bus_Access, address: u16, value: u8, force: bool = false)
Read_Proc :: proc(ctx: ^Bus_Access, address: u16, force: bool = false) -> u8

Bus_Access :: struct {
    ctx: rawptr,
    // Reads from the specified context, at the specified address
    read: Read_Proc,
    // Writes to the specified context, at the specified address the given byte
    write: Write_Proc
}