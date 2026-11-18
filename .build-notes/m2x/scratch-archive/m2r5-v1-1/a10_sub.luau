--!nocheck
-- The measure's N_SUB_WORK runs out in part order. D per fixture under the budget as built, lifted, and shared by quota; part order and an exact copy on C09 + 0.03 under each.
local V = require("./v1")
local Force = V.Force
local fmt = string.format
local Fx = V.Fx
local function longer(dl)
	local base = V.fixture("C09")
	for _, i in ipairs({ 12, 13, 14, 15, 16 }) do
		base[i].size = if i == 12 then { base[i].size[1], base[i].size[2] + dl, base[i].size[3] } else { base[i].size[1] + dl, base[i].size[2], base[i].size[3] }
		base[i].pos = { base[i].pos[1], base[i].pos[2] + dl / 2, base[i].pos[3] }
	end
	for _, i in ipairs({ 17, 18 }) do
		base[i].pos = { base[i].pos[1], base[i].pos[2] + dl, base[i].pos[3] }
	end
	return base
end
local function dOf(parts, mode)
	Force.FORCE.subMode = mode
	local R = V.emu(V.copyParts(parts))
	local sub = R.buildExposure and R.buildExposure.subSampled or 0
	Force.FORCE.subMode = nil
	return R, sub
end
print("-- D per fixture: as built | lifted | quota")
for _, list in ipairs({ Fx.calibration(), Fx.golden(), Fx.perf() }) do
	for _, b in ipairs(list) do
		local a, sa = dOf(b.parts, nil)
		local c, sc = dOf(b.parts, "lift")
		local d, sd = dOf(b.parts, "quota")
		local w1 = V.dDiff(a, c)
		local w2 = V.dDiff(a, d)
		if w1 > 0 or w2 > 0 then
			print(fmt("%-26s %s (sub %d) | %s (sub %d, |dD| %.4f) | %s (sub %d, |dD| %.4f)", string.sub(b.name, 1, 26), V.dline(a), sa, V.dline(c), sc, w1, V.dline(d), sd, w2))
		end
	end
end
print("-- C09 + 0.03: part order and a copy under each budget")
local base = longer(0.03)
for _, mode in ipairs({ false, "lift", "quota" }) do
	local m = mode or nil
	local a = dOf(base, m)
	local t = { V.dline(a) }
	for _, j in ipairs({ 13, 15, 16 }) do
		local p = V.copyParts(base)
		local q = table.remove(p, j)
		table.insert(p, 1, q)
		local r = dOf(p, m)
		table.insert(t, fmt("part %d first: %s", j, V.dline(r)))
		local c = V.copyParts(base)
		table.insert(c, 1, V.copyPart(base[j]))
		local r2 = dOf(c, m)
		table.insert(t, fmt("copy of %d first: %s", j, V.dline(r2)))
	end
	print(tostring(mode), table.concat(t, "\n    "))
end
print("-- 200 random orders of C09: the spread of D under each budget")
local seed = 777
local function rnd(n)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed % n + 1
end
for _, mode in ipairs({ false, "lift", "quota" }) do
	local m = mode or nil
	local base0 = V.fixture("C09")
	local lo, hi = { 9, 9, 9 }, { -9, -9, -9 }
	for t = 1, 200 do
		local parts = V.copyParts(base0)
		for i = #parts, 2, -1 do
			local j = rnd(i)
			parts[i], parts[j] = parts[j], parts[i]
		end
		local r = dOf(parts, m)
		for i, s in ipairs(r.steps) do
			lo[i], hi[i] = math.min(lo[i], s.d), math.max(hi[i], s.d)
		end
	end
	print(fmt("%s: Sm [%.4f, %.4f] Ha [%.4f, %.4f] Sh [%.4f, %.4f]", tostring(mode), lo[1], hi[1], lo[2], hi[2], lo[3], hi[3]))
end
