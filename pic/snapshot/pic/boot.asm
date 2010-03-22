;==============================================================================
;    boot.asm
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

; -- Externals From host_bus.asm ----------------------------------------------

    EXTERN      ensure_master
    EXTERN      revert_master
    EXTERN      mem_write

    EXTERN      DREG
    EXTERN      HI_ADDR
    EXTERN      LO_ADDR

  UDATA

WRCOUNT         RES     1
BOOTWR_FLAGS      RES     1

  CODE

boot_init

; set up the PWM peripheral that's going to generate the clock
    movlw       d'39'            ; Frequency setting  1 = 5MHz, 2 = 3.33MHz, 
                                 ;                    3 = 2.5MHz, 39 = 250kHz
    movwf       PR2
; Duty cycle 1/2 
; 10 bit value bits <9:2> in CCPR1L
;              bits <1:0> in CCP1CON<5:4>
; 5MHz = 4    (b'0000000100' - 0x01 & b'00')
; 3.33MHz = 6 (b'0000000110' - 0x01 & b'10')
; 2.5MHz = 16 (b'0000010000' - 0x02 & b'00')
; 250kHz = 80 (b'0001010000' - 0x14 & b'00')
; CCP1CON<7:6> 00 - single output
; CCP1CON<5:4> xx - see above
; CCP1CON<3:0> 1100 - PWM mode
    movlw       b'00001100'
    movwf       CCP1CON
    movlw       0x14
    movwf       CCPR1L          

    bcf         TRISC,P_CLK     ; pin as output
    
    movlw       b'00000100'     ; T2 on, no pre or post scale
    movwf       T2CON

    return

;*******************************************************************************
;*  boot_load - loads the boot ROM from the PIC's flash to system memory       *
;*******************************************************************************
boot_load
    ; make sure that the Z80 is a slave
    call	ensure_master

    ; set up the table read pointers

    clrf        TBLPTRU
    movlw       0x60
    movwf       TBLPTRH
    clrf        TBLPTRL

    ; set up EECON1 for Flash memory read
    
    movlw       b'10000000'
    movwf       EECON1

    ; now loop over all 8KB of data
    clrf        HI_ADDR
    clrf        LO_ADDR

boot_load_loop
    tblrd*+             ; copy a byte into TABLAT
    movff       TABLAT,DREG
    call        mem_write
    incfsz      LO_ADDR,f
    bra         boot_load_loop
    incf        HI_ADDR,f
    movf        HI_ADDR,w
    xorlw       0x20
    bnz         boot_load_loop

    ; all done, release the bus if we claimed it and return
    call        revert_master

    return


;*******************************************************************************
;*  boot_update - copy a 128 byte packet from RX buffer to flash               *
;*    This is called repeatedly from serial.asm after an update BIOS command   *
;*    is sent from a PC.                                                       *
;*******************************************************************************
boot_update
    ; first two bytes in the RX buffer are the start address in FLASH
    ; they've already been checked so just trust them
    ; FSR0L is already pointing at the high address

    clrf        TBLPTRU
    movf        POSTINC0,w
    movwf       TBLPTRH
    movf        POSTINC0,w
    movwf       TBLPTRL

    bsf         BOOTWR_FLAGS,0
    ; next code gets run twice because you can only erase data in 64 byte blocks
boot_update_erase
    ; erase a block
    bsf         EECON1, EEPGD
    bcf         EECON1, CFGS
    bsf         EECON1, WREN
    bsf         EECON1, FREE
    bcf         INTCON, GIE

    movlw       0x55
    movwf       EECON2
    movlw       0x0AA
    movwf       EECON2
    bsf         EECON1, WR              ; actual erase command up to 2 ms

    bsf         INTCON, GIE     ; re-enable interrupts
    tblrd*-                     ; dummy decrement, we're going to use pre-inc
                                ; to write so the pointer is still in the
                                ; block when we call write

    bsf         BOOTWR_FLAGS,1  ; flag to see how many times we've done this
    ; write a 32 byte block, happens twice
boot_update_write
    movlw       d'32'
    movwf       WRCOUNT

boot_update_write_loop
    movf        POSTINC0,w
    movwf       TABLAT
    tblwt+*
    decfsz      WRCOUNT,f
    bra         boot_update_write_loop

    ; written 32 bytes to tablat, now need to initiate the write
    bsf         EECON1, EEPGD
    bcf         EECON1, CFGS
    bsf         EECON1, WREN
    bcf         INTCON, GIE

    movlw       0x55
    movwf       EECON2
    movlw       0x0AA
    movwf       EECON2
    bsf         EECON1, WR

    bsf         INTCON, GIE
    bcf         EECON1, WREN

    btfss       BOOTWR_FLAGS,1
    bra         boot_update_second_erase

    bcf         BOOTWR_FLAGS,1
    bra         boot_update_write

boot_update_second_erase
    btfss       BOOTWR_FLAGS,0
    goto        boot_verify
    bcf         BOOTWR_FLAGS,0
    tblrd*+                     ; dummy increment to make sure we erase the next block
    goto        boot_update_erase

boot_verify
    ; check through all the bytes just written to flash and make sure they
    ; match.  Then build a report packet accordingly
    bsf         BOOTWR_FLAGS,2  ; set a flag, this gets cleared if we find an
                                ; error

    movlw       0x1
    movwf       FSR0H
    movlw       0x02            ; need to skip the command and length bytes
    movwf       FSR0L

    ; set the table pointer
    clrf        TBLPTRU
    movf        POSTINC0,w
    movwf       TBLPTRH
    movf        POSTINC0,w
    movwf       TBLPTRL

    movlw       0x80
    movwf       WRCOUNT

boot_verify_loop
    movf        POSTINC0,w
    tblrd*+
    xorwf       TABLAT,w
    btfss       STATUS,Z
    bcf         BOOTWR_FLAGS,2
    decfsz      WRCOUNT,f
    bra         boot_verify_loop

    ; all verified, need to make a response packet based on the OK flag
    btfss       BOOTWR_FLAGS,2
    bra         boot_verify_nak

    ; got here so write went according to plan
    movlw       0x2
    movwf       FSR1H
    clrf        FSR1L

    movlw       0x08            ; successful command 8 executed
    movwf       POSTINC1
    movlw       0x00            ; no data, just ack
    movwf       POSTINC1
    movlw       0x08            ; hard coded checksum Oo
    movwf       POSTINC1

    return

boot_verify_nak
    ; there must have been an error in the memory writing, send a NAK
    movlw       0x02
    movwf       FSR1H
    clrf        FSR1L

    ; going to cheat and use the WRCOUNT as a checksum holder
    clrf        WRCOUNT

    movlw       0x48            ; nak for command 8
    movwf       POSTINC1
    xorwf       WRCOUNT,f
    movlw       0x02            ; only the error code to reply with
    movwf       POSTINC1
    xorwf       WRCOUNT,f
    movlw       0x00
    movwf       POSTINC1
    xorwf       WRCOUNT,f
    movlw       0x08            ; verification error number
    movwf       POSTINC1
    xorwf       WRCOUNT,f
    movf        WRCOUNT,w
    movwf       POSTINC1        ; add the checksum

    return
    

; == Export These ==============================================================

    GLOBAL      boot_init
    GLOBAL      boot_load
    GLOBAL      boot_update

end

