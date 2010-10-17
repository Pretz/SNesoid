#define LOG_TAG "libsnes"
#include <utils/Log.h>
#include <string.h>
#include "../memmap.h"

extern "C"
void S9xMessage(int type, int number, const char *message)
{
	LOGD(message);
}

extern "C"
bool8 S9xMovieActive()
{
	return FALSE;
}

extern "C"
const char *S9xGetFilename(const char *ext)
{
	static char filename[1024];

	const char *dot = strrchr(Memory.ROMFilename, '.');
	if (dot == NULL)
		strcpy(filename, Memory.ROMFilename);
	else {
		int len = dot - Memory.ROMFilename;
		strncpy(filename, Memory.ROMFilename, len);
		filename[len] = '\0';
	}
	strcat(filename, ext);
	return filename;
}

extern "C"
const char *S9xBasename(const char *f)
{
	const char *p = strrchr(f, '/');
	if (p == NULL)
		return f;
	return (p + 1);
}

extern "C"
const char *S9xGetFilenameInc(const char *e)
{
	return S9xGetFilename(e);
}

extern "C"
const char *S9xGetSnapshotDirectory()
{
	return "";
}

extern "C"
char* osd_GetPackDir()
{
  static char filename[_MAX_PATH];
  memset(filename, 0, _MAX_PATH);
  
  char dir [_MAX_DIR + 1];
  char drive [_MAX_DRIVE + 1];
  char name [_MAX_FNAME + 1];
  char ext [_MAX_EXT + 1];
  _splitpath(Memory.ROMFilename, drive, dir, name, ext);
  _makepath(filename, drive, dir, NULL, NULL);
  
  if(!strncmp((char*)&Memory.ROM [0xffc0], "SUPER POWER LEAG 4   ", 21))
  {
      strcat(filename, "/SPL4-SP7");
  }
  else if(!strncmp((char*)&Memory.ROM [0xffc0], "MOMOTETSU HAPPY      ",21))
  {
      strcat(filename, "/SMHT-SP7");
  }
  else if(!strncmp((char*)&Memory.ROM [0xffc0], "HU TENGAI MAKYO ZERO ", 21))
  {
      strcat(filename, "/FEOEZSP7");
  }
  else if(!strncmp((char*)&Memory.ROM [0xffc0], "JUMP TENGAIMAKYO ZERO",21))
  {
      strcat(filename, "/SJUMPSP7");
  } else strcat(filename, "/MISC-SP7");
  return filename;
}

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
