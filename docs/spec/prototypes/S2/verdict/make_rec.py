#!/usr/bin/env python
"""Writes rec/src/shared/Physics/Sampling.luau: the recommended verdict as clean code, from the candidate's file. The measure and everything the prototype pins stay."""
import shutil, os

SRC = '../m2r4-va/prop/src/shared/Physics/Sampling.luau'
DST = 'rec/src/shared/Physics/Sampling.luau'
if not os.path.isdir('rec'):
    shutil.copytree('../m2r4-va/prop', 'rec')

s = open(SRC, encoding='utf-8', newline='').read()
crlf = '\r\n' in s
if crlf:
    s = s.replace('\r\n', '\n')


def sub(old, new, count=1):
    global s
    assert old in s, old
    s = s.replace(old, new, count)


# ── the header ──
start = s.index('-- Exposure. A sample s of part p (normal n)')
end = s.index('-- All state is per call (§4.9')
s = s[:start] + '''-- Exposure. A sample s of part p (normal n) is hidden by another part q if it is buried (sd_q(s) < −EPS_GEOM), or lies
-- on q's surface and q has the lower index (a coincident face counts once), or its probe s + HIDE_OFFSET·n is inside q.
-- HIDE_OFFSET = CONTACT_TOL + 0.002, so any gap validation calls connected hides the faces across it.
--
-- The verdict comes first, per part, and depends only on the part and on what covers it: Dust: V < MIN_PART_VOLUME, no samples,
-- hides nothing. An exact copy (Shapes.sameSolid with a lower index) lies wholly on that part's surface: Enclosed, no samples,
-- hides nothing. Any other part is Enclosed when under ENCLOSED_EXPOSED_MAX of its surface shows, read on a grid of its own
-- (the first H_LADDER spacing whose surfaceEstimate fits VERDICT_SAMPLES, a Ball nf = VERDICT_BALL_NF), against every part but
-- copies and Dust, stopping once it shows that much. No budget: nothing another part brings can change the grid or which
-- patches get looked at, only a part that really covers this one can change what it reads.
-- With so few samples a patch is large, so the reading is more careful than the measure's. A patch is tested at its centre and
-- 4 corners (just inside the patch, VERDICT_CORNER); it is uniform only if they all show, or one part hides all five (the hiding
-- regions are convex; two parts can leave a slit between them). Otherwise its 4 × 4 sub-grid, over the sub-points on the part's own surface, decides. A strip
-- narrower than the sub-grid's reach shows nothing there: VERDICT_STRIP_RIM of the patch if a corner on the surface showed,
-- VERDICT_STRIP_CENTRE if the centre did. A Cylinder's side has these patches too, its sub-points put back on the surface.
-- A triangle has at least 2 cells per edge, so that patch corners reach its 3 vertices. A Ball keeps the centre verdict.
--
-- Then the measure: every kept part against kept parts only, once, on a ladder and a sub-grid budget of their own, in part
-- order. The prototype's patches and numbers (exposedKept, contact) come from here: a planar sample whose patch may straddle
-- a hiding boundary is tested at its 4 corners and, if they disagree with its centre, weighted by the exposed fraction of a
-- 4 × 4 sub-grid. Cleaned parts never reach it, so enclosed parts leave D bit-identical.
--
''' + s[end:]

# ── the constants ──
sub('''local VERDICT_SAMPLES = 64 -- a part's samples for its Enclosed verdict: 24 x 24 x 64 stays within N_SURF_WORK
local VERDICT_SUB_WORK = 6000 -- a part's sub-grid tests for its verdict
''', '''local VERDICT_SAMPLES = 64 -- a part's samples for its Enclosed verdict, as a Block: 24 x 24 x 64 stays within N_SURF_WORK
local VERDICT_BALL_NF = 4 -- a Ball's cells per cube-face axis in the verdict, whatever its radius: no sample alone reads 2 %
local VERDICT_CORNER = 0.98 -- the corner test's points, in patch half-vectors: a corner exactly on another part's rim is no strip
local VERDICT_STRIP_RIM = 1 / 16 -- of a patch: a corner showed, no sub-point did (the strip is under 1/8 of the patch wide)
local VERDICT_STRIP_CENTRE = 1 / 4 -- of a patch: the centre showed, no sub-point did (the strip is under 1/4 of the patch wide)
''')

