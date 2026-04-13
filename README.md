# Shrike 

![image](./asset/shirke-angle-01.jpg)

Shrike is a family of low cost affordable FPGA development board along with a host microcontroller. 
Currently the family features these two members -: 

1. Shrike-lite (FPGA with RP2040) 
2. Shrike      (FPGA with RP2350)
3. Shrike-fi   (FPGA with ESP32-S3) 

And a lot version under development.

We usually work on very complex FPGA-based projects built around [Vaaman](https://vicharak.in/vaaman) and its upcoming series. However, Shrike is a passion project at Vicharak, driven by our love for engineering across both embedded microcontrollers and FPGAs.

Our goal is to make FPGAs accessible to everyone by offering robust toolchains, high-quality hardware, and strong ecosystem support. We’re committed to keeping the hardware prices extremely low, and every piece of software for Shrike will be completely open-source.

We at vicharak have kept in mind need of a learner, maker and a hobbyist while designing this art. This dev board will be your stepping stone in the field of FPGA, reconfigurable and heterogenous computing.

We invite contributors from all over the world to join us in this mission. Together, let’s make FPGA technology truly accessible to all. 

### Get the Hardware 

Shrike-lite the RP2040 version of the family is available at our store for worldwide shipping and the Shrike RP2350 version will be available on the crowdsupply soon. You can follow the links below to get both.


#### 1. [Shrike-lite](https://store.vicharak.in/?product=shrike&post_type=product&name=shrike&v=13b5bfe96f3e)

#### 2. [Shrike](https://www.crowdsupply.com/vicharak/shrike)

#### 3. Shrike-fi (Launching Soon)

### Board level Block Diagram

<div align="center">

![shrike](./asset/shrike_block.svg)

</div>


### Key Features : 

| **Feature**                          | **Shrike**             | **Shrike-lite**        |**Shrike-fi**       |
|:-----------------------------------:|:-----------------------:|:----------------------:|:------------------:|
| FPGA                                | 1120 × 5-input LUTs     | 1120 × 5-input LUTs    | 1120 × 5-input LUTs|
| MCU                                 | RP2350                  | RP2040                 | ESP32-S3           |
| PMOD Compatible Connector           | ✅                      | ✅                     | ✅                 |
| Breadboard Compatible               | ✅                      | ✅                     | ✅                 |
| FPGA ↔ MCU IO Interface             | ✅                      | ✅                     | ✅                 |  
| Flash (QSPI)                        | 4 MB                    | 4 MB                   | 8 MB               |
| PSRAM (QSPI)                        | ❌                      | ❌                     | 8 MB               |
| User LEDs                           | 2                       | 2                      | 2                  |
| USB Type-C (Power & Programming)    | ✅                      | ✅                     | ✅                 |
| WiFi                                | ❌                      | ❌                     | ✅                 |
| BLE                                 | ❌                      | ❌                     | ✅                 |




### Documentation for Shrike-fi is work in Progress. 

### Check out 
 1. [Documentation](https://vicharak-in.github.io/shrike/index.html)
 2. [Pin_outs](https://vicharak-in.github.io/shrike/shrike_pinouts.html)
 3. [FPGA_CPU_Interconnect](https://vicharak-in.github.io/shrike/shrike_pinouts.html#fpga-rp2040-communication-pin-outs)


## 📫 Join our communities at :
  
   [<img src="./asset/discord-icon.svg" width="10%"/>](https://discord.com/invite/EhQy97CQ9G)  &nbsp; [<img src="./asset/x_icon.png" width="10%"/>](https://x.com/Vicharak_In)  &nbsp; [<img src="./asset/vicharak_icon.png" width="10%"/>](https://discuss.vicharak.in/)  &nbsp; [<img src="https://img.icons8.com/color/48/000000/linkedin.png" width="10%"/>](https://www.linkedin.com/company/vicharak-in)  &nbsp; [<img src="./asset/reddit_icon.jpeg" width="10%"/>](https://www.reddit.com/r/Vicharak/)  &nbsp;

### Note
 
We are building a ecosystem for learners , makers and hobbyist around shrike and the projects that will follow in future, thus we request you contribution in the same. Join our communities across all the platforms, pitch and showcase your ideas with Shrike. 

Thank You 

### What to contribute ? 

You can contribute the project's and example's that you have designed on Shrike or any utils that you might have designed.

We also have live bounty from time to time check it [here](./bounty.md) 

## Contribution Guideline  

Your contribution to the Shrike project are always welcome.
To contribute fork the project test your changes and create a PR. Few things in to keep in mind for better contribution. 
Please read the Contribution [Guide](./CONTRIBUTING.md) to know them.


## LICENSE 

### Software

This project’s software is licensed under the GNU General Public License v2.0 (GPL-2.0).
See the [LICENSE](./LICENSE.md)for details.

### Hardware

This project’s hardware designs (HDL/RTL, schematics, PCB files, constraints, etc.) are licensed under the CERN Open Hardware License v1.2.
See [LICENSE_HW](./LICENSE_HW.md) for details.

