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
#ifdef __linux
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/io.h>
#include <stdlib.h>
#include <signal.h>

#include <vga.h>
#include <vgagl.h>
#include <vgakeyboard.h>

#include "snes9x.h"
#include "memmap.h"
#include "debug.h"
#include "ppu.h"
#include "snapshot.h"
#include "gfx.h"
#include "display.h"
#include "apu.h"

#define COUNT(a) (sizeof(a) / sizeof(a[0]))

static bool8 planar;
static int screen_pitch;
static int screen_width;
static int screen_height;
static int mode = -1;
static bool8 stretch = FALSE;
static bool8 text_mode = TRUE;
static bool8 interpolation = FALSE;
static char prev_keystate [128] = "";
static bool8 restore_modex = FALSE;
static uint8 *DeltaScreen = NULL;
static vga_modeinfo *info = NULL;
static uint32 video_page_size = 64 * 1024;
static uint32 selected_video_page = ~0;

uint8 snes9x_clear_change_log = 0;

extern uint32 joypads [5];

#define ATTRCON_ADDR	0x3c0
#define MISC_ADDR	0x3c2
#define VGAENABLE_ADDR	0x3c3
#define SEQ_ADDR	0x3c4
#define GRACON_ADDR	0x3ce
#define CRTC_ADDR	0x3d4
#define STATUS_ADDR	0x3da

typedef struct
{
    unsigned port;
    unsigned char index;
    unsigned char value;
} Register;

typedef Register *RegisterPtr;
void outRegArray (Register *r, int n);

Register scr256x256[] =
{
     { 0x3c2, 0x00, 0xe3},{ 0x3d4, 0x00, 0x5f},{ 0x3d4, 0x01, 0x3f},
     { 0x3d4, 0x02, 0x40},{ 0x3d4, 0x03, 0x82},{ 0x3d4, 0x04, 0x4A},
     { 0x3d4, 0x05, 0x9A},{ 0x3d4, 0x06, 0x23},{ 0x3d4, 0x07, 0xb2},
     { 0x3d4, 0x08, 0x00},{ 0x3d4, 0x09, 0x61},{ 0x3d4, 0x10, 0x0a},
     { 0x3d4, 0x11, 0xac},{ 0x3d4, 0x12, 0xff},{ 0x3d4, 0x13, 0x20},
     { 0x3d4, 0x14, 0x40},{ 0x3d4, 0x15, 0x07},{ 0x3d4, 0x16, 0x1a},
     { 0x3d4, 0x17, 0xa3},{ 0x3c4, 0x01, 0x01},{ 0x3c4, 0x04, 0x0e},
     { 0x3ce, 0x05, 0x40},{ 0x3ce, 0x06, 0x05},{ 0x3c0, 0x10, 0x41},
     { 0x3c0, 0x13, 0x00}
};

typedef struct
{
    int width;
    int height;
    int mode;
} Mode;

static Mode modes [] = {
    {320, 240, G320x240x256}, // 0
    {320, 200, G320x200x256}, // 1
    {256, 256, G320x200x256}, // 2
    {640, 480, G640x480x256}, // 3
    {800, 600, G800x600x256}, // 4
    {320, 200, G320x200x64K}, // 5
    {640, 480, G640x480x64K}, // 6
    {800, 600, G800x600x64K}, // 7
};

int S9xMinCommandLineArgs ()
{
    return (2);
}

void S9xGraphicsMode ()
{
    if (text_mode)
    {
	screen_width = modes [mode].width;
	screen_height = modes [mode].height;
	int ret = vga_setmode (modes [mode].mode);

	if (ret < 0)
	{
	    fprintf (stderr, "Unable to switch to requested screen mode/resolution:\n");
	    S9xExit ();
	}

	if (vga_setlinearaddressing () < 0)
	{
	    if (info->flags & EXT_INFO_AVAILABLE)
		video_page_size = info->aperture_size;
	    else
		video_page_size = 64 * 1024;
	}
	else
	    video_page_size = ~0;

	if (modes [mode].mode == G320x200x256 && screen_width == 256)
	{
	    iopl(3);
	    outRegArray (scr256x256, sizeof (scr256x256) / sizeof (Register));
	    screen_pitch = screen_width;
	}
    
	gl_setcontextvga (modes [mode].mode);
	if (keyboard_init ())
	{
	    fprintf (stdout, "Keyboard initialisation failed.\n");
	    S9xExit ();
	}
	text_mode = FALSE;
	if (DeltaScreen)
	    memset (DeltaScreen, 0xff, GFX.Pitch * IMAGE_HEIGHT);
    }
}

