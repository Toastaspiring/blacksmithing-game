-- Perfect / Idle checks per family x config at 60 and 30 fps (TS), x = tier reference and x = 1
local Sim = require("./Sim")
local Bots = require("./Bots")
local process = require("@lune/process")
local N = tonumber(process.args[1]) or 1000
for _, fam in { "HoldZone", "TimingStrike", "PrecisionTrace" } do
	for _, c in { { "Iron", "Normal" }, { "Steel", "Normal" }, { "Iron", "Hard" }, { "Steel", "Hard" } } do
		local cells = {}
		for _, x in { -1, 1 } do
			local fpsList = if fam == "TimingStrike" then { 60, 30 } else { 60 }
			for _, fps in fpsList do
				local s, p, f = Sim.run({ family = fam, material = c[1], tier = c[2], profile = "Perfect", fps = fps, n = if fam == "TimingStrike" then N else math.min(N, 200), x = if x < 0 then nil else x })
				local st = Bots.stats(s, p, f)
				local mn = 1
				for _, v in s do mn = math.min(mn, v) end
				table.insert(cells, string.format("x=%s fps%d mean %.4f min %.4f flag %.0f%%", if x < 0 then "ref" else tostring(x), fps, st.mean, mn, st.flag * 100))
			end
		end
		print(fam, c[1], c[2], table.concat(cells, " | "))
	end
end
