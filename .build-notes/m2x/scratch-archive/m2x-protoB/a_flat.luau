--!nocheck
-- Flat patches: windows between the lines, hairlines along them, and the early return when family A agrees.
local L = require("./lib")
local T = L.T
local fmt = string.format
local I, Z90 = L.I, L.Z90
T.SPACING, T.MAX_LINES, T.BALL_POINTS = 0.0005, 4000, 200000

local SLOTS = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Pommel", "Pommel", "Pommel", "Pommel", "Grip" }

local function relabel(parts)
	-- the core (label Core) in the Blade, one small grip, the rest wherever fits
	local n = { Blade = 0, Guard = 0, Grip = 0, Pommel = 0 }
	local MAX = { Blade = 12, Guard = 8, Grip = 6, Pommel = 4 }
	for _, p in ipairs(parts) do
		if p.slot == "Blade" or p.slot == "Grip" or p.slot == "Guard" or p.slot == "Pommel" then
			n[p.slot] += 1
		end
	end
	return parts
end

local function report(name, parts, labels)
	local w, tier, step, Rv, Rt, shares, read, real = L.vsTruth(parts)
	local t = {}
	for i, p in ipairs(parts) do
		for _, l in ipairs(labels) do
			if p.label == l then
				table.insert(t, fmt("%s#%d(%s) true %.3f%% read %.3f%% %s", l, i, p.shape, (shares[i] or 0) * 100, (read[i] or 0) * 100, if real.kept[i] then "kept" else "CLEANED"))
			end
		end
	end
	print(fmt("%s [%d parts, %s]\n   %s\n   build %s\n   truth %s\n   |dD| %.4f %s%s", name, #parts, L.ok(parts), table.concat(t, "; "), L.dline(Rv), L.dline(Rt), w, step, if tier then " TIER FLIP" else ""))
	return Rv, Rt
end

-- A grid: the core's verdict spacing and its patches, from the build's own numbers
local function gridOf(sx, sy, sz)
	local Geo = require("./repo/src/shared/Definitions/Balance").Geometry
	local h
	for _, f in ipairs(Geo.H_LADDER) do
		h = Geo.H_SURF * f
		local a, b, c = math.ceil(sx / h), math.ceil(sy / h), math.ceil(sz / h)
		if 2 * (a * b + b * c + a * c) <= Geo.VERDICT_SAMPLES then
			return h, a, b, c
		end
	end
	return h, math.ceil(sx / h), math.ceil(sy / h), math.ceil(sz / h)
end

local slotCursor
local function nextSlot()
	slotCursor += 1
	return SLOTS[slotCursor]
end

-- the stage: a grip below, the core in a blade's place, a back cheek, 4 rim bars; lids on +Z are added by the attack
local function stage(sx, sy, sz, cy, void)
	slotCursor = 0
	local parts = {}
	table.insert(parts, L.part("Grip", "Cylinder", "Grip", { 0, 0.6, 0 }, Z90, { 0.9, 0.16, 0.16 }))
	local b = 0.06
	local zmid = 0
	table.insert(parts, L.part("Back", "Block", nextSlot(), { 0, cy, -sz / 2 - b / 2 }, I, { sx + 2 * b, sy + 2 * b, b }))
	table.insert(parts, L.part("Bar", "Block", nextSlot(), { sx / 2 + b / 2, cy, 0 }, I, { b, sy + 2 * b, sz + 2 * b }))
	table.insert(parts, L.part("Bar", "Block", nextSlot(), { -sx / 2 - b / 2, cy, 0 }, I, { b, sy + 2 * b, sz + 2 * b }))
	table.insert(parts, L.part("Bar", "Block", nextSlot(), { 0, cy + sy / 2 + b / 2, 0 }, I, { sx, b, sz + 2 * b }))
	table.insert(parts, L.part("Bar", "Block", nextSlot(), { 0, cy - sy / 2 - b / 2, 0 }, I, { sx, b, sz + 2 * b }))
	-- connect the grip to the blade
	table.insert(parts, L.part("Tang", "Block", "Grip", { 0, (1.0 + cy - sy / 2) / 2, 0 }, I, { 0.1, cy - sy / 2 - 1.0 + 0.02, 0.1 }))
	return parts
end

local function coreOf(sx, sy, sz, cy)
	return L.part("Core", "Block", "Blade", { 0, cy, 0 }, I, { sx, sy, sz })
end

-- 1. Windows: strips over the lines of each patch, both ways
do
	local sx, sy, sz = 1.2, 1.2, 0.02
	local h, a, b = gridOf(sx, sy, sz)
	local cy = 2.2
	local parts = stage(sx, sy, sz, cy)
	table.insert(parts, coreOf(sx, sy, sz, cy))
	local eps = 1e-5
	local zc = sz / 2 + 0.03
	-- vertical strips, across x
	local pw, ph = sx / a, sy / b
	for i = 0, a - 1 do
		local c = -sx / 2 + (i + 0.5) * pw
		for _, s in ipairs({ -1, 1 }) do
			local x0, x1 = c + s * 0.25 * pw / 2, c + s * 0.75 * pw / 2
			if x0 > x1 then x0, x1 = x1, x0 end
			table.insert(parts, L.part("Strip", "Block", nextSlot(), { (x0 + x1) / 2, cy, zc }, I, { x1 - x0 + 2 * eps, sy, 0.06 }))
		end
	end
	for j = 0, b - 1 do
		local c = -sy / 2 + (j + 0.5) * ph
		for _, s in ipairs({ -1, 1 }) do
			local y0, y1 = c + s * 0.25 * ph / 2, c + s * 0.75 * ph / 2
			if y0 > y1 then y0, y1 = y1, y0 end
			table.insert(parts, L.part("Strip", "Block", nextSlot(), { 0, cy + (y0 + y1) / 2, zc }, I, { sx, y1 - y0 + 2 * eps, 0.06 }))
		end
	end
	report(fmt("windows: core %.1f x %.1f x %.2f, grid %d x %d, %d strips", sx, sy, sz, a, b, 2 * (a + b)), parts, { "Core" })
end

-- A lid set on +Z from cut positions: tiles between the x cuts and y cuts
local function tiles(parts, sx, sy, sz, cy, xs, ys, hair)
	local X = { -sx / 2 }
	for _, x in ipairs(xs) do table.insert(X, x) end
	table.insert(X, sx / 2)
	local Y = { -sy / 2 }
	for _, y in ipairs(ys) do table.insert(Y, y) end
	table.insert(Y, sy / 2)
	local zc = sz / 2 + 0.03
	for i = 1, #X - 1 do
		for j = 1, #Y - 1 do
			local x0, x1 = X[i] + (if i > 1 then hair / 2 else 0), X[i + 1] - (if i < #X - 1 then hair / 2 else 0)
			local y0, y1 = Y[j] + (if j > 1 then hair / 2 else 0), Y[j + 1] - (if j < #Y - 1 then hair / 2 else 0)
			table.insert(parts, L.part("Tile", "Block", nextSlot(), { (x0 + x1) / 2, cy + (y0 + y1) / 2, zc }, I, { x1 - x0, y1 - y0, 0.06 }))
		end
	end
end

-- 2. Hairlines crossing on lines, a thin core and a fat one
local function crossing(sx, sy, sz, nx, ny, hair)
	local h, a, b = gridOf(sx, sy, sz)
	local cy = 2.2
	local pw, ph = sx / a, sy / b
	-- cuts: on the line +0.25 of successive patches
	local xs, ys = {}, {}
	for i = 1, nx do
		local c = -sx / 2 + (i - 0.5 + (a - nx) // 2) * pw
		table.insert(xs, c + 0.25 * pw / 2)
	end
	for j = 1, ny do
		local c = -sy / 2 + (j - 0.5 + (b - ny) // 2) * ph
		table.insert(ys, c + 0.25 * ph / 2)
	end
	local K = stage(sx, sy, sz, cy)
	tiles(K, sx, sy, sz, cy, xs, ys, hair)
	local KF = L.copyParts(K)
	table.insert(KF, coreOf(sx, sy, sz, cy))
	return K, KF, a, b
end
for _, c in ipairs({ { 1.2, 1.2, 0.02, 2, 2 }, { 1.2, 1.2, 0.02, 2, 3 }, { 1.2, 2.0, 0.02, 2, 3 }, { 1.2, 1.2, 0.2, 2, 2 }, { 1.2, 1.2, 0.4, 3, 2 }, { 1.2, 1.2, 0.4, 3, 3 } }) do
	local K, KF, a, b = crossing(c[1], c[2], c[3], c[4], c[5], 1e-5)
	local Rv, Rt = report(fmt("hair crossings: core %.1f x %.1f x %.2f, grid %d x %d, %d x %d = %d crossings", c[1], c[2], c[3], a, b, c[4], c[5], c[4] * c[5]), KF, { "Core" })
	local RK = L.emu(L.copyParts(K))
	local w, tier, step = L.dDiff(RK, Rv)
	print(fmt("   K alone %s | K + core: |dD| %.4f %s%s", L.dline(RK), w, step, if tier then " TIER FLIP" else ""))
end

-- 3. Family A agrees on a fraction and returns at once: hairlines on the 4 rows of one patch and a needle across them
local function needle(sx, sy, sz, rows)
	local h, a, b = gridOf(sx, sy, sz)
	local cy = 2.2
	local pw, ph = sx / a, sy / b
	local K = stage(sx, sy, sz, cy)
	return K, a, b, pw, ph, cy
end
do
	local sx, sy, sz, hair = 1.2, 1.2, 0.02, 1e-5
	local K, a, b, pw, ph, cy = needle(sx, sy, sz)
	-- which family runs along x? Block's +Z face: addRectangle(-hx, -hy, hz, 2hx, 0, 0, 0, 2hy, 0): e1 along x, e2 along y. A: lines along e1, at offsets in e2: rows of constant y
	local cj = -sy / 2 + (1 - 0.5) * ph -- the patch row j = 1 (bottom), column: all
	local ys = {}
	for _, s in ipairs({ -0.75, -0.25, 0.25, 0.75 }) do table.insert(ys, cj + s * ph / 2) end
	tiles(K, sx, sy, sz, cy, {}, ys, hair)
	local cx = -sx / 2 + (1 - 0.5) * pw -- the first column's patch
	-- the needle: between the columns +0.25 and +0.75 of that patch, across all 4 rows, on the lids' level, thin in x
	local nx0 = cx + 0.5 * pw / 2
	local same = L.copyParts(K)
	table.insert(K, L.part("Needle", "Block", "Pommel", { nx0, cy + cj, sz / 2 + 0.03 }, I, { 0.02, ph * 0.95, 0.06 }))
	local KF = L.copyParts(K)
	table.insert(KF, coreOf(sx, sy, sz, cy))
	report("rows: 4 hairlines on one patch's rows + a needle crossing them", KF, { "Core" })
	local noNeedle = L.copyParts(same)
	table.insert(noNeedle, coreOf(sx, sy, sz, cy))
	report("rows: the same without the needle", noNeedle, { "Core" })
	-- the same turned: hairlines on the columns (family B), a needle across them
	local K2 = stage(sx, sy, sz, cy)
	local cols = {}
	for _, s in ipairs({ -0.75, -0.25, 0.25, 0.75 }) do table.insert(cols, cx + s * pw / 2) end
	tiles(K2, sx, sy, sz, cy, cols, {}, hair)
	table.insert(K2, L.part("Needle", "Block", "Pommel", { cx, cy + cj + 0.5 * ph / 2, sz / 2 + 0.03 }, I, { pw * 0.95, 0.02, 0.06 }))
	table.insert(K2, coreOf(sx, sy, sz, cy))
	report("columns: the same design turned 90 degrees", K2, { "Core" })
end
