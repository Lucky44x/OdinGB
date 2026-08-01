package bus

import c "../common"
import audio "../apu"

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
    boot_rom: ^Boot_Rom,
    cart_rom: ^c.CART_Access,
    ppu: ^c.PPU_Access,
    apu: ^audio.APU, //FIXME: Replace with common Access Struct
    input: ^c.Input_State,

    // In-Bus Memory
    ram: Bus_RAM,
    io: IO_Registers,

    // Interrupt enable reg
    ie_reg: u8,

    // DMA Controller
    dma: DMA_State,

    is_banked: bool
}

init :: proc(
    self: ^Bus,
    boot_rom: ^Boot_Rom,
    cart: ^c.CART_Access,
    ppu: ^c.PPU_Access,
    apu: ^audio.APU,
    input: ^c.Input_State
) {
    self.boot_rom = boot_rom
    self.cart_rom = cart
    self.ppu = ppu
    self.input = input
    self.apu = apu
}

reset :: proc(
    self: ^Bus
) {
    self.ie_reg = 0x00
    self.is_banked = false
    
    self.io.data = {}
    self.ram.hram = {}
    self.ram.wram = {}
    self.ram.wram_bank = 0

    self.dma.origin_addr = 0x00
    self.dma.enabled = false
    self.dma.progress = 0
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

adapter_bus_write :: proc (bus: ^c.Bus_Access, addr: u16, val: u8, force: bool) { bus_write(cast(^Bus)bus.ctx, addr, val, force) }
bus_write :: proc(ctx: ^Bus, addr: u16, value: u8, force: bool = false) {
    if addr == 0xFF50 {
        ctx.is_banked = true
        write_IO_Registers(ctx, 0xFF50, 0xFF, force = true)
        return
    }

    if !force && ctx.dma.enabled && (addr < 0xFF80 || addr > 0xFFFE) do return // During DMA, everything except H-RAM is disabled

    switch(addr) {
        case 0x0000 ..= 0x7FFF: // Forwards write to the cartridge, cart then has to decide wether or not write is valid
            ctx.cart_rom.write_ram(ctx.cart_rom, addr, value); return
        case 0x8000 ..= 0x9FFF: 
            ctx.ppu.write(ctx.ppu, addr, value); return
        case 0xA000 ..= 0xBFFF: // Forwards write to the cartridge, cart then has to decide wether or not write is valid
            ctx.cart_rom.write_ram(ctx.cart_rom, addr, value); return
        case 0xC000 ..= 0xDFFF:
            write_ram(&ctx.ram, .WRAM, addr, value); return
        case 0xE000 ..= 0xFDFF:
            write_ram(&ctx.ram, .WRAM, addr - 0x2000, value); return
        case 0xFE00 ..= 0xFE9F:
            ctx.ppu.write(ctx.ppu, addr, value); return
        case 0xFEA0 ..= 0xFEFF: return // Ignored -> Nothing in this range
        case 0xFF00 ..= 0xFF7F: 
            write_IO_Registers(ctx, addr, value, force); return
        case 0xFF80 ..= 0xFFFE:
            write_ram(&ctx.ram, .HRAM, addr, value); return
        case 0xFFFF: 
            ctx.ie_reg = value; return
    }

}

adapter_bus_read :: proc (bus: ^c.Bus_Access, addr: u16, force: bool = false) -> u8 { return bus_read(cast(^Bus)bus.ctx, addr, force) }
bus_read :: proc(ctx: ^Bus, addr: u16, force: bool = false) -> u8 {
    if !ctx.is_banked && addr <= 0xFF do return ctx.boot_rom.data[addr]

    if !force && ctx.dma.enabled && (addr < 0xFF80 || addr > 0xFFFE) do return 0x00 // During DMA, everything except H-RAM is disabled

    switch(addr) {
        case 0x0000 ..= 0x7FFF: return ctx.cart_rom.read_rom(ctx.cart_rom, addr)
        case 0x8000 ..= 0x9FFF: return ctx.ppu.read(ctx.ppu, addr)
        case 0xA000 ..= 0xBFFF: return ctx.cart_rom.read_rom(ctx.cart_rom, addr) //FIXME: Reading RAM not ROM
        case 0xC000 ..= 0xDFFF: return read_ram(&ctx.ram, .WRAM, addr)
        case 0xE000 ..= 0xFDFF: return read_ram(&ctx.ram, .WRAM, addr - 0x2000)
        case 0xFE00 ..= 0xFE9F: return ctx.ppu.read(ctx.ppu, addr)
        case 0xFEA0 ..= 0xFEFF: return 0xFF; // Nothing inside this region
        case 0xFF00 ..= 0xFF7F: return read_IO_Registers(ctx, addr, force)
        case 0xFF80 ..= 0xFFFE: return read_ram(&ctx.ram, .HRAM, addr)
        case 0xFFFF: return ctx.ie_reg
    }
    return 0x00
}