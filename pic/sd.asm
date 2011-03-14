list p=18f4520
include <p18f4520.inc>
include "portpins.inc"

; -- Externals From host_bus.asm -----------------------------------------------

    EXTERN      slave_count

    EXTERN      io_write
    EXTERN      DREG
    EXTERN      LO_ADDR
    EXTERN      HI_ADDR

    EXTERN      ensure_master
    EXTERN      revert_master

    UDATA
count           res     2
sdflags         res     1
v2              equ     0
carderr         equ     1
cardinit        equ     2
init_started     equ     3

sd_command      res     1
sd_data         res     4
; MAIN_TEMP       res     1
temp2           res     1
; low_jump        res     1
sd_bus_block_size       res     1       ; used to store the block size for
                                        ; transfer to the Z80
    CODE

sd_init
    bsf         LATC, P_SD_CS           ; cs pin high
    bcf         TRISC, P_SD_CS          ; cs pin as output
    bcf         TRISC, P_SD_DO
    bcf         TRISC, P_SD_CK
    bsf         TRISC, P_SD_DI

    movlw       b'00000000'
    movwf       SSPSTAT
    movlw       b'00110000'
    movwf       SSPCON1

    clrf        sdflags

    movlw       b'00000110'
    movwf       T0CON                   ; setup timer 0 for 16 bit mode with
                                        ; 128 prescale, takes ~ 0.8s to timeout
    return                              ; used as a guard in sd routines

sd_card_init
    movlw       0x10
    movwf       count
sd_card_init_loop
    call        read_spi
    decfsz      count, f
    bra         sd_card_init_loop

; version 2 SD driver, supports HCSD
; send CMD0 with correct checksum

    bcf         LATC, P_SD_CS
    
    movlw       0x40                    ; cmd0
    movwf       sd_command
    clrf        sd_data
    clrf        sd_data+1
    clrf        sd_data+2
    clrf        sd_data+3

    call        write_sd
    
    call        start_timeout           ; start the timer
nloop
    btfsc       INTCON, TMR0IF
    goto        sd_timeout
    call        read_spi                 ; get a non 0xff byte
    
    bcf         T0CON, TMR0ON           ; stop the timer

    xorlw       0x01
    btfss       STATUS, Z
    bra         nloop

    movlw       0x48
    movwf       sd_command
    clrf        sd_data+3
    clrf        sd_data+2
    movlw       0x01
    movwf       sd_data+1
    movlw       0xAA
    movwf       sd_data

    call        write_sd

    call        start_timeout
    call        read_sd
    bcf         T0CON, TMR0ON

    bcf         sdflags, v2
    btfsc       WREG, 2
    bra         not_hcsd                ; if bit 2 is set then it's a type 1
                                        ; card hence doesn't support CMD8
    call        read_spi
    call        read_spi
    call        read_spi
    xorlw       0x01
    bnz         error_exit
    call        read_spi
    xorlw       0xaa
    bnz         error_exit

    bsf         sdflags, v2

not_hcsd
    call        start_timeout
sd_acmd41
    ; now poll until the card is ready
    movlw       0xE9                    ; cmd41 | 0x80 to signify ACMD
    movwf       sd_command
    movlw       0x00
    btfsc       sdflags, v2
    movlw       0x40
    movwf       sd_data+3
    clrf        sd_data+2
    clrf        sd_data+1
    clrf        sd_data

    call        write_sd

    call        read_sd

    xorlw       0x01
    bz          sd_acmd41

    bsf         sdflags, cardinit
    bcf         T0CON, TMR0ON
    bsf         LATC, P_SD_CS
    return                              ; all done

sd_timeout
    btfsc       sdflags, init_started   ; if this is in the init Z80 doesn't
    bra         sd_timeout_nr           ; know about it, don't send a response
    xorlw       0xff                    ; otherwise, correct for the last xor
    movwf       temp2                   ; save the value

    clrf        FSR2L                   ; initialise the response buffer pointer
    movlw       0x03
    movwf       FSR2H
    movlw       'T'                     ; set first character T for timeout
    movwf       POSTINC2
    movf        sd_command, w           ; add the last command sent to the SD
    movwf       POSTINC2
    movf        temp2, w                ; add the last response before timeout
    movwf       POSTINC2

