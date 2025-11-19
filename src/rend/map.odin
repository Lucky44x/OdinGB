#+private
package rend

import "../mmu"

get_map_tile :: proc(
    ctx: ^PPU,
    tileX, tileY: u8,
    mapStart: u16
) -> u8 {
    map_addr : u16 = mapStart + (u16(tileX) + (u16(tileY) * 32))
    tile_idx := mmu.get(ctx.bus, u8, map_addr)
    return tile_idx
}

get_map_tile_8800 :: proc(
    ctx: ^PPU,
    tileX, tileY: u8,
    mapStart: u16
) -> i8 {
    map_addr : u16 = mapStart + (u16(tileX) + (u16(tileY) * 32))
    tile_idx := mmu.get(ctx.bus, i8, map_addr)
    return tile_idx
}