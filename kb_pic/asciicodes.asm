;-------------------------------------------------------------------------------
;
; asciicodes.asm - lookup table routines to give ASCII from ndcodes
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

list p=18f4520
include <p18f4520.inc>
include scancodes.inc
include portpins.inc

;-- Externals from ps2.asm -----------------------------------------------------

    EXTERN      flags

    CODE

;===============================================================================
; ascii_lookup - looksup the byte in WREG from an ndcode to an ascii code
;===============================================================================

;; This function works on printable ndcodes (less than 0x40) or numpad (0xC0 up)
;; The returned code is dependent on shift, caps and numlock where appropriate
;; if it's a numpad and numlock isn't asserted the return code may be a control
;; ndcode (0x40-0xBF).

ascii_lookup
  btfsc         WREG, 7
  bra           ascii_lookup_numpad
  ; lookup a normal text key
  btfsc         flags, shift_flag
  bra           ascii_lookup_shift
  btfsc         flags, caps_flag
  bra           ascii_lookup_caps
ascii_lookup_nomod
  clrf          TBLPTRH
  addlw         low ND_CODES_ASCII_NOMOD
  btfsc         STATUS, C
  incf          TBLPTRH, f
  movwf         TBLPTRL
  movlw         high ND_CODES_ASCII_NOMOD
  addwf         TBLPTRH, f
  clrf          TBLPTRU
  tblrd*
  movf          TABLAT,w
  return

ascii_lookup_shift
  ; see if CAPS is set too
  btfsc         flags, caps_flag
  bra           ascii_lookup_shiftcaps
  clrf          TBLPTRH
  addlw         low ND_CODES_ASCII_SHIFT
  btfsc         STATUS, C
  incf          TBLPTRH, f
  movwf         TBLPTRL
  movlw         high ND_CODES_ASCII_SHIFT
  addwf         TBLPTRH, f
  clrf          TBLPTRU
  tblrd*
  movf          TABLAT,w
  return

ascii_lookup_caps
  clrf          TBLPTRH
  addlw         low ND_CODES_ASCII_CAPS
  btfsc         STATUS, C
  incf          TBLPTRH, f
  movwf         TBLPTRL
  movlw         high ND_CODES_ASCII_CAPS
  addwf         TBLPTRH, f
  clrf          TBLPTRU
  tblrd*
  movf          TABLAT,w
  return

ascii_lookup_shiftcaps
  clrf          TBLPTRH
  addlw         low ND_CODES_ASCII_SHIFTCAPS
  btfsc         STATUS, C
  incf          TBLPTRH, f
  movwf         TBLPTRL
  movlw         high ND_CODES_ASCII_SHIFTCAPS
  addwf         TBLPTRH, f
  clrf          TBLPTRU
  tblrd*
  movf          TABLAT,w
  return

ascii_lookup_numpad
  ; numpad codes need 0xC0 taken off for lookup
  andlw         0x3F
  btfss         flags, num_flag
  bra           ascii_lookup_numctrl

ascii_lookup_num
  clrf          TBLPTRH
  addlw         low ND_CODES_ASCII_NUM
  btfsc         STATUS, C
  incf          TBLPTRH, f
  movwf         TBLPTRL
  movlw         high ND_CODES_ASCII_NUM
  addwf         TBLPTRH, f
  clrf          TBLPTRU
  tblrd*
  movf          TABLAT,w
  return

ascii_lookup_numctrl
  clrf          TBLPTRH
  addlw         low ND_CODES_ASCII_NUMCTRL
  btfsc         STATUS, C
  incf          TBLPTRH,f
  movwf         TBLPTRL
  movlw         high ND_CODES_ASCII_NUMCTRL
  addwf         TBLPTRH, f
  clrf          TBLPTRU
  tblrd*
  movf          TABLAT,w
  return

include asciicodes.inc

;-- Export functions -----------------------------------------------------------

    GLOBAL      ascii_lookup

end