#+private
package apu

import c "../common"

SQUARE_DUTY_TABLE: [4][8]u8 = {
    { 0, 0, 0, 0, 0, 0, 0, 1 },
    { 1, 0, 0, 0, 0, 0, 0, 1 },
    { 1, 0, 0, 0, 0, 1, 1, 1 },
    { 0, 1, 1, 1, 1, 1, 1, 0 },
}

Square_Channel :: struct {
    enabled: bool,
    duty_position: u8,
    timer: int,

    length_counter: u8,
    length_enabled: bool,

    current_volume: u8,
    envelope_timer: u8,
    envelope_period: u8,
    envelope_increase: bool,

    sweep_timer: u8,
    sweep_period: u8,
    sweep_shift: u8,
    sweep_increase: bool,
    sweep_shadow_frequency: int,
    sweep_enabled: bool,
}

square_frequency :: proc(
    bus: ^c.Bus_Access,
    low_reg: c.IO_Regs,
    high_reg: c.IO_Regs,
) -> int {
    low := bus.read(bus, u16(low_reg), true)
    high := bus.read(bus, u16(high_reg), true)
    return int(u16(low) | (u16(high & 0x07) << 8))
}

square_step :: proc(
    apu: ^APU,
    channel: ^Square_Channel,
    len_reg: c.IO_Regs,
    frequency_low_reg: c.IO_Regs,
    frequency_high_reg: c.IO_Regs,
    elapsed_m: int,
) {
    if !channel.enabled do return

    freq := square_frequency(apu.bus, frequency_low_reg, frequency_high_reg)
    period := 2048 - freq
    if period < 1 do period = 1
    if channel.timer <= 0 do channel.timer = period

    remaining := elapsed_m
    for remaining > 0 {
        if channel.timer > remaining {
            channel.timer -= remaining
            break
        }

        remaining -= channel.timer
        channel.timer = period
        channel.duty_position = (channel.duty_position + 1) & 7
    }
    _ = len_reg
}

square_clock_length :: proc(channel: ^Square_Channel) {
    if !channel.length_enabled || channel.length_counter == 0 do return
    channel.length_counter -= 1
    if channel.length_counter == 0 do channel.enabled = false
}

square_clock_envelope :: proc(channel: ^Square_Channel) {
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

square_clock_sweep :: proc(
    apu: ^APU,
    channel: ^Square_Channel,
    is_channel_1: bool,
) {
    if !is_channel_1 || !channel.sweep_enabled do return

    if channel.sweep_timer > 0 do channel.sweep_timer -= 1
    if channel.sweep_timer != 0 do return

    channel.sweep_timer = channel.sweep_period
    if channel.sweep_timer == 0 do channel.sweep_timer = 8

    change := channel.sweep_shadow_frequency >> channel.sweep_shift
    next_frequency := channel.sweep_increase ? channel.sweep_shadow_frequency + change : channel.sweep_shadow_frequency - change
    if next_frequency > 2047 {
        channel.enabled = false
        return
    }

    if channel.sweep_shift != 0 {
        channel.sweep_shadow_frequency = next_frequency
        apu.bus.write(apu.bus, u16(c.IO_Regs.NR13), u8(next_frequency & 0xFF), true)
        high := apu.bus.read(apu.bus, u16(c.IO_Regs.NR14), true)
        apu.bus.write(apu.bus, u16(c.IO_Regs.NR14), (high & 0xF8) | u8((next_frequency >> 8) & 0x07), true)

        second_change := next_frequency >> channel.sweep_shift
        second_frequency := channel.sweep_increase ? next_frequency + second_change : next_frequency - second_change
        if second_frequency > 2047 do channel.enabled = false
    }
}

square_output :: proc(
    channel: ^Square_Channel,
    bus: ^c.Bus_Access,
    len_reg: c.IO_Regs,
    envelope_reg: c.IO_Regs,
) -> i16 {
    if !channel.enabled || channel.current_volume == 0 do return 0

    _ = envelope_reg
    duty_value := bus.read(bus, u16(len_reg), true) >> 6
    high := SQUARE_DUTY_TABLE[int(duty_value)][int(channel.duty_position)]
    volume := i16(channel.current_volume)
    if high == 0 do return -volume
    return volume
}

square_trigger :: proc(
    apu: ^APU,
    channel: ^Square_Channel,
    len_reg: c.IO_Regs,
    envelope_reg: c.IO_Regs,
    freq_low_reg: c.IO_Regs,
    freq_high_reg: c.IO_Regs,
) {
    envelope := apu.bus.read(apu.bus, u16(envelope_reg), true)
    freq := square_frequency(apu.bus, freq_low_reg, freq_high_reg)
    length := apu.bus.read(apu.bus, u16(len_reg), true)

    channel.enabled = envelope & 0xF8 != 0
    channel.duty_position = 0
    channel.current_volume = envelope >> 4
    channel.timer = 2048 - freq
    channel.length_counter = 64 - (length & 0x3F)
    if channel.length_counter == 0 do channel.length_counter = 64
    channel.length_enabled = apu.bus.read(apu.bus, u16(freq_high_reg), true) & 0x40 != 0
    channel.envelope_period = envelope & 0x07
    channel.envelope_timer = channel.envelope_period
    channel.envelope_increase = envelope & 0x08 != 0

    if freq_high_reg == .NR14 {
        sweep := apu.bus.read(apu.bus, u16(c.IO_Regs.NR10), true)
        channel.sweep_period = (sweep >> 4) & 0x07
        channel.sweep_increase = sweep & 0x08 == 0
        channel.sweep_shift = sweep & 0x07
        channel.sweep_shadow_frequency = freq
        channel.sweep_timer = channel.sweep_period
        if channel.sweep_timer == 0 do channel.sweep_timer = 8
        channel.sweep_enabled = channel.sweep_period != 0 || channel.sweep_shift != 0
    } else {
        channel.sweep_enabled = false
    }

    if channel.timer < 1 do channel.timer = 1
}
