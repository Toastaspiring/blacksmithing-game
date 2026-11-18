--!nocheck
-- a Cylinder sunk in a Block, its cap just proud of the Block's top, small Balls on the cap: the cap facet (32 vertices)
-- against Ball hiders (128 half-spaces): how large one report gets
local L = require("./lib")
local fmt = string.format
local function maxReport(parts)
	L.renumber(parts)
	local P = L.prep(parts)
	local mx = 0
	local e = L.Sampling.exposure(P, function(n)
		if n > mx then mx = n end
	end)
	return mx, e.verdictWork, e
end
local best = { 0 }
for _, R in ipairs({ 0.2, 0.28 }) do
	for _, poke in ipairs({ 0.001, 0.004 }) do
		for _, rb in ipairs({ 0.02, 0.03, 0.04, 0.06, 0.1 }) do
			for _, h in ipairs({ -0.9, -0.5, 0, 0.5, 0.9, 1.0 }) do
				for _, nb in ipairs({ 1, 3, 5 }) do
					local top = 1.3 + poke
					local parts = {
						L.part("Blade", "Block", { 0, 1, 0 }, L.I, { 0.7, 0.6, 0.6 }),
						L.part("Blade", "Cylinder", { 0, 1 + poke, 0 }, L.Z90, { 0.6, 2 * R, 2 * R }),
					}
					for k = 1, nb do
						local ang = 2 * math.pi * k / nb
						local x, z = 0.5 * R * math.cos(ang), 0.5 * R * math.sin(ang)
						if nb == 1 then x, z = 0, 0 end
						table.insert(parts, L.part("Guard", "Ball", { x, top + h * rb, z }, L.I, { 2 * rb, 2 * rb, 2 * rb }))
					end
					local mx, vw = maxReport(parts)
					if mx > best[1] then best = { mx, R, poke, rb, h, nb, vw } end
				end
			end
		end
	end
end
print(fmt("largest single report %.1f units: Cylinder R %.2f proud %.3f, %d Balls r %.2f at %.1f r (verdict %.0f units)", best[1], best[2], best[3], best[6], best[4], best[5], best[7]))
