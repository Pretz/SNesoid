/*******************************************************************************
  Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
 
  (c) Copyright 1996 - 2003 Gary Henderson (gary.henderson@ntlworld.com) and
                            Jerremy Koot (jkoot@snes9x.com)

  (c) Copyright 2002 - 2003 Matthew Kendora and
                            Brad Jorsch (anomie@users.sourceforge.net)
 

                      
  C4 x86 assembler and some C emulation code
  (c) Copyright 2000 - 2003 zsKnight (zsknight@zsnes.com),
                            _Demo_ (_demo_@zsnes.com), and
                            Nach (n-a-c-h@users.sourceforge.net)
                                          
  C4 C++ code
  (c) Copyright 2003 Brad Jorsch

  DSP-1 emulator code
  (c) Copyright 1998 - 2003 Ivar (ivar@snes9x.com), _Demo_, Gary Henderson,
                            John Weidman (jweidman@slip.net),
                            neviksti (neviksti@hotmail.com), and
                            Kris Bleakley (stinkfish@bigpond.com)
 
  DSP-2 emulator code
  (c) Copyright 2003 Kris Bleakley, John Weidman, neviksti, Matthew Kendora, and
                     Lord Nightmare (lord_nightmare@users.sourceforge.net

  OBC1 emulator code
  (c) Copyright 2001 - 2003 zsKnight, pagefault (pagefault@zsnes.com)
  Ported from x86 assembler to C by sanmaiwashi

  SPC7110 and RTC C++ emulator code
  (c) Copyright 2002 Matthew Kendora with research by
                     zsKnight, John Weidman, and Dark Force

  S-RTC C emulator code
  (c) Copyright 2001 John Weidman
  
  Super FX x86 assembler emulator code 
  (c) Copyright 1998 - 2003 zsKnight, _Demo_, and pagefault 

  Super FX C emulator code 
  (c) Copyright 1997 - 1999 Ivar and Gary Henderson.

  S-DD1 decompression code
  (c) Copyright 2003 Jose Luis Bravo

 
  Specific ports contains the works of other authors. See headers in
  individual files.
 
  Snes9x homepage: http://www.snes9x.com
 
  Permission to use, copy, modify and distribute Snes9x in both binary and
  source form, for non-commercial purposes, is hereby granted without fee,
  providing that this license information and copyright notice appear with
  all copies and any derived work.
 
  This software is provided 'as-is', without any express or implied
  warranty. In no event shall the authors be held liable for any damages
  arising from the use of this software.
 
  Snes9x is freeware for PERSONAL USE only. Commercial users should
  seek permission of the copyright holders first. Commercial use includes
  charging money for Snes9x or software derived from Snes9x.
 
  The copyright holders request that bug fixes and improvements to the code
  should be forwarded to them so everyone can benefit from the modifications
  in future versions.
 
  Super NES and Super Nintendo Entertainment System are trademarks of
  Nintendo Co., Limited and its subsidiary companies.
*******************************************************************************/
.data
.BankSave:
	.long 0
.text

.globl S9xGetByte

S9xGetByte:
	movl %edx, %eax
	shrl $MEMMAP_SHIFT, %eax
	and $MEMMAP_MASK, %eax

	movb InDMA, %cl
	testb %cl, %cl
	jne .GB_NOADD
	movb MemorySpeed(%eax), %cl
	andl $0xff, %ecx
	addl %ecx, CYCLES
	SAVE_CYCLES /*save now, so we don't need to necessarily save later*/
.GB_NOADD:
#ifdef CPU_SHUTDOWN
	movb BlockIsRAM(%eax), %ch
#endif	
	movl Map(, %eax, 4), %eax
	cmpl $18, %eax /* MAP_LAST */
	jb .GBSpecial
	andl $0xffff, %edx
#ifdef CPU_SHUTDOWN
	testb %ch, %ch
	jz .GBNotRAM
	pushl %eax
	movl PCAtOpcodeStart, %eax
	movl %eax, WaitAddress
	popl %eax
.GBNotRAM:
#endif
	movb (%eax, %edx), %al
	ret

	.align 4
