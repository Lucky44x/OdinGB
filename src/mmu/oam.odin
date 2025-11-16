#+private
package mmu

import "core:mem"

oam_get :: proc(
    ctx: ^MMU,
    $T: typeid,
    offset: u16 = 0
) -> T {
    p := mem.ptr_offset(ctx.oam, offset)
    val := mem.reinterpret_copy(T, p)
    return val
}

oam_put :: proc(
    ctx: ^MMU,
    val: $T,
    offset: u16 = 0
) {
    dst := mem.ptr_offset(ctx.oam, offset)
    value: T = val
    _ = mem.copy(dst, &value, size_of(T))
}