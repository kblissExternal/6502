;================================================================================
; Basic boot ROM for 6502 prototype
;
; Author:	Korey Bliss
;
; https://github.com/kblissExternal/6502
;
; Revision History:
;
;	2022-08-22	First commit.
;================================================================================

; Enable syntax features
  .feature labels_without_colons
  .feature c_comments
  .feature loose_char_term

; Zero page locations
Z0 = $00                                        
Z1 = $01
Z2 = $02
Z3 = $03

;================================================================================
; Common
;================================================================================
WAIT_C = $18                                    ; Sleep multiplier

;================================================================================
; VIA
;================================================================================
PORTB = $6000                                   ; VIA port B
PORTA = $6001                                   ; VIA port A
DDRB = $6002                                    ; Data Direction Register B
DDRA = $6003                                    ; Data Direction Register A
IER = $600e                                     ; VIA Interrupt Enable Register

E =  %10000000
RW = %01000000
RS = %00100000

;================================================================================
; VGA
;================================================================================
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

;================================================================================
; Memory Locations
;================================================================================
PROGRAM_LOCATION = $0200                      	; Memory location for user programs

END_OF_RAM = $3fde

SHIFT_COUNT = CHARACTER_COLOR - 1		; Counts VGA character shifts (1 byte)
CHARACTER_COLOR = CHARACTER_SHIFTER - 1		; Stores VGA character color (1 byte)
CHARACTER_SHIFTER = SCREEN_CURSOR - 2		; Tracks VGA character shifting (2 bytes)
SCREEN_CURSOR = WAIT - 2			; Stores VGA cursor position (2 bytes)
WAIT = POSITION_MENU - 1			; Stores current wait count for sleep function (1 byte)
POSITION_MENU = POSITION_CURSOR - 1           	; Position for LCD menu (1 byte)
POSITION_CURSOR = LCD_RAM - 1                 	; Position for LCD cursor (1 byte)
LCD_RAM = END_OF_RAM - 32                       ; RAM for LCD display (32 bytes)

.segment "CODE"

;   main - Initialize the bootloader
main:
    jsr LIB_run_basic

    ldx #$ff                                    ; Initialize the stackpointer with 0xff
    txs

    jsr LIB_LCD_initialize			; Initialize the LCD display and clear the screen
    jsr LIB_LCD_clear

    lda #<message0                          	; Display the boot screen
    ldy #>message0
    jsr LIB_LCD_print

    ldx #$20                                    ; Brief delay
    lda #$ff
@wait:
    jsr LIB_sleep
    dex
    bne @wait

    jsr main_menu                               ; Display the menu
    jmp main                                    ; Restart if we ever end up back here

;   main_menu - Render the primary menu on the LCD
main_menu:
    lda #0                                      ; Initialize menu and cursor positions
    sta POSITION_MENU
    sta POSITION_CURSOR

    jmp @begin
@MAX_SCREEN_POS:                                ; define some constants in ROM     
    .byte $06                                   ; Number of menu items - 2
@OFFSETS:
    .byte $00, $10, $20, $30, $40, $50, $60     ; Offsets for each menu item
@begin:
    jsr LIB_LCD_clear
    ldx POSITION_MENU
    ldy @OFFSETS,X				; Load first offset into Y
    ldx #0
@loop:
    lda menu_items,Y                            ; Load character for index Y
    sta LCD_RAM,X                             ; Store in LCD memory at X
    iny
    inx
    cpx #$20                                    ; Repeat 32 times
    bne @loop

@render_cursor:                                 ; Render cursor position
    lda #">"
    ldy POSITION_CURSOR
    bne @move_cursor_down
    sta LCD_RAM
    jmp @render

@move_cursor_down:
    sta LCD_RAM + $10

@render:
    jsr LIB_LCD_display

; Handle VIA input
@wait_for_input:
    ldx #4
    lda #$ff
@wait:
    jsr LIB_sleep				; Brief delay
    dex
    bne @wait

    lda #0
    jsr LIB_VIA_read_input
    beq @wait_for_input                         ; No buttons were pressed
      
; In the main menu the user can move up, down, or right to select an item
@handle_input:
    cmp #$01    
    beq @move_up                                ; UP key pressed
    cmp #$02
    beq @move_down                              ; DOWN key pressed
    cmp #$08
    beq @move_right                             ; RIGHT key pressed
    lda #0                                      ; Must set A back to 0
    jmp @wait_for_input                         ; Wait for futher input

@move_up:
    lda POSITION_CURSOR                         ; Load cursor position
    beq @dec_menu_offset                        ; Is cursor in up position
    lda #0
    sta POSITION_CURSOR                         ; Set cursor in up position
    jmp @begin                                  ; Render the menu