.GBSpecial:
	jmp *.GBJmpTable(, %eax, 4)
.data
	.align 4
.GBJmpTable:
	.long .GBPPU    /* MAP_PPU */
	.long .GBCPU    /* MAP_CPU */
	.long .GBDSP    /* MAP_DSP */
	.long .GBLSRAM  /* MAP_LOROM_SRAM */
	.long .GBHSRAM  /* MAP_HIROM_SRAM */
	.long .GBNONE   /* MAP_NONE */
	.long .GBDEBUG  /* MAP_DEBUG */
	.long .GBC4     /* MAP_C4 */
	.long .GBBWRAM  /* MAP_BWRAM */
	.long .GBNONE   /* MAP_BWRAM_BITMAP */
	.long .GBNONE   /* MAP_BWRAM_BITMAP2 */
	.long .GBNONE   /* MAP_SA1RAM */
	.long .GB7ROM   /* MAP_SPC7110_ROM */
	.long .GB7RAM   /* MAP_SPC7110_DRAM */
	.long .GB7SRM   /* MAP_RONLY_SRAM */
	.long .GBOBC1   /* MAP_OBC_RAM */
	.long .GBSDSP   /* MAP_SETA_DSP */
	.long .GBSRISC  /* MAP_SETA_RISC */

.text
.GBPPU: /* MAP_PPU */
	pushl %edx
	ccall S9xGetPPU
	popl %edx
	LOAD_CYCLES
	ret

.GBCPU: /* MAP_CPU */
	pushl %edx
	ccall S9xGetCPU
	popl %edx
	LOAD_CYCLES
	ret

.GBDSP: /* MAP_DSP */
	pushl %edx
	ccall S9xGetDSP
	LOAD_CYCLES
	popl %edx
	ret

.GBLSRAM: /* MAP_LOROM_SRAM */
	movl %edx, %ecx
	andl $0x7fff, %edx
	andl $0x00ff0000, %ecx
	sarl $1, %ecx
	orl  %ecx, %edx
	movl SRAM, %ecx
	andl SRAMMask, %edx
	movb (%ecx, %edx), %al
	ret

.GB7SRM: /* MAP_RONLY_SRAM */
.GBHSRAM: /* MAP_HIROM_SRAM */
	movl %edx, %ecx
	andl $0xf0000, %ecx
	andl $0x7fff, %edx
	sarl $3, %ecx
	addl $-24576, %edx
	addl %ecx, %edx
	movl SRAM, %eax
	andl SRAMMask, %edx
	movb (%eax, %edx), %al
	ret

.GBNONE: /* MAP_NONE */
	xorl %eax, %eax
	movb OpenBus, %al
	ret

.GBDEBUG: /* MAP_DEBUG */
	xorl %eax, %eax
	movb OpenBus, %al
	ret

.GBC4: /* MAP_C4 */
	pushl %edx
	ccall S9xGetC4
	popl %edx
	LOAD_CYCLES
	ret

.GBBWRAM: /* MAP_BWRAM */
	andl $0x7fff, %edx
	addl $-24576, %edx
	movl BWRAM, %eax
	movb (%eax, %edx), %al
	ret

.GB7ROM: /* MAP_SPC7110_ROM */
	pushl %edx
	ccall S9xGetSPC7110Byte
	popl %edx
	LOAD_CYCLES
	ret

.GB7RAM: /* MAP_SPC7110_DRAM */
	movl $0x4800, %edx
	pushl %edx
	ccall S9xGetSPC7110
	popl %edx
	LOAD_CYCLES
	ret

.GBOBC1: /* MAP_OBC_RAM */
	pushl %edx
	ccall GetOBC1
	popl %edx
	LOAD_CYCLES
	ret

.GBSDSP: /* MAP_SETA_DSP */
	pushl %edx
	ccall S9xGetSetaDSP
	popl %edx
	LOAD_CYCLES
	ret

.GBSRISC: /* MAP_SETA_RISC */
	pushl %edx
	ccall S9xGetST018
	popl %edx
	LOAD_CYCLES
	ret


.globl S9xGetWord

