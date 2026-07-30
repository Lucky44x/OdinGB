package main

import "core:path/filepath"
import "core:fmt"
import "core"
import "core:os"
import "core:log"

import rl "vendor:raylib"

M_CYCLES_PER_FRAME :: 17556 // 17556

emulator_core: core.GB_Core 
boot_rom: core.GB_Bios
cart_rom: core.GB_Cartridge

DMG_PALETTE := GB_Palette {
    {224, 248, 208, 255},
    {136, 192, 112, 255},
    {52, 104, 86, 255},
    {8, 24, 32, 255},
}

emulation_setup :: proc(bios: ^os.File, rom: ^os.File) {
    emulation_init_renderer(&DMG_PALETTE, 4)

    if bios != nil do load_bios(&boot_rom, bios)
    if rom != nil do load_rom(&boot_rom, rom)
}

emulation_teardown :: proc(bios: ^os.File) {
    unload_bios(&boot_rom, bios)
}

emulation_step :: proc() {
    if !emulator_core.is_loaded || DEBUG_STEPPING_ENABLED do return

    cycles := M_CYCLES_PER_FRAME
        
    for cycles > 0 {
        steps := int(core.step_emulation(&emulator_core))
        if steps <= 0 do log.info("Invalid return value")
        cycles -= steps
    }
}

load_bios :: proc(bios: ^core.GB_Bios, file: ^os.File) {
    err: os.Error
    bios.is_loaded = true
    bios.fileName = os.name(file)
    bios.data, err = os.read_entire_file_from_file(file, context.allocator)
    if err != nil do log.errorf("Error while loading %s", bios.fileName)
    else do log.infof("Loaded bios: %s = %d bytes", bios.fileName, len(bios.data))
}

unload_bios :: proc(bios: ^core.GB_Bios, file: ^os.File) {
    delete(bios.data)
    os.close(file)
}

load_rom :: proc(bios: ^core.GB_Bios, rom: ^os.File) {
    rom_data, err := os.read_entire_file_from_file(rom, context.allocator)

    if err != nil {
        log.errorf("Could not read rom: %e", err)
        return
    }
    core.cartridge_load(&cart_rom, rom_data)

    // Initialize emulator core
    core.make_GB_Core(
        &emulator_core, 
        &cart_rom, 
        &boot_rom,
        render_scanline_adapter
    )
}

unload_rom :: proc() {
    if !emulator_core.is_loaded do return

    core.cartridge_unload(&cart_rom)
    core.teardown_GB_Core(&emulator_core)
}

reset_rom :: proc() {
    if !emulator_core.is_loaded do return
    core.reload_GB_Core(&emulator_core)
}