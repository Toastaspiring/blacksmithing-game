--!strict
-- Minigames/Properties (SPEC §14.5): the generic properties of every public pure Minigames function, one row per
-- module (M4's plan [6.7]): P-DET same input → deep-equal output, bit for bit; P-NOMUT inputs unchanged; P-TOTAL
-- untrusted input returns an error, never throws; P-FINITE; P-RANGE outputs in their ranges; P-ORDER Definitions
-- maps rebuilt in another order leave results bit-identical (Params' P-ORDER is T-MG-07's, in Params.spec). Rows
-- that generate or replay PrecisionTrace patterns or run bots take PROP_N_FAST cases in the quick run and PROP_N under
-- t.slow (L1's share); the others take PROP_N. The codec, the facade and the Recorder close the list (slice 7), and the
-- bots (slice 8): Bots.play and Bots.run, deterministic per seed, their scores finite and in range.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Prop = require("../lib/Prop")
local Tol = require("../lib/Tol")
local TestRng = require("../lib/TestRng")
local Edges = require("../fixtures/Edges")
local H = require("./MinigamesHelpers")
local DT = require("../../src/shared/Definitions/Types")
local MF = require("../../src/shared/Definitions/MinigameFamilies")
local Validate = require("../../src/shared/Definitions/Validate")
local Bots = require("../../src/shared/Minigames/Bots")
local Checks = require("../../src/shared/Minigames/Checks")
local HoldZone = require("../../src/shared/Minigames/HoldZone")
local Input = require("../../src/shared/Minigames/Input")
local Minigames = require("../../src/shared/Minigames/Minigames")
local Params = require("../../src/shared/Minigames/Params")
local PrecisionTrace = require("../../src/shared/Minigames/PrecisionTrace")
local Rng = require("../../src/shared/Minigames/Rng")
local Timeline = require("../../src/shared/Minigames/Timeline")
local TimingStrike = require("../../src/shared/Minigames/TimingStrike")
local Types = require("../../src/shared/Minigames/Types")

type FactorValue = Types.FactorValue
type FlagId = Types.FlagId
type MinigameResult = Types.MinigameResult
-- one family case: a pattern's inputs, records in time order, and view times
type FamilyCase = {
	family: DT.FamilyId,
	seed: number,
	params: { [string]: number },
	source: { number }?,
	records: { any },
	viewTimes: { number },
}

local M32 = 4294967296
local TAGS = { "", "HoldZone.Target", "TimingStrike.Tempo", "TimingStrike.Offsets", "PrecisionTrace.Perturb" }
local FAMILIES: { DT.FamilyId } = { "HoldZone", "TimingStrike", "PrecisionTrace" }
local MATERIALS: { DT.MaterialId } = { "Iron", "Steel", "Bronze", "Mithril" }
local TIERS: { DT.TierId } = { "Normal", "Hard", "Expert", "Master", "Hell" }
local FLAGS: { FlagId } =
	{ "HzInhumanRate", "TsLowVariance", "TsExactHits", "PtTooPrecise", "PtTooSmooth", "PtTeleport", "PtSparse" }

local function isU32(v: any): boolean
	return type(v) == "number" and v >= 0 and v < M32 and math.floor(v) == v
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

-- the judge's path without the facade: push every record, finish, checks
local function replayOf(F: any, P: any, records: { any }): (MinigameResult, { FlagId })
	local S = F.newSession(P)
	for _, r in ipairs(records) do
		F.push(S, r)
	end
	local result = F.finish(S)
	return result, F.checks(P, records, result)
end

-- every number in a view, the optional ones included, is finite
local function finiteView(view: { [string]: any }, what: string)
	for k, v in view do
		if type(v) == "number" then
			A.finite(v, what .. "." .. k)
		elseif type(v) == "table" then
			finiteView(v, what .. "." .. k)
		end
	end
end

-- deep equality, numbers bit for bit (−0 = 0), building no string: A.deepEq names a path per element, too slow for a
-- trace's whole path, so it only words a failure
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

-- a copy with some fields replaced (a result, for the judge's elapsedMs)
local function with(t: { [string]: any }, changes: { [string]: any }): any
	local out = table.clone(t)
	for k, v in changes do
		out[k] = v
	end
	return out
end

local function copy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = copy(x)
	end
	return out
end

-- a family's flags, as Definitions lists them
local function flagsOf(family: DT.FamilyId): { [string]: boolean }
	local allowed: { [string]: boolean } = {}
	for _, f in ipairs((MF.get(family) :: MF.MinigameFamilyDef).flagLevels) do
		allowed[f.flag] = true
	end
	return allowed
end

-- a decoded or recorded timeline is honest for its family and step: times integers in [0, durationMs], non-decreasing
-- (the trace's increasing), HoldZone's kinds alternating from down, the trace's points in the panel, within the cap
local function honestTimeline(family: DT.FamilyId, records: { any }, durationMs: number, what: string)
	A.truthy(#records <= MF.MAX_RECORDS[family], what .. ": within MAX_RECORDS")
	local prev = -1
	for i, r in ipairs(records) do
		local t = if type(r) == "number" then r else r.t
		A.truthy(t >= 0 and t <= durationMs and math.floor(t) == t, what .. ": an integer time within the step")
		A.truthy(t >= prev, what .. ": times non-decreasing")
		if family == "HoldZone" then
			A.eq(r.down, i % 2 == 1, what .. ": kinds alternate from down")
		elseif family == "PrecisionTrace" then
			A.truthy(t > prev, what .. ": trace times increase")
			A.truthy(r.u >= 0 and r.u <= Timeline.U_MAX and r.v >= 0 and r.v <= Timeline.V_MAX, what .. ": in the panel")
		end
		prev = t
	end
end

-- a record's time: TimingStrike's record is the press time itself
local function timeOf(r: any): number
	return if type(r) == "number" then r else r.t
end

-- P-DET (generate, hash, replay, checks), P-NOMUT (params, source, records), P-FINITE and P-RANGE (the result and every
-- view), and a live session advanced and viewed between its records (every advance after the push of every earlier
-- record, M4's D4) finishes as the replay does. inRange(P, view) adds the family's own ranges. Returns the pattern and
-- the replay's result, for the family's own checks.
local function familyProperties(F: any, c: FamilyCase, inRange: (P: any, view: any) -> ()): (any, MinigameResult)
	local before = Dump.canonical({ c.params, c.source or false, c.records } :: { any })
	local P = F.generate(c.seed, c.params, c.source)
	deepEqFast(F.generate(c.seed, c.params, c.source), P, "P-DET generate")
	A.eq(F.hash(P), P.hash, "hash")
	A.truthy(P.hash >= 0 and P.hash < 4294967296 and math.floor(P.hash) == P.hash, "the hash is a u32")
	A.truthy(P.durationMs > 0 and math.floor(P.durationMs) == P.durationMs, "an integer duration")
	local result, flags = replayOf(F, P, c.records)
	local again, flagsAgain = replayOf(F, P, c.records)
	A.deepEq(again, result, "P-DET replay")
	A.deepEq(flagsAgain, flags, "P-DET checks")
	local S = F.newSession(P)
	local k = 1
	for _, tv in ipairs(c.viewTimes) do
		while k <= #c.records and timeOf(c.records[k]) <= tv do
			F.push(S, c.records[k])
			k += 1
		end
		F.advance(S, tv)
		local view = F.view(S, tv)
		finiteView(view, "view")
		A.eq(view.t, tv, "view.t")
		A.within(view.timeLeftMs, 0, P.durationMs + 3000, "timeLeftMs")
		inRange(P, view)
	end
	for i = k, #c.records do
		F.push(S, c.records[i])
	end
	A.deepEq(F.finish(S), result, "the live session, advanced and viewed, finishes as the replay")
	A.eq(Dump.canonical({ c.params, c.source or false, c.records } :: { any }), before, "P-NOMUT")
	A.eq(result.status, "Ok")
	A.within(result.score, 0, 1, "score")
	A.eq(result.score, math.round(result.score * 10000) / 10000, "the score is on the q grid")
	A.eq(result.rawScore, result.score, "a family's own result is unclamped")
	A.eq(result.passed, result.score >= P.p.passThreshold, "passed")
	A.eq(result.elapsedMs, 0)
	A.deepEq(result.flags, {}, "finish leaves the flags to checks")
	for name, v in result.breakdown do
		A.finite(v, "breakdown." .. name)
	end
	local allowed: { [string]: boolean } = {}
	for _, f in ipairs((MF.get(c.family) :: MF.MinigameFamilyDef).flagLevels) do
		allowed[f.flag] = true
	end
	for _, flag in ipairs(flags) do
		A.truthy(allowed[flag], c.family .. " raises " .. flag)
	end
	A.deepEq(Checks.sorted(flags), flags, "checks returns its flags in byte order")
	return P, result
end

-- 60 draws cycling through every method, with the case's bounds
local function stream(seed: number, tag: string, lo: number, hi: number, ilo: number, ihi: number, p: number): { any }
	local r = Rng.new(seed, tag)
	local out: { any } = {}
	for i = 1, 60 do
		local m = i % 6
		if m == 0 then
			out[i] = r:nextU32()
		elseif m == 1 then
			out[i] = r:nextFloat()
		elseif m == 2 then
			out[i] = r:range(lo, hi)
		elseif m == 3 then
			out[i] = r:int(ilo, ihi)
		elseif m == 4 then
			out[i] = r:chance(p)
		else
			out[i] = r:sign()
		end
	end
	return out
end

return Test.suite("Minigames/Properties", function(t)
	-- ── Rng ──────────────────────────────────────────────────────────────────────────────────────────────────

	t.it("Rng: P-DET, P-FINITE and P-RANGE for every method, on random seeds, tags and bounds", function()
		type Case = { seed: number, tag: string, lo: number, hi: number, ilo: number, ihi: number, p: number }
		Prop.check(Tol.PROP_N, function(rng: TestRng.TestRng): Case
			local lo = rng:range(-1000, 1000)
			local ilo = rng:int(-50000, 50000)
			local tag = if rng:int(1, 4) == 1 then "T-RNG-P/" .. rng:u32() else rng:pick(TAGS)
			return {
				seed = rng:u32(),
				tag = tag,
				lo = lo,
				hi = lo + rng:range(0.001, 1000),
				ilo = ilo,
				ihi = ilo + rng:int(0, 100000),
				p = rng:float(),
			}
		end, function(c: Case)
			local a = stream(c.seed, c.tag, c.lo, c.hi, c.ilo, c.ihi, c.p)
			local b = stream(c.seed, c.tag, c.lo, c.hi, c.ilo, c.ihi, c.p)
			A.deepEq(a, b, "P-DET")
			for i, v in ipairs(a) do
				local m = i % 6
				if m == 0 then
					A.truthy(isU32(v), "nextU32 is a u32")
				elseif m == 1 then
					A.truthy(v >= 0 and v < 1, "nextFloat in [0, 1)")
				elseif m == 2 then
					A.truthy(v >= c.lo and v < c.hi, "range in [lo, hi)")
				elseif m == 3 then
					A.truthy(math.floor(v) == v and v >= c.ilo and v <= c.ihi, "int in [lo, hi], an integer")
				elseif m == 4 then
					A.eq(type(v), "boolean", "chance")
				else
					A.truthy(v == -1 or v == 1, "sign")
				end
			end
			-- the bounds of chance: never below 0, always below 1
			local r = Rng.new(c.seed, c.tag)
			for _ = 1, 20 do
				A.falsy(r:chance(0), "chance(0)")
				A.truthy(r:chance(1), "chance(1)")
			end
		end)
	end)

	t.it("Rng: mul32 is the exact product mod 2^32; fnv1a32, fmix32 and hashU32 give u32s, deterministically", function()
		type Case = { a: number, b: number, small: { number }, s: string }
		Prop.check(Tol.PROP_N, function(rng: TestRng.TestRng): Case
			local chars: { string } = {}
			for _ = 1, rng:int(0, 24) do
				table.insert(chars, string.char(rng:int(0, 255)))
			end
			-- two factors below 2^26: their product is below 2^52, so `%` is exact there
			return { a = rng:u32(), b = rng:u32(), small = { rng:int(0, 67108863), rng:int(0, 67108863) },
				s = table.concat(chars) }
		end, function(c: Case)
			local x, y = c.small[1], c.small[2]
			A.eq(Rng.mul32(x, y), (x * y) % M32, "mul32 below 2^26")
			A.eq(Rng.mul32(c.a, c.b), Rng.mul32(c.b, c.a), "mul32 commutes")
			A.truthy(isU32(Rng.mul32(c.a, c.b)), "mul32 is a u32")
			-- (a · b) mod 2^32 from the bytes of b: Σ a·b_k·2^(8k), each term reduced mod 2^32 (a·b_k < 2^40; a product
			-- by a power of two only moves the exponent), so every step is exact
			local acc = 0
			local scale = 1
			local rest = c.b
			for _ = 1, 4 do
				local byte = rest % 256
				rest = (rest - byte) / 256
				local term = (((c.a * byte) % M32) * scale) % M32
				acc = (acc + term) % M32
				scale *= 256
			end
			A.eq(Rng.mul32(c.a, c.b), acc, "mul32 = the byte-wise product mod 2^32")
			local h = Rng.fnv1a32(c.s)
			A.truthy(isU32(h), "fnv1a32 is a u32")
			A.eq(Rng.fnv1a32(c.s), h, "fnv1a32 P-DET")
			A.truthy(isU32(Rng.fmix32(c.a)), "fmix32 is a u32")
			A.truthy(isU32(Rng.hashU32(h, c.a)), "hashU32 is a u32")
			A.eq(Rng.hashU32(h, c.a), Rng.hashU32(h, c.a), "hashU32 P-DET")
		end)
		-- the folds agree with Dump's independent FNV-1a 32
		A.eq(Rng.fnv1a32("smithy é"), Dump.fnv1a32("smithy é"), "Dump.fnv1a32")
	end)

	-- ── Params (P-ORDER: Params.spec, T-MG-07) ───────────────────────────────────────────────────────────────

	t.it("Params: P-DET, P-NOMUT and P-FINITE on random families, materials, tiers and factor arrays", function()
		type Case = { family: DT.FamilyId, material: DT.MaterialId, tier: DT.TierId, factors: { FactorValue } }
		Prop.check(Tol.PROP_N, function(rng: TestRng.TestRng): Case
			-- any subset of the factors, in any order, x beyond [0, 1] now and then
			local factors: { FactorValue } = {}
			for _, f in ipairs(Validate.FACTOR_ORDER) do
				if rng:int(1, 4) > 1 then
					local x = rng:range(-0.5, 1.5)
					table.insert(factors, rng:int(1, #factors + 1), { factor = f :: DT.FactorId, raw = x * 10, x = x })
				end
			end
			-- indexed picks keep the id types (luau-lsp widens a generic pick of a string-literal union to string)
			local family: DT.FamilyId = FAMILIES[rng:int(1, #FAMILIES)]
			local material: DT.MaterialId = MATERIALS[rng:int(1, #MATERIALS)]
			local tier: DT.TierId = TIERS[rng:int(1, #TIERS)]
			return { family = family, material = material, tier = tier, factors = factors }
		end, function(c: Case)
			local before = Dump.canonical(c.factors)
			local a = Params.resolve(c.family, c.material, c.tier, c.factors)
			local e = Params.explain(c.family, c.material, c.tier, c.factors)
			A.deepEq(Params.resolve(c.family, c.material, c.tier, c.factors), a, "P-DET resolve")
			A.deepEq(Params.explain(c.family, c.material, c.tier, c.factors), e, "P-DET explain")
			A.eq(Dump.canonical(c.factors), before, "P-NOMUT: the factors are untouched")
			for name, v in a do
				A.finite(v, "P-FINITE " .. name)
				A.truthy(v > 0, "every MVP parameter is positive: " .. name)
				local x = e[name]
				A.finite(x.mMaterial * x.mTier * x.mDesign, "P-FINITE modifiers " .. name)
			end
		end)
	end)

	-- ── Checks ────────────────────────────────────────────────────────────────────────────────────────────────

	t.it("Checks: P-DET, P-NOMUT and P-FINITE for mean, sampleSd, maxInWindow and sorted", function()
		type Case = { xs: { number }, times: { number }, flags: { FlagId } }
		Prop.check(Tol.PROP_N, function(rng: TestRng.TestRng): Case
			local xs: { number } = {}
			local times: { number } = {}
			local tNow = 0
			for i = 1, rng:int(2, 50) do
				xs[i] = rng:range(-500, 500)
				tNow += rng:int(0, 200)
				times[i] = tNow
			end
			local flags: { FlagId } = {}
			for _, f in FLAGS do
				if rng:int(1, 2) == 1 then
					table.insert(flags, rng:int(1, #flags + 1), f)
				end
			end
			return { xs = xs, times = times, flags = flags }
		end, function(c: Case)
			local before = Dump.canonical(c)
			local m, sd, most = Checks.mean(c.xs), Checks.sampleSd(c.xs), Checks.maxInWindow(c.times, 1000)
			local sorted = Checks.sorted(c.flags)
			A.eq(Checks.mean(c.xs), m, "P-DET mean")
			A.eq(Checks.sampleSd(c.xs), sd, "P-DET sampleSd")
			A.eq(Checks.maxInWindow(c.times, 1000), most, "P-DET maxInWindow")
			A.deepEq(Checks.sorted(c.flags), sorted, "P-DET sorted")
			A.eq(Dump.canonical(c), before, "P-NOMUT")
			A.finite(m, "P-FINITE mean")
			A.finite(sd, "P-FINITE sampleSd")
			A.truthy(sd >= 0, "an SD is never negative")
			A.within(most, 1, #c.times, "maxInWindow counts entries")
			A.eq(#sorted, #c.flags, "sorted keeps every flag")
		end)
	end)

	-- ── the families ──────────────────────────────────────────────────────────────────────────────────────────

	t.it("TimingStrike: P-DET, P-NOMUT, P-FINITE and P-RANGE for generate, the session, views, finish and checks", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng.TestRng): FamilyCase
			local material: DT.MaterialId = MATERIALS[rng:int(1, #MATERIALS)]
			local tier: DT.TierId = TIERS[rng:int(1, #TIERS)]
			local params = Params.resolve("TimingStrike", material, tier, Params.refFactors(rng:range(-0.2, 1.2)))
			local seed = rng:u32()
			local P = TimingStrike.generate(seed, params)
			-- presses near the targets at any spread, exact ones, strays and repeats, in time order
			local sd = rng:pick({ 0, 3, 20, 80, 300 })
			local presses: { number } = {}
			for _, cy in ipairs(P.cycles) do
				for _ = 1, rng:int(0, 2) do
					table.insert(presses, math.max(0, cy.target + math.round(rng:normal(0, sd))))
				end
			end
			for _ = 1, rng:int(0, 4) do
				table.insert(presses, rng:int(0, P.durationMs))
			end
			table.sort(presses)
			local viewTimes: { number } = {}
			for i = 1, rng:int(1, 12) do
				viewTimes[i] = rng:int(-1000, P.durationMs + 1000)
			end
			table.sort(viewTimes)
			return { family = "TimingStrike", seed = seed, params = params, records = presses, viewTimes = viewTimes }
		end, function(c: FamilyCase)
			local P: TimingStrike.Pattern, result = familyProperties(TimingStrike, c, function(P: TimingStrike.Pattern,
				view: Types.TimingStrikeView)
				A.within(view.cycle, 1, #P.cycles, "cycle")
				A.eq(view.cycles, #P.cycles)
				A.within(view.marker, 0, 1, "marker")
				A.within(view.windowCenter, 0, 1, "windowCenter")
				A.within(view.runningScore, 0, 1, "runningScore")
				A.truthy(view.combo >= 0 and math.floor(view.combo) == view.combo, "combo")
				A.truthy(view.perfectHalf <= view.goodHalf and view.goodHalf <= view.windowHalf, "bands nest")
			end)
			for _, cy in ipairs(P.cycles) do
				A.truthy(cy.start <= cy.target and cy.target < cy.start + cy.period, "each target inside its cycle")
			end
			A.truthy(P.core <= P.W and P.W <= P.M, "core ≤ W ≤ M")
			local b = result.breakdown
			local N = #P.cycles
			A.eq(b.judged + b.miss, N, "every span judged or missed")
			A.truthy(b.perfect + b.good + b.ok <= b.judged, "graded presses are judged ones")
			A.within(b.bestCombo, 0, N, "bestCombo")
			A.within(b.meanAbsErrMs, 0, P.M, "meanAbsErrMs within ±M")
			A.within(b.meanErrMs, -P.M, P.M, "meanErrMs (signed)")
			A.truthy(b.whiffs >= 0 and b.judged + b.whiffs == #c.records, "each press judged or a whiff")
		end)
	end)

	sized(t, "HoldZone: P-DET, P-NOMUT, P-FINITE and P-RANGE for generate, the session, views, finish and checks", function(n: number)
		Prop.check(n, function(rng: TestRng.TestRng): FamilyCase
			local material: DT.MaterialId = MATERIALS[rng:int(1, #MATERIALS)]
			local tier: DT.TierId = TIERS[rng:int(1, #TIERS)]
			local params = Params.resolve("HoldZone", material, tier, Params.refFactors(rng:range(-0.2, 1.2)))
			local seed = rng:u32()
			local P = HoldZone.generate(seed, params)
			-- alternating OR-state changes from down at any pace, bursts included, a final down left held at times
			local records: { Types.HoldRecord } = {}
			local tNow = rng:int(0, 1500)
			local down = false
			while tNow < P.durationMs and #records < 400 do
				down = not down
				table.insert(records, { t = tNow, down = down })
				tNow += rng:pick({ 0, 5, 30, 70, 150, 400 })
			end
			local viewTimes: { number } = {}
			for i = 1, rng:int(1, 12) do
				viewTimes[i] = rng:int(-1000, P.durationMs + 1000)
			end
			table.sort(viewTimes)
			return { family = "HoldZone", seed = seed, params = params, records = records, viewTimes = viewTimes }
		end, function(c: FamilyCase)
			local P: HoldZone.Pattern, result = familyProperties(HoldZone, c, function(P: HoldZone.Pattern,
				view: Types.HoldZoneView)
				A.within(view.temperature, 0, 1, "temperature")
				A.within(view.fire, 0, 1, "fire")
				A.within(view.zoneCenter, P.p.targetMin, P.p.targetMax, "zoneCenter")
				A.within(view.runningScore, 0, 1, "runningScore")
				A.truthy(view.phase == "Ramp" or view.phase == "Hold" or view.phase == "Done", "phase")
			end)
			for i = 1, #P.keysC do
				A.within(P.keysC[i], P.p.targetMin, P.p.targetMax, "zone centres within [targetMin, targetMax]")
				A.truthy(i == 1 or P.keysT[i] >= P.keysT[i - 1], "key times non-decreasing")
			end
			local b = result.breakdown
			A.within(b.inZone, 0, 1, "inZone")
			-- the last tick starts at durationMs − 10: a later down is never integrated (it could move no score)
			local lastTick = (math.floor(P.durationMs / HoldZone.HZ_TICK_MS) - 1) * HoldZone.HZ_TICK_MS
			local downs = 0
			for _, r in ipairs(c.records) do
				local e = r :: Types.HoldRecord
				downs += if e.down and e.t <= lastTick then 1 else 0
			end
			A.eq(b.strokes, downs, "every down up to the last tick is a stroke")
		end)
	end)

	sized(t, "PrecisionTrace: P-DET, P-NOMUT, P-FINITE and P-RANGE for generate, the session, views, finish and checks", function(n: number)
		local QF = PrecisionTrace.PT_FIXED_POINT
		Prop.check(n, function(rng: TestRng.TestRng): FamilyCase
			local material: DT.MaterialId = MATERIALS[rng:int(1, #MATERIALS)]
			local tier: DT.TierId = TIERS[rng:int(1, #TIERS)]
			local params = Params.resolve("PrecisionTrace", material, tier, Params.refFactors(rng:range(-0.2, 1.2)))
			-- a reference edge's source, none (the fallback) or a raw one: a random walk anywhere in the panel, its
			-- length bounded as the hand-off bounds a source's (a long scribble only makes generate slow)
			local source: { number }? = nil
			local pick = rng:int(1, 4)
			if pick <= 2 then
				local e: Edges.Edge = (Edges :: any)[rng:pick(Edges.order)]
				source = PrecisionTrace.edgeToPanel(PrecisionTrace.sidesFromChains(e.chains, e.gripPoint, e.gripAxis),
					e.gripPoint, e.gripAxis, params.pacerSpeed)
			elseif pick == 3 then
				local s: { number } = {}
				local u, v = rng:range(0, 3), rng:range(0, 1)
				for _ = 1, rng:int(1, 12) do
					table.insert(s, math.round(u * QF))
					table.insert(s, math.round(v * QF))
					u = math.clamp(u + rng:range(-0.4, 0.4), 0, 3)
					v = math.clamp(v + rng:range(-0.3, 0.3), 0, 1)
				end
				source = s
			end
			local seed = rng:u32()
			local P = PrecisionTrace.generate(seed, params, source)
			-- samples at strictly increasing times near the pacer, any cadence and noise, grinding with lifts, a far
			-- cursor now and then (at most 400: P-NOMUT's canonical dump of the records is most of a case's cost)
			local records: { Types.TraceRecord } = {}
			local tNow = rng:int(0, 200)
			local noise = rng:pick({ 0, 0.003, 0.03, 0.3 })
			local grind = true
			while tNow <= P.durationMs and #records < 400 do
				local u, v = PrecisionTrace.pointAt(P, PrecisionTrace.pacerArc(P, tNow + rng:int(-300, 300)))
				if rng:int(1, 30) == 1 then
					u, v = rng:range(0, 3), rng:range(0, 1)
				end
				u += rng:range(-noise, noise)
				v += rng:range(-noise, noise)
				if rng:int(1, 25) == 1 then
					grind = not grind
				end
				table.insert(records, { t = tNow, u = math.clamp(math.round(u * QF), 0, 3 * QF),
					v = math.clamp(math.round(v * QF), 0, QF), grind = grind })
				tNow += rng:pick({ 1, 9, 20, 20, 33, 41, 120, 300 })
			end
			local viewTimes: { number } = {}
			for i = 1, rng:int(1, 12) do
				viewTimes[i] = rng:int(-1000, P.durationMs + 1000)
			end
			table.sort(viewTimes)
			return { family = "PrecisionTrace", seed = seed, params = params, source = source, records = records,
				viewTimes = viewTimes }
		end, function(c: FamilyCase)
			local nBins = 0
			local P: PrecisionTrace.Pattern, result = familyProperties(PrecisionTrace, c, function(P: PrecisionTrace.Pattern,
				view: Types.PrecisionTraceView)
				nBins = math.ceil(P.L / PrecisionTrace.PT_BIN)
				A.within(view.pacerArc, 0, P.L, "pacerArc")
				A.within(view.pacerU, 0, 3, "pacerU")
				A.within(view.pacerV, 0, 1, "pacerV")
				A.within(view.accuracySoFar, 0, 1, "accuracySoFar")
				A.within(view.coverage, 0, 1, "coverage")
				A.within(view.runningScore, 0, 1, "runningScore")
				if view.credit ~= nil then
					A.within(view.credit, 0, 1, "credit")
				end
				if view.distance ~= nil then
					A.truthy(view.distance >= 0 and view.cursorArc ~= nil, "a cursor's distance and arc")
				end
				A.eq(view.onPath, view.distance ~= nil and view.distance <= P.p.halfWidth, "onPath")
				A.eq(view.paceLag ~= nil, view.onPath, "paceLag only on the band")
				local runs = view.coveredRuns
				A.eq(#runs % 2, 0, "runs come in pairs")
				for i = 1, #runs do
					A.truthy(runs[i] >= 1 and runs[i] <= nBins and math.floor(runs[i]) == runs[i], "a bin")
					A.truthy(i == 1 or runs[i] >= runs[i - 1] + (if i % 2 == 0 then 0 else 2), "maximal runs, in order")
				end
			end)
			for i = 1, #P.pu do
				-- the panel's clamp [0.05, 2.95] × [0.05, 0.95], quantized
				A.within(P.pu[i] * QF, 819, 48333, "u in the panel")
				A.within(P.pv[i] * QF, 819, 15565, "v in the panel")
				A.truthy(i == 1 or P.arc[i] > P.arc[i - 1], "arc increasing")
			end
			A.eq(P.L, P.arc[#P.arc])
			A.truthy(P.travelMs >= PrecisionTrace.PT_TRAVEL_MIN_MS and P.travelMs <= PrecisionTrace.PT_TRAVEL_MAX_MS
				and P.travelMs % PrecisionTrace.PT_EVAL_MS == 0, "travel clamped, in whole ticks")
			A.eq(P.durationMs, P.leadInMs + P.travelMs + c.params.tailMs)
			local b = result.breakdown
			for _, name in { "accuracy", "pacing", "coverage" } do
				A.within(b[name], 0, 1, name)
			end
			A.eq(b.usedFallback, if P.usedFallback then 1 else 0, "usedFallback")
		end)
	end)

	sized(t, "PrecisionTrace's edge hand-off: P-DET, P-NOMUT, P-TOTAL on degenerate chains, P-FINITE and P-RANGE", function(n: number)
		local QF = PrecisionTrace.PT_FIXED_POINT
		type Case = { chains: { Types.EdgeChain }?, gripPoint: { number }, gripAxis: { number }, speed: number }
		Prop.check(n, function(rng: TestRng.TestRng): Case
			-- a random walk up a blade, or a degenerate chain: none, empty, one point, one point repeated, flat across the
			-- grip axis; a grip axis at any angle (test-side trigonometry)
			local a = rng:range(-math.pi, math.pi)
			local axis = { math.cos(a), math.sin(a) }
			local grip = { rng:range(-1, 1), rng:range(-1, 1), 0 }
			local kind = rng:int(1, 10)
			local pts: { { number } } = {}
			if kind == 3 then
				pts = { { 0.5, 2 } }
			elseif kind == 4 then
				pts = { { 0.5, 2 }, { 0.5, 2 }, { 0.5, 2 } }
			elseif kind == 5 then
				for i = 1, rng:int(2, 6) do
					local w = rng:range(-0.5, 0.5) -- across the axis only
					pts[i] = { grip[1] + 2 * axis[1] - w * axis[2], grip[2] + 2 * axis[2] + w * axis[1] }
				end
			else
				local x, y = rng:range(-0.3, 0.3), rng:range(0, 2)
				for i = 1, rng:int(2, 300) do
					x += rng:range(-0.2, 0.2)
					y += rng:range(-0.05, 0.3)
					pts[i] = { x, y }
				end
			end
			local chains: { Types.EdgeChain }? = if kind == 1 then nil
				elseif kind == 2 then {}
				else { { points = pts, length = 0 } }
			return { chains = chains, gripPoint = grip, gripAxis = axis, speed = rng:range(0.05, 0.6) }
		end, function(c: Case)
			local before = Dump.canonical(c)
			local sides = PrecisionTrace.sidesFromChains(c.chains, c.gripPoint, c.gripAxis)
			A.deepEq(PrecisionTrace.sidesFromChains(c.chains, c.gripPoint, c.gripAxis), sides, "P-DET sides")
			local source, info = PrecisionTrace.edgeToPanelInfo(sides, c.gripPoint, c.gripAxis, c.speed)
			local again, infoAgain = PrecisionTrace.edgeToPanelInfo(sides, c.gripPoint, c.gripAxis, c.speed)
			A.deepEq({ again, infoAgain } :: { any }, { source, info } :: { any }, "P-DET source")
			A.deepEq(PrecisionTrace.edgeToPanel(sides, c.gripPoint, c.gripAxis, c.speed), source, "edgeToPanel")
			A.eq(Dump.canonical(c), before, "P-NOMUT")
			A.truthy(#sides <= 2, "at most two sides")
			for _, side in ipairs(sides) do
				A.truthy(#side >= 2, "a side has 2 points or more")
			end
			if source == nil then
				A.truthy(info.reason ~= nil, "no source names its reason")
				return
			end
			A.eq(#source % 2, 0, "pairs")
			A.within(#source / 2, 2, PrecisionTrace.PT_MAX_SOURCE_POINTS, "points")
			for i = 1, #source, 2 do
				-- the usable panel, u 0.15–2.85 and v 0.12–0.88 (§6.10), give or take the rounding
				A.within(source[i], 0.15 * QF - 1, 2.85 * QF + 1, "u")
				A.within(source[i + 1], 0.12 * QF - 1, 0.88 * QF + 1, "v")
				A.eq(source[i], math.round(source[i]), "fixed point")
			end
			A.within(info.len :: number, PrecisionTrace.PT_MIN_SOURCE_LEN, info.maxLen :: number, "within the length bounds")
			A.finite(info.E :: number, "E")
		end)
	end)
	-- ── the codec, the facade and the Recorder ────────────────────────────────────────────────────────────────

	t.it("Timeline: P-DET, P-NOMUT and P-RANGE for encode and decode; P-TOTAL: decode of any value or byte string", function()
		type Case = { family: DT.FamilyId, durationMs: number, hash: number, records: { any }, junk: buffer }
		Prop.check(Tol.PROP_N, function(rng: TestRng.TestRng): Case
			local family: DT.FamilyId = FAMILIES[rng:int(1, 3)]
			local D = rng:int(0, 40000)
			local records: { any } = {}
			local tNow = rng:int(0, 50)
			for i = 1, rng:int(0, 60) do
				if tNow > D then
					break
				end
				records[i] = if family == "HoldZone" then { t = tNow, down = i % 2 == 1 }
					elseif family == "TimingStrike" then tNow
					else { t = tNow, u = rng:int(0, Timeline.U_MAX), v = rng:int(0, Timeline.V_MAX), grind = rng:int(1, 2) == 1 }
				tNow += rng:int(if family == "PrecisionTrace" then 1 else 0, 900)
			end
			local junk = buffer.create(rng:int(0, 40))
			for o = 0, buffer.len(junk) - 1 do
				buffer.writeu8(junk, o, rng:int(0, 255))
			end
			if buffer.len(junk) >= 2 and rng:int(1, 2) == 1 then
				buffer.writeu8(junk, 0, 1)
				buffer.writeu8(junk, 1, MF.FAMILY_CODE[family])
			end
			return { family = family, durationMs = D, hash = rng:u32(), records = records, junk = junk }
		end, function(c: Case)
			local before = copy(c.records)
			local b = Timeline.encode(c.family, c.durationMs, c.hash, c.records)
			local bytes = buffer.tostring(b)
			A.eq(buffer.tostring(Timeline.encode(c.family, c.durationMs, c.hash, c.records)), bytes, "P-DET encode")
			deepEqFast(c.records, before, "P-NOMUT encode")
			local records, h = Timeline.decode(b, c.family, c.durationMs)
			A.eq(buffer.tostring(b), bytes, "P-NOMUT decode")
			deepEqFast(Timeline.decode(b, c.family, c.durationMs), records, "P-DET decode")
			deepEqFast(records, c.records, "decode(encode(r)) = r")
			A.eq(h, c.hash)
			honestTimeline(c.family, records :: { any }, c.durationMs, "P-RANGE")
			local values: { any } = { c.junk, buffer.tostring(c.junk), c.durationMs, c.records, true }
			for _, v in values do
				local ok, out, why = pcall(Timeline.decode, v, c.family, c.durationMs)
				A.truthy(ok, "P-TOTAL: decode never throws")
				if out == nil then
					A.eq(type(why), "string", "a refusal names its reason")
				else
					honestTimeline(c.family, out, c.durationMs, "P-RANGE of a junk buffer that decodes")
				end
			end
		end)
	end)

	sized(t, "Minigames: P-DET, P-NOMUT, P-FINITE and P-RANGE for prepare, start, replay, judge and encode", function(n: number)
		type Case = { family: DT.FamilyId, material: DT.MaterialId, tier: DT.TierId, x: number, seed: number, edge: string?,
			run: number }
		Prop.check(n, function(rng: TestRng.TestRng): Case
			local family: DT.FamilyId = FAMILIES[rng:int(1, 3)]
			local material: DT.MaterialId = MATERIALS[rng:int(1, #MATERIALS)]
			local tier: DT.TierId = TIERS[rng:int(1, #TIERS)]
			return { family = family, material = material, tier = tier, x = rng:range(-0.2, 1.2), seed = rng:u32(),
				edge = if rng:int(1, 5) == 1 then nil else rng:pick(Edges.order), run = rng:u32() }
		end, function(c: Case)
			local input = H.inputFor(c.family, c.material, c.tier, c.x, c.seed, if c.edge then (Edges :: any)[c.edge] else nil)
			local inputBefore = copy(input)
			local spec, P = Minigames.prepare(input)
			local spec2, P2 = Minigames.prepare(input)
			deepEqFast(spec2, spec, "P-DET prepare: the spec")
			deepEqFast(P2, P, "P-DET prepare: the pattern")
			deepEqFast(input, inputBefore, "P-NOMUT prepare")
			A.truthy(isU32(spec.patternHash), "the hash is a u32")
			A.truthy(spec.durationMs > 0 and math.floor(spec.durationMs) == spec.durationMs, "an integer duration")
			for name, v in spec.params do
				A.finite(v, "P-FINITE params." .. name)
			end
			local again, err = Minigames.start(spec)
			A.eq(err, nil, "start")
			deepEqFast(again, P, "start = prepare's pattern")
			local records = H.randomRecords(TestRng.new(c.run), c.family, P)
			local recordsBefore = copy(records)
			local result = Minigames.replay(spec, P, records)
			deepEqFast(Minigames.replay(spec, P, records), result, "P-DET replay")
			deepEqFast(records, recordsBefore, "P-NOMUT replay")
			A.eq(result.status, "Ok")
			A.within(result.rawScore, 0, 1, "P-RANGE rawScore")
			A.within(result.score, 0, result.rawScore, "P-RANGE score")
			A.eq(result.rawScore, math.round(result.rawScore * 10000) / 10000, "on the q grid")
			for name, v in result.breakdown do
				A.finite(v, "P-FINITE breakdown." .. name)
			end
			local allowed = flagsOf(c.family)
			for _, f in ipairs(result.flags) do
				A.truthy(allowed[f], c.family .. " raises " .. f)
			end
			local b = Minigames.encode(spec, records)
			local bytes = buffer.tostring(b)
			A.eq(buffer.tostring(Minigames.encode(spec, records)), bytes, "P-DET encode")
			local judged = Minigames.judge(spec, P, b, 5)
			deepEqFast(Minigames.judge(spec, P, b, 5), judged, "P-DET judge")
			A.eq(buffer.tostring(b), bytes, "P-NOMUT judge: the buffer")
			deepEqFast(judged, with(result, { elapsedMs = 5 }), "judge = replay on an honest timeline")
		end)
	end)

	t.it("Minigames.judge: P-TOTAL, any value as the timeline gives a result: Invalid with a reason, never an error", function()
		local spec, P = H.prepared("TimingStrike", "Iron", "Hard", 0.3, 1)
		Prop.check(Tol.PROP_N, function(rng: TestRng.TestRng): any
			local pick = rng:int(1, 4)
			if pick == 1 then
				local values: { any } = { "abc", 12, true, {}, { 1, 2 }, math.huge }
				return rng:pick(values)
			end
			local b = buffer.create(rng:int(0, 64))
			for o = 0, buffer.len(b) - 1 do
				buffer.writeu8(b, o, if rng:int(1, 3) == 1 then rng:int(0, 255) else rng:int(0, 3))
			end
			if buffer.len(b) >= 12 and pick >= 3 then
				buffer.writeu8(b, 0, 1)
				buffer.writeu8(b, 1, 2)
				buffer.writeu16(b, 2, (buffer.len(b) - 12) // 2)
				buffer.writeu32(b, 4, spec.durationMs)
				if pick == 4 then
					buffer.writeu32(b, 8, spec.patternHash)
				end
			end
			return b
		end, function(v: any)
			local ok, result = pcall(Minigames.judge, spec, P, v, 0)
			A.truthy(ok, "never throws: " .. tostring(result))
			if result.status == "Invalid" then
				A.eq(type(result.invalidReason), "string", "a reason")
				A.eq(result.score, 0)
			else
				A.within(result.rawScore, 0, 1, "an Ok result's score")
			end
		end)
	end)

	sized(t, "Input: the same calls give the same records (P-DET); times in the step, points in the panel, caps held (P-RANGE)", function(n: number)
		type Case = { family: DT.FamilyId, durationMs: number, offset: number, seed: number }
		Prop.check(n, function(rng: TestRng.TestRng): Case
			local family: DT.FamilyId = FAMILIES[rng:int(1, 3)]
			return { family = family, durationMs = rng:int(0, 32000), offset = rng:int(-120, 120), seed = rng:u32() }
		end, function(c: Case)
			local spec = { family = c.family, seed = 1, params = {}, source = nil, durationMs = c.durationMs,
				countdownMs = 3000, patternHash = 0, balanceVersion = 1 }
			-- one random script of calls, before and after go, clocks mostly forward, played twice
			local function play(): { any }
				local rng = TestRng.new(c.seed)
				local rec = Input.new(spec, c.offset, 50)
				local clock = 50 + rng:range(-0.5, 0.2)
				for _ = 1, rng:int(1, 1500) do
					local k = rng:int(1, 12)
					if k == 1 then
						rec:go(rng:int(1, 2) == 1, rng:range(-1, 4), rng:range(-1, 2), if rng:int(1, 3) == 1 then nil else true)
					elseif k <= 5 then
						rec:button(rng:int(1, 2) == 1, clock, rng:range(0, 0.1))
					elseif k <= 9 then
						rec:cursor(rng:range(-1, 4), rng:range(-1, 2), rng:int(1, 2) == 1, clock)
					elseif k == 10 then
						rec:release()
					elseif k == 11 then
						rec:horizonMs(clock, rng:range(0, 0.1))
					else
						rec:since(rng:int(0, 50))
					end
					clock += if rng:int(1, 30) == 1 then -rng:range(0, 0.2) else rng:range(0, 0.06)
				end
				return rec:records()
			end
			local records = play()
			deepEqFast(play(), records, "P-DET")
			honestTimeline(c.family, records, c.durationMs, "P-RANGE")
			if c.family == "PrecisionTrace" then
				A.truthy(#records <= math.floor(c.durationMs / PrecisionTrace.PT_EVAL_MS) + 1, "the trace's cap (L6)")
			end
			A.eq(#(Timeline.decode(Timeline.encode(c.family, c.durationMs, 0, records), c.family, c.durationMs) :: { any }),
				#records, "the timeline decodes")
		end)
	end)

	sized(t, "Bots: P-DET for play and run (the same seed, the same records and scores); P-FINITE and P-RANGE of their results", function(n: number)
		type Case = { family: DT.FamilyId, material: DT.MaterialId, tier: DT.TierId, x: number, who: number, fps: number,
			seed: number, botSeed: number, offset: number }
		local NAMES = { "Elite", "Good", "Average", "Poor", "Perfect", "Exact", "Idle" }
		Prop.check(n, function(rng: TestRng.TestRng): Case
			local family: DT.FamilyId = FAMILIES[rng:int(1, 3)]
			local material: DT.MaterialId = MATERIALS[rng:int(1, 2)]
			local tier: DT.TierId = TIERS[rng:int(1, 2)]
			return { family = family, material = material, tier = tier, x = rng:float(), who = rng:int(1, #NAMES),
				fps = rng:pick({ 30, 60, 144 }), seed = rng:u32(), botSeed = rng:u32() * 37 + rng:int(0, 36), offset = rng:int(-120, 120) }
		end, function(c: Case)
			local spec, P = H.prepared(c.family, c.material, c.tier, c.x, c.seed, Edges.arming)
			local name = NAMES[c.who]
			local who: Bots.Who = if c.who <= 4 then Bots.variant((Bots.PROFILES :: any)[name], c.fps) else name :: any
			local opts = { offsetMs = c.offset, fps = if c.fps == 144 then 60 else c.fps }
			local records = Bots.play(spec, P, who, c.botSeed, opts)
			deepEqFast(Bots.play(spec, P, who, c.botSeed, opts), records, "P-DET play")
			A.truthy(table.isfrozen(records), "the Recorder's frozen copy")
			honestTimeline(c.family, records, spec.durationMs, "P-RANGE records")
			local result = Minigames.replay(spec, P, records)
			A.within(result.rawScore, 0, 1, "P-RANGE rawScore")
			A.eq(result.passed, result.score >= spec.params.passThreshold, "passed")
			for k, v in result.breakdown do
				A.finite(v, "P-FINITE breakdown." .. k)
			end
			if c.family ~= "PrecisionTrace" then
				-- run's determinism (a trace run costs 8 ms: the family's runs elsewhere, Reference's parity)
				local cell = { family = c.family, material = c.material, tier = c.tier, x = c.x, profile = name, n = 2,
					salt = c.seed, fps = c.fps, offsetMs = c.offset }
				local s1, p1, f1 = Bots.run(cell)
				local s2, p2, f2 = Bots.run(cell)
				deepEqFast({ s2, p2, f2 } :: { any }, { s1, p1, f1 } :: { any }, "P-DET run")
				for i = 1, 2 do
					A.within(s1[i], 0, 1, "P-RANGE run's rawScore")
				end
			end
		end)
	end)
end)
