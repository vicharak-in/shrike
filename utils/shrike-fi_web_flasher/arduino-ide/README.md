# FPGA Flasher over Wi-Fi (Shrike fi)

This project lets you upload an FPGA bitstream file from a browser to an Shrike fi over Wi-Fi, store it in SPIFFS, and stream it to an FPGA over SPI.

## Features

- Wi-Fi hosted upload page (`/`)
- Drag-and-drop or file picker upload UI
- SPIFFS storage on ESP32-S3
- SPI transfer to FPGA in 256-byte chunks

## Hardware

- Shrike-fi board

## Pin Mapping

Current mapping from `Web_FPGA_programmer.ino`:

- `MISO` -> GPIO `13`
- `MOSI` -> GPIO `11`
- `SCK`  -> GPIO `12`
- `SS`   -> GPIO `10`
- `PWR`  -> GPIO `9`
- `EN`   -> GPIO `8`

## Wi-Fi Configuration

Update these values in `Web_FPGA_programmer.ino` before flashing:

```cpp
const char *ssid = <"SSID">;
const char *password = <"PASSWORD">;
```

## Build and Flash

1. Open `fpga_flasher.ino` in Arduino IDE.
2. Select your ESP32-S3 board and correct serial port.
3. Make sure ESP32 core for Arduino is installed.
4. Upload the sketch.

## How to Use

1. Open Serial Monitor at `115200` baud.
2. Wait for Wi-Fi connection and note the printed IP address.
3. Open that `IP` in your browser.
4. Drag/drop or select your `FPGA_bitstream` file.
5. Wait for completion message:
   `FILE UPLOADED IN ESP32S3 & FPGA FLASHING DONE`

## Serial Output (Expected)

You should see logs similar to:

- `FPGA INIT DONE`
- `WIFI CONNECTED`
- `ESP32 IP: <ip>`
- `HTTP SERVER STARTED`
- Upload and SPI transfer progress logs

## Notes

- SPI clock is configured as `16 MHz` (`SPI_CLOCK = 1000 * 16000`) as per configuration Documentation.
- Upload files are saved in SPIFFS using their uploaded filename.
- The upload handler writes to SPIFFS first, then transmits file contents to FPGA.

## Troubleshooting

- If Wi-Fi does not connect, recheck SSID/password.
- If upload fails, verify the browser is opening the ESP32 IP on the same network.
- If SPI transfer fails, verify wiring, voltage compatibility, and FPGA power/reset timing.

## Web page link

- `http://<ESP32 IP>` 
- Example: `http://10.122.189.12`
