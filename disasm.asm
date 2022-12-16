%include 'mac.inc'

org 100h

%define BUFFER_SIZE 255
%define OPERAND_SIZE 32
%define RING_BUFFER_POW 5
%define RING_BUFFER_SIZE (1 << RING_BUFFER_POW)
%define RING_BUFFER_MASK RING_BUFFER_SIZE - 1; 0b1000 => 0b0111

section .bss
	INFD: resb 2
	OUTFD: resb 2
	OUTBUFFER: resb BUFFER_SIZE
	BYTESREAD: resb 16
	LEFT_OPERAND: resb OPERAND_SIZE
	RIGHT_OPERAND: resb OPERAND_SIZE
	READCNT: resb 2
	LINE_COUNTER: resb 2
	INPUT_BUFFER: resb BUFFER_SIZE
	RING_BUFFER: resb RING_BUFFER_SIZE

section .data
	OUTBUFFERUSED: dw 0
	CURRENTBYTE: dw 0x100
	INPUT_FILLED: dw 0
	INPUT_USED: dw 0
	RING_BUFFER_OFFSET: dw 0
	RING_BUFFER_FILLED: dw 0

	show_help_arg: db "/?", 0x0d
	crlf_: db crlf, 0

section .text
start:
	call procOpenFiles

	.loop:
		mov word [READCNT], 0
		call procDecodeByte
		jc .exit
		mov ax, word [READCNT]
		add word [CURRENTBYTE], ax
	jmp .loop

	.exit:
	call procExitProgram

procOpenFiles:
	; check if arguments are /?
	mov cx, 3
	mov si, 0x82
	mov di, show_help_arg
	repe cmpsb
	je procShowHelp

	; find first space	
	mov cl, byte [0x80] ; ch is already 0
	mov di, 0x82
	mov al, ' '
	repne scasb
	
	; if no space was found, show help
	test cx, cx
	jz procShowHelp

	mov [OUTFD], di ; save location of second file path
	mov byte [di-1], 0 ; make asciiz string
	
	; try finding next space
	repne scasb
	test cx, cx
	jnz procShowHelp ; show help if found

	mov byte [di-1], 0

	mov ax, 0x3d00
	mov dx, 0x82
	int 0x21
	jc procShowFileOpenError
	mov [INFD], ax

	mov ax, 0x3c00
	mov dx, [OUTFD]
	int 0x21
	jc procShowFileOpenError
	mov [OUTFD], ax
	ret

procAddBytesRead:
	push bx
	mov bx, word [READCNT]
	add ax, bx
	pop bx
	ret

procFillRingBuffer:
	test cx, cx
	jnz .have_bytes
	ret
	.have_bytes:
	push bx
	push cx
	push si
	push di

	add word [RING_BUFFER_FILLED], cx

	mov bx, word [RING_BUFFER_OFFSET]
	mov di, RING_BUFFER
	.l:
		lodsb
		mov byte [RING_BUFFER + bx], al
		inc bx
		and bx, RING_BUFFER_MASK
	loop .l

	pop di
	pop si
	pop cx
	pop bx
	ret

procDecodeByte:
    call procReadByte
    jnc .no_failure
	ret
    .no_failure:

	call procWriteCSIP
	push ax
	xor ah, ah
	mov bx, instrDecodeTable
	shl ax, 2
	add bx, ax
	pop ax

	mov di, word [bx]
	test di, di
	mov bx, word [bx+2]
	jz .parse_failure

	; in:
	; al - opcode
	; cx - left operand
	; dx - right operand
	; out:
	; bx - instruction string
	; cx - left operand
	; dx - right operand
	.decode:
	mov cx, LEFT_OPERAND
	mov dx, RIGHT_OPERAND
	clc
	call di
	test bx, bx
	jnz .write_result

	.parse_failure:
	mov cx, LEFT_OPERAND
	xor dx, dx
	mov di, cx
	mov al, byte [BYTESREAD]
	call procWriteB
	macPushZero
	push cx
	mov si, BYTESREAD+1
	mov cx, [READCNT]
	dec cx
	call procFillRingBuffer
	mov word [READCNT], 1
	mov bx, _DB
	pop cx
	jmp .write_result
	
	.write_result:

	call procWriteResult
	
	clc
	ret
procWriteCSIP:
	push ax
	mov ax, 0x0734
	call procFWriteW

	mov al, ':'
	call procFPutC

	mov ax, word [CURRENTBYTE]
	call procFWriteW

	mov al, ' '
	call procFPutC
	pop ax

	ret

