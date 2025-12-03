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

render_dbg_map :: proc(
    ctx: ^PPU,
    map_mode: bool
) {
    //Render all 32 by 32 tiles
    for tY in 0..<u8(32) {
        for tX in 0..<u8(32) {
            tile_id := get_map_tile(ctx, tX, tY, map_mode ? 0x9800 : 0x9C00)
            tile_data := get_tile_data(ctx, tile_id)
            render_tile(ctx, tile_data, tX*8, tY*8, true)
        }
    } 
}