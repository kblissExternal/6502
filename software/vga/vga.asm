VGA_RAM = $8000					; Video Memory (VGA)

SCREEN_WIDTH = 128				; Define pixel count of maximum VGA screen width
HALF_SCREEN_WIDTH = 64				; Half the value of SCREEN_WIDTH
SCREEN_HORIZ_OFFSET = 4				; Indent this number of pixels on each line to avoid running into garbage from vertical sync

; Define pixel color values
COLOR_BLACK	 = $00	; 0
COLOR_BLUE	 = $0a	; 10
COLOR_GREEN	 = $10	; 16
COLOR_LIME	 = $3f	; 63
COLOR_RED	 = $40	; 64
COLOR_PINK	 = $44	; 68
COLOR_YELLOW	 = $50	; 80
COLOR_WHITE	 = $54	; 84

; Clear out VGA memory
LIB_VGA_clear_vram:
    lda #<VGA_RAM
    sta Z0
    lda #>VGA_RAM
    sta Z1

    lda #$00 ; Data to load into each address
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

;================================================================================
;
;   LIB_VGA_draw_pixel - Draw a pixel to VGA memory using the given parameters
;
;   ������������������������������������
;   Preparatory Ops: @A: byte representing the color value to store for each pixel
;                    @Y: byte representing the width of the pixel
;                    @X: byte representing the height of the pixel
;
;   Returned Values: none
;
;   Destroys:       .A, X, Y
;   ������������������������������������
;
;================================================================================

LIB_VGA_draw_pixel:
    pha ; Temporarily push A to the stack so we can push CURSOR position from memory into Zero Page

    lda SCREEN_CURSOR
    sta Z0
    lda SCREEN_CURSOR + 1
    sta Z1

    pla ; Restore A from the stack (contains the pixel color to store in video memory)

; Columns of pixels are written first, from the maximum width decrementing back to the cursor location.
; A column of pixels is repeated for each row.

@rows:
    phy	; Push Y (width) to the stack so it can be restored once each set of columns is written to memory
@cols:
    sta (Z0), y	; Write A to the memory location and decrement Y; repeat until Y is 0
    dey
    bne @cols

    ply	; Restore the original value of Y (width) from the stack so it can be used in the next row

    ; If current cursor position is less than SCREEN_WIDTH, increment page 0 instead of 1 (by adding SCREEN_WIDTH)

    pha	; Temporarily save A (our pixel color) to the stack

    lda #SCREEN_WIDTH
    cmp Z0
    bcc @increment_memory_page	; Updating page 0 would overflow, so increment page 1

    adc Z0	; Add the accumulator (currently contains SCREEN_WIDTH) to page 0 and store it back in memory
    sta Z0
    dec Z0	; Unsure why this is required; after adding to bootloader it seemed like each new row was a pixel ahead

    bcs @increment_memory_page	; If adding SCREEN_WIDTH to the particular cursor location causes a carry, we still need to increment page 1

    pla			; Cursor location is set, we can proceed with completing this row of pixels
    jmp @proceed

@increment_memory_page:
    inc Z1

    ; If the last move of the cursor pushed out past the visible screen width we need to account for it
    lda #HALF_SCREEN_WIDTH
    cmp SCREEN_CURSOR
    bcs @skip_adjustment

    lda SCREEN_CURSOR 		; Subtract the SCREEN_WIDTH from the cursor (a hack, probably a better way of doing this)
    sbc #SCREEN_WIDTH
    sta SCREEN_CURSOR 
@skip_adjustment:
    lda SCREEN_CURSOR
    sta Z0

    pla
@proceed:
    dex		; Decrement the counter for this row
    bne @rows

    ; The row is complete, account for SCREEN_WIDTH
    lda Z0
    sbc #SCREEN_WIDTH
    bpl @update_cursor

    dec Z1
@update_cursor:
    ; Update CURSOR memory location with contents of zero page locations
    inc a	; Move the cursor forward one pixel to account for backtracking
    sta SCREEN_CURSOR
    dec Z1
    lda Z1
    sta SCREEN_CURSOR + 1

    rts

;   LIB_VGA_newline - move to the next horizontal line of text on the screen
LIB_VGA_newline:
    pha

    lda SCREEN_CURSOR + 1
    inc a
    inc a
    inc a
    sta SCREEN_CURSOR + 1

    ; If we've exceeded the maximum number of horizontal lines, clear the screen and start over
    cmp #$a5
    bcc @set_horiz_offset

    phy
    phx
    jsr LIB_VGA_clear_vram
    plx
    ply

    lda #>VGA_RAM
    sta SCREEN_CURSOR + 1

