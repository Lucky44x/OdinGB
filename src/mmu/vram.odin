#+private
package mmu

import "core:fmt"
import "core:mem"

vram_get :: proc(
    ctx: ^MMU,
    $T: typeid,
    offset: u16 = 0
) -> T {
    p := mem.ptr_offset(ctx.vram, offset)
    val := mem.reinterpret_copy(T, p)
    return val
}

vram_put :: proc(
    ctx: ^MMU,
    val: $T,
    offset: u16 = 0
) {
    dst := mem.ptr_offset(ctx.vram, offset)
    value: T = val
    _ = mem.copy(dst, &value, size_of(T))
}