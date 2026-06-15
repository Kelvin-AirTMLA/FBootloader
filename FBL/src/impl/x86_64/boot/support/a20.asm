; =============================================================================
; a20.asm — A20 Line Enable
; =============================================================================

    bits    16

%ifndef A20_ASM
%define A20_ASM

a20_enable:
    mov     ax, 0x2403
    int     0x15
    jb      .try_port92
    cmp     ah, 0
    jnz     .try_port92

    mov     ax, 0x2401
    int     0x15
    jb      .try_port92
    cmp     ah, 0
    jnz     .try_port92

    call    a20_check
    jnz     .done

.try_port92:
    in      al, 0x92
    test    al, 0x02
    jnz     .check_port92
    or      al, 0x02
    and     al, 0xFE
    out     0x92, al

.check_port92:
    call    a20_check
    jnz     .done

    call    kbc_wait_input
    mov     al, 0xAD
    out     0x64, al

    call    kbc_wait_input
    mov     al, 0xD0
    out     0x64, al

    call    kbc_wait_output
    in      al, 0x60
    push    ax

    call    kbc_wait_input
    mov     al, 0xD1
    out     0x64, al

    call    kbc_wait_input
    pop     ax
    or      al, 0x02
    out     0x60, al

    call    kbc_wait_input
    mov     al, 0xAE
    out     0x64, al

    call    kbc_wait_input

    call    a20_check
    jnz     .done

    mov     si, .msg_fail
    call    print_str
    cli
    hlt

.done:
    ret

.msg_fail   db  "ERR: A20 enable failed", 0x0D, 0x0A, 0

a20_check:
    pushf
    push    ds
    push    es
    push    di
    push    si

    cli

    xor     ax, ax
    mov     es, ax
    mov     di, 0x0500

    mov     ax, 0xFFFF
    mov     ds, ax
    mov     si, 0x0510

    mov     al, byte [es:di]
    push    ax
    mov     al, byte [ds:si]
    push    ax

    mov     byte [es:di], 0x00
    mov     byte [ds:si], 0xFF

    cmp     byte [es:di], 0xFF

    pop     ax
    mov     byte [ds:si], al
    pop     ax
    mov     byte [es:di], al

    pop     si
    pop     di
    pop     es
    pop     ds
    popf

    je      .disabled
    mov     ax, 1
    ret
.disabled:
    xor     ax, ax
    ret

kbc_wait_input:
    in      al, 0x64
    test    al, 0x02
    jnz     kbc_wait_input
    ret

kbc_wait_output:
    in      al, 0x64
    test    al, 0x01
    jz      kbc_wait_output
    ret

%endif ; A20_ASM
