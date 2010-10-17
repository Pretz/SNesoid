
	.global SnesScreenClear32
	.global SnesScreenClear8

SnesScreenClear32:
	;@ r0 = pointer to screen
	;@ r1 = number of lines to update
	;@ r2 = colour
	
	stmfd sp!,{r4-r9,lr}
	mov r3,r2 ;@ copy the back colour to 7 other regs
	mov r4,r2
	mov r5,r2
	mov r6,r2
	mov r7,r2
	mov r8,r2
	mov r9,r2
1:
	stmia r0!,{r2-r9} ;@ now store 8*2 pixels in 1 opcode
	stmia r0!,{r2-r9} ;@ do this 16 times, which equals 256 pixels
	stmia r0!,{r2-r9} ;@ which is the length of a snes rendered line on the GP2X
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}
	
	subs r1,r1,#1
	;@ if we need to loop again, then push screen pointer to start of next line
	addne r0,r0,#640-(256*2)  ;@  RealPitch(640) - 
	bne 1b
	ldmfd sp!,{r4-r9,pc}
	
SnesScreenClear8:	
	;@ r0 = pointer to screen
	;@ r1 = number of lines to update
	;@ r2 = colour
	
	stmfd sp!,{r4-r9,lr}
	mov r3,r2 ;@ copy the back colour to 7 other regs
	mov r4,r2
	mov r5,r2
	mov r6,r2
	mov r7,r2
	mov r8,r2
	mov r9,r2
1:
	stmia r0!,{r2-r9} ;@ now store 8*2 pixels in 1 opcode
	stmia r0!,{r2-r9} ;@ do this 8 times, which equals 256 8bit pixels
	stmia r0!,{r2-r9} ;@ which is the length of a snes rendered line on the GP2X
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}
	stmia r0!,{r2-r9}

	
	subs r1,r1,#1
	;@ if we need to loop again, then push screen pointer to start of next line
	addne r0,r0,#320-256  ;@  ZPitch(320) - 
	bne 1b
	ldmfd sp!,{r4-r9,pc}
	
	