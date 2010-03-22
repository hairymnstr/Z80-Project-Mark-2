all: keyboard_driver.hex

keyboard_driver.hex: keyboard.o hostbus.o ps2.o ndcodes.o asciicodes.o translation.o
	gplink -m -c -s /usr/share/gputils/lkr/18f4520.lkr keyboard.o asciicodes.o translation.o ndcodes.o ps2.o hostbus.o -o keyboard_driver.hex

keyboard.o: main.asm
	gpasm -c main.asm -o keyboard.o

hostbus.o: hostbus.asm
	gpasm -c hostbus.asm -o hostbus.o

ps2.o: ps2.asm
	gpasm -c ps2.asm -o ps2.o

ndcodes.o: ndcodes.asm
	gpasm -c ndcodes.asm -o ndcodes.o

asciicodes.o: asciicodes.asm
	gpasm -c asciicodes.asm -o asciicodes.o

translation.o: translation.asm
	gpasm -c translation.asm -o translation.o

install:
	pk2cmd -PPIC18F4520 -M -Fkeyboard_driver.hex

clean:
	rm *.o
