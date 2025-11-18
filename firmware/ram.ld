MEMORY {
        PROGROM (RX) : ORIGIN = 0x00000, LENGTH = 0x10000
        DATARAM (RW) : ORIGIN = 0x10000, LENGTH = 0x10000
}

SECTIONS {
        .text : {
                . = ALIGN(4);
                *startPipeline*.o (.text)
                *(.text*)
        } > PROGROM

        .data : {
                . = ALIGN(4);
                *(.data*)
                *(.sdata*)
                *(.rodata*)
                *(.srodata*)
                *(.bss*)
                *(.sbss*)

                *(COMMON)
                *(.eh_frame)  
                *(.eh_frame_hdr)
                *(.init_array*)         
                *(.gcc_except_table*)
        } > DATARAM
}
