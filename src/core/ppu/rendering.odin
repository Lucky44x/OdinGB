#+private
package ppu

import c "../common"

DMG_COLORS := [4]u16 {
    0b11111_11111_11111_1, // White
    0b10101_10101_10101_1, // Light gray
    0b01010_01010_01010_1, // Dark gray
    0b00000_00000_00000_1, // Black
}

render_scanline :: proc(
    ppu: ^PPU
) {
    /*
        TODO: Rendering procedure ->
            For current-line (LY) do:
                1. Collect background pixels from background tiles
                2. Collect 
                (3.) Walk OAM and calculate overlapping objects, and override necessary pixels in frame-buffer 
    */

    LCDC := ppu.bus.read(ppu.bus, u16(c.IO_Regs.LCDC), force=true)
    wbg_enabled := LCDC & 1 != 0

    adressMode: AddressMode = LCDC & 0x10 != 0 ? .normal : .minus
    scanline := ppu.rend.current_line

    bg_tilemap : TileMap = LCDC & 0x08 != 0 ? .low : .high

    SCX := ppu.bus.read(ppu.bus, u16(c.IO_Regs.SCX), force=true)
    SCY := ppu.bus.read(ppu.bus, u16(c.IO_Regs.SCY), force=true)

    realY := (u16(SCY) + u16(scanline)) & 0xFF // % 256

    for x: u8 = 0; x < 160; x += 1 {
        realX := (u16(SCX) + u16(x)) & 0xFF // % 256

        /* 
            Calculation for tile in bg map: 

            tile_internal_Y := 
            tile_internal_X := realX % 8
        */
        tile_y := realY / 8
        tile_x := realX / 8

        tile_index := tile_x + (tile_y * 32)
        tile_id := ppu.bus.read(ppu.bus, u16(bg_tilemap) + tile_index , force=true)

        // TODO: Render pixels here
        fb_addr := u16(x) + (u16(scanline) * 160)
        color_id := get_tile_pixel(ppu.bus, tile_id, u8(realX % 8), u8(realY % 8), adressMode)
        ppu.frameBuffer[fb_addr] = DMG_COLORS[color_id]
    }
}

get_tile_pixel :: proc(
    bus: ^c.Bus_Access,
    tile_id:  u8,
    pixel_x, pixel_y: u8,
    mode: AddressMode = .normal
) -> u8 {
    assert(pixel_x < 8)
    assert(pixel_y < 8)

    tile_addr: u16

    switch mode {
        case .normal: tile_addr = 0x8000 + u16(tile_id) * 16
        case .minus: 
            signed_id := cast(i8)tile_id
            tile_addr = cast(u16)(i32(0x9000) + i32(signed_id) * 16)
    }

    row_addr := tile_addr + u16(pixel_y) * 2

    low_byte := bus.read(bus, row_addr, true)
    high_byte := bus.read(bus, row_addr + 1, true)

    bit := 7 - pixel_x

    low_bit := (low_byte >> bit) & 1
    high_bit := (high_byte >> bit) & 1

    return low_bit | (high_bit << 1)
}