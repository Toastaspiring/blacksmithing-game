--!nocheck
-- m2x-fix-3: V1's tie-axis rods (m2x-v1-3/tieaxis.luau) on the base and the build: a Cylinder whose axis has its two smallest
-- components equal (two 45° snaps) and its copy spun about the axis in a later slot; what each reads, spun 0…179°
local Lab = require("./lab")
local fmt = string.format
for _, T in ipairs({ Lab.tree("base"), Lab.tree("now") }) do
	local Quat = T.Quat
	local snap = Quat.hemisphere(Quat.normalize(Quat.mul(T.axisAngle(0, 1, 0, -45), T.axisAngle(0, 0, 1, 45))))
	for _, size in ipairs({ { 1.0, 0.12, 0.12 }, { 0.6, 0.24, 0.24 } }) do
		local worstCopy, worstAng, leastOrig = 0, 0, 1
		for ang = 0, 179 do
			local q2 = Quat.hemisphere(Quat.normalize(Quat.mul(snap, T.axisAngle(1, 0, 0, ang))))
			local parts = T.renumber({ T.part("Blade", "Cylinder", { 0, 2, 0 }, snap, size), T.part("Guard", "Cylinder", { 0, 2, 0 }, q2, size) })
			local P = T.prep(parts)
			local models = T.models(P)
			if models[2] then
				local s2 = T.readOf(P, 2, models)
				local s1 = T.readOf(P, 1, models)
				if s2 > worstCopy then
					worstCopy, worstAng = s2, ang
				end
				leastOrig = math.min(leastOrig, s1)
			end
		end
		print(fmt("%s rods %.2f x %.2f: the spun copy reads at most %.3f%% (spun %d°), the original at least %.3f%%",
			T.root == Lab.ROOTS.now and "build" or "base ", size[1], size[2], 100 * worstCopy, worstAng, 100 * leastOrig))
	end
end
