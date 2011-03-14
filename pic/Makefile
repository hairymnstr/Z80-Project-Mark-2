all: debug_kernel.hex

debug_kernel.hex: serial.o main.o host_bus.o boot.o rom.o sd.o portpins.inc eeprom.o
	gplink -m -c -s /usr/share/gputils/lkr/18f4520.lkr serial.o sd.o main.o eeprom.o host_bus.o boot.o rom.o -o debug_kernel.hex

serial.o: serial.asm
	gpasm -c serial.asm

main.o: main.asm
	gpasm -c main.asm

host_bus.o: host_bus.asm
	gpasm -c host_bus.asm

boot.o: boot.asm
	gpasm -c boot.asm

sd.o: sd.asm
	gpasm -c sd.asm

rom.o: rom.asm
	gpasm -c rom.asm

eeprom.o: eeprom.asm
	gpasm -c eeprom.asm

rom.asm: bios.bin
	python ../z80/bin2asm.py

bios.bin: ../z80/bios.z8a
	z80asm ../z80/bios.z8a -o ../z80/bios.bin -I../z80/

install:
	pk2cmd -PPIC18F4520 -M -Fdebug_kernel.hex

clean:
	rm -rf *.o
	rm -rf *.lst
	rm -rf *.map
