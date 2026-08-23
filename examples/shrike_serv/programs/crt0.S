# crt0.S -- minimal C runtime for programs on the shrike_serv core.
#
# Sets the stack pointer to the top of the 4 KB memory, zeroes .bss, calls
# main(), then reports the result to the GPIO latch (store to 0x40000000):
#   main() == 0  -> store 1  (PASS, result pins read 0b11)
#   main() != 0  -> store 0  (FAIL, result pins read 0b01)
# and spins forever. Reset PC is 0x0, so this lands first via .text.start.
        .section .text.start
        .global _start
_start:
        la      sp, _stack_top          # stack grows down from 0x1000
        # zero .bss
        la      a0, __bss_start
        la      a1, __bss_end
1:      bgeu    a0, a1, 2f
        sw      zero, 0(a0)
        addi    a0, a0, 4
        j       1b
2:      jal     ra, main                # a0 = return value (0 = success)
        seqz    a0, a0                  # a0 = (main()==0) ? 1 : 0
        li      a1, 0x40000000          # result MMIO (ext space)
        sw      a0, 0(a1)               # 1 -> PASS, 0 -> FAIL
3:      j       3b                      # halt
