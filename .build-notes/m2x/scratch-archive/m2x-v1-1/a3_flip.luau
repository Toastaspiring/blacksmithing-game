--!nocheck
-- A3b: a verdict a Z mirror flips without twins: plate T and plate B tie on volume, cy, |cx|, |cz| (cz ±0.05), are not
-- images of each other, and share a coplanar window on T's top; everything else of T is under lids, walls and a floor.
local L = require("./lib")
local Mirror = L.Mirror
local fmt = string.format
local dz = 0.05
local function P(shape, pos, size) return L.part("Blade", shape, pos, L.I, size) end
local parts = {
	P("Block", { 0, -0.01, dz }, { 0.5, 0.02, 0.5 }), -- T
	P("Block", { 0, -0.01, -dz }, { 0.25, 0.02, 1.0 }), -- B: the same volume, cz opposite
	P("Block", { 0, -0.0275, dz }, { 0.5, 0.015, 0.5 }), -- floor
	P("Block", { 0.26, -0.02, dz }, { 0.02, 0.04, 0.54 }),
	P("Block", { -0.26, -0.02, dz }, { 0.02, 0.04, 0.54 }),
	P("Block", { 0, -0.02, dz + 0.26 }, { 0.5, 0.04, 0.02 }),
	P("Block", { 0, -0.02, dz - 0.26 }, { 0.5, 0.04, 0.02 }),
}
local function lid(x0, x1, z0, z1)
	table.insert(parts, P("Block", { (x0 + x1) / 2, 0.05, (z0 + z1) / 2 }, { x1 - x0, 0.1, z1 - z0 }))
end
local wz0, wz1 = 0.0, 0.162
lid(-0.25, -0.05, dz - 0.25, dz + 0.25)
lid(0.05, 0.25, dz - 0.25, dz + 0.25)
lid(-0.05, 0.05, dz - 0.25, wz0)
lid(-0.05, 0.05, wz1, dz + 0.25)
L.renumber(parts)
local A = L.prep(parts)
print(fmt("T volume %.17g, B volume %.17g", A[1].volume, A[2].volume))
local img = {}
for i, p in ipairs(parts) do img[i] = Mirror.reflect(p, "Z") end
L.renumber(img)
local Q = L.prep(img)
local ea, eb = L.Sampling.exposure(A), L.Sampling.exposure(Q)
local _, _, ha = L.Oracle.flags(A)
local _, _, hb = L.Oracle.flags(Q)
print(fmt("original: T reads %.3f%% (truth %.3f%%) %s; B reads %.3f%%", 100 * L.readOf(A, 1), 100 * L.Oracle.share(A, 1, ha), ea.kept[1] and "kept" or "cleaned", 100 * L.readOf(A, 2)))
print(fmt("Z mirror: T reads %.3f%% (truth %.3f%%) %s; B reads %.3f%%", 100 * L.readOf(Q, 1), 100 * L.Oracle.share(Q, 1, hb), eb.kept[1] and "kept" or "cleaned", 100 * L.readOf(Q, 2)))
local twin = false
for j = 1, #parts do if L.Shapes.sameSolid(Q[j], A[1]) then twin = true end end
print("T has a twin:", twin)
