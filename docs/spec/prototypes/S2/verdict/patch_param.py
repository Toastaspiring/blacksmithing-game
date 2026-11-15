#!/usr/bin/env python
"""Turns the candidate's Sampling.luau (tree/) into a parametric one for the study: every knob lives in Sampling.CFG, and the
defaults are the candidate, bit for bit (checked by check_param.luau against the candidate's own file)."""
import re

path = 'tree/src/shared/Physics/Sampling.luau'
s = open(path, encoding='utf-8', newline='').read()
crlf = '\r\n' in s
if crlf:
    s = s.replace('\r\n', '\n')


def sub(old, new, count=1):
    global s
    assert old in s, old
    s = s.replace(old, new, count)


sub('''local VERDICT_SAMPLES = 64 -- a part's samples for its Enclosed verdict: 24 x 24 x 64 stays within N_SURF_WORK
local VERDICT_SUB_WORK = 6000 -- a part's sub-grid tests for its verdict
''', '''-- m2r5 study knobs. The defaults are the candidate's rule.
local CFG: any = {
	samples = 64, -- VERDICT_SAMPLES
	subWork = 6000, -- VERDICT_SUB_WORK (math.huge = no budget)
	ballRule = "estimate", -- "estimate": surfaceEstimate; "real": 6 nf^2 <= samples; "nf": nf = ballNf, whatever the radius
	ballNf = 3,
	cylRule = "estimate", -- "estimate": surfaceEstimate; "real": the cylinder's own count <= samples
	cylDirs = 0, -- at least this many directions on a Cylinder's side in the verdict (0: what the spacing gives)
	earlyOut = false, -- verdict: a sample hidden by a part that is not near stops the candidate loop (the same bits, less time)
	verdictOnly = false, -- skip the measure (for the verdict tallies)
	fullReading = false, -- no stop at the threshold: visibleArea is the whole reading
	forceKept = nil, -- a kept row to measure instead of the verdict's (D with truth's verdict)
	stats = nil, -- when a table: verdict samples, candidates and sub-grid tests are added up
}
''')

sub('''local BLOCK, WEDGE, CORNER, CYLINDER = Shapes.BLOCK, Shapes.WEDGE, Shapes.CORNER, Shapes.CYLINDER
''', '''local BLOCK, WEDGE, CORNER, CYLINDER = Shapes.BLOCK, Shapes.WEDGE, Shapes.CORNER, Shapes.CYLINDER
local BALL = 5
''')

sub('''Sampling.INSIDE_MARGIN = INSIDE_MARGIN
''', '''Sampling.INSIDE_MARGIN = INSIDE_MARGIN
Sampling.CFG = CFG
''')

# the cylinder's directions in the verdict
sub('''local function addCylinder(P: Prepared, out: SurfaceSamples, work: Spend, h: number)
''', '''local function addCylinder(P: Prepared, out: SurfaceSamples, work: Spend, h: number, minDirs: number?)
''')
sub('''	else
		nth, stride = 32, 1
	end
	local nax = axisCount(2 * hx, h, 1, nMax)
''', '''	else
		nth, stride = 32, 1
	end
	if minDirs and minDirs > nth then
		nth, stride = minDirs, 32 // minDirs
	end
	local nax = axisCount(2 * hx, h, 1, nMax)
''')
sub('''function Sampling.surfaceSamples(P: Prepared, h: number, spend: Spend?): SurfaceSamples
''', '''function Sampling.surfaceSamples(P: Prepared, h: number, spend: Spend?, minDirs: number?): SurfaceSamples
''')
sub('''		addCylinder(P, out, work, h)
''', '''		addCylinder(P, out, work, h, minDirs)
''')

# the early exit of the verdict
sub('''			local hid = d0 < -eps or (q.index < p.index and d0 <= eps) or d1 <= eps
			if abs(d0) <= lim or abs(d1) <= lim then
				nn += 1
				near[nn] = q
				hiddenNear = hiddenNear or hid
			elseif hid then
				hiddenFar = true
			end
''', '''			local hid = d0 < -eps or (q.index < p.index and d0 <= eps) or d1 <= eps
			if abs(d0) <= lim or abs(d1) <= lim then
				nn += 1
				near[nn] = q
				hiddenNear = hiddenNear or hid
			elseif hid then
				hiddenFar = true
				if verdictEarly then
					break
				end
			end
''')
sub('''	local subLeft = Geo.N_SUB_WORK
	local subSampled = 0
	local near: { Prepared } = {}
''', '''	local subLeft = Geo.N_SUB_WORK
	local subSampled = 0
	local near: { Prepared } = {}
	local verdictEarly = false
	local stats = CFG.stats
	local subTests = 0
''')
sub('''		subLeft -= 4 * nn
		local uniform = true
''', '''		subLeft -= 4 * nn
		subTests += 4 * nn
		local uniform = true
''')
sub('''		subLeft -= 16 * nn
		subSampled += 1
''', '''		subLeft -= 16 * nn
		subTests += 16 * nn
		subSampled += 1
''')

