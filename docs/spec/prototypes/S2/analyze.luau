--!strict
-- S2 prototype: full analysis pipeline (validate -> clean -> mass properties -> factors -> difficulty).
local Num = require("./num")
local Shapes = require("./shapes")
local Gjk = require("./gjk")

local sqrt, max, min, floor = math.sqrt, math.max, math.min, math.floor
local clock = os.clock

local Analyze = {}

local CFG = {
	HITBOX_MIN = { -0.8, 0.0, -0.3 },
	HITBOX_MAX = { 0.8, 5.0, 0.3 },
	EPS_CONTAIN = 1e-4,
	CONTACT_TOL = 0.01, -- connectivity + joint contact areas + chord merging
	HIDE_TOL = 0.002, -- surface exposure
	SLOTS = {
		{ id = "Blade", min = 1, max = 12, rank = 1 },
		{ id = "Guard", min = 0, max = 8, rank = 2 },
		{ id = "Grip", min = 1, max = 6, rank = 3 },
		{ id = "Pommel", min = 0, max = 4, rank = 4 },
	},
	PARTS_MIN = 2,
	PARTS_MAX = 24,
	-- sampling
	H_VOL = 0.05,
	N_MIN_AXIS = 2,
	N_MAX_AXIS = 48,
	N_MAX_PART = 3000,
	H_SURF = 0.04,
	NS_MAX = 64,
	N_VOL_TOTAL = 12000, -- global budgets: spacing coarsened along a fixed ladder until the estimate fits
	N_SURF_TOTAL = 8000,
	H_LADDER = { 1, 1.25, 1.5, 2, 2.5, 3, 4, 5, 6, 8 },
	ASYM_BUDGET = 4000,
	-- cleaning
	MIN_PART_VOLUME = 0.0002,
	ENCLOSED_EXPOSED_MAX = 0.02,
	V_PART_FULL = 0.004,
	-- thickness
	THICK_BUDGET = 400,
	SIGMA_LO = 40,
	SIGMA_HI = 130,
	-- asymmetry
	ASYM_TOL = 0.02,
	ASYM_MAX_AXIS_TILT_COS = 0.7071, -- grip axis more than 45deg off +Y -> use +Y
	-- edge
	EDGE_CELL = 0.02,
	EDGE_MAX_THICK = 0.25,
	EDGE_DOWN_COS = 0.5,
	EDGE_SIMPLIFY = 1.0, -- x cell
	EDGE_GAP_BRIDGE = 3.0, -- x cell
	EDGE_MIN_CHAIN = 3.0, -- x cell
	EDGE_MAX_CELLS = 12000,
	-- joints
	JOINT_BOOST = 1.0,
	A_JOINT_REF = 0.05,
	-- reference ranges [lo, hi]
	REF = {
		Volume = { 0.08, 0.80 },
		PartCount = { 3, 16 },
		Asymmetry = { 0.0, 0.6 },
		SurfaceComplexity = { 2.1, 2.9 },
		EdgeLength = { 4.0, 10.0 },
		Joints = { 3, 24 },
		MaterialMix = { 1, 4 },
	},
	DENSITY = { Iron = 7.87, Steel = 7.85 },
	MAT_DIFF = { Iron = 0.0, Steel = 0.10 },
	STEPS = {
		{ id = "Smelting", set = "All", w = { { "Volume", 1.0 } } },
		{ id = "Hammering", set = "All", w = { { "Thinness", 0.40 }, { "Asymmetry", 0.30 }, { "SurfaceComplexity", 0.30 } } },
		{ id = "Sharpening", set = "Blade", w = { { "EdgeLength", 0.50 }, { "SurfaceComplexity", 0.20 }, { "Asymmetry", 0.30 } } },
		-- Phase 2 hooks (not played in the MVP; computed for calibration only)
		{ id = "Quenching", set = "All", w = { { "Thinness", 0.60 }, { "PartCount", 0.40 } }, phase2 = true },
		{ id = "Assembly", set = "All", w = { { "PartCount", 0.35 }, { "Joints", 0.45 }, { "MaterialMix", 0.20 } }, phase2 = true },
		{ id = "Finishing", set = "All", w = { { "SurfaceComplexity", 1.0 } }, phase2 = true },
	},
	TIERS = { { "Normal", 0.0 }, { "Hard", 0.2 }, { "Expert", 0.4 }, { "Master", 0.6 }, { "Hell", 0.8 } },
	MAX_TIER = 2, -- MVP clamp: Hard
}
Analyze.CFG = CFG

