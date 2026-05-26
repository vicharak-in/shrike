(hardware_overview)=

# Shrike - Hardware Overview

Shrike is a family low-cost, low-power, and easy-to-use FPGA development board that combines both the Renesas FPGA and microcontroller. It is designed for hobbyists, students, and professionals to explore and prototype FPGA-based designs with ease.

The board features a variety of peripherals to support various applications. Some of the key features include:


::::{tab-set}
:::{tab-item} Shrike/Shrike-lite

## Hardware Features

- Renesas FPGA with 1120 5 Input LUT's  
- MCU - RP2350/RP2040  
- PMOD Connector  
- Reset Button  
- Boot Select Button  
- USB Type C for Power & Programming  
- MCU User LED  
- FPGA User LED  
- 23 MCU GPIO  
- 14 FPGA GPIO's  
- 6 Bit FPGA MCU Link  
- Bread Board Compatible  

---

## GPIO's

The Shrike Packed with User IO's I have 23 MCU IO's and 14 FPGA IO's all of which are 3.3V compatible.

The Board also has Header for 3.3V and 5V Power Rails for powering external peripherals.

---

## PMOD Connector

The Shrike Board has a PMOD connector for connecting to various peripherals, the PMOD connector is 3.3 V Compatible

> **Note:** All the pins on shrike are 3.3 V compatible supplying anything more than that will result in damage to IC's on board which are beyond repair.

---

## Type C Port

The Board has a USB type C connector for both programming and power.  
Connect the board to a host PC using a type c cable and you are good to go.

---

## User LED's

The board has two user LED's one for the RP2350/RP2040 and one for the FPGA. The LED's are connected to GPIO pins of the respective chips.  
The RP2350/RP2040 LED is connected to GPIO 04 and the FPGA LED is connected to GPIO 16.

The LED's are active high meaning that when the GPIO pin is set to high the LED will turn on and when the GPIO pin is set to low the LED will turn off.

---

## FLASH

The Shrike Dev Board features a 32Mb/4MB QSPI based Flash memory which is connected to RP2350/RP2040. The part number for which is W25Q32JV. This flash is used to store the fpga bitstream and RP2350/RP2040 firmware.

---

## Programming

Both the IC on the board have separate programming models. The RP2040 can be programmed using MicroPython, Arduino or RPi's C SDK whereas the FPGA needs to be programmed using Verilog in the Renesas Go Configure hub.

---

## Powering the Board

The board can be powered using one of these two methods:

1. The USB Type C port  
2. Header 1 marked 5V and any of the GND pins on the board  

> **Note:** The board can be powered using the USB Type C port or the header marked 5V. Do not power the board using both methods at the same time as this will damage the board.

The voltage on the Type C and header both should be 5V only. The board has a voltage regulator that converts the 5V to 3.3V for the RP2350/RP2040 and the FPGA.

The voltage on the PMOD connector is 3.3V.



:::


:::{tab-item} Shrike-fi



## Hardware Features

- Renesas FPGA with 1120 5 Input LUT's  
- MCU - ESP32S3  
- PMOD Connector  
- Reset Button  
- Boot Select Button  
- USB Type C for Power & Programming  
- MCU User LED  
- FPGA User LED  
- 24 MCU GPIO  
- 14 FPGA GPIO's  
- 4 Bit FPGA MCU Link  
- Bread Board Compatible  

---

## GPIO's

The Shrike-fi Packed with User IO's I have 24 MCU IO's and 14 FPGA IO's all of which are 3.3V compatible.

The Board also has Header for 3.3V and 5V Power Rails for powering external peripherals.

---

## PMOD Connector

The Shrike-fi Board has a PMOD connector for connecting to various peripherals, the PMOD connector is 3.3 V Compatible

> **Note:** All the pins on Shrike-fi are 3.3 V compatible supplying anything more than that will result in damage to IC's on board which are beyond repair.

---

## Type C Port

The Board has two USB type C connector for programming and power.  
Connect the board to a host PC using a type c cable and you are good to go.

---

## User LED's

The board has two user LED's one for the ESP32S3 and one for the FPGA. The LED's are connected to GPIO pins of the respective chips.  
The ESP32S3 LED is connected to GPIO 21 and the FPGA LED is connected to GPIO 16.

The LED's are active high meaning that when the GPIO pin is set to high the LED will turn on and when the GPIO pin is set to low the LED will turn off.

---

## WiFi and BLE

The Shrike-fi dev board with ESP32S3 supports 2.4 GHz, 802.11 b/g/n Wi-Fi 4 and Bluetooth 5 (LE).
These are on-chip features of ESP32S3.

## FLASH

