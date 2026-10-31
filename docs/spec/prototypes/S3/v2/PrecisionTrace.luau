--!strict
-- S3 prototype v2: PrecisionTrace (Sharpening).
-- v2 changes: sidesFromChains (main chain split at its point farthest along the grip axis); edgeToPanel in the
-- grip frame with +N (= +X for an upright grip) DOWN, matching S6's canvas and S7's VIEW_H; source bounded to
-- 256 points and to a length the pacer covers in PT_TRAVEL_MAX_MS at pacerSpeed (Douglas-Peucker, doubling
-- tolerance); clearance found by a local grid search (O(n)); PT_Sparse implemented; round4 = math.round.
local R = require("./Rng")
local Rng = R.Rng
local HZ = require("./HoldZone")

local PT = {}
PT.PANEL_W = 3.0
PT.Q = 16384
PT.DS = 0.01
PT.EVAL_MS = 20
PT.MARGIN_U = 0.15
PT.MARGIN_V = 0.12
PT.BLADE_REF_LEN = 4.5
PT.EXAG_MAX = 2.0
PT.EXAG_SHRINK = 0.9 -- per step while the source is longer than the travel bound
PT.MIN_SOURCE_LEN = 0.4
PT.MAX_SOURCE_POINTS = 256
PT.LEN_MARGIN = 0.95 -- source length <= LEN_MARGIN * TRAVEL_MAX_S * pacerSpeed
PT.SIMPLIFY_TOL = 0.004 -- first Douglas-Peucker tolerance (panel u), doubled up to SIMPLIFY_STEPS times
PT.SIMPLIFY_STEPS = 8
PT.CHAIKIN_ITERS = 3
PT.CLEAR_SKIP = 0.30
PT.CLEAR_FRAC = 0.35
PT.CLEAR_CELL = 0.30
PT.TAPER = 0.15
PT.SEARCH = 0.5
PT.BIN = 0.02
PT.VMAX_FACTOR = 6
PT.VMAX_MIN = 1.5
PT.MAX_GAP_MS = 250
PT.TRAVEL_MIN_MS = 6000
PT.TRAVEL_MAX_MS = 30000
-- checks
PT.PRECISE_MIN_SAMPLES = 40
PT.PRECISE_MEAN_DEV = 0.0008
PT.SMOOTH_MIN_TRIPLETS = 150
PT.SMOOTH_MEAN_JERK = 0.0002
PT.SMOOTH_MIN_MOVE = 0.002
PT.TELEPORT_DIST = 0.25
PT.TELEPORT_MAX_DT = 40
PT.TELEPORT_COUNT = 3
PT.SPARSE_FRAC = 0.5

local function quant(x: number): number
	return math.round(x * PT.Q)
end

-- S2 EdgeChain = { points: {{x, y}}, length } (blueprint XY studs, CCW, longest first)
-- returns 0, 1 or 2 sides, each ordered base -> tip (in blueprint XY)
function PT.sidesFromChains(chains: { any }?, gripPoint: { number }, gripAxis: { number }): { { { number } } }
	if not chains or #chains == 0 then
		return {}
	end
	local pts = chains[1].points
	local n = #pts
	if n < 2 then
		return {}
	end
	local ax, ay = gripAxis[1], gripAxis[2]
	local k, best = 1, -math.huge
	for i = 1, n do
		local a = (pts[i][1] - gripPoint[1]) * ax + (pts[i][2] - gripPoint[2]) * ay
		if a > best then
			best, k = a, i
		end
	end
	local sideA, sideB = {}, {}
	for i = 1, k do
		table.insert(sideA, pts[i])
	end
	for i = n, k, -1 do
		table.insert(sideB, pts[i])
	end
	local sides = {}
	if #sideA >= 2 then
		table.insert(sides, sideA)
	end
	if #sideB >= 2 then
		table.insert(sides, sideB)
	end
	return sides
end

local function polyLen(xs: { number }, ys: { number }): number
	local L = 0
	for i = 2, #xs do
		local du, dv = xs[i] - xs[i - 1], ys[i] - ys[i - 1]
		L += math.sqrt(du * du + dv * dv)
	end
	return L
