#+private
package cart

import "core:log"
import c "../common"

ROM_BANK_SIZE :: 0x4000

ROM_Buffered :: struct {
    backend: ^ROM_Access,

    banks: [][ROM_BANK_SIZE]u8,
    bank_indecies: []int,
    ages: []u64,
    access_counter: u64,

    rom_size: u32
}

init_buffered_rom :: proc(
    max_banks: int,

    backend: ^ROM_Access,
    rom_size: u32
) -> ROM_Buffered {
    return ROM_Buffered {
        banks = make([][ROM_BANK_SIZE]u8, max_banks),
        bank_indecies = make([]int, max_banks),
        ages = make([]u64, max_banks),
        backend = backend,
        rom_size = rom_size
    }
}

read_rom_buffered :: proc(
    ctx: ^ROM_Buffered,
    offset: u32
) -> u8 {
    if offset >= ctx.rom_size do return 0xFF

    bank := int(offset / ROM_BANK_SIZE)
    bank_offset := int(offset % ROM_BANK_SIZE)

    slot := buffered_find_bank_slot(ctx, bank)

    if slot < 0 {
        slot = buffered_load_bank(ctx, bank)
        if slot < -1 do return 0xFF
    }

    ctx.access_counter += 1
    ctx.ages[slot] = ctx.access_counter

    return ctx.banks[slot][bank_offset]
}

/*
    Finds the bank with the given idx inside the Buffered ROM.
    If the bank is not present inside the ROM data, returns a -1
*/
buffered_find_bank_slot :: proc(
    ctx: ^ROM_Buffered,
    idx: int
) -> int {
    for i := 0; i < len(ctx.banks); i += 1 {
        if ctx.bank_indecies[i] == idx do return i
    }

    return -1
}

/*
    Finds a free slot in the buffer, or the bank that has been
    inactive the longest
*/
buffered_choose_slot :: proc(
    ctx: ^ROM_Buffered
) -> int {
    max_timeout : u64 = 0
    max_timeout_ind : int = -1

    for i := 0; i < len(ctx.banks); i += 1 {
        if ctx.bank_indecies[i] == -1 do return i

        timediff := ctx.access_counter - ctx.ages[i]
        if timediff >= max_timeout {
            max_timeout = timediff
            max_timeout_ind = i
        }
    }

    return max_timeout_ind
}

/*
    Loads the given bank (idx) into the Buffered ROM, And sets the metadata accordingly
*/
buffered_load_bank :: proc(
    ctx: ^ROM_Buffered,
    bank: int
) -> int {
    slot := buffered_choose_slot(ctx)
    if slot == -1 {
        log.errorf("Could not find the next slot for bank %d in the buffered ROM...", bank)
        return -1
    }

    phys_offset := u32(bank) * ROM_BANK_SIZE
    bytes_remaining := ctx.rom_size - phys_offset
    read_size := min(int(bytes_remaining), ROM_BANK_SIZE)

    slice := ctx.banks[slot][:]
    ok := ctx.backend.read(ctx.backend.ctx, &slice, phys_offset, read_size)
    if !ok do return -1

    if read_size < ROM_BANK_SIZE do for i in read_size..<ROM_BANK_SIZE do slice[i] = 0xFF

    ctx.bank_indecies[slot] = bank
    ctx.access_counter += 1
    ctx.ages[slot] = ctx.access_counter
    return slot
}