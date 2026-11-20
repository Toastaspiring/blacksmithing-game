--!strict
-- Minigames/Statistics (SPEC §6.13, §14.6, §14.8, §16.32, E-S3.2; T-MG-03, 04, 05, 06 and 12; M4's D10, D11 and L5): the
-- bots' score statistics. Each configuration seeds from its pinned name (§14.8: pattern seeds Bots.seedOf(i, salt), bot
-- seeds i·7919 + salt·31 + 17, salt = fnv1a32(name)), so each outcome is pass or fail per code version; and since the
-- build reproduces the S3 prototype score for score (Minigames/Reference), each is known before it runs: precomputed on
-- the prototype with the same names (critic B's t45, t6 and fair; builder 4's pre_tmg03; M4-notes B4) and pinned here
-- at the printed precision. A difference is a porting bug (or this machine's libm: Minigames/Bots' canary), never a
-- reason to re-seed (D11).
-- Plain L3 (t.slow): T-MG-04's bands with its Q8 fail rates on BOT_RUNS_FAIL, and T-MG-05 on T-MG-04's runs.
-- L3V (t.volume, L5: outcomes only the BALANCE data, the bots and the names decide): T-MG-03, T-MG-06 (b) and T-MG-12;
-- T-MG-06 (a), the Steel columns, is fast. T-MG-09, 11 and 15's slow cases sit beside their fast ones (Minigames, Bots,
-- Input); T-MG-10 is Minigames/FalsePositives. One case per family keeps each under SLOW_CASE_BUDGET_MS.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Tol = require("../lib/Tol")
local Edges = require("../fixtures/Edges")
local H = require("./MinigamesHelpers")
local DT = require("../../src/shared/Definitions/Types")
local MF = require("../../src/shared/Definitions/MinigameFamilies")
local Bots = require("../../src/shared/Minigames/Bots")
local Minigames = require("../../src/shared/Minigames/Minigames")
local Params = require("../../src/shared/Minigames/Params")

local PROFILES = { "Elite", "Good", "Average", "Poor" }
-- §6.13's Q8 targets: Average fails in [3 %, 15 %] on Normal and [15 %, 40 %] on Hard; Good at most 5 % / 15 %
local Q8: { [string]: { [string]: { number } } } = {
	Average = { Normal = { 0.03, 0.15 }, Hard = { 0.15, 0.40 } },
	Good = { Normal = { 0, 0.05 }, Hard = { 0, 0.15 } },
}
local IDLE_RUNS = 20 -- T-MG-03's Idle runs per cell: no input scores 0 whatever the pattern

