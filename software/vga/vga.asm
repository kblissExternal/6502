;================================================================================
; Zero Page Locations
;================================================================================
FONT_PTR        = $E4     ; 2 bytes

;================================================================================
; Memory Locations
;================================================================================
VRAM                 = $6000
VRAM_START           = $6114
VRAM_LAST_S          = $6f94
VRAM_LAST_E          = $6fdd

FONT_LINE            = END_OF_RAM - 1   ; 1 byte
CURRENT_FONT         = END_OF_RAM - 2   ; 1 byte
FONT_COUNTER         = END_OF_RAM - 3   ; 1 byte
VRAM_CURSOR          = END_OF_RAM - 5   ; 2 bytes
FONT_PAGE            = END_OF_RAM - 6   ; 1 byte
FONT_VERT            = END_OF_RAM - 7   ; 1 byte
FONT_ASCII           = END_OF_RAM - 8   ; 1 byte

;================================================================================
; VGA Registers
;================================================================================
FONT_CONTROL    = $7c00
FONT_DATA       = $7c01
CHAR_ADDR_H     = $7c02
CHAR_ADDR_L     = $7c03
CHAR_WRI_H      = $7c06
CHAR_WRI_L      = $7c07

;================================================================================
; Static values
;================================================================================
FONT_LOAD       = %10110000
FONT_WRITE      = %01110000
DISPLAY_MODE    = %10100000

COLOR_WHITE          = $0f
COLOR_YELLOW         = $0d
CHARACTER_LINES      = 73
CHARACTER_ROWS       = 30
BYTES_PER_ROW        = 127

; Clear character RAM
LIB_VGA_clear_ram:
    pha
    phx
    phy

    ldx #16         ; Clear 16 pages of RAM
    lda #>VRAM
    sta Z1

@clear_block:
    lda #<VRAM
    sta Z0
    ldy #$ff
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

    ply
    plx
    pla
    
    rts

; Clear the screen and reset the character cursor
LIB_VGA_initialize:
    lda #COLOR_WHITE
    sta CHAR_WRI_H

    jsr LIB_VGA_clear_ram

    lda #<VRAM_START
    sta VRAM_CURSOR
    lda #>VRAM_START
    sta VRAM_CURSOR + 1

    rts

; Put a single character (stored in A) on the screen at the current cursor position
LIB_VGA_put:
    pha

    ; Test if this is a printable character
    cmp #8
    bcs @check_line_feed
    jmp @done

; Test if this is a new line character (ignore LF, only act on CR)
@check_line_feed:
    cmp #10
    bne @check_cr
    jmp @done
@check_cr:
    cmp #13
    beq @newline
    jmp @continue

@newline:
    ; Move the cursor down one line
    lda VRAM_CURSOR
    cmp #$5d
    bcs @increment_cursor_page

    lda #<VRAM_LAST_S
    sta VRAM_CURSOR
    jmp @done

@increment_cursor_page:
    lda #<VRAM_START
    sta VRAM_CURSOR
    inc VRAM_CURSOR + 1
    jmp @test_end_screen

@continue:
    pha
    lda VRAM_CURSOR
    sta Z0
    lda VRAM_CURSOR + 1
    sta Z1
    pla

    sta (Z0)

    ; Increment the cursor position
    inc VRAM_CURSOR

    ; Check to see if the cursor is past the last character in a line
    lda #<VRAM_LAST_E
    sbc #$80
    cmp VRAM_CURSOR

    bne @next
    lda #<VRAM_START
    sta VRAM_CURSOR
    inc VRAM_CURSOR + 1
    jmp @test_end_screen

@next:
    adc #$80
    cmp VRAM_CURSOR

    bne @done

    inc VRAM_CURSOR + 1

@test_end_screen:
    ; Test if we've gone past the end of the screen
    lda #>VRAM_LAST_S
    cmp VRAM_CURSOR + 1

    bcs @done

    jsr LIB_VGA_scroll_screen

@done:
    pla

    rts

; The cursor has reached the end of the screen; we need to move everything up one line
LIB_VGA_scroll_screen:
    pha
    phy
    phx

    lda #<VRAM_START
    sta Z0
    adc #$80
    sta Z2
    lda #>VRAM_START
    sta Z1
    sta Z3

    ; Loop through to copy the number of rows - 2 (the last two must be handled differently)
    ldx #28
@outer_loop:
    clc
    ldy #BYTES_PER_ROW
