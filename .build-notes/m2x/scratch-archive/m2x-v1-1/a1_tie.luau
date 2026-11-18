--!nocheck
-- A1: the Cylinder model's frame "from the world axis most across its own (Y, then X, then Z on a tie)": a tie between two
-- non-zero smallest components flips with the ulps of the axis, and the 32-gon turns by an angle that is no multiple of 11.25°.
local L = require("./lib")
local Quat = L.Quat
local fmt = string.format
-- axis u = R(q)·X. Pick q so that u = (a, a, b), a < b: rotate X about Z by 45°, then tilt about the new horizontal axis.
local function axisOf(q)
	local P = L.Shapes.prepare(L.part("Blade", "Cylinder", { 0, 2, 0 }, q, { 0.6, 0.24, 0.24 }), 1)
	return P.ux, P.uy, P.uz
end
local cases = {}
-- (1) body diagonal: u = (1,1,1)/sqrt 3
-- rotation taking X to (1,1,1)/sqrt3: axis X × d, angle acos(1/sqrt3)
local function toDir(dx, dy, dz)
	local n = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / n, dy / n, dz / n
	local ax, ay, az = 0, -dz, dy -- X × d
	local an = math.sqrt(ax * ax + ay * ay + az * az)
	local ang = math.deg(math.acos(dx))
	if an < 1e-12 then return L.I end
	return L.axisAngle(ax, ay, az, ang)
end
table.insert(cases, { "diag (1,1,1)", toDir(1, 1, 1) })
table.insert(cases, { "(1,1,2)", toDir(1, 1, 2) })
table.insert(cases, { "(1,2,1)", toDir(1, 2, 1) })
table.insert(cases, { "(2,1,1)", toDir(2, 1, 1) })
table.insert(cases, { "(1,1,3)", toDir(1, 1, 3) })
table.insert(cases, { "X axis (Y/Z tie at 0)", L.I })
table.insert(cases, { "Y axis (Z90)", L.Z90 })
for _, c in ipairs(cases) do
	local q = c[2]
	local ux, uy, uz = axisOf(q)
	local worst, worstAng, n = 0, 0, 0
	local keptBoth = 0
	for ang = 1, 359, 2 do
		local spun = Quat.hemisphere(Quat.normalize(Quat.mul(q, L.axisAngle(1, 0, 0, ang))))
		local parts = L.renumber({ L.part("Blade", "Cylinder", { 0, 2, 0 }, q, { 0.6, 0.24, 0.24 }), L.part("Blade", "Cylinder", { 0, 2, 0 }, spun, { 0.6, 0.24, 0.24 }) })
		local P = L.prep(parts)
		local r1, r2 = L.readOf(P, 1), L.readOf(P, 2)
		local lo = math.min(r1, r2)
		n += 1
		if lo > worst then
			worst, worstAng = lo, ang
		end
		local e = L.Sampling.exposure(P)
		if e.kept[1] and e.kept[2] then keptBoth += 1 end
	end
	print(fmt("%-24s u=(%.17g, %.17g, %.17g)  spins %d: the lower reading at worst %.3f%% (spin %d°), both kept in %d", c[1], ux, uy, uz, n, 100 * worst, worstAng, keptBoth))
end
