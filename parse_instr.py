#!/usr/bin/python3

instr = [None for _ in range(256)]
labels = set()

with open('instr.txt', 'r') as f:
	for i, line in enumerate(f):
		line = line.rstrip()
		if not line:
			continue

		label, opcode, handler = line.split(';')
		opcode = int(opcode, base=2)

		labels.add(label)
		if instr[opcode] != None:
			print(f'Duplicate on line {line}')
			exit(1)
		else:
			instr[opcode] = (label, handler)

with open('insinc.asm', 'w') as f:
	f.write('section .data\n')
	f.write('\tinstrLabels:\n')
	for l in labels:
		f.write(f'\t\t_{l}: db "{l}", 0\n')
	
	f.write('\tinstrDecodeTable:\n')
	for i in range(256):
		if instr[i] == None:
			f.write(f'\t\tdw 0, 0\n')
		else:
			label, handler = instr[i]
			f.write(f'\t\tdw {handler}, _{label}\n')