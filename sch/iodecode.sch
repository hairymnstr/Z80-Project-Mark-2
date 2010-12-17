EESchema Schematic File Version 2  date Fri 17 Dec 2010 20:03:20 GMT
LIBS:74xx
LIBS:adc-dac
LIBS:analog_switches
LIBS:audio
LIBS:cmos4000
LIBS:conn
LIBS:contrib
LIBS:cypress
LIBS:device
LIBS:digital-audio
LIBS:display
LIBS:dsp
LIBS:intel
LIBS:interface
LIBS:linear
LIBS:maxim
LIBS:memory
LIBS:microchip
LIBS:microcontrollers
LIBS:motorola
LIBS:parallax
LIBS:philips
LIBS:power
LIBS:regul
LIBS:siliconi
LIBS:special
LIBS:texas
LIBS:valves
LIBS:xilinx
LIBS:z80_mark2-cache
EELAYER 24  0
EELAYER END
$Descr A4 11700 8267
Sheet 5 12
Title ""
Date "17 dec 2010"
Rev ""
Comp ""
Comment1 ""
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
NoConn ~ 4500 3700
NoConn ~ 4500 3600
NoConn ~ 4500 3500
NoConn ~ 4500 3400
NoConn ~ 4500 3300
NoConn ~ 4500 3200
NoConn ~ 4500 3100
NoConn ~ 4500 3000
NoConn ~ 4500 2900
NoConn ~ 4500 2800
NoConn ~ 4500 2700
NoConn ~ 4500 2600
NoConn ~ 4500 2500
NoConn ~ 4500 2400
Wire Wire Line
	4500 2300 4600 2300
Wire Wire Line
	7800 2500 7900 2500
Wire Wire Line
	6100 3000 6100 3100
Wire Wire Line
	6100 3100 6200 3100
Wire Wire Line
	6100 5100 6100 5000
Wire Wire Line
	6100 5000 6200 5000
Wire Wire Line
	6100 4800 6100 4900
Connection ~ 5650 1900
Wire Wire Line
	5350 1900 6200 1900
Connection ~ 5450 1700
Wire Wire Line
	5350 1700 6200 1700
Wire Wire Line
	6200 3600 5550 3600
Wire Wire Line
	5550 3600 5550 1800
Wire Wire Line
	6200 3800 5750 3800
Wire Wire Line
	5750 3800 5750 2000
Wire Wire Line
	6100 4100 6200 4100
Wire Wire Line
	4500 2200 6200 2200
Wire Wire Line
	2800 3500 2800 3600
Wire Wire Line
	2800 3600 2900 3600
Wire Wire Line
	2800 2900 2800 2800
Wire Wire Line
	2800 2800 2900 2800
Wire Wire Line
	2800 2700 2900 2700
Wire Wire Line
	2900 3700 2800 3700
Wire Wire Line
	2800 3700 2800 3800
Wire Wire Line
	2900 2200 2800 2200
Wire Wire Line
	2900 2300 2800 2300
Wire Wire Line
	2900 2400 2800 2400
Wire Wire Line
	2900 2500 2800 2500
Wire Wire Line
	6200 2300 6100 2300
Wire Wire Line
	6200 4000 5850 4000
Wire Wire Line
	5850 4000 5850 2200
Connection ~ 5850 2200
Wire Wire Line
	6200 3700 5650 3700
Wire Wire Line
	5650 3700 5650 1900
Wire Wire Line
	6200 3500 5450 3500
Wire Wire Line
	5450 3500 5450 1700
Wire Wire Line
	5350 1800 6200 1800
Connection ~ 5550 1800
Wire Wire Line
	5350 2000 6200 2000
Connection ~ 5750 2000
Wire Wire Line
	6100 4900 6200 4900
Wire Wire Line
	6200 3200 6100 3200
Wire Wire Line
	6100 3200 6100 3300
Wire Wire Line
	7800 1700 7900 1700
Wire Wire Line
	7800 1800 7900 1800
Wire Wire Line
	7800 1900 7900 1900
Wire Wire Line
	7800 2000 7900 2000
Wire Wire Line
	7800 2100 7900 2100
Wire Wire Line
	7800 2200 7900 2200
Wire Wire Line
	7800 2300 7900 2300
Wire Wire Line
	7800 2400 7900 2400
Wire Wire Line
	7800 3500 7900 3500
Wire Wire Line
	7800 3600 7900 3600
Wire Wire Line
	7800 3700 7900 3700
Wire Wire Line
	7800 3800 7900 3800
Wire Wire Line
	7800 3900 7900 3900
Wire Wire Line
	7800 4000 7900 4000
Wire Wire Line
	7800 4100 7900 4100
Wire Wire Line
	7800 4200 7900 4200
