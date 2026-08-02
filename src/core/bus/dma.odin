package bus

import "core:log"
@(private)
DMA_State :: struct {
    enabled: bool,
    origin_addr: u16,
    progress: u16,
}

step_dma :: proc(ctx: ^Bus, elapsed_m: u16) {
    //TODO: Add a separate CGB HDMA/GDMA controller; OAM DMA has different
    //TODO: blocking and timing rules from VRAM DMA.
    if !ctx.dma.enabled do return

    for i in 0..<elapsed_m {
        if ctx.dma.progress >= 160 do break

        val := bus_read(ctx, ctx.dma.origin_addr + ctx.dma.progress, true)
        bus_write(ctx, 0xFE00 + ctx.dma.progress, val, true)

        ctx.dma.progress += 1
    }

    if ctx.dma.progress >= 160 do ctx.dma.enabled = false
}
