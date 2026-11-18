--!nocheck
-- near-copy pairs (same shape, solids within T) among the fixtures, the attack designs and the plausible set
local L = require("./lib")
local Attacks = require("./repo/tests/Physics/CoverAttacks")
local Plaus = require("./repo/tests/Physics/PlausibleDesigns")
local fmt = string.format
local sqrt, abs = math.sqrt, math.abs
local function near(a, b, tol)
	if a.code ~= b.code then return false end
	if a.poly then
		local function covered(x, y)
			for i = 1, #x, 3 do
				local hit = false
				for j = 1, #y, 3 do
					local dx, dy, dz = x[i] - y[j], x[i + 1] - y[j + 1], x[i + 2] - y[j + 2]
					if dx * dx + dy * dy + dz * dz <= tol * tol then hit = true break end
				end
				if not hit then return false end
			end
			return true
		end
		return covered(a.wverts, b.wverts) and covered(b.wverts, a.wverts)
	elseif a.code == L.Shapes.CYLINDER then
		local function caps(p) return { p.cx + p.hx * p.ux, p.cy + p.hx * p.uy, p.cz + p.hx * p.uz }, { p.cx - p.hx * p.ux, p.cy - p.hx * p.uy, p.cz - p.hx * p.uz } end
		local a1, a2 = caps(a)
		local b1, b2 = caps(b)
		local function dist(x, y) return sqrt((x[1] - y[1]) ^ 2 + (x[2] - y[2]) ^ 2 + (x[3] - y[3]) ^ 2) end
		local capd = math.min(math.max(dist(a1, b1), dist(a2, b2)), math.max(dist(a1, b2), dist(a2, b1)))
		local dot = abs(a.ux * b.ux + a.uy * b.uy + a.uz * b.uz)
		local tilt = math.max(a.r, b.r) * sqrt(math.max(0, 1 - dot * dot))
		return capd + tilt + abs(a.r - b.r) <= tol
	else
		return sqrt((a.cx - b.cx) ^ 2 + (a.cy - b.cy) ^ 2 + (a.cz - b.cz) ^ 2) + abs(a.r - b.r) <= tol
	end
end
local designs = {}
for _, id in ipairs(L.Blueprints.order) do table.insert(designs, { id, L.repoFixture(id) }) end
for _, list in ipairs({ L.Fx.calibration(), L.Fx.regression(), L.Fx.perf(), L.Fx.golden(), L.Fx.adversarial(), L.Fx.validation() }) do
	for _, b in ipairs(list) do
		local f = b.fixture or b
		if f.parts then table.insert(designs, { tostring(f.name), L.copyParts(f.parts) }) end
	end
end
for _, d in ipairs(Attacks) do table.insert(designs, { "attack " .. (d.name or "?"), L.copyParts(d.parts) }) end
print("PlausibleDesigns API:", (function() local t = {} for k in pairs(Plaus) do table.insert(t, k) end table.sort(t) return table.concat(t, " ") end)())
for _, T in ipairs({ 1e-4, 1e-3, 0.01 }) do
	local hits = {}
	for _, d in ipairs(designs) do
		local P = L.prep(L.renumber(L.copyParts(d[2])))
		local n = 0
		for i = 1, #P do
			for j = i + 1, #P do
				if near(P[i], P[j], T) and not L.Shapes.sameSolid(P[i], P[j]) then n += 1 end
			end
		end
		if n > 0 then table.insert(hits, fmt("%s (%d)", d[1], n)) end
	end
	print(fmt("T %.0e: %d designs with near (not exact) copies: %s", T, #hits, table.concat(hits, "; ")))
end
