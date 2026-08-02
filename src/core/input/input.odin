package input

import c "../common"

Dpad_Input :: enum {
    RIGHT = 1 << 0,
    LEFT = 1 << 1,
    UP = 1 << 2,
    DOWN = 1 << 3,
}

Button_Input :: enum {
    A = 1 << 0,
    B = 1 << 1,
    SELECT = 1 << 2,
    START = 1 << 3
}

button_pressed :: proc(
    button: Button_Input,
    state: ^c.Input_State,
    bus: ^c.Bus_Access
) { 
    was_released := state.buttons & u8(button) != 0
    state.buttons &= ~(u8(button))
    enabled := bus.read(bus, 0xFF00, true) & 0x20 == 0

    if enabled && was_released do c.set_interrupt(bus, .Joypad)
}

button_released :: proc(
    button: Button_Input,
    state: ^c.Input_State,
) { state.buttons |= u8(button) }

dpad_pressed :: proc(
    button: Dpad_Input,
    state: ^c.Input_State,
    bus: ^c.Bus_Access
) {
    was_released := state.dpad & u8(button) != 0
    state.dpad &= ~(u8(button))
    enabled := bus.read(bus, 0xFF00, true) & 0x10 == 0

    if enabled && was_released do c.set_interrupt(bus, .Joypad)
}

dpad_released :: proc(
    button: Dpad_Input,
    state: ^c.Input_State
) { state.dpad |= u8(button)}