void S9xTextMode ()
{
//    if (!text_mode)
    {
	keyboard_close ();
	vga_setmode (TEXT);
	text_mode = TRUE;
    }
}

static struct sigaction sig1handler;
static struct sigaction oldsig1handler;
static struct sigaction sig2handler;
static struct sigaction oldsig2handler;

void Sig1HandlerFunction(int)
{
    extern void StopTimer ();
    StopTimer ();

    sigaction(SIGUSR2, &sig2handler, NULL);
    sigaction(SIGUSR1, &oldsig1handler, NULL);
    sigsetmask (0);
    raise(SIGUSR1);
}

void Sig2HandlerFunction(int)
{
    restore_modex = TRUE;

    sigaction(SIGUSR1, &sig1handler, NULL);
    sigaction(SIGUSR2, &oldsig2handler, NULL);
    sigsetmask (0);
    raise(SIGUSR2);
}

void S9xInitDisplay (int /*argc*/, char ** /*argv*/)
{
    if (vga_init() < 0)
    {
	fprintf (stdout, "Unable to initialise vga.\n");
	S9xExit ();
    }
    S9xTextMode ();

    if (mode < 0)
    {
	if (Settings.SixteenBit)
	    mode = 6;
	else
	    mode = 2;
    }
    info = vga_getmodeinfo (modes [mode].mode);
    if (info->flags & IS_MODEX)
	planar = 1;

    if (info->flags & CAPABLE_LINEAR)
	video_page_size = ~0;
    else
    if (info->flags & EXT_INFO_AVAILABLE)
	video_page_size = info->aperture_size;
    else
	video_page_size = 64 * 1024;

    if (!screen_pitch)
	screen_pitch = info->linewidth;
	
    if (info->bytesperpixel > 1)
    {
	Settings.Transparency = TRUE;
	Settings.SixteenBit = TRUE;
    }
    else
    {
	Settings.Transparency = FALSE;
	Settings.SixteenBit = FALSE;
    }

    if (info->width >= 512 && info->height >= 578)
	Settings.SupportHiRes = TRUE;

    if (!Settings.SixteenBit || info->width < 512 || info->height < 240)
	interpolation = FALSE;

    if (interpolation)
    {
	GFX.Pitch = (IMAGE_WIDTH + 2) * 2;
	GFX.Screen = (uint8 *) malloc (GFX.Pitch * IMAGE_HEIGHT);
	GFX.SubScreen = (uint8 *) malloc (GFX.Pitch * IMAGE_HEIGHT);
	DeltaScreen = (uint8 *) malloc (GFX.Pitch * IMAGE_HEIGHT);
	GFX.ZBuffer = (uint8 *) malloc ((GFX.Pitch >> 1) * IMAGE_HEIGHT);
	GFX.SubZBuffer = (uint8 *) malloc ((GFX.Pitch >> 1) * IMAGE_HEIGHT);

	if (!GFX.Screen || !GFX.SubScreen || !DeltaScreen || 
	    !GFX.ZBuffer || !GFX.SubZBuffer)
	{
	    fprintf (stdout, "Cannot allocate screen buffer.\n");
	    S9xExit ();
	}
    }
    else
    if (Settings.SixteenBit)
    {
	GFX.Pitch = IMAGE_WIDTH * 2;
	GFX.Screen = (uint8 *) malloc (GFX.Pitch * IMAGE_HEIGHT);
	GFX.SubScreen = (uint8 *) malloc (GFX.Pitch * IMAGE_HEIGHT);
	GFX.ZBuffer = (uint8 *) malloc ((GFX.Pitch >> 1) * IMAGE_HEIGHT);
	GFX.SubZBuffer = (uint8 *) malloc ((GFX.Pitch >> 1) * IMAGE_HEIGHT);

	if (!GFX.Screen || !GFX.SubScreen)
	{
	    fprintf (stdout, "Cannot allocate screen buffer.\n");
	    S9xExit ();
	}
    }
    else
    {
	GFX.Pitch = IMAGE_WIDTH;
	GFX.Screen = (uint8 *) malloc (GFX.Pitch * IMAGE_HEIGHT);
	if (!GFX.Screen)
	{
	    fprintf (stdout, "Cannot allocate screen buffer.\n");
	    S9xExit ();
	}
	GFX.SubScreen = NULL;
	DeltaScreen = (uint8 *) malloc (GFX.Pitch * IMAGE_HEIGHT);
	if (!DeltaScreen)
	{
	    fprintf (stdout, "Cannot allocate shadow screen buffer.\n");
	    S9xExit ();
        }
	GFX.ZBuffer = (uint8 *) malloc (GFX.Pitch * IMAGE_HEIGHT);
	GFX.SubZBuffer = NULL;
    }
    ZeroMemory (GFX.Screen, GFX.Pitch * IMAGE_HEIGHT);
    if (GFX.SubScreen)
	ZeroMemory (GFX.SubScreen, GFX.Pitch * IMAGE_HEIGHT);
    if (DeltaScreen)
	ZeroMemory (DeltaScreen, GFX.Pitch * IMAGE_HEIGHT);

    sig1handler.sa_handler = Sig1HandlerFunction;
    sigemptyset (&sig1handler.sa_mask);
    sig1handler.sa_flags = 0;
    sig2handler.sa_handler = Sig2HandlerFunction;
    sigemptyset (&sig2handler.sa_mask);
    sig2handler.sa_flags = 0;
    sigaction (SIGUSR1, &sig1handler, &oldsig1handler);
    sigaction (SIGUSR2, &sig2handler, &oldsig2handler);
}

