package main

import rl "vendor:raylib"


VRAM_SIZE          :: 0x2000
TILE_DATA_SIZE     :: 0x1800
TILE_BYTE_SIZE     :: 16
TILE_WIDTH         :: 8
TILE_HEIGHT        :: 8
TILE_COUNT         :: TILE_DATA_SIZE / TILE_BYTE_SIZE // 384

TILE_VIEW_COLUMNS  :: 16
TILE_VIEW_ROWS     :: TILE_COUNT / TILE_VIEW_COLUMNS // 24
TILE_VIEW_WIDTH    :: TILE_VIEW_COLUMNS * TILE_WIDTH  // 128
TILE_VIEW_HEIGHT   :: TILE_VIEW_ROWS * TILE_HEIGHT    // 192

VRAM_Viewer :: struct {
    texture: rl.Texture,
    pixels:  [TILE_VIEW_WIDTH * TILE_VIEW_HEIGHT]rl.Color,
}

vram_viewer_init :: proc() -> VRAM_Viewer {
    viewer: VRAM_Viewer

    image := rl.Image {
        data    = raw_data(viewer.pixels[:]),
        width   = TILE_VIEW_WIDTH,
        height  = TILE_VIEW_HEIGHT,
        mipmaps = 1,
        format  = .UNCOMPRESSED_R8G8B8A8
    }

    viewer.texture = rl.LoadTextureFromImage(image)

    // Preserve sharp pixel edges when scaling.
    rl.SetTextureFilter(viewer.texture, .POINT)

    return viewer
}

vram_viewer_destroy :: proc(viewer: ^VRAM_Viewer) {
    rl.UnloadTexture(viewer.texture)
}

vram_viewer_update :: proc(
    viewer: ^VRAM_Viewer,
    vram: ^[VRAM_SIZE]u8,
) {
    palette := [4]rl.Color {
        rl.Color{224, 248, 208, 255},
        rl.Color{136, 192, 112, 255},
        rl.Color{52, 104, 86, 255},
        rl.Color{8, 24, 32, 255},
    }

    for tile_index in 0..<TILE_COUNT {
        tile_x := tile_index % TILE_VIEW_COLUMNS
        tile_y := tile_index / TILE_VIEW_COLUMNS

        tile_address := tile_index * TILE_BYTE_SIZE

        for pixel_y in 0..<TILE_HEIGHT {
            low_byte  := vram[tile_address + pixel_y * 2]
            high_byte := vram[tile_address + pixel_y * 2 + 1]

            for pixel_x in 0..<TILE_WIDTH {
                // Game Boy stores the leftmost pixel in bit 7.
                bit := 7 - pixel_x

                low_bit  := (low_byte  >> u8(bit)) & 1
                high_bit := (high_byte >> u8(bit)) & 1

                color_index := low_bit | (high_bit << 1)

                destination_x := tile_x * TILE_WIDTH + pixel_x
                destination_y := tile_y * TILE_HEIGHT + pixel_y

                destination_index :=
                    destination_y * TILE_VIEW_WIDTH +
                    destination_x

                viewer.pixels[destination_index] =
                    palette[color_index]
            }
        }
    }

    rl.UpdateTexture(
        viewer.texture,
        raw_data(viewer.pixels[:]),
    )
}

vram_viewer_draw :: proc(
    viewer: ^VRAM_Viewer,
    position: [2]f32,
    scale: f32,
) {
    source := rl.Rectangle {
        x      = 0,
        y      = 0,
        width  = f32(TILE_VIEW_WIDTH),
        height = f32(TILE_VIEW_HEIGHT),
    }

    destination := rl.Rectangle {
        x      = position.x,
        y      = position.y,
        width  = f32(TILE_VIEW_WIDTH) * scale,
        height = f32(TILE_VIEW_HEIGHT) * scale,
    }

    rl.DrawTexturePro(
        viewer.texture,
        source,
        destination,
        {0, 0},
        0,
        rl.WHITE,
    )
}