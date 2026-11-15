import sys
p = sys.argv[1]; s = open(p, encoding="utf-8", newline="").read()
a = "\t\t\t\t\t\tband = band or s < -EPS\n"
assert s.count(a) == 1
s = s.replace(a, "")
open(p, "w", encoding="utf-8", newline="").write(s)
