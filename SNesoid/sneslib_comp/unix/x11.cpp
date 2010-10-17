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
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#ifdef HAVE_STRINGS_H
#include <strings.h>
#endif
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

#include "snes9x.h"
#include "memmap.h"
#include "debug.h"
#include "ppu.h"
#include "snapshot.h"
#include "gfx.h"
#include "display.h"
#include "apu.h"
#include "soundux.h"
#include "x11.h"
#include "spc7110.h"

#if 0
#define QT_CLEAN_NAMESPACE
#include <qapplication.h>
#include "snes9x_gui.h"
#endif

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <X11/cursorfont.h>

#ifdef USE_GLIDE
bool8 S9xGlideEnable (bool8);
void S9xGlidePutImage (int, int);
void S9xSwitchToGlideMode (bool8);
#endif

#ifdef USE_AIDO
#include "aido.h"
#endif

#ifdef __linux
// Select seems to be broken in 2.x.x kernels - if a signal interrupts a
// select system call with a zero timeout, the select call is restarted but
// with an infinite timeout! The call will block until data arrives on the
// selected fd(s).
//
// The workaround is to stop the X library calling select in the first
// place! Replace XPending - which polls for data from the X server using 
// select - with an ioctl call to poll for data and then only call the blocking
// XNextEvent if data is waiting.

#define SELECT_BROKEN_FOR_SIGNALS
#endif

#ifdef USE_DGA_EXTENSION
#include <X11/extensions/xf86dga.h>

void CreateFullScreenWindow ();
void S9xSwitchToFullScreen (bool8 enable);

#ifdef USE_VIDMODE_EXTENSION
#if defined (__cplusplus) || defined (c_plusplus)
#include <X11/extensions/xf86vmode.h>
#endif

#define ALL_DEVICE_EVENTS 0
#endif

typedef struct 
{
    bool8		full_screen_available;
    bool8		is_full_screen;
    bool8		scale;
    char		*vram;
    int			line_width;
    int			bank_size;
    int			size;
    int			window_width;
    int			window_height;
    int			saved_window_width;
    int			saved_window_height;
    bool8		saved_image_needs_scaling;
    Window		fs_window;

#ifdef USE_VIDMODE_EXTENSION
    bool8		switch_video_mode;
    XF86VidModeModeInfo	**all_modes;
    int			num_modes;
    XF86VidModeModeInfo orig;
    XF86VidModeModeInfo *best;
    bool8		no_mode_switch;
    bool8		start_full_screen;
#endif
} XF86Data;

static XF86Data XF86;
#endif

GUIData GUI;
extern uint32 joypads [5];

#if 0
QApplication *app;
Snes9xGUI *gui;
#endif

void Scale8 (int width, int height);
void Scale16 (int width, int height);
void Convert8To16 (int width, int height);
void Convert16To8 (int width, int height);
void Convert8To24 (int width, int height);
void Convert8To24Packed (int width, int height);
void Convert16To24 (int width, int height);
void Convert16To24Packed (int width, int height);
void SetupImage ();
int ErrorHandler (Display *, XErrorEvent *);
void TVMode (int width, int height);
void S9xDisplayStateChange (const char *str, bool8 on);

void Init_2xSaI (uint32);
void Super2xSaI (uint8 *srcPtr, uint32 srcPitch,
		 uint8 *deltaPtr, uint8 *dstPtr, uint32 dstPitch,
		 int width, int height);
void SuperEagle (uint8 *srcPtr, uint32 srcPitch, uint8 *deltaPtr, 
		 uint8 *dstPtr, uint32 dstPitch, int width, int height);
void _2xSaI (uint8 *srcPtr, uint32 srcPitch, uint8 *deltaPtr, 
	     uint8 *dstPtr, uint32 dstPitch, int width, int height);
void Scale_2xSaI (uint8 *srcPtr, uint32 srcPitch, uint8 * /* deltaPtr */,
		  uint8 *dstPtr, uint32 dstPitch, 
		  uint32 dstWidth, uint32 dstHeight, int width, int height);

START_EXTERN_C
uint8 snes9x_clear_change_log = 0;
END_EXTERN_C

void S9xDeinitDisplay ()
{
#ifdef USE_GLIDE
    S9xGlideEnable (FALSE);
#elif USE_AIDO
    if (Settings.AIDOShmId)
        return;
#endif

    S9xTextMode ();
    uint32 i;

    for (i = 0; i < sizeof (GUI.to_free) / sizeof (GUI.to_free [0]); i++)
	if (GUI.to_free [i])
	{
	    free (GUI.to_free [i]);
	    GUI.to_free [i] = NULL;
	}

    if (GUI.image)
    {
#ifdef MITSHM
	if (GUI.use_shared_memory)
	{
	    XShmDetach (GUI.display, &GUI.sm_info);
	    GUI.image->data = NULL;
	    XDestroyImage (GUI.image);
	    if (GUI.sm_info.shmaddr)
		shmdt (GUI.sm_info.shmaddr);
	    if (GUI.sm_info.shmid >= 0)
		shmctl (GUI.sm_info.shmid, IPC_RMID, 0);
	    GUI.image = NULL;
        }
	else
#endif
	{
	    XDestroyImage (GUI.image);
	    GUI.image = NULL;
	}
    }
    XSync (GUI.display, False);
    XCloseDisplay (GUI.display);
}

void S9xInitDisplay (int, char **)
{
#ifdef USE_AIDO
    if (Settings.AIDOShmId)
    {
        S9xAIDOInit ();
        return;
    }
#endif

    if (!(GUI.display = XOpenDisplay (NULL)))
    {
	fprintf (stderr, "Failed to connect to X server.\n");
	exit (1);
    }
    GUI.screen = DefaultScreenOfDisplay (GUI.display);
    GUI.screen_num = XScreenNumberOfScreen (GUI.screen);
    GUI.visual = DefaultVisualOfScreen (GUI.screen);
    GUI.window_width = IMAGE_WIDTH;
    GUI.window_height = IMAGE_HEIGHT;

#ifdef USE_OPENGL
    // XXX:
    Settings.OpenGLEnable = TRUE;

    if (Settings.OpenGLEnable)
	S9xOpenGLInit ();
#endif

    XVisualInfo plate;
    XVisualInfo *matches;
    int count;

    plate.visualid = XVisualIDFromVisual (GUI.visual);
    matches = XGetVisualInfo (GUI.display, VisualIDMask, &plate, &count);

    if (!count)
    {
	fprintf (stderr, "Your X Window System server is unwell!\n");
	exit (1);
    }
    GUI.depth = matches[0].depth;
    if ((GUI.depth != 8 && GUI.depth != 15 && GUI.depth != 16 && GUI.depth != 24) ||
	(matches[0].c_class != PseudoColor && matches[0].c_class != TrueColor &&
	 matches[0].c_class != GrayScale))
    {
	fprintf (stderr, "\
Snes9x needs an X Window System server set to 8, 15, 16, 24 or 32-bit colour GUI.depth\n\
supporting PseudoColor, TrueColor or GrayScale.\n");
	exit (1);
    }

    if (GUI.depth >= 15 && !Settings.ForceNoTransparency)
    {
	Settings.Transparency = TRUE;
	Settings.SixteenBit = TRUE;
    }

    GUI.pseudo = matches[0].c_class == PseudoColor ||
	     matches[0].c_class == GrayScale;
    GUI.grayscale = matches[0].c_class == GrayScale;

    if (GUI.depth != 8 || !GUI.pseudo)
    {
	GUI.red_shift = ffs (matches[0].red_mask) - 1;
	GUI.green_shift = ffs (matches[0].green_mask) - 1;
	GUI.blue_shift = ffs (matches[0].blue_mask) - 1;
	GUI.red_size = matches[0].red_mask >> GUI.red_shift;
	GUI.green_size = matches[0].green_mask >> GUI.green_shift;
	GUI.blue_size = matches[0].blue_mask >> GUI.blue_shift;
	if (GUI.depth == 16 && GUI.green_size == 63)
	    GUI.green_shift++;

#ifdef GFX_MULTI_FORMAT
	switch (GUI.depth)
	{
	default:
	case 24:
	case 8:
	    S9xSetRenderPixelFormat (RGB565);
	    Init_2xSaI (565);
	    break;
	case 16:
	    if (GUI.red_size != GUI.green_size || GUI.blue_size != GUI.green_size)
	    {
		// 565 format
		if (GUI.green_shift > GUI.blue_shift && GUI.green_shift > GUI.red_shift)
		    S9xSetRenderPixelFormat (GBR565);
		else
		if (GUI.red_shift > GUI.blue_shift)
		    S9xSetRenderPixelFormat (RGB565);
		else
		    S9xSetRenderPixelFormat (BGR565);

		Init_2xSaI (565);
		break;
	    }
	    /* FALL ... */
	case 15:
	    if (GUI.green_shift > GUI.blue_shift && GUI.green_shift > GUI.red_shift)
		S9xSetRenderPixelFormat (GBR555);
	    else
	    if (GUI.red_shift > GUI.blue_shift)
		S9xSetRenderPixelFormat (RGB555);
	    else
		S9xSetRenderPixelFormat (BGR555);

	    Init_2xSaI (555);
	    break;
	}
#endif	
    }
    XFree ((char *) matches);

#if defined(USE_OPENGL) || defined(USE_AIDO)
    if (Settings.OpenGLEnable || Settings.AIDOShmId)
    {
	S9xSetRenderPixelFormat (RGB555);
        Settings.SixteenBit = TRUE;
        Settings.Transparency = TRUE;
    }
#endif

    int l = 0;
    int i;

    for (i = 0; i < 6; i++)
    {
	int r = (i * 31) / (6 - 1);
	for (int j = 0; j < 6; j++)
	{
	    int g = (j * 31) / (6 - 1);
	    for (int k = 0; k < 6; k++)
	    { 
		int b = (k * 31) / (6 - 1);

		GUI.fixed_colours [l].red = r;
		GUI.fixed_colours [l].green = g;
		GUI.fixed_colours [l++].blue = b;
	    }
	}
    }

    int *color_diff = new int [0x10000];
    int diffr, diffg, diffb, maxdiff = 0, won = 0, lost;
    int r, d = 8;
    for (r = 0; r <= (int) MAX_RED; r++)
    {
	int cr, g, q;
      
	int k = 6 - 1;
	cr = (r * k) / MAX_RED;
	q  = (r * k) % MAX_RED;
	if (q > d && cr < k) 
	    cr++;
	diffr = abs (cr * k - r);
	for (g = 0; g <= (int) MAX_GREEN; g++)
	{
	    int cg, b;
	  
	    k  = 6 - 1;
	    cg = (g * k) / MAX_GREEN;
	    q  = (g * k) % MAX_GREEN;
	    if(q > d && cg < k)
		cg++;
	    diffg = abs (cg * k - g);
	    for (b = 0; b <= (int) MAX_BLUE; b++) 
	    {
		int cb;
		int rgb = BUILD_PIXEL2(r, g, b);

		k  = 6 - 1;
		cb = (b * k) / MAX_BLUE;
		q  = (b * k) % MAX_BLUE;
		if (q > d && cb < k)
		    cb++;
		diffb = abs (cb * k - b);
		GUI.palette[rgb] = (cr * 6 + cg) * 6 + cb;
		color_diff[rgb] = diffr + diffg + diffb;
		if (color_diff[rgb] > maxdiff)
		    maxdiff = color_diff[rgb];
	    }
	}
    }

    while (maxdiff > 0 && l < 256)
    {
	int newmaxdiff = 0;
	lost = 0; won++;
	for (r = MAX_RED; r >= 0; r--)
	{
	    int g;
      
	    for (g = MAX_GREEN; g >= 0; g--)
	    {
		int b;
	  
		for (b = MAX_BLUE; b >= 0; b--) 
		{
		    int rgb = BUILD_PIXEL2(r, g, b);

		    if (color_diff[rgb] == maxdiff)
		    {
			if (l >= 256)
			    lost++;
			else
			{
			    GUI.fixed_colours [l].red = r;
			    GUI.fixed_colours [l].green = g;
			    GUI.fixed_colours [l].blue = b;
			    GUI.palette [rgb] = l;
			    l++;
			}
			color_diff[rgb] = 0;
		    }
		    else
			if (color_diff[rgb] > newmaxdiff)
			    newmaxdiff = color_diff[rgb];
		    
		}
	    }
	}
	maxdiff = newmaxdiff;
    }
    delete[] color_diff;

    XSetWindowAttributes attrib;

    attrib.background_pixel = BlackPixelOfScreen (GUI.screen);
    GUI.window = XCreateWindow (GUI.display, RootWindowOfScreen (GUI.screen),
				(WidthOfScreen(GUI.screen) - GUI.window_width) / 2,
				(HeightOfScreen(GUI.screen) - GUI.window_height) / 2,
				GUI.window_width, GUI.window_height, 0, 
				GUI.depth, InputOutput, GUI.visual, 
				CWBackPixel, &attrib);

#ifdef USE_DGA_EXTENSION
    CreateFullScreenWindow ();
#endif

    static XColor bg;
    static XColor fg;
    static char data [8] = { 0x01 };

    Pixmap bitmap = XCreateBitmapFromData (GUI.display, GUI.window, data, 8, 8);
    GUI.point_cursor = XCreatePixmapCursor (GUI.display, bitmap, bitmap, &fg, &bg, 0, 0);
    XDefineCursor (GUI.display, GUI.window, GUI.point_cursor);
#ifdef USE_DGA_EXTENSION
    if (XF86.full_screen_available)
	XDefineCursor (GUI.display, XF86.fs_window, GUI.point_cursor);
#endif

    GUI.cross_hair_cursor = XCreateFontCursor (GUI.display, XC_crosshair);
    GUI.gc = DefaultGCOfScreen (GUI.screen);
    {
        XSizeHints Hints;
	XWMHints WMHints;

	memset ((void *) &Hints, 0, sizeof (XSizeHints));
	memset ((void *) &WMHints, 0, sizeof (XWMHints));

	Hints.flags = PSize | PMinSize;
	Hints.min_width = Hints.base_width = SNES_WIDTH;
	Hints.min_height = Hints.base_height = SNES_HEIGHT_EXTENDED;
	WMHints.input = True;
	WMHints.flags = InputHint;
	XSetWMHints (GUI.display, GUI.window, &WMHints);
	XSetWMNormalHints (GUI.display, GUI.window, &Hints);
    }
    XSelectInput (GUI.display, GUI.window, FocusChangeMask | ExposureMask |
		  KeyPressMask | KeyReleaseMask | StructureNotifyMask |
		  ButtonPressMask | ButtonReleaseMask);
#ifdef USE_DGA_EXTENSION
    if (XF86.full_screen_available)
	XSelectInput (GUI.display, XF86.fs_window, FocusChangeMask | ExposureMask |
		      KeyPressMask | KeyReleaseMask | StructureNotifyMask |
		      ButtonPressMask | ButtonReleaseMask);
#endif

    if (GUI.pseudo)
    {
	GUI.cmap = XCreateColormap (GUI.display, GUI.window, GUI.visual, True);
	XSetWindowColormap (GUI.display, GUI.window, GUI.cmap);
	for (i = 0; i < 256; i++)
	{
	    GUI.colors[i].red = GUI.colors[i].green = GUI.colors[i].blue = 0;
	    GUI.colors[i].pixel = i;
	    GUI.colors[i].flags = DoRed | DoGreen | DoBlue;
	}
	XStoreColors (GUI.display, GUI.cmap, GUI.colors, 256);
    }
    XMapRaised (GUI.display, GUI.window);
    XClearWindow (GUI.display, GUI.window);
    SetupImage ();

    switch (GUI.depth)
    {
    case 8:
	GUI.bytes_per_pixel = 1;
	break;

    case 15:
    case 16:
	GUI.bytes_per_pixel = 2;
	break;

    case 24:
	if (GUI.image->bits_per_pixel == 24)
	    GUI.bytes_per_pixel = 3;
	else
	    GUI.bytes_per_pixel = 4;
	break;

    case 32:
	GUI.bytes_per_pixel = 4;
	break;
    }
#if 0
    app = new QApplication (GUI.display);
    gui = new Snes9xGUI ();
    app->setMainWidget (gui);
    gui->show ();
#endif

#ifdef USE_OPENGL
    if (Settings.OpenGLEnable)
	S9xOpenGLInit2 ();
#endif

#ifdef USE_GLIDE
    putenv("FX_GLIDE_NO_SPLASH=");
    S9xSwitchToGlideMode (TRUE);
#endif
}

