include statics

org 0000

    ld  hl,$7fff
    ld  sp,hl           ;set the stack pointer to top of the 32k ram chip

    ld  a,$10
main:

    ld  b,$FF
    ld  c,$FF
    inc a
    out (1),a

loop:

    djnz        loop
    dec         c
    jr          nz, loop
    
    jp          main