local SLOT_RANK = {}
for _, s in ipairs(CFG.SLOTS) do
	SLOT_RANK[s.id] = s.rank
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

local function lineHitsAabb(q: any, ox: number, oy: number, oz: number, ux: number, uy: number, uz: number): boolean
	local t0, t1 = -math.huge, math.huge
	if ux == 0 then
		if ox < q.minx or ox > q.maxx then
			return false
		end
	else
		local a, b = (q.minx - ox) / ux, (q.maxx - ox) / ux
		if a > b then
			a, b = b, a
		end
		t0, t1 = max(t0, a), min(t1, b)
	end
	if uy == 0 then
		if oy < q.miny or oy > q.maxy then
			return false
		end
	else
		local a, b = (q.miny - oy) / uy, (q.maxy - oy) / uy
		if a > b then
			a, b = b, a
		end
		t0, t1 = max(t0, a), min(t1, b)
	end
	if uz == 0 then
		if oz < q.minz or oz > q.maxz then
			return false
		end
	else
		local a, b = (q.minz - oz) / uz, (q.maxz - oz) / uz
		if a > b then
			a, b = b, a
		end
		t0, t1 = max(t0, a), min(t1, b)
	end
	return t0 <= t1
end

-- length of the merged union chord through point o (o is inside some part of list)
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

