--!strict
-- M4 plan critic B: per-run cost of the S3 prototype's TimingStrike FP runs (generate + human bot + replay + checks) on
-- the four T-MG-10 devices, to check the plan's 0.12 ms per run (and so T-MG-10's 4 x 300,000 runs = 144 s).
local Sim = require("./Sim")
local Bots = require("./Bots")
local Params = require("./Params")
local TS = require("./TimingStrike")
local N = 20000
local total = 0
for _, spec in { { "Elite", 240 }, { "Elite", 60 }, { "Good", 60 }, { "Average", 30 } } do
	local prof = Bots.variant((Bots.PROFILES :: any)[spec[1]], spec[2])
	local t0 = os.clock()
	local flagged = 0
	for i = 1, N do
		local tier = if i % 2 == 0 then "Hard" else "Normal"
		local mat = if i % 4 < 2 then "Iron" else "Steel"
		local p = Params.resolve("TimingStrike", mat, tier, Params.refFactors(Sim.REF_X[tier]))
		local pat = TS.generate(Sim.seedOf(i, 77), p)
		local r = TS.replay(pat, Bots.tsHuman(pat, prof, i * 7919 + 77 * 31 + 17, 0))
		if #r.flags > 0 then
			flagged += 1
		end
	end
	local dt = os.clock() - t0
	total += dt / N * 300000
	print(string.format("%s@%d: %.3f ms per run (%d runs, flagged %d) -> 300,000 runs = %.0f s", spec[1], spec[2], dt / N * 1000, N, flagged, dt / N * 300000))
end
print(string.format("T-MG-10 TimingStrike FP at FP_RUNS_TS = 300,000 per device, 4 devices: %.0f s (plan: 144 s)", total))
