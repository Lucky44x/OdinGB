#+private
package sound

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

channels_step :: proc(
    self: ^APU
) {

}

channel_get :: proc(
    self: Channels,
    idx: int
) -> f32 {
    if idx == 1 do return self.ch1.out
    else if idx == 2 do return self.ch2.out
    else if idx == 3 do return self.ch3.out
    else if idx == 4 do return self.ch4.out
    return 0.0
}