void SetupImage ()
{
    int tf = 0;
    int image_width = GUI.window_width;
    int image_height = GUI.window_height;

    if (image_width < IMAGE_WIDTH)
	image_width = IMAGE_WIDTH;
    if (image_height < IMAGE_HEIGHT)
	image_height = IMAGE_HEIGHT;

    if (GUI.interpolate)
    {
	if (image_width < 512)
	    image_width = 512;
	if (image_height < 239 * 2)
	    image_height = 239 * 2;
	GUI.image_needs_scaling = (GUI.window_width != 512 || 
				   GUI.window_height != 239 * 2) &&
				   GUI.interpolate != 5;
    }
    else
    {
	GUI.image_needs_scaling = GUI.window_width != IMAGE_WIDTH ||
				  GUI.window_height != IMAGE_HEIGHT ||
				  GUI.scale
#ifdef USE_DGA_EXTENSION
				  || (XF86.is_full_screen && XF86.scale)
#endif
				  ;
    }

    uint32 i;

    for (i = 0; i < sizeof (GUI.to_free) / sizeof (GUI.to_free [0]); i++)
	if (GUI.to_free [i])
	{
	    free (GUI.to_free [i]);
	    GUI.to_free [i] = NULL;
	}

    if (GUI.image)
    {
#ifdef MITSHM
	if (GUI.use_shared_memory)
	{
	    XShmDetach (GUI.display, &GUI.sm_info);
	    GUI.image->data = NULL;
	    XDestroyImage (GUI.image);
	    if (GUI.sm_info.shmaddr)
		shmdt (GUI.sm_info.shmaddr);
	    if (GUI.sm_info.shmid >= 0)
		shmctl (GUI.sm_info.shmid, IPC_RMID, 0);
	    GUI.image = NULL;
        }
	else
#endif
	{
	    XDestroyImage (GUI.image);
	    GUI.image = NULL;
	}
    }

#ifdef MITSHM
    GUI.use_shared_memory = 1;

    int major, minor;
    Bool shared;
    if (!XShmQueryVersion (GUI.display, &major, &minor, &shared) || !shared)
	GUI.image = NULL;
    else
	GUI.image = XShmCreateImage (GUI.display, GUI.visual, GUI.depth, ZPixmap, NULL, &GUI.sm_info,
				     image_width, image_height);
    if (!GUI.image)
    {
	fprintf (stderr, "XShmCreateImage failed, switching to XPutImage\n");
	GUI.use_shared_memory = 0;
    }
    else
    {
	GUI.sm_info.shmid = shmget (IPC_PRIVATE, 
				    GUI.image->bytes_per_line * GUI.image->height,
				    IPC_CREAT | 0777);
	if (GUI.sm_info.shmid < 0)
	{
	    fprintf (stderr, "shmget failed, switching to XPutImage\n");
	    XDestroyImage (GUI.image);
	    GUI.use_shared_memory = 0;
	}
	else
	{
	    GUI.image->data = GUI.sm_info.shmaddr = (char *) shmat (GUI.sm_info.shmid, 0, 0);
	    if (!GUI.image->data)
	    {
		fprintf (stderr, "shmat failed, switching to XPutImage\n");
		XDestroyImage (GUI.image);
		shmctl (GUI.sm_info.shmid, IPC_RMID, 0);
		GUI.use_shared_memory = 0;
	    }
	    else
	    {
		GUI.sm_info.readOnly = False;

		XErrorHandler error_handler = XSetErrorHandler (ErrorHandler);
		XShmAttach (GUI.display, &GUI.sm_info);
		XSync (GUI.display, False);
		(void) XSetErrorHandler (error_handler);

		// X Error handler might clear GUI.use_shared_memory if XShmAttach failed
		if (!GUI.use_shared_memory)
		{
		    fprintf (stderr, "XShmAttach failed, switching to XPutImage\n");
		    XDestroyImage (GUI.image);
		    shmdt (GUI.sm_info.shmaddr);
		    shmctl (GUI.sm_info.shmid, IPC_RMID, 0);
		}
	    }
	}
    }

    if (!GUI.use_shared_memory)
    {
#endif
	GUI.image = XCreateImage (GUI.display, GUI.visual, GUI.depth, ZPixmap, 0,
				  (char *) NULL, image_width, image_height,
				  BitmapUnit (GUI.display), 0);
	GUI.image->data = (char *) malloc (image_height *
					   GUI.image->bytes_per_line);
#ifdef LSB_FIRST
	GUI.image->byte_order = LSBFirst;
#else
	GUI.image->byte_order = MSBFirst;
#endif

#ifdef MITSHM
    }
#endif

    int h = IMAGE_HEIGHT;

    if (!Settings.SixteenBit)
    {
	if (GUI.image_needs_scaling || GUI.depth != 8)
	{
	    GFX.Screen = (uint8 *) (GUI.to_free [tf++] = malloc (IMAGE_WIDTH * h));
	    GFX.Pitch = IMAGE_WIDTH;
	}
	else
	{
	    GFX.Screen = (uint8 *) GUI.image->data;
	    GFX.Pitch = GUI.image->bytes_per_line;
	}
	GFX.SubScreen = NULL;
	GFX.ZBuffer = (uint8 *) (GUI.to_free [tf++] = malloc (GFX.Pitch * h));
	GFX.SubZBuffer = NULL;
    }
    else
    if (GUI.depth == 8)
    {
	if (GUI.interpolate)
	{
	    GFX.Pitch = (IMAGE_WIDTH + 4) * 2;
	    h += 2;
	}
	else
	    GFX.Pitch = IMAGE_WIDTH * 2;
	GFX.Screen = (uint8 *) (GUI.to_free [tf++] = malloc (GFX.Pitch * h));
	GFX.SubScreen = (uint8 *) (GUI.to_free [tf++] = malloc (GFX.Pitch * h));
	GFX.ZBuffer = (uint8 *) (GUI.to_free [tf++] = malloc ((GFX.Pitch >> 1) * h));
	GFX.SubZBuffer = (uint8 *) (GUI.to_free [tf++] = malloc ((GFX.Pitch >> 1) * h));
	if (GUI.interpolate)
	{
	    GUI.interpolated_screen = (uint8 *) (GUI.to_free [tf++] = malloc (512 * 478 * 2));
	    GUI.delta_screen = (uint8 *) (GUI.to_free [tf++] = malloc (GFX.Pitch * h));
	}
    }
    else
    {
	if ((GUI.depth != 15 && GUI.depth != 16) || GUI.interpolate)
	{
	    if (GUI.interpolate)
	    {
		GFX.Pitch = (IMAGE_WIDTH + 4) * 2;
		h += 2;
	    }
	    else
		GFX.Pitch = IMAGE_WIDTH * 2;
	    GFX.Screen = (uint8 *) (GUI.to_free [tf++] = malloc (GFX.Pitch * h));
	    if (GUI.interpolate)
	    {
		if (GUI.image_needs_scaling || (GUI.depth != 15 && GUI.depth != 16)
#ifdef USE_DGA_EXTENSION
		    || XF86.scale
#endif
)
		GUI.interpolated_screen = (uint8 *) (GUI.to_free [tf++] = malloc (512 * 478 * 2));
		GUI.delta_screen = (uint8 *) (GUI.to_free [tf++] = malloc (GFX.Pitch * h));
	    }
	}
	else
	{
	    GFX.Screen = (uint8 *) GUI.image->data;
	    GFX.Pitch = GUI.image->bytes_per_line;
	}
	GFX.SubScreen = (uint8 *) (GUI.to_free [tf++] = malloc (GFX.Pitch * h));
	GFX.ZBuffer = (uint8 *) (GUI.to_free [tf++] = malloc ((GFX.Pitch >> 1) * h));
	GFX.SubZBuffer = (uint8 *) (GUI.to_free [tf++] = malloc ((GFX.Pitch >> 1) * h));
    }
    GFX.Delta = (GFX.SubScreen - GFX.Screen) >> 1;
    ZeroMemory (GFX.Screen, GFX.Pitch * h);
    if ((uint8 *) GUI.image->data != GFX.Screen)
	ZeroMemory (GUI.image->data, GUI.image->bytes_per_line * GUI.image->height);
    if (GUI.delta_screen)
	memset (GUI.delta_screen, 0xff, GFX.Pitch * h);
    if (GUI.interpolated_screen)
	ZeroMemory (GUI.interpolated_screen, 512 * 478 * 2);
    if (Settings.SixteenBit && GUI.interpolate)
    {
	// Offset the rendering of the SNES image by at least one pixel because
	// Kreed's interpolation routines read one pixel beyond the bounds of
	// the source image buffer.
	GFX.Screen += GFX.Pitch + sizeof (uint16) * 2;
    }
    GUI.image_date = (uint8 *) GUI.image->data;
    GUI.bytes_per_line = GUI.image->bytes_per_line;
}

int ErrorHandler (Display *, XErrorEvent *)
{
#ifdef MITSHM
    GUI.use_shared_memory = 0;
#endif
    return (0);
}

void S9xSetTitle (const char *string)
{
#ifdef USE_AIDO
    if (Settings.AIDOShmId)
        return;
#endif

    XStoreName (GUI.display, GUI.window, string);
    XFlush (GUI.display);
}
    
bool8 S9xReadMousePosition (int which1, int &x, int &y, uint32 &buttons)
{
    if (which1 == 0)
    {
	x = GUI.mouse_x;
	y = GUI.mouse_y;
	buttons = GUI.mouse_buttons;
	return (TRUE);
    }
    return (FALSE);
}

bool8 S9xReadSuperScopePosition (int &x, int &y, uint32 &buttons)
{
    x = (int) ((GUI.mouse_x - GUI.box.x) * 
	       (256.0 / (double) GUI.box.width));
    y = (int) ((GUI.mouse_y - GUI.box.y) * 
	       (224.0 / (double) GUI.box.height));
    buttons = (GUI.mouse_buttons & 3) | (GUI.superscope_turbo << 2) |
	      (GUI.superscope_pause << 3);

    return (TRUE);
}

bool JustifierOffscreen()
{
  return (bool)(GUI.mouse_buttons&2);
}

void JustifierButtons(uint32& justifiers)
{
  if(IPPU.Controller==SNES_JUSTIFIER_2)
  {
    if((GUI.mouse_buttons&1)||(GUI.mouse_buttons&2))
    {
      justifiers|=0x00200;
    }
    if(GUI.mouse_buttons&4)
    {
      justifiers|=0x00800;
    }
  }
  else
  {
    if((GUI.mouse_buttons&1)||(GUI.mouse_buttons&2))
    {
      justifiers|=0x00100;
    }
    if(GUI.mouse_buttons&4)
    {
      justifiers|=0x00400;
    }
  }
}

#ifdef SELECT_BROKEN_FOR_SIGNALS
#include <sys/ioctl.h>
#endif

static bool8 CheckForPendingXEvents (Display *display)
{
#ifdef SELECT_BROKEN_FOR_SIGNALS
    int arg = 0;

    return (XEventsQueued (display, QueuedAlready) ||
	    ioctl (ConnectionNumber (display), FIONREAD, &arg) == 0 && arg);
#else
    return (XPending (display));
#endif
}

