# GPIO and PSRAM Test Script for Shrike-Fi

This script is used to verify the functionality of the GPIO pins on the Shrike Fi, check PSRAM detection, and determine the available PSRAM size.

## Setup & Execution
### Install Python3 Environment and serial screen tool (Required). If both are already Install then skip.
1. Install Python3 and pip
```bash 
sudo apt update
sudo apt install python3 python3-pip python3-venv -y
```
2. Install pipx (Recommended for tools)
```bash 
sudo apt install pipx -y
pipx ensurepath
```
3. Install ESP Flash Tool
``` bash
pipx install esptool
```
4. Install Pyserial
``` bash 
pip3 install pyserial
```
5. Install screen tool
```bash 
sudo apt install screen  
```

### Cloning the Repository

Clone the repository using the following command:
```bash
git clone https://github.com/vicharak-in/shrike.git
```
Explanation:
This command downloads the project files from the remote Git repository to your local system.

### Nevigate the project directory 
``` bash
cd shrike/test/shrike-fi/
```
### Repository Contents

After cloning, ensure the following essential files and folder are present in the project directory and their functions.

1. ``` flash_test.sh ```
- Flashes firmware to multiple Shrike-Fi (ESP32-S3) boards
- Performs an LED blink test to verify GPIO functionality and checks whether PSRAM is connected to the board.
- Reads .bin file and converts it to byte data
- read data from PC over UART.
- Supports FPGA flashing through ESP32-S3
- Handles multiple boards in a single run

2. ``` test_firmware.bin ```
- Initializes the ESP32-S3 at startup

3. ``` bootloder.bin ```
- Initializes the ESP32-S3 at startup

4. ``` partition-table.bin```
- Defines memory layout (flash partitions)

5. ``` bin_streamer.py ```
- Reads .bin file data from the PC and sends it over serial (UART) to all active ports.

### Follow the below steps to run the script on a Linux system terminal:

1. Make the Script Executable
```bash
chmod +x flash_test.sh
```
Explanation:
The chmod +x command adds execute permission to the script file, allowing it to be run as a program.

2. Allow Port permissions 
```bash 
sudo usermod -aG dialout $USER
newgrp dialout
```

3. Run the Script
```bash
./flash_test.sh
```
"After the setup only run ``` ./flash_tesh.sh ``` command only to Run the script." 

**Important:**
Start serial logging only if ```PSRAM``` is connected.
4. To start the screen log 
```bash 
sudo screen /dev/ttyACM0 115200  
```
**Important:**
* In the above command, replace `/dev/ttyACM0` with the port of your connected device. 
* If multiple ports are connected, open a new terminal window for each port. 
* If no logs are displayed, press the **Reset** button on the Shrike-Fi board to restart the device. The logs will then be displayed from the beginning.

5. To exit the session, press `Ctrl + A`, then type `:quit`. Alternatively, you can disconnect the Shrike-Fi board's USB cable.


## After Run the Script successfully
Open serial_flash_tool folder using command ```cd serial_flash_tool``` and **python file** and **blink_all.bin** in the folder then run Command.

```bash
python3 bin_streamer.py blink_all.bin 
```
Wait until all .bin file (bytes) are fully send on UART; only after the entire transfer is complete FPGA flashing process begin.

**Check that the generated logs match the expected output shown in the Images folder.**

**This script can be used on boards with or without PSRAM.**
