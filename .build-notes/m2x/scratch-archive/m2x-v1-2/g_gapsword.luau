--!nocheck
-- a valid sword holding the single-report maximiser (a Block with a Cylinder sunk in it, its cap 0.006 proud, a Ball r 0.04
-- centred on the cap): its largest report, and the checkpoint gaps of Analyze.run (median of 15)
local L = require("./lib")
local fmt = string.format
local base = L.repoFixture("F5")
local parts = { base[1], base[2], base[3] }
-- the blade: a wide block 0.7 × 0.6 × 0.58 from y 1.38, a Cylinder R 0.2 sunk in it (axis Y), a Ball on its cap, the rest
local y0 = 1.38
table.insert(parts, L.part("Blade", "Block", { 0, y0 + 0.3, 0 }, L.I, { 0.7, 0.6, 0.58 }))
table.insert(parts, L.part("Blade", "Cylinder", { 0, y0 + 0.3 + 0.006, 0 }, L.Z90, { 0.6, 0.4, 0.4 }))
table.insert(parts, L.part("Guard", "Ball", { 0, y0 + 0.6 + 0.006, 0 }, L.I, { 0.08, 0.08, 0.08 }))
table.insert(parts, L.part("Blade", "Block", { 0, y0 + 0.6 + 1.2, 0 }, L.I, { 0.16, 2.4, 0.06 }))
L.renumber(parts)
local P = L.prep(parts)
local mx = 0
local e = L.Sampling.exposure(P, function(n) if n > mx then mx = n end end)
local r = L.run(L.copyParts(parts), { measureInvalid = false })
print(fmt("valid %s %s; verdict %.1f units; largest single report %.1f", tostring(r.validation.ok), L.codes(r), e.verdictWork, mx))
local core = { schema = 1, name = "x", type = "Sword", parts = parts }
local gaps = {}
for k = 1, 15 do
	local last = os.clock()
	local worst = 0
	L.Analyze.run(core, { checkpoint = function()
		local now = os.clock()
		if now - last > worst then worst = now - last end
		last = now
	end })
	table.insert(gaps, worst * 1000)
end
table.sort(gaps)
print(fmt("checkpoint gaps, the longest per run (ms): median %.3f, min %.3f, max %.3f", gaps[8], gaps[1], gaps[15]))
