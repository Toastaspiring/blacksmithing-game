--!strict
-- Physics/MassProps (SPEC §4.3, §4.5; owner S2): who owns each overlap, then mass, centre of mass and the sword's
-- frames and lengths. Pure; §4.1's determinism rules apply. Exact for polyhedra. No inertia in the MVP (§4.7, §15.1).
--
-- Overlap ownership (§4.3). An overlap counts once, for its owner. Priority: kept parts, then slot rank (§3.7), then the
-- larger part (Sampling.measureRanked, so no id decides). V_own(p) = V_p − V(p ∩ ∪ higher(p)), with the first moment
-- likewise:
--   exactOverlap    all polyhedra and ≤ MAX_EXACT higher overlapping parts: exact convex clipping, inclusion–exclusion
--                   over the subsets, volume and moment by tetrahedra
--   sampledOverlap  otherwise (a Ball or Cylinder involved, or more parts): midpoint sampling of the overlap box in p's
--                   frame at H_OVERLAP (OVERLAP_N_MIN–OVERLAP_N_MAX cells per axis), coarsened to fit N_OVERLAP_WORK,
--                   kept parts first
-- An exact copy of a part above it (Shapes.sameSolid) owns nothing, exactly, whatever its shape.
-- The clipping differs from the prototype's on purpose. Its cut face was made of the vertices found on the plane: a face
-- 3e-13 to 3e-11 off the plane, some vertices past CLIP_EPS and others within it, got covered twice, and repeated cuts
-- could leave two section loops joined into one polygon, so a near copy could own up to all of its volume. Here the cut
-- face comes from the plane itself and a vertex is in or out by its sign alone. Crossings on such a face are still
-- ill-conditioned, which leaves up to about 3e-4 of the part's volume; everywhere else the numbers are the prototype's
-- within 4e-15.
--
-- Mass (§4.5). U = Σ V_own, M = Σ ρ·V_own, COM = Σ ρ·M1_own / M, in part order; ρ = Definitions/Materials.density.
-- Physics frame = all Grip parts (balance, reach, display pivot); cleaned parts count for mass, COM and this frame
-- (a lead core is a legal balance trick; an enclosed part owns no volume), never for reach or the blade's length.
-- Difficulty frame = the point of the kept Grip parts, axis fixed at blueprint +Y, consistent with the fixed plane
-- x = 0: no grip part, visible or hidden, can steer a factor (A25–A27, E-S2.7).

local Balance = require("../Definitions/Balance")
local DT = require("../Definitions/Types")
local Materials = require("../Definitions/Materials")
local Schema = require("../Blueprint/Schema")
local Gjk = require("./Gjk")
local Sampling = require("./Sampling")
local Shapes = require("./Shapes")

type Prepared = Shapes.Prepared
type Spend = Sampling.Spend
type Vec3 = Schema.Vec3

export type Vec2 = { number } -- {x, y} array, blueprint XY

-- The part of Analyze's PhysicsReport this module computes (§4.7).
export type MassReport = {
	mass: number,
	volume: number,
	com: Vec3,
	gripPoint: Vec3,
	gripAxis: Vec2,
	guardPos: number,
	balance: number,
	balanceFromHand: number,
	reach: number,
	bladeLength: number,
	totalLength: number,
	comOffAxis: number,
	ownedVolume: { number }, -- per part, in blueprint order
}

