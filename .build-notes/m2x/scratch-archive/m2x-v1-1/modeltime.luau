--!nocheck
local L = require("./lib")
local fmt = string.format
for _, shape in ipairs({ "Ball", "Cylinder", "Block", "Wedge", "CornerWedge" }) do
	local size = if shape == "Ball" then { 0.58, 0.58, 0.58 } elseif shape == "Cylinder" then { 1, 0.3, 0.3 } else { 0.5, 0.4, 0.3 }
	local P = L.Shapes.prepare(L.part("Blade", shape, { 0, 2, 0 }, L.axisAngle(1, 2, 3, 30), size), 1)
	local t = {}
	local m
	for run = 1, 21 do
		local a = os.clock()
		for k = 1, 50 do m = L.Cover.model(P) end
		t[run] = (os.clock() - a) * 1000 / 50
	end
	table.sort(t)
	print(fmt("%-12s model: %d facets, %.1f units, median %.4f ms (%.0f ns a unit), best %.4f, worst %.4f", shape, m.n, m.work, t[11], t[11] / m.work * 1e6, t[1], t[21]))
end
