--!strict
-- M4 plan critic B: T-MG-10's PrecisionTrace margin as the M4 plan sizes it (FP_RUNS = 20,000 on the Elite 30 fps /
-- 360 px device, Iron, Normal and Hard halves, design x = REF_X as Bots.run defaults), on the S3 prototype.
-- Writes every run's mean deviation (devN >= 40) so the lower tail can be analysed; usage: lune run ptmargin.luau <n> <out>
local Sim = require("./Sim")
local Bots = require("./Bots")
local Params = require("./Params")
local R = require("./Rng")
local PT = require("./PrecisionTrace")
local fs = require("@lune/fs")
local process = require("@lune/process")

local N = tonumber(process.args[1]) or 10000
local OUT = process.args[2]
local lines = {}
local t0 = os.clock()
for _, tier in { "Normal", "Hard" } do
	local name = "T-MG-10 PrecisionTrace Elite@30/360 " .. tier
	local salt = R.fnv1a32(name)
	local p = Params.resolve("PrecisionTrace", "Iron", tier, Params.refFactors(Sim.REF_X[tier]))
	local src = Sim.source("arming", p.pacerSpeed)
	local prof = table.clone(Bots.variant((Bots.PROFILES :: any).Elite, 30)) :: any
	prof.panelPx = 360
	local flagged, minDev, minJerk, nDev = 0, math.huge, math.huge, 0
	local devs = {}
	for i = 1, N do
		local pat = PT.generate(Sim.seedOf(i, salt), p, src)
		local smp = Bots.ptHuman(pat, prof, i * 7919 + salt * 31 + 17)
		local fl, info = PT.checks(pat, smp)
		if #fl > 0 then
			flagged += 1
		end
		if info.devN >= PT.PRECISE_MIN_SAMPLES then
			nDev += 1
			devs[nDev] = string.format("%.7f", info.meanDev)
			minDev = math.min(minDev, info.meanDev)
		end
		if info.jerkN >= PT.SMOOTH_MIN_TRIPLETS then
			minJerk = math.min(minJerk, info.meanJerk)
		end
	end
	table.insert(lines, tier .. " " .. table.concat(devs, " "))
	print(string.format("%s: %d runs, flagged %d, runs with devN>=40 %d, min mean deviation %.5f u (x%.2f of 0.0008; plan's floor 0.0024 = x3), min mean jerk %.5f",
		tier, N, flagged, nDev, minDev, minDev / PT.PRECISE_MEAN_DEV, minJerk))
end
print(string.format("(%.1f s)", os.clock() - t0))
if OUT then
	fs.writeFile(OUT, table.concat(lines, "\n") .. "\n")
end