@inner_loop:
    lda (Z2), Y
    sta (Z0), Y
    dey
    bpl @inner_loop

    dex
    beq @done

    lda Z2
    cmp Z0
    sta Z0
    bcc @mode2
    inc Z3
    sbc #$80
    sta Z2
    jmp @outer_loop

@mode2:
    inc Z1
    sbc #BYTES_PER_ROW
    sta Z2
    jmp @outer_loop

@done:
    ; Handle the last two lines
    inc Z1
    ldy #$6b
@last_line_loop:
    lda (Z0), Y
    sta (Z2), Y
    dey
    bpl @last_line_loop

    lda #$00
    ldy #$6b
@blank_last_line_loop
    sta (Z0), Y
    dey
    bne @blank_last_line_loop

    sta (Z0), Y
    lda Z0
    sta VRAM_CURSOR
    lda Z1
    sta VRAM_CURSOR + 1

    plx
    ply
    pla

    rts

; Print a test pattern
LIB_VGA_test_pattern:
    jsr LIB_VGA_clear_ram

    ; Set the default font and color
    lda #COLOR_WHITE
    sta CHAR_WRI_H
    sta CURRENT_FONT

    ; Print screen borders
    jsr LIB_VGA_print_absolute_borders

    ; Print heading text
    lda #<VRAM_START
    adc #153                 ; Move right and down
    sta Z0
    lda #>VRAM_START
    sta Z1

    lda #<heading1
    sta Z2
    lda #>heading1
    sta Z3
    
    jsr LIB_VGA_print_text

    ; Change the font color to Yellow for character sets
    lda #COLOR_YELLOW
    sta CHAR_WRI_H
    sta CURRENT_FONT

    ; Print G0 Character set
    jsr LIB_VGA_print_g0_charset
    
    ; Print G1 Character set
    ;jsr LIB_VGA_print_g1_charset

    ; Change the font color back to White
    lda #COLOR_WHITE
    sta CHAR_WRI_H
    sta CURRENT_FONT

    ; Print color set
    jsr LIB_VGA_print_colors

    ; Reset to the default font / color
    lda #COLOR_WHITE
    sta CHAR_WRI_H
    sta CURRENT_FONT

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
    lda #<VRAM_LAST_S
    sta Z0
    lda #>VRAM_LAST_S
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
    lda #<VRAM_LAST_S
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

; Print out each Font set
LIB_VGA_print_g0_charset:
    clc

    ; Position the 'cursor' for the first run
    lda #>VRAM_START
    adc #1              ; 3 lines from the top of the screen
    sta Z1
    lda #<VRAM_START
    adc #7              ; 5 characters from the left of the screen
    sta Z0

    ; Setup the initial font
    lda CURRENT_FONT
    sta FONT_COUNTER

    ldx #0
@font_set_loop:
    ; Switch back to the default font
    lda CURRENT_FONT
    sta CHAR_WRI_H

    ; Print out the identifier of this Font Set
    clc
    lda Z0
    pha
    lda #$97
    sta Z0
    inc Z1

    lda #48
    sta (Z0)
    inc Z0
    txa
    adc #48
    sta (Z0)

    pla
    sta Z0
    dec Z1
    clc

    phx
    ; Print out the box
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
    clc
    ldy #$41    ; Distance between corners

    ; Move the 'cursor' up and one character right to plot the corners 
    lda Z1
    sbc #3
    sta Z1
    inc Z0

    lda #218
    sta (Z0)
    lda #191
    sta (Z0), Y

    clc
    ; Move the 'cursor' down
    lda Z1
    adc #2
    sta Z1
    lda Z0
    adc #$80
    sta Z0

    lda #192
    sta (Z0)
    lda #217
    sta (Z0), Y

; Print sides
    ; Move the 'cursor' again
    clc
    lda Z0
    sbc #BYTES_PER_ROW
    sta Z0

    ldx #4
@print_side_loop:
    clc
    lda #179
    sta (Z0)
    sta (Z0), Y

    lda Z0
    sbc #BYTES_PER_ROW
    sta Z0

    bpl @side_loop_next

    dec Z1
@side_loop_next:
    dex
    bne @print_side_loop

; Print the characters for this font set

; Move the cursor down and right
    clc
    lda Z0
    adc #$81
    sta Z0

    stz FONT_LINE

    ldx #4
@line_loop:
    ldy #$3f

    lda FONT_COUNTER
    sta CHAR_WRI_H
