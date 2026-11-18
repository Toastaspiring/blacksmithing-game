--!nocheck
-- Hand-built attacks on the reading rules, each against the truth. Printed: true share and reading of the named part, verdict, validity, D by the build's verdict and by the truth's.
local L = require("./lib")
local T = L.T
local fmt = string.format
local I, Z90 = L.I, L.Z90
local sqrt, sin, cos, rad = math.sqrt, math.sin, math.cos, math.rad
T.SPACING, T.MAX_LINES, T.BALL_POINTS = 0.001, 3200, 200000

local function hilt()
	return {
		L.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		L.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, Z90, { 0.90, 0.16, 0.16 }),
		L.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { 1.10, 0.16, 0.30 }),
	}
end

local function report(name, parts, labels)
	local w, tier, step, Rv, Rt, shares, read, real = L.vsTruth(parts)
	local t = {}
	for i, p in ipairs(parts) do
		for _, l in ipairs(labels) do
			if p.label == l then
				table.insert(t, fmt("%s#%d(%s) true %.2f%% read %.2f%% %s", l, i, p.shape, (shares[i] or 0) * 100, (read[i] or 0) * 100, if real.kept[i] then "kept" else "CLEANED"))
			end
		end
	end
	print(fmt("%s [%d parts, %s]\n   %s\n   build %s\n   truth %s\n   |dD| %.4f %s%s", name, #parts, L.ok(parts), table.concat(t, "; "), L.dline(Rv), L.dline(Rt), w, step, if tier then " TIER FLIP" else ""))
end

-- ── a Cylinder behind slats ───────────────────────────────────────────────────────────────────────────────────────
-- A rod along world Y (local X); slats stand tangent at the local directions, hiding arcs by their probes. Test angles per patch at nth = 8: 0, ±5.6, ±16.4, ±21.05.
local function slat(label, slot, cx, cy, cz, r, angDeg, halfArcDeg, L0, t)
	-- tangent plate at world direction angle in XZ: local Y of rod = ?, computed below
	local a = rad(angDeg)
	local nx, nz = cos(a), sin(a)
	local W = (r + 0.012) * sin(rad(halfArcDeg)) -- half-width that hides that arc by the probe
	local d = r + t / 2 + 1e-4 -- centre distance: the inner face 1e-4 off the rod
	-- a block of size W*2 (along the tangent) x L0 x t, turned about Y so its thickness points along (nx, nz)
	local q = L.axisAngle(0, 1, 0, -angDeg + 90) -- local Z toward (nx, nz)
	return L.part(label, "Block", slot, { cx + d * nx, cy, cz + d * nz }, q, { 2 * W, L0, t })
end

local function rodSword(r, len, nslats, halfArcs, slatThick)
	-- hilt + a round bar blade, its ends in the guard and under a cap
	local parts = hilt()
	local y = 1.40 + len / 2
	-- local Y, Z of the rod under Z90: u = world Y, v = world -X, w = world Z. Directions k * 45 deg in local (Y, Z) are world angles in (X, Z) off -X: multiples of 45 stay multiples of 45.
	table.insert(parts, L.part("Rod", "Cylinder", "Blade", { 0, y, 0 }, Z90, { len, 2 * r, 2 * r }))
	table.insert(parts, L.part("Cap", "Block", "Pommel", { 0, y + len / 2 + 0.02, 0 }, I, { 2 * r + 0.1, 0.04, math.min(0.6, 2 * r + 0.1) }))
	return parts, y
end

local function ribbed(r, len, mode)
	local parts, y = rodSword(r, len)
	local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Grip", "Grip" }
	local n = 0
	local function add(ang, half)
		n += 1
		table.insert(parts, slat("Slat", slots[n], 0, y, 0, r, ang, half, len - 0.04, 0.02))
	end
	if mode == 8 then
		-- one cover per 45°: from 16.4 to 45 + 5.6, centred at 33.5: open arcs (5.6, 16.4)
		for k = 0, 7 do add(33.5 + 45 * k, 17.3) end
	else
		-- two per 45°: over the centre and over the seam: open (5.6, 16.4), (28.6, 39.4)
		for k = 0, 7 do
			add(45 * k, 6.1)
			add(22.5 + 45 * k, 6.6)
		end
	end
	return parts
end

for _, r in ipairs({ 0.08, 0.15, 0.25 }) do
	report(fmt("rod r %.2f, 8 slats at 33.5 + 45k", r), ribbed(r, 3.0, 8), { "Rod" })
	report(fmt("rod r %.2f, 16 slats at 22.5k", r), ribbed(r, 3.0, 16), { "Rod" })
end

-- the same, wide enough a guard so the rod's foot is buried: the biggest bar
do
	for _, r in ipairs({ 0.25, 0.29 }) do
		local parts = ribbed(r, 3.0, 8)
		parts[3].size = { 1.10, 0.16, 0.60 }
		report(fmt("rod r %.2f, wide guard, 8 slats", r), parts, { "Rod" })
		local p16 = ribbed(r, 3.0, 16)
		p16[3].size = { 1.10, 0.16, 0.60 }
		report(fmt("rod r %.2f, wide guard, 16 slats", r), p16, { "Rod" })
	end
end

-- ── a Ball: its samples avoid 3 bands |n_i| < 0.196 ────────────────────────────────────────────────────────────
local function ballCage(r, y, k)
	-- k = 2: 2 plates; 4: quadrants about Y; 8: octants. A block per region, its corner at c = 0.2 (r + delta) off each open plane
	local c = 0.19 * (r + 0.012)
	local parts = hilt()
	-- a real blade above, the ball on the guard's top as a boss
	table.insert(parts, L.part("Ball", "Ball", "Blade", { 0, y, 0 }, I, { 2 * r, 2 * r, 2 * r }))
	local s = r + 0.02 -- the blocks' outer reach
	local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade" }
	local n = 0
	local function add(x0, x1, y0, y1, z0, z1)
		n += 1
		table.insert(parts, L.part("Box", "Block", slots[n], { (x0 + x1) / 2, y + (y0 + y1) / 2, (z0 + z1) / 2 }, I, { x1 - x0, y1 - y0, z1 - z0 }))
	end
	if k == 2 then
		add(-s, s, c, s, -s, s)
		add(-s, s, -s, -c, -s, s)
	elseif k == 4 then
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				add(math.min(sx * c, sx * s), math.max(sx * c, sx * s), -s, s, math.min(sz * c, sz * s), math.max(sz * c, sz * s))
			end
		end
	else
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					add(math.min(sx * c, sx * s), math.max(sx * c, sx * s), math.min(sy * c, sy * s), math.max(sy * c, sy * s), math.min(sz * c, sz * s), math.max(sz * c, sz * s))
				end
			end
		end
	end
	return parts
end
for _, k in ipairs({ 2, 4, 8 }) do
	report(fmt("ball d 0.56 at the blade's root, %d blocks", k), ballCage(0.28, 1.76, k), { "Ball" })
end
