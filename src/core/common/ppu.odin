package common

PPU_Write :: proc(ctx: ^PPU_Access, addr: u16, val: u8)
PPU_Read :: proc(ctx: ^PPU_Access, addr: u16) -> u8

PPU_ScanlineCallback :: proc(ctx: rawptr, scanline: u8, pixels: ^[160]u8)
//TODO: Replace 2-bit scanline pixels with a BGR555 framebuffer or color-aware
//TODO: callback so CGB palettes can reach the frontend.

PPU_Callback :: struct {
    ctx: rawptr,
    callback: PPU_ScanlineCallback
}

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