export type Ownership = {
	ownedVolume: { number }, -- V_own per part, in blueprint order
	overlapVolume: { number }, -- V(p ∩ ∪ higher(p)) per part
	overlapX: { number }, -- its first moment per part
	overlapY: { number },
	overlapZ: { number },
	higher: { { Prepared } }, -- per part: the higher-priority parts that overlap it (M3's owned-probe test)
	hOverlap: number, -- kept parts' spacing: fits N_OVERLAP_WORK
	refinedCells: number, -- overlap cells sampled
}

local sqrt, max, min, ceil, floor, abs = math.sqrt, math.max, math.min, math.ceil, math.floor, math.abs
local aabbOverlap, aabbContains = Shapes.aabbOverlap, Shapes.aabbContains

local Geo = Balance.Geometry
local MAX_EXACT = Geo.MAX_EXACT

local OVERLAP_TOL = 1e-9 -- parts that merely touch own their whole volume; GJK decides at this gap
local CLIP_EPS = 1e-12 -- a solid no further than this past a clipping plane does not cross it (rounding of flush parts)
local INSIDE_MARGIN = Sampling.INSIDE_MARGIN -- §4.3: a cell centre counts iff sd < −1e-9

local UNITS_PER_SUBSET = 250 -- one clipped subset costs about this many shape queries (checkpoints only)
local UNITS_PER_OVERLAP_TEST = 20 -- one GJK query

local function noSpend(_: number) end

local MassProps = {}

-- ── exact overlaps: convex clipping ───────────────────────────────────────────────────────────────────────────────

-- A polygon (flat x, y, z) clipped to n·x ≤ d. A vertex is in or out by the sign alone, so a polygon never disagrees with
-- itself; fewer than 3 vertices means nothing is left.
local function clipPolygon(poly: { number }, nx: number, ny: number, nz: number, d: number): { number }
	local out: { number } = {}
	local m = #poly / 3
	for i = 0, m - 1 do
		local j = if i == m - 1 then 0 else i + 1
		local ax, ay, az = poly[3 * i + 1], poly[3 * i + 2], poly[3 * i + 3]
		local bx, by, bz = poly[3 * j + 1], poly[3 * j + 2], poly[3 * j + 3]
		local da = nx * ax + ny * ay + nz * az - d
		local db = nx * bx + ny * by + nz * bz - d
		if da <= 0 then
			table.insert(out, ax)
			table.insert(out, ay)
			table.insert(out, az)
		end
		if (da > 0) ~= (db > 0) then
			local t = da / (da - db)
			table.insert(out, ax + t * (bx - ax))
			table.insert(out, ay + t * (by - ay))
			table.insert(out, az + t * (bz - az))
		end
	end
	return out
end

-- The cut face on the plane n·x = d: a square around p, wider than p, counter-clockwise about +n, clipped by the planes
-- that cut so far. It comes from the plane, not from where other faces crossed it, so nearly coplanar faces cannot make
-- it wrong: it needs no ordering, and no second loop can join it.
local function capOn(p: Prepared, nx: number, ny: number, nz: number, d: number, active: { { number } }): { number }
	-- an in-plane basis: a perpendicular to n, b = n × a
	local ax, ay, az
	if abs(nx) <= abs(ny) and abs(nx) <= abs(nz) then
		ax, ay, az = 0, -nz, ny
	elseif abs(ny) <= abs(nz) then
		ax, ay, az = -nz, 0, nx
	else
		ax, ay, az = -ny, nx, 0
	end
	local l = sqrt(ax * ax + ay * ay + az * az)
	ax, ay, az = ax / l, ay / l, az / l
	local bx, by, bz = ny * az - nz * ay, nz * ax - nx * az, nx * ay - ny * ax
	local s = 2 * (p.hx + p.hy + p.hz)
	local off = nx * p.gx + ny * p.gy + nz * p.gz - d
	local cx, cy, cz = p.gx - off * nx, p.gy - off * ny, p.gz - off * nz
	local poly: { number } = {
		cx - s * ax - s * bx, cy - s * ay - s * by, cz - s * az - s * bz,
		cx + s * ax - s * bx, cy + s * ay - s * by, cz + s * az - s * bz,
		cx + s * ax + s * bx, cy + s * ay + s * by, cz + s * az + s * bz,
		cx - s * ax + s * bx, cy - s * ay + s * by, cz - s * az + s * bz,
	}
	for i = 1, #active do
		local plane = active[i]
		poly = clipPolygon(poly, plane[1], plane[2], plane[3], plane[4])
		if #poly < 9 then
			return poly
		end
	end
	return poly
end

-- A closed convex polyhedron (faces counter-clockwise from outside, flat x, y, z) clipped to n·x ≤ d, capping the cut.
-- active holds the half-spaces of the solid so far and takes this one if it cuts. A solid on one side within CLIP_EPS is
-- left untouched, or (a contact, no volume) emptied, so flush parts stay exact.
local function clip(p: Prepared, faces: { { number } }, plane: { number }, active: { { number } }): { { number } }
	local nx, ny, nz, d = plane[1], plane[2], plane[3], plane[4]
	local above, below = false, false
	for f = 1, #faces do
		local poly = faces[f]
		for i = 1, #poly, 3 do
			local da = nx * poly[i] + ny * poly[i + 1] + nz * poly[i + 2] - d
			above = above or da > CLIP_EPS
			below = below or da < -CLIP_EPS
		end
	end
	if not above then
		return faces
	end
	if not below then
		return {}
	end
	local out: { { number } } = {}
	for f = 1, #faces do
		local kept = clipPolygon(faces[f], nx, ny, nz, d)
		if #kept >= 9 then
			table.insert(out, kept)
		end
	end
	local cap = capOn(p, nx, ny, nz, d, active)
	if #cap >= 9 then
		table.insert(out, cap)
	end
	table.insert(active, plane)
	return out
end

-- Volume and world first moment of a closed polyhedron given as outward faces, by tetrahedra from its first vertex.
local function volumeAndMoment(faces: { { number } }): (number, number, number, number)
	if #faces == 0 then
		return 0, 0, 0, 0
	end
	local first = faces[1]
	local ox, oy, oz = first[1], first[2], first[3]
	local V, Mx, My, Mz = 0, 0, 0, 0
	for f = 1, #faces do
		local poly = faces[f]
		local m = #poly / 3
		local ax, ay, az = poly[1] - ox, poly[2] - oy, poly[3] - oz
		for i = 1, m - 2 do
			local bx, by, bz = poly[3 * i + 1] - ox, poly[3 * i + 2] - oy, poly[3 * i + 3] - oz
			local cx, cy, cz = poly[3 * i + 4] - ox, poly[3 * i + 5] - oy, poly[3 * i + 6] - oz
			local det = ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx) + az * (bx * cy - by * cx)
			local v = det / 6
			V += v
			Mx += v * (ax + bx + cx) / 4
			My += v * (ay + by + cy) / 4
			Mz += v * (az + bz + cz) / 4
		end
	end
	if V <= 0 then
		return 0, 0, 0, 0
	end
	return V, Mx + V * ox, My + V * oy, Mz + V * oz
