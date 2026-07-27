package core

import c "common"

import "cpu"
import "bus"
import cart "cartridge"

GB_Core :: struct {
    is_loaded: bool,

    bios: ^GB_Bios,

    cpu_state: cpu.CPU,
    bus_state: bus.Bus, bus: c.Bus_Access,
    cart_state: ^cart.Cartridge, cartridge: c.CART_Access
}

GB_Bios :: bus.Boot_Rom
GB_Cartridge :: cart.Cartridge

make_GB_Core :: proc(
    core: ^GB_Core,
    cartridge: ^GB_Cartridge,
    bios: ^GB_Bios
) {
    core.bios = bios

    core.cart_state = cartridge
    core.cartridge = cart.get_cart_accessor(cartridge) 

    bus.init(&core.bus_state, core.bios, &core.cartridge)
    core.bus = bus.get_access(&core.bus_state)

    cpu.init(&core.cpu_state, &core.bus)

    core.is_loaded = true
}

cartridge_load :: proc {
    cart.cartridge_load_direct,
    cart.cartridge_load_buffered
}

step_emulation :: proc(
    core: ^GB_Core
) -> u8 {
    cpu.step(&core.cpu_state, &core.bus)
    return core.cpu_state.last_instruction
}