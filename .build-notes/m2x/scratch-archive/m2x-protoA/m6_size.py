# M6: code size of the old reading (Sampling.orig.luau) against the new (Cover.luau + the verdict block in Sampling).
import re
def count(lines):
    code = [l for l in lines if l.strip() and not l.strip().startswith('--')]
    comments = [l for l in lines if l.strip().startswith('--')]
    return len(lines), len(code), len(comments)
old = open('Sampling.orig.luau', encoding='utf-8').read().split('\n')
def span(lines, start_marker, end_marker):
    a = next(i for i, l in enumerate(lines) if start_marker in l)
    b = next(i for i, l in enumerate(lines) if i > a and end_marker in l)
    return lines[a:b]
reading = span(old, '-- A line through a flat patch, in the frame of each near part', '-- the measure: the kept parts, against kept parts only')
consts = [l for l in old if re.match(r'^local (VERDICT_CORNER|VERDICT_STRIP_RIM|VERDICT_STRIP_CENTRE|LINES_AGREE|LINE_NOTHING) ', l)]
header = span(old, '-- With so few samples a patch is large', '-- Then the measure:')
helpers_only_verdict = span(old, '-- A triangular face: corner o, edges a, b', 'local function addCylinder')  # minCells branch is the verdict's (kept: the measure uses it too)
fn = lambda name, ls: print('%-62s lines %4d  code %4d  comment %4d' % ((name,) + count(ls)))
print('== old reading (base/src/shared/Physics/Sampling.luau)')
fn('flatShown, lineShown, shownArea, sidePoint, hiddenByNear + verdict loop', reading)
fn('its constants (VERDICT_CORNER, STRIP_*, LINES_AGREE, LINE_NOTHING)', consts)
fn('its header paragraph', header)
tot = reading + consts + header
fn('total', tot)
new = open('repo/src/shared/Physics/Cover.luau', encoding='utf-8').read().split('\n')
samp = open('repo/src/shared/Physics/Sampling.luau', encoding='utf-8').read().split('\n')
vloop = span(samp, '-- the verdict: each part', '-- the measure: the kept parts, against kept parts only')
print('== new reading')
fn('Cover.luau (whole module: model, clipping, subtraction, shown)', new)
cos = span(new, '-- The unit circle in 32 directions', 'export type Spend')
fn('  of which the 32-direction table moved from Sampling', cos)
fn('Sampling verdict loop calling Cover', vloop)
model = span(new, '-- ── the model ──', '-- ── a facet\'s plane')
fn('  Cover: the model (3 options)', model)
read = span(new, '-- ── a facet\'s plane', 'return table.freeze(Cover)')
fn('  Cover: clipping, subtraction, shown', read)
