;-------------------------------------------------------------------------------
;|                                                                             |
;| serial.asm - Dedicated host debug/programming comms for the PIC monitor     |
;| File Version: 2.0                                                           |
;| hairymnstr@gmail.com                                                        |
;|                                                                             |
;| Copyright (C) 2011  Nathan Dumont                                           |
;|                                                                             |
;| This file is part of Z80 Project Mark 2                                     |
;|                                                                             |
;| Z80 Project Mark 2 is free software: you can redistribute it and/or modify  |
;| it under the terms of the GNU General Public License as published by        |
;| the Free Software Foundation, either version 3 of the License, or           |
;| (at your option) any later version.                                         |
;|                                                                             |
;| This program is distributed in the hope that it will be useful,             |
;| but WITHOUT ANY WARRANTY; without even the implied warranty of              |
;| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               |
;| GNU General Public License for more details.                                |
;|                                                                             |
;| You should have received a copy of the GNU General Public License           |
;| along with this program.  If not, see <http://www.gnu.org/licenses/>.       |
;|                                                                             |
;-------------------------------------------------------------------------------

list p=18f4520
include <p18f4520.inc>

; -- Externals From main.asm --------------------------------------------------
    extern      MAIN_TEMP

; -- Externals From host_bus.asm ----------------------------------------------
    extern      HI_ADDR
    extern      LO_ADDR
    extern      DREG

    extern      ensure_master
    extern      revert_master
    extern      io_read
    extern      io_write
    extern      mem_read
    extern      mem_write
    extern      get_reset
    extern      get_slave
    extern      get_dma

; -- Externals From boot.asm --------------------------------------------------
    extern      boot_update

  UDATA

; rx_mode - Variable for the state machine used when receiving packets
rx_mode         res     1
; -- rx mode constants --------------------------------------------------------
RX_COM          equ     0
RX_LEN          equ     1
RX_DAT          equ     2
RX_CKS          equ     3
RX_BSY          equ     4

RX_COMMAND      RES     1
RX_COUNT        RES     1
RX_CHECKSUM     RES     1
RX_FLAGS        RES     1
; -- FLAG VALUES --------------------------------------------------------------
CHECKSUM_FAIL   EQU     0x01

TX_CHECKSUM     RES     1
TX_COUNT        RES     1
JUMP_REG        RES     1
  
  CODE
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
    clrf        RX_FLAGS
    movlw       0x01
    movwf       FSR0H           ; set FSR0 to BANK1, RX Buffer
    clrf        FSR0L
    ; since code only talks when spoken to using two pointers and 512 bytes of
    ; RAM is greedy! now only use FSR0 and in BANK1
    ;movlw       0x02
    ;movwf       FSR1H           ; set FSR1 to BANK2, TX Buffer
    ;clrf        FSR1L
    movlw       RX_COM
    movwf       rx_mode         ; set rx_mode to look for a command
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
    clrf        FSR0L
    ; send the first byte (the command code)
    movf        POSTINC0,w
    call        serial_send
    ; now send the length byte, and initialise the counter
    movf        POSTINC0,w
    call        serial_send
    movwf       TX_COUNT

    andlw       0xFF
    bz          serial_tx_send_packet_checksum  ; if length is zero skip data loop
    ; now we loop over send and decrement the counter
serial_tx_send_packet_data_loop
    movf        POSTINC0,w
    call        serial_send
    decfsz      TX_COUNT,f
    bra         serial_tx_send_packet_data_loop
    
serial_tx_send_packet_checksum
    bcf         LATC,5
    ; lastly send the checksum
    movf        POSTINC0,w
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

    ; if rx_mode & FC != 0 -> error message, busy
    movlw       0xFC                    ; three non-busy modes
    andwf       rx_mode,w               ; don't change the rx_mode
    bnz         serial_rx_int_error     ; busy mode so reply NAK, we don't want data at the moment

    movlw       UPPER serial_rx_jump_table
    movwf       PCLATU
    movlw       HIGH serial_rx_jump_table
    movwf       PCLATH
    movf        rx_mode,w
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
    incf        rx_mode,f
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
    incf        rx_mode,f
    ; if the byte count is 0 skip data mode
    movlw       0x00
    cpfseq      RX_COUNT
    return
    incf        rx_mode,f       ; inc to checksum mode
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
    incf        rx_mode,f       ; inc to checksum mode
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
    incf        rx_mode,f               ; switch to busy mode
    clrf        FSR0L                   ; reset the RX pointer
    return