end
PT.polyLen = polyLen

-- Douglas-Peucker keep flags (ties: first index); iterative, order-independent result
local function douglasPeucker(xs: { number }, ys: { number }, tol: number): ({ number }, { number })
	local n = #xs
	local keep = table.create(n, false)
	keep[1], keep[n] = true, true
	local stack = { { 1, n } }
	while #stack > 0 do
		local seg = table.remove(stack) :: { number }
		local a, b = seg[1], seg[2]
		if b > a + 1 then
			local ax, ay, bx, by = xs[a], ys[a], xs[b], ys[b]
			local dx, dy = bx - ax, by - ay
			local l2 = dx * dx + dy * dy
			local dmax, imax = -1, a
			for i = a + 1, b - 1 do
				local px, py = xs[i] - ax, ys[i] - ay
				local t = if l2 > 0 then math.clamp((px * dx + py * dy) / l2, 0, 1) else 0
				local qx, qy = px - dx * t, py - dy * t
				local d = math.sqrt(qx * qx + qy * qy)
				if d > dmax then
					dmax, imax = d, i
				end
			end
			if dmax > tol then
				keep[imax] = true
				table.insert(stack, { a, imax })
				table.insert(stack, { imax, b })
			end
		end
	end
	local ox, oy = {}, {}
	for i = 1, n do
		if keep[i] then
			table.insert(ox, xs[i])
			table.insert(oy, ys[i])
		end
	end
	return ox, oy
end
PT.douglasPeucker = douglasPeucker

