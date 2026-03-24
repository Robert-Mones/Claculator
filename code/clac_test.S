	PROCESSOR 6502

KEYPAD_DATA	= $4000
KEYPAD_STAT	= $4001	; DO NOT USE

DISPLAY_RAM = $5000

VIA_REG_B		= $6000
VIA_REG_A		= $6001
VIA_DDR_B		= $6002
VIA_DDR_A		= $6003
VIA_T1_COUNT_L	= $6004
VIA_T1_COUNT_H	= $6005
VIA_T1_LATCH_L	= $6006
VIA_T1_LATCH_H	= $6007
VIA_SR			= $600A
VIA_AUX_CTRL	= $600B
VIA_PER_CTRL	= $600C
VIA_INT_FLAG	= $600D
VIA_INT_ENBL	= $600E

;ACIA_DATA 	= $5000
;ACIA_STATUS	= $5001
;ACIA_CMD	= $5002
;ACIA_CTRL	= $5003

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

	LDA #$FB				; Set all besides A2 on the VIA to be outputs
	STA VIA_DDR_A
	LDA #$FF
	STA VIA_DDR_B

	LDX #[LCD_EN_HIGH | LCD_RW_WRITE | LCD_RS_CMD]
	LDY #[LCD_EN_LOW  | LCD_RW_WRITE | LCD_RS_CMD]

	LDA #%00111100			; 8-bit width, 2-line display, 5x10 font size
	STA VIA_REG_B			; Set the data lines to the correct command
	STX VIA_REG_A			; Turn enable on, set control signals
	STY VIA_REG_A			; Turn enable off

	LDA #%00000001			; Clear display
	STA VIA_REG_B
	STX VIA_REG_A
	STY VIA_REG_A

	LDA #80					; Wait for the display to be ready again
delay_loop:
	ADC #1
	BCC delay_loop

	LDA #%00000110			; Increment DDRAM pointer, do not shift display
	STA VIA_REG_B
	STX VIA_REG_A
	STY VIA_REG_A

	LDA #%00001110			; Set display on, cursor on, enable cursor blink
	STA VIA_REG_B
	STX VIA_REG_A
	STY VIA_REG_A

	; Now initialize the ACIA
	/*
	STA ACIA_STATUS			; Software reset

	LDA #%00010000			; 1 stop bit, 8-bit word length, use baud rate, 115200 baud
	STA ACIA_CTRL

	LDA #%00001001			; IRQB enabled, data terminal ready
	STA ACIA_CMD
	*/
	
	; Now initialize the display
	LDY #72
	LDA #$0
disp_init_loop
	DEY
	STA DISPLAY_RAM,y
	BNE disp_init_loop
	STY DISPLAY_INDEX


; Run the main loop
loop:
	LDA VIA_REG_A			; Check the VIA pin A2 for the status of the keypad
	AND #$04
	BNE skip_read_key		; If the interrupt bit is 1, go back to the beginning of loop
	JSR read_key			; If the interrupt bit is 0, read the keypress
skip_read_key:

	JMP loop

; Read a key
read_key:
	LDY KEYPAD_DATA			; Read the key group index

read_key_wait:
	LDA VIA_REG_A
	AND #$04
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
	LDA symbol_table,y
	jsr print				; Print the key index

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

; Prints the character in the A register to the display
print:
	PHA
	STA VIA_REG_B	; Set the data lines to the character we want to show
	LDA #[LCD_EN_HIGH | LCD_RW_WRITE | LCD_RS_DATA]
	STA VIA_REG_A	; Turn enable on, set control signals
	LDA #[LCD_EN_LOW  | LCD_RW_WRITE | LCD_RS_DATA]
	STA VIA_REG_A	; Turn enable off
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

	LDA VIA_REG_A
	AND #$04
	BEQ keypad_irq

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
