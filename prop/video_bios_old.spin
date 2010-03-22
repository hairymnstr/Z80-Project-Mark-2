CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000


OBJ

  vgatext : "VGA_Text_ND"
  tvtext : "TV_Text_ND"
  hostbus : "z80bus"

VAR

  long  fifo_base
  long  cursor

  ' buffer for commands
  word  fifo[128]


PUB start | k


  tvtext.start(12)
  vgatext.start(16)

  fifo_base := @fifo
  cursor := $00000000
  hostbus.start(@fifo_base)

  vgatext.out($0C)
  vgatext.out($04)
  vgatext.out($20)
  vgatext.cprint(@logo1 >> 6)
  vgatext.cprint(@logo1 >> 6)
  vgatext.cprint(@logo1 >> 6)
  vgatext.cprint(@logo1 >> 6)
  vgatext.cprint(@logo1 >> 6)
  vgatext.out($0D)
  vgatext.out($20)
  vgatext.out($20)
  vgatext.cprint((@logo1 >> 6) + 1)
  vgatext.cprint(@logo2 >> 6)
  vgatext.cprint((@logo2 >> 6) + 1)
  vgatext.cprint(@logo3 >> 6)
  vgatext.out($0D)
  vgatext.out($20)
  vgatext.cprint((@logo3 >> 6) + 1)
  vgatext.cprint(@logo4 >> 6)
  vgatext.cprint((@logo4 >> 6) + 1)
  vgatext.cprint(@logo1 >> 6)
  vgatext.cprint(@logo1 >> 6)
  vgatext.out($0C)
  vgatext.out($00)
  vgatext.str(string(13," ZiLOG"))
  tvtext.out($0C)
  tvtext.out($04)
  tvtext.out($20)
  tvtext.cprint(@logo1 >> 6)
  tvtext.cprint(@logo1 >> 6)
  tvtext.cprint(@logo1 >> 6)
  tvtext.cprint(@logo1 >> 6)
  tvtext.cprint(@logo1 >> 6)
  tvtext.out($0D)
  tvtext.out($20)
  tvtext.out($20)
  tvtext.cprint((@logo1 >> 6) + 1)
  tvtext.cprint(@logo2 >> 6)
  tvtext.cprint((@logo2 >> 6) + 1)
  tvtext.cprint(@logo3 >> 6)
  tvtext.out($0D)
  tvtext.out($20)
  tvtext.cprint((@logo3 >> 6) + 1)
  tvtext.cprint(@logo4 >> 6)
  tvtext.cprint((@logo4 >> 6) + 1)
  tvtext.cprint(@logo1 >> 6)
  tvtext.cprint(@logo1 >> 6)
  tvtext.out($0C)
  tvtext.out($00)
  tvtext.str(string(13," ZiLOG"))
  k := 0
  repeat
    if fifo[k] & $8000
      ' there's some new data
      if fifo[k] & $4000
        ' it's a command
        command(fifo[k] & $ff)
        ' clear the new flags
        fifo[k] := 0
      elseif fifo[k] & $2000
        ' it's a byte of data
        out(fifo[k])
        out(fifo[k])
        fifo[k] := 0
      k++
      if k == 128
        k := 0


PUB out(c)
'' A wrapper to deal with printing a character depending on which monitor(s) are
'' currently selected.
''
'' Modes Currently Defined:
''   $00: Both displays (default)
''   $01: VGA monitor only
''   $02: TV display only

  case screen_mode
    $00:  tvtext.out(c)
          vgatext.out(c)
          cursor := vgatext.getrow() << 16 + vgatext.getcol() << 8 + vgatext.getchr()
    $01:  vgatext.out(c)
          cursor := vgatext.getrow() << 16 + vgatext.getcol() << 8 + vgatext.getchr()
    $02:  tvtext.out(c)
          cursor := tvtext.getrow() << 16 + tvtext.getcol() << 8 + tvtext.getcol()


PUB command(c)
'' Handler routine to deal with commands sent to the command port
''
'' Command codes currently defined:
''   $

  case c
    $00:  out(c)                                        ' clear active screen(s)
    $FC..$FF: set_screen_mode(c & $03)                  ' select active screen(s)

PUB set_screen_mode(c)
'' Sets the screen mode including updating the cursor variable
  case c
    $00:  screen_mode := $00
          cursor := vgatext.getrow() << 16 + vgatext.getcol() << 8 + vgatext.getchr()
    $01:  screen_mode := $01
          cursor := vgatext.getrow() << 16 + vgatext.getcol() << 8 + vgatext.getchr()
    $02:  screen_mode := $02
          cursor := tvtext.getrow() << 16 + tvtext.getcol() << 8 + tvtext.getchr()

DAT
        s0 long 0
        s1 long 0
        s2 long 0
        s3 long 0
        s4 long 0
        s5 long 0
        s6 long 0
        s7 long 0, 0, 0, 0, 0, 0, 0, 0
        s8 long 0, 0, 0, 0, 0, 0, 0, 0
logo1   long
long    $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
long    $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
long    $D5555555,$F5555555,$FD555555,$FF555555,$FFD55555,$FFF55555,$FFFD5555,$FFFF5555
long    $FFFFD555,$FFFFF555,$FFFFFD55,$FFFFFF55,$FFFFFFD5,$FFFFFFF5,$FFFFFFFD,$FFFFFFFF
logo2   long
long    $EAAAAAAA,$FAAAAAAA,$FEAAAAAA,$FFAAAAAA,$FFEAAAAA,$FFFAAAAA,$FFFEAAAA,$FFFFAAAA
long    $FFFFEAAA,$FFFFFAAA,$FFFFFEAA,$FFFFFFAA,$FFFFFFEA,$FFFFFFFA,$FFFFFFFE,$FFFFFFFF
long    $7FFFFFFF,$5FFFFFFF,$57FFFFFF,$55FFFFFF,$557FFFFF,$555FFFFF,$5557FFFF,$5555FFFF
long    $55557FFF,$55555FFF,$555557FF,$555555FF,$5555557F,$5555555F,$55555557,$55555555
logo3   long
long    $95555555,$A5555555,$A9555555,$AA555555,$AA955555,$AAA55555,$AAA95555,$AAAA5555
long    $AAAA9555,$AAAAA555,$AAAAA955,$AAAAAA55,$AAAAAA95,$AAAAAAA5,$AAAAAAA9,$AAAAAAAA
long    $AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA
long    $AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA
logo4   long
long    $7FFFFFFF,$5FFFFFFF,$57FFFFFF,$55FFFFFF,$557FFFFF,$555FFFFF,$5557FFFF,$5555FFFF
long    $55557FFF,$55555FFF,$555557FF,$555555FF,$5555557F,$5555555F,$55555557,$55555555
long    $FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
long    $FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
