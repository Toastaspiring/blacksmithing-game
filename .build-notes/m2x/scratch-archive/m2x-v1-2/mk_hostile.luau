--!nocheck
-- writes my hostile designs as JSON for t_time: the rod bundle, the big-report sword, the honest designs past the cap
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local function bundle(d, ov)
	local parts = {}
	local step = d * (1 - ov)
	for i = 1, 6 do table.insert(parts, L.part("Grip", "Cylinder", { (i - 3.5) * step, 0.65, 0 }, L.Z90, { 0.9, d, d })) end
	for i = 1, 6 do table.insert(parts, L.part("Guard", "Cylinder", { 0, 1.15 + (i - 3.5) * step, 0 }, L.I, { 1.0, d, d })) end
	for i = 1, 12 do table.insert(parts, L.part("Blade", "Cylinder", { (i - 6.5) * step, 2.5, 0 }, L.Z90, { 2.6, d, d })) end
	return L.renumber(parts)
end
fs.writeFile("out/h_bundle.json", serde.encode("json", bundle(0.12, 0.4)))
local base = L.repoFixture("F5")
local parts = { base[1], base[2], base[3] }
local y0 = 1.38
table.insert(parts, L.part("Blade", "Block", { 0, y0 + 0.3, 0 }, L.I, { 0.7, 0.6, 0.58 }))
table.insert(parts, L.part("Blade", "Cylinder", { 0, y0 + 0.3 + 0.004, 0 }, L.Z90, { 0.6, 0.3, 0.3 }))
table.insert(parts, L.part("Guard", "Ball", { 0, y0 + 0.6 + 0.004, 0 }, L.I, { 0.08, 0.08, 0.08 }))
table.insert(parts, L.part("Blade", "Block", { 0.27, y0 + 0.6 + 1.2, 0 }, L.I, { 0.16, 2.4, 0.06 }))
fs.writeFile("out/h_report.json", serde.encode("json", L.renumber(parts)))
print("written")
