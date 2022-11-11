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
;	2022-11-01	Updated with latest VGA code.
;================================================================================

; Enable syntax features
  .feature labels_without_colons
  .feature c_comments
  .feature loose_char_term

; Zero page locations
Z0 = $E0                                        
Z1 = $E1
Z2 = $E2
Z3 = $E3

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
; Memory Locations
;================================================================================
PROGRAM_LOCATION = $0200                      	; Memory location for user programs

END_OF_RAM = $3fde

.segment "CODE"

;   main - Initialize the bootloader

main:
    ldx #$ff                                    ; Initialize the stackpointer with 0xff
    txs

    jsr LIB_VGA_initialize
    jsr LIB_run_monitor                         ; Run the monitor subroutine

    jmp main                                    ; Restart if we ever end up back here

; Initialize the VIA
initialize:
    jsr LIB_VIA_initialize

    rts

LIB_load_user_ram:
    ldy #<PROGRAM_LOCATION                      ; Load location for user programs into zero page
    sty Z0
    lda #>PROGRAM_LOCATION
    sta Z1

    jsr do_load

    rts

; Load data via XMODEM into the 16 bit addres at Z0
do_load:
    ; Call the transfer subroutine
    jsr LIB_ACIA_rx_xmodem

    rts

;   Clears RAM from $0200 up to $3fff
LIB_clear_user_ram:
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

;================================================================================
; VIA Functions
;================================================================================

; Return key presses from the attached buttons
LIB_VIA_read_input:
    lda PORTA                                   ; Load current status from VIA

    and #$0f
    eor #$0f

    rts

; Initialize the VIA
LIB_VIA_initialize:
    stx DDRA                                    ; Configure data direction for port A
    sta DDRB                                    ; Configure data direction for port B

    rts

; Put a single character (stored in A) to VGA and ACIA
LIB_put:
    jsr LIB_ACIA_tx
    jsr LIB_VGA_put

    rts

; Convert binary byte to hex ASCII - Steve Wozniak
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

; Sleep function with an inner (Y) and outer (X) loop
LIB_sleep:
@outerloop:
    tay
@loop:
    dey
    bne @loop
    dex
    bne @outerloop

    rts

LIB_run_monitor:
    jsr LIB_ACIA_initialize
    jsr MonitorBoot

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
    .word LIB_put           ; Byte out to VGA and ACIA
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
.include "..\vga\vga.asm"
.include "..\monitor\sbc.asm"
.include "..\ehbasic\ehbasic.asm"

.segment "MONITOR"
ISR
    rti

.segment "VECTORS"
    .word main                                  ; Entry vector: Reset
    .word ISR                                   ; Entry vector: Interrupt Service Routine

