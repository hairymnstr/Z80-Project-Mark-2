#!/usr/bin/env python

import os, sys

# open the rom binary to read

fr = file(os.path.join(os.path.dirname(__file__),"bios.bin"),"rb")

# open the asm file to write

fw = file("../pic/rom.asm","w")

# write the header stuff into the rom file

fw.write("list p=18f4520\n")
fw.write("#include <p18f4520.inc>\n")
fw.write("\n")
fw.write("    org 0x6000\n")
fw.write("\n")

# need to write a 8k image so start a counter
bytes = 8192

# write the rom data
b = fr.read(8)
while len(b) == 8:
  fw.write("    data 0x%02X%02X, 0x%02X%02X, 0x%02X%02X, 0x%02X%02X ; %04X\n" % (ord(b[1]), ord(b[0]), ord(b[3]), ord(b[2]), ord(b[5]), ord(b[4]), ord(b[7]), ord(b[6]), 32768 - bytes))
  bytes -= 8
  b = fr.read(8)

if len(b) > 0:
  # not an exact multiple of 8 bytes
  b = b + "\x00" * (8 - len(b))

  fw.write("    data 0x%02X%02X, 0x%02X%02X, 0x%02X%02X, 0x%02X%02X ; %04X\n" % (ord(b[1]), ord(b[0]), ord(b[3]), ord(b[2]), ord(b[5]), ord(b[4]), ord(b[7]), ord(b[6]), 32768 - bytes))
  bytes -= 8

while bytes > 0:
  fw.write("    data 0x0000, 0x0000, 0x0000, 0x0000 ; %04X\n" % (32768 - bytes))
  bytes -= 8


# finish off the assembly file
fw.write("\n")
fw.write("    end\n")
