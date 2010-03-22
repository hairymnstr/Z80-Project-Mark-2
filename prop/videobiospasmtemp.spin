CON

  cols = 128
  rows = 64
  rowshift = 7

  'screensize = cols * rows
  'lastrow = screensize - cols

VAR

  long cog
  long screenvar
  long cursor1var
  long cursor2var

PUB start(spinscreen1, cursor1, cursor2) : success

  screenvar := spinscreen1
  cursor1var := cursor1
  cursor2var := cursor2

  stop
  success := cog := cognew(@init, @screenvar) + 1

PUB stop

  if cog
    cogstop(cog~ - 1)


DAT

        org

init
        ' screen setup stuff
        'rdlong vgaptr, par
        'rdlong screen1, vgaptr
        'mov   x, par
        'add   x, #4
        'rdlong tvptr, x
        'rdlong screen2, tvptr

        'add   x, #4
        'rdlong screen3, x
        'add   x, #4
        'rdlong screen4, x

        mov   x, par
        rdlong          screen, x
        add             x, #4
        rdlong          cur1, x
        add             x, #4
        rdlong          cur2, x

        ' IO setup stuff
        mov   dira, start_dirs
        mov   outa, start_levels

        'mov   screen, screen1

        call  #reset

        andn  outa, int_pin     ' we're ready to work so set the ready flag

        jmp   #main

''
''      Reset - called by the Z80 to initialize on boot
''              also runs when the prop starts and can be called later
''
reset
        'mov   active_screen, #$10
        'call  #set_active
        call  #cls
        'mov   colour, #0
        'add   active_screen, #$20
        'call  #set_active
        'call  #cls
        'mov   colour, #0
        'add   active_screen, #$30
        'call  #set_active
        'call  #cls
        'mov   colour, #0
        'call  #set_active
        'call  #cls
        'mov   colour, #0

        'wrlong screen1, vgaptr
        'wrlong screen1, tvptr   ' start with the two displays on logical screen1
reset_ret     ret


''
''      Main loop - checks for a new read/write event
''
main    waitpne         trigger_mask, trigger_mask
        ' one of the select pins is not 1
        ' set wait high (enables the pull down transistor
        or              outa, wait_pin

        ' now decide which pin triggered the event
        test            wr_command_pin, ina     wz
if_z    jmp             #wr_command
        test            wr_data_pin, ina        wz
if_z    jmp             #wr_data
        test            rd_command_pin, ina     wz
if_z    jmp             #rd_command
        test            rd_data_pin, ina        wz
if_z    jmp             #rd_data

        ' something went wrong, a power on glitch or something
        ' make sure wait is low and go back to main
        andn            outa, wait_pin
        jmp             #main

''
''      wr_data - Z80 is writing data into the display buffer
''
wr_data
        ' the Z80 is writing a data byte
        or              outa, dir_pin           ' set buffer direction in
        andn            outa, buffer_enable_pin ' enable the buffer
        nop                                     ' make sure the levels settle
        ' read the value
        mov             rxreg, ina              ' read the byte
        and             rxreg, #$ff             ' mask it off
        ' make sure it wasn't a special character value
        ' for now that's anything below 16
        testn           rxreg, #$f              wz
if_z    jmp             #special_chars
        ' it wasn't so just print it to the active monitor and release the bus
        call            #print

        andn            outa, wait_pin          ' disable the wait signal
        or              outa, buffer_enable_pin ' turn off the buffer
        waitpeq         wr_data_pin, wr_data_pin ' make sure the Z80 has ended the write
        jmp             #main

special_chars
        xor             rxreg, #$A              nr,wz
if_z    call            #newline
        xor             rxreg, #$D              nr,wz
if_z    call            #newline
        xor             rxreg, #$8              nr,wz           ' backspace
if_z    call            #backspace
        xor             rxreg, #$9              nr,wz
if_z    call            #tab

special_chars_exit
        andn            outa, wait_pin
        or              outa, buffer_enable_pin
        waitpeq         wr_data_pin, wr_data_pin
        jmp             #main

''
''      wr_command - receive a command written by the Z80
''
wr_command
        ' the Z80 is writing a command to us so we need to read
        ' set the buffer to inwards
        or              outa, dir_pin
        ' set the buffer to drive
        andn            outa, buffer_enable_pin
        nop
        ' read the value
        mov             rxreg, ina
        and             rxreg, #$ff
        mov             x, rxreg                ' default to reading the new byte
        test            command_flags, #$ff     wz
if_nz   mov             x, command_flags        ' buf if there's a flag jump based on that
        ' mask top 4 bits
        and             x, #$f0
        shr             x, #4
        ' decide what the command is
        add             x, #command_table   ' turn it into a jump
        movs            wr_command_jump, x
        nop
