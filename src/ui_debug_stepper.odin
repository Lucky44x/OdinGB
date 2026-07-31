#+private file
package main

import "core:fmt"
import "core:strings"
import imgui "../libs/odin-imgui"
import imguirl "../libs/rlimgui"

import c "core"
import cpu "core/cpu"

step_count: i32

@(private)
DEBUG_STEPPING_ENABLED: bool
@(private)
UI_DEBUG_STEPPER_ENABLED: bool = false

last_m_cycles: u16

draw_last_instruction :: proc(emuCore: ^c.GB_Core) {
    imgui.TextUnformatted("Last Instruction")
    imgui.Separator()

    instruction := emuCore.cpu_state.last_instruction
    if instruction == nil {
        imgui.TextDisabled("No instruction executed")
        return
    }

    byte_count := clamp(
        int(emuCore.cpu_state.last_instruction_length),
        0,
        len(emuCore.cpu_state.last_instruction_bytes),
    )

    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)

    for i in 0..<byte_count {
        if i != 0 {
            fmt.sbprint(&builder, " ")
        }

        fmt.sbprintf(
            &builder,
            "0x%02X",
            emuCore.cpu_state.last_instruction_bytes[i],
        )
    }

    bytes_text := strings.to_cstring(&builder)
    ins_name := strings.clone_to_cstring(instruction.name, context.temp_allocator)

    imgui.TextUnformatted(bytes_text)
    imgui.TextUnformatted(ins_name)
}

@(private)
imgui_display_debug_stepper :: proc(
    emuCore: ^c.GB_Core
) {
    if !UI_DEBUG_STEPPER_ENABLED do return

    visible := imgui.Begin("Debug Stepper", &UI_DEBUG_STEPPER_ENABLED)
    defer imgui.End()

    if !visible do return

    imgui.Checkbox("Step By Step Execution", &DEBUG_STEPPING_ENABLED)

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    imgui.SetNextItemWidth(120)
    imgui.InputInt(
        "Number of Steps",
        &step_count,
        1,   // Small increment button
        10,  // Large increment, usually Ctrl + click
    )
    step_count = max(1, step_count)
    imgui.Spacing()

    if imgui.Button("Step") {
        for i in 0..<step_count do last_m_cycles = c.step_emulation(emuCore)
    }

    imgui.Spacing()
    draw_last_instruction(emuCore)
}