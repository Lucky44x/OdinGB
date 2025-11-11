package rend

import "core:mem"
import rl "vendor:raylib"

COLOR_TABLE := [4]u8 {
    0x00,
    0xFF,
    0xFF,
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
    for fY in y..<y+8 {
        current_line : u16 = tile[fY-y]
        for fX in x..<x+8 {
            // Combine grayscale values
            bit_idx: u8 = 7 - u8(fX-x) // Left to right, bit7, 6, 5, 4, 3, 2, 1
            bit_lsb: u8 = u8(current_line & 0xFF) >> bit_idx
            bit_msb: u8 = u8((current_line << 8) & 0xFF) >> bit_idx
            color_id: u8 = bit_msb

            //Calculate frame-buffer index
            fbI : u32 = u32(x) + u32(y) * 160
            ctx.frameBuffer[fbI] = COLOR_TABLE[color_id]
        }
    }
}