--!strict
-- S2 prototype v2: Physics/Analyze (quick validation -> connectivity -> exposure + cleaning -> owned volumes and
-- mass -> edge -> 8 factors per step work set -> g, m, d, tiers). Input: canonical BlueprintCore {parts = {PartData}}.
-- Changes from v1 (spec final §4/§5): no sanitizer (canonical input asserted), fixed-plane soft Asymmetry,
-- exposure with burial/coincidence/probe rules + kept-only second pass, exact polyhedron overlaps, axis probes
-- for round parts, thin-share Thinness, dilated edge raster, main-chain EdgeLength, kept Blade + Grip rule.
local Num = require("./num")
local Shapes = require("./shapes")
local Gjk = require("./gjk")
local Overlap = require("./overlap")
-- V-A patch: the M3 emulator. opts.build = true takes kept, exposedKept, contact and ownership from the build's modules,
-- then runs the prototype's edge and factor formulas on them (nothing else in this file is changed).
local BSampling = require("../repo/src/shared/Physics/Sampling")
local BShapes = require("../repo/src/shared/Physics/Shapes")
local BMass = require("../repo/src/shared/Physics/MassProps")

local sqrt, max, min, floor, ceil, abs = math.sqrt, math.max, math.min, math.floor, math.ceil, math.abs
local clock = os.clock

local Analyze = {}

local FACTORS = { "PartCount", "Thinness", "Asymmetry", "SurfaceComplexity", "EdgeLength", "Joints", "MaterialMix", "Volume" }
Analyze.FACTORS = FACTORS

local CFG: any = {
	HITBOX_MIN = { -0.8, 0.0, -0.3 },
	HITBOX_MAX = { 0.8, 5.0, 0.3 },
	MIN_DIM = 0.02,
	MAX_DIM = 6.0,
	POS_ABS_MAX = 16,
	MAX_PARTS = 24,
	EPS_CONTAIN = 1e-4,
	CONTACT_TOL = 0.01,
	EPS_GEOM = 1e-7,
	HIDE_OFFSET = 0.012, -- CONTACT_TOL + 0.002: a face across any gap validation calls connected is hidden
	RASTER_TOL = 0.005, -- CONTACT_TOL / 2
	SLOTS = {
		{ id = "Blade", required = true, min = 1, max = 12, rank = 1 },
		{ id = "Guard", required = false, min = 0, max = 8, rank = 2 },
		{ id = "Grip", required = true, min = 1, max = 6, rank = 3 },
		{ id = "Pommel", required = false, min = 0, max = 4, rank = 4 },
	},
	STRIKING_SLOT = "Blade",
	GRIP_SLOT = "Grip",
	GUARD_SLOT = "Guard",
	-- sampling
	H_VOL = 0.05,
	N_MIN_AXIS = 2,
	N_MAX_AXIS = 48,
	N_MAX_PART = 3000,
	N_VOL_TOTAL = 12000,
	H_SURF = 0.04,
	NS_MAX = 64,
	N_SURF_WORK = 40000, -- surface samples x candidate parts (coarsening ladder)
	H_LADDER = { 1, 1.25, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10, 12, 16 },
	-- overlaps
	H_OVERLAP = 0.0125,
	OVERLAP_N_MIN = 4,
	OVERLAP_N_MAX = 24,
	N_OVERLAP_WORK = 40000, -- refined overlap cells x (1 + higher parts)
	-- cleaning
	MIN_PART_VOLUME = 0.0002,
	ENCLOSED_EXPOSED_MAX = 0.02,
	V_PART_FULL = 0.004,
	-- frame
	AXIS_ELONGATION = 1.5,
	AXIS_MAX_TILT_COS = 0.7071,
	-- thinness
	THICK_BUDGET = 400,
	SIGMA_LO = 45,
	SIGMA_HI = 130,
	THIN_SHARE_MIN = 0.25,
	THIN_REF = "Striking", -- "Set" = R3-03 as proposed (share of the whole work set)
	-- asymmetry
	ASYM_TOL = 0.02,
	ASYM_RAMP = 0.03,
	ASYM_N_MIN = 10,
	ASYM_AXIS_X = 0.6, -- local axes with |axis.x| >= this get ASYM_N_MIN probes (at most two axes can)
	ASYM_WORK = 30000, -- asymmetry probes x (1 + mirror candidates + higher parts), per work set
	-- edge
	EDGE_CELL = 0.02,
	EDGE_MAX_THICK = 0.25,
	EDGE_DOWN_COS = 0.5,
	EDGE_SIMPLIFY = 1.0,
	EDGE_GAP_BRIDGE = 3.0,
	EDGE_MIN_CHAIN = 3.0,
	EDGE_MAX_CELLS = 12000,
	EDGE_MAX_WORK = 30000, -- raster cells x parts spanning the row
	EDGE_MAX_POINTS = 256,
	CUT_LO = 10,
	CUT_HI = 60,
	-- joints
	JOINT_BOOST = 1.0,
	A_JOINT_REF = 0.05,
	-- reference ranges {lo, hi}
	REF = {
		PartCount = { 3, 16 },
		Asymmetry = { 0.0, 0.6 },
		SurfaceComplexity = { 2.3, 2.9 },
		EdgeLength = { 4.8, 8.0 },
		Joints = { 3, 24 },
		MaterialMix = { 1, 4 },
		Volume = { 0.08, 0.80 },
	},
	-- Definitions/Materials (ordered): density mu/stud^3, hardness 0..100, difficultyTerm (MVP 0)
	MATERIALS = {
		{ id = "Iron", density = 7.87, hardness = 45, difficultyTerm = 0.0 },
		{ id = "Steel", density = 7.85, hardness = 70, difficultyTerm = 0.0 },
	},
	-- Definitions/CraftPlans (Sword) + Steps factor weights (arrays)
	STEPS = {
		{ step = "Smelting", worksOn = "All", w = { { "Volume", 1.0 } } },
		{ step = "Hammering", worksOn = "All", w = { { "Thinness", 0.40 }, { "Asymmetry", 0.30 }, { "SurfaceComplexity", 0.30 } } },
		{ step = "Sharpening", worksOn = { "Blade" }, w = { { "EdgeLength", 0.50 }, { "Asymmetry", 0.30 }, { "SurfaceComplexity", 0.20 } } },
	},
	TIERS = {
		{ id = "Normal", dMin = 0.0, enabled = true },
		{ id = "Hard", dMin = 0.2, enabled = true },
		{ id = "Expert", dMin = 0.4, enabled = false },
		{ id = "Master", dMin = 0.6, enabled = false },
		{ id = "Hell", dMin = 0.8, enabled = false },
	},
	N_SUB_WORK = 24000, -- sub-point x near-candidate tests for boundary patches (corner pre-test + 4 x 4 sub-grid)
	-- difficulty frame: "Fixed" = blueprint +Y (plane x = 0); "KeptGrip" = grip axis of kept Grip parts
	DIFF_FRAME = "Fixed",
	-- execution
	CHECK_UNITS = 500,
	BALANCE_VERSION = 1,
}
Analyze.CFG = CFG

local function slotRule(id: string): any
	for _, s in ipairs(CFG.SLOTS) do
		if s.id == id then
			return s
		end
	end
	return nil
end

local function material(id: string): any
	for _, m in ipairs(CFG.MATERIALS) do
		if m.id == id then
			return m
		end
	end
	error("unknown material " .. id)
end

