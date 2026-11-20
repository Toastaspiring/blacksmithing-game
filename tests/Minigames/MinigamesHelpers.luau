--!strict
-- tests/Minigames/MinigamesHelpers.luau — shared by the Minigames specs (not a spec: discovery reads *.spec.luau only).
-- Step inputs as S5 builds them, scripted timelines (TimingStrike presses, HoldZone strokes, trace samples), random
-- honest record sets, and a step played through the Recorder as S6's host plays it; the configurations every T-MG
-- case walks (M4's plan [6.3]).
--
--   stepInputFrom(analysis, i, seed)   §4.8's Pipeline.stepInput (M5's): step i of Analyze.run's output, Sharpening's
--                                 edge as the narrow { chains, gripPoint, gripAxis } table (G13); typed from Analyze's
--                                 exports, so luau-lsp checks Minigames/Types' copies of S2's types against S2's (D5)
--   inputFor(family, material, tier, x, seed, edge?)   a PrepareInput at the reference design x (Params.refFactors)
--   prepared(family, material, tier, x, seed, edge?)   Minigames.prepare of it: (spec, pattern)
--   presses(P, errs)              TimingStrike: a press at T_i + errs[i] per cycle (false: none), in time order
--   taps(durationMs, periodMs, holdMs, startMs?)   HoldZone: a down every periodMs from startMs, each held holdMs
--   onPacer(P, everyMs, grind?)   PrecisionTrace: samples on the pacer from GO every everyMs, quantized to the panel
--   randomRecords(rng, family, P) honest records of any pace: alternating HoldZone states, TimingStrike presses near
--                                 the targets with strays, trace samples near the pacer at increasing times
--   frames(rng, endMs, lo, hi, hitchMs)   frame times from GO: a random phase, a step in [lo, hi] ± 1 ms, hitches
--   play(spec, pattern, opts)     the step through a Recorder at those frames, as S6's host plays it (§12.5, D4)
--   configSalt(name)              a statistical configuration's salt, fnv1a32 of its pinned name (§14.8, M4's D11)
--   ES32["<family> <material>/<tier>"][profile]   E-S3.2's { mean, sd } per cell, as printed (3 decimals; T-MG-04)

local Dump = require("../lib/Dump")
local TestRng = require("../lib/TestRng")
local Edges = require("../fixtures/Edges")
local DT = require("../../src/shared/Definitions/Types")
local MinigameFamilies = require("../../src/shared/Definitions/MinigameFamilies")
local Steps = require("../../src/shared/Definitions/Steps")
local Versions = require("../../src/shared/Definitions/Versions")
local Input = require("../../src/shared/Minigames/Input")
local Minigames = require("../../src/shared/Minigames/Minigames")
local Params = require("../../src/shared/Minigames/Params")
local PrecisionTrace = require("../../src/shared/Minigames/PrecisionTrace")
local TimingStrike = require("../../src/shared/Minigames/TimingStrike")
local Types = require("../../src/shared/Minigames/Types")
local Analyze = require("../../src/shared/Physics/Analyze")

type HoldRecord = Types.HoldRecord
type TraceRecord = Types.TraceRecord
type MinigameResult = Types.MinigameResult
type PrepareInput = Types.PrepareInput
type StepSpec = Types.StepSpec
-- a physical button action (Space OR LMB) at t ms from GO
export type Action = { t: number, down: boolean }
export type PlayOptions = {
	frames: { number }, -- frame times, ms from GO
	offsetMs: number?, -- timingOffsetMs
	heldAtGo: boolean?, -- the button down at GO
	buttons: { Action }?, -- in time order
	releases: { number }?, -- focus losses, ms from GO, in order
	cursor: ((t: number) -> (number, number, boolean))?, -- the trace's cursor (panel u, v) and grind state at t
	viewEvery: number?, -- view every n frames (0: never)
	rawClock: boolean?, -- advance to the raw frame time instead of the Recorder's horizon (the negative of D4)
	skipFinalPush: boolean?, -- finish without pushing the records made after the last frame (the negative of [3.6])
}
export type Played = {
	finish: MinigameResult,
	records: { any },
	views: { any },
	events: { Types.FeedbackEvent },
	session: any, -- the client's session, finished
}

