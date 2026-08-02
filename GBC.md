# Game Boy Color Compatibility Report

## Executive Summary

The emulator is currently a DMG-oriented implementation. GBC support is possible, but it is not limited to adding the existing CGB register constants. The largest changes are required in:

- Cartridge detection, mapper state, and external RAM
- Banked WRAM and VRAM
- CGB palette RAM and color transport
- PPU tile attributes, sprite attributes, window rendering, and priority
- CPU double-speed mode and clock-domain separation
- HDMA/GDMA
- Frontend and debugger assumptions about four-color output

The CPU instruction handlers and most APU logic are reusable. The current PPU/bus interfaces, however, encode DMG assumptions that must be changed before CGB games can run reliably.

Overall difficulty: **high** for broad compatibility. A limited first milestone supporting ROM-only CGB software in CGB mode is **medium-high**. Full commercial compatibility including MBC3/MBC5, external RAM, RTC, HDMA, accurate priority, and double speed is **high**.

## Current Compatibility Baseline

Already reusable or partially prepared:

- CPU opcode handlers are generally shared between DMG and CGB.
- Screen dimensions remain 160x144.
- PPU line timing uses the same 456-dot scanline structure used by CGB hardware.
- APU register and channel model is not inherently DMG-only.
- CGB register constants already exist in `src/core/common/busaccess.odin`.
- `pack_rgba555a1` provides a possible starting point for color conversion.
- Mapper type constants list many CGB-era mapper families, although implementations are missing.

Currently DMG-only or incomplete:

- No explicit DMG/CGB hardware mode exists.
- The cartridge header is logged but not retained.
- Every loaded cartridge uses `MAPPER_Basic`.
- External cartridge RAM is absent.
- WRAM and VRAM each have only one bank.
- CGB palette registers have no backing RAM or side effects.
- PPU output is a four-value color index.
- CGB tile and sprite attributes are ignored.
- Window rendering is absent.
- KEY1 and double-speed mode are absent.
- HDMA/GDMA are absent.
- CGB boot-ROM mapping is absent.
- Frontend viewers assume a single VRAM bank and a four-color palette.

## System Mode and Cartridge Detection

### `src/core/cartridge/header.odin`

`read_cart_header` currently logs header values and discards them. GBC mode selection needs persistent header metadata, especially:

- CGB flag at `$0143`
- Cartridge type at `$0147`
- ROM size at `$0148`
- RAM size at `$0149`
- Licensee and destination metadata where needed

Add a stored `Cartridge_Header` containing at least:

- `cgb_flag`
- CGB-compatible and CGB-only flags
- Mapper type
- ROM bank count/size
- External RAM size
- Battery and RTC capabilities

Mode selection must distinguish DMG-only, CGB-compatible, and CGB-only cartridges. A CGB-compatible title may boot in DMG mode with a DMG BIOS, while a CGB-only title requires CGB hardware and BIOS behavior.

### `src/core/cartridge/cart.odin`

`Cartridge` currently contains only `loaded`, a mapper, and a ROM union. It needs to own or reference:

- Parsed header data
- Hardware compatibility mode
- Mapper registers
- External RAM
- RAM enable state and selected RAM bank
- Battery persistence state
- RTC state for MBC3
- Rumble state where applicable

`cartridge_load_direct` currently always sets `MAPPER_Basic`. It must parse the header first and construct the correct mapper.

The current `cartridge_write` is a stub. Mapper writes are required for bank switching and RAM access.

There is also an ownership issue independent of GBC: `ROM_Bulk` stores a borrowed slice, but `cartridge_unload` deletes it. The ownership contract must be corrected before adding flash-backed or caller-owned cartridge storage.

### `src/core/cartridge/mapper.odin` and `MBC1.odin`

Only the basic no-mapper address mapping exists. `MBC1.odin` is empty despite the mapper enum containing many types.

Recommended mapper order:

1. ROM-only
2. MBC1
3. MBC3, including RTC state
4. MBC5, including its larger ROM bank register

These cover a large portion of commercial DMG/GBC software. MBC2, MBC6/7, MMM01, HuC, and special cartridges can follow later.

### `src/core/bus/bus.odin`

The `$A000-$BFFF` path currently calls `read_rom`; it must route to mapper-controlled external RAM. Writes in this range must also reach the cartridge RAM implementation.