-- sides (blueprint XY, base -> tip) -> flat fixed-point source {u1, v1, ...} or nil; info for diagnostics
function PT.edgeToPanel(sides: { { { number } } }, gripPoint: { number }, gripAxis: { number }, pacerSpeed: number): ({ number }?, any)
	if #sides == 0 then
		return nil, { reason = "noSides" }
	end
	local pts: { { number } } = {}
	for _, p in sides[1] do
		table.insert(pts, p)
	end
	if sides[2] then
		local b = sides[2]
		for i = #b, 1, -1 do
			table.insert(pts, b[i])
		end
	end
	local ax, ay = gripAxis[1], gripAxis[2]
	local nx, ny = ay, -ax -- S2's in-plane normal N = (A_y, -A_x): +X for an upright grip
	local A, C = {}, {}
	local aMin, aMax, cMin, cMax = math.huge, -math.huge, math.huge, -math.huge
	for i, p in pts do
		local dx, dy = p[1] - gripPoint[1], p[2] - gripPoint[2]
		A[i] = dx * ax + dy * ay
		C[i] = dx * nx + dy * ny
		aMin, aMax = math.min(aMin, A[i]), math.max(aMax, A[i])
		cMin, cMax = math.min(cMin, C[i]), math.max(cMax, C[i])
	end
	local Lb = aMax - aMin
	if Lb <= 0 then
		return nil, { reason = "flat" }
	end
	local usableU = PT.PANEL_W - 2 * PT.MARGIN_U
	local usableV = 1 - 2 * PT.MARGIN_V
	local s = usableU / math.max(PT.BLADE_REF_LEN, Lb)
	local E = PT.EXAG_MAX
	if cMax > cMin then
		E = math.min(E, usableV / (s * (cMax - cMin)))
	end
	local u0 = (PT.PANEL_W - Lb * s) / 2
	local cMid = (cMin + cMax) / 2
	local function map(e: number): ({ number }, { number })
		local us, vs = {}, {}
		for i = 1, #pts do
			local u = u0 + (A[i] - aMin) * s
			local v = 0.5 + (C[i] - cMid) * s * e -- +N down (VIEW_H)
			-- drop consecutive duplicates (the shared tip)
			if #us == 0 or u ~= us[#us] or v ~= vs[#vs] then
				table.insert(us, u)
				table.insert(vs, v)
			end
		end
		return us, vs
	end
	local maxLen = PT.LEN_MARGIN * (PT.TRAVEL_MAX_MS / 1000) * pacerSpeed
	local us, vs = map(E)
	-- 1) too long: shrink the cross-axis exaggeration first (keeps every point), down to E = 1
	local eSteps = 0
	while polyLen(us, vs) > maxLen and E > 1 do
		E = math.max(1, E * PT.EXAG_SHRINK)
		eSteps += 1
		us, vs = map(E)
	end
	-- 2) still too long or too many points: Douglas-Peucker with a doubling tolerance
	local xs, ys = us, vs
	local tol = 0
	local steps = 0
	while #xs > PT.MAX_SOURCE_POINTS or polyLen(xs, ys) > maxLen do
		steps += 1
		if steps > PT.SIMPLIFY_STEPS then
			return nil, { reason = "tooLong", len = polyLen(us, vs) }
		end
		tol = PT.SIMPLIFY_TOL * 2 ^ (steps - 1)
		xs, ys = douglasPeucker(us, vs, tol)
	end
	if #xs < 2 or polyLen(xs, ys) < PT.MIN_SOURCE_LEN then
		return nil, { reason = "short" }
	end
	local out = {}
	for i = 1, #xs do
		table.insert(out, quant(xs[i]))
		table.insert(out, quant(ys[i]))
	end
	return out, { tol = tol, steps = steps, E = E, eSteps = eSteps, rawPts = #us, pts = #xs, len = polyLen(xs, ys), rawLen = polyLen(us, vs), maxLen = maxLen }
end

-- canonical straight double-edged blade (blueprint XY studs; upright grip at the origin)
PT.FALLBACK_SIDES = {
	{ { 0.22, 0 }, { 0.22, 2.6 }, { 0, 3.4 } },
	{ { -0.22, 0 }, { -0.22, 2.6 }, { 0, 3.4 } },
}

local function chaikin(xs: { number }, ys: { number }): ({ number }, { number })
	local nx, ny = { xs[1] }, { ys[1] }
	for i = 1, #xs - 1 do
		local x0, y0, x1, y1 = xs[i], ys[i], xs[i + 1], ys[i + 1]
		table.insert(nx, 0.75 * x0 + 0.25 * x1)
		table.insert(ny, 0.75 * y0 + 0.25 * y1)
		table.insert(nx, 0.25 * x0 + 0.75 * x1)
		table.insert(ny, 0.25 * y0 + 0.75 * y1)
	end
	table.insert(nx, xs[#xs])
	table.insert(ny, ys[#ys])
	return nx, ny
end

local function resample(xs: { number }, ys: { number }, ds: number): ({ number }, { number })
	local ox, oy = { xs[1] }, { ys[1] }
	local acc = 0
	local i = 1
	local px, py = xs[1], ys[1]
	while i < #xs do
		local qx, qy = xs[i + 1], ys[i + 1]
		local dx, dy = qx - px, qy - py
		local seg = math.sqrt(dx * dx + dy * dy)
		if acc + seg >= ds and seg > 0 then
			local t = (ds - acc) / seg
			px, py = px + dx * t, py + dy * t
			table.insert(ox, px)
			table.insert(oy, py)
			acc = 0
		else
			acc += seg
			px, py = qx, qy
			i += 1
		end
	end
	if acc > ds * 0.25 then
		table.insert(ox, xs[#xs])
		table.insert(oy, ys[#ys])
	else
		ox[#ox], oy[#oy] = xs[#xs], ys[#ys]
	end
	return ox, oy
end

export type Pattern = {
	p: { [string]: number },
	pu: { number },
	pv: { number },
	arc: { number },
	L: number,
	speed: number,
	leadInMs: number,
	travelMs: number,
	durationMs: number,
	usedFallback: boolean,
	hash: number,
	clampedTravel: boolean,
	clearChecks: number,
}

local FALLBACK_SOURCE: { [number]: { number } } = {}

function PT.fallbackSource(pacerSpeed: number): { number }
	local src = FALLBACK_SOURCE[pacerSpeed]
	if not src then
		src = (PT.edgeToPanel(PT.FALLBACK_SIDES, { 0, 0, 0 }, { 0, 1 }, pacerSpeed)) :: { number }
		FALLBACK_SOURCE[pacerSpeed] = src
	end
	return src
end

function PT.generate(seed: number, p: { [string]: number }, source: { number }?): Pattern
	local usedFallback = false
	local xs, ys = {}, {}
	local function load(s: { number })
		local lu, lv = -1, -1
		for i = 1, #s - 1, 2 do
			if s[i] ~= lu or s[i + 1] ~= lv then
				table.insert(xs, s[i] / PT.Q)
				table.insert(ys, s[i + 1] / PT.Q)
				lu, lv = s[i], s[i + 1]
			end
		end
	end
	if source and #source >= 4 then
		load(source)
	end
	if #xs < 2 or polyLen(xs, ys) < PT.MIN_SOURCE_LEN then
		usedFallback = true
		xs, ys = {}, {}
		load(PT.fallbackSource(p.pacerSpeed))
	end
	for _ = 1, PT.CHAIKIN_ITERS do
		xs, ys = chaikin(xs, ys)
	end
	xs, ys = resample(xs, ys, PT.DS)
	local n = #xs
	local arc = { 0 }
	for i = 2, n do
		local du, dv = xs[i] - xs[i - 1], ys[i] - ys[i - 1]
		arc[i] = arc[i - 1] + math.sqrt(du * du + dv * dv)
	end
	local L = arc[n]
	local nu, nv = {}, {}
	for i = 1, n do
		local a, b = math.max(1, i - 1), math.min(n, i + 1)
		local tu, tv = xs[b] - xs[a], ys[b] - ys[a]
		local tl = math.sqrt(tu * tu + tv * tv)
		if tl > 0 then
			nu[i], nv[i] = -tv / tl, tu / tl -- left normal (-dv, du)/|d|
		else
			nu[i], nv[i] = 0, 0
		end
	end
	-- seeded bumps (stratified along the path)
	local rng = Rng.new(seed, "PrecisionTrace.Perturb")
	local K = math.max(1, math.round(L * p.bumpDensity))
	local bc, bw, ba = {}, {}, {}
	for k = 1, K do
		bc[k] = (k - 1 + rng:range(0.2, 0.8)) * L / K
		bw[k] = p.bumpWidth * rng:range(0.7, 1.3)
		ba[k] = p.perturbAmp * rng:range(0.5, 1.0) * rng:sign()
	end
	local o = table.create(n, 0)
	for i = 1, n do
		local sum = 0
		for k = 1, K do
			local x = (arc[i] - bc[k]) / bw[k]
			if x > -1 and x < 1 then
				local q = 1 - x * x
				sum += ba[k] * q * q
			end
		end
		o[i] = sum
	end
	-- local clearance: grid of CLEAR_CELL, search only within r = |o_i| / CLEAR_FRAC
	local G = PT.CLEAR_CELL
	local cells: { [number]: { number } } = {}
	local NCU = 64
	for i = 1, n do
		local key = math.floor(ys[i] / G) * NCU + math.floor(xs[i] / G)
		local list = cells[key]
		if not list then
			list = {}
			cells[key] = list
		end
		table.insert(list, i)
	end
	local checks = 0
	for i = 1, n do
		local oi = o[i]
		if oi ~= 0 then
			local r = math.abs(oi) / PT.CLEAR_FRAC
			local best = r * r
			local found = false
			local cx, cy = math.floor(xs[i] / G), math.floor(ys[i] / G)
			local m = math.ceil(r / G)
			for gy = cy - m, cy + m do
				for gx = cx - m, cx + m do
					local list = cells[gy * NCU + gx]
					if list then
						for _, j in list do
							if math.abs(arc[j] - arc[i]) > PT.CLEAR_SKIP then
								checks += 1
								local du, dv = xs[j] - xs[i], ys[j] - ys[i]
								local d2 = du * du + dv * dv
								if d2 < best then
									best, found = d2, true
								end
							end
						end
					end
				end
			end
			if found then
				local lim = PT.CLEAR_FRAC * math.sqrt(best)
				if oi > lim then
					oi = lim
				elseif oi < -lim then
					oi = -lim
				end
			end
		end
		local taper = math.min(1, arc[i] / PT.TAPER, (L - arc[i]) / PT.TAPER)
		o[i] = oi * taper
	end
	local px, py = {}, {}
	for i = 1, n do
		px[i] = math.clamp(xs[i] + o[i] * nu[i], 0.05, PT.PANEL_W - 0.05)
		py[i] = math.clamp(ys[i] + o[i] * nv[i], 0.05, 0.95)
	end
	px, py = resample(px, py, PT.DS)
	local pu, pv = {}, {}
	local h = 0x811C9DC5
	for i = 1, #px do
		local qu, qv = quant(px[i]), quant(py[i])
		h = HZ.hashU32(h, qu)
		h = HZ.hashU32(h, qv)
		pu[i], pv[i] = qu / PT.Q, qv / PT.Q
	end
	local arc2 = { 0 }
	for i = 2, #pu do
		local du, dv = pu[i] - pu[i - 1], pv[i] - pv[i - 1]
		arc2[i] = arc2[i - 1] + math.sqrt(du * du + dv * dv)
	end
	local L2 = arc2[#pu]
	local travel0 = math.ceil(L2 / p.pacerSpeed * 1000 / PT.EVAL_MS) * PT.EVAL_MS
	local travel = math.clamp(travel0, PT.TRAVEL_MIN_MS, PT.TRAVEL_MAX_MS)
	return {
		p = p,
		pu = pu,
		pv = pv,
		arc = arc2,
		L = L2,
		speed = L2 / (travel / 1000),
		leadInMs = p.leadInMs,
		travelMs = travel,
		durationMs = p.leadInMs + travel + p.tailMs,
		usedFallback = usedFallback,
		hash = h,
		clampedTravel = travel0 > PT.TRAVEL_MAX_MS,
		clearChecks = checks,
	}
end

function PT.pacerArc(pat: Pattern, t: number): number
	local s = (t - pat.leadInMs) * pat.speed / 1000
	if s < 0 then
		return 0
	elseif s > pat.L then
		return pat.L
	end
	return s
end

function PT.pointAt(pat: Pattern, s: number): (number, number)
	local arc = pat.arc
	local i = math.clamp(math.floor(s / PT.DS) + 1, 1, #arc - 1)
	while i > 1 and arc[i] > s do
		i -= 1
	end
	while i < #arc - 1 and arc[i + 1] < s do
		i += 1
	end
	local seg = arc[i + 1] - arc[i]
	local t = if seg > 0 then (s - arc[i]) / seg else 0
	t = math.clamp(t, 0, 1)
	return pat.pu[i] + (pat.pu[i + 1] - pat.pu[i]) * t, pat.pv[i] + (pat.pv[i + 1] - pat.pv[i]) * t
end

-- nearest point of the path to the cursor, searched only around the pacer (arc s* +- SEARCH, by index):
-- stage 1: nearest VERTEX i in [lo, hi] (first minimum wins); stage 2: exact distance to the segments (i-1, i) and
-- (i, i+1) (first minimum wins). 2.6x cheaper than scanning every segment; |d| differs by <= 1.1e-4 u in rare cases.
function PT.nearest(pat: Pattern, cu: number, cv: number, sc: number): (number, number)
	local arc, pu, pv = pat.arc, pat.pu, pat.pv
	local n = #arc
	local lo = math.clamp(math.floor((sc - PT.SEARCH) / PT.DS), 1, n - 1)
	local hi = math.clamp(math.ceil((sc + PT.SEARCH) / PT.DS) + 1, 1, n - 1) + 1
	local bj, bd = lo, math.huge
	for i = lo, hi do
		local du, dv = cu - pu[i], cv - pv[i]
		local d2 = du * du + dv * dv
		if d2 < bd then
			bd, bj = d2, i
		end
	end
	local best, bestS = math.huge, 0
	for i = math.max(lo, bj - 1), math.min(hi - 1, bj) do
		local au, av = pu[i], pv[i]
		local bu, bv = pu[i + 1] - au, pv[i + 1] - av
		local l2 = bu * bu + bv * bv
		local t = 0
		if l2 > 0 then
			t = ((cu - au) * bu + (cv - av) * bv) / l2
			if t < 0 then
				t = 0
			elseif t > 1 then
				t = 1
			end
		end
		local du, dv = cu - (au + bu * t), cv - (av + bv * t)
		local d2 = du * du + dv * dv
		if d2 < best then
			best = d2
			bestS = arc[i] + (arc[i + 1] - arc[i]) * t
		end
	end
	return math.sqrt(best), bestS
end

export type Sample = { t: number, u: number, v: number, grind: boolean }

export type Session = { pat: Pattern, st: { Sample }, j: number, k: number, K: number, accSum: number, paceSum: number, covered: { boolean }, nCovered: number, nBins: number, prevU: number?, prevV: number? }

function PT.newSession(pat: Pattern): Session
	local nBins = math.ceil(pat.L / PT.BIN)
	return { pat = pat, st = {}, j = 1, k = 1, K = pat.travelMs // PT.EVAL_MS, accSum = 0, paceSum = 0, covered = table.create(nBins, false), nCovered = 0, nBins = nBins }
end

function PT.push(s: Session, sm: Sample)
	table.insert(s.st, sm)
end

local function cursorAt(s: Session, t: number): (number?, number?, boolean)
	local st = s.st
	if #st == 0 or t < st[1].t then
		return nil, nil, false
	end
	while s.j < #st and st[s.j + 1].t <= t do
		s.j += 1
	end
	local a = st[s.j]
	local b = st[s.j + 1]
	local au, av = a.u / PT.Q, a.v / PT.Q
	if t == a.t then
		return au, av, a.grind
	end
	if b == nil then
		if t - a.t > PT.MAX_GAP_MS then
			return au, av, false
		end
		return au, av, a.grind
	end
	if b.t - a.t > PT.MAX_GAP_MS then
		return au, av, false
	end
	local f = (t - a.t) / (b.t - a.t)
	local bu, bv = b.u / PT.Q, b.v / PT.Q
	return au + (bu - au) * f, av + (bv - av) * f, a.grind
end

local function evalTick(s: Session, t: number)
	local pat = s.pat
	local p = pat.p
	local cu, cv, grind = cursorAt(s, t)
	local w = p.halfWidth
	local core = p.coreFrac * w
	local sStar = PT.pacerArc(pat, t)
	if cu and cv then
		local speed = math.huge
		if s.prevU then
			local du, dv = cu - (s.prevU :: number), cv - (s.prevV :: number)
			speed = math.sqrt(du * du + dv * dv) / (PT.EVAL_MS / 1000)
		end
		s.prevU, s.prevV = cu, cv
		if grind then
			local d, sc = PT.nearest(pat, cu, cv, sStar)
			local a
			if d <= core then
				a = 1
			else
				a = 1 - (d - core) / (w - core)
				if a < 0 then
					a = 0
				end
			end
			s.accSum += a
			if d <= w then
				local lag = math.abs(sc - sStar)
				local pc
				if lag <= p.paceTol then
					pc = 1
				else
					pc = 1 - (lag - p.paceTol) / p.paceFall
					if pc < 0 then
						pc = 0
					end
				end
				s.paceSum += pc
				local vmax = math.max(PT.VMAX_FACTOR * pat.speed, PT.VMAX_MIN)
				if speed <= vmax then
					local bin = math.min(math.floor(sc / PT.BIN) + 1, s.nBins)
					if not s.covered[bin] then
						s.covered[bin] = true
						s.nCovered += 1
					end
				end
			end
		end
	else
		s.prevU, s.prevV = nil, nil
	end
end

function PT.advance(s: Session, untilMs: number?)
	local pat = s.pat
	local limit = untilMs or (if #s.st > 0 then s.st[#s.st].t else -1)
	while s.k <= s.K do
		local t = pat.leadInMs + s.k * PT.EVAL_MS
		if t > limit then
			break
		end
		if s.k == 1 and s.prevU == nil then
			local u0, v0 = cursorAt(s, t - PT.EVAL_MS)
			s.prevU, s.prevV = u0, v0
			s.j = 1
		end
		evalTick(s, t)
		s.k += 1
	end
end

export type Result = { score: number, rawScore: number, passed: boolean, accuracy: number, pacing: number, coverage: number, flags: { string }, usedFallback: boolean }

function PT.finish(s: Session): Result
	PT.advance(s, s.pat.durationMs)
	local p = s.pat.p
	local A = s.accSum / s.K
	local Pc = s.paceSum / s.K
	local C = s.nCovered / s.nBins
	local score = HZ.round4(C * (p.wAccuracy * A + (1 - p.wAccuracy) * Pc))
	return { score = score, rawScore = score, passed = score >= p.passThreshold, accuracy = A, pacing = Pc, coverage = C, flags = {}, usedFallback = s.pat.usedFallback }
end

function PT.checks(pat: Pattern, samples: { Sample }): ({ string }, { [string]: number })
	local flags = {}
	local devSum, devN = 0, 0
	local jerkSum, jerkN = 0, 0
	local teleports = 0
	local inTravel = 0
	for i, sm in samples do
		if sm.t >= pat.leadInMs and sm.t <= pat.leadInMs + pat.travelMs then
			inTravel += 1
		end
		if sm.grind and sm.t >= pat.leadInMs and sm.t <= pat.leadInMs + pat.travelMs then
			local u, v = sm.u / PT.Q, sm.v / PT.Q
			local d = PT.nearest(pat, u, v, PT.pacerArc(pat, sm.t))
			devSum += d
			devN += 1
			local a, c = samples[i - 1], samples[i + 1]
			if a and c and a.grind and c.grind then
				local dt1, dt2 = sm.t - a.t, c.t - sm.t
				local mu, mv = (c.u - a.u) / PT.Q, (c.v - a.v) / PT.Q
				local moving = math.sqrt(mu * mu + mv * mv) > PT.SMOOTH_MIN_MOVE
				if moving and dt1 >= 10 and dt1 <= 40 and dt2 >= 10 and dt2 <= 40 then
					local ju = (c.u - 2 * sm.u + a.u) / PT.Q
					local jv = (c.v - 2 * sm.v + a.v) / PT.Q
					jerkSum += math.sqrt(ju * ju + jv * jv)
					jerkN += 1
				end
			end
			if a and a.grind then
				local du, dv = (sm.u - a.u) / PT.Q, (sm.v - a.v) / PT.Q
				if sm.t - a.t <= PT.TELEPORT_MAX_DT and math.sqrt(du * du + dv * dv) > PT.TELEPORT_DIST then
					teleports += 1
				end
			end
		end
	end
	local meanDev = if devN > 0 then devSum / devN else 0
	local meanJerk = if jerkN > 0 then jerkSum / jerkN else 0
	if devN >= PT.PRECISE_MIN_SAMPLES and meanDev < PT.PRECISE_MEAN_DEV then
		table.insert(flags, "PT_TooPrecise")
	end
	if jerkN >= PT.SMOOTH_MIN_TRIPLETS and meanJerk < PT.SMOOTH_MEAN_JERK then
		table.insert(flags, "PT_TooSmooth")
	end
	if teleports >= PT.TELEPORT_COUNT then
		table.insert(flags, "PT_Teleport")
	end
	if inTravel < PT.SPARSE_FRAC * (pat.travelMs / PT.EVAL_MS) then
		table.insert(flags, "PT_Sparse")
	end
	table.sort(flags)
	return flags, { meanDev = meanDev, meanJerk = meanJerk, teleports = teleports, devN = devN, jerkN = jerkN }
end

function PT.replay(pat: Pattern, samples: { Sample }): Result
	local s = PT.newSession(pat)
	for _, sm in samples do
		PT.push(s, sm)
	end
	local res = PT.finish(s)
	res.flags = PT.checks(pat, samples)
	return res
end

return PT
