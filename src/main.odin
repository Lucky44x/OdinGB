package main

import "core:mem"
import "core:fmt"
import "core:log"
import "core:strings"
import "core:path/filepath"
import "core"
import rl "vendor:raylib"
import "core:flags"
import "core:os"

emulator_core: core.GB_Core 
boot_rom: core.GB_Bios

main :: proc() {
    logger := log.create_console_logger(.Debug)
    context.logger = logger
    defer log.destroy_console_logger(logger)
    
    // Tracking allocator during debug
    when ODIN_DEBUG {
        log.info("DEBUG ENABLED")

        track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				log.errorf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					log.errorf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			} else do log.info("=== ALL ALLOCATIONS FREED :)")

			if len(track.bad_free_array) > 0 {
				log.errorf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					log.errorf("- %p @ %v\n", entry.memory, entry.location)
				}
			} else do log.info("=== NO INCORRECT FREES :)")
			mem.tracking_allocator_destroy(&track)
		}
    }

    CONF :: struct {
        bios: ^os.File `args:"name=bios-file,pos=0,required,file=r" usage:"The dmg_boot.bin"`
    }

    conf: CONF
    flags.parse_or_exit(&conf, os.args, .Odin)

    load_bios(&boot_rom, conf.bios)
    defer unload_bios(&boot_rom, conf.bios)

    //rl.SetTraceLogLevel(.WARNING)
    rl.InitWindow(640, 576, "AcornGB")
    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        // Rendering
        rl.BeginDrawing()
        rl.ClearBackground(rl.GRAY)

        rl.EndDrawing()

        // Logic
        if rl.IsFileDropped() {
            fileList := rl.LoadDroppedFiles()
            if fileList.count != 1 { 
                notify("Could not load rom", "Too many files")
                rl.UnloadDroppedFiles(fileList)
                continue
            }// Ignore anyting that isnt 1 single rom-file

            newFilePath := strings.clone_from_cstring(fileList.paths[0])
            defer delete(newFilePath)

            if filepath.ext(newFilePath) != ".gb" {
                notify("Could not load rom", "%s is not a GameBoy rom", filepath.base(newFilePath))
                rl.UnloadDroppedFiles(fileList)
                continue
            }

            f, err := os.open(newFilePath)
            if err != nil {
                notify("Could not load rom", "Error while reading %s: %e", filepath.base(newFilePath), err)
                rl.UnloadDroppedFiles(fileList)
                continue
            }
            else do load_rom(&boot_rom, f)

            rl.UnloadDroppedFiles(fileList)
        }
    }

    rl.CloseWindow()
}

load_bios :: proc(bios: ^core.GB_Bios, file: ^os.File) {
    err: os.Error
    bios.fileName = os.name(file)
    bios.data, err = os.read_entire_file_from_file(file, context.allocator)
    if err != nil do log.errorf("Error while loading %s", bios.fileName)
    else do log.infof("Loaded bios: %s = %d bytes", bios.fileName, len(bios.data))
}

unload_bios :: proc(bios: ^core.GB_Bios, file: ^os.File) {
    delete(bios.data)
    os.close(file)
}

load_rom :: proc(bios: ^core.GB_Bios, rom: ^os.File) {
    // Load Cartridge in direct mode
    rom_cart: core.GB_Cartridge

    rom_data, err := os.read_entire_file_from_file(rom, context.allocator)
    defer delete(rom_data)
    if err != nil {
        log.errorf("Could not read rom: %e", err)
        return
    }
    core.cartridge_load(&rom_cart, &rom_data)

    // Initialize emulator core
    core.make_GB_Core(&emulator_core)
}