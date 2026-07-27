#+private
#+feature dynamic-literals
package cpu

import "core:log"
import c "../common"

INTERRUPT_JMP_ADDR := map[c.InterruptSource]u16{
    .VBlank = 0x40, .Stat = 0x48, .Timer = 0x50, .Serial = 0x58, .Joypad = 0x60
}

is_interrupt_pending :: #force_inline proc(
    cpu: ^CPU
) -> bool {
    IE_value := cpu.bus.read(cpu.bus, 0xFFFF)
    IF_value := cpu.bus.read(cpu.bus, 0xFF0F)

    return (IE_value & IF_value & 0x1F) != 0
}

fetch_interrupt :: proc(
    cpu: ^CPU
) -> (found: bool, interrupt: c.InterruptSource) {
    reg_value := cpu.bus.read(cpu.bus, 0xFF0F)

    for i in 0..<5 {
        if reg_value & (1 << u8(i)) == 0 do continue
        interrupt = cast(c.InterruptSource)i
        found = true
        return
    }

    // log.infof("Found no active interrupt: %02X", reg_value)

    return false, .VBlank
}

dispatch_interrupt :: proc(
    cpu: ^CPU,
    interrupt: c.InterruptSource
) -> u8 {
    // Disable IME
    cpu.ime = false
    addr := INTERRUPT_JMP_ADDR[interrupt]

    // Push current PC onto stack
    stack_push_SP(cpu, read_r16(cpu, .PC))
    // Jump to interrupt handler
    write_r16(cpu, .PC, addr)
    // Clear the interrupt bit
    c.clear_interrupt(cpu.bus, interrupt)

    // log.infof("Dispatched interrupt: %e", interrupt)

    return 5
}