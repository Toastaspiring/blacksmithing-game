--!nocheck
-- V1's a1_d.luau on the build: a rod whose axis ties (two 45° snaps, u = (0.707, 0.5, 0.5)) in the Guard of F5 or F3, and a
-- copy spun about its own axis in the Guard or the Blade; truly hidden, the copy read on the model, D against the truth's row
local L = require("./lab")
local E = require("./emulab")
local Quat = L.Quat
local fmt = string.format
local function axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.hemisphere(Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
end
local q = Quat.hemisphere(Quat.normalize(Quat.mul(axisAngle(1, 0, 0, 45), axisAngle(0, 0, 1, 45))))
local function part(slot, pos, rot)
	return { id = 0, slot = slot, shape = "Cylinder", material = "Iron", pos = pos, rot = rot, size = { 0.5, 0.08, 0.08 } }
end
local function design(spin, slot, which)
	local parts = {}
	for i, p in ipairs(L.Blueprints.core(which).parts) do parts[i] = p end
	local gy = which == "F5" and 1.29 or 1.24
	table.insert(parts, part("Guard", { 0, gy, 0 }, q))
	if spin then
		table.insert(parts, part(slot, { 0, gy, 0 }, Quat.hemisphere(Quat.normalize(Quat.mul(q, axisAngle(1, 0, 0, spin))))))
	end
	for i, p in ipairs(parts) do p.id = i end
	return parts
end
for _, which in ipairs({ "F5", "F3" }) do
	print(which .. " + the rod: " .. E.dline(E.run(design(nil, nil, which))))
	local worst = { 0 }
	local rows, readMax = 0, 0
	for spin = 5, 355, 10 do
		for _, slot in ipairs({ "Guard", "Blade" }) do
			local parts = design(spin, slot, which)
			local P = L.prepared(parts)
			local e = L.Sampling.exposure(P)
			local n = #parts
			local _, _, hider = L.Oracle.flags(P)
			local t1, t2 = L.Oracle.share(P, n - 1, hider), L.Oracle.share(P, n, hider)
			readMax = math.max(readMax, math.min((L.H.reads(P, n - 1)), (L.H.reads(P, n))))
			local row = table.clone(e.kept)
			row[n - 1], row[n] = t1 >= 0.02, t2 >= 0.02
			if row[n - 1] ~= e.kept[n - 1] or row[n] ~= e.kept[n] then
				rows += 1
				local Rb, Rt = E.run(parts), E.run(parts, row)
				local d, t, s = E.diff(Rb, Rt)
				if d > worst[1] then worst = { d, spin, slot, s, t, E.dline(Rb), E.dline(Rt) } end
			end
		end
	end
	print(fmt("%s: %d of 72 designs keep a truly hidden copy; the lower reading up to %.2f%%; worst |dD| %.4f (spin %s, copy in %s, %s, tier flip %s)", which, rows, 100 * readMax, worst[1], tostring(worst[2]), tostring(worst[3]), tostring(worst[4]), tostring(worst[5])))
	if worst[6] then print("   build " .. worst[6] .. " | truth row " .. worst[7]) end
end
