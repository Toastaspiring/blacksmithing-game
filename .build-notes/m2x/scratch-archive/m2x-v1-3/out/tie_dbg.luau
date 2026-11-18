--!nocheck
local L = require("../lib")
local Quat = L.Quat
local fmt = string.format
local snap = Quat.hemisphere(Quat.normalize(Quat.mul(L.axisAngle(0, 1, 0, -45), L.axisAngle(0, 0, 1, 45))))
local off = Quat.hemisphere(Quat.normalize(Quat.mul(snap, L.axisAngle(0, 1, 0, 0.3))))
for ang = 0, 179, 1 do
	local q2 = Quat.hemisphere(Quat.normalize(Quat.mul(off, L.axisAngle(1, 0, 0, ang))))
	local parts = {
		L.part("Blade", "Cylinder", { 0, 2, 0 }, off, { 1.0, 0.12, 0.12 }),
		L.part("Guard", "Cylinder", { 0, 2, 0 }, q2, { 1.0, 0.12, 0.12 }),
	}
	L.renumber(parts)
	local P = L.prep(parts)
	local models = L.models(P)
	if models[2] then
		local s, used, shown = L.readOf(P, 2, models)
		if s > 1.0000001 then
			print(fmt("ang %d: share %.6g shown %.17g total %.17g used %.1f n %d", ang, s, shown, models[2].total, used, models[2].n))
			local m = models[2]
			for f = 1, m.n do
				if m.area[f] ~= m.area[f] or m.area[f] > 10 then
					print("facet", f, m.area[f])
				end
			end
			print(fmt("axis2 %.17g %.17g %.17g", P[2].ux, P[2].uy, P[2].uz))
			print(fmt("axis1 %.17g %.17g %.17g", P[1].ux, P[1].uy, P[1].uz))
			break
		end
	end
end
