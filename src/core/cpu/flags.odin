#+private
package cpu

CPU_FLAGS :: enum(u8) {
    Z = 7, // Zero flag
    N = 6, // Subtract flag
    H = 5, // Half carry flag
    C = 4  // Carry flag
}

carry_per_bit_internal :: proc(
    left: u32,
    right: u32,
    bit: int,
    bit_width: int,
    carry: u32 = 0,
) -> bool {
    if bit < 0 || bit >= bit_width {
        return false
    }

    shift_amount := u8(bit + 1)
    carry_mask := u32((u32(1) << shift_amount) - 1)
    return (left & carry_mask) + (right & carry_mask) + carry > carry_mask
}

borrow_from_bit_internal :: proc(
    left: u32,
    right: u32,
    bit: int,
    bit_width: int,
    carry: u32 = 0,
) -> bool {
    if bit < 0 || bit >= bit_width {
        return false
    }

    shift_amount := u8(bit + 1)
    borrow_mask := u32((u32(1) << shift_amount) - 1)
    return (left & borrow_mask) < (right & borrow_mask) + carry
}

carry_per_bit :: proc(
    left: u8,
    right: u8,
    bit: int,
    carry: u8 = 0,
) -> bool {
    return carry_per_bit_internal(u32(left), u32(right), bit, 8, u32(carry))
}

borrow_from_bit :: proc(
    left: u8,
    right: u8,
    bit: int,
    carry: u8 = 0,
) -> bool {
    return borrow_from_bit_internal(u32(left), u32(right), bit, 8, u32(carry))
}

carry_per_bit_16 :: proc(
    left: u16,
    right: u16,
    bit: int,
    carry: u16 = 0,
) -> bool {
    return carry_per_bit_internal(u32(left), u32(right), bit, 16, u32(carry))
}

borrow_from_bit_16 :: proc(
    left: u16,
    right: u16,
    bit: int,
    carry: u16 = 0,
) -> bool {
    return borrow_from_bit_internal(u32(left), u32(right), bit, 16, u32(carry))
}

set_flag :: proc(
    c: ^CPU,
    flag: CPU_FLAGS,
    value: bool,
) {
    mask := u8(1) << u8(flag)
    f := c.regs.bytes[REG_8.F]

    if value {
        f |= mask
    } else {
        f &= ~mask
    }

    // The lower nibble of F is always zero.
    c.regs.bytes[REG_8.F] = f & 0xF0
}

get_flag :: proc(
    c: ^CPU,
    flag: CPU_FLAGS,
) -> bool {
    return (c.regs.bytes[REG_8.F] & u8(1 << flag)) != 0
}
