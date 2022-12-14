%ifndef _MAC_INC
%define _MAC_INC

%define crlf 0x0d, 0x0a

%macro macWriteStr 1+
section .data
	%%str: db %1, '$'
section .text
	macWriteStrAddr %%str
%endmacro

%macro macWriteStrAddrSize 2
	push ax
	push bx
	push cx
	push dx

	mov cx, %2
	mov bx, %1
	mov ah, 0x02
	%%loop:
		mov dl, byte [bx]
		int 0x21
		inc bx
	loop %%loop

	pop dx
	pop cx
	pop bx
	pop ax

%endmacro

%macro macWriteStrAddr 1
	push ax
	push dx
	mov ah, 0x09
	mov dx, %1
	int 0x21
	pop dx
	pop ax
%endmacro

%macro macExitProgram 0
	mov ax, 0x4c00
	int 0x21
%endmacro

%macro macReserveVar 2 
	%assign %{1}__OFFSET__ BP_OFFSET
	%define %1 bp + %{1}__OFFSET__
	%assign BP_OFFSET BP_OFFSET+%2
%endmacro

%macro macPushZero 0
    call pushZero
%endmacro

%macro macReturnNoArg 0
	xor cx, cx
	xor dx, dx
	clc
	ret
%endmacro

%macro macReturnOneArg 0
	xor dx, dx
	clc
	ret
%endmacro

%macro macReturnTwoArg 0
	clc
	ret
%endmacro

%macro macModEntry 2
    cmp al, (%1 << 3)
    jnz %%skip
    mov bx, %2
    jmp .label_assigned
    %%skip:
%endmacro

%macro macModEntryCall 3
	cmp al, (%1 << 3)
	jnz %%skip
	mov bx, %2
	mov di, %3
	jmp .label_assigned
	%%skip:
%endmacro

%macro macReadByteWithCheck 0
    call readByte
    jnc %%no_failure
    ret
    %%no_failure:
%endmacro

%macro macReadSecondByte 0
    mov ah, al
    macReadByteWithCheck
%endmacro

%endif