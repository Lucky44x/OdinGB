#+private
package mmu

import "core:fmt"
import "core:mem"

hram_get :: proc(
    ctx: ^MMU,
    $T: typeid,
    offset: u16 = 0
) -> T {
    p := mem.ptr_offset(ctx.hram, offset)
    val := mem.reinterpret_copy(T, p)
    fmt.printfln("Getting from HRAM addr: %#04X = %#02X", offset + 0xFF80, val)
    return val
}

hram_put :: proc(
    ctx: ^MMU,
    val: $T,
    offset: u16 = 0
) {
    fmt.printfln("Writing to HRAM addr: %#04X = %#02X", offset + 0xFF80, val)
    dst := mem.ptr_offset(ctx.hram, offset)
    value: T = val
    _ = mem.copy(dst, &value, size_of(T))
}