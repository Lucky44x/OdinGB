#+private file
package main

import "vendor:stb/truetype"
import rl "vendor:raylib"

import imgui "../libs/odin-imgui"
import imguirl "../libs/rlimgui"

import "core"

TILEMAP_WIDTH :: 32
TILEMAP_HEIGHT :: 32

TILEMAP_PX_WIDTH :: TILEMAP_WIDTH * TILE_WIDTH
TILEMAP_PX_HEIGHT :: TILEMAP_HEIGHT * TILE_HEIGHT

VRAM_SIZE :: 0x2000
//TODO: Add bank-1 attribute-map display, CGB palette selection, flips, and
//TODO: tile priority controls to this DMG-only viewer.
TILE_DATA_UNSIGNED :: 0x0000 // $8000
TILE_DATA_SIGNED :: 0x1000 // $9000

TILEMAP_1_OFFSET :: 0x1800
TILEMAP_2_OFFSET :: 0x1C00

LCD_WIDTH  :: 160
LCD_HEIGHT :: 144

REG_LCDC :: u16(0xff40)
REG_SCY  :: u16(0xff42)
REG_SCX  :: u16(0xff43)
REG_WX :: u16(0xFF4B)
REG_WY :: u16(0xFF4A)

LCDC_BG_TILEMAP_SELECT :: u8(1 << 3)

@(private)
UI_TILEMAP_VIEWER_ENABLED := false

signed_addressing: bool
selected_tilemap: int
tilemap_texture: rl.Texture2D
tilemap_pixels: [TILEMAP_PX_WIDTH * TILEMAP_PX_HEIGHT]rl.Color

@(private)
ui_init_tilemap_viewer :: proc() {
    image := rl.GenImageColor(TILEMAP_PX_WIDTH, TILEMAP_PX_HEIGHT, ACTIVE_PALETTE[0])
    defer rl.UnloadImage(image)

    tilemap_texture = rl.LoadTextureFromImage(image)
    rl.SetTextureFilter(tilemap_texture, .POINT)
}

/*
 Returns the VRAM offset of a tile's first byte.

 Unsigned addressing:

     tile 0   -> $8000 -> vram[0x0000]
     tile 255 -> $8ff0 -> vram[0x0ff0]

 Signed addressing:

     tile byte $00 -> tile 0    -> $9000 -> vram[0x1000]
     tile byte $7f -> tile 127  -> $97f0 -> vram[0x17f0]
     tile byte $80 -> tile -128 -> $8800 -> vram[0x0800]
     tile byte $ff -> tile -1   -> $8ff0 -> vram[0x0ff0]
*/
tile_data_offset :: proc(
    tile_number:      u8,
    signed_addressing: bool,
) -> int {
    if signed_addressing {
        signed_index := int(cast(i8)tile_number)
        return TILE_DATA_SIGNED + signed_index * 16
    }

    return TILE_DATA_UNSIGNED + int(tile_number) * 16
}

render_tile_to_pixels :: proc(
    vram:              []u8,
    tile_number:       u8,
    destination_x:     int,
    destination_y:     int,
    signed_addressing: bool,
) {
    tile_offset := tile_data_offset(
        tile_number,
        signed_addressing,
    )

    // Each tile occupies 16 bytes: two bytes per row.
    if tile_offset < 0 || tile_offset + 15 >= len(vram) {
        return
    }

    for pixel_y in 0 ..< TILE_HEIGHT {
        low_plane  := vram[tile_offset + pixel_y * 2]
        high_plane := vram[tile_offset + pixel_y * 2 + 1]

        for pixel_x in 0 ..< TILE_WIDTH {
            // Game Boy tile pixels are stored most-significant bit first.
            bit := 7 - pixel_x

            low_bit  := (low_plane  >> u8(bit)) & 1
            high_bit := (high_plane >> u8(bit)) & 1

            colour_index := int(low_bit | (high_bit << 1))

            output_x := destination_x + pixel_x
            output_y := destination_y + pixel_y
            output_index := output_y * TILEMAP_PX_WIDTH + output_x

            tilemap_pixels[output_index] =
                ACTIVE_PALETTE[colour_index]
        }
    }
}

