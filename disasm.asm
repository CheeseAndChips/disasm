%include 'mac.inc'

org 100h

%define BUFFER_SIZE 255
%define OPERAND_SIZE 32

section .bss
	INFD: resb 2
	OUTFD: resb 2
	OUTBUFFER: resb BUFFER_SIZE
	BYTESREAD: resb 16
	LEFT_OPERAND: resb OPERAND_SIZE
	RIGHT_OPERAND: resb OPERAND_SIZE
	READCNT: resb 2
	LINE_BUFFER: resb 32

section .data
	OUTBUFFERUSED: dw 0
	CURRENTBYTE: dw 0x100

	show_help_arg: db "/?", 0x0d
	crlf_: db crlf, 0

section .text
start:
	call openFiles

	.loop:
		mov word [READCNT], 0
		call procDecodeByte
		mov ax, word [READCNT]
		add word [CURRENTBYTE], ax
	jmp .loop

	call exitProgram
	write_failure:
	macWriteStr "Failed decoding byte", crlf
	call exitProgram

openFiles:
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

	mov [OUTFD], di ; save location of second file path
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
	mov [INFD], ax

	mov ax, 0x3c00
	mov dx, [OUTFD]
	int 0x21
	jc showFileOpenError
	mov [OUTFD], ax
	ret

addBytesRead:
	push bx
	mov bx, word [READCNT]
	add ax, bx
	pop bx
	ret

procDecodeByte:
	call readByte
	push ax
	mov bx, instrDecodeTable
	shl ax, 2
	add bx, ax
	pop ax

	push dx
	mov dx, word [bx]
	test dx, dx
	jz write_failure		
	pop dx

	; in:
	; al - opcode
	; cx - left operand
	; dx - right operand
	; out:
	; bx - instruction string
	; cx - left operand
	; dx - right operand
	lea cx, [LEFT_OPERAND]
	lea dx, [RIGHT_OPERAND]
	clc
	call [bx]

	jnc .no_failure
	macWriteStr "Failed reading byte", crlf
	macExitProgram
	.no_failure:

	push bx
	push cx
	push dx ; ff7e

	lea di, [LINE_BUFFER]; FFDE

	mov ax, 0x0736
	call writeW
	mov dl, ':'
	call pushC

	mov ax, [CURRENTBYTE]
	call writeW

	mov dl, ' '
	call pushC

	mov si, BYTESREAD
	mov cx, word [READCNT]
	.byteloop:
		mov al, byte [si]
		inc si
		call writeB
	loop .byteloop

	mov dl, 0
	call pushC

	lea di, [LINE_BUFFER]
	.byteloop2:
		mov al, byte [di]
		inc di
		test al, al
		jz .past_loop2
		call fPutC
	jmp .byteloop2

	.past_loop2:

	push cx
	push dx
		mov cx, 18
		mov dx, word [READCNT]
		shl dx, 1
		sub cx, dx
		mov al, ' '
		.spaceloop:
			call fPutC
		loop .spaceloop
	pop dx
	pop cx
	

	pop dx
	pop cx
	pop bx

	mov di, bx
	call fPutArrZero
	test cx, cx
	jz .skip_args

	call getArrSize
	push cx
	mov cx, ax
	neg cx
	add cx, 8
	mov al, ' '
	int 0x03
	.spaceloop2:
		call fPutC
	loop .spaceloop2
	pop cx


	mov di, cx
	call fPutArrZero
	test dx, dx
	jz .skip_args

	mov al, ','
	call fPutC
	mov di, dx
	call fPutArrZero

	.skip_args:
	macFWriteStr crlf

	ret

exitProgram:
	call flushBuffer
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
	push ax

	jmp pasbuff
	buff: db 0
	
	pasbuff:
	mov ah, 0x3f
	mov bx, [INFD]
	mov cx, 1
	mov dx, buff
	int 21h

	test ax, ax
	jnz .bytes_left
	pop ax
	stc
	jmp .skip_write
	
	.bytes_left:
	pop ax
	mov al, byte [buff]

	mov bx, word [READCNT]
	mov [bx+BYTESREAD], al
	inc word [READCNT]

	.skip_write:
	pop dx
	pop cx
	pop bx
	ret

fillBuffer:

writeParsedBytes:
	push cx
	push di
	mov cx, word [READCNT]
	mov di, BYTESREAD
	.loop:
		mov al, byte [di]
		call writeB
		inc di
	loop .loop
	pop di
	pop cx
	ret

flushBuffer:
	push ax
	push bx
	push cx
	push dx
	
	mov ah, 0x40
	mov bx, word [OUTFD]
	mov cx, word [OUTBUFFERUSED]
	mov dx, word OUTBUFFER
	int 0x21
	mov word [OUTBUFFERUSED], 0

	pop dx
	pop cx
	pop bx
	pop ax
	ret

; al - char
fPutC:
	push di
	push bx

	mov di, word OUTBUFFER
	mov bx, word [OUTBUFFERUSED]
	
	cmp bl, BUFFER_SIZE
	jnz .skip_writing
		call flushBuffer
		xor bx, bx
	.skip_writing:
	mov byte [di+bx], al
	inc word [OUTBUFFERUSED]

	pop bx
	pop di
	ret

; di - data, cx - cnt
fPutArr:
	test cx, cx
	jnz .start_write
	ret

	.start_write:
	push bx
	push ax
	xor bx, bx
	.loop:
		mov al, byte [di+bx]
		call fPutC
		inc bx
		cmp bx, cx
	jnz .loop
	pop ax
	pop bx
	ret

; di - data
fPutArrZero:
	push cx
	push ax
	call getArrSize
	mov cx, ax
	call fPutArr
	pop ax
	pop cx
	ret

getArrSize:
	push cx
	push di

	xor cx, cx
	.loop:
		mov al, byte [di]
		inc di
		test al, al
		jz .done
		inc cx
	jmp .loop

	.done:
	mov ax, cx
	pop di
	pop cx
	ret

; dl - char
; di - destination
pushC:
	mov byte [di], dl
	inc di
	ret

pushArr:
	push dx
	cmp byte [si], 0
	jnz .skip_ret
	pop dx
	ret
	.skip_ret:
		mov dl, byte [si]
		call pushC
		inc si
		cmp byte [si], 0
		jnz .skip_ret
	pop dx
	ret

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
	add dl, 'A' - 10	
	.after_change:

	call pushC

	pop ax
	push ax
	mov dl, al
	and dl, 0x0f
	cmp dl, 9
	jg .add_letter2
	add dl, '0'
	jmp .after_change2
	.add_letter2:
	add dl, 'A' - 10	
	.after_change2:

	call pushC

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

fWriteStrAddr:
	push bx
	push cx
	xor bx, bx
	.loop:
		inc bx
		cmp byte [di+bx-1], 0
	jnz .loop
	dec bx

	mov cx, bx
	call fPutArr

	pop cx
	pop bx
	ret

writeOutputFile:



%include "inshan.asm"
%include "insinc.asm"