package main

import "core:time"
import "core:flags"
import "core:os"
import "core:fmt"
import "core:mem"

import rl "vendor:raylib"

import "sm83"
import "mmu"
import "cartridge"
import "rend"
import "sound"

DEBUG_PRINT :: #config(VERBOSE, false)
SCALE :: 5

when ODIN_DEBUG && DEBUG_PRINT {
    CYCLES_PER_FRAME :: 150
} else {
    CYCLES_PER_FRAME :: 70224
}

EmuArgs :: struct {
    bios: os.Handle `args:"pos=0,required,file=r" usage:"bios-rom."`,
    rom: os.Handle `args:"pos=1,required,file=r" usage:"Rom file."`,
}

EmuContext :: struct {
    args: EmuArgs,
    cpu: sm83.CPU,
    cart: cartridge.Cartridge,
    bus: mmu.MMU,
    ppu: rend.PPU,
    apu: sound.APU
}

main :: proc() {
    when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

    rl.InitWindow(160*SCALE, 144*SCALE, "OdinGB")
    defer rl.CloseWindow()

    ctx: EmuContext
    if !make_emu_context(&ctx) {
        fmt.eprintfln("[OdinGB] Failed to initialize, shutting down")
        return 
    }
    defer delete_emu_context(&ctx)

    // Setup Debug context (skip boot rom)
    //mmu.put(&ctx.bus, 0x01, 0xFF50)
    //fmt.printfln("[DEBUG] Set BANK_REGISTER to %#02X", mmu.get(&ctx.bus, u8, u16(mmu.IO_REGS.BANK)))
    
    rl.SetTargetFPS(59)

    rot : f32 = 0.0
    for !rl.WindowShouldClose() {
        wait_cpu_cycles : u32 = 0
        for cycles in 0 ..< CYCLES_PER_FRAME {    // Execute instructions for roughly one frame (60Hz refresh), each cycle = 1T = 1/4 M
            if wait_cpu_cycles == 0 do wait_cpu_cycles = sm83.step(&ctx.cpu, &ctx.bus)
            else do wait_cpu_cycles -= 1
            rend.step(&ctx.ppu)
            sound.step(&ctx.apu)
        }


        rl.UpdateTexture(ctx.ppu.renderTarget, ctx.ppu.frameBuffer)
        sound.flush_to_audio_device(&ctx.apu)

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        if mmu.get_bit_flag(&ctx.bus, u16(mmu.IO_REGS.LCDC), 7) do rl.DrawTextureEx(ctx.ppu.renderTarget, {0,0}, 0, SCALE, rl.WHITE)
        rl.EndDrawing()
    }

    _ = rend.get_tile_data_8000(&ctx.ppu, 0)
}

make_emu_context :: proc(ctx: ^EmuContext) -> bool {
    when ODIN_DEBUG && DEBUG_PRINT { fmt.printfln("Initializing Emulator") }

    style : flags.Parsing_Style = .Odin
    flags.parse_or_exit(&ctx.args, os.args, style);

    sm83.init(&ctx.cpu)
    when ODIN_DEBUG && DEBUG_PRINT do fmt.eprintfln("[OdinGB-Init] Initialized CPU (1/5)")

    if !cartridge.init(&ctx.cart, ctx.args.rom) {
        when ODIN_DEBUG && DEBUG_PRINT do fmt.eprintfln("[OdinGB-Init] Failed to initialize Cartridge")
        return false
    }
    when ODIN_DEBUG && DEBUG_PRINT do fmt.eprintfln("[OdinGB-Init] Initialized Cartridge (2/5)")

    if !mmu.init(&ctx.bus, ctx.args.bios, &ctx.cart) {
        when ODIN_DEBUG && DEBUG_PRINT do fmt.eprintfln("[OdinGB-Init] Failed to initialize MMU")
        return false
    }
    when ODIN_DEBUG && DEBUG_PRINT do fmt.eprintfln("[OdinGB-Init] Initialized MMU (3/5)")

    rend.make_ppu(&ctx.ppu, &ctx.bus)
    when ODIN_DEBUG && DEBUG_PRINT do fmt.eprintfln("[OdinGB-Init] Initialized renderer (4/5)")

    sound.make_apu(&ctx.apu, &ctx.bus)
    when ODIN_DEBUG && DEBUG_PRINT do fmt.eprintfln("[OdinGB-Init] Initialized renderer (4/5)")

    return true
}

delete_emu_context :: proc(ctx: ^EmuContext) {
    sm83.deinit(&ctx.cpu)
    mmu.deinit(&ctx.bus)
    cartridge.deinit(&ctx.cart)
    rend.delete_ppu(&ctx.ppu)
}