wr_command_jump
        jmp             #command_table

wr_command_exit
        ' clear the wait line
        andn            outa, wait_pin
        ' stop the buffer driving
        or              outa, buffer_enable_pin

        waitpeq         wr_command_pin, wr_command_pin
        ' return to main
        jmp             #main


command_table
        jmp             #reset_command
        jmp             #cls_command
        jmp             #colour_command
        jmp             #column_command
        jmp             #row_command
        jmp             #assign_command
        jmp             #select_command

reset_command
        call            #reset
        jmp             #wr_command_exit

cls_command
        call            #cls
        jmp             #wr_command_exit

colour_command
        ' if bit 4 is 1 then set the colour, otherwise load the colour reg
        test            rxreg, #$08             wz
if_z    jmp             #colour_command_read
        ' bit 4 is set.  We need to set the colour based on the lowest 3 bits of the command
        and             rxreg, #$7
        mov             colour, rxreg
        jmp             #wr_command_exit

colour_command_read
        ' need to set txreg to the current colour
        mov             txreg, colour
        jmp             #wr_command_exit

column_command
        test            command_flags, #$ff     wz
if_nz   jmp             #set_column_command
        ' test read/write bit
        test            rxreg, #$08     wz
if_z    jmp             #read_column_command
        jmp             #set_flag
set_column_command
        ' if the flag isn't zero that's because we need to save rxreg as the new column
        ' rxreg has already been masked to the least significant 8 bits
        mov             col, rxreg              ' just copy the column into col
        mov             command_flags, #0       ' clear the flag
        jmp             #wr_command_exit
read_column_command
        mov             txreg, col              ' set the txreg
        jmp             #wr_command_exit

row_command
        test            command_flags, #$ff     wz
if_nz   jmp             #set_row_command
        ' if the flag is zero, either this is a set flag or get data instruction
        test            rxreg, #$08             wz
if_z    jmp             #read_row_command
        jmp             #set_flag               ' not read, so set flag
set_row_command
        ' if the flag isn't zero that's because we need to save rxreg as the new row
        mov             row, rxreg
        mov             command_flags, #0
        jmp             #wr_command_exit
read_row_command
        mov             txreg, col
        jmp             #wr_command_exit

assign_command
'        test            rxreg, #$08             wz
'if_z    jmp             #assign_vga
'        ' set tv command, set the tv to one of the four possible screens
'        and             rxreg, #3               ' mask to 4 options
'        add             rxreg, #screen1         ' get address of screen pointer
'        movs            assign_command_copy, rxreg
'        nop
'assign_command_copy
'        mov             x, screen1
'        ' now set the screen pointer in hub ram for the tv driver
'        wrlong          x, tvptr
'        jmp             #wr_command_exit

'assign_vga
'        ' testing for hi-res mode here if implemented
'        and             rxreg, #3
'        add             rxreg, #screen1
'        movs            assign_command_vga_copy, rxreg
'        nop
'assign_command_vga_copy
'        mov             x, screen1
'        wrlong          x, vgaptr
        jmp             #wr_command_exit

select_command
        ' select the nth screen buffer as active based on the lower 4 bits of the command
'        test            rxreg, #$0C             wz      ' if this isn't zero then we're not
'                                                        ' dealing with a normal screen
'if_nz   jmp             #select_other_command
'        ' select one of the four primary work spaces
'        and             rxreg, #$03                     ' mask the address of the new screen
'        shl             rxreg, #4
'        add             active_screen, rxreg            ' put the new screen in second nibble
'        call            #set_active                     ' swap over all active variables
'
        jmp             #wr_command_exit

'select_other_command
'        ' select a target other than a screen buffer, not supported yet
'        jmp             #wr_command_exit

set_flag
        ' set the flag to say what command we've received and what to do with the next byte
        mov             command_flags, rxreg
        jmp             #wr_command_exit

'set_get_commands
'        mov             x, rxreg
'        shr             x, #6                         ' mask off the command bits
'        sub             x, #1                         ' values are 1, 2, 3 want 0, 1, 2
'        add             x, #colour
'        test            rxreg, #$20             wz
'if_z    jmp             #get_commands
'        and             rxreg, #$1F
'        movd            set_command, x
'set_command
'        mov             colour, rxreg
'        jmp             #wr_command_exit

'get_commands
'        movs            get_command, x
'get_command
'        mov             txreg, colour
'        jmp             #wr_command_exit