#include "movie.h"
static const char *S9xChooseMovieFilename(bool8 read_only)
{
    char def [PATH_MAX + 1];
    char title [PATH_MAX + 1];
    char drive [_MAX_DRIVE + 1];
    char dir [_MAX_DIR + 1];
    char ext [_MAX_EXT + 1];

    _splitpath (Memory.ROMFilename, drive, dir, def, ext);
    strcat (def, ".smv");
    sprintf (title, "Choose movie %s filename", read_only ? "playback" : "record");
    const char *filename;

    S9xSetSoundMute (TRUE);
    filename = S9xSelectFilename (def, S9xGetSnapshotDirectory (), "smv", title);
    S9xSetSoundMute (FALSE);
    return (filename);
}

static void S9xInfoMessage(const char *msg)
{
    S9xSetInfoString(msg);
    if(Settings.Paused) puts(msg);
}

static uint32 GetNormalSpeed()
{
    return Settings.PAL ? Settings.FrameTimePAL : Settings.FrameTimeNTSC;
}
static unsigned GetSpeedPercentage()
{
    const uint32 normalspeed = GetNormalSpeed();
    return normalspeed * 100 / Settings.FrameTime;
}
static void SetSpeedPercentage(unsigned p)
{
    const uint32 normalspeed = GetNormalSpeed();
    Settings.FrameTime = normalspeed * 100 / p;
}

#include <map>
using namespace std;
static class KeyboardSetup
{
public:
    /* List of all possible keyboard-accessible functions */
    enum functiontype
    {
        FUNC_NONE=0,
        PLAYING_KEY,
        TOGGLE_SOUND,
        WRITE_SAVE_NUM,
        WRITE_SAVE_ASK,
        LOAD_SAVE_NUM,
        LOAD_SAVE_ASK,
        TOGGLE_LAYER,
        WRITE_SPC_ASK,
        FRAMETIME_INC,
        FRAMETIME_DEC,
        FRAMESKIP_INC,
        FRAMESKIP_DEC,
        PAUSE,
        DGA_FULLSCREEN,
        SCREENSHOT,
        SPC7110LOG,
        TOGGLE_HDMA,
        TOGGLE_JOYSWAP,
        TOGGLE_GL_CUBE,
        TOGGLE_BG_HACK,
        TOGGLE_TRANSP,
        TOGGLE_CLIPWIN,
        TOGGLE_CONTROLLER,
        TOGGLE_INTERPSOUND,
        TOGGLE_SYNCSOUND,
        TOGGLE_MODE7INTERP,
        TURBO_ENABLE,
        SUPERSCOPE_TURBO,
        SUPERSCOPE_PAUSE_ENABLE,
        EXIT,
        WRITE_MOVIE_ASK,
        LOAD_MOVIE_ASK,
        STOP_MOVIE,
        
        FUNC_LAST = STOP_MOVIE /* update this to match the last token */
    };
    static const char* GetFuncName(functiontype func)
    {
        switch(func)
        {
            case PLAYING_KEY: return             "PLAYING_KEY";
            case TOGGLE_SOUND: return            "TOGGLE_SOUND";
            case WRITE_SAVE_NUM: return          "WRITE_SAVE_NUM";
            case WRITE_SAVE_ASK: return          "WRITE_SAVE_ASK";
            case LOAD_SAVE_NUM: return           "LOAD_SAVE_NUM";
            case LOAD_SAVE_ASK: return           "LOAD_SAVE_ASK";
            case TOGGLE_LAYER: return            "TOGGLE_LAYER";
            case WRITE_SPC_ASK: return           "WRITE_SPC_ASK";
            case FRAMETIME_INC: return           "FRAMETIME_INC";
            case FRAMETIME_DEC: return           "FRAMETIME_DEC";
            case FRAMESKIP_INC: return           "FRAMESKIP_INC";
            case FRAMESKIP_DEC: return           "FRAMESKIP_DEC";
            case PAUSE: return                   "PAUSE";
            case DGA_FULLSCREEN: return          "DGA_FULLSCREEN";
            case SCREENSHOT: return              "SCREENSHOT";
            case SPC7110LOG: return              "SPC7110LOG";
            case TOGGLE_HDMA: return             "TOGGLE_HDMA";
            case TOGGLE_JOYSWAP: return          "TOGGLE_JOYSWAP";
            case TOGGLE_GL_CUBE: return          "TOGGLE_GL_CUBE";
            case TOGGLE_BG_HACK: return          "TOGGLE_BG_HACK";
            case TOGGLE_TRANSP: return           "TOGGLE_TRANSP";
            case TOGGLE_CLIPWIN: return          "TOGGLE_CLIPWIN";
            case TOGGLE_CONTROLLER: return       "TOGGLE_CONTROLLER";
            case TOGGLE_INTERPSOUND: return      "TOGGLE_INTERPSOUND";
            case TOGGLE_SYNCSOUND: return        "TOGGLE_SYNCSOUND";
            case TOGGLE_MODE7INTERP: return      "TOGGLE_MODE7INTERP";
            case TURBO_ENABLE: return            "TURBO_ENABLE";
            case SUPERSCOPE_TURBO: return        "SUPERSCOPE_TURBO";
            case SUPERSCOPE_PAUSE_ENABLE: return "SUPERSCOPE_PAUSE_ENABLE";
            case EXIT: return                    "EXIT";
            case WRITE_MOVIE_ASK: return         "WRITE_MOVIE_ASK";
            case LOAD_MOVIE_ASK: return          "LOAD_MOVIE_ASK";
            case STOP_MOVIE: return              "STOP_MOVIE";
            default: return "unknown";
        }
    }
    static const char *GetKeySymName(int sym)
    {
        static char Buf[64];
        sprintf(Buf, "'%c'(%d)", sym,sym);
        return Buf;
    }
    struct Keyfunction
    {
        functiontype func;
        unsigned param;
        bool inited;
        int sym; const char *prefix;
    private:
        /* ensure nobody uses the assignment operator on us */
        void operator=(const Keyfunction& b);
    public:
        Keyfunction(): func(FUNC_NONE), inited(false) {}
        Keyfunction(functiontype f,unsigned p): func(f),param(p), inited(true) {}
        void Assign(const Keyfunction& b)
        {
            if(inited)
            {
                fprintf(stderr,
                   "[Input] Warning: Key %s%s had %s[0x%X], overwriting by %s[0x%X]\n",
                   prefix, GetKeySymName(sym),
                   GetFuncName(func), param,
                   GetFuncName(b.func), b.param);
            }
            func   = b.func;
            param  = b.param;
            inited = b.inited;
        }
        void SetName(int s, const char* p) { sym=s; prefix=p; }
    };
    struct Keydata
    {
        Keyfunction plain, shift, ctrl, alt;
    public:
        Keydata() {}
        void DefineAs(int sym)
        {
            plain.SetName(sym,"");
            shift.SetName(sym,"shift+");
            ctrl.SetName(sym,"ctrl+");
            alt.SetName(sym,"alt+");
        }
    };
private:
    enum masktype { MaskNone,MaskCtrl,MaskShift,MaskAlt };
    map<int, Keydata> keydata;
    
    void Define(int sym, masktype mask, functiontype func, unsigned param)
    {
        Keyfunction result(func, param);
        Keydata& target = keydata[sym];
        target.DefineAs(sym);
        switch(mask)
        {
            case MaskCtrl: target.ctrl.Assign(result); break;
            case MaskShift: target.shift.Assign(result); break;
            case MaskAlt: target.alt.Assign(result); break;
            case MaskNone:
            {
                target.plain.Assign(result);

                result.inited = false;
                /* so we'll not get warnings when overwriting
                 * these extra fields later: */
                if(!target.shift.inited) target.shift.Assign(result);
                if(!target.ctrl.inited) target.ctrl.Assign(result);
                if(!target.alt.inited) target.alt.Assign(result);
                break;
            }
        }
    }
    void VerifySetup()
    {
        bool8 Defined[(unsigned)FUNC_LAST + 1] = {FALSE};
        map<int, Keydata>::const_iterator i;
        for(i=keydata.begin(); i!=keydata.end(); ++i)
        {
            Defined[i->second.plain.func] = TRUE;
            Defined[i->second.shift.func] = TRUE;
            Defined[i->second.ctrl.func] = TRUE;
            Defined[i->second.alt.func] = TRUE;
        }
        for(unsigned a=0; a<sizeof(Defined); ++a)
            if(a != FUNC_NONE && !Defined[a])
            {
                fprintf(stderr, "[Input] Warning: No key assigned for %s\n",
                    GetFuncName((functiontype)a) );
            }
    }
private:
    struct Key
    {
        int symbol;
        masktype mask;
    public:
        Key(): symbol(0), mask(MaskNone) {}
        Key(int sym): symbol(sym), mask(MaskNone) {}
        Key(int sym,masktype m): symbol(sym), mask(m) {}
    };
    static Key Shift(int symbol) { return Key(symbol,MaskShift); }
    static Key Ctrl(int symbol) { return Key(symbol,MaskCtrl); }
    static Key Alt(int symbol) { return Key(symbol,MaskAlt); }
private:
    void Define(functiontype func, unsigned param,
                Key k1,
                Key k2 = Key(),
                Key k3 = Key(),
                Key k4 = Key()
               )
    {
        if(k1.symbol) Define(k1.symbol, k1.mask, func, param);
        if(k2.symbol) Define(k2.symbol, k2.mask, func, param);
        if(k3.symbol) Define(k3.symbol, k3.mask, func, param);
        if(k4.symbol) Define(k4.symbol, k4.mask, func, param);
    }
public:
    /* Contruct the keyboard setup upon program start. */
    KeyboardSetup()
    {
        // player 1: tr,tl, x,a
        Define(PLAYING_KEY, 0x00000010, XK_z, XK_w, XK_b);
        Define(PLAYING_KEY, 0x00000020, XK_a, XK_q, XK_v);
        Define(PLAYING_KEY, 0x00000040, XK_s, XK_e, XK_m);
        Define(PLAYING_KEY, 0x00000080, XK_d, XK_t, XK_period);
        // player 1: right,left,down,up
        Define(PLAYING_KEY, 0x00000100, XK_k, XK_Right);
        Define(PLAYING_KEY, 0x00000200, XK_h, XK_Left);
        Define(PLAYING_KEY, 0x00000400, XK_j, XK_n, XK_Down);
        Define(PLAYING_KEY, 0x00000800, XK_u, XK_Up);
        // player 1: start,select, y,b
        Define(PLAYING_KEY, 0x00001000, XK_Return);
        Define(PLAYING_KEY, 0x00002000, XK_space);
        Define(PLAYING_KEY, 0x00004000, XK_x, XK_r, XK_comma);
        Define(PLAYING_KEY, 0x00008000, XK_y, XK_c);
        // player 2: tr,tl, x,a
        Define(PLAYING_KEY, 0x00100000, XK_Delete);
        Define(PLAYING_KEY, 0x00200000, XK_Insert);
        Define(PLAYING_KEY, 0x00400000, XK_Home);
        Define(PLAYING_KEY, 0x00800000, XK_Prior);
        // player 2: right,left,down,up
        Define(PLAYING_KEY, 0x01000000, XK_KP_4);
        Define(PLAYING_KEY, 0x02000000, XK_KP_6);
        Define(PLAYING_KEY, 0x04000000, XK_KP_2);
        Define(PLAYING_KEY, 0x08000000, XK_KP_8);
        // player 2: start,select,y,b
        Define(PLAYING_KEY, 0x10000000, XK_KP_Enter);
        Define(PLAYING_KEY, 0x20000000, XK_KP_Add);
        Define(PLAYING_KEY, 0x40000000, XK_End);
        Define(PLAYING_KEY, 0x80000000, XK_Next);
        // toggle sound channels
        // Careful: alt + f-keys might be bound to the window manager!
        Define(TOGGLE_SOUND, 0,         Alt(XK_F4), Ctrl(XK_F4));
        Define(TOGGLE_SOUND, 1,         Alt(XK_F5), Ctrl(XK_F5));
        Define(TOGGLE_SOUND, 2,         Alt(XK_F6), Ctrl(XK_F6));
        Define(TOGGLE_SOUND, 3,         Alt(XK_F7), Ctrl(XK_F7));
        Define(TOGGLE_SOUND, 4,         Alt(XK_F8), Ctrl(XK_F8));
        Define(TOGGLE_SOUND, 5,         Alt(XK_F9), Ctrl(XK_F9));
        Define(TOGGLE_SOUND, 6,         Alt(XK_F10), Ctrl(XK_F10));
        Define(TOGGLE_SOUND, 7,         Alt(XK_F11), Ctrl(XK_F11));
        // re-enable all sound channels
        Define(TOGGLE_SOUND, 8,         Alt(XK_F12), Ctrl(XK_F12));
        // numbered quicksaves
        Define(WRITE_SAVE_NUM, 0,       XK_F1);
        Define(WRITE_SAVE_NUM, 1,       XK_F2);
        Define(WRITE_SAVE_NUM, 2,       XK_F3);
        Define(WRITE_SAVE_NUM, 3,       XK_F4);
        Define(WRITE_SAVE_NUM, 4,       XK_F5);
        Define(WRITE_SAVE_NUM, 5,       XK_F6);
        Define(WRITE_SAVE_NUM, 6,       XK_F7);
        Define(WRITE_SAVE_NUM, 7,       XK_F8);
        Define(WRITE_SAVE_NUM, 8,       XK_F9);
        Define(WRITE_SAVE_NUM, 9,       XK_F10);
        Define(LOAD_SAVE_NUM, 0,       Shift(XK_F1));
        Define(LOAD_SAVE_NUM, 1,       Shift(XK_F2));
        Define(LOAD_SAVE_NUM, 2,       Shift(XK_F3));
        Define(LOAD_SAVE_NUM, 3,       Shift(XK_F4));
        Define(LOAD_SAVE_NUM, 4,       Shift(XK_F5));
        Define(LOAD_SAVE_NUM, 5,       Shift(XK_F6));
        Define(LOAD_SAVE_NUM, 6,       Shift(XK_F7));
        Define(LOAD_SAVE_NUM, 7,       Shift(XK_F8));
        Define(LOAD_SAVE_NUM, 8,       Shift(XK_F9));
        Define(LOAD_SAVE_NUM, 9,       Shift(XK_F10));
        // layer toggles
        Define(TOGGLE_LAYER,  0,       XK_1);
        Define(TOGGLE_LAYER,  1,       XK_2);
        Define(TOGGLE_LAYER,  2,       XK_3);
        Define(TOGGLE_LAYER,  3,       XK_4);
        // sprite layer toggle
        Define(TOGGLE_LAYER,  4,       XK_5);
        // named saves
        Define(LOAD_SAVE_ASK,  0,      Alt(XK_F2), Ctrl(XK_F2), XK_F11);
        Define(WRITE_SAVE_ASK, 0,      Alt(XK_F3), Ctrl(XK_F3), XK_F12);
        Define(WRITE_SPC_ASK, 0,       Alt(XK_F1), Ctrl(XK_F1));
        // timings
        Define(FRAMETIME_INC, 0,       Shift(XK_equal), Shift(XK_plus));
        Define(FRAMETIME_DEC, 0,       Shift(XK_minus));
        Define(FRAMESKIP_INC, 0,       XK_equal, XK_plus);
        Define(FRAMESKIP_DEC, 0,       XK_minus);
        // pause
        Define(PAUSE, 0,               XK_Pause, XK_Break, XK_Scroll_Lock);
        // misc functions
        Define(DGA_FULLSCREEN, 0,      Alt(XK_Return));
        Define(SCREENSHOT, 0,          XK_Print);
        Define(SPC7110LOG, 0,          XK_Sys_Req);
        Define(TOGGLE_HDMA, 0,         XK_0);
        Define(TOGGLE_JOYSWAP, 0,      XK_6);
        Define(TOGGLE_GL_CUBE, 0,      Shift(XK_6));
        Define(TOGGLE_BG_HACK, 0,      XK_8);
        Define(TOGGLE_TRANSP, 0,       XK_9);
        Define(TOGGLE_CLIPWIN, 0,      XK_BackSpace);
        Define(TOGGLE_CONTROLLER, 0,   XK_7);
        Define(TOGGLE_INTERPSOUND, 0,  XK_bracketleft, Alt(XK_8));
        Define(TOGGLE_SYNCSOUND, 0,    XK_bracketright, Alt(XK_9));
        Define(TOGGLE_MODE7INTERP, 0,  Shift(XK_9));
        Define(TURBO_ENABLE, 0,        XK_Tab);
        Define(SUPERSCOPE_TURBO, 0,    XK_grave, XK_asciitilde, XK_numbersign);
        Define(SUPERSCOPE_PAUSE_ENABLE, 0, XK_slash);
        // escape from fullscreen, escape from emulator
        Define(EXIT, 0,                XK_Escape);
        // movie functions
        Define(WRITE_MOVIE_ASK, 0,     Shift(XK_1));
        Define(LOAD_MOVIE_ASK, 0,      Shift(XK_2));
        Define(STOP_MOVIE, 0,          Shift(XK_3));
        
        VerifySetup();
    }
public:
    const Keyfunction& GetKeyFunction(int keycode, unsigned keymask) const
    {
        static Keyfunction notfound;
        map<int, Keydata>::const_iterator i = keydata.find(keycode);
        //fprintf(stderr, "Pressed key %d (mask %X)\n", keycode, keymask);
        if(i != keydata.end())
        {
            // ShiftMask: shift ($0001)
            // LockMask:  capslock ($0002)
            // Mod1Mask:  alt ($0008)
            // Mod4Mask:  numlock ($0010)
            //         :  altgr ($2000)
            // Mod5Mask:  scrolllock ($0080)
            // Button1Mask: left mouse button ($0100)
            // Button2Mask: middle mouse button ($0200)
            // Button3Mask: right mouse button ($0400)
            
            if(keymask & (Mod1Mask | 0x2000)) return i->second.alt;
            if(keymask & (ControlMask)) return i->second.ctrl;
            if(keymask & (ShiftMask)) return i->second.shift;
            return i->second.plain;
        }
        return notfound;
    }
} KBSetup;

