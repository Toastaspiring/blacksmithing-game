# M6 by the judge: lines of the new readings' modules and of today's reading, all / code (non-blank, not a comment line)
import re, sys
def count(path, a=None, b=None):
    lines = open(path, encoding='utf-8').read().split('\n')
    if a is not None:
        i = next(k for k, l in enumerate(lines) if a in l)
        j = next(k for k, l in enumerate(lines) if k > i and b in l)
        lines = lines[i:j]
    code = [l for l in lines if l.strip() and not l.strip().startswith('--')]
    return len(lines), len(code)
A = '../m2x-protoA/repo/src/shared/Physics/'
B = '../m2x-protoB/repo/src/shared/Physics/'
T = 'repo/src/shared/Physics/'
print('A Cover.luau', count(A + 'Cover.luau'))
print('B Cover.luau', count(B + 'Cover.luau'))
print('A Sampling.luau', count(A + 'Sampling.luau'), 'B Sampling.luau', count(B + 'Sampling.luau'), 'today Sampling.luau', count(T + 'Sampling.luau'))
# today's reading: from the frames/lineShown block to the verdict loop's end (before the measure)
print("today's reading (lines/lineShown/flatShown/sidePoint/hiddenByNear/shownArea + verdict loop)", count(T + 'Sampling.luau', '-- A line through a flat patch', '-- the measure: the kept parts'))
print("A's verdict loop", count(A + 'Sampling.luau', '-- the verdict: each part', '-- the measure: the kept parts'))
print("B's verdict loop", count(B + 'Sampling.luau', '-- the verdict: each part', '-- the measure: the kept parts'))
print('judge CoverC (A + conservative probe)', count('proto/CoverC.luau'))
