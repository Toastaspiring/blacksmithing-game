--!nocheck
-- every plausible design (tests/Physics/PlausibleDesigns.all): the verdicts' units, the largest single report, per family
local L = require("./lib")
local Plaus = require("./repo/tests/Physics/PlausibleDesigns")
local fmt = string.format
local all = Plaus.all()
local fam = {}
local best, bestName, maxRep, maxRepName = 0, "", 0, ""
for k, d in ipairs(all) do
	local parts = d.parts or d[3]
	local name = d.name or d[1]
	local family = d.family or d[2]
	local P = L.prep(L.renumber(L.copyParts(parts)))
	local mx = 0
	local e = L.Sampling.exposure(P, function(n) if n > mx then mx = n end end)
	local u = e.verdictWork
	local f = fam[family] or { n = 0, max = 0 }
	f.n += 1
	f.max = math.max(f.max, u)
	fam[family] = f
	if u > best then best, bestName = u, name end
	if mx > maxRep then maxRep, maxRepName = mx, name end
end
print(fmt("%d plausible designs: the most units %.1f (%s); the largest single report %.1f (%s)", #all, best, tostring(bestName), maxRep, tostring(maxRepName)))
local names = {}
for k in pairs(fam) do table.insert(names, k) end
table.sort(names)
for _, k in ipairs(names) do print(fmt("  %-20s %6d designs, at most %10.1f units", tostring(k), fam[k].n, fam[k].max)) end
