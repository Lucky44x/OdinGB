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
    line_dots: u16,
    current_line: u8
}

/*
    Returns the number of dots that have elapsed on the scanline
*/
step_ppu_state :: proc(
    rend: ^PPU_Renderer,
    bus: ^c.Bus_Access,
    elapsed_dots: u16,
) -> u16 {
    rend.line_dots += elapsed_dots;

    if rend.ppu_mode == .OAMScan {
        if rend.line_dots < 80 do return elapsed_dots // We stay inside the OAMScan mode and consume all dots
        rend.ppu_mode = .Drawing

        apply_ppu_io_flags(rend, bus)
    }

    if rend.ppu_mode == .Drawing {
        if rend.line_dots < 252 do return elapsed_dots // We stay inside the Drawing mode and consume all dots
        // TODO: Trigger scanline render here -> State transiton at end of Drawing mode
        rend.ppu_mode = .HorizontalBlank

        apply_ppu_io_flags(rend, bus)
    }

    if rend.ppu_mode == .HorizontalBlank {
        if rend.line_dots < 456 do return elapsed_dots // We stay inside the Horizontal Blank and consume all dots

        // Calculate the number of consumed dots until end of scanline
        consumed := elapsed_dots - (rend.line_dots - 456)
        rend.current_line += 1

        // Choose next mode:
        if rend.current_line >= 144 do rend.ppu_mode = .VerticalBlank 
        else do rend.ppu_mode = .OAMScan

        // Reset other parameters
        rend.line_dots = 0
        
        apply_ppu_io_flags(rend, bus)
        return consumed // Return out here to trigger the next scanline to be processed
    }

    if rend.ppu_mode == .VerticalBlank {
        if rend.line_dots < 456 do return elapsed_dots

        consumed := elapsed_dots - (rend.line_dots - 456) // Calculate consumed dots
        rend.current_line += 1 // Increment line at end of Scanline
        rend.line_dots = 0

        if rend.current_line >= 154 {
            rend.ppu_mode = .OAMScan
            rend.current_line = 0
        }
        else do rend.ppu_mode = .VerticalBlank // Redundant but better safe than sorry

        apply_ppu_io_flags(rend, bus)
        return consumed
    }

    // If none of the above have triggered, something most likely went very wrong
    return 0
}

apply_ppu_io_flags :: proc(
    rend: ^PPU_Renderer,
    bus: ^c.Bus_Access
) {
    if rend.ppu_mode == .VerticalBlank && rend.line_dots == 0 do c.set_interrupt(bus, .VBlank)
    //TODO: Evaluate STAT: The increment of rend.current_line means that STAT LCY = LY will always trigger at the start of the targetetd scanline

    bus.write(bus, u16(c.IO_Regs.LY), rend.current_line, force=true) // Write LY
    lyc := bus.read(bus, u16(c.IO_Regs.LYC), force=true)

    stat_orig := bus.read(bus, u16(c.IO_Regs.STAT), force=true)
    if lyc == rend.current_line do stat_orig |= (1 << 2) // Set bit 2
    else do stat_orig &= 0xFB // Reset bit 2

    //TODO: Write 0 to ppu_mode when PPU is disabled -> LCDC.7

    ppu_mode := u8(rend.ppu_mode) & 0x3
    stat_orig = (stat_orig & 0xFC) | ppu_mode // Clear the two lowest bits and then set them to our ppu_mode

    bus.write(bus, u16(c.IO_Regs.STAT), stat_orig, force=true) // Write combined new STAT state to the STAT register

    //TODO: Send interrupts depending on STAT
}