; =============================================================================
; stage2.asm — Stage 2 Bootloader
; Loaded by Stage 1 at 0x0000:0x7E00.
; Responsibilities:
;   1. Print banner (still in real mode)
;   2. Enable A20
;   3. Load kernel from disk into high memory (0x100000)
;   4. Switch to 32-bit protected mode
;   5. Set up identity-mapped page tables for 64-bit long mode
;   6. Switch to 64-bit long mode
;   7. Jump to kernel entry point
;
; Assemble: nasm -f bin stage2.asm -o stage2.bin
; =============================================================================

    bits    16
    org     0x7E00

%include "header.asm"
%include "print.asm"
%include "disk.asm"
%include "a20.asm"
%include "gdt.asm"

; -----------------------------------------------------------------------------
; KERNEL LOAD CONSTANTS
; -----------------------------------------------------------------------------
KERNEL_LBA_START    equ 17          ; LBA sector right after Stage 2
KERNEL_SECTORS      equ 64          ; 64 × 512 = 32 KB max kernel size
KERNEL_LOAD_SEG     equ 0x1000      ; temporary: 0x1000:0x0000 = 0x10000
KERNEL_LOAD_OFF     equ 0x0000
KERNEL_PHYS_ADDR    equ 0x00100000  ; final kernel location: 1 MB mark

; Page table base addresses (identity map first 2 MB)
PML4_ADDR           equ 0x1000      ; PML4  at physical 0x1000
PDPT_ADDR           equ 0x2000      ; PDPT  at physical 0x2000
PD_ADDR             equ 0x3000      ; PD    at physical 0x3000

; =============================================================================
; REAL MODE ENTRY
; =============================================================================
stage2_start:
    ; Segment setup (we're at 0x0000:0x7E00)
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, 0x7C00              ; stack below Stage 1

    ; Save drive number passed in DL by Stage 1
    mov     [boot_drive], dl

    mov     si, msg_stage2
    call    print_str

    ; -------------------------------------------------------------------------
    ; 1. Enable A20
    ; -------------------------------------------------------------------------
    mov     si, msg_a20
    call    print_str
    call    a20_enable
    mov     si, msg_ok
    call    print_str

    ; -------------------------------------------------------------------------
    ; 2. Load kernel from disk into 0x1000:0x0000 (physical 0x10000)
    ; -------------------------------------------------------------------------
    mov     si, msg_kernel
    call    print_str

    ; Enter "unreal mode" so we can write above 1 MB with 32-bit registers
    call    enter_unreal

    ; Set disk read parameters
    mov     word  [disk_sectors],   KERNEL_SECTORS
    mov     word  [disk_dest_seg],  KERNEL_LOAD_SEG
    mov     word  [disk_dest_off],  KERNEL_LOAD_OFF
    mov     dword [disk_lba],       KERNEL_LBA_START
    mov     dword [disk_lba + 4],   0
    mov     dl,   [boot_drive]
    call    disk_read_retry
    jc      .disk_fail

    mov     si, msg_ok
    call    print_str
    jmp     .setup_paging

.disk_fail:
    mov     si, msg_kernel_fail
    call    print_str
    cli
    hlt

    ; -------------------------------------------------------------------------
    ; 3. Set up identity-mapped page tables (first 2 MB using 2 MB huge page)
    ; -------------------------------------------------------------------------
.setup_paging:
    mov     si, msg_paging
    call    print_str

    ; Zero out page table area (3 × 4096 = 12 KB at PML4_ADDR)
    mov     edi, PML4_ADDR
    mov     ecx, (3 * 4096) / 4
    xor     eax, eax
    rep     stosd

    ; PML4[0] → PDPT
    mov     eax, PDPT_ADDR
    or      eax, 0x03               ; present + writable
    mov     dword [PML4_ADDR], eax
    mov     dword [PML4_ADDR + 4], 0

    ; PDPT[0] → PD
    mov     eax, PD_ADDR
    or      eax, 0x03
    mov     dword [PDPT_ADDR], eax
    mov     dword [PDPT_ADDR + 4], 0

    ; PD[0] → 2 MB huge page at physical 0x000000
    mov     dword [PD_ADDR], 0x00000083     ; present | writable | huge
    mov     dword [PD_ADDR + 4], 0

    mov     si, msg_ok
    call    print_str

    ; -------------------------------------------------------------------------
    ; 4. Switch to 32-bit protected mode
    ; -------------------------------------------------------------------------
    cli
    lgdt    [gdt32_descriptor]

    mov     eax, cr0
    or      eax, 1                  ; PE bit
    mov     cr0, eax

    jmp     GDT32_CODE_SEL:.pm32   ; far jump flushes pipeline, loads CS

; =============================================================================
; 32-BIT PROTECTED MODE
; =============================================================================
    bits    32
.pm32:
    mov     ax, GDT32_DATA_SEL
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     ss, ax
    mov     esp, 0x90000            ; protected mode stack

    ; -------------------------------------------------------------------------
    ; 5. Enable PAE (required for long mode)
    ; -------------------------------------------------------------------------
    mov     eax, cr4
    or      eax, (1 << 5)          ; PAE bit
    mov     cr4, eax

    ; Load PML4 address into CR3
    mov     eax, PML4_ADDR
    mov     cr3, eax

    ; -------------------------------------------------------------------------
    ; 6. Enable long mode in EFER MSR
    ; -------------------------------------------------------------------------
    mov     ecx, 0xC0000080         ; EFER MSR
    rdmsr
    or      eax, (1 << 8)          ; LME bit
    wrmsr

    ; -------------------------------------------------------------------------
    ; 7. Enable paging (activates long mode since LME is set)
    ; -------------------------------------------------------------------------
    mov     eax, cr0
    or      eax, (1 << 31)         ; PG bit
    mov     cr0, eax

    ; Far jump into 64-bit code segment
    jmp     GDT64_CODE_SEL:.lm64

; =============================================================================
; 64-BIT LONG MODE
; =============================================================================
    bits    64
.lm64:
    mov     ax, GDT64_DATA_SEL
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     ss, ax
    mov     rsp, 0x200000           ; 2 MB stack (below kernel load)

    ; Jump to kernel entry point (loaded at physical 0x10000)
    mov     rax, 0x10000
    jmp     rax

    cli
    hlt

; =============================================================================
; UNREAL MODE — expands DS limit to 4 GB while staying in real mode
; =============================================================================
    bits    16
enter_unreal:
    push    eax
    push    ds

    lgdt    [gdt32_descriptor]

    mov     eax, cr0
    or      al, 1                   ; PE=1
    mov     cr0, eax

    mov     bx, GDT32_DATA_SEL
    mov     ds, bx

    and     al, 0xFE                ; PE=0 (back to real mode)
    mov     cr0, eax

    pop     ds
    pop     eax
    ret

; =============================================================================
; DATA
; =============================================================================
    bits    16

boot_drive  db  0

msg_stage2      db  "Stage 2 loaded", 0x0D, 0x0A, 0
msg_a20         db  "Enabling A20...", 0
msg_kernel      db  "Loading kernel...", 0
msg_paging      db  "Setting up paging...", 0
msg_ok          db  " OK", 0x0D, 0x0A, 0
msg_kernel_fail db  "ERR: Kernel load failed", 0x0D, 0x0A, 0
