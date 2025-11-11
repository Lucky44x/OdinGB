package rend

import "core:mem"

oam_get :: proc(
    ctx: ^PPU,
    $T: typeid,
    offset: u16 = 0
) -> T {
    p := mem.ptr_offset(ctx.oam, offset)
    return mem.reinterpret_copy(T, p)
}

oam_put :: proc(
    ctx: ^PPU,
    val: $T,
    offset: u16 = 0
) {
    dst := mem.ptr_offset(ctx.oam, offset)
    value: T = val
    _ = mem.copy(dst, &value, size_of(T))
}