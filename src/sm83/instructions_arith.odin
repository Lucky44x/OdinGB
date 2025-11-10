#+private
#+feature dynamic-literals
package sm83

import "base:builtin"
import "core:fmt"
import "../mmu"

/*
    registers all arithmetic-instructions

    ONLY USE ONCE AT STARTUP
*/
register_arith_instructions :: proc() {
    /*
    register_instruction("01xxxxxx", Instruction{ handler=ld_r8_r8,     length=1, name="LD r8 r8" })
    register_instruction("00xxx110", Instruction{ handler=ld_r8_imm8,   length=2, name="LD r8 imm8" })
    register_instruction("00xx0001", Instruction{ handler=ld_r16_imm16, length=3, name="LD r16 imm16" })
    register_instruction("01xxx110", Instruction{ handler=ld_r8_HLmem,  length=1, name="LD r8 [HL]" })
    register_instruction("01110xxx", Instruction{ handler=ld_HLmem_r8,  length=1, name="LD [HL] r8" })
    register_instruction("00xx1010", Instruction{ handler=ld_A_r16mem,  length=1, name="LD A [r16]" })
    register_instruction("00xx0010", Instruction{ handler=ld_r16mem_A,  length=1, name="LD [r16] A" })
    register_instruction("11xx0101", Instruction{ handler=push_r16,     length=1, name="PUSH r16stk" })
    register_instruction("11xx0001", Instruction{ handler=pop_r16,      length=1, name="POP r16stk" })

    // Register constant opcodes after patterend, so that in doubt, they will overide
    register_instruction(0x36, Instruction{ handler=ld_HLmem_imm8,  length=2, name="LD [HL] imm8" })
    register_instruction(0xFA, Instruction{ handler=ld_A_imm16mem,  length=3, name="LD A [imm16]" })
    register_instruction(0xEA, Instruction{ handler=ld_imm16mem_A,  length=3, name="LD [imm16] A" })
    register_instruction(0xF2, Instruction{ handler=ldh_A_Cmem,     length=1, name="LDH A [C]" })
    register_instruction(0xE2, Instruction{ handler=ldh_Cmem_A,     length=1, name="LDH [C] A" })
    register_instruction(0xF0, Instruction{ handler=ldh_A_imm8mem,  length=2, name="LDH A [imm8]" })
    register_instruction(0xE0, Instruction{ handler=ldh_imm8mem_A,  length=2, name="LDH [imm8] A" })
    register_instruction(0x3A, Instruction{ handler=ldd_A_HLmem,    length=1, name="LD A [HL-]" })
    register_instruction(0x32, Instruction{ handler=ldd_HLmem_A,    length=1, name="LD [HL-] A" })
    register_instruction(0x2A, Instruction{ handler=ldi_A_HLmem,    length=1, name="LD A [HL+]" })
    register_instruction(0x22, Instruction{ handler=ldi_HLmem_A,    length=1, name="LD [HL+] A" })
    register_instruction(0x08, Instruction{ handler=ld_SP_imm16mem, length=3, name="LD SP [imm16]" })
    register_instruction(0xF9, Instruction{ handler=ld_SP_HL,       length=1, name="LD SP HL" })
    register_instruction(0xF8, Instruction{ handler=ld_HL_SPe,      length=2, name="LD HL SP+e" })
    */
}