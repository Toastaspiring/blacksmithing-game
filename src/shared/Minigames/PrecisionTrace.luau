--!strict
-- Minigames/PrecisionTrace (SPEC §6.10, §6.14, §10.6, §16.22, E-S3.5; owner S3): Sharpening. A spark (the pacer) runs
-- along a path drawn from the blade's own edge and the player grinds behind it, keeping the cursor on the band; the
-- records are cursor samples {t, u, v, grind} from GO, u and v in 1/16384 panel units (one per 20 ms, from Input).
-- Ticks every PT_EVAL_MS score accuracy, pace and coverage. Pure.
--
--   sidesFromChains     S2's main chain chains[1], split at its first point farthest along the grip axis A: side A =
--                       points 1…k, side B = points n…k, each base → tip; a side under 2 points is dropped
--   edgeToPanel         A ++ reverse(B) in the grip frame N = (A_y, −A_x), +N down: s = 2.7/max(4.5, Lb), E = min(2,
--                       0.76/(s·range c)), u = (3 − Lb·s)/2 + (a − min a)·s, v = 0.5 + (c − mid c)·s·E; longer than
--                       the pacer covers in PT_TRAVEL_MAX_MS → E ×= 0.9 down to 1, then Douglas–Peucker (tolerance 0.004
--                       doubled per attempt, at most 8, every attempt on one tree of its splits) while > 256 points or
--                       too long; nil when nothing fits, < 2 points or < 0.4 u; source = {round(u·16384),
--                       round(v·16384), …}
--   generate(seed, p, source?)   load (the fallback edge when none, < 2 points or < 0.4 u) → Chaikin ×3 → resample at
--                       0.01 → seeded bumps along the left normals (Rng "PrecisionTrace.Perturb"), each offset clamped to
--                       0.35 × its clearance (a grid search) and tapered at the ends → into the panel → resample →
--                       quantize; travelMs = clamp(ceil(L/pacerSpeed·1000/20)·20, 6000, 30000), durationMs = leadInMs +
--                       travelMs + tailMs; hash: FNV-1a over (uQ_i, vQ_i)
--   advance(S, now)     evaluates the ticks t_k = leadInMs + 20k, k = 1…travelMs/20, with t_k ≤ min(now, the latest
--                       sample's t): the cursor at t_k (a lerp between samples; past a gap over 250 ms it holds, not
--                       grinding), the path's nearest point around the pacer s*(t_k), accuracy (1 in the core, down to
--                       0 at halfWidth), pace (1 within paceTol of s*, down over paceFall) and coverage (the bin of the
--                       nearest point, under the speed gate); finish evaluates every remaining tick
--   finish              score = q(C·(wAccuracy·A + (1 − wAccuracy)·P)), A and P tick means, C = covered bins /
--                       ceil(L/0.02); breakdown accuracy, pacing, coverage, usedFallback (§6.14)
--   checks              PtSparse, PtTeleport, PtTooPrecise, PtTooSmooth over the samples in travel (§10.6; thresholds,
--                       PtTooSmooth's dt bounds included, are Definitions' rows)
--
-- Every expression is the S3 prototype's in its order (docs/spec/prototypes/S3/v2/PrecisionTrace.luau), which made
-- E-S3's hashes, goldens and distributions (M4's D1): note travel0 = ceil(L/pacerSpeed·1000/20)·20, not §6.10's
-- ceil(L/pacerSpeed·50)·20, which rounds differently, and the Douglas–Peucker tolerance doubled per attempt where the
-- prototype writes 0.004·2^(steps − 1) (the same doubles: a product by 2 is exact). The prototype runs each attempt
-- anew; here they share one tree of the splits, which keeps the same points at a fraction of the cost of several
-- attempts (M4's fix round 1: on X08's zigzag the prototype's 8 attempts were most of prepare). Where one or two
-- attempts suffice, the whole tree can cost more than they do, and far more than one attempt, which may stop at its
-- first segment: up to about 0.5 ms on 256 points, where every split sheds one point (M4's fix round 3). Live =
-- replay (§6.4 rule 7): advance evaluates a tick only once a sample at or after it is known, so every tick sees the
-- replay's cursor.
-- The view: the pacer on the raw clock, the cursor from the latest sample, and for §12.8's trail and tint the latest
-- tick's accuracy credit and the covered bins as runs (G14). Live score: the accuracy and pace means of the ticks so
-- far, times the coverage of the arc the pacer has passed **[Decision to confirm]** (§17.1 O14); display only.

local DT = require("../Definitions/Types")
local Quantize = require("../Util/Quantize")
local Checks = require("./Checks")
local Rng = require("./Rng")
local Types = require("./Types")

type EdgeChain = Types.EdgeChain
type FeedbackEvent = Types.FeedbackEvent
type FlagId = Types.FlagId
type MinigameResult = Types.MinigameResult
type PrecisionTraceView = Types.PrecisionTraceView
type TraceRecord = Types.TraceRecord
type Vec2 = Types.Vec2

export type Pattern = {
	p: { [string]: number },
	pu: { number }, -- the path, panel u (multiples of 1/16384)
	pv: { number },
	arc: { number }, -- arc length (u) at each point
	L: number,
	speed: number, -- the pacer (u/s)
	leadInMs: number,
	travelMs: number,
	durationMs: number,
	usedFallback: boolean,
	hash: number,
}
export type Session = {
	pat: Pattern,
	st: { TraceRecord }, -- the pushed samples
	j: number, -- the cursor's sample pointer
	k: number, -- the next tick
	K: number, -- ticks: travelMs / PT_EVAL_MS
	accSum: number,
	paceSum: number,
	covered: { boolean }, -- per arc bin
	nCovered: number,
	nBins: number,
	prevU: number?, -- the cursor at the previous tick (the speed gate)
	prevV: number?,
	-- presentation (views and feedback); no score reads them
	credit: number?, -- the last evaluated tick's accuracy credit
	grinding: boolean,
	onPath: boolean,
	paceOk: boolean,
	quarters: number,
	ended: boolean,
}
-- edgeToPanelInfo's diagnostics (tests, E-S3.5's table): why there is no source, or how it was fitted
export type EdgeInfo = {
	reason: string?, -- "noSides", "flat", "tooLong" or "short" when there is no source
	E: number?, -- the cross-axis exaggeration used
	eSteps: number?, -- its shrink steps
	tol: number?, -- the last Douglas–Peucker tolerance (0: not simplified)
	steps: number?, -- Douglas–Peucker attempts
	rawPts: number?,
	pts: number?,
	rawLen: number?,
	len: number?,
	maxLen: number?,
}
-- the inhuman-input measures checks reads (T-MG-10 reports them)
export type Measures = {
	meanDev: number, -- mean nearest distance of the grinding samples in travel (u)
	devN: number,
	meanJerk: number, -- mean |Δ²p| of the moving triplets (u)
	jerkN: number,
	teleports: number,
	inTravel: number, -- samples in travel
}

local FAMILY: DT.FamilyId = "PrecisionTrace"
-- §16.22
local PT_PANEL_ASPECT = 3.0 -- the panel's width, in heights (u)
local PT_FIXED_POINT = 16384 -- per u: sources and records hold round(u·16384) ≤ 49152, round(v·16384) ≤ 16384
local PT_MARGIN_U = 0.15 -- u
local PT_MARGIN_V = 0.12 -- u
local PT_BLADE_REF_LEN = 4.5 -- studs: a blade this long spans the usable panel
local PT_EXAG_MAX = 2.0 -- cross-axis exaggeration
local PT_EXAG_SHRINK = 0.9 -- its step while the source is longer than the travel bound
local PT_LEN_MARGIN = 0.95 -- a source ≤ PT_LEN_MARGIN · PT_TRAVEL_MAX_MS · pacerSpeed
local PT_MAX_SOURCE_POINTS = 256
local PT_SIMPLIFY_TOL = 0.004 -- u: the first Douglas–Peucker tolerance
local PT_SIMPLIFY_STEPS = 8 -- attempts, the tolerance doubled each
local PT_MIN_SOURCE_LEN = 0.4 -- u: shorter sources play the fallback edge
local PT_CHAIKIN_ITERS = 3
local PT_DS = 0.01 -- u: path spacing
local PT_TAPER = 0.15 -- u: calm ends
local PT_CLEAR_SKIP = 0.30 -- u of arc: a path point's own stretch, not its clearance
local PT_CLEAR_FRAC = 0.35 -- |offset| ≤ PT_CLEAR_FRAC × clearance: the path never crosses itself
local PT_CLEAR_CELL = 0.30 -- u: the clearance grid
local PT_EVAL_MS = 20 -- ms: the tick, the sampling cadence
local PT_SEARCH = 0.5 -- u of arc: the nearest-point window around the pacer
local PT_BIN = 0.02 -- u of arc: a coverage bin
local PT_VMAX_FACTOR = 6 -- × the pacer's speed: the coverage speed gate
local PT_VMAX_MIN = 1.5 -- u/s
local PT_MAX_GAP_MS = 250 -- ms: a longer gap between samples holds the cursor, not grinding
local PT_TRAVEL_MIN_MS = 6000
local PT_TRAVEL_MAX_MS = 30000
-- a generic straight double edge (blueprint XY studs) and its upright grip, for a blade with no usable edge (Q15)
local PT_FALLBACK_EDGE = table.freeze({
	sides = table.freeze({
		table.freeze({ table.freeze({ 0.22, 0 }), table.freeze({ 0.22, 2.6 }), table.freeze({ 0, 3.4 }) }),
		table.freeze({ table.freeze({ -0.22, 0 }), table.freeze({ -0.22, 2.6 }), table.freeze({ 0, 3.4 }) }),
	}),
	gripPoint = table.freeze({ 0, 0, 0 }),
	gripAxis = table.freeze({ 0, 1 }),
})
-- the clearance grid's row stride (the prototype's; no §16 row): cell columns stay below it, since u ≤ 3 gives ≤ 10
local NCU = 64

