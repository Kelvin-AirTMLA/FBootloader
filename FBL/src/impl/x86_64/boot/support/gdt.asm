; =============================================================================
; gdt.asm — Global Descriptor Table
; =============================================================================

%ifndef GDT_ASM
%define GDT_ASM

GDT_NULL_SEL    equ 0x00
GDT32_CODE_SEL  equ 0x08
GDT32_DATA_SEL  equ 0x10
GDT64_CODE_SEL  equ 0x08
GDT64_DATA_SEL  equ 0x10

align 8
gdt32_start:

gdt32_null:
    dq  0x0000000000000000

gdt32_code:
    dw  0xFFFF
    dw  0x0000
    db  0x00
    db  10011010b
    db  11001111b
    db  0x00

gdt32_data:
    dw  0xFFFF
    dw  0x0000
    db  0x00
    db  10010010b
    db  11001111b
    db  0x00

gdt32_end:

gdt32_descriptor:
    dw  gdt32_end - gdt32_start - 1
    dd  gdt32_start

align 8
gdt64_start:

gdt64_null:
    dq  0x0000000000000000

gdt64_code:
    dw  0x0000
    dw  0x0000
    db  0x00
    db  10011010b
    db  00100000b
    db  0x00

gdt64_data:
    dw  0x0000
    dw  0x0000
    db  0x00
    db  10010010b
    db  00000000b
    db  0x00

gdt64_end:

gdt64_descriptor:
    dw  gdt64_end - gdt64_start - 1
    dq  gdt64_start

%endif ; GDT_ASM
