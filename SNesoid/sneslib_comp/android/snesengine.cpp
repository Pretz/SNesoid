#define LOG_TAG "libsnes"
#include <utils/Log.h>
#include "../snes9x.h"
#include "../memmap.h"
#include "../cpuexec.h"
#include "../apu.h"
#include "../ppu.h"
#include "../gfx.h"
#include "../display.h"
#include "../soundux.h"
#include "../snapshot.h"
#include "../cheats.h"
#include "emuengine.h"
#include "file.h"
#include <unistd.h>

#define SCREEN_W		256
#define SCREEN_H		240
#define SCREEN_PITCH	(SCREEN_W * 2)

static EmuEngine *engine;
static EmuEngine::Callbacks *callbacks;
static uint32 lightGunEvent;
static unsigned int keyStates;
static bool pad2Enabled;

class SNesEngine : public EmuEngine {
public:
	SNesEngine();
	virtual ~SNesEngine();

	virtual bool initialize(Callbacks *cbs);
	virtual void destroy();
	virtual void reset();
	virtual void power();
	virtual void fireLightGun(int x, int y);
	virtual Game *loadRom(const char *file);
	virtual void unloadRom();
	virtual void renderFrame(const Surface &surface);
	virtual bool saveState(const char *file);
	virtual bool loadState(const char *file);
	virtual bool addCheat(const char *code);
	virtual void removeCheat(const char *code);
	virtual void runFrame(unsigned int keys, bool skip);
	virtual void setOption(const char *name, const char *value);

private:
	void setKeyStates(int states) {
		if (Settings.SuperScope) {
			// turbo switch
			if ((keyStates ^ states) & states & 1)
				lightGunEvent ^= 0x4;

			// pause
			if (states & 2)
				lightGunEvent |= 0x8;
			else
				lightGunEvent &= ~0x8;

			// cursor
			if (states & 4)
				lightGunEvent |= 0x02;
			else
				lightGunEvent &= ~0x02;
		}

		keyStates = states;
	}

	void loadSRAM() {
		if (sramEnabled)
			Memory.LoadSRAM(S9xGetFilename(".sav"));
	}
	void saveSRAM() {
		if (sramEnabled && CPU.SRAMModified) {
			Memory.SaveSRAM(S9xGetFilename(".sav"));
			CPU.SRAMModified = FALSE;
		}
	}

	bool soundEnabled;
	bool sramEnabled;
};


SNesEngine::SNesEngine() :
		soundEnabled(false),
		sramEnabled(false)
{
	engine = this;
}

SNesEngine::~SNesEngine()
{
	fileCleanup();

	if (GFX.Screen) {
		free(GFX.Screen);
		GFX.Screen = NULL;
	}
	if (GFX.SubScreen) {
		free(GFX.SubScreen);
		GFX.SubScreen = NULL;
	}
	if (GFX.ZBuffer) {
		free(GFX.ZBuffer);
		GFX.ZBuffer = NULL;
	}
	if (GFX.SubZBuffer) {
		free(GFX.SubZBuffer);
		GFX.SubZBuffer = NULL;
	}
	engine = NULL;
}

