''***************************************************************************************
''*                                                                                     *
''*  Z80 BUS DRIVER                                                                     *
''*                                                                                     *
''***************************************************************************************
CON

  cols = 32
  rows = 15
  WIDTH_SHIFT = 5

VAR

  long cog

PUB start(tempvar) : success

  stop
  success := cog := cognew(@init, tempvar) + 1

PUB stop

  if cog
    cogstop(cog~ - 1)

DAT

        org

init    mov             dira, start_dirs
        mov             outa, start_levels
        rdlong          fifo_base, par
        mov             status, par
        add             status, #4

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

wr_command
        ' the Z80 is writing a command to us so we need to read
        ' set the buffer to inwards
        or              outa, dir_pin
        ' set the buffer to drive
        andn            outa, buffer_enable_pin
        nop
        ' read the value
        mov             rxreg, ina
        ' mask to 8 bits
        and             rxreg, #$ff
        ' decide what to do with it
        test            rxreg, #$80             wz
        ' if bit 7 is not set then pass it on to the spin
if_z    jmp             #pass_command
        ' bit 7 was set so this is a data request
        ' set the txcommand to the appropriate data
        and             rxreg, #$0F
        shl             rxreg, #4               ' convert to long address
        add             rxreg, param_base
        mov             txcommand, @rxreg
        and             txcommand, #$FF
        jmp             #leave_wr_command
pass_command
        or              rxreg, cmd_full_flags
        ' check the next fifo location is empty
        mov             fifo_ad, fifo_base
'        add             fifo_ad, #4
        add             fifo_ad, fifo
        ' clear the wait line
        andn            outa, wait_pin
'        rdword          temp, fifo_ad
'        test            temp, full_flag         wz
'if_nz   jmp             #fifo_full
        ' put it in hub ram
        wrword          rxreg, fifo_ad
        ' stop the buffer driving
        or              outa, buffer_enable_pin
        ' increment the fifo pointer
        add             fifo, #2
        and             fifo, #$ff              ' modulo 128 word fifo
        ' return to main
        jmp             #main

wr_data
        ' the Z80 is writing a data byte
        ' for now release the wait line and ignore
        or              outa, dir_pin
        andn            outa, buffer_enable_pin
        nop
        ' read the value
        mov             rxreg, ina
        and             rxreg, #$ff
        or              rxreg, data_full_flags
        mov             fifo_ad, fifo_base
'        add             fifo_ad, #4
        add             fifo_ad, fifo
'        rdword          temp, fifo_ad
'        test            temp, full_flag         wz
'if_nz   jmp             #fifo_full
        andn            outa, wait_pin
        wrword          rxreg, fifo_ad
        or              outa, buffer_enable_pin
        add             fifo, #2
        and             fifo, #$ff
        jmp             #main

rd_command
        ' the Z80 wants to read the command status
        ' several things need to happen here
        ' 1: if we're in fifo full mode reading the command port clears the interrupt
        ' 2: need to see what's wanted could be:
        '   a: a cursor position, we can get this from status
        '   b: some other data that needs to be provided by spin
        '      in this case we need to see if the spin has provided the right info yet
        test            outa, int_pin wz
if_z    jmp             #notfull
        ' interrupt pin is set so this read provides a null byte and clears it
        or              outa, int_pin
        andn            outa, #$ff
        jmp             #doread
notfull

doread  or              dira, #$ff
        andn            outa, dir_pin
        andn            outa, buffer_enable_pin
        andn            outa, wait_pin
        waitpeq         rd_command_pin, rd_command_pin
        or              outa, buffer_enable_pin
        or              outa, dir_pin
        andn            dira, #$ff
        jmp             #main

rd_data
        ' the Z80 wants to read the value at the text cursor
        ' need to fetch the least significant byte of the status long
        rdbyte          txreg, status
        andn            outa, #$ff
        or              outa, txreg
        or              dira, #$ff
        andn            outa, dir_pin
        andn            outa, buffer_enable_pin
        andn            outa, wait_pin
        waitpeq         rd_data_pin, rd_data_pin        ' wait for the read to finish
        or              outa, buffer_enable_pin
        or              outa, dir_pin
        andn            dira, #$ff                      ' set the bus to read again
        jmp             #main

'fifo_full
        ' the internal data and command fifo is full, dump this data
        ' make a note in status register
        ' probably ought to lock the status register
'        rdlong          temp, par
'        or              temp, overflow_flag
'        wrlong          temp, par
        ' also need to release the bus
'        or              outa, buffer_enable_pin
'        andn            dira, wait_pin
'        jmp             #main


display_out
        ' PASM equivalent of the xxtext.out(c) spin function
        ' c is in rxreg
        test            flags, #$07             wz
if_z    jmp             #no_flags
        ' got a flag means we're waiting on a second byte
        test            flags, #01              wz
if_nz   jmp             #set_col
        test            flags, #02              wz
if_nz   jmp             #set_row
        ' must be set colour
        mov             temp, @params
        add             temp, COLOR_SETTING
        and             rxreg, #$07
        mov             @temp, rxreg
        andn            flags, #04              ' clear the flag
        jmp             #display_out_ret

no_flags
        sub             rxreg, #$0C             wc,wr,wz
if_a    jmp             #normal_char
        ' below or equal to $0C, special code

normal_char
        ' just a normal character, need to print it
        ' if screen_mode = 01 or 11, set pointer to screen1
        test            screen_mode, #1         wz
if_z    jmp             #test_mode2
        mov             screen_base, screen1
        call            #print
test_mode2
        test            screen_mode, #2         wz
if_z    jmp             #display_out_ret
        mov             screen_base, screen2
        call            #print

        jmp             #display_out_ret

print   ' actually do the character printing
        mov             temp, screen1_row
        shl             temp, WIDTH_SHIFT
        add             screen_base, temp
        add             screen_base, screen1_col
        ' sorted pointer now do actual character
        mov             temp, screen1_colour
        shl             temp, #1
        test            rxreg, #1               wz
if_z    or              temp, #1
        shl             temp, #$A
        add             temp, chr_offset
        add             temp, rxreg
        andn            temp, #1
        wrword          temp, screen_base

print_ret     ret

display_out_ret         ret
' Initialised data

int_pin                 long    %1000__0000_0000
wait_pin                long    %1000_0000__0000_0000
rd_command_pin          long    %1__0000_0000__0000_0000__0000_0000
wr_command_pin          long    %10__0000_0000__0000_0000__0000_0000
rd_data_pin             long    %100__0000_0000__0000_0000__0000_0000
wr_data_pin             long    %1000__0000_0000__0000_0000__0000_0000
dir_pin                 long    %10__0000_0000
buffer_enable_pin       long    %1__0000_0000

trigger_mask            long    $f000000

start_dirs              long    %0000_0000__0000_0000__1000_1011__0000_0000
start_levels            long    %0000_0000__0000_0000__0000_1011__0000_0000

full_flag               long    %1000_0000__0000_0000
cmd_full_flags          long    %1100_0000__0000_0000
data_full_flags         long    %1010_0000__0000_0000

overflow_flag           long    $1
fifo                    long    $0
' Uninitialised data

rxreg                   res     1
fifo_ad                 res     1
fifo_base               res     1
temp                    res     1
sreg                    res     1
status                  res     1
txreg                   res     1
txcommand               res     1

param_base    long      @params
params  long
screen1_colour          long
screen2_colour          long
screen_mode             long

