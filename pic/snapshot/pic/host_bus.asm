;==============================================================================
;    host_bus.asm
;==============================================================================
list p=18f4520
#include <p18f4520.inc>
#include "portpins.inc"

    UDATA
LO_ADDR RES     1
HI_ADDR RES     1
DREG    RES     1

MODE            RES     1
TEMP_MODE       RES     1

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


; == Export these refs ========================================================

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
end