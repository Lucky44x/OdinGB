// package tests

// import "core:fmt"
// import "core:testing"

// run_normal_opcode_range :: proc(
//     t: ^testing.T,
//     first, last: u8
// ) {
//     for opcode := int(first); opcode <= int(last); opcode += 1 {
//         opcode_name := fmt.tprintf("%02x", opcode)
//         run_sm83_opcode_file(t, opcode_name)
//     }
// }

// @(test)
// sm83_opcode_00_3f :: proc(t: ^testing.T) {
//     run_normal_opcode_range(t, 0x00, 0x3f)
// }

// @(test)
// sm83_opcode_40_7f :: proc(t: ^testing.T) {
//     run_normal_opcode_range(t, 0x40, 0x7f)
// }

// @(test)
// sm83_opcode_80_bf :: proc(t: ^testing.T) {
//     run_normal_opcode_range(t, 0x80, 0xbf)
// }

// @(test)
// sm83_opcode_c0_ff :: proc(t: ^testing.T) {
//     run_normal_opcode_range(t, 0xc0, 0xff)
// }

// run_cb_opcode_range :: proc(
//     t: ^testing.T,
//     first, last: u8
// ) {
//     for opcode := int(first); opcode <= int(last); opcode += 1 {
//         opcode_name := fmt.tprintf("cb %02x", opcode)
//         run_sm83_opcode_file(t, opcode_name)
//     }
// }

// @(test)
// sm83_opcode_cb_00_7f :: proc(t: ^testing.T) {
//     run_cb_opcode_range(t, 0x00, 0x7f)
// }

// @(test)
// sm83_opcode_cb_80_ff :: proc(t: ^testing.T) {
//     run_cb_opcode_range(t, 0x80, 0xff)
// }