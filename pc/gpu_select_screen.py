# -*- coding: utf-8 -*-
import seriallib

pk = seriallib.Packet()

sp = seriallib.Port()

pk.set_command(seriallib.RDIO)
pk.set_data("\x00\x03")

sp.send(str(pk))

rp = sp.receive()
print repr(rp)