Text GLabel 4600 2300 2    60   Output ~ 0
CLK_CS
NoConn ~ 7800 5000
NoConn ~ 7800 4900
NoConn ~ 7800 4800
NoConn ~ 7800 4700
NoConn ~ 7800 4600
NoConn ~ 7800 4500
NoConn ~ 7800 4400
NoConn ~ 7800 4300
NoConn ~ 7800 3200
NoConn ~ 7800 3100
NoConn ~ 7800 3000
NoConn ~ 7800 2900
NoConn ~ 7800 2800
NoConn ~ 7800 2700
NoConn ~ 7800 2600
Text GLabel 7900 2000 2    60   Output ~ 0
KEY_RD
Text GLabel 7900 4200 2    60   Output ~ 0
USB_WR
Text GLabel 7900 4000 2    60   Output ~ 0
GPU_DAT_WR
Text GLabel 7900 4100 2    60   Output ~ 0
PIE
Text GLabel 7900 3900 2    60   Output ~ 0
GPU_CMD_WR
Text GLabel 7900 3800 2    60   Output ~ 0
KEY_WR
Text GLabel 7900 3700 2    60   Output ~ 0
SD_WR
Text GLabel 7900 3600 2    60   Output ~ 0
DEBUG
Text GLabel 7900 3500 2    60   Output ~ 0
TXREG
Text GLabel 7900 2500 2    60   Output ~ 0
STATUS
Text GLabel 7900 2400 2    60   Output ~ 0
USB_RD
Text GLabel 7900 2300 2    60   Output ~ 0
PIF
Text GLabel 7900 2200 2    60   Output ~ 0
GPU_DAT_RD
Text GLabel 7900 2100 2    60   Output ~ 0
GPU_CMD_RD
Text GLabel 7900 1900 2    60   Output ~ 0
SD_RD
Text GLabel 7900 1800 2    60   Output ~ 0
RCSTA
Text GLabel 7900 1700 2    60   Output ~ 0
RCREG
$Comp
L GND #PWR?
U 1 1 4D09096B
P 6100 5100
F 0 "#PWR?" H 6100 5100 30  0001 C CNN
F 1 "GND" H 6100 5030 30  0001 C CNN
	1    6100 5100
	1    0    0    -1  
$EndComp
$Comp
L +5V #PWR?
U 1 1 4D090966
P 6100 4800
F 0 "#PWR?" H 6100 4890 20  0001 C CNN
F 1 "+5V" H 6100 4890 30  0000 C CNN
	1    6100 4800
	1    0    0    -1  
$EndComp
$Comp
L +5V #PWR?
U 1 1 4D09095F
P 6100 3000
F 0 "#PWR?" H 6100 3090 20  0001 C CNN
F 1 "+5V" H 6100 3090 30  0000 C CNN
	1    6100 3000
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR?
U 1 1 4D09095B
P 6100 3300
F 0 "#PWR?" H 6100 3300 30  0001 C CNN
F 1 "GND" H 6100 3230 30  0001 C CNN
	1    6100 3300
	1    0    0    -1  
$EndComp
Text GLabel 5350 2000 0    60   Input ~ 0
A3
Text GLabel 5350 1900 0    60   Input ~ 0
A2
Text GLabel 5350 1800 0    60   Input ~ 0
A1
Text GLabel 5350 1700 0    60   Input ~ 0
A0
Text GLabel 6100 4100 0    60   Input ~ 0
WR
Text GLabel 6100 2300 0    60   Input ~ 0
RD
Text GLabel 2800 2500 0    60   Input ~ 0
A7
Text GLabel 2800 2400 0    60   Input ~ 0
A6
Text GLabel 2800 2300 0    60   Input ~ 0
A5
Text GLabel 2800 2200 0    60   Input ~ 0
A4
$Comp
L GND #PWR?
U 1 1 4D090897
P 2800 3800
F 0 "#PWR?" H 2800 3800 30  0001 C CNN
F 1 "GND" H 2800 3730 30  0001 C CNN
	1    2800 3800
	1    0    0    -1  
$EndComp
$Comp
L +5V #PWR?
U 1 1 4D090894
P 2800 3500
F 0 "#PWR?" H 2800 3590 20  0001 C CNN
F 1 "+5V" H 2800 3590 30  0000 C CNN
	1    2800 3500
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR?
U 1 1 4D09087C
P 2800 2900
F 0 "#PWR?" H 2800 2900 30  0001 C CNN
F 1 "GND" H 2800 2830 30  0001 C CNN
	1    2800 2900
	1    0    0    -1  
$EndComp
Text GLabel 2800 2700 0    60   Input ~ 0
iORQ
$Comp
L 74HC154 IC?
U 1 1 4D090776
P 7000 4250
AR Path="/4D09070D/4D090772" Ref="IC?"  Part="1" 
AR Path="/4D09070D/4D090776" Ref="IC?"  Part="1" 
F 0 "IC?" H 6550 5150 60  0000 C CNN
F 1 "74HC154" H 7250 3350 60  0000 C CNN
	1    7000 4250
	1    0    0    -1  
$EndComp
$Comp
L 74HC154 IC?
U 1 1 4D090775
P 7000 2450
AR Path="/4D09070D/4D090772" Ref="IC?"  Part="1" 
AR Path="/4D09070D/4D090775" Ref="IC?"  Part="1" 
F 0 "IC?" H 6550 3350 60  0000 C CNN
F 1 "74HC154" H 7250 1550 60  0000 C CNN
	1    7000 2450
	1    0    0    -1  
$EndComp
$Comp
L 74HC154 IC?
U 1 1 4D090772
P 3700 2950
F 0 "IC?" H 3250 3850 60  0000 C CNN
F 1 "74HC154" H 3950 2050 60  0000 C CNN
	1    3700 2950
	1    0    0    -1  
$EndComp
$EndSCHEMATC
