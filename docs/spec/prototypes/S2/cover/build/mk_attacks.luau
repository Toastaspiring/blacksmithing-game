--!nocheck
-- The attack designs of Cover.spec (c), rebuilt from the scripts that found them (the judge's atk_chain_sword.luau and
-- atk_model.luau; the verifiers' x_lattice.luau, a_hand.luau, a_void.luau), with each target's truth (VisibleOracle, its fine
-- lattice) and what the build reads. Writes tests/Physics/CoverAttacks.luau: Luau literals, 17 significant digits.
-- args: outfile
local process = require("@lune/process")
local fs = require("@lune/fs")
local L = require("./lib")
local fmt = string.format
local I = { 0, 0, 0, 1 }
local Z90 = { 0, 0, 0.70710678118654757, 0.70710678118654757 }
local OUT = process.args[1] or "../out/CoverAttacks.luau"

local function axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return L.Quat.hemisphere(L.Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
end
local function part(label, shape, slot, pos, rot, size)
	return { label = label, shape = shape, slot = slot, material = "Iron", pos = pos, rot = rot, size = size }
end
local function hilt(gx, gz)
	return {
		part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, Z90, { 0.90, 0.16, 0.16 }),
		part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { gx or 1.10, 0.16, gz or 0.30 }),
	}
end
local function slotCycle()
	local left = { Blade = 12, Guard = 8, Grip = 6, Pommel = 4 }
	return function(parts)
		local count = { Blade = 0, Guard = 0, Grip = 0, Pommel = 0 }
		for _, p in ipairs(parts) do count[p.slot] += 1 end
		for _, s in ipairs({ "Blade", "Guard", "Grip", "Pommel" }) do
			if count[s] < left[s] then return s end
		end
		error("no slot")
	end
end

local designs = {}
local function add(name, parts, label, note)
	for i, p in ipairs(parts) do p.id = i end
	local target
	for i, p in ipairs(parts) do
		if p.label == label then target = i end
	end
	table.insert(designs, { name = name, parts = parts, target = target, note = note })
end

-- 1. the chain swords (atk_chain_sword.luau, scale 0.2, y 3.3)
do
	local s, cy, g = 0.2, 3.3, 1.5e-8
	local function c01()
		return {
			part("Pommel", "Block", "Pommel", { 0, 0.35, 0 }, I, { 0.3, 0.3, 0.3 }),
			part("Grip", "Block", "Grip", { 0, 1, 0 }, I, { 0.2, 1, 0.2 }),
			part("Guard", "Block", "Guard", { 0, 1.6, 0 }, I, { 1, 0.2, 0.3 }),
			part("Blade", "Block", "Blade", { 0, 2.9, 0 }, I, { 0.25, 2.4, 0.1 }),
		}
	end
	for _, kind in ipairs({ "hidden", "visible" }) do
		local parts = c01()
		local cx = 0.125 + 1.2 * s
		local function put(label, pos, size)
			table.insert(parts, part(label, "Block", "Blade", { cx + pos[1] * s, cy + pos[2] * s, pos[3] * s }, I, { size[1] * s, size[2] * s, size[3] * s }))
		end
		put("Target", { 0, 0, 0 }, { 2, 1, 2 })
		local eps = 1e-7 / s
		local function cover(label, x0, x1, z0, z1, thAbs)
			local th = thAbs / s
			put(label, { (x0 + x1) / 2, 0.5 + th / 2, (z0 + z1) / 2 }, { x1 - x0, th, z1 - z0 })
		end
		if kind == "hidden" then
			cover("Z", -1.2, 1 - 2 * g / s - eps, -0.95, 1.1, 0.03)
			cover("Y", -1.2, 1 - g / s - eps, -1.1, 0.95, 0.025)
			cover("X", 0, 1.2, -0.9, 0.9, 0.02)
		else
			cover("Lid", -1.2, 0.5, -1.1, 1.1, 0.02)
			local c = 0.9
			cover("I", c + 2 * g / s + eps, 1.2, -1.1, 0.95, 0.03)
			cover("M", c + g / s + eps, 1.2, -0.95, 1.1, 0.025)
			cover("O", c + eps, 1.2, -0.9, 0.9, 0.02)
		end
		put("WallXp", { 1.1, -0.05, 0 }, { 0.2, 1.1, 2.4 })
		put("WallXm", { -1.1, -0.05, 0 }, { 0.2, 1.1, 2.4 })
		put("WallZp", { 0, -0.05, 1.1 }, { 2.0, 1.1, 0.2 })
		put("WallZm", { 0, -0.05, -1.1 }, { 2.0, 1.1, 0.2 })
		put("Floor", { 0, -0.6, 0 }, { 2.0, 0.2, 2.0 })
		add("chain " .. kind .. " in C01", parts, "Target", "three covers whose edges lie 1.5e-8 apart")
	end
