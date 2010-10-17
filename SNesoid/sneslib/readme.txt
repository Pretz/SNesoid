DrPocketSnes
Super Nintendo (SNES) Emulator
by Reesy

DrPocketSnes is a Super Nintendo (SNES) emulator for the GP2X and Gizmondo. I've taken bits from PocketSnes and SquidgeSnes and merged them into another new emulator.  I then stuck my menu system on it and called it my own :) you've got to love porting stuff.

So credits for this emulator should really go to.

Snes9x Team for creating the original Snes9x emulator
http://www.snes9x.com/

Scott Ramsby for PocketSnes port based on Snes9x sources
http://paqpark.nuclearfallout.net/projects/pocketsnes.php

Yoyofr for OpenSnes9x port based on Snes9x sources
http://yoyofr.fr.st/

Squidge for the SquidgeSnes port based on OpenSnes9x
http://squidge2x.com/

Notaz for his fixes and improvements to SquidgeSnes.
http://notaz.atspace.com/

Rlyeh for his work on the gp2x (not so)minimal sdk
http://www.retrodev.info/

HeadOverHeels for lots of fixes and added functionality
(No known website)

Reesy for merging everything and sticking a menu on it...the really complicated stuff ;).
http://reesy.gp32x.de/

====================
IMPORTANT
When upgrading from v4 to v5 you will need to manually move the savestate files (*.sv*) from the options directory into the savestate directory and the SRAM files (*.srm) from the root installation directory into the sram directory.  See change history for more details.
====================

==============
Change History
==============
___________________________________
Version 6.4.4	Release Date 01/06/2008
___________________________________
Changes by Reesy
	1. version includes fixes by HeadOverHeels ( 6.4.3 ). 
	2. KGSDK.DLL no longer required ( all now built into executable )
	3. Zipped save states
	4. Non-Gizmondo related menu options now hidden.
	5. Snes Select button now mapped :) 
	6. Rom Browser code tidied, you can now set the default directory
		from inside the rom browser.  The rom browser now also tells
		you the current directory.
___________________________________
Version 6.4.3	Release Date 23/02/2008
___________________________________
Changes by HeadOverHeels
	1. USB pads support (GP2x only)
	2. Fixed sky colour for Super Mario World when transparencies are not active.
	3. Fixed framerate for PAL games (50 fps) and added an option to configure region (AUTO, NTSC, PAL)
	4. Fixed sound problems with some games (Ilussion of Gaia for exmaple)
	5. Sound frequencies have been changed (8250,16500) to make GP2X F200 compatible
	6. 256x240 games resolution problem have been fixed
	7. C4 chip support (Megaman X2, X3)
	8. High resolution text support (Seiken Densetsu 3 - Secret of Mana2)
	9. Added DSP optimizations from snes9xTYL of Yoyofr.
	10. F200 sound level now is lower
	11. SDD1 support (Star Ocean & Street Fighter Alpha 2)
		SDD1 decompressed packs are supported. SDD1GFX.DAT & SDD1GFX.IDX must be copied to a subdirectory named socnsdd1 (for Star Ocean) and sfa2sdd1 (for Street Fighter 2 alpha). Create these subdirectories in the roms directory.
		If no packs are found, the emulator uses realtime decompression (slower)
	12. Other minor fixes and optimizations.
	13. Added stereo sound.
	14. New advanced hacks options:
		Audio performance hack
		Ignore palette writes
		Ignore Fixed Colour
		Ignore Windows clipping
		Ignore Add/Sub modes
		Layer desactivation___
________________________________
Version 6	Release Date 04/02/2007
___________________________________
Changes by Reesy
	1. Fixed a bug on the rom browsing code.  Strings were not being terminated correctly.  
___________________________________
Version 5	Release Date 03/02/2007
___________________________________
	1. Changed the way SRAM works.  The old versions of PocketSnes used a timer to check if SRAM had changed while the SNES emulator was running.  If a change was detected the SRAM was saved straight away.  This used to cause glitches in the framerate.  SRAM is now saved when you enter the menu as long as you have SRAM saving set to automatic in the options menu.
	2. Added options to allow you to switch MMU hack on or off
	3. Added options to allow you to switch Craigx's RAM settings on or off.
	4. Fixed problems where data was not being saved to SD card correctly, I was missing a few calls to sync()
	5. I've tidied up the installation directory abit.  Most things used to be stored in the options sub directory and somethings were saved to the root installation directory, which was a bit of a mess.  So I've now created the following 3 directories in order to make things more logical.
	
	options (*.opt)		- used to hold global and individual game settings
	savestate (*.sv*) 	- used to hold save states for all games
	sram (*.srm)		- used to hold SRAM saves for all games
	
	This means that we you upgrade from Version 4 to Version 5 you will need to manually copy the savestates out of the options directory and into the savestate directory in order for PocketSnes to recognise them.  You will also have to move the SRAM files out of the root
installation directory and into the sram directory.	
___________________________________	
Version 4	Release Date 30/01/2007
___________________________________
	1. Fixed timer code which was causing the emulator to crash
___________________________________	
Version 3	Release Date 24/01/2007
___________________________________
	1. Scaled display mode added.
	2. 44K sound mode added.
	3. Super FX support added - very very buggy and slow
___________________________________
Version 2	Release Date 24/01/2007
___________________________________
	1. Fixed Diagnals.
	2. Fixed Volume controls.
	3. Fixed Reset game function.
	4. Snes Select button now working.
___________________________________	
Version 1	Release Date 24/01/2007
___________________________________
	Initial release

