--!strict
-- Minigames/PrecisionTrace (SPEC §6.10, §6.14, §10.6, §16.22, E-S3.5; T-MG-13 (a)): §16.22's constants and the reference
-- edges against the S3 prototype; E-S3.5's golden source, path, hash and fallback, and its blade table for all nine
-- edges; the edge hand-off's bounds (one side, degenerate chains, the travel bound, Douglas–Peucker's doubling
-- tolerance), its Douglas–Peucker against the prototype's on random chains, and the worst source at the length bound;
-- nearest's first minimum on a tie, the coverage gate's floor and a source's duplicate points; the travel clamp; the
-- tick rules on a straight path (accuracy at the core and the band's edge, pace, coverage and its speed gate, the
-- 250 ms gap, tick 1's previous cursor); each flag at its threshold, PtTooSmooth's dt bounds 9 / 10 / 40 / 41 ms
-- included; the view (credit, covered runs, the live score, O14) and feedback; live = replay; and the prototype's edge
-- mapping, generate, replay and checks bit for bit (M4's D1).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Cost = require("../fixtures/Cost")
local Edges = require("../fixtures/Edges")
local DT = require("../../src/shared/Definitions/Types")
local Checks = require("../../src/shared/Minigames/Checks")
local Params = require("../../src/shared/Minigames/Params")
local PrecisionTrace = require("../../src/shared/Minigames/PrecisionTrace")
local Types = require("../../src/shared/Minigames/Types")

-- Through a cast, so luau-lsp stays out of the prototype's loose types: it is reference data, not game code.
local Proto: any = (require :: any)("../../docs/spec/prototypes/S3/v2/PrecisionTrace")
local Blades: any = (require :: any)("../../docs/spec/prototypes/S3/v2/Blades")

type Pattern = PrecisionTrace.Pattern
type Session = PrecisionTrace.Session
type TraceRecord = Types.TraceRecord
type FeedbackEvent = Types.FeedbackEvent
type FlagId = Types.FlagId
type MinigameResult = Types.MinigameResult

local PT = PrecisionTrace
local QF = PT.PT_FIXED_POINT
local MATERIALS: { DT.MaterialId } = { "Iron", "Steel" }
local TIERS: { DT.TierId } = { "Normal", "Hard", "Expert", "Master", "Hell" }
local PROTO_FLAG: { [string]: FlagId } = {
	PT_TooPrecise = "PtTooPrecise", PT_TooSmooth = "PtTooSmooth", PT_Teleport = "PtTeleport", PT_Sparse = "PtSparse",
}

local function paramsOf(material: DT.MaterialId, tier: DT.TierId, x: number): { [string]: number }
	return Params.resolve("PrecisionTrace", material, tier, Params.refFactors(x))
end

-- an edge's source at a pacer speed, through the hand-off
local function sourceOf(e: Edges.Edge, pacerSpeed: number): { number }?
	return PT.edgeToPanel(PT.sidesFromChains(e.chains, e.gripPoint, e.gripAxis), e.gripPoint, e.gripAxis, pacerSpeed)
end

-- the judge's path without the facade (slice 7): push every sample, finish, checks
local function replay(P: Pattern, samples: { TraceRecord }): (MinigameResult, { FlagId }, Session)
	local S = PT.newSession(P)
	for _, r in ipairs(samples) do
		PT.push(S, r)
	end
	local result = PT.finish(S)
	return result, PT.checks(P, samples, result), S
end

-- a sample at panel (u, v), quantized as Input records it
local function sample(t: number, u: number, v: number, grind: boolean): TraceRecord
	return { t = t, u = math.clamp(math.round(u * QF), 0, 3 * QF), v = math.clamp(math.round(v * QF), 0, QF), grind = grind }
end

-- on the pacer every `every` ms from GO to the end, v shifted by dv
local function onPacer(P: Pattern, every: number, dv: number): { TraceRecord }
	local out: { TraceRecord } = {}
	local t = 0
	while t <= P.durationMs do
		local u, v = PT.pointAt(P, PT.pacerArc(P, t))
		table.insert(out, sample(t, u, v + dv, true))
		t += every
	end
	return out
end

-- A straight path along v = 0.5 from u = 0.5: 201 points 164/16384 u apart (exact doubles, about PT_DS), L =
-- 2.001953125, travel 8000 ms, so the pacer moves 82/16384 u per tick; halfWidth 1024/16384 and coreFrac 0.125 (core
-- 128/16384), so a cursor k/16384 off the line is exactly that far from it.
local function straight(): Pattern
	local p = table.clone(paramsOf("Iron", "Normal", 0))
	p.halfWidth = 1024 / 16384
	p.coreFrac = 0.125
	local pu: { number }, pv: { number }, arc: { number } = {}, {}, {}
	for i = 1, 201 do
		pu[i] = (8192 + 164 * (i - 1)) / 16384
		pv[i] = 0.5
		arc[i] = 164 * (i - 1) / 16384
	end
	local L = arc[201]
	return { p = p, pu = pu, pv = pv, arc = arc, L = L, speed = L / 8, leadInMs = 600, travelMs = 8000, durationMs = 9000,
		usedFallback = false, hash = 0 }
end

-- tick k's time
local function tickT(P: Pattern, k: number): number
	return P.leadInMs + k * PT.PT_EVAL_MS
end

-- a sample at tick k's time on the straight path: at arc s* + ds, dk/16384 off the line
local function atTick(P: Pattern, k: number, ds: number, dk: number, grind: boolean): TraceRecord
	local t = tickT(P, k)
	local u = P.pu[1] + math.clamp(PT.pacerArc(P, t) + ds, 0, P.L)
	return { t = t, u = math.round(u * QF), v = 8192 + dk, grind = grind }
end

-- a session with these samples, advanced to tick k
local function sessionAt(P: Pattern, samples: { TraceRecord }, k: number): Session
	local S = PT.newSession(P)
	for _, r in ipairs(samples) do
		PT.push(S, r)
	end
	PT.advance(S, tickT(P, k))
	return S
end

-- human-like samples from GO to the end, strictly increasing times: one per frame of about `every` ms, the cursor ahead
-- of or behind the pacer by a drifting lag, off the line by a cross offset, with tremor; grinding with lifts; now and
-- then a gap over 250 ms or a jump. One case in six is a cheat: on the pacer every 20 ms.
local function humanSamples(rng: TestRng.TestRng, P: Pattern): { TraceRecord }
	local out: { TraceRecord } = {}
	local cheat = rng:int(1, 6) == 1
	local lag = if cheat then 0 else rng:range(-0.15, 0.15)
	local cross = if cheat then 0 else rng:range(-0.03, 0.03)
	local tremor = if cheat then 0 else rng:pick({ 0, 0.0005, 0.002, 0.01 })
	local every = if cheat then 20 else rng:pick({ 20, 20, 17, 33, 40, 200 })
	local grind = cheat or rng:int(1, 4) > 1
	local t = 0
	while t <= P.durationMs do
		local u, v = PT.pointAt(P, math.clamp(PT.pacerArc(P, t) + lag, 0, P.L))
		if tremor > 0 then
			u += rng:normal(0, tremor)
			v += rng:normal(0, tremor)
		end
		table.insert(out, sample(t, u + cross, v + cross, grind))
		if not cheat then
			local r = rng:int(1, 100)
			if r <= 3 then
				grind = not grind
			elseif r == 4 then
				t += rng:int(251, 600)
			elseif r == 5 then
				cross = rng:range(-0.4, 0.4)
			elseif r <= 25 then
				lag = math.clamp(lag + rng:range(-0.05, 0.05), -0.5, 0.5)
			end
		end
		t += if cheat then every else math.max(1, every + rng:int(-3, 3))
	end
	return out
end

-- printed to `dp` decimals in the evidence: within half a unit of the last printed digit
local function printed(actual: number, expected: number, dp: number, what: string)
	local unit = 1
	for _ = 1, dp do
		unit /= 10
	end
	A.near(actual, expected, unit / 2 * (1 + 1e-9) + 1e-12, what)
end

-- deep equality, numbers bit for bit (−0 = 0), building no string: A.deepEq names a path per element, too slow for a
-- whole path, so it only words a failure
local function same(a: any, b: any): boolean
	if a == b then
		return true
	elseif type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function deepEqFast(actual: any, expected: any, msg: string)
	if not same(actual, expected) then
		A.deepEq(actual, expected, msg)
	end
end

-- kinds, with a value when there is one: "OnPath PaceWarn(1)"
local function kinds(events: { FeedbackEvent }): string
	local out: { string } = {}
	for _, e in ipairs(events) do
		table.insert(out, e.kind .. (if e.value then "(" .. tostring(e.value) .. ")" else ""))
	end
	return table.concat(out, " ")
end

-- a property case at PROP_N_FAST cases in the quick run, and at PROP_N under t.slow (M4's L1 share, D10)
local function sized(t: Test.Api, name: string, body: (n: number) -> ())
	t.it(name, function()
		body(Tol.PROP_N_FAST)
	end)
	t.slow(name .. " (PROP_N cases)", function()
		body(Tol.PROP_N)
	end)
end

-- an edge turned by a radians about its grip, with its grip axis (test-side trigonometry: both implementations get the
-- same doubles)
local function turned(e: Edges.Edge, a: number): Edges.Edge
	local c, s = math.cos(a), math.sin(a)
	local g = e.gripPoint
	local pts: { { number } } = {}
	for _, p in ipairs(e.chains[1].points) do
		local x, y = p[1] - g[1], p[2] - g[2]
		table.insert(pts, { g[1] + x * c - y * s, g[2] + x * s + y * c })
	end
	local ax, ay = e.gripAxis[1], e.gripAxis[2]
	return { name = e.name .. " turned", chains = { { points = pts, length = e.chains[1].length } }, gripPoint = g,
		gripAxis = { ax * c - ay * s, ax * s + ay * c } }
end

-- a random edge for the hand-off: a reference edge, turned about its grip now and then
local function randomEdge(rng: TestRng.TestRng): Edges.Edge
	local e: Edges.Edge = (Edges :: any)[rng:pick(Edges.order)]
	if rng:int(1, 3) > 1 then
		return e
	end
	return turned(e, rng:range(-math.pi, math.pi))
end

-- a random chain of the shapes that reach the hand-off's Douglas–Peucker (too long once E is 1, or over 256 points):
-- a zigzag, a walk, a comb (two-point teeth), straight runs between corners (exactly collinear when a run follows the
-- axis), doubled points with the chain run back over itself, a closed loop; 3 to 300 points, a turned grip
local function dpEdge(rng: TestRng.TestRng): Edges.Edge
	local kind = rng:int(1, 6)
	local n = rng:pick({ 3, 10, 40, 120, 200, 256, 300 })
	local amp = rng:pick({ 0.01, 0.05, 0.3, 0.8 })
	local Lb = rng:range(0.5, 9)
	local pts: { { number } } = {}
	if kind == 1 then
		for i = 1, n do
			table.insert(pts, { if i % 2 == 0 then amp else -amp, 0.9 + Lb * (i - 1) / (n - 1) })
		end
	elseif kind == 2 or kind == 6 then
		local x, y = 0, 0.9
		for _ = 1, if kind == 6 then n - 1 else n do
			x += rng:normal(0, amp / 5)
			y += Lb / n * rng:range(if kind == 6 then -0.5 else 0, 2)
			table.insert(pts, { x, y })
		end
		if kind == 6 then
			table.insert(pts, { pts[1][1], pts[1][2] }) -- the loop closes: the hand-off's first and last points meet
		end
	elseif kind == 3 then
		for i = 1, n do
			table.insert(pts, { if i % 4 < 2 then amp else 0, 0.9 + Lb * (i - 1) / (n - 1) })
		end
	elseif kind == 4 then
		local corners = rng:int(2, 9)
		local per = math.max(1, math.floor(n / corners))
		local x0, y0 = 0, 0.9
		for c = 1, corners do
			local x1 = if rng:int(1, 3) == 1 then x0 else rng:range(-amp, amp)
			local y1 = 0.9 + Lb * c / corners
			for k = 0, per - 1 do
				table.insert(pts, { x0 + (x1 - x0) * k / per, y0 + (y1 - y0) * k / per })
			end
			x0, y0 = x1, y1
		end
		table.insert(pts, { x0, y0 })
	else
		local m = math.max(2, math.floor(n / 3))
		for i = 1, m do
			local x, y = if i % 2 == 0 then amp else -amp, 0.9 + Lb * (i - 1) / (m - 1)
			table.insert(pts, { x, y })
			if rng:int(1, 3) == 1 then
				table.insert(pts, { x, y })
			end
		end
		for i = #pts - 1, 1, -1 do
			table.insert(pts, { pts[i][1], pts[i][2] })
		end
	end
	local turn = rng:range(-0.6, 0.6)
	-- the grip axis not of unit length, on purpose: the hand-off takes it as given
	return { name = "dp " .. kind, chains = { { points = pts, length = 0 } },
		gripPoint = { rng:range(-0.2, 0.2), 0.88, 0 }, gripAxis = { -turn, 1 } }
end

return Test.suite("Minigames/PrecisionTrace", function(t)
	t.it("PrecisionTrace is §6.2's FamilyModule: id, generate, hash, newSession, push, advance, view, finish, checks", function()
		-- typed: luau-lsp checks the module against the facade's type (a wider table, by width subtyping)
		local F: Types.FamilyModule<Pattern, TraceRecord, Session, Types.PrecisionTraceView> = PrecisionTrace
		A.eq(F.id, "PrecisionTrace")
		for _, name in { "generate", "hash", "newSession", "push", "advance", "view", "finish", "checks" } do
			A.eq(type((F :: any)[name]), "function", name)
		end
	end)

	t.it("§16.22's constants as the prototype has them; Edges = the prototype's blades; Cost.X08_EDGE is the zigzag", function()
		local expected: { [string]: number } = {
			PT_PANEL_ASPECT = 3, PT_FIXED_POINT = 16384, PT_MARGIN_U = 0.15, PT_MARGIN_V = 0.12, PT_BLADE_REF_LEN = 4.5,
			PT_EXAG_MAX = 2, PT_EXAG_SHRINK = 0.9, PT_LEN_MARGIN = 0.95, PT_MAX_SOURCE_POINTS = 256,
			PT_SIMPLIFY_TOL = 0.004, PT_SIMPLIFY_STEPS = 8, PT_MIN_SOURCE_LEN = 0.4, PT_CHAIKIN_ITERS = 3, PT_DS = 0.01,
			PT_TAPER = 0.15, PT_CLEAR_SKIP = 0.30, PT_CLEAR_FRAC = 0.35, PT_CLEAR_CELL = 0.30, PT_EVAL_MS = 20,
			PT_SEARCH = 0.5, PT_BIN = 0.02, PT_VMAX_FACTOR = 6, PT_VMAX_MIN = 1.5, PT_MAX_GAP_MS = 250,
			PT_TRAVEL_MIN_MS = 6000, PT_TRAVEL_MAX_MS = 30000,
		}
		local renamed: { [string]: string } = { PANEL_ASPECT = "PANEL_W", FIXED_POINT = "Q" }
		for name, v in expected do
			A.eq((PT :: any)[name], v, name)
			local theirs = string.sub(name, 4)
			theirs = renamed[theirs] or theirs
			A.eq(Proto[theirs], v, "the prototype's " .. theirs)
		end
		local fb = PT.PT_FALLBACK_EDGE
		A.deepEq(fb.sides, Proto.FALLBACK_SIDES, "PT_FALLBACK_EDGE's sides")
		A.deepEq({ fb.gripPoint, fb.gripAxis } :: { any }, { { 0, 0, 0 }, { 0, 1 } } :: { any }, "and its grip")
		-- the fixture's literals are the doubles the prototype computes (the sabre's ^, the flamberge's sin and the
		-- tilted grip's sin and cos come from this machine's libm: a difference in those three names it)
		A.deepEq(Edges.order, Blades.ORDER, "the order")
		for _, key in ipairs(Edges.order) do
			local e: Edges.Edge, b = (Edges :: any)[key], Blades[key]
			A.eq(e.name, b.name)
			A.deepEq(e.chains, b.chains, key .. "'s chain")
			A.deepEq({ e.gripPoint, e.gripAxis } :: { any }, { b.grip, b.axis } :: { any }, key .. "'s grip")
		end
		A.truthy(Cost.X08_EDGE == Edges.zigzag, "X08's edge is the zigzag (one source)")
		local zz = Edges.zigzag.chains[1].points
		A.eq(#zz, 256)
		A.deepEq({ zz[1], zz[256] } :: { any }, { { 0.3, 1.48 }, { -0.3, 4.88 } } :: { any }, "±0.30 stud, y 1.48 → 4.88")
	end)

	t.it("T-MG-13 E-S3.5's golden: Edges.arming, seed 1, Iron/Normal, x = 0; the fallback; the tilted grip", function()
		local p = paramsOf("Iron", "Normal", 0)
		local e = Edges.arming
		local sides = PT.sidesFromChains(e.chains, e.gripPoint, e.gripAxis)
		A.eq(#sides, 2, "two sides")
		A.eq(#sides[1], 3, "side A: 3 points")
		A.eq(#sides[2], 4, "side B: 4 points")
		local source = sourceOf(e, p.pacerSpeed)
		A.deepEq(source, { 10912, 10158, 34996, 10158, 38240, 8389, 38142, 7799, 34996, 6226, 10912, 6226 },
			"the source exactly (the +X side has v > 0.5: down)")
		local P = PT.generate(1, p, source)
		A.eq(#P.pu, 337, "path points")
		printed(P.L, 3.3526, 4, "L")
		A.eq(P.travelMs, 11180, "travelMs")
		A.eq(P.durationMs, 12180, "durationMs")
		printed(P.speed, 0.2999, 4, "speed")
		A.eq(P.hash, 0xF0B5CD03, "hash")
		A.eq(PT.hash(P), P.hash)
		A.falsy(P.usedFallback)
		local fb = PT.generate(1, p, nil)
		A.eq(#fb.pu, 402, "fallback path points")
		printed(fb.L, 4.0083, 4, "fallback L")
		A.eq(fb.travelMs, 13380, "fallback travelMs")
		A.eq(fb.hash, 0x405C00EA, "fallback hash")
		A.truthy(fb.usedFallback)
		local given = PT.generate(1, p, PT.fallbackSource(p.pacerSpeed))
		A.deepEq({ given.pu, given.pv, given.hash } :: { any }, { fb.pu, fb.pv, fb.hash } :: { any },
			"the fallback plays fallbackSource's path")
		A.falsy(given.usedFallback, "handed in as a source, it is not a fallback")
		A.deepEq(sourceOf(Edges.tilted, p.pacerSpeed), source, "the grip tilted 30° gives the identical source")
	end)

	t.it("E-S3.5's blade table: sides, source points, E, Douglas–Peucker tolerance, path points, L, travel Normal / Hard", function()
		-- as cost.luau computes them: Iron/Normal x = 0.10 (seed 20 for the path) and Iron/Hard x = 0.30 (seed 1)
		local pN, pH = paramsOf("Iron", "Normal", 0.10), paramsOf("Iron", "Hard", 0.30)
		local rows: { { any } } = {
			-- name, chain points, studs, sides, source points, E, tolerance, path points, L, travel N, travel H (s)
			{ "arming", 6, 5.60, 2, 6, 2.00, 0, 337, 3.359, 11.0, 10.3 },
			{ "longsword", 5, 7.27, 2, 5, 2.00, 0, 431, 4.293, 14.1, 13.0 },
			{ "dagger", 5, 3.06, 2, 5, 2.00, 0, 185, 1.835, 6.0, 6.0 },
			{ "sabre", 18, 3.48, 1, 18, 2.00, 0, 215, 2.140, 7.0, 6.6 },
			{ "flamberge", 123, 8.36, 2, 123, 2.00, 0, 574, 5.703, 18.7, 17.4 },
			{ "tilted", 6, 5.60, 2, 6, 2.00, 0, 337, 3.359, 11.0, 10.3 },
			{ "serrated", 71, 10.34, 2, 71, 1.62, 0, 595, 5.900, 19.4, 18.9 },
			{ "saw", 139, 22.28, 2, 5, 1.00, 0.128, 447, 4.462, 14.7, 13.6 },
			{ "zigzag", 256, 153.04, 1, 2, 1.00, 0.512, 209, 2.073, 6.8, 6.3 },
		}
		A.eq(#rows, #Edges.order)
		for i, r in ipairs(rows) do
			local key = r[1]
			A.eq(Edges.order[i], key)
			local e: Edges.Edge = (Edges :: any)[key]
			A.eq(#e.chains[1].points, r[2], key .. " chain points")
			printed(e.chains[1].length, r[3], 2, key .. " chain studs")
			local sides = PT.sidesFromChains(e.chains, e.gripPoint, e.gripAxis)
			A.eq(#sides, r[4], key .. " sides")
			local source, info = PT.edgeToPanelInfo(sides, e.gripPoint, e.gripAxis, pN.pacerSpeed)
			if source == nil then
				return A.fail(key .. ": no source")
			end
			A.eq(#source / 2, r[5], key .. " source points")
			printed(info.E :: number, r[6], 2, key .. " E")
			printed(info.tol :: number, r[7], 3, key .. " tolerance")
			local P = PT.generate(20, pN, source)
			A.eq(#P.pu, r[8], key .. " path points")
			printed(P.L, r[9], 3, key .. " L")
			printed(P.travelMs / 1000, r[10], 1, key .. " travel Normal")
			printed(PT.generate(1, pH, sourceOf(e, pH.pacerSpeed)).travelMs / 1000, r[11], 1, key .. " travel Hard")
			A.falsy(P.usedFallback, key .. " plays its own edge")
		end
	end)

	t.it("the edge hand-off: one side, degenerate chains, the travel bound, Douglas–Peucker's doubling tolerance", function()
		local g, axis = { 0, 0.88, 0 }, { 0, 1 }
		local function chain(points: { { number } }): { Types.EdgeChain }
			return { { points = points, length = 0 } }
		end
		-- the split: at the first point farthest along the axis; a side under 2 points is dropped
		A.deepEq(PT.sidesFromChains(nil, g, axis), {}, "no chains")
		A.deepEq(PT.sidesFromChains({}, g, axis), {}, "an empty list")
		A.deepEq(PT.sidesFromChains(chain({ { 0, 2 } }), g, axis), {}, "one point")
		A.deepEq(PT.sidesFromChains(chain({ { 0, 1 }, { 0, 3 } }), g, axis), { { { 0, 1 }, { 0, 3 } } },
			"a base → tip chain: side A alone")
		A.deepEq(PT.sidesFromChains(chain({ { 0, 3 }, { 0, 1 } }), g, axis), { { { 0, 1 }, { 0, 3 } } },
			"a tip → base chain: side B alone, base → tip")
		A.deepEq(PT.sidesFromChains(chain({ { 0.1, 1 }, { 0.1, 3 }, { -0.1, 3 }, { -0.1, 1 } }), g, axis),
			{ { { 0.1, 1 }, { 0.1, 3 } }, { { -0.1, 1 }, { -0.1, 3 }, { 0.1, 3 } } }, "a tie: the first maximum splits")
		-- no source: no sides, flat, a zero-length chain, too short, too long for 8 attempts
		local function reason(sides: { { Types.Vec2 } }, speed: number): string?
			local s, i = PT.edgeToPanelInfo(sides, g, axis, speed)
			A.eq(s, nil, "no source")
			return i.reason
		end
		A.eq(reason({}, 0.3), "noSides")
		A.eq(reason({ { { -0.2, 2 }, { 0.2, 2 } } }, 0.3), "flat", "across the axis")
		A.eq(reason({ { { 0, 2 }, { 0, 2 } } }, 0.3), "flat", "zero length")
		A.eq(reason({ { { 0, 2 }, { 0, 2.5 } } }, 0.3), "short", "0.5 stud maps to 0.3 u")
		local sabre = PT.sidesFromChains(Edges.sabre.chains, g, axis)
		A.eq(reason(sabre, 0.05), "tooLong", "base to tip is over 2.07 u, the bound 1.43 u")
		A.eq(reason(sabre, 0.07), "tooLong", "the bound 2.00 u")
		-- the shrink, then the tolerance doubled per attempt: the saw at 6 attempts (0.004 · 2^5), the zigzag at 8
		local function fitted(e: Edges.Edge): PrecisionTrace.EdgeInfo
			local s, i = PT.edgeToPanelInfo(PT.sidesFromChains(e.chains, e.gripPoint, e.gripAxis), e.gripPoint, e.gripAxis,
				0.3045)
			A.truthy(s ~= nil, e.name)
			return i
		end
		local serrated, saw, zigzag = fitted(Edges.serrated), fitted(Edges.saw), fitted(Edges.zigzag)
		A.deepEq({ serrated.E, serrated.eSteps, serrated.steps, serrated.tol } :: { any }, { 2 * 0.9 * 0.9, 2, 0, 0 },
			"serrated: two shrink steps fit it")
		A.deepEq({ saw.E, saw.eSteps, saw.steps, saw.tol } :: { any }, { 1, 7, 6, 0.004 * 32 }, "saw")
		A.deepEq({ zigzag.E, zigzag.eSteps, zigzag.steps, zigzag.tol, zigzag.pts } :: { any }, { 1, 7, 8, 0.004 * 128, 2 },
			"zigzag")
		for _, i in { serrated, saw, zigzag } do
			A.truthy((i.len :: number) <= (i.maxLen :: number) and (i.pts :: number) <= PT.PT_MAX_SOURCE_POINTS,
				"within both bounds")
			A.eq(i.maxLen, 0.95 * 30 * 0.3045)
		end
		-- a blade 1 stud wide: the cross axis fills the usable 0.76 of the height (E < 2)
		local wide = PT.sidesFromChains(chain({ { 0.5, 1.48 }, { 0.5, 4 }, { 0, 5 }, { -0.5, 4 }, { -0.5, 1.48 } }), g, axis)
		local wideSource, wideInfo = PT.edgeToPanelInfo(wide, g, axis, 0.3)
		local scale = (3 - 2 * 0.15) / 4.5
		A.near((wideInfo.E :: number) * scale * 1.0, 1 - 2 * 0.12, 1e-12, "E · s · (cross range) = the usable height")
		A.deepEq({ wideInfo.eSteps, wideInfo.steps } :: { any }, { 0, 0 } :: { any }, "no shrink, no simplifying")
		local vs: { number } = {}
		for i = 2, #(wideSource :: { number }), 2 do
			table.insert(vs, (wideSource :: { number })[i])
		end
		A.deepEq({ math.min(table.unpack(vs)), math.max(table.unpack(vs)) } :: { any },
			{ math.round(0.12 * QF), math.round(0.88 * QF) } :: { any }, "v spans 0.12–0.88")
		-- 301 points that fit the length bound: still simplified, at the first tolerance, to at most 256
		local many: { { number } } = {}
		for i = 0, 149 do
			table.insert(many, { 0.2, 1.48 + 2.52 * i / 149 })
		end
		table.insert(many, { 0, 4.6 })
		for i = 149, 0, -1 do
			table.insert(many, { -0.2, 1.48 + 2.52 * i / 149 })
		end
		local manyInfo = select(2, PT.edgeToPanelInfo(PT.sidesFromChains(chain(many), g, axis), g, axis, 0.3))
		A.deepEq({ manyInfo.rawPts, manyInfo.steps, manyInfo.tol, manyInfo.pts } :: { any }, { 301, 1, 0.004, 5 } :: { any },
			"301 points: one Douglas–Peucker pass keeps the 5 corners")
		-- generate plays the fallback for a missing, one-point or too short source
		local p = paramsOf("Iron", "Normal", 0)
		local fb = PT.generate(1, p, nil)
		for _, s in { {}, { 8192, 8192 }, { 8192, 8192, 8192, 8192 }, { 8192, 8192, 8192 + 6553, 8192 } } :: { { number } } do
			A.deepEq(PT.generate(1, p, s), fb, "the fallback for " .. Dump.canonical(s))
		end
		A.falsy(PT.generate(1, p, { 8192, 8192, 8192 + 6554, 8192 }).usedFallback, "0.40002 u plays")
	end)

	-- the hand-off's Douglas–Peucker attempts share one split tree, where the prototype runs each anew (M4's fix round
	-- 1): the same points by construction, pinned here on the saw and the zigzag turned and on random chains, ties of
	-- collinear runs and repeated points included, at the MVP pacer speeds (Iron and Steel, Normal and Hard, x 0, 0.3
	-- and 1): PROP_N_FAST chains at the slowest and the fastest in the quick run, PROP_N at all 12 under t.slow (M4's L1
	-- share)
	local function dpParity(n: number, every: boolean)
		local speeds: { number } = {}
		for _, material: DT.MaterialId in MATERIALS do
			for _, tier: DT.TierId in { "Normal", "Hard" } :: { DT.TierId } do
				for _, x in { 0, 0.3, 1 } do
					table.insert(speeds, paramsOf(material, tier, x).pacerSpeed)
				end
			end
		end
		table.sort(speeds)
		if not every then
			speeds = { speeds[1], speeds[#speeds] }
		end
		local through = 0
		-- the two reference blades that reach it, turned 13° (their regular teeth make exact ties on the farthest point
		-- there: the first index must win), then random chains
		local function check(e: Edges.Edge)
			local sides = PT.sidesFromChains(e.chains, e.gripPoint, e.gripAxis)
			for _, speed in speeds do
				local ours, info = PT.edgeToPanelInfo(sides, e.gripPoint, e.gripAxis, speed)
				local theirs, theirInfo = Proto.edgeToPanel(sides, e.gripPoint, e.gripAxis, speed)
				deepEqFast(ours, theirs, "the source at pacerSpeed " .. speed)
				A.deepEq({ info.E, info.eSteps, info.steps, info.tol, info.reason } :: { any },
					{ theirInfo.E, theirInfo.eSteps, theirInfo.steps, theirInfo.tol, theirInfo.reason } :: { any },
					"E, its shrinks, the attempts, the tolerance, the reason at pacerSpeed " .. speed)
				-- through it: simplified, or refused after its last attempt
				if (info.steps or 0) > 0 or info.reason == "tooLong" then
					through += 1
				end
			end
		end
		check(turned(Edges.saw, 13 * math.pi / 180))
		check(turned(Edges.zigzag, 13 * math.pi / 180))
		Prop.check(n, dpEdge, check)
		A.truthy(through > 0, "hand-offs through Douglas–Peucker: " .. through)
	end
	t.it("the hand-off's Douglas–Peucker keeps the prototype's points on turned blades and random chains (slowest, fastest pacer)", function()
		dpParity(Tol.PROP_N_FAST, false)
	end)
	t.slow("the hand-off's Douglas–Peucker keeps the prototype's points on turned blades and random chains (PROP_N cases, 12 pacers)", function()
		dpParity(Tol.PROP_N, true)
	end)

	t.it("the worst source (a 256-point wave at the length bound) plays whole: E-S3.5's 860 points, L 8.564, 28.56 s", function()
		-- worst.luau's source: a sine across the usable panel, the largest amplitude (in 0.001 steps) whose length fits
		local p = paramsOf("Iron", "Normal", 0)
		local maxLen = PT.PT_LEN_MARGIN * PT.PT_TRAVEL_MAX_MS / 1000 * p.pacerSpeed
		local best: { number }? = nil
		for a10 = 1, 380 do
			local amp = a10 / 1000
			local us: { number }, vs: { number } = {}, {}
			local len = 0
			for i = 0, 255 do
				us[i + 1] = 0.15 + 2.7 * i / 255
				vs[i + 1] = 0.5 + amp * math.sin(2 * math.pi * 10 * i / 255)
				if i > 0 then
					local du, dv = us[i + 1] - us[i], vs[i + 1] - vs[i]
					len += math.sqrt(du * du + dv * dv)
				end
			end
			if len <= maxLen then
				local src: { number } = {}
				for i = 1, 256 do
					table.insert(src, math.round(us[i] * QF))
					table.insert(src, math.round(vs[i] * QF))
				end
				best = src
			end
		end
		local P = PT.generate(10, p, best)
		A.falsy(P.usedFallback)
		A.eq(#P.pu, 860, "path points")
		printed(P.L, 8.564, 3, "L")
		A.eq(P.travelMs, 28560, "travel under the clamp")
		A.eq(P.durationMs, 29560)
	end)

	t.it("nearest keeps the first minimum on a tie (D1): a U-shaped path, the cursor equidistant from three vertices", function()
		-- the bottom arm i = 1…11, the right arm 12…21, the top arm 22…31, 164/16384 apart; the cursor at the U's
		-- centre is 820/16384 from vertices 6, 16 and 26
		local pu: { number }, pv: { number } = {}, {}
		for i = 1, 11 do
			pu[i], pv[i] = (8192 + 164 * (i - 1)) / QF, 8192 / QF
		end
		for k = 1, 10 do
			pu[11 + k], pv[11 + k] = 9832 / QF, (8192 + 164 * k) / QF
			pu[21 + k], pv[21 + k] = (9832 - 164 * k) / QF, 9832 / QF
		end
		local arc = { 0 }
		for i = 2, #pu do
			arc[i] = arc[i - 1] + 164 / QF
		end
		local P = { p = paramsOf("Iron", "Normal", 0), pu = pu, pv = pv, arc = arc, L = arc[#arc], speed = 0.3,
			leadInMs = 600, travelMs = 8000, durationMs = 9000, usedFallback = false, hash = 0 } :: any
		local d, s = PT.nearest(P, 9012 / QF, 9012 / QF, arc[16])
		local pd, ps = Proto.nearest(P, 9012 / QF, 9012 / QF, arc[16])
		A.eq(d, 820 / QF, "the distance")
		A.eq(s, arc[6], "the first of the tied vertices, on the bottom arm")
		A.eq(d, pd, "the prototype's distance")
		A.eq(s, ps, "the prototype's arc")
	end)

	t.it("the coverage speed gate has its floor PT_VMAX_MIN: a slow pacer's path still covers at 1 u/s", function()
		-- a path whose pacer runs at 0.125 u/s (6 × 0.125 = 0.75 < PT_VMAX_MIN 1.5, as on a short path held to 6 s);
		-- the cursor grinds on the line at 1 u/s ahead of the pacer, inside the search window
		local P = table.clone(straight()) :: any
		P.travelMs, P.durationMs = 16000, 17000
		P.speed = P.L / 16
		local samples: { TraceRecord } = {}
		for k = 0, 20 do
			local u = math.round((P.pu[1] + 0.02 * k) * QF)
			table.insert(samples, { t = P.leadInMs + 20 * k, u = u, v = 8192, grind = true })
		end
		local _, _, S = replay(P, samples)
		A.eq(math.max(PT.PT_VMAX_FACTOR * P.speed, PT.PT_VMAX_MIN), PT.PT_VMAX_MIN, "the floor is the gate here")
		A.truthy(S.nCovered >= 10, "1 u/s is under the gate's floor: covered " .. S.nCovered) -- 14 bins; 1 at 6 × speed
	end)

	t.it("a source's consecutive duplicate points are dropped on load: the pattern of the source without them", function()
		local p = paramsOf("Iron", "Normal", 0)
		local source = sourceOf(Edges.arming, p.pacerSpeed) :: { number }
		local doubled: { number } = {}
		for i = 1, #source, 2 do
			table.insert(doubled, source[i])
			table.insert(doubled, source[i + 1])
			if i == 5 then -- the third point twice
				table.insert(doubled, source[i])
				table.insert(doubled, source[i + 1])
			end
		end
		A.eq(#doubled, #source + 2)
		A.eq(PT.generate(1, p, doubled).hash, PT.generate(1, p, source).hash, "the same pattern")
	end)

	t.it("the travel clamp: a short path plays 6 s, a source past the bound 30 s; the path stays in the panel", function()
		local p = paramsOf("Iron", "Normal", 0)
		-- a 0.5 u line: about 1.7 s at pacerSpeed, slowed to the 6 s floor
		local short = PT.generate(3, p, { 16384, 8192, 16384 + 8192, 8192 })
		A.eq(short.travelMs, 6000)
		A.eq(short.speed, short.L / 6, "the pacer slows to cover L in 6 s")
		-- a 30-point zigzag across the panel handed straight to generate (the hand-off never makes one): 30 s, faster
		local long: { number } = {}
		for i = 0, 29 do
			table.insert(long, math.round((0.2 + 2.6 * i / 29) * QF))
			table.insert(long, if i % 2 == 0 then math.round(0.1 * QF) else math.round(0.9 * QF))
		end
		local P = PT.generate(3, p, long)
		A.eq(P.travelMs, 30000)
		A.truthy(P.L > 0.3 * 30 and P.speed > p.pacerSpeed, "faster than pacerSpeed")
		for _, Q in { short, P, PT.generate(3, p, nil) } do
			for i = 1, #Q.pu do
				-- the panel's clamp [0.05, 2.95] × [0.05, 0.95], quantized
				A.within(Q.pu[i] * QF, 819, 48333, "u in the panel")
				A.within(Q.pv[i] * QF, 819, 15565, "v in the panel")
				A.eq(Q.pu[i] * QF, math.round(Q.pu[i] * QF), "quantized")
				A.truthy(i == 1 or Q.arc[i] > Q.arc[i - 1], "arc increasing")
			end
			A.eq(Q.L, Q.arc[#Q.arc])
			A.eq(Q.durationMs, Q.leadInMs + Q.travelMs + p.tailMs)
			A.eq(Q.leadInMs, p.leadInMs)
			A.eq(Q.travelMs % 20, 0, "travel in whole ticks")
		end
	end)

	t.it("ticks on a straight path: accuracy at the core and the band's edge, pace, the 250 ms gap, tick 1's cursor", function()
		local P = straight()
		local K = math.floor(P.travelMs / PT.PT_EVAL_MS)
		local k = 200 -- mid-path
		local function credit(dk: number, grind: boolean): number?
			return PT.view(sessionAt(P, { atTick(P, k, 0, dk, grind) }, k), tickT(P, k)).credit
		end
		A.eq(PT.view(PT.newSession(P), 0).credit, nil, "nil before the first tick")
		A.eq(credit(0, true), 1, "on the line")
		A.eq(credit(128, true), 1, "at the core's edge (128/16384)")
		A.eq(credit(-128, true), 1, "either side")
		A.eq(credit(129, true), 1 - (1 / 16384) / (896 / 16384), "one step past the core")
		A.eq(credit(1024, true), 0, "at halfWidth: 0 credit, still on the band")
		A.eq(credit(1025, true), 0, "off the band")
		A.eq(credit(0, false), 0, "not grinding")
		-- on the band at its edge pace still counts; past it nothing does
		local onEdge = sessionAt(P, { atTick(P, k, 0, 1024, true) }, k)
		local offEdge = sessionAt(P, { atTick(P, k, 0, 1025, true) }, k)
		A.deepEq({ onEdge.accSum, onEdge.paceSum } :: { any }, { 0, 1 } :: { any }, "d = w: pace 1")
		A.deepEq({ offEdge.accSum, offEdge.paceSum } :: { any }, { 0, 0 } :: { any }, "d > w: nothing")
		-- pace: 1 within paceTol 0.12 of the pacer, down to 0 over paceFall 0.24 (cursors quantized: ±1/32768)
		for _, c in { { 0, 1 }, { 0.1, 1 }, { -0.1, 1 }, { 0.24, 0.5 }, { -0.24, 0.5 }, { 0.3, 0.25 }, { 0.37, 0 } } do
			local S = sessionAt(P, { atTick(P, k, c[1], 0, true) }, k)
			A.near(S.paceSum, c[2], 1e-3, "pace at a lag of " .. c[1])
			A.eq(S.accSum, 1, "on the line")
		end
		-- the 250 ms gap: between samples up to 250 ms apart the cursor moves and grinds; over it, it holds, not grinding
		local function mid(gap: number): number?
			local a = atTick(P, k, 0, 0, true)
			local tb = a.t + gap
			local b = { t = tb, u = math.round((P.pu[1] + PT.pacerArc(P, tb)) * QF), v = 8192, grind = true }
			return PT.view(sessionAt(P, { a, b }, k + 6), tickT(P, k + 6)).credit
		end
		A.eq(mid(240), 1, "lerp, grinding")
		A.eq(mid(250), 1, "250 ms is no gap")
		A.eq(mid(251), 0, "held, not grinding")
		-- after the last sample the cursor holds and grinds for PT_MAX_GAP_MS: a sample 10 ms before tick k grinds at
		-- ticks k … k + 12 (10 … 250 ms after it), not at k + 13 (270)
		local last = atTick(P, k, 0, 0, true)
		local _, _, held = replay(P, { { t = last.t - 10, u = last.u, v = last.v, grind = true } })
		A.eq(held.accSum, 13, "13 ticks within 250 ms of the sample")
		A.eq(held.k, K + 1, "finish evaluates every tick")
		-- tick 1's speed gate reads the cursor at leadInMs: a sample at GO lets tick 1 cover its bin
		local early = atTick(P, 1, 0, 0, true)
		A.eq(sessionAt(P, { sample(0, P.pu[1], 0.5, true), early }, 1).nCovered, 1, "a cursor at t_1 − 20")
		A.eq(sessionAt(P, { early }, 1).nCovered, 0, "no cursor before tick 1: no coverage")
	end)

	t.it("coverage on a straight path: the pacer covers every bin; scribbling past the speed gate covers none", function()
		local P = straight()
		local nBins = math.ceil(P.L / PT.PT_BIN)
		local perfect, flags, S = replay(P, onPacer(P, 20, 0))
		A.eq(S.nCovered, nBins, "every bin")
		A.deepEq({ perfect.score, perfect.breakdown.accuracy, perfect.breakdown.pacing, perfect.breakdown.coverage },
			{ 1, 1, 1, 1 }, "on the pacer every 20 ms: 1")
		A.deepEq(flags, { "PtTooPrecise", "PtTooSmooth" }, "and flagged")
		-- ±0.1 u about the pacer at alternate ticks: within paceTol and on the line, but 10 u/s > the 1.5 u/s gate
		local scribble: { TraceRecord } = {}
		for k = 0, math.floor(P.travelMs / 20) do
			table.insert(scribble, atTick(P, k, if k % 2 == 0 then 0.1 else -0.1, 0, true))
		end
		local r = replay(P, scribble)
		A.eq(r.breakdown.coverage, 0, "no bin covered")
		A.eq(r.breakdown.accuracy, 1)
		A.eq(r.score, 0, "coverage multiplies the score")
		-- nothing, or never grinding: 0
		for _, samples in { {}, onPacer(P, 20, 0) } :: { { TraceRecord } } do
			local lifted: { TraceRecord } = {}
			for _, x in ipairs(samples) do
				table.insert(lifted, { t = x.t, u = x.u, v = x.v, grind = false })
			end
			local idle = replay(P, lifted)
			A.deepEq({ idle.score, idle.breakdown.accuracy, idle.breakdown.pacing, idle.breakdown.coverage }, { 0, 0, 0, 0 })
		end
	end)

	t.it("checks at their thresholds: PtSparse, PtTeleport, PtTooPrecise, PtTooSmooth with its dt bounds 9 / 10 / 40 / 41", function()
		local P = straight()
		local function flags(samples: { TraceRecord }): { FlagId }
			local _, f = replay(P, samples)
			return f
		end
		local function has(samples: { TraceRecord }, flag: FlagId): boolean
			return table.find(flags(samples), flag) ~= nil
		end
		-- PtSparse: samples in travel < 0.5 · 8000/20 = 200 (strict); travel is [600, 8600]
		local every40 = onPacer(P, 40, 0.01) -- 0.01 u off the line, not too precise; t = 600, 640, … 8600 in travel
		A.eq(PT.measures(P, every40).inTravel, 201)
		A.falsy(has(every40, "PtSparse"), "201")
		local fewer = table.clone(every40)
		table.remove(fewer, 30)
		A.falsy(has(fewer, "PtSparse"), "200 is not below 200")
		table.remove(fewer, 40)
		A.truthy(has(fewer, "PtSparse"), "199")
		A.deepEq(flags(onPacer(P, 200, 0.01)), { "PtSparse" }, "41 in travel: sparse and nothing else")
		-- PtTeleport: ≥ 3 grinding steps over 0.25 u (strict) within ≤ 40 ms; n jumps out, each back 200 ms later
		local function jumps(n: number, du: number, dt: number): { TraceRecord }
			local out: { TraceRecord } = {}
			local tNow = 600
			for _ = 1, n do
				table.insert(out, { t = tNow, u = 8192, v = 8192, grind = true })
				table.insert(out, { t = tNow + dt, u = 8192 + du, v = 8192, grind = true })
				tNow += dt + 200
			end
			return out
		end
		A.eq(Checks.value("PrecisionTrace", "PT_TELEPORT_DIST"), 0.25)
		A.truthy(has(jumps(3, 4097, 40), "PtTeleport"), "3 jumps of 4097/16384 u in 40 ms")
		A.falsy(has(jumps(2, 4097, 40), "PtTeleport"), "2 jumps")
		A.falsy(has(jumps(3, 4096, 40), "PtTeleport"), "0.25 u is not over 0.25")
		A.falsy(has(jumps(3, 4097, 41), "PtTeleport"), "41 ms")
		A.eq(PT.measures(P, jumps(3, 4097, 40)).teleports, 3, "returns 200 ms later are no jumps")
		local lifted = jumps(3, 4097, 40)
		lifted[3] = { t = lifted[3].t, u = lifted[3].u, v = lifted[3].v, grind = false }
		A.eq(PT.measures(P, lifted).teleports, 2, "a jump from a lifted sample does not count")
		-- PtTooPrecise: ≥ 40 grinding samples in travel, mean distance < 0.0008 (13/16384 under, 14/16384 over)
		local function steady(n: number, dk: number, grind: boolean): { TraceRecord }
			local out: { TraceRecord } = {}
			for i = 1, n do
				table.insert(out, atTick(P, 10 * i, 0, dk, grind))
			end
			return out
		end
		A.truthy(has(steady(40, 13, true), "PtTooPrecise"), "40 samples 0.00079 u off")
		A.falsy(has(steady(39, 13, true), "PtTooPrecise"), "39 samples")
		A.falsy(has(steady(40, 14, true), "PtTooPrecise"), "0.00085 u off")
		A.falsy(has(steady(40, 0, false), "PtTooPrecise"), "not grinding")
		A.eq(PT.measures(P, steady(40, 13, true)).meanDev, 13 / 16384)
		-- PtTooSmooth: ≥ 150 moving triplets (both neighbours grinding, outer span > 0.002 u, both dt in [10, 40]) with
		-- mean |Δ²p| < 0.0002: v alternating by k/16384 gives |Δ²p| = 2k/16384 (k = 1: 0.00012; k = 2: 0.00024)
		local function wave(n: number, dt: number, k: number): { TraceRecord }
			local out: { TraceRecord } = {}
			for i = 0, n - 1 do
				table.insert(out, { t = 600 + i * dt, u = 8192 + 20 * i, v = 8192 + (if i % 2 == 0 then 0 else k), grind = true })
			end
			return out
		end
		A.truthy(has(wave(152, 20, 1), "PtTooSmooth"), "150 triplets")
		A.falsy(has(wave(151, 20, 1), "PtTooSmooth"), "149 triplets")
		A.falsy(has(wave(152, 20, 2), "PtTooSmooth"), "|Δ²p| 0.00024")
		A.eq(PT.measures(P, wave(152, 20, 1)).meanJerk, 2 / 16384)
		for _, c in { { 9, false }, { 10, true }, { 40, true }, { 41, false } } :: { { any } } do
			local s = wave(152, c[1], 1)
			A.eq(has(s, "PtTooSmooth"), c[2], "dt " .. c[1] .. " ms")
			A.eq(PT.measures(P, s).jerkN, if c[2] then 150 else 0, "triplets at dt " .. c[1])
		end
		local still: { TraceRecord } = {}
		for i = 0, 200 do
			table.insert(still, { t = 600 + 20 * i, u = 8192 + (if i % 2 == 0 then 0 else 16), v = 8192, grind = true })
		end
		A.eq(PT.measures(P, still).jerkN, 0, "an outer span of 0 u is not moving")
		-- all four, in byte order: 160 samples on the pacer, v alternating by 1/16384, then three 0.26 u hops along
		-- the path 5 ms apart (jumps that are neither imprecise nor in a timed triplet)
		local all: { TraceRecord } = {}
		for i = 0, 159 do
			table.insert(all, { t = 600 + 20 * i, u = 8192 + 82 * i, v = 8192 + (if i % 2 == 0 then 0 else 1), grind = true })
		end
		local last = all[#all]
		for i = 1, 3 do
			table.insert(all, { t = last.t + 5 * i, u = last.u + (if i % 2 == 1 then 4260 else 0), v = 8192, grind = true })
		end
		local m = PT.measures(P, all)
		A.deepEq({ m.inTravel, m.teleports, m.jerkN } :: { any }, { 163, 3, 158 } :: { any })
		A.deepEq(flags(all), { "PtSparse", "PtTeleport", "PtTooPrecise", "PtTooSmooth" }, "byte order")
	end)

	t.it("the view: the pacer on the raw clock, the cursor from the latest sample, credit, covered runs, the live score", function()
		local P = straight()
		local S = PT.newSession(P)
		local before = PT.view(S, -3000)
		A.deepEq({ before.pacerArc, before.pacerU, before.pacerV } :: { any }, { 0, 0.5, 0.5 } :: { any }, "at the start")
		A.eq(before.cursorArc, nil)
		A.eq(before.distance, nil)
		A.eq(before.paceLag, nil)
		A.eq(before.credit, nil)
		A.deepEq({ before.onPath, before.grinding, before.accuracySoFar, before.coverage, before.runningScore } :: { any },
			{ false, false, 0, 0, 0 } :: { any }, "nothing yet")
		A.deepEq(before.coveredRuns, {})
		A.eq(before.timeLeftMs, P.durationMs + 3000)
		-- on the pacer for ticks 0–100, ahead by 0.05 u at 101–150, off the band at 151–200
		local function script(k: number): TraceRecord
			return atTick(P, k, if k > 100 and k <= 150 then 0.05 else 0, if k > 150 then 2000 else 0, true)
		end
		for k = 0, 200 do
			PT.push(S, script(k))
		end
		PT.advance(S, tickT(P, 200))
		local v = PT.view(S, tickT(P, 200))
		A.eq(v.pacerArc, PT.pacerArc(P, tickT(P, 200)))
		A.falsy(v.onPath, "off the band")
		A.truthy(v.grinding)
		A.eq(v.paceLag, nil, "no lag off the band")
		A.near(v.distance :: number, 2000 / 16384, 1e-12)
		A.eq(v.credit, 0)
		A.eq(v.accuracySoFar, S.accSum / 200)
		A.eq(v.coverage, S.nCovered / S.nBins)
		-- the runs decode to the covered bins, maximal and in order
		local runs = v.coveredRuns
		A.eq(#runs % 2, 0)
		A.truthy(#runs >= 4, "at least two runs")
		local fromRuns: { boolean } = table.create(S.nBins, false)
		for i = 1, #runs, 2 do
			A.truthy(runs[i] <= runs[i + 1] and (i == 1 or runs[i] > runs[i - 1] + 1), "maximal runs, in order")
			for b = runs[i], runs[i + 1] do
				fromRuns[b] = true
			end
		end
		A.deepEq(fromRuns, S.covered, "the runs are the covered bins")
		-- back on the band, ahead: paceLag > 0
		local ahead = PT.view(sessionAt(P, { atTick(P, 120, 0.05, 0, true) }, 120), tickT(P, 120))
		A.truthy(ahead.onPath and (ahead.paceLag :: number) > 0.04, "ahead of the pacer")
		A.near(ahead.cursorArc :: number, PT.pacerArc(P, tickT(P, 120)) + 0.05, 1e-4)
		-- the live score is the score's formula on the ticks so far, coverage over the bins the pacer passed (O14) …
		local n = 200
		local passed = math.ceil(PT.pacerArc(P, tickT(P, n)) / PT.PT_BIN)
		local w = P.p.wAccuracy
		local Am, Pm = S.accSum / n, S.paceSum / n
		A.eq(v.runningScore, math.round(math.min(1, S.nCovered / passed) * (w * Am + (1 - w) * Pm) * 10000) / 10000,
			"q(C·(w·A + (1 − w)·P)) so far")
		-- … and the score once every tick is in
		local result = PT.finish(S)
		A.eq(PT.view(S, P.durationMs).runningScore, result.score, "at the end the live score is the score")
		A.eq(PT.view(S, P.durationMs + 500).timeLeftMs, 0)
		-- views change nothing
		local again = PT.newSession(P)
		for k = 0, 200 do
			PT.push(again, script(k))
			PT.view(again, tickT(P, k) + 7)
		end
		A.deepEq(PT.finish(again), result, "a view at any time leaves the result alone")
	end)

	t.it("feedback: GrindStart / Stop, OnPath / OffPath, PaceWarn ±1, Coverage by quarters, End once; else one frozen array", function()
		local P = straight()
		local S = PT.newSession(P)
		local idle = PT.advance(S, 5000)
		A.eq(#idle, 0)
		A.truthy(table.isfrozen(idle), "frozen")
		A.truthy(PT.advance(S, 6000) == idle, "the same array every time (D13)")
		A.eq(kinds(PT.push(S, atTick(P, 0, 0, 0, false))), "", "not grinding before the first sample")
		A.deepEq(PT.push(S, atTick(P, 1, 0, 0, true)), { { kind = "GrindStart", t = tickT(P, 1) } })
		A.truthy(PT.push(S, atTick(P, 2, 0, 0, true)) == idle, "no change: the shared array")
		A.eq(kinds(PT.advance(S, tickT(P, 2))), "OnPath", "the first grinding tick on the band")
		A.deepEq(PT.push(S, atTick(P, 3, 0, 0, false)), { { kind = "GrindStop", t = tickT(P, 3) } })
		A.eq(kinds(PT.advance(S, tickT(P, 3))), "", "a lifted tick changes nothing")
		A.eq(kinds(PT.push(S, atTick(P, 4, 0, 2000, true))), "GrindStart")
		A.eq(kinds(PT.advance(S, tickT(P, 4))), "OffPath")
		-- back on the pacer, then 0.2 u ahead (a warning, once), back within paceTol, then 0.2 u behind (again)
		local events: { string } = {}
		local function step(k: number, ds: number)
			PT.push(S, atTick(P, k, ds, 0, true))
			local e = kinds(PT.advance(S, tickT(P, k)))
			if e ~= "" then
				table.insert(events, k .. ": " .. e)
			end
		end
		for k = 5, 39 do
			step(k, 0)
		end
		step(40, 0.2)
		step(41, 0.2)
		step(42, 0)
		step(43, -0.2)
		step(44, 0)
		A.deepEq(events, { "5: OnPath", "40: PaceWarn(1)", "43: PaceWarn(-1)" }, "ahead, back, behind")
		-- on the pacer from GO: Coverage at each quarter of the bins as it is reached, then End after the last tick
		local K = math.floor(P.travelMs / 20)
		local B = PT.newSession(P)
		local seen: { string } = {}
		for k = 0, K do
			local before = B.nCovered
			for _, e in ipairs(PT.push(B, atTick(P, k, 0, 0, true))) do
				table.insert(seen, kinds({ e }))
			end
			for _, e in ipairs(PT.advance(B, tickT(P, k))) do
				table.insert(seen, kinds({ e }))
				if e.kind == "Coverage" then
					local q = (e.value :: number) / 25
					A.truthy(before * 4 < q * B.nBins and B.nCovered * 4 >= q * B.nBins, "at the tick it is reached")
				elseif e.kind == "End" then
					A.eq(e.t, P.leadInMs + P.travelMs)
					A.eq(k, K, "after the last tick")
				end
			end
		end
		A.deepEq(seen, { "GrindStart", "OnPath", "Coverage(25)", "Coverage(50)", "Coverage(75)", "Coverage(100)", "End" }
			:: { string }, "each once, in order")
		A.eq(#PT.advance(B, P.durationMs + 1), 0, "End only once")
		A.eq(PT.finish(B).breakdown.coverage, 1)
	end)

	sized(t, "live = replay: pushing samples and advancing to any times, even past the latest sample, finishes alike", function(n: number)
		Prop.check(n, function(rng: TestRng.TestRng): { any }
			local material: DT.MaterialId = MATERIALS[rng:int(1, 2)]
			local tier: DT.TierId = if rng:int(1, 2) == 1 then "Normal" else "Hard"
			local p = paramsOf(material, tier, rng:float())
			local P = PT.generate(rng:u32(), p, if rng:int(1, 4) > 1 then sourceOf(randomEdge(rng), p.pacerSpeed) else nil)
			return { P = P, samples = humanSamples(rng, P), salt = rng:u32() }
		end, function(c: any)
			local P: Pattern = c.P
			local rng = TestRng.new(c.salt)
			local whole = replay(P, c.samples)
			local S = PT.newSession(P)
			for _, r in ipairs(c.samples) do
				PT.push(S, r)
				if rng:int(1, 3) == 1 then
					local now = r.t + rng:int(-40, 400)
					PT.advance(S, now)
					PT.view(S, now)
				end
			end
			A.deepEq(PT.finish(S), whole, "live session = replay")
		end)
	end)

	sized(t, "PrecisionTrace = the S3 prototype's edge mapping, generate, replay and checks, bit for bit (D1)", function(n: number)
		Prop.check(n, function(rng: TestRng.TestRng): { any }
			local material: DT.MaterialId = MATERIALS[rng:int(1, 2)]
			local tier: DT.TierId = TIERS[rng:int(1, #TIERS)]
			local p = paramsOf(material, tier, rng:range(-0.2, 1.2))
			-- a reference edge (turned now and then), none (the fallback) or a raw source: a random walk anywhere in
			-- the panel, its length bounded as the hand-off bounds a source's
			local pick = rng:int(1, 6)
			local raw: { number }? = nil
			if pick == 6 then
				local s: { number } = {}
				local u, v = rng:range(0, 3), rng:range(0, 1)
				for _ = 1, rng:int(1, 12) do
					table.insert(s, math.round(u * QF))
					table.insert(s, math.round(v * QF))
					u = math.clamp(u + rng:range(-0.4, 0.4), 0, 3)
					v = math.clamp(v + rng:range(-0.3, 0.3), 0, 1)
				end
				raw = s
			end
			return { p = p, seed = rng:u32(), edge = if pick <= 4 then randomEdge(rng) else nil, raw = raw, salt = rng:u32() }
		end, function(c: any)
			local source: { number }? = c.raw
			local e: Edges.Edge? = c.edge
			if e then
				local sides = PT.sidesFromChains(e.chains, e.gripPoint, e.gripAxis)
				A.deepEq(sides, Proto.sidesFromChains(e.chains, e.gripPoint, e.gripAxis), "sides")
				local ours, info = PT.edgeToPanelInfo(sides, e.gripPoint, e.gripAxis, c.p.pacerSpeed)
				local theirs, theirInfo = Proto.edgeToPanel(sides, e.gripPoint, e.gripAxis, c.p.pacerSpeed)
				A.deepEq(ours, theirs, "the source")
				A.deepEq({ info.E, info.tol, info.reason } :: { any }, { theirInfo.E, theirInfo.tol, theirInfo.reason } :: { any },
					"E, tolerance, reason")
				source = ours
			end
			local P = PT.generate(c.seed, c.p, source)
			local Q = Proto.generate(c.seed, c.p, source)
			deepEqFast({ P.pu, P.pv, P.arc } :: { any }, { Q.pu, Q.pv, Q.arc } :: { any }, "the path")
			A.deepEq({ P.L, P.speed, P.leadInMs, P.travelMs, P.durationMs, P.usedFallback, P.hash } :: { any },
				{ Q.L, Q.speed, Q.leadInMs, Q.travelMs, Q.durationMs, Q.usedFallback, Q.hash } :: { any },
				"L, speed, leadInMs, travelMs, durationMs, usedFallback, hash")
			local samples = humanSamples(TestRng.new(c.salt), P)
			local result, flags, S = replay(P, samples)
			local s = Proto.newSession(Q)
			for _, r in ipairs(samples) do
				Proto.push(s, r)
			end
			local theirs = Proto.finish(s)
			A.deepEq({ S.accSum, S.paceSum, S.nCovered, S.nBins, S.K } :: { any },
				{ s.accSum, s.paceSum, s.nCovered, s.nBins, s.K } :: { any }, "the unquantized session sums")
			A.eq(result.score, theirs.score, "score")
			A.deepEq({ result.breakdown.accuracy, result.breakdown.pacing, result.breakdown.coverage } :: { any },
				{ theirs.accuracy, theirs.pacing, theirs.coverage } :: { any }, "accuracy, pacing, coverage")
			local theirFlags, theirMeasures = Proto.checks(Q, samples)
			local mapped: { FlagId } = {}
			for _, f in ipairs(theirFlags) do
				table.insert(mapped, PROTO_FLAG[f])
			end
			A.deepEq(flags, mapped, "flags")
			local m = PT.measures(P, samples)
			A.deepEq({ m.meanDev, m.devN, m.meanJerk, m.jerkN, m.teleports } :: { any }, { theirMeasures.meanDev,
				theirMeasures.devN, theirMeasures.meanJerk, theirMeasures.jerkN, theirMeasures.teleports } :: { any },
				"the check measures")
		end)
		-- the hash covers the path, not the scoring knobs (§6.4 rule 5)
		local p = table.clone(paramsOf("Iron", "Normal", 0))
		local source = sourceOf(Edges.arming, p.pacerSpeed)
		local h = PT.generate(1, p, source).hash
		p.halfWidth += 0.01
		A.eq(PT.generate(1, p, source).hash, h, "halfWidth does not move the hash")
		p.perturbAmp += 0.001
		A.truthy(PT.generate(1, p, source).hash ~= h, "perturbAmp does")
	end)
end)