-- typed, so luau-lsp keeps the literal types (M1's lesson)
local PT_SPARSE: FlagId = "PtSparse"
local PT_TELEPORT: FlagId = "PtTeleport"
local PT_TOO_PRECISE: FlagId = "PtTooPrecise"
local PT_TOO_SMOOTH: FlagId = "PtTooSmooth"

-- push and advance hand this out when nothing fires (no table per call, M4's D13)
local NONE: { FeedbackEvent } = table.freeze({})

local function q(x: number): number
	return Quantize.q(x, Quantize.SCALAR_SCALE)
end

local function add(events: { FeedbackEvent }?, e: FeedbackEvent): { FeedbackEvent }
	local out = events or {}
	table.insert(out, e)
	return out
end

local function polyLen(xs: { number }, ys: { number }): number
	local L = 0
	for i = 2, #xs do
		local du, dv = xs[i] - xs[i - 1], ys[i] - ys[i - 1]
		L += math.sqrt(du * du + dv * dv)
	end
	return L
end

-- Douglas–Peucker's splits, made once for all the hand-off's attempts: a segment's first farthest point (ties keep the
-- first index) does not depend on the tolerance, only whether the segment splits there (dmax > tol) does, so keeping
-- the splits with dmax > tol from the root down keeps exactly the points an iterative Douglas–Peucker at tol (the
-- prototype's) keeps. A segment gets children only when its loop found a farthest point (imax > a, so dmax ≥ 0): a NaN
-- distance never beats −1, and Douglas–Peucker leaves such a segment whole at every tolerance, so the tree is finite
-- for every input
type Splits = { a: { number }, b: { number }, i: { number }, d: { number }, left: { number }, right: { number } }

local function splitTree(xs: { number }, ys: { number }): Splits
	local tree: Splits = { a = { 1 }, b = { #xs }, i = {}, d = {}, left = {}, right = {} }
	local k = 1
	while k <= #tree.a do
		local a, b = tree.a[k], tree.b[k]
		local dmax, imax = -1, a
		if b > a + 1 then
			local ax, ay, bx, by = xs[a], ys[a], xs[b], ys[b]
			local dx, dy = bx - ax, by - ay
			local l2 = dx * dx + dy * dy
			for i = a + 1, b - 1 do
				local px, py = xs[i] - ax, ys[i] - ay
				local t = if l2 > 0 then math.clamp((px * dx + py * dy) / l2, 0, 1) else 0
				local qx, qy = px - dx * t, py - dy * t
				local d = math.sqrt(qx * qx + qy * qy)
				if d > dmax then
					dmax, imax = d, i
				end
			end
		end
		tree.i[k], tree.d[k], tree.left[k], tree.right[k] = imax, dmax, 0, 0
		if imax > a then
			table.insert(tree.a, a)
			table.insert(tree.b, imax)
			tree.left[k] = #tree.a
			table.insert(tree.a, imax)
			table.insert(tree.b, b)
			tree.right[k] = #tree.a
		end
		k += 1
	end
	return tree
end

-- the points Douglas–Peucker keeps at tol: the splits with dmax > tol, from the root down
local function keptFor(tree: Splits, xs: { number }, ys: { number }, tol: number): ({ number }, { number })
	local n = #xs
	local keep = table.create(n, false)
	keep[1], keep[n] = true, true
	local stack: { number } = { 1 }
	while #stack > 0 do
		local k = table.remove(stack) :: number
		if tree.d[k] > tol then
			keep[tree.i[k]] = true
			table.insert(stack, tree.left[k])
			table.insert(stack, tree.right[k])
		end
	end
	local ox: { number }, oy: { number } = {}, {}
	for i = 1, n do
		if keep[i] then
			table.insert(ox, xs[i])
			table.insert(oy, ys[i])
		end
	end
	return ox, oy
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

-- points every ds along the polyline, the last point kept: appended when the remainder is over ds/4, else in place of
-- the last resampled point
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

-- a source's points in panel units, consecutive duplicates dropped
local function loadSource(s: { number }): ({ number }, { number })
	local xs: { number }, ys: { number } = {}, {}
	local lu, lv = -1, -1
	for i = 1, #s - 1, 2 do
		if s[i] ~= lu or s[i + 1] ~= lv then
			table.insert(xs, s[i] / PT_FIXED_POINT)
			table.insert(ys, s[i + 1] / PT_FIXED_POINT)
			lu, lv = s[i], s[i + 1]
		end
	end
	return xs, ys
end

local PrecisionTrace = {
	id = FAMILY,
	PT_PANEL_ASPECT = PT_PANEL_ASPECT,
	PT_FIXED_POINT = PT_FIXED_POINT,
	PT_MARGIN_U = PT_MARGIN_U,
	PT_MARGIN_V = PT_MARGIN_V,
	PT_BLADE_REF_LEN = PT_BLADE_REF_LEN,
	PT_EXAG_MAX = PT_EXAG_MAX,
	PT_EXAG_SHRINK = PT_EXAG_SHRINK,
	PT_LEN_MARGIN = PT_LEN_MARGIN,
	PT_MAX_SOURCE_POINTS = PT_MAX_SOURCE_POINTS,
	PT_SIMPLIFY_TOL = PT_SIMPLIFY_TOL,
	PT_SIMPLIFY_STEPS = PT_SIMPLIFY_STEPS,
	PT_MIN_SOURCE_LEN = PT_MIN_SOURCE_LEN,
	PT_FALLBACK_EDGE = PT_FALLBACK_EDGE,
	PT_CHAIKIN_ITERS = PT_CHAIKIN_ITERS,
	PT_DS = PT_DS,
	PT_TAPER = PT_TAPER,
	PT_CLEAR_SKIP = PT_CLEAR_SKIP,
	PT_CLEAR_FRAC = PT_CLEAR_FRAC,
	PT_CLEAR_CELL = PT_CLEAR_CELL,
	PT_EVAL_MS = PT_EVAL_MS,
	PT_SEARCH = PT_SEARCH,
	PT_BIN = PT_BIN,
	PT_VMAX_FACTOR = PT_VMAX_FACTOR,
	PT_VMAX_MIN = PT_VMAX_MIN,
	PT_MAX_GAP_MS = PT_MAX_GAP_MS,
	PT_TRAVEL_MIN_MS = PT_TRAVEL_MIN_MS,
	PT_TRAVEL_MAX_MS = PT_TRAVEL_MAX_MS,
}

-- S2's main chain as 0, 1 or 2 sides, each base → tip in blueprint XY (§6.10's edge hand-off)
function PrecisionTrace.sidesFromChains(chains: { EdgeChain }?, gripPoint: { number }, gripAxis: Vec2): { { Vec2 } }
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
	local sideA: { Vec2 }, sideB: { Vec2 } = {}, {}
	for i = 1, k do
		table.insert(sideA, pts[i])
	end
	for i = n, k, -1 do
		table.insert(sideB, pts[i])
	end
	local sides: { { Vec2 } } = {}
	if #sideA >= 2 then
		table.insert(sides, sideA)
	end
	if #sideB >= 2 then
		table.insert(sides, sideB)
	end
	return sides
end

-- the sides mapped into the panel as a fixed-point source {u1, v1, u2, v2, …}, or nil; and how (EdgeInfo)
function PrecisionTrace.edgeToPanelInfo(sides: { { Vec2 } }, gripPoint: { number }, gripAxis: Vec2,
	pacerSpeed: number): ({ number }?, EdgeInfo)
	if #sides == 0 then
		return nil, { reason = "noSides" }
	end
	local pts: { Vec2 } = {}
	for _, p in ipairs(sides[1]) do
		table.insert(pts, p)
	end
	local b = sides[2]
	if b then
		for i = #b, 1, -1 do
			table.insert(pts, b[i])
		end
	end
	local ax, ay = gripAxis[1], gripAxis[2]
	local nx, ny = ay, -ax -- S2's in-plane normal N = (A_y, −A_x): +X for an upright grip
	local A: { number }, C: { number } = {}, {}
	local aMin, aMax, cMin, cMax = math.huge, -math.huge, math.huge, -math.huge
	for i, p in ipairs(pts) do
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
	local usableU = PT_PANEL_ASPECT - 2 * PT_MARGIN_U
	local usableV = 1 - 2 * PT_MARGIN_V
	local s = usableU / math.max(PT_BLADE_REF_LEN, Lb)
	local E = PT_EXAG_MAX
	if cMax > cMin then
		E = math.min(E, usableV / (s * (cMax - cMin)))
	end
	local u0 = (PT_PANEL_ASPECT - Lb * s) / 2
	local cMid = (cMin + cMax) / 2
	local function map(e: number): ({ number }, { number })
		local us: { number }, vs: { number } = {}, {}
		for i = 1, #pts do
			local u = u0 + (A[i] - aMin) * s
			local v = 0.5 + (C[i] - cMid) * s * e -- +N down (S7's VIEW_H)
			-- consecutive duplicates dropped (the shared tip)
			if #us == 0 or u ~= us[#us] or v ~= vs[#vs] then
				table.insert(us, u)
				table.insert(vs, v)
			end
		end
		return us, vs
	end
	local maxLen = PT_LEN_MARGIN * (PT_TRAVEL_MAX_MS / 1000) * pacerSpeed
	local us, vs = map(E)
	-- too long for the travel bound: shrink the cross-axis exaggeration first (every point kept), down to E = 1
	local eSteps = 0
	while polyLen(us, vs) > maxLen and E > 1 do
		E = math.max(1, E * PT_EXAG_SHRINK)
		eSteps += 1
		us, vs = map(E)
	end
	-- still too long, or too many points: Douglas–Peucker, the tolerance doubled each attempt, every attempt on the
	-- one split tree
	local xs, ys = us, vs
	local tol = 0
	local steps = 0
	local tree: Splits? = nil
	while #xs > PT_MAX_SOURCE_POINTS or polyLen(xs, ys) > maxLen do
		steps += 1
		if steps > PT_SIMPLIFY_STEPS then
			return nil, { reason = "tooLong", len = polyLen(us, vs) }
		end
		tol = if steps == 1 then PT_SIMPLIFY_TOL else tol * 2
		if tree == nil then
			tree = splitTree(us, vs)
		end
		xs, ys = keptFor(tree :: Splits, us, vs, tol)
	end
	if #xs < 2 or polyLen(xs, ys) < PT_MIN_SOURCE_LEN then
		return nil, { reason = "short" }
	end
	local out: { number } = {}
	for i = 1, #xs do
		table.insert(out, math.round(xs[i] * PT_FIXED_POINT))
		table.insert(out, math.round(ys[i] * PT_FIXED_POINT))
	end
	return out, { E = E, eSteps = eSteps, tol = tol, steps = steps, rawPts = #us, pts = #xs, rawLen = polyLen(us, vs),
		len = polyLen(xs, ys), maxLen = maxLen }
end

function PrecisionTrace.edgeToPanel(sides: { { Vec2 } }, gripPoint: { number }, gripAxis: Vec2,
	pacerSpeed: number): { number }?
	local source = PrecisionTrace.edgeToPanelInfo(sides, gripPoint, gripAxis, pacerSpeed)
	return source
end

-- PT_FALLBACK_EDGE's source at this pacer speed, made on every call (no module-level cache)
function PrecisionTrace.fallbackSource(pacerSpeed: number): { number }
	local e = PT_FALLBACK_EDGE
	local source = PrecisionTrace.edgeToPanel(e.sides, e.gripPoint, e.gripAxis, pacerSpeed)
	if source == nil then
		error("PrecisionTrace.fallbackSource: the fallback edge does not fit at pacerSpeed " .. tostring(pacerSpeed), 2)
	end
	return source
end

function PrecisionTrace.generate(seed: number, p: { [string]: number }, source: { number }?): Pattern
	local usedFallback = false
	local xs: { number }, ys: { number } = {}, {}
	if source and #source >= 4 then
		xs, ys = loadSource(source)
	end
	if #xs < 2 or polyLen(xs, ys) < PT_MIN_SOURCE_LEN then
		usedFallback = true
		xs, ys = loadSource(PrecisionTrace.fallbackSource(p.pacerSpeed))
	end
	for _ = 1, PT_CHAIKIN_ITERS do
		xs, ys = chaikin(xs, ys)
	end
	xs, ys = resample(xs, ys, PT_DS)
	local n = #xs
	local arc = { 0 }
	for i = 2, n do
		local du, dv = xs[i] - xs[i - 1], ys[i] - ys[i - 1]
		arc[i] = arc[i - 1] + math.sqrt(du * du + dv * dv)
	end
	local L = arc[n]
	local nu: { number }, nv: { number } = {}, {}
	for i = 1, n do
		local a, b = math.max(1, i - 1), math.min(n, i + 1)
		local tu, tv = xs[b] - xs[a], ys[b] - ys[a]
		local tl = math.sqrt(tu * tu + tv * tv)
		if tl > 0 then
			nu[i], nv[i] = -tv / tl, tu / tl -- the left normal (−dv, du)/|d|
		else
			nu[i], nv[i] = 0, 0
		end
	end
	-- seeded bumps, stratified along the path; draws per bump: centre, width, amplitude, sign
	local rng = Rng.new(seed, Rng.TAGS.PrecisionTracePerturb)
	local K = math.max(1, math.round(L * p.bumpDensity))
	local bc: { number }, bw: { number }, ba: { number } = {}, {}, {}
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
				local w = 1 - x * x
				sum += ba[k] * w * w
			end
		end
		o[i] = sum
	end
	-- the clearance: the nearest point more than PT_CLEAR_SKIP of arc away, searched on a grid of PT_CLEAR_CELL within
	-- r = |o_i| / PT_CLEAR_FRAC (the same clamp as a full scan; the cell map is looked up, never iterated)
	local G = PT_CLEAR_CELL
	local cells: { [number]: { number } } = {}
	for i = 1, n do
		local key = math.floor(ys[i] / G) * NCU + math.floor(xs[i] / G)
		local list = cells[key]
		if not list then
			list = {}
			cells[key] = list
		end
		table.insert(list, i)
	end
	for i = 1, n do
		local oi = o[i]
		if oi ~= 0 then
			local r = math.abs(oi) / PT_CLEAR_FRAC
			local best = r * r
			local found = false
			local cx, cy = math.floor(xs[i] / G), math.floor(ys[i] / G)
			local m = math.ceil(r / G)
			for gy = cy - m, cy + m do
				for gx = cx - m, cx + m do
					local list = cells[gy * NCU + gx]
					if list then
						for _, j in ipairs(list) do
							if math.abs(arc[j] - arc[i]) > PT_CLEAR_SKIP then
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
				local lim = PT_CLEAR_FRAC * math.sqrt(best)
				if oi > lim then
					oi = lim
				elseif oi < -lim then
					oi = -lim
				end
			end
		end
		local taper = math.min(1, arc[i] / PT_TAPER, (L - arc[i]) / PT_TAPER)
		o[i] = oi * taper
	end
	local px: { number }, py: { number } = {}, {}
	for i = 1, n do
		px[i] = math.clamp(xs[i] + o[i] * nu[i], 0.05, PT_PANEL_ASPECT - 0.05)
		py[i] = math.clamp(ys[i] + o[i] * nv[i], 0.05, 0.95)
	end
	px, py = resample(px, py, PT_DS)
	local pu: { number }, pv: { number } = {}, {}
	local h = Rng.FNV_BASIS
	for i = 1, #px do
		local qu, qv = math.round(px[i] * PT_FIXED_POINT), math.round(py[i] * PT_FIXED_POINT)
		h = Rng.hashU32(h, qu)
		h = Rng.hashU32(h, qv)
		pu[i], pv[i] = qu / PT_FIXED_POINT, qv / PT_FIXED_POINT
	end
	local arc2 = { 0 }
	for i = 2, #pu do
		local du, dv = pu[i] - pu[i - 1], pv[i] - pv[i - 1]
		arc2[i] = arc2[i - 1] + math.sqrt(du * du + dv * dv)
	end
	local L2 = arc2[#pu]
	local travel0 = math.ceil(L2 / p.pacerSpeed * 1000 / PT_EVAL_MS) * PT_EVAL_MS
	local travel = math.clamp(travel0, PT_TRAVEL_MIN_MS, PT_TRAVEL_MAX_MS)
	return table.freeze({
		p = p,
		pu = table.freeze(pu),
		pv = table.freeze(pv),
		arc = table.freeze(arc2),
		L = L2,
		speed = L2 / (travel / 1000),
		leadInMs = p.leadInMs,
		travelMs = travel,
		durationMs = p.leadInMs + travel + p.tailMs,
		usedFallback = usedFallback,
		hash = h,
	})
end

function PrecisionTrace.hash(P: Pattern): number
	return P.hash
end

-- the pacer's arc at t: s*(t) = clamp((t − leadInMs)·speed/1000, 0, L)
function PrecisionTrace.pacerArc(P: Pattern, t: number): number
	local s = (t - P.leadInMs) * P.speed / 1000
	if s < 0 then
		return 0
	elseif s > P.L then
		return P.L
	end
	return s
end

-- the path's point at arc s
function PrecisionTrace.pointAt(P: Pattern, s: number): (number, number)
	local arc = P.arc
	local i = math.clamp(math.floor(s / PT_DS) + 1, 1, #arc - 1)
	while i > 1 and arc[i] > s do
		i -= 1
	end
	while i < #arc - 1 and arc[i + 1] < s do
		i += 1
	end
	local seg = arc[i + 1] - arc[i]
	local t = if seg > 0 then (s - arc[i]) / seg else 0
	t = math.clamp(t, 0, 1)
	return P.pu[i] + (P.pu[i + 1] - P.pu[i]) * t, P.pv[i] + (P.pv[i + 1] - P.pv[i]) * t
end

-- the path's nearest point to the cursor (cu, cv), searched only around the pacer's arc sc: the nearest vertex j in
-- the index window of arc sc ± PT_SEARCH (the first minimum), then the exact distance to the segments (j − 1, j) and
-- (j, j + 1) (the first minimum). Returns the distance and the nearest point's arc.
function PrecisionTrace.nearest(P: Pattern, cu: number, cv: number, sc: number): (number, number)
	local arc, pu, pv = P.arc, P.pu, P.pv
	local n = #arc
	local lo = math.clamp(math.floor((sc - PT_SEARCH) / PT_DS), 1, n - 1)
	local hi = math.clamp(math.ceil((sc + PT_SEARCH) / PT_DS) + 1, 1, n - 1) + 1
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

function PrecisionTrace.newSession(P: Pattern): Session
	local nBins = math.ceil(P.L / PT_BIN)
	return {
		pat = P,
		st = {},
		j = 1,
		k = 1,
		K = math.floor(P.travelMs / PT_EVAL_MS),
		accSum = 0,
		paceSum = 0,
		covered = table.create(nBins, false),
		nCovered = 0,
		nBins = nBins,
		prevU = nil,
		prevV = nil,
		credit = nil,
		grinding = false,
		onPath = false,
		paceOk = true,
		quarters = 0,
		ended = false,
	}
end

-- a sample: GrindStart / GrindStop when its grind flag differs from the last sample's (not grinding before the first)
function PrecisionTrace.push(S: Session, r: TraceRecord): { FeedbackEvent }
	table.insert(S.st, r)
	if r.grind ~= S.grinding then
		S.grinding = r.grind
		return { { kind = if r.grind then "GrindStart" else "GrindStop", t = r.t } }
	end
	return NONE
end

-- the cursor at t (panel u, v) and whether it grinds: the last sample a with a.t ≤ t and the next one b; at a's time,
-- a; with no b, a, grinding while t − a.t ≤ PT_MAX_GAP_MS; across a gap over PT_MAX_GAP_MS, a, not grinding; else the
-- lerp from a to b with a's grind; none before the first sample. The pointer only moves forward.
local function cursorAt(S: Session, t: number): (number?, number?, boolean)
	local st = S.st
	if #st == 0 or t < st[1].t then
		return nil, nil, false
	end
	while S.j < #st and st[S.j + 1].t <= t do
		S.j += 1
	end
	local a = st[S.j]
	local b: TraceRecord? = st[S.j + 1]
	local au, av = a.u / PT_FIXED_POINT, a.v / PT_FIXED_POINT
	if t == a.t then
		return au, av, a.grind
	end
	if b == nil then
		if t - a.t > PT_MAX_GAP_MS then
			return au, av, false
		end
		return au, av, a.grind
	end
	if b.t - a.t > PT_MAX_GAP_MS then
		return au, av, false
	end
	local f = (t - a.t) / (b.t - a.t)
	local bu, bv = b.u / PT_FIXED_POINT, b.v / PT_FIXED_POINT
	return au + (bu - au) * f, av + (bv - av) * f, a.grind
end

-- one tick at t: accuracy, pace and coverage as the prototype's evalTick, then the presentation state and its events
-- (OnPath / OffPath when a grinding tick's d ≤ halfWidth changes, off before the first; PaceWarn, +1 ahead or −1
-- behind, when |s_c − s*| first exceeds paceTol after being within it; Coverage at each quarter of the bins)
local function evalTick(S: Session, t: number, events: { FeedbackEvent }?): { FeedbackEvent }?
	local pat = S.pat
	local p = pat.p
	local cu, cv, grind = cursorAt(S, t)
	local w = p.halfWidth
	local core = p.coreFrac * w
	local sStar = PrecisionTrace.pacerArc(pat, t)
	local credit = 0
	if cu and cv then
		local speed = math.huge
		if S.prevU then
			local du, dv = cu - (S.prevU :: number), cv - (S.prevV :: number)
			speed = math.sqrt(du * du + dv * dv) / (PT_EVAL_MS / 1000)
		end
		S.prevU, S.prevV = cu, cv
		if grind then
			local d, sc = PrecisionTrace.nearest(pat, cu, cv, sStar)
			local a
			if d <= core then
				a = 1
			else
				a = 1 - (d - core) / (w - core)
				if a < 0 then
					a = 0
				end
			end
			S.accSum += a
			credit = a
			local inside = d <= w
			if inside ~= S.onPath then
				S.onPath = inside
				events = add(events, { kind = if inside then "OnPath" else "OffPath", t = t })
			end
			if inside then
				local lag = math.abs(sc - sStar)
				local pc
				if lag <= p.paceTol then
					pc = 1
					S.paceOk = true
				else
					pc = 1 - (lag - p.paceTol) / p.paceFall
					if pc < 0 then
						pc = 0
					end
					if S.paceOk then
						S.paceOk = false
						events = add(events, { kind = "PaceWarn", t = t, value = if sc > sStar then 1 else -1 })
					end
				end
				S.paceSum += pc
				local vmax = math.max(PT_VMAX_FACTOR * pat.speed, PT_VMAX_MIN)
				if speed <= vmax then
					local bin = math.min(math.floor(sc / PT_BIN) + 1, S.nBins)
					if not S.covered[bin] then
						S.covered[bin] = true
						S.nCovered += 1
						while S.quarters < 4 and S.nCovered * 4 >= (S.quarters + 1) * S.nBins do
							S.quarters += 1
							events = add(events, { kind = "Coverage", t = t, value = 25 * S.quarters })
						end
					end
				end
			end
		end
	else
		S.prevU, S.prevV = nil, nil
	end
	S.credit = credit
	return events
end

-- evaluates the ticks with t_k ≤ limit (tick 1's previous cursor is the one at t_1 − PT_EVAL_MS); End after the last
local function evaluate(S: Session, limit: number): { FeedbackEvent }?
	local pat = S.pat
	local events: { FeedbackEvent }? = nil
	while S.k <= S.K do
		local t = pat.leadInMs + S.k * PT_EVAL_MS
		if t > limit then
			break
		end
		if S.k == 1 and S.prevU == nil then
			local u0, v0 = cursorAt(S, t - PT_EVAL_MS)
			S.prevU, S.prevV = u0, v0
			S.j = 1
		end
		events = evalTick(S, t, events)
		S.k += 1
	end
	if S.k > S.K and not S.ended then
		S.ended = true
		events = add(events, { kind = "End", t = pat.leadInMs + S.K * PT_EVAL_MS })
	end
	return events
end

-- the ticks up to now that a known sample reaches (live = replay)
function PrecisionTrace.advance(S: Session, nowMs: number): { FeedbackEvent }
	local st = S.st
	local latest = if #st > 0 then st[#st].t else -1
	return evaluate(S, math.min(nowMs, latest)) or NONE
end

function PrecisionTrace.finish(S: Session): MinigameResult
	local pat = S.pat
	local p = pat.p
	evaluate(S, pat.durationMs)
	local A = S.accSum / S.K
	local Pc = S.paceSum / S.K
	local C = S.nCovered / S.nBins
	local score = q(C * (p.wAccuracy * A + (1 - p.wAccuracy) * Pc))
	return {
		status = "Ok",
		score = score,
		rawScore = score,
		passed = score >= p.passThreshold,
		flags = {},
		invalidReason = nil,
		breakdown = { accuracy = A, pacing = Pc, coverage = C, usedFallback = if pat.usedFallback then 1 else 0 },
		elapsedMs = 0,
	}
end

-- the samples' inhuman-input measures, in sample order (§10.6): the grinding samples in travel give the mean nearest
-- distance to the path around the pacer, their moving triplets (both neighbours grinding, the outer span over
-- PT_SMOOTH_MIN_MOVE, both intervals in [PT_SMOOTH_DT_MIN_MS, PT_SMOOTH_DT_MAX_MS]) the mean |Δ²p|, and their steps
-- from a grinding sample the jumps over PT_TELEPORT_DIST within PT_TELEPORT_MAX_DT
function PrecisionTrace.measures(P: Pattern, samples: { TraceRecord }): Measures
	local Q = PT_FIXED_POINT
	local minMove = Checks.value(FAMILY, "PT_SMOOTH_MIN_MOVE")
	local dtMin = Checks.value(FAMILY, "PT_SMOOTH_DT_MIN_MS")
	local dtMax = Checks.value(FAMILY, "PT_SMOOTH_DT_MAX_MS")
	local jumpDist = Checks.value(FAMILY, "PT_TELEPORT_DIST")
	local jumpDt = Checks.value(FAMILY, "PT_TELEPORT_MAX_DT")
	local devSum, devN = 0, 0
	local jerkSum, jerkN = 0, 0
	local teleports = 0
	local inTravel = 0
	for i, sm in ipairs(samples) do
		local travel = sm.t >= P.leadInMs and sm.t <= P.leadInMs + P.travelMs
		if travel then
			inTravel += 1
		end
		if sm.grind and travel then
			local d = PrecisionTrace.nearest(P, sm.u / Q, sm.v / Q, PrecisionTrace.pacerArc(P, sm.t))
			devSum += d
			devN += 1
			local a: TraceRecord?, c: TraceRecord? = samples[i - 1], samples[i + 1]
			if a and c and a.grind and c.grind then
				local dt1, dt2 = sm.t - a.t, c.t - sm.t
				local mu, mv = (c.u - a.u) / Q, (c.v - a.v) / Q
				local moving = math.sqrt(mu * mu + mv * mv) > minMove
				if moving and dt1 >= dtMin and dt1 <= dtMax and dt2 >= dtMin and dt2 <= dtMax then
					local ju = (c.u - 2 * sm.u + a.u) / Q
					local jv = (c.v - 2 * sm.v + a.v) / Q
					jerkSum += math.sqrt(ju * ju + jv * jv)
					jerkN += 1
				end
			end
			if a and a.grind then
				local du, dv = (sm.u - a.u) / Q, (sm.v - a.v) / Q
				if sm.t - a.t <= jumpDt and math.sqrt(du * du + dv * dv) > jumpDist then
					teleports += 1
				end
			end
		end
	end
	return {
		meanDev = if devN > 0 then devSum / devN else 0,
		devN = devN,
		meanJerk = if jerkN > 0 then jerkSum / jerkN else 0,
		jerkN = jerkN,
		teleports = teleports,
		inTravel = inTravel,
	}
end

function PrecisionTrace.checks(P: Pattern, samples: { TraceRecord }, _result: MinigameResult): { FlagId }
	local m = PrecisionTrace.measures(P, samples)
	local flags: { FlagId } = {}
	-- in byte order (§10.5)
	if m.inTravel < Checks.value(FAMILY, "PT_SPARSE_FRAC") * (P.travelMs / PT_EVAL_MS) then
		table.insert(flags, PT_SPARSE)
	end
	if m.teleports >= Checks.value(FAMILY, "PT_TELEPORT_COUNT") then
		table.insert(flags, PT_TELEPORT)
	end
	if m.devN >= Checks.value(FAMILY, "PT_PRECISE_MIN_SAMPLES") and m.meanDev < Checks.value(FAMILY, "PT_PRECISE_MEAN_DEV") then
		table.insert(flags, PT_TOO_PRECISE)
	end
	if m.jerkN >= Checks.value(FAMILY, "PT_SMOOTH_MIN_TRIPLETS") and m.meanJerk < Checks.value(FAMILY, "PT_SMOOTH_MEAN_JERK") then
		table.insert(flags, PT_TOO_SMOOTH)
	end
	return flags
end

-- the covered bins as runs {first1, last1, first2, last2, …}, bin b spanning arc [(b − 1)·PT_BIN, b·PT_BIN)
local function coveredRuns(S: Session): { number }
	local runs: { number } = {}
	local covered, nBins = S.covered, S.nBins
	for b = 1, nBins do
		if covered[b] then
			if b == 1 or not covered[b - 1] then
				table.insert(runs, b)
			end
			if b == nBins or not covered[b + 1] then
				table.insert(runs, b)
			end
		end
	end
	return runs
end

-- the live score (O14): the score's formula on the ticks so far, coverage over the bins the pacer has passed by the
-- last of them (every bin once the last tick is in, so it ends equal to the score); 0 before the first tick
local function runningScore(S: Session): number
	local n = S.k - 1
	if n <= 0 then
		return 0
	end
	local pat = S.pat
	local p = pat.p
	local passed = S.nBins
	if S.k <= S.K then
		passed = math.clamp(math.ceil(PrecisionTrace.pacerArc(pat, pat.leadInMs + n * PT_EVAL_MS) / PT_BIN), 1, S.nBins)
	end
	local A = S.accSum / n
	local Pc = S.paceSum / n
	local C = math.min(1, S.nCovered / passed)
	return q(C * (p.wAccuracy * A + (1 - p.wAccuracy) * Pc))
end

-- The panel at nowMs (the raw clock): the pacer there, the cursor from the latest sample (distance and arc from the
-- path's nearest point around the pacer), the tick sums so far. The static path is the pattern's pu, pv.
function PrecisionTrace.view(S: Session, nowMs: number): PrecisionTraceView
	local pat = S.pat
	local sStar = PrecisionTrace.pacerArc(pat, nowMs)
	local pacerU, pacerV = PrecisionTrace.pointAt(pat, sStar)
	local last: TraceRecord? = S.st[#S.st]
	local distance: number?, cursorArc: number?, paceLag: number? = nil, nil, nil
	local onPath, grinding = false, false
	if last then
		local d, sc = PrecisionTrace.nearest(pat, last.u / PT_FIXED_POINT, last.v / PT_FIXED_POINT, sStar)
		distance, cursorArc = d, sc
		onPath = d <= pat.p.halfWidth
		grinding = last.grind
		if onPath then
			paceLag = sc - sStar
		end
	end
	local ticks = S.k - 1
	return {
		t = nowMs,
		pacerU = pacerU,
		pacerV = pacerV,
		pacerArc = sStar,
		cursorArc = cursorArc,
		distance = distance,
		onPath = onPath,
		grinding = grinding,
		accuracySoFar = if ticks > 0 then S.accSum / ticks else 0,
		coverage = S.nCovered / S.nBins,
		paceLag = paceLag,
		credit = S.credit,
		coveredRuns = coveredRuns(S),
		runningScore = runningScore(S),
		timeLeftMs = math.max(0, pat.durationMs - nowMs),
	}
end

return table.freeze(PrecisionTrace)
