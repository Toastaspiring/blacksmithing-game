--!nocheck
-- a round HIDER's probe half-spaces, moved out to its true surface, meet beyond it: 0.026 r past a Ball's box at its 6 axis
-- tips. A plate whose top face stands g past HIDE_OFFSET under a Ball's tip (truly nothing hides it there): how much of
-- the plate's model reads hidden, and its truth
local L = require("./lib")
local fmt = string.format
for _, r in ipairs({ 0.1, 0.2, 0.3 }) do
	for _, extra in ipairs({ 0.0005, 0.001, 0.002, 0.004 }) do
		local g = 0.012 + extra
		local parts = {
			L.part("Guard", "Block", { 0, -0.01, 0 }, L.I, { 0.16, 0.02, 0.16 }),
			L.part("Pommel", "Ball", { 0, g + r, 0 }, L.I, { 2 * r, 2 * r, 2 * r }),
		}
		L.renumber(parts)
		local P = L.prep(parts)
		local read = L.readOf(P, 1, L.models(P))
		local _, _, hider = L.Oracle.flags(P)
		local truth = L.Oracle.share(P, 1, hider)
		print(fmt("Ball r %.1f, the plate's top %.4f under its tip (HIDE_OFFSET + %.4f; tip past the box %.4f): plate reads %.3f%%, truth %.3f%% (top face %.1f%% of the plate)",
			r, g, extra, 0.026 * r, 100 * read, 100 * truth, 100 * 0.0256 / (2 * 0.0256 + 4 * 0.0032)))
	end
end