local QF = PrecisionTrace.PT_FIXED_POINT

-- T-MG-01's configurations (M4's plan [6.3]): 3 families × {Iron, Steel} × {Normal, Hard} × x ∈ {0, 0.3, 1}
local FAMILIES: { DT.FamilyId } = { "HoldZone", "TimingStrike", "PrecisionTrace" }
local MATERIALS: { DT.MaterialId } = { "Iron", "Steel" }
local TIERS: { DT.TierId } = { "Normal", "Hard" }

local H = {
	FAMILIES = table.freeze(FAMILIES),
	MATERIALS = table.freeze(MATERIALS),
	TIERS = table.freeze(TIERS),
	XS = table.freeze({ 0, 0.3, 1 }),
}

function H.configSalt(name: string): number
	return Dump.fnv1a32(name)
end

-- E-S3.2's final bot table (SPEC-evidence.md, `out/final_table.txt`): mean and SD of 2,000 runs per cell, as printed;
-- Minigames/Reference checks them against the shipped distributions
local function cell(elite: { number }, good: { number }, average: { number }, poor: { number }): { [string]: { number } }
	return table.freeze({ Elite = table.freeze(elite), Good = table.freeze(good), Average = table.freeze(average),
		Poor = table.freeze(poor) })
end
H.ES32 = table.freeze({
	["HoldZone Iron/Normal"] = cell({ 0.858, 0.074 }, { 0.799, 0.068 }, { 0.615, 0.074 }, { 0.481, 0.080 }),
	["HoldZone Steel/Normal"] = cell({ 0.870, 0.061 }, { 0.800, 0.064 }, { 0.599, 0.075 }, { 0.466, 0.082 }),
	["HoldZone Iron/Hard"] = cell({ 0.825, 0.069 }, { 0.748, 0.068 }, { 0.550, 0.071 }, { 0.421, 0.075 }),
	["HoldZone Steel/Hard"] = cell({ 0.830, 0.061 }, { 0.743, 0.067 }, { 0.535, 0.070 }, { 0.408, 0.073 }),
	["TimingStrike Iron/Normal"] = cell({ 0.864, 0.049 }, { 0.792, 0.079 }, { 0.648, 0.108 }, { 0.389, 0.117 }),
	["TimingStrike Steel/Normal"] = cell({ 0.858, 0.050 }, { 0.784, 0.082 }, { 0.636, 0.109 }, { 0.380, 0.117 }),
	["TimingStrike Iron/Hard"] = cell({ 0.808, 0.058 }, { 0.719, 0.091 }, { 0.555, 0.103 }, { 0.312, 0.096 }),
	["TimingStrike Steel/Hard"] = cell({ 0.806, 0.058 }, { 0.713, 0.092 }, { 0.547, 0.105 }, { 0.306, 0.098 }),
	["PrecisionTrace Iron/Normal"] = cell({ 0.957, 0.011 }, { 0.874, 0.027 }, { 0.633, 0.083 }, { 0.405, 0.102 }),
	["PrecisionTrace Steel/Normal"] = cell({ 0.955, 0.011 }, { 0.870, 0.027 }, { 0.624, 0.083 }, { 0.393, 0.103 }),
	["PrecisionTrace Iron/Hard"] = cell({ 0.949, 0.013 }, { 0.848, 0.032 }, { 0.559, 0.092 }, { 0.332, 0.099 }),
	["PrecisionTrace Steel/Hard"] = cell({ 0.947, 0.013 }, { 0.844, 0.034 }, { 0.549, 0.096 }, { 0.321, 0.099 }),
}) :: { [string]: { [string]: { number } } }

