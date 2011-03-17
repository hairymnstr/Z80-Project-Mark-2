;==============================================================================
;    host_bus.asm
;==============================================================================
list p=18f4520
include <p18f4520.inc>
include <portpins.inc>

; -- Externals From eeprom.asm -------------------------------------------------

    EXTERN      eeprom_read
    EXTERN      eeprom_write

    EXTERN      eeprom_data
    EXTERN      eeprom_addr

; -- Externals From sd.asm -----------------------------------------------------

    EXTERN      sd_card_cid
    EXTERN      sd_card_csd
    EXTERN      sd_card_read_block

    EXTERN      sd_data

    EXTERN      sd_bus_block_size

    UDATA
carderr           equ   1

LO_ADDR RES     1
HI_ADDR RES     1
DREG    RES     1

MODE            RES     1
TEMP_MODE       RES     1

low_jump        res     1

slave_latb_temp         res     1
slave_trisb_temp        res     1

slave_count             res     2
slaveflags              res     1

busy                    equ     0
rxbytes                 equ     1
txbytes                 equ     2

FSR2L_DEF       equ 0xC0
    CODE

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
    call        get_slave
    return

revert_master_reset
    call        get_reset       ; assert the reset line
    return

revert_master_dma
    call        get_dma         ; get DMA control
    return


get_dma
    ; save state of slave registers
    movff       LATB, slave_latb_temp
    movff       TRISB, slave_trisb_temp
    bcf         LATA,1          ; assert the BUSRQ signal low
get_dma_loop
    btfsc       PORTC,0         ; wait for BUSACK to go low
    bra         get_dma_loop
    movlw       0x02
    movwf       MODE            ; set mode to DMA master
    call        set_master
    return

get_reset
    bcf         LATA,0          ; pull reset low

    ; while waiting for the Z80 M cycle to end, reset the slave device settings
    movlw       SLAVE_LATB_DEF
    movwf       slave_latb_temp
    movlw       SLAVE_TRISB_DEF
    movwf       slave_trisb_temp
    clrf        slave_count
    clrf        slave_count+1
    clrf        slaveflags
    nop                         ; leave time for the M cycle to finish
    movlw       0x01
    movwf       MODE
    call        set_master
    return

get_slave
    clrf        MODE            ; set mode to slave
    call        set_slave       ; set IO into slave mode
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
    ; disable PSP interrupts
    bcf         PIE1, PSPIE
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
    movff       slave_latb_temp, LATB
    movff       slave_trisb_temp, TRISB
;     setf        TRISB
    movlw       b'00010111'     ; PSP mode
    iorwf       TRISE, f
    setf        LATA            ; all pins in A are high or don't care
    movlw       b'11001100'     ; MREQ, IORQ input
    movwf       TRISA

    ; now enable PSP interrupt
    bcf         PIR1, PSPIF
    bsf         PIE1, PSPIE
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

; == Slave mode code ===========================================================

;===============================================================================
; slave_int - interrupt generated by the PSP
;===============================================================================

;; This splits into two blocks of code, read and write.
;;
;; Write: if the Z80 wrote a byte, see if we are expecting bytes (TXE low), if
;; so then check if it's the first byte, in this case we need to update the byte
;; counters for this command based on the command length.  Otherwise, store the
;; byte and check if it was the last.  If it was set the busy flag, and let the
;; main-loop command dispatcher prepare a response.
;;
;; Read: if the Z80 read a byte, look at the state of the response count.  If
;; there are any bytes left put the next one in the output latch and set RXF to
;; signal more data, otherwise return to "waiting for command" mode.

slave_int
    ; what mode are we in?
    btfsc       slaveflags, busy
    bra         slave_ignore_event      ; don't do anything if busy
    btfsc       slaveflags, txbytes
    bra         slave_tx
    btfsc       slaveflags, rxbytes
    bra         slave_rx
    ; if it's none of them, must be idle
    btfsc       TRISE, IBF
    bra         slave_rx

    ; the Z80 read a byte from the PSP, need to reload it if there's data
slave_tx
    ; check if this was a read event
    btfsc       TRISE, IBF
    goto        slave_ignore_event      ; if it was a write ignore it
    bsf         LATB, P_RXF             ; nothing to read for a min!!
    bsf         slaveflags, txbytes     ; set the txmode flag
    call        slave_check_byte0
    xorlw       0x00
    btfsc       STATUS, Z
    goto        slave_go_idle           ; go into idle mode
    ; not the last byte just read, so put another in output
    movf        POSTINC2, w             ; get a byte from the fifo
    movwf       PORTD                   ; put it in the output buffer
    dcfsnz      slave_count, f          ; decrement the remaining byte count
    decf        slave_count+1, f        ; decrement high byte if low is zero
    bcf         LATB, P_RXF             ; set the flag to say there's more data
    bcf         PIR1, PSPIF             ; clear the interrupt flag
    return

