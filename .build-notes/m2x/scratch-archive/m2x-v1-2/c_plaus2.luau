--!nocheck
-- rod-bundle and bead swords over their parameters: the heaviest that stay canonical and valid, and the first past the cap
local process = require("@lune/process")
local L = require("./lib")
local fmt = string.format
local which = process.args[1] or "bundle"
local results = {}
local function eval(name, parts)
	L.renumber(parts)
	local okc = L.canonical(L.copyParts(parts))
	local P = L.prep(parts)
	local u = L.units(P)
	local r = L.run(L.copyParts(parts), { measureInvalid = false })
	local codes = L.codes(r)
	table.insert(results, { name = name, u = u, valid = r.validation.ok, codes = codes, canon = okc })
end
if which == "bundle" then
	for _, d in ipairs({ 0.04, 0.05, 0.06, 0.08, 0.1, 0.12 }) do
		for _, ov in ipairs({ 0, 0.1, 0.2, 0.3, 0.4, 0.5 }) do
			for _, nb in ipairs({ 8, 10, 12 }) do
				local parts = {}
				local step = d * (1 - ov)
				for i = 1, 6 do table.insert(parts, L.part("Grip", "Cylinder", { (i - 3.5) * step, 0.65, 0 }, L.Z90, { 0.9, d, d })) end
				for i = 1, 6 do table.insert(parts, L.part("Guard", "Cylinder", { 0, 1.15 + (i - 3.5) * step, 0 }, L.I, { 1.0, d, d })) end
				for i = 1, nb do table.insert(parts, L.part("Blade", "Cylinder", { (i - (nb + 1) / 2) * step, 2.5, 0 }, L.Z90, { 2.6, d, d })) end
				eval(fmt("bundle d %.2f overlap %.0f%% blade %d rods", d, 100 * ov, nb), parts)
			end
		end
	end
else
	for _, d in ipairs({ 0.12, 0.16, 0.2, 0.24 }) do
		for _, ov in ipairs({ 0.5, 0.6, 0.7, 0.75, 0.8 }) do
			local parts = {}
			local step = d * (1 - ov)
			for i = 1, 4 do table.insert(parts, L.part("Pommel", "Ball", { (i - 2.5) * step, 0.1 + d / 2, 0 }, L.I, { d, d, d })) end
			for i = 1, 6 do table.insert(parts, L.part("Grip", "Ball", { 0, 0.1 + d / 2 + i * step, 0 }, L.I, { d, d, d })) end
			local gy = 0.1 + d / 2 + 7 * step
			for i = 1, 8 do table.insert(parts, L.part("Guard", "Ball", { (i - 4.5) * step, gy, 0 }, L.I, { d, d, d })) end
			table.insert(parts, L.part("Blade", "Block", { 0, gy + 1.3, 0 }, L.I, { 0.16, 2.5, 0.06 }))
			for i = 1, 5 do table.insert(parts, L.part("Blade", "Ball", { 0, gy + i * step, 0 }, L.I, { d, d, d })) end
			eval(fmt("beads d %.2f overlap %.0f%%", d, 100 * ov), parts)
		end
	end
end
table.sort(results, function(a, b) return a.u > b.u end)
for k, r in ipairs(results) do
	if k <= 12 or (r.valid and k <= 40) then
		print(fmt("%-40s %10.1f units  canonical %s  valid %s %s", r.name, r.u, tostring(r.canon), tostring(r.valid), r.codes))
	end
end
