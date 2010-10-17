CFLAGS = -Wall

all : spc700a.s

spc700a.s : spcgen
	./spcgen

spcgen : spcgen.o


clean :
	$(RM) spc700a.s spcgen spcgen.o

