#+private
package ppu

VRAM :: struct {
    //TODO: Allow banking for GBC implementation
    data: [0x2000]u8
}

read_vram :: proc(
    ctx: ^VRAM,
    addr: u16,
) -> u8 {
    return ctx.data[addr - 0x8000]
}

write_vram :: proc(
    ctx: ^VRAM,
    addr: u16,
    val: u8
) {
    ctx.data[addr - 0x8000] = val
}