sd_timeout_nr
    bsf         sdflags, carderr        ; set the error flag
    bsf         LATC, P_SD_CS           ; and release the SD
    return

error_exit
    btfsc       sdflags, init_started   ; don't send a report if in auto-init
    bra         error_exit_nr
    movwf       temp2                   ; save the error code from the SD

    clrf        FSR2L
    movlw       0x03
    movwf       FSR2H
    movlw       'E'                     ; start with E for error
    movwf       POSTINC2
    movf        sd_command, w           ; add the last command sent to SD
    movwf       POSTINC2
    movf        temp2, w                ; add the error response
    movwf       POSTINC2

error_exit_nr
    bsf         sdflags, carderr        ; cleared when card removed
    bsf         LATC, P_SD_CS
    return

sd_card_csd
    bcf         LATC, P_SD_CS

    movlw       0x49
    movwf       sd_command
    clrf        sd_data+3
    clrf        sd_data+2
    clrf        sd_data+1
    clrf        sd_data

    call        write_sd

    call        start_timeout
    call        read_sd
    bcf         T0CON, TMR0ON

    xorlw       0x00
    bnz         error_exit

    call        start_timeout
    call        read_sd
    bcf         T0CON, TMR0ON

    xorlw       0xFE
    bnz         error_exit

    movlw       0x10
    movwf       count

sd_card_csd_loop
    call        read_spi
    movwf       POSTINC2
    decfsz      count,f
    bra         sd_card_csd_loop

    bsf         LATC, P_SD_CS
    return

sd_card_cid
    bcf         LATC, P_SD_CS

    movlw       0x4A
    movwf       sd_command

    clrf        sd_data+3
    clrf        sd_data+2
    clrf        sd_data+1
    clrf        sd_data

    call        write_sd

    call        start_timeout
    call        read_sd
    bcf         T0CON, TMR0ON

    xorlw       0x00
    bnz         error_exit

    call        start_timeout
    call        read_sd
    bcf         T0CON, TMR0ON

    xorlw       0xFE
    bnz         error_exit

    movlw       0x10
    movwf       count

sd_card_cid_read_loop
    call        read_spi
    movwf       POSTINC2
    decfsz      count, f
    bra         sd_card_cid_read_loop

    bsf         LATC, P_SD_CS
    return

start_timeout
    clrf        TMR0H
    clrf        TMR0L
    bsf         T0CON, TMR0ON           ; start timeout
    bcf         INTCON, TMR0IF
    return

;===============================================================================
; sd_card_read_block - Reads a 512 byte block from the SD card into memory.
;===============================================================================

;; Issues the read a single block command to the SD card.  Assuming this returns
;; a valid response, 512 bytes of data are then read and stored as well as two
;; checksum bytes from the SD.  Data is stored in indirect register 2.  This
;; must be set-up preceding the call to this function.

sd_card_read_block
    bcf         LATC, P_SD_CS

    movlw       0x51                    ; CMD17 - read a single block
    movwf       sd_command

    ; assume address already set

    call        write_sd

    call        start_timeout           ; wait for the busy signal to end
    call        read_sd
    bcf         T0CON, TMR0ON

    xorlw       0x00                    ; make sure it was a no-error response
    bnz         error_exit

    call        start_timeout           ; make sure we don't hang waiting for
sd_card_read_block_wait                 ; data
    call        read_sd
    bcf         T0CON, TMR0ON

    xorlw       0xFE
    bnz         sd_card_read_block_wait ; wait for a data token

    movlw       0x01                    ; set count to 514-1 bytes (512 data and
    movwf       count                   ; two checksum)
    movlw       0x02
    movwf       count+1

sd_card_read_block_loop
    call        read_spi                ; get a byte
    movwf       POSTINC2                ; store it in pointer block 2
    decf        count, f
    btfsc       STATUS, C               ; skips if count overflowed
    bra         sd_card_read_block_loop
    decf        count+1, f              ; skips if high count overflowed too
    btfsc       STATUS, C
    bra         sd_card_read_block_loop

    bsf         LATC, P_SD_CS           ; de-select SD card, more for effect
                                        ; with the activity light as it won't
                                        ; release SPI unless clocked a few times
    return

