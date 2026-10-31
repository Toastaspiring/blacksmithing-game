import re
import sys

p = sys.argv[1]
lines = open(p, encoding="utf-8").read().split("\n")
in_code = False
expected = None
problems = 0
pipe = re.compile(r"(?<!\\)\|")
tick = re.compile(r"`[^`]*`")
for i, l in enumerate(lines, 1):
    if l.startswith("```"):
        in_code = not in_code
        continue
    if in_code:
        continue
    if l.startswith("|"):
        s = tick.sub("", l)
        n = len(pipe.findall(s))
        if expected is None:
            expected = n
        elif n != expected:
            print(f"line {i}: {n} pipes, expected {expected}: {l[:120]}")
            problems += 1
    else:
        expected = None
print("problems:", problems)
