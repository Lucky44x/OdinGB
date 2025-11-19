#+private
package sound

/*
    Steps the sequencer: run at 512Hz
*/
sequencer_step :: proc(
    self: ^APU
) {
    self.frame_step = (self.frame_step + 1) & 7
    
    if self.frame_step & 1 == 0 do channels_step(self)
    if self.frame_step == 2 || self.frame_step == 6 do channels_sweep(self)
}