;===============================================================================
; sd_card_poll - called in the main loop, checks the card detect pin
;===============================================================================

;; If the card detect pin is low and the init flag is clear, calls init.  If
;; card detect pin is high (no card) clears all flags.
sd_card_poll
    btfsc       PORTB, P_SD_FIND
    bra         sd_card_removed

    ; sd attached, check it's init or err state
    movlw       0x6
    andwf       sdflags, w
    btfss       STATUS, Z
    ; not zero so already been started, return
    return

    btfsc       sdflags, init_started
    bra         sd_init_timeout
    call        start_timeout
    bsf         sdflags, init_started
    return

sd_init_timeout
    btfsc       INTCON, TMR0IF
    bra         sd_do_init
    ; debounce time not up
    return

sd_do_init
    ; disable timer
    bcf         T0CON, TMR0ON
    call        sd_card_init
    btfsc       sdflags, cardinit
    bcf         LATB, P_SD_PRES         ; tell Z80 there's a started card here

    ; clear the init timer
    bcf         sdflags, init_started
    return

sd_card_removed
    clrf        sdflags
    bsf         LATB, P_SD_PRES         ; signal sd removed
    return

;-------------------------------------------------------------------------------
; read_sd - internal mid-level read from SD
;-------------------------------------------------------------------------------
read_sd
    btfsc       INTCON, TMR0IF
    goto        sd_timeout
    call        read_spi
    xorlw       0xff
    bz          read_sd
    xorlw       0xff
    return

;-------------------------------------------------------------------------------
; write_sd - internal mid-level write a command to SD
;-------------------------------------------------------------------------------
write_sd
    ; test for an ACMD41
    btfsc       sd_command, 7
    call        sd_cmd55

    call        read_spi
    movf        sd_command, w
    andlw       0x7F
    call        write_spi

    ; now the 32 bit data
    movf        sd_data+3, w
    call        write_spi
    movf        sd_data+2, w
    call        write_spi
    movf        sd_data+1, w
    call        write_spi
    movf        sd_data, w
    call        write_spi

    ; now the checksum, might need to be a real one
    call        sd_get_checksum
    call        write_spi

    return

; send the special command 55 which preceeds ACMD codes
sd_cmd55
    call        read_spi
    movlw       0x77
    call        write_spi
    movlw       0x00
    call        write_spi
    movlw       0x00
    call        write_spi
    movlw       0x00
    call        write_spi
    movlw       0x00
    call        write_spi
    movlw       0x01
    call        write_spi

    call        read_sd
    andlw       0x7e
    btfss       STATUS, Z
    goto        error_exit                      ; if it was not zero an error
                                                ; flag was set
    return

sd_get_checksum
    movlw       0x40            ; cmd0
    xorwf       sd_command, w
    btfsc       STATUS, Z
    retlw       0x95
    movlw       0x48            ; cmd8
    xorwf       sd_command, w
    btfsc       STATUS, Z
    retlw       0x87
    ; neither of those, so don't care
    retlw       0x01

;-------------------------------------------------------------------------------
; read_spi - internal low-level read a byte from SPI
;-------------------------------------------------------------------------------

read_spi
    setf        SSPBUF
read_spi_loop
    btfss       SSPSTAT, BF
    bra         read_spi_loop
    movf        SSPBUF, w
    return

;-------------------------------------------------------------------------------
; write_spi - internal low-level write a byte to the SPI peripheral
;-------------------------------------------------------------------------------

write_spi
    movwf       SSPBUF
write_spi_loop
    btfss       SSPSTAT, BF
    bra         write_spi_loop
    movf        SSPBUF, w
    return

; -- Export these --------------------------------------------------------------

    GLOBAL      sd_init
    GLOBAL      sd_card_csd
    GLOBAL      sd_card_cid
    GLOBAL      sd_card_poll
    GLOBAL      sd_card_read_block
    
    GLOBAL      sd_data
    GLOBAL      sd_bus_block_size

end