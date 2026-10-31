--!strict
-- v2: exact convex overlap vs fine sampling
local Shapes = require("./shapes")
local Overlap = require("./overlap")
local Quat = require("./quat")
local fmt = string.format
local function P(shape, pos, rot, size) return Shapes.prepare({ id = 1, shape = shape, slot = "Blade", material = "Iron", pos = pos, rot = rot, size = size }, 1) end
local I = { 0, 0, 0, 1 }
local function fine(p, q)
	local xs, ys, zs, w = Shapes.volumeSamples(p, 0.004, 3, 400, 4000000)
	local V, Mx, My, Mz = 0, 0, 0, 0
	for k = 1, #xs do
		if Shapes.sd(q, xs[k], ys[k], zs[k]) < 0 then V += w; Mx += w * xs[k]; My += w * ys[k]; Mz += w * zs[k] end
	end
	return V, Mx, My, Mz
end
local cases = {
	{ "box/box axis", P("Block", { 0, 0, 0 }, I, { 0.2, 1, 0.06 }), P("Block", { 0.05, 0.4, 0.01 }, I, { 0.2, 0.4, 0.06 }) },
	{ "box/box rot 45z", P("Block", { 0, 2.65, 0 }, I, { 0.16, 2.6, 0.06 }), P("Block", { 0, 3.95, 0 }, Quat.axisAngle(0, 0, 1, 45), { 0.113, 0.113, 0.055 }) },
	{ "box/wedge rot", P("Block", { 0, 0, 0 }, I, { 0.3, 0.5, 0.2 }), P("Wedge", { 0.1, 0.2, 0.05 }, Quat.axisAngle(0.3, 1, 0.2, 37), { 0.25, 0.3, 0.2 }) },
	{ "corner/box rot", P("CornerWedge", { 0, 0, 0 }, Quat.axisAngle(1, 0.2, 0.1, 21), { 0.4, 0.3, 0.25 }), P("Block", { 0.05, 0.05, -0.03 }, Quat.axisAngle(0, 1, 1, 60), { 0.2, 0.2, 0.2 }) },
	{ "laminate z", P("Block", { 0, 0, 0.01 }, I, { 0.2, 2.5, 0.05 }), P("Block", { 0, 0, 0 }, I, { 0.2, 2.5, 0.05 }) },
}
for _, c in ipairs(cases) do
	local t0 = os.clock()
	local V, Mx, My, Mz = Overlap.exact(c[2], { c[3] })
	local te = os.clock() - t0
	local Vf, Fx, Fy, Fz = fine(c[2], c[3])
	print(fmt("%-18s exact V %.7f c (%.5f %.5f %.5f) %.3f ms | fine V %.7f c (%.5f %.5f %.5f) | relErr %.2e", c[1], V, Mx / math.max(V, 1e-30), My / math.max(V, 1e-30), Mz / math.max(V, 1e-30), te * 1000, Vf, Fx / math.max(Vf, 1e-30), Fy / math.max(Vf, 1e-30), Fz / math.max(Vf, 1e-30), math.abs(V - Vf) / math.max(Vf, 1e-12)))
end
-- full self-volume check: clip a part by a huge box -> its own volume
for _, s in ipairs({ "Block", "Wedge", "CornerWedge" }) do
	local p = P(s, { 0.1, 0.2, 0.3 }, Quat.axisAngle(0.3, 1, 0.2, 37), { 0.3, 0.5, 0.2 })
	local big = P("Block", { 0, 0, 0 }, I, { 5, 5, 5 })
	local V, Mx, My, Mz = Overlap.exact(p, { big })
	print(fmt("%-12s self V %.9f analytic %.9f | centroid (%.6f %.6f %.6f) analytic (%.6f %.6f %.6f)", s, V, p.volume, Mx / V, My / V, Mz / V, p.gx, p.gy, p.gz))
end
