#+private
package rend

import "core:fmt"
import "core:math"
import "../mmu"

/*
    DRAWING BEHAVIOUR:
        - Screen is split into 154 Scanlines, first 144 are drawn top-to bottom
    MODES:
        - Mode 0: Horizontal Blank      (376 - mode3 duration)      MEM: VRAM, CGB pal, OAM
            Wait for end of scanline
        - Mode 1: Vertical Blank        (4560 dots)                 MEM: VRAM, CGB pal, OAM
            Wait for end of frame
        - Mode 2: OAM Scan              (80 dots)                   MEM: VRAM, CGB palettes
            Search for objects that overlap the line
        - Mode 3: Horizontal Blank      (between 172 and 289 dots)  MEM: none
            Draw pixels to the screen
    ORDER:
        2 -> 3 -> 0 for SL 0..143
        1           for SL 144..153
*/

RenderMode :: union {
    Mode0,
    Mode1,
    Mode2,
    Mode3
}

Mode0 :: struct {
    scanline: u8,
    elapsed_dots: u32,
    desired_dots: u32
}

Mode1 :: struct {
    scanline: u8,
    elapsed_dots: u32
}

Mode2 :: struct {
    scanline: u8,
    elapsed_dots: u32
}

Mode3 :: struct {
    scanline: u8,
    elapsed_dots: u32,
    scy,scx,curx,wx,wy: u8,
    tile8000: bool,
    windowMap: u16,     // Denotes MAP used for window (0x9800 or 0x9C00)... contains 0x00 if window off
    bgMap: u16
}

switch_mode :: proc(
    ctx: ^PPU,
    scanline: u8,
    mode: RenderMode
) {
    ctx.mode = mode
    mmu.put(ctx.bus, scanline, u16(mmu.IO_REGS.LY), true)
    lcy := mmu.get(ctx.bus, u8, u16(mmu.IO_REGS.LYC), true)
    mmu.set_bit_flag(ctx.bus, u16(mmu.IO_REGS.STAT), 2, lcy == scanline)
}

update_render_mode :: proc(
    ctx: ^PPU,
    mode: ^RenderMode
) {
    switch &inst in mode {
        case Mode0: 
            update_render_mode_0(ctx, &inst)
            return
        case Mode1: 
            update_render_mode_1(ctx, &inst)
            return
        case Mode2: 
            update_render_mode_2(ctx, &inst)
            return
        case Mode3: 
            update_render_mode_3(ctx, &inst)
            return
    }
}

/*
    Wait for end of scanline
*/
update_render_mode_0 :: proc(
    ctx: ^PPU,
    state: ^Mode0
) {
    if state.elapsed_dots == state.desired_dots {
        if state.scanline == 143 do switch_mode(ctx, state.scanline + 1, Mode1{ scanline = state.scanline + 1, elapsed_dots = 0 })
        else do switch_mode(ctx, state.scanline + 1, Mode2{ scanline = state.scanline + 1, elapsed_dots = 0 })
    }
    state.elapsed_dots += 1
}

/*
    Wait until next frame
*/
update_render_mode_1 :: proc(
    ctx: ^PPU,
    state: ^Mode1
) {
    if state.elapsed_dots == 456 {
        if state.scanline == 153 do switch_mode(ctx, 0, Mode2{ scanline = 0, elapsed_dots = 0 })
        else do switch_mode(ctx, state.scanline + 1, Mode1{ scanline = state.scanline + 1, elapsed_dots = 0 })
    }
    state.elapsed_dots += 1
}

/*
    Search for OBJ that overlap line
*/
update_render_mode_2 :: proc(
    ctx: ^PPU,
    state: ^Mode2
) {

    //TODO: OAM Scan
    if state.elapsed_dots == 80 {
        switch_mode(ctx, state.scanline, Mode3{ 
            scanline = state.scanline, 
            elapsed_dots = 0, 
            scy = mmu.get(ctx.bus, u8, 0xFF42, true),
            scx = mmu.get(ctx.bus, u8, 0xFF43, true),
            tile8000 = mmu.get_bit_flag(ctx.bus, 0xFF40, 4),
            windowMap = mmu.get_bit_flag(ctx.bus, 0xFF40, 5) ? (mmu.get_bit_flag(ctx.bus, 0xFF40, 6) ? 0x9C00 : 0x9800) : 0x00, // Set Window-Tilemap, 0x00 if disabled
            bgMap = mmu.get_bit_flag(ctx.bus, 0xFF40, 3) ? 0x9C00 : 0x9800
        })
        return 
    }
    state.elapsed_dots += 1
}

/*
    Draw pixels to buffer
*/
update_render_mode_3 :: proc(
    ctx: ^PPU,
    state: ^Mode3
) {

    //when ODIN_DEBUG do fmt.printfln("Updating Mode3: %i", state.curx)

    if state.elapsed_dots == 172 {
        switch_mode(ctx, state.scanline, Mode0{ 
            scanline = state.scanline,
            elapsed_dots = 0, 
            desired_dots = 376 - state.elapsed_dots
        })
        return 
    }

    if state.curx > 159 {
        state.elapsed_dots += 1
        return 
    }

    if state.curx % 8 == 0 {
        // Draw Background
        {
            //Do 8 pixels at once, because why not
            mapX := (u16(state.scx) + u16(state.curx)) % 256
            mapY := (u16(state.scy) + u16(state.scanline)) % 256
            //fmt.printfln("mapY: %i + %i = %i", state.scy, state.scanline, mapY)
            tileX := math.floor_div(u8(mapX), 8)
            tileY := math.floor_div(u8(mapY), 8)
            tileR := mapY % 8

            tileRow: u16
            if state.tile8000 {
                tileIdx := get_map_tile(ctx, u8(tileX), u8(tileY), state.bgMap)
                tileRow = get_tile_row(ctx, tileIdx, u8(tileR))
            } else {
                tileIdx := get_map_tile_8800(ctx, u8(tileX), u8(tileY), state.bgMap)
                tileRow = get_tile_row(ctx, tileIdx, u8(tileR))          
            }

            render_row(ctx, tileRow, state.curx, state.scanline)
        }

        // Draw Window as overlay
        if state.windowMap != 0x00 {
            mapX := u8(u16(state.curx) % 256)
            mapY := u8(u16(state.scanline) % 256)
            tileX := math.floor_div(mapX, 8)
            tileY := math.floor_div(mapY, 8)
            tileR := mapY % 8

            tileRow: u16
            if state.tile8000 {
                tileIdx := get_map_tile(ctx, u8(tileX), u8(tileY), state.windowMap)
                tileRow = get_tile_row(ctx, tileIdx, u8(tileR))
            } else {
                tileIdx := get_map_tile_8800(ctx, u8(tileX), u8(tileY), state.windowMap)
                tileRow = get_tile_row(ctx, tileIdx, u8(tileR))
            }

            fmt.printfln("Rendering Window...")
            render_row(ctx, tileRow, state.curx, state.scanline)
        }
    }
    state.curx += 1
    state.elapsed_dots += 1
}