void S9xDeinitDisplay ()
{
    S9xTextMode ();
    if (GFX.Screen)
	free ((char *) GFX.Screen);
    if (GFX.SubScreen)
	free ((char *) GFX.SubScreen);
    if (DeltaScreen)
	free ((char *) DeltaScreen);
    if (GFX.ZBuffer)
	free ((char *) GFX.ZBuffer);
    if (GFX.SubZBuffer)
	free ((char *) GFX.SubZBuffer);
    GFX.Screen = NULL;
    GFX.SubScreen = NULL;
    DeltaScreen = NULL;
    GFX.ZBuffer = NULL;
    GFX.SubZBuffer = NULL;
}

void S9xSetPalette ()
{
    uint16 Brightness = IPPU.MaxBrightness * 138;
    for (int i = 0; i < 256; i++)
	vga_setpalette (i, 
			(((PPU.CGDATA [i] >> 0) & 0x1F) * Brightness) >> 10,
			(((PPU.CGDATA [i] >> 5) & 0x1F) * Brightness) >> 10,
			(((PPU.CGDATA [i] >> 10) & 0x1F) * Brightness) >> 10);
}

void S9xProcessEvents (bool8 block)
{
    int fn = -1;

    if (restore_modex)
    {
	restore_modex = FALSE;

	ZeroMemory (prev_keystate, 128);
	if (!text_mode && modes [mode].mode == G320x200x256 && screen_width == 256)
	{
	    iopl(3);
	    outRegArray (scr256x256, sizeof (scr256x256) / sizeof (Register));
	}
	extern void InitTimer ();
	InitTimer ();
    }
    if (block)
    {
//	keyboard_waitforupdate ();
	usleep (10000);
	keyboard_update ();
    }
    else
	keyboard_update ();
    char *keystate = keyboard_getstate ();
    
#define KEY_DOWN(a) (keystate[a])
#define KEY_PRESS(a) (keystate[a] && !prev_keystate[a])
#define KEY_WASPRESSED(a) (prev_keystate[a] && !keystate[a])
#define PROCESS_KEY(k, b, v)\
if (KEY_PRESS(k)) b |= v;\
if (KEY_WASPRESSED(k)) b &= ~v;

    if (KEY_PRESS (SCANCODE_ESCAPE))
	S9xExit ();

    // Joypad 1:
    PROCESS_KEY(SCANCODE_K,		    joypads [0], SNES_RIGHT_MASK)
    PROCESS_KEY(SCANCODE_CURSORBLOCKRIGHT,  joypads [0], SNES_RIGHT_MASK)
    PROCESS_KEY(SCANCODE_H,		    joypads [0], SNES_LEFT_MASK)
    PROCESS_KEY(SCANCODE_CURSORBLOCKLEFT,   joypads [0], SNES_LEFT_MASK)
    PROCESS_KEY(SCANCODE_N,		    joypads [0], SNES_DOWN_MASK)
    PROCESS_KEY(SCANCODE_J,		    joypads [0], SNES_DOWN_MASK)
    PROCESS_KEY(SCANCODE_CURSORBLOCKDOWN,   joypads [0], SNES_DOWN_MASK)
    PROCESS_KEY(SCANCODE_U,		    joypads [0], SNES_UP_MASK)
    PROCESS_KEY(SCANCODE_CURSORBLOCKUP,	    joypads [0], SNES_UP_MASK)
    PROCESS_KEY(SCANCODE_ENTER,		    joypads [0], SNES_START_MASK)
    PROCESS_KEY(SCANCODE_SPACE,		    joypads [0], SNES_SELECT_MASK)

    PROCESS_KEY(SCANCODE_A,		    joypads [0], SNES_TL_MASK)
    PROCESS_KEY(SCANCODE_V,		    joypads [0], SNES_TL_MASK)
    PROCESS_KEY(SCANCODE_Q,		    joypads [0], SNES_TL_MASK)

    PROCESS_KEY(SCANCODE_Z,		    joypads [0], SNES_TR_MASK)
    PROCESS_KEY(SCANCODE_B,		    joypads [0], SNES_TR_MASK)
    PROCESS_KEY(SCANCODE_W,		    joypads [0], SNES_TR_MASK)

    PROCESS_KEY(SCANCODE_S,		    joypads [0], SNES_X_MASK)
    PROCESS_KEY(SCANCODE_M,		    joypads [0], SNES_X_MASK)
    PROCESS_KEY(SCANCODE_E,		    joypads [0], SNES_X_MASK)

    PROCESS_KEY(SCANCODE_X,		    joypads [0], SNES_Y_MASK)
    PROCESS_KEY(SCANCODE_COMMA,		    joypads [0], SNES_Y_MASK)
    PROCESS_KEY(SCANCODE_R,		    joypads [0], SNES_Y_MASK)

    PROCESS_KEY(SCANCODE_D,		    joypads [0], SNES_A_MASK)
    PROCESS_KEY(SCANCODE_PERIOD,	    joypads [0], SNES_A_MASK)
    PROCESS_KEY(SCANCODE_T,		    joypads [0], SNES_A_MASK)

    PROCESS_KEY(SCANCODE_C,		    joypads [0], SNES_B_MASK)
    PROCESS_KEY(SCANCODE_SLASH,		    joypads [0], SNES_B_MASK)
    PROCESS_KEY(SCANCODE_Y,		    joypads [0], SNES_B_MASK)
    
    // Joypad 2:
    PROCESS_KEY(SCANCODE_CURSORRIGHT,	    joypads [1], SNES_RIGHT_MASK)
    PROCESS_KEY(SCANCODE_CURSORLEFT,	    joypads [1], SNES_LEFT_MASK)
    PROCESS_KEY(SCANCODE_CURSORDOWN,	    joypads [1], SNES_DOWN_MASK)
    PROCESS_KEY(SCANCODE_CURSORUP,	    joypads [1], SNES_UP_MASK)
    PROCESS_KEY(SCANCODE_KEYPADENTER,	    joypads [1], SNES_START_MASK)
    PROCESS_KEY(SCANCODE_KEYPADPLUS,	    joypads [1], SNES_SELECT_MASK)
    PROCESS_KEY(SCANCODE_INSERT,	    joypads [1], SNES_TL_MASK)
    PROCESS_KEY(SCANCODE_REMOVE,	    joypads [1], SNES_TR_MASK)
    PROCESS_KEY(SCANCODE_HOME,		    joypads [1], SNES_X_MASK)
    PROCESS_KEY(SCANCODE_END,		    joypads [1], SNES_Y_MASK)
    PROCESS_KEY(SCANCODE_PAGEUP,	    joypads [1], SNES_A_MASK)
    PROCESS_KEY(SCANCODE_PAGEDOWN,	    joypads [1], SNES_B_MASK)
    
    if (KEY_PRESS (SCANCODE_1))
	PPU.BG_Forced ^= 1;
    if (KEY_PRESS (SCANCODE_2))
	PPU.BG_Forced ^= 2;
    if (KEY_PRESS (SCANCODE_3))
	PPU.BG_Forced ^= 4;
    if (KEY_PRESS (SCANCODE_4))
	PPU.BG_Forced ^= 8;
    if (KEY_PRESS (SCANCODE_5))
	PPU.BG_Forced ^= 16;
    if (KEY_PRESS (SCANCODE_0))
	Settings.DisableHDMA = !Settings.DisableHDMA;
    if (KEY_PRESS (SCANCODE_8))
	Settings.BGLayering = !Settings.BGLayering;
    if (KEY_PRESS (SCANCODE_6))
	Settings.SwapJoypads = !Settings.SwapJoypads;
    if (KEY_PRESS (SCANCODE_BACKSPACE))
	Settings.DisableGraphicWindows = !Settings.DisableGraphicWindows;
    if (KEY_PRESS(SCANCODE_F1))
	fn = 1;
    if (KEY_PRESS(SCANCODE_F2))
	fn = 2;
    if (KEY_PRESS(SCANCODE_F3))
	fn = 3;
    if (KEY_PRESS(SCANCODE_F4))
	fn = 4;
    if (KEY_PRESS(SCANCODE_F5))
	fn = 5;
    if (KEY_PRESS(SCANCODE_F6))
	fn = 6;
    if (KEY_PRESS(SCANCODE_F7))
	fn = 7;
    if (KEY_PRESS(SCANCODE_F8))
	fn = 8;
    if (KEY_PRESS(SCANCODE_F9))
	fn = 9;
    if (KEY_PRESS(SCANCODE_F10))
	fn = 10;
    if (KEY_PRESS(SCANCODE_F11))
	fn = 11;
    if (KEY_PRESS(SCANCODE_F12))
	fn = 12;
	
    if (fn > 0)
    {
	if (!KEY_DOWN(SCANCODE_LEFTALT) && !KEY_DOWN(SCANCODE_LEFTSHIFT) &&
	    !KEY_DOWN(SCANCODE_CONTROL) && !KEY_DOWN(SCANCODE_LEFTCONTROL))
	{
	    if (fn == 11)
	    {
		S9xLoadSnapshot (S9xChooseFilename (TRUE));
	    }
	    else if (fn == 12)
	    {
		Snapshot (S9xChooseFilename (FALSE));
	    }
	    else
	    {
		char def [PATH_MAX];
		char filename [PATH_MAX];
		char drive [_MAX_DRIVE];
		char dir [_MAX_DIR];
		char ext [_MAX_EXT];

		_splitpath (Memory.ROMFilename, drive, dir, def, ext);
		sprintf (filename, "%s%s%s.%03d",
			 S9xGetSnapshotDirectory (), SLASH_STR, def,
			 fn - 1);
		S9xLoadSnapshot (filename);
	    }
	}
	else if (KEY_DOWN(SCANCODE_LEFTALT) || KEY_DOWN(SCANCODE_LEFTCONTROL) ||
		 KEY_DOWN(SCANCODE_CONTROL))
	{
	    if (fn >= 4)
		S9xToggleSoundChannel (fn - 4);
#ifdef DEBUGGER
	    else if (fn == 1)
		CPU.Flags |= DEBUG_MODE_FLAG;
#endif
	    else if (fn == 2)
		S9xLoadSnapshot (S9xChooseFilename (TRUE));
	    else if (fn == 3)
		Snapshot (S9xChooseFilename (FALSE));
	}
	else
	{
	    char def [PATH_MAX];
	    char filename [PATH_MAX];
	    char drive [_MAX_DRIVE];
	    char dir [_MAX_DIR];
	    char ext [_MAX_EXT];

	    _splitpath (Memory.ROMFilename, drive, dir, def, ext);
	    sprintf (filename, "%s%s%s.%03d",
		     S9xGetSnapshotDirectory (), SLASH_STR, def,
		     fn - 1);
	    Snapshot (filename);
	}
    }
    if (KEY_PRESS (SCANCODE_BREAK) || KEY_PRESS (SCANCODE_BREAK_ALTERNATIVE) ||
	KEY_PRESS (SCANCODE_SCROLLLOCK))
	Settings.Paused ^= 1;

    if (KEY_PRESS (SCANCODE_MINUS))
    {
	if (KEY_PRESS(SCANCODE_LEFTSHIFT) || KEY_PRESS(SCANCODE_RIGHTSHIFT))
	{
	    if (Settings.FrameTime >= 1000)
		Settings.FrameTime -= 1000;
	}
	else
	{
	    if (Settings.SkipFrames <= 1)
		Settings.SkipFrames = AUTO_FRAMERATE;
	    else
	    if (Settings.SkipFrames != AUTO_FRAMERATE)
		Settings.SkipFrames--;
	}
    }

    if (KEY_PRESS (SCANCODE_EQUAL))
    {
	if (KEY_PRESS(SCANCODE_LEFTSHIFT) || KEY_PRESS(SCANCODE_RIGHTSHIFT))
	    Settings.FrameTime += 1000;
	else
	{
	    if (Settings.SkipFrames == AUTO_FRAMERATE)
		Settings.SkipFrames = 1;
	    else
	    if (Settings.SkipFrames < 10)
		Settings.SkipFrames++;
	}
    }
	
    memcpy (prev_keystate, keystate, sizeof (prev_keystate));
}

