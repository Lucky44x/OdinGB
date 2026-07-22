package tests

import "../cpu"

SM83_RAM_Entry :: [2]u16

SM83_State :: struct {
    pc, sp: u16,

    a, b, c, d, e, f, h, l: u8,
    ime, ie: u8,

    ram: []SM83_RAM_Entry
}

SM83_Test_Case :: struct {
    name: string,
    initial: SM83_State,
    final: SM83_State
}

Test_Bus :: struct {
    memory: [65536]u8
}

test_read_adapter :: proc(bus: rawptr, address: u16) -> u8 { return test_bus_read(cast(^Test_Bus)bus, address) }
test_bus_read :: proc(
    bus: ^Test_Bus,
    address: u16
) -> u8 {
    return bus.memory[address]
}

test_write_adapter :: proc(bus: rawptr, address: u16, val: u8) { test_bus_write(cast(^Test_Bus)bus, address, val) }
test_bus_write :: proc(
    bus: ^Test_Bus,
    address: u16,
    value: u8
) {
    bus.memory[address] = value
}

make_test_bus_access :: proc(
    bus: ^Test_Bus    
) -> cpu.Bus_Access {
    return {
        ctx = bus,
        read = test_read_adapter,
        write = test_write_adapter
    }
}