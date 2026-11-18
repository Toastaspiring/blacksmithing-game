--!nocheck
-- regular rod-bundle swords (every part visible): their units against the cap
local L = require("./lib")
local fmt = string.format
local CAP = L.Geo.VERDICT_WORK_MAX
local function report(name, parts)
	L.renumber(parts)
	local okc = L.canonical(L.copyParts(parts))
	local P = L.prep(parts)
	local u = L.units(P)
	local r = L.run(L.copyParts(parts), { measureInvalid = false })
	local models = L.models(P)
	local hidden, lowest = 0, 1
	for i = 1, #P do
		if models[i] then
			local s = L.readOf(P, i, models)
			lowest = math.min(lowest, s)
			if s < 0.02 then hidden += 1 end
		end
	end
	print(fmt("%-66s %10.1f units %s  canonical %s, %s %s; parts reading under 2 %%: %d (lowest %.1f%%)", name, u, u > CAP and "PAST" or fmt("(%.2f× under)", CAP / u), tostring(okc),
		r.validation.ok and "valid" or "invalid", L.codes(r), hidden, 100 * lowest))
	return u
end
local function bundle(d, ov, opts)
	opts = opts or {}
	local parts = {}
	local step = d * (1 - ov)
	for i = 1, 6 do
		local rot = L.Z90
		if opts.twist then rot = L.Quat.hemisphere(L.Quat.normalize(L.Quat.mul(L.axisAngle(0, 1, 0, opts.twist * (i - 3.5)), L.Z90))) end
		table.insert(parts, L.part("Grip", "Cylinder", { (i - 3.5) * step, 0.65, 0 }, rot, { 0.9, d, d }))
	end
	for i = 1, (opts.guard or 6) do
		local rot = L.I
		if opts.guardTilt then rot = L.axisAngle(0, 0, 1, opts.guardTilt * (i - 3.5)) end
		table.insert(parts, L.part("Guard", "Cylinder", { 0, 1.15 + (i - 3.5) * step, 0 }, rot, { 1.0, d, d }))
	end
	for i = 1, (opts.blade or 12) do
		local rot = L.Z90
		local x = (i - ((opts.blade or 12) + 1) / 2) * step
		if opts.fan then rot = L.Quat.hemisphere(L.Quat.normalize(L.Quat.mul(L.axisAngle(0, 0, 1, -opts.fan * (i - 6.5)), L.Z90))) end
		table.insert(parts, L.part("Blade", "Cylinder", { x, 2.5, 0 }, rot, { 2.6, d, d }))
	end
	return parts
end
report("rod bundle d 0.12, 40 % overlap (grip 6, guard 6, blade 12)", bundle(0.12, 0.4))
report("rod bundle d 0.10, 20 % overlap", bundle(0.10, 0.2))
for _, f in ipairs({ 0.5, 1, 2, 3 }) do
	report(fmt("rod bundle d 0.12, 40 %% overlap, blade rods fanned %.1f° apart", f), bundle(0.12, 0.4, { fan = f }))
end
for _, t in ipairs({ 2, 5, 10 }) do
	report(fmt("rod bundle d 0.12, 40 %% overlap, grip rods twisted %d° apart", t), bundle(0.12, 0.4, { twist = t }))
end
for _, t in ipairs({ 1, 3 }) do
	report(fmt("rod bundle d 0.12, 40 %% overlap, guard rods tilted %d° apart", t), bundle(0.12, 0.4, { guardTilt = t }))
end
report("rod bundle d 0.10, 20 % overlap, blade fanned 1°", bundle(0.10, 0.2, { fan = 1 }))
report("rod bundle d 0.10, 20 % overlap, guard tilted 2°", bundle(0.10, 0.2, { guardTilt = 2 }))
