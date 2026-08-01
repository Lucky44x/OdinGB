#+private
package apu

import c "../common"

Wave_Channel :: struct {
    enabled: bool,
    position: u8,
    timer: int,
    length_counter: u16,
    length_enabled: bool,
}

wave_frequency :: proc(bus: ^c.Bus_Access) -> int {
    low := bus.read(bus, u16(c.IO_Regs.NR33), true)
    high := bus.read(bus, u16(c.IO_Regs.NR34), true)
    return int(u16(low) | (u16(high & 0x07) << 8))
}

wave_step :: proc(apu: ^APU, channel: ^Wave_Channel, elapsed_m: int) {
    if !channel.enabled do return

    period := (2048 - wave_frequency(apu.bus)) / 2
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
        channel.position = (channel.position + 1) & 31
    }
}

wave_clock_length :: proc(channel: ^Wave_Channel) {
    if !channel.length_enabled || channel.length_counter == 0 do return
    channel.length_counter -= 1
    if channel.length_counter == 0 do channel.enabled = false
}

wave_output :: proc(apu: ^APU, channel: ^Wave_Channel) -> i16 {
    if !channel.enabled do return 0

    wave_ram := u16(c.IO_Regs.WAVE_RAM_0) + u16(channel.position / 2)
    value := apu.bus.read(apu.bus, wave_ram, true)
    sample := channel.position & 1 == 0 ? value >> 4 : value & 0x0F

    volume_code := (apu.bus.read(apu.bus, u16(c.IO_Regs.NR32), true) >> 5) & 0x03
    if volume_code == 0 do return 0
    if volume_code == 2 do sample >>= 1
    if volume_code == 3 do sample >>= 2
    return i16(sample) - 8
}

wave_trigger :: proc(apu: ^APU, channel: ^Wave_Channel) {
    length := apu.bus.read(apu.bus, u16(c.IO_Regs.NR31), true)
    channel.enabled = apu.bus.read(apu.bus, u16(c.IO_Regs.NR30), true) & 0x80 != 0
    channel.position = 0
    channel.timer = (2048 - wave_frequency(apu.bus)) / 2
    channel.length_counter = 256 - u16(length)
    if channel.length_counter == 0 do channel.length_counter = 256
    channel.length_enabled = apu.bus.read(apu.bus, u16(c.IO_Regs.NR34), true) & 0x40 != 0
    if channel.timer < 1 do channel.timer = 1
}
