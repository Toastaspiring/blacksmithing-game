--!nocheck
-- round fillers sealed by flat walls just under HIDE_OFFSET: a rod in a k-gon tube whose corners stand δ − ε off it, turned
-- by any angle about the rod (and the rod along X, Y, Z or tilted), end plates δ − ε off its caps; a Ball in the 26 plates
-- of a rhombicuboctahedron. Truly hidden; the build's reading and verdict.
local L = require("./lib")
local TestRng = require("./repo/tests/lib/TestRng")
local Quat = L.Quat
local fmt = string.format
local rng = TestRng.new(7)
local D = 0.012
local worst, n, kept = { 0 }, 0, 0
local function frameFrom(u)
	-- a rotation taking local X to u
	local ax, ay, az = 0, -u[3], u[2] -- (1,0,0) × u
	local s = math.sqrt(ay * ay + az * az)
	if s < 1e-12 then return if u[1] > 0 then { 0, 0, 0, 1 } else { 0, 0, 1, 0 } end
	local ang = math.acos(math.max(-1, math.min(1, u[1])))
	return Quat.hemisphere(Quat.normalize({ 0, ay / s * math.sin(ang / 2), az / s * math.sin(ang / 2), math.cos(ang / 2) }))
end
for t = 1, 120 do
	local r = rng:pick({ 0.05, 0.1, 0.2, 0.3 })
	local hx = rng:range(0.2, 1.0)
	local k = rng:pick({ 8, 12, 16, 24 })
	local eps = rng:pick({ 1e-4, 1e-5, 1e-6, 2e-7 })
	local turn = rng:range(0, 360)
	local u = rng:pick({ { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } })
	if rng:float() < 0.4 then
		u = { rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1) }
		local l = math.sqrt(u[1] ^ 2 + u[2] ^ 2 + u[3] ^ 2)
		u = { u[1] / l, u[2] / l, u[3] / l }
	end
	local q = frameFrom(u)
	local c = { 0, 2.5, 0 }
	local parts = { L.part("Blade", "Cylinder", c, q, { 2 * hx, 2 * r, 2 * r }) }
	local R = (r + D - eps) * math.cos(math.pi / k) -- the walls' inner faces: corners at r + D − eps
	local side = 2 * (r + D) * math.tan(math.pi / k) + 0.03
	for j = 1, k do
		local a = math.rad(turn) + 2 * math.pi * j / k
		local ly, lz = math.cos(a), math.sin(a)
		local local_ = { 0, (R + 0.01) * ly, (R + 0.01) * lz }
		local w = Quat.rotate(q, local_)
		-- the wall: thin along its normal (local Y of the wall frame), long along the rod
		local wq = Quat.hemisphere(Quat.normalize(Quat.mul(q, L.axisAngle(1, 0, 0, math.deg(a) - 90))))
		table.insert(parts, L.part("Guard", "Block", { c[1] + w[1], c[2] + w[2], c[3] + w[3] }, wq, { 2 * hx + 0.06, side, 0.02 }))
	end
	for s = -1, 1, 2 do
		local w = Quat.rotate(q, { s * (hx + D - eps + 0.01), 0, 0 })
		table.insert(parts, L.part("Guard", "Block", { c[1] + w[1], c[2] + w[2], c[3] + w[3] }, q, { 0.02, 2 * (r + D) + 0.06, 2 * (r + D) + 0.06 }))
	end
	L.renumber(parts)
	local P = L.prep(parts)
	local e = L.Sampling.exposure(P)
	local read = L.readOf(P, 1, L.models(P))
	n += 1
	if e.kept[1] then kept += 1 end
	if read > worst[1] then
		local _, _, hider = L.Oracle.flags(P)
		local truth = L.Oracle.share(P, 1, hider)
		worst = { read, r, k, eps, turn, truth }
	end
end
print(fmt("%d sealed rods: %d kept; the highest reading %.4f%% (r %.2f, %d-gon, corners δ − %.0e, turned %.1f°; truth %.4f%%)", n, kept, 100 * worst[1], worst[2] or 0, worst[3] or 0, worst[4] or 0, worst[5] or 0, 100 * (worst[6] or 0)))