The Shrike Dev Board features a 32Mb/4MB QSPI based Flash memory which is connected to ESP32S3. The part number for which is W25Q32JV. This flash is used to store the fpga bitstream and firmware.

The board also has optional 8MB PSRAM in the ESP32S3.

---

##  Optional Add-On

The Shrike-fi Dev also has two optional add on's hardware features. 

### 1. PSRAM

Shrike-fi can be equipped with an optional 8 MB PSRAM. Depending on the variant purchased, the PSRAM may come pre-soldered or left unpopulated. If you choose to buy without it soldered, you can add it later. The part number is **LY68L6400SLIT**, and the designator is **U10**.


### 2. Batter Management System  

Shrike-fi features an onboard battery management and charging circuit. However, in the base version, these parts are designated as do not place (DNP). A future version with these components pre-soldered will be available soon.

In the meantime, we are providing the necessary details for all the parts if you wish to solder them yourself. 

The complete BOM for the BMS and charging circuit is available in the table below. 


| Designator        | Description                                                                 | Value     | Manufacturer Part Number | Case/Package | Quantity | Type       |
|------------------|-----------------------------------------------------------------------------|-----------|--------------------------|--------------|----------|------------|
| C9               | 100nF, 10V, X7R, ±10%, 0402, MLCC | 100nF     | CC0402KRX7R6BB104           |0402         | 1        | Capacitor  |
| C10, C11, C12    | 10uF, 10V, X5R, ±10%, 0603, MLCC | 10uF      | CL10A106KP8NNNC          | 0603         | 3        | Capacitor  |
| D9               | LED ORANGE 0603                                                             | ORANGE LED| XL-1608UOC-06            |0603         | 1        | LED        |
| D10              | GREEN LED (LED)                       | GREEN LED | XL-1608UGC-04    |0603         | 1        | LED        |
| J3               | 2P 1x2P 2.5mm 2.2A 1 Right Angle Through Hole ,P=2.5mm Headers| — | XY-XHB2.54-2A21        |  TH, P=2.5mm |  1        | Connector  |
| R5               | Resistor - 100 ohm, 1%, 0402                                                | 100R      | RC0402FR-07100RL           |0402         | 1        | Resistor   |
| R6, R7, R11, R12 | Resistor - 1 kohm, 1%, 0402                                                 | 1K        | RC0402FR-071KL           |0402         | 4        | Resistor   |
| R8               | 402Ohm, ±1%, 62.5mW, 0402, Chip Resistor                                    | 402R      | 0402WGF4020TCE           |0402         | 1        | Resistor   |
| R9               | Resistor - 0 ohm, 1%, 0402                                                  | 0R        | RC0402FR-070RL             |0402         | 1        | Resistor   |
| R10              | 0Ohm,125mW, ±1%, 0805, Resistor                                             | 0R        | 0805W8F0000T5E           | 0805         | 1        | Resistor   |
| U2               | Lithium Battery protection IC, SOT23-6 (4911) (DW01A) (C436931)             | DW01A     | DW01A                    |SOT23-6      | 1        | IC         |
| U3               | POWER SWITCH IC [TPS2113ADRBR] (C354512)                                    | —         | TPS2113ADRBR             | VSON-8       | 1        | IC         |
| U4               | Lithium Battery Charger, 1A, 5V, (3656) [TP4056] (SOP8)                     | —         | TP4056                   | SOP8         | 1        | IC         |
| U5               | Dual N-Channel -20V 6A 1V @ 250uA [FS8205A]                                 | —         | FS8205A                  | TSSOP-8      | 1        | IC         |



---

#### Part Designators 

The complete out and pcb file's aren't open for Shrike-fi yet they will be open mid june. However to solder the above mentionded parts you can use this part Designators file available [here](./images/Shrike_fi_designator.pdf).

---

> **Note:** Both of these add-ons are not placed in the base version of Shrike-fi. We will launch a board with these components pre-soldered soon. In the meantime, you can solder them yourself if you want these features.

---



## Programming

Both the IC on the board have separate programming models. The ESP32S3 can be programmed using MicroPython, Arduino or ESP-SDK whereas the FPGA needs to be programmed using Verilog in the Renesas Go Configure hub.


---

## Powering the Board

The board can be powered using one of these two methods:

1. The USB Type C port  
2. Header 1 marked 5V and any of the GND pins on the board  

> **Note:** The board can be powered using the USB Type C port or the header marked 5V. Do not power the board using both methods at the same time as this will damage the board.

The voltage on the Type C and header both should be 5V only. The board has a voltage regulator that converts the 5V to 3.3V for the ESP32S3 and the FPGA.

The voltage on the PMOD connector is 3.3V.

:::
::::


