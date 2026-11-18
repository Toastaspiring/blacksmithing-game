--!nocheck
-- V1 round 2's hand-built designs, by name: { name, parts }, each a whole sword unless it says so.
local L = require("./lib")
local fmt = string.format
local I, Z90 = L.I, L.Z90
local sin, cos, rad, pi = math.sin, math.cos, math.rad, math.pi

local D = {}

local function hilt(gx, gz)
	return {
		L.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		L.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, Z90, { 0.90, 0.16, 0.16 }),
		L.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { gx or 1.10, 0.16, gz or 0.30 }),
	}
end
D.hilt = hilt

-- ── a round bar behind slats ─────────────────────────────────────────────────────────────────────────────────────
local function slat(slot, cy, r, angDeg, halfArcDeg, len, t, gap)
	local a = rad(angDeg)
	local nx, nz = cos(a), sin(a)
	local W = (r + 0.012) * sin(rad(halfArcDeg))
	local d = r + t / 2 + (gap or 1e-4)
	local q = L.axisAngle(0, 1, 0, -angDeg + 90)
	return L.part("Slat", "Block", slot, { d * nx, cy, d * nz }, q, { 2 * W, len, t })
end
local SLOTS = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Grip", "Grip", "Grip", "Grip", "Grip" }

-- mode 8: covers centred at 33.5 + 45k; 16: centred at 22.5k; others: n covers at offset roll, half arc
function D.slatted(r, len, mode, roll, half)
	local parts = hilt(1.10, math.min(0.6, 2 * r + 0.1))
	local y = 1.40 + len / 2
	table.insert(parts, L.part("Rod", "Cylinder", "Blade", { 0, y, 0 }, Z90, { len, 2 * r, 2 * r }))
	table.insert(parts, L.part("Cap", "Block", "Pommel", { 0, y + len / 2 + 0.02, 0 }, I, { 2 * r + 0.1, 0.04, math.min(0.6, 2 * r + 0.1) }))
	local n = 0
	local function add(ang, h)
		n += 1
		table.insert(parts, slat(SLOTS[n], y, r, ang, h, len - 0.04, 0.02))
	end
	if mode == 8 then
		for k = 0, 7 do add(33.5 + 45 * k, 17.3) end
	elseif mode == 16 then
		for k = 0, 7 do
			add(45 * k, 6.1)
			add(22.5 + 45 * k, 6.6)
		end
	else
		for k = 0, mode - 1 do add((roll or 0) + k * 360 / mode, half) end
	end
	return parts
end

-- ── a Ball behind k blocks ───────────────────────────────────────────────────────────────────────────────────────
function D.caged(r, y, k)
	local c = 0.19 * (r + 0.012)
	local parts = hilt()
	table.insert(parts, L.part("Ball", "Ball", "Blade", { 0, y, 0 }, I, { 2 * r, 2 * r, 2 * r }))
	local s = r + 0.02
	local function add(x0, x1, y0, y1, z0, z1)
		table.insert(parts, L.part("Box", "Block", "Blade", { (x0 + x1) / 2, y + (y0 + y1) / 2, (z0 + z1) / 2 }, I, { x1 - x0, y1 - y0, z1 - z0 }))
	end
	local function iv(sg, a, b) return math.min(sg * a, sg * b), math.max(sg * a, sg * b) end
	if k == 2 then
		add(-s, s, c, s, -s, s)
		add(-s, s, -s, -c, -s, s)
	elseif k == 4 then
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local x0, x1 = iv(sx, c, s)
				local z0, z1 = iv(sz, c, s)
				add(x0, x1, -s, s, z0, z1)
			end
		end
	else
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local x0, x1 = iv(sx, c, s)
					local y0, y1 = iv(sy, c, s)
					local z0, z1 = iv(sz, c, s)
					add(x0, x1, y0, y1, z0, z1)
				end
			end
		end
	end
	return parts
end

-- ── a flat core on a stage ───────────────────────────────────────────────────────────────────────────────────────
local Geo = require("./repo/src/shared/Definitions/Balance").Geometry
function D.gridOf(sx, sy, sz)
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
local gridOf = D.gridOf

local STAGE_SLOTS = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Pommel", "Pommel", "Pommel", "Pommel", "Grip" }
local cursor = 0
local function nextSlot()
	cursor += 1
	return STAGE_SLOTS[cursor]
end

