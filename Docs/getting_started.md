(getting_started)=

# Getting Started

In this getting started guide we will see how to blink an led on shrike both on fpga and RP2040.

You can program the microcontroller on Shrike-lite using two methods:<br>
&emsp;**1. Arduino (C/C++)**  
&emsp;**2. MicroPython using the UF2 bootloader**

Both are beginner-friendly, and you can switch between them anytime.  
Let’s follow the steps and get Shrike-lite up and running!

::::{tab-set}
:::{tab-item} ArduinoIDE

# Using it with ArduinoIDE

If you already know Arduino and love working with the Arduino IDE, you can continue using it with Shrike-lite. You do not have to switch to MicroPython unless you want to., 


We will follow these steps to setup our arduino IDE for shrike. If you don't have arduino IDE already ,you can download it from [here](https://www.arduino.cc/en/software/) or if you are using linux(ubuntu)then just run 
```
sudo apt install arduino
```

### Step 1. Adding the board support for RP2040/RP2350

The Shrike has a on board RP2040/RP2350 has a host controller the Arduino IDE doesn't native support them however we can add the board support for the same. 
It is quit straight forward we need to add this URL 
```
https://github.com/earlephilhower/arduino-pico/releases/download/global/package_rp2040_index.json
``` 
in the addition board URL section of arduino IDE which you can find in File->Preferences.

<div align="center">

 <img src="./images/shrike_arduino/board_URL.png" alt="ADD BOARD URL" width="90%">

</div>

If you already have another board URL just add a "," between the two URL's.

