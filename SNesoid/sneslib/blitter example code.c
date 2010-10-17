#if defined(GP2X)
unsigned long devMem=0;
volatile unsigned long *gp2x_memreg32=NULL;
volatile unsigned short *gp2x_memreg16=NULL;
volatile unsigned long* blitter32=NULL;
#endif


#ifdef GP2X
volatile int   vsync_polarity;
#endif

#if defined(GP2X) && !defined(WANT_SDL)
extern unsigned int GetUpperRealAddress(void*);

// dummy blit to force MMSP2's blitter to flush it's cache
void gp2x_dummy_blit(void)
{
    // Blitter seems to have a 16 byte buffer, so force flushing by
    // drawing 8 16bit pixels onto themselves.
    blitter32[0x0000 >> 2] = (1 << 5) | (1 << 6);
    blitter32[0x0004 >> 2] = 0x3101000; // front screen buffer
    blitter32[0x000C>>2] = 1<<8;
    blitter32[0x0020>>2] = 0;
    blitter32[0x002C>>2] = (1 << 16) | 8; // number of bytes to copy
    blitter32[0x0030>>2] = 1<< 8 | 1<< 9 | 0xaa;
    // Make sure blitter is ready
    while (blitter32[0x0034 >> 2] & 1)
    {
        asm volatile ("nop");
        asm volatile ("nop");
        asm volatile ("nop");
        asm volatile ("nop");
    }
    asm volatile ("" ::: "memory");
    blitter32[0x0034 >> 2] = 0x0001;
}

void gp2x_clear_back_buffer(void)
{
    blitter32[0x4 >> 2] = 0x3381000;
    blitter32[0x0] = 1<<5;                                             // Destination is 16 bpp
    blitter32[0x8 >> 2] = 640;                                        // Destination stride size in bytes
    blitter32[0x20 >> 2] = 1 << 5  | 2 << 3;                    // Perform ROP with a 1bpp pattern
    blitter32[0x24 >> 2] = 0;                                // Setup the foreground and background colors for the pattern to be the same
    blitter32[0x28 >> 2] = 0;                                // so we don't actually have to upload a pattern image.
    blitter32[0x2c >> 2] = (240 << 16) | (320 << 0);                // Height and width to blit
    blitter32[0x30 >> 2] = (1<<8) | (1<<9 ) | 0xf0;            // Fill from top left to bottom right

    // Wait for blitter to be free, start it, and then wait for completion.
    // Throw in some nop's so we don't saturate the address bus with polling requests.
    while (blitter32[0x0034 >> 2] & 1)
    {
        asm volatile ("nop");
        asm volatile ("nop");
        asm volatile ("nop");
        asm volatile ("nop");
    }
    blitter32[0x34 >> 2] = 1;
    gp2x_dummy_blit();
}

// fill solid rectangle -workes, yahoo!
void gp2x_fillrect(int x, int y, int w, int h, unsigned short col)
{
    blitter32[0x4 >> 2] = (0x3381000 + (y*640) + (x<<1) ) & ~3;
    blitter32[0x0] = 1<<5  | ((x & 0x00000001) << 4);                                             // Destination is 16 bpp
    blitter32[0x8 >> 2] = 640;                                        // Destination stride size in bytes
    blitter32[0xC >> 2] = 0;


    blitter32[0x20 >> 2] = 1 << 5  | 2 << 3;                    // Perform ROP with a 1bpp pattern
    blitter32[0x24 >> 2] = col;                                // Setup the foreground and background colors for the pattern to be the same
    blitter32[0x28 >> 2] = col;                                // so we don't actually have to upload a pattern image.
    blitter32[0x2c >> 2] = (h << 16) | (w << 0);                // Height and width to blit
    blitter32[0x30 >> 2] = (1<<8) | (1<<9 ) | 0xf0;            // Fill from top left to bottom right

    // Wait for blitter to be free, start it, and then wait for completion.
    // Throw in some nop's so we don't saturate the address bus with polling requests.
    while (blitter32[0x0034 >> 2] & 1)
    {
        asm volatile ("nop");
        asm volatile ("nop");
        asm volatile ("nop");
        asm volatile ("nop");
    }
    blitter32[0x34 >> 2] = 1;
    gp2x_dummy_blit();
}


