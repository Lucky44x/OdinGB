#+private
package bus

IO_Registers :: struct {
    data: [128]u8
}

read_IO_Registers :: proc(
    ctx: ^IO_Registers,
    addr: u16
) -> u8 {
    return ctx.data[addr - 0xFF00]
}

write_IO_Registers :: proc(
    ctx: ^IO_Registers,
    addr: u16,
    val: u8
) {
    ctx.data[addr - 0xFF00] = val
}