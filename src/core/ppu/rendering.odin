#+private
package ppu

import c "../common"

PPU_Mode :: enum(u8) {
    HorizontalBlank = 0,
    VerticalBlank = 1,
    OAMScan = 2,
    Drawing = 3,
}

PPU_Renderer :: struct {
    ppu_mode: PPU_Mode,
    line_dots, mode_dots: u16,
    current_line: u8
}

step_ppu_state :: proc(
    rend: ^PPU_Renderer,
    bus: ^c.Bus_Access,
    elapsed_dots: u16,
) {
    rend.line_dots += elapsed_dots
    rend.mode_dots += elapsed_dots

    switch rend.ppu_mode {
        case .OAMScan:
            if rend.mode_dots < 80 do return
            rend.mode_dots -= 80
            rend.ppu_mode = .Drawing
            return
        case .Drawing:
            if rend.mode_dots < 298 do return
            rend.mode_dots -= 298
            rend.ppu_mode = .HorizontalBlank
            
            //TODO: Draw Scanline

            return
        case .HorizontalBlank:
            if rend.mode_dots < 87 do return
            rend.mode_dots -= 87
            rend.current_line += 1

            if rend.current_line <= 143 do rend.ppu_mode = .OAMScan
            else {
                rend.ppu_mode = .VerticalBlank
                c.set_interrupt(bus, .VBlank)
            }
            return
        case .VerticalBlank:
            if rend.line_dots >= 465 {
                rend.line_dots = 0
                rend.current_line += 1
            }
            
            if rend.current_line >= 153 {
                rend.ppu_mode = .OAMScan
                rend.mode_dots = 0
                rend.line_dots = 0
                return
            }
            
            return
    }
}