function H.stepInputFrom(analysis: Analyze.Analysis, stepIndex: number, seed: number): PrepareInput
	local steps = analysis.steps :: { Analyze.StepAnalysis }
	local step = steps[stepIndex]
	local def = Steps.get(step.step) :: DT.StepDef
	local edge = analysis.edge
	return {
		family = def.family,
		seed = seed,
		material = step.material,
		tier = step.tier,
		factors = step.factors,
		edge = if def.family == "PrecisionTrace" and edge
			then { chains = edge.chains, gripPoint = edge.gripPoint, gripAxis = edge.gripAxis }
			else nil,
		balanceVersion = analysis.balanceVersion,
	}
end

function H.inputFor(family: DT.FamilyId, material: DT.MaterialId, tier: DT.TierId, x: number, seed: number,
	edge: Edges.Edge?): PrepareInput
	return {
		family = family,
		seed = seed,
		material = material,
		tier = tier,
		factors = Params.refFactors(x),
		edge = if edge then { chains = edge.chains, gripPoint = edge.gripPoint, gripAxis = edge.gripAxis } else nil,
		balanceVersion = Versions.BALANCE_VERSION,
	}
end

function H.prepared(family: DT.FamilyId, material: DT.MaterialId, tier: DT.TierId, x: number, seed: number,
	edge: Edges.Edge?): (StepSpec, any)
	return Minigames.prepare(H.inputFor(family, material, tier, x, seed, edge))
end

function H.presses(P: TimingStrike.Pattern, errs: { number | false }): { number }
	local out: { number } = {}
	for i, c in ipairs(P.cycles) do
		local e = errs[i]
		if type(e) == "number" then
			table.insert(out, c.target + e)
		end
	end
	table.sort(out)
	return out
end

function H.taps(durationMs: number, periodMs: number, holdMs: number, startMs: number?): { HoldRecord }
	local out: { HoldRecord } = {}
	local t = startMs or 0
	while t + holdMs <= durationMs do
		table.insert(out, { t = t, down = true })
		table.insert(out, { t = t + holdMs, down = false })
		t += periodMs
	end
	return out
end

-- the panel point (u, v) as a record's fixed-point fields, clamped to the panel
function H.fixed(u: number, v: number): (number, number)
	return math.clamp(math.round(u * QF), 0, 3 * QF), math.clamp(math.round(v * QF), 0, QF)
end

function H.onPacer(P: PrecisionTrace.Pattern, everyMs: number, grind: boolean?): { TraceRecord }
	local out: { TraceRecord } = {}
	local t = 0
	while t <= P.durationMs do
		local u, v = H.fixed(PrecisionTrace.pointAt(P, PrecisionTrace.pacerArc(P, t)))
		table.insert(out, { t = t, u = u, v = v, grind = if grind == nil then true else grind })
		t += everyMs
	end
	return out
end

function H.randomRecords(rng: TestRng.TestRng, family: DT.FamilyId, P: any): { any }
	local D = P.durationMs
	local max = MinigameFamilies.MAX_RECORDS[family]
	if family == "HoldZone" then
		local out: { HoldRecord } = {}
		local t = rng:int(0, 2000)
		local down = false
		while t <= D and #out < math.min(max, 300) do
			down = not down
			table.insert(out, { t = t, down = down })
			t += rng:pick({ 0, 10, 40, 80, 150, 300, 700 })
		end
		return out
	elseif family == "TimingStrike" then
		local out: { number } = {}
		local sd = rng:pick({ 0, 5, 30, 120 })
		for _, c in ipairs((P :: TimingStrike.Pattern).cycles) do
			for _ = 1, rng:int(0, 2) do
				table.insert(out, math.clamp(c.target + math.round(rng:normal(0, sd)), 0, D))
			end
		end
		for _ = 1, rng:int(0, 3) do
			table.insert(out, rng:int(0, D))
		end
		table.sort(out)
		return out
	end
	local T = P :: PrecisionTrace.Pattern
	local out: { TraceRecord } = {}
	local t = rng:int(0, 30)
	local noise = rng:pick({ 0, 0.004, 0.04 })
	local grind = true
	while t <= D and #out < 700 do
		local u, v = PrecisionTrace.pointAt(T, PrecisionTrace.pacerArc(T, t + rng:int(-100, 100)))
		if rng:int(1, 40) == 1 then
			grind = not grind
		end
		local fu, fv = H.fixed(u + rng:range(-noise, noise), v + rng:range(-noise, noise))
		table.insert(out, { t = t, u = fu, v = fv, grind = grind })
		t += rng:pick({ 13, 20, 20, 20, 27, 41, 90 })
	end
	return out
