''***************************************
''*  VGA Text 32x15 v1.0                *
''*  Author: Chip Gracey                *
''*  Copyright (c) 2006 Parallax, Inc.  *
''*  See end of file for terms of use.  *
''***************************************

CON

  cols = 32
  rows = 15

  screensize = cols * rows
  lastrow = screensize - cols

  vga_count = 22

  
VAR

  long  col, row, color, flag

  word  screen[screensize]
  long  colors[8 * 2]

  long  vga_status    '0/1/2 = off/visible/invisible      read-only   (21 longs)
  long  vga_enable    '0/non-0 = off/on                   write-only
  long  vga_pins      '%pppttt = pins                     write-only
  long  vga_mode      '%tihv = tile,interlace,hpol,vpol   write-only
  long  vga_screen    'pointer to screen (words)          write-only
  long  vga_colors    'pointer to colors (longs)          write-only            
  long  vga_ht        'horizontal tiles                   write-only
  long  vga_vt        'vertical tiles                     write-only
  long  vga_hx        'horizontal tile expansion          write-only
  long  vga_vx        'vertical tile expansion            write-only
  long  vga_ho        'horizontal offset                  write-only
  long  vga_vo        'vertical offset                    write-only
  long  vga_hd        'horizontal display ticks           write-only
  long  vga_hf        'horizontal front porch ticks       write-only
  long  vga_hs        'horizontal sync ticks              write-only
  long  vga_hb        'horizontal back porch ticks        write-only
  long  vga_vd        'vertical display lines             write-only
  long  vga_vf        'vertical front porch lines         write-only
  long  vga_vs        'vertical sync lines                write-only
  long  vga_vb        'vertical back porch lines          write-only
  long  vga_rate      'tick rate (Hz)                     write-only
  long  cursor


OBJ

  vga : "vgac"


PUB start(basepin) : okay

'' Start terminal - starts a cog
'' returns false if no cog available
''
'' requires at least 80MHz system clock

  wordfill(@screen, $220, screensize)
  setcolors(@palette)

  longmove(@vga_status, @vga_params, vga_count)
  vga_pins := basepin | %000_111
  vga_screen := @screen
  vga_colors := @colors
  vga_rate := clkfreq >> 2
  
  vga.start(@vga_status)

  okay := @vga_screen

PUB stop

'' Stop terminal - frees a cog

  vga.stop


PUB setcolors(colorptr) | i, fore, back

'' Override default color palette
'' colorptr must point to a list of up to 8 colors
'' arranged as follows (where r, g, b are 0..3):
''
''               fore   back
''               ------------
'' palette  byte %%rgb, %%rgb     'color 0
''          byte %%rgb, %%rgb     'color 1
''          byte %%rgb, %%rgb     'color 2
''          ...

  repeat i from 0 to 7
    fore := byte[colorptr][i << 1] << 2
    back := byte[colorptr][i << 1 + 1] << 2
    colors[i << 1]     := fore << 24 + back << 16 + fore << 8 + back
    colors[i << 1 + 1] := fore << 24 + fore << 16 + back << 8 + back

DAT

vga_params              long    0               'status
                        long    1               'enable
                        long    0               'pins
                        long    %1000           'mode
                        long    0               'videobase
                        long    0               'colorbase
                        long    cols            'hc
                        long    rows            'vc
                        long    1               'hx
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    512             'hd
                        long    10              'hf
                        long    75              'hs
                        long    43              'hb
                        long    480             'vd
                        long    11              'vf
                        long    2               'vs
                        long    31              'vb
                        long    0               'rate
                        long    0               'cursor

                        '        fore   back
                        '         RGB    RGB
palette                 byte    %%333, %%000    '0    white / black
                        byte    %%300, %%000    '1      red / black
                        byte    %%030, %%000    '2    green / black
                        byte    %%003, %%000    '3     blue / black
                        byte    %%330, %%000    '4   yellow / black
                        byte    %%303, %%000    '5  magenta / black
                        byte    %%033, %%000    '6     cyan / black
                        byte    %%000, %%333    '7    black / white

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
