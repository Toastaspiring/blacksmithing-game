--!strict
-- Physics/Sampling (SPEC §4.1, §4.3, §4.4, §4.9; owner S2): stratified samples in each part's own frame, surface
-- exposure and cleaning. No global grid: a 0.01 nudge must not change a measurement by 2× (E-S2.4). Pure; §4.1's
-- determinism rules apply. The sampling details are pinned by the reference prototype docs/spec/prototypes/S2/v2/
-- (loops: local X outermost, then Y, Z; cell centres −h_k + (i + ½)·2h_k/n_k), and the goldens come from it.
--
--   ladder         the first H_LADDER multiple of a spacing whose work fits a budget (deterministic coarsening, §4.9)
--   volumeSamples  a part's interior grid: n_k = clamp(ceil(size_k/h), N_MIN_AXIS, N_MAX_AXIS), ≤ N_MAX_PART per part
--                  (coarser h per part until it fits), kept iff sd < −1e-9, weight V/count
--   volumeProbes   the volume samples of every kept part at the spacing that fits N_VOL_TOTAL
--   surfaceSamples a part's surface samples with normals and patch half-vectors e1, e2
--   ranked         the verdict's order: the larger first, then the slot's name, then the solids (§4.4)
--   measureRanked  the measure's and ownership's order: the larger first, then the solids, then the slot's name (§4.4)
--   exposure       §4.4: the verdict (Dust and Enclosed cleaning, read by Physics/Cover), then the measure: the kept
--                  parts' exposed areas and contact areas (SurfaceComplexity and Joints, §5.2)
--
-- Exposure. A sample s of part p (normal n) is hidden by another part q if it is buried (sd_q(s) < −EPS_GEOM), or lies
-- on q's surface and q ranks higher (a coincident face counts once), or its probe s + HIDE_OFFSET·n is inside q.
-- HIDE_OFFSET = CONTACT_TOL + 0.002, so any gap validation calls connected hides the faces across it where the part
-- beyond holds the probe. The probe is one point: a face flush on a part thinner than HIDE_OFFSET there (a Wedge's
-- thin edge) shows where that part ranks lower, the coincident rule hiding only the lower part's face (SPEC §4.4,
-- §17.1 O10). Both ranks put the larger part first and settle every tie by the solids or the slot's name, so a part's
-- id cannot decide anything here.
--
-- The verdict comes first, per part, and depends only on the part and on what covers it. Dust: V < MIN_PART_VOLUME, no
-- samples, hides nothing. An exact copy (Shapes.sameSolid with a higher rank) lies wholly on that part's surface:
-- Enclosed, no samples, hides nothing. Any other part is Enclosed when under ENCLOSED_EXPOSED_MAX of its model's area
-- shows, read exactly on its polyhedral model (Physics/Cover; a flat facet against a Ball also by its sphere, a round
-- part against a round hider by their true solids) against the models of every part but copies and Dust whose box comes
-- within its model's reach (HIDE_OFFSET, + the largest sag and spread on a round part) + the hider's model's over (0 on
-- a polyhedron) + 2·EPS_GEOM, in rank order, stopping once it shows that much. No grid and no budget of its own:
-- nothing another part brings can change what is looked at, only a part that really covers this one can change what it
-- reads. All the verdicts share one cap, VERDICT_WORK_MAX of Cover's units (the models, each part's look over the
-- others' boxes and its reading): past it the exposure stops at that report, capped, with no verdict at all, and
-- Analyze makes the design TooComplex.
-- A part's units depend on the part, its hiders and the number of parts (its look), so their sum, and whether it passes
-- the cap, do not depend on the order of the parts.
--
-- Then the measure: every kept part against kept parts only, once, on a ladder and a sub-grid budget of their own, in
-- the measure's rank order (`measureRanked`), which also decides between them who keeps a coincident face. The
-- prototype's patches and numbers (exposedKept, contact) come from here: a planar sample whose patch may straddle a
-- hiding boundary is tested at its 4 corners and, if they disagree with its centre, weighted by the exposed fraction of
-- a 4 × 4 sub-grid, where a sub-point past a triangle's or a cap's rim counts as exposed, as in the prototype. Cleaned
-- parts never reach it, so enclosed parts leave D bit-identical. N_SURF_WORK holds by the ladder's estimate, which
-- treats every part as a Block: thin cylinders sample about 2 × that (8 directions against the estimate's 4 faces), and
-- 24 thin rods run about 2 × N_SURF_WORK.
--
-- All state is per call (§4.9: a checkpoint may raise to cancel a run). Work is reported through `spend`, which
-- Analyze turns into checkpoints between samples, never inside a comparator.

local Balance = require("../Definitions/Balance")
local Limits = require("../Definitions/Limits")
local Cover = require("./Cover")
local Shapes = require("./Shapes")

type Prepared = Shapes.Prepared

local sqrt, abs, max, min, ceil = math.sqrt, math.abs, math.max, math.min, math.ceil
local sd, sdLocal, toWorld, aabbContains, aabbOverlap =
	Shapes.sd, Shapes.sdLocal, Shapes.toWorld, Shapes.aabbContains, Shapes.aabbOverlap

local Geo = Balance.Geometry
local EPS_GEOM = Geo.EPS_GEOM
local HIDE_OFFSET = Geo.HIDE_OFFSET
local CONTACT_TOL = Limits.CONTACT_TOL
local PI = Shapes.PI

local BLOCK, WEDGE, CORNER, CYLINDER = Shapes.BLOCK, Shapes.WEDGE, Shapes.CORNER, Shapes.CYLINDER

local INSIDE_MARGIN = 1e-9 -- §4.3: a volume sample is kept iff sd < −1e-9
local UNITS_PER_SAMPLE = 4 -- writing one surface sample costs about this many shape queries (checkpoints only)

-- The unit circle in 32 directions, k = 0…31 (§4.1: literal constants, 17 significant digits, never trigonometry),
-- Cover's: the verdict's Cylinder model stands on the same 32 directions. T-PHY checks them against math.cos and math.sin.
local COS: { number } = Cover.COS
local SIN: { number } = Cover.SIN

export type Spend = (units: number) -> ()

export type VolumeSamples = {
	n: number,
	x: { number }, -- world positions, in sample order
	y: { number },
	z: { number },
	w: number, -- weight of every sample: V / n
}

export type VolumeProbes = {
	h: number, -- the spacing that fits N_VOL_TOTAL
	total: number, -- samples over all kept parts
	byPart: { VolumeSamples }, -- per part, in blueprint order; cleaned parts have none
}

export type SurfaceSamples = {
	n: number,
	x: { number }, -- world positions
	y: { number },
	z: { number },
	w: { number }, -- area weights, summing to the part's area
	nx: { number }, -- world normals
	ny: { number },
	nz: { number },
	e1x: { number }, -- patch half-vectors (zero on a ball)
	e1y: { number },
	e1z: { number },
	e2x: { number },
	e2y: { number },
	e2z: { number },
	flat: { boolean }, -- planar faces: the measure's boundary test; curved ones keep the centre verdict
}

export type CleanReason = "Dust" | "Enclosed"
export type Cleaned = { partId: number, reason: CleanReason }

export type Exposure = {
	hSurf: number, -- the measure's spacing: what fits N_SURF_WORK over the kept parts
	surfSamples: number, -- the measure's surface samples
	subSampled: number, -- the measure's patches weighted by the 4 × 4 sub-grid
	exposedKept: { number }, -- per part, kept parts hide; 0 on cleaned parts
	contact: { { number } }, -- contact[p][q]: p's sampled area within CONTACT_TOL of q, kept pairs on hSurf's grid
	kept: { boolean }, -- per part: not Dust, not Enclosed
	cleaned: { Cleaned }, -- in part order
	capped: boolean, -- the verdicts passed VERDICT_WORK_MAX: no verdict, nothing measured (Analyze: TooComplex)
	verdictWork: number, -- Cover's units over all the verdicts, up to where they stopped
}

local function noSpend(_: number) end

local Sampling = {}

Sampling.COS, Sampling.SIN = COS, SIN
Sampling.INSIDE_MARGIN = INSIDE_MARGIN

-- ── budgets (§4.9) ────────────────────────────────────────────────────────────────────────────────────────────────

-- base × the first H_LADDER factor for which fits(h) holds; the last factor when none does.
function Sampling.ladder(base: number, fits: (h: number) -> boolean): number
	local factors = Geo.H_LADDER
	local h = base
	for i = 1, #factors do
		h = base * factors[i]
		if fits(h) then
			break
		end
	end
	return h
end

local function axisCount(size: number, h: number, nMin: number, nMax: number): number
	return max(nMin, min(nMax, ceil(size / h)))
end

-- ── volume samples (§4.3) ─────────────────────────────────────────────────────────────────────────────────────────

-- minX, minY, minZ raise N_MIN_AXIS per local axis (M3's Asymmetry wants ≥ ASYM_N_MIN across the mirror plane).
function Sampling.volumeSamples(P: Prepared, h: number, spend: Spend?, minX: number?, minY: number?,
	minZ: number?): VolumeSamples
	local work = spend or noSpend
	local nMax, budget = Geo.N_MAX_AXIS, Geo.N_MAX_PART
	local sx, sy, sz = 2 * P.hx, 2 * P.hy, 2 * P.hz
	local mx, my, mz = minX or Geo.N_MIN_AXIS, minY or Geo.N_MIN_AXIS, minZ or Geo.N_MIN_AXIS
	local nx, ny, nz
	local k = 1
	while true do
		nx = axisCount(sx, k * h, mx, nMax)
		ny = axisCount(sy, k * h, my, nMax)
		nz = axisCount(sz, k * h, mz, nMax)
		if nx * ny * nz <= budget or (nx == mx and ny == my and nz == mz) then
			break
		end
		k += 1
	end
	local xs: { number }, ys: { number }, zs: { number } = {}, {}, {}
	local n = 0
	local dx, dy, dz = sx / nx, sy / ny, sz / nz
	for i = 0, nx - 1 do
		local lx = -P.hx + (i + 0.5) * dx
		work(ny * nz)
		for j = 0, ny - 1 do
			local ly = -P.hy + (j + 0.5) * dy
			for l = 0, nz - 1 do
				local lz = -P.hz + (l + 0.5) * dz
				if sdLocal(P, lx, ly, lz) < -INSIDE_MARGIN then
					n += 1
					xs[n], ys[n], zs[n] = toWorld(P, lx, ly, lz)
				end
			end
		end
	end
	if n == 0 then -- cannot happen above MIN_DIM: one sample at the centroid
		n = 1
		xs[1], ys[1], zs[1] = P.gx, P.gy, P.gz
	end
	return { n = n, x = xs, y = ys, z = zs, w = P.volume / n }
end

-- The volume samples of every kept part (cleaned parts have none; Thinness and Asymmetry measure kept metal only).
function Sampling.volumeProbes(parts: { Prepared }, kept: { boolean }, spend: Spend?): VolumeProbes
	local nMin, nMax, budget = Geo.N_MIN_AXIS, Geo.N_MAX_AXIS, Geo.N_MAX_PART
	local h = Sampling.ladder(Geo.H_VOL, function(spacing: number): boolean
		local est = 0
		for i = 1, #parts do
			if kept[i] then
				local p = parts[i]
				local a = axisCount(2 * p.hx, spacing, nMin, nMax)
				local b = axisCount(2 * p.hy, spacing, nMin, nMax)
				local c = axisCount(2 * p.hz, spacing, nMin, nMax)
				est += min(a * b * c, budget)
			end
		end
		return est <= Geo.N_VOL_TOTAL
	end)
	local byPart: { VolumeSamples } = table.create(#parts)
	local total = 0
	for i = 1, #parts do
		if kept[i] then
			local samples = Sampling.volumeSamples(parts[i], h, spend)
			byPart[i] = samples
			total += samples.n
		else
			byPart[i] = { n = 0, x = {}, y = {}, z = {}, w = 0 }
		end
	end
	return { h = h, total = total, byPart = byPart }
end

-- ── surface samples (§4.3) ────────────────────────────────────────────────────────────────────────────────────────

local function faceNormal(P: Prepared, ox: number, oy: number, oz: number, ax: number, ay: number, az: number,
	bx: number, by: number, bz: number): (number, number, number)
	local cx, cy, cz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
	local l = sqrt(cx * cx + cy * cy + cz * cz)
	cx, cy, cz = cx / l, cy / l, cz / l
	if (ox - P.lcx) * cx + (oy - P.lcy) * cy + (oz - P.lcz) * cz < 0 then
		cx, cy, cz = -cx, -cy, -cz
	end
	return cx, cy, cz
end

local function setNormal(P: Prepared, out: SurfaceSamples, n: number, lnx: number, lny: number, lnz: number)
	out.nx[n] = lnx * P.ux + lny * P.vx + lnz * P.wx
	out.ny[n] = lnx * P.uy + lny * P.vy + lnz * P.wy
	out.nz[n] = lnx * P.uz + lny * P.vz + lnz * P.wz
end

-- Patch half-vectors of sample n, local → world (rotation only).
local function setPatch(P: Prepared, out: SurfaceSamples, n: number, ax: number, ay: number, az: number, bx: number,
	by: number, bz: number, flat: boolean)
	out.e1x[n] = ax * P.ux + ay * P.vx + az * P.wx
	out.e1y[n] = ax * P.uy + ay * P.vy + az * P.wy
	out.e1z[n] = ax * P.uz + ay * P.vz + az * P.wz
	out.e2x[n] = bx * P.ux + by * P.vx + bz * P.wx
	out.e2y[n] = bx * P.uy + by * P.vy + bz * P.wy
	out.e2z[n] = bx * P.uz + by * P.vz + bz * P.wz
	out.flat[n] = flat
end

-- A rectangular face: corner o, edges a, b.
local function addRectangle(P: Prepared, out: SurfaceSamples, work: Spend, ox: number, oy: number, oz: number,
	ax: number, ay: number, az: number, bx: number, by: number, bz: number, h: number)
	local nMax = Geo.NS_MAX
	local la = sqrt(ax * ax + ay * ay + az * az)
	local lb = sqrt(bx * bx + by * by + bz * bz)
	local na = axisCount(la, h, 1, nMax)
	local nb = axisCount(lb, h, 1, nMax)
	local w = la * lb / (na * nb)
	local fx, fy, fz = faceNormal(P, ox, oy, oz, ax, ay, az, bx, by, bz)
	for i = 0, na - 1 do
		local s = (i + 0.5) / na
		work(UNITS_PER_SAMPLE * nb)
		for j = 0, nb - 1 do
			local t = (j + 0.5) / nb
			local x, y, z = toWorld(P, ox + s * ax + t * bx, oy + s * ay + t * by, oz + s * az + t * bz)
			local n = out.n + 1
			out.n = n
			out.x[n], out.y[n], out.z[n], out.w[n] = x, y, z, w
			setNormal(P, out, n, fx, fy, fz)
			setPatch(P, out, n, ax / (2 * na), ay / (2 * na), az / (2 * na), bx / (2 * nb), by / (2 * nb), bz / (2 * nb),
				true)
		end
	end
end

-- A triangular face: corner o, edges a, b; the grid cells with s + t ≤ 1.
local function addTriangle(P: Prepared, out: SurfaceSamples, work: Spend, ox: number, oy: number, oz: number,
	ax: number, ay: number, az: number, bx: number, by: number, bz: number, h: number)
	local nMax = Geo.NS_MAX
	local la = sqrt(ax * ax + ay * ay + az * az)
	local lb = sqrt(bx * bx + by * by + bz * bz)
	local na = axisCount(la, h, 1, nMax)
	local nb = axisCount(lb, h, 1, nMax)
	local cx, cy, cz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
	local area = sqrt(cx * cx + cy * cy + cz * cz) / 2
	local fx, fy, fz = faceNormal(P, ox, oy, oz, ax, ay, az, bx, by, bz)
	local first = out.n + 1
	for i = 0, na - 1 do
		local s = (i + 0.5) / na
		work(UNITS_PER_SAMPLE * nb)
		for j = 0, nb - 1 do
			local t = (j + 0.5) / nb
			if s + t <= 1 then
				local n = out.n + 1
				out.n = n
				out.x[n], out.y[n], out.z[n] =
					toWorld(P, ox + s * ax + t * bx, oy + s * ay + t * by, oz + s * az + t * bz)
			end
		end
	end
	local count = out.n - first + 1
	if count == 0 then -- a sliver: its centroid
		local n = out.n + 1
		out.n = n
		out.x[n], out.y[n], out.z[n] = toWorld(P, ox + (ax + bx) / 3, oy + (ay + by) / 3, oz + (az + bz) / 3)
		count = 1
	end
	for i = first, out.n do
		out.w[i] = area / count
		setNormal(P, out, i, fx, fy, fz)
		setPatch(P, out, i, ax / (2 * na), ay / (2 * na), az / (2 * na), bx / (2 * nb), by / (2 * nb), bz / (2 * nb),
			true)
	end
end

local function addCylinder(P: Prepared, out: SurfaceSamples, work: Spend, h: number)
	local nMax = Geo.NS_MAX
	local hx, r = P.hx, P.r
	-- the caps: a disk grid
	local nc = axisCount(2 * r, h, 2, nMax)
	for s = -1, 1, 2 do
		local first = out.n + 1
		for i = 0, nc - 1 do
			local ly = -r + (i + 0.5) * (2 * r / nc)
			work(UNITS_PER_SAMPLE * nc)
			for j = 0, nc - 1 do
				local lz = -r + (j + 0.5) * (2 * r / nc)
				if ly * ly + lz * lz <= r * r then
					local n = out.n + 1
					out.n = n
					out.x[n], out.y[n], out.z[n] = toWorld(P, s * hx, ly, lz)
					setNormal(P, out, n, s, 0, 0)
					setPatch(P, out, n, 0, r / nc, 0, 0, 0, r / nc, true)
				end
			end
		end
		local count = out.n - first + 1
		for i = first, out.n do
			out.w[i] = PI * r * r / count
		end
	end
	-- the side: 8, 16 or 32 directions (circumference / h ≤ 8, ≤ 16, above) × axial
	local circumference = 2 * PI * r
	local nth, stride
	if circumference / h <= 8 then
		nth, stride = 8, 4
	elseif circumference / h <= 16 then
		nth, stride = 16, 2
	else
		nth, stride = 32, 1
	end
	local nax = axisCount(2 * hx, h, 1, nMax)
	local w = circumference * 2 * hx / (nth * nax)
	local halfTangent = circumference / (2 * nth)
	for i = 0, nax - 1 do
		local lx = -hx + (i + 0.5) * (2 * hx / nax)
		work(UNITS_PER_SAMPLE * nth)
		for k = 1, 32, stride do
			local n = out.n + 1
			out.n = n
			local cosk, sink = COS[k], SIN[k]
			out.x[n], out.y[n], out.z[n] = toWorld(P, lx, r * cosk, r * sink)
			out.w[n] = w
			setNormal(P, out, n, 0, cosk, sink)
			setPatch(P, out, n, hx / nax, 0, 0, 0, -halfTangent * sink, halfTangent * cosk, false)
		end
	end
end

-- A cube-sphere grid: clamp(ceil((πr/2)/h), 2, NS_MAX) per cube-face axis, Jacobian weights (1 + a² + b²)^(−3/2)
-- normalized to 4πr².
local function addBall(P: Prepared, out: SurfaceSamples, work: Spend, h: number)
	local r = P.r
	local nf = axisCount(PI * r / 2, h, 2, Geo.NS_MAX)
	local first = out.n + 1
	local total = 0
	for face = 1, 6 do
		for i = 0, nf - 1 do
			local a = -1 + (i + 0.5) * (2 / nf)
			work(UNITS_PER_SAMPLE * nf)
			for j = 0, nf - 1 do
				local b = -1 + (j + 0.5) * (2 / nf)
				local px, py, pz
				if face == 1 then
					px, py, pz = 1, a, b
				elseif face == 2 then
					px, py, pz = -1, a, b
				elseif face == 3 then
					px, py, pz = a, 1, b
				elseif face == 4 then
					px, py, pz = a, -1, b
				elseif face == 5 then
					px, py, pz = a, b, 1
				else
					px, py, pz = a, b, -1
				end
				local s2 = 1 + a * a + b * b
				local inv = 1 / sqrt(s2)
				local wt = inv / s2
				local n = out.n + 1
				out.n = n
				out.x[n], out.y[n], out.z[n] = toWorld(P, r * px * inv, r * py * inv, r * pz * inv)
				out.w[n] = wt
				setNormal(P, out, n, px * inv, py * inv, pz * inv)
				setPatch(P, out, n, 0, 0, 0, 0, 0, 0, false)
				total += wt
			end
		end
	end
	local scale = 4 * PI * r * r / total
	for i = first, out.n do
		out.w[i] *= scale
	end
end

-- A part's surface samples at spacing h, face by face.
function Sampling.surfaceSamples(P: Prepared, h: number, spend: Spend?): SurfaceSamples
	local work = spend or noSpend
	local out: SurfaceSamples = {
		n = 0,
		x = {}, y = {}, z = {}, w = {},
		nx = {}, ny = {}, nz = {},
		e1x = {}, e1y = {}, e1z = {},
		e2x = {}, e2y = {}, e2z = {},
		flat = {},
	}
	local hx, hy, hz = P.hx, P.hy, P.hz
	local code = P.code
	if code == BLOCK then
		addRectangle(P, out, work, hx, -hy, -hz, 0, 2 * hy, 0, 0, 0, 2 * hz, h)
		addRectangle(P, out, work, -hx, -hy, -hz, 0, 2 * hy, 0, 0, 0, 2 * hz, h)
		addRectangle(P, out, work, -hx, hy, -hz, 2 * hx, 0, 0, 0, 0, 2 * hz, h)
		addRectangle(P, out, work, -hx, -hy, -hz, 2 * hx, 0, 0, 0, 0, 2 * hz, h)
		addRectangle(P, out, work, -hx, -hy, hz, 2 * hx, 0, 0, 0, 2 * hy, 0, h)
		addRectangle(P, out, work, -hx, -hy, -hz, 2 * hx, 0, 0, 0, 2 * hy, 0, h)
	elseif code == WEDGE then
		addRectangle(P, out, work, -hx, -hy, -hz, 2 * hx, 0, 0, 0, 0, 2 * hz, h) -- the −Y face
		addRectangle(P, out, work, -hx, -hy, hz, 2 * hx, 0, 0, 0, 2 * hy, 0, h) -- the +Z face
		addRectangle(P, out, work, -hx, -hy, -hz, 2 * hx, 0, 0, 0, 2 * hy, 2 * hz, h) -- the slope
		addTriangle(P, out, work, hx, -hy, hz, 0, 0, -2 * hz, 0, 2 * hy, 0, h) -- the +X side
		addTriangle(P, out, work, -hx, -hy, hz, 0, 0, -2 * hz, 0, 2 * hy, 0, h) -- the −X side
	elseif code == CORNER then
		addRectangle(P, out, work, -hx, -hy, -hz, 2 * hx, 0, 0, 0, 0, 2 * hz, h) -- the −Y face
		addTriangle(P, out, work, hx, -hy, -hz, 0, 0, 2 * hz, 0, 2 * hy, 0, h) -- x = +hx
		addTriangle(P, out, work, hx, -hy, -hz, -2 * hx, 0, 0, 0, 2 * hy, 0, h) -- z = −hz
		addTriangle(P, out, work, -hx, -hy, -hz, 0, 0, 2 * hz, 2 * hx, 2 * hy, 0, h) -- the slope y/hy = x/hx
		addTriangle(P, out, work, -hx, -hy, hz, 2 * hx, 0, 0, 2 * hx, 2 * hy, -2 * hz, h) -- the slope y/hy = −z/hz
	elseif code == CYLINDER then
		addCylinder(P, out, work, h)
	else
		addBall(P, out, work, h)
	end
	return out
end

-- The sample count at spacing h, for the budget ladder (an estimate: faces as if every part were a Block).
local function surfaceEstimate(P: Prepared, h: number): number
	local nMax = Geo.NS_MAX
	local a = axisCount(2 * P.hx, h, 1, nMax)
	local b = axisCount(2 * P.hy, h, 1, nMax)
	local c = axisCount(2 * P.hz, h, 1, nMax)
	return 2 * (a * b + b * c + a * c)
end

-- ── exposure and cleaning (§4.4) ──────────────────────────────────────────────────────────────────────────────────

-- The verdict's rank of each part (1 = highest), and the parts in rank order: which of two exact copies survives, the
-- hiders' order and who keeps a coincident face in a reading. The larger first (a Block's volume from its half extents
-- sorted, a Wedge's from hy and hz in order, so that the frame and the size that describe one solid decide nothing; a
-- Cylinder's and a Ball's come from their radius and length alone): a part wholly inside another, flush with its faces,
-- gives them up to it whatever its label, so filler buys no face. Of two of one volume the name of the slot first: a
-- label is visible, so of two parts that coincide the one whose slot's name comes first keeps their faces, and an
-- invisible copy cannot take them, whatever its frame, its size's description or a nudge of its place; a copy a hair
-- larger encloses the part and takes them, as relabelling the part would. Then by where it stands (|cx| before cx, |cz|
-- before cz: a mirror image across either centre plane can only swap parts that tie on all of it), by its half extents
-- (a Block's sorted, a Wedge's hy and hz in order), by the name of its material, then by its half extents as given and
-- its turn; only what is the same in every way falls to the index.
function Sampling.ranked(parts: { Prepared }): ({ number }, { Prepared })
	local N = #parts
	local order: { Prepared } = table.create(N)
	local keys: { { number } } = table.create(N)
	local given: { { number } } = table.create(N)
	for i = 1, N do
		local p = parts[i]
		order[i] = p
		local h1, h2, h3, v = p.hx, p.hy, p.hz, p.volume
		if p.code == BLOCK then
			h1, h3 = min(p.hx, p.hy, p.hz), max(p.hx, p.hy, p.hz)
			h2 = max(min(p.hx, p.hy), min(max(p.hx, p.hy), p.hz))
			v = 8 * h1 * h2 * h3
		elseif p.code == WEDGE then
			-- a Wedge (sx, sy, sz) is the same solid as (sx, sz, sy) half turned about its local (0, 1, −1): the volume and the
			-- half extents from hy and hz in order, so that the two descriptions tie and, as for a Block, the material decides
			h2, h3 = min(p.hy, p.hz), max(p.hy, p.hz)
			v = 4 * p.hx * h2 * h3
		end
		keys[p.index] = { -v, p.cy, abs(p.cx), p.cx, abs(p.cz), p.cz, h1, h2, h3 }
		given[p.index] = { p.hx, p.hy, p.hz, p.ux, p.uy, p.uz, p.vx, p.vy, p.vz }
	end
	table.sort(order, function(a: Prepared, b: Prepared): boolean
		local ka, kb = keys[a.index], keys[b.index]
		if ka[1] ~= kb[1] then
			return ka[1] < kb[1]
		end
		if a.slot ~= b.slot then
			return a.slot < b.slot
		end
		for k = 2, #ka do
			if ka[k] ~= kb[k] then
				return ka[k] < kb[k]
			end
		end
		if a.material ~= b.material then
			return a.material < b.material
		end
		local ga, gb = given[a.index], given[b.index]
		for k = 1, #ga do
			if ga[k] ~= gb[k] then
				return ga[k] < gb[k]
			end
		end
		return a.index < b.index
	end)
	local rank: { number } = table.create(N, 0)
	for r = 1, N do
		rank[order[r].index] = r
	end
	return rank, order
end

-- The measure's rank: the larger first, then by where it stands (|cx| before cx, |cz| before cz), then by its half
-- extents and turn as given, then by the names of its slot and material, then the index. Between kept parts it settles
-- who keeps a face they share, who owns an overlap within a slot (§4.3, MassProps) and who spends the measure's sub-grid
-- budget first. It is the rank both had before the verdict's took the slot's name ahead of where a part stands, kept so
-- that the measure, owned volumes and mass move only where a verdict does; Reference.spec hands the prototype its order.
function Sampling.measureRanked(parts: { Prepared }): ({ number }, { Prepared })
	local N = #parts
	local order: { Prepared } = table.create(N)
	local keys: { { number } } = table.create(N)
	for i = 1, N do
		local p = parts[i]
		order[i] = p
		keys[p.index] =
			{ -p.volume, p.cy, abs(p.cx), p.cx, abs(p.cz), p.cz, p.hx, p.hy, p.hz, p.ux, p.uy, p.uz, p.vx, p.vy, p.vz }
	end
	table.sort(order, function(a: Prepared, b: Prepared): boolean
		local ka, kb = keys[a.index], keys[b.index]
		for k = 1, #ka do
			if ka[k] ~= kb[k] then
				return ka[k] < kb[k]
			end
		end
		if a.slot ~= b.slot then
			return a.slot < b.slot
		end
		if a.material ~= b.material then
			return a.material < b.material
		end
		return a.index < b.index
	end)
	local rank: { number } = table.create(N, 0)
	for r = 1, N do
		rank[order[r].index] = r
	end
	return rank, order
end

-- The measure's 4 × 4 sub-grid offsets in patch half-vectors, and its corner pre-test's.
local SUB_GRID: { number } = table.freeze({ -0.75, -0.25, 0.25, 0.75 })
local CORNERS_A: { number } = table.freeze({ -1, 1, -1, 1 })
local CORNERS_B: { number } = table.freeze({ -1, -1, 1, 1 })

function Sampling.exposure(parts: { Prepared }, spend: Spend?): Exposure
	local work = spend or noSpend
	local N = #parts
	local eps = EPS_GEOM
	local delta = HIDE_OFFSET
	local tol = CONTACT_TOL

	local rank, byRank = Sampling.ranked(parts)
	local measureRank, byMeasureRank = Sampling.measureRanked(parts)

	-- exact copies of a higher-ranked part: Enclosed, never sampled, no candidate for anyone. A copy in another slot does not
	-- stand next to its original, so every part above with the same centre is asked
	local isCopy: { boolean } = table.create(N, false)
	for r = 2, N do
		local p = byRank[r]
		for t = r - 1, 1, -1 do
			local q = byRank[t]
			if q.cx == p.cx and q.cy == p.cy and q.cz == p.cz and Shapes.sameSolid(p, q) then
				isCopy[p.index] = true
				break
			end
		end
	end

	local subLeft = Geo.N_SUB_WORK
	local subSampled = 0
	local near: { Prepared } = {}

	-- The whole hide test at a sub-point: only the near parts can change over the patch (sd is 1-Lipschitz).
	local function hides(q: Prepared, pIndex: number, x: number, y: number, z: number, ox: number, oy: number,
		oz: number): boolean
		if aabbContains(q, x, y, z, 2 * eps) then
			local d0 = sd(q, x, y, z)
			if d0 < -eps or (measureRank[q.index] < measureRank[pIndex] and d0 <= eps) then
				return true
			end
		end
		return aabbContains(q, ox, oy, oz, 2 * eps) and sd(q, ox, oy, oz) <= eps
	end

	-- The exposed part of sample k's area, as the prototype weighs it. contactRow collects the area within CONTACT_TOL per
	-- part.
	local function exposedWeight(p: Prepared, S: SurfaceSamples, k: number, cand: { Prepared },
		contactRow: { number }): number
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
			local hid = d0 < -eps or (measureRank[q.index] < measureRank[p.index] and d0 <= eps) or d1 <= eps
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

	-- the verdict: each part's model against every part but exact copies and Dust that its probes can reach, in rank order,
	-- until it shows ENCLOSED_EXPOSED_MAX of its model's area (Physics/Cover). How many other parts there are changes
	-- nothing it looks at, so hidden parts cannot change a verdict by using anything up; only a part that covers another
	-- can. Past VERDICT_WORK_MAX all of it stops, with no verdict at all: the cap changes none.
	local kept: { boolean } = table.create(N, false)
	local cleaned: { Cleaned } = {}
	local hider: { boolean } = table.create(N, false)
	local models: { Cover.Model } = table.create(N)
	local verdictWork = 0
	for i = 1, N do
		hider[i] = not isCopy[i] and parts[i].volume >= Geo.MIN_PART_VOLUME
		if hider[i] then
			local m = Cover.model(parts[i], work)
			models[i] = m
			verdictWork += m.work
		end
	end
	local cap = Geo.VERDICT_WORK_MAX
	local capped = verdictWork > cap
	local look = Cover.UNITS_PER_BOX * N -- a part's look over the others' boxes
	for i = 1, N do
		local p = parts[i]
		if capped then
			break
		elseif p.volume < Geo.MIN_PART_VOLUME then
			table.insert(cleaned, { partId = p.id, reason = "Dust" :: CleanReason })
		elseif isCopy[i] then
			table.insert(cleaned, { partId = p.id, reason = "Enclosed" :: CleanReason })
		else
			local cand: { Cover.Model } = {}
			local higher: { boolean } = {}
			local own = rank[i]
			local reach = models[i].reach + 2 * eps
			for r = 1, N do
				local q = byRank[r]
				local j = q.index
				if j ~= i and hider[j] and aabbOverlap(p, q, reach + models[j].over) then
					table.insert(cand, models[j])
					table.insert(higher, r < own)
				end
			end
			work(look)
			verdictWork += look
			local need = Geo.ENCLOSED_EXPOSED_MAX * models[i].total
			local shown, used, over = Cover.shown(models[i], cand, higher, need, cap - verdictWork, work)
			verdictWork += used
			if over then
				capped = true
			elseif shown >= need then
				kept[i] = true
			else
				table.insert(cleaned, { partId = p.id, reason = "Enclosed" :: CleanReason })
			end
		end
	end
	if capped then
		local contact: { { number } } = table.create(N)
		for i = 1, N do
			contact[i] = table.create(N, 0)
		end
		return {
			hSurf = 0,
			surfSamples = 0,
			subSampled = 0,
			exposedKept = table.create(N, 0),
			contact = contact,
			kept = table.create(N, false),
			cleaned = {},
			capped = true,
			verdictWork = verdictWork,
		}
	end

	-- the measure: the kept parts, against kept parts only, on a ladder (samples × (1 + candidate parts) within
	-- N_SURF_WORK) and a sub-grid budget of their own, in the measure's rank order. It runs whatever was cleaned, so a
	-- hidden part anywhere cannot reach a kept part's area or contact rows.
	local hSurf = Sampling.ladder(Geo.H_SURF, function(h: number): boolean
		local est = 0
		for i = 1, N do
			if kept[i] then
				local p = parts[i]
				local nc = 0
				for j = 1, N do
					if j ~= i and kept[j] and aabbOverlap(p, parts[j], delta + tol + h) then
						nc += 1
					end
				end
				est += surfaceEstimate(p, h) * (1 + nc)
			end
			work(N)
		end
		return est <= Geo.N_SURF_WORK
	end)
	local surfSamples = 0
	local contact: { { number } } = table.create(N)
	for i = 1, N do
		contact[i] = table.create(N, 0)
	end
	local exposedKept: { number } = table.create(N, 0)
	for r = 1, N do
		local i = byMeasureRank[r].index
		if kept[i] then
			local p = parts[i]
			local S = Sampling.surfaceSamples(p, hSurf, work)
			surfSamples += S.n
			local keptCand: { Prepared } = {}
			for j = 1, N do
				if j ~= i and kept[j] and aabbOverlap(p, parts[j], delta + tol + hSurf) then
					table.insert(keptCand, parts[j])
				end
			end
			local row = contact[i]
			local exposed = 0
			local units = #keptCand + 1
			for k = 1, S.n do
				exposed += exposedWeight(p, S, k, keptCand, row)
				work(units)
			end
			exposedKept[i] = exposed
		end
	end

	return {
		hSurf = hSurf,
		surfSamples = surfSamples,
		subSampled = subSampled,
		exposedKept = exposedKept,
		contact = contact,
		kept = kept,
		cleaned = cleaned,
		capped = false,
		verdictWork = verdictWork,
	}
end

return table.freeze(Sampling)
