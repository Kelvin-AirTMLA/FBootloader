; ==========================================
; HEADER.ASM - Common constants and macros
; ==========================================
; NASM include file for bare-metal x86_64.
; %include "header.asm" from boot/kernel sources.

; ------------------------------------------
; General constants
; ------------------------------------------

SYSTEM_SUCCESS  equ 0
SYSTEM_FAILURE  equ 1
BOOT_MAGIC      equ 0xAA55          ; MBR signature (bytes 510-511: 55 AA)

PAGE_SIZE       equ 4096
PAGE_MASK       equ (PAGE_SIZE - 1)

; x86_64 flat memory model segment selectors (set by bootloader / GDT)
KERNEL_CS       equ 0x08
KERNEL_DS       equ 0x10
USER_CS         equ 0x1B
USER_DS         equ 0x23
TSS_SELECTOR    equ 0x28

; Control register bits
CR0_PE          equ 1 << 0
CR0_PG          equ 1 << 31
CR4_PAE         equ 1 << 5

; Page table entry flags
PTE_PRESENT     equ 1 << 0
PTE_WRITABLE    equ 1 << 1
PTE_USER        equ 1 << 2
PTE_PWT         equ 1 << 3
PTE_PCD         equ 1 << 4
PTE_ACCESSED    equ 1 << 5
PTE_DIRTY       equ 1 << 6
PTE_PS          equ 1 << 7
PTE_GLOBAL      equ 1 << 8
PTE_NO_EXEC     equ 1 << 63

; ------------------------------------------
; Multiboot2 constants
; ------------------------------------------

MULTIBOOT2_MAGIC        equ 0xE85250D6
MULTIBOOT2_ARCH         equ 0
; MULTIBOOT2_HEADER_LEN: define in boot.asm where header labels exist
MULTIBOOT2_CHECKSUM     equ -(MULTIBOOT2_MAGIC + MULTIBOOT2_ARCH)

MULTIBOOT_TAG_ALIGN     equ 8
MULTIBOOT_TAG_END       equ 0
MULTIBOOT_TAG_INFO_REQ  equ 1
MULTIBOOT_TAG_ADDRESS   equ 2
MULTIBOOT_TAG_FRAMEBUFFER equ 5

; ------------------------------------------
; VGA text mode constants
; ------------------------------------------

VGA_WIDTH       equ 80
VGA_HEIGHT      equ 25
VGA_MEMORY      equ 0xB8000

VGA_BLACK       equ 0x0
VGA_BLUE        equ 0x1
VGA_GREEN       equ 0x2
VGA_CYAN        equ 0x3
VGA_RED         equ 0x4
VGA_MAGENTA     equ 0x5
VGA_BROWN       equ 0x6
VGA_LIGHT_GRAY  equ 0x7
VGA_DARK_GRAY   equ 0x8
VGA_LIGHT_BLUE  equ 0x9
VGA_LIGHT_GREEN equ 0xA
VGA_LIGHT_CYAN  equ 0xB
VGA_LIGHT_RED   equ 0xC
VGA_LIGHT_MAGENTA equ 0xD
VGA_YELLOW      equ 0xE
VGA_WHITE       equ 0xF

VGA_DEFAULT_COLOR equ ((VGA_LIGHT_GRAY << 4) | VGA_BLACK)

; ------------------------------------------
; Serial (COM1) constants
; ------------------------------------------

COM1_PORT       equ 0x3F8
COM_IER         equ 1
COM_IIR         equ 2
COM_FCR         equ 2
COM_LCR         equ 3
COM_MCR         equ 4
COM_LSR         equ 5
COM_DLL         equ 0
COM_DLH         equ 1

; ------------------------------------------
; Port I/O macros
; ------------------------------------------

%macro OUTB 2
    mov dx, %1
    mov al, %2
    out dx, al
%endmacro

%macro INB 2
    mov dx, %1
    in al, dx
    mov %2, al
%endmacro

%macro OUTW 2
    mov dx, %1
    mov ax, %2
    out dx, ax
%endmacro

%macro INW 2
    mov dx, %1
    in ax, dx
    mov %2, ax
%endmacro

%macro OUTL 2
    mov dx, %1
    mov eax, %2
    out dx, eax
%endmacro

%macro INL 2
    mov dx, %1
    in eax, dx
    mov %2, eax
%endmacro

; ------------------------------------------
; CPU control macros
; ------------------------------------------

%macro DISABLE_INTERRUPTS 0
    cli
%endmacro

%macro ENABLE_INTERRUPTS 0
    sti
%endmacro

%macro CPU_HALT 0
    hlt
%endmacro

%macro CPU_PAUSE 0
    pause
%endmacro

%macro CPU_HANG 0
%%hang:
    hlt
    jmp %%hang
%endmacro

%macro CPU_BREAKPOINT 0
    int3
%endmacro

; ------------------------------------------
; Stack macros
; ------------------------------------------