## Boot ROM and Hardware Mode

### `src/core/core.odin`

`GB_Core` has no explicit hardware mode. Add a mode enum such as `DMG` and `CGB`, then pass it to the bus, PPU, CPU/timing layer, cartridge, and frontend.

Mode should be selected during cartridge/core initialization rather than inferred from whether CGB registers exist.

### `src/core/bus/boot_rom.odin` and `bus.odin`

The current boot mapping is:

```odin
if !ctx.is_banked && addr <= 0xFF do return ctx.boot_rom.data[addr]
```

This is DMG-specific. CGB startup maps additional BIOS regions, notably the range beyond `$00FF` through the CGB startup sequence. The BIOS type and length must also be validated.

`$FF50` should be represented as a one-way boot-ROM disable latch rather than the generic `is_banked` name. The bus must select a DMG or CGB mapping table based on hardware mode.

## Memory Banking

### WRAM: `src/core/bus/ram.odin` and `bus.odin`

DMG has 8 KiB of WRAM. CGB has eight 4 KiB banks:

- Bank 0 fixed at `$C000-$CFFF`
- Bank 1-7 selected at `$D000-$DFFF`
- `$FF70` (`SVBK`) selects the active bank
- A written bank value of 0 selects bank 1

The current `Bus_RAM.wram: [8192]u8` cannot represent this. A CGB representation should use `[8][0x1000]u8` or caller-provided equivalent storage.

Echo RAM mappings must use the same bank selection rules.

### VRAM: `src/core/ppu/varm.odin`, `ppu.odin`, and `io.odin`

CGB VRAM consists of two 8 KiB banks selected for CPU access using `$FF4F` (`VBK`). The current `VRAM` contains one `[0x2000]u8` array and ignores `VBK`.

The CPU-visible bank and the renderer's tile-data bank are different concepts. The renderer must be able to read both banks regardless of the current CPU-selected bank because tile attributes select the rendering bank.

Required changes:

- Store two VRAM banks.
- Implement VBK reads/writes and masking.
- Route CPU reads/writes through the selected bank.
- Allow the PPU renderer to explicitly select bank 0 or bank 1.

## PPU Rendering

### Background and window: `src/core/ppu/rendering.odin`

The current renderer reads one tile ID from the tile map and produces a two-bit color index. CGB tile-map attributes are stored at the same map address in VRAM bank 1.

Attribute bits are:

- Bits 0-2: CGB background palette number
- Bit 3: tile-data VRAM bank
- Bit 5: horizontal flip
- Bit 6: vertical flip
- Bit 7: background priority

The renderer must read both the tile ID and matching attribute byte, select tile data from the requested VRAM bank, apply flips, select one of eight palettes, and apply CGB priority rules.

Window rendering is currently absent. Implementing the window requires:

- LCDC window enable
- LCDC window tile-map select
- WY/WX handling
- A window line counter
- Correct transition between background and window pixels

Window support is not uniquely CGB, but is necessary for broad compatibility.

### Sprites: `src/core/ppu/oam.odin`

The current sprite path treats bit 4 as the DMG palette selector and ignores CGB attributes. CGB sprite attributes require:

- Bits 0-2: CGB object palette number
- Bit 3: tile-data VRAM bank
- Bit 4: unused in CGB mode
- Bit 5: X flip
- Bit 6: Y flip
- Bit 7: priority

Sprite tile reads must select the requested VRAM bank. Sprite ordering and priority also need separate DMG and CGB behavior. The current code explicitly sorts by X position, which is not sufficient for CGB OAM-order rules.

### PPU timing: `src/core/ppu/mode.odin` and `ppu.odin`

The line timing values are broadly reusable, but `ppu.step` currently derives dots directly from CPU M-cycles:

```odin
dots := elapsed_m_cycles * 4
```

That coupling breaks when the CGB CPU enters double speed. PPU dots must continue at the hardware rate while the CPU executes twice as fast.

LCD disable behavior is also unfinished. The PPU should reset mode/line state and expose the correct STAT/LCD behavior when LCDC bit 7 changes.

## CGB Palettes and Color Transport

### Palette registers: `src/core/common/busaccess.odin` and `bus/io.odin`

Implement:

