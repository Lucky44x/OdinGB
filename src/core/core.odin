package core

import c "common"

import "cpu"
import "bus"
import cart "cartdrige"

GB_Core :: struct {
    cpu: cpu.CPU,
    bus_state: bus.Bus, bus: c.Bus_Access,

    cartridge: cart.Cartridge
}

GB_Bios :: bus.Boot_Rom
GB_Cartridge :: cart.Cartridge

make_GB_Core :: proc(
    core: ^GB_Core
) {
    core.bus = bus.get_access(&core.bus_state)
    cpu.init(&core.cpu, &core.bus)
}

cartridge_load :: proc {
    cart.cartridge_load_direct,
    cart.cartridge_load_buffered
}