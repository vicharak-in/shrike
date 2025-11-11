# Basic Logic Gates

This example project demonstrates basic **logic gate implementations** on the **Shrike-Lite**, perfect for beginners exploring digital logic and FPGA programming.

---

## Folder Structure

Each logic gate (AND, OR, NOT, NAND, NOR, XOR) is organized as a separate subfolder under this project:

```
logic_gates
├── and
├── or
├── not
├── nand
├── nor
└── xor
```

Inside each folder, you’ll find:

```
and
├── and.ffpga
└── ffpga
    └── src
        └── main.v
```

The **Verilog code** for the gate is located in `ffpga/src/main.v`.

---

## Hardware Setup

The project uses two **interconnects** between the **RP2040 MCU** and the **FPGA** on the Shrike-Lite board:

| RP2040 GPIO | FPGA Pin |
| ----------- | -------- |
| 14          | 18       |
| 15          | 17       |

And also uses the already available led on the board which is connected to **FPGA** on `FPGA_IO16`
These are used as input signals for the logic gates.
See PINOUTS [here](https://vicharak-in.github.io/shrike-lite/shrike_pinouts.html)

---

## Example: AND Gate

**Verilog source:** `and/ffpga/src/main.v`

```verilog
(* top *) module and_gate(
  (* iopad_external_pin *) output LED,
  (* iopad_external_pin *) output LED_en,
  (* iopad_external_pin *) input a,
  (* iopad_external_pin *) input b
);
  
  assign LED_en = 1'b1;
  assign LED = a & b;
endmodule
```

---

##  Building the Project

### 1. Open in Go-Configure

Open the project folder in **Go-Configure** (as explained in the official documentation [here](https://vicharak-in.github.io/shrike-lite/index.html)).

> Tip: To open an existing project, check the **bottom-right** corner of the Go-Configure Hub after launching.

### 2. Verify Pin Connections

Inside Go-Configure, use the **I/O Planner** to make sure your Verilog pins (`a`, `b`, `LED`, etc.) are mapped correctly to the **actual GPIOs** used on the RP2040-FPGA interconnect.

### 3. Generate the Bitstream

Hit **Generate Bitstream** at the bottom-left corner of Go-Configure.
Once the synthesis completes, a `build` directory will appear under your gate folder.

Example build output:

```
and
├── and.ffpga
└── ffpga
    ├── build
    │   ├── bitstream
    │   │   ├── FPGA_bitstream_FLASH_MEM.bin
    │   │   ├── FPGA_bitstream_MCU.bin
    │   │   └── ...
    │   ├── FPGA_bitstream.log
    │   ├── post_synth_report.txt
    │   ├── resource-utilization-report.log
    │   └── ...
    └── src
        └── main.v
```

Your **final bitstream** file will be:

```
and/ffpga/build/FPGA_bitstream_MCU.bin
```

---

## Flashing & Testing

Follow the flashing instructions from the Shrike-Lite documentation [here](https://vicharak-in.github.io/shrike-lite/getting_started.html) to upload the generated `.bin` file to your FPGA.

> Tip: For faster way to access your shrike according to me you maybe interested in CLI based flashing and running micropython, [here is the guide for the same](https://vicharak-in.github.io/shrike-lite/shrike_cli_guide.html)

Then, on the RP2040 side, toggle the input GPIOs via **MicroPython**:

**Both inputs HIGH:**

```python
import machine
a = machine.Pin(15, machine.Pin.OUT)
b = machine.Pin(14, machine.Pin.OUT)
a.value(1)
b.value(1)
```

**Both inputs LOW:**

```python
import machine
a = machine.Pin(15, machine.Pin.OUT)
b = machine.Pin(14, machine.Pin.OUT)
a.value(0)
b.value(0)
```

The **LED output** on the FPGA will light up according to your logic gate behavior — in this case, only when both `a` and `b` are high.

---

## Available Gates

| Gate | Folder  | Description           |
| ---- | ------- | --------------------- |
| AND  | `and/`  | Logical AND operation |
| OR   | `or/`   | Logical OR operation  |
| NOT  | `not/`  | Logical inversion     |
| NAND | `nand/` | Inverted AND          |
| NOR  | `nor/`  | Inverted OR           |
| XOR  | `xor/`  | Exclusive OR          |
