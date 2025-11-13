package mmu

import "core:fmt"
import "core:os"
import "core:mem"

import "../cartridge"
import "../rend"

@(private="file")
WRAM_PAGE_SIZE :: 4096

/*
    Describes the BUS of the GB, and in my Implementation additionally contains all Memory that is not situated in the Cart

    In this case, keeping subsections of memory apart, instead of flattening all memory above WRAM into one big buffer,
    imporoves clarity of commands and allwos for better debugging of behaviour
*/
MMU :: struct {
    cart: ^cartridge.Cartridge,
    ppu: ^rend.PPU,
    banked: bool,
    boot_rom: [^]u8,
    wram: [^]u8,
    io_registers: [^]u8,
    hram: [^]u8
}

init :: proc(
    ctx: ^MMU,
    bios: os.Handle,
    cart: ^cartridge.Cartridge,
    ppu: ^rend.PPU
) -> bool {
    /*
        Make Boot-Rom Size, and load into memory
        -> DMG - Boot = 256 B / CGB = 256 + 1792
    */
    boot_size, boot_err := os.file_size(bios)
    if boot_err != nil {
        when ODIN_DEBUG do fmt.eprintfln("[MMU-INIT] Could not load Boot-Rom: %e", boot_err)
        return false
    }
    if boot_size != 256 && boot_size != 2048 {
        when ODIN_DEBUG do fmt.eprintfln("[MMU-INIT] Boot-Rom can be neither DMG, nor CGB... 256 (DMG) != %i != 2048 (CGB)", boot_size)
        return false
    }
    ctx.boot_rom = make([^]u8, boot_size)

    romData, boot_err1 := os.read_entire_file(bios)
    defer delete(romData)
    if !boot_err1 {
        when ODIN_DEBUG do fmt.eprintfln("[MMU-INIT] Could not load Boot-ROM")
        return false
    }

    mem.copy(ctx.boot_rom, raw_data(romData), cast(int)boot_size)

    /*
        Set a reference to the loaded CART
    */
    ctx.cart = cart
    ctx.ppu = ppu
    /*
        Base-Pages are 2 in the GB DMG and 8 in the GBC
        WRAM_PAGE_SIZE * (BASE_PAGES + BANK_NUM) + 512
    */
    ctx.wram = make([^]u8, WRAM_PAGE_SIZE * 2)
    /*
        128 bytes for I/O Registers FF00 -  FF7F + 1 byte for IE
    */
    ctx.io_registers = make([^]u8, 129)
    /*
        127 bytes for H-RAM FF80 -  FFFE
    */
    ctx.hram = make([^]u8, 128)

    return true
}

deinit :: proc(
    ctx: ^MMU
) {
    free(ctx.wram)
    free(ctx.io_registers)
    free(ctx.hram)
    free(ctx.boot_rom)
}

boot_rom_get :: proc(
    ctx: ^MMU,
    $T: typeid,
    offset: u16 = 0
) -> T {
    if offset > 0xFF do return 0x00
    p := mem.ptr_offset(ctx.boot_rom, offset)
    return mem.reinterpret_copy(T, p)
}

get :: proc(
    ctx: ^MMU,
    $T: typeid,
    address: u16
) -> T {
    //Redirect call to section
    if address < 0x4000 {
        // 0x0000 - 0x3FFF
        // ROM-Bank 00, unless boot flag not set, then boot-rom
        if ctx.banked do return cartridge.get_rom(ctx.cart, T, address)
        if address > 0x0100 do return cartridge.get_rom(ctx.cart, T, address)

        return boot_rom_get(ctx, T, address)
    }
    else if address < 0x8000 {
        // 0x4000 - 0x7FFF
        // TODO BANK
        return cartridge.get_rom(ctx.cart, T, address)
    }
    else if address < 0xA000 {
        // 0x8000 x 0x9FFF
        // V-Ram
        return rend.vram_get(ctx.ppu, T, address-0x8000)
    }
    else if address <  0xC000 {
        // 0xA000 - 0xBFFF
        // TODO: BANK
        return cartridge.get_exram(ctx.cart, T, address)
    }
    else if address < 0xE000 {
        // 0xC000 - 0xDFFF -> 2 Wram sections
        // WRAM - Bank 0 + (1 | in GBC mode further banks defined)
        return wram_get(ctx, T, address - 0xC000)
    }
    else if address < 0xFE00 {              // 0xE000 - 0xFDFF - Echo RAM -> Redirect to work-ram
        return get(ctx, T, address - 0x2000)
    } else if address < 0xFEA0 {
        // 0xFE00 - 0xFE9F
        return rend.oam_get(ctx.ppu, T, address-0xFE00)
    } else if address < 0xFF00 {
        //NOOP - Not usable
        // see https://gbdev.io/pandocs/Memory_Map.html#fea0feff-range for more details
    } else if address < 0xFF80 {
        // 0xFF00 - 0xFF7F
        // I/O - Registers
        return io_get(ctx, T, address - 0xFF00)
    } else if address < 0xFFFF {
        // 0xFF80 - 0xFFFE
        // High-RAM (HRAM)
        return hram_get(ctx, T, address - 0xFF80)
    } else {
        return io_get(ctx, T, 0xFFFF)   // 0xFFFF gets converted internaly, to 0xFF80 to map to the last byte of the virtual registry
    }
    return cast(T)0
}

put :: proc(
    ctx: ^MMU,
    val: $T,
    address: u16
) {
    //Redirect call to section
    if address < 0x4000 { /*ROM BANK 00 / BOOT_ROM if flag not set --==--> NOOP*/ }
    else if address < 0x8000 { /*ROM BANK 01 - NN --==--> NOOP*/ }
    else if address < 0xA000 {
        // 0x8000 x 0x9FFF
        // V-Ram
        rend.vram_put(ctx.ppu, val, address - 0x8000)
    }
    else if address <  0xC000 {
        // 0xA000 - 0xBFFF
        // TODO Banks
        cartridge.put_exram(ctx.cart, val, address - 0xA000)
    }
    else if address < 0xE000 {
        // 0xC000 - 0xDFFF -> 2 Wram sections
        // WRAM - Bank 0 + (1 | in GBC mode further banks defined)
        wram_put(ctx, val, address - 0xC000)
    }
    else if address < 0xFE00 {              // 0xE000 - 0xFDFF - Echo RAM -> Redirect to work-ram
        put(ctx, val, address - 0x2000)     // IDK if echo page is read-only but whatever
    } else if address < 0xFEA0 {
        // 0xFE00 - 0xFE9F
        rend.vram_put(ctx.ppu, val, address - 0xFE00)
    } else if address < 0xFF00 {
        //NOOP - Not usable
        // see https://gbdev.io/pandocs/Memory_Map.html#fea0feff-range for more details
    } else if address < 0xFF80 {
        // 0xFF00 - 0xFF7F
        // I/O - Registers
        io_put(ctx, val, address - 0xFF00)
    } else if address < 0xFFFF {
        // 0xFF80 - 0xFFFE
        // High-RAM (HRAM)
        hram_put(ctx, val, address - 0xFF80)
    } else {
        io_put(ctx, val, 0xFFFF)        // 0xFFFF gets converted internaly, to 0xFF80 to map to the last byte of the virtual registry
    }
}