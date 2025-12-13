(shrike_cli_guide)=

# User guide to access and use shrike from your terminal(CLI)

If you are anything like our team at [vicharak](vicharak.in) and you don't want to move away from the terminal. We have got you cover here is a quick guide for accessing and using shrike from terminal (CLI). 

To do so we will be using mpremote feature of micro-python.

Before getting started with accessing the shrike over terminal you should upload the shrike uf2 board read first two steps from [this](./getting_started.md) guide to learn how to. 

Now we are assuming that you have done those two steps lets connect with shrike over terminal.

We will follow these steps 


### 1. Getting the Py-env and mpremote

Mpremote is a python package and we will have to use pip to install it thus we need to a py virtual env. (if you already have one use that).

Or to setup a python Env read [this](https://docs.python.org/3/library/venv.html) and then activate it . 

Now that your v-env is activated we will get mpremote in the env. To do so run this command 

```
    pip install mpremote 
```
if everything run's without error you have successfully got all the tools to access shrike over terminal however if you face issues then google it or ask in our discord. 

Now lets blink led form the terminal 

### 2. Blinking the CPU led 

To check out how mpremote works we will first blink the led connected to rp2040 and then we will flash blink led on fpga.

To blink a led on rp2040 the python script looks like this save this as a test_led.py file on your pc.

```
from machine import Pin
import time

led = Pin(4, Pin.OUT)  # onboard LED on GPIO 25

while True:
led.toggle()   # switch state
time.sleep(0.5)
```
then we can run this file using the command 
```
    mpremote run test_led.py
```

if you have multiple shrike or rp2040 connected then you need to specify the port number of the board you want to programme something like 

```
    mpremote connect port:<port path> run test_led.py
```
you should see the led blinking on shrike.

You can also access the REPL on the rp2040 by running 

```
    mpremote 
```
now you can python one line at a time. 

### 3. Uploading the bitstream to the shrike.

To flash the fpga with bitstream we need to first upload it to the rp2040 to do that we need to simply run the cp command of mpremote. The bitstream file could be found [here](https://github.com/vicharak-in/shrike_fpga/tree/main/test/bitstreams) get the one corresponding to your board version. 

```
    mpremote cp blink_led.bin : 
```
do not forget the : in the end . Now just run the cmd below to check if the file is copied or not
```
    mpremote ls 
```
lets flash that bitstream to the fpga now.


### 4. Flashing the fpga 

To flash the uploaded bitstream we need to execute this python script 

```
import shrike

#shrike.flash("<bitstream_name>.bin")
# in out case that is 

shrike.flash("blink_led.bin")
```
now you can run this cmd as mentioned in step 2 or you can open the repl and type the python script one by one.

Onces the fpga is flashed you should see the led connected to fpga blinking.

The mpremote has a lot more features as well you can check them all out in there guide [here](https://docs.micropython.org/en/latest/reference/mpremote.html#).

Will also suggest reading this [discussion](https://github.com/orgs/micropython/discussions/9096). 