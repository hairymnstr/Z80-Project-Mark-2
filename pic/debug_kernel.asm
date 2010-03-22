;------------------------------------------------------------------------------
;
; Simple Debug Kernel for CPU supervisor on Z80 Project Mark 2
; File Version 1 - 20 - Sep - 2009
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

;== PORT Definitions ==========================================================

;-- PORT A --------------------------------------------------------------------

P_RESET         EQU     0
P_BUSRQ         EQU     1
P_MREQ          EQU     2
P_IORQ          EQU     3
P_WAIT          EQU     4
P_HI_LAT        EQU     5

;-- PORT C --------------------------------------------------------------------

P_BUSACK        EQU     0
P_SD_CS         EQU     1
P_CLK           EQU     2
P_SD_CK         EQU     3
P_SD_DI         EQU     4
P_SD_DO         EQU     5
P_TX            EQU     6
P_RX            EQU     7

;-- PORT E --------------------------------------------------------------------

P_RD            EQU     0
P_WR            EQU     1
P_CS            EQU     2

;== Variables =================================================================

UDATA

count   RES     3
LO_ADDR RES     1
HI_ADDR RES     1
DREG    RES     1
RX_MODE RES     1
; -- RX MODE CONSTANTS --------------------------------------------------------
RX_COM  EQU     0
RX_LEN  EQU     1
RX_DAT  EQU     2
RX_CKS  EQU     3
RX_BSY  EQU     4

RX_COMMAND      RES     1
RX_COUNT        RES     1
RX_CHECKSUM     RES     1
RX_FLAGS        RES     1
; -- FLAG VALUES --------------------------------------------------------------
CHECKSUM_FAIL   EQU     0x01

TX_CHECKSUM     RES     1
TX_COUNT        RES     1
MODE            RES     1
TEMP_MODE       RES     1

MAIN_TEMP       RES     1

org 0x00
    goto init

org 0x08
interrupt
    btfsc       PIR1,RCIF       ;test serial receive interrupt flag
    call        serial_rx_int   ;set, so handle received data
    retfie      FAST            ;all interrupts serviced, return reinstating context

init
    clrf        RX_FLAGS
    movlw       0x01
    movwf       FSR0H           ; set FSR0 to BANK1, RX Buffer
    clrf        FSR0L
    movlw       0x02
    movwf       FSR1H           ; set FSR1 to BANK2, TX Buffer
    clrf        FSR1L
    movlw       RX_COM
    movwf       RX_MODE         ; set RX_MODE to look for a command
    call        serial_init     ; initialise the serial port
    call        set_master      ; Z80 not fitted so PIC is always master atm.
    movlw       0x00
    movwf       HI_ADDR
    movlw       0x01
    movwf       LO_ADDR         ; Port address of "debug port"
    bcf         TRISC,5         ; the extra LED on SD card port needs output
    bsf         LATC,5          ; turn the extra LED on
    movlw       0x01
    movwf       DREG            ; initialise DREG with a 1 in the lsb

main
    ; call serial_command_dispatch, checks for a whole command received and
    ; calls an appropriate handler function for the command
    call        serial_command_dispatch
    goto        main





;== Z80 Bus interfacing functions =============================================

;******************************************************************************
;*                                                                            *
;* ensure_master - if in slave mode acquire DMA control and return.           *
;*                 otherwise return immediately.  Note current state.         *
;*                                                                            *
;* Inputs:  NONE                                                              *
;* Outputs: NONE                                                              *
;* Called:  set_master                                                        *
;* Changes: TEMP_MODE                                                         *
;*                                                                            *
;******************************************************************************

ensure_master
    ; check_mode
    movf        MODE,w
    movwf       TEMP_MODE       ; save the mode at the entry to this function
    xorlw       0x00     
    bz          ensure_master_not_master
    return                      ; already master so just return
ensure_master_not_master
    ; not master need to get DMA mode
    call        get_dma
    call        set_master
    return

;******************************************************************************
;*                                                                            *
;* revert_master - set master mode back to the mode in TEMP_MODE              *
;*                                                                            *
;******************************************************************************

revert_master
    movf        MODE,w
    xorwf       TEMP_MODE,w
    bnz         revert_master_needs_change
    return              ; MODE and TEMP_MODE matched don't change
