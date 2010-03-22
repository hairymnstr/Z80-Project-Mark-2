# -*- coding: utf-8 -*-
# test_gpu.py

# tests the gpu code by sending bytes straight from the PC using the debug
# port

import seriallib

p = seriallib.Port()

pk = seriallib.Packet()

pk.set_command(seriallib.WRIO)

# simple text
message = "Hello World!\n"

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