- 64 bytes of background palette RAM
- 64 bytes of object palette RAM
- BCPS/BCPD index/data access
- OCPS/OCPD index/data access
- Index bit 7 auto-increment
- Little-endian 15-bit BGR555 colors

The current raw I/O byte array and masks do not provide these side effects.

### Framebuffer callback: `src/core/common/ppu.odin`

The callback currently accepts:

```odin
^[160]u8
```

That can carry only four-color indexes. Options for CGB output include:

1. Change the callback to `[160]u16` BGR555 colors.
2. Introduce a shared color type.
3. Have the core own a `[160*144]u16` framebuffer and let the frontend convert it.
4. Pass color IDs plus palette data through a more complex callback.

An internal BGR555 framebuffer or a `[160]u16` scanline is the cleanest design. It keeps CGB palette application inside the core and lets the frontend perform only display-format conversion.

### Frontend: `src/emulation_rendering.odin` and `emulation.odin`

The frontend currently uses `GB_Palette :: distinct [4]rl.Color` and applies one fixed DMG palette. It must accept actual per-pixel CGB colors while retaining DMG palette conversion for DMG mode.

The renderer initialization must become mode-aware. It should not convert a CGB pixel into one of four DMG colors.

## CPU Speed and Clock Domains

### KEY1: `src/core/common/busaccess.odin` and `bus/io.odin`

KEY1 requires:

- Current-speed bit
- Prepare-speed-switch bit
- Correct read/write masks
- Speed switch triggered by STOP
- Preparation bit cleared after switching

### CPU: `src/core/cpu/cpu.odin`

STOP currently returns a simple cycle value and does not implement CGB speed switching. The CPU needs a speed state and a way for STOP to request a transition.

### Timing: `src/core/core.odin`, `emulation.odin`, PPU, timer, DMA, and APU

The current core passes one `elapsed_m` value to every subsystem. This works for DMG but is insufficient for CGB double speed.

The implementation needs separate timing domains:

- CPU clock: 1x or 2x
- PPU dot clock: unchanged hardware rate
- Timer/divider clock: hardware-specific base behavior
- OAM DMA clock
- HDMA/GDMA clock
- APU clock

This is one of the highest-risk parts of the port. A single global “elapsed M-cycles” parameter should be replaced with either a master dot/t-cycle clock or per-device clock conversion.

## HDMA and GDMA

### `src/core/common/busaccess.odin`, `bus/io.odin`, and `bus/dma.odin`

The HDMA registers exist, but no controller is implemented. OAM DMA is separate and cannot be reused directly.

Required behavior:

- HDMA1/HDMA2 source registers
- HDMA3/HDMA4 VRAM destination registers
- HDMA5 length/control/status
- General DMA mode
- HBlank DMA mode
- 16-byte transfers per HBlank
- Cancellation semantics
- Source/destination alignment
- CPU blocking behavior for GDMA
- VRAM bank-aware destination writes

HDMA must coordinate with PPU mode transitions, so it should be implemented alongside the timing redesign rather than as an isolated register handler.

## Cartridge Mappers and External RAM

The mapper enum lists many types, but only `Mapper_Basic` is implemented and `MBC1.odin` is empty.

Required cartridge work includes:

- MBC1 ROM/RAM banking
- MBC2 nibble RAM if needed
- MBC3 ROM/RAM banking
- MBC3 RTC registers and time progression
- MBC5 9-bit ROM banking
- RAM enable and selected RAM bank
- Battery-backed save integration
- Rumble variants where applicable

For a practical first GBC milestone, ROM-only, MBC1, MBC3, and MBC5 should be prioritized.

## Audio, Timer, Serial, and DMA Reuse

### APU

The APU is not obviously DMG-only, but its stepping currently receives CPU-derived elapsed cycles. It must be connected to the correct hardware clock when double speed is implemented.

### Timer

`src/core/timer/timer.odin` currently advances from `elapsed_m`. Divider and TIMA timing need review once CPU speed changes, especially around CGB speed switching and STOP.

### Serial

SB/SC registers are declared, but there is no serial device implementation or transfer timing. Serial is not uniquely CGB, but it is commonly exercised by test ROMs and should be added to a complete compatibility target.

### OAM DMA

OAM DMA is currently driven directly by elapsed CPU cycles and blocks most bus accesses. It needs review after clock-domain separation so double-speed CPU execution does not accidentally double or halve DMA timing.

