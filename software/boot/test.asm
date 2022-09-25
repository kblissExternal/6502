; Enable syntax features
  .feature labels_without_colons
  .feature c_comments
  .feature loose_char_term

; Zero page locations
Z0 = $00                                        
Z1 = $01
Z2 = $02
Z3 = $03

.segment "CODE"

;   main - Initialize the bootloader
main:

    MEM_LOC_1 = $0300
    MEM_LOC_2 = $0301
    MEM_LOC_3 = $0302
    MEM_LOC_4 = $0303
    MEM_LOC_5 = $0304

    lda #$ff
    sta MEM_LOC_1
    sta MEM_LOC_2
    sta MEM_LOC_3
    sta MEM_LOC_4
    sta MEM_LOC_5

    lda #$00
    lda MEM_LOC_1
    lda #$00
    lda MEM_LOC_2
    lda #$00
    lda MEM_LOC_3
    lda #$00
    lda MEM_LOC_4
    lda #$00
    lda MEM_LOC_5

    jsr subroutine

    lda MEM_LOC_1
    sta MEM_LOC_2
subroutine:
    lda $01
    sta MEM_LOC_1

    rts

.segment "MONITOR"
ISR
    rti

.segment "VECTORS"
    .word main                                  ; Entry vector: Reset
    .word ISR                                   ; Entry vector: Interrupt Service Routine

