#ifndef _MENU_H_
#define _MENU_H_

#ifdef __cplusplus
extern "C" {
#endif



#ifdef __GIZ__
#define DIR_SEP	"\\"
#define DIR_SEP_BAD "/"	
#define SYSTEM_DIR		"\\SD Card\\DrPocketSnes"
#endif

#ifdef __GP2X__
#include "gp2x_sdk.h"

#define DIR_SEP	"/"
#define DIR_SEP_BAD "\\"	
#define SYSTEM_DIR		"/mnt/sd/DrPocketSnes"
#endif




#define SNES_OPTIONS_DIR		"options"
#define SNES_SRAM_DIR			"sram"
#define SNES_SAVESTATE_DIR		"savestate"

#define ROM_LIST_FILENAME			"romlist.bin"
#define SRAM_FILE_EXT				"srm"
#define SAVESTATE_EXT				"sv"
#define MENU_OPTIONS_FILENAME		"menu"
#define MENU_OPTIONS_EXT			"opt"
#define DEFAULT_ROM_DIR_FILENAME	"romdir"
#define DEFAULT_ROM_DIR_EXT			"opt"


//define emulation modes
#define EMU_MODE_NONE	0
#define EMU_MODE_SNES 	1

#define SAVESTATE_MODE_SAVE				0
#define SAVESTATE_MODE_LOAD				1
#define SAVESTATE_MODE_DELETE			2

#define SNES_OPTIONS_VER 			1
#define DRSNES_VERSION				"version 6.4.4"

#define ROM_SIZE 		0x500000 //ssf2(40mbits)
#define MENU_RGB(r,g,b) 		((r) << 11 | (g) << 6 | (b) << 0 )
#define MAX_ROMS		3000
#define MAX_CPU			39
#ifndef MAX_PATH
#define MAX_PATH    			255
#endif

#define MENU_CPU_SPEED 			100
#define MENU_FAST_CPU_SPEED		200

enum  FILE_TYPE_ENUM
{
	FILE_TYPE_FILE = 0,
	FILE_TYPE_DIRECTORY
};

enum  MAIN_MENU_ENUM
{
	MAIN_MENU_RETURN = 0,
	MAIN_MENU_ROM_SELECT,
	MAIN_MENU_MANAGE_SAVE_STATE,
	MAIN_MENU_SAVE_SRAM,
	MAIN_MENU_SNES_OPTIONS,
	MAIN_MENU_RESET_GAME,
	MAIN_MENU_EXIT_APP,
	MAIN_MENU_COUNT
};

enum  LOAD_ROM_ENUM
{
	LOAD_ROM_MENU_SNES = 0,
	LOAD_ROM_MENU_RETURN,
	LOAD_ROM_MENU_COUNT
};

enum SNES_MENU_ENUM
{
	SNES_MENU_SOUND = 0,
	SNES_MENU_SOUND_RATE,
	SNES_MENU_SOUND_VOL,
	SNES_MENU_FRAMESKIP,
	SNES_MENU_REGION,
	SNES_MENU_FPS,
	SNES_MENU_TRANSPARENCY,
#if defined(__GP2X__)
	SNES_MENU_CPUSPEED,
	SNES_MENU_RENDER_MODE,
	SNES_MENU_GAMMA,
	SNES_MENU_RAM_SETTINGS,
	SNES_MENU_MMU_HACK,
	SNES_MENU_ACTION_BUTTONS,
#endif
	SNES_MENU_ADVANCED_HACKS,
	SNES_MENU_AUTO_SAVE_SRAM,
	SNES_MENU_LOAD_GLOBAL,
	SNES_MENU_SAVE_GLOBAL,
	SNES_MENU_DELETE_GLOBAL,
	SNES_MENU_LOAD_CURRENT,
	SNES_MENU_SAVE_CURRENT,
	SNES_MENU_DELETE_CURRENT,
	SNES_MENU_SET_ROMDIR,
	SNES_MENU_CLEAR_ROMDIR,
	SNES_MENU_RETURN,
	SNES_MENU_COUNT
};

enum SAVESTATE_MENU_ENUM
{
	SAVESTATE_MENU_LOAD = 0,
	SAVESTATE_MENU_SAVE,
	SAVESTATE_MENU_DELETE,
	SAVESTATE_MENU_RETURN,
	SAVESTATE_MENU_COUNT
};

enum HACKS_MENU_ENUM
{
	HACKS_MENU_AUDIO = 0,
	HACKS_MENU_PALETTE,
	HACKS_MENU_FIXEDCOL,
	HACKS_MENU_WINDOW,
	HACKS_MENU_ADDSUB,
	HACKS_MENU_OBJ,
	HACKS_MENU_BG0,
	HACKS_MENU_BG1,
	HACKS_MENU_BG2,
	HACKS_MENU_BG3,
	HACKS_MENU_RETURN,
	HACKS_MENU_COUNT
};

enum SRAM_MENU_ENUM
{
	SRAM_MENU_LOAD = 0,
	SRAM_MENU_SAVE,
	SRAM_MENU_DELETE,
	SRAM_MENU_RETURN,
	SRAM_MENU_COUNT,
};

enum EVENT_TYPES
{
	EVENT_NONE = 0,
	EVENT_EXIT_APP,
	EVENT_LOAD_SNES_ROM,
	EVENT_RUN_SNES_ROM,
	EVENT_RESET_SNES_ROM
};

enum RENDER_MODE_ENUM
{
	RENDER_MODE_UNSCALED = 0,
	RENDER_MODE_SCALED
};

#define MENU_TILE_WIDTH      64
#define MENU_TILE_HEIGHT     64

#define GP32_GCC

#ifdef __GIZ__
#define INP_BUTTON_MENU_SELECT			INP_BUTTON_PLAY
#define INP_BUTTON_MENU_CANCEL			INP_BUTTON_STOP
#define INP_BUTTON_MENU_ENTER			INP_BUTTON_BRIGHT
#define INP_BUTTON_MENU_DELETE			INP_BUTTON_REWIND
#define INP_BUTTON_MENU_QUICKSAVE1		INP_BUTTON_R
#define INP_BUTTON_MENU_QUICKSAVE2		INP_BUTTON_BRIGHT
#define INP_BUTTON_MENU_QUICKLOAD1		INP_BUTTON_L
#define INP_BUTTON_MENU_QUICKLOAD2		INP_BUTTON_BRIGHT

//Menu Text
#define MENU_TEXT_LOAD_SAVESTATE 		"Press Play to load"
#define MENU_TEXT_OVERWRITE_SAVESTATE	"Press Play to overwrite"
#define MENU_TEXT_DELETE_SAVESTATE 		"Press Play to delete"
#define MENU_TEXT_PREVIEW_SAVESTATE 	"Press R to preview"
#endif

#ifdef __GP2X__
#define INP_BUTTON_MENU_SELECT			INP_BUTTON_B
#define INP_BUTTON_MENU_CANCEL			INP_BUTTON_X
#define INP_BUTTON_MENU_ENTER			INP_BUTTON_SELECT
#define INP_BUTTON_MENU_DELETE			INP_BUTTON_SELECT
#define INP_BUTTON_MENU_QUICKSAVE1		INP_BUTTON_R
#define INP_BUTTON_MENU_QUICKSAVE2		INP_BUTTON_SELECT
#define INP_BUTTON_MENU_QUICKLOAD1		INP_BUTTON_L
#define INP_BUTTON_MENU_QUICKLOAD2		INP_BUTTON_SELECT


//Menu Text
#define MENU_TEXT_LOAD_SAVESTATE 		"Press B to load"
#define MENU_TEXT_OVERWRITE_SAVESTATE	"Press B to overwrite"
#define MENU_TEXT_DELETE_SAVESTATE 		"Press B to delete"
#define MENU_TEXT_PREVIEW_SAVESTATE 	"Press Y to preview"
#endif

typedef struct {
   char name[MAX_ROMS][MAX_PATH];    //  128 entrys,16 Bytes long
   int size[MAX_ROMS];
} DIRDATA;

//Graphics - moved to objects because they get updated with current gamma setting
extern unsigned short menuHeader[];
extern unsigned short menuHeaderOrig[];
extern unsigned short highLightBar[];
extern unsigned short highLightBarOrig[];
extern unsigned short menuTile[];
extern unsigned short menuTileOrig[];

extern unsigned char padConfig[];
extern float soundRates[];
extern char currentWorkingDir[];
extern char snesOptionsDir[];
extern char snesSramDir[];
extern char snesSaveStateDir[];
extern unsigned char gammaConv[];
extern char lastSaveName[];
extern short *soundBuffer;
extern unsigned char *RomData;
extern int currentEmuMode;
extern int lastStage;
extern int currFB;
extern int prevFB;
extern int saveStateSize;
extern int romLoaded;
extern int frames,taken; // Frames and 60hz ticks
extern char showFps;
extern char soundRate;
extern char soundOn;

void UpdateMenuGraphicsGamma(void);
int RoundDouble(double val);
void ClearScreen(unsigned int *buffer,unsigned int data);
void LoadSram(char *path,char *romname,char *ext,char *srammem);
void SaveSram(char *path,char *romname,char *ext,char *srammem);
void DeleteSram(char *path,char *romname,char *ext);
int SaveMenuOptions(char *path, char *filename, char *ext, char *optionsmem, int maxsize, int showMessage);
int LoadMenuOptions(char *path, char *filename, char *ext, char *optionsmem, int maxsize, int showMessage);
int DeleteMenuOptions(char *path, char *filename, char *ext, int showMessage);
void SnesDefaultMenuOptions(void);
#ifdef __GIZ__
void sync(void);
#endif
// menu.cpp
void MenuPause(void);
void MenuFlip(void);
void SplitFilename(char *wholeFilename, char *filename, char *ext);
void CheckDirSep(char *path);
int FileSelect(int mode);
int MainMenu(int prevAction);
void PrintTitle(int flip);
void PrintTile(int flip);
void PrintBar(int flip, unsigned int givenY);

int FileScan();
extern void loadStateFile(char *filename);
extern int quickSavePresent;
extern unsigned short cpuSpeedLookup[];
extern float gammaLookup[];

extern char currentRomFilename[];
extern char romDir[];
extern char snesRomDir[];

struct SNES_MENU_OPTIONS
{
  unsigned char menuVer;
  unsigned char frameSkip;
  unsigned char soundOn;
  unsigned char cpuSpeed;
  unsigned char padConfig[32];
  unsigned char tripleBuffer;
  unsigned char forceRegion;
  unsigned char showFps;
  signed char gamma;
  unsigned char lcdver;
  unsigned char stereo;
  unsigned char soundRate;
  unsigned char autoSram;
  unsigned char renderMode;
  unsigned char volume;
  unsigned char actionButtons;
  unsigned char transparency;
  unsigned char ramSettings;
  unsigned char mmuHack;
  unsigned char region;
  unsigned char soundHack;
  unsigned short graphHacks;
  unsigned char spare16;
  unsigned char spare17;
  unsigned char spare18;
  unsigned char spare19;
  unsigned char spare1A;
  unsigned char spare1B;
  unsigned char spare1C;
  unsigned char spare1D;
  unsigned char spare1E;
};

extern struct SNES_MENU_OPTIONS snesMenuOptions;

struct SAVE_STATE
{
  char filename[MAX_PATH+1];
  char fullFilename[MAX_PATH+1];
  unsigned int inUse;
};


extern struct SAVE_STATE saveState[];  // holds the filenames for the savestate and "inuse" flags
extern char saveStateName[];

// Input.cpp
struct INPUT
{
  unsigned int held[32];
  unsigned int repeat[32];
};
extern struct INPUT Inp;

int InputInit();
int InputUpdate(int EnableDiagnals);

#ifdef __cplusplus
}
#endif

#endif /* _MENU_H_ */