void S9xSetTitle (const char * /*title*/)
{
}

void S9xPutImage (int width, int height)
{
    int y_buff;
    int y_start;
    int y_end;
    int x_start = (screen_width - width) >> 1;
    if (screen_height >= height)
    {
	y_start = (screen_height - height) >> 1;
	y_end = y_start + height;
	y_buff = 0;
    }
    else
    {
	y_start = 0;
	y_end = screen_height;
	y_buff = (height - screen_height) >> 1;
    }
	
    if (planar)
	vga_copytoplanar256 (GFX.Screen + y_buff * GFX.Pitch,
			     IMAGE_WIDTH,
			     y_start * screen_pitch + x_start / 4,
			     screen_pitch, width, y_end - y_start);
    else
    {
	if (screen_pitch == width && screen_height >= height)
	{
#if 0
	    memcpy (vga_getgraphmem () + screen_pitch * y_start,
		    GFX.Screen, width * height);
#else
	    register uint32 *s = (uint32 *) (vga_getgraphmem () + screen_pitch * y_start);
	    register uint32 *o = (uint32 *) DeltaScreen;
	    register uint32 *n = (uint32 *) GFX.Screen;
	    uint32 *end = (uint32 *) (GFX.Screen + width * height);
	    do
	    {
		if (*n != *o)
		    *o = *s = *n;

		o++;
		s++;
		n++;
	    } while (n < end);
#endif
	}
	else
	{
	    if (stretch && screen_width != width)
	    {
		register uint32 x_error;
		register uint32 x_fraction;
		uint32 y_error = 0;
		uint32 y_fraction;
		int yy = 0;
		
		x_fraction = (SNES_WIDTH * 0x10000) / width;
		y_fraction = (SNES_HEIGHT_EXTENDED * 0x10000) / height;
		
		for (int y = 0; y < height; y++)
		{
		    register uint8 *d = (uint8 *) vga_getgraphmem () + y * screen_pitch;
		    register uint8 *s = GFX.Screen + yy * GFX.Pitch;
		    y_error += y_fraction;
		    while (y_error >= 0x10000)
		    {
			yy++;
			y_error -= 0x10000;
		    }
		    x_error = 0;
		    for (register int x = 0; x < width; x++)
		    {
			*d++ = *s;
			x_error += x_fraction;

			while (x_error >= 0x10000)
			{
			    s++;
			    x_error -= 0x10000;
			}
		    }
		}
	    }
	    else
	    {
#if 0
		uint8 *s = GFX.Screen + GFX.Pitch * y_buff;
		uint8 *p = vga_getgraphmem () + screen_pitch * y_start +
			  x_start;
		for (int y = y_start; y < y_end; y++, s += GFX.Pitch, p += screen_pitch)
		    memcpy (p, s, width);
#else
		gl_putbox (0, 0, width * 2, height * 2, GFX.Screen);
#endif
	    }
	}
    }
}

