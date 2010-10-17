# Makefile for MS Visual C

ALL : spc700a.s

spc700a.s : spcgen.exe
	spcgen.exe

spcgen.exe :
	cl /W3 spcgen.c


CLEAN :
	-@erase spc700a.s
	-@erase spcgen.exe
	-@erase spcgen.obj
