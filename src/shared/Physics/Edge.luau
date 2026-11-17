--!strict
-- Physics/Edge (SPEC §4.6, §4.7; owner S2): the blade's raster, its outline, the sharpenable chains and cutIndex. Pure;
-- §4.1's determinism rules apply. The reference prototype's rules (docs/spec/prototypes/S2/v2, edgeProfile), without
-- its % and //: crack edges keep their integer ends, cyclic indices wrap by subtraction, the chains' order is total;
-- but each cell is sampled off its centre, chords merge across what the verdict hides across and Douglas–Peucker runs
-- on the outline's integer lattice (below), so a fixture whose cells the prototype's centres decided by rounding, or
-- whose outline it simplified at a near tie in blueprint XY, measures otherwise (docs/build/M3-notes.md).
--
--   profile       §4.6's five rows on a list of parts in the order to walk, kept indexed like the list (MassProps'
--                 difficultyFrame convention), in the difficulty frame (§4.5): the EdgeProfile, and the chosen rung's
--                 raster size and work
--   cutIndex      clamp((max(bladeLength, 1e-6)/bladeMeanThickness − CUT_LO)/(CUT_HI − CUT_LO), 0, 1); 0 with no
--                 thickness
--   simplify      Douglas–Peucker on an open polyline of lattice points, exact: the indices kept
--   mergedLength  the length of a union of intervals, gaps up to tol merged (on a copy)
--   hiddenGap     whether the verdict hides the gap a line crosses from one part to the next (below), and the shape
--                 queries it made: the raster's thickness and Factors' union chord merge across it
--
-- Raster. Cells of EDGE_CELL × the first H_LADDER factor (Sampling.ladder) that gives ≤ EDGE_MAX_CELLS cells and
-- ≤ EDGE_MAX_WORK cell × part tests (a kept part counts in every cell of a row its dilated y-range holds), the last if
-- none does; x anchored at the plane x = 0, y at the lowest kept striking point, with one empty cell round the
-- striking parts' box dilated by RASTER_TOL. A cell's sample is its centre moved SAMPLE_X towards x = 0 and SAMPLE_Y up.
-- It is covered when the sample's Z line passes within RASTER_TOL of a kept part of the striking slot (Shapes.chord,
-- dilated); its thickness is the union of the plain chords, a gap merged that is up to HIDE_OFFSET + EPS_GEOM along the
-- line or that the verdict hides where the line crosses it to the next chord, however slantwise (hidden gaps, below),
-- or of the dilated ones where only the dilation reaches it; hilt = a dilated chord through a kept part of another
-- slot. bladeArea and bladeMeanThickness count the cells a plain chord crosses.
-- Hidden gaps. The verdict hides a gap by its width across it, along a face's normal (§4.4), and a line that crosses it
-- at a slant sees it wider: a laminate turned 30° about its length, its faces hidden 0.0105 apart, is 0.0121 apart
-- along Z. So past MERGE_GAP along the line, the next chord joins too where the measure's own hide test hides both
-- faces the line crosses between them, each by the other part (Sampling.exposure: a face's probe, HIDE_OFFSET along its
-- outward normal, within EPS_GEOM of the other part), the face where it leaves the one part and the face where it meets
-- the other: a facing gap merges at any slant as far as the verdict hides it. The air it merges is the gap's own: each
-- part is convex and lies behind its face's plane, so the line between the two points runs between the two faces'
-- planes, within MERGE_GAP of them summed, and where flat faces face each other the point where it leaves the one lies
-- under the other part, where its probe lands, the point where it meets the other over the one, and by convexity the
-- line between over both all along; so too on round faces (a Ball's and a Cylinder's side against a plate and each
-- other, slants of 0.5–80°, gaps either side of the window: every point of 179,928 merged lines within MERGE_GAP of the
-- two parts summed, each part's face nearest to it hidden, but where the part across is thinner than HIDE_OFFSET there
-- and the verdict reads through it, §17.1 O10; M3's fix round 4, docs/build/M3-notes.md). A corner or an edge beside a
-- face, which the verdict shows, merges nothing (V1's two-sided rule, each part within MERGE_GAP of the point where the
-- line crosses the other's face, merged those too: ribs on a rod, a tip on a turned blade). A probe that lands in a
-- part beside the one across does not hide its face here: asked of every part of the set (M3's fix round 3), the test
-- merged visible air, an open slot that the line crosses at a grazing slant between two hidden gaps, each probe held
-- beside it (four slabs 3° off Z over F5's blade, a slot 0.15 long: its column read 0.27 thick and cut the edge in two,
-- Sharpening 0.2728 Hard → 0.0720 Normal; withdrawn in fix round 4). So a seam beside a slanted crossing, the part
-- beyond cut flush where the probe lands in the piece beside, which the verdict counts, reopens the gap (F5's laminate
-- turned 30° and hidden 0.0105 apart, its far plate in 4 flush pieces: Hammering 0.3095 Hard against 0.1734 for the
-- same pieces 0.0100 apart; §17.1 O11). Nor does a slanted slit's mouth merge, where it meets the blade's outline: a
-- line that enters the gap there leaves it into air, with no chord beyond to join, and its thickness ends at the hidden
-- face (F5's blade turned 30° about its length and split 0.0119 apart: its columns at x ±0.0687 read 0.0278 against the
-- whole blade's 0.0360, the mean thickness 0.0611 → 0.0591); closing it needs the gap's lateral bound, which no part
-- carries (§17.1 O10). A face's normal is that of the largest term of Shapes.sdLocal at the point (a Block's faces in
-- x, y, z order, then a Wedge's or a CornerWedge's slopes; a Cylinder's cap before its side; a Ball's radius). The gap
-- across, (f − e)·n_p at most REACH, is tested first, from the normal alone: f's probe held implies it (p lies behind
-- its face's plane), so it is an exact pre-test, which a far chord ends at one query; each probe asks the part across,
-- its box, then its sd.
-- Outline. Crack edges with the covered cell on the left, each stored with its integer ends on the vertex lattice,
-- traced into loops turning right first (8-connected); a loop of positive area runs counter-clockwise, an outer loop,
-- the others are holes. An edge is eligible when its outer cell is not hilt and its inner cell is at most
-- EDGE_MAX_THICK thick. A loop gives its runs of eligible edges, or, all eligible, opens at its lowest vertex (lowest
-- y, then x).
-- Geometry. A run's polyline is its first vertex, each edge's midpoint and its last vertex, on the doubled vertex
-- lattice (a vertex (i, j) at (2i, 2j), a midpoint at the sum of its edge's ends): integers. Douglas–Peucker at
-- EDGE_SIMPLIFY cells, doubled until ≤ EDGE_MAX_POINTS points, compares squared distances as integers, exactly; ties
-- keep the first point. The kept points become blueprint XY, x = (i0 + i)·h and y = Y0 + (j0 + j)·h, and a segment's
-- length is its lattice length × h, so one lattice gives one set of lengths to the bit. Segments whose outward normal n
-- faces the pommel (n·A < −EDGE_DOWN_COS, A the frame's axis) are dropped, such gaps inside a run bridged when shorter
-- than EDGE_GAP_BRIDGE cells, chains shorter than EDGE_MIN_CHAIN cells dropped.
-- Output. Chains longest first, then by the first point's x and y, then in the order they were found; length = the main
-- chain's. With no kept striking part: no chain, all zero, the frame.
--
-- Translation. A Y or Z shift keeps the raster: no sample lies on a face of a snapped design, RASTER_TOL from one or on
-- a thin Wedge's edge, where rounding would decide (the cell centres did: C05, C09, C10 and C11 moved under E-S2.10's
-- offsets). A kept raster keeps the lattice, so the chains, their ties and lengths to the bit; a Y shift moves the
-- points by Δy. (Douglas–Peucker in blueprint XY carried the rounding of Y0 + (j0 + j)·h, which broke a tie or an
-- EDGE_MIN_CHAIN test the other way after a shift: |ΔG| 0.0037 on a generated design; docs/build/M3-notes.md.) But
-- where a part lies flush with the face a line leaves for a slanted hidden gap, which of the two ends the run there,
-- and so which hiddenGap asks, is rounding's call, which a Z shift makes again: a rib flush under a laminate turned
-- 30°, past which the far face's probe lands, reopens the gap at some shifts (the mean thickness 0.063386 or
-- 0.064654; §17.1 O11 (k), M3's review round 5).
-- Magnitudes: a design within Canonical's bounds (|pos| ≤ POS_ABS_MAX, sizes ≤ MAX_DIM) spans under 42.4 studs, so a
-- squared distance on the doubled lattice stays under 2^25 at a rung of ≤ EDGE_MAX_CELLS cells and under 2^18 at the
-- last; every product compared (a squared distance times a span's, tol² times a span's, tol² < 4 × the largest) stays
-- under 2^52, exact in a double.
--
-- Work (spend; one unit ≈ one shape query): per row of each rung the ladder tries, the kept parts; per cell,
-- 1 + 2 per striking part of its row (the dilated and the plain chord) + 1 per other part of it + hiddenGap's queries
-- (a normal, a box test or an sd each, all charged); per crack row, its cells; per crack edge, 1; per Douglas–Peucker
-- span, its points.

local Balance = require("../Definitions/Balance")
local DT = require("../Definitions/Types")
local Schema = require("../Blueprint/Schema")
local Sampling = require("./Sampling")
local Shapes = require("./Shapes")

type Prepared = Shapes.Prepared
type Spend = Sampling.Spend
type Vec3 = Schema.Vec3

export type Vec2 = { number } -- {x, y} array, blueprint XY
export type EdgeChain = { points: { Vec2 }, length: number } -- blueprint XY
export type EdgeProfile = {
	chains: { EdgeChain },
	length: number, -- the main chain's (EdgeLength, §5.2)
	cell: number, -- the raster's cell size (AnalysisBudget.edgeCell)
	bladeArea: number,
	bladeMeanThickness: number,
	gripPoint: Vec3, -- the difficulty frame, for sidesFromChains
	gripAxis: Vec2,
}
export type RasterStats = { cells: number, work: number } -- the chosen rung's, against EDGE_MAX_CELLS and EDGE_MAX_WORK

local sqrt, floor, max, min, abs = math.sqrt, math.floor, math.max, math.min, math.abs
local chord, sd, aabbContains = Shapes.chord, Shapes.sd, Shapes.aabbContains

local Geo = Balance.Geometry
local HIDE_OFFSET, EPS_GEOM = Geo.HIDE_OFFSET, Geo.EPS_GEOM
local MERGE_GAP = HIDE_OFFSET + EPS_GEOM -- what the verdict hides across (§4.4): a gap it hides is no gap
local REACH = HIDE_OFFSET + 2 * EPS_GEOM -- how far a face's probe can lie in the other part, rounding allowed
-- Not tunables, and not mere guards: where a cell is read moves edges (0.0012 / 0.0018 moves 14 of T-DIF-12's 70
-- golden entries: C06's EdgeLength, P2's chains, P5's cutIndex), so a change goes with BALANCE_VERSION (§16.18). A
-- cell is sampled this far from its centre, towards x = 0 (so a mirror image keeps its raster) and up. Cell centres lie
-- on the 0.0025 grid (x from 0, y from Y0), so every sample is ≥ 0.0002 off any multiple of 0.0005: no face of a design
-- snapped to such a step (0.001, 0.0025, 0.005, 0.01, …), nor RASTER_TOL from one, holds a sample, and no rounding
-- decides a cell that a shift could decide again
local SAMPLE_X, SAMPLE_Y = 0.0013, 0.0017
local BLADE_LENGTH_FLOOR = 1e-6 -- numeric guard, not a tunable: cutIndex's blade length at least this
-- A right turn from crack direction d (0 +x, 1 +y, 2 −x, 3 −y) is RIGHT[d + 1].
local RIGHT: { number } = table.freeze({ 3, 0, 1, 2 })

local function noSpend(_: number) end

-- The outward unit normal at a point of p's surface: the largest term of Shapes.sdLocal there (above), in the world.
local function normalAt(p: Prepared, x: number, y: number, z: number): (number, number, number)
	local lx, ly, lz = Shapes.toLocal(p, x, y, z)
	local code = p.code
	local nx, ny, nz
	if code == Shapes.BALL then
		local l = sqrt(lx * lx + ly * ly + lz * lz)
		nx, ny, nz = lx / l, ly / l, lz / l
	elseif code == Shapes.CYLINDER then
		local rho = sqrt(ly * ly + lz * lz)
		if abs(lx) - p.hx >= rho - p.r then
			nx, ny, nz = if lx >= 0 then 1 else -1, 0, 0
		else
			nx, ny, nz = 0, ly / rho, lz / rho
		end
	else
		local best = abs(lx) - p.hx
		nx, ny, nz = if lx >= 0 then 1 else -1, 0, 0
		local dy, dz = abs(ly) - p.hy, abs(lz) - p.hz
		if dy > best then
			best = dy
			nx, ny, nz = 0, if ly >= 0 then 1 else -1, 0
		end
		if dz > best then
			best = dz
			nx, ny, nz = 0, 0, if lz >= 0 then 1 else -1
		end
		if code == Shapes.WEDGE then
			if (ly * p.hz - lz * p.hy) * p.k1 > best then
				nx, ny, nz = 0, p.hz * p.k1, -p.hy * p.k1
			end
		elseif code == Shapes.CORNER then
			local s1 = (ly * p.hx - lx * p.hy) * p.k1
			if s1 > best then
				best = s1
				nx, ny, nz = -p.hy * p.k1, p.hx * p.k1, 0
			end
			if (ly * p.hz + lz * p.hy) * p.k2 > best then
				nx, ny, nz = 0, p.hz * p.k2, p.hy * p.k2
			end
		end
	end
	return nx * p.ux + ny * p.vx + nz * p.wx, nx * p.uy + ny * p.vy + nz * p.wy, nx * p.uz + ny * p.vz + nz * p.wz
end

-- Does q hold the point within EPS_GEOM (its box, then its sd)? And the shape queries: a unit a box test, a unit an sd.
local function held(q: Prepared, x: number, y: number, z: number): (boolean, number)
	if not aabbContains(q, x, y, z, 2 * EPS_GEOM) then
		return false, 1
	end
	return sd(q, x, y, z) <= EPS_GEOM, 2
end

-- Does the verdict hide the gap a line crosses from p, which it leaves at e, to q, which it meets at f (hidden gaps,
-- above)? And the shape queries made.
local function hiddenGap(p: Prepared, ex: number, ey: number, ez: number, q: Prepared, fx: number, fy: number,
	fz: number): (boolean, number)
	local dx, dy, dz = fx - ex, fy - ey, fz - ez
	local nx, ny, nz = normalAt(p, ex, ey, ez)
	if dx * nx + dy * ny + dz * nz > REACH then
		return false, 1
	end
	local hidden, units = held(q, ex + HIDE_OFFSET * nx, ey + HIDE_OFFSET * ny, ez + HIDE_OFFSET * nz)
	if not hidden then
		return false, 1 + units
	end
	nx, ny, nz = normalAt(q, fx, fy, fz)
	local more
	hidden, more = held(p, fx + HIDE_OFFSET * nx, fy + HIDE_OFFSET * ny, fz + HIDE_OFFSET * nz)
	return hidden, 2 + units + more
end

-- The union length of n intervals (lo, hi flat in ivs), gaps up to tol merged, and hiddenGap's shape queries. Sorts
-- ivs's first n in place by their start, insertion (stable), as the prototype. With own (each interval's part, sorted
-- along with it) and the Z line's (x, y), a wider gap merges too where the verdict hides it (hiddenGap).
local function mergeSorted(ivs: { number }, n: number, tol: number, own: { Prepared }?, x: number?,
	y: number?): (number, number)
	for i = 2, n do
		local a, b = ivs[2 * i - 1], ivs[2 * i]
		local q = if own then own[i] else nil
		local j = i - 1
		while j >= 1 and ivs[2 * j - 1] > a do
			ivs[2 * j + 1], ivs[2 * j + 2] = ivs[2 * j - 1], ivs[2 * j]
			if own then
				own[j + 1] = own[j]
			end
			j -= 1
		end
		ivs[2 * j + 1], ivs[2 * j + 2] = a, b
		if own then
			own[j + 1] = q :: Prepared
		end
	end
	local total, queries = 0, 0
	local lo, hi = ivs[1], ivs[2]
	local last = if own then own[1] else nil -- the part whose chord ends at hi
	for i = 2, n do
		local a, b = ivs[2 * i - 1], ivs[2 * i]
		local join = a <= hi + tol
		if not join and own and last then
			local px, py = x :: number, y :: number
			local units
			join, units = hiddenGap(last, px, py, hi, own[i], px, py, a)
			queries += units
		end
		if join then
			if b > hi then
				hi = b
				last = if own then own[i] else nil
			end
		else
			total += hi - lo
			lo, hi = a, b
			last = if own then own[i] else nil
		end
	end
	return total + (hi - lo), queries
end

local Edge = {}

-- n ≥ 1 intervals; ivs is left as it was.
function Edge.mergedLength(ivs: { number }, n: number, tol: number): number
	return (mergeSorted(table.move(ivs, 1, 2 * n, 1, table.create(2 * n, 0)), n, tol))
end

Edge.hiddenGap = hiddenGap

-- Douglas–Peucker on an open polyline of lattice points (integer coordinates, ≥ 2 points): the indices kept, ascending.
-- A span's farthest point from its segment (from the nearer end past either end; from its first point when its ends
-- meet, a closed run) is kept when farther than tol, and splits it; ties keep the first point. A distance is compared
-- squared and times the span's squared length, so between integers, exactly: cross² inside the segment, |ap|²·|ab|²
-- or |bp|²·|ab|² past its ends, against tol²·|ab|² (tol² alone where the ends meet). spend: a span's points.
function Edge.simplify(xs: { number }, ys: { number }, tol: number, spend: Spend?): { number }
	local work = spend or noSpend
	local n = #xs
	local keep: { boolean } = table.create(n, false)
	keep[1], keep[n] = true, true
	local stack: { number } = { 1, n }
	local top = 2
	local tol2 = tol * tol
	while top > 0 do
		local a, b = stack[top - 1], stack[top]
		top -= 2
		work(b - a)
		local ax, ay = xs[a], ys[a]
		local dx, dy = xs[b] - ax, ys[b] - ay
		local ll = dx * dx + dy * dy
		local best, bi = -1, 0
		for i = a + 1, b - 1 do
			local px, py = xs[i] - ax, ys[i] - ay
			local d2: number
			if ll == 0 then
				d2 = px * px + py * py
			else
				local dot = px * dx + py * dy
				if dot <= 0 then
					d2 = (px * px + py * py) * ll
				elseif dot >= ll then
					local qx, qy = px - dx, py - dy
					d2 = (qx * qx + qy * qy) * ll
				else
					local cross = px * dy - py * dx
					d2 = cross * cross
				end
			end
			if d2 > best then
				best, bi = d2, i
			end
		end
		if best > (if ll == 0 then tol2 else tol2 * ll) then
			keep[bi] = true
			stack[top + 1], stack[top + 2], stack[top + 3], stack[top + 4] = a, bi, bi, b
			top += 4
		end
	end
	local out: { number } = {}
	for i = 1, n do
		if keep[i] then
			table.insert(out, i)
		end
	end
	return out
end

function Edge.cutIndex(bladeLength: number, bladeMeanThickness: number): number
	if bladeMeanThickness <= 0 then
		return 0
	end
	local x = (max(bladeLength, BLADE_LENGTH_FLOOR) / bladeMeanThickness - Geo.CUT_LO) / (Geo.CUT_HI - Geo.CUT_LO)
	return if x < 0 then 0 elseif x > 1 then 1 else x
end

function Edge.profile(list: { Prepared }, kept: { boolean }, geometry: DT.GeometryRules, gripPoint: Vec3,
	gripAxis: Vec2, spend: Spend?): (EdgeProfile, RasterStats)
	local work = spend or noSpend
	local RT = Geo.RASTER_TOL
	local blade: { Prepared }, hilt: { Prepared } = {}, {}
	for r = 1, #list do
		if kept[r] then
			table.insert(if list[r].slot == geometry.strikingSlot then blade else hilt, list[r])
		end
	end
	local chains: { EdgeChain } = {}
	local profile: EdgeProfile = {
		chains = chains,
		length = 0,
		cell = 0,
		bladeArea = 0,
		bladeMeanThickness = 0,
		gripPoint = { gripPoint[1], gripPoint[2], gripPoint[3] },
		gripAxis = { gripAxis[1], gripAxis[2] },
	}
	if #blade == 0 then
		return profile, { cells = 0, work = 0 }
	end
	local nb, nh = #blade, #hilt
	local mnx, mxx, mny, mxy = math.huge, -math.huge, math.huge, -math.huge
	for k = 1, nb do
		local b = blade[k]
		mnx, mxx, mny, mxy = min(mnx, b.minx), max(mxx, b.maxx), min(mny, b.miny), max(mxy, b.maxy)
	end
	local Y0 = mny

	-- The lattice of cell size h: ni columns from i0 and nj rows from j0 (cell centres x = (i0 + i + ½)·h,
	-- y = Y0 + (j0 + j + ½)·h), one empty cell round the dilated box.
	local function lattice(h: number): (number, number, number, number)
		local i0, j0 = floor((mnx - RT) / h) - 1, floor(-RT / h) - 1
		return i0, j0, floor((mxx + RT) / h) + 2 - i0, floor((mxy + RT - Y0) / h) + 2 - j0
	end

	-- 1 the ladder: cells and cell × part tests of each rung, until both fit
	local rungWork = 0
	local function rungFits(h: number): boolean
		local _, j0, ni, nj = lattice(h)
		local tests = 0
		for j = 0, nj - 1 do
			local y = Y0 + (j0 + j + 0.5) * h + SAMPLE_Y
			local c = 0
			for k = 1, nb do
				if y >= blade[k].miny - RT and y <= blade[k].maxy + RT then
					c += 1
				end
			end
			for k = 1, nh do
				if y >= hilt[k].miny - RT and y <= hilt[k].maxy + RT then
					c += 1
				end
			end
			tests += ni * c
			work(nb + nh)
		end
		rungWork = tests -- the ladder stops at the rung it returns: the last one tried
		return ni * nj <= Geo.EDGE_MAX_CELLS and tests <= Geo.EDGE_MAX_WORK
	end
	local H = Sampling.ladder(Geo.EDGE_CELL, rungFits)
	local i0, j0, NI, NJ = lattice(H)
	local cells = NI * NJ

	-- 2 the raster: covered, thickness and hilt per cell (index j·NI + i + 1)
	local cov: { boolean } = table.create(cells, false)
	local thick: { number } = table.create(cells, 0)
	local hil: { boolean } = table.create(cells, false)
	local coveredU, thickSum = 0, 0
	local function raster()
		local rowB: { Prepared }, rowH: { Prepared } = table.create(nb), table.create(nh)
		local ivs: { number }, ivd: { number } = table.create(2 * nb, 0), table.create(2 * nb, 0)
		local own: { Prepared } = table.create(nb)
		for j = 0, NJ - 1 do
			local y = Y0 + (j0 + j + 0.5) * H + SAMPLE_Y
			local rb, rh = 0, 0
			for k = 1, nb do
				if y >= blade[k].miny - RT and y <= blade[k].maxy + RT then
					rb += 1
					rowB[rb] = blade[k]
				end
			end
			for k = 1, nh do
				if y >= hilt[k].miny - RT and y <= hilt[k].maxy + RT then
					rh += 1
					rowH[rh] = hilt[k]
				end
			end
			for i = 0, NI - 1 do
				local centre = (i0 + i + 0.5) * H -- never 0
				local x = if centre > 0 then centre - SAMPLE_X else centre + SAMPLE_X
				local idx = j * NI + i + 1
				local n, nd, extra = 0, 0, 0
				for k = 1, rb do
					local b = rowB[k]
					if x >= b.minx - RT and x <= b.maxx + RT then
						local ok, t0, t1 = chord(b, x, y, 0, 0, 0, 1, RT)
						if ok and t1 > t0 then
							nd += 1
							ivd[2 * nd - 1], ivd[2 * nd] = t0, t1
							local plain, s0, s1 = chord(b, x, y, 0, 0, 0, 1)
							if plain and s1 > s0 then
								n += 1
								ivs[2 * n - 1], ivs[2 * n] = s0, s1
								own[n] = b
							end
						end
					end
				end
				if nd > 0 then
					cov[idx] = true
					if n > 0 then
						if n == 1 then -- one chord: its length, as mergeSorted would give it
							thick[idx] = ivs[2] - ivs[1]
						else
							thick[idx], extra = mergeSorted(ivs, n, MERGE_GAP, own, x, y)
						end
						coveredU += 1
						thickSum += thick[idx]
					else
						thick[idx] = (mergeSorted(ivd, nd, MERGE_GAP))
					end
				end
				for k = 1, rh do
					local p = rowH[k]
					if x >= p.minx - RT and x <= p.maxx + RT then
						local ok, t0, t1 = chord(p, x, y, 0, 0, 0, 1, RT)
						if ok and t1 >= t0 then
							hil[idx] = true
							break
						end
					end
				end
				work(1 + 2 * rb + rh + extra)
			end
		end
	end
	raster()
	profile.cell = H
	profile.bladeArea = coveredU * H * H
	profile.bladeMeanThickness = if coveredU > 0 then thickSum / coveredU else 0

	-- 3 crack edges, the covered cell on the left: from (fi, fj) to (ti, tj) on the vertex lattice, direction, inner
	-- and outer cell; outA, outB the (at most two) edges leaving each vertex (index vj·VI + vi + 1)
	local VI = NI + 1
	local fi: { number }, fj: { number }, ti: { number }, tj: { number } = {}, {}, {}, {}
	local dir: { number }, inner: { number }, outer: { number } = {}, {}, {}
	local outA: { number } = table.create(VI * (NJ + 1), 0)
	local outB: { number } = table.create(VI * (NJ + 1), 0)
	local ne = 0
	local function addEdge(ai: number, aj: number, bi: number, bj: number, d: number, inIdx: number, outIdx: number)
		ne += 1
		fi[ne], fj[ne], ti[ne], tj[ne], dir[ne], inner[ne], outer[ne] = ai, aj, bi, bj, d, inIdx, outIdx
		local v = aj * VI + ai + 1
		if outA[v] == 0 then
			outA[v] = ne
		else
			outB[v] = ne
		end
	end
	local function covered(i: number, j: number): boolean
		return i >= 0 and j >= 0 and i < NI and j < NJ and cov[j * NI + i + 1]
	end
	local function crackEdges()
		for j = 0, NJ - 1 do
			work(NI)
			for i = 0, NI - 1 do
				local idx = j * NI + i + 1
				if cov[idx] then
					if not covered(i, j - 1) then
						addEdge(i, j, i + 1, j, 0, idx, idx - NI)
					end
					if not covered(i + 1, j) then
						addEdge(i + 1, j, i + 1, j + 1, 1, idx, idx + 1)
					end
					if not covered(i, j + 1) then
						addEdge(i + 1, j + 1, i, j + 1, 2, idx, idx + NI)
					end
					if not covered(i - 1, j) then
						addEdge(i, j + 1, i, j, 3, idx, idx - 1)
					end
				end
			end
		end
	end
	crackEdges()

	-- 4 a run of crack edges → its chains (emission order kept for the sort's last key), on the doubled lattice
	local ax, ay = gripAxis[1], gripAxis[2]
	local half = H / 2
	local function emitRun(run: { number }, count: number)
		local n = count + 2
		local xs: { number }, ys: { number } = table.create(n, 0), table.create(n, 0)
		xs[1], ys[1] = 2 * fi[run[1]], 2 * fj[run[1]]
		for k = 1, count do
			local e = run[k]
			xs[k + 1], ys[k + 1] = fi[e] + ti[e], fj[e] + tj[e]
		end
		xs[n], ys[n] = 2 * ti[run[count]], 2 * tj[run[count]]
		local tol = 2 * Geo.EDGE_SIMPLIFY -- cells, in doubled lattice units
		local pick = Edge.simplify(xs, ys, tol, work)
		while #pick > Geo.EDGE_MAX_POINTS do
			tol *= 2
			pick = Edge.simplify(xs, ys, tol, work)
		end
		local m = #pick - 1
		local segLen: { number }, sharp: { boolean } = table.create(m, 0), table.create(m, false)
		for s = 1, m do
			local dx, dy = xs[pick[s + 1]] - xs[pick[s]], ys[pick[s + 1]] - ys[pick[s]]
			local l = sqrt(dx * dx + dy * dy)
			segLen[s] = l * half
			-- the outward normal of a counter-clockwise outline's segment is (dy, −dx)/l
			sharp[s] = l > 0 and (dy * ax - dx * ay) / l >= -Geo.EDGE_DOWN_COS
		end
		local s = 1
		while s <= m do
			if not sharp[s] then
				local e, gap = s, 0
				while e <= m and not sharp[e] do
					gap += segLen[e]
					e += 1
				end
				if s > 1 and e <= m and gap < Geo.EDGE_GAP_BRIDGE * H then
					for q = s, e - 1 do
						sharp[q] = true
					end
				end
				s = e
			else
				s += 1
			end
		end
		local points: { Vec2 }? = nil
		local length = 0
		local function point(k: number): Vec2
			return { (i0 + xs[k] / 2) * H, Y0 + (j0 + ys[k] / 2) * H }
		end
		local function flush()
			if points ~= nil and length >= Geo.EDGE_MIN_CHAIN * H then
				table.insert(chains, { points = points, length = length })
			end
			points, length = nil, 0
		end
		for q = 1, m do
			if sharp[q] then
				local open = points or { point(pick[q]) }
				table.insert(open, point(pick[q + 1]))
				points = open
				length += segLen[q]
			else
				flush()
			end
		end
		flush()
	end

	-- 5 loops: turn right first at a vertex with two ways out; outer loops (positive area) give their eligible runs
	local function traceLoops()
		local used: { boolean } = table.create(ne, false)
		local loop: { number }, elig: { boolean }, run: { number } = {}, {}, {}
		for e0 = 1, ne do
			work(1)
			if not used[e0] then
				local m = 0
				local e = e0
				while true do
					used[e] = true
					m += 1
					loop[m] = e
					local v = tj[e] * VI + ti[e] + 1
					local a, b = outA[v], outB[v]
					local nxt = a
					if b ~= 0 then
						local right = RIGHT[dir[e] + 1]
						if dir[a] == right and not used[a] then
							nxt = a
						elseif dir[b] == right and not used[b] then
							nxt = b
						else
							nxt = if not used[a] then a else b
						end
					end
					if nxt == 0 or nxt == e0 or used[nxt] then
						break
					end
					e = nxt
				end
				local area = 0 -- twice the loop's signed area, in cells
				for k = 1, m do
					local c = loop[k]
					area += fi[c] * tj[c] - ti[c] * fj[c]
				end
				if area > 0 then
					local startAt = 0
					for k = 1, m do
						local c = loop[k]
						local o = outer[c]
						elig[k] = not (o >= 1 and o <= cells and hil[o]) and thick[inner[c]] <= Geo.EDGE_MAX_THICK
						if not elig[k] and startAt == 0 then
							startAt = k
						end
					end
					if startAt == 0 then
						local low = 1
						for k = 2, m do
							local c, l = loop[k], loop[low]
							if fj[c] < fj[l] or (fj[c] == fj[l] and fi[c] < fi[l]) then
								low = k
							end
						end
						for s = 0, m - 1 do
							local k = low + s
							if k > m then
								k -= m
							end
							run[s + 1] = loop[k]
						end
						emitRun(run, m)
					else
						local count = 0
						local k = startAt
						for _ = 1, m do
							if elig[k] then
								count += 1
								run[count] = loop[k]
							elseif count > 0 then
								emitRun(run, count)
								count = 0
							end
							k += 1
							if k > m then
								k -= m
							end
						end
						if count > 0 then
							emitRun(run, count)
						end
					end
				end
			end
		end
	end
	traceLoops()

	-- 6 the chains in a total order: longest first, then the first point's x, y, then the order found
	local order: { number } = table.create(#chains, 0)
	for k = 1, #chains do
		order[k] = k
	end
	table.sort(order, function(a: number, b: number): boolean
		local ca, cb = chains[a], chains[b]
		if ca.length ~= cb.length then
			return ca.length > cb.length
		end
		local pa, pb = ca.points[1], cb.points[1]
		if pa[1] ~= pb[1] then
			return pa[1] < pb[1]
		end
		if pa[2] ~= pb[2] then
			return pa[2] < pb[2]
		end
		return a < b
	end)
	local sorted: { EdgeChain } = table.create(#chains)
	for k = 1, #order do
		sorted[k] = chains[order[k]]
	end
	profile.chains = sorted
	profile.length = if #sorted > 0 then sorted[1].length else 0
	return profile, { cells = cells, work = rungWork }
end

return table.freeze(Edge)
