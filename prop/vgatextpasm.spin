CON

  cols = 32
  rows = 15
  rowshift = 5

  screensize = cols * rows
  lastrow = screensize - cols

VAR

  long cog
  long screens1
  long screens2

PUB start(spinscreen1, spinscreen2) : success

  screens1 := spinscreen1
  screens2 := spinscreen2

  stop
  success := cog := cognew(@init, @screens1) + 1

PUB stop

  if cog
    cogstop(cog~ - 1)


DAT

        org

init    rdlong screen1ptr, par
        rdlong screen1, screen1ptr
        mov   x, par
        add   x, #4
        rdlong screen2ptr, x
        rdlong screen2, screen2ptr
        mov   screen, screen1

main    mov   rxreg, #"S"
        call  #switch1
        call  #print
        call  #switch2
        call  #print

        mov   rxreg, #"c"
        call  #switch1
        call  #print
        call  #switch2
        call  #print

        mov   rxreg, #"r"
        call  #switch1
        call  #print
        call  #switch2
        call  #print

        mov   rxreg, #"e"
        call  #switch1
        call  #print
        call  #switch2
        call  #print

        mov   rxreg, #"e"
        call  #switch1
        call  #print
        call  #switch2
        call  #print

        mov   rxreg, #"n"
        call  #switch1
        call  #print
        call  #switch2
        call  #print

        mov   rxreg, #" "
        call  #switch1
        call  #print
        call  #switch2
        call  #print

        mov   rxreg, #"1"
        call  #switch1
        call  #print
        add   rxreg, #1
        call  #switch2
        call  #print

loop    djnz  bignum, #loop
        ' here's a clever trick
        wrlong screen2, screen1ptr
        wrlong screen1, screen2ptr
idle    jmp   #idle

switch1 test  flags, screen2_flag               wz
if_z    jmp   #switch1_ret
        mov   screen, screen1
        mov   col2, col
        mov   col, col1
        mov   row2, row
        mov   row, row1
        mov   colour, colour1
        andn  flags, screen2_flag
switch1_ret   ret

switch2 test  flags, screen2_flag               wz
if_nz   jmp   #switch2_ret
        mov   screen, screen2
        mov   col1, col
        mov   col, col2
        mov   row1, row
        mov   row, row2
        mov   colour, colour2
        or    flags, screen2_flag
switch2_ret   ret
''
''      Print - prints a character, handles character codes no understanding
''              of special ascii characters (newline etc.)
''
print   mov   char, colour
        shl   char, #2
        test  rxreg, #1         wz
if_nz   or    char, #2
        or    char, #1
        shl   char, #$9
        add   char, rxreg
        andn  char, #$1

        mov   hubad, row
        shl   hubad, #rowshift
        add   hubad, col
        shl   hubad, #1         'word aligned.
        add   hubad, screen

        wrword char, hubad

        add   col,#1
        test  col, #$20         wz
if_nz   call  #newline

print_ret     ret


''
''      Newline - moves the cursor to the start of a new line
''                if at the bottom of the screen it wraps or scrolls
''                depending on the state of the wrap/scroll setting
''
newline
        mov   col, #0
        add   row, #1
        xor   row, #$F          nr, wz
if_nz   jmp   #newline_ret
        ' here we need to scroll or wrap the display
        test  flags, auto_scroll_flag           wz
if_z    jmp   #wrap_vert        ' wrap, don't scroll
        ' scroll is set, need to scroll the whole screen up
        mov   x, #224           ' need to shift 14 rows up each row is 16 longs
        mov   hubad, #32        ' start at the begining of line 2
        shl   hubad, #1         ' word aligned
        add   hubad, screen     ' move into screen buffer

scroll_loop
        rdlong y, hubad         ' read two characters
        sub   hubad, #64        ' jump back one line of words
        wrlong y, hubad         ' write them back
        add   hubad, #68        ' jump forward one line and two characters
        djnz  x, #scroll_loop

        ' now need to write the last row, and pointing at first long AFTER the buffer
        sub   hubad, #64
        mov   x, #16            ' now fill the last row with zeros

space_loop
        wrlong doublespace, hubad
        add   hubad, #4
        djnz  x, #space_loop

        mov   row, #14         ' set row back to the last line
        jmp   #newline_ret

wrap_vert
        mov   row, #0

newline_ret     ret



row     long  0
col     long  0
colour  long  0
row1    long  0
row2    long  0
col1    long  0
col2    long  0
colour1 long  0
colour2 long  0
flags   long  1

auto_scroll_flag long %0000_0001
screen2_flag  long %0000_0010

bignum  long 200_000_000
doublespace  long      $02200220
screen1ptr    res       1
screen2ptr    res       1
screen  res   1
screen1 res   1
screen2 res   1
rxreg   res   1
hubad   res   1
char    res   1
y       res   1
x       res   1
a       res   1
b       res   1
c       res   1