## Frontend and Debug Viewers

### `src/ui_vram_viewer.odin`

The viewer assumes one 8 KiB VRAM bank and four colors. It should provide bank selection and optionally display bank-1 attribute data, palette number, tile bank, flips, and priority.

### `src/ui_tilemap_viewer.odin`

The viewer directly accesses the single linear VRAM array. It needs bank-0/bank-1 selection and CGB attribute visualization.

### `src/ui_object_viewer.odin`

The viewer always reads VRAM bank 0, uses the DMG palette, and does not fully represent CGB sprite attributes. It should show sprite bank, palette, priority, flips, and correct 8x16 rendering.

The existing object buffer comment claims 8x16 support, but the current buffer is only 8x8 pixels and the renderer uses an 8x8 texture.

### `src/emulation.odin`

ROM loading currently does not inspect CGB capability or select a CGB boot ROM. Initialization should:

1. Parse cartridge header.
2. Select DMG or CGB mode.
3. Validate/select the matching BIOS.
4. Initialize the core with the selected mode.
5. Initialize a color-capable renderer.

## Recommended Implementation Phases

### Phase 1: Hardware identity and data model

Files:

- `src/core/core.odin`
- `src/core/cartridge/header.odin`
- `src/core/cartridge/cart.odin`
- `src/core/cartridge/mapper.odin`

Add hardware mode, persistent header metadata, mapper construction, and explicit initialization parameters.

### Phase 2: Memory banking

Files:

- `src/core/bus/ram.odin`
- `src/core/bus/bus.odin`
- `src/core/bus/io.odin`
- `src/core/ppu/varm.odin`
- `src/core/ppu/ppu.odin`

Implement WRAM banking, VRAM banking, SVBK, VBK, safe boot mapping, and external-RAM routing.

### Phase 3: Color PPU

Files:

- `src/core/ppu/rendering.odin`
- `src/core/ppu/oam.odin`
- `src/core/common/ppu.odin`
- `src/core/bus/io.odin`
- `src/emulation_rendering.odin`

Implement palette RAM, tile/sprite attributes, BGR555 output, CGB priority, and window rendering.

### Phase 4: Timing and DMA

Files:

- `src/core/cpu/cpu.odin`
- `src/core/bus/io.odin`
- `src/core/bus/dma.odin`
- `src/core/ppu/ppu.odin`
- `src/core/ppu/mode.odin`
- `src/core/core.odin`
- `src/emulation.odin`

Implement KEY1, STOP speed switching, independent clocks, and HDMA/GDMA.

### Phase 5: Cartridge completeness

Implement MBC1, MBC3/RTC, MBC5, external RAM, save data, and remaining mapper variants.

### Phase 6: Frontend and tools

Update rendering, VRAM, tilemap, and object viewers for banks, palettes, attributes, and BGR555 colors.

## Difficulty Summary

| Subsystem | Difficulty | Reason |
| --- | --- | --- |
| Mode/header detection | Low-Medium | New persistent metadata and initialization flow |
| WRAM banking | Low-Medium | Straightforward storage and register routing |
| VRAM banking | Medium | CPU and renderer use different bank semantics |
| CGB palette RAM | Medium-High | New state, register side effects, framebuffer changes |
| CGB PPU attributes | High | Renderer and priority redesign |
| Window rendering | High | Missing state and rendering path |
| CPU double speed | High | Requires clock-domain separation |
| HDMA/GDMA | High | Timing-sensitive PPU coupling |
| MBC/RAM/RTC | High | Broad mapper and persistence work |
| Frontend renderer | Medium | Dimensions work, color transport does not |
| Debug viewers | Medium | Direct DMG assumptions |
| Audio/timer reuse | Low-Medium | Timing source must change |
| Serial | Medium | Device is currently absent |

## Main Architectural Risks

1. Keeping `PPU_ScanlineCallback` as `^[160]u8` prevents correct CGB color output.
2. Passing one CPU-derived elapsed-cycle value to every subsystem prevents correct double-speed timing.
3. Treating mapper state as a simple address function prevents external RAM, RTC, battery, and bank-register behavior.
4. Selecting CGB mode only in the frontend would leave core devices with inconsistent hardware state.

The safest route is to establish explicit hardware mode and clock abstractions first, then implement memory banking and the color PPU on top of them.