serial_rx_checksum_passed
    ; checksum okay, set busy mode and exit
    incf        rx_mode,f
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
    btfss       rx_mode,2       ; if bit 2 is set (mode 4 == RX_BUSY) there is a command ready
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
    goto        serial_read_mem                 ; 02
    goto        serial_write_mem                ; 03
    goto        serial_block_mem_read           ; 04
    goto        serial_block_mem_write          ; 05
    goto        serial_read_io                  ; 06
    goto        serial_write_io                 ; 07
    goto        serial_bios_update              ; 08
    goto        serial_do_commands              ; 09
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
    btfss       STATUS,Z
    goto        serial_error_wrong_parameters   ; long bnz
;    bnz         serial_error_wrong_parameters   ; not zero so not equal, report
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
    clrf        FSR0L
    ; reply with the command
    movf        RX_COMMAND,w
    movwf       POSTINC0
    movwf       TX_CHECKSUM
    ; now the length (1 byte)
    movlw       0x01
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    ; now the actual data
    movf        DREG,w
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    ; finally add the checksum to the packet
    movf        TX_CHECKSUM,w
    movwf       POSTINC0

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
    btfss       STATUS,Z                ; long bnz
    goto        serial_error_wrong_parameters
;    bnz         serial_error_wrong_parameters   ; not zero so not equal, report
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
    clrf        FSR0L
    ; reply with the command
    movf        RX_COMMAND,w
    movwf       POSTINC0
    movwf       TX_CHECKSUM
    ; now the length (0 bytes)
    movlw       0x00
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    ; finally add the checksum to the packet
    movf        TX_CHECKSUM,w
    movwf       POSTINC0

    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_read_mem
    ; read a single byte from system memory
    ; Address   2 byte be

    movf        POSTINC0,w      ; dump the command byte
    movlw       0x02            ; correct number of bytes
    movwf       MAIN_TEMP       ; put it in temp for error report
    xorwf       POSTINC0,w      ; check the byte length of the command
    btfss       STATUS,Z        ; long bnz
    goto        serial_error_wrong_parameters

    ; make sure we can do Z80 bus operations
    call        ensure_master

    movf        POSTINC0,w
    movwf       HI_ADDR
    movf        POSTINC0,w
    movwf       LO_ADDR

    call        mem_read

    call        revert_master

    ; reset the send buffer pointer
    clrf        FSR0L
    ; reply with the command
    movf        RX_COMMAND,w
    movwf       POSTINC0
    movwf       TX_CHECKSUM
    ; now the packet length (1 byte of data)
    movlw       0x01
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; now the data byte
    movf        DREG,w
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    ; finally the checksum
    movf        TX_CHECKSUM,w
    movwf       POSTINC0
    
    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_write_mem
    ; write a single byte to system memory
    ; Address   2 byte be
    ; Data      1 byte

    movf        POSTINC0,w
    movlw       0x03            ; correct number of bytes
    movwf       MAIN_TEMP
    xorwf       POSTINC0,w
    btfss       STATUS,Z
    goto        serial_error_wrong_parameters

    ; make sure we can do Z80 bus operations
    call        ensure_master

    movf        POSTINC0,w
    movwf       HI_ADDR
    movf        POSTINC0,w
    movwf       LO_ADDR
    movf        POSTINC0,w
    movwf       DREG

    call        mem_write

    call        revert_master

    clrf        FSR0L

    movf        RX_COMMAND,w
    movwf       POSTINC0
    movwf       TX_CHECKSUM
    ; now the packet length (0 bytes, this is just an ACK)
    movlw       0x00
    movwf       POSTINC1
    xorwf       TX_CHECKSUM,f
    ; finally add the checksum
    movf        TX_CHECKSUM,w
    movwf       POSTINC0

    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_block_mem_read
    ; read a block of memory addresses
    ; Start Address     2 byte be
    ; Data Count        1 byte

    movf        POSTINC0,w
    movlw       0x03
    movwf       MAIN_TEMP
    xorwf       POSTINC0,w
    btfss       STATUS,Z
    goto        serial_error_wrong_parameters

    ; check that we can do Z80 bus operations
    call        ensure_master

    movf        POSTINC0,w
    movwf       HI_ADDR
    movf        POSTINC0,w
    movwf       LO_ADDR
    movf        POSTINC0,w
    movwf       TX_COUNT

    ; ought to check TX_COUNT length here
    movlw       0xFE
    cpfslt      TX_COUNT
    goto        serial_error_packet_length

    clrf        FSR0L

    movf        RX_COMMAND,w
    movwf       POSTINC0
    movwf       TX_CHECKSUM
    movf        TX_COUNT,w
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f

    ; loop call mem_read and store in TX buffer
