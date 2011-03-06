EESchema Schematic File Version 2  date Sun 06 Mar 2011 19:20:09 GMT
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
Sheet 5 13
Title ""
Date "6 mar 2011"
Rev ""
Comp ""
Comment1 ""
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
Text GLabel 5900 4950 0    60   Input ~ 0
Z80_RST#
Wire Wire Line
	6000 4950 5900 4950
Wire Wire Line
	6850 5200 6850 5300
Wire Wire Line
	7150 4400 7150 4600
Wire Wire Line
	8850 3600 8750 3600
Wire Wire Line
	7550 5000 7550 5100
Connection ~ 7450 5600
Wire Wire Line
	7450 5500 7450 5600
Connection ~ 8700 5200
Wire Wire Line
	8700 5300 8700 4700
Wire Wire Line
	8700 5200 8200 5200
Wire Wire Line
	8200 5200 8200 5100
Connection ~ 8200 4500
Wire Wire Line
	8200 4700 8200 4500
Wire Wire Line
	8800 4400 8700 4400
Wire Wire Line
	8700 4400 8700 4300
Wire Wire Line
	8800 4500 7750 4500
Wire Wire Line
	7750 4500 7750 4400
Wire Wire Line
	7450 4400 7450 4500
Connection ~ 7700 2350
Wire Wire Line
	7700 2450 7700 2350
Wire Wire Line
	8650 3200 8750 3200
Wire Wire Line
	8650 3500 8750 3500
Wire Wire Line
	4050 3800 4150 3800
Wire Wire Line
	4050 3700 4150 3700
Wire Wire Line
	4050 3600 4150 3600
Wire Wire Line
	4050 3500 4150 3500
Wire Wire Line
	4050 3400 4150 3400
Wire Wire Line
	4050 3300 4150 3300
Wire Wire Line
	4050 3200 4150 3200
Wire Wire Line
	5550 3800 6350 3800
Wire Wire Line
	5550 3700 6350 3700
Wire Wire Line
	5550 3600 6350 3600
Wire Wire Line
	5550 3500 6350 3500
Wire Wire Line
	5550 3400 6350 3400
Wire Wire Line
	5550 3300 6350 3300
Wire Wire Line
	5550 3200 6350 3200
Wire Wire Line
	5550 3100 6350 3100
Wire Wire Line
	4150 4100 4000 4100
Wire Wire Line
	4000 4100 4000 4200
Wire Wire Line
	4000 4200 3850 4200
Wire Wire Line
	2650 4100 2550 4100
Wire Wire Line
	2650 4300 2550 4300
Wire Wire Line
	4050 4000 4150 4000
Wire Wire Line
	4150 3100 4050 3100
Wire Wire Line
	8650 3400 8750 3400
Wire Wire Line
	8650 3300 8750 3300
Wire Wire Line
	7600 2450 7600 2350
Wire Wire Line
	7600 2350 7900 2350
Wire Wire Line
	7900 2350 7900 2450
Wire Wire Line
	7300 2350 7300 2450
Wire Wire Line
	7550 4400 7550 4500
Wire Wire Line
	7650 4400 7650 4600
Wire Wire Line
	7650 4600 8800 4600
Wire Wire Line
	8700 4700 8800 4700
Wire Wire Line
	8500 4700 8500 4600
Connection ~ 8500 4600
Wire Wire Line
	8500 5100 8500 5200
Connection ~ 8500 5200
Wire Wire Line
	7200 5400 7200 5600
Wire Wire Line
	7200 5600 7550 5600
Wire Wire Line
	7550 5600 7550 5500
Wire Wire Line
	7450 5100 7450 5000
Wire Wire Line
	9750 3600 9850 3600
Wire Wire Line
	8750 3500 8750 3600
Wire Wire Line
	7150 4600 6850 4600
Wire Wire Line
	6850 4600 6850 4700
Wire Wire Line
	6600 4950 6500 4950
$Comp
L R R?
U 1 1 4D73DCE1
P 6250 4950
F 0 "R?" V 6330 4950 50  0000 C CNN
F 1 "1k" V 6250 4950 50  0000 C CNN
	1    6250 4950
	0    1    1    0   
$EndComp
$Comp
L GND #PWR?
U 1 1 4D73DCCF
P 6850 5300
F 0 "#PWR?" H 6850 5300 30  0001 C CNN
F 1 "GND" H 6850 5230 30  0001 C CNN
	1    6850 5300
	1    0    0    -1  
$EndComp
$Comp
L 2N3904 Q?
U 1 1 4D73DC88
P 6850 4950
F 0 "Q?" H 6950 5100 60  0000 C CNN
F 1 "2N3904" H 7100 4750 60  0000 C CNN
	1    6850 4950
	-1   0    0    -1  
$EndComp
$Comp
L 74HC04 IC?
U 1 1 4D0AB53D
P 9300 3600
F 0 "IC?" H 9450 3700 40  0000 C CNN
F 1 "74HC04" H 9500 3500 40  0000 C CNN
F 2 "108-5299" H 9300 3600 50  0001 C CNN
	1    9300 3600
	-1   0    0    1   
$EndComp
$Comp
L +5V #PWR?
U 1 1 4D0AB50E
P 7200 5400
F 0 "#PWR?" H 7200 5490 20  0001 C CNN
F 1 "+5V" H 7200 5490 30  0000 C CNN
	1    7200 5400
	1    0    0    -1  
$EndComp
$Comp
L LED D?
U 1 1 4D0AB4B6
P 7550 5300
F 0 "D?" H 7550 5400 50  0000 C CNN
F 1 "LED" H 7550 5200 50  0000 C CNN
	1    7550 5300
	0    1    1    0   
