--!nocheck
local L = require("./lib")
local P = L.Shapes.prepare({ id = 1, shape = "Ball", slot = "Blade", material = "Iron", pos = { 0, 2, 0 }, rot = { 0, 0, 0, 1 }, size = { 0.3, 0.3, 0.3 } }, 1)
local m = L.Cover.model(P)
local mx, mn = 0, 1
for f = 1, m.n do mx = math.max(mx, m.area[f] / m.total); mn = math.min(mn, m.area[f] / m.total) end
print(m.n, mx, mn, m.total / (4 * math.pi * P.r * P.r), m.work)
local C = L.Shapes.prepare({ id = 1, shape = "Cylinder", slot = "Blade", material = "Iron", pos = { 0, 2, 0 }, rot = { 0, 0, 0, 1 }, size = { 1, 0.3, 0.3 } }, 1)
local mc = L.Cover.model(C)
print(mc.n, mc.total / C.area, mc.work, mc.sag[1], mc.sag[33], mc.sag[34])
