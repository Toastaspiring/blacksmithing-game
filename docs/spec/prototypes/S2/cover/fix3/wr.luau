--!nocheck
local Lab = require("./lab")
local fmt = string.format
local names = { "base", Lab.SCR .. "/m2x-fix-3/var_AB", "now" }
local N = Lab.tree("now")
local PD = (require :: any)(N.root .. "/tests/Physics/PlausibleDesigns")
for _, d in ipairs(PD.all()) do
	if d.name == "wrapRings|C09|n5 extra0.04 gap0.0020" or d.name == "wrapRings|C09|n3 extra0.04 gap0.0500" then
		local row = {}
		for _, n in ipairs(names) do
			local T = Lab.tree(n)
			table.insert(row, fmt("%.3f", T.Sampling.exposure(T.prep(d.parts)).verdictWork))
		end
		print(d.name, table.concat(row, " / "))
	end
end
