VRAM = $8000

; Memory Locations (zero page)
CURSOR_X = $fe
CURSOR_Y = $ff 

; System libraries
LIB_sleep               = $c064
LIB_VIA_initialize      = $c043
LIB_VIA_read_input      = $c03b
LIB_VGA_clear_vram      = $ea27

; Static values
COLOR_BLACK = $00
COLOR_WHITE = $ff

X_MAX = 101
Y_MAX = 76

; Hi/Lo Byte reference:
; VRAM = $8000
; lda #<VRAM ; Should evaluate to $00
; lda #>VRAM ; Should evaluate to $80

  .segment "CODE"

; Entry point
reset:
  ; Initialize the VIA and clear VRAM
  jsr initialize

  ; Set a default cursor position at the beginning of VRAM
  lda #<VRAM
  sta CURSOR_X
  lda #>VRAM
  sta CURSOR_Y

  ; Prime the cursor
  lda #COLOR_WHITE
  sta (CURSOR_X)

loop:
@wait_for_input:                                ; Handle keyboard input
    ldx #1
    lda #$ff                                    ; Debounce
    jsr LIB_sleep

    lda #0
    jsr LIB_VIA_read_input
    beq @wait_for_input
      
    cmp #$04
    beq @move_up                                ; UP key pressed
    cmp #$08
    beq @move_down                              ; DOWN key pressed
    cmp #$01
    beq @move_left                              ; RIGHT key pressed
    cmp #$02
    beq @move_right                             ; RIGHT key pressed

    lda #0
    jmp @wait_for_input

@move_up:
    lda #COLOR_BLACK                            ; Blank the cursor
    sta (CURSOR_X)

    inc CURSOR_Y
    cmp #Y_MAX                                  ; Has the cursor position moved past the bottom of the screen?
    bne @draw                                   ; No, proceed with drawing pixel, otherwise reset Y position

@reset_y_cursor:
    lda #>VRAM
    sta CURSOR_Y

    jmp @draw
@move_down:
    lda #COLOR_BLACK                            ; Blank the cursor
    sta (CURSOR_X)

    dec CURSOR_Y
    bpl @draw                                   ; Has the cursor position moved past the top of the screen?

    lda #Y_MAX - 1
    sta CURSOR_Y

    jmp @draw
@move_left:
    lda #COLOR_BLACK                            ; Blank the cursor
    sta (CURSOR_X)

    dec CURSOR_X
    bpl @draw                                   ; Has the cursor position moved past the left side of the screen?

    lda #X_MAX - 1
    sta CURSOR_X

    jmp @draw
@move_right:
    lda #COLOR_BLACK                            ; Blank the cursor
    sta (CURSOR_X)

    inc CURSOR_X
    cmp #X_MAX                                  ; Has the cursor position moved past the right side of the screen?
    bne @draw                                   ; No, proceed with drawing pixel, otherwise reset X position

    lda #<VRAM
    sta CURSOR_X

    inc CURSOR_Y                                ; In this case increment the Y cursor position nas well
    cmp #Y_MAX                                  ; Ensure we haven't moved past the bottom of the screen
    beq @reset_y_cursor

@draw:
  lda #COLOR_WHITE
  sta (CURSOR_X)

  lda #0                                      ; explicitly setting A is a MUST here
  jmp @wait_for_input

; Initialize the VIA and clear VRAM
initialize:
  jsr LIB_VGA_clear_vram
  jsr LIB_VIA_initialize

  rts
