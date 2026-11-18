--!nocheck
local L = require("./lib")
local P = L.Shapes.prepare(L.part("Blade", "Ball", { 0, 0, 0 }, L.I, { 2, 2, 2 }), 1)
local m = L.Cover.model(P)
local maxsag, reach = 0, m.reach
for i = 1, m.np do maxsag = math.max(maxsag, m.sag[i]) end
print(string.format("Ball r 1: model area %.6f of 4πr² (%d facets), largest sag %.5f r, reach %.5f, over %.4f, work %.1f", m.total / (4 * math.pi), m.n, maxsag, reach, m.over, m.work))
local C = L.Shapes.prepare(L.part("Blade", "Cylinder", { 0, 0, 0 }, L.I, { 2, 2, 2 }), 1)
local mc = L.Cover.model(C)
local ms = 0
for i = 1, mc.np do ms = math.max(ms, mc.sag[i]) end
print(string.format("Cylinder r 1, hx 1: model area %.6f of the true, largest sag %.5f r (1 − cos(π/32) = %.5f), reach %.5f, over %.4f", mc.total / (2 * math.pi + 4 * math.pi), ms, 1 - math.cos(math.pi / 32), mc.reach, mc.over))