These board support had been created by [earlephilhower](https://github.com/earlephilhower) and you can check out github [repository](https://github.com/earlephilhower/arduino-pico) for more details.

After adding the URL go to Tools->Boards->Board Manager in the Arduino IDE. 
Then search for pico and the board from Earle F. Philhower. 

<div align="center">

 <img src="./images/shrike_arduino/board_manager.png" alt="ADD BOARD" width="90%">

</div>
Perfect we have successfully add the board support for the RP2040/RP2350.

As we discussed earlier, in shrike-lite the micro-controller (RP2040) is responsible for configuring the FPGA.  

To make this possible, we developed a simple mechanism: we store the FPGA bitstreams in the RP2040’s flash memory and retrieve them whenever we need to configure the FPGA.

### Step 2. Adding the LittleFS Tool

The LittleFS library in Arduino allows you to store, load, and update the bitstream in the flash memory through the microcontroller (RP2040).

We need to add a Little-FS utility to bind a bin file (FPGA bitstream with code for Shrike). We can find the utility [here](https://github.com/earlephilhower/arduino-pico-littlefs-plugin/releases/) download the latest release ZIP. 

We will unzip and copy it to the tools directory in Arduino directory.

In case of windows you will find the Arduino folder in C disk if you have not changed it during installation.
In case of linux it would be available in your home directory. 

The directory/ folder  should look like this `<home_dir>/Arduino/tools/PicoLittleFS/tool/picolittlefs.jar`

You will need to restart the Arduino IDE and you should see the Pico Little FS tool like this in your Tools menu.

For more details on the PicoLittleFS tool checkout this [repository](https://github.com/earlephilhower/arduino-pico-littlefs-plugin).

> [!NOTE]
> For Arduino IDE version 2.x.x please follow [this](https://randomnerdtutorials.com/arduino-ide-2-install-esp32-littlefs/) guide instead of step 2 to setup the Little FS tools and you can come back for step 3. 
> Littlefs tool for Arduino IDE 2 can be found [here](https://github.com/earlephilhower/arduino-littlefs-upload).

### Step 3. Installing the Shrike Library 

The Arduino library developed by Vicharak takes care of configuring the FPGA for you. You can install it directly from the Arduino IDE’s Library Manager, just search for **“Shrike”** and install the **Shrike** library.


<div align="center">

 <img src="./images/shrike_arduino/shrike_lib.png" alt="ADD SHRIKE lib" width="90%">

</div>

Choose the first one names as Shrike and not the shrike flash library.
We are almost done with the setup lets continue and blink en led on FPGA using the arduino IDE. 

### Step 4. Programming the FPGA from ArduinoIDE
Lets program out first bitstream to fpga using the arduino. We will be blinking an led.

StartArduino IDE and look for Shrike >- shrike_flash in the example section of IDE and then save it with a name of you choice and at a location of your choice. This will create a folder with the name, now in the folder/dir create a subfolder by name `data` keep the case and in mind. 

Any bitstream that needs to be uploaded to the board should be placed in the folder. 
We have already generated and hosted a bitstream to blink led [here](https://github.com/vicharak-in/shrike-lite/blob/main/test/bitstreams/v1_4/led_blink.bin) save this bitstream to the data subfolder.

Checkout guide to learn how to generate your own fpga design [here](./generating_your_first_bitstream.md).

Onces you have done this go to arduino and hit compile your compilation should finish without error if error occurs don't we have s discord hope on there. 

If the compilation has been done without any error then it's time to connect the board in boot mode " PRESS THE BOOT BUTTON WHILE CONNECTING THE BOARD WITH PC" ( this should be done only the first time of setting up if arduino are if you have programmed the board with any other way last time).

And then hit upload on the board. 

You should see the beautiful blue led blinking on board.

Congratulation you have you arduino IDE and shrike ready to programmed using the Arduino infrastructure. 


>Credit and Gratitude  to [earlephilhower](https://github.com/earlephilhower/) to creating the board support for RP2040/RP2350 in ArduinoIDE and the little FS tool. 

:::


:::{tab-item} Micro-Python

# Using it with Micro-python 

We have created custom UF2 for shrike this contains a shrike.py library that has custom function to flash fpga and few others. You can use the normal rpi micro python uf2 as well however the step's would be different. 

Now we will here safely assume that you will be using our uf2.

### 1. Uploading the shrike UF2

1. Download the uf2 corresponding to your board version from the shrike's [Github](https://github.com/vicharak-in/shrike-lite).
2. Hold the boot button on the board and connect it the your pc now shrike will show up as as storage device.
3. Copy the downloaded uf2 in storage device you can simply drag and drop in mostly all the devices. 
4. After the successful copying the storage device should disappear.

Check the video tutorial on how to upload the uf2 Shrike dev board(its a generic board video and uf2 will differ in our case) [here](https://www.youtube.com/watch?v=os4mv_8jWfU).

Congratulations you have successfully uploaded the uf2. 


### 2. Shrike Mass Storage Device 

Onces that you have copied the uf2 to the Shrike.  The board will disconnect momentary and so up as both a mass storage device and tty/ACM device now the mass storage is the part where you would need to save you bitstream (read step 3). 

The default device ID for mass storage device is `5221-0000` this could be changed as per your choice. 
For windows simply right click and rename for changing the name in linux read [this](https://superuser.com/questions/223527/renaming-a-fat16-volume). 

### 3. Get the bitstream(.bin) for led blink 

To program a FPGA you will require  bitstream file this is much like a firmware for MCU's we will see how to generate these but for now we have uploaded the bitstream required for led_bin you can download them the corresponding to your board's version [here](https://github.com/vicharak-in/shrike-lite/tree/main/test/bitstreams). 

Now that you have both uf2 and bin file settled up lets move forward and upload the bitstream to board.

### 4. Getting the Thonny IDE 

The bitstream can be uploaded on the shrike using one of these two ways 
   1. Using a GUI Based-IDE (Thonny)
   2. Using Command line interface (CLI)

In this guide we will use Thonny however guide to programme using CLI can be found [here](./shrike_cli_guide.md).

Now we will need to get thonny on our pc. Installation is quite straight forward You can download it from [here](https://thonny.org/). 

Now that we have got all the required tools set-ed up let blink some leds.

Open thonny and connect the board to the laptop (do not press boot button this time). And do these two things 
   1. Connect the board from the bottom right corner of Thonny IDE.
   2. Go to file view mode in the thonny to see the rp2040 as a file system.

### 5. Flashing the bitstream 

The bitstream needs to be copied to the Shrike Mass storage part this is a simple copy process same way as copying a file to a USB drive.

Or you can use this way -- 
You should in thonny see both the your pc and rp2040 file's on the left windows now we have to transfer the led_blink.bin file to the rp2040. 
To do so find the file on your system then right click and upload.

Now we will have to flash this file to the fpga to do so we will use the function 

```
    shrike.flash("<your_bitstream_name>.bin")
```

> [!NOTE]
> The bitstream file that you need to copy will be named as "FPGA_bitstream_MCU.bin" found in ffpga -> build -> bitstream folder in your project directory.  
> If you copy any other file present in the bitstream folder the fpga wont be programmed.
> You are free to change the name of this file however you please.

in thonny open a new python file and write this python script 
```
    import shrike
    shrike.flash("blink_led.bin")
```

Save this file to your board (RP2040) and run it. (to run this file on board boot up just name it as main.py)

:::
::::

If everything has been done correctly you should see led blinking on the board.
