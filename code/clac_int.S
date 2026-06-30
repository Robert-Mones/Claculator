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

DISPLAY_INDEX	= $00	; One-byte index into the display buffer for looping
ENTRY_DRAW_NEEDED = $01 ; One-byte flag indicating a redraw of the entry portion of the display is needed

CALC_ARG1	= $02	; Two-byte arg for calculations
CALC_ARG2	= $04	; Two-byte arg for calculations
CALC_RESULT1	= $06	; Two-byte result for calculations

INPUT_BUFFER	= $08	; Two-byte buffer for entering an operand
FULL_DRAW_NEEDED	= $0A	; One-byte flag indicating a redraw of the whole display is needed

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
RENDER_RESULT = $24	; Eight-byte result of rendering a number
RENDER_NEGATIVE = $2C	; One-byte flag indicating that the number being rendered was negative
JUMP_TABLE_TEMP = $2D	; Two-byte buffer to write an address into to do indirect addressing jumps
ENTRY_BUFFER = $2F ; Two-byte buffer for incoming numbers to be entered
RENDER_BCD_RESULT = $31	; Three-byte buffer (five half-bytes) to compute BCD digits while performing a render
RENDER_BCD_RHS = $34	; Two-byte buffer for RHS of BCD algo

STACK = $0200	; 252-byte operand stack
DISPLAY_BUFFER = $0300 ; 72-byte buffer of the display RAM, first byte is MSDigit of #8 in stack

; ========================================

	SEG		text
	ORG $8000

start:
	; Initialize the stack pointer
	LDX #$FF
	TXS

	; Initialize the VIA
	LDA #$FF
	STA VIA_DDR_A
	LDA #$7F				; Set all besides B7 on the VIA to be outputs
	STA VIA_DDR_B

	; Initialize the ACIA
	/*
	STA ACIA_STATUS			; Software reset

	LDA #%00010000			; 1 stop bit, 8-bit word length, use baud rate, 115200 baud
	STA ACIA_CTRL

	LDA #%00001001			; IRQB enabled, data terminal ready
	STA ACIA_CMD
	*/

	; Initialize some variables
	LDA #$00
	STA ENTRY_BUFFER + 0
	STA ENTRY_BUFFER + 1
	STA STACK_SIZE
	
	; Initialize the display
	LDY #72
	LDA #$0
disp_init_loop:
	DEY
	STA DISPLAY_BUFFER,y
	BNE disp_init_loop
	STY DISPLAY_INDEX

	JSR draw_display

; Run the main loop
loop:
	LDA VIA_REG_B			; Check the VIA pin B7 for the status of the keypad
	AND #$80
	BNE skip_read_key		; If the interrupt bit is 1, go back to the beginning of loop
	JSR read_key			; If the interrupt bit is 0, read the keypress
skip_read_key:

	LDA FULL_DRAW_NEEDED	; Check the FULL_DRAW_NEEDED flag
	BEQ full_redraw_not_needed	; If it's 0, skip drawing the display
	JSR draw_display		; If it's non-zero, draw the display

	LDA #$00
	STA FULL_DRAW_NEEDED
	STA ENTRY_DRAW_NEEDED
	JMP redraw_done
full_redraw_not_needed:

	LDA ENTRY_DRAW_NEEDED
	BEQ redraw_done
	JSR draw_entry_display
	
	LDA #$00
	STA ENTRY_DRAW_NEEDED

	LDA #$00

redraw_done:

	JMP loop

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
op_mul:
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
	BEQ op_mul_fast__done ; If MUL_FAST_LOOP_COUNT == 0, we're done

	LDA MUL_FAST_ARG1 + 0
	ORA MUL_FAST_ARG1 + 1
	BEQ op_mul_fast__done ; If MUL_FAST_ARG != 0, we're not done yet

	JMP op_mul_fast__loop

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

	; Push a two-byte value to the stack
	; Uses the A and Y registers
	; Usage: stack_push { src }
	MACRO stack_push
		LDY STACK_SIZE
		
		LDA {1} + 0
		STA STACK,y
		INY

		LDA {1} + 1
		STA STACK,y
		INY

		INY ; Pad two bytes for future i32 support
		INY

		STY STACK_SIZE
	ENDM

	; Drop the value from the top of the stack
	MACRO stack_drop
		LDA STACK_SIZE
		SEC
		SBC #4
		STA STACK_SIZE
	ENDM