void S9xProcessEvents (bool8 block)
{
#ifdef USE_AIDO
    if (Settings.AIDOShmId)
    {
        S9xAIDOProcessEvents(block);
        return;
    }
#endif

    while (block || CheckForPendingXEvents (GUI.display))
    {
        XEvent event;

        XNextEvent (GUI.display, &event);
        block = FALSE;

#if 0
        if (event.xany.window != window)
        {
            app->x11ProcessEvent (&event);
            continue;
        }
#endif
        switch (event.type)
        {
        case KeyPress:
        case KeyRelease:
        {
            int key = XKeycodeToKeysym (GUI.display, event.xkey.keycode, 0);
            
            const KeyboardSetup::Keyfunction& func
                = KBSetup.GetKeyFunction(key, event.xkey.state);
            switch(func.func)
            {
                case KeyboardSetup::FUNC_NONE:
                {
                    break;
                }
                case KeyboardSetup::PLAYING_KEY:
                {
                    uint16 word1 = (func.param      ) & 0xFFFF;
                    uint16 word2 = (func.param >> 16) & 0xFFFF;
                    if(event.type == KeyPress)
                    {
                        joypads[0] |= word1;
                        joypads[1] |= word2;
                    }
                    else
                    {
                        joypads[0] &= ~word1;
                        joypads[1] &= ~word2;
                    }
                    break;
                }
                case KeyboardSetup::TOGGLE_SOUND:
                {
                    if(event.type != KeyPress) break;
                    if(func.param > 8) break;
                    
                    S9xToggleSoundChannel(func.param);
                    if(func.param == 8)
                        S9xInfoMessage ("All sound channels on");
                    else
                    {
                        sprintf (GUI.info_string, "Sound channel %d %s", func.param,
                                   (so.sound_switch & (1 << (func.param))) ? "on" : "off");
                        S9xInfoMessage (GUI.info_string);
                    }
                    break;
                }
                case KeyboardSetup::WRITE_SAVE_NUM:
                {
                    if(event.type != KeyPress) break;
                    if(func.param > 999) break;
                    
                    char def [PATH_MAX];
                    char filename [PATH_MAX];
                    char drive [_MAX_DRIVE];
                    char dir [_MAX_DIR];
                    char ext [_MAX_EXT];

                    _splitpath (Memory.ROMFilename, drive, dir, def, ext);
                    sprintf (filename, "%s%s%s.%03d",
                             S9xGetSnapshotDirectory (), SLASH_STR, def,
                             func.param);
                    sprintf (GUI.info_string, "%s.%03d saved", def, func.param);
                    S9xInfoMessage (GUI.info_string);
                    S9xFreezeGame (filename);
                    break;
                }
                case KeyboardSetup::WRITE_SAVE_ASK:
                {
                    if(event.type != KeyPress) break;
                    
                    S9xFreezeGame (S9xChooseFilename (FALSE));
                    break;
                }
                case KeyboardSetup::LOAD_SAVE_NUM:
                {
                    if(event.type != KeyPress) break;
                    if(func.param > 999) break;
                    
                    char def [PATH_MAX];
                    char filename [PATH_MAX];
                    char drive [_MAX_DRIVE];
                    char dir [_MAX_DIR];
                    char ext [_MAX_EXT];

                    _splitpath (Memory.ROMFilename, drive, dir, def, ext);
                    sprintf (filename, "%s%s%s.%03d",
                             S9xGetSnapshotDirectory (), SLASH_STR, def,
                             func.param);
                    if (S9xUnfreezeGame (filename))
                    {
                        sprintf (GUI.info_string, "%s.%03d loaded", def, func.param);
                        S9xInfoMessage (GUI.info_string);
                    }
                    else
                    {
                        static char *digits = "t123456789";
                        _splitpath (Memory.ROMFilename, drive, dir, def, ext);
                        sprintf (filename, "%s%s%s.zs%c",
                                 S9xGetSnapshotDirectory (), SLASH_STR, 
                                 def, digits [func.param]);
                        if (S9xUnfreezeGame (filename))
                        {
                            sprintf (GUI.info_string, "Loaded ZSNES freeze file %s.zs%c",
                                     def, digits [func.param]);
                            S9xInfoMessage (GUI.info_string);
                        }
                        else
                        {
                            sprintf (GUI.info_string, "Freeze file %u not found",
                                     func.param);
                            S9xMessage (S9X_ERROR, S9X_FREEZE_FILE_NOT_FOUND,
                                        GUI.info_string);
                        }
                    }
                    break;
                }
                case KeyboardSetup::LOAD_SAVE_ASK:
                {
                    if(event.type != KeyPress) break;
                    
                    S9xUnfreezeGame (S9xChooseFilename (TRUE));
                    break;
                }
                case KeyboardSetup::TOGGLE_LAYER:
                {
                    if(event.type != KeyPress) break;
                    if(func.param > 4) break;
                    
                    unsigned mask = 1 << func.param;
                    PPU.BG_Forced ^= mask;
                    if(func.param == 4)
                        sprintf(GUI.info_string, "Sprites");
                    else
                        sprintf(GUI.info_string, "BG#%d", func.param);
                    S9xDisplayStateChange (GUI.info_string, !(PPU.BG_Forced & mask));
                    break;
                }
                case KeyboardSetup::WRITE_SPC_ASK:
                {
                    if(event.type != KeyPress) break;
                    
                    char def [PATH_MAX];
                    char filename [PATH_MAX];
                    char drive [_MAX_DRIVE];
                    char dir [_MAX_DIR];
                    char ext [_MAX_EXT];

                    _splitpath (Memory.ROMFilename, drive, dir, def, ext);
                    strcpy (ext, "spc");
                    _makepath (filename, drive, S9xGetSnapshotDirectory (), 
                               def, ext);
                    if (S9xSPCDump (filename))
                        sprintf (GUI.info_string, "%s.%s saved", def, ext);
                    else
                        sprintf (GUI.info_string, "%s.%s not saved (%s)", def, ext,
                                 strerror (errno));
                    
                    S9xInfoMessage (GUI.info_string);
                    break;
                }
                case KeyboardSetup::FRAMETIME_INC:
                {
                    if(event.type != KeyPress) break;
                    
                    unsigned CurSpeed = GetSpeedPercentage();
                    if(CurSpeed < 10) ++CurSpeed;
                    else if(CurSpeed < 150) CurSpeed += 5;
                    else if(CurSpeed < 200) CurSpeed += 10;
                    else if(CurSpeed < 400) CurSpeed += 20;
                    else if(CurSpeed < 500) CurSpeed += 50;
                    else if(CurSpeed < 1500) CurSpeed += 100;
                    
                    SetSpeedPercentage(CurSpeed);
                    sprintf (GUI.info_string, "Emulated speed: %d%% (%.1f FPS)",
                        CurSpeed, 1e6 / Settings.FrameTime);
                    S9xInfoMessage (GUI.info_string);
                    break;
                }
                case KeyboardSetup::FRAMETIME_DEC:
                {
                    if(event.type != KeyPress) break;
                    
                    unsigned CurSpeed = GetSpeedPercentage();
                    if(CurSpeed <= 1) {}
                    else if(CurSpeed <= 10) --CurSpeed;
                    else if(CurSpeed <= 150) CurSpeed -= 5;
                    else if(CurSpeed <= 200) CurSpeed -= 10;
                    else if(CurSpeed <= 400) CurSpeed -= 20;
                    else if(CurSpeed <= 500) CurSpeed -= 50;
                    else CurSpeed -= 100;
                    
                    SetSpeedPercentage(CurSpeed);
                    sprintf (GUI.info_string, "Emulated speed: %d%% (%.1f FPS)",
                        CurSpeed, 1e6 / Settings.FrameTime);
                    S9xInfoMessage (GUI.info_string);
                    break;
                }
                case KeyboardSetup::FRAMESKIP_INC:
                {
                    if(event.type != KeyPress) break;
                    
                    if (Settings.SkipFrames == AUTO_FRAMERATE)
                        Settings.SkipFrames = 1;
                    else
                    if (Settings.SkipFrames < 10)
                        Settings.SkipFrames++;

                    if (Settings.SkipFrames == AUTO_FRAMERATE)
                        S9xInfoMessage ("Auto frame skip");
                    else
                    {
                        sprintf (GUI.info_string, "Frame skip: %d",
                                 Settings.SkipFrames - 1);
                        S9xInfoMessage (GUI.info_string);
                    }
                    break;
                }
                case KeyboardSetup::FRAMESKIP_DEC:
                {
                    if(event.type != KeyPress) break;
                    
                    if (Settings.SkipFrames <= 1)
                        Settings.SkipFrames = AUTO_FRAMERATE;
                    else
                        if (Settings.SkipFrames != AUTO_FRAMERATE)
                            Settings.SkipFrames--;

                    if (Settings.SkipFrames == AUTO_FRAMERATE)
                        S9xInfoMessage ("Auto frame skip");
                    else
                    {
                        sprintf (GUI.info_string, "Frame skip: %d",
                                 Settings.SkipFrames - 1);
                        S9xInfoMessage (GUI.info_string);
                    }
                    break;
                }
                case KeyboardSetup::PAUSE:
                {
                    if(event.type != KeyPress) break;
                    
                    Settings.Paused ^= 1;
                    S9xDisplayStateChange ("Pause", Settings.Paused);
                    
                    break;
                }
                case KeyboardSetup::DGA_FULLSCREEN:
                {
                    if(event.type != KeyPress) break;
                    
#ifdef USE_DGA_EXTENSION
                    S9xSwitchToFullScreen (!XF86.is_full_screen);
#endif
                    break;
                }
                case KeyboardSetup::SCREENSHOT:
                {
                    if(event.type != KeyPress) break;
                    
                    Settings.TakeScreenshot = TRUE; 
                    break;
                }
                case KeyboardSetup::SPC7110LOG:
                {
                    if(event.type != KeyPress) break;
                    
                    if(Settings.SPC7110)
                        Do7110Logging();
                    break;
                }
                case KeyboardSetup::TOGGLE_HDMA:
                {
                    if(event.type != KeyPress) break;
                    
                    Settings.DisableHDMA = !Settings.DisableHDMA;
                    S9xDisplayStateChange ("HDMA emulation", !Settings.DisableHDMA);
                    break;
                }
                case KeyboardSetup::TOGGLE_JOYSWAP:
                {
                    if(event.type != KeyPress) break;
                    
                    Settings.SwapJoypads = !Settings.SwapJoypads;
                    S9xDisplayStateChange ("Joypad swapping", Settings.SwapJoypads);
                    break;
                }
                case KeyboardSetup::TOGGLE_GL_CUBE:
                {
                    if(event.type != KeyPress) break;
                    
#ifdef USE_OPENGL
                    OpenGL.draw_cube ^= TRUE;
#endif
                    break;
                }
                case KeyboardSetup::TOGGLE_BG_HACK:
                {
                    if(event.type != KeyPress) break;
                    
                    Settings.BGLayering = !Settings.BGLayering;
                    S9xDisplayStateChange ("Background layering hack", 
                                           Settings.BGLayering);
                    break;
                }
                case KeyboardSetup::TOGGLE_TRANSP:
                {
                    if(event.type != KeyPress) break;
                    
                    if (Settings.SixteenBit)
                    {
                        Settings.Transparency = !Settings.Transparency;
                        S9xDisplayStateChange ("Transparency effects", 
                                               Settings.Transparency);
                    }
                    break;
                }
                case KeyboardSetup::TOGGLE_CLIPWIN:
                {
                    if(event.type != KeyPress) break;
                    
                    Settings.DisableGraphicWindows = !Settings.DisableGraphicWindows;
                    S9xDisplayStateChange ("Graphic clip windows",
                                           !Settings.DisableGraphicWindows);
                
                    break;
                }
                case KeyboardSetup::TOGGLE_CONTROLLER:
                {
                    if(event.type != KeyPress) break;
                    
                    static char *controllers [] = {
                        "Multiplayer 5 on #0", "Joypad on #0", "Mouse on #1",
                        "Mouse on #0", "Superscope on #1"
                    };
                    S9xNextController ();
                    S9xInfoMessage (controllers [IPPU.Controller]);
                    break;
                }
                case KeyboardSetup::TOGGLE_INTERPSOUND:
                {
                    if(event.type != KeyPress) break;
                    
                    Settings.InterpolatedSound ^= 1;
                    S9xDisplayStateChange ("Interpolated sound",
                                           Settings.InterpolatedSound);
                    break;
                }
                case KeyboardSetup::TOGGLE_SYNCSOUND:
                {
                    if(event.type != KeyPress) break;
                    
                    Settings.SoundSync ^= 1;
                    S9xDisplayStateChange ("Synchronised sound",
                                           Settings.SoundSync);
                    break;
                }
                case KeyboardSetup::TOGGLE_MODE7INTERP:
                {
                    if(event.type != KeyPress) break;

                    Settings.Mode7Interpolate ^= TRUE;
                    S9xDisplayStateChange ("Mode 7 Interpolation", 
                                           Settings.Mode7Interpolate);
                
                    break;
                }
                case KeyboardSetup::TURBO_ENABLE:
                {
                    Settings.TurboMode = event.type == KeyPress;
                    break;
                }
                case KeyboardSetup::SUPERSCOPE_TURBO:
                {
                    if(event.type != KeyPress) break;

                    GUI.superscope_turbo = !GUI.superscope_turbo;
                    
                    break;
                }
                case KeyboardSetup::SUPERSCOPE_PAUSE_ENABLE:
                {
                    GUI.superscope_pause = event.type == KeyPress;
                    break;
                }
                case KeyboardSetup::EXIT:
                {
                    if(event.type != KeyPress) break;

#ifdef USE_DGA_EXTENSION
                    if (XF86.is_full_screen)
                    {
                        S9xSwitchToFullScreen (FALSE);
                        break;
                    }
#endif
                    S9xExit ();

                    break;
                }
                case KeyboardSetup::WRITE_MOVIE_ASK:
                {
                    if(event.type != KeyPress) break;

                    wchar_t name[MOVIE_MAX_METADATA] = {0};
                    if(S9xMovieActive()) S9xMovieStop(FALSE);
                    S9xMovieCreate(S9xChooseMovieFilename(FALSE),
                                   0x1F,
                                   //MOVIE_OPT_FROM_SNAPSHOT
                                   MOVIE_OPT_FROM_RESET
                                   ,
                                   name,0);
                    break;
                }
                case KeyboardSetup::LOAD_MOVIE_ASK:
                {
                    if(event.type != KeyPress) break;

                    if(S9xMovieActive()) S9xMovieStop(FALSE);
                    S9xMovieOpen(S9xChooseMovieFilename(TRUE), FALSE);
                    break;
                }
                case KeyboardSetup::STOP_MOVIE:
                {
                    if(event.type != KeyPress) break;

                    if(S9xMovieActive()) S9xMovieStop(FALSE);
                    break;
                }

                /* Do not put a "default" case here, or you'll
                 * miss the compiler warning about unhandled
                 * enumeration values
                 */
            }
            
            break;
        }
        case FocusIn:
            //XAutoRepeatOff (GUI.display);
            XFlush (GUI.display);
            //Settings.Paused &= ~2;
            break;
        case FocusOut:
            XAutoRepeatOn (GUI.display);
            XFlush (GUI.display);
            //Settings.Paused |= 2;
            break;
        case ConfigureNotify:
            if (event.xany.window == GUI.window &&
                (GUI.window_width != event.xconfigure.width ||
                 GUI.window_height != event.xconfigure.height))
            {
                GUI.window_width = event.xconfigure.width;
                GUI.window_height = event.xconfigure.height;
                IPPU.RenderThisFrame = TRUE;
                IPPU.FrameSkip = Settings.SkipFrames;
                SetupImage ();
            }
#ifdef USE_DGA_EXTENSION
            if (XF86.start_full_screen)
            {
                XF86.start_full_screen = FALSE;
                S9xSwitchToFullScreen (TRUE);
            }
#endif
            break;
#if 0
        case ButtonPress:
            GUI.mouse_buttons = (event.xbutton.state | (1 << event.xbutton.button)) & 0x1f;
            break;
        case ButtonRelease:
            GUI.mouse_buttons = (event.xbutton.state & ~(1 << event.xbutton.button)) & 0x1f;
            break;
#endif
        }
    }
}

