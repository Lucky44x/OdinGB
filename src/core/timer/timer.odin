package timer

import c "../common"

Timer :: struct {
    bus: ^c.Bus_Access,

    internal_div, elapsed_m: u16,
}

step_timer :: proc(
    ctx: ^Timer,
    bus: ^c.Bus_Access,
    elapsed_m: u16
) {
    ctx.internal_div += elapsed_m * 4
    bus.write(bus, u16(c.IO_Regs.DIV), u8(ctx.internal_div >> 8), true) // Write new timer value to DIV

    // Increment TIMA
    TAC := bus.read(bus, u16(c.IO_Regs.TAC), true)
    
    if TAC & 0x4 == 0 do return
    ctx.elapsed_m += elapsed_m

    period_mode := TAC & 0x03

    period: u16
    switch (period_mode) {
        case 0: period = 256
        case 1: period = 4
        case 2: period = 16
        case 3: period = 64
    }

    TIMA := bus.read(bus, u16(c.IO_Regs.TIMA), true)
    TMA := bus.read(bus, u16(c.IO_Regs.TMA), true)

    for ctx.elapsed_m >= period {
        ctx.elapsed_m -= period

        if TIMA == 0xFF {
            TIMA = TMA

            // Set timer-interrupt
            c.set_interrupt(bus, .Timer)
        } else do TIMA += 1
    }

    bus.write(bus, u16(c.IO_Regs.TIMA), TIMA, true)
}