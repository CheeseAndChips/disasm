org 100h

section .text
	ADD		bx, 0x213
	ADC		bx, 0x213
	SUB		bx, 0x213
	SBB		bx, 0x213
	CMP		bx, 0x213

	ADC     BP,[BX+DI+0x5678]
	SUB     CX,[BX]
	SUB     DX,[BX+0x78]
	ADC     BX,[BX+0x3456]
	SBB     SI,[BX+SI]
	ADC     DI,[BX+SI+0x79]
	ADC     BP,[BX+SI+0x5678]
	ADC     SI,[BX+DI]
	SBB		bx, 0x213
	ADC     DI,[BX+DI+0x29]
	ADC     BP,[BX+DI+0x5678]
	ADC     SP,[SI]
	ADC     DX,[SI+0x28]
	ADC     BX,[SI+0x3456]
	ADC     AX,[DI]
	mov ax, 0x1234
	add al, 0x02
	mov ax, 0x4c00
	int 0x21

