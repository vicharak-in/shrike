#!/bin/bash
set -uo pipefail

# ============================================================
#  flash_shrike_multi.sh
#  Flashes one or more Shrike boards in parallel.
#
#  Flow:
#    1. Detect board(s) in UF2/bootloader mode  (label = RPI-RP2)
#    2. Copy MicroPython UF2 → board reboots into runtime mode
#    3. Detect board(s) in runtime mode          (UUID = 5221-0000)
#    4. Copy bitstream + main.py → board
#    5. Run main.py via mpremote on every /dev/ttyACM*
# ============================================================

# ── Configuration ───────────────────────────────────────────
UF2_LABEL="RPI-RP2"
SHRIKE_UUID="5221-0000"

MOUNT_BASE="/mnt/shrike"

FILES_UF2=(
    "./shrike-lite-micropython.uf2"
)

FILES_SHRIKE=(
    "./blink_all.bin"
    "./main.py"
)

MPREMOTE_BIN="/home/vicharak/hardware_test/venv/bin/mpremote"
MPREMOTE_TIMEOUT=8          # seconds before mpremote is killed
MPREMOTE_MAIN="/home/vicharak/hardware_test/main.py"

REBOOT_WAIT=6               # seconds to wait after UF2 flash for reboot
RUNTIME_SETTLE=4            # seconds to wait after runtime flash before mpremote
SERIAL_POLL_RETRIES=10      # how many times to check for a file via mpremote ls
# ────────────────────────────────────────────────────────────

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ── Helper: copy files to a USB device, then unmount ────────
flash_usb() {
    local device="$1"
    local mountpoint="$2"
    local -n files="$3"     # nameref to the files array

    # Use existing auto-mount if available, otherwise mount manually
    local existing
    existing=$(findmnt -n -o TARGET -S "$device" 2>/dev/null || true)
    if [[ -n "$existing" ]]; then
        mountpoint="$existing"
        log "[$device] Using auto-mount at $mountpoint"
    else
        log "[$device] Mounting to $mountpoint"
        sudo mkdir -p "$mountpoint"
        if ! sudo mount "$device" "$mountpoint"; then
            log "[$device] ERROR: mount failed"
            return 0   # don't let this kill the parent via 'wait'
        fi
    fi

    for f in "${files[@]}"; do
        if [[ -e "$f" ]]; then
            log "[$device] Copying $(basename "$f")"
            sudo cp -r "$f" "$mountpoint/" || log "[$device] WARN: copy failed for $f"
        else
            log "[$device] ERROR: file not found – $f"
        fi
    done

    sync && sync && sleep 3

    if [[ -z "$existing" ]]; then
        log "[$device] Unmounting $mountpoint"
        sudo umount "$mountpoint" || log "[$device] WARN: umount failed"
    fi

    log "[$device] USB flash complete"
    return 0
}

# ── Helper: wait until a specific file appears on the board ─
wait_for_file_on_board() {
    local serial="$1"
    local filename="$2"

    for (( i = 0; i < SERIAL_POLL_RETRIES; i++ )); do
        "$MPREMOTE_BIN" connect "$serial" ls 2>/dev/null | grep -q "$filename" && return 0
        sleep 1
    done
    return 1
}

# ── Helper: run main.py on a single serial port ──────────────
run_mpremote() {
    local serial="$1"

    if [[ ! -x "$MPREMOTE_BIN" ]]; then
        log "[$serial] ERROR: mpremote not found at $MPREMOTE_BIN"
        return 0
    fi

    log "[$serial] Waiting for blink_all.bin to appear on board..."
    if ! wait_for_file_on_board "$serial" "blink_all.bin"; then
        log "[$serial] ERROR: blink_all.bin not ready – skipping"
        return 0
    fi

    log "[$serial] Executing main.py"
    if timeout "$MPREMOTE_TIMEOUT" "$MPREMOTE_BIN" connect "$serial" run "$MPREMOTE_MAIN"; then
        log "[$serial] mpremote completed successfully"
    else
        log "[$serial] WARN: mpremote timed out or returned an error"
    fi
    return 0
}

# ── Step 1: Flash UF2 (bootloader mode) ─────────────────────
flash_uf2_stage() {
    mapfile -t uf2_devs < <(
        lsblk -rpo NAME,TYPE,LABEL \
        | awk -v lbl="$UF2_LABEL" '$2=="part" && $3==lbl {print $1}'
    )
    [[ "${#uf2_devs[@]}" -eq 0 ]] && return 0

    log "Detected ${#uf2_devs[@]} board(s) in UF2 / bootloader mode"

    local idx=0
    for dev in "${uf2_devs[@]}"; do
        flash_usb "$dev" "$MOUNT_BASE/$idx" FILES_UF2 &
        (( idx++ )) || true
    done
    wait

    log "UF2 flash done → waiting ${REBOOT_WAIT}s for boards to reboot..."
    sleep "$REBOOT_WAIT"
    return 0
}

# ── Step 2: Flash runtime files + run via mpremote ──────────
flash_runtime_stage() {
    mapfile -t shrike_devs < <(
        lsblk -rpo NAME,UUID \
        | awk -v u="$SHRIKE_UUID" '$2==u {print $1}'
    )
    [[ "${#shrike_devs[@]}" -eq 0 ]] && return 0

    log "Detected ${#shrike_devs[@]} board(s) in runtime mode"

    local idx=0
    for dev in "${shrike_devs[@]}"; do
        flash_usb "$dev" "$MOUNT_BASE/$idx" FILES_SHRIKE &
        (( idx++ )) || true
    done
    wait

    log "Runtime files flashed → waiting ${RUNTIME_SETTLE}s before mpremote..."
    sleep "$RUNTIME_SETTLE"

    mapfile -t acm_devs < <(ls /dev/ttyACM* 2>/dev/null || true)
    if [[ "${#acm_devs[@]}" -eq 0 ]]; then
        log "WARN: no /dev/ttyACM* devices found – skipping mpremote"
        return 0
    fi

    for acm in "${acm_devs[@]}"; do
        run_mpremote "$acm" &
    done
    wait

    log "All boards flashed and running successfully"
    return 0
}

# ── Main ────────────────────────────────────────────────
mkdir -p "$MOUNT_BASE"
log "Running flash once (UF2 label='$UF2_LABEL' | runtime UUID='$SHRIKE_UUID')..."

flash_uf2_stage
flash_runtime_stage

log "Done."