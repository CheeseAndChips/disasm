section .data
    _REGISTERS:
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

    _SEGREGISTERS:
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
; -------------------------
;   instruction decoding
; -------------------------

    ; single byte, no operands
    procHandleSingleByte:
        macReturnNoArg

    ; move immediate to register/memory
    procHandleMovImmRM:
        macReadSecondByte

        mov di, cx
        call procDecodeModRMPtr

        mov di, dx
        test ah, 1
        call procWriteDataByFlag
        .done:
        macReturnTwoArg

    ; move immediate to register
    procHandleMovImmReg:
        mov di, cx
        call procDecodeRegister

        mov di, dx
        test al, 0x08
        call procWriteDataByFlag
        .done:
        macReturnTwoArg

    ; reads from file and writes to output byte or word
    ; according to zero flag
    procWriteDataByFlag:
        jnz .dataW
            call procReadDataB
            call procWriteB
            ret
        .dataW:
            call procReadDataW
            call procWriteW
            ret

    ; move memory to/from accumulator
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

        mov di, dx
        push dx

            mov dl, '['
            call procPushC
            call procReadDataW
            call procWriteW
            mov dl, ']'
            call procPushC

        pop dx

        test al, 2
        jz .skip_swap
        xchg cx, dx
        .skip_swap:

        macReturnTwoArg

    ; move to/from segment register
    procHandleMovSegReg:
        macReadSecondByte

        mov di, cx
        or ah, 1
        call procDecodeModRMPtr

        mov di, dx
        push ax
        shr al, 3
        call procDecodeSegRegister
        pop ax

        test ah, 2
        jz .skip_swap
        xchg cx, dx
        .skip_swap:
        macReturnTwoArg

    ; shl/shr/sar/rol/ror/rcl/rcr
    procHandleLogic:
        macReadSecondByte

        mov di, cx
        call procDecodeModRMPtr

        mov di, dx
        test ah, 2
        jz .write1
            push ax
            mov ax, [_CL]
            mov word [di], ax
            pop ax
            jmp .done
        .write1:
            push dx
            mov dl, '1'
            call procPushC
            pop dx
        .done:

        push ax
            and al, 00111000b

            macModEntry 100b, _SHL
            macModEntry 101b, _SHR
            macModEntry 111b, _SAR
            macModEntry 000b, _ROL
            macModEntry 001b, _ROR
            macModEntry 010b, _RCL
            macModEntry 011b, _RCR

            xor bx, bx
            
        .label_assigned:
        pop ax
        macReturnTwoArg

    ; test register/memory with register
    procHandleTestRMReg:
        macReadSecondByte
        
        mov di, cx
        call procDecodeModRM

        mov di, dx
        and ah, 1
        shl ah, 3
        shr al, 3
        and al, 0x7
        or al, ah
        call procDecodeRegister

        macReturnTwoArg

    ; test register/memory with immediate
    procHandleTestImmRM:
        mov di, cx
        call procDecodeModRMPtr

        mov di, dx

        test ah, 1
        call procWriteDataByFlag
        macReturnTwoArg

    ; jump with 1 byte displacement
    procHandleDispJump:
        macReadSecondByte
        cbw

        add ax, word [CURRENTBYTE]
        call procAddBytesRead

        mov di, cx
        call procWriteW

        macReturnOneArg
    
    ; push/pop segment register
    procHandleSegReg:
        shr al, 3
        mov di, cx
        call procDecodeSegRegister
        macReturnOneArg
    
    ; register/memory as argument
    procHandleModRMTwoByte:
        mov di, cx
        call procDecodeModRMPtr
        macReturnOneArg

    ; register/memory with FAR prefix as argument
    procHandleModRMTwoByteFar:
        mov di, cx
        mov si, _FAR
        call procPushArr
        call procDecodeModRM
        macReturnOneArg

    ; pop register/memory
    procHandlePopRM:
        macReadSecondByte
        test al, 111b << 3
        jz .mod_ok
        xor bx, bx
        ret
        .mod_ok:
        call procHandleModRMTwoByte
        macReturnOneArg

    ; push/pop/inc/dec, register as argument
    procHandleRegInstr:
        or al, 0x08
        mov di, cx
        call procDecodeRegister
        macReturnOneArg

    ; xchg register to accumulator
    procHandleRegAcc:
        mov di, dx
        or al, 0x08
        call procDecodeRegister

        mov di, cx
        mov ax, word [_AX]
        mov word [di], ax

        macReturnTwoArg

    ; handle mul/imul/div/idiv/neg/not
    procHandleMulDivNegNot:
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
            xor bx, bx
            ret
        .label_assigned:
        pop ax

        call procHandleModRMTwoByte
        macReturnTwoArg

    ; direct jump/call
    procHandleDirect:
        mov di, cx
        call procReadDataW

        add ax, word [CURRENTBYTE]
        call procAddBytesRead

        call procWriteW
        macReturnOneArg

    ; in/out instructions
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
        pop ax
        ret

    ; in/out, fixed port
    procHandleIOFixed:
        push ax
        call procHandleIOReg
        
        macReadSecondByte

        mov di, dx
        call procWriteB
        pop ax
        call procIOSwap
        macReturnTwoArg

    ; in/out, variable port
    procHandleIOVariable:
        push ax
        call procHandleIOReg
        mov di, dx
        mov ax, word [_DX]
        mov word [di], ax
        add di, 2
        pop ax
        call procIOSwap
        macReturnTwoArg

    ; inc/dec with register/memory
    procHandleIncRM:
        macReadSecondByte

        push ax
            and al, 00111000b
            macModEntry 000b, _INC
            macModEntry 001b, _DEC

            xor bx, bx
            pop ax
            ret

        .label_assigned:
        pop ax
        call procHandleModRMTwoByte
        macReturnOneArg

    ; byte FF - jmp/call/push/inc/dec
    procHandleFF:
        macReadSecondByte

        push ax
            and al, 00111000b
        
            macModEntryCall 100b, _JMP, procHandleModRMTwoByte
            macModEntryCall 101b, _JMP, procHandleModRMTwoByteFar
            macModEntryCall 010b, _CALL, procHandleModRMTwoByte
            macModEntryCall 011b, _CALL, procHandleModRMTwoByteFar
            macModEntryCall 110b, _PUSH, procHandleModRMTwoByte
            macModEntryCall 000b, _INC, procHandleModRMTwoByte
            macModEntryCall 001b, _DEC, procHandleModRMTwoByte

            pop ax
            xor bx, bx
            ret
        .label_assigned:
        pop ax
        call di
        ret

    ; repe/repne
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
        call procPushArr
        macReturnOneArg

    ; intersegment call/jmp
    procHandleIntersegment:
        mov di, cx
        call procReadDataW
        push ax
        call procReadDataW
        call procWriteW
        mov dl, ':'
        call procPushC
        pop ax
        call procWriteW
        macReturnOneArg

    ; ret with adding to sp
    procHandleRetAdd:
        mov di, cx
        call procReadDataW
        jnc .no_error
        ret
        .no_error:
        call procWriteW
        macReturnOneArg

    ; int x
    procHandleInt:
        mov di, cx
        call procReadDataB
        call procWriteB
        macReturnOneArg

    ; int 3
    procHandleInt3:
        mov di, cx
        mov dl, '3'
        call procPushC
        macReturnOneArg
    
    ; add/adc/sub/sbb/cmp/and/or/xor/test with accumulator
    procHandleImmAcc:
        mov di, dx
        push dx
        test al, 1
        jz .handle_al
            mov dx, word [_AX]
            call procReadDataW
            call procWriteW
            jmp .postif
        .handle_al:
            mov dx, word [_AL]
            call procReadDataB
            call procWriteB
        .postif:
        mov di, cx
        call procPushC
        mov dl, dh
        call procPushC
        pop dx
        macReturnTwoArg

    ; immediate with register/memory
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

    procHandleRegMemNoSwap:
        macReadSecondByte
        call handleRegMem
        ret

    procHandleRegMemSwap:
        macReadSecondByte
        or ah, 0x01
        call handleRegMem
        xchg cx, dx
        ret

    handleRegMem:
        push ax

        mov di, cx
        call procDecodeModRM
        mov di, dx
        and al, 0x38
        shr al, 3
        and ah, 1
        shl ah, 3
        or al, ah
        call procDecodeRegister

        pop ax
        and ah, 0x02
        jz .finished
        xchg cx, dx
        .finished:
        macReturnTwoArg

