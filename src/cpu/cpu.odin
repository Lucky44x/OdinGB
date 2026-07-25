package cpu

CPU :: struct {
    regs: Registers,
    bus: ^Bus_Access,

    // Interrupt
    ime: bool,
    ime_enable_pending: u8,

    halted: bool,
    stopped: bool
}

step :: proc(
    cpu: ^CPU,
    bus: ^Bus_Access,
) {
    cpu.bus = bus
    opcode: u8 = fetch_next_u8(cpu)
    if handle_instruction(cpu, opcode) == 0 do return

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