slave_go_idle
    bcf         slaveflags, txbytes
    bcf         slaveflags, rxbytes
    ; busy can only be cleared in the main loop
    bcf         PIR1, PSPIF
    bcf         LATB, P_TXE     ; let the Z80 talk again
    return

slave_rx
    ; see if this was actually a write
    btfss       TRISE, IBF
    bra         slave_ignore_event      ; if it was a read ignore it
    ; set the TXE bit until we're finished processing
    bsf         LATB, P_TXE
    btfsc       slaveflags, rxbytes     ; see if we're already in rx mode
    bra         slave_rx_data

    ; if not do setup work
    ; setup the rx register
    clrf        FSR2H
    movlw       FSR2L_DEF
    movwf       FSR2L
    movf        PORTD, w
    movwf       POSTINC2

    ; this is the first byte so setup the counter etc.
    clrf        TBLPTRH
    rlncf       WREG, w                 ; 16 bit lookup, multiply 2
    addlw       low slave_command_lengths
;     addwf       PORTD, w
    btfsc       STATUS, C
    incf        TBLPTRH, f
    movwf       TBLPTRL
    movlw       high slave_command_lengths
    addwf       TBLPTRH, f
    clrf        TBLPTRU
    tblrd*+
    movff       TABLAT, slave_count     ; low byte first
    tblrd*
    movff       TABLAT, slave_count+1   ; then high byte

    ; set the rxmode flag
    bsf         slaveflags, rxbytes

    ; byte is already in buffer, so skip saving again
    bra         slave_rx_data_done

slave_rx_data
    ; save the actual byte received
    movf        PORTD, w
    movwf       POSTINC2

slave_rx_data_done
    ; see if the byte count is down to zero yet
    call        slave_check_byte0
    xorlw       0x00
    bz          slave_start_processing          ; if it's zero process the cmd
    ; it's not zero yet so decrement the counter
    dcfsnz      slave_count, f
    decf        slave_count+1, f                ; if low byte is zero dec upper

    bcf         PIR1, PSPIF                     ; clear the interrupt
    bcf         LATB, P_TXE                     ; let the Z80 send the next byte
    return

slave_start_processing
    ; got a whole command in the buffer
    bcf         slaveflags, rxbytes
    bsf         slaveflags, busy                ; signal the main process
    bcf         PIR1, PSPIF
    ; don't clear either of the talk/listen flags until we're done
    return

slave_ignore_event
    ; it was an event we're not interested in or can't deal with now
    ; just clear the interrupt and get back to work
    bcf         PIR1, PSPIF
    return

;===============================================================================
; slave_command_dispatch - if there are any commands waiting to be serviced do
;                               them, otherwise return immediately
;===============================================================================

slave_command_dispatch
    btfss       slaveflags, busy
    return                              ; no commands to deal with
    ; there's a new command to deal with.  First reset the pointer
    clrf        FSR2H
    movlw       FSR2L_DEF
    movwf       FSR2L

    ; now get the command byte and do a jump
    movlw       high slave_cmd_table
    movwf       PCLATH
    movf        INDF2, w
    andlw       0x3F
    rlncf       WREG, w
    rlncf       WREG, w
    addlw       low slave_cmd_table
    btfsc       STATUS,C
    incf        PCLATH, f
    movwf       PCL

;===============================================================================
; slave_cmd_table - 64 command lookup table for commands from Z80
;===============================================================================