void S9xPutImage (int snes_width, int snes_height)
{
#ifdef USE_GLIDE
    if (Settings.GlideEnable)
	S9xGlidePutImage (snes_width, snes_height);
    else
#elif USE_OPENGL
    if (Settings.OpenGLEnable)
	S9xOpenGLPutImage (snes_width, snes_height);
    else
#elif USE_AIDO
    if (Settings.AIDOShmId)
        S9xAIDOPutImage (snes_width, snes_height);
    else
#endif

    {
    bool8 done = FALSE;
    int width, height, cheight;

    width = snes_width;
    height = snes_height;
    cheight = (height>SNES_HEIGHT_EXTENDED)?SNES_HEIGHT_EXTENDED*2:SNES_HEIGHT_EXTENDED;
    
    if (GUI.interpolate && Settings.SixteenBit)
    {
	if (snes_width == 512 && snes_height > 240 && GUI.interpolate != 5)
	{
	    GUI.output_screen = GFX.Screen;
	    GUI.output_pitch = GFX.Pitch;

#ifdef USE_DGA_EXTENSION
	    if (XF86.is_full_screen)
	    {
		if (XF86.scale)
		    GUI.image_date = (uint8 *) XF86.vram;
		else
		{
		    GUI.box.x = (XF86.window_width - width) / 2;
		    GUI.box.y = (XF86.window_height - cheight) / 2;
		    GUI.image_date = (uint8 *) XF86.vram +
			    GUI.box.x * GUI.bytes_per_pixel +
			    GUI.box.y * GUI.bytes_per_line;
		}
	    }
#endif
	    if (!GUI.image_needs_scaling)
	    {
		for (int y = 0; y < snes_height; y++)
		{
		    memmove (GUI.image_date + y * GUI.bytes_per_line,
			     GFX.Screen + GFX.Pitch * y,
			     snes_width * GUI.bytes_per_pixel);
		}
		done = TRUE;
	    }
	}
	else
	{
	    if (GUI.interpolate != 5)
	    {
		width = 512;
		if (snes_height < 240)
		    height = snes_height << 1;
		else
		    height = snes_height;
                cheight = SNES_HEIGHT_EXTENDED << 1;
	    }
	    else
	    {
		width = GUI.window_width;
		cheight = height = GUI.window_height;
	    }
	    if (GUI.image_needs_scaling || GUI.interpolate == 5)
	    {
		GUI.box.x = 0;
		GUI.box.y = 0;
	    }
	    else
	    {
		GUI.box.x = (GUI.window_width - width) / 2;
		GUI.box.y = (GUI.window_height - cheight) / 2;
	    }

	    // Kreed's bi-linear image filter scales as well
	    if ((GUI.image_needs_scaling && GUI.interpolate != 5) ||
		(GUI.depth != 15 && GUI.depth != 16))
	    {
		GUI.output_screen = GUI.interpolated_screen;
		GUI.output_pitch = 512 * 2;
	    }
	    else
	    {
#ifdef USE_DGA_EXTENSION
		if (XF86.is_full_screen)
		{
		    if (XF86.scale)
			GUI.image_date = (uint8 *) XF86.vram;
		    else
		    {
			GUI.box.x = (XF86.window_width - width) / 2;
			GUI.box.y = (XF86.window_height - cheight) / 2;
			GUI.image_date = (uint8 *) XF86.vram +
				GUI.box.x * GUI.bytes_per_pixel +
				GUI.box.y * GUI.bytes_per_line;
		    }
		    GUI.output_screen = GUI.image_date;
		    GUI.output_pitch = GUI.bytes_per_line;
		    done = TRUE;
		}
		else
#endif
		{
		    GUI.output_screen = (uint8 *) GUI.image->data;
		    GUI.output_pitch = GUI.image->bytes_per_line;
		}
	    }

	    if (snes_width != GUI.last_snes_width ||
		snes_height != GUI.last_snes_height)
	    {
		memset (GUI.delta_screen, 255, GFX.Pitch * snes_height);
	    }
	    TVMode (snes_width, snes_height);
	}
    }
    else
    {
	GUI.output_screen = GFX.Screen;
	GUI.output_pitch = GFX.Pitch;
	width = snes_width;
	height = snes_height;
        cheight = (height>SNES_HEIGHT_EXTENDED)?SNES_HEIGHT_EXTENDED<<1:SNES_HEIGHT_EXTENDED;

	if (GUI.image_needs_scaling)
	{
	    GUI.box.x = 0;
	    GUI.box.y = 0;
	}
	else
	{
	    GUI.box.x = (GUI.window_width - width) / 2;
	    GUI.box.y = (GUI.window_height - cheight) / 2;
	}
    }

    if ((Settings.SixteenBit && GUI.depth != 15 && GUI.depth != 16) ||
	(!Settings.SixteenBit && (!GUI.pseudo || GUI.depth != 8)) ||
	(GUI.image_needs_scaling && !(Settings.SixteenBit && GUI.interpolate == 5)))
    {
	done = TRUE;
	switch (GUI.depth)
	{
	case 8:
	    if (Settings.SixteenBit)
		Convert16To8 (width, height);
	    else
		Scale8 (width, height);
	    break;

	case 15:
	case 16:
	    if (!Settings.SixteenBit)
		Convert8To16 (width, height);
	    else
		Scale16 (width, height);
	    break;

	case 32:
	case 24:
	    if (Settings.SixteenBit)
	    {
		if (GUI.image->bits_per_pixel == 32)
		    Convert16To24 (width, height);
		else
		    Convert16To24Packed (width, height);
	    }
	    else
	    {
		if (GUI.image->bits_per_pixel == 32)
		    Convert8To24 (width, height);
		else
		    Convert8To24Packed (width, height);
	    }
	    break;
	}
    }
    if (GUI.image_needs_scaling)
    {
	GUI.box.width = GUI.window_width;
	GUI.box.height = GUI.window_height;
    }
    else
    {
	GUI.box.width = width;
	GUI.box.height = height;
    }

#ifdef USE_DGA_EXTENSION
    if (XF86.is_full_screen && !done)
    {
	if (XF86.scale)
	    GUI.image_date = (uint8 *) XF86.vram;
	else
	    GUI.image_date = (uint8 *) XF86.vram +
		    ((XF86.window_width - width) / 2) * GUI.bytes_per_pixel +
		    ((XF86.window_height - cheight) / 2) * GUI.bytes_per_line;

	for (int y = 0; y < snes_height; y++)
	{
	    memmove (GUI.image_date + y * GUI.bytes_per_line,
		     GFX.Screen + GFX.Pitch * y,
		     snes_width * GUI.bytes_per_pixel);
	}
    }
#endif

#ifdef USE_DGA_EXTENSION
    if (!XF86.is_full_screen)
    {
#endif
#ifdef MITSHM
	if(GUI.use_shared_memory)
	{
	    XShmPutImage (GUI.display, GUI.window, GUI.gc, GUI.image,
			  0, 0, 
			  GUI.box.x, GUI.box.y,
			  GUI.box.width, GUI.box.height,
			  False);
	    XSync (GUI.display, False);
	}
	else
#endif
	    XPutImage (GUI.display, GUI.window, GUI.gc, GUI.image,
		       0, 0, 
		       GUI.box.x, GUI.box.y,
		       GUI.box.width, GUI.box.height);
#ifdef USE_DGA_EXTENSION
    }
#endif

    GUI.last_snes_width = snes_width;
    GUI.last_snes_height = snes_height;

    if (GUI.box.x != GUI.old_box.x || GUI.box.y != GUI.old_box.y ||
	GUI.box.width != GUI.old_box.width || GUI.box.height != GUI.old_box.height)
    {
	// If the rendered image has changed size/position clear any areas of the
	// screen that should now be border
	Region old_box = XCreateRegion ();
	Region new_box = XCreateRegion ();

	XUnionRectWithRegion (&GUI.old_box, old_box, old_box);
	XUnionRectWithRegion (&GUI.box, new_box, new_box);
	XSubtractRegion (old_box, new_box, old_box);
	if (!XEmptyRegion (old_box))
	{
	    Window window = GUI.window;
	    XRectangle clip;

	    XClipBox (old_box, &clip);
	    XSetRegion (GUI.display, GUI.gc, old_box);
	    XSetForeground (GUI.display, GUI.gc, GUI.depth == 8 ? 0 :
			    BlackPixelOfScreen (GUI.screen));
#ifdef USE_DGA_EXTENSION
	    if (XF86.full_screen_available)
		window = XF86.fs_window;
#endif
	    XFillRectangle (GUI.display, window, GUI.gc, 
			    clip.x, clip.y, clip.width, clip.height);
	    XSetClipMask (GUI.display, GUI.gc, None);
	}
	
	XDestroyRegion (new_box);
	XDestroyRegion (old_box);
	GUI.old_box = GUI.box;
    }

    Window root, child;
    int root_x, root_y;
    int x, y;
    unsigned int mask;

    // Use QueryPointer to sync X server and as a side effect also gets
    // current pointer position for SNES mouse emulation.
    XQueryPointer (GUI.display, GUI.window, &root, &child, &root_x, &root_y,
		   &x, &y, &mask);

    if (IPPU.Controller == SNES_SUPERSCOPE)
    {
	if (!GUI.superscope)
	{
	    XDefineCursor (GUI.display, GUI.window, GUI.cross_hair_cursor);
#ifdef USE_DGA_EXTENSION
	    if (XF86.is_full_screen)
		XDefineCursor (GUI.display, GUI.window, GUI.cross_hair_cursor);
#endif
	    GUI.superscope = TRUE;
	}
    }
    else
    if (GUI.superscope)
    {
	XDefineCursor (GUI.display, GUI.window, GUI.point_cursor);
#ifdef USE_DGA_EXTENSION
	if (XF86.is_full_screen)
	    XDefineCursor (GUI.display, GUI.window, GUI.point_cursor);
#endif
	GUI.superscope = FALSE;
    }
    if (x >= 0 && y >= 0 && GUI.window_width && y < GUI.window_height)
    {
        GUI.mouse_x = x * width / GUI.window_width;  /* Scale to SNES's. */
        GUI.mouse_y = y * height / GUI.window_height;
	if (mask & Mod1Mask)
	{
	    IPPU.PrevMouseX [0] = IPPU.PrevMouseX [1] = GUI.mouse_x;
	    IPPU.PrevMouseY [0] = IPPU.PrevMouseY [1] = GUI.mouse_y;
	    if (!GUI.mod1_pressed)
	    {
		GUI.mod1_pressed = TRUE;
		XDefineCursor (GUI.display, GUI.window, GUI.cross_hair_cursor);
#ifdef USE_DGA_EXTENSION
		if (XF86.is_full_screen)
		    XDefineCursor (GUI.display, GUI.window, GUI.cross_hair_cursor);
#endif
	    }
	}
	else
	if (GUI.mod1_pressed)
	{
	    GUI.mod1_pressed = FALSE;
	    if (!GUI.superscope)
	    {
		XDefineCursor (GUI.display, GUI.window, GUI.point_cursor);
#ifdef USE_DGA_EXTENSION
		if (XF86.is_full_screen)
		    XDefineCursor (GUI.display, GUI.window, GUI.point_cursor);
#endif
	    }
	}
	GUI.mouse_buttons = ((mask & 0x100) >> 8) | ((mask & 0x200) >> 7) |
			((mask & 0x400) >> 9) | ((mask & 0x800) >> 8);
    }
    }
}

