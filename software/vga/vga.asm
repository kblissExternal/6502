;================================================================================
; Memory Locations
;================================================================================
VRAM                 = $6000
VRAM_START           = $6114
VRAM_LAST            = $6f94

;================================================================================
; VGA Registers
;================================================================================
FONT_CONTROL   = $7c00
FONT_DATA      = $7c01
CHAR_WRI_H     = $7c06
CHAR_WRI_L     = $7c07

;================================================================================
; Static values
;================================================================================
COLOR_WHITE          = $0f
COLOR_YELLOW         = $0d
CHARACTER_LINES      = 73
CHARACTER_ROWS       = 30
BYTES_PER_ROW        = 127

; Clear character RAM
LIB_VGA_clear_ram:
    ldx #16         ; Clear 16 pages of RAM
    lda #>VRAM
    sta Z1

@clear_block:
    lda #<VRAM
    sta Z0
    ldy $ff
@clear_page:
    lda #$00            ; Clear byte
    sta (Z0), Y
    dey
    bne @clear_page

    ; Clear the final location
    sta (Z0), Y

    inc Z1
    dex
    bne @clear_block

    rts

; Print a test pattern
LIB_VGA_test_pattern:
    jsr LIB_VGA_clear_ram

    ; Set the default font and color
    lda #COLOR_WHITE
    sta CHAR_WRI_H

    ; Print screen borders
    jsr LIB_VGA_print_absolute_borders

    ; Print heading text
    lda #$63
    sta Z1
    lda #$2f
    sta Z0

    lda #<heading1
    sta Z2
    lda #>heading1
    sta Z3
    
    jsr LIB_VGA_print_text

    ; Change the font color to Yellow for character sets
    lda #COLOR_YELLOW
    sta CHAR_WRI_H

    ; Print G0 Character set
    jsr LIB_VGA_print_g0_charset
    
    ; Print G1 Character set
    ;jsr LIB_VGA_print_g1_charset

    ; Change the font color back to White
    lda #COLOR_WHITE
    sta CHAR_WRI_H

    ; Print color set
    jsr LIB_VGA_print_colors

    rts

LIB_VGA_print_absolute_borders:
    ; Print top border
    lda #<VRAM_START
    sta Z0
    lda #>VRAM_START
    sta Z1

    ; Pint the Northern and Southern borders
    ldy #CHARACTER_LINES
    ldx #2              ; Repeat this loop for two iterations (North and South)
@north_south_border:
    lda #$cd            ; North/south line
@north_south_border_loop:
    sta (Z0), Y
    dey
    bne @north_south_border_loop

    ldy #CHARACTER_LINES
    dex
    beq @north_south_complete

    lda #201            ; Northwest corner
    sta (Z0)
    lda #187            ; Northeast corner
    sta (Z0), Y

    ; Switch to the Southern border
    lda #<VRAM_LAST
    sta Z0
    lda #>VRAM_LAST
    sta Z1

    jmp @north_south_border

@north_south_complete:
    lda #200            ; Southwest corner
    sta (Z0)
    lda #188            ; Southeast corner
    sta (Z0), Y

; Print Eastern and Western borders
    ldx #CHARACTER_ROWS         ; Iterate for each character row, but decrement X to avoid overwriting the first and last rows
    dex
    dex

@west_east_border_loop:
    lda Z0
    sbc #BYTES_PER_ROW
    sta Z0
    bcs @write_east_west_character

    ; Reset Z0 and decrement Z1
    lda #<VRAM_LAST
    sta Z0
    dec Z1

@write_east_west_character:
    lda #186
    sta (Z0)
    sta (Z0), Y

    dex
    bne @west_east_border_loop

    rts

LIB_VGA_print_text:
    ldy #0
@loop:
    lda (Z2), Y
    cmp #$00
    beq @done
    sta (Z0), Y
    iny
    jmp @loop

@done:
    rts

LIB_VGA_print_g0_charset:
    ; Print out the box; it should start on the 10th line (651A)
    lda #>VRAM_START
    adc #3              ; 4 rows from the top of the screen
    sta Z1
    lda #<VRAM_START
    adc #5              ; 5 characters from the left of the screen
    sta Z0

    ldx #2
@outer_box_loop:
    lda #196
    ldy #64
@inner_box_loop:
    sta (Z0), Y
    dey
    bne @inner_box_loop
    sta (Z0), Y

    ; Move the 'cursor' down 5 lines
    inc Z1
    inc Z1
    lda Z0
    adc #BYTES_PER_ROW
    sta Z0
    dex
    bne @outer_box_loop

; Print box corners and sides
    lda #218
    sta $6518   ; Northwest
    lda #192
    sta $6798   ; Southwest

    lda #191
    sta $6559   ; Northeast
    lda #217
    sta $67D9   ; Southeast

; Print sides
    lda #179
    sta $6598
    sta $6618
    sta $6698
    sta $6718
    sta $65D9
    sta $6659
    sta $66D9
    sta $6759