; 
; Key Press
;

; The incoming key code is stored in the A register
; X and Y are saved by the caller, A does not need to be saved
process_key:
	; First, add 29 to the keycode to make them all 0-whatever ([-29, 9] -> [0 - 38])
	; This range must be at most [0,127] to keep the jump table offset in 8 bits
	CLC
	ADC #29
	; Then double it to get a word-width offset
	ASL
	; Then put this value in Y to do the indexing
	TAY
	
	; Load the address from the jump table into the temp variable
	LDA process_key__jump_table,y
	STA JUMP_TABLE_TEMP
	LDA [process_key__jump_table + 1],y
	STA JUMP_TABLE_TEMP + 1
	
	; Jump to branch in switch case
	JMP (JUMP_TABLE_TEMP)

process_key__key__enter:
	; Push the value from the entry buffer onto the stack, then clear the entry buffer
	; Also move the rendered version of the display buffer to prevent re-rendering
	
	stack_push ENTRY_BUFFER

	; Check to make sure the value has actually been rendered (not the case for empty entries)
	LDA DISPLAY_BUFFER + 71
	BNE process_key__key__enter_render_done

	LDA ENTRY_BUFFER + 0
	STA CALC_ARG1 + 0
	LDA ENTRY_BUFFER + 1
	STA CALC_ARG1 + 1

	JSR render_number

	LDY #7
process_key__key__enter_render_copy_loop:
	LDA RENDER_RESULT,y
	STA [DISPLAY_BUFFER + 64],y
	DEY
	BPL process_key__key__enter_render_copy_loop

process_key__key__enter_render_done:

	; Move the display buffer up eight bytes (one row)
	; TODO optimize this to only copy the populated parts of the display buffer
	LDY #63
	LDX #0
process_key__key__enter_display_copy_loop:
	LDA [DISPLAY_BUFFER + 8],x
	STA DISPLAY_BUFFER,x
	INX
	DEY
	BPL process_key__key__enter_display_copy_loop

	LDA #0
	LDY #7
process_key__key__enter_display_clear_loop:
	STA [DISPLAY_BUFFER + 64],y
	DEY
	BPL process_key__key__enter_display_clear_loop

	LDA #00
	STA ENTRY_BUFFER + 0
	STA ENTRY_BUFFER + 1

	LDA #01
	STA FULL_DRAW_NEEDED

	JMP process_key__done

process_key__key__pos_neg:
	LDA ENTRY_BUFFER + 0
	STA CALC_ARG1 + 0
	LDA ENTRY_BUFFER + 1
	STA CALC_ARG2 + 1

	JSR op_neg

	LDA CALC_RESULT1 + 0
	STA CALC_ARG1 + 0
	STA ENTRY_BUFFER + 0
	LDA CALC_RESULT1 + 1
	STA CALC_ARG1 + 1
	STA ENTRY_BUFFER + 1

	JSR render_number

	LDY #7
process_key__key__pos_neg_copy_loop:
	LDA RENDER_RESULT,y
	STA [DISPLAY_BUFFER + 64],y
	DEY
	BPL process_key__key__pos_neg_copy_loop

	LDA #$01
	STA ENTRY_DRAW_NEEDED

	JMP process_key__done

process_key__key__backspace:
	LDA ENTRY_BUFFER + 0
	STA CALC_ARG1 + 0
	LDA ENTRY_BUFFER + 1
	STA CALC_ARG1 + 1

	LDA #10
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_divmod

	LDA CALC_RESULT1 + 0
	STA CALC_ARG1 + 0
	STA ENTRY_BUFFER + 0
	LDA CALC_RESULT1 + 1
	STA CALC_ARG1 + 1
	STA ENTRY_BUFFER + 1

	JSR render_number

	LDY #7
process_key__key__backspace_copy_loop:
	LDA RENDER_RESULT,y
	STA [DISPLAY_BUFFER + 64],y
	DEY
	BPL process_key__key__backspace_copy_loop

	LDA #$01
	STA ENTRY_DRAW_NEEDED

	JMP process_key__done

