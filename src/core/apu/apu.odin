package apu

import c "../common"

SAMPLE_RATE :: 48000
FRAME_SEQUENCER_PERIOD :: 2048
MIX_GAIN :: 64

APU :: struct {
    bus: ^c.Bus_Access,

    sample_rate: u32,
    sample_accumulator: u64,
    frame_seq_counter: u32,
    frame_seq_step: u8,
    dropped_samples: u64,

    channel_1: Square_Channel,
    channel_2: Square_Channel,
    channel_3: Wave_Channel,
    channel_4: Noise_Channel,

    audioBuffer: Audio_Buffer
}

init :: proc(apu: ^APU, bus: ^c.Bus_Access, sample_rate: u32) {
    apu.bus = bus
    apu.sample_rate = sample_rate

    apu.channel_4.lfsr = 0x7FFF
}

reset :: proc(apu: ^APU) {
    sample_rate := apu.sample_rate
    bus := apu.bus
    apu^ = {}
    apu.sample_rate = sample_rate
    apu.bus = bus
    apu.channel_4.lfsr = 0x7FFF
}

step :: proc(apu: ^APU, elapsed_m: u16) {
    if apu.sample_rate == 0 do return

    nr52 := apu.bus.read(apu.bus, u16(c.IO_Regs.NR52), true)
    if nr52 & 0x80 == 0 do return

    // Advance the APU at the sample clock boundary instead of advancing all
    // oscillators first and rendering the whole instruction from one state.
    for _ in 0..<int(elapsed_m) {
        square_step(apu, &apu.channel_1, .NR11, .NR13, .NR14, 1)
        square_step(apu, &apu.channel_2, .NR21, .NR23, .NR24, 1)
        wave_step(apu, &apu.channel_3, 1)
        noise_step(apu, &apu.channel_4, 1)

        apu.frame_seq_counter += 1
        if apu.frame_seq_counter >= FRAME_SEQUENCER_PERIOD {
            apu.frame_seq_counter -= FRAME_SEQUENCER_PERIOD
            apu.frame_seq_step = (apu.frame_seq_step + 1) & 7

            if apu.frame_seq_step & 1 == 0 {
                square_clock_length(&apu.channel_1)
                square_clock_length(&apu.channel_2)
                wave_clock_length(&apu.channel_3)
                noise_clock_length(&apu.channel_4)
            }
            if apu.frame_seq_step == 2 || apu.frame_seq_step == 6 {
                square_clock_sweep(apu, &apu.channel_1, true)
            }
            if apu.frame_seq_step == 7 {
                square_clock_envelope(&apu.channel_1)
                square_clock_envelope(&apu.channel_2)
                noise_clock_envelope(&apu.channel_4)
            }
            update_channel_status(apu)
        }

        apu.sample_accumulator += u64(apu.sample_rate)
        if apu.sample_accumulator < u64(c.GB_M_CYCLES_PER_SECOND) do continue
        apu.sample_accumulator -= u64(c.GB_M_CYCLES_PER_SECOND)
        if !buffer_push(&apu.audioBuffer, mix_sample(apu)) do apu.dropped_samples += 1
    }
}

mix_sample :: proc(apu: ^APU) -> i16 {
    nr50 := apu.bus.read(apu.bus, u16(c.IO_Regs.NR50), true)
    nr51 := apu.bus.read(apu.bus, u16(c.IO_Regs.NR51), true)
    outputs := [4]i16{
        square_output(&apu.channel_1, apu.bus, .NR11, .NR12),
        square_output(&apu.channel_2, apu.bus, .NR21, .NR22),
        wave_output(apu, &apu.channel_3),
        noise_output(&apu.channel_4),
    }

    left: int
    right: int
    for index in 0..<4 {
        if nr51 & u8(1 << u32(index + 4)) != 0 do left += int(outputs[index])
        if nr51 & u8(1 << u32(index)) != 0 do right += int(outputs[index])
    }

    left *= int((nr50 >> 4) & 0x07)
    right *= int(nr50 & 0x07)
    result := ((left + right) / 2) * MIX_GAIN
    if result > 32767 do result = 32767
    if result < -32768 do result = -32768
    return i16(result)
}

update_channel_status :: proc(apu: ^APU) {
    nr52 := apu.bus.read(apu.bus, u16(c.IO_Regs.NR52), true) & 0x80
    if apu.channel_1.enabled do nr52 |= 0x01
    if apu.channel_2.enabled do nr52 |= 0x02
    if apu.channel_3.enabled do nr52 |= 0x04
    if apu.channel_4.enabled do nr52 |= 0x08
    apu.bus.write(apu.bus, u16(c.IO_Regs.NR52), nr52, true)
}

pop_frame :: proc(apu: ^APU) -> (sample: i16, ok: bool) {
    return buffer_pop(&apu.audioBuffer)
}

available_frames :: proc(apu: ^APU) -> int {
    return buffer_available(&apu.audioBuffer)
}

trigger_channel_1 :: proc(apu: ^APU) {
    if apu.bus.read(apu.bus, u16(c.IO_Regs.NR52), true) & 0x80 == 0 do return
    square_trigger(apu, &apu.channel_1, .NR11, .NR12, .NR13, .NR14)
    update_channel_status(apu)
}

trigger_channel_2 :: proc(apu: ^APU) {
    if apu.bus.read(apu.bus, u16(c.IO_Regs.NR52), true) & 0x80 == 0 do return
    square_trigger(apu, &apu.channel_2, .NR21, .NR22, .NR23, .NR24)
    update_channel_status(apu)
}

trigger_channel_3 :: proc(apu: ^APU) {
    if apu.bus.read(apu.bus, u16(c.IO_Regs.NR52), true) & 0x80 == 0 do return
    wave_trigger(apu, &apu.channel_3)
    update_channel_status(apu)
}

trigger_channel_4 :: proc(apu: ^APU) {
    if apu.bus.read(apu.bus, u16(c.IO_Regs.NR52), true) & 0x80 == 0 do return
    noise_trigger(apu, &apu.channel_4)
    update_channel_status(apu)
}