@line1:
    ldy #$3f
    lda #$99
    sta Z0
    lda #$65
    sta Z1

@line1_loop:
    tya
    sta (Z0), Y
    dey
    bne @line1_loop

@line2:
    ldy #$40
    lda #$18
    sta Z0
    lda #$66
    sta Z1

@line2_loop:
    tya
    adc #$3f
    sta (Z0), Y
    dey
    bne @line2_loop

@line3:
    ldy #$40
    lda #$98
    sta Z0
    lda #$66
    sta Z1

@line3_loop:
    tya
    adc #$7f
    sta (Z0), Y
    dey
    bne @line3_loop

@line4:
    ldy #$40
    lda #$18
    sta Z0
    lda #$67
    sta Z1

@line4_loop:
    tya
    adc #$bf
    sta (Z0), Y
    dey
    bne @line4_loop

    rts

LIB_VGA_print_g1_charset:
    rts

LIB_VGA_print_colors:
    ; Numbers

    ; 0
    lda #$00
    sta $6a21
    lda #$30
    sta $6a22
    lda #$00
    sta $6a23

    ; 1
    lda #$00
    sta $6a24
    lda #$31
    sta $6a25
    lda #$00
    sta $6a26

    ; 2
    lda #$00
    sta $6a27
    lda #$32
    sta $6a28
    lda #$00
    sta $6a29

    ; 3
    lda #$00
    sta $6a2a
    lda #$33
    sta $6a2b
    lda #$00
    sta $6a2c

    ; 4
    lda #$00
    sta $6a2d
    lda #$34
    sta $6a2e
    lda #$00
    sta $6a2f

    ; 5
    lda #$00
    sta $6a30
    lda #$35
    sta $6a31
    lda #$00
    sta $6a32

    ; 6
    lda #$00
    sta $6a33
    lda #$36
    sta $6a34
    lda #$00
    sta $6a35

    ; 7
    lda #$00
    sta $6a36
    lda #$37
    sta $6a37
    lda #$00
    sta $6a38

    ; 8
    lda #$00
    sta $6a39
    lda #$38
    sta $6a3a
    lda #$00
    sta $6a3b

    ; 9
    lda #$00
    sta $6a3c
    lda #$39
    sta $6a3d
    lda #$00
    sta $6a3e

    ; 10
    lda #$00
    sta $6a3f
    lda #$31
    sta $6a40
    lda #$30
    sta $6a41

    ; 11
    lda #$00
    sta $6a42
    lda #$31
    sta $6a43
    lda #$31
    sta $6a44

    ; 12
    lda #$00
    sta $6a45
    lda #$31
    sta $6a46
    lda #$32
    sta $6a47

    ; 13
    lda #$00
    sta $6a48
    lda #$31
    sta $6a49
    lda #$33
    sta $6a4a

    ; 14
    lda #$00
    sta $6a4b
    lda #$31
    sta $6a4c
    lda #$34
    sta $6a4d

    ; 15
    lda #$00
    sta $6a4e
    lda #$31
    sta $6a4f
    lda #$35
    sta $6a50

    ; Colors
    lda #$01
    sta $7c06

    lda #219
    sta $69a4
    sta $69a5
    sta $69a6

    lda #$02
    sta $7c06

    lda #219
    sta $69a7
    sta $69a8
    sta $69a9

    lda #$03
    sta $7c06

    lda #219
    sta $69aa
    sta $69ab
    sta $69ac

    lda #$04
    sta $7c06

    lda #219
    sta $69ad
    sta $69ae
    sta $69af

    lda #$05
    sta $7c06

    lda #219
    sta $69b0
    sta $69b1
    sta $69b2

    lda #$06
    sta $7c06

    lda #219
    sta $69b3
    sta $69b4
    sta $69b5

    lda #$07
    sta $7c06

    lda #219
    sta $69b6
    sta $69b7
    sta $69b8

    lda #$08
    sta $7c06

    lda #219
    sta $69b9
    sta $69ba
    sta $69bb

    lda #$09
    sta $7c06

    lda #219
    sta $69bc
    sta $69bd
    sta $69be

    lda #$0a
    sta $7c06

    lda #219
    sta $69bf
    sta $69c0
    sta $69c1

    lda #$0b
    sta $7c06

    lda #219
    sta $69c2
    sta $69c3
    sta $69c4

    lda #$0c
    sta $7c06

    lda #219
    sta $69c5
    sta $69c6
    sta $69c7

    lda #$0d
    sta $7c06

    lda #219
    sta $69c8
    sta $69c9
    sta $69ca

    lda #$0e
    sta $7c06

    lda #219
    sta $69cb
    sta $69cc
    sta $69cd

    lda #$0f
    sta $7c06

    lda #219
    sta $69ce
    sta $69cf
    sta $69d0

    rts

heading1:
  .asciiz "Simple 6502 Based Computer"

initialize_fonts:

; Zero Page locations
FONT_PTR        = $00     ; 2 bytes

