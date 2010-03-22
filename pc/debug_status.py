# -*- coding: utf-8 -*-
import seriallib

s = seriallib.Port()
p = seriallib.Packet()

p.set_command(seriallib.RDIO)
p.set_data("\x00\x08")
s.send(str(p))

pkr = s.receive()

print repr(pkr)