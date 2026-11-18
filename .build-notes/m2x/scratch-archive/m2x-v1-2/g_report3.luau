--!nocheck
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
for _, R in ipairs({ 0.15, 0.2, 0.25, 0.3 }) do
	for _, poke in ipairs({ 0.002, 0.004, 0.006 }) do
		for _, rb in ipairs({ 0.01, 0.015, 0.02, 0.025, 0.03, 0.035, 0.04, 0.045, 0.05 }) do
			for _, h in ipairs({ -0.3, -0.15, -0.05, 0, 0.05, 0.15, 0.3 }) do
				for _, off in ipairs({ 0, 0.3, 0.6 }) do
					local top = 1.3 + poke
					local parts = {
						L.part("Blade", "Block", { 0, 1, 0 }, L.I, { 0.7, 0.6, 0.65 }),
						L.part("Blade", "Cylinder", { 0, 1 + poke, 0 }, L.Z90, { 0.6, 2 * R, 2 * R }),
						L.part("Guard", "Ball", { off * R, top + h * rb, 0.3 * off * R }, L.I, { 2 * rb, 2 * rb, 2 * rb }),
					}
					local mx, vw = maxReport(parts)
					if mx > best[1] then best = { mx, R, poke, rb, h, off, vw } end
				end
			end
		end
	end
end
print(fmt("largest single report %.1f units: Cylinder R %.2f proud %.3f, a Ball r %.3f at %.2f r, off-centre %.1f R (verdict %.0f units)", best[1], best[2], best[3], best[4], best[5], best[6], best[7]))