@character_loop:
    tya
    adc FONT_LINE
    sta (Z0), Y
    dey
    bpl @character_loop

    inc Z0                  ; Move the cursor one character to make addition easier
    lda Z0
    adc #BYTES_PER_ROW
    sta Z0

    bcc @increment_line_loop
    inc Z1

@increment_line_loop;
    lda #$3f
    adc FONT_LINE
    sta FONT_LINE
    dex
    bne @line_loop

    ; End of loops for an individual font set; restore X from the stack and decrement
    plx
    inx
    cpx #4
    beq @exit

    ; Increment the cursor
    clc
    lda Z0
    adc #BYTES_PER_ROW
    sta Z0
    inc Z0

    bcc @continue_font_set_loop
    inc Z1

@continue_font_set_loop:
    ; Increment the font set
    clc
    lda FONT_COUNTER
    adc #$10
    sta FONT_COUNTER

    jmp @font_set_loop

@exit:

    rts

LIB_VGA_print_colors:
    ; Print number values for each color
    lda #>VRAM_LAST_S
    sta Z1
    lda #<VRAM_LAST_S
    sbc #BYTES_PER_ROW
    adc #12              ; Move the cursor right
    sta Z0

    lda #<color_identifiers
    sta Z2
    lda #>color_identifiers
    sta Z3
    
    jsr LIB_VGA_print_text

    ; Colors
    
    dec Z1
    lda Z0
    adc #BYTES_PER_ROW 
    adc #30              ; Move the cursor right
    sta Z0
    clc

    ldy #$0f
@color_loop:
    tya
    sta CHAR_WRI_H

    ; Print each color three times
    lda #219
    sta (Z0), Y
    inc Z0
    sta (Z0), Y
    inc Z0
    sta (Z0), Y

    dec Z0
    dec Z0
    dec Z0
    dec Z0

    dey
    bpl @color_loop

    rts

LIB_VGA_circleman:
    ; Clear the RAM and change the default color to yellow
    jsr LIB_VGA_clear_ram
    lda #COLOR_YELLOW
    sta CHAR_WRI_H

    lda #$10
    sta Z0
    lda #$65
    sta Z1

    ; $e6 = back half
    ; $e7 = front half (mouth closed)
    ; $e8 = front half (mouth open)

    ; Move circle man to the far right side of the screen
    ldx #0
    ldy #2
@move_right_loop:
    phy
    phx
    ; Delay
    ldx $0300
@delay_outer:
    ldy $0301
@delay_inner:
    nop
    nop
    dey
    bne @delay_inner
    dex
    bne @delay_outer

    plx
    ply

    ; Clear any previous tracks
    lda #$00
    dey
    sta (Z0), Y
    dey
    sta (Z0), Y
    iny
    iny

    ; Print back half
    lda #$e6
    sta (Z0), Y
    iny

    ; Print front half
    inx
    txa
    lsr A
    bcc @print_mouth_open
    lda #$e7
    jmp @print_front_half
@print_mouth_open
    lda #$e8
@print_front_half
    sta (Z0), Y

    iny
    cpy #BYTES_PER_ROW
    bcc @move_right_loop

    rts

heading1:
  .asciiz "Simple 6502 Based Computer"
color_identifiers:
  .asciiz " 0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15"

initialize_fonts:
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
    adc #15                 ; Each bitmap is 16 bytes
    sta FONT_PTR

    bcc increment_ascii     ; If there is no carry proceed with incrementing the ASCII character
    inc FONT_PTR + 1        ; Otherwise increase the page

increment_ascii:
    inc FONT_ASCII          ; Increase the ASCII code; if we've exceeded the max (255) the memory location
                            ; will be set to 0 and the Z flag set
    bne vert_loop           ; Additional ASCII characters need to be written, proceed back to the vertical loop

    ; Set display mode to on and exit
    lda DISPLAY_MODE
    sta FONT_CONTROL

    rts

font_test:
    lda #FONT_LOAD
    sta FONT_CONTROL

    ldy #$0f
@loop:
    lda #$00
    sta CHAR_WRI_H
    lda #$00
    sta CHAR_WRI_L

    lda #$ff
    sta FONT_DATA

    tya
    ora #FONT_WRITE
    sta FONT_CONTROL

    dey
    bpl @loop

    lda #DISPLAY_MODE
    sta FONT_CONTROL

    rts

.include "character_rom.asm"