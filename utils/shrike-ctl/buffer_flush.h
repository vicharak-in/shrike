#ifndef SHRIKE_CTL_BUFFER_FLUSH_H
#define SHRIKE_CTL_BUFFER_FLUSH_H

#include <stddef.h>
#include <stdint.h>

// Pure byte-buffering state machine used by the UART -> SPI forwarding loop
// in main.c. Has no pico-sdk dependency so it can be compiled and unit
// tested on a host machine (see test_buffer_flush.c).
//
// Feed it one event at a time:
//   - event in [0, 255]: a byte received from the host over UART.
//   - event < 0:         no byte was available before the read timeout,
//                         i.e. the host has gone idle / finished sending.
//
// Returns the number of bytes in `buf` that are ready to be written out
// over SPI (0 means "nothing to flush yet"). When the return value is
// non-zero, the caller must transmit buf[0..return) and then reset *len
// to 0 before the next call.
static inline size_t shrike_ctl_process_event(uint8_t *buf, size_t *len, size_t cap, int event) {
    if (event >= 0 && event <= 255) {
        buf[(*len)++] = (uint8_t)event;
        if (*len == cap) {
            return *len;
        }
        return 0;
    }

    // Idle: nothing arrived within the timeout window. Flush any partial
    // chunk now instead of holding onto it forever — otherwise the tail of
    // a file whose size isn't a multiple of `cap` bytes is silently dropped.
    return *len;
}

#endif // SHRIKE_CTL_BUFFER_FLUSH_H
