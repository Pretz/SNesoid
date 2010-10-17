/*******************************************************************************
  Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
 
  (c) Copyright 1996 - 2002 Gary Henderson (gary.henderson@ntlworld.com) and
                            Jerremy Koot (jkoot@snes9x.com)

  (c) Copyright 2001 - 2004 John Weidman (jweidman@slip.net)

  (c) Copyright 2002 - 2004 Brad Jorsch (anomie@users.sourceforge.net),
                            funkyass (funkyass@spam.shaw.ca),
                            Joel Yliluoma (http://iki.fi/bisqwit/)
                            Kris Bleakley (codeviolation@hotmail.com),
                            Matthew Kendora,
                            Nach (n-a-c-h@users.sourceforge.net),
                            Peter Bortas (peter@bortas.org) and
                            zones (kasumitokoduck@yahoo.com)

  C4 x86 assembler and some C emulation code
  (c) Copyright 2000 - 2003 zsKnight (zsknight@zsnes.com),
                            _Demo_ (_demo_@zsnes.com), and Nach

  C4 C++ code
  (c) Copyright 2003 Brad Jorsch

  DSP-1 emulator code
  (c) Copyright 1998 - 2004 Ivar (ivar@snes9x.com), _Demo_, Gary Henderson,
                            John Weidman, neviksti (neviksti@hotmail.com),
                            Kris Bleakley, Andreas Naive

  DSP-2 emulator code
  (c) Copyright 2003 Kris Bleakley, John Weidman, neviksti, Matthew Kendora, and
                     Lord Nightmare (lord_nightmare@users.sourceforge.net

  OBC1 emulator code
  (c) Copyright 2001 - 2004 zsKnight, pagefault (pagefault@zsnes.com) and
                            Kris Bleakley
  Ported from x86 assembler to C by sanmaiwashi

  SPC7110 and RTC C++ emulator code
  (c) Copyright 2002 Matthew Kendora with research by
                     zsKnight, John Weidman, and Dark Force

  S-DD1 C emulator code
  (c) Copyright 2003 Brad Jorsch with research by
                     Andreas Naive and John Weidman
 
  S-RTC C emulator code
  (c) Copyright 2001 John Weidman
  
  ST010 C++ emulator code
  (c) Copyright 2003 Feather, Kris Bleakley, John Weidman and Matthew Kendora

  Super FX x86 assembler emulator code 
  (c) Copyright 1998 - 2003 zsKnight, _Demo_, and pagefault 

  Super FX C emulator code 
  (c) Copyright 1997 - 1999 Ivar, Gary Henderson and John Weidman


  SH assembler code partly based on x86 assembler code
  (c) Copyright 2002 - 2004 Marcus Comstedt (marcus@mc.pp.se) 

 
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
.macro APUS9xPackStatus K
    movb ApuP, %dl
    andb $~(Zero | Negative | Carry | Overflow), %dl
    orb APU_Carry, %dl
    movb APU_Zero, %al
    andb $0x80, %al
    orb %al, %dl
    movb APU_Overflow, %al
    salb $6, %al
    orb %al, %dl
    movb APU_Zero, %al
    orb %al, %al
    setz %al
    salb $1, %al
    orb %al, %dl
    movb %dl, ApuP
.endm

.macro APUS9xUnpackStatus K
.endm

.macro Absolute K
	movw (APUPC), %dx
	addl $2, APUPC
	andl $0xffff, %edx
.endm

.macro Direct K
	movb (APUPC), %dl
	incl APUPC
	andl $0xff, %edx
.endm

.macro Immediate8 K
	movb (APUPC), %al
	incl APUPC
.endm

.macro IndirectX K
	movb ApuX, %dl
	andl $0xff, %edx
.endm

.macro IndexedXIndirect K
	xorl %eax, %eax
	xorl %edx, %edx
	movb ApuX, %al
	movl APUDirectPage, %ecx
	addb (APUPC), %al
	movw (%ecx, %eax), %dx
	incl APUPC
.endm

.macro DirectX K
        movb (APUPC), %dl
	addb ApuX, %dl
	andl $0xff, %edx
	incl APUPC
.endm

.macro AbsoluteX K
	movb ApuX, %dl
	andl $0xff, %edx
	addw (APUPC), %dx
	addl $2, APUPC
.endm	

.macro AbsoluteY K
	movb ApuY, %dl
	andl $0xff, %edx
	addw (APUPC), %dx
	addl $2, APUPC
.endm

.macro IndirectIndexedY K
	xorl %edx, %edx
	xorl %eax, %eax
	movl APUDirectPage, %ecx
	movb ApuY, %dl
	movb (APUPC), %al
	addw (%ecx, %eax), %dx
	incl APUPC
.endm

.macro MemBit K
	xorl %ecx, %ecx
	movw (APUPC), %dx
	movb 1(APUPC), %cl
	shrb $5, %cl
	andl $0x1fff, %edx
	addl $2, APUPC
.endm

.macro ApuPushWord
	movb ApuS, %cl
	movl APURAM, %edx
	andl $0xff, %ecx
	movw %ax,0xff(%edx, %ecx)
	subl $2, %ecx
	movb %cl, ApuS
.endm

.macro ApuPushByte
	movb ApuS, %cl
	movl APURAM, %edx
	andl $0xff, %ecx
	movb %al,0x100(%edx, %ecx)
	decb %cl
	movb %cl, ApuS
.endm

.macro Tcall N
	movl APUPC, %eax
	subl APURAM, %eax
	ApuPushWord
	movw APUExtraRAM + ((15 - \N) << 1), %cx
	movl APURAM, APUPC
	andl $0xffff, %ecx
	addl %ecx, APUPC
	ret
.endm	

.macro Set K
	Direct SET\K
	pushl %edx
	call S9xAPUGetByteZ
	orb $(1 << \K), %al
	popl %edx
	call S9xAPUSetByteZ
	ret
.endm

.macro Clr K
	Direct CLR\K
	pushl %edx
	call S9xAPUGetByteZ
	andb $~(1 << \K), %al
	popl %edx
	call S9xAPUSetByteZ
	ret
.endm

.macro BBS K
	movb (APUPC), %dl
	andl $0xff, %edx
	call S9xAPUGetByteZ
	andb $(1 << \K), %al
	jz .BBS\K
	movsbl 1(APUPC), %eax
	addl $2, APUPC
	addl %eax, APUPC
	ret
.BBS\K:
	addl $2, APUPC
	ret
.endm	

.macro BBC K
	movb (APUPC), %dl
	andl $0xff, %edx
	call S9xAPUGetByteZ
	andb $(1 << \K), %al
	jnz .BBC\K
	movsbl 1(APUPC), %eax
	addl $2, APUPC
	addl %eax, APUPC
	ret
.BBC\K:
	addl $2, APUPC
	ret
.endm	

.macro ORA K
	orb ApuA, %al
	movb %al, ApuA
	movb %al, APU_Zero
	movb %al, APU_Negative
	ret
.endm