-- ---------------------------------------------------------------- edge profile
local function edgeProfile(parts: { any }, kept: { boolean }, gpx: number, gpy: number): any
	local H = CFG.EDGE_CELL
	local blade, hilt = {}, {}
	for _, p in ipairs(parts) do
		if p.slot == "Blade" then
			if kept[p.index] then
				table.insert(blade, p)
			end
		else
			table.insert(hilt, p)
		end
	end
	local res = { chains = {}, length = 0, cells = 0, loops = 0 }
	if #blade == 0 then
		return res
	end
	local mnx, mxx, mny, mxy = math.huge, -math.huge, math.huge, -math.huge
	for _, b in ipairs(blade) do
		mnx, mxx, mny, mxy = min(mnx, b.minx), max(mxx, b.maxx), min(mny, b.miny), max(mxy, b.maxy)
	end
	local i0, i1, j0, j1, NI, NJ
	for _, k in ipairs(CFG.H_LADDER) do
		H = CFG.EDGE_CELL * k
		i0 = floor((mnx - gpx) / H) - 1
		i1 = floor((mxx - gpx) / H) + 1
		j0 = floor((mny - gpy) / H) - 1
		j1 = floor((mxy - gpy) / H) + 1
		NI, NJ = i1 - i0 + 1, j1 - j0 + 1
		if NI * NJ <= CFG.EDGE_MAX_CELLS then
			break
		end
	end
	res.cells, res.cell = NI * NJ, H
	local cov = table.create(NI * NJ, false)
	local thick = table.create(NI * NJ, 0)
	local hil = table.create(NI * NJ, false)
	local ivs = {}
	local covered, thickSum = 0, 0
	for jj = 0, NJ - 1 do
		local y = gpy + (j0 + jj + 0.5) * H
		for ii = 0, NI - 1 do
			local x = gpx + (i0 + ii + 0.5) * H
			local idx = jj * NI + ii + 1
			local n = 0
			for _, b in ipairs(blade) do
				if x >= b.minx and x <= b.maxx and y >= b.miny and y <= b.maxy then
					local ok, t0, t1 = Shapes.chord(b, x, y, 0, 0, 0, 1)
					if ok and t1 > t0 then
						n += 1
						ivs[2 * n - 1], ivs[2 * n] = t0, t1
					end
				end
			end
			if n > 0 then
				cov[idx] = true
				thick[idx] = mergedLength(ivs, n, CFG.CONTACT_TOL)
				covered += 1
				thickSum += thick[idx]
			end
			for _, h in ipairs(hilt) do
				if x >= h.minx and x <= h.maxx and y >= h.miny and y <= h.maxy then
					local ok, t0, t1 = Shapes.chord(h, x, y, 0, 0, 0, 1)
					if ok and t1 >= t0 then
						hil[idx] = true
						break
					end
				end
			end
		end
	end
	res.bladeArea = covered * H * H
	res.bladeMeanThickness = if covered > 0 then thickSum / covered else 0 -- V/A on the same cells: aliasing cancels
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
		return gpx + (i0 + (v - 1) % VI) * H
	end
	local function vy(v)
		return gpy + (j0 + (v - 1) // VI) * H
	end
	local function emitRun(run: { number })
		-- midpoint polyline (marching-squares style), endpoints = run end vertices
		local xs, ys = { vx(eFrom[run[1]]) }, { vy(eFrom[run[1]]) }
		for _, ee in ipairs(run) do
			table.insert(xs, (vx(eFrom[ee]) + vx(eTo[ee])) / 2)
			table.insert(ys, (vy(eFrom[ee]) + vy(eTo[ee])) / 2)
		end
		table.insert(xs, vx(eTo[run[#run]]))
		table.insert(ys, vy(eTo[run[#run]]))
		local k = simplify(xs, ys, CFG.EDGE_SIMPLIFY * H)
		local m = #k - 1
		local segLen, sharp = table.create(m, 0), table.create(m, false)
		for s = 1, m do
			local dx, dy = xs[k[s + 1]] - xs[k[s]], ys[k[s + 1]] - ys[k[s]]
			local len = sqrt(dx * dx + dy * dy)
			segLen[s] = len
			sharp[s] = len > 0 and (-dx / len) >= -CFG.EDGE_DOWN_COS -- right-hand normal y component
		end
		-- bridge short non-sharpenable gaps between sharpenable segments
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
				res.length += clen
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
					local right = (eDir[e] + 3) % 4 -- saddle: right turn first = covered cells 8-connected
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
	return res
end

-- ---------------------------------------------------------------- main
function Analyze.run(bp: any, opts: any?): any
	local T = {}
	local tStart = clock()
	local t = tStart
	local tol = CFG.CONTACT_TOL
	local parts = {}
	for i, raw in ipairs(bp.parts) do
		parts[i] = Shapes.prepare(Shapes.sanitizePart(raw), i)
	end
	local N = #parts
	local R: any = { name = bp.name, errors = {}, parts = N }

	-- ======== 1. validation
	local hmin, hmax, e = CFG.HITBOX_MIN, CFG.HITBOX_MAX, CFG.EPS_CONTAIN
	for _, p in ipairs(parts) do
		if p.minx < hmin[1] - e or p.miny < hmin[2] - e or p.minz < hmin[3] - e or p.maxx > hmax[1] + e or p.maxy > hmax[2] + e or p.maxz > hmax[3] + e then
			table.insert(R.errors, "OUT_OF_HITBOX:" .. p.id)
		end
	end
	if N < CFG.PARTS_MIN or N > CFG.PARTS_MAX then
		table.insert(R.errors, "PART_COUNT")
	end
	for _, s in ipairs(CFG.SLOTS) do
		local c = 0
		for _, p in ipairs(parts) do
			if p.slot == s.id then
				c += 1
			end
		end
		if c < s.min then
			table.insert(R.errors, "SLOT_MISSING:" .. s.id)
		elseif c > s.max then
			table.insert(R.errors, "SLOT_TOO_MANY:" .. s.id)
		end
	end
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
	local gjkCalls, gjkIters = 0, 0
	for i = 1, N - 1 do
		local A = parts[i]
		for j = i + 1, N do
			local B = parts[j]
			if A.minx <= B.maxx + tol and B.minx <= A.maxx + tol and A.miny <= B.maxy + tol and B.miny <= A.maxy + tol and A.minz <= B.maxz + tol and B.minz <= A.maxz + tol then
				gjkCalls += 1
				local ok, _, it = Gjk.within(A, B, tol)
				gjkIters += it
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
			end
		end
	end
	-- main component = largest total volume (tie: lowest root index)
	local compV = {}
	for i = 1, N do
		local r = find(i)
		compV[r] = (compV[r] or 0) + parts[i].volume
	end
	local mainRoot, mainV = 1, -1
	for i = 1, N do
		if find(i) == i and compV[i] > mainV then
			mainRoot, mainV = i, compV[i]
		end
	end
	for i = 1, N do
		if find(i) ~= mainRoot then
			table.insert(R.errors, "DISCONNECTED:" .. parts[i].id)
		end
	end
	R.gjkCalls, R.gjkIters = gjkCalls, gjkIters
	-- grip point, grip axis, blade orientation
	local gV, gX, gY, gZ = 0, 0, 0, 0
	local axX, axY = 0, 0
	local bV, bY = 0, 0
	for _, p in ipairs(parts) do
		if p.slot == "Grip" then
			gV += p.volume
			gX += p.volume * p.gx
			gY += p.volume * p.gy
			gZ += p.volume * p.gz
			-- axis contribution: cylinders always (coaxial rings/wraps), polyhedra only if elongated
			-- (longest >= 1.5 x middle), balls never; dust (< MIN_PART_VOLUME) never
			local ex, ey = nil, nil
			if p.volume >= CFG.MIN_PART_VOLUME then
				if p.code == Shapes.CYL then
					ex, ey = p.ux, p.uy
				elseif p.code ~= Shapes.BALL then
					local h = { { p.hx, p.ux, p.uy }, { p.hy, p.vx, p.vy }, { p.hz, p.wx, p.wy } }
					table.sort(h, function(a, b)
						return a[1] > b[1]
					end)
					if h[1][1] >= 1.5 * h[2][1] then
						ex, ey = h[1][2], h[1][3]
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
		elseif p.slot == "Blade" then
			bV += p.volume
			bY += p.volume * p.gy
		end
	end
	local grip = { 0, 0, 0 }
	if gV > 0 then
		grip = { gX / gV, gY / gV, gZ / gV }
	end
	local an = sqrt(axX * axX + axY * axY)
	local axis = { 0, 1 }
	if an > 1e-9 and axY / an >= CFG.ASYM_MAX_AXIS_TILT_COS then
		axis = { axX / an, axY / an }
	end
	if bV > 0 and gV > 0 and bY / bV <= grip[2] then
		table.insert(R.errors, "BLADE_NOT_ABOVE_GRIP")
	end
	R.grip, R.axis = grip, axis
	T.validate = clock() - t
	t = clock()

	-- ======== 2. surface exposure, contact areas
	local contact = {}
	for i = 1, N do
		contact[i] = table.create(N, 0)
	end
	local surfSamples = 0
	local htol = CFG.HIDE_TOL
	local hSurf = CFG.H_SURF
	for _, k in ipairs(CFG.H_LADDER) do
		hSurf = CFG.H_SURF * k
		local est = 0
		for _, p in ipairs(parts) do
			local a = max(1, min(CFG.NS_MAX, math.ceil(2 * p.hx / hSurf)))
			local b = max(1, min(CFG.NS_MAX, math.ceil(2 * p.hy / hSurf)))
			local c = max(1, min(CFG.NS_MAX, math.ceil(2 * p.hz / hSurf)))
			est += 2 * (a * b + b * c + a * c)
		end
		if est <= CFG.N_SURF_TOTAL then
			break
		end
	end
	R.hSurf = hSurf
	for _, p in ipairs(parts) do
		local S = Shapes.surfaceSamples(p, hSurf, CFG.NS_MAX)
		surfSamples += S.n
		local cand = {}
		for _, q in ipairs(parts) do
			if q ~= p and q.minx <= p.maxx + tol and p.minx <= q.maxx + tol and q.miny <= p.maxy + tol and p.miny <= q.maxy + tol and q.minz <= p.maxz + tol and p.minz <= q.maxz + tol then
				table.insert(cand, q)
			end
		end
		local exposed = 0
		local cp = contact[p.index]
		local delta = 2 * htol
		for k = 1, S.n do
			local x, y, z, w = S.x[k], S.y[k], S.z[k], S.w[k]
			local ox, oy, oz = x + delta * S.nx[k], y + delta * S.ny[k], z + delta * S.nz[k]
			local hidden = false
			for _, q in ipairs(cand) do
				if Shapes.aabbContains(q, x, y, z, tol) then
					local d = Shapes.sd(q, x, y, z)
					if d <= tol then
						cp[q.index] += w
					end
					if not hidden then
						if Shapes.sd(q, ox, oy, oz) <= 0 then
							hidden = true -- covered just outside the face: contact or penetration
						elseif q.index < p.index and d <= htol and d >= -htol then
							hidden = true -- coincident coplanar face: counted once, by the lowest index
						end
					end
				end
			end
			if not hidden then
				exposed += w
			end
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
			table.insert(cleaned, p.id .. (if dust then "(dust)" else "(enclosed)"))
		end
		p.sig = min(1, p.volume / CFG.V_PART_FULL)
		-- thinnest local axis (world direction) for the thickness probe
		if p.code == Shapes.BALL or (p.code == Shapes.CYL and p.hx <= p.r) then
			p.thinX, p.thinY, p.thinZ = p.ux, p.uy, p.uz
		elseif p.code == Shapes.CYL then
			p.thinX, p.thinY, p.thinZ = p.vx, p.vy, p.vz
		elseif p.hx <= p.hy and p.hx <= p.hz then
			p.thinX, p.thinY, p.thinZ = p.ux, p.uy, p.uz
		elseif p.hy <= p.hz then
			p.thinX, p.thinY, p.thinZ = p.vx, p.vy, p.vz
		else
			p.thinX, p.thinY, p.thinZ = p.wx, p.wy, p.wz
		end
	end
	R.cleaned = cleaned
	T.surface = clock() - t
	t = clock()

	-- ======== 3. volume samples, ownership, mass properties
	local order = {}
	for _, p in ipairs(parts) do
		table.insert(order, p)
	end
	table.sort(order, function(a, b)
		local ka, kb = if kept[a.index] then 0 else 1, if kept[b.index] then 0 else 1
		if ka ~= kb then
			return ka < kb
		end
		local ra, rb = SLOT_RANK[a.slot], SLOT_RANK[b.slot]
		if ra ~= rb then
			return ra < rb
		end
		return a.index < b.index
	end)
	local volSamples = 0
	local U, M, Mx, My, Mz = 0, 0, 0, 0, 0
	local hVol = CFG.H_VOL
	for _, k in ipairs(CFG.H_LADDER) do
		hVol = CFG.H_VOL * k
		local est = 0
		for _, p in ipairs(parts) do
			local a = max(CFG.N_MIN_AXIS, min(CFG.N_MAX_AXIS, math.ceil(2 * p.hx / hVol)))
			local b = max(CFG.N_MIN_AXIS, min(CFG.N_MAX_AXIS, math.ceil(2 * p.hy / hVol)))
			local c = max(CFG.N_MIN_AXIS, min(CFG.N_MAX_AXIS, math.ceil(2 * p.hz / hVol)))
			est += min(a * b * c, CFG.N_MAX_PART)
		end
		if est <= CFG.N_VOL_TOTAL then
			break
		end
	end
	R.hVol = hVol
	for r, p in ipairs(order) do
		local xs, ys, zs, w = Shapes.volumeSamples(p, hVol, CFG.N_MIN_AXIS, CFG.N_MAX_AXIS, CFG.N_MAX_PART)
		local n = #xs
		volSamples += n
		local own = table.create(n, true)
		local remN, remX, remY, remZ = 0, 0, 0, 0
		local higher = {}
		for r2 = 1, r - 1 do
			local q = order[r2]
			if q.minx <= p.maxx and p.minx <= q.maxx and q.miny <= p.maxy and p.miny <= q.maxy and q.minz <= p.maxz and p.minz <= q.maxz then
				table.insert(higher, q)
			end
		end
		if #higher > 0 then
			for k = 1, n do
				local x, y, z = xs[k], ys[k], zs[k]
				for _, q in ipairs(higher) do
					if Shapes.aabbContains(q, x, y, z, 0) and Shapes.sd(q, x, y, z) < 0 then
						own[k] = false
						remN += 1
						remX += x
						remY += y
						remZ += z
						break
					end
				end
			end
		end
		p.vxs, p.vys, p.vzs, p.vw, p.own = xs, ys, zs, w, own
		p.ownV = p.volume - remN * w
		local rho = CFG.DENSITY[p.material]
		p.rho = rho
		U += p.ownV
		M += rho * p.ownV
		Mx += rho * (p.volume * p.gx - remX * w)
		My += rho * (p.volume * p.gy - remY * w)
		Mz += rho * (p.volume * p.gz - remZ * w)
	end
	R.volSamples = volSamples
	local com = { Mx / M, My / M, Mz / M }
	local I = 0
	for _, p in ipairs(parts) do
		local acc = 0
		for k = 1, #p.vxs do
			if p.own[k] then
				local dx, dy = p.vxs[k] - grip[1], p.vys[k] - grip[2]
				acc += dx * dx + dy * dy
			end
		end
		I += p.rho * p.vw * acc
	end
	local guV, guY = 0, 0
	local gripTop = -math.huge
	for _, p in ipairs(parts) do
		if p.slot == "Guard" then
			guV += p.volume
			guY += p.volume * p.gy
		elseif p.slot == "Grip" then
			gripTop = max(gripTop, p.maxy)
		end
	end
	local guardY = if guV > 0 then guY / guV else gripTop
	local reach, bladeTop = 0, -math.huge
	local ymin, ymax = math.huge, -math.huge
	for _, p in ipairs(parts) do
		ymin, ymax = min(ymin, p.miny), max(ymax, p.maxy)
		if p.slot == "Blade" then
			reach = max(reach, Shapes.maxDist(p, grip[1], grip[2], grip[3]))
			bladeTop = max(bladeTop, p.maxy)
		end
	end
	R.mass = {
		volume = U,
		mass = M,
		com = com,
		guardY = guardY,
		balance = com[2] - guardY,
		balanceFromHand = com[2] - grip[2],
		reach = reach,
		bladeLength = bladeTop - guardY,
		totalLength = ymax - ymin,
		inertia = I,
	}
	T.mass = clock() - t
	t = clock()

	-- ======== 4. edge profile (blade)
	R.edge = edgeProfile(parts, kept, grip[1], grip[2])
	do
		local bl = max(R.mass.bladeLength, 1e-6)
		local e = R.edge
		e.bladeWidth = (e.bladeArea or 0) / bl
		e.cutIndex = if (e.bladeMeanThickness or 0) > 0 then Num.norm(bl / e.bladeMeanThickness, 10, 60) else 0
	end
	T.edge = clock() - t
	t = clock()

	-- ======== 5. factors (lazy, per working set)
	local sets = {}
	local function getSet(set: string): any
		if sets[set] then
			return sets[set]
		end
		local W, Wall = {}, {}
		for _, p in ipairs(parts) do
			if set == "All" or p.slot == set then
				table.insert(Wall, p)
				if kept[p.index] then
					table.insert(W, p)
				end
			end
		end
		local S = { W = W, Wall = Wall, raw = {}, x = {}, t = {} }
		local m = 0
		for _, p in ipairs(W) do
			m = max(m, CFG.MAT_DIFF[p.material])
		end
		S.m = m
		sets[set] = S
		return S
	end
	local nx, ny = axis[2], -axis[1] -- mirror plane normal (in XY), plane through grip point containing axis and Z
	local raw = {}
	function raw.Volume(S)
		local V = 0
		for _, p in ipairs(S.W) do
			V += p.ownV
		end
		return V
	end
	function raw.SurfaceComplexity(S)
		local V, A = 0, 0
		for _, p in ipairs(S.W) do
			V += p.ownV
			A += p.exposedArea
		end
		if V <= 0 then
			return 0
		end
		local c = Num.cbrt(V)
		S.exposed = A
		return A / (6 * c * c)
	end
	function raw.Asymmetry(S)
		local owned = 0
		for _, p in ipairs(S.W) do
			for k = 1, #p.vxs do
				if p.own[k] then
					owned += 1
				end
			end
		end
		local stride = max(1, math.ceil(owned / CFG.ASYM_BUDGET))
		local tot, ov, idx = 0, 0, 0
		local atol = CFG.ASYM_TOL
		for _, p in ipairs(S.W) do
			local w = p.vw
			for k = 1, #p.vxs do
				if p.own[k] then
					idx += 1
					if (idx - 1) % stride == 0 then
						tot += w
						local px, py, pz = p.vxs[k], p.vys[k], p.vzs[k]
						local d = (px - grip[1]) * nx + (py - grip[2]) * ny
						local x, y = px - 2 * d * nx, py - 2 * d * ny
						for _, q in ipairs(S.W) do
							if Shapes.aabbContains(q, x, y, pz, atol) and Shapes.sd(q, x, y, pz) <= atol then
								ov += w
								break
							end
						end
					end
				end
			end
		end
		return if tot > 0 then 1 - ov / tot else 0
	end
	function raw.VisibleParts(S)
		local A, Q = 0, 0
		for _, p in ipairs(S.W) do
			A += p.exposedArea
		end
		if A <= 0 then
			return 0
		end
		for _, p in ipairs(S.W) do
			local f = p.exposedArea / A
			Q += f * f
		end
		return 1 / Q
	end
	function raw.Thinness(S)
		local ylo, yhi = math.huge, -math.huge
		local totalOwned = 0
		for _, p in ipairs(S.W) do
			ylo, yhi = min(ylo, p.miny), max(yhi, p.maxy)
			for k = 1, #p.vxs do
				if p.own[k] then
					totalOwned += 1
				end
			end
		end
		local L = yhi - ylo
		local stride = max(1, math.ceil(totalOwned / CFG.THICK_BUDGET))
		local sw1, sw2, tauSum, tauW, cnt = 0, 0, 0, 0, 0
		local idx = 0
		for _, p in ipairs(S.W) do
			for k = 1, #p.vxs do
				if p.own[k] then
					idx += 1
					if (idx - 1) % stride == 0 then
						cnt += 1
						local x, y, z = p.vxs[k], p.vys[k], p.vzs[k]
						local L_ = S.Wall
						local tau = unionChordAt(L_, x, y, z, 0, 0, 1, tol)
						tau = min(tau, unionChordAt(L_, x, y, z, p.thinX, p.thinY, p.thinZ, tol))
						local xs = Num.norm(L / max(tau, 1e-6), CFG.SIGMA_LO, CFG.SIGMA_HI)
						sw1 += p.vw * xs
						sw2 += p.vw * xs * xs
						tauSum += p.vw * tau
						tauW += p.vw
					end
				end
			end
		end
		S.thickSamples, S.meanTau, S.L = cnt, (if tauW > 0 then tauSum / tauW else 0), L
		return if sw1 > 0 then sw2 / sw1 else 0
	end
	function raw.EdgeLength(_S)
		return R.edge.length
	end
	function raw.PartCount(_S)
		local n = 0
		for _, p in ipairs(parts) do
			if kept[p.index] then
				n += p.sig
			end
		end
		return n
	end
	function raw.Joints(_S)
		local J = 0
		for i = 1, N - 1 do
			for j = i + 1, N do
				if kept[i] and kept[j] and conn[i][j] then
					local a = (contact[i][j] + contact[j][i]) / 2
					J += min(parts[i].sig, parts[j].sig) * (1 + CFG.JOINT_BOOST * Num.clamp01(1 - a / CFG.A_JOINT_REF))
				end
			end
		end
		return J
	end
	function raw.MaterialMix(_S)
		local seen, n = {}, 0
		for _, p in ipairs(parts) do
			if kept[p.index] and not seen[p.material] then
				seen[p.material] = true
				n += 1
			end
		end
		return n
	end
	local function factor(S, f: string): number
		if S.x[f] == nil then
			local t0 = clock()
			local v = raw[f](S)
			S.raw[f] = v
			if f == "Thinness" or f == "VisibleParts" then
				S.x[f] = v
			else
				S.x[f] = Num.norm(v, CFG.REF[f][1], CFG.REF[f][2])
			end
			S.t[f] = clock() - t0
		end
		return S.x[f]
	end
	R.steps = {}
	local function evalStep(st)
		local S = getSet(st.set)
		local G = 0
		for _, fw in ipairs(st.w) do
			G += fw[2] * factor(S, fw[1])
		end
		local D = 1 - (1 - S.m) * (1 - G)
		local tier = 1
		for k = #CFG.TIERS, 1, -1 do
			if D >= CFG.TIERS[k][2] then
				tier = k
				break
			end
		end
		local played = min(tier, CFG.MAX_TIER)
		return { id = st.id, G = G, m = S.m, D = D, tier = CFG.TIERS[tier][1], played = CFG.TIERS[played][1], phase2 = st.phase2 }
	end
	for _, st in ipairs(CFG.STEPS) do
		if not st.phase2 then
			table.insert(R.steps, evalStep(st))
		end
	end
	T.factors = clock() - t
	T.total = clock() - tStart -- MVP path ends here
	-- reporting extras (not part of the MVP timing): phase-2 steps and all factors on both sets
	for _, st in ipairs(CFG.STEPS) do
		if st.phase2 then
			table.insert(R.steps, evalStep(st))
		end
	end
	for _, set in ipairs({ "All", "Blade" }) do
		local S = getSet(set)
		for f, _ in pairs(raw) do
			factor(S, f)
		end
	end
	R.F = sets
	R.T = T
	return R
end

return Analyze