revert_master_needs_change
    btfsc       TEMP_MODE,0     ; test reset mode bit
    goto        revert_master_reset
    btfsc       TEMP_MODE,1     ; test DMA master mode bit
    goto        revert_master_dma
    ; if neither of those need to switch back to slave
    clrf        MODE            ; set mode to slave
    call        set_slave       ; set IO into slave mode
    return

revert_master_reset
    call        get_reset       ; assert the reset line
    call        set_master      ; set IO mode to master
    return

revert_master_dma
    call        get_dma         ; get DMA control
    call        set_master      ; set IO to master
    return


get_dma
    bcf         LATA,1          ; assert the BUSRQ signal low
get_dma_loop
    btfsc       PORTC,0         ; wait for BUSACK to go low
    bra         get_dma_loop
    movlw       0x02
    movwf       MODE            ; set mode to DMA master
    return

get_reset
    bcf         LATA,0          ; pull reset low
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop                         ; leave time for the M cycle to finish
    movlw       0x01
    movwf       MODE
    return

;******************************************************************************
;*                                                                            *
;* set_master - configure pins so PIC is master device                        *
;*                                                                            *
;* Inputs:  NONE                                                              *
;* Outputs: NONE                                                              *
;* Called:                                                                    *
;* Changes: TRISB, TRISE, TRISA                                               *
;*                                                                            *
;******************************************************************************

set_master


    ; set the address pins to output
    clrf        TRISB
    movlw       b'11101100'     ;RD and WR as output, disable PSP
    andwf       TRISE,f
    movlw       0xFF
    movwf       LATE            ;set RD and WR High

    movlw       b'11010000'
    andwf       TRISA,f
    movlw       b'00111100'
    iorwf       LATA,f
    return

set_slave
    setf        TRISB
    movlw       b'00010111'     ; PSP mode
    movwf       TRISE
    setf        LATA            ; all pins in A are high or don't care
    movlw       b'11001100'     ; MREQ, IORQ input
    movwf       TRISA
    return

