--!nocheck
local PD = require("../snapcap/tests/Physics/PlausibleDesigns")
local Sampling = require("../snapcap/src/shared/Physics/Sampling")
local Shapes = require("../snapcap/src/shared/Physics/Shapes")
local best, name, n = 0, "", 0
local byFam = {}
for _, d in ipairs(PD.all()) do
	local P = {}
	for i, p in ipairs(d.parts) do P[i] = Shapes.prepare(p, i) end
	local e = Sampling.exposure(P)
	n += 1
	if e.verdictWork > best then best, name = e.verdictWork, d.name end
	byFam[d.family] = math.max(byFam[d.family] or 0, e.verdictWork)
end
print(n, best, name)
for f, u in pairs(byFam) do print(f, u) end
