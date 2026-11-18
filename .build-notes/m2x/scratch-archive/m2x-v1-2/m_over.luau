--!nocheck
-- how far a round model's half-spaces moved out by their sag (the probe's) stand past the part's box: the vertices of that
-- polytope (every triple of planes, kept if inside all), their largest excess past c ± r along each world axis
local L = require("./lib")
local fmt = string.format
local function overOf(P)
	local m = L.Cover.model(P)
	local pl, sag = m.planes, m.sag
	local N = m.np
	local planes = {}
	for i = 1, N do
		planes[i] = { pl[4 * i - 3], pl[4 * i - 2], pl[4 * i - 1], pl[4 * i] + sag[i] }
	end
	local best = { 0, 0, 0 }
	local function det3(a, b, c)
		return a[1] * (b[2] * c[3] - b[3] * c[2]) - a[2] * (b[1] * c[3] - b[3] * c[1]) + a[3] * (b[1] * c[2] - b[2] * c[1])
	end
	for i = 1, N do
		for j = i + 1, N do
			for k = j + 1, N do
				local A, B, C = planes[i], planes[j], planes[k]
				local D = det3(A, B, C)
				if math.abs(D) > 1e-9 then
					-- Cramer
					local x = det3({ A[4], A[2], A[3] }, { B[4], B[2], B[3] }, { C[4], C[2], C[3] }) / D
					local y = det3({ A[1], A[4], A[3] }, { B[1], B[4], B[3] }, { C[1], C[4], C[3] }) / D
					local z = det3({ A[1], A[2], A[4] }, { B[1], B[2], B[4] }, { C[1], C[2], C[4] }) / D
					local ok = true
					for t = 1, N do
						local q = planes[t]
						if q[1] * x + q[2] * y + q[3] * z > q[4] + 1e-12 then ok = false break end
					end
					if ok then
						local ex = { math.abs(x - P.cx) - (P.maxx - P.cx), math.abs(y - P.cy) - (P.maxy - P.cy), math.abs(z - P.cz) - (P.maxz - P.cz) }
						for a = 1, 3 do best[a] = math.max(best[a], ex[a]) end
					end
				end
			end
		end
	end
	return best, m.over
end
local P = L.Shapes.prepare(L.part("Blade", "Ball", { 0, 0, 0 }, L.I, { 2, 2, 2 }), 1)
local b, o = overOf(P)
print(fmt("Ball r 1: past the box by x %.5f, y %.5f, z %.5f (over %.4f)", b[1], b[2], b[3], o))
for _, rot in ipairs({ L.I, L.axisAngle(1, 2, 3, 37), L.axisAngle(1, 1, 0, 45), L.axisAngle(0.3, 1, 0.2, 71) }) do
	local C = L.Shapes.prepare(L.part("Blade", "Cylinder", { 0, 0, 0 }, rot, { 1.2, 2, 2 }), 1)
	local bc, oc = overOf(C)
	print(fmt("Cylinder r 1 turned: past the box by x %.5f, y %.5f, z %.5f (over %.4f)", bc[1], bc[2], bc[3], oc))
end
