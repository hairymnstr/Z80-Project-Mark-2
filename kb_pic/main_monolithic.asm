;==============================================================================
;    main.asm
;==============================================================================

;------------------------------------------------------------------------------
;
; PS/2 Keyboard driver and buffer firmware
; File Version 1.0 - 5 Feb 2010
; hairymnstr@gmail.com
;
; Copyright (C) 2010  Nathan Dumont
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
;
;------------------------------------------------------------------------------

list p=18f4520
include <p18f4520.inc>
include scancodes.inc
include <portpins.inc>

errorlevel -302
errorlevel -205

CONFIG OSC = HSPLL
CONFIG FCMEN = ON, IESO = OFF, PWRT = ON, BOREN = OFF, BORV = 0
CONFIG WDT = OFF, WDTPS = 1, MCLRE = ON, LPT1OSC = OFF
CONFIG PBADEN = OFF, CCP2MX = PORTC, STVREN = ON, LVP = OFF
CONFIG XINST = OFF, DEBUG = OFF, CP0 = OFF, CP1 = OFF, CP2 = OFF, CP3 = OFF
CONFIG CPB = OFF, CPD = OFF, WRT0 = OFF, WRT1 = OFF, WRT2 = OFF, WRT3 = OFF
CONFIG WRTB = OFF, WRTC = OFF, WRTD = OFF, EBTR0 = OFF, EBTR1 = OFF
CONFIG EBTR2 = OFF, EBTR3 = OFF, EBTRB = OFF

UDATA

count           res     3
bit_count       res     1
rxreg           res     1
txreg           res     1
translate_mode  res     1

TRANSLATE_ASCII equ     0x01

flags           res     1

scroll_flag     equ     0
num_flag        equ     1
caps_flag       equ     2
shift_flag      equ     3
release_flag    equ     4
talking_flag    equ     5
send_failed_flag equ    6
update_leds_flag equ    7

parity          res     1

parity_flag     equ     0

flags2          res     1
special_flag    equ     0

org 0x00
    goto        init

org 0x08
interrupt
  btfsc         PIR1, PSPIF
  goto          psp_rd_int
  btfsc         INTCON, TMR0IF
  goto          timeout
  goto          edge_event

psp_rd_int
  ; a byte has been read by the Z80
  ; see if there is a new byte and load that into the buffer
  ; first clear the interrupt so that the Z80 doesn't come back immediately
  bsf           LATA, P_INT

  bcf           PIR1, PSPIF             ; clear the interrupt flag
  movf          FSR0L,w
  xorwf         FSR1L,w
  bz            exit_interrupt          ; if low bytes of fifo write and read
                                        ; match, there's no new data
  ; if not then there's more data for the Z80
  movf          POSTINC1,w              ; get the byte from the read pointer
  movwf         PORTD                   ; put it in the buffer for the next read
  movlw         0x01
  movwf         FSR1H                   ; make sure we don't overflow the buffer
  bcf           LATA, P_INT             ; set the interrupt again
  goto          exit_interrupt

timeout
  ; called if Timer0 overflows.  This means that there wasn't a bit edge in time
  ; alternatively that we've initiated host->device comms
  btfsc         flags, talking_flag
  goto          timeout_talking
  ; just a timeout.  Set all registers back to zero
  clrf          bit_count
  clrf          rxreg
  bcf           T0CON, TMR0ON           ; disable the timeout until the next
                                        ; start bit
  bcf           INTCON, TMR0IF
  goto          exit_interrupt

timeout_talking
  ; Timer0 overflowed, but this is the start of the talking routine
  movlw         0x00
  xorwf         bit_count,w
  bz            timeout_start_talking
  ; it's a timeout in some other part of the talk routine.  set send_failed_flag
  ; and clear up
  bsf           flags, send_failed_flag
  bcf           flags, talking_flag
  bcf           T0CON, TMR0ON           ; disable the timer again
  bsf           TRISB,1                 ; make sure the data pin is an input!
  clrf          bit_count
  clrf          txreg
  bcf           INTCON, TMR0IF          ; clear the interrupt flag
  goto          exit_interrupt          ; all done

timeout_start_talking
  ; just finished the "I want to talk signal"
  ; initialise the parity counter for odd parity
  bsf           parity, parity_flag
  ; set data as output
  bcf           TRISB, 1
  movlw         d'20'
  movwf         count
