
APPNAME = DrPocketSnes

COPT = -IC:/cygwin/opt/cegcc/arm-wince-cegcc/include -I .
COPT += -mcpu=arm920 -mtune=arm920t -O3 -ffast-math -fexpensive-optimizations -finline -finline-functions -msoft-float -falign-functions=32 -falign-loops -falign-labels -falign-jumps -fomit-frame-pointer
COPT += -D__GIZ__

GCC = gcc
STRIP = strip

#
# SNES stuff (c-based)
# memset.o memcpy.o 
OBJS = 2xsaiwin.o apu.o c4.o c4emu.o cheats.o cheats2.o clip.o cpu.o cpuexec.o data.o 
OBJS += dma.o dsp1.o fxemu.o fxinst.o gfx.o globals.o loadzip.o memmap.o ppu.o  
OBJS += sdd1.o sdd1emu.o snapshot.o soundux.o spc700.o srtc.o tile.o
#
# ASM CPU Core, ripped from Yoyo's OpenSnes9X
#
OBJS += os9x_asm_cpu.o os9x_65c816.o spc700a.o
#
# and some asm from LJP...
#
OBJS += m3d_func.o misc.o
# 
# Dave's minimal SDK
#
OBJS += giz_sdk.o menu.o input.o gp2x_menutile.o gp2x_highlightbar.o \
			gp2x_menu_header.o unzip.o zip.o ioapi.o giz_kgsdkasm.o

#
# and the glue code that sticks it all together :)
#
OBJS += main.o

# Inopia's menu system, hacked for the GP2X under rlyeh's sdk
PRELIBS = -LC:/cygwin/opt/cegcc/arm-wince-cegcc/lib -lz -lGizSdk $(LIBS) 

all: $(APPNAME).exe
clean: tidy $(APPNAME).exe

.c.o:
	$(GCC) $(COPT) -c $< -o $@

.cpp.o:
	$(GCC) $(COPT) -c $< -o $@

# make seems to lowercase the extensions, so files with '.S' end up being passed to the compiler as '.s', which means thousands of errors.
# this is a small workaround. 

spc700a.o: spc700a.s
	$(GCC) $(COPT) -c $< -o $@
	
os9x_65c816.o: os9x_65c816.s
	$(GCC) $(COPT) -c $< -o $@

osnes9xgp_asmfunc.o: osnes9xgp_asmfunc.s
	$(GCC) $(COPT) -c $< -o $@

m3d_func.o: m3d_func.S
	$(GCC) $(COPT) -c $< -o $@

spc_decode.o: spc_decode.s
	$(GCC) $(COPT) -c $< -o $@

misc.o: misc.s
	$(GCC) $(COPT) -c $< -o $@

memset.o: memset.s
	$(GCC) $(COPT) -c $< -o $@
	
memcpy.o: memcpy.s
	$(GCC) $(COPT) -c $< -o $@

dspMixer.o: dspMixer.s
	$(GCC) $(COPT) -c $< -o $@
	
giz_kgsdkasm.o: giz_kgsdkasm.s
	$(GCC) $(COPT) -c $< -o $@

RenderASM/render8.o: RenderASM/render8.S
	$(GCC) $(COPT) -c $< -o $@

$(APPNAME)d.exe: $(OBJS)
	$(GCC) $(COPT) $(OBJS) -static $(PRELIBS) -o $@ -lstdc++ -lm

$(APPNAME).exe: $(APPNAME)d.exe
	$(STRIP) $(APPNAME)d.exe -o $(APPNAME).exe

tidy:
	rm *.o
	rm $(APPNAME)d.exe
	rm $(APPNAME).exe
