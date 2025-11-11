package main

import "core:time"
import "core:flags"
import "core:os"
import "core:fmt"

import rl "vendor:raylib"

import "sm83"
import "mmu"
import "cartridge"

EmuArgs :: struct {
    bios: os.Handle `args:"pos=0,required,file=r" usage:"bios-rom."`,
    rom: os.Handle `args:"pos=1,required,file=r" usage:"Rom file."`,
}

EmuContext :: struct {
    args: EmuArgs,
    cpu: sm83.CPU,
    cart: cartridge.Cartridge,
    bus: mmu.MMU
}

main :: proc() {
    ctx: EmuContext
    if !make_emu_context(&ctx) {
        fmt.eprintfln("[OdinGB] Failed to initialize, shutting down")
        return 
    }
    defer delete_emu_context(&ctx)

    /*
    // Setup Debug context (skip boot rom)
    mmu.put(&ctx.bus, 0xFF, u16(mmu.IO_REGS.BANK))
    fmt.printfln("[DEBUG] Set BANK_REGISTER to %#02X", mmu.get(&ctx.bus, u8, u16(mmu.IO_REGS.BANK)))
    */
    
    rl.InitWindow(480, 432, "OdinGB")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    rot : f32 = 0.0
    for !rl.WindowShouldClose() {
        elapsed_cycles : u32 = 0
        for elapsed_cycles < 512 {    // Execute instructions for roughly one frame (60Hz refresh), each cycle = 1T = 1/4 M
            cycles := sm83.step(&ctx.cpu, &ctx.bus)
            // Update PPU and other modules with cycles
            elapsed_cycles += cycles
        }

        rl.BeginDrawing()
        
        rl.ClearBackground(rl.BLACK)

        rot += 1
        if rot > 360 do rot = 0.0
        rl.DrawRectanglePro({ 220, 196, 40, 40 }, { 0.5, 0.5 }, rot, rl.BLUE)

        rl.EndDrawing()
    }
}

make_emu_context :: proc(ctx: ^EmuContext) -> bool {
    when ODIN_DEBUG { fmt.printfln("Initializing Emulator") }

    style : flags.Parsing_Style = .Odin
    flags.parse_or_exit(&ctx.args, os.args, style);

    sm83.init(&ctx.cpu)

    if !cartridge.init(&ctx.cart, ctx.args.rom) {
        when ODIN_DEBUG do fmt.eprintfln("[OdinGB-Init] Failed to initialize Cartridge")
        return false
    }

    if !mmu.init(&ctx.bus, ctx.args.bios, &ctx.cart) {
        when ODIN_DEBUG do fmt.eprintfln("[OdinGB-Init] Failed to initialize MMU")
        return false
    }

    return true
}

delete_emu_context :: proc(ctx: ^EmuContext) {
    sm83.deinit(&ctx.cpu)
    mmu.deinit(&ctx.bus)
    cartridge.deinit(&ctx.cart)
}