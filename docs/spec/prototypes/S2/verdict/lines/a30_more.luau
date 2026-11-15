--!nocheck
-- More attacks than the verifiers listed, to try the reading wider. Run in the base folder and in each alt folder.
local V = require("./v1")
local fmt = string.format
local I = V.I
local T = V.T
local S45 = 0.70710678118654757

local function row(name, K, KF)
	local Ra, Rb = V.emu(V.copyParts(K)), V.emu(V.copyParts(KF))
	local w, tier = V.dDiff(Ra, Rb)
	print(fmt("%-52s |dD| %.4f%s   K %s | K+ %s", name, w, if tier then " TIER" else "     ", V.dline(Ra), V.dline(Rb)))
end
local function hilt()
	return {
		V.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		V.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, V.Z90, { 0.90, 0.16, 0.16 }),
		V.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { 1.10, 0.16, 0.30 }),
	}
end
local function showCore(name, parts, i)
	local real, read = V.reads(parts)
	local S = T.solids(parts)
	local hider = T.hidersOf(S)
	local s = T.share(S, i, hider, 0.0005)
	print(fmt("%-52s core true %.3f %%, read %.3f %%, %s", name, s * 100, read[i] * 100, if real.kept[i] then "kept" else "cleaned"))
	return real, read, s
end

-- 1 exact copies in another slot, either id order
do
	for _, def in ipairs({ { "F3", 6, "Guard" }, { "C08", 4, "Guard" }, { "F5", 4, "Pommel" } }) do
		local base = V.fixture(def[1])
		local c1 = V.copyParts(base)
		local copy = V.copyPart(base[def[2]])
		copy.slot = def[3]
		table.insert(c1, copy)
		row(def[1] .. ": exact copy of the blade in " .. def[3] .. ", after", base, c1)
		local c2 = V.copyParts(base)
		table.insert(c2, 1, V.copyPart(copy))
		row(def[1] .. ": exact copy of the blade in " .. def[3] .. ", first", base, c2)
		local c3 = V.copyParts(base)
		local steel = V.copyPart(base[def[2]])
		steel.material = "Steel"
		table.insert(c3, 1, steel)
		row(def[1] .. ": exact Steel copy, same slot, first", base, c3)
		-- the label alone
		local l = V.copyParts(base)
		l[def[2]].slot = def[3]
		row(def[1] .. ": the blade labelled " .. def[3], base, l)
	end
end

