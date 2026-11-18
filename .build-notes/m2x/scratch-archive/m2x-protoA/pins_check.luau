--!nocheck
-- A few of the failing Verdict.spec pins, rebuilt: what the new reading reads against the closed form of the true geometry (and the
-- oracle), to show the failures are pins of the old reading and not wrong answers.
local L = require("./lib")
local fmt = string.format
local EPS = 1e-7
local PLATE_AREA = 2 * 0.25 + 4 * 0.5 * 0.02
local FAR = 0.5
local function solid(id, shape, pos, rot, size) return L.part(id, shape, "Blade", pos, rot, size) end
local function partsUnder(lids)
	local parts = {
		solid(1, "Block", { 0, -0.01, 0 }, L.I, { 0.5, 0.02, 0.5 }),
		solid(2, "Block", { 0, -0.0275, 0 }, L.I, { 0.5, 0.015, 0.5 }),
		solid(3, "Block", { 0.26, -0.02, 0 }, L.I, { 0.02, 0.04, 0.54 }),
		solid(4, "Block", { -0.26, -0.02, 0 }, L.I, { 0.02, 0.04, 0.54 }),
		solid(5, "Block", { 0, -0.02, 0.26 }, L.I, { 0.5, 0.04, 0.02 }),
		solid(6, "Block", { 0, -0.02, -0.26 }, L.I, { 0.5, 0.04, 0.02 }),
	}
	for k, lid in ipairs(lids) do
		table.insert(parts, solid(6 + k, "Block", { (lid[1] + lid[2]) / 2, 0.05, (lid[3] + lid[4]) / 2 }, L.I, { lid[2] - lid[1], 0.1, lid[4] - lid[3] }))
	end
	return parts
end
local function check(name, parts, i, want)
	local P = L.prep(parts)
	local share = L.newShares(P)
	local old = L.oldVerdict(parts)
	local tr = L.truth(P)
	print(fmt("%-44s new %.6f %%  closed form %s  oracle %.4f %%  | new %s, old %s", name, share[i] * 100, if want then fmt("%.6f %%", want * 100) else "-", (tr[i] or 0) * 100,
		if share[i] >= 0.02 then "kept" else "CLEANED", if old[i] then "kept" else "CLEANED"))
end
local s = 0.008
check("ring strip 0.008 round the rim", partsUnder({ { -0.25 + s, 0.25 - s, -0.25 + s, 0.25 - s } }), 1, (0.25 - (0.5 - 2 * s + 2 * EPS) ^ 2) / PLATE_AREA)
check("strip on 3 sides", partsUnder({ { -0.25 + s, 0.25 - s, -FAR, 0.25 - s } }), 1, (0.25 - (0.5 - 2 * s + 2 * EPS) * (0.5 - s + EPS)) / PLATE_AREA)
check("hair 0.002 round the rim", partsUnder({ { -0.248, 0.248, -0.248, 0.248 } }), 1, (0.25 - (0.496 + 2 * EPS) ^ 2) / PLATE_AREA)
check("hair 0.001 round the rim (old: 0)", partsUnder({ { -0.249, 0.249, -0.249, 0.249 } }), 1, (0.25 - (0.498 + 2 * EPS) ^ 2) / PLATE_AREA)
for _, g in ipairs({ 0.03, 0.00001 }) do
	check(fmt("slit %.5f through the column", g), partsUnder({ { -FAR, 0.0625 - g / 2, -FAR, FAR }, { 0.0625 + g / 2, FAR, -FAR, FAR } }), 1, 0.5 * (g - 2 * EPS) / PLATE_AREA)
end
local x0, x1 = 0.0625 + 0.26 * 0.0625, 0.0625 + 0.74 * 0.0625
check("window between the lines (old: 0)", partsUnder({ { -FAR, x0, -FAR, FAR }, { x1, FAR, -FAR, FAR }, { x0, x1, -FAR, x0 }, { x0, x1, x1, FAR } }), 1, (x1 - x0 - 2 * EPS) ^ 2 / PLATE_AREA)
local d, gap = 0.5, 0.1
check("ball between 2 plates (old: 0)", { solid(1, "Ball", { 0, 2, 0 }, L.I, { d, d, d }), solid(2, "Block", { 0, 2 + gap / 2 + 0.15, 0 }, L.I, { 0.8, 0.3, 0.55 }), solid(3, "Block", { 0, 2 - gap / 2 - 0.15, 0 }, L.I, { 0.8, 0.3, 0.55 }) }, 1, nil)