timeout_wait_loop
  decfsz        count,f
  bra           timeout_wait_loop
  ; set clock as input
  bsf           TRISB, 0
  ; clear the edge interrupt flag
  bcf           INTCON, INT0IF
  ; enable the edge interrupt again
  bsf           INTCON, INT0IE
  ; increment the bit counter because that data bit is the start bit
  incf          bit_count,f
  ; re-enable the timer overflow interrupt
  bcf           INTCON, TMR0IF
  bcf           T0CON, TMR0ON
  clrf          TMR0L
;   clrf          txreg
  ; leave the interrupt
  goto          exit_interrupt

edge_event
  ; a falling edge on the keyboard clock save the bit
  bsf           T0CON, TMR0ON           ; enable timeout counter
  movlw         d'0'
  xorwf         bit_count,w
  bz            edge_event_start
  movlw         d'9'
  xorwf         bit_count,w
  bz            edge_event_parity
  movlw         d'10'
  xorwf         bit_count,w
  bz            edge_event_stop
  movlw         d'11'                   ; ack bit in tx mode only
  xorwf         bit_count,w
  bz            edge_event_ack

  ; it's a data bit
  ; see if we're in talk or listen mode
  btfsc         flags, talking_flag
  bra           edge_event_send_bit
  ; listening so clock in a bit
  rrncf         rxreg,f
  bcf           rxreg,7
  btfsc         PORTB, 1
  bsf           rxreg,7
  goto          edge_event_exit

edge_event_send_bit
  btfsc         txreg,0
  bsf           TRISB, 1        ; only one of these will run but it avoids
  btfss         txreg,0         ; 'glitching' the hardware line with a clear-set
  bcf           TRISB, 1
  btfsc         txreg,0
  btg           parity,parity_flag  ; don't forget the parity bit
  rrncf         txreg,f         ; rotate the register to put the next bit at 0
  goto          edge_event_exit ; all done

edge_event_stop
  ; if we got this far it's the stop bit
  ; see if we need to receive or send
  btfsc         flags, talking_flag
  bra           edge_event_send_stop
  bcf           T0CON, TMR0ON           ; turn off the timer
  setf          bit_count               ; clear the bit count for the next one
  goto          key_translate
  ; do some translation here

edge_event_send_stop
  ; need to send the stop bit
  bsf           TRISB, 1                ; set data as HIGH-Z
  ; not quite done, need to wait for an ack as well
  goto          edge_event_exit

edge_event_save_byte

  call          buffer_push_byte
  goto          edge_event_exit

;edge_event_load_fifo
;   movf          rxreg,w
;   goto          edge_event_exit

edge_event_start
  ; only do this on receive
  clrf          rxreg
  bsf           T0CON, TMR0ON           ; enable the timeout function
  goto          edge_event_exit

edge_event_parity
  ; only care when we're talking but need to check this
  btfss         flags, talking_flag
  goto          edge_event_exit
  ; okay so we're talking, send the parity bit
  btfss         parity, parity_flag
  bcf           TRISB,1
  btfsc         parity, parity_flag
  bsf           TRISB,1
  ; all done
  goto          edge_event_exit

edge_event_ack
  ; this is the acknowledge from the keyboard when we've just sent a byte
  btfsc         PORTB,1
  bra           edge_event_ack_error    ; should have been low
  ; all done transmitting, clear the flags and tidy up
  bcf           T0CON, TMR0ON           ; stop the timer
  setf          bit_count               ; reset the bit counter
  bcf           flags, talking_flag     ; exit talking mode
  clrf          txreg
  goto          edge_event_exit

edge_event_ack_error
  ; all went wrong somewhere, set send_failed bit and clear the status
  bsf           flags, send_failed_flag
  bcf           flags, talking_flag
  setf          bit_count
  bcf           T0CON, TMR0ON
  clrf          txreg
  goto          edge_event_exit

edge_event_exit
  incf          bit_count,f
  clrf          TMR0L                   ; clear the timeout counter
  bcf           INTCON, INT0IF
  goto          exit_interrupt

exit_interrupt
  retfie        FAST

; == End of Interrupt code ====================================================

