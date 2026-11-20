--!strict
-- Minigames/Bots (SPEC §6.12, §16.23, E-S3.2, E-S8.5; T-MG-11, M4's D7, D14 and L6): the player models. The profiles
-- are §6.12's table with the S3 prototype's policy fields; play is deterministic per seed; every timeline a bot makes
-- is one an unmodified client could send (decode gives it back, the judge accepts it, within its record caps); Perfect,
-- Exact (at its exact targets, D7) and Idle; Perfect at 30 fps on every run (T-MG-11, its minima those precomputed on
-- the prototype); the autoplay source (a record due at its own time); Bots.play still makes the frozen timelines of
-- tests/fixtures/MinigameTimelines (D14), and the libm canary says whether a difference there is this machine's C
-- runtime rather than the code.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Edges = require("../fixtures/Edges")
local MinigameTimelines = require("../fixtures/MinigameTimelines")
local H = require("./MinigamesHelpers")
local MF = require("../../src/shared/Definitions/MinigameFamilies")
local DT = require("../../src/shared/Definitions/Types")
local Bots = require("../../src/shared/Minigames/Bots")
local Minigames = require("../../src/shared/Minigames/Minigames")
local Rng = require("../../src/shared/Minigames/Rng")
local Timeline = require("../../src/shared/Minigames/Timeline")
local TimingStrike = require("../../src/shared/Minigames/TimingStrike")
local Types = require("../../src/shared/Minigames/Types")

-- Through a cast, so luau-lsp stays out of the prototype's loose types: it is reference data, not game code.
local ProtoBots: any = (require :: any)("../../docs/spec/prototypes/S3/v2/Bots")
local ProtoSim: any = (require :: any)("../../docs/spec/prototypes/S3/v2/Sim")

type StepSpec = Types.StepSpec

local NAMES = { "Elite", "Good", "Average", "Poor" }

-- §6.12's table, as the SPEC prints it (per profile: Elite, Good, Average, Poor)
local TABLE: { [string]: { number } } = {
	fps = { 60, 60, 60, 30 },
	hitchRate = { 0.003, 0.003, 0.003, 0.006 },
	sigmaMs = { 12, 25, 45, 90 },
	biasMeanMs = { 3, 5, 10, 25 },
	biasSdMs = { 5, 10, 15, 20 },
	lapse = { 0.005, 0.02, 0.05, 0.10 },
	extraPress = { 0, 0.02, 0.02, 0.04 },
	hzDelayMs = { 160, 210, 300, 380 },
	hzNoise = { 0.004, 0.008, 0.020, 0.035 },
	hzKPred = { 0.30, 0.22, 0.08, 0 },
	hzKZone = { 0.5, 0.3, 0, 0 },
	pumpPeriodMs = { 130, 140, 180, 220 },
	pumpJitterMs = { 20, 25, 40, 50 },
	pumpHoldMs = { 65, 70, 90, 110 },
	pumpHoldJitterMs = { 8, 10, 10, 15 },
	hzLapseRate = { 0, 0.01, 0.04, 0.08 },
	hzLapseMs = { 0, 400, 700, 900 },
	ptTauMs = { 70, 100, 160, 200 },
	ptCross = { 0.006, 0.012, 0.025, 0.038 },
	ptCrossTauS = { 0.30, 0.35, 0.40, 0.45 },
	ptLagMu = { -0.02, -0.04, -0.07, -0.09 },
	ptLagSigma = { 0.02, 0.04, 0.08, 0.11 },
	ptLagTauS = { 1.0, 1.0, 1.2, 1.4 },
	ptTremor = { 0.0012, 0.0015, 0.002, 0.003 },
	ptLiftRate = { 0, 0.003, 0.015, 0.025 },
	ptStartOff = { 0.005, 0.01, 0.03, 0.05 },
	ptLatePressMs = { 0, 150, 350, 500 },
}

-- T-MG-11's minima over the pinned names' runs, precomputed on the S3 prototype (M4-notes B4, L9): the first 50
-- runs (the fast case) and all SOLVABILITY_SEEDS (the slow one)
local T_MG_11_MIN: { [string]: { number } } = {
	["T-MG-11 Normal Iron x=0"] = { 0.9913, 0.9897 },
	["T-MG-11 Normal Iron x=1"] = { 0.9792, 0.9746 },
	["T-MG-11 Normal Steel x=0"] = { 0.9858, 0.9858 },
	["T-MG-11 Normal Steel x=1"] = { 0.9813, 0.9731 },
	["T-MG-11 Hard Iron x=0"] = { 0.9774, 0.9671 },
	["T-MG-11 Hard Iron x=1"] = { 0.9700, 0.9623 },
	["T-MG-11 Hard Steel x=0"] = { 0.9749, 0.9684 },
	["T-MG-11 Hard Steel x=1"] = { 0.9684, 0.9613 },
}
local T_MG_11_FAST = 50 -- runs per cell in the quick run

-- fnv1a32 over the %.17g text of this machine's math.log, math.cos and math.exp at the canary's inputs, blessed once on
-- 19 Nov 2026 (Windows 11, lune 0.8.9's UCRT). It changes when the C runtime does (D14): then the bots' records may
-- change too, while the judge, which uses no libm, cannot.
local LIBM_CANARY = 572967914

-- a record's time: TimingStrike's record is the press time
local function timeOf(r: any): number
	return if type(r) == "number" then r else r.t
end

-- a step and its pattern at Iron, the tier's reference x, the trace on the arming sword
local function stepOf(family: DT.FamilyId, tier: DT.TierId, seed: number, material: DT.MaterialId?): (StepSpec, any)
	return H.prepared(family, material or "Iron", tier, (Bots.BOT_REF_X :: any)[tier], seed,
		if family == "PrecisionTrace" then Edges.arming else nil)
end

-- the records judged as Submit judges them
local function judged(spec: StepSpec, P: any, records: { any }): Types.MinigameResult
	return Minigames.judge(spec, P, Minigames.encode(spec, records), 0)
end

-- the players the bot cases walk: the four profiles, two device variants and the extremes; in the quick run the trace's
-- human players are two (8 ms a run, L5's 3 s share): the slow case and the frozen timelines take the rest
local function players(family: DT.FamilyId, quick: boolean): { { name: string, who: Bots.Who } }
	local out: { { name: string, who: Bots.Who } } = {}
	local few = quick and family == "PrecisionTrace"
	for k, name: string in NAMES do
		if not few or k == 1 then -- Elite
			table.insert(out, { name = name, who = (Bots.PROFILES :: any)[name] })
		end
	end
	if not few then
		table.insert(out, { name = "Elite@240", who = Bots.variant(Bots.PROFILES.Elite, 240) })
	end
	table.insert(out, { name = "Average@30/360", who = Bots.variant(Bots.PROFILES.Average, 30, 360) })
	for _, extreme in { "Perfect", "Exact", "Idle" } do
		table.insert(out, { name = extreme, who = extreme :: any })
	end
	return out
end

-- An honest timeline: encode then decode gives the records back (T-MG-08), within decode's caps and the judge's (L6),
-- the judge accepts it, and a session pushed every record finishes at the judge's rawScore.
local function honest(spec: StepSpec, P: any, records: { any }, what: string)
	local family: DT.FamilyId = spec.family
	local b = Minigames.encode(spec, records)
	local back, hash = Timeline.decode(b, family, spec.durationMs)
	A.truthy(back ~= nil, what .. ": decodes (" .. tostring(hash) .. ")")
	A.eq(hash, spec.patternHash, what .. ": the header's hash")
	A.eq(#(back :: { any }), #records, what .. ": every record back")
	for i, r in ipairs(records) do
		local d = (back :: { any })[i]
		if type(r) == "number" then
			A.eq(d, r, what .. ": record " .. i)
		else
			for k, v in r :: any do
				A.eq(d[k], v, what .. ": record " .. i .. "." .. tostring(k))
			end
		end
	end
	A.truthy(#records <= Minigames.recordCap(spec), what .. ": within the judge's cap (L6)")
	A.truthy(#records <= MF.MAX_RECORDS[family], what .. ": within decode's cap")
	local result = Minigames.judge(spec, P, b, 0)
	A.eq(result.status, "Ok", what .. ": judged Ok")
	local F = Minigames.get(family)
	local S = F.newSession(P)
	for _, r in ipairs(records) do
		F.push(S, r)
	end
	A.eq(F.finish(S).score, result.rawScore, what .. ": the client's finish = rawScore")
end

-- the canary's hash (LIBM_CANARY): 1,000 inputs from a fixed stream, plus the OU steps' exponents of every profile
local function libmCanary(): number
	local r = Rng.new(0x11B3, "libm canary")
	local parts: { string } = {}
	for _ = 1, 1000 do
		local u = r:nextFloat()
		table.insert(parts, string.format("%.17g", math.log(math.max(u, 1e-12))))
		table.insert(parts, string.format("%.17g", math.cos(2 * math.pi * u)))
		table.insert(parts, string.format("%.17g", math.exp(-u * 4)))
	end
	for _, name in NAMES do
		local p: any = (Bots.PROFILES :: any)[name]
		for _, tau in { p.ptLagTauS, p.ptCrossTauS } do
			table.insert(parts, string.format("%.17g", math.exp(-(2 / 1000) / tau)))
		end
	end
	return Dump.fnv1a32(table.concat(parts, " "))
end

-- T-MG-11 on n runs per cell: TimingStrike Perfect@30, every MVP tier × material × x ∈ {0, 1}, the pinned names
local function tmg11(n: number, column: number)
	for ti = 1, #H.TIERS do
		local tier: DT.TierId = H.TIERS[ti]
		for mi = 1, #H.MATERIALS do
			local material: DT.MaterialId = H.MATERIALS[mi]
			for _, x in { 0, 1 } do
				local name = string.format("T-MG-11 %s %s x=%d", tier, material, x)
				local scores, _, flagged = Bots.run({ family = "TimingStrike", material = material, tier = tier, x = x,
					profile = "Perfect", fps = 30, n = n, salt = H.configSalt(name) })
				local low = math.huge
				for i = 1, n do
					low = math.min(low, scores[i])
					A.falsy(flagged[i], name .. ": run " .. i .. " flagged")
				end
				A.truthy(low >= Tol.PERFECT_30FPS_MIN_SCORE, string.format("%s: every run ≥ %.2f, lowest %.4f", name,
					Tol.PERFECT_30FPS_MIN_SCORE, low))
				A.eq(low, T_MG_11_MIN[name][column], name .. ": the lowest run, as precomputed on the prototype (D11)")
			end
		end
	end
end

return Test.suite("Minigames/Bots", function(t)
	t.it("profiles: §6.12's table, the prototype's policy fields, §16.23's constants; variants; seedOf; frozen", function()
		for k, name in NAMES do
			local p: any = (Bots.PROFILES :: any)[name]
			local proto: any = ProtoBots.PROFILES[name]
			A.eq(p.id, name)
			for field, column in TABLE do
				A.eq(p[field], column[k], name .. "." .. field .. " (§6.12)")
			end
			A.eq(p.extraLagMs, Bots.BOT_EXTRA_LAG_MS, name .. ": lag = 8 ms + 1 frame")
			A.eq(p.panelPx, Bots.BOT_PANEL_PX, name .. ": panel 520 px")
			for field, v in proto do
				A.eq(p[field], v, name .. "." .. field .. " (the prototype's)")
			end
			for field in p do
				A.truthy(proto[field] ~= nil, name .. "." .. field .. " is the prototype's")
			end
			A.truthy(table.isfrozen(p), name .. " frozen")
		end
		A.deepEq(Bots.BOT_REF_X, { Normal = 0.10, Hard = 0.30 }, "BOT_REF_X (§16.23)")
		A.eq(Bots.BOT_EXTRA_LAG_MS, 8)
		A.eq(Bots.BOT_PANEL_PX, 520)
		A.eq(Bots.BOT_HZ_PERFECT_LOOKAHEAD_MS, 300)
		A.eq(Bots.BOT_RUNS_PER_CELL, 2000)
		A.deepEq(Bots.BOT_REF_X, ProtoSim.REF_X, "the prototype's REF_X")
		local avg30 = Bots.variant(Bots.PROFILES.Average, 30)
		A.eq(avg30.id, "Average@30")
		A.eq(avg30.fps, 30)
		A.eq(avg30.sigmaMs, Bots.PROFILES.Average.sigmaMs, "the same player")
		A.eq(Bots.PROFILES.Average.fps, 60, "the base unchanged")
		local small = Bots.variant(Bots.PROFILES.Elite, 30, 360)
		A.eq(small.id, "Elite@30/360")
		A.eq(small.panelPx, 360)
		A.truthy(table.isfrozen(avg30) and table.isfrozen(small), "variants frozen")
		for _, c in { { 1, 1 }, { 400, 1 }, { 300000, 4294967295 }, { 7, 0xDEADBEEF } } do
			local s = Bots.seedOf(c[1], c[2])
			A.eq(s, ProtoSim.seedOf(c[1], c[2]), "seedOf = the prototype's Sim.seedOf")
			A.truthy(s >= 0 and s < 4294967296 and math.floor(s) == s, "a u32")
		end
	end)

	t.it("play is deterministic per seed, and every bot timeline is honest: decoded back, within the caps (L6), judged Ok", function()
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			for ti = 1, #H.TIERS do
				local tier: DT.TierId = H.TIERS[ti]
				local spec, P = stepOf(family, tier, 5)
				for _, pl in players(family, true) do
					local what = string.format("%s %s %s", family, tier, pl.name)
					local records = Bots.play(spec, P, pl.who, 21)
					A.truthy(table.isfrozen(records), what .. ": frozen (the Recorder's copy)")
					honest(spec, P, records, what)
					if tier == "Normal" then
						A.deepEq(Bots.play(spec, P, pl.who, 21), records, what .. ": P-DET")
						if pl.name == "Elite" then
							A.falsy(Dump.canonical(Bots.play(spec, P, pl.who, 22)) == Dump.canonical(records),
								what .. ": another seed plays otherwise")
						end
					end
				end
				if family == "HoldZone" then
					honest(spec, P, Bots.play(spec, P, Bots.PROFILES.Good, 21, { policy = "hold" }), "HoldZone hold policy")
				elseif family == "TimingStrike" then
					for _, offset in { -120, 120 } do
						honest(spec, P, Bots.play(spec, P, Bots.PROFILES.Poor, 21, { offsetMs = offset }), "offset " .. offset)
					end
				end
			end
		end
	end)

	t.slow("play is deterministic per seed, and every bot timeline is honest: every player, both materials and tiers, ten seeds", function()
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			for ti = 1, #H.TIERS do
				for mi = 1, #H.MATERIALS do
					for seed = 1, 10 do
						local spec, P = stepOf(family, H.TIERS[ti], seed, H.MATERIALS[mi])
						for _, pl in players(family, false) do
							local what = string.format("%s %s %s seed %d %s", family, H.TIERS[ti], H.MATERIALS[mi], seed, pl.name)
							local records = Bots.play(spec, P, pl.who, seed * 7 + 1)
							honest(spec, P, records, what)
							A.deepEq(Bots.play(spec, P, pl.who, seed * 7 + 1), records, what .. ": P-DET")
						end
					end
				end
			end
		end
	end)

	t.it("Perfect, Exact and Idle (§6.12, E-S8.5): ceilings, cheats flagged and clamped at the pass line, no input", function()
		-- TimingStrike: Perfect@60 hits every core, unflagged; Exact errs by 0 (by −offset with one), both HIGH flags
		local spec, P = stepOf("TimingStrike", "Normal", 1)
		local perfect = judged(spec, P, Bots.play(spec, P, "Perfect", 3))
		A.eq(perfect.rawScore, 1, "TimingStrike Perfect@60")
		A.deepEq(perfect.flags, {}, "never flagged (E-S3.2)")
		local exact = Bots.play(spec, P, "Exact", 3)
		for i, e in ipairs(TimingStrike.judgeErrors(P, exact)) do
			A.eq(e, 0, "Exact: error " .. i)
		end
		local r = judged(spec, P, exact)
		A.deepEq(r.flags, { "TsExactHits", "TsLowVariance" })
		A.eq(r.rawScore, 1)
		A.eq(r.score, spec.params.passThreshold, "clamped to the pass line")
		A.truthy(r.passed, "passed: Exact passes at the line, flagged (S-E2E-10)")
		for i, e in ipairs(TimingStrike.judgeErrors(P, Bots.play(spec, P, "Exact", 3, { offsetMs = 60 }))) do
			A.eq(e, -60, "Exact at offset +60: error " .. i)
		end
		-- D7: Exact presses its targets exactly, also where (t/1000)·1000 falls short of t (372 integers ≤ 60,000)
		local short = 0
		for seed = 1, 150 do
			local s, Q = stepOf("TimingStrike", "Normal", seed)
			local presses = Bots.play(s, Q, "Exact", 0)
			for i, c in ipairs((Q :: TimingStrike.Pattern).cycles) do
				A.eq(presses[i], c.target, string.format("Exact, seed %d: press %d at its target", seed, i))
				short += if (c.target / 1000) * 1000 < c.target then 1 else 0
			end
		end
		A.truthy(short > 0, "some targets are among the integers where t/1000 falls short: " .. short)
		-- HoldZone: the exact-state controller strokes up to 50 per second: HzInhumanRate; Exact is the same player
		local specZ, Z = stepOf("HoldZone", "Hard", 1)
		local zone = Bots.play(specZ, Z, "Perfect", 3)
		A.deepEq(Bots.play(specZ, Z, "Exact", 9), zone, "HoldZone Exact = Perfect (no randomness)")
		A.truthy(#zone < MF.MAX_RECORDS[specZ.family] - 1, "far from the record cap: " .. #zone)
		local rz = judged(specZ, Z, zone)
		A.deepEq(rz.flags, { "HzInhumanRate" })
		A.truthy(rz.rawScore >= Tol.PERFECT_HZ_RUN_MIN_SCORE, "HoldZone Perfect " .. rz.rawScore)
		A.eq(rz.score, specZ.params.passThreshold, "clamped")
		A.truthy(rz.passed)
		-- PrecisionTrace: on the pacer every 20 ms from GO, the judge's cap exactly; PtTooPrecise (HIGH)
		local specT, T = stepOf("PrecisionTrace", "Normal", 1)
		local onPacer = Bots.play(specT, T, "Perfect", 3)
		A.deepEq(Bots.play(specT, T, "Exact", 9), onPacer, "PrecisionTrace Exact = Perfect")
		A.eq(#onPacer, Minigames.recordCap(specT), "one sample per due time: the cap")
		for i, s in ipairs(onPacer) do
			A.eq(s.t, (i - 1) * 20, "sample " .. i)
		end
		local rt = judged(specT, T, onPacer)
		A.eq(rt.rawScore, 1, "PrecisionTrace Perfect")
		A.truthy(table.find(rt.flags, "PtTooPrecise") ~= nil, "PtTooPrecise")
		A.eq(rt.score, specT.params.passThreshold, "clamped")
		local sparse = judged(specT, T, Bots.play(specT, T, "Perfect", 3, { everyMs = 200 }))
		A.deepEq(sparse.flags, { "PtSparse", "PtTooPrecise" }, "every 200 ms on the pacer: sparse, and still too precise")
		local noisy = judged(specT, T, Bots.play(specT, T, "Perfect", 3, { noise = 0.004 }))
		A.eq(table.find(noisy.flags, "PtTooPrecise"), nil, "0.004 u of noise: not too precise (Q17's accepted risk)")
		A.truthy(noisy.rawScore >= 0.9, "and still near 1: " .. noisy.rawScore)
		-- Idle: nothing, not even GO's cursor
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			local s, pattern = stepOf(family, "Normal", 1)
			local idle = Bots.play(s, pattern, "Idle", 3)
			A.deepEq(idle, {}, family .. " Idle records nothing")
			local ri = judged(s, pattern, idle)
			A.eq(ri.rawScore, 0, family .. " Idle scores 0")
			A.deepEq(ri.flags, if family == "PrecisionTrace" then { "PtSparse" } else {}, family .. " Idle's flags")
		end
	end)

	t.it("T-MG-11: TimingStrike Perfect at 30 fps scores ≥ PERFECT_30FPS_MIN_SCORE on every run (50 per cell)", function()
		tmg11(T_MG_11_FAST, 1)
	end)

	t.slow("T-MG-11: TimingStrike Perfect at 30 fps on SOLVABILITY_SEEDS runs per cell", function()
		tmg11(Tol.SOLVABILITY_SEEDS, 2)
	end)

	t.it("autoplaySource hands out each record once, in order, as it comes due (§12.5's test hook)", function()
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			local spec, P = stepOf(family, "Normal", 2)
			local records = Bots.play(spec, P, Bots.PROFILES.Good, 4)
			-- a record is due at its own time (t_r ≤ t)
			local atOwn = Bots.autoplaySource(records)(timeOf(records[1]))
			A.truthy(atOwn[1] == records[1], family .. ": the first record is due at its own time")
			local source = Bots.autoplaySource(records)
			local got: { any } = {}
			local rng = TestRng.new(0xA070)
			local now = -1
			while now <= spec.durationMs do
				local batch = source(now)
				for _, r in ipairs(batch) do
					A.truthy(timeOf(r) <= now, family .. ": due by " .. now)
					table.insert(got, r)
				end
				A.deepEq(source(now), {}, family .. ": handed out once")
				now += rng:int(1, 40)
			end
			for _, r in ipairs(source(math.huge)) do
				table.insert(got, r)
			end
			A.eq(#got, #records, family .. ": every record")
			for i, r in ipairs(records) do
				A.eq(got[i], r, family .. ": record " .. i .. " in order")
			end
		end
	end)

	t.it("stats is the prototype's: mean, quantiles, pass and flag rates", function()
		local rng = TestRng.new(0x57A7)
		for _ = 1, 20 do
			local n = rng:int(1, 60)
			local scores, passes, flags = {}, {}, {}
			for i = 1, n do
				scores[i] = math.round(rng:range(0, 1) * 10000) / 10000
				passes[i] = scores[i] >= 0.5
				flags[i] = rng:int(1, 10) == 1
			end
			A.deepEq(Bots.stats(scores, passes, flags), ProtoBots.stats(scores, passes, flags))
			A.deepEq(Bots.stats(scores, passes), ProtoBots.stats(scores, passes))
		end
	end)

	t.it("D14: Bots.play still makes the frozen timelines of tests/fixtures/MinigameTimelines, byte for byte", function()
		A.eq(#MinigameTimelines.entries, 24, "3 families × 2 tiers × 4 profiles")
		for _, e in ipairs(MinigameTimelines.entries) do
			local spec, P = H.prepared(e.family :: DT.FamilyId, e.material :: DT.MaterialId, e.tier :: DT.TierId, e.x, e.seed,
				if e.family == "PrecisionTrace" then Edges.arming else nil)
			local b = Minigames.encode(spec, Bots.play(spec, P, (Bots.PROFILES :: any)[e.profile], e.botSeed))
			local hex = MinigameTimelines.hex(b)
			if hex ~= e.hex then
				A.fail(string.format("%s %s %s: Bots.play no longer makes the frozen timeline (%d bytes, was %d): a change of "
					.. "the bots, or of this machine's libm if the canary case fails too (M4's D14)", e.family, e.tier,
					e.profile, buffer.len(b), #e.hex / 2))
			end
		end
	end)

	t.it("D14: the libm canary (math.log, cos and exp at 1,000 draws and the 8 OU exponents) is the blessed hash", function()
		local h = libmCanary()
		if h ~= LIBM_CANARY then
			A.fail(string.format("this machine's libm differs from the one the canary was blessed with (%d, was %d): the "
				.. "bots' records may differ too (Bots and Reference), the judge cannot (M4's D14)", h, LIBM_CANARY))
		end
	end)
end)
