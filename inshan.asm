%macro writeInstrName 0

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
        
        macWriteStr "Failed decoding move", crlf
        call exitProgram

        .handle_imm:
            macFWriteStrAddr word [bx+2]
            ;macWriteStrAddr word [bx+2] ; write instruction
            ;macWriteStr " "

            push ax
            and ax, 0x0f
            call decodeRegister
            pop ax

            test al, 0x08
            jz .data_byte
                call readDataW
                call writeW
                jmp .finished
            .data_byte:
                call readDataB
                call writeB
            jmp .finished

        .finished:
        ret

    procHandleAdd:
        test al, 0xfc
        jz .handle_reg_mem

        test al, 0x7c
        jz .handle_imm_reg_mem

        test al, 0xfa
        jz .handle_imm_acc

        macWriteStr "Failed decoding add", crlf
        call exitProgram

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

        ret

    decodeRegister:
        push ax
        push bx

        mov bx, registers
        shl ax, 1
        add bx, ax
        macWriteStrAddrSize bx, 2

        pop bx
        pop ax

        ret

    readDataB:
        call readByte
        ret

    readDataW:
        push bx
        call readByte
        mov bx, ax
        call readByte
        mov bh, al
        pop bx
        ret