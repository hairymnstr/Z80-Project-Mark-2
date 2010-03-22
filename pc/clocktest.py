# -*- coding: utf-8 -*-
import seriallib

port = seriallib.Port()

port.ser.timeout = 0.1

while 1:
  if port.ser.read() == "":
    break

pack1 = seriallib.Packet()

pack1.set_command(seriallib.DOCMD)
pack1.set_data(chr(seriallib.DOGETDMA))
port.safe_send(pack1)

pack1.set_command(seriallib.WRIO)
pack1.set_data("\x00\x14\x20")

#port.send(str(pack1))

#print "got", repr(port.receive())

pack2 = seriallib.Packet()
pack2.set_command(seriallib.RDIO)
pack2.set_data("\x00\x14")

port.send(str(pack2))

print repr(port.receive())