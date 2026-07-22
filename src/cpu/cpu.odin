package cpu

import "core:fmt"
import ins "instructions"

@(private="file")
InstructionTable :: [256]ins.Instruction

CPU :: struct {
    regs: Registers,
}

step :: proc(
    machine: ^CPU,
    bus: ^Bus_Access,
) {
    //TODO Run decoder and then execute instruction accordingly
}