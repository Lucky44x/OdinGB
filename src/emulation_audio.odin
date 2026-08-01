package main

import "core"
import rl "vendor:raylib"

SAMPLE_RATE :: 48000
AUDIO_UPDATE_FRAMES :: 1024

audio_output: rl.AudioStream

emulation_init_audio :: proc() {
    rl.InitAudioDevice()
    rl.SetAudioStreamBufferSizeDefault(AUDIO_UPDATE_FRAMES)

    audio_output = rl.LoadAudioStream(
        SAMPLE_RATE,
        16,
        2
    )

    rl.PlayAudioStream(audio_output)
}

emulation_audio_reset :: proc() {
}

emulation_audio_render :: proc() {
    if !rl.IsAudioStreamProcessed(audio_output) do return

    available := core.audio_available(&emulator_core)
    if available < AUDIO_UPDATE_FRAMES do return

    samples: [AUDIO_UPDATE_FRAMES * 2]i16
    core.audio_render(
        &emulator_core,
        AUDIO_UPDATE_FRAMES,
        samples[:]
    )

    rl.UpdateAudioStream(
        audio_output,
        raw_data(&samples),
        AUDIO_UPDATE_FRAMES
    )

}
