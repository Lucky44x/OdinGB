package ppu

import "core:log"
import c "../common"

PPU :: struct {
    bus: ^c.Bus_Access,
    vram: VRAM,
    renderer: PPU_Renderer
}

// The Framebuffer for the gameboy's screen
// Stored in R5G5B5A1 -> 5 bits each, 1 alpha bit => 16 bit per pixel
PPU_FrameBuffer :: [160 * 144]u16

init :: proc(
    self: ^PPU,
    bus: ^c.Bus_Access
) {
    self.bus = bus
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

step :: proc(
    ppu: ^PPU,
    elapsed_m_cycles: u16
) {
    dots := elapsed_m_cycles * 4 // 4 Dots per M-Cycle
    
    its := 0
    for dots > 0 {
        its += 1
        consumed := step_ppu_state(&ppu.renderer, ppu.bus, dots)
        assert(consumed > 0)
        assert(consumed <= dots)

        dots -= consumed
    }
}

ppu_read :: proc(ctx: ^c.PPU_Access, addr: u16) -> u8 { return read_vram(&(cast(^PPU)ctx.ctx).vram, addr) }
ppu_write :: proc(ctx: ^c.PPU_Access, addr: u16, val: u8) { write_vram(&(cast(^PPU)ctx.ctx).vram, addr, val) }