; Memory locations
FONT_PAGE       = $0200   ; 1 byte
FONT_VERT       = $0201   ; 1 byte
FONT_ASCII      = $0202   ; 1 byte

; Static values
FONT_LOAD       = %11010000
FONT_WRITE      = %11100000
DISPLAY_MODE    = %10010000

    ; Change to Font Load mode
    lda #FONT_LOAD
    sta FONT_CONTROL

    ; Loop through all ASCII characters and store them in Font RAM.
    ; 
    ; There will be 4096 total bytes written per style (256 characters * 16 bytes) 
    ; so we need to copy 16 pages of ROM into Font RAM for each one

    ; Initialize the Font bitmap pointer to ROM
    lda #<FONT_ASCII_DATA
    sta FONT_PTR
    lda #>FONT_ASCII_DATA
    sta FONT_PTR + 1

    ; Start the Font page/style at 0
    stz FONT_PAGE

    ; Start the Font vertical position at 0
    stz FONT_VERT

    ; Keep a separate location in memory to store the ASCII counter
    ; so we don't need to split addresses
    stz FONT_ASCII

vert_loop:
    ; Start this loop by clearing the carry flag
    clc

    ; Set the first 4 bits of the Font Address (A0-A3, corresponding to vertical section of the bitmap)
    lda FONT_VERT
    tay                     ; Save the current vertical index in Y for use as an offset to load bitmap data later
    ora #FONT_LOAD          ; OR with FONT_LOAD to preserve the 4 high control bits
                            ; but load in the 4 low bits from FONT_POS which are still in
                            ; the accumulator (since it keeps getting reset to 0 the high
                            ; bits will always be 0)
    sta FONT_CONTROL        ; Write result to the FONT_CONTROL register (ultimately we're
                            ; only writing the 4 low bits, which correspond to A0-A3 of
                            ; the Font Address)
    
    ; Set the next 8 bits of the Font Address (A4-A11, corresponding to 256 byte ASCII code of the character)
    ; placing them in the CHAR_WRI_L register
    lda FONT_ASCII
    sta CHAR_WRI_L 

    ; The final 3 bits are the page/style information, which are written to the CHAR_WRI_H register
    lda FONT_PAGE
    sta CHAR_WRI_H

    ; Next, write the actual data for this Page/ASCII/Line combination into the Font Data Buffer
    lda (FONT_PTR), Y

    ; Determine if manipulation needs to be performed for additional pages
    pha

    ; Check to see if this is the last vertical index AND this is the 'underline' style
    cpy #15
    bcc check_reverse       ; No, check the next setting
    lda #%00100000          ; Check to see if the 'underline' style is selected
    bit FONT_PAGE
    beq check_reverse       ; No, check the next setting

    ; This is the last vertical line of an underline character, replace the value on the stack with $ff
    pla
    lda #$ff
    pha

check_reverse:
    lda #%01000000          ; Check to see if the 'reverse' style is selected
    bit FONT_PAGE
    pla
    bne write_data          ; No, write the data

    ; Reverse the bit values
    eor #$ff
write_data:
    sta FONT_DATA

    ; Send a control signal to load the font, then switch back to load mode 
    tya                     ; Transfer Y (which still has the current vertical index value) into accumulator
                            ; and OR with FONT_WRITE control bits 
    ora #FONT_WRITE
    sta FONT_CONTROL
    lda #FONT_LOAD          ; Switch back to load mode
    sta FONT_CONTROL

    inc FONT_VERT           ; Increase the vertical line index

    cpy #15                 ; Is our current vertical line index at the last position?
    bcc vert_loop           ; No

    ; All vertical lines for this character have been captured; move on to the next ASCII code
    stz FONT_VERT           ; Reset the vertical counter

    ; Increase the position of the Font bitmap pointer
    lda FONT_PTR
    adc #16                 ; Each bitmap is 16 bytes
    sta FONT_PTR

    bcc increment_ascii     ; If there is no carry proceed with incrementing the ASCII character
    inc FONT_PTR + 1        ; Otherwise increase the page

increment_ascii:
    inc FONT_ASCII          ; Increase the ASCII code; if we've exceeded the max (255) the memory location
                            ; will be set to 0 and the Z flag set
    bne vert_loop           ; Additional ASCII characters need to be written, proceed back to the vertical loop

increment_style:
    ; All ASCII characters for this style have been written, move on to the next style

    ; Reset the Font bitmap pointer
    lda #<FONT_ASCII_DATA
    sta FONT_PTR
    lda #>FONT_ASCII_DATA
    sta FONT_PTR + 1

    lda FONT_PAGE
    adc #$20                ; Add $20 to affect only the 3 highest bits
    sta FONT_PAGE
    bcc vert_loop           ; If carry is not set continue back into the vertical counter loop

    ; Otherwise set display mode to on and exit
    lda DISPLAY_MODE
    sta FONT_CONTROL

    rts

.include "character_rom.asm"