process_key__key__decimal:
	JMP process_key__done

process_key__key__sci_not_e:
	JMP process_key__done

process_key__key__div:
	JMP process_key__done

process_key__key__mul:
	JMP process_key__done

process_key__key__sub:
	JMP process_key__done

process_key__key__add:
	JMP process_key__done

process_key__key__mod:
	JMP process_key__done

process_key__key__reciprocal:
	JMP process_key__done

process_key__key__square_root:
	JMP process_key__done

process_key__key__square:
	JMP process_key__done

process_key__key__floor:
	JMP process_key__done

process_key__key__ceiling:
	JMP process_key__done

process_key__key__nth_root:
	JMP process_key__done

process_key__key__exponent:
	JMP process_key__done

process_key__key__drop:
	; Drop the value from the top of the stack
	; Also move the rendered version of the display buffer to prevent re-rendering
	stack_drop

	; Move the display buffer up eight bytes (one row)
	; TODO optimize this to only copy the populated parts of the display buffer
	LDY #55
process_key__key__drop_display_copy_loop:
	LDA DISPLAY_BUFFER,y
	STA [DISPLAY_BUFFER + 8],y
	DEY
	BPL process_key__key__drop_display_copy_loop

	; By now the stack size has already been decremented, if there's still at least 32 bytes left (8 numbers),
	;   re-render the 8th number in the stack and put it in the display buffer
	LDA STACK_SIZE
	SEC
	SBC #32
	BMI process_key__key__drop_clear_8th_spot
	
	; A now has the offset into the stack of the 8th number
	TAY

	LDA [STACK + 0],y
	STA CALC_ARG1 + 0
	LDA [STACK + 1],y
	STA CALC_ARG1 + 1

	JSR render_number

	LDY #7
process_key__key__drop_display_copy_new_loop:
	LDA RENDER_RESULT,y
	STA DISPLAY_BUFFER,y
	DEY
	BPL process_key__key__drop_display_copy_new_loop

	JMP process_key__key__drop_done

process_key__key__drop_clear_8th_spot:
	LDA #0
	LDY #7
process_key__key__drop_display_clear_loop:
	STA DISPLAY_BUFFER,y
	DEY
	BPL process_key__key__drop_display_clear_loop
	
process_key__key__drop_done:
	LDA #01
	STA FULL_DRAW_NEEDED

	JMP process_key__done

process_key__key__swap:
	JMP process_key__done

process_key__key__rotate:
	JMP process_key__done

process_key__key__pick:
	JMP process_key__done

process_key__key__skip:
	JMP process_key__done

process_key__key__if:
	JMP process_key__done

process_key__key__noop:
	JMP process_key__done

process_key__key__less_than:
	JMP process_key__done

process_key__key__P:
	JMP process_key__done

process_key__key__semicolon:
	JMP process_key__done

process_key__key__colon:
	JMP process_key__done

process_key__key__clear:
	LDA #0
	STA STACK_SIZE

	LDY #63
process_key__key__clear_loop:
	STA DISPLAY_BUFFER,y
	DEY
	BPL process_key__key__clear_loop

	LDA #1
	STA FULL_DRAW_NEEDED

	JMP process_key__done

process_key__key__digit_zero:
	LDA #0
	JMP process_key__digit_common

process_key__key__digit_one:
	LDA #1
	JMP process_key__digit_common

process_key__key__digit_two:
	LDA #2
	JMP process_key__digit_common

process_key__key__digit_three:
	LDA #3
	JMP process_key__digit_common

process_key__key__digit_four:
	LDA #4
	JMP process_key__digit_common

process_key__key__digit_five:
	LDA #5
	JMP process_key__digit_common

process_key__key__digit_six:
	LDA #6
	JMP process_key__digit_common

process_key__key__digit_seven:
	LDA #7
	JMP process_key__digit_common

process_key__key__digit_eight:
	LDA #8
	JMP process_key__digit_common

process_key__key__digit_nine:
	LDA #9
	JMP process_key__digit_common

