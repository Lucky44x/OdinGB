#+private file
package main

import "core:fmt"
import "core:flags"
import "core:log"
import rl "vendor:raylib"
import imgui "../libs/odin-imgui"
import imguirl "../libs/rlimgui"
import "core"

OBJECT_COUNT :: 40

OBJECT_WIDTH_8 :: 8
OBJECT_HEIGHT_8 :: 8

OBJECT_WIDTH_16 :: 8
OBJECT_HEIGHT_16 :: 16

OBJECT_BUFFER_SIZE :: OBJECT_WIDTH_8 * OBJECT_HEIGHT_8

Object_Meta :: struct { pos_x, pos_y, tile_id, flags: u8 }

@(private)
UI_OBJECT_VIEWER_ENABLED := false

selected_object: int = -1

object_metas: [OBJECT_COUNT]Object_Meta
object_textures: [OBJECT_COUNT]rl.Texture2D
object_pixels: [40][OBJECT_BUFFER_SIZE]rl.Color // Support both 8x8 and 8x16

@(private)
ui_init_object_viewer :: proc() {
    image := rl.GenImageColor(OBJECT_WIDTH_8, OBJECT_HEIGHT_8, ACTIVE_PALETTE[0])
    defer rl.UnloadImage(image)

    for i in 0..<OBJECT_COUNT {
        object_textures[i] = rl.LoadTextureFromImage(image)
        rl.SetTextureFilter(object_textures[i], .POINT)
    }
}

ui_update_object :: proc(
    emuCore: ^core.GB_Core,
    object_id: int
) {
    //TODO: Render CGB sprite bank, palette, priority, and correct 8x16 tiles.
    if !emuCore.is_loaded do return

    oam_addr := 0xFE00 + u16(object_id) * 4
    tile_id := emuCore.bus.read(&emuCore.bus, oam_addr + 2, true)

    object_metas[object_id].pos_y = emuCore.bus.read(&emuCore.bus, oam_addr, true)
    object_metas[object_id].pos_x = emuCore.bus.read(&emuCore.bus, oam_addr + 1, true)
    object_metas[object_id].tile_id = tile_id
    object_metas[object_id].flags = emuCore.bus.read(&emuCore.bus, oam_addr + 3, true)

    ui_render_tile(emuCore, tile_id, &object_pixels[object_id])
    rl.UpdateTexture(object_textures[object_id], raw_data(&object_pixels[object_id]))
}

ui_render_tile :: proc(
    emuCore: ^core.GB_Core,
    tile_id: u8,
    buffer: ^[OBJECT_BUFFER_SIZE]rl.Color
) {
    tile_offset := u16(tile_id) * BYTES_PER_TILE

    for pixel_y in 0..<TILE_HEIGHT {
        low := emuCore.bus.read(&emuCore.bus, 0x8000 + tile_offset + (u16(pixel_y) * 2), true)
        hi := emuCore.bus.read(&emuCore.bus, 0x8000 + tile_offset + (u16(pixel_y) * 2) + 1, true)

        for pixel_x in 0 ..< TILE_WIDTH {
            // Game Boy tile pixels are stored most-significant bit first.
            bit := 7 - pixel_x

            low_bit  := (low  >> u8(bit)) & 1
            high_bit := (hi >> u8(bit)) & 1

            colour_index := int(low_bit | (high_bit << 1))

            output_index := pixel_x + (pixel_y * TILE_WIDTH)
            buffer[output_index] = ACTIVE_PALETTE[colour_index]
        }
    }
}

@(private)
imgui_display_object_viewer :: proc(
    emuCore: ^core.GB_Core
) {
    if !UI_OBJECT_VIEWER_ENABLED do return

    visible := imgui.Begin("Object Viewer", &UI_OBJECT_VIEWER_ENABLED)
    defer imgui.End()

    if !visible do return

    outer_flags :=
        imgui.TableFlags_BordersInnerV |
        imgui.TableFlags_Resizable |
        imgui.TableFlags_SizingStretchProp

    if imgui.BeginTable("object_viewer_outer", 2, outer_flags) {
        imgui.TableNextRow()
        imgui.TableSetColumnIndex(0)
        imgui.Text("Inspector")
        imgui.Separator()

        ui_draw_inspector()

        imgui.TableSetColumnIndex(1)

        inner_flags :=
            imgui.TableFlags_Borders |
            imgui.TableFlags_SizingStretchSame

        if imgui.BeginTable("object_viewer_cards", 8, inner_flags) {
            for i in 0..<OBJECT_COUNT {
                ui_update_object(emuCore, i)
                ui_draw_object(i)
            }
            
            imgui.EndTable()
        }

        imgui.EndTable()
    }
}

ui_draw_inspector :: proc() {
    if selected_object == -1 do return

    imgui.Text("Tile-ID: %d %#02X", object_metas[selected_object].tile_id, object_metas[selected_object].tile_id)
    imgui.Text("PosX: %d %#02X", object_metas[selected_object].pos_x, object_metas[selected_object].pos_x)
    imgui.Text("PosY: %d %#02X", object_metas[selected_object].pos_y, object_metas[selected_object].pos_y)

    if object_metas[selected_object].flags & 0x80 != 0 do imgui.Text("[P]")
    else do imgui.TextDisabled("[P]")
    imgui.SameLine()
    if object_metas[selected_object].flags & 0x40 != 0 do imgui.Text("[Y]")
    else do imgui.TextDisabled("[Y]")
    imgui.SameLine()
    if object_metas[selected_object].flags & 0x20 != 0 do imgui.Text("[X]")
    else do imgui.TextDisabled("[X]")

    if object_metas[selected_object].flags & 0x10 != 0 do imgui.Text("[PAL]")
    else do imgui.TextDisabled("[PAL]")
    imgui.SameLine()
    if object_metas[selected_object].flags & 0x08 != 0 do imgui.Text("[B]")
    else do imgui.TextDisabled("[B]")

    imgui.Image(
        raylib_imgui_tex_ref(object_textures[selected_object]),
        imgui.GetContentRegionAvail()
    )
}

ui_draw_object :: proc(
    object_idx: int
) {
    if object_idx < 0 || object_idx >= OBJECT_COUNT do return

    cell_size := imgui.Vec2{92, 92}
    imgui.PushIDInt(i32(object_idx))
    imgui.TableNextColumn() 

    imgui.Image(
        raylib_imgui_tex_ref(object_textures[object_idx]),
        cell_size
    )
    label: cstring = fmt.ctprintf("%d",object_idx)
    if imgui.Selectable(label, selected_object == object_idx, {}, {cell_size.x, cell_size.y/4}) do selected_object = object_idx

    //if imgui.Selectable("object-select-##xx", selected_object == object_idx, {}) do selected_object = object_idx
    imgui.PopID()
}
