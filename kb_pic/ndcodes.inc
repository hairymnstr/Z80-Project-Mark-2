;-------------------------------------------------------------------------------
;
; ndcodes.inc - lookup table to give every key a unique single byte code from
;               PS/2 set 2 scancodes, completely unique mapping
; File Version 1.0 - 23 Feb 2010
; hairymnstr@gmail.com
;
; Copyright (C) 2010  Nathan Dumont
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
;-------------------------------------------------------------------------------

; actual codes are defined in scancodes.inc for ease of maintenance
; CC_PSF is a fake scancode intended to be stripped from the stream
; e.g. Print Screen sends 2 keys effectively, or when NUM lock is on a shift
; character is sent along with delete, end, pgup etc.
; Pause/Break is a long sequence starting with E1 and must be trapped separately
; F7 is moved from 0x83 to 0x7F (0x7F is otherwise unused) to keep the key
; codes all below 8 bits so the lookup tables are shorter.
; codes with bit 7 set are response or control codes (e.g. 0xAA = good self test
; 0xFA is acknowledge, 0xF0 is release) these should be trapped separately.

SCAN_CODES_ND
        db 0xFF,        CC_F9           ;00,            01 - F9
        db 0xFF,        CC_F5           ;02,            03 - F5
        db CC_F3,       CC_F1           ;04 - F3,       05 - F1
        db CC_F2,       CC_F12          ;06 - F2,       07 - F12
        db 0xFF,        CC_F10          ;08,            09 - F10
        db CC_F8,       CC_F6           ;0A - F8,       0B - F6
        db CC_F4,       CC_TAB          ;0C - F4,       0D - TAB
        db CC_LQ,       0xFF            ;0E - `,        0F
        db 0xFF,        CC_ALT          ;10,            11 - ALT
        db CC_LSHIFT,   0xFF            ;12 - L SHIFT,  13
        db CC_CTRL,     CC_Q            ;14 - CTRL,     15 - Q
        db CC_1,        0xFF            ;16 - 1,        17
        db 0xFF,        0xFF            ;18,            19
        db CC_Z,        CC_S            ;1A - Z,        1B - S
        db CC_A,        CC_W            ;1C - A,        1D - W
        db CC_2,        CC_GUIL         ;1E - 2,        1F - L GUI
        db 0xFF,        CC_C            ;20,            21 - C
        db CC_X,        CC_D            ;22 - X,        23 - D
        db CC_E,        CC_4            ;24 - E,        25 - 4
        db CC_3,        CC_GUIR         ;26 - 3,        27 - R GUI
        db 0xFF,        CC_SP           ;28,            29 - SPACE
        db CC_V,        CC_F            ;2A - V,        2B - F
        db CC_T,        CC_R            ;2C - T,        2D - R
        db CC_5,        CC_APPS         ;2E - 5,        2F - APPS
        db 0xFF,        CC_N            ;30,            31 - N
        db CC_B,        CC_H            ;32 - B,        33 - H
        db CC_G,        CC_Y            ;34 - G,        35 - Y
        db CC_6,        0xFF            ;36 - 6,        37
        db 0xFF,        0xFF            ;38,            39
        db CC_M,        CC_J            ;3A - M,        3B - J
        db CC_U,        CC_7            ;3C - U,        3D - 7
        db CC_8,        0xFF            ;3E - 8,        3F
        db 0xFF,        CC_CM           ;40,            41 - ,
        db CC_K,        CC_I            ;42 - K,        43 - I
        db CC_O,        CC_0            ;44 - O,        45 - 0 (zero)
        db CC_9,        0xFF            ;46 - 9,        47
        db 0xFF,        CC_FS           ;48,            49 - .
        db CC_US,       CC_L            ;4A - /,        4B - L
        db CC_SC,       CC_P            ;4C - ;,        4D - P
        db CC_DSH,      0xFF            ;4E - -,        4F
        db 0xFF,        0xFF            ;50,            51
        db CC_AP,       0xFF            ;52 - ',        53
        db CC_LSB,      CC_EQ           ;54 - [,        55 - =
        db 0xFF,        0xFF            ;56,            57
        db CC_CAPS,     CC_RSHIFT       ;58 - CAPS,     59 - R SHIFT
        db CC_ENTER,    CC_RSB          ;5A - ENTER,    5B - ]
        db 0xFF,        CC_WS           ;5C,            5D - \
        db 0xFF,        0xFF            ;5E,            5F
        db 0xFF,        CC_WS           ;60,            61 - \
        db 0xFF,        0xFF            ;62,            63
        db 0xFF,        0xFF            ;64,            65
        db CC_BKSP,     0xFF            ;66 - BKSP,     67
        db 0xFF,        CC_KP1          ;68,            69 - KP 1
        db 0xFF,        CC_KP4          ;6A,            6B - KP 4
        db CC_KP7,      0xFF            ;6C - KP 7,     6D
        db 0xFF,        0xFF            ;6E,            6F
        db CC_KP0,      CC_KPD          ;70 - KP 0,     71 - KP .
        db CC_KP2,      CC_KP5          ;72 - KP 2,     73 - KP 5
        db CC_KP6,      CC_KP8          ;74 - KP 6,     75 - KP 8
        db CC_ESC,      CC_NUM          ;76 - ESC,      77 - NUM
        db CC_F11,      CC_KPP          ;78 - F11,      79 - KP+
        db CC_KP3,      CC_KPM          ;7A - KP 3,     7B - KP -
        db CC_KPS,      CC_KP9          ;7C - KP *,     7D - KP 9
        db CC_SCROLL,   CC_F7           ;7E - SCROLL,   7F - F7 (Not real scan 
                                        ;   code, has to be moved here from 83)

; special keys preceded by E0
SCAN_CODES_ND_E0
        db 0xFF,        0xFF            ;00, 01
        db 0xFF,        0xFF            ;02, 03
        db 0xFF,        0xFF            ;04, 05
        db 0xFF,        0xFF            ;06, 07
        db 0xFF,        0xFF            ;08, 09
        db 0xFF,        0xFF            ;0A, 0B
        db 0xFF,        0xFF            ;0C, 0D
        db 0xFF,        0xFF            ;0E, 0F
        db CC_MSRCH,    CC_ALTR         ;10, 11
        db CC_PSF,      CC_PSF          ;12, 13     (both not wanted codes)
        db CC_CTRLR,    CC_MPRV         ;14, 15
        db 0xFF,        0xFF            ;16, 17
        db CC_MFV,      0xFF            ;18, 19
        db 0xFF,        0xFF            ;1A, 1B
        db 0xFF,        0xFF            ;1C, 1D
        db 0xFF,        CC_GUIL         ;1E, 1F
        db CC_MRFSH,    CC_MVD          ;20, 21
        db 0xFF,        CC_MMT          ;22, 23
        db 0xFF,        0xFF            ;24, 25
        db 0xFF,        CC_GUIR         ;26, 27
        db CC_MWSP,     0xFF            ;28, 29
        db CC_PSF,      CC_MCLC         ;2A, 2B
        db 0xFF,        0xFF            ;2C, 2D
        db 0xFF,        CC_APPS         ;2E, 2F
        db CC_MFWD,     0xFF            ;30, 31
        db CC_MVU,      0xFF            ;32, 33
        db CC_MPP,      0xFF            ;34, 35
        db CC_PSF,      CC_PWR          ;36, 37
        db CC_MBCK,     0xFF            ;38, 39
        db CC_MHOME,    CC_MSTP         ;3A, 3B
        db 0xFF,        0xFF            ;3C, 3D
        db 0xFF,        CC_SLP          ;3E, 3F
        db CC_MCMP,     0xFF            ;40, 41
        db 0xFF,        0xFF            ;42, 43
        db 0xFF,        0xFF            ;44, 45
        db 0xFF,        0xFF            ;46, 47
        db CC_MEM,      0xFF            ;48, 49
        db CC_KPSL,     0xFF            ;4A, 4B
        db 0xFF,        CC_MNXT         ;4C, 4D
        db 0xFF,        0xFF            ;4E, 4F
        db CC_MSL,      0xFF            ;50, 51
        db 0xFF,        0xFF            ;52, 53
        db 0xFF,        0xFF            ;54, 55
        db 0xFF,        0xFF            ;56, 57
        db 0xFF,        CC_PSF          ;58, 59
        db CC_KPE,      0xFF            ;5A, 5B
        db 0xFF,        0xFF            ;5C, 5D
        db CC_WK,       0xFF            ;5E, 5F
        db 0xFF,        0xFF            ;60, 61
        db 0xFF,        0xFF            ;62, 63
        db 0xFF,        0xFF            ;64, 65
        db 0xFF,        0xFF            ;66, 67
        db 0xFF,        CC_END          ;68, 69
        db 0xFF,        CC_LEFT         ;6A, 6B
        db CC_HOME,     0xFF            ;6C, 6D
        db 0xFF,        0xFF            ;6E, 6F
        db CC_INS,      CC_DEL          ;70, 71
        db CC_DOWN,     0xFF            ;72, 73
        db CC_RIGHT,    CC_UP           ;74, 75
        db 0xFF,        0xFF            ;76, 77
        db 0xFF,        0xFF            ;78, 79
        db CC_PGDN,     0xFF            ;7A, 7B
        db CC_PSR,      CC_PGUP         ;7C, 7D
        db 0xFF,        0xFF            ;7E, 7F