--!nocheck
-- a flat part read against a Ball's tip: a plate sunk in a block, its top under a frame at 0.005 but for a window w × w
-- under a Ball r whose bottom stands HIDE_OFFSET + e over the window; truly the window shows
local L = require("./lib")
local fmt = string.format
for _, r in ipairs({ 0.2, 0.3 }) do
	for _, w in ipairs({ 0.04, 0.06 }) do
		for _, e in ipairs({ 0.0005, 0.001, 0.002 }) do
			local parts = {
				L.part("Blade", "Block", { 0, -0.01, 0 }, L.I, { 0.16, 0.02, 0.16 }), -- the plate, top at y 0
				L.part("Blade", "Block", { 0, -0.05, 0 }, L.I, { 0.5, 0.1, 0.5 }), -- the block it sits in (its top at 0)
			}
			-- the plate stands on the block (its top at y −0.02), side walls 0.005 off its 4 sides
			parts[2] = L.part("Blade", "Block", { 0, -0.07, 0 }, L.I, { 0.5, 0.1, 0.5 })
			for sx = -1, 1, 2 do
				table.insert(parts, L.part("Guard", "Block", { sx * (0.08 + 0.005 + 0.01), -0.01, 0 }, L.I, { 0.02, 0.02, 0.2 }))
				table.insert(parts, L.part("Guard", "Block", { 0, -0.01, sx * (0.08 + 0.005 + 0.01) }, L.I, { 0.2, 0.02, 0.02 }))
			end
			-- the frame: 4 strips 0.005 over the plate's top, leaving a w × w window in the middle
			local t, y = 0.02, 0.005 + 0.01
			local a = (0.16 - w) / 2
			table.insert(parts, L.part("Guard", "Block", { -(w / 2 + a / 2), y, 0 }, L.I, { a, t, 0.16 }))
			table.insert(parts, L.part("Guard", "Block", { (w / 2 + a / 2), y, 0 }, L.I, { a, t, 0.16 }))
			table.insert(parts, L.part("Guard", "Block", { 0, y, -(w / 2 + a / 2) }, L.I, { w, t, a }))
			table.insert(parts, L.part("Guard", "Block", { 0, y, (w / 2 + a / 2) }, L.I, { w, t, a }))
			table.insert(parts, L.part("Pommel", "Ball", { 0, 0.012 + e + r, 0 }, L.I, { 2 * r, 2 * r, 2 * r }))
			L.renumber(parts)
			local P = L.prep(parts)
			local read = L.readOf(P, 1, L.models(P))
			local _, _, hider = L.Oracle.flags(P)
			local truth = L.Oracle.share(P, 1, hider)
			print(fmt("Ball r %.1f, window %.2f, its bottom HIDE_OFFSET + %.4f over it: the plate reads %.3f%%, truth %.3f%%", r, w, e, 100 * read, 100 * truth))
		end
	end
end
