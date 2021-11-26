; ***************************************************************************
; ***************************************************************************
;
; zx0_6502.asm
;
; NMOS 6502 decompressor for data stored in Einar Saukas's ZX0 format.
;
; This code is written for the ACME assembler.
;
; The code is 196 bytes long, and is self-modifying.
;
; Copyright John Brandwood 2021.
;
; Distributed under the Boost Software License, Version 1.0.
; (See accompanying file LICENSE_1_0.txt or copy at
;  http://www.boost.org/LICENSE_1_0.txt)
;
; ***************************************************************************
; ***************************************************************************



; ***************************************************************************
; ***************************************************************************
;
; Decompression Options & Macros
;

                ;
                ; Assume that we're decompessing from a large multi-bank
                ; compressed data file, and that the next bank may need to
                ; paged in when a page-boundary is crossed.
                ;

ZX0_FROM_BANK   =       0

                ;
                ; Macro to increment the source pointer to the next page.
                ;

                !macro   ZX0_INC_PAGE {
                !if     ZX0_FROM_BANK {
                        jsr     zx0_next_page
                } else   {
                        inc     <zx0_srcptr + 1
                }
                }



; ***************************************************************************
; ***************************************************************************
;
; Data usage is 8 bytes of zero-page.
;

zx0_srcptr      =       $F8                     ; 1 word.
zx0_dstptr      =       $FA                     ; 1 word.
zx0_length      =       $FC                     ; 1 word.
zx0_offset      =       $FE                     ; 1 word.



; ***************************************************************************
; ***************************************************************************
;
; zx0_unpack - Decompress data stored in Einar Saukas's ZX0 format.
;
; Args: zx0_srcptr = ptr to compessed data
; Args: zx0_dstptr = ptr to output buffer
; Uses: lots!
;

zx0_unpack:     ldy     #$FF                    ; Initialize default offset.
                sty     <zx0_offset+0
                sty     <zx0_offset+1
                iny                             ; Initialize source index.
                sty     <zx0_length+1           ; Initialize length to 1.

                ldx     #$40                    ; Initialize empty buffer.

zx0_next_cmd:   lda     #1                      ; Initialize length back to 1.
                sta     <zx0_length + 0

                txa                             ; Restore bit-buffer.

                asl                             ; Copy from literals or new offset?
                bcc     zx0_cp_literal

                ;
                ; Copy bytes from new offset.
                ;

zx0_new_offset: jsr     zx0_gamma_flag          ; Get offset MSB, returns CS.

                tya                             ; Negate offset MSB and check
                sbc     <zx0_length + 0         ; for zero (EOF marker).
                bcs     zx0_got_eof

                sec
                ror
                sta     <zx0_offset + 1         ; Save offset MSB.

                lda     (<zx0_srcptr),y         ; Get offset LSB.
                inc     <zx0_srcptr + 0
                beq     zx0_inc_of_src

zx0_off_skip1:  ror                             ; Last offset bit starts gamma.
                sta     <zx0_offset + 0         ; Save offset LSB.

                lda     #-2                     ; Minimum length of 2?
                bcs     zx0_get_lz_dst

                lda     #1                      ; Initialize length back to 1.
                sta     <zx0_length + 0

                txa                             ; Restore bit-buffer.

                jsr     zx0_gamma_data          ; Get length, returns CS.

                lda     <zx0_length + 0         ; Negate lo-byte of (length+1).
                eor     #$FF

;               bne     zx0_get_lz_dst          ; N.B. Optimized to do nothing!
;
;               inc     <zx0_length + 1         ; Increment from (length+1).
;               dec     <zx0_length + 1         ; Decrement because lo-byte=0.

zx0_get_lz_dst: tay                             ; Calc address of partial page.
                eor     #$FF                    ; Always CS from previous SBC.
                adc     <zx0_dstptr + 0
                sta     <zx0_dstptr + 0
                bcs     zx0_get_lz_win

                dec     <zx0_dstptr + 1

zx0_get_lz_win: clc                             ; Calc address of match.
                adc     <zx0_offset + 0         ; N.B. Offset is negative!
                sta     zx0_winptr + 0
                lda     <zx0_dstptr + 1
                adc     <zx0_offset + 1
                sta     zx0_winptr + 1

zx0_winptr      =       *+1

zx0_lz_page:    lda     $1234,y                 ; Self-modifying zx0_winptr.
                sta     (<zx0_dstptr),y
                iny
                bne     zx0_lz_page
                inc     <zx0_dstptr + 1

                lda     <zx0_length + 1         ; Any full pages left to copy?
                beq     zx0_next_cmd

                dec     <zx0_length + 1         ; This is rare, so slower.
                inc     zx0_winptr + 1
                bne     zx0_lz_page             ; Always true.

zx0_got_eof:    rts                             ; Finished decompression.

                ;
                ; Copy bytes from compressed source.
                ;

zx0_cp_literal: jsr     zx0_gamma_flag          ; Get length, returns CS.

                pha                             ; Preserve bit-buffer.

                ldx     <zx0_length + 0         ; Check the lo-byte of length
                bne     zx0_cp_byte             ; without effecting CS.

zx0_cp_page:    dec     <zx0_length + 1         ; Decrement # of pages to copy.

zx0_cp_byte:    lda     (<zx0_srcptr),y         ; CS throughout the execution of
                sta     (<zx0_dstptr),y         ; of this .cp_page loop.

                inc     <zx0_srcptr + 0
                beq     zx0_inc_cp_src

zx0_cp_skip1:   inc     <zx0_dstptr + 0
                beq     zx0_inc_cp_dst

zx0_cp_skip2:   dex                             ; Any bytes left to copy?
                bne     zx0_cp_byte

                lda     <zx0_length + 1         ; Any full pages left to copy?
                bne     zx0_cp_page             ; Optimized for branch-unlikely.

                inx                             ; Initialize length back to 1.
                stx     <zx0_length + 0

                pla                             ; Restore bit-buffer.

                asl                             ; Copy from last offset or new offset?
                bcs     zx0_new_offset

                ;
                ; Copy bytes from last offset (rare so slower).
                ;

zx0_old_offset: jsr     zx0_gamma_flag          ; Get length, returns CS.

                tya                             ; Negate the lo-byte of length.
                sbc     <zx0_length + 0
                sec                             ; Ensure CS before zx0_get_lz_dst!
                bne     zx0_get_lz_dst

                dec     <zx0_length + 1         ; Decrement because lo-byte=0.
                bcs     zx0_get_lz_dst          ; Always true!

                ;
                ; Optimized handling of pointers crossing page-boundaries.
                ;

zx0_inc_of_src: +ZX0_INC_PAGE
                bne     zx0_off_skip1           ; Always true.

zx0_inc_cp_src: +ZX0_INC_PAGE
                bcs     zx0_cp_skip1            ; Always true.

zx0_inc_cp_dst: inc     <zx0_dstptr + 1
                bcs     zx0_cp_skip2            ; Always true.

zx0_inc_ga_src: +ZX0_INC_PAGE
                bne     zx0_gamma_skip          ; Always true.

                ;
                ; Get 16-bit interlaced Elias gamma value.
                ;

zx0_gamma_data: asl                             ; Get next bit.
                rol     <zx0_length + 0
zx0_gamma_flag: asl
                bcc     zx0_gamma_data          ; Loop until finished or empty.
                bne     zx0_gamma_done          ; Bit-buffer empty?

zx0_gamma_load: lda     (<zx0_srcptr),y         ; Reload the empty bit-buffer
                inc     <zx0_srcptr + 0         ; from the compressed source.
                beq     zx0_inc_ga_src
zx0_gamma_skip: rol
                bcs     zx0_gamma_done          ; Finished?

zx0_gamma_word: asl                             ; Get next bit.
                rol     <zx0_length + 0
                rol     <zx0_length + 1
                asl
                bcc     zx0_gamma_word          ; Loop until finished or empty.
                beq     zx0_gamma_load          ; Bit-buffer empty?

zx0_gamma_done: tax                             ; Preserve bit-buffer.
                rts
