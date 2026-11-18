--!nocheck
-- one flat wall past HIDE_OFFSET from a Ball's true surface (so it truly hides nothing): how much of the Ball's model the
-- reading hides, over the wall's direction and gap
local L = require("./lib")
local fmt = string.format
local Quat = L.Quat
local function frameTo(m)
	-- a rotation taking local +Y to m
	local ax, az = m[3], -m[1]
	local s = math.sqrt(ax * ax + az * az)
	if s < 1e-12 then
		return if m[2] > 0 then { 0, 0, 0, 1 } else { 1, 0, 0, 0 }
	end
	local ang = math.acos(math.max(-1, math.min(1, m[2])))
	return Quat.hemisphere(Quat.normalize({ ax / s * math.sin(ang / 2), 0, az / s * math.sin(ang / 2), math.cos(ang / 2) }))
end
local function hiddenBy(r, m, g)
	local d = r + g + 0.01
	local parts = {
		L.part("Blade", "Ball", { 0, 0, 0 }, L.I, { 2 * r, 2 * r, 2 * r }),
		L.part("Guard", "Block", { m[1] * d, m[2] * d, m[3] * d }, frameTo(m), { 4 * r, 0.02, 4 * r }),
	}
	L.renumber(parts)
	local P = L.prep(parts)
	return 1 - L.readOf(P, 1)
end
math.randomseed(3)
for _, r in ipairs({ 0.05, 0.1, 0.2, 0.25 }) do
	local best = { 0 }
	-- candidate directions: grid vertices of the model (where it touches the sphere)
	local P = L.Shapes.prepare(L.part("Blade", "Ball", { 0, 0, 0 }, L.I, { 2, 2, 2 }), 1)
	local mm = L.Cover.model(P)
	local dirs = {}
	for f = 1, mm.n do
		local p = mm.poly[f]
		for i = 1, #p, 3 do
			table.insert(dirs, { p[i], p[i + 1], p[i + 2] })
		end
		table.insert(dirs, { mm.nx[f], mm.ny[f], mm.nz[f] })
	end
	for k = 1, 300 do
		local x, y, z = math.random() - 0.5, math.random() - 0.5, math.random() - 0.5
		local l = math.sqrt(x * x + y * y + z * z)
		table.insert(dirs, { x / l, y / l, z / l })
	end
	for _, m in ipairs(dirs) do
		for _, gf in ipairs({ 0.0001, 0.001, 0.003, 0.006, 0.01, 0.015 }) do
			local g = 0.012 + 1e-6 + gf * r
			local h = hiddenBy(r, m, g)
			if h > best[1] then best = { h, m, g } end
		end
	end
	print(fmt("r %.2f: a wall %.5f off the sphere (past HIDE_OFFSET by %.5f), along (%.4f, %.4f, %.4f), hides %.3f%% of the model; truly nothing",
		r, best[3], best[3] - 0.012, best[2][1], best[2][2], best[2][3], 100 * best[1]))
end