init
  movlw         ADCONDEF
  movwf         ADCON1

  movlw         PORTADEF
  movwf         LATA
  movlw         PORTADIR
  movwf         TRISA

  movlw         PORTBDEF
  movwf         LATB
  movlw         PORTBDIR
  movwf         TRISB

  movlw         PORTCDEF
  movwf         LATC
  movlw         PORTCDIR
  movwf         TRISC

  ; don't need to set up port D because it is controlled by the PSP mode bits
  ; in TRISE

  movlw         PORTEDEF
  movwf         LATE
  movlw         PORTEDIR
  movwf         TRISE

  ; setup the pointers
  movlw         0x01
  movwf         FSR0H
  movwf         FSR1H
  clrf          FSR0L
  clrf          FSR1L

  clrf          bit_count

  movlw         b'01000010'
  movwf         T0CON                   ; setup for interrupt ~5kHz
  clrf          TMR0L

  ; set the default translation mode to ascii
  movlw         TRANSLATE_ASCII
  movwf         translate_mode

  ; set the default flags
  movlw         b'00000010'
  movwf         flags

  bcf           INTCON2, INTEDG0        ; interrupt on falling edge on RB0

  bsf           INTCON, INT0IE
  bsf           INTCON, TMR0IE
  bcf           INTCON, TMR0IF
  bcf           INTCON, INT0IF
  bcf           PIR1, PSPIF
  bsf           PIE1, PSPIE
  bsf           INTCON, PEIE
  bsf           INTCON, GIE
   
  bcf           LATA, P_READY           ; clear the ready bit in the Z80 status register

waiting_start
  setf          count
  setf          count+1                 ; set up a timeout
  movlw         0x20
  movwf         count+2
wait_new_board_loop
  btfss         LATA, P_FOUND           ; keep checking if there's a keyboard
  goto          main2                    ; ready
  decfsz        count,f
  bra           wait_new_board_loop     ; wait until there is
  decfsz        count+1,f
  bra           wait_new_board_loop
  decfsz        count+2,f
  bra           wait_new_board_loop

  ; wait timed out - try sending a reset
  movlw         0xff
  movwf         txreg

  call          wait_to_talk

  bra           waiting_start

main2

;   movlw         0xED
;   movwf         txreg

main
;   bra           main

  btfsc         flags, update_leds_flag
  bra           send_leds_byte
  ; keep looking for bytes to send, and then to see if it's safe to send them
  movlw         0x00
  xorwf         txreg,w
  bz            main            ; if it's a null byte don't send
  ; check if this is a set LEDs command and set a flag
  movlw         0xED
  xorwf         txreg,w
  btfsc         STATUS,Z        ; don't set flag if not zero
  bsf           flags, update_leds_flag

  call          wait_to_talk
  bra           main

wait_to_talk
  movlw         0x00
  xorwf         bit_count,w     ; see if we're already receiving something
  bz            start_talking   ; if not start talking
  
  bra           wait_to_talk       ; other wise wait for a gap

send_leds_byte
  movlw         0x20
  movwf         count+1
  setf          count
;   setf          count+1
loop
  decfsz        count,f
  bra           loop
  decfsz        count+1,f
  bra           loop
  movf          flags,w
  andlw         0x07            ; mask the led bits
  movwf         txreg
  bcf           flags, update_leds_flag
  call          wait_to_talk
  goto          main

; ------------------------------------------------------------------------------
;       Host -> device comms
; ------------------------------------------------------------------------------

start_talking
  ; turn off the edge interrupt for a bit
  bcf           INTCON, INT0IE
  ; set the clock pin to output (drive the line low)
  bcf           TRISB, 0
  ; clear timer 0 for a ~200uS delay, longer than the 100uS minimum
  clrf          TMR0L
  ; start the timer to do the startup delay
  bsf           T0CON, TMR0ON
  ; set the flag to say we're in talk mode
  bsf           flags, talking_flag
  ; wait for the flag to get cleared by the last interrupt (ack bit)

talking_loop
  btfsc         flags, talking_flag
  bra           talking_loop
  ; all done go back to main
  return

test_startup
  movlw         0xAA
  xorwf         rxreg,w
  btfsc         STATUS,Z
  bcf           LATA, P_FOUND
  goto          edge_event_exit

