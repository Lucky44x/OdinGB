#+private
package sound

RingBuffer :: struct(
    $T: typeid,
    $MAX_CAP: int
) {
    data: [MAX_CAP]T,
    read_idx, write_idx: int,
    count: int
}

ring_count :: proc(
    ring: ^RingBuffer
) -> int {
    return ring.count
}

ring_free :: proc(
    ring: ^RingBuffer
) -> int {
    return len(ring.data) - ring.count
}

ring_push :: proc(
    ring: ^RingBuffer($T, $MAX_CAP),
    dat: T
) -> bool {
    if ring.count >= len(ring.data) do return false
    ring.data[ring.write_idx] = dat
    ring.write_idx = (ring.write_idx + 1) % len(ring.data)
    ring.count += 1
    return true
}

ring_pop :: proc(
    ring: ^RingBuffer($T, $MAX_CAP)
) -> T {
    val := ring.data[ring.read_idx]
    ring.read_idx = (ring.read_idx + 1) % MAX_CAP
    ring.count -= 1
    return val
}

ring_pop_len :: proc(
    ring: ^RingBuffer($T, $MAX_CAP),
    dst: []T
) -> int {
    available := ring.count
    if available == 0 {
        return 0
    }

    to_read := available
    if to_read > len(dst) {
        to_read = len(dst)
    }

    // Because of wrapping, we might need two copies
    first_chunk := to_read
    space_till_end := len(ring.data) - ring.read_idx
    if first_chunk > space_till_end {
        first_chunk = space_till_end
    }

    // First contiguous block
    for i in 0 ..< first_chunk {
        dst[i] = ring.data[ring.read_idx + i]
    }

    // Second block if wrapped
    remaining := to_read - first_chunk
    if remaining > 0 {
        for i in 0 ..< remaining {
            dst[first_chunk + i] = ring.data[i]
        }
    }

    ring.read_idx = (ring.read_idx + to_read) % len(ring.data)
    ring.count -= to_read

    return to_read
}

ring_clear :: proc(
    ring: ^RingBuffer
) {
    ring.read_idx = 0
    ring.write_idx = 0
    ring.count = 0
}