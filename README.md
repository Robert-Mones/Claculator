# Claculator
A reverse Polish notation calculator with added features such as comparisons, branching, and custom recursive operators taken from the Clac project from the 15-122 course at Carnegie Mellon University. The project is built around a 65C02 microprocessor with a custom architecture to reduce CPU load by making memory-mapped peripherals operate asynchronously. All logic and board design was done in KiCAD. All 3D modeling was done in Autodesk Fusion.

## Display
The seven-segment display board supports nine numerical displays, each with eight digits. It contains an SRAM chip which interfaces to the rest of the computer as a memory-mapped peripheral. When selected, the address and data bus is connected to the computer to be written to (but not read from) transparently. When the memory is not selected, a counter with a selectable clock source loops through each of the seventy-two digits, reads the corresponding byte from memory, and drives the corresponding digit using one bit for each segement (seven for the numerical part, one for the decimal point) with an array of P- and N-channel MOSFETs.

## Keypad
The keypad input board supports up to sixteen rows, each with eight buttons. It detects rising and falling edges of each button (equivalent to KeyDown and KeyUp events) with hardware RC debouncing and writes this information to a hardware FIFO buffer which is interfaced directly to the address and data bus of the system and can be configured to send an interrupt on new information in the buffer. This part is still being designed with the schematic and logic design nearly complete.

## Code
Once the hardware design is complete, I will start with a 32-bit integer mode to develop the RPN behavior and a feature-complete Clac implementation. After this, I will write a software 32-bit floating point implementation to support decimal arithmetic and comparisons. All of the code for this project will be written in 65C02 assembly.
