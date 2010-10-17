LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE_TAGS := user

LOCAL_ARM_MODE := arm

# This is the target being built.
LOCAL_MODULE := libsnes_comp

# All of the source files that we will compile.
LOCAL_SRC_FILES := \
    cpuops.cpp \
    cpuexec.cpp \
    sa1cpu.cpp \
    spc700.cpp \
    soundux.cpp \
    apu.cpp \
    apudebug.cpp \
    fxinst.cpp \
    fxemu.cpp \
    fxdbg.cpp \
    c4.cpp \
    c4emu.cpp \
    cpu.cpp \
    sa1.cpp \
    debug.cpp \
    sdd1.cpp \
    tile.cpp \
    srtc.cpp \
    gfx.cpp \
    memmap.cpp \
    clip.cpp \
    dsp1.cpp \
    ppu.cpp \
    dma.cpp \
    data.cpp \
    globals.cpp \
	spc7110.cpp \
	obc1.cpp \
	seta.cpp \
	seta010.cpp \
	seta011.cpp \
	seta018.cpp \
	sdd1emu.cpp \
    cheats.cpp \
    cheats2.cpp \
    snapshot.cpp

LOCAL_SRC_FILES += \
    loadzip.cpp \
	zip.c \
	unzip.c \
	ioapi.c

LOCAL_SRC_FILES += \
	android/android.cpp \
	android/file.cpp \
	android/snesengine.cpp

# All of the shared libraries we link against.
LOCAL_SHARED_LIBRARIES := \
	libutils \
	libz

# Static libraries.
LOCAL_STATIC_LIBRARIES := \
	libunz

# Also need the JNI headers.
LOCAL_C_INCLUDES += \
	$(JNI_H_INCLUDE) \
	$(LOCAL_PATH)/../../common \
    $(LOCAL_PATH)/unzip \
	external/zlib

# Compiler flags.
LOCAL_CFLAGS += -O3 -fvisibility=hidden

LOCAL_CFLAGS += \
    -DVAR_CYCLES \
    -DCPU_SHUTDOWN \
    -DSPC700_SHUTDOWN \
    -DEXECUTE_SUPERFX_PER_LINE \
    -DSPC700_C \
    -DUNZIP_SUPPORT \
	-DSDD1_DECOMP \
    -DNO_INLINE_SET_GET \
	-DNOASM \
	-DZLIB \
	-DHAVE_STRINGS_H

# Don't prelink this library.  For more efficient code, you may want
# to add this library to the prelink map and set this to true. However,
# it's difficult to do this for applications that are not supplied as
# part of a system image.

LOCAL_PRELINK_MODULE := false

include $(BUILD_SHARED_LIBRARY)

