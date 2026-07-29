package main

import "core:path/filepath"
import "core:fmt"
import "core"
import "core:os"
import "core:log"

import rl "vendor:raylib"

M_CYCLES_PER_FRAME :: 17690

emulator_core: core.GB_Core 
boot_rom: core.GB_Bios
cart_rom: core.GB_Cartridge

emulation_setup :: proc(bios: ^os.File) {
    load_bios(&boot_rom, bios)
}

emulation_teardown :: proc(bios: ^os.File) {
    unload_bios(&boot_rom, bios)
}

emulation_step :: proc() {
    if !emulator_core.is_loaded do return

    cycles := M_CYCLES_PER_FRAME
        
    for cycles > 0 {
        //log.info("Next Instruction")
        cycles -= int(core.step_emulation(&emulator_core))
    }
}

load_bios :: proc(bios: ^core.GB_Bios, file: ^os.File) {
    err: os.Error
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
    core.make_GB_Core(&emulator_core, &cart_rom, &boot_rom)
}

unload_rom :: proc() {
    if !emulator_core.is_loaded do return

    core.cartridge_unload(&cart_rom)
    core.teardown_GB_Core(&emulator_core)
}