bool SNesEngine::initialize(EmuEngine::Callbacks *cbs)
{
	callbacks = cbs;
	lightGunEvent = 0;
	keyStates = 0;
	pad2Enabled = false;

	// Initialise Snes stuff
	memset(&Settings, 0, sizeof(Settings));

	Settings.JoystickEnabled = FALSE;
	Settings.SoundPlaybackRate = 22050;
	Settings.Stereo = FALSE;
	Settings.SoundBufferSize = 0;
	Settings.CyclesPercentage = 100;
	Settings.DisableSoundEcho = FALSE;
	Settings.APUEnabled = Settings.NextAPUEnabled = FALSE;
	Settings.H_Max = SNES_CYCLES_PER_SCANLINE;
	Settings.SkipFrames = AUTO_FRAMERATE;
	Settings.ShutdownMaster = TRUE;
	Settings.FrameTimePAL = 20000;
	Settings.FrameTimeNTSC = 16667;
	Settings.FrameTime = Settings.FrameTimeNTSC;
	Settings.DisableSampleCaching = FALSE;
	Settings.DisableMasterVolume = FALSE;
	Settings.Mouse = FALSE;
	Settings.MultiPlayer5 = FALSE;
	//	Settings.ControllerOption = SNES_MULTIPLAYER5;
	Settings.ControllerOption = 0;

	Settings.ForceTransparency = FALSE;
	Settings.Transparency = FALSE;
	Settings.SixteenBit = TRUE;
	
	Settings.SupportHiRes = TRUE;
	Settings.NetPlay = FALSE;
	Settings.ServerName [0] = 0;
	Settings.AutoSaveDelay = 30;
	Settings.ApplyCheats = TRUE;
	Settings.TurboMode = FALSE;
	Settings.TurboSkipFrames = 15;
	Settings.ThreadSound = FALSE;
	Settings.SoundSync = FALSE;
	//Settings.NoPatch = true;		

	if (Settings.ForceNoTransparency)
		Settings.Transparency = FALSE;
	if (Settings.Transparency)
		Settings.SixteenBit = TRUE;
	Settings.HBlankStart = (256 * Settings.H_Max) / SNES_HCOUNTER_MAX;

	GFX.Pitch = SCREEN_PITCH;
	GFX.Screen = (uint8 *) malloc(GFX.Pitch * SCREEN_H);
	GFX.SubScreen = (uint8 *) malloc(GFX.Pitch * SCREEN_H);
	GFX.ZBuffer = (uint8 *) malloc(SCREEN_W * SCREEN_H);
	GFX.SubZBuffer = (uint8 *) malloc(SCREEN_W * SCREEN_H);

	fileInitialize();

	if (!Memory.Init() || !S9xInitAPU())
		return false;

	Settings.SixteenBitSound = TRUE;
	so.stereo = Settings.Stereo;
	S9xInitSound(Settings.SoundPlaybackRate, Settings.Stereo,
			Settings.SoundBufferSize);;

	return S9xGraphicsInit();
}

void SNesEngine::destroy()
{
	delete this;
}

void SNesEngine::reset()
{
	S9xReset();
}

void SNesEngine::power()
{
	reset();
}

void SNesEngine::fireLightGun(int x, int y)
{
	if (Settings.SuperScope)
		lightGunEvent = ((x & 0xff) << 8) | ((y & 0xff) << 16) | 1;
}

static const uint32 crc32Table[256] = {
  0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f,
  0xe963a535, 0x9e6495a3, 0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988,
  0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91, 0x1db71064, 0x6ab020f2,
  0xf3b97148, 0x84be41de, 0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
  0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec, 0x14015c4f, 0x63066cd9,
  0xfa0f3d63, 0x8d080df5, 0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172,
  0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b, 0x35b5a8fa, 0x42b2986c,
  0xdbbbc9d6, 0xacbcf940, 0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
  0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423,
  0xcfba9599, 0xb8bda50f, 0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
  0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d, 0x76dc4190, 0x01db7106,
  0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
  0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d,
  0x91646c97, 0xe6635c01, 0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e,
  0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457, 0x65b0d9c6, 0x12b7e950,
  0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
  0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7,
  0xa4d1c46d, 0xd3d6f4fb, 0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0,
  0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9, 0x5005713c, 0x270241aa,
  0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
  0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81,
  0xb7bd5c3b, 0xc0ba6cad, 0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a,
  0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683, 0xe3630b12, 0x94643b84,
  0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
  0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb,
  0x196c3671, 0x6e6b06e7, 0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc,
  0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5, 0xd6d6a3e8, 0xa1d1937e,
  0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
  0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55,
  0x316e8eef, 0x4669be79, 0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
  0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f, 0xc5ba3bbe, 0xb2bd0b28,
  0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
  0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f,
  0x72076785, 0x05005713, 0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38,
  0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21, 0x86d3d2d4, 0xf1d4e242,
  0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
  0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69,
  0x616bffd3, 0x166ccf45, 0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2,
  0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db, 0xaed16a4a, 0xd9d65adc,
  0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
  0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693,
  0x54de5729, 0x23d967bf, 0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94,
  0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d
};

//CRC32 for char arrays
uint32 caCRC32(uint8 *array, uint32 size, register uint32 crc32) {	
  for (register uint32 i = 0; i < size; i++) {
    crc32 = ((crc32 >> 8) & 0x00FFFFFF) ^ crc32Table[(crc32 ^ array[i]) & 0xFF];
  }
  return ~crc32;
}

