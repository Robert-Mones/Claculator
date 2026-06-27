	PROCESSOR 6502

DISPLAY_RAM = $4400

KEYPAD_DATA	= $4800
KEYPAD_STAT	= $4801	; DO NOT USE

ACIA_DATA 	= $5C00
ACIA_STATUS	= $5C01
ACIA_CMD	= $5C02
ACIA_CTRL	= $5C03

VIA_REG_B	= $6C00
VIA_REG_A	= $6C01
VIA_DDR_B	= $6C02
VIA_DDR_A	= $6C03
VIA_T1_COUNT_L	= $6C04
VIA_T1_COUNT_H	= $6C05
VIA_T1_LATCH_L	= $6C06
VIA_T1_LATCH_H	= $6C07
VIA_SR		= $6C0A
VIA_AUX_CTRL	= $6C0B
VIA_PER_CTRL	= $6C0C
VIA_INT_FLAG	= $6C0D
VIA_INT_ENBL	= $6C0E

DISPLAY_INDEX	= $00	; Index into the display buffer for looping
STACK_POINTER   = $01	; One-byte pointer to the operand stack

CALC_ARG1	= $02	; Two-byte arg for calculations
CALC_ARG2	= $04	; Two-byte arg for calculations
CALC_RESULT1	= $06	; Two-byte result for calculations

INPUT_BUFFER	= $08	; Two-byte buffer for entering an operand
RENDER_NEEDED	= $0A	; One-byte flag indicating a redraw of the display is needed

MUL_MINOR	= $0B	; Two-byte buffer for the smaller of the two operands for mul

DIV_DIVISOR_NEG	= $0D	; One-byte flag indicating that the divisor was negated
DIV_RESULT	= $0E	; Two-byte buffer for the result of the division operation
DIV_DIVIDEND	= $10	; Two-byte buffer for the dividend

MUL_FAST_ARG1	= $12	; Two-byte buffer for ARG1 input for mul_fast operation
MUL_FAST_ARG2	= $14	; Two-byte buffer for ARG2 input for mul_fast operation
MUL_FAST_RESULT	= $16	; Two-byte buffer for result of mul_fast operation
MUL_FAST_LOOP_COUNT	= $18	; One-byte counter for the loop iters for mul_fast operation

DIV_DIVISOR_SHIFT_COUNT = $19 ; One-byte counter for the loop iters for the div operation
DIV_DIVISOR	= $1A	; Two-byte buffer for the divisor
DIV_DIVIDEND_NEG	= $1C	; One-byte flag indicating that the dividend was negated

STACK_SIZE = $1D	; One-byte size of the stack, should be incremented in multiples of 4 and should not be incremented above 0xFC to prevent overflow
CALC_RESULT2	= $1E	; Two-byte result for calculations that produce two results
STACK_TEMP = $20	; Four-byte temp variable to copy values into before they're pushed onto the stack