@dec_menu_offset:
    lda POSITION_MENU
    beq @wait_for_input                         ; Render the menu
@decrease:
    dec POSITION_MENU                           ; Decrease menu position by one
    jmp @begin                                  ; Render the menu

@move_down:
    lda POSITION_CURSOR                         ; Load cursor position
    cmp #1                                      ; Is cursor in down position
    beq @inc_menu_offset
    lda #1
    sta POSITION_CURSOR                         ; Set cursor in down position
    jmp @begin                                  ; Render the menu
@inc_menu_offset:
    lda POSITION_MENU                           ; Load menu position
    cmp @MAX_SCREEN_POS                         ; Check to see if we're at the bottom of the menu
    bne @increase
    jmp @wait_for_input
@increase:
    adc #1                                      ; Increase menu position
    sta POSITION_MENU
    jmp @begin                                  ; Render the menu

@move_right:
    clc
    lda #0
    adc POSITION_MENU
    adc POSITION_CURSOR                         ; Determine the selected index
    cmp #0                                      ; Choose the appropriate option
    beq @run_basic
    cmp #1
    beq @load
    cmp #2
    beq @load_vram
    cmp #3
    beq @run
    cmp #4
    beq @monitor
    cmp #5
    beq @clear_ram
    cmp #6
    beq @clear_vram
    cmp #7
    beq @about
    jmp @end                                    ; Restart

    jsr LIB_LCD_clear
@run_basic:
    lda #<message5
    ldy #>message5
    jsr LIB_LCD_print

    jsr LIB_run_basic
    jmp @begin
@load:
    ; Set X and Y to the address for user programs
    ldx #<PROGRAM_LOCATION
    ldy #>PROGRAM_LOCATION
    jsr do_load

    jmp @begin
@load_vram:
    ; Set X and Y to the address for VGA_RAM
    ldx #<VGA_RAM
    ldy #>VGA_RAM
    jsr do_load

    jmp @begin
@run:
    jmp do_execute
    jmp @begin
@monitor:
    ; Start the monitor at the address for user programs
    lda #<PROGRAM_LOCATION
    ldy #>PROGRAM_LOCATION
    jsr do_monitor
    jmp @begin
@clear_ram:
    lda #<message4
    ldy #>message4
    jsr LIB_LCD_print

    jsr do_clear_ram
    jmp @begin
@clear_vram:
    lda #<message4
    ldy #>message4
    jsr LIB_LCD_print

    jsr LIB_VGA_clear_vram
    jmp @begin
@about:
    lda #<about
    ldy #>about
    ldx #3
    jsr LIB_LCD_print_scrollable
    jmp @begin
@end:
    jmp @begin

; Load data via XMODEM into the address locations specified by X and Y
do_load:
    phx
    phy

    ; Clear the LCD and display the waiting message
    jsr LIB_LCD_clear
    lda #<message1
    ldy #>message1
    jsr LIB_LCD_print

    ply
    plx
    stx Z0
    sty Z1

    ;lda #$ff                                    ; Brief delay
    ;jsr LIB_sleep

    ; Call the transfer subroutine
    jsr LIB_ACIA_rx_xmodem

    ; Clear the LCD and display the completed message
    jsr LIB_LCD_clear
    lda #<message2
    ldy #>message2
    jsr LIB_LCD_print

    rts

; Transfer execution to the address for user programs
do_execute:
    sei                                  ; Disable interups
    jsr LIB_LCD_clear
    lda #<message3
    ldy #>message3
    jsr LIB_LCD_print

    jmp PROGRAM_LOCATION

;   Clears RAM from $0200 up to $3fff
do_clear_ram:
    ldy #<PROGRAM_LOCATION                      ; Load location for user programs into zero page
    sty Z0
    lda #>PROGRAM_LOCATION
    sta Z1
    lda #$00                                    ; Clearing byte
@loop:
    sta (Z0),Y
    iny
    bne @loop    
    inc Z1
    bit Z1                                      ; V is set (= $40)
    bvs @loop

    rts

; View data in computer's address space
do_monitor:
    ; Starting location was stored in A and Y
    sta Z0
    sty Z1

@render_current_ram_location:
    jsr LIB_LCD_clear

    lda #$00                                    ; Select upper row of video ram
    sta Z3
    jsr @transform_contents                     ; Load and transform RAM and address bytes

    clc                                         ; Add offset to address
    lda Z0
    adc #$04
    sta Z0
    bcc @skip
    inc Z1

