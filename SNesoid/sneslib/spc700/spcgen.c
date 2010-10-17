// notaz's SPC700 Emulator
// (c) Copyright 2006 notaz, All rights reserved.
//
// this is a rewrite of spc700.cpp in ARM asm, inspired by other asm CPU cores like
// Cyclone and DrZ80. It is meant to be used in Snes9x emulator ports for ARM platforms.
//
// notes:
// "Shutdown" mechanism is not supported, so undefine SPC700_SHUTDOWN in your port.h
// code branches backwards over start of memory are not supported
// (never seen any game doing that)
//
// license:
// the code is released under Snes9x license. It would be nice if the word "notaz"
// would appear somewhere in your documentation or your program's "about" screen
// if you use this :)

/*
 * Permission to use, copy, modify and distribute Snes9x in both binary and
 * source form, for non-commercial purposes, is hereby granted without fee,
 * providing that this license information and copyright notice appear with
 * all copies and any derived work.
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event shall the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Snes9x is freeware for PERSONAL USE only. Commercial users should
 * seek permission of the copyright holders first. Commercial use includes
 * charging money for Snes9x or software derived from Snes9x.
 *
 * The copyright holders request that bug fixes and improvements to the code
 * should be forwarded to them so everyone can benefit from the modifications
 * in future versions.
 *
 * Super NES and Super Nintendo Entertainment System are trademarks of
 * Nintendo Co., Limited and its subsidiary companies.
 */


// settings
#define ONE_APU_CYCLE 21
#define VERSION "0.11"
//#define SPC_DEBUG


// includes
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>


// timings
int S9xAPUCycles [256] =
{
    /*        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, a, b, c, d, e, f, */
    /* 00 */  2, 8, 4, 5, 3, 4, 3, 6, 2, 6, 5, 4, 5, 4, 6, 8, 
    /* 10 */  2, 8, 4, 5, 4, 5, 5, 6, 5, 5, 6, 5, 2, 2, 4, 6, 
    /* 20 */  2, 8, 4, 5, 3, 4, 3, 6, 2, 6, 5, 4, 5, 4, 5, 4, 
    /* 30 */  2, 8, 4, 5, 4, 5, 5, 6, 5, 5, 6, 5, 2, 2, 3, 8, 
    /* 40 */  2, 8, 4, 5, 3, 4, 3, 6, 2, 6, 4, 4, 5, 4, 6, 6, 
    /* 50 */  2, 8, 4, 5, 4, 5, 5, 6, 5, 5, 4, 5, 2, 2, 4, 3, 
    /* 60 */  2, 8, 4, 5, 3, 4, 3, 6, 2, 6, 4, 4, 5, 4, 5, 5, 
    /* 70 */  2, 8, 4, 5, 4, 5, 5, 6, 5, 5, 5, 5, 2, 2, 3, 6, 
    /* 80 */  2, 8, 4, 5, 3, 4, 3, 6, 2, 6, 5, 4, 5, 2, 4, 5, 
    /* 90 */  2, 8, 4, 5, 4, 5, 5, 6, 5, 5, 5, 5, 2, 2,12, 5, 
    /* a0 */  3, 8, 4, 5, 3, 4, 3, 6, 2, 6, 4, 4, 5, 2, 4, 4, 
    /* b0 */  2, 8, 4, 5, 4, 5, 5, 6, 5, 5, 5, 5, 2, 2, 3, 4, 
    /* c0 */  3, 8, 4, 5, 4, 5, 4, 7, 2, 5, 6, 4, 5, 2, 4, 9, 
    /* d0 */  2, 8, 4, 5, 5, 6, 6, 7, 4, 5, 4, 5, 2, 2, 6, 3, 
    /* e0 */  2, 8, 4, 5, 3, 4, 3, 6, 2, 4, 5, 3, 4, 3, 4, 3, 
    /* f0 */  2, 8, 4, 5, 4, 5, 5, 6, 3, 4, 5, 4, 2, 2, 4, 3
};


// stuff
static FILE *AsmFile=NULL;
static int opcode=0; // 0-0xff

void ot(char *format, ...)
{
  va_list valist=NULL;
  int i, len;

  // notaz: stop me from leaving newlines in the middle of format string
  // and generating bad code
  for(i=0, len=strlen(format); i < len && format[i] != '\n'; i++);
  if(i < len-1 && format[len-1] != '\n') printf("\nWARNING: possible improper newline placement:\n%s\n", format);

  va_start(valist,format);
  if (AsmFile) vfprintf(AsmFile,format,valist);
  va_end(valist);
}


//  r0-2: Temporary registers
//  r3  : current opcode or temp
//  r4  : Cycles remaining
//  r5  : Pointer to IAPU structure
//  r6  : Pointer to Opcode Jump table
//  r7  : Current PC
//  r8  : YA
//  r9  : P (nzzzzzzz ........ ........ NODBHIZC; nzzzzzzz - NZ flag in use (for a little speedup)
//  r10 : X
//  r11 : S
//  r12 : temp
//  lr  : RAM pointer

static void PrintFramework()
{
#ifndef SPC_DEBUG
	ot("  .extern IAPU\n");
#else
	ot("  .extern IAPU2\n");
#endif
	ot("  .extern CPU @ for STOP and SLEEP\n");
	ot("  .extern S9xAPUGetByte\n");
	ot("  .extern S9xAPUSetByte\n");
	ot("  .extern S9xAPUGetByteZ\n");
	ot("  .extern S9xAPUSetByteZ\n\n");

	ot("  .global spc700_execute @ int cycles\n");
	ot("  .global Spc700JumpTab\n\n");

	ot("  opcode  .req r3\n");
	ot("  cycles  .req r4\n");
	ot("  context .req r5\n");
	ot("  opcodes .req r6\n");
	ot("  spc_pc  .req r7\n");
	ot("  spc_ya  .req r8\n");
	ot("  spc_p   .req r9\n");
	ot("  spc_x   .req r10\n");
	ot("  spc_s   .req r11\n");
	ot("  spc_ram .req lr\n\n");

	ot("  .equ iapu_directpage,    0x00\n");
	ot("  .equ iapu_ram,           0x44\n");
	ot("  .equ iapu_extraram,      0x48\n");
	ot("  .equ iapu_allregs_load,  0x30\n");
	ot("  .equ iapu_allregs_save,  0x34\n\n");

	ot("  .equ flag_c,             0x01\n");
	ot("  .equ flag_z,             0x02\n");
	ot("  .equ flag_i,             0x04\n");
	ot("  .equ flag_h,             0x08\n");
	ot("  .equ flag_b,             0x10\n");
	ot("  .equ flag_d,             0x20\n");
	ot("  .equ flag_o,             0x40\n");
	ot("  .equ flag_n,             0x80\n\n");

	// tmp
//	ot("  .equ iapu_carry,         0x24\n");
//	ot("  .equ iapu_overflow,      0x26\n\n");

	ot("@ --------------------------- Framework --------------------------\n");
	ot("spc700_execute: @ int cycles\n");

	ot("  stmfd sp!,{r4-r11,lr}\n");

#ifndef SPC_DEBUG
	ot("  ldr   context,=IAPU               @ Pointer to SIAPU struct\n");
#else
	ot("  ldr   context,=IAPU2              @ Pointer to SIAPU struct\n");
#endif
	ot("  mov   cycles,r0                   @ Cycles\n");
	ot("  add   r0,context,#iapu_allregs_load\n");
	ot("  ldmia r0,{opcodes,spc_pc,spc_ya,spc_p,spc_x,spc_ram}\n");

	ot("  mov   spc_s,spc_x,lsr #8\n");
	ot("  and   spc_x,spc_x,#0xff\n");
	ot("\n");

	ot("  ldrb  opcode,[spc_pc],#1          @ Fetch first opcode\n");
	ot("  ldr   pc,[opcodes,opcode,lsl #2]  @ Jump to opcode handler\n");
	ot("\n\n");


	ot("@ We come back here after execution\n");
	ot("spc700End:\n");
	ot("  orr   spc_x,spc_x,spc_s,lsl #8\n");
	ot("  add   r0,context,#iapu_allregs_save\n");
	ot("  stmia r0,{spc_pc,spc_ya,spc_p,spc_x}\n");
	ot("  mov   r0,cycles\n");
	ot("  ldmfd sp!,{r4-r11,pc}\n");
	ot("\n");

	ot("  .ltorg\n");
	ot("\n");
}


// ---------------------------------------------------------------------------

// Trashes r0-r3
static void MemHandler(int set, int z, int save)
{
	if(set) ot("  bl    S9xAPUSetByte%s\n", z ? "Z" : "");
	else    ot("  bl    S9xAPUGetByte%s\n", z ? "Z" : "");

	if(save) ot("  ldr   spc_ram,[context,#iapu_ram]\n");
}

// pushes reg, trashes r1
static void Push(char *reg)
{
	ot("  add   r1,spc_ram,spc_s\n");
	ot("  strb  %s,[r1,#0x100]\n", reg);
	ot("  sub   spc_s,spc_s,#1\n");
}

