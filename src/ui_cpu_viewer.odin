#+private file
package main

import rl "vendor:raylib"

import imgui "../libs/odin-imgui"
import imguirl "../libs/rlimgui"

import c "core"
import cpu "core/cpu"

@(private)
UI_CPU_VIEWER_ENABLED: bool = false

@(private)
ui_init_cpu_viewer :: proc() {}

FLAG_Z :: u8(1 << 7)
FLAG_N :: u8(1 << 6)
FLAG_H :: u8(1 << 5)
FLAG_C :: u8(1 << 4)

flag_is_set :: proc(f, mask: u8) -> bool {
    return (f & mask) != 0
}

draw_register_u8 :: proc(
    name: cstring, value: u8
) {
    imgui.TableNextRow()

    imgui.TableSetColumnIndex(0)
    imgui.Text("%s", name)

    imgui.TableSetColumnIndex(1)
    imgui.Text("0x%02X", value)

    imgui.TableSetColumnIndex(2)
    imgui.Text("%d", value)
}

draw_register_u16 :: proc(name: cstring, value: u16) {
    imgui.TableNextRow()

    imgui.TableSetColumnIndex(0)
    imgui.Text("%s", name)

    imgui.TableSetColumnIndex(1)
    imgui.Text("0x%04X", value)

    imgui.TableSetColumnIndex(2)
    imgui.Text("%d", value)
}

draw_register_table_header :: proc() {
    imgui.TableSetupColumn("Register")
    imgui.TableSetupColumn("Hex")
    imgui.TableSetupColumn("Decimal")
    imgui.TableHeadersRow()
}

draw_flag_indicator :: proc(name: cstring, enabled: bool) {
    if enabled {
        imgui.Text("[%s]", name)
    } else {
        imgui.TextDisabled("[%s]", name)
    }

    imgui.SameLine()
}

draw_compact_flags :: proc(f: u8) {
    imgui.Text("Flags:")
    imgui.SameLine()

    draw_flag_indicator("Z", flag_is_set(f, FLAG_Z))
    draw_flag_indicator("N", flag_is_set(f, FLAG_N))
    draw_flag_indicator("H", flag_is_set(f, FLAG_H))
    draw_flag_indicator("C", flag_is_set(f, FLAG_C))

    imgui.NewLine()
}

@(private)
imgui_display_cpu_viewer :: proc(
    emuCore: ^c.GB_Core
) {
    if !UI_CPU_VIEWER_ENABLED do return

    visible := imgui.Begin("CPU State", &UI_CPU_VIEWER_ENABLED)
    defer imgui.End()

    imgui.Checkbox("Paused", &emuCore.cpu_state.paused)
    
    state: cstring
    switch emuCore.cpu_state.state {
        case .Running: state = "Running"
        case .Halted: state = "Halted"
        case .Stopped: state = "Stopped"
    }
    imgui.Text("State: %s", state)


    outer_flags :=
        imgui.TableFlags_BordersInnerV |
        imgui.TableFlags_Resizable |
        imgui.TableFlags_SizingStretchProp

    if imgui.BeginTable("cpu_registers_panels", 2, outer_flags) {
        imgui.TableNextRow()

        // ------------------------------------------------------------
        // Left panel: 8-bit registers
        // ------------------------------------------------------------

        imgui.TableSetColumnIndex(0)

        imgui.Text("8-bit Registers")
        imgui.Separator()

        register_flags :=
            imgui.TableFlags_Borders |
            imgui.TableFlags_RowBg |
            imgui.TableFlags_SizingStretchProp

        if imgui.BeginTable("registers_8_bit", 3, register_flags) {
            draw_register_table_header()

            draw_register_u8("A", cpu.read_r8(&emuCore.cpu_state, .A))
            draw_register_u8("F", cpu.read_r8(&emuCore.cpu_state, .F))
            draw_register_u8("B", cpu.read_r8(&emuCore.cpu_state, .B))
            draw_register_u8("C", cpu.read_r8(&emuCore.cpu_state, .C))
            draw_register_u8("D", cpu.read_r8(&emuCore.cpu_state, .D))
            draw_register_u8("E", cpu.read_r8(&emuCore.cpu_state, .E))
            draw_register_u8("H", cpu.read_r8(&emuCore.cpu_state, .H))
            draw_register_u8("L", cpu.read_r8(&emuCore.cpu_state, .L))

            imgui.EndTable()
        }

        // ------------------------------------------------------------
        // Right panel: 16-bit registers
        // ------------------------------------------------------------

        imgui.TableSetColumnIndex(1)

        imgui.Text("16-bit Registers")
        imgui.Separator()

        if imgui.BeginTable("registers_16_bit", 3, register_flags) {
            draw_register_table_header()

            draw_register_u16("AF", cpu.read_r16(&emuCore.cpu_state, .AF))
            draw_register_u16("BC", cpu.read_r16(&emuCore.cpu_state, .BC))
            draw_register_u16("DE", cpu.read_r16(&emuCore.cpu_state, .DE))
            draw_register_u16("HL", cpu.read_r16(&emuCore.cpu_state, .HL))
            draw_register_u16("SP", cpu.read_r16(&emuCore.cpu_state, .SP))
            draw_register_u16("PC", cpu.read_r16(&emuCore.cpu_state, .PC))

            imgui.EndTable()
        }

        draw_compact_flags(cpu.read_r8(&emuCore.cpu_state, .F))

        imgui.EndTable()
    }
}