%macro SETUP_STACK 1
    mov rsp, %1
    and rsp, ~0xF
%endmacro

%macro PUSH_REGS 0
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
%endmacro

%macro POP_REGS 0
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
%endmacro

; ------------------------------------------
; Segment / table macros
; ------------------------------------------

%macro LOAD_GDT 1
    lgdt [%1]
%endmacro

%macro LOAD_IDT 1
    lidt [%1]
%endmacro

%macro RELOAD_SEGMENTS 2
    mov ax, %1
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    push %2
    push qword .flush_return
    retfq
.flush_return:
%endmacro

; GDT entry: base, limit, access byte, granularity byte
%macro GDT_ENTRY 4
    dw (%2 & 0xFFFF)
    dw (%1 & 0xFFFF)
    db ((%1 >> 16) & 0xFF)
    db %3
    db (%2 >> 16) & 0x0F
    db %4
%endmacro

; IDT gate: offset_low, selector, ist/type/attributes, offset_mid, offset_high
%macro IDT_GATE 5
    dw (%1 & 0xFFFF)
    dw %2
    db 0
    db %3
    dw (%1 >> 16) & 0xFFFF
    dd (%1 >> 32) & 0xFFFFFFFF
    dd 0
%endmacro

; ------------------------------------------
; VGA text output macros
; ------------------------------------------
; Requires extern cursor_pos (dword) in the including file.

%macro VGA_PUTCHAR 2
    push rax
    push rbx
    push rcx
    push rdx
    push rdi

    mov eax, [cursor_pos]
    mov ebx, VGA_WIDTH
    xor edx, edx
    div ebx
    mov ebx, eax
    mov eax, edx

    imul ebx, VGA_WIDTH
    add ebx, eax
    shl ebx, 1
    add rbx, VGA_MEMORY

    mov al, %1
    mov ah, %2
    mov [rbx], ax

    inc dword [cursor_pos]

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
%endmacro

%macro VGA_PRINT_STRING 2
    push rax
    push rcx
    push rdi

    mov rdi, %1
    mov cl, %2

%%.next_char:
    test cl, cl
    jz %%.done
    mov al, [rdi]
    VGA_PUTCHAR al, VGA_DEFAULT_COLOR
    inc rdi
    dec cl
    jmp %%.next_char

%%.done:
    pop rdi
    pop rcx
    pop rax
%endmacro

%macro VGA_CLEAR_SCREEN 1
    push rax
    push rcx
    push rdi

    mov rdi, VGA_MEMORY
    mov rcx, VGA_WIDTH * VGA_HEIGHT
    mov ax, (VGA_DEFAULT_COLOR << 8) | %1
    rep stosw

    mov dword [cursor_pos], 0

    pop rdi
    pop rcx
    pop rax
%endmacro

; ------------------------------------------
; Serial output macros (COM1)
; ------------------------------------------

%macro SERIAL_INIT 0
    OUTB COM1_PORT + COM_IER, 0x00
    OUTB COM1_PORT + COM_LCR, 0x80
    OUTB COM1_PORT + COM_DLL, 0x03
    OUTB COM1_PORT + COM_DLH, 0x00
    OUTB COM1_PORT + COM_LCR, 0x03
    OUTB COM1_PORT + COM_FCR, 0xC7
    OUTB COM1_PORT + COM_MCR, 0x0B
%endmacro

%macro SERIAL_WAIT 0
%%.wait:
    INB COM1_PORT + COM_LSR, al
    test al, 0x20
    jz %%.wait
%endmacro

%macro SERIAL_PUTCHAR 1
    push rax
    SERIAL_WAIT
    OUTB COM1_PORT, %1
    pop rax
%endmacro

%macro SERIAL_PRINT_STRING 2
    push rax
    push rcx
    push rdi

    mov rdi, %1
    mov cl, %2

%%.next_char:
    test cl, cl
    jz %%.done
    mov al, [rdi]
    SERIAL_PUTCHAR al
    inc rdi
    dec cl
    jmp %%.next_char

%%.done:
    pop rdi
    pop rcx
    pop rax
%endmacro

; ------------------------------------------
; Utility macros
; ------------------------------------------

%macro ALIGN 1
    align %1
%endmacro

%macro KERNEL_ENTRY 0
    [bits 64]
%endmacro

%macro BOOT_ENTRY 0
    [bits 32]
%endmacro

%macro ZERO_BSS 2
    mov rdi, %1
    mov rcx, %2
    xor rax, rax
    rep stosb
%endmacro

%macro MEMCPY 3
    push rsi
    push rdi
    push rcx

    mov rsi, %1
    mov rdi, %2
    mov rcx, %3
    rep movsb

    pop rcx
    pop rdi
    pop rsi
%endmacro

%macro MEMSET 3
    push rdi
    push rcx

    mov rdi, %1
    mov al, %2
    mov rcx, %3
    rep stosb

    pop rcx
    pop rdi
%endmacro
