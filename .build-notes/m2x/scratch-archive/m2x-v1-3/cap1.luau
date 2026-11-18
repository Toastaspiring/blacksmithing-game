--!nocheck
-- V1 (m2x, round 3): does the model's probe (δ + sag along the facet's normal) leave a thin hider's far side where the
-- true probe (δ along the radius) is still inside? A Ball under the thin end of a Wedge: what the wedge hides of the
-- ball, model against truth.
local L = require("./lib")
local fmt = string.format

local function run(r, g, t0)
	-- wedge: local −Y face down, thickness along local Y grows with local z: hy·(1 + (z − zc)/hz); hy = 0.01, hz = 0.5
	local hy, hz = 0.01, 0.5
	local zc = (1 - t0 / hy) / 2 * hz
	local yc = 2 + r + g + hy
	local parts = {
		L.part("Blade", "Ball", { 0, 2, 0 }, L.I, { 2 * r, 2 * r, 2 * r }),
		L.part("Guard", "Wedge", { 0, yc, zc }, L.I, { 0.6, 2 * hy, 2 * hz }),
	}
	L.renumber(parts)
	local P = L.prep(parts)
	local models = L.models(P)
	local share = L.readOf(P, 1, models)
	local _, _, hider = L.Oracle.flags(P)
	local truth = L.Oracle.measure(P, 1, hider, 400000)
	return 1 - share, 1 - truth
end

for _, r in ipairs({ 0.1, 0.2, 0.25, 0.3 }) do
	for _, g in ipairs({ 0, 0.002, 0.004 }) do
		for _, t0 in ipairs({ 0.008, 0.010, 0.012, 0.014 }) do
			local mh, th = run(r, g, t0)
			print(fmt("r %.2f g %.3f t0 %.3f: model hides %.3f%%, truth hides %.3f%% (model %s)", r, g, t0, 100 * mh,
				100 * th, if mh < th - 1e-4 then "UNDER" else "ok"))
		end
	end
end
