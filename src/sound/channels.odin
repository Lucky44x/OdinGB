#+private
package sound

import "../mmu"

Channels :: struct {
    ch1: Channel1,
    ch2: Channel2,
    ch3: Channel3,
    ch4: Channel4
}

Channel :: struct {
    // Out should stay between [-1,1] and 0.0 if off
    out: f32
}

@(private="file")
Channel1 :: struct {
    using Channel
}

@(private="file")
Channel2 :: struct {
    using Channel
}

@(private="file")
Channel3 :: struct {
    using Channel
}

@(private="file")
Channel4 :: struct {
    using Channel
}

@(private)
channels_step :: proc(
    self: ^APU
) {

}

@(private)
channels_length_step :: proc(
    self: ^APU
) {
    
}

@(private)
channels_envelope_step :: proc(
    self: ^APU
) {

}

@(private)
channel_get :: proc(
    self: ^APU,
    idx: int
) -> f32 {
    if idx == 1 do return mmu.get(self.bus, u8, u16(mmu.IO_REGS.NR12)) == 0 ? 0 : self.ch.ch1.out
    else if idx == 2 do return mmu.get(self.bus, u8, u16(mmu.IO_REGS.NR22)) == 0 ? 0 : self.ch.ch2.out
    else if idx == 3 do return mmu.get(self.bus, u8, u16(mmu.IO_REGS.NR30)) == 0 ? 0 : self.ch.ch3.out
    else if idx == 4 do return mmu.get(self.bus, u8, u16(mmu.IO_REGS.NR42)) == 0 ? 0 : self.ch.ch4.out
    return 0.0
}

@(private)
channels_sweep :: proc(
    self: ^APU
) {

}