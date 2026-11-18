--!nocheck
-- V1 (m2x, round 3): a Cylinder whose axis has its two smallest components equal (two 45° snaps: (0.7071, 0.5, 0.5)) and its
-- copy spun about that axis, in a later slot: what the copy reads (it truly shows nothing), and a Cylinder off the tie.
local L = require("./lib")
local Quat = L.Quat
local fmt = string.format

-- the frame taking local X to (0.7071, 0.5, 0.5): 45° about Z then 45° about the new... built as two 45° snaps
local snap = Quat.hemisphere(Quat.normalize(Quat.mul(L.axisAngle(0, 1, 0, -45), L.axisAngle(0, 0, 1, 45))))
local function axisOf(q)
	local ux, vx, wx, uy, vy, wy, uz, vz, wz = Quat.toMatrix(q)
	return ux, uy, uz
end
print(fmt("axis %.17g %.17g %.17g", axisOf(snap)))
local worst, worstAng = 0, 0
for ang = 0, 179, 1 do
	local q2 = Quat.hemisphere(Quat.normalize(Quat.mul(snap, L.axisAngle(1, 0, 0, ang))))
	local parts = {
		L.part("Blade", "Cylinder", { 0, 2, 0 }, snap, { 1.0, 0.12, 0.12 }),
		L.part("Guard", "Cylinder", { 0, 2, 0 }, q2, { 1.0, 0.12, 0.12 }),
	}
	L.renumber(parts)
	local P = L.prep(parts)
	local models = L.models(P)
	if models[2] then
		local s = L.readOf(P, 2, models)
		if s > worst then
			worst, worstAng = s, ang
		end
	end
end
print(fmt("tie axis: the spun copy reads at most %.3f%% (spun %d°)", 100 * worst, worstAng))
-- off the tie: the axis nudged
local off = Quat.hemisphere(Quat.normalize(Quat.mul(snap, L.axisAngle(0, 1, 0, 0.3))))
local worst2 = 0
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
		worst2 = math.max(worst2, (L.readOf(P, 2, models)))
	end
end
print(fmt("off the tie by 0.3°: the spun copy reads at most %.3f%%", 100 * worst2))
