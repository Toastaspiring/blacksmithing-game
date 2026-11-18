#!/usr/bin/env python
"""For a survivor: does it change behaviour? Build each mutant as a module beside force/Sampling (its lines numbered as tree's), and let mdiff.luau compare what it reads against the build on many designs."""
import os, sys, json
from mutants import M
HERE = os.path.dirname(os.path.abspath(__file__))
ids = [int(x) for x in sys.argv[1].split(",")]
src = open(os.path.join(HERE, "tree/src/shared/Physics/Sampling.luau"), encoding="utf-8", newline="").read()
nl = "\r\n" if "\r\n" in src else "\n"
os.makedirs(os.path.join(HERE, "mdiff"), exist_ok=True)
def force(s):
    s = s.replace('require("../Definitions/Balance")', 'require("../tree/src/shared/Definitions/Balance")')
    s = s.replace('require("../Definitions/Limits")', 'require("../tree/src/shared/Definitions/Limits")')
    s = s.replace('require("./Shapes")', 'require("../tree/src/shared/Physics/Shapes")')
    s = s.replace("local Sampling = {}" + nl, "local Sampling = {}" + nl + "Sampling.FORCE = {} :: any" + nl, 1)
    a = "\t\t\t\tif visible >= need then" + nl + "\t\t\t\t\tbreak" + nl + "\t\t\t\tend"
    assert a in s
    s = s.replace(a, "\t\t\t\tif visible >= need and not Sampling.FORCE.fullRead then" + nl + "\t\t\t\t\tbreak" + nl + "\t\t\t\tend")
    a = "\t\t\tif visible >= need then" + nl + "\t\t\t\tkept[i] = true"
    assert a in s
    s = s.replace(a, "\t\t\tif Sampling.FORCE.read then Sampling.FORCE.read[i] = visible / p.area end" + nl + a)
    return s
for i in ids:
    mu = M[i]
    assert mu["file"].endswith("Sampling.luau")
    lines = src.split("\n")
    assert mu["old"] in lines[mu["line"] - 1]
    lines[mu["line"] - 1] = lines[mu["line"] - 1].replace(mu["old"], mu["new"], 1)
    open(os.path.join(HERE, "mdiff", "m%d.luau" % i), "w", encoding="utf-8", newline="").write(force("\n".join(lines)))
print("built", ids)