process_key__digit_common:
	PHA

	LDA ENTRY_BUFFER + 0
	STA CALC_ARG1 + 0
	LDA ENTRY_BUFFER + 1
	STA CALC_ARG1 + 1
	PHA

	LDA #10
	STA CALC_ARG2 + 0
	LDA #$00
	STA CALC_ARG2 + 1

	JSR op_mul

	LDA CALC_RESULT1 + 0
	STA CALC_ARG1 + 0
	LDA CALC_RESULT1 + 1
	STA CALC_ARG1 + 1

	PLA
	BMI process_key__digit_common_negative

	PLA
	STA CALC_ARG2 + 0

	JSR op_add

	JMP process_key__digit_common_add_sub_done

process_key__digit_common_negative:
	PLA
	STA CALC_ARG2 + 0

	JSR op_sub

process_key__digit_common_add_sub_done:

	LDA CALC_RESULT1 + 0
	STA CALC_ARG1 + 0
	STA ENTRY_BUFFER + 0
	LDA CALC_RESULT1 + 1
	STA CALC_ARG1 + 1
	STA ENTRY_BUFFER + 1

	JSR render_number

	LDY #7
process_key__digit_common_copy_loop:
	LDA RENDER_RESULT,y
	STA [DISPLAY_BUFFER + 64],y
	DEY
	BPL process_key__digit_common_copy_loop

	LDA #$01
	STA ENTRY_DRAW_NEEDED

	JMP process_key__done

process_key__done:
	RTS ; Real RTS

read_key__found:
	LDY DISPLAY_INDEX
	JSR segment_print
	INC DISPLAY_INDEX
	LDA DISPLAY_INDEX
	CMP #72
	BNE dont_rst_disp_index
	LDA #0
	STA DISPLAY_INDEX
dont_rst_disp_index:
	LDA #$01
	STA FULL_DRAW_NEEDED
	RTS

; Prints the number in the A register to the Y-th seven-segment digit
segment_print:
	PHA
	TAX
	LDA segment_table,x
	STA DISPLAY_BUFFER,y
	PLA
	RTS

; Keep these sorted low to high
; All have -1 for now because using RTS instead of JMP until c02 is implemented
process_key__jump_table:
	DC.W process_key__key__enter
	DC.W process_key__key__pos_neg
	DC.W process_key__key__backspace
	DC.W process_key__key__decimal
	DC.W process_key__key__sci_not_e
	DC.W process_key__key__div
	DC.W process_key__key__mul
	DC.W process_key__key__sub
	DC.W process_key__key__add
	DC.W process_key__key__mod
	DC.W process_key__key__reciprocal
	DC.W process_key__key__square_root
	DC.W process_key__key__square
	DC.W process_key__key__floor
	DC.W process_key__key__ceiling
	DC.W process_key__key__nth_root
	DC.W process_key__key__exponent
	DC.W process_key__key__drop
	DC.W process_key__key__swap
	DC.W process_key__key__rotate
	DC.W process_key__key__pick
	DC.W process_key__key__skip
	DC.W process_key__key__if
	DC.W process_key__key__noop
	DC.W process_key__key__less_than
	DC.W process_key__key__P
	DC.W process_key__key__semicolon
	DC.W process_key__key__colon
	DC.W process_key__key__clear
	DC.W process_key__key__digit_zero
	DC.W process_key__key__digit_one
	DC.W process_key__key__digit_two
	DC.W process_key__key__digit_three
	DC.W process_key__key__digit_four
	DC.W process_key__key__digit_five
	DC.W process_key__key__digit_six
	DC.W process_key__key__digit_seven
	DC.W process_key__key__digit_eight
	DC.W process_key__key__digit_nine

; 
; Display Operations
; 

draw_display:
	LDY #71
draw_display__loop:
	LDA DISPLAY_BUFFER,y
	STA DISPLAY_RAM,y
	DEY
	BPL draw_display__loop

	RTS

draw_entry_display:
	LDY #7
draw_entry_display__loop:
	LDA [DISPLAY_BUFFER + 64],y
	STA [DISPLAY_RAM + 64],y
	DEY
	BPL draw_entry_display__loop

	RTS

