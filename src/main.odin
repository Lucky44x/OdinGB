package main

import "core:flags"
import "core:os"
import "core:fmt"

import rl "vendor:raylib"

import "sm83"

EmuArgs :: struct {
    bios: os.Handle `args:"pos=0,required,file=r" usage:"bios-rom."`,
    rom: os.Handle `args:"pos=1,required,file=r" usage:"Rom file."`,
}

EmuContext :: struct {
    args: EmuArgs,
    cpu: sm83.CPU,
}

main :: proc() {
    ctx: EmuContext
    make_emu_context(&ctx)
    defer delete_emu_context(&ctx)

    rl.InitWindow(480, 432, "OdinGB")
    defer rl.CloseWindow()

    /*  ====== DEBUG

    sm83.set_register(&ctx.cpu, sm83.REG8.A, 0xA7)
    sm83.set_register(&ctx.cpu, sm83.REG16.PC, 0xFFA7)

    val1 := sm83.get_register(&ctx.cpu, sm83.REG8.A)
    val2 := sm83.get_register(&ctx.cpu, sm83.REG16.PC)

    fmt.printfln("%#02X", val1)
    fmt.printfln("%#04X", val2)
    
    */

    for !rl.WindowShouldClose() {
        elapsed_cycles : u32 = 0
        for elapsed_cycles < 70224 {    // Execute instructions for roughly one frame (60Hz refresh), each cycle = 1T = 1/4 M
            cycles := sm83.step(&ctx.cpu)
            // Update APU and other modules with cycles
            elapsed_cycles += cycles
        }

        rl.BeginDrawing()
        
        rl.ClearBackground(rl.BLACK)
        
        rl.EndDrawing()
    }
}

make_emu_context :: proc(ctx: ^EmuContext) {
    when ODIN_DEBUG { fmt.printfln("Initializing Emulator") }

    style : flags.Parsing_Style = .Odin
    flags.parse_or_exit(&ctx.args, os.args, style);

    sm83.init(&ctx.cpu)
    //gbmem.mem_init(&ctx.mem, ctx.args.bios, ctx.args.rom)
}

delete_emu_context :: proc(ctx: ^EmuContext) {
    //gbmem.mem_deinit(ctx.mem)
    sm83.deinit(&ctx.cpu)
}