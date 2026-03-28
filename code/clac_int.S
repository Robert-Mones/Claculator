	PROCESSOR 6502

KEYPAD_DATA	= $4000
KEYPAD_STAT	= $4001	; DO NOT USE

DISPLAY_RAM = $5000

VIA_REG_B	= $6000
VIA_REG_A	= $6001
VIA_DDR_B	= $6002
VIA_DDR_A	= $6003
VIA_T1_COUNT_L	= $6004
VIA_T1_COUNT_H	= $6005
VIA_T1_LATCH_L	= $6006
VIA_T1_LATCH_H	= $6007
VIA_SR		= $600A
VIA_AUX_CTRL	= $600B
VIA_PER_CTRL	= $600C
VIA_INT_FLAG	= $600D
VIA_INT_ENBL	= $600E

;ACIA_DATA 	= $5000
;ACIA_STATUS	= $5001
;ACIA_CMD	= $5002
;ACIA_CTRL	= $5003

LCD_EN_LOW	= (0 << 7)
LCD_EN_HIGH	= (1 << 7)

LCD_RW_WRITE	= (0 << 6)
LCD_RW_READ 	= (1 << 6)

LCD_RS_CMD	= (0 << 5)
LCD_RS_DATA	= (1 << 5)

DISPLAY_INDEX	= $00	; Index into the display buffer for looping
STACK_POINTER   = $01	; One-byte pointer to the operand stack

CALC_ARG1	= $02	; Two-byte arg for calculations
CALC_ARG2	= $04	; Two-byte arg for calculations
CALC_RESULT	= $06	; Two-byte result for calculations

INPUT_BUFFER	= $08	; Two-byte buffer for entering an operand
RENDER_NEEDED	= $0A	; One-byte flag indicating a redraw of the display is needed

MUL_MINOR	= $0B	; Two-byte buffer for the smaller of the two operands for mul
DIV_RESULT_NEG	= $0D	; One-byte
DIV_RESULT	= $0E	; Two-byte
DIV_TMP		= $10	; Two-byte
MUL_FAST_ARG1	= $12	; Two-byte buffer for ARG1 input for mul_fast operation
MUL_FAST_ARG2	= $14	; Two-byte buffer for ARG2 input for mul_fast operation
MUL_FAST_RESULT	= $16	; Two-byte buffer for result of mul_fast operation
MUL_FAST_LOOP_COUNT	= $18	; One-byte counter for the loop iters for mul_fast operation

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
disp_init_loop:
	DEY
	STA DISPLAY_RAM,y
	BNE disp_init_loop
	STY DISPLAY_INDEX



	LDA #$C0
	STA CALC_ARG1 + 0
	LDA #$02
	STA CALC_ARG1 + 1

	LDA #$00
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_shl
	LDA CALC_RESULT + 0
	TAY
	LDA CALC_RESULT + 1
	TAX

	LDA #$01
	STA CALC_ARG2 + 0

	JSR op_shl
	LDA CALC_RESULT + 0
	TAY
	LDA CALC_RESULT + 1
	TAX

	LDA #$02
	STA CALC_ARG2 + 0

	JSR op_shl
	LDA CALC_RESULT + 0
	TAY
	LDA CALC_RESULT + 1
	TAX

	LDA #$41
	STA CALC_ARG1 + 0
	LDA #$01
	STA CALC_ARG1 + 1

	LDA #$C0
	STA CALC_ARG2 + 0
	LDA #$02
	STA CALC_ARG2 + 1

	JSR op_add
	LDA CALC_RESULT + 0
	TAY
	LDA CALC_RESULT + 1
	TAX

	JSR op_sub
	LDA CALC_RESULT + 0
	TAY
	LDA CALC_RESULT + 1
	TAX

	JSR op_mul
	LDA CALC_RESULT + 0
	TAY
	LDA CALC_RESULT + 1
	TAX

	JSR op_mul_fast
	LDA CALC_RESULT + 0
	TAY
	LDA CALC_RESULT + 1
	TAX

	LDA #$FF
	STA CALC_ARG1 + 0
	LDA #$FF
	STA CALC_ARG1 + 1

	LDA #$C0
	STA CALC_ARG2 + 0
	LDA #$02
	STA CALC_ARG2 + 1

	JSR op_mul_fast
	LDA CALC_RESULT + 0
	TAY
	LDA CALC_RESULT + 1
	TAX

	LDA #$41
	STA CALC_ARG1 + 0
	LDA #$01
	STA CALC_ARG1 + 1

	LDA #$C0
	STA CALC_ARG2 + 0
	LDA #$02
	STA CALC_ARG2 + 1

	JSR op_div
	LDA CALC_RESULT + 0
	TAY
	LDA CALC_RESULT + 1
	TAX