end

-- 2. a rod sealed in 16 flat walls, turned 5.625° (atk_model.luau)
for _, def in ipairs({ { 0.1, 0.0119 }, { 0.1, 0.0118 }, { 0.2, 0.0119 }, { 0.2, 0.0118 }, { 0.2, 0.0116 }, { 0.2, 0.0115 } }) do
	local r, gc = def[1], def[2]
	local parts = {
		part("Pommel", "Block", "Pommel", { 0, 0.35, 0 }, I, { 0.3, 0.3, 0.3 }),
		part("Grip", "Block", "Grip", { 0, 1, 0 }, I, { 0.2, 1, 0.2 }),
		part("Guard", "Block", "Guard", { 0, 1.6, 0 }, I, { 1, 0.2, 0.3 }),
		part("Blade", "Block", "Blade", { 0, 2.9, 0 }, I, { 0.25, 2.4, 0.1 }),
	}
	local n, rc = 16, r + gc
	local rf = rc * 0.98078528040323043
	local len, th = 1.6, 0.03
	local cx, cy = 0.125 + rc + th - 0.005, 2.3
	local turn = 5.625
	table.insert(parts, part("Rod", "Cylinder", "Blade", { cx, cy, 0 }, Z90, { len, 2 * r, 2 * r }))
	local side = 2 * rc * 0.19509032201612825 + 0.004
	for k = 0, n - 1 do
		local a = math.rad(k * 360 / n + turn)
		local d = rf + th / 2
		local q = axisAngle(0, 1, 0, -(k * 360 / n + turn) + 90)
		table.insert(parts, part("Wall", "Block", if k < 10 then "Blade" else "Guard", { cx + d * math.cos(a), cy, d * math.sin(a) }, q, { side, len + 0.06, th }))
	end
	table.insert(parts, part("CapTop", "Block", "Guard", { cx, cy + len / 2 + 0.015 + 0.004, 0 }, I, { 2 * rc + 0.08, 0.03, 2 * rc + 0.08 }))
	table.insert(parts, part("CapBottom", "Block", "Grip", { cx, cy - len / 2 - 0.015 - 0.004, 0 }, I, { 2 * rc + 0.08, 0.03, 2 * rc + 0.08 }))
	add(fmt("rod r %.2f sealed in 16 walls, corner gap %.4f", r, gc), parts, "Rod", "an inscribed model's facets probe short of the walls")
end

-- 3. ribs over every line of an earlier reading, windows between them (x_lattice.luau)
local function lines(w, n)
	local out = {}
	local hw = w / n / 2
	for k = 0, n - 1 do
		local c = (2 * k + 1) * hw
		for _, f in ipairs({ -0.75, -0.25, 0.25, 0.75 }) do table.insert(out, c + f * hw) end
	end
	return out
end
for _, m in ipairs({ 0.001, 0.0005 }) do
	local W, Lg, t, c, nx, ny = 1.0, 2.0, 0.02, 0.03, 3, 5
	local y = 1.45 + Lg / 2
	local parts = hilt()
	local slot = slotCycle()
	table.insert(parts, part("Core", "Block", "Blade", { 0, y, 0 }, I, { W, Lg, t }))
	local z = t / 2 + c / 2
	table.insert(parts, part("Back", "Block", "Blade", { 0, y, -z }, I, { W, Lg, c }))
	table.insert(parts, part("Tip", "Block", "Blade", { 0, y + Lg / 2 + 0.02, 0 }, I, { W + 0.08, 0.04, t + 2 * c }))
	table.insert(parts, part("Side", "Block", "Blade", { W / 2 + 0.02, y, 0 }, I, { 0.04, Lg, t + 2 * c }))
	table.insert(parts, part("Side", "Block", "Blade", { -W / 2 - 0.02, y, 0 }, I, { 0.04, Lg, t + 2 * c }))
	local lx = lines(W, nx)
	for i = 1, #lx, 2 do
		local a, b = lx[i] - W / 2 - m, lx[i + 1] - W / 2 + m
		table.insert(parts, part("RibX", "Block", slot(parts), { (a + b) / 2, y, z }, I, { b - a, Lg, c }))
	end
	local ly = lines(Lg, ny)
	for j = 1, #ly, 2 do
		local a, b = ly[j] - Lg / 2 - m + y, ly[j + 1] - Lg / 2 + m + y
		table.insert(parts, part("RibY", "Block", slot(parts), { 0, (a + b) / 2, z }, I, { W, b - a, c }))
	end
	add(fmt("a core under 16 ribs, %.4f past the lines", m), parts, "Core", "windows between ribs over every line of both families")
