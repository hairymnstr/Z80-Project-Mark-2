;== PORT Definitions ==========================================================

;-- PORT A --------------------------------------------------------------------

P_READY         EQU     0
P_FOUND         EQU     1
P_INT           EQU     5

PORTADEF        EQU     b'00100011'
PORTADIR        EQU     b'11011100'

;-- PORT B --------------------------------------------------------------------

PORTBDEF        EQU     b'00000000'
PORTBDIR        EQU     b'01111111'

;-- PORT C --------------------------------------------------------------------

P_TX            EQU     6
P_RX            EQU     7

PORTCDEF        EQU     b'00000000'
PORTCDIR        EQU     b'11111111'

;-- PORT E --------------------------------------------------------------------

P_RD            EQU     0
P_WR            EQU     1
P_CS            EQU     2

PORTEDIR        EQU     b'00010111'
PORTEDEF        EQU     b'00000000'

;-- ADC PINS -------------------------------------------------------------------

ADCONDEF        EQU     b'00001111'

;== FLAG BIT DEFINITIONS =======================================================

; flags
scroll_flag             equ     0
num_flag                equ     1
caps_flag               equ     2
shift_flag              equ     3
release_flag            equ     4
talking_flag            equ     5
send_failed_flag        equ     6
special_flag            equ     7

; txflags
ack_flag                equ     0
resend_flag             equ     1
pause_flag              equ     2
send_release_flag       equ     3
send_command_release_flag       equ     4