package common

PPU_Write :: proc(ctx: ^PPU_Access, addr: u16, val: u8)
PPU_Read :: proc(ctx: ^PPU_Access, addr: u16) -> u8

// The Framebuffer for the gameboy's screen
// Stored in R5G5B5A1 -> 5 bits each, 1 alpha bit => 16 bit per pixel
PPU_FrameBuffer :: [160 * 144]u16

PPU_Access :: struct {
    ctx: rawptr,
    
    write: PPU_Write,
    read: PPU_Read
}

pack_rgba555a1 :: proc(r, g, b: u16) -> u16 {
    return ((r & 0x1F) << 11) |
            ((g & 0x1F) << 6) |
            ((b & 0x1F) << 1) |
            1
}