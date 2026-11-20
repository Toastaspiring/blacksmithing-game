--!strict
-- Minigames/Minigames (SPEC §6.1, §6.2, §10.5, §14.9; T-MG-01, T-MG-02, T-MG-08's judge level, T-MG-09, T-MG-13 (b),
-- T-MG-14, M4's D8, D14 and L6): the facade. get and the re-export; prepare is deterministic and its StepSpec complete,
-- start rebuilds the pattern and desyncs on a changed seed, source or generation parameter, never on a scoring one;
-- passed ⇔ Ok ∧ score ≥ the pass line, at the boundary, on random honest records and on every bot's runs; every
-- malformed, flooded or replayed timeline is Invalid with its reason; judge is total on garbage; the trace's record cap
-- (L6); the HIGH clamp, scripted and on the bots' cheats; live = judge on bot timelines, pushed in any order §6.4 rule 7
-- allows and played again through a Recorder and S6's host loop (T-MG-09); golden (b), minigames.bv1, over every
-- config's pattern and the results of scripted and frozen bot timelines (D14: never a live bot run); and S2's real
-- output (F5, C02 from Analyze.run) prepared, started and judged, with no Physics value asserted (L1).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Cheats = require("../lib/Cheats")
local Gen = require("../lib/Gen")
local Golden = require("../lib/Golden")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Blueprints = require("../fixtures/Blueprints")
local Calibration = require("../fixtures/Calibration")
local Edges = require("../fixtures/Edges")
local MinigameTimelines = require("../fixtures/MinigameTimelines")
local H = require("./MinigamesHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local MF = require("../../src/shared/Definitions/MinigameFamilies")
local Network = require("../../src/shared/Definitions/Network")
local DT = require("../../src/shared/Definitions/Types")
local Versions = require("../../src/shared/Definitions/Versions")
local Bots = require("../../src/shared/Minigames/Bots")
local Checks = require("../../src/shared/Minigames/Checks")
local HoldZone = require("../../src/shared/Minigames/HoldZone")
local Minigames = require("../../src/shared/Minigames/Minigames")
local Params = require("../../src/shared/Minigames/Params")
local PrecisionTrace = require("../../src/shared/Minigames/PrecisionTrace")
local Timeline = require("../../src/shared/Minigames/Timeline")
local TimingStrike = require("../../src/shared/Minigames/TimingStrike")
local Types = require("../../src/shared/Minigames/Types")
local Analyze = require("../../src/shared/Physics/Analyze")

type StepSpec = Types.StepSpec
type MinigameResult = Types.MinigameResult

local CHEATS = Cheats.new({ Timeline = Timeline, MinigameFamilies = MF, Minigames = Minigames, Bots = Bots })
local CTX = Gen.context(Limits, EquipmentTypes.get("Sword") :: any, Materials.enabled, Versions.BLUEPRINT_SCHEMA,
	Balance.Geometry)
local SEEDS = { 0, 1, 0xDEADBEEF, 0xFFFFFFFF }
local SPEC_KEYS = { "balanceVersion", "countdownMs", "durationMs", "family", "params", "patternHash", "seed", "source" }
local GOLDEN_SEEDS = { 1, 2, 0xDEADBEEF, 0xFFFFFFFF } -- golden (b)'s (M4's plan [6.5])
local OFFSETS = { -120, -60, 0, 60, 120 }
-- T-MG-09's runs per family in the quick run (L5's 3 s share; its slow case runs 1,000, the plan's [6.3])
local T_MG_09_FAST = { HoldZone = 20, TimingStrike = 30, PrecisionTrace = 6 }

-- a record's time: TimingStrike's record is the press time
local function timeOf(r: any): number
	return if type(r) == "number" then r else r.t
end

-- deep equality, numbers bit for bit, building no string (A.deepEq only words a failure: it is slow on whole paths)
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

-- a copy with some fields replaced (a spec or params table is frozen)
local function with(t: { [string]: any }, changes: { [string]: any }): any
	local out = table.clone(t)
	for k, v in changes do
		out[k] = v
	end
	return out
end

-- a short honest timeline for a pattern: presses on the first targets, 80 ms taps every 300 ms from GO, samples on
-- the pacer every 20 ms
local function honest(family: DT.FamilyId, P: any): { any }
	if family == "TimingStrike" then
		return H.presses(P, { 0, 4, -9, 17, false, 2 })
	elseif family == "HoldZone" then
		return H.taps(P.durationMs, 300, 80)
	end
	return H.onPacer(P, 20)
end

-- the client's own score for records: a session pushed every record, then finished (what Submit sends as clientScore)
local function clientScore(family: DT.FamilyId, P: any, records: { any }): number
	local F = Minigames.get(family)
	local S = F.newSession(P)
	for _, r in ipairs(records) do
		F.push(S, r)
	end
	return F.finish(S).score
end

local function invalidAs(result: MinigameResult, reason: string, elapsedMs: number, what: string)
	A.eq(result.status, "Invalid", what)
	A.eq(result.invalidReason, reason, what)
	A.eq(result.score, 0, what .. ": score")
	A.eq(result.rawScore, 0, what .. ": rawScore")
	A.eq(result.passed, false, what .. ": passed")
	A.deepEq(result.flags, {}, what .. ": flags")
	A.deepEq(result.breakdown, {}, what .. ": breakdown")
	A.eq(result.elapsedMs, elapsedMs, what .. ": elapsedMs")
end

-- an Ok result's numbers are finite and in range
local function okFinite(result: MinigameResult, pass: number, what: string)
	A.eq(result.status, "Ok", what)
	A.within(result.rawScore, 0, 1, what .. ": rawScore")
	A.within(result.score, 0, result.rawScore, what .. ": score")
	A.eq(result.passed, result.score >= pass, what .. ": passed")
	for name, v in result.breakdown do
		A.finite(v, what .. ": breakdown." .. name)
	end
end

-- a property case at PROP_N_FAST cases in the quick run and PROP_N under t.slow
local function sized(t: Test.Api, name: string, body: (n: number) -> ())
	t.it(name, function()
		body(Tol.PROP_N_FAST)
	end)
	t.slow(name .. " (PROP_N cases)", function()
		body(Tol.PROP_N)
	end)
end

-- a fuzz case at FUZZ_N_STRUCT_FAST values in the quick run and FUZZ_N_GARBAGE under t.slow (D10)
local function fuzzSized(t: Test.Api, name: string, body: (n: number) -> ())
	t.it(name, function()
		body(Tol.FUZZ_N_STRUCT_FAST)
	end)
	t.slow(name .. " (FUZZ_N_GARBAGE)", function()
		body(Tol.FUZZ_N_GARBAGE)
	end)
end

-- The physical actions behind a bot timeline, for S6's host loop on another device: a press at each TimingStrike
-- record (released 30 ms later), each HoldZone state change, and the trace's cursor at the last sample at or before f
-- (the first before it), in panel units with its grind state
local function actionsOf(family: DT.FamilyId, records: { any }): ({ H.Action }, ((number) -> (number, number, boolean))?)
	local buttons: { H.Action } = {}
	if family == "TimingStrike" then
		for i, t in ipairs(records) do
			table.insert(buttons, { t = t, down = true })
			local nextT = records[i + 1]
			table.insert(buttons, { t = if nextT then math.min(t + 30, (t + nextT) / 2) else t + 30, down = false })
		end
		return buttons, nil
	elseif family == "HoldZone" then
		for _, r in ipairs(records) do
			table.insert(buttons, { t = r.t, down = r.down })
		end
		return buttons, nil
	end
	local Q = PrecisionTrace.PT_FIXED_POINT
	local k = 1
	return buttons, function(f: number): (number, number, boolean)
		while k < #records and records[k + 1].t <= f do
			k += 1
		end
		local r = records[k]
		return r.u / Q, r.v / Q, r.grind
	end
end

-- T-MG-09 on n runs of a family, the pinned name "T-MG-09 <family>" (D11): a bot's timeline (a profile or Perfect, on
-- either tier and material; TimingStrike at a random timing offset) is judged, then (a) pushed into a live session and
-- advanced in a random order that keeps §6.4 rule 7 (every record with t < h pushed before advance(h)), with views
-- between, and finished; (b) its physical actions played again on another device through a Recorder and S6's host
-- loop (H.play: the horizon, the final push). Each live finish is its judge's rawScore, bit for bit, and replay's.
-- Returns the timelines' byte sizes: min, mean and max (E-S3.6's).
local function tmg09(family: DT.FamilyId, n: number): (number, number, number)
	local salt = H.configSalt("T-MG-09 " .. family)
	local F = Minigames.get(family)
	local who: { Bots.Who } = { Bots.PROFILES.Elite, Bots.PROFILES.Good, Bots.PROFILES.Average, Bots.PROFILES.Poor,
		"Perfect" }
	local low, sum, high = math.huge, 0, 0
	for i = 1, n do
		local seed = Bots.seedOf(i, salt)
		local rng = TestRng.new(seed)
		local tier: DT.TierId = H.TIERS[rng:int(1, 2)]
		local material: DT.MaterialId = H.MATERIALS[rng:int(1, 2)]
		local spec, P = H.prepared(family, material, tier, (Bots.BOT_REF_X :: any)[tier], seed, Edges.arming)
		local D = spec.durationMs
		local offset = if family == "TimingStrike" then OFFSETS[rng:int(1, #OFFSETS)] else 0
		local records = Bots.play(spec, P, who[rng:int(1, #who)], i * 7919 + salt * 31 + 17, { offsetMs = offset })
		local what = string.format("T-MG-09 %s run %d (%s/%s)", family, i, material, tier)
		local b = Minigames.encode(spec, records)
		low, sum, high = math.min(low, buffer.len(b)), sum + buffer.len(b), math.max(high, buffer.len(b))
		local judged = Minigames.judge(spec, P, b, 0)
		A.eq(judged.status, "Ok", what)
		A.eq(Minigames.replay(spec, P, records).rawScore, judged.rawScore, what .. ": replay = judge")
		-- (a) the session level
		local S = F.newSession(P)
		local k, h = 1, 0
		while h <= D + 60 do
			h += rng:range(1, 40) + (if rng:int(1, 30) == 1 then rng:range(0, 120) else 0)
			local now = math.floor(h)
			while k <= #records and (timeOf(records[k]) < now or rng:int(1, 6) == 1) do
				F.push(S, records[k])
				k += 1
			end
			F.advance(S, now)
			if rng:int(1, 8) == 1 then
				F.view(S, now)
			end
		end
		for j = k, #records do
			F.push(S, records[j])
		end
		A.eq(F.finish(S).score, judged.rawScore, what .. ": (a) the live session = the judge, bit for bit")
		-- (b) end to end, on a 30–144 fps device with hitches; HoldZone ends on a press after the last frame
		local buttons, cursor = actionsOf(family, records)
		if family == "HoldZone" and (#buttons == 0 or not buttons[#buttons].down) then
			table.insert(buttons, { t = D - 4, down = true })
		end
		local played = H.play(spec, P, { frames = H.frames(rng, D, rng:range(7, 33), 34, 120), offsetMs = offset,
			buttons = buttons, cursor = cursor, viewEvery = 20 })
		local again = Minigames.judge(spec, P, Minigames.encode(spec, played.records), 0)
		A.eq(again.status, "Ok", what .. ": (b) the replayed device's timeline")
		A.eq(played.finish.score, again.rawScore, what .. ": (b) S6's host loop = the judge, bit for bit")
	end
	return low, sum / n, high
end

-- Golden (b)'s value (M4's plan [6.5]): every config's pattern at GOLDEN_SEEDS (its duration and hash and its shape),
-- the results of scripted timelines per family and tier, and of the 24 frozen bot timelines (D14)
local function goldenB(): any
	local patterns: { [string]: any } = {}
	for fi = 1, #H.FAMILIES do
		local family: DT.FamilyId = H.FAMILIES[fi]
		for mi = 1, #H.MATERIALS do
			local material: DT.MaterialId = H.MATERIALS[mi]
			for ti = 1, #H.TIERS do
				local tier: DT.TierId = H.TIERS[ti]
				for _, x in H.XS do
					for _, seed in GOLDEN_SEEDS do
						local spec, P = H.prepared(family, material, tier, x, seed, Edges.arming)
						local row: { [string]: any } = { durationMs = spec.durationMs, patternHash = spec.patternHash }
						if family == "HoldZone" then
							row.keys = #P.keysT
						elseif family == "TimingStrike" then
							row.N, row.M, row.W, row.core = #P.cycles, P.M, P.W, P.core
						else
							row.points, row.L, row.travelMs, row.usedFallback = #P.pu, P.L, P.travelMs, P.usedFallback
						end
						patterns[string.format("%s %s %s x=%s seed=%d", family, material, tier, tostring(x), seed)] = row
					end
				end
			end
		end
	end
	local scripted: { [string]: any } = {}
	for ti = 1, #H.TIERS do
		local tier: DT.TierId = H.TIERS[ti]
		local function add(family: DT.FamilyId, name: string, timeline: (P: any) -> { any })
			local spec, P = H.prepared(family, "Iron", tier, 0, 1, Edges.arming)
			scripted[string.format("%s %s %s", family, tier, name)] = Minigames.judge(spec, P,
				Minigames.encode(spec, timeline(P)), 0)
		end
		add("TimingStrike", "E-S3.4's presses", function(P: any): { any }
			return H.presses(P, { 0, 6, -15, 35, 79, false, -81, 0, 0, 0, 0, 0 })
		end)
		add("TimingStrike", "exact presses", function(P: any): { any }
			return H.presses(P, { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 })
		end)
		add("HoldZone", "taps every 300 ms, 80 ms", function(P: any): { any }
			return H.taps(P.durationMs, 300, 80)
		end)
		add("HoldZone", "taps every 200 ms, 50 ms", function(P: any): { any }
			return H.taps(P.durationMs, 200, 50)
		end)
		add("PrecisionTrace", "on the pacer every 20 ms", function(P: any): { any }
			return H.onPacer(P, 20)
		end)
		add("PrecisionTrace", "every 60 ms, 0.003 u off", function(P: any): { any }
			local out: { Types.TraceRecord } = {}
			for _, r in ipairs(H.onPacer(P, 60)) do
				table.insert(out, { t = r.t, u = r.u, v = math.min(r.v + 49, 16384), grind = true })
			end
			return out
		end)
	end
	local bots: { [string]: any } = {}
	for _, e in ipairs(MinigameTimelines.entries) do
		local spec, P = H.prepared(e.family :: DT.FamilyId, e.material :: DT.MaterialId, e.tier :: DT.TierId, e.x, e.seed,
			if e.family == "PrecisionTrace" then Edges.arming else nil)
		bots[string.format("%s %s %s %s", e.family, e.tier, e.material, e.profile)] = Minigames.judge(spec, P,
			MinigameTimelines.bytes(e.hex), 0)
	end
	return { patterns = patterns, scripted = scripted, bots = bots }
end

return Test.suite("Minigames/Minigames", function(t)
	t.it("get: each MVP family's module; none for the Phase 2 rows; TS_OFFSET_OFFER_MIN_JUDGED re-exported for S6", function()
		-- typed: luau-lsp checks the facade's registry type
		local F: Types.FamilyModule<any, any, any, any> = Minigames.get("HoldZone")
		A.eq(F, HoldZone)
		A.eq(Minigames.get("TimingStrike"), TimingStrike)
		A.eq(Minigames.get("PrecisionTrace"), PrecisionTrace)
		for _, family in { "RhythmSequence", "ReleaseTiming", "FitPuzzle" } do
			A.throws(function()
				Minigames.get(family :: any)
			end, "no minigame module", family)
			A.throws(function()
				Minigames.prepare(H.inputFor(family :: any, "Iron", "Normal", 0, 1))
			end, "no minigame module", family)
		end
		A.eq(Minigames.TS_OFFSET_OFFER_MIN_JUDGED, TimingStrike.TS_OFFSET_OFFER_MIN_JUDGED)
		A.eq(Minigames.TS_OFFSET_OFFER_MIN_JUDGED, 8)
	end)

	t.it("T-MG-01 prepare is deterministic, its StepSpec complete and frozen; start rebuilds the pattern; judge twice agrees", function()
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			for mi = 1, #H.MATERIALS do
				local material: DT.MaterialId = H.MATERIALS[mi]
				for ti = 1, #H.TIERS do
					local tier: DT.TierId = H.TIERS[ti]
					for _, x in H.XS do
						for _, seed in SEEDS do
							local what = string.format("%s %s/%s x = %s seed %d", family, material, tier, tostring(x), seed)
							local input = H.inputFor(family, material, tier, x, seed, Edges.arming)
							local spec, P = Minigames.prepare(input)
							local spec2, P2 = Minigames.prepare(input)
							deepEqFast(spec2, spec, what .. ": P-DET spec")
							deepEqFast(P2, P, what .. ": P-DET pattern")
							for k in spec :: any do
								A.truthy(table.find(SPEC_KEYS, k) ~= nil, what .. ": a StepSpec field " .. tostring(k))
							end
							A.eq(spec.family, family, what)
							A.eq(spec.seed, seed, what)
							deepEqFast(spec.params, Params.resolve(family, material, tier, input.factors), what .. ": params")
							A.eq(spec.durationMs, P.durationMs, what .. ": durationMs")
							A.eq(spec.countdownMs, Network.COUNTDOWN_MS, what .. ": countdownMs")
							A.eq(spec.patternHash, Minigames.get(family).hash(P), what .. ": patternHash")
							A.eq(spec.balanceVersion, Versions.BALANCE_VERSION, what .. ": balanceVersion")
							A.eq(spec.source ~= nil, family == "PrecisionTrace", what .. ": a source for the trace only")
							A.truthy(table.isfrozen(spec) and table.isfrozen(spec.params), what .. ": frozen")
							local again, err = Minigames.start(spec)
							A.eq(err, nil, what .. ": start")
							deepEqFast(again, P, what .. ": start rebuilds the pattern")
							if seed == 1 then
								local b = Minigames.encode(spec, honest(family, P))
								deepEqFast(Minigames.judge(spec, P, b, 0), Minigames.judge(spec, P, b, 0), what .. ": judge")
							end
						end
					end
				end
			end
		end
		-- the input's balance version, whatever it is
		local versioned = H.inputFor("HoldZone", "Iron", "Normal", 0, 1)
		versioned.balanceVersion = 7
		A.eq(Minigames.prepare(versioned).balanceVersion, 7, "balanceVersion is the input's")
		-- no edge, or one with no usable side: the fallback plays and the spec carries no source
		local spec, P = H.prepared("PrecisionTrace", "Iron", "Normal", 0, 1)
		A.eq(spec.source, nil, "no edge")
		A.truthy(P.usedFallback, "the fallback")
		local flat = { name = "flat", chains = { { points = { { 0.1, 2 }, { 0.1, 2 } }, length = 0 } },
			gripPoint = { 0, 0.88, 0 }, gripAxis = { 0, 1 } }
		local specFlat, PFlat = H.prepared("PrecisionTrace", "Iron", "Normal", 0, 1, flat)
		A.eq(specFlat.source, nil, "an edge with no usable side")
		A.truthy(PFlat.usedFallback, "the fallback")
		A.eq(specFlat.patternHash, spec.patternHash, "the same fallback pattern")
		-- a chain whose mapped length is 0.4000028 u before the 1/16384 rounding and 0.39996 after: the hand-off keeps it
		-- (its bound is before rounding), generate plays the fallback (its bound is after), so prepare drops the source
		local edge = { name = "at the bound", chains = { { points = { { 0, 0.88 }, { 0.005740714073181153, 1.5465725111961365 } },
			length = 0 } }, gripPoint = { 0, 0, 0 }, gripAxis = { 0, 1 } }
		local p = Params.resolve("PrecisionTrace", "Iron", "Normal", Params.refFactors(0))
		local handed = PrecisionTrace.edgeToPanel(PrecisionTrace.sidesFromChains(edge.chains, edge.gripPoint, edge.gripAxis),
			edge.gripPoint, edge.gripAxis, p.pacerSpeed)
		A.deepEq(handed, { 21300, 8136, 27852, 8248 }, "the hand-off's source")
		local specBound, PBound = H.prepared("PrecisionTrace", "Iron", "Normal", 0, 1, edge)
		A.truthy(PBound.usedFallback, "generate plays the fallback")
		A.eq(specBound.source, nil, "so the spec carries no source")
		A.eq(specBound.patternHash, spec.patternHash, "the fallback pattern")
		A.eq(Minigames.get("PrecisionTrace").hash((Minigames.start(specBound))), spec.patternHash, "start agrees")
	end)

	t.it("prepare hands Sharpening its edge as §6.10 maps it, on every reference blade; the tilted grip plays arming's", function()
		local arming: { number }? = nil
		for _, name in ipairs(Edges.order) do
			local e: Edges.Edge = (Edges :: any)[name]
			local spec, P = H.prepared("PrecisionTrace", "Steel", "Hard", 0.3, 7, e)
			local expected = PrecisionTrace.edgeToPanel(PrecisionTrace.sidesFromChains(e.chains, e.gripPoint, e.gripAxis),
				e.gripPoint, e.gripAxis, spec.params.pacerSpeed)
			A.truthy(expected ~= nil, name .. " has a source (E-S3.5)")
			A.deepEq(spec.source, expected, name .. ": the hand-off at the step's pacer speed")
			A.falsy(P.usedFallback, name .. ": its own edge plays")
			if name == "arming" then
				arming = spec.source
			elseif name == "tilted" then
				A.deepEq(spec.source, arming, "the grip tilted 30° gives arming's source")
			end
		end
	end)

	t.it("T-MG-01 start desyncs on another seed, a moved source point or a nudged generation parameter, not a scoring one", function()
		local generation = { HoldZone = "driftSpeed", TimingStrike = "beatMs", PrecisionTrace = "perturbAmp" }
		local scoring = { "zoneWidth", "windowMs", "halfWidth", "passThreshold" }
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			for _, seed in { 1, 0xDEADBEEF } do
				local spec = H.prepared(family, "Iron", "Normal", 0.3, seed, Edges.arming)
				local what = family .. " seed " .. seed
				local pattern, err = Minigames.start(with(spec, { seed = seed + 1 }))
				A.eq(pattern, nil, what .. ": seed + 1")
				A.eq(err, "Desync", what .. ": seed + 1")
				local name = generation[family]
				local _, errGen = Minigames.start(with(spec, { params = with(spec.params, { [name] = spec.params[name] * 1.05 }) }))
				A.eq(errGen, "Desync", what .. ": " .. name .. " × 1.05")
				if family == "PrecisionTrace" then
					local moved = table.clone(spec.source :: { number })
					moved[3] += 200
					local _, errSrc = Minigames.start(with(spec, { source = moved }))
					A.eq(errSrc, "Desync", what .. ": a source point moved")
				end
				-- the hash covers the pattern only, and the client plays params verbatim (§6.4 rule 5)
				for _, p in scoring do
					if spec.params[p] ~= nil then
						local again, errScore = Minigames.start(with(spec, { params = with(spec.params, { [p] = spec.params[p] * 1.1 }) }))
						A.eq(errScore, nil, what .. ": " .. p .. " × 1.1 does not desync")
						A.eq(Minigames.get(family).hash(again), spec.patternHash, what .. ": the same hash")
					end
				end
			end
		end
	end)

	t.it("T-MG-02 the pass line: 6 of 12 full-point presses score 0.5000 and pass; 5 and one 0.9851 press, 0.4988 and fail", function()
		local spec, P = H.prepared("TimingStrike", "Iron", "Normal", 0, 1)
		A.eq(#P.cycles, 12, "E-S3.4's N")
		local six = Minigames.judge(spec, P, Minigames.encode(spec, H.presses(P, { 0, 0, 0, 0, 0, 0 })), 0)
		A.eq(six.rawScore, 0.5, "6 / 12")
		A.eq(six.score, 0.5)
		A.truthy(six.passed, "0.5000 ≥ 0.50")
		A.deepEq(six.flags, {}, "under TS_MIN_JUDGED: no checks")
		local short = Minigames.judge(spec, P, Minigames.encode(spec, H.presses(P, { 0, 0, -15, 0, 0, false, 0 })), 0)
		A.eq(short.rawScore, 0.4988, "(5 + 0.9851) / 12")
		A.falsy(short.passed, "0.4988 < 0.50")
		A.eq(clientScore("TimingStrike", P, H.presses(P, { 0, 0, -15, 0, 0, false, 0 })), short.rawScore, "clientScore")
	end)

	t.it("T-MG-02 every malformed, flooded or replayed timeline is Invalid with its reason, scored 0 and never passed", function()
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			local spec, P = H.prepared(family, "Iron", "Normal", 0, 1, Edges.arming)
			for _, reason in CHEATS.reasons(family) do
				for k, v in CHEATS.malformed(spec, reason) do
					invalidAs(Minigames.judge(spec, P, v, 1234), reason, 1234, string.format("%s %s #%d", family, reason, k))
				end
			end
			local flood = CHEATS.flood(spec)
			invalidAs(Minigames.judge(spec, P, flood.overCount, 0), "TooMany", 0, family .. " flood")
			invalidAs(Minigames.judge(spec, P, flood.overLength, 0), "TooMany", 0, family .. " flood past the cap")
			local wrong = Timeline.encode(family, spec.durationMs, (spec.patternHash + 1) % 4294967296, honest(family, P))
			invalidAs(Minigames.judge(spec, P, wrong, 0), "HashMismatch", 0, family .. " another hash")
		end
	end)

	sized(t, "T-MG-02 random honest records: passed ⇔ Ok ∧ score ≥ pass line, HIGH flags clamp, clientScore = rawScore", function(n: number)
		type Case = { family: DT.FamilyId, material: DT.MaterialId, tier: DT.TierId, x: number, seed: number, run: number }
		Prop.check(n, function(rng: TestRng.TestRng): Case
			local family: DT.FamilyId = H.FAMILIES[rng:int(1, 3)]
			local material: DT.MaterialId = H.MATERIALS[rng:int(1, 2)]
			local tier: DT.TierId = H.TIERS[rng:int(1, 2)]
			return { family = family, material = material, tier = tier, x = rng:range(0, 1), seed = rng:u32(), run = rng:u32() }
		end, function(c: Case)
			local e: Edges.Edge = (Edges :: any)[Edges.order[c.run % #Edges.order + 1]]
			local spec, P = H.prepared(c.family, c.material, c.tier, c.x, c.seed, e)
			local records = H.randomRecords(TestRng.new(c.run), c.family, P)
			local result = Minigames.judge(spec, P, Minigames.encode(spec, records), 7)
			local pass = spec.params.passThreshold
			okFinite(result, pass, "judge")
			A.eq(result.passed, result.rawScore >= pass, "passed ⇔ rawScore ≥ pass line (T-MG-14)")
			local high = Checks.anyHigh(c.family, result.flags)
			A.eq(result.score, if high then math.min(result.rawScore, pass) else result.rawScore, "the clamp")
			A.deepEq(Checks.sorted(result.flags), result.flags, "flags sorted by id")
			A.eq(result.elapsedMs, 7, "elapsedMs copied in")
			A.eq(clientScore(c.family, P, records), result.rawScore, "the client's finish = rawScore")
		end)
	end)

	fuzzSized(t, "T-MG-08 judge never throws: garbage values and structured buffers give Ok or Invalid with a reason", function(n: number)
		local rng = TestRng.new(0x1ADE0008)
		local garbage: { any } = {}
		for i = 1, n do
			garbage[i] = Gen.garbage(rng, CTX)
		end
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			local spec, P = H.prepared(family, "Iron", "Hard", 0.3, 1, Edges.arming)
			local reasons = CHEATS.reasons(family)
			table.insert(reasons, "HashMismatch")
			local values: { any } = CHEATS.garbageBuffers(rng, spec, H.randomRecords(rng, family, P), n)
			for _, v in ipairs(garbage) do
				table.insert(values, v)
			end
			local oks = 0
			for k, v in values do
				local ok, result = pcall(Minigames.judge, spec, P, v, 0)
				A.truthy(ok, string.format("%s value %d: judge never throws: %s", family, k, tostring(result)))
				if result.status == "Ok" then
					oks += 1
					okFinite(result, spec.params.passThreshold, family .. " value " .. k)
				else
					A.truthy(table.find(reasons, result.invalidReason :: any) ~= nil, string.format("%s value %d: %s",
						family, k, tostring(result.invalidReason)))
					A.eq(result.score, 0)
				end
			end
			A.truthy(oks > 0, family .. ": some structured buffers judge Ok")
		end
	end)

	t.it("T-MG-08 the Replay cheat: one timeline twice judges alike; an old timeline on another seed's step is HashMismatch", function()
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			local spec1, P1 = H.prepared(family, "Iron", "Normal", 0, 1, Edges.arming)
			local spec2, P2 = H.prepared(family, "Iron", "Normal", 0, 2, Edges.arming)
			-- honest records that end before both steps do
			local endMs = math.min(spec1.durationMs, spec2.durationMs)
			local records: { any } = {}
			for _, r in honest(family, P1) do
				if (if type(r) == "number" then r else r.t) <= endMs then
					table.insert(records, r)
				end
			end
			local replayed = CHEATS.replay(spec1, records, spec2)
			A.eq(buffer.tostring(replayed.again), buffer.tostring(replayed.first), family .. ": the same bytes")
			local first = Minigames.judge(spec1, P1, replayed.first, 10)
			A.eq(first.status, "Ok", family)
			A.deepEq(Minigames.judge(spec1, P1, replayed.again, 10), first, family .. ": judged alike (S5: a duplicate)")
			invalidAs(Minigames.judge(spec2, P2, replayed.stale, 0), "HashMismatch", 0, family .. ": on seed 2's step")
			local asSent = Minigames.judge(spec2, P2, replayed.first, 0)
			A.eq(asSent.status, "Invalid", family .. ": the unchanged old timeline")
			A.eq(asSent.invalidReason, if spec1.durationMs == spec2.durationMs then "HashMismatch" else "Duration", family)
		end
	end)

	t.it("L6: judge refuses a trace with more records than floor(durationMs / PT_EVAL_MS) + 1 (TooMany, before the hash)", function()
		local spec, P = H.prepared("PrecisionTrace", "Iron", "Normal", 0, 1, Edges.arming)
		local cap = Minigames.recordCap(spec)
		A.eq(cap, math.floor(spec.durationMs / PrecisionTrace.PT_EVAL_MS) + 1, "the trace's cap")
		A.eq(cap, 610, "Edges.arming at Iron/Normal: 12,180 ms")
		local full = H.onPacer(P, 20)
		A.eq(#full, cap, "one sample per due time from GO")
		A.eq(Minigames.judge(spec, P, Minigames.encode(spec, full), 0).status, "Ok", "the honest maximum")
		local flood = CHEATS.flood(spec)
		local over = flood.overCap :: buffer
		A.eq(buffer.readu16(over, 2), cap + 1, "one record more")
		A.eq(#(Timeline.decode(over, "PrecisionTrace", spec.durationMs) :: { any }), cap + 1, "which decode accepts")
		invalidAs(Minigames.judge(spec, P, over, 0), "TooMany", 0, "cap + 1")
		buffer.writeu32(over, 8, (spec.patternHash + 1) % 4294967296)
		invalidAs(Minigames.judge(spec, P, over, 0), "TooMany", 0, "the cap before the hash")
		local others: { DT.FamilyId } = { "HoldZone", "TimingStrike" }
		for oi = 1, #others do
			local family: DT.FamilyId = others[oi]
			local s = H.prepared(family, "Iron", "Normal", 0, 1)
			A.eq(Minigames.recordCap(s), MF.MAX_RECORDS[family], family .. ": decode's cap")
			A.eq(CHEATS.flood(s).overCap, nil, family .. ": no tighter cap")
		end
	end)

	t.it("T-MG-14 the HIGH clamp on scripted input: exact presses pass at the line, 0-point ones fail, a medium flag clamps nothing", function()
		local spec, P = H.prepared("TimingStrike", "Iron", "Normal", 0, 1)
		local exact = H.presses(P, { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 })
		local r1 = Minigames.judge(spec, P, Minigames.encode(spec, exact), 0)
		A.deepEq(r1.flags, { "TsExactHits", "TsLowVariance" }, "both HIGH flags, sorted")
		A.eq(r1.rawScore, 1)
		A.eq(r1.score, 0.5, "clamped to the pass line")
		A.truthy(r1.passed, "a HIGH flag never fails a step")
		A.eq(clientScore("TimingStrike", P, exact), r1.rawScore, "clientScore = rawScore, unclamped")
		local late: { number | false } = {}
		for i = 1, #P.cycles do
			late[i] = P.W + 1
		end
		local zero = H.presses(P, late)
		local r2 = Minigames.judge(spec, P, Minigames.encode(spec, zero), 0)
		A.deepEq(r2.flags, { "TsLowVariance" }, "judged, all at W + 1: no spread")
		A.eq(r2.breakdown.judged, #P.cycles, "every press judged (W + 1 ≤ M)")
		A.eq(r2.rawScore, 0)
		A.eq(r2.score, 0)
		A.falsy(r2.passed, "failed by its raw score, not the flag")
		A.eq(clientScore("TimingStrike", P, zero), 0)
		-- a sparse trace, off the path by 0.003 u: PtSparse (medium) alone, so no clamp
		local specT, PT = H.prepared("PrecisionTrace", "Iron", "Normal", 0, 1, Edges.arming)
		local sparse: { Types.TraceRecord } = {}
		for _, r in ipairs(H.onPacer(PT, 60)) do
			table.insert(sparse, { t = r.t, u = r.u, v = math.min(r.v + 49, 16384), grind = true })
		end
		local r3 = Minigames.judge(specT, PT, Minigames.encode(specT, sparse), 0)
		A.deepEq(r3.flags, { "PtSparse" }, "medium only")
		A.eq(Checks.level("PrecisionTrace", "PtSparse"), "Medium")
		A.truthy(r3.rawScore > specT.params.passThreshold, "above the line, so a clamp would show")
		A.eq(r3.score, r3.rawScore, "not clamped")
		A.eq(clientScore("PrecisionTrace", PT, sparse), r3.rawScore, "clientScore = rawScore")
	end)

	t.it("encode is Timeline.encode with the spec's header; Cheats.fast's early timeline judges Ok; forged arguments", function()
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			local spec, P = H.prepared(family, "Steel", "Hard", 1, 0xDEADBEEF, Edges.flamberge)
			local records = honest(family, P)
			local b = Minigames.encode(spec, records)
			A.eq(buffer.tostring(b), buffer.tostring(Timeline.encode(family, spec.durationMs, spec.patternHash, records)), family)
			-- S5 refuses a submit before D − EARLY_TOL_MS by its time (§7.8); its timeline itself is honest
			local fast = CHEATS.fast(spec, records, Network.EARLY_TOL_MS)
			A.eq(fast.sendAtMs, spec.countdownMs + spec.durationMs - Network.EARLY_TOL_MS - 1, family .. ": sendAtMs")
			A.eq(Minigames.judge(spec, P, fast.timeline, 0).status, "Ok", family .. ": fast judges Ok")
		end
		local args = { sessionId = "0F1E2D3C-4B5A-6978-8796-A5B4C3D2E1F0", stepIndex = 2, timeline = buffer.create(12),
			clientScore = 0.5 }
		local forged = CHEATS.forged(args)
		A.eq(forged.extraKey.extraKey, true, "one key more")
		A.eq(forged.extraKey.sessionId, args.sessionId)
		A.truthy(forged.otherSession.sessionId ~= args.sessionId and #forged.otherSession.sessionId == #args.sessionId,
			"another session id")
		local noBots = Cheats.new({ Timeline = Timeline, MinigameFamilies = MF, Minigames = Minigames })
		A.throws(function()
			noBots.exact(nil, nil)
		end, "needs Bots")
	end)

	t.it("Cheats.exact is Bots' Exact: TimingStrike at the exact targets, unquantized; the others their Perfect", function()
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			local spec, P = H.prepared(family, "Iron", "Normal", 0.1, 4, Edges.arming)
			local exact = CHEATS.exact(spec, P)
			A.deepEq(exact, Bots.play(spec, P, "Exact", 0), family)
			if family == "TimingStrike" then
				A.deepEq(exact, H.presses(P, { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }), "a press at each target")
			else
				A.deepEq(exact, Bots.play(spec, P, "Perfect", 0), family .. ": Perfect's records")
			end
		end
	end)

	t.it("T-MG-02 with bots: every profile's runs pass ⇔ Ok ∧ score ≥ the line; Idle scores 0; Exact passes at the line, flagged", function()
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			for _, profile in { "Elite", "Good", "Average", "Poor", "Idle", "Exact" } do
				Bots.run({ family = family, material = "Steel", tier = "Hard", profile = profile, n = 1, salt = 2,
					edge = Edges.arming, each = function(i: number, spec: StepSpec, P: any, records: { any }, replayed: MinigameResult)
						local what = string.format("%s %s run %d", family, profile, i)
						local result = Minigames.judge(spec, P, Minigames.encode(spec, records), 0)
						A.deepEq(result, replayed, what .. ": judge = replay")
						local pass = spec.params.passThreshold
						A.eq(result.status, "Ok", what)
						A.eq(result.passed, result.score >= pass, what .. ": passed ⇔ score ≥ pass line")
						if profile == "Idle" then
							A.eq(result.rawScore, 0, what .. ": no input scores 0")
							A.falsy(result.passed, what)
						elseif profile == "Exact" then
							A.truthy(Checks.anyHigh(family, result.flags), what .. ": a HIGH flag")
							A.eq(result.score, pass, what .. ": clamped to the pass line")
							A.truthy(result.passed, what .. ": the flag never fails a step")
						else
							A.deepEq(result.flags, {}, what .. ": a human is never flagged (E-S3.2)")
						end
					end })
			end
		end
	end)

	t.it("T-MG-14 with bots: HoldZone's exact-state Perfect is clamped at the line and passes; the client's finish = rawScore", function()
		for ti = 1, #H.TIERS do
			local tier: DT.TierId = H.TIERS[ti]
			local spec, P = H.prepared("HoldZone", "Steel", tier, (Bots.BOT_REF_X :: any)[tier], 3)
			local records = Bots.play(spec, P, "Exact", 0)
			local result = Minigames.judge(spec, P, Minigames.encode(spec, records), 0)
			A.deepEq(result.flags, { "HzInhumanRate" }, tier .. ": strokes up to 50 per second")
			A.truthy(result.rawScore > spec.params.passThreshold, tier .. ": above the line, so the clamp shows")
			A.eq(result.score, spec.params.passThreshold, tier .. ": clamped")
			A.truthy(result.passed, tier)
			A.eq(clientScore("HoldZone", P, records), result.rawScore, tier .. ": clientScore = rawScore, unclamped")
		end
	end)

	t.it("T-MG-09 live session = judge on bot timelines: any push order §6.4 rule 7 allows, and S6's host loop on another device", function()
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			tmg09(family, (T_MG_09_FAST :: any)[family])
		end
	end)

	t.slow("T-MG-09 live session = judge on 1,000 bot timelines per family", function()
		local sizes: { string } = {}
		for fi = 1, #H.FAMILIES do
			local low, mean, high = tmg09(H.FAMILIES[fi], 1000)
			table.insert(sizes, string.format("%s %d / %.0f / %d", H.FAMILIES[fi], low, mean, high))
		end
		print("  T-MG-09 timeline bytes min / mean / max (E-S3.6's): " .. table.concat(sizes, ", "))
	end)

	t.it("T-MG-13 (b): golden minigames.bv1, every config's pattern and the results of scripted and frozen bot timelines", function()
		local value = goldenB()
		local count = 0
		for _ in value.patterns do
			count += 1
		end
		A.eq(count, 3 * 2 * 2 * 3 * #GOLDEN_SEEDS, "every config × the golden's seeds")
		for key, r in value.bots do
			A.eq(r.status, "Ok", key .. ": a frozen bot timeline judges Ok")
		end
		A.eq(value.scripted["TimingStrike Normal E-S3.4's presses"].rawScore, 0.8084, "E-S3.4's worked example")
		Golden.check("minigames.bv1", value)
	end)

	t.it("S2's real output: F5's and C02's steps from Analyze.run prepared, started and judged Ok (L1: no Physics value)", function()
		for _, core in { Blueprints.get("F5").core, Calibration.get("C02").core } do
			local analysis = Analyze.run(core :: any)
			local steps = analysis.steps :: { Analyze.StepAnalysis }
			A.truthy(steps ~= nil and #steps >= 3, "valid, with the MVP's steps")
			local families: { string } = {}
			for i = 1, #steps do
				local input = H.stepInputFrom(analysis, i, 1000 + i)
				local spec, P = Minigames.prepare(input)
				table.insert(families, spec.family)
				local again, err = Minigames.start(spec)
				A.eq(err, nil, spec.family)
				A.eq(Minigames.get(spec.family).hash(again), spec.patternHash, spec.family)
				local frames: { number } = {}
				for f = 7, spec.durationMs + 40, 16.7 do
					table.insert(frames, f)
				end
				local buttons: { H.Action } = {}
				if spec.family == "TimingStrike" then
					for _, c in ipairs((P :: TimingStrike.Pattern).cycles) do
						table.insert(buttons, { t = c.target + 30, down = true })
						table.insert(buttons, { t = c.target + 90, down = false })
					end
				elseif spec.family == "HoldZone" then
					for _, r in ipairs(H.taps(spec.durationMs, 330, 90)) do
						table.insert(buttons, r)
					end
				end
				local played = H.play(spec, P, { frames = frames, buttons = buttons, cursor = if spec.family
					== "PrecisionTrace" then function(f: number): (number, number, boolean)
						local u, v = PrecisionTrace.pointAt(P, PrecisionTrace.pacerArc(P, f - 80))
						return u, v, true
					end else nil })
				local judged = Minigames.judge(spec, P, Minigames.encode(spec, played.records), 0)
				A.eq(judged.status, "Ok", spec.family)
				A.eq(played.finish.score, judged.rawScore, spec.family .. ": the client's finish = rawScore")
			end
			A.truthy(table.find(families, "PrecisionTrace") ~= nil and table.find(families, "TimingStrike") ~= nil
				and table.find(families, "HoldZone") ~= nil, "Smelting, Hammering and Sharpening played")
		end
	end)
end)
