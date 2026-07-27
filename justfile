app_package  := "./src"
test_package := "./src/core/tests"
binary_name  := "gameboy"

release_dir := "./build/release"
debug_dir := "./build/debug"
test_dir    := "./build/test"

release_binary := release_dir / (binary_name + ".exe")
test_binary    := test_dir / (binary_name + "-tests.exe")
debug_binary := debug_dir / (binary_name + "-dbg.exe")

default:
    @just --list

build debug="false":
    if [ {{debug}} = "true" ]; then \
    mkdir -p "{{debug_dir}}"; \
    else \
    mkdir -p "{{release_dir}}"; \
    fi

    if [ {{debug}} = "true" ]; then \
    odin build "{{app_package}}" \
            -out:"{{debug_binary}}" \
            -extra-linker-flags:"/FORCE:MULTIPLE" \
            -debug; \
    else \
        odin build "{{app_package}}" \
            -out:"{{release_binary}}" \
            -o:speed \
            -extra-linker-flags:"/FORCE:MULTIPLE"; \
    fi

run debug="false":
    @just build {{debug}}

    if [ {{debug}} = "false" ]; then \
        ./{{release_binary}} -bios-file:"./roms/dmg_boot.bin" \
    else \
        ./{{debug_binary}} -bios-file:"./roms/dmg_boot.bin" \
    fi

test name="" debug="false":
    mkdir -p "{{test_dir}}"
    if [ -n "{{name}}" ]; then \
        odin test "{{test_package}}" \
            -out:"{{test_binary}}" \
            -collection:project=. \
            -define:ODIN_TEST_NAMES="sm83_opcode_{{name}}" \
            -define:DEBUG_MEMORY_ACCESS={{debug}}; \
    else \
        odin test "{{test_package}}" \
            -out:"{{test_binary}}" \
            -collection:project=. \
            -define:DEBUG_MEMORY_ACCESS={{debug}}; \
    fi

test-opcode opcode prefix="":
    if [ "{{prefix}}" = "cb" ]; then \
        just test test_name="sm83_opcode_cb_{{lowercase(opcode)}}"; \
    else \
        just test test_name="sm83_opcode_{{lowercase(opcode)}}"; \
    fi

all: build test

clean:
    rm -rf ./build
