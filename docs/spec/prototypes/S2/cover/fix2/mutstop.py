"""fix-2: mutants of Cover.shown's stops past the budget: each `return` right under `if over then` or `if due() then`
(and the budget < 0 return) dropped in turn; the capped-design test of Cover.spec (f) run on each."""
import re, subprocess, sys
root = sys.argv[1]
p = root + "/src/shared/Physics/Cover.luau"
orig = open(p, encoding="utf-8").read()
lines = orig.split("\n")
start = next(i for i, l in enumerate(lines) if l.startswith("function Cover.shown("))
sites = []
for i in range(start, len(lines)):
    l = lines[i]
    if re.match(r"^\s*return\b", l) and i > 0 and (re.search(r"if over then\s*$", lines[i - 1]) or re.search(r"if due\(\) then\s*$", lines[i - 1]) or "budget < 0" in lines[i - 1]):
        sites.append(i)
lune = "C:/Users/louis/.aftman/tool-storage/lune-org/lune/0.8.9/lune.exe"
killed = 0
for i in sites:
    mut = lines[:]
    mut[i] = re.sub(r"return\b.*$", "local _ = nil -- mutant", lines[i])
    open(p, "w", encoding="utf-8", newline="\n").write("\n".join(mut))
    r = subprocess.run([lune, "run", "tests/run", "--", "--filter", "(f) a design past the cap"], cwd=root, capture_output=True, text=True, encoding="utf-8")
    res = [l for l in r.stdout.split("\n") if l.startswith("RESULT")]
    fails = [l.strip() for l in r.stdout.split("\n") if "expected" in l or "ERROR" in l or "FAIL" in l][:2]
    dead = "fail=0" not in (res[0] if res else "") or r.returncode != 0
    killed += dead
    print(f"line {i + 1}: {lines[i - 1].strip()} / {lines[i].strip()}  -> {'killed' if dead else 'SURVIVED'} {res[0] if res else r.stderr[-200:]} {fails}")
open(p, "w", encoding="utf-8", newline="\n").write(orig)
print(f"{killed} of {len(sites)} killed")
