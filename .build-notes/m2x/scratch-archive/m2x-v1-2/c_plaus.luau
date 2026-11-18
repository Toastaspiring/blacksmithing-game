--!nocheck
-- plausible-looking valid swords heavy in round parts: their units against VERDICT_WORK_MAX
local L = require("./lib")
local fmt = string.format
local function report(name, parts)
	L.renumber(parts)
	local P = L.prep(parts)
	local u = L.units(P)
	local r = L.run(L.copyParts(parts), { measureInvalid = false })
	local t0 = os.clock()
	for k = 1, 3 do L.Sampling.exposure(P) end
	print(fmt("%-60s %2d parts %10.1f units (%.2f × under the cap), valid %s %s, exposure %.1f ms", name, #parts, u, L.Geo.VERDICT_WORK_MAX / u, tostring(r.validation.ok), L.codes(r), (os.clock() - t0) / 3 * 1000))
end
-- a beaded sword: 6 Ball beads on the grip, 8 Balls in the guard, 4 in the pommel, a blade of 6 overlapping Balls under a
-- core, all overlapping their neighbours
for _, ov in ipairs({ 0.3, 0.5, 0.7, 0.85 }) do
	local parts = {}
	local d = 0.18
	local step = d * (1 - ov)
	for i = 1, 4 do table.insert(parts, L.part("Pommel", "Ball", { (i - 2.5) * step, 0.1, 0 }, L.I, { d, d, d })) end
	for i = 1, 6 do table.insert(parts, L.part("Grip", "Ball", { 0, 0.1 + i * step, 0 }, L.I, { d, d, d })) end
	local gy = 0.1 + 6 * step + step
	for i = 1, 8 do table.insert(parts, L.part("Guard", "Ball", { (i - 4.5) * step, gy, 0 }, L.I, { d, d, d })) end
	table.insert(parts, L.part("Blade", "Block", { 0, gy + 1.3, 0 }, L.I, { 0.16, 2.5, 0.06 }))
	for i = 1, 5 do table.insert(parts, L.part("Blade", "Ball", { 0, gy + 0.2 + i * step, 0 }, L.I, { d, d, d })) end
	report(fmt("beaded: Balls d %.2f overlapping %.0f%%", d, 100 * ov), parts)
end
-- a cylinder-bundle blade: 12 Cylinders along Y, overlapping, a grip of 6 Cylinders, guard of 6 Cylinders across
for _, ov in ipairs({ 0.3, 0.6, 0.85 }) do
	local parts = {}
	local d = 0.08
	local step = d * (1 - ov)
	for i = 1, 6 do table.insert(parts, L.part("Grip", "Cylinder", { (i - 3.5) * step, 0.65, 0 }, L.Z90, { 0.9, d, d })) end
	for i = 1, 6 do table.insert(parts, L.part("Guard", "Cylinder", { 0, 1.15 + (i - 3.5) * step, 0 }, L.I, { 1.0, d, d })) end
	for i = 1, 12 do table.insert(parts, L.part("Blade", "Cylinder", { (i - 6.5) * step, 2.5, 0 }, L.Z90, { 2.6, d, d })) end
	report(fmt("bundle: Cylinders d %.2f overlapping %.0f%%", d, 100 * ov), parts)
end
