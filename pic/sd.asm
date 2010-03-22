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

;     movlw       low debugmsg1
;     movwf       TBLPTRL
;     movlw       high debugmsg1
;     movwf       TBLPTRH
;     clrf        TBLPTRU
;     call        msg

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

;     movlw       0x40
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x95
;     call        write_spi
    
    call        start_timeout           ; start the timer
nloop
    btfsc       INTCON, TMR0IF
    goto        sd_timeout
    call        read_spi                 ; get a non 0xff byte
    
    bcf         T0CON, TMR0ON           ; stop the timer

;     movwf       temp2
;     movlw       low debugmsg2
;     movwf       TBLPTRL
;     movlw       high debugmsg2
;     movwf       TBLPTRH
;     clrf        TBLPTRU
;     call        msg
;     movf        temp2, w
;     call        debug
;     movf        temp2, w
    xorlw       0x01
    btfss       STATUS, Z
    ;goto        error_exit              ; should be 0x01 - busy
    bra         nloop
;     movlw       0x55
;     call        debug

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
;     movlw       0x66
;     call        debug

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

;     movwf       temp2
;     movlw       low debugmsg3
;     movwf       TBLPTRL
;     movlw       high debugmsg3
;     movwf       TBLPTRH
;     clrf        TBLPTRU
;     call        msg
;     movf        temp2, w
;     call        debug
;     movf        temp2, w
    
;     clrf        count
;     clrf        count+1
; hold
;     decfsz      count, f
;     bra         hold
;     decfsz      count+1, f
;     bra         hold

    xorlw       0x01
    bz          sd_acmd41

;     movlw       low debugmsg4
;     movwf       TBLPTRL
;     movlw       high debugmsg4
;     movwf       TBLPTRH
;     clrf        TBLPTRU
;     call        msg

    bsf         sdflags, cardinit
    bcf         T0CON, TMR0ON
    bsf         LATC, P_SD_CS
    return                              ; all done

;     movlw       0x40
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x95
;     call        write_spi
; 
;     clrf        TMR0H
;     clrf        TMR0L
;     bsf         T0CON, TMR0ON           ; start timeout
;     bcf         INTCON, TMR0IF
; sd_card_init2
;     btfsc       INTCON, TMR0IF
;     goto        sd_timeout
;     call        read_spi
;     xorlw       0x01
;     bnz         sd_card_init2
;     ; stop timer
;     bcf         T0CON, TMR0ON
; 
; ; send CMD8 to see if it is HCSD
; 
; sd_card_cmd8
;     call        read_spi
;     movlw       0x48
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x01
;     call        write_spi
;     movlw       0xAA
;     call        write_spi
;     movlw       0x87
;     call        write_spi
; 
;     clrf        TMR0H
;     clrf        TMR0L
;     bsf         T0CON, TMR0ON           ; start timeout
;     bcf         INTCON, TMR0IF
; sd_card_check_cmd8
;     btfsc       INTCON, TMR0IF
;     goto        sd_timeout
;     call        read_spi
;     xorlw       0xff
;     bz          sd_card_check_cmd8
;     xorlw       0xff
; 
;     bcf         T0CON, TMR0ON           ; stop timer
; 
;     xorlw       0x01                    ; see if the first byte is 01
;     bnz         sdnc                    ; if not probably an old SD
;     call        read_spi                ; should be 00
;     call        read_spi                ; should be 00
;     call        read_spi                ; has to be 01
;     xorlw       0x01
;     bnz         error_exit
;     call        read_spi                ; has to be aa
;     xorlw       0xaa
;     bnz         error_exit
;     bsf         sdflags, v2             ; if it's a valid response this is a
;     bra         sd_card_enter_acmd41          ; mark2 card
; 
; sdnc
;     xorlw       0x04                    ; see if it responded "unknown command"
;     bnz         error_exit              ; if not something went wrong
; 
; 
; sd_card_enter_acmd41
;     clrf        TMR0H
;     clrf        TMR0L
;     bsf         T0CON, TMR0ON           ; start timeout
;     bcf         INTCON, TMR0IF
; sd_card_acmd41                          ; now initialise with acmd41
;     call        read_spi
;     movlw       0x77                    ; means send cmd55, then cmd41
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x01
;     call        write_spi
; 
; sd_card_ack_cmd55                       ; check cmd 55 was acknowledged
;     btfsc       INTCON, TMR0IF
;     goto        sd_timeout
;     call        read_spi
;     xorlw       0xff
;     bz          sd_card_ack_cmd55
;     xorlw       0xfe
;     bnz         error_exit              ; for mmc support ought to try cmd1 here
;                                         ; not really important in this day...
; 
;     call        read_spi
;     movlw       0x69                    ; cmd41
;     call        write_spi
;     movlw       0x00
;     btfsc       sdflags, v2             ; signal that we are HC capable if the
;     movlw       0x40                    ; card is a version 2, otherwise no need
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x01
;     call        write_spi
; 
; sd_card_init6
;     btfsc       INTCON, TMR0IF
;     goto        sd_timeout
;     call        read_spi
;     xorlw       0xff                    ; if response was ff, try again it was
;     bz          sd_card_init6           ; just a bit slow
;     xorlw       0xfe                    ; 0xff ^ 0xfe = 0x01 > see if still idle
;     bz          sd_card_acmd41          ; if so, poll again
;     xorlw       0x01                    ; 0xff ^ 0xfe ^ 0x01 = 0x00
;     btfss       STATUS, Z               ; if zero card is ready
;     bra         error_exit              ; if it's none of these something went
;                                         ; wrong, exit
;     bcf         T0CON, TMR0ON           ; turn off timeout
;     bsf         LATC, P_SD_CS           ; release chip select
;     bsf         sdflags, cardinit
;     return

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

