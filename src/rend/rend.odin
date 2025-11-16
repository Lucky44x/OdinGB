package rend

import "../mmu"
import "core:mem"
import rl "vendor:raylib"

/*
    DRAWING BEHAVIOUR:
        - Screen is split into 154 Scanlines, first 144 are drawn top-to bottom
    MODES:
        - Mode 0: Horizontal Blank      (376 - mode3 duration)      MEM: VRAM, CGB pal, OAM
            Wait for end of scanline
        - Mode 1: Vertical Blank        (4560 dots)                 MEM: VRAM, CGB pal, OAM
            Wait for end of frame
        - Mode 2: OAM Scan              (80 dots)                   MEM: VRAM, CGB palettes
            Search for objects that overlap the line
        - Mode 3: Horizontal Blank      (between 172 and 289 dots)  MEM: none
            Draw pixels to the screen
    ORDER:
        2 -> 3 -> 0 for SL 0..143
        1           for SL 144..153
*/

COLOR_TABLE := [4]u8 {
    0x00,
    0x44,
    0x77,
    0xFF
}

PPU :: struct {
    mode: u8,
    elapse_dots: u32,

    bus: ^mmu.MMU,

    renderTarget: rl.Texture2D,
    frameBuffer: [^]u8
}

make_ppu :: proc(
    ctx: ^PPU,
    bus: ^mmu.MMU
) {
    if ctx == nil do return 

    ctx.bus = bus

    ctx.frameBuffer = make([^]u8, 160*144)  // 1byte per pixel

    img: rl.Image
    img.data = ctx.frameBuffer
    img.width = 160
    img.height = 144
    img.mipmaps = 1
    img.format = .UNCOMPRESSED_GRAYSCALE

    ctx.renderTarget = rl.LoadTextureFromImage(img)
    rl.SetTextureFilter(ctx.renderTarget, .POINT)
}

delete_ppu :: proc(
    ctx: ^PPU
) {
    free(ctx.frameBuffer)
    rl.UnloadTexture(ctx.renderTarget)
}

clear_ppu :: proc(
    ctx: ^PPU
) {
    mem.set(ctx.frameBuffer, 0xFF, 160*144)
}

update_ppu :: proc(
    ctx: ^PPU,
) {
    ctx.elapse_dots += 1
    // Draw one pixel
}

render_tile :: proc(
    ctx: ^PPU,
    tile: [8]u16,
    x, y: u8,
) {
    for fY in u8(0)..<8 {
        current_line : u16 = tile[fY]
        for fX in u8(0)..<8 {
            fbI := u32(x + fX) + (u32(y + fY) * 160)
            bitIndex := 7 - fX

            lsb_byte := u8(current_line & 0xFF)
            msb_byte := u8((current_line >> 8) & 0xFF)
            bit_idx := 7 - u8(fX)

            lo := (lsb_byte >> bit_idx) & 0x01
            hi := (msb_byte >> bit_idx) & 0x01

            color_id: u8 = (hi << 1 ) | lo

            ctx.frameBuffer[fbI] = COLOR_TABLE[color_id]
        }
    }
}