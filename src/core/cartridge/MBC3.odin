#+private
package cart

import "core:time"

MAPPER_MBC3 :: ROM_Mapper {
    map_addr = Mapper_MBC3,
    write = Write_MBC3,
    state = {}
}

Mapper_MBC3 :: proc(
    mapper: ^ROM_Mapper,
    addr: u16,
) -> (is_ram: bool, phys_addr: u32) {
    mapper.state.rtc_selected = false

    bank := u32(mapper.state.rom_bank & 0x7F)
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
        case 0xA000..=0xBFFF:
            // 0x08-0x0C select RTC registers. RTC is intentionally outside
            // the normal external RAM mapping.
            if !mapper.state.ram_enabled do return false, 0
            if mapper.state.ram_bank >= 0x08 && mapper.state.ram_bank <= 0x0C {
                mapper.state.rtc_selected = true
                mapper.state.rtc_register = mapper.state.ram_bank
                return false, 0
            }
            if mapper.state.ram_bank > 3 || mapper.ram_size == 0 {
                return false, 0
            }
            phys_addr = u32(mapper.state.ram_bank) * RAM_BANK_SIZE + u32(addr - 0xA000)
            if phys_addr >= mapper.ram_size do return false, 0
            return true, phys_addr
    }

    return false, 0
}

Write_MBC3 :: proc(
    mapper: ^ROM_Mapper,
    addr: u16,
    val: u8,
) -> (do_write: bool) {
    switch addr {
        case 0x0000..=0x1FFF:
            mapper.state.ram_enabled = (val & 0x0F) == 0x0A
            mapper.state.rtc_selected = false
            return false
        case 0x2000..=0x3FFF:
            mapper.state.rom_bank = val & 0x7F
            return false
        case 0x4000..=0x5FFF:
            mapper.state.ram_bank = val & 0x0F
            mapper.state.rtc_selected = false
            return false
        case 0x6000..=0x7FFF:
            // RTC latch is intentionally not implemented here.
            return false
        case 0xA000..=0xBFFF:
            return mapper.state.ram_enabled && mapper.state.ram_bank <= 3 && mapper.ram_size > 0
    }

    return false
}

Read_MBC3_RTC :: proc(
    mapper: ^ROM_Mapper,
) -> u8 {
    // Use UTC Unix time as a temporary RTC epoch. Persistence and latching are
    // intentionally outside the mapper's current scope.
    unix_seconds := time.time_to_unix(time.now())
    seconds_today := unix_seconds % 86400
    days := unix_seconds / 86400

    switch mapper.state.rtc_register {
        case 0x08: return u8(seconds_today % 60)
        case 0x09: return u8(seconds_today / 60 % 60)
        case 0x0A: return u8(seconds_today / 3600 % 24)
        case 0x0B: return u8(days & 0xFF)
        case 0x0C:
            value: u8 = u8((days >> 8) & 0x01)
            if days > 511 do value |= 0x80 // Day-counter overflow flag.
            return value
    }

    return 0xFF
}
