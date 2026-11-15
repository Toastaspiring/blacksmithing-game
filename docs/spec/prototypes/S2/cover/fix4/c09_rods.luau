--!nocheck
-- fix-4: V1's script (m2x-v1-4) on a named tree: TREE=<name> (lab.luau; default "now").
local TREE = require("@lune/process").env.TREE or "now"
-- V1 (m2x, round 4): C09 (Sharpening 0.1904 Normal, 0.0096 under Hard) plus k Blade rods inside its grip Cylinder
-- (r 0.075 along Y, y 0.43–1.33), along its side e under it, their tops in the guard Block (y 1.32–1.50): truly hidden
-- (every point in the grip or the guard), round filler reaching another part. The build's reading, the truth, and D on
-- the build's verdicts against the truth's row.
--   lune run c09_rods -- <k> <e> <rod r> <len> [side]
local process = require("@lune/process")
local L = require("./lab").tree(TREE)
local fmt = string.format
local K = tonumber(process.args[1]) or 4
local e = tonumber(process.args[2]) or 0.0002
local rr = tonumber(process.args[3]) or 0.025
local len = tonumber(process.args[4]) or 0.4
local side = process.args[5] or "one"

local parts = L.fixture("C09")
local base = L.copyParts(parts)
local top = 1.36 -- the rods' tops, inside the guard (y ≥ 1.32)
for k = 1, K do
	-- angles round the grip on the +x side (one), or all round (all)
	local a = if side == "one" then math.rad(-60 + 120 * (k - 1) / math.max(K - 1, 1)) else 2 * math.pi * (k - 1) / K
	local d = 0.075 - rr - e
	table.insert(parts, L.part("Blade", "Cylinder", { d * math.cos(a), top - len / 2, d * math.sin(a) }, L.Z90, { len, 2 * rr, 2 * rr }))
end
L.renumber(parts)
local Rr = L.run(L.copyParts(parts), { measureInvalid = false })
print("valid:", Rr.validation.ok, L.codes(Rr), "canonical:", L.canonical(L.copyParts(parts)))
local P = L.prep(parts)
local reads = L.readAll(P)
local truth = L.truthAll(P)
local kept = L.Sampling.exposure(P).kept
for i = 19, #parts do
	print(fmt("%2d %-6s %-8s reads %8s (%s), truth %8s", i, parts[i].slot, parts[i].shape, L.pct(reads[i]), if kept[i] then "kept" else "cleaned", L.pct(truth[i])))
end
-- each rod lies in the union of the grip (3) and the guard (7)
for i = 19, #P do
	local p = P[i]
	local worst = -math.huge
	for a = 0, 359 do
		local c, s = math.cos(math.rad(a)), math.sin(math.rad(a))
		for k = 0, 80 do
			local x, y, z = L.Shapes.toWorld(p, -p.hx + 2 * p.hx * k / 80, p.r * c, p.r * s)
			local m = math.huge
			for _, j in ipairs({ 3, 4, 5, 6, 7 }) do
				m = math.min(m, L.Shapes.sd(P[j], x, y, z))
			end
			worst = math.max(worst, m)
		end
	end
	print(fmt("rod %d: the largest distance of its side out of the grip, rings and guard %.6f", i, worst))
end
L.renumber(base)
print("D C09:            ", L.dline(L.emu(base, nil)))
local Db, Dt = L.emu(L.copyParts(parts), nil), L.emu(L.copyParts(parts), L.truthRow(truth))
print("D build:          ", L.dline(Db))
print("D truth's row:    ", L.dline(Dt))
local w, tier, step = L.dDiff(Db, Dt)
print(fmt("|dD| %.4f on %s, tier flip %s", w, step, tostring(tier)))