STACK_START = $0200	; 252-byte operand stack
DISPLAY_BUFFER_START = $0300 ; 72-byte buffer of the display RAM, first byte is MSDigit of #8 in stack

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
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	LDA #$01
	STA CALC_ARG2 + 0

	JSR op_shl
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	LDA #$02
	STA CALC_ARG2 + 0

	JSR op_shl
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
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
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	JSR op_sub
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	JSR op_mul_fast
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
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
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	; -7 / -2 (= 3)
	LDA #$F9
	STA CALC_ARG1 + 0
	LDA #$FF
	STA CALC_ARG1 + 1

	LDA #$FE
	STA CALC_ARG2 + 0
	LDA #$FF
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	; 15122 / 213 (= 70)
	LDA #$12
	STA CALC_ARG1 + 0
	LDA #$3B
	STA CALC_ARG1 + 1

	LDA #$D5
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	; 15123 / 213 (= 71)
	LDA #$13
	STA CALC_ARG1 + 0
	LDA #$3B
	STA CALC_ARG1 + 1

	LDA #$D5
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	; -15122 / 213 (= -70)
	LDA #$EE
	STA CALC_ARG1 + 0
	LDA #$C4
	STA CALC_ARG1 + 1

	LDA #$D5
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	; -15123 / 213 (= -71)
	LDA #$ED
	STA CALC_ARG1 + 0
	LDA #$C4
	STA CALC_ARG1 + 1

	LDA #$D5
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	; 15122 / -213 (= -70)
	LDA #$12
	STA CALC_ARG1 + 0
	LDA #$3B
	STA CALC_ARG1 + 1

	LDA #$2B
	STA CALC_ARG2 + 0
	LDA #$FF
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	; 15123 / -213 (= -71)
	LDA #$13
	STA CALC_ARG1 + 0
	LDA #$3B
	STA CALC_ARG1 + 1

	LDA #$2B
	STA CALC_ARG2 + 0
	LDA #$FF
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	; -15122 / -213 (= 70)
	LDA #$EE
	STA CALC_ARG1 + 0
	LDA #$C4
	STA CALC_ARG1 + 1

	LDA #$2B
	STA CALC_ARG2 + 0
	LDA #$FF
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	; -15123 / -213 (= 71)
	LDA #$ED
	STA CALC_ARG1 + 0
	LDA #$C4
	STA CALC_ARG1 + 1

	LDA #$2B
	STA CALC_ARG2 + 0
	LDA #$FF
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	; 24241 / 971 (= 24)
	LDA #$B1
	STA CALC_ARG1 + 0
	LDA #$5E
	STA CALC_ARG1 + 1

	LDA #$CB
	STA CALC_ARG2 + 0
	LDA #$03
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	; -24241 / 971 (= -24)
	LDA #$4F
	STA CALC_ARG1 + 0
	LDA #$A1
	STA CALC_ARG1 + 1

	LDA #$CB
	STA CALC_ARG2 + 0
	LDA #$03
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	; 24241 / -971 (= -24)
	LDA #$B1
	STA CALC_ARG1 + 0
	LDA #$5E
	STA CALC_ARG1 + 1

	LDA #$35
	STA CALC_ARG2 + 0
	LDA #$FC
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	; -24241 / -971 (= 24)
	LDA #$4F
	STA CALC_ARG1 + 0
	LDA #$A1
	STA CALC_ARG1 + 1

	LDA #$35
	STA CALC_ARG2 + 0
	LDA #$FC
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT1 + 0
	TAY
	LDA CALC_RESULT1 + 1
	TAX

	; 15 % 3 (= 0)
	LDA #$0F
	STA CALC_ARG1 + 0
	LDA #$00
	STA CALC_ARG1 + 1

	LDA #$03
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT2 + 0
	TAY
	LDA CALC_RESULT2 + 1
	TAX

	; 16 % 3 (= 1)
	LDA #$10
	STA CALC_ARG1 + 0
	LDA #$00
	STA CALC_ARG1 + 1

	LDA #$03
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT2 + 0
	TAY
	LDA CALC_RESULT2 + 1
	TAX

	; 17 % 3 (= 2)
	LDA #$11
	STA CALC_ARG1 + 0
	LDA #$00
	STA CALC_ARG1 + 1

	LDA #$03
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT2 + 0
	TAY
	LDA CALC_RESULT2 + 1
	TAX

	; -17 % 3 (= -2)
	LDA #$EF
	STA CALC_ARG1 + 0
	LDA #$FF
	STA CALC_ARG1 + 1

	LDA #$03
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT2 + 0
	TAY
	LDA CALC_RESULT2 + 1
	TAX

	; 17 % -3 (= 2)
	LDA #$11
	STA CALC_ARG1 + 0
	LDA #$00
	STA CALC_ARG1 + 1

	LDA #$FD
	STA CALC_ARG2 + 0
	LDA #$FF
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT2 + 0
	TAY
	LDA CALC_RESULT2 + 1
	TAX

	; -17 % -3 (= -2)
	LDA #$EF
	STA CALC_ARG1 + 0
	LDA #$FF
	STA CALC_ARG1 + 1

	LDA #$03
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT2 + 0
	TAY
	LDA CALC_RESULT2 + 1
	TAX

	; 15165 % 271 (= 260)
	LDA #$3D
	STA CALC_ARG1 + 0
	LDA #$3B
	STA CALC_ARG1 + 1

	LDA #$0F
	STA CALC_ARG2 + 0
	LDA #$01
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT2 + 0
	TAY
	LDA CALC_RESULT2 + 1
	TAX

	; -15165 % 271 (= -260)
	LDA #$C3
	STA CALC_ARG1 + 0
	LDA #$C4
	STA CALC_ARG1 + 1

	LDA #$0F
	STA CALC_ARG2 + 0
	LDA #$01
	STA CALC_ARG2 + 1

	JSR op_divmod
	LDA CALC_RESULT2 + 0
	TAY
	LDA CALC_RESULT2 + 1
	TAX

	NOP


; Run the main loop
loop:
	LDA VIA_REG_B			; Check the VIA pin A2 for the status of the keypad
	AND #$80
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
; Value of CALC_RESULT1 is modified by the callee to save the result
; Value of CALC_RESULT2 is optionally modified by the callee to save an auxilliary result