-- 2 hairline slits on a Cylinder filler buried in a split solid
do
	local y, L, W, D = 2.45, 2.0, 1.0, 0.14
	for _, g in ipairs({ 0.00001, 0.001 }) do
		local K = hilt()
		local sw = (W - g) / 2
		table.insert(K, V.part("Half", "Block", "Blade", { g / 2 + sw / 2, y, 0 }, I, { sw, L, D }))
		table.insert(K, V.part("Half", "Block", "Blade", { -g / 2 - sw / 2, y, 0 }, I, { sw, L, D }))
		local KF = V.copyParts(K)
		for _, slot in ipairs({ "Blade", "Guard" }) do
			local F = V.copyParts(K)
			table.insert(F, V.part("Rod", "Cylinder", slot, { 0, y, 0 }, V.Z90, { L - 0.02, 0.1, 0.1 }))
			showCore(fmt("rod in a split solid, slit %.5f, %s", g, slot), F, #F)
			row(fmt("rod in a split solid, slit %.5f, %s", g, slot), K, F)
		end
		-- a turned rod, so that the slit runs through a direction
		local Q = V.Quat.hemisphere(V.Quat.normalize(V.Quat.mul(V.Z90, V.axisAngle(1, 0, 0, 22.5))))
		local F = V.copyParts(K)
		table.insert(F, V.part("Rod", "Cylinder", "Blade", { 0, y, 0 }, Q, { L - 0.02, 0.1, 0.1 }))
		showCore(fmt("rod spun 22.5, slit %.5f", g), F, #F)
	end
end

-- 3 a groove shorter than a patch: what a partial slit reads
do
	local y, L = 2.45, 2.0
	local function fuller(gx, gw, gy0, gy1)
		local parts = hilt()
		local c, k = 0.03, 0.02
		table.insert(parts, V.part("Core", "Block", "Blade", { 0, y, 0 }, I, { 1.0, L, k }))
		local z = k / 2 + c / 2
		local bot, top = y - L / 2, y + L / 2
		local x0, x1 = gx - gw / 2, gx + gw / 2
		for s = -1, 1, 2 do
			table.insert(parts, V.part("L", "Block", "Blade", { (-0.5 + x0) / 2, y, s * z }, I, { x0 + 0.5, L, c }))
			table.insert(parts, V.part("R", "Block", "Blade", { (0.5 + x1) / 2, y, s * z }, I, { 0.5 - x1, L, c }))
			if gy0 > bot then
				table.insert(parts, V.part("Lo", "Block", "Blade", { gx, (bot + gy0) / 2, s * z }, I, { gw, gy0 - bot, c }))
			end
			if gy1 < top then
				table.insert(parts, V.part("Hi", "Block", "Blade", { gx, (gy1 + top) / 2, s * z }, I, { gw, top - gy1, c }))
			end
		end
		table.insert(parts, V.part("Tip", "Block", "Blade", { 0, top + 0.02, 0 }, I, { 1.08, 0.04, k + 2 * c }))
		table.insert(parts, V.part("Side", "Block", "Blade", { 0.52, y, 0 }, I, { 0.04, L, k + 2 * c }))
		table.insert(parts, V.part("Side", "Block", "Blade", { -0.52, y, 0 }, I, { 0.04, L, k + 2 * c }))
		return parts
	end
	for _, def in ipairs({ { 0.05, 0.03, 1.5, 3.4 }, { 0.05, 0.05, 1.8, 3.1 }, { 0.09, 0.03, 2.0, 2.9 }, { 0.09, 0.05, 2.2, 2.7 }, { 0.2, 0.03, 2.3, 2.6 }, { 0.15, 0.06, 2.0, 2.2 } }) do
		local p = fuller(def[1], def[2], def[3], def[4])
		showCore(fmt("a groove %.2f at x %.2f, y %.1f to %.1f", def[2], def[1], def[3], def[4]), p, 4)
	end
end

-- 4 a lattice: windows in every patch
do
	local y, L, W = 2.45, 2.0, 1.0
	local function lattice(nx, ny, rib, off)
		local parts = hilt()
		local k, c = 0.02, 0.03
		table.insert(parts, V.part("Core", "Block", "Blade", { 0, y, 0 }, I, { W, L, k }))
		local z = k / 2 + c / 2
		-- one face whole, the other a lattice of ribs
		table.insert(parts, V.part("Back", "Block", "Blade", { 0, y, -z }, I, { W, L, c }))
		for i = 0, nx do
			local x = -W / 2 + W * i / nx + off
			if math.abs(x) + rib / 2 <= W / 2 + 1e-9 then
				table.insert(parts, V.part("RibX", "Block", "Blade", { x, y, z }, I, { rib, L, c }))
			end
		end
		for j = 0, ny do
			local yy = y - L / 2 + L * j / ny + off
			if math.abs(yy - y) + rib / 2 <= L / 2 + 1e-9 then
				table.insert(parts, V.part("RibY", "Block", "Blade", { 0, yy, z }, I, { W, rib, c }))
			end
		end
		table.insert(parts, V.part("Tip", "Block", "Blade", { 0, y + L / 2 + 0.02, 0 }, I, { W + 0.08, 0.04, k + 2 * c }))
		table.insert(parts, V.part("Side", "Block", "Blade", { W / 2 + 0.02, y, 0 }, I, { 0.04, L, k + 2 * c }))
		table.insert(parts, V.part("Side", "Block", "Blade", { -W / 2 - 0.02, y, 0 }, I, { 0.04, L, k + 2 * c }))
		return parts
	end
	for _, def in ipairs({ { 3, 5, 0.25, 0 }, { 3, 5, 0.27, 0 }, { 6, 10, 0.1, 0 }, { 6, 10, 0.12, 0 }, { 3, 5, 0.3, 0.02 }, { 6, 5, 0.12, 0.01 } }) do
		local p = lattice(def[1], def[2], def[3], def[4])
		if #p <= 24 then
			showCore(fmt("lattice %d x %d rib %.2f off %.2f (%d parts)", def[1], def[2], def[3], def[4], #p), p, 4)
		end
	end
end

-- 5 skin on a Wedge and a Cylinder: flush parts inside, with lower ids
do
	local base = V.fixture("C09")
	for _, i in ipairs({ 12, 13, 3, 7 }) do
		local h = base[i]
		local plates = {}
		if h.shape ~= "Cylinder" then
			local t = math.min(0.02, h.size[3] / 3)
			plates = { V.part("Skin", h.shape, "Guard", h.pos, h.rot, { h.size[1], h.size[2], h.size[3] }) }
			plates[1].size = { h.size[1] * 0.999, h.size[2], h.size[3] }
		else
			plates = { V.part("Skin", "Cylinder", "Guard", h.pos, h.rot, { h.size[1] * 0.5, h.size[2], h.size[3] }) }
		end
		local KF = V.copyParts(plates)
		for _, p in ipairs(base) do
			table.insert(KF, V.copyPart(p))
		end
		row(fmt("C09: a flush near copy of part %d (%s) first", i, h.shape), base, KF)
	end
end
