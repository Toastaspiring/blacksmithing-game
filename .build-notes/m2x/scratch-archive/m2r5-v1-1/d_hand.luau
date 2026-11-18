--!nocheck
-- Hand-built attacks on the verdict's cost: shape queries counted, no timing here. args: none
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local V = require("./v1")
local C = require("./count/Sampling")
local Sets = require("./b_sets")
local fmt = string.format
local I = V.I
local COUNT = C.COUNT

local function cost(parts)
	V.renumber(parts)
	local P = V.prep(parts)
	COUNT.sd, COUNT.aabb = 0, 0
	C.FORCE.verdictOnly = true
	local ex = C.exposure(P)
	C.FORCE.verdictOnly = nil
	return COUNT.sd, COUNT.aabb, #ex.cleaned
end

local SLOTS = { "Pommel", "Pommel", "Grip", "Grip", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade" }

-- near copies, each shifted: on each axis a different part stands out, the rest hidden by many, no single one hiding a whole patch
local function copies(size, shift, tilt)
	local parts = {}
	local R = Sets.rng(11)
	for i = 1, 24 do
		local dx, dy, dz = R.range(-shift, shift), R.range(-shift, shift), R.range(-shift, shift)
		local q = if tilt > 0 then V.axisAngle(R.range(-1, 1), R.range(-1, 1), R.range(-1, 1), R.range(-tilt, tilt)) else I
		parts[i] = V.part("x", "Block", SLOTS[i], { dx, 2.5 + dy, dz }, q, { size[1], size[2], size[3] })
	end
	return parts
end

local list = {}
for _, size in ipairs({ { 1.0, 3.5, 0.4 }, { 1.4, 4.5, 0.5 }, { 0.8, 2.5, 0.3 }, { 1.2, 4.0, 0.2 }, { 1.5, 4.8, 0.55 } }) do
	for _, shift in ipairs({ 0.015, 0.02, 0.03, 0.05, 0.08 }) do
		for _, tilt in ipairs({ 0, 0.5, 1, 2 }) do
			table.insert(list, { fmt("copies %.1f x %.1f x %.1f shift %.3f tilt %.1f", size[1], size[2], size[3], shift, tilt), copies(size, shift, tilt) })
		end
	end
end

-- rods: thin long Cylinders have the most samples per part (8 directions x 15 rows + caps), a bundle of them all near each other
local function rods(d, L, spread)
	local parts = {}
	local R = Sets.rng(7)
	for i = 1, 24 do
		local q = V.Quat.hemisphere(V.Quat.normalize(V.Quat.mul(V.axisAngle(R.range(-1, 1), 0, R.range(-1, 1), R.range(-1, 1)), V.Z90)))
		parts[i] = V.part("x", "Cylinder", SLOTS[i], { R.range(-spread, spread), 2.5, R.range(-spread, spread) }, q, { L, d, d })
	end
	return parts
end
for _, d in ipairs({ 0.03, 0.05, 0.08, 0.1, 0.15 }) do
	for _, L in ipairs({ 2, 3.5, 4.8 }) do
		for _, spread in ipairs({ 0.01, 0.02, 0.04, 0.08 }) do
			table.insert(list, { fmt("rods d %.2f L %.1f spread %.2f", d, L, spread), rods(d, L, spread) })
		end
	end
end

-- wedges and corner wedges at odd turns, nested
local function nest(shape, sx, sy, sz, tilt, spread)
	local parts = {}
	local R = Sets.rng(23)
	for i = 1, 24 do
		local q = V.axisAngle(R.range(-1, 1), R.range(-1, 1), R.range(-1, 1), R.range(-tilt, tilt))
		parts[i] = V.part("x", shape, SLOTS[i], { R.range(-spread, spread), 2.5 + R.range(-spread, spread), R.range(-spread, spread) }, q, { sx, sy, sz })
	end
	return parts
end
for _, shape in ipairs({ "Wedge", "CornerWedge", "Block" }) do
	for _, s in ipairs({ { 1.2, 4, 0.45 }, { 0.8, 3, 0.3 }, { 1.0, 1.0, 0.4 } }) do
		for _, tilt in ipairs({ 1, 3, 8 }) do
			for _, spread in ipairs({ 0.02, 0.05 }) do
				table.insert(list, { fmt("%s %.1f x %.1f x %.1f tilt %d spread %.2f", shape, s[1], s[2], s[3], tilt, spread), nest(shape, s[1], s[2], s[3], tilt, spread) })
			end
		end
	end
end

-- a brick wall: plates side by side, a layer over them crossing the seams, so that every patch needs two hiders and the near lists are long
local function bricks(nx, ny, t)
	local parts = {}
	local w, L = 1.6 / nx, 4.6 / ny
	local i = 0
	for ax = 1, nx do
		i += 1
		parts[i] = V.part("x", "Block", SLOTS[i], { -0.8 + (ax - 0.5) * w, 2.4, 0 }, I, { w + 0.02, 4.6, t })
	end
	for ay = 1, ny do
		i += 1
		parts[i] = V.part("x", "Block", SLOTS[i], { 0, 0.1 + (ay - 0.5) * L, t / 2 + 0.0 }, I, { 1.6, L + 0.02, t })
		if i >= 24 then break end
	end
	return parts
end
for _, def in ipairs({ { 12, 12, 0.2 }, { 8, 16, 0.2 }, { 16, 8, 0.2 }, { 10, 14, 0.1 }, { 6, 18, 0.25 } }) do
	table.insert(list, { fmt("bricks %d x %d t %.2f", def[1], def[2], def[3]), bricks(def[1], def[2], def[3]) })
end

table.sort(list, function(a, b) return a[1] < b[1] end)
local rows = {}
for _, it in ipairs(list) do
	local sd, aabb, cleaned = cost(it[2])
	table.insert(rows, { it[1], sd, aabb, cleaned, it[2] })
end
table.sort(rows, function(a, b) return a[2] > b[2] end)
for k = 1, math.min(25, #rows) do
	local r = rows[k]
	print(fmt("%-52s sd %7d aabb %7d cleaned %2d", r[1], r[2], r[3], r[4]))
end
-- the study's worst, for scale
local worst = serde.decode("json", fs.readFile("tree/docs/spec/prototypes/S2/verdict/worst_P.json"))
for i, d in ipairs(worst) do
	local sd, aabb, cleaned = cost(d.parts)
	print(fmt("worst_P #%d (%s): sd %7d aabb %7d cleaned %2d", i, tostring(d.from), sd, aabb, cleaned))
end
local out = {}
for k = 1, 5 do
	table.insert(out, { name = rows[k][1], parts = rows[k][5] })
end
fs.writeFile("out/d_hand.json", serde.encode("json", out))
