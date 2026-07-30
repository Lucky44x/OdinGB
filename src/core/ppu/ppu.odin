package ppu

import "core:log"
import c "../common"

PPU_Mode :: enum(u8) {
    HorizontalBlank = 0,
    VerticalBlank = 1,
    OAMScan = 2,
    Drawing = 3,
}

PPU_Renderer :: struct {
    ppu_mode: PPU_Mode,
    line_dots: u16,
    current_line: u8
}

PPU :: struct {
    bus: ^c.Bus_Access,
    vram: VRAM,
    rend: PPU_Renderer,
    callback: c.PPU_Callback
}

init :: proc(
    self: ^PPU,
    bus: ^c.Bus_Access,
    callback_function: c.PPU_ScanlineCallback,
    callback_ctx: rawptr = nil
) {
    self.bus = bus
    self.callback.callback = callback_function
    self.callback.ctx = callback_ctx
}

reset :: proc(
    self: ^PPU
) {
    self.rend.current_line = 0
    self.rend.line_dots = 0
    self.rend.ppu_mode = .OAMScan

    self.vram.data = {}
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
        consumed := step_ppu_state(ppu, dots)
        assert(consumed > 0)
        assert(consumed <= dots)

        dots -= consumed
    }
}

ppu_read :: proc(ctx: ^c.PPU_Access, addr: u16) -> u8 { return read_vram(&(cast(^PPU)ctx.ctx).vram, addr) }
ppu_write :: proc(ctx: ^c.PPU_Access, addr: u16, val: u8) { write_vram(&(cast(^PPU)ctx.ctx).vram, addr, val) }