void gp2x_blit(unsigned int hardware_src, int x_from, int y_from, int src_stride_bytes, int x, int y, int w, int h)
{
    blitter32[0x4 >> 2] = (0x3381000 + (y*640) + (x<<1) ) & ~3; // dest ptr
    blitter32[0x0] = 1<<5  | ((x & 0x00000001) << 4);             // Destination is 16 bpp
    blitter32[0x8 >> 2] = 640;                                    // Destination stride size in bytes

    //Set the source address
    blitter32[0x0010 >> 2] = (hardware_src +(y_from*640)+(x_from<<1) )&~3;
    //Set the pitch of source in bytes
    blitter32[0x0014 >> 2] = src_stride_bytes;
    //Do nothing with pattern
    blitter32[0x0020 >> 2] = 0;

    // Set a 16bit source, enable source and say the source is not controlled by CPU(?)
    blitter32[0x000C >> 2] = (1 << 8) | (1 << 7) | (1 << 5) | ((x_from & 0x00000001) << 4);

    // Clear the source input FIFO, positive X,Y. And do a copy ROP.
    blitter32[0x0030 >> 2] = (1 << 10) | (1 << 9) | (1 << 8) | 0xCC;

    blitter32[0x2c >> 2] = (h << 16) | (w << 0);                // Height and width to blit

    // Wait for blitter to be free, start it, and then wait for completion.
    // Throw in some nop's so we don't saturate the address bus with polling requests.
    while (blitter32[0x0034 >> 2] & 1)
    {
        asm volatile ("nop");
        asm volatile ("nop");
        asm volatile ("nop");
        asm volatile ("nop");
    }
    blitter32[0x34 >> 2] = 1;
    gp2x_dummy_blit();
}


void gp2x_blit_cookie(unsigned int hardware_src, int x_from, int y_from, int src_stride_bytes, int x, int y, int w, int h, unsigned short cookie)
{
    blitter32[0x4 >> 2] = (0x3381000 + (y*640) + (x<<1) ) & ~3; // dest ptr
    blitter32[0x0] = 1<<5  | ((x & 0x00000001) << 4);             // Destination is 16 bpp
    blitter32[0x8 >> 2] = 640;                                    // Destination stride size in bytes

    //Set the source address
    blitter32[0x0010 >> 2] = (hardware_src +(y_from*640)+(x_from<<1) )&~3;
    //Set the pitch of source in bytes
    blitter32[0x0014 >> 2] = src_stride_bytes;
    //Do nothing with pattern
    blitter32[0x0020 >> 2] = 0;

    // Set a 16bit source, enable source and say the source is not controlled by CPU(?)
    blitter32[0x000C >> 2] = (1 << 8) | (1 << 7) | (1 << 5) | ((x_from & 0x00000001) << 4);

    // Clear the source input FIFO, positive X,Y. And do a copy ROP.  cookie        enable cookie
    blitter32[0x0030 >> 2] = (1 << 10) | (1 << 9) | (1 << 8) | 0xCC | (cookie<<16)|(1<<11);

    blitter32[0x2c >> 2] = (h << 16) | (w << 0);                // Height and width to blit

    // Wait for blitter to be free, start it, and then wait for completion.
    // Throw in some nop's so we don't saturate the address bus with polling requests.
    while (blitter32[0x0034 >> 2] & 1)
    {
        asm volatile ("nop");
        asm volatile ("nop");
        asm volatile ("nop");
        asm volatile ("nop");
    }
    blitter32[0x34 >> 2] = 1;
    gp2x_dummy_blit();
}