serial_block_mem_read_loop
    call        mem_read
    movf        DREG,w
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f

    infsnz      LO_ADDR,f
    incf        HI_ADDR,f

    decfsz      TX_COUNT,f
    bra         serial_block_mem_read_loop

    ; release the bus
    call        revert_master

    ; add the checksum
    movf        TX_CHECKSUM,w
    movwf       POSTINC0

    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_block_mem_write
    ; copy a block of data from the PC into the memory
    ; Start Address:    2 bytes be
    ; Data:             Any length 1 or longer
    movf        POSTINC0,w
    movlw       0x03            ; minimum number of parameters
    movwf       MAIN_TEMP
    movf        POSTINC0,w
    movwf       TX_COUNT        ; need to keep a track of this for byte counting
    movlw       0x02            ; we're going to do a greater than, so needs to be 1 less than min
    ; second parameter can be any length of bytes, so the correct length is a minimum
    cpfsgt      TX_COUNT
    goto        serial_error_wrong_parameters

    movf        POSTINC0,w
    movwf       HI_ADDR
    movf        POSTINC0,w
    movwf       LO_ADDR

    ; now set up the byte counter, length of packet data - address field
    movlw       0x02
    subwf       TX_COUNT,f      ; take off the address length

    call        ensure_master

serial_block_mem_write_loop    
    movf        POSTINC0,w
    movwf       DREG

    call        mem_write

    infsnz      LO_ADDR,f
    incf        HI_ADDR,f

    decfsz      TX_COUNT,f
    bra         serial_block_mem_write_loop

    call        revert_master

    clrf        FSR0L
    movf        RX_COMMAND,w
    movwf       POSTINC0
    movwf       TX_CHECKSUM

    movlw       0x00
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f

    movf        TX_CHECKSUM,w
    movwf       POSTINC0

    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_bios_update
    ; update a 128 byte block of the BIOS image in Flash
    ; Start Address:    2 bytes be
    ; Data:             128 bytes
    movf        POSTINC0,w      ; command, dump this
    movlw       0x82            ; 130 exact number of bytes for this packet
    movwf       MAIN_TEMP       ; store the number for a possible error report
    xorwf       POSTINC0,w      ; xor with the length from the packet
    btfss       STATUS,Z        ; if it was zero all ok
    goto        serial_error_wrong_parameters   ; if not send an error

    ; need to check the address is a 128 byte aligned one
    ; next byte is the high address byte, can be anything up to 0x1F
    movf        POSTINC0,w
    andlw       0xE0
    btfss       STATUS,Z
    goto        serial_error_bios_address_space

    movf        POSTINC0,w
    andlw       0x7F            ; needs to be 128 bit aligned, so nothing in
                                ; bottom 7 bits to be valid
    btfss       STATUS,Z
    goto        serial_error_bios_address_offset

    ; looks like there's enough data and the parameters are valid.
    ; apply the 24K offset to point the address to the top of ROM

    movlw       0x02
    movwf       FSR0L
    movlw       0x60
    addwf       INDF0,f         ; add the offset but leave the pointer there

    ; call boot_update to deal with the memory writing
    call        boot_update

    ; boot_update has built the response packet for us, so just send it
    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_do_commands
    ; run a no data command
    movf        POSTINC0,w      ; command 
    movlw       0x01
    movwf       MAIN_TEMP
    xorwf       POSTINC0,w
    btfss       STATUS,Z
    goto        serial_error_wrong_parameters

    ; now perform the lookup
    movf        POSTINC0,w
    movwf       JUMP_REG        ; copy to a holding register
    clrf        MAIN_TEMP       ; clear for high byte of address jump
    bcf         STATUS,C        ; clear the carry bit to rotate into bit 0
    rlcf        JUMP_REG,f      ; rotate storing MSB in C == x 2
    btfsc       STATUS,C        ; see if MSB was set
    bsf         MAIN_TEMP,1     ; if it was add 2 to high reg (gonna x2 later)
    bcf         STATUS,C        ; clear the carry bit again
    rlcf        JUMP_REG,f      ; rotate again x4 now
    btfsc       STATUS,C        ; see if high bit was set
    bsf         MAIN_TEMP,0     ; add 1 to the high byte register

    movlw       LOW serial_cmd_jumps    ; copy the low address for jump table
    addwf       JUMP_REG,f      ; add it to the jump address
    btfsc       STATUS,C        ; see if the add overflowed
    incf        MAIN_TEMP,f     ; if so increment the high address
    movlw       HIGH serial_cmd_jumps   ; get the high address byte
    addwf       MAIN_TEMP,w     ; add it to the high address

    movwf       PCLATH          ; put the high byte into the PCLATH
    movf        JUMP_REG,w
    movwf       PCL             ; put the low address into the PC

