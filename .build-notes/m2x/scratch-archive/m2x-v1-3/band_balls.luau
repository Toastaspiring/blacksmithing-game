--!nocheck
-- V1 (m2x, round 3): F5 with a pommel Ball r 0.3 holding small Blade Balls wholly inside it, each against the pommel's true
-- surface by `e` along (1, ±1, ±1)/√3 (within the pommel's sag band there): a round filler in a round hider's band.
-- Usage: band_balls.luau -- <r> <e> <count 1..4>
local L = require("./lib")
local process = require("@lune/process")
local fmt = string.format

local S3 = 1 / math.sqrt(3)
local DIRS = { { S3, -S3, S3 }, { S3, -S3, -S3 }, { S3, S3, S3 }, { S3, S3, -S3 } }
local r, e, count = tonumber(process.args[1] or "0.06"), tonumber(process.args[2] or "0.002"), tonumber(process.args[3] or "4")
local R = 0.3
local base = L.fixture("F5")
base[1] = L.part("Pommel", "Ball", { 0, R, 0 }, L.I, { 2 * R, 2 * R, 2 * R })
local parts = L.copyParts(base)
for k = 1, count do
	local d = DIRS[k]
	local s = R - e - r
	table.insert(parts, L.part("Blade", "Ball", { s * d[1], R + s * d[2], s * d[3] }, L.I, { 2 * r, 2 * r, 2 * r }))
end
L.renumber(parts)
print("canonical:", L.canonical(parts))
local Rv = L.run(L.copyParts(parts), { measureInvalid = false })
print("valid:", Rv.validation.ok, L.codes(Rv))
local P = L.prep(parts)
local reads = L.readAll(P)
local truth = L.truthAll(P)
for i = #base + 1, #parts do
	print(fmt("  hidden Ball %d: reads %s, truth %s", i, L.pct(reads[i]), L.pct(truth[i])))
end
local Rb = L.emu(L.copyParts(parts), nil)
local Rt = L.emu(L.copyParts(parts), L.truthRow(truth))
print("D build:       ", L.dline(Rb))
print("D truth's row: ", L.dline(Rt))
local w, tier, step = L.dDiff(Rb, Rt)
print(fmt("|dD| %.4f on %s, tier flip %s", w, step, tostring(tier)))
