%macro macPushZero 0
    push dx
    mov dl, 0
    call pushC
    pop dx
%endmacro

section .data
    registers:
        _AL: db "AL"
        _CL: db "CL"
        _DL: db "DL"
        _BL: db "BL"
        _AH: db "AH"
        _CH: db "CH"
        _DH: db "DH"
        _BH: db "BH"
        _AX: db "AX"
        _CX: db "CX"
        _DX: db "DX"
        _BX: db "BX"
        _SP: db "SP"
        _BP: db "BP"
        _SI: db "SI"
        _DI: db "DI"

    _BX_SI_DISP: db "BX+SI+", 0
    _BX_DI_DISP: db "BX+DI+", 0
    _BP_SI_DISP: db "BP+SI+", 0
    _BP_DI_DISP: db "BP+DI+", 0
    _SI_DISP: db "SI+", 0
    _DI_DISP: db "DI+", 0
    _BP_DISP: db "BP+", 0
    _BX_DISP: db "BX+", 0


    rm_table:
        dw _BX_SI_DISP
        dw _BX_DI_DISP
        dw _BP_SI_DISP
        dw _BP_DI_DISP
        dw _SI_DISP
        dw _DI_DISP
        dw _BP_DISP
        dw _BX_DISP
        


section .text
    procHandleMove:
        mov bx, word [bx+2]

        test al, 0x40 ; todo fix
        jz .handle_imm
        
        
        stc
        ret

        .handle_imm:
            push ax
            and ax, 0x0f
            mov di, cx
            call decodeRegister
            macPushZero
            pop ax

            mov di, dx
            test al, 0x08
            jz .data_byte
                call readDataW
                call writeW
                jmp .noelse
            .data_byte:
                call readDataB
                call writeB
            .noelse:
            macPushZero
            jmp .finished

        .finished:
        ret

    procHandleAdd:
        mov bx, word [bx+2]

        push ax

        test al, 0x04
        jnz .handle_imm_acc

        test al, 0x80
        jnz .handle_imm_reg_mem

        jmp .handle_reg_mem

        stc
        pop ax
        ret

        .handle_reg_mem:
            pop ax
            mov ah, al
            call readByte
            push ax

            mov di, cx
            call procDecodeModRM
            mov di, dx
            and al, 0x38
            shr al, 3
            and ah, 1
            shl ah, 3
            or al, ah
            call decodeRegister
            macPushZero

            pop ax
            and ah, 0x02
            jz .finished
            xchg cx, dx
            jmp .finished

        .handle_imm_reg_mem:
            pop ax
            mov ah, al
            call readByte
            mov di, cx
            call procDecodeModRM
            mov di, dx
            call procGetData

            jmp .finished

        .handle_imm_acc:
            pop ax

            test al, 1
            jz .handle_al
                mov dx, word [_AX]
                mov di, cx
                call pushC
                mov dl, dh
                call pushC
                macPushZero
                mov di, dx
                call readDataW
                call writeW
                macPushZero
                jmp .finished
            .handle_al:
                mov dx, word [_AL]
                mov di, cx
                call pushC
                mov dl, dh
                call pushC
                mov di, dx
                macPushZero
                call readDataB
                call writeB
                macPushZero
                jmp .finished

        .finished:
        ret

    ; ax - instructions
    ; di - output
    procDecodeModRM:
        push bp
        sub sp, 2
        mov bp, sp
        mov word [bp], ax

        and al, 0xc0
        cmp al, 0xc0
        jz .mod_11

        push dx
        mov dl, '['
        call pushC
        pop dx

        cmp al, 0x00
        jne .decode_rm
        mov ax, [bp]
        and al, 0x7
        cmp al, 0x6
        jne .decode_rm

        jmp .skip_rm

        .decode_rm:
        mov ax, [bp]
        call getRMTable
        call pushArr

        .skip_rm:
        mov ax, [bp]
        and al, 0xc0
        cmp al, 0x00
        je .mod_00

        cmp al, 0x40
        je .mod_01

        cmp al, 0x80
        je .mod_10

        .mod_00:
            mov ax, [bp]
            and al, 0x7
            cmp al, 0x6
            jnz .skip_read

            call readDataW
            call writeW
            inc di

            .skip_read:
            dec di
            jmp .post_mod

        .mod_01:
            call readDataB
            test al, 0x80
            jnz .has_sign

            call writeB
            jmp .post_mod

            .has_sign:
            dec di
            mov dl, '-'
            call pushC
            neg al
            call writeB
            jmp .post_mod
        .mod_10:
            call readDataW
            call writeW  
            jmp .post_mod
        .mod_11: ; register
            mov ax, [bp]
            and ah, 1
            shl ah, 3
            and al, 0x07
            or al, ah
            call decodeRegister
            jmp .post_brackets

        .post_mod:
        push dx
        mov dl, ']'
        call pushC
        pop dx
        .post_brackets:
        macPushZero
        mov ax, [bp]
        add sp, 2
        pop bp
        ret

    procGetData:
        push ax
        
        and ah, 0x03
        cmp ah, 0x01
        jz .dataw
        cmp ah, 0x00
        jz .datab
        cmp ah, 0x03
        jz .datasb
        
        .dataw:
            call readDataW
            call writeW
            jmp .post_data

        .datab:
            call readDataB
            call writeB
            jmp .post_data

        .datasb:
            call readDataB
            cmp al, 0x80
            jnz .no_negative
            neg al
            push dx
            mov dl, '-'
            call pushC
            pop dx
            .no_negative:
            call writeB
            jmp .post_data
        
        .post_data:
        macPushZero
        pop ax
        ret

    procHandleSingleByte:
        xor cx, cx
        xor dx, dx
        mov bx, word [bx+2]
        ret

    decodeRegister:
        push ax
        push bx
        push cx

        mov bx, registers
        and ax, 0xf
        shl ax, 1
        add bx, ax

        mov cx, word [bx]
        mov word[di], cx

        add di, 2

        pop cx
        pop bx
        pop ax

        ret

    getRMTable:
        push ax
        push bx
        xor ah, ah
        and al, 0x7
        shl al, 1
        add ax, rm_table
        mov bx, ax
        mov si, [bx]
        pop bx
        pop ax
        ret

    readDataB:
        call readByte
        ret

    readDataW:
        push bx
        call readByte
        mov bl, al
        call readByte
        mov bh, al
        mov ax, bx
        pop bx
        ret