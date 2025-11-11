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

SCALE :: 3

EmuArgs :: struct {
    bios: os.Handle `args:"pos=0,required,file=r" usage:"bios-rom."`,
    rom: os.Handle `args:"pos=1,required,file=r" usage:"Rom file."`,
}

EmuContext :: struct {
    args: EmuArgs,
    cpu: sm83.CPU,
    cart: cartridge.Cartridge,
    bus: mmu.MMU,
    ppu: rend.PPU
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
    
    rl.SetTargetFPS(60)

    rot : f32 = 0.0
    for !rl.WindowShouldClose() {
        elapsed_cycles : u32 = 0
        for elapsed_cycles < 512 {    // Execute instructions for roughly one frame (60Hz refresh), each cycle = 1T = 1/4 M
            cycles := sm83.step(&ctx.cpu, &ctx.bus)
            // Update PPU and other modules with cycles
            elapsed_cycles += cycles
            //if !ctx.cpu.running do return 
        }

        // Try drawing one or two tiles
        tile1 := rend.get_tile_data(&ctx.ppu, u8(0))
        tile2 := rend.get_tile_data(&ctx.ppu, u8(1))

        rend.clear_ppu(&ctx.ppu)
        rend.render_tile(&ctx.ppu, tile1, 5, 5)
        rend.render_tile(&ctx.ppu, tile2, 5, 5)
        
        rl.UpdateTexture(ctx.ppu.renderTarget, ctx.ppu.frameBuffer)

        rl.BeginDrawing()
        
        rl.ClearBackground(rl.BLACK)

        rl.DrawTextureEx(ctx.ppu.renderTarget, {0,0}, 0, SCALE, rl.WHITE)

        rl.EndDrawing()
    }

    _ = rend.get_tile_data_8000(&ctx.ppu, 0)
}

make_emu_context :: proc(ctx: ^EmuContext) -> bool {
    when ODIN_DEBUG { fmt.printfln("Initializing Emulator") }

    style : flags.Parsing_Style = .Odin
    flags.parse_or_exit(&ctx.args, os.args, style);

    sm83.init(&ctx.cpu)
    when ODIN_DEBUG do fmt.eprintfln("[OdinGB-Init] Initialized CPU (1/4)")

    if !cartridge.init(&ctx.cart, ctx.args.rom) {
        when ODIN_DEBUG do fmt.eprintfln("[OdinGB-Init] Failed to initialize Cartridge")
        return false
    }
    when ODIN_DEBUG do fmt.eprintfln("[OdinGB-Init] Initialized Cartridge (2/4)")

    rend.make_ppu(&ctx.ppu)
    when ODIN_DEBUG do fmt.eprintfln("[OdinGB-Init] Initialized renderer (3/4)")

    if !mmu.init(&ctx.bus, ctx.args.bios, &ctx.cart, &ctx.ppu) {
        when ODIN_DEBUG do fmt.eprintfln("[OdinGB-Init] Failed to initialize MMU")
        return false
    }
    when ODIN_DEBUG do fmt.eprintfln("[OdinGB-Init] Initialized MMU (4/4)")

    return true
}

delete_emu_context :: proc(ctx: ^EmuContext) {
    sm83.deinit(&ctx.cpu)
    mmu.deinit(&ctx.bus)
    cartridge.deinit(&ctx.cart)
    rend.delete_ppu(&ctx.ppu)
}