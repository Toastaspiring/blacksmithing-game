--!nocheck
-- V2: the crossing and the lattice on swords of ordinary proportions, and the shape of the reading on them. args: none
local V = require("./v1")
local T = V.T
local fmt = string.format
local I = V.I
local Geo = require("./repo/src/shared/Definitions/Balance").Geometry

local function hilt(guardW)
	return {
		V.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		V.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, V.Z90, { 0.90, 0.16, 0.16 }),
		V.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { guardW, 0.16, 0.30 }),
	}
end

local function gridOf(w, l, t)
	local P = V.Shapes.prepare(V.part("C", "Block", "Blade", { 0, 2.5, 0 }, I, { w, l, t }), 1)
	local h = V.Sampling.ladder(Geo.H_SURF, function(s)
		local a, b, c = math.ceil(w / s), math.ceil(l / s), math.ceil(t / s)
		return 2 * (a * b + b * c + a * c) <= Geo.VERDICT_SAMPLES
	end)
	return math.ceil(w / h), math.ceil(l / h), h
end

local function lines(w, n)
	local out = {}
	local hw = w / n / 2
	for k = 0, n - 1 do
		local c = (2 * k + 1) * hw
		for _, f in ipairs({ -0.75, -0.25, 0.25, 0.75 }) do
			table.insert(out, c + f * hw)
		end
	end
	return out
end

local function slotCycle()
	local left = { Blade = 12, Guard = 8, Grip = 6, Pommel = 4 }
	return function(parts)
		local count = { Blade = 0, Guard = 0, Grip = 0, Pommel = 0 }
		for _, p in ipairs(parts) do
			count[p.slot] += 1
		end
		for _, s in ipairs({ "Blade", "Guard", "Grip", "Pommel" }) do
			if count[s] < left[s] then
				return s
			end
		end
		error("no slot")
	end
end

-- a blade: core between cheeks, walled at its rims. The front cheek in tiles, slits on a line of each family.
local function bladeTiles(W, L, t, c, xs, ys, e, withCore, frontSolid)
	local y = 1.45 + L / 2
	local parts = hilt(math.max(W + 0.1, 0.5))
	local slot = slotCycle()
	local z = t / 2 + c / 2
	if withCore then
		table.insert(parts, V.part("Core", "Block", "Guard", { 0, y, 0 }, I, { W, L, t }))
	end
	table.insert(parts, V.part("Back", "Block", "Blade", { 0, y, -z }, I, { W, L, c }))
	table.insert(parts, V.part("Tip", "Block", "Blade", { 0, y + L / 2 + 0.02, 0 }, I, { W + 0.08, 0.04, t + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { W / 2 + 0.02, y, 0 }, I, { 0.04, L, t + 2 * c }))
	table.insert(parts, V.part("Side", "Block", "Blade", { -W / 2 - 0.02, y, 0 }, I, { 0.04, L, t + 2 * c }))
	local cx = { -W / 2 }
	for _, x in ipairs(xs) do
		table.insert(cx, x - W / 2 - e)
		table.insert(cx, x - W / 2 + e)
	end
	table.insert(cx, W / 2)
	local cy = { y - L / 2 }
	for _, yy in ipairs(ys) do
		table.insert(cy, yy - L / 2 + y - e)
		table.insert(cy, yy - L / 2 + y + e)
	end
	table.insert(cy, y + L / 2)
	for i = 1, #cx, 2 do
		for j = 1, #cy, 2 do
			local x0, x1, y0, y1 = cx[i], cx[i + 1], cy[j], cy[j + 1]
			table.insert(parts, V.part("Tile", "Block", slot(parts), { (x0 + x1) / 2, (y0 + y1) / 2, z }, I, { x1 - x0, y1 - y0, c }))
		end
	end
	return parts
end

local function show(name, parts, noCore)
	V.renumber(parts)
	local ok, full = V.valid(V.copyParts(parts))
	local real, read = V.reads(parts)
	local shares = T.all(parts, 0.0005)
	local row = {}
	local idx
	for i, p in ipairs(parts) do
		row[i] = shares[i] ~= false and shares[i] >= 0.02
		if p.label == "Core" then idx = i end
	end
	local Rv, Rt = V.emu(V.copyParts(parts)), V.emu(V.copyParts(parts), row)
	local w, tier = V.dDiff(Rv, Rt)
	print(fmt("%s: %d parts valid=%s | core true %.3f %% read %.3f %% %s | against truth's verdict |dD| %.4f%s", name, #parts, tostring(ok), shares[idx] * 100, read[idx] * 100, if real.kept[idx] then "kept" else "CLEANED", w, if tier then " TIER" else ""))
	print("   build " .. V.dline(Rv))
	print("   truth " .. V.dline(Rt))
	if noCore then
		V.renumber(noCore)
		local Ra = V.emu(V.copyParts(noCore))
		local w2, t2 = V.dDiff(Ra, Rv)
		print(fmt("   K alone %s, K + F against K |dD| %.4f%s", V.dline(Ra), w2, if t2 then " TIER" else ""))
	end
	if not ok then
		for _, e in ipairs(full.validation.errors) do print("   error", e.code, e.partId, e.slot) end
	end
end

for _, def in ipairs({ { 0.3, 2.6, 0.02, 0.03 }, { 0.3, 2.6, 0.02, 0.05 }, { 0.2, 2.5, 0.02, 0.03 }, { 0.5, 2.5, 0.02, 0.03 }, { 1.0, 2.0, 0.02, 0.05 }, { 0.16, 2.6, 0.02, 0.03 } }) do
	local W, L, t, c = def[1], def[2], def[3], def[4]
	local na, nb, h = gridOf(W, L, t)
	print(fmt("--- blade %.2f x %.2f, core %.2f, cheeks %.2f: spacing %.3f, %d x %d patches", W, L, t, c, h, na, nb))
	local lx, ly = lines(W, na), lines(L, nb)
	local P = V.Shapes.prepare(V.part("C", "Block", "Blade", { 0, 2.5, 0 }, I, { W, L, t }), 1)
	local perCrossing = 0.25 * (W / na) * (L / nb) / P.area
	local need = math.ceil(0.02 / perCrossing)
	local ys = {}
	for k = 1, need do
		table.insert(ys, ly[2 + 4 * (k - 1)])
	end
	local xs = { lx[2] }
	local e = 0.000005
	show(fmt("  %d crossings", need), bladeTiles(W, L, t, c, xs, ys, e, true), bladeTiles(W, L, t, c, xs, ys, e, false))
end
