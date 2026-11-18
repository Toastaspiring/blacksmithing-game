--!nocheck
-- A thin Wedge's sharp edge pointing at a face just past the probe: its half-spaces grown by EPS_GEOM stand
-- EPS/sin(θ/2) past its box, so the hide test hides a strip of the face that no box test lets through.
local L = require("./lib")
local E = require("./exactlib")
local AB = require("./arrbrute")
local fmt = string.format
local R = L.axisAngle(1, 0, 0, -90)
print("rot", R[1], R[2], R[3], R[4])
for _, def in ipairs({ { 1.0, 0.02, 0.5 }, { 3.0, 0.02, 0.5 }, { 3.0, 0.02, 6.0 }, { 1.0, 0.05, 0.5 } }) do
	local hz, thick, len = def[1], def[2], def[3]
	for _, s in ipairs({ 1e-7, 2.5e-7, 5e-7, 1e-6, 3e-6, 1e-5, 2e-5, 5e-5, 1e-4 }) do
		local apex = 0.012 + s
		local parts = {
			L.part("Blade", "Block", { 0, -0.05, 0 }, L.I, { len + 0.2, 0.1, 0.5 }),
			L.part("Blade", "Wedge", { 0, apex + hz, 0 }, R, { len, thick, 2 * hz }),
		}
		L.renumber(parts)
		local P = L.prep(parts)
		local models = L.models(P)
		local W = P[2]
		local read = L.readOf(P, 1, models)
		local aidx, ah = L.allHiders(P, 1, models)
		local am = {}
		for k, j in ipairs(aidx) do am[k] = models[j] end
		local b = AB.shown(models[1], am, ah, 0)
		local bp = AB.shown(models[1], am, ah, 1e-11)
		local bm = AB.shown(models[1], am, ah, -1e-11)
		local idx = L.hidersOf(P, 1, models)
		print(fmt("hz %.1f thick %.2f len %.1f s %.1e: W miny %.9f; hiders %d; cover %.12f, hide test %.12f [%.12f, %.12f]; missed area %.3e (%.2e of the part)",
			hz, thick, len, s, W.miny, #idx, read * models[1].total, b, bp, bm, read * models[1].total - b, (read * models[1].total - b) / models[1].total))
	end
end
