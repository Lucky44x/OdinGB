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
    
    opcode: u8 = bus.read(bus, read_r16(cpu, .PC))
    if handle_instruction(cpu, opcode) == 0 {
        log.errorf("Could not find instruction handler matching %02X in table...", opcode)
    }
}