render_number:
	; Save args to restore at the end
	LDA CALC_ARG1 + 0
	STA RENDER_BCD_RHS + 0
	PHA
	LDA CALC_ARG1 + 1
	STA RENDER_BCD_RHS + 1
	PHA
	
	LDA #$00 ; Clear RENDER_RESULT, RENDER_BCD_RESULT, and RENDER_NEGATIVE
	STA RENDER_RESULT + 0
	STA RENDER_RESULT + 1
	STA RENDER_RESULT + 2
	STA RENDER_RESULT + 3
	STA RENDER_RESULT + 4
	STA RENDER_RESULT + 5
	STA RENDER_RESULT + 6
	STA RENDER_RESULT + 7
	STA RENDER_BCD_RESULT + 0
	STA RENDER_BCD_RESULT + 1
	STA RENDER_BCD_RESULT + 2
	STA RENDER_NEGATIVE

	LDA CALC_ARG1 + 1
	BPL render_number__arg1_positive
	
	JSR op_neg

	LDA CALC_RESULT1 + 0
	STA RENDER_BCD_RHS + 0
	LDA CALC_RESULT1 + 1
	STA RENDER_BCD_RHS + 1

	LDA #$01
	STA RENDER_NEGATIVE

render_number__arg1_positive:

	; At this point, RENDER_BCD_RHS is u16

	LDY #16

render_number__bcd_loop:

	; Do block >= 5 checking

	; Block 0
	LDA RENDER_BCD_RESULT + 0
	AND #$0F
	CMP #$5
	BMI render_number__skip_block_0
	; Add 3
	LDA RENDER_BCD_RESULT + 0
	CLC
	ADC #$3
	STA RENDER_BCD_RESULT + 0
render_number__skip_block_0:

	; Block 1
	LDA RENDER_BCD_RESULT + 0
	AND #$F0
	CMP #$50
	BMI render_number__skip_block_1
	; Add 3
	LDA RENDER_BCD_RESULT + 0
	CLC
	ADC #$30
	STA RENDER_BCD_RESULT + 0
render_number__skip_block_1:

	; Block 2
	LDA RENDER_BCD_RESULT + 1
	AND #$0F
	CMP #$5
	BMI render_number__skip_block_2
	; Add 3
	LDA RENDER_BCD_RESULT + 1
	CLC
	ADC #$3
	STA RENDER_BCD_RESULT + 1
render_number__skip_block_2:

	; Block 3
	LDA RENDER_BCD_RESULT + 1
	AND #$F0
	CMP #$50
	BMI render_number__skip_block_3
	; Add 3
	LDA RENDER_BCD_RESULT + 1
	CLC
	ADC #$30
	STA RENDER_BCD_RESULT + 1
render_number__skip_block_3:

	; Block 4
	LDA RENDER_BCD_RESULT + 2
	AND #$0F
	CMP #$5
	BMI render_number__skip_block_4
	; Add 3
	LDA RENDER_BCD_RESULT + 2
	CLC
	ADC #$3
	STA RENDER_BCD_RESULT + 2
render_number__skip_block_4:

	; Do big left shift
	CLC
	ROL RENDER_BCD_RHS + 0
	ROL RENDER_BCD_RHS + 1
	ROL RENDER_BCD_RESULT + 0
	ROL RENDER_BCD_RESULT + 1
	ROL RENDER_BCD_RESULT + 2

	; Loop over all bits
	DEY
	BNE render_number__bcd_loop

	; Find the leftmost non-zero digit and store its index in Y, index 7 is LSDigit to match memory layout

	; Check block 4
	LDY #3
	LDA RENDER_BCD_RESULT + 2
	AND #$0F
	BNE render_number__display_block_4

	; Check block 3
	LDY #4
	LDA RENDER_BCD_RESULT + 1
	AND #$F0
	BNE render_number__display_block_3

	; Check block 2
	LDY #5
	LDA RENDER_BCD_RESULT + 1
	AND #$0F
	BNE render_number__display_block_2

	; Check block 1
	LDY #6
	LDA RENDER_BCD_RESULT + 0
	AND #$F0
	BNE render_number__display_block_1
	
	; Check block 0
	; We don't care about the result here, always render one digit
	LDY #7
	JMP render_number__display_block_0

	; Go through each BCD result chunk and turn it into a digit
	
