#+private
package cart

ROM_BANK_SIZE :: 16384
RAM_BANK_SIZE :: 8192

MapperType :: enum(u8) {
    ROM_ONLY = 0x00,
    MBC1 = 0x01, MBC1_RAM = 0x02, MBC1_RAM_BAT = 0x03,
    MBC2 = 0x05, MBC2_BAT = 0x06,
    ROM_RAM = 0x08, ROM_RAM_BAT = 0x09,
    MMM01 = 0x0B, MMM01_RAM = 0x0C, MMM01_RAM_BAT = 0x0D,
    MBC3_TIMER_BAT = 0x0F, MBC3_TIMER_RAM_BAT = 0x10, MBC3 = 0x11, MBC3_RAM = 0x12, MBC3_RAM_BAT = 0x13,
    MBC5 = 0x19, MBC5_RAM = 0x1A, MBC5_RAM_BAT = 0x1B, MBC5_RUMBLE = 0x1C, MBC5_RUMBLE_RAM = 0x1D, MBC5_RUMBLE_RAM_BAT = 0x1E,
    MBC6 = 0x20,
    MBC7_SENS_RUMB_RAM_BAT = 0x22,
    POCKET_CAMERA = 0xFC,
    BANDAI_TAMAS = 0xFD,
    HUC3 = 0xFE, HUC1_RAM_BAT = 0xFF
}

MAPPING_FUNCTION :: proc(mapper: ^ROM_Mapper, addr: u16) -> (bool, u32)
MAPPER_WRITE :: proc(mapper: ^ROM_Mapper, addr: u16, val: u8) -> bool

MAPPER_Basic :: ROM_Mapper {
    banks = 0,
    state = {},

    map_addr = Mapper_Basic,
    write = nil
}

MapperState :: struct {
    ram_enabled: bool,
    rom_bank, ram_bank, bank_mode: u8,
    rtc_selected: bool,
    rtc_register: u8,
}

ROM_Mapper :: struct {
    banks, rom_size, ram_banks, ram_size: u32,
    ram_nibble: bool,
    state: MapperState,

    map_addr: MAPPING_FUNCTION,
    write: MAPPER_WRITE
}

// No Mapper -> Identical mapping between input and output
Mapper_Basic :: proc(mapper: ^ROM_Mapper, addr: u16) -> (bool, u32) { return false, u32(addr) }
