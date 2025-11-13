MEMORY {
        BRAM (RWX) : ORIGIN = 0x0000, LENGTH = 0x10000
}

SECTIONS {
        .text : {
                . = ALIGN(4);
                *(.text);
        } > BRAM
        .data : {
                . = ALIGN(4);
                *(.rodata);
        } > BRAM
}
