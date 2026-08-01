#+private
package apu

AUDIO_BUFFER_CAPACITY :: 4096

Audio_Buffer :: struct {
    samples: [AUDIO_BUFFER_CAPACITY]i16,

    read_idx: int,
    write_idx: int,
    count: int
}

buffer_push :: proc(
    buf: ^Audio_Buffer,
    sample: i16
) -> (ok: bool) {
    if buf.count >= len(buf.samples) do return false

    buf.samples[buf.write_idx] = sample
    buf.write_idx = (buf.write_idx + 1) % len(buf.samples)
    buf.count += 1

    return true
}

buffer_pop :: proc(
    buf: ^Audio_Buffer
) -> (sample: i16, ok: bool) {
    if buf.count == 0 do return 0, false

    sample = buf.samples[buf.read_idx]
    buf.read_idx = (buf.read_idx + 1) % len(buf.samples)
    buf.count -= 1
    return sample, true
}

buffer_available :: proc(buf: ^Audio_Buffer) -> int {
    return buf.count
}
