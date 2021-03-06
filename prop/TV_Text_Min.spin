''***************************************
''*  TV Text 40x13 v1.0                 *
''*  Author: Chip Gracey                *
''*  Copyright (c) 2006 Parallax, Inc.  *
''*  See end of file for terms of use.  *
''***************************************

CON

  cols = 32
  rows = 15

  screensize = cols * rows
  lastrow = screensize - cols

  tv_count = 14


VAR

  long  col, row, color, flag

  word  screen[screensize]
  long  colors[8 * 2]

  long  tv_status     '0/1/2 = off/invisible/visible              read-only   (14 longs)
  long  tv_enable     '0/non-0 = off/on                           write-only
  long  tv_pins       '%pppmmmm = pin group, pin group mode       write-only
  long  tv_mode       '%tccip = tile,chroma,interlace,ntsc/pal    write-only
  long  tv_screen     'pointer to screen (words)                  write-only
  long  tv_colors     'pointer to colors (longs)                  write-only
  long  tv_ht         'horizontal tiles                           write-only
  long  tv_vt         'vertical tiles                             write-only
  long  tv_hx         'horizontal tile expansion                  write-only
  long  tv_vx         'vertical tile expansion                    write-only
  long  tv_ho         'horizontal offset                          write-only
  long  tv_vo         'vertical offset                            write-only
  long  tv_broadcast  'broadcast frequency (Hz)                   write-only
  long  tv_auralcog   'aural fm cog                               write-only


OBJ

  tv : "tv"


PUB start(basepin) : okay

'' Start terminal - starts a cog
'' returns false if no cog available

  wordfill(@screen, $220, screensize)
  setcolors(@palette)

  longmove(@tv_status, @tv_params, tv_count)
  tv_pins := (basepin & $38) << 1 | (basepin & 4 == 4) & %0101
  tv_screen := @screen
  tv_colors := @colors

  tv.start(@tv_status)

  okay := @tv_screen

PUB stop

'' Stop terminal - frees a cog

  tv.stop

PUB setcolors(colorptr) | i, fore, back

'' Override default color palette
'' colorptr must point to a list of up to 8 colors
'' arranged as follows:
''
''               fore   back
''               ------------
'' palette  byte color, color     'color 0
''          byte color, color     'color 1
''          byte color, color     'color 2
''          ...

  repeat i from 0 to 7
    fore := byte[colorptr][i << 1]
    back := byte[colorptr][i << 1 + 1]
    colors[i << 1]     := fore << 24 + back << 16 + fore << 8 + back
    colors[i << 1 + 1] := fore << 24 + fore << 16 + back << 8 + back

DAT

tv_params               long    0               'status
                        long    1               'enable
                        long    0               'pins
                        long    %10011          'mode  (PAL!!)
                        long    0               'screen
                        long    0               'colors
                        long    cols            'hc
                        long    rows            'vc
                        long    4               'hx
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    0               'broadcast
                        long    0               'auralcog


                        '       fore   back
                        '       color  color
palette                 byte    $07,   $02    '0    white / black
                        byte    $AE,   $02    '1      red / black
                        byte    $7E,   $02    '2    green / black
                        byte    $1E,   $02    '3     blue / black
                        byte    $9E,   $02    '4   yellow / black
                        byte    $FE,   $02    '5  magenta / black
                        byte    $3E,   $02    '6     cyan / black
                        byte    $02,   $07    '7    black / white

{{

┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}
