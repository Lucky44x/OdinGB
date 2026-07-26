package common

InterruptSource :: enum(u8) {
    VBlank = 0,
    LCD = 1,
    Timer = 2,
    Serial = 3,
    Joypad = 4
}

enable_interrupt_source :: proc(
    access: ^Bus_Access,
    src: InterruptSource
) {
    state := access.read(access.ctx, 0xFFFF)
    state |= (1 << src)
    access.write(access.ctx, 0xFFFF, state)
}

disable_interrupt_source :: proc(
    access: ^Bus_Access,
    src: InterruptSource
) {
    state := access.read(access.ctx, 0xFFFF)
    state &= ~(1 << src)
    access.write(access.ctx, 0xFFFF, state)
}