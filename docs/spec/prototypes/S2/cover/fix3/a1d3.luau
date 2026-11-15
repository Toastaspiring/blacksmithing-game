--!nocheck
-- m2x-fix-3: fix/a1d.luau (V1's a1_d) on a tree: a rod whose axis ties (two 45° snaps) in the Guard of F5 or F3 and a copy
-- spun about its own axis in the Guard or the Blade; the parts the verdict keeps that the truth hides, D against the truth's row
--   lune run a1d3 -- <base | now>
local Lab = require("./lab")
local process = require("@lune/process")
local L = Lab.tree(process.args[1] or "now")
local Quat = L.Quat
local fmt = string.format
local q = Quat.hemisphere(Quat.normalize(Quat.mul(L.axisAngle(1, 0, 0, 45), L.axisAngle(0, 0, 1, 45))))
local function part(slot, pos, rot)
	return { id = 0, slot = slot, shape = "Cylinder", material = "Iron", pos = pos, rot = rot, size = { 0.5, 0.08, 0.08 } }
end
local function design(spin, slot, which)
	local parts = L.repoFixture(which)
	local gy = which == "F5" and 1.29 or 1.24
	table.insert(parts, part("Guard", { 0, gy, 0 }, q))
	if spin then
		table.insert(parts, part(slot, { 0, gy, 0 }, Quat.hemisphere(Quat.normalize(Quat.mul(q, L.axisAngle(1, 0, 0, spin))))))
	end
	return L.renumber(parts)
end
for _, which in ipairs({ "F5", "F3" }) do
	print(which .. " + the rod: " .. L.dline(L.emu(design(nil, nil, which))))
	local worst = { 0 }
	local rows, readMax = 0, 0
	for spin = 5, 355, 10 do
		for _, slot in ipairs({ "Guard", "Blade" }) do
			local parts = design(spin, slot, which)
			local P = L.prep(parts)
			local e = L.Sampling.exposure(P)
			local n = #parts
			local _, _, hider = L.Oracle.flags(P)
			local t1, t2 = L.Oracle.share(P, n - 1, hider), L.Oracle.share(P, n, hider)
			local models = L.models(P)
			readMax = math.max(readMax, math.min((L.readOf(P, n - 1, models)), (L.readOf(P, n, models))))
			local row = table.clone(e.kept)
			row[n - 1], row[n] = t1 >= 0.02, t2 >= 0.02
			if row[n - 1] ~= e.kept[n - 1] or row[n] ~= e.kept[n] then
				rows += 1
				local Rb, Rt = L.emu(L.copyParts(parts)), L.emu(L.copyParts(parts), row)
				local d, t, s = L.dDiff(Rb, Rt)
				if d > worst[1] then
					worst = { d, spin, slot, s, t, L.dline(Rb), L.dline(Rt) }
				end
			end
		end
	end
	print(fmt("%s: %d of 72 designs keep a truly hidden copy; the lower reading up to %.2f%%; worst |dD| %.4f%s", which, rows, 100 * readMax, worst[1],
		if worst[2] then fmt(" (spin %d, copy in %s, %s, tier flip %s)\n   build %s | truth row %s", worst[2], worst[3], worst[4], tostring(worst[5]), worst[6], worst[7]) else ""))
end
