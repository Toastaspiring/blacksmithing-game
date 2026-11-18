--!nocheck
-- V1 (m2x, round 3): fixA's price. A Block inside a Ball r 0.3, its top face e past the true sphere at the +Y pole, where the
-- circumscribed polyhedron (the probe's) stands 0.026 r past the sphere: the truth shows the top face; the build's probe
-- leaves it showing; a buried piece on the circumscribed half-spaces hides it. Run beside a tree's lib.
local L = require("./lib")
local fmt = string.format

for _, e in ipairs({ 0.001, 0.002, 0.004, 0.006, 0.008 }) do
	for _, a in ipairs({ 0.04, 0.06, 0.1 }) do
		local R, len = 0.3, 0.2
		local parts = {
			L.part("Pommel", "Ball", { 0, 0.5, 0 }, L.I, { 2 * R, 2 * R, 2 * R }),
			L.part("Blade", "Block", { 0, 0.5 + R + e - len / 2, 0 }, L.I, { a, len, a }),
		}
		L.renumber(parts)
		local P = L.prep(parts)
		local share = L.readOf(P, 2, L.models(P))
		local _, _, hider = L.Oracle.flags(P)
		local truth = L.Oracle.share(P, 2, hider)
		print(fmt("block %.2f x %.2f x %.2f, top %.3f past the pole: reads %7.3f%% (%s), truth %7.3f%% (%s)", a, len, a, e,
			100 * share, if share >= 0.02 then "kept" else "cleaned", 100 * truth, if truth >= 0.02 then "kept" else "cleaned"))
	end
end
