#+private
package mmu

import "core:mem"

hram_get :: proc(
    ctx: ^MMU,
    $T: typeid,
    offset: u16 = 0
) -> T {
    p := mem.ptr_offset(ctx.hram, offset)
    return mem.reinterpret_copy(T, p)
}

hram_put :: proc(
    ctx: ^MMU,
    val: $T,
    offset: u16 = 0
) {
    dst := mem.ptr_offset(ctx.hram, offset)
    value: T = val
    _ = mem.copy(dst, &value, size_of(T))
}