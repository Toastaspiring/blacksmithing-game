"""fix-2: add V1's emulator hook (FORCE.kept overrides the verdict) to an emulator copy of Sampling.luau."""
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "FORCE" in s:
    print("already hooked", p); sys.exit(0)
s = s.replace("--!strict", "--!nocheck", 1)
s = s.replace("Sampling.INSIDE_MARGIN = INSIDE_MARGIN\n", "Sampling.INSIDE_MARGIN = INSIDE_MARGIN;\nlocal _ = nil;\n(Sampling :: any).FORCE = {} -- fix-2's hook (emulator copy only): FORCE.kept overrides the verdict\n", 1)
anchor = "\tif capped then\n\t\tlocal contact: { { number } } = table.create(N)\n"
hook = """\tlocal FK = (Sampling :: any).FORCE.kept
\tif FK ~= nil and not capped then
\t\tcleaned = {}
\t\tfor i = 1, N do
\t\t\tkept[i] = FK[i] == true
\t\t\tif not kept[i] then
\t\t\t\ttable.insert(cleaned, { partId = parts[i].id, reason = (if parts[i].volume < Geo.MIN_PART_VOLUME then "Dust" else "Enclosed") :: CleanReason })
\t\t\tend
\t\tend
\tend
"""
assert s.count(anchor) == 1, p
s = s.replace(anchor, hook + anchor, 1)
open(p, "w", encoding="utf-8").write(s)
print("hooked", p)
