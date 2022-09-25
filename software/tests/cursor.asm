VIDEO_RAM = $8000

; Zero page locations
Z0 = $00
Z1 = $01
Z2 = $02
Z3 = $03

; Memory Locations
CURSOR = $0400			; 2 bytes
WIDTH  = $0402			; 1 byte
HEIGHT = $0403			; 1 byte

VALUE_TO_DECODE = $0404		; 2 bytes
MOD10           = $0406		; 2 bytes
DECODED_VALUE   = $0408		; 6 bytes

; Static values
SCREEN_WIDTH      = 127
HALF_SCREEN_WIDTH = 64
COLOR_BLACK	      = $00
COLOR_PINK	      = $44

; System libraries
LIB_VIA_read_input      = $c255
LIB_LCD_clear           = $c264
LIB_LCD_initialize      = $c276
LIB_LCD_print           = $c28d
LIB_sleep               = $c3a0
LIB_ACIA_initialize     = $c455
LIB_ACIA_tx             = $c499
LIB_VGA_clear_vram      = $e2d6

; Hi/Lo Byte reference:
; VIDEO_RAM = $8000
; lda #<VIDEO_RAM ; Should evaluate to $00
; lda #>VIDEO_RAM ; Should evaluate to $80

  .segment "CODE"
  

; Entry point
reset:
  ; Initialize the LCD and clear VRAM
  jsr initialize

  ; Set a default width and height of 5 for the test pattern
  lda #5
  sta WIDTH
  lda #5
  sta HEIGHT

  ; Prime the first image
  lda #<VIDEO_RAM
  sta CURSOR
  lda #>VIDEO_RAM
  sta CURSOR + 1

  lda #COLOR_PINK
  ldy WIDTH
  ldx HEIGHT
  jsr draw_line

loop:
@wait_for_input:                                ; Handle keyboard input
    ldx #4
    lda #$ff                                    ; Debounce
@wait:
    jsr LIB_sleep
    dex
    bne @wait

    lda #0
    jsr LIB_VIA_read_input
    beq @wait_for_input                         ; no
      
@handle_keyboard_input:
    cmp #$04
    beq @move_up                                ; UP key pressed
    cmp #$08
    beq @move_down                              ; DOWN key pressed
    cmp #$01
    beq @move_left                              ; RIGHT key pressed
    cmp #$02
    beq @move_right                             ; RIGHT key pressed
    lda #0                                      ; explicitly setting A is a MUST here
    jmp @wait_for_input                         ; and go around

@move_up:
    jsr clear_cursor
    dec HEIGHT
    jmp @draw
@move_down:
    inc HEIGHT
    jmp @draw
@move_left:
    jsr clear_cursor
    dec WIDTH
    jmp @draw
@move_right:
    inc WIDTH
@draw:
  lda #<VIDEO_RAM
  sta CURSOR
  lda #>VIDEO_RAM
  sta CURSOR + 1

  ; Print current coordinates to UART

  lda #COLOR_PINK
  ldy WIDTH
  ldx HEIGHT
  jsr draw_line

  lda #0                                      ; explicitly setting A is a MUST here
  jmp @wait_for_input

clear_cursor:
  lda #<VIDEO_RAM
  sta CURSOR
  lda #>VIDEO_RAM
  sta CURSOR + 1

  lda #COLOR_BLACK
  ldy WIDTH
  ldx HEIGHT
  jsr draw_line

  rts

; Initialize the display
initialize:
  jsr LIB_LCD_initialize
  jsr LIB_LCD_clear

  lda #<load_message
  ldy #>load_message

  jsr LIB_LCD_print

  jsr LIB_ACIA_initialize

  ; Clear VRAM
  jsr LIB_VGA_clear_vram

  rts

; Draw a line using the color in A, a width of Y, and a height of X

draw_line:
  pha ; Temporarily push A to the stack so we can push CURSOR position from memory into Zero Page

  lda CURSOR
  sta Z0
  lda CURSOR + 1
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

  sta (Z0), y	; Add one last pixel

  ply	; Restore the original value of Y (width) from the stack so it can be used in the next row

  ; If current cursor position is less than SCREEN_WIDTH, increment page 0 instead of 1 (by adding SCREEN_WIDTH)

  pha	; Temporarily save A (our pixel color) to the stack

  lda #SCREEN_WIDTH
  cmp Z0
  bcc @increment_memory_page	; Updating page 0 would overflow, so increment page 1

  adc Z0	; Add the accumulator (currently contains SCREEN_WIDTH) to page 0 and store it back in memory
  sta Z0

  bcs @increment_memory_page	; If adding SCREEN_WIDTH to the particular cursor location causes a carry, we still need to increment page 1

  pla			; Cursor location is set, we can proceed with completing this row of pixels
  jmp @proceed

@increment_memory_page:
  inc Z1

  ; If the last move of the cursor pushed out past the visible screen width we need to account for it
  lda #HALF_SCREEN_WIDTH
  cmp CURSOR
  bcs @skip_adjustment

  lda CURSOR 		; Subtract the SCREEN_WIDTH from the cursor (a hack, probably a better way of doing this)
  sbc #SCREEN_WIDTH
  sta CURSOR 
@skip_adjustment:
  lda CURSOR
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
  sta CURSOR
  dec Z1
  lda Z1
  sta CURSOR + 1

  rts

load_message:
    .asciiz "Waiting for input..."
