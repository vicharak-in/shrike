/* Linker script for programs running on shrike_serv (SERV RV32I core).
 *
 * The design's memory is the 8 BRAM slices as one flat 4 KB space at 0x0.
 * That 4 KB holds program + data + stack together, so a program overflowing
 * it will fail to link here rather than misbehave on hardware. The stack grows
 * down from the top (_stack_top); keep code + globals + stack within 4 KB.
 * Reset PC is 0x0, so _start must land first -> .text.init / .text.start.
 */
OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY {
  RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 0x1000   /* 4 KB = 8 BRAM slices */
}

SECTIONS {
  . = 0x00000000;
  .text : {
    *(.text.init) *(.text.start)
    *(.text) *(.text*)
  } > RAM
  .rodata : { *(.rodata) *(.rodata*) *(.srodata*) } > RAM
  .data   : { *(.data) *(.data*) *(.sdata*) } > RAM
  .bss    : {
    __bss_start = .;
    *(.bss) *(.bss*) *(.sbss*) *(COMMON)
    __bss_end = .;
  } > RAM
  _end = .;

  _stack_top = ORIGIN(RAM) + LENGTH(RAM);   /* 0x1000 */
}
