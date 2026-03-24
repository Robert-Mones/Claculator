	PROCESSOR 6502

KEYPAD_DATA	= $4000
KEYPAD_STAT	= $4001	; DO NOT USE

VIA_REG_B	= $6000
VIA_REG_A	= $6001
VIA_DDR_B	= $6002
VIA_DDR_A	= $6003

LCD_EN_LOW		= (0 << 7)
LCD_EN_HIGH		= (1 << 7)

LCD_RW_WRITE	= (0 << 6)
LCD_RW_READ 	= (1 << 6)

LCD_RS_CMD		= (0 << 5)
LCD_RS_DATA		= (1 << 5)

; ========================================

	SEG		text
	ORG $8000

start:
	LDA #$FB
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

	LDA #%00000110			; Increment DDRAM pointer, do not shift display
	STA VIA_REG_B
	STX VIA_REG_A
	STY VIA_REG_A

	LDA #%00001110			; Set display on, cursor on, enable cursor blink
	STA VIA_REG_B
	STX VIA_REG_A
	STY VIA_REG_A
	
	JMP main
	LDX #0
	LDA text_message,x	; This loads the ASCII value of the letter 'H'

print_loop:
	
	JSR print		; Prints the char to the display

	INX
	LDA text_message,x
	BNE print_loop	

; Run the main loop
main:
	LDA VIA_REG_A			; Check the VIA pin A2 for the status of the keypad
	AND #$04

	BNE main				; If the interrupt bit is 1, go back to the beginning of main
	JSR read_key			; If the interrupt bit is 0, read the keypress

	JMP main

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
	TYA
	CLC
	ADC #$30				; Add 0x30 to get ascii for the group index
	jsr print				; Print the group index
	LDY #$0					; Y is counter to count bits
	TXA
read_key_pressed_loop:
	AND #$1
	BNE read_key_found
	TXA
	LSR
	TAX
	INY
	JMP read_key_pressed_loop
read_key_found:
	TYA
	CLC
	ADC	#$30				; Add 0x30 to get ascii for the key index
	jsr print				; Print the key index
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

text_message:
	DC.B "Hello, world!",0

	ORG $FFFA
reset_vectors:
	DC.W start	; NMI
	DC.W start	; RESET
	DC.W start	; IRQ
