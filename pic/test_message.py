import serial,sys

s = serial.Serial("/dev/ttyUSB0")

msg = "\x00\x00\x00"

if len(sys.argv) > 1:
  if sys.argv[1] == "u":
    msg = "\x11\x00\x11"
  elif sys.argv[1] == "ce":
    msg = "\x11\x00\x10"
  elif sys.argv[1] == "i":
    msg = "\x23\x00\x23"
  elif sys.argv[1] == "wi":
    msg = "\x07\x03\x00\x01\xAA\xAF"
  elif sys.argv[1] == "wm":
    if len(sys.argv) < 4:
      print "not enough params"
      sys.exit(-1)
    ad = "%04X" % int(sys.argv[2])
    d = "%02X" % int(sys.argv[3])
    msg = "\x03\x03" + chr(int(ad[0:2],16)) + chr(int(ad[2:4],16))
    msg += chr(int(d,16))
    cs = "\x00"
    for c in msg:
      cs = chr(ord(cs) ^ ord(c))
    msg = msg + cs
  elif sys.argv[1] == "rm":
    if len(sys.argv) < 3:
      print "not enough params"
      sys.exit(-1)
    ad = "%04X" % int(sys.argv[2])
    msg = "\x02\x02" + chr(int(ad[0:2],16)) + chr(int(ad[2:4],16))
    cs = "\x00"
    for c in msg:
      cs = chr(ord(cs) ^ ord(c))
    msg = msg + cs
s.write(msg)

s.timeout = 1.0

while True:
  a = s.read()
  if a != "":
    print "%02X" % ord(a)
  else:
    break
