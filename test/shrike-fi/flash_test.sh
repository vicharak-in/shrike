!/bin/bash

set -e

echo "Starting ESP32 parallel flashing..."

shopt -s nullglob
PORTS=(/dev/ttyACM*)

if [ ${#PORTS[@]} -eq 0 ]; then
    echo "No /dev/ttyACM* devices found."
    exit 1
fi

for PORT in "${PORTS[@]}"
do
(
    echo "Flashing $PORT"

    esptool.py \
    --chip esp32s3 \
    --port "$PORT" \
    --baud 921600 \
    write_flash -z \
    0x0 bootloader.bin \
    0x8000 partition-table.bin \
    0x10000 test_firmware.bin

    echo "$PORT DONE"

) &
done

wait

echo "All ESP32 boards flashed successfully."