render_number__display_block_4:
	; Block 4
	LDA RENDER_BCD_RESULT + 2
	AND #$0F
	TAX
	LDA segment_table,x
	STA RENDER_RESULT + 3
	
render_number__display_block_3:
	; Block 3
	LDA RENDER_BCD_RESULT + 1
	LSR
	LSR
	LSR
	LSR
	TAX
	LDA segment_table,x
	STA RENDER_RESULT + 4
	
render_number__display_block_2:
	; Block 2
	LDA RENDER_BCD_RESULT + 1
	AND #$0F
	TAX
	LDA segment_table,x
	STA RENDER_RESULT + 5

render_number__display_block_1:
	; Block 1
	LDA RENDER_BCD_RESULT + 0
	LSR
	LSR
	LSR
	LSR
	TAX
	LDA segment_table,x
	STA RENDER_RESULT + 6
	
render_number__display_block_0:
	; Block 0
	LDA RENDER_BCD_RESULT + 0
	AND #$0F
	TAX
	LDA segment_table,x
	STA RENDER_RESULT + 7

	DEY ; Decrement Y so that the negative sign goes one digit to the left of the leftmost digit

	; Optionally render a minus sign
	LDA RENDER_NEGATIVE
	BEQ render_number__done

	LDA #SEGMENT_MINUS
	STA RENDER_RESULT,y

render_number__done:

	; Restore args
	PLA
	STA CALC_ARG1 + 1
	PLA
	STA CALC_ARG1 + 0

	RTS

; 
; Hardware Interfaces
; 

; Read a key
read_key:
	LDY KEYPAD_DATA			; Read the key group index

read_key__wait:
	LDA VIA_REG_B
	AND #$80
	BNE read_key__wait		; If the second byte isn't ready, wait

	LDX KEYPAD_DATA			; Read the key down bitmask
	BNE read_key__pressed	; If the bitmask is not equal to zero, there's a keypress
	RTS
read_key__pressed:
	TYA						; Put key group index << 3 in Y
	ASL
	ASL
	ASL
	TAY

	TXA						; Put the orig bitmask in A
read_key__pressed_loop:
	AND #$1					; Test the lsb
	BEQ read_key__key_processing_done ; Skip if there's no keypress

	; Save X and Y registers
	TXA
	PHA
	TYA
	PHA

	LDA number_table,y

	JSR process_key
	
	; Restore X and Y registers
	PLA
	TAY
	PLA
	TAX

read_key__key_processing_done:
	TXA						; Put the most recent bitmask back in A
	LSR						; Right-shift it by 1 and put it back in X
	TAX
	INY

	TXA
	BNE read_key__pressed_loop ; If there's still keys in the bitmask, keep going

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

; This is kind of contrived but I decided to keep digits their own values and make all the ops negative so I could easily check for it
; This number mapping was chosen somewhat arbitrarily
	; Clear -1
	; Colon -2
	; Semicolon -3
	; P -4
	; Less Than -5
	; Noop -6
	; If -7
	; Skip -8
	; Pick -9
	; Rotate -10
	; Swap -11
	; Drop -12
	; Exp -13
	; Nth Root -14
	; Ceiling -15
	; Floor -16
	; Square -17
	; Square root -18
	; Recip -19
	; Mod -20
	; Add -21
	; Sub -22
	; Mul -23
	; Div -24
	; Sci Not Exp -25
	; Decimal -26
	; Backspace -27
	; Pos/Neg -28
	; Enter -29
number_table:
	DC.B 9,-27,6,-28,3,-29,-26,-29,7,8,4,5,1,2,-25,0,-17,-21,-18,-22,-19,-23,-20,-24,-9,-13,-10,-14,-11,-15,-12,-16,-1,-5,-2,-6,-3,-7,-4,-8

segment_table:
	DC.B %00111111, %00000110, %01011011, %01001111, %01100110, %01101101, %01111101, %00000111, %01111111, %01101111, %00001001

; Remember to use these in immediate mode! LDA #SEGMENT_MINUS, not LDA SEGMENT_MINUS
SEGMENT_MINUS = %01000000

	ORG $FFFA
vector_table:
	DC.W start			; NMI
	DC.W start			; RESET
	DC.W irq_handler	; IRQ
