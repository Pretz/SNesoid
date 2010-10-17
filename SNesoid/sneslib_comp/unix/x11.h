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
#ifndef _x11_h_
#define _x11_h_

#include <X11/Xlib.h>

#ifdef MITSHM
#include <sys/ipc.h>
#include <sys/shm.h>
#include <X11/extensions/XShm.h>
#endif

#include "3d.h"

typedef struct
{
    Display	*display;
    Screen	*screen;
    int		screen_num;
    Visual	*visual;
    Window	window;
    GC		gc;
    XImage	*image;
    uint8	*image_date;
    int		bytes_per_line;
    int		bytes_per_pixel;
    uint8	*output_screen;
    uint32	output_pitch;
    uint8	*interpolated_screen;
    uint8	*delta_screen;
    Colormap	cmap;
    Cursor	point_cursor;
    Cursor	cross_hair_cursor;
    XColor	colors [256];
    bool8	pseudo;
    bool8	grayscale;
    uint8	interpolate;
    bool8	image_needs_scaling;
    bool8	scale;
    int		depth;
    int		window_width;
    int		window_height;
    int		last_snes_width;
    int		last_snes_height;
    uint32	red_shift;
    uint32	blue_shift;
    uint32	green_shift;
    uint32	red_size;
    uint32	green_size;
    uint32	blue_size;
    int		mouse_x;
    int		mouse_y;
    uint32	mouse_buttons;
    bool8	mod1_pressed;
    bool8	superscope;
    uint32	superscope_turbo;
    uint32	superscope_pause;
    XRectangle  box;
    XRectangle  old_box;

    XColor	fixed_colours [256];
    uint8	palette [0x10000];
    char	info_string [256];
    void	*to_free [6];
#ifdef MITSHM
    XShmSegmentInfo sm_info;
    int		use_shared_memory;
#endif
#ifdef USE_OPENGL
    GLXContext  glcontext;
#endif
} GUIData;

extern GUIData GUI;
#endif

