;-------------------------------------------------------------------------------
;
; ps2.asm - PS/2 Keyboard driver and buffer firmware - PS/2 communication
;           routines for Z80 project Mark 2
; File Version 1.0 - 23 Feb 2010
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
;-------------------------------------------------------------------------------

list p=18f4520
include <p18f4520.inc>
include <portpins.inc>

; -- Externals from hostbus.asm ------------------------------------------------

    EXTERN      hostbus_push

; -- Externals from translation.asm --------------------------------------------

    EXTERN      translate_key

    UDATA
bit_count               res     1
txreg                   res     1
rxreg                   res     1
ps2_send_val_temp       res     1
ps2_send_ptr_temp       res     1
ps2_timeout_reg         res     1
ps2_send_count          res     1

flags                   res     1
txflags                 res     1

count                   res     3

parity                  res     1
parity_flag             equ     0

    CODE

;===============================================================================
; ps2_init - setup interrupts and counter/timers
;===============================================================================

;; Called at boot to initialise all the flags registers, bit counters and 
;; interrupts used by the PS/2 communication routines

ps2_init
  movlw         0x02
  movwf         FSR2H                   ; initialise send buffer pointer
  movlw         0x01
  movwf         FSR1H
  movwf         FSR0H

  clrf          FSR0L
  clrf          FSR1L
  clrf          FSR2L

  clrf          ps2_send_count

  clrf          bit_count

  movlw         b'01000010'
  movwf         T0CON                   ; setup for interrupt ~5kHz
  clrf          TMR0L

  ; set the default flags
  movlw         b'00000010'
  movwf         flags

  bcf           INTCON2, INTEDG0        ; interrupt on falling edge on RB0

  bsf           INTCON, INT0IE
  bsf           INTCON, TMR0IE
  bcf           INTCON, TMR0IF
  bcf           INTCON, INT0IF

  return

;===============================================================================
; ps2_keyboard_init - intialise the keyboard (reset and LEDs etc.)
;===============================================================================

;; This is a main loop function that waits for the keyboard to send a successful
;; startup message.  If it does not within ~1 second of entering the routine, a
;; reset message is sent to the keyboard and the timeout begins again.\\
;; Once the keyboard is started the LEDs are set to the default state.

ps2_keyboard_init
  ; setup timer1 for 1 second overflow
  movlw         b'00110001'             ; enable TMR1 1:8 prescale
  movwf         T1CON

  ; means it will overflow 19.07 times in a second
  movlw         0x20
  movwf         ps2_timeout_reg