set_debug_pixel :: proc(
    x, y:   int,
    colour: rl.Color,
) {
    // The background tilemap wraps at 256 pixels.
    wrapped_x := ((x % TILEMAP_PX_WIDTH) + TILEMAP_PX_WIDTH) %
                 TILEMAP_PX_WIDTH
    wrapped_y := ((y % TILEMAP_PX_HEIGHT) + TILEMAP_PX_HEIGHT) %
                 TILEMAP_PX_HEIGHT

    tilemap_pixels[
        wrapped_y * TILEMAP_PX_WIDTH + wrapped_x
    ] = colour
}

draw_wrapped_viewport_outline :: proc(
    scroll_x: u8,
    scroll_y: u8,
) {
    x := int(scroll_x)
    y := int(scroll_y)

    // Two-pixel outline so it remains visible when the texture is shown
    // at its native size.
    outer_colour := rl.Color { 255, 255, 255, 255 }

    inner_colour := rl.Color { 255, 32, 32, 255 }

    for thickness in 0 ..< 2 {
        colour := inner_colour
        if thickness == 0 {
            colour = outer_colour
        }

        left   := x + thickness
        right  := x + LCD_WIDTH - 1 - thickness
        top    := y + thickness
        bottom := y + LCD_HEIGHT - 1 - thickness

        for px in left ..= right {
            set_debug_pixel(px, top, colour)
            set_debug_pixel(px, bottom, colour)
        }

        for py in top ..= bottom {
            set_debug_pixel(left, py, colour)
            set_debug_pixel(right, py, colour)
        }
    }
}

draw_window_outline :: proc(
    scx, scy: u8,
    window_x: u8,
    window_y: u8,
) {
    x := int(window_x + scx) - 7
    y := int(window_y + scy)

    // Two-pixel outline so it remains visible when the texture is shown
    // at its native size.
    outer_colour := rl.Color { 255, 255, 255, 255 }

    inner_colour := rl.Color { 32, 255, 32, 255 }

    for thickness in 0 ..< 2 {
        colour := inner_colour
        if thickness == 0 {
            colour = outer_colour
        }

        left   := x + thickness
        right  := x + LCD_WIDTH - 1 - thickness
        top    := y + thickness
        bottom := y + LCD_HEIGHT - 1 - thickness

        for px in left ..= right {
            set_debug_pixel(px, top, colour)
            set_debug_pixel(px, bottom, colour)
        }

        for py in top ..= bottom {
            set_debug_pixel(left, py, colour)
            set_debug_pixel(right, py, colour)
        }
    }
}

build_tilemap_texture :: proc(
    vram: []u8,
    tilemap_offset: int,
    show_viewport:  bool,
    show_window: bool,
    scroll_x, scroll_y: u8,
    wx, wy: u8
) {
    if len(vram) < VRAM_SIZE {
        return
    }

    if tilemap_offset < 0 ||
       tilemap_offset + TILEMAP_WIDTH * TILEMAP_HEIGHT > len(vram) {
        return
    }

    for map_y in 0 ..< TILEMAP_HEIGHT {
        for map_x in 0 ..< TILEMAP_WIDTH {
            map_index :=
                tilemap_offset +
                map_y * TILEMAP_WIDTH +
                map_x

            tile_number := vram[map_index]

            render_tile_to_pixels(
                vram,
                tile_number,
                map_x * TILE_WIDTH,
                map_y * TILE_HEIGHT,
                signed_addressing
            )
        }
    }

    // Only overlay the viewport on the background map currently selected
    // by LCDC bit 3.
    if show_viewport {
        draw_wrapped_viewport_outline(
            scroll_x,
            scroll_y,
        )
    }

    if show_window {
        draw_window_outline(scroll_x, scroll_y, wx, wy)
    }

    rl.UpdateTexture(
        tilemap_texture,
        raw_data(tilemap_pixels[:]),
    )
}

