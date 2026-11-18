--!nocheck
-- A tried fix for the ids: the verdict and the measure visit parts in an order of their geometry, not their ids. D per fixture against the table, and C09 under any order.
local V = require("./v1")
local fmt = string.format
local Fx = V.Fx
local function key(p)
	return { p.pos[2], p.pos[1], p.pos[3], p.size[1], p.size[2], p.size[3], p.rot[1], p.rot[2], p.rot[3], p.rot[4], #p.shape }
end
local function geo(parts)
	local out = V.copyParts(parts)
	table.sort(out, function(a, b)
		local ka, kb = key(a), key(b)
		for i = 1, #ka do
			if ka[i] ~= kb[i] then return ka[i] < kb[i] end
		end
		return false
	end)
	return out
end
print("-- D as built | in geometric order, where they differ")
for _, list in ipairs({ Fx.calibration(), Fx.golden(), Fx.perf() }) do
	for _, b in ipairs(list) do
		local a = V.emu(V.copyParts(b.parts))
		local c = V.emu(geo(b.parts))
		local w, tier = V.dDiff(a, c)
		if w > 0 then
			print(fmt("%-30s %s | %s | |dD| %.4f%s", string.sub(b.name, 1, 30), V.dline(a), V.dline(c), w, if tier then " TIER" else ""))
		end
	end
end
local seed = 4242
local function rnd(n)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed % n + 1
end
local base = V.fixture("C09")
local first
local spread = 0
for t = 1, 100 do
	local parts = V.copyParts(base)
	for i = #parts, 2, -1 do
		local j = rnd(i)
		parts[i], parts[j] = parts[j], parts[i]
	end
	local R = V.emu(geo(parts))
	if not first then first = R end
	spread = math.max(spread, (V.dDiff(first, R)))
end
print(fmt("C09, 100 orders, geometric: %s, spread %.6f", V.dline(first), spread))
local KF = V.copyParts(base)
table.insert(KF, 1, V.copyPart(base[15]))
print(fmt("C09 + a copy of part 15 first, geometric: %s", V.dline(V.emu(geo(KF)))))
