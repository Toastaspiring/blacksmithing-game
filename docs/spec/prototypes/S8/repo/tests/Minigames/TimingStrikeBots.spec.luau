--!strict
-- Bot-driven replay tests (toy TimingStrike). Shape of the real family suites.
local Test = require("../lib/Test")
local A = require("../lib/Assert")
local TestRng = require("../lib/TestRng")
local Bots = require("../lib/Bots")
local TS = require("../../src/shared/Minigames/ProtoTimingStrike")

local NORMAL: TS.Params = { strikes = 12, periodMs = 700, jitterMs = 120, windowMs = 120, passScore = 0.5 }
local HARD: TS.Params = { strikes = 12, periodMs = 550, jitterMs = 150, windowMs = 90, passScore = 0.5 }
local RUNS = 400

local function play(profile: Bots.Profile, params: TS.Params, runs: number): (number, number, number)
	local rng = TestRng.new(0xB0757)
	local sum, passes, flagged = 0, 0, 0
	for _ = 1, runs do
		local seed = rng:u32()
		local pattern = TS.generate(seed, params)
		local r = TS.score(pattern, params, Bots.strikes(pattern.targets, profile, rng))
		assert(r.ok, "bot produced an invalid timeline: " .. tostring(r.code))
		sum += r.score
		if r.pass then passes += 1 end
		if #r.flags > 0 then flagged += 1 end
	end
	return sum / runs, passes / runs, flagged
end

return Test.suite("Minigames/TimingStrike bots (prototype)", function(t)
	t.it("replay is deterministic", function()
		local pattern = TS.generate(42, NORMAL)
		A.deepEq(TS.generate(42, NORMAL), pattern)
		local tl = Bots.strikes(pattern.targets, Bots.Profiles.GoodHuman, TestRng.new(1))
		A.deepEq(TS.score(pattern, NORMAL, tl), TS.score(pattern, NORMAL, tl))
	end)

	t.it("perfect inputs score 1.0 and are flagged by the full validator", function()
		local pattern = TS.generate(7, NORMAL)
		local r = TS.score(pattern, NORMAL, Bots.strikes(pattern.targets, Bots.Profiles.Perfect, TestRng.new(1)))
		A.eq(r.score, 1)
		A.eq(r.flags[1], "InhumanPrecision")
	end)

	t.slow("score bands per profile and tier, humans never flagged", function()
		local bands = {
			{ Bots.Profiles.GoodHuman, NORMAL, 0.75, 0.92, 0.95 }, { Bots.Profiles.GoodHuman, HARD, 0.60, 0.85, 0.80 },
			{ Bots.Profiles.AverageHuman, NORMAL, 0.55, 0.80, 0.80 }, { Bots.Profiles.AverageHuman, HARD, 0.40, 0.70, 0.55 },
			{ Bots.Profiles.PoorHuman, NORMAL, 0.15, 0.50, 0.00 }, { Bots.Profiles.PoorHuman, HARD, 0.05, 0.40, 0.00 },
		}
		for _, b in bands do
			local profile, params, lo, hi, minPass = b[1] :: Bots.Profile, b[2] :: TS.Params, b[3] :: number, b[4] :: number, b[5] :: number
			local mean, passRate, flagged = play(profile, params, RUNS)
			local label = string.format("%s @W=%d mean=%.3f pass=%.2f", profile.id, params.windowMs, mean, passRate)
			print("      " .. label)
			A.within(mean, lo, hi, label)
			A.truthy(passRate >= minPass, label .. " pass rate")
			A.eq(flagged, 0, label .. " flagged")
		end
	end)

	t.slow("Hard is measurably harder than Normal for the same human", function()
		local n = play(Bots.Profiles.AverageHuman, NORMAL, RUNS)
		local h = play(Bots.Profiles.AverageHuman, HARD, RUNS)
		A.truthy(n - h >= 0.05, string.format("Normal %.3f vs Hard %.3f", n, h))
	end)

	t.it("cheats: spam is penalised, malformed timelines are rejected without throwing", function()
		local pattern = TS.generate(9, NORMAL)
		local spam = TS.score(pattern, NORMAL, Bots.spam(pattern.durationMs, 10))
		A.truthy(not spam.ok or spam.score <= 0.2, "spam score " .. spam.score)
		for _, bad in { "x", { { t = 0 / 0 } }, { { t = 5 }, { t = 4 } }, { { t = -1 } }, { { t = 1.5 } }, { { t = 1e12 } }, { 1, 2, 3 } } do
			local r = TS.score(pattern, NORMAL, bad :: any)
			A.falsy(r.ok, "accepted malformed timeline")
			A.truthy(type(r.code) == "string")
		end
		local idle = TS.score(pattern, NORMAL, {})
		A.eq(idle.score, 0)
		A.falsy(idle.pass)
		A.eq(#idle.flags, 0)
	end)
end)
