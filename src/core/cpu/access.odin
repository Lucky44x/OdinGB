package cpu

Bus_Access :: struct {
    ctx: rawptr,
    // Reads from the specified context, at the specified address
    read: proc(rawptr, u16) -> u8,
    // Writes to the specified context, at the specified address the given byte
    write: proc(rawptr, u16, u8)
}

@(private)
bus_read_u16 :: proc(bus: ^Bus_Access, address: u16) -> u16 {
    lo := bus.read(bus.ctx, address)
    hi := bus.read(bus.ctx, address + 1)
    return (u16(hi) << 8) | u16(lo)
}

@(private)
bus_write_u16 :: proc(bus: ^Bus_Access, address: u16, value: u16) {
    bus.write(bus.ctx, address, u8(value & 0xFF))
    bus.write(bus.ctx, address + 1, u8(value >> 8))
}