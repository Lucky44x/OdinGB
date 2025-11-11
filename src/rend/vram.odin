package rend

import "core:fmt"
import "core:mem"

/*
    TILE-DATA:
        0x8000 - 0x97FF
        0x =
*/

vram_get :: proc(
    ctx: ^PPU,
    $T: typeid,
    offset: u16 = 0
) -> T {
    p := mem.ptr_offset(ctx.vram, offset)
    return mem.reinterpret_copy(T, p)
}

vram_put :: proc(
    ctx: ^PPU,
    val: $T,
    offset: u16 = 0
) {
    dst := mem.ptr_offset(ctx.vram, offset)
    value: T = val
    _ = mem.copy(dst, &value, size_of(T))
}

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
    ptr := mem.ptr_offset(ctx.vram, addr)
    dat = mem.reinterpret_copy([8]u16, ptr)
    return dat
}

get_tile_data_8800 :: proc(
    ctx: ^PPU,
    tile: i8,
) -> [8]u16 {
    dat: [8]u16
    addr: u16 = u16(i32(0x8000) + i32(tile) * 16) & 0xFFFF
    ptr := mem.ptr_offset(ctx.vram, addr)
    dat = mem.reinterpret_copy([8]u16, ptr)
    return dat
}