end

-- V(p ∩ q1 ∩ … ∩ qk) and its first moment; polyhedra only.
local function intersection(p: Prepared, list: { Prepared }): (number, number, number, number)
	local faces = Shapes.faces(p)
	local active = Shapes.planes(p)
	for i = 1, #list do
		local planes = Shapes.planes(list[i])
		for k = 1, #planes do
			faces = clip(p, faces, planes[k], active)
			if #faces == 0 then
				return 0, 0, 0, 0
			end
		end
	end
	return volumeAndMoment(faces)
end

-- Exact V(p ∩ (q1 ∪ … ∪ qk)) and its first moment by inclusion–exclusion over the non-empty subsets of H.
function MassProps.exactOverlap(p: Prepared, H: { Prepared }, spend: Spend?): (number, number, number, number)
	local work = spend or noSpend
	local k = #H
	local subsets = 1
	for _ = 1, k do
		subsets *= 2
	end
	local V, Mx, My, Mz = 0, 0, 0, 0
	for mask = 1, subsets - 1 do
		work(UNITS_PER_SUBSET)
		local list: { Prepared } = {}
		local rest = mask
		for i = 1, k do -- the bits of mask, H[1] first
			local half = floor(rest / 2)
			if rest - 2 * half == 1 then
				table.insert(list, H[i])
			end
			rest = half
		end
		local v, mx, my, mz = intersection(p, list)
		local sign = if 2 * floor(#list / 2) == #list then -1 else 1
		V, Mx, My, Mz = V + sign * v, Mx + sign * mx, My + sign * my, Mz + sign * mz
	end
	return max(0, V), Mx, My, Mz
end

-- ── refined overlaps: midpoint sampling ───────────────────────────────────────────────────────────────────────────

-- The box of p's frame that holds p ∩ (q's AABB) for every q in H, clamped to p's half extents.
function MassProps.overlapBox(p: Prepared, H: { Prepared }): (Vec3, Vec3)
	local lo: Vec3 = { math.huge, math.huge, math.huge }
	local hi: Vec3 = { -math.huge, -math.huge, -math.huge }
	for n = 1, #H do
		local q = H[n]
		local qloA, qloB, qloD = math.huge, math.huge, math.huge
		local qhiA, qhiB, qhiD = -math.huge, -math.huge, -math.huge
		for c = 0, 7 do
			local x = if c == 1 or c == 3 or c == 5 or c == 7 then q.maxx else q.minx
			local y = if c == 2 or c == 3 or c == 6 or c == 7 then q.maxy else q.miny
			local z = if c >= 4 then q.maxz else q.minz
			local a, b, d = Shapes.toLocal(p, x, y, z)
			qloA, qloB, qloD = min(qloA, a), min(qloB, b), min(qloD, d)
			qhiA, qhiB, qhiD = max(qhiA, a), max(qhiB, b), max(qhiD, d)
		end
		lo[1], hi[1] = min(lo[1], max(-p.hx, qloA)), max(hi[1], min(p.hx, qhiA))
		lo[2], hi[2] = min(lo[2], max(-p.hy, qloB)), max(hi[2], min(p.hy, qhiB))
		lo[3], hi[3] = min(lo[3], max(-p.hz, qloD)), max(hi[3], min(p.hz, qhiD))
	end
	return lo, hi
