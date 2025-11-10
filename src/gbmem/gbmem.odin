package gbmem

import "core:os"
import "core:mem"
import "core:fmt"

/*
Memory Map:
0000 - 3FFF - 16 KiB Rom Bank 00    -> Fixed
4000 - 7FFF - 16 KiB Rom Bank 01-NN -> Bank switch enabled
8000 - 9FFF - 8 KiB Video Ram
    - Video Ram stores Tile-Defs
        - 8000 - 87FF -> Block0
        - 8800 - 8FFF -> Block1
        - 9000 - 97FF -> Block2
    - And TileMap-Data
        - 9800 - 9BFF -> 32x32 TileMap 1
        - 9C00 - 9FFF -> 32x32 TileMap 2

        Adressing may differ depending on state of  LCDC.4 = 1 -> 0-127 Block 1 / 128-255 -> Block 2
                                                    LCDC.4 = 0 -> 0-127 Block 2 / 238-255 -> Block 3

A000 - BFFF - 8 KiB External        -> Bank switch enabled
C000 - CFFF - Work Ram
D000 - DFFF - Work Ram
E000 - FDFF - Echo - Ram [mirrors C000 - DDFF]
FE00 - FE9F - OAM (Object attribute memory)
FEA0 - FEFF - Not Usable
FF00 - FF7F - I/O Registers
FF80 - FF7F - High Ram
FFFF - FFFF - Interrupt enable register


Memory :: struct {
    ram: [^]u8,
    rom: [^]u8,
}

mem_init :: proc(
    ctx: ^Memory,
    bios: os.Handle,
    rom: os.Handle,
) {
    ctx.ram = make([^]u8, 0x10000) //Over-allocate for good measure
    rom_size, _ := os.file_size(rom)
    ctx.rom = make([^]u8, rom_size)
    
    romData, err := os.read_entire_file(rom)
    if !err { panic("Could not read rom file") }
    mem.copy(ctx.rom, raw_data(romData), cast(int)rom_size)
}

mem_deinit :: proc(
    ctx: Memory
) {
    mem.free(ctx.ram)
    mem.free(ctx.rom)
}

get :: proc(
    ctx: Memory,
    $T: typeid,
    offset: int = 0
) -> T {
    p := mem.ptr_offset(ctx.ram, offset)
    return mem.reinterpret_copy(T, p)
}

put :: proc(
    ctx: Memory,
    val: $T,
    offset: int = 0
) {
    dst := mem.ptr_offset(ctx.ram, offset)
    value: T = val
    _ = mem.copy(dst, &value, size_of(T))
}

write_work_ram :: proc(
    ctx: Memory,
    val: $T,
    offset: int = 0
) {
    put(val, offset, 0xC000)
}
*/