; == Key buffer handler ========================================================

buffer_push_byte
  btfsc         TRISE,OBF
  bra           buffer_push_load_fifo
  ; the buffer is empty so load the byte directly to the Z80
;   movf          rxreg,w
  movwf         PORTD
  bcf           LATA,P_INT              ; set an interrupt.
  return

buffer_push_load_fifo
  
  movwf         POSTINC0                ; bung the byte in the fifo
  movlw         0x01
  movwf         FSR0H                   ; make sure we wrap around 256 bytes
  return

; == Key translation ===========================================================

key_translate
  btfsc         LATA, P_FOUND
  goto          test_startup
  ; see what translation mode is enabled
  movlw         TRANSLATE_ASCII
  xorwf         translate_mode,w
  btfsc         STATUS,Z
  goto          key_ascii
  ; failsafe do key_none
  movf          rxreg,w
  goto          edge_event_save_byte

key_ascii
  movlw         0xF0
  xorwf         rxreg, w
  bz            key_ascii_release
  movlw         0xE0
  xorwf         rxreg, w
  bz            key_ascii_special
  movlw         0x83                    ; F7 - only scan code above 7F
  xorwf         rxreg, w
  btfsc         STATUS,Z
  bz            key_ascii_f7

  ; need to make sure bit 7 isn't set, if it is then it's an ack from setting
  ; LEDs for example
  btfsc         rxreg, 7
  goto          edge_event_exit         ; if it is just ignore

key_ascii_nd_code
  ; do a first pass lookup into "nathan-code"
  movf          rxreg,w
  btfsc         flags2, special_flag
  call          key_nd_decode_special
  btfss         flags2, special_flag
  call          key_nd_decode

  bcf           flags2, special_flag    ; has no meaning now we're in nd code

  ; need to trap the dummy key for print screen which sends two codes
  movwf         rxreg
  xorlw         CC_PSF
  btfsc         STATUS,Z
  goto          key_ascii_exit_release
  movf          rxreg, w                ; get the nd code back
  ; now it's easy to decide what key group the key was in
  btfsc         WREG, 7
  goto          key_ascii_control       ; it's a control or keypad key
  ; if it's not a control key (and it's not!!) then we don't care about release
  btfsc         flags, release_flag
  goto          key_ascii_exit_release
  ; not a special key, translate it into something based on shift/caps
  btfsc         flags, shift_flag
  goto          key_ascii_decode_shift
  btfsc         flags, caps_flag
  goto          key_ascii_decode_caps
  ; no modifiers, just translate to ascii
  goto          key_ascii_decode_nomod

key_ascii_f7
  setf          rxreg
  bcf           rxreg, 7                ; sets code to 7F if we just set the register,
                                        ; if not then it won't affect it.
  bra           key_ascii_nd_code

send_release_code
  ; send F0 to the Z80
  movlw         0xF0
  call          buffer_push_byte
  return

key_ascii_special
  bsf           flags2, special_flag
  goto          edge_event_exit

key_ascii_exit_release
  ; release event on a character key, don't care, clear the flag and exit
  bcf           flags, release_flag
  goto          edge_event_exit

key_ascii_release
  bsf           flags, release_flag
  goto          edge_event_exit

key_ascii_control
  ; control or keypad button
  ; if it's a keypad button delegate
  btfsc         WREG,6
  goto          key_ascii_numpad
  ; it's a control key.  Z80 wants to know about release of these
  movwf         rxreg           ; save this for later
  btfsc         flags, release_flag
  call          send_release_code

  ; send the actual key itself as well
  movf          rxreg, w
  call          buffer_push_byte

  ; now trap locally important keys (shift, caps, num, scroll)
  movlw         0xFE            ; mask makes LSHIFT == RSHIFT
  andwf         rxreg, w
  xorlw         CC_LSHIFT
  btfsc         STATUS,Z
  goto          key_ascii_set_shift
  ; don't care about key release on any of these
  btfsc         flags, release_flag
  goto          key_ascii_exit_release
  movlw         CC_CAPS
  xorwf         rxreg, w
  btfsc         STATUS,Z
  goto          key_ascii_set_caps
  movlw         CC_NUM
  xorwf         rxreg, w
  btfsc         STATUS,Z
  goto          key_ascii_set_num
  movlw         CC_SCROLL
  xorwf         rxreg, w
  btfsc         STATUS, Z
  goto          key_ascii_set_scroll
  goto          edge_event_exit         ; key code we're not interested in

