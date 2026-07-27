package cpu

import "core:log"
import c "../common"

CPU_RunState :: enum(u8) {
    Running,
    Halted,
    Stopped
}

CPU :: struct {
    regs: Registers,
    bus: ^c.Bus_Access,

    // Interrupt
    ime: bool,
    ime_enable_pending: u8,

    state: CPU_RunState,

    last_instruction: u8,
}

init :: proc(
    cpu: ^CPU,
    bus: ^c.Bus_Access
) {
    cpu.bus = bus
}

step :: proc(
    cpu: ^CPU,
    bus: ^c.Bus_Access,
) -> (m_cycles: u8) {
    if cpu.bus == nil do cpu.bus = bus

    // TODO: Wake on specific interrupt etc...
    if cpu.state == .Stopped do return 0 // Do not advance hardware state during STOP 

    // Check if interrupt is pending
    pending_interrupt := is_interrupt_pending(cpu)

    if cpu.state == .Halted {
        if !pending_interrupt do return 1 // NOOP
        // Any Interrupt will break halt
        cpu.state = .Running
        // Automatically falls through to the interrupt dispatcher
    }

    if pending_interrupt && cpu.ime {
        // log.info("Scanning for interrupts")
        found, interrupt := fetch_interrupt(cpu)
        if found do m_cycles += dispatch_interrupt(cpu, interrupt)
        return // Let instruction execute at next CPU step
    }

    opcode: u8 = fetch_next_u8(cpu)
    cpu.last_instruction = opcode
    instruction_cycles := handle_instruction(cpu, opcode)
    if instruction_cycles <= 0 do log.warnf("Opcode: %02x returned a cycle time of 0", opcode)

    m_cycles += instruction_cycles

    if cpu.ime_enable_pending == 1 {
        cpu.ime = true
        cpu.ime_enable_pending = 0
    } else if cpu.ime_enable_pending > 1 do cpu.ime_enable_pending -= 1

    return
}

@(private)
fetch_next_u8 :: proc(cpu: ^CPU) -> u8 {
    pc := read_r16(cpu, .PC)
    val := cpu.bus.read(cpu.bus, pc)
    inc_r16(cpu, .PC)
    return val
}

@(private)
fetch_next_u16 :: proc(cpu: ^CPU) -> u16 {
    pc := read_r16(cpu, .PC)
    val := cpu.bus.read(cpu.bus, pc)
    inc_r16(cpu, .PC)
    val2 := cpu.bus.read(cpu.bus, read_r16(cpu, .PC))
    inc_r16(cpu, .PC)

    return u16(val) | (u16(val2) << 8)
}

@(private)
bus_read_u16 :: proc(bus: ^c.Bus_Access, address: u16) -> u16 {
    lo := bus.read(bus, address)
    hi := bus.read(bus, address + 1)
    return (u16(hi) << 8) | u16(lo)
}

@(private)
bus_write_u16 :: proc(bus: ^c.Bus_Access, address: u16, value: u16) {
    bus.write(bus, address, u8(value & 0xFF))
    bus.write(bus, address + 1, u8(value >> 8))
}