draw_tilemap_image :: proc(
    emuCore: ^core.GB_Core,
    map_offset: int,
    map_number: int,
) {
    lcdc := emuCore.bus.read(&emuCore.bus, REG_LCDC, true)
    scy := emuCore.bus.read(&emuCore.bus, REG_SCY, true)
    scx := emuCore.bus.read(&emuCore.bus, REG_SCX, true)
    wx := emuCore.bus.read(&emuCore.bus, REG_WX, true)
    wy := emuCore.bus.read(&emuCore.bus, REG_WY, true)

    active_map_number := 0
    if lcdc & LCDC_BG_TILEMAP_SELECT != 0 {
        active_map_number = 1
    }

    show_viewport := map_number == active_map_number
    show_window := show_viewport && (lcdc & 0x20 != 0) 

    build_tilemap_texture(
        emuCore.ppu_state.vram.data[:],
        map_offset,
        show_viewport,
        show_window,
        scx,
        scy,
        wx,
        wy
    )

    imgui.Text(
        "SCX: %d  SCY: %d",
        scx,
        scy,
    )

    imgui.SameLine()

    if show_viewport {
        imgui.TextDisabled("Active background map")
    } else {
        imgui.TextDisabled("Inactive background map")
    }

    available := imgui.GetContentRegionAvail()

    scale_x := available.x / f32(TILEMAP_PX_WIDTH)
    scale_y := available.y / f32(TILEMAP_PX_HEIGHT)
    scale := min(scale_x, scale_y)
    scale = max(scale, 1.0)

    display_size := imgui.Vec2 {
        f32(TILEMAP_PX_WIDTH)  * scale,
        f32(TILEMAP_PX_HEIGHT) * scale,
    }

    imgui.Image(
        raylib_imgui_tex_ref(tilemap_texture),
        display_size,
        {0, 0},
        {1, 1},
    )
}

@(private)
imgui_display_tilemap_viewer :: proc(
    emuCore: ^core.GB_Core
) {
    if !UI_TILEMAP_VIEWER_ENABLED do return

    visible := imgui.Begin(
        "Game Boy Tilemaps",
        &UI_TILEMAP_VIEWER_ENABLED,
    )
    defer imgui.End()

    if !visible do return 
    if emuCore == nil || !emuCore.is_loaded do return

    if emuCore == nil {
        imgui.Text("Cannot display tilemaps: core is nil.")
        return
    }

    if len(emuCore.ppu_state.vram.data) < VRAM_SIZE {
        imgui.Text(
            "VRAM is too small: expected at least 0x%04X bytes, got 0x%04X.",
            VRAM_SIZE,
            len(emuCore.ppu_state.vram.data),
        )
        return
    }

    imgui.Checkbox(
        "Signed tile addressing (-128 to 127)",
        &signed_addressing,
    )

    if signed_addressing {
        imgui.TextDisabled(
            "Tile data: $8800-$97FF, indexed relative to $9000",
        )
    } else {
        imgui.TextDisabled(
            "Tile data: $8000-$8FFF, indexed 0-255",
        )
    }

    lcdc := emuCore.bus.read(&emuCore.bus, REG_LCDC)
    active_map_address := "$9800"

    if lcdc & LCDC_BG_TILEMAP_SELECT != 0 {
        active_map_address = "$9C00"
    }

    imgui.Text(
        "LCDC: $%02X  Active BG map: %s",
        lcdc,
        active_map_address,
    )

    wx := int(emuCore.bus.read(&emuCore.bus, REG_WX, true)) - 7
    wy := emuCore.bus.read(&emuCore.bus, REG_WY, true)
    active_map_address = (lcdc & 0x40 == 0) ? "$9800" : "$9C00"

    imgui.Text(
        "WX: %d WY: %d, Active Window map: %s",
        wx, wy, active_map_address
    )

    window_enabled := (lcdc & 0x20) != 0 ? "True" : "False"
    imgui.Text(
        "Window enabled: %s",
        window_enabled
    )

    if imgui.BeginTabBar("Tilemap tabs") {
        defer imgui.EndTabBar()

        if imgui.BeginTabItem("Map 1 - $9800") {
            selected_tilemap = 0

            draw_tilemap_image(
                emuCore,
                TILEMAP_1_OFFSET,
                0
            )

            imgui.EndTabItem()
        }

        if imgui.BeginTabItem("Map 2 - $9C00") {
            selected_tilemap = 1

            draw_tilemap_image(
                emuCore,
                TILEMAP_2_OFFSET,
                1
            )

            imgui.EndTabItem()
        }
    }
}