@set_horiz_offset:
    lda #SCREEN_HORIZ_OFFSET
    inc a
    sta SCREEN_CURSOR

    pla

    rts

;================================================================================
;
;   LIB_VGA_write_character - write the given ASCII character to VGA
;
;   ������������������������������������
;   Preparatory Ops: @X: byte representing the ASCII code of the character
;
;   Returned Values: none
;
;   Destroys:       .A, X, Y
;   ������������������������������������
;
;================================================================================

LIB_VGA_write_character:
    ; Set the initial value for SHIFT_COUNT
    lda #8
    sta SHIFT_COUNT

    ; Bits are stored by row, then column (i.e. row 0, col 0, row 0, col1, row 0, col2, etc)
    ; Start in the bottom right corner by incrementing page 1 once, then adding SCREEN_WIDTH
    lda SCREEN_CURSOR

    ; Start a new line if the pixel is at position 100 (either $64 or $e4)
@test_newline:
    cmp #$65
    bne @continue
    jsr LIB_VGA_newline

@continue:
    lda SCREEN_CURSOR
    sta Z0
    lda SCREEN_CURSOR + 1
    sta Z1

    inc Z1
    lda #SCREEN_WIDTH
    adc Z0
    sta Z0

    bcc @populate_shifters
    ; If carry flag is set we need to increment page 1 again
    inc Z1

@populate_shifters:
    ; Populate the shifters
    ldy CHARACTER_DATA_L, x
    sty CHARACTER_SHIFTER		; Top two rows
    ldy CHARACTER_DATA_H, x
    sty CHARACTER_SHIFTER + 1	; Bottom two rows
 
    ; Iterate over 4 rows and 4 columns, populating each depending on the settings of this character
    lda CHARACTER_COLOR
    ldx #4

@rows:
    ldy #3	; Reset the columns to 4 (zero index based)
@cols:
    lsr CHARACTER_SHIFTER
    ; lsr will set the Z flag before all 8 bits are shifted if the high bits are zeros?
    dec SHIFT_COUNT
    bne @skip_character_shifter_adjust

    ; Reset SHIFT_COUNT
    pha
    lda #8
    sta SHIFT_COUNT

    ; Push the second byte of the character shifter back to the first address
    lda CHARACTER_SHIFTER + 1
    sta CHARACTER_SHIFTER

    pla

@skip_character_shifter_adjust:
    bcc @store_zero

    sta (Z0), y
    jmp @finish_column

@store_zero:
    pha
    lda #$00
    sta (Z0), y
    pla

@finish_column:
    dey
    bpl @cols

    ; Determine if we need to decrement page 0 or page 1
    pha
    lda Z0
    cmp #SCREEN_WIDTH

    ; We need to decrement page 1 if cursor is less than SCREEN_WIDTH,
    ; or decrement page 0 if it's greater than or equal to.  CMP will
    ; set the Z flag on equal, C on less than or equal, and clear C on greater than
    beq @decrement_page_zero
    bcc @decrement_memory_page
@decrement_page_zero:
    sbc #SCREEN_WIDTH
    sta Z0

    bmi @decrement_memory_page
    jmp @proceed

@decrement_memory_page:
    dec Z1
    pha
    lda SCREEN_CURSOR
    adc #SCREEN_WIDTH
    sta Z0
    pla

@proceed:
    pla

    dex
    bne @rows

    ; Move the screen cursor by the offset amount
    lda #SCREEN_HORIZ_OFFSET
    adc SCREEN_CURSOR
    sta SCREEN_CURSOR

    rts

;================================================================================
;
;   LIB_VGA_write_string - write a complete null terminated string to VGA memory
;
;   ������������������������������������
;   Preparatory Ops: @A: LSN String Address
;                    @Y: MSN String Address
;
;   Returned Values: none
;
;   Destroys:       .A, X, Y
;   ������������������������������������
;
;================================================================================

LIB_VGA_write_string:
    ; The first two zero pages will be in use by the write_character subroutine, so we need to use Z2 and Z3
    sta Z2
    sty Z3

@loop:
    ldy #$00
@inner_loop:
    lda (Z2), y
    beq @return

    tax
    phy
    jsr LIB_VGA_write_character
    ply

    iny
    bne @inner_loop
    inc Z3
    jmp @inner_loop

@return:

    rts

.include "character_rom.asm"
