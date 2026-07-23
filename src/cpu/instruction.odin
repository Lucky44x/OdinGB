#+private
package cpu

import "core:log"
import "core:fmt"
import "base:runtime"

op_8 :: enum(u8) { b, c, d, e, h, l, mem, a }
op_16 :: enum(u8) { bc, de, hl, sp }
op_16_stk :: enum(u8) { bc, de, hl, af }
op_16_mem :: enum(u8) { bc, de, hlp, hlm }
op_cond :: enum(u8) { nz, z, nc, c }

/*
    b3 -> 3 bit bit index
    tgt3 -> rst target address divided by 8
    imm8 / n -> Immidiate 8 bit
    imm16 / m -> Immediate 16 bit
*/

@(private="file")
InstructionTable: [256]Instruction

InstructionHandler :: proc(
    cpu: ^CPU,
    opcode: u8
) -> u8

Instruction :: struct {
    handle: InstructionHandler,
    
    name: string,
    length: u8,
}

@(init)
setup_instruction_table :: proc "contextless"() {
    register_load_instructions(&InstructionTable)
}

decode_r8_dst :: #force_inline proc(opcode: u8) -> op_8 {
    return op_8((opcode >> 3) & 0b111)
}

decode_r8_src :: #force_inline proc(opcode: u8) -> op_8 {
    return op_8(opcode & 0b111)
}

register_instruction :: proc "contextless"(
    table: ^[256]Instruction,
    handler: InstructionHandler,
    name: string,
    mask: u8,
    value: u8,
    length: u8 = 1,
    allow_override := false,
) {
    context = runtime.default_context()

    for opcode_int in 0..<256 {
        opcode := u8(opcode_int)

        if opcode & mask != value {
            continue
        }

        if table[opcode].length > 0 {
            log.errorf("Opcode %02X was already registered -> %s -- %d", opcode, table[opcode].name, table[opcode].length)
            assert(false)
        }

        table[opcode] = {
            handle = handler,
            name    = name,
            length  = length,
        }
    }
}

handle_instruction :: proc(
    cpu: ^CPU,
    opcode: u8
) -> (cycles: u8) {
    if InstructionTable[opcode].length == 0 do return 0
    return InstructionTable[opcode].handle(cpu, opcode)
}