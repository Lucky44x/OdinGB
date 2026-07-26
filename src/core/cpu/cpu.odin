package cpu

import "core:log"

CPU_RunState :: enum(u8) {
    Running,
    Halted,
    Stopped
}

CPU :: struct {
    regs: Registers,
    bus: ^Bus_Access,

    // Interrupt
    ime: bool,
    ime_enable_pending: u8,

    state: CPU_RunState
}

step :: proc(
    cpu: ^CPU,
    bus: ^Bus_Access,
) {
    cpu.bus = bus

    // TODO: Wake on specific interrupt etc...
    if cpu.state == .Stopped do return

    //TODO: Fetch interrupts
    pending_interrupt := false

    if cpu.state == .Halted {
        if !pending_interrupt do return
        // Any Interrupt will break halt
        cpu.state = .Running
        // Autoamtically falls through to the interrupt dispatcher
    }

    if pending_interrupt && cpu.ime {
        //TODO: Dispatch interrupt
    }

    opcode: u8 = fetch_next_u8(cpu)
    if handle_instruction(cpu, opcode) == 0 do log.warnf("Opcode: %02x returned a cycle time of 0", opcode)

    if cpu.ime_enable_pending == 1 {
        cpu.ime = true
        cpu.ime_enable_pending = 0
    } else if cpu.ime_enable_pending > 1 do cpu.ime_enable_pending -= 1
}

@(private)
fetch_next_u8 :: proc(cpu: ^CPU) -> u8 {
    pc := read_r16(cpu, .PC)
    val := cpu.bus.read(cpu.bus.ctx, pc)
    inc_r16(cpu, .PC)
    return val
}

@(private)
fetch_next_u16 :: proc(cpu: ^CPU) -> u16 {
    pc := read_r16(cpu, .PC)
    val := cpu.bus.read(cpu.bus.ctx, pc)
    inc_r16(cpu, .PC)
    val2 := cpu.bus.read(cpu.bus.ctx, read_r16(cpu, .PC))
    inc_r16(cpu, .PC)

    return u16(val) | (u16(val2) << 8)
}