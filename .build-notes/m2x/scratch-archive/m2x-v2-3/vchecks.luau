--!nocheck
-- V2 round 3: numbers Verdict.spec's comments quote, and the copies-of-a-blade case against its closed form.
local R = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3/repo"
local H = require(R .. "/tests/Physics/PhysicsHelpers")
local Oracle = require(R .. "/tests/Physics/VisibleOracle")
local Sampling = require(R .. "/src/shared/Physics/Sampling")
local fmt = string.format
local EPS = 1e-7
-- the bead
local d, gap = 0.5, 0.1
local bead = H.prepared({ parts = {
	H.solid(1, "Ball", { 0, 2, 0 }, H.I, { d, d, d }),
	H.solid(2, "Block", { 0, 2 + gap / 2 + 0.15, 0 }, H.I, { 0.8, 0.3, 0.55 }),
	H.solid(3, "Block", { 0, 2 - gap / 2 - 0.15, 0 }, H.I, { 0.8, 0.3, 0.55 }),
} })
local _, _, hider = Oracle.flags(bead)
print(fmt("bead: reads %.4f %%, truth %.4f %%", 100 * H.reads(bead, 1), 100 * Oracle.share(bead, 1, hider)))
-- F5 + 6 copies of its blade at z = k·0.002
local design = H.f("F5")
local blade = design.parts[4]
for k = 1, 6 do
	table.insert(design.parts, H.part(10 + k, "Blade", "Block", "Iron", { blade.pos[1], blade.pos[2], k * 0.002 }, H.I, blade.size))
end
local list = H.prepared(design)
local sx, sy, sz = blade.size[1], blade.size[2], blade.size[3]
local area = 2 * (sx * sy + sx * sz + sy * sz)
print(fmt("blade %s at %s", table.concat(blade.size, " × "), table.concat(blade.pos, ", ")))
local _, _, hid = Oracle.flags(list)
for k = 1, 6 do
	local i = #design.parts - 6 + k
	local share = H.reads(list, i)
	print(fmt("copy %d: reads %.9f (%.6f stud², the strip's (2·%g + %g)·(0.002 − EPS) = %.6f), truth %.5f", k, share, share * area,
		sy, sx, (2 * sy + sx) * (0.002 - EPS), Oracle.share(list, i, hid)))
end
print("kept:", table.concat((function() local t = {} for i = 1, #list do t[i] = Sampling.exposure(list).kept[i] and "K" or "E" end return t end)(), ""))
