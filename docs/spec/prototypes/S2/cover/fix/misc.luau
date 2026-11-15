--!nocheck
-- V1's non-twin mirror flip (a3_flip), the caged-Ball sword through the emulator, the C09 plate's reading
local L = require("./lab")
local E = require("./emulab")
local Cage = require("./cage")
local fmt = string.format
local dz = 0.05
local function P(pos, size) return { id = 0, slot = "Blade", shape = "Block", material = "Iron", pos = pos, rot = { 0, 0, 0, 1 }, size = size } end
local parts = {
	P({ 0, -0.01, dz }, { 0.5, 0.02, 0.5 }), P({ 0, -0.01, -dz }, { 0.25, 0.02, 1.0 }), P({ 0, -0.0275, dz }, { 0.5, 0.015, 0.5 }),
	P({ 0.26, -0.02, dz }, { 0.02, 0.04, 0.54 }), P({ -0.26, -0.02, dz }, { 0.02, 0.04, 0.54 }), P({ 0, -0.02, dz + 0.26 }, { 0.5, 0.04, 0.02 }),
	P({ 0, -0.02, dz - 0.26 }, { 0.5, 0.04, 0.02 }),
}
local function lid(x0, x1, z0, z1) table.insert(parts, P({ (x0 + x1) / 2, 0.05, (z0 + z1) / 2 }, { x1 - x0, 0.1, z1 - z0 })) end
lid(-0.25, -0.05, dz - 0.25, dz + 0.25)
lid(0.05, 0.25, dz - 0.25, dz + 0.25)
lid(-0.05, 0.05, dz - 0.25, 0.0)
lid(-0.05, 0.05, 0.162, dz + 0.25)
for i, p in ipairs(parts) do p.id = i end
local A = L.prepared(parts)
local img = {}
for i, p in ipairs(parts) do img[i] = L.Mirror.reflect(p, "Z") end
local Q = L.prepared(img)
local ea, eb = L.Sampling.exposure(A), L.Sampling.exposure(Q)
local _, _, ha = L.Oracle.flags(A)
local _, _, hb = L.Oracle.flags(Q)
print(fmt("original: T reads %.3f%% (truth %.3f%%) %s", 100 * L.H.reads(A, 1), 100 * L.Oracle.share(A, 1, ha), ea.kept[1] and "kept" or "cleaned"))
print(fmt("Z mirror: T reads %.3f%% (truth %.3f%%) %s", 100 * L.H.reads(Q, 1), 100 * L.Oracle.share(Q, 1, hb), eb.kept[1] and "kept" or "cleaned"))
-- the caged-Ball sword: D of the build against the truth's row, Ball in the Blade and as Pommel
for _, slot in ipairs({ "Blade", "Pommel" }) do
	local sw = Cage.sword(nil, nil, nil, slot)
	local Ps = L.prepared(sw)
	local e = L.Sampling.exposure(Ps)
	local row = table.clone(e.kept)
	local _, _, h = L.Oracle.flags(Ps)
	row[5] = L.Oracle.share(Ps, 5, h) >= 0.02
	local Rb, Rt = E.run(sw), E.run(sw, row)
	local forced = table.clone(e.kept)
	forced[5] = true
	print(fmt("caged sword, Ball in %s: build %s | truth row %s | the Ball kept %s", slot, E.dline(Rb), E.dline(Rt), E.dline(E.run(sw, forced))))
end
-- C09 + the plate: what the verdict reads on it
local base = L.H.ornate()
table.insert(base.parts, L.H.part(50, "Blade", "Block", "Iron", { -0.03, 2.6, 0 }, L.H.I, { 0.12, 2, 0.05 }))
local Pp = L.prepared(base.parts)
print(fmt("C09 + plate: reads %.3f%%", 100 * L.H.reads(Pp, #base.parts)))
