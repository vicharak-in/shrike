.. _hardware_overview:

=====================================
Shrike FPGA - Hardware Overview
=====================================
Shrike is a low-cost, low-power, and easy-to-use FPGA development board that combines both the 
Renesas FPGA and the RP2350/RP2040 microcontroller. It is designed for hobbyists, students, and professionals to explore and prototype FPGA-based designs with ease. 

The board features a variety of peripherals to support various applications. Some of the key features include: 

Hardware Features :
####################

    - Renesas FPGA with 1120 5 Input LUT's
    - MCU - RP2350/RP2040
    - PMOD Connector 
    - Reset Button 
    - Boot Select Button 
    - USB Type C for Power & Programming 
    - MCU User LED 
    - FPGA User LED 
    - 23 MCU GPIO'
    - 14 FPGA GPIO's 
    - 6 Bit FPGA MCU Link 
    - Bread Board Compatible 


GPIO's 
################

The Shrike Packed with User IO's I have 23 MCU IO's and 14 FPGA IO's all of which are 3.3V compatible.

The Board also has Header for 3.3V and 5V Power Rails for powering external peripherals. 

PMOD Connector
################
The Shrike Board has a PMOD connector for connecting to various peripherals,the PMOD connector is 3.3 V Compatible

.. note:: All the pins on shrike are 3.3 V compatible supplying anything more than that will result in damage to IC's on  board which are beyond repair. 


Type C Port 
################
The Board has a USB type C connector for both programming and power.
Connect the board to a host PC using a type c cable and you are good to go.

User LED's
################

The board has two user LED's one for the RP2350/RP2040 and one for the FPGA. The LED's are connected to GPIO pins of the respective chips.
The RP2350/RP2040 LED is connected to GPIO 04 and the FPGA LED is connected to GPIO 16.

The LED's are active high meaning that when the GPIO pin is set to high the LED will turn on and when the GPIO pin is set to low the LED will turn off.

FLASH
######
The Shrike Dev Board features a 32Mb/4MB QSPI based Flash memory which is connected to RP2350/RP2040. The part number for which is W25Q32JV. This flash is used to store the fpga bitstream and RP2350/RP2040 firmware. 

Programming 
################


Both the IC on the board have separate programming models. The RP2040 
can be programmed using MicroPython, Arduino or Rpi's C SDK whereas the FPGA needed to be programmed using Verilog in the Renesas Go Configure hub.


Powering the Board
##################
The board can be powered using one of these two methods:
 1. The USB Type C port
 2. Header 1 marked 5V and any of the GND pins on the board.

 .. note:: The board can be powered using the USB Type C port or the header marked 5V. Do not power the board using both methods at the same time as this will damage the board.

The voltage on the Type C and header both should be 5V only. The board has a voltage regulator that converts the 5V to 3.3V for the RP2350/RP2040 and the FPGA.

The voltage on the PMOD connector is 3.3V.

