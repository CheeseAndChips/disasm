%macro writeInstrName 0

%endmacro

section .data
    registers:
        _AL: db "AL"
        db "CL"
        db "DL"
        db "BL"
        _AH: db "AH"
        db "CH"
        db "DH"
        db "BH"
        _AX: db "AX"
        db "CX"
        db "DX"
        db "BX"
        db "SP"
        db "BP"
        db "SI"
        db "DI"


section .text
    procHandleMove:
        test al, 0x40
        jz .handle_imm
        
        macWriteStr "Failed decoding move", crlf
        macExitProgram

        .handle_imm:
            macWriteStrAddr word [bx+2]
            macWriteStr " "

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
        macExitProgram

        .handle_reg_mem:

        .handle_imm_reg_mem:

        .handle_imm_acc:
            macWriteStr "Decoding imm acc", crlf
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