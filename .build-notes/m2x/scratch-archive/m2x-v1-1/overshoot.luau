--!nocheck
-- how far a round model's probe polytope (half-spaces moved out by their sag) stands past the part's AABB
local L = require("./lib")
local function solve3(a, b, c) -- planes {nx,ny,nz,d}: intersection point
	local function det(m) return m[1]*(m[5]*m[9]-m[6]*m[8]) - m[2]*(m[4]*m[9]-m[6]*m[7]) + m[3]*(m[4]*m[8]-m[5]*m[7]) end
	local M = { a[1], a[2], a[3], b[1], b[2], b[3], c[1], c[2], c[3] }
	local D = det(M)
	if math.abs(D) < 1e-9 then return nil end
	local function rep(col)
		local m = table.clone(M)
		m[col], m[col + 3], m[col + 6] = a[4], b[4], c[4]
		return det(m)
	end
	return { rep(1) / D, rep(2) / D, rep(3) / D }
end
for _, shape in ipairs({ "Ball", "Cylinder" }) do
	local P = L.Shapes.prepare(L.part("Blade", shape, { 0, 0, 0 }, if shape == "Cylinder" then L.axisAngle(1, 2, 3, 40) else L.I, if shape == "Ball" then { 0.4, 0.4, 0.4 } else { 0.6, 0.4, 0.4 }), 1)
	local m = L.Cover.model(P)
	local pl = {}
	for i = 1, m.np do
		pl[i] = { m.planes[4 * i - 3], m.planes[4 * i - 2], m.planes[4 * i - 1], m.planes[4 * i] + m.sag[i] }
	end
	local over = 0
	local n = m.np
	for i = 1, n do
		for j = i + 1, n do
			for k = j + 1, n do
				local x = solve3(pl[i], pl[j], pl[k])
				if x then
					local ok = true
					for q = 1, n do
						if pl[q][1] * x[1] + pl[q][2] * x[2] + pl[q][3] * x[3] > pl[q][4] + 1e-12 then ok = false; break end
					end
					if ok then
						over = math.max(over, x[1] - P.maxx, P.minx - x[1], x[2] - P.maxy, P.miny - x[2], x[3] - P.maxz, P.minz - x[3])
					end
				end
			end
		end
		if shape == "Ball" and i > 40 then break end -- the octants repeat
	end
	print(shape, "r", P.r, "probe polytope past the AABB by", over, "=", over / P.r, "r")
end