end

local function cellsPerAxis(lo: Vec3, hi: Vec3, k: number, h: number): number
	local extent = hi[k] - lo[k]
	if extent <= 0 then
		return 0
	end
	return max(Geo.OVERLAP_N_MIN, min(Geo.OVERLAP_N_MAX, ceil(extent / h)))
end

-- Midpoint sampling of V(p ∩ ∪ H) and its first moment over the box, at spacing h.
function MassProps.sampledOverlap(p: Prepared, H: { Prepared }, lo: Vec3, hi: Vec3, h: number,
	spend: Spend?): (number, number, number, number, number)
	local work = spend or noSpend
	local nx, ny, nz = cellsPerAxis(lo, hi, 1, h), cellsPerAxis(lo, hi, 2, h), cellsPerAxis(lo, hi, 3, h)
	if nx == 0 or ny == 0 or nz == 0 then
		return 0, 0, 0, 0, nx * ny * nz
	end
	local dx, dy, dz = (hi[1] - lo[1]) / nx, (hi[2] - lo[2]) / ny, (hi[3] - lo[3]) / nz
	local cell = dx * dy * dz
	local V, Mx, My, Mz = 0, 0, 0, 0
	local units = nz * (1 + #H)
	for i = 0, nx - 1 do
		local lx = lo[1] + (i + 0.5) * dx
		for j = 0, ny - 1 do
			local ly = lo[2] + (j + 0.5) * dy
			for k = 0, nz - 1 do
				local lz = lo[3] + (k + 0.5) * dz
				if Shapes.sdLocal(p, lx, ly, lz) < -INSIDE_MARGIN then
					local x, y, z = Shapes.toWorld(p, lx, ly, lz)
					for n = 1, #H do
						local q = H[n]
						if aabbContains(q, x, y, z, 0) and Shapes.sd(q, x, y, z) < -INSIDE_MARGIN then
							V += cell
							Mx += cell * x
							My += cell * y
							Mz += cell * z
							break
						end
					end
				end
			end
			work(units)
		end
	end
	return V, Mx, My, Mz, nx * ny * nz
end

-- ── ownership ─────────────────────────────────────────────────────────────────────────────────────────────────────

type OverlapJob = { p: Prepared, H: { Prepared }, exact: boolean, lo: Vec3, hi: Vec3 }

-- rankOf: the type's SlotDef.rank per slot id (lookup only).
function MassProps.ownership(parts: { Prepared }, kept: { boolean }, rankOf: { [string]: number },
	spend: Spend?): Ownership
	local work = spend or noSpend
	local N = #parts
	local order: { Prepared } = table.create(N)
	for i = 1, N do
		order[i] = parts[i]
	end
	-- a total order: kept parts, then slot rank, then the measure's rank
	local ranked = Sampling.measureRanked(parts)
	table.sort(order, function(a: Prepared, b: Prepared): boolean
		local keptA, keptB = kept[a.index], kept[b.index]
		if keptA ~= keptB then
			return keptA
		end
		local rankA, rankB = rankOf[a.slot], rankOf[b.slot]
		if rankA ~= rankB then
			return rankA < rankB
		end
		return ranked[a.index] < ranked[b.index]
	end)

	local higher: { { Prepared } } = table.create(N)
	local overlapVolume: { number } = table.create(N, 0)
	local overlapX: { number } = table.create(N, 0)
	local overlapY: { number } = table.create(N, 0)
	local overlapZ: { number } = table.create(N, 0)
	local jobs: { OverlapJob } = {}
	for r = 1, N do
		local p = order[r]
		local H: { Prepared } = {}
		for s = 1, r - 1 do
			local q = order[s]
			if aabbOverlap(p, q, 0) then
				work(UNITS_PER_OVERLAP_TEST)
				if (Gjk.within(p, q, OVERLAP_TOL)) then
					table.insert(H, q)
				end
			end
		end
		higher[p.index] = H
		local copy = false
		for s = 1, #H do
			copy = copy or Shapes.sameSolid(p, H[s])
		end
		if copy then
			-- all of it belongs to a part above it, exactly, whatever its shape
			local i = p.index
			overlapVolume[i] = p.volume
			overlapX[i], overlapY[i], overlapZ[i] = p.volume * p.gx, p.volume * p.gy, p.volume * p.gz
		elseif #H > 0 then
			local allPolyhedra = p.poly
			for s = 1, #H do
				allPolyhedra = allPolyhedra and H[s].poly
			end
			if allPolyhedra and #H <= MAX_EXACT then
				table.insert(jobs, { p = p, H = H, exact = true, lo = {}, hi = {} })
			else
				local lo, hi = MassProps.overlapBox(p, H)
				table.insert(jobs, { p = p, H = H, exact = false, lo = lo, hi = hi })
			end
		end
	end

	-- N_OVERLAP_WORK goes to kept parts first, and cleaned parts' jobs share what is left, so a cleaned part can never
	-- coarsen a kept part's V_own (§4.4: enclosed copies leave D bit-identical). A kept part's higher parts are all
	-- kept.
	local function jobWork(wantKept: boolean, h: number): number
		local est = 0
		for j = 1, #jobs do
			local job = jobs[j]
			if not job.exact and kept[job.p.index] == wantKept then
				local nx = cellsPerAxis(job.lo, job.hi, 1, h)
				local ny = cellsPerAxis(job.lo, job.hi, 2, h)
				local nz = cellsPerAxis(job.lo, job.hi, 3, h)
				est += nx * ny * nz * (1 + #job.H)
			end
		end
		return est
	end
	local hOverlap = Sampling.ladder(Geo.H_OVERLAP, function(h: number): boolean
		return jobWork(true, h) <= Geo.N_OVERLAP_WORK
	end)
	local workLeft = Geo.N_OVERLAP_WORK - jobWork(true, hOverlap)
	local hCleaned = Sampling.ladder(Geo.H_OVERLAP, function(h: number): boolean
		return jobWork(false, h) <= workLeft
	end)

	local refinedCells = 0
	for j = 1, #jobs do
		local job = jobs[j]
		local V, X, Y, Z
		if job.exact then
			V, X, Y, Z = MassProps.exactOverlap(job.p, job.H, work)
		else
			local cells
			local h = if kept[job.p.index] then hOverlap else hCleaned
			V, X, Y, Z, cells = MassProps.sampledOverlap(job.p, job.H, job.lo, job.hi, h, work)
			refinedCells += cells
		end
		local i = job.p.index
		overlapVolume[i] = min(V, job.p.volume)
		overlapX[i], overlapY[i], overlapZ[i] = X, Y, Z
	end

	local ownedVolume: { number } = table.create(N, 0)
	for i = 1, N do
		ownedVolume[i] = parts[i].volume - overlapVolume[i]
	end
	return {
		ownedVolume = ownedVolume,
		overlapVolume = overlapVolume,
		overlapX = overlapX,
		overlapY = overlapY,
		overlapZ = overlapZ,
		higher = higher,
		hOverlap = hOverlap,
		refinedCells = refinedCells,
	}
end

-- ── frames (§4.5) ─────────────────────────────────────────────────────────────────────────────────────────────────

-- A grip part's axis contribution in XY, ê_y ≥ 0: Cylinders local X; polyhedra whose longest half extent (ties
-- X < Y < Z) is ≥ AXIS_ELONGATION × the middle one; never Balls or dust; never a part whose axis, in 3D, tilts more than 45°
-- from +Y: a level crossbar or a handle along Z has no way up, and rounding or a 1° nudge would decide its vote. ê is a unit
-- vector, so its y is the cosine of that tilt. nil when the part has no axis or no vote.
local function axisOf(p: Prepared): (number?, number?)
	if p.volume < Geo.MIN_PART_VOLUME or p.code == Shapes.BALL then
		return nil, nil
	end
	local ex, ey
	if p.code == Shapes.CYLINDER then
		ex, ey = p.ux, p.uy
	else
		local hx, hy, hz = p.hx, p.hy, p.hz
		local longest, middle
		if hy > hx and hy >= hz then
			longest, middle, ex, ey = hy, max(hx, hz), p.vx, p.vy
		elseif hz > hx and hz > hy then
			longest, middle, ex, ey = hz, max(hx, hy), p.wx, p.wy
		else
			longest, middle, ex, ey = hx, max(hy, hz), p.ux, p.uy
		end
		if longest < Geo.AXIS_ELONGATION * middle then
			return nil, nil
		end
	end
	if ey < 0 then
		ex, ey = -ex, -ey
	end
	if ey < Geo.AXIS_MAX_TILT_COS then
		return nil, nil
	end
	return ex, ey
end

-- A frame from a list of Grip parts: the volume-weighted centroid, and the normalized Σ V·ê projected on XY (every vote
-- has ê_y ≥ AXIS_MAX_TILT_COS, so the sum tilts less than any vote can); (0, 1) if no part votes.
function MassProps.gripFrame(list: { Prepared }): (Vec3, Vec2)
	local gV, gX, gY, gZ = 0, 0, 0, 0
	local axX, axY = 0, 0
	for i = 1, #list do
		local p = list[i]
		gV += p.volume
		gX += p.volume * p.gx
		gY += p.volume * p.gy
		gZ += p.volume * p.gz
		local ex, ey = axisOf(p)
		if ex ~= nil and ey ~= nil then
			axX += p.volume * ex
			axY += p.volume * ey
		end
	end
	local point: Vec3 = { 0, 0, 0 }
	if gV > 0 then
		point = { gX / gV, gY / gV, gZ / gV }
	end
	local axis: Vec2 = { 0, 1 }
	if axY > 0 then
		local length = sqrt(axX * axX + axY * axY)
		axis = { axX / length, axY / length }
	end
	return point, axis
end

-- Physics frame: all parts of the grip slot, kept or cleaned.
function MassProps.physicsFrame(parts: { Prepared }, gripSlot: DT.SlotId): (Vec3, Vec2)
	local list: { Prepared } = {}
	for i = 1, #parts do
		if parts[i].slot == gripSlot then
			table.insert(list, parts[i])
		end
	end
	return MassProps.gripFrame(list)
end

-- Difficulty frame: the point of the kept parts of the grip slot, axis fixed at blueprint +Y.
function MassProps.difficultyFrame(parts: { Prepared }, kept: { boolean }, gripSlot: DT.SlotId): (Vec3, Vec2)
	local list: { Prepared } = {}
	for i = 1, #parts do
		if parts[i].slot == gripSlot and kept[i] then
			table.insert(list, parts[i])
		end
	end
	local point = MassProps.gripFrame(list)
	return point, { 0, 1 }
end

-- ── mass properties (§4.5) ────────────────────────────────────────────────────────────────────────────────────────

-- gripPoint and gripAxis: the physics frame. Parts carry their material id; density comes from Definitions/Materials
-- (retired rows stay readable). A design with no kept part of the striking slot (only measureInvalid reaches here with
-- one) has reach and bladeLength 0.
function MassProps.report(parts: { Prepared }, kept: { boolean }, owned: Ownership, geometry: DT.GeometryRules,
	gripPoint: Vec3, gripAxis: Vec2): MassReport
	local N = #parts
	local gx, gy, gz = gripPoint[1], gripPoint[2], gripPoint[3]
	local ax, ay = gripAxis[1], gripAxis[2]

	local U, M, Mx, My, Mz = 0, 0, 0, 0, 0
	local ownedVolume: { number } = table.create(N, 0)
	for i = 1, N do
		local p = parts[i]
		local def = Materials.get(p.material)
		if def == nil then
			error("MassProps.report: unknown material " .. tostring(p.material), 2)
		end
		local rho = def.density
		local own = owned.ownedVolume[i]
		ownedVolume[i] = own
		U += own
		M += rho * own
		if own > 0 then -- no volume of its own, no moment either: an enclosed copy leaves COM and balance bit-identical
			Mx += rho * (p.volume * p.gx - owned.overlapX[i])
			My += rho * (p.volume * p.gy - owned.overlapY[i])
			Mz += rho * (p.volume * p.gz - owned.overlapZ[i])
		end
	end
	local com: Vec3 = { Mx / M, My / M, Mz / M }

	-- the guard line, or the top of the grip without a guard
	local guardVolume, guardMoment = 0, 0
	local gripTop = -math.huge
	local gAlong = gx * ax + gy * ay
	for i = 1, N do
		local p = parts[i]
		if geometry.guardSlot ~= nil and p.slot == geometry.guardSlot then
			guardVolume += p.volume
			guardMoment += p.volume * ((p.gx - gx) * ax + (p.gy - gy) * ay)
		elseif p.slot == geometry.gripSlot then
			local _, top = Shapes.extentAlong(p, ax, ay, 0)
			gripTop = max(gripTop, top - gAlong)
		end
	end
	local guardPos = 0
	if guardVolume > 0 then
		guardPos = guardMoment / guardVolume
	elseif gripTop > -math.huge then
		guardPos = gripTop
	end

	-- reach and blade length over kept striking parts; total length over all parts
	local reach, bladeTop = 0, -math.huge
	local lowest, highest = math.huge, -math.huge
	for i = 1, N do
		local p = parts[i]
		local lo, hi = Shapes.extentAlong(p, ax, ay, 0)
		lowest, highest = min(lowest, lo), max(highest, hi)
		if p.slot == geometry.strikingSlot and kept[i] then
			reach = max(reach, Shapes.maxDist(p, gx, gy, gz))
			bladeTop = max(bladeTop, hi - gAlong)
		end
	end
	local bladeLength = if bladeTop > -math.huge then bladeTop - guardPos else 0

	local comAlong = (com[1] - gx) * ax + (com[2] - gy) * ay
	return {
		mass = M,
		volume = U,
		com = com,
		gripPoint = gripPoint,
		gripAxis = gripAxis,
		guardPos = guardPos,
		balance = comAlong - guardPos,
		balanceFromHand = comAlong,
		reach = reach,
		bladeLength = bladeLength,
		totalLength = highest - lowest,
		comOffAxis = (com[1] - gx) * ay - (com[2] - gy) * ax,
		ownedVolume = ownedVolume,
	}
end

return table.freeze(MassProps)