-- T-MG-04 per cell, precomputed (critic B's t45): the mean of the first BOT_RUNS runs (%.6f) and the runs under the
-- pass line, of BOT_RUNS_FAIL for Average and Good and of BOT_RUNS for Elite and Poor; no run flagged anywhere
local T_MG_04: { [string]: { any } } = {
	["HoldZone Normal Iron"] = { "0.858235", 0, "0.800797", 0, "0.619108", 53, "0.483994", 237 },
	["HoldZone Normal Steel"] = { "0.868389", 0, "0.806751", 0, "0.602796", 76, "0.462271", 264 },
	["HoldZone Hard Iron"] = { "0.823013", 0, "0.754755", 0, "0.551088", 236, "0.421541", 336 },
	["HoldZone Hard Steel"] = { "0.824210", 0, "0.739067", 0, "0.534002", 315, "0.410835", 346 },
	["TimingStrike Normal Iron"] = { "0.865603", 0, "0.790154", 1, "0.643108", 107, "0.375370", 351 },
	["TimingStrike Normal Steel"] = { "0.856393", 0, "0.787426", 3, "0.642652", 106, "0.368188", 342 },
	["TimingStrike Hard Iron"] = { "0.812158", 0, "0.713924", 19, "0.545460", 298, "0.325240", 381 },
	["TimingStrike Hard Steel"] = { "0.802713", 0, "0.717156", 10, "0.554410", 304, "0.311115", 385 },
	["PrecisionTrace Normal Iron"] = { "0.956909", 0, "0.872073", 0, "0.632763", 69, "0.411730", 324 },
	["PrecisionTrace Normal Steel"] = { "0.954179", 0, "0.869101", 0, "0.625552", 91, "0.385909", 354 },
	["PrecisionTrace Hard Iron"] = { "0.949163", 0, "0.850017", 0, "0.553876", 246, "0.336815", 367 },
	["PrecisionTrace Hard Steel"] = { "0.949004", 0, "0.840720", 0, "0.551196", 261, "0.324947", 385 },
}

-- T-MG-03 per cell, precomputed (builder 4's pre_tmg03, L9): the Perfect bot's mean rawScore (%.6f), its lowest run
-- (%.4f) and the runs flagged (the exact-state HoldZone controller and the on-pacer trace are cheats: HIGH flags)
local T_MG_03: { [string]: { any } } = {
	["HoldZone Normal Iron"] = { "0.985583", "0.9285", 1000 },
	["HoldZone Normal Steel"] = { "0.987971", "0.9176", 1000 },
	["HoldZone Hard Iron"] = { "0.965925", "0.8828", 1000 },
	["HoldZone Hard Steel"] = { "0.969914", "0.9147", 1000 },
	["TimingStrike Normal Iron"] = { "1.000000", "1.0000", 0 },
	["TimingStrike Normal Steel"] = { "1.000000", "1.0000", 0 },
	["TimingStrike Hard Iron"] = { "1.000000", "1.0000", 0 },
	["TimingStrike Hard Steel"] = { "1.000000", "1.0000", 0 },
	["PrecisionTrace Normal Iron"] = { "1.000000", "1.0000", 1000 },
	["PrecisionTrace Normal Steel"] = { "1.000000", "1.0000", 1000 },
	["PrecisionTrace Hard Iron"] = { "1.000000", "1.0000", 1000 },
	["PrecisionTrace Hard Steel"] = { "1.000000", "1.0000", 1000 },
}

-- T-MG-06 (b), precomputed (critic B's t6): the Iron and Steel means and the paired drop (%.4f)
local T_MG_06: { [string]: { string } } = {
	HoldZone = { "0.6144", "0.5991", "0.0153" },
	TimingStrike = { "0.6489", "0.6403", "0.0086" },
	PrecisionTrace = { "0.6337", "0.6207", "0.0130" },
}

-- T-MG-12, precomputed (critic B's fair): the SD over pattern seeds of the per-pattern Average mean (%.4f), Normal and Hard
local T_MG_12: { [string]: { string } } = {
	HoldZone = { "0.0463", "0.0510" },
	TimingStrike = { "0.0220", "0.0213" },
	PrecisionTrace = { "0.0246", "0.0136" },
}

-- T-MG-06 (a): each family's Steel column, as §6.8–§6.10 list it, and the way it tightens the step: the window or zone
-- narrower, the beat faster, the drift and the pacer quicker, the zone hotter (+1: Steel ≥ Iron; −1: Steel ≤ Iron)
local STEEL: { [string]: { [string]: { number } } } = {
	HoldZone = { zoneWidth = { 0.98, -1 }, driftSpeed = { 1.01, 1 }, targetMin = { 1.08, 1 }, targetMax = { 1.04, 1 } },
	TimingStrike = { beatMs = { 0.98, -1 }, windowMs = { 0.98, -1 } },
	PrecisionTrace = { halfWidth = { 0.98, -1 }, pacerSpeed = { 1.01, 1 } },
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

-- T-MG-04 and T-MG-05 for one family: the 16 cells at BOT_REF_X, HoldZone pumping, offset 0, the trace on the arming
-- sword. Per cell the first BOT_RUNS runs' mean is within 4 standard errors of E-S3.2's (plus 0.0005 for its 3
-- decimals; the plan's reading, G16) and no run is flagged; Average and Good run BOT_RUNS_FAIL (the same seed list
-- extended) and fail inside Q8's bands. Then per tier and material Elite > Good > Average > Poor, and per material and
-- profile the Normal → Hard drop is ≥ TIER_MIN_MEAN_DROP for Average and > 0 for the others (unpaired: the names differ
-- per tier).
local function tmg04(family: DT.FamilyId)
	local means: { [string]: number } = {}
	local worstBand, worstQ8 = 0, math.huge
	for ti = 1, #H.TIERS do
		local tier: DT.TierId = H.TIERS[ti]
		for mi = 1, #H.MATERIALS do
			local material: DT.MaterialId = H.MATERIALS[mi]
			local cell = string.format("%s %s %s", family, tier, material)
			local es32 = H.ES32[string.format("%s %s/%s", family, material, tier)]
			for k, profile in PROFILES do
				local name = string.format("T-MG-04 %s %s", cell, profile)
				local q8 = Q8[profile]
				local n = if q8 then Tol.BOT_RUNS_FAIL else Tol.BOT_RUNS
				local scores, passes, flagged = Bots.run({ family = family, material = material, tier = tier, profile = profile,
					n = n, salt = H.configSalt(name), edge = edgeOf(family) })
				local sum, fails = 0, 0
				for i = 1, n do
					if i <= Tol.BOT_RUNS then
						sum += scores[i]
					end
					if not passes[i] then
						fails += 1
					end
					if flagged[i] then
						A.fail(string.format("%s: run %d flagged (E-S3.2: no human run is)", name, i))
					end
				end
				local mean = sum / Tol.BOT_RUNS
				means[string.format("%s %s %s", tier, material, profile)] = mean
				local want = T_MG_04[cell]
				pinned(string.format("%.6f", mean), want[2 * k - 1], name .. ": the mean of the first BOT_RUNS")
				A.eq(fails, want[2 * k], name .. ": the runs under the pass line, as precomputed (D11)")
				local ref = es32[profile]
				local band = 4 * ref[2] / math.sqrt(Tol.BOT_RUNS) + 0.0005
				local off = math.abs(mean - ref[1])
				worstBand = math.max(worstBand, off / band)
				A.truthy(off <= band, string.format("%s: mean %.4f, E-S3.2's %.3f ± %.4f", name, mean, ref[1], band))
				if q8 then
					local rate = fails / n
					local lo, hi = q8[tier][1], q8[tier][2]
					worstQ8 = math.min(worstQ8, if lo > 0 then rate - lo else math.huge, hi - rate) -- Good's floor is no edge
					A.truthy(rate >= lo and rate <= hi, string.format("%s: fails %.1f %% of %d runs, Q8's band %.0f–%.0f %%", name,
						rate * 100, n, lo * 100, hi * 100))
				end
			end
		end
	end
	-- T-MG-05
	for ti = 1, #H.TIERS do
		for mi = 1, #H.MATERIALS do
			local at = H.TIERS[ti] .. " " .. H.MATERIALS[mi]
			for k = 1, #PROFILES - 1 do
				local a, b = means[at .. " " .. PROFILES[k]], means[at .. " " .. PROFILES[k + 1]]
				A.truthy(a > b, string.format("T-MG-05 %s %s: %s %.4f > %s %.4f", family, at, PROFILES[k], a, PROFILES[k + 1], b))
			end
		end
	end
	local smallest = math.huge
	for mi = 1, #H.MATERIALS do
		for _, profile in PROFILES do
			local drop = means["Normal " .. H.MATERIALS[mi] .. " " .. profile] - means["Hard " .. H.MATERIALS[mi] .. " " .. profile]
			local what = string.format("T-MG-05 %s %s %s: Normal → Hard drop %.4f", family, H.MATERIALS[mi], profile, drop)
			if profile == "Average" then
				A.truthy(drop >= Tol.TIER_MIN_MEAN_DROP, what .. " ≥ TIER_MIN_MEAN_DROP")
			else
				A.truthy(drop > 0, what .. " > 0")
				smallest = math.min(smallest, drop)
			end
		end
	end
	print(string.format("  T-MG-04 %s: worst mean at %.2f of its band, smallest Q8 margin %.1f points; T-MG-05 smallest "
		.. "non-Average drop %.4f", family, worstBand, worstQ8 * 100, smallest))
end

-- T-MG-03 for one family: the Perfect bot (TimingStrike at 60 fps) on SOLVABILITY_SEEDS patterns per tier and
-- material, "T-MG-03 <family> <tier> <material>": the mean rawScore ≥ PERFECT_MIN_SCORE (PERFECT_HZ_MIN_SCORE for
-- HoldZone), as §14.6 writes, and every run ≥ PERFECT_MIN_SCORE (PERFECT_HZ_RUN_MIN_SCORE): the rare impossible pattern
-- SOLVABILITY_SEEDS is sized to find, which a mean cannot see; and Idle scores 0
local function tmg03(family: DT.FamilyId)
	local hz = family == "HoldZone"
	local minMean = if hz then Tol.PERFECT_HZ_MIN_SCORE else Tol.PERFECT_MIN_SCORE
	local runMin = if hz then Tol.PERFECT_HZ_RUN_MIN_SCORE else Tol.PERFECT_MIN_SCORE
	for ti = 1, #H.TIERS do
		local tier: DT.TierId = H.TIERS[ti]
		for mi = 1, #H.MATERIALS do
			local material: DT.MaterialId = H.MATERIALS[mi]
			local cell = string.format("%s %s %s", family, tier, material)
			local name = "T-MG-03 " .. cell
			local n = Tol.SOLVABILITY_SEEDS
			local scores, _, flagged = Bots.run({ family = family, material = material, tier = tier, profile = "Perfect", fps = 60,
				n = n, salt = H.configSalt(name), edge = edgeOf(family) })
			local sum, low, nFlagged = 0, math.huge, 0
			for i = 1, n do
				sum += scores[i]
				low = math.min(low, scores[i])
				if flagged[i] then
					nFlagged += 1
				end
			end
			local want = T_MG_03[cell]
			pinned(string.format("%.6f", sum / n), want[1], name .. ": the mean rawScore")
			pinned(string.format("%.4f", low), want[2], name .. ": the lowest run")
			A.eq(nFlagged, want[3], name .. ": the runs flagged, as precomputed (D11)")
			A.truthy(sum / n >= minMean, string.format("%s: mean %.4f ≥ %.2f", name, sum / n, minMean))
			A.truthy(low >= runMin, string.format("%s: every run ≥ %.2f, lowest %.4f", name, runMin, low))
			local idle = Bots.run({ family = family, material = material, tier = tier, profile = "Idle", n = IDLE_RUNS,
				salt = H.configSalt(name), edge = edgeOf(family) })
			for i = 1, IDLE_RUNS do
				A.eq(idle[i], 0, name .. ": Idle run " .. i .. " scores 0")
			end
		end
	end
end

-- T-MG-06 (b) for one family: Average on Normal, Iron and Steel on one seed list ("T-MG-06 <family>": paired), each
-- STEEL_DROP_RUNS[family] runs: mean(Iron) − mean(Steel) ∈ STEEL_MEAN_DROP (O4's floor 0.005, M4's L3)
local function tmg06(family: DT.FamilyId)
	local name = "T-MG-06 " .. family
	local n = (Tol.STEEL_DROP_RUNS :: any)[family]
	local function run(material: DT.MaterialId): { number }
		return (Bots.run({ family = family, material = material, tier = "Normal", profile = "Average", n = n,
			salt = H.configSalt(name), edge = edgeOf(family) }))
	end
	local iron, steel = run("Iron"), run("Steel")
	local si, ss = 0, 0
	for i = 1, n do
		si += iron[i]
		ss += steel[i]
	end
	local drop = (si - ss) / n
	local want = T_MG_06[family]
	pinned(string.format("%.4f", si / n), want[1], name .. ": the Iron mean")
	pinned(string.format("%.4f", ss / n), want[2], name .. ": the Steel mean")
	pinned(string.format("%.4f", drop), want[3], name .. ": the drop")
	A.truthy(drop >= Tol.STEEL_MEAN_DROP[1] and drop <= Tol.STEEL_MEAN_DROP[2], string.format(
		"%s: Iron − Steel %.4f over %d paired runs, STEEL_MEAN_DROP [%.3f, %.2f]", name, drop, n, Tol.STEEL_MEAN_DROP[1],
		Tol.STEEL_MEAN_DROP[2]))
	print(string.format("  %s: Iron %.4f, Steel %.4f, drop %.4f over %d paired runs", name, si / n, ss / n, drop, n))
end

-- T-MG-12 for one family (the plan's reading, G6): per tier, Iron at BOT_REF_X, FAIRNESS_SEEDS patterns × FAIRNESS_BOT_RUNS
-- Average runs, the bot seeds (r·7919 + salt·31 + 17, r = 1…FAIRNESS_BOT_RUNS) shared across the patterns; the SD over
-- the patterns of the per-pattern mean ≤ FAIRNESS_MAX_SD: no pattern seed makes a step much easier or harder than
-- another for the same players
local function tmg12(family: DT.FamilyId)
	local out: { string } = {}
	for ti = 1, #H.TIERS do
		local tier: DT.TierId = H.TIERS[ti]
		local name = string.format("T-MG-12 %s %s", family, tier)
		local salt = H.configSalt(name)
		local np, nb = Tol.FAIRNESS_SEEDS, Tol.FAIRNESS_BOT_RUNS
		local means: { number } = {}
		for j = 1, np do
			local spec, P = H.prepared(family, "Iron", tier, (Bots.BOT_REF_X :: any)[tier], Bots.seedOf(j, salt), edgeOf(family))
			local sum = 0
			for r = 1, nb do
				sum += Minigames.replay(spec, P, Bots.play(spec, P, Bots.PROFILES.Average, r * 7919 + salt * 31 + 17)).rawScore
			end
			means[j] = sum / nb
		end
		local mm = 0
		for j = 1, np do
			mm += means[j]
		end
		mm /= np
		local v = 0
		for j = 1, np do
			v += (means[j] - mm) * (means[j] - mm)
		end
		local sd = math.sqrt(v / (np - 1))
		pinned(string.format("%.4f", sd), T_MG_12[family][ti], name .. ": the SD of the per-pattern means")
		A.truthy(sd <= Tol.FAIRNESS_MAX_SD, string.format("%s: SD %.4f ≤ FAIRNESS_MAX_SD %.2f", name, sd, Tol.FAIRNESS_MAX_SD))
		table.insert(out, string.format("%s %.4f", tier, sd))
	end
	print(string.format("  T-MG-12 %s: SD of the per-pattern means %s", family, table.concat(out, ", ")))
end

return Test.suite("Minigames/Statistics", function(t)
	t.it("T-MG-06 (a): every Steel column is at least as tight as Iron's, at every MVP tier and design x", function()
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			local listed = STEEL[family]
			local def: any = MF.get(family)
			for _, row in ipairs(def.params) do
				local steel = row.material and row.material.Steel
				if listed[row.name] then
					A.eq(steel, listed[row.name][1], family .. "." .. row.name .. "'s Steel column (§6.8–§6.10)")
				else
					A.eq(steel, nil, family .. "." .. row.name .. " has no Steel column")
				end
			end
			for ti = 1, #H.TIERS do
				for k = 0, 10 do
					local factors = Params.refFactors(k / 10)
					local iron = Params.resolve(family, "Iron", H.TIERS[ti], factors)
					local steel = Params.resolve(family, "Steel", H.TIERS[ti], factors)
					for param, c in listed do
						local what = string.format("%s.%s at %s, x = %.1f: Steel %s, Iron %s", family, param, H.TIERS[ti], k / 10,
							tostring(steel[param]), tostring(iron[param]))
						A.truthy((steel[param] - iron[param]) * c[2] >= 0, what)
					end
				end
			end
		end
	end)

	for fi = 1, #H.FAMILIES do
		local family: DT.FamilyId = H.FAMILIES[fi]
		t.slow(string.format("T-MG-04 and T-MG-05 %s: the 16 cells' means in E-S3.2's bands, Q8's fail rates, the profile "
			.. "order and the Normal → Hard drops", family), function()
			tmg04(family)
		end)
	end

	for fi = 1, #H.FAMILIES do
		local family: DT.FamilyId = H.FAMILIES[fi]
		t.volume(string.format("T-MG-03 %s: the Perfect bot solves every pattern (SOLVABILITY_SEEDS per cell); Idle "
			.. "scores 0", family), function()
			tmg03(family)
		end)
	end

	for fi = 1, #H.FAMILIES do
		local family: DT.FamilyId = H.FAMILIES[fi]
		t.volume(string.format("T-MG-06 (b) %s: Average on Normal drops by STEEL_MEAN_DROP from Iron to Steel (paired "
			.. "runs)", family), function()
			tmg06(family)
		end)
	end

	for fi = 1, #H.FAMILIES do
		local family: DT.FamilyId = H.FAMILIES[fi]
		t.volume(string.format("T-MG-12 %s: the per-pattern Average means vary by at most FAIRNESS_MAX_SD", family), function()
			tmg12(family)
		end)
	end
end)
