# FPGA Smart Keyboard Autocorrector

A hybrid hardware-software spell correction system built on the **Vicharak Shrike-Lite FPGA platform**.

The system captures text input on a host PC, performs real-time spell correction using an RP2040 microcontroller, validates communication through an FPGA-based SPI processing pipeline, and automatically replaces misspelled words inside target applications.The spell corrector is based on the Peter Norvig's algorithm. 

---

## Features

* Real-time spell correction
* FPGA-assisted text processing pipeline
* RP2040 MicroPython firmware
* Host-side keyboard interception
* Automatic typo replacement
* Frequency-based candidate ranking
* Edit Distance 1 correction engine
* Works with words and complete sentences
* Compatible with Windows applications such as Notepad, Chrome, and Microsoft Word

---

## System Architecture

```text
User Typing
     │
     ▼
Host Keyboard Hook
     │
     ▼
Python HID Interface
     │
     ▼
RP2040 (MicroPython)
     │
     ├─ Candidate Generation
     ├─ Frequency Lookup
     └─ Spell Correction
     │
     ▼
SPI Interface
     │
     ▼
FPGA Echo Pipeline
     │
     ▼
RP2040 Verification
     │
     ▼
Automatic Text Replacement
```

---

## Hardware Requirements

| Component        | Description                 |
| ---------------- | --------------------------- |
| Shrike-Lite FPGA | FPGA Processing Unit        |
| RP2040 MCU       | MicroPython Runtime         |
| USB Cable        | Programming & Communication |
| Jumper Wires     | SPI Connections             |

---

## Board Compatibility

| Board                | Firmware    | Status     |
| -------------------- | ----------- | ---------- |
| Shrike-Lite (RP2040) | MicroPython | ✅ Tested   |
| Shrike (RP2350)      | MicroPython | ⬜ Untested |
| Shrike-Fi (ESP32-S3) | MicroPython | ⬜ Untested |

---

## SPI Connections

| Signal | RP2040 GPIO | FPGA Signal |
| ------ | ----------- | ----------- |
| MOSI   | GPIO 19     | spi_mosi    |
| MISO   | GPIO 16     | spi_miso    |
| SCK    | GPIO 18     | spi_sck     |
| CS     | GPIO 5      | spi_ss_n    |
| GND    | GND         | GND         |

---

## Quick Start

### 1. Program the FPGA

Compile and flash:

```text
top.v
spi_target.v
```

to the Shrike-Lite FPGA.

### 2. Copy Firmware

Copy the following files to the RP2040:

```text
code.py
top512.txt
```

### 3. Install Host Dependencies

```bash
pip install keyboard pyserial
```

### 4. Launch the Host Interface

```bash
python hid_interface.py
```

Run the terminal with Administrator privileges.

### 5. Start Typing

Example:

```text
teh wrod si graet
```

Automatically becomes:

```text
the word is great
```

---

## Build From Source

### FPGA

Add the following files to the Go Configure project:

```text
top.v
spi_target.v
```

Generate the FPGA bitstream and flash the device.

### RP2040 Firmware

Copy:

```text
code.py
top512.txt
```

to the root directory of the RP2040.

### Host Application

Install dependencies:

```bash
pip install keyboard pyserial
```

Run:

```bash
python hid_interface.py
```

---

## Spell Correction Algorithm

The RP2040 performs:

1. Exact dictionary lookup
2. Edit Distance 1 candidate generation
3. Frequency-based ranking
4. Candidate selection

Supported operations:

* Character insertion
* Character deletion
* Character replacement
* Adjacent character transposition

---

## FPGA Pipeline

The FPGA implements a lightweight SPI processing pipeline.

Functions:

* SPI Target Interface
* Clock Domain Synchronization
* Byte-Level Echo Processing
* Communication Verification

The FPGA validates data transmission between the host and MCU before text replacement occurs.

---

## Dictionary Constraints

The frequency dictionary is stored on the RP2040.

Current configuration:

| Parameter       | Value      |
| --------------- | ---------- |
| Dictionary Size | 512 Words  |
| Edit Distance   | 1          |
| Storage         | top512.txt |

---

## Example Corrections

### Single Words

| Input | Output |
| ----- | ------ |
| teh   | the    |
| wrod  | word   |
| naem  | name   |
| graet | great  |

### Sentences

Input:

```text
Hsi motehr ahd fatehr weer frenhc
```

Output:

```text
his mother and father were french
```

---

## Example Runtime Log

```text
[DEBUG] Intercepted : teh
[DEBUG] FPGA Echo   : the
[DEBUG] Processed   : the

[DEBUG] Intercepted : si
[DEBUG] FPGA Echo   : is
[DEBUG] Processed   : is

[DEBUG] Intercepted : wrod
[DEBUG] FPGA Echo   : word
[DEBUG] Processed   : word
```

---

## Limitations

### Memory Constraints

The RP2040 provides approximately 264 KB of SRAM.

To ensure stable operation:

* Dictionary limited to 512 words
* Frequency data stored in RAM
* Larger dictionaries may require external storage
* Language supported only English

### Algorithm Constraints

Current implementation supports:


* Edit Distance = 1 .This means only the words for example 'ahd','teh','wrod','siad' ..etc can be corrected. Words requiring multiple edits may not be corrected successfully.

* One word at a time. This means it is build for one word at a time only.

---

### Demo Video 

https://drive.google.com/file/d/1DCIpYfwh39nGkkCYZKiDOFOqq2Mgnk5v/view?usp=sharing



This is the google drive link of the video of working Spell Corrector with its proper flow showing how to generate the bitstream then how to upload the bitstream into the thonny and after that how to run the hid_interface.py script.


