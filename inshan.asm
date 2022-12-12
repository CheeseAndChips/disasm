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
        and al, 0xfe

        cmp al, 0x04
        jz .handle_imm_acc

        and al, 0xfc
        cmp al, 0x00
        jz .handle_reg_mem

        cmp al, 0x80
        jz .handle_imm_reg_mem

        stc
        pop ax
        ret

        .handle_reg_mem:
            pop ax

            jmp .finished

        .handle_imm_reg_mem:
            pop ax
            mov ah, al
            call readByte

            call procDecodeModRM

            ; and ah, 0x3
            ; cmp ah, 0x1
            ; jz .sw_01

            ; cmp ah, 0x3
            ; jz .sw_11

            ; cmp ah, 0x00
            ; jz .sw_00

            ; .sw_01:
            
            ; mov di, cx
            

            ; .sw_11:

            ; .sw_00:

            jmp .finished

        .handle_imm_acc:
            pop ax

            test al, 1
            jz .handle_al
            macWriteStrAddrSize _AX, 2
            call readDataW
            call writeW
            jmp .finished
            .handle_al:
            macWriteStrAddrSize _AL, 2
            call readDataB
            call writeB
            jmp .finished

        .finished:
        ret

    ; ax - instructions
    ; di - output
    procDecodeModRM:
        mov di, dx
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
            mov dl, '-'
            call pushC
            .no_negative:
            call writeB
            jmp .post_data
        .post_data:

        macPushZero
        int 0x03
        pop ax
        push ax
        and al, 0xc0
        cmp al, 0x00 ; mod=00
        jz .mod_00

        cmp al, 0x40 ; mod=10
        jz .mod_01

        cmp al, 0x80
        jz .mod_10

        cmp al, 0xc0
        jz .mod_11

        .mod_00:

            ; pop ax
            ; and al, 0x07
            ; cmp al, 0x06
            ; jz .

        .mod_01:
            pop ax
            call readDataB
            test al, 0x80
            jnz .has_sign

            call writeW
            ret

            .has_sign:
            mov dl, '-'
            call pushC
            neg al
            call writeB
            neg al
            ret


        .mod_10: ; DISP
            pop ax
            mov dl, '['
            call pushC
            call readDataW
            call writeW
            mov dl, ']'
            call pushC
            ret
        .mod_11: ; register
            int 0x03
            pop ax
            and ah, 1
            shl ah, 3
            and al, 0x07
            or al, ah
            mov di, cx
            int 0x03
            call decodeRegister
            macPushZero
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