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

import "core/common"

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

    // CLI Argument parsing
    CONF :: struct {
        bios: ^os.File `args:"name=bios-file,pos=0,file=r" usage:"The dmg_boot.bin"`,
        rom: ^os.File `args:"name=rom-file,pos=1,file=r" usage:"The game-rom"`
    }

    conf: CONF
    flags.parse_or_exit(&conf, os.args, .Odin)

    // Setup emulation environment
    emulation_setup(conf.bios, conf.rom)
    defer emulation_teardown(conf.bios)

    // Initialize the RL window
    rl.SetConfigFlags({ .WINDOW_RESIZABLE })
    rl.InitWindow(640, 576, "AcornGB")
    rl.SetTargetFPS(60)

    ui_init_imgui()

    for !rl.WindowShouldClose() {
        ui_update_imgui()

        // Emulation step
        emulation_step()

        // Rendering
        rl.BeginDrawing()
        rl.ClearBackground(rl.GRAY)

        ui_draw_imgui()
        rl.EndDrawing()
    }

    unload_rom()
    rl.CloseWindow()
}