; =============================================================================
; disk.asm — BIOS Disk Read Routines (real mode)
; Uses INT 0x13 AH=0x42 (extended LBA read).
; =============================================================================

%ifndef DISK_ASM
%define DISK_ASM

    bits    16

disk_read:
    pusha

    mov     byte  [disk_dap.size],    0x10
    mov     byte  [disk_dap.reserved], 0x00
    mov     ax,   [disk_sectors]
    mov     word  [disk_dap.count],   ax
    mov     ax,   [disk_dest_off]
    mov     word  [disk_dap.offset],  ax
    mov     ax,   [disk_dest_seg]
    mov     word  [disk_dap.segment], ax
    mov     eax,  dword [disk_lba]
    mov     dword [disk_dap.lba_lo],  eax
    mov     eax,  dword [disk_lba + 4]
    mov     dword [disk_dap.lba_hi],  eax

    mov     si,  disk_dap
    mov     ah,  0x42
    int     0x13
    jc      .error

    popa
    clc
    ret

.error:
    popa
    mov     si, disk_err_msg
    call    print_str
    stc
    ret

disk_read_retry:
    pusha
    mov     cx, 3

.try:
    push    cx
    call    disk_read
    pop     cx
    jnc     .ok

    xor     ax, ax
    int     0x13
    loop    .try

    mov     si, disk_retry_fail_msg
    call    print_str
    popa
    stc
    ret

.ok:
    popa
    clc
    ret

align 4
disk_dap:
  .size     db  0x10
  .reserved db  0x00
  .count    dw  0
  .offset   dw  0
  .segment  dw  0
  .lba_lo   dd  0
  .lba_hi   dd  0

disk_lba        dq  0
disk_dest_seg   dw  0
disk_dest_off   dw  0
disk_sectors    dw  0

disk_err_msg        db  "ERR: Disk read error", 0x0D, 0x0A, 0
disk_retry_fail_msg db  "ERR: Disk read failed after retries", 0x0D, 0x0A, 0

%endif ; DISK_ASM