key_ascii_set_shift
  ; see if this is a press or release event
  btfsc         flags, release_flag
  goto          key_ascii_clear_shift
  ; it's a shift key press, set the shift flag
  bsf           flags, shift_flag
  goto          edge_event_exit

key_ascii_clear_shift
  bcf           flags, shift_flag
  bcf           flags, release_flag
  goto          edge_event_exit

key_ascii_set_caps
  ; actually this is toggle caps
  btg           flags, caps_flag
  ; queue a set CAPS LED command
  movlw         0xED
  movwf         txreg
  goto          edge_event_exit

key_ascii_set_num
  movlw         0xED
  movwf         txreg
  btg           flags, num_flag
  goto          edge_event_exit

key_ascii_set_scroll
  movlw         0xED
  movwf         txreg
  btg           flags, scroll_flag
  goto          edge_event_exit

key_ascii_numpad
  ; need to interpret the numpad as a control key or number depending on numlock
  ; also affects whether we send release events
  btfsc         flags, num_flag
  goto          key_ascii_numpad_num    ; it's in numlock mode so send a number
  ; not in numlock, need to decide what the key is and send a release possibly
  call          key_ascii_numpad_control        ; lookup the key

  xorlw         0x00
  btfsc         STATUS, Z
  goto          key_ascii_exit_release  ; if it's zero then it's a 5 which has
                                        ; no meaning in this mode
                                        ; always clear the release flag, doesn't
                                        ; matter if it wasn't set
  btfss         WREG, 7
  bra           key_ascii_numpad_ascii  ; if bit 7 isn't set it's ascii so just
                                        ; send it
  ; if we got here, then it's a control key
  ; send a release code if necessary
  btfss         flags, release_flag
  ; send the control key now
  goto          edge_event_save_byte

; otherwise, it was a release so send release, and clear the flag on the way out
  movwf         rxreg
  call          send_release_code
  movf          rxreg, w
  bcf           flags, release_flag
  goto          edge_event_save_byte

key_ascii_numpad_ascii
  btfsc         flags, release_flag
  goto          key_ascii_exit_release
  goto          edge_event_save_byte

key_ascii_numpad_num
  ; see if it's a release because we don't care about that here
  btfsc         flags, release_flag
  goto          key_ascii_exit_release
  ; lookup the keypad key in the ascii numpad table
  clrf          TBLPTRH
  andlw         0x3F            ; mask top two bits which are set to indicate
                                ; this is a numpad key
  addlw         low ND_CODES_ASCII_NUM
  btfsc         STATUS,C
  incf          TBLPTRH,f
  movwf         TBLPTRL
  movf          TBLPTRH,w
  addlw         high ND_CODES_ASCII_NUM
  movwf         TBLPTRH
  clrf          TBLPTRU
  tblrd*
  movf          TABLAT,w
  goto          edge_event_save_byte

key_ascii_numpad_control
  ; lookup the keypad key in the control codes table
  clrf          TBLPTRH
  andlw         0x3F            ; mask top two bits which are set to indicate
                                ; this is a numpad key
  addlw         low ND_CODES_ASCII_NUMCTRL
  btfsc         STATUS,C
  incf          TBLPTRH,f
  movwf         TBLPTRL
  movf          TBLPTRH,w
  addlw         high ND_CODES_ASCII_NUMCTRL
  movwf         TBLPTRH
  clrf          TBLPTRU
  tblrd*
  movf          TABLAT,w
  return
  
key_ascii_decode_nomod
  movwf         TBLPTRL
  movlw         0x80
  iorwf         TBLPTRL,f
  clrf          TBLPTRU
  movlw         0x77
  movwf         TBLPTRH
  tblrd*
  movf          TABLAT,w
  goto          edge_event_save_byte

key_ascii_decode_shift
  movwf         TBLPTRL
  movlw         0xC0
  iorwf         TBLPTRL,f
  clrf          TBLPTRU
  movlw         0x77
  movwf         TBLPTRH
  tblrd*
  movf          TABLAT,w
  goto          edge_event_save_byte

