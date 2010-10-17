#include <stdio.h>
#include <string.h>
#include <zlib.h>
#include "../memmap.h"
#include "../unzip.h"
#include "../zip.h"

int (*statef_open)(const char *fname, const char *mode);
int (*statef_read)(void *p, int l);
int (*statef_write)(void *p, int l);
void (*statef_close)();
static FILE *state_file;
static char state_filename[1024];
static char *state_mem;
static int state_mem_pos;
static int state_mem_size;
static int state_mode;

static int check_zip(char *filename)
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

    unzFile fd = NULL;
    unz_file_info info;
    int ret = 0;
         
	/* Attempt to open the archive */
	fd = unzOpen(filename);
	if(!fd)
	{
		return NULL;
	}

	/* Go to first file in archive */
	ret = unzLocateFile(fd, "SNESOID", 0);
	if(ret != UNZ_OK)
	{
		unzClose(fd);
		return NULL;
	}

	ret = unzGetCurrentFileInfo(fd, &info, NULL, 0, NULL, 0, NULL, 0);
	if(ret != UNZ_OK)
	{
        unzClose(fd);
        return NULL;
	}

	/* Open the file for reading */
	ret = unzOpenCurrentFile(fd);
	if(ret != UNZ_OK)
	{
		unzClose(fd);
		return NULL;
	}

	/* Allocate file data buffer */
	size = info.uncompressed_size;
	buf=(char*)malloc(size);
	if(!buf)
	{
		unzClose(fd);
		return NULL;
	}
	
	/* Read (decompress) the file */
	ret = unzReadCurrentFile(fd, buf, info.uncompressed_size);
	if(ret != info.uncompressed_size)
	{
		free(buf);
	    unzCloseCurrentFile(fd);
		unzClose(fd);
		return NULL;
	}

	/* Close the current file */
	ret = unzCloseCurrentFile(fd);
	if(ret != UNZ_OK)
	{
		free(buf);
	    unzClose(fd);
		return NULL;
	}

	/* Close the archive */
	ret = unzClose(fd);
	if(ret != UNZ_OK)
	{
		free(buf);
	    return NULL;
	}

	/* Update file size and return pointer to file data */
	*file_size = size;
	return buf;
}

static int save_archive(char *filename, char *buffer, int size)
{
    uint8 *buf = NULL;
    zipFile fd = NULL;
    int ret = 0;
    fd=zipOpen(filename, APPEND_STATUS_ADDINZIP);
	if(!fd)
       fd=zipOpen(filename, APPEND_STATUS_CREATE);
    if(!fd)
    {
       return (0);
    }

    ret=zipOpenNewFileInZip(fd,"SNESOID",
			    NULL,
				NULL,0,
			    NULL,0,
			    NULL,
			    Z_DEFLATED,
			    Z_DEFAULT_COMPRESSION);
			    
    if(ret != ZIP_OK)
    {
       zipClose(fd,NULL);
       return (0);    
    }

    ret=zipWriteInFileInZip(fd,buffer,size);
    if(ret != ZIP_OK)
    {
      zipCloseFileInZip(fd);
      zipClose(fd,NULL);
      return (0);
    }

    ret=zipCloseFileInZip(fd);
    if(ret != ZIP_OK)
    {
      zipClose(fd,NULL);
      return (0);
    }

    ret=zipClose(fd,NULL);
    if(ret != ZIP_OK)
    {
      return (0);
    }
	
    return(1);
}

static int state_unc_open(const char *fname, const char *mode)
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
			state_mode = 1; //zip mode
			state_mem=load_archive((char*)fname,&state_mem_size);
			if(!state_mem) return 0;
			state_mem_pos=0;
			strcpy(state_filename,fname);
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
		//Write mode requested. Zip only option
		state_mode = 2; //normal file mode
		state_mem=(char*)malloc(200);
		state_mem_size=200;
		state_mem_pos = 0;
		strcpy(state_filename,fname);
		return 1;
	}
}

static int state_unc_read(void *p, int l)
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
			return 0;
		}
		else
		{
			memcpy(p,state_mem+state_mem_pos,l);
			state_mem_pos+=l;
		}
		return l;
	}
}

static int state_unc_write(void *p, int l)
{
	if(state_mode==0)
	{
		return fwrite(p, 1, l, state_file);
	}
	else
	{
		if((state_mem_pos+l)>state_mem_size)
		{
			//Write will exceed current buffer, re-alloc buffer and continue
			state_mem=(char*)realloc(state_mem,state_mem_pos+l);
			state_mem_size=state_mem_pos+l;
		}
		//Now do write
		memcpy(state_mem+state_mem_pos,p,l);
		state_mem_pos+=l;
		return l;
	}
}

static void state_unc_close()
{
	if(state_mode==0)
	{
		fclose(state_file);
	}
	else
	{
		if (state_mode == 2)
			save_archive(state_filename,state_mem,state_mem_size);
		free(state_mem);
		state_mem=NULL;
		state_mem_size=0;
		state_mem_pos=0;
		state_filename[0]=0;
	}
}

bool fileInitialize()
{
	statef_open  = state_unc_open;
	statef_read  = state_unc_read;
	statef_write = state_unc_write;
	statef_close = state_unc_close;
	return true;
}

void fileCleanup()
{
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
