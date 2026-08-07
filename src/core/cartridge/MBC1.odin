#+private
package cart

MAPPER_MBC1 :: ROM_Mapper {
    map_addr = Mapper_MBC1,
    write = Write_MBC1,
    state = {}
}

Mapper_MBC1 :: proc(
    mapper: ^ROM_Mapper,
    addr: u16
) -> (is_ram: bool, phys_addr: u32) {
    low_bank := mapper.state.rom_bank & 0x1F
    if low_bank == 0 do low_bank = 1

    high_bank := mapper.state.ram_bank & 0x03
    switchable_bank := (u32(high_bank) << 5) | u32(low_bank)
    fixed_bank: u32 = 0
    ram_bank: u32 = 0

    if mapper.state.bank_mode != 0 {
        fixed_bank = u32(high_bank) << 5
        ram_bank = u32(high_bank)
    }

    // Limit register values to the ROM actually present in the cartridge.
    if mapper.banks > 0 {
        fixed_bank %= mapper.banks
        switchable_bank %= mapper.banks
        if switchable_bank == 0 && mapper.banks > 1 do switchable_bank = 1
    }

    switch addr {
        case 0x00..=0x3FFF:
            return false, fixed_bank * ROM_BANK_SIZE + u32(addr)
        case 0x4000..=0x7FFF:
            return false, switchable_bank * ROM_BANK_SIZE + u32(addr - 0x4000)

        case 0xA000..=0xBFFF:
            if !mapper.state.ram_enabled || mapper.ram_size == 0 do return false, 0
            phys_addr = ram_bank * RAM_BANK_SIZE + u32(addr - 0xA000)
            if phys_addr >= mapper.ram_size do return false, 0
            return true, phys_addr
    }

    return false, 0x00
}

Write_MBC1 :: proc(
    mapper: ^ROM_Mapper,
    addr: u16,
    val: u8
) -> (do_write: bool) {
    // Registers
    switch addr {
        case 0x00..=0x1FFF:
            mapper.state.ram_enabled = (val & 0x0F) == 0x0A
            return false

        case 0x2000..=0x3FFF:
            mapper.state.rom_bank = val & 0x1F
            return false
        
        case 0x4000..=0x5FFF:
            mapper.state.ram_bank = val & 0x3
            return false
        
        case 0x6000..=0x7FFF:
            mapper.state.bank_mode = val & 0x01
            return false
    }

    if addr >= 0xA000 && addr <= 0xBFFF {
        if !mapper.state.ram_enabled || mapper.ram_size == 0 do return false
        return true
    }
    return false
}