key_ascii_decode_caps
  movwf         TBLPTRL
  clrf          TBLPTRU
  movlw         0x78
  movwf         TBLPTRH
  tblrd*
  movf          TABLAT,w
  goto          edge_event_save_byte

key_nd_decode
  ; return a keycode in the custom code map specified in scancodes.inc
  ; this sets bit 7 if the key is a control (escape - F1-F12 - Home, Insert etc.)
  ; bits 7 and 6 are set if it is a numberpad key
  ; if neither bit 6 or 7 are set it's a main character/number key
  movwf         TBLPTRL
  clrf          TBLPTRU
  movlw         0x77
  movwf         TBLPTRH
  tblrd*
  movf          TABLAT,w
  return
  
key_nd_decode_special
  
  clrf          TBLPTRH
  addlw         low SCAN_CODES_ND_E0
  btfsc         STATUS,C
  incf          TBLPTRH,f
  movwf         TBLPTRL
  movlw         high SCAN_CODES_ND_E0
  addwf         TBLPTRH,f
  clrf          TBLPTRU
  tblrd*
  movf          TABLAT,w
  return
  
org 0x7700
SCAN_CODES_ND
        db 0xFF,CC_F9   ;00, 01 - F9
        db 0xFF,CC_F5   ;02, 03 - F5
        db CC_F3,CC_F1  ;04 - F3, 05 - F1
        db CC_F2,CC_F12 ;06 - F2, 07 - F12
        db 0xFF,CC_F10  ;08, 09 - F10
        db CC_F8,CC_F6  ;0A - F8, 0B - F6
        db CC_F4,CC_TAB ;0C - F4, 0D - TAB
        db CC_LQ,0xFF   ;0E - `, 0F
        db 0xFF,CC_ALT  ;10, 11 - ALT
        db CC_LSHIFT,0xFF       ;12 - L SHIFT, 13
        db CC_CTRL,CC_Q ;14 - CTRL, 15 - Q
        db CC_1,0xFF    ;16 - 1, 17
        db 0xFF,0xFF    ;18, 19
        db CC_Z,CC_S    ;1A - Z, 1B - S
        db CC_A,CC_W    ;1C - A, 1D - W
        db CC_2,CC_GUIL ;1E - 2, 1F - L GUI
        db 0xFF,CC_C    ;20, 21 - C
        db CC_X,CC_D    ;22 - X, 23 - D
        db CC_E,CC_4    ;24 - E, 25 - 4
        db CC_3,CC_GUIR ;26 - 3, 27 - R GUI
        db 0xFF,CC_SP   ;28, 29 - SPACE
        db CC_V,CC_F    ;2A - V,2B - F
        db CC_T,CC_R    ;2C - T,2D - R
        db CC_5,CC_APPS ;2E - 5, 2F - APPS
        db 0xFF,CC_N    ;30, 31 - N
        db CC_B,CC_H    ;32 - B, 33 - H
        db CC_G,CC_Y    ;34 - G,35 - Y
        db CC_6,0xFF    ;36 - 6, 37
        db 0xFF,0xFF    ;38, 39
        db CC_M,CC_J    ;3A - M, 3B - J
        db CC_U,CC_7    ;3C - U, 3D - 7
        db CC_8,0xFF    ;3E - 8, 3F
        db 0xFF,CC_CM   ;40, 41 - ,
        db CC_K,CC_I    ;42 - K, 43 - I
        db CC_O,CC_0    ;44 - O, 45 - 0 (zero)
        db CC_9,0xFF    ;46 - 9, 47
        db 0xFF,CC_FS   ;48, 49 - .
        db CC_US,CC_L   ;4A - /,4B - L
        db CC_SC,CC_P   ;4C - ;, 4D - P
        db CC_DSH,0xFF  ;4E - -, 4F
        db 0xFF,0xFF    ;50, 51
        db CC_AP,0xFF   ;52 - ', 53
        db CC_LSB,CC_EQ ;54 - [, 55     - =
        db 0xFF,0xFF    ;56, 57
        db CC_CAPS,CC_RSHIFT    ;58 - CAPS, 59 - R SHIFT
        db CC_ENTER,CC_RSB      ;5A - ENTER, 5B - ]
        db 0xFF,CC_WS   ;5C, 5D - \
        db 0xFF,0xFF    ;5E, 5F
        db 0xFF,0xFF    ;60, 61
        db 0xFF,0xFF    ;62,63
        db 0xFF,0xFF    ;64, 65
        db CC_BKSP,0xFF ;66 - BKSP, 67
        db 0xFF,CC_KP1  ;68, 69 - KP 1
        db 0xFF,CC_KP4  ;6A, 6B - KP 4
        db CC_KP7,0xFF  ;6C - KP 7, 6D
        db 0xFF,0xFF    ;6E, 6F
        db CC_KP0,CC_KPD        ;70 - KP 0, 71 - KP .
        db CC_KP2,CC_KP5        ;72 - KP 2, 73 - KP 5
        db CC_KP6,CC_KP8        ;74 - KP 6, 75 - KP 8
        db CC_ESC,CC_NUM        ;76 - ESC, 77 - NUM
        db CC_F11,CC_KPP        ;78 - F11,79 - KP+
        db CC_KP3,CC_KPM        ;7A - KP 3, 7B - KP -
        db CC_KPS,CC_KP9        ;7C - KP *, 7D - KP 9
        db CC_SCROLL,CC_F7      ;7E - SCROLL, 7F - F7 (Not real scan code, has to be moved here from 83)

org 0x7780
ND_CODES_ASCII_NOMOD
        db '0','1'
        db '2','3'
        db '4','5'
        db '6','7'
        db '8','9'
        db 'a','b'
        db 'c','d'
        db 'e','f'
        db 'g','h'
        db 'i','j'
        db 'k','l'
        db 'm','n'
        db 'o','p'
        db 'q','r'
        db 's','t'
        db 'u','v'
        db 'w','x'
        db 'y','z'
        db '`','-'
        db '=','['
        db ']','\''
        db ',','.'
        db '\\','/'
        db ';',' '
        db '\t','\n'
        db '\n',0x7F
        db 0x08,0x00

