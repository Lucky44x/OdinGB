#+private
package cart

ROM_Bulk :: struct {
    data: ^[]u8
}

init_bulk_rom :: proc(
    data: ^[]u8
) -> ROM_Bulk {
    return ROM_Bulk {
        data = data
    }
}

read_rom_bulk :: proc(
    ctx: ^ROM_Bulk,
    offset: u32
) -> u8 {
    if offset >= u32(len(ctx.data)) do return 0xFF
    return ctx.data[offset]
}