; Signed/unsigned add operation
; Does not use CALC_RESULT2
op_add:
	CLC

	LDA CALC_ARG1 + 0
	ADC CALC_ARG2 + 0
	STA CALC_RESULT1 + 0

	LDA CALC_ARG1 + 1
	ADC CALC_ARG2 + 1
	STA CALC_RESULT1 + 1

	RTS

; Signed/unsigned sub operation
; Does not use CALC_RESULT2
op_sub:
	SEC

	LDA CALC_ARG1 + 0
	SBC CALC_ARG2 + 0
	STA CALC_RESULT1 + 0

	LDA CALC_ARG1 + 1
	SBC CALC_ARG2 + 1
	STA CALC_RESULT1 + 1

	RTS

; Signed/unsigned fast (log-time) multiplication operation
; Does not use CALC_RESULT2
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

	LDA CALC_RESULT1 + 0
	STA MUL_FAST_RESULT + 0
	LDA CALC_RESULT1 + 1
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

	LDA CALC_RESULT1 + 0
	STA MUL_FAST_ARG1 + 0
	LDA CALC_RESULT1 + 1
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

	LDA CALC_RESULT1 + 0
	STA MUL_FAST_ARG2 + 0

	LDA CALC_RESULT1 + 1
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
	STA CALC_RESULT1 + 0
	LDA MUL_FAST_RESULT + 1
	STA CALC_RESULT1 + 1

	RTS

; Signed div and mod operation
; Stores result of div in CALC_RESULT1
; Stores result of mod in CALC_RESULT2
op_divmod:
	LDA CALC_ARG1 + 0
	STA DIV_DIVIDEND + 0
	PHA
	LDA CALC_ARG1 + 1
	STA DIV_DIVIDEND + 1
	PHA

	LDA CALC_ARG2 + 0
	STA DIV_DIVISOR + 0
	PHA
	LDA CALC_ARG2 + 1
	STA DIV_DIVISOR + 1
	PHA

	; Clear the DIV_DIVIDEND_NEG flag, the DIV_DIVISOR_NEG flag, and DIV_RESULT
	LDA #$00
	STA DIV_DIVIDEND_NEG
	STA DIV_DIVISOR_NEG
	STA DIV_RESULT + 0
	STA DIV_RESULT + 1

	; Make the dividend negative
	LDA DIV_DIVIDEND + 1
	BMI op_div__dividend_negative ; Skip if already negative

	STA CALC_ARG1 + 1
	LDA DIV_DIVIDEND + 0
	STA CALC_ARG1 + 0

	JSR op_neg

	LDA CALC_RESULT1 + 0
	STA DIV_DIVIDEND + 0
	LDA CALC_RESULT1 + 1
	STA DIV_DIVIDEND + 1

	LDA #$01
	STA DIV_DIVIDEND_NEG ; Save fact that dividend was negated

	; Dividend is now negative
op_div__dividend_negative:

	; Make the divisor negative
	LDA DIV_DIVISOR + 1
	BMI op_div__divisor_negative ; Skip if already negative

	STA CALC_ARG1 + 1
	LDA DIV_DIVISOR + 0
	STA CALC_ARG1 + 0

	JSR op_neg

	LDA CALC_RESULT1 + 0
	STA DIV_DIVISOR + 0
	LDA CALC_RESULT1 + 1
	STA DIV_DIVISOR + 1

	LDA #$01
	STA DIV_DIVISOR_NEG ; Save fact that divisor was negated

	; Divisor is now negative
op_div__divisor_negative:

	; Shift divisor left until second-most significant bit is 0
	; MSbit must be 1 at this point because it's negative
	; Keep track of how many shifts we do
	LDA #$01 ; Loop needs to run for one more iteration to shift back because it's the last thing we do
	STA DIV_DIVISOR_SHIFT_COUNT

op_div__divisor_shift_left_loop:
	; Check second-MSbit
	LDA DIV_DIVISOR + 1
	BIT bits_table + 6
	BEQ op_div__divisor_shift_left_done

	; If != 0, shift left 
	LDA DIV_DIVISOR + 0
	STA CALC_ARG1 + 0
	LDA DIV_DIVISOR + 1
	STA CALC_ARG1 + 1
	
	LDA #$01
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_shl

	LDA CALC_RESULT1 + 0
	STA DIV_DIVISOR + 0
	LDA CALC_RESULT1 + 1
	STA DIV_DIVISOR + 1

	INC DIV_DIVISOR_SHIFT_COUNT

	JMP op_div__divisor_shift_left_loop
op_div__divisor_shift_left_done:

