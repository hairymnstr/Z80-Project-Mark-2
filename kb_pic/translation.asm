;-------------------------------------------------------------------------------
;
; translation.asm - translate and handle raw set 2 scancodes
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

;-- Externals from hostbus.asm -------------------------------------------------

    EXTERN      hostbus_push

;-- Externals from ps2.asm -----------------------------------------------------

    EXTERN      ps2_queue_send

    EXTERN      flags
    EXTERN      txflags

;-- Externals from asciicodes.asm ----------------------------------------------

    EXTERN      ascii_lookup

;-- Externals from ndcodes.asm -------------------------------------------------

    EXTERN      ndcodes_lookup

    UDATA

translation_buffer      res     1
pause_count             res     1
translation_mode        res     1

TRANSLATE_ASCII         equ     1


    CODE

;===============================================================================
; translate_init - setup the translation system
;===============================================================================

translate_init
  movlw         TRANSLATE_ASCII
  movwf         translation_mode

  bcf           txflags, send_release_flag
  bsf           txflags, send_command_release_flag
  bcf           txflags, pause_flag

  return

;===============================================================================
; translate_key - handle a generic byte from a PS/2 keyboard
;===============================================================================

;; This takes any byte received via the PS/2 protocol module and translates it
;; to another code e.g. ASCII or NDCODE.  It also handles all flag setting (e.g.
;; ack flag when 0xFA is received, and shift, caps, num flag setting

translate_key
  movwf         translation_buffer      ; store the code before it gets mangled
  ; if we're waiting for the Pause stream to finish, don't do anything
  btfsc         txflags, pause_flag
  bra           translate_pause_count

  ; next handle F7
  movlw         0x83
  xorwf         translation_buffer, w
  btfsc         STATUS, Z
  call          translate_f7

  ; Now we can generalise
  btfsc         translation_buffer, 7
  goto          translate_key_message   ; it's a special message not character

  ; if not, then it's a scancode, turn it into something more useful
  movlw         TRANSLATE_ASCII
  xorwf         translation_mode, w
  bz            translate_ascii

  ; default send the raw code and flags
  ; set the LEDS first though
  movlw         0x77                            ; set2 - set numlock
  xorwf         translation_buffer, w
  btfsc         STATUS, Z
  call          translate_set_num

  movlw         0x58                            ; set2 - set capslock
  xorwf         translation_buffer, w
  btfsc         STATUS, Z
  call          translate_set_caps

  movlw         0x7E                            ; set2 - set scrolllock
  xorwf         translation_buffer, w
  btfsc         STATUS, Z
  call          translate_set_scroll

  btfsc         flags, special_flag
  call          translate_send_special

  btfsc         flags, release_flag
  call          translate_send_release

  movf          translation_buffer, w
  call          hostbus_push

  bcf           flags, special_flag
  bcf           flags, release_flag

  return

translate_send_special
  movlw         0xE0
  call          hostbus_push
  return

translate_send_release
  movlw         0xF0
  call          hostbus_push
  return

translate_f7
  movlw         0x7F                    ; fake scancode for F7
  movwf         translation_buffer
  return

translate_key_message
  ; need to set flags and stuff here
  ; release code
  movlw         0xF0
  xorwf         translation_buffer, w
  bz            translate_set_release
  ; special key code
  movlw         0xE0
  xorwf         translation_buffer, w
  bz            translate_set_special
  ; acknowledge code
  movlw         0xFA
  xorwf         translation_buffer, w
  bz            translate_set_ack
  ; resend code
  movlw         0xFE
  xorwf         translation_buffer, w
  bz            translate_set_resend
  ; startup OK code
  movlw         0xAA
  xorwf         translation_buffer, w
  bz            translate_set_startup
  ; pause break start
  movlw         0xE1
  xorwf         translation_buffer, w
  bz            translate_set_pause
  ; other codes shouldn't happen or we don't care about them
  return

translate_set_release
  bsf           flags, release_flag
  return

translate_set_special
  bsf           flags, special_flag
  return

translate_set_ack
  bsf           txflags, ack_flag
  return

translate_set_resend
  bsf           txflags, resend_flag
  return

translate_set_startup
  bcf           LATA, P_FOUND
  return

; -- Pause/Break handling ------------------------------------------------------

translate_set_pause
  bsf           txflags, pause_flag
  movlw         0x7
  movwf         pause_count
  movlw         CC_PAUSE
  call          hostbus_push
  return

translate_pause_count
  dcfsnz        pause_count, f
  bcf           txflags, pause_flag
  return

;===============================================================================
; translate_ascii - use ndcodes and ascii tables to send a useful code
;===============================================================================

;; This routine translates the ASCII compatible keys to single ASCII symbols.
;; Other keys (e.g. Cursor Keys, Control, Shift etc.) are sent in NDCODE along
;; with their release regardless of the "send_release" flag.

translate_ascii
  ; to ndcode then it's just a bittest to see if it's printable or control
  movf          translation_buffer, w
  call          ndcodes_lookup
  btfss         WREG, 7
  bra           translate_ascii_norm
  ; bit 7 set so it's keypad or control
  btfsc         WREG, 6
  bra           translate_ascii_norm
  ; bit 6 clear so it's not keypad

  ; trap the extra fluff the keyboard sends
  movwf         translation_buffer
  xorlw         CC_PSF
  btfsc         STATUS, Z
  bra           translate_clearflags_leave      ; clear flags and return

  ; trap shift, caps, num and scroll
  movf          translation_buffer, w
  andlw         0xFE
  xorlw         CC_LSHIFT
  btfsc         STATUS, Z
  call          translate_set_shift

  movlw         CC_NUM
  xorwf         translation_buffer, w
  btfsc         STATUS, Z
  call          translate_set_num

  movlw         CC_CAPS
  xorwf         translation_buffer, w
  btfsc         STATUS, Z
  call          translate_set_caps

  movlw         CC_SCROLL
  xorwf         translation_buffer, w
  btfsc         STATUS, Z
  call          translate_set_scroll

translate_ascii_control
  btfsc         txflags, send_command_release_flag
  bra           translate_ascii_control_release

  ; send the nd control code
  movf          translation_buffer, w
  btfss         flags, release_flag
  call          hostbus_push

  ; clear the flags and exit
translate_clearflags_leave
  bcf           flags, release_flag
  bcf           flags, special_flag
  return

translate_ascii_control_release
  ; see if this is a release and send if so
  btfsc         flags, release_flag
  call          translate_send_release

  ; now  send the key
  movf          translation_buffer, w
  call          hostbus_push

  bcf           flags, release_flag
  bcf           flags, special_flag

  return

translate_ascii_norm
  ; it's a character or keypad press, so translate to an ascii code if pos
  call          ascii_lookup

  movwf         translation_buffer
  ; now see if it really is ascii
  ; two exceptions 1st is £ symbol, trap that
  movlw         0xA3
  xorwf         translation_buffer, w
  bz            translate_ascii_not_control
  ; other is degree symbol, replaces mystery symbol ¬
  movlw         0xB0
  xorwf         translation_buffer, w
  bz            translate_ascii_not_control
  ; othewise it it's above 0x7F it's a control key
  btfsc         translation_buffer, 7
  bra           translate_ascii_control ; probably numlock off then

  ; also interested in null bytes e.g. 5 when numlock is off, don't send these
  movlw         0x00
  xorwf         translation_buffer, w
  bz            translate_ascii_nosend  ; still clear the flags

translate_ascii_not_control
  ; actual ascii, see if we should send a release
  btfsc         txflags, send_release_flag
  bra           translate_ascii_norm_release

  ; send the code
  movf          translation_buffer, w
  btfss         flags, release_flag
  call          hostbus_push

translate_ascii_nosend
  ; clear the flags
  bcf           flags, release_flag
  bcf           flags, special_flag
  return

translate_ascii_norm_release
  btfsc         flags,release_flag
  call          translate_send_release

  movf          translation_buffer, w
  call          hostbus_push

  bcf           flags, release_flag
  bcf           flags, special_flag
  return

;===============================================================================
; translate_set_shift - set or clear the shift flag
;===============================================================================

translate_set_shift
  bsf           flags, shift_flag
  btfsc         flags, release_flag
  bcf           flags, shift_flag
  return

translate_set_num
  btfsc         flags, release_flag
  return                                        ; do nothing on key-release
  btg           flags, num_flag
  movlw         0xED
  call          ps2_queue_send
  movlw         0x07
  andwf         flags, w
  call          ps2_queue_send
  return

translate_set_caps
  btfsc         flags, release_flag
  return                                        ; do nothing on key-release
  btg           flags, caps_flag
  movlw         0xED
  call          ps2_queue_send
  movlw         0x07
  andwf         flags, w
  call          ps2_queue_send
  return

translate_set_scroll
  btfsc         flags, release_flag
  return                                        ; do nothing on key-release
  btg           flags, scroll_flag
  movlw         0xED
  call          ps2_queue_send
  movlw         0x07
  andwf         flags, w
  call          ps2_queue_send
  return

;-- Exported functions ---------------------------------------------------------

    GLOBAL      translate_key
    GLOBAL      translate_init

    GLOBAL      translation_mode        ; can be set by hostbus

end