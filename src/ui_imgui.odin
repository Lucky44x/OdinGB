package main

import imgui "../libs/odin-imgui"
import imgui_rl "../libs/rlimgui"
import nfd "../libs/nativefiledialog"

import rl "vendor:raylib"

TILE_WIDTH :: 8
TILE_HEIGHT :: 8
BYTES_PER_TILE :: 16
TILE_COUNT :: 384

dmg_palette := [4]rl.Color {
    {224, 248, 208, 255},
    {136, 192, 112, 255},
    {52, 104, 86, 255},
    {8, 24, 32, 255},
}

ui_init_imgui :: proc() {
    nfd.Init()
    imgui.CreateContext(nil)
    imgui_rl.init()

    ui_init_vram_tiles_viewer()
    ui_init_tilemap_viewer()
    ui_init_cpu_viewer()
}

ui_deinit_imgui :: proc() {
    nfd.Quit()
	imgui.DestroyContext(nil)
	imgui_rl.shutdown()
}

ui_update_imgui :: proc() {
    imgui_rl.process_events()
    imgui_rl.new_frame()
    imgui.NewFrame()
}

ui_draw_imgui :: proc() {
    imgui_menu_bar()
    imgui_display_vram_tiles_viewer(emulator_core.ppu_state.vram.data[:])
    imgui_display_tilemap_viewer(&emulator_core)
    imgui_display_cpu_viewer(&emulator_core)
    imgui_display_debug_stepper(&emulator_core)

    imgui.Render()
    imgui_rl.render_draw_data(imgui.GetDrawData())
}

raylib_imgui_tex_ref :: proc(texture: rl.Texture2D) -> imgui.TextureRef {
    return imgui.TextureRef {
        _TexID = imgui.TextureID(texture.id)
    }
}