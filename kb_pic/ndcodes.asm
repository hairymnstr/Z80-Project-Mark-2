;-------------------------------------------------------------------------------
;
; ndcodes.asm - lookup table routines to give every key a unique single byte 
;               code from PS/2 set 2 scancodes, completely unique mapping
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
; ndcodes_lookup
;===============================================================================

;; Lookup a set2 scancode and return a unique "ndcode" 8 bit value.  Checks the
;; special_flag to determine the proper key code

ndcodes_lookup
  btfsc         flags, special_flag
  goto          ndcodes_special
  ; normal key code
  clrf          TBLPTRH
  addlw         low SCAN_CODES_ND
  btfsc         STATUS,C
  incf          TBLPTRH, f
  movwf         TBLPTRL
  movlw         high SCAN_CODES_ND
  addwf         TBLPTRH, f
  clrf          TBLPTRU
  tblrd*
  movf          TABLAT,w
  return

ndcodes_special
  clrf          TBLPTRH
  addlw         low SCAN_CODES_ND_E0
  btfsc         STATUS,C
  incf          TBLPTRH,f
  movwf         TBLPTRL
  movlw         high SCAN_CODES_ND_E0
  addwf         TBLPTRH,f
  clrf          TBLPTRU
  tblrd*
  movf          TABLAT,w
  return

include ndcodes.inc

;-- Exported functions ---------------------------------------------------------

    GLOBAL      ndcodes_lookup

end