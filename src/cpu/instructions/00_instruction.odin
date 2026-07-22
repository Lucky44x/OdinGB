package instruction

InstructionHandler :: proc()

Instruction :: struct {
    handle: InstructionHandler,
    
    name: string,
    length: u8,
}