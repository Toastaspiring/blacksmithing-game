--!nocheck
-- V1's truth against closed forms, written anew, each in whole-design turns. Then against the repo's oracle on random designs.
local T = require("./truth")
local Quat = require("./tree/src/shared/Blueprint/Quat")
local Shapes = require("./tree/src/shared/Physics/Shapes")
local Oracle = require("./tree/tests/Physics/VisibleOracle")
local fmt = string.format
local DELTA = 0.012
local PI = math.pi
local I = { 0, 0, 0, 1 }

local function axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) })
end
local TURNS = { I, axisAngle(1, 2, 3, 37), axisAngle(-2, 1, 0.5, 71), axisAngle(0, 0, 1, 22.5), axisAngle(1, 1, 0, 45), axisAngle(3, -1, 2, 113) }

local function turned(parts, q)
	local out = {}
	for i, p in ipairs(parts) do
		out[i] = { id = i, slot = "Blade", shape = p.shape, material = "Iron", pos = Quat.rotate(q, p.pos), rot = Quat.normalize(Quat.mul(q, p.rot)), size = p.size }
	end
	return out
end

local worst, worstName, count, worstU = 0, "", 0, 0
local function check(what, parts, idx, want, cell)
	local errs = {}
	for t, q in ipairs(TURNS) do
		local P = turned(parts, q)
		local S = T.solids(P)
		local hider = T.hidersOf(S)
		local got, lo, hi, cells = T.share(S, idx, hider, cell)
		local e = math.abs(got - want)
		errs[t] = fmt("%.4f", e * 100)
		if e > worst then
			worst, worstName = e, what
		end
		worstU = math.max(worstU, hi - lo)
		count += 1
	end
	print(fmt("%-52s want %8.4f %%  err pts: %s", what, want * 100, table.concat(errs, " ")))
end

local function host(c)
	return { shape = "Block", pos = { 0, c - 2, 0 }, rot = I, size = { 8, 4, 8 } }
end

for _, r in ipairs({ 0.15, 0.05 }) do
	for _, f in ipairs({ 0.99, 0.95, 0.85, 0.5, 0.2, 0, -0.5, -0.9 }) do
		local c = f * r
		-- a sphere point at height y: hidden if buried (y < c) or its probe (y (1 + d/r)) is below c: below the plane or, under c < 0, below c/(1 + d/r)
		local ce = if c >= 0 then c else c / (1 + DELTA / r)
		check(fmt("ball r %.2f, plane %.2f r", r, f), { { shape = "Ball", pos = { 0, 0, 0 }, rot = I, size = { 2 * r, 2 * r, 2 * r } }, host(c) }, 1, (r - ce) / (2 * r))
	end
end
for _, def in ipairs({ { 0.1, 1.0 }, { 0.03, 2.0 }, { 0.2, 0.05 }, { 0.01, 0.5 } }) do
	local r, L = def[1], def[2]
	for _, f in ipairs({ 0.98, 0.9, 0.7, 0.3, 0, -0.5, -0.9 }) do
		local c = f * r
		local ce = if c >= 0 then c else c / (1 + DELTA / r)
		local side = L * 2 * r * math.acos(math.clamp(ce / r, -1, 1))
		local cap = 2 * (r * r * math.acos(f) - c * math.sqrt(r * r - c * c))
		check(fmt("cylinder r %.2f L %.2f, plane %.2f r", r, L, f), { { shape = "Cylinder", pos = { 0, 0, 0 }, rot = I, size = { L, 2 * r, 2 * r } }, host(c) }, 1, (side + cap) / (2 * PI * r * L + 2 * PI * r * r))
	end
end
for _, t in ipairs({ 0.001, 0.002, 0.005, 0.02, 0.1 }) do
	local a, b, c = 0.3, 0.5, 0.04
	check(fmt("plate 0.3 x 0.5 x 0.04 sunk, %.3f out", t), { { shape = "Block", pos = { 0, t - b / 2, 0 }, rot = I, size = { a, b, c } }, host(0) }, 1, (a * c + 2 * (a + c) * t) / (2 * (a * b + a * c + b * c)))
end
for _, f in ipairs({ 0.95, 0.8, 0.5, 0, -0.5, -0.9 }) do
	local hx, hy, hz = 0.2, 0.15, 0.1
	local c = f * hy
	local s = math.sqrt(hy * hy + hz * hz)
	local total = 4 * hx * hz + 4 * hx * hy + 4 * hx * s + 4 * hy * hz
	local vis = 2 * hx * (hy - c) + (hy - c) / (2 * hy) * 4 * hx * s + 2 * hz * (hy - c) ^ 2 / (2 * hy)
	check(fmt("wedge, plane %.2f hy", f), { { shape = "Wedge", pos = { 0, 0, 0 }, rot = I, size = { 2 * hx, 2 * hy, 2 * hz } }, host(c) }, 1, vis / total)
