package common

CART_Read :: proc(cart: ^CART_Access, addr: u16) -> u8
CART_Write :: proc(cart: ^CART_Access, addr: u16, val: u8)

CART_Access :: struct {
    ctx: rawptr,
    
    read_rom: CART_Read,
    write_ram: CART_Write
}