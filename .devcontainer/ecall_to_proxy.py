#!/opt/venv/bin/python3

import sys
import re
filename = sys.argv[1]
fileout = sys.argv[2]
with open(filename, 'r') as f:
data = f.read()
lines = data.split("\n")
pattern = r"\s+ecall"
newlines = []
for line in lines:
    if re.match(pattern, line):
        newlines.append(f"""
        sw  ra, -4(sp)
        jal ecall_proxy
        lw ra, -4(sp)
""")
    else:
        newlines.append(line)

data = "\n".join(newlines)
with open(fileout, 'w') as f:
    f.write(data)
