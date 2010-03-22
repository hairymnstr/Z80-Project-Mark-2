;-------------------------------------------------------------------------------
;
; asciicodes.inc - lookup tables to give ASCII from ndcodes
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

ND_CODES_ASCII_NOMOD
        db '0','1'
        db '2','3'
        db '4','5'
        db '6','7'
        db '8','9'
        db 'a','b'
        db 'c','d'
        db 'e','f'
        db 'g','h'
        db 'i','j'
        db 'k','l'
        db 'm','n'
        db 'o','p'
        db 'q','r'
        db 's','t'
        db 'u','v'
        db 'w','x'
        db 'y','z'
        db '`','-'
        db '=','['
        db ']','\''
        db ',','.'
        db '\\','/'
        db ';',' '
        db '\t','\n'
        db '\n',0x7F
        db 0x08,0x00

ND_CODES_ASCII_SHIFT
        db ')','!'
        db '\"',0xA3    ; £ symbol
        db '$','%'
        db '^','&'
        db '*','('
        db 'A','B'
        db 'C','D'
        db 'E','F'
        db 'G','H'
        db 'I','J'
        db 'K','L'
        db 'M','N'
        db 'O','P'
        db 'Q','R'
        db 'S','T'
        db 'U','V'
        db 'W','X'
        db 'Y','Z'
        db 0xB0,'_'     ;¬ character mapped to degree symbol
        db '+','{'
        db '}','@'
        db '<','>'
        db '|','?'
        db ':',' '
        db '\t','\n'
        db '\n',0x7F
        db 0x08,0x00

ND_CODES_ASCII_CAPS
        db '0','1'
        db '2','3'
        db '4','5'
        db '6','7'
        db '8','9'
        db 'A','B'
        db 'C','D'
        db 'E','F'
        db 'G','H'
        db 'I','J'
        db 'K','L'
        db 'M','N'
        db 'O','P'
        db 'Q','R'
        db 'S','T'
        db 'U','V'
        db 'W','X'
        db 'Y','Z'
        db '`','-'
        db '=','['
        db ']','\''
        db ',','.'
        db '\\','/'
        db ';',' '
        db '\t','\n'
        db '\n',0x7F
        db 0x08,0x00

ND_CODES_ASCII_SHIFTCAPS ; shift and CAPS active, lower case and symbols
        db ')','!'
        db '\"',0xA3    ; £ symbol
        db '$','%'
        db '^','&'
        db '*','('
        db 'a','b'
        db 'c','d'
        db 'e','f'
        db 'g','h'
        db 'i','j'
        db 'k','l'
        db 'm','n'
        db 'o','p'
        db 'q','r'
        db 's','t'
        db 'u','v'
        db 'w','x'
        db 'y','z'
        db 0xB0,'_'     ;¬ character mapped to degree symbol
        db '+','{'
        db '}','@'
        db '<','>'
        db '|','?'
        db ':',' '
        db '\t','\n'
        db '\n',0x7F
        db 0x08,0x00

ND_CODES_ASCII_NUM
        db '0', '1'
        db '2', '3'
        db '4', '5'
        db '6', '7'
        db '8', '9'
        db '.', '*'
        db '+', '-'
        db '/', 0x00

ND_CODES_ASCII_NUMCTRL
        db CC_INS, CC_END
        db CC_DOWN, CC_PGDN
        db CC_LEFT, 0x00
        db CC_RIGHT, CC_HOME
        db CC_UP, CC_PGUP
        db 0x7F, '*'
        db '+', '-'
        db '/', 0x00
