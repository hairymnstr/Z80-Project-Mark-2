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

;-- PORT B ---------------------------------------------------------------------

P_SD_FIND       EQU     4
P_TXE           EQU     5
P_RXF           EQU     6
P_SD_PRES       EQU     7

SLAVE_LATB_DEF EQU     b'11000000'
SLAVE_TRISB_DEF EQU     b'00011111'

;-- PORT E --------------------------------------------------------------------

P_RD            EQU     0
P_WR            EQU     1
P_CS            EQU     2