void S9xSetPalette ()
{
#if defined(USE_GLIDE) || defined(USE_AIDO)
    if (Settings.GlideEnable || Settings.AIDOShmId)
	return;
#endif

    int i;

    if (GUI.grayscale)
    {
	uint16 Brightness = IPPU.MaxBrightness;
	    
	for (i = 0; i < 256; i++)
	{
	    GUI.colors[i].flags = DoRed | DoGreen | DoBlue;
	    GUI.colors[i].red = GUI.colors[i].green = GUI.colors[i].blue = 
		(uint16)(((((PPU.CGDATA[i] >> 0) & 0x1F) * Brightness * 50) +
		        (((PPU.CGDATA[i] >> 5) & 0x1F) * Brightness * 69) +
			(((PPU.CGDATA[i] >> 10) & 0x1F) * Brightness * 21)) * 1.40935);
	}
	XStoreColors (GUI.display, GUI.cmap, GUI.colors, 256);
    }
    else
    if (GUI.pseudo)
    {
	if (Settings.SixteenBit)
	{
	    for (i = 0; i < 256; i++)
	    {
		GUI.colors[i].flags = DoRed | DoGreen | DoBlue;
		GUI.colors[i].red = GUI.fixed_colours[i].red << 11;
		GUI.colors[i].green = GUI.fixed_colours[i].green << 11;
		GUI.colors[i].blue = GUI.fixed_colours[i].blue << 11;
	    }
	}
	else
	{
	    uint16 Brightness = (IPPU.MaxBrightness) * 140;
	    
	    for (i = 0; i < 256; i++)
	    {
		GUI.colors[i].flags = DoRed | DoGreen | DoBlue;
		GUI.colors[i].red = ((PPU.CGDATA[i] >> 0) & 0x1F) * Brightness;
		GUI.colors[i].green = ((PPU.CGDATA[i] >> 5) & 0x1F) * Brightness;
		GUI.colors[i].blue = ((PPU.CGDATA[i] >> 10) & 0x1F) * Brightness;
	    }
	}
	XStoreColors (GUI.display, GUI.cmap, GUI.colors, 256);
    }
}

const char *S9xSelectFilename (const char *def, const char *dir1,
			    const char *ext1, const char *title)
{
    static char path [PATH_MAX];
    char buffer [PATH_MAX];
    
    XAutoRepeatOn (GUI.display);

    printf ("\n%s (default: %s): ", title, def);
    fflush (stdout);
    if (fgets (buffer, sizeof (buffer) - 1, stdin))
    {
        //XAutoRepeatOff (GUI.display);

	char *p = buffer;
	while (isspace (*p))
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
	return (path);
    }

    //XAutoRepeatOff (GUI.display);

    return (NULL);
}

void Scale8 (int width, int height)
{
    register uint32 x_error;
    register uint32 x_fraction;
    uint32 y_error = 0;
    uint32 y_fraction;
    int yy = height - 1;
    
    x_fraction = (width * 0x10000) / GUI.window_width;
    y_fraction = (height * 0x10000) / GUI.window_height;
    
    for (int y = GUI.window_height - 1; y >= 0; y--)
    {
	register uint8 *d = (uint8 *) GUI.image_date + y * GUI.bytes_per_line +
			   GUI.window_width - 1;
	register uint8 *s = GUI.output_screen + yy * GUI.output_pitch + width - 1;
	y_error += y_fraction;
	while (y_error >= 0x10000)
	{
	    yy--;
	    y_error -= 0x10000;
	}
	x_error = 0;
	for (register int x = GUI.window_width - 1; x >= 0; x--)
	{
	    *d-- = *s;
	    x_error += x_fraction;

	    while (x_error >= 0x10000)
	    {
		s--;
		x_error -= 0x10000;
	    }
	}
    }
}

void Scale16 (int width, int height)
{
    register uint32 x_error;
    register uint32 x_fraction;
    uint32 y_error = 0;
    uint32 y_fraction;
    int yy = height - 1;
    
    x_fraction = (width * 0x10000) / GUI.window_width;
    y_fraction = (height * 0x10000) / GUI.window_height;
    
    for (int y = GUI.window_height - 1; y >= 0; y--)
    {
	register uint16 *d = (uint16 *) (GUI.image_date + y * GUI.bytes_per_line) +
					 GUI.window_width - 1;
	register uint16 *s = (uint16 *) (GUI.output_screen + yy * GUI.output_pitch) + width - 1;
	y_error += y_fraction;
	while (y_error >= 0x10000)
	{
	    yy--;
	    y_error -= 0x10000;
	}
	x_error = 0;
	for (register int x = GUI.window_width - 1; x >= 0; x--)
	{
	    *d-- = *s;
	    x_error += x_fraction;

	    while (x_error >= 0x10000)
	    {
		s--;
		x_error -= 0x10000;
	    }
	}
    }
}

void Convert8To24 (int width, int height)
{
    uint32 brightness = IPPU.MaxBrightness >> 1;

    if (!GUI.image_needs_scaling)
    {
	// Convert
	for (register int y = 0; y < height; y++)
	{
	    register uint32 *d = (uint32 *) (GUI.image_date +
					     y * GUI.bytes_per_line);
	    register uint8 *s = GUI.output_screen + y * GUI.output_pitch;

	    for (register int x = 0; x < width; x++)
	    {
		uint32 pixel = PPU.CGDATA [*s++];
		*d++ = (((pixel & 0x1f) * brightness) << GUI.red_shift) |
		       ((((pixel >> 5) & 0x1f) * brightness) << GUI.green_shift) |
		       ((((pixel >> 10) & 0x1f) * brightness) << GUI.blue_shift);
	    }
	}
    }
    else
    {
	// Scale and convert
	register uint32 x_error;
	register uint32 x_fraction;
	uint32 y_error = 0;
	uint32 y_fraction;
	int yy = 0;
	
	x_fraction = (width * 0x10000) / GUI.window_width;
	y_fraction = (height * 0x10000) / GUI.window_height;
	
	for (int y = 0; y < GUI.window_height; y++)
	{
	    register uint32 *d = (uint32 *) (GUI.image_date +
					   y * GUI.bytes_per_line);
	    register uint8 *s = GUI.output_screen + yy * GUI.output_pitch;
	    y_error += y_fraction;
	    while (y_error >= 0x10000)
	    {
		yy++;
		y_error -= 0x10000;
	    }
	    x_error = 0;
	    for (register int x = 0; x < GUI.window_width; x++)
	    {
		uint32 pixel = PPU.CGDATA [*s];
		*d++ = (((pixel & 0x1f) * brightness) << GUI.red_shift) |
		       ((((pixel >> 5) & 0x1f) * brightness) << GUI.green_shift) |
		       ((((pixel >> 10) & 0x1f) * brightness) << GUI.blue_shift);
		       
		x_error += x_fraction;
		while (x_error >= 0x10000)
		{
		    s++;
		    x_error -= 0x10000;
		}
	    }
	}
    }
}

void Convert16To24 (int width, int height)
{
    if (!GUI.image_needs_scaling)
    {
	// Convert
	for (register int y = 0; y < height; y++)
	{
	    register uint32 *d = (uint32 *) (GUI.image_date +
					     y * GUI.bytes_per_line);
	    register uint16 *s = (uint16 *) (GUI.output_screen + y * GUI.output_pitch);

	    for (register int x = 0; x < width; x++)
	    {
		uint32 pixel = *s++;
		*d++ = (((pixel >> 11) & 0x1f) << (GUI.red_shift + 3)) |
		       (((pixel >> 6) & 0x1f) << (GUI.green_shift + 3)) |
		       ((pixel & 0x1f) << (GUI.blue_shift + 3));
	    }
	}
    }
    else
    {
	// Scale and convert
	register uint32 x_error;
	register uint32 x_fraction;
	uint32 y_error = 0;
	uint32 y_fraction;
	int yy = 0;
	
	x_fraction = (width * 0x10000) / GUI.window_width;
	y_fraction = (height * 0x10000) / GUI.window_height;
	
	for (int y = 0; y < GUI.window_height; y++)
	{
	    register uint32 *d = (uint32 *) (GUI.image_date +
					     y * GUI.bytes_per_line);
	    register uint16 *s = (uint16 *) (GUI.output_screen + yy * GUI.output_pitch);
	    y_error += y_fraction;
	    while (y_error >= 0x10000)
	    {
		yy++;
		y_error -= 0x10000;
	    }
	    x_error = 0;
	    for (register int x = 0; x < GUI.window_width; x++)
	    {
		uint32 pixel = *s;
		*d++ = (((pixel >> 11) & 0x1f) << (GUI.red_shift + 3)) |
		       (((pixel >> 6) & 0x1f) << (GUI.green_shift + 3)) |
		       ((pixel & 0x1f) << (GUI.blue_shift + 3));
		       
		x_error += x_fraction;
		while (x_error >= 0x10000)
		{
		    s++;
		    x_error -= 0x10000;
		}
	    }
	}
    }
}

