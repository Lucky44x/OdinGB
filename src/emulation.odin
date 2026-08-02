package main

import "core:path/filepath"
import "core:fmt"
import "core"
import "core:os"
import "core:log"

import rl "vendor:raylib"

GB_M_CYCLES_PER_SECOND :: 1048576

emulation_cycle_accumulator: f64
emulation_clock_initialized: bool

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
    emulation_init_renderer(&DMG_PALETTE, 7)
    emulation_init_audio()

    if bios != nil do load_bios(&boot_rom, bios)
    if rom != nil do load_rom(&boot_rom, rom)
}

emulation_teardown :: proc(bios: ^os.File) {
    unload_bios(&boot_rom, bios)
}

emulation_step :: proc() {
    if !emulator_core.is_loaded || DEBUG_STEPPING_ENABLED do return

    // GetFrameTime may include setup work performed before the first frame.
    // Discard that stale interval so the boot ROM starts after rendering is
    // initialized and receives normal-sized time slices.
    if !emulation_clock_initialized {
        emulation_clock_initialized = true
        emulation_audio_render()
        return
    }

    // Pace the emulated hardware from elapsed real time instead of assuming
    // that the host renders exactly one Game Boy frame per display frame.
    emulation_cycle_accumulator += f64(rl.GetFrameTime()) * f64(GB_M_CYCLES_PER_SECOND)
    cycles := int(emulation_cycle_accumulator)
    emulation_cycle_accumulator -= f64(cycles)
    for cycles > 0 {
        emulation_check_input()

        steps := int(core.step_emulation(&emulator_core))
        if steps <= 0 do log.info("Invalid return value")
        cycles -= steps
    }

    emulation_audio_render()
}

//TODO: Parse cartridge CGB capability and select a DMG/CGB renderer and boot
//TODO: ROM before constructing the core.

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
        render_scanline_adapter,
        audio_sample_rate = SAMPLE_RATE
    )
    emulation_audio_reset()
    emulation_cycle_accumulator = 0
    emulation_clock_initialized = false

    UI_SHOW_MENU_BAR = false
}

unload_rom :: proc() {
    if !emulator_core.is_loaded do return

    core.cartridge_unload(&cart_rom)
    core.teardown_GB_Core(&emulator_core)
}

reset_rom :: proc() {
    if !emulator_core.is_loaded do return
    emulation_cycle_accumulator = 0
    emulation_clock_initialized = false
    emulation_audio_reset()
    core.reload_GB_Core(&emulator_core)
}
