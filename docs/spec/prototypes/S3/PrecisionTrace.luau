--!strict
-- S3 prototype: PrecisionTrace (Sharpening). Path from the blade's sharpenable edge, seeded perturbation,
-- fixed-step (20 ms) evaluation of a piecewise-linear cursor trajectory.
local R = require("./Rng")
local Rng = R.Rng
local HZ = require("./HoldZone") -- hashInts

local PT = {}
PT.PANEL_W = 3.0 -- panel width in panel-height units (height = 1)
PT.Q = 16384 -- fixed-point scale (1 unit = 16384)
PT.DS = 0.01 -- path resample spacing (panel units)
PT.EVAL_MS = 20
PT.MARGIN_U = 0.15
PT.MARGIN_V = 0.12
PT.BLADE_REF_LEN = 4.5 -- studs that span the usable panel width
PT.EXAG_MAX = 2.0 -- max cross-axis exaggeration
PT.MIN_SOURCE_LEN = 0.4 -- panel units; shorter edges use the fallback
PT.CHAIKIN_ITERS = 3
PT.CLEAR_SKIP = 0.30 -- arc distance ignored when measuring clearance
PT.CLEAR_FRAC = 0.35 -- |offset| <= CLEAR_FRAC * clearance
PT.TAPER = 0.15 -- arc length at both ends without perturbation
PT.SEARCH = 0.5 -- +- arc window around the pacer for the nearest-point search
PT.BIN = 0.02 -- coverage bin length
PT.VMAX_FACTOR = 6 -- coverage only while cursor speed <= VMAX_FACTOR * pacer speed
PT.VMAX_MIN = 1.5 -- panel units / s floor of that limit
PT.MAX_GAP_MS = 250 -- larger sample gaps: cursor holds, not grinding
PT.MIN_TRAVEL_MS = 6000
PT.MAX_TRAVEL_MS = 30000

local function quant(x: number): number
	return math.floor(x * PT.Q + 0.5)
end

-- polylines: list of polylines in blueprint X-Y studs, each ordered base -> tip
function PT.edgeToPanel(polylines: { { { number } } }?): { number }?
	if not polylines or #polylines == 0 then
		return nil
	end
	local pts: { { number } } = {}
	for _, pt in polylines[1] do
		table.insert(pts, { pt[1], pt[2] })
	end
	if polylines[2] then
		local b = polylines[2]
		for i = #b, 1, -1 do
			table.insert(pts, { b[i][1], b[i][2] })
		end
	end
	if #pts < 2 then
		return nil
	end
	local xMin, xMax, yMin, yMax = math.huge, -math.huge, math.huge, -math.huge
	for _, pt in pts do
		xMin, xMax = math.min(xMin, pt[1]), math.max(xMax, pt[1])
		yMin, yMax = math.min(yMin, pt[2]), math.max(yMax, pt[2])
	end
	local usableU = PT.PANEL_W - 2 * PT.MARGIN_U
	local usableV = 1 - 2 * PT.MARGIN_V
	local Lb = yMax - yMin
	if Lb <= 0 then
		return nil
	end
	local s = usableU / math.max(PT.BLADE_REF_LEN, Lb)
	local wx = xMax - xMin
	local E = PT.EXAG_MAX
	if wx > 0 then
		E = math.min(E, usableV / (s * wx))
	end
	local sx = s * E
	local u0 = (PT.PANEL_W - Lb * s) / 2
	local xc = (xMin + xMax) / 2
	local out = {}
	for _, pt in pts do
		local u = u0 + (pt[2] - yMin) * s
		local v = 0.5 - (pt[1] - xc) * sx
		table.insert(out, quant(u))
		table.insert(out, quant(v))
	end
	return out
end

-- canonical straight double-edged blade (studs) used when no usable edge exists
PT.FALLBACK_EDGE = {
	{ { 0.22, 0 }, { 0.22, 2.6 }, { 0, 3.4 } },
	{ { -0.22, 0 }, { -0.22, 2.6 }, { 0, 3.4 } },
}

local function polyLen(xs: { number }, ys: { number }): number
	local L = 0
	for i = 2, #xs do
		local du, dv = xs[i] - xs[i - 1], ys[i] - ys[i - 1]
		L += math.sqrt(du * du + dv * dv)
	end
	return L