S9xGetWord:
	movl %edx, %eax
	/*MK: blocks can be 0x1000 bytes, not a 0x2000 minimum*/
	andl $0x0fff, %eax
	cmpl $0x0fff, %eax
	/*MK*/
	jne .GWNotAtBlockBoundary
	pushl %edx
	call S9xGetByte
	popl %edx
        movb %al, OpenBus
	incl %edx
	call S9xGetByte
        movb %al, %ah
	movb OpenBus, %al
	ret

.GWNotAtBlockBoundary:
	movl %edx, %eax
	shrl $MEMMAP_SHIFT, %eax
	and $MEMMAP_MASK, %eax

	movb InDMA, %cl
	testb %cl, %cl
	jne .GW_NOADD
	movb MemorySpeed(%eax), %cl
	andl $0xff, %ecx
	addl %ecx, CYCLES
	addl %ecx, CYCLES
	SAVE_CYCLES
.GW_NOADD:

#ifdef CPU_SHUTDOWN
	movb BlockIsRAM(%eax), %ch
#endif	
	movl Map(, %eax, 4), %eax
	cmpl $18, %eax  /* MAP_LAST */
	jb .GWSpecial
	andl $0xffff, %edx
#ifdef CPU_SHUTDOWN
	testb %ch, %ch
	jz .GWNotRAM
	pushl %eax
	movl PCAtOpcodeStart, %eax
	movl %eax, WaitAddress
	popl %eax
.GWNotRAM:
#endif	
	movw (%eax, %edx), %ax
	ret

	.align 4
.GWSpecial:
	jmp *.GWJmpTable(, %eax, 4)

.data
	.align 4
.GWJmpTable:
	.long .GWPPU    /* MAP_PPU */
	.long .GWCPU    /* MAP_CPU */
	.long .GWDSP    /* MAP_DSP */
	.long .GWLSRAM  /* MAP_LOROM_SRAM */
	.long .GWHSRAM  /* MAP_HIROM_SRAM */
	.long .GWNONE   /* MAP_NONE */
	.long .GWDEBUG  /* MAP_DEBUG */
	.long .GWC4     /* MAP_C4 */
	.long .GWBWRAM  /* MAP_BWRAM */
	.long .GWNONE   /* MAP_BWRAM_BITMAP */
	.long .GWNONE   /* MAP_BWRAM_BITMAP2 */
	.long .GWNONE   /* MAP_SA1RAM */
	.long .GW7ROM   /* MAP_SPC7110_ROM */
	.long .GW7RAM   /* MAP_SPC7110_DRAM */
	.long .GW7SRM   /* MAP_RONLY_SRAM */
	.long .GWOBC1   /* MAP_OBC_RAM */
	.long .GWSDSP   /* MAP_SETA_DSP */
	.long .GWSRISC  /* MAP_SETA_RISC */

.text
.GWPPU: /* MAP_PPU */
	pushl %edx
	ccall S9xGetPPU
	popl %edx
	pushl %eax
	incl %edx
	pushl %edx
	ccall S9xGetPPU
	LOAD_CYCLES
	popl %edx
	popl %edx
	movb %al, %ah
	movb %dl, %al
	ret

.GWCPU: /* MAP_CPU */
	pushl %edx
	ccall S9xGetCPU
	popl %edx
	pushl %eax
	incl %edx
	pushl %edx
	ccall S9xGetCPU
	LOAD_CYCLES
	popl %edx
	popl %edx
	movb %al, %ah
	movb %dl, %al
	ret

.GWDSP: /* MAP_DSP */
	pushl %edx
	ccall S9xGetDSP
	popl %edx
	pushl %eax
	incl %edx
	pushl %edx
	ccall S9xGetDSP
	LOAD_CYCLES
	popl %edx
	popl %edx
	movb %al, %ah
	movb %dl, %al
	ret

.GWLSRAM: /* MAP_LOROM_SRAM */
	movl %edx, %ecx
	andl $0x7fff, %edx
	andl $0x00ff0000, %ecx
	sarl $1, %ecx
	orl  %ecx, %edx
	movl SRAM, %ecx
	andl SRAMMask, %edx
	movb (%ecx, %edx), %al
	incl %edx
	andl SRAMMask, %edx
	movb (%ecx, %edx), %ah
	ret

