--!nocheck
-- the regular rod-bundle sword placed by hand: every rod nudged ±j and tilted ±a about a random axis (free transforms, no
-- snapping): how often is an honest design (every part visible) past the cap?
local process = require("@lune/process")
local L = require("./lib")
local TestRng = require("./repo/tests/lib/TestRng")
local serde = require("@lune/serde")
local fmt = string.format
local CAP = L.Geo.VERDICT_WORK_MAX
local seed, count = tonumber(process.args[1]) or 1, tonumber(process.args[2]) or 40
local rng = TestRng.new(seed)
local function bundle(d, ov)
	local parts = {}
	local step = d * (1 - ov)
	for i = 1, 6 do table.insert(parts, L.part("Grip", "Cylinder", { (i - 3.5) * step, 0.65, 0 }, L.Z90, { 0.9, d, d })) end
	for i = 1, 6 do table.insert(parts, L.part("Guard", "Cylinder", { 0, 1.15 + (i - 3.5) * step, 0 }, L.I, { 1.0, d, d })) end
	for i = 1, 12 do table.insert(parts, L.part("Blade", "Cylinder", { (i - 6.5) * step, 2.5, 0 }, L.Z90, { 2.6, d, d })) end
	return parts
end
for _, def in ipairs({ { 0.002, 0.25 }, { 0.005, 0.5 }, { 0.01, 1.0 }, { 0.005, 2.0 } }) do
	local j, a = def[1], def[2]
	local n, past, valid, worst, worstParts = 0, 0, 0, 0, nil
	for k = 1, count do
		local parts = bundle(rng:pick({ 0.08, 0.1, 0.12 }), rng:pick({ 0.2, 0.3, 0.4 }))
		for _, p in ipairs(parts) do
			for c = 1, 3 do p.pos[c] += rng:range(-j, j) end
			local q = L.Quat.mul(L.axisAngle(rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1), rng:range(-a, a)), p.rot)
			local r = L.Quat.hemisphere(L.Quat.normalize(q))
			p.rot = { r[1], r[2], r[3], r[4] }
		end
		L.renumber(parts)
		if L.canonical(L.copyParts(parts)) then
			local P = L.prep(parts)
			local u = L.units(P)
			local r = L.run(L.copyParts(parts), { measureInvalid = false })
			local codes = L.codes(r)
			if r.validation.ok or codes == "TooComplex" then
				local models = L.models(P)
				local honest = true
				for i = 1, #P do
					if models[i] and L.readOf(P, i, models) < 0.02 then honest = false end
				end
				if honest then
					n += 1
					if u > CAP then past += 1 end
					if u > worst then worst, worstParts = u, parts end
				end
			end
		end
	end
	print(fmt("nudged ±%.3f, tilted ±%.2f°: %d honest valid-or-TooComplex designs, %d past the cap (%.0f %%), the heaviest %.1f units",
		j, a, n, past, n > 0 and 100 * past / n or 0, worst))
	if worstParts and worst > CAP then print("HEAVIEST " .. serde.encode("json", worstParts)) end
end
