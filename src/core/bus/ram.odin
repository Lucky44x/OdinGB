#+private
package bus

Bus_RAM :: struct {
    wram: [8][0x1000]u8,    // 8 Banks of 4096 bytes of WRAM
    hram: [127]u8,          // 127 bytes of HRAM
    wram_bank: u8,          // Selected WRAM Bank
}