const char *S9xSelectFilename (const char *def, const char *dir1,
			    const char *ext1, const char *title)
{
    static char path [PATH_MAX];
    char buffer [PATH_MAX];
    
    S9xTextMode ();
    printf ("\n%s (default: %s): ", title, def);
    fflush (stdout);
    if (fgets (buffer, sizeof (buffer) - 1, stdin))
    {
	char *p = buffer;
	while (isspace (*p) || *p == '\n')
	    p++;
	if (!*p)
	{
	    strcpy (buffer, def);
	    p = buffer;
	}

	char *q = strrchr (p, '\n');
	if (q)
	    *q = 0;

	char fname [PATH_MAX];
	char drive [_MAX_DRIVE];
	char dir [_MAX_DIR];
	char ext [_MAX_EXT];

	_splitpath (p, drive, dir, fname, ext);
	_makepath (path, drive, *dir ? dir : dir1, fname, *ext ? ext : ext1);
	S9xGraphicsMode ();
	return (path);
    }
    S9xGraphicsMode ();
    return (NULL);
}

void outReg(Register r)
{
    switch (r.port)
    {
	/* First handle special cases: */

	case ATTRCON_ADDR:
	    /* reset read/write flip-flop */
	    inb (STATUS_ADDR);
	    /* ensure VGA output is enabled */
	    outb (r.index | 0x20, ATTRCON_ADDR);
	    outb (r.value, ATTRCON_ADDR);
	    break;

	case MISC_ADDR:
	case VGAENABLE_ADDR:
	    /*	directly to the port */
	    outb (r.value, r.port);
	    break;

	case SEQ_ADDR:
	case GRACON_ADDR:
	case CRTC_ADDR:
	default:
	    /*	index to port			   */
	    outb (r.index, r.port);
	    /*	value to port+1 		   */
	    outb (r.value, r.port + 1);
	    break;
    }
}

