--!strict
-- Minigames/FalsePositives (SPEC §10.6, §14.8, §16.32, E-S3.8; T-MG-10; M4's D10, D11, G17, G19 and L5): the
-- inhuman-input checks. False positives: the human models on their devices are never flagged, with the margins §14.8
-- asserts (the trace's smallest mean deviation ≥ 3 × PT_PRECISE_MEAN_DEV, its smallest mean jerk ≥ 3 ×
-- PT_SMOOTH_MEAN_JERK; HoldZone's most presses in 1 s ≤ HZ_RATE_MAX_PRESSES / 3). True positives: the cheats are, at
-- 100 %; and two known limits (Q17's accepted careful cheaters) are pinned so a change shows.
-- Every configuration seeds from its pinned name as Bots.run does (pattern seeds Bots.seedOf(i, salt), bot seeds
-- i·7919 + salt·31 + 17, salt = fnv1a32(name)), so each outcome is known before it runs: precomputed on the S3 prototype
-- with the same names (builder 4's pre_tmg10ts and pre_misc, critic B's ptmargin; M4-notes B4) and pinned here at the
-- printed precision (the σ 4 ms TP pins the build's own count: no prototype config). A difference is a porting bug (or
-- this machine's libm: Minigames/Bots' canary), never re-seeded (D11). The printed lines are E-S3.10's figures.
-- L3V (t.volume, L5): every false-positive case (TimingStrike FP_RUNS_TS per device, split by tier; HoldZone FP_RUNS;
-- the trace FP_RUNS on the 30 fps / 360 px Elite device, split by tier, and its other devices). Plain L3 (t.slow): the
-- true positives and the known limits.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Cheats = require("../lib/Cheats")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Edges = require("../fixtures/Edges")
local H = require("./MinigamesHelpers")
local DT = require("../../src/shared/Definitions/Types")
local MF = require("../../src/shared/Definitions/MinigameFamilies")
local Bots = require("../../src/shared/Minigames/Bots")
local Checks = require("../../src/shared/Minigames/Checks")
local Input = require("../../src/shared/Minigames/Input")
local Minigames = require("../../src/shared/Minigames/Minigames")
local PrecisionTrace = require("../../src/shared/Minigames/PrecisionTrace")
local Timeline = require("../../src/shared/Minigames/Timeline")
local TimingStrike = require("../../src/shared/Minigames/TimingStrike")
local Types = require("../../src/shared/Minigames/Types")

type StepSpec = Types.StepSpec
type MinigameResult = Types.MinigameResult

local CHEATS = Cheats.new({ Timeline = Timeline, MinigameFamilies = MF, Minigames = Minigames, Bots = Bots })
local PT_DEVICE_RUNS = 1000 -- the trace's other devices: 1,000 runs each, as E-S3.8 (§14.8)
local HZ_PERFECT_RUNS = 100 -- the exact-state HoldZone controller: 100 runs (E-S3.8), 2 ms each
local AUTOCLICK_HZ = 30 -- presses per second: HZ_RATE_MAX_PRESSES in HZ_RATE_WINDOW_MS

-- TimingStrike's devices (E-S3.8's four; G17), precomputed per tier on FP_RUNS_TS / 2 runs: the smallest sample SD
-- of the judged errors (ms, %.2f; TsLowVariance under TS_MIN_SD_MS), the largest share of |e| ≤ TS_EXACT_MS (%.3f;
-- TsExactHits at TS_EXACT_FRAC), the runs with TS_MIN_JUDGED judged presses, the mean rawScore (%.4f)
local TS_DEVICES: { { any } } = {
	{ "Elite@240", "Elite", 240, { Normal = { "2.78", "0.500", "150000", "0.9337" }, Hard = { "4.24", "0.400", "150000", "0.8971" } } },
	{ "Elite@60", "Elite", 60, { Normal = { "3.37", "0.364", "150000", "0.8615" }, Hard = { "5.13", "0.333", "150000", "0.8065" } } },
	{ "Good@60", "Good", 60, { Normal = { "7.24", "0.417", "150000", "0.7900" }, Hard = { "8.93", "0.333", "150000", "0.7155" } } },
	{ "Average@30", "Average", 30, { Normal = { "11.95", "0.333", "149991", "0.5694" }, Hard = { "16.75", "0.308", "150000", "0.4833" } } },
}
-- HoldZone's devices, pumping, precomputed: the most presses in any HZ_RATE_WINDOW_MS window, Normal and Hard
local HZ_DEVICES: { { any } } = {
	{ "Elite@60", "Elite", 60, 9, 9 },
	{ "Elite@30", "Elite", 30, 8, 8 },
	{ "Good@60", "Good", 60, 8, 8 },
	{ "Average@30", "Average", 30, 7, 7 },
}
-- the trace on the 30 fps / 360 px Elite device, precomputed (critic B's ptmargin): the smallest mean deviation and
-- mean jerk (u, %.5f), and the 0.1 % quantile of the mean deviations (critic B's tail, numpy's linear rule)
local PT_HALVES: { [string]: { string } } = {
	Normal = { "0.00279", "0.00409", "0.00304" },
	Hard = { "0.00259", "0.00404", "0.00303" },
}
-- the trace's other devices (Iron, the tier alternating by run), precomputed: smallest mean deviation and mean jerk
local PT_DEVICES: { { any } } = {
	{ "Elite@240/520", "Elite", 240, 520, "0.00284", "0.00382" },
	{ "Elite@60/520", "Elite", 60, 520, "0.00296", "0.00454" },
	{ "Good@60/520", "Good", 60, 520, "0.00543", "0.00535" },
}

-- Sharpening plays the reference arming edge (E-S3.2's), the other steps no edge
local function edgeOf(family: DT.FamilyId): Edges.Edge?
	return if family == "PrecisionTrace" then Edges.arming else nil
end

-- a statistic as the prototype printed it, against its pinned value
local function pinned(got: string, want: string, what: string)
	if got ~= want then
		A.fail(string.format("%s: %s, precomputed on the S3 prototype as %s (a porting bug or this machine's libm, "
			.. "never a reason to re-seed: M4's D11)", what, got, want))
	end
end

-- n runs of a pinned name as Bots.run plays them (prepare, Bots.play through the Recorder, replay), each run's material
-- and tier from cellOf(i); each(i, spec, pattern, records, result) sees every run
local function runs(name: string, n: number, family: DT.FamilyId, who: Bots.Who, opts: Bots.PlayOptions?,
	cellOf: (i: number) -> (DT.MaterialId, DT.TierId),
	each: (i: number, spec: StepSpec, P: any, records: { any }, result: MinigameResult) -> ())
	local salt = H.configSalt(name)
	for i = 1, n do
		local material: DT.MaterialId, tier: DT.TierId = cellOf(i)
		local spec, P = H.prepared(family, material, tier, (Bots.BOT_REF_X :: any)[tier], Bots.seedOf(i, salt), edgeOf(family))
		local records = Bots.play(spec, P, who, i * 7919 + salt * 31 + 17, opts)
		each(i, spec, P, records, Minigames.replay(spec, P, records))
	end
end

-- Iron on one tier; Iron and Steel alternating by run (odd Iron); Iron, Normal and Hard alternating (odd Normal)
local function on(tier: DT.TierId): (i: number) -> (DT.MaterialId, DT.TierId)
	return function(_: number): (DT.MaterialId, DT.TierId)
		return "Iron", tier
	end
end
local function materialsOn(tier: DT.TierId): (i: number) -> (DT.MaterialId, DT.TierId)
	return function(i: number): (DT.MaterialId, DT.TierId)
		return if i % 2 == 1 then "Iron" else "Steel", tier
	end
end
local function tiersAlternate(i: number): (DT.MaterialId, DT.TierId)
	return "Iron", if i % 2 == 1 then "Normal" else "Hard"
end

-- the down times of a HoldZone timeline
local function downs(records: { any }): { number }
	local out: { number } = {}
	for _, r in ipairs(records) do
		if r.down then
			table.insert(out, r.t)
		end
	end
	return out
end

-- T-MG-10 on one TimingStrike device and tier: FP_RUNS_TS / 2 runs, Iron and Steel alternating, no run flagged
local function tsDevice(d: { any }, tier: DT.TierId)
	local name = string.format("T-MG-10 TimingStrike %s %s", d[1], tier)
	local who = Bots.variant((Bots.PROFILES :: any)[d[2]], d[3])
	local n = Tol.FP_RUNS_TS / 2
	local minJudged = Checks.value("TimingStrike", "TS_MIN_JUDGED")
	local exactMs = Checks.value("TimingStrike", "TS_EXACT_MS")
	local minSd, maxExact, checked, sum = math.huge, 0, 0, 0
	runs(name, n, "TimingStrike", who, nil, materialsOn(tier), function(i, _spec, P, records, result)
		if #result.flags > 0 then
			A.fail(string.format("%s: run %d flagged %s", name, i, table.concat(result.flags, ", ")))
		end
		sum += result.rawScore
		local errs = TimingStrike.judgeErrors(P, records)
		if #errs >= minJudged then
			checked += 1
			local exact = 0
			for _, e in ipairs(errs) do
				if math.abs(e) <= exactMs then
					exact += 1
				end
			end
			minSd = math.min(minSd, Checks.sampleSd(errs))
			maxExact = math.max(maxExact, exact / #errs)
		end
	end)
	local want = d[4][tier]
	pinned(string.format("%.2f", minSd), want[1], name .. ": the smallest SD")
	pinned(string.format("%.3f", maxExact), want[2], name .. ": the largest exact share")
	pinned(string.format("%d", checked), want[3], name .. ": the runs with TS_MIN_JUDGED judged presses")
	pinned(string.format("%.4f", sum / n), want[4], name .. ": the mean rawScore")
	print(string.format("  %s: 0 of %d flagged; smallest SD %.2f ms (flag < %.1f), largest exact share %.3f (flag ≥ %.2f)",
		name, n, minSd, Checks.value("TimingStrike", "TS_MIN_SD_MS"), maxExact, Checks.value("TimingStrike", "TS_EXACT_FRAC")))
end

-- T-MG-10 on the trace: n runs of a device, no run flagged; the smallest mean deviation and mean jerk over the runs the
-- checks measure (PT_PRECISE_MIN_SAMPLES grinding samples, PT_SMOOTH_MIN_TRIPLETS moving triplets), ≥ 3 × their
-- thresholds; the sorted deviations for the quantile
local function ptRuns(name: string, n: number, who: Bots.Profile, cellOf: (i: number) -> (DT.MaterialId, DT.TierId))
	: (number, number, { number })
	local minSamples = Checks.value("PrecisionTrace", "PT_PRECISE_MIN_SAMPLES")
	local minTriplets = Checks.value("PrecisionTrace", "PT_SMOOTH_MIN_TRIPLETS")
	local devs: { number } = {}
	local minJerk = math.huge
	runs(name, n, "PrecisionTrace", who, nil, cellOf, function(i, _spec, P, records, result)
		if #result.flags > 0 then
			A.fail(string.format("%s: run %d flagged %s", name, i, table.concat(result.flags, ", ")))
		end
		local m = PrecisionTrace.measures(P, records)
		if m.devN >= minSamples then
			table.insert(devs, m.meanDev)
		end
		if m.jerkN >= minTriplets then
			minJerk = math.min(minJerk, m.meanJerk)
		end
	end)
	table.sort(devs)
	local precise = 3 * Checks.value("PrecisionTrace", "PT_PRECISE_MEAN_DEV")
	local smooth = 3 * Checks.value("PrecisionTrace", "PT_SMOOTH_MEAN_JERK")
	A.truthy(devs[1] >= precise, string.format("%s: smallest mean deviation %.5f u ≥ 3 × PT_PRECISE_MEAN_DEV (%.4f)", name,
		devs[1], precise))
	A.truthy(minJerk >= smooth, string.format("%s: smallest mean jerk %.5f ≥ 3 × PT_SMOOTH_MEAN_JERK (%.4f)", name, minJerk,
		smooth))
	return devs[1], minJerk, devs
end

-- the q quantile of sorted values, numpy's default (linear) rule, as critic B's tail.py reported it
local function quantile(sorted: { number }, q: number): number
	local h = (#sorted - 1) * q
	local lo = math.floor(h)
	return sorted[lo + 1] + (h - lo) * (sorted[math.min(lo + 2, #sorted)] - sorted[lo + 1])
end

return Test.suite("Minigames/FalsePositives", function(t)
	for _, d in TS_DEVICES do
		for ti = 1, #H.TIERS do
			local tier: DT.TierId = H.TIERS[ti]
			t.volume(string.format("T-MG-10 TimingStrike %s %s: FP_RUNS_TS / 2 runs, none flagged", d[1], tier), function()
				tsDevice(d, tier)
			end)
		end
	end

	t.volume("T-MG-10 HoldZone: FP_RUNS pumping runs on four devices × two tiers, none flagged, at most "
		.. "HZ_RATE_MAX_PRESSES / 3 presses in 1 s", function()
		local window = Checks.value("HoldZone", "HZ_RATE_WINDOW_MS")
		local most = Checks.value("HoldZone", "HZ_RATE_MAX_PRESSES") / 3
		local n = Tol.FP_RUNS / (#HZ_DEVICES * #H.TIERS)
		local out: { string } = {}
		for _, d in HZ_DEVICES do
			for ti = 1, #H.TIERS do
				local tier: DT.TierId = H.TIERS[ti]
				local name = string.format("T-MG-10 HoldZone %s %s", d[1], tier)
				local peak = 0
				runs(name, n, "HoldZone", Bots.variant((Bots.PROFILES :: any)[d[2]], d[3]), nil, on(tier),
					function(i, _spec, _P, records, result)
						if #result.flags > 0 then
							A.fail(string.format("%s: run %d flagged %s", name, i, table.concat(result.flags, ", ")))
						end
						peak = math.max(peak, Checks.maxInWindow(downs(records), window))
					end)
				A.truthy(peak <= most, string.format("%s: at most %d presses in %d ms, %d", name, most, window, peak))
				A.eq(peak, d[3 + ti], name .. ": the most presses in 1 s, as precomputed (D11)")
				table.insert(out, string.format("%s %s %d", d[1], tier, peak))
			end
		end
		print(string.format("  T-MG-10 HoldZone: 0 of %d flagged; most presses in 1 s: %s", Tol.FP_RUNS, table.concat(out, ", ")))
	end)

	for ti = 1, #H.TIERS do
		local tier: DT.TierId = H.TIERS[ti]
		t.volume(string.format("T-MG-10 PrecisionTrace Elite@30/360 %s: FP_RUNS / 2 runs, none flagged, the smallest mean "
			.. "deviation ≥ 3 × PT_PRECISE_MEAN_DEV", tier), function()
			local name = "T-MG-10 PrecisionTrace Elite@30/360 " .. tier
			local dev, jerk, devs = ptRuns(name, Tol.FP_RUNS / 2, Bots.variant(Bots.PROFILES.Elite, 30, 360), on(tier))
			local q = quantile(devs, 0.001)
			local want = PT_HALVES[tier]
			pinned(string.format("%.5f", dev), want[1], name .. ": the smallest mean deviation")
			pinned(string.format("%.5f", jerk), want[2], name .. ": the smallest mean jerk")
			pinned(string.format("%.5f", q), want[3], name .. ": the 0.1 % quantile of the mean deviations")
			local threshold = Checks.value("PrecisionTrace", "PT_PRECISE_MEAN_DEV")
			print(string.format("  %s: 0 of %d flagged; smallest mean deviation %.5f u (×%.2f of PT_PRECISE_MEAN_DEV), "
				.. "0.1 %% quantile %.5f (×%.2f), smallest mean jerk %.5f", name, Tol.FP_RUNS / 2, dev, dev / threshold, q,
				q / threshold, jerk))
		end)
	end

	t.volume("T-MG-10 PrecisionTrace on its other devices: 1,000 runs each, none flagged, the same margins", function()
		local threshold = Checks.value("PrecisionTrace", "PT_PRECISE_MEAN_DEV")
		local out: { string } = {}
		for _, d in PT_DEVICES do
			local name = "T-MG-10 PrecisionTrace " .. d[1]
			local dev, jerk = ptRuns(name, PT_DEVICE_RUNS, Bots.variant((Bots.PROFILES :: any)[d[2]], d[3], d[4]),
				tiersAlternate)
			pinned(string.format("%.5f", dev), d[5], name .. ": the smallest mean deviation")
			pinned(string.format("%.5f", jerk), d[6], name .. ": the smallest mean jerk")
			table.insert(out, string.format("%s %.5f (×%.2f), jerk %.5f", d[1], dev, dev / threshold, jerk))
		end
		print("  T-MG-10 PrecisionTrace devices, 0 flagged; smallest mean deviation: " .. table.concat(out, "; "))
	end)

	t.slow("T-MG-10 TP TimingStrike: Exact flagged TsExactHits and TsLowVariance every time; σ 4 ms noise accepted (Q17)", function()
		local pass = 0
		runs("T-MG-10 TP TimingStrike Exact", Tol.TP_RUNS, "TimingStrike", "Exact", nil, tiersAlternate,
			function(i, spec, P, records, result)
				A.deepEq(records, CHEATS.exact(spec, P), "Cheats.exact is Bots' Exact")
				A.deepEq(result.flags, { "TsExactHits", "TsLowVariance" }, "Exact run " .. i)
				A.eq(result.rawScore, 1, "Exact run " .. i)
				A.eq(result.score, spec.params.passThreshold, "Exact run " .. i .. ": clamped to the pass line")
				A.truthy(result.passed, "Exact run " .. i .. ": a flag never fails a step")
				pass = spec.params.passThreshold
			end)
		-- A careful cheater: every target plus N(0, 4 ms), rounded, through the Recorder at exact clocks (D7). Accepted
		-- (Q17) but for the rare run whose errors spread less than TS_MIN_SD_MS by chance (about 4 in 10,000 runs with
		-- Normal's 12 strikes, 0.8 with Hard's 15): 2 of these 2,000 runs, TsLowVariance alone, pinned (E-S3.8's "0 %"
		-- was on 2,000 runs per tier).
		local name = "T-MG-10 TP TimingStrike noise 4 ms"
		local salt = H.configSalt(name)
		local flagged, sum = 0, 0
		for i = 1, Tol.TP_RUNS do
			local material: DT.MaterialId, tier: DT.TierId = tiersAlternate(i)
			local spec, P = H.prepared("TimingStrike", material, tier, (Bots.BOT_REF_X :: any)[tier], Bots.seedOf(i, salt))
			local rng = TestRng.new(Bots.seedOf(i, salt))
			local presses: { number } = {}
			for _, c in ipairs((P :: TimingStrike.Pattern).cycles) do
				table.insert(presses, math.max(0, math.round(c.target + rng:normal(0, 4))))
			end
			table.sort(presses)
			local rec = Input.new(spec, 0, 0)
			rec:go(false)
			for _, p in ipairs(presses) do
				rec:button(true, (p + 0.5) / 1000, 0)
				rec:button(false, (p + 0.5) / 1000, 0)
			end
			local result = Minigames.replay(spec, P, rec:records())
			if #result.flags > 0 then
				A.deepEq(result.flags, { "TsLowVariance" }, name .. ", run " .. i .. ": a spread under TS_MIN_SD_MS by chance")
				flagged += 1
			end
			sum += result.rawScore
		end
		A.eq(flagged, 2, name .. ": accepted (Q17) but for 2 runs, as pinned")
		A.truthy(sum / Tol.TP_RUNS >= 0.99, string.format("%s: mean %.4f ≥ 0.99", name, sum / Tol.TP_RUNS))
		print(string.format("  T-MG-10 TP TimingStrike: Exact flagged %d of %d, clamped to %.2f; σ 4 ms noise flagged %d of %d, "
			.. "mean %.4f", Tol.TP_RUNS, Tol.TP_RUNS, pass, flagged, Tol.TP_RUNS, sum / Tol.TP_RUNS))
	end)

	t.slow("T-MG-10 TP PrecisionTrace: on the pacer PtTooPrecise, 200 ms apart PtSparse, every time; 0.004 u noise never (Q17)", function()
		local smooth, precise = 0, 0
		runs("T-MG-10 TP PrecisionTrace on the pacer", Tol.TP_RUNS, "PrecisionTrace", "Perfect", nil, tiersAlternate,
			function(i, spec, _P, _records, result)
				A.truthy(table.find(result.flags, "PtTooPrecise") ~= nil, "on the pacer, run " .. i .. ": PtTooPrecise (HIGH)")
				A.eq(result.rawScore, 1, "on the pacer, run " .. i)
				A.eq(result.score, spec.params.passThreshold, "on the pacer, run " .. i .. ": clamped")
				precise += 1
				if table.find(result.flags, "PtTooSmooth") then
					smooth += 1
				end
			end)
		local sparse = 0
		runs("T-MG-10 TP PrecisionTrace sparse 200 ms", Tol.TP_RUNS, "PrecisionTrace", "Perfect", { everyMs = 200 },
			tiersAlternate, function(i, _spec, _P, _records, result)
				A.truthy(table.find(result.flags, "PtSparse") ~= nil, "200 ms apart, run " .. i .. ": PtSparse")
				sparse += 1
			end)
		local sum = 0
		runs("T-MG-10 TP PrecisionTrace noise 0.004 u", Tol.TP_RUNS, "PrecisionTrace", "Perfect", { noise = 0.004 },
			tiersAlternate, function(i, _spec, _P, _records, result)
				A.deepEq(result.flags, {}, "0.004 u of white noise, run " .. i .. ": accepted (Q17)")
				sum += result.rawScore
			end)
		A.truthy(sum / Tol.TP_RUNS >= 0.98, string.format("0.004 u of noise: mean %.4f ≥ 0.98", sum / Tol.TP_RUNS))
		-- reported, not asserted: no evidence puts the on-pacer PtTooSmooth rate at 100 % (the plan's [6.3])
		print(string.format("  T-MG-10 TP PrecisionTrace: on the pacer PtTooPrecise %d of %d (PtTooSmooth %d); 200 ms apart "
			.. "PtSparse %d of %d; 0.004 u noise flagged 0, mean %.4f", precise, Tol.TP_RUNS, smooth, sparse, Tol.TP_RUNS,
			sum / Tol.TP_RUNS))
	end)

	t.slow("T-MG-10 TP HoldZone: the exact-state Perfect and a 30/s autoclicker flagged HzInhumanRate every time", function()
		local peak = 0
		runs("T-MG-10 TP HoldZone Perfect", HZ_PERFECT_RUNS, "HoldZone", "Perfect", nil, tiersAlternate,
			function(i, spec, _P, records, result)
				A.deepEq(result.flags, { "HzInhumanRate" }, "Perfect run " .. i)
				A.eq(result.score, math.min(result.rawScore, spec.params.passThreshold), "Perfect run " .. i .. ": clamped")
				peak = math.max(peak, Checks.maxInWindow(downs(records), Checks.value("HoldZone", "HZ_RATE_WINDOW_MS")))
			end)
		-- a press every 1000/30 ms from a random phase, each held 10 ms, the whole step, at exact clocks (D7)
		local name = "T-MG-10 TP HoldZone autoclicker 30/s"
		local salt = H.configSalt(name)
		for i = 1, Tol.TP_RUNS do
			local material: DT.MaterialId, tier: DT.TierId = tiersAlternate(i)
			local spec, P = H.prepared("HoldZone", material, tier, (Bots.BOT_REF_X :: any)[tier], Bots.seedOf(i, salt))
			local phase = TestRng.new(Bots.seedOf(i, salt)):int(0, 32)
			local rec = Input.new(spec, 0, 0)
			rec:go(false)
			local k = 0
			while true do
				local t0 = phase + math.round(k * 1000 / AUTOCLICK_HZ)
				if t0 + 10 > spec.durationMs then
					break
				end
				rec:button(true, (t0 + 0.5) / 1000, 0)
				rec:button(false, (t0 + 10.5) / 1000, 0)
				k += 1
			end
			A.deepEq(Minigames.replay(spec, P, rec:records()).flags, { "HzInhumanRate" }, name .. ", run " .. i)
		end
		print(string.format("  T-MG-10 TP HoldZone: Perfect flagged %d of %d (up to %d presses in 1 s); the 30/s autoclicker "
			.. "%d of %d", HZ_PERFECT_RUNS, HZ_PERFECT_RUNS, peak, Tol.TP_RUNS, Tol.TP_RUNS))
	end)
end)
