;  unzx0_8088.S - ZX0 decompressor for 8088 - 81 bytes - NASM
;
;  inputs:
;  * ds:si: start of compressed data
;  * es:di: start of decompression buffer
;
;  Copyright (C) 2021 Emmanuel Marty
;  ZX0 compression (c) 2021 Einar Saukas, https://github.com/einar-saukas/ZX0
;
;  This software is provided 'as-is', without any express or implied
;  warranty.  In no event will the authors be held liable for any damages
;  arising from the use of this software.
;
;  Permission is granted to anyone to use this software for any purpose,
;  including commercial applications, and to alter it and redistribute it
;  freely, subject to the following restrictions:
;
;  1. The origin of this software must not be misrepresented; you must not
;     claim that you wrote the original software. If you use this software
;     in a product, an acknowledgment in the product documentation would be
;     appreciated but is not required.
;  2. Altered source versions must be plainly marked as such, and must not be
;     misrepresented as being the original software.
;  3. This notice may not be removed or altered from any source distribution.

        segment .text
        bits 16

zx0_decompress:
        cld                     ; make string operations go forward
        mov     al,080H         ; initialize empty bit queue
                                ; plus bit to roll into carry
        xor     dx,dx           ; initialize rep-offset to 1
        dec     dx

.literals:
        call    .get_elias      ; read number of literals to copy
        rep     movsb           ; copy literal bytes

        add     al,al           ; shift bit queue, and high bit into carry
        jc      .get_offset     ; if 1: read offset, if 0: rep-match

        call    .get_elias      ; read rep-match length (starts at 1)

.copy_match:
        push    ds              ; save ds:si (current pointer to compressed data)
        push    si

        push    es
        pop     ds
        mov     si,di           ; point to destination in es:di + offset in dx
        add     si,dx
        rep     movsb           ; copy matched bytes

        pop     si              ; restore ds:si
        pop     ds

        add     al,al           ; read 'literal or match' bit
        jnc     .literals       ; if 0: go copy literals

.get_offset:
        mov     cl,0feh         ; initialize value to FEh
        call    .elias_loop     ; read high byte of match offset
        inc     cl              ; obtain negative offset high byte
        je      .done           ; exit if EOD marker
        
        mov     dh,cl           ; transfer negative high byte into dh
        mov     cx,1            ; initialize match length value to 1
        mov     dl,[si]         ; read low byte of offset + 1 bit of len
        inc     si
        stc                     ; set high bit that is shifted into bit 15
        rcr     dx,1            ; shift len bit into carry/offset in place
        jc      .got_offs       ; if len bit is set, no need for more
        call    .elias_bt       ; read rest of elias-encoded match length
.got_offs:
        inc     cx              ; fix match length
        jmp     short .copy_match ; go copy match

.get_elias:
        mov     cx,1            ; initialize value to 1
.elias_loop:
        add     al,al           ; shift bit queue, and high bit into carry
        jnz     .got_bit        ; queue not empty, bits remain
        lodsb                   ; read 8 new bits
        adc     al,al           ; shift bit queue, and high bit into carry
.got_bit:
        jc      .got_elias      ; done if control bit is 1
.elias_bt:
        add     al,al           ; read data bit
        adc     cx,cx           ; shift into cx
        jmp     short .elias_loop ; keep reading
.got_elias:
.done:
        ret
