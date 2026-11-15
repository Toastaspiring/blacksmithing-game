# p_nocap.py <tree>: CAP_CIRCLE = false in Cover and CoverBrute (a cap keeps the round facet's pieces)
import sys
for p in ("/src/shared/Physics/Cover.luau", "/tests/Physics/CoverBrute.luau"):
    f = sys.argv[1] + p
    s = open(f, encoding="utf-8", newline="").read()
    a = "local CAP_CIRCLE = true"
    assert s.count(a) == 1, f
    open(f, "w", encoding="utf-8", newline="").write(s.replace(a, "local CAP_CIRCLE = false"))
print("nocap ok")
