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
git clone <repository_url>
```
Explanation:
This command downloads the project files from the remote Git repository to your local system.

### Repository Contents

After cloning, ensure the following essential files and folder are present in the project directory:
```bash
flash_test.sh
test_firmware.bin
bootloder.bin
partition-table.bin
pc_script
```
### Nevigate the project directory 
``` bash
cd <repository_folder>
```
### Follow the below steps to run the script on a Linux system terminal:
1. Make the Script Executable
```bash
chmod +x <script_name>.sh
```
Example:
```bash
chmod +x flash_test.sh
```
Explanation:
The chmod +x command adds execute permission to the script file, allowing it to be run as a program.

2. Run the Script
```bash
./<script_name>.sh
```
Example:
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
Open pc_script folder 
and run Command

```bash 
python3 <File_name.py> <File_name.bin>
```
Example: 
```bash
python3 pc_serial.py FPGA_bitstream_MCU.bin 
```
Wait until all .bin file (bytes) are fully send on UART; only after the entire transfer is complete FPGA flashing process begin.
