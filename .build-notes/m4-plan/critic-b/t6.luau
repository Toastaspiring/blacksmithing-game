--!strict
-- M4 plan critic B: T-MG-06 (b) exactly as the M4 plan words it, on the S3 prototype: Average, Normal, Iron and Steel
-- paired on one seed list, salt = fnv1a32("T-MG-06 <family>"), STEEL_DROP_RUNS = HZ 4000, TS 20000, PT 4000.
local Sim = require("./Sim")
local R = require("./Rng")
local t0 = os.clock()
for _, c in { { "HoldZone", 4000 }, { "TimingStrike", 20000 }, { "PrecisionTrace", 4000 } } do
	local fam, n = c[1], c[2]
	local salt = R.fnv1a32("T-MG-06 " .. fam)
	local pol = if fam == "HoldZone" then "pump" else nil
	local a = Sim.run({ family = fam, material = "Iron", tier = "Normal", profile = "Average", n = n, salt = salt, policy = pol })
	local b = Sim.run({ family = fam, material = "Steel", tier = "Normal", profile = "Average", n = n, salt = salt, policy = pol })
	local sa, sb, s4 = 0, 0, 0
	for i = 1, n do
		sa += a[i]
		sb += b[i]
		if i == 400 then
			s4 = (sa - sb) / 400
		end
	end
	print(string.format("%-14s salt %10d  Iron %.4f  Steel %.4f  drop %.4f over %d paired runs (first 400: %.4f)", fam, salt, sa / n, sb / n, (sa - sb) / n, n, s4))
end
print(string.format("(%.1f s)", os.clock() - t0))
