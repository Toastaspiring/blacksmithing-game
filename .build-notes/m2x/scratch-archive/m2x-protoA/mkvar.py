# Build variant copies of Sampling (and Cover) under v/<name>/, requiring the repo's Definitions and Shapes.
import os, re, sys
root = os.path.dirname(os.path.abspath(__file__))
def rd(p): return open(os.path.join(root, p), encoding='utf-8', newline='').read()
def wr(p, s):
    full = os.path.join(root, p); os.makedirs(os.path.dirname(full), exist_ok=True)
    open(full, 'w', encoding='utf-8', newline='').write(s)
R = '../../repo/src/shared/'
def fix_requires(s, cover_path=None):
    s = s.replace('require("../Definitions/Balance")', 'require("%sDefinitions/Balance")' % R)
    s = s.replace('require("../Definitions/Limits")', 'require("%sDefinitions/Limits")' % R)
    s = s.replace('require("./Shapes")', 'require("%sPhysics/Shapes")' % R)
    if cover_path:
        s = s.replace('require("./Cover")', 'require("%s")' % cover_path)
    return s
def verdict_only(s):
    nl = '\r\n' if '\r\n' in s else '\n'
    i = s.index('-- the measure: the kept parts, against kept parts only')
    j = s.rfind(nl, 0, i)
    tail = nl.join(['', '\treturn { kept = kept, cleaned = cleaned, hSurf = 0, surfSamples = 0, subSampled = 0, exposedKept = {}, contact = {} } :: any', 'end', '', 'return table.freeze(Sampling)', ''])
    return s[:j] + tail
new = rd('repo/src/shared/Physics/Sampling.luau')
old = rd('base/src/shared/Physics/Sampling.luau')
cover = rd('repo/src/shared/Physics/Cover.luau')
cov = fix_requires(cover)
variants = {}
for name, opts in [('base', 'nil'), ('canon', '{ canon = true }'), ('fine', '{ canon = true, sag = 0.002 }')]:
    wr('v/cover/Cover.luau', cov)
    s = new.replace('local MODEL: Cover.ModelOptions? = nil', 'local MODEL: Cover.ModelOptions? = %s' % opts)
    assert s != new or name == 'base'
    wr('v/new_%s/Sampling.luau' % name, fix_requires(s, '../cover/Cover'))
    wr('v/newV_%s/Sampling.luau' % name, fix_requires(verdict_only(s), '../cover/Cover'))
wr('v/old/Sampling.luau', fix_requires(old))
wr('v/oldV/Sampling.luau', fix_requires(verdict_only(old)))
print('ok')

# FORCE-instrumented copies (FORCE.read, FORCE.fullRead, FORCE.kept, FORCE.verdictOnly), as the verifiers' harnesses use them
def add_force_tail(s):
    nl = '\r\n' if '\r\n' in s else '\n'
    s = s.replace('local Sampling = {}' + nl, 'local Sampling = {}' + nl + 'Sampling.FORCE = {} :: any' + nl, 1)
    i = s.index('\t-- the measure: the kept parts, against kept parts only')
    hook = nl.join(['\tif Sampling.FORCE.kept then', '\t\tcleaned = {}', '\t\tfor i = 1, N do', '\t\t\tkept[i] = Sampling.FORCE.kept[i]',
        '\t\t\tif not kept[i] then', '\t\t\t\ttable.insert(cleaned, { partId = parts[i].id, reason = "Enclosed" :: CleanReason })',
        '\t\t\tend', '\t\tend', '\tend', '\tif Sampling.FORCE.verdictOnly then', '\t\treturn { kept = kept, cleaned = cleaned } :: any', '\tend', '', ''])
    return s[:i] + hook + s[i:]
def force_new(s):
    a = 'if Cover.shown(models[i], cand, higher, need, work) >= need then'
    assert a in s
    nl = '\r\n' if '\r\n' in s else '\n'
    b = nl.join(['local shownArea = Cover.shown(models[i], cand, higher, need, work, Sampling.FORCE.fullRead)',
        '\t\t\tif Sampling.FORCE.read then Sampling.FORCE.read[i] = shownArea / models[i].total end',
        '\t\t\tif shownArea >= need then'])
    return add_force_tail(s.replace(a, b))
def force_old(s):
    a = 'if visible >= need then\n\t\t\t\t\tbreak'
    nl = '\r\n' if '\r\n' in s else '\n'
    a = a.replace('\n', nl)
    assert a in s
    s = s.replace(a, a.replace('if visible >= need then', 'if visible >= need and not Sampling.FORCE.fullRead then'))
    b = '\t\t\tif visible >= need then' + nl + '\t\t\t\tkept[i] = true'
    assert b in s
    s = s.replace(b, '\t\t\tif Sampling.FORCE.read then Sampling.FORCE.read[i] = visible / p.area end' + nl + b)
    return add_force_tail(s)
for name, opts in [('base', 'nil'), ('canon', '{ canon = true }'), ('fine', '{ canon = true, sag = 0.002 }')]:
    s = new.replace('local MODEL: Cover.ModelOptions? = nil', 'local MODEL: Cover.ModelOptions? = %s' % opts)
    wr('v/force_%s/Sampling.luau' % name, fix_requires(force_new(s), '../cover/Cover'))
wr('v/force_old/Sampling.luau', fix_requires(force_old(old)))
# the emulator of M3 (S2/v2 + analyze_build), one per reading
S2 = 'repo/docs/spec/prototypes/S2/'
for f in ['num', 'shapes', 'gjk', 'overlap', 'quat', 'mirror', 'fixtures']:
    src = rd(S2 + 'v2/%s.luau' % f)
    for name in ['base', 'canon', 'fine', 'old']:
        wr('proto_%s/%s.luau' % (name, f), src)
ab = rd(S2 + 'verdict/analyze_build.luau')
for name in ['base', 'canon', 'fine', 'old']:
    s = ab.replace('require("../repo/src/shared/Physics/Sampling")', 'require("../v/force_%s/Sampling")' % name)
    assert s != ab
    wr('proto_%s/analyze_build.luau' % name, s)
print('force + proto ok')
