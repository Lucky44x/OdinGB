package main

import rl "vendor:raylib"
import "core"

OUTPUT_TEXTURE: rl.Texture

init_renderer :: proc(
    ctx: ^core.GB_Core
) {
    image := rl.Image {
        data = raw_data(ctx.ppu_frameBuffer[:]),
        width = 160,
        height = 144,
        mipmaps = 1,
        format = .UNCOMPRESSED_R5G5B5A1
    }

    OUTPUT_TEXTURE = rl.LoadTextureFromImage(image)
    rl.SetTextureFilter(OUTPUT_TEXTURE, .POINT)
}

deinit_renderer :: proc() {
    rl.UnloadTexture(OUTPUT_TEXTURE)
}

update_renderer :: proc(
    ctx: ^core.GB_Core
) {
    rl.UpdateTexture(OUTPUT_TEXTURE, raw_data(ctx.ppu_frameBuffer[:]))
}

draw_renderer :: proc(
    scale: f32
) {
    source := rl.Rectangle {
        x      = 0,
        y      = 0,
        width  = 160,
        height = 144,
    }

    destination := rl.Rectangle {
        x      = 0,
        y      = 0,
        width  = 160 * scale,
        height = 144 * scale,
    }

    rl.DrawTexturePro(
        OUTPUT_TEXTURE,
        source,
        destination,
        {0, 0},
        0,
        rl.WHITE,
    )
}