;     call        read_spi
;     movlw       0x49
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x01
;     call        write_spi
; 
; sd_card_csd_loop
;     call        read_spi
;     xorlw       0x00
;     btfss       STATUS, Z
;     bra         sd_card_csd_loop
; 
; sd_card_csd_loop2
;     call        read_spi
;     xorlw       0xfe
;     bnz         sd_card_csd_loop2
;     
;     movlw       0x10
;     movwf       count
; 
; sd_card_csd_loop3
;     call        read_spi
;     movwf       POSTINC2
;     decfsz      count,f
;     bra         sd_card_csd_loop3
; 
;     movlw       0x01
;     movwf       slave_count+1
;     movlw       0x10
;     movwf       slave_count
;     bsf         LATC, P_SD_CS
;     return

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

    
;     call        read_spi
;     movlw       0x4A
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x00
;     call        write_spi
;     movlw       0x01
;     call        write_spi
; 
; sd_card_cid_loop
;     call        read_spi
;     xorlw       0x00
;     bnz         sd_card_cid_loop
; 
; sd_card_cid_loop2
;     call        read_spi
;     xorlw       0xfe
;     bnz         sd_card_cid_loop2

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

sd_card_read_block
    bcf         LATC, P_SD_CS

    movlw       0x51                    ; CMD17
    movwf       sd_command

    ; assume address already set

    call        write_sd

    call        start_timeout
    call        read_sd
    bcf         T0CON, TMR0ON

    xorlw       0x00
    bnz         error_exit

    call        start_timeout
sd_card_read_block_wait
    call        read_sd
    bcf         T0CON, TMR0ON

    xorlw       0xFE
    bnz         sd_card_read_block_wait ; wait for a data token

    movlw       0x01                    ; set count to 514-1 bytes (512 data and
    movwf       count                   ; two checksum)
    movlw       0x02
    movwf       count+1

sd_card_read_block_loop
    call        read_spi
    movwf       POSTINC2
    decf        count, f
    btfsc       STATUS, C               ; skips if count overflowed
    bra         sd_card_read_block_loop
    decf        count+1, f
    btfsc       STATUS, C
    bra         sd_card_read_block_loop

    bsf         LATC, P_SD_CS
    return

; push_z80
;     movwf       PORTD
;     bcf         LATB, P_RXF
; z80_push_loop
;     btfsc       TRISE, OBF
;     bra         z80_push_loop
; 
;     bsf         LATB, P_RXF
;     return

; debug
;     movwf       MAIN_TEMP
;     swapf       WREG, w
;     call        hex
;     movwf       DREG
;     movlw       0x05
;     movwf       LO_ADDR
;     clrf        HI_ADDR
;     call        ensure_master
;     call        io_write
;     movf        MAIN_TEMP, w
;     call        hex
;     movwf       DREG
;     call        io_write
;     call        revert_master
;     return
; 
; hex
;     clrf        PCLATH
;     andlw       0xf
;     rlncf       WREG, w
;     addlw       low hex_lut
;     btfsc       STATUS, C
;     incf        PCLATH, f
;     movwf       low_jump
;     movlw       high hex_lut
;     addwf       PCLATH, f
;     movf        low_jump, w
;     movwf       PCL
; 
; hex_lut
;     retlw       '0'
;     retlw       '1'
;     retlw       '2'
;     retlw       '3'
;     retlw       '4'
;     retlw       '5'
;     retlw       '6'
;     retlw       '7'
;     retlw       '8'
;     retlw       '9'
;     retlw       'A'
;     retlw       'B'
;     retlw       'C'
;     retlw       'D'
;     retlw       'E'
;     retlw       'F'
; 
; msg
;     movlw       0x05
;     movwf       LO_ADDR
;     clrf        HI_ADDR
;     tblrd*+
;     movff       TABLAT, DREG
;     movlw       0x00
;     xorwf       DREG, w
;     btfsc       STATUS, Z
;     return
;     call        ensure_master
;     call        io_write
;     call        revert_master
;     bra         msg
; 
; newline
;     movlw       0xA
;     movwf       DREG
;     movlw       0x05
;     movwf       LO_ADDR
;     clrf        HI_ADDR
;     call        ensure_master
;     call        io_write
;     call        revert_master
;     return

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


; debugmsg1
;     db          '\n', 'C'
;     db          'M', 'D'
;     db          '0', 0x00
; 
; debugmsg2
;     db          'G', 'o'
;     db          't', 0x00
; 
; debugmsg3
;     db          'A', 'C'
;     db          'M', 'D'
;     db          '4', '1'
;     db          ' ', 0x00
; 
; debugmsg4
;     db          '\n', '['
;     db          ' ', 'O'
;     db          'k', ' '
;     db          ']', '\n'
;     db          0x00, 0x00
; 
; em
;     db          'E', 'r'
;     db          'r', 'o'
;     db          'r', '!'
;     db          ' ', 0x00
; 
; tom
;     db          'T', '.'
;     db          'O', 0x00
; -- Export these --------------------------------------------------------------

    GLOBAL      sd_init
    ;GLOBAL      sd_card_init    ; shouldn't be global
    GLOBAL      sd_card_csd
    GLOBAL      sd_card_cid
    GLOBAL      sd_card_poll
    GLOBAL      sd_card_read_block
    
    GLOBAL      sd_data

end