.GW7SRM:  /* MAP_RONLY_SRAM */
.GWHSRAM: /* MAP_HIROM_SRAM */
	movl %edx, %ecx
	andl $0xf0000, %ecx
	andl $0x7fff, %edx
	sarl $3, %ecx
	addl $-24576, %edx
	addl %ecx, %edx
	movl SRAM, %ecx
	movb (%ecx, %edx), %al
	incl %edx
	andl SRAMMask, %edx
	movb (%ecx, %edx), %ah
	ret

.GWNONE:
	xorl %eax, %eax
	movb OpenBus, %ah
	movb OpenBus, %al
	ret

.GWDEBUG: /* MAP_DEBUG */
	xorl %eax, %eax
	movb OpenBus, %ah
	movb OpenBus, %al
	ret

.GWC4: /* MAP_C4 */
	pushl %edx
	ccall S9xGetC4
	popl %edx
	pushl %eax
	incl %edx
	pushl %edx
	ccall S9xGetC4
	LOAD_CYCLES
	popl %edx
	popl %edx
	movb %al, %ah
	movb %dl, %al
	ret

.GWBWRAM: /* MAP_BWRAM */
	andl $0x7fff, %edx
	addl $-24576, %edx
	movl BWRAM, %eax
	movw (%eax, %edx), %ax
	ret

.GW7ROM: /* MAP_SPC7110_ROM */
	pushl %edx
	ccall S9xGetSPC7110Byte
	popl %edx
	pushl %eax
	incl %edx
	pushl %edx
	ccall S9xGetSPC7110Byte
	LOAD_CYCLES
	popl %edx
	popl %edx
	movb %al, %ah
	movb %dl, %al
	ret

.GW7RAM: /* MAP_SPC7110_DRAM */
	movl $0x4800, %edx
	pushl %edx
	ccall S9xGetSPC7110
	popl %edx
	pushl %eax
	pushl %edx
	ccall S9xGetSPC7110
	LOAD_CYCLES
	popl %edx
	popl %edx
	movb %al, %ah
	movb %dl, %al
	ret

.GWOBC1: /* MAP_OBC_RAM */
	pushl %edx
	ccall GetOBC1
	popl %edx
	pushl %eax
	incl %edx
	pushl %edx
	ccall GetOBC1
	LOAD_CYCLES
	popl %edx
	popl %edx
	movb %al, %ah
	movb %dl, %al
	ret

.GWSDSP: /* MAP_SETA_DSP */
	pushl %edx
	ccall S9xGetSetaDSP
	popl %edx
	pushl %eax
	incl %edx
	pushl %edx
	ccall S9xGetSetaDSP
	LOAD_CYCLES
	popl %edx
	popl %edx
	movb %al, %ah
	movb %dl, %al
	ret

.GWSRISC: /* MAP_SETA_RISC */
	pushl %edx
	ccall S9xGetST018
	popl %edx
	pushl %eax
	incl %edx
	pushl %edx
	ccall S9xGetST018
	LOAD_CYCLES
	popl %edx
	popl %edx
	movb %al, %ah
	movb %dl, %al
	ret


.globl S9xSetByte
S9xSetByte:
	pushl %eax
#ifdef CPU_SHUTDOWN
	movl $0, WaitAddress
#endif	
	movl %edx, %eax
	shrl $MEMMAP_SHIFT, %eax
	and $MEMMAP_MASK, %eax

	movb InDMA, %cl
	testb %cl, %cl
	jne .SB_NOADD
	movb MemorySpeed(%eax), %cl
	andl $0xff, %ecx
	addl %ecx, CYCLES
	SAVE_CYCLES
.SB_NOADD:
	
	movl WriteMap(, %eax, 4), %eax
	cmpl $18, %eax  /* MAP_LAST */
	jb .SBSpecial
	andl $0xffff, %edx
#ifdef CPU_SHUTDOWN
	addl %eax, %edx
	cmpl SA1WaitByteAddress1, %edx
	jz .Matched
	cmpl SA1WaitByteAddress2, %edx
	jnz .NoMatch
