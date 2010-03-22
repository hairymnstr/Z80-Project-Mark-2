list p=18f4520
include <p18f4520.inc>
include <portpins.inc>

    UDATA

eeprom_addr     RES     1
eeprom_data     RES     1

    CODE

eeprom_write
    movf        eeprom_addr, w
    movwf       EEADR
    movf        eeprom_data, w
    movwf       EEDATA
    bcf         EECON1, EEPGD
    bcf         EECON1, CFGS
    bsf         EECON1, WREN

    bcf         INTCON, GIE
    movlw       0x55
    movwf       EECON2
    movlw       0xAA
    movwf       EECON2
    bsf         EECON1, WR

eeprom_write_wait
    btfsc       EECON1, WR
    bra         eeprom_write_wait

    bsf         INTCON, GIE

    bcf         EECON1, WREN

    return

eeprom_read
    movf        eeprom_addr, w
    movwf       EEADR
    bcf         EECON1, EEPGD
    bcf         EECON1, CFGS
    bsf         EECON1, RD
    movf        EEDATA, w
    movwf       eeprom_data

    return

;== Export all labels ==========================================================

    GLOBAL      eeprom_write
    GLOBAL      eeprom_read

    GLOBAL      eeprom_addr
    GLOBAL      eeprom_data

end
