

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <dirent.h>
#include <errno.h>
#include <zlib.h>
#include "unzip.h"
#include "zip.h"

#ifdef __GIZ__
#define TIMER_1_SECOND	1000
#include <unistd.h>
#include <w32api/GizSdk/FrameworkAudio.h>
#include "giz_sdk.h"
#endif

#ifdef __GP2X__
#define TIMER_1_SECOND	1000000
#include "gp2x_sdk.h"
#include "squidgehack.h"
#endif

#include "menu.h"
#include "snes9x.h"
#include "memmap.h"
#include "apu.h"
#include "gfx.h"
#include "soundux.h"
#include "snapshot.h"


#define EMUVERSION "SquidgeSNES V0.37 01-Jun-06"

//---------------------------------------------------------------------------

#ifdef __GP2X__
extern "C" char joy_Count();
extern "C" int InputClose();
extern "C" int joy_getButton(int joyNumber);
#endif

unsigned char gammatab[10][32]={
	{0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F,
	0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,0x1F},
	{0x00,0x01,0x02,0x03,0x04,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F,0x10,
	0x11,0x12,0x13,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,0x1F},
	{0x00,0x01,0x03,0x04,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F,0x10,0x11,
	0x12,0x13,0x14,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1A,0x1B,0x1C,0x1D,0x1E,0x1F},
	{0x00,0x02,0x04,0x06,0x07,0x08,0x09,0x0A,0x0C,0x0D,0x0E,0x0F,0x0F,0x10,0x11,0x12,
	0x13,0x14,0x15,0x16,0x16,0x17,0x18,0x19,0x19,0x1A,0x1B,0x1C,0x1C,0x1D,0x1E,0x1F},
	{0x00,0x03,0x05,0x07,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F,0x10,0x11,0x12,0x13,0x14,
	0x14,0x15,0x16,0x17,0x17,0x18,0x19,0x19,0x1A,0x1B,0x1B,0x1C,0x1D,0x1D,0x1E,0x1F},
	{0x00,0x05,0x07,0x09,0x0B,0x0C,0x0D,0x0E,0x0F,0x10,0x11,0x12,0x13,0x14,0x14,0x15,
	0x16,0x16,0x17,0x18,0x18,0x19,0x1A,0x1A,0x1B,0x1B,0x1C,0x1C,0x1D,0x1D,0x1E,0x1F},
	{0x00,0x07,0x0A,0x0C,0x0D,0x0E,0x10,0x11,0x12,0x12,0x13,0x14,0x15,0x15,0x16,0x17,
	0x17,0x18,0x18,0x19,0x1A,0x1A,0x1B,0x1B,0x1B,0x1C,0x1C,0x1D,0x1D,0x1E,0x1E,0x1F},
	{0x00,0x0B,0x0D,0x0F,0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x16,0x17,0x17,0x18,0x18,
	0x19,0x19,0x1A,0x1A,0x1B,0x1B,0x1B,0x1C,0x1C,0x1D,0x1D,0x1D,0x1E,0x1E,0x1E,0x1F},
	{0x00,0x0F,0x11,0x13,0x14,0x15,0x16,0x17,0x17,0x18,0x18,0x19,0x19,0x1A,0x1A,0x1A,
	0x1B,0x1B,0x1B,0x1C,0x1C,0x1C,0x1C,0x1D,0x1D,0x1D,0x1D,0x1E,0x1E,0x1E,0x1E,0x1F},
	{0x00,0x15,0x17,0x18,0x19,0x19,0x1A,0x1A,0x1B,0x1B,0x1B,0x1B,0x1C,0x1C,0x1C,0x1C,
	0x1D,0x1D,0x1D,0x1D,0x1D,0x1D,0x1D,0x1E,0x1E,0x1E,0x1E,0x1E,0x1E,0x1E,0x1E,0x1F}
};

int32 gp32_fastmode = 1;
int gp32_8bitmode = 0;
int32 gp32_ShowSub = 0;
int gp32_fastsprite = 1;
int gp32_gammavalue = 0;
int squidgetranshack = 0;
int globexit = 0;
int sndvolL, sndvolR;
char fps_display[256];
int samplecount=0;
int enterMenu = 0;
void *currentFrameBuffer;
int16 oldHeight = 0;

static int S9xCompareSDD1IndexEntries (const void *p1, const void *p2)
{
    return (*(uint32 *) p1 - *(uint32 *) p2);
}

void S9xExit ()
{
}
void S9xGenerateSound (void)
   {
      S9xMessage (0,0,"generate sound");
	   return;
   }

