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

%macro macFWriteStr 1+
    section .data
        %%str: db %1
        %%len: dw $-%%str
    section .text
        push di
        push cx
        mov di, %%str
        mov cx, [%%len]
        call fPutArr
        pop cx
        pop di
%endmacro

%macro macFWriteStrAddr 1
    mov di, %1
    call fWriteStrAddr
%endmacro