# ── triangles and the surface samples ──
sub('''local function addTriangle(P: Prepared, out: SurfaceSamples, work: Spend, ox: number, oy: number, oz: number,
	ax: number, ay: number, az: number, bx: number, by: number, bz: number, h: number)
	local nMax = Geo.NS_MAX
	local la = sqrt(ax * ax + ay * ay + az * az)
	local lb = sqrt(bx * bx + by * by + bz * bz)
	local na = axisCount(la, h, 1, nMax)
	local nb = axisCount(lb, h, 1, nMax)
''', '''local function addTriangle(P: Prepared, out: SurfaceSamples, work: Spend, ox: number, oy: number, oz: number,
	ax: number, ay: number, az: number, bx: number, by: number, bz: number, h: number, minCells: number)
	local nMax = Geo.NS_MAX
	local la = sqrt(ax * ax + ay * ay + az * az)
	local lb = sqrt(bx * bx + by * by + bz * bz)
	local na = axisCount(la, h, minCells, nMax)
	local nb = axisCount(lb, h, minCells, nMax)
''')
sub('''-- A part's surface samples at spacing h, face by face.
function Sampling.surfaceSamples(P: Prepared, h: number, spend: Spend?): SurfaceSamples
	local work = spend or noSpend
''', '''-- A part's surface samples at spacing h, face by face. minCells: at least this many cells per edge of a triangular face (1 by
-- default, the prototype's: with 1 the far half of a thin triangle has no sample).
function Sampling.surfaceSamples(P: Prepared, h: number, spend: Spend?, minCells: number?): SurfaceSamples
	local work = spend or noSpend
	local cells = minCells or 1
''')
for a, b in [
    ('addTriangle(P, out, work, hx, -hy, hz, 0, 0, -2 * hz, 0, 2 * hy, 0, h) -- the +X side', 'addTriangle(P, out, work, hx, -hy, hz, 0, 0, -2 * hz, 0, 2 * hy, 0, h, cells) -- the +X side'),
    ('addTriangle(P, out, work, -hx, -hy, hz, 0, 0, -2 * hz, 0, 2 * hy, 0, h) -- the −X side', 'addTriangle(P, out, work, -hx, -hy, hz, 0, 0, -2 * hz, 0, 2 * hy, 0, h, cells) -- the −X side'),
    ('addTriangle(P, out, work, hx, -hy, -hz, 0, 0, 2 * hz, 0, 2 * hy, 0, h) -- x = +hx', 'addTriangle(P, out, work, hx, -hy, -hz, 0, 0, 2 * hz, 0, 2 * hy, 0, h, cells) -- x = +hx'),
    ('addTriangle(P, out, work, hx, -hy, -hz, -2 * hx, 0, 0, 0, 2 * hy, 0, h) -- z = −hz', 'addTriangle(P, out, work, hx, -hy, -hz, -2 * hx, 0, 0, 0, 2 * hy, 0, h, cells) -- z = −hz'),
    ('addTriangle(P, out, work, -hx, -hy, -hz, 0, 0, 2 * hz, 2 * hx, 2 * hy, 0, h) -- the slope y/hy = x/hx', 'addTriangle(P, out, work, -hx, -hy, -hz, 0, 0, 2 * hz, 2 * hx, 2 * hy, 0, h, cells) -- the slope y/hy = x/hx'),
    ('addTriangle(P, out, work, -hx, -hy, hz, 2 * hx, 0, 0, 2 * hx, 2 * hy, -2 * hz, h) -- the slope y/hy = −z/hz', 'addTriangle(P, out, work, -hx, -hy, hz, 2 * hx, 0, 0, 2 * hx, 2 * hy, -2 * hz, h, cells) -- the slope y/hy = −z/hz'),
]:
    sub(a, b)

