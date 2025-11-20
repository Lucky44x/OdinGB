package timer

import "../mmu"
import "../sm83"

Timer :: struct {
    div_counter, time_counter: u32,
}

div_step :: proc(
    ctx: ^Timer,
    bus: ^mmu.MMU
) {
    if ctx.div_counter == 256 {
        ctx.div_counter = 0
        prev_val := mmu.get(bus, u8, 0xFF04, true)
        prev_val += 1
        mmu.put(bus, prev_val, 0xFF04, true)
        return
    }
    ctx.div_counter += 1
}

@(private = "file")
CLOCK_FREQUENCIES := [4]u32 {
    1024,   // 256  M-Cycle     * 4 = 1024  T-Cycle
    16,     // 4    M-Cyucle    * 4 = 16    T-Cycle
    64,     // 16   M-Cycle     * 4 = 64    T-Cycle
    256,    // 64   M-Cycle     * 4 = 256   T-Cycle
}

timer_step :: proc(
    ctx: ^Timer,
    bus: ^mmu.MMU,
    cpu: ^sm83.CPU
) {
    if !mmu.get_bit_flag(bus, 0xFF07, 2) do return  // Timer not enabled
    tac_val := mmu.get(bus, u8, 0xFF07)
    clk_sel := (tac_val & 0x02)                     // Bit 0 and 1 = 2 bit clock-select value
    if (ctx.time_counter % CLOCK_FREQUENCIES[clk_sel]) == 0 {
        // Increment TIMA register
        ctx.time_counter = 0
        prev_val := mmu.get(bus, u8, 0xFF05, true)
        if prev_val == 255 {    // TIMA register will fall back to 0 after this add operation
            // INTERRUPT
            sm83.request_interrupt(bus, sm83.Interrupts.Timer)
            tma_val := mmu.get(bus, u8, 0xFF06, true)
            prev_val = tma_val - 1              // Set to TMA - 1 (-1 for letting this run through, and increment back up to TMA)
        }
        prev_val += 1
        mmu.put(bus, prev_val, 0xFF05, true)    // Increment register
        return
    }
    ctx.time_counter += 1
}