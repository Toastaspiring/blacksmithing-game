--!nocheck
-- V1 (m2x, round 3): F5 with a pommel Ball r 0.3 holding hidden Blade blocks whose outer faces sit in the Ball's sag band
-- (inside the true sphere by e, outside the inscribed model, facing out along (1, ±1, ±1)). The truth buries them; the
-- build reads their outer faces as showing and keeps them, so Sharpening's work set gains hidden metal.
local L = require("./lib")
local process = require("@lune/process")
local fmt = string.format

local S3 = 1 / math.sqrt(3)

local function blockAlong(c, d, rOuter, len, a, slot)
	local ax, az = d[3], -d[1] -- (0, 1, 0) × d
	local rot = L.axisAngle(ax, 0, az, math.deg(math.acos(d[2])))
	local k = rOuter - len / 2
	return L.part(slot, "Block", { c[1] + k * d[1], c[2] + k * d[2], c[3] + k * d[3] }, rot, { a, len, a })
end

local function design(opts)
	local parts = L.fixture("F5")
	local r = opts.r or 0.3
	local c = { 0, r, 0 }
	parts[1] = L.part("Pommel", "Ball", c, L.I, { 2 * r, 2 * r, 2 * r })
	for _, d in ipairs(opts.dirs) do
		table.insert(parts, blockAlong(c, d, r - opts.e, opts.len, opts.a, opts.slot or "Blade"))
	end
	return L.renumber(parts)
end

local dirsX = { { S3, S3, S3 }, { S3, -S3, S3 }, { S3, S3, -S3 }, { S3, -S3, -S3 } }
local which = process.args[1] or "x4"
local opts = { e = 0.011, len = 0.2, a = 0.1, dirs = dirsX }
if which == "x2" then
	opts.dirs = { dirsX[2], dirsX[4] }
elseif which == "x1" then
	opts.dirs = { dirsX[2] }
end

local parts = design(opts)
print("canonical:", L.canonical(parts))
local R = L.run(L.copyParts(parts), { measureInvalid = false })
print("valid:", R.validation.ok, L.codes(R))
local P = L.prep(parts)
local reads = L.readAll(P)
local truth = L.truthAll(P)
local keptB = R.physics and R.physics.kept or {}
for i = 1, #parts do
	print(fmt("%2d %-6s %-6s build reads %s (%s), truth %s (%s)", i, parts[i].slot, parts[i].shape, L.pct(reads[i]),
		if keptB[i] then "kept" else "cleaned", L.pct(truth[i]),
		if truth[i] and truth[i] >= 0.02 then "kept" else "cleaned"))
end
local Rb = L.emu(L.copyParts(parts), nil)
local Rt = L.emu(L.copyParts(parts), L.truthRow(truth))
print("D build:", L.dline(Rb))
print("D truth:", L.dline(Rt))
local base = L.fixture("F5")
base[1] = L.part("Pommel", "Ball", { 0, opts.r or 0.3, 0 }, L.I, { 0.6, 0.6, 0.6 })
print("D base (no hidden):", L.dline(L.emu(L.renumber(base), nil)))
local w, tier, step = L.dDiff(Rb, Rt)
print(fmt("|dD| %.4f on %s, tier flip %s", w, step, tostring(tier)))