end

function H.frames(rng: TestRng.TestRng, endMs: number, lo: number, hi: number, hitchMs: number): { number }
	local out: { number } = {}
	local step = rng:range(lo, hi)
	local t = rng:range(0, step)
	while t <= endMs + 2 * hi + hitchMs do
		table.insert(out, t)
		local dt = step + rng:range(-1, 1)
		if hitchMs > 0 and rng:int(1, 60) == 1 then
			dt += rng:range(0, hitchMs)
		end
		t += math.max(dt, 0.25)
	end
	return out
end

-- One step played as S6's host plays it (§12.5 with M4's D4): go at the first frame; at each frame before GO +
-- durationMs, the focus losses and button changes since the last frame reach the Recorder (InputCapture's logical
-- OR-state: after a focus loss a held button counts only through a new press), the trace's cursor is offered, then
-- the host pushes since(pushed), advances the live session to horizonMs (or to the raw frame time with rawClock) and
-- views it every viewEvery frames; at GO + durationMs the inputs since the last frame are recorded, the host pushes
-- since(pushed) once more and finishes. Returns the client's finish, the records, the views and every event.
function H.play(spec: StepSpec, pattern: any, opts: PlayOptions): Played
	local F = Minigames.get(spec.family)
	local rec = Input.new(spec, opts.offsetMs or 0, 0)
	local S = F.newSession(pattern)
	local D = spec.durationMs
	local buttons, releases, cursor = opts.buttons or {}, opts.releases or {}, opts.cursor
	local viewEvery = opts.viewEvery or 0
	local views: { any } = {}
	local events: { Types.FeedbackEvent } = {}
	local pushed = 0
	local bi, ri = 1, 1
	local logical = opts.heldAtGo == true
	local function push()
		local new = rec:since(pushed)
		for _, r in ipairs(new) do
			for _, e in ipairs(F.push(S, r)) do
				table.insert(events, e)
			end
		end
		pushed += #new
	end
	-- the inputs that happened by f (ms), as InputCapture records them with this frame's clock and delta
	local function deliver(f: number, dtMs: number)
		local clock = f / 1000
		while bi <= #buttons or ri <= #releases do
			local b, r = buttons[bi], releases[ri]
			if r ~= nil and r <= f and (b == nil or r <= b.t) then
				rec:release()
				logical = false
				ri += 1
			elseif b ~= nil and b.t <= f then
				if b.down ~= logical then
					rec:button(b.down, clock, dtMs / 1000)
					logical = b.down
				end
				bi += 1
			else
				break
			end
		end
	end
	local frames = opts.frames
	local lastDt = 0
	for k, f in ipairs(frames) do
		if f >= D then
			break
		end
		local dt = if k > 1 then f - frames[k - 1] else f
		lastDt = dt
		if k == 1 then
			local u: number?, v: number?, g: boolean? = nil, nil, nil
			if cursor then
				u, v, g = cursor(f)
			end
			rec:go(opts.heldAtGo == true, u, v, g)
		end
		deliver(f, dt)
		if cursor then
			local u, v, g = cursor(f)
			rec:cursor(u, v, g, f / 1000)
		end
		push()
		local now = if opts.rawClock then math.floor(f) else rec:horizonMs(f / 1000, dt / 1000)
		for _, e in ipairs(F.advance(S, now)) do
			table.insert(events, e)
		end
		if viewEvery > 0 and (k - 1) % viewEvery == 0 then
			table.insert(views, F.view(S, math.floor(f)))
		end
	end
	deliver(D, lastDt)
	if not opts.skipFinalPush then
		push()
	end
	return { finish = F.finish(S), records = rec:records(), views = views, events = events, session = S }
end

return H
