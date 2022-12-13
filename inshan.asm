%macro macPushZero 0
    push dx
    mov dl, 0
    call pushC
    pop dx
%endmacro

%macro macModEntry 2
    cmp al, (%1 << 3)
    jnz %%skip
    mov bx, %2
    jmp .label_assigned
    %%skip:
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
        


section .text
    procHandleMovRM:
        mov bx, word [bx+2]

        mov ah, al
        call readByte
        
        mov di, cx
        push ax
        shr al, 3
        and al, 0x7
        and ah, 1
        shl ah, 3
        or al, ah
        call decodeRegister
        macPushZero
        pop ax

        mov di, dx
        call procDecodeModRM
        macPushZero

        test ah, 2
        jnz .skip_swap
        xchg cx, dx
        .skip_swap:

        ret

    procHandleMovImmRM:
        mov bx, word [bx+2]

        mov ah, al
        call readByte

        mov di, cx
        call procDecodeModRM
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

        ret

    procHandleMovImmReg:
        mov bx, word [bx+2]

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

        ret

    procHandleMovMemAX:
        mov bx, word [bx+2]

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

        ret

    procHandleMovSegReg:
        mov bx, word [bx+2]
        
        mov ah, al
        call readByte

        mov di, cx
        call procDecodeModRM
        macPushZero

        push ax
        push bx
        mov di, dx
        shr al, 2
        and al, 0x6
        xor ah, ah
        add ax, segregisters
        mov bx, ax
        mov ax, word [bx]
        mov word [di], ax
        add di, 2
        macPushZero
        pop bx
        pop ax

        test ah, 2
        jz .skip_swap
        xchg cx, dx
        .skip_swap:
        ret

    procHandleLogic:
        mov ah, al
        call readByte

        mov di, cx
        call procDecodeModRM
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
        ret

    procHandleTestRMReg:
        mov bx, word [bx+2]

        mov ah, al
        call readByte
        
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

        ret

    procHandleTestImmRM:
        mov di, cx
        call procDecodeModRM
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

        ret

    procHandleDispJump:
        mov bx, word [bx+2]

        mov ah, al
        call readByte
        cbw

        add ax, word [currentbyte]
        call addBytesRead

        mov di, cx
        call writeW
        macPushZero

        xor dx, dx
        ret
        
    procHandleMul:
        mov ah, al
        call readByte

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
            
            stc
            xor dx, dx
            pop ax
            ret
        .label_assigned:
        pop ax

        mov di, cx
        call procDecodeModRM
        macPushZero

        xor dx, dx
        ret

    procHandleDirect:
        mov bx, word [bx+2]
        mov di, cx
        call readDataW

        add ax, word [currentbyte]
        call addBytesRead

        call writeW
        macPushZero
        xor dx, dx
        ret

    procHandleIndirect:
        mov bx, word [bx+2]
        mov ah, al
        call readByte

        mov di, cx

        test al, 0x08
        jz .skip_far_write
        mov si, _FAR
        call pushArr
        .skip_far_write:

        call procDecodeModRM

        macPushZero

        xor dx, dx
        ret



    procHandleIntersegment:
        mov bx, word [bx+2]
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
        xor dx, dx
        ret

    procHandleRetAdd:
        mov bx, word [bx+2]

        mov di, cx
        call readDataW
        call writeW
        macPushZero

        xor dx, dx
        ret

    procHandleInt:
        mov bx, word [bx+2]
        
        mov di, cx
        call readDataB
        call writeB
        macPushZero

        xor dx, dx
        ret

    procHandleInt3:
        mov bx, word [bx+2]
        
        mov di, cx
        mov al, 0x03
        call writeB
        macPushZero

        xor dx, dx
        ret
    
    procHandleImmAcc:
        mov bx, word [bx+2]

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
            ret
        .handle_al:
            mov dx, word [_AL]
            mov di, cx
            call pushC
            mov dl, dh
            call pushC
            macPushZero
            mov di, dx
            call readDataB
            call writeB
            macPushZero
            ret

    procHandleImmRegMem:
        mov ah, al
        call readByte
        
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

            stc
            ret

            .label_assigned:
        pop ax

        mov di, cx
        call procDecodeModRM
        mov di, dx
        call procGetData
        ret

    procHandleRegMem:
        mov bx, word [bx+2]

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