$EndComp
$Comp
L LED D?
U 1 1 4D0AB4B2
P 7450 5300
F 0 "D?" H 7450 5400 50  0000 C CNN
F 1 "LED" H 7450 5200 50  0000 C CNN
	1    7450 5300
	0    1    1    0   
$EndComp
$Comp
L R R?
U 1 1 4D0AB4AE
P 7550 4750
AR Path="/4D0AB28F/4D0AB4AC" Ref="R?"  Part="1" 
AR Path="/4D0AB28F/4D0AB4AE" Ref="R?"  Part="1" 
F 0 "R?" V 7500 4550 50  0000 C CNN
F 1 "330" V 7550 4750 50  0000 C CNN
	1    7550 4750
	1    0    0    -1  
$EndComp
$Comp
L R R?
U 1 1 4D0AB4AC
P 7450 4750
F 0 "R?" V 7400 4550 50  0000 C CNN
F 1 "330" V 7450 4750 50  0000 C CNN
	1    7450 4750
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR?
U 1 1 4D0AB4A2
P 8700 5300
F 0 "#PWR?" H 8700 5300 30  0001 C CNN
F 1 "GND" H 8700 5230 30  0001 C CNN
	1    8700 5300
	1    0    0    -1  
$EndComp
$Comp
L C C?
U 1 1 4D0AB48D
P 8200 4900
AR Path="/4D0AB28F/4D0AB488" Ref="C?"  Part="1" 
AR Path="/4D0AB28F/4D0AB48D" Ref="C?"  Part="1" 
F 0 "C?" H 8250 5000 50  0000 L CNN
F 1 "47pF" H 8250 4800 50  0000 L CNN
	1    8200 4900
	1    0    0    -1  
$EndComp
$Comp
L C C?
U 1 1 4D0AB488
P 8500 4900
F 0 "C?" H 8550 5000 50  0000 L CNN
F 1 "47pF" H 8550 4800 50  0000 L CNN
	1    8500 4900
	1    0    0    -1  
$EndComp
$Comp
L +5V #PWR?
U 1 1 4D0AB471
P 8700 4300
F 0 "#PWR?" H 8700 4390 20  0001 C CNN
F 1 "+5V" H 8700 4390 30  0000 C CNN
	1    8700 4300
	1    0    0    -1  
$EndComp
$Comp
L USBA P?
U 1 1 4D0AB467
P 9350 4800
F 0 "P?" H 9350 4800 60  0000 C CNN
F 1 "USBA" H 9350 5300 60  0000 C CNN
	1    9350 4800
	1    0    0    -1  
$EndComp
$Comp
L +5V #PWR?
U 1 1 4D0AB430
P 7300 2350
F 0 "#PWR?" H 7300 2440 20  0001 C CNN
F 1 "+5V" H 7300 2440 30  0000 C CNN
	1    7300 2350
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR?
U 1 1 4D0AB42B
P 7900 2450
F 0 "#PWR?" H 7900 2450 30  0001 C CNN
F 1 "GND" H 7900 2380 30  0001 C CNN
	1    7900 2450
	1    0    0    -1  
$EndComp
NoConn ~ 7200 2450
NoConn ~ 8650 3700
NoConn ~ 8650 3600
Text GLabel 8750 3300 2    60   Output ~ 0
USB_TXE
Text GLabel 8750 3200 2    60   Output ~ 0
USB_RXF
Text GLabel 9850 3600 2    60   Input ~ 0
USB_WR
Text GLabel 8750 3400 2    60   Input ~ 0
USB_RD
Text GLabel 4050 3800 0    60   BiDi ~ 0
D7
Text GLabel 4050 3700 0    60   BiDi ~ 0
D6
Text GLabel 4050 3600 0    60   BiDi ~ 0
D5
Text GLabel 4050 3500 0    60   BiDi ~ 0
D4
Text GLabel 4050 3400 0    60   BiDi ~ 0
D3
Text GLabel 4050 3300 0    60   BiDi ~ 0
D2
Text GLabel 4050 3200 0    60   BiDi ~ 0
D1
Text GLabel 4050 3100 0    60   BiDi ~ 0
D0
Text GLabel 4050 4000 0    60   Input ~ 0
USB_RD
Text GLabel 2550 4300 0    60   Input ~ 0
USB_WR
Text GLabel 2550 4100 0    60   Input ~ 0
USB_RD
$Comp
L 74HC08 IC20
U 3 1 4D0AB2CC
P 3250 4200
F 0 "IC20" H 3250 4250 60  0000 C CNN
F 1 "74HC08" H 3250 4150 60  0000 C CNN
F 2 "110-3129" H 3250 4200 50  0001 C CNN
	3    3250 4200
	1    0    0    -1  
$EndComp
$Comp
L 74HC245 IC?
U 1 1 4D0AB2BE
P 4850 3600
F 0 "IC?" H 4950 4200 60  0000 L CNN
F 1 "74HC245" H 4950 3000 60  0000 L CNN
F 2 "108-5315" H 4850 3600 50  0001 C CNN
	1    4850 3600
	1    0    0    -1  
$EndComp
$Comp
L VDIP1 IC?
U 1 1 4D0AB2AD
P 7450 3450
F 0 "IC?" H 6800 4250 60  0000 C CNN
F 1 "VDIP1" H 6800 4350 60  0000 C CNN
F 2 "VDIP1" H 7450 3450 50  0001 C CNN
	1    7450 3450
	1    0    0    -1  
$EndComp
$EndSCHEMATC
