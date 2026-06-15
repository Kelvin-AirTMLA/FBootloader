; =============================================================================
; boot.asm — Stage 1 Bootloader (MBR)
; Loaded by BIOS at 0x7C00, exactly 512 bytes.
; Responsibilities:
;   1. Set up segment registers and stack
;   2. Save BIOS drive number
;   3. Load Stage 2 from disk using INT 0x13 extended read (LBA)
;   4. Jump to Stage 2
; Assemble: nasm -f bin boot.asm -o boot.bin
; =============================================================================

    bits    16
    org     0x7C00

%include "header.asm"

; -----------------------------------------------------------------------------
; CONSTANTS
; -----------------------------------------------------------------------------
STAGE2_LOAD_SEG     equ 0x0000      ; segment where Stage 2 is loaded
STAGE2_LOAD_OFF     equ 0x7E00      ; offset  (right after MBR)
STAGE2_SECTORS      equ 16          ; number of 512-byte sectors to load
STAGE2_LBA_START    equ 1           ; LBA sector index of Stage 2 (0 = MBR)

STACK_SEG           equ 0x0000
STACK_TOP           equ 0x7C00      ; stack grows downward from MBR load addr

; =============================================================================
; ENTRY POINT
; =============================================================================
start:
    ; --- Normalise CS:IP to 0x0000:0x7C00 ---
    jmp     0x0000:.init

.init:
    cli                             ; disable interrupts while setting up

    ; --- Zero all segment registers ---
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     ss, ax
    mov     sp, STACK_TOP           ; stack just below us

    sti                             ; re-enable interrupts

    ; --- Save BIOS drive number (DL is set by BIOS) ---
    mov     [boot_drive], dl

    ; --- Print banner ---
    mov     si, msg_loading
    call    print_str

    ; --- Check INT 0x13 extensions (LBA support) ---
    mov     ah, 0x41
    mov     bx, 0x55AA
    mov     dl, [boot_drive]
    int     0x13
    jc      .no_ext                 ; CF set = not supported
    cmp     bx, 0xAA55
    jne     .no_ext
    jmp     .load_stage2

.no_ext:
    mov     si, msg_no_lba
    call    print_str
    jmp     halt

; --- Load Stage 2 using INT 0x13, AH=0x42 (extended read) ---
.load_stage2:
    mov     si, dap                 ; DS:SI → Disk Address Packet
    mov     dl, [boot_drive]
    mov     ah, 0x42
    int     0x13
    jc      .disk_error

    mov     si, msg_ok
    call    print_str

    ; --- Jump to Stage 2 ---
    mov     dl, [boot_drive]        ; pass drive number to Stage 2
    jmp     STAGE2_LOAD_SEG:STAGE2_LOAD_OFF

.disk_error:
    mov     si, msg_disk_err
    call    print_str
    jmp     halt

; =============================================================================
; SUBROUTINES
; =============================================================================

; print_str — prints null-terminated string pointed to by SI
print_str:
    pusha
.loop:
    lodsb
    test    al, al
    jz      .done
    mov     ah, 0x0E
    mov     bx, 0x0007
    int     0x10
    jmp     .loop
.done:
    popa
    ret

halt:
    cli
    hlt
    jmp     halt

; =============================================================================
; DATA
; =============================================================================
boot_drive  db  0

; Disk Address Packet for INT 0x13 AH=0x42
dap:
    db  0x10                        ; packet size (16 bytes)
    db  0x00                        ; reserved
    dw  STAGE2_SECTORS              ; number of sectors to read
    dw  STAGE2_LOAD_OFF             ; destination offset
    dw  STAGE2_LOAD_SEG             ; destination segment
    dq  STAGE2_LBA_START            ; LBA start sector (64-bit)

msg_loading db  "Loading Stage 2...", 0x0D, 0x0A, 0
msg_ok      db  "OK", 0x0D, 0x0A, 0
msg_no_lba  db  "ERR: No LBA support", 0x0D, 0x0A, 0
msg_disk_err db "ERR: Disk read failed", 0x0D, 0x0A, 0

; =============================================================================
; BOOT SIGNATURE — must be at bytes 510-511
; =============================================================================
    times   510 - ($ - $$) db 0    ; pad to 510 bytes
    dw      BOOT_MAGIC              ; 0xAA55
