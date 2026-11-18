--!nocheck
local L = require("./lib")
for _, d in ipairs({ 0.02, 0.1, 0.3, 0.6 }) do
	local P = L.Shapes.prepare(L.part("Blade", "Ball", { 0, 2, 0 }, L.I, { d, d, d }), 1)
	local m = L.Cover.model(P)
	local lo, hi = math.huge, 0
	for i = 1, m.np do lo = math.min(lo, m.sag[i]); hi = math.max(hi, m.sag[i]) end
	local P2 = L.Shapes.prepare(L.part("Blade", "Cylinder", { 0, 2, 0 }, L.I, { 0.5, d, d }), 1)
	local m2 = L.Cover.model(P2)
	print(string.format("Ball d=%.2f r=%.3f: sag %.5f..%.5f (%.4f..%.4f r), inner %.5f, model/sphere %.4f | Cylinder side sag %.6f (%.5f r)", d, P.r, lo, hi, lo / P.r, hi / P.r, m.inner, m.total / P.area, m2.sag[1], m2.sag[1] / P2.r))
end
