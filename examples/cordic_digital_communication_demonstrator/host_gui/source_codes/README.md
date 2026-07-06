## Host GUI Source Files

The Python Host GUI provides the user interface, communication layer, visualization tools, and educational demonstrations for the FPGA-Based CORDIC Digital Communication Demonstrator.

Unlike the FPGA, the GUI does **not** compute trigonometric functions during transmission. Instead, it prepares input data, communicates with the RP2040, receives hardware-generated SIN/COS/TAN values from the FPGA, and visualizes the complete digital communication process in real time.

---

### main.py

**Purpose**

Application entry point.

**Responsibilities**

- Creates the PyQt6 application.
- Loads the global stylesheet.
- Instantiates the main application window.
- Starts the GUI event loop.

---

### main_window.py

**Purpose**

Main dashboard of the demonstrator.

**Responsibilities**

- Builds the complete graphical interface.
- Connects all GUI components.
- Handles user interaction.
- Manages transmission workflow.
- Controls BPSK and QPSK modes.
- Displays FPGA-generated results.
- Coordinates waveform, constellation, backend processing, calculator, and serial monitor windows.
- Imports and integrates all supporting modules into a single application.

---

### serial_manager.py

**Purpose**

Low-level serial communication layer.

**Responsibilities**

- Opens and closes the USB serial port.
- Implements the ASCII line-based communication protocol.
- Sends commands to the RP2040.
- Receives responses asynchronously.
- Buffers incoming serial data.
- Detects communication errors and connection loss.
- Maintains transmission history for debugging.

---

### fpga_manager.py

**Purpose**

High-level FPGA communication controller.

**Responsibilities**

- Implements the communication state machine.
- Performs startup handshake.
- Manages command sequencing.
- Sends modulation and angle requests.
- Receives hardware-generated SIN, COS, and TAN values.
- Synchronizes GUI updates with FPGA responses.
- Coordinates complete transmission sessions.

---

### dcd.py

**Purpose**

RP2040 firmware implementing the GUI communication protocol.

**Responsibilities**

- Runs on the RP2040 using MicroPython.
- Initializes the SPI interface.
- Receives ASCII commands from the GUI.
- Converts modulation symbols into phase angles.
- Sends phase angles to the FPGA.
- Reads hardware-generated SIN, COS, and TAN values.
- Returns formatted responses to the GUI.
- Bridges USB Serial and SPI communication.

---

### modulation.py

**Purpose**

Digital modulation preprocessing.

**Responsibilities**

- Converts ASCII text into binary.
- Parses binary input.
- Generates random bit streams.
- Groups bits into symbols.
- Performs Gray coding.
- Maps symbols to modulation phases.
- Computes expected constellation locations.
- Supplies visualization data for waveform and constellation displays.

---

### waveform.py

**Purpose**

Waveform visualization engine.

**Responsibilities**

- Generates interactive waveform plots.
- Displays baseband bit streams.
- Displays carrier waveforms.
- Displays BPSK and QPSK modulated signals.
- Supports zooming, panning, hovering, and waveform inspection.
- Highlights symbol boundaries and phase transitions.

---

### constellation.py

**Purpose**

I/Q constellation visualization.

**Responsibilities**

- Displays real-time constellation points.
- Draws ideal constellation reference locations.
- Displays symbol history.
- Supports interactive zooming and panning.
- Shows I/Q coordinates and symbol information.
- Visualizes FPGA-generated modulation results.

---

### backend_visualizer.py

**Purpose**

Educational FPGA processing visualization.

**Responsibilities**

Visualizes the complete hardware processing pipeline executed inside the FPGA.

Displays

- Input Data
- ASCII Encoding
- Binary Conversion
- Serial Bit Stream
- Symbol Grouping
- Gray Mapping
- Phase Selection
- CORDIC Input Angle
- Quadrant Reduction
- CORDIC Rotation Engine
- SIN Register
- COS Register
- Linear Divider
- TAN Register
- I/Q Components
- RF Waveform Generation

This window represents the actual FPGA processing stages and updates live during transmission.

---

### cordic_calculator.py

**Purpose**

Interactive hardware CORDIC calculator.

**Responsibilities**

- Accepts degree or radian inputs.
- Sends arbitrary angles to the FPGA.
- Receives hardware-generated SIN, COS, and TAN values.
- Displays software reference values for comparison.
- Maintains calculation history.
- Supports exporting results.

---

### serial_monitor.py

**Purpose**

Serial protocol analyzer.

**Responsibilities**

- Displays every transmitted command.
- Displays every received response.
- Annotates protocol messages.
- Shows timestamps.
- Maintains communication history.
- Exports communication logs.
- Assists with debugging and protocol verification.

---

### plot_window.py

**Purpose**

Expanded visualization window.

**Responsibilities**

- Displays enlarged waveform plots.
- Displays enlarged constellation diagrams.
- Supports exporting plots as PNG.
- Supports exporting numerical data as CSV.
- Provides additional interactive analysis tools.

---

### firmware_updater.py

**Purpose**

Automatic firmware deployment utility.

**Responsibilities**

- Uploads RP2040 firmware.
- Replaces main.py on the board.
- Reboots the RP2040.
- Automates firmware updates using mpremote.

---

### port_scanner.py

**Purpose**

Serial device discovery.

**Responsibilities**

- Detects available serial ports.
- Retrieves device descriptions.
- Supplies available COM ports to the GUI.

---

### styles.py

**Purpose**

Application styling engine.

**Responsibilities**

- Defines the global dark theme.
- Configures PyQt6 stylesheets.
- Configures Matplotlib plotting styles.
- Maintains consistent visual appearance across all windows.

---

### test_connection.py

**Purpose**

Hardware verification utility.

**Responsibilities**

- Opens the serial connection.
- Reboots the RP2040.
- Sends test commands.
- Verifies communication.
- Confirms successful board initialization.

---

## Overall Software Architecture

The Python Host GUI is organized into four major subsystems.

### User Interface Layer

- main.py
- main_window.py
- styles.py

Provides the complete graphical interface and user interaction.

---

### Communication Layer

- serial_manager.py
- fpga_manager.py
- dcd.py
- firmware_updater.py
- port_scanner.py

Implements reliable communication between the GUI, RP2040, and ForgeFPGA.

---

### Signal Processing Layer

- modulation.py

Performs data preparation and symbol mapping before hardware processing.

---

### Visualization Layer

- waveform.py
- constellation.py
- backend_visualizer.py
- cordic_calculator.py
- plot_window.py
- serial_monitor.py

Displays hardware-generated results through interactive engineering visualizations and educational processing views.

---

The software architecture follows a modular design, separating user interaction, communication, preprocessing, visualization, and hardware control into independent components. This organization improves maintainability, scalability, and allows each module to be developed and tested independently while providing a unified interface for interacting with the FPGA-based CORDIC digital communication system.
