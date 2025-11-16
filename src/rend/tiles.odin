package rend

import "core:fmt"
import "core:mem"
import "../mmu"

/*
    TILE-DATA:
        0x8000 - 0x97FF
        0x =
*/

get_tile_data :: proc{
    get_tile_data_8000,
    get_tile_data_8800
}

get_tile_data_8000 :: proc(
    ctx: ^PPU,
    tile: u8,
) -> [8]u16 {
    dat: [8]u16
    addr: u16 = 0x8000 + (u16(tile) * 16)
    dat = mmu.get(ctx.bus, [8]u16, addr)
    return dat
}

get_tile_data_8800 :: proc(
    ctx: ^PPU,
    tile: i8,
) -> [8]u16 {
    dat: [8]u16
    addr: u16 = u16(i32(0x9000) + i32(tile) * 16) & 0xFFFF
    dat = mmu.get(ctx.bus, [8]u16, addr)
    return dat
}