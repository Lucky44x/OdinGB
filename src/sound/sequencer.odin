#+private
package sound

sequencer_step :: proc(
    self: ^APU
) {
    self.frame_step = (self.frame_step + 1) & 7
    
}