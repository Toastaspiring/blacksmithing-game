--!strict
-- M4 plan critic B: T-MG-04 / T-MG-05 exactly as the M4 plan words them, on the S3 prototype: the 48 cells, salt =
-- fnv1a32("T-MG-04 <family> <tier> <material> <profile>"), i = 1..400 (BOT_RUNS) for the means, i = 1..1000
-- (BOT_RUNS_FAIL, the same list extended) for Average and Good fail rates. Prints one line per cell for tail analysis.
local Sim = require("./Sim")
local R = require("./Rng")
local t0 = os.clock()
for _, fam in { "HoldZone", "TimingStrike", "PrecisionTrace" } do
	for _, tier in { "Normal", "Hard" } do
		for _, mat in { "Iron", "Steel" } do
			for _, prof in { "Elite", "Good", "Average", "Poor" } do
				local salt = R.fnv1a32("T-MG-04 " .. fam .. " " .. tier .. " " .. mat .. " " .. prof)
				local n = if prof == "Average" or prof == "Good" then 1000 else 400
				local s, _, f = Sim.run({ family = fam, material = mat, tier = tier, profile = prof, n = n, salt = salt, policy = if fam == "HoldZone" then "pump" else nil })
				local sum, fails, flags = 0, 0, 0
				for i = 1, n do
					if i <= 400 then
						sum += s[i]
					end
					if s[i] < 0.5 then
						fails += 1
					end
					if f[i] then
						flags += 1
					end
				end
				print(string.format("CELL %s %s %s %s mean400 %.6f fails %d n %d flagged %d", fam, tier, mat, prof, sum / 400, fails, n, flags))
			end
		end
	end
end
print(string.format("(%.1f s)", os.clock() - t0))
