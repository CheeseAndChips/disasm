org 100h

section .text
	add byte [bx+si], 0x0c
	mov ax, 0x1234
	add al, 0x02
	mov ax, 0x4c00
	int 0x21