.Matched:
	cmpl $0, SA1Opcodes
	movl $0, SA1WaitCounter
	setnz %al
	movb %al, SA1Executing
.NoMatch:
	popl %ecx
	movb %cl, (%edx)
#else
	popl %ecx
	movb %cl, (%eax, %edx)
#endif
	ret

.SBSpecial:
	jmp *.SBJmpTable(, %eax, 4)
.data
	.align 4
.SBJmpTable:
	.long .SBPPU    /* MAP_PPU */
	.long .SBCPU    /* MAP_CPU */
	.long .SBDSP    /* MAP_DSP */
	.long .SBLSRAM  /* MAP_LOROM_SRAM */
	.long .SBHSRAM  /* MAP_HIROM_SRAM */
	.long .SBNONE   /* MAP_NONE */
	.long .SBDEBUG  /* MAP_DEBUG */
	.long .SBC4     /* MAP_C4 */
	.long .SBBWRAM  /* MAP_BWRAM */
	.long .SBNONE   /* MAP_BWRAM_BITMAP */
	.long .SBNONE   /* MAP_BWRAM_BITMAP2 */
	.long .SBNONE   /* MAP_SA1RAM */
	.long .SBNONE   /* MAP_SPC7110_ROM */
	.long .SBNONE   /* MAP_SPC7110_DRAM */
	.long .SBNONE   /* MAP_RONLY_SRAM */
	.long .SBOBC1   /* MAP_OBC_RAM */
	.long .SBSDSP   /* MAP_SETA_DSP */
	.long .SBSRISC  /* MAP_SETA_RISC */

.text
.SBPPU: /* MAP_PPU */
	STORE_REGISTERS
	popl %eax
	pushl %edx	/* Save Address because S9xSetPPU can stomp it with certain optimizations enabled */
	pushl %edx
	pushl %eax
	ccall S9xSetPPU
	LOAD_REGISTERS
	addl $8, %esp
	popl %edx
	ret

.SBCPU: /* MAP_CPU */
	STORE_REGISTERS
	popl %eax
	pushl %edx
	pushl %eax
	ccall S9xSetCPU
	LOAD_REGISTERS
	addl $8, %esp
	ret

.SBDSP: /* MAP_DSP */
	popl %eax
	pushl %edx
	pushl %eax
	ccall S9xSetDSP
	LOAD_CYCLES
	addl $8, %esp
	ret

.SBLSRAM: /* MAP_LOROM_SRAM */
	popl %eax
	movl SRAMMask, %ecx
	orl %ecx, %ecx
	jz .SBLSRAM_SKIP
	movl %edx, %ecx
	andl $0x7fff, %edx
	andl $0x00ff0000, %ecx
	sarl $1, %ecx
	orl  %ecx, %edx
	movl SRAM, %ecx
	andl SRAMMask, %edx
	movb %al, (%ecx, %edx)
	movb $1, SRAMModified
.SBLSRAM_SKIP:
	ret

.SBHSRAM: /* MAP_HIROM_SRAM */
	popl %eax
	movl %edx, %ecx
	andl $0xf0000, %ecx
	andl $0x7fff, %edx
	sarl $3, %ecx
	addl $-24576, %edx
	addl %ecx, %edx
	movl SRAMMask, %ecx
	orl %ecx, %ecx
	jz .SBHSRAM_SKIP
	andl %ecx, %edx
	movl SRAM, %ecx
	movb %al, (%ecx, %edx)
	movb $1, SRAMModified
.SBHSRAM_SKIP:
	ret

.SBNONE:  /* MAP_NONE */
.SBDEBUG: /* MAP_DEBUG */
	popl %eax
	ret

.SBC4: /* MAP_C4 */
	STORE_REGISTERS
	popl %eax
	pushl %edx
	pushl %eax
	ccall S9xSetC4
	LOAD_REGISTERS
	addl $8, %esp
	ret

.SBBWRAM: /* MAP_BWRAM */
	andl $0x7fff, %edx
	popl %eax
	addl $-24576, %edx
	movl BWRAM, %ecx
	movb %al, (%ecx, %edx)
	movb $1, SRAMModified
	ret

