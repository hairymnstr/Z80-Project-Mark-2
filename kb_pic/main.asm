;-------------------------------------------------------------------------------
;
; main.asm - PS/2 Keyboard driver and buffer firmware for Z80 Project Mark 2
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
;-------------------------------------------------------------------------------

list p=18f4520
include <p18f4520.inc>
include <scancodes.inc>
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

;-- Externals from hostbus.asm -------------------------------------------------

    EXTERN      hostbus_init
    EXTERN      hostbus_int
;     EXTERN      hostbus_push

;-- Externals from ps2.asm -----------------------------------------------------

    EXTERN      ps2_init
    EXTERN      ps2_keyboard_init
    EXTERN      ps2_timer_int
    EXTERN      ps2_edge_int
    EXTERN      ps2_send_bytes

    EXTERN      flags

;-- Externals from translation.asm ---------------------------------------------

;     EXTERN      translate_key
    EXTERN      translate_init

UDATA

org 0x00
    goto        init

org 0x08
interrupt
  btfsc         PIR1, PSPIF
  goto          psp_int
  btfsc         INTCON, TMR0IF
  goto          tmr0_int
  goto          int0_int

psp_int
  call          hostbus_int             ; see hostbus.asm for details
  bra           exit_interrupt

tmr0_int
  call          ps2_timer_int
  bra           exit_interrupt

int0_int
  call          ps2_edge_int
  bra           exit_interrupt

exit_interrupt
  retfie        FAST

; == End of Interrupt code ====================================================

init
  movlw         ADCONDEF
  movwf         ADCON1          ; no adc pins

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

  call          hostbus_init            ; setup the PSP
  call          ps2_init                ; setup interrupts
  call          translate_init

  bsf           INTCON, PEIE            ; enable interrupts
  bsf           INTCON, GIE
   
  bcf           LATA, P_READY           ; clear the ready bit

  call          ps2_keyboard_init       ; wait for keyboard to start up

main
  call          ps2_send_bytes
  bra           main

end