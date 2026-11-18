--!nocheck
-- a flat part read against a Ball's tip: a plate standing on a block, walls 0.005 off its sides, a frame 0.005 over its top
-- but for a window w × w, a Ball r whose bottom stands HIDE_OFFSET + e over the window (truly the window shows)
local L = require("./lib")
local fmt = string.format
local function design(r, w, e)
	local parts = {
		L.part("Blade", "Block", { 0, -0.01, 0 }, L.I, { 0.16, 0.02, 0.16 }), -- the plate, top at y 0
		L.part("Blade", "Block", { 0, -0.07, 0 }, L.I, { 0.5, 0.1, 0.5 }), -- the block under it
	}
	for sx = -1, 1, 2 do
		table.insert(parts, L.part("Guard", "Block", { sx * (0.08 + 0.005 + 0.02), -0.01, 0 }, L.I, { 0.04, 0.04, 0.26 }))
		table.insert(parts, L.part("Guard", "Block", { 0, -0.01, sx * (0.08 + 0.005 + 0.02) }, L.I, { 0.26, 0.04, 0.04 }))
	end
	local a = (0.16 - w) / 2
	for sz = -1, 1, 2 do -- full-width strips over the window's two sides in z
		table.insert(parts, L.part("Guard", "Block", { 0, 0.005 + 0.02, sz * (w / 2 + a / 2) }, L.I, { 0.16, 0.04, a }))
	end
	for sx = -1, 1, 2 do -- the window's two sides in x, tall enough not to be Dust
		table.insert(parts, L.part("Guard", "Block", { sx * (w / 2 + a / 2), 0.005 + 0.05, 0 }, L.I, { a, 0.1, w }))
	end
	table.insert(parts, L.part("Pommel", "Ball", { 0, 0.012 + e + r, 0 }, L.I, { 2 * r, 2 * r, 2 * r }))
	return L.renumber(parts)
end
for _, r in ipairs({ 0.2, 0.3 }) do
	for _, w in ipairs({ 0.03, 0.05 }) do
		for _, e in ipairs({ 0.0005, 0.002 }) do
			local P = L.prep(design(r, w, e))
			local models = L.models(P)
			local idx = L.hidersOf(P, 1, models)
			local read = L.readOf(P, 1, models)
			local _, _, hider = L.Oracle.flags(P)
			local truth = L.Oracle.share(P, 1, hider)
			print(fmt("Ball r %.1f, window %.2f, its bottom HIDE_OFFSET + %.4f over it: %d hiders; the plate reads %.3f%%, truth %.3f%%", r, w, e, #idx, 100 * read, 100 * truth))
		end
	end
end
