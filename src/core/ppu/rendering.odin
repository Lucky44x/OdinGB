#+private
package ppu

import "core:mem"
import "core:text/scanner"
import "core:crypto/x25519"
import c "../common"

DMG_COLORS := [4]u16 {
    0b11111_11111_11111_1, // White
    0b10101_10101_10101_1, // Light gray
    0b01010_01010_01010_1, // Dark gray
    0b00000_00000_00000_1, // Black
}

@(private="file")
SCANLINE_PIXEL_BUFFER: [160]u8

render_scanline :: proc(
    ppu: ^PPU
) {
    //TODO: Read CGB tile attributes from VRAM bank 1: palette, tile bank,
    //TODO: X/Y flip, and background priority. Implement window rendering too.
    LCDC := ppu.bus.read(ppu.bus, u16(c.IO_Regs.LCDC), force=true)
    wbg_enabled := LCDC & 1 != 0

    adressMode: AddressMode = LCDC & 0x10 != 0 ? .normal : .minus
    scanline := ppu.rend.current_line

    bg_tilemap : TileMap = LCDC & 0x08 != 0 ? .high : .low
    window_tilemap : TileMap = LCDC & 0x40 != 0 ? .high : .low

    SCX := ppu.bus.read(ppu.bus, u16(c.IO_Regs.SCX), force=true)
    SCY := ppu.bus.read(ppu.bus, u16(c.IO_Regs.SCY), force=true)
    WX := int(ppu.bus.read(ppu.bus, u16(c.IO_Regs.WX), force=true)) - 7
    WY := int(ppu.bus.read(ppu.bus, u16(c.IO_Regs.WY), force=true))

    WY_Condition := int(scanline) >= WY
    window_enabled := (LCDC & 0x20 != 0) && WY_Condition
    bg_realY := (u16(SCY) + u16(scanline)) & 0xFF // % 256

    bg_palette := ppu.bus.read(ppu.bus, u16(c.IO_Regs.BGP), force=true)
    ob_palette_0 := ppu.bus.read(ppu.bus, u16(c.IO_Regs.OBP0), force=true)
    ob_palette_1 := ppu.bus.read(ppu.bus, u16(c.IO_Regs.OBP1), force=true)

    pixel_tilemap := bg_tilemap

    if wbg_enabled {
        for x: u8 = 0; x < 160; x += 1 {
            realX := (u16(SCX) + u16(x)) & 0xFF // % 256
            realY := bg_realY
            if window_enabled && int(x) >= WX {
                realY = u16(int(scanline) - WY)
                realX = u16(int(x) - WX)

                pixel_tilemap = window_tilemap
            }

            tile_y := realY / 8
            tile_x := realX / 8

            tile_index := tile_x + (tile_y * 32)
            tile_id := ppu.bus.read(ppu.bus, u16(pixel_tilemap) + tile_index , force=true)

            fb_addr := u16(x) + (u16(scanline) * 160)
            color_id := get_tile_pixel(ppu.bus, tile_id, u8(realX % 8), u8(realY % 8), adressMode)

            SCANLINE_PIXEL_BUFFER[x] = (bg_palette >> (color_id * 2)) & 0x03
        
            //TODO: Choose between background pixel and window pixel when window is enabled
        }
    } else {
        mem.set(raw_data(&SCANLINE_PIXEL_BUFFER), 0x00, len(SCANLINE_PIXEL_BUFFER))
    }

    // Render Objects when enabled
    if LCDC & 0x02 != 0 {
        // Render OAM objects
        objects := collect_objects(ppu, scanline, LCDC)
        // Iterate over objects left -> right (lower priority is left, meaing right will overdraw)
        for obj in objects {
            if !obj.render do break 
            
            prio := obj.bg_priority
            x_base := obj.x_position
            palette := obj.palette == 0 ? ob_palette_0 : ob_palette_1

            for x in 0..<8 {
                pixel_idx := x_base + x
                if pixel_idx < 0 || pixel_idx >= 160 do continue

                object_color := obj.pixels[x]
                if object_color == 0 do continue // Transparent pixel

                // Priority only suppresses non-zero background pixels.
                if prio && SCANLINE_PIXEL_BUFFER[pixel_idx] != 0x00 do continue

                SCANLINE_PIXEL_BUFFER[pixel_idx] = (palette >> (object_color * 2)) & 0x03
            }
        }
    }

    ppu.callback.callback(ppu.callback.ctx, scanline, &SCANLINE_PIXEL_BUFFER)
}

get_tile_pixel :: proc(
    bus: ^c.Bus_Access,
    tile_id:  u8,
    pixel_x, pixel_y: u8,
    mode: AddressMode
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
