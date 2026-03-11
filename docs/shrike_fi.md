# Setting Up the Shrike-fi board

To flash the firmware 

1. Get the esptools ( install from pip)
2. `python -m esptool erase_flash`
3. `python -m esptool --chip esp32s3 -b 460800 --before default_reset --after hard_reset write_flash --flash_mode dio --flash_size 4MB --flash_freq 80m 0x0 firmware.bin`


