# Project paths can be overridden from the command line:
#   just build app_package=./src/main binary_name=my-emulator
#   just test test_package=./src/tests
#   just test test_name=sm83_opcode_40

app_package  := "./src"
test_package := "./src/tests"
binary_name  := "gameboy"
test_name    := "sm83_opcode_43"

release_dir := "./build/release"
test_dir    := "./build/test"

release_binary := release_dir / (binary_name + ".exe")
test_binary    := test_dir / (binary_name + "-tests.exe")

# Show available recipes when `just` is run without arguments.
default:
    @just --list

# Build an optimized emulator executable.
build:
    mkdir -p "{{release_dir}}"
    odin build "{{app_package}}" \
        -out:"{{release_binary}}" \
        -o:speed

# Compile and run tests. Optionally select one or more comma-separated test names:
#   just test test_name=sm83_opcode_40
#   just test test_name=sm83_opcode_40,sm83_opcode_41
#   just test test_name=sm83_opcode_cb_40
test:
    mkdir -p "{{test_dir}}"
    if [ -n "{{test_name}}" ]; then \
        odin test "{{test_package}}" \
            -out:"{{test_binary}}" \
            -collection:project=. \
            -define:ODIN_TEST_NAMES="{{test_name}}"; \
    else \
        odin test "{{test_package}}" \
            -out:"{{test_binary}}" \
            -collection:project=.; \
    fi

# Run one unprefixed opcode test by hexadecimal opcode:
#   just test-opcode 40
#
# Run one CB-prefixed opcode test:
#   just test-opcode 40 cb
test-opcode opcode prefix="":
    if [ "{{prefix}}" = "cb" ]; then \
        just test test_name="sm83_opcode_cb_{{lowercase(opcode)}}"; \
    else \
        just test test_name="sm83_opcode_{{lowercase(opcode)}}"; \
    fi

# Build and then test.
all: build test

# Remove generated build output.
clean:
    rm -rf ./build
