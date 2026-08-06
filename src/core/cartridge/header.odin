#+private
package cart

import "core:strings"
import "core:log"

read_cart_header :: proc(
    cart: ^Cartridge,
    header_data: []u8,
) {
    //TODO: Persist the CGB flag at $0143, mapper type, ROM size, RAM size,
    //TODO: and other header metadata for mode selection and mapper setup.
    if len(header_data) != 79 do log.warnf("Loaded header region ws %d bytes large, not 79")

    rom_name, err := strings.clone_from_bytes(header_data[0x34:0x43])
    defer delete(rom_name)    
    log.infof("game-name: %s", rom_name)

    cart_type := cast(MapperType)header_data[0x47]
    log.infof("Rom type: %02x - %e", cart_type, cart_type)

    #partial switch cart_type {
        case .ROM_ONLY:
            cart.mapper = MAPPER_Basic
            break
        
        case .MBC1: fallthrough
        case .MBC1_RAM: fallthrough
        case .MBC1_RAM_BAT:
            cart.mapper = MAPPER_MBC1
            break
        
        case:
            log.infof("No registered Mapper-Implementation for %e", cart.mapper)
            cart.mapper = MAPPER_Basic
            break
    }

    cart_size : u32 = (32 * (1 << u32(header_data[0x48]))) * 1024
    log.infof("Rom size: %d", cart_size)

    ram_size: u32
    ram_size_flag := header_data[0x49]
    switch ram_size_flag {
        case 0x01: fallthrough
        case 0x00: // No external RAM
            ram_size = 0
            break
        case 0x02: // One bank of 8 KiB
            ram_size = 8192
            break
        case 0x03: // 4 Banks of 8 KiB each -> 32 KiB
            ram_size = 32768
            break
        case 0x04: // 16 banks of 8 KiB each -> 128 KiB
            ram_size = 131072
            break
        case 0x05: // 8 banks of 8 KiB each -> 64 KiB
            ram_size = 65536
            break
    }

    cart.external_ram = make([]u8, ram_size)
    cart.mapper.ram_size = ram_size;

    log.infof("ROM has %d bytes of external RAM", ram_size)

    rom_banks, rom_size: u32
    rom_size_flag := header_data[0x48]
    switch rom_size_flag {
        case 0x00:
            rom_size = 32768
            rom_banks = 0
            break
        case 0x01:
            rom_size = 65536
            rom_banks = 4
            break
        case 0x02:
            rom_size = 131072
            rom_banks = 8
            break
        case 0x03:
            rom_size = 262144
            rom_banks = 16
            break
        case 0x04:
            rom_size = 524288
            rom_banks = 32
            break
        case 0x05:
            rom_size = 1048576
            rom_banks = 64
            break
        case 0x06:
            rom_size = 2097152
            rom_banks = 128
            break
        case 0x07:
            rom_size = 4194304
            rom_banks = 256
            break
        case 0x08:
            rom_size = 8388608
            rom_banks = 512
            break
        case 0x52:
            rom_size = 1126400
            rom_banks = 72
            break
        case 0x53:
            rom_size = 1228800
            rom_banks = 80
            break
        case 0x54:
            rom_size = 1536000
            rom_banks = 96
            break
    }

    if rom_size != cart_size do log.warnf("Size Mismatch: Cart reports %02X bytes but Rom-Banks says %02X", cart_size, rom_size)

    cart.mapper.rom_size = rom_size
    cart.mapper.banks = rom_banks
}
