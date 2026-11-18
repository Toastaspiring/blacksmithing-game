--!nocheck
-- a valid sword holding the single-report maximiser; search the Ball's size, place and slot for the largest report, then
-- the checkpoint gaps of Analyze.run (median of 15) on the worst
local L = require("./lib")
local fmt = string.format
local function build(R, poke, rb, h, slot, bx)
	local base = L.repoFixture("F5")
	local parts = { base[1], base[2], base[3] }
	local y0 = 1.38
	table.insert(parts, L.part("Blade", "Block", { 0, y0 + 0.3, 0 }, L.I, { 0.7, 0.6, 0.58 }))
	table.insert(parts, L.part("Blade", "Cylinder", { 0, y0 + 0.3 + poke, 0 }, L.Z90, { 0.6, 2 * R, 2 * R }))
	table.insert(parts, L.part(slot, "Ball", { 0, y0 + 0.6 + poke + h * rb, 0 }, L.I, { 2 * rb, 2 * rb, 2 * rb }))
	table.insert(parts, L.part("Blade", "Block", { bx, y0 + 0.6 + 1.2, 0 }, L.I, { 0.16, 2.4, 0.06 }))
	return L.renumber(parts)
end
local best = { 0 }
for _, R in ipairs({ 0.15, 0.2, 0.25 }) do
	for _, poke in ipairs({ 0.004, 0.006 }) do
		for _, rb in ipairs({ 0.03, 0.04, 0.05 }) do
			for _, h in ipairs({ -0.05, 0, 0.05 }) do
				for _, slot in ipairs({ "Guard", "Blade", "Pommel" }) do
					local parts = build(R, poke, rb, h, slot, 0.27)
					local P = L.prep(parts)
					local mx = 0
					L.Sampling.exposure(P, function(n) if n > mx then mx = n end end)
					if mx > best[1] then
						local r = L.run(L.copyParts(parts), { measureInvalid = false })
						if r.validation.ok then best = { mx, R, poke, rb, h, slot } end
					end
				end
			end
		end
	end
end
print(fmt("valid sword: largest single report %.1f units (R %.2f, proud %.3f, Ball r %.2f at %.2f r, %s)", best[1], best[2], best[3], best[4], best[5], best[6]))
local parts = build(best[2], best[3], best[4], best[5], best[6], 0.27)
local core = { schema = 1, name = "x", type = "Sword", parts = parts }
local gaps = {}
for k = 1, 15 do
	local last = os.clock()
	local worst = 0
	L.Analyze.run(core, { checkpoint = function()
		local now = os.clock()
		if now - last > worst then worst = now - last end
		last = now
	end })
	table.insert(gaps, worst * 1000)
end
table.sort(gaps)
print(fmt("checkpoint gaps, the longest per run (ms): median %.3f (min %.3f, max %.3f)", gaps[8], gaps[1], gaps[15]))