'map_screens
'        test            rxreg, #$4              wz
'if_z    jmp             #map_vga_screen
'        test            rxreg, #$1              wz
'if_z    jmp             #map_screen_tv_1
'        wrlong          screen2, tvptr
'        jmp             #wr_command_exit
'map_screen_tv_1
'        wrlong          screen1, tvptr
'        jmp             #wr_command_exit

'map_vga_screen
'        test            rxreg, #$1              wz
'if_z    jmp             #map_screen_vga_1
'        wrlong          screen2, vgaptr
'        jmp             #wr_command_exit
'
'map_screen_vga_1
'        wrlong          screen1, vgaptr
'        jmp             #wr_command_exit


'set_active
'        test            rxreg, #$1              wz
'if_z    jmp             #set_active_1
'        call            #switch2
'        jmp             #wr_command_exit
'
'set_active_1
'        call            #switch1
'        jmp             #wr_command_exit



''
''      rd_data - allow the Z80 to read a byte of data
''
rd_data
        ' first find the data it wants - the byte from the cursor
        ' on the active screen
        mov             hubad, row
        shl             hubad, #rowshift
        add             hubad, col
        'shl             hubad, #1               ' word aligned
        add             hubad, screen
        rdbyte          txdat, hubad

        'next, we need to move the lsb because of colour mapping
'        test            txdat, col_bit          wz
'if_nz   or              txdat, #$1

        ' now mask the byte and put it in the output
'        and             txdat, #$ff
        andn            outa, #$ff
        or              outa, txdat

        ' drive the outputs
        or              dira, #$ff
        ' set the buffer direction
        andn            outa, dir_pin
        ' enable the buffer
        andn            outa, buffer_enable_pin

        nop
        nop
        ' now release the wait pin and wait for the Z80 to finish
        andn            outa, wait_pin
        waitpeq         rd_data_pin, rd_data_pin
        nop
        or              outa, buffer_enable_pin
        or              outa, dir_pin
        andn            dira, #$ff

        jmp             #main

''
''      rd_command - respond to info commands
''
rd_command
        ' just present the contents of txreg, it is the Z80's responsibility
        ' to request the data be put in this register before reading it

        ' now mask the byte and put it in the output
        and             txreg, #$ff
        andn            outa, #$ff
        or              outa, txdat

        ' drive the outputs
        or              dira, #$ff
        ' set the buffer direction
        andn            outa, dir_pin
        ' enable the buffer
        andn            outa, buffer_enable_pin

        ' now release the wait pin and wait for the Z80 to finish
        andn            outa, wait_pin
        waitpeq         rd_command_pin, rd_command_pin
        or              outa, buffer_enable_pin
        or              outa, dir_pin
        andn            dira, #$ff

        jmp             #main

''
''      Set Active - set the current screen to the one specified by the second least significant nibble
''                      in the active_screen register
''
'set_active
'        ' active_screen contains the current screen in bits in 0-1 and the next in 4-5
'        mov             x, active_screen
'        and             x, #$3
'        add             x, #row1             ' get the base address for the screen parameters
'        movd            copy_row, x
'        add             x, #4                ' point to columns
'copy_row
'        mov             row1, row
'        movd            copy_col, x
'        add             x, #4                ' point to colours
'copy_col
'        mov             col1, col
'        movd            copy_colour, x
'        nop
'copy_colour
'        mov             colour1, colour
'
'        mov             x, active_screen
'        and             x, #$30
'        shr             x, #4                ' set temp equal to target screen number
'        add             x, #row1
'        movs            copy_row2, x
'        add             x, #4
'copy_row2
'        mov             row, row1
'        movs            copy_col2, x
'        add             x, #4
'copy_col2
'        mov             col, col1
'        movs            copy_colour2, x
'        add             x, #4
'copy_colour2
'        mov             colour, colour1
'        movs            copy_screen, x
'        nop
'copy_screen
'        mov             screen, screen1
'
'        ' now just set the active sceen field
'        and             active_screen, #$30
'        shr             active_screen, #4
'set_active_ret
'        ret

''
''      Print - prints a character, handles character codes no understanding
''              of special ascii characters (newline etc.)
''
print   'mov   char, colour
        'shl   char, #2
        'test  rxreg, #1         wz
'if_nz   or    char, #2
        'or    char, #1
        'shl   char, #$9
        'add   char, rxreg
        'andn  char, #$1

        mov   hubad, row
        shl   hubad, #rowshift
        add   hubad, col
        'shl   hubad, #1         'word aligned.
        add   hubad, screen

        wrbyte rxreg, hubad

        add   col,#1
        cmp   col, #cols         wc
if_nc   call  #newline

print_ret     ret


