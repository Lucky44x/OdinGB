#+feature dynamic-literals
package sm83

import "../mmu"

@(private = "file")
InterruptAddr : [Interrupts]u16 = {
    .VBlank = 0x0040,
    .STAT = 0x0048,
    .Timer = 0x0050,
    .Serial = 0x0058,
    .Joypad = 0x0060
}

step_interrupts :: proc(
    cpu: ^CPU,
    bus: ^mmu.MMU
) -> (
    serviced: bool = false,
    cycles: u32 = 0,
) {
    if !cpu.registers.IME do return                         // Interrupt master enable is off -- ignore
    if mmu.get(bus, u8, 0xFF0F, true) == 0x00 do return     // No Interrupts requested... ignore

    for i in u8(0)..<len(InterruptAddr) {
        interrupt_requested := mmu.get_bit_flag(bus, 0xFF0F, i)     // Get request flag for this interrupt
        if ! interrupt_requested do continue
        if ! send_interrupt(cpu, bus, Interrupts(i)) do continue
        mmu.set_bit_flag(bus, 0xFF0F, i, false)                     // Reset request-flag for this interrupt
        return true, 5
    }

    return
}

request_interrupt :: proc(
    bus: ^mmu.MMU,
    interrupt: Interrupts
) {
    if ! mmu.get_bit_flag(bus, 0xFFFF, u8(interrupt)) do return     // Interrupt is disabled
    mmu.set_bit_flag(bus, 0xFF0F, u8(interrupt), true)              // Set interrupt request bit
}

send_interrupt :: proc(
    cpu: ^CPU,
    bus: ^mmu.MMU,
    interrupt: Interrupts
) -> (
    serviced: bool = false
) {
    if ! cpu.registers.IME do return                                // Interrupt master enable is off -- ignore
    if ! mmu.get_bit_flag(bus, 0xFFFF, u8(interrupt)) do return     // Interrupt is disabled
    interrupt_addr := InterruptAddr[interrupt]
    call_routine(cpu, bus, interrupt_addr)                          // Call / Jump to interrupt handler
    return true                                                     // Confirm Interrupt called
}