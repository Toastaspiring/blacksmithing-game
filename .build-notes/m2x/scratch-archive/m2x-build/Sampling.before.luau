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
--   ranked         the parts' order by the solids, which no id can change (§4.4)
--   exposure       §4.4: the verdict (Dust and Enclosed cleaning), then the measure: the kept parts' exposed areas and
--                  contact areas (SurfaceComplexity and Joints, §5.2)
--
-- Exposure. A sample s of part p (normal n) is hidden by another part q if it is buried (sd_q(s) < −EPS_GEOM), or lies
-- on q's surface and q ranks higher (a coincident face counts once), or its probe s + HIDE_OFFSET·n is inside q.
-- HIDE_OFFSET = CONTACT_TOL + 0.002, so any gap validation calls connected hides the faces across it. The rank (`ranked`)
-- goes by the solids, the larger first, so a part's id cannot decide anything here.
--
-- The verdict comes first, per part, and depends only on the part and on what covers it. Dust: V < MIN_PART_VOLUME, no
-- samples, hides nothing. An exact copy (Shapes.sameSolid with a higher rank) lies wholly on that part's surface:
-- Enclosed, no samples, hides nothing. Any other part is Enclosed when under ENCLOSED_EXPOSED_MAX of its surface shows,
-- read on a grid of its own (the first H_LADDER spacing whose surfaceEstimate fits VERDICT_SAMPLES, a Ball
-- VERDICT_BALL_NF cells per cube-face axis), against every part but copies and Dust, stopping once it shows that much.
-- No budget: nothing another part brings can change the grid or which patches get looked at, only a part that really
-- covers this one can change what it reads.
-- With so few samples a patch is large, so the reading is more careful than the measure's. A flat patch reads nothing if
-- one part hides its centre and 4 corners (just inside the patch, VERDICT_CORNER; the hiding regions are convex, and two
-- parts can leave a slit between them). Otherwise it is measured on 4 lines along each half-vector, at ±0.25 and ±0.75 of
-- the other: a convex part hides one interval of a line, at the surface and at the probe's line, so what shows of a line
-- is exact, whatever the width, and past the patch's own rim nothing counts. A boundary across a line is read to the bit
-- and one along a line not at all, so of the two families the one whose lines agree crosses the pattern; a family that
-- reads nothing loses to one that reads something (what shows lies between its lines), and of two that agree alike, the
-- smaller reading stands. A triangle has at least VERDICT_TRIANGLE_CELLS cells per edge: with 1 the far half of a
-- thin triangle has no sample. A Cylinder's side has no straight lines across it: its centre and corners are uniform if
-- they all show or one part hides all five, otherwise its 4 × 4 sub-grid, the sub-points back on the surface, decides, and
-- a strip narrower than the sub-grid's reach reads VERDICT_STRIP_RIM of the patch if a corner showed, VERDICT_STRIP_CENTRE
-- if the centre did. A Ball keeps the centre verdict.
--
-- Then the measure: every kept part against kept parts only, once, on a ladder and a sub-grid budget of their own, in
-- rank order. The prototype's patches and numbers (exposedKept, contact) come from here: a planar sample whose patch
-- may straddle a hiding boundary is tested at its 4 corners and, if they disagree with its centre, weighted by the
-- exposed fraction of a 4 × 4 sub-grid, where a sub-point past a triangle's or a cap's rim counts as exposed, as in the
-- prototype. Cleaned parts never reach it, so enclosed parts leave D bit-identical. N_SURF_WORK holds by the ladder's
-- estimate, which treats every part as a Block: thin cylinders sample about 2 × that (8 directions against the
-- estimate's 4 faces), and 24 thin rods run about 2 × N_SURF_WORK.
--
-- All state is per call (§4.9: a checkpoint may raise to cancel a run). Work is reported through `spend`, which
-- Analyze turns into checkpoints between samples, never inside a comparator.

local Balance = require("../Definitions/Balance")
local Limits = require("../Definitions/Limits")
local Shapes = require("./Shapes")

type Prepared = Shapes.Prepared

local sqrt, abs, max, min, ceil = math.sqrt, math.abs, math.max, math.min, math.ceil
local sd, sdLocal, toWorld, aabbContains, aabbOverlap, chordLocal =
	Shapes.sd, Shapes.sdLocal, Shapes.toWorld, Shapes.aabbContains, Shapes.aabbOverlap, Shapes.chordLocal

local Geo = Balance.Geometry
local EPS_GEOM = Geo.EPS_GEOM
local HIDE_OFFSET = Geo.HIDE_OFFSET
local CONTACT_TOL = Limits.CONTACT_TOL
local PI = Shapes.PI

local BLOCK, WEDGE, CORNER, CYLINDER, BALL = Shapes.BLOCK, Shapes.WEDGE, Shapes.CORNER, Shapes.CYLINDER, Shapes.BALL

local INSIDE_MARGIN = 1e-9 -- §4.3: a volume sample is kept iff sd < −1e-9
local UNITS_PER_SAMPLE = 4 -- writing one surface sample costs about this many shape queries (checkpoints only)
local VERDICT_CORNER = Geo.VERDICT_CORNER
local VERDICT_STRIP_RIM = Geo.VERDICT_STRIP_RIM
local VERDICT_STRIP_CENTRE = Geo.VERDICT_STRIP_CENTRE
local LINES_AGREE = 1e-6 -- numeric guard, not a tunable: a family's lines read the same fraction
local LINE_NOTHING = 1e-9 -- numeric guard, not a tunable: the rounding left after a line's spans are summed

-- The unit circle in 32 directions, k = 0…31 (§4.1: literal constants, 17 significant digits, never trigonometry).
-- These are the prototype's values bit for bit, so k = 8 is 6.1e-17 and not 0. T-PHY checks them against math.cos and
-- math.sin.
local COS: { number } = table.freeze({
	1, 0.98078528040323043, 0.92387953251128674, 0.83146961230254524,
	0.70710678118654757, 0.55557023301960229, 0.38268343236508984, 0.19509032201612833,
	6.123233995736766e-17, -0.19509032201612819, -0.38268343236508973, -0.55557023301960196,
	-0.70710678118654746, -0.83146961230254535, -0.92387953251128674, -0.98078528040323043,
	-1, -0.98078528040323043, -0.92387953251128685, -0.83146961230254546,
	-0.70710678118654768, -0.55557023301960218, -0.38268343236509034, -0.19509032201612866,
	-1.8369701987210297e-16, 0.1950903220161283, 0.38268343236509, 0.55557023301960184,
	0.70710678118654735, 0.83146961230254524, 0.92387953251128652, 0.98078528040323032,
})
local SIN: { number } = table.freeze({
	0, 0.19509032201612825, 0.38268343236508978, 0.55557023301960218,
	0.70710678118654757, 0.83146961230254524, 0.92387953251128674, 0.98078528040323043,
	1, 0.98078528040323043, 0.92387953251128674, 0.83146961230254535,
	0.70710678118654757, 0.55557023301960218, 0.38268343236508989, 0.19509032201612861,
	1.2246467991473532e-16, -0.19509032201612836, -0.38268343236508967, -0.55557023301960196,
	-0.70710678118654746, -0.83146961230254524, -0.92387953251128652, -0.98078528040323032,
	-1, -0.98078528040323043, -0.92387953251128663, -0.83146961230254546,
	-0.70710678118654768, -0.55557023301960218, -0.38268343236509039, -0.19509032201612872,
})

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
	flat: { boolean }, -- planar faces: the measure's boundary test and the verdict's lines; curved ones neither
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
	ax: number, ay: number, az: number, bx: number, by: number, bz: number, h: number, minCells: number)
	local nMax = Geo.NS_MAX
	local la = sqrt(ax * ax + ay * ay + az * az)
	local lb = sqrt(bx * bx + by * by + bz * bz)
	local na = axisCount(la, h, minCells, nMax)
	local nb = axisCount(lb, h, minCells, nMax)
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

