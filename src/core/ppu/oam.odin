#+private file
package ppu

@(private)
OAM :: struct {
    data: [160]u8
}

@(private)
read_oam :: proc(ctx: ^PPU, addr: u16) -> u8 { return ctx.oam.data[addr - 0xFE00] }
@(private)
write_oam :: proc(ctx: ^PPU, addr: u16, val: u8) { ctx.oam.data[addr - 0xFE00] = val }

/*
    OAM Entry:
    byte 0:
        Y position
    byte 1:
        X position
    byte 2:
        Tile Index: Specifies tile ID in 8x8 and 8x16 specifies Top tile (ID + 1 -> Bottom tile)
    byte 3:
        Attribute flags:
            [7] = Priority (0 NO, 1 BG and Window colors 1-3 are drawn over object)
            [6] = Y-Flip
            [5] = X-Flip
            [4] = DMG-Palette = OBP0, 1 = OPB1
            [3] (CGB) -> Bank in VRAM
            [2-0] (CGB) -> CGB Palette
*/