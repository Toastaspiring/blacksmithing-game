--!nocheck
-- V1 (m2x, round 3): a fixture as it is, plus Blade blocks wholly inside one of its Balls, their outer faces in the Ball's
-- sag band along (1, ±1, ±1)/√3. Usage: band_fx.luau -- <fixture> <ball part> <count 1..4> [e] [a] [len]
local L = require("./lib")
local process = require("@lune/process")
local fmt = string.format

local S3 = 1 / math.sqrt(3)
local DIRS = { { S3, -S3, S3 }, { S3, -S3, -S3 }, { S3, S3, S3 }, { S3, S3, -S3 } }

local function blockAlong(c, d, rOuter, len, a, slot)
	local rot = L.axisAngle(d[3], 0, -d[1], math.deg(math.acos(d[2])))
	local k = rOuter - len / 2
	return L.part(slot, "Block", { c[1] + k * d[1], c[2] + k * d[2], c[3] + k * d[3] }, rot, { a, len, a })
end

local name, bi, count = process.args[1] or "C09", tonumber(process.args[2] or "1"), tonumber(process.args[3] or "2")
local base = L.fixture(name)
local ball = base[bi]
assert(ball.shape == "Ball", "not a Ball")
local r = math.min(ball.size[1], ball.size[2], ball.size[3]) / 2
local e = tonumber(process.args[4] or "") or 0.55 * 0.0572 * r -- inside the true sphere, outside the model's facet
-- the largest square face at depth e that stays 0.0005 inside the sphere
local a = tonumber(process.args[5] or "") or math.floor(math.sqrt(2 * ((r - 0.0005) ^ 2 - (r - e) ^ 2)) * 1000) / 1000
local len = tonumber(process.args[6] or "") or math.floor((2 * r - e - 0.03) * 1000) / 1000
local parts = L.copyParts(base)
for k = 1, count do
	table.insert(parts, blockAlong(ball.pos, DIRS[k], r - e, len, a, "Blade"))
end
L.renumber(parts)
print(fmt("%s + %d Blade blocks %.3f x %.3f x %.3f inside part %d (Ball r %.3f), outer faces %.4f deep", name, count, a,
	len, a, bi, r, e))
print("canonical:", L.canonical(parts))
local R = L.run(L.copyParts(parts), { measureInvalid = false })
print("valid:", R.validation.ok, L.codes(R), "units", R.budget and "" or "")
local P = L.prep(parts)
local reads = L.readAll(P)
local truth = L.truthAll(P)
local keptB = R.physics and R.physics.kept or {}
for i = #base + 1, #parts do
	local worst = -math.huge
	for j = 1, #P[i].wverts, 3 do
		local v = P[i].wverts
		worst = math.max(worst, L.Shapes.sd(P[bi], v[j], v[j + 1], v[j + 2]))
	end
	print(fmt("  hidden %2d: build reads %s (%s), truth %s; deepest... its farthest corner %.4f inside the Ball", i,
		L.pct(reads[i]), if keptB[i] then "kept" else "cleaned", L.pct(truth[i]), -worst))
end
local Rb = L.emu(L.copyParts(parts), nil)
local Rt = L.emu(L.copyParts(parts), L.truthRow(truth))
local R0 = L.emu(L.copyParts(base), nil)
print("D fixture alone: ", L.dline(R0))
print("D build:         ", L.dline(Rb))
print("D truth's row:   ", L.dline(Rt))
local w, tier, step = L.dDiff(Rb, Rt)
print(fmt("|dD| build - truth %.4f on %s, tier flip %s", w, step, tostring(tier)))
