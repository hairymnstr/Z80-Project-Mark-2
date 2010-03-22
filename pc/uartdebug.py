# -*- coding: utf-8 -*-
import seriallib

p = seriallib.Packet()

p.set_command(seriallib.RDIO)
p.set_data("\x00\x01")

s = seriallib.Port()

s.send(p)

rp = s.receive()
print repr(rp)

out = ""
for n in range(7,-1,-1):
  if ord(rp[2]) & (1 << n):
    out += "1"
  else:
    out += "0"
print out

if out[-1] == "1":
  p.set_data("\x00\x00")
  s.send(p)
  rp = s.receive()
  print rp[2]