;******************************************************************************
;*                                                                            *
;* io_read - Read an address on the IO bus                                    *
;*                                                                            *
;* Inputs:  HI_ADDR, LO_ADDR                                                  *
;* Outputs: DREG                                                              *
;* Called:                                                                    *
;* Changes:                                                                   *
;*                                                                            *
;* Asssumes the PIC is in master mode (WAIT in, RD,WR,IORQ,MREQ and ADDR out  *
;*                                                                            *
;******************************************************************************

io_read
    ; set address
    movf    HI_ADDR,w
    movwf   LATB
    bcf     LATA,P_HI_LAT
    movf    LO_ADDR,w
    bsf     LATA,P_HI_LAT
    movwf   LATB
    ; 200ns delay before IORQ and RD
    nop
    bcf     LATA,P_IORQ
    bcf     LATE,P_RD
    nop
    ; mandatory wait state
io_read_wait_loop
    btfss   PORTA,P_WAIT
    bra     io_read_wait_loop
    ; store the read data
    movf    PORTD,w
    ;release IORQ and RD
    bsf     LATE,P_RD
    bsf     LATA,P_IORQ
    movwf   DREG
    return

;******************************************************************************
;*                                                                            *
;* io_write - Write an address on the IO bus                                  *
;*                                                                            *
;* Inputs:  HI_ADDR, LO_ADDR, DREG                                            *
;* Outputs: NONE                                                              *
;* Called:                                                                    *
;* Changes:                                                                   *
;*                                                                            *
;* Asssumes the PIC is in master mode (WAIT in, RD,WR,IORQ,MREQ and ADDR out  *
;*                                                                            *
;******************************************************************************

io_write
    ; set address
    movf        HI_ADDR,w
    movwf       LATB
    bcf         LATA,P_HI_LAT
    movf        LO_ADDR,w
    bsf         LATA,P_HI_LAT
    movwf       LATB
    ; 200ns delay before IORQ and RD
    movf        DREG,w          ; write the data to the bus
    movwf       LATD
    clrf        TRISD           ; don't forget to drive the bus for a write!!
    bcf         LATA,P_IORQ
    bcf         LATE,P_WR
    nop
    ; mandatory wait state
io_write_wait_loop
    btfss       PORTA,P_WAIT
    bra         io_write_wait_loop
    ;release IORQ and RD
    bsf         LATE,P_WR
    bsf         LATA,P_IORQ
    setf        TRISD           ; stop driving the bus again
    return

;******************************************************************************
;*                                                                            *
;* mem_read - Read from an address on the memory bus                          *
;*                                                                            *
;* Inputs:  HI_ADDR, LO_ADDR                                                  *
;* Outputs: DREG                                                              *
;* Called:                                                                    *
;* Changes:                                                                   *
;*                                                                            *
;* Asssumes the PIC is in master mode (WAIT in, RD,WR,IORQ,MREQ and ADDR out) *
;*                                                                            *
;******************************************************************************

mem_read
    ; set address
    movf    HI_ADDR,w
    movwf   LATB
    bcf     LATA,P_HI_LAT
    movf    LO_ADDR,w
    bsf     LATA,P_HI_LAT
    movwf   LATB
    bcf     LATA,P_MREQ
    bcf     LATE,P_RD
mem_read_wait_loop
    btfss   PORTA,P_WAIT
    bra     mem_read_wait_loop
    ; store the read data
    movf    PORTD,w
    ;release IORQ and RD
    bsf     LATE,P_RD
    bsf     LATA,P_MREQ
    movwf   DREG
    return

;******************************************************************************
;*                                                                            *
;* mem_write - Write to an address on the memory bus                          *
;*                                                                            *
;* Inputs:  HI_ADDR, LO_ADDR, DREG                                            *
;* Outputs: NONE                                                              *
;* Called:                                                                    *
;* Changes:                                                                   *
;*                                                                            *
;* Asssumes the PIC is in master mode (WAIT in, RD,WR,IORQ,MREQ and ADDR out) *
;*                                                                            *
;******************************************************************************

mem_write
    ; set address
    movf        HI_ADDR,w
    movwf       LATB
    bcf         LATA,P_HI_LAT
    movf        LO_ADDR,w
    bsf         LATA,P_HI_LAT
    movwf       LATB
    ; 200ns delay before IORQ and RD
    movf        DREG,w          ; write the data to the bus
    movwf       LATD
    clrf        TRISD           ; don't forget to drive the bus for a write!!
    bcf         LATA,P_MREQ
    bcf         LATE,P_WR
    ; mandatory wait state
mem_write_wait_loop
    btfss       PORTA,P_WAIT
    bra         mem_write_wait_loop
    ;release IORQ and RD
    bsf         LATE,P_WR
    bsf         LATA,P_MREQ
    setf        TRISD           ; stop driving the bus again
    return


;== Serial Console Functions ==================================================

;******************************************************************************
;*                                                                            *
;* serial_init - set up the serial port for PC comms                          *
;*                                                                            *
;* Inputs:  NONE                                                              *
;* Outputs: NONE                                                              *
;* Called:                                                                    *
;* Changes: SPBRG, RCSTA, TXSTA, BAUDCON, TRISC, RCON, PIR1, PIE1, INTCON     *
;*                                                                            *
;******************************************************************************

serial_init
    ; first make sure that the RX and TX are both set input, hardware changes
    ; this once the UART is enabled
    movlw       b'11000000'
    iorwf       TRISC,f

    ; next set the UART up
    movlw       0x10
    movwf       SPBRG
    movlw       0x04
    movwf       SPBRGH          ; 9600 baud high speed 16 bit mode
    movlw       b'00100100'     ; enable sending, 8-bit, high speed baud rate
    movwf       TXSTA
    movlw       b'00010000'     ; enable receiving 8-bit
    movwf       RCSTA
    movlw       b'00001000'     ; no-auto sensing - 16 bit baud rate
    movwf       BAUDCON
    bsf         RCSTA,SPEN      ; enable the serial port

    ; set up interrupt on receive
    bsf         RCON, IPEN
    bcf         PIR1, RCIF
    bsf         PIE1, RCIE
    bsf         INTCON, GIEH    ; enable global interrupts
    return

;******************************************************************************
;*                                                                            *
;* serial_send - send the contents of W via the UART                          *
;*                                                                            *
;* Inputs:  Byte to send in W                                                 *
;* Outputs: NONE                                                              *
;* Called:                                                                    *
;* Changes: TXREG                                                             *
;*                                                                            *
;******************************************************************************

serial_send
    btfss PIR1,TXIF     ;test transmit interrupt flag
    bra serial_send     ;if clear, TXREG is full
    movwf TXREG         ;if set, TXREG is empty, so copy data into it
    return

; -- serial_tx_send_packet ----------------------------------------------------

serial_tx_send_packet
    ; send a whole message packet from the TX Buffer
    ; first set the TX pointer to the start of the buffer
    clrf        FSR1L
    ; send the first byte (the command code)
    movf        POSTINC1,w
    call        serial_send
    ; now send the length byte, and initialise the counter
    movf        POSTINC1,w
    call        serial_send
    movwf       TX_COUNT

    andlw       0xFF
    bz          serial_tx_send_packet_checksum  ; if length is zero skip data loop
    ; now we loop over send and decrement the counter
serial_tx_send_packet_data_loop
    movf        POSTINC1,w
    call        serial_send
    decfsz      TX_COUNT,f
    bra         serial_tx_send_packet_data_loop
    
serial_tx_send_packet_checksum
    ; lastly send the checksum
    movf        POSTINC1,w
    call        serial_send

    ; done, return
    return

;******************************************************************************
;*                                                                            *
;* serial_rx_int - UART receive interrupt routine                             *
;*                                                                            *
;* Inputs:  None                                                              *
;* Outputs: None                                                              *
;* Called:                                                                    *
;* Changes: PIR1, w                                                           *
;*                                                                            *
;******************************************************************************

; called later but must be on before the page to avoid relative branch errors
serial_nak_exit
    movlw       0x15
    call        serial_send
    return

serial_rx_int_error
    bcf         RCSTA,CREN              ;clear the CREN bit to clear errors
    movlw       0x15                    ;prepare a NAK symbol
    call        serial_send             ;and send it
    bsf         RCSTA,CREN              ;re-enable receiving
    movf        RCREG,w                 ;have to read the RCREG to clear the interrupt
    return

serial_rx_int
    movlw       b'00000110'
    andwf       RCSTA,w                 ;test if either of the error bits are set
    bnz         serial_rx_int_error     ;if result is not zero an error occurred
serial_rx_int_no_error                  ;if no error occurred, just echo input

    ; if RX_MODE & FC != 0 -> error message, busy
    movlw       0xFC                    ; three non-busy modes
    andwf       RX_MODE,w               ; don't change the RX_MODE
    bnz         serial_nak_exit         ; busy mode so reply NAK, we don't want data at the moment

    movlw       UPPER serial_rx_jump_table
    movwf       PCLATU
    movlw       HIGH serial_rx_jump_table
    movwf       PCLATH
    movf        RX_MODE,w
    rlncf       WREG,f
    rlncf       WREG,f
    goto        serial_rx_jump_table

PAGE            ; doing a jump table need to make sure it's all in one page of memory
serial_rx_jump_table
    addwf       PCL,f
    goto        serial_rx_command       ;0
    goto        serial_rx_length        ;1
    goto        serial_rx_data          ;2
    goto        serial_rx_checksum      ;3

;command byte
serial_rx_command
    ; store the command
    movf        RCREG,w
    movwf       RX_COMMAND    
    ; put it in the RX buffer
    movwf       POSTINC0
    ; also store it to start the checksum
    movwf       RX_CHECKSUM
    ; change to length mode
    incf        RX_MODE,f
    ; return
    return

; length byte
serial_rx_length
    ; set the byte count
    movf        RCREG,w
    movwf       RX_COUNT
    ; store this in the RX buffer too
    movwf       POSTINC0
    ; xor the length for checksum
    xorwf       RX_CHECKSUM,f
    ; change to data mode
    incf        RX_MODE,f
    ; if the byte count is 0 skip data mode
    movlw       0x00
    cpfseq      RX_COUNT
    return
    incf        RX_MODE,f       ; inc to checksum mode
    return

serial_rx_data
    ; store the data byte in the indirect register
    movf        RCREG,w
    movwf       POSTINC0
    ; update the checksum
    xorwf       RX_CHECKSUM,f
    ; decrement the byte counter
    decfsz      RX_COUNT,f
    return
    ; if execution got here the full count of bytes is done
    incf        RX_MODE,f       ; inc to checksum mode
    return

serial_rx_checksum
    movf        RCREG,w
    ; keep a copy in the RX buffer
    movwf       POSTINC0
    ; do an xor with the calculated checksum so far, should result in zero
    xorwf       RX_CHECKSUM,f
    bz          serial_rx_checksum_passed
    ; if execution got here the checksum failed
    xorwf       RX_CHECKSUM,f           ; return to the calculated checksum for debug
    bsf         RX_FLAGS,CHECKSUM_FAIL  ; set a flag
    incf        RX_MODE,f               ; switch to busy mode
    clrf        FSR0L                   ; reset the RX pointer
    return

serial_rx_checksum_passed
    ; checksum okay, set busy mode and exit
    incf        RX_MODE,f
    clrf        FSR0L
    return

; -- End of interrupt routines ------------------------------------------------

;******************************************************************************
;*                                                                            *
;*      serial_command_dispatch - checks command and branches to appropriate  *
;*                                routine                                     *
;*                                                                            *
;*      Called from the main loop to deal with any complete commands          *
;*                                                                            *
;******************************************************************************

serial_command_dispatch
    ; first check if there is a command
    btfss       RX_MODE,2       ; if bit 2 is set (mode 4 == RX_BUSY) there is a command ready
    return                      ; otherwise nothing to do here
    ; next see if there was an error in the checksum
    btfsc       RX_FLAGS,CHECKSUM_FAIL
    goto        serial_error_checksum           ; if there was report the error
    ; no error, so check the command is within bounds
    movlw       0xE0
    andwf       RX_COMMAND,w
    btfss       STATUS,Z
    goto        serial_error_bad_command        ; command was more than 31
    ; We know RX_COMMAND is a valid command now.  Jump
    movlw       UPPER serial_command_jump_table
    movwf       PCLATU
    movlw       HIGH serial_command_jump_table
    movwf       PCLATH
    movf        RX_COMMAND,w
    rlncf       WREG,f
    rlncf       WREG,f
    goto        serial_command_jump_table

PAGE
serial_command_jump_table
    addwf       PCL,f
    goto        serial_error_unused_command     ; 00
    goto        serial_error_unused_command     ; 01
    goto        serial_error_unused_command     ; 02
    goto        serial_error_unused_command     ; 03
    goto        serial_error_unused_command     ; 04
    goto        serial_error_unused_command     ; 05
    goto        serial_read_io                  ; 06
    goto        serial_write_io                 ; 07
    goto        serial_error_unused_command     ; 08
    goto        serial_error_unused_command     ; 09
    goto        serial_error_unused_command     ; 0A
    goto        serial_error_unused_command     ; 0B
    goto        serial_error_unused_command     ; 0C
    goto        serial_error_unused_command     ; 0D
    goto        serial_error_unused_command     ; 0E
    goto        serial_error_unused_command     ; 0F
    goto        serial_error_unused_command     ; 10
    goto        serial_error_unused_command     ; 11
    goto        serial_error_unused_command     ; 12
    goto        serial_error_unused_command     ; 13
    goto        serial_error_unused_command     ; 14
    goto        serial_error_unused_command     ; 15
    goto        serial_error_unused_command     ; 16
    goto        serial_error_unused_command     ; 17
    goto        serial_error_unused_command     ; 18
    goto        serial_error_unused_command     ; 19
    goto        serial_error_unused_command     ; 1A
    goto        serial_error_unused_command     ; 1B
    goto        serial_error_unused_command     ; 1C
    goto        serial_error_unused_command     ; 1D
    goto        serial_error_unused_command     ; 1E
    goto        serial_error_unused_command     ; 1F

; -- serial command functions -------------------------------------------------

serial_read_io
    ; read a single IO port to the serial host
    ; Address   2 bytes be
    ; check that the command argument length is right
    movf        POSTINC0,w              ; command, just move the pointer
    movlw       0x02                    ; correct number of bytes
    movwf       MAIN_TEMP               ; put it in temp for error report
    xorwf       POSTINC0,w              ; check that the length is right
    bnz         serial_error_wrong_parameters   ; not zero so not equal, report
    ; got here so length is good

    ; make sure we can do Z80 bus operations
    call        ensure_master

    movf        POSTINC0,w
    movwf       HI_ADDR
    movf        POSTINC0,w
    movwf       LO_ADDR
    ; do the IO read
    call        io_read

    ; now return to previous master/slave mode
    call        revert_master

    ; now build a serial packet and return it to the host
    clrf        FSR1L
    ; reply with the command
    movf        RX_COMMAND,w
    movwf       POSTINC1
    movwf       TX_CHECKSUM
    ; now the length (1 byte)
    movlw       0x01
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; now the actual data
    movf        DREG,w
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; finally add the checksum to the packet
    movf        TX_CHECKSUM,w
    movwf       POSTINC1

    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_write_io
    ; write a single IO port from the serial host
    ; Address   2 bytes be
    ; Data      1 byte
    ; check that the command argument length is right
    movf        POSTINC0,w              ; command, just move the pointer
    movlw       0x03                    ; correct number of bytes
    movwf       MAIN_TEMP               ; put it in temp for error report
    xorwf       POSTINC0,w              ; check that the length is right
    bnz         serial_error_wrong_parameters   ; not zero so not equal, report
    ; got here so length is good

    ; make sure we can do Z80 bus operations
    call        ensure_master

    movf        POSTINC0,w
    movwf       HI_ADDR
    movf        POSTINC0,w
    movwf       LO_ADDR
    movf        POSTINC0,w
    movwf       DREG
    ; do the IO write
    call        io_write

    ; now return to previous master/slave mode
    call        revert_master

    ; now build a serial packet and return it to the host (just an ack)
    clrf        FSR1L
    ; reply with the command
    movf        RX_COMMAND,w
    movwf       POSTINC1
    movwf       TX_CHECKSUM
    ; now the length (0 bytes)
    movlw       0x00
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; finally add the checksum to the packet
    movf        TX_CHECKSUM,w
    movwf       POSTINC1

    call        serial_tx_send_packet

    goto        serial_handler_exit

; -- serial error functions ---------------------------------------------------

serial_error_checksum
    ; report a message received with a bad checksum
    ; special first character because we don't know if the command was corrupt
    ; or data following it so start with a "0"
    ; set the send pointer to the start of the buffer
    clrf        FSR1L
    movlw       0x80
    movwf       POSTINC1
    movwf       TX_CHECKSUM
    ; next is length byte.  checksum fail message is always 3 bytes
    movlw       0x03
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; now is the error code.  checksum fail = 0x0001
    movlw       0x00
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    movlw       0x01
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; now send the calculated checksum for debugging
    movf        RX_CHECKSUM,w
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; now add the checksum
    movf        TX_CHECKSUM,w
    movwf       POSTINC1
    
    ; packet assembled, send the packet
    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_error_bad_command
    ; report a bad command i.e. byte outside [A-Z]
    ; set the send pointer to the start of the buffer
    clrf        FSR1L
    movlw       0x81     ; bad command so can't do the normal upper/lower conversion
    movwf       POSTINC1
    movwf       TX_CHECKSUM
    ; next is length byte.  always 3 bytes for bad command
    movlw       0x03
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; now is the error code.  bad command = 0x0002
    movlw       0x00
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    movlw       0x02
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; now send the bad command for debug
    movf        RX_COMMAND,w
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; finally add the checksum
    movf        TX_CHECKSUM,w
    movwf       POSTINC1

    ; packet assembled, send the packet
    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_error_unused_command
    ; valid command letter but not used
    ; set the send pointer to the start of the buffer
    clrf        FSR1L
    ; command code is same with bit 6 set
    movf        RX_COMMAND,w
    bsf         WREG,6          ; set bit 6, the error flag
    movwf       POSTINC1
    movwf       TX_CHECKSUM
    ; now the length only the error code now
    movlw       0x02
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; now the error code 0x0003 for unused command
    movlw       0x00
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    movlw       0x03
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; now the checksum
    movf        TX_CHECKSUM,w
    movwf       POSTINC1

    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_error_wrong_parameters
    ; valid command but got the wrong number of parameters
    clrf        FSR1L
    ; command code with bit 6 set
    movf        RX_COMMAND,w
    bsf         WREG,6
    movwf       POSTINC1
    movwf       TX_CHECKSUM
    ; now the length, error code plus the expected number of params
    movlw       0x03
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; now the error code 0x0004
    movlw       0x00
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    movlw       0x04
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; now the correct number of argument bytes
    movf        MAIN_TEMP,w
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; now the checksum
    movf        TX_CHECKSUM,w
    movwf       POSTINC1

    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_handler_exit
    ; standard exit for all serial response functions
    clrf        FSR0L           ; reset RX pointer
    clrf        RX_FLAGS        ; get rid of any flags from this message
    clrf        RX_MODE         ; go back to waiting
    return

delay
    clrf count
    clrf count+1
    movlw 0x08
    movwf count+2
delay_loop
    decfsz count,f
    goto delay_loop
    decfsz count+1,f
    goto delay_loop
    decfsz count+2,f
    goto delay_loop
    return

end