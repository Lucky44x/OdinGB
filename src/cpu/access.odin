package cpu

Bus_Access :: struct {
    ctx: rawptr,
    read: proc(rawptr, u16) -> u8,
    write: proc(rawptr, u16, u8)
}