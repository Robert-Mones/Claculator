# Claculator
A reverse Polish notation calculator with added features such as comparisons, branching, and custom recursive operators taken from the Clac project from the 15-122 course at Carnegie Mellon University. The project is built around a 65C02 microprocessor with a custom architecture to reduce CPU load by making memory-mapped peripherals operate asynchronously. All logic and board design was done in KiCAD. All 3D modeling was done in Autodesk Fusion.

## Display
The seven-segment display board supports nine numeric displays, each with eight digits. It contains an SRAM chip which interfaces to the rest of the computer as a memory-mapped peripheral. When selected, the address and data bus is connected to the computer to be written to (but not read from) transparently. When the memory is not selected, a counter with a selectable clock source loops through each of the seventy-two digits, reads the corresponding byte from memory, and drives the corresponding digit using one bit for each segement (seven for the numeric part, one for the decimal point) with an array of P- and N-channel MOSFETs.

<p align="center">The front of the display, showing eight numeric displays</p>

![The front of the display, showing eight numeric displays](https://raw.githubusercontent.com/Robert-Mones/Claculator/main/Images/Display_Front.jpg)

<p align="center">The back of the display, showing the logic and driver chips</p>

![The back of the display, showing the logic and driver chips](https://raw.githubusercontent.com/Robert-Mones/Claculator/main/Images/Display_Back.jpg)

## Keypad
The keypad input board supports up to sixteen rows (5 are implemented), each with eight buttons. It detects rising edges of each button (equivalent to KeyDown events) with hardware RC debouncing and writes this information to a hardware FIFO buffer which is interfaced directly to the address and data bus of the system and can be configured to send an interrupt on new information in the buffer. It also has a header and location for a seven-segment display (not populated in these photos) as the ninth display that is driven from the display board.

<p align="center">The front of the keypad, showing five groups of eight keys</p>

![The front of the keypad, showing five groups of eight keys](https://raw.githubusercontent.com/Robert-Mones/Claculator/main/Images/Keypad_Front.jpg)

<p align="center">The back of the keypad, showing the logic chips and hot-swappable key sockets</p>

![The back of the keypad, showing the logic chips and hot-swappable key sockets](https://raw.githubusercontent.com/Robert-Mones/Claculator/main/Images/Keypad_Back.jpg)

## Chassis
I have placed an order from SendCutSend to have a chassis built for the Claculator out of 1/8"-thick 304 stainless steel (except for the keypad plate which must be 0.06" thick to fit the keys). It has hinges at the top back to open the Claculator from the front to enable demonstrations and debugging more easily. It will be very heavy and was very expensive but it's for the bit.

<p align="center">Model of the assembled Claculator</p>

![Model of the assembled Claculator](https://raw.githubusercontent.com/Robert-Mones/Claculator/main/Images/Assembly_Closed.png)

## Code
I am currently working on some tests building up to a 32-bit integer mode to develop the RPN behavior and a feature-complete Clac implementation. After this, I will write a software 32-bit floating point implementation to support decimal arithmetic and comparisons. All of the code for this project will be written in 65C02 assembly.