extern "C"
{
	void S9xSetPalette ()
	{

	}

	void S9xExtraUsage ()
	{
	}
	
	void S9xParseArg (char **argv, int &index, int argc)
	{	
	}

	bool8 S9xOpenSnapshotFile (const char *fname, bool8 read_only, STREAM *file)
	{
		if (read_only)
		{
			if (*file = OPEN_STREAM(fname,"rb")) 
				return(TRUE);
		}
		else
		{
			if (*file = OPEN_STREAM(fname,"w+b")) 
				return(TRUE);
		}

		return (FALSE);	
	}
	
	void S9xCloseSnapshotFile (STREAM file)
	{
		CLOSE_STREAM(file);
	}

   void S9xMessage (int /* type */, int /* number */, const char *message)
   {
		printf ("%s\n", message);
   }

   void erk (void)
   {
      S9xMessage (0,0, "Erk!");
   }

   char *osd_GetPackDir(void)
   {
      S9xMessage (0,0,"get pack dir");
      return ".";
   }

   const char *S9xGetSnapshotDirectory(void)
   {
      S9xMessage (0,0,"get snapshot dir");
      return ".";
   }

   void S9xLoadSDD1Data (void)
   {
    char filename [_MAX_PATH + 1];
    char index [_MAX_PATH + 1];
    char data [_MAX_PATH + 1];
    char patch [_MAX_PATH + 1];
	char text[256];
	//FILE *fs = fopen ("data.log", "w");

	Settings.SDD1Pack=TRUE;
    Memory.FreeSDD1Data();

    gp_clearFramebuffer16(framebuffer16[currFB],0x0);
    sprintf(text,"Loading SDD1 pack...");
	gp_drawString(0,0,strlen(text),text,0xFFFF,(unsigned char*)framebuffer16[currFB]);
	MenuFlip();
	strcpy (filename, romDir);

    if (strncmp (Memory.ROMName, "Star Ocean", 10) == 0)
	strcat (filename, "/socnsdd1");
    else
	strcat (filename, "/sfa2sdd1");

    DIR *dir = opendir (filename);

    index [0] = 0;
    data [0] = 0;
    patch [0] = 0;

 	//fprintf(fs,"SDD1 data: %s...\n",filename);
    if (dir)
    {
	struct dirent *d;
	
		while ((d = readdir (dir)))
		{
			//fprintf(fs,"File :%s.\n",d->d_name);
			if (strcasecmp (d->d_name, "sdd1gfx.idx") == 0)
			{
			strcpy (index, filename);
			strcat (index, "/");
			strcat (index, d->d_name);
			//fprintf(fs,"File :%s.\n",index);
			}
			else
			if (strcasecmp (d->d_name, "sdd1gfx.dat") == 0)
			{
			strcpy (data, filename);
			strcat (data, "/");
			strcat (data, d->d_name);
			//fprintf(fs,"File :%s.\n",data);
			}
			if (strcasecmp (d->d_name, "sdd1gfx.pat") == 0)
			{
			strcpy (patch, filename);
			strcat (patch, "/");
			strcat (patch, d->d_name);
			}
		}
		closedir (dir);
	
		if (strlen (index) && strlen (data))
		{
			FILE *fs = fopen (index, "rb");
			int len = 0;
	
			if (fs)
			{
			// Index is stored as a sequence of entries, each entry being
			// 12 bytes consisting of:
			// 4 byte key: (24bit address & 0xfffff * 16) | translated block
			// 4 byte ROM offset
			// 4 byte length
			fseek (fs, 0, SEEK_END);
			len = ftell (fs);
			rewind (fs);
			Memory.SDD1Index = (uint8 *) malloc (len);
			fread (Memory.SDD1Index, 1, len, fs);
			fclose (fs);
			Memory.SDD1Entries = len / 12;
	
			if (!(fs = fopen (data, "rb")))
			{
				free ((char *) Memory.SDD1Index);
				Memory.SDD1Index = NULL;
				Memory.SDD1Entries = 0;
			}
			else
			{
				fseek (fs, 0, SEEK_END);
				len = ftell (fs);
				rewind (fs);
				Memory.SDD1Data = (uint8 *) malloc (len);
				fread (Memory.SDD1Data, 1, len, fs);
				fclose (fs);
	
				if (strlen (patch) > 0 &&
				(fs = fopen (patch, "rb")))
				{
				fclose (fs);
				}
	#ifdef MSB_FIRST
				// Swap the byte order of the 32-bit value triplets on
				// MSBFirst machines.
				uint8 *ptr = Memory.SDD1Index;
				for (int i = 0; i < Memory.SDD1Entries; i++, ptr += 12)
				{
				SWAP_DWORD ((*(uint32 *) (ptr + 0)));
				SWAP_DWORD ((*(uint32 *) (ptr + 4)));
				SWAP_DWORD ((*(uint32 *) (ptr + 8)));
				}
	#endif
				qsort (Memory.SDD1Index, Memory.SDD1Entries, 12,
				   S9xCompareSDD1IndexEntries);
			}
			}
			Settings.SDD1Pack = FALSE;
			return;
		}
    }
	//fprintf(fs,"Decompressed data pack not found in '%s'\n",filename);
	//fclose(fs);
	gp_clearFramebuffer16(framebuffer16[currFB],0x0);
	sprintf(text,"Decompressed data pack not found!");
	gp_drawString(0,8,strlen(text),text,0xFFFF,(unsigned char*)framebuffer16[currFB]);
	MenuFlip();
	MenuPause();
   }

   

   bool8_32 S9xInitUpdate ()
   {
      static int needfskip = 0;
      
	  currFB++;
	  currFB&=3;
	  
	  if (snesMenuOptions.renderMode == RENDER_MODE_SCALED)
		GFX.Screen = (uint8 *) framebuffer16[currFB];
	  else if (PPU.ScreenHeight != SNES_HEIGHT_EXTENDED)
	    GFX.Screen = (uint8 *) framebuffer16[currFB]+ (640*8) + 64;
	  else
	    GFX.Screen = (uint8 *) framebuffer16[currFB]+ 64;
	  
	   return (TRUE);
   }

   bool8_32 S9xDeinitUpdate (int Width, int Height, bool8_32)
   {
      if (snesMenuOptions.showFps) 
	  {
			unsigned int *pix;
			pix=(unsigned int*)framebuffer16[currFB];
			for(int i=8;i;i--)
			{
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				*pix++ = 0x0;
				pix+=128;
			}
			gp_drawString(0,0,strlen(fps_display),fps_display,0xFFFF,(unsigned char*)framebuffer16[currFB]);
	  }
		if ( snesMenuOptions.renderMode == RENDER_MODE_SCALED && oldHeight!=Height)
		{
			gp2x_video_RGB_setscaling(256,Height);
			oldHeight=Height;
		}
    // TODO clear Z buffer if not in fastsprite mode
		gp_setFramebuffer(currFB,0);
   }

   const char *S9xGetFilename (const char *ex)
   {
      static char filename [PATH_MAX + 1];
      char drive [_MAX_DRIVE + 1];
      char dir [_MAX_DIR + 1];
      char fname [_MAX_FNAME + 1];
      char ext [_MAX_EXT + 1];

      _splitpath (Memory.ROMFilename, drive, dir, fname, ext);
      strcpy (filename, S9xGetSnapshotDirectory ());
      strcat (filename, SLASH_STR);
      strcat (filename, fname);
      strcat (filename, ex);

      return (filename);
   }

#ifdef __GIZ__
   uint32 S9xReadJoypad (int which1)
   {
	   uint32 val=0x80000000;

	   if (which1 != 0) return val;
		unsigned long joy = gp_getButton(0);
		 
		if (joy & (1<<INP_BUTTON_REWIND)) val |= SNES_Y_MASK;
		if (joy & (1<<INP_BUTTON_FORWARD)) val |= SNES_A_MASK;
		if (joy & (1<<INP_BUTTON_PLAY)) val |= SNES_B_MASK;
		if (joy & (1<<INP_BUTTON_STOP)) val |= SNES_X_MASK;
			
		if (joy & (1<<INP_BUTTON_UP)) val |= SNES_UP_MASK;
		if (joy & (1<<INP_BUTTON_DOWN)) val |= SNES_DOWN_MASK;
		if (joy & (1<<INP_BUTTON_LEFT)) val |= SNES_LEFT_MASK;
		if (joy & (1<<INP_BUTTON_RIGHT)) val |= SNES_RIGHT_MASK;
		if (joy & (1<<INP_BUTTON_HOME)) val |= SNES_START_MASK;
		if (joy & (1<<INP_BUTTON_VOL)) val |= SNES_SELECT_MASK;
		if (joy & (1<<INP_BUTTON_L)) val |= SNES_TL_MASK;
		if (joy & (1<<INP_BUTTON_R)) val |= SNES_TR_MASK;
		
		if (joy & (1<<INP_BUTTON_BRIGHT))	enterMenu = 1;
      return val;
   }
#endif

#ifdef __GP2X__
   uint32 S9xReadJoypad (int which1)
   {
	   uint32 val=0x80000000;
		unsigned long joy = 0;

		if (which1 == 0)
		{
			joy = gp_getButton(1);
		}
		else if (joy >= joy_Count()) return val;
		
		joy |= joy_getButton(which1++);
		      
		if (snesMenuOptions.actionButtons)
		{
			if (joy & (1<<INP_BUTTON_A)) val |= SNES_Y_MASK;
			if (joy & (1<<INP_BUTTON_B)) val |= SNES_A_MASK;
			if (joy & (1<<INP_BUTTON_X)) val |= SNES_B_MASK;
			if (joy & (1<<INP_BUTTON_Y)) val |= SNES_X_MASK;
		}
		else
		{
			if (joy & (1<<INP_BUTTON_A)) val |= SNES_A_MASK;
			if (joy & (1<<INP_BUTTON_B)) val |= SNES_B_MASK;
			if (joy & (1<<INP_BUTTON_X)) val |= SNES_X_MASK;
			if (joy & (1<<INP_BUTTON_Y)) val |= SNES_Y_MASK;
		}
			
		if (joy & (1<<INP_BUTTON_UP)) val |= SNES_UP_MASK;
		if (joy & (1<<INP_BUTTON_DOWN)) val |= SNES_DOWN_MASK;
		if (joy & (1<<INP_BUTTON_LEFT)) val |= SNES_LEFT_MASK;
		if (joy & (1<<INP_BUTTON_RIGHT)) val |= SNES_RIGHT_MASK;
		if (joy & (1<<INP_BUTTON_START)) val |= SNES_START_MASK;
		if (joy & (1<<INP_BUTTON_L)) val |= SNES_TL_MASK;
		if (joy & (1<<INP_BUTTON_R)) val |= SNES_TR_MASK;
		
		if (joy & (1<<INP_BUTTON_SELECT)) val |= SNES_SELECT_MASK;
		
		if ((joy & (1<<INP_BUTTON_VOL_UP)) && (joy & (1<<INP_BUTTON_VOL_DOWN)))	enterMenu = 1;
		else if (joy & (1<<INP_BUTTON_VOL_UP)) 
		{
			snesMenuOptions.volume+=1;
			if(snesMenuOptions.volume>100) snesMenuOptions.volume=100;
			gp2x_sound_volume(snesMenuOptions.volume,snesMenuOptions.volume);
		}
		else if (joy & (1<<INP_BUTTON_VOL_DOWN))	
		{
			snesMenuOptions.volume-=1;
			if(snesMenuOptions.volume>100) snesMenuOptions.volume=0;
			gp2x_sound_volume(snesMenuOptions.volume,snesMenuOptions.volume);
		}
		
      return val;
   }
#endif


   bool8 S9xReadMousePosition (int /* which1 */, int &/* x */, int & /* y */,
			    uint32 & /* buttons */)
   {
      S9xMessage (0,0,"read mouse");
      return (FALSE);
   }

   bool8 S9xReadSuperScopePosition (int & /* x */, int & /* y */,
				 uint32 & /* buttons */)
   {
      S9xMessage (0,0,"read scope");
      return (FALSE);
   }

   const char *S9xGetFilenameInc (const char *e)
   {
      S9xMessage (0,0,"get filename inc");
      return e;
   }

   void S9xSyncSpeed(void)
   {
      //S9xMessage (0,0,"sync speed");
   }

   const char *S9xBasename (const char *f)
   {
      const char *p;

      S9xMessage (0,0,"s9x base name");

      if ((p = strrchr (f, '/')) != NULL || (p = strrchr (f, '\\')) != NULL)
         return (p + 1);

      return (f);
   }

};

	
void S9xAutoSaveSRAM (void)
{
	//since I can't sync the data, there is no point in even writing the data
	//out at this point.  Instead I'm now saving the data as the users enter the menu.
	//Memory.SaveSRAM (S9xGetFilename (".srm"));
	//sync();  can't sync when emulator is running as it causes delays
}

