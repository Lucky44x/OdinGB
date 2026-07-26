package main

import "core:fmt"
import win32 "core:sys/windows"

notify :: proc(
    title: string,
    msg: string,
    args: ..any
) {
    when ODIN_OS == .Windows do _notify_windows(title, msg, args)
}

@(private)
_notify_windows :: proc(
    title: string,
    msg: string,
    args: ..any
) {
    message := fmt.tprintf(msg, args)

    title_w := win32.utf8_to_wstring(title)
    msg_w := win32.utf8_to_wstring(message)

    response := win32.MessageBoxW(
        hWnd = nil,
        lpText = msg_w,
        lpCaption = title_w,
        uType = win32.MB_OK | win32.MB_ICONERROR
    )
}