end
-- a CornerWedge cut by a plane y = c: above it, 4 similar triangles scaled by t = (hy - c)/(2 hy)
for _, f in ipairs({ 0.9, 0.5, 0, -0.5, -0.9 }) do
	local hx, hy, hz = 0.05, 0.5, 0.05
	local c = f * hy
	local t = (hy - c) / (2 * hy)
	local l1, l2 = math.sqrt(hx * hx + hy * hy), math.sqrt(hy * hy + hz * hz)
	local side = 2 * hy * hz + 2 * hx * hy + 2 * hz * l1 + 2 * hx * l2
	local total = 4 * hx * hz + side
	check(fmt("corner wedge, plane %.2f hy", f), { { shape = "CornerWedge", pos = { 0, 0, 0 }, rot = I, size = { 2 * hx, 2 * hy, 2 * hz } }, host(c) }, 1, t * t * side / total)
end
do
	local a, b, c, o = 0.6, 0.3, 0.1, 0.2
	local pair = { { shape = "Block", pos = { -(a - o) / 2, 0, 0 }, rot = I, size = { a, b, c } }, { shape = "Block", pos = { (a - o) / 2, 0, 0 }, rot = I, size = { a, b, c } } }
	local total = 2 * (a * b + a * c + b * c)
	check("lower index keeps coincident faces, loses its end", pair, 1, (total - b * c) / total)
	check("higher index loses them and its end", pair, 2, (total - b * c - o * (2 * b + 2 * c)) / total)
end
do
	local a, b, c = 0.3, 0.1, 0.4
	local total = 2 * (a * b + a * c + b * c)
	check("plate 0.008 above a host", { { shape = "Block", pos = { 0, b / 2 + 0.008, 0 }, rot = I, size = { a, b, c } }, host(0) }, 1, (total - a * c) / total)
	check("plate 0.014 above a host", { { shape = "Block", pos = { 0, b / 2 + 0.014, 0 }, rot = I, size = { a, b, c } }, host(0) }, 1, 1)
end
-- a cylinder cap flush on a host wider than it, a lower-index host: all the cap is hidden; a cap above by 0.008: hidden by the probe; a side tangent line
do
	local r, L = 0.1, 0.4
	local total = 2 * PI * r * L + 2 * PI * r * r
	check("cylinder standing on a host, lower index first", { { shape = "Block", pos = { 0, -2, 0 }, rot = I, size = { 8, 4, 8 } }, { shape = "Cylinder", pos = { 0, L / 2, 0 }, rot = { 0, 0, 0.70710678118654757, 0.70710678118654757 }, size = { L, 2 * r, 2 * r } } }, 2, (total - PI * r * r) / total)
end
print(fmt("\n%d checks, worst error %.4f points (%s), widest certified band %.4f points", count, worst * 100, worstName, worstU * 100))

-- against the repo's oracle: random designs from the test helper's generator
local H = require("./tree/tests/Physics/PhysicsHelpers")
local TestRng = require("./tree/tests/lib/TestRng")
local rng = TestRng.new(7)
local maxDiff, n, sum = 0, 0, 0
local t0 = os.clock()
for d = 1, 40 do
	local design = H.anyDesign(rng)
	local Sh = {}
	for i, p in ipairs(design.parts) do Sh[i] = Shapes.prepare(p, i) end
	local isCopy, isDust, hider = Oracle.flags(Sh)
	local S = T.solids(design.parts)
	local h2 = T.hidersOf(S)
	for i = 1, #Sh do
		if not isCopy[i] and not isDust[i] then
			local a = Oracle.measure(Sh, i, hider, 60000)
			local b = T.share(S, i, h2, 0.001)
			n += 1
			sum += math.abs(a - b)
			if math.abs(a - b) > maxDiff then
				maxDiff = math.abs(a - b)
				print(fmt("  design %d part %d %s: oracle %.4f %%, mine %.4f %%", d, i, design.parts[i].shape, a * 100, b * 100))
			end
		end
	end
end
print(fmt("against VisibleOracle on 60,000 points: %d parts, mean |diff| %.4f points, worst %.4f points, %.1f s", n, sum / n * 100, maxDiff * 100, os.clock() - t0))