void S9xLoadSRAM (void)
{
	char path[MAX_PATH];
	
	sprintf(path,"%s%s%s",snesSramDir,DIR_SEP,S9xGetFilename (".srm"));
	Memory.LoadSRAM (path);
}

void S9xSaveSRAM (void)
{
	char path[MAX_PATH];
	
	if (CPU.SRAMModified)
	{
		sprintf(path,"%s%s%s",snesSramDir,DIR_SEP,S9xGetFilename (".srm"));
		Memory.SaveSRAM (path);
		sync();
	}
}

bool JustifierOffscreen(void)
{
   return false;
}

void JustifierButtons(uint32& justifiers)
{
}

static int SnesRomLoad()
{
	char filename[MAX_PATH+1];
	int check;
	char text[256];
	FILE *stream=NULL;
  
    gp_clearFramebuffer16(framebuffer16[currFB],0x0);
	sprintf(text,"Loading Rom...");
	gp_drawString(0,0,strlen(text),text,0xFFFF,(unsigned char*)framebuffer16[currFB]);
	MenuFlip();
	S9xReset();
	
	// get full filename
	sprintf(filename,"%s%s%s",romDir,DIR_SEP,currentRomFilename);
	
	if (!Memory.LoadROM (filename))
	{
		sprintf(text,"Loading Rom...Failed");
		gp_drawString(0,0,strlen(text),text,0xFFFF,(unsigned char*)framebuffer16[currFB]);
		MenuFlip();
		MenuPause();
		return 0;
	}
	
	sprintf(text,"Loading Rom...OK!");
	gp_drawString(0,0,strlen(text),text,0xFFFF,(unsigned char*)framebuffer16[currFB]);
	sprintf(text,"Loading Sram");
	gp_drawString(0,8,strlen(text),text,0xFFFF,(unsigned char*)framebuffer16[currFB]);
	MenuFlip();
	
	//Memory.LoadSRAM (S9xGetFilename (".srm")); 
	S9xLoadSRAM();

	//auto load default config for this rom if one exists
	if (LoadMenuOptions(snesOptionsDir, currentRomFilename, MENU_OPTIONS_EXT, (char*)&snesMenuOptions, sizeof(snesMenuOptions),1))
	{
		//failed to load options for game, so load the default global ones instead
		if (LoadMenuOptions(snesOptionsDir, MENU_OPTIONS_FILENAME, MENU_OPTIONS_EXT, (char*)&snesMenuOptions, sizeof(snesMenuOptions),1))
		{
			//failed to load global options, so use default values
			SnesDefaultMenuOptions();
		}
	}
	
	gp_clearFramebuffer16(framebuffer16[currFB],0x0);
	
	return(1);
}