void Convert8To24Packed (int width, int height)
{
    uint32 brightness = IPPU.MaxBrightness >> 1;
    uint8 levels [32];

    for (int l = 0; l < 32; l++)
	levels [l] = l * brightness;
	
    if (!GUI.image_needs_scaling)
    {
	// Convert
	for (register int y = 0; y < height; y++)
	{
	    register uint8 *d = (uint8 *) (GUI.image_date + y * GUI.bytes_per_line);
	    register uint8 *s = GUI.output_screen + y * GUI.output_pitch;

#ifdef LSB_FIRST
	    if (GUI.red_shift < GUI.blue_shift)
#else	    
	    if (GUI.red_shift > GUI.blue_shift)
#endif
	    {
		// Order is RGB
		for (register int x = 0; x < width; x++)
		{
		    uint16 pixel = PPU.CGDATA [*s++];
		    *d++ = levels [(pixel & 0x1f)];
		    *d++ = levels [((pixel >> 5) & 0x1f)];
		    *d++ = levels [((pixel >> 10) & 0x1f)];
		}
	    }
	    else
	    {
		// Order is BGR
		for (register int x = 0; x < width; x++)
		{
		    uint16 pixel = PPU.CGDATA [*s++];
		    *d++ = levels [((pixel >> 10) & 0x1f)];
		    *d++ = levels [((pixel >> 5) & 0x1f)];
		    *d++ = levels [(pixel & 0x1f)];
		}
	    }
	}
    }
    else
    {
	// Scale and convert
	register uint32 x_error;
	register uint32 x_fraction;
	uint32 y_error = 0;
	uint32 y_fraction;
	int yy = 0;
	
	x_fraction = (width * 0x10000) / GUI.window_width;
	y_fraction = (height * 0x10000) / GUI.window_height;
	
	for (int y = 0; y < GUI.window_height; y++)
	{
	    register uint8 *d = (uint8 *) (GUI.image_date +
					 y * GUI.bytes_per_line);
	    register uint8 *s = GUI.output_screen + yy * GUI.output_pitch;
	    y_error += y_fraction;
	    while (y_error >= 0x10000)
	    {
		yy++;
		y_error -= 0x10000;
	    }
	    x_error = 0;
#ifdef LSB_FIRST
	    if (GUI.red_shift < GUI.blue_shift)
#else
	    if (GUI.red_shift > GUI.blue_shift)
#endif
	    {
		// Order is RGB
		for (register int x = 0; x < GUI.window_width; x++)
		{
		    uint16 pixel = PPU.CGDATA [*s];
		    *d++ = levels [(pixel & 0x1f)];
		    *d++ = levels [((pixel >> 5) & 0x1f)];
		    *d++ = levels [((pixel >> 10) & 0x1f)];
		       
		    x_error += x_fraction;
		    while (x_error >= 0x10000)
		    {
			s++;
			x_error -= 0x10000;
		    }
		}
	    }
	    else
	    {
		// Order is BGR
		for (register int x = 0; x < GUI.window_width; x++)
		{
		    uint16 pixel = PPU.CGDATA [*s];
		    *d++ = levels [((pixel >> 10) & 0x1f)];
		    *d++ = levels [((pixel >> 5) & 0x1f)];
		    *d++ = levels [(pixel & 0x1f)];
		       
		    x_error += x_fraction;
		    while (x_error >= 0x10000)
		    {
			s++;
			x_error -= 0x10000;
		    }
		}
	    }
	}
    }
}

void Convert16To24Packed (int width, int height)
{
    if (!GUI.image_needs_scaling)
    {
	// Convert
	for (register int y = 0; y < height; y++)
	{
	    register uint8 *d = (uint8 *) (GUI.image_date +
					 y * GUI.bytes_per_line);
	    register uint16 *s = (uint16 *) (GUI.output_screen + y * GUI.output_pitch);

#ifdef LSB_FIRST
	    if (GUI.red_shift < GUI.blue_shift)
#else	    
	    if (GUI.red_shift > GUI.blue_shift)
#endif
	    {
		// Order is RGB
		for (register int x = 0; x < width; x++)
		{
		    uint32 pixel = *s++;
		    *d++ = (pixel >> (11 - 3)) & 0xf8;
		    *d++ = (pixel >> (6 - 3)) & 0xf8;
		    *d++ = (pixel & 0x1f) << 3;
		}
	    }
	    else
	    {
		// Order is BGR
		for (register int x = 0; x < width; x++)
		{
		    uint32 pixel = *s++;
		    *d++ = (pixel & 0x1f) << 3;
		    *d++ = (pixel >> (6 - 3)) & 0xf8;
		    *d++ = (pixel >> (11 - 3)) & 0xf8;
		}
	    }
	}
    }
    else
    {
	// Scale and convert
	register uint32 x_error;
	register uint32 x_fraction;
	uint32 y_error = 0;
	uint32 y_fraction;
	int yy = 0;
	
	x_fraction = (width * 0x10000) / GUI.window_width;
	y_fraction = (height * 0x10000) / GUI.window_height;
	
	for (int y = 0; y < GUI.window_height; y++)
	{
	    register uint8 *d = (uint8 *) (GUI.image_date +
					 y * GUI.bytes_per_line);
	    register uint16 *s = (uint16 *) (GUI.output_screen + yy * GUI.output_pitch);
	    y_error += y_fraction;
	    while (y_error >= 0x10000)
	    {
		yy++;
		y_error -= 0x10000;
	    }
	    x_error = 0;
#ifdef LSB_FIRST
	    if (GUI.red_shift < GUI.blue_shift)
#else
	    if (GUI.red_shift > GUI.blue_shift)
#endif
	    {
		// Order is RGB
		for (register int x = 0; x < GUI.window_width; x++)
		{
		    uint32 pixel = *s;
		    *d++ = (pixel >> (11 - 3)) & 0xf8;
		    *d++ = (pixel >> (6 - 3)) & 0xf8;
		    *d++ = (pixel & 0x1f) << 3;
		       
		    x_error += x_fraction;
		    while (x_error >= 0x10000)
		    {
			s++;
			x_error -= 0x10000;
		    }
		}
	    }
	    else
	    {
		// Order is BGR
		for (register int x = 0; x < GUI.window_width; x++)
		{
		    uint32 pixel = *s;
		    *d++ = (pixel & 0x1f) << 3;
		    *d++ = (pixel >> (6 - 3)) & 0xf8;
		    *d++ = (pixel >> (11 - 3)) & 0xf8;
		       
		    x_error += x_fraction;
		    while (x_error >= 0x10000)
		    {
			s++;
			x_error -= 0x10000;
		    }
		}
	    }
	}
    }
}

void Convert16To8 (int width, int height)
{
    if (!GUI.image_needs_scaling)
    {
	// Convert
	for (register int y = 0; y < height; y++)
	{
	    register uint8 *d = (uint8 *) GUI.image_date + y * GUI.bytes_per_line;
	    register uint16 *s = (uint16 *) (GUI.output_screen + y * GUI.output_pitch);

	    for (register int x = 0; x < width; x++)
		*d++ = GUI.palette [*s++];
	}
    }
    else
    {
	// Scale and convert
	register uint32 x_error;
	register uint32 x_fraction;
	uint32 y_error = 0;
	uint32 y_fraction;
	int yy = 0;
	
	x_fraction = (width * 0x10000) / GUI.window_width;
	y_fraction = (height * 0x10000) / GUI.window_height;
	
	for (int y = 0; y < GUI.window_height; y++)
	{
	    register uint8 *d = (uint8 *) GUI.image_date + y * GUI.bytes_per_line;
	    register uint16 *s = (uint16 *) (GUI.output_screen + yy * GUI.output_pitch);
	    y_error += y_fraction;
	    while (y_error >= 0x10000)
	    {
		yy++;
		y_error -= 0x10000;
	    }
	    x_error = 0;
	    for (register int x = 0; x < GUI.window_width; x++)
	    {
		*d++ = GUI.palette [*s];
		       
		x_error += x_fraction;
		while (x_error >= 0x10000)
		{
		    s++;
		    x_error -= 0x10000;
		}
	    }
	}
    }
}

void Convert8To16 (int width, int height)
{
    uint32 levels [32];

    for (int l = 0; l < 32; l++)
	levels [l] = (l * IPPU.MaxBrightness) >> 4;
	
    if (!GUI.image_needs_scaling)
    {
	// Convert
	for (register int y = 0; y < height; y++)
	{
	    register uint16 *d = (uint16 *) (GUI.image_date + y * GUI.bytes_per_line);
	    register uint8 *s = GUI.output_screen + y * GUI.output_pitch;

	    for (register int x = 0; x < width; x++)
	    {
		uint32 pixel = PPU.CGDATA [*s++];
		*d++ = (levels [pixel & 0x1f] << GUI.red_shift) |
		       (levels [(pixel >> 5) & 0x1f] << GUI.green_shift) |
		       (levels [(pixel >> 10) & 0x1f] << GUI.blue_shift);
	    }
	}
    }
    else
    {
	// Scale and convert
	register uint32 x_error;
	register uint32 x_fraction;
	uint32 y_error = 0;
	uint32 y_fraction;
	int yy = 0;
	
	x_fraction = (width * 0x10000) / GUI.window_width;
	y_fraction = (height * 0x10000) / GUI.window_height;
	
	for (int y = 0; y < GUI.window_height; y++)
	{
	    register uint16 *d = (uint16 *) (GUI.image_date +
					   y * GUI.bytes_per_line);
	    register uint8 *s = GUI.output_screen + yy * GUI.output_pitch;
	    y_error += y_fraction;
	    while (y_error >= 0x10000)
	    {
		yy++;
		y_error -= 0x10000;
	    }
	    x_error = 0;
	    for (register int x = 0; x < GUI.window_width; x++)
	    {
		uint32 pixel = PPU.CGDATA [*s];
		*d++ = (levels [pixel & 0x1f] << GUI.red_shift) |
		       (levels [(pixel >> 5) & 0x1f] << GUI.green_shift) |
		       (levels [(pixel >> 10) & 0x1f] << GUI.blue_shift);
		       
		x_error += x_fraction;
		while (x_error >= 0x10000)
		{
		    s++;
		    x_error -= 0x10000;
		}
	    }
	}
    }
}

void S9xTextMode ()
{
#ifdef USE_AIDO
    if (Settings.AIDOShmId)
        return;
#endif
#ifdef USE_DGA_EXTENSION
    if (XF86.full_screen_available && XF86.is_full_screen)
    {
	XF86DGADirectVideo (GUI.display, GUI.screen_num, 0);
#ifdef USE_VIDMODE_EXTENSION
	if (XF86.switch_video_mode)
	    XF86VidModeSwitchToMode (GUI.display, GUI.screen_num, &XF86.orig);
#endif
	XUngrabKeyboard (GUI.display, CurrentTime);
	XUngrabPointer (GUI.display, CurrentTime);
	XUnmapWindow (GUI.display, XF86.fs_window);
	XWarpPointer (GUI.display, None, GUI.window, 0, 0, 0, 0, 0, 0);
	XSync (GUI.display, False);
    }
#endif
    XAutoRepeatOn (GUI.display);
}

void S9xGraphicsMode ()
{
#ifdef USE_AIDO
    if (Settings.AIDOShmId)
        return;
#endif
#ifdef USE_DGA_EXTENSION
    if (XF86.full_screen_available && XF86.is_full_screen)
    {
	XMapRaised (GUI.display, XF86.fs_window);
	XClearWindow (GUI.display, XF86.fs_window);
	XGrabKeyboard (GUI.display, GUI.window, False, GrabModeAsync, GrabModeAsync,
		       CurrentTime);
	XGrabPointer (GUI.display, GUI.window, False, ALL_DEVICE_EVENTS,
		      GrabModeAsync, GrabModeAsync, GUI.window, GUI.point_cursor,
		      CurrentTime);

	XWarpPointer (GUI.display, None, RootWindowOfScreen (GUI.screen),
		      0, 0, 0, 0, 0, 0);
	XSync (GUI.display, False);

#ifdef USE_VIDMODE_EXTENSION
	if (XF86.switch_video_mode)
	{
	    XF86VidModeSwitchToMode (GUI.display, GUI.screen_num, XF86.best);
	    XF86DGAGetVideo (GUI.display, GUI.screen_num, &XF86.vram,
			     &XF86.line_width, &XF86.bank_size,
			     &XF86.size);
	    XF86VidModeSetViewPort (GUI.display, GUI.screen_num, 0, 0);
	    XSync (GUI.display, False);
	}
#endif
	XF86DGADirectVideo (GUI.display, GUI.screen_num, XF86DGADirectGraphics);
	XF86VidModeSetViewPort (GUI.display, GUI.screen_num, 0, 0);
	XSync (GUI.display, False);

	//memset (XF86.vram, 0, XF86.size * 1024);
    }
#endif
    //XAutoRepeatOff (GUI.display);
}

