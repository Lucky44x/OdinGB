#+private file
package main

import "core"
import rl "vendor:raylib"

@(private)
emulation_check_input :: proc() {
    if rl.IsKeyPressed(.UP) do core.set_dpad(&emulator_core, .UP, true)
    else if rl.IsKeyReleased(.UP) do core.set_dpad(&emulator_core, .UP, false)
    if rl.IsKeyPressed(.DOWN) do core.set_dpad(&emulator_core, .DOWN, true)
    else if rl.IsKeyReleased(.DOWN) do core.set_dpad(&emulator_core, .DOWN, false)
    if rl.IsKeyPressed(.LEFT) do core.set_dpad(&emulator_core, .LEFT, true)
    else if rl.IsKeyReleased(.LEFT) do core.set_dpad(&emulator_core, .LEFT, false) 
    if rl.IsKeyPressed(.RIGHT) do core.set_dpad(&emulator_core, .RIGHT, true)
    else if rl.IsKeyReleased(.RIGHT) do core.set_dpad(&emulator_core, .RIGHT, false) 

    if rl.IsKeyPressed(.Z) do core.set_button(&emulator_core, .A, true)
    else if rl.IsKeyReleased(.Z) do core.set_button(&emulator_core, .A, false)
    if rl.IsKeyPressed(.X) do core.set_button(&emulator_core, .B, true)
    else if rl.IsKeyReleased(.X) do core.set_button(&emulator_core, .B, false)

    if rl.IsKeyPressed(.ENTER) do core.set_button(&emulator_core, .START, true)
    else if rl.IsKeyReleased(.ENTER) do core.set_button(&emulator_core, .START, false)
    if rl.IsKeyPressed(.BACKSPACE) do core.set_button(&emulator_core, .SELECT, true)
    else if rl.IsKeyReleased(.BACKSPACE) do core.set_button(&emulator_core, .SELECT, false)
}