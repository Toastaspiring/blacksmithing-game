--!strict
-- Dump raw factor values (All / Blade sets) for the calibration + golden fixtures, with Thinness at several
-- (SIGMA_LO, SIGMA_HI) pairs, as CSV for the range fit (calib.py).
local Analyze = require("./analyze")
local Fx = require("./fixtures")
local CFG = Analyze.CFG
local fmt = string.format

local list = {}
for _, b in ipairs(Fx.calibration()) do table.insert(list, b) end
for _, b in ipairs(Fx.golden()) do table.insert(list, b) end
table.insert(list, Fx.validation()[9]) -- A24 needle
local sig = { { 40, 130 }, { 45, 130 }, { 50, 130 }, { 50, 140 }, { 55, 140 }, { 50, 150 }, { 60, 150 } }
local head = "name,As_All,As_Bl,SC_All,SC_Bl,EL,Vo_All"
for _, s in ipairs(sig) do
	head ..= fmt(",Th_All_%d_%d,Th_Bl_%d_%d", s[1], s[2], s[1], s[2])
end
print(head)
for _, b in ipairs(list) do
	local row = nil
	for _, s in ipairs(sig) do
		CFG.SIGMA_LO, CFG.SIGMA_HI = s[1], s[2]
		local R = Analyze.run(b)
		if row == nil then
			local A, B = R.sets.All.raw, R.sets.Blade.raw
			row = fmt("%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f", (string.gsub(b.name, ",", ";")), A.Asymmetry, B.Asymmetry, A.SurfaceComplexity, B.SurfaceComplexity, A.EdgeLength, A.Volume)
		end
		row ..= fmt(",%.6f,%.6f", R.sets.All.raw.Thinness, R.sets.Blade.raw.Thinness)
	end
	print(row)
end