@skip:    
    lda #$01                                    ; Select lower row of LCD RAM
    sta Z3
    jsr @transform_contents                     ; Load and transform RAM and address bytes into that location

    jsr LIB_LCD_display

@wait_for_input:                                ; Wait for input
    ldx #$04                                    ; Debounce
@wait:
    lda #$ff                                    
    jsr LIB_sleep
    dex
    bne @wait

    lda #0
    jsr LIB_VIA_read_input
    beq @wait_for_input                         ; Wait again if no key was pressed
 
@handle_input:
    cmp #$01    
    beq @move_up                                ; UP key pressed
    cmp #$02
    beq @move_down                              ; DOWN key pressed
    cmp #$04
    beq @exit					; LEFT key pressed
    cmp #$08
    beq @page_down                           	; RIGHT key pressed
    lda #0
    jmp @wait_for_input
@exit:
    lda #0
    rts

@move_down:
    jmp @render_current_ram_location            ; Address is already correct
@move_up:
    sec                                         ; Decrease the 16bit RAM pointer
    lda Z0
    sbc #$08
    sta Z0
    lda Z1
    sbc #$00
    sta Z1
    jmp @render_current_ram_location            ; Render
@page_down:                                  	; Add $0800 to current RAM location
    sec
    lda Z0
    adc #$00
    sta Z0
    lda Z1
    adc #$04
    sta Z1
    jmp @render_current_ram_location            ; Render
@transform_contents:                            ; Read address and RAM into stack
    ldy #3
@iterate_ram:                                   ; Transfer 4 RAM bytes to stack
    lda (Z0),Y
    pha
    dey
    bne @iterate_ram
    lda (Z0),Y
    pha

    lda Z0                                      ; Transfer the matching address bytes to stack
    pha
    lda Z1 
    pha

    ldy #0
@iterate_stack:                                 ; Transform stack contents from binary to hex
    cpy #6
    beq @end
    sty Z2                                      ; Preserve Y
    pla
    jsr bin_to_hex
    ldy Z2                                      ; Restore Y
    pha                                         ; Push least significant nibble (LSN) onto stack
    txa
    pha                                         ; Push most significant nibble (MSN) onto stack

    tya                                         ; Calculate nibble positions in LCD RAM
    adc position_map, Y
    tax
    pla
    jsr @store_nibble                           ; Store MSN to video ram
    inx
    pla
    jsr @store_nibble                           ; Store LSN to video ram

    iny
    jmp @iterate_stack                          ; Repeat for all 6 bytes on stack
; Store nibbles in two LCD rows
@store_nibble:
    pha
    lda Z3
    beq @store_upper_line                       ; Upper line
    pla                                         ; Lower line
    sta LCD_RAM + $10, X
    jmp @end_store
@store_upper_line:                               ; Upper line storage
    pla
    sta LCD_RAM,X
@end_store:
    rts
@end:
    lda #":"
    sta LCD_RAM + $4
    sta LCD_RAM + $14

    rts

;================================================================================
; VIA Functions
;================================================================================

; Return key presses from the attached buttons
LIB_VIA_read_input:
    lda PORTA                                   ; Load current status from VIA
    ror
    and #$0f                                    ; Ignore the first 4 bits
    eor #$0f

    rts

; Initialize the VIA
LIB_VIA_initialize:
    stx DDRA                                    ; Configure data direction for port A
    sta DDRB                                    ; Configure data direction for port B

    rts

;================================================================================
; LCD Functions
;================================================================================

; Clear the RAM location used by the LCD
LIB_LCD_clear:
    ; Push A and Y to the stack
    pha
    phy
    ldy #$20                                    ; Set index to 32
    lda #$20                                    ; Set character to 'space'
@loop:
    sta LCD_RAM,Y
    dey
    bne @loop

    ; Write the last byte
    sta LCD_RAM

    ; Restore values from the stack
    ply
    pla

    rts

;   Initializes the LCD display
LIB_LCD_initialize:
    lda #%11111111                              ; Set all pins on port B to output
    ldx #%11100000                              ; Set top 3 pins and bottom ones to on port A to output, 5 middle ones to input
    jsr LIB_VIA_initialize

    lda #%00111000                              ; Set 8-bit mode, 2-line display, 5x8 font
    jsr LIB_LCD_tx_cmd

    lda #%00001110                              ; Display on, cursor on, blink off
    jsr LIB_LCD_tx_cmd
    
    lda #%00000110                              ; Increment and shift cursor, don't shift display
    jmp LIB_LCD_tx_cmd

    rts

