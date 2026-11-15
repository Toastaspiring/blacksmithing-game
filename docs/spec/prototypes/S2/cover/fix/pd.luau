--!nocheck
-- every plausible design on the build (LAB_ROOT): kept row and units, one line each; then the heaviest and by part count
-- args: out
local process = require("@lune/process")
local fs = require("@lune/fs")
local L = require("./lab")
local PD = (require :: any)(L.ROOT .. "/tests/Physics/PlausibleDesigns")
local fmt = string.format
local lines, rows, byN = {}, {}, {}
for k, d in ipairs(PD.all()) do
	local e = L.Sampling.exposure(L.prepared(d.parts))
	local kept = {}
	for i = 1, #d.parts do kept[i] = e.kept[i] and "1" or "0" end
	table.insert(lines, fmt("%d\t%s\t%s\t%s\t%s", k, d.name, e.capped and "C" or "-", table.concat(kept), tostring(e.verdictWork)))
	table.insert(rows, { k = k, name = d.name, n = #d.parts, u = e.verdictWork })
	local b = byN[#d.parts] or { count = 0, max = 0 }
	b.count += 1
	b.max = math.max(b.max, e.verdictWork)
	byN[#d.parts] = b
end
fs.writeFile(process.args[1], table.concat(lines, "\n") .. "\n")
table.sort(rows, function(a, b) return a.u > b.u end)
print("designs", #rows)
for i = 1, 20 do
	local r = rows[i]
	print(fmt("%6d %-60s parts %3d units %9.3f  k%%4=%d", r.k, string.sub(r.name, 1, 60), r.n, r.u, r.k % 4))
end
local q, heaviest4, h20 = 0, 0, 0
for _, r in ipairs(rows) do
	if r.k % 4 == 0 then heaviest4 = math.max(heaviest4, r.u) end
	if r.n >= 20 then q += 1; h20 = math.max(h20, r.u) end
end
print(fmt("every 4th: heaviest %.3f; 20 parts or more: %d designs, heaviest %.3f", heaviest4, q, h20))
local ns = {}
for n in pairs(byN) do table.insert(ns, n) end
table.sort(ns)
for _, n in ipairs(ns) do print(fmt("parts %3d designs %6d max units %9.0f", n, byN[n].count, byN[n].max)) end
