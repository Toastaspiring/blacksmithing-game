--!nocheck
-- False kept on round parts: a rod and a ball hidden in a real void, behind a slit that passes through their samples. K + F against K.
local L = require("./lib")
local T = L.T
local fmt = string.format
local I, Z90 = L.I, L.Z90
T.SPACING, T.MAX_LINES, T.BALL_POINTS = 0.0005, 4000, 300000

local function hilt(gz)
	return {
		L.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		L.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, Z90, { 0.90, 0.16, 0.16 }),
		L.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { 1.10, 0.16, gz or 0.30 }),
	}
end

local function compare(name, K, F, labels)
	local KF = L.copyParts(K)
	for _, f in ipairs(F) do table.insert(KF, L.copyPart(f)) end
	local w, tier, step, Rv, Rt, shares, read, real = L.vsTruth(KF)
	local t = {}
	for i, p in ipairs(KF) do
		for _, l in ipairs(labels) do
			if p.label == l then
				table.insert(t, fmt("%s#%d(%s) true %.3f%% read %.3f%% %s", l, i, p.shape, (shares[i] or 0) * 100, (read[i] or 0) * 100, if real.kept[i] then "kept" else "CLEANED"))
			end
		end
	end
	local RK = L.emu(L.copyParts(K))
	local wk, tk, sk = L.dDiff(RK, Rv)
	print(fmt("%s [%d parts, %s]\n   %s\n   K alone %s\n   K + F   %s\n   |dD| %.4f %s%s  (truth's verdict on K + F: %s)", name, #KF, L.ok(KF), table.concat(t, "; "), L.dline(RK), L.dline(Rv), wk, sk, if tk then " TIER FLIP" else "", L.dline(Rt)))
end

-- A square tube round a void: 4 walls, a cap on top, the guard below. One wall split at x = 0 by a hair.
local function tube(side, len, wall, hair, faces)
	local parts = hilt(side + 2 * wall)
	local y = 1.48 + len / 2
	local half = side / 2
	local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade" }
	local n = 0
	local function add(label, pos, size)
		n += 1
		table.insert(parts, L.part(label, "Block", slots[n], pos, I, size))
	end
	add("WallX", { half + wall / 2, y, 0 }, { wall, len, side + 2 * wall })
	add("WallX", { -half - wall / 2, y, 0 }, { wall, len, side + 2 * wall })
	-- +Z wall, split at x = 0 if faces >= 1; -Z wall, split if faces >= 2
	for s = 1, -1, -2 do
		local split = (s == 1 and faces >= 1) or (s == -1 and faces >= 2)
		if split then
			local w = (side - hair) / 2
			add("WallZ", { (w + hair) / 2, y, s * (half + wall / 2) }, { w, len, wall })
			add("WallZ", { -(w + hair) / 2, y, s * (half + wall / 2) }, { w, len, wall })
		else
			add("WallZ", { 0, y, s * (half + wall / 2) }, { side, len, wall })
		end
	end
	add("Cap", { 0, y + len / 2 + 0.02, 0 }, { side + 2 * wall, 0.04, side + 2 * wall })
	return parts, y
end

for _, c in ipairs({ { 0.16, 3.0, 1 }, { 0.30, 3.0, 1 }, { 0.50, 3.0, 1 }, { 0.50, 2.0, 2 }, { 0.50, 3.0, 2 } }) do
	local side, len, faces = c[1], c[2], c[3]
	local K, y = tube(side, len, 0.04, 1e-5, faces)
	-- the rod just fits: its surface touches the walls, its ends in the guard and under the cap
	local rod = L.part("Rod", "Cylinder", "Blade", { 0, y, 0 }, Z90, { len, side, side })
	compare(fmt("rod d %.2f x %.1f in a square tube, %d wall(s) split by 1e-5 at the rod's direction", side, len, faces), K, { rod }, { "Rod" })
end

-- A Ball: its samples on the plane z = 0.25 x (b = 0.25 on faces +-x), turned so the plane is z = 0 in the world; slit in the +Z wall? Samples on a slit plane through the centre:
-- the slit lies in the wall at x = 0: the plane x = 0 in the world. Turn the ball about Y by atan(0.25) so that samples (1, a, 0.25)/norm come to the plane containing world Y and Z? They lie on z = 0.25 x, a plane through
-- local Y. Turning about local Y by atan(0.25) brings it to z' = 0. For a slit at x = 0 use a further 90 degrees.
do
	local side = 0.56
	local len = 0.60
	local K, y = tube(side, len, 0.02, 1e-5, 2)
	local ang = math.deg(math.atan(0.25))
	for _, q in ipairs({ { 0, L.I }, { 90 + ang, L.axisAngle(0, 1, 0, 90 + ang) }, { 90 - ang, L.axisAngle(0, 1, 0, 90 - ang) } }) do
		local ball = L.part("Ball", "Ball", "Blade", { 0, y, 0 }, q[2], { side, side, side })
		compare(fmt("ball d %.2f in a box, 2 walls split at x = 0, turned %.2f about Y", side, q[1]), K, { ball }, { "Ball" })
	end
end