; Run the main loop
loop:
	LDA VIA_REG_A			; Check the VIA pin A2 for the status of the keypad
	AND #$04
	BNE skip_read_key		; If the interrupt bit is 1, go back to the beginning of loop
	JSR read_key			; If the interrupt bit is 0, read the keypress
skip_read_key:

	LDA RENDER_NEEDED		; Check the RENDER_NEEDED flag
	BEQ skip_redraw			; If it's 0, skip drawing the display
	JSR draw_display		; If it's non-zero, draw the display
skip_redraw:

	JMP loop

; Redraw the display
draw_display:
	RTS

; Spec for all operations
; Values of CALC_ARG1 and CALC_ARG2 are unmodified and must be restored by the callee
; Values of A/X/Y registers and P are undefined and may be modified by the callee
; Value of CALC_RESULT are modified by the callee to save the result

; Add operation
op_add:
	CLC

	LDA CALC_ARG1 + 0
	ADC CALC_ARG2 + 0
	STA CALC_RESULT + 0

	LDA CALC_ARG1 + 1
	ADC CALC_ARG2 + 1
	STA CALC_RESULT + 1

	RTS

; Sub operation
op_sub:
	SEC

	LDA CALC_ARG1 + 0
	SBC CALC_ARG2 + 0
	STA CALC_RESULT + 0

	LDA CALC_ARG1 + 1
	SBC CALC_ARG2 + 1
	STA CALC_RESULT + 1

	RTS

; Fast (log-time) multiplication operation
; ARG1 is saved on stack, restored at end
; ARG2 is saved on stack, restored at end
; On every loop, ARG1 is shifted right, if LSB set, ARG2 is added to MUL_FAST_RESULT
; On every loop, ARG2 is shifted left
op_mul_fast:
	LDA CALC_ARG1 + 0
	STA MUL_FAST_ARG1 + 0
	PHA
	LDA CALC_ARG1 + 1
	STA MUL_FAST_ARG1 + 1
	PHA

	LDA CALC_ARG2 + 0
	STA MUL_FAST_ARG2 + 0
	PHA
	LDA CALC_ARG2 + 1
	STA MUL_FAST_ARG2 + 1
	PHA

	LDA #$00
	STA MUL_FAST_RESULT + 0
	STA MUL_FAST_RESULT + 1

	LDA #$10 ; Loop 16 times, once for each bit in ARG2
	STA MUL_FAST_LOOP_COUNT

op_mul_fast__loop:
	LDA MUL_FAST_ARG1 + 0
	BIT bits_table + 0		; Bit test LSBit of A
	BEQ op_mul_fast__add_done	; If LSbit of LSbyte of ARG1 is unset, skip the ADD

op_mul_fast__add:
	; MUL_FAST_RESULT + MUL_FAST_ARG2 -> MUL_FAST_RESULT
	LDA MUL_FAST_RESULT + 0
	STA CALC_ARG1 + 0
	LDA MUL_FAST_RESULT + 1
	STA CALC_ARG1 + 1

	LDA MUL_FAST_ARG2 + 0
	STA CALC_ARG2 + 0
	LDA MUL_FAST_ARG2 + 1
	STA CALC_ARG2 + 1
	
	JSR op_add

	LDA CALC_RESULT + 0
	STA MUL_FAST_RESULT + 0
	LDA CALC_RESULT + 1
	STA MUL_FAST_RESULT + 1

op_mul_fast__add_done:
op_mul_fast__shift:
	; MUL_FAST_ARG1 >> 1 -> MUL_FAST_ARG1
	LDA MUL_FAST_ARG1 + 0
	STA CALC_ARG1 + 0
	LDA MUL_FAST_ARG1 + 1
	STA CALC_ARG1 + 1

	LDA #$01
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	jsr op_shr

	LDA CALC_RESULT + 0
	STA MUL_FAST_ARG1 + 0
	LDA CALC_RESULT + 1
	STA MUL_FAST_ARG1 + 1

	; MUL_FAST_ARG2 << 1 -> MUL_FAST_ARG2
	LDA MUL_FAST_ARG2 + 0
	STA CALC_ARG1 + 0
	LDA MUL_FAST_ARG2 + 1
	STA CALC_ARG1 + 1

	LDA #$01
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	jsr op_shl

	LDA CALC_RESULT + 0
	STA MUL_FAST_ARG2 + 0

	LDA CALC_RESULT + 1
	STA MUL_FAST_ARG2 + 1

	DEC MUL_FAST_LOOP_COUNT
	BNE op_mul_fast__loop ; If MUL_FAST_LOOP_COUNT != 0 we're not done

	JMP op_mul_fast__done