-- A part's surface samples at spacing h, face by face. minCells: at least this many cells per edge of a triangular face
-- (1 by default, the prototype's; the verdict asks for VERDICT_TRIANGLE_CELLS).
function Sampling.surfaceSamples(P: Prepared, h: number, spend: Spend?, minCells: number?): SurfaceSamples
	local work = spend or noSpend
	local cells = minCells or 1
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
		addTriangle(P, out, work, hx, -hy, hz, 0, 0, -2 * hz, 0, 2 * hy, 0, h, cells) -- the +X side
		addTriangle(P, out, work, -hx, -hy, hz, 0, 0, -2 * hz, 0, 2 * hy, 0, h, cells) -- the −X side
	elseif code == CORNER then
		addRectangle(P, out, work, -hx, -hy, -hz, 2 * hx, 0, 0, 0, 0, 2 * hz, h) -- the −Y face
		addTriangle(P, out, work, hx, -hy, -hz, 0, 0, 2 * hz, 0, 2 * hy, 0, h, cells) -- x = +hx
		addTriangle(P, out, work, hx, -hy, -hz, -2 * hx, 0, 0, 0, 2 * hy, 0, h, cells) -- z = −hz
		addTriangle(P, out, work, -hx, -hy, -hz, 0, 0, 2 * hz, 2 * hx, 2 * hy, 0, h, cells) -- the slope y/hy = x/hx
		if cells > 1 then -- the slope y/hy = −z/hz, the other's mirror image (§3.8): a verdict reads the same on an image
			addTriangle(P, out, work, hx, -hy, hz, -2 * hx, 0, 0, 0, 2 * hy, -2 * hz, h, cells)
		else -- the prototype's, for the measure
			addTriangle(P, out, work, -hx, -hy, hz, 2 * hx, 0, 0, 2 * hx, 2 * hy, -2 * hz, h, cells)
		end
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

-- The rank of each part (1 = highest), and the parts in rank order: the larger first, then by where it stands (|cx| before
-- cx: a mirror image can only swap true twins), then by its half extents and turn. Who keeps a coincident face, which of two
-- exact copies survives and who spends a budget first are all settled by it, so no id can settle them. Exact copies tie on
-- all of that: the names of their slot and material choose, and only what is the same in every way falls to the index.
function Sampling.ranked(parts: { Prepared }): ({ number }, { Prepared })
	local N = #parts
	local order: { Prepared } = table.create(N)
	local keys: { { number } } = table.create(N)
	for i = 1, N do
		local p = parts[i]
		order[i] = p
		keys[p.index] = { -p.volume, p.cy, abs(p.cx), p.cx, p.cz, p.hx, p.hy, p.hz, p.ux, p.uy, p.uz, p.vx, p.vy, p.vz }
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

-- The 4 × 4 sub-grid's offsets in patch half-vectors (the verdict's lines stand at the same), and the corner pre-test's.
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

	-- exact copies of a higher-ranked part: Enclosed, never sampled, no candidate for anyone. They tie on every geometric key,
	-- so they stand next to each other
	local isCopy: { boolean } = table.create(N, false)
	for r = 2, N do
		isCopy[byRank[r].index] = Shapes.sameSolid(byRank[r], byRank[r - 1])
	end

	local subLeft = Geo.N_SUB_WORK
	local subSampled = 0
	local near: { Prepared } = {}

	-- The whole hide test at a sub-point: only the near parts can change over the patch (sd is 1-Lipschitz).
	local function hides(q: Prepared, pIndex: number, x: number, y: number, z: number, ox: number, oy: number,
		oz: number): boolean
		if aabbContains(q, x, y, z, 2 * eps) then
			local d0 = sd(q, x, y, z)
			if d0 < -eps or (rank[q.index] < rank[pIndex] and d0 <= eps) then
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
			local hid = d0 < -eps or (rank[q.index] < rank[p.index] and d0 <= eps) or d1 <= eps
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

	-- A line through a flat patch, in the frame of each near part that reaches the patch: per part 12 numbers, the patch's
	-- centre, the units of e1 and e2 and the probe's offset; whether it reaches at the surface and at the probe; the spans
	-- hidden on the line.
	local frames: { number } = table.create(12 * N, 0)
	local reachesSurface: { boolean } = table.create(N, false)
	local reachesProbe: { boolean } = table.create(N, false)
	local spanLo: { number } = {}
	local spanHi: { number } = {}

	-- What shows of a line through a flat patch, and how much of the line is on p's surface. along, across: where the line's
	-- direction and its offset's stand in a frame. A convex part hides one interval of a line at the surface (grown by eps
	-- if q keeps a coincident face, else shrunk: the hide test's own level sets, §4.3) and one at the probe's line (grown).
	-- A span that carries on from the front moves its part up the list: the same union, sooner.
	local function lineShown(p: Prepared, nn: number, along: number, across: number, off: number, half: number, lx: number,
		ly: number, lz: number, ux: number, uy: number, uz: number): (number, number)
		local a0, a1 = -half, half
		if p.code ~= BLOCK then -- past the rim of a triangle or a cap nothing counts; a Block's patches stay on its face
			local hit, t0, t1 = Shapes.chord(p, lx, ly, lz, ux, uy, uz, eps)
			work(2)
			if not hit then
				return 0, 0
			end
			a0, a1 = max(t0, a0), min(t1, a1)
			if a1 <= a0 then
				return 0, 0
			end
		end
		local pRank = rank[p.index]
		local spans, chords = 0, 0
		local front = a0
		for m = 1, nn do
			local q = near[m]
			local qi = q.index
			local f = 12 * (qi - 1)
			local vx, vy, vz = frames[f + along + 1], frames[f + along + 2], frames[f + along + 3]
			local ox = frames[f + 1] + off * frames[f + across + 1]
			local oy = frames[f + 2] + off * frames[f + across + 2]
			local oz = frames[f + 3] + off * frames[f + across + 3]
			local moved = false
			if reachesProbe[qi] then
				chords += 1
				local hit, s0, s1 = chordLocal(q, ox + frames[f + 10], oy + frames[f + 11], oz + frames[f + 12], vx, vy, vz, eps)
				if hit and s1 > a0 and s0 < a1 then
					spans += 1
					spanLo[spans], spanHi[spans] = max(s0, a0), min(s1, a1)
					if s0 <= front and s1 > front then
						front = s1
						moved = true
					end
				end
			end
			if reachesSurface[qi] and front < a1 then
				chords += 1
				local hit, s0, s1 = chordLocal(q, ox, oy, oz, vx, vy, vz, if rank[qi] < pRank then eps else -eps)
				if hit and s1 > a0 and s0 < a1 then
					spans += 1
					spanLo[spans], spanHi[spans] = max(s0, a0), min(s1, a1)
					if s0 <= front and s1 > front then
						front = s1
						moved = true
					end
				end
			end
			if moved and m > 1 then
				near[m], near[1] = near[1], q
			end
			if front >= a1 then
				work(2 * chords)
				return 0, a1 - a0
			end
		end
		work(2 * chords)
		for i = 2, spans do -- by where they start; they are few
			local lo, hi = spanLo[i], spanHi[i]
			local j = i - 1
			while j >= 1 and spanLo[j] > lo do
				spanLo[j + 1], spanHi[j + 1] = spanLo[j], spanHi[j]
				j -= 1
			end
			spanLo[j + 1], spanHi[j + 1] = lo, hi
		end
		-- their union, whole runs at a time: the same numbers in the same order, whatever order the parts were asked in
		local hidden, lo, hi = 0, a0, a0
		for i = 1, spans do
			if spanLo[i] > hi then
				hidden += hi - lo
				lo, hi = spanLo[i], spanHi[i]
			elseif spanHi[i] > hi then
				hi = spanHi[i]
			end
		end
		return (a1 - a0) - (hidden + hi - lo), a1 - a0
	end

	-- What the verdict reads on a flat patch with near parts (§4.4). The first nh of them hide its centre.
	local function flatShown(p: Prepared, nn: number, nh: number, x: number, y: number, z: number, nx: number, ny: number,
		nz: number, e1x: number, e1y: number, e1z: number, e2x: number, e2y: number, e2z: number, w: number): number
		for m = 1, nh do
			local q = near[m]
			local all = true
			for c = 1, 4 do
				local a, b = CORNERS_A[c] * VERDICT_CORNER, CORNERS_B[c] * VERDICT_CORNER
				local sx, sy, sz = x + a * e1x + b * e2x, y + a * e1y + b * e2y, z + a * e1z + b * e2z
				if not hides(q, p.index, sx, sy, sz, sx + delta * nx, sy + delta * ny, sz + delta * nz) then
					all = false
					break
				end
			end
			work(4)
			if all then
				return 0
			end
		end

		-- Which near parts reach the patch at all, on their own 3 axes, as a box: near goes by distance, and most near parts
		-- stand clear of the patch's plane. The rest change no line, so this gives the same answer, sooner.
		local l1 = sqrt(e1x * e1x + e1y * e1y + e1z * e1z)
		local l2 = sqrt(e2x * e2x + e2y * e2y + e2z * e2z)
		local u1x, u1y, u1z = e1x / l1, e1y / l1, e1z / l1
		local u2x, u2y, u2z = e2x / l2, e2y / l2, e2z / l2
		local reaching = 0
		for m = 1, nn do
			local q = near[m]
			local qi = q.index
			local dx, dy, dz = x - q.cx, y - q.cy, z - q.cz
			local ax, ay, az = q.ux, q.uy, q.uz
			local bx, by, bz = q.vx, q.vy, q.vz
			local cx, cy, cz = q.wx, q.wy, q.wz
			local ox, oy, oz = dx * ax + dy * ay + dz * az, dx * bx + dy * by + dz * bz, dx * cx + dy * cy + dz * cz
			local px, py, pz = u1x * ax + u1y * ay + u1z * az, u1x * bx + u1y * by + u1z * bz, u1x * cx + u1y * cy + u1z * cz
			local rx, ry, rz = u2x * ax + u2y * ay + u2z * az, u2x * bx + u2y * by + u2z * bz, u2x * cx + u2y * cy + u2z * cz
			local sx, sy, sz = nx * ax + ny * ay + nz * az, nx * bx + ny * by + nz * bz, nx * cx + ny * cy + nz * cz
			sx, sy, sz = delta * sx, delta * sy, delta * sz
			local hx = l1 * abs(px) + l2 * abs(rx) + q.hx + 2 * eps
			local hy = l1 * abs(py) + l2 * abs(ry) + q.hy + 2 * eps
			local hz = l1 * abs(pz) + l2 * abs(rz) + q.hz + 2 * eps
			local atSurface = abs(ox) <= hx and abs(oy) <= hy and abs(oz) <= hz
			local atProbe = abs(ox + sx) <= hx and abs(oy + sy) <= hy and abs(oz + sz) <= hz
			reachesSurface[qi], reachesProbe[qi] = atSurface, atProbe
			if atSurface or atProbe then
				reaching += 1
				near[reaching] = q
				local f = 12 * (qi - 1)
				frames[f + 1], frames[f + 2], frames[f + 3] = ox, oy, oz
				frames[f + 4], frames[f + 5], frames[f + 6] = px, py, pz
				frames[f + 7], frames[f + 8], frames[f + 9] = rx, ry, rz
				frames[f + 10], frames[f + 11], frames[f + 12] = sx, sy, sz
			end
		end
		work(nn)
		if reaching == 0 then
			return w
		end

		local shownA, onA, loA, hiA = 0, 0, math.huge, -math.huge
		for i = 1, 4 do
			local c = SUB_GRID[i]
			local shown, on = lineShown(p, reaching, 3, 6, c * l2, l1, x + c * e2x, y + c * e2y, z + c * e2z, u1x, u1y, u1z)
			if on > 0 then
				shownA += shown
				onA += on
				loA, hiA = min(loA, shown / on), max(hiA, shown / on)
			end
		end
		if hiA - loA <= LINES_AGREE and shownA > LINE_NOTHING * onA and shownA < (1 - LINE_NOTHING) * onA then
			return w * (shownA / onA) -- they agree on a fraction: whatever the other family reads, this one wins
		end
		local shownB, onB, loB, hiB = 0, 0, math.huge, -math.huge
		for i = 1, 4 do
			local c = SUB_GRID[i]
			local shown, on = lineShown(p, reaching, 6, 3, c * l1, l2, x + c * e1x, y + c * e1y, z + c * e1z, u2x, u2y, u2z)
			if on > 0 then
				shownB += shown
				onB += on
				loB, hiB = min(loB, shown / on), max(hiB, shown / on)
			end
		end
		-- onA, onB > 0: a sample stands on its face, and so do the points a quarter of the way back toward the face's corner or
		-- the cap's centre, which a line of each family passes through
		local readA, readB = shownA / onA, shownB / onB
		if readA <= LINE_NOTHING then
			return w * readB
		elseif readB <= LINE_NOTHING then
			return w * readA
		end
		local spreadA, spreadB = hiA - loA, hiB - loB
		if abs(spreadA - spreadB) > LINES_AGREE then
			return w * (if spreadA < spreadB then readA else readB)
		end
		return w * min(readA, readB)
	end

	-- A point of a Cylinder's side patch and the normal there: back on the surface, with the radial normal.
	local function sidePoint(p: Prepared, S: SurfaceSamples, k: number, a: number,
		b: number): (number, number, number, number, number, number)
		local x = S.x[k] + a * S.e1x[k] + b * S.e2x[k]
		local y = S.y[k] + a * S.e1y[k] + b * S.e2y[k]
		local z = S.z[k] + a * S.e1z[k] + b * S.e2z[k]
		local dx, dy, dz = x - p.cx, y - p.cy, z - p.cz
		local along = dx * p.ux + dy * p.uy + dz * p.uz
		local vx, vy, vz = dx - along * p.ux, dy - along * p.uy, dz - along * p.uz
		local l = sqrt(vx * vx + vy * vy + vz * vz)
		local mx, my, mz = vx / l, vy / l, vz / l
		return p.cx + along * p.ux + p.r * mx, p.cy + along * p.uy + p.r * my, p.cz + along * p.uz + p.r * mz, mx, my, mz
	end

	-- Does a near part hide this point? One that does likely hides the next point too, so it goes first: the same answer,
	-- sooner.
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
		local nn, nh = 0, 0 -- near parts, the first nh of them hiding the centre
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
			local hid = d0 < -eps or (rank[q.index] < rank[index] and d0 <= eps) or d1 <= eps
			if hid and c > 1 then
				cand[c], cand[1] = cand[1], q -- it likely hides the next sample too
			end
			if abs(d0) <= lim or abs(d1) <= lim then
				nn += 1
				near[nn] = q
				if hid then
					nh += 1
					near[nn], near[nh] = near[nh], q
				end
			elseif hid then
				return 0 -- a part too far to change over the patch hides all of it
			end
		end
		if nn == 0 then
			return w
		end
		local hiddenNear = nh > 0
		if p.code == BALL then
			return if hiddenNear then 0 else w -- no patch: the centre verdict
		end
		if S.flat[k] then
			return flatShown(p, nn, nh, x, y, z, nx, ny, nz, e1x, e1y, e1z, e2x, e2y, e2z, w)
		end

		-- a Cylinder's side: the 4 corners against the centre
		local uniform = true
		for c = 1, 4 do
			local sx, sy, sz, mx, my, mz = sidePoint(p, S, k, CORNERS_A[c] * VERDICT_CORNER, CORNERS_B[c] * VERDICT_CORNER)
			local hidden = hiddenByNear(index, nn, sx, sy, sz, sx + delta * mx, sy + delta * my, sz + delta * mz)
			if hidden ~= hiddenNear then
				uniform = false
			end
		end
		work(4 * nn)
		local cornerShows = not uniform
		if uniform and hiddenNear and nn > 1 then
			-- all five hidden, but by one part? Two can leave a slit between them.
			uniform = false
			for m = 1, nn do
				local q = near[m]
				if hides(q, index, x, y, z, ox, oy, oz) then
					local all = true
					for c = 1, 4 do
						local sx, sy, sz, mx, my, mz = sidePoint(p, S, k, CORNERS_A[c] * VERDICT_CORNER, CORNERS_B[c] * VERDICT_CORNER)
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

		local hiddenPoints = 0
		for i = 1, 4 do
			local a = SUB_GRID[i]
			for j = 1, 4 do
				local sx, sy, sz, mx, my, mz = sidePoint(p, S, k, a, SUB_GRID[j])
				if hiddenByNear(index, nn, sx, sy, sz, sx + delta * mx, sy + delta * my, sz + delta * mz) then
					hiddenPoints += 1
				end
			end
		end
		work(16 * nn)
		if hiddenPoints < 16 then
			return w * (16 - hiddenPoints) / 16
		end
		-- a strip narrower than the sub-grid's reach: through the centre, or along the rim
		if not hiddenNear then
			return w * VERDICT_STRIP_CENTRE
		end
		return if cornerShows then w * VERDICT_STRIP_RIM else 0
	end

	-- the verdict: each part on a grid of its own, against every part but exact copies and Dust, until it shows
	-- ENCLOSED_EXPOSED_MAX. How many other parts there are cannot change the grid or which patches get looked at, so
	-- hidden parts cannot change a verdict by coarsening or by using anything up; only a part that covers another can.
	local kept: { boolean } = table.create(N, false)
	local cleaned: { Cleaned } = {}
	local hider: { boolean } = table.create(N, false)
	for i = 1, N do
		hider[i] = not isCopy[i] and parts[i].volume >= Geo.MIN_PART_VOLUME
	end
	for i = 1, N do
		local p = parts[i]
		if p.volume < Geo.MIN_PART_VOLUME then
			table.insert(cleaned, { partId = p.id, reason = "Dust" :: CleanReason })
		elseif isCopy[i] then
			table.insert(cleaned, { partId = p.id, reason = "Enclosed" :: CleanReason })
		else
			local hOwn
			if p.code == BALL then
				hOwn = PI * p.r / 2 / (Geo.VERDICT_BALL_NF - 0.5) -- ceil((πr/2)/h) = VERDICT_BALL_NF
			else
				hOwn = Sampling.ladder(Geo.H_SURF, function(h: number): boolean
					return surfaceEstimate(p, h) <= Geo.VERDICT_SAMPLES
				end)
			end
			local S = Sampling.surfaceSamples(p, hOwn, work, Geo.VERDICT_TRIANGLE_CELLS)
			local cand: { Prepared } = {}
			for j = 1, N do
				if j ~= i and hider[j] and aabbOverlap(p, parts[j], delta + tol + hOwn) then
					table.insert(cand, parts[j])
				end
			end
			local need = Geo.ENCLOSED_EXPOSED_MAX * p.area
			local visible = 0
			local units = #cand + 1
			for k = 1, S.n do
				visible += shownArea(p, S, k, cand)
				work(units)
				if visible >= need then
					break
				end
			end
			if visible >= need then
				kept[i] = true
			else
				table.insert(cleaned, { partId = p.id, reason = "Enclosed" :: CleanReason })
			end
		end
	end

	-- the measure: the kept parts, against kept parts only, on a ladder (samples × (1 + candidate parts) within
	-- N_SURF_WORK) and a sub-grid budget of their own, in rank order. It runs whatever was cleaned, so a hidden part
	-- anywhere cannot reach a kept part's area or contact rows.
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
		local i = byRank[r].index
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
	}
end

return table.freeze(Sampling)