end

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
	local acc = 0 -- distance since last emitted point
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
	pu: { number }, -- final path points (floats = int / Q)
	pv: { number },
	arc: { number }, -- cumulative arc length at each point
	L: number,
	speed: number, -- effective pacer speed (panel units / s)
	leadInMs: number,
	travelMs: number,
	durationMs: number,
	usedFallback: boolean,
	hash: number,
}

function PT.generate(seed: number, p: { [string]: number }, source: { number }?): Pattern
	local usedFallback = false
	local src = source
	local xs, ys = {}, {}
	-- consecutive duplicate vertices (e.g. the shared tip of two edges) are dropped
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
	if src and #src >= 4 then
		load(src)
	end
	if #xs < 2 or polyLen(xs, ys) < PT.MIN_SOURCE_LEN then
		usedFallback = true
		src = PT.edgeToPanel(PT.FALLBACK_EDGE)
		xs, ys = {}, {}
		load(src :: { number })
	end
	for _ = 1, PT.CHAIKIN_ITERS do
		xs, ys = chaikin(xs, ys)
	end
	xs, ys = resample(xs, ys, PT.DS)
	local n = #xs
	-- arc, normals
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
			nu[i], nv[i] = -tv / tl, tu / tl
		else
			nu[i], nv[i] = 0, 0
		end
	end
	-- clearance to non-neighbouring parts of the path
	local clear = {}
	for i = 1, n do
		local best = math.huge
		for j = 1, n do
			if math.abs(arc[j] - arc[i]) > PT.CLEAR_SKIP then
				local du, dv = xs[j] - xs[i], ys[j] - ys[i]
				local d2 = du * du + dv * dv
				if d2 < best then
					best = d2
				end
			end
		end
		clear[i] = math.sqrt(best)
	end
	-- seeded bumps (stratified along the path)
	local rng = Rng.new(seed, "PrecisionTrace.Perturb")
	local K = math.max(1, math.floor(L * p.bumpDensity + 0.5))
	local bc, bw, ba = {}, {}, {}
	for k = 1, K do
		bc[k] = (k - 1 + rng:range(0.2, 0.8)) * L / K
		bw[k] = p.bumpWidth * rng:range(0.7, 1.3)
		ba[k] = p.perturbAmp * rng:range(0.5, 1.0) * rng:sign()
	end
	local px, py = {}, {}
	for i = 1, n do
		local o = 0
		for k = 1, K do
			local x = (arc[i] - bc[k]) / bw[k]
			if x > -1 and x < 1 then
				local q = 1 - x * x
				o += ba[k] * q * q
			end
		end
		local lim = PT.CLEAR_FRAC * clear[i]
		if o > lim then
			o = lim
		elseif o < -lim then
			o = -lim
		end
		local taper = math.min(1, arc[i] / PT.TAPER, (L - arc[i]) / PT.TAPER)
		o *= taper
		px[i] = math.clamp(xs[i] + o * nu[i], 0.05, PT.PANEL_W - 0.05)
		py[i] = math.clamp(ys[i] + o * nv[i], 0.05, 0.95)
	end
	px, py = resample(px, py, PT.DS)
	-- quantize the final path (canonical) and rebuild arc
	local pu, pv = {}, {}
	local h = 0x811C9DC5
	for i = 1, #px do
		local qu, qv = quant(px[i]), quant(py[i])
		h = HZ.hashInts(h, qu)
		h = HZ.hashInts(h, qv)
		pu[i], pv[i] = qu / PT.Q, qv / PT.Q
	end
	local arc2 = { 0 }
	for i = 2, #pu do
		local du, dv = pu[i] - pu[i - 1], pv[i] - pv[i - 1]
		arc2[i] = arc2[i - 1] + math.sqrt(du * du + dv * dv)
	end
	local L2 = arc2[#pu]
	local travel = math.ceil(L2 / p.pacerSpeed * 1000 / PT.EVAL_MS) * PT.EVAL_MS
	travel = math.clamp(travel, PT.MIN_TRAVEL_MS, PT.MAX_TRAVEL_MS)
	local speed = L2 / (travel / 1000)
	return {
		p = p,
		pu = pu,
		pv = pv,
		arc = arc2,
		L = L2,
		speed = speed,
		leadInMs = p.leadInMs,
		travelMs = travel,
		durationMs = p.leadInMs + travel + p.tailMs,
		usedFallback = usedFallback,
		hash = h,
	}
end

-- pacer arc position at time t
function PT.pacerArc(pat: Pattern, t: number): number
	local s = (t - pat.leadInMs) * pat.speed / 1000
	if s < 0 then
		return 0
	elseif s > pat.L then
		return pat.L
	end
	return s
end

-- point at arc s
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

-- nearest point on the path within +-SEARCH of arc sc; returns distance, arc of nearest point
function PT.nearest(pat: Pattern, cu: number, cv: number, sc: number): (number, number)
	local arc, pu, pv = pat.arc, pat.pu, pat.pv
	local n = #arc
	local lo = math.clamp(math.floor((sc - PT.SEARCH) / PT.DS), 1, n - 1)
	local hi = math.clamp(math.ceil((sc + PT.SEARCH) / PT.DS) + 1, 1, n - 1)
	local best, bestS = math.huge, 0
	for i = lo, hi do
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
		local qu, qv = au + bu * t, av + bv * t
		local du, dv = cu - qu, cv - qv
		local d2 = du * du + dv * dv
		if d2 < best then
			best = d2
			bestS = arc[i] + (arc[i + 1] - arc[i]) * t
		end
	end
	return math.sqrt(best), bestS
end

export type Sample = { t: number, u: number, v: number, grind: boolean } -- u, v are fixed-point ints

export type Session = {
	pat: Pattern,
	st: { Sample },
	j: number, -- sample cursor
	k: number, -- next eval tick (1-based)
	K: number,
	accSum: number,
	paceSum: number,
	covered: { boolean },
	nCovered: number,
	nBins: number,
	prevU: number?,
	prevV: number?,
	onPathTicks: number,
}

function PT.newSession(pat: Pattern): Session
	local nBins = math.ceil(pat.L / PT.BIN)
	local covered = table.create(nBins, false)
	return {
		pat = pat,
		st = {},
		j = 1,
		k = 1,
		K = pat.travelMs // PT.EVAL_MS,
		accSum = 0,
		paceSum = 0,
		covered = covered,
		nCovered = 0,
		nBins = nBins,
		prevU = nil,
		prevV = nil,
		onPathTicks = 0,
	}
end

function PT.push(s: Session, sm: Sample)
	table.insert(s.st, sm)
end

-- cursor state at time t (from samples); returns u, v (floats), grinding
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
		return au, av, a.grind -- exactly on a sample: identical live and in replay
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
	local span = b.t - a.t
	local f = if span > 0 then (t - a.t) / span else 0
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
		local d, sc = PT.nearest(pat, cu, cv, sStar)
		local speed = math.huge
		if s.prevU then
			local du, dv = cu - (s.prevU :: number), cv - (s.prevV :: number)
			speed = math.sqrt(du * du + dv * dv) / (PT.EVAL_MS / 1000)
		end
		s.prevU, s.prevV = cu, cv
		if grind then
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
				s.onPathTicks += 1
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

-- evaluate all ticks whose time is <= the latest sample time (live) or <= untilMs (finish)
function PT.advance(s: Session, untilMs: number?)
	local pat = s.pat
	local limit = untilMs or (if #s.st > 0 then s.st[#s.st].t else -1)
	-- prime previous position one tick before the first scored tick
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

export type Result = {
	score: number,
	passed: boolean,
	accuracy: number,
	pacing: number,
	coverage: number,
	flags: { string },
}

local function round4(x: number): number
	return math.floor(x * 10000 + 0.5) / 10000
end

function PT.finish(s: Session): Result
	PT.advance(s, s.pat.durationMs)
	local p = s.pat.p
	local A = s.accSum / s.K
	local Pc = s.paceSum / s.K
	local C = s.nCovered / s.nBins
	local score = round4(C * (p.wAccuracy * A + (1 - p.wAccuracy) * Pc))
	return { score = score, passed = score >= p.passThreshold, accuracy = A, pacing = Pc, coverage = C, flags = {} }
end

-- impossible-input checks on raw samples
PT.PRECISE_MIN_SAMPLES = 40
PT.PRECISE_MEAN_DEV = 0.0008
PT.SMOOTH_MIN_TRIPLETS = 150
PT.SMOOTH_MEAN_JERK = 0.0002
PT.SMOOTH_MIN_MOVE = 0.002 -- triplet must span > 1 px at 500 px panel
PT.TELEPORT_DIST = 0.25
PT.TELEPORT_MAX_DT = 40
PT.TELEPORT_COUNT = 3
function PT.checks(pat: Pattern, samples: { Sample }): ({ string }, { [string]: number })
	local flags = {}
	local devSum, devN = 0, 0
	local jerkSum, jerkN = 0, 0
	local teleports = 0
	for i, sm in samples do
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
