/* XIP demo layout: code+data live in the 60 KB below the IO words at 0xF000.
   Stack descends from 0x10000 (set by crt0), clear of 0xF000/0xF004.        */
MEMORY {
	mem : ORIGIN = 0x00000000, LENGTH = 0x0000F000
}

SECTIONS {
	.text : {
		. = 0x000000;
		*(.text.start)
		*(.text*)
		. = ALIGN(4);
	} > mem

	.rodata : { *(.rodata*) *(.srodata*) . = ALIGN(4); } > mem
	.data   : { *(.data*)   *(.sdata*)   . = ALIGN(4); } > mem

	.bss : {
		. = ALIGN(4);
		__bss_start = .;
		*(.bss*) *(.sbss*) *(COMMON)
		. = ALIGN(4);
		__bss_end = .;
	} > mem
}
