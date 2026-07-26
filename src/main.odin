package main

import "core"
import rl "vendor:raylib"

emulator_core: core.GB_Core 

main :: proc() {
    rl.SetTraceLogLevel(.WARNING)
    rl.InitWindow(640, 576, "AcornGB")
    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        // Rendering
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        rl.EndDrawing()

        // Logic
        if rl.IsFileDropped() {
            fileList := rl.LoadDroppedFiles()
            if fileList.count <= 1 do continue // Ignore anyting that isnt 1 single rom-file
            
        }
    }

    rl.CloseWindow()
}

load_rom :: proc() {
    // Initialize emulator core
    core.make_GB_Core(&emulator_core)
}