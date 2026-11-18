--!nocheck
-- V1 (m2x, round 3): a polyhedral part wholly inside a Ball, its outer face within the sag band (inside the true sphere,
-- outside the inscribed model) and pointing out. The buried piece keeps the inscribed half-spaces and the probe leaves the
-- true sphere, so the model reads the face as showing; the truth buries all of it.
local L = require("./lib")
local fmt = string.format

local S3 = 1 / math.sqrt(3)

-- a Block of size (a, t, a), its local +Y along (dx, dy, dz) (unit), its outer face at distance r − e from the ball's centre
local function plate(c, r, e, a, t, dx, dy, dz, slot)
	local rot
	if dy > 0.999999 then
		rot = L.I
	else
		local ax, az = dz, -dx -- (0, 1, 0) × d
		local ang = math.deg(math.acos(dy))
		rot = L.axisAngle(ax, 0, az, ang)
	end
	local k = r - e - t / 2
	return L.part(slot or "Blade", "Block", { c[1] + k * dx, c[2] + k * dy, c[3] + k * dz }, rot, { a, t, a })
end

local function run(r, e, a, t, dir)
	local c = { 0, 0.4, 0 }
	local parts = {
		L.part("Pommel", "Ball", c, L.I, { 2 * r, 2 * r, 2 * r }),
		plate(c, r, e, a, t, dir[1], dir[2], dir[3]),
	}
	L.renumber(parts)
	local P = L.prep(parts)
	local models = L.models(P)
	local share = L.readOf(P, 2, models)
	local _, _, hider = L.Oracle.flags(P)
	local truth = L.Oracle.share(P, 2, hider)
	-- the plate's corners inside the true ball?
	local worst = -math.huge
	for i = 1, #P[2].wverts, 3 do
		local v = P[2].wverts
		worst = math.max(worst, L.Shapes.sd(P[1], v[i], v[i + 1], v[i + 2]))
	end
	return share, truth, worst
end

for _, r in ipairs({ 0.3, 0.25, 0.2, 0.15 }) do
	for _, e in ipairs({ 0.002, 0.005, 0.008, 0.011 }) do
		for _, t in ipairs({ 0.02, 0.1 }) do
			local a = 0.1 * r / 0.3
			local s, tr, w = run(r, e, a, t, { S3, S3, S3 })
			print(fmt("r %.2f e %.3f plate %.3f x %.2f x %.3f: model %.3f%% (%s), truth %.3f%%, deepest corner sd %.4f",
				r, e, a, t, a, 100 * s, if s >= 0.02 then "kept" else "cleaned", 100 * tr, w))
		end
	end
end
