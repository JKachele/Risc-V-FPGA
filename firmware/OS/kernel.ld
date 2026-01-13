MEMORY {
        PROGROM (RX) : ORIGIN = 0x00000, LENGTH = 0x10000
        DATARAM (RW) : ORIGIN = 0x10000, LENGTH = 0x10000
}

ENTRY(_start)

SECTIONS {
        .text : {
                . = ALIGN(2);
                KEEP(*(.text.bios));
                *(.text .text.*);
        } > PROGROM

        .data : {
                . = ALIGN(4);
                *(.data.bios*)
                *(.sdata.bios*)
                *(.rodata.bios*)
                *(.srodata.bios*)
                __bss_bios = .;
                *(.bss.bios*)
                *(.sbss.bios*)
                __bss_bios_end = .;

                . += 8 * 1024; /* 8KB */
                __stack_top_bios = .;

                . = ALIGN(4);
                *(.data*)
                *(.sdata*)
                *(.rodata*)
                *(.srodata*)
                __bss = .;
                *(.bss*)
                *(.sbss*)
                __bss_end = .;

                . += 8 * 1024; /* 8KB */
                __stack_top = .;
        } > DATARAM
}
