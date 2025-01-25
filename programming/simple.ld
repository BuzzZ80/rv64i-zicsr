OUTPUT_ARCH( "riscv" )
ENTRY(_start)

__heap_size   = 0x1000;
__stack_size  = 0x4000;

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 0x8000
}
SECTIONS
{
    .text :
    {
        *(.boot)
        *(.text*)
        *(.rodata*)
    } > RAM

    .data :
    {
        *(.sbss)
        *(.data*)
        *(.bss)
        *(.rela*)
        *(COMMON)
    } > RAM

    .heap :
    {
        . = ALIGN(8);
        PROVIDE ( end = . );
        _sheap = .;
        . = . + __heap_size;
        . = ALIGN(8);
        _eheap = .;
    } >RAM

    .stack :
    {
        . = ALIGN(8);
        _estack = .;
        . = . + __stack_size;
        . = ALIGN(8);
        _sstack = .;
    } >RAM
}