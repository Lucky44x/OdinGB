#+private
package sound

import "../mmu"

mixer_step :: proc(
    self: ^APU
) -> f32 {
    if mmu.get(self.bus, u8, u16(mmu.IO_REGS.NR52), true) & 0x80 == 0 do return 0.0

    c1 := channel_get(self, 1)
    c2 := channel_get(self, 2)
    c3 := channel_get(self, 3)
    c4 := channel_get(self, 4)

    sum := c1 + c2 + c3 + c4
    num_used := 0

    if c1 != 0.0 do num_used += 1
    if c2 != 0.0 do num_used += 1
    if c3 != 0.0 do num_used += 1
    if c4 != 0.0 do num_used += 1

    if num_used == 0.0 do return 0.0
    sample := sum / f32(num_used)
    sample *= 0.8   //Global gain
    return sample
}