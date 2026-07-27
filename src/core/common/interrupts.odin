package common

import "core:log"
InterruptSource :: enum(u8) {
    VBlank = 0,
    Stat = 1,
    Timer = 2,
    Serial = 3,
    Joypad = 4
}

enable_interrupt_source :: proc(
    access: ^Bus_Access,
    src: InterruptSource
) {
    state := access.read(access, 0xFFFF)
    state |= (1 << src)
    access.write(access, 0xFFFF, state)

    // log.infof("Enabled interrupt %e -> %02X", src, access.read(access, 0xFFFF))
}

disable_interrupt_source :: proc(
    access: ^Bus_Access,
    src: InterruptSource
) {
    state := access.read(access, 0xFFFF)
    state &= ~(1 << src)
    access.write(access, 0xFFFF, state)

    // log.infof("Disabled interrupt %e -> %02X", src, access.read(access, 0xFFFF))
}

set_interrupt :: proc(
    access: ^Bus_Access,
    src: InterruptSource
) {
    state := access.read(access, 0xFF0F)
    state |= (1 << src)
    access.write(access, 0xFF0F, state)
    //log.infof("Set interrupt %e -> %02X", src, access.read(access, 0xFF0F))
}

clear_interrupt :: proc(
    access: ^Bus_Access,
    src: InterruptSource
) {
    state := access.read(access, 0xFF0F)
    state &= ~(1 << src)
    access.write(access, 0xFF0F, state)

    //log.infof("Reset interrupt %e -> %02X", src, access.read(access, 0xFF0F))
}