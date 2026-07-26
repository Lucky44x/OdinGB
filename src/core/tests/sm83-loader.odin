package tests

import "core:encoding/json"
import "core:fmt"
import "core:os"

TEST_DATA_ROOT :: "./test-data/v1"

load_opcode_cases :: proc(
    opcode_name: string,
    allocator := context.allocator
) -> (
    cases: []SM83_Test_Case,
    ok: bool
) {
    path := fmt.aprintf(
        "%s/%s.json",
        TEST_DATA_ROOT,
        opcode_name,
        allocator = allocator
    )
    defer delete(path, allocator)

    data, f_err := os.read_entire_file_from_path(path, allocator)
    if f_err != nil {
        fmt.eprintf("Could not SM83 Test-File %s: %v\n", path, f_err)
        return nil, false
    }
    defer delete(data, allocator)

    u_err := json.unmarshal(data, &cases, allocator = allocator)
    if u_err != nil {
        fmt.eprintf("Could not parse SM83 Test-File %s: %v\n", path, u_err)
        return nil, false
    }

    return cases, true
}