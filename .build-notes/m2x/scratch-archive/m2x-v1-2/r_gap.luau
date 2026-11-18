--!nocheck
-- the Ball model's gap to its sphere along a direction m: r − max_v m·(v − c); the best single, perpendicular pair and
-- orthogonal triple of directions (random frames, then a local polish)
local L = require("./lib")
local fmt = string.format
local P = L.Shapes.prepare(L.part("Blade", "Ball", { 0, 0, 0 }, L.I, { 2, 2, 2 }), 1)
local m = L.Cover.model(P)
local V = {}
for f = 1, m.n do
	local p = m.poly[f]
	for i = 1, #p, 3 do
		table.insert(V, { p[i], p[i + 1], p[i + 2] })
	end
end
local function gap(x, y, z)
	local best = -math.huge
	for _, v in ipairs(V) do
		best = math.max(best, x * v[1] + y * v[2] + z * v[3])
	end
	return 1 - best
end
-- single
local bs = { 0 }
for f = 1, m.n do
	local g = gap(m.nx[f], m.ny[f], m.nz[f])
	if g > bs[1] then bs = { g, m.nx[f], m.ny[f], m.nz[f] } end
end
print(fmt("single: gap %.5f r along (%.4f, %.4f, %.4f); sag max %.5f", bs[1], bs[2], bs[3], bs[4], m.sag[1]))
local maxsag = 0
for i = 1, m.np do maxsag = math.max(maxsag, m.sag[i]) end
print("max sag", maxsag)
-- frames: random rotations, score = min gap over the 3 axes (triple) and over 2 axes (pair)
math.randomseed(7)
local Quat = L.Quat
local bestP, bestT = { 0 }, { 0 }
local function frame(q)
	local ux, vx, wx, uy, vy, wy, uz, vz, wz = Quat.toMatrix(q)
	return { { ux, uy, uz }, { vx, vy, vz }, { wx, wy, wz } }
end
local function score(q)
	local F = frame(q)
	local g1, g2, g3 = gap(F[1][1], F[1][2], F[1][3]), gap(F[2][1], F[2][2], F[2][3]), gap(F[3][1], F[3][2], F[3][3])
	local gs = { g1, g2, g3 }
	table.sort(gs)
	return gs[2], gs[1], gs
end
for t = 1, 20000 do
	local q = Quat.hemisphere(Quat.normalize({ math.random() - 0.5, math.random() - 0.5, math.random() - 0.5, math.random() - 0.5 }))
	local pair, triple = score(q)
	if pair > bestP[1] then bestP = { pair, q } end
	if triple > bestT[1] then bestT = { triple, q } end
end
-- polish
for _, B in ipairs({ bestP, bestT }) do
	local which = if B == bestP then 1 else 2
	for it = 1, 4000 do
		local q = B[2]
		local d = 0.02 * (1 - it / 4000) + 1e-4
		local q2 = Quat.hemisphere(Quat.normalize({ q[1] + d * (math.random() - 0.5), q[2] + d * (math.random() - 0.5), q[3] + d * (math.random() - 0.5), q[4] + d * (math.random() - 0.5) }))
		local pair, triple = score(q2)
		local s = if which == 1 then pair else triple
		if s > B[1] then B[1], B[2] = s, q2 end
	end
end
local _, _, gp = score(bestP[2])
local _, _, gt = score(bestT[2])
print(fmt("pair: min gap %.5f r, q = {%.17g, %.17g, %.17g, %.17g}, gaps %.5f %.5f %.5f", bestP[1], bestP[2][1], bestP[2][2], bestP[2][3], bestP[2][4], gp[1], gp[2], gp[3]))
print(fmt("triple: min gap %.5f r, q = {%.17g, %.17g, %.17g, %.17g}, gaps %.5f %.5f %.5f", bestT[1], bestT[2][1], bestT[2][2], bestT[2][3], bestT[2][4], gt[1], gt[2], gt[3]))
