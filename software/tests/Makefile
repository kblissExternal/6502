CA=ca65
LD=ld65

all: test cursor colors

colors: colors.o
	$(LD) -C prg.config -vm -m colors.map -o colors.prg colors.o

colors.o:
	$(CA) --cpu 65C02 --listing colors.lst -o colors.o colors.asm

cursor: cursor.o
	$(LD) -C prg.config -vm -m cursor.map -o cursor.prg cursor.o

cursor.o:
	$(CA) --cpu 65C02 --listing cursor.lst -o cursor.o cursor.asm

test: test.o
	$(LD) -C prg.config -vm -m test.map -o test.prg test.o

test.o:
	$(CA) --cpu 65C02 --listing test.lst -o test.o test.asm

clean:
	del *.o *.rom *.map *.lst
