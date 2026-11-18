#!/usr/bin/env python
"""A harness folder over a tree: python mkh.py <tree dir> <harness dir>. Scripts from h/, proto from h/proto, force/plain from the tree's Sampling."""
import os, shutil, sys
src, dest = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
H = os.path.join(HERE, "h")
os.makedirs(os.path.join(dest, "out"), exist_ok=True)
for f in os.listdir(H):
    if f.endswith(".luau") or f in ("aftman.toml", "repo_spec.md", "repo_evidence.md"):
        shutil.copy(os.path.join(H, f), os.path.join(dest, f))
if os.path.isdir(os.path.join(dest, "proto")):
    shutil.rmtree(os.path.join(dest, "proto"))
shutil.copytree(os.path.join(H, "proto"), os.path.join(dest, "proto"))
repo = os.path.join(dest, "repo")
if os.path.isdir(repo):
    shutil.rmtree(repo)
os.makedirs(os.path.join(repo, "tests"))
shutil.copytree(os.path.join(src, "src"), os.path.join(repo, "src"))
for sub in ("Physics", "lib", "fixtures", "Blueprint"):
    shutil.copytree(os.path.join(src, "tests", sub), os.path.join(repo, "tests", sub))
os.makedirs(os.path.join(repo, "docs", "spec", "prototypes", "S2", "verdict"))
shutil.copytree(os.path.join(src, "docs", "spec", "prototypes", "S2", "v2"), os.path.join(repo, "docs", "spec", "prototypes", "S2", "v2"))
shutil.copy(os.path.join(src, "docs", "spec", "prototypes", "S2", "verdict", "worst_P.json"), os.path.join(repo, "docs", "spec", "prototypes", "S2", "verdict", "worst_P.json"))
if not os.path.isdir(os.path.join(dest, "tree")):
    shutil.copytree(repo, os.path.join(dest, "tree"))
else:
    shutil.rmtree(os.path.join(dest, "tree"))
    shutil.copytree(repo, os.path.join(dest, "tree"))
if not os.path.isdir(os.path.join(dest, "old")):
    shutil.copytree(os.path.join(H, "old"), os.path.join(dest, "old"))
nl = "\n"
s = open(os.path.join(repo, "src/shared/Physics/Sampling.luau"), encoding="utf-8", newline="").read()
f = s
f = f.replace('require("../Definitions/Balance")', 'require("../repo/src/shared/Definitions/Balance")')
f = f.replace('require("../Definitions/Limits")', 'require("../repo/src/shared/Definitions/Limits")')
f = f.replace('require("./Shapes")', 'require("../repo/src/shared/Physics/Shapes")')
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
os.makedirs(os.path.join(dest, "force"), exist_ok=True)
open(os.path.join(dest, "force/Sampling.luau"), "w", encoding="utf-8", newline="").write(f)
g = f.replace(marker, "\tif Sampling.FORCE.verdictOnly then" + nl + "\t\treturn { kept = kept, cleaned = cleaned }" + nl + "\tend" + nl + marker)
os.makedirs(os.path.join(dest, "plain"), exist_ok=True)
open(os.path.join(dest, "plain/Sampling.luau"), "w", encoding="utf-8", newline="").write(g)
print("harness", dest)
