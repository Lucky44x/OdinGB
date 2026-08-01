package core

import c "common"

import "cpu"
import "bus"
import "ppu"
import cart "cartridge"
import "input"

GB_Core :: struct {
    is_loaded: bool,

    bios: ^GB_Bios,

    cpu_state: cpu.CPU,
    bus_state: bus.Bus, bus: c.Bus_Access,
    ppu_state: ppu.PPU, ppu: c.PPU_Access,

    cart_state: ^cart.Cartridge, cartridge: c.CART_Access,

    input_state: c.Input_State
}

GB_PPU_Callback :: c.PPU_ScanlineCallback
GB_Bios :: bus.Boot_Rom
GB_Cartridge :: cart.Cartridge
GB_DPAD_Button :: input.Dpad_Input
GB_Button :: input.Button_Input

make_GB_Core :: proc(
    core: ^GB_Core,
    cartridge: ^GB_Cartridge,
    bios: ^GB_Bios,

    render_callback: GB_PPU_Callback,
    render_callback_ctx: rawptr = nil
) {
    core.bios = bios

    core.cart_state = cartridge
    core.cartridge = cart.get_cart_accessor(cartridge) 

    core.ppu = ppu.get_access(&core.ppu_state)

    bus.init(&core.bus_state, core.bios, &core.cartridge, &core.ppu, &core.input_state)
    core.bus = bus.get_access(&core.bus_state)

    ppu.init(&core.ppu_state, &core.bus, render_callback, render_callback_ctx)
    cpu.init(&core.cpu_state, &core.bus)

    core.is_loaded = true
}

reload_GB_Core :: proc(
    core: ^GB_Core
) {
    ppu.reset(&core.ppu_state)
    cpu.reset(&core.cpu_state)
    bus.reset(&core.bus_state)
}

teardown_GB_Core :: proc(
    core: ^GB_Core
) {
    core.is_loaded = false
    core.cart_state = nil

    ppu.reset(&core.ppu_state)
    cpu.reset(&core.cpu_state)
    bus.reset(&core.bus_state)
}

cartridge_load :: proc {
    cart.cartridge_load_direct,
    cart.cartridge_load_buffered
}

cartridge_unload :: proc { 
    cart.cartridge_unload 
}

step_emulation :: proc(
    core: ^GB_Core
) -> u16 {
    if !core.is_loaded do return 0

    elapsed_m := cpu.step(&core.cpu_state, &core.bus)
    elapsed_m += bus.consume_system_delay(&core.bus_state)

    ppu.step(&core.ppu_state, u16(elapsed_m))
    
    return elapsed_m
}

set_button :: proc(
    core: ^GB_Core,
    button: GB_Button,
    is_pressed: bool
) {
    if is_pressed do input.button_pressed(button, &core.input_state, &core.bus) 
    else do input.button_released(button, &core.input_state)
}

set_dpad :: proc(
    core: ^GB_Core,
    dpad: GB_DPAD_Button,
    is_pressed: bool
) {
    if is_pressed do input.dpad_pressed(dpad, &core.input_state, &core.bus)
    else do input.dpad_released(dpad, &core.input_state)
}