end

-- 4. tiles whose hairline slits cross over a core (x_lattice.luau)
do
	local W, Lg = 1.0, 2.0
	local lx, ly = lines(W, 3), lines(Lg, 5)
	local e = 0.00001 / 2
	local function tiles(xs, ys)
		local t, c = 0.02, 0.05
		local y = 1.45 + Lg / 2
		local parts = hilt()
		local slot = slotCycle()
		local z = t / 2 + c / 2
		table.insert(parts, part("Core", "Block", "Guard", { 0, y, 0 }, I, { W, Lg, t }))
		table.insert(parts, part("Back", "Block", "Blade", { 0, y, -z }, I, { W, Lg, c }))
		table.insert(parts, part("Tip", "Block", "Blade", { 0, y + Lg / 2 + 0.02, 0 }, I, { W + 0.08, 0.04, t + 2 * c }))
		table.insert(parts, part("Side", "Block", "Blade", { W / 2 + 0.02, y, 0 }, I, { 0.04, Lg, t + 2 * c }))
		table.insert(parts, part("Side", "Block", "Blade", { -W / 2 - 0.02, y, 0 }, I, { 0.04, Lg, t + 2 * c }))
		local cx = { -W / 2 }
		for _, x in ipairs(xs) do
			table.insert(cx, x - W / 2 - e)
			table.insert(cx, x - W / 2 + e)
		end
		table.insert(cx, W / 2)
		local cyy = { y - Lg / 2 }
		for _, yy in ipairs(ys) do
			table.insert(cyy, yy - Lg / 2 + y - e)
			table.insert(cyy, yy - Lg / 2 + y + e)
		end
		table.insert(cyy, y + Lg / 2)
		for i = 1, #cx, 2 do
			for j = 1, #cyy, 2 do
				local x0, x1, y0, y1 = cx[i], cx[i + 1], cyy[j], cyy[j + 1]
				table.insert(parts, part("Tile", "Block", slot(parts), { (x0 + x1) / 2, (y0 + y1) / 2, z }, I, { x1 - x0, y1 - y0, c }))
			end
		end
		return parts
	end
	add("a core under 8 tiles, 3 hairline crossings", tiles({ lx[2] }, { ly[2], ly[6], ly[10] }), "Core", "hairlines 1e-5 crossing on an earlier reading's lines")
	add("a core under 9 tiles, 4 hairline crossings", tiles({ lx[2], lx[6] }, { ly[2], ly[6] }), "Core", "hairlines 1e-5 crossing on an earlier reading's lines")
end

-- 5. a bar behind 16 slats (a_hand.luau)
for _, r in ipairs({ 0.15, 0.25 }) do -- at r 0.08 a slat is under MIN_DIM wide
	local len = 3.0
	local parts = hilt()
	local y = 1.40 + len / 2
	table.insert(parts, part("Rod", "Cylinder", "Blade", { 0, y, 0 }, Z90, { len, 2 * r, 2 * r }))
	table.insert(parts, part("Cap", "Block", "Pommel", { 0, y + len / 2 + 0.02, 0 }, I, { 2 * r + 0.1, 0.04, math.min(0.6, 2 * r + 0.1) }))
	local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Grip", "Grip" }
	local n = 0
	local function slat(angDeg, halfArcDeg)
		n += 1
		local a = math.rad(angDeg)
		local W = (r + 0.012) * math.sin(math.rad(halfArcDeg))
		local d = r + 0.02 / 2 + 1e-4
		table.insert(parts, part("Slat", "Block", slots[n], { d * math.cos(a), y, d * math.sin(a) }, axisAngle(0, 1, 0, -angDeg + 90), { 2 * W, len - 0.04, 0.02 }))
	end
	for k = 0, 7 do
		slat(45 * k, 6.1)
		slat(22.5 + 45 * k, 6.6)
	end
	add(fmt("a bar r %.2f behind 16 slats", r), parts, "Rod", "slats over an earlier reading's directions, arcs open between them")
end

