package core

import c "common"

import "cpu"
import "bus"

GB_Core :: struct {
    cpu: cpu.CPU,
    bus_state: bus.Bus, bus: c.Bus_Access
}

make_GB_Core :: proc(
    core: ^GB_Core
) {
    core.bus = bus.get_access(&core.bus_state)
    cpu.init(&core.cpu, &core.bus)
}