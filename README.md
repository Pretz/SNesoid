SNesoid: [Snes9x][snes9x] for Android
===========================

This is a fork of Zhang Yong's snes9x port to Android, which he named [SNesoid][snesoid].  Since Zhang Yong has been placing source tarballs on [sourceforge](http://sourceforge.net/projects/androidemu/files/) with no documentation, I imported the latest versions of his code release at the time of this writing (October 2010, SNesoid 2.1) into github.  I then made a few modifications to the build system to get compilation to work correctly without requiring the full Android source tree. These modifications can be seen in Pretz/SNesoid@6393bd5a66097a0d353b56aef8b896942b748c85


Building
--------

Zhang Yong's emulators have a shared common library, which I have put up on github as [Emudroid-Common](http://github.com/Pretz/Emudroid-Common).  I've included the common library as a git submodule, so before you'll be able to compile SNesoid, you'll need to go into the top level directory in the repository and execute

    $ git submodule init

I've fixed Zhang Yong's build system so once you've installed the [Android NDK](http://developer.android.com/sdk/ndk/index.html) (in addition to the Android SDK), you should be able to go into the SNesoid directory and execute

    $ ~/<path-to-NDK>/ndk-build
    
This will compile the native portions of the application: snes9x and the bridge to Android.  Once you've compiled the native components you should be able to compile and run the Android project via Eclipse or ant.


Future Work
-----------

I intend to keep my fork of SNesoid synced with any future updates Zhang Yong posts to sourceforge.  As of 10/17/10 he has just posted version 2.1 of many of his emulators.  I suspect my build changes can be applied to his other emulators as well, but I have not yet explored them.

SNesoid currently uses fairly old versions of [Snes9x][snes9x], and I am interested in bringing it up to date with the latest version, [1.52](http://www.snes9x.com/phpbb2/viewtopic.php?t=4542), however it is possible (likely?) that 1.52's performance will be significantly worse than the current 1.43 version.  Additionally, 1.52 breaks compatibility with all previous savestate files (however, it will still work with SRAM saves).


Interesting Things to Note
--------------------------

SNesoid is a great example of wrapping a large preexisting native codebase in an Android application.

It appears SNesoid includes two complete copies of Snes9x: what Zhang calls `sneslib` and `sneslib_comp`.  It looks like `sneslib` is more-or-less Reesy's [DrPocketSNES][drpsnes] version 6.4.4, which in turn is based on snes9x 1.39, including several components written in native ARM assembly.  This is the default emulator engine SNesoid uses.  `sneslib_comp` appears it be vanilla snes9x version 1.43, but it is compiled with all assembly based parts disabled:

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

License
-------

Snes9x is distributed under [its own open-source license](http://github.com/Pretz/SNesoid/blob/master/SNesoid/sneslib/snes9x.h#L21) which forbids commercial use of snes9x or any work derived from snes9x.  Any additions made by me in this project are licensed under the same terms.


Credits
-------

* The [snes9x][snes9x] team for the huge effort of writing a fast, cross-platform, and accurate SNES emulator.
* [Zhang Yong](http://www.appbrain.com/browse/dev/yongzh) for his impressive job porting snes9x to Android/JNI and the fully featured Android UI.
* [AndroidDrPocketSNES](http://code.google.com/p/androiddrpocketsnes/) for making a first attempt to getting yonghz's code to compile on Android.  Referencing the build changes made by this project was incredibly helpful in getting SNesoid to compile.
* Reesy's [DrPocketSNES][drpsnes] for paving the way in getting snes9x working on linux-based mobile devices.


[snes9x]: http://www.snes9x.com/ "Snes9x Homepage"
[snesoid]: http://www.appbrain.com/app/snesoid-(snes-emulator)/com.androidemu.snes "SNesoid on AppBrain"
[drpsnes]: http://reesy.gp32x.de/DrPocketSnes.html "DrPocketSNES"