-- 6. a Ball in 8 corner blocks (a_hand.luau)
do
	local r, y = 0.28, 1.76
	local c = 0.19 * (r + 0.012)
	local parts = hilt()
	table.insert(parts, part("Ball", "Ball", "Blade", { 0, y, 0 }, I, { 2 * r, 2 * r, 2 * r }))
	local s = r + 0.02
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local x0, x1 = math.min(sx * c, sx * s), math.max(sx * c, sx * s)
				local y0, y1 = math.min(sy * c, sy * s), math.max(sy * c, sy * s)
				local z0, z1 = math.min(sz * c, sz * s), math.max(sz * c, sz * s)
				table.insert(parts, part("Box", "Block", "Blade", { (x0 + x1) / 2, y + (y0 + y1) / 2, (z0 + z1) / 2 }, I, { x1 - x0, y1 - y0, z1 - z0 }))
			end
		end
	end
	add("a Ball d 0.56 in 8 corner blocks", parts, "Ball", "bands open between the blocks, round 3 great circles")
end

-- 7. a rod in an octagon of flats whose seams are split by 1e-5 (a_void.luau)
for _, def in ipairs({ { 8, 0.10, 3.0 }, { 8, 0.09, 2.5 } }) do
	local n, r, len = def[1], def[2], def[3]
	local parts = hilt(2 * r + 0.3, math.min(0.6, 2 * r + 0.2))
	local y = 1.48 + len / 2
	local a = (r + 0.012) * math.cos(math.pi / n) - 1e-5
	local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade" }
	for k = 0, n - 1 do
		local ang = (k + 0.5) * 360 / n
		local inner = a * math.tan(math.pi / n)
		table.insert(parts, part("Flat", "Block", slots[k + 1], { (a + 0.02) * math.cos(math.rad(ang)), y, (a + 0.02) * math.sin(math.rad(ang)) }, axisAngle(0, 1, 0, -ang + 90), { 2 * inner - 1e-5, len, 0.04 }))
	end
	table.insert(parts, part("Cap", "Block", "Pommel", { 0, y + len / 2 + 0.02, 0 }, I, { 2 * a + 0.2, 0.04, math.min(0.6, 2 * a + 0.2) }))
	table.insert(parts, part("Rod", "Cylinder", "Blade", { 0, y, 0 }, Z90, { len, 2 * r, 2 * r }))
	add(fmt("a rod r %.2f in an octagon, seams 1e-5", r), parts, "Rod", "the seams under the probe's reach")
end

-- canonical form, truth, reading
local out = { "--!strict", "-- tests/Physics/CoverAttacks.luau — the attack designs of Cover.spec (c) (SPEC §4.4, E-S2.12), as Luau literals with 17",
	"-- significant digits (Lune's JSON is not exact). Generated by docs/spec/prototypes/S2/cover/mk_attacks.luau from the scripts that",
	"-- found them; `truth` is the target's share by VisibleOracle's fine lattice, `kept` the verdict a truth gives. Not a spec.", "",
	"export type Design = { name: string, note: string, target: number, truth: number, kept: boolean, parts: { any } }", "",
	"local DESIGNS: { Design } = {" }
for _, d in ipairs(designs) do
	local res = L.Canonical.draft({ schema = 1, name = "x", type = "Sword", parts = d.parts })
	assert(res.ok, d.name .. ": " .. tostring(res.code) .. " " .. tostring(res.path))
	local parts = res.value.parts
	local P = L.prep(parts)
	local _, _, hider = L.Oracle.flags(P)
	local truth = L.Oracle.share(P, d.target, hider)
	local e = L.Sampling.exposure(P)
	local valid = L.Analyze.quick({ schema = 1, name = "x", type = "Sword", parts = parts }, { connectivity = true }).ok
	print(fmt("%-52s target %2d truth %8.4f%% kept %-5s build %-5s quick-valid %s", d.name, d.target, truth * 100, tostring(truth >= 0.02), tostring(e.kept[d.target]), tostring(valid)))
	table.insert(out, "\t{")
	table.insert(out, fmt("\t\tname = %q,", d.name))
	table.insert(out, fmt("\t\tnote = %q,", d.note))
	table.insert(out, fmt("\t\ttarget = %d,", d.target))
	table.insert(out, fmt("\t\ttruth = %s,", L.num(truth)))
	table.insert(out, fmt("\t\tkept = %s,", tostring(truth >= 0.02)))
	table.insert(out, "\t\tparts = {")
	for _, p in ipairs(parts) do
		table.insert(out, "\t\t\t" .. L.partLiteral(p) .. ",")
	end
	table.insert(out, "\t\t},")
	table.insert(out, "\t},")
end
table.insert(out, "}")
table.insert(out, "")
table.insert(out, "return table.freeze(DESIGNS)")
fs.writeFile(OUT, table.concat(out, "\n") .. "\n")
