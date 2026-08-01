#+private file
package ppu

import "core:log"
@(private)
OAM :: struct {
    data: [160]u8
}

@(private)
OAM_Entry :: struct {
    render, bg_priority: bool,
    palette: u8,
    x_position: int,
    pixels: [8]u8
}

@(private)
read_oam :: proc(ctx: ^PPU, addr: u16) -> u8 { return ctx.oam.data[addr - 0xFE00] }
@(private)
write_oam :: proc(ctx: ^PPU, addr: u16, val: u8) { ctx.oam.data[addr - 0xFE00] = val }

/*
    OAM Entry:
    byte 0:
        Y position
    byte 1:
        X position
    byte 2:
        Tile Index: Specifies tile ID in 8x8 and 8x16 specifies Top tile (ID + 1 -> Bottom tile)
    byte 3:
        Attribute flags:
            [7] = Priority (0 NO, 1 BG and Window colors 1-3 are drawn over object)
            [6] = Y-Flip
            [5] = X-Flip
            [4] = DMG-Palette = OBP0, 1 = OPB1
            [3] (CGB) -> Bank in VRAM
            [2-0] (CGB) -> CGB Palette
*/

// Collects the 10 objects in AOM that should be rendered, and returns them sorted by their X-positions
@(private)
collect_objects :: proc(
    ctx: ^PPU,
    scanline: u8,
    LCDC: u8
) -> (out: [10]OAM_Entry) {

    mode_16px := LCDC & 0x04 != 0
    collected := 0

    // Walk along all OAM entries, but collect only the first 10 that fit our scanline
    for i in 0..<40 {
        obj_addr := 0xFE00 + (u16(i) * 4)
        pos_y := int(read_oam(ctx, obj_addr)) - 16
        if pos_y <= -16 do continue // Generellay off-screen, no need to check overlap

        allowed_offset := mode_16px ? 16 : 8
        offset := int(scanline) - int(pos_y)

        if offset < 0 || offset >= allowed_offset do continue
        insert_and_sort(
            collect_OAM_entry(ctx, obj_addr, scanline, u8(offset), mode_16px),
            &out
        )
        collected += 1
        if collected >= 10 do break
    }

    return // Return out with the values written to the out-array
}

insert_and_sort :: proc(
    newValue: OAM_Entry,
    arr: ^[10]OAM_Entry
) {
    carrying := newValue
    
    for i in 0..<10 {
        if carrying.render == false do return   // Break once we have swapped with a nil entry

        if arr[i].render != false {
            if arr[i].x_position > carrying.x_position do continue
        }

        tmp := arr[i]
        arr[i] = carrying
        carrying = tmp
    }
}

collect_OAM_entry :: proc(
    ctx: ^PPU,
    obj_addr: u16,
    scanline, obj_tile_y: u8,
    mode_16px: bool
) -> (out: OAM_Entry) {
    pos_x := int(read_oam(ctx, obj_addr + 1)) - 8
    out.x_position = pos_x
    out.render = true
    obj_attr := read_oam(ctx, obj_addr + 3)
    out.bg_priority = obj_attr & 0x80 != 0
    out.palette = (obj_attr >> 4) & 1

    collect_object_pixels(ctx, obj_addr, scanline, obj_tile_y, mode_16px, &out.pixels)
    return // Return out with the Completed OAM_Entry record
}

/*
    Collects the pixels of a given Object
    TODO: IN CGB Mode, Priority in "drawing" will only rely on the Position of the Object in OAM, not X-Position
*/
collect_object_pixels :: proc(
    ctx: ^PPU,
    obj_addr: u16,
    scanline, obj_tile_y: u8,
    mode_16px: bool,

    pixels_out: ^[8]u8
) {
    obj_attr := read_oam(ctx, obj_addr + 3)

    tile_flip_x := obj_attr & 0x20 != 0
    tile_flip_y := obj_attr & 0x40 != 0

    sprite_height: u8 = mode_16px ? 16 : 8
    internal_y := obj_tile_y
    if tile_flip_y do internal_y = sprite_height - 1 - internal_y

    tile_id := read_oam(ctx, obj_addr + 2)
    if mode_16px do tile_id &= 0xFE
    if mode_16px && internal_y >= 8 {
        tile_id += 1
        internal_y -= 8
    }

    for i in 0..<8 {
        insert_idx := tile_flip_x ? 7 - u8(i) : u8(i)
        pixels_out[insert_idx] = get_tile_pixel(ctx.bus, tile_id, u8(i), internal_y, .normal)
    }
}