=========================
Installation Instructions - Gizmondo
=========================

When you extracted the release zip file it would have created a DrPocketSnes folder.  Simply copy this folder onto your SD card.

NOTE: If you are using zektor's menu system, then the DrPocketSnes.exe will need to be renamed to autorun.exe in order to be seen.

Now you need to copy some SNES roms to you SD card.  Again you can put your roms anywhere you like on your SD card, just remember where you put them as you'll need to know this later. 

============
Menu Options
============
_______________________________________________	
Return To Game
	If you have a rom loaded this will allow to exit the menu and return to the game.
_______________________________________________	
Select Rom
	Takes you to the Rom Selection screen which allows you load a new game.
_______________________________________________		
Manage Save States
	Takes you to the save state management screen.  Save states allow you to save your current position in the currently loaded game.  This means that you can reload a particular position in the game as many times as you want.
_______________________________________________	
Save Sram
	Allows you save the current contents of SRAM to a file.  SRAM is the battery backup ram which used to be on the Snes cartridges.  This allowed high scores or game progress, so that the next time you loaded the snes game you could continue where you left off.  If you plan to use save states then you don't need to worry about SRAM saves as the save state holds all of this information as well.
_______________________________________________	
SNES Options
	Takes you into the options screen which allows you to customise how the emulator runs. See "SNES Options - In Detail" for more information on each of the settings.
_______________________________________________
Reset Game
	Allows you to reset the current rom, its the same as reloading the rom apart from you don't have to read the rom file from the SD card again.
_______________________________________________	
Exit Application
	Exits PocketSnes and reloaded the GP2X menu.
_______________________________________________

========================	
SNES Options - In Detail
========================
_______________________________________________
Sound
	Allows you to turn the sound on or off
_______________________________________________	
Sound Rate
	Allows you to configure the sample rate of the sound emulation.  The high the rate the clearer and more accurate the sound.
_______________________________________________
Volumne
	Allows you setup default volume levels.  Volume can also be controlled using the volume controls on the GP2X.
_______________________________________________	
Cpu Speed (GP2x only)
	Allows you select the GP2X cpu speed to be used when emulating the Snes.  The higher the cpu speed the smoother the emulation is ( plus it drains you battery more)
_______________________________________________	
FrameSkip
	Allows you to control how many frames are not rendered, this can allow you to keep full speed emulation when at low cpu speeds. AUTO will skip as many frames as needed in order to maintain full speed emulation.
_______________________________________________	
Action Buttons (GP2x only)
	The GP2X has the same button as the snes but the buttons are in the wrong order.  This option allows you to have the same button names as the snes, or to have the same button positions as snes.
	NORMAL = same button names as Snes
	SWAPPED = same button positions as Snes
_______________________________________________	
Show FPS
	This allows you to see how man frames are being rendered per second.  This can allow you to see how the emulator is performing.
_______________________________________________	
Brightness (GP2x only)
	This allows you to control the current brightness of the screen.  You can make it darker or brighter.
_______________________________________________	
Transparencies
	The SNES has very complicated graphics hardware which can be quite slow to emulate.  Switching off transparencies can improve performce but makes some games unplayable because you can not see all of the information that you need.
_______________________________________________	
Render Mode (GP2x only)
	Allows you to scale the emulated SNES graphics.  The normal SNES screen resolution is less than the GP2X's, so when in unscaled mode the graphics appear in a window.  If you select the scaled mode then the graphics are stretched to fill the screen.
_______________________________________________	
RAM Timing (GP2x only)
	This allows you select faster ram timings.  This can improve performance.  If you change this option you need to restart PocketSnes because these settings are only applied as the emulator is first started.
_______________________________________________	
MMU Hack (GP2x only)
	This option allows you to enable the MMU hack developed by Squidge.  This option massively improves performance and is recommended.  Again if you change this option you need to restart PocketSnes because these settings are only applied as the emulator is first started.
_______________________________________________	
Saving SRAM
	This option allows you to control how the SRAM is saved to you SD card.  If you select automatic then SRAM will be saved automatically everytime you return to the menu if it has been modified during the last run of emulation.  If you select the manual option then SRAM will only be saved when you select the Save SRAM menu option from the main menu.
_______________________________________________	
Load Global Settings
	This option will reload the global settings.  Global Settings affect all games as long as the games does not have a setting file of its own ( See Load Settings for current game). 
_______________________________________________	
Save Global Settings
	This option allows you to save the current settings to the SD card.  Everytime you load a new rom these settings will be reloaded, so basically they become you default settings.  This can be overwritten using the "Save Settings For Current Game" option which allows you to save a config file for a particular rom. So each time you load the rom these settings will automatically be loaded.
_______________________________________________	
Delete Global Settings
	Deletes any global setting file that has been created.  If you have no global setting file then PocketSnes will use its own internal default settings when loading a new rom.
_______________________________________________	
Load Settings For Current Game
	This option will load any setting file associated with the currently loaded rom.
_______________________________________________	
Save Settings For Current Game
	This option allows you to save a config file for the currently loaded rom. So each time you load this rom these settings will automatically be loaded instead of the global settings.
_______________________________________________	
Delete Settings For Current Game
	Deletes any config file for the currently loaded rom.
_______________________________________________	
Save Current Rom Directory
	This option allows you to save the current rom directory as you default rom directory.
_______________________________________________
Reset Default Rom Directory
	This option clears any previous default rom directory.  The Rom directory is reset to the current working directory instead.
_______________________________________________
	
	
	









