package cpu

import "core:log"

CPU :: struct {
    regs: Registers,
    bus: ^Bus_Access
}

step :: proc(
    cpu: ^CPU,
    bus: ^Bus_Access,
) {
    cpu.bus = bus
    opcode: u8 = fetch_next_u8(cpu)
    if handle_instruction(cpu, opcode) == 0 {
        log.errorf("Could not find instruction handler matching %02X in table...", opcode)
    }
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