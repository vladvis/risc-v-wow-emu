SECTIONS
{
    . = 0x80000000; /* Set the starting address for your program */

    .text : {
        *(.text)
    }
}