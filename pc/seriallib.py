# -*- coding: utf-8 -*-
import serial, sys

# Serial interface to Z80 Project Mark 2 debug port, general utilities

# constant declarations
RDMEM = 2
WRMEM = 3
RDMEMBLK = 4
WRMEMBLK = 5
RDIO = 6
WRIO = 7
UPDBIOS = 8
DOCMD = 9


DOGETRST = 1
DOGETDMA = 2
DOGETSLV = 3
DORST = 4

ERRMASK = 0x40

errors = {}
errors[0] = "Unknown"
errors[1] = "Checksum Error"
errors[2] = "Bad Command"
errors[3] = "Unused Command"
errors[4] = "Wrong Parameter Count"
errors[5] = "Request too large"
errors[6] = "BIOS Update address too high"
errors[7] = "BIOS Update address not 128 byte offset"
errors[8] = "BIOS block verify failed"
errors[9] = "Do Command, illegal command"

# Packet - class that wraps all the packet handling functions

class Packet:
  def __init__(self):
    command = "\x00"
    data = ""

  def __str__(self):
    return self.as_string()

  def __repr__(self):
    output = ""
    for c in self.as_string():
      output = "%s%02X " % (output, ord(c))
    output = output[:-1]        # get rid of trailing space
    return output

  def as_string(self):
    output = self.command
    output += chr(len(self.data))
    output += self.data
    cs = "\x00"
    for c in output:
      cs = chr(ord(c) ^ ord(cs))
    output += cs
    return output

  def set_command(self, com):
    if com > 31:
      com = 31
      sys.stderr.write("Warning: Command %d truncated must be in range 0-31\n" % com)
    elif com < 0:
      com = 0
      sys.stderr.write("Warning: Command %d truncated must be in range 0-31\n" % com)

    self.command = chr(com)
    return

  def get_command(self):
    return ord(self.command)

  def __getitem__(self,y):
    s = self.as_string()
    return s[y]

  def __getslice__(self,x,y):
    s = self.as_string()
    return s[x:y]

  def __len__(self):
    return len(self.as_string())

  def set_data(self,data):
    self.data = data
    return

  def get_data(self):
    return data

  def set_string(self, bytes):
    # sets the parameters from a byte string (possibly a received packet)
    # first run checksum
    cs = "\x00"
    for c in bytes:
      cs = chr(ord(cs) ^ ord(c))
    if not cs == "\x00":
      sys.stderr.write("Error importing packet, checksum failed\n")
      return 1

    # checksum okay so take packet appart
    if not ord(bytes[1]) == (len(bytes)-3):
      sys.stderr.write("Error importing packet, wrong byte count\n")
      return 1

    # length and checksum okay, just set command and data
    self.command = bytes[0]
    self.data = bytes[2:-1]
    return

  def get_error(self):
    if ord(self.command) < 0x40:
      return (0, "No Error")
    else:
      # need to return a useful error message
      if len(self.data) < 2:
        return (-1, "Faulty Packet")
      code = ord(self.data[0]) * 256 + ord(self.data[1])
      if code == 1:
        return (1, "Checksum error calculated %02X" % ord(self.data[3]))
      elif code == 2:
        return (2, "Bad Command, %02X is out of range 0-31" % ord(self.data[3]))
      elif code == 4:
        return (3, "Wrong number of parameters, was expecting %d" % ord(self.data[3]))
      elif code == 9:
        return (9, "Do %02X is undefined." % ord(self.data[3]))
      else:
        if code < len(errors):
          return (code, errors[code])
        else:
          return (code, "Unknown error")

class Port:
  def __init__(self):
    try:
      self.ser = serial.Serial("/dev/serial/by-id/usb-FTDI_TTL232R_FTE3Q88E-if00-port0")
    except:
      print "Failed to get favourite port."
      self.ser = serial.Serial("/dev/ttyUSB0")

  def send(self, packet):
    self.ser.write(str(packet))

  def receive(self):
    rp = Packet()
    pks = ""
    mode = "cmd"
    count = 0
    while True:
      r = self.ser.read()
      if not r == "":
        if mode == "cmd":
          pks = r
          mode = "len"
        elif mode == "len":
          pks += r
          count = ord(r) + 1
          mode = "dat"
        else:
          pks += r
          count -= 1
          if count == 0:
            break

    rp.set_string(pks)
    return rp

  def safe_send(self, packet):
    # sends packet then makes sure response is not an error
    # if it is simply prints the error and kills python
    self.send(packet)
    rp = self.receive()
    if rp.get_error()[0] > 0:
      sys.stderr.write("Error communicating with PIC:\n  Code %d: %s\n" % rp.get_error())
      sys.exit(1)
    return