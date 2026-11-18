--!strict
-- M4 plan critic B: T-MG-12 as the M4 plan defines it, on the S3 prototype (which the build reproduces bit for bit):
-- per family x tier (Iron, x = REF_X), 100 pattern seeds x 20 Average runs, the 20 bot seeds shared across patterns;
-- statistic = sample SD over the 100 pattern seeds of the per-pattern mean (FAIRNESS_MAX_SD 0.08).
local Sim = require("./Sim")
local Bots = require("./Bots")
local Params = require("./Params")
local R = require("./Rng")
local HZ = require("./HoldZone")
local TS = require("./TimingStrike")
local PT = require("./PrecisionTrace")

local NP, NB = 100, 20
local t0 = os.clock()
for _, fam in { "HoldZone", "TimingStrike", "PrecisionTrace" } do
	for _, tier in { "Normal", "Hard" } do
		local salt = R.fnv1a32("T-MG-12 " .. fam .. " " .. tier)
		local p = Params.resolve(fam, "Iron", tier, Params.refFactors(Sim.REF_X[tier]))
		local prof = (Bots.PROFILES :: any).Average
		local src = if fam == "PrecisionTrace" then Sim.source("arming", p.pacerSpeed) else nil
		local means = {}
		local withinSum = 0
		for j = 1, NP do
			local seed = Sim.seedOf(j, salt)
			local sc = {}
			for r = 1, NB do
				local botSeed = r * 7919 + salt * 31 + 17
				local s
				if fam == "HoldZone" then
					local pat = HZ.generate(seed, p)
					local _, res = Bots.hzHuman(pat, prof, botSeed, "pump")
					s = res.score
				elseif fam == "TimingStrike" then
					local pat = TS.generate(seed, p)
					s = TS.replay(pat, Bots.tsHuman(pat, prof, botSeed, 0)).score
				else
					local pat = PT.generate(seed, p, src)
					s = PT.replay(pat, Bots.ptHuman(pat, prof, botSeed)).score
				end
				sc[r] = s
			end
			local m = 0
			for r = 1, NB do
				m += sc[r]
			end
			m /= NB
			local v = 0
			for r = 1, NB do
				v += (sc[r] - m) * (sc[r] - m)
			end
			withinSum += v / (NB - 1)
			means[j] = m
		end
		local mm = 0
		for j = 1, NP do
			mm += means[j]
		end
		mm /= NP
		local vm = 0
		local lo, hi = math.huge, -math.huge
		for j = 1, NP do
			vm += (means[j] - mm) * (means[j] - mm)
			lo, hi = math.min(lo, means[j]), math.max(hi, means[j])
		end
		vm /= (NP - 1)
		local within = withinSum / NP
		local between2 = vm - within / NB
		print(string.format("%-14s %-6s mean %.4f  SD of per-pattern means %.4f (gate 0.08)  within-pattern SD %.4f  between-pattern SD %.4f  per-pattern means %.3f..%.3f",
			fam, tier, mm, math.sqrt(vm), math.sqrt(within), if between2 > 0 then math.sqrt(between2) else 0, lo, hi))
	end
end
print(string.format("(%.1f s)", os.clock() - t0))