static int os9x_findhacks(int game_crc32)
{
	int i=0,j;
	int _crc32;	
	char c;
	char str[256];
	unsigned int size_snesadvance;
	unsigned char *snesadvance;
	FILE *f;
	
	f=fopen("/sdcard/snesadvance.dat", "rb");
	if (!f) return 0;
	fseek(f,0,SEEK_END);
	size_snesadvance=ftell(f);
	fseek(f,0,SEEK_SET);
	snesadvance=(unsigned char*)malloc(size_snesadvance);
	fread(snesadvance,1,size_snesadvance,f);
	fclose(f);
	
	for (;;) {
		//get crc32
		j=i;
		while ((i<size_snesadvance)&&(snesadvance[i]!='|')) i++;
		if (i==size_snesadvance) {free(snesadvance);return 0;}
		//we have (snesadvance[i]=='|')
		//convert crc32 to int
		_crc32=0;
		while (j<i) {
			c=snesadvance[j];
			if ((c>='0')&&(c<='9'))	_crc32=(_crc32<<4)|(c-'0');
			else if ((c>='A')&&(c<='F'))	_crc32=(_crc32<<4)|(c-'A'+10);
			else if ((c>='a')&&(c<='f'))	_crc32=(_crc32<<4)|(c-'a'+10);				
			j++;
		}
		if (game_crc32==_crc32) {
			//int p=0;
			for (;;) {
				int adr,val;
							
				i++;
				j=i;
				while ((i<size_snesadvance)&&(snesadvance[i]!=0x0D)&&(snesadvance[i]!=',')) {
					if (snesadvance[i]=='|') j=i+1;
					i++;
				}
				if (i==size_snesadvance) {free(snesadvance);return 0;}
				memcpy(str,&snesadvance[j],i-j);
				str[i-j]=0;								
				sscanf(str,"%X=%X",&adr,&val);
				//sprintf(str,"read : %X=%X",adr,val);
				//pgPrintAllBG(32,31-p++,0xFFFF,str);
				
				if ((val==0x42)||((val&0xFF00)==0x4200)) {					
					if (val&0xFF00) {
						ROM[adr]=(val>>8)&0xFF;
						ROM[adr+1]=val&0xFF;
					} else ROM[adr]=val;
				}
				
				if (snesadvance[i]==0x0D) {free(snesadvance);return 1;				}
			}
				
		}
		while ((i<size_snesadvance)&&(snesadvance[i]!=0x0A)) i++;
		if (i==size_snesadvance) {free(snesadvance);return 0;}
		i++; //new line
	}
}

SNesEngine::Game *SNesEngine::loadRom(const char *file)
{
	if (!Memory.LoadROM(file))
		return NULL;

	loadSRAM();

//	if (os9x_findhacks(Memory.ROMCRC32))
//		LOGI("Found speedhacks, applying...");

	Settings.ForceNTSC =
	Settings.ForcePAL = FALSE;
	Settings.PAL = (ROM[Memory.HiROM ? 0xffd9 : 0x7fd9] >= 2);

	Settings.FrameTime = (Settings.PAL ?
		Settings.FrameTimePAL : Settings.FrameTimeNTSC);
	Memory.ROMFramesPerSecond = (Settings.PAL ? 50 : 60);

	memset(GFX.Screen, 0, SCREEN_PITCH * SCREEN_H);

	static Game game;
	game.videoWidth = SCREEN_W;
	game.videoHeight = SCREEN_H;
	if (!Settings.PAL)
		game.videoHeight -= 16;

	game.soundRate = Settings.SoundPlaybackRate;
	game.soundBits = 16;
	game.soundChannels = (Settings.Stereo ? 2 : 1);
	game.fps = Memory.ROMFramesPerSecond;
	return &game;
}

void SNesEngine::unloadRom()
{
	saveSRAM();
}

void SNesEngine::renderFrame(const EmuEngine::Surface &surface)
{
	uint8 *d = (uint8 *) surface.bits;
	uint8 *s = GFX.Screen;
	int h = SCREEN_H;
	if (!Settings.PAL)
		h -= 16;

	if (surface.bpr > 0) {
		while (--h >= 0) {
			memcpy(d, s, SCREEN_PITCH);
			d += surface.bpr;
			s += SCREEN_PITCH;
		}
	} else {
		d += (h - 1) * -surface.bpr + SCREEN_PITCH;
		while (--h >= 0) {
			uint32 *src = (uint32 *) s;
			uint32 *dst = (uint32 *) d;
			for (int w = SCREEN_W / 2; --w >= 0; src++)
				*--dst = (*src << 16) | (*src >> 16);

			d += surface.bpr;
			s += SCREEN_PITCH;
		}
	}
}

bool SNesEngine::saveState(const char *file)
{
	bool8 rv = S9xFreezeGame(file);
	sync();
	return (rv == TRUE);
}

bool SNesEngine::loadState(const char *file)
{
	return S9xUnfreezeGame(file);
}

