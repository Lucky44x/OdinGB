package tests

import "core:log"
import "core:fmt"
import "core:mem"
import "core:testing"
import "../cpu"

SM83_STOP_AFTER_FAILURE :: #config(SM83_STOP_AFTER_FAILURE, true)

make_initial_cpu_state :: proc(
    state: ^SM83_State
) -> cpu.CPU {
    result: cpu.CPU

    cpu.write_r8(&result, .A, state.a)
    cpu.write_r8(&result, .B, state.b)
    cpu.write_r8(&result, .C, state.c)
    cpu.write_r8(&result, .D, state.d)
    cpu.write_r8(&result, .E, state.e)
    cpu.write_r8(&result, .F, state.f)
    cpu.write_r8(&result, .H, state.h)
    cpu.write_r8(&result, .L, state.l)

    cpu.write_r16(&result, .SP, state.sp)
    cpu.write_r16(&result, .SP, state.pc)

    //TODO: Add IME and IE flags

    return result
}

make_initial_ram :: proc(
    t: ^testing.T,
    bus: ^Test_Bus,
    entries: []SM83_RAM_Entry,
    case_name: string
) -> bool {
    for entry in entries {
        address := entry[0]
        value := entry[1]

        if !testing.expectf(t, value <= 0xFF, "%s: RAM[%04X] cotnains invalid byte value %d", case_name, address, value) do return false
        bus.memory[int(address)] = u8(value)
    }

    return true
}

expect_registers :: proc(
    t: ^testing.T,
    machine: ^cpu.CPU,
    expected: ^SM83_State,
    case_name: string
) -> bool {
    ok := true

    ok = testing.expectf(
        t, cpu.read_r8(machine, .A) == expected.a, "%s: A expected %02X, got %02X", case_name, expected.a, cpu.read_r8(machine, .A)
    ) && ok

    ok = testing.expectf(
        t, cpu.read_r8(machine, .B) == expected.b, "%s: B expected %02X, got %02X", case_name, expected.b, cpu.read_r8(machine, .B)
    ) && ok

    ok = testing.expectf(
        t, cpu.read_r8(machine, .C) == expected.c, "%s: C expected %02X, got %02X", case_name, expected.c, cpu.read_r8(machine, .C)
    ) && ok

    ok = testing.expectf(
        t, cpu.read_r8(machine, .D) == expected.d, "%s: D expected %02X, got %02X", case_name, expected.d, cpu.read_r8(machine, .D)
    ) && ok

    ok = testing.expectf(
        t, cpu.read_r8(machine, .E) == expected.e, "%s: E expected %02X, got %02X", case_name, expected.e, cpu.read_r8(machine, .E)
    ) && ok

    ok = testing.expectf(
        t, cpu.read_r8(machine, .F) == expected.f, "%s: F expected %02X, got %02X", case_name, expected.f, cpu.read_r8(machine, .F)
    ) && ok

    ok = testing.expectf(
        t, cpu.read_r8(machine, .H) == expected.h, "%s: H expected %02X, got %02X", case_name, expected.h, cpu.read_r8(machine, .H)
    ) && ok

    ok = testing.expectf(
        t, cpu.read_r8(machine, .L) == expected.l, "%s: L expected %02X, got %02X", case_name, expected.l, cpu.read_r8(machine, .L)
    ) && ok

    ok = testing.expectf(
        t, cpu.read_r16(machine, .SP) == expected.sp, "%s: SP expected %04X, got %04X", case_name, expected.sp, cpu.read_r16(machine, .SP)
    ) && ok
    ok = testing.expectf(
        t, cpu.read_r16(machine, .PC) == expected.pc, "%s: PC expected %04X, got %04X", case_name, expected.pc, cpu.read_r16(machine, .PC)
    ) && ok

    //TODO: Add IME and IE flags

    return ok
}

expect_ram :: proc(
    t: ^testing.T,
    bus: ^Test_Bus,
    expected: []SM83_RAM_Entry,
    case_name: string
) -> bool {
    ok := true

    for entry in expected {
        address := entry[0]
        value := entry[1]

        if value > 0xFF {
            testing.expectf(t, false, "%s: Invalid epxected RAM byte at %04X -> %d", case_name, address, value)
            ok = false
            continue
        }

        ok = testing.expectf(
            t, bus.memory[int(address)] == u8(value), "%s: RAM[%04X] expected %02X, got %02X", case_name, address, u8(value), bus.memory[int(address)]
        ) && ok
    }

    return ok
}

run_sm83_case :: proc(
    t: ^testing.T,
    test_case: ^SM83_Test_Case
) -> bool {
    // Re-Create local instances of CPU and RAM state to ensure clean slate for tests
    machine := make_initial_cpu_state(&test_case.initial)
    bus: Test_Bus

    if !make_initial_ram(
        t, &bus, test_case.initial.ram, test_case.name
    ) { return false }

    bus_access := make_test_bus_access(&bus)

    // Execute opcode
    cpu.step(&machine, &bus_access)

    registers_ok := expect_registers(t, &machine, &test_case.final, test_case.name)
    ram_ok := expect_ram(t, &bus, test_case.final.ram, test_case.name)

    return registers_ok && ram_ok
}

run_sm83_opcode_file :: proc(
    t: ^testing.T,
    opcode_name: string
) {
    arena: mem.Dynamic_Arena

    mem.dynamic_arena_init(&arena)
    defer mem.dynamic_arena_destroy(&arena)

    allocator := mem.dynamic_arena_allocator(&arena)

    cases, loaded := load_opcode_cases(opcode_name, allocator)
    if !testing.expectf(t, loaded, "Failed loading %s.json", opcode_name) do return

    log.infof("Testing opcode %s", opcode_name)

    for &test_case in cases {
        case_ok := run_sm83_case(t, &test_case)

        if SM83_STOP_AFTER_FAILURE && !case_ok do return
    }
}