slave_cmd_table
    goto        slave_unused_command    ; 0
    goto        slave_unused_command    ; 1
    goto        slave_unused_command    ; 2
    goto        slave_unused_command    ; 3
    goto        slave_unused_command    ; 4
    goto        slave_unused_command    ; 5
    goto        slave_unused_command    ; 6
    goto        slave_unused_command    ; 7
    goto        slave_unused_command    ; 8
    goto        slave_unused_command    ; 9
    goto        slave_command_read_eeprom    ; 10
    goto        slave_command_write_eeprom    ; 11
    goto        slave_unused_command    ; 12
    goto        slave_unused_command    ; 13
    goto        slave_unused_command    ; 14
    goto        slave_unused_command    ; 15
    goto        slave_unused_command    ; 16
    goto        slave_unused_command    ; 17
    goto        slave_unused_command    ; 18
    goto        slave_unused_command    ; 19
    goto        slave_unused_command    ; 20
    goto        slave_unused_command    ; 21
    goto        slave_unused_command    ; 22
    goto        slave_unused_command    ; 23
    goto        slave_unused_command    ; 24
    goto        slave_unused_command    ; 25
    goto        slave_unused_command    ; 26
    goto        slave_unused_command    ; 27
    goto        slave_unused_command    ; 28
    goto        slave_unused_command    ; 29
    goto        slave_unused_command    ; 30
    goto        slave_unused_command    ; 31
    goto        slave_command_card_cid    ; 32
    goto        slave_command_card_csd    ; 33
    goto        slave_command_read_sector    ; 34
    goto        slave_unused_command    ; 35
    goto        slave_unused_command    ; 36
    goto        slave_unused_command    ; 37
    goto        slave_unused_command    ; 38
    goto        slave_unused_command    ; 39
    goto        slave_unused_command    ; 40
    goto        slave_unused_command    ; 41
    goto        slave_unused_command    ; 42
    goto        slave_unused_command    ; 43
    goto        slave_unused_command    ; 44
    goto        slave_unused_command    ; 45
    goto        slave_unused_command    ; 46
    goto        slave_unused_command    ; 47
    goto        slave_unused_command    ; 48
    goto        slave_unused_command    ; 49
    goto        slave_unused_command    ; 50
    goto        slave_unused_command    ; 51
    goto        slave_unused_command    ; 52
    goto        slave_unused_command    ; 53
    goto        slave_unused_command    ; 54
    goto        slave_unused_command    ; 55
    goto        slave_unused_command    ; 56
    goto        slave_unused_command    ; 57
    goto        slave_unused_command    ; 58
    goto        slave_unused_command    ; 59
    goto        slave_unused_command    ; 60
    goto        slave_unused_command    ; 61
    goto        slave_unused_command    ; 62
    goto        slave_command_reset     ; 63

slave_unused_command
    ; dummy incase a bad command was sent
    bcf         slaveflags, busy
    bcf         slaveflags, txbytes
    bcf         slaveflags, rxbytes

    ; let the Z80 write, but not read
    bcf         LATB, P_TXE
    bsf         LATB, P_RXF

    ; in idle mode again, return to main loop
    return

slave_command_write_eeprom
    ; write a byte to the EEPROM non-volatile memory
    ; 3 byte sequence: command, address, data
    incf        FSR2L, f                ; ignore the command byte
    movff       POSTINC2, eeprom_addr
    movff       POSTINC2, eeprom_data

    call        eeprom_write

    bcf         slaveflags, busy
    bcf         slaveflags, txbytes
    bcf         slaveflags, rxbytes

    bsf         LATB, P_RXF
    bcf         LATB, P_TXE
    return

;-------------------------------------------------------------------------------
; slave_command_read_eeprom - read a byte from eeprom and return it
;-------------------------------------------------------------------------------
slave_command_read_eeprom
    ; read a byte from the NV eeprom memory
    ; two bytes: command, addr
    incf        FSR2L, f                ; ignore the command
    movff       POSTINC2, eeprom_addr

    call        eeprom_read             ; read a byte

    movwf       PORTD                   ; put the data in the output buffer

    clrf        slave_count
    clrf        slave_count+1           ; this is the last byte

    bcf         slaveflags, busy
    bcf         slaveflags, rxbytes
    bsf         slaveflags, txbytes     ; in tx mode ignore all else until read

    bsf         LATB, P_TXE             ; don't write
    bcf         LATB, P_RXF             ; do read!!

    return

;-------------------------------------------------------------------------------
; slave_command_read_sector - read a sector from the SD card
;-------------------------------------------------------------------------------
slave_command_read_sector
    ; run sd_card_init and respond with the output
    incf        FSR2L, f        ; ignore the command
    movff       POSTINC2, sd_data
    movff       POSTINC2, sd_data+1
    movff       POSTINC2, sd_data+2
    movff       POSTINC2, sd_data+3     ; select the block

    clrf        FSR2H
    movlw       FSR2L_DEF
    movwf       FSR2L

    ; set first byte to okay, changed on error
    movlw       'O'
    movwf       POSTINC2

    call        sd_card_read_block

    ; response is always 515 bytes - ack, 512 data, 2 crc
    movlw       0x03
    movwf       slave_count+1
    movlw       0x03
    movwf       slave_count

    movlw       FSR2L_DEF
    movwf       FSR2L
    clrf        FSR2H
    movf        POSTINC2, w
    movwf       PORTD
    decf        slave_count, f

    bcf         slaveflags, busy
    bcf         slaveflags, rxbytes
    bsf         slaveflags, txbytes

    bcf         LATB, P_RXF
    bsf         LATB, P_TXE

    return

