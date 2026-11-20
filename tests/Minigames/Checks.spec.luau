--!strict
-- Minigames/Checks (SPEC §6.2, §6.4 rules 4 and 7, §10.5, §10.6): the left-to-right mean; the two-pass sample SD, bit
-- for bit the S3 prototype's TimingStrike variance; the most entries in a window at its exact boundaries; the check
-- thresholds and flag levels read from Definitions/MinigameFamilies (D3's PtTooSmooth dt rows included); the HIGH test;
-- and the byte-ordered flag list.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local DT = require("../../src/shared/Definitions/Types")
local MF = require("../../src/shared/Definitions/MinigameFamilies")
local Checks = require("../../src/shared/Minigames/Checks")
local Types = require("../../src/shared/Minigames/Types")

type FlagId = Types.FlagId

local MVP: { DT.FamilyId } = { "HoldZone", "TimingStrike", "PrecisionTrace" }
-- §6.2's FlagIds in byte order
local SORTED: { FlagId } =
	{ "HzInhumanRate", "PtSparse", "PtTeleport", "PtTooPrecise", "PtTooSmooth", "TsExactHits", "TsLowVariance" }

-- the S3 prototype's TimingStrike variance (v2/TimingStrike.luau, TS.checks), written out as it stands
local function prototypeSd(errs: { number }): number
	local n = #errs
	local sum = 0
	for _, e in errs do
		sum += e
	end
	local mean = sum / n
	local ss = 0
	for _, e in errs do
		ss += (e - mean) * (e - mean)
	end
	return math.sqrt(ss / (n - 1))
end

return Test.suite("Minigames/Checks", function(t)
	t.it("mean: the left-to-right sum over n; 0 for none", function()
		A.eq(Checks.mean({}), 0)
		A.eq(Checks.mean({ 4 }), 4)
		A.eq(Checks.mean({ 1, 2, 3, 4 }), 2.5)
		-- the order is the array's, uncompensated (§6.4 rule 4): (1e17 + 1) − 1e17 rounds the 1 away (1e17's ulp is
		-- 16), (1e17 − 1e17) + 1 keeps it
		A.eq(Checks.mean({ 1e17, 1, -1e17 }), 0, "left to right")
		A.eq(Checks.mean({ 1, 1e17, -1e17 }), 0, "left to right")
		A.eq(Checks.mean({ 1e17, -1e17, 1 }), 1 / 3, "left to right")
	end)

	t.it("sampleSd: n − 1, two passes, the prototype's TimingStrike variance bit for bit; refuses n < 2", function()
		A.eq(Checks.sampleSd({ 5, 5 }), 0)
		A.eq(Checks.sampleSd({ 1, 2, 3, 4 }), math.sqrt(5 / 3), "Σ (x − 2.5)² = 5 over n − 1 = 3")
		A.eq(Checks.sampleSd({ -1, 1 }), math.sqrt(2))
		A.throws(function()
			Checks.sampleSd({ 1 })
		end, "at least 2")
		A.throws(function()
			Checks.sampleSd({})
		end, "at least 2")
		Prop.check(Tol.PROP_N, function(rng: TestRng.TestRng): { number }
			local errs: { number } = {}
			for i = 1, rng:int(2, 40) do
				-- integer ms errors as TimingStrike judges them, and now and then a fraction
				errs[i] = if rng:int(1, 5) == 1 then rng:range(-200, 200) else rng:int(-200, 200)
			end
			return errs
		end, function(errs: { number })
			A.eq(Checks.sampleSd(errs), prototypeSd(errs), "bit for bit")
		end)
	end)

	t.it("maxInWindow: the most entries in any [t_j, t_j + w), exact at the boundary", function()
		A.eq(Checks.maxInWindow({}, 1000), 0)
		A.eq(Checks.maxInWindow({ 5 }, 1000), 1)
		A.eq(Checks.maxInWindow({ 0, 999 }, 1000), 2, "999 ms apart: one window")
		A.eq(Checks.maxInWindow({ 0, 1000 }, 1000), 1, "1000 ms apart: two")
		A.eq(Checks.maxInWindow({ 0, 0, 0 }, 1000), 3, "equal times")
		A.eq(Checks.maxInWindow({ 0, 600, 1100, 1500, 2600 }, 1000), 3, "600, 1100, 1500")
		-- 30 presses 34 ms apart span 986 ms: all in one window; 35 ms apart span 1015 ms: 29
		local tight, loose = {}, {}
		for i = 1, 30 do
			tight[i] = (i - 1) * 34
			loose[i] = (i - 1) * 35
		end
		A.eq(Checks.maxInWindow(tight, 1000), 30)
		A.eq(Checks.maxInWindow(loose, 1000), 29)
		A.throws(function()
			Checks.maxInWindow({ 1, 2 }, 0)
		end, "positive")
		-- against a brute force over every window that starts at an entry
		Prop.check(Tol.PROP_N, function(rng: TestRng.TestRng): { any }
			local times: { number } = {}
			local tNow = 0
			for i = 1, rng:int(0, 60) do
				tNow += rng:int(0, 120)
				times[i] = tNow
			end
			return { times = times, w = rng:int(1, 1500) }
		end, function(c: any)
			local best = 0
			for j = 1, #c.times do
				local n = 0
				for i = j, #c.times do
					if c.times[i] - c.times[j] < c.w then
						n += 1
					end
				end
				best = math.max(best, n)
			end
			A.eq(Checks.maxInWindow(c.times, c.w), best)
		end)
	end)

	t.it("value reads each check row of Definitions/MinigameFamilies, D3's PtTooSmooth dt bounds included", function()
		for _, family: DT.FamilyId in MVP do
			local def = MF.get(family) :: MF.MinigameFamilyDef
			local seen: { [string]: boolean } = {}
			for _, c in ipairs(def.checks) do
				A.falsy(seen[c.name], family .. ": " .. c.name .. " is unique, so a lookup by name cannot depend on order")
				seen[c.name] = true
				A.eq(Checks.value(family, c.name), c.value, family .. "." .. c.name)
			end
		end
		A.eq(Checks.value("HoldZone", "HZ_RATE_WINDOW_MS"), 1000)
		A.eq(Checks.value("HoldZone", "HZ_RATE_MAX_PRESSES"), 30)
		A.eq(Checks.value("TimingStrike", "TS_MIN_SD_MS"), 1.5)
		A.eq(Checks.value("PrecisionTrace", "PT_SMOOTH_DT_MIN_MS"), 10)
		A.eq(Checks.value("PrecisionTrace", "PT_SMOOTH_DT_MAX_MS"), 40)
		A.throws(function()
			Checks.value("HoldZone", "TS_MIN_SD_MS")
		end, "HoldZone has no check TS_MIN_SD_MS")
		A.throws(function()
			Checks.value("NoSuchFamily" :: any, "X")
		end, "no minigame family NoSuchFamily")
	end)

	t.it("level and anyHigh: every FlagId's level from flagLevels; only a High flag counts", function()
		local all = 0
		for _, family: DT.FamilyId in MVP do
			local def = MF.get(family) :: MF.MinigameFamilyDef
			local seen: { [string]: boolean } = {}
			local highs: { FlagId } = {}
			local mediums: { FlagId } = {}
			for _, f in ipairs(def.flagLevels) do
				all += 1
				local flag: FlagId = f.flag :: FlagId
				A.falsy(seen[flag], family .. ": " .. flag .. " is unique")
				seen[flag] = true
				A.eq(Checks.level(family, flag), f.level, family .. ": " .. flag)
				table.insert(if f.level == "High" then highs else mediums, flag)
			end
			A.falsy(Checks.anyHigh(family, {}), family .. ": no flag")
			A.falsy(Checks.anyHigh(family, mediums), family .. ": medium flags only")
			for _, high in highs do
				local mixed = table.clone(mediums)
				table.insert(mixed, high)
				A.truthy(Checks.anyHigh(family, mixed), family .. ": " .. high .. " among medium flags")
			end
		end
		A.eq(all, 7, "the seven FlagIds")
		A.eq(Checks.level("PrecisionTrace", "PtTooPrecise"), "High")
		A.eq(Checks.level("PrecisionTrace", "PtSparse"), "Medium")
		A.throws(function()
			Checks.level("HoldZone", "PtSparse")
		end, "HoldZone raises no flag PtSparse")
	end)

	t.it("sorted: a new array in byte order, the input untouched", function()
		local rng = TestRng.new(0x5EED0005)
		for _ = 1, 50 do
			local shuffled: { FlagId } = {}
			for _, flag in SORTED do
				table.insert(shuffled, rng:int(1, #shuffled + 1), flag)
			end
			local before = table.clone(shuffled)
			local out = Checks.sorted(table.freeze(shuffled))
			A.deepEq(out, SORTED, "byte order")
			A.deepEq(shuffled, before, "the input is unchanged")
			A.truthy(out ~= shuffled and not table.isfrozen(out), "a new array")
		end
		local two: { FlagId } = { "TsLowVariance", "TsExactHits" }
		A.deepEq(Checks.sorted(two), { "TsExactHits", "TsLowVariance" } :: { FlagId }, "§10.5's order for the Exact cheat")
		A.deepEq(Checks.sorted({}), {}, "none")
	end)
end)
