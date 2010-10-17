	.DATA
/****************************************************************	
****************************************************************/
	.align 4

    @ notaz
	.equiv ASM_SPC700, 		1		;@ 1 = use notaz's ASM_SPC700 core

/****************************************************************
	DEFINES
****************************************************************/

.equ MAP_LAST,	12

rstatus 	.req R4  @ format : 0xff800000
reg_d_bank	.req R4  @ format : 0x000000ll
reg_a		.req R5  @ format : 0xhhll0000 or 0xll000000
reg_d		.req R6  @ format : 0xhhll0000
reg_p_bank	.req R6  @ format : 0x000000ll
reg_x		.req R7  @ format : 0xhhll0000 or 0xll000000
reg_s		.req R8  @ format : 0x0000hhll
reg_y		.req R9  @ format : 0xhhll0000 or 0xll000000

rpc	    	.req R10 @ 32bits address
reg_cycles	.req R11 @ 32bits counter
regpcbase	.req R12 @ 32bits address

rscratch	.req R0  @ format : 0xhhll0000 if data and calculation or return of S9XREADBYTE	or WORD
regopcode	.req R0  @ format : 0x000000ll
rscratch2	.req R1  @ format : 0xhhll for calculation and value
rscratch3	.req R2  @ 
rscratch4	.req R3  @ ??????

@ used for SBC opcode
rscratch9	.req R10 @ ??????

reg_cpu_var .req R14



@ not used
@ R13	@ Pointer 32 bit on a struct.

@ R15 = pc (sic!)


/*
.equ Carry       1
.equ Zero        2
.equ IRQ         4
.equ Decimal     8
.equ IndexFlag  16
.equ MemoryFlag 32
.equ Overflow   64
.equ Negative  128
.equ Emulation 256*/

.equ STATUS_SHIFTER,		24
.equ MASK_EMUL,		(1<<(STATUS_SHIFTER-1))
.equ MASK_SHIFTER_CARRY,	(STATUS_SHIFTER+1)
.equ	MASK_CARRY,		(1<<(STATUS_SHIFTER))  @ 0
.equ	MASK_ZERO,		(2<<(STATUS_SHIFTER))  @ 1
.equ MASK_IRQ,		(4<<(STATUS_SHIFTER))  @ 2
.equ MASK_DECIMAL,		(8<<(STATUS_SHIFTER))  @ 3
.equ	MASK_INDEX,		(16<<(STATUS_SHIFTER)) @ 4  @ 1
.equ	MASK_MEM,		(32<<(STATUS_SHIFTER)) @ 5  @ 2
.equ	MASK_OVERFLOW,		(64<<(STATUS_SHIFTER)) @ 6  @ 4
.equ	MASK_NEG,		(128<<(STATUS_SHIFTER))@ 7  @ 8

.equ ONE_CYCLE, 6
.equ SLOW_ONE_CYCLE, 8

.equ	NMI_FLAG,	    (1 << 7)
.equ IRQ_PENDING_FLAG,    (1 << 11)
.equ SCAN_KEYS_FLAG,	    (1 << 4)


.equ MEMMAP_BLOCK_SIZE, (0x1000)
.equ MEMMAP_SHIFT, 12
.equ MEMMAP_MASK, (0xFFF)

/****************************************************************
	MACROS
****************************************************************/

@ #include "os9x_65c816_mac_gen.h"
/*****************************************************************/
/*     Offset in SCPUState structure				 */
/*****************************************************************/
.equ Flags_ofs,		    0    
.equ BranchSkip_ofs,	4
.equ NMIActive_ofs,		5
.equ IRQActive_ofs,		6
.equ WaitingForInterrupt_ofs,	7

.equ	RPB_ofs,		8
.equ	RDB_ofs,		9
.equ	RP_ofs,		    10
.equ	RA_ofs,		    12
.equ    RAH_ofs,	    13
.equ	RD_ofs,		    14
.equ	RX_ofs,		    16
.equ	RS_ofs,		    18
.equ	RY_ofs,		    20
@.equ	RPC_ofs,		22
   
.equ PC_ofs,			24
.equ Cycles_ofs,		28
.equ PCBase_ofs,		32

.equ PCAtOpcodeStart_ofs,	36
.equ WaitAddress_ofs,		40
.equ WaitCounter_ofs,		44
.equ NextEvent_ofs,		    48
.equ V_Counter_ofs,		    52
.equ MemSpeed_ofs,		    56
.equ MemSpeedx2_ofs,		60
.equ FastROMSpeed_ofs,	    64
.equ AutoSaveTimer_ofs,	    68
.equ NMITriggerPoint_ofs,	72
.equ NMICycleCount_ofs,	    76
.equ IRQCycleCount_ofs,	    80

.equ InDMA_ofs,		        84
.equ WhichEvent,		    85
.equ SRAMModified_ofs,	    86
.equ BRKTriggered_ofs,	    87
.equ	asm_OPTABLE_ofs,		88
.equ TriedInterleavedMode2_ofs,	92

.equ Map_ofs,		    96
.equ WriteMap_ofs,      100
.equ MemorySpeed_ofs,   104
.equ BlockIsRAM_ofs,    108
.equ SRAM, 		        112
.equ BWRAM,             116
.equ SRAMMask,          120

.equ	APUExecuting_ofs,   122

.equ	PALMOS_R9_ofs, 	    124
.equ	PALMOS_R10_ofs, 	128

@ notaz
.equ	APU_Cycles, 	    132

/*****************************************************************/

/* prepare */
.macro		PREPARE_C_CALL
	STMFD	R13!,{R12,R14}	
.endm
.macro		PREPARE_C_CALL_R0
	STMFD	R13!,{R0,R12,R14}	
.endm
.macro		PREPARE_C_CALL_R0R1
	STMFD	R13!,{R0,R1,R12,R14}		
.endm
.macro		PREPARE_C_CALL_LIGHT
	STMFD	R13!,{R14}
.endm
.macro		PREPARE_C_CALL_LIGHTR12
	STMFD	R13!,{R12,R14}
.endm
/* restore */
.macro		RESTORE_C_CALL
	LDMFD	R13!,{R12,R14}
.endm
.macro		RESTORE_C_CALL_R0
	LDMFD	R13!,{R0,R12,R14}
.endm
.macro		RESTORE_C_CALL_R1
	LDMFD	R13!,{R1,R12,R14}
.endm
.macro		RESTORE_C_CALL_LIGHT
	LDMFD	R13!,{R14}
.endm
.macro		RESTORE_C_CALL_LIGHTR12
	LDMFD	R13!,{R12,R14}
.endm


@ --------------
.macro		LOAD_REGS
    @ notaz
    add     r0,reg_cpu_var,#8
    ldmia   r0,{r1,reg_a,reg_x,reg_y,rpc,reg_cycles,regpcbase}
    @ rstatus (P) & reg_d_bank
    mov     reg_d_bank,r1,lsl #16
    mov     reg_d_bank,reg_d_bank,lsr #24
    mov     r0,r1,lsr #16
	orrs	rstatus, rstatus, r0,lsl #STATUS_SHIFTER @ 24
	@ if Carry set, then EMULATION bit was set
	orrcs	rstatus,rstatus,#MASK_EMUL	
    @ reg_d & reg_p_bank
    mov     reg_d,reg_a,lsr #16
    mov     reg_d,reg_d,lsl #8
    orr     reg_d,reg_d,r1,lsl #24
    mov     reg_d,reg_d,ror #24    @ 0xdddd00pb
    @ reg_x, reg_s
    mov     reg_s,reg_x,lsr #16
	@ Shift X,Y & A according to the current mode (INDEX, MEMORY bits)
	tst		rstatus,#MASK_INDEX
	movne	reg_x,reg_x,lsl #24
	movne	reg_y,reg_y,lsl #24
	moveq	reg_x,reg_x,lsl #16
	moveq	reg_y,reg_y,lsl #16
	tst		rstatus,#MASK_MEM
	movne	reg_a,reg_a,lsl #24
	moveq	reg_a,reg_a,lsl #16

/*
    @ reg_d & reg_p_bank share the same register
	LDRB		reg_p_bank,[reg_cpu_var,#RPB_ofs]
	LDRH		rscratch,[reg_cpu_var,#RD_ofs]
	ORR		reg_d,reg_d,rscratch, LSL #16	
	@ rstatus & reg_d_bank share the same register
	LDRB		reg_d_bank,[reg_cpu_var,#RDB_ofs]
	LDRH		rscratch,[reg_cpu_var,#RP_ofs]	
	ORRS		rstatus, rstatus, rscratch,LSL #STATUS_SHIFTER @ 24
	@ if Carry set, then EMULATION bit was set
	ORRCS		rstatus,rstatus,#MASK_EMUL	
	@ 
	LDRH		reg_a,[reg_cpu_var,#RA_ofs]		
	LDRH		reg_x,[reg_cpu_var,#RX_ofs]
	LDRH		reg_y,[reg_cpu_var,#RY_ofs]
	LDRH		reg_s,[reg_cpu_var,#RS_ofs]
	@ Shift X,Y & A according to the current mode (INDEX, MEMORY bits)
	TST		rstatus,#MASK_INDEX
	MOVNE		reg_x,reg_x,LSL #24
	MOVNE		reg_y,reg_y,LSL #24
	MOVEQ		reg_x,reg_x,LSL #16
	MOVEQ		reg_y,reg_y,LSL #16
	TST		rstatus,#MASK_MEM
	MOVNE		reg_a,reg_a,LSL #24
	MOVEQ		reg_a,reg_a,LSL #16
	
	LDR		regpcbase,[reg_cpu_var,#PCBase_ofs]
	LDR		rpc,[reg_cpu_var,#PC_ofs]	
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs]
*/
.endm


.macro		SAVE_REGS
    @ notaz
    @ reg_p_bank, reg_d_bank and rstatus
    mov 	r1, rstatus, lsr #16
    orr     r1, r1, reg_p_bank, lsl #24
	movs	r1, r1, lsr #8
	orrcs	r1, r1, #0x100 @ EMULATION bit
    orr     r1, r1, reg_d_bank, lsl #24
    mov     r1, r1, ror #16
    @ reg_a, reg_d
	tst		rstatus,#MASK_MEM
	ldrneh	r0, [reg_cpu_var,#RA_ofs]
	bicne	r0, r0,#0xFF
	orrne	reg_a, r0, reg_a,lsr #24	
	moveq	reg_a, reg_a, lsr #16
    mov     reg_d, reg_d, lsr #16
	orr  	reg_a, reg_a, reg_d, lsl #16
	@ Shift X&Y according to the current mode (INDEX, MEMORY bits)
	tst		rstatus,#MASK_INDEX
	movne	reg_x,reg_x,LSR #24
	movne	reg_y,reg_y,LSR #24
	moveq	reg_x,reg_x,LSR #16
	moveq	reg_y,reg_y,LSR #16
    @ reg_x, reg_s
	orr  	reg_x, reg_x, reg_s, lsl #16
    @ store
    add     r0,reg_cpu_var,#8
    stmia   r0,{r1,reg_a,reg_x,reg_y,rpc,reg_cycles,regpcbase}

/*
    @ reg_d & reg_p_bank is same register
	STRB		reg_p_bank,[reg_cpu_var,#RPB_ofs]
	MOV		rscratch,reg_d, LSR #16
	STRH		rscratch,[reg_cpu_var,#RD_ofs]
	@ rstatus & reg_d_bank is same register
	STRB		reg_d_bank,[reg_cpu_var,#RDB_ofs]
	MOVS		rscratch, rstatus, LSR #STATUS_SHIFTER  
	ORRCS		rscratch,rscratch,#0x100 @ EMULATION bit
	STRH		rscratch,[reg_cpu_var,#RP_ofs]
	@ 
	@ Shift X,Y & A according to the current mode (INDEX, MEMORY bits)
	TST		rstatus,#MASK_INDEX
	MOVNE		rscratch,reg_x,LSR #24
	MOVNE		rscratch2,reg_y,LSR #24
	MOVEQ		rscratch,reg_x,LSR #16
	MOVEQ		rscratch2,reg_y,LSR #16
	STRH		rscratch,[reg_cpu_var,#RX_ofs]
	STRH		rscratch2,[reg_cpu_var,#RY_ofs]
	TST		rstatus,#MASK_MEM
	LDRNEH		rscratch,[reg_cpu_var,#RA_ofs]
	BICNE		rscratch,rscratch,#0xFF
	ORRNE		rscratch,rscratch,reg_a,LSR #24	
	MOVEQ		rscratch,reg_a,LSR #16
	STRH		rscratch,[reg_cpu_var,#RA_ofs]
	
	STRH		reg_s,[reg_cpu_var,#RS_ofs]	
	STR		regpcbase,[reg_cpu_var,#PCBase_ofs]
	STR		rpc,[reg_cpu_var,#PC_ofs]
	
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs]
*/
.endm

/*****************************************************************/
.macro		ADD1CYCLE		
		add	reg_cycles,reg_cycles, #ONE_CYCLE		
.endm
.macro		ADD1CYCLENE
		addne	reg_cycles,reg_cycles, #ONE_CYCLE		
.endm		
.macro		ADD1CYCLEEQ
		addeq	reg_cycles,reg_cycles, #ONE_CYCLE		
.endm		

.macro		ADD2CYCLE
		add	reg_cycles,reg_cycles, #(ONE_CYCLE*2)
.endm
.macro		ADD2CYCLENE
		addne	reg_cycles,reg_cycles, #(ONE_CYCLE*2)
.endm
.macro		ADD2CYCLE2MEM		
		ldr	rscratch,[reg_cpu_var,#MemSpeed_ofs]
		add	reg_cycles,reg_cycles, #(ONE_CYCLE*2)
		add	reg_cycles, reg_cycles, rscratch, LSL #1		
.endm
.macro		ADD2CYCLE1MEM
		ldr	rscratch,[reg_cpu_var,#MemSpeed_ofs]
		add	reg_cycles,reg_cycles, #(ONE_CYCLE*2)
		add	reg_cycles, reg_cycles, rscratch
.endm

.macro		ADD3CYCLE
		add	reg_cycles,reg_cycles, #(ONE_CYCLE*3)
.endm

.macro		ADD1CYCLE1MEM
		ldr	rscratch,[reg_cpu_var,#MemSpeed_ofs]
		add	reg_cycles,reg_cycles, #ONE_CYCLE
		add	reg_cycles, reg_cycles, rscratch
.endm

.macro		ADD1CYCLE2MEM
		ldr	rscratch,[reg_cpu_var,#MemSpeed_ofs]
		add	reg_cycles,reg_cycles, #ONE_CYCLE
		add	reg_cycles, reg_cycles, rscratch, lsl #1
.endm

.macro		ADD1MEM
		ldr	rscratch,[reg_cpu_var,#MemSpeed_ofs]		
		add	reg_cycles, reg_cycles, rscratch
.endm
			
.macro		ADD2MEM
		ldr	rscratch,[reg_cpu_var,#MemSpeed_ofs]		
		add	reg_cycles, reg_cycles, rscratch, lsl #1
.endm
			
.macro		ADD3MEM
		ldr	rscratch,[reg_cpu_var,#MemSpeed_ofs]		
		add	reg_cycles, rscratch, reg_cycles
		add	reg_cycles, reg_cycles, rscratch, lsl #1
.endm

/**************/
.macro		ClearDecimal
		BIC	rstatus,rstatus,#MASK_DECIMAL	
.endm			
.macro		SetDecimal
		ORR	rstatus,rstatus,#MASK_DECIMAL	
.endm
.macro		SetIRQ
		ORR	rstatus,rstatus,#MASK_IRQ
.endm						
.macro		ClearIRQ
		BIC	rstatus,rstatus,#MASK_IRQ
.endm

.macro		CPUShutdown
@ if (Settings.Shutdown && CPU.PC == CPU.WaitAddress)
		LDR		rscratch,[reg_cpu_var,#WaitAddress_ofs]
		CMP		rpc,rscratch
		BNE		5431f
@ if (CPU.WaitCounter == 0 && !(CPU.Flags & (IRQ_PENDING_FLAG | NMI_FLAG)))		
		LDR		rscratch,[reg_cpu_var,#Flags_ofs]
		LDR		rscratch2,[reg_cpu_var,#WaitCounter_ofs]
		TST		rscratch,#(IRQ_PENDING_FLAG|NMI_FLAG)
		BNE		5432f		
		MOVS		rscratch2,rscratch2
		BNE		5432f
@ CPU.WaitAddress = NULL;		
		MOV		rscratch,#0
		STR		rscratch,[reg_cpu_var,#WaitAddress_ofs]
@ if (Settings.SA1)
@ 		S9xSA1ExecuteDuringSleep ();		: TODO
		
@ 	    CPU.Cycles = CPU.NextEvent;
		LDR		reg_cycles,[reg_cpu_var,#NextEvent_ofs]
		LDRB		r0,[reg_cpu_var,#APUExecuting_ofs]
		MOVS		r0,r0
		BEQ		5431f
@ 	    if (IAPU.APUExecuting)
/*	    {
		ICPU.CPUExecuting = FALSE;
		do
		{
		    APU_EXECUTE1();
		} while (APU.Cycles < CPU.NextEvent);
		ICPU.CPUExecuting = TRUE;
	    }
	*/					
		asmAPU_EXECUTE2
		B		5431f
@.pool		
5432:
/*	else
	if (CPU.WaitCounter >= 2)
	    CPU.WaitCounter = 1;
	else
	    CPU.WaitCounter--;
*/
		CMP		rscratch2,#1
		MOVHI		rscratch2,#1
		@ SUBLS		rscratch2,rscratch2,#1
		MOVLS		rscratch2,#0
		STR		rscratch2,[reg_cpu_var,#WaitCounter_ofs]
5431:		

.endm						
.macro		BranchCheck0	
		/*in rsctach : OpAddress
		/*destroy rscratch2*/
		LDRB	rscratch2,[reg_cpu_var,#BranchSkip_ofs]
		MOVS	rscratch2,rscratch2	
		BEQ	1110f
		MOV	rscratch2,#0		
		STRB	rscratch2,[reg_cpu_var,#BranchSkip_ofs]
		SUB	rscratch2,rpc,regpcbase
		@ if( CPU.PC - CPU.PCBase > OpAddress) return;
		CMP	rscratch2,rscratch
		BHI	1111f
1110:		
.endm									
.macro		BranchCheck1		
		/*in rsctach : OpAddress
		/*destroy rscratch2*/
		LDRB	rscratch2,[reg_cpu_var,#BranchSkip_ofs]
		MOVS	rscratch2,rscratch2	
		BEQ	1110f
		MOV	rscratch2,#0		
		STRB	rscratch2,[reg_cpu_var,#BranchSkip_ofs]
		SUB	rscratch2,rpc,regpcbase
		@ if( CPU.PC - CPU.PCBase > OpAddress) return;
		CMP	rscratch2,rscratch
		BHI	1111f
1110:
.endm												
.macro		BranchCheck2
		/*in rsctach : OpAddress
		/*destroy rscratch2*/
		LDRB	rscratch2,[reg_cpu_var,#BranchSkip_ofs]
		MOVS	rscratch2,rscratch2	
		BEQ	1110f
		MOV	rscratch2,#0		
		STRB	rscratch2,[reg_cpu_var,#BranchSkip_ofs]
		SUB	rscratch2,rpc,regpcbase
		@ if( CPU.PC - CPU.PCBase > OpAddress) return;
		CMP	rscratch2,rscratch
		BHI	1111f
1110:		
.endm
			
.macro		S9xSetPCBase
		@  in  : rscratch (0x00hhmmll)				
		PREPARE_C_CALL			
		BL	asm_S9xSetPCBase		
		RESTORE_C_CALL
		LDR	rpc,[reg_cpu_var,#PC_ofs]
		LDR	regpcbase,[reg_cpu_var,#PCBase_ofs]
.endm		

.macro		S9xFixCycles
		TST		rstatus,#MASK_EMUL
		LDRNE		rscratch, = jumptable1	   @ Mode 0 : M=1,X=1
		BNE		991111f
		@ EMULATION=0
		TST		rstatus,#MASK_MEM
		BEQ		991112f
		@ MEMORY=1
		TST		rstatus,#MASK_INDEX
		@ INDEX=1  @ Mode 0 : M=1,X=1
		LDRNE		rscratch, = jumptable1		
		@ INDEX=0  @ Mode 1 : M=1,X=0
		LDREQ		rscratch, = jumptable2
		B		991111f
991112:		@ MEMORY=0		
		TST		rstatus,#MASK_INDEX
		@ INDEX=1   @ Mode 3 : M=0,X=1
		LDRNE		rscratch, = jumptable4
		@ INDEX=0   @ Mode 2 : M=0,X=0
		LDREQ		rscratch, = jumptable3		
991111:
		STR		rscratch,[reg_cpu_var,#asm_OPTABLE_ofs]
.endm		
/*
.macro		S9xOpcode_NMI
		SAVE_REGS
		PREPARE_C_CALL_LIGHT
		BL	asm_S9xOpcode_NMI
		RESTORE_C_CALL_LIGHT
		LOAD_REGS		
.endm
.macro		S9xOpcode_IRQ
		SAVE_REGS
		PREPARE_C_CALL_LIGHT
		BL	asm_S9xOpcode_IRQ
		RESTORE_C_CALL_LIGHT
		LOAD_REGS		
.endm
*/
.macro		S9xDoHBlankProcessing
		SAVE_REGS
		PREPARE_C_CALL_LIGHT
@		BL	asm_S9xDoHBlankProcessing
		BL	S9xDoHBlankProcessing @ let's go straight to number one
		RESTORE_C_CALL_LIGHT
		LOAD_REGS		
.endm

/********************************/
.macro		EXEC_OP					
		LDR		R1,[reg_cpu_var,#asm_OPTABLE_ofs]
		STR		rpc,[reg_cpu_var,#PCAtOpcodeStart_ofs]
		ADD1MEM
		LDRB		R0, [rpc], #1		
		
		LDR		PC, [R1,R0, LSL #2]
.endm
.macro		NEXTOPCODE
		LDR			rscratch,[reg_cpu_var,#NextEvent_ofs]
		CMP			reg_cycles,rscratch
		BLT			mainLoop
  		S9xDoHBlankProcessing
		B			mainLoop
.endm

.macro		asmAPU_EXECUTE
		LDRB		R0,[reg_cpu_var,#APUExecuting_ofs]
		CMP 		R0,#1   @ spc700 enabled, hack mode off
		BNE		    43210f
		LDR		    R0,[reg_cpu_var,#APU_Cycles]
        SUBS	    R0,reg_cycles,R0
        BMI         43210f
.if ASM_SPC700
		PREPARE_C_CALL_LIGHTR12
		BL		spc700_execute
		RESTORE_C_CALL_LIGHTR12
        SUB     R0,reg_cycles,R0 @ sub cycles left
		STR		R0,[reg_cpu_var,#APU_Cycles]
.else
        @ SAVE_REGS
		STR		reg_cycles,[reg_cpu_var,#Cycles_ofs]
		PREPARE_C_CALL_LIGHTR12
		BL		asm_APU_EXECUTE
		RESTORE_C_CALL_LIGHTR12
		LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs]
.endif
        @ LOAD_REGS
		@ S9xFixCycles
43210:
.endm

.macro		asmAPU_EXECUTE2
.if ASM_SPC700
		LDRB		R0,[reg_cpu_var,#APUExecuting_ofs]
		CMP 		R0,#1   @ spc700 enabled, hack mode off
		BNE		    43211f
		LDR		    R0,[reg_cpu_var,#APU_Cycles]
        SUBS	    R0,reg_cycles,R0 @ reg_cycles == NextEvent
        BLE         43211f
		PREPARE_C_CALL_LIGHTR12
		BL		spc700_execute
		RESTORE_C_CALL_LIGHTR12
        SUB     R0,reg_cycles,R0 @ sub cycles left
		STR		R0,[reg_cpu_var,#APU_Cycles]
43211:
.else
		@ SAVE_REGS		
		STR		reg_cycles,[reg_cpu_var,#Cycles_ofs]
		PREPARE_C_CALL_LIGHTR12
		BL		asm_APU_EXECUTE2
		RESTORE_C_CALL_LIGHTR12
		LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs]		
		@ LOAD_REGS
.endif
.endm

@ #include "os9x_65c816_mac_mem.h"
.macro		S9xGetWord	
		@  in  : rscratch (0x00hhmmll)
		@  out : rscratch (0xhhll0000)
		STMFD	R13!,{PC} @ Push return address
		B	asmS9xGetWord
		MOV	R0, R0, LSL #16
.endm
.macro		S9xGetWordLow	
		@  in  : rscratch (0x00hhmmll)
		@  out : rscratch (0x0000hhll)		
		STMFD	R13!,{PC} @ Push return address
		B	asmS9xGetWord
.endm
.macro		S9xGetWordRegStatus	reg
		@  in  : rscratch (0x00hhmmll) 
		@  out : reg      (0xhhll0000)
		@  flags have to be updated with read value
		STMFD	R13!,{PC} @ Push return address
		B	asmS9xGetWord
		MOVS	\reg, R0, LSL #16
.endm
.macro		S9xGetWordRegNS	reg
		@  in  : rscratch (0x00hhmmll) 
		@  out : reg (0xhhll0000)
		@  DOES NOT DESTROY rscratch (R0)
		STMFD	R13!,{R0}
		STMFD	R13!,{PC} @ Push return address
		B	asmS9xGetWord
		MOV	\reg, R0, LSL #16
		LDMFD	R13!,{R0}
.endm			
.macro		S9xGetWordLowRegNS	reg
		@  in  : rscratch (0x00hhmmll) 
		@  out : reg (0xhhll0000)
		@  DOES NOT DESTROY rscratch (R0)
		STMFD	R13!,{R0}
		STMFD	R13!,{PC} @ Push return address
		B	asmS9xGetWord
		MOV	\reg, R0
		LDMFD	R13!,{R0}
.endm			

.macro		S9xGetByte 	
		@  in  : rscratch (0x00hhmmll)
		@  out : rscratch (0xll000000)
		STMFD	R13!,{PC} @ Push return address
		B	asmS9xGetByte
		MOV	R0, R0, LSL #24
.endm
.macro		S9xGetByteLow
		@  in  : rscratch (0x00hhmmll) 
		@  out : rscratch (0x000000ll)		
		STMFD	R13!,{PC}		
		B	asmS9xGetByte
.endm
.macro		S9xGetByteRegStatus	reg
		@  in  : rscratch (0x00hhmmll)
		@  out : reg      (0xll000000)
		@  flags have to be updated with read value
		STMFD	R13!,{PC} @ Push return address
		B	asmS9xGetByte
		MOVS	\reg, R0, LSL #24
.endm
.macro		S9xGetByteRegNS	reg
		@  in  : rscratch (0x00hhmmll) 
		@  out : reg      (0xll000000)
		@  DOES NOT DESTROY rscratch (R0)
		STMFD	R13!,{R0}
		STMFD	R13!,{PC} @ Push return address
		B	asmS9xGetByte
		MOVS	\reg, R0, LSL #24
		LDMFD	R13!,{R0}
.endm
.macro		S9xGetByteLowRegNS	reg
		@  in  : rscratch (0x00hhmmll) 
		@  out : reg      (0x000000ll)
		@  DOES NOT DESTROY rscratch (R0)
		STMFD	R13!,{R0}
		STMFD	R13!,{PC} @ Push return address
		B	asmS9xGetByte
		MOVS	\reg, R0
		LDMFD	R13!,{R0}
.endm

.macro		S9xSetWord	regValue		
		@  in  : regValue  (0xhhll0000)
		@  in  : rscratch=address   (0x00hhmmll)
		MOV	R1,\regValue, LSR #16
		STMFD	R13!,{PC} @ Push return address
		B	asmS9xSetWord
.endm
.macro		S9xSetWordZero	
		@  in  : rscratch=address   (0x00hhmmll)
		MOV	R1,#0
		STMFD	R13!,{PC} @ Push return address
		B	asmS9xSetWord
.endm
.macro		S9xSetWordLow	regValue		
		@  in  : regValue  (0x0000hhll)
		@  in  : rscratch=address   (0x00hhmmll)
		MOV	R1,\regValue
		STMFD	R13!,{PC} @ Push return address
		B	asmS9xSetWord
.endm
.macro		S9xSetByte	regValue
		@  in  : regValue  (0xll000000)
		@  in  : rscratch=address   (0x00hhmmll)
		MOV	R1,\regValue, LSR #24
		STMFD	R13!,{PC} @ Push return address
		B	asmS9xSetByte
.endm
.macro		S9xSetByteZero			
		@  in  : rscratch=address   (0x00hhmmll)
		MOV	R1,#0
		STMFD	R13!,{PC} @ Push return address
		B	asmS9xSetByte
.endm
.macro		S9xSetByteLow	regValue
		@  in  : regValue  (0x000000ll)
		@  in  : rscratch=address   (0x00hhmmll)
		MOV	R1,\regValue
		STMFD	R13!,{PC} @ Push return address
		B	asmS9xSetByte
.endm


@  ===========================================
@  ===========================================
@  Adressing mode
@  ===========================================
@  ===========================================


.macro		Absolute		
		ADD2MEM		
		LDRB	rscratch2    , [rpc, #1]
		LDRB	rscratch   , [rpc],#2
		ORR	rscratch    , rscratch,	rscratch2, LSL #8
		ORR	rscratch    , rscratch,	reg_d_bank, LSL #16
.endm
.macro		AbsoluteIndexedIndirectX0
		ADD2MEM		
		LDRB	rscratch2    , [rpc, #1]
		LDRB	rscratch   , [rpc], #2
		ORR	rscratch    , rscratch,	rscratch2, LSL #8
		ADD	rscratch    , reg_x, rscratch, LSL #16
		MOV	rscratch , rscratch, LSR #16
		ORR	rscratch    , rscratch,	reg_p_bank, LSL #16
		S9xGetWordLow
		
.endm
.macro		AbsoluteIndexedIndirectX1
		ADD2MEM		
		LDRB	rscratch2    , [rpc, #1]
		LDRB	rscratch   , [rpc], #2
		ORR	rscratch    , rscratch,	rscratch2, LSL #8
		ADD	rscratch    , rscratch, reg_x, LSR #24
		BIC	rscratch , rscratch, #0x00FF0000
		ORR	rscratch    , rscratch,	reg_p_bank, LSL #16
		S9xGetWordLow
		
.endm
.macro		AbsoluteIndirectLong		
		ADD2MEM
		LDRB			rscratch2    , [rpc, #1]
		LDRB			rscratch   , [rpc], #2
		ORR			rscratch    , rscratch,	rscratch2, LSL #8
		S9xGetWordLowRegNS 	rscratch2
		ADD			rscratch   , rscratch,	#2
		STMFD			r13!,{rscratch2}
		S9xGetByteLow
		LDMFD			r13!,{rscratch2}
		ORR			rscratch   , rscratch2, rscratch, LSL #16
.endm
.macro		AbsoluteIndirect
		ADD2MEM
		LDRB	rscratch2    , [rpc,#1]
		LDRB	rscratch   , [rpc], #2
		ORR	rscratch    , rscratch,	rscratch2, LSL #8
		S9xGetWordLow
		ORR	rscratch    , rscratch,	reg_p_bank, LSL #16
.endm
.macro		AbsoluteIndexedX0		
		ADD2MEM
		LDRB	rscratch2    , [rpc, #1]
		LDRB	rscratch   , [rpc], #2
		ORR	rscratch    , rscratch,	rscratch2, LSL #8
		ORR	rscratch    , rscratch,	reg_d_bank, LSL #16
		ADD	rscratch    , rscratch,	reg_x, LSR #16
.endm
.macro		AbsoluteIndexedX1
		ADD2MEM
		LDRB	rscratch2    , [rpc, #1]
		LDRB	rscratch   , [rpc], #2
		ORR	rscratch    , rscratch,	rscratch2, LSL #8
		ORR	rscratch    , rscratch,	reg_d_bank, LSL #16
		ADD	rscratch    , rscratch,	reg_x, LSR #24
.endm


.macro		AbsoluteIndexedY0
		ADD2MEM
		LDRB	rscratch2    , [rpc, #1]
		LDRB	rscratch   , [rpc], #2
		ORR	rscratch    , rscratch,	rscratch2, LSL #8
		ORR	rscratch    , rscratch,	reg_d_bank, LSL #16
		ADD	rscratch    , rscratch,	reg_y, LSR #16
.endm
.macro		AbsoluteIndexedY1
		ADD2MEM
		LDRB	rscratch2    , [rpc, #1]
		LDRB	rscratch   , [rpc], #2
		ORR	rscratch    , rscratch,	rscratch2, LSL #8
		ORR	rscratch    , rscratch,	reg_d_bank, LSL #16
		ADD	rscratch    , rscratch,	reg_y, LSR #24
.endm
.macro		AbsoluteLong
		ADD3MEM
		LDRB	rscratch2    , [rpc, #1]
		LDRB	rscratch   , [rpc], #2
		ORR	rscratch    , rscratch,	rscratch2, LSL #8
		LDRB	rscratch2   , [rpc], #1
		ORR	rscratch    , rscratch,	rscratch2, LSL #16
.endm


.macro		AbsoluteLongIndexedX0
		ADD3MEM
		LDRB	rscratch2    , [rpc, #1]
		LDRB	rscratch   , [rpc], #2
		ORR	rscratch    , rscratch,	rscratch2, LSL #8
		LDRB	rscratch2   , [rpc], #1
		ORR	rscratch    , rscratch,	rscratch2, LSL #16
		ADD	rscratch    , rscratch,	reg_x, LSR #16
		BIC	rscratch, rscratch, #0xFF000000
.endm
.macro		AbsoluteLongIndexedX1
		ADD3MEM
		LDRB	rscratch2    , [rpc, #1]
		LDRB	rscratch   , [rpc], #2
		ORR	rscratch    , rscratch,	rscratch2, LSL #8
		LDRB	rscratch2   , [rpc], #1
		ORR	rscratch    , rscratch,	rscratch2, LSL #16
		ADD	rscratch    , rscratch,	reg_x, LSR #24
		BIC	rscratch, rscratch, #0xFF000000		
.endm
.macro		Direct
		ADD1MEM
		LDRB	rscratch    , [rpc], #1
		ADD	rscratch    , reg_d, rscratch, LSL #16
		MOV	rscratch, rscratch, LSR #16
.endm
.macro		DirectIndirect
		ADD1MEM
		LDRB	rscratch    , [rpc], #1
		ADD	rscratch    , reg_d, rscratch,	 LSL #16		
		MOV	rscratch, rscratch, LSR #16
		S9xGetWordLow
		ORR	rscratch    , rscratch,	reg_d_bank, LSL #16
.endm
.macro		DirectIndirectLong
		ADD1MEM
		LDRB			rscratch    , [rpc], #1
		ADD			rscratch    , reg_d, rscratch,	 LSL #16
		MOV			rscratch, rscratch, LSR #16		
		S9xGetWordLowRegNS	rscratch2
		ADD			rscratch    , rscratch,#2
		STMFD			r13!,{rscratch2}
		S9xGetByteLow
		LDMFD			r13!,{rscratch2}
		ORR			rscratch   , rscratch2, rscratch, LSL #16
.endm
.macro		DirectIndirectIndexed0
		ADD1MEM
		LDRB	rscratch    , [rpc], #1
		ADD	rscratch    , reg_d, rscratch,	 LSL #16
		MOV	rscratch, rscratch, LSR #16
		S9xGetWordLow
		ORR	rscratch, rscratch,reg_d_bank, LSL #16
		ADD	rscratch, rscratch,reg_y, LSR #16
.endm
.macro		DirectIndirectIndexed1
		ADD1MEM
		LDRB	rscratch    , [rpc], #1
		ADD	rscratch    , reg_d, rscratch,	 LSL #16
		MOV	rscratch, rscratch, LSR #16
		S9xGetWordLow
		ORR	rscratch, rscratch,reg_d_bank, LSL #16
		ADD	rscratch, rscratch,reg_y, LSR #24
.endm
.macro		DirectIndirectIndexedLong0
		ADD1MEM
		LDRB			rscratch    , [rpc], #1
		ADD			rscratch    , reg_d, rscratch,	 LSL #16
		MOV			rscratch, rscratch, LSR #16		
		S9xGetWordLowRegNS	rscratch2
		ADD			rscratch    , rscratch,#2
		STMFD			r13!,{rscratch2}
		S9xGetByteLow
		LDMFD			r13!,{rscratch2}
		ORR			rscratch   , rscratch2, rscratch, LSL #16				
		ADD			rscratch, rscratch,reg_y, LSR #16
.endm
.macro		DirectIndirectIndexedLong1
		ADD1MEM
		LDRB			rscratch    , [rpc], #1
		ADD			rscratch    , reg_d, rscratch,	 LSL #16
		MOV			rscratch, rscratch, LSR #16
		S9xGetWordLowRegNS	rscratch2
		ADD			rscratch    , rscratch,#2
		STMFD			r13!,{rscratch2}
		S9xGetByteLow
		LDMFD			r13!,{rscratch2}
		ORR			rscratch   , rscratch2, rscratch, LSL #16
		ADD			rscratch, rscratch,reg_y, LSR #24
.endm
.macro		DirectIndexedIndirect0
		ADD1CYCLE1MEM
		LDRB	rscratch    , [rpc], #1				
		ADD	rscratch2   , reg_d , reg_x
		ADD	rscratch    , rscratch2 , rscratch, LSL #16		
		MOV	rscratch, rscratch, LSR #16
		S9xGetWordLow
		ORR	rscratch    , rscratch , reg_d_bank, LSL #16		
.endm
.macro		DirectIndexedIndirect1
		ADD1CYCLE1MEM
		LDRB	rscratch    , [rpc], #1
		ADD	rscratch2   , reg_d , reg_x, LSR #8
		ADD	rscratch    , rscratch2 , rscratch, LSL #16
		MOV	rscratch, rscratch, LSR #16
		S9xGetWordLow
		ORR	rscratch    , rscratch , reg_d_bank, LSL #16		
.endm
.macro		DirectIndexedX0
		ADD1CYCLE1MEM
		LDRB	rscratch    , [rpc], #1
		ADD	rscratch2   , reg_d , reg_x
		ADD	rscratch    , rscratch2 , rscratch, LSL #16
		MOV	rscratch, rscratch, LSR #16
.endm
.macro		DirectIndexedX1
		ADD1CYCLE1MEM
		LDRB	rscratch    , [rpc], #1
		ADD	rscratch2   , reg_d , reg_x, LSR #8
		ADD	rscratch    , rscratch2 , rscratch, LSL #16
		MOV	rscratch, rscratch, LSR #16
.endm
.macro		DirectIndexedY0
		ADD1CYCLE1MEM
		LDRB	rscratch    , [rpc], #1
		ADD	rscratch2   , reg_d , reg_y
		ADD	rscratch    , rscratch2 , rscratch, LSL #16
		MOV	rscratch, rscratch, LSR #16
.endm
.macro		DirectIndexedY1
		ADD1CYCLE1MEM
		LDRB	rscratch    , [rpc], #1
		ADD	rscratch2   , reg_d , reg_y, LSR #8
		ADD	rscratch    , rscratch2 , rscratch, LSL #16
		MOV	rscratch, rscratch, LSR #16
.endm
.macro		Immediate8
		ADD	rscratch, rpc, reg_p_bank, LSL #16
		SUB	rscratch, rscratch, regpcbase
		ADD	rpc, rpc, #1
.endm
.macro		Immediate16
		ADD	rscratch, rpc, reg_p_bank, LSL #16
		SUB	rscratch, rscratch, regpcbase
		ADD	rpc, rpc, #2
.endm
.macro		asmRelative
		ADD1MEM
		LDRSB	rscratch    , [rpc],#1
		ADD	rscratch , rscratch , rpc
		SUB	rscratch , rscratch, regpcbase		
		BIC	rscratch,rscratch,#0x00FF0000
		BIC	rscratch,rscratch,#0xFF000000
.endm
.macro		asmRelativeLong
		ADD1CYCLE2MEM
		LDRB	rscratch2    , [rpc, #1]
		LDRB	rscratch   , [rpc], #2
		ORR	rscratch    , rscratch,	rscratch2, LSL #8
		SUB	rscratch2    , rpc, regpcbase
		ADD	rscratch    , rscratch2, rscratch		
		BIC	rscratch,rscratch,#0x00FF0000
.endm


.macro		StackasmRelative
		ADD1CYCLE1MEM
		LDRB	rscratch    , [rpc], #1
		ADD	rscratch    , rscratch,	reg_s
		BIC	rscratch,rscratch,#0x00FF0000
.endm
.macro		StackasmRelativeIndirectIndexed0
		ADD2CYCLE1MEM
		LDRB	rscratch    , [rpc], #1
		ADD	rscratch    , rscratch,	reg_s
		BIC	rscratch,rscratch,#0x00FF0000
		S9xGetWordLow
		ORR	rscratch    , rscratch,	reg_d_bank, LSL #16
		ADD	rscratch    , rscratch,	reg_y, LSR #16
		BIC	rscratch, rscratch, #0xFF000000
.endm
.macro		StackasmRelativeIndirectIndexed1
		ADD2CYCLE1MEM
		LDRB	rscratch    , [rpc], #1
		ADD	rscratch    , rscratch,	reg_s
		BIC	rscratch,rscratch,#0x00FF0000
		S9xGetWordLow
		ORR	rscratch    , rscratch,	reg_d_bank, LSL #16
		ADD	rscratch    , rscratch,	reg_y, LSR #24
		BIC	rscratch, rscratch, #0xFF000000
.endm


/****************************************/
.macro		PushB		reg
		MOV		rscratch,reg_s
		S9xSetByte	\reg
		SUB		reg_s,reg_s,#1
.endm			
.macro		PushBLow	reg
		MOV		rscratch,reg_s
		S9xSetByteLow	\reg
		SUB		reg_s,reg_s,#1
.endm
.macro		PushWLow	reg 
		SUB		rscratch,reg_s,#1
		S9xSetWordLow	\reg
		SUB		reg_s,reg_s,#2
.endm			
.macro		PushWrLow	
		MOV		rscratch2,rscratch
		SUB		rscratch,reg_s,#1
		S9xSetWordLow	rscratch2
		SUB		reg_s,reg_s,#2
.endm			
.macro		PushW		reg
		SUB		rscratch,reg_s,#1
		S9xSetWord	\reg
		SUB		reg_s,reg_s,#2
.endm

/********/

.macro		PullB		reg
		ADD		rscratch,reg_s,#1
		S9xGetByteLow
		ADD		reg_s,reg_s,#1
		MOV		\reg,rscratch,LSL #24
.endm
.macro		PullBr		
		ADD		rscratch,reg_s,#1
		S9xGetByte
		ADD		reg_s,reg_s,#1		
.endm
.macro		PullBLow	reg
		ADD		rscratch,reg_s,#1
		S9xGetByteLow
		ADD		reg_s,reg_s,#1
		MOV		\reg,rscratch
.endm
.macro		PullBrLow
		ADD		rscratch,reg_s,#1
		S9xGetByteLow
		ADD		reg_s,reg_s,#1		
.endm
.macro		PullW		reg
		ADD		rscratch,reg_s,#1
		S9xGetWordLow
		ADD		reg_s,reg_s,#2
		MOV		\reg,rscratch,LSL #16
.endm

.macro		PullWLow	reg
		ADD		rscratch,reg_s,#1
		S9xGetWordLow	
		ADD		reg_s,reg_s,#2
		MOV		\reg,rscratch
.endm


/*****************/
.macro		PullBS		reg
		ADD		rscratch,reg_s,#1
		S9xGetByteLow
		ADD		reg_s,reg_s,#1
		MOVS		\reg,rscratch,LSL #24
.endm
.macro		PullBrS	
		ADD		rscratch,reg_s,#1
		S9xGetByteLow
		ADD		reg_s,reg_s,#1
		MOVS		rscratch,rscratch,LSL #24
.endm
.macro		PullBLowS	reg
		ADD		rscratch,reg_s,#1
		S9xGetByteLow
		ADD		reg_s,reg_s,#1
		MOVS		\reg,rscratch
.endm
.macro		PullBrLowS	
		ADD		rscratch,reg_s,#1
		S9xGetByteLow
		ADD		reg_s,reg_s,#1
		MOVS		rscratch,rscratch
.endm
.macro		PullWS		reg
		ADD		rscratch,reg_s,#1
		S9xGetWordLow
		ADD		reg_s,reg_s,#2
		MOVS		\reg,rscratch, LSL #16
.endm
.macro		PullWrS		
		ADD		rscratch,reg_s,#1
		S9xGetWordLow
		ADD		reg_s,reg_s,#2
		MOVS		rscratch,rscratch, LSL #16
.endm
.macro		PullWLowS	reg
		ADD		rscratch,reg_s,#1
		S9xGetWordLow
		ADD		reg_s,reg_s,#2
		MOVS		\reg,rscratch
.endm
.macro		PullWrLowS	
		ADD		rscratch,reg_s,#1
		S9xGetWordLow
		ADD		reg_s,reg_s,#2
		MOVS		rscratch,rscratch
.endm


.globl asmS9xGetByte
.globl asmS9xGetWord
.globl asmS9xSetByte
.globl asmS9xSetWord

@ uint8 aaS9xGetByte(uint32 address);
asmS9xGetByte:
	@  in : R0  = 0x00hhmmll
	@  out : R0 = 0x000000ll
	@  DESTROYED : R1,R2,R3
	@  UPDATE : reg_cycles
	@ R1 <= block	
	MOV		R1,R0,LSR #MEMMAP_SHIFT
	@ MEMMAP_SHIFT is 12, Address is 0xFFFFFFFF at max, so
	@ R1 is maxed by 0x000FFFFF, MEMMAP_MASK is 0x1000-1=0xFFF
	@ so AND MEMMAP_MASK is BIC 0xFF000
	BIC		R1,R1,#0xFF000
	@ R2 <= Map[block] (GetAddress)
	LDR		R2,[reg_cpu_var,#Map_ofs]
	LDR		R2,[R2,R1,LSL #2]
	CMP		R2,#MAP_LAST
	BLO		GBSpecial  @ special
	@  Direct ROM/RAM acess
	@ R2 <= GetAddress + Address & 0xFFFF	
	@ R3 <= MemorySpeed[block]			
	LDR		R3,[reg_cpu_var,#MemorySpeed_ofs]
	MOV		R0,R0,LSL #16		
	LDRB		R3,[R3,R1]
	ADD		R2,R2,R0,LSR #16
	@ Update CPU.Cycles
	ADD		reg_cycles,reg_cycles,R3	
	@ R3 = BlockIsRAM[block]
	LDR		R3,[reg_cpu_var,#BlockIsRAM_ofs]
	@ Get value to return
	LDRB		R0,[R2]
	LDRB		R3,[R3,R1]
	MOVS		R3,R3
	@  if BlockIsRAM => update for CPUShutdown
	LDRNE		R1,[reg_cpu_var,#PCAtOpcodeStart_ofs]
	STRNE		R1,[reg_cpu_var,#WaitAddress_ofs]
	
	LDMFD		R13!,{PC} @ Return
GBSpecial:
	
	LDR		PC,[PC,R2,LSL #2]
	MOV		R0,R0 		@ nop, for align
	.long GBPPU
	.long GBCPU
	.long GBDSP
	.long GBLSRAM
	.long GBHSRAM
	.long GBNONE
	.long GBDEBUG
	.long GBC4
	.long GBBWRAM
	.long GBNONE
	.long GBNONE
	.long GBNONE
	/*.long GB7ROM
	.long GB7RAM
	.long GB7SRM*/
GBPPU:
	@ InDMA ?
	LDRB		R1,[reg_cpu_var,#InDMA_ofs]
	MOVS		R1,R1	
	ADDEQ		reg_cycles,reg_cycles,#ONE_CYCLE		@ No -> update Cycles
	MOV		R0,R0,LSL #16	@ S9xGetPPU(Address&0xFFFF);
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs]	@ Save Cycles
	MOV		R0,R0,LSR #16	
		PREPARE_C_CALL
	BL		S9xGetPPU
		RESTORE_C_CALL
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles	
	LDMFD		R13!,{PC} @ Return
GBCPU:	
	ADD		reg_cycles,reg_cycles,#ONE_CYCLE	@ update Cycles	
	MOV		R0,R0,LSL #16 @ S9xGetCPU(Address&0xFFFF);	
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Save Cycles
	MOV		R0,R0,LSR #16
		PREPARE_C_CALL
	BL		S9xGetCPU
		RESTORE_C_CALL
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles	
	LDMFD		R13!,{PC} @ Return
GBDSP:
	ADD		reg_cycles,reg_cycles,#SLOW_ONE_CYCLE	@ update Cycles	
	MOV		R0,R0,LSL #16 @ S9xGetCPU(Address&0xFFFF);	
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Save Cycles
	MOV		R0,R0,LSR #16
		PREPARE_C_CALL
	BL		S9xGetDSP		
		RESTORE_C_CALL
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles	
	LDMFD		R13!,{PC} @ Return
GBLSRAM:
	ADD		reg_cycles,reg_cycles,#SLOW_ONE_CYCLE	@ update Cycles		
	LDRH		R2,[reg_cpu_var,#SRAMMask]
	LDR		R1,[reg_cpu_var,#SRAM]	
	AND		R0,R2,R0		@ Address&SRAMMask
	LDRB		R0,[R1,R0]		@ *Memory.SRAM + Address&SRAMMask
	LDMFD		R13!,{PC}
GB7SRM:	
GBHSRAM:
	ADD		reg_cycles,reg_cycles,#SLOW_ONE_CYCLE	@ update Cycles		
	
	MOV		R1,R0,LSL #17  
	AND		R2,R0,#0xF0000
	MOV		R1,R1,LSR #17	@ Address&0x7FFF	
	MOV		R2,R2,LSR #3 @ (Address&0xF0000 >> 3)
	ADD		R0,R2,R1
	LDRH		R2,[reg_cpu_var,#SRAMMask]
	SUB		R0,R0,#0x6000 @ ((Address & 0x7fff) - 0x6000 + ((Address & 0xf0000) >> 3))
	LDR		R1,[reg_cpu_var,#SRAM]	
	AND		R0,R2,R0		@ Address&SRAMMask	
	LDRB		R0,[R1,R0]		@ *Memory.SRAM + Address&SRAMMask
	LDMFD		R13!,{PC}		@ return
GB7ROM:
GB7RAM:	
GBNONE:
	MOV		R0,R0,LSR #8
	ADD		reg_cycles,reg_cycles,#SLOW_ONE_CYCLE	@ update Cycles
	AND		R0,R0,#0xFF
	LDMFD		R13!,{PC}
@ GBDEBUG:
	/*ADD		reg_cycles,reg_cycles,#SLOW_ONE_CYCLE	@ update Cycles
	MOV		R0,#0
	LDMFD		R13!,{PC}*/
GBC4:
	ADD		reg_cycles,reg_cycles,#SLOW_ONE_CYCLE	@ update Cycles	
	MOV		R0,R0,LSL #16 @ S9xGetC4(Address&0xFFFF);	
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Save Cycles
	MOV		R0,R0,LSR #16
		PREPARE_C_CALL
	BL		S9xGetC4
		RESTORE_C_CALL
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles		
	LDMFD		R13!,{PC} @ Return
GBDEBUG:	
GBBWRAM:
	MOV		R0,R0,LSL #17  
	ADD		reg_cycles,reg_cycles,#SLOW_ONE_CYCLE	@ update Cycles	
	MOV		R0,R0,LSR #17	@ Address&0x7FFF			
	LDR		R1,[reg_cpu_var,#BWRAM]	
	SUB		R0,R0,#0x6000   @ ((Address & 0x7fff) - 0x6000)	
	LDRB		R0,[R0,R1]		@ *Memory.BWRAM + ((Address & 0x7fff) - 0x6000)	
	LDMFD		R13!,{PC}


@ uint16 aaS9xGetWord(uint32 address);
asmS9xGetWord:
	@  in : R0  = 0x00hhmmll
	@  out : R0 = 0x000000ll
	@  DESTROYED : R1,R2,R3
	@  UPDATE : reg_cycles
	
	
	MOV		R1,R0,LSL #19	
	ADDS		R1,R1,#0x80000
	@ if = 0x1FFF => 0
	BNE		GW_NotBoundary
	
	STMFD		R13!,{R0}
		STMFD		R13!,{PC}
	B		asmS9xGetByte
	LDMFD		R13!,{R1}
	STMFD		R13!,{R0}
	ADD		R0,R1,#1
		STMFD		R13!,{PC}
	B		asmS9xGetByte
	LDMFD		R13!,{R1}
	ORR		R0,R1,R0,LSL #8
	LDMFD		R13!,{PC}
	
GW_NotBoundary:	
	
	@ R1 <= block	
	MOV		R1,R0,LSR #MEMMAP_SHIFT
	@ MEMMAP_SHIFT is 12, Address is 0xFFFFFFFF at max, so
	@ R1 is maxed by 0x000FFFFF, MEMMAP_MASK is 0x1000-1=0xFFF
	@ so AND MEMMAP_MASK is BIC 0xFF000
	BIC		R1,R1,#0xFF000
	@ R2 <= Map[block] (GetAddress)
	LDR		R2,[reg_cpu_var,#Map_ofs]
	LDR		R2,[R2,R1,LSL #2]
	CMP		R2,#MAP_LAST
	BLO		GWSpecial  @ special
	@  Direct ROM/RAM acess
	
	TST		R0,#1	
	BNE		GW_Not_Aligned1
	@ R2 <= GetAddress + Address & 0xFFFF	
	@ R3 <= MemorySpeed[block]			
	LDR		R3,[reg_cpu_var,#MemorySpeed_ofs]
	MOV		R0,R0,LSL #16
	LDRB		R3,[R3,R1]	
	MOV		R0,R0,LSR #16
	@ Update CPU.Cycles
	ADD		reg_cycles,reg_cycles,R3, LSL #1
	@ R3 = BlockIsRAM[block]
	LDR		R3,[reg_cpu_var,#BlockIsRAM_ofs]
	@ Get value to return
	LDRH		R0,[R2,R0]
	LDRB		R3,[R3,R1]
	MOVS		R3,R3
	@  if BlockIsRAM => update for CPUShutdown
	LDRNE		R1,[reg_cpu_var,#PCAtOpcodeStart_ofs]
	STRNE		R1,[reg_cpu_var,#WaitAddress_ofs]
	
	LDMFD		R13!,{PC} @ Return
GW_Not_Aligned1:			

	MOV		R0,R0,LSL #16		
	ADD		R3,R0,#0x10000
	LDRB		R3,[R2,R3,LSR #16]	@ GetAddress+ (Address+1)&0xFFFF
	LDRB		R0,[R2,R0,LSR #16]	@ GetAddress+ Address&0xFFFF	
	ORR		R0,R0,R3,LSL #8	

	@  if BlockIsRAM => update for CPUShutdown
	LDR		R3,[reg_cpu_var,#BlockIsRAM_ofs]	
	LDR		R2,[reg_cpu_var,#MemorySpeed_ofs]
	LDRB		R3,[R3,R1]   @ R3 = BlockIsRAM[block]
	LDRB		R2,[R2,R1]   @ R2 <= MemorySpeed[block]
	MOVS		R3,R3 	    @ IsRAM ? CPUShutdown stuff
	LDRNE		R1,[reg_cpu_var,#PCAtOpcodeStart_ofs]	
	STRNE		R1,[reg_cpu_var,#WaitAddress_ofs]			
	ADD		reg_cycles,reg_cycles,R2, LSL #1 @ Update CPU.Cycles				
	LDMFD		R13!,{PC}  @ Return
GWSpecial:
	LDR		PC,[PC,R2,LSL #2]
	MOV		R0,R0 		@ nop, for align
	.long GWPPU
	.long GWCPU
	.long GWDSP
	.long GWLSRAM
	.long GWHSRAM
	.long GWNONE
	.long GWDEBUG
	.long GWC4
	.long GWBWRAM
	.long GWNONE
	.long GWNONE
	.long GWNONE
	/*.long GW7ROM
	.long GW7RAM
	.long GW7SRM*/
/*	MAP_PPU, MAP_CPU, MAP_DSP, MAP_LOROM_SRAM, MAP_HIROM_SRAM,
	MAP_NONE, MAP_DEBUG, MAP_C4, MAP_BWRAM, MAP_BWRAM_BITMAP,
	MAP_BWRAM_BITMAP2, MAP_SA1RAM, MAP_LAST*/
	
GWPPU:
	@ InDMA ?
	LDRB		R1,[reg_cpu_var,#InDMA_ofs]
	MOVS		R1,R1	
	ADDEQ		reg_cycles,reg_cycles,#(ONE_CYCLE*2)		@ No -> update Cycles
	MOV		R0,R0,LSL #16	@ S9xGetPPU(Address&0xFFFF);
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs]	@ Save Cycles
	MOV		R0,R0,LSR #16
		PREPARE_C_CALL_R0
	BL		S9xGetPPU
	LDMFD		R13!,{R1}
	STMFD		R13!,{R0}
	ADD		R0,R1,#1
	@ BIC		R0,R0,#0x10000
	BL		S9xGetPPU
		RESTORE_C_CALL_R1
	ORR		R0,R1,R0,LSL #8
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles	
	LDMFD		R13!,{PC} @ Return
GWCPU:	
	ADD		reg_cycles,reg_cycles,#(ONE_CYCLE*2)	@ update Cycles	
	MOV		R0,R0,LSL #16 @ S9xGetCPU(Address&0xFFFF);	
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Save Cycles
	MOV		R0,R0,LSR #16
		PREPARE_C_CALL_R0
	BL		S9xGetCPU
	LDMFD		R13!,{R1}
	STMFD		R13!,{R0}
	ADD		R0,R1,#1
	@ BIC		R0,R0,#0x10000
	BL		S9xGetCPU			
		RESTORE_C_CALL_R1
	ORR		R0,R1,R0,LSL #8
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles	
	LDMFD		R13!,{PC} @ Return
GWDSP:
	ADD		reg_cycles,reg_cycles,#(SLOW_ONE_CYCLE*2)	@ update Cycles	
	MOV		R0,R0,LSL #16 @ S9xGetCPU(Address&0xFFFF);	
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Save Cycles
	MOV		R0,R0,LSR #16
		PREPARE_C_CALL_R0
	BL		S9xGetDSP
	LDMFD		R13!,{R1}
	STMFD		R13!,{R0}
	ADD		R0,R1,#1
	@ BIC		R0,R0,#0x10000
	BL		S9xGetDSP	
		RESTORE_C_CALL_R1
	ORR		R0,R1,R0,LSL #8
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles	
	LDMFD		R13!,{PC} @ Return
GWLSRAM:
	ADD		reg_cycles,reg_cycles,#(SLOW_ONE_CYCLE*2)	@ update Cycles		
	
	TST		R0,#1
	BNE		GW_Not_Aligned2
	LDRH		R2,[reg_cpu_var,#SRAMMask]
	LDR		R1,[reg_cpu_var,#SRAM]
	AND		R3,R2,R0		@ Address&SRAMMask
	LDRH		R0,[R3,R1]		@ *Memory.SRAM + Address&SRAMMask		
	LDMFD		R13!,{PC}	@ return
GW_Not_Aligned2:	
	LDRH		R2,[reg_cpu_var,#SRAMMask]
	LDR		R1,[reg_cpu_var,#SRAM]	
	AND		R3,R2,R0		@ Address&SRAMMask
	ADD		R0,R0,#1
	AND		R2,R0,R2		@ Address&SRAMMask
	LDRB		R3,[R1,R3]		@ *Memory.SRAM + Address&SRAMMask
	LDRB		R2,[R1,R2]		@ *Memory.SRAM + Address&SRAMMask
	ORR		R0,R3,R2,LSL #8
	LDMFD		R13!,{PC}	@ return
GW7SRM:	
GWHSRAM:
	ADD		reg_cycles,reg_cycles,#(SLOW_ONE_CYCLE*2)	@ update Cycles		
	
	TST		R0,#1
	BNE		GW_Not_Aligned3
	
	MOV		R1,R0,LSL #17  
	AND		R2,R0,#0xF0000
	MOV		R1,R1,LSR #17	@ Address&0x7FFF	
	MOV		R2,R2,LSR #3 @ (Address&0xF0000 >> 3)
	ADD		R0,R2,R1
	LDRH		R2,[reg_cpu_var,#SRAMMask]
	SUB		R0,R0,#0x6000 @ ((Address & 0x7fff) - 0x6000 + ((Address & 0xf0000) >> 3))
	LDR		R1,[reg_cpu_var,#SRAM]	
	AND		R0,R2,R0		@ Address&SRAMMask	
	LDRH		R0,[R1,R0]		@ *Memory.SRAM + Address&SRAMMask
	LDMFD		R13!,{PC}		@ return
	
GW_Not_Aligned3:	
	MOV		R3,R0,LSL #17  
	AND		R2,R0,#0xF0000
	MOV		R3,R3,LSR #17	@ Address&0x7FFF	
	MOV		R2,R2,LSR #3 @ (Address&0xF0000 >> 3)	
	ADD		R2,R2,R3						
	ADD		R0,R0,#1	
	SUB		R2,R2,#0x6000 @ ((Address & 0x7fff) - 0x6000 + ((Address & 0xf0000) >> 3))
	MOV		R3,R0,LSL #17  
	AND		R0,R0,#0xF0000
	MOV		R3,R3,LSR #17	@ (Address+1)&0x7FFF	
	MOV		R0,R0,LSR #3 @ ((Address+1)&0xF0000 >> 3)	
	ADD		R0,R0,R3	
	LDRH		R3,[reg_cpu_var,#SRAMMask]	@ reload mask	
	SUB		R0,R0,#0x6000 @ (((Address+1) & 0x7fff) - 0x6000 + (((Address+1) & 0xf0000) >> 3))		
	AND		R2,R3,R2		@ Address...&SRAMMask	
	AND		R0,R3,R0		@ (Address+1...)&SRAMMask	

	LDR		R3,[reg_cpu_var,#SRAM]
	LDRB		R0,[R0,R3]		@ *Memory.SRAM + (Address...)&SRAMMask	
	LDRB		R2,[R2,R3]		@ *Memory.SRAM + (Address+1...)&SRAMMask
	ORR		R0,R2,R0,LSL #8
			
	LDMFD		R13!,{PC}		@ return
GW7ROM:
GW7RAM:	
GWNONE:		
	MOV		R0,R0,LSL #16
	ADD		reg_cycles,reg_cycles,#(SLOW_ONE_CYCLE*2)	@ update Cycles
	MOV		R0,R0,LSR #24
	ORR		R0,R0,R0,LSL #8
	LDMFD		R13!,{PC}
GWDEBUG:
	ADD		reg_cycles,reg_cycles,#(SLOW_ONE_CYCLE*2)	@ update Cycles
	MOV		R0,#0
	LDMFD		R13!,{PC}
GWC4:
	ADD		reg_cycles,reg_cycles,#(SLOW_ONE_CYCLE*2)	@ update Cycles	
	MOV		R0,R0,LSL #16 @ S9xGetC4(Address&0xFFFF);	
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Save Cycles
	MOV		R0,R0,LSR #16
		PREPARE_C_CALL_R0
	BL		S9xGetC4
	LDMFD		R13!,{R1}
	STMFD		R13!,{R0}
	ADD		R0,R1,#1
	@ BIC		R0,R0,#0x10000
	BL		S9xGetC4
		RESTORE_C_CALL_R1
	ORR		R0,R1,R0,LSL #8
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles	
	LDMFD		R13!,{PC} @ Return
GWBWRAM:
	TST		R0,#1
	BNE		GW_Not_Aligned4
	MOV		R0,R0,LSL #17  
	ADD		reg_cycles,reg_cycles,#(SLOW_ONE_CYCLE*2)	@ update Cycles
	MOV		R0,R0,LSR #17	@ Address&0x7FFF
	LDR		R1,[reg_cpu_var,#BWRAM]		
	SUB		R0,R0,#0x6000 @ ((Address & 0x7fff) - 0x6000)		
	LDRH		R0,[R1,R0]		@ *Memory.BWRAM + ((Address & 0x7fff) - 0x6000)	
	LDMFD		R13!,{PC}		@ return
GW_Not_Aligned4:
	MOV		R0,R0,LSL #17  	
	ADD		reg_cycles,reg_cycles,#(SLOW_ONE_CYCLE*2)	@ update Cycles
	ADD		R3,R0,#0x20000
	MOV		R0,R0,LSR #17	@ Address&0x7FFF
	MOV		R3,R3,LSR #17	@ (Address+1)&0x7FFF
	LDR		R1,[reg_cpu_var,#BWRAM]		
	SUB		R0,R0,#0x6000 @ ((Address & 0x7fff) - 0x6000)	
	SUB		R3,R3,#0x6000 @ (((Address+1) & 0x7fff) - 0x6000)	
	LDRB		R0,[R1,R0]		@ *Memory.BWRAM + ((Address & 0x7fff) - 0x6000)		
	LDRB		R3,[R1,R3]		@ *Memory.BWRAM + (((Address+1) & 0x7fff) - 0x6000)	
	ORR		R0,R0,R3,LSL #8
	LDMFD		R13!,{PC}		@ return




@ void aaS9xSetByte(uint32 address,uint8 val);
asmS9xSetByte:
	@  in : R0=0x00hhmmll  R1=0x000000ll	
	@  DESTROYED : R0,R1,R2,R3
	@  UPDATE : reg_cycles	
	@ cpu shutdown
	MOV		R2,#0
	STR		R2,[reg_cpu_var,#WaitAddress_ofs]
	@ 
	
	@ R3 <= block				
	MOV		R3,R0,LSR #MEMMAP_SHIFT
	@ MEMMAP_SHIFT is 12, Address is 0xFFFFFFFF at max, so
	@ R0 is maxed by 0x000FFFFF, MEMMAP_MASK is 0x1000-1=0xFFF
	@ so AND MEMMAP_MASK is BIC 0xFF000
	BIC		R3,R3,#0xFF000
	@ R2 <= Map[block] (SetAddress)
	LDR		R2,[reg_cpu_var,#WriteMap_ofs]
	LDR		R2,[R2,R3,LSL #2]
	CMP		R2,#MAP_LAST
	BLO		SBSpecial  @ special
	@  Direct ROM/RAM acess
	
	@ R2 <= SetAddress + Address & 0xFFFF	
	MOV		R0,R0,LSL #16	
	ADD		R2,R2,R0,LSR #16	
	LDR		R0,[reg_cpu_var,#MemorySpeed_ofs]
	@ Set byte
	STRB		R1,[R2]		
	@ R0 <= MemorySpeed[block]
	LDRB		R0,[R0,R3]	
	@ Update CPU.Cycles
	ADD		reg_cycles,reg_cycles,R0
	@ CPUShutdown
	@ only SA1 here : TODO	
	@ Return
	LDMFD		R13!,{PC}
SBSpecial:
	LDR		PC,[PC,R2,LSL #2]
	MOV		R0,R0 		@ nop, for align
	.long SBPPU
	.long SBCPU
	.long SBDSP
	.long SBLSRAM
	.long SBHSRAM
	.long SBNONE
	.long SBDEBUG
	.long SBC4
	.long SBBWRAM
	.long SBNONE
	.long SBNONE
	.long SBNONE
	/*.long SB7ROM
	.long SB7RAM
	.long SB7SRM*/
SBPPU:
	@ InDMA ?
	LDRB		R2,[reg_cpu_var,#InDMA_ofs]
	MOVS		R2,R2	
	ADDEQ		reg_cycles,reg_cycles,#ONE_CYCLE		@ No -> update Cycles
	MOV		R0,R0,LSL #16	
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs]	@ Save Cycles
	MOV		R0,R0,LSR #16
		PREPARE_C_CALL
	MOV		R12,R0
	MOV		R0,R1
	MOV		R1,R12		
	AND     R0,R0,#0xFF
	BL		S9xSetPPU		
		RESTORE_C_CALL
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles	
	LDMFD		R13!,{PC} @ Return
SBCPU:	
	ADD		reg_cycles,reg_cycles,#ONE_CYCLE	@ update Cycles	
	MOV		R0,R0,LSL #16 
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Save Cycles
	MOV		R0,R0,LSR #16	@ Address&0xFFFF
		PREPARE_C_CALL
	MOV		R12,R0
	MOV		R0,R1
	MOV		R1,R12		
	AND		R0,R0,#0xFF
	BL		S9xSetCPU		
		RESTORE_C_CALL
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles	
	LDMFD		R13!,{PC} @ Return
SBDSP:
	ADD		reg_cycles,reg_cycles,#SLOW_ONE_CYCLE	@ update Cycles	
	MOV		R0,R0,LSL #16 
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Save Cycles
	MOV		R0,R0,LSR #16	@ Address&0xFFFF
		PREPARE_C_CALL
	MOV		R12,R0
	MOV		R0,R1
	MOV		R1,R12		
	AND		R0,R0,#0xFF
	BL		S9xSetDSP		
		RESTORE_C_CALL
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles	
	LDMFD		R13!,{PC} @ Return
SBLSRAM:
	ADD		reg_cycles,reg_cycles,#SLOW_ONE_CYCLE	@ update Cycles		
	LDRH		R2,[reg_cpu_var,#SRAMMask]
	MOVS		R2,R2
	LDMEQFD		R13!,{PC} @ return if SRAMMask=0
	LDR		R3,[reg_cpu_var,#SRAM]	
	AND		R0,R2,R0		@ Address&SRAMMask	
	STRB		R1,[R0,R3]		@ *Memory.SRAM + Address&SRAMMask	
	
	MOV		R0,#1
	STRB		R0,[reg_cpu_var,#SRAMModified_ofs]		
	LDMFD		R13!,{PC}  @ return
SB7SRM:	
SBHSRAM:
	ADD		reg_cycles,reg_cycles,#SLOW_ONE_CYCLE	@ update Cycles		
	
	MOV		R3,R0,LSL #17  
	AND		R2,R0,#0xF0000
	MOV		R3,R3,LSR #17	@ Address&0x7FFF	
	MOV		R2,R2,LSR #3 @ (Address&0xF0000 >> 3)	
	ADD		R0,R2,R3	
	
	LDRH		R2,[reg_cpu_var,#SRAMMask]
	MOVS		R2,R2
	LDMEQFD		R13!,{PC} @ return if SRAMMask=0
	
	SUB		R0,R0,#0x6000 @ ((Address & 0x7fff) - 0x6000 + ((Address & 0xf0000) >> 3))
	LDR		R3,[reg_cpu_var,#SRAM]	
	AND		R0,R2,R0		@ Address&SRAMMask	
	STRB		R1,[R0,R3]		@ *Memory.SRAM + Address&SRAMMask
	
	MOV		R0,#1
	STRB		R0,[reg_cpu_var,#SRAMModified_ofs]		
	LDMFD		R13!,{PC}	@ return
SB7ROM:
SB7RAM:	
SBNONE:	
SBDEBUG:
	ADD		reg_cycles,reg_cycles,#SLOW_ONE_CYCLE	@ update Cycles
	LDMFD		R13!,{PC}
SBC4:
	ADD		reg_cycles,reg_cycles,#SLOW_ONE_CYCLE	@ update Cycles	
	MOV		R0,R0,LSL #16 
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Save Cycles
	MOV		R0,R0,LSR #16	@ Address&0xFFFF	
		PREPARE_C_CALL
	MOV		R12,R0
	MOV		R0,R1
	MOV		R1,R12		
	AND		R0,R0,#0xFF
	BL		S9xSetC4		
		RESTORE_C_CALL
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles	
	LDMFD		R13!,{PC} @ Return
SBBWRAM:
	MOV		R0,R0,LSL #17  
	ADD		reg_cycles,reg_cycles,#SLOW_ONE_CYCLE	@ update Cycles
	MOV		R0,R0,LSR #17	@ Address&0x7FFF			
	LDR		R2,[reg_cpu_var,#BWRAM]	
	SUB		R0,R0,#0x6000 @ ((Address & 0x7fff) - 0x6000)	
	STRB		R1,[R0,R2]		@ *Memory.BWRAM + ((Address & 0x7fff) - 0x6000)
	
	MOV		R0,#1
	STRB		R0,[reg_cpu_var,#SRAMModified_ofs]		
	
	LDMFD		R13!,{PC}



@ void aaS9xSetWord(uint32 address,uint16 val);
asmS9xSetWord:
	@  in : R0  = 0x00hhmmll R1=0x0000hhll
	@  DESTROYED : R0,R1,R2,R3
	@  UPDATE : reg_cycles
	@ R1 <= block	
	
	MOV		R2,R0,LSL #19	
	ADDS		R2,R2,#0x80000
	@ if = 0x1FFF => 0
	BNE		SW_NotBoundary
	
	STMFD		R13!,{R0,R1}
		STMFD		R13!,{PC}
	B		asmS9xSetByte
	LDMFD		R13!,{R0,R1}	
	ADD		R0,R0,#1
	MOV		R1,R1,LSR #8
		STMFD		R13!,{PC}
	B		asmS9xSetByte
	
	LDMFD		R13!,{PC}
	
SW_NotBoundary:	
	
	MOV		R2,#0
	STR		R2,[reg_cpu_var,#WaitAddress_ofs]
	@ 	
	@ R3 <= block				
	MOV		R3,R0,LSR #MEMMAP_SHIFT
	@ MEMMAP_SHIFT is 12, Address is 0xFFFFFFFF at max, so
	@ R1 is maxed by 0x000FFFFF, MEMMAP_MASK is 0x1000-1=0xFFF
	@ so AND MEMMAP_MASK is BIC 0xFF000
	BIC		R3,R3,#0xFF000
	@ R2 <= Map[block] (SetAddress)
	LDR		R2,[reg_cpu_var,#WriteMap_ofs]
	LDR		R2,[R2,R3,LSL #2]
	CMP		R2,#MAP_LAST
	BLO		SWSpecial  @ special
	@  Direct ROM/RAM acess		
	
	
	@ check if address is 16bits aligned or not
	TST		R0,#1
	BNE		SW_not_aligned1
	@ aligned
	MOV		R0,R0,LSL #16
	ADD		R2,R2,R0,LSR #16	@ address & 0xFFFF + SetAddress
	LDR		R0,[reg_cpu_var,#MemorySpeed_ofs]
	@ Set word
	STRH		R1,[R2]		
	@ R1 <= MemorySpeed[block]
	LDRB		R0,[R0,R3]
	@ Update CPU.Cycles
	ADD		reg_cycles,reg_cycles,R0, LSL #1
	@ CPUShutdown
	@ only SA1 here : TODO	
	@ Return
	LDMFD		R13!,{PC}
	
SW_not_aligned1:	
	@ R1 = (Address&0xFFFF)<<16
	MOV		R0,R0,LSL #16		
	@ First write @address
	STRB		R1,[R2,R0,LSR #16]
	ADD		R0,R0,#0x10000
	MOV		R1,R1,LSR #8
	@ Second write @address+1
	STRB		R1,[R2,R0,LSR #16]	
	@ R1 <= MemorySpeed[block]
	LDR		R0,[reg_cpu_var,#MemorySpeed_ofs]
	LDRB		R0,[R0,R3]	
	@ Update CPU.Cycles
	ADD		reg_cycles,reg_cycles,R0,LSL #1
	@ CPUShutdown
	@ only SA1 here : TODO	
	@ Return
	LDMFD		R13!,{PC}
SWSpecial:
	LDR		PC,[PC,R2,LSL #2]
	MOV		R0,R0 		@ nop, for align
	.long SWPPU
	.long SWCPU
	.long SWDSP
	.long SWLSRAM
	.long SWHSRAM
	.long SWNONE
	.long SWDEBUG
	.long SWC4
	.long SWBWRAM
	.long SWNONE
	.long SWNONE
	.long SWNONE
	/*.long SW7ROM
	.long SW7RAM
	.long SW7SRM*/
SWPPU:
	@ InDMA ?
	LDRB		R2,[reg_cpu_var,#InDMA_ofs]
	MOVS		R2,R2	
	ADDEQ		reg_cycles,reg_cycles,#(ONE_CYCLE*2)		@ No -> update Cycles
	MOV		R0,R0,LSL #16	
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs]	@ Save Cycles
	MOV		R0,R0,LSR #16
	MOV		R2,R1
	MOV		R1,R0
	MOV		R0,R2
		PREPARE_C_CALL_R0R1
	AND     R0,R0,#0xFF
	BL		S9xSetPPU		
	LDMFD		R13!,{R0,R1}
	ADD		R1,R1,#1
	MOV		R0,R0,LSR #8	
	BIC		R1,R1,#0x10000		
	AND     R0,R0,#0xFF
	BL		S9xSetPPU		
		RESTORE_C_CALL
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles	
	LDMFD		R13!,{PC} @ Return
SWCPU:	
	ADD		reg_cycles,reg_cycles,#(ONE_CYCLE*2)	@ update Cycles	
	MOV		R0,R0,LSL #16 
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Save Cycles
	MOV		R0,R0,LSR #16	@ Address&0xFFFF
	MOV		R2,R1
	MOV		R1,R0
	MOV		R0,R2	
		PREPARE_C_CALL_R0R1
	AND		R0,R0,#0xFF
	BL		S9xSetCPU		
	LDMFD		R13!,{R0,R1}
	ADD		R1,R1,#1
	MOV		R0,R0,LSR #8	
	BIC		R1,R1,#0x10000		
	AND		R0,R0,#0xFF
	BL		S9xSetCPU		
		RESTORE_C_CALL
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles	
	LDMFD		R13!,{PC} @ Return
SWDSP:
	ADD		reg_cycles,reg_cycles,#SLOW_ONE_CYCLE	@ update Cycles	
	MOV		R0,R0,LSL #16 
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Save Cycles
	MOV		R0,R0,LSR #16	@ Address&0xFFFF
	MOV		R2,R1
	MOV		R1,R0
	MOV		R0,R2
		PREPARE_C_CALL_R0R1
	AND		R0,R0,#0xFF
	BL		S9xSetDSP	
	LDMFD		R13!,{R0,R1}
	ADD		R1,R1,#1
	MOV		R0,R0,LSR #8	
	BIC		R1,R1,#0x10000	
	AND		R0,R0,#0xFF
	BL		S9xSetDSP		
		RESTORE_C_CALL
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles	
	LDMFD		R13!,{PC} @ Return
SWLSRAM:
	ADD		reg_cycles,reg_cycles,#(SLOW_ONE_CYCLE*2)	@ update Cycles		
	LDRH		R2,[reg_cpu_var,#SRAMMask]
	MOVS		R2,R2
	LDMEQFD		R13!,{PC} @ return if SRAMMask=0
			
	AND		R3,R2,R0		@ Address&SRAMMask
	TST		R0,#1
	BNE		SW_not_aligned2
	@ aligned	
	LDR		R0,[reg_cpu_var,#SRAM]	
	STRH		R1,[R0,R3]		@ *Memory.SRAM + Address&SRAMMask		
	MOV		R0,#1
	STRB		R0,[reg_cpu_var,#SRAMModified_ofs]		
	LDMFD		R13!,{PC}  @ return	
SW_not_aligned2:	

	ADD		R0,R0,#1
	AND		R2,R2,R0		@ (Address+1)&SRAMMask		
	LDR		R0,[reg_cpu_var,#SRAM]	
	STRB		R1,[R0,R3]		@ *Memory.SRAM + Address&SRAMMask
	MOV		R1,R1,LSR #8
	STRB		R1,[R0,R2]		@ *Memory.SRAM + (Address+1)&SRAMMask	
	MOV		R0,#1
	STRB		R0,[reg_cpu_var,#SRAMModified_ofs]		
	LDMFD		R13!,{PC}  @ return
SW7SRM:	
SWHSRAM:
	ADD		reg_cycles,reg_cycles,#(SLOW_ONE_CYCLE*2)	@ update Cycles		
	
	LDRH		R2,[reg_cpu_var,#SRAMMask]
	MOVS		R2,R2
	LDMEQFD		R13!,{PC} @ return if SRAMMask=0
	
	TST		R0,#1
	BNE		SW_not_aligned3	
	@ aligned
	MOV		R3,R0,LSL #17  
	AND		R2,R0,#0xF0000
	MOV		R3,R3,LSR #17	@ Address&0x7FFF	
	MOV		R2,R2,LSR #3 @ (Address&0xF0000 >> 3)	
	ADD		R0,R2,R3				
	SUB		R0,R0,#0x6000 @ ((Address & 0x7fff) - 0x6000 + ((Address & 0xf0000) >> 3))
	LDRH		R2,[reg_cpu_var,#SRAMMask]
	LDR		R3,[reg_cpu_var,#SRAM]	
	AND		R0,R2,R0		@ Address&SRAMMask	
	STRH		R1,[R0,R3]		@ *Memory.SRAM + Address&SRAMMask	
	MOV		R0,#1
	STRB		R0,[reg_cpu_var,#SRAMModified_ofs]		
	LDMFD		R13!,{PC}	@ return		
SW_not_aligned3:	
	MOV		R3,R0,LSL #17  
	AND		R2,R0,#0xF0000
	MOV		R3,R3,LSR #17	@ Address&0x7FFF	
	MOV		R2,R2,LSR #3 @ (Address&0xF0000 >> 3)	
	ADD		R2,R2,R3				
	SUB		R2,R2,#0x6000 @ ((Address & 0x7fff) - 0x6000 + ((Address & 0xf0000) >> 3))
	
	ADD		R0,R0,#1	
	MOV		R3,R0,LSL #17  
	AND		R0,R0,#0xF0000
	MOV		R3,R3,LSR #17	@ (Address+1)&0x7FFF	
	MOV		R0,R0,LSR #3 @ ((Address+1)&0xF0000 >> 3)	
	ADD		R0,R0,R3	
	LDRH		R3,[reg_cpu_var,#SRAMMask]	@ reload mask	
	SUB		R0,R0,#0x6000 @ (((Address+1) & 0x7fff) - 0x6000 + (((Address+1) & 0xf0000) >> 3))		
	AND		R2,R3,R2		@ Address...&SRAMMask	
	AND		R0,R3,R0		@ (Address+1...)&SRAMMask	
	
	LDR		R3,[reg_cpu_var,#SRAM]
	STRB		R1,[R2,R3]		@ *Memory.SRAM + (Address...)&SRAMMask
	MOV		R1,R1,LSR #8
	STRB		R1,[R0,R3]		@ *Memory.SRAM + (Address+1...)&SRAMMask
	
	MOV		R0,#1
	STRB		R0,[reg_cpu_var,#SRAMModified_ofs]		
	LDMFD		R13!,{PC}	@ return	
SW7ROM:
SW7RAM:	
SWNONE:	
SWDEBUG:
	ADD		reg_cycles,reg_cycles,#(SLOW_ONE_CYCLE*2)	@ update Cycles
	LDMFD		R13!,{PC}	@ return
SWC4:
	ADD		reg_cycles,reg_cycles,#(SLOW_ONE_CYCLE*2)	@ update Cycles	
	MOV		R0,R0,LSL #16 
	STR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Save Cycles
	MOV		R0,R0,LSR #16	@ Address&0xFFFF	
	MOV		R2,R1
	MOV		R1,R0
	MOV		R0,R2
		PREPARE_C_CALL_R0R1
	AND		R0,R0,#0xFF
	BL		S9xSetC4		
	LDMFD		R13!,{R0,R1}	
	ADD		R1,R1,#1
	MOV		R0,R0,LSR #8	
	BIC		R1,R1,#0x10000		
	AND		R0,R0,#0xFF
	BL		S9xSetC4		
		RESTORE_C_CALL
	LDR		reg_cycles,[reg_cpu_var,#Cycles_ofs] @ Load Cycles	
	LDMFD		R13!,{PC} @ Return
SWBWRAM:
	ADD		reg_cycles,reg_cycles,#(SLOW_ONE_CYCLE*2)	@ update Cycles
	TST		R0,#1
	BNE		SW_not_aligned4
	@ aligned
	MOV		R0,R0,LSL #17		
	LDR		R2,[reg_cpu_var,#BWRAM]
	MOV		R0,R0,LSR #17	@ Address&0x7FFF			
	SUB		R0,R0,#0x6000 @ ((Address & 0x7fff) - 0x6000)	
	MOV		R3,#1
	STRH		R1,[R0,R2]		@ *Memory.BWRAM + ((Address & 0x7fff) - 0x6000)			
	STRB		R3,[reg_cpu_var,#SRAMModified_ofs]			
	LDMFD		R13!,{PC}	@ return
SW_not_aligned4:
	MOV		R0,R0,LSL #17	
	ADD		R3,R0,#0x20000
	MOV		R0,R0,LSR #17	@ Address&0x7FFF
	MOV		R3,R3,LSR #17	@ (Address+1)&0x7FFF
	LDR		R2,[reg_cpu_var,#BWRAM]	
	SUB		R0,R0,#0x6000 @ ((Address & 0x7fff) - 0x6000)
	SUB		R3,R3,#0x6000 @ (((Address+1) & 0x7fff) - 0x6000)
	STRB		R1,[R2,R0]		@ *Memory.BWRAM + ((Address & 0x7fff) - 0x6000)
	MOV		R1,R1,LSR #8
	STRB		R1,[R2,R3]		@ *Memory.BWRAM + (((Address+1) & 0x7fff) - 0x6000)	
	MOV		R0,#1
	STRB		R0,[reg_cpu_var,#SRAMModified_ofs]			
	LDMFD		R13!,{PC}		@ return
	




/*****************************************************************
	FLAGS  
*****************************************************************/

.macro		UPDATE_C
		@  CC : ARM Carry Clear
		BICCC	rstatus, rstatus, #MASK_CARRY  @ 	0 : AND	mask 11111011111 : set C to zero
		@  CS : ARM Carry Set
		ORRCS	rstatus, rstatus, #MASK_CARRY      @ 	1 : OR	mask 00000100000 : set C to one
.endm
.macro		UPDATE_Z
		@  NE : ARM Zero Clear
		BICNE	rstatus, rstatus, #MASK_ZERO	 @  0 : AND mask	11111011111 : set Z to zero
		@  EQ : ARM Zero Set
		ORREQ	rstatus, rstatus, #MASK_ZERO	 @  1 : OR  mask	00000100000  : set Z to	one		
.endm
.macro		UPDATE_ZN
		@  NE : ARM Zero Clear
		BICNE	rstatus, rstatus, #MASK_ZERO	 @  0 : AND mask	11111011111 : set Z to zero
		@  EQ : ARM Zero Set
		ORREQ	rstatus, rstatus, #MASK_ZERO	 @  1 : OR  mask	00000100000  : set Z to	one
		@  PL : ARM Neg Clear
		BICPL	rstatus, rstatus, #MASK_NEG	@  0 : AND mask 11111011111 : set N to zero
		@  MI : ARM Neg Set
		ORRMI	rstatus, rstatus, #MASK_NEG	@  1 : OR  mask 00000100000 : set N to one
.endm

/*****************************************************************
	OPCODES_MAC
*****************************************************************/




.macro ADC8
		TST rstatus, #MASK_DECIMAL
		BEQ 1111f				
		S9xGetByte		
		
	
	        STMFD 	R13!,{rscratch}		
		MOV 	rscratch4,#0x0F000000
		@ rscratch2=xxW1xxxxxxxxxxxx
		AND 	rscratch2, rscratch, rscratch4
		@ rscratch=xxW2xxxxxxxxxxxx
		AND 	rscratch, rscratch4, rscratch, LSR #4
		@ rscratch3=xxA2xxxxxxxxxxxx
		AND 	rscratch3, rscratch4, reg_a, LSR #4
		@ rscratch4=xxA1xxxxxxxxxxxx		
		AND 	rscratch4,reg_a,rscratch4		
		@ R1=A1+W1+CARRY
		TST 	rstatus, #MASK_CARRY
		ADDNE 	rscratch2, rscratch2, #0x01000000
		ADD 	rscratch2,rscratch2,rscratch4
		@  if R1 > 9
		CMP 	rscratch2, #0x09000000
		@  then R1 -= 10
		SUBGT 	rscratch2, rscratch2, #0x0A000000
		@  then A2++
		ADDGT 	rscratch3, rscratch3, #0x01000000
		@  R2 = A2+W2
		ADD 	rscratch3, rscratch3, rscratch
		@  if R2 > 9
		CMP 	rscratch3, #0x09000000
		@  then R2 -= 10@ 
		SUBGT 	rscratch3, rscratch3, #0x0A000000
		@  then SetCarry()
		ORRGT 	rstatus, rstatus, #MASK_CARRY @  1 : OR mask 00000100000 : set C to one
		@  else ClearCarry()
		BICLE 	rstatus, rstatus, #MASK_CARRY @  0 : AND mask 11111011111 : set C to zero
		@  gather rscratch3 and rscratch2 into ans8
		@  rscratch3 : 0R2000000
		@  rscratch2 : 0R1000000
		@  -> 0xR2R1000000
		ORR 	rscratch2, rscratch2, rscratch3, LSL #4		
		LDMFD 	R13!,{rscratch}
		@ only last bit
		AND 	rscratch,rscratch,#0x80000000
		@  (register.AL ^ Work8)
		EORS 	rscratch3, reg_a, rscratch
		BICNE 	rstatus, rstatus, #MASK_OVERFLOW @  0 : AND mask 11111011111 : set V to zero
		BNE 	1112f
		@  (Work8 ^ Ans8)
		EORS 	rscratch3, rscratch2, rscratch
		@  & 0x80 
		TSTNE	rscratch3,#0x80000000
		BICEQ 	rstatus, rstatus, #MASK_OVERFLOW @  0 : AND mask 11111011111 : set V to zero
		ORRNE 	rstatus, rstatus, #MASK_OVERFLOW @  1 : OR mask 00000100000 : set V to one 
1112:
		MOVS reg_a, rscratch2
		UPDATE_ZN
		B 1113f
1111:
		S9xGetByteLow
		MOVS rscratch2, rstatus, LSR #MASK_SHIFTER_CARRY
		SUBCS rscratch, rscratch, #0x100 
		ADCS reg_a, reg_a, rscratch, ROR #8
		@ OverFlow
		ORRVS rstatus, rstatus, #MASK_OVERFLOW
		BICVC rstatus, rstatus, #MASK_OVERFLOW
		@ Carry
		UPDATE_C
		@ clear lower part
		ANDS reg_a, reg_a, #0xFF000000
		@ Update flag
		UPDATE_ZN
1113: 
.endm
/* TO TEST */
.macro ADC16 
		TST rstatus, #MASK_DECIMAL
		BEQ 1111f 
		S9xGetWord
		
		@ rscratch = W3W2W1W0........
		LDR 	rscratch4, = 0x0F0F0000
		@  rscratch2 = xxW2xxW0xxxxxx
		@  rscratch3 = xxW3xxW1xxxxxx
		AND 	rscratch2, rscratch4, rscratch
		AND 	rscratch3, rscratch4, rscratch, LSR #4 
		@  rscratch2 = xxW3xxW1xxW2xxW0
		ORR 	rscratch2, rscratch3, rscratch2, LSR #16 		
		@  rscratch3 = xxA2xxA0xxxxxx
		@  rscratch4 = xxA3xxA1xxxxxx
		@  rscratch2 = xxA3xxA1xxA2xxA0
		AND 	rscratch3, rscratch4, reg_a
		AND 	rscratch4, rscratch4, reg_a, LSR #4
		ORR 	rscratch3, rscratch4, rscratch3, LSR #16		
		ADD 	rscratch2, rscratch3, rscratch2 		
		LDR 	rscratch4, = 0x0F0F0000		
		@  rscratch2 = A + W
		TST 	rstatus, #MASK_CARRY
		ADDNE 	rscratch2, rscratch2, #0x1
		@  rscratch2 = A + W + C
		@ A0
		AND 	rscratch3, rscratch2, #0x0000001F
		CMP 	rscratch3, #0x00000009
		ADDHI 	rscratch2, rscratch2, #0x00010000
		SUBHI 	rscratch2, rscratch2, #0x0000000A
		@ A1
		AND 	rscratch3, rscratch2, #0x001F0000
		CMP 	rscratch3, #0x00090000
		ADDHI 	rscratch2, rscratch2, #0x00000100
		SUBHI 	rscratch2, rscratch2, #0x000A0000
		@ A2
		AND 	rscratch3, rscratch2, #0x00001F00
		CMP 	rscratch3, #0x00000900
		SUBHI 	rscratch2, rscratch2, #0x00000A00
		ADDHI 	rscratch2, rscratch2, #0x01000000
		@ A3
		AND 	rscratch3, rscratch2, #0x1F000000
		CMP 	rscratch3, #0x09000000
		SUBHI 	rscratch2, rscratch2, #0x0A000000
		@ SetCarry
		ORRHI 	rstatus, rstatus, #MASK_CARRY
		@ ClearCarry
		BICLS 	rstatus, rstatus, #MASK_CARRY
		@ rscratch2 = xxR3xxR1xxR2xxR0
		@ Pack result 
		@ rscratch3 = xxR3xxR1xxxxxxxx 
		AND 	rscratch3, rscratch4, rscratch2 
		@ rscratch2 = xxR2xxR0xxxxxxxx
		AND 	rscratch2, rscratch4, rscratch2,LSL #16
		@ rscratch2 = R3R2R1R0xxxxxxxx
		ORR 	rscratch2, rscratch2,rscratch3,LSL #4		
@ only last bit
		AND 	rscratch,rscratch,#0x80000000
		@  (register.AL ^ Work8)
		EORS 	rscratch3, reg_a, rscratch 
		BICNE 	rstatus, rstatus, #MASK_OVERFLOW @  0 : AND mask 11111011111 : set V to zero
		BNE 	1112f
		@  (Work8 ^ Ans8)
		EORS 	rscratch3, rscratch2, rscratch 
		TSTNE	rscratch3,#0x80000000
		BICEQ 	rstatus, rstatus, #MASK_OVERFLOW @  0 : AND mask 11111011111 : set V to zero
		ORRNE 	rstatus, rstatus, #MASK_OVERFLOW @  1 : OR mask 00000100000 : set V to one 
1112:
		MOVS 	reg_a, rscratch2
		UPDATE_ZN
		B 	1113f
1111:
		S9xGetWordLow
		MOVS rscratch2, rstatus, LSR #MASK_SHIFTER_CARRY 
		SUBCS rscratch, rscratch, #0x10000 
		ADCS reg_a, reg_a,rscratch, ROR #16
		@ OverFlow 
		ORRVS rstatus, rstatus, #MASK_OVERFLOW
		BICVC rstatus, rstatus, #MASK_OVERFLOW
		MOV reg_a, reg_a, LSR #16
		@ Carry
		UPDATE_C
		@ clear lower parts 
		MOVS reg_a, reg_a, LSL #16
		@ Update flag
		UPDATE_ZN
1113: 
.endm


.macro		AND16
		S9xGetWord
		ANDS		reg_a, reg_a, rscratch
		UPDATE_ZN
.endm
.macro		AND8
		S9xGetByte
		ANDS		reg_a, reg_a, rscratch
		UPDATE_ZN
.endm
.macro		A_ASL8
		@  7	instr		
		MOVS	reg_a, reg_a, LSL #1
		UPDATE_C
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		A_ASL16
		@  7	instr		
		MOVS	reg_a, reg_a, LSL #1
		UPDATE_C
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		ASL16		
		S9xGetWordRegNS	rscratch2	      @ 	do not destroy Opadress	in rscratch
		MOVS		rscratch2, rscratch2, LSL #1
		UPDATE_C
		UPDATE_ZN		
		S9xSetWord 	rscratch2
		ADD1CYCLE
.endm
.macro		ASL8				
		S9xGetByteRegNS	rscratch2	      @ 	do not destroy Opadress	in rscratch
		MOVS		rscratch2, rscratch2, LSL #1
		UPDATE_C
		UPDATE_ZN		
		S9xSetByte 	rscratch2
		ADD1CYCLE
.endm
.macro		BIT8
		S9xGetByte
		MOVS	rscratch2, rscratch, LSL #1
		@  Trick in ASM : shift one more bit	: ARM C	= Snes N
		@ 					  ARM N	= Snes V
		@  If Carry Set, then Set Neg in SNES
		BICCC	rstatus, rstatus, #MASK_NEG	@  0 : AND mask 11111011111 : set C to zero
		ORRCS	rstatus, rstatus, #MASK_NEG	@  1 : OR  mask 00000100000 : set C to one
		@  If Neg Set, then Set Overflow in SNES
		BICPL	rstatus, rstatus, #MASK_OVERFLOW  @  0 : AND mask 11111011111	: set N	to zero
		ORRMI	rstatus, rstatus, #MASK_OVERFLOW	     @  1 : OR  mask 00000100000	: set N	to one

		@  Now do a real AND	with A register
		@  Set Zero Flag, bit test
		ANDS	rscratch2, reg_a, rscratch
		BICNE	rstatus, rstatus, #MASK_ZERO	 @  0 : AND mask	11111011111 : set Z to zero
		ORREQ	rstatus, rstatus, #MASK_ZERO	 @  1 : OR  mask	00000100000  : set Z to	one
.endm

.macro		BIT16
		S9xGetWord
		MOVS	rscratch2, rscratch, LSL #1
		@  Trick in ASM : shift one more bit	: ARM C	= Snes N
		@ 					  ARM N	= Snes V
		@  If Carry Set, then Set Neg in SNES
		BICCC	rstatus, rstatus, #MASK_NEG	@  0 : AND mask 11111011111 : set N to zero
		ORRCS	rstatus, rstatus, #MASK_NEG	@  1 : OR  mask 00000100000 : set N to one
		@  If Neg Set, then Set Overflow in SNES
		BICPL	rstatus, rstatus, #MASK_OVERFLOW  @  0 : AND mask 11111011111	: set V	to zero
		ORRMI	rstatus, rstatus, #MASK_OVERFLOW	     @  1 : OR  mask 00000100000	: set V	to one
		@  Now do a real AND	with A register
		@  Set Zero Flag, bit test
		ANDS	rscratch2, reg_a, rscratch
		@  Bit set  ->Z=0->xxxNE Clear flag
		BICNE	rstatus, rstatus, #MASK_ZERO	 @  0 : AND mask	11111011111 : set Z to zero
		@  Bit clear->Z=1->xxxEQ Set flag
		ORREQ	rstatus, rstatus, #MASK_ZERO	 @  1 : OR  mask	00000100000  : set Z to	one
.endm
.macro		CMP8
		S9xGetByte			
		SUBS 	rscratch2,reg_a,rscratch		
		BICCC	rstatus, rstatus, #MASK_CARRY
		ORRCS	rstatus, rstatus, #MASK_CARRY
		UPDATE_ZN
		
.endm
.macro		CMP16
		S9xGetWord
		SUBS 	rscratch2,reg_a,rscratch		
		BICCC	rstatus, rstatus, #MASK_CARRY
		ORRCS	rstatus, rstatus, #MASK_CARRY
		UPDATE_ZN
		
.endm
.macro		CMX16
		S9xGetWord
		SUBS 	rscratch2,reg_x,rscratch		
		BICCC	rstatus, rstatus, #MASK_CARRY
		ORRCS	rstatus, rstatus, #MASK_CARRY
		UPDATE_ZN
.endm
.macro		CMX8
		S9xGetByte
		SUBS 	rscratch2,reg_x,rscratch		
		BICCC	rstatus, rstatus, #MASK_CARRY
		ORRCS	rstatus, rstatus, #MASK_CARRY
		UPDATE_ZN
.endm
.macro		CMY16
		S9xGetWord
		SUBS 	rscratch2,reg_y,rscratch		
		BICCC	rstatus, rstatus, #MASK_CARRY
		ORRCS	rstatus, rstatus, #MASK_CARRY
		UPDATE_ZN
.endm
.macro		CMY8
		S9xGetByte
		SUBS 	rscratch2,reg_y,rscratch		
		BICCC	rstatus, rstatus, #MASK_CARRY
		ORRCS	rstatus, rstatus, #MASK_CARRY
		UPDATE_ZN
.endm
.macro		A_DEC8		
		MOV		rscratch,#0		
		SUBS		reg_a, reg_a, #0x01000000
		STR		rscratch,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		A_DEC16		
		MOV		rscratch,#0
		SUBS 		reg_a, reg_a, #0x00010000
		STR		rscratch,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		DEC16		
		S9xGetWordRegNS rscratch2	       @  do not	destroy	Opadress in rscratch		
		MOV		rscratch3,#0
		SUBS		rscratch2, rscratch2, #0x00010000
		STR		rscratch3,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN		
		S9xSetWord 	rscratch2
		ADD1CYCLE
.endm
.macro		DEC8
		S9xGetByteRegNS rscratch2	       @  do not	destroy	Opadress in rscratch
		MOV		rscratch3,#0
		SUBS		rscratch2, rscratch2, #0x01000000
		STR		rscratch3,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN		
		S9xSetByte 	rscratch2
		ADD1CYCLE
.endm
.macro		EOR16
		S9xGetWord
		EORS		reg_a, reg_a, rscratch
		UPDATE_ZN
.endm
.macro		EOR8
		S9xGetByte
		EORS		reg_a, reg_a, rscratch
		UPDATE_ZN
.endm
.macro		A_INC8		
		MOV		rscratch3,#0
		ADDS		reg_a, reg_a, #0x01000000
		STR		rscratch3,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		A_INC16		
		MOV		rscratch3,#0	
		ADDS		reg_a, reg_a, #0x00010000
		STR		rscratch3,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		INC16		
		S9xGetWordRegNS	rscratch2
		MOV		rscratch3,#0
		ADDS		rscratch2, rscratch2, #0x00010000
		STR		rscratch3,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN		
		S9xSetWord 	rscratch2
		ADD1CYCLE
.endm
.macro		INC8		
		S9xGetByteRegNS	rscratch2
		MOV		rscratch3,#0
		ADDS		rscratch2, rscratch2, #0x01000000
		STR		rscratch3,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN		
		S9xSetByte 	rscratch2
		ADD1CYCLE
.endm
.macro		LDA16
		S9xGetWordRegStatus reg_a
		UPDATE_ZN
.endm
.macro		LDA8
		S9xGetByteRegStatus reg_a
		UPDATE_ZN
.endm
.macro		LDX16
		S9xGetWordRegStatus reg_x
		UPDATE_ZN
.endm
.macro		LDX8
		S9xGetByteRegStatus reg_x
		UPDATE_ZN
.endm
.macro		LDY16
		S9xGetWordRegStatus reg_y
		UPDATE_ZN
.endm
.macro		LDY8
		S9xGetByteRegStatus reg_y
		UPDATE_ZN
.endm
.macro		A_LSR16				
		BIC	rstatus, rstatus, #MASK_NEG	 @  0 : AND mask	11111011111 : set N to zero
		MOVS	reg_a, reg_a, LSR #17		 @  hhhhhhhh llllllll 00000000 00000000 -> 00000000 00000000 0hhhhhhh hlllllll
		@  Update Zero
		BICNE	rstatus, rstatus, #MASK_ZERO	 @  0 : AND mask	11111011111 : set Z to zero
		MOV	reg_a, reg_a, LSL #16			@  -> 0lllllll 00000000 00000000	00000000
		ORREQ	rstatus, rstatus, #MASK_ZERO	 @  1 : OR  mask	00000100000  : set Z to	one
		@  Note : the two MOV are included between instruction, to optimize
		@  the pipeline.
		UPDATE_C
		ADD1CYCLE
.endm
.macro		A_LSR8		
		BIC	rstatus, rstatus, #MASK_NEG	 @  0 : AND mask	11111011111 : set N to zero
		MOVS	reg_a, reg_a, LSR #25		 @  llllllll 00000000 00000000 00000000 -> 00000000 00000000 00000000 0lllllll
		@  Update Zero
		BICNE	rstatus, rstatus, #MASK_ZERO	 @  0 : AND mask	11111011111 : set Z to zero
		MOV	reg_a, reg_a, LSL #24			@  -> 00000000 00000000 00000000	0lllllll
		ORREQ	rstatus, rstatus, #MASK_ZERO	 @  1 : OR  mask	00000100000  : set Z to	one		
		@  Note : the two MOV are included between instruction, to optimize
		@  the pipeline.
		UPDATE_C
		ADD1CYCLE
.endm
.macro		LSR16				
		S9xGetWordRegNS	rscratch2
		@  N set to zero by >> 1 LSR
		BIC		rstatus, rstatus, #MASK_NEG	 @  0 : AND mask	11111011111 : set N to zero
		MOVS		rscratch2, rscratch2, LSR #17		   @  llllllll 00000000 00000000	00000000 -> 00000000 00000000 00000000 0lllllll
		@  Update Carry		
		BICCC		rstatus, rstatus, #MASK_CARRY  @ 	0 : AND	mask 11111011111 : set C to zero		
		ORRCS		rstatus, rstatus, #MASK_CARRY      @ 	1 : OR	mask 00000100000 : set C to one
		@  Update Zero
		BICNE		rstatus, rstatus, #MASK_ZERO	 @  0 : AND mask	11111011111 : set Z to zero
		ORREQ		rstatus, rstatus, #MASK_ZERO	 @  1 : OR  mask	00000100000  : set Z to	one	
		S9xSetWordLow 	rscratch2
		ADD1CYCLE
.endm
.macro		LSR8				
		S9xGetByteRegNS	rscratch2
		@  N set to zero by >> 1 LSR
		BIC		rstatus, rstatus, #MASK_NEG	 @  0 : AND mask	11111011111 : set N to zero
		MOVS		rscratch2, rscratch2, LSR #25		   @  llllllll 00000000 00000000	00000000 -> 00000000 00000000 00000000 0lllllll
		@  Update Carry		
		BICCC		rstatus, rstatus, #MASK_CARRY  @ 	0 : AND	mask 11111011111 : set C to zero		
		ORRCS		rstatus, rstatus, #MASK_CARRY      @ 	1 : OR	mask 00000100000 : set C to one
		@  Update Zero
		BICNE		rstatus, rstatus, #MASK_ZERO	 @  0 : AND mask	11111011111 : set Z to zero
		ORREQ		rstatus, rstatus, #MASK_ZERO	 @  1 : OR  mask	00000100000  : set Z to	one		
		S9xSetByteLow 	rscratch2
		ADD1CYCLE
.endm
.macro		ORA8
		S9xGetByte
		ORRS		reg_a, reg_a, rscratch
		UPDATE_ZN
.endm
.macro		ORA16
		S9xGetWord
		ORRS		reg_a, reg_a, rscratch
		UPDATE_ZN
.endm
.macro		A_ROL16		
		TST		rstatus, #MASK_CARRY
		ORRNE		reg_a, reg_a, #0x00008000
		MOVS		reg_a, reg_a, LSL #1
		UPDATE_ZN
		UPDATE_C
		ADD1CYCLE
.endm
.macro		A_ROL8		
		TST		rstatus, #MASK_CARRY
		ORRNE		reg_a, reg_a, #0x00800000
		MOVS		reg_a, reg_a, LSL #1
		UPDATE_ZN
		UPDATE_C
		ADD1CYCLE
.endm
.macro		ROL16		
		S9xGetWordRegNS	rscratch2
		TST		rstatus, #MASK_CARRY
		ORRNE		rscratch2, rscratch2, #0x00008000
		MOVS		rscratch2, rscratch2, LSL #1
		UPDATE_ZN
		UPDATE_C		
		S9xSetWord 	rscratch2
		ADD1CYCLE
.endm
.macro		ROL8		
		S9xGetByteRegNS	rscratch2
		TST		rstatus, #MASK_CARRY
		ORRNE		rscratch2, rscratch2, #0x00800000
		MOVS		rscratch2, rscratch2, LSL #1
		UPDATE_ZN
		UPDATE_C		
		S9xSetByte 	rscratch2
		ADD1CYCLE
.endm
.macro		A_ROR16		
		MOV			reg_a,reg_a, LSR #16
		TST			rstatus, #MASK_CARRY
		ORRNE			reg_a, reg_a, #0x00010000
		ORRNE			rstatus,rstatus,#MASK_NEG
		BICEQ			rstatus,rstatus,#MASK_NEG		
		MOVS			reg_a,reg_a,LSR #1
		UPDATE_C
		UPDATE_Z		
		MOV			reg_a,reg_a, LSL #16
		ADD1CYCLE
.endm
.macro		A_ROR8				
		MOV			reg_a,reg_a, LSR #24
		TST			rstatus, #MASK_CARRY
		ORRNE			reg_a, reg_a, #0x00000100
		ORRNE			rstatus,rstatus,#MASK_NEG
		BICEQ			rstatus,rstatus,#MASK_NEG		
		MOVS			reg_a,reg_a,LSR #1
		UPDATE_C
		UPDATE_Z		
		MOV			reg_a,reg_a, LSL #24
		ADD1CYCLE
.endm
.macro		ROR16		
		S9xGetWordLowRegNS	rscratch2
		TST			rstatus, #MASK_CARRY
		ORRNE			rscratch2, rscratch2, #0x00010000
		ORRNE			rstatus,rstatus,#MASK_NEG
		BICEQ			rstatus,rstatus,#MASK_NEG		
		MOVS			rscratch2,rscratch2,LSR #1
		UPDATE_C
		UPDATE_Z
		S9xSetWordLow 	rscratch2
		ADD1CYCLE

.endm
.macro		ROR8		
		S9xGetByteLowRegNS	rscratch2
		TST			rstatus, #MASK_CARRY
		ORRNE			rscratch2, rscratch2, #0x00000100
		ORRNE			rstatus,rstatus,#MASK_NEG
		BICEQ			rstatus,rstatus,#MASK_NEG		
		MOVS			rscratch2,rscratch2,LSR #1
		UPDATE_C
		UPDATE_Z
		S9xSetByteLow 	rscratch2
		ADD1CYCLE
.endm

.macro SBC16
        TST rstatus, #MASK_DECIMAL
		BEQ 1111f
		@ TODO
		S9xGetWord
		
		STMFD 	R13!,{rscratch9}
		MOV 	rscratch9,#0x000F0000
        @ rscratch2 - result
        @ rscratch3 - scratch
        @ rscratch4 - scratch
        @ rscratch9 - pattern

		AND 	rscratch2, rscratch, #0x000F0000
		TST 	rstatus, #MASK_CARRY
		ADDEQ 	rscratch2, rscratch2, #0x00010000  @ W1=W1+!Carry
		AND 	rscratch4, reg_a, #0x000F0000
        SUB 	rscratch2, rscratch4,rscratch2		@ R1=A1-W1-!Carry
		CMP 	rscratch2, #0x00090000	@  if R1 > 9		
		ADDHI 	rscratch2, rscratch2, #0x000A0000 @  then R1 += 10		
		AND	    rscratch2, rscratch2, #0x000F0000

		AND 	rscratch3, rscratch9, rscratch, LSR #4
        ADDHI 	rscratch3, rscratch3, #0x00010000  @  then (W2++)

		AND 	rscratch4, rscratch9, reg_a, LSR #4
        SUB 	rscratch3, rscratch4, rscratch3		@ R2=A2-W2
		CMP 	rscratch3, #0x00090000	@  if R2 > 9		
		ADDHI 	rscratch3, rscratch3, #0x000A0000 @  then R2 += 10		
		AND	    rscratch3, rscratch3, #0x000F0000
		ORR	    rscratch2, rscratch2, rscratch3,LSL #4

		AND 	rscratch3, rscratch9, rscratch, LSR #8
        ADDHI 	rscratch3, rscratch3, #0x00010000  @  then (W3++)

		AND 	rscratch4, rscratch9, reg_a, LSR #8
        SUB 	rscratch3, rscratch4, rscratch3		@ R3=A3-W3
		CMP 	rscratch3, #0x00090000	@  if R3 > 9		
		ADDHI 	rscratch3, rscratch3, #0x000A0000 @  then R3 += 10		
		AND	    rscratch3, rscratch3, #0x000F0000
		ORR	    rscratch2, rscratch2, rscratch3,LSL #8

		AND 	rscratch3, rscratch9, rscratch, LSR #12
        ADDHI 	rscratch3, rscratch3, #0x00010000  @  then (W3++)

		AND 	rscratch4, rscratch9, reg_a, LSR #12				
        SUB 	rscratch3, rscratch4, rscratch3		@ R4=A4-W4
		CMP 	rscratch3, #0x00090000	@  if R4 > 9		
		ADDHI 	rscratch3, rscratch3, #0x000A0000 @  then R4 += 10
		BICHI 	rstatus, rstatus, #MASK_CARRY	@  then ClearCarry
		ORRLS 	rstatus, rstatus, #MASK_CARRY	@  else SetCarry
		
		AND	    rscratch3,rscratch3,#0x000F0000
		ORR	    rscratch2,rscratch2,rscratch3,LSL #12
		
		LDMFD 	R13!,{rscratch9}
		@ only last bit
		AND 	reg_a,reg_a,#0x80000000
		@  (register.A.W ^ Work8)			
		EORS 	rscratch3, reg_a, rscratch
		BICEQ 	rstatus, rstatus, #MASK_OVERFLOW @  0 : AND mask 11111011111 : set V to zero
		BEQ 	1112f
		@  (register.A.W ^ Ans8)
		EORS 	rscratch3, reg_a, rscratch2
		@  & 0x80 
		TSTNE	rscratch3,#0x80000000
		BICEQ   rstatus, rstatus, #MASK_OVERFLOW @  0 : AND mask 11111011111 : set V to zero		
		ORRNE 	rstatus, rstatus, #MASK_OVERFLOW @  1 : OR mask 00000100000 : set V to one 
1112:
		MOVS 	reg_a, rscratch2
		UPDATE_ZN 		
		B 1113f
1111:
		S9xGetWordLow 
		MOVS rscratch2,rstatus,LSR #MASK_SHIFTER_CARRY
		SBCS reg_a, reg_a, rscratch, LSL #16 
		@ OverFlow 
		ORRVS rstatus, rstatus, #MASK_OVERFLOW
		BICVC rstatus, rstatus, #MASK_OVERFLOW
		MOV reg_a, reg_a, LSR #16
		@ Carry
		UPDATE_C
		MOVS reg_a, reg_a, LSL #16
		@ Update flag
		UPDATE_ZN
1113:
.endm 

.macro SBC8
		TST rstatus, #MASK_DECIMAL 
		BEQ 1111f		
		S9xGetByte					
		STMFD 	R13!,{rscratch}		
		MOV 	rscratch4,#0x0F000000
		@ rscratch2=xxW1xxxxxxxxxxxx
		AND 	rscratch2, rscratch, rscratch4
		@ rscratch=xxW2xxxxxxxxxxxx
		AND 	rscratch, rscratch4, rscratch, LSR #4				
		@ rscratch3=xxA2xxxxxxxxxxxx
		AND 	rscratch3, rscratch4, reg_a, LSR #4
		@ rscratch4=xxA1xxxxxxxxxxxx
		AND 	rscratch4,reg_a,rscratch4		
		@ R1=A1-W1-!CARRY
		TST 	rstatus, #MASK_CARRY
		ADDEQ 	rscratch2, rscratch2, #0x01000000
		SUB 	rscratch2,rscratch4,rscratch2
		@  if R1 > 9
		CMP 	rscratch2, #0x09000000
		@  then R1 += 10
		ADDHI 	rscratch2, rscratch2, #0x0A000000
		@  then A2-- (W2++)
		ADDHI 	rscratch, rscratch, #0x01000000
		@  R2=A2-W2
		SUB 	rscratch3, rscratch3, rscratch
		@  if R2 > 9
		CMP 	rscratch3, #0x09000000
		@  then R2 -= 10@ 
		ADDHI 	rscratch3, rscratch3, #0x0A000000
		@  then SetCarry()
		BICHI 	rstatus, rstatus, #MASK_CARRY @  1 : OR mask 00000100000 : set C to one
		@  else ClearCarry()
		ORRLS 	rstatus, rstatus, #MASK_CARRY @  0 : AND mask 11111011111 : set C to zero
		@  gather rscratch3 and rscratch2 into ans8
		AND	rscratch3,rscratch3,#0x0F000000
		AND	rscratch2,rscratch2,#0x0F000000		
		@  rscratch3 : 0R2000000
		@  rscratch2 : 0R1000000
		@  -> 0xR2R1000000				
		ORR 	rscratch2, rscratch2, rscratch3, LSL #4		
		LDMFD 	R13!,{rscratch}
		@ only last bit
		AND 	reg_a,reg_a,#0x80000000
		@  (register.AL ^ Work8)			
		EORS 	rscratch3, reg_a, rscratch
		BICEQ 	rstatus, rstatus, #MASK_OVERFLOW @  0 : AND mask 11111011111 : set V to zero
		BEQ 	1112f
		@  (register.AL ^ Ans8)
		EORS 	rscratch3, reg_a, rscratch2
		@  & 0x80 
		TSTNE	rscratch3,#0x80000000
		BICEQ rstatus, rstatus, #MASK_OVERFLOW @  0 : AND mask 11111011111 : set V to zero
		ORRNE rstatus, rstatus, #MASK_OVERFLOW @  1 : OR mask 00000100000 : set V to one 
1112:
		MOVS reg_a, rscratch2
		UPDATE_ZN 
		B 1113f
1111:
		S9xGetByteLow
		MOVS rscratch2,rstatus,LSR #MASK_SHIFTER_CARRY
		SBCS reg_a, reg_a, rscratch, LSL #24 
		@ OverFlow 
		ORRVS rstatus, rstatus, #MASK_OVERFLOW
		BICVC rstatus, rstatus, #MASK_OVERFLOW 
		@ Carry
		UPDATE_C 
		@ Update flag
		ANDS reg_a, reg_a, #0xFF000000
		UPDATE_ZN
1113:
.endm 

.macro		STA16
		S9xSetWord	reg_a
.endm
.macro		STA8
		S9xSetByte	reg_a
.endm
.macro		STX16
		S9xSetWord	reg_x
.endm
.macro		STX8
		S9xSetByte	reg_x
.endm
.macro		STY16
		S9xSetWord	reg_y
.endm
.macro		STY8
		S9xSetByte	reg_y
.endm
.macro		STZ16
		S9xSetWordZero
.endm
.macro		STZ8		
		S9xSetByteZero
.endm
.macro		TSB16			
		S9xGetWordRegNS	rscratch2
		TST		reg_a, rscratch2
		BICNE		rstatus, rstatus, #MASK_ZERO	 @  0 : AND mask	11111011111 : set Z to zero
		ORREQ		rstatus, rstatus, #MASK_ZERO	 @  1 : OR  mask	00000100000  : set Z to	one		
		ORR		rscratch2, reg_a, rscratch2		
		S9xSetWord 	rscratch2
		ADD1CYCLE
.endm
.macro		TSB8				
		S9xGetByteRegNS	rscratch2
		TST		reg_a, rscratch2
		BICNE		rstatus, rstatus, #MASK_ZERO	 @  0 : AND mask	11111011111 : set Z to zero
		ORREQ		rstatus, rstatus, #MASK_ZERO	 @  1 : OR  mask	00000100000  : set Z to	one
		ORR		rscratch2, reg_a, rscratch2				
		S9xSetByte 	rscratch2
		ADD1CYCLE
.endm
.macro		TRB16		
		S9xGetWordRegNS	rscratch2
		TST		reg_a, rscratch2
		BICNE		rstatus, rstatus, #MASK_ZERO	 @  0 : AND mask	11111011111 : set Z to zero
		ORREQ		rstatus, rstatus, #MASK_ZERO	 @  1 : OR  mask	00000100000  : set Z to	one
		MVN		rscratch3, reg_a
		AND		rscratch2, rscratch3, rscratch2
		S9xSetWord 	rscratch2
		ADD1CYCLE
.endm
.macro		TRB8				
		S9xGetByteRegNS	rscratch2
		TST		reg_a, rscratch2
		BICNE		rstatus, rstatus, #MASK_ZERO	 @  0 : AND mask	11111011111 : set Z to zero
		ORREQ		rstatus, rstatus, #MASK_ZERO	 @  1 : OR  mask	00000100000  : set Z to	one
		MVN		rscratch3, reg_a
		AND		rscratch2, rscratch3, rscratch2		
		S9xSetByte 	rscratch2
		ADD1CYCLE
.endm
/**************************************************************************/


/**************************************************************************/

.macro		Op09M0		/*ORA*/
		LDRB		rscratch2, [rpc,#1]
		LDRB		rscratch, [rpc], #2
		ORR		rscratch2,rscratch,rscratch2,LSL #8
		ORRS		reg_a,reg_a,rscratch2,LSL #16
		UPDATE_ZN
		ADD2MEM
.endm
.macro		Op09M1		/*ORA*/
		LDRB		rscratch, [rpc], #1
		ORRS		reg_a,reg_a,rscratch,LSL #24
		UPDATE_ZN
		ADD1MEM
.endm
/***********************************************************************/
.macro		Op90 	/*BCC*/
		asmRelative		
		BranchCheck0
		TST		rstatus, #MASK_CARRY
		BNE		1111f
                ADD 		rpc, rscratch, regpcbase @  rpc = OpAddress +PCBase
                ADD1CYCLE
                CPUShutdown
1111:
.endm
.macro		OpB0	/*BCS*/
		asmRelative		
		BranchCheck0
		TST		rstatus, #MASK_CARRY
		BEQ		1111f
                ADD 		rpc, rscratch, regpcbase @  rpc = OpAddress +PCBase
                ADD1CYCLE
                CPUShutdown
1111:
.endm
.macro		OpF0 	/*BEQ*/
		asmRelative		
		BranchCheck2
		TST		rstatus, #MASK_ZERO
		BEQ		1111f
                ADD 		rpc, rscratch, regpcbase @  rpc = OpAddress +PCBase
                ADD1CYCLE
                CPUShutdown
1111:
.endm
.macro		OpD0	/*BNE*/
		asmRelative		
		BranchCheck1
		TST		rstatus, #MASK_ZERO
		BNE		1111f
                ADD 		rpc, rscratch, regpcbase @  rpc = OpAddress +PCBase
                ADD1CYCLE
                CPUShutdown
1111:
.endm
.macro		Op30	/*BMI*/
		asmRelative		
		BranchCheck0
		TST		rstatus, #MASK_NEG
		BEQ		1111f
                ADD 		rpc, rscratch, regpcbase @  rpc = OpAddress +PCBase
                ADD1CYCLE
                CPUShutdown
1111:
.endm
.macro		Op10   /*BPL*/
		asmRelative
		BranchCheck1
		TST 		rstatus, #MASK_NEG @  neg, z!=0, NE
		BNE		1111f
                ADD 		rpc, rscratch, regpcbase @  rpc = OpAddress + PCBase
                ADD1CYCLE
                CPUShutdown
1111:                
.endm
.macro		Op50   /*BVC*/
		asmRelative
		BranchCheck0
		TST 		rstatus, #MASK_OVERFLOW @  neg, z!=0, NE
		BNE		1111f
                ADD 		rpc, rscratch, regpcbase @  rpc = OpAddress + PCBase
                ADD1CYCLE
                CPUShutdown
1111:                
.endm
.macro		Op70   /*BVS*/
		asmRelative
		BranchCheck0
		TST 		rstatus, #MASK_OVERFLOW @  neg, z!=0, NE
		BEQ		1111f
                ADD 		rpc, rscratch, regpcbase @  rpc = OpAddress + PCBase
                ADD1CYCLE
                CPUShutdown
1111:                
.endm
.macro		Op80   /*BRA*/
		asmRelative				
                ADD 		rpc, rscratch, regpcbase @  rpc = OpAddress + PCBase
                ADD1CYCLE
                CPUShutdown
1111:                
.endm
/*******************************************************************************************/
/************************************************************/
/* SetFlag Instructions ********************************************************************** */
.macro		Op38 /*SEC*/		
		ORR		rstatus, rstatus, #MASK_CARRY      @ 	1 : OR	mask 00000100000 : set C to one
		ADD1CYCLE
.endm
.macro		OpF8 /*SED*/		
		SetDecimal
		ADD1CYCLE		
.endm
.macro		Op78 /*SEI*/
		SetIRQ
		ADD1CYCLE
.endm


/****************************************************************************************/
/* ClearFlag Instructions ******************************************************************** */		
.macro		Op18  /*CLC*/		
		BIC 		rstatus, rstatus, #MASK_CARRY
		ADD1CYCLE
.endm
.macro		OpD8 /*CLD*/		
		ClearDecimal
		ADD1CYCLE
.endm
.macro		Op58  /*CLI*/		
		ClearIRQ
		ADD1CYCLE		
		@ CHECK_FOR_IRQ
.endm
.macro		OpB8 /*CLV*/		
		BIC 		rstatus, rstatus, #MASK_OVERFLOW
		ADD1CYCLE     
.endm

/******************************************************************************************/
/* DEX/DEY *********************************************************************************** */

.macro		OpCAX1  /*DEX*/
		MOV		rscratch3,#0
		SUBS 		reg_x, reg_x, #0x01000000
		STR		rscratch3,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		OpCAX0  /*DEX*/		
		MOV		rscratch3,#0
		SUBS 		reg_x, reg_x, #0x00010000
		STR		rscratch3,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		Op88X1 /*DEY*/
		MOV		rscratch3,#0
		SUBS 		reg_y, reg_y, #0x01000000
		STR		rscratch3,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		Op88X0 /*DEY*/
		MOV		rscratch3,#0
		SUBS 		reg_y, reg_y, #0x00010000
		STR		rscratch3,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN
		ADD1CYCLE
.endm

/******************************************************************************************/
/* INX/INY *********************************************************************************** */		
.macro		OpE8X1
		MOV		rscratch3,#0
		ADDS 		reg_x, reg_x, #0x01000000
		STR		rscratch3,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		OpE8X0
		MOV		rscratch3,#0
		ADDS 		reg_x, reg_x, #0x00010000
		STR		rscratch3,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		OpC8X1
		MOV		rscratch3,#0
		ADDS 		reg_y, reg_y, #0x01000000
		STR		rscratch3,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		OpC8X0		
		MOV		rscratch3,#0
		ADDS 		reg_y, reg_y, #0x00010000
		STR		rscratch3,[reg_cpu_var,#WaitAddress_ofs]
		UPDATE_ZN
		ADD1CYCLE
.endm

/**********************************************************************************************/

/* NOP *************************************************************************************** */		
.macro		OpEA		
		ADD1CYCLE
.endm

/**************************************************************************/
/* PUSH Instructions **************************************************** */
.macro		OpF4
		Absolute		
		PushWrLow
.endm
.macro		OpD4
		DirectIndirect		
		PushWrLow
.endm
.macro		Op62
		asmRelativeLong
		PushWrLow
.endm
.macro		Op48M0		
		PushW 		reg_a
		ADD1CYCLE
.endm
.macro		Op48M1		
		PushB 		reg_a
		ADD1CYCLE
.endm
.macro		Op8B
		AND		rscratch2, reg_d_bank, #0xFF
		PushBLow 	rscratch2
		ADD1CYCLE
.endm
.macro		Op0B
		PushW	 	reg_d
		ADD1CYCLE
.endm
.macro		Op4B
		PushBlow	reg_p_bank
		ADD1CYCLE
.endm
.macro		Op08		
		PushB	 	rstatus
		ADD1CYCLE
.endm
.macro		OpDAX1
		PushB 		reg_x
		ADD1CYCLE
.endm
.macro		OpDAX0
		PushW 		reg_x
		ADD1CYCLE
.endm
.macro		Op5AX1		
		PushB 		reg_y
		ADD1CYCLE
.endm
.macro		Op5AX0
		PushW 		reg_y
		ADD1CYCLE
.endm
/**************************************************************************/
/* PULL Instructions **************************************************** */
.macro		Op68M1
		PullBS		reg_a
		UPDATE_ZN
		ADD2CYCLE
.endm
.macro		Op68M0
		PullWS		reg_a
		UPDATE_ZN
		ADD2CYCLE
.endm
.macro		OpAB
		BIC		reg_d_bank,reg_d_bank, #0xFF
		PullBrS 	
		ORR		reg_d_bank,reg_d_bank,rscratch, LSR #24
		UPDATE_ZN
		ADD2CYCLE
.endm
.macro		Op2B		
		BIC		reg_d,reg_d, #0xFF000000
		BIC		reg_d,reg_d, #0x00FF0000
		PullWrS		
		ORR		reg_d,rscratch,reg_d
		UPDATE_ZN
		ADD2CYCLE
.endm
.macro		Op28X1M1	/*PLP*/
		@ INDEX set, MEMORY set
		BIC		rstatus,rstatus,#0xFF000000
		PullBr
		ORR		rstatus,rscratch,rstatus
		TST 		rstatus, #MASK_INDEX		
		@ INDEX clear & was set : 8->16
		MOVEQ		reg_x,reg_x,LSR #8
		MOVEQ		reg_y,reg_y,LSR #8		
		TST 		rstatus, #MASK_MEM		
		@ MEMORY cleared & was set : 8->16
		LDREQB		rscratch,[reg_cpu_var,#RAH_ofs]		
		MOVEQ		reg_a,reg_a,LSR #8
		ORREQ		reg_a,reg_a,rscratch, LSL #24
		S9xFixCycles
		ADD2CYCLE
.endm
.macro		Op28X0M1	/*PLP*/		
		@ INDEX cleared, MEMORY set
		BIC		rstatus,rstatus,#0xFF000000				
		PullBr		
		ORR		rstatus,rscratch,rstatus
		TST 		rstatus, #MASK_INDEX
		@ INDEX set & was cleared : 16->8
		MOVNE		reg_x,reg_x,LSL #8
		MOVNE		reg_y,reg_y,LSL #8
		TST 		rstatus, #MASK_MEM
		@ MEMORY cleared & was set : 8->16
		LDREQB		rscratch,[reg_cpu_var,#RAH_ofs]
		MOVEQ		reg_a,reg_a,LSR #8
		ORREQ		reg_a,reg_a,rscratch, LSL #24
		S9xFixCycles
		ADD2CYCLE
.endm
.macro		Op28X1M0	/*PLP*/
		@ INDEX set, MEMORY set		
		BIC		rstatus,rstatus,#0xFF000000				
		PullBr		
		ORR		rstatus,rscratch,rstatus
		TST 		rstatus, #MASK_INDEX
		@ INDEX clear & was set : 8->16
		MOVEQ		reg_x,reg_x,LSR #8
		MOVEQ		reg_y,reg_y,LSR #8		
		TST 		rstatus, #MASK_MEM
		@ MEMORY set & was cleared : 16->8				
		MOVNE		rscratch,reg_a,LSR #24
		MOVNE		reg_a,reg_a,LSL #8
		STRNEB		rscratch,[reg_cpu_var,#RAH_ofs]
		S9xFixCycles
		ADD2CYCLE
.endm
.macro		Op28X0M0	/*PLP*/
		@ INDEX set, MEMORY set
		BIC		rstatus,rstatus,#0xFF000000
		PullBr
		ORR		rstatus,rscratch,rstatus
		TST 		rstatus, #MASK_INDEX
		@ INDEX set & was cleared : 16->8
		MOVNE		reg_x,reg_x,LSL #8
		MOVNE		reg_y,reg_y,LSL #8
		TST 		rstatus, #MASK_MEM
		@ MEMORY set & was cleared : 16->8				
		MOVNE		rscratch,reg_a,LSR #24
		MOVNE		reg_a,reg_a,LSL #8
		STRNEB		rscratch,[reg_cpu_var,#RAH_ofs]
		S9xFixCycles
		ADD2CYCLE
.endm
.macro		OpFAX1
		PullBS 		reg_x
		UPDATE_ZN
		ADD2CYCLE
.endm
.macro		OpFAX0	
		PullWS 		reg_x
		UPDATE_ZN
		ADD2CYCLE
.endm
.macro		Op7AX1
		PullBS		reg_y
		UPDATE_ZN
		ADD2CYCLE
.endm
.macro		Op7AX0		
		PullWS 		reg_y
		UPDATE_ZN
		ADD2CYCLE
.endm		

/**********************************************************************************************/
/* Transfer Instructions ********************************************************************* */
.macro		OpAAX1M1 /*TAX8*/		
		MOVS 		reg_x, reg_a
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		OpAAX0M1 /*TAX16*/		
		LDRB 		reg_x, [reg_cpu_var,#RAH_ofs]
		MOV		reg_x, reg_x,LSL #24
		ORRS		reg_x, reg_x,reg_a, LSR #8		
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		OpAAX1M0 /*TAX8*/		
		MOVS 		reg_x, reg_a, LSL #8
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		OpAAX0M0 /*TAX16*/		
		MOVS 		reg_x, reg_a
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		OpA8X1M1 /*TAY8*/		
		MOVS 		reg_y, reg_a
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		OpA8X0M1 /*TAY16*/
		LDRB 		reg_y, [reg_cpu_var,#RAH_ofs]
		MOV		reg_y, reg_y,LSL #24
		ORRS		reg_y, reg_y,reg_a, LSR #8		
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		OpA8X1M0 /*TAY8*/		
		MOVS 		reg_y, reg_a, LSL #8
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		OpA8X0M0 /*TAY16*/
		MOVS 		reg_y, reg_a
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		Op5BM1		
		LDRB		rscratch, [reg_cpu_var,#RAH_ofs]
		MOV		reg_d,reg_d,LSL #16
		MOV		rscratch,rscratch,LSL #24
		ORRS		rscratch,rscratch,reg_a, LSR #8		
		UPDATE_ZN
		ORR  		reg_d,rscratch,reg_d,LSR #16
		ADD1CYCLE
.endm
.macro		Op5BM0		
		MOV		reg_d,reg_d,LSL #16		
		MOVS		reg_a,reg_a
		UPDATE_ZN
		ORR  		reg_d,reg_a,reg_d,LSR #16
		ADD1CYCLE
.endm
.macro		Op1BM1
		TST 		rstatus, #MASK_EMUL
		MOVNE		reg_s, reg_a, LSR #24
		ORRNE		reg_s, reg_s, #0x100		
		LDREQB		reg_s, [reg_cpu_var,#RAH_ofs]
		ORREQ		reg_s, reg_s, reg_a
		MOVEQ		reg_s, reg_s, ROR #24
		ADD1CYCLE
.endm
.macro		Op1BM0		
		MOV 		reg_s, reg_a, LSR #16
		ADD1CYCLE
.endm
.macro		Op7BM1		
		MOVS 		reg_a, reg_d, ASR #16		
		UPDATE_ZN
		MOV		rscratch,reg_a,LSR #8		
		MOV		reg_a,reg_a, LSL #24
		STRB		rscratch, [reg_cpu_var,#RAH_ofs]
		ADD1CYCLE
.endm
.macro		Op7BM0
		MOVS 		reg_a, reg_d, ASR #16		
		UPDATE_ZN
		MOV		reg_a,reg_a, LSL #16
		ADD1CYCLE
.endm
.macro		Op3BM1
		MOV		rscratch,reg_s, LSR #8
		MOVS		reg_a, reg_s, LSL #16
		STRB		rscratch, [reg_cpu_var,#RAH_ofs]
		UPDATE_ZN
		MOV		reg_a,reg_a, LSL #8
		ADD1CYCLE
.endm
.macro		Op3BM0
		MOVS		reg_a, reg_s, LSL #16
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		OpBAX1
		MOVS 		reg_x, reg_s, LSL #24
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		OpBAX0
		MOVS 		reg_x, reg_s, LSL #16
		UPDATE_ZN
		ADD1CYCLE
.endm		
.macro		Op8AM1X1
		MOVS 		reg_a, reg_x
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		Op8AM1X0
		MOVS 		reg_a, reg_x, LSL #8
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		Op8AM0X1
		MOVS 		reg_a, reg_x, LSR #8
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		Op8AM0X0
		MOVS 		reg_a, reg_x
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		Op9AX1		
		MOV 		reg_s, reg_x, LSR #24
		TST 		rstatus, #MASK_EMUL		
		ORRNE		reg_s, reg_s, #0x100
		ADD1CYCLE
.endm
.macro		Op9AX0		
		MOV 		reg_s, reg_x, LSR #16
		ADD1CYCLE
.endm
.macro		Op9BX1		
		MOVS 		reg_y, reg_x
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		Op9BX0		
		MOVS 		reg_y, reg_x
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		Op98M1X1	
		MOVS 		reg_a, reg_y
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		Op98M1X0
		MOVS 		reg_a, reg_y, LSL #8
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		Op98M0X1
		MOVS 		reg_a, reg_y, LSR #8
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		Op98M0X0
		MOVS 		reg_a, reg_y
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		OpBBX1		
		MOVS 		reg_x, reg_y
		UPDATE_ZN
		ADD1CYCLE
.endm
.macro		OpBBX0
		MOVS 		reg_x, reg_y
		UPDATE_ZN
		ADD1CYCLE
.endm

/**********************************************************************************************/
/* XCE *************************************************************************************** */

.macro		OpFB
    TST		rstatus,#MASK_CARRY
    BEQ		1111f
    @ CARRY is set
    TST		rstatus,#MASK_EMUL    
    BNE		1112f
    @ EMUL is cleared
    BIC		rstatus,rstatus,#(MASK_CARRY)
    TST		rstatus,#MASK_INDEX
    @ X & Y were 16bits before
    MOVEQ	reg_x,reg_x,LSL #8
    MOVEQ	reg_y,reg_y,LSL #8
    TST		rstatus,#MASK_MEM
    @ A was 16bits before
    @ save AH
    MOVEQ	rscratch,reg_a,LSR #24
    STREQB	rscratch,[reg_cpu_var,#RAH_ofs]
    MOVEQ	reg_a,reg_a,LSL #8
    ORR		rstatus,rstatus,#(MASK_EMUL|MASK_MEM|MASK_INDEX)
    AND		reg_s,reg_s,#0xFF
    ORR		reg_s,reg_s,#0x100    
    B		1113f    
1112:    
    @ EMUL is set
    TST		rstatus,#MASK_INDEX
    @ X & Y were 16bits before
    MOVEQ	reg_x,reg_x,LSL #8
    MOVEQ	reg_y,reg_y,LSL #8
    TST		rstatus,#MASK_MEM
    @ A was 16bits before
    @ save AH
    MOVEQ	rscratch,reg_a,LSR #24
    STREQB	rscratch,[reg_cpu_var,#RAH_ofs]
    MOVEQ	reg_a,reg_a,LSL #8
    ORR		rstatus,rstatus,#(MASK_CARRY|MASK_MEM|MASK_INDEX)
    AND		reg_s,reg_s,#0xFF
    ORR		reg_s,reg_s,#0x100    
    B		1113f
1111:    
    @ CARRY is cleared
    TST		rstatus,#MASK_EMUL
    BEQ		1115f
    @ EMUL was set : X,Y & A were 8bits
    @ Now have to check MEMORY & INDEX for potential conversions to 16bits
    TST		rstatus,#MASK_INDEX
    @  X & Y are now 16bits
    MOVEQ	reg_x,reg_x,LSR #8	
    MOVEQ	reg_y,reg_y,LSR #8	
    TST		rstatus,#MASK_MEM
    @  A is now 16bits
    MOVEQ	reg_a,reg_a,LSR #8	
    @ restore AH
    LDREQB	rscratch,[reg_cpu_var,#RAH_ofs]    
    ORREQ	reg_a,reg_a,rscratch,LSL #24
1115:    
    BIC		rstatus,rstatus,#(MASK_EMUL)
    ORR		rstatus,rstatus,#(MASK_CARRY)
1113:
    ADD1CYCLE
    S9xFixCycles
.endm

/*******************************************************************************/
/* BRK *************************************************************************/
.macro		Op00		/*BRK*/
		MOV		rscratch,#1
		STRB		rscratch,[reg_cpu_var,#BRKTriggered_ofs]
		
		TST 		rstatus, #MASK_EMUL
		@  EQ is flag to zero (!CheckEmu)
		BNE 		2001f@ elseOp00
		PushBLow	reg_p_bank
		SUB 		rscratch, rpc, regpcbase
		ADD 		rscratch2, rscratch, #1
		PushWLow 	rscratch2
		@  PackStatus
		PushB	 	rstatus
		ClearDecimal
		SetIRQ
		BIC 		reg_p_bank, reg_p_bank, #0xFF
		MOV 		rscratch, #0xE6
		ORR 		rscratch, rscratch, #0xFF00
		S9xGetWordLow 		
		S9xSetPCBase 	
		ADD2CYCLE
		B 		2002f@ endOp00
2001:@ elseOp00
		SUB 		rscratch2, rpc, regpcbase
		PushWLow 	rscratch2
		@  PackStatus
		PushB	 	rstatus
		ClearDecimal
		SetIRQ
		BIC		reg_p_bank,reg_p_bank, #0xFF
		MOV 		rscratch, #0xFE
		ORR 		rscratch, rscratch, #0xFF00
		S9xGetWordLow 		
		S9xSetPCBase 	
		ADD1CYCLE
2002:@ endOp00
.endm


/**********************************************************************************************/
/* BRL ************************************************************************************** */
.macro		Op82	/*BRL*/
		asmRelativeLong
		ORR		rscratch, rscratch, reg_p_bank, LSL #16
		S9xSetPCBase
.endm		
/**********************************************************************************************/
/* IRQ *************************************************************************************** */			
@ void S9xOpcode_IRQ (void)		
.macro		S9xOpcode_IRQ	@ IRQ
		TST 		rstatus, #MASK_EMUL
		@  EQ is flag to zero (!CheckEmu)
		BNE 		2121f@ elseOp02
		PushBLow 	reg_p_bank
		SUB 		rscratch2, rpc, regpcbase
		PushWLow 	rscratch2
		@  PackStatus
		PushB	 	rstatus
		ClearDecimal
		SetIRQ
		BIC 		reg_p_bank, reg_p_bank,#0xFF
		MOV 		rscratch, #0xEE
		ORR 		rscratch, rscratch, #0xFF00
		S9xGetWordLow 		
		S9xSetPCBase 	
		ADD2CYCLE
		B 2122f
2121:@ else
		SUB 		rscratch2, rpc, regpcbase
		PushWLow 	rscratch2
		@  PackStatus
		PushB	 	rstatus
		ClearDecimal
		SetIRQ
		BIC 		reg_p_bank,reg_p_bank, #0xFF
		MOV 		rscratch, #0xFE
		ORR 		rscratch, rscratch, #0xFF00
		S9xGetWordLow 		
		S9xSetPCBase 	
		ADD1CYCLE
2122:
.endm

/*
void asm_S9xOpcode_IRQ(void)
{
    if (!CheckEmulation())
    {
        PushB (Registers.PB);
        PushW (CPU.PC - CPU.PCBase);
        PushB (Registers.PL);
        ClearDecimal ();
        SetIRQ ();

        Registers.PB = 0;
		S9xSetPCBase (S9xGetWord (0xFFEE));
        CPU.Cycles += TWO_CYCLES;
    }
    else
    {
        PushW (CPU.PC - CPU.PCBase);
        PushB (Registers.PL);
        ClearDecimal ();
        SetIRQ ();

        Registers.PB = 0;
        S9xSetPCBase (S9xGetWord (0xFFFE));
        CPU.Cycles += ONE_CYCLE;
    }
}
*/	
		
/**********************************************************************************************/
/* NMI *************************************************************************************** */		
@ void S9xOpcode_NMI (void)
.macro		S9xOpcode_NMI	@ NMI
		TST 		rstatus, #MASK_EMUL
		@  EQ is flag to zero (!CheckEmu)
		BNE 		2123f@ elseOp02
		PushBLow 	reg_p_bank
		SUB 		rscratch2, rpc, regpcbase
		PushWLow 	rscratch2
		@  PackStatus
		PushB	 	rstatus
		ClearDecimal
		SetIRQ
		BIC 		reg_p_bank, reg_p_bank,#0xFF
		MOV 		rscratch, #0xEA
		ORR 		rscratch, rscratch, #0xFF00
		S9xGetWordLow 		
		S9xSetPCBase 	
		ADD2CYCLE
		B 2124f
2123:@ else
		SUB 		rscratch2, rpc, regpcbase
		PushWLow 	rscratch2
		@  PackStatus
		PushB	 	rstatus
		ClearDecimal
		SetIRQ
		BIC 		reg_p_bank,reg_p_bank, #0xFF
		MOV 		rscratch, #0xFA
		ORR 		rscratch, rscratch, #0xFF00
		S9xGetWordLow 		
		S9xSetPCBase 	
		ADD1CYCLE
2124:
.endm
/*
void asm_S9xOpcode_NMI(void)
{	
	if (!CheckEmulation())
    {
        PushB (Registers.PB);
        PushW (CPU.PC - CPU.PCBase);
        PushB (Registers.PL);
        ClearDecimal ();
        SetIRQ ();

        Registers.PB = 0;
        S9xSetPCBase (S9xGetWord (0xFFEA));
        CPU.Cycles += TWO_CYCLES;
    }
    else
    {
        PushW (CPU.PC - CPU.PCBase);
        PushB (Registers.PL);
        ClearDecimal ();
        SetIRQ ();

        Registers.PB = 0;
        S9xSetPCBase (S9xGetWord (0xFFFA));
        CPU.Cycles += ONE_CYCLE;
    }    
}
*/

/**********************************************************************************************/
/* COP *************************************************************************************** */
.macro		Op02		/*COP*/
		TST 		rstatus, #MASK_EMUL
		@  EQ is flag to zero (!CheckEmu)
		BNE 		2021f@ elseOp02
		PushBLow 	reg_p_bank
		SUB 		rscratch, rpc, regpcbase
		ADD 		rscratch2, rscratch, #1
		PushWLow 	rscratch2
		@  PackStatus
		PushB	 	rstatus
		ClearDecimal
		SetIRQ
		BIC 		reg_p_bank, reg_p_bank,#0xFF
		MOV 		rscratch, #0xE4
		ORR 		rscratch, rscratch, #0xFF00
		S9xGetWordLow 		
		S9xSetPCBase 	
		ADD2CYCLE
		B 2022f@ endOp02
2021:@ elseOp02
		SUB 		rscratch2, rpc, regpcbase
		PushWLow 	rscratch2
		@  PackStatus
		PushB	 	rstatus
		ClearDecimal
		SetIRQ
		BIC 		reg_p_bank,reg_p_bank, #0xFF
		MOV 		rscratch, #0xF4
		ORR 		rscratch, rscratch, #0xFF00
		S9xGetWordLow 		
		S9xSetPCBase 	
		ADD1CYCLE
2022:@ endOp02
.endm

/**********************************************************************************************/
/* JML *************************************************************************************** */
.macro		OpDC		
		AbsoluteIndirectLong		
		BIC		reg_p_bank,reg_p_bank,#0xFF
		ORR 		reg_p_bank,reg_p_bank, rscratch, LSR #16
		S9xSetPCBase 	
		ADD2CYCLE
.endm
.macro		Op5C		
		AbsoluteLong		
		BIC		reg_p_bank,reg_p_bank,#0xFF
		ORR 		reg_p_bank,reg_p_bank, rscratch, LSR #16
		S9xSetPCBase 	
.endm

/**********************************************************************************************/
/* JMP *************************************************************************************** */
.macro		Op4C
		Absolute
		BIC		rscratch, rscratch, #0xFF0000
		ORR		rscratch, rscratch, reg_p_bank, LSL #16
		S9xSetPCBase
		CPUShutdown
.endm		
.macro		Op6C
		AbsoluteIndirect
		BIC		rscratch, rscratch, #0xFF0000
		ORR		rscratch, rscratch, reg_p_bank, LSL #16
		S9xSetPCBase		
.endm		
.macro		Op7C						
		ADD 		rscratch, rscratch, reg_p_bank, LSL #16
		S9xSetPCBase 	
		ADD1CYCLE
.endm

/**********************************************************************************************/
/* JSL/RTL *********************************************************************************** */
.macro		Op22				
		PushBlow	reg_p_bank
		SUB 		rscratch, rpc, regpcbase
		@ SUB 		rscratch2, rscratch2, #1
		ADD 		rscratch2, rscratch, #2
		PushWlow	rscratch2
		AbsoluteLong		
		BIC		reg_p_bank,reg_p_bank,#0xFF
		ORR 		reg_p_bank, reg_p_bank, rscratch, LSR #16
		S9xSetPCBase 	
.endm
.macro		Op6B		
		PullWLow 	rpc		
		BIC		reg_p_bank,reg_p_bank,#0xFF
		PullBrLow 			
		ORR 		reg_p_bank, reg_p_bank, rscratch
		ADD 		rscratch, rpc, #1
		BIC		rscratch, rscratch,#0xFF0000
		ORR		rscratch, rscratch, reg_p_bank, LSL #16
		S9xSetPCBase
		ADD2CYCLE
.endm
/**********************************************************************************************/
/* JSR/RTS *********************************************************************************** */
.macro		Op20				
		SUB 		rscratch, rpc, regpcbase
		@ SUB 		rscratch2, rscratch2, #1
		ADD 		rscratch2, rscratch, #1		
		PushWlow	rscratch2				
		Absolute		
		BIC		rscratch, rscratch, #0xFF0000		
		ORR 		rscratch, rscratch, reg_p_bank, LSL #16
		S9xSetPCBase 
		ADD1CYCLE
.endm
.macro		OpFCX0
		SUB 		rscratch, rpc, regpcbase
		@ SUB 		rscratch2, rscratch2, #1
		ADD		rscratch2, rscratch, #1
		PushWlow	rscratch2
		AbsoluteIndexedIndirectX0
		ORR 		rscratch, rscratch, reg_p_bank, LSL #16
		S9xSetPCBase
		ADD1CYCLE
.endm
.macro		OpFCX1
		SUB 		rscratch, rpc, regpcbase
		@ SUB 		rscratch2, rscratch2, #1
		ADD		rscratch2, rscratch, #1		
		PushWlow	rscratch2	
		AbsoluteIndexedIndirectX1
		ORR 		rscratch, rscratch, reg_p_bank, LSL #16
		S9xSetPCBase 
		ADD1CYCLE
.endm
.macro		Op60			
		PullWLow 	rpc
		ADD 		rscratch, rpc, #1		
		BIC		rscratch, rscratch,#0x10000		
		ORR		rscratch, rscratch, reg_p_bank, LSL #16		
		S9xSetPCBase 
		ADD3CYCLE
.endm

/**********************************************************************************************/
/* MVN/MVP *********************************************************************************** */		
.macro		Op54X1M1
		@ Save RegStatus = reg_d_bank >> 24
		MOV		rscratch, reg_d_bank, LSR #16
                LDRB		reg_d_bank    , [rpc], #1
		LDRB		rscratch2    , [rpc], #1
		@ Restore RegStatus = reg_d_bank >> 24
		ORR		reg_d_bank, reg_d_bank, rscratch, LSL #16
		MOV		rscratch    , reg_x, LSR #24		
                ORR		rscratch    , rscratch, rscratch2, LSL #16                
		S9xGetByteLow 
		MOV		rscratch2, rscratch
		MOV		rscratch   , reg_y, LSR #24
		ORR		rscratch   , rscratch, reg_d_bank, LSL #16		
		S9xSetByteLow 	rscratch2	
		@ load 16bits A		
		LDRB		rscratch,[reg_cpu_var,#RAH_ofs]
		MOV		reg_a,reg_a,LSR #8
		ORR		reg_a,reg_a,rscratch, LSL #24
		ADD		reg_x, reg_x, #0x01000000
		SUB		reg_a, reg_a, #0x00010000
		ADD		reg_y, reg_y, #0x01000000				
                CMP		reg_a, #0xFFFF0000
                SUBNE		rpc, rpc, #3
                @ update AH
                MOV		rscratch, reg_a, LSR #24
                MOV		reg_a,reg_a,LSL #8
                STRB		rscratch,[reg_cpu_var,#RAH_ofs]                
                ADD2CYCLE2MEM
.endm
.macro		Op54X1M0
		@ Save RegStatus = reg_d_bank >> 24
		MOV		rscratch, reg_d_bank, LSR #16
                LDRB		reg_d_bank    , [rpc], #1
		LDRB		rscratch2    , [rpc], #1
		@ Restore RegStatus = reg_d_bank >> 24
		ORR		reg_d_bank, reg_d_bank, rscratch, LSL #16
		MOV		rscratch    , reg_x, LSR #24		
                ORR		rscratch    , rscratch, rscratch2, LSL #16                
		S9xGetByteLow 
		MOV		rscratch2, rscratch
		MOV		rscratch   , reg_y, LSR #24
		ORR		rscratch   , rscratch, reg_d_bank, LSL #16		
		S9xSetByteLow 	rscratch2		
		ADD		reg_x, reg_x, #0x01000000
		SUB		reg_a, reg_a, #0x00010000
		ADD		reg_y, reg_y, #0x01000000				
                CMP		reg_a, #0xFFFF0000
                SUBNE		rpc, rpc, #3
                ADD2CYCLE2MEM
.endm
.macro		Op54X0M1
		@ Save RegStatus = reg_d_bank >> 24
		MOV		rscratch, reg_d_bank, LSR #16
                LDRB		reg_d_bank    , [rpc], #1
		LDRB		rscratch2    , [rpc], #1
		@ Restore RegStatus = reg_d_bank >> 24
		ORR		reg_d_bank, reg_d_bank, rscratch, LSL #16
		MOV		rscratch    , reg_x, LSR #16
                ORR		rscratch    , rscratch, rscratch2, LSL #16                
		S9xGetByteLow 
		MOV		rscratch2, rscratch
		MOV		rscratch   , reg_y, LSR #16
		ORR		rscratch   , rscratch, reg_d_bank, LSL #16		
		S9xSetByteLow 	rscratch2		
		@ load 16bits A		
		LDRB		rscratch,[reg_cpu_var,#RAH_ofs]
		MOV		reg_a,reg_a,LSR #8
		ORR		reg_a,reg_a,rscratch, LSL #24
		ADD		reg_x, reg_x, #0x00010000
		SUB		reg_a, reg_a, #0x00010000
		ADD		reg_y, reg_y, #0x00010000				
                CMP		reg_a, #0xFFFF0000
                SUBNE		rpc, rpc, #3                
                @ update AH
                MOV		rscratch, reg_a, LSR #24
                MOV		reg_a,reg_a,LSL #8
                STRB		rscratch,[reg_cpu_var,#RAH_ofs]                
                ADD2CYCLE2MEM
.endm
.macro		Op54X0M0
		@ Save RegStatus = reg_d_bank >> 24
		MOV		rscratch, reg_d_bank, LSR #16
                LDRB		reg_d_bank    , [rpc], #1
		LDRB		rscratch2    , [rpc], #1
		@ Restore RegStatus = reg_d_bank >> 24
		ORR		reg_d_bank, reg_d_bank, rscratch, LSL #16
		MOV		rscratch    , reg_x, LSR #16
                ORR		rscratch    , rscratch, rscratch2, LSL #16                
		S9xGetByteLow 
		MOV		rscratch2, rscratch
		MOV		rscratch   , reg_y, LSR #16
		ORR		rscratch   , rscratch, reg_d_bank, LSL #16		
		S9xSetByteLow 	rscratch2		
		ADD		reg_x, reg_x, #0x00010000
		SUB		reg_a, reg_a, #0x00010000
		ADD		reg_y, reg_y, #0x00010000				
                CMP		reg_a, #0xFFFF0000
                SUBNE		rpc, rpc, #3
                ADD2CYCLE2MEM
.endm

.macro		Op44X1M1
		@ Save RegStatus = reg_d_bank >> 24
		MOV		rscratch, reg_d_bank, LSR #16
                LDRB		reg_d_bank    , [rpc], #1
		LDRB		rscratch2    , [rpc], #1
		@ Restore RegStatus = reg_d_bank >> 24
		ORR		reg_d_bank, reg_d_bank, rscratch, LSL #16
		MOV		rscratch    , reg_x, LSR #24		
                ORR		rscratch    , rscratch, rscratch2, LSL #16                
		S9xGetByteLow 
		MOV		rscratch2, rscratch
		MOV		rscratch   , reg_y, LSR #24
		ORR		rscratch   , rscratch, reg_d_bank, LSL #16		
		S9xSetByteLow 	rscratch2
		@ load 16bits A		
		LDRB		rscratch,[reg_cpu_var,#RAH_ofs]
		MOV		reg_a,reg_a,LSR #8
		ORR		reg_a,reg_a,rscratch, LSL #24
		SUB		reg_x, reg_x, #0x01000000
		SUB		reg_a, reg_a, #0x00010000
		SUB		reg_y, reg_y, #0x01000000				
                CMP		reg_a, #0xFFFF0000
                SUBNE		rpc, rpc, #3
                @ update AH
                MOV		rscratch, reg_a, LSR #24
                MOV		reg_a,reg_a,LSL #8
                STRB		rscratch,[reg_cpu_var,#RAH_ofs]                
                ADD2CYCLE2MEM
.endm
.macro		Op44X1M0
		@ Save RegStatus = reg_d_bank >> 24
		MOV		rscratch, reg_d_bank, LSR #16
                LDRB		reg_d_bank    , [rpc], #1
		LDRB		rscratch2    , [rpc], #1
		@ Restore RegStatus = reg_d_bank >> 24
		ORR		reg_d_bank, reg_d_bank, rscratch, LSL #16
		MOV		rscratch    , reg_x, LSR #24		
                ORR		rscratch    , rscratch, rscratch2, LSL #16                
		S9xGetByteLow 
		MOV		rscratch2, rscratch
		MOV		rscratch   , reg_y, LSR #24
		ORR		rscratch   , rscratch, reg_d_bank, LSL #16		
		S9xSetByteLow 	rscratch2		
		SUB		reg_x, reg_x, #0x01000000
		SUB		reg_a, reg_a, #0x00010000
		SUB		reg_y, reg_y, #0x01000000				
                CMP		reg_a, #0xFFFF0000
                SUBNE		rpc, rpc, #3
                ADD2CYCLE2MEM
.endm
.macro		Op44X0M1
		@ Save RegStatus = reg_d_bank >> 24
		MOV		rscratch, reg_d_bank, LSR #16
                LDRB		reg_d_bank    , [rpc], #1
		LDRB		rscratch2    , [rpc], #1
		@ Restore RegStatus = reg_d_bank >> 24
		ORR		reg_d_bank, reg_d_bank, rscratch, LSL #16
		MOV		rscratch    , reg_x, LSR #16
                ORR		rscratch    , rscratch, rscratch2, LSL #16                
		S9xGetByteLow 
		MOV		rscratch2, rscratch
		MOV		rscratch   , reg_y, LSR #16
		ORR		rscratch   , rscratch, reg_d_bank, LSL #16		
		S9xSetByteLow 	rscratch2
		@ load 16bits A		
		LDRB		rscratch,[reg_cpu_var,#RAH_ofs]
		MOV		reg_a,reg_a,LSR #8
		ORR		reg_a,reg_a,rscratch, LSL #24
		SUB		reg_x, reg_x, #0x00010000
		SUB		reg_a, reg_a, #0x00010000
		SUB		reg_y, reg_y, #0x00010000				
                CMP		reg_a, #0xFFFF0000
                SUBNE		rpc, rpc, #3
                @ update AH
                MOV		rscratch, reg_a, LSR #24
                MOV		reg_a,reg_a,LSL #8
                STRB		rscratch,[reg_cpu_var,#RAH_ofs]                
                ADD2CYCLE2MEM
.endm
.macro		Op44X0M0
		@ Save RegStatus = reg_d_bank >> 24
		MOV		rscratch, reg_d_bank, LSR #16
                LDRB		reg_d_bank    , [rpc], #1
		LDRB		rscratch2    , [rpc], #1
		@ Restore RegStatus = reg_d_bank >> 24
		ORR		reg_d_bank, reg_d_bank, rscratch, LSL #16
		MOV		rscratch    , reg_x, LSR #16
                ORR		rscratch    , rscratch, rscratch2, LSL #16                
		S9xGetByteLow 
		MOV		rscratch2, rscratch
		MOV		rscratch   , reg_y, LSR #16
		ORR		rscratch   , rscratch, reg_d_bank, LSL #16		
		S9xSetByteLow 	rscratch2		
		SUB		reg_x, reg_x, #0x00010000
		SUB		reg_a, reg_a, #0x00010000
		SUB		reg_y, reg_y, #0x00010000				
                CMP		reg_a, #0xFFFF0000
                SUBNE		rpc, rpc, #3
                ADD2CYCLE2MEM
.endm

/**********************************************************************************************/
/* REP/SEP *********************************************************************************** */
.macro		OpC2
		@  status&=~(*rpc++);
		@  so possible changes are :		
		@  INDEX = 1 -> 0  : X,Y 8bits -> 16bits
		@  MEM = 1 -> 0 : A 8bits -> 16bits
		@ SAVE OLD status for MASK_INDEX & MASK_MEM comparison
		MOV		rscratch3, rstatus
		LDRB		rscratch, [rpc], #1
		MVN		rscratch, rscratch		
		AND		rstatus,rstatus,rscratch, ROR #(32-STATUS_SHIFTER)
		TST		rstatus,#MASK_EMUL
		BEQ		1111f
		@ emulation mode on : no changes since it was on before opcode
		@ just be sure to reset MEM & INDEX accordingly
		ORR		rstatus,rstatus,#(MASK_MEM|MASK_INDEX)		
		B		1112f
1111:		
		@ NOT in Emulation mode, check INDEX & MEMORY bits
		@ Now check INDEX
		TST		rscratch3,#MASK_INDEX
		BEQ		1113f		
		@  X & Y were 8bit before
		TST		rstatus,#MASK_INDEX
		BNE		1113f
		@  X & Y are now 16bits
		MOV		reg_x,reg_x,LSR #8
		MOV		reg_y,reg_y,LSR #8
1113:		@ X & Y still in 16bits
		@ Now check MEMORY
		TST		rscratch3,#MASK_MEM
		BEQ		1112f		
		@  A was 8bit before
		TST		rstatus,#MASK_MEM
		BNE		1112f
		@  A is now 16bits
		MOV		reg_a,reg_a,LSR #8		
		@ restore AH
    		LDREQB		rscratch,[reg_cpu_var,#RAH_ofs]    		
    		ORREQ		reg_a,reg_a,rscratch,LSL #24
1112:
		S9xFixCycles
		ADD1CYCLE1MEM
.endm
.macro		OpE2
		@  status|=*rpc++;
		@  so possible changes are :
		@  INDEX = 0 -> 1  : X,Y 16bits -> 8bits
		@  MEM = 0 -> 1 : A 16bits -> 8bits
		@ SAVE OLD status for MASK_INDEX & MASK_MEM comparison
		MOV		rscratch3, rstatus
		LDRB		rscratch, [rpc], #1		
		ORR		rstatus,rstatus,rscratch, LSL #STATUS_SHIFTER
		TST		rstatus,#MASK_EMUL
		BEQ		10111f
		@ emulation mode on : no changes sinc eit was on before opcode
		@ just be sure to have mem & index set accordingly
		ORR		rstatus,rstatus,#(MASK_MEM|MASK_INDEX)		
		B		10112f
10111:		
		@ NOT in Emulation mode, check INDEX & MEMORY bits
		@ Now check INDEX
		TST		rscratch3,#MASK_INDEX
		BNE		10113f		
		@  X & Y were 16bit before
		TST		rstatus,#MASK_INDEX
		BEQ		10113f
		@  X & Y are now 8bits
		MOV		reg_x,reg_x,LSL #8
		MOV		reg_y,reg_y,LSL #8
10113:		@ X & Y still in 16bits
		@ Now check MEMORY
		TST		rscratch3,#MASK_MEM
		BNE		10112f		
		@  A was 16bit before
		TST		rstatus,#MASK_MEM
		BEQ		10112f
		@  A is now 8bits
		@  save AH
		MOV		rscratch,reg_a,LSR #24
		MOV		reg_a,reg_a,LSL #8	
		STRB		rscratch,[reg_cpu_var,#RAH_ofs]	
10112:
		S9xFixCycles
		ADD1CYCLE1MEM
.endm

/**********************************************************************************************/
/* XBA *************************************************************************************** */
.macro		OpEBM1		
		@ A is 8bits
		ADD		rscratch,reg_cpu_var,#RAH_ofs
		MOV		reg_a,reg_a, LSR #24
		SWPB		reg_a,reg_a,[rscratch]
		MOVS		reg_a,reg_a, LSL #24
		UPDATE_ZN
		ADD2CYCLE
.endm
.macro		OpEBM0		
		@ A is 16bits
		MOV 		rscratch, reg_a, ROR #24 @  ll0000hh
		ORR 		rscratch, rscratch, reg_a, LSR #8@  ll0000hh + 00hhll00 -> llhhllhh
		MOV 		reg_a, rscratch, LSL #16@  llhhllhh -> llhh0000		
		MOVS		rscratch,rscratch,LSL #24 @ to set Z & N flags with AL		
		UPDATE_ZN
		ADD2CYCLE
.endm


/**********************************************************************************************/
/* RTI *************************************************************************************** */
.macro		Op40X1M1
		@ INDEX set, MEMORY set		
		BIC		rstatus,rstatus,#0xFF000000
		PullBr
		ORR		rstatus,rscratch,rstatus
		PullWlow	rpc
		TST 		rstatus, #MASK_EMUL
		ORRNE		rstatus, rstatus, #(MASK_MEM|MASK_INDEX)
                BNE		2401f
		PullBrLow
		BIC		reg_p_bank,reg_p_bank,#0xFF
		ORR		reg_p_bank,reg_p_bank,rscratch
2401:		
		ADD 		rscratch, rpc, reg_p_bank, LSL #16
		S9xSetPCBase
		TST 		rstatus, #MASK_INDEX		
		@ INDEX cleared & was set : 8->16
		MOVEQ		reg_x,reg_x,LSR #8
		MOVEQ		reg_y,reg_y,LSR #8
		TST 		rstatus, #MASK_MEM		
		@ MEMORY cleared & was set : 8->16
		LDREQB		rscratch,[reg_cpu_var,#RAH_ofs]		
		MOVEQ		reg_a,reg_a,LSR #8		
		ORREQ		reg_a,reg_a,rscratch, LSL #24		
		ADD2CYCLE
		S9xFixCycles
.endm
.macro		Op40X0M1
		@ INDEX cleared, MEMORY set		
		BIC		rstatus,rstatus,#0xFF000000
		PullBr
		ORR		rstatus,rscratch,rstatus
		PullWlow	rpc
		TST 		rstatus, #MASK_EMUL
		ORRNE		rstatus, rstatus, #(MASK_MEM|MASK_INDEX)
                BNE		2401f
		PullBrLow
		BIC		reg_p_bank,reg_p_bank,#0xFF
		ORR		reg_p_bank,reg_p_bank,rscratch
2401:		
		ADD 		rscratch, rpc, reg_p_bank, LSL #16
		S9xSetPCBase		
		TST 		rstatus, #MASK_INDEX		
		@ INDEX set & was cleared : 16->8
		MOVNE		reg_x,reg_x,LSL #8
		MOVNE		reg_y,reg_y,LSL #8		
		TST 		rstatus, #MASK_MEM		
		@ MEMORY cleared & was set : 8->16
		LDREQB		rscratch,[reg_cpu_var,#RAH_ofs]		
		MOVEQ		reg_a,reg_a,LSR #8		
		ORREQ		reg_a,reg_a,rscratch, LSL #24
		ADD2CYCLE
		S9xFixCycles
.endm
.macro		Op40X1M0
		@ INDEX set, MEMORY cleared
		BIC		rstatus,rstatus,#0xFF000000
		PullBr
		ORR		rstatus,rscratch,rstatus
		PullWlow	rpc
		TST 		rstatus, #MASK_EMUL
		ORRNE		rstatus, rstatus, #(MASK_MEM|MASK_INDEX)
                BNE		2401f
		PullBrLow
		BIC		reg_p_bank,reg_p_bank,#0xFF
		ORR		reg_p_bank,reg_p_bank,rscratch
2401:		
		ADD 		rscratch, rpc, reg_p_bank, LSL #16
		S9xSetPCBase
		TST 		rstatus, #MASK_INDEX		
		@ INDEX cleared & was set : 8->16
		MOVEQ		reg_x,reg_x,LSR #8
		MOVEQ		reg_y,reg_y,LSR #8		
		TST 		rstatus, #MASK_MEM		
		@ MEMORY set & was cleared : 16->8
		MOVNE		rscratch,reg_a,LSR #24
		MOVNE		reg_a,reg_a,LSL #8
		STRNEB		rscratch,[reg_cpu_var,#RAH_ofs]
		ADD2CYCLE
		S9xFixCycles
.endm
.macro		Op40X0M0
		@ INDEX cleared, MEMORY cleared
		BIC		rstatus,rstatus,#0xFF000000
		PullBr
		ORR		rstatus,rscratch,rstatus
		PullWlow	rpc
		TST 		rstatus, #MASK_EMUL
		ORRNE		rstatus, rstatus, #(MASK_MEM|MASK_INDEX)
                BNE		2401f
		PullBrLow
		BIC		reg_p_bank,reg_p_bank,#0xFF
		ORR		reg_p_bank,reg_p_bank,rscratch
2401:		
		ADD 		rscratch, rpc, reg_p_bank, LSL #16
		S9xSetPCBase
		TST 		rstatus, #MASK_INDEX
		@ INDEX set & was cleared : 16->8
		MOVNE		reg_x,reg_x,LSL #8
		MOVNE		reg_y,reg_y,LSL #8		
		TST 		rstatus, #MASK_MEM		
		@ MEMORY set & was cleared : 16->8
		@ MEMORY set & was cleared : 16->8
		MOVNE		rscratch,reg_a,LSR #24
		MOVNE		reg_a,reg_a,LSL #8
		STRNEB		rscratch,[reg_cpu_var,#RAH_ofs]
		ADD2CYCLE
		S9xFixCycles
.endm
	

/**********************************************************************************************/
/* STP/WAI/DB ******************************************************************************** */
@  WAI
.macro		OpCB	/*WAI*/
	LDRB		rscratch,[reg_cpu_var,#IRQActive_ofs]
	MOVS		rscratch,rscratch
	@ (CPU.IRQActive)
	ADD2CYCLENE
	BNE		1234f
/*
	CPU.WaitingForInterrupt = TRUE;
	CPU.PC--;*/	
	MOV		rscratch,#1
	SUB		rpc,rpc,#1
/*		
	    CPU.Cycles = CPU.NextEvent;	    
*/		
	STRB		rscratch,[reg_cpu_var,#WaitingForInterrupt_ofs]
	LDR		reg_cycles,[reg_cpu_var,#NextEvent_ofs]
/*
	if (IAPU.APUExecuting)
	    {
		ICPU.CPUExecuting = FALSE;
		do
		{
		    APU_EXECUTE1 ();
		} while (APU.Cycles < CPU.NextEvent);
		ICPU.CPUExecuting = TRUE;
	    }	
*/	
	LDRB		rscratch,[reg_cpu_var,#APUExecuting_ofs]
	MOVS		rscratch,rscratch
	BEQ		1234f
	asmAPU_EXECUTE2	

1234:	
.endm
.macro		OpDB	/*STP*/    
    		SUB	rpc,rpc,#1
    		@ CPU.Flags |= DEBUG_MODE_FLAG;
.endm
.macro		Op42   /*Reserved Snes9X*/
.endm	
		
/**********************************************************************************************/
/* AND ******************************************************************************** */
.macro		Op29M1
		LDRB	rscratch    , [rpc], #1		
		ANDS	reg_a    , reg_a,	rscratch, LSL #24
		UPDATE_ZN
		ADD1MEM
.endm		
.macro		Op29M0		
		LDRB	rscratch2  , [rpc,#1]
		LDRB	rscratch   , [rpc], #2
		ORR	rscratch, rscratch, rscratch2, LSL #8		
		ANDS	reg_a    , reg_a,	rscratch, LSL #16
		UPDATE_ZN
		ADD2MEM
.endm

		


		

		

		

		

		

		
/**********************************************************************************************/
/* EOR ******************************************************************************** */
.macro		Op49M0		
                LDRB	rscratch2 , [rpc, #1]
                LDRB	rscratch , [rpc], #2
		ORR	rscratch, rscratch, rscratch2,LSL #8                
		EORS    reg_a, reg_a, rscratch,LSL #16
		UPDATE_ZN
		ADD2MEM
.endm

		
.macro		Op49M1		
                LDRB	rscratch , [rpc], #1                
		EORS    reg_a, reg_a, rscratch,LSL #24
		UPDATE_ZN
		ADD1MEM
.endm


/**********************************************************************************************/
/* STA *************************************************************************************** */		
.macro		Op81M1				
		STA8
		@ TST 		rstatus, #MASK_INDEX
		@ ADD1CYCLENE
.endm
.macro		Op81M0				
		STA16
		@ TST rstatus, #MASK_INDEX
		@ ADD1CYCLENE
.endm


/**********************************************************************************************/
/* BIT *************************************************************************************** */
.macro		Op89M1		
                LDRB	rscratch , [rpc], #1                
		TST     reg_a, rscratch, LSL #24
		UPDATE_Z
		ADD1MEM
.endm
.macro		Op89M0		
                LDRB	rscratch2 , [rpc, #1]
                LDRB	rscratch , [rpc], #2
		ORR	rscratch, rscratch, rscratch2, LSL #8                
		TST     reg_a, rscratch, LSL #16
		UPDATE_Z
		ADD2MEM
.endm

		

		
		

/**********************************************************************************************/
/* LDY *************************************************************************************** */
.macro		OpA0X1
                LDRB	rscratch , [rpc], #1                
                MOVS    reg_y, rscratch, LSL #24
		UPDATE_ZN
		ADD1MEM
.endm
.macro		OpA0X0		
                LDRB	rscratch2 , [rpc, #1]
                LDRB	rscratch , [rpc], #2
		ORR	rscratch, rscratch, rscratch2, LSL #8                
                MOVS    reg_y, rscratch, LSL #16
		UPDATE_ZN
		ADD2MEM
.endm

/**********************************************************************************************/
/* LDX *************************************************************************************** */		
.macro		OpA2X1		
                LDRB	rscratch , [rpc], #1                
                MOVS    reg_x, rscratch, LSL #24
		UPDATE_ZN
		ADD1MEM
.endm
.macro		OpA2X0		
                LDRB	rscratch2 , [rpc, #1]
                LDRB	rscratch , [rpc], #2
		ORR	rscratch, rscratch, rscratch2, LSL #8                
                MOVS    reg_x, rscratch, LSL #16
		UPDATE_ZN
		ADD2MEM
.endm
		
/**********************************************************************************************/
/* LDA *************************************************************************************** */		
.macro		OpA9M1		
                LDRB	rscratch , [rpc], #1
                MOVS    reg_a, rscratch, LSL #24
		UPDATE_ZN
		ADD1MEM
.endm
.macro		OpA9M0		
                LDRB	rscratch2 , [rpc, #1]
                LDRB	rscratch , [rpc], #2
		ORR	rscratch, rscratch, rscratch2, LSL #8                
                MOVS    reg_a, rscratch, LSL #16                
		UPDATE_ZN
		ADD2MEM
.endm
												
/**********************************************************************************************/
/* CMY *************************************************************************************** */
.macro		OpC0X1
		LDRB	rscratch    , [rpc], #1		
		SUBS	rscratch2   , reg_y , rscratch, LSL #24
		BICCC	rstatus, rstatus, #MASK_CARRY
		ORRCS	rstatus, rstatus, #MASK_CARRY
		UPDATE_ZN		
		ADD1MEM
.endm
.macro		OpC0X0
		LDRB	rscratch2   , [rpc, #1]
		LDRB	rscratch   , [rpc], #2		
		ORR	rscratch, rscratch, rscratch2, LSL #8
		SUBS	rscratch2   , reg_y, rscratch, LSL #16
		BICCC	rstatus, rstatus, #MASK_CARRY
		ORRCS	rstatus, rstatus, #MASK_CARRY
		UPDATE_ZN
		ADD2MEM
.endm

		

		

/**********************************************************************************************/
/* CMP *************************************************************************************** */		
.macro		OpC9M1		
		LDRB	rscratch    , [rpc], #1		
		SUBS	rscratch2   , reg_a , rscratch, LSL #24		
		BICCC	rstatus, rstatus, #MASK_CARRY
		ORRCS	rstatus, rstatus, #MASK_CARRY
		UPDATE_ZN
		ADD1MEM
.endm
.macro		OpC9M0		
		LDRB	rscratch2   , [rpc,#1]
		LDRB	rscratch   , [rpc], #2		
		ORR	rscratch, rscratch, rscratch2, LSL #8
		SUBS	rscratch2   , reg_a, rscratch, LSL #16		
		BICCC	rstatus, rstatus, #MASK_CARRY
		ORRCS	rstatus, rstatus, #MASK_CARRY
		UPDATE_ZN
		ADD2MEM
.endm

/**********************************************************************************************/
/* CMX *************************************************************************************** */		
.macro		OpE0X1		
		LDRB	rscratch    , [rpc], #1		
		SUBS	rscratch2   , reg_x , rscratch, LSL #24
		BICCC	rstatus, rstatus, #MASK_CARRY
		ORRCS	rstatus, rstatus, #MASK_CARRY
		UPDATE_ZN		
		ADD1MEM
.endm
.macro		OpE0X0		
		LDRB	rscratch2   , [rpc,#1]
		LDRB	rscratch   , [rpc], #2		
		ORR	rscratch, rscratch, rscratch2, LSL #8
		SUBS	rscratch2   , reg_x, rscratch, LSL #16
		BICCC	rstatus, rstatus, #MASK_CARRY
		ORRCS	rstatus, rstatus, #MASK_CARRY
		UPDATE_ZN
		ADD2MEM
.endm

/*


CLI_OPE_REC_Nos_Layer0 
  	nos.nos_ope_treasury_date = convert(DATETIME, @treasuryDate, 103)
    	nos.nos_ope_accounting_date = convert(DATETIME, @accountingDate, 103)

CLI_OPE_Nos_Ope_Layer0
	n.nos_ope_treasury_date = convert(DATETIME, @LARD, 103)
	n.nos_ope_accounting_date = convert(DATETIME, @LARD, 103)
    	
CLI_OPE_Nos_Layer0    	
	nos.nos_ope_treasury_date = convert(DATETIME, @LARD, 103)
	nos.nos_ope_accounting_date = convert(DATETIME, @LARD, 103)    	
	
Ecrans:
------


[GNV] : utilisation de la lard (laccdate) pour afficher les openings.
   +nécessité d'avoir des valeurs dans l'opening pour date tréso=date compta=laccdate
	
[Accounting rec] : si laccdate pas bonne (pas = BD-1) -> message warning et pas de donnée
sinon : 
  +données nécessaires : opening date tréso=date compta=laccdate=BD-1
  +données nécessaires : opening date tréso=date compta=laccdate-1
  +données nécessaires : opening date tréso=laccdate-1 et date compta=laccdate
   */


	
/****************************************************************
	GLOBAL
****************************************************************/
	.globl   test_opcode
	.globl	 asmMainLoop


@ void asmMainLoop(asm_cpu_var_t *asmcpuPtr);
asmMainLoop:
	@ save registers
	STMFD		R13!,{R4-R11,LR}
	@ init pointer to CPUvar structure
	MOV		reg_cpu_var,R0
	@ init registers
	LOAD_REGS
	@ get cpu mode from flag and init jump table
	S9xFixCycles

mainLoop:
	@ APU Execute
	asmAPU_EXECUTE

	@ Test Flags
	LDR		rscratch,[reg_cpu_var,#Flags_ofs]
	MOVS		rscratch,rscratch
	BNE		CPUFlags_set	@ If flags => check for irq/nmi/scan_keys...	
	
	EXEC_OP						@ Execute next opcode
	
CPUFlags_set:	@ Check flags (!=0)
		TST	rscratch,#NMI_FLAG		@ Check NMI
		BEQ	CPUFlagsNMI_FLAG_cleared	
		LDR	rscratch2,[reg_cpu_var,#NMICycleCount_ofs]
		SUBS	rscratch2,rscratch2,#1
		STR	rscratch2,[reg_cpu_var,#NMICycleCount_ofs]		
		BNE	CPUFlagsNMI_FLAG_cleared	
		BIC	rscratch,rscratch,#NMI_FLAG
		STR	rscratch,[reg_cpu_var,#Flags_ofs]		
		LDRB	rscratch2,[reg_cpu_var,#WaitingForInterrupt_ofs]
		MOVS	rscratch2,rscratch2
		BEQ	NotCPUaitingForInterruptNMI
		MOV	rscratch2,#0
		ADD	rpc,rpc,#1
		STRB	rscratch2,[reg_cpu_var,#WaitingForInterrupt_ofs]		
NotCPUaitingForInterruptNMI:
		S9xOpcode_NMI
		LDR	rscratch,[reg_cpu_var,#Flags_ofs]	
CPUFlagsNMI_FLAG_cleared:
		TST	rscratch,#IRQ_PENDING_FLAG   @ Check IRQ_PENDING_FLAG
		BEQ	CPUFlagsIRQ_PENDING_FLAG_cleared		
		LDR	rscratch2,[reg_cpu_var,#IRQCycleCount_ofs]
		MOVS	rscratch2,rscratch2
		BNE	CPUIRQCycleCount_NotZero		
	 	LDRB	rscratch2,[reg_cpu_var,#WaitingForInterrupt_ofs]
		MOVS	rscratch2,rscratch2
		BEQ	NotCPUaitingForInterruptIRQ
	        MOV	rscratch2,#0
		ADD	rpc,rpc,#1
		STRB	rscratch2,[reg_cpu_var,#WaitingForInterrupt_ofs]
NotCPUaitingForInterruptIRQ:
		LDRB	rscratch2,[reg_cpu_var,#IRQActive_ofs]
		MOVS	rscratch2,rscratch2
		BEQ	CPUIRQActive_cleared
		TST	rstatus,#MASK_IRQ
		BNE	CPUFlagsIRQ_PENDING_FLAG_cleared
		S9xOpcode_IRQ
		LDR	rscratch,[reg_cpu_var,#Flags_ofs]	
		B	CPUFlagsIRQ_PENDING_FLAG_cleared
CPUIRQActive_cleared:		
		BIC	rscratch,rscratch,#IRQ_PENDING_FLAG
		STR	rscratch,[reg_cpu_var,#Flags_ofs]	
		B	CPUFlagsIRQ_PENDING_FLAG_cleared
CPUIRQCycleCount_NotZero:
		SUB	rscratch2,rscratch2,#1
		STR	rscratch2,[reg_cpu_var,#IRQCycleCount_ofs]
CPUFlagsIRQ_PENDING_FLAG_cleared:

		TST	rscratch,#SCAN_KEYS_FLAG   @ Check SCAN_KEYS_FLAG
		BNE	endmainLoop		

	EXEC_OP	@ Execute next opcode

endmainLoop:

    /*Registers.PC = CPU.PC - CPU.PCBase;
    S9xPackStatus ();
    APURegisters.PC = IAPU.PC - IAPU.RAM;
    S9xAPUPackStatus ();
    
    if (CPU.Flags & SCAN_KEYS_FLAG)
    {
	    S9xSyncSpeed ();
	CPU.Flags &= ~SCAN_KEYS_FLAG;
    }	*/
/********end*/
	SAVE_REGS
	LDMFD		R13!,{R4-R11,LR}
	MOV		PC,LR
.pool

@ void test_opcode(struct asm_cpu_var *asm_var);
test_opcode:
	@ save registers
	STMFD		R13!,{R4-R11,LR}
	@ init pointer to CPUvar structure
	MOV		reg_cpu_var,R0
	@ init registers
	LOAD_REGS
	@ get cpu mode from flag and init jump table
	S9xFixCycles
	
	EXEC_OP
.pool

/*****************************************************************
       ASM CODE
*****************************************************************/

	
jumptable1:		.long	Op00mod1
			.long	Op01M1mod1
			.long	Op02mod1
			.long	Op03M1mod1
			.long	Op04M1mod1
			.long	Op05M1mod1
			.long	Op06M1mod1
			.long	Op07M1mod1
			.long	Op08mod1
			.long	Op09M1mod1
			.long	Op0AM1mod1
			.long	Op0Bmod1
			.long	Op0CM1mod1
			.long	Op0DM1mod1
			.long	Op0EM1mod1
			.long	Op0FM1mod1
			.long	Op10mod1
			.long	Op11M1mod1
			.long	Op12M1mod1
			.long	Op13M1mod1
			.long	Op14M1mod1
			.long	Op15M1mod1
			.long	Op16M1mod1
			.long	Op17M1mod1
			.long	Op18mod1
			.long	Op19M1mod1
			.long	Op1AM1mod1
			.long	Op1Bmod1
			.long	Op1CM1mod1
			.long	Op1DM1mod1
			.long	Op1EM1mod1
			.long	Op1FM1mod1
			.long	Op20mod1
			.long	Op21M1mod1
			.long	Op22mod1
			.long	Op23M1mod1
			.long	Op24M1mod1
			.long	Op25M1mod1
			.long	Op26M1mod1
			.long	Op27M1mod1
			.long	Op28mod1
			.long	Op29M1mod1
			.long	Op2AM1mod1
			.long	Op2Bmod1
			.long	Op2CM1mod1
			.long	Op2DM1mod1
			.long	Op2EM1mod1
			.long	Op2FM1mod1
			.long	Op30mod1
			.long	Op31M1mod1
			.long	Op32M1mod1
			.long	Op33M1mod1
			.long	Op34M1mod1
			.long	Op35M1mod1
			.long	Op36M1mod1
			.long	Op37M1mod1
			.long	Op38mod1
			.long	Op39M1mod1
			.long	Op3AM1mod1
			.long	Op3Bmod1
			.long	Op3CM1mod1
			.long	Op3DM1mod1
			.long	Op3EM1mod1
			.long	Op3FM1mod1
			.long	Op40mod1
			.long	Op41M1mod1
			.long	Op42mod1
			.long	Op43M1mod1
			.long	Op44X1mod1
			.long	Op45M1mod1
			.long	Op46M1mod1
			.long	Op47M1mod1
			.long	Op48M1mod1
			.long	Op49M1mod1
			.long	Op4AM1mod1
			.long	Op4Bmod1
			.long	Op4Cmod1
			.long	Op4DM1mod1
			.long	Op4EM1mod1
			.long	Op4FM1mod1
			.long	Op50mod1
			.long	Op51M1mod1
			.long	Op52M1mod1
			.long	Op53M1mod1
			.long	Op54X1mod1
			.long	Op55M1mod1
			.long	Op56M1mod1
			.long	Op57M1mod1
			.long	Op58mod1
			.long	Op59M1mod1
			.long	Op5AX1mod1
			.long	Op5Bmod1
			.long	Op5Cmod1
			.long	Op5DM1mod1
			.long	Op5EM1mod1
			.long	Op5FM1mod1
			.long	Op60mod1
			.long	Op61M1mod1
			.long	Op62mod1
			.long	Op63M1mod1
			.long	Op64M1mod1
			.long	Op65M1mod1
			.long	Op66M1mod1
			.long	Op67M1mod1
			.long	Op68M1mod1
			.long	Op69M1mod1
			.long	Op6AM1mod1
			.long	Op6Bmod1
			.long	Op6Cmod1
			.long	Op6DM1mod1
			.long	Op6EM1mod1
			.long	Op6FM1mod1
			.long	Op70mod1
			.long	Op71M1mod1
			.long	Op72M1mod1
			.long	Op73M1mod1
			.long	Op74M1mod1
			.long	Op75M1mod1
			.long	Op76M1mod1
			.long	Op77M1mod1
			.long	Op78mod1
			.long	Op79M1mod1
			.long	Op7AX1mod1
			.long	Op7Bmod1
			.long	Op7Cmod1
			.long	Op7DM1mod1
			.long	Op7EM1mod1
			.long	Op7FM1mod1
			.long	Op80mod1
			.long	Op81M1mod1
			.long	Op82mod1
			.long	Op83M1mod1
			.long	Op84X1mod1
			.long	Op85M1mod1
			.long	Op86X1mod1
			.long	Op87M1mod1
			.long	Op88X1mod1
			.long	Op89M1mod1
			.long	Op8AM1mod1
			.long	Op8Bmod1
			.long	Op8CX1mod1
			.long	Op8DM1mod1
			.long	Op8EX1mod1
			.long	Op8FM1mod1
			.long	Op90mod1
			.long	Op91M1mod1
			.long	Op92M1mod1
			.long	Op93M1mod1
			.long	Op94X1mod1
			.long	Op95M1mod1
			.long	Op96X1mod1
			.long	Op97M1mod1
			.long	Op98M1mod1
			.long	Op99M1mod1
			.long	Op9Amod1
			.long	Op9BX1mod1
			.long	Op9CM1mod1
			.long	Op9DM1mod1
			.long	Op9EM1mod1
			.long	Op9FM1mod1
			.long	OpA0X1mod1
			.long	OpA1M1mod1
			.long	OpA2X1mod1
			.long	OpA3M1mod1
			.long	OpA4X1mod1
			.long	OpA5M1mod1
			.long	OpA6X1mod1
			.long	OpA7M1mod1
			.long	OpA8X1mod1
			.long	OpA9M1mod1
			.long	OpAAX1mod1
			.long	OpABmod1
			.long	OpACX1mod1
			.long	OpADM1mod1
			.long	OpAEX1mod1
			.long	OpAFM1mod1
			.long	OpB0mod1
			.long	OpB1M1mod1
			.long	OpB2M1mod1
			.long	OpB3M1mod1
			.long	OpB4X1mod1
			.long	OpB5M1mod1
			.long	OpB6X1mod1
			.long	OpB7M1mod1
			.long	OpB8mod1
			.long	OpB9M1mod1
			.long	OpBAX1mod1
			.long	OpBBX1mod1
			.long	OpBCX1mod1
			.long	OpBDM1mod1
			.long	OpBEX1mod1
			.long	OpBFM1mod1
			.long	OpC0X1mod1
			.long	OpC1M1mod1
			.long	OpC2mod1
			.long	OpC3M1mod1
			.long	OpC4X1mod1
			.long	OpC5M1mod1
			.long	OpC6M1mod1
			.long	OpC7M1mod1
			.long	OpC8X1mod1
			.long	OpC9M1mod1
			.long	OpCAX1mod1
			.long	OpCBmod1
			.long	OpCCX1mod1
			.long	OpCDM1mod1
			.long	OpCEM1mod1
			.long	OpCFM1mod1
			.long	OpD0mod1
			.long	OpD1M1mod1
			.long	OpD2M1mod1
			.long	OpD3M1mod1
			.long	OpD4mod1
			.long	OpD5M1mod1
			.long	OpD6M1mod1
			.long	OpD7M1mod1
			.long	OpD8mod1
			.long	OpD9M1mod1
			.long	OpDAX1mod1
			.long	OpDBmod1
			.long	OpDCmod1
			.long	OpDDM1mod1
			.long	OpDEM1mod1
			.long	OpDFM1mod1
			.long	OpE0X1mod1
			.long	OpE1M1mod1
			.long	OpE2mod1
			.long	OpE3M1mod1
			.long	OpE4X1mod1
			.long	OpE5M1mod1
			.long	OpE6M1mod1
			.long	OpE7M1mod1
			.long	OpE8X1mod1
			.long	OpE9M1mod1
			.long	OpEAmod1
			.long	OpEBmod1
			.long	OpECX1mod1
			.long	OpEDM1mod1
			.long	OpEEM1mod1
			.long	OpEFM1mod1
			.long	OpF0mod1
			.long	OpF1M1mod1
			.long	OpF2M1mod1
			.long	OpF3M1mod1
			.long	OpF4mod1
			.long	OpF5M1mod1
			.long	OpF6M1mod1
			.long	OpF7M1mod1
			.long	OpF8mod1
			.long	OpF9M1mod1
			.long	OpFAX1mod1
			.long	OpFBmod1
			.long	OpFCmod1
			.long	OpFDM1mod1
			.long	OpFEM1mod1
			.long	OpFFM1mod1
			
Op00mod1:
lbl00mod1:	Op00
			NEXTOPCODE
Op01M1mod1:
lbl01mod1a:	DirectIndexedIndirect1
lbl01mod1b:	ORA8
			NEXTOPCODE
Op02mod1:
lbl02mod1:	Op02
			NEXTOPCODE
Op03M1mod1:
lbl03mod1a:	StackasmRelative
lbl03mod1b:	ORA8
			NEXTOPCODE
Op04M1mod1:
lbl04mod1a:	Direct
lbl04mod1b:	TSB8
			NEXTOPCODE
Op05M1mod1:
lbl05mod1a:	Direct
lbl05mod1b:	ORA8
			NEXTOPCODE
Op06M1mod1:
lbl06mod1a:	Direct
lbl06mod1b:	ASL8
			NEXTOPCODE
Op07M1mod1:
lbl07mod1a:	DirectIndirectLong
lbl07mod1b:	ORA8
			NEXTOPCODE
Op08mod1:
lbl08mod1:	Op08
			NEXTOPCODE
Op09M1mod1:
lbl09mod1:	Op09M1
			NEXTOPCODE
Op0AM1mod1:
lbl0Amod1a:	A_ASL8
			NEXTOPCODE
Op0Bmod1:
lbl0Bmod1:	Op0B
			NEXTOPCODE
Op0CM1mod1:
lbl0Cmod1a:	Absolute
lbl0Cmod1b:	TSB8
			NEXTOPCODE
Op0DM1mod1:
lbl0Dmod1a:	Absolute
lbl0Dmod1b:	ORA8
			NEXTOPCODE
Op0EM1mod1:
lbl0Emod1a:	Absolute
lbl0Emod1b:	ASL8
			NEXTOPCODE
Op0FM1mod1:
lbl0Fmod1a:	AbsoluteLong
lbl0Fmod1b:	ORA8
			NEXTOPCODE
Op10mod1:
lbl10mod1:	Op10
			NEXTOPCODE
Op11M1mod1:
lbl11mod1a:	DirectIndirectIndexed1
lbl11mod1b:	ORA8
			NEXTOPCODE
Op12M1mod1:
lbl12mod1a:	DirectIndirect
lbl12mod1b:	ORA8
			NEXTOPCODE
Op13M1mod1:
lbl13mod1a:	StackasmRelativeIndirectIndexed1
lbl13mod1b:	ORA8
			NEXTOPCODE
Op14M1mod1:
lbl14mod1a:	Direct
lbl14mod1b:	TRB8
			NEXTOPCODE
Op15M1mod1:
lbl15mod1a:	DirectIndexedX1
lbl15mod1b:	ORA8
			NEXTOPCODE
Op16M1mod1:
lbl16mod1a:	DirectIndexedX1
lbl16mod1b:	ASL8
			NEXTOPCODE
Op17M1mod1:
lbl17mod1a:	DirectIndirectIndexedLong1
lbl17mod1b:	ORA8
			NEXTOPCODE
Op18mod1:
lbl18mod1:	Op18
			NEXTOPCODE
Op19M1mod1:
lbl19mod1a:	AbsoluteIndexedY1
lbl19mod1b:	ORA8
			NEXTOPCODE
Op1AM1mod1:
lbl1Amod1a:	A_INC8
			NEXTOPCODE
Op1Bmod1:
lbl1Bmod1:	Op1BM1
			NEXTOPCODE
Op1CM1mod1:
lbl1Cmod1a:	Absolute
lbl1Cmod1b:	TRB8
			NEXTOPCODE
Op1DM1mod1:
lbl1Dmod1a:	AbsoluteIndexedX1
lbl1Dmod1b:	ORA8
			NEXTOPCODE
Op1EM1mod1:
lbl1Emod1a:	AbsoluteIndexedX1
lbl1Emod1b:	ASL8
			NEXTOPCODE
Op1FM1mod1:
lbl1Fmod1a:	AbsoluteLongIndexedX1
lbl1Fmod1b:	ORA8
			NEXTOPCODE
Op20mod1:
lbl20mod1:	Op20
			NEXTOPCODE
Op21M1mod1:
lbl21mod1a:	DirectIndexedIndirect1
lbl21mod1b:	AND8
			NEXTOPCODE
Op22mod1:
lbl22mod1:	Op22
			NEXTOPCODE
Op23M1mod1:
lbl23mod1a:	StackasmRelative
lbl23mod1b:	AND8
			NEXTOPCODE
Op24M1mod1:
lbl24mod1a:	Direct
lbl24mod1b:	BIT8
			NEXTOPCODE
Op25M1mod1:
lbl25mod1a:	Direct
lbl25mod1b:	AND8
			NEXTOPCODE
Op26M1mod1:
lbl26mod1a:	Direct
lbl26mod1b:	ROL8
			NEXTOPCODE
Op27M1mod1:
lbl27mod1a:	DirectIndirectLong
lbl27mod1b:	AND8
			NEXTOPCODE
Op28mod1:
lbl28mod1:	Op28X1M1
			NEXTOPCODE
.pool			
Op29M1mod1:
lbl29mod1:	Op29M1
			NEXTOPCODE
Op2AM1mod1:
lbl2Amod1a:	A_ROL8
			NEXTOPCODE
Op2Bmod1:
lbl2Bmod1:	Op2B
			NEXTOPCODE
Op2CM1mod1:
lbl2Cmod1a:	Absolute
lbl2Cmod1b:	BIT8
			NEXTOPCODE
Op2DM1mod1:
lbl2Dmod1a:	Absolute
lbl2Dmod1b:	AND8
			NEXTOPCODE
Op2EM1mod1:
lbl2Emod1a:	Absolute
lbl2Emod1b:	ROL8
			NEXTOPCODE
Op2FM1mod1:
lbl2Fmod1a:	AbsoluteLong
lbl2Fmod1b:	AND8
			NEXTOPCODE
Op30mod1:
lbl30mod1:	Op30
			NEXTOPCODE
Op31M1mod1:
lbl31mod1a:	DirectIndirectIndexed1
lbl31mod1b:	AND8
			NEXTOPCODE
Op32M1mod1:
lbl32mod1a:	DirectIndirect
lbl32mod1b:	AND8
			NEXTOPCODE
Op33M1mod1:
lbl33mod1a:	StackasmRelativeIndirectIndexed1
lbl33mod1b:	AND8
			NEXTOPCODE
Op34M1mod1:
lbl34mod1a:	DirectIndexedX1
lbl34mod1b:	BIT8
			NEXTOPCODE
Op35M1mod1:
lbl35mod1a:	DirectIndexedX1
lbl35mod1b:	AND8
			NEXTOPCODE
Op36M1mod1:
lbl36mod1a:	DirectIndexedX1
lbl36mod1b:	ROL8
			NEXTOPCODE
Op37M1mod1:
lbl37mod1a:	DirectIndirectIndexedLong1
lbl37mod1b:	AND8
			NEXTOPCODE
Op38mod1:
lbl38mod1:	Op38
			NEXTOPCODE
Op39M1mod1:
lbl39mod1a:	AbsoluteIndexedY1
lbl39mod1b:	AND8
			NEXTOPCODE
Op3AM1mod1:
lbl3Amod1a:	A_DEC8
			NEXTOPCODE
Op3Bmod1:
lbl3Bmod1:	Op3BM1
			NEXTOPCODE
Op3CM1mod1:
lbl3Cmod1a:	AbsoluteIndexedX1
lbl3Cmod1b:	BIT8
			NEXTOPCODE
Op3DM1mod1:
lbl3Dmod1a:	AbsoluteIndexedX1
lbl3Dmod1b:	AND8
			NEXTOPCODE
Op3EM1mod1:
lbl3Emod1a:	AbsoluteIndexedX1
lbl3Emod1b:	ROL8
			NEXTOPCODE
Op3FM1mod1:
lbl3Fmod1a:	AbsoluteLongIndexedX1
lbl3Fmod1b:	AND8
			NEXTOPCODE
Op40mod1:
lbl40mod1:	Op40X1M1
			NEXTOPCODE
.pool						
Op41M1mod1:
lbl41mod1a:	DirectIndexedIndirect1
lbl41mod1b:	EOR8
			NEXTOPCODE
Op42mod1:
lbl42mod1:	Op42
			NEXTOPCODE
Op43M1mod1:
lbl43mod1a:	StackasmRelative
lbl43mod1b:	EOR8
			NEXTOPCODE
Op44X1mod1:
lbl44mod1:	Op44X1M1
			NEXTOPCODE
Op45M1mod1:
lbl45mod1a:	Direct
lbl45mod1b:	EOR8
			NEXTOPCODE
Op46M1mod1:
lbl46mod1a:	Direct
lbl46mod1b:	LSR8
			NEXTOPCODE
Op47M1mod1:
lbl47mod1a:	DirectIndirectLong
lbl47mod1b:	EOR8
			NEXTOPCODE
Op48M1mod1:
lbl48mod1:	Op48M1
			NEXTOPCODE
Op49M1mod1:
lbl49mod1:	Op49M1
			NEXTOPCODE
Op4AM1mod1:
lbl4Amod1a:	A_LSR8
			NEXTOPCODE
Op4Bmod1:
lbl4Bmod1:	Op4B
			NEXTOPCODE
Op4Cmod1:
lbl4Cmod1:	Op4C
			NEXTOPCODE
Op4DM1mod1:
lbl4Dmod1a:	Absolute
lbl4Dmod1b:	EOR8
			NEXTOPCODE
Op4EM1mod1:
lbl4Emod1a:	Absolute
lbl4Emod1b:	LSR8
			NEXTOPCODE
Op4FM1mod1:
lbl4Fmod1a:	AbsoluteLong
lbl4Fmod1b:	EOR8
			NEXTOPCODE
Op50mod1:
lbl50mod1:	Op50
			NEXTOPCODE
Op51M1mod1:
lbl51mod1a:	DirectIndirectIndexed1
lbl51mod1b:	EOR8
			NEXTOPCODE
Op52M1mod1:
lbl52mod1a:	DirectIndirect
lbl52mod1b:	EOR8
			NEXTOPCODE
Op53M1mod1:
lbl53mod1a:	StackasmRelativeIndirectIndexed1
lbl53mod1b:	EOR8
			NEXTOPCODE
Op54X1mod1:
lbl54mod1:	Op54X1M1
			NEXTOPCODE
Op55M1mod1:
lbl55mod1a:	DirectIndexedX1
lbl55mod1b:	EOR8
			NEXTOPCODE
Op56M1mod1:
lbl56mod1a:	DirectIndexedX1
lbl56mod1b:	LSR8
			NEXTOPCODE
Op57M1mod1:
lbl57mod1a:	DirectIndirectIndexedLong1
lbl57mod1b:	EOR8
			NEXTOPCODE
Op58mod1:
lbl58mod1:	Op58
			NEXTOPCODE
Op59M1mod1:
lbl59mod1a:	AbsoluteIndexedY1
lbl59mod1b:	EOR8
			NEXTOPCODE
Op5AX1mod1:
lbl5Amod1:	Op5AX1
			NEXTOPCODE
Op5Bmod1:
lbl5Bmod1:	Op5BM1
			NEXTOPCODE
Op5Cmod1:
lbl5Cmod1:	Op5C
			NEXTOPCODE
Op5DM1mod1:
lbl5Dmod1a:	AbsoluteIndexedX1
lbl5Dmod1b:	EOR8
			NEXTOPCODE
Op5EM1mod1:
lbl5Emod1a:	AbsoluteIndexedX1
lbl5Emod1b:	LSR8
			NEXTOPCODE
Op5FM1mod1:
lbl5Fmod1a:	AbsoluteLongIndexedX1
lbl5Fmod1b:	EOR8
			NEXTOPCODE
Op60mod1:
lbl60mod1:	Op60
			NEXTOPCODE
Op61M1mod1:
lbl61mod1a:	DirectIndexedIndirect1
lbl61mod1b:	ADC8
			NEXTOPCODE
Op62mod1:
lbl62mod1:	Op62
			NEXTOPCODE
Op63M1mod1:
lbl63mod1a:	StackasmRelative
lbl63mod1b:	ADC8
			NEXTOPCODE
Op64M1mod1:
lbl64mod1a:	Direct
lbl64mod1b:	STZ8
			NEXTOPCODE
Op65M1mod1:
lbl65mod1a:	Direct
lbl65mod1b:	ADC8
			NEXTOPCODE
Op66M1mod1:
lbl66mod1a:	Direct
lbl66mod1b:	ROR8
			NEXTOPCODE
Op67M1mod1:
lbl67mod1a:	DirectIndirectLong
lbl67mod1b:	ADC8
			NEXTOPCODE
Op68M1mod1:
lbl68mod1:	Op68M1
			NEXTOPCODE
Op69M1mod1:
lbl69mod1a:	Immediate8
lbl69mod1b:	ADC8
			NEXTOPCODE
Op6AM1mod1:
lbl6Amod1a:	A_ROR8
			NEXTOPCODE
Op6Bmod1:
lbl6Bmod1:	Op6B
			NEXTOPCODE
Op6Cmod1:
lbl6Cmod1:	Op6C
			NEXTOPCODE
Op6DM1mod1:
lbl6Dmod1a:	Absolute
lbl6Dmod1b:	ADC8
			NEXTOPCODE
Op6EM1mod1:
lbl6Emod1a:	Absolute
lbl6Emod1b:	ROR8
			NEXTOPCODE
Op6FM1mod1:
lbl6Fmod1a:	AbsoluteLong
lbl6Fmod1b:	ADC8
			NEXTOPCODE
Op70mod1:
lbl70mod1:	Op70
			NEXTOPCODE
Op71M1mod1:
lbl71mod1a:	DirectIndirectIndexed1
lbl71mod1b:	ADC8
			NEXTOPCODE
Op72M1mod1:
lbl72mod1a:	DirectIndirect
lbl72mod1b:	ADC8
			NEXTOPCODE
Op73M1mod1:
lbl73mod1a:	StackasmRelativeIndirectIndexed1
lbl73mod1b:	ADC8
			NEXTOPCODE

Op74M1mod1:
lbl74mod1a:	DirectIndexedX1
lbl74mod1b:	STZ8
			NEXTOPCODE
Op75M1mod1:
lbl75mod1a:	DirectIndexedX1
lbl75mod1b:	ADC8
			NEXTOPCODE
Op76M1mod1:
lbl76mod1a:	DirectIndexedX1
lbl76mod1b:	ROR8
			NEXTOPCODE
Op77M1mod1:
lbl77mod1a:	DirectIndirectIndexedLong1
lbl77mod1b:	ADC8
			NEXTOPCODE
Op78mod1:
lbl78mod1:	Op78
			NEXTOPCODE
Op79M1mod1:
lbl79mod1a:	AbsoluteIndexedY1
lbl79mod1b:	ADC8
			NEXTOPCODE
Op7AX1mod1:
lbl7Amod1:	Op7AX1
			NEXTOPCODE
Op7Bmod1:
lbl7Bmod1:	Op7BM1
			NEXTOPCODE
Op7Cmod1:
lbl7Cmod1:	AbsoluteIndexedIndirectX1
		Op7C
			NEXTOPCODE
Op7DM1mod1:
lbl7Dmod1a:	AbsoluteIndexedX1
lbl7Dmod1b:	ADC8
			NEXTOPCODE
Op7EM1mod1:
lbl7Emod1a:	AbsoluteIndexedX1
lbl7Emod1b:	ROR8
			NEXTOPCODE
Op7FM1mod1:
lbl7Fmod1a:	AbsoluteLongIndexedX1
lbl7Fmod1b:	ADC8
			NEXTOPCODE


Op80mod1:
lbl80mod1:	Op80
			NEXTOPCODE
Op81M1mod1:
lbl81mod1a:	DirectIndexedIndirect1
lbl81mod1b:	Op81M1
			NEXTOPCODE
Op82mod1:
lbl82mod1:	Op82
			NEXTOPCODE
Op83M1mod1:
lbl83mod1a:	StackasmRelative
lbl83mod1b:	STA8
			NEXTOPCODE
Op84X1mod1:
lbl84mod1a:	Direct
lbl84mod1b:	STY8
			NEXTOPCODE
Op85M1mod1:
lbl85mod1a:	Direct
lbl85mod1b:	STA8
			NEXTOPCODE
Op86X1mod1:
lbl86mod1a:	Direct
lbl86mod1b:	STX8
			NEXTOPCODE
Op87M1mod1:
lbl87mod1a:	DirectIndirectLong
lbl87mod1b:	STA8
			NEXTOPCODE
Op88X1mod1:
lbl88mod1:	Op88X1
			NEXTOPCODE
Op89M1mod1:
lbl89mod1:	Op89M1
			NEXTOPCODE
Op8AM1mod1:
lbl8Amod1:	Op8AM1X1
			NEXTOPCODE
Op8Bmod1:
lbl8Bmod1:	Op8B
			NEXTOPCODE
Op8CX1mod1:
lbl8Cmod1a:	Absolute
lbl8Cmod1b:	STY8
			NEXTOPCODE
Op8DM1mod1:
lbl8Dmod1a:	Absolute
lbl8Dmod1b:	STA8
			NEXTOPCODE
Op8EX1mod1:
lbl8Emod1a:	Absolute
lbl8Emod1b:	STX8
			NEXTOPCODE
Op8FM1mod1:
lbl8Fmod1a:	AbsoluteLong
lbl8Fmod1b:	STA8
			NEXTOPCODE
Op90mod1:
lbl90mod1:	Op90
			NEXTOPCODE
Op91M1mod1:
lbl91mod1a:	DirectIndirectIndexed1
lbl91mod1b:	STA8
			NEXTOPCODE
Op92M1mod1:
lbl92mod1a:	DirectIndirect
lbl92mod1b:	STA8
			NEXTOPCODE
Op93M1mod1:
lbl93mod1a:	StackasmRelativeIndirectIndexed1
lbl93mod1b:	STA8
			NEXTOPCODE
Op94X1mod1:
lbl94mod1a:	DirectIndexedX1
lbl94mod1b:	STY8
			NEXTOPCODE
Op95M1mod1:
lbl95mod1a:	DirectIndexedX1
lbl95mod1b:	STA8
			NEXTOPCODE
Op96X1mod1:
lbl96mod1a:	DirectIndexedY1
lbl96mod1b:	STX8
			NEXTOPCODE
Op97M1mod1:
lbl97mod1a:	DirectIndirectIndexedLong1
lbl97mod1b:	STA8
			NEXTOPCODE
Op98M1mod1:
lbl98mod1:	Op98M1X1
			NEXTOPCODE
Op99M1mod1:
lbl99mod1a:	AbsoluteIndexedY1
lbl99mod1b:	STA8
			NEXTOPCODE
Op9Amod1:
lbl9Amod1:	Op9AX1
			NEXTOPCODE
Op9BX1mod1:
lbl9Bmod1:	Op9BX1
			NEXTOPCODE
Op9CM1mod1:
lbl9Cmod1a:	Absolute
lbl9Cmod1b:	STZ8
			NEXTOPCODE
Op9DM1mod1:
lbl9Dmod1a:	AbsoluteIndexedX1
lbl9Dmod1b:	STA8
			NEXTOPCODE
Op9EM1mod1:	
lbl9Emod1:	AbsoluteIndexedX1		
		STZ8
			NEXTOPCODE
Op9FM1mod1:
lbl9Fmod1a:	AbsoluteLongIndexedX1
lbl9Fmod1b:	STA8
			NEXTOPCODE
OpA0X1mod1:
lblA0mod1:	OpA0X1
			NEXTOPCODE
OpA1M1mod1:
lblA1mod1a:	DirectIndexedIndirect1
lblA1mod1b:	LDA8
			NEXTOPCODE
OpA2X1mod1:
lblA2mod1:	OpA2X1
			NEXTOPCODE
OpA3M1mod1:
lblA3mod1a:	StackasmRelative
lblA3mod1b:	LDA8
			NEXTOPCODE
OpA4X1mod1:
lblA4mod1a:	Direct
lblA4mod1b:	LDY8
			NEXTOPCODE
OpA5M1mod1:
lblA5mod1a:	Direct
lblA5mod1b:	LDA8
			NEXTOPCODE
OpA6X1mod1:
lblA6mod1a:	Direct
lblA6mod1b:	LDX8
			NEXTOPCODE
OpA7M1mod1:
lblA7mod1a:	DirectIndirectLong
lblA7mod1b:	LDA8
			NEXTOPCODE
OpA8X1mod1:
lblA8mod1:	OpA8X1M1
			NEXTOPCODE
OpA9M1mod1:
lblA9mod1:	OpA9M1
			NEXTOPCODE
OpAAX1mod1:
lblAAmod1:	OpAAX1M1
			NEXTOPCODE
OpABmod1:
lblABmod1:	OpAB
			NEXTOPCODE
OpACX1mod1:
lblACmod1a:	Absolute
lblACmod1b:	LDY8
			NEXTOPCODE
OpADM1mod1:
lblADmod1a:	Absolute
lblADmod1b:	LDA8
			NEXTOPCODE
OpAEX1mod1:
lblAEmod1a:	Absolute
lblAEmod1b:	LDX8
			NEXTOPCODE
OpAFM1mod1:
lblAFmod1a:	AbsoluteLong
lblAFmod1b:	LDA8
			NEXTOPCODE
OpB0mod1:
lblB0mod1:	OpB0
			NEXTOPCODE
OpB1M1mod1:
lblB1mod1a:	DirectIndirectIndexed1
lblB1mod1b:	LDA8
			NEXTOPCODE
OpB2M1mod1:
lblB2mod1a:	DirectIndirect
lblB2mod1b:	LDA8
			NEXTOPCODE
OpB3M1mod1:
lblB3mod1a:	StackasmRelativeIndirectIndexed1
lblB3mod1b:	LDA8
			NEXTOPCODE
OpB4X1mod1:
lblB4mod1a:	DirectIndexedX1
lblB4mod1b:	LDY8
			NEXTOPCODE
OpB5M1mod1:
lblB5mod1a:	DirectIndexedX1
lblB5mod1b:	LDA8
			NEXTOPCODE
OpB6X1mod1:
lblB6mod1a:	DirectIndexedY1
lblB6mod1b:	LDX8
			NEXTOPCODE
OpB7M1mod1:
lblB7mod1a:	DirectIndirectIndexedLong1
lblB7mod1b:	LDA8
			NEXTOPCODE
OpB8mod1:
lblB8mod1:	OpB8
			NEXTOPCODE
OpB9M1mod1:
lblB9mod1a:	AbsoluteIndexedY1
lblB9mod1b:	LDA8
			NEXTOPCODE
OpBAX1mod1:
lblBAmod1:	OpBAX1
			NEXTOPCODE
OpBBX1mod1:
lblBBmod1:	OpBBX1
			NEXTOPCODE
OpBCX1mod1:
lblBCmod1a:	AbsoluteIndexedX1
lblBCmod1b:	LDY8
			NEXTOPCODE
OpBDM1mod1:
lblBDmod1a:	AbsoluteIndexedX1
lblBDmod1b:	LDA8
			NEXTOPCODE
OpBEX1mod1:
lblBEmod1a:	AbsoluteIndexedY1
lblBEmod1b:	LDX8
			NEXTOPCODE
OpBFM1mod1:
lblBFmod1a:	AbsoluteLongIndexedX1
lblBFmod1b:	LDA8
			NEXTOPCODE
OpC0X1mod1:
lblC0mod1:	OpC0X1
			NEXTOPCODE
OpC1M1mod1:
lblC1mod1a:	DirectIndexedIndirect1
lblC1mod1b:	CMP8
			NEXTOPCODE
OpC2mod1:
lblC2mod1:	OpC2
			NEXTOPCODE
.pool
OpC3M1mod1:
lblC3mod1a:	StackasmRelative
lblC3mod1b:	CMP8
			NEXTOPCODE
OpC4X1mod1:
lblC4mod1a:	Direct
lblC4mod1b:	CMY8
			NEXTOPCODE
OpC5M1mod1:
lblC5mod1a:	Direct
lblC5mod1b:	CMP8
			NEXTOPCODE
OpC6M1mod1:
lblC6mod1a:	Direct
lblC6mod1b:	DEC8
			NEXTOPCODE
OpC7M1mod1:
lblC7mod1a:	DirectIndirectLong
lblC7mod1b:	CMP8
			NEXTOPCODE
OpC8X1mod1:
lblC8mod1:	OpC8X1
			NEXTOPCODE
OpC9M1mod1:
lblC9mod1:	OpC9M1
			NEXTOPCODE
OpCAX1mod1:
lblCAmod1:	OpCAX1
			NEXTOPCODE
OpCBmod1:
lblCBmod1:	OpCB
			NEXTOPCODE
OpCCX1mod1:
lblCCmod1a:	Absolute
lblCCmod1b:	CMY8
			NEXTOPCODE
OpCDM1mod1:
lblCDmod1a:	Absolute
lblCDmod1b:	CMP8
			NEXTOPCODE
OpCEM1mod1:
lblCEmod1a:	Absolute
lblCEmod1b:	DEC8
			NEXTOPCODE
OpCFM1mod1:
lblCFmod1a:	AbsoluteLong
lblCFmod1b:	CMP8
			NEXTOPCODE
OpD0mod1:
lblD0mod1:	OpD0
			NEXTOPCODE
OpD1M1mod1:
lblD1mod1a:	DirectIndirectIndexed1
lblD1mod1b:	CMP8
			NEXTOPCODE
OpD2M1mod1:
lblD2mod1a:	DirectIndirect
lblD2mod1b:	CMP8
			NEXTOPCODE
OpD3M1mod1:
lblD3mod1a:	StackasmRelativeIndirectIndexed1
lblD3mod1b:	CMP8
			NEXTOPCODE
OpD4mod1:
lblD4mod1:	OpD4
			NEXTOPCODE
OpD5M1mod1:
lblD5mod1a:	DirectIndexedX1
lblD5mod1b:	CMP8
			NEXTOPCODE
OpD6M1mod1:
lblD6mod1a:	DirectIndexedX1
lblD6mod1b:	DEC8
			NEXTOPCODE
OpD7M1mod1:
lblD7mod1a:	DirectIndirectIndexedLong1
lblD7mod1b:	CMP8
			NEXTOPCODE
OpD8mod1:
lblD8mod1:	OpD8
			NEXTOPCODE
OpD9M1mod1:
lblD9mod1a:	AbsoluteIndexedY1
lblD9mod1b:	CMP8
			NEXTOPCODE
OpDAX1mod1:
lblDAmod1:	OpDAX1
			NEXTOPCODE
OpDBmod1:
lblDBmod1:	OpDB
			NEXTOPCODE
OpDCmod1:
lblDCmod1:	OpDC
			NEXTOPCODE
OpDDM1mod1:
lblDDmod1a:	AbsoluteIndexedX1
lblDDmod1b:	CMP8
			NEXTOPCODE
OpDEM1mod1:
lblDEmod1a:	AbsoluteIndexedX1
lblDEmod1b:	DEC8
			NEXTOPCODE
OpDFM1mod1:
lblDFmod1a:	AbsoluteLongIndexedX1
lblDFmod1b:	CMP8
			NEXTOPCODE
OpE0X1mod1:
lblE0mod1:	OpE0X1
			NEXTOPCODE
OpE1M1mod1:
lblE1mod1a:	DirectIndexedIndirect1
lblE1mod1b:	SBC8
			NEXTOPCODE
OpE2mod1:
lblE2mod1:	OpE2
			NEXTOPCODE
.pool
OpE3M1mod1:
lblE3mod1a:	StackasmRelative
lblE3mod1b:	SBC8
			NEXTOPCODE
OpE4X1mod1:
lblE4mod1a:	Direct
lblE4mod1b:	CMX8
			NEXTOPCODE
OpE5M1mod1:
lblE5mod1a:	Direct
lblE5mod1b:	SBC8
			NEXTOPCODE
OpE6M1mod1:
lblE6mod1a:	Direct
lblE6mod1b:	INC8
			NEXTOPCODE
OpE7M1mod1:
lblE7mod1a:	DirectIndirectLong
lblE7mod1b:	SBC8
			NEXTOPCODE
OpE8X1mod1:
lblE8mod1:	OpE8X1
			NEXTOPCODE
OpE9M1mod1:
lblE9mod1a:	Immediate8
lblE9mod1b:	SBC8
			NEXTOPCODE
OpEAmod1:
lblEAmod1:	OpEA
			NEXTOPCODE
OpEBmod1:
lblEBmod1:	OpEBM1
			NEXTOPCODE
OpECX1mod1:
lblECmod1a:	Absolute
lblECmod1b:	CMX8
			NEXTOPCODE
OpEDM1mod1:
lblEDmod1a:	Absolute
lblEDmod1b:	SBC8
			NEXTOPCODE
OpEEM1mod1:
lblEEmod1a:	Absolute
lblEEmod1b:	INC8
			NEXTOPCODE
OpEFM1mod1:
lblEFmod1a:	AbsoluteLong
lblEFmod1b:	SBC8
			NEXTOPCODE
OpF0mod1:
lblF0mod1:	OpF0
			NEXTOPCODE
OpF1M1mod1:
lblF1mod1a:	DirectIndirectIndexed1
lblF1mod1b:	SBC8
			NEXTOPCODE
OpF2M1mod1:
lblF2mod1a:	DirectIndirect
lblF2mod1b:	SBC8
			NEXTOPCODE
OpF3M1mod1:
lblF3mod1a:	StackasmRelativeIndirectIndexed1
lblF3mod1b:	SBC8
			NEXTOPCODE
OpF4mod1:
lblF4mod1:	OpF4
			NEXTOPCODE
OpF5M1mod1:
lblF5mod1a:	DirectIndexedX1
lblF5mod1b:	SBC8
			NEXTOPCODE
OpF6M1mod1:
lblF6mod1a:	DirectIndexedX1
lblF6mod1b:	INC8
			NEXTOPCODE
OpF7M1mod1:
lblF7mod1a:	DirectIndirectIndexedLong1
lblF7mod1b:	SBC8
			NEXTOPCODE
OpF8mod1:
lblF8mod1:	OpF8
			NEXTOPCODE
OpF9M1mod1:
lblF9mod1a:	AbsoluteIndexedY1
lblF9mod1b:	SBC8
			NEXTOPCODE
OpFAX1mod1:
lblFAmod1:	OpFAX1
			NEXTOPCODE
OpFBmod1:
lblFBmod1:	OpFB
			NEXTOPCODE
OpFCmod1:
lblFCmod1:	OpFCX1
			NEXTOPCODE
OpFDM1mod1:
lblFDmod1a:	AbsoluteIndexedX1
lblFDmod1b:	SBC8
			NEXTOPCODE
OpFEM1mod1:
lblFEmod1a:	AbsoluteIndexedX1
lblFEmod1b:	INC8
			NEXTOPCODE
OpFFM1mod1:
lblFFmod1a:	AbsoluteLongIndexedX1
lblFFmod1b:	SBC8
			NEXTOPCODE
.pool

			
jumptable2:		.long	Op00mod2
			.long	Op01M1mod2
			.long	Op02mod2
			.long	Op03M1mod2
			.long	Op04M1mod2
			.long	Op05M1mod2
			.long	Op06M1mod2
			.long	Op07M1mod2
			.long	Op08mod2
			.long	Op09M1mod2
			.long	Op0AM1mod2
			.long	Op0Bmod2
			.long	Op0CM1mod2
			.long	Op0DM1mod2
			.long	Op0EM1mod2
			.long	Op0FM1mod2
			.long	Op10mod2
			.long	Op11M1mod2
			.long	Op12M1mod2
			.long	Op13M1mod2
			.long	Op14M1mod2
			.long	Op15M1mod2
			.long	Op16M1mod2
			.long	Op17M1mod2
			.long	Op18mod2
			.long	Op19M1mod2
			.long	Op1AM1mod2
			.long	Op1Bmod2
			.long	Op1CM1mod2
			.long	Op1DM1mod2
			.long	Op1EM1mod2
			.long	Op1FM1mod2
			.long	Op20mod2
			.long	Op21M1mod2
			.long	Op22mod2
			.long	Op23M1mod2
			.long	Op24M1mod2
			.long	Op25M1mod2
			.long	Op26M1mod2
			.long	Op27M1mod2
			.long	Op28mod2
			.long	Op29M1mod2
			.long	Op2AM1mod2
			.long	Op2Bmod2
			.long	Op2CM1mod2
			.long	Op2DM1mod2
			.long	Op2EM1mod2
			.long	Op2FM1mod2
			.long	Op30mod2
			.long	Op31M1mod2
			.long	Op32M1mod2
			.long	Op33M1mod2
			.long	Op34M1mod2
			.long	Op35M1mod2
			.long	Op36M1mod2
			.long	Op37M1mod2
			.long	Op38mod2
			.long	Op39M1mod2
			.long	Op3AM1mod2
			.long	Op3Bmod2
			.long	Op3CM1mod2
			.long	Op3DM1mod2
			.long	Op3EM1mod2
			.long	Op3FM1mod2
			.long	Op40mod2
			.long	Op41M1mod2
			.long	Op42mod2
			.long	Op43M1mod2
			.long	Op44X0mod2
			.long	Op45M1mod2
			.long	Op46M1mod2
			.long	Op47M1mod2
			.long	Op48M1mod2
			.long	Op49M1mod2
			.long	Op4AM1mod2
			.long	Op4Bmod2
			.long	Op4Cmod2
			.long	Op4DM1mod2
			.long	Op4EM1mod2
			.long	Op4FM1mod2
			.long	Op50mod2
			.long	Op51M1mod2
			.long	Op52M1mod2
			.long	Op53M1mod2
			.long	Op54X0mod2
			.long	Op55M1mod2
			.long	Op56M1mod2
			.long	Op57M1mod2
			.long	Op58mod2
			.long	Op59M1mod2
			.long	Op5AX0mod2
			.long	Op5Bmod2
			.long	Op5Cmod2
			.long	Op5DM1mod2
			.long	Op5EM1mod2
			.long	Op5FM1mod2
			.long	Op60mod2
			.long	Op61M1mod2
			.long	Op62mod2
			.long	Op63M1mod2
			.long	Op64M1mod2
			.long	Op65M1mod2
			.long	Op66M1mod2
			.long	Op67M1mod2
			.long	Op68M1mod2
			.long	Op69M1mod2
			.long	Op6AM1mod2
			.long	Op6Bmod2
			.long	Op6Cmod2
			.long	Op6DM1mod2
			.long	Op6EM1mod2
			.long	Op6FM1mod2
			.long	Op70mod2
			.long	Op71M1mod2
			.long	Op72M1mod2
			.long	Op73M1mod2
			.long	Op74M1mod2
			.long	Op75M1mod2
			.long	Op76M1mod2
			.long	Op77M1mod2
			.long	Op78mod2
			.long	Op79M1mod2
			.long	Op7AX0mod2
			.long	Op7Bmod2
			.long	Op7Cmod2
			.long	Op7DM1mod2
			.long	Op7EM1mod2
			.long	Op7FM1mod2
			.long	Op80mod2
			.long	Op81M1mod2
			.long	Op82mod2
			.long	Op83M1mod2
			.long	Op84X0mod2
			.long	Op85M1mod2
			.long	Op86X0mod2
			.long	Op87M1mod2
			.long	Op88X0mod2
			.long	Op89M1mod2
			.long	Op8AM1mod2
			.long	Op8Bmod2
			.long	Op8CX0mod2
			.long	Op8DM1mod2
			.long	Op8EX0mod2
			.long	Op8FM1mod2
			.long	Op90mod2
			.long	Op91M1mod2
			.long	Op92M1mod2
			.long	Op93M1mod2
			.long	Op94X0mod2
			.long	Op95M1mod2
			.long	Op96X0mod2
			.long	Op97M1mod2
			.long	Op98M1mod2
			.long	Op99M1mod2
			.long	Op9Amod2
			.long	Op9BX0mod2
			.long	Op9CM1mod2
			.long	Op9DM1mod2
			.long	Op9EM1mod2
			.long	Op9FM1mod2
			.long	OpA0X0mod2
			.long	OpA1M1mod2
			.long	OpA2X0mod2
			.long	OpA3M1mod2
			.long	OpA4X0mod2
			.long	OpA5M1mod2
			.long	OpA6X0mod2
			.long	OpA7M1mod2
			.long	OpA8X0mod2
			.long	OpA9M1mod2
			.long	OpAAX0mod2
			.long	OpABmod2
			.long	OpACX0mod2
			.long	OpADM1mod2
			.long	OpAEX0mod2
			.long	OpAFM1mod2
			.long	OpB0mod2
			.long	OpB1M1mod2
			.long	OpB2M1mod2
			.long	OpB3M1mod2
			.long	OpB4X0mod2
			.long	OpB5M1mod2
			.long	OpB6X0mod2
			.long	OpB7M1mod2
			.long	OpB8mod2
			.long	OpB9M1mod2
			.long	OpBAX0mod2
			.long	OpBBX0mod2
			.long	OpBCX0mod2
			.long	OpBDM1mod2
			.long	OpBEX0mod2
			.long	OpBFM1mod2
			.long	OpC0X0mod2
			.long	OpC1M1mod2
			.long	OpC2mod2
			.long	OpC3M1mod2
			.long	OpC4X0mod2
			.long	OpC5M1mod2
			.long	OpC6M1mod2
			.long	OpC7M1mod2
			.long	OpC8X0mod2
			.long	OpC9M1mod2
			.long	OpCAX0mod2
			.long	OpCBmod2
			.long	OpCCX0mod2
			.long	OpCDM1mod2
			.long	OpCEM1mod2
			.long	OpCFM1mod2
			.long	OpD0mod2
			.long	OpD1M1mod2
			.long	OpD2M1mod2
			.long	OpD3M1mod2
			.long	OpD4mod2
			.long	OpD5M1mod2
			.long	OpD6M1mod2
			.long	OpD7M1mod2
			.long	OpD8mod2
			.long	OpD9M1mod2
			.long	OpDAX0mod2
			.long	OpDBmod2
			.long	OpDCmod2
			.long	OpDDM1mod2
			.long	OpDEM1mod2
			.long	OpDFM1mod2
			.long	OpE0X0mod2
			.long	OpE1M1mod2
			.long	OpE2mod2
			.long	OpE3M1mod2
			.long	OpE4X0mod2
			.long	OpE5M1mod2
			.long	OpE6M1mod2
			.long	OpE7M1mod2
			.long	OpE8X0mod2
			.long	OpE9M1mod2
			.long	OpEAmod2
			.long	OpEBmod2
			.long	OpECX0mod2
			.long	OpEDM1mod2
			.long	OpEEM1mod2
			.long	OpEFM1mod2
			.long	OpF0mod2
			.long	OpF1M1mod2
			.long	OpF2M1mod2
			.long	OpF3M1mod2
			.long	OpF4mod2
			.long	OpF5M1mod2
			.long	OpF6M1mod2
			.long	OpF7M1mod2
			.long	OpF8mod2
			.long	OpF9M1mod2
			.long	OpFAX0mod2
			.long	OpFBmod2
			.long	OpFCmod2
			.long	OpFDM1mod2
			.long	OpFEM1mod2
			.long	OpFFM1mod2
Op00mod2:
lbl00mod2:	Op00
			NEXTOPCODE
Op01M1mod2:
lbl01mod2a:	DirectIndexedIndirect0
lbl01mod2b:	ORA8
			NEXTOPCODE
Op02mod2:
lbl02mod2:	Op02
			NEXTOPCODE
Op03M1mod2:
lbl03mod2a:	StackasmRelative
lbl03mod2b:	ORA8
			NEXTOPCODE
Op04M1mod2:
lbl04mod2a:	Direct
lbl04mod2b:	TSB8
			NEXTOPCODE
Op05M1mod2:
lbl05mod2a:	Direct
lbl05mod2b:	ORA8
			NEXTOPCODE
Op06M1mod2:
lbl06mod2a:	Direct
lbl06mod2b:	ASL8
			NEXTOPCODE
Op07M1mod2:
lbl07mod2a:	DirectIndirectLong
lbl07mod2b:	ORA8
			NEXTOPCODE
Op08mod2:
lbl08mod2:	Op08
			NEXTOPCODE
Op09M1mod2:
lbl09mod2:	Op09M1
			NEXTOPCODE
Op0AM1mod2:
lbl0Amod2a:	A_ASL8
			NEXTOPCODE
Op0Bmod2:
lbl0Bmod2:	Op0B
			NEXTOPCODE
Op0CM1mod2:
lbl0Cmod2a:	Absolute
lbl0Cmod2b:	TSB8
			NEXTOPCODE
Op0DM1mod2:
lbl0Dmod2a:	Absolute
lbl0Dmod2b:	ORA8
			NEXTOPCODE
Op0EM1mod2:
lbl0Emod2a:	Absolute
lbl0Emod2b:	ASL8
			NEXTOPCODE
Op0FM1mod2:
lbl0Fmod2a:	AbsoluteLong
lbl0Fmod2b:	ORA8
			NEXTOPCODE
Op10mod2:
lbl10mod2:	Op10
			NEXTOPCODE
Op11M1mod2:
lbl11mod2a:	DirectIndirectIndexed0
lbl11mod2b:	ORA8
			NEXTOPCODE
Op12M1mod2:
lbl12mod2a:	DirectIndirect
lbl12mod2b:	ORA8
			NEXTOPCODE
Op13M1mod2:
lbl13mod2a:	StackasmRelativeIndirectIndexed0
lbl13mod2b:	ORA8
			NEXTOPCODE
Op14M1mod2:
lbl14mod2a:	Direct
lbl14mod2b:	TRB8
			NEXTOPCODE
Op15M1mod2:
lbl15mod2a:	DirectIndexedX0
lbl15mod2b:	ORA8
			NEXTOPCODE
Op16M1mod2:
lbl16mod2a:	DirectIndexedX0
lbl16mod2b:	ASL8
			NEXTOPCODE
Op17M1mod2:
lbl17mod2a:	DirectIndirectIndexedLong0
lbl17mod2b:	ORA8
			NEXTOPCODE
Op18mod2:
lbl18mod2:	Op18
			NEXTOPCODE
Op19M1mod2:
lbl19mod2a:	AbsoluteIndexedY0
lbl19mod2b:	ORA8
			NEXTOPCODE
Op1AM1mod2:
lbl1Amod2a:	A_INC8
			NEXTOPCODE
Op1Bmod2:
lbl1Bmod2:	Op1BM1
			NEXTOPCODE
Op1CM1mod2:
lbl1Cmod2a:	Absolute
lbl1Cmod2b:	TRB8
			NEXTOPCODE
Op1DM1mod2:
lbl1Dmod2a:	AbsoluteIndexedX0
lbl1Dmod2b:	ORA8
			NEXTOPCODE
Op1EM1mod2:
lbl1Emod2a:	AbsoluteIndexedX0
lbl1Emod2b:	ASL8
			NEXTOPCODE
Op1FM1mod2:
lbl1Fmod2a:	AbsoluteLongIndexedX0
lbl1Fmod2b:	ORA8
			NEXTOPCODE
Op20mod2:
lbl20mod2:	Op20
			NEXTOPCODE
Op21M1mod2:
lbl21mod2a:	DirectIndexedIndirect0
lbl21mod2b:	AND8
			NEXTOPCODE
Op22mod2:
lbl22mod2:	Op22
			NEXTOPCODE
Op23M1mod2:
lbl23mod2a:	StackasmRelative
lbl23mod2b:	AND8
			NEXTOPCODE
Op24M1mod2:
lbl24mod2a:	Direct
lbl24mod2b:	BIT8
			NEXTOPCODE
Op25M1mod2:
lbl25mod2a:	Direct
lbl25mod2b:	AND8
			NEXTOPCODE
Op26M1mod2:
lbl26mod2a:	Direct
lbl26mod2b:	ROL8
			NEXTOPCODE
Op27M1mod2:
lbl27mod2a:	DirectIndirectLong
lbl27mod2b:	AND8
			NEXTOPCODE
Op28mod2:
lbl28mod2:	Op28X0M1
			NEXTOPCODE
.pool
Op29M1mod2:
lbl29mod2:	Op29M1
			NEXTOPCODE
Op2AM1mod2:
lbl2Amod2a:	A_ROL8
			NEXTOPCODE
Op2Bmod2:
lbl2Bmod2:	Op2B
			NEXTOPCODE
Op2CM1mod2:
lbl2Cmod2a:	Absolute
lbl2Cmod2b:	BIT8
			NEXTOPCODE
Op2DM1mod2:
lbl2Dmod2a:	Absolute
lbl2Dmod2b:	AND8
			NEXTOPCODE
Op2EM1mod2:
lbl2Emod2a:	Absolute
lbl2Emod2b:	ROL8
			NEXTOPCODE
Op2FM1mod2:
lbl2Fmod2a:	AbsoluteLong
lbl2Fmod2b:	AND8
			NEXTOPCODE
Op30mod2:
lbl30mod2:	Op30
			NEXTOPCODE
Op31M1mod2:
lbl31mod2a:	DirectIndirectIndexed0
lbl31mod2b:	AND8
			NEXTOPCODE
Op32M1mod2:
lbl32mod2a:	DirectIndirect
lbl32mod2b:	AND8
			NEXTOPCODE
Op33M1mod2:
lbl33mod2a:	StackasmRelativeIndirectIndexed0
lbl33mod2b:	AND8
			NEXTOPCODE
Op34M1mod2:
lbl34mod2a:	DirectIndexedX0
lbl34mod2b:	BIT8
			NEXTOPCODE
Op35M1mod2:
lbl35mod2a:	DirectIndexedX0
lbl35mod2b:	AND8
			NEXTOPCODE
Op36M1mod2:
lbl36mod2a:	DirectIndexedX0
lbl36mod2b:	ROL8
			NEXTOPCODE
Op37M1mod2:
lbl37mod2a:	DirectIndirectIndexedLong0
lbl37mod2b:	AND8
			NEXTOPCODE
Op38mod2:
lbl38mod2:	Op38
			NEXTOPCODE
Op39M1mod2:
lbl39mod2a:	AbsoluteIndexedY0
lbl39mod2b:	AND8
			NEXTOPCODE
Op3AM1mod2:
lbl3Amod2a:	A_DEC8
			NEXTOPCODE
Op3Bmod2:
lbl3Bmod2:	Op3BM1
			NEXTOPCODE
Op3CM1mod2:
lbl3Cmod2a:	AbsoluteIndexedX0
lbl3Cmod2b:	BIT8
			NEXTOPCODE
Op3DM1mod2:
lbl3Dmod2a:	AbsoluteIndexedX0
lbl3Dmod2b:	AND8
			NEXTOPCODE
Op3EM1mod2:
lbl3Emod2a:	AbsoluteIndexedX0
lbl3Emod2b:	ROL8
			NEXTOPCODE
Op3FM1mod2:
lbl3Fmod2a:	AbsoluteLongIndexedX0
lbl3Fmod2b:	AND8
			NEXTOPCODE
Op40mod2:
lbl40mod2:	Op40X0M1
			NEXTOPCODE
.pool						
Op41M1mod2:
lbl41mod2a:	DirectIndexedIndirect0
lbl41mod2b:	EOR8
			NEXTOPCODE
Op42mod2:
lbl42mod2:	Op42
			NEXTOPCODE
Op43M1mod2:
lbl43mod2a:	StackasmRelative
lbl43mod2b:	EOR8
			NEXTOPCODE
Op44X0mod2:
lbl44mod2:	Op44X0M1
			NEXTOPCODE
Op45M1mod2:
lbl45mod2a:	Direct
lbl45mod2b:	EOR8
			NEXTOPCODE
Op46M1mod2:
lbl46mod2a:	Direct
lbl46mod2b:	LSR8
			NEXTOPCODE
Op47M1mod2:
lbl47mod2a:	DirectIndirectLong
lbl47mod2b:	EOR8
			NEXTOPCODE
Op48M1mod2:
lbl48mod2:	Op48M1
			NEXTOPCODE
Op49M1mod2:
lbl49mod2:	Op49M1
			NEXTOPCODE
Op4AM1mod2:
lbl4Amod2a:	A_LSR8
			NEXTOPCODE
Op4Bmod2:
lbl4Bmod2:	Op4B
			NEXTOPCODE
Op4Cmod2:
lbl4Cmod2:	Op4C
			NEXTOPCODE
Op4DM1mod2:
lbl4Dmod2a:	Absolute
lbl4Dmod2b:	EOR8
			NEXTOPCODE
Op4EM1mod2:
lbl4Emod2a:	Absolute
lbl4Emod2b:	LSR8
			NEXTOPCODE
Op4FM1mod2:
lbl4Fmod2a:	AbsoluteLong
lbl4Fmod2b:	EOR8
			NEXTOPCODE
Op50mod2:
lbl50mod2:	Op50
			NEXTOPCODE
Op51M1mod2:
lbl51mod2a:	DirectIndirectIndexed0
lbl51mod2b:	EOR8
			NEXTOPCODE
Op52M1mod2:
lbl52mod2a:	DirectIndirect
lbl52mod2b:	EOR8
			NEXTOPCODE
Op53M1mod2:
lbl53mod2a:	StackasmRelativeIndirectIndexed0
lbl53mod2b:	EOR8
			NEXTOPCODE
Op54X0mod2:
lbl54mod2:	Op54X0M1
			NEXTOPCODE
Op55M1mod2:
lbl55mod2a:	DirectIndexedX0
lbl55mod2b:	EOR8
			NEXTOPCODE
Op56M1mod2:
lbl56mod2a:	DirectIndexedX0
lbl56mod2b:	LSR8
			NEXTOPCODE
Op57M1mod2:
lbl57mod2a:	DirectIndirectIndexedLong0
lbl57mod2b:	EOR8
			NEXTOPCODE
Op58mod2:
lbl58mod2:	Op58
			NEXTOPCODE
Op59M1mod2:
lbl59mod2a:	AbsoluteIndexedY0
lbl59mod2b:	EOR8
			NEXTOPCODE
Op5AX0mod2:
lbl5Amod2:	Op5AX0
			NEXTOPCODE
Op5Bmod2:
lbl5Bmod2:	Op5BM1
			NEXTOPCODE
Op5Cmod2:
lbl5Cmod2:	Op5C
			NEXTOPCODE
Op5DM1mod2:
lbl5Dmod2a:	AbsoluteIndexedX0
lbl5Dmod2b:	EOR8
			NEXTOPCODE
Op5EM1mod2:
lbl5Emod2a:	AbsoluteIndexedX0
lbl5Emod2b:	LSR8
			NEXTOPCODE
Op5FM1mod2:
lbl5Fmod2a:	AbsoluteLongIndexedX0
lbl5Fmod2b:	EOR8
			NEXTOPCODE
Op60mod2:
lbl60mod2:	Op60
			NEXTOPCODE
Op61M1mod2:
lbl61mod2a:	DirectIndexedIndirect0
lbl61mod2b:	ADC8
			NEXTOPCODE
Op62mod2:
lbl62mod2:	Op62
			NEXTOPCODE
Op63M1mod2:
lbl63mod2a:	StackasmRelative
lbl63mod2b:	ADC8
			NEXTOPCODE
Op64M1mod2:
lbl64mod2a:	Direct
lbl64mod2b:	STZ8
			NEXTOPCODE
Op65M1mod2:
lbl65mod2a:	Direct
lbl65mod2b:	ADC8
			NEXTOPCODE
Op66M1mod2:
lbl66mod2a:	Direct
lbl66mod2b:	ROR8
			NEXTOPCODE
Op67M1mod2:
lbl67mod2a:	DirectIndirectLong
lbl67mod2b:	ADC8
			NEXTOPCODE
Op68M1mod2:
lbl68mod2:	Op68M1
			NEXTOPCODE
Op69M1mod2:
lbl69mod2a:	Immediate8
lbl69mod2b:	ADC8
			NEXTOPCODE
Op6AM1mod2:
lbl6Amod2a:	A_ROR8
			NEXTOPCODE
Op6Bmod2:
lbl6Bmod2:	Op6B
			NEXTOPCODE
Op6Cmod2:
lbl6Cmod2:	Op6C
			NEXTOPCODE
Op6DM1mod2:
lbl6Dmod2a:	Absolute
lbl6Dmod2b:	ADC8
			NEXTOPCODE
Op6EM1mod2:
lbl6Emod2a:	Absolute
lbl6Emod2b:	ROR8
			NEXTOPCODE
Op6FM1mod2:
lbl6Fmod2a:	AbsoluteLong
lbl6Fmod2b:	ADC8
			NEXTOPCODE
Op70mod2:
lbl70mod2:	Op70
			NEXTOPCODE
Op71M1mod2:
lbl71mod2a:	DirectIndirectIndexed0
lbl71mod2b:	ADC8
			NEXTOPCODE
Op72M1mod2:
lbl72mod2a:	DirectIndirect
lbl72mod2b:	ADC8
			NEXTOPCODE
Op73M1mod2:
lbl73mod2a:	StackasmRelativeIndirectIndexed0
lbl73mod2b:	ADC8
			NEXTOPCODE
Op74M1mod2:
lbl74mod2a:	DirectIndexedX0
lbl74mod2b:	STZ8
			NEXTOPCODE
Op75M1mod2:
lbl75mod2a:	DirectIndexedX0
lbl75mod2b:	ADC8
			NEXTOPCODE
Op76M1mod2:
lbl76mod2a:	DirectIndexedX0
lbl76mod2b:	ROR8
			NEXTOPCODE
Op77M1mod2:
lbl77mod2a:	DirectIndirectIndexedLong0
lbl77mod2b:	ADC8
			NEXTOPCODE
Op78mod2:
lbl78mod2:	Op78
			NEXTOPCODE
Op79M1mod2:
lbl79mod2a:	AbsoluteIndexedY0
lbl79mod2b:	ADC8
			NEXTOPCODE
Op7AX0mod2:
lbl7Amod2:	Op7AX0
			NEXTOPCODE
Op7Bmod2:
lbl7Bmod2:	Op7BM1
			NEXTOPCODE
Op7Cmod2:
lbl7Cmod2:	AbsoluteIndexedIndirectX0
		Op7C
			NEXTOPCODE
Op7DM1mod2:
lbl7Dmod2a:	AbsoluteIndexedX0
lbl7Dmod2b:	ADC8
			NEXTOPCODE
Op7EM1mod2:
lbl7Emod2a:	AbsoluteIndexedX0
lbl7Emod2b:	ROR8
			NEXTOPCODE
Op7FM1mod2:
lbl7Fmod2a:	AbsoluteLongIndexedX0
lbl7Fmod2b:	ADC8
			NEXTOPCODE


Op80mod2:
lbl80mod2:	Op80
			NEXTOPCODE
Op81M1mod2:
lbl81mod2a:	DirectIndexedIndirect0
lbl81mod2b:	Op81M1
			NEXTOPCODE
Op82mod2:
lbl82mod2:	Op82
			NEXTOPCODE
Op83M1mod2:
lbl83mod2a:	StackasmRelative
lbl83mod2b:	STA8
			NEXTOPCODE
Op84X0mod2:
lbl84mod2a:	Direct
lbl84mod2b:	STY16
			NEXTOPCODE
Op85M1mod2:
lbl85mod2a:	Direct
lbl85mod2b:	STA8
			NEXTOPCODE
Op86X0mod2:
lbl86mod2a:	Direct
lbl86mod2b:	STX16
			NEXTOPCODE
Op87M1mod2:
lbl87mod2a:	DirectIndirectLong
lbl87mod2b:	STA8
			NEXTOPCODE
Op88X0mod2:
lbl88mod2:	Op88X0
			NEXTOPCODE
Op89M1mod2:
lbl89mod2:	Op89M1
			NEXTOPCODE
Op8AM1mod2:
lbl8Amod2:	Op8AM1X0
			NEXTOPCODE
Op8Bmod2:
lbl8Bmod2:	Op8B
			NEXTOPCODE
Op8CX0mod2:
lbl8Cmod2a:	Absolute
lbl8Cmod2b:	STY16
			NEXTOPCODE
Op8DM1mod2:
lbl8Dmod2a:	Absolute
lbl8Dmod2b:	STA8
			NEXTOPCODE
Op8EX0mod2:
lbl8Emod2a:	Absolute
lbl8Emod2b:	STX16
			NEXTOPCODE
Op8FM1mod2:
lbl8Fmod2a:	AbsoluteLong
lbl8Fmod2b:	STA8
			NEXTOPCODE
Op90mod2:
lbl90mod2:	Op90
			NEXTOPCODE
Op91M1mod2:
lbl91mod2a:	DirectIndirectIndexed0
lbl91mod2b:	STA8
			NEXTOPCODE
Op92M1mod2:
lbl92mod2a:	DirectIndirect
lbl92mod2b:	STA8
			NEXTOPCODE
Op93M1mod2:
lbl93mod2a:	StackasmRelativeIndirectIndexed0
lbl93mod2b:	STA8
			NEXTOPCODE
Op94X0mod2:
lbl94mod2a:	DirectIndexedX0
lbl94mod2b:	STY16
			NEXTOPCODE
Op95M1mod2:
lbl95mod2a:	DirectIndexedX0
lbl95mod2b:	STA8
			NEXTOPCODE
Op96X0mod2:
lbl96mod2a:	DirectIndexedY0
lbl96mod2b:	STX16
			NEXTOPCODE
Op97M1mod2:
lbl97mod2a:	DirectIndirectIndexedLong0
lbl97mod2b:	STA8
			NEXTOPCODE
Op98M1mod2:
lbl98mod2:	Op98M1X0
			NEXTOPCODE
Op99M1mod2:
lbl99mod2a:	AbsoluteIndexedY0
lbl99mod2b:	STA8
			NEXTOPCODE
Op9Amod2:
lbl9Amod2:	Op9AX0
			NEXTOPCODE
Op9BX0mod2:
lbl9Bmod2:	Op9BX0
			NEXTOPCODE
Op9CM1mod2:
lbl9Cmod2a:	Absolute
lbl9Cmod2b:	STZ8
			NEXTOPCODE
Op9DM1mod2:
lbl9Dmod2a:	AbsoluteIndexedX0
lbl9Dmod2b:	STA8
			NEXTOPCODE
Op9EM1mod2:	
lbl9Emod2:	AbsoluteIndexedX0		
		STZ8
			NEXTOPCODE
Op9FM1mod2:
lbl9Fmod2a:	AbsoluteLongIndexedX0
lbl9Fmod2b:	STA8
			NEXTOPCODE
OpA0X0mod2:
lblA0mod2:	OpA0X0
			NEXTOPCODE
OpA1M1mod2:
lblA1mod2a:	DirectIndexedIndirect0
lblA1mod2b:	LDA8
			NEXTOPCODE
OpA2X0mod2:
lblA2mod2:	OpA2X0
			NEXTOPCODE
OpA3M1mod2:
lblA3mod2a:	StackasmRelative
lblA3mod2b:	LDA8
			NEXTOPCODE
OpA4X0mod2:
lblA4mod2a:	Direct
lblA4mod2b:	LDY16
			NEXTOPCODE
OpA5M1mod2:
lblA5mod2a:	Direct
lblA5mod2b:	LDA8
			NEXTOPCODE
OpA6X0mod2:
lblA6mod2a:	Direct
lblA6mod2b:	LDX16
			NEXTOPCODE
OpA7M1mod2:
lblA7mod2a:	DirectIndirectLong
lblA7mod2b:	LDA8
			NEXTOPCODE
OpA8X0mod2:
lblA8mod2:	OpA8X0M1
			NEXTOPCODE
OpA9M1mod2:
lblA9mod2:	OpA9M1
			NEXTOPCODE
OpAAX0mod2:
lblAAmod2:	OpAAX0M1
			NEXTOPCODE
OpABmod2:
lblABmod2:	OpAB
			NEXTOPCODE
OpACX0mod2:
lblACmod2a:	Absolute
lblACmod2b:	LDY16
			NEXTOPCODE
OpADM1mod2:
lblADmod2a:	Absolute
lblADmod2b:	LDA8
			NEXTOPCODE
OpAEX0mod2:
lblAEmod2a:	Absolute
lblAEmod2b:	LDX16
			NEXTOPCODE
OpAFM1mod2:
lblAFmod2a:	AbsoluteLong
lblAFmod2b:	LDA8
			NEXTOPCODE
OpB0mod2:
lblB0mod2:	OpB0
			NEXTOPCODE
OpB1M1mod2:
lblB1mod2a:	DirectIndirectIndexed0
lblB1mod2b:	LDA8
			NEXTOPCODE
OpB2M1mod2:
lblB2mod2a:	DirectIndirect
lblB2mod2b:	LDA8
			NEXTOPCODE
OpB3M1mod2:
lblB3mod2a:	StackasmRelativeIndirectIndexed0
lblB3mod2b:	LDA8
			NEXTOPCODE
OpB4X0mod2:
lblB4mod2a:	DirectIndexedX0
lblB4mod2b:	LDY16
			NEXTOPCODE
OpB5M1mod2:
lblB5mod2a:	DirectIndexedX0
lblB5mod2b:	LDA8
			NEXTOPCODE
OpB6X0mod2:
lblB6mod2a:	DirectIndexedY0
lblB6mod2b:	LDX16
			NEXTOPCODE
OpB7M1mod2:
lblB7mod2a:	DirectIndirectIndexedLong0
lblB7mod2b:	LDA8
			NEXTOPCODE
OpB8mod2:
lblB8mod2:	OpB8
			NEXTOPCODE
OpB9M1mod2:
lblB9mod2a:	AbsoluteIndexedY0
lblB9mod2b:	LDA8
			NEXTOPCODE
OpBAX0mod2:
lblBAmod2:	OpBAX0
			NEXTOPCODE
OpBBX0mod2:
lblBBmod2:	OpBBX0
			NEXTOPCODE
OpBCX0mod2:
lblBCmod2a:	AbsoluteIndexedX0
lblBCmod2b:	LDY16
			NEXTOPCODE
OpBDM1mod2:
lblBDmod2a:	AbsoluteIndexedX0
lblBDmod2b:	LDA8
			NEXTOPCODE
OpBEX0mod2:
lblBEmod2a:	AbsoluteIndexedY0
lblBEmod2b:	LDX16
			NEXTOPCODE
OpBFM1mod2:
lblBFmod2a:	AbsoluteLongIndexedX0
lblBFmod2b:	LDA8
			NEXTOPCODE
OpC0X0mod2:
lblC0mod2:	OpC0X0
			NEXTOPCODE
OpC1M1mod2:
lblC1mod2a:	DirectIndexedIndirect0
lblC1mod2b:	CMP8
			NEXTOPCODE
OpC2mod2:
lblC2mod2:	OpC2
			NEXTOPCODE
.pool
OpC3M1mod2:
lblC3mod2a:	StackasmRelative
lblC3mod2b:	CMP8
			NEXTOPCODE
OpC4X0mod2:
lblC4mod2a:	Direct
lblC4mod2b:	CMY16
			NEXTOPCODE
OpC5M1mod2:
lblC5mod2a:	Direct
lblC5mod2b:	CMP8
			NEXTOPCODE
OpC6M1mod2:
lblC6mod2a:	Direct
lblC6mod2b:	DEC8
			NEXTOPCODE
OpC7M1mod2:
lblC7mod2a:	DirectIndirectLong
lblC7mod2b:	CMP8
			NEXTOPCODE
OpC8X0mod2:
lblC8mod2:	OpC8X0
			NEXTOPCODE
OpC9M1mod2:
lblC9mod2:	OpC9M1
			NEXTOPCODE
OpCAX0mod2:
lblCAmod2:	OpCAX0
			NEXTOPCODE
OpCBmod2:
lblCBmod2:	OpCB
			NEXTOPCODE
OpCCX0mod2:
lblCCmod2a:	Absolute
lblCCmod2b:	CMY16
			NEXTOPCODE
OpCDM1mod2:
lblCDmod2a:	Absolute
lblCDmod2b:	CMP8
			NEXTOPCODE
OpCEM1mod2:
lblCEmod2a:	Absolute
lblCEmod2b:	DEC8
			NEXTOPCODE
OpCFM1mod2:
lblCFmod2a:	AbsoluteLong
lblCFmod2b:	CMP8
			NEXTOPCODE
OpD0mod2:
lblD0mod2:	OpD0
			NEXTOPCODE
OpD1M1mod2:
lblD1mod2a:	DirectIndirectIndexed0
lblD1mod2b:	CMP8
			NEXTOPCODE
OpD2M1mod2:
lblD2mod2a:	DirectIndirect
lblD2mod2b:	CMP8
			NEXTOPCODE
OpD3M1mod2:
lblD3mod2a:	StackasmRelativeIndirectIndexed0
lblD3mod2b:	CMP8
			NEXTOPCODE
OpD4mod2:
lblD4mod2:	OpD4
			NEXTOPCODE
OpD5M1mod2:
lblD5mod2a:	DirectIndexedX0
lblD5mod2b:	CMP8
			NEXTOPCODE
OpD6M1mod2:
lblD6mod2a:	DirectIndexedX0
lblD6mod2b:	DEC8
			NEXTOPCODE
OpD7M1mod2:
lblD7mod2a:	DirectIndirectIndexedLong0
lblD7mod2b:	CMP8
			NEXTOPCODE
OpD8mod2:
lblD8mod2:	OpD8
			NEXTOPCODE
OpD9M1mod2:
lblD9mod2a:	AbsoluteIndexedY0
lblD9mod2b:	CMP8
			NEXTOPCODE
OpDAX0mod2:
lblDAmod2:	OpDAX0
			NEXTOPCODE
OpDBmod2:
lblDBmod2:	OpDB
			NEXTOPCODE
OpDCmod2:
lblDCmod2:	OpDC
			NEXTOPCODE
OpDDM1mod2:
lblDDmod2a:	AbsoluteIndexedX0
lblDDmod2b:	CMP8
			NEXTOPCODE
OpDEM1mod2:
lblDEmod2a:	AbsoluteIndexedX0
lblDEmod2b:	DEC8
			NEXTOPCODE
OpDFM1mod2:
lblDFmod2a:	AbsoluteLongIndexedX0
lblDFmod2b:	CMP8
			NEXTOPCODE
OpE0X0mod2:
lblE0mod2:	OpE0X0
			NEXTOPCODE
OpE1M1mod2:
lblE1mod2a:	DirectIndexedIndirect0
lblE1mod2b:	SBC8
			NEXTOPCODE
OpE2mod2:
lblE2mod2:	OpE2
			NEXTOPCODE
.pool
OpE3M1mod2:
lblE3mod2a:	StackasmRelative
lblE3mod2b:	SBC8
			NEXTOPCODE
OpE4X0mod2:
lblE4mod2a:	Direct
lblE4mod2b:	CMX16
			NEXTOPCODE
OpE5M1mod2:
lblE5mod2a:	Direct
lblE5mod2b:	SBC8
			NEXTOPCODE
OpE6M1mod2:
lblE6mod2a:	Direct
lblE6mod2b:	INC8
			NEXTOPCODE
OpE7M1mod2:
lblE7mod2a:	DirectIndirectLong
lblE7mod2b:	SBC8
			NEXTOPCODE
OpE8X0mod2:
lblE8mod2:	OpE8X0
			NEXTOPCODE
OpE9M1mod2:
lblE9mod2a:	Immediate8
lblE9mod2b:	SBC8
			NEXTOPCODE
OpEAmod2:
lblEAmod2:	OpEA
			NEXTOPCODE
OpEBmod2:
lblEBmod2:	OpEBM1
			NEXTOPCODE
OpECX0mod2:
lblECmod2a:	Absolute
lblECmod2b:	CMX16
			NEXTOPCODE
OpEDM1mod2:
lblEDmod2a:	Absolute
lblEDmod2b:	SBC8
			NEXTOPCODE
OpEEM1mod2:
lblEEmod2a:	Absolute
lblEEmod2b:	INC8
			NEXTOPCODE
OpEFM1mod2:
lblEFmod2a:	AbsoluteLong
lblEFmod2b:	SBC8
			NEXTOPCODE
OpF0mod2:
lblF0mod2:	OpF0
			NEXTOPCODE
OpF1M1mod2:
lblF1mod2a:	DirectIndirectIndexed0
lblF1mod2b:	SBC8
			NEXTOPCODE
OpF2M1mod2:
lblF2mod2a:	DirectIndirect
lblF2mod2b:	SBC8
			NEXTOPCODE
OpF3M1mod2:
lblF3mod2a:	StackasmRelativeIndirectIndexed0
lblF3mod2b:	SBC8
			NEXTOPCODE
OpF4mod2:
lblF4mod2:	OpF4
			NEXTOPCODE
OpF5M1mod2:
lblF5mod2a:	DirectIndexedX0
lblF5mod2b:	SBC8
			NEXTOPCODE
OpF6M1mod2:
lblF6mod2a:	DirectIndexedX0
lblF6mod2b:	INC8
			NEXTOPCODE
OpF7M1mod2:
lblF7mod2a:	DirectIndirectIndexedLong0
lblF7mod2b:	SBC8
			NEXTOPCODE
OpF8mod2:
lblF8mod2:	OpF8
			NEXTOPCODE
OpF9M1mod2:
lblF9mod2a:	AbsoluteIndexedY0
lblF9mod2b:	SBC8
			NEXTOPCODE
OpFAX0mod2:
lblFAmod2:	OpFAX0
			NEXTOPCODE
OpFBmod2:
lblFBmod2:	OpFB
			NEXTOPCODE
OpFCmod2:
lblFCmod2:	OpFCX0
			NEXTOPCODE
OpFDM1mod2:
lblFDmod2a:	AbsoluteIndexedX0
lblFDmod2b:	SBC8
			NEXTOPCODE
OpFEM1mod2:
lblFEmod2a:	AbsoluteIndexedX0
lblFEmod2b:	INC8
			NEXTOPCODE
OpFFM1mod2:
lblFFmod2a:	AbsoluteLongIndexedX0
lblFFmod2b:	SBC8
			NEXTOPCODE

.pool


jumptable3:		.long	Op00mod3
			.long	Op01M0mod3
			.long	Op02mod3
			.long	Op03M0mod3
			.long	Op04M0mod3
			.long	Op05M0mod3
			.long	Op06M0mod3
			.long	Op07M0mod3
			.long	Op08mod3
			.long	Op09M0mod3
			.long	Op0AM0mod3
			.long	Op0Bmod3
			.long	Op0CM0mod3
			.long	Op0DM0mod3
			.long	Op0EM0mod3
			.long	Op0FM0mod3
			.long	Op10mod3
			.long	Op11M0mod3
			.long	Op12M0mod3
			.long	Op13M0mod3
			.long	Op14M0mod3
			.long	Op15M0mod3
			.long	Op16M0mod3
			.long	Op17M0mod3
			.long	Op18mod3
			.long	Op19M0mod3
			.long	Op1AM0mod3
			.long	Op1Bmod3
			.long	Op1CM0mod3
			.long	Op1DM0mod3
			.long	Op1EM0mod3
			.long	Op1FM0mod3
			.long	Op20mod3
			.long	Op21M0mod3
			.long	Op22mod3
			.long	Op23M0mod3
			.long	Op24M0mod3
			.long	Op25M0mod3
			.long	Op26M0mod3
			.long	Op27M0mod3
			.long	Op28mod3
			.long	Op29M0mod3
			.long	Op2AM0mod3
			.long	Op2Bmod3
			.long	Op2CM0mod3
			.long	Op2DM0mod3
			.long	Op2EM0mod3
			.long	Op2FM0mod3
			.long	Op30mod3
			.long	Op31M0mod3
			.long	Op32M0mod3
			.long	Op33M0mod3
			.long	Op34M0mod3
			.long	Op35M0mod3
			.long	Op36M0mod3
			.long	Op37M0mod3
			.long	Op38mod3
			.long	Op39M0mod3
			.long	Op3AM0mod3
			.long	Op3Bmod3
			.long	Op3CM0mod3
			.long	Op3DM0mod3
			.long	Op3EM0mod3
			.long	Op3FM0mod3
			.long	Op40mod3
			.long	Op41M0mod3
			.long	Op42mod3
			.long	Op43M0mod3
			.long	Op44X0mod3
			.long	Op45M0mod3
			.long	Op46M0mod3
			.long	Op47M0mod3
			.long	Op48M0mod3
			.long	Op49M0mod3
			.long	Op4AM0mod3
			.long	Op4Bmod3
			.long	Op4Cmod3
			.long	Op4DM0mod3
			.long	Op4EM0mod3
			.long	Op4FM0mod3
			.long	Op50mod3
			.long	Op51M0mod3
			.long	Op52M0mod3
			.long	Op53M0mod3
			.long	Op54X0mod3
			.long	Op55M0mod3
			.long	Op56M0mod3
			.long	Op57M0mod3
			.long	Op58mod3
			.long	Op59M0mod3
			.long	Op5AX0mod3
			.long	Op5Bmod3
			.long	Op5Cmod3
			.long	Op5DM0mod3
			.long	Op5EM0mod3
			.long	Op5FM0mod3
			.long	Op60mod3
			.long	Op61M0mod3
			.long	Op62mod3
			.long	Op63M0mod3
			.long	Op64M0mod3
			.long	Op65M0mod3
			.long	Op66M0mod3
			.long	Op67M0mod3
			.long	Op68M0mod3
			.long	Op69M0mod3
			.long	Op6AM0mod3
			.long	Op6Bmod3
			.long	Op6Cmod3
			.long	Op6DM0mod3
			.long	Op6EM0mod3
			.long	Op6FM0mod3
			.long	Op70mod3
			.long	Op71M0mod3
			.long	Op72M0mod3
			.long	Op73M0mod3
			.long	Op74M0mod3
			.long	Op75M0mod3
			.long	Op76M0mod3
			.long	Op77M0mod3
			.long	Op78mod3
			.long	Op79M0mod3
			.long	Op7AX0mod3
			.long	Op7Bmod3
			.long	Op7Cmod3
			.long	Op7DM0mod3
			.long	Op7EM0mod3
			.long	Op7FM0mod3
			.long	Op80mod3
			.long	Op81M0mod3
			.long	Op82mod3
			.long	Op83M0mod3
			.long	Op84X0mod3
			.long	Op85M0mod3
			.long	Op86X0mod3
			.long	Op87M0mod3
			.long	Op88X0mod3
			.long	Op89M0mod3
			.long	Op8AM0mod3
			.long	Op8Bmod3
			.long	Op8CX0mod3
			.long	Op8DM0mod3
			.long	Op8EX0mod3
			.long	Op8FM0mod3
			.long	Op90mod3
			.long	Op91M0mod3
			.long	Op92M0mod3
			.long	Op93M0mod3
			.long	Op94X0mod3
			.long	Op95M0mod3
			.long	Op96X0mod3
			.long	Op97M0mod3
			.long	Op98M0mod3
			.long	Op99M0mod3
			.long	Op9Amod3
			.long	Op9BX0mod3
			.long	Op9CM0mod3
			.long	Op9DM0mod3
			.long	Op9EM0mod3
			.long	Op9FM0mod3
			.long	OpA0X0mod3
			.long	OpA1M0mod3
			.long	OpA2X0mod3
			.long	OpA3M0mod3
			.long	OpA4X0mod3
			.long	OpA5M0mod3
			.long	OpA6X0mod3
			.long	OpA7M0mod3
			.long	OpA8X0mod3
			.long	OpA9M0mod3
			.long	OpAAX0mod3
			.long	OpABmod3
			.long	OpACX0mod3
			.long	OpADM0mod3
			.long	OpAEX0mod3
			.long	OpAFM0mod3
			.long	OpB0mod3
			.long	OpB1M0mod3
			.long	OpB2M0mod3
			.long	OpB3M0mod3
			.long	OpB4X0mod3
			.long	OpB5M0mod3
			.long	OpB6X0mod3
			.long	OpB7M0mod3
			.long	OpB8mod3
			.long	OpB9M0mod3
			.long	OpBAX0mod3
			.long	OpBBX0mod3
			.long	OpBCX0mod3
			.long	OpBDM0mod3
			.long	OpBEX0mod3
			.long	OpBFM0mod3
			.long	OpC0X0mod3
			.long	OpC1M0mod3
			.long	OpC2mod3
			.long	OpC3M0mod3
			.long	OpC4X0mod3
			.long	OpC5M0mod3
			.long	OpC6M0mod3
			.long	OpC7M0mod3
			.long	OpC8X0mod3
			.long	OpC9M0mod3
			.long	OpCAX0mod3
			.long	OpCBmod3
			.long	OpCCX0mod3
			.long	OpCDM0mod3
			.long	OpCEM0mod3
			.long	OpCFM0mod3
			.long	OpD0mod3
			.long	OpD1M0mod3
			.long	OpD2M0mod3
			.long	OpD3M0mod3
			.long	OpD4mod3
			.long	OpD5M0mod3
			.long	OpD6M0mod3
			.long	OpD7M0mod3
			.long	OpD8mod3
			.long	OpD9M0mod3
			.long	OpDAX0mod3
			.long	OpDBmod3
			.long	OpDCmod3
			.long	OpDDM0mod3
			.long	OpDEM0mod3
			.long	OpDFM0mod3
			.long	OpE0X0mod3
			.long	OpE1M0mod3
			.long	OpE2mod3
			.long	OpE3M0mod3
			.long	OpE4X0mod3
			.long	OpE5M0mod3
			.long	OpE6M0mod3
			.long	OpE7M0mod3
			.long	OpE8X0mod3
			.long	OpE9M0mod3
			.long	OpEAmod3
			.long	OpEBmod3
			.long	OpECX0mod3
			.long	OpEDM0mod3
			.long	OpEEM0mod3
			.long	OpEFM0mod3
			.long	OpF0mod3
			.long	OpF1M0mod3
			.long	OpF2M0mod3
			.long	OpF3M0mod3
			.long	OpF4mod3
			.long	OpF5M0mod3
			.long	OpF6M0mod3
			.long	OpF7M0mod3
			.long	OpF8mod3
			.long	OpF9M0mod3
			.long	OpFAX0mod3
			.long	OpFBmod3
			.long	OpFCmod3
			.long	OpFDM0mod3
			.long	OpFEM0mod3
			.long	OpFFM0mod3
Op00mod3:
lbl00mod3:	Op00
			NEXTOPCODE
Op01M0mod3:
lbl01mod3a:	DirectIndexedIndirect0
lbl01mod3b:	ORA16
			NEXTOPCODE
Op02mod3:
lbl02mod3:	Op02
			NEXTOPCODE
Op03M0mod3:
lbl03mod3a:	StackasmRelative
lbl03mod3b:	ORA16
			NEXTOPCODE
Op04M0mod3:
lbl04mod3a:	Direct
lbl04mod3b:	TSB16
			NEXTOPCODE
Op05M0mod3:
lbl05mod3a:	Direct
lbl05mod3b:	ORA16
			NEXTOPCODE
Op06M0mod3:
lbl06mod3a:	Direct
lbl06mod3b:	ASL16
			NEXTOPCODE
Op07M0mod3:
lbl07mod3a:	DirectIndirectLong
lbl07mod3b:	ORA16
			NEXTOPCODE
Op08mod3:
lbl08mod3:	Op08
			NEXTOPCODE
Op09M0mod3:
lbl09mod3:	Op09M0
			NEXTOPCODE
Op0AM0mod3:
lbl0Amod3a:	A_ASL16
			NEXTOPCODE
Op0Bmod3:
lbl0Bmod3:	Op0B
			NEXTOPCODE
Op0CM0mod3:
lbl0Cmod3a:	Absolute
lbl0Cmod3b:	TSB16
			NEXTOPCODE
Op0DM0mod3:
lbl0Dmod3a:	Absolute
lbl0Dmod3b:	ORA16
			NEXTOPCODE
Op0EM0mod3:
lbl0Emod3a:	Absolute
lbl0Emod3b:	ASL16
			NEXTOPCODE
Op0FM0mod3:
lbl0Fmod3a:	AbsoluteLong
lbl0Fmod3b:	ORA16
			NEXTOPCODE
Op10mod3:
lbl10mod3:	Op10
			NEXTOPCODE
Op11M0mod3:
lbl11mod3a:	DirectIndirectIndexed0
lbl11mod3b:	ORA16
			NEXTOPCODE
Op12M0mod3:
lbl12mod3a:	DirectIndirect
lbl12mod3b:	ORA16
			NEXTOPCODE
Op13M0mod3:
lbl13mod3a:	StackasmRelativeIndirectIndexed0
lbl13mod3b:	ORA16
			NEXTOPCODE
Op14M0mod3:
lbl14mod3a:	Direct
lbl14mod3b:	TRB16
			NEXTOPCODE
Op15M0mod3:
lbl15mod3a:	DirectIndexedX0
lbl15mod3b:	ORA16
			NEXTOPCODE
Op16M0mod3:
lbl16mod3a:	DirectIndexedX0
lbl16mod3b:	ASL16
			NEXTOPCODE
Op17M0mod3:
lbl17mod3a:	DirectIndirectIndexedLong0
lbl17mod3b:	ORA16
			NEXTOPCODE
Op18mod3:
lbl18mod3:	Op18
			NEXTOPCODE
Op19M0mod3:
lbl19mod3a:	AbsoluteIndexedY0
lbl19mod3b:	ORA16
			NEXTOPCODE
Op1AM0mod3:
lbl1Amod3a:	A_INC16
			NEXTOPCODE
Op1Bmod3:
lbl1Bmod3:	Op1BM0
			NEXTOPCODE
Op1CM0mod3:
lbl1Cmod3a:	Absolute
lbl1Cmod3b:	TRB16
			NEXTOPCODE
Op1DM0mod3:
lbl1Dmod3a:	AbsoluteIndexedX0
lbl1Dmod3b:	ORA16
			NEXTOPCODE
Op1EM0mod3:
lbl1Emod3a:	AbsoluteIndexedX0
lbl1Emod3b:	ASL16
			NEXTOPCODE
Op1FM0mod3:
lbl1Fmod3a:	AbsoluteLongIndexedX0
lbl1Fmod3b:	ORA16
			NEXTOPCODE
Op20mod3:
lbl20mod3:	Op20
			NEXTOPCODE
Op21M0mod3:
lbl21mod3a:	DirectIndexedIndirect0
lbl21mod3b:	AND16
			NEXTOPCODE
Op22mod3:
lbl22mod3:	Op22
			NEXTOPCODE
Op23M0mod3:
lbl23mod3a:	StackasmRelative
lbl23mod3b:	AND16
			NEXTOPCODE
Op24M0mod3:
lbl24mod3a:	Direct
lbl24mod3b:	BIT16
			NEXTOPCODE
Op25M0mod3:
lbl25mod3a:	Direct
lbl25mod3b:	AND16
			NEXTOPCODE
Op26M0mod3:
lbl26mod3a:	Direct
lbl26mod3b:	ROL16
			NEXTOPCODE
Op27M0mod3:
lbl27mod3a:	DirectIndirectLong
lbl27mod3b:	AND16
			NEXTOPCODE
Op28mod3:
lbl28mod3:	Op28X0M0
			NEXTOPCODE
.pool
Op29M0mod3:
lbl29mod3:	Op29M0
			NEXTOPCODE
Op2AM0mod3:
lbl2Amod3a:	A_ROL16
			NEXTOPCODE
Op2Bmod3:
lbl2Bmod3:	Op2B
			NEXTOPCODE
Op2CM0mod3:
lbl2Cmod3a:	Absolute
lbl2Cmod3b:	BIT16
			NEXTOPCODE
Op2DM0mod3:
lbl2Dmod3a:	Absolute
lbl2Dmod3b:	AND16
			NEXTOPCODE
Op2EM0mod3:
lbl2Emod3a:	Absolute
lbl2Emod3b:	ROL16
			NEXTOPCODE
Op2FM0mod3:
lbl2Fmod3a:	AbsoluteLong
lbl2Fmod3b:	AND16
			NEXTOPCODE
Op30mod3:
lbl30mod3:	Op30
			NEXTOPCODE
Op31M0mod3:
lbl31mod3a:	DirectIndirectIndexed0
lbl31mod3b:	AND16
			NEXTOPCODE
Op32M0mod3:
lbl32mod3a:	DirectIndirect
lbl32mod3b:	AND16
			NEXTOPCODE
Op33M0mod3:
lbl33mod3a:	StackasmRelativeIndirectIndexed0
lbl33mod3b:	AND16
			NEXTOPCODE
Op34M0mod3:
lbl34mod3a:	DirectIndexedX0
lbl34mod3b:	BIT16
			NEXTOPCODE
Op35M0mod3:
lbl35mod3a:	DirectIndexedX0
lbl35mod3b:	AND16
			NEXTOPCODE
Op36M0mod3:
lbl36mod3a:	DirectIndexedX0
lbl36mod3b:	ROL16
			NEXTOPCODE
Op37M0mod3:
lbl37mod3a:	DirectIndirectIndexedLong0
lbl37mod3b:	AND16
			NEXTOPCODE
Op38mod3:
lbl38mod3:	Op38
			NEXTOPCODE
Op39M0mod3:
lbl39mod3a:	AbsoluteIndexedY0
lbl39mod3b:	AND16
			NEXTOPCODE
Op3AM0mod3:
lbl3Amod3a:	A_DEC16
			NEXTOPCODE
Op3Bmod3:
lbl3Bmod3:	Op3BM0
			NEXTOPCODE
Op3CM0mod3:
lbl3Cmod3a:	AbsoluteIndexedX0
lbl3Cmod3b:	BIT16
			NEXTOPCODE
Op3DM0mod3:
lbl3Dmod3a:	AbsoluteIndexedX0
lbl3Dmod3b:	AND16
			NEXTOPCODE
Op3EM0mod3:
lbl3Emod3a:	AbsoluteIndexedX0
lbl3Emod3b:	ROL16
			NEXTOPCODE
Op3FM0mod3:
lbl3Fmod3a:	AbsoluteLongIndexedX0
lbl3Fmod3b:	AND16
			NEXTOPCODE
Op40mod3:
lbl40mod3:	Op40X0M0
			NEXTOPCODE
.pool						
Op41M0mod3:
lbl41mod3a:	DirectIndexedIndirect0
lbl41mod3b:	EOR16
			NEXTOPCODE
Op42mod3:
lbl42mod3:	Op42
			NEXTOPCODE
Op43M0mod3:
lbl43mod3a:	StackasmRelative
lbl43mod3b:	EOR16
			NEXTOPCODE
Op44X0mod3:
lbl44mod3:	Op44X0M0
			NEXTOPCODE
Op45M0mod3:
lbl45mod3a:	Direct
lbl45mod3b:	EOR16
			NEXTOPCODE
Op46M0mod3:
lbl46mod3a:	Direct
lbl46mod3b:	LSR16
			NEXTOPCODE
Op47M0mod3:
lbl47mod3a:	DirectIndirectLong
lbl47mod3b:	EOR16
			NEXTOPCODE
Op48M0mod3:
lbl48mod3:	Op48M0
			NEXTOPCODE
Op49M0mod3:
lbl49mod3:	Op49M0
			NEXTOPCODE
Op4AM0mod3:
lbl4Amod3a:	A_LSR16
			NEXTOPCODE
Op4Bmod3:
lbl4Bmod3:	Op4B
			NEXTOPCODE
Op4Cmod3:
lbl4Cmod3:	Op4C
			NEXTOPCODE
Op4DM0mod3:
lbl4Dmod3a:	Absolute
lbl4Dmod3b:	EOR16
			NEXTOPCODE
Op4EM0mod3:
lbl4Emod3a:	Absolute
lbl4Emod3b:	LSR16
			NEXTOPCODE
Op4FM0mod3:
lbl4Fmod3a:	AbsoluteLong
lbl4Fmod3b:	EOR16
			NEXTOPCODE
Op50mod3:
lbl50mod3:	Op50
			NEXTOPCODE
Op51M0mod3:
lbl51mod3a:	DirectIndirectIndexed0
lbl51mod3b:	EOR16
			NEXTOPCODE
Op52M0mod3:
lbl52mod3a:	DirectIndirect
lbl52mod3b:	EOR16
			NEXTOPCODE
Op53M0mod3:
lbl53mod3a:	StackasmRelativeIndirectIndexed0
lbl53mod3b:	EOR16
			NEXTOPCODE
Op54X0mod3:
lbl54mod3:	Op54X0M0
			NEXTOPCODE
Op55M0mod3:
lbl55mod3a:	DirectIndexedX0
lbl55mod3b:	EOR16
			NEXTOPCODE
Op56M0mod3:
lbl56mod3a:	DirectIndexedX0
lbl56mod3b:	LSR16
			NEXTOPCODE
Op57M0mod3:
lbl57mod3a:	DirectIndirectIndexedLong0
lbl57mod3b:	EOR16
			NEXTOPCODE
Op58mod3:
lbl58mod3:	Op58
			NEXTOPCODE
Op59M0mod3:
lbl59mod3a:	AbsoluteIndexedY0
lbl59mod3b:	EOR16
			NEXTOPCODE
Op5AX0mod3:
lbl5Amod3:	Op5AX0
			NEXTOPCODE
Op5Bmod3:
lbl5Bmod3:	Op5BM0
			NEXTOPCODE
Op5Cmod3:
lbl5Cmod3:	Op5C
			NEXTOPCODE
Op5DM0mod3:
lbl5Dmod3a:	AbsoluteIndexedX0
lbl5Dmod3b:	EOR16
			NEXTOPCODE
Op5EM0mod3:
lbl5Emod3a:	AbsoluteIndexedX0
lbl5Emod3b:	LSR16
			NEXTOPCODE
Op5FM0mod3:
lbl5Fmod3a:	AbsoluteLongIndexedX0
lbl5Fmod3b:	EOR16
			NEXTOPCODE
Op60mod3:
lbl60mod3:	Op60
			NEXTOPCODE
Op61M0mod3:
lbl61mod3a:	DirectIndexedIndirect0
lbl61mod3b:	ADC16
			NEXTOPCODE
Op62mod3:
lbl62mod3:	Op62
			NEXTOPCODE
Op63M0mod3:
lbl63mod3a:	StackasmRelative
lbl63mod3b:	ADC16
			NEXTOPCODE
.pool			
Op64M0mod3:
lbl64mod3a:	Direct
lbl64mod3b:	STZ16
			NEXTOPCODE
Op65M0mod3:
lbl65mod3a:	Direct
lbl65mod3b:	ADC16
			NEXTOPCODE
.pool			
Op66M0mod3:
lbl66mod3a:	Direct
lbl66mod3b:	ROR16
			NEXTOPCODE
Op67M0mod3:
lbl67mod3a:	DirectIndirectLong
lbl67mod3b:	ADC16
			NEXTOPCODE
.pool			
Op68M0mod3:
lbl68mod3:	Op68M0
			NEXTOPCODE
Op69M0mod3:
lbl69mod3a:	Immediate16
lbl69mod3b:	ADC16
			NEXTOPCODE
.pool			
Op6AM0mod3:
lbl6Amod3a:	A_ROR16
			NEXTOPCODE
Op6Bmod3:
lbl6Bmod3:	Op6B
			NEXTOPCODE
Op6Cmod3:
lbl6Cmod3:	Op6C
			NEXTOPCODE
Op6DM0mod3:
lbl6Dmod3a:	Absolute
lbl6Dmod3b:	ADC16
			NEXTOPCODE
Op6EM0mod3:
lbl6Emod3a:	Absolute
lbl6Emod3b:	ROR16
			NEXTOPCODE
Op6FM0mod3:
lbl6Fmod3a:	AbsoluteLong
lbl6Fmod3b:	ADC16
			NEXTOPCODE
Op70mod3:
lbl70mod3:	Op70
			NEXTOPCODE
Op71M0mod3:
lbl71mod3a:	DirectIndirectIndexed0
lbl71mod3b:	ADC16
			NEXTOPCODE
Op72M0mod3:
lbl72mod3a:	DirectIndirect
lbl72mod3b:	ADC16
			NEXTOPCODE
Op73M0mod3:
lbl73mod3a:	StackasmRelativeIndirectIndexed0
lbl73mod3b:	ADC16
			NEXTOPCODE
.pool
Op74M0mod3:
lbl74mod3a:	DirectIndexedX0
lbl74mod3b:	STZ16
			NEXTOPCODE
Op75M0mod3:
lbl75mod3a:	DirectIndexedX0
lbl75mod3b:	ADC16
			NEXTOPCODE
.pool
Op76M0mod3:
lbl76mod3a:	DirectIndexedX0
lbl76mod3b:	ROR16
			NEXTOPCODE
Op77M0mod3:
lbl77mod3a:	DirectIndirectIndexedLong0
lbl77mod3b:	ADC16
			NEXTOPCODE
Op78mod3:
lbl78mod3:	Op78
			NEXTOPCODE
Op79M0mod3:
lbl79mod3a:	AbsoluteIndexedY0
lbl79mod3b:	ADC16
			NEXTOPCODE
Op7AX0mod3:
lbl7Amod3:	Op7AX0
			NEXTOPCODE
Op7Bmod3:
lbl7Bmod3:	Op7BM0
			NEXTOPCODE
Op7Cmod3:
lbl7Cmod3:	AbsoluteIndexedIndirectX0
		Op7C
			NEXTOPCODE
Op7DM0mod3:
lbl7Dmod3a:	AbsoluteIndexedX0
lbl7Dmod3b:	ADC16
			NEXTOPCODE
Op7EM0mod3:
lbl7Emod3a:	AbsoluteIndexedX0
lbl7Emod3b:	ROR16
			NEXTOPCODE
Op7FM0mod3:
lbl7Fmod3a:	AbsoluteLongIndexedX0
lbl7Fmod3b:	ADC16
			NEXTOPCODE
.pool			
Op80mod3:
lbl80mod3:	Op80
			NEXTOPCODE
Op81M0mod3:
lbl81mod3a:	DirectIndexedIndirect0
lbl81mod3b:	Op81M0
			NEXTOPCODE
Op82mod3:
lbl82mod3:	Op82
			NEXTOPCODE
Op83M0mod3:
lbl83mod3a:	StackasmRelative
lbl83mod3b:	STA16
			NEXTOPCODE
Op84X0mod3:
lbl84mod3a:	Direct
lbl84mod3b:	STY16
			NEXTOPCODE
Op85M0mod3:
lbl85mod3a:	Direct
lbl85mod3b:	STA16
			NEXTOPCODE
Op86X0mod3:
lbl86mod3a:	Direct
lbl86mod3b:	STX16
			NEXTOPCODE
Op87M0mod3:
lbl87mod3a:	DirectIndirectLong
lbl87mod3b:	STA16
			NEXTOPCODE
Op88X0mod3:
lbl88mod3:	Op88X0
			NEXTOPCODE
Op89M0mod3:
lbl89mod3:	Op89M0
			NEXTOPCODE
Op8AM0mod3:
lbl8Amod3:	Op8AM0X0
			NEXTOPCODE
Op8Bmod3:
lbl8Bmod3:	Op8B
			NEXTOPCODE
Op8CX0mod3:
lbl8Cmod3a:	Absolute
lbl8Cmod3b:	STY16
			NEXTOPCODE
Op8DM0mod3:
lbl8Dmod3a:	Absolute
lbl8Dmod3b:	STA16
			NEXTOPCODE
Op8EX0mod3:
lbl8Emod3a:	Absolute
lbl8Emod3b:	STX16
			NEXTOPCODE
Op8FM0mod3:
lbl8Fmod3a:	AbsoluteLong
lbl8Fmod3b:	STA16
			NEXTOPCODE
Op90mod3:
lbl90mod3:	Op90
			NEXTOPCODE
Op91M0mod3:
lbl91mod3a:	DirectIndirectIndexed0
lbl91mod3b:	STA16
			NEXTOPCODE
Op92M0mod3:
lbl92mod3a:	DirectIndirect
lbl92mod3b:	STA16
			NEXTOPCODE
Op93M0mod3:
lbl93mod3a:	StackasmRelativeIndirectIndexed0
lbl93mod3b:	STA16
			NEXTOPCODE
Op94X0mod3:
lbl94mod3a:	DirectIndexedX0
lbl94mod3b:	STY16
			NEXTOPCODE
Op95M0mod3:
lbl95mod3a:	DirectIndexedX0
lbl95mod3b:	STA16
			NEXTOPCODE
Op96X0mod3:
lbl96mod3a:	DirectIndexedY0
lbl96mod3b:	STX16
			NEXTOPCODE
Op97M0mod3:
lbl97mod3a:	DirectIndirectIndexedLong0
lbl97mod3b:	STA16
			NEXTOPCODE
Op98M0mod3:
lbl98mod3:	Op98M0X0
			NEXTOPCODE
Op99M0mod3:
lbl99mod3a:	AbsoluteIndexedY0
lbl99mod3b:	STA16
			NEXTOPCODE
Op9Amod3:
lbl9Amod3:	Op9AX0
			NEXTOPCODE
Op9BX0mod3:
lbl9Bmod3:	Op9BX0
			NEXTOPCODE
Op9CM0mod3:
lbl9Cmod3a:	Absolute
lbl9Cmod3b:	STZ16
			NEXTOPCODE
Op9DM0mod3:
lbl9Dmod3a:	AbsoluteIndexedX0
lbl9Dmod3b:	STA16
			NEXTOPCODE
Op9EM0mod3:	
lbl9Emod3:	AbsoluteIndexedX0		
		STZ16
			NEXTOPCODE
Op9FM0mod3:
lbl9Fmod3a:	AbsoluteLongIndexedX0
lbl9Fmod3b:	STA16
			NEXTOPCODE
OpA0X0mod3:
lblA0mod3:	OpA0X0
			NEXTOPCODE
OpA1M0mod3:
lblA1mod3a:	DirectIndexedIndirect0
lblA1mod3b:	LDA16
			NEXTOPCODE
OpA2X0mod3:
lblA2mod3:	OpA2X0
			NEXTOPCODE
OpA3M0mod3:
lblA3mod3a:	StackasmRelative
lblA3mod3b:	LDA16
			NEXTOPCODE
OpA4X0mod3:
lblA4mod3a:	Direct
lblA4mod3b:	LDY16
			NEXTOPCODE
OpA5M0mod3:
lblA5mod3a:	Direct
lblA5mod3b:	LDA16
			NEXTOPCODE
OpA6X0mod3:
lblA6mod3a:	Direct
lblA6mod3b:	LDX16
			NEXTOPCODE
OpA7M0mod3:
lblA7mod3a:	DirectIndirectLong
lblA7mod3b:	LDA16
			NEXTOPCODE
OpA8X0mod3:
lblA8mod3:	OpA8X0M0
			NEXTOPCODE
OpA9M0mod3:
lblA9mod3:	OpA9M0
			NEXTOPCODE
OpAAX0mod3:
lblAAmod3:	OpAAX0M0
			NEXTOPCODE
OpABmod3:
lblABmod3:	OpAB
			NEXTOPCODE
OpACX0mod3:
lblACmod3a:	Absolute
lblACmod3b:	LDY16
			NEXTOPCODE
OpADM0mod3:
lblADmod3a:	Absolute
lblADmod3b:	LDA16
			NEXTOPCODE
OpAEX0mod3:
lblAEmod3a:	Absolute
lblAEmod3b:	LDX16
			NEXTOPCODE
OpAFM0mod3:
lblAFmod3a:	AbsoluteLong
lblAFmod3b:	LDA16
			NEXTOPCODE
OpB0mod3:
lblB0mod3:	OpB0
			NEXTOPCODE
OpB1M0mod3:
lblB1mod3a:	DirectIndirectIndexed0
lblB1mod3b:	LDA16
			NEXTOPCODE
OpB2M0mod3:
lblB2mod3a:	DirectIndirect
lblB2mod3b:	LDA16
			NEXTOPCODE
OpB3M0mod3:
lblB3mod3a:	StackasmRelativeIndirectIndexed0
lblB3mod3b:	LDA16
			NEXTOPCODE
OpB4X0mod3:
lblB4mod3a:	DirectIndexedX0
lblB4mod3b:	LDY16
			NEXTOPCODE
OpB5M0mod3:
lblB5mod3a:	DirectIndexedX0
lblB5mod3b:	LDA16
			NEXTOPCODE
OpB6X0mod3:
lblB6mod3a:	DirectIndexedY0
lblB6mod3b:	LDX16
			NEXTOPCODE
OpB7M0mod3:
lblB7mod3a:	DirectIndirectIndexedLong0
lblB7mod3b:	LDA16
			NEXTOPCODE
OpB8mod3:
lblB8mod3:	OpB8
			NEXTOPCODE
OpB9M0mod3:
lblB9mod3a:	AbsoluteIndexedY0
lblB9mod3b:	LDA16
			NEXTOPCODE
OpBAX0mod3:
lblBAmod3:	OpBAX0
			NEXTOPCODE
OpBBX0mod3:
lblBBmod3:	OpBBX0
			NEXTOPCODE
OpBCX0mod3:
lblBCmod3a:	AbsoluteIndexedX0
lblBCmod3b:	LDY16
			NEXTOPCODE
OpBDM0mod3:
lblBDmod3a:	AbsoluteIndexedX0
lblBDmod3b:	LDA16
			NEXTOPCODE
OpBEX0mod3:
lblBEmod3a:	AbsoluteIndexedY0
lblBEmod3b:	LDX16
			NEXTOPCODE
OpBFM0mod3:
lblBFmod3a:	AbsoluteLongIndexedX0
lblBFmod3b:	LDA16
			NEXTOPCODE
OpC0X0mod3:
lblC0mod3:	OpC0X0
			NEXTOPCODE
OpC1M0mod3:
lblC1mod3a:	DirectIndexedIndirect0
lblC1mod3b:	CMP16
			NEXTOPCODE
OpC2mod3:
lblC2mod3:	OpC2
			NEXTOPCODE
.pool
OpC3M0mod3:
lblC3mod3a:	StackasmRelative
lblC3mod3b:	CMP16
			NEXTOPCODE
OpC4X0mod3:
lblC4mod3a:	Direct
lblC4mod3b:	CMY16
			NEXTOPCODE
OpC5M0mod3:
lblC5mod3a:	Direct
lblC5mod3b:	CMP16
			NEXTOPCODE
OpC6M0mod3:
lblC6mod3a:	Direct
lblC6mod3b:	DEC16
			NEXTOPCODE
OpC7M0mod3:
lblC7mod3a:	DirectIndirectLong
lblC7mod3b:	CMP16
			NEXTOPCODE
OpC8X0mod3:
lblC8mod3:	OpC8X0
			NEXTOPCODE
OpC9M0mod3:
lblC9mod3:	OpC9M0
			NEXTOPCODE
OpCAX0mod3:
lblCAmod3:	OpCAX0
			NEXTOPCODE
OpCBmod3:
lblCBmod3:	OpCB
			NEXTOPCODE
OpCCX0mod3:
lblCCmod3a:	Absolute
lblCCmod3b:	CMY16
			NEXTOPCODE
OpCDM0mod3:
lblCDmod3a:	Absolute
lblCDmod3b:	CMP16
			NEXTOPCODE
OpCEM0mod3:
lblCEmod3a:	Absolute
lblCEmod3b:	DEC16
			NEXTOPCODE
OpCFM0mod3:
lblCFmod3a:	AbsoluteLong
lblCFmod3b:	CMP16
			NEXTOPCODE
OpD0mod3:
lblD0mod3:	OpD0
			NEXTOPCODE
OpD1M0mod3:
lblD1mod3a:	DirectIndirectIndexed0
lblD1mod3b:	CMP16
			NEXTOPCODE
OpD2M0mod3:
lblD2mod3a:	DirectIndirect
lblD2mod3b:	CMP16
			NEXTOPCODE
OpD3M0mod3:
lblD3mod3a:	StackasmRelativeIndirectIndexed0
lblD3mod3b:	CMP16
			NEXTOPCODE
OpD4mod3:
lblD4mod3:	OpD4
			NEXTOPCODE
OpD5M0mod3:
lblD5mod3a:	DirectIndexedX0
lblD5mod3b:	CMP16
			NEXTOPCODE
OpD6M0mod3:
lblD6mod3a:	DirectIndexedX0
lblD6mod3b:	DEC16
			NEXTOPCODE
OpD7M0mod3:
lblD7mod3a:	DirectIndirectIndexedLong0
lblD7mod3b:	CMP16
			NEXTOPCODE
OpD8mod3:
lblD8mod3:	OpD8
			NEXTOPCODE
OpD9M0mod3:
lblD9mod3a:	AbsoluteIndexedY0
lblD9mod3b:	CMP16
			NEXTOPCODE
OpDAX0mod3:
lblDAmod3:	OpDAX0
			NEXTOPCODE
OpDBmod3:
lblDBmod3:	OpDB
			NEXTOPCODE
OpDCmod3:
lblDCmod3:	OpDC
			NEXTOPCODE
OpDDM0mod3:
lblDDmod3a:	AbsoluteIndexedX0
lblDDmod3b:	CMP16
			NEXTOPCODE
OpDEM0mod3:
lblDEmod3a:	AbsoluteIndexedX0
lblDEmod3b:	DEC16
			NEXTOPCODE
OpDFM0mod3:
lblDFmod3a:	AbsoluteLongIndexedX0
lblDFmod3b:	CMP16
			NEXTOPCODE
OpE0X0mod3:
lblE0mod3:	OpE0X0
			NEXTOPCODE
OpE1M0mod3:
lblE1mod3a:	DirectIndexedIndirect0
lblE1mod3b:	SBC16
			NEXTOPCODE
OpE2mod3:
lblE2mod3:	OpE2
			NEXTOPCODE
.pool
OpE3M0mod3:
lblE3mod3a:	StackasmRelative
lblE3mod3b:	SBC16
			NEXTOPCODE
OpE4X0mod3:
lblE4mod3a:	Direct
lblE4mod3b:	CMX16
			NEXTOPCODE
OpE5M0mod3:
lblE5mod3a:	Direct
lblE5mod3b:	SBC16
			NEXTOPCODE
OpE6M0mod3:
lblE6mod3a:	Direct
lblE6mod3b:	INC16
			NEXTOPCODE
OpE7M0mod3:
lblE7mod3a:	DirectIndirectLong
lblE7mod3b:	SBC16
			NEXTOPCODE
OpE8X0mod3:
lblE8mod3:	OpE8X0
			NEXTOPCODE
OpE9M0mod3:
lblE9mod3a:	Immediate16
lblE9mod3b:	SBC16
			NEXTOPCODE
OpEAmod3:
lblEAmod3:	OpEA
			NEXTOPCODE
OpEBmod3:
lblEBmod3:	OpEBM0
			NEXTOPCODE
OpECX0mod3:
lblECmod3a:	Absolute
lblECmod3b:	CMX16
			NEXTOPCODE
OpEDM0mod3:
lblEDmod3a:	Absolute
lblEDmod3b:	SBC16
			NEXTOPCODE
OpEEM0mod3:
lblEEmod3a:	Absolute
lblEEmod3b:	INC16
			NEXTOPCODE
OpEFM0mod3:
lblEFmod3a:	AbsoluteLong
lblEFmod3b:	SBC16
			NEXTOPCODE
OpF0mod3:
lblF0mod3:	OpF0
			NEXTOPCODE
OpF1M0mod3:
lblF1mod3a:	DirectIndirectIndexed0
lblF1mod3b:	SBC16
			NEXTOPCODE
OpF2M0mod3:
lblF2mod3a:	DirectIndirect
lblF2mod3b:	SBC16
			NEXTOPCODE
OpF3M0mod3:
lblF3mod3a:	StackasmRelativeIndirectIndexed0
lblF3mod3b:	SBC16
			NEXTOPCODE
OpF4mod3:
lblF4mod3:	OpF4
			NEXTOPCODE
OpF5M0mod3:
lblF5mod3a:	DirectIndexedX0
lblF5mod3b:	SBC16
			NEXTOPCODE
OpF6M0mod3:
lblF6mod3a:	DirectIndexedX0
lblF6mod3b:	INC16
			NEXTOPCODE
OpF7M0mod3:
lblF7mod3a:	DirectIndirectIndexedLong0
lblF7mod3b:	SBC16
			NEXTOPCODE
OpF8mod3:
lblF8mod3:	OpF8
			NEXTOPCODE
OpF9M0mod3:
lblF9mod3a:	AbsoluteIndexedY0
lblF9mod3b:	SBC16
			NEXTOPCODE
OpFAX0mod3:
lblFAmod3:	OpFAX0
			NEXTOPCODE
OpFBmod3:
lblFBmod3:	OpFB
			NEXTOPCODE
OpFCmod3:
lblFCmod3:	OpFCX0
			NEXTOPCODE
OpFDM0mod3:
lblFDmod3a:	AbsoluteIndexedX0
lblFDmod3b:	SBC16
			NEXTOPCODE
OpFEM0mod3:
lblFEmod3a:	AbsoluteIndexedX0
lblFEmod3b:	INC16
			NEXTOPCODE
OpFFM0mod3:
lblFFmod3a:	AbsoluteLongIndexedX0
lblFFmod3b:	SBC16
			NEXTOPCODE
.pool

jumptable4:		.long	Op00mod4
			.long	Op01M0mod4
			.long	Op02mod4
			.long	Op03M0mod4
			.long	Op04M0mod4
			.long	Op05M0mod4
			.long	Op06M0mod4
			.long	Op07M0mod4
			.long	Op08mod4
			.long	Op09M0mod4
			.long	Op0AM0mod4
			.long	Op0Bmod4
			.long	Op0CM0mod4
			.long	Op0DM0mod4
			.long	Op0EM0mod4
			.long	Op0FM0mod4
			.long	Op10mod4
			.long	Op11M0mod4
			.long	Op12M0mod4
			.long	Op13M0mod4
			.long	Op14M0mod4
			.long	Op15M0mod4
			.long	Op16M0mod4
			.long	Op17M0mod4
			.long	Op18mod4
			.long	Op19M0mod4
			.long	Op1AM0mod4
			.long	Op1Bmod4
			.long	Op1CM0mod4
			.long	Op1DM0mod4
			.long	Op1EM0mod4
			.long	Op1FM0mod4
			.long	Op20mod4
			.long	Op21M0mod4
			.long	Op22mod4
			.long	Op23M0mod4
			.long	Op24M0mod4
			.long	Op25M0mod4
			.long	Op26M0mod4
			.long	Op27M0mod4
			.long	Op28mod4
			.long	Op29M0mod4
			.long	Op2AM0mod4
			.long	Op2Bmod4
			.long	Op2CM0mod4
			.long	Op2DM0mod4
			.long	Op2EM0mod4
			.long	Op2FM0mod4
			.long	Op30mod4
			.long	Op31M0mod4
			.long	Op32M0mod4
			.long	Op33M0mod4
			.long	Op34M0mod4
			.long	Op35M0mod4
			.long	Op36M0mod4
			.long	Op37M0mod4
			.long	Op38mod4
			.long	Op39M0mod4
			.long	Op3AM0mod4
			.long	Op3Bmod4
			.long	Op3CM0mod4
			.long	Op3DM0mod4
			.long	Op3EM0mod4
			.long	Op3FM0mod4
			.long	Op40mod4
			.long	Op41M0mod4
			.long	Op42mod4
			.long	Op43M0mod4
			.long	Op44X1mod4
			.long	Op45M0mod4
			.long	Op46M0mod4
			.long	Op47M0mod4
			.long	Op48M0mod4
			.long	Op49M0mod4
			.long	Op4AM0mod4
			.long	Op4Bmod4
			.long	Op4Cmod4
			.long	Op4DM0mod4
			.long	Op4EM0mod4
			.long	Op4FM0mod4
			.long	Op50mod4
			.long	Op51M0mod4
			.long	Op52M0mod4
			.long	Op53M0mod4
			.long	Op54X1mod4
			.long	Op55M0mod4
			.long	Op56M0mod4
			.long	Op57M0mod4
			.long	Op58mod4
			.long	Op59M0mod4
			.long	Op5AX1mod4
			.long	Op5Bmod4
			.long	Op5Cmod4
			.long	Op5DM0mod4
			.long	Op5EM0mod4
			.long	Op5FM0mod4
			.long	Op60mod4
			.long	Op61M0mod4
			.long	Op62mod4
			.long	Op63M0mod4
			.long	Op64M0mod4
			.long	Op65M0mod4
			.long	Op66M0mod4
			.long	Op67M0mod4
			.long	Op68M0mod4
			.long	Op69M0mod4
			.long	Op6AM0mod4
			.long	Op6Bmod4
			.long	Op6Cmod4
			.long	Op6DM0mod4
			.long	Op6EM0mod4
			.long	Op6FM0mod4
			.long	Op70mod4
			.long	Op71M0mod4
			.long	Op72M0mod4
			.long	Op73M0mod4
			.long	Op74M0mod4
			.long	Op75M0mod4
			.long	Op76M0mod4
			.long	Op77M0mod4
			.long	Op78mod4
			.long	Op79M0mod4
			.long	Op7AX1mod4
			.long	Op7Bmod4
			.long	Op7Cmod4
			.long	Op7DM0mod4
			.long	Op7EM0mod4
			.long	Op7FM0mod4
			.long	Op80mod4
			.long	Op81M0mod4
			.long	Op82mod4
			.long	Op83M0mod4
			.long	Op84X1mod4
			.long	Op85M0mod4
			.long	Op86X1mod4
			.long	Op87M0mod4
			.long	Op88X1mod4
			.long	Op89M0mod4
			.long	Op8AM0mod4
			.long	Op8Bmod4
			.long	Op8CX1mod4
			.long	Op8DM0mod4
			.long	Op8EX1mod4
			.long	Op8FM0mod4
			.long	Op90mod4
			.long	Op91M0mod4
			.long	Op92M0mod4
			.long	Op93M0mod4
			.long	Op94X1mod4
			.long	Op95M0mod4
			.long	Op96X1mod4
			.long	Op97M0mod4
			.long	Op98M0mod4
			.long	Op99M0mod4
			.long	Op9Amod4
			.long	Op9BX1mod4
			.long	Op9CM0mod4
			.long	Op9DM0mod4
			.long	Op9EM0mod4
			.long	Op9FM0mod4
			.long	OpA0X1mod4
			.long	OpA1M0mod4
			.long	OpA2X1mod4
			.long	OpA3M0mod4
			.long	OpA4X1mod4
			.long	OpA5M0mod4
			.long	OpA6X1mod4
			.long	OpA7M0mod4
			.long	OpA8X1mod4
			.long	OpA9M0mod4
			.long	OpAAX1mod4
			.long	OpABmod4
			.long	OpACX1mod4
			.long	OpADM0mod4
			.long	OpAEX1mod4
			.long	OpAFM0mod4
			.long	OpB0mod4
			.long	OpB1M0mod4
			.long	OpB2M0mod4
			.long	OpB3M0mod4
			.long	OpB4X1mod4
			.long	OpB5M0mod4
			.long	OpB6X1mod4
			.long	OpB7M0mod4
			.long	OpB8mod4
			.long	OpB9M0mod4
			.long	OpBAX1mod4
			.long	OpBBX1mod4
			.long	OpBCX1mod4
			.long	OpBDM0mod4
			.long	OpBEX1mod4
			.long	OpBFM0mod4
			.long	OpC0X1mod4
			.long	OpC1M0mod4
			.long	OpC2mod4
			.long	OpC3M0mod4
			.long	OpC4X1mod4
			.long	OpC5M0mod4
			.long	OpC6M0mod4
			.long	OpC7M0mod4
			.long	OpC8X1mod4
			.long	OpC9M0mod4
			.long	OpCAX1mod4
			.long	OpCBmod4
			.long	OpCCX1mod4
			.long	OpCDM0mod4
			.long	OpCEM0mod4
			.long	OpCFM0mod4
			.long	OpD0mod4
			.long	OpD1M0mod4
			.long	OpD2M0mod4
			.long	OpD3M0mod4
			.long	OpD4mod4
			.long	OpD5M0mod4
			.long	OpD6M0mod4
			.long	OpD7M0mod4
			.long	OpD8mod4
			.long	OpD9M0mod4
			.long	OpDAX1mod4
			.long	OpDBmod4
			.long	OpDCmod4
			.long	OpDDM0mod4
			.long	OpDEM0mod4
			.long	OpDFM0mod4
			.long	OpE0X1mod4
			.long	OpE1M0mod4
			.long	OpE2mod4
			.long	OpE3M0mod4
			.long	OpE4X1mod4
			.long	OpE5M0mod4
			.long	OpE6M0mod4
			.long	OpE7M0mod4
			.long	OpE8X1mod4
			.long	OpE9M0mod4
			.long	OpEAmod4
			.long	OpEBmod4
			.long	OpECX1mod4
			.long	OpEDM0mod4
			.long	OpEEM0mod4
			.long	OpEFM0mod4
			.long	OpF0mod4
			.long	OpF1M0mod4
			.long	OpF2M0mod4
			.long	OpF3M0mod4
			.long	OpF4mod4
			.long	OpF5M0mod4
			.long	OpF6M0mod4
			.long	OpF7M0mod4
			.long	OpF8mod4
			.long	OpF9M0mod4
			.long	OpFAX1mod4
			.long	OpFBmod4
			.long	OpFCmod4
			.long	OpFDM0mod4
			.long	OpFEM0mod4
			.long	OpFFM0mod4
Op00mod4:
lbl00mod4:	Op00
			NEXTOPCODE
Op01M0mod4:
lbl01mod4a:	DirectIndexedIndirect1
lbl01mod4b:	ORA16
			NEXTOPCODE
Op02mod4:
lbl02mod4:	Op02
			NEXTOPCODE
Op03M0mod4:
lbl03mod4a:	StackasmRelative
lbl03mod4b:	ORA16
			NEXTOPCODE
Op04M0mod4:
lbl04mod4a:	Direct
lbl04mod4b:	TSB16
			NEXTOPCODE
Op05M0mod4:
lbl05mod4a:	Direct
lbl05mod4b:	ORA16
			NEXTOPCODE
Op06M0mod4:
lbl06mod4a:	Direct
lbl06mod4b:	ASL16
			NEXTOPCODE
Op07M0mod4:
lbl07mod4a:	DirectIndirectLong
lbl07mod4b:	ORA16
			NEXTOPCODE
Op08mod4:
lbl08mod4:	Op08
			NEXTOPCODE
Op09M0mod4:
lbl09mod4:	Op09M0
			NEXTOPCODE
Op0AM0mod4:
lbl0Amod4a:	A_ASL16
			NEXTOPCODE
Op0Bmod4:
lbl0Bmod4:	Op0B
			NEXTOPCODE
Op0CM0mod4:
lbl0Cmod4a:	Absolute
lbl0Cmod4b:	TSB16
			NEXTOPCODE
Op0DM0mod4:
lbl0Dmod4a:	Absolute
lbl0Dmod4b:	ORA16
			NEXTOPCODE
Op0EM0mod4:
lbl0Emod4a:	Absolute
lbl0Emod4b:	ASL16
			NEXTOPCODE
Op0FM0mod4:
lbl0Fmod4a:	AbsoluteLong
lbl0Fmod4b:	ORA16
			NEXTOPCODE
Op10mod4:
lbl10mod4:	Op10
			NEXTOPCODE
Op11M0mod4:
lbl11mod4a:	DirectIndirectIndexed1
lbl11mod4b:	ORA16
			NEXTOPCODE
Op12M0mod4:
lbl12mod4a:	DirectIndirect
lbl12mod4b:	ORA16
			NEXTOPCODE
Op13M0mod4:
lbl13mod4a:	StackasmRelativeIndirectIndexed1
lbl13mod4b:	ORA16
			NEXTOPCODE
Op14M0mod4:
lbl14mod4a:	Direct
lbl14mod4b:	TRB16
			NEXTOPCODE
Op15M0mod4:
lbl15mod4a:	DirectIndexedX1
lbl15mod4b:	ORA16
			NEXTOPCODE
Op16M0mod4:
lbl16mod4a:	DirectIndexedX1
lbl16mod4b:	ASL16
			NEXTOPCODE
Op17M0mod4:
lbl17mod4a:	DirectIndirectIndexedLong1
lbl17mod4b:	ORA16
			NEXTOPCODE
Op18mod4:
lbl18mod4:	Op18
			NEXTOPCODE
Op19M0mod4:
lbl19mod4a:	AbsoluteIndexedY1
lbl19mod4b:	ORA16
			NEXTOPCODE
Op1AM0mod4:
lbl1Amod4a:	A_INC16
			NEXTOPCODE
Op1Bmod4:
lbl1Bmod4:	Op1BM0
			NEXTOPCODE
Op1CM0mod4:
lbl1Cmod4a:	Absolute
lbl1Cmod4b:	TRB16
			NEXTOPCODE
Op1DM0mod4:
lbl1Dmod4a:	AbsoluteIndexedX1
lbl1Dmod4b:	ORA16
			NEXTOPCODE
Op1EM0mod4:
lbl1Emod4a:	AbsoluteIndexedX1
lbl1Emod4b:	ASL16
			NEXTOPCODE
Op1FM0mod4:
lbl1Fmod4a:	AbsoluteLongIndexedX1
lbl1Fmod4b:	ORA16
			NEXTOPCODE
Op20mod4:
lbl20mod4:	Op20
			NEXTOPCODE
Op21M0mod4:
lbl21mod4a:	DirectIndexedIndirect1
lbl21mod4b:	AND16
			NEXTOPCODE
Op22mod4:
lbl22mod4:	Op22
			NEXTOPCODE
Op23M0mod4:
lbl23mod4a:	StackasmRelative
lbl23mod4b:	AND16
			NEXTOPCODE
Op24M0mod4:
lbl24mod4a:	Direct
lbl24mod4b:	BIT16
			NEXTOPCODE
Op25M0mod4:
lbl25mod4a:	Direct
lbl25mod4b:	AND16
			NEXTOPCODE
Op26M0mod4:
lbl26mod4a:	Direct
lbl26mod4b:	ROL16
			NEXTOPCODE
Op27M0mod4:
lbl27mod4a:	DirectIndirectLong
lbl27mod4b:	AND16
			NEXTOPCODE
Op28mod4:
lbl28mod4:	Op28X1M0
			NEXTOPCODE
.pool
Op29M0mod4:
lbl29mod4:	Op29M0
			NEXTOPCODE
Op2AM0mod4:
lbl2Amod4a:	A_ROL16
			NEXTOPCODE
Op2Bmod4:
lbl2Bmod4:	Op2B
			NEXTOPCODE
Op2CM0mod4:
lbl2Cmod4a:	Absolute
lbl2Cmod4b:	BIT16
			NEXTOPCODE
Op2DM0mod4:
lbl2Dmod4a:	Absolute
lbl2Dmod4b:	AND16
			NEXTOPCODE
Op2EM0mod4:
lbl2Emod4a:	Absolute
lbl2Emod4b:	ROL16
			NEXTOPCODE
Op2FM0mod4:
lbl2Fmod4a:	AbsoluteLong
lbl2Fmod4b:	AND16
			NEXTOPCODE
Op30mod4:
lbl30mod4:	Op30
			NEXTOPCODE
Op31M0mod4:
lbl31mod4a:	DirectIndirectIndexed1
lbl31mod4b:	AND16
			NEXTOPCODE
Op32M0mod4:
lbl32mod4a:	DirectIndirect
lbl32mod4b:	AND16
			NEXTOPCODE
Op33M0mod4:
lbl33mod4a:	StackasmRelativeIndirectIndexed1
lbl33mod4b:	AND16
			NEXTOPCODE
Op34M0mod4:
lbl34mod4a:	DirectIndexedX1
lbl34mod4b:	BIT16
			NEXTOPCODE
Op35M0mod4:
lbl35mod4a:	DirectIndexedX1
lbl35mod4b:	AND16
			NEXTOPCODE
Op36M0mod4:
lbl36mod4a:	DirectIndexedX1
lbl36mod4b:	ROL16
			NEXTOPCODE
Op37M0mod4:
lbl37mod4a:	DirectIndirectIndexedLong1
lbl37mod4b:	AND16
			NEXTOPCODE
Op38mod4:
lbl38mod4:	Op38
			NEXTOPCODE
Op39M0mod4:
lbl39mod4a:	AbsoluteIndexedY1
lbl39mod4b:	AND16
			NEXTOPCODE
Op3AM0mod4:
lbl3Amod4a:	A_DEC16
			NEXTOPCODE
Op3Bmod4:
lbl3Bmod4:	Op3BM0
			NEXTOPCODE
Op3CM0mod4:
lbl3Cmod4a:	AbsoluteIndexedX1
lbl3Cmod4b:	BIT16
			NEXTOPCODE
Op3DM0mod4:
lbl3Dmod4a:	AbsoluteIndexedX1
lbl3Dmod4b:	AND16
			NEXTOPCODE
Op3EM0mod4:
lbl3Emod4a:	AbsoluteIndexedX1
lbl3Emod4b:	ROL16
			NEXTOPCODE
Op3FM0mod4:
lbl3Fmod4a:	AbsoluteLongIndexedX1
lbl3Fmod4b:	AND16
			NEXTOPCODE
Op40mod4:
lbl40mod4:	Op40X1M0
			NEXTOPCODE
.pool						
Op41M0mod4:
lbl41mod4a:	DirectIndexedIndirect1
lbl41mod4b:	EOR16
			NEXTOPCODE
Op42mod4:
lbl42mod4:	Op42
			NEXTOPCODE
Op43M0mod4:
lbl43mod4a:	StackasmRelative
lbl43mod4b:	EOR16
			NEXTOPCODE
Op44X1mod4:
lbl44mod4:	Op44X1M0
			NEXTOPCODE
Op45M0mod4:
lbl45mod4a:	Direct
lbl45mod4b:	EOR16
			NEXTOPCODE
Op46M0mod4:
lbl46mod4a:	Direct
lbl46mod4b:	LSR16
			NEXTOPCODE
Op47M0mod4:
lbl47mod4a:	DirectIndirectLong
lbl47mod4b:	EOR16
			NEXTOPCODE
Op48M0mod4:
lbl48mod4:	Op48M0
			NEXTOPCODE
Op49M0mod4:
lbl49mod4:	Op49M0
			NEXTOPCODE
Op4AM0mod4:
lbl4Amod4a:	A_LSR16
			NEXTOPCODE
Op4Bmod4:
lbl4Bmod4:	Op4B
			NEXTOPCODE
Op4Cmod4:
lbl4Cmod4:	Op4C
			NEXTOPCODE
Op4DM0mod4:
lbl4Dmod4a:	Absolute
lbl4Dmod4b:	EOR16
			NEXTOPCODE
Op4EM0mod4:
lbl4Emod4a:	Absolute
lbl4Emod4b:	LSR16
			NEXTOPCODE
Op4FM0mod4:
lbl4Fmod4a:	AbsoluteLong
lbl4Fmod4b:	EOR16
			NEXTOPCODE
Op50mod4:
lbl50mod4:	Op50
			NEXTOPCODE
Op51M0mod4:
lbl51mod4a:	DirectIndirectIndexed1
lbl51mod4b:	EOR16
			NEXTOPCODE
Op52M0mod4:
lbl52mod4a:	DirectIndirect
lbl52mod4b:	EOR16
			NEXTOPCODE
Op53M0mod4:
lbl53mod4a:	StackasmRelativeIndirectIndexed1
lbl53mod4b:	EOR16
			NEXTOPCODE
Op54X1mod4:
lbl54mod4:	Op54X1M0
			NEXTOPCODE
Op55M0mod4:
lbl55mod4a:	DirectIndexedX1
lbl55mod4b:	EOR16
			NEXTOPCODE
Op56M0mod4:
lbl56mod4a:	DirectIndexedX1
lbl56mod4b:	LSR16
			NEXTOPCODE
Op57M0mod4:
lbl57mod4a:	DirectIndirectIndexedLong1
lbl57mod4b:	EOR16
			NEXTOPCODE
Op58mod4:
lbl58mod4:	Op58
			NEXTOPCODE
Op59M0mod4:
lbl59mod4a:	AbsoluteIndexedY1
lbl59mod4b:	EOR16
			NEXTOPCODE
Op5AX1mod4:
lbl5Amod4:	Op5AX1
			NEXTOPCODE
Op5Bmod4:
lbl5Bmod4:	Op5BM0
			NEXTOPCODE
Op5Cmod4:
lbl5Cmod4:	Op5C
			NEXTOPCODE
Op5DM0mod4:
lbl5Dmod4a:	AbsoluteIndexedX1
lbl5Dmod4b:	EOR16
			NEXTOPCODE
Op5EM0mod4:
lbl5Emod4a:	AbsoluteIndexedX1
lbl5Emod4b:	LSR16
			NEXTOPCODE
Op5FM0mod4:
lbl5Fmod4a:	AbsoluteLongIndexedX1
lbl5Fmod4b:	EOR16
			NEXTOPCODE
Op60mod4:
lbl60mod4:	Op60
			NEXTOPCODE
Op61M0mod4:
lbl61mod4a:	DirectIndexedIndirect1
lbl61mod4b:	ADC16
			NEXTOPCODE
Op62mod4:
lbl62mod4:	Op62
			NEXTOPCODE
Op63M0mod4:
lbl63mod4a:	StackasmRelative
lbl63mod4b:	ADC16
			NEXTOPCODE
.pool			
Op64M0mod4:
lbl64mod4a:	Direct
lbl64mod4b:	STZ16
			NEXTOPCODE
Op65M0mod4:
lbl65mod4a:	Direct
lbl65mod4b:	ADC16
			NEXTOPCODE
.pool			
Op66M0mod4:
lbl66mod4a:	Direct
lbl66mod4b:	ROR16
			NEXTOPCODE
Op67M0mod4:
lbl67mod4a:	DirectIndirectLong
lbl67mod4b:	ADC16
			NEXTOPCODE
.pool			
Op68M0mod4:
lbl68mod4:	Op68M0
			NEXTOPCODE
Op69M0mod4:
lbl69mod4a:	Immediate16
lbl69mod4b:	ADC16
			NEXTOPCODE
.pool			
Op6AM0mod4:
lbl6Amod4a:	A_ROR16
			NEXTOPCODE
Op6Bmod4:
lbl6Bmod4:	Op6B
			NEXTOPCODE
Op6Cmod4:
lbl6Cmod4:	Op6C
			NEXTOPCODE
Op6DM0mod4:
lbl6Dmod4a:	Absolute
lbl6Dmod4b:	ADC16
			NEXTOPCODE
Op6EM0mod4:
lbl6Emod4a:	Absolute
lbl6Emod4b:	ROR16
			NEXTOPCODE
Op6FM0mod4:
lbl6Fmod4a:	AbsoluteLong
lbl6Fmod4b:	ADC16
			NEXTOPCODE
Op70mod4:
lbl70mod4:	Op70
			NEXTOPCODE
Op71M0mod4:
lbl71mod4a:	DirectIndirectIndexed1
lbl71mod4b:	ADC16
			NEXTOPCODE
Op72M0mod4:
lbl72mod4a:	DirectIndirect
lbl72mod4b:	ADC16
			NEXTOPCODE
Op73M0mod4:
lbl73mod4a:	StackasmRelativeIndirectIndexed1
lbl73mod4b:	ADC16
			NEXTOPCODE
.pool
Op74M0mod4:
lbl74mod4a:	DirectIndexedX1
lbl74mod4b:	STZ16
			NEXTOPCODE
Op75M0mod4:
lbl75mod4a:	DirectIndexedX1
lbl75mod4b:	ADC16
			NEXTOPCODE
.pool
Op76M0mod4:
lbl76mod4a:	DirectIndexedX1
lbl76mod4b:	ROR16
			NEXTOPCODE
Op77M0mod4:
lbl77mod4a:	DirectIndirectIndexedLong1
lbl77mod4b:	ADC16
			NEXTOPCODE
Op78mod4:
lbl78mod4:	Op78
			NEXTOPCODE
Op79M0mod4:
lbl79mod4a:	AbsoluteIndexedY1
lbl79mod4b:	ADC16
			NEXTOPCODE
Op7AX1mod4:
lbl7Amod4:	Op7AX1
			NEXTOPCODE
Op7Bmod4:
lbl7Bmod4:	Op7BM0
			NEXTOPCODE
Op7Cmod4:
lbl7Cmod4:	AbsoluteIndexedIndirectX1
		Op7C
			NEXTOPCODE
Op7DM0mod4:
lbl7Dmod4a:	AbsoluteIndexedX1
lbl7Dmod4b:	ADC16
			NEXTOPCODE
Op7EM0mod4:
lbl7Emod4a:	AbsoluteIndexedX1
lbl7Emod4b:	ROR16
			NEXTOPCODE
Op7FM0mod4:
lbl7Fmod4a:	AbsoluteLongIndexedX1
lbl7Fmod4b:	ADC16
			NEXTOPCODE
.pool			
Op80mod4:
lbl80mod4:	Op80
			NEXTOPCODE
Op81M0mod4:
lbl81mod4a:	DirectIndexedIndirect1
lbl81mod4b:	Op81M0
			NEXTOPCODE
Op82mod4:
lbl82mod4:	Op82
			NEXTOPCODE
Op83M0mod4:
lbl83mod4a:	StackasmRelative
lbl83mod4b:	STA16
			NEXTOPCODE
Op84X1mod4:
lbl84mod4a:	Direct
lbl84mod4b:	STY8
			NEXTOPCODE
Op85M0mod4:
lbl85mod4a:	Direct
lbl85mod4b:	STA16
			NEXTOPCODE
Op86X1mod4:
lbl86mod4a:	Direct
lbl86mod4b:	STX8
			NEXTOPCODE
Op87M0mod4:
lbl87mod4a:	DirectIndirectLong
lbl87mod4b:	STA16
			NEXTOPCODE
Op88X1mod4:
lbl88mod4:	Op88X1
			NEXTOPCODE
Op89M0mod4:
lbl89mod4:	Op89M0
			NEXTOPCODE
Op8AM0mod4:
lbl8Amod4:	Op8AM0X1
			NEXTOPCODE
Op8Bmod4:
lbl8Bmod4:	Op8B
			NEXTOPCODE
Op8CX1mod4:
lbl8Cmod4a:	Absolute
lbl8Cmod4b:	STY8
			NEXTOPCODE
Op8DM0mod4:
lbl8Dmod4a:	Absolute
lbl8Dmod4b:	STA16
			NEXTOPCODE
Op8EX1mod4:
lbl8Emod4a:	Absolute
lbl8Emod4b:	STX8
			NEXTOPCODE
Op8FM0mod4:
lbl8Fmod4a:	AbsoluteLong
lbl8Fmod4b:	STA16
			NEXTOPCODE
Op90mod4:
lbl90mod4:	Op90
			NEXTOPCODE
Op91M0mod4:
lbl91mod4a:	DirectIndirectIndexed1
lbl91mod4b:	STA16
			NEXTOPCODE
Op92M0mod4:
lbl92mod4a:	DirectIndirect
lbl92mod4b:	STA16
			NEXTOPCODE
Op93M0mod4:
lbl93mod4a:	StackasmRelativeIndirectIndexed1
lbl93mod4b:	STA16
			NEXTOPCODE
Op94X1mod4:
lbl94mod4a:	DirectIndexedX1
lbl94mod4b:	STY8
			NEXTOPCODE
Op95M0mod4:
lbl95mod4a:	DirectIndexedX1
lbl95mod4b:	STA16
			NEXTOPCODE
Op96X1mod4:
lbl96mod4a:	DirectIndexedY1
lbl96mod4b:	STX8
			NEXTOPCODE
Op97M0mod4:
lbl97mod4a:	DirectIndirectIndexedLong1
lbl97mod4b:	STA16
			NEXTOPCODE
Op98M0mod4:
lbl98mod4:	Op98M0X1
			NEXTOPCODE
Op99M0mod4:
lbl99mod4a:	AbsoluteIndexedY1
lbl99mod4b:	STA16
			NEXTOPCODE
Op9Amod4:
lbl9Amod4:	Op9AX1
			NEXTOPCODE
Op9BX1mod4:
lbl9Bmod4:	Op9BX1
			NEXTOPCODE
Op9CM0mod4:
lbl9Cmod4a:	Absolute
lbl9Cmod4b:	STZ16
			NEXTOPCODE
Op9DM0mod4:
lbl9Dmod4a:	AbsoluteIndexedX1
lbl9Dmod4b:	STA16
			NEXTOPCODE
Op9EM0mod4:	
lbl9Emod4:	AbsoluteIndexedX1		
		STZ16
			NEXTOPCODE
Op9FM0mod4:
lbl9Fmod4a:	AbsoluteLongIndexedX1
lbl9Fmod4b:	STA16
			NEXTOPCODE
OpA0X1mod4:
lblA0mod4:	OpA0X1
			NEXTOPCODE
OpA1M0mod4:
lblA1mod4a:	DirectIndexedIndirect1
lblA1mod4b:	LDA16
			NEXTOPCODE
OpA2X1mod4:
lblA2mod4:	OpA2X1
			NEXTOPCODE
OpA3M0mod4:
lblA3mod4a:	StackasmRelative
lblA3mod4b:	LDA16
			NEXTOPCODE
OpA4X1mod4:
lblA4mod4a:	Direct
lblA4mod4b:	LDY8
			NEXTOPCODE
OpA5M0mod4:
lblA5mod4a:	Direct
lblA5mod4b:	LDA16
			NEXTOPCODE
OpA6X1mod4:
lblA6mod4a:	Direct
lblA6mod4b:	LDX8
			NEXTOPCODE
OpA7M0mod4:
lblA7mod4a:	DirectIndirectLong
lblA7mod4b:	LDA16
			NEXTOPCODE
OpA8X1mod4:
lblA8mod4:	OpA8X1M0
			NEXTOPCODE
OpA9M0mod4:
lblA9mod4:	OpA9M0
			NEXTOPCODE
OpAAX1mod4:
lblAAmod4:	OpAAX1M0
			NEXTOPCODE
OpABmod4:
lblABmod4:	OpAB
			NEXTOPCODE
OpACX1mod4:
lblACmod4a:	Absolute
lblACmod4b:	LDY8
			NEXTOPCODE
OpADM0mod4:
lblADmod4a:	Absolute
lblADmod4b:	LDA16
			NEXTOPCODE
OpAEX1mod4:
lblAEmod4a:	Absolute
lblAEmod4b:	LDX8
			NEXTOPCODE
OpAFM0mod4:
lblAFmod4a:	AbsoluteLong
lblAFmod4b:	LDA16
			NEXTOPCODE
OpB0mod4:
lblB0mod4:	OpB0
			NEXTOPCODE
OpB1M0mod4:
lblB1mod4a:	DirectIndirectIndexed1
lblB1mod4b:	LDA16
			NEXTOPCODE
OpB2M0mod4:
lblB2mod4a:	DirectIndirect
lblB2mod4b:	LDA16
			NEXTOPCODE
OpB3M0mod4:
lblB3mod4a:	StackasmRelativeIndirectIndexed1
lblB3mod4b:	LDA16
			NEXTOPCODE
OpB4X1mod4:
lblB4mod4a:	DirectIndexedX1
lblB4mod4b:	LDY8
			NEXTOPCODE
OpB5M0mod4:
lblB5mod4a:	DirectIndexedX1
lblB5mod4b:	LDA16
			NEXTOPCODE
OpB6X1mod4:
lblB6mod4a:	DirectIndexedY1
lblB6mod4b:	LDX8
			NEXTOPCODE
OpB7M0mod4:
lblB7mod4a:	DirectIndirectIndexedLong1
lblB7mod4b:	LDA16
			NEXTOPCODE
OpB8mod4:
lblB8mod4:	OpB8
			NEXTOPCODE
OpB9M0mod4:
lblB9mod4a:	AbsoluteIndexedY1
lblB9mod4b:	LDA16
			NEXTOPCODE
OpBAX1mod4:
lblBAmod4:	OpBAX1
			NEXTOPCODE
OpBBX1mod4:
lblBBmod4:	OpBBX1
			NEXTOPCODE
OpBCX1mod4:
lblBCmod4a:	AbsoluteIndexedX1
lblBCmod4b:	LDY8
			NEXTOPCODE
OpBDM0mod4:
lblBDmod4a:	AbsoluteIndexedX1
lblBDmod4b:	LDA16
			NEXTOPCODE
OpBEX1mod4:
lblBEmod4a:	AbsoluteIndexedY1
lblBEmod4b:	LDX8
			NEXTOPCODE
OpBFM0mod4:
lblBFmod4a:	AbsoluteLongIndexedX1
lblBFmod4b:	LDA16
			NEXTOPCODE
OpC0X1mod4:
lblC0mod4:	OpC0X1
			NEXTOPCODE
OpC1M0mod4:
lblC1mod4a:	DirectIndexedIndirect1
lblC1mod4b:	CMP16
			NEXTOPCODE
OpC2mod4:
lblC2mod4:	OpC2
			NEXTOPCODE
.pool
OpC3M0mod4:
lblC3mod4a:	StackasmRelative
lblC3mod4b:	CMP16
			NEXTOPCODE
OpC4X1mod4:
lblC4mod4a:	Direct
lblC4mod4b:	CMY8
			NEXTOPCODE
OpC5M0mod4:
lblC5mod4a:	Direct
lblC5mod4b:	CMP16
			NEXTOPCODE
OpC6M0mod4:
lblC6mod4a:	Direct
lblC6mod4b:	DEC16
			NEXTOPCODE
OpC7M0mod4:
lblC7mod4a:	DirectIndirectLong
lblC7mod4b:	CMP16
			NEXTOPCODE
OpC8X1mod4:
lblC8mod4:	OpC8X1
			NEXTOPCODE
OpC9M0mod4:
lblC9mod4:	OpC9M0
			NEXTOPCODE
OpCAX1mod4:
lblCAmod4:	OpCAX1
			NEXTOPCODE
OpCBmod4:
lblCBmod4:	OpCB
			NEXTOPCODE
OpCCX1mod4:
lblCCmod4a:	Absolute
lblCCmod4b:	CMY8
			NEXTOPCODE
OpCDM0mod4:
lblCDmod4a:	Absolute
lblCDmod4b:	CMP16
			NEXTOPCODE
OpCEM0mod4:
lblCEmod4a:	Absolute
lblCEmod4b:	DEC16
			NEXTOPCODE
OpCFM0mod4:
lblCFmod4a:	AbsoluteLong
lblCFmod4b:	CMP16
			NEXTOPCODE
OpD0mod4:
lblD0mod4:	OpD0
			NEXTOPCODE
OpD1M0mod4:
lblD1mod4a:	DirectIndirectIndexed1
lblD1mod4b:	CMP16
			NEXTOPCODE
OpD2M0mod4:
lblD2mod4a:	DirectIndirect
lblD2mod4b:	CMP16
			NEXTOPCODE
OpD3M0mod4:
lblD3mod4a:	StackasmRelativeIndirectIndexed1
lblD3mod4b:	CMP16
			NEXTOPCODE
OpD4mod4:
lblD4mod4:	OpD4
			NEXTOPCODE
OpD5M0mod4:
lblD5mod4a:	DirectIndexedX1
lblD5mod4b:	CMP16
			NEXTOPCODE
OpD6M0mod4:
lblD6mod4a:	DirectIndexedX1
lblD6mod4b:	DEC16
			NEXTOPCODE
OpD7M0mod4:
lblD7mod4a:	DirectIndirectIndexedLong1
lblD7mod4b:	CMP16
			NEXTOPCODE
OpD8mod4:
lblD8mod4:	OpD8
			NEXTOPCODE
OpD9M0mod4:
lblD9mod4a:	AbsoluteIndexedY1
lblD9mod4b:	CMP16
			NEXTOPCODE
OpDAX1mod4:
lblDAmod4:	OpDAX1
			NEXTOPCODE
OpDBmod4:
lblDBmod4:	OpDB
			NEXTOPCODE
OpDCmod4:
lblDCmod4:	OpDC
			NEXTOPCODE
OpDDM0mod4:
lblDDmod4a:	AbsoluteIndexedX1
lblDDmod4b:	CMP16
			NEXTOPCODE
OpDEM0mod4:
lblDEmod4a:	AbsoluteIndexedX1
lblDEmod4b:	DEC16
			NEXTOPCODE
OpDFM0mod4:
lblDFmod4a:	AbsoluteLongIndexedX1
lblDFmod4b:	CMP16
			NEXTOPCODE
OpE0X1mod4:
lblE0mod4:	OpE0X1
			NEXTOPCODE
OpE1M0mod4:
lblE1mod4a:	DirectIndexedIndirect1
lblE1mod4b:	SBC16
			NEXTOPCODE
OpE2mod4:
lblE2mod4:	OpE2
			NEXTOPCODE
.pool
OpE3M0mod4:
lblE3mod4a:	StackasmRelative
lblE3mod4b:	SBC16
			NEXTOPCODE
OpE4X1mod4:
lblE4mod4a:	Direct
lblE4mod4b:	CMX8
			NEXTOPCODE
OpE5M0mod4:
lblE5mod4a:	Direct
lblE5mod4b:	SBC16
			NEXTOPCODE
OpE6M0mod4:
lblE6mod4a:	Direct
lblE6mod4b:	INC16
			NEXTOPCODE
OpE7M0mod4:
lblE7mod4a:	DirectIndirectLong
lblE7mod4b:	SBC16
			NEXTOPCODE
OpE8X1mod4:
lblE8mod4:	OpE8X1
			NEXTOPCODE
OpE9M0mod4:
lblE9mod4a:	Immediate16
lblE9mod4b:	SBC16
			NEXTOPCODE
OpEAmod4:
lblEAmod4:	OpEA
			NEXTOPCODE
OpEBmod4:
lblEBmod4:	OpEBM0
			NEXTOPCODE
OpECX1mod4:
lblECmod4a:	Absolute
lblECmod4b:	CMX8
			NEXTOPCODE
OpEDM0mod4:
lblEDmod4a:	Absolute
lblEDmod4b:	SBC16
			NEXTOPCODE
OpEEM0mod4:
lblEEmod4a:	Absolute
lblEEmod4b:	INC16
			NEXTOPCODE
OpEFM0mod4:
lblEFmod4a:	AbsoluteLong
lblEFmod4b:	SBC16
			NEXTOPCODE
OpF0mod4:
lblF0mod4:	OpF0
			NEXTOPCODE
OpF1M0mod4:
lblF1mod4a:	DirectIndirectIndexed1
lblF1mod4b:	SBC16
			NEXTOPCODE
OpF2M0mod4:
lblF2mod4a:	DirectIndirect
lblF2mod4b:	SBC16
			NEXTOPCODE
OpF3M0mod4:
lblF3mod4a:	StackasmRelativeIndirectIndexed1
lblF3mod4b:	SBC16
			NEXTOPCODE
OpF4mod4:
lblF4mod4:	OpF4
			NEXTOPCODE
OpF5M0mod4:
lblF5mod4a:	DirectIndexedX1
lblF5mod4b:	SBC16
			NEXTOPCODE
OpF6M0mod4:
lblF6mod4a:	DirectIndexedX1
lblF6mod4b:	INC16
			NEXTOPCODE
OpF7M0mod4:
lblF7mod4a:	DirectIndirectIndexedLong1
lblF7mod4b:	SBC16
			NEXTOPCODE
OpF8mod4:
lblF8mod4:	OpF8
			NEXTOPCODE
OpF9M0mod4:
lblF9mod4a:	AbsoluteIndexedY1
lblF9mod4b:	SBC16
			NEXTOPCODE
OpFAX1mod4:
lblFAmod4:	OpFAX1
			NEXTOPCODE
OpFBmod4:
lblFBmod4:	OpFB
			NEXTOPCODE
OpFCmod4:
lblFCmod4:	OpFCX1
			NEXTOPCODE
OpFDM0mod4:
lblFDmod4a:	AbsoluteIndexedX1
lblFDmod4b:	SBC16
			NEXTOPCODE
OpFEM0mod4:
lblFEmod4a:	AbsoluteIndexedX1
lblFEmod4b:	INC16
			NEXTOPCODE
OpFFM0mod4:
lblFFmod4a:	AbsoluteLongIndexedX1
lblFFmod4b:	SBC16
			NEXTOPCODE

			
			.pool

