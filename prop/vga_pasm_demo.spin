''
''  PASM Text demo
''
CON

  cols = 32
  rows = 15

  screensize = cols * rows
  lastrow = screensize - cols

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

OBJ

  vgatextmin : "vga_text_min"
  pasmtext : "vgatextpasm"
  tvtextmin : "TV_Text_Min"

PUB start | j, k, l

  k := vgatextmin.start(16)
  l := tvtextmin.start(12)
  j := pasmtext.start(k, l)

'  tvtext.start(12)

'  tvtext.hex(j,8)
'  tvtext.out(13)
'  tvtext.hex(k,8)
'  tvtext.out(13)
'  tvtext.hex(@screen,4)

