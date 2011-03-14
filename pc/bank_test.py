# -*- coding: utf-8 -*-
# test_gpu.py

# tests the gpu code by sending bytes straight from the PC using the debug
# port

import seriallib
import sys

p = seriallib.Port()

pk = seriallib.Packet()

pk.set_command(seriallib.RDMEMBLK)
pk.set_data("\x01\x00\x04")
p.send(pk)
rp = p.receive()
print "ramtop contents:"
print repr(rp)

pk.set_command(seriallib.RDMEM)
pk.set_data("\x00\x00")
p.send(pk)
rp = p.receive()
print "address $0000 contents:"
print repr(rp)

pk.set_data("\x80\x00")
p.send(pk)
rp = p.receive()
print "address $8000 contents:"
print repr(rp)

sys.exit(1)

pk.set_command(seriallib.DOCMD)
pk.set_data(chr(seriallib.DOGETSLV))
p.safe_send(pk)

pk.set_command(seriallib.WRIO)
pk.set_data("\x00\x24" + "\xFF")
p.safe_send(pk)
sys.exit()

for c in message:
  pk.set_data("\x00\x05" + c)

  p.safe_send(str(pk))

# colour test
for i in range(8):
  c = chr(0x28 + i)
  pk.set_data("\x00\x04" + c)
  p.safe_send(str(pk))

  message = "Hello World!\n"

  for c in message:
    pk.set_data("\x00\x05" + c)

    p.safe_send(str(pk))

# cls test
pk.set_data("\x00\x04\x01")

p.safe_send(str(pk))

# screen target test
for i in range(4):

  c = chr(0x60 + i)
  pk.set_data("\x00\x04" + c)
  p.safe_send(str(pk))

  message = "Screen %d\n" % (i)
  print message
  
  for c in message:
    pk.set_data("\x00\x05" + c)

    p.safe_send(str(pk))

pk.set_data("\x00\x04\x60")
p.safe_send(str(pk))

# screen switch test (vga)
for i in range(4):
  print "Press space to switch to screen", i

  raw_input()
  c = chr(0x50 + i)
  pk.set_data("\x00\x04" + c)
  p.safe_send(str(pk))

#screen switch test (tv)
for i in range(4):
  print "Press space to switch to screen", i

  raw_input()
  c = chr(0x58 + i)
  pk.set_data("\x00\x04" + c)
  p.safe_send(str(pk))