#ifdef __GIZ__
static int SegAim()
{

	int aim=FrameworkAudio_GetCurrentBank();
	return aim;
}
#endif

#ifdef __GP2X__
static int SegAim()
{
  int aim=CurrentSoundBank; 
  aim--; if (aim<0) aim+=8;

  return aim;
}
#endif


void _makepath (char *path, const char *, const char *dir,
	const char *fname, const char *ext)
{
	if (dir && *dir)
	{
		strcpy (path, dir);
		strcat (path, "/");
	}
	else
	*path = 0;
	strcat (path, fname);
	if (ext && *ext)
	{
		strcat (path, ".");
		strcat (path, ext);
	}
}

void _splitpath (const char *path, char *drive, char *dir, char *fname,
	char *ext)
{
	*drive = 0;

	char *slash = strrchr (path, '/');
	if (!slash)
		slash = strrchr (path, '\\');

	char *dot = strrchr (path, '.');

	if (dot && slash && dot < slash)
		dot = NULL;

	if (!slash)
	{
		strcpy (dir, "");
		strcpy (fname, path);
		if (dot)
		{
			*(fname + (dot - path)) = 0;
			strcpy (ext, dot + 1);
		}
		else
			strcpy (ext, "");
	}
	else
	{
		strcpy (dir, path);
		*(dir + (slash - path)) = 0;
		strcpy (fname, slash + 1);
		if (dot)
		{
			*(fname + (dot - slash) - 1) = 0;
			strcpy (ext, dot + 1);
		}
		else
			strcpy (ext, "");
	}
} 

// save state file I/O
int  (*statef_open)(const char *fname, const char *mode);
int  (*statef_read)(void *p, int l);
int  (*statef_write)(void *p, int l);
void (*statef_close)();
static FILE  *state_file = 0;
static char state_filename[MAX_PATH];
static char *state_mem = NULL;
static int state_mem_pos = 0;
static int state_mem_size=0;
static int state_mode = 0;