procWriteResult:
	; 1. write decoded bytes
	mov word [LINE_COUNTER], 0
	mov di, BYTESREAD
	push cx
		mov cx, [READCNT]

		.loop1:
			mov al, [di]
			inc di
			call procFWriteB
		loop .loop1

		mov cx, 18
		call procSpaceFill

		; 2. write instruction
		mov word [LINE_COUNTER], 0
		mov di, bx

		call procFPutArrZero
	pop cx

	test cx, cx
	jz .done

	.write_arg1:
	push cx
		mov cx, 8
		call procSpaceFill
	pop cx

	mov di, cx
	call procFPutArrZero

	test dx, dx
	jz .done

	mov al, ','
	call procFPutC
	mov di, dx
	call procFPutArrZero

	.done:
	mov ax, 0x0a0d
	call procFPutW
	ret

procSpaceFill:
	push ax
	mov ax, word [LINE_COUNTER]
	sub cx, ax
	jg .do_write
	pop ax
	ret

	.do_write:
	mov al, ' '
	.loop:
		call procFPutC
	loop .loop

	pop ax
	ret

procExitProgram:
	call procFlushBuffer
	macExitProgram

procShowHelp:
	macWriteStr "Joris Pevcevicius", crlf, "1 kursas 3 grupe", crlf, ".com programu disassembleris", crlf, "Naudojimas: disasm.com <programa.com> <rezultatas.asm>", crlf
	macExitProgram

procShowFileOpenError:
	xor ax, ax
	mov di, dx
	mov cx, 0xffff
	repnz scasb
	mov byte [di-1], '$'
	macWriteStr "Nepavyko atidaryti failo "
	macWriteStrAddr dx
	macExitProgram


procReadByte:
	push bx
	push cx

	cmp word [RING_BUFFER_FILLED], 0
	jz .ring_empty
	mov bx, word [RING_BUFFER_OFFSET]
	mov al, byte [RING_BUFFER+bx]
	dec word [RING_BUFFER_FILLED]
	inc bx
	and bx, RING_BUFFER_MASK
	mov word [RING_BUFFER_OFFSET], bx
	jmp .update_globals
	

	.ring_empty:
	mov bx, word [INPUT_USED]
	mov cx, word [INPUT_FILLED]
	cmp bx, cx
	jne .return_byte
		push ax
		push dx
		mov ah, 0x3f
		mov bx, word [INFD]
		mov cx, BUFFER_SIZE
		mov dx, INPUT_BUFFER
		int 0x21

		mov word [INPUT_FILLED], ax
		mov word [INPUT_USED], 0
		xor bx, bx

		pop dx
		test ax, ax
		pop ax
		jnz .return_byte
		stc
		jmp .return
	.return_byte:
	mov al, byte [INPUT_BUFFER+bx]
	inc word [INPUT_USED]

	.update_globals:
	mov bx, word [READCNT]
	mov byte [BYTESREAD+bx], al
	inc word [READCNT]
	clc

	.return:
	pop cx
	pop bx
	ret

procFlushBuffer:
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
procFPutC:
	push di
	push bx

	mov di, word OUTBUFFER
	mov bx, word [OUTBUFFERUSED]
	
	cmp bl, BUFFER_SIZE
	jnz .skip_writing
		call procFlushBuffer
		xor bx, bx
	.skip_writing:
	mov byte [di+bx], al
	inc word [OUTBUFFERUSED]
	inc word [LINE_COUNTER]

	pop bx
	pop di
	ret

procFPutW:
	push ax
	call procFPutC
	mov al, ah
	call procFPutC
	pop ax
	ret

procFWriteW:
	push di
	sub sp, 4
	mov di, sp

	call procWriteW
	mov cx, 4
	mov di, sp
	call procFPutArr

	add sp, 4
	pop di
	ret

procFWriteB:
	push cx
	push di
	sub sp, 2
	mov di, sp

	call procWriteB
	mov cx, 2
	mov di, sp
	call procFPutArr
	
	add sp, 2
	pop di
	pop cx
	ret

; di - data, cx - cnt
procFPutArr:
	test cx, cx
	jnz .start_write
	ret

	.start_write:
	push bx
	push ax
	xor bx, bx
	.loop:
		mov al, byte [di+bx]
		call procFPutC
		inc bx
		cmp bx, cx
	jnz .loop
	pop ax
	pop bx
	ret

; di - data
procFPutArrZero:
	push di
	push ax
	.loop:
		mov al, [di]
		inc di
		test al, al
		jz .post_loop
		call procFPutC
	jmp .loop
	.post_loop:
	pop ax
	pop di
	ret

; dl - char
; di - destination
procPushC:
	mov byte [di], dl
	inc di
	ret

procPushZero:
	mov byte [di], 0
	inc di
	ret

procPushArr:
	push dx
	cmp byte [si], 0
	jnz .skip_ret
	pop dx
	ret
	.skip_ret:
		mov dl, byte [si]
		call procPushC
		inc si
		cmp byte [si], 0
		jnz .skip_ret
	pop dx
	ret

procWriteB:
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

	call procPushC

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

	call procPushC

	pop ax
	pop dx
	ret

procWriteW:
	push ax
	mov al, ah
	call procWriteB
	pop ax
	call procWriteB
	ret

%include "inshan.asm"
%include "insinc.asm"