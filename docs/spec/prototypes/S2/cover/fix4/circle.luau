--!nocheck
-- fix-4: the circle's 32-gon on the build (TREE, default "now"): a plate's top face 2.4 r wide at height h over a Ball's
-- centre (r 0.3, the Ball ranking higher), read alone against the Ball: what the Ball hides of it is the 32-gon round the
-- circle (R + EPS_GEOM)² − h² (the buried piece) or (R + EPS_GEOM)² − (h + δ)² (the probe's), whichever is larger,
-- 32·tan(π/32)·ρ²; and how far the 32-gon stands past the sphere, sqrt(h² + ρ²·sec²(π/32)) − R (its corners).
local process = require("@lune/process")
local L = require("./lab").tree(process.env.TREE or "now")
local fmt = string.format
local EPS, DELTA = L.Geo.EPS_GEOM, L.Geo.HIDE_OFFSET
local R = 0.3
local C = { 0, 2, 0 }
local ball = L.Shapes.prepare(L.part("Pommel", "Ball", C, L.I, { 2 * R, 2 * R, 2 * R }), 1)
local qm = L.Cover.model(ball)
local T32, SEC = 0.098491403357164253, 1.0048385723763145 -- tan(π/32), sec(π/32)
local worstRel = 0
for _, f in ipairs({ -0.99, -0.9, -0.5, -0.1, 0, 0.1, 0.3, 0.5, 0.7, 0.9, 0.95, 0.99, 0.999 }) do
	local h = f * R
	local plate = L.Shapes.prepare(L.part("Blade", "Block", { C[1] + 0.013, C[2] + h - 0.01, C[3] - 0.007 }, L.I, { 2.4 * R, 0.02, 2.4 * R }), 2)
	local pm = L.Cover.model(plate)
	local top = 0
	for k = 1, pm.n do
		if pm.ny[k] > 0.999 then
			top = k
		end
	end
	local b = 6 * (top - 1)
	local one = { part = plate, round = false, n = 1, poly = { pm.poly[top] }, nx = { pm.nx[top] }, ny = { pm.ny[top] }, nz = { pm.nz[top] },
		area = { pm.area[top] }, box = { pm.box[b + 1], pm.box[b + 2], pm.box[b + 3], pm.box[b + 4], pm.box[b + 5], pm.box[b + 6] },
		spread = { 0 }, flat = { true }, hull = { {} }, total = pm.area[top], np = 0, planes = {}, sag = { 0 }, inner = 0, reach = pm.reach, over = 0, work = 0 }
	local shown, used = L.Cover.shown(one, { qm }, { true }, math.huge, math.huge)
	local hidden = pm.area[top] - shown
	local RA = R + EPS
	local rhoA2 = math.max(0, RA * RA - h * h)
	local rhoB2 = math.max(0, RA * RA - (h + DELTA) * (h + DELTA))
	local rho2 = math.max(rhoA2, rhoB2)
	local want = 32 * T32 * rho2
	local hP = if rhoA2 >= rhoB2 then h else h + DELTA
	local over = math.sqrt(hP * hP + rho2 * SEC * SEC) - R
	local rel = if want > 0 then math.abs(hidden - want) / want else math.abs(hidden)
	worstRel = math.max(worstRel, rel)
	print(fmt("h %+6.3f r: hidden %.12f, 32-gon %.12f (%.2e off; the circle %.12f), its corners %.6f r past the sphere; %.1f units",
		f, hidden, want, rel, math.pi * rho2, over / R, used))
end
print(fmt("worst relative difference from the circumscribed 32-gon: %.2e; through the centre sec(π/32) − 1 = %.6f", worstRel, SEC - 1))
