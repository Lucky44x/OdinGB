package cpu

import "core:log"
import c "../common"

CPU_RunState :: enum(u8) {
    Running,
    Halted,
    Stopped,
}

CPU :: struct {
    regs: Registers,
    bus: ^c.Bus_Access,

    // Interrupt
    ime: bool,
    ime_enable_pending: u8,
    halt_bug: bool,

    state: CPU_RunState,

    last_instruction: ^Instruction,
    last_instruction_bytes: [16]u8,
    last_instruction_length: u8,
    paused: bool
}

init :: proc(
    cpu: ^CPU,
    bus: ^c.Bus_Access
) {
    cpu.bus = bus
}

reset :: proc(
    cpu: ^CPU,
) {
    cpu.ime = false
    cpu.ime_enable_pending = 0
    cpu.halt_bug = false
    cpu.last_instruction = nil
    cpu.last_instruction_length = 0

    cpu.regs.bytes = {}
    cpu.regs.pc = 0
    cpu.regs.sp = 0

    cpu.state = .Running
}

step :: proc(
    cpu: ^CPU,
    bus: ^c.Bus_Access,
) -> (m_cycles: u16) {
    if cpu.bus == nil do cpu.bus = bus
    cpu.last_instruction = nil
    cpu.last_instruction_length = 0

    // TODO: Wake on specific interrupt etc...
    //TODO: Implement CGB KEY1 speed switching through STOP and separate CPU
    //TODO: timing from PPU, timer, DMA, and APU clock domains.
    if cpu.paused do return 1

    pending_interrupt := is_interrupt_pending(cpu)

    if cpu.state == .Stopped {
        // DMG STOP wakes on a joypad request even when that interrupt is not
        // enabled for dispatch. Once awake, normal interrupt rules apply.
        joypad_requested := cpu.bus.read(cpu.bus, u16(c.IO_Regs.IF), true) & u8(1 << u8(c.InterruptSource.Joypad)) != 0
        if !joypad_requested do return 1
        cpu.state = .Running
        pending_interrupt = is_interrupt_pending(cpu)
    }

    // Check if interrupt is pending
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
        return 5 // Let instruction execute at next CPU step
    }

    opcode: u8 = fetch_next_u8(cpu)

    instruction_cycles := handle_instruction(cpu, opcode)
    if instruction_cycles <= 0 do log.warnf("Opcode: %02x returned a cycle time of 0", opcode)

    m_cycles += instruction_cycles

    if cpu.ime_enable_pending == 1 {
        cpu.ime = true
        cpu.ime_enable_pending = 0
    } else if cpu.ime_enable_pending > 1 do cpu.ime_enable_pending -= 1

    return m_cycles
}

@(private)
fetch_next_u8 :: proc(cpu: ^CPU) -> u8 {
    pc := read_r16(cpu, .PC)
    val := cpu.bus.read(cpu.bus, pc)
    if cpu.halt_bug do cpu.halt_bug = false
    else do inc_r16(cpu, .PC)

    cpu.last_instruction_bytes[cpu.last_instruction_length] = val
    cpu.last_instruction_length += 1
    //log.infof("  PC: %04X -> Fetched u8: %02X -> %04X", pc, val, read_r16(cpu, .PC))

    return val
}

@(private)
fetch_next_u16 :: proc(cpu: ^CPU) -> u16 {
    pc := read_r16(cpu, .PC)
    val := cpu.bus.read(cpu.bus, pc)
    cpu.last_instruction_bytes[cpu.last_instruction_length] = val
    cpu.last_instruction_length += 1
    
    inc_r16(cpu, .PC)
    val2 := cpu.bus.read(cpu.bus, read_r16(cpu, .PC))
    cpu.last_instruction_bytes[cpu.last_instruction_length] = val2
    cpu.last_instruction_length += 1
    
    inc_r16(cpu, .PC)

    //log.infof("  PC: %04X -> Fetched u16: %04X -> %04X", pc, u16(val) | (u16(val2) << 8), read_r16(cpu, .PC))

    return u16(val) | (u16(val2) << 8)
}

@(private)
bus_write :: proc(ctx: ^CPU, address: u16, val: u8, force: bool = false) {
    ctx.bus.write(ctx.bus, address, val, force)
}

@(private)
bus_read :: proc(ctx: ^CPU, address: u16, force: bool = false) -> u8 {
    return ctx.bus.read(ctx.bus, address, force)
}

@(private)
bus_read_u16 :: proc(ctx: ^CPU, address: u16) -> u16 {
    lo := bus_read(ctx, address)
    hi := bus_read(ctx, address + 1)
    return (u16(hi) << 8) | u16(lo)
}

@(private)
bus_write_u16 :: proc(ctx: ^CPU, address: u16, value: u16) {
    bus_write(ctx, address, u8(value & 0x00FF))
    bus_write(ctx, address + 1, u8(value >> 8))
}
