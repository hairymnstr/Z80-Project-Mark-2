import serial, sys

ser = serial.Serial("/dev/ttyUSB0")

ser.timeout = 0.5
ser.flushInput()

fw = file("log","wb")

def build_packet(addr, s=128):
  packet = "\x05"

  if s > 251 or s < 1:
    print "Bad packet size, abort"
    sys.exit(-1)

  packet = packet + chr(s+2)

  saddr = "%04X" % addr

  packet += chr(int(saddr[0:2],16)) + chr(int(saddr[2:4], 16))

  cs = chr(5 ^ ord(packet[1]) ^ ord(packet[2]) ^ ord(packet[3]))

  for n in range(addr,addr+s):
    sn = "%04X" % n
    bn = chr(int(sn[0:2], 16) ^ int(sn[2:4], 16))
    packet += bn
    cs = chr(ord(cs) ^ ord(bn))

  packet += cs
  return packet

def compare_packet(addr,s=128):
  pk = build_packet(addr, s)

  pk = "\x04" + pk[1:]
  cs = chr(ord(pk[-1]) ^ 4 ^ 5)
  cs = chr(ord(cs) ^ ord(pk[2]) ^ ord(pk[3]) ^ ord(pk[1]) ^ (ord(pk[1]) - 2))
  pk = pk[0:1] + chr(ord(pk[1]) - 2) + pk[4:-1] + cs

  saddr = "%04X" % addr
  
  msg = "\x04\x03" + chr(int(saddr[0:2], 16)) + chr(int(saddr[2:4],16))
  msg += chr(s)
  msg += chr(4^3^ord(msg[2])^ord(msg[3])^ord(msg[4]))
  ser.write(msg)
  r = ""
  for n in range(len(pk)):
    r += ser.read()

  if r == pk:
    print "okay"
  else:
    print "missmatch at %04X" % addr
    fw.write("%s\n" % repr(pk))
    fw.write("%s\n" % repr(r))
    #print repr(pk)
    #print repr(r)

for n in range(65408,-1,-128):
  p = build_packet(n)
  ser.write(p)
  r = ser.read()
  r += ser.read()
  r += ser.read()
  print repr(r), "%04X" % n

for n in range(0,65535,128):
  compare_packet(n)

fw.close()
