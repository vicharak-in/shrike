(shrike_pinouts)=

# Shrike Dev Board Pin Outs 



<div align="center">

 <img src="./images/shrike_pinouts.svg" alt="shrike" width="100%">

</div>


## FPGA RP2040 Communication Pin-outs

### FPGA CPU Interconnect Pin-outs 

<div align="center">


| FPGA PIN | RP 2040 PIN |       RP2040         |       FPGA             |
|----------|-------------|----------------------|------------------------|
| EN       | 13          | GPIO                 | EN (Enable)            |
| PWR      | 12          | GPIO                 | PWR                    |
| 3        | 2           | GPIO                 | SPI_SCLK               |
| 4        | 1           | UART RX / GPIO       | SPI_SS                 |
| 5        | 3           | GPIO                 | SPI_SI (MOSI)          |
| 6        | 0           | UART TX / GPIO       | SPI_SO (MISO) / CONFIG |
| 18       | 14          | GPIO / I2C 1 SDA     | GPIO                   |
| 17       | 15          | GPIO / I2C 1 SDA     | GPIO                   |
 
</div>
