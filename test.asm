org 100h

section .text
	ADD     BP,[BX+DI+0x5678]
	ADD     CX,[BX]
	ADD     DX,[BX+0x78]
	ADD     BX,[BX+0x3456]
	ADD     SI,[BX+SI]
	ADD     DI,[BX+SI+0x79]
	ADD     BP,[BX+SI+0x5678]
	ADD     SI,[BX+DI]
	ADD     DI,[BX+DI+0x29]
	ADD     BP,[BX+DI+0x5678]
	ADD     SP,[SI]
	ADD     DX,[SI+0x28]
	ADD     BX,[SI+0x3456]
	ADD     AX,[DI]
	mov ax, 0x1234
	add al, 0x02
	mov ax, 0x4c00
	int 0x21