static int decodeCheat(const char *code, uint32 &address, uint8 bytes[3])
{
	if (S9xGameGenieToRaw(code, address, bytes[0]) == NULL)
		return 1;
	if (S9xProActionReplayToRaw(code, address, bytes[0]) == NULL)
		return 1;

	bool8 sram;
	uint8 num_bytes;
	if (S9xGoldFingerToRaw(code, address, sram, num_bytes, bytes) == NULL)
		return num_bytes;
	return 0;
}

bool SNesEngine::addCheat(const char *code)
{
	uint32 address;
	uint8 bytes[3];
	int n = decodeCheat(code, address, bytes);
	if (n <= 0)
		return false;

	for (int i = 0; i < n; i++)
		S9xAddCheat(TRUE, FALSE, address + i, bytes[i]);
	return true;
}

void SNesEngine::removeCheat(const char *code)
{
	uint32 address;
	uint8 bytes[3];
	int n = decodeCheat(code, address, bytes);

	for (int i = 0; i < n; i++)
		S9xDeleteCheat(address + i, bytes[i]);
}

void SNesEngine::runFrame(unsigned int keys, bool skip)
{
	setKeyStates(keys);

	IPPU.RenderThisFrame = (skip ? FALSE : TRUE);
	S9xMainLoop();

	if (Settings.APUEnabled && soundEnabled) {
		static short buffer[2048] __attribute__ ((aligned(4)));
		const unsigned int frameLimit = (Settings.PAL ? 50 : 60);
		const int sampleCount = Settings.SoundPlaybackRate / frameLimit;

		S9xMixSamples((uint8 *) buffer, sampleCount);
		callbacks->playAudio(buffer, sampleCount * 2);
	}
}

void SNesEngine::setOption(const char *name, const char *value)
{
	if (strcmp(name, "soundEnabled") == 0) {
		soundEnabled = (strcmp(value, "true") == 0);
		S9xSetPlaybackRate(soundEnabled ? Settings.SoundPlaybackRate : 0);

	} else if (strcmp(name, "apuEnabled") == 0) {
		Settings.NextAPUEnabled = (strcmp(value, "true") == 0);

	} else if (strcmp(name, "transparencyEnabled") == 0) {
		Settings.Transparency = (strcmp(value, "true") == 0);

	} else if (strcmp(name, "enableLightGun") == 0) {
		Settings.SuperScope = (strcmp(value, "true") == 0);
		if (Settings.SuperScope)
			Settings.ControllerOption = SNES_SUPERSCOPE;

	} else if (strcmp(name, "enableGamepad2") == 0) {
		pad2Enabled = (strcmp(value, "true") == 0);

	} else if (strcmp(name, "enableSRAM") == 0) {
		sramEnabled = (strcmp(value, "true") == 0);
	}
}


extern "C"
void S9xLoadSDD1Data()
{
    Memory.FreeSDD1Data();
	Settings.SDD1Pack = TRUE;
}

extern "C"
void S9xSetPalette()
{
}

extern "C"
bool8 S9xInitUpdate()
{
	return TRUE;
}

extern "C"
bool8 S9xDeinitUpdate(int width, int height, bool8)
{
	EmuEngine::Surface surface;
	if (!callbacks->lockSurface(&surface))
		return FALSE;

	engine->renderFrame(surface);
	callbacks->unlockSurface(&surface);
	return TRUE;
}

extern "C"
uint32 S9xReadJoypad(int which)
{
	uint32 states;

	switch (which) {
	case 0:
		states = (keyStates & 0xfff0);
		break;
	case 1:
		if (pad2Enabled) {
			states = (keyStates >> 16);
			break;
		}
		// fall though
	default:
		return 0;
	}
	return (states | 0x80000000);
}

extern "C"
bool8 S9xReadMousePosition(int which1_0_to_1,
		int &x, int &y, uint32 &buttons)
{
	return FALSE;
}

extern "C"
bool8 S9xReadSuperScopePosition(int &x, int &y, uint32 &buttons)
{
	x = (lightGunEvent >> 8) & 0xff;
	y = (lightGunEvent >> 16) & 0xff;
	buttons = (lightGunEvent & 0xff);

	lightGunEvent &= ~1;
	return TRUE;
}

bool JustifierOffscreen()
{
	return false;
}

void JustifierButtons(uint32& justifiers)
{
}

void S9xGenerateSound()
{
}

void S9xSyncSpeed()
{
}

bool8 S9xOpenSoundDevice(int mode, bool8 stereo, int buffer_size)
{
	return TRUE;
}

void S9xAutoSaveSRAM()
{
    Memory.SaveSRAM(S9xGetFilename (".sav"));
}

void S9xExit()
{
    exit(0);
}

extern "C" __attribute__((visibility("default")))
void *createObject()
{
	return new SNesEngine;
}