serial_cmd_jumps
    ; now put 256 goto commands
    goto        serial_error_do_unknown         ; 0                     
    goto        serial_do_get_reset             ; 1                     
    goto        serial_do_get_dma               ; 2                     
    goto        serial_do_get_slave             ; 3                     
    goto        serial_do_reset                 ; 4                     
    goto        serial_error_do_unknown         ; 5                     
    goto        serial_error_do_unknown         ; 6                     
    goto        serial_error_do_unknown         ; 7                     
    goto        serial_error_do_unknown         ; 8                     
    goto        serial_error_do_unknown         ; 9                     
    goto        serial_error_do_unknown         ; 10                    
    goto        serial_error_do_unknown         ; 11                    
    goto        serial_error_do_unknown         ; 12                    
    goto        serial_error_do_unknown         ; 13                    
    goto        serial_error_do_unknown         ; 14                    
    goto        serial_error_do_unknown         ; 15                    
    goto        serial_error_do_unknown         ; 16                    
    goto        serial_error_do_unknown         ; 17                    
    goto        serial_error_do_unknown         ; 18                                                                                                                                
    goto        serial_error_do_unknown         ; 19                                                                                                                                
    goto        serial_error_do_unknown         ; 20                                                                                                                                
    goto        serial_error_do_unknown         ; 21                                                                                                                                
    goto        serial_error_do_unknown         ; 22                                                                                                                                
    goto        serial_error_do_unknown         ; 23                                                                                                                                
    goto        serial_error_do_unknown         ; 24                                                                                                                                
    goto        serial_error_do_unknown         ; 25                                                                                                                                
    goto        serial_error_do_unknown         ; 26                                                                                                                                
    goto        serial_error_do_unknown         ; 27                                                                                                                                
    goto        serial_error_do_unknown         ; 28                                                                                                                                
    goto        serial_error_do_unknown         ; 29                                                                                                                                
    goto        serial_error_do_unknown         ; 30                                                                                                                                
    goto        serial_error_do_unknown         ; 31                                                                                                                                
    goto        serial_error_do_unknown         ; 32                                                                                                                                
    goto        serial_error_do_unknown         ; 33                                                                                                                                
    goto        serial_error_do_unknown         ; 34                                                                                                                                
    goto        serial_error_do_unknown         ; 35                                                                                                                                
    goto        serial_error_do_unknown         ; 36                                                                                                                                
    goto        serial_error_do_unknown         ; 37                                                                                                                                
    goto        serial_error_do_unknown         ; 38                                                                                                                                
    goto        serial_error_do_unknown         ; 39                                                                                                                                
    goto        serial_error_do_unknown         ; 40                                                                                                                                
    goto        serial_error_do_unknown         ; 41                                                                                                                                
    goto        serial_error_do_unknown         ; 42                                                                                                                                
    goto        serial_error_do_unknown         ; 43                                                                                                                                
    goto        serial_error_do_unknown         ; 44                                                                                                                                
    goto        serial_error_do_unknown         ; 45                                                                                                                                
    goto        serial_error_do_unknown         ; 46                                                                                                                                
    goto        serial_error_do_unknown         ; 47                                                                                                                                
    goto        serial_error_do_unknown         ; 48                                                                                                                                
    goto        serial_error_do_unknown         ; 49                                                                                                                                
    goto        serial_error_do_unknown         ; 50                                                                                                                                
    goto        serial_error_do_unknown         ; 51                                                                                                                                
    goto        serial_error_do_unknown         ; 52                                                                                                                                
    goto        serial_error_do_unknown         ; 53                                                                                                                                
    goto        serial_error_do_unknown         ; 54                                                                                                                                
    goto        serial_error_do_unknown         ; 55                                                                                                                                
    goto        serial_error_do_unknown         ; 56                                                                                                                                
    goto        serial_error_do_unknown         ; 57                                                                                                                                
    goto        serial_error_do_unknown         ; 58                                                                                                                                
    goto        serial_error_do_unknown         ; 59                                                                                                                                
    goto        serial_error_do_unknown         ; 60                                                                                                                                
    goto        serial_error_do_unknown         ; 61                                                                                                                                
    goto        serial_error_do_unknown         ; 62                                                                                                                                
    goto        serial_error_do_unknown         ; 63                                                                                                                                
    goto        serial_error_do_unknown         ; 64                                                                                                                                
    goto        serial_error_do_unknown         ; 65                                                                                                                                
    goto        serial_error_do_unknown         ; 66                                                                                                                                
    goto        serial_error_do_unknown         ; 67                                                                                                                                
    goto        serial_error_do_unknown         ; 68                                                                                                                                
    goto        serial_error_do_unknown         ; 69                                                                                                                                
    goto        serial_error_do_unknown         ; 70                                                                                                                                
    goto        serial_error_do_unknown         ; 71                                                                                                                                
    goto        serial_error_do_unknown         ; 72                                                                                                                                
    goto        serial_error_do_unknown         ; 73                                                                                                                                
    goto        serial_error_do_unknown         ; 74                                                                                                                                
    goto        serial_error_do_unknown         ; 75                                                                                                                                
    goto        serial_error_do_unknown         ; 76                                                                                                                                
    goto        serial_error_do_unknown         ; 77                                                                                                                                
    goto        serial_error_do_unknown         ; 78                                                                                                                                
    goto        serial_error_do_unknown         ; 79                                                                                                                                
    goto        serial_error_do_unknown         ; 80                                                                                                                                
    goto        serial_error_do_unknown         ; 81                                                                                                                                
    goto        serial_error_do_unknown         ; 82                                                                                                                                
    goto        serial_error_do_unknown         ; 83                                                                                                                                
    goto        serial_error_do_unknown         ; 84                                                                                                                                
    goto        serial_error_do_unknown         ; 85                                                                                                                                
    goto        serial_error_do_unknown         ; 86                                                                                                                                
    goto        serial_error_do_unknown         ; 87                                                                                                                                
    goto        serial_error_do_unknown         ; 88                                                                                                                                
    goto        serial_error_do_unknown         ; 89                                                                                                                                
    goto        serial_error_do_unknown         ; 90                                                                                                                                
    goto        serial_error_do_unknown         ; 91                                                                                                                                
    goto        serial_error_do_unknown         ; 92                                                                                                                                
    goto        serial_error_do_unknown         ; 93                                                                                                                                
    goto        serial_error_do_unknown         ; 94                                                                                                                                
    goto        serial_error_do_unknown         ; 95                                                                                                                                
    goto        serial_error_do_unknown         ; 96                                                                                                                                
    goto        serial_error_do_unknown         ; 97                                                                                                                                
    goto        serial_error_do_unknown         ; 98                                                                                                                                
    goto        serial_error_do_unknown         ; 99                                                                                                                                
    goto        serial_error_do_unknown         ; 100                                                                                                                               
    goto        serial_error_do_unknown         ; 101                                                                                                                               
    goto        serial_error_do_unknown         ; 102                                                                                                                               
    goto        serial_error_do_unknown         ; 103                                                                                                                               
    goto        serial_error_do_unknown         ; 104                                                                                                                               
    goto        serial_error_do_unknown         ; 105                                                                                                                               
    goto        serial_error_do_unknown         ; 106                                                                                                                               
    goto        serial_error_do_unknown         ; 107                                                                                                                               
    goto        serial_error_do_unknown         ; 108                                                                                                                               
    goto        serial_error_do_unknown         ; 109                                                                                                                               
    goto        serial_error_do_unknown         ; 110                                                                                                                               
    goto        serial_error_do_unknown         ; 111                                                                                                                               
    goto        serial_error_do_unknown         ; 112                                                                                                                               
    goto        serial_error_do_unknown         ; 113                                                                                                                               
    goto        serial_error_do_unknown         ; 114                                                                                                                               
    goto        serial_error_do_unknown         ; 115                                                                                                                               
    goto        serial_error_do_unknown         ; 116                                                                                                                               
    goto        serial_error_do_unknown         ; 117                                                                                                                               
    goto        serial_error_do_unknown         ; 118                                                                                                                               
    goto        serial_error_do_unknown         ; 119                                                                                                                               
    goto        serial_error_do_unknown         ; 120                                                                                                                               
    goto        serial_error_do_unknown         ; 121                                                                                                                               
    goto        serial_error_do_unknown         ; 122                                                                                                                               
    goto        serial_error_do_unknown         ; 123                                                                                                                               
    goto        serial_error_do_unknown         ; 124                                                                                                                               
    goto        serial_error_do_unknown         ; 125                                                                                                                               
    goto        serial_error_do_unknown         ; 126                                                                                                                               
    goto        serial_error_do_unknown         ; 127                                                                                                                               
    goto        serial_error_do_unknown         ; 128                                                                                                                               
    goto        serial_error_do_unknown         ; 129                                                                                                                               
    goto        serial_error_do_unknown         ; 130                                                                                                                               
    goto        serial_error_do_unknown         ; 131                                                                                                                               
    goto        serial_error_do_unknown         ; 132                                                                                                                               
    goto        serial_error_do_unknown         ; 133                                                                                                                               
    goto        serial_error_do_unknown         ; 134                                                                                                                               
    goto        serial_error_do_unknown         ; 135                                                                                                                               
    goto        serial_error_do_unknown         ; 136                                                                                                                               
    goto        serial_error_do_unknown         ; 137                                                                                                                               
    goto        serial_error_do_unknown         ; 138                                                                                                                               
    goto        serial_error_do_unknown         ; 139                                                                                                                               
    goto        serial_error_do_unknown         ; 140                                                                                                                               
    goto        serial_error_do_unknown         ; 141                                                                                                                               
    goto        serial_error_do_unknown         ; 142                                                                                                                               
    goto        serial_error_do_unknown         ; 143                                                                                                                               
    goto        serial_error_do_unknown         ; 144                                                                                                                               
    goto        serial_error_do_unknown         ; 145                                                                                                                               
    goto        serial_error_do_unknown         ; 146                                                                                                                               
    goto        serial_error_do_unknown         ; 147                                                                                                                               
    goto        serial_error_do_unknown         ; 148                                                                                                                               
    goto        serial_error_do_unknown         ; 149                                                                                                                               
    goto        serial_error_do_unknown         ; 150                                                                                                                               
    goto        serial_error_do_unknown         ; 151                                                                                                                               
    goto        serial_error_do_unknown         ; 152                                                                                                                               
    goto        serial_error_do_unknown         ; 153                                                                                                                               
    goto        serial_error_do_unknown         ; 154                                                                                                                               
    goto        serial_error_do_unknown         ; 155                                                                                                                               
    goto        serial_error_do_unknown         ; 156                                                                                                                               
    goto        serial_error_do_unknown         ; 157                                                                                                                               
    goto        serial_error_do_unknown         ; 158                                                                                                                               
    goto        serial_error_do_unknown         ; 159                                                                                                                               
    goto        serial_error_do_unknown         ; 160                                                                                                                               
    goto        serial_error_do_unknown         ; 161                                                                                                                               
    goto        serial_error_do_unknown         ; 162                                                                                                                               
    goto        serial_error_do_unknown         ; 163                                                                                                                               
    goto        serial_error_do_unknown         ; 164                                                                                                                               
    goto        serial_error_do_unknown         ; 165                                                                                                                               
    goto        serial_error_do_unknown         ; 166                                                                                                                               
    goto        serial_error_do_unknown         ; 167                                                                                                                               
    goto        serial_error_do_unknown         ; 168                                                                                                                               
    goto        serial_error_do_unknown         ; 169                                                                                                                               
    goto        serial_error_do_unknown         ; 170                                                                                                                               
    goto        serial_error_do_unknown         ; 171                                                                                                                               
    goto        serial_error_do_unknown         ; 172                                                                                                                               
    goto        serial_error_do_unknown         ; 173                                                                                                                               
    goto        serial_error_do_unknown         ; 174                                                                                                                               
    goto        serial_error_do_unknown         ; 175                                                                                                                               
    goto        serial_error_do_unknown         ; 176                                                                                                                               
    goto        serial_error_do_unknown         ; 177                                                                                                                               
    goto        serial_error_do_unknown         ; 178                                                                                                                               
    goto        serial_error_do_unknown         ; 179                                                                                                                               
    goto        serial_error_do_unknown         ; 180                                                                                                                               
    goto        serial_error_do_unknown         ; 181                                                                                                                               
    goto        serial_error_do_unknown         ; 182                                                                                                                               
    goto        serial_error_do_unknown         ; 183                                                                                                                               
    goto        serial_error_do_unknown         ; 184                                                                                                                               
    goto        serial_error_do_unknown         ; 185                                                                                                                               
    goto        serial_error_do_unknown         ; 186                                                                                                                               
    goto        serial_error_do_unknown         ; 187                                                                                                                               
    goto        serial_error_do_unknown         ; 188                                                                                                                               
    goto        serial_error_do_unknown         ; 189                                                                                                                               
    goto        serial_error_do_unknown         ; 190                                                                                                                               
    goto        serial_error_do_unknown         ; 191                                                                                                                               
    goto        serial_error_do_unknown         ; 192                                                                                                                               
    goto        serial_error_do_unknown         ; 193                                                                                                                               
    goto        serial_error_do_unknown         ; 194                                                                                                                               
    goto        serial_error_do_unknown         ; 195                                                                                                                               
    goto        serial_error_do_unknown         ; 196
    goto        serial_error_do_unknown         ; 197
    goto        serial_error_do_unknown         ; 198
    goto        serial_error_do_unknown         ; 199
    goto        serial_error_do_unknown         ; 200
    goto        serial_error_do_unknown         ; 201
    goto        serial_error_do_unknown         ; 202
    goto        serial_error_do_unknown         ; 203
    goto        serial_error_do_unknown         ; 204
    goto        serial_error_do_unknown         ; 205
    goto        serial_error_do_unknown         ; 206
    goto        serial_error_do_unknown         ; 207
    goto        serial_error_do_unknown         ; 208
    goto        serial_error_do_unknown         ; 209
    goto        serial_error_do_unknown         ; 210
    goto        serial_error_do_unknown         ; 211
    goto        serial_error_do_unknown         ; 212
    goto        serial_error_do_unknown         ; 213
    goto        serial_error_do_unknown         ; 214
    goto        serial_error_do_unknown         ; 215
    goto        serial_error_do_unknown         ; 216
    goto        serial_error_do_unknown         ; 217
    goto        serial_error_do_unknown         ; 218
    goto        serial_error_do_unknown         ; 219
    goto        serial_error_do_unknown         ; 220
    goto        serial_error_do_unknown         ; 221
    goto        serial_error_do_unknown         ; 222
    goto        serial_error_do_unknown         ; 223
    goto        serial_error_do_unknown         ; 224
    goto        serial_error_do_unknown         ; 225
    goto        serial_error_do_unknown         ; 226
    goto        serial_error_do_unknown         ; 227
    goto        serial_error_do_unknown         ; 228
    goto        serial_error_do_unknown         ; 229
    goto        serial_error_do_unknown         ; 230
    goto        serial_error_do_unknown         ; 231
    goto        serial_error_do_unknown         ; 232
    goto        serial_error_do_unknown         ; 233
    goto        serial_error_do_unknown         ; 234
    goto        serial_error_do_unknown         ; 235
    goto        serial_error_do_unknown         ; 236
    goto        serial_error_do_unknown         ; 237
    goto        serial_error_do_unknown         ; 238
    goto        serial_error_do_unknown         ; 239
    goto        serial_error_do_unknown         ; 240
    goto        serial_error_do_unknown         ; 241
    goto        serial_error_do_unknown         ; 242
    goto        serial_error_do_unknown         ; 243
    goto        serial_error_do_unknown         ; 244
    goto        serial_error_do_unknown         ; 245
    goto        serial_error_do_unknown         ; 246
    goto        serial_error_do_unknown         ; 247
    goto        serial_error_do_unknown         ; 248
    goto        serial_error_do_unknown         ; 249
    goto        serial_error_do_unknown         ; 250
    goto        serial_error_do_unknown         ; 251
    goto        serial_error_do_unknown         ; 252
    goto        serial_error_do_unknown         ; 253
    goto        serial_error_do_unknown         ; 254
    goto        serial_error_do_unknown         ; 255