; Print a string to the LCD with no offset
LIB_LCD_print:
    ldx #0                                    ; Set a default offset of 0
    jsr LIB_LCD_print_offset

    rts

; Print a string to the LCD with an offset
LIB_LCD_print_offset:
STRING_ADDRESS_PTR = Z0
    sta STRING_ADDRESS_PTR
    sty STRING_ADDRESS_PTR + 1
    stx Z2
    ldy #0
@loop:
    clc
    tya
    adc Z2
    tax
    lda (STRING_ADDRESS_PTR), Y
    beq @return
    sta LCD_RAM, X
    iny
    jmp @loop
@return:
    jsr LIB_LCD_display		; Render

    rts

;   Transfers LCD RAM contents onto the display
LIB_LCD_display:
    lda #%10000000                              ; Force cursor to first line
    jsr LIB_LCD_cursor_line1                         
    ldx #0
@write_char:                                    ; Start writing chars from video ram
    lda LCD_RAM, X
    cpx #$10
    beq @next_line
    cpx #$20
    beq @return
    jsr LIB_LCD_tx_data
    inx
    jmp @write_char
@next_line:
    jsr LIB_LCD_cursor_line2
    jsr LIB_LCD_tx_data
    inx
    jmp @write_char
@return:

    rts

; Print scrollable text to the LCD
LIB_LCD_print_scrollable:
    sta Z0
    sty Z1
    dex
    stx Z2
@CURRENT_PAGE = Z3
    lda #0
    sta Z3
@render_page:
    jsr LIB_LCD_clear                    ; Clear video ram
    ldy #0
@render_chars:
    lda (Z0), Y
    cmp #$00
    beq @do_render
    sta LCD_RAM, Y
    iny
    bne @render_chars
@do_render:
    jsr LIB_LCD_display                  ; Render

@wait_for_input:
    ldx #4
@wait:
    lda #$ff                             ; Debounce
    jsr LIB_sleep
    dex
    bne @wait

    lda #0
    jsr LIB_VIA_read_input
    bne @handle_input
    jmp @wait_for_input

@handle_input:
    cmp #$01    
    beq @move_up                                ; UP key pressed
    cmp #$02
    beq @move_down                              ; DOWN key pressed
    cmp #$04
    beq @exit                                   ; LEFT key pressed
    lda #0
    jmp @wait_for_input
@exit:

    rts
@move_up:
    lda @CURRENT_PAGE
    beq @wait_for_input

    dec @CURRENT_PAGE

    sec
    lda Z0
    sbc #$20
    sta Z0
    bcs @skipdec
    dec Z1
@skipdec:    
    jmp @render_page                            ; Render

@move_down:
    lda @CURRENT_PAGE
    cmp Z2
    beq @wait_for_input

    inc @CURRENT_PAGE

    clc
    lda Z0
    adc #$20
    sta Z0
    bcc @skipinc
    inc Z1
@skipinc:
    jmp @render_page                            ; Render

; Sets the cursor into upper or lower row
LIB_LCD_cursor_line1:
    jmp LIB_LCD_tx_cmd

    rts

; Sets cursor to second row, first column
LIB_LCD_cursor_line2:
    pha
    lda #%11000000                              ; Set cursor to line 2
    jsr LIB_LCD_tx_cmd
    pla

    rts

; Sends an instruction to the LCD display
LIB_LCD_tx_cmd:
    pha
@loop:                                          ; Wait until LCD is ready
    jsr LIB_LCD_check_busy
    bne @loop
    pla

    sta PORTB                                   ; Write accumulator content into PORTB
    lda #E
    sta PORTA                                   ; Set E bit to send instruction
    lda #0
    sta PORTA                                   ; Clear RS/RW/E bits

    rts

; Sends data to the LCD controller
LIB_LCD_tx_data:
    sta PORTB                                   ; Write accumulator content into PORTB
    lda #(RS | E)
    sta PORTA                                   ; Set E bit AND register select bit to send instruction
    lda #0
    sta PORTA                                   ; Clear RS/RW/E bits

    rts

; Returns the LCD's busy status flag
LIB_LCD_check_busy:
    lda #0                                      ; Clear port A
    sta PORTA                                   ; Clear RS/RW/E bits

    lda #RW                                     ; Prepare read mode
    sta PORTA

    bit PORTB                                   ; Read data from LCD
    bpl @ready                                  ; Bit 7 not set -> ready
    lda #1                                      ; Bit 7 set -> not ready
    rts
@ready:
    lda #0
@return:
    rts

;   CONVERT BINARY BYTE TO HEX ASCII CHARS - Steve Wozniak
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