// pushes r0, trashes r0,r1
static void PushW()
{
	ot("  add   r1,spc_ram,spc_s\n");
	ot("  strb  r0,[r1,#0xff]\n");
	ot("  mov   r0,r0,lsr #8\n");
	ot("  strb  r0,[r1,#0x100]\n");
	ot("  sub   spc_s,spc_s,#2\n");
}

// pops to reg
static void Pop(char *reg)
{
	ot("  add   spc_s,spc_s,#1\n");
	ot("  add   %s,spc_ram,spc_s\n", reg);
	ot("  ldrb  %s,[%s,#0x100]\n", reg, reg);
}

// pops to r0, trashes r1
static void PopW()
{
	ot("  add   spc_s,spc_s,#2\n");
	ot("  add   r1,spc_ram,spc_s\n");
	ot("  ldrb  r0,[r1,#0xff]\n");
	ot("  ldrb  r1,[r1,#0x100]\n");
	ot("  orr   r0,r0,r1,lsl #8\n");
}

// rr <- absolute, trashes r12
static void Absolute(int r)
{
	ot("  ldrb  r%i,[spc_pc],#1\n", r);
	ot("  ldrb  r12,[spc_pc],#1\n");
	ot("  orr   r%i,r%i,r12,lsl #8\n", r, r);
}

// rr <- absoluteX, trashes r12
static void AbsoluteX(int r)
{
	Absolute(r);
	ot("  add   r%i,r%i,spc_x\n", r, r);
}

// r0 <- absoluteY, trashes r1
static void AbsoluteY(int r)
{
	Absolute(r);
	ot("  add   r%i,r%i,spc_ya,lsr #8\n", r, r);
}

// rr <- IndirectIndexedY, trashes r12
static void IndirectIndexedY(int r)
{
	ot("  ldrb  r%i,[spc_pc],#1\n", r);
	ot("  ldr   r12,[context,#iapu_directpage]\n");
	ot("  ldrb  r%i,[r12,r%i]!\n", r, r);
	ot("  ldrb  r12,[r12,#1]\n");
	ot("  orr   r%i,r%i,r12,lsl #8\n", r, r);
	ot("  add   r%i,r%i,spc_ya,lsr #8\n", r, r);
}

// rr <- address, trashes r12
static void IndexedXIndirect(int r)
{
	ot("  ldrb  r%i,[spc_pc],#1\n", r);
	ot("  add   r%i,r%i,spc_x\n", r, r);
	ot("  and   r%i,r%i,#0xff\n", r, r);
	ot("  ldr   r12,[context,#iapu_directpage]\n");
	ot("  ldrb  r%i,[r12,r%i]!\n", r, r);
	ot("  ldrb  r12,[r12,#1]\n");
	ot("  orr   r%i,r%i,r12,lsl #8\n", r, r);
}

// sets ZN for reg in *reg, not suitable for Y
static void SetZN8(char *reg)
{
	ot("  and   spc_p,spc_p,#0xff\n");
	ot("  orr   spc_p,spc_p,%s,lsl #24\n", reg);
}

// sets ZN for reg in *reg
static void SetZN16(char *reg)
{
	ot("  and   spc_p,spc_p,#0xff\n");
	ot("  orr   spc_p,spc_p,%s,lsl #16\n", reg);
	ot("  tst   %s,#0xff\n", reg);
	ot("  orrne spc_p,spc_p,#0x01000000\n");
}

// does ROL on r0, sets flags
static void Rol()
{
	ot("  mov   r0,r0,lsl #1\n");
	ot("  tst   spc_p,#flag_c\n");
	ot("  orrne r0,r0,#1\n");
	ot("  tst   r0,#0x100\n");
	ot("  orrne spc_p,spc_p,#flag_c\n");
	ot("  biceq spc_p,spc_p,#flag_c\n");
	SetZN8("r0");
}

// does ROR on r0, sets flags
static void Ror()
{
	ot("  tst   spc_p,#flag_c\n");
	ot("  orrne r0,r0,#0x100\n");
	ot("  movs  r0,r0,lsr #1\n");
	ot("  orrcs spc_p,spc_p,#flag_c\n");
	ot("  biccc spc_p,spc_p,#flag_c\n");
	SetZN8("r0");
}

// does ASL on r0, sets flags but doesn't cut the shifted bits
static void Asl()
{
	ot("  tst   r0,#0x80\n");
	ot("  orrne spc_p,spc_p,#flag_c\n");
	ot("  biceq spc_p,spc_p,#flag_c\n");
	ot("  mov   r0,r0,lsl #1\n");
	SetZN8("r0");
}

// does LSR on r0, sets flags
static void Lsr()
{
	ot("  tst   r0,#0x01\n");
	ot("  orrne spc_p,spc_p,#flag_c\n");
	ot("  biceq spc_p,spc_p,#flag_c\n");
	ot("  mov   r0,r0,lsr #1\n");
	SetZN8("r0");
}

// CMP rr0,rr1; trashes r12
static void Cmp(char *r0, char *r1, int and_r0)
{
	char *lop = r0;

	if(and_r0) { ot("  and   r12,%s,#0xff\n", r0); lop = "r12"; }
	ot("  subs  r12,%s,%s\n", lop, r1);
	ot("  orrge spc_p,spc_p,#flag_c\n");
	ot("  biclt spc_p,spc_p,#flag_c\n");
	SetZN8("r12");
}

// ADC rr0,rr1 -> rr0, trashes r3,r12, does not mask to byte
static void Adc(char *r0, char *r1)
{
	ot("  eor   r3,%s,%s\n", r0, r1); // r3=(a) ^ (b)
	ot("  add   %s,%s,%s\n", r0, r0, r1);
	ot("  tst   spc_p,#flag_c\n");
	ot("  addne %s,%s,#1\n", r0, r0);
	ot("  movs  r12,%s,lsr #8\n", r0);
	ot("  orrne spc_p,spc_p,#flag_c\n");
	ot("  biceq spc_p,spc_p,#flag_c\n");
	ot("  eor   r12,%s,%s\n", r0, r1); // r12=(b) ^ Work16
	ot("  bic   r12,r12,r3\n"); // ((b) ^ Work16) & ~((a) ^ (b))
	ot("  tst   r12,#0x80\n");
	ot("  orrne spc_p,spc_p,#flag_o\n");
	ot("  biceq spc_p,spc_p,#flag_o\n");
	ot("  eor   r12,r3,%s\n", r0);
	ot("  tst   r12,#0x10\n");
	ot("  orrne spc_p,spc_p,#flag_h\n");
	ot("  biceq spc_p,spc_p,#flag_h\n");
}

// SBC rr0,rr1 -> rr0, trashes r2,r3,r12, does not mask to byte
static void Sbc(char *r0, char *r1)
{
	ot("  movs  r12,spc_p,lsr #1\n");
	ot("  sbcs  r2,%s,%s\n", r0, r1);
	ot("  orrge spc_p,spc_p,#flag_c\n");
	ot("  biclt spc_p,spc_p,#flag_c\n");
	ot("  eor   r12,%s,r2\n", r0); // r12=(a) ^ Int16
	ot("  eor   r3,%s,%s\n", r0, r1); // r3=(a) ^ (b)
	ot("  and   r12,r12,r3\n"); // ((a) ^ Work16) & ((a) ^ (b))
	ot("  tst   r12,#0x80\n");
	ot("  orrne spc_p,spc_p,#flag_o\n");
	ot("  biceq spc_p,spc_p,#flag_o\n");
	ot("  eor   r12,r3,r2\n", r0);
	ot("  tst   r12,#0x10\n");
	ot("  orreq spc_p,spc_p,#flag_h\n");
	ot("  bicne spc_p,spc_p,#flag_h\n");
	ot("  mov   %s,r2\n", r0);
}


// 
static void TCall()
{
	ot("  sub   r0,spc_pc,spc_ram\n");
	PushW();
	ot("  ldr   r0,[context,#iapu_extraram]\n");
	ot("  ldrh  r0,[r0,#0x%x]\n", (15-(opcode>>4))<<1);
	ot("  add   spc_pc,spc_ram,r0\n");
}

// 
static void SetClr1()
{
	ot("  ldrb  r0,[spc_pc]\n");
	MemHandler(0, 1, 0);
	ot("  %s   r0,r0,#0x%02x\n", opcode & 0x10 ? "bic" : "orr", 1<<(opcode>>5));
	ot("  ldrb  r1,[spc_pc],#1\n");
	MemHandler(1, 1, 1);
}

// 
static void BssBbc()
{
	ot("  ldrb  r0,[spc_pc],#1\n");
	MemHandler(0, 1, 1);
	ot("  tst   r0,#0x%02x\n", 1<<(opcode>>5));
	ot("  add%s spc_pc,spc_pc,#1\n", opcode & 0x10 ? "ne" : "eq");
	ot("  ldr%ssb r0,[spc_pc],#1\n", opcode & 0x10 ? "eq" : "ne");
	ot("  add%s spc_pc,spc_pc,r0\n", opcode & 0x10 ? "eq" : "ne");
	ot("  sub%s cycles,cycles,#%i\n",opcode & 0x10 ? "eq" : "ne", ONE_APU_CYCLE*2);
}

