--!nocheck
local L = require("../lib")
local fmt = string.format
local P = L.prep(L.renumber({ L.part("Blade", "Ball", { 0, 1, 0 }, L.I, { 0.6, 0.6, 0.6 }), L.part("Blade", "Cylinder", { 0, 2, 0 }, L.axisAngle(0.3, 0.2, 1, 40), { 1, 0.6, 0.6 }) }))
local b = L.Cover.model(P[1])
local c = L.Cover.model(P[2])
local smin, smax, sagmax = math.huge, 0, 0
for f = 1, b.n do smin = math.min(smin, b.spread[f]); smax = math.max(smax, b.spread[f]); sagmax = math.max(sagmax, b.sag[f]) end
print(fmt("Ball: %d facets, area %.4f%% of the sphere, spread %.5f–%.5f, sag max %.5f r, reach %.5f", b.n, 100 * b.total / (4 * math.pi * 0.09), smin, smax, sagmax / 0.3, b.reach))
local cs = 0
for f = 1, 32 do cs = math.max(cs, c.spread[f]) end
print(fmt("Cylinder: %d facets, side spread %.5f (δ·sin(π/32) %.5f), caps %.3g %.3g, sag side %.5f r", c.n, cs, 0.012 * math.sin(math.pi / 32), c.spread[33], c.spread[34], c.sag[1] / 0.3))
