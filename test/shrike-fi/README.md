# GPIO Test Script for Shrike-Fi

This script is used to verify the functionality of GPIO pins connected to the ESP32-S3 and FPGA. 

## Setup & Execution
### Install Python3 Environment (Required) If Install then skip
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

### Cloning the Repository

Clone the repository using the following command:
```bash
git clone https://github.com/vicharak-in/shrike.git
```
Explanation:
This command downloads the project files from the remote Git repository to your local system.

### Nevigate the project directory 
``` bash
cd test/shrike-fi/
```
### Repository Contents

After cloning, ensure the following essential files and folder are present in the project directory and their functions.

 
``` bash
 flash_test.sh
```
Explanation:
- Flashes firmware to multiple Shrike-Fi (ESP32-S3) boards
- Performs LED blink test to verify GPIO functionality
- Reads .bin file and converts it to byte data
- read data from PC over UART.
- Supports FPGA flashing through ESP32-S3
- Handles multiple boards in a single run

 
``` bash
 test_firmware.bin
```
Explanation:
- Initializes the ESP32-S3 at startup


```bash
 bootloder.bin
```
Explanation:
- Initializes the ESP32-S3 at startup


```bash 
 partition-table.bin
```

Explanation:
- Defines memory layout (flash partitions)


```bash
 bin_streamer.py
```
Explanation:
- Reads .bin file data from the PC and sends it over serial (UART) to all active ports.

### Follow the below steps to run the script on a Linux system terminal:
1. Make the Script Executable
```bash
chmod +x flash_test.sh
```
Explanation:
The chmod +x command adds execute permission to the script file, allowing it to be run as a program.

2. Run the Script
```bash
./flash_test.sh
```

After the setup only run ``` ./flash_tesh.sh ``` command only to Run the script. 

3. If the Device, Port permission Denied then use only
```bash 
sudo usermod -aG dialout $USER
newgrp dialout
```
Then open new terminal it allow the permission. 

## After Run the Script successfully
Open serial_flash_tool folder and add FPGA .bin file in the folder then run Command

```bash
python3 bin_streamer.py blink_all.bin 
```
Wait until all .bin file (bytes) are fully send on UART; only after the entire transfer is complete FPGA flashing process begin.