; -------------------------
;    helpers for decoding
; -------------------------

    procIOSwap:
        test al, 2
        jz .skip_swap
        xchg cx, dx
        .skip_swap:
        ret

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
        call procPushArr
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
        call procPushC
        pop dx

        test al, 0xc0
        jnz .decode_rm
        mov ax, [bp]
        and al, 0x7
        cmp al, 0x6
        je .skip_rm

        .decode_rm:
        mov ax, [bp]
        call procGetRMTable
        call procPushArr

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

            call procReadDataW
            call procWriteW
            inc di

            .skip_read:
            dec di
            jmp .post_mod

        .mod_01:
            call procReadDataB
            test al, 0x80
            jnz .has_sign

            call procWriteB
            jmp .post_mod

            .has_sign:
            dec di
            push dx
            mov dl, '-'
            call procPushC
            pop dx
            neg al
            call procWriteB
            jmp .post_mod
        .mod_10:
            call procReadDataW
            call procWriteW  
            jmp .post_mod
        .mod_11: ; register
            mov ax, [bp]
            and ah, 1
            shl ah, 3
            and al, 0x07
            or al, ah
            call procDecodeRegister
            jmp .post_brackets

        .post_mod:
        push dx
        mov dl, ']'
        call procPushC
        pop dx
        .post_brackets:
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
            call procReadDataW
            call procWriteW
            jmp .post_data

        .datab:
            call procReadDataB
            call procWriteB
            jmp .post_data

        .datasb:
            call procReadDataB
            cmp al, 0x80
            push dx
            jnz .no_negative
                neg al
                mov dl, '-'
                jmp .write
            .no_negative:
                mov dl, '+'
            .write:
            call procPushC
            pop dx
            call procWriteB
            jmp .post_data
        
        .post_data:
        pop ax
        ret

    procDecodeSegRegister:
        push ax
        push bx
        and ax, 0x0003
        shl al, 1

        add ax, _SEGREGISTERS
        mov bx, ax
        mov ax, word [bx]
        mov word [di], ax
        add di, 2
        pop bx
        pop ax
        ret

    procDecodeRegister:
        push ax
        push bx
        push cx

        mov bx, _REGISTERS
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

    procGetRMTable:
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

    procReadDataB:
        macReadByteWithCheck
        ret

    procReadDataW:
        push cx
        macReadByteWithCheck
        mov cl, al
        macReadByteWithCheck
        mov ch, al
        mov ax, cx
        pop cx
        ret