;   LIB_sleep - sleeps for a given amount of cycles
LIB_sleep:
    ldy #WAIT_C
    sty WAIT
@outerloop:
    tay
@loop:
    dey
    bne @loop
    dec WAIT
    bne @outerloop

    rts

; Start of EH Basic Code.  Adapted from min_mon.asm (https://bit.ly/3PZ49RJ)
LIB_run_basic:
IRQ_vec     = VEC_SV + 2    ; IRQ code vector
NMI_vec     = ISR + $0A     ; NMI code vector

; This code sets up the vectors and interrupt code and then waits
; for the user to select [C]old or [W]arm start.

RES_vec
    cld                    ; Clear decimal mode
    ldx #$FF               ; Empty stack
    txs                    ; Set the stack
    jsr LIB_ACIA_initialize

; Set up vectors and interrupt code, copy them to page 2

    ldy #END_CODE - LAB_vec ; Set index/count
LAB_stlp
    lda LAB_vec - 1, Y     ; Get byte from interrupt code
    sta VEC_IN - 1, Y      ; Save to RAM
    dey                    ; Decrement index/count
    bne LAB_stlp           ; Loop if more to do

; Now do the signon message, Y = $00 here

LAB_signon
    lda LAB_mess,Y        ; Get byte from sign on message
    beq LAB_nokey         ; Exit loop if done

    jsr V_OUTP            ; Output character
    iny                   ; Increment index
    bne LAB_signon        ; Loop, branch always

LAB_nokey
    jsr V_INPT            ; Call scan input device
    bcc LAB_nokey         ; Loop if no key

    and #$DF              ; Mask xx0x xxxx, ensure upper case
    cmp #'W'              ; Compare with [W]arm start
    beq LAB_dowarm        ; Branch if [W]arm start

    cmp #'C'              ; Compare with [C]old start
    bne RES_vec           ; Loop if not [C]old start

    jmp LAB_COLD          ; Do EhBASIC cold start

LAB_dowarm
    jmp LAB_WARM          ; Do EhBASIC warm start

no_load
no_save

    rts

; We need to do some extra work (i.e. upper-casing characters) and can't use the ACIA library calls directly
ACIAin
    lda	ACIA_STATUS		; Read ACIA status
    and	#$08
    beq	LAB_nobyw		; RX buffer is empty

    lda	ACIA_DATA		; Read byte from ACIA
    cmp	#'a'			; Is it < 'a'?
    bcc	ACIAin_DONE		; Yes, we're done
    cmp	#'{'			; Is it >= '{'?
    bcs	ACIAin_DONE		; Yes, we're done
    and	#$5f			; Otherwise, mask to uppercase
ACIAin_DONE
    sec				; Flag byte received
    rts
LAB_nobyw
    clc                         ; Flag no byte received

    rts

; Vector tables

LAB_vec:
    .word ACIAin       	    ; Byte in from ACIA
    .word LIB_ACIA_tx       ; Byte out to ACIA
    .word no_load           ; Null Load vector for EhBASIC
    .word no_save           ; Null Save vector for EhBASIC

; EhBASIC IRQ support

IRQ_CODE
    rti

; EhBASIC NMI support

NMI_CODE
    rti

END_CODE

    rts

LAB_mess
      .byte $0D,$0A,"Enhanced 6502 BASIC 2.22 (c) Lee Davison"
      .byte $0D,$0A,"6502 EhBASIC [C]old/[W]arm ?",$00

; End EH Basic Code

.include "..\acia\acia.asm"
.include "..\ehbasic\ehbasic.asm"
.include "..\vga\vga.asm"

message0:
    .asciiz "6502 Prototype  Boot 1.0"
message1:
    .asciiz "Waiting..."
message2:
    .asciiz "Done!"
message3:
    .asciiz "Running $0x200"
message4:
    .asciiz "Clearing RAM"
message5:
    .asciiz "Derived from    EhBasic v2.22   "
test:
    .asciiz "LET A = 1"

position_map:
    .byte $00, $01, $03, $05, $07, $09
menu_items:
    .byte " Run EH Basic   "
    .byte " Load Program   "
    .byte " Load VGA RAM   "
    .byte " Run            "
    .byte " Memory Monitor "
    .byte " Clear RAM      "
    .byte " Clear VGA RAM  "
    .byte " About          "
about:
    .asciiz "EhBasic v2.22   Lee Davidson (https://bit.ly/3PZ49RJ)"

.segment "MONITOR"
ISR
    rti

.segment "VECTORS"
    .word main                                  ; Entry vector: Reset
    .word ISR                                   ; Entry vector: Interrupt Service Routine

