#+private
package rend

import "../mmu"

get_map_tile :: proc(
    ctx: ^PPU,
    tileX, tileY: u8
) -> u8 {
    map_addr : u16 = 0x9800 + (u16(tileX) + (u16(tileY) * 32))
    tile_idx := mmu.get(ctx.bus, u8, map_addr)
    return tile_idx
}