	PROCESSOR 6502

KEYPAD_DATA	= $4800
KEYPAD_STAT	= $4801	; DO NOT USE

DISPLAY_RAM = $4400

VIA_REG_B		= $6C00
VIA_REG_A		= $6C01
VIA_DDR_B		= $6C02
VIA_DDR_A		= $6C03
VIA_T1_COUNT_L	= $6C04
VIA_T1_COUNT_H	= $6C05
VIA_T1_LATCH_L	= $6C06
VIA_T1_LATCH_H	= $6C07
VIA_SR			= $6C0A
VIA_AUX_CTRL	= $6C0B
VIA_PER_CTRL	= $6C0C
VIA_INT_FLAG	= $6C0D
VIA_INT_ENBL	= $6C0E

;ACIA_DATA 	= $5C00
;ACIA_STATUS	= $5C01
;ACIA_CMD	= $5C02
;ACIA_CTRL	= $5C03

LCD_EN_LOW		= (0 << 7)
LCD_EN_HIGH		= (1 << 7)

LCD_RW_WRITE	= (0 << 6)
LCD_RW_READ 	= (1 << 6)

LCD_RS_CMD		= (0 << 5)
LCD_RS_DATA		= (1 << 5)

DISPLAY_INDEX	= $00

; ========================================

	SEG		text
	ORG $8000

start:
	LDX #$FF				; Initialize the stack pointer
	TXS

	LDA #$FF
	STA VIA_DDR_A
	LDA #$7F				; Set all besides B7 on the VIA to be outputs
	STA VIA_DDR_B

; Run the main loop
loop:
	LDA VIA_REG_B			; Check the VIA pin B7 for the status of the keypad
	AND #$80
	BNE skip_read_key		; If the interrupt bit is 1, go back to the beginning of loop
	JSR read_key			; If the interrupt bit is 0, read the keypress
skip_read_key:

	JMP loop

; Read a key
read_key:
	LDY KEYPAD_DATA			; Read the key group index

read_key_wait:
	LDA VIA_REG_B
	AND #$80
	BNE read_key_wait		; If the second byte isn't ready, wait

	LDX KEYPAD_DATA			; Read the key down bitmask
	BNE read_key_pressed	; If the bitmask is equal to zero, there's a keypress
	rts
read_key_pressed:
	TYA						; Put key group index << 3 in Y
	ASL
	ASL
	ASL
	TAY

	TXA						; Put the orig bitmask in A
read_key_pressed_loop:
	AND #$1					; Test the lsb
	BNE read_key_found
	TXA						; Put the most recent bitmask back in A
	LSR						; Right-shift it by 1 and put it back in X
	TAX
	INY
	JMP read_key_pressed_loop
read_key_found:

	LDA number_table,y
	LDY DISPLAY_INDEX
	jsr segment_print
	INC DISPLAY_INDEX
	LDA DISPLAY_INDEX
	CMP #72
	BNE dont_rst_disp_index
	LDA #0
	STA DISPLAY_INDEX
dont_rst_disp_index:

	rts

; Prints the number in the A register to the Y-th seven-segment digit
segment_print:
	PHA
	TAX
	LDA segment_table,x
	STA DISPLAY_RAM,y
	PLA
	rts


; ================== ;
; Interrupt handlers ;
; ================== ;

irq_handler:
	PHA

	;LDA ACIA_STATUS
	;AND #[1 << 3]
	;BNE acia_irq

	LDA VIA_INT_FLAG
	AND #[1 << 6]
	BNE timer_irq

	PLA
	RTI

timer_irq:
	LDA VIA_T1_COUNT_L	; Clear pending interrupt

	LDA VIA_REG_A		; Toggle A0
	EOR #1
	STA VIA_REG_A

	PLA
	RTI

/*acia_irq:
	LDA ACIA_DATA
	STA VIA_REG_B

	LDA VIA_REG_A
	ORA #[LCD_EN_HIGH | LCD_RS_DATA]
	STA VIA_REG_A
	AND #[~LCD_EN_HIGH]
	STA VIA_REG_A

	PLA
	RTI*/

keypad_irq:
	PLA
	RTI


; ======================== ;
; Constants and other data ;
; ======================== ;

symbol_table:
	DC.B "9e6_3E.E784512<0<+^-N*%/RTRRSCDFCP:N;IPS"
number_table:
	DC.B 9,0,6,0,3,0,0,0,7,8,4,5,1,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
segment_table:
	DC.B %00111111, %00000110, %01011011, %01001111, %01100110, %01101101, %01111101, %00000111, %01111111, %01101111

	ORG $FFFA
vector_table:
	DC.W start			; NMI
	DC.W start			; RESET
	DC.W irq_handler	; IRQ
