--!nocheck
-- fix-4: V1's script (m2x-v1-4) on a named tree: TREE=<name> (lab.luau; default "now").
local TREE = require("@lune/process").env.TREE or "now"
-- V1 (m2x, round 4): a tier that truly hidden round filler moves. F5 with its pommel a Ball 0.6 across (Verdict.spec's
-- band case) and its blade 0.25 longer (a real edit: Sharpening 0.1827 Normal), plus 4 Blade rods r 0.0433 × 0.137
-- in the crease where the grip Block enters the pommel, on the +x side: each lies in the union of the pommel and the
-- grip (every point of its surface buried in one of them), so the truth reads 0 and cleans them. The build keeps them.
-- Canonicalized through Blueprint/Canonical; the design is printed as Luau literals (17 significant digits).
local L = require("./lab").tree(TREE)
local fmt = string.format

local R, GROW = 0.3, 0.25
local PC = { 0, R, 0 }
local ROD = { { 0.091440, 0.529981, -0.038118 }, { 0.13697, 0.08655, 0.08655 }, { 0.000000, 0.063277, 0.974090, 0.217127 } }

local parts = L.repoFixture("F5")
parts[1] = L.part("Pommel", "Ball", PC, L.I, { 2 * R, 2 * R, 2 * R })
parts[4].size[2] += GROW
parts[4].pos[2] += GROW / 2
parts[5].pos[2] += GROW
local function turned(t)
	local x, z = ROD[1][1], ROD[1][3]
	local q = ROD[3]
	for _ = 1, t do
		x, z = z, -x
		q = L.Quat.hemisphere(L.Quat.normalize(L.Quat.mul(L.axisAngle(0, 1, 0, 90), q)))
	end
	return L.part("Blade", "Cylinder", { x, ROD[1][2], z }, q, ROD[2])
end
for t = 0, 3 do
	local p = turned(t)
	if p.pos[1] > 0 then
		table.insert(parts, p)
		table.insert(parts, L.Mirror.reflect(L.copyPart(p), "Z"))
	end
end
L.renumber(parts)
local draft = L.Canonical.draft({ schema = 1, name = "crease", type = "Sword", parts = L.copyParts(parts) })
assert(draft.ok, "canonical")
parts = draft.value.parts
print("canonical:", L.Canonical.isCanonical({ schema = 1, name = "crease", type = "Sword", parts = parts }))
local Rr = L.run(L.copyParts(parts), { measureInvalid = false })
print("valid:", Rr.validation.ok, L.codes(Rr))
local P = L.prep(parts)
local reads = L.readAll(P)
local _, _, hider = L.Oracle.flags(P)
local kept = L.Sampling.exposure(P).kept
for i = 1, #parts do
	local t = if hider[i] then L.Oracle.measure(P, i, hider, if i >= 6 then 400000 else 40000) else false
	print(fmt("%2d %-6s %-8s reads %8s (%s), truth %8s on %s points", i, parts[i].slot, parts[i].shape, L.pct(reads[i]),
		if kept[i] then "kept" else "cleaned", L.pct(t), if i >= 6 then "400,000" else "40,000"))
end
-- every point of each rod's surface lies inside the pommel or the grip: the largest min(sd_pommel, sd_grip) over a fine
-- grid of the rod's surface (side and caps)
for i = 6, #P do
	local p = P[i]
	local worst = -math.huge
	local function at(lx, ly, lz)
		local x, y, z = L.Shapes.toWorld(p, lx, ly, lz)
		worst = math.max(worst, math.min(L.Shapes.sd(P[1], x, y, z), L.Shapes.sd(P[2], x, y, z)))
	end
	for a = 0, 719 do
		local c, s = math.cos(a * math.pi / 360), math.sin(a * math.pi / 360)
		for k = 0, 100 do
			at(-p.hx + 2 * p.hx * k / 100, p.r * c, p.r * s)
		end
		for k = 0, 50 do
			at(p.hx, p.r * c * k / 50, p.r * s * k / 50)
			at(-p.hx, p.r * c * k / 50, p.r * s * k / 50)
		end
	end
	print(fmt("rod %d: the largest min(sd pommel, sd grip) over its surface %.6f (< 0: buried in the union)", i, worst))
end
local Db = L.emu(L.copyParts(parts), nil)
local truthRow = {}
for i = 1, #parts do
	truthRow[i] = i <= 5
end
local Dt = L.emu(L.copyParts(parts), truthRow)
local base = {}
for i = 1, 5 do
	base[i] = L.copyPart(parts[i])
end
print("D without the rods:", L.dline(L.emu(base, nil)))
print("D build:           ", L.dline(Db))
print("D truth's row:     ", L.dline(Dt))
local w, tier, step = L.dDiff(Db, Dt)
print(fmt("|dD| %.4f on %s, tier flip %s", w, step, tostring(tier)))
for i = 6, #parts do
	local p = parts[i]
	print(fmt('\t{ slot = "Blade", shape = "Cylinder", material = "Iron", pos = { %.17g, %.17g, %.17g }, rot = { %.17g, %.17g, %.17g, %.17g }, size = { %.17g, %.17g, %.17g } },',
		p.pos[1], p.pos[2], p.pos[3], p.rot[1], p.rot[2], p.rot[3], p.rot[4], p.size[1], p.size[2], p.size[3]))
end
