; Define ACIA address locations
ACIA_DATA = $8800		; Receive / Transmit
;ACIA_DATA = $4000		; Receive / Transmit
ACIA_STATUS = ACIA_DATA + 1	; Status register
ACIA_COMMAND = ACIA_DATA + 2	; Command register
ACIA_CONTROL = ACIA_DATA + 3	; Control register

; Delay values
OUTER_DELAY = 6
INNER_DELAY = $68

; Initialize ACIA settings
LIB_ACIA_initialize:
    stz ACIA_STATUS       ; Soft reset

    lda #%00001011	; No parity, no echo, no interrupts
    sta ACIA_COMMAND    ; Save instruction to COMMAND register

    ;lda #$1A        	; 8-N-1, 2400 baud
    ;lda #$1C        	; 8-N-1, 4800 baud
    lda #$1E        	; 8-N-1, 9600 baud
    ;lda #$1F        	; 8-N-1, 19200 baud

    sta ACIA_CONTROL    ; Save instruction to CONTROL register

    rts

; Attempt to read a byte from ACIA; return immediately if there is no data
LIB_ACIA_rx:
    lda ACIA_STATUS     ; Get ACIA status

    and #$08      	; Mask RX buffer status flag
    beq @exit 		; Exit if RX buffer is empty
 
    lda ACIA_DATA   	; Get byte from ACIA data port

    sec			; Set the carry flag (used by EHBASIC)
    rts

@exit:
    clc			; Ensure carry flag is clear (used by EHBASIC)
    rts

; Continually read from ACIA until a byte becomes available
LIB_ACIA_rx_wait:
    lda ACIA_STATUS     	; Get ACIA status

    and #$08			; Mask RX buffer status flag
    beq LIB_ACIA_rx_wait    	; Loop if RX buffer is empty
 
    lda ACIA_DATA       	; Get byte from ACIA data port
    sec				; Set the carry flag (used by EHBASIC)

    rts

; Attempt to read a byte from ACIA, with a timeout
LIB_ACIA_rx_timeout:
    ldy #$ff
@outerloop:
    ldx #$ff
@innerloop:
    lda ACIA_STATUS              ; Check ACIA status
    and #$08                     ; Mask RX buffer status flag
    bne @exit_with_byte
    dex
    cpx #0
    bne @innerloop
    dey
    cpy #0
    bne @outerloop

    ; No byte was received in time; exit
    clc                          ; Ensure carry flag is clear (used by EHBASIC)
    rts

@exit_with_byte:
    lda ACIA_DATA                ; Get byte from ACIA data port
    sec                          ; Set the carry flag (used by EHBASIC)

    rts

; Attempt to transmit a byte to ACIA 
LIB_ACIA_tx:
    ; Save the value of the accumulator to the stack and loop until the device is ready to transmit
    pha

@loop:

    lda ACIA_STATUS     ; Get status byte
    and #$10        	; Mask TX buffer status flag
    beq @loop 		; Loop if TX buffer full

    ; Restore A and save the byte to ACIA data port
    pla
    sta ACIA_DATA

    ; Mandatory delay after transmission due to 6551 bug
    jsr LIB_ACIA_delay

    rts
 
; Receive a file using the XMODEM protocol.  Z0 and Z1 should already be defined and populated with the appropriate destination address.
LIB_ACIA_rx_xmodem:
    jsr LIB_ACIA_initialize

     ; Brief delay
    lda #1
    jsr LIB_ACIA_rx_delay

    ; NAK, ACK once
@nak:
    lda #$15
    jsr LIB_ACIA_tx
    jsr LIB_ACIA_rx_timeout
    bcc @nak
    cmp #$01            ; Should be SOH packet
    bne @rx_error       ; Terminate transfer if we don't get SOH

@rx_block:
    ; Receive block headers
    jsr LIB_ACIA_rx_wait       ; Block number
    jsr LIB_ACIA_rx_wait       ; Inverse block number
    ldy #0

    ; Store next 128 bytes into memory location referenced by 1st and 2nd Zero Page addresses
@rx_byte:
    jsr LIB_ACIA_rx_wait
    sta (Z0), Y
    iny
    cpy #128
    bne @rx_byte

    jsr LIB_ACIA_rx_wait
    lda #$06                ; ACK the packet
    jsr LIB_ACIA_tx
    jsr LIB_ACIA_rx_wait
    cmp #$04                ; EOT has been received, no further blocks
    beq @rx_complete

    cmp #$01                ; SOH paket, there is another block
    bne @nak

    ; Increment Z0 and Z1 (if necessary)
    lda Z0
    cmp #$00
    beq @increment_page
    lda #$00
    sta Z0
    inc Z1
    jmp @rx_byte
@increment_page:
    lda #$80
    sta Z0
    jmp @rx_byte
@rx_complete:
    lda #$6                 ; ACK the EOT packet
    jsr LIB_ACIA_tx
    lda #1                  ; Brief delay
    jsr LIB_ACIA_rx_delay
    jsr LIB_ACIA_tx_newline
    lda #0
    jmp @exit
@rx_error:
    lda #1
@exit:

    rts

; Sleep for roughly A seconds
LIB_ACIA_rx_delay:
    ; Save registers to stack
    pha
    phx
    phy

    asl
    asl

@outerloop:
    cmp #0
    beq @exit
    ldy #$ff
@middleloop:
    ldx #$ff
@innerloop:
    dex
    cpx #0
    bne @innerloop
    dey
    cpy #0
    bne @middleloop
    dec
    jmp @outerloop

@exit:
    ; Restore registers
    ply
    plx
    pla

    rts

; Transmit a newline
LIB_ACIA_tx_newline:
    lda #$0d
    jsr LIB_ACIA_rx
    lda #$0a
    jsr LIB_ACIA_rx

    rts

LIB_ACIA_delay:
    ; Save X and Y registers
    phy
    phx

    ldy #OUTER_DELAY
@outerloop:
    ldx #INNER_DELAY
@innerloop:
    dex
    bne @innerloop
    dey
    bne @outerloop

    ; Restore X and Y registers
    plx
    ply

    rts
