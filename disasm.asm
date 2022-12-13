%include 'mac.inc'

org 100h

section .data
	show_help_arg: db "/?", 0x0d
	infd: dw 0
	outfd: dw 0
	outbuffaddr: dw 0
	outbuffused: dw 0
	currentbyte: dw 0
	readcnt: db 0
	readnow: times 16 db 0

	crlf_: db crlf, 0

%define BUFFER_SIZE 255
%define OPERAND_SIZE 32

section .text
	%assign BP_OFFSET 0
	macReserveVar OUTBUFFER, BUFFER_SIZE
	macReserveVar LEFT_OPERAND, OPERAND_SIZE
	macReserveVar RIGHT_OPERAND, OPERAND_SIZE
	macReserveVar LINE_BUFFER, 32

	sub sp, BP_OFFSET
	mov bp, sp

	lea ax, [OUTBUFFER]
	mov word [outbuffaddr], ax

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

	mov word [currentbyte], 0x100

	mov cx, 10
	.loop:
		push cx
		mov byte [readcnt], 0
		call procDecodeByte
		xor ax, ax
		mov al, byte [readcnt]
		add word [currentbyte], ax
		pop cx
	jmp .loop
	; loop .loop

	call exitProgram
	write_failure:
	macWriteStr "Failed decoding byte", crlf
	call exitProgram


addBytesRead:
	push bx
	xor bx, bx
	mov bl, byte [readcnt]
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

	; mov ax, [currentbyte]
	; call writeW

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

	mov ax, [currentbyte]
	call writeW

	mov dl, ' '
	call pushC

	mov si, readnow
	xor cx, cx
	mov cl, byte [readcnt]
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
		xor dx, dx
		mov dl, byte [readcnt]
		shl dl, 1
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
	mov bx, [infd]
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

	xor bx, bx
	mov bl, byte [readcnt]
	mov [bx+readnow], al
	inc byte [readcnt]

	.skip_write:
	pop dx
	pop cx
	pop bx
	ret

fillBuffer:

writeParsedBytes:
	push cx
	push di
	xor cx, cx
	mov cl, byte [readcnt]
	mov di, readnow
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
	mov bx, word [outfd]
	xor cx, cx
	mov cl, byte [outbuffused]
	mov dx, word [outbuffaddr]
	int 0x21
	mov byte [outbuffused], 0

	pop dx
	pop cx
	pop bx
	pop ax
	ret

; al - char
fPutC:
	push di
	push bx

	mov di, word [outbuffaddr]
	xor bx, bx
	mov bl, byte [outbuffused]
	
	cmp bl, BUFFER_SIZE
	jnz .skip_writing
		call flushBuffer
		xor bx, bx
	.skip_writing:
	mov byte [di+bx], al
	inc byte [outbuffused]

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