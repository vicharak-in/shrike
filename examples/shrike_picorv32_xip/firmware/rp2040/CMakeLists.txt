cmake_minimum_required(VERSION 3.13)

include(pico_sdk_import.cmake)

project(shrike_xip C CXX ASM)
set(CMAKE_C_STANDARD 11)

pico_sdk_init()

# Embed the FPGA bitstream as a C array so the RP2040 configures the FPGA over
# SPI at boot -- no separate flash step. Generated inline from the example's
# committed bitstream (re-run cmake if the bitstream changes).
set(BITSTREAM ${CMAKE_CURRENT_LIST_DIR}/../../bitstream/shrike_picorv32_xip.bin)
file(READ ${BITSTREAM} _bits_hex HEX)
string(LENGTH "${_bits_hex}" _bits_hexlen)
math(EXPR _bits_len "${_bits_hexlen} / 2")
string(REGEX REPLACE "(..)" "0x\\1," _bits_arr "${_bits_hex}")
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/bitstream.c
     "#include <stdint.h>\n"
     "const uint32_t fpga_bitstream_len = ${_bits_len};\n"
     "const uint8_t fpga_bitstream[${_bits_len}] = {${_bits_arr}};\n")

add_executable(shrike_xip
    main.c
    sram.c
    ${CMAKE_CURRENT_BINARY_DIR}/bitstream.c
)

pico_generate_pio_header(shrike_xip ${CMAKE_CURRENT_LIST_DIR}/sram.pio)

target_include_directories(shrike_xip PRIVATE ${CMAKE_CURRENT_LIST_DIR})

target_link_libraries(shrike_xip
    pico_stdlib
    pico_multicore
    hardware_pio
    hardware_dma
    hardware_spi
)

# USB console, no UART; the custom memmap places emu_ram at 0x20030000
pico_enable_stdio_usb(shrike_xip 1)
pico_enable_stdio_uart(shrike_xip 0)
pico_set_linker_script(shrike_xip ${CMAKE_CURRENT_LIST_DIR}/sram_memmap.ld)

pico_add_extra_outputs(shrike_xip)
