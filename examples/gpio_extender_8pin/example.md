# Controlling FPGA Pins with RP2040

To help you understand how the **RP2040** controls the **FPGA** pins, let's walk through a concrete example: **Making an LED connected to FPGA Pin 20 (GPIO Bit 0) blink.**

---

## 1. The Setup

* **Target Pin:** FPGA Pin 20 (Logic Label: `GPIO07`).
* **Logic Index:** This corresponds to **Bit 0** of our 8-bit GPIO bus.
* **Direction:** We need this pin to be an **Output** to drive the LED.
* **State:** We want to toggle it between **High (3.3V)** and **Low (0V)**.

---

## Step 1: Setting the Direction (Input Packet 1)

To make Bit 0 an output, we need to talk to the **Direction Register**. In our Verilog code, the opcode for the lower nibble (Bits 0-3) of the direction register is `0x1`.

* **Direction Logic:** `0` = Output, `1` = Input.
* **Command:** We want Bit 0 to be `0` (Output) and we'll leave the others as `1` (Input) for safety.
* **Data Nibble:** `1110` in binary, which is `0xE` in hex.
* **Full SPI Packet:** `0x1E` (Opcode 1 + Data E).

> **What the FPGA does:** It receives `0x1E`, sees the `0x1` prefix, and writes `1110` into the lower 4 bits of `gpio_io_dir`. Because Bit 0 is now `0`, the FPGA hardware internally sets the **Output Enable (OE)** for Pin 20 to **High**.

---

## Step 2: Driving the Pin High (Input Packet 2)

Now that the pin is an output, we need to send the data. The opcode for the lower nibble of the **Output Data Register** is `0x3`.

* **Logic:** `1` = High (3.3V), `0` = Low (0V).
* **Data Nibble:** We want Bit 0 to be `1`. Binary `0001`, which is `0x1` in hex.
* **Full SPI Packet:** `0x31` (Opcode 3 + Data 1).

> **What the FPGA does:** It receives `0x31`, sees the `0x3` prefix, and writes `0001` into the lower bits of `gpio_o_data_reg`. Since OE is already High from Step 1, Pin 20 immediately jumps to **3.3V**, and the LED turns on.

---

## Step 3: The Simultaneous Feedback (Output Packet)

Every time you sent those commands above, the FPGA sent a byte back to the RP2040 at the **exact same time**.

* **FPGA Action:** The FPGA looks at the physical voltage on all 8 pins and puts those values into a shift register.
* **Result:** If Pin 20 successfully went High, the RP2040 will receive a byte where the last bit is `1` (e.g., `0b00000001`). This confirms to your Python script that the pin actually changed state.