org 0x77C0
ND_CODES_ASCII_SHIFT
        db ')','!'
        db '\"',0xA3    ; £ symbol
        db '$','%'
        db '^','&'
        db '*','('
        db 'A','B'
        db 'C','D'
        db 'E','F'
        db 'G','H'
        db 'I','J'
        db 'K','L'
        db 'M','N'
        db 'O','P'
        db 'Q','R'
        db 'S','T'
        db 'U','V'
        db 'W','X'
        db 'Y','Z'
        db 0xB0,'_'     ;¬ character mapped to degree symbol
        db '+','{'
        db '}','@'
        db '<','>'
        db '|','?'
        db ':',' '
        db '\t','\n'
        db '\n',0x7F
        db 0x08,0x00

org 0x7800
ND_CODES_ASCII_CAPS
        db '0','1'
        db '2','3'
        db '4','5'
        db '6','7'
        db '8','9'
        db 'A','B'
        db 'C','D'
        db 'E','F'
        db 'G','H'
        db 'I','J'
        db 'K','L'
        db 'M','N'
        db 'O','P'
        db 'Q','R'
        db 'S','T'
        db 'U','V'
        db 'W','X'
        db 'Y','Z'
        db '`','-'
        db '=','['
        db ']','\''
        db ',','.'
        db '\\','/'
        db ';',' '
        db '\t','\n'
        db '\n',0x7F
        db 0x08,0x00

ND_CODES_ASCII_NUM
        db '0', '1'
        db '2', '3'
        db '4', '5'
        db '6', '7'
        db '8', '9'
        db '.', '*'
        db '+', '-'
        db '/', 0x00

ND_CODES_ASCII_NUMCTRL
        db CC_INS, CC_END
        db CC_DOWN, CC_PGDN
        db CC_LEFT, 0x00
        db CC_RIGHT, CC_HOME
        db CC_UP, CC_PGUP
        db 0x7F, '*'
        db '+', '-'
        db '/', 0x00