//
static void Membit()
{
	ot("  ldrb  r0,[spc_pc],#1\n");
	ot("  ldrb  r1,[spc_pc],#1\n");
	ot("  add   r0,r0,r1,lsl #8\n");
	ot("  mov   r1,r1,lsr #5\n");
	ot("  mov   r0,r0,lsl #19\n");
	ot("  mov   r0,r0,lsr #19\n");
	ot("  orr   spc_x,spc_x,r1,lsl #29 @ store membit where it can survive memhandler call\n");
	if((opcode >> 4) >= 0xC)
		ot("  stmfd sp!,{r0}\n");
	MemHandler(0, 0, 0);
	ot("  mov   r1,spc_x,lsr #29\n");
	ot("  and   spc_x,spc_x,#0xff\n");
	if((opcode >> 4) < 0xC) {
		ot("  mov   r0,r0,lsr r1\n");
		ot("  tst   r0,#1\n");
		switch(opcode >> 4) {
			case 0x0: ot("  orrne spc_p,spc_p,#flag_c\n"); break; // OR1 C,membit
			case 0x2: ot("  orreq spc_p,spc_p,#flag_c\n"); break; // OR1 C,not membit
			case 0x4: ot("  biceq spc_p,spc_p,#flag_c\n"); break; // AND1 C,membit
			case 0x6: ot("  bicne spc_p,spc_p,#flag_c\n"); break; // AND1 C, not membit
			case 0x8: ot("  eorne spc_p,spc_p,#flag_c\n"); break; // EOR1 C, membit
			case 0xA: ot("  orrne spc_p,spc_p,#flag_c\n");        // MOV1 C,membit
					  ot("  biceq spc_p,spc_p,#flag_c\n"); break;
		}
	} else {
		ot("  mov   r2,#1\n");
		ot("  mov   r2,r2,lsl r1\n");
		if((opcode >> 4) == 0xC) { // MOV1 membit,C
			ot("  tst   spc_p,#flag_c\n");
			ot("  orrne r0,r0,r2\n");
			ot("  biceq r0,r0,r2\n");
		} else { // NOT1 membit
			ot("  eor   r0,r0,r2\n");
		}
		ot("  ldmfd sp!,{r1}\n");
		MemHandler(1, 0, 0);
	}
	ot("  ldr   spc_ram,[context,#iapu_ram] @ restore what memhandler(s) messed up\n");
}

//
static void CBranch()
{
	int tests[]  = { 0x80000000, 0x40, 0x01, 0xff000000 }; // NOCZ
	char *eq = "eq";
	char *ne = "ne";

	if((opcode>>6) == 3) { // zero test inverts everything
		eq = "ne";
		ne = "eq";
	}

	ot("  tst   spc_p,#0x%08X\n", tests[opcode>>6]);
	ot("  add%s spc_pc,spc_pc,#1\n",  opcode & 0x20 ? eq : ne);
/*
	ot("  b%s   Apu%02X\n",  opcode & 0x20 ? eq : ne, opcode);
	ot("  sub   r0,spc_pc,spc_ram\n");
	ot("  ldrsb r1,[spc_pc],#1\n");
	ot("  add   r0,r0,r1\n");
	ot("  mov   r0,r0,lsl #16\n");
	ot("  add   spc_pc,spc_ram,r0,lsr #16\n");
*/
	ot("  ldr%ssb r0,[spc_pc],#1\n",  opcode & 0x20 ? ne : eq);
	ot("  add%s spc_pc,spc_pc,r0\n",  opcode & 0x20 ? ne : eq);

	ot("  sub%s cycles,cycles,#%i\n", opcode & 0x20 ? ne : eq, ONE_APU_CYCLE*2);
//	ot("Apu%02X:\n", opcode);
}

// NeededOperation spc_ya,r0 -> spc_ya
static void ArithOpToA()
{
	// special A pre-processing
	if((opcode>>5) == 4 || (opcode>>5) == 5) {
		ot("  and   r1,spc_ya,#0xff00\n");
		ot("  and   spc_ya,spc_ya,#0xff\n");
	}

	switch(opcode>>5) {
		case 0: ot("  orr   spc_ya,spc_ya,r0\n"); break; // OR
		case 1: ot("  orr   r0,r0,#0xff00\n");
				ot("  and   spc_ya,spc_ya,r0\n"); break; // AND
		case 2: ot("  eor   spc_ya,spc_ya,r0\n"); break; // EOR
		case 3: Cmp("spc_ya", "r0", 1); break; // CMP
		case 4: Adc("spc_ya", "r0");    break; // ADC
		case 5: Sbc("spc_ya", "r0");    break; // SBC
		case 6: printf("MOV (reversed)!?\n");     break; // MOV (reversed)
		case 7: ot("  and   spc_ya,spc_ya,#0xff00\n");
				ot("  orr   spc_ya,spc_ya,r0\n"); break; // MOV
	}

	if((opcode>>5) != 3) SetZN8("spc_ya"); // only if not Cmp

	// special A post-processing
	if((opcode>>5) == 4 || (opcode>>5) == 5) {
		ot("  and   spc_ya,spc_ya,#0xff\n");
		ot("  orr   spc_ya,spc_ya,r1\n");
	}
}

//
static void ArithmeticToA()
{
	switch(opcode&0x1f) {
		case 0x04: // OP A,dp
			ot("  ldrb  r0,[spc_pc],#1\n");
			MemHandler(0, 1, 1);
			ArithOpToA();
			break;

		case 0x05: // OP A,abs
			Absolute(0);
			MemHandler(0, 0, 1);
			ArithOpToA();
			break;

		case 0x06: // OP A,(X)
			ot("  mov   r0,spc_x\n");
			MemHandler(0, 1, 1);
			ArithOpToA();
			break;

		case 0x07: // OP A,(dp+X)
			IndexedXIndirect(0);
			MemHandler(0, 0, 1);
			ArithOpToA();
			break;

		case 0x08: // OP A,#00
			ot("  ldrb  r0,[spc_pc],#1\n");
			ArithOpToA();
			break;

		case 0x14: // OP A,dp+X
			ot("  ldrb  r0,[spc_pc],#1\n");
			ot("  add   r0,r0,spc_x\n");
			MemHandler(0, 1, 1);
			ArithOpToA();
			break;

		case 0x15: // OP A,abs+X
			AbsoluteX(0);
			MemHandler(0, 0, 1);
			ArithOpToA();
			break;

		case 0x16: // OP A,abs+Y
			AbsoluteY(0);
			MemHandler(0, 0, 1);
			ArithOpToA();
			break;

		case 0x17: // OP A,(dp)+Y
			IndirectIndexedY(0);
			MemHandler(0, 0, 1);
			ArithOpToA();
			break;

		default:
			printf("Op %02X - arithmetic??\n", opcode);
	}
}