;-------------------------------------------------------------------------------
; slave_command_card_cid - get the CID data from the attached SD card
;-------------------------------------------------------------------------------
slave_command_card_cid
    clrf        FSR2H
    movlw       FSR2L_DEF
    movwf       FSR2L

    ; set first byte of response to O for okay, overwritten by error routines
    movlw       'O'
    movwf       POSTINC2
    call        sd_card_cid


    ; Z80 expects this number of bytes
    movlw       0x11
    movwf       slave_count
    movlw       0x01
    movwf       slave_count+1

    movlw       FSR2L_DEF
    movwf       FSR2L
    movf        POSTINC2, w
    movwf       PORTD
    decf        slave_count, f

    bcf         slaveflags, busy
    bcf         slaveflags, rxbytes
    bsf         slaveflags, txbytes

    bcf         LATB, P_RXF
    bsf         LATB, P_TXE

    return

;-------------------------------------------------------------------------------
; slave_command_card_csd - get the CSD data from the attached SD card
;-------------------------------------------------------------------------------
slave_command_card_csd
    clrf        FSR2H
    movlw       FSR2L_DEF
    movwf       FSR2L

    ; put O at the start of the response.  This gets overwritten by errors
    movlw       'O'
    movwf       POSTINC2
    call        sd_card_csd

    ; whatever happens the data we return must be 17 bytes
    movlw       0x11
    movwf       slave_count
    movlw       0x01
    movwf       slave_count+1

    movlw       FSR2L_DEF
    movwf       FSR2L
    movf        POSTINC2, w
    movwf       PORTD
    decf        slave_count, f

    bcf         slaveflags, busy
    bcf         slaveflags, rxbytes
    bsf         slaveflags, txbytes

    bcf         LATB, P_RXF
    bsf         LATB, P_TXE

    return

;-------------------------------------------------------------------------------
; slave_command_card_set_block_size - set the block size to the requested amount
;-------------------------------------------------------------------------------
slave_command_card_set_block_size
    incf        FSR2L,f         ; ignore the command byte
    movf        INDF2, w        ; going to need to test this a few times so
                                ; don't move the pointer
    xorlw       0x01            ; test to see if it's a valid size
    bz          slave_command_card_set_block_size_okay

    movf        INDF2, w        ; test against the next valid size
    xorlw       0x02
    bz          slave_command_card_set_block_size_okay

    movf        INDF2, w
    xorlw       0x04
    bz          slave_command_card_set_block_size_okay

    ; if the execution has got here then there was a size we can't deal with
    movlw       FSR2L_DEF
    movwf       FSR2L
    movlw       'E'
    movwf       PORTD
    goto        slave_command_card_set_block_size_done

slave_command_card_set_block_size_okay
    ; the value we've been given is valid.  From now on all block request
    ; addresses and byte counts will be based on this value
    movf        INDF2, w
    movwf       sd_bus_block_size

    ; return a single 'O' to indicate that the operation succeeded
    movlw       FSR2L_DEF
    movwf       FSR2L
    movlw       'O'
    movwf       PORTD

slave_command_card_set_block_size_done
    clrf        slave_count
    clrf        slave_count+1

    bcf         slaveflags, busy
    bcf         slaveflags, rxbytes
    bsf         slaveflags, txbytes

    bcf         LATB, P_RXF
    bsf         LATB, P_TXE

    return

slave_command_reset
    ; reset the whole system
    reset

;-------------------------------------------------------------------------------
; slave_check_byte0 - returns 0 in w if the current byte number is zero
;-------------------------------------------------------------------------------
slave_check_byte0
    movf        slave_count+1, w
    xorlw       0x00
    btfss       STATUS,Z
    retlw       0xff
    movf        slave_count, w
    xorlw       0x00
    btfss       STATUS, Z
    retlw       0xff
    retlw       0x00

