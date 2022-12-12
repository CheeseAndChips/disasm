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
        test al, 0x40
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
                int 0x03
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
        mov bx, word [bx+2]
        ret

    procHandleAdd:
        test al, 0xfc
        jz .handle_reg_mem

        test al, 0x7c
        jz .handle_imm_reg_mem

        test al, 0xfa
        jz .handle_imm_acc

        stc
        ret

        .handle_reg_mem:

        .handle_imm_reg_mem:

        .handle_imm_acc:
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