.SBOBC1: /* MAP_OBC_RAM */
	STORE_REGISTERS
	popl %eax
	pushl %edx
	pushl %eax
	ccall SetOBC1
	LOAD_REGISTERS
	addl $8, %esp
	ret

.SBSDSP: /* MAP_SETA_DSP */
	STORE_REGISTERS
	popl %eax
	pushl %edx
	pushl %eax
	ccall S9xSetSetaDSP
	LOAD_REGISTERS
	addl $8, %esp
	ret

.SBSRISC: /* MAP_SETA_RISC */
	STORE_REGISTERS
	popl %eax
	pushl %edx
	pushl %eax
	ccall S9xSetST018
	LOAD_REGISTERS
	addl $8, %esp
	ret

.globl S9xSetWord

S9xSetWord:
	pushl %eax

	movl %edx, %eax
	andl $0x0fff, %eax
	cmpl $0x0fff, %eax
	jne .SWNotAtBlockBoundary
	xorl %eax, %eax
	pushl %edx
	movb 4(%esp), %al
	call S9xSetByte
	popl %edx
	xorl %eax, %eax
	incl %edx
	movb 1(%esp), %al
	call S9xSetByte
	popl %ecx
	ret

.SWNotAtBlockBoundary:

#ifdef CPU_SHUTDOWN
	movl $0, WaitAddress
#endif	
	movl %edx, %eax
	shrl $MEMMAP_SHIFT, %eax
	and $MEMMAP_MASK, %eax

	movb InDMA, %cl
	testb %cl, %cl
	jne .SW_NOADD
	movb MemorySpeed(%eax), %cl
	andl $0xff, %ecx
	addl %ecx, CYCLES
	addl %ecx, CYCLES
	SAVE_CYCLES
.SW_NOADD:
	movl WriteMap(, %eax, 4), %eax
	cmpl $18, %eax  /* MAP_LAST */
	jb .SWSpecial
	andl $0xffff, %edx
#ifdef CPU_SHUTDOWN
	addl %eax, %edx
	cmpl SA1WaitByteAddress1, %edx
	jz .Matched2
	cmpl SA1WaitByteAddress2, %edx
	jnz .NoMatch2
.Matched2:
	cmpl $0, SA1Opcodes
	movl $0, SA1WaitCounter
	setnz %al
	movb %al, SA1Executing
.NoMatch2:
	popl %ecx
	movw %cx, (%edx)
#else
	popl %ecx
	movw %cx, (%eax, %edx)
#endif
	ret

.SWSpecial:
	jmp *.SWJmpTable(, %eax, 4)
.data
	.align 4
.SWJmpTable:
	.long .SWPPU    /* MAP_PPU */
	.long .SWCPU    /* MAP_CPU */
	.long .SWDSP    /* MAP_DSP */
	.long .SWLSRAM  /* MAP_LOROM_SRAM */
	.long .SWHSRAM  /* MAP_HIROM_SRAM */
	.long .SWNONE   /* MAP_NONE */
	.long .SWDEBUG  /* MAP_DEBUG */
	.long .SWC4     /* MAP_C4 */
	.long .SWBWRAM  /* MAP_BWRAM */
	.long .SWNONE   /* MAP_BWRAM_BITMAP */
	.long .SWNONE   /* MAP_BWRAM_BITMAP2 */
	.long .SWNONE   /* MAP_SA1RAM */
	.long .SWNONE   /* MAP_SPC7110_ROM */
	.long .SWNONE   /* MAP_SPC7110_DRAM */
	.long .SWNONE   /* MAP_RONLY_SRAM */
	.long .SWOBC1   /* MAP_OBC_RAM */
	.long .SWSDSP   /* MAP_SETA_DSP */
	.long .SWSRISC  /* MAP_SETA_RISC */