function D.stage(sx, sy, sz, cy)
	cursor = 0
	local parts = {}
	table.insert(parts, L.part("Grip", "Cylinder", "Grip", { 0, 0.6, 0 }, Z90, { 0.9, 0.16, 0.16 }))
	local b = 0.06
	table.insert(parts, L.part("Back", "Block", nextSlot(), { 0, cy, -sz / 2 - b / 2 }, I, { sx + 2 * b, sy + 2 * b, b }))
	table.insert(parts, L.part("Bar", "Block", nextSlot(), { sx / 2 + b / 2, cy, 0 }, I, { b, sy + 2 * b, sz + 2 * b }))
	table.insert(parts, L.part("Bar", "Block", nextSlot(), { -sx / 2 - b / 2, cy, 0 }, I, { b, sy + 2 * b, sz + 2 * b }))
	table.insert(parts, L.part("Bar", "Block", nextSlot(), { 0, cy + sy / 2 + b / 2, 0 }, I, { sx, b, sz + 2 * b }))
	table.insert(parts, L.part("Bar", "Block", nextSlot(), { 0, cy - sy / 2 - b / 2, 0 }, I, { sx, b, sz + 2 * b }))
	table.insert(parts, L.part("Tang", "Block", "Grip", { 0, (1.0 + cy - sy / 2) / 2, 0 }, I, { 0.1, cy - sy / 2 - 1.0 + 0.02, 0.1 }))
	return parts
end
local stage = D.stage

function D.coreOf(sx, sy, sz, cy)
	return L.part("Core", "Block", "Blade", { 0, cy, 0 }, I, { sx, sy, sz })
end
local coreOf = D.coreOf

function D.windows(sx, sy, sz)
	local h, a, b = gridOf(sx, sy, sz)
	local cy = 2.2
	local parts = stage(sx, sy, sz, cy)
	table.insert(parts, coreOf(sx, sy, sz, cy))
	local eps = 1e-5
	local zc = sz / 2 + 0.03
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
	return parts
end

function D.tiles(parts, sx, sy, sz, cy, xs, ys, hair)
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
local tiles = D.tiles

-- K (stage + tiles), K + the core
function D.crossing(sx, sy, sz, nx, ny, hair)
	local h, a, b = gridOf(sx, sy, sz)
	local cy = 2.2
	local pw, ph = sx / a, sy / b
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

-- 4 hairlines on the rows of one patch row, across the face: the 2 patches at the bars read whole
function D.rows(sx, sy, sz, hair)
	local h, a, b = gridOf(sx, sy, sz)
	local cy = 2.2
	local ph = sy / b
	local K = stage(sx, sy, sz, cy)
	local cj = -sy / 2 + 0.5 * ph
	local ys = {}
	for _, s in ipairs({ -0.75, -0.25, 0.25, 0.75 }) do table.insert(ys, cj + s * ph / 2) end
	tiles(K, sx, sy, sz, cy, {}, ys, hair)
	local KF = L.copyParts(K)
	table.insert(KF, coreOf(sx, sy, sz, cy))
	return K, KF
end
-- the same on the columns: the design turned 90 degrees
function D.columns(sx, sy, sz, hair)
	local h, a, b = gridOf(sx, sy, sz)
	local cy = 2.2
	local pw = sx / a
	local K = stage(sx, sy, sz, cy)
	local ci = -sx / 2 + 0.5 * pw
	local xs = {}
	for _, s in ipairs({ -0.75, -0.25, 0.25, 0.75 }) do table.insert(xs, ci + s * pw / 2) end
	tiles(K, sx, sy, sz, cy, xs, {}, hair)
	local KF = L.copyParts(K)
	table.insert(KF, coreOf(sx, sy, sz, cy))
	return K, KF
end

-- ── a closed box with a block in the cavity ──────────────────────────────────────────────────────────────────────
function D.box(w, len, th, wall)
	local parts = hilt(w + 2 * wall + 0.1, math.min(0.6, th + 2 * wall + 0.1))
	local y = 1.48 + wall + len / 2
	table.insert(parts, L.part("Wall", "Block", "Blade", { w / 2 + wall / 2, y, 0 }, I, { wall, len, th + 2 * wall }))
	table.insert(parts, L.part("Wall", "Block", "Blade", { -w / 2 - wall / 2, y, 0 }, I, { wall, len, th + 2 * wall }))
	table.insert(parts, L.part("Wall", "Block", "Blade", { 0, y, th / 2 + wall / 2 }, I, { w, len, wall }))
	table.insert(parts, L.part("Wall", "Block", "Blade", { 0, y, -th / 2 - wall / 2 }, I, { w, len, wall }))
	table.insert(parts, L.part("Wall", "Block", "Blade", { 0, y + len / 2 + wall / 2, 0 }, I, { w + 2 * wall, wall, th + 2 * wall }))
	table.insert(parts, L.part("Wall", "Block", "Blade", { 0, y - len / 2 - wall / 2, 0 }, I, { w + 2 * wall, wall, th + 2 * wall }))
	return parts, y
end

