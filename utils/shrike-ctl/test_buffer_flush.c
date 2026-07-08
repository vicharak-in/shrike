// Host-side regression test for the SPI forwarding buffer in main.c.
//
// Build & run (no pico-sdk required):
//   gcc -Wall -o test_buffer_flush test_buffer_flush.c && ./test_buffer_flush
//
// Before the fix, shrike_ctl_process_event() never flushed a partial buffer
// on idle, so the trailing bytes of any file whose size wasn't a multiple
// of BUF_SIZE (e.g. every 46408-byte bitstream in test/bitstreams/v1_4/)
// were silently dropped. This test fails on that old behavior and passes
// on the fixed behavior.
#include <assert.h>
#include <stdio.h>
#include "buffer_flush.h"

int main(void) {
    const size_t FILE_SIZE = 46408; // matches test/bitstreams/v1_4/led_blink.bin
    const size_t BUF_SIZE = 64;     // matches BUF_SIZE in main.c

    uint8_t tx_buf[BUF_SIZE];
    size_t tx_len = 0;
    size_t total_flushed = 0;
    size_t flush_count = 0;

    for (size_t i = 0; i < FILE_SIZE; i++) {
        size_t n = shrike_ctl_process_event(tx_buf, &tx_len, BUF_SIZE, (int)(i % 256));
        if (n > 0) {
            total_flushed += n;
            flush_count++;
            tx_len = 0;
        }
    }

    // Host has stopped sending (file fully read) -> next getchar_timeout_us
    // call would time out. Simulate that idle event.
    size_t n = shrike_ctl_process_event(tx_buf, &tx_len, BUF_SIZE, -1);
    if (n > 0) {
        total_flushed += n;
        flush_count++;
        tx_len = 0;
    }

    assert(total_flushed == FILE_SIZE);   // every byte must reach the FPGA
    assert(flush_count == 726);           // 725 full 64-byte chunks + 1 trailing 8-byte chunk
    assert(tx_len == 0);                  // nothing left stuck in the buffer

    printf("OK: %zu/%zu bytes flushed across %zu chunk(s)\n", total_flushed, FILE_SIZE, flush_count);
    return 0;
}