-- ---------------------------------------------------------------- canonical form (stand-in for S1 Canonical.isCanonical)
local function finite(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end
function Analyze.isCanonical(core: any): (boolean, string?)
	local parts = core.parts
	if #parts > CFG.MAX_PARTS then
		return false, "TooManyParts"
	end
	local lastId = -math.huge
	for i, p in ipairs(parts) do
		if p.id <= lastId then
			return false, "order@" .. i
		end
		lastId = p.id
		for k = 1, 3 do
			if not finite(p.pos[k]) or abs(p.pos[k]) > CFG.POS_ABS_MAX then
				return false, "pos@" .. i
			end
			if not finite(p.size[k]) or p.size[k] < CFG.MIN_DIM or p.size[k] > CFG.MAX_DIM then
				return false, "size@" .. i
			end
		end
		local q = p.rot
		local n2 = q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4]
		if abs(n2 - 1) > 1e-9 then
			return false, "quat@" .. i
		end
		if q[4] < 0 or (q[4] == 0 and (q[1] < 0 or (q[1] == 0 and (q[2] < 0 or (q[2] == 0 and q[3] < 0))))) then
			return false, "hemisphere@" .. i
		end
		local cs = Shapes.canonicalSize(p.shape, p.size)
		if cs[1] ~= p.size[1] or cs[2] ~= p.size[2] or cs[3] ~= p.size[3] then
			return false, "shapeSize@" .. i
		end
	end
	return true, nil
end

-- ---------------------------------------------------------------- helpers
local function mergedLength(ivs: { number }, n: number, tol: number): number
	for i = 2, n do
		local a, b = ivs[2 * i - 1], ivs[2 * i]
		local j = i - 1
		while j >= 1 and ivs[2 * j - 1] > a do
			ivs[2 * j + 1], ivs[2 * j + 2] = ivs[2 * j - 1], ivs[2 * j]
			j -= 1
		end
		ivs[2 * j + 1], ivs[2 * j + 2] = a, b
	end
	local total = 0
	local lo, hi = ivs[1], ivs[2]
	for i = 2, n do
		local a, b = ivs[2 * i - 1], ivs[2 * i]
		if a <= hi + tol then
			if b > hi then
				hi = b
			end
		else
			total += hi - lo
			lo, hi = a, b
		end
	end
	return total + (hi - lo)
end

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
local function lineHitsAabb(q: any, ox: number, oy: number, oz: number, ux: number, uy: number, uz: number): boolean
	local t0, t1 = slab(-math.huge, math.huge, ox, ux, q.minx, q.maxx)
	if t0 > t1 then
		return false
	end
	t0, t1 = slab(t0, t1, oy, uy, q.miny, q.maxy)
	if t0 > t1 then
		return false
	end
	t0, t1 = slab(t0, t1, oz, uz, q.minz, q.maxz)
	return t0 <= t1
end

-- length of the merged union chord through o (grown from [0,0]) over the list
local function unionChordAt(list: { any }, ox: number, oy: number, oz: number, ux: number, uy: number, uz: number, tol: number): number
	local ivs = {}
	local n = 0
	for _, q in ipairs(list) do
		if lineHitsAabb(q, ox, oy, oz, ux, uy, uz) then
			local ok, t0, t1 = Shapes.chord(q, ox, oy, oz, ux, uy, uz)
			if ok then
				n += 1
				ivs[2 * n - 1], ivs[2 * n] = t0, t1
			end
		end
	end
	local lo, hi = 0, 0
	local used = table.create(n, false)
	local changed = true
	while changed do
		changed = false
		for i = 1, n do
			if not used[i] and ivs[2 * i - 1] <= hi + tol and ivs[2 * i] >= lo - tol then
				used[i] = true
				if ivs[2 * i - 1] < lo then
					lo = ivs[2 * i - 1]
				end
				if ivs[2 * i] > hi then
					hi = ivs[2 * i]
				end
				changed = true
			end
		end
	end
	return hi - lo
end

-- Douglas-Peucker on an open polyline; returns kept indices
local function simplify(xs: { number }, ys: { number }, tol: number): { number }
	local n = #xs
	local keep = table.create(n, false)
	keep[1], keep[n] = true, true
	local stack = { 1, n }
	while #stack > 0 do
		local b = table.remove(stack) :: number
		local a = table.remove(stack) :: number
		local ax, ay, bx, by = xs[a], ys[a], xs[b], ys[b]
		local dx, dy = bx - ax, by - ay
		local ll = dx * dx + dy * dy
		local best, bi = -1, -1
		for i = a + 1, b - 1 do
			local px, py = xs[i] - ax, ys[i] - ay
			local t = if ll > 1e-24 then (px * dx + py * dy) / ll else 0
			if t < 0 then
				t = 0
			elseif t > 1 then
				t = 1
			end
			local ex, ey = px - t * dx, py - t * dy
			local d = sqrt(ex * ex + ey * ey)
			if d > best then
				best, bi = d, i
			end
		end
		if best > tol then
			keep[bi] = true
			table.insert(stack, a)
			table.insert(stack, bi)
			table.insert(stack, bi)
			table.insert(stack, b)
		end
	end
	local r = {}
	for i = 1, n do
		if keep[i] then
			table.insert(r, i)
		end
	end
	return r
end

-- grip frame from a list of Grip parts: point = volume-weighted centroid; axis from eligible parts (XY projection)
local function gripFrame(list: { any }): ({ number }, { number })
	local gV, gX, gY, gZ = 0, 0, 0, 0
	local axX, axY = 0, 0
	for _, p in ipairs(list) do
		gV += p.volume
		gX += p.volume * p.gx
		gY += p.volume * p.gy
		gZ += p.volume * p.gz
		local ex, ey = nil, nil
		if p.volume >= CFG.MIN_PART_VOLUME then
			if p.code == Shapes.CYL then
				ex, ey = p.ux, p.uy
			elseif p.code ~= Shapes.BALL then
				-- longest local axis (ties X < Y < Z) must be >= AXIS_ELONGATION x the middle one
				local h = { { p.hx, p.ux, p.uy }, { p.hy, p.vx, p.vy }, { p.hz, p.wx, p.wy } }
				local i1 = 1
				for k = 2, 3 do
					if h[k][1] > h[i1][1] then
						i1 = k
					end
				end
				local mid = 0
				for k = 1, 3 do
					if k ~= i1 and h[k][1] > mid then
						mid = h[k][1]
					end
				end
				if h[i1][1] >= CFG.AXIS_ELONGATION * mid then
					ex, ey = h[i1][2], h[i1][3]
				end
			end
		end
		if ex ~= nil and ey ~= nil then
			if ey < 0 or (ey == 0 and ex < 0) then
				ex, ey = -ex, -ey
			end
			axX += p.volume * ex
			axY += p.volume * ey
		end
	end
	local g = { 0, 0, 0 }
	if gV > 0 then
		g = { gX / gV, gY / gV, gZ / gV }
	end
	local an = sqrt(axX * axX + axY * axY)
	local axis = { 0, 1 }
	if an > 1e-9 and axY / an >= CFG.AXIS_MAX_TILT_COS then
		axis = { axX / an, axY / an }
	end
	return g, axis
end

-- ---------------------------------------------------------------- quick validation (Pipeline.quick)
function Analyze.quickErrors(parts: { any }): { any }
	local errs = {}
	for _, s in ipairs(CFG.SLOTS) do
		local c = 0
		for _, p in ipairs(parts) do
			if p.slot == s.id then
				c += 1
			end
		end
		if c < s.min then
			table.insert(errs, { code = "SlotMissing", slot = s.id })
		elseif c > s.max then
			table.insert(errs, { code = "SlotTooMany", slot = s.id })
		end
	end
	local hmin, hmax, e = CFG.HITBOX_MIN, CFG.HITBOX_MAX, CFG.EPS_CONTAIN
	for _, p in ipairs(parts) do
		if p.minx < hmin[1] - e or p.miny < hmin[2] - e or p.minz < hmin[3] - e or p.maxx > hmax[1] + e or p.maxy > hmax[2] + e or p.maxz > hmax[3] + e then
			table.insert(errs, { code = "OutOfHitbox", partId = p.id })
		end
	end
	return errs
