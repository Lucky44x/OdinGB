#+private
package bus

import "core:log"
RAM_Region :: enum(u16) {
    WRAM = 0xC000,
    HRAM = 0xFF80
}

Bus_RAM :: struct {
    wram: [8192]u8,         // 8 KiB bytes of WRAM
    hram: [127]u8,          // 127 bytes of HRAM
    wram_bank: u8,          // Selected WRAM Bank
}

write_ram :: proc(
    ram: ^Bus_RAM,
    reg: RAM_Region,
    addr: u16,
    val: u8
) {
    //if reg == .HRAM do log.infof("Writing %#02x to %04X in HRAM", val, addr)

    phys_addr := addr - u16(reg)
    if reg == .WRAM do ram.wram[phys_addr] = val
    else do ram.hram[phys_addr] = val
}

read_ram :: proc(
    ram: ^Bus_RAM,
    reg: RAM_Region,
    addr: u16,
) -> u8 {
    phys_addr := addr - u16(reg)
    return reg == .WRAM ? ram.wram[phys_addr] : ram.hram[phys_addr]
}