# the verdict
old_verdict = s[s.index('''			local hOwn = Sampling.ladder(Geo.H_SURF, function(h: number): boolean
				return surfaceEstimate(p, h) <= VERDICT_SAMPLES
			end)
'''):s.index('''			visibleArea[i] = visible
			if visible >= need then
				kept[i] = true
''')]
new_verdict = '''			local hOwn = verdictSpacing(p)
			local S = Sampling.surfaceSamples(p, hOwn, work, if p.code == CYLINDER and CFG.cylDirs > 0 then CFG.cylDirs else nil)
			local cand: { Prepared } = {}
			for j = 1, N do
				if j ~= i and hider[j] and aabbOverlap(p, parts[j], delta + tol + hOwn) then
					table.insert(cand, parts[j])
				end
			end
			subLeft = CFG.subWork
			verdictEarly = CFG.earlyOut
			local need = Geo.ENCLOSED_EXPOSED_MAX * p.area
			local visible = 0
			local units = #cand + 1
			local fullReading = CFG.fullReading
			local visited = 0
			for k = 1, S.n do
				local _, onSurface = exposedWeight(p, S, k, cand, nil)
				visible += onSurface
				work(units)
				visited = k
				if visible >= need and not fullReading then
					break
				end
			end
			verdictEarly = false
			if stats then
				stats.parts = (stats.parts or 0) + 1
				stats.samples = (stats.samples or 0) + S.n
				stats.visited = (stats.visited or 0) + visited
				stats.tests = (stats.tests or 0) + visited * units
			end
'''
s = s.replace(old_verdict, new_verdict, 1)

sub('''	local kept: { boolean } = table.create(N, false)
	local cleaned: { Cleaned } = {}
	local visibleArea: { number } = table.create(N, 0)
	local hider: { boolean } = table.create(N, false)
''', '''	local function verdictSpacing(p: Prepared): number
		local samples = CFG.samples
		if p.code == BALL then
			if CFG.ballRule == "nf" then
				return PI * p.r / 2 / (CFG.ballNf - 0.5)
			elseif CFG.ballRule == "real" then
				return Sampling.ladder(Geo.H_SURF, function(h: number): boolean
					local nf = axisCount(PI * p.r / 2, h, 2, Geo.NS_MAX)
					return 6 * nf * nf <= samples
				end)
			end
		elseif p.code == CYLINDER and CFG.cylRule == "real" then
			return Sampling.ladder(Geo.H_SURF, function(h: number): boolean
				local nc = axisCount(2 * p.r, h, 2, Geo.NS_MAX)
				local c = 2 * PI * p.r / h
				local nth = if c <= 8 then 8 elseif c <= 16 then 16 else 32
				nth = max(nth, CFG.cylDirs)
				return nth * axisCount(2 * p.hx, h, 1, Geo.NS_MAX) + 2 * ceil(0.7854 * nc * nc) <= samples
			end)
		end
		return Sampling.ladder(Geo.H_SURF, function(h: number): boolean
			return surfaceEstimate(p, h) <= samples
		end)
	end

	local kept: { boolean } = table.create(N, false)
	local cleaned: { Cleaned } = {}
	local visibleArea: { number } = table.create(N, 0)
	local hider: { boolean } = table.create(N, false)
''')

# a forced kept row and verdict only
sub('''	-- the measure: the kept parts, against kept parts only, on a ladder and a sub-grid budget of their own, in part order. It
''', '''	if CFG.forceKept then
		local forced = CFG.forceKept
		table.clear(cleaned)
		for i = 1, N do
			kept[i] = forced[i]
			if not kept[i] then
				local p = parts[i]
				local dust = p.volume < Geo.MIN_PART_VOLUME
				table.insert(cleaned, { partId = p.id, reason = (if dust then "Dust" else "Enclosed") :: CleanReason })
			end
		end
	end
	if CFG.verdictOnly then
		return {
			hSurf = 0, hKept = 0, surfSamples = 0, subSampled = 0, exposedArea = table.create(N, 0), visibleArea = visibleArea,
			exposedKept = table.create(N, 0), contact = {}, kept = kept, cleaned = cleaned,
		}
	end

	-- the measure: the kept parts, against kept parts only, on a ladder and a sub-grid budget of their own, in part order. It
''')

if crlf:
    s = s.replace('\n', '\r\n')
open(path, 'w', encoding='utf-8', newline='').write(s)

# the emulator and the lib point at the study's tree
for path in ['proto/analyze_build.luau']:
    t = open(path, encoding='utf-8', newline='').read()
    t2 = t.replace('../prop/src/', '../tree/src/')
    assert t != t2
    open(path, 'w', encoding='utf-8', newline='').write(t2)
t = open('lib.luau', encoding='utf-8', newline='').read()
t2 = t.replace('./prop/src/', './tree/src/').replace('./proto_prop/', './proto/')
assert t != t2
open('lib.luau', 'w', encoding='utf-8', newline='').write(t2)
print('ok')