end

function Analyze.quick(core: any): any
	local parts = {}
	for i, raw in ipairs(core.parts) do
		parts[i] = Shapes.prepare(raw, i)
	end
	local errs = Analyze.quickErrors(parts)
	return { ok = #errs == 0, errors = errs }
end

-- ---------------------------------------------------------------- edge profile
local function edgeProfile(parts: { any }, kept: { boolean }, axis: { number }, tick: (number) -> ()): any
	local H = CFG.EDGE_CELL
	local RT = CFG.RASTER_TOL
	local blade, hilt = {}, {}
	for _, p in ipairs(parts) do
		if kept[p.index] then
			if p.slot == CFG.STRIKING_SLOT then
				table.insert(blade, p)
			else
				table.insert(hilt, p)
			end
		end
	end
	local res: any = { chains = {}, length = 0, cells = 0, loops = 0, bladeArea = 0, bladeMeanThickness = 0 }
	if #blade == 0 then
		return res
	end
	local mnx, mxx, mny, mxy = math.huge, -math.huge, math.huge, -math.huge
	for _, b in ipairs(blade) do
		mnx, mxx, mny, mxy = min(mnx, b.minx), max(mxx, b.maxx), min(mny, b.miny), max(mxy, b.maxy)
	end
	local i0, i1, j0, j1, NI, NJ
	-- lattice: x anchored at the fixed plane x = 0 (mirror-symmetric cells), y at the lowest kept Blade point
	-- (a pure Y translation gives the same raster)
	local Y0 = mny
	for _, k in ipairs(CFG.H_LADDER) do
		H = CFG.EDGE_CELL * k
		i0 = floor((mnx - RT) / H) - 1
		i1 = floor((mxx + RT) / H) + 1
		j0 = floor(-RT / H) - 1
		j1 = floor((mxy + RT - Y0) / H) + 1
		NI, NJ = i1 - i0 + 1, j1 - j0 + 1
		-- work = cells x parts whose y-range (dilated) contains the row
		local work = 0
		for jj = 0, NJ - 1 do
			local y = Y0 + (j0 + jj + 0.5) * H
			local c = 0
			for _, b in ipairs(blade) do
				if y >= b.miny - RT and y <= b.maxy + RT then
					c += 1
				end
			end
			for _, h in ipairs(hilt) do
				if y >= h.miny - RT and y <= h.maxy + RT then
					c += 1
				end
			end
			work += NI * c
		end
		if NI * NJ <= CFG.EDGE_MAX_CELLS and work <= CFG.EDGE_MAX_WORK then
			break
		end
	end
	res.cells, res.cell = NI * NJ, H
	local cov = table.create(NI * NJ, false)
	local thick = table.create(NI * NJ, 0)
	local hil = table.create(NI * NJ, false)
	local ivs, ivd = {}, {}
	local coveredU, thickSum = 0, 0
	for jj = 0, NJ - 1 do
		local y = Y0 + (j0 + jj + 0.5) * H
		local rowB, rowH = {}, {}
		for _, b in ipairs(blade) do
			if y >= b.miny - RT and y <= b.maxy + RT then
				table.insert(rowB, b)
			end
		end
		for _, h in ipairs(hilt) do
			if y >= h.miny - RT and y <= h.maxy + RT then
				table.insert(rowH, h)
			end
		end
		for ii = 0, NI - 1 do
			local x = (i0 + ii + 0.5) * H
			local idx = jj * NI + ii + 1
			local n, nd = 0, 0
			for _, b in ipairs(rowB) do
				if x >= b.minx - RT and x <= b.maxx + RT and y >= b.miny - RT and y <= b.maxy + RT then
					local ok, t0, t1 = Shapes.chord(b, x, y, 0, 0, 0, 1, RT)
					if ok and t1 > t0 then
						nd += 1
						ivd[2 * nd - 1], ivd[2 * nd] = t0, t1
						local ok2, s0, s1 = Shapes.chord(b, x, y, 0, 0, 0, 1)
						if ok2 and s1 > s0 then
							n += 1
							ivs[2 * n - 1], ivs[2 * n] = s0, s1
						end
					end
				end
			end
			if nd > 0 then
				cov[idx] = true
				if n > 0 then
					thick[idx] = mergedLength(ivs, n, CFG.CONTACT_TOL)
					coveredU += 1
					thickSum += thick[idx]
				else
					thick[idx] = mergedLength(ivd, nd, CFG.CONTACT_TOL)
				end
			end
			for _, h in ipairs(rowH) do
				if x >= h.minx - RT and x <= h.maxx + RT then
					local ok, t0, t1 = Shapes.chord(h, x, y, 0, 0, 0, 1, RT)
					if ok and t1 >= t0 then
						hil[idx] = true
						break
					end
				end
			end
			tick(1 + #rowB + #rowH)
		end
	end
	res.bladeArea = coveredU * H * H
	res.bladeMeanThickness = if coveredU > 0 then thickSum / coveredU else 0
	-- crack edges, covered cell on the left (outer loops CCW)
	local VI = NI + 1
	local eFrom, eTo, eDir, eIn, eOut = {}, {}, {}, {}, {}
	local outA, outB = {}, {}
	local ne = 0
	local function addEdge(fi, fj, ti, tj, dir, inIdx, outIdx)
		ne += 1
		local fv, tv = fj * VI + fi + 1, tj * VI + ti + 1
		eFrom[ne], eTo[ne], eDir[ne], eIn[ne], eOut[ne] = fv, tv, dir, inIdx, outIdx
		if outA[fv] == nil then
			outA[fv] = ne
		else
			outB[fv] = ne
		end
	end
	local function c(ii, jj)
		if ii < 0 or jj < 0 or ii >= NI or jj >= NJ then
			return false
		end
		return cov[jj * NI + ii + 1]
	end
	for jj = 0, NJ - 1 do
		tick(NI)
		for ii = 0, NI - 1 do
			if c(ii, jj) then
				local idx = jj * NI + ii + 1
				if not c(ii, jj - 1) then
					addEdge(ii, jj, ii + 1, jj, 0, idx, idx - NI)
				end
				if not c(ii + 1, jj) then
					addEdge(ii + 1, jj, ii + 1, jj + 1, 1, idx, idx + 1)
				end
				if not c(ii, jj + 1) then
					addEdge(ii + 1, jj + 1, ii, jj + 1, 2, idx, idx + NI)
				end
				if not c(ii - 1, jj) then
					addEdge(ii, jj + 1, ii, jj, 3, idx, idx - 1)
				end
			end
		end
	end
	local used = table.create(ne, false)
	local function vx(v)
		return (i0 + (v - 1) % VI) * H
	end
	local function vy(v)
		return Y0 + (j0 + (v - 1) // VI) * H
	end
	local ax, ay = axis[1], axis[2]
	local function emitRun(run: { number })
		tick(4 * #run)
		local xs, ys = { vx(eFrom[run[1]]) }, { vy(eFrom[run[1]]) }
		for _, ee in ipairs(run) do
			table.insert(xs, (vx(eFrom[ee]) + vx(eTo[ee])) / 2)
			table.insert(ys, (vy(eFrom[ee]) + vy(eTo[ee])) / 2)
		end
		table.insert(xs, vx(eTo[run[#run]]))
		table.insert(ys, vy(eTo[run[#run]]))
		local tolS = CFG.EDGE_SIMPLIFY * H
		local k = simplify(xs, ys, tolS)
		while #k > CFG.EDGE_MAX_POINTS do
			tolS *= 2
			k = simplify(xs, ys, tolS)
		end
		local m = #k - 1
		local segLen, sharp = table.create(m, 0), table.create(m, false)
		for s = 1, m do
			local dx, dy = xs[k[s + 1]] - xs[k[s]], ys[k[s + 1]] - ys[k[s]]
			local len = sqrt(dx * dx + dy * dy)
			segLen[s] = len
			-- outward normal of a CCW outline segment = (dy, -dx)/len; not facing the pommel: n.A >= -EDGE_DOWN_COS
			sharp[s] = len > 0 and (dy * ax - dx * ay) / len >= -CFG.EDGE_DOWN_COS
		end
		local s = 1
		while s <= m do
			if not sharp[s] then
				local e2, gl = s, 0
				while e2 <= m and not sharp[e2] do
					gl += segLen[e2]
					e2 += 1
				end
				if s > 1 and e2 <= m and gl < CFG.EDGE_GAP_BRIDGE * H then
					for q = s, e2 - 1 do
						sharp[q] = true
					end
				end
				s = e2
			else
				s += 1
			end
		end
		local chain, clen = nil, 0
		local function flush()
			if chain and clen >= CFG.EDGE_MIN_CHAIN * H then
				table.insert(res.chains, { points = chain, length = clen })
			end
			chain, clen = nil, 0
		end
		for q = 1, m do
			if sharp[q] then
				if chain == nil then
					chain = { { xs[k[q]], ys[k[q]] } }
				end
				table.insert(chain :: any, { xs[k[q + 1]], ys[k[q + 1]] })
				clen += segLen[q]
			else
				flush()
			end
		end
		flush()
	end
	for e0 = 1, ne do
		tick(1)
		if not used[e0] then
			local loop = {}
			local e = e0
			while true do
				used[e] = true
				table.insert(loop, e)
				local v = eTo[e]
				local a, b = outA[v], outB[v]
				local nxt
				if b == nil then
					nxt = a
				else
					local right = (eDir[e] + 3) % 4
					if eDir[a] == right and not used[a] then
						nxt = a
					elseif eDir[b] == right and not used[b] then
						nxt = b
					else
						nxt = if not used[a] then a else b
					end
				end
				if nxt == nil or nxt == e0 or used[nxt] then
					break
				end
				e = nxt
			end
			res.loops += 1
			local area = 0
			for _, ee in ipairs(loop) do
				area += vx(eFrom[ee]) * vy(eTo[ee]) - vx(eTo[ee]) * vy(eFrom[ee])
			end
			if area > 0 then
				local m = #loop
				local elig = table.create(m, false)
				local startAt = 0
				for k, ee in ipairs(loop) do
					local outIdx = eOut[ee]
					local buried = outIdx >= 1 and outIdx <= NI * NJ and hil[outIdx]
					elig[k] = not buried and thick[eIn[ee]] <= CFG.EDGE_MAX_THICK
					if not elig[k] and startAt == 0 then
						startAt = k
					end
				end
				if startAt == 0 then
					local best, bk = math.huge, 1
					for k, ee in ipairs(loop) do
						local key = vy(eFrom[ee]) * 1e6 + vx(eFrom[ee])
						if key < best then
							best, bk = key, k
						end
					end
					local run = {}
					for s = 0, m - 1 do
						table.insert(run, loop[((bk - 1 + s) % m) + 1])
					end
					emitRun(run)
				else
					local run = nil
					for s = 0, m - 1 do
						local k = ((startAt - 1 + s) % m) + 1
						if elig[k] then
							if run == nil then
								run = {}
							end
							table.insert(run :: { number }, loop[k])
						elseif run ~= nil then
							emitRun(run)
							run = nil
						end
					end
					if run ~= nil then
						emitRun(run)
					end
				end
			end
		end
	end
	table.sort(res.chains, function(a: any, b: any): boolean
		if a.length ~= b.length then
			return a.length > b.length
		end
		if a.points[1][1] ~= b.points[1][1] then
			return a.points[1][1] < b.points[1][1]
		end
		return a.points[1][2] < b.points[1][2]
	end)
	res.length = if #res.chains > 0 then res.chains[1].length else 0
	local all = 0
	for _, ch in ipairs(res.chains) do
		all += ch.length
	end
	res.allChainsLength = all
	return res
end

-- ---------------------------------------------------------------- main
function Analyze.run(core: any, opts: any?): any
	local o = opts or {}
	local checkpoint = o.checkpoint
	local units = 0
	local function tick(n: number)
		units += n
		if units >= CFG.CHECK_UNITS then
			units = 0
			if checkpoint then
				checkpoint()
			end
		end
	end
	local function phase()
		units = 0
		if checkpoint then
			checkpoint()
		end
	end
	local T: any = {}
	local tStart = clock()
	local t = tStart
	local tol = CFG.CONTACT_TOL
	local EPS = CFG.EPS_GEOM
	local parts = {}
	for i, raw in ipairs(core.parts) do
		parts[i] = Shapes.prepare(raw, i)
	end
	local N = #parts
	local R: any = { name = core.name, balanceVersion = CFG.BALANCE_VERSION, parts = N }

	-- ======== 1. quick validation (early exit)
	local errs = Analyze.quickErrors(parts)
	if #errs > 0 then
		R.valid = false
		R.validation = { ok = false, errors = errs, quick = true, components = {} }
		T.total = clock() - tStart
		R.T = T
		return R
	end
	phase()

	-- ======== 2. connectivity (GJK contact graph) and orientation
	local conn = {}
	for i = 1, N do
		conn[i] = table.create(N, false)
	end
	local parent = {}
	for i = 1, N do
		parent[i] = i
	end
	local function find(i)
		while parent[i] ~= i do
			parent[i] = parent[parent[i]]
			i = parent[i]
		end
		return i
	end
	local gjkCalls = 0
	for i = 1, N - 1 do
		local A = parts[i]
		for j = i + 1, N do
			local B = parts[j]
			if Shapes.aabbOverlap(A, B, tol) then
				gjkCalls += 1
				local ok = Gjk.within(A, B, tol)
				if ok then
					conn[i][j], conn[j][i] = true, true
					local ri, rj = find(i), find(j)
					if ri ~= rj then
						if ri < rj then
							parent[rj] = ri
						else
							parent[ri] = rj
						end
					end
				end
				tick(20)
			end
		end
	end
	-- main component = most Grip volume, else largest volume, then lowest root
	local compGrip, compV = {}, {}
	for i = 1, N do
		local r = find(i)
		compV[r] = (compV[r] or 0) + parts[i].volume
		compGrip[r] = (compGrip[r] or 0) + (if parts[i].slot == CFG.GRIP_SLOT then parts[i].volume else 0)
	end
	local mainRoot = 0
	for i = 1, N do
		if find(i) == i then
			if mainRoot == 0 or compGrip[i] > compGrip[mainRoot] or (compGrip[i] == compGrip[mainRoot] and compV[i] > compV[mainRoot]) then
				mainRoot = i
			end
		end
	end
	local verrs = {}
	local components = {}
	for i = 1, N do
		if find(i) == i and i ~= mainRoot then
			local ids, best, bvx, bvy, bvz, nearest = {}, math.huge, 0, 0, 0, 0
			for f = 1, N do
				if find(f) == i then
					table.insert(ids, parts[f].id)
					for m = 1, N do
						if find(m) == mainRoot then
							local d, vx, vy, vz = Gjk.distance(parts[f], parts[m])
							tick(40)
							if d < best then
								best, bvx, bvy, bvz, nearest = d, vx, vy, vz, parts[m].id
							end
						end
					end
				end
			end
			local l = sqrt(bvx * bvx + bvy * bvy + bvz * bvz)
			table.insert(components, { partIds = ids, gap = best, dir = if l > 0 then { -bvx / l, -bvy / l, -bvz / l } else { 0, 0, 0 }, nearestPartId = nearest })
		end
	end
	for i = 1, N do
		if find(i) ~= mainRoot then
			table.insert(verrs, { code = "Disconnected", partId = parts[i].id })
		end
	end
	-- physics grip frame (all Grip parts) and orientation
	local gripAll, bladeAll = {}, {}
	for _, p in ipairs(parts) do
		if p.slot == CFG.GRIP_SLOT then
			table.insert(gripAll, p)
		elseif p.slot == CFG.STRIKING_SLOT then
			table.insert(bladeAll, p)
		end
	end
	local grip, axis = gripFrame(gripAll)
	do
		local bV, bA = 0, 0
		for _, p in ipairs(bladeAll) do
			bV += p.volume
			bA += p.volume * ((p.gx - grip[1]) * axis[1] + (p.gy - grip[2]) * axis[2])
		end
		if bV > 0 and bA / bV <= 0 then
			table.insert(verrs, { code = "BladeNotAboveGrip" })
		end
	end
	R.gjkCalls = gjkCalls
	T.validate = clock() - t
	t = clock()
	phase()

	-- ======== 3. surface exposure (pass 1: all parts hide), cleaning, pass 2 (kept parts hide)
	-- A sample is hidden by another part q if it is buried in q (sd < -EPS), lies on q's surface and q has the lower
	-- index (coincident face, counted once), or its probe s + HIDE_OFFSET*n is inside q. Planar samples whose patch
	-- may straddle a hiding boundary (some q with |sd| <= patch radius at the sample or its probe) are re-tested on a
	-- 4 x 4 sub-grid against those q only (sd is 1-Lipschitz, so every other q gives the same verdict on the patch).
	local contact = {}
	for i = 1, N do
		contact[i] = table.create(N, 0)
	end
	local surfSamples = 0
	local delta = CFG.HIDE_OFFSET
	local hSurf = CFG.H_SURF
	for _, k in ipairs(CFG.H_LADDER) do
		hSurf = CFG.H_SURF * k
		local est = 0
		for _, p in ipairs(parts) do
			local nc = 0
			for _, q in ipairs(parts) do
				if q ~= p and Shapes.aabbOverlap(p, q, delta + tol + hSurf) then
					nc += 1
				end
			end
			est += Shapes.surfaceEstimate(p, hSurf, CFG.NS_MAX) * (1 + nc)
		end
		if est <= CFG.N_SURF_WORK then
			break
		end
	end
	R.hSurf = hSurf
	local subLeft = CFG.N_SUB_WORK
	local subCount = 0
	local near = {}
	local cp: { number } = contact[1]
	local function hides(q: any, pIndex: number, x: number, y: number, z: number, ox: number, oy: number, oz: number): boolean
		if Shapes.aabbContains(q, x, y, z, 2 * EPS) then
			local d0 = Shapes.sd(q, x, y, z)
			if d0 < -EPS or (q.index < pIndex and d0 <= EPS) then
				return true
			end
		end
		return Shapes.aabbContains(q, ox, oy, oz, 2 * EPS) and Shapes.sd(q, ox, oy, oz) <= EPS
	end
	local function exposedWeight(p: any, S: any, k: number, cand: { any }, withContact: boolean): number
		local x, y, z, w = S.x[k], S.y[k], S.z[k], S.w[k]
		local nx, ny, nz = S.nx[k], S.ny[k], S.nz[k]
		local ox, oy, oz = x + delta * nx, y + delta * ny, z + delta * nz
		local e1x, e1y, e1z, e2x, e2y, e2z = S.e1x[k], S.e1y[k], S.e1z[k], S.e2x[k], S.e2y[k], S.e2z[k]
		local lim = sqrt(e1x * e1x + e1y * e1y + e1z * e1z) + sqrt(e2x * e2x + e2y * e2y + e2z * e2z) + EPS
		local m0 = max(tol, 2 * lim)
		local nn = 0
		local hiddenFar, hiddenNear = false, false
		for _, q in ipairs(cand) do
			local d0, d1 = math.huge, math.huge
			if Shapes.aabbContains(q, x, y, z, m0) then
				d0 = Shapes.sd(q, x, y, z)
				if withContact and d0 <= tol then
					cp[q.index] += w
				end
			end
			if Shapes.aabbContains(q, ox, oy, oz, 2 * lim) then
				d1 = Shapes.sd(q, ox, oy, oz)
			end
			local hid = d0 < -EPS or (q.index < p.index and d0 <= EPS) or d1 <= EPS
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
		if not S.flat[k] or subLeft < 20 * nn then
			return if hiddenNear then 0 else w
		end
		-- corner pre-test: the hiding regions are convex, so a patch whose 4 corners agree with the centre is uniform
		subLeft -= 4 * nn
		local uniform = true
		for c = 0, 3 do
			local a = if c % 2 == 0 then -1 else 1
			local b = if c < 2 then -1 else 1
			local sx, sy, sz = x + a * e1x + b * e2x, y + a * e1y + b * e2y, z + a * e1z + b * e2z
			local tx, ty, tz = sx + delta * nx, sy + delta * ny, sz + delta * nz
			local hc = false
			for m = 1, nn do
				if hides(near[m], p.index, sx, sy, sz, tx, ty, tz) then
					hc = true
					break
				end
			end
			if hc ~= hiddenNear then
				uniform = false
				break
			end
		end
		tick(4 * nn)
		if uniform then
			return if hiddenNear then 0 else w
		end
		subLeft -= 16 * nn
		subCount += 1
		local hidden = 0
		for i = 0, 3 do
			local a = (2 * i + 1) / 4 - 1
			for j = 0, 3 do
				local b = (2 * j + 1) / 4 - 1
				local sx, sy, sz = x + a * e1x + b * e2x, y + a * e1y + b * e2y, z + a * e1z + b * e2z
				local tx, ty, tz = sx + delta * nx, sy + delta * ny, sz + delta * nz
				for m = 1, nn do
					if hides(near[m], p.index, sx, sy, sz, tx, ty, tz) then
						hidden += 1
						break
					end
				end
			end
		end
		tick(16 * nn)
		return w * (16 - hidden) / 16
	end
	local SS = {}
	for _, p in ipairs(parts) do
		local S = Shapes.surfaceSamples(p, hSurf, CFG.NS_MAX, tick)
		SS[p.index] = S
		surfSamples += S.n
		local cand = {}
		for _, q in ipairs(parts) do
			if q ~= p and Shapes.aabbOverlap(p, q, delta + tol + hSurf) then
				table.insert(cand, q)
			end
		end
		p.cand = cand
		cp = contact[p.index]
		local exposed = 0
		for k = 1, S.n do
			exposed += exposedWeight(p, S, k, cand, true)
			tick(#cand + 1)
		end
		p.exposedArea = exposed
		p.exposedFrac = exposed / p.area
	end
	R.surfSamples = surfSamples
	local kept = table.create(N, false)
	local cleaned = {}
	for _, p in ipairs(parts) do
		local dust = p.volume < CFG.MIN_PART_VOLUME
		local enclosed = p.exposedFrac < CFG.ENCLOSED_EXPOSED_MAX
		kept[p.index] = not dust and not enclosed
		if not kept[p.index] then
			table.insert(cleaned, { partId = p.id, reason = if dust then "Dust" else "Enclosed" })
		end
		p.sig = min(1, p.volume / CFG.V_PART_FULL)
	end
	-- pass 2: a kept part next to a cleaned part is re-measured against kept parts only (own sub-sampling budget,
	-- so cleaned parts cannot change a kept part's verdicts by using up pass 1's budget)
	subLeft = CFG.N_SUB_WORK
	for _, p in ipairs(parts) do
		p.exposedKept = p.exposedArea
		if kept[p.index] then
			local keptCand, anyCleaned = {}, false
			for _, q in ipairs(p.cand) do
				if kept[q.index] then
					table.insert(keptCand, q)
				else
					anyCleaned = true
				end
			end
			if anyCleaned then
				local S = SS[p.index]
				local exposed = 0
				for k = 1, S.n do
					exposed += exposedWeight(p, S, k, keptCand, false)
					tick(#keptCand + 1)
				end
				p.exposedKept = exposed
			end
		end
	end
	R.subSampled = subCount
	local bparts
	if o.build then
		bparts = {}
		for i, raw in ipairs(core.parts) do
			bparts[i] = BShapes.prepare(raw, i)
		end
		local ex = BSampling.exposure(bparts)
		R.buildExposure = ex
		R.hSurf, R.hKept = ex.hSurf, ex.hSurf
		cleaned = ex.cleaned
		for i = 1, N do
			kept[i] = ex.kept[i]
			contact[i] = ex.contact[i]
			parts[i].exposedKept = ex.exposedKept[i]
			parts[i].exposedArea = ex.exposedKept[i]
		end
		for _, f in ipairs(o.forceClean or {}) do
			kept[f] = false
		end
	end
	-- required slots need a kept part
	for _, s in ipairs(CFG.SLOTS) do
		if s.required then
			local any = false
			for _, p in ipairs(parts) do
				if p.slot == s.id and kept[p.index] then
					any = true
					break
				end
			end
			if not any then
				table.insert(verrs, { code = "SlotMissing", slot = s.id, reason = "Cleaned" })
			end
		end
	end
	R.cleaned = cleaned
	R.validation = { ok = #verrs == 0, errors = verrs, quick = false, components = components }
	R.valid = #verrs == 0
	T.surface = clock() - t
	if not R.valid and not o.measureInvalid then
		T.total = clock() - tStart
		R.T = T
		return R
	end
	t = clock()
	phase()

	-- ======== 4. owned volumes (exact polyhedron overlaps, refined sampling otherwise), mass, probes
	local rankOf = {}
	for _, s in ipairs(CFG.SLOTS) do
		rankOf[s.id] = s.rank
	end
	local order = {}
	for _, p in ipairs(parts) do
		table.insert(order, p)
	end
	table.sort(order, function(a, b)
		local ka, kb = if kept[a.index] then 0 else 1, if kept[b.index] then 0 else 1
		if ka ~= kb then
			return ka < kb
		end
		local ra, rb = rankOf[a.slot], rankOf[b.slot]
		if ra ~= rb then
			return ra < rb
		end
		return a.index < b.index
	end)
	local jobs = {}
	local refineEst = 0
	for r, p in ipairs(order) do
		p.prio = r
		local H = {}
		for r2 = 1, r - 1 do
			local q = order[r2]
			if Shapes.aabbOverlap(p, q, 0) then
				tick(20)
				if Gjk.within(p, q, 1e-9) then
					table.insert(H, q)
				end
			end
		end
		p.higher = H
		if #H > 0 then
			local allPoly = p.poly
			for _, q in ipairs(H) do
				allPoly = allPoly and q.poly
			end
			if allPoly and #H <= Overlap.MAX_EXACT then
				table.insert(jobs, { p = p, H = H, exact = true })
			else
				local lo, hi = Overlap.boxOf(p, H)
				local nx, ny, nz = Overlap.cellsFor(lo, hi, CFG.H_OVERLAP, CFG.OVERLAP_N_MIN, CFG.OVERLAP_N_MAX)
				refineEst += nx * ny * nz
				table.insert(jobs, { p = p, H = H, exact = false, lo = lo, hi = hi })
			end
		end
	end
	local hOv = CFG.H_OVERLAP
	for _, k in ipairs(CFG.H_LADDER) do
		hOv = CFG.H_OVERLAP * k
		local est = 0
		for _, jb in ipairs(jobs) do
			if not jb.exact then
				local nx, ny, nz = Overlap.cellsFor(jb.lo, jb.hi, hOv, CFG.OVERLAP_N_MIN, CFG.OVERLAP_N_MAX)
				est += nx * ny * nz * (1 + #jb.H)
			end
		end
		if est <= CFG.N_OVERLAP_WORK then
			break
		end
	end
	R.hOverlap = hOv
	local refinedCells = 0
	for _, p in ipairs(parts) do
		p.ovV, p.ovX, p.ovY, p.ovZ = 0, 0, 0, 0
	end
	for _, jb in ipairs(jobs) do
		local V, X, Y, Z
		if jb.exact then
			V, X, Y, Z = Overlap.exact(jb.p, jb.H, tick)
		else
			local nx, ny, nz = Overlap.cellsFor(jb.lo, jb.hi, hOv, CFG.OVERLAP_N_MIN, CFG.OVERLAP_N_MAX)
			refinedCells += nx * ny * nz
			V, X, Y, Z = Overlap.sampled(jb.p, jb.H, jb.lo, jb.hi, nx, ny, nz, tick)
		end
		local p = jb.p
		V = min(V, p.volume)
		p.ovV, p.ovX, p.ovY, p.ovZ = V, X, Y, Z
	end
	R.refinedCells = refinedCells
	local U, M, Mx, My, Mz = 0, 0, 0, 0, 0
	local ownedVolume = table.create(N, 0)
	for _, p in ipairs(parts) do
		p.ownV = p.volume - p.ovV
		local rho = material(p.material).density
		p.rho = rho
		U += p.ownV
		M += rho * p.ownV
		Mx += rho * (p.volume * p.gx - p.ovX)
		My += rho * (p.volume * p.gy - p.ovY)
		Mz += rho * (p.volume * p.gz - p.ovZ)
		ownedVolume[p.index] = p.ownV
	end
	if o.build then
		local own = BMass.ownership(bparts, kept, rankOf)
		R.buildOwned = own
		for _, p in ipairs(parts) do
			p.ownV = own.ownedVolume[p.index]
			local H = {}
			for _, q in ipairs(own.higher[p.index]) do
				table.insert(H, parts[q.index])
			end
			p.higher = H
		end
	end
	local com = { Mx / M, My / M, Mz / M }
	-- volume samples (probes for Thinness), owned = not strictly inside a higher-priority overlapping part
	local volSamples = 0
	local hVol = CFG.H_VOL
	for _, k in ipairs(CFG.H_LADDER) do
		hVol = CFG.H_VOL * k
		local est = 0
		for _, p in ipairs(parts) do
			if kept[p.index] then
				local a = max(CFG.N_MIN_AXIS, min(CFG.N_MAX_AXIS, ceil(2 * p.hx / hVol)))
				local b = max(CFG.N_MIN_AXIS, min(CFG.N_MAX_AXIS, ceil(2 * p.hy / hVol)))
				local c = max(CFG.N_MIN_AXIS, min(CFG.N_MAX_AXIS, ceil(2 * p.hz / hVol)))
				est += min(a * b * c, CFG.N_MAX_PART)
			end
		end
		if est <= CFG.N_VOL_TOTAL then
			break
		end
	end
	R.hVol = hVol
	for _, p in ipairs(parts) do
		p.vxs, p.vys, p.vzs, p.vw, p.own = {}, {}, {}, 0, {}
		if kept[p.index] then
			local xs, ys, zs, w = Shapes.volumeSamples(p, hVol, CFG.N_MIN_AXIS, CFG.N_MAX_AXIS, CFG.N_MAX_PART, nil, nil, nil, tick)
			volSamples += #xs
			p.vxs, p.vys, p.vzs, p.vw, p.own = xs, ys, zs, w, {} -- ownership is tested only for probes (ownedAt)
		end
	end
	R.volSamples = volSamples
	local function ownedAt(p: any, k: number): boolean
		local o = p.own[k]
		if o == nil then
			o = true
			local x, y, z = p.vxs[k], p.vys[k], p.vzs[k]
			for _, q in ipairs(p.higher) do
				if Shapes.aabbContains(q, x, y, z, 0) and Shapes.sd(q, x, y, z) < -1e-9 then
					o = false
					break
				end
			end
			p.own[k] = o
		end
		return o :: boolean
	end
	-- guard line, balance, reach (physics frame); reach and blade length over kept Blade parts
	local guV, guA = 0, 0
	local gripTop = -math.huge
	local gA = grip[1] * axis[1] + grip[2] * axis[2]
	for _, p in ipairs(parts) do
		if p.slot == CFG.GUARD_SLOT then
			guV += p.volume
			guA += p.volume * ((p.gx - grip[1]) * axis[1] + (p.gy - grip[2]) * axis[2])
		elseif p.slot == CFG.GRIP_SLOT then
			local _, hi = Shapes.extentAlong(p, axis[1], axis[2], 0)
			gripTop = max(gripTop, hi - gA)
		end
	end
	local guardPos = if guV > 0 then guA / guV else gripTop
	local reach, bladeTop = 0, -math.huge
	local lo0, hi0 = math.huge, -math.huge
	for _, p in ipairs(parts) do
		local lo, hi = Shapes.extentAlong(p, axis[1], axis[2], 0)
		lo0, hi0 = min(lo0, lo), max(hi0, hi)
		if p.slot == CFG.STRIKING_SLOT and kept[p.index] then
			reach = max(reach, Shapes.maxDist(p, grip[1], grip[2], grip[3]))
			bladeTop = max(bladeTop, hi - gA)
		end
	end
	local comA = (com[1] - grip[1]) * axis[1] + (com[2] - grip[2]) * axis[2]
	local keptFlags = table.create(N, false)
	for i = 1, N do
		keptFlags[i] = kept[i]
	end
	R.physics = {
		mass = M,
		volume = U,
		com = com,
		gripPoint = grip,
		gripAxis = axis,
		guardPos = guardPos,
		balance = comA - guardPos,
		balanceFromHand = comA,
		reach = reach,
		bladeLength = bladeTop - guardPos,
		totalLength = hi0 - lo0,
		comOffAxis = (com[1] - grip[1]) * axis[2] - (com[2] - grip[2]) * axis[1],
		kept = keptFlags,
		ownedVolume = ownedVolume,
	}
	T.mass = clock() - t
	t = clock()
	phase()

	if o.mark then o.mark() end -- m3-plan-r2: M3's phases start here (gap timing)
	-- ======== 5. difficulty frame (kept Grip parts) and edge
	local gripKept = {}
	for _, p in ipairs(gripAll) do
		if kept[p.index] then
			table.insert(gripKept, p)
		end
	end
	local dgrip, daxis = gripFrame(gripKept)
	if CFG.DIFF_FRAME == "Fixed" then
		daxis = { 0, 1 }
	end
	R.frame = { gripPoint = dgrip, gripAxis = daxis }
	R.edge = edgeProfile(parts, kept, daxis, tick)
	R.edge.gripPoint, R.edge.gripAxis = dgrip, daxis
	do
		local e = R.edge
		local bl = max(R.physics.bladeLength, 1e-6)
		e.cutIndex = if e.bladeMeanThickness > 0 then Num.norm(bl / e.bladeMeanThickness, CFG.CUT_LO, CFG.CUT_HI) else 0
	end
	R.physics.edgeLength = R.edge.length
	T.edge = clock() - t
	t = clock()
	phase()

	-- ======== 6. factors per work set, steps
	local cache = {}
	local function workSet(sel: any): { any }
		local W = {}
		for _, p in ipairs(parts) do
			if kept[p.index] then
				local inSet = sel == "All"
				if not inSet then
					for _, s in ipairs(sel) do
						if p.slot == s then
							inSet = true
						end
					end
				end
				if inSet then
					table.insert(W, p)
				end
			end
		end
		return W
	end
	local function setFactors(W: { any }): any
		local raw, x = {}, {}
		local inW = {}
		for _, p in ipairs(W) do
			inW[p.index] = true
		end
		-- Volume, PartCount, MaterialMix
		local V, nEff = 0, 0
		local mats, nm = {}, 0
		for _, p in ipairs(W) do
			V += p.ownV
			nEff += p.sig
			if not mats[p.material] then
				mats[p.material] = true
				nm += 1
			end
		end
		raw.Volume, raw.PartCount, raw.MaterialMix = V, nEff, nm
		-- SurfaceComplexity (pass-2 exposure over owned volume)
		local A = 0
		for _, p in ipairs(W) do
			A += p.exposedKept
		end
		local cV = Num.cbrt(V)
		raw.SurfaceComplexity = if V > 0 then A / (6 * cV * cV) else 0
		-- EdgeLength: main chain
		raw.EdgeLength = R.edge.length
		-- Joints
		local J = 0
		for i = 1, #W - 1 do
			for j = i + 1, #W do
				local p, q = W[i], W[j]
				if conn[p.index][q.index] then
					local a = (contact[p.index][q.index] + contact[q.index][p.index]) / 2
					J += min(p.sig, q.sig) * (1 + CFG.JOINT_BOOST * Num.clamp01(1 - a / CFG.A_JOINT_REF))
				end
			end
		end
		raw.Joints = J
		-- Thinness
		do
			local lo, hi = math.huge, -math.huge
			local nW = 0
			for _, p in ipairs(W) do
				local a, b = Shapes.extentAlong(p, daxis[1], daxis[2], 0)
				lo, hi = min(lo, a), max(hi, b)
				nW += #p.vxs
			end
			local L = hi - lo
			local stride = max(1, ceil(nW / CFG.THICK_BUDGET))
			local sw, sw1, sw2, swThin, swStrike = 0, 0, 0, 0, 0
			local idx = 0
			for _, p in ipairs(W) do
				-- thinnest local axis of the owner
				local tx, ty, tz
				if p.code == Shapes.BALL then
					tx, ty, tz = p.ux, p.uy, p.uz
				elseif p.code == Shapes.CYL then
					if p.hx <= p.r then
						tx, ty, tz = p.ux, p.uy, p.uz
					else
						tx, ty, tz = p.vx, p.vy, p.vz -- radial = local Y
					end
				elseif p.hx <= p.hy and p.hx <= p.hz then
					tx, ty, tz = p.ux, p.uy, p.uz
				elseif p.hy <= p.hz then
					tx, ty, tz = p.vx, p.vy, p.vz
				else
					tx, ty, tz = p.wx, p.wy, p.wz
				end
				for k = 1, #p.vxs do
					idx += 1
					if (idx - 1) % stride == 0 then
						if ownedAt(p, k) then
							local px, py, pz = p.vxs[k], p.vys[k], p.vzs[k]
							if p.code == Shapes.BALL then
								px, py, pz = p.cx, p.cy, p.cz
							elseif p.code == Shapes.CYL then
								local s = (px - p.cx) * p.ux + (py - p.cy) * p.uy + (pz - p.cz) * p.uz
								px, py, pz = p.cx + s * p.ux, p.cy + s * p.uy, p.cz + s * p.uz
							end
							local tau = unionChordAt(W, px, py, pz, 0, 0, 1, tol)
							tau = min(tau, unionChordAt(W, px, py, pz, tx, ty, tz, tol))
							tick(2 * #W)
							local phi = Num.norm(L / max(tau, 1e-6), CFG.SIGMA_LO, CFG.SIGMA_HI)
							local w = p.vw
							sw += w
							sw1 += w * phi
							sw2 += w * phi * phi
							if phi > 0 then
								swThin += w
							end
							if p.slot == CFG.STRIKING_SLOT then
								swStrike += w
							end
						end
					end
				end
			end
			local self = if sw1 > 0 then sw2 / sw1 else 0
			-- thin share relative to the striking-slot metal of the set (the whole set if it has none)
			local ref = if CFG.THIN_REF == "Striking" and swStrike > 0 then swStrike else sw
			raw.Thinness = self * min(1, if ref > 0 then swThin / (CFG.THIN_SHARE_MIN * ref) else 0)
			raw.ThinL = L
		end
		-- Asymmetry: fixed plane x = 0, dedicated probes, soft coverage
		do
			local hA = CFG.H_VOL
			-- at least ASYM_N_MIN probes along every local axis that runs across the mirror plane (|axis.x| >= ASYM_AXIS_X)
			local function axisMins(p: any): (number, number, number)
				local c = CFG.ASYM_AXIS_X
				local mx = if abs(p.ux) >= c then CFG.ASYM_N_MIN else CFG.N_MIN_AXIS
				local my = if abs(p.vx) >= c then CFG.ASYM_N_MIN else CFG.N_MIN_AXIS
				local mz = if abs(p.wx) >= c then CFG.ASYM_N_MIN else CFG.N_MIN_AXIS
				return mx, my, mz
			end
			local reachA = CFG.ASYM_TOL + CFG.ASYM_RAMP
			-- mirror candidates of p: parts of W whose AABB meets p's mirrored AABB (+ reachA); higher parts of W
			local mcand, hcand = {}, {}
			for _, p in ipairs(W) do
				local mc, hc = {}, {}
				for _, q in ipairs(W) do
					if q.maxx >= -p.maxx - reachA and q.minx <= -p.minx + reachA and q.maxy >= p.miny - reachA and q.miny <= p.maxy + reachA
						and q.maxz >= p.minz - reachA and q.minz <= p.maxz + reachA then
						table.insert(mc, q)
					end
				end
				for _, q in ipairs(p.higher) do
					if inW[q.index] then
						table.insert(hc, q)
					end
				end
				mcand[p.index], hcand[p.index] = mc, hc
			end
			for _, k in ipairs(CFG.H_LADDER) do
				hA = CFG.H_VOL * k
				local est = 0
				for _, p in ipairs(W) do
					local mx, my, mz = axisMins(p)
					local a = max(mx, min(CFG.N_MAX_AXIS, ceil(2 * p.hx / hA)))
					local b = max(my, min(CFG.N_MAX_AXIS, ceil(2 * p.hy / hA)))
					local c = max(mz, min(CFG.N_MAX_AXIS, ceil(2 * p.hz / hA)))
					est += min(a * b * c, CFG.N_MAX_PART) * (1 + #mcand[p.index] + #hcand[p.index])
				end
				if est <= CFG.ASYM_WORK then
					break
				end
			end
			local tot, cov = 0, 0
			for _, p in ipairs(W) do
				local mx, my, mz = axisMins(p)
				local xs, ys, zs, w = Shapes.volumeSamples(p, hA, CFG.N_MIN_AXIS, CFG.N_MAX_AXIS, CFG.N_MAX_PART, mx, my, mz, tick)
				local higher, mc = hcand[p.index], mcand[p.index]
				for k = 1, #xs do
					local x, y, z = xs[k], ys[k], zs[k]
					local owned = true
					for _, q in ipairs(higher) do
						if Shapes.aabbContains(q, x, y, z, 0) and Shapes.sd(q, x, y, z) < -1e-9 then
							owned = false
							break
						end
					end
					if owned then
						tot += w
						local mxp = -x
						local d = math.huge
						for _, q in ipairs(mc) do
							if Shapes.aabbContains(q, mxp, y, z, reachA) then
								local s = Shapes.sd(q, mxp, y, z)
								if s < d then
									d = s
									if d <= CFG.ASYM_TOL then
										break
									end
								end
							end
						end
						cov += w * Num.clamp01((reachA - d) / CFG.ASYM_RAMP)
					end
					tick(1 + #mc + #higher)
				end
			end
			raw.Asymmetry = if tot > 0 then 1 - cov / tot else 0
		end
		for _, f in ipairs(FACTORS) do
			if f == "Thinness" then
				x[f] = raw[f]
			else
				local ref = CFG.REF[f]
				x[f] = Num.norm(raw[f], ref[1], ref[2])
			end
		end
		return { raw = raw, x = x }
	end
	local function keyOf(sel: any): string
		if sel == "All" then
			return "All"
		end
		return table.concat(sel, "+")
	end
	R.steps = {}
	R.sets = {}
	for _, st in ipairs(CFG.STEPS) do
		local key = keyOf(st.worksOn)
		local W = workSet(st.worksOn)
		local F = cache[key]
		if F == nil then
			F = setFactors(W)
			cache[key] = F
			R.sets[key] = F
		end
		local g = 0
		local terms = {}
		for _, fw in ipairs(st.w) do
			g += fw[2] * F.x[fw[1]]
			table.insert(terms, { factor = fw[1], w = fw[2], x = F.x[fw[1]] })
		end
		g = Num.q4(g)
		-- governing material: highest (difficultyTerm, hardness), ties by Materials order
		local gov = nil
		for _, mdef in ipairs(CFG.MATERIALS) do
			local present = false
			for _, p in ipairs(W) do
				if p.material == mdef.id then
					present = true
					break
				end
			end
			if present and (gov == nil or mdef.difficultyTerm > gov.difficultyTerm or (mdef.difficultyTerm == gov.difficultyTerm and mdef.hardness > gov.hardness)) then
				gov = mdef
			end
		end
		local m = Num.q4(if gov then gov.difficultyTerm else 0)
		local d = Num.q4(1 - (1 - m) * (1 - g))
		local tierRaw, tier = CFG.TIERS[1].id, CFG.TIERS[1].id
		for _, td in ipairs(CFG.TIERS) do
			if d >= td.dMin then
				tierRaw = td.id
				if td.enabled then
					tier = td.id
				end
			end
		end
		local factors = {}
		for _, f in ipairs(FACTORS) do
			table.insert(factors, { factor = f, raw = F.raw[f], x = F.x[f] })
		end
		table.insert(R.steps, {
			step = st.step, g = g, m = m, d = d, tierRaw = tierRaw, tier = tier,
			material = if gov then gov.id else nil, terms = terms, factors = factors,
		})
	end
	T.factors = clock() - t
	T.total = clock() - tStart
	R.T = T
	return R
end

return Analyze
