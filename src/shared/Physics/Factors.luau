--!strict
-- Physics/Factors (SPEC §5.2, §5.3; owner S2): the 8 factors of a step's work set, raw and normalized. Pure; §4.1's
-- determinism rules apply. The numbers are the reference prototype's (docs/spec/prototypes/S2/v2/analyze.luau,
-- setFactors) but for Thinness' chords, walk and pick (below), read from what Analyze's phases hold: the measure's areas
-- and contact rows, owned volumes and the parts above each (MassProps.ownership), the volume probes, the contact graph
-- and the edge. Every walk goes through the set in the measure's rank order (Sampling.measureRanked, §17.2), then a
-- part's samples, so no id and no order of the parts reaches a factor.
--
--   measure        the set's 8 FactorValues in FactorId order, and what its budgets chose
--   ORDER          FactorId order (Definitions/Types): every factor array follows it
--   norm, cbrt, unionChord, thinDirections, canonicalWalk, latticeStep, thinness, asymmetry
--                  the parts of measure, for tests
--
--   PartCount          n = Σ min(1, V_p/V_PART_FULL), V_p the part's volume                    norm(n, refs)
--   Thinness           below                                                                  the raw value
--   Asymmetry          below                                                                  norm(raw, refs)
--   SurfaceComplexity  A/(6·cbrt(V)²), A = Σ exposedKept, V = Σ owned volume; 0 if V = 0      norm(r, refs)
--   EdgeLength         the main chain's length (§4.6), the same on every set                   norm(E, refs)
--   Joints             Σ over touching pairs min(s_p, s_q)·(1 + JOINT_BOOST·clamp01(1 − a/A_JOINT_REF)),
--                      s = min(1, V/V_PART_FULL), a the mean of the pair's two contact rows        norm(J, refs)
--   MaterialMix        the Definitions/Materials rows the set holds                            norm(k, refs)
--   Volume             Σ owned volume                                                          norm(V, refs)
--
-- Thinness. The set's volume probes, as many as every k-th sample of the set's walk, k = max(1, ceil(n/THICK_BUDGET)):
-- the walk goes through the parts in rank order, a polyhedron's samples in a canonical order its writing cannot change
-- (canonicalWalk), a round part's in their own; a part takes the stride's count of probes, placed by a rank-1 lattice
-- over its walk (latticeStep), so that no layer of its grid is missed whatever k. A probe is measured where its part
-- owns it (not strictly inside a part of owned.higher); a Ball's probe moves to its centre, a Cylinder's to its
-- projection on the axis. τ = the shortest of the union chords through it along thicknessAxis and θ, its part's
-- directions (thinDirections), each grown from [0, 0] over the set's parts (unionChord): a gap merged that is up to
-- HIDE_OFFSET + EPS_GEOM along the line, or that the verdict hides where the line crosses it from one chord to the
-- next, however slantwise (Edge's hidden gaps, each face's probe asked of the part across: the raster's thickness
-- merges the same, §4.4, §4.6), every part but the probe's own read grown by TIE (face ties, below). A chord that
-- enters a slanted hidden slit where it meets the blade's outline, its mouth, leaves it into air with no chord beyond
-- to join and ends at the hidden face (F5's blade turned 45° and split 0.005 → 0.0119 apart: Hammering 0.1765 Normal
-- → 0.2068 Hard, 0.1833 with the mouths closed; §17.1 O10); and a probe that lands in a piece beside the part across,
-- past a flush seam, does not hide the face here, so the seam reopens the gap (F5's laminate turned 30°, hidden 0.0105
-- apart, its far plate in 4 flush pieces: Hammering 0.3095 Hard against 0.1734 merged; asked of every part of W, M3's
-- fix round 3 merged visible air too, an open slot crossed at a grazing slant, and was withdrawn; §17.1 O11). A part
-- flush with the face a chord leaves for such a gap (a rib under the lower plate), grown by TIE where it is not the
-- probe's own, ends the chord there and is the one asked, so where the far face's probe lands past it the gap reopens
-- (Hammering 0.1119 against 0.1121 with the ribs' tops 0.001 lower; §17.1 O11 (k), M3's review round 5).
-- φ = norm(L/max(τ, 1e-6), SIGMA_LO, SIGMA_HI), L the set's extent along +Y.
-- Thinness = (Σw·φ²/Σw·φ)·min(1, Σ_{φ>0} w/(THIN_SHARE_MIN·S)), S the weight of the measured probes in the striking
-- slot, or of all of them where none is (the prototype's rule).
-- Face ties. A probe can lie exactly on another part's face, its line along that face (F1's tip, a Block centred on its
-- blade's top face, has a row of them; a groove's edge on a sample column): whether the line met that part was rounding's
-- call, which a Y shift or another writing of the part made again (G up to 0.0055 over 3,000 generated designs; M3's
-- review round 2). So every part but the probe's own is read grown by TIE, its box test and its chord (Shapes.chord's
-- dilate): a line within TIE of a face meets the part, as Shapes.chord already counts a face its own (its bounds are
-- closed), and geometry decides, the same way however the design is shifted, written or mirrored, but for a face that
-- lies exactly TIE from a probe's line, a sub-1e-9 offset only typing gives, which rounding decides again (F5's tip
-- typed 1e-10 over its blade: 26 of 120 Y shifts move G 0.0007; §17.1 O11). TIE lies far above the
-- rounding of a coordinate a design within Canonical's bounds holds (under 21.2 studs: an ulp 3.6e-15, a probe's local
-- coordinate within 1e-13) and far below any feature: INSIDE_MARGIN, by which a probe lies inside its own part, is
-- 10 × TIE, so a part that shares a face with the probe's own stays out of a line along it, and EPS_GEOM 1,000 × TIE.
-- The probe's own part is read as it is (a Wedge's probe may lie barely INSIDE_MARGIN inside its slope). A chord that
-- crosses a face slantwise is TIE/cos longer at that end (Thinness' last digits).
-- Cleaned parts are in no work set, so they are inert in every factor and a chord opens where one was: a core
-- sandwiched between cheeks that crosses 2 % moves D (§17.2) **[Decision to confirm]** (§17.1 O10). A flush re-cut
-- gives the pieces grids, walks and counts of their own, so it still moves the probes (§17.2) **[Decision to confirm]**
-- (§17.1 O11): G by up to 0.0379 on the 500 generated designs tried, but those are a corpus's figures, not a bound: a
-- piece takes the stride's count of probes from the middle of its walk, so a re-cut can put every piece's probes where
-- it wants them (V1's aimed plate in 11 pieces: ΔG 0.218, Normal → Hard).
-- Asymmetry, about the fixed plane x = 0. Each part's own volume samples, ASYM_N_MIN along a local axis with
-- |axis·X| ≥ ASYM_AXIS_X (N_MIN_AXIS otherwise), at H_VOL × the first H_LADDER factor that keeps
-- Σ min(samples, N_MAX_PART) × (1 + mirror candidates + higher parts in the set) within ASYM_WORK. Its mirror
-- candidates are the set's parts whose box meets its mirrored box widened by ASYM_TOL + ASYM_RAMP + MIRROR_GUARD (one
-- that far away counts in the estimate however a whole-design move rounds the gap; its samples read it as 0). An owned
-- sample s counts c = clamp01((ASYM_TOL + ASYM_RAMP − d)/ASYM_RAMP), d = min over them of sd_q(−s_x, s_y, s_z);
-- Asymmetry = 1 − Σw·c/Σw.
--
-- Work (spend; one unit ≈ one shape query): per Thinness probe taken, its part's higher parts (the ownership test) and,
-- where it is measured, a part of the set per union chord (along thicknessAxis and each of θ) + Edge.hiddenGap's
-- queries; a Wedge's or a CornerWedge's walk, a unit a sample; per Asymmetry part, the set and its higher parts (the
-- candidates), then per sample 1 + its candidates; the samples as Sampling charges them.

local Balance = require("../Definitions/Balance")
local DT = require("../Definitions/Types")
local Materials = require("../Definitions/Materials")
local Edge = require("./Edge")
local MassProps = require("./MassProps")
local Sampling = require("./Sampling")
local Shapes = require("./Shapes")

type Prepared = Shapes.Prepared
type Spend = Sampling.Spend
type VolumeSamples = Sampling.VolumeSamples

export type FactorValue = { factor: DT.FactorId, raw: number, x: number }
export type FactorBudget = {
	thinStride: number, -- every thinStride-th volume probe of the set is taken (§5.2's k)
	thinProbes: number, -- the probes taken, ≤ THICK_BUDGET
	asymSpacing: number, -- Asymmetry's sample spacing
	asymWork: number, -- its estimate there: ≤ ASYM_WORK, or the last rung's
}
-- What Analyze's phases hold, as Factors reads it. Indices are blueprint order throughout.
export type FactorContext = {
	parts: { Prepared },
	rank: { number }, -- Sampling.measureRanked's rank of each part (1 = the highest)
	probes: Sampling.VolumeProbes, -- phase 5: byPart, none on cleaned parts
	exposure: Sampling.Exposure, -- exposedKept, contact
	owned: MassProps.Ownership, -- ownedVolume, higher
	touching: { { boolean } }, -- the contact graph (V3)
	edgeLength: number, -- EdgeProfile.length
	geometry: DT.GeometryRules, -- refs, strikingSlot, thicknessAxis
}

local sqrt, abs, max, min, floor, ceil = math.sqrt, math.abs, math.max, math.min, math.floor, math.ceil
local sd, aabbContains = Shapes.sd, Shapes.aabbContains

local Geo = Balance.Geometry
local Dif = Balance.Difficulty
local MERGE_GAP = Geo.HIDE_OFFSET + Geo.EPS_GEOM -- what the verdict hides across (§4.4): a gap it hides is no gap
local INSIDE_MARGIN = Sampling.INSIDE_MARGIN -- §4.3: strictly inside a higher part
local TAU_FLOOR = 1e-6 -- numeric guard, not a tunable: σ = L/max(τ, 1e-6)
local AXIS_TIE = 1e-9 -- numeric guard, not a tunable (Cover's): components this close tie, so last bits cannot pick
local GOLDEN = 0.6180339887498949 -- (√5 − 1)/2, a literal: the probe pick's step as a share of a part's walk
local TIE = 1e-10 -- numeric guard, not a tunable: the other parts grow this much in a union chord (face ties, above)
local MIRROR_GUARD = 1e-9 -- numeric guard, not a tunable: Asymmetry's mirror candidates' box grows this past its reach
local WALK_ROW = 64 -- samples a Wedge's or a CornerWedge's walk slots between reports to spend (checkpoints only)

local ORDER: { DT.FactorId } =
	{ "PartCount", "Thinness", "Asymmetry", "SurfaceComplexity", "EdgeLength", "Joints", "MaterialMix", "Volume" }

local function noSpend(_: number) end

local function clamp01(x: number): number
	return if x < 0 then 0 elseif x > 1 then 1 else x
end

local function significance(p: Prepared): number
	return min(1, p.volume / Dif.V_PART_FULL)
end

local Factors = {}

Factors.ORDER = table.freeze(ORDER)

-- clamp((v − lo)/(hi − lo), 0, 1) (§5.1).
function Factors.norm(v: number, lo: number, hi: number): number
	return clamp01((v - lo) / (hi - lo))
end

-- §4.1's cube root, the prototype's: a power-of-8 range reduction, 8 fixed Newton steps from 1.5, the powers of 2 back;
-- 0 for v ≤ 0.
function Factors.cbrt(v: number): number
	if v <= 0 then
		return 0
	end
	local m, k = v, 0
	while m >= 8 do
		m /= 8
		k += 1
	end
	while m < 1 do
		m *= 8
		k -= 1
	end
	local x = 1.5
	for _ = 1, 8 do
		x = (2 * x + m / (x * x)) / 3
	end
	if k > 0 then
		for _ = 1, k do
			x *= 2
		end
	else
		for _ = 1, -k do
			x /= 2
		end
	end
	return x
end

-- The line o + t·u against the slab lo ≤ o + t·u ≤ hi, on the t-interval (t0, t1); empty as (1, 0).
local function slab(t0: number, t1: number, o: number, u: number, lo: number, hi: number): (number, number)
	if u == 0 then
		if o < lo or o > hi then
			return 1, 0
		end
		return t0, t1
	end
	local a, b = (lo - o) / u, (hi - o) / u
	if a > b then
		a, b = b, a
	end
	return max(t0, a), min(t1, b)
end

-- Does the line meet q's box grown by m?
local function lineMeetsBox(q: Prepared, ox: number, oy: number, oz: number, ux: number, uy: number, uz: number,
	m: number): boolean
	local t0, t1 = slab(-math.huge, math.huge, ox, ux, q.minx - m, q.maxx + m)
	if t0 > t1 then
		return false
	end
	t0, t1 = slab(t0, t1, oy, uy, q.miny - m, q.maxy + m)
	if t0 > t1 then
		return false
	end
	t0, t1 = slab(t0, t1, oz, uz, q.minz - m, q.maxz + m)
	return t0 <= t1
end

-- The union chord through o along the unit vector u over the list, every part but owner grown by TIE: from [0, 0],
-- every chord within MERGE_GAP of what has grown joins it, and then the nearest one past either end where the verdict
-- hides the gap the line crosses to it from the part that ends the grown chord there (Edge.hiddenGap), until none does.
-- Its length, and hiddenGap's shape queries. What grows is the same in any order of the list but for which of two parts
-- that end it at one t hiddenGap asks: the first in the list (W is in the measure's rank order).
local function unionChord(list: { Prepared }, owner: Prepared, ox: number, oy: number, oz: number, ux: number,
	uy: number, uz: number): (number, number)
	local ivs: { number } = {} -- per chord met: its ends and its part's place in the list
	local n = 0
	for k = 1, #list do
		local q = list[k]
		local m = if q == owner then 0 else TIE
		if lineMeetsBox(q, ox, oy, oz, ux, uy, uz, m) then
			local hit, t0, t1 = Shapes.chord(q, ox, oy, oz, ux, uy, uz, m)
			if hit then
				n += 1
				ivs[3 * n - 2], ivs[3 * n - 1], ivs[3 * n] = t0, t1, k
			end
		end
	end
	local lo, hi, queries = 0, 0, 0
	local joined: { boolean } = table.create(n, false)
	local left = n -- the chords not joined
	while left > 0 do
		local grew = true
		while grew do
			grew = false
			for i = 1, n do
				local a, b = ivs[3 * i - 2], ivs[3 * i - 1]
				if not joined[i] and a <= hi + MERGE_GAP and b >= lo - MERGE_GAP then
					joined[i] = true
					left -= 1
					if a < lo then
						lo = a
					end
					if b > hi then
						hi = b
					end
					grew = true
				end
			end
		end
		if left == 0 then
			break
		end
		-- what is left lies past an end by more than MERGE_GAP: the nearest each way, and the chords that end it
		local right, back, hiAt, loAt = 0, 0, 0, 0
		for i = 1, n do
			local a, b = ivs[3 * i - 2], ivs[3 * i - 1]
			if joined[i] then
				if b == hi and hiAt == 0 then
					hiAt = i
				end
				if a == lo and loAt == 0 then
					loAt = i
				end
			elseif a > hi then
				if right == 0 or a < ivs[3 * right - 2] then
					right = i
				end
			elseif back == 0 or b > ivs[3 * back - 1] then
				back = i
			end
		end
		local joins = false
		if right > 0 and hiAt > 0 then -- hiAt 0: no chord holds the probe (a test's list)
			local a = ivs[3 * right - 2]
			local hidden, units = Edge.hiddenGap(list[ivs[3 * hiAt]], ox + hi * ux, oy + hi * uy, oz + hi * uz,
				list[ivs[3 * right]], ox + a * ux, oy + a * uy, oz + a * uz)
			queries += units
			if hidden then
				joined[right] = true
				left -= 1
				hi = ivs[3 * right - 1]
				joins = true
			end
		end
		if back > 0 and loAt > 0 then
			local b = ivs[3 * back - 1]
			local hidden, units = Edge.hiddenGap(list[ivs[3 * loAt]], ox + lo * ux, oy + lo * uy, oz + lo * uz,
				list[ivs[3 * back]], ox + b * ux, oy + b * uy, oz + b * uz)
			queries += units
			if hidden then
				joined[back] = true
				left -= 1
				lo = ivs[3 * back - 2]
				joins = true
			end
		end
		if not joins then
			break
		end
	end
	return hi - lo, queries
end
Factors.unionChord = unionChord

-- θ: the directions a probe's chords take besides the thickness axis z, as flat triples. A polyhedron's three local
-- axes; a Cylinder's axis and two radial directions, r1 = axis × z made unit (where the axis lies along z, within
-- AXIS_TIE, the world axis most across it, Y then X then Z, made square to it) and r2 = axis × r1; a Ball's world axes.
-- Only the solid and the world fix them, so every writing of a part takes the same chords, and so does every flush
-- piece of a Block (§17.1 O11). A direction that is ±z to the bit is left out: its chord is z's.
local function thinDirections(p: Prepared, zx: number, zy: number, zz: number): { number }
	local d: { number }
	if p.code == Shapes.BALL then
		d = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
	elseif p.code == Shapes.CYLINDER then
		local ux, uy, uz = p.ux, p.uy, p.uz
		local ax, ay, az = uy * zz - uz * zy, uz * zx - ux * zz, ux * zy - uy * zx
		local l = sqrt(ax * ax + ay * ay + az * az)
		if l <= AXIS_TIE then
			local bx, by, bz = abs(ux), abs(uy), abs(uz)
			local ex, ey, ez = 0, 0, 0
			if by <= bx + AXIS_TIE and by <= bz + AXIS_TIE then
				ey = 1
			elseif bx <= bz + AXIS_TIE then
				ex = 1
			else
				ez = 1
			end
			local t = ex * ux + ey * uy + ez * uz
			ax, ay, az = ex - t * ux, ey - t * uy, ez - t * uz
			l = sqrt(ax * ax + ay * ay + az * az)
		end
		ax, ay, az = ax / l, ay / l, az / l
		d = { ux, uy, uz, ax, ay, az, uy * az - uz * ay, uz * ax - ux * az, ux * ay - uy * ax }
	else
		d = { p.ux, p.uy, p.uz, p.vx, p.vy, p.vz, p.wx, p.wy, p.wz }
	end
	local out: { number } = {}
	for a = 1, 7, 3 do
		local x, y, z = d[a], d[a + 1], d[a + 2]
		if not ((x == zx and y == zy and z == zz) or (x == -zx and y == -zy and z == -zz)) then
			table.insert(out, x)
			table.insert(out, y)
			table.insert(out, z)
		end
	end
	return out
end
Factors.thinDirections = thinDirections

-- The set's parts in the measure's rank order (a sorted copy; ranks are distinct, so the order is total).
local function inRankOrder(ctx: FactorContext, set: { number }): { Prepared }
	local rank = ctx.rank
	local order = table.move(set, 1, #set, 1, table.create(#set, 0))
	table.sort(order, function(a: number, b: number): boolean
		return rank[a] < rank[b]
	end)
	local W: { Prepared } = table.create(#order)
	for k = 1, #order do
		W[k] = ctx.parts[order[k]]
	end
	return W
end

-- Does a part above p hold the point strictly inside?
local function buried(above: { Prepared }, x: number, y: number, z: number): boolean
	for h = 1, #above do
		local q = above[h]
		if aabbContains(q, x, y, z, 0) and sd(q, x, y, z) < -INSIDE_MARGIN then
			return true
		end
	end
	return false
end

-- The canonical walk of a polyhedron's volume samples (§5.2), so that every writing of one solid walks the same
-- sequence of points: its local axes from the smallest half extent to the largest, the last innermost (of two equal
-- ones, the one more along world Y first, then X, then Z, components within AXIS_TIE tying), each signed up the world
-- (+Y, else +X, else +Z). The sample at canonical position c (0-based), or nil for a Ball or a Cylinder, whose grids
-- follow their writing (M2's measure, §17.2). Sampling's grid is cells of a part's box, local X outermost, a cell
-- centre half a cell in: a Block holds a sample in every cell, so its counts come from its first sample; a Wedge's or a
-- CornerWedge's samples are slotted by their local coordinates, the counts from the outermost ones (spend: one unit a
-- sample).
local function canonicalWalk(p: Prepared, S: VolumeSamples, work: Spend): ((number) -> number)?
	local n = S.n
	if not p.poly or n < 2 then
		return nil
	end
	local h: { number } = { p.hx, p.hy, p.hz }
	local d: { number } = { p.ux, p.uy, p.uz, p.vx, p.vy, p.vz, p.wx, p.wy, p.wz }
	local sign: { number } = table.create(3, 1)
	for a = 1, 3 do
		local x, y, z = d[3 * a - 2], d[3 * a - 1], d[3 * a]
		sign[a] = if y > AXIS_TIE then 1 elseif y < -AXIS_TIE then -1 elseif x > AXIS_TIE then 1
			elseif x < -AXIS_TIE then -1 elseif z > 0 then 1 else -1
	end
	-- does local axis a come before b (outer first)? A strict order: two square axes differ by ≥ 0.8 in a component
	local function before(a: number, b: number): boolean
		if h[a] ~= h[b] then
			return h[a] < h[b]
		end
		for k = 1, 0, -1 do -- signed y, then x
			local va, vb = sign[a] * d[3 * a - 2 + k], sign[b] * d[3 * b - 2 + k]
			if va > vb + AXIS_TIE then
				return true
			elseif vb > va + AXIS_TIE then
				return false
			end
		end
		return sign[a] * d[3 * a] > sign[b] * d[3 * b]
	end
	local o: { number } = { 1, 2, 3 }
	if before(o[2], o[1]) then
		o[1], o[2] = o[2], o[1]
	end
	if before(o[3], o[2]) then
		o[2], o[3] = o[3], o[2]
	end
	if before(o[2], o[1]) then
		o[1], o[2] = o[2], o[1]
	end
	local a1, a2, a3 = o[1], o[2], o[3]
	local function localOf(s: number, a: number): number
		return (S.x[s] - p.cx) * d[3 * a - 2] + (S.y[s] - p.cy) * d[3 * a - 1] + (S.z[s] - p.cz) * d[3 * a]
	end
	local count: { number } = table.create(3, 0)
	if p.code == Shapes.BLOCK then
		for a = 1, 3 do
			count[a] = floor(h[a] / (localOf(1, a) + h[a]) + 0.5) -- the first cell's centre: h/count in
		end
		if count[1] * count[2] * count[3] == n then
			local n1, n2, n3 = count[a1], count[a2], count[a3]
			local cell: { number } = table.create(3, 0) -- per local axis
			return function(c: number): number
				local c1 = floor(c / (n2 * n3))
				local c2 = floor((c - c1 * n2 * n3) / n3)
				local c3 = c - (c1 * n2 + c2) * n3
				cell[a1] = if sign[a1] > 0 then c1 else n1 - 1 - c1
				cell[a2] = if sign[a2] > 0 then c2 else n2 - 1 - c2
				cell[a3] = if sign[a3] > 0 then c3 else n3 - 1 - c3
				return (cell[1] * count[2] + cell[2]) * count[3] + cell[3] + 1
			end
		end
	end
	-- local coordinates, charged by the row; the counts from the outermost samples
	local l: { number } = table.create(3 * n, 0)
	local m: { number } = { 0, 0, 0 }
	local pending = 0
	for s = 1, n do
		for a = 1, 3 do
			local v = localOf(s, a)
			l[3 * s - 3 + a] = v
			m[a] = max(m[a], abs(v))
		end
		pending += 1
		if pending == WALK_ROW then
			work(pending)
			pending = 0
		end
	end
	work(pending)
	for a = 1, 3 do
		count[a] = floor(h[a] / (h[a] - m[a]) + 0.5)
	end
	-- each sample in its slot: canonical cell (c1, c2, c3), c1 outermost
	local n1, n2, n3 = count[a1], count[a2], count[a3]
	local f1, f2, f3 = n1 / (2 * h[a1]), n2 / (2 * h[a2]), n3 / (2 * h[a3])
	local slots: { number } = table.create(n1 * n2 * n3, 0)
	for s = 1, n do
		local c1 = floor((l[3 * s - 3 + a1] + h[a1]) * f1)
		local c2 = floor((l[3 * s - 3 + a2] + h[a2]) * f2)
		local c3 = floor((l[3 * s - 3 + a3] + h[a3]) * f3)
		if sign[a1] < 0 then
			c1 = n1 - 1 - c1
		end
		if sign[a2] < 0 then
			c2 = n2 - 1 - c2
		end
		if sign[a3] < 0 then
			c3 = n3 - 1 - c3
		end
		slots[(c1 * n2 + c2) * n3 + c3 + 1] = s
	end
	local order: { number } = table.create(n, 0)
	local q = 0
	for k = 1, #slots do
		if slots[k] > 0 then
			q += 1
			order[q] = slots[k]
		end
	end
	if q < n then -- two samples in one cell: not Sampling's grid, so the samples' own order
		return nil
	end
	return function(c: number): number
		return order[c + 1]
	end
end
Factors.canonicalWalk = canonicalWalk

-- The pick's step over a walk of n: the integer nearest GOLDEN·n, raised until coprime to n (at n − 1 at the latest),
-- so that its picks are distinct and spread like a rank-1 lattice. On a Block, n = n1·n2·n3 (the outer axis first): a
-- step coprime to n is coprime to n3 and to n2·n3, so the picks cycle through every layer of the inner axis and every
-- cell of the two inner ones, and the golden step spreads them over the outer one, whatever the stride; a plain stride
-- sharing a factor with n3 keeps to some of its layers.
local function latticeStep(n: number): number
	local a = max(1, min(n - 1, floor(GOLDEN * n + 0.5)))
	while n > 1 do
		local x, y = n, a -- Euclid: gcd(n, a)
		while y > 0 do
			x, y = y, x - floor(x / y) * y
		end
		if x == 1 then
			break
		end
		a += 1
	end
	return a
end
Factors.latticeStep = latticeStep

-- Thinness of W (in walk order): raw, the stride, the probes taken.
local function thinness(ctx: FactorContext, W: { Prepared }, work: Spend): (number, number, number)
	local nW = #W
	local byPart, higher = ctx.probes.byPart, ctx.owned.higher
	local axis = ctx.geometry.thicknessAxis
	local zx, zy, zz = axis[1], axis[2], axis[3]
	local lo, hi, total = math.huge, -math.huge, 0
	for k = 1, nW do
		local a, b = Shapes.extentAlong(W[k], 0, 1, 0)
		lo, hi = min(lo, a), max(hi, b)
		total += byPart[W[k].index].n
	end
	local L = hi - lo
	local stride = max(1, ceil(total / Dif.THICK_BUDGET))
	local strikingSlot = ctx.geometry.strikingSlot
	local sw, sw1, sw2, swThin, swStrike = 0, 0, 0, 0, 0
	local taken, skip = 0, 0 -- skip: the samples the stride passes over before its next pick
	for k = 1, nW do
		local p = W[k]
		local S = byPart[p.index]
		local n = S.n
		-- the stride's count here (every stride-th sample of W's walk), placed by the lattice over the part's walk
		local t = if skip >= n then 0 else floor((n - skip - 1) / stride) + 1
		skip = if t == 0 then skip - n else stride - 1 - (n - skip - 1 - (t - 1) * stride)
		if t > 0 then
			local above = higher[p.index]
			local dirs = thinDirections(p, zx, zy, zz)
			local units = #above + (1 + #dirs / 3) * nW -- the ownership test, then a union chord along z and each of θ
			local walk = canonicalWalk(p, S, work)
			local step = latticeStep(n)
			local c = floor(n / 2) -- 0-based: the middle of the walk first
			for _ = 1, t do
				taken += 1
				local s = if walk then walk(c) else c + 1
				c += step
				if c >= n then
					c -= n
				end
				local x, y, z = S.x[s], S.y[s], S.z[s]
				if buried(above, x, y, z) then
					work(#above)
				else
					if p.code == Shapes.BALL then
						x, y, z = p.cx, p.cy, p.cz
					elseif p.code == Shapes.CYLINDER then
						local u = (x - p.cx) * p.ux + (y - p.cy) * p.uy + (z - p.cz) * p.uz
						x, y, z = p.cx + u * p.ux, p.cy + u * p.uy, p.cz + u * p.uz
					end
					local tau, extra = unionChord(W, p, x, y, z, zx, zy, zz)
					for a = 1, #dirs, 3 do
						local chord, queries = unionChord(W, p, x, y, z, dirs[a], dirs[a + 1], dirs[a + 2])
						tau, extra = min(tau, chord), extra + queries
					end
					local phi = Factors.norm(L / max(tau, TAU_FLOOR), Dif.SIGMA_LO, Dif.SIGMA_HI)
					local w = S.w
					sw += w
					sw1 += w * phi
					sw2 += w * phi * phi
					if phi > 0 then
						swThin += w
					end
					if p.slot == strikingSlot then
						swStrike += w
					end
					work(units + extra)
				end
			end
		end
	end
	local mean = if sw1 > 0 then sw2 / sw1 else 0
	local ref = if swStrike > 0 then swStrike else sw
	return mean * min(1, if ref > 0 then swThin / (Dif.THIN_SHARE_MIN * ref) else 0), stride, taken
end

-- ASYM_N_MIN samples along a local axis that runs across the mirror plane, at most two of them; N_MIN_AXIS otherwise.
local function axisMins(p: Prepared): (number, number, number)
	local across, nMin, nAcross = Dif.ASYM_AXIS_X, Geo.N_MIN_AXIS, Dif.ASYM_N_MIN
	local mx = if abs(p.ux) >= across then nAcross else nMin
	local my = if abs(p.vx) >= across then nAcross else nMin
	local mz = if abs(p.wx) >= across then nAcross else nMin
	return mx, my, mz
end

-- Asymmetry of W (in walk order; inW per part index): raw, the spacing, the work estimate there.
local function asymmetry(ctx: FactorContext, W: { Prepared }, inW: { boolean }, work: Spend): (number, number, number)
	local nW = #W
	local higher = ctx.owned.higher
	local reach = Dif.ASYM_TOL + Dif.ASYM_RAMP
	local wide = reach + MIRROR_GUARD -- the candidates' box: a part at reach exactly is one, however the gap rounds
	local mirrors: { { Prepared } }, aboves: { { Prepared } } = table.create(nW), table.create(nW)
	for k = 1, nW do
		local p = W[k]
		local mc: { Prepared } = {}
		for j = 1, nW do
			local q = W[j]
			if q.maxx >= -p.maxx - wide and q.minx <= -p.minx + wide and q.maxy >= p.miny - wide
				and q.miny <= p.maxy + wide and q.maxz >= p.minz - wide and q.minz <= p.maxz + wide
			then
				table.insert(mc, q)
			end
		end
		local hc: { Prepared } = {}
		local above = higher[p.index]
		for h = 1, #above do
			if inW[above[h].index] then
				table.insert(hc, above[h])
			end
		end
		mirrors[k], aboves[k] = mc, hc
		work(nW + #above)
	end
	local estimate = 0
	local nMax, partMax = Geo.N_MAX_AXIS, Geo.N_MAX_PART
	local h = Sampling.ladder(Geo.H_VOL, function(spacing: number): boolean
		local est = 0
		for k = 1, nW do
			local p = W[k]
			local mx, my, mz = axisMins(p)
			local a = max(mx, min(nMax, ceil(2 * p.hx / spacing)))
			local b = max(my, min(nMax, ceil(2 * p.hy / spacing)))
			local c = max(mz, min(nMax, ceil(2 * p.hz / spacing)))
			est += min(a * b * c, partMax) * (1 + #mirrors[k] + #aboves[k])
		end
		estimate = est -- the ladder stops at the rung it returns: the last one tried
		return est <= Dif.ASYM_WORK
	end)
	local tot, cov = 0, 0
	for k = 1, nW do
		local p = W[k]
		local mx, my, mz = axisMins(p)
		local S = Sampling.volumeSamples(p, h, work, mx, my, mz)
		local mc, hc = mirrors[k], aboves[k]
		local units = 1 + #mc + #hc
		local w = S.w
		for s = 1, S.n do
			local x, y, z = S.x[s], S.y[s], S.z[s]
			if not buried(hc, x, y, z) then
				tot += w
				local d = math.huge
				for j = 1, #mc do
					local q = mc[j]
					if aabbContains(q, -x, y, z, reach) then
						local e = sd(q, -x, y, z)
						if e < d then
							d = e
							if d <= Dif.ASYM_TOL then
								break
							end
						end
					end
				end
				cov += w * clamp01((reach - d) / Dif.ASYM_RAMP)
			end
			work(units)
		end
	end
	return if tot > 0 then 1 - cov / tot else 0, h, estimate
end

local function membership(ctx: FactorContext, W: { Prepared }): { boolean }
	local inW: { boolean } = table.create(#ctx.parts, false)
	for k = 1, #W do
		inW[W[k].index] = true
	end
	return inW
end

-- Thinness of a set (ascending part indices, as WorkSet.select gives them): raw, the stride, the probes taken.
function Factors.thinness(ctx: FactorContext, set: { number }, spend: Spend?): (number, number, number)
	return thinness(ctx, inRankOrder(ctx, set), spend or noSpend)
end

-- Asymmetry of a set: raw, the spacing, the work estimate there.
function Factors.asymmetry(ctx: FactorContext, set: { number }, spend: Spend?): (number, number, number)
	local W = inRankOrder(ctx, set)
	return asymmetry(ctx, W, membership(ctx, W), spend or noSpend)
end

-- The reference range of a factor (geometry.refs, FactorId order).
local function rangeOf(refs: { DT.FactorRange }, factor: DT.FactorId): (number, number)
	for k = 1, #refs do
		if refs[k].factor == factor then
			return refs[k].lo, refs[k].hi
		end
	end
	error("Factors: no reference range for " .. factor, 3)
end

-- The 8 factors of a set (ascending part indices, as WorkSet.select gives them; kept parts only), in FactorId order.
function Factors.measure(ctx: FactorContext, set: { number }, spend: Spend?): ({ FactorValue }, FactorBudget)
	local work = spend or noSpend
	local W = inRankOrder(ctx, set)
	local nW = #W
	local ownedVolume, exposedKept = ctx.owned.ownedVolume, ctx.exposure.exposedKept
	local contact, touching = ctx.exposure.contact, ctx.touching

	local V, n, A = 0, 0, 0
	for k = 1, nW do
		local i = W[k].index
		V += ownedVolume[i]
		n += significance(W[k])
		A += exposedKept[i]
	end
	local cv = Factors.cbrt(V)
	local surface = if V > 0 then A / (6 * cv * cv) else 0

	local J = 0
	for a = 1, nW - 1 do
		local p = W[a]
		for b = a + 1, nW do
			local q = W[b]
			if touching[p.index][q.index] then
				local mean = (contact[p.index][q.index] + contact[q.index][p.index]) / 2
				J += min(significance(p), significance(q)) * (1 + Dif.JOINT_BOOST * clamp01(1 - mean / Dif.A_JOINT_REF))
			end
		end
	end

	local kinds = 0
	local ordered = Materials.ordered
	for m = 1, #ordered do
		local id = ordered[m].id
		for k = 1, nW do
			if W[k].material == id then
				kinds += 1
				break
			end
		end
	end

	local thin, stride, taken = thinness(ctx, W, work)
	local asym, spacing, estimate = asymmetry(ctx, W, membership(ctx, W), work)

	local raw: { number } = { n, thin, asym, surface, ctx.edgeLength, J, kinds, V } -- FactorId order
	local refs = ctx.geometry.refs
	local values: { FactorValue } = table.create(#ORDER)
	for k = 1, #ORDER do
		local factor: DT.FactorId = ORDER[k]
		local x = raw[k]
		if factor ~= "Thinness" then -- Thinness is in [0, 1] already: its range is σ's, inside φ
			local lo, hi = rangeOf(refs, factor)
			x = Factors.norm(x, lo, hi)
		end
		values[k] = { factor = factor, raw = raw[k], x = x }
	end
	return values, { thinStride = stride, thinProbes = taken, asymSpacing = spacing, asymWork = estimate }
end

return table.freeze(Factors)
