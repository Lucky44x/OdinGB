package bus

import c "../common"

// [CART] 0x0000 - 0x7FFF -> 32KiB Cartridge, reads provided by frontend handle
// [PPU] 0x8000 - 0x9FFF -> 8 KiB Window, owned by PPU
// [CART] 0xA000 - 0xBFFF -> 8 KiB Window, owned by Cartridge (switchable External RAM)
// * 0xC000 - 0xDFFF -> 8 KiB Window - Work RAM, self-owned W-RAM
// [-] 0xE000 - 0xFDFF -> Mirror of C000 - DFFF
// [PPU] 0xFE00 - 0xFE9F -> 160 bytes PPU data (OAM)
// [-] 0xFEA0 - 0xFEFF -> 96 bytes of nothing
// [API] 0xFF00 - 0xFF7F -> 128 bytes Device Fields
// * 0xFF80 - 0xFFFE -> 127 bytes Internal Memory H-RAM
// 0xFFFF -> 1 bytes Interrupt register

Bus :: struct {
    // Accessors
    boot_rom: Boot_Rom,

    // In-Bus Memory
    ram: Bus_RAM,

    // Interrupts
    ic: Bus_InterruptController
}

get_access :: proc(
    bus: ^Bus
) -> c.Bus_Access {
    return {
        ctx = bus,
        read = adapter_bus_read,
        write = adapter_bus_write
    }
}

adapter_bus_write :: proc (ctx: rawptr, addr: u16, val: u8) { bus_write(cast(^Bus)ctx, addr, val) }
bus_write :: proc(ctx: ^Bus, addr: u16, value: u8) {
    switch(addr) {
        case 0x0000 ..= 0x7FFF: //TODO: Ignore, write to cart
            break
        case 0x8000 ..= 0x9FFF: //TODO: Write to PPU
            break
        case 0xA000 ..= 0xBFFF: //TODO: Ignore, write to cart
            break
        case 0xC000 ..= 0xDFFF: fallthrough // Falls through, since E000 - FDFF is a mirror region
        case 0xE000 ..= 0xFDFF: //TODO: Write to own wram bank and guard against overflow beyond Mirror-Limit
            break
        case 0xFE00 ..= 0xFE9F: //TODO: Write to PPU
            break
        case 0xFEA0 ..= 0xFEFF: return; // Ignored -> Nothing in this range
        case 0xFF00 ..= 0xFF7F: //TODO: Write to device fields
            break
        case 0xFF80 ..= 0xFFFE: //TODO: Write to hram
            break
        case 0xFFFF: //TODO: Write to interrupt register
            break
    }

}

adapter_bus_read :: proc (ctx: rawptr, addr: u16) -> u8 { return bus_read(cast(^Bus)ctx, addr) }
bus_read :: proc(ctx: ^Bus, addr: u16) -> u8 {
    switch(addr) {
        case 0x0000 ..= 0x7FFF: //TODO: Read from cart
            break
        case 0x8000 ..= 0x9FFF: //TODO: Read from PPU
            break
        case 0xA000 ..= 0xBFFF: //TODO: Read from cart
            break
        case 0xC000 ..= 0xDFFF: fallthrough // Falls through, since E000 - FDFF is a mirror region
        case 0xE000 ..= 0xFDFF: //TODO: Read from own wram bank and guard against overflow beyond Mirror-Limit
            break
        case 0xFE00 ..= 0xFE9F: //TODO: Read from PPU
            break
        case 0xFEA0 ..= 0xFEFF: return 0xFF; // Nothing inside this region
        case 0xFF00 ..= 0xFF7F: //TODO: Read from device fields
            break
        case 0xFF80 ..= 0xFFFE: //TODO: Read from hram
            break
        case 0xFFFF: //TODO: Read from interrupt register
            break
    }
    return 0x00
}