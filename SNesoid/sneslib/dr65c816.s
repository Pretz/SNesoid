

	.data
	
	
;@ MASK_EMUL	MASK_MEM	MASK_INDEX		Jump Table
;@ TRUE			?			?				jumptable1		Mode 0 : M=1,X=1
;@ FALSE		TRUE		TRUE			jumptable1		Mode 0 : M=1,X=1
;@ FALSE		TRUE		FALSE			jumptable2		Mode 1 : M=1,X=0
;@ FALSE		FALSE		TRUE			jumptable4		Mode 3 : M=0,X=1
;@ FALSE		FALSE		FALSE			jumptable3		Mode 2 : M=0,X=0

opcodetable_lookup_addr	opcodetable_lookup
opcodetable_lookup: 
	.word jumptable3 ;@ 000
	.word jumptable4 ;@ 001
	.word jumptable2 ;@ 010
	.word jumptable1 ;@ 011
	.word jumptable1 ;@ 100
	.word jumptable1 ;@ 101
	.word jumptable1 ;@ 110
	.word jumptable1 ;@ 111
	
get_opcode_table:
	ldr r0,opcodetable_lookup_addr
	and r1,reg_f,MASK_EMUL	MASK_MEM	MASK_INDEX
	ldr opcodes,[r0,r1,lsl#2]
	mov pc,lr

	
	reg_a				.req r5
	reg_d_bank			.req r5
	reg_d				.req r5
	reg_p_bank				.req r5
	reg_x				.req r5
	reg_sp				.req r5
	reg_y				.req r5
	reg_f				.req r5
	reg_pc				.req r5
	cycles				.req r5
	cpu_context			.req r5
	opcodes				.req r5

	.equ BRKtriggered
	.equ pc_base

.equ STATUS_SHIFTER,		24
.equ MASK_EMUL,				(1<<(STATUS_SHIFTER-1))
.equ MASK_SHIFTER_CARRY,	(STATUS_SHIFTER+1)
.equ	MASK_CARRY,			(1<<(STATUS_SHIFTER))  @ 0
.equ	MASK_ZERO,			(2<<(STATUS_SHIFTER))  @ 1
.equ MASK_IRQ,				(4<<(STATUS_SHIFTER))  @ 2
.equ MASK_DECIMAL,			(8<<(STATUS_SHIFTER))  @ 3
.equ	MASK_INDEX,			(16<<(STATUS_SHIFTER)) @ 4  @ 1
.equ	MASK_MEM,			(32<<(STATUS_SHIFTER)) @ 5  @ 2
.equ	MASK_OVERFLOW,		(64<<(STATUS_SHIFTER)) @ 6  @ 4
.equ	MASK_NEG,			(128<<(STATUS_SHIFTER))@ 7  @ 8

.macro prepare_c_call
	stmfd sp!,{r12}
.endm

.macro restore_c_call
	ldmfd sp!,{r12}
.endm

;@push16 - saves a 16bit value onto stack
;@ r0 = address 0x0000HHLL
;@ r1 = data    0x0000HHLL
.macro push16
	prepare_c_call
	mov lr,pc
	ldr pc,[cpu_context,#writemem16]  ;@ r0 = address  r1=data
	restore_c_call
.endm

;@push16 - saves a 8bit value onto stack
;@ r0 = address 0x0000HHLL
;@ r1 = data    0x0000HHLL
.macro push8
	prepare_c_call
	mov lr,pc
	ldr pc,[cpu_context,#writemem8]  ;@ r0 = address  r1=data
	restore_c_call
.endm

.macro mov_reg_sp_to_r0
	mov r0,reg_sp
.endm

.macro push16_s24 reg
	mov_reg_sp_to_r0
	mov r1,\reg>>24
	push16
.endm

.macro push16_s16 reg
	mov_reg_sp_to_r0
	mov r1,\reg>>16
	push16
.endm

.macro push16_s8 reg
	mov_reg_sp_to_r0
	mov r1,\reg>>8
	push16
.endm

.macro push16_s0 reg
	mov_reg_sp_to_r0
	mov r1,\reg>
	push16
.endm

.macro push8_s24 reg
	mov_reg_sp_to_r0
	mov r1,\reg>>24
	push8
.endm

.macro push8_s16 reg
	mov_reg_sp_to_r0
	mov r1,\reg>>16
	push8
.endm

.macro push8_s8 reg
	mov_reg_sp_to_r0
	mov r1,\reg>>8
	push8
.endm

.macro push8_s0 reg
	mov_reg_sp_to_r0
	mov r1,\reg>
	push8
.endm

.macro pushPC
	ldr r1,[cpu_context,#pc_base]
	sub r1,reg_pc,r1
	push16_s0
.endm

.macro getSnesFlags reg
	sub \reg,[cpu_context,#snes_flag_lookup]
	ldr \reg,[\reg,reg_f>>24]
.endm


.macro setIRQ
	;@ IRQ flag has ben raised
.endm

;@ re-calculates reg_pc and pc_base
;@ in: r0=new snes pc
;@ out: r0=new arm pc
.macro setPCbase
	prepare_c_call
	mov lr,pc
	ldr pc,[cpu_context,#rebase_pc]
	restore_c_call
	mov reg_pc,r0
.endm

.macro fetch cyc
	subs cycles,cycles,#\cyc
	ldrplb r0,[reg_pc],#1
	ldrpl pc,[opcodes,r0, lsl #2]
	bmi cpu_execute_end
.endm


cpu_execute:
	;@ load cpu context
	;@ check interupts
	;@ run opcodes

cpu_execute_end
	;@ cycle count has expired
	;@    This means that 
	;@         	All cpu cycles requested have been used
	;@         	NMI interupt has occurred
	;@			IRQ interupt has occurred
	;@    Check which counter has expired
	;@      if normal cycle count then exit cpu emulation
	;@         this will only occur while NMI and IRQ ints are NOT pending
	;@      if NMI cycle count then raise NMI interrupt
	;@         then continue cpu emulation using IRQ cycle count (if any) otherwise use remaining cycle count
	;@         which would already be adjusted to remove NMI cycles used.
	;@         count between normal cycles and IRQ cycles.
	;@      if IRQ cycle count then raise IRQ interrupt.
	;@      
	;@ save cpu context
	;@ exit
	

	

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
			

;@ ##############################################
;@ BRK 
;@ ##############################################		
Op00mod1:
lbl00mod1:
	;@ set BRK flag
	;@ Only used by SuperFX emulation
	mov r0,#1
	strb r0,[cpu_context,#BRKTriggered]
		
	tst reg_f, #MASK_EMUL
	bne 1f

	push8_s0 reg_p_bank
	pushPC
	getSnesFlags r1
	push8_s0	
	clearFlag #MASK_DECIMAL
	SetIRQ
	bic reg_p_bank, reg_p_bank, #0xFF
	mov r0,0xE6
	orr r0,r0,0xFF00
	readmem16_s0
	setPCbase
	use_cycles 2
	b 2f
	
1:
	pushPC
	getSnesFlags r1
	push8_s0	
	clearFlag #MASK_DECIMAL
	SetFlag #MASK_IRQ
	bic reg_p_bank, reg_p_bank, #0xFF
	mov r0,0xFE
	orr r0,r0,0xFF00
	readmem16_s0
	setPCbase
	use_cycles 1
2:
	
			
			
	