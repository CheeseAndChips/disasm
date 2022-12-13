#!/usr/bin/python3

instr = [None for _ in range(256)]
labels = []

with open('instr.txt', 'r') as f:
	additional = f.readline().rstrip()
	labels = list(additional.split(';'))
	for i, line in enumerate(f):
		line = line.rstrip()
		if not line:
			continue

		label, opcode, handler = line.split(';')
		opcode = int(opcode, base=2)

		if not label:
			label = None

		if label not in labels:
			labels.append(label)
		if instr[opcode] != None:
			print(f'Duplicate on line {line}')
			exit(1)
		else:
			instr[opcode] = (label, handler)

with open('insinc.asm', 'w') as f:
	f.write('section .data\n')
	f.write('\tinstrLabels:\n')
	for l in labels:
		if l:
			f.write(f'\t\t_{l}: db "{l}", 0\n')
	
	f.write('\tinstrDecodeTable:\n')
	for i in range(256):
		if instr[i] == None:
			f.write(f'\t\tdw 0, 0\n')
		else:
			label, handler = instr[i]
			if not label:
				f.write(f'\t\tdw {handler}, 0\n')
			else:
				f.write(f'\t\tdw {handler}, _{label}\n')
