#+private
package cart

import "core:strings"
import "core:log"

read_cart_header :: proc(
    header_data: []u8
) {
    if len(header_data) != 79 do log.warnf("Loaded header region ws %d bytes large, not 79")

    rom_name, err := strings.clone_from_bytes(header_data[0x34:0x43])
    defer delete(rom_name)    
    log.infof("game-name: %s", rom_name)

    cart_type := cast(MapperType)header_data[0x47]
    log.infof("Rom type: %02x - %e", cart_type, cart_type)

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
    log.infof("ROM has %d bytes of external RAM", ram_size)
}