op_mul_fast__done:
	PLA
	STA CALC_ARG2 + 1
	PLA
	STA CALC_ARG2 + 0

	PLA
	STA CALC_ARG1 + 1
	PLA
	STA CALC_ARG1 + 0

	LDA MUL_FAST_RESULT + 0
	STA CALC_RESULT + 0
	LDA MUL_FAST_RESULT + 1
	STA CALC_RESULT + 1

	RTS

; Div operation
op_div:
	LDA CALC_ARG1 + 0
	STA DIV_TMP + 0
	LDA CALC_ARG1 + 1
	STA DIV_TMP + 1

	LDA CALC_ARG2 + 0
	STA CALC_ARG1 + 0
	LDA CALC_ARG2 + 1
	STA CALC_ARG1 + 1

	LDA #$00
	STA CALC_ARG2 + 0
	STA CALC_ARG2 + 1

	JSR op_lt

	BEQ op_div_dont_negate_arg2


op_div_dont_negate_arg2:

	RTS

; < operation
op_lt:
	LDA CALC_ARG1 + 1
	CMP CALC_ARG2 + 1
	BMI op_lt_true
	BNE op_lt_false
	
	LDA CALC_ARG1 + 0
	CMP CALC_ARG2 + 0
	BMI op_lt_true

op_lt_false:
	LDA #$0
	JMP op_lt_done
op_lt_true:
	LDA #$1
op_lt_done:
	STA CALC_RESULT + 0
	LDA #$0
	STA CALC_RESULT + 1
	RTS

; Negation operation
op_neg:
	LDA CALC_ARG1

	LDA #$01
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_add

; ARG1 >> ARG2 (MSByte of ARG2 ignored)
; Performs sign extension
op_shr:
	LDA CALC_ARG1 + 0
	STA CALC_RESULT + 0
	LDA CALC_ARG1 + 1
	STA CALC_RESULT + 1

	LDA CALC_ARG2 + 0
	TAX

	LDA CALC_RESULT + 1
	BIT bits_table + 7 ; Check top bit of MSByte
	; If top bit is zero, shift without sign extension
	BEQ op_shr__loop_guard_zero_extend

; Loop with sign extension
op_shr__loop_guard_one_extend:
	TXA
	BEQ op_shr__done

	SEC
	ROR CALC_RESULT + 1
	ROR CALC_RESULT + 0
	DEX

	JMP op_shr__loop_guard_zero_extend

; Loop without sign extension
op_shr__loop_guard_zero_extend:
	TXA
	BEQ op_shr__done

	CLC
	ROR CALC_RESULT + 1
	ROR CALC_RESULT + 0
	DEX

	JMP op_shr__loop_guard_zero_extend

op_shr__done:
	RTS


; ARG1 << ARG2 (MSByte of ARG2 ignored)
op_shl:
	LDA CALC_ARG1 + 0
	STA CALC_RESULT + 0
	LDA CALC_ARG1 + 1
	STA CALC_RESULT + 1

	LDA CALC_ARG2 + 0
	TAX

op_shl__loop_guard:
	TXA
	BEQ op_shl__done
op_shl__loop:
	CLC
	ROL CALC_RESULT + 0
	ROL CALC_RESULT + 1
	DEX

	JMP op_shl__loop_guard

op_shl__done:
	RTS

; Read a key
read_key:
	LDY KEYPAD_DATA			; Read the key group index

read_key_wait:
	LDA VIA_REG_A
	AND #$04
	BNE read_key_wait		; If the second byte isn't ready, wait

	LDX KEYPAD_DATA			; Read the key down bitmask
	BNE read_key_pressed	; If the bitmask is equal to zero, there's a keypress
	RTS
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
	LDA #$01
	STA RENDER_NEEDED
	RTS

; Prints the number in the A register to the Y-th seven-segment digit
segment_print:
	PHA
	TAX
	LDA segment_table,x
	STA DISPLAY_RAM,y
	PLA
	RTS

; Prints the character in the A register to the display
print:
	PHA
	STA VIA_REG_B	; Set the data lines to the character we want to show
	LDA #[LCD_EN_HIGH | LCD_RW_WRITE | LCD_RS_DATA]
	STA VIA_REG_A	; Turn enable on, set control signals
	LDA #[LCD_EN_LOW  | LCD_RW_WRITE | LCD_RS_DATA]
	STA VIA_REG_A	; Turn enable off
	PLA
	RTS


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

bits_table:
	DC.B %00000001
	DC.B %00000010
	DC.B %00000100
	DC.B %00001000
	DC.B %00010000
	DC.B %00100000
	DC.B %01000000
	DC.B %10000000
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
