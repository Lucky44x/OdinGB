#+private file
package main

import "core:log"
import "core:text/scanner"
import "core:mem"
import rl "vendor:raylib"

SCREEN_WIDTH :: 160
SCREEN_HEIGHT :: 144
@(private)
GB_Palette :: distinct [4]rl.Color
//TODO: Replace the four-color DMG palette with a BGR555 framebuffer converter
//TODO: for CGB output while retaining DMG palette conversion for DMG mode.
@(private)
ACTIVE_PALETTE: ^GB_Palette

renderer_texture: rl.Texture2D
renderer_pixels: [160 * 144]rl.Color
renderer_scale: f32

@(private)
emulation_init_renderer :: proc(
    palette: ^GB_Palette,
    scale: f32
) {
    ACTIVE_PALETTE = palette
    renderer_scale = scale

    image := rl.GenImageColor(
        SCREEN_WIDTH, SCREEN_HEIGHT, ACTIVE_PALETTE[0]
    )
    defer rl.UnloadImage(image)
    
    renderer_texture = rl.LoadTextureFromImage(image)
    rl.SetTextureFilter(renderer_texture, .POINT)
}

@(private)
emulation_draw_renderer :: proc() {
    if ACTIVE_PALETTE == nil do return

    rl.UpdateTexture(renderer_texture, &renderer_pixels)
    rl.DrawTextureEx(renderer_texture, {0,0}, 0, renderer_scale, rl.WHITE)
}

@(private)
render_scanline_adapter :: proc(ctx: rawptr, scanline: u8, pixels: ^[160]u8) { render_scanline(scanline, pixels) }
render_scanline :: proc(
    scanline: u8,
    pixels: ^[160]u8
) { 
    for i in 0..<160 do renderer_pixels[i + (int(scanline) * 160)] = ACTIVE_PALETTE[pixels[i]] 
}
