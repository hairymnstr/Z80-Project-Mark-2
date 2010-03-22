# -*- coding: utf-8 -*-
import seriallib

tp = seriallib.Packet()
tp.set_command(seriallib.DOCMD)
tp.set_data(chr(seriallib.DORST))

ser = seriallib.Port()
ser.safe_send(tp)