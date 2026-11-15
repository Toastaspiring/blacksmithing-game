#!/usr/bin/env python
"""Differential: the shortcuts that claim to change no reading, each removed, against the build, reading by reading. args: harness folder"""
import os, sys
alt = sys.argv[1]
src = open(os.path.join(alt, "force/Sampling.luau"), encoding="utf-8", newline="").read()
VARIANTS = {
    "nofilter": [("local atSurface = abs(ox) <= hx and abs(oy) <= hy and abs(oz) <= hz", "local atSurface = true"),
                 ("local atProbe = abs(ox + sx) <= hx and abs(oy + sy) <= hy and abs(oz + sz) <= hz", "local atProbe = true")],
    "nofront": [("""			if front >= a1 then
				work(2 * chords)
				return 0, a1 - a0
			end
""", ""), ("if reachesSurface[qi] and front < a1 then", "if reachesSurface[qi] then")],
    "noearlyB": [("if onA > 0 and hiA - loA <= LINES_AGREE and shownA > LINE_NOTHING * onA and shownA < (1 - LINE_NOTHING) * onA then", "if false then")],
    "nomoves": [("""			if moved and m > 1 then
				near[m], near[1] = near[1], q
			end
""", ""), ("""			if hid and c > 1 then
				cand[c], cand[1] = cand[1], q -- it likely hides the next sample too
			end
""", "")],
}
for name, reps in VARIANTS.items():
    s = src
    for a, b in reps:
        assert s.count(a) == 1, (name, a[:60], s.count(a))
        s = s.replace(a, b)
    d = os.path.join(alt, "var_" + name)
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, "Sampling.luau"), "w", encoding="utf-8", newline="").write(s)
print("built", list(VARIANTS))
