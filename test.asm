org 100h

section .text
	add word [bx+12], 0x1234
	add [0x1234], sp
	mov ax, 0x1234
	add al, 0x02
	mov ax, 0x4c00
	int 0x21

