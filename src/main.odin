package main

import "core:time"
import "core:flags"
import "core:os"
import "core:fmt"
import "core:mem"

import rl "vendor:raylib"

import "sm83"
import "mmu"
import "timer"
import "cartridge"
import "rend"
import "sound"

import "core:log"

DEBUG_PRINT :: #config(VERBOSE, false)
SCALE :: 5
DBG_SCALE :: (SCALE * 160) / 256

when DEBUG_PRINT {
    CYCLES_PER_FRAME :: 15000
} else {
    CYCLES_PER_FRAME :: 70224
}

EmuDBGMode :: enum {
    PLAYBACK,
    TILEMAP,
    TILESET
}

EmuArgs :: struct {
    bios: os.Handle `args:"pos=0,required,file=r" usage:"bios-rom."`,
    rom: os.Handle `args:"pos=1,required,file=r" usage:"Rom file."`
}

EmuContext :: struct {
    logger: log.Logger,
    args: EmuArgs,
    cpu: sm83.CPU,
    timer: timer.Timer,
    cart: cartridge.Cartridge,
    bus: mmu.MMU,
    ppu: rend.PPU,
    apu: sound.APU,

    dbgX, dbgY: u8,
    mode: EmuDBGMode,
    paused, tileMapSwitch, tileSetSwitch: bool
}

main :: proc() {
    when DEBUG_PRINT {
        f_hand, f_err := os.open("./logs/verbose.log", (os.O_CREATE | os.O_TRUNC | os.O_RDWR))
        if f_err != nil {
            fmt.eprintfln("Error during log file opening: %e", f_err)
            return 
        }

        logger := log.create_file_logger(f_hand)
    } else do logger := log.create_console_logger()
    context.logger = logger

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
        log.errorf("[OdinGB] Failed to initialize, shutting down")
        return
    }
    defer delete_emu_context(&ctx)

    // Setup Debug context (skip boot rom)
    //mmu.put(&ctx.bus, 0x01, 0xFF50)
    //log.info("[DEBUG] Set BANK_REGISTER to %#02X", mmu.get(&ctx.bus, u8, u16(mmu.IO_REGS.BANK)))
    
    rl.SetTargetFPS(59)

    rot : f32 = 0.0
    for !rl.WindowShouldClose() {
        emu_state_input(&ctx)

        if !ctx.paused do emu_step_frame(&ctx)

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        switch ctx.mode {
            case .PLAYBACK: emu_render_screen(&ctx)
            case .TILEMAP: emu_render_tilemap(&ctx)
            case .TILESET: emu_render_tileset(&ctx)
            case: break
        }

        if ctx.paused do rl.DrawText("PAUSED", 5, 144*SCALE - 12, 12, rl.YELLOW)

        rl.EndDrawing()
    }

    when DEBUG_PRINT do log.destroy_file_logger(logger)
    else do log.destroy_console_logger(logger)
}

emu_render_tilemap :: proc(
    ctx: ^EmuContext
) {
    rend.render_dbg_map(&ctx.ppu, ctx.tileMapSwitch)
    rl.UpdateTexture(ctx.ppu.dbgTarget, ctx.ppu.dbgBuffer)
    rl.DrawTextureEx(ctx.ppu.dbgTarget, {0,0}, 0, DBG_SCALE, rl.WHITE)
    rl.DrawText(rl.TextFormat("Tilemap (%i)", ctx.tileMapSwitch ? 1 : 0), 5, 5, 12, rl.YELLOW)
    
    scy := mmu.get(&ctx.bus, u8, 0xFF42, true)
    scx := mmu.get(&ctx.bus, u8, 0xFF43, true)
    rl.DrawRectangle(i32(scx), i32(scy), 160 * DBG_SCALE, 144 * DBG_SCALE, rl.ColorAlpha(rl.RED, 0.75))
}

emu_render_tileset :: proc(
    ctx: ^EmuContext
) {
    rl.DrawText(rl.TextFormat("Tileset (%i)", ctx.tileSetSwitch ? 1 : 0), 5, 5, 12, rl.YELLOW)
}

