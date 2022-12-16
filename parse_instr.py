#!/usr/bin/python3

instr = [None for _ in range(256)]
labels = []

with open('instr.txt', 'r') as f:
	additional = f.readline().rstrip()
	labels = set(additional.split(';'))
	for i, line in enumerate(f):
		line = line.rstrip()
		if not line:
			continue

		label, opcode, handler = line.split(';')
		opcode = int(opcode, base=2)

		if label and label not in labels:
			labels.add(label)
		
		if instr[opcode]:
			print(f'Duplicate on line {line}')
			exit(1)
		
		instr[opcode] = (label, handler)

with open('insinc.asm', 'w') as f:
	f.write('section .data\n')
	f.write('\tinstrLabels:\n')
	for l in labels:
		if l:
			f.write(f'\t\t_{l}: db "{l}", 0\n')
	
	genString = lambda label, handler: f'\t\tdw {handler}, {"_"+label if label else "0"}'
	maxlen = max(len(genString(*instr[i])) for i in range(256) if instr[i])

	f.write('\tinstrDecodeTable:\n')
	for i in range(256):
		if not instr[i]:
			s = genString(None, '0')
		else:
			s = genString(*instr[i])
		
		f.write(f'{s}{((maxlen - len(s)) * " ")} ; {hex(i)}\n')

