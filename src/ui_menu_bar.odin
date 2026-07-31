package main

import "core:os"
import "core:log"
import imgui "../libs/odin-imgui"
import imguirl "../libs/rlimgui"

import nfd "../libs/nativefiledialog"

imgui_menu_bar :: proc() {
    if imgui.BeginMainMenuBar() {
        if imgui.BeginMenu("File") {
            if boot_rom.is_loaded {
                if imgui.MenuItem("Load Rom", selected=false, enabled=!emulator_core.is_loaded) {
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

                if imgui.MenuItem("Unload Rom", selected=false, enabled=emulator_core.is_loaded) {
                    unload_rom()
                }
                
                if imgui.MenuItem("Reset", selected=false, enabled=emulator_core.is_loaded) {
                    reset_rom()
                }
            } else {
                if imgui.MenuItem("Load Boot-Rom", selected=false) {
                    filters := [2]nfd.Filter_Item { {"Gameboy Roms", "gb,bin"}, {"All Files", "*"} }
                    args := nfd.Open_Dialog_Args{
                        filter_list = raw_data(filters[:]),
                        filter_count = len(filters)
                    }

                    path: cstring
                    result := nfd.OpenDialogU8_With(&path, &args)
                    switch result {
                        case .Okay: 
                            bios_file, err := os.open(string(path))
                            if err != nil {
                                //TODO: Throw error
                                nfd.FreePathU8(path)
                                return
                            }
                            load_bios(&boot_rom, bios_file)
                            nfd.FreePathU8(path)
                        case .Error: break
                        case .Cancel: break
                    }
                }
            }

            imgui.EndMenu()
        } 

        if imgui.BeginMenu("Debug") {
            if imgui.MenuItem("DEBUG STEPPER") do UI_DEBUG_STEPPER_ENABLED = !UI_DEBUG_STEPPER_ENABLED
            if imgui.MenuItem("CPU") do UI_CPU_VIEWER_ENABLED = !UI_CPU_VIEWER_ENABLED
            if imgui.MenuItem("Vram-Tiles") do UI_VRAM_TILES_VIEWER_ENABLED = !UI_VRAM_TILES_VIEWER_ENABLED
            if imgui.MenuItem("Tile-Maps") do UI_TILEMAP_VIEWER_ENABLED = !UI_TILEMAP_VIEWER_ENABLED
            if imgui.MenuItem("Objects") do UI_OBJECT_VIEWER_ENABLED = !UI_OBJECT_VIEWER_ENABLED

            imgui.EndMenu()
        }
        
        imgui.EndMainMenuBar()
    }
}