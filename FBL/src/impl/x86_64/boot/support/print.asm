; =============================================================================
; print.asm — Early BIOS Print Routines (real mode)
; Uses INT 0x10 (BIOS video services).
; %include from boot.asm or stage2.asm.
; =============================================================================

%ifndef PRINT_ASM
%define PRINT_ASM

    bits    16

; =============================================================================
; print_str — print null-terminated string
; In:  SI → string
; =============================================================================
print_str:
    pusha
.loop:
    lodsb
    test    al, al
    jz      .done
    mov     ah, 0x0E
    mov     bx, 0x0007              ; page 0, white on black
    int     0x10
    jmp     .loop
.done:
    popa
    ret

; =============================================================================
; print_char — print single character in AL
; =============================================================================
print_char:
    pusha
    mov     ah, 0x0E
    mov     bx, 0x0007
    int     0x10
    popa
    ret

; =============================================================================
; print_newline — print CR+LF
; =============================================================================
print_newline:
    pusha
    mov     al, 0x0D
    call    print_char
    mov     al, 0x0A
    call    print_char
    popa
    ret

; =============================================================================
; print_hex16 — print AX as 4 hex digits (e.g. "0x1A2B")
; =============================================================================
print_hex16:
    pusha
    mov     si, hex_prefix
    call    print_str

    mov     cx, 4                   ; 4 nibbles
.loop:
    rol     ax, 4                   ; rotate high nibble into low
    mov     bx, ax
    and     bx, 0x000F
    mov     bl, byte [hex_chars + bx]
    push    ax
    mov     al, bl
    call    print_char
    pop     ax
    loop    .loop

    popa
    ret

; =============================================================================
; print_hex32 — print EAX as 8 hex digits
; =============================================================================
print_hex32:
    pusha
    mov     si, hex_prefix
    call    print_str

    mov     cx, 8
.loop:
    rol     eax, 4
    mov     ebx, eax
    and     ebx, 0x0000000F
    mov     bl, byte [hex_chars + ebx]
    push    eax
    mov     al, bl
    call    print_char
    pop     eax
    loop    .loop

    popa
    ret

; =============================================================================
; DATA
; =============================================================================
hex_chars   db  "0123456789ABCDEF"
hex_prefix  db  "0x", 0

%endif ; PRINT_ASM