op_div__divide_loop:
	; Loop for DIV_DIVISOR_SHIFT_COUNT iters
	LDA DIV_DIVISOR_SHIFT_COUNT
	BEQ op_div__divide_done
	DEC DIV_DIVISOR_SHIFT_COUNT

	; Left-shift the result by 1
	LDA DIV_RESULT + 0
	STA CALC_ARG1 + 0
	LDA DIV_RESULT + 1
	STA CALC_ARG1 + 1

	LDA #$01
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_shl

	LDA CALC_RESULT1 + 0
	STA DIV_RESULT + 0
	LDA CALC_RESULT1 + 1
	STA DIV_RESULT + 1

	; Attempt DIVIDEND - DIVISOR
	LDA DIV_DIVIDEND + 0
	STA CALC_ARG1 + 0
	LDA DIV_DIVIDEND + 1
	STA CALC_ARG1 + 1

	LDA DIV_DIVISOR + 0
	STA CALC_ARG2 + 0
	LDA DIV_DIVISOR + 1
	STA CALC_ARG2 + 1

	JSR op_sub

	LDA CALC_RESULT1 + 1
	BMI op_div__divide_loop_sub_good
	; Check the rest of the bytes, all 0s is also okay
	ORA CALC_RESULT1 + 0
	BEQ op_div__divide_loop_sub_good

	; Here, the subtraction was too much so let's ignore it and complete this iter
	JMP op_div__divide_loop_iter_done

op_div__divide_loop_sub_good:
	; Successfully subtracted from the dividend, keep that change
	LDA CALC_RESULT1 + 0
	STA DIV_DIVIDEND + 0
	LDA CALC_RESULT1 + 1
	STA DIV_DIVIDEND + 1

	; Increment the result
	LDA DIV_RESULT + 0
	STA CALC_ARG1 + 0
	LDA DIV_RESULT + 1
	STA CALC_ARG1 + 1

	LDA #$01
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_add

	LDA CALC_RESULT1 + 0
	STA DIV_RESULT + 0
	LDA CALC_RESULT1 + 1
	STA DIV_RESULT + 1

op_div__divide_loop_iter_done:
	; Right-shift the divisor by 1
	LDA DIV_DIVISOR + 0
	STA CALC_ARG1 + 0
	LDA DIV_DIVISOR + 1
	STA CALC_ARG1 + 1

	LDA #$01
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_shr

	LDA CALC_RESULT1 + 0
	STA DIV_DIVISOR + 0
	LDA CALC_RESULT1 + 1
	STA DIV_DIVISOR + 1

	JMP op_div__divide_loop

op_div__divide_done:

	; Store the result of the mod
	LDA DIV_DIVIDEND_NEG
	BEQ op_div__result2_no_negation

	; Store the remaining dividend as the result of the mod
	; Need to negate mod result based on dividend
	LDA DIV_DIVIDEND + 0
	STA CALC_ARG1 + 0
	LDA DIV_DIVIDEND + 1
	STA CALC_ARG1 + 1

	JSR op_neg

	LDA CALC_RESULT1 + 0
	STA CALC_RESULT2 + 0
	LDA CALC_RESULT1 + 1
	STA CALC_RESULT2 + 1

	JMP op_div__result2_negation_done

op_div__result2_no_negation:

	; Store the remaining dividend as the result of the mod
	LDA DIV_DIVIDEND + 0
	STA CALC_RESULT2 + 0
	LDA DIV_DIVIDEND + 1
	STA CALC_RESULT2 + 1

op_div__result2_negation_done:

	; Store the result of the div
	LDA DIV_DIVISOR_NEG
	EOR DIV_DIVIDEND_NEG
	BEQ op_div__result1_no_negation

	; Need to negate div result based on both divisor and dividend
	LDA DIV_RESULT + 0
	STA CALC_ARG1 + 0
	LDA DIV_RESULT + 1
	STA CALC_ARG1 + 1

	JSR op_neg
	; New div result in result1 here
	JMP op_div__result1_negation_done

op_div__result1_no_negation:

	; No need to negate div result
	LDA DIV_RESULT + 0
	STA CALC_RESULT1 + 0
	LDA DIV_RESULT + 1
	STA CALC_RESULT1 + 1

op_div__result1_negation_done:

	; Clean up
	PLA
	STA CALC_ARG2 + 1
	PLA
	STA CALC_ARG2 + 0

	PLA
	STA CALC_ARG1 + 1
	PLA
	STA CALC_ARG1 + 0

	RTS

