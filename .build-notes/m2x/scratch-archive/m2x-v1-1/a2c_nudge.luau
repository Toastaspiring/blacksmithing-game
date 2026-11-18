--!nocheck
-- A2c: a copy of F3's blade nudged by a hair below it (cy smaller), in the Guard: it ranks above the blade by where it
-- stands, so the blade's faces, coincident to EPS, are its: the blade is cleaned (in the truth as in the build)
local L = require("./lib")
local fmt = string.format
local base = L.repoFixture("F3")
local R0 = L.emu(L.copyParts(base))
for _, dy in ipairs({ -1e-12, -1e-10, -1e-8, -5e-8 }) do
	local parts = L.copyParts(base)
	local c = L.copyPart(base[6])
	c.slot = "Guard"
	c.pos = { c.pos[1], c.pos[2] + dy, c.pos[3] }
	table.insert(parts, c)
	L.renumber(parts)
	local P = L.prep(parts)
	local e = L.Sampling.exposure(P)
	local _, _, h = L.Oracle.flags(P)
	local t6 = L.Oracle.share(P, 6, h)
	local R = L.emu(L.copyParts(parts))
	local d, t = L.dDiff(R0, R)
	print(fmt("F3 + its blade %.0e lower, in the Guard: blade %s (reads %.3f%%, truth %.3f%%)  %s  |dD| %.4f flip %s", dy, e.kept[6] and "kept" or "CLEANED", 100 * L.readOf(P, 6), 100 * t6, L.dline(R), d, tostring(t)))
end
