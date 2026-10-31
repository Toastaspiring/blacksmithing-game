--!strict
-- Per-material (volume, centroid y) of each fixture, sum-of-parts, exact.
local P = require("../repo/src/shared/Physics/ProtoShapes")
local F = require("../repo/tests/fixtures/Blueprints")
for _, name in F.order do
	local parts = (F :: any)[name] :: { P.Part }
	local acc: { [string]: { v: number, vy: number, vx: number } } = {}
	for _, part in parts do
		local v = P.analyticVolume(part)
		local c = P.rotate(P.matrix(part.rot), P.localCentroid(part))
		local a = acc[part.material] or { v = 0, vy = 0, vx = 0 }
		a.v += v; a.vy += v * (part.pos[2] + c[2]); a.vx += v * (part.pos[1] + c[1])
		acc[part.material] = a
	end
	local out = {}
	for _, mat in { "Iron", "Steel" } do
		local a = acc[mat]
		if a then table.insert(out, string.format("%s: V=%.6f ybar=%+.5f xbar=%+.5f", mat, a.v, a.vy / a.v, a.vx / a.v)) end
	end
	print(string.format("%-13s %s", name, table.concat(out, "   ")))
end
