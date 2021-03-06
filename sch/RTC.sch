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
Sheet 8 13
Title ""
Date "6 mar 2011"
Rev ""
Comp ""
Comment1 ""
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
Wire Wire Line
	4700 2700 4600 2700
Wire Wire Line
	4600 2700 4600 2850
Wire Wire Line
	4600 2850 5250 2850
Wire Wire Line
	5150 3050 5250 3050
Wire Wire Line
	7200 3100 7200 3050
Wire Wire Line
	7200 3050 6550 3050
Connection ~ 6650 2650
Wire Wire Line
	6650 1750 6650 2850
Wire Wire Line
	6650 2850 6550 2850
Wire Wire Line
	6550 3250 6650 3250
Wire Wire Line
	5250 3950 5150 3950
Wire Wire Line
	5150 4100 6900 4100
Wire Wire Line
	6900 4100 6900 3450
Wire Wire Line
	5150 3650 5250 3650
Wire Wire Line
	6550 3950 6650 3950
Wire Wire Line
	6550 3850 6650 3850
Wire Wire Line
	6550 3750 6650 3750
Wire Wire Line
	6550 3650 6650 3650
Wire Wire Line
	6550 3550 6650 3550
Wire Wire Line
	6850 1950 6850 1850
Connection ~ 6650 1850
Wire Wire Line
	6850 1850 6650 1850
Wire Wire Line
	6650 2650 6550 2650
Wire Wire Line
	6850 2450 6850 2350
Wire Wire Line
	5250 3850 5150 3850
Wire Wire Line
	5250 3750 5150 3750
Wire Wire Line
	5150 3950 5150 4200
Connection ~ 5150 4100
Wire Wire Line
	6550 3350 6650 3350
Wire Wire Line
	6550 2750 6750 2750
Wire Wire Line
	7200 3400 7200 3450
Wire Wire Line
	7200 3450 6550 3450
Connection ~ 6900 3450
Wire Wire Line
	5150 3250 5250 3250
Wire Wire Line
	5150 3350 5250 3350
Wire Wire Line
	5150 3450 5250 3450
Wire Wire Line
	5150 3550 5250 3550
Wire Wire Line
	5000 2700 5100 2700
Wire Wire Line
	5100 2700 5100 2750
Wire Wire Line
	5100 2750 5250 2750
$Comp
L CRYSTAL X?
U 1 1 4D09047E
P 4850 2700
F 0 "X?" H 4850 2850 60  0000 C CNN
F 1 "32.768kHz" H 4850 2500 60  0000 C CNN
	1    4850 2700
	1    0    0    -1  
$EndComp
Text GLabel 5150 3050 0    60   Output ~ 0
CLK_INT
NoConn ~ 5250 2650
NoConn ~ 5250 2950
NoConn ~ 5250 3150
Text GLabel 5150 3250 0    60   Input ~ 0
A3
Text GLabel 5150 3350 0    60   Input ~ 0
A2
Text GLabel 5150 3450 0    60   Input ~ 0
A1
Text GLabel 5150 3550 0    60   Input ~ 0
A0
$Comp
L CELL B?
U 1 1 4D09036A
P 7200 3250
F 0 "B?" H 7350 3450 60  0000 C CNN
F 1 "CR2032" H 7000 3400 60  0000 C CNN
	1    7200 3250
	1    0    0    -1  
$EndComp
Text GLabel 6750 2750 2    60   Input ~ 0
WR
NoConn ~ 6550 2950
NoConn ~ 6550 3150
Text GLabel 6650 3250 2    60   Input ~ 0
RD
Text GLabel 6650 3350 2    60   Input ~ 0
CLK_CS
$Comp
L GND #PWR?
U 1 1 4D090279
P 5150 4200
F 0 "#PWR?" H 5150 4200 30  0001 C CNN
F 1 "GND" H 5150 4130 30  0001 C CNN
	1    5150 4200
	1    0    0    -1  
$EndComp
Text GLabel 6650 3550 2    60   BiDi ~ 0
D7
Text GLabel 6650 3650 2    60   BiDi ~ 0
D6
Text GLabel 6650 3750 2    60   BiDi ~ 0
D5
Text GLabel 6650 3850 2    60   BiDi ~ 0
D4
Text GLabel 6650 3950 2    60   BiDi ~ 0
D3
Text GLabel 5150 3850 0    60   BiDi ~ 0
D2
Text GLabel 5150 3750 0    60   BiDi ~ 0
D1
Text GLabel 5150 3650 0    60   BiDi ~ 0
D0
$Comp
L +5V #PWR?
U 1 1 4D09021A
P 6650 1750
F 0 "#PWR?" H 6650 1840 20  0001 C CNN
F 1 "+5V" H 6650 1840 30  0000 C CNN
	1    6650 1750
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR?
U 1 1 4D090209
P 6850 2450
F 0 "#PWR?" H 6850 2450 30  0001 C CNN
F 1 "GND" H 6850 2380 30  0001 C CNN
	1    6850 2450
	1    0    0    -1  
$EndComp
$Comp
L C C?
U 1 1 4D090200
P 6850 2150
F 0 "C?" H 6900 2250 50  0000 L CNN
F 1 "0.1uF" H 6900 2050 50  0000 L CNN
	1    6850 2150
	1    0    0    -1  
$EndComp
$Comp
L BQ4845 IC?
U 1 1 4D0901E1
P 5900 3300
F 0 "IC?" H 5650 4050 60  0000 C CNN
F 1 "BQ4845" H 6050 2550 60  0000 C CNN
	1    5900 3300
	1    0    0    -1  
$EndComp
$EndSCHEMATC
