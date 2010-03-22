CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000


OBJ

  'vgamin : "VGA_Text_Min"
  'tvmin : "TV_Text_Min"
  vgahires : "VGA_HiRes_Text"
  biospasm : "videobiospasmtemp"

VAR
  byte screenbytes[128*64]
  word colours[64]
  byte cursors[6]
  long sync

PUB start | i

  'k := vgamin.start(16)
  'l := tvmin.start(12)
  vgahires.start(16, @screenbytes, @colours, @cursors, @sync)

  repeat i from 0 to 63
    colours[i] := %%0000_3330

  biospasm.start(@screenbytes, @cursors, @cursors+3)

