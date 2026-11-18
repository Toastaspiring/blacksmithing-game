--!nocheck
-- the largest single report Sampling.exposure makes through `spend` (Cover's stretches), on fixtures, worst designs and
-- hostile constructions: a Cylinder's 32-gon cap under Balls whose many half-spaces cut it
local L = require("./lib")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format
local function maxReport(parts)
	L.renumber(parts)
	local P = L.prep(parts)
	local mx, total = 0, 0
	local e = L.Sampling.exposure(P, function(n)
		if n > mx then mx = n end
		total += n
	end)
	return mx, e.verdictWork, e.capped
end
local overall = { 0 }
local function show(name, parts)
	local mx, vw, capped = maxReport(parts)
	if mx > overall[1] then overall = { mx, name } end
	return mx, vw, capped
end
for _, set in ipairs({ "valid", "tooComplex" }) do
	for _, d in ipairs(Worst[set]) do
		show(d.name, L.copyParts(d.parts))
	end
end
for _, list in ipairs({ L.Fx.calibration(), L.Fx.regression(), L.Fx.perf() }) do
	for _, b in ipairs(list) do
		if b.parts then show(b.name, L.copyParts(b.parts)) end
	end
end
print(fmt("fixtures and worst designs: largest single report %.1f units (%s)", overall[1], overall[2]))
-- hostile: a big Cylinder (axis Y) whose top cap is near Balls
local best = { 0 }
for _, R in ipairs({ 0.25, 0.3 }) do
	for _, rb in ipairs({ 0.04, 0.06, 0.08, 0.12, 0.2 }) do
		for _, h in ipairs({ -0.5, -0.2, 0, 0.2, 0.5, 0.8 }) do
			for _, nb in ipairs({ 1, 4, 9 }) do
				local parts = { L.part("Blade", "Cylinder", { 0, 1, 0 }, L.Z90, { 0.6, 2 * R, 2 * R }) }
				local top = 1 + 0.3
				local k = 0
				for i = 1, 3 do
					for j = 1, 3 do
						k += 1
						if k <= nb then
							local x, z = (i - 2) * R * 0.5, (j - 2) * R * 0.5
							if nb == 1 then x, z = 0, 0 end
							table.insert(parts, L.part("Guard", "Ball", { x, top + h * rb, z }, L.I, { 2 * rb, 2 * rb, 2 * rb }))
						end
					end
				end
				local mx, vw = show(fmt("cyl R %.2f, %d Balls r %.2f at %.1f r", R, nb, rb, h), parts)
				if mx > best[1] then best = { mx, R, rb, h, nb, vw } end
			end
		end
	end
end
print(fmt("hostile: largest single report %.1f units (Cylinder R %.2f, %d Balls r %.2f at %.1f r; verdict %.0f units)", best[1], best[2], best[5], best[3], best[4], best[6]))
print(fmt("overall: %.1f units (%s)", overall[1], overall[2]))
