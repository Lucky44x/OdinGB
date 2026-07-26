package common

Write_Proc :: proc(ctx: rawptr, address: u16, value: u8)
Read_Proc :: proc(ctx: rawptr, address: u16) -> u8

Bus_Access :: struct {
    ctx: rawptr,
    // Reads from the specified context, at the specified address
    read: Read_Proc,
    // Writes to the specified context, at the specified address the given byte
    write: Write_Proc
}