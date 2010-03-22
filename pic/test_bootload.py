import serial

s = serial.Serial("/dev/ttyUSB0")

cmd = "\x04\x03\x00\x00\x20"    # command to block read memory, starting at 0x0000, read 32 (0x20) bytes

cs = "\x00"
for c in cmd:
  cs = chr(ord(c) ^ ord(cs))

s.write(cmd + cs)

print ord(s.read())
print ord(s.read())

o = ""
for n in range(32):
  o = "%s%02X " % (o, ord(s.read()))

print o

print ord(s.read())

