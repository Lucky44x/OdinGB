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
    switch addr {
        case 0x00..=0x3FFF: return false, u32(addr)
        case 0x4000..=0x7FFF:
            if mapper.state.rom_bank == 0 do mapper.state.rom_bank = 1
            return false, u32(mapper.state.rom_bank) * ROM_BANK_SIZE + u32(addr - 0x4000);

        case 0xA000..=0xBFFF:
            if !mapper.state.ram_enabled do return true, 0xFF
            return true, u32(mapper.state.ram_bank) * RAM_BANK_SIZE + u32(addr - 0xA000)
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
            if val == 0xA do mapper.state.ram_enabled = true
            else do mapper.state.ram_enabled = false
            return false

        case 0x2000..=0x3FFF:
            mapper.state.rom_bank = val & 0x1F
            return false
        
        case 0x4000..=0x5FFF:
            mapper.state.ram_bank = val & 0x3
            return false
        
        case 0x6000..=0x7FFF:
            //TODO: Implement Banking Mode
            return false
    }

    if addr >= 0xA000 && 0xBFFF <= addr do return true // Only allow writes into RAM-Bank Region
    return false
}