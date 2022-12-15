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

    segregisters:
        _ES: db "ES"
        _CS: db "CS"
        _SS: db "SS"
        _DS: db "DS"

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

    _FAR: db "FAR ", 0

    _WORDPTR: db "WORD PTR ", 0
    _BYTEPTR: db "BYTE PTR ", 0

    _UNUSED: db "(unused)", 0

    _REP_ALLOWED_INSTR:
        db 0xa4 ; MOVSB
        db 0xa5 ; MOVSW
        db 0xa6 ; CMPSB
        db 0xa7 ; CMPSW
        db 0xaa ; STOSB
        db 0xab ; STOSW
        db 0xac ; LODSB
        db 0xad ; LODSW
        db 0xae ; SCASB
        db 0xaf ; SCASW
    _REP_TABLE_LEN equ $-_REP_ALLOWED_INSTR

section .text
    procHandleMovImmRM:
        macReadSecondByte

        mov di, cx
        call procDecodeModRMPtr
        macPushZero

        mov di, dx
        test ah, 1
        jnz .dataW
            call readDataB
            call writeB
            jmp .done
        .dataW:
            call readDataW
            call writeW

        .done:
        macPushZero

        macReturnTwoArg

    procHandleMovImmReg:
        mov di, cx
        call decodeRegister
        macPushZero

        mov di, dx
        test al, 0x08
        jnz .dataW
            call readDataB
            call writeB
            jmp .done
        .dataW:
            call readDataW
            call writeW

        .done:
        macPushZero
        
        macReturnTwoArg

    procHandleMovMemAX:
        test al, 0x01
        mov di, cx
        jnz .dataW
            mov si, _AL
            jmp .done
        .dataW:
            mov si, _AX
        .done:
        push ax
        mov ax, word [si]
        mov word [di], ax
        pop ax
        add di, 2
        macPushZero

        mov di, dx
        push dx

            mov dl, '['
            call pushC
            call readDataW
            call writeW
            mov dl, ']'
            call pushC

        pop dx
        macPushZero

        test al, 2
        jz .skip_swap
        xchg cx, dx
        .skip_swap:

        macReturnTwoArg

    procHandleMovSegReg:
        macReadSecondByte

        mov di, cx
        or ah, 1
        call procDecodeModRMPtr
        macPushZero

        mov di, dx
        push ax
        shr al, 3
        call decodeSegRegister
        pop ax

        test ah, 2
        jz .skip_swap
        xchg cx, dx
        .skip_swap:
        macReturnTwoArg

    procHandleLogic:
        macReadSecondByte

        mov di, cx
        call procDecodeModRMPtr
        macPushZero

        mov di, dx
        test ah, 2
        jz .write1
            push ax
            mov ax, [_CL]
            mov word [di], ax
            add di, 2
            pop ax
            jmp .done
        .write1:
            push dx
            mov dl, '1'
            call pushC
            pop dx
        .done:       
        macPushZero

        push ax
            and al, 00111000b

            macModEntry 100b, _SHL
            macModEntry 101b, _SHR
            macModEntry 111b, _SAR
            macModEntry 000b, _ROL
            macModEntry 001b, _ROR
            macModEntry 010b, _RCL
            macModEntry 011b, _RCR

            stc
            
        .label_assigned:
        pop ax
        macReturnTwoArg

    procHandleTestRMReg:
        macReadSecondByte
        
        mov di, cx
        call procDecodeModRM
        macPushZero

        mov di, dx
        and ah, 1
        shl ah, 3
        shr al, 3
        and al, 0x7
        or al, ah
        call decodeRegister
        macPushZero

        macReturnTwoArg

    procHandleTestImmRM:
        mov di, cx
        call procDecodeModRMPtr
        macPushZero

        mov di, dx

        test ah, 1
        jz .dataB
            call readDataW
            call writeW
            jmp .done
        .dataB:
            call readDataB
            call writeB
        .done:
        macPushZero

        macReturnTwoArg

    procHandleDispJump:
        macReadSecondByte
        cbw

        add ax, word [CURRENTBYTE]
        call addBytesRead

        mov di, cx
        call writeW
        macPushZero

        macReturnOneArg
        
    procHandleSegReg:
        shr al, 3
        mov di, cx
        call decodeSegRegister
        macReturnOneArg
    
    procHandleModRMTwoByte:
        mov di, cx
        call procDecodeModRMPtr
        macPushZero

        macReturnOneArg

    procHandlePopRM:
        macReadSecondByte
        test al, 111b << 3
        jz .mod_ok
        stc
        ret
        .mod_ok:
        call procHandleModRMTwoByte
        ret

    procHandleRegInstr:
        or al, 0x08
        mov di, cx
        call decodeRegister
        macReturnOneArg

    procHandleMul:
        macReadSecondByte
        push ax
            and al, 00111000b

            cmp al, (000b << 3)
            jnz .skip_test
                mov bx, _TEST
                pop ax
                call procHandleTestImmRM
                ret
            .skip_test:

            macModEntry 011b, _NEG
            macModEntry 100b, _MUL
            macModEntry 101b, _IMUL
            macModEntry 110b, _DIV
            macModEntry 111b, _IDIV
            macModEntry 010b, _NOT
            
            pop ax
            stc
            ret
        .label_assigned:
        pop ax

        call procHandleModRMTwoByte
        ret

    procHandleDirect:
        mov di, cx
        call readDataW

        add ax, word [CURRENTBYTE]
        call addBytesRead

        call writeW
        macPushZero
        macReturnOneArg

    procHandleIndirect:
        mov di, cx
        call procDecodeModRMPtr
        macPushZero
        macReturnOneArg

    procHandleIndirectIntersegment:
        mov di, cx
        mov si, _FAR
        call pushArr
        call procDecodeModRM
        macPushZero
        macReturnOneArg

    procHandleRegAcc:
        mov di, dx
        or al, 0x08
        call decodeRegister
        macPushZero

        mov di, cx
        mov ax, word [_AX]
        mov word [di], ax
        add di, 2
        macPushZero

        macReturnTwoArg

    procIOSwap:
        test al, 2
        jz .skip_swap
        xchg cx, dx
        .skip_swap:
        ret

    procHandleIOReg:
        push ax
        mov di, cx
        test al, 1
        jz .w0
            mov ax, word [_AX]
            jmp .done
        .w0:
            mov ax, word [_AL]
        .done:
        mov word [di], ax
        add di, 2
        macPushZero
        pop ax
        ret

    procHandleIOFixed:
        push ax
        call procHandleIOReg
        
        macReadSecondByte

        mov di, dx
        call writeB
        macPushZero
        pop ax
        call procIOSwap
        macReturnTwoArg

    procHandleIOVariable:
        push ax
        call procHandleIOReg
        mov di, dx
        mov ax, word [_DX]
        mov word [di], ax
        add di, 2
        macPushZero
        pop ax
        call procIOSwap
        macReturnTwoArg

    procHandleFF:
        macReadSecondByte

        push ax
            and al, 00111000b
        
            macModEntryCall 100b, _JMP, procHandleIndirect
            macModEntryCall 101b, _JMP, procHandleIndirectIntersegment
            macModEntryCall 010b, _CALL, procHandleIndirect
            macModEntryCall 011b, _CALL, procHandleIndirectIntersegment
            macModEntryCall 110b, _PUSH, procHandleModRMTwoByte

            pop ax
            stc
            ret
        .label_assigned:
        pop ax
        call di
        ret

    procHandleRep:
        macReadSecondByte

        push cx
        mov cx, _REP_TABLE_LEN
        mov si, _REP_ALLOWED_INSTR
        .l:
            cmp byte [si], al
            je .instr_found
            inc si
        loop .l
        pop cx
        mov si, _UNUSED
        jmp .return

        .instr_found:
        pop cx
        push bx
        xor bx, bx
        mov bl, al
        shl bx, 2
        add bx, instrDecodeTable
        mov si, [bx+2]
        pop bx

        .return:
        mov di, cx
        call pushArr
        macPushZero
        macReturnOneArg

    procHandleIntersegment:
        mov di, cx
        call readDataW
        push ax
        call readDataW
        call writeW
        mov dl, ':'
        call pushC
        pop ax
        call writeW
        macPushZero
        macReturnOneArg

    procHandleRetAdd:
        mov di, cx
        call readDataW
        call writeW
        macPushZero
        macReturnOneArg

    procHandleInt:
        mov di, cx
        call readDataB
        call writeB
        macPushZero
        macReturnOneArg

    procHandleInt3:
        mov di, cx
        mov dl, '3'
        call pushC
        macPushZero
        macReturnOneArg
    
    procHandleImmAcc:
        mov di, dx
        push dx
        test al, 1
        jz .handle_al
            mov dx, word [_AX]
            call readDataW
            call writeW
            jmp .postif
        .handle_al:
            mov dx, word [_AL]
            call readDataB
            call writeB
        .postif:
        macPushZero
        mov di, cx
        call pushC
        mov dl, dh
        call pushC
        macPushZero
        pop dx
        macReturnTwoArg

    procHandleImmRegMem:
        macReadSecondByte
        
        push ax
            and al, 00111000b
        
            macModEntry 000b, _ADD
            macModEntry 010b, _ADC
            macModEntry 101b, _SUB
            macModEntry 011b, _SBB
            macModEntry 111b, _CMP
            macModEntry 100b, _AND
            macModEntry 001b, _OR
            macModEntry 110b, _XOR
            .label_assigned:
        pop ax

        mov di, cx
        call procDecodeModRMPtr
        mov di, dx
        call procGetData
        macReturnTwoArg

    procHandleRegMem:
        macReadSecondByte
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
        .finished:
        macReturnTwoArg

    procHandleSingleByte:
        macReturnNoArg

    procDecodeModRMPtr:
        push ax
        and al, 0xc0
        cmp al, 0xc0
        pop ax
        je .start_decode ; mod 11 => register

        push si
        test ah, 1
        jnz .dataW
            mov si, _BYTEPTR
            jmp .writeptr
        .dataW:
            mov si, _WORDPTR
        .writeptr:
        call pushArr
        pop si

        .start_decode:
        call procDecodeModRM
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
        mov ax, word [bp]
        je .mod_11

        push dx
        mov dl, '['
        call pushC
        pop dx

        test al, 0xc0
        jnz .decode_rm
        mov ax, [bp]
        and al, 0x7
        cmp al, 0x6
        je .skip_rm

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
            push dx
            jnz .no_negative
                neg al
                mov dl, '-'
                jmp .write
            .no_negative:
                mov dl, '+'
            .write:
            call pushC
            pop dx
            call writeB
            jmp .post_data
        
        .post_data:
        macPushZero
        pop ax
        ret

    decodeSegRegister:
        push ax
        push bx
        and ax, 0x0003
        shl al, 1

        add ax, segregisters
        mov bx, ax
        mov ax, word [bx]
        mov word [di], ax
        add di, 2
        macPushZero
        pop bx
        pop ax

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
        macReadByteWithCheck
        ret

    readDataW:
        push bx
        macReadByteWithCheck
        mov bl, al
        macReadByteWithCheck
        mov bh, al
        mov ax, bx
        pop bx
        ret