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

S9xSA1GetByte:
	movl %edx, %eax
	shrl $MEMMAP_SHIFT, %eax
	and $MEMMAP_MASK, %eax
	movl SA1Map(, %eax, 4), %eax
	cmpl $10, %eax
	jbe .GBSpecial
	andl $0xffff, %edx
	movb (%eax, %edx), %al
	ret

	.align 4
.GBSpecial:
	jmp *.GBJmpTable(, %eax, 4)
.data
	.align 4
.GBJmpTable:
	.long .GBPPU
	.long .GBCPU
	.long .GBDSP
	.long .GBLSRAM
	.long .GBHSRAM
	.long .GBNONE
	.long .GBDEBUG
	.long .GBNONE
	.long .GBBWRAM
	.long .GBBWBITMAP
	.long .GBBWBITMAP2

.text
.GBPPU: /* MAP_PPU */
	andl $0xffff, %edx
	pushl %edx
	ccall S9xGetSA1
	popl %edx
	ret

.GBCPU: /* MAP_CPU */

.GBDSP: /* MAP_DSP */
	mov $0, %al
	ret

.GBLSRAM: /* MAP_LOROM_SRAM */
	andl $0xffff, %edx
	movl SRAM, %ecx
	andw SRAMMask, %dx
	movb (%ecx, %edx), %al
	ret

.GBHSRAM: /* MAP_HIROM_SRAM */
	movl %edx, %ecx
	andl $0xf0000, %ecx
	andl $0x7fff, %edx
	sarl $3, %ecx
	addl $-24576, %edx
	addl %ecx, %edx
	movl SRAM, %eax
	andw SRAMMask, %dx
	movb (%eax, %edx), %al
	ret

.GBNONE:
.GBDEBUG: /* MAP_DEBUG */
	xorl %eax, %eax
	movb OpenBus, %al
	ret

.GBBWRAM: /* MAP_BWRAM */
	andl $0x7fff, %edx
	addl $-24576, %edx
	movl SA1BWRAM, %eax
	movb (%eax, %edx), %al
	ret

.GBBWBITMAP:
	movl FillRAM, %eax
	subl $0x600000, %edx
	testb $0x80, 0x223f(%eax)
	movl %edx, %eax
	jz .GB4

	// Depth 2
	movb %dl, %cl
	shrl $2, %eax
	andb $3, %cl
	andl $0xffff, %eax
	addl SRAM, %eax
	shlb $1, %cl
	movb (%eax), %al
	shrb %cl, %al
	andb $3, %al
	ret	
.GB4:
	movb %dl, %cl
	shrl $1, %eax
	andb $1, %cl
	andl $0xffff, %eax
	addl SRAM, %eax
	shlb $2, %cl
	movb (%eax), %al
	shrb %cl, %al
	andb $15, %al
	ret	

.GBBWBITMAP2:
	andl $0xffff, %edx
	movl FillRAM, %eax
	subl $0x6000, %edx
	testb $0x80, 0x223f(%eax)
	movl %edx, %eax
	jz .GB42

	// Depth 2
	movb %dl, %cl
	shrl $2, %eax
	andb $3, %cl
	andl $0xffff, %eax
	addl SA1BWRAM, %eax
	shlb $1, %cl
	movb (%eax), %al
	shrb %cl, %al
	andb $3, %al
	ret	
.GB42:
	movb %dl, %cl
	shrl $1, %eax
	andb $1, %cl
	andl $0xffff, %eax
	addl SA1BWRAM, %eax
	shlb $2, %cl
	movb (%eax), %al
	shrb %cl, %al
	andb $15, %al
	ret	


S9xSA1GetWord:
	pushl %edx
	call S9xSA1GetByte
	popl %edx
	movb %al, OpenBus
	incl %edx
	call S9xSA1GetByte
	movb %al, %ah
	movb OpenBus, %al
	ret

S9xSA1SetByte:
	pushl %eax
	movl %edx, %eax
	shrl $MEMMAP_SHIFT, %eax
	and $MEMMAP_MASK, %eax
	movl SA1WriteMap(, %eax, 4), %eax
	cmpl $10, %eax
	jbe .SBSpecial
	andl $0xffff, %edx
	popl %ecx
	movb %cl, (%eax, %edx)
	ret

.SBSpecial:
	jmp *.SBJmpTable(, %eax, 4)
.data
	.align 4
.SBJmpTable:
	.long .SBPPU
	.long .SBCPU
	.long .SBDSP
	.long .SBLSRAM
	.long .SBHSRAM
	.long .SBNONE
	.long .SBDEBUG
	.long .SBNONE
	.long .SBBWRAM
	.long .SBBWBITMAP
	.long .SBBWBITMAP2

.text
.SBPPU: /* MAP_PPU */
	andl $0xffff, %edx
	popl %eax
	pushl %edx
	pushl %eax
	ccall S9xSetSA1
	addl $8, %esp
	ret

.SBCPU: /* MAP_CPU */
	popl %eax
	ret

.SBDSP: /* MAP_DSP */
	popl %eax
	ret

.SBLSRAM: /* MAP_LOROM_SRAM */
	popl %eax
	movw SRAMMask, %cx
	orw %cx, %cx
	jz .SBLSRAM_SKIP
	andl $0xffff, %edx
	andw %cx, %dx
	movl SRAM, %ecx
	movb %al, (%ecx, %edx)
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
	movw SRAMMask, %cx
	orw %cx, %cx
	jz .SBHSRAM_SKIP
	andw %cx, %dx
	movl SRAM, %ecx
	movb %al, (%ecx, %edx)
