package common

PPU_Write :: proc(ctx: ^PPU_Access, addr: u16, val: u8)
PPU_Read :: proc(ctx: ^PPU_Access, addr: u16) -> u8

PPU_Access :: struct {
    ctx: rawptr,
    
    write: PPU_Write,
    read: PPU_Read
}