emu_render_screen :: proc(
    ctx: ^EmuContext
) {
    if mmu.get_bit_flag(&ctx.bus, u16(mmu.IO_REGS.LCDC), 7) do rl.DrawTextureEx(ctx.ppu.renderTarget, {0,0}, 0, SCALE, rl.WHITE)
}

emu_state_input :: proc(
    ctx: ^EmuContext
) {
    if rl.IsKeyPressed(.P) do ctx.paused = !ctx.paused
    if rl.IsKeyPressed(.RIGHT) {
        ctx.mode = ctx.mode == .PLAYBACK ? .TILEMAP : ctx.mode == .TILEMAP ? .TILESET : .PLAYBACK
    }

    if rl.IsKeyPressed(.SPACE) {
        switch ctx.mode {
            case .PLAYBACK: break
            case .TILEMAP: ctx.tileMapSwitch = !ctx.tileMapSwitch
            case .TILESET: ctx.tileSetSwitch = !ctx.tileSetSwitch
            case: break
        }
    }
}

emu_step_frame :: proc(
    ctx: ^EmuContext
) {
    wait_cpu_cycles : u32 = 0
    for cycles in 0 ..< CYCLES_PER_FRAME {    // Execute instructions for roughly one frame (60Hz refresh), each cycle = 1T = 1/4 M
        if wait_cpu_cycles == 0 do wait_cpu_cycles = sm83.step(&ctx.cpu, &ctx.bus)
        else do wait_cpu_cycles -= 1

        //Step timing stuff
        timer.div_step(&ctx.timer, &ctx.bus)
        timer.timer_step(&ctx.timer, &ctx.bus, &ctx.cpu)

        rend.step(&ctx.ppu)
        sound.step(&ctx.apu)
    }

    rl.UpdateTexture(ctx.ppu.renderTarget, ctx.ppu.frameBuffer)
    sound.flush_to_audio_device(&ctx.apu)
}

make_emu_context :: proc(ctx: ^EmuContext) -> bool {
    when ODIN_DEBUG && DEBUG_PRINT { log.info("Initializing Emulator") }

    style : flags.Parsing_Style = .Odin
    flags.parse_or_exit(&ctx.args, os.args, style);

    sm83.init(&ctx.cpu)
    when ODIN_DEBUG && DEBUG_PRINT do log.errorf("[OdinGB-Init] Initialized CPU (1/5)")

    if !cartridge.init(&ctx.cart, ctx.args.rom) {
        when ODIN_DEBUG && DEBUG_PRINT do log.errorf("[OdinGB-Init] Failed to initialize Cartridge")
        return false
    }
    when ODIN_DEBUG && DEBUG_PRINT do log.errorf("[OdinGB-Init] Initialized Cartridge (2/5)")

    if !mmu.init(&ctx.bus, ctx.args.bios, &ctx.cart) {
        when ODIN_DEBUG && DEBUG_PRINT do log.errorf("[OdinGB-Init] Failed to initialize MMU")
        return false
    }
    when ODIN_DEBUG && DEBUG_PRINT do log.errorf("[OdinGB-Init] Initialized MMU (3/5)")

    rend.make_ppu(&ctx.ppu, &ctx.bus, &ctx.cpu)
    when ODIN_DEBUG && DEBUG_PRINT do log.errorf("[OdinGB-Init] Initialized renderer (4/5)")

    sound.make_apu(&ctx.apu, &ctx.bus)
    when ODIN_DEBUG && DEBUG_PRINT do log.errorf("[OdinGB-Init] Initialized renderer (4/5)")

    return true
}

delete_emu_context :: proc(ctx: ^EmuContext) {
    sm83.deinit(&ctx.cpu)
    mmu.deinit(&ctx.bus)
    cartridge.deinit(&ctx.cart)
    rend.delete_ppu(&ctx.ppu)
}