''
''      Newline - moves the cursor to the start of a new line
''                if at the bottom of the screen it wraps or scrolls
''                depending on the state of the wrap/scroll setting
''
newline
        mov             col, #0
        add             row, #1
        cmp             row, #rows        wc
if_c    jmp             #newline_ret      ' return if row is less than rows
        ' here we need to scroll or wrap the display
        test            flags, auto_scroll_flag           wz
if_z    jmp             #wrap_vert        ' wrap, don't scroll
        ' scroll is set, need to scroll the whole screen up
        mov             x, #cols               ' calculate the address of the
        shl             x, #rowshift           ' last byte in the screen

        mov             hubad, #1
        shl             hubad, #rowshift
        add             hubad, screen

scroll_loop
        rdbyte          y, hubad         ' read two characters
        sub             hubad, #cols     ' jump back one line of characters
        wrbyte          y, hubad         ' write them back
        add             hubad, #cols+1   ' jump forward one line and two characters
        djnz            x, #scroll_loop

        ' now need to write the last row, and pointing at first long AFTER the buffer
        sub             hubad, #cols
        mov             x, #cols            ' now fill the last row with zeros
        mov             y, #$20

space_loop
        wrbyte          y, hubad
        add             hubad, #1
        djnz            x, #space_loop

        mov             row, #rows-1       ' set row back to the last line
        jmp             #newline_ret

wrap_vert
        mov   row, #0

newline_ret     ret

''
''      backspace - move the cursor back one space
''
backspace
        cmp             col, #0                 wz
if_z    jmp             #backspace_ret                  ' if at column zero can't backspace
        sub             col, #1                         ' decrement column and return
backspace_ret
        ret

''
''      tab - fill with spaces until in a modulo 8 column
''
tab
        mov             rxreg, #$20                     ' space
        call            #print
        test            col, #3                 wz
tab_ret
if_z    ret                                             ' modulo 8 number
        jmp             #tab                            ' keep looping

''
''      delete - shift all characters to the right of the cursor up one and put a space at the end
''
delete
        mov             endofscreen, cols               ' calculate the address of the
        shl             endofscreen, #rowshift           ' last byte in the screen
        sub             endofscreen, #1                 ' so we know when to stop
        add             endofscreen, screen

        mov             hubad, row
        shl             hubad, #rowshift
        add             hubad, col
        add             hubad, screen

delete_loop
        add             hubad, #1
        cmp             hubad, endofscreen      wz
if_z    jmp             #delete_last
        rdbyte          rxreg, hubad
        sub             hubad, #1
        wrbyte          rxreg, hubad
        jmp             #delete_loop

delete_last
        mov             rxreg, #$20             'space
        wrbyte          rxreg, hubad
delete_ret
        ret

''
''      cls - Clear screen, and reset cursors to (0,0)
''
cls
        mov             x, #cols
        shl             x, #rowshift
        sub             x, #1
        mov             hubad, screen
        mov             y, #$20
cls_loop
        wrbyte          y, hubad
        add             hubad, #1
        djnz            x, #cls_loop

        mov             row, #0
        mov             col, #0
cls_ret ret



colour  long  0
col     long  0
row     long  0
row1    long  0
row2    long  0
row3    long  0
row4    long  0
col1    long  0
col2    long  0
col3    long  0
col4    long  0
colour1 long  0
colour2 long  0
colour3 long  0
colour4 long  0
screen1 long  0
screen2 long  0
screen3 long  0
screen4 long  0
flags   long  1

auto_scroll_flag long %0000_0001
screen2_flag  long %0000_0010

bignum  long 200_000_000
doublespace  long      $02200220
col_bit long  $400

' IO port definitions
start_dirs              long    %0000_0000__0000_0000__1000_1011__0000_0000
start_levels            long    %0000_0000__0000_0000__0000_1011__0000_0000

int_pin                 long    %1000__0000_0000
wait_pin                long    %1000_0000__0000_0000
rd_command_pin          long    %1__0000_0000__0000_0000__0000_0000
wr_command_pin          long    %10__0000_0000__0000_0000__0000_0000
rd_data_pin             long    %100__0000_0000__0000_0000__0000_0000
wr_data_pin             long    %1000__0000_0000__0000_0000__0000_0000
dir_pin                 long    %10__0000_0000
buffer_enable_pin       long    %1__0000_0000
trigger_mask            long    $0f000000
command_flags           long    0
vgaptr        res       1
tvptr         res       1
screen        res       1
rxreg         res       1
txreg         res       1
txdat         res       1
hubad         res       1
char          res       1
y             res       1
x             res       1
active_screen res       1
cur1          res       1
cur2          res       1
endofscreen   res       1
