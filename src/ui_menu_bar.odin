package main

import "core:os"
import "core:log"
import imgui "../libs/odin-imgui"
import imguirl "../libs/rlimgui"

import nfd "../libs/nativefiledialog"

imgui_menu_bar :: proc() {
    if imgui.BeginMainMenuBar() {
        if imgui.BeginMenu("File") {
            if imgui.MenuItem("Load", selected=false, enabled=!emulator_core.is_loaded) {
                filters := [2]nfd.Filter_Item { {"Gameboy Roms", "gb,bin"}, {"All Files", "*"} }
                args := nfd.Open_Dialog_Args{
                    filter_list = raw_data(filters[:]),
                    filter_count = len(filters)
                }

                path: cstring
                result := nfd.OpenDialogU8_With(&path, &args)
                switch result {
                    case .Okay: 
                        if emulator_core.is_loaded do unload_rom()

                        rom_file, err := os.open(string(path))
                        if err != nil {
                            //TODO: Throw error
                            nfd.FreePathU8(path)
                            return
                        }
                        load_rom(&boot_rom, rom_file)
                        nfd.FreePathU8(path)
                    case .Error: break
                    case .Cancel: break
                }
            }

            if imgui.MenuItem("Unload", selected=false, enabled=emulator_core.is_loaded) {
                unload_rom()
            }

            imgui.EndMenu()
        }

        if imgui.BeginMenu("Debug") {
            if imgui.MenuItem("Vram-Tiles") do UI_VRAM_TILES_VIEWER_ENABLED = !UI_VRAM_TILES_VIEWER_ENABLED
            if imgui.MenuItem("Tile-Maps") do UI_TILEMAP_VIEWER_ENABLED = !UI_TILEMAP_VIEWER_ENABLED

            imgui.EndMenu()
        }
        
        imgui.EndMainMenuBar()
    }
}