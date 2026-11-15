import sys
p = sys.argv[1]; s = open(p, encoding="utf-8", newline="").read()
a = "\tif pm.round then\n\t\tfor k = 1, nh do\n\t\t\tlocal q = hiders[k]\n\t\t\tif q.round then\n\t\t\t\tlocal s = farthest(pm.part, q.part)"
assert s.count(a) == 1
s = s.replace(a, "\tif false then\n\t\tfor k = 1, nh do\n\t\t\tlocal q = hiders[k]\n\t\t\tif q.round then\n\t\t\t\tlocal s = farthest(pm.part, q.part)")
open(p, "w", encoding="utf-8", newline="").write(s)
