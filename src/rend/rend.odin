package rend

import "core:mem"
import rl "vendor:raylib"

COLOR_TABLE := [4]u8 {
    0x00,
    0x44,
    0x77,
    0xFF
}

PPU :: struct {
    renderTarget: rl.Texture2D,
    frameBuffer: [^]u8,

    vram: [^]u8,
    oam: [^]u8
}

make_ppu :: proc(
    ctx: ^PPU
) {
    if ctx == nil do return 

    ctx.frameBuffer = make([^]u8, 160*144)  // 1byte per pixel
    ctx.oam = make([^]u8, 256)  // Overallocate a bit, as usual
    ctx.vram = make([^]u8, 4096*2)

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
    free(ctx.vram)
    free(ctx.oam)
    rl.UnloadTexture(ctx.renderTarget)
}

clear_ppu :: proc(
    ctx: ^PPU
) {
    mem.set(ctx.frameBuffer, 0xFF, 160*144)
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