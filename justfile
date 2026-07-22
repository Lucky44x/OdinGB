# Project paths can be overridden from the command line:
#   just build app_package=./src/main binary_name=my-emulator
#   just test test_package=./src/tests

app_package  := "./src"
test_package := "./src/tests"
binary_name  := "gameboy"

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

# Compile and run the emulator tests.
test:
    mkdir -p "{{test_dir}}"
    odin test "{{test_package}}" \
        -out:"{{test_binary}}" \
        -collection:project=.

# Build and then test.
all: build test

# Remove generated build output.
clean:
    rm -rf ./build
