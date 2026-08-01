# Core Optimization Roadmap

This document records the memory-efficiency audit for the Game Boy core and the work needed to make it suitable for a Raspberry Pi Pico-class target.

## Current Hardware Memory

The core's required Game Boy memory is already close to the hardware minimum:

| Area | Size |
| --- | ---: |
| WRAM | 8 KiB |
| VRAM | 8 KiB |
| OAM | 160 bytes |
| HRAM | 127 bytes |
| I/O registers | 128 bytes |

These areas should not be reduced because they represent required DMG state.

## Highest-Priority Work

### Cartridge Storage

`ROM_Bulk` currently keeps the entire cartridge ROM in RAM. This is the largest Pico blocker.

The embedded core should instead read cartridge data through a backend callback, allowing ROM to remain in flash or external storage. If a cache is required, it should use a small fixed-size cache supplied by the caller.

The current buffered-ROM path also needs correction:

- `cartridge_load_buffered` initializes the cache with `max_banks = 0`.
- The cache can then return slot `-1` and index invalid memory.
- The cache metadata uses dynamically allocated slices.

### Audio Buffer

`AUDIO_BUFFER_CAPACITY = 4096` stores 8 KiB of `i16` samples. This is reasonable for the desktop frontend but unnecessarily large for an embedded build.

Make the capacity configurable:

- Desktop default: 2,048 or 4,096 samples.
- Embedded default: 512 or 1,024 samples.

An alternative is to expose audio samples through a callback and remove the core-owned ring buffer entirely.

### Dynamic I/O Maps

The I/O implementation uses runtime maps for:

- Read fallbacks
- Write fallbacks
- Read masks
- Write masks
- Read bit-OR values

These maps add allocator, hash-table, and runtime initialization overhead for a fixed 128-byte address range. Replace them with static arrays or switch statements. The CPU interrupt vector map should receive the same treatment.

## CPU State and Debug Data

The two 256-entry instruction tables contain handler pointers, names, lengths, and override flags. The following fields are primarily debug or initialization data:

- Instruction names
- Override flags after table construction
- Formatted duplicate-registration errors

Release builds should use compact instruction metadata containing only the handler and required execution information. Instruction names and duplicate-registration diagnostics should be debug-only.

The CPU also stores:

- A pointer to the last instruction
- A 16-byte instruction history buffer
- The last instruction length

These fields are useful to the desktop debugger but can be omitted from an embedded release build.

## Allocation and Runtime Dependencies

The embedded core should avoid or isolate:

- `core:os`
- `core:log`
- `core:fmt`
- `core:strings`
- Runtime-created maps
- Unnecessary `make` and `delete` calls

Use caller-provided storage or static storage for cartridge caches, external RAM, and optional audio buffers. Keep file loading, logging, formatting, and UI code in the desktop frontend.

The cartridge ownership contract also needs to be made explicit. `ROM_Bulk` currently stores a borrowed slice, while `cartridge_unload` deletes it. That can cause invalid frees or double frees when the caller owns the ROM data.

## Integer Types

Several core structures use platform-sized `int` values for indexes, timers, and counters. Prefer fixed-width types where the values have known limits:

- `u8` for hardware-sized registers and small indexes
- `u16` for Game Boy addresses and timers
- `u32` for counters and sizes where needed

The APU currently uses `u64` for its sample accumulator and dropped-sample count. These can likely become `u32` with wrap-safe arithmetic, reducing state size and execution cost on RP2040.

## Small or Optional Improvements

- Move the global 160-byte scanline buffer into `PPU` to support multiple core instances safely.
- Consider storing the ten temporary sprite entries inside PPU state if stack usage matters.
- Validate audio output slice length before writing stereo samples.
- Validate cartridge input size before reading the header.
- Implement or explicitly disable external cartridge RAM instead of routing `0xA000-0xBFFF` through ROM reads.
- Remove unused imports and desktop-only diagnostics from core packages.

These changes are less important than cartridge storage and dynamic map removal.

## Approximate Memory Priorities

The largest avoidable allocations are:

1. Complete cartridge ROM in RAM: potentially tens or hundreds of KiB.
2. Audio ring buffer: 8 KiB at the current capacity.
3. Instruction tables: several KiB, depending on target pointer and string sizes.
4. Runtime maps: implementation-dependent heap and metadata overhead.
5. Dynamic cartridge cache metadata and bank storage.

The fixed Game Boy memory areas total approximately 16.5 KiB before CPU, PPU, APU, and cartridge state. With the cartridge kept in flash and debug/frontend state removed, the core should fit comfortably within Pico-class SRAM.

## Recommended Implementation Order

1. Add a release/embedded core configuration with logging and debugger metadata disabled.
2. Replace full-ROM ownership with a read-only cartridge backend suitable for flash or external storage.
3. Fix buffered-ROM initialization and make its cache caller-owned and statically sized.
4. Make the audio buffer capacity configurable and reduce the embedded default.
5. Replace runtime I/O and interrupt maps with static tables or switches.
6. Compact instruction-table entries and remove release-only names and flags.
7. Replace unnecessary `u64` and `int` state with fixed-width integers.
8. Fix ownership, bounds checks, audio output validation, and external RAM behavior.
9. Add a memory-budget test that reports `sizeof(GB_Core)` and all cartridge/audio allocations for each build profile.

## Target Architecture

The preferred architecture is:

- Core owns only emulation state.
- Frontend owns files, logging, rendering, and audio device buffers.
- Cartridge reads are supplied by a backend callback.
- Optional audio uses a caller-provided buffer or callback.
- Debug metadata is excluded from release builds.
- All large storage is statically allocated or supplied by the platform.

This keeps the desktop frontend flexible while allowing the same emulation core to run with Pico flash-backed cartridges and fixed SRAM budgets.
