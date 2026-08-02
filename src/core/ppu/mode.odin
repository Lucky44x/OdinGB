#+private
package ppu

import "core:log"
import c "../common"

/*
    Returns the number of dots that have elapsed on the scanline
*/
step_ppu_state :: proc(
    ppu: ^PPU,
    elapsed_dots: u16,
) -> u16 {
    ppu.rend.line_dots += elapsed_dots;

    if ppu.rend.ppu_mode == .OAMScan {
        if ppu.rend.line_dots < 80 do return elapsed_dots // We stay inside the OAMScan mode and consume all dots
        switch_mode(ppu, .Drawing)

        apply_ppu_io_flags(ppu)
    }

    if ppu.rend.ppu_mode == .Drawing {
        if ppu.rend.line_dots < 252 do return elapsed_dots // We stay inside the Drawing mode and consume all dots
        
        render_scanline(ppu)
        switch_mode(ppu, .HorizontalBlank)

        apply_ppu_io_flags(ppu)
    }

    if ppu.rend.ppu_mode == .HorizontalBlank {
        if ppu.rend.line_dots < 456 do return elapsed_dots // We stay inside the Horizontal Blank and consume all dots

        // Calculate the number of consumed dots until end of scanline
        consumed := elapsed_dots - (ppu.rend.line_dots - 456)
        ppu.rend.current_line += 1

        // Choose next mode:
        if ppu.rend.current_line >= 144 do switch_mode(ppu, .VerticalBlank)
        else do switch_mode(ppu, .OAMScan)

        // Reset other parameters
        ppu.rend.line_dots = 0
        
        apply_ppu_io_flags(ppu)
        return consumed // Return out here to trigger the next scanline to be processed
    }

    if ppu.rend.ppu_mode == .VerticalBlank {
        if ppu.rend.line_dots < 456 do return elapsed_dots

        consumed := elapsed_dots - (ppu.rend.line_dots - 456) // Calculate consumed dots
        ppu.rend.current_line += 1 // Increment line at end of Scanline
        ppu.rend.line_dots = 0

        if ppu.rend.current_line >= 154 {
            switch_mode(ppu, .OAMScan)
            ppu.rend.current_line = 0
        }
        else do switch_mode(ppu, .VerticalBlank) // Redundant but better safe than sorry

        apply_ppu_io_flags(ppu)
        return consumed
    }

    // If none of the above have triggered, something most likely went very wrong
    return 0
}

switch_mode :: proc(
    ppu: ^PPU,
    newMode: PPU_Mode
) {
    changed_mode: bool = ppu.rend.ppu_mode != newMode
    ppu.rend.ppu_mode = newMode

    if !changed_mode do return
    STAT := ppu.bus.read(ppu.bus, u16(c.IO_Regs.STAT), true)
    LYC := ppu.bus.read(ppu.bus, u16(c.IO_Regs.LYC), true)

    if newMode == .HorizontalBlank && STAT & 0x08 != 0 do c.set_interrupt(ppu.bus, .Stat)
    if newMode == .VerticalBlank && STAT & 0x10 != 0 do c.set_interrupt(ppu.bus, .Stat)
    if newMode == .OAMScan && STAT & 0x20 != 0 do c.set_interrupt(ppu.bus, .Stat)

    if ppu.rend.current_line == LYC && STAT & 0x40 != 0 do c.set_interrupt(ppu.bus, .Stat)
}

apply_ppu_io_flags :: proc(
    ppu: ^PPU,
) {
    if ppu.rend.ppu_mode == .VerticalBlank && ppu.rend.line_dots == 0 do c.set_interrupt(ppu.bus, .VBlank)

    ppu.bus.write(ppu.bus, u16(c.IO_Regs.LY), ppu.rend.current_line, force=true) // Write LY
    lyc := ppu.bus.read(ppu.bus, u16(c.IO_Regs.LYC), force=true)

    stat_orig := ppu.bus.read(ppu.bus, u16(c.IO_Regs.STAT), force=true)
    
    if lyc == ppu.rend.current_line do stat_orig |= (1 << 2) // Set bit 2
    else do stat_orig &= 0xFB // Reset bit 2

    //TODO: Write mode 0 when LCDC.7 is disabled and implement LCD transitions.
    //TODO: Keep PPU dot timing independent from the CGB double-speed CPU clock.

    ppu_mode := u8(ppu.rend.ppu_mode) & 0x3
    stat_orig = (stat_orig & 0xFC) | ppu_mode // Clear the two lowest bits and then set them to our ppu_mode

    ppu.bus.write(ppu.bus, u16(c.IO_Regs.STAT), stat_orig, force=true) // Write combined new STAT state to the STAT register
}