ps2_keyboard_wait
  btfss         LATA, P_FOUND           ; see if the keyboard has been found
  bra           ps2_keyboard_init_done  ; disable timer and exit

  ; not found yet, wait for timeout
  btfsc         PIR1, TMR1IF
  bra           ps2_keyboard_wait
  ; timer overflowed
  bcf           PIR1, TMR1IF            ; clear flag
  decfsz        ps2_timeout_reg, f      ; keep count of how many times it has
  bra           ps2_keyboard_wait

  call          ps2_wait_to_talk
  btfss         LATA, P_FOUND
  bra           ps2_keyboard_init_done  ; exit if it got through at the last min
  movlw         0xFF
  call          ps2_start_talking

  bra           ps2_keyboard_init       ; go back to waiting (reset to 1 sec

ps2_keyboard_init_done
  ; clear any active_flags
  movlw         b'00000010'
  movwf         flags

  movlw         b'00010000'
  movwf         txflags

  ; send LEDs
  movlw         0xED
  call          ps2_queue_send

  movlw         0x07
  andwf         flags, w
  call          ps2_queue_send

  ; all done go back to main
  return

;===============================================================================
; ps2_timer_int - service a timer interrupt used in the PS/2 comms
;===============================================================================

;; The timer interrupt is used as a watchdog for serial comms, if a bit 
;; transition is expected but doesn't arrive after a certain time the receiver
;; is reset, this can cope with noise on the line such as connecting the
;; keyboard after boot.  The timer is also used in initialising host to device
;; communication which requires a timed initialisation phase.

ps2_timer_int
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
  return

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
  return

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
  ; leave the interrupt
  return

;===============================================================================
; ps2_edge_int - an edge on the clock line caused interrupt
;===============================================================================

;; Triggered by a falling edge on the clock line, means we need to read or
;; write a bit from/to the keyboard.

ps2_edge_int
  ; a falling edge on the keyboard clock save the bit
  bsf           T0CON, TMR0ON           ; enable timeout counter
  movlw         d'0'                    ; startbit
  xorwf         bit_count,w
  bz            edge_event_start
  movlw         d'9'                    ; parity bit
  xorwf         bit_count,w
  bz            edge_event_parity
  movlw         d'10'                   ; stop bit
  xorwf         bit_count,w
  bz            edge_event_stop
  movlw         d'11'                   ; ack bit in tx mode only
  xorwf         bit_count,w
  bz            edge_event_ack

  ; otherwise it's a data bit
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
  movf          rxreg, w
  call          translate_key
  goto          edge_event_exit
  ; do some translation here

edge_event_send_stop
  ; need to send the stop bit
  bsf           TRISB, 1                ; set data as HIGH-Z
  ; not quite done, need to wait for an ack as well
  goto          edge_event_exit

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
  return

;===============================================================================
; ps2_queue_send - queue a byte to be sent to the keyboard
;===============================================================================

;; This can be called with a byte in WREG to send to the keyboard (e.g. 0xED
;; then the LED setting to change LED state).  The byte is queued in an internal
;; buffer and sent once there are no ongoing transmissions.

ps2_queue_send
  ; this can be called in interrupt so need to save the current pointer
  movwf         ps2_send_val_temp
  movf          FSR2L,w
  movwf         ps2_send_ptr_temp

  movlw         0x00
  xorwf         ps2_send_count, w        ; see if there are any bytes queued
  bz            ps2_queue_send_save_here ; if not save straight away

  ; at least one byte queued, increment pointer until we're past the byte
ps2_queue_send_loop
  incf          FSR2L, f
  decfsz        WREG, f
  bra           ps2_queue_send_loop

ps2_queue_send_save_here
  movf          ps2_send_val_temp, w
  movwf         INDF2

  incf          ps2_send_count,f         ; increment bytes to send reference

  ; return the pointer to where it was
  movf          ps2_send_ptr_temp, w
  movwf         FSR2L
  return

;===============================================================================
; ps2_send_bytes - send any queued bytes if the line is clear
;===============================================================================

;; If there are any bytes to send to the keyboard in the send buffer, send them
;; as soon as the line is clear.  Then wait for a response (ACK or RESEND) and
;; deal with it, if it's ACK, dump the sent byte and shift the buffer and return

ps2_send_bytes
  ; keep looking for bytes to send, and then to see if it's safe to send them
  movlw         0x00
  xorwf         ps2_send_count,w
  btfsc         STATUS, Z
  return                                ; no bytes to send

ps2_send_bytes_resend
  bcf           txflags, resend_flag
  call          ps2_wait_to_talk
  ; safe to send
  movf          INDF2, w
  call          ps2_start_talking
  ; now wait for an ack
ps2_send_bytes_wait
  movlw         0x03
  andwf         txflags, w
  bz            ps2_send_bytes_wait

  ; got a response
  btfss         txflags, ack_flag
  ; was a resend request
  bra           ps2_send_bytes_resend

  ; dec the byte count and move the pointer on

  incf          FSR2L, f
  decf          ps2_send_count, f

  bcf           txflags, ack_flag
  bcf           txflags, resend_flag    ; make sure they're both clear

  return                                ; return to main

ps2_wait_to_talk
  movlw         0x00
  xorwf         bit_count,w             ; see if we're already receiving  
  bnz           ps2_wait_to_talk        ; wait for a gap
  return

ps2_start_talking
  movwf         txreg
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
  return

;-- Export the global functions and registers ----------------------------------

    GLOBAL      ps2_init
    GLOBAL      ps2_keyboard_init
    GLOBAL      ps2_timer_int
    GLOBAL      ps2_edge_int
    GLOBAL      ps2_queue_send
    GLOBAL      ps2_send_bytes

    GLOBAL      flags
    GLOBAL      txflags

end