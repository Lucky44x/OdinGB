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
    loaded: bool,
    external_ram: []u8,
    mapper: ROM_Mapper,

    rom: ROM_Source,

    //TODO: Implement external RAM
    //TODO: Store cartridge mode, RAM/battery state, and mapper-specific state
    //TODO: including MBC3 RTC data and MBC5 bank registers.
}

cartridge_load_buffered :: proc(
    cart: ^Cartridge,
    file_accessor: ^ROM_Access,
    max_buffered_banks: int
) {
    cart.loaded = true

    // TODO: Load Mapper etc from cart header
    cart_header: []u8 = make([]u8, 79)
    defer delete(cart_header)

    ok := file_accessor.read(file_accessor.ctx, &cart_header, 0x0100, 0x4F)
    if !ok do log.errorf("Error while reading cart-header...")

    cart.rom = init_buffered_rom(0, file_accessor, 0)
    for i in 0..<max_buffered_banks do cart.rom.(ROM_Buffered).bank_indecies[i] = -1

    read_cart_header(cart, cart.rom.(ROM_Buffered).banks[0][0x0100:0x014F])
}

cartridge_load_direct :: proc(
    cart: ^Cartridge,
    data: []u8
) {
    cart.loaded = true
    cart.rom = init_bulk_rom(data)
    
    read_cart_header(cart, data[0x0100:0x014F])
}

cartridge_init :: proc(
    cart: ^Cartridge,
    mapper: ROM_Mapper
) {
    cart.mapper = mapper
    if cart.mapper.ram_size > 0 do cart.external_ram = make([]u8, cart.mapper.ram_size)
    else do cart.external_ram = nil
}

cartridge_unload :: proc(
    cart: ^Cartridge
) {
    if !cart.loaded do return
    cart.loaded = false

    if cart.external_ram != nil do delete(cart.external_ram)

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
    is_ram, phys_addr := ctx.mapper.map_addr(&ctx.mapper, addr)

    if addr >= 0xA000 && addr <= 0xBFFF {
        if ctx.mapper.state.rtc_selected do return Read_MBC3_RTC(&ctx.mapper)
        if !is_ram || phys_addr >= u32(len(ctx.external_ram)) do return 0xFF
        value := ctx.external_ram[phys_addr]
        if ctx.mapper.ram_nibble do return value | 0xF0
        return value
    }
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
    // Mapper does not define a write handler, so writes are disabled by default
    if ctx.mapper.write == nil do return

    // Check if we should actually write
    if !ctx.mapper.write(&ctx.mapper, addr, val) do return

    is_ram, phys_addr := ctx.mapper.map_addr(&ctx.mapper, addr)
    if is_ram {
        if phys_addr >= u32(len(ctx.external_ram)) do return
        write_value := val
        if ctx.mapper.ram_nibble do write_value &= 0x0F
        ctx.external_ram[phys_addr] = write_value
        return
    }
}
