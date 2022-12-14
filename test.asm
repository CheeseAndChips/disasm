org 100h

section .text
start:
	jmp .l
	.l:
	je .l
	jl .l
	jle .l
	jb .l
	jbe .l
	jp .l
	JO .l
	JS .l
	.l2:
	jne .l2
	jnl .l2
	jnle .l2
	jnb .l2
	jnbe .l2
	jnp .l2
	JNO .l2
	.l3:
	JNS .l2
	loop .l2
	LOOPZ .l3
	LOOPNZ .l3
	jcxz .l3


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
	db 0x90
