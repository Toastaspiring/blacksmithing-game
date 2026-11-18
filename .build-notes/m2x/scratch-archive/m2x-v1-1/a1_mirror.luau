--!nocheck
-- the model of a mirror image against the mirror of the model, for a Cylinder whose axis ties (two smallest components equal)
local L = require("./lib")
local fmt = string.format
local function toDir(dx, dy, dz)
	local n = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / n, dy / n, dz / n
	return L.axisAngle(0, -dz, dy, math.deg(math.acos(dx)))
end
local function verts(m)
	local out = {}
	for f = 1, m.n do
		local p = m.poly[f]
		for k = 1, #p, 3 do table.insert(out, { p[k], p[k + 1], p[k + 2] }) end
	end
	return out
end
local function setDist(a, b) -- max over a of the nearest in b
	local worst = 0
	for _, v in ipairs(a) do
		local best = math.huge
		for _, w in ipairs(b) do
			local d = math.abs(v[1] - w[1]) + math.abs(v[2] - w[2]) + math.abs(v[3] - w[3])
			if d < best then best = d end
		end
		worst = math.max(worst, best)
	end
	return worst
end
for _, dir in ipairs({ { 1, 1, 1 }, { 1, 1, 2 }, { 2, 1, 1 }, { 1, 2, 1 }, { 1, 1, 3 }, { 0.3, 1, 0.3 } }) do
	for spin = 0, 50, 10 do
		local q = L.Quat.hemisphere(L.Quat.normalize(L.Quat.mul(toDir(dir[1], dir[2], dir[3]), L.axisAngle(1, 0, 0, spin))))
		local part = L.part("Blade", "Cylinder", { 0.1, 2, 0.05 }, q, { 0.6, 0.3, 0.3 })
		for _, plane in ipairs({ "X", "Z" }) do
			local img = L.Mirror.reflect(part, plane)
			local m = L.Cover.model(L.Shapes.prepare(part, 1))
			local mi = L.Cover.model(L.Shapes.prepare(img, 1))
			local refl = {}
			for _, v in ipairs(verts(m)) do table.insert(refl, if plane == "X" then { -v[1], v[2], v[3] } else { v[1], v[2], -v[3] }) end
			local d = setDist(verts(mi), refl)
			if d > 1e-9 then
				local P, Q = L.Shapes.prepare(part, 1), L.Shapes.prepare(img, 1)
				print(fmt("axis (%g,%g,%g) spin %d across %s: the image's model is %.4f off the mirrored model; u = (%.17g, %.17g, %.17g), image u = (%.17g, %.17g, %.17g)", dir[1], dir[2], dir[3], spin, plane, d, P.ux, P.uy, P.uz, Q.ux, Q.uy, Q.uz))
			end
		end
	end
end
print("done")
