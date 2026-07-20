// Minimal C runtime for the XIP demo: set the stack, zero .bss, call main.
	.section .text.start
	.global _start
_start:
	li   sp, 0x10000            // top of the 64 KB RAM; grows down
	la   a0, __bss_start
	la   a1, __bss_end
1:	bgeu a0, a1, 2f
	sw   zero, 0(a0)
	addi a0, a0, 4
	j    1b
2:	jal  ra, main
	ebreak
