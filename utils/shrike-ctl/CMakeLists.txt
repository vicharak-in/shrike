cmake_minimum_required(VERSION 3.13)
include(/PATH/TO/PICO_SDK/pico_sdk_import.cmake)
project(shrike-ctl)
pico_sdk_init()
add_executable(shrike-ctl main.c)
target_link_libraries(shrike-ctl 
        pico_stdlib 
        hardware_spi
    )
pico_enable_stdio_usb(shrike-ctl 1)
pico_add_extra_outputs(shrike-ctl) 
