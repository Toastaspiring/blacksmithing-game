--!nocheck
-- V1 (m2x, round 3): a Ball buried in a block but for its top cap (height c), the cap under the thin end of a Wedge
-- (gap g over the pole, thickness t0 there). The truth hides the cap when δ reaches the wedge from the rim and stays in it
-- at the pole; the model probes δ + sag along a facet's normal, which may leave the wedge's top near the pole.
local L = require("./lib")
local fmt = string.format

local function design(r, c, g, t0, rotDeg)
	local hy, hz = 0.01, 0.5
	local zc = (1 - t0 / hy) / 2 * hz
	local cy = 2
	local parts = {
		L.part("Blade", "Ball", { 0, cy, 0 }, if rotDeg then L.axisAngle(0.3, 1, 0.2, rotDeg) else L.I, { 2 * r, 2 * r, 2 * r }),
		-- the core: top face at cy + r − c, sides far out, bottom far below
		L.part("Guard", "Block", { 0, cy + (r - c - (r + 0.1)) / 2, 0 }, L.I, { 2 * r + 0.2, 2 * r + 0.1 - c, 2 * r + 0.2 }),
		L.part("Guard", "Wedge", { 0, cy + r + g + hy, zc }, L.I, { 0.6, 2 * hy, 2 * hz }),
	}
	return L.renumber(parts)
end

local function run(r, c, g, t0, rotDeg)
	local parts = design(r, c, g, t0, rotDeg)
	local P = L.prep(parts)
	local models = L.models(P)
	local share = L.readOf(P, 1, models)
	local _, _, hider = L.Oracle.flags(P)
	local truth = L.Oracle.measure(P, 1, hider, 400000)
	return share, truth
end

for _, r in ipairs({ 0.15, 0.2, 0.25, 0.3 }) do
	for _, c in ipairs({ 0.004, 0.008 }) do
		for _, g in ipairs({ 0, 0.002 }) do
			for _, t0 in ipairs({ 0.012, 0.013, 0.015 }) do
				local s, t = run(r, c, g, t0)
				print(fmt("r %.2f c %.3f g %.3f t0 %.3f: model shows %.4f%%, truth %.4f%%%s", r, c, g, t0, 100 * s, 100 * t,
					if s > t + 1e-4 then "  MODEL OVER" else ""))
			end
		end
	end
end