slave_command_lengths
    db          0x00, 0x00                      ;  0 (0x00): none
    db          0x00, 0x00                      ;  1 (0x01): none
    db          0x00, 0x00                      ;  2 (0x02): none
    db          0x00, 0x00                      ;  3 (0x03): none
    db          0x00, 0x00                      ;  4 (0x04): none
    db          0x00, 0x00                      ;  5 (0x05): none
    db          0x00, 0x00                      ;  6 (0x06): none
    db          0x00, 0x00                      ;  7 (0x07): none
    db          0x00, 0x00                      ;  8 (0x08): none
    db          0x00, 0x00                      ;  9 (0x09): none
    db          0x01, 0x01                      ; 10 (0x0A): read eeprom 1: addr
    db          0x02, 0x01                      ; 11 (0x0B): write eeprom 2: addr, data
    db          0x00, 0x00                      ; 12 (0x0C): none
    db          0x00, 0x00                      ; 13 (0x0D): none
    db          0x00, 0x00                      ; 14 (0x0E): none
    db          0x00, 0x00                      ; 15 (0x0F): none
    db          0x00, 0x00                      ; 16 (0x10): none
    db          0x00, 0x00                      ; 17 (0x11): none
    db          0x00, 0x00                      ; 18 (0x12): none
    db          0x00, 0x00                      ; 19 (0x13): none
    db          0x00, 0x00                      ; 20 (0x14): none
    db          0x00, 0x00                      ; 21 (0x15): none
    db          0x00, 0x00                      ; 22 (0x16): none
    db          0x00, 0x00                      ; 23 (0x17): none
    db          0x00, 0x00                      ; 24 (0x18): none
    db          0x00, 0x00                      ; 25 (0x19): none
    db          0x00, 0x00                      ; 26 (0x1A): none
    db          0x00, 0x00                      ; 27 (0x1B): none
    db          0x00, 0x00                      ; 28 (0x1C): none
    db          0x00, 0x00                      ; 29 (0x1D): none
    db          0x00, 0x00                      ; 30 (0x1E): none
    db          0x00, 0x00                      ; 31 (0x1F): none
    db          0x00, 0x00                      ; 32 (0x20): sd_card_cid, no data
    db          0x00, 0x00                      ; 33 (0x21): sd_card_csd, no data
    db          0x04, 0x01                      ; 34 (0x22): sd_card_read_block 4: addr
    db          0x00, 0x00                      ; 35 (0x23): none
    db          0x00, 0x00                      ; 36 (0x24): none
    db          0x00, 0x00                      ; 37 (0x25): none
    db          0x00, 0x00                      ; 38 (0x26): none
    db          0x00, 0x00                      ; 39 (0x27): none
    db          0x00, 0x00                      ; 40 (0x28): none
    db          0x00, 0x00                      ; 41 (0x29): none
    db          0x00, 0x00                      ; 42 (0x2A): none
    db          0x00, 0x00                      ; 43 (0x2B): none
    db          0x00, 0x00                      ; 44 (0x2C): none
    db          0x00, 0x00                      ; 45 (0x2D): none
    db          0x00, 0x00                      ; 46 (0x2E): none
    db          0x00, 0x00                      ; 47 (0x2F): none
    db          0x00, 0x00                      ; 48 (0x30): none
    db          0x00, 0x00                      ; 49 (0x31): none
    db          0x00, 0x00                      ; 50 (0x32): none
    db          0x00, 0x00                      ; 51 (0x33): none
    db          0x00, 0x00                      ; 52 (0x34): none
    db          0x00, 0x00                      ; 53 (0x35): none
    db          0x00, 0x00                      ; 54 (0x36): none
    db          0x00, 0x00                      ; 55 (0x37): none
    db          0x00, 0x00                      ; 56 (0x38): none
    db          0x00, 0x00                      ; 57 (0x39): none
    db          0x00, 0x00                      ; 58 (0x3A): none
    db          0x00, 0x00                      ; 59 (0x3B): none
    db          0x00, 0x00                      ; 60 (0x3C): none
    db          0x00, 0x00                      ; 61 (0x3D): none
    db          0x00, 0x00                      ; 62 (0x3E): none
    db          0x00, 0x00                      ; 63 (0x3F): reset, no data
; == Export these refs =========================================================

    GLOBAL      HI_ADDR
    GLOBAL      LO_ADDR
    GLOBAL      DREG

    GLOBAL      get_reset
    GLOBAL      get_dma
    GLOBAL      get_slave
    GLOBAL      ensure_master
    GLOBAL      revert_master
    GLOBAL      io_read
    GLOBAL      io_write
    GLOBAL      mem_read
    GLOBAL      mem_write
    GLOBAL      slave_int
    GLOBAL      slave_command_dispatch
    GLOBAL      slave_count
end