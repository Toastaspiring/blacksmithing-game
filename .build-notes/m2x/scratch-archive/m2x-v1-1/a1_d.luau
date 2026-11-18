--!nocheck
-- A1's effect on D: a Cylinder at an orientation whose two smallest axis components tie (two 45° snaps: u = (0.707, 0.5,
-- 0.5)), and a copy of it spun about its own axis: coincident with it, truly hidden (0 %), read up to ~40 % and kept.
local L = require("./lib")
local Quat = L.Quat
local fmt = string.format
local q45z = L.axisAngle(0, 0, 1, 45)
local q45x = L.axisAngle(1, 0, 0, 45)
local q = Quat.hemisphere(Quat.normalize(Quat.mul(q45x, q45z)))
local P0 = L.Shapes.prepare(L.part("Guard", "Cylinder", { 0, 1.29, 0 }, q, { 0.5, 0.08, 0.08 }), 1)
print(fmt("rod axis u = (%.17g, %.17g, %.17g)", P0.ux, P0.uy, P0.uz))
local function design(spin, slot, which)
	local parts = L.repoFixture(which)
	local gy = which == "F5" and 1.29 or 1.24
	table.insert(parts, L.part("Guard", "Cylinder", { 0, gy, 0 }, q, { 0.5, 0.08, 0.08 }))
	if spin then
		local spun = Quat.hemisphere(Quat.normalize(Quat.mul(q, L.axisAngle(1, 0, 0, spin))))
		table.insert(parts, L.part(slot, "Cylinder", { 0, gy, 0 }, spun, { 0.5, 0.08, 0.08 }))
	end
	return L.renumber(parts)
end
for _, which in ipairs({ "F5", "F3" }) do
	local R0 = L.emu(design(nil, nil, which))
	print(which .. " + the rod: " .. L.dline(R0))
	local worst = { 0 }
	local rows = 0
	for spin = 5, 355, 10 do
		for _, slot in ipairs({ "Guard", "Blade" }) do
			local parts = design(spin, slot, which)
			local P = L.prep(parts)
			local e = L.Sampling.exposure(P)
			local n = #parts
			local truth = L.truthAll(P, { [n - 1] = true, [n] = true })
			local row = table.clone(e.kept)
			row[n - 1] = truth[n - 1] >= 0.02
			row[n] = truth[n] >= 0.02
			local differs = row[n - 1] ~= e.kept[n - 1] or row[n] ~= e.kept[n]
			if differs then
				rows += 1
				local Rb = L.emu(L.copyParts(parts))
				local Rt = L.emu(L.copyParts(parts), row)
				local d, t, s = L.dDiff(Rb, Rt)
				if d > worst[1] then
					worst = { d, spin, slot, s, t, L.dline(Rb), L.dline(Rt), L.readOf(P, n - 1), L.readOf(P, n), truth[n - 1], truth[n] }
				end
			end
		end
	end
	print(fmt("%s: %d of 72 designs keep a truly hidden copy; worst |dD| %.4f (spin %s, copy in %s, step %s, tier flip %s)", which, rows, worst[1], tostring(worst[2]), tostring(worst[3]), tostring(worst[4]), tostring(worst[5])))
	if worst[6] then
		print("   build " .. worst[6] .. " | truth row " .. worst[7])
		print(fmt("   reads rod %.2f%% copy %.2f%%; truth rod %.2f%% copy %.2f%%", 100 * worst[8], 100 * worst[9], 100 * worst[10], 100 * worst[11]))
	end
end
