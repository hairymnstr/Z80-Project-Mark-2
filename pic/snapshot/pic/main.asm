;==============================================================================
;    main.asm
;==============================================================================

;------------------------------------------------------------------------------
;
; Simple Debug Kernel for CPU supervisor on Z80 Project Mark 2
; File Version 2 - 17 Oct 09
; hairymnstr@gmail.com
;
; Copyright (C) 2009  Nathan Dumont
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
#include <p18f4520.inc>
#include "portpins.inc"

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

; -- Externals From serial.asm ------------------------------------------------

    EXTERN      serial_rx_int
    EXTERN      serial_init
    EXTERN      serial_command_dispatch

; -- Externals From host_bus.asm ----------------------------------------------

    EXTERN      get_reset
    EXTERN      get_dma
    EXTERN      get_slave
    EXTERN      ensure_master
    EXTERN      revert_master

; -- Externals From boot.asm ---------------------------------------------------

    EXTERN      boot_init
    EXTERN      boot_load

;== Variables =================================================================

UDATA

MAIN_TEMP       RES     1

org 0x00
    goto init

org 0x08
interrupt
    btfsc       PIR1,RCIF       ;test serial receive interrupt flag
    call        serial_rx_int   ;set, so handle received data
    retfie      FAST            ;all interrupts serviced, return reinstating context

init
    movlw       0x0F
    movwf       ADCON1          ; no ADC functionality thanks.
    call        get_reset       ; put the Z80 into reset before we start doing stuff
    call        serial_init     ; initialise the serial port
    call        boot_init       ; set up CPU clock etc.

    bcf         TRISC,5         ; the extra LED on SD card port needs output
    bcf         LATC,5

    call        boot_load
    
    bsf         LATC,5

    ; let the Z80 go!!
    call        get_slave

main
    ; call serial_command_dispatch, checks for a whole command received and
    ; calls an appropriate handler function for the command
    call        serial_command_dispatch
    goto        main

; == Export these =============================================================

    GLOBAL      MAIN_TEMP
end