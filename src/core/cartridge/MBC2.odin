#+private
package cart

MAPPER_MBC2 :: ROM_Mapper {
    map_addr = Mapper_MBC2,
    write = Write_MBC2,
    ram_size = 512,
    ram_banks = 1,
    ram_nibble = true,
    state = {}
}

Mapper_MBC2 :: proc(
    mapper: ^ROM_Mapper,
    addr: u16,
) -> (is_ram: bool, phys_addr: u32) {
    bank := u32(mapper.state.rom_bank & 0x0F)
    if bank == 0 do bank = 1
    if mapper.banks > 0 {
        bank %= mapper.banks
        if bank == 0 && mapper.banks > 1 do bank = 1
    }

    switch addr {
        case 0x0000..=0x3FFF:
            return false, u32(addr)
        case 0x4000..=0x7FFF:
            return false, bank * ROM_BANK_SIZE + u32(addr - 0x4000)
        case 0xA000..=0xA1FF:
            if !mapper.state.ram_enabled do return false, 0
            return true, u32(addr & 0x01FF)
    }

    return false, 0
}

Write_MBC2 :: proc(
    mapper: ^ROM_Mapper,
    addr: u16,
    val: u8,
) -> (do_write: bool) {
    switch addr {
        case 0x0000..=0x3FFF:
            // A8 selects the MBC2 register within this address range.
            if (addr & 0x0100) == 0 {
                mapper.state.ram_enabled = (val & 0x0F) == 0x0A
            } else {
                mapper.state.rom_bank = val & 0x0F
            }
            return false
        case 0xA000..=0xA1FF:
            return mapper.state.ram_enabled
    }

    return false
}
