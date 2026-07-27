package cart

import "core:log"
import c "../common"

ROM_Read :: proc(ctx: rawptr, out: ^[]u8, lower: u32, size: int) -> bool

ROM_Access :: struct {
    ctx: rawptr,
    read: ROM_Read
}

ROM_Source :: union {
    ROM_Buffered,
    ROM_Bulk
}

Cartridge :: struct {
    mapper: ROM_Mapper,
    rom: ROM_Source,
    //TODO: Implement external RAM
}

cartridge_load_buffered :: proc(
    cart: ^Cartridge,
    file_accessor: ^ROM_Access,
    max_buffered_banks: int
) {
    // TODO: Load Mapper etc from cart header
    cart_header: []u8 = make([]u8, 79)
    defer delete(cart_header)

    ok := file_accessor.read(file_accessor.ctx, &cart_header, 0x0100, 0x4F)
    if !ok do log.errorf("Error while reading cart-header...")

    cart.rom = init_buffered_rom(0, file_accessor, 0)
    for i in 0..<max_buffered_banks do cart.rom.(ROM_Buffered).bank_indecies[i] = -1
}

cartridge_load_direct :: proc(
    cart: ^Cartridge,
    data: []u8
) {
    read_cart_header(data[0x0100:0x014F])
    cart.rom = init_bulk_rom(data)
    cart.mapper = MAPPER_Basic
}

cartridge_unload :: proc(
    cart: ^Cartridge
) {
    switch type in cart.rom {
        case ROM_Buffered:
            delete(type.ages)
            delete(type.bank_indecies)
            delete(type.banks)
            return
        case ROM_Bulk:
            delete(type.data)
            return
    }
}

get_cart_accessor :: proc(
    cart: ^Cartridge
) -> c.CART_Access {
    return {
        ctx = cart,
        read_rom = cart_read_adapter,
        write_ram = cart_write_adapter
    }
}

@(private)
cart_read_adapter :: proc(cart: ^c.CART_Access, addr: u16) -> u8 { return cartridge_read(cast(^Cartridge)cart.ctx, addr) }
@(private)
cartridge_read :: proc(
    ctx: ^Cartridge,
    addr: u16
) -> u8 {
    phys_addr := ctx.mapper.map_addr(&ctx.mapper, addr)
    value: u8

    switch &type in ctx.rom {
        case ROM_Buffered:
            return read_rom_buffered(&type, phys_addr)
        case ROM_Bulk:
            return read_rom_bulk(&type, phys_addr)
    }
    return 0xFF
}

@(private)
cart_write_adapter :: proc(cart: ^c.CART_Access, addr: u16, val: u8) { cartridge_write(cast(^Cartridge)cart.ctx, addr,val) }
@(private)
cartridge_write :: proc(
    ctx: ^Cartridge,
    addr: u16,
    val: u8
) {
    //TODO: STUB implement later
}