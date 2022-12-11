org 100h

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

section .data
	show_help_arg: db "/?", 0x0d
	infd: dw 0
	outfd: dw 0

section .text
	; %assign BP_OFFSET 0
	; macReserveVar INBUFFER, 256 + 2
	; sub sp, BP_OFFSET
	; mov bp, sp

	; check if arguments are /?
	mov cx, 3
	mov si, 0x82
	mov di, show_help_arg
	repe cmpsb
	je showHelp

	; find first space	
	mov cl, byte [0x80] ; ch is already 0
	mov di, 0x82
	mov al, ' '
	repne scasb
	
	; if no space was found, show help
	test cx, cx
	jz showHelp

	mov [outfd], di ; save location of second file path
	mov byte [di-1], 0 ; make asciiz string
	
	; try finding next space
	repne scasb
	test cx, cx
	jnz showHelp ; show help if found

	mov byte [di-1], 0

	mov ax, 0x3d00
	mov dx, 0x82
	int 0x21
	jc showFileOpenError
	mov [infd], ax

	mov ax, 0x3c00
	mov dx, [outfd]
	int 0x21
	jc showFileOpenError
	mov [outfd], ax
	
	; clear buffer
	; mov word [INBUFFER], 0

	; lea ax, [INBUFFER]
	; mov [inbufferaddr], ax

	mov cx, 4
	.decode_loop:
		call readByte
		push ax
		mov bx, instrDecodeTable
		shl ax, 2
		add bx, ax
		pop ax

		int 0x03
		push dx
		mov dx, word [bx]
		test dx, dx
		jz .write_failure		
		pop dx
		call [bx]

		macWriteStr crlf, 0
		loop .decode_loop

	macExitProgram
	.write_failure:
	macWriteStr "Failed decoding byte", crlf
	macExitProgram


showHelp:
	macWriteStr "Joris Pevcevicius", crlf, "1 kursas 3 grupe", crlf, ".com programu disassembleris", crlf, "Naudojimas: disasm.com <programa.com> <rezultatas.asm>", crlf
	macExitProgram

showFileOpenError:
	xor ax, ax
	mov di, dx
	mov cx, 0xffff
	repnz scasb
	mov byte [di-1], '$'
	macWriteStr "Nepavyko atidaryti failo "
	macWriteStrAddr dx
	macExitProgram


readByte:
	push bx
	push cx
	push dx

	jmp pasbuff
	buff: db 0
	
	pasbuff:
	mov ah, 0x3f
	mov bx, [infd]
	mov cx, 1
	mov dx, buff
	int 21h

	test ax, ax
	jnz .bytes_left
	stc
	jmp .skip_write
	
	.bytes_left:
	xor ax, ax
	mov al, byte [buff]
	
	.skip_write:
	pop dx
	pop cx
	pop bx
	ret

fillBuffer:


writeB:
	push dx
	push ax

	mov dl, al
	shr dl, 4
	cmp dl, 9
	jg .add_letter
	add dl, '0'
	jmp .after_change
	.add_letter:
	add dl, 'a' - 10	
	.after_change:

	mov ah, 0x02
	int 0x21

	pop ax
	push ax
	mov dl, al
	and dl, 0x0f
	cmp dl, 9
	jg .add_letter2
	add dl, '0'
	jmp .after_change2
	.add_letter2:
	add dl, 'a' - 10	
	.after_change2:

	mov ah, 0x02
	int 0x21

	pop ax
	pop dx
	ret

writeW:
	push ax
	mov al, ah
	call writeB
	pop ax
	call writeB
	ret


%include "inshan.asm"
%include "insinc.asm"