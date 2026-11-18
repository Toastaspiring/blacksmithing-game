--!nocheck
-- V1 (m2x, round 3): more of the sag band. (a) a small Ball wholly inside a big Ball, its outer side within the big one's
-- band along (1, 1, 1); (b) a Cylinder likewise; (c) a long Block plate inside a Cylinder, its outer face within the
-- 32-gon's band; (d) a Ball under a thin plate that cuts its true surface but not its model (round part, flat hider).
local L = require("./lib")
local fmt = string.format

local S3 = 1 / math.sqrt(3)

local function row(name, parts, i)
	L.renumber(parts)
	local P = L.prep(parts)
	local models = L.models(P)
	local share = L.readOf(P, i, models)
	local _, _, hider = L.Oracle.flags(P)
	local truth = L.Oracle.share(P, i, hider)
	print(fmt("%-58s build %7.3f%% (%s)  truth %7.3f%% (%s)%s", name, 100 * share, if share >= 0.02 then "kept" else "cleaned",
		100 * truth, if truth >= 0.02 then "kept" else "cleaned",
		if (share >= 0.02) ~= (truth >= 0.02) then "  <-- differs" else ""))
end

local function rotTo(d)
	local ax, az = d[3], -d[1]
	if math.abs(ax) + math.abs(az) < 1e-12 then
		return L.I
	end
	return L.axisAngle(ax, 0, az, math.deg(math.acos(d[2])))
end

local C = { 0, 0.5, 0 }
local R = 0.3
-- (a) a Ball r inside the big Ball, centre at distance R − e − r along (1, 1, 1)
for _, r in ipairs({ 0.04, 0.06, 0.1 }) do
	for _, e in ipairs({ 0.002, 0.006, 0.010 }) do
		local k = R - e - r
		local parts = {
			L.part("Pommel", "Ball", C, L.I, { 2 * R, 2 * R, 2 * R }),
			L.part("Blade", "Ball", { C[1] + k * S3, C[2] + k * S3, C[3] + k * S3 }, L.I, { 2 * r, 2 * r, 2 * r }),
		}
		row(fmt("(a) Ball r %.2f inside Ball 0.3, depth %.3f", r, e), parts, 2)
	end
end
-- (b) a Cylinder (axis across (1,1,1)) inside the big Ball near its surface
for _, e in ipairs({ 0.002, 0.006, 0.010 }) do
	local r, hx = 0.04, 0.05
	local k = R - e - r
	local parts = {
		L.part("Pommel", "Ball", C, L.I, { 2 * R, 2 * R, 2 * R }),
		L.part("Blade", "Cylinder", { C[1] + k * S3, C[2] + k * S3, C[3] + k * S3 }, L.axisAngle(1, 0, -1, 90),
			{ 2 * hx, 2 * r, 2 * r }),
	}
	row(fmt("(b) Cylinder r 0.04 inside Ball 0.3, depth %.3f", e), parts, 2)
end
-- (c) a Block plate inside a Cylinder along X (r 0.3, length 3), its outer face at r − e, facing the side facet k = 2's
-- direction (between 32-gon vertices 2 and 3 of the circle that starts from world Y)
for _, r in ipairs({ 0.3, 0.15 }) do
	for _, e in ipairs({ 0.0003, 0.0006, 0.001 }) do
		if e < 0.0048 * r then
			-- the cylinder's frame: axis X, circle from world Y (the axis most across X is Y): direction of facet 1's centre
			-- is at angle π/32 from Y toward Z
			local a = math.pi / 32
			local d = { 0, math.cos(a), math.sin(a) }
			local w = 2 * math.sqrt(math.max(0, (r - 1e-4) ^ 2 - (r - e) ^ 2)) * 0.95
			local t = 0.03
			local k = r - e - t / 2
			local rot = L.axisAngle(1, 0, 0, math.deg(a))
			local parts = {
				L.part("Grip", "Cylinder", { 0, 1, 0 }, L.I, { 3, 2 * r, 2 * r }),
				L.part("Blade", "Block", { 0, 1 + k * d[2], k * d[3] }, rot, { 2.8, t, math.max(w, 0.02) }),
			}
			row(fmt("(c) plate %.3f wide in Cylinder r %.2f, depth %.4f", w, r, e), parts, 2)
		end
	end
end
-- (d) Ball r 0.3 under a plate 0.02 thick whose lower face is at R − s along (1,1,1)
for _, s in ipairs({ 0.008, 0.011, 0.014, 0.016 }) do
	local d = { S3, S3, S3 }
	local k = R - s + 0.01
	local parts = {
		L.part("Blade", "Ball", C, L.I, { 2 * R, 2 * R, 2 * R }),
		L.part("Guard", "Block", { C[1] + k * d[1], C[2] + k * d[2], C[3] + k * d[3] }, rotTo(d), { 0.3, 0.02, 0.3 }),
	}
	L.renumber(parts)
	local P = L.prep(parts)
	local models = L.models(P)
	local share = L.readOf(P, 1, models)
	local _, _, hider = L.Oracle.flags(P)
	local truth = L.Oracle.measure(P, 1, hider, 400000)
	print(fmt("(d) Ball 0.3 under a plate cutting %.3f deep: build hides %.3f%%, truth hides %.3f%%%s", s,
		100 * (1 - share), 100 * (1 - truth), if (1 - share) < (1 - truth) then "  <-- build under" else ""))
end
