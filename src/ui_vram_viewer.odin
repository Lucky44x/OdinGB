#+private file
package main

import rl "vendor:raylib"

import imgui "../libs/odin-imgui"
import imguirl "../libs/rlimgui"

ATLAS_COLUMNS :: 16
ATLAS_ROWS :: TILE_COUNT / ATLAS_COLUMNS
ATLAS_WIDTH :: ATLAS_COLUMNS * TILE_WIDTH
ATLAS_HEIGHT :: ATLAS_ROWS * TILE_HEIGHT

tile_atlas: rl.Texture2D
atlas_pixels: [ATLAS_WIDTH * ATLAS_HEIGHT]rl.Color
atlas_scale: f32

@(private)
UI_VRAM_TILES_VIEWER_ENABLED := false

@(private)
ui_init_vram_tiles_viewer :: proc() {
    image := rl.GenImageColor(
        ATLAS_WIDTH, ATLAS_HEIGHT, ACTIVE_PALETTE[0]
    )

    tile_atlas = rl.LoadTextureFromImage(image)
    rl.UnloadImage(image)

    rl.SetTextureFilter(tile_atlas, .POINT)
}

@(private)
ui_update_vram_tiles_viewer :: proc(
    vram: []u8
) {
    //TODO: Add VRAM bank selection and display CGB tile-bank/palette attributes.
    if !UI_VRAM_TILES_VIEWER_ENABLED do return
    assert(len(vram) >= TILE_COUNT * BYTES_PER_TILE)

    for tile_index in 0..<TILE_COUNT {
        tile_offset := tile_index * BYTES_PER_TILE
        tile_x := (tile_index % ATLAS_COLUMNS) * TILE_WIDTH
        tile_y := (tile_index / ATLAS_ROWS) * TILE_HEIGHT

        for row in 0..<TILE_HEIGHT {
            low := vram[tile_offset + row * 2]
            hi := vram[tile_offset + row * 2 + 1]

            for column in 0..<TILE_WIDTH {
                // Pixel 0 is encoded in bit 7, pixel 7 in bit 0
                bit := u8(7 - column)
                low_bit  := (low  >> bit) & 1
                high_bit := (hi >> bit) & 1

                color_index := low_bit | (high_bit << 1)

                atlas_x := tile_x + column
                atlas_y := tile_y + row

                atlas_pixels[atlas_y * ATLAS_WIDTH + atlas_x] =
                    ACTIVE_PALETTE[color_index]
            }
        }
    }

    rl.UpdateTexture(
        tile_atlas, raw_data(atlas_pixels[:])
    )
}

@(private)
imgui_display_vram_tiles_viewer :: proc(vram: []u8) {
    if !UI_VRAM_TILES_VIEWER_ENABLED do return

    imgui.PushStyleVarImVec2(.WindowPadding, {0,0})
    //imgui.PushStyleVar_Vec2(.WindowPadding, {0, 0})

    if imgui.Begin("VRAM Tiles", &UI_VRAM_TILES_VIEWER_ENABLED) {
        ui_update_vram_tiles_viewer(vram)

        available := imgui.GetContentRegionAvail()

        imgui.Image(
            raylib_imgui_tex_ref(tile_atlas),
            available
        )
    }
    imgui.End()
    imgui.PopStyleVar()
}