.SBHSRAM_SKIP:
	ret

.SBNONE:
.SBDEBUG: /* MAP_DEBUG */
	popl %eax
	ret

.SBBWRAM: /* MAP_BWRAM */
	andl $0x7fff, %edx
	popl %eax
	addl $-24576, %edx
	movl SA1BWRAM, %ecx
	movb %al, (%ecx, %edx)
	ret

.SBBWBITMAP:
	movl FillRAM, %eax
	subl $0x600000, %edx
	movb 0x223f(%eax), %al
	testb $0x80, %al
	movl %edx, %eax
	jz .SB4

	// Depth 2
	shrl $2, %eax
	movb %dl, %cl
	andl $0xffff, %eax
	addl SRAM, %eax
	andb $3, %cl
	popl %edx
	shlb $1, %cl
	movb %dl, %dh
	movb $3, %dl
	shlb %cl, %dl
	notb %dl
	andb $3, %dh
	andb (%eax), %dl
	shlb %cl, %dh
	orb %dh, %dl
	movb %dl, (%eax)
	ret	
.SB4:
	shrl $1, %eax
	movb %dl, %cl
	andl $0xffff, %eax
	addl SRAM, %eax
	andb $1, %cl
	popl %edx
	shlb $2, %cl
	movb %dl, %dh
	movb $15, %dl
	shlb %cl, %dl
	notb %dl
	andb $15, %dh
	andb (%eax), %dl
	shlb %cl, %dh
	orb %dh, %dl
	movb %dl, (%eax)
	ret	

.SBBWBITMAP2:
	andl $0xffff, %edx
	subl $0x6000, %edx
	movl FillRAM, %eax
	testb $0x80, 0x223f(%eax)
	jz .SB42

	// Depth 2
	movl %edx, %eax
	shrl $2, %eax
	andl $0xffff, %eax
	addl SA1BWRAM, %eax

	movb %dl, %cl
	popl %edx
	andb $3, %cl
	movb %dl, %dh
	shlb $1, %cl
	movb $3, %dl
	andb $3, %dh
	shlb %cl, %dl
	shlb %cl, %dh
	notb %dl
	andb (%eax), %dl
	orb %dh, %dl
	movb %dl, (%eax)
	ret	
.SB42:
	movl %edx, %eax
	shrl $1, %eax
	andl $0xffff, %eax
	addl SA1BWRAM, %eax
	movb %dl, %cl
	andb $1, %cl
	shlb $2, %cl
	popl %edx
	movb %dl, %dh
	movb $15, %dl
	shlb %cl, %dl
	notb %dl
	andb (%eax), %dl
	andb $15, %dh
	shlb %cl, %dh
	orb %dh, %dl
	movb %dl, (%eax)
	ret	

S9xSA1SetWord:
	pushl %eax
	pushl %edx
	call S9xSA1SetByte
	popl %edx
	popl %eax
	incl %edx
	movb %ah, %al
	jmp S9xSA1SetByte

S9xSA1SetPCBase:
	movl %edx, %eax
	shrl $MEMMAP_SHIFT, %eax
	and $MEMMAP_MASK, %eax
	movl SA1Map(, %eax, 4), %eax
	cmpl $10, %eax
	jbe .SPCSpecial
	andl $0xffff, %edx
	movl %eax, SA1PCBase
	addl %edx, %eax
	movl %eax, PC
	ret

	.align 4
.SPCSpecial:
	jmp *.SPCJmpTable(, %eax, 4)
.data
	.align 4
.SPCJmpTable:
	.long .SPCPPU
	.long .SPCCPU
	.long .SPCDSP
	.long .SPCLSRAM
	.long .SPCHSRAM
	.long .SPCNONE
	.long .SPCDEBUG
	.long .SPCNONE
	.long .SPCBWRAM
	.long .SPCNONE
	.long .SPCNONE

.text
.SPCPPU: /* MAP_PPU */
	movl FillRAM, %ecx
	andl $0xffff, %edx
	movl %ecx, SA1PCBase
	addl %edx, %ecx
	movl %ecx, PC
	ret

.SPCCPU: /* MAP_CPU */
	movl FillRAM, %ecx
	andl $0xffff, %edx
	movl %ecx, SA1PCBase
	addl %edx, %ecx
	movl %ecx, PC
	ret

.SPCDSP: /* MAP_DSP */
	movl FillRAM, %ecx
	andl $0xffff, %edx
	movl %ecx, SA1PCBase
	addl %edx, %ecx
	movl %ecx, PC
	ret

.SPCLSRAM: /* MAP_LOROM_SRAM */
	movl SRAM, %ecx
	andl $0xffff, %edx
	movl %ecx, SA1PCBase
	addl %edx, %ecx
	movl %ecx, PC
	ret

.SPCHSRAM: /* MAP_HIROM_SRAM */
	movl SRAM, %eax
	andl $0xffff, %edx
	addl $-24576, %eax
	movl %eax, SA1PCBase
	addl %eax, %edx
	movl %edx, PC
	ret

.SPCNONE:
.SPCDEBUG: /* MAP_DEBUG */
	movl SRAM, %eax
	movl %eax, SA1PCBase
	movl %eax, PC
	ret

.SPCBWRAM: /* MAP_BWRAM */
	movl SA1BWRAM, %eax
	andl $0xffff, %edx
	addl $-24576, %eax
	movl %eax, SA1PCBase
	addl %eax, %edx
	movl %edx, PC
	ret
