package sound

import "core:strconv/decimal"
import "core:mem"
import rl "vendor:raylib"
import "../mmu"

@(private = "file")
CYCLES_PER_FRAME : u32 : 4194304 / 512
@(private = "file")
CYCLES_PER_SAMPLE : f32 : 4194304.0 / 44100.0

APU :: struct {
    bus: ^mmu.MMU,
    cycles_since_frame: u32,
    cycles_since_sample: f32,

    frame_step: u8,

    stream: rl.AudioStream,
    buffer: RingBuffer(f32, 16384),

    ch: Channels
}

make_apu :: proc(
    self: ^APU,
    bus: ^mmu.MMU
) {
    self.bus = bus

    self.frame_step = 0
    self.cycles_since_frame = 0
    self.cycles_since_sample = 0

    rl.InitAudioDevice()
    self.stream = rl.LoadAudioStream(44100, 32, 1)
    rl.PlayAudioStream(self.stream)
}

step :: proc(
    self: ^APU
) {
    self.cycles_since_frame += 1
    self.cycles_since_sample += 1

    for self.cycles_since_frame >= CYCLES_PER_FRAME {
        self.cycles_since_frame -= CYCLES_PER_FRAME
        sequencer_step(self)
    }

    channels_step(self)

    for self.cycles_since_sample >= CYCLES_PER_SAMPLE {
        self.cycles_since_sample -= CYCLES_PER_SAMPLE
        samp := mixer_step(self)
        _ = ring_push(&self.buffer, samp) 
    }
}

flush_to_audio_device :: proc(
    self: ^APU
) {
    /*
    if !rl.IsAudioStreamProcessed(self.stream) do return

    temp_buf: []f32 = make([]f32, 512)
    mem.set(&temp_buf, 0, size_of(temp_buf))
    _ = ring_pop_len(&self.buffer, temp_buf)

    rl.UpdateAudioStream(self.stream, &temp_buf, i32(len(temp_buf)))
    delete(temp_buf)
    */
}