serial_do_get_reset
    ; run the get_reset subroutine and return success
    call        get_reset
    call        serial_do_ack
    goto        serial_handler_exit

serial_do_get_dma
    call        get_dma
    call        serial_do_ack
    goto        serial_handler_exit

serial_do_get_slave
    call        get_slave
    call        serial_do_ack
    goto        serial_handler_exit

serial_do_reset
    ; special case, send ack then perform a CPU reset
    call        serial_do_ack

serial_do_reset_loop
    ; need to wait here until the UART has finished sending the two bytes
    ; that are in the shift register and transmit buffer
    btfss       TXSTA,TRMT
    bra         serial_do_reset_loop
    ; TSR is now empty, can safely do reset.

    reset

serial_do_ack
    clrf        FSR0L
    movlw       0x09
    movwf       POSTINC0
    movwf       TX_CHECKSUM

    movlw       0x01
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f

; no need to copy this from one pointer to the other because it's now the
; same byte :D
;    movlw       0x02
;    movwf       FSR0L
;    movf        INDF0,w
;    movwf       POSTINC1
    movf        POSTINC0, w     
    xorwf       TX_CHECKSUM,f

    movf        TX_CHECKSUM,w
    movwf       POSTINC0

    call        serial_tx_send_packet

    return

; -- serial error functions ---------------------------------------------------

serial_error_checksum
    ; report a message received with a bad checksum
    ; special first character because we don't know if the command was corrupt
    ; or data following it so start with a "0"
    ; set the send pointer to the start of the buffer
    clrf        FSR0L
    movlw       0x80
    movwf       POSTINC0
    movwf       TX_CHECKSUM
    ; next is length byte.  checksum fail message is always 3 bytes
    movlw       0x03
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    ; now is the error code.  checksum fail = 0x0001
    movlw       0x00
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    movlw       0x01
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    ; now send the calculated checksum for debugging
    movf        RX_CHECKSUM,w
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    ; now add the checksum
    movf        TX_CHECKSUM,w
    movwf       POSTINC0
    
    ; packet assembled, send the packet
    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_error_bad_command
    ; report a bad command i.e. byte outside [A-Z]
    ; set the send pointer to the start of the buffer
    clrf        FSR0L
    movlw       0x81     ; bad command so can't do the normal upper/lower conversion
    movwf       POSTINC0
    movwf       TX_CHECKSUM
    ; next is length byte.  always 3 bytes for bad command
    movlw       0x03
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    ; now is the error code.  bad command = 0x0002
    movlw       0x00
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    movlw       0x02
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    ; now send the bad command for debug
    movf        RX_COMMAND,w
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    ; finally add the checksum
    movf        TX_CHECKSUM,w
    movwf       POSTINC0

    ; packet assembled, send the packet
    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_error_unused_command
    ; valid command letter but not used
    ; set the send pointer to the start of the buffer
    clrf        FSR0L
    ; command code is same with bit 6 set
    movf        RX_COMMAND,w
    bsf         WREG,6          ; set bit 6, the error flag
    movwf       POSTINC0
    movwf       TX_CHECKSUM
    ; now the length only the error code now
    movlw       0x02
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    ; now the error code 0x0003 for unused command
    movlw       0x00
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    movlw       0x03
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    ; now the checksum
    movf        TX_CHECKSUM,w
    movwf       POSTINC0

    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_error_wrong_parameters
    ; valid command but got the wrong number of parameters
    clrf        FSR0L
    ; command code with bit 6 set
    movf        RX_COMMAND,w
    bsf         WREG,6
    movwf       POSTINC0
    movwf       TX_CHECKSUM
    ; now the length, error code plus the expected number of params
    movlw       0x03
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    ; now the error code 0x0004
    movlw       0x00
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    movlw       0x04
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    ; now the correct number of argument bytes
    movf        MAIN_TEMP,w
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f
    ; now the checksum
    movf        TX_CHECKSUM,w
    movwf       POSTINC0

    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_error_do_unknown
    movlw       0x02
    movwf       FSR0L
    movf        INDF0, w
    movwf       MAIN_TEMP
    
    clrf        FSR0L
    movlw       0x49
    movwf       POSTINC0
    movwf       TX_CHECKSUM

    movlw       0x03
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f

    movlw       0x00
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f

    movlw       0x09
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f

    movf        MAIN_TEMP,w
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f

    movf        TX_CHECKSUM,w
    movwf       POSTINC0

    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_error_packet_length
    movlw       0x05
    movwf       MAIN_TEMP
    goto        serial_error_generic

serial_error_bios_address_space
    movlw       0x06
    movwf       MAIN_TEMP
    goto        serial_error_generic

serial_error_bios_address_offset
    movlw       0x07
    movwf       MAIN_TEMP
    goto        serial_error_generic

serial_error_generic
    clrf        FSR0L
    movf        RX_COMMAND,w
    bsf         WREG,6
    movwf       POSTINC1
    movwf       TX_CHECKSUM

    movlw       0x02
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f

    movlw       0x00
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,f

    movf        MAIN_TEMP,w
    movwf       POSTINC0
    xorwf       TX_CHECKSUM,w

    movwf       POSTINC0

    call        serial_tx_send_packet

    goto        serial_handler_exit

serial_handler_exit
    ; standard exit for all serial response functions
    clrf        FSR0L           ; reset RX pointer
    clrf        RX_FLAGS        ; get rid of any flags from this message
    clrf        rx_mode         ; go back to waiting
    return

; == Export Direct Access to ==================================================

    GLOBAL      serial_init
    GLOBAL      serial_rx_int
    GLOBAL      serial_command_dispatch

end