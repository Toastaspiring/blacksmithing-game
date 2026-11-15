#!/usr/bin/env python
"""The repo as it stands, as a whole harness folder: ../alt-<name>, with force, plain and count derived from its Sampling. args: name [keepout]"""
import os, shutil, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BASE = os.path.join(ROOT, "h")
REPO = r"C:\Users\louis\Documents\RANDOM\ROBLOX\Blacksmithing Game"
name = sys.argv[1]
ALT = os.path.join(ROOT, "alt-" + name)
if not os.path.isdir(ALT):
    os.makedirs(ALT)
    shutil.copytree(os.path.join(BASE, "proto"), os.path.join(ALT, "proto"))
    os.makedirs(os.path.join(ALT, "out"))
tree = os.path.join(ALT, "tree")
if os.path.isdir(tree):
    shutil.rmtree(tree)
os.makedirs(tree)
shutil.copytree(os.path.join(REPO, "src"), os.path.join(tree, "src"))
os.makedirs(os.path.join(tree, "tests"))
for sub in ("Physics", "lib", "fixtures", "Blueprint"):
    shutil.copytree(os.path.join(REPO, "tests", sub), os.path.join(tree, "tests", sub))
os.makedirs(os.path.join(tree, "docs", "spec", "prototypes", "S2"))
shutil.copytree(os.path.join(REPO, "docs", "spec", "prototypes", "S2", "v2"), os.path.join(tree, "docs", "spec", "prototypes", "S2", "v2"))
for f in os.listdir(BASE):
    if f.endswith(".luau") or f == "aftman.toml":
        shutil.copy(os.path.join(BASE, f), os.path.join(ALT, f))
for f in os.listdir(HERE):
    if f.endswith(".luau") and not f.startswith("lines_") and f != "truth_rank.luau":
        shutil.copy(os.path.join(HERE, f), os.path.join(ALT, f))
shutil.copy(os.path.join(HERE, "truth_rank.luau"), os.path.join(ALT, "truth.luau"))

s = open(os.path.join(tree, "src/shared/Physics/Sampling.luau"), encoding="utf-8", newline="").read()
nl = "\n"
f = s
f = f.replace('require("../Definitions/Balance")', 'require("../tree/src/shared/Definitions/Balance")')
f = f.replace('require("../Definitions/Limits")', 'require("../tree/src/shared/Definitions/Limits")')
f = f.replace('require("./Shapes")', 'require("../tree/src/shared/Physics/Shapes")')
marker = "\t-- the measure: the kept parts, against kept parts only"
assert marker in f
patch = nl.join(["\tif Sampling.FORCE.kept then", "\t\tcleaned = {}", "\t\tfor i = 1, N do", "\t\t\tkept[i] = Sampling.FORCE.kept[i]", "\t\t\tif not kept[i] then",
                 "\t\t\t\ttable.insert(cleaned, { partId = parts[i].id, reason = \"Enclosed\" :: CleanReason })", "\t\t\tend", "\t\tend", "\tend", "", ""])
f = f.replace(marker, patch + marker)
f = f.replace("local Sampling = {}" + nl, "local Sampling = {}" + nl + "Sampling.FORCE = {} :: any" + nl, 1)
a = "\t\t\t\tif visible >= need then" + nl + "\t\t\t\t\tbreak" + nl + "\t\t\t\tend"
assert a in f
f = f.replace(a, "\t\t\t\tif visible >= need and not Sampling.FORCE.fullRead then" + nl + "\t\t\t\t\tbreak" + nl + "\t\t\t\tend")
a = "\t\t\tif visible >= need then" + nl + "\t\t\t\tkept[i] = true"
assert a in f
f = f.replace(a, "\t\t\tif Sampling.FORCE.read then Sampling.FORCE.read[i] = visible / p.area end" + nl + a)
os.makedirs(os.path.join(ALT, "force"), exist_ok=True)
open(os.path.join(ALT, "force/Sampling.luau"), "w", encoding="utf-8", newline="").write(f)
g = f.replace(marker, "\tif Sampling.FORCE.verdictOnly then" + nl + "\t\treturn { kept = kept, cleaned = cleaned }" + nl + "\tend" + nl + marker)
os.makedirs(os.path.join(ALT, "plain"), exist_ok=True)
open(os.path.join(ALT, "plain/Sampling.luau"), "w", encoding="utf-8", newline="").write(g)
c = g
a = "local sd, sdLocal, toWorld, aabbContains, aabbOverlap, chordLocal =" + nl + "\tShapes.sd, Shapes.sdLocal, Shapes.toWorld, Shapes.aabbContains, Shapes.aabbOverlap, Shapes.chordLocal"
assert a in c
c = c.replace(a, nl.join(["local COUNT = { sd = 0, aabb = 0, chord = 0 }", "local sdRaw, aabbRaw, chordRaw, chordLRaw = Shapes.sd, Shapes.aabbContains, Shapes.chord, Shapes.chordLocal",
                          "local function sd(q, x, y, z) COUNT.sd += 1 return sdRaw(q, x, y, z) end",
                          "local function aabbContains(q, x, y, z, m) COUNT.aabb += 1 return aabbRaw(q, x, y, z, m) end",
                          "local function chord(q, a, b, c, d, e, f, g) COUNT.chord += 1 return chordRaw(q, a, b, c, d, e, f, g) end",
                          "local function chordLocal(q, a, b, c, d, e, f, g) COUNT.chord += 1 return chordLRaw(q, a, b, c, d, e, f, g) end",
                          "local sdLocal, toWorld, aabbOverlap = Shapes.sdLocal, Shapes.toWorld, Shapes.aabbOverlap"]))
c = c.replace("Shapes.chord(", "chord(")
c = c.replace("local COUNT = { sd = 0, aabb = 0, chord = 0 }", "local COUNT = { sd = 0, aabb = 0, chord = 0, reach = 0 }")
a2 = chr(9)*3 + "local qi = q.index" + nl + chr(9)*3 + "local dx, dy, dz = x - q.cx, y - q.cy, z - q.cz"
assert a2 in c
c = c.replace(a2, chr(9)*3 + "COUNT.reach += 1" + nl + a2)
c = c.replace("Sampling.FORCE = {} :: any" + nl, "Sampling.FORCE = {} :: any" + nl + "Sampling.COUNT = COUNT" + nl)
os.makedirs(os.path.join(ALT, "count"), exist_ok=True)
open(os.path.join(ALT, "count/Sampling.luau"), "w", encoding="utf-8", newline="").write(c)
print("synced", ALT)