; Signed < operation
; Does not use CALC_RESULT2
op_lt_signed:
    ; Start with MSBytes
    LDA CALC_ARG2 + 1
    CMP CALC_ARG1 + 1

    BMI op_lt_signed__false	; If RHS - LHS < 0, LHS !< RHS
    BNE op_lt_signed__true	; If RHS - LHS > 0, LHS < RHS
    ; Otherwise, RHS - LHS = 0, need to check the next byte
	; All further checks from this point on are unsigned compares so we use the carry bit

    LDA CALC_ARG2 + 0
    LDA CALC_ARG1 + 0

    BCC op_lt_signed__false	; If RHS - LHS < 0
    BNE op_lt_signed__true

    ; Otherwise, RHS - LHS = 0, no more bytes left to check
    JMP op_lt_signed__false

op_lt_signed__true:
    LDA #$1
    JMP op_lt_signed__done
op_lt_signed__false:
    LDA #$0
op_lt_signed__done:
    STA CALC_RESULT1 + 0
    LDA #$0
    STA CALC_RESULT1 + 1
    RTS


; Negation operation
; Ignores CALC_ARG2
; Does not use CALC_RESULT2
op_neg:
	; Save CALC_ARG1 and CALC_ARG2 to be restored
	LDA CALC_ARG1 + 0
	PHA
	LDA CALC_ARG1 + 1
	PHA
	
	LDA CALC_ARG2 + 0
	PHA
	LDA CALC_ARG2 + 1
	PHA

	; Bitwise inverse CALC_ARG1 into CALC_ARG1
	LDA CALC_ARG1 + 0
	EOR #$FF
	STA CALC_ARG1 + 0

	LDA CALC_ARG1 + 1
	EOR #$FF
	STA CALC_ARG1 + 1

	; Add 1 to the result
	LDA #$01
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_add
	; Negated value now in CALC_RESULT1

	; Restore CALC_ARG1 and CALC_ARG2
	PLA
	LDA CALC_ARG2 + 1
	PLA
	LDA CALC_ARG2 + 0

	PLA
	LDA CALC_ARG1 + 1
	PLA
	LDA CALC_ARG1 + 0

	RTS

; ARG1 >> ARG2 (MSByte of ARG2 ignored)
; Does not perform sign extension
; Does not use CALC_RESULT2
op_shr_no_extend:
	LDA CALC_ARG1 + 0
	STA CALC_RESULT1 + 0
	LDA CALC_ARG1 + 1
	STA CALC_RESULT1 + 1

	LDA CALC_ARG2 + 0
	TAX

	JMP op_shr__loop_guard_zero_extend

; ARG1 >> ARG2 (MSByte of ARG2 ignored)
; Performs sign extension
; Does not use CALC_RESULT2
op_shr:
	LDA CALC_ARG1 + 0
	STA CALC_RESULT1 + 0
	LDA CALC_ARG1 + 1
	STA CALC_RESULT1 + 1

	LDA CALC_ARG2 + 0
	TAX

	LDA CALC_RESULT1 + 1
	BIT bits_table + 7 ; Check top bit of MSByte
	; If top bit is zero, shift without sign extension
	BEQ op_shr__loop_guard_zero_extend

; Loop with sign extension
op_shr__loop_guard_one_extend:
	TXA
	BEQ op_shr__done

	SEC
	ROR CALC_RESULT1 + 1
	ROR CALC_RESULT1 + 0
	DEX

	JMP op_shr__loop_guard_zero_extend

; Loop without sign extension
op_shr__loop_guard_zero_extend:
	TXA
	BEQ op_shr__done

	CLC
	ROR CALC_RESULT1 + 1
	ROR CALC_RESULT1 + 0
	DEX

	JMP op_shr__loop_guard_zero_extend

op_shr__done:
	RTS


; ARG1 << ARG2 (MSByte of ARG2 ignored)
; Does not use CALC_RESULT2
op_shl:
	LDA CALC_ARG1 + 0
	STA CALC_RESULT1 + 0
	LDA CALC_ARG1 + 1
	STA CALC_RESULT1 + 1

	LDA CALC_ARG2 + 0
	TAX

op_shl__loop_guard:
	TXA
	BEQ op_shl__done
op_shl__loop:
	CLC
	ROL CALC_RESULT1 + 0
	ROL CALC_RESULT1 + 1
	DEX

	JMP op_shl__loop_guard

op_shl__done:
	RTS


; 
; Stack Operations
;




; 
; Display Operations
; 




; 
; Hardware Interfaces
; 

; Read a key
read_key:
	LDY KEYPAD_DATA			; Read the key group index

read_key_wait:
	LDA VIA_REG_A
	AND #$04
	BNE read_key_wait		; If the second byte isn't ready, wait

	LDX KEYPAD_DATA			; Read the key down bitmask
	BNE read_key_pressed	; If the bitmask is not equal to zero, there's a keypress
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
