#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/spi.h"

// -----------------SPI Definaltions-----------------------------
#define SPI_INSTANCE (spi0) 	// SPI0  
#define SPI_CLOCK (1000*16000)  // FPGA support 16MHZ clock
#define PIN_MISO  0             // Not used (receive only)
#define PIN_MOSI  3
#define PIN_SCK   2
#define PIN_SS    1
#define PIN_PWR   12            // Power PIN
#define PIN_EN    13           // Enable PIN
#define BUF_SIZE  64
uint8_t tx_buf[BUF_SIZE];
size_t  tx_len = 0;

int main(){
    stdio_init_all();
    //---------------------SPI PIN Setup------------------------------------
    spi_init(SPI_INSTANCE, SPI_CLOCK);
    gpio_set_function(PIN_MISO, GPIO_FUNC_SPI);
    gpio_set_function(PIN_MOSI, GPIO_FUNC_SPI);
    gpio_set_function(PIN_SCK,  GPIO_FUNC_SPI);
    gpio_set_function(PIN_SS, GPIO_FUNC_SPI);

    //--------------------- PIN Initilization--------------------------------
    gpio_init(PIN_SS);
    gpio_init(PIN_PWR);
    gpio_init(PIN_EN);

    //-----------------------PINS Set as a output----------------------------
    gpio_set_dir(PIN_PWR, GPIO_OUT);
    gpio_set_dir(PIN_EN, GPIO_OUT);
    gpio_set_dir(PIN_SS, GPIO_OUT);

    //----------------------FPGA RESET---------------------------------------
    gpio_put(PIN_PWR, 0);
    gpio_put(PIN_EN, 0);
    gpio_put(PIN_SS, 1);
    sleep_ms(3);

    //--------------------FPGA Initilization---------------------------------
    gpio_put(PIN_PWR, 1);
    gpio_put(PIN_EN, 1);
    gpio_put(PIN_SS, 0);
    sleep_ms(3);
    gpio_put(PIN_SS, 1);
    sleep_us(3);

    while (true) {
    
         int ch = getchar_timeout_us(1000);
           if (ch >= 0 && ch <= 255){
      	        tx_buf[tx_len++] = (uint8_t)ch;

	         if (tx_len == BUF_SIZE){
                      gpio_put(PIN_SS, 0);
                      spi_write_blocking(SPI_INSTANCE, tx_buf, tx_len);
                      gpio_put(PIN_SS, 1);
                      tx_len = 0;
                  }
            }
      }
}    
