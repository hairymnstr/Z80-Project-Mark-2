all: bios.bin

bios.bin: bios.z8a rtc.z8a uart.z8a gpu.z8a statics.z8a gpu_commands.z8a menu.z8a boot.z8a maths.z8a sd.z8a sd_commands.z8a fat.z8a usb.z8a
	z80asm bios.z8a -Lbios.lbl -o bios.bin

install:
	/home/nathan/active/proppc/minimal/code/pc/rom_flasher bios.bin

try:
	/home/nathan/active/proppc/minimal/code/pc/load_ram bios.bin
