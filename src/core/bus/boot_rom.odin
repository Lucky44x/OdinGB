package bus

Boot_Rom :: struct {
    data: []u8,
    is_loaded: bool,
    fileName: string,
    //TODO: Validate DMG/CGB BIOS type and support the extended CGB boot mapping.
}
