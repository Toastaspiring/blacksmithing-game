--!nocheck
-- fix-2: D through the emulator (V2's, emuV) on fin's kept rows: F3 and C08 with a copy of their blade a hair larger in the
-- Guard, the blade relabelled Guard; F5 and F3 with 4 skins 0.02 thick inside the guard labelled Blade; V1's cage-flip sword
local M = require("../mlib")
local fmt = string.format
local W = M.W
local function req(p) return (require :: any)(p) end
local Shapes = req(W .. "/fin/src/shared/Physics/Shapes")
local Sampling = req(W .. "/fin/src/shared/Physics/Sampling")
local Fx = req(W .. "/fin/docs/spec/prototypes/S2/v2/fixtures")
local B = req(W .. "/fin/tests/fixtures/Blueprints")
local T = M.tree("V")
local function finRow(parts)
	local P = {}
	for i, p in ipairs(parts) do P[i] = Shapes.prepare(p, i) end
	return Sampling.exposure(P).kept
end
local function D(parts)
	M.renumber(parts)
	return M.dline(M.emu(T, parts, finRow(parts)))
end
local function copyOf(list)
	return M.copyParts(list)
end
local C08
for _, b in ipairs(Fx.calibration()) do
	if string.sub(b.name, 1, 3) == "C08" then C08 = b.parts end
end
for _, case in ipairs({ { "F3", copyOf(B.core("F3").parts) }, { "C08", copyOf(C08) } }) do
	local base = case[2]
	local main = M.mainBlade(base)
	local blade = base[main]
	print(case[1] .. ": " .. D(copyOf(base)))
	local relabelled = copyOf(base)
	relabelled[main].slot = "Guard"
	print("   blade relabelled Guard: " .. D(relabelled))
	for _, grow in ipairs({ 1e-12, 1e-6, 1e-4 }) do
		local parts = copyOf(base)
		local c = copyOf({ blade })[1]
		c.slot = "Guard"
		c.size = { blade.size[1] + grow, blade.size[2] + grow, blade.size[3] + grow }
		table.insert(parts, c)
		local row = finRow(M.renumber(parts))
		print(fmt("   + its blade %g larger in the Guard: blade kept %s, copy kept %s: %s", grow, tostring(row[main]), tostring(row[#parts]), D(parts)))
	end
end
for _, name in ipairs({ "F5", "F3" }) do
	local base = copyOf(B.core(name).parts)
	local g
	for _, p in ipairs(base) do
		if p.slot == "Guard" and p.shape == "Block" then g = p end
	end
	local parts = copyOf(base)
	local tz, tx = 0.02, 0.02
	for k, d in ipairs({ { 0, (g.size[3] - tz) / 2, { g.size[1], g.size[2], tz } }, { 0, -(g.size[3] - tz) / 2, { g.size[1], g.size[2], tz } } }) do
		table.insert(parts, { id = 0, slot = "Blade", shape = "Block", material = "Iron", pos = { g.pos[1], g.pos[2], g.pos[3] + d[2] }, rot = g.rot, size = d[3] })
	end
	for _, s in ipairs({ 1, -1 }) do
		table.insert(parts, { id = 0, slot = "Blade", shape = "Block", material = "Iron", pos = { g.pos[1] + s * (g.size[1] - tx) / 2, g.pos[2], g.pos[3] }, rot = g.rot, size = { tx, g.size[2], g.size[3] } })
	end
	local row = finRow(M.renumber(parts))
	local cleaned = 0
	for k = #base + 1, #parts do if not row[k] then cleaned += 1 end end
	print(fmt("%s: %s | + 4 skins in its guard, labelled Blade: %d of 4 cleaned: %s", name, D(copyOf(base)), cleaned, D(parts)))
	local relabelled = copyOf(base)
	for _, p in ipairs(relabelled) do if p.slot == "Guard" and p.shape == "Block" then p.slot = "Blade" end end
	print("   its guard relabelled Blade: " .. D(relabelled))
end
-- V1's cage-flip sword
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local sword = serde.decode("json", fs.readFile(M.SCR .. "/m2x-v1-2/out/cageflip_sword.json"))
local parts = copyOf(sword.parts or sword)
local row = finRow(M.renumber(parts))
print(fmt("cage-flip sword: the Ball kept %s: %s", tostring(row[5]), D(parts)))
local truthRow = table.clone(row)
truthRow[5] = true
print("   with the Ball kept (the build before): " .. M.dline(M.emu(T, parts, truthRow)))
