--!nocheck
-- A Ball sealed in a cage in the blade of a valid sword: truly hidden (VisibleOracle), the model's hide test hides it, the
-- build's per-facet box test (HIDE_OFFSET + 2 EPS) skips the walls its own probe reaches, so it reads over 2 % and is kept.
local process = require("@lune/process")
local L = require("./lib")
local mk = require("./cagelib")
local fmt = string.format
local r, g, b = tonumber(process.args[1]) or 0.20, tonumber(process.args[2]) or 0.002769, tonumber(process.args[3]) or 0.051018
local ballSlot = process.args[4] or "Blade"
local material = process.args[5] or "Iron"
local c = { 0, 2.4, 0 }
local cage = mk.cage(L, r, g, b, 0.02, 2 * r + 0.1, c)
local parts = {}
table.insert(parts, L.part("Grip", "Block", { 0, 0.75, 0 }, L.I, { 0.16, 0.9, 0.16 }))
table.insert(parts, L.part("Guard", "Block", { 0, 1.29, 0 }, L.I, { 1.0, 0.18, 0.24 }))
local wallBottom = c[2] - (r + g + 0.02)
local wallTop = c[2] + (r + g + 0.02)
table.insert(parts, L.part("Blade", "Block", { 0, (1.38 + wallBottom) / 2, 0 }, L.I, { 0.16, wallBottom - 1.38, 0.06 }))
table.insert(parts, L.part("Blade", "Block", { 0, (wallTop + 4.0) / 2, 0 }, L.I, { 0.16, 4.0 - wallTop, 0.06 }))
-- cage: 1 ball, 6 walls (index 2..7), 12 edge blocks (8..19)
local ball = cage[1]
ball.slot = ballSlot
ball.material = material
local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Pommel" } -- walls
for k = 2, 7 do cage[k].slot = slots[k - 1] end
local eslots = { "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Grip" }
for k = 8, 19 do cage[k].slot = eslots[k - 7] end
for k = 1, #cage do table.insert(parts, cage[k]) end
L.renumber(parts)
local bi = 5 -- the ball
local okc = L.canonical(L.copyParts(parts))
local run = L.run(L.copyParts(parts), { measureInvalid = false })
local P = L.prep(parts)
local e = L.Sampling.exposure(P)
local read = L.readOf(P, bi, L.models(P))
local _, _, hider = L.Oracle.flags(P)
local truth = L.Oracle.share(P, bi, hider)
print(fmt("sword + caged Ball (r %.2f, g %.6f, b %.6f) in %s: %d parts, canonical %s, valid %s (%s), units %.1f", r, g, b, ballSlot, #parts, tostring(okc), tostring(run.validation.ok), L.codes(run), e.verdictWork))
print(fmt("  the Ball: reads %.3f%%, truth %.3f%%: build %s, truth %s", 100 * read, 100 * truth, e.kept[bi] and "kept" or "cleaned", truth >= 0.02 and "kept" or "cleaned"))
local Rb = L.emu(L.copyParts(parts))
local row = table.clone(e.kept)
row[bi] = truth >= 0.02
local Rt = L.emu(L.copyParts(parts), row)
local d, t, s = L.dDiff(Rb, Rt)
print("  build " .. L.dline(Rb))
print("  truth " .. L.dline(Rt))
print(fmt("  |dD| %.4f on %s, tier flip %s", d, s, tostring(t)))
