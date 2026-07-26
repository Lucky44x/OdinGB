app_package  := "./src"
test_package := "./src/core/tests"
binary_name  := "gameboy"

release_dir := "./build/release"
test_dir    := "./build/test"

release_binary := release_dir / (binary_name + ".exe")
test_binary    := test_dir / (binary_name + "-tests.exe")

default:
    @just --list

build debug="false":
    mkdir -p "{{release_dir}}"

    if [ {{debug}} = "true" ]; then \
    odin build "{{app_package}}" \
            -out:"{{release_binary}}" \
            -o:speed \
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
    ./{{release_binary}} -bios-file:"./roms/dmg_boot.bin"

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