# ── the shared weight: the measure's alone now, and one number ──
start = s.index('	-- The exposed part of sample k\'s area, and the same over the sub-points on p\'s surface only')
end = s.index('	-- the verdict: each part on a grid of its own')
measure = '''	-- The exposed part of sample k's area, as the prototype weighs it. contactRow collects the area within CONTACT_TOL per part.
	local function exposedWeight(p: Prepared, S: SurfaceSamples, k: number, cand: { Prepared }, contactRow: { number }): number
		local x, y, z, w = S.x[k], S.y[k], S.z[k], S.w[k]
		local nx, ny, nz = S.nx[k], S.ny[k], S.nz[k]
		local ox, oy, oz = x + delta * nx, y + delta * ny, z + delta * nz
		local e1x, e1y, e1z, e2x, e2y, e2z = S.e1x[k], S.e1y[k], S.e1z[k], S.e2x[k], S.e2y[k], S.e2z[k]
		local lim = sqrt(e1x * e1x + e1y * e1y + e1z * e1z) + sqrt(e2x * e2x + e2y * e2y + e2z * e2z) + eps
		local m0 = max(tol, 2 * lim)
		local nn = 0
		local hiddenFar, hiddenNear = false, false
		for c = 1, #cand do
			local q = cand[c]
			local d0, d1 = math.huge, math.huge
			if aabbContains(q, x, y, z, m0) then
				d0 = sd(q, x, y, z)
				if d0 <= tol then
					contactRow[q.index] += w
				end
			end
			if aabbContains(q, ox, oy, oz, 2 * lim) then
				d1 = sd(q, ox, oy, oz)
			end
			local hid = d0 < -eps or (q.index < p.index and d0 <= eps) or d1 <= eps
			if abs(d0) <= lim or abs(d1) <= lim then
				nn += 1
				near[nn] = q
				hiddenNear = hiddenNear or hid
			elseif hid then
				hiddenFar = true
			end
		end
		if hiddenFar then
			return 0
		end
		if nn == 0 then
			return w
		end
		local centre = if hiddenNear then 0 else w
		if not S.flat[k] or subLeft < 20 * nn then
			return centre
		end
		-- corner pre-test: the hiding regions are convex, so a patch whose 4 corners agree with its centre is uniform
		subLeft -= 4 * nn
		local uniform = true
		for c = 1, 4 do
			local a, b = CORNERS_A[c], CORNERS_B[c]
			local sx, sy, sz = x + a * e1x + b * e2x, y + a * e1y + b * e2y, z + a * e1z + b * e2z
			local tx, ty, tz = sx + delta * nx, sy + delta * ny, sz + delta * nz
			local hidden = false
			for m = 1, nn do
				if hides(near[m], p.index, sx, sy, sz, tx, ty, tz) then
					hidden = true
					break
				end
			end
			if hidden ~= hiddenNear then
				uniform = false
				break
			end
		end
		work(4 * nn)
		if uniform then
			return centre
		end
		subLeft -= 16 * nn
		subSampled += 1
		local hiddenCount = 0
		for i = 1, 4 do
			local a = SUB_GRID[i]
			for j = 1, 4 do
				local b = SUB_GRID[j]
				local sx, sy, sz = x + a * e1x + b * e2x, y + a * e1y + b * e2y, z + a * e1z + b * e2z
				local tx, ty, tz = sx + delta * nx, sy + delta * ny, sz + delta * nz
				for m = 1, nn do
					if hides(near[m], p.index, sx, sy, sz, tx, ty, tz) then
						hiddenCount += 1
						break
					end
				end
			end
		end
		work(16 * nn)
		return w * (16 - hiddenCount) / 16
	end

	-- A point of sample k's patch and the normal there: on a Cylinder's side, back on the surface with the radial normal.
	local function patchPoint(p: Prepared, S: SurfaceSamples, k: number, a: number, b: number): (number, number, number, number, number, number)
		local x = S.x[k] + a * S.e1x[k] + b * S.e2x[k]
		local y = S.y[k] + a * S.e1y[k] + b * S.e2y[k]
		local z = S.z[k] + a * S.e1z[k] + b * S.e2z[k]
		if S.flat[k] then
			return x, y, z, S.nx[k], S.ny[k], S.nz[k]
		end
		local dx, dy, dz = x - p.cx, y - p.cy, z - p.cz
		local along = dx * p.ux + dy * p.uy + dz * p.uz
		local vx, vy, vz = dx - along * p.ux, dy - along * p.uy, dz - along * p.uz
		local l = sqrt(vx * vx + vy * vy + vz * vz)
		local mx, my, mz = vx / l, vy / l, vz / l
		return p.cx + along * p.ux + p.r * mx, p.cy + along * p.uy + p.r * my, p.cz + along * p.uz + p.r * mz, mx, my, mz
	end

	-- Does a near part hide this point? One that does likely hides the next point too, so it goes first: the same answer, sooner.
	local function hiddenByNear(index: number, nn: number, x: number, y: number, z: number, ox: number, oy: number,
		oz: number): boolean
		for m = 1, nn do
			local q = near[m]
			if hides(q, index, x, y, z, ox, oy, oz) then
				near[m], near[1] = near[1], q
				return true
			end
		end
		return false
	end

	-- What the verdict reads at sample k: the area of its patch that shows (§4.4).
	local function shownArea(p: Prepared, S: SurfaceSamples, k: number, cand: { Prepared }): number
		local x, y, z, w = S.x[k], S.y[k], S.z[k], S.w[k]
		local nx, ny, nz = S.nx[k], S.ny[k], S.nz[k]
		local ox, oy, oz = x + delta * nx, y + delta * ny, z + delta * nz
		local e1x, e1y, e1z, e2x, e2y, e2z = S.e1x[k], S.e1y[k], S.e1z[k], S.e2x[k], S.e2y[k], S.e2z[k]
		local lim = sqrt(e1x * e1x + e1y * e1y + e1z * e1z) + sqrt(e2x * e2x + e2y * e2y + e2z * e2z) + eps
		local m0 = max(tol, 2 * lim)
		local nn = 0
		local hiddenNear = false
		local index = p.index
		for c = 1, #cand do
			local q = cand[c]
			local d0, d1 = math.huge, math.huge
			if aabbContains(q, x, y, z, m0) then
				d0 = sd(q, x, y, z)
			end
			if aabbContains(q, ox, oy, oz, 2 * lim) then
				d1 = sd(q, ox, oy, oz)
			end
			local hid = d0 < -eps or (q.index < index and d0 <= eps) or d1 <= eps
			if hid and c > 1 then
				cand[c], cand[1] = cand[1], q -- it likely hides the next sample too
			end
			if abs(d0) <= lim or abs(d1) <= lim then
				nn += 1
				near[nn] = q
				hiddenNear = hiddenNear or hid
			elseif hid then
				return 0 -- a part too far to change over the patch hides all of it
			end
		end
		if nn == 0 then
			return w
		end
		if p.code == BALL then
			return if hiddenNear then 0 else w -- no patch: the centre verdict
		end

		-- the 4 corners against the centre
		local uniform, cornerShows = true, false
		for c = 1, 4 do
			local sx, sy, sz, mx, my, mz = patchPoint(p, S, k, CORNERS_A[c] * VERDICT_CORNER, CORNERS_B[c] * VERDICT_CORNER)
			local hidden = hiddenByNear(index, nn, sx, sy, sz, sx + delta * mx, sy + delta * my, sz + delta * mz)
			if hidden ~= hiddenNear then
				uniform = false
				if not hidden and (not S.flat[k] or sd(p, sx, sy, sz) <= eps) then
					cornerShows = true
				end
			end
		end
		work(4 * nn)
		if uniform and hiddenNear and nn > 1 then
			-- all five hidden, but by one part? Two can leave a slit between them.
			uniform = false
			for m = 1, nn do
				local q = near[m]
				if hides(q, index, x, y, z, ox, oy, oz) then
					local all = true
					for c = 1, 4 do
						local sx, sy, sz, mx, my, mz = patchPoint(p, S, k, CORNERS_A[c] * VERDICT_CORNER, CORNERS_B[c] * VERDICT_CORNER)
						if not hides(q, index, sx, sy, sz, sx + delta * mx, sy + delta * my, sz + delta * mz) then
							all = false
							break
						end
					end
					if all then
						uniform = true
						break
					end
				end
			end
			work(5 * nn)
		end
		if uniform then
			return if hiddenNear then 0 else w
		end

		-- the sub-grid, over the sub-points on p's own surface: a patch on a triangle or a cap can spill over the face's rim
		local onSurface, hiddenOnSurface = 0, 0
		for i = 1, 4 do
			local a = SUB_GRID[i]
			for j = 1, 4 do
				local sx, sy, sz, mx, my, mz = patchPoint(p, S, k, a, SUB_GRID[j])
				if not S.flat[k] or sd(p, sx, sy, sz) <= eps then
					onSurface += 1
					if hiddenByNear(index, nn, sx, sy, sz, sx + delta * mx, sy + delta * my, sz + delta * mz) then
						hiddenOnSurface += 1
					end
				end
			end
		end
		work(16 * nn)
		local shown = if onSurface == 0 then (if hiddenNear then 0 else w) else w * (onSurface - hiddenOnSurface) / onSurface
		if shown > 0 then
			return shown
		end
		-- a strip narrower than the sub-grid's reach: through the centre, or along the rim
		if not hiddenNear then
			return w * VERDICT_STRIP_CENTRE
		end
		return if cornerShows then w * VERDICT_STRIP_RIM else 0
	end

'''
s = s[:start] + measure + s[end:]

