# fix-3: reunits.py <worst_designs.luau> <units> <timing>: worst_designs.luau again with the build's units, uncapped (lines
# "valid k <name> <units>" and "tooComplex k <name> <units>", the scratch units2.luau's), and verdict ms (timing.luau's
# output, the build's column), its valid designs slowest first
import re, sys
path, unitsPath, timingPath = sys.argv[1:4]
src = open(path, encoding="utf-8", newline="").read()
units = {}
for line in open(unitsPath, encoding="utf-8"):
    m = re.match(r"^(valid|tooComplex) (\d+) (.*?)\s+(-?[\d.]+)\s*$", line.rstrip("\n"))
    if m:
        units[(m.group(1), int(m.group(2)))] = float(m.group(4))
ms = {}
for line in open(timingPath, encoding="utf-8"):
    if line.startswith("valid "):
        cols = line.split("|")
        name = cols[0][len("valid "):].strip()
        m = re.search(r"verdict\s+([\d.]+)", cols[2])
        ms[name] = float(m.group(1))
head, rest = src.split("return {\n", 1)
lines = rest.split("\n")
# blocks: valid entries and tooComplex entries, each from "\t\t{" to "\t\t},"
def blocks(start, end):
    out, cur = [], None
    for i in range(start, end):
        l = lines[i]
        if l == "\t\t{":
            cur = [l]
        elif l == "\t\t}," and cur is not None:
            cur.append(l)
            out.append(cur)
            cur = None
        elif cur is not None:
            cur.append(l)
    return out
iv = lines.index("\tvalid = {")
it = lines.index("\ttooComplex = {")
ie = len(lines) - 1 - lines[::-1].index("\t},")
valid = blocks(iv + 1, it)
past = blocks(it + 1, ie)
def fmtnum(x):
    return repr(x) if x != int(x) else str(int(x))
def setfield(block, field, value):
    for k, l in enumerate(block):
        if l.startswith("\t\t\t" + field + " = "):
            block[k] = "\t\t\t" + field + " = " + value + ","
            return
    raise SystemExit("no field " + field)
def nameOf(block):
    return re.match(r'\t\t\tname = "(.*)",', block[1]).group(1)
for k, b in enumerate(valid):
    setfield(b, "units", fmtnum(units[("valid", k + 1)]))
    key = next(n for n in ms if nameOf(b).startswith(n))
    setfield(b, "verdictMs", "%.2f" % ms[key])
for k, b in enumerate(past):
    setfield(b, "units", fmtnum(units[("tooComplex", k + 1)]))
valid.sort(key=lambda b: -float(re.search(r"verdictMs = ([\d.]+)", "\n".join(b)).group(1)))
out = lines[: iv + 1]
for b in valid:
    out += b
out += lines[it - 1 : it + 1]
for b in past:
    out += b
out += lines[ie:]
open(path, "w", encoding="utf-8", newline="").write(head + "return {\n" + "\n".join(out))
for b in valid:
    print(nameOf(b).encode("ascii", "replace").decode(), re.search(r"units = ([\d.]+)", "\n".join(b)).group(1), re.search(r"verdictMs = ([\d.]+)", "\n".join(b)).group(1))
