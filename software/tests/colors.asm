  .feature labels_without_colons
  .feature c_comments
  .feature loose_char_term

VRAM = $8000

; Zero Page locations
Z0 = $00
Z1 = $01
Z2 = $02
Z3 = $03

SCREEN_WIDTH = 128
HALF_SCREEN_WIDTH = 64
SCREEN_HORIZ_OFFSET = 4

; Memory Locations (from bootloader.asm)
SCREEN_CURSOR = $3fb9		; 2 bytes
CHARACTER_COLOR = $3fb6		; 1 byte

;LIB_VGA_clear_vram    = $ed6d
LIB_VGA_draw_pixel    = $ed86
LIB_VGA_write_character = $edfc
LIB_VGA_write_string    = $ee83

.segment "CODE"

; Entry point
reset:
  ; Clear VRAM
  jsr LIB_VGA_clear_vram

  ; Set the cursor to the beginning of VRAM + 4 pixels
  lda #<VRAM
  adc #SCREEN_HORIZ_OFFSET
  sta SCREEN_CURSOR
  lda #>VRAM
  sta SCREEN_CURSOR + 1

  ; Print each color available
  lda #00
  sta CHARACTER_COLOR

loop:
  lda CHARACTER_COLOR

  jsr bin_to_hex
  pha
  dex
  jsr LIB_VGA_write_character
  pla
  tax
  jsr LIB_VGA_write_character

  lda #<space
  ldy #>space
  jsr LIB_VGA_write_string

  inc CHARACTER_COLOR
  lda CHARACTER_COLOR
  cmp #64

  beq exit
  jmp loop

exit:
  jmp exit

bin_to_hex:
    ldy #$ff
    pha
    lsr
    lsr
    lsr                     
    lsr
    jsr @to_hex
    pla
@to_hex:
    and #%00001111
    ora #"0"
    cmp #"9"+1
    bcc @output
    adc #6
@output:
    iny
    bne @return
    tax
@return:

    rts

LIB_VGA_clear_vram:
    lda #<VRAM
    sta Z0
    lda #>VRAM
    sta Z1

    lda #$fa ; Data to load into each address
    ldy #0
    ldx #48 ; Number of pages to clear
@loop:
    sta (Z0), y
    iny
    bne @loop
    inc Z1
    dex
    bne @loop

    rts

space:
  .asciiz " "
  