int check_zip(char *filename)
{
    uint8 buf[2];
    FILE *fd = NULL;
    fd = (FILE*)fopen(filename, "rb");
    if(!fd) return (0);
    fread(buf, 1, 2, fd);
    fclose(fd);
    if(memcmp(buf, "PK", 2) == 0) return (1);
    return (0);
}

static char *load_archive(char *filename, int *file_size)
{
    int size = 0;
    char *buf = NULL;
    char text[128];	

    unzFile fd = NULL;
    unz_file_info info;
    int ret = 0;
         
	/* Attempt to open the archive */
	fd = unzOpen(filename);
	if(!fd)
	{
		printf("Failed to open archive\r\n");
		return NULL;
	}

	/* Go to first file in archive */
	ret = unzGoToFirstFile(fd);
	if(ret != UNZ_OK)
	{
		printf("Failed to find first file in zip\r\n");
		unzClose(fd);
		return NULL;
	}

	ret = unzGetCurrentFileInfo(fd, &info, NULL, 0, NULL, 0, NULL, 0);
	if(ret != UNZ_OK)
	{
		printf("Failed to zip info\r\n");
        unzClose(fd);
        return NULL;
	}

	/* Open the file for reading */
	ret = unzOpenCurrentFile(fd);
	if(ret != UNZ_OK)
	{
	    printf("Failed to read file\r\n");
		unzClose(fd);
		return NULL;
	}

	/* Allocate file data buffer */
	size = info.uncompressed_size;
	buf=(char*)malloc(size);
	if(!buf)
	{
		printf("Failed to malloc zip buffer\r\n");
		unzClose(fd);
		return NULL;
	}
	
	/* Read (decompress) the file */
	ret = unzReadCurrentFile(fd, buf, info.uncompressed_size);
	if(ret != info.uncompressed_size)
	{
		free(buf);
	    printf("File failed to uncompress fully\r\n");
	    unzCloseCurrentFile(fd);
		unzClose(fd);
		return NULL;
	}

	/* Close the current file */
	ret = unzCloseCurrentFile(fd);
	if(ret != UNZ_OK)
	{
		free(buf);
	    printf("Failed to close file in zip\r\n");
	    unzClose(fd);
		return NULL;
	}

	/* Close the archive */
	ret = unzClose(fd);
	if(ret != UNZ_OK)
	{
		free(buf);
	    printf("Failed to close zip\r\n");
	    return NULL;
	}

	/* Update file size and return pointer to file data */
	*file_size = size;
	return buf;
}

static int save_archive(char *filename, char *buffer, int size)
{
    uint8 *buf = NULL;
    char text[128]="";	
    zipFile fd = NULL;
    int ret = 0;
    fd=zipOpen(filename,0);
    if(!fd)
    {
       printf("Failed to create zip\r\n");
       return (0);
    }

    ret=zipOpenNewFileInZip(fd,"SNAPSHOT",
			    NULL,
				NULL,0,
			    NULL,0,
			    NULL,
			    Z_DEFLATED,
			    Z_BEST_COMPRESSION);
			    
    if(ret != ZIP_OK)
    {
       zipClose(fd,NULL);
       printf("Failed to create file in zip\r\n");
       return (0);    
    }

    ret=zipWriteInFileInZip(fd,buffer,size);
    if(ret != ZIP_OK)
    {
      zipCloseFileInZip(fd);
      zipClose(fd,NULL);
      printf("Failed to write file in zip\r\n");
      return (0);
    }

    ret=zipCloseFileInZip(fd);
    if(ret != ZIP_OK)
    {
      zipClose(fd,NULL);
      printf("Failed to close file in zip\r\n");
      return (0);
    }

    ret=zipClose(fd,NULL);
    if(ret != ZIP_OK)
    {
      printf("Failed to close zip\r\n");
      return (0);
    }
	
    return(1);
}

int state_unc_open(const char *fname, const char *mode)
{
	//mode = "wb"  or "rb"
	//If mode is write then create a new buffer to hold written data
	//when file is closed buffer will be compressed to zip file and then freed
	if(mode[0]=='r')
	{
		//Read mode requested
		if(check_zip((char*)fname))
		{
			//File is a zip, so uncompress
			printf("state is zipped\r\n");
			state_mode = 1; //zip mode
			state_mem=load_archive((char*)fname,&state_mem_size);
			if(!state_mem) return 0;
			state_mem_pos=0;
			strcpy(state_filename,fname);
			printf("Unzipped ok\r\n");
			return 1;
		}
		else
		{
			state_mode = 0; //normal file mode
			state_file = fopen(fname, mode);
			return (int) state_file;
		}
	}
	else
	{
		printf("open file to write\r\n");
		//Write mode requested. Zip only option
		state_mode = 1; //normal file mode
		state_mem=(char*)malloc(200);
		state_mem_size=200;
		state_mem_pos = 0;
		strcpy(state_filename,fname);
		return 1;
	}
}

int state_unc_read(void *p, int l)
{
	if(state_mode==0)
	{
		return fread(p, 1, l, state_file);
	}
	else
	{
		
		if((state_mem_pos+l)>state_mem_size)
		{
			//Read requested that exceeded memory limits
			printf("read req:%d act:%d\r\n",l,0);
			return 0;
		}
		else
		{
			memcpy(p,state_mem+state_mem_pos,l);
			state_mem_pos+=l;
			printf("read req:%d act:%d\r\n",l,l);
		}
		return l;
	}
}

int state_unc_write(void *p, int l)
{
	printf("write file\r\n");
	if(state_mode==0)
	{
		return fwrite(p, 1, l, state_file);
	}
	else
	{
		printf("ok\r\n");
		if((state_mem_pos+l)>state_mem_size)
		{
			printf("realloc\r\n");
			//Write will exceed current buffer, re-alloc buffer and continue
			state_mem=(char*)realloc(state_mem,state_mem_pos+l);
			state_mem_size=state_mem_pos+l;
		}
		printf("do write\r\n");
		//Now do write
		memcpy(state_mem+state_mem_pos,p,l);
		state_mem_pos+=l;
		printf("leaving\r\n");
		return l;
	}
}

void state_unc_close()
{
	if(state_mode==0)
	{
		fclose(state_file);
	}
	else
	{
		printf("f:%s\r\n",state_filename);
		save_archive(state_filename,state_mem,state_mem_size);
		free(state_mem);
		state_mem=NULL;
		state_mem_size=0;
		state_mem_pos=0;
		state_filename[0]=0;
	}
}

char **g_argv;
int main(int argc, char *argv[])
{
 	unsigned int i,j = 0;
	unsigned int romrunning = 0;
	int aim=0, done=0, skip=0, Frames=0, fps=0, tick=0,efps=0;
	uint8 *soundbuffer=NULL;
	int Timer=0;
	int action=0;
	int romloaded=0;
	char text[256];
	bool8  ROMAPUEnabled = 0;
	DIR *d;
	
	g_argv = argv;
	
	// saves
	statef_open  = state_unc_open;
	statef_read  = state_unc_read;
	statef_write = state_unc_write;
	statef_close = state_unc_close;
	
	

	getcwd(currentWorkingDir, MAX_PATH);
	CheckDirSep(currentWorkingDir);

	sprintf(snesOptionsDir,"%s%s%s",currentWorkingDir,DIR_SEP,SNES_OPTIONS_DIR);
	sprintf(snesSramDir,"%s%s%s",currentWorkingDir,DIR_SEP,SNES_SRAM_DIR);
	sprintf(snesSaveStateDir,"%s%s%s",currentWorkingDir,DIR_SEP,SNES_SAVESTATE_DIR);

	
	InputInit();  // clear input context

	//ensure dirs exist
	//should really check if these worked but hey whatever
	mkdir(snesOptionsDir,0777);
	mkdir(snesSramDir,0777);
	mkdir(snesSaveStateDir,0777);

	printf("Loading global menu options\r\n"); fflush(stdout);
	if (LoadMenuOptions(snesOptionsDir,MENU_OPTIONS_FILENAME,MENU_OPTIONS_EXT,(char*)&snesMenuOptions, sizeof(snesMenuOptions),0))
	{
		// Failed to load menu options so default options
		printf("Failed to load global options, so using defaults\r\n"); fflush(stdout);
		SnesDefaultMenuOptions();
	}
	
	printf("Loading default rom directory\r\n"); fflush(stdout);
	if (LoadMenuOptions(snesOptionsDir,DEFAULT_ROM_DIR_FILENAME,DEFAULT_ROM_DIR_EXT,(char*)snesRomDir, MAX_PATH,0))
	{
		// Failed to load options to default rom directory to current working directory
		printf("Failed to default rom dir, so using current dir\r\n"); fflush(stdout);
		strcpy(snesRomDir,currentWorkingDir);
	}
	
	//Check that rom directory actually exists
	d = opendir(romDir);
	if(d)
	{
		closedir(d);
	}
	else
	{
		//Failed to open Rom directory, so reset to current directory
		strcpy(snesRomDir,currentWorkingDir);
	}
	
	// Init graphics (must be done before MMUHACK)
	gp_initGraphics(16,0,snesMenuOptions.mmuHack);
	
#ifdef __GP2X__
	if (snesMenuOptions.ramSettings)
	{
		printf("Craigs RAM settings are enabled.  Now applying settings..."); fflush(stdout);
		// craigix: --trc 6 --tras 4 --twr 1 --tmrd 1 --trfc 1 --trp 2 --trcd 2
		set_RAM_Timings(6, 4, 1, 1, 1, 2, 2);
		printf("Done\r\n"); fflush(stdout);
	}
	else
	{
		printf("Using normal Ram settings.\r\n"); fflush(stdout);
	}

	set_gamma(snesMenuOptions.gamma+100);
#endif

	UpdateMenuGraphicsGamma();
	
	// Initialise Snes stuff
	ZeroMemory (&Settings, sizeof (Settings));

	Settings.JoystickEnabled = FALSE;
	Settings.SoundPlaybackRate = 22050;
	Settings.Stereo = FALSE;
	Settings.SoundBufferSize = 0;
	Settings.CyclesPercentage = 100;
	Settings.DisableSoundEcho = FALSE;
	Settings.APUEnabled = FALSE;
	Settings.H_Max = SNES_CYCLES_PER_SCANLINE;
	Settings.SkipFrames = AUTO_FRAMERATE;
	Settings.Shutdown = Settings.ShutdownMaster = TRUE;
	Settings.FrameTimePAL = 20000;
	Settings.FrameTimeNTSC = 16667;
	Settings.FrameTime = Settings.FrameTimeNTSC;
	Settings.DisableSampleCaching = FALSE;
	Settings.DisableMasterVolume = FALSE;
	Settings.Mouse = FALSE;
	Settings.SuperScope = FALSE;
	Settings.MultiPlayer5 = FALSE;
	//	Settings.ControllerOption = SNES_MULTIPLAYER5;
	Settings.ControllerOption = 0;
	
	Settings.ForceTransparency = FALSE;
	Settings.Transparency = FALSE;
	Settings.SixteenBit = TRUE;
	
	Settings.SupportHiRes = FALSE;
	Settings.NetPlay = FALSE;
	Settings.ServerName [0] = 0;
	Settings.AutoSaveDelay = 30;
	Settings.ApplyCheats = FALSE;
	Settings.TurboMode = FALSE;
	Settings.TurboSkipFrames = 15;
	Settings.ThreadSound = FALSE;
	Settings.SoundSync = FALSE;
	//Settings.NoPatch = true;		

	//GFX.RealPitch = GFX.Pitch = 318 * 2;
	
	GFX.Pitch = 320 * 2;
	GFX.RealPitch = 320 * 2;
	GFX.Screen = (uint8 *) framebuffer16[currFB];
	
	GFX.SubScreen = (uint8 *)malloc(GFX.RealPitch * 480 * 2); 
	GFX.ZBuffer =  (uint8 *)malloc(GFX.RealPitch * 480 * 2); 
	GFX.SubZBuffer = (uint8 *)malloc(GFX.RealPitch * 480 * 2);
	GFX.Delta = (GFX.SubScreen - GFX.Screen) >> 1;
	GFX.PPL = GFX.Pitch >> 1;
	GFX.PPLx2 = GFX.Pitch;
	GFX.ZPitch = GFX.Pitch >> 1;
	
	if (Settings.ForceNoTransparency)
         Settings.Transparency = FALSE;

	if (Settings.Transparency)
         Settings.SixteenBit = TRUE;

	Settings.HBlankStart = (256 * Settings.H_Max) / SNES_HCOUNTER_MAX;

	if (!Memory.Init () || !S9xInitAPU())
         erk();

	S9xInitSound ();
	
	//S9xSetRenderPixelFormat (RGB565);
	S9xSetSoundMute (TRUE);

	if (!S9xGraphicsInit ())
         erk();
         	
	while (1)
	{
		
		S9xSetSoundMute (TRUE);
		action=MainMenu(action);
		gp_clearFramebuffer16(framebuffer16[currFB],0x0);
		if (action==EVENT_EXIT_APP) break;
		
		if (action==EVENT_LOAD_SNES_ROM)
		{
			// user wants to load a rom
			romloaded=SnesRomLoad();
			if(romloaded)  	
			{
				#ifdef ASM_SPC700
				ROMAPUEnabled = Settings.APUEnabled;
				#endif
				action=EVENT_RUN_SNES_ROM;   // rom loaded okay so continue with emulation
			}
			else
				action=0;   // rom failed to load so return to menu
		}

		if (action==EVENT_RESET_SNES_ROM)
		{
			// user wants to reset current game
			S9xReset();
			action=EVENT_RUN_SNES_ROM;
		}

		if (action==EVENT_RUN_SNES_ROM)
		{		
			// any change in configuration?
			gp_setCpuspeed(cpuSpeedLookup[snesMenuOptions.cpuSpeed]);
			gp_clearFramebuffer16(framebuffer16[0],0x0);
			gp_clearFramebuffer16(framebuffer16[1],0x0);
			gp_clearFramebuffer16(framebuffer16[2],0x0);
			gp_clearFramebuffer16(framebuffer16[3],0x0);
			
			Settings.os9x_hack = snesMenuOptions.graphHacks;
			if (snesMenuOptions.transparency)
			{
				Settings.Transparency = TRUE;
				Settings.SixteenBit = TRUE;
			}
			else
			{
				Settings.Transparency = FALSE;
				Settings.SixteenBit = TRUE;
			}
			switch (snesMenuOptions.region)
			{
				case 0:				
					Settings.ForceNTSC = Settings.ForcePAL = FALSE;
					if (Memory.HiROM)
					// Country code
					Settings.PAL = ROM [0xffd9] >= 2;
					else
					Settings.PAL = ROM [0x7fd9] >= 2;
				break;
				case 1:
						Settings.ForceNTSC = TRUE;
						Settings.PAL = Settings.ForcePAL= FALSE;
				break;
				case 2:
						Settings.ForceNTSC = FALSE;
						Settings.PAL = Settings.ForcePAL= TRUE;
				break;
			}
			Settings.FrameTime = Settings.PAL?Settings.FrameTimePAL:Settings.FrameTimeNTSC;
			Memory.ROMFramesPerSecond = Settings.PAL?50:60;
			
			oldHeight = 0;
			
			if (!S9xGraphicsInit ())
				erk();
		 
			if (snesMenuOptions.soundOn)
			{
				unsigned int frame_limit = (Settings.PAL?50:60);
				unsigned int aimCheck=0;
				gp32_fastmode = 1;
				gp32_8bitmode = 0;
				gp32_ShowSub = 0;
				gp32_fastsprite = 1;
				gp32_gammavalue = snesMenuOptions.gamma;
				squidgetranshack = 0;
				if (snesMenuOptions.soundHack)
					CPU.APU_APUExecuting = Settings.APUEnabled = 3;
				else
				CPU.APU_APUExecuting = Settings.APUEnabled = ROMAPUEnabled | 1;
				Settings.SoundPlaybackRate=(unsigned int)soundRates[snesMenuOptions.soundRate];
				Settings.SixteenBitSound=true;
				Settings.Stereo=snesMenuOptions.stereo;
				samplecount=Settings.SoundPlaybackRate/frame_limit;
				if (Settings.Stereo)
					samplecount = samplecount * 2;
				gp_initSound(Settings.SoundPlaybackRate,16,Settings.Stereo,frame_limit,0x0002000F);
				so.stereo = Settings.Stereo;
				so.playback_rate = Settings.SoundPlaybackRate;
				S9xSetPlaybackRate(so.playback_rate);
				S9xSetSoundMute (FALSE);
#if defined(__GP2X__)
				SoundThreadFlag = SOUND_THREAD_SOUND_ON;
#endif
				gp2x_sound_volume(snesMenuOptions.volume,snesMenuOptions.volume);
				
				while (1)
				{   	
					for (i=10;i;i--)
					{
						Timer=gp2x_timer_read();
					    if(Timer-tick>TIMER_1_SECOND)
						{
					       fps=Frames;
					       Frames=0;
					       tick=Timer;
					       sprintf(fps_display,"Fps: %d",fps);
				        }
						else if (Timer<tick) 
						{
							// should never happen but I'm seeing problems where the FPS stops updating
							tick=Timer; // start timeing again, maybe Timer value has wrapped around?
						}
						
						//Limit emulation speed
						//This stop us from going to fast
						//We never want to be rendering audio into the bank
						//that is currently being played
						aim=SegAim();
						if (done!=aim)
						{
							//We need to render more audio:  
#ifdef __GIZ__
							soundbuffer=(uint8 *)FrameworkAudio_GetAudioBank(done);
#endif
#ifdef __GP2X__
							soundbuffer=(uint8 *)pOutput[done];
#endif
							done++; if (done>=8) done=0;
							if(snesMenuOptions.frameSkip==0)
							{
#if defined(__GIZ__)
								int aim1;
								int aim2;
								int aim3;
								aim1=aim-1;
								if(aim1<0) aim1+=7;
								aim2=aim-2;
								if(aim2<0) aim2+=7;
								aim3=aim-3;
								if(aim3<0) aim3+=7;
								//If we start to get to slow the audio buffer will start
								//to catch us up.  So we need to skip frames in order to
								//catch up the real time rendering
								if(
									(done==aim) || // we up right up to speed to render frame
									(done==aim1) || // we are 1 bank behind so still okay
									(done==aim2) || // we are 2 banks behind so just about ok
									(done==aim3)  // we are 3 banks behind so getting dodgy
									)
								{
									IPPU.RenderThisFrame=TRUE; // Render last frame
									Frames++;	
								}
	
#endif
#if defined(__GP2X__)
								if ((done==aim)) 
								{
									IPPU.RenderThisFrame=TRUE; // Render last frame
									Frames++;
								}
#endif
								else           IPPU.RenderThisFrame=FALSE;
							}
							else
							{
								if (skip) 
								{
									IPPU.RenderThisFrame=FALSE;
									skip--;
								}
								else 
								{  
									IPPU.RenderThisFrame=TRUE;
									Frames++;
									skip=snesMenuOptions.frameSkip-1;
								}
							}

							S9xMainLoop (); 
							S9xMixSamples((short*)soundbuffer, samplecount);
						}
						if (done==aim) break; // Up to date now
					}
#if defined (__GP2X__)					
					done=aim; // Make sure up to date
#endif					
					// need some way to exit menu
					if (enterMenu)
						break;
				}
				enterMenu=0;
				gp_stopSound();
			}
			else
			{
				int quit=0,ticks=0,now=0,done=0,i=0;
				int tick=0,fps=0;
				unsigned int frame_limit = (Settings.PAL?50:60);
				unsigned int frametime=TIMER_1_SECOND/frame_limit;
				CPU.APU_APUExecuting = Settings.APUEnabled = 0;
				S9xSetSoundMute (TRUE);
				Timer=0;
				Frames=0;
				while (1)
				{
					Timer=gp2x_timer_read()/frametime;
					if(Timer-tick>frame_limit)
				    {
				       fps=Frames;
				       Frames=0;
				       tick=Timer;
				       sprintf(fps_display,"Fps: %d",fps);
				    }
					else if (Timer<tick) 
					{
						// should never happen but I'm seeing problems where the FPS stops updating
						tick=Timer; // start timeing again, maybe Timer value has wrapped around?
					}
					
				    now=Timer;
				    ticks=now-done;
				    
				    if(ticks<1) continue;
				    if(snesMenuOptions.frameSkip==0)
				    {
				       if(ticks>10) ticks=10;
				       for (i=0; i<ticks-1; i++)
				       {
						  IPPU.RenderThisFrame=FALSE; // Render last frame
						  S9xMainLoop (); 
				       } 
				       if(ticks>=1)
				       {
							IPPU.RenderThisFrame=TRUE; // Render last frame
							Frames++;
							S9xMainLoop (); 							
						}
					}
					else
					{
					   if(ticks>(snesMenuOptions.frameSkip-1)) ticks=snesMenuOptions.frameSkip-1;
					   for (i=0; i<ticks-1; i++)
					   {
							IPPU.RenderThisFrame=FALSE; // Render last frame
							S9xMainLoop (); 
					   } 
					   if(ticks>=1)
					   {
							IPPU.RenderThisFrame=TRUE; // Render last frame
							Frames++;
							S9xMainLoop (); 
					   }
					}
					    
					    done=now;
						
					// need some way to exit menu
					if (enterMenu)
						break;
				}
				enterMenu=0;
			}
			if (snesMenuOptions.autoSram)
			{
				S9xSaveSRAM();
			}
		}
	}
	set_gamma(100);
	
#if defined(__GP2X__)
	InputClose();
#endif	
	gp_Reset();
	
#if 0
	//Just a delay so I can read the printf messages
	i=0;
	j=0;
	while(j<0x1000)
	{
		i++;
		if(i>0xFFFF)
		{
			j++;
			i=0;
		}
	}
#endif	
	return 0;
}
