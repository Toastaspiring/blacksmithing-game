--!nocheck
-- V1 (m2x, round 4): the price on a round guard disk (a Cylinder r 0.8 along Z, the largest round part a sword's hitbox
-- holds): a Block a (round the rim) × depth × b (along the axis), its top face p out of the side, centred on a 32-gon
-- vertex's direction (where the moved-out sides stand 0.0048 r out) or a side's middle.
local L = require("./lab").tree(require("@lune/process").env.TREE or "now")
local fmt = string.format
local R = 0.8
local C = { 0, 2, 0 }
-- the disk's 32-gon frame: Cover starts the circle from the world axis most across the axis (Z): Y, then X
local function run(where, a, b, p)
	local parts = { L.part("Guard", "Cylinder", C, L.Y90, { 0.5, 2 * R, 2 * R }) } -- axis local X → world Z under Y90? check below
	local P0 = L.Shapes.prepare(parts[1], 1)
	local m = L.Cover.model(P0)
	-- a vertex of side facet 1 and that facet's middle, as directions across the axis
	local v = m.poly[1]
	local ux, uy, uz = P0.ux, P0.uy, P0.uz
	local function across(x, y, z)
		local dx, dy, dz = x - P0.cx, y - P0.cy, z - P0.cz
		local t = dx * ux + dy * uy + dz * uz
		dx, dy, dz = dx - t * ux, dy - t * uy, dz - t * uz
		local l = math.sqrt(dx * dx + dy * dy + dz * dz)
		return { dx / l, dy / l, dz / l }
	end
	local d = if where == "vertex" then across(v[1], v[2], v[3]) else { m.nx[1], m.ny[1], m.nz[1] }
	local depth = 0.1
	local k = R + p - depth / 2
	-- the Block's local Y along d, its local Z along the disk's axis
	local yv = d
	local zv = { ux, uy, uz }
	local xv = { yv[2] * zv[3] - yv[3] * zv[2], yv[3] * zv[1] - yv[1] * zv[3], yv[1] * zv[2] - yv[2] * zv[1] }
	local q = L.Quat.fromMatrix(xv[1], yv[1], zv[1], xv[2], yv[2], zv[2], xv[3], yv[3], zv[3])
	q = L.Quat.hemisphere(L.Quat.normalize(q))
	table.insert(parts, L.part("Blade", "Block", { C[1] + k * d[1], C[2] + k * d[2], C[3] + k * d[3] }, q, { a, depth, b }))
	L.renumber(parts)
	local P = L.prep(parts)
	local read = L.readOf(P, 2, L.models(P))
	local _, _, hider = L.Oracle.flags(P)
	local truth = L.Oracle.share(P, 2, hider)
	print(fmt("disk axis (%.3f, %.3f, %.3f); %-6s Block %.2f × %.2f × %.2f, %.4f out: reads %6.3f%%, truth %6.3f%%%s", ux, uy, uz, where, a, depth, b, p,
		100 * read, 100 * truth, if (read >= 0.02) ~= (truth >= 0.02) then "  <-" else ""))
end
for _, where in ipairs({ "vertex", "middle" }) do
	for _, ab in ipairs({ { 0.04, 0.2 }, { 0.06, 0.4 }, { 0.1, 0.45 } }) do
		for _, p in ipairs({ 0.0005, 0.001, 0.002, 0.003 }) do
			run(where, ab[1], ab[2], p)
		end
	end
end
