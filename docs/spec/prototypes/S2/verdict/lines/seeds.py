#!/usr/bin/env python
"""tests/Physics, slow cases too, on other PROP_BASE_SEED values, each in its own copy of the repo."""
import os, re, shutil, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REPO = r"C:\Users\louis\Documents\RANDOM\ROBLOX\Blacksmithing Game"
LUNE = r"C:/Users/louis/.aftman/bin/lune.exe"
seeds = ["0x12345678", "0xDEADBEEF", "0x00000007", "0x7FFFFFFF", "0xA5A5A5A5", "0x0BADF00D"]
procs = []
for seed in seeds:
    d = os.path.join(ROOT, "seedw", seed)
    if os.path.isdir(d):
        shutil.rmtree(d)
    shutil.copytree(REPO, d, ignore=shutil.ignore_patterns(".git", "tools", "review", "*.rbxlx", "S1", "S3", "S4", "S5", "S6", "S7", "S8"))
    tol = os.path.join(d, "tests/lib/Tol.luau")
    t = open(tol, encoding="utf-8", newline="").read()
    m = re.search(r"PROP_BASE_SEED = 0x[0-9A-Fa-f]+", t)
    assert m, "no seed"
    t = t.replace(m.group(0), "PROP_BASE_SEED = " + seed).replace("CASE_BUDGET_MS = 2000,", "CASE_BUDGET_MS = 60000,")
    open(tol, "w", encoding="utf-8", newline="").write(t)
    log = open(os.path.join(ROOT, "results", "seed_%s.log" % seed), "w")
    procs.append((seed, subprocess.Popen([LUNE, "run", "tests/run", "--", "--filter", "Physics/"], cwd=d, stdout=log, stderr=subprocess.STDOUT), log))
for seed, p, log in procs:
    p.wait()
    log.close()
    lines = open(os.path.join(ROOT, "results", "seed_%s.log" % seed), encoding="utf-8", errors="replace").read().splitlines()
    bad = [l for l in lines if re.match(r"^\s*(FAIL|ERROR)", l)]
    print(seed, "exit", p.returncode, lines[-1][:80] if lines else "", bad[:4])