# ── the verdict loop ──
sub('''	-- the verdict: each part on a grid of its own, with a sub-grid budget of its own, against every part but exact copies and
	-- Dust, until it shows ENCLOSED_EXPOSED_MAX. How many other parts there are cannot change the grid or the budget, so
	-- hidden parts cannot change a verdict by coarsening or by using up patches; only a part that covers another can.
''', '''	-- the verdict: each part on a grid of its own, against every part but exact copies and Dust, until it shows
	-- ENCLOSED_EXPOSED_MAX. How many other parts there are cannot change the grid or which patches get looked at, so hidden
	-- parts cannot change a verdict by coarsening or by using anything up; only a part that covers another can.
''')
sub('''			local hOwn = Sampling.ladder(Geo.H_SURF, function(h: number): boolean
				return surfaceEstimate(p, h) <= VERDICT_SAMPLES
			end)
			local S = Sampling.surfaceSamples(p, hOwn, work)
''', '''			local hOwn
			if p.code == BALL then
				hOwn = PI * p.r / 2 / (VERDICT_BALL_NF - 0.5) -- ceil((πr/2)/h) = VERDICT_BALL_NF
			else
				hOwn = Sampling.ladder(Geo.H_SURF, function(h: number): boolean
					return surfaceEstimate(p, h) <= VERDICT_SAMPLES
				end)
			end
			local S = Sampling.surfaceSamples(p, hOwn, work, 2)
''')
sub('''			subLeft = VERDICT_SUB_WORK
			local need = Geo.ENCLOSED_EXPOSED_MAX * p.area
''', '''			local need = Geo.ENCLOSED_EXPOSED_MAX * p.area
''')
sub('''				local _, onSurface = exposedWeight(p, S, k, cand, nil)
				visible += onSurface
				work(units)
''', '''				visible += shownArea(p, S, k, cand)
				work(units)
''')
sub('''local BLOCK, WEDGE, CORNER, CYLINDER = Shapes.BLOCK, Shapes.WEDGE, Shapes.CORNER, Shapes.CYLINDER
''', '''local BLOCK, WEDGE, CORNER, CYLINDER, BALL = Shapes.BLOCK, Shapes.WEDGE, Shapes.CORNER, Shapes.CYLINDER, Shapes.BALL
''')

if crlf:
    s = s.replace('\n', '\r\n')
open(DST, 'w', encoding='utf-8', newline='').write(s)
print('wrote', DST)