int main()
{
	int i;

	printf("\n  notaz's SPC700 Emulator v%s - Core Creator\n\n", VERSION);

	// Open the assembly file
	AsmFile=fopen("spc700a.s", "wt"); if (AsmFile==NULL) return 1;

	ot("@  notaz's SPC700 Emulator v%s - Assembler Output\n\n", VERSION);
	ot("@ (c) Copyright 2006 notaz, All rights reserved.\n\n");
	ot("@ this is a rewrite of spc700.cpp in ARM asm, inspired by other asm CPU cores like\n");
	ot("@ Cyclone and DrZ80. It is meant to be used in Snes9x emulator ports for ARM platforms.\n\n");
	ot("@ the code is released under Snes9x license. See spcgen.c or any other source file\n@ from Snes9x source tree.\n\n\n");

	PrintFramework();

	for(opcode; opcode < 0x100; opcode++) {
		printf("%02X", opcode);

		ot("\n\n");
		//tmp_prologue();
		ot("Apu%02X:\n", opcode);

		if((opcode & 0x1f) == 0x10) CBranch();  // BXX
		if((opcode & 0x0f) == 0x01) TCall();    // TCALL X
		if((opcode & 0x0f) == 0x02) SetClr1();  // SET1/CLR1 direct page bit X
		if((opcode & 0x0f) == 0x03) BssBbc();   // BBS/BBC direct page bit X
		if((opcode & 0x1f) == 0x0A) Membit();   // membit ops
		if((opcode & 0x0f) >= 0x04 && (opcode & 0x0f) <= 0x08 && (opcode & 0x1f) != 0x18 && (opcode >> 5) != 6)
									ArithmeticToA();


		switch(opcode) {
			case 0x00: // NOP
				break;

			case 0x3F: // CALL absolute
				Absolute(2);
				ot("  sub   r0,spc_pc,spc_ram\n");
				PushW();
				ot("  add   spc_pc,spc_ram,r2\n");
				break;

			case 0x4F: // PCALL $XX
				ot("  ldrb  r2,[spc_pc],#1\n");
				ot("  sub   r0,spc_pc,spc_ram\n");
				PushW();
				ot("  add   spc_pc,spc_ram,r2\n");
				ot("  add   spc_pc,spc_pc,#0xff00\n");
				break;

			case 0x09: // OR dp(dest),dp(src)
				ot("  ldrb  r0,[spc_pc],#1\n");
				MemHandler(0, 1, 0);
				ot("  orr   spc_x,spc_x,r0,lsl #24 @ save from harm\n");
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				ot("  orr   r0,r0,spc_x,lsr #24\n");
				ot("  and   spc_x,spc_x,#0xff\n");
				SetZN8("r0");
				ot("  ldrb  r1,[spc_pc],#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0x18: // OR dp,#00
				ot("  ldrb  r0,[spc_pc,#1]\n");
				MemHandler(0, 1, 0);
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  orr   r0,r0,r1\n");
				SetZN8("r0");
				ot("  ldrb  r1,[spc_pc],#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0x19: // OR (X),(Y)
				ot("  mov   r0,spc_x\n");
				MemHandler(0, 1, 0);
				ot("  orr   spc_x,spc_x,r0,lsl #24\n");
				ot("  mov   r0,spc_ya,lsr #8\n");
				MemHandler(0, 1, 0);
				ot("  orr   r0,r0,spc_x,lsr #24\n");
				ot("  and   spc_x,spc_x,#0xff\n");
				SetZN8("r0");
				ot("  mov   r1,spc_x\n");
				MemHandler(1, 1, 1);
				break;

			case 0x0B: // ASL dp
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				Asl();
				ot("  ldrb  r1,[spc_pc],#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0x0C: // ASL abs
				Absolute(0);
				ot("  stmfd sp!,{r0}\n");
				MemHandler(0, 0, 0);
				Asl();
				ot("  ldmfd sp!,{r1}\n");
				MemHandler(1, 0, 1);
				break;

			case 0x1B: // ASL dp+X
				ot("  ldrb  r0,[spc_pc],#1\n");
				ot("  add   r0,r0,spc_x\n");
				ot("  stmfd sp!,{r0}\n");
				MemHandler(0, 1, 0);
				Asl();
				ot("  ldmfd sp!,{r1}\n");
				MemHandler(1, 1, 1);
				break;

			case 0x1C: // ASL A
				ot("  tst   spc_ya,#0x80\n");
				ot("  orrne spc_p,spc_p,#flag_c\n");
				ot("  biceq spc_p,spc_p,#flag_c\n");
				ot("  and   r0,spc_ya,#0x7f\n");
				ot("  and   spc_ya,spc_ya,#0xff00\n");
				ot("  orr   spc_ya,spc_ya,r0,lsl #1\n");
				SetZN8("spc_ya");
				break;

			case 0x0D: // PUSH PSW
				ot("  mov   r0,spc_p,lsr #24\n");
				ot("  and   r1,r0,#0x80\n");
				ot("  tst   r0,r0\n");
				ot("  orreq r1,r1,#flag_z\n");
				ot("  and   spc_p,spc_p,#0x7d @ clear N & Z\n");
				ot("  orr   spc_p,spc_p,r1\n");
				Push("spc_p");
				ot("  orr   spc_p,spc_p,r0,lsl #24\n");
				break;

			case 0x2D: // PUSH A
				Push("spc_ya");
				break;

			case 0x4D: // PUSH X
				Push("spc_x");
				break;

			case 0x6D: // PUSH Y
				ot("  mov   r0,spc_ya,lsr #8\n");
				Push("r0");
				break;

			case 0x8E: // POP PSW
				Pop("spc_p");
				ot("  and   r0,spc_p,#(flag_z|flag_n)\n");
				ot("  eor   r0,r0,#flag_z\n");
				ot("  orr   spc_p,spc_p,r0,lsl #24\n");
				ot("  tst   spc_p,#flag_d\n");
				ot("  addne r0,spc_ram,#0x100\n");
				ot("  moveq r0,spc_ram\n");
				ot("  str   r0,[context,#iapu_directpage]\n");
				break;

			case 0xAE: // POP A
				Pop("r0");
				ot("  and   spc_ya,spc_ya,#0xff00\n");
				ot("  orr   spc_ya,spc_ya,r0\n");
				break;

			case 0xCE: // POP X
				Pop("spc_x");
				break;

			case 0xEE: // POP X
				Pop("r0");
				ot("  and   spc_ya,spc_ya,#0xff\n");
				ot("  orr   spc_ya,spc_ya,r0,lsl #8\n");
				break;

			case 0x0E: // TSET1 abs
				Absolute(0);
				ot("  orr   spc_x,spc_x,r0,lsl #16 @ save from memhandler\n");
				MemHandler(0, 0, 0);
				ot("  and   r2,r0,spc_ya\n");
				SetZN8("r2");
				ot("  orr   r0,r0,spc_ya\n");
				ot("  mov   r1,spc_x,lsr #16\n");
				ot("  and   spc_x,spc_x,#0xff\n");
				MemHandler(1, 0, 1);
				break;

			case 0x4E: // TCLR1 abs
				Absolute(0);
				ot("  orr   spc_x,spc_x,r0,lsl #16 @ save from memhandler\n");
				MemHandler(0, 0, 0);
				ot("  and   r2,r0,spc_ya\n");
				SetZN8("r2");
				ot("  bic   r0,r0,spc_ya\n");
				ot("  mov   r1,spc_x,lsr #16\n");
				ot("  and   spc_x,spc_x,#0xff\n");
				MemHandler(1, 0, 1);
				break;

			case 0x0F: // BRK
				ot("  sub   r0,spc_pc,spc_ram\n");
				PushW();
				ot("  mov   r0,spc_p,lsr #24\n");
				ot("  and   r1,r0,#0x80\n");
				ot("  tst   r0,r0\n");
				ot("  orrne r1,r1,#flag_z\n");
				ot("  and   spc_p,spc_p,#0x7d @ clear N & Z\n");
				ot("  orr   spc_p,spc_p,r1\n");
				Push("spc_p");
				ot("  orr   spc_p,spc_p,#flag_b\n");
				ot("  bic   spc_p,spc_p,#flag_i\n");
				ot("  ldr   r0,[context,#iapu_extraram]\n");
				ot("  ldrh  r0,[r0,#0x20]\n");
				ot("  add   spc_pc,spc_ram,r0\n");
				break;

			case 0xEF: // SLEEP
			case 0xFF: // STOP: this is to be compatible with yoyofr's code
				ot("  ldr   r0,=CPU\n");
				ot("  mov   r1,#0\n");
				ot("  strb  r1,[r0,#122]\n");
				break;

			case 0x2F: // BRA
				ot("  ldrsb r0,[spc_pc],#1\n");
				ot("  add   spc_pc,spc_pc,r0\n");
				break;

			case 0x80: // SETC
				ot("  orr   spc_p,spc_p,#flag_c\n");
				break;

			case 0xED: // NOTC
				ot("  eor   spc_p,spc_p,#flag_c\n");
				break;

			case 0x40: // SETP
				ot("  orr   spc_p,spc_p,#flag_d\n");
				ot("  add   r0,spc_ram,#0x100\n");
				ot("  str   r0,[context,#iapu_directpage]\n");
				break;

			case 0x1A: // DECW dp
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				ot("  stmfd sp!,{r0}\n");
				ot("  ldrb  r0,[spc_pc]\n");
				ot("  add   r0,r0,#1\n");
				MemHandler(0, 1, 0);
				ot("  ldmfd sp!,{r1}\n");
				ot("  orr   r1,r1,r0,lsl #8\n");
				ot("  sub   r0,r1,#1\n");
				SetZN16("r0");
				ot("  stmfd sp!,{r0}\n");
				ot("  ldrb  r1,[spc_pc]\n");
				MemHandler(1, 1, 0);
				ot("  ldmfd sp!,{r0}\n");
				ot("  mov   r0,r0,lsr #8\n");
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  add   r1,r1,#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0x5A: // CMPW YA,dp
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				ot("  stmfd sp!,{r0}\n");
				ot("  ldrb  r0,[spc_pc],#1\n");
				ot("  add   r0,r0,#1\n");
				MemHandler(0, 1, 1);
				ot("  ldmfd sp!,{r1}\n");
				ot("  orr   r1,r1,r0,lsl #8\n");
				ot("  subs  r0,spc_ya,r1\n");
				ot("  orrge spc_p,spc_p,#flag_c\n");
				ot("  biclt spc_p,spc_p,#flag_c\n");
				SetZN16("r0");
				break;

			case 0x3A: // INCW dp
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				ot("  stmfd sp!,{r0}\n");
				ot("  ldrb  r0,[spc_pc]\n");
				ot("  add   r0,r0,#1\n");
				MemHandler(0, 1, 0);
				ot("  ldmfd sp!,{r1}\n");
				ot("  orr   r1,r1,r0,lsl #8\n");
				ot("  add   r0,r1,#1\n");
				SetZN16("r0");
				ot("  stmfd sp!,{r0}\n");
				ot("  ldrb  r1,[spc_pc]\n");
				MemHandler(1, 1, 0);
				ot("  ldmfd sp!,{r0}\n");
				ot("  mov   r0,r0,lsr #8\n");
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  add   r1,r1,#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0x7A: // ADDW YA,dp
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				ot("  stmfd sp!,{r0}\n");
				ot("  ldrb  r0,[spc_pc],#1\n");
				ot("  add   r0,r0,#1\n");
				MemHandler(0, 1, 1);
				ot("  ldmfd sp!,{r1}\n");
				ot("  orr   r1,r1,r0,lsl #8\n");
				ot("  add   r0,spc_ya,r1\n");
				ot("  movs  r2,r0,lsr #16\n");
				ot("  orrne spc_p,spc_p,#flag_c\n");
				ot("  biceq spc_p,spc_p,#flag_c\n");
				ot("  bic   r2,r0,#0x00ff0000\n");
				ot("  eor   r3,r1,r2\n"); // Work16 ^ (uint16) Work32
				ot("  eor   r12,spc_ya,r1\n");
				ot("  mvn   r12,r12\n");  // ~(pIAPU->YA.W ^ Work16)
				ot("  and   r12,r12,r3\n");
				ot("  tst   r12,#0x8000\n");
				ot("  orrne spc_p,spc_p,#flag_o\n");
				ot("  biceq spc_p,spc_p,#flag_o\n");
				ot("  eor   r12,r3,spc_ya\n");
				ot("  tst   r12,#0x10\n");
				ot("  orrne spc_p,spc_p,#flag_h\n");
				ot("  biceq spc_p,spc_p,#flag_h\n");
				ot("  mov   spc_ya,r2\n");
				SetZN16("spc_ya");
				break;

			case 0x9A: // SUBW YA,dp
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				ot("  stmfd sp!,{r0}\n");
				ot("  ldrb  r0,[spc_pc],#1\n");
				ot("  add   r0,r0,#1\n");
				MemHandler(0, 1, 1);
				ot("  ldmfd sp!,{r1}\n");
				ot("  orr   r1,r1,r0,lsl #8\n");
				ot("  subs  r0,spc_ya,r1\n");
				ot("  orrge spc_p,spc_p,#flag_c\n");
				ot("  biclt spc_p,spc_p,#flag_c\n");
				ot("  mov   r2,r0,lsl #16\n");
				ot("  mov   r2,r2,lsr #16\n"); // r2=(uint16) Int32
				ot("  eor   r3,spc_ya,r2\n");  // r3=pIAPU->YA.W ^ (uint16) Int32
				ot("  eor   r12,spc_ya,r1\n");
				ot("  and   r12,r12,r3\n");
				ot("  tst   r12,#0x8000\n");
				ot("  orrne spc_p,spc_p,#flag_o\n");
				ot("  biceq spc_p,spc_p,#flag_o\n");
				ot("  eor   r12,r3,r1\n");
				ot("  tst   r12,#0x10\n");
				ot("  bicne spc_p,spc_p,#flag_h\n");
				ot("  orreq spc_p,spc_p,#flag_h\n");
				ot("  mov   spc_ya,r2\n");
				SetZN16("spc_ya");
				break;

			case 0xBA: // MOVW YA,dp
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				ot("  mov   spc_ya,r0\n");
				ot("  ldrb  r0,[spc_pc],#1\n");
				ot("  add   r0,r0,#1\n");
				MemHandler(0, 1, 1);
				ot("  orr   spc_ya,spc_ya,r0,lsl #8\n");
				SetZN16("spc_ya");
				break;

			case 0xDA: // MOVW dp,YA
				ot("  ldrb  r1,[spc_pc]\n");
				ot("  mov   r0,spc_ya\n");
				MemHandler(1, 1, 0);
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  add   r1,r1,#1\n");
				ot("  mov   r0,spc_ya,lsr #8\n");
				MemHandler(1, 1, 1);
				break;

			case 0x69: // CMP dp(dest), dp(src)
				ot("  ldrb  r0,[spc_pc],#1\n");
				MemHandler(0, 1, 0);
				ot("  orr   spc_x,spc_x,r0,lsl #24\n");
				ot("  ldrb  r0,[spc_pc],#1\n");
				MemHandler(0, 1, 1);
				ot("  mov   r1,spc_x,lsr #24\n");
				Cmp("r0", "r1", 0);
				ot("  and   spc_x,spc_x,#0xff\n");
				break;

			case 0x78: // CMP dp,#00
				ot("  ldrb  r0,[spc_pc,#1]\n");
				MemHandler(0, 1, 1);
				ot("  ldrb  r1,[spc_pc],#2\n");
				Cmp("r0", "r1", 0);
				break;

			case 0x79: // CMP (X),(Y)
				ot("  mov   r0,spc_x\n");
				MemHandler(0, 1, 0);
				ot("  orr   spc_x,spc_x,r0,lsl #24\n");
				ot("  mov   r0,spc_ya,lsr #8\n");
				MemHandler(0, 1, 1);
				ot("  mov   r1,spc_x,lsr #24\n");
				Cmp("r1", "r0", 0);
				ot("  and   spc_x,spc_x,#0xff\n");
				break;

			case 0x1E: // CMP X,abs
				Absolute(0);
				MemHandler(0, 0, 1);
				Cmp("spc_x", "r0", 0);
				break;

			case 0x3E: // CMP X,dp
				ot("  ldrb  r0,[spc_pc],#1\n");
				MemHandler(0, 1, 1);
				Cmp("spc_x", "r0", 0);
				break;

			case 0xC8: // CMP X,#00
				ot("  ldrb  r0,[spc_pc],#1\n");
				Cmp("spc_x", "r0", 0);
				break;

			case 0x5E: // CMP Y,abs
				Absolute(0);
				MemHandler(0, 0, 1);
				ot("  mov   r1,spc_ya,lsr #8\n");
				Cmp("r1", "r0", 0);
				break;

			case 0x7E: // CMP Y,dp
				ot("  ldrb  r0,[spc_pc],#1\n");
				MemHandler(0, 1, 1);
				ot("  mov   r1,spc_ya,lsr #8\n");
				Cmp("r1", "r0", 0);
				break;

			case 0xAD: // CMP Y,#00
				ot("  ldrb  r0,[spc_pc],#1\n");
				ot("  mov   r1,spc_ya,lsr #8\n");
				Cmp("r1", "r0", 0);
				break;

			case 0x1F: // JMP (abs+X)
				AbsoluteX(0);
				ot("  sub   sp,sp,#8\n");
				ot("  str   r0,[sp,#4]\n");
				MemHandler(0, 0, 0);
				ot("  str   r0,[sp]\n");
				ot("  ldr   r0,[sp,#4]\n");
				ot("  add   r0,r0,#1\n");
				MemHandler(0, 0, 1);
				ot("  ldr   r1,[sp],#8\n");
				ot("  orr   r0,r1,r0,lsl #8\n");
				ot("  add   spc_pc,spc_ram,r0\n");
				break;

			case 0x5F: // JMP abs
				Absolute(0);
				ot("  add   spc_pc,spc_ram,r0\n");
				break;

			case 0x20: // CLRP
				ot("  bic   spc_p,spc_p,#flag_d\n");
				ot("  str   spc_ram,[context,#iapu_directpage]\n");
				break;

			case 0x60: // CLRC
				ot("  bic   spc_p,spc_p,#flag_c\n");
				break;

			case 0xE0: // CLRV
				ot("  bic   spc_p,spc_p,#(flag_o|flag_h)\n");
				break;

			case 0x29: // AND dp(dest), dp(src)
				ot("  ldrb  r0,[spc_pc],#1\n");
				MemHandler(0, 1, 0);
				ot("  stmfd sp!,{r0}\n");
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				ot("  ldmfd sp!,{r1}\n");
				ot("  and   r0,r0,r1\n");
				SetZN8("r0");
				ot("  ldrb  r1,[spc_pc],#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0x38: // AND dp,#00
				ot("  ldrb  r0,[spc_pc,#1]\n");
				MemHandler(0, 1, 0);
				ot("  ldrb  r1,[spc_pc],#2\n");
				ot("  and   r0,r0,r1\n");
				SetZN8("r0");
				ot("  ldrb  r1,[spc_pc,#-1]\n");
				MemHandler(1, 1, 1);
				break;

			case 0x39: // AND (X),(Y)
				ot("  mov   r0,spc_x\n");
				MemHandler(0, 1, 0);
				ot("  stmfd sp!,{r0}\n");
				ot("  mov   r0,spc_ya,lsr #8\n");
				MemHandler(0, 1, 0);
				ot("  ldmfd sp!,{r1}\n");
				ot("  and   r0,r0,r1\n");
				SetZN8("r0");
				ot("  mov   r1,spc_x\n");
				MemHandler(1, 1, 1);
				break;

			case 0x2B: // ROL dp
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				Rol();
				ot("  ldrb  r1,[spc_pc],#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0x2C: // ROL abs
				Absolute(0);
				ot("  stmfd sp!,{r0}\n");
				MemHandler(0, 0, 0);
				Rol();
				ot("  ldmfd sp!,{r1}\n");
				MemHandler(1, 0, 1);
				break;

			case 0x3B: // ROL dp+X
				ot("  ldrb  r0,[spc_pc]\n");
				ot("  add   r0,r0,spc_x\n");
				MemHandler(0, 1, 0);
				Rol();
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  add   r1,r1,spc_x\n");
				MemHandler(1, 1, 1);
				break;

			case 0x3C: // ROL A
				ot("  and   r0,spc_ya,#0xff\n");
				Rol();
				ot("  and   r0,r0,#0xff\n");
				ot("  mov   spc_ya,spc_ya,lsr #8\n");
				ot("  orr   spc_ya,r0,spc_ya,lsl #8\n");
				break;

			case 0x2E: // CBNE dp,rel
				ot("  ldrb  r0,[spc_pc],#1\n");
				MemHandler(0, 1, 1);
				ot("  and   r1,spc_ya,#0xff\n");
				ot("  cmp   r0,r1\n");
				ot("  addeq spc_pc,spc_pc,#1\n");
				ot("  ldrnesb r0,[spc_pc],#1\n");
				ot("  addne spc_pc,spc_pc,r0\n");
				ot("  subne cycles,cycles,#%i\n", ONE_APU_CYCLE*2);
				break;

			case 0xDE: // CBNE dp+X,rel
				ot("  ldrb  r0,[spc_pc],#1\n");
				ot("  add   r0,r0,spc_x\n");
				MemHandler(0, 1, 1);
				ot("  and   r1,spc_ya,#0xff\n");
				ot("  cmp   r0,r1\n");
				ot("  addeq spc_pc,spc_pc,#1\n");
				ot("  ldrnesb r0,[spc_pc],#1\n");
				ot("  addne spc_pc,spc_pc,r0\n");
				ot("  subne cycles,cycles,#%i\n", ONE_APU_CYCLE*2);
				break;

			case 0x3D: // INC X
				ot("  add   spc_x,spc_x,#1\n");
				ot("  and   spc_x,spc_x,#0xff\n");
				SetZN8("spc_x");
				break;

			case 0xFC: // INC Y
				ot("  mov   r0,spc_ya,lsr #8\n");
				ot("  add   r0,r0,#1\n");
				ot("  and   r0,r0,#0xff\n");
				SetZN8("r0");
				ot("  and   spc_ya,spc_ya,#0xff\n");
				ot("  orr   spc_ya,spc_ya,r0,lsl #8\n");
				break;

			case 0x1D: // DEC X
				ot("  sub   spc_x,spc_x,#1\n");
				ot("  and   spc_x,spc_x,#0xff\n");
				SetZN8("spc_x");
				break;

			case 0xDC: // DEC Y
				ot("  mov   r0,spc_ya,lsr #8\n");
				ot("  sub   r0,r0,#1\n");
				ot("  and   r0,r0,#0xff\n");
				SetZN8("r0");
				ot("  and   spc_ya,spc_ya,#0xff\n");
				ot("  orr   spc_ya,spc_ya,r0,lsl #8\n");
				break;

			case 0xAB: // INC dp
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				ot("  add   r0,r0,#1\n");
				SetZN8("r0");
				ot("  ldrb  r1,[spc_pc],#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0xAC: // INC abs
				Absolute(0);
				ot("  stmfd sp!,{r0}\n");
				MemHandler(0, 0, 0);
				ot("  add   r0,r0,#1\n");
				SetZN8("r0");
				ot("  ldmfd sp!,{r1}\n");
				MemHandler(1, 0, 1);
				break;

			case 0xBB: // INC dp+X
				ot("  ldrb  r0,[spc_pc]\n");
				ot("  add   r0,r0,spc_x\n");
				MemHandler(0, 1, 0);
				ot("  add   r0,r0,#1\n");
				SetZN8("r0");
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  add   r1,r1,spc_x\n");
				MemHandler(1, 1, 1);
				break;

			case 0xBC: // INC A
				ot("  and   r0,spc_ya,#0xff\n");
				ot("  add   r0,r0,#1\n");
				SetZN8("r0");
				ot("  and   r0,r0,#0xff\n");
				ot("  mov   spc_ya,spc_ya,lsr #8\n");
				ot("  orr   spc_ya,r0,spc_ya,lsl #8\n");
				break;

			case 0x8B: // DEC dp
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				ot("  sub   r0,r0,#1\n");
				SetZN8("r0");
				ot("  ldrb  r1,[spc_pc],#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0x8C: // DEC abs
				Absolute(0);
				ot("  stmfd sp!,{r0}\n");
				MemHandler(0, 0, 0);
				ot("  sub   r0,r0,#1\n");
				SetZN8("r0");
				ot("  ldmfd sp!,{r1}\n");
				MemHandler(1, 0, 1);
				break;

			case 0x9B: // DEC dp+X
				ot("  ldrb  r0,[spc_pc]\n");
				ot("  add   r0,r0,spc_x\n");
				MemHandler(0, 1, 0);
				ot("  sub   r0,r0,#1\n");
				SetZN8("r0");
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  add   r1,r1,spc_x\n");
				MemHandler(1, 1, 1);
				break;

			case 0x9C: // DEC A
				ot("  and   r0,spc_ya,#0xff\n");
				ot("  sub   r0,r0,#1\n");
				SetZN8("r0");
				ot("  and   r0,r0,#0xff\n");
				ot("  mov   spc_ya,spc_ya,lsr #8\n");
				ot("  orr   spc_ya,r0,spc_ya,lsl #8\n");
				break;

			case 0x49: // EOR dp(dest), dp(src)
				ot("  ldrb  r0,[spc_pc],#1\n");
				MemHandler(0, 1, 0);
				ot("  stmfd sp!,{r0}\n");
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				ot("  ldmfd sp!,{r1}\n");
				ot("  eor   r0,r0,r1\n");
				SetZN8("r0");
				ot("  ldrb  r1,[spc_pc],#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0x58: // EOR dp,#00
				ot("  ldrb  r0,[spc_pc,#1]\n");
				MemHandler(0, 1, 0);
				ot("  ldrb  r1,[spc_pc],#2\n");
				ot("  eor   r0,r0,r1\n");
				SetZN8("r0");
				ot("  ldrb  r1,[spc_pc,#-1]\n");
				MemHandler(1, 1, 1);
				break;

			case 0x59: // EOR (X),(Y)
				ot("  mov   r0,spc_x\n");
				MemHandler(0, 1, 0);
				ot("  stmfd sp!,{r0}\n");
				ot("  mov   r0,spc_ya,lsr #8\n");
				MemHandler(0, 1, 0);
				ot("  ldmfd sp!,{r1}\n");
				ot("  eor   r0,r0,r1\n");
				SetZN8("r0");
				ot("  mov   r1,spc_x\n");
				MemHandler(1, 1, 1);
				break;

			case 0x4B: // LSR dp
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				Lsr();
				ot("  ldrb  r1,[spc_pc],#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0x4C: // LSR abs
				Absolute(0);
				ot("  stmfd sp!,{r0}\n");
				MemHandler(0, 0, 0);
				Lsr();
				ot("  ldmfd sp!,{r1}\n");
				MemHandler(1, 0, 1);
				break;

			case 0x5B: // LSR dp+X
				ot("  ldrb  r0,[spc_pc]\n");
				ot("  add   r0,r0,spc_x\n");
				MemHandler(0, 1, 0);
				Lsr();
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  add   r1,r1,spc_x\n");
				MemHandler(1, 1, 1);
				break;

			case 0x5C: // LSR A
				ot("  and   r0,spc_ya,#0xff\n");
				Lsr();
				ot("  mov   spc_ya,spc_ya,lsr #8\n");
				ot("  orr   spc_ya,r0,spc_ya,lsl #8\n");
				break;

			case 0x7D: // MOV A,X
				ot("  and   spc_ya,spc_ya,#0xff00\n");
				ot("  orr   spc_ya,spc_ya,spc_x\n");
				SetZN8("spc_ya");
				break;

			case 0xDD: // MOV A,Y
				ot("  and   spc_ya,spc_ya,#0xff00\n");
				ot("  orr   spc_ya,spc_ya,spc_ya,lsr #8\n");
				SetZN8("spc_ya");
				break;

			case 0x5D: // MOV X,A
				ot("  and   spc_x,spc_ya,#0xff\n");
				SetZN8("spc_x");
				break;

			case 0xFD: // MOV Y,A
				ot("  and   spc_ya,spc_ya,#0xff\n");
				ot("  orr   spc_ya,spc_ya,spc_ya,lsl #8\n");
				SetZN8("spc_ya");
				break;

			case 0x9D: // MOV X,SP
				ot("  mov   spc_x,spc_s\n");
				SetZN8("spc_x");
				break;

			case 0xBD: // SP,X
				ot("  mov   spc_s,spc_x\n");
				break;

			case 0x6B: // ROR dp
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				Ror();
				ot("  ldrb  r1,[spc_pc],#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0x6C: // ROR abs
				Absolute(0);
				ot("  stmfd sp!,{r0}\n");
				MemHandler(0, 0, 0);
				Ror();
				ot("  ldmfd sp!,{r1}\n");
				MemHandler(1, 0, 1);
				break;

			case 0x7B: // ROR dp+X
				ot("  ldrb  r0,[spc_pc]\n");
				ot("  add   r0,r0,spc_x\n");
				MemHandler(0, 1, 0);
				Ror();
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  add   r1,r1,spc_x\n");
				MemHandler(1, 1, 1);
				break;

			case 0x7C: // ROR A
				ot("  and   r0,spc_ya,#0xff\n");
				Ror();
				ot("  mov   spc_ya,spc_ya,lsr #8\n");
				ot("  orr   spc_ya,r0,spc_ya,lsl #8\n");
				break;

			case 0x6E: // DBNZ dp,rel
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  sub   r0,r0,#1\n");
				ot("  tst   r0,r0\n");
				ot("  addeq spc_pc,spc_pc,#1\n");
				ot("  ldrnesb r2,[spc_pc],#1\n");
				ot("  addne spc_pc,spc_pc,r2\n");
				ot("  subne cycles,cycles,#%i\n", ONE_APU_CYCLE*2);
				MemHandler(1, 1, 1);
				break;

			case 0xFE: // DBNZ Y,rel
				ot("  sub   spc_ya,spc_ya,#0x100\n");
				ot("  mov   spc_ya,spc_ya,lsl #16\n");
				ot("  mov   spc_ya,spc_ya,lsr #16\n");
				ot("  movs  r0,spc_ya,lsr #8\n");
				ot("  addeq spc_pc,spc_pc,#1\n");
				ot("  ldrnesb r0,[spc_pc],#1\n");
				ot("  addne spc_pc,spc_pc,r0\n");
				ot("  subne cycles,cycles,#%i\n", ONE_APU_CYCLE*2);
				break;

			case 0x6F: // RET
				PopW();
				ot("  add   spc_pc,spc_ram,r0\n");
				break;

			case 0x7F: // RETI
				Pop("spc_p");
				ot("  and   r0,spc_p,#(flag_z|flag_n)\n");
				ot("  eor   r0,r0,#flag_z\n");
				ot("  orr   spc_p,spc_p,r0,lsl #24\n");
				ot("  tst   spc_p,#flag_d\n");
				ot("  addne r0,spc_ram,#0x100\n");
				ot("  moveq r0,spc_ram\n");
				ot("  str   r0,[context,#iapu_directpage]\n");
				PopW();
				ot("  add   spc_pc,spc_ram,r0\n");
				break;

			case 0x89: // ADC dp(dest), dp(src)
				ot("  ldrb  r0,[spc_pc],#1\n");
				MemHandler(0, 1, 0);
				ot("  stmfd sp!,{r0}\n");
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				ot("  ldmfd sp!,{r1}\n");
				Adc("r0", "r1");
				SetZN8("r0");
				ot("  ldrb  r1,[spc_pc],#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0x98: // ADC dp,#00
				ot("  ldrb  r0,[spc_pc,#1]\n");
				MemHandler(0, 1, 0);
				ot("  ldrb  r1,[spc_pc],#2\n");
				Adc("r0", "r1");
				SetZN8("r0");
				ot("  ldrb  r1,[spc_pc,#-1]\n");
				MemHandler(1, 1, 1);
				break;

			case 0x99: // ADC (X),(Y)
				ot("  mov   r0,spc_x\n");
				MemHandler(0, 1, 0);
				ot("  stmfd sp!,{r0}\n");
				ot("  mov   r0,spc_ya,lsr #8\n");
				MemHandler(0, 1, 0);
				ot("  ldmfd sp!,{r1}\n");
				Adc("r0", "r1");
				SetZN8("r0");
				ot("  mov   r1,spc_x\n");
				MemHandler(1, 1, 1);
				break;

			case 0x8D: // MOV Y,#00
				ot("  ldrb  r0,[spc_pc],#1\n");
				ot("  and   spc_ya,spc_ya,#0xff\n");
				ot("  orr   spc_ya,spc_ya,r0,lsl #8\n");
				SetZN8("r0");
				break;

			case 0x8F: // MOV dp,#00
				ot("  ldrb  r0,[spc_pc],#1\n");
				ot("  ldrb  r1,[spc_pc],#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0x9E: // DIV YA,X
				ot("  tst   spc_x,spc_x @ div by 0?\n");
				ot("  orreq spc_ya,spc_ya,#0xff00\n");
				ot("  orreq spc_ya,spc_ya,#0x00ff\n");
				ot("  orreq spc_p,spc_p,#flag_o\n");
				ot("  beq   Apu9E_end\n");
				ot("  bic   spc_p,spc_p,#flag_o\n");

				// division algo from Cyclone (result in r3, remainder instead of divident)
				ot("@ Divide spc_ya by spc_x\n");
				ot("  mov r3,#0\n");
				ot("  mov r1,spc_x\n");
				ot("\n");

				//
				/*ot("@ Shift up divisor till it's just less than numerator\n");
				ot("divshift:\n");
				ot("  cmp r1,spc_ya,lsr #1\n");
				ot("  movls r1,r1,lsl #1\n");
				ot("  bcc divshift\n");
				ot("\n");*/

				//optimised version of code provided by William Blair
				ot("@ Shift up divisor till it's just less than numerator\n");
			    ot("cmp   spc_ya,r1,lsl #8\n");
			    ot("movge r1,r1,lsl #8\n");
			    ot("cmp   spc_ya,r1,lsl #4\n");
			    ot("movge r1,r1,lsl #4\n");
			    ot("cmp   spc_ya,r1,lsl #2\n");
			    ot("movge r1,r1,lsl #2\n");
			    ot("cmp   spc_ya,r1,lsl #1\n");
			    ot("movge r1,r1,lsl #1\n");

				ot("divloop:\n");
				ot("  cmp spc_ya,r1\n");
				ot("  adc r3,r3,r3 ;@ Double r3 and add 1 if carry set\n");
				ot("  subcs spc_ya,spc_ya,r1\n");
				ot("  teq r1,spc_x\n");
				ot("  movne r1,r1,lsr #1\n");
				ot("  bne divloop\n");
				ot("\n");

				ot("  and   spc_ya,spc_ya,#0xff\n");
				ot("  and   r3,r3,#0xff\n");
				ot("  orr   spc_ya,r3,spc_ya,lsl #8\n");

				ot("Apu9E_end:\n");
				SetZN8("spc_ya");
				break;

			case 0x9F: // XCN A
				ot("  and   r0,spc_ya,#0xff\n");
				ot("  mov   r1,r0,lsl #28\n");
				ot("  orr   r0,r1,r0,lsl #20\n");
				ot("  and   spc_ya,spc_ya,#0xff00\n");
				ot("  orr   spc_ya,spc_ya,r0,lsr #24\n");
				SetZN8("spc_ya");
				break;

			case 0xA9: // SBC dp(dest), dp(src)
				ot("  ldrb  r0,[spc_pc],#1\n");
				MemHandler(0, 1, 0);
				ot("  stmfd sp!,{r0}\n");
				ot("  ldrb  r0,[spc_pc]\n");
				MemHandler(0, 1, 0);
				ot("  ldmfd sp!,{r1}\n");
				Sbc("r0", "r1");
				SetZN8("r0");
				ot("  ldrb  r1,[spc_pc],#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0xB8: // SBC dp,#00
				ot("  ldrb  r0,[spc_pc,#1]\n");
				MemHandler(0, 1, 0);
				ot("  ldrb  r1,[spc_pc],#2\n");
				Sbc("r0", "r1");
				SetZN8("r0");
				ot("  ldrb  r1,[spc_pc,#-1]\n");
				MemHandler(1, 1, 1);
				break;

			case 0xB9: // SBC (X),(Y)
				ot("  mov   r0,spc_x\n");
				MemHandler(0, 1, 0);
				ot("  stmfd sp!,{r0}\n");
				ot("  mov   r0,spc_ya,lsr #8\n");
				MemHandler(0, 1, 0);
				ot("  ldmfd sp!,{r1}\n");
				Sbc("r0", "r1");
				SetZN8("r0");
				ot("  mov   r1,spc_x\n");
				MemHandler(1, 1, 1);
				break;

			case 0xAF: // MOV (X)+, A
				ot("  mov   r0,spc_ya\n");
				ot("  mov   r1,spc_x\n");
				MemHandler(1, 1, 1);
				ot("  add   spc_x,spc_x,#1\n");
				ot("  and   spc_x,spc_x,#0xff\n");
				break;

			case 0xBE: // DAS
				ot("  and   r0,spc_ya,#0xff\n");
				ot("  and   r1,spc_ya,#0x0f\n");
				ot("  cmp   r1,#9\n");
				ot("  subhi r0,r0,#6\n");
				ot("  tstls spc_p,#flag_h\n");
				ot("  subeq r0,r0,#6\n");
				ot("  cmp   r0,#0x9f\n");
				ot("  bhi   ApuBE_tens\n");
				ot("  tst   spc_p,#flag_c\n");
				ot("  beq   ApuBE_tens\n");
				ot("  orr   spc_p,spc_p,#flag_c\n");
				ot("  b     ApuBE_end\n");
				ot("ApuBE_tens:\n");
				ot("  sub   r0,r0,#0x60\n");
				ot("  bic   spc_p,spc_p,#flag_c\n");
				ot("ApuBE_end:\n");
				ot("  and   spc_ya,spc_ya,#0xff00\n");
				ot("  orr   spc_ya,spc_ya,r0\n");
				SetZN8("spc_ya");
				break;

			case 0xBF: // MOV A,(X)+
				ot("  mov   r0,spc_x\n");
				MemHandler(0, 1, 1);
				ot("  and   spc_ya,spc_ya,#0xff00\n");
				ot("  orr   spc_ya,spc_ya,r0\n");
				ot("  add   spc_x,spc_x,#1\n");
				ot("  and   spc_x,spc_x,#0xff\n");
				SetZN8("spc_ya");
				break;

			case 0xC0: // DI
				ot("  bic   spc_p,spc_p,#flag_i\n");
				break;

			case 0xA0: // EI
				ot("  orr   spc_p,spc_p,#flag_i\n");
				break;

			case 0xC4: // MOV dp,A
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  mov   r0,spc_ya\n");
				MemHandler(1, 1, 1);
				break;

			case 0xC5: // MOV abs,A
				Absolute(1);
				ot("  mov   r0,spc_ya\n");
				MemHandler(1, 0, 1);
				break;

			case 0xC6: // MOV (X),A
				ot("  mov   r0,spc_ya\n");
				ot("  mov   r1,spc_x\n");
				MemHandler(1, 1, 1);
				break;

			case 0xC7: // MOV (dp+X),A
				IndexedXIndirect(1);
				ot("  mov   r0,spc_ya\n");
				MemHandler(1, 0, 1);
				break;

			case 0xC9: // MOV abs,X
				Absolute(1);
				ot("  mov   r0,spc_x\n");
				MemHandler(1, 0, 1);
				break;

			case 0xCB: // MOV dp,Y
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  mov   r0,spc_ya,lsr #8\n");
				MemHandler(1, 1, 1);
				break;

			case 0xCC: // MOV abs,Y
				Absolute(1);
				ot("  mov   r0,spc_ya,lsr #8\n");
				MemHandler(1, 0, 1);
				break;

			case 0xCD: // MOV X,#00
				ot("  ldrb  spc_x,[spc_pc],#1\n");
				SetZN8("spc_x");
				break;

			case 0xCF: // MUL YA
				ot("  mov   r0,spc_ya,lsr #8\n");
				ot("  and   spc_ya,spc_ya,#0xff\n");
				ot("  mul   spc_ya,r0,spc_ya\n");
				SetZN16("spc_ya");
				break;

			case 0xD4: // MOV dp+X, A
				ot("  mov   r0,spc_ya\n");
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  add   r1,r1,spc_x\n");
				MemHandler(1, 1, 1);
				break;

			case 0xD5: // MOV abs+X,A
				AbsoluteX(1);
				ot("  mov   r0,spc_ya\n");
				MemHandler(1, 0, 1);
				break;

			case 0xD6: // MOV abs+Y,A
				AbsoluteY(1);
				ot("  mov   r0,spc_ya\n");
				MemHandler(1, 0, 1);
				break;

			case 0xD7: // MOV (dp)+Y,A
				IndirectIndexedY(1);
				ot("  mov   r0,spc_ya\n");
				MemHandler(1, 0, 1);
				break;

			case 0xD8: // MOV dp,X
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  mov   r0,spc_x\n");
				MemHandler(1, 1, 1);
				break;

			case 0xD9: // MOV dp+Y,X
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  add   r1,r1,spc_ya,lsr #8\n");
				ot("  mov   r0,spc_x\n");
				MemHandler(1, 1, 1);
				break;

			case 0xDB: // MOV dp+X,Y
				ot("  ldrb  r1,[spc_pc],#1\n");
				ot("  add   r1,r1,spc_x\n");
				ot("  mov   r0,spc_ya,lsr #8\n");
				MemHandler(1, 1, 1);
				break;

			case 0xDF: // DAA
				ot("  and   r0,spc_ya,#0xff\n");
				ot("  and   r1,spc_ya,#0x0f\n");
				ot("  cmp   r1,#9\n");
				ot("  addhi r0,r0,#6\n");
				ot("  bls   ApuDF_testHc\n");
				ot("  cmphi r0,#0xf0\n");
				ot("  orrhi spc_p,spc_p,#flag_c\n");
				ot("  b     ApuDF_test2\n");
				ot("ApuDF_testHc:\n");
				ot("  tst   spc_p,#flag_h\n");
				ot("  addne r0,r0,#6\n");
				ot("  beq   ApuDF_test2\n");
				ot("  cmp   r0,#0xf0\n");
				ot("  orrhi spc_p,spc_p,#flag_c\n");
				ot("ApuDF_test2:\n");
				ot("  tst   spc_p,#flag_c\n");
				ot("  addne r0,r0,#0x60\n");
				ot("  bne   ApuDF_end\n");
				ot("  cmp   r0,#0x9f\n");
				ot("  addhi r0,r0,#0x60\n");
				ot("  orrhi spc_p,spc_p,#flag_c\n");
				ot("  bicls spc_p,spc_p,#flag_c\n");
				ot("ApuDF_end:\n");
				ot("  and   spc_ya,spc_ya,#0xff00\n");
				ot("  orr   spc_ya,spc_ya,r0\n");
				SetZN8("spc_ya");
				break;

			case 0xE9: // MOV X, abs
				Absolute(0);
				MemHandler(0, 0, 1);
				ot("  mov   spc_x,r0\n");
				SetZN8("spc_x");
				break;

			case 0xEB: // MOV Y,dp
				ot("  ldrb  r0,[spc_pc],#1\n");
				MemHandler(0, 1, 1);
				ot("  and   spc_ya,spc_ya,#0xff\n");
				ot("  orr   spc_ya,spc_ya,r0,lsl #8\n");
				SetZN8("r0");
				break;

			case 0xEC: // MOV Y,abs
				Absolute(0);
				MemHandler(0, 0, 1);
				ot("  and   spc_ya,spc_ya,#0xff\n");
				ot("  orr   spc_ya,spc_ya,r0,lsl #8\n");
				SetZN8("r0");
				break;

			case 0xF8: // MOV X,dp
				ot("  ldrb  r0,[spc_pc],#1\n");
				MemHandler(0, 1, 1);
				ot("  mov   spc_x,r0\n");
				SetZN8("spc_x");
				break;

			case 0xF9: // MOV X,dp+Y
				ot("  ldrb  r0,[spc_pc],#1\n");
				ot("  add   r0,r0,spc_ya,lsr #8\n");
				MemHandler(0, 1, 1);
				ot("  mov   spc_x,r0\n");
				SetZN8("spc_x");
				break;

			case 0xFA: // MOV dp(dest),dp(src)
				ot("  ldrb  r0,[spc_pc],#1\n");
				MemHandler(0, 1, 0);
				ot("  ldrb  r1,[spc_pc],#1\n");
				MemHandler(1, 1, 1);
				break;

			case 0xFB: // MOV Y,dp+X
				ot("  ldrb  r0,[spc_pc],#1\n");
				ot("  add   r0,r0,spc_x\n");
				MemHandler(0, 1, 1);
				ot("  and   spc_ya,spc_ya,#0xff\n");
				ot("  orr   spc_ya,spc_ya,r0,lsl #8\n");
				SetZN8("r0");
				break;
		}

		//tmp_epilogue();
		ot("  subs   cycles,cycles,#%i\n", S9xAPUCycles[opcode] * ONE_APU_CYCLE);
		ot("  ldrgeb opcode,[spc_pc],#1\n");
		ot("  ldrge  pc,[opcodes,opcode,lsl #2]\n");
		ot("  b      spc700End\n");

		printf("\b\b");
	}


	ot("\n\n");
	ot("@ -------------------------- Jump Table --------------------------\n");
	ot("Spc700JumpTab:\n");

	for (i=0; i < 0x100; i++)
	{
		if ((i&7)==0) ot("  .long ");

		ot("Apu%02X", i);

		if ((i&7)==7) ot(" @ %02x\n",i-7);
		else if (i+1 < 0x100) ot(", ");
	}

	fclose(AsmFile); AsmFile=NULL;

	printf("Assembling...\n");
	// Assemble the file
	//system("as -marmv4t -mthumb-interwork -o spc700a.o spc700a.S");
	printf("Done!\n\n");

	return 0;
}