/*
    readyVgaRegs() does the initialization to make the VGA ready to
    accept any combination of configuration register settings.

    This involves enabling writes to index 0 to 7 of the CRT controller
    (port 0x3d4), by clearing the most significant bit (bit 7) of index
    0x11.
*/

void readyVgaRegs (void)
{
    int v;

    outb (0x11, 0x3d4);
    v = inb (0x3d5) & 0x7f;
    outb (0x11, 0x3d4);
    outb (v, 0x3d5);
}
/*
	outRegArray sets n registers according to the array pointed to by r.
	First, indexes 0-7 of the CRT controller are enabled for writing.
*/

void outRegArray (Register *r, int n)
{
    readyVgaRegs ();
    while (n--)
	outReg (*r++);
}

void S9xParseDisplayArg (char **argv, int &ind, int)
{
    if ((strcmp (argv [ind], "-m") == 0 ||
	 strcasecmp (argv [ind], "-mode") == 0) && argv [ind + 1])
    {
	mode = atoi (argv [++ind]);
	if (mode >= (int) (sizeof (modes) / sizeof (modes [0])))
	    mode = 0;
    }
    else
    if (strcasecmp (argv [ind], "-scale") == 0 ||
	strcasecmp (argv [ind], "-sc") == 0)
	stretch = TRUE;
    else
    if (strcasecmp (argv [ind], "-y") == 0 ||
	strcasecmp (argv [ind], "-interpolation") == 0)
    {
	interpolation = TRUE;
	Settings.SixteenBit = TRUE;
	Settings.SupportHiRes = TRUE;
	Settings.Transparency = TRUE;
    }
    else
	S9xUsage ();
}

void S9xExtraUsage ()
{
    printf ("\
-m  num     Screen mode:\n\
            0 - 320x240 (modex, slower), 1 - 320x200 (faster but clipped)\n\
            2 - 256x256 (faster but non-standard), 3 - 640x480, 4 - 800x600\n");
    printf ("\
-scale      Scale SNES screen to fit S-VGA screen\n");
}

bool8 S9xReadMousePosition (int /* which1 */, int &/* x */, int & /* y */,
			    uint32 & /* buttons */)
{
    return (FALSE);
}

bool8 S9xReadSuperScopePosition (int & /* x */, int & /* y */, 
				 uint32 & /* buttons */)
{
    return (FALSE);
}

void S9xMessage (int /* type */, int /* number */, const char *message)
{
    fprintf (stderr, "%s\n", message);
}
#endif

