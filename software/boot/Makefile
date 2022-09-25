CA=ca65
LD=ld65

all: boot

boot: boot.o
	$(LD) -C boot.config -vm -m boot.map -o boot.rom boot.o

boot.o:
	$(CA) --cpu 65C02 --listing boot.lst -o boot.o boot.asm

test.o:
	$(CA) --cpu 65C02 --listing test.lst -o test.o test.asm

clean:
	del *.o *.rom *.map *.lst
