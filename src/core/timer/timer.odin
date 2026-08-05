package timer

import c "../common"

Timer :: struct {
    bus: ^c.Bus_Access,

    // The divider is a 16-bit counter clocked at the 4.194304 MHz T-cycle
    // rate. DIV exposes its upper eight bits.
    internal_div: u16,

    // TIMA reload is delayed by one M-cycle after an overflow on DMG hardware.
    reload_pending: bool,
}

step_timer :: proc(
    ctx: ^Timer,
    bus: ^c.Bus_Access,
    elapsed_m: u16,
) {
    ctx.bus = bus

    // A CPU write to DIV is visible here before the timer advances. Keep the
    // internal counter aligned with the visible register when possible.
    visible_div := bus.read(bus, u16(c.IO_Regs.DIV), true)
    if visible_div != u8(ctx.internal_div >> 8) {
        ctx.internal_div = u16(visible_div) << 8
    }

    tac := bus.read(bus, u16(c.IO_Regs.TAC), true)
    timer_enabled := tac & 0x04 != 0
    timer_bit := timer_divider_bit(tac & 0x03)

    for _ in 0..<int(elapsed_m) {
        // Complete a previous overflow before processing the next M-cycle.
        if ctx.reload_pending {
            tma := bus.read(bus, u16(c.IO_Regs.TMA), true)
            bus.write(bus, u16(c.IO_Regs.TIMA), tma, true)
            c.set_interrupt(bus, .Timer)
            ctx.reload_pending = false
        }

        previous_div := ctx.internal_div
        ctx.internal_div += 4

        // TIMA is clocked by falling edges of the selected divider bit, not
        // by an independent period accumulator.
        if timer_enabled {
            previous_bit := previous_div & (u16(1) << u32(timer_bit)) != 0
            current_bit := ctx.internal_div & (u16(1) << u32(timer_bit)) != 0
            if previous_bit && !current_bit do clock_tima(ctx, bus)
        }
    }

    bus.write(bus, u16(c.IO_Regs.DIV), u8(ctx.internal_div >> 8), true)
}

timer_divider_bit :: proc(mode: u8) -> u8 {
    switch mode {
        case 0: return 9  // 4096 Hz
        case 1: return 3  // 262144 Hz
        case 2: return 5  // 65536 Hz
        case 3: return 7  // 16384 Hz
    }
    return 9
}

clock_tima :: proc(ctx: ^Timer, bus: ^c.Bus_Access) {
    tima := bus.read(bus, u16(c.IO_Regs.TIMA), true)
    if tima == 0xFF {
        // Keep TIMA at FF until the delayed reload. This also leaves a
        // one-M-cycle window for hardware-accurate overflow behavior.
        ctx.reload_pending = true
        return
    }

    bus.write(bus, u16(c.IO_Regs.TIMA), tima + 1, true)
}