void S9xParseDisplayArg (char **argv, int &ind, int)
{
    if (strncasecmp (argv [ind], "-y", 2) == 0)
    {
	Settings.SixteenBit = TRUE;
        Settings.SupportHiRes = TRUE;
        Settings.ForceTransparency = TRUE;
	switch (argv[ind][2])
	{
	case 0:	    GUI.interpolate = TRUE;	break;
	case '1':   GUI.interpolate = TRUE;	break;
	case '2':   GUI.interpolate = 2;	break;
	case '3':   GUI.interpolate = 3;	break;
	case '4':   GUI.interpolate = 4;	break;
	case '5':   GUI.interpolate = 5;	break;
	}
    }
    else
    if (strncasecmp (argv [ind], "-GUI.interpolate", 12) == 0)
    {
	Settings.SixteenBit = TRUE;
        Settings.SupportHiRes = TRUE;
        Settings.ForceTransparency = TRUE;
	switch (argv[ind][12])
	{
	case 0:	    GUI.interpolate = TRUE;	break;
	case '1':   GUI.interpolate = TRUE;	break;
	case '2':   GUI.interpolate = 2;	break;
	case '3':   GUI.interpolate = 3;	break;
	case '4':   GUI.interpolate = 4;	break;
	case '5':   GUI.interpolate = 5;	break;
	}
    }
    else
    if (strcasecmp (argv [ind], "-scale") == 0 ||
	strcasecmp (argv [ind], "-sc") == 0)
    {
#ifdef USE_DGA_EXTENSION
	XF86.scale = TRUE;
#endif
	GUI.scale = TRUE;
    }
#ifdef USE_DGA_EXTENSION
#ifdef USE_VIDMODE_EXTENSION
    else
    if (strcasecmp (argv [ind], "-nms") == 0 ||
	strcasecmp (argv [ind], "-nomodeswitch") == 0)
	XF86.no_mode_switch = TRUE;
#endif
    else
    if (strcasecmp (argv [ind], "-fs") == 0 ||
	strcasecmp (argv [ind], "-fullscreen") == 0)
	XF86.start_full_screen = TRUE;
#endif
    else
	S9xUsage ();
}

void S9xExtraUsage ()
{
}

int S9xMinCommandLineArgs ()
{
    return (2);
}

void S9xMessage (int /*type*/, int /*number*/, const char *message)
{
#define MAX_MESSAGE_LEN (36 * 3)

    static char buffer [MAX_MESSAGE_LEN + 1];

    fprintf (stdout, "%s\n", message);
    strncpy (buffer, message, MAX_MESSAGE_LEN);
    buffer [MAX_MESSAGE_LEN] = 0;
    S9xSetInfoString (buffer);
}

void TVMode (int width, int height)
{
    switch (width != 256 && GUI.interpolate != 5 ? 1 : GUI.interpolate)
    {
    case 2:
	Super2xSaI (GFX.Screen, GFX.Pitch, GUI.delta_screen, GUI.output_screen,
		    GUI.output_pitch, width, height);
	break;
    case 3:
	SuperEagle (GFX.Screen, GFX.Pitch, GUI.delta_screen, GUI.output_screen,
		    GUI.output_pitch, width, height);
	break;
    case 4:
	_2xSaI (GFX.Screen, GFX.Pitch, GUI.delta_screen, GUI.output_screen,
		GUI.output_pitch, width, height);
	break;
    case 5:
#ifdef USE_DGA_EXTENSION
	if (XF86.is_full_screen && !XF86.scale)
	{
	    Scale_2xSaI (GFX.Screen, GFX.Pitch, GUI.delta_screen, GUI.output_screen,
			 GUI.output_pitch, IMAGE_WIDTH, IMAGE_HEIGHT, width, height);
	}
	else
#endif
	Scale_2xSaI (GFX.Screen, GFX.Pitch, GUI.delta_screen, GUI.output_screen,
		     GUI.output_pitch, GUI.window_width, GUI.window_height, width, height);
	break;
    case 1:
    {
	uint8 *nextLine, *srcPtr, *deltaPtr, *finish;
	uint8 *dstPtr;
	uint32 colorMask = ~(RGB_LOW_BITS_MASK | (RGB_LOW_BITS_MASK << 16));
	uint32 lowPixelMask = RGB_LOW_BITS_MASK;

	srcPtr = GFX.Screen;
	deltaPtr = GUI.delta_screen;
	dstPtr = GUI.output_screen;
	nextLine = GUI.output_screen + GUI.output_pitch;

	if (width == 256)
	{
	    do
	    {
		uint32 *bP = (uint32 *) srcPtr;
		uint32 *xP = (uint32 *) deltaPtr;
		uint32 *dP = (uint32 *) dstPtr;
		uint32 *nL = (uint32 *) nextLine;
		uint32 currentPixel;
		uint32 nextPixel;
		uint32 currentDelta;
		uint32 nextDelta;

		finish = (uint8 *) bP + ((width + 2) << 1);
		nextPixel = *bP++;
		nextDelta = *xP++;

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
#ifdef LSB_FIRST
			colorA = currentPixel & 0xffff;
#else
			colorA = (currentPixel & 0xffff0000) >> 16;
#endif

#ifdef LSB_FIRST
			colorB = (currentPixel & 0xffff0000) >> 16;
			*(dP) = product = colorA |
					  ((((colorA & colorMask) >> 1) +
					    ((colorB & colorMask) >> 1) +
					    (colorA & colorB & lowPixelMask)) << 16);
#else
			colorB = currentPixel & 0xffff;
			*(dP) = product = (colorA << 16) | 
					  (((colorA & colorMask) >> 1) +
					   ((colorB & colorMask) >> 1) +
					   (colorA & colorB & lowPixelMask));
#endif
                        if(IPPU.RenderedScreenHeight<=SNES_HEIGHT_EXTENDED){
                            darkened = (product = ((product & colorMask) >> 1));
                            darkened += (product = ((product & colorMask) >> 1));
                            darkened += (product & colorMask) >> 1;
                            *(nL) = darkened;
                        }

#ifdef LSB_FIRST
			colorA = nextPixel & 0xffff;
			*(dP + 1) = product = colorB |
					      ((((colorA & colorMask) >> 1) +
						((colorB & colorMask) >> 1) +
						(colorA & colorB & lowPixelMask)) << 16);
#else
			colorA = (nextPixel & 0xffff0000) >> 16;
			*(dP + 1) = product = (colorB << 16) | 
					       (((colorA & colorMask) >> 1) +
						((colorB & colorMask) >> 1) + 
						(colorA & colorB & lowPixelMask));
#endif
                        if(IPPU.RenderedScreenHeight<=SNES_HEIGHT_EXTENDED){
                            darkened = (product = ((product & colorMask) >> 1));
                            darkened += (product = ((product & colorMask) >> 1));
                            darkened += (product & colorMask) >> 1;
                            *(nL + 1) = darkened;
                        }
		    }

		    dP += 2;
		    nL += 2;
		}
		while ((uint8 *) bP < finish);

		deltaPtr += GFX.Pitch;
		srcPtr += GFX.Pitch;
                if(IPPU.RenderedScreenHeight<=SNES_HEIGHT_EXTENDED){
                    dstPtr += GUI.output_pitch * 2;
                    nextLine += GUI.output_pitch * 2;
                } else {
                    dstPtr += GUI.output_pitch;
                    nextLine += GUI.output_pitch;
                }
	    }
	    while (--height);
	}
	else
	{
	    do
	    {
		uint32 *bP = (uint32 *) srcPtr;
		uint32 *xP = (uint32 *) deltaPtr;
		uint32 *dP = (uint32 *) dstPtr;
		uint32 currentPixel;

		finish = (uint8 *) bP + ((width + 2) << 1);

		do
		{
		    currentPixel = *bP++;

		    if (currentPixel != *xP++)
		    {
			uint32 product, darkened;

			*(xP - 1) = currentPixel;
			*dP = currentPixel;
                        if(IPPU.RenderedScreenHeight<=SNES_HEIGHT_EXTENDED){
                            darkened = (product = ((currentPixel & colorMask) >> 1));
                            darkened += (product = ((product & colorMask) >> 1));
                            darkened += (product & colorMask) >> 1;
                            *(uint32 *) ((uint8 *) dP + GUI.output_pitch) = darkened;
                        }
		    }

		    dP++;
		}
		while ((uint8 *) bP < finish);

		deltaPtr += GFX.Pitch;
		srcPtr += GFX.Pitch;
                if(IPPU.RenderedScreenHeight<=SNES_HEIGHT_EXTENDED){
                    dstPtr += GUI.output_pitch * 2;
                } else {
                    dstPtr += GUI.output_pitch;
                }
	    }
	    while (--height);
	}
    }
    }
}

#ifdef USE_DGA_EXTENSION
void CreateFullScreenWindow ()
{
    int major, minor;

    XF86.full_screen_available = False;

    if (XF86DGAQueryVersion (GUI.display, &major, &minor))
    {
	int fd;

	// Need to test for access to /dev/mem here because XF86DGAGetVideo
	// just calls exit if it can't access this device.
	if ((fd = open ("/dev/mem", O_RDWR) < 0))
	{
	    perror ("Can't open \"/dev/mem\", full screen mode not available");
	    return;
	}
	else
	    close (fd);

	XF86DGAGetVideo (GUI.display, GUI.screen_num, &XF86.vram,
			 &XF86.line_width, &XF86.bank_size,
			 &XF86.size);

	XF86.full_screen_available = True;

	XSetWindowAttributes attributes;

	attributes.override_redirect = True;
	attributes.background_pixel = BlackPixelOfScreen (GUI.screen);
	XF86.fs_window = XCreateWindow (GUI.display, RootWindowOfScreen (GUI.screen),
				   0, 0, WidthOfScreen (GUI.screen), 
				   HeightOfScreen (GUI.screen),
				   0, GUI.depth,
				   InputOutput, GUI.visual, 
				   CWOverrideRedirect | CWBackPixel,
				   &attributes);

	XF86.window_width = WidthOfScreen (GUI.screen);
	XF86.window_height = HeightOfScreen (GUI.screen);

#ifdef USE_VIDMODE_EXTENSION
	XF86VidModeModeLine current;
	int dot_clock;

	if (!XF86.no_mode_switch &&
	    XF86VidModeGetAllModeLines (GUI.display, GUI.screen_num,
					&XF86.num_modes,
					&XF86.all_modes) &&
	    XF86VidModeGetModeLine (GUI.display, GUI.screen_num,
				    &dot_clock, &current))
	{
	    int i;

	    XF86.orig.dotclock = dot_clock;
	    XF86.orig.hdisplay = current.hdisplay;
	    XF86.orig.hdisplay = current.hdisplay;
	    XF86.orig.hsyncstart = current.hsyncstart;
	    XF86.orig.hsyncend = current.hsyncend;
	    XF86.orig.htotal = current.htotal;
	    XF86.orig.vdisplay = current.vdisplay;
	    XF86.orig.vsyncstart = current.vsyncstart;
	    XF86.orig.vsyncend = current.vsyncend;
	    XF86.orig.vtotal = current.vtotal;
	    XF86.orig.flags = current.flags;
	    XF86.orig.c_private = current.c_private;
	    XF86.orig.privsize = current.privsize;

	    int best_width_so_far = current.hdisplay;
	    int best_height_so_far = current.vdisplay;
	    XF86.best = NULL;
	    XF86.switch_video_mode = False;
	    
	    for (i = 0; i < XF86.num_modes; i++)
	    {
		if (XF86.all_modes [i]->hdisplay >= IMAGE_WIDTH &&
		    XF86.all_modes [i]->hdisplay <= best_width_so_far &&
		    XF86.all_modes [i]->vdisplay >= IMAGE_HEIGHT &&
		    XF86.all_modes [i]->vdisplay <= best_height_so_far &&
		    (XF86.all_modes [i]->hdisplay != current.hdisplay ||
		     XF86.all_modes [i]->vdisplay != current.vdisplay))
		{
		    best_width_so_far = XF86.all_modes [i]->hdisplay;
		    best_height_so_far = XF86.all_modes [i]->vdisplay;
		    XF86.best = XF86.all_modes [i];
		}
	    }
	    if (XF86.best)
		XF86.switch_video_mode = True;
	    else
		XF86.best = &XF86.orig;

	    XF86.window_width = XF86.best->hdisplay;
	    XF86.window_height = XF86.best->vdisplay;
	}
#endif
    }
}

void S9xSwitchToFullScreen (bool8 enable)
{
    if (XF86.full_screen_available && enable != XF86.is_full_screen)
    {
	S9xTextMode ();
	XF86.is_full_screen = enable;
	if (GUI.delta_screen)
	{
	    uint32 *p = (uint32 *) GUI.delta_screen;
	    uint32 *q = (uint32 *) (GUI.delta_screen + GFX.Pitch * 478);
	    while (p < q)
		*p++ ^= ~0;
	}
	S9xGraphicsMode ();

	if (enable)
	{
	    XF86.saved_image_needs_scaling = GUI.image_needs_scaling;
	    XF86.saved_window_width = GUI.window_width;
	    XF86.saved_window_height = GUI.window_height;
	    GUI.bytes_per_line = XF86.line_width * GUI.bytes_per_pixel;

	    if (XF86.scale)
	    {
		GUI.image_date = (uint8 *) XF86.vram;
		GUI.window_width = XF86.window_width;
		GUI.window_height = XF86.window_height;
		GUI.image_needs_scaling = TRUE;
	    }
	    else
	    {
		// Centre image in available width/height
		GUI.image_date = (uint8 *) XF86.vram +
			     ((XF86.window_width - IMAGE_WIDTH) / 2) * GUI.bytes_per_pixel +
			     ((XF86.window_height - IMAGE_HEIGHT) / 2) * GUI.bytes_per_line;
		GUI.image_needs_scaling = FALSE;
	    }
	}
	else
	{
	    GUI.image_needs_scaling = XF86.saved_image_needs_scaling;
	    GUI.window_width = XF86.saved_window_width;
	    GUI.window_height = XF86.saved_window_height;
	    GUI.image_date = (uint8 *) GUI.image->data;
	    GUI.bytes_per_line = GUI.image->bytes_per_line;
	}
    }
}
#endif

void S9xDisplayStateChange (const char *str, bool8 on)
{
    static char string [100];

    sprintf (string, "%s %s", str, on ? "on" : "off");
    S9xInfoMessage (string);
}

#ifdef USE_GLIDE
void S9xSwitchToGlideMode (bool8 enable)
{
    S9xGlideEnable (enable);
    if (Settings.GlideEnable)
	XGrabKeyboard (GUI.display, GUI.window, True, GrabModeAsync, GrabModeAsync,
		       CurrentTime);
    else
	XUngrabKeyboard (GUI.display, CurrentTime);
}
#endif

