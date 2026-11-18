--!nocheck
-- the tier flip: the caged Ball r 0.08 (g 0.00537, b 0.0302) in a sword with a 0.050 × 0.16 blade; truth at 2M points
local L = require("./lib")
local mk = require("./cagelib")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local fmt = string.format
local r, g, b, th, w = 0.08, 0.00537, 0.0302, 0.05, 0.16
local c = { 0, 2.4, 0 }
local cage = mk.cage(L, r, g, b, 0.02, 2 * r + 0.1, c)
local parts = {}
table.insert(parts, L.part("Grip", "Block", { 0, 0.75, 0 }, L.I, { 0.16, 0.9, 0.16 }))
table.insert(parts, L.part("Guard", "Block", { 0, 1.29, 0 }, L.I, { 1.0, 0.18, 0.24 }))
local wallBottom = c[2] - (r + g + 0.02)
local wallTop = c[2] + (r + g + 0.02)
table.insert(parts, L.part("Blade", "Block", { 0, (1.38 + wallBottom) / 2, 0 }, L.I, { w, wallBottom - 1.38, th }))
table.insert(parts, L.part("Blade", "Block", { 0, (wallTop + 4.0) / 2, 0 }, L.I, { w, 4.0 - wallTop, th }))
cage[1].slot = "Blade"
local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Pommel" }
for k = 2, 7 do cage[k].slot = slots[k - 1] end
local eslots = { "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Grip" }
for k = 8, 19 do cage[k].slot = eslots[k - 7] end
for k = 1, #cage do table.insert(parts, cage[k]) end
L.renumber(parts)
local bi = 5
fs.writeFile("out/cageflip_sword.json", serde.encode("json", parts))
local okc = L.canonical(L.copyParts(parts))
local run = L.run(L.copyParts(parts), { measureInvalid = false })
local P = L.prep(parts)
local e = L.Sampling.exposure(P)
local read = L.readOf(P, bi, L.models(P))
local _, _, hider = L.Oracle.flags(P)
local t2m = L.Oracle.measure(P, bi, hider, 2000000)
print(fmt("%d parts, canonical %s, valid %s %s; the Ball reads %.4f%% (%s), truth %.4f%% (2M points)", #parts, tostring(okc), tostring(run.validation.ok), L.codes(run), 100 * read, e.kept[bi] and "kept" or "cleaned", 100 * t2m))
local Rb = L.emu(L.copyParts(parts))
local row = table.clone(e.kept)
row[bi] = false
local Rt = L.emu(L.copyParts(parts), row)
print("build " .. L.dline(Rb))
print("truth " .. L.dline(Rt))
for _, s in ipairs(Rb.steps) do
	if s.step == "Hammering" then
		local f = {}
		for _, fv in ipairs(s.factors) do f[fv.factor] = fv.x end
		print(fmt("  build Hammering factors: Thinness %.4f Asymmetry %.4f SC %.4f", f.Thinness, f.Asymmetry, f.SurfaceComplexity))
	end
end
for _, s in ipairs(Rt.steps) do
	if s.step == "Hammering" then
		local f = {}
		for _, fv in ipairs(s.factors) do f[fv.factor] = fv.x end
		print(fmt("  truth Hammering factors: Thinness %.4f Asymmetry %.4f SC %.4f", f.Thinness, f.Asymmetry, f.SurfaceComplexity))
	end
end