SCAN_CODES_ND_E0
        db 0xFF, 0xFF   ;00, 01 - F9
        db 0xFF, 0xFF   ;02, 03 - F5
        db 0xFF, 0xFF   ;04 - F3, 05 - F1
        db 0xFF, 0xFF   ;06 - F2, 07 - F12
        db 0xFF, 0xFF   ;08, 09 - F10
        db 0xFF, 0xFF   ;0A - F8, 0B - F6
        db 0xFF, 0xFF   ;0C - F4, 0D - TAB
        db 0xFF, 0xFF   ;0E - `, 0F
        db 0xFF, CC_ALTR   ;10, 11 - ALT
        db 0xFF, CC_PSF   ;12 - L SHIFT, 13
        db CC_CTRLR, 0xFF   ;14 - CTRL, 15 - Q
        db 0xFF, 0xFF   ;16 - 1, 17
        db 0xFF, 0xFF   ;18, 19
        db 0xFF, 0xFF   ;1A - Z, 1B - S
        db 0xFF, 0xFF   ;1C - A, 1D - W
        db 0xFF, CC_GUIL   ;1E - 2, 1F - L GUI
        db 0xFF, 0xFF   ;20, 21 - C
        db 0xFF, 0xFF   ;22 - X, 23 - D
        db 0xFF, 0xFF   ;24 - E, 25 - 4
        db 0xFF, CC_GUIR   ;26 - 3, 27 - R GUI
        db 0xFF, 0xFF   ;28, 29 - SPACE
        db 0xFF, 0xFF   ;2A - V,2B - F
        db 0xFF, 0xFF   ;2C - T,2D - R
        db 0xFF, CC_APPS   ;2E - 5, 2F - APPS
        db 0xFF, 0xFF   ;30, 31 - N
        db 0xFF, 0xFF   ;32 - B, 33 - H
        db 0xFF, 0xFF    ;34 - G,35 - Y
        db 0xFF, 0xFF    ;36 - 6, 37
        db 0xFF, 0xFF    ;38, 39
        db 0xFF, 0xFF    ;3A - M, 3B - J
        db 0xFF, 0xFF    ;3C - U, 3D - 7
        db 0xFF, 0xFF    ;3E - 8, 3F
        db 0xFF, 0xFF   ;40, 41 - ,
        db 0xFF, 0xFF    ;42 - K, 43 - I
        db 0xFF, 0xFF    ;44 - O, 45 - 0 (zero)
        db 0xFF, 0xFF    ;46 - 9, 47
        db 0xFF, 0xFF   ;48, 49 - .
        db CC_KPSL, 0xFF   ;4A - /,4B - L
        db 0xFF, 0xFF   ;4C - ;, 4D - P
        db 0xFF, 0xFF  ;4E - -, 4F
        db 0xFF, 0xFF    ;50, 51
        db 0xFF, 0xFF   ;52 - ', 53
        db 0xFF, 0xFF ;54 - [, 55     - =
        db 0xFF, 0xFF    ;56, 57
        db 0xFF, 0xFF    ;58 - CAPS, 59 - R SHIFT
        db CC_KPE, 0xFF      ;5A - ENTER, 5B - ]
        db 0xFF, 0xFF   ;5C, 5D - \
        db 0xFF, 0xFF    ;5E, 5F
        db 0xFF, 0xFF    ;60, 61
        db 0xFF, 0xFF    ;62,63
        db 0xFF, 0xFF    ;64, 65
        db 0xFF, 0xFF ;66 - BKSP, 67
        db 0xFF, CC_END  ;68, 69 - KP 1
        db 0xFF, CC_LEFT  ;6A, 6B - KP 4
        db CC_HOME, 0xFF  ;6C - KP 7, 6D
        db 0xFF, 0xFF    ;6E, 6F
        db CC_INS, CC_DEL        ;70 - KP 0, 71 - KP .
        db CC_DOWN, 0xFF        ;72 - KP 2, 73 - KP 5
        db CC_RIGHT, CC_UP        ;74 - KP 6, 75 - KP 8
        db 0xFF, 0xFF        ;76 - ESC, 77 - NUM
        db 0xFF, 0xFF        ;78 - F11,79 - KP+
        db 0xFF, CC_PGDN        ;7A - KP 3, 7B - KP -
        db CC_PSR, CC_PGUP        ;7C - KP *, 7D - KP 9
        db 0xFF, 0xFF      ;7E - SCROLL, 7F - F7 (Not real scan code, has to be moved here from 83)
end