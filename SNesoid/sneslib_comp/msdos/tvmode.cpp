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
#include <sys/farptr.h>

#include "snes9x.h"
#include "port.h"
#include "gfx.h"

#include <allegro.h>

extern uint32 screen_width;
extern uint32 screen_height;

void TVMode (uint8 *srcPtr, uint32 srcPitch,
	     uint8 *deltaPtr,
	     BITMAP *dstBitmap, int width, int height)
{
    uint8 *finish;
    uint32 dstPitch = dstBitmap->w * 2;
    uint32 line;
    uint32 x_offset;
    uint32 fraction;
    uint32 error = 0;
    uint32 colorMask = ~(RGB_LOW_BITS_MASK | (RGB_LOW_BITS_MASK << 16));
    uint32 lowPixelMask = RGB_LOW_BITS_MASK;

    if (height * 2 <= screen_height)
    {
	line = (screen_height - height * 2) >> 1;
	fraction = 0x10000;
    }
    else
    {
	line = 0;
	fraction = ((screen_height - height) * 0x10000) / height;
    }

    _farsetsel (dstBitmap->seg);
    
    if (width == 512)
    {
	// Offset into scanline in bytes, since each pixel takes two bytes,
	// no divide by two.
	x_offset = screen_width - width;

	do
	{
	    uint32 *bP = (uint32 *) srcPtr;
	    uint32 *xP = (uint32 *) deltaPtr;
	    uint32 dP = bmp_write_line (dstBitmap, line) + x_offset;
	    uint32 currentPixel;
	    uint32 currentDelta;

	    finish = (uint8 *) bP + ((width + 2) << 1);
	    if ((error += fraction) >= 0x10000)
	    {
		error -= 0x10000;
		do
		{
		    currentPixel = *bP++;

		    if (currentPixel != *xP++)
		    {
			uint32 product, darkened;

			*(xP - 1) = currentPixel;
			_farnspokel (dP, currentPixel);

			darkened = (product = ((currentPixel & colorMask) >> 1));
			darkened += (product = ((product & colorMask) >> 1));
			darkened += (product & colorMask) >> 1;
			_farnspokel (dP + dstPitch, darkened);
		    }

		    dP += 4;
		} while ((uint8 *) bP < finish);
		line += 2;
	    }
	    else
	    {
		do
		{
		    currentPixel = *bP++;

		    if (currentPixel != *xP++)
		    {
			*(xP - 1) = currentPixel;
			_farnspokel (dP, currentPixel);
		    }
		    dP += 4;
		} while ((uint8 *) bP < finish);
		line++;
	    }

	    deltaPtr += srcPitch;
	    srcPtr += srcPitch;
	} while (--height);
    }
    else
    {
	x_offset = (screen_width - width * 2);
	do
	{
	    uint32 *bP = (uint32 *) srcPtr;
	    uint32 *xP = (uint32 *) deltaPtr;
	    uint32 dP = bmp_write_line (dstBitmap, line) + x_offset;
	    uint32 currentPixel;
	    uint32 nextPixel;
	    uint32 currentDelta;
	    uint32 nextDelta;

	    finish = (uint8 *) bP + ((width + 2) << 1);
	    nextPixel = *bP++;
	    nextDelta = *xP++;
	    if ((error += fraction) >= 0x10000)
	    {
		error -= 0x10000;
		do
		{
		    currentPixel = nextPixel;
		    currentDelta = nextDelta;
		    nextPixel = *bP++;
		    nextDelta = *xP++;

		    if ((nextPixel != nextDelta) || (currentPixel != currentDelta))
		    {
			uint32 colorA, colorB, product, darkened;

			*(xP - 2) = currentPixel;
			colorA = currentPixel & 0xffff;

			colorB = (currentPixel & 0xffff0000) >> 16;
			product = colorA |
				  ((((colorA & colorMask) >> 1) +
				    ((colorB & colorMask) >> 1) +
				    (colorA & colorB & lowPixelMask)) << 16);
			_farnspokel (dP, product);

			darkened = (product = ((product & colorMask) >> 1));
			darkened += (product = ((product & colorMask) >> 1));
			darkened += (product & colorMask) >> 1;
			_farnspokel (dP + dstPitch, darkened);

			colorA = nextPixel & 0xffff;
			product = colorB |
				  ((((colorA & colorMask) >> 1) +
				    ((colorB & colorMask) >> 1) +
				    (colorA & colorB & lowPixelMask)) << 16);
			_farnspokel (dP + 4, product);

			darkened = (product = ((product & colorMask) >> 1));
			darkened += (product = ((product & colorMask) >> 1));
			darkened += (product & colorMask) >> 1;
			_farnspokel (dP + dstPitch + 4, darkened);
		    }

		    dP += 8;
		} while ((uint8 *) bP < finish);
		line += 2;
	    }
	    else
	    {
		do
		{
		    currentPixel = nextPixel;
		    currentDelta = nextDelta;
		    nextPixel = *bP++;
		    nextDelta = *xP++;

		    if ((nextPixel != nextDelta) || (currentPixel != currentDelta))
		    {
			uint32 colorA, colorB, product;

			*(xP - 2) = currentPixel;
			colorA = currentPixel & 0xffff;

			colorB = (currentPixel & 0xffff0000) >> 16;
			product = colorA |
				  ((((colorA & colorMask) >> 1) +
				    ((colorB & colorMask) >> 1) +
				    (colorA & colorB & lowPixelMask)) << 16);
			_farnspokel (dP, product);

			colorA = nextPixel & 0xffff;
			product = colorB |
				  ((((colorA & colorMask) >> 1) +
				    ((colorB & colorMask) >> 1) +
				    (colorA & colorB & lowPixelMask)) << 16);
			_farnspokel (dP + 4, product);
		    }
		    dP += 8;
		} while ((uint8 *) bP < finish);
		line++;
	    }

	    deltaPtr += srcPitch;
	    srcPtr += srcPitch;
	} while (--height);
    }
}

