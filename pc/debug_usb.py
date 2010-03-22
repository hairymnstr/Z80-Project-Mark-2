# -*- coding: utf-8 -*-
import seriallib

s = seriallib.Port()
p = seriallib.Packet()

#p.set_command(seriallib.WRIO)
#p.set_data("\x00\x07e")
#s.send(str(p))

#pkr = s.receive()
#print repr(pkr)

while True:
  p.set_command(seriallib.RDIO)
  p.set_data("\x00\x08")
  s.send(str(p))

  pkr = s.receive()
  print repr(pkr)
  a = raw_input()
  if ord(pkr[2]) & 0x80:
    break

  p.set_command(seriallib.RDIO)
  p.set_data("\x00\x07")
  s.send(str(p))

  pkr = s.receive()

  print repr(pkr[2])

opr = "SCS\r"
p.set_command(seriallib.WRIO)
for c in opr:
  p.set_data("\x00\x07" + c)
  s.safe_send(str(p))

while True:
  p.set_command(seriallib.RDIO)
  p.set_data("\x00\x08")
  s.send(str(p))

  pkr = s.receive()
  print repr(pkr)
  if ord(pkr[2]) & 0x80:
    break

  p.set_command(seriallib.RDIO)
  p.set_data("\x00\x07")
  s.send(str(p))

  pkr = s.receive()

  print repr(pkr[2])

opr = "\x0e BOOT.Z8B\r"
p.set_command(seriallib.WRIO)
for c in opr:
  p.set_data("\x00\x07" + c)
  s.safe_send(str(p))

while True:
  p.set_command(seriallib.RDIO)
  p.set_data("\x00\x08")
  s.send(str(p))

  pkr = s.receive()
  print repr(pkr)
  if ord(pkr[2]) & 0x80:
    break

  p.set_command(seriallib.RDIO)
  p.set_data("\x00\x07")
  s.send(str(p))

  pkr = s.receive()

  print repr(pkr[2])