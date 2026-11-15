# p_rodrim.py <rodrim.luau>: V1's rodrim.luau, reporting when no rod reads above 0 (it indexed a nil worst)
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8", newline="").read()
a = "local worst, wpar = 0, nil"
i = s.index('print(fmt("R %.2f: %d rods wholly inside the disk')
b = ('if wpar == nil then -- m2x-fix-5: every rod reads 0\n'
     '\tprint(fmt("R %.2f: %d rods wholly inside the disk (truly 0), %d read 2 %% or more (kept); none reads above 0", R, total, kept))\n'
     '\treturn\nend\n')
if "m2x-fix-5" not in s:
    s = s[:i] + b + s[i:]
open(p, "w", encoding="utf-8", newline="").write(s)
print("ok", p)