-- ── a rod in a polygon of flats ──────────────────────────────────────────────────────────────────────────────────
function D.polygonTube(n, r, len, hair, roll)
	local parts = hilt(2 * r + 0.3, math.min(0.6, 2 * r + 0.2))
	local y = 1.48 + len / 2
	local a = (r + 0.012) * cos(pi / n) - 1e-5
	if a < r then return nil end
	local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Grip", "Grip" }
	for k = 0, n - 1 do
		local ang = (k + 0.5) * 360 / n + (roll or 0)
		local c, s = cos(rad(ang)), sin(rad(ang))
		local inner = a * math.tan(pi / n)
		local q = L.axisAngle(0, 1, 0, -ang + 90)
		table.insert(parts, L.part("Flat", "Block", slots[k + 1], { (a + 0.02) * c, y, (a + 0.02) * s }, q, { 2 * inner - hair, len, 0.04 }))
	end
	table.insert(parts, L.part("Cap", "Block", "Pommel", { 0, y + len / 2 + 0.02, 0 }, I, { 2 * a + 0.2, 0.04, math.min(0.6, 2 * a + 0.2) }))
	return parts, y
end

-- ── a laminate's core under sheets ───────────────────────────────────────────────────────────────────────────────
function D.laminate(gap, n, t)
	local w, len, ch = 1.1, 2.0, 0.06
	local y = 1.45 + len / 2
	local K = hilt()
	table.insert(K, L.part("Cheek", "Block", "Blade", { 0, y, gap / 2 + ch / 2 }, I, { w, len, ch }))
	table.insert(K, L.part("Cheek", "Block", "Blade", { 0, y, -(gap / 2 + ch / 2) }, I, { w, len, ch }))
	table.insert(K, L.part("Top", "Block", "Blade", { 0, 1.45 + len + 0.02, 0 }, I, { w, 0.04, gap + 2 * ch }))
	table.insert(K, L.part("Core", "Block", "Blade", { 0, y, 0 }, I, { 0.95, len, gap }))
	local F = {}
	local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Grip", "Grip" }
	for k = 1, n do
		local z = -gap / 2 + t / 2 + (k - 1) * (gap - t) / math.max(1, n - 1)
		table.insert(F, L.part("Sheet", "Block", slots[k], { 0, y, z }, I, { 0.95 + 2 * 0.016, len, t }))
	end
	return K, F
end

-- every hand-built design, for order, digest and mutant runs
function D.all()
	local out = {}
	local function add(name, parts)
		if parts then table.insert(out, { name = name, parts = L.renumber(L.copyParts(parts)) }) end
	end
	for _, r in ipairs({ 0.08, 0.15, 0.25 }) do
		add(fmt("slats8 r%.2f", r), D.slatted(r, 3.0, 8))
		add(fmt("slats16 r%.2f", r), D.slatted(r, 3.0, 16))
	end
	for _, k in ipairs({ 2, 4, 8 }) do add(fmt("cage%d", k), D.caged(0.28, 1.76, k)) end
	add("windows", D.windows(1.2, 1.2, 0.02))
	for _, c in ipairs({ { 1.2, 1.2, 0.02, 2, 2 }, { 1.2, 2.0, 0.02, 2, 3 }, { 1.2, 1.2, 0.4, 3, 3 } }) do
		local K, KF = D.crossing(c[1], c[2], c[3], c[4], c[5], 1e-5)
		add(fmt("cross %.1f %.1f %.2f K", c[1], c[2], c[3]), K)
		add(fmt("cross %.1f %.1f %.2f KF", c[1], c[2], c[3]), KF)
	end
	do
		local _, r = D.rows(1.2, 1.2, 0.02, 1e-5)
		add("rows", r)
		local _, c = D.columns(1.2, 1.2, 0.02, 1e-5)
		add("columns", c)
	end
	do
		local K, y = D.box(0.6, 3.0, 0.2, 0.02)
		add("box", K)
		local KF = L.copyParts(K)
		table.insert(KF, L.part("Fill", "Block", "Guard", { 0, y, 0 }, I, { 0.54, 2.94, 0.14 }))
		table.insert(KF, L.part("Strut", "Block", "Guard", { 0, y - 1.5 + 0.015, 0 }, I, { 0.1, 0.032, 0.02 }))
		add("box+fill", KF)
	end
	do
		local K, y = D.polygonTube(8, 0.10, 3.0, 1e-5, 0)
		add("octagon", K)
		local KF = L.copyParts(K)
		table.insert(KF, L.part("Rod", "Cylinder", "Blade", { 0, y, 0 }, Z90, { 3.0, 0.2, 0.2 }))
		add("octagon+rod", KF)
	end
	do
		local K, F = D.laminate(0.10, 10, 0.02)
		add("laminate", K)
		local KF = L.copyParts(K)
		for _, f in ipairs(F) do table.insert(KF, L.copyPart(f)) end
		add("laminate+sheets", KF)
	end
	return out
end

return D
