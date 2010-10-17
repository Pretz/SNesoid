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
#include <allegro.h>
#undef TRUE
#undef FALSE

#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <stdio.h>

#include <dpmi.h>
#include <go32.h>

#include "snes9x.h"
#include "memmap.h"
#include "debug.h"
#include "ppu.h"
#include "snapshot.h"
#include "gfx.h"
#include "display.h"
#include "apu.h"
#include "soundux.h"

extern BITMAP *off_screen;
extern uint32 last_rendered_width;
extern uint32 last_rendered_height;

void SaveScreenshot ()
{
    char FilePCX [512];
    char FileNAME [255], FileDIR [255], FileDRIVE [_MAX_DRIVE], FileEXT [255];
    int i, numpos;
    char HexDig [17] = "0123456789ABCDEF";
    BITMAP *bmp;

    _splitpath (Memory.ROMFilename, FileDRIVE, FileDIR, FileNAME, FileEXT);

    if (strlen (FileNAME) <= 8)
    {
	for (i = strlen (FileNAME); i < 8 ; i++)
	    FileNAME [i] = '_';
	FileNAME [8] = 0;  // We extended the filename... Truncate it at 8.
	numpos = 6;
    }
    else
    {
	numpos = strlen (FileNAME);
			 // Make sure our extending terminates properly.
	FileNAME [numpos + 1] = FileNAME [numpos + 2]=0;
    }

    i = 0;
    while (i <= 0xff)    // Find an open slot. 0-FF.
    {
	FileNAME [numpos] = HexDig [i >> 4];
	FileNAME [numpos + 1] = HexDig [i & 0xf];
	_makepath (FilePCX, FileDRIVE, FileDIR, FileNAME, "pcx");

	if (!exists (FilePCX))
	   break;
	else
	   i++;
    }

    // There.  We have a decent filename, now save the damned thing!
    uint16 Brightness = IPPU.MaxBrightness * 138;
    PALLETE p;
    for (int i = 0; i < 256; i++)
    {
	p[i].r = (((PPU.CGDATA [i] >> 0) & 0x1F) * Brightness) >> 10;
	p[i].g = (((PPU.CGDATA [i] >> 5) & 0x1F) * Brightness) >> 10;
	p[i].b = (((PPU.CGDATA [i] >> 10) & 0x1F) * Brightness) >> 10;
    }
    bmp = create_sub_bitmap (off_screen, 0, 0, last_rendered_width,
			     last_rendered_height);
    save_bitmap (FilePCX, bmp, p);
    destroy_bitmap (bmp);
}

