SECTIONS
{
    /* Define the memory regions */
    . = 0x80000000; /* Set the starting address for your program */

    .text : {
        *(.text)
    }

    .data : {
        *(.data)
    }

    .bss : {
        *(.bss)
    }

    .result 0x80001000 : {  /* Allocate the .result section at a fixed address */
        KEEP(*(.result))
    }
}