--!nocheck
-- Units of every plausible design (the build, ../snapcap): the heaviest, by index, name and part count; units by part count.
local PD = require("../snapcap/tests/Physics/PlausibleDesigns")
local Sampling = require("../snapcap/src/shared/Physics/Sampling")
local Shapes = require("../snapcap/src/shared/Physics/Shapes")
local rows = {}
local byN = {}
for k, d in ipairs(PD.all()) do
	local P = {}
	for i, p in ipairs(d.parts) do P[i] = Shapes.prepare(p, i) end
	local e = Sampling.exposure(P)
	table.insert(rows, { k = k, name = d.name, n = #d.parts, u = e.verdictWork })
	local b = byN[#d.parts] or { count = 0, max = 0 }
	b.count += 1
	b.max = math.max(b.max, e.verdictWork)
	byN[#d.parts] = b
end
table.sort(rows, function(a, b) return a.u > b.u end)
print("designs", #rows)
for i = 1, 40 do
	local r = rows[i]
	print(string.format("%6d %-60s parts %3d units %9.0f  k%%4=%d", r.k, string.sub(r.name, 1, 60), r.n, r.u, r.k % 4))
end
local ns = {}
for n in pairs(byN) do table.insert(ns, n) end
table.sort(ns)
for _, n in ipairs(ns) do print(string.format("parts %3d designs %6d max units %9.0f", n, byN[n].count, byN[n].max)) end
