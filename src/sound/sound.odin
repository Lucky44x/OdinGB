package sound

import "../mmu"

APU :: struct {
    bus: ^mmu.MMU
}

make_apu :: proc(
    self: ^APU,
    bus: ^mmu.MMU
) {
    self.bus = bus
}