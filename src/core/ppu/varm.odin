#+private
package ppu

/*
    normal -> Tile-IDs 0-255
    minus -> Tile-IDs -128-127
*/
AddressMode :: enum(u16) {
    normal = 0x8000,
    minus = 0x9000
}

/*
    Both have 1024 tiles -> 32x32

    Low -> Tilemap 0x9800 - 0x9BFF
    High -> Tilemap 0x9C00 - 0x9FFF
*/
TileMap :: enum(u16) {
    low = 0x9800,
    high = 0x9C00
}

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

