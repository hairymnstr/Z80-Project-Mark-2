;------------------------------------------------------------------------------
;
; hostbus.asm - PS/2 Keyboard driver and buffer firmware - Z80 bus interfacing
;               routines for Z80 project Mark 2
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
;------------------------------------------------------------------------------

list p=18f4520
include <p18f4520.inc>
include <portpins.inc>

;-- Externals from ps2.asm -----------------------------------------------------

    EXTERN      ps2_queue_send

    EXTERN      flags
    EXTERN      txflags

;-- Externals from translation.asm ---------------------------------------------

    EXTERN      translation_mode

    UDATA

hostbus_buffer          res     1    ; stores commands from Z80 while processing
high_jump               res     1    ; high byte of jump address
low_jump                res     1    ; low byte of jump address

    CODE

;===============================================================================
; hostbus_init - Setup the PSP and enable relevant interrupts
;===============================================================================

;; Called at boot time, sets the port directions and interrupts for running the
;; parallel slave port and interrupt outputs.

hostbus_init
  ; setup the pointers, INDF0 is write pointer, INDF1 is read, make a looping
  ; 256 byte fifo
  movlw         0x01
  movwf         FSR0H
  movwf         FSR1H
  clrf          FSR0L
  clrf          FSR1L

  ; clear the PSPIF flag if it's set then enable the interrupt
  bcf           PIR1, PSPIF
  bsf           PIE1, PSPIE
  return

;===============================================================================
; hostbus_int - Interrupt service routine for the PSP module
;===============================================================================

;; Called when PSPIF triggers an interrupt.  Deals with commands from the Z80
;; and keeping the output buffer loaded with the latest queued byte from the
;; FIFO.

hostbus_int
  ; test to see if the Z80 read or wrote, if write IBF will be set (OBF might
  ; be low but could just mean we don't have anything to send)
  btfsc         TRISE, IBF
  bra           hostbus_int_write       ; IBF set, so Z80 wrote a byte
  ; otherwise Z80 read a byte
hostbus_int_read
  ; a byte has been read by the Z80
  ; see if there is a new byte and load that into the buffer
  ; first clear the interrupt so that the Z80 doesn't come back immediately
  bsf           LATA, P_INT

  bcf           PIR1, PSPIF             ; clear the internal interrupt flag
  movf          FSR0L,w
  xorwf         FSR1L,w
  btfsc         STATUS, Z               ; if low bytes of fifo write and read
  return                                ; match, there's no new data
  ; if not then there's more data for the Z80
  movf          POSTINC1,w              ; get the byte from the read pointer
  movwf         PORTD                   ; put it in the buffer for the next read
  movlw         0x01
  movwf         FSR1H                   ; make sure we don't overflow the buffer
  bcf           LATA, P_INT             ; set the interrupt again

  return

hostbus_int_write
  movf          PORTD, w
  call          hostbus_command         ; interpret the command byte
  bcf           PIR1, PSPIF             ; clear the interrupt

  return

;===============================================================================
; hostbus_push - push a byte to the Z80, will queue in FIFO if bus is busy
;===============================================================================

;; The contents of WREG are sent to the Z80 at the next available time.  The
;; byte is put straight into the output if there are no queued bytes and an
;; interrupt is sent to the Z80 to request reading.  If the output is currently
;; full the byte is stored in the internal FIFO to await collection.

hostbus_push
  btfsc         TRISE,OBF
  bra           hostbus_push_load_fifo
  ; the buffer is empty so load the byte directly to the Z80
  movwf         PORTD
  bcf           LATA, P_INT             ; set an interrupt.
  return

hostbus_push_load_fifo
  movwf         POSTINC0                ; bung the byte in the fifo
  movlw         0x01
  movwf         FSR0H                   ; make sure we wrap around 256 bytes
  return

;-- Private functions ----------------------------------------------------------

hostbus_command
  ; interpret the byte in W as a command from the Z80
  movwf         hostbus_buffer          ; save the byte before it gets mangled
  movlw         high hostbus_command_table
  movwf         high_jump               ; prepare to do a jump table lookup

  rrncf         hostbus_buffer, w       ; ends up with high nibble * 4 in WREG
  rrncf         WREG, w                 ; which is the jump index
  andlw         0x3C                    ; mask the nibble
  addlw         low hostbus_command_table
  btfsc         STATUS, C
  incf          high_jump, f            ; make sure the high jump is ready

  movwf         low_jump
  movf          high_jump, w
  movwf         PCLATH                  ; set high byte for jump
  movf          low_jump, w
  movwf         PCL                     ; set the low byte for jump

hostbus_command_table
  ; 16 commands
  goto          hostbus_null_command    ; 0
  goto          hostbus_null_command    ; 1
  goto          hostbus_null_command    ; 2
  goto          hostbus_null_command    ; 3
  goto          hostbus_null_command    ; 4
  goto          hostbus_null_command    ; 5
  goto          hostbus_null_command    ; 6
  goto          hostbus_null_command    ; 7
  goto          hostbus_null_command    ; 8
  goto          hostbus_null_command    ; 9
  goto          hostbus_null_command    ; A
  goto          hostbus_null_command    ; B
  goto          hostbus_set_translation_mode    ; C
  goto          hostbus_set_send_release    ; D
  goto          hostbus_set_send_command_release    ; E
  goto          hostbus_set_flags    ; F

hostbus_null_command
  ; unused command code
  return

hostbus_set_flags
  ; command to set the caps/num/scroll flags
  movlw         0xF1
  andwf         flags, f                ; set caps/shift/scroll off

  movf          hostbus_buffer, w
  andlw         0x07
  
  iorwf         flags, f                ; set them to the new value

  movlw         0xED
  call          ps2_queue_send          ; update keyboard LEDs
  movf          flags, w
  andlw         0x07
  call          ps2_queue_send
  return

hostbus_set_send_command_release
  ; lsb contains new setting
  bcf           txflags, send_command_release_flag
  btfsc         hostbus_buffer, 0
  bsf           txflags, send_command_release_flag
  return

hostbus_set_send_release
  ; lsb contains new setting
  bcf           txflags, send_release_flag
  btfsc         hostbus_buffer, 0
  bsf           txflags, send_release_flag
  return

hostbus_set_translation_mode
  ; lower nibble is new translation mode
  movlw         0x0F
  andwf         hostbus_buffer, w
  movwf         translation_mode
  return

;== Export these functions =====================================================

    GLOBAL      hostbus_push
    GLOBAL      hostbus_int
    GLOBAL      hostbus_init

end