package ppu

import c "../common"

PPU :: struct {
    vram: VRAM
}

get_access :: proc(
    ppu: ^PPU
) -> c.PPU_Access {
    return {
        ctx = ppu,
        write = ppu_write,
        read = ppu_read
    }
}

ppu_read :: proc(ctx: ^c.PPU_Access, addr: u16) -> u8 { return read_vram(&(cast(^PPU)ctx.ctx).vram, addr) }
ppu_write :: proc(ctx: ^c.PPU_Access, addr: u16, val: u8) { write_vram(&(cast(^PPU)ctx.ctx).vram, addr, val) }