package core

import c "common"

import "cpu"
import "bus"
import "ppu"
import cart "cartridge"

GB_Core :: struct {
    is_loaded: bool,

    bios: ^GB_Bios,

    cpu_state: cpu.CPU,
    bus_state: bus.Bus, bus: c.Bus_Access,
    ppu_state: ppu.PPU, ppu: c.PPU_Access,

    cart_state: ^cart.Cartridge, cartridge: c.CART_Access,

    ppu_frameBuffer: GB_FrameBuffer
}

GB_FrameBuffer :: c.PPU_FrameBuffer
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

    core.ppu = ppu.get_access(&core.ppu_state)

    bus.init(&core.bus_state, core.bios, &core.cartridge, &core.ppu)
    core.bus = bus.get_access(&core.bus_state)

    ppu.init(&core.ppu_state, &core.bus, &core.ppu_frameBuffer)
    cpu.init(&core.cpu_state, &core.bus)

    core.is_loaded = true
}

cartridge_load :: proc {
    cart.cartridge_load_direct,
    cart.cartridge_load_buffered
}

cartridge_unload :: proc { cart.cartridge_unload }

step_emulation :: proc(
    core: ^GB_Core
) -> u8 {
    elapsed_m := cpu.step(&core.cpu_state, &core.bus)
    ppu.step(&core.ppu_state, u16(elapsed_m))
    
    return elapsed_m
}