.text
.SWPPU: /* MAP_PPU */
	STORE_REGISTERS
	popl %eax
	pushl %edx	/* Save Address because S9xSetPPU will use it with certain optimizations enabled */
	pushl %eax	/* Save Byte because S9xSetPPU will use it with certain optimizations enabled */
	pushl %edx
	pushl %eax
	ccall S9xSetPPU
	popl %eax
	popl %edx
	popl %eax
	popl %edx
	pushl %edx
	movb %ah, %al
	incl %edx
	pushl %edx
	pushl %eax
	ccall S9xSetPPU
	LOAD_REGISTERS
	addl $8, %esp
	popl %edx
	ret

.SWCPU: /* MAP_CPU */
	STORE_REGISTERS
	popl %eax
	pushl %edx
	pushl %eax
	ccall S9xSetCPU
	popl %eax
	popl %edx
	movb %ah, %al
	incl %edx
	pushl %edx
	pushl %eax
	ccall S9xSetCPU
	LOAD_REGISTERS
	addl $8, %esp
	ret

.SWDSP: /* MAP_DSP */
	popl %eax
	pushl %edx
	pushl %eax
	ccall S9xSetDSP
	popl %eax
	popl %edx
	movb %ah, %al
	incl %edx
	pushl %edx
	pushl %eax
	ccall S9xSetDSP
	LOAD_CYCLES
	addl $8, %esp
	ret

.SWLSRAM: /* MAP_LOROM_SRAM */
	popl %eax
	movl SRAMMask, %ecx
	orl %ecx, %ecx
	jz .SWLSRAM_SKIP
	movl %edx, %ecx
	andl $0x7fff, %edx
	andl $0x00ff0000, %ecx
	sarl $1, %ecx
	orl  %ecx, %edx
	movl SRAM, %ecx
	andl SRAMMask, %edx
	movb %al, (%ecx, %edx)
	incl %edx
	andl SRAMMask, %edx
	movb %ah, (%ecx, %edx)
	movb $1, SRAMModified
.SWLSRAM_SKIP:
	ret

.SWHSRAM: /* MAP_HIROM_SRAM */
	popl %eax
	movl %edx, %ecx
	andl $0xf0000, %ecx
	andl $0x7fff, %edx
	sarl $3, %ecx
	addl $-24576, %edx
	addl %ecx, %edx
	movl SRAMMask, %ecx
	orl %ecx, %ecx
	jz .SWHSRAM_SKIP
	andl %ecx, %edx
	movl SRAM, %ecx
	movb %al, (%ecx, %edx)
	incl %edx
	andl SRAMMask, %edx
	movb %ah, (%ecx, %edx)
	movb $1, SRAMModified
.SWHSRAM_SKIP:
	ret

.SWNONE:
.SWDEBUG: /* MAP_DEBUG */
	popl %eax
	ret

.SWC4: /* MAP_C4 */
	STORE_REGISTERS
	popl %eax
	pushl %edx
	pushl %eax
	ccall S9xSetC4
	popl %eax
	popl %edx
	movb %ah, %al
	incl %edx
	pushl %edx
	pushl %eax
	ccall S9xSetC4
	LOAD_REGISTERS
	addl $8, %esp
	ret

.SWBWRAM: /* MAP_BWRAM */
	andl $0x7fff, %edx
	popl %eax
	addl $-24576, %edx
	movl BWRAM, %ecx
	movw %ax, (%ecx, %edx)
	movb $1, SRAMModified
	ret

.SWOBC1: /* MAP_OBC1 */
	STORE_REGISTERS
	popl %eax
	pushl %edx
	pushl %eax
	ccall SetOBC1
	popl %eax
	popl %edx
	movb %ah, %al
	incl %edx
	pushl %edx
	pushl %eax
	ccall SetOBC1
	LOAD_REGISTERS
	addl $8, %esp
	ret

.SWSDSP: /* MAP_SETA_DSP */
	STORE_REGISTERS
	popl %eax
	pushl %edx
	pushl %eax
	ccall S9xSetSetaDSP
	popl %eax
	popl %edx
	movb %ah, %al
	incl %edx
	pushl %edx
	pushl %eax
	ccall S9xSetSetaDSP
	LOAD_REGISTERS
	addl $8, %esp
	ret

.SWSRISC: /* MAP_SETA_RISC */
	STORE_REGISTERS
	popl %eax
	pushl %edx
	pushl %eax
	ccall S9xSetST018
	popl %eax
	popl %edx
	movb %ah, %al
	incl %edx
	pushl %edx
	pushl %eax
	ccall S9xSetST018
	LOAD_REGISTERS
	addl $8, %esp
	ret


.globl S9xSetPCBase

S9xSetPCBase:
	movl %edx, %eax
	shrl $MEMMAP_SHIFT, %eax
	and $MEMMAP_MASK, %eax
	movb MemorySpeed(%eax), %cl
	andl $0xff, %ecx
	movl %ecx, MemSpeed
	addl %ecx, %ecx
	movl %ecx, MemSpeedx2
	movl Map(, %eax, 4), %eax
	cmpl $18, %eax  /* MAP_LAST */
	jb .SPCSpecial
	andl $0xffff, %edx
	movl %eax, PCBase
	addl %edx, %eax
	movl %eax, PC
	ret

	.align 4
.SPCSpecial:
	jmp *.SPCJmpTable(, %eax, 4)
.data
	.align 4
.SPCJmpTable:
	.long .SPCPPU    /* MAP_PPU */
	.long .SPCCPU    /* MAP_CPU */
	.long .SPCDSP    /* MAP_DSP */
	.long .SPCLSRAM  /* MAP_LOROM_SRAM */
	.long .SPCHSRAM  /* MAP_HIROM_SRAM */
	.long .SPCNONE   /* MAP_NONE */
	.long .SPCDEBUG  /* MAP_DEBUG */
	.long .SPCC4     /* MAP_C4 */
	.long .SPCBWRAM  /* MAP_BWRAM */
	.long .SPCNONE   /* MAP_BWRAM_BITMAP */
	.long .SPCNONE   /* MAP_BWRAM_BITMAP2 */
	.long .SPCNONE   /* MAP_SA1RAM */
	.long .SPCNONE   /* MAP_SPC7110_ROM */
	.long .SPCNONE   /* MAP_SPC7110_DRAM */
	.long .SPCNONE   /* MAP_RONLY_SRAM */
	.long .SPCNONE   /* MAP_OBC_RAM */
	.long .SPCNONE   /* MAP_SETA_DSP */
	.long .SPCNONE   /* MAP_SETA_RISC */

.text
.SPCPPU: /* MAP_PPU */
	movl FillRAM, %ecx
	andl $0xffff, %edx
	movl %ecx, PCBase
	addl %edx, %ecx
	movl %ecx, PC
	ret

.SPCCPU: /* MAP_CPU */
	movl FillRAM, %ecx
	andl $0xffff, %edx
	movl %ecx, PCBase
	addl %edx, %ecx
	movl %ecx, PC
	ret

.SPCDSP: /* MAP_DSP */
	movl FillRAM, %ecx
	andl $0xffff, %edx
	movl %ecx, PCBase
	addl %edx, %ecx
	movl %ecx, PC
	ret

.SPCLSRAM: /* MAP_LOROM_SRAM */
	movl SRAM, %ecx
	andl $0xffff, %edx
	movl %ecx, PCBase
	addl %edx, %ecx
	movl %ecx, PC
	ret

.SPCHSRAM: /* MAP_HIROM_SRAM */
	movl SRAM, %eax
	andl $0xffff, %edx
	addl $-24576, %eax
	movl %eax, PCBase
	addl %eax, %edx
	movl %edx, PC
	ret

.SPCNONE:
.SPCDEBUG: /* MAP_DEBUG */
	movl SRAM, %eax
	andl $0xffff, %edx
	movl %eax, PCBase
	addl %eax, %edx
	movl %edx, PC
	ret

.SPCC4: /* MAP_C4 */
	movl C4RAM, %ecx
	andl $0xffff, %edx
	addl $-0x6000, %ecx
	movl %ecx, PCBase
	addl %edx, %ecx
	movl %ecx, PC
	ret

.SPCBWRAM: /* MAP_BWRAM */
	movl SRAM, %eax
	andl $0xffff, %edx
	addl $-24576, %eax
	movl %eax, PCBase
	addl %eax, %edx
	movl %edx, PC
	ret
