#+private
package apu

import c "../common"

Noise_Channel :: struct {
    enabled: bool,
    timer: int,
    lfsr: u16,
    length_counter: u8,
    length_enabled: bool,
    current_volume: u8,
    envelope_timer: u8,
    envelope_period: u8,
    envelope_increase: bool,
}

noise_step :: proc(apu: ^APU, channel: ^Noise_Channel, elapsed_m: int) {
    if !channel.enabled do return

    nr43 := apu.bus.read(apu.bus, u16(c.IO_Regs.NR43), true)
    divisor: int = 8
    switch nr43 & 0x07 {
        case 0: divisor = 8
        case 1: divisor = 16
        case 2: divisor = 32
        case 3: divisor = 48
        case 4: divisor = 64
        case 5: divisor = 80
        case 6: divisor = 96
        case 7: divisor = 112
    }
    period := (divisor << u32((nr43 >> 4) & 0x0F)) / 4
    if channel.timer <= 0 do channel.timer = period

    remaining := elapsed_m
    for remaining > 0 {
        if channel.timer > remaining {
            channel.timer -= remaining
            break
        }
        remaining -= channel.timer
        channel.timer = period

        feedback: u16 = (channel.lfsr & 1) == ((channel.lfsr >> 1) & 1) ? 1 : 0
        channel.lfsr = (channel.lfsr >> 1) | (feedback << 14)
        if nr43 & 0x08 != 0 do channel.lfsr = (channel.lfsr &~ u16(1 << 6)) | (feedback << 6)
    }
}

noise_clock_length :: proc(channel: ^Noise_Channel) {
    if !channel.length_enabled || channel.length_counter == 0 do return
    channel.length_counter -= 1
    if channel.length_counter == 0 do channel.enabled = false
}

noise_clock_envelope :: proc(channel: ^Noise_Channel) {
    if !channel.enabled || channel.envelope_period == 0 do return
    if channel.envelope_timer > 0 do channel.envelope_timer -= 1
    if channel.envelope_timer != 0 do return

    channel.envelope_timer = channel.envelope_period
    if channel.envelope_increase {
        if channel.current_volume < 15 do channel.current_volume += 1
    } else {
        if channel.current_volume > 0 do channel.current_volume -= 1
    }
}

noise_output :: proc(channel: ^Noise_Channel) -> i16 {
    if !channel.enabled || channel.current_volume == 0 do return 0
    volume := i16(channel.current_volume)
    if channel.lfsr & 1 == 0 do return volume
    return -volume
}

noise_trigger :: proc(apu: ^APU, channel: ^Noise_Channel) {
    nr42 := apu.bus.read(apu.bus, u16(c.IO_Regs.NR42), true)
    nr44 := apu.bus.read(apu.bus, u16(c.IO_Regs.NR44), true)
    length := apu.bus.read(apu.bus, u16(c.IO_Regs.NR41), true)

    channel.enabled = nr42 & 0xF8 != 0
    channel.timer = 0
    channel.lfsr = 0
    channel.length_counter = 64 - (length & 0x3F)
    if channel.length_counter == 0 do channel.length_counter = 64
    channel.length_enabled = nr44 & 0x40 != 0
    channel.current_volume = nr42 >> 4
    channel.envelope_period = nr42 & 0x07
    channel.envelope_timer = channel.envelope_period
    channel.envelope_increase = nr42 & 0x08 != 0
}
