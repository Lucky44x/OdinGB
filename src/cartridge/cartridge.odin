package cartridge

import "core:fmt"
import "core:os"
import "core:mem"

Cartridge :: struct {
    external_ram: [^]u8,
    rom_data: [^]u8,
}

init :: proc(
    ctx: ^Cartridge,
    rom: os.Handle
) -> bool {
    romSize, err := os.file_size(rom)
    if err != nil {
        when ODIN_DEBUG do fmt.eprintfln("Could not load ROM: %e", err)
        return false
    }

    ctx.rom_data = make([^]u8, romSize)
    romData, err1 := os.read_entire_file(rom)
    if !err1 {
        when ODIN_DEBUG do fmt.eprintfln("Could not load ROM")
        return false
    }

    mem.copy(ctx.rom_data, raw_data(romData), cast(int)romSize)

    //TODO: Initialize External RAM with cartridge-header FLAGS

    return true
}

deinit :: proc(
    ctx: ^Cartridge
) {
    free(ctx.external_ram)
    free(ctx.rom_data)
}

put_exram :: proc(
    ctx: ^Cartridge,
    val: $T,
    addr: u16 = 0
) {
    dst := mem.ptr_offset(ctx.external_ram, addr)
    value: T = val
    _ = mem.copy(dst, &value, size_of(T))
}

get_exram :: proc(
    ctx: ^Cartridge,
    $T: typeid,
    addr: u16 = 0
) -> T {
    p := mem.ptr_offset(ctx.external_ram, addr)
    return mem.reinterpret_copy(T, p)
}

get_rom :: proc(
    ctx: ^Cartridge,
    $T: typeid,
    addr: u16 = 0
) -> T {
    p := mem.ptr_offset(ctx.rom_data, addr)
    val := mem.reinterpret_copy(T, p)
    return val
}