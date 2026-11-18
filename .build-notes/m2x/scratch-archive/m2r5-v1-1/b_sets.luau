--!nocheck
-- V1's own designs for precision: decoration on real swords and hand-made hilts, invented here, swept across the threshold. No family or number is taken from sets.luau.
local V = require("./v1")
local Quat = V.Quat
local I = V.I
local fmt = string.format

local S = {}

local BASES = { "C02 Arming (Iron)", "C05", "C08", "F3", "F4", "F5", "C06", "C09" }
local MAIN = { ["C02 Arming (Iron)"] = 4, C05 = 4, C08 = 4, F3 = 6, F4 = 4, F5 = 4, C06 = 5, C09 = 12 }

-- deterministic generator
local function rng(seed)
	local s = (seed * 2654435761 + 97) % 4294967296
	if s == 0 then s = 88172645 end
	local R = {}
	function R.u()
		s = bit32.bxor(s, bit32.lshift(s, 13))
		s = bit32.bxor(s, bit32.rshift(s, 17))
		s = bit32.bxor(s, bit32.lshift(s, 5))
		return s / 4294967296
	end
	function R.range(a, b) return a + (b - a) * R.u() end
	function R.int(a, b) return a + math.floor(R.u() * (b - a + 1)) end
	function R.pick(t) return t[R.int(1, #t)] end
	function R.quat()
		while true do
			local a, b, c, d = R.range(-1, 1), R.range(-1, 1), R.range(-1, 1), R.range(-1, 1)
			local s1, s2 = a * a + b * b, c * c + d * d
			if s1 < 1 and s1 > 1e-4 and s2 < 1 and s2 > 1e-4 then
				local k = math.sqrt((1 - s1) / s2)
				return Quat.hemisphere(Quat.normalize({ a, b, c * k, d * k }))
			end
		end
	end
	return R
end
S.rng = rng

-- cube rotations: 24 turns, for the prisms' odd orientations
local function cubeTurns()
	local out = {}
	local gens = { V.axisAngle(1, 0, 0, 90), V.axisAngle(0, 1, 0, 90), V.axisAngle(0, 0, 1, 90) }
	local seen = {}
	local function key(q)
		local m = { Quat.toMatrix(q) }
		local t = {}
		for i = 1, 9 do t[i] = string.format("%.0f", m[i]) end
		return table.concat(t, ",")
	end
	local function visit(q)
		local k = key(q)
		if seen[k] then return end
		seen[k] = true
		table.insert(out, q)
		for _, g in ipairs(gens) do
			visit(Quat.hemisphere(Quat.normalize(Quat.mul(g, q))))
		end
	end
	visit(I)
	return out
end
local TURNS = cubeTurns()
S.TURNS = TURNS

local slotOrder = { "Blade", "Guard", "Pommel", "Grip" }
local MAXES = { Blade = 12, Guard = 8, Pommel = 4, Grip = 6 }
local function freeSlot(parts, want)
	local c = { Blade = 0, Guard = 0, Pommel = 0, Grip = 0 }
	for _, p in ipairs(parts) do c[p.slot] += 1 end
	if want and c[want] < MAXES[want] then return want end
	for _, s in ipairs(slotOrder) do
		if c[s] < MAXES[s] then return s end
	end
	return nil
end
S.freeSlot = freeSlot

local function inBox(part)
	local lo, hi = V.Shapes.aabb(part)
	local e = 1e-4
	return lo[1] >= -0.8 - e and lo[2] >= -e and lo[3] >= -0.3 - e and hi[1] <= 0.8 + e and hi[2] <= 5 + e and hi[3] <= 0.3 + e
end
S.inBox = inBox

local function add(list, family, name, parts)
	if #parts > 24 then return end
	for _, p in ipairs(parts) do
		if not inBox(p) then return end
		for k = 1, 3 do
			if p.size[k] < 0.02 or p.size[k] > 6 then return end
		end
	end
	table.insert(list, { family = family, name = name, parts = parts })
end

local function withPart(base, part)
	local parts = V.copyParts(base)
	part.slot = freeSlot(parts, part.slot)
	if not part.slot then return nil end
	table.insert(parts, part)
	return parts
end

local function hilt()
	return {
		V.part("Pommel", "Ball", "Pommel", { 0, 0.30, 0 }, I, { 0.30, 0.30, 0.30 }),
		V.part("Grip", "Cylinder", "Grip", { 0, 0.88, 0 }, V.Z90, { 0.90, 0.16, 0.16 }),
		V.part("Guard", "Block", "Guard", { 0, 1.40, 0 }, I, { 1.10, 0.16, 0.30 }),
	}
end
S.hilt = hilt

function S.families()
	return { "ballRivet", "pinRivet", "sunkRod", "chamfer", "oddPoke", "curvedGrip", "tiltPlate", "thinPart", "wall", "fuller", "bead", "comb" }
end

function S.get(family)
	local list = {}
	local F = {}

	-- ball rivets, on every blade, across the threshold, some turned (a Ball's grid turns with it)
	function F.ballRivet()
		for _, bn in ipairs(BASES) do
			local base = V.fixture(bn)
			local h = base[MAIN[bn]]
			local R = rng(#bn * 13 + 1)
			for _, d in ipairs({ 0.08, 0.1, 0.12, 0.16, 0.2, 0.25, 0.3, 0.4 }) do
				local r = d / 2
				for _, f in ipairs({ -0.99, -0.97, -0.95, -0.92, -0.9, -0.87, -0.84, -0.8, -0.75, -0.7, -0.6, -0.5, -0.3 }) do
					for _, x in ipairs({ 0, h.size[1] / 4 }) do
						for _, y in ipairs({ -0.5, 0.3 }) do
							for t = 1, 3 do
								local q = if t == 1 then I else R.quat()
								local rivet = V.part("Rivet", "Ball", "Blade", { h.pos[1] + x, h.pos[2] + y, h.pos[3] + h.size[3] / 2 + r * f }, q, { d, d, d })
								local parts = withPart(base, rivet)
								if parts then add(list, "ballRivet", fmt("%s d%.2f f%.2f x%.2f y%.1f t%d", bn, d, f, x, y, t), parts) end
							end
						end
					end
				end
			end
		end
	end

	-- cylinders across the blade, a pin poking both sides, or standing on one side
	function F.pinRivet()
		for _, bn in ipairs(BASES) do
			local base = V.fixture(bn)
			local h = base[MAIN[bn]]
			for _, r in ipairs({ 0.02, 0.03, 0.05, 0.08, 0.12 }) do
				for _, poke in ipairs({ 0.0005, 0.001, 0.002, 0.004, 0.008, 0.012, 0.02, 0.04 }) do
					for _, oneSide in ipairs({ false, true }) do
						for _, spin in ipairs({ 0, 11.25, 22.5, 33 }) do
							local L = if oneSide then h.size[3] / 2 + poke else h.size[3] + 2 * poke
							local z = if oneSide then h.pos[3] + h.size[3] / 2 + poke - L / 2 else h.pos[3]
							-- local X along world Z: turn about Y, then spin about the axis
							local q = Quat.hemisphere(Quat.normalize(Quat.mul(V.axisAngle(0, 1, 0, -90), V.axisAngle(1, 0, 0, spin))))
							local d = 2 * r
							local parts = withPart(base, V.part("Pin", "Cylinder", "Guard", { h.pos[1], h.pos[2], z }, q, { L, d, d }))
							if parts then add(list, "pinRivet", fmt("%s r%.2f poke%.4f %s spin%.0f", bn, r, poke, if oneSide then "one" else "both", spin), parts) end
						end
					end
				end
			end
		end
	end

	-- rods sunk along the blade's face, level or tilted so they come up out of it
	function F.sunkRod()
		for _, bn in ipairs(BASES) do
			local base = V.fixture(bn)
			local h = base[MAIN[bn]]
			for _, r in ipairs({ 0.01, 0.015, 0.02, 0.03, 0.05, 0.08 }) do
				for _, L in ipairs({ 0.7, 1.2, 2.0 }) do
					for _, f in ipairs({ -0.98, -0.95, -0.9, -0.8, -0.65, -0.4, 0 }) do
						for _, tilt in ipairs({ 0, 0.5, 1, 2, 4 }) do
							for _, spin in ipairs({ 0, 13 }) do
								local q = Quat.hemisphere(Quat.normalize(Quat.mul(V.axisAngle(1, 0, 0, -tilt), Quat.mul(V.Z90, V.axisAngle(1, 0, 0, spin)))))
								local d = 2 * r
								local rod = V.part("Rod", "Cylinder", "Blade", { h.pos[1], h.pos[2], h.pos[3] + h.size[3] / 2 + r * f }, q, { L, d, d })
								local parts = withPart(base, rod)
								if parts then add(list, "sunkRod", fmt("%s r%.3f L%.1f f%.2f tilt%.1f spin%.0f", bn, r, L, f, tilt, spin), parts) end
							end
						end
					end
				end
			end
		end
	end

	-- wedges along the blade's rims, sunk across the threshold, in every cube orientation that lies along Y
	function F.chamfer()
		for _, bn in ipairs(BASES) do
			local base = V.fixture(bn)
			local h = base[MAIN[bn]]
			local turns = {}
			for _, q in ipairs(TURNS) do
				local m = { Quat.toMatrix(q) }
				-- local X along world Y
				if math.abs(m[4]) > 0.9 then table.insert(turns, q) end
			end
			for _, a in ipairs({ 0.02, 0.03, 0.05, 0.08 }) do
				for _, b in ipairs({ 0.03, 0.06, 0.12 }) do
					for _, sink in ipairs({ 0.002, 0.005, 0.01, 0.02, 0.04 }) do
						for ti, q in ipairs(turns) do
							for _, side in ipairs({ 1, -1 }) do
								for _, shape in ipairs({ "Wedge", "CornerWedge" }) do
									local L = math.min(h.size[2], 1.6)
									local x = h.pos[1] + side * (h.size[1] / 2 + a / 2 - sink)
									local p = V.part("Chamfer", shape, "Blade", { x, h.pos[2], h.pos[3] }, q, { L, a, b })
									local parts = withPart(base, p)
									if parts then add(list, "chamfer", fmt("%s %s a%.2f b%.2f sink%.3f turn%d side%d", bn, shape, a, b, sink, ti, side), parts) end
								end
							end
						end
					end
				end
			end
		end
	end

	-- a part of any shape at an odd turn, one vertex or side poking out of the blade, guard or grip by a set amount
	function F.oddPoke()
		local R = rng(4242)
		for _, bn in ipairs(BASES) do
			local base = V.fixture(bn)
			for k = 1, 700 do
				local host = base[R.int(1, #base)]
				local shape = R.pick({ "Wedge", "CornerWedge", "Wedge", "CornerWedge", "Block", "Cylinder" })
				local size = { R.range(0.03, 0.5), R.range(0.03, 0.5), R.range(0.03, 0.5) }
				if shape == "Cylinder" then
					local d = math.min(size[2], size[3])
					size = { size[1], d, d }
				end
				local q = R.quat()
				local part = V.part("Poke", shape, "Blade", { 0, 0, 0 }, q, size)
				local P = V.Shapes.prepare(part, 1)
				-- pick a direction among the host's faces, shift so that the part stands t past that face
				local Ph = V.Shapes.prepare(host, 1)
				local axis = R.int(1, 3)
				local sign = if R.u() < 0.5 then 1 else -1
				local dx, dy, dz
				if axis == 1 then dx, dy, dz = sign * Ph.ux, sign * Ph.uy, sign * Ph.uz
				elseif axis == 2 then dx, dy, dz = sign * Ph.vx, sign * Ph.vy, sign * Ph.vz
				else dx, dy, dz = sign * Ph.wx, sign * Ph.wy, sign * Ph.wz end
				local _, hi = V.Shapes.extentAlong(P, dx, dy, dz)
				local half = if axis == 1 then Ph.hx elseif axis == 2 then Ph.hy else Ph.hz
				local t = R.pick({ 0.001, 0.002, 0.004, 0.008, 0.012, 0.02, 0.03, 0.05, 0.08 })
				local ox, oy, oz = R.range(-0.4, 0.4), R.range(-0.4, 0.4), R.range(-0.4, 0.4)
				local ax = Ph.cx + ox * Ph.hx * Ph.ux + oy * Ph.hy * Ph.vx + oz * Ph.hz * Ph.wx
				local ay = Ph.cy + ox * Ph.hx * Ph.uy + oy * Ph.hy * Ph.vy + oz * Ph.hz * Ph.wy
				local az = Ph.cz + ox * Ph.hx * Ph.uz + oy * Ph.hy * Ph.vz + oz * Ph.hz * Ph.wz
				-- along (dx, dy, dz) the part's top is at hi from the origin; move it to the host's face + t
				local face = ax * dx + ay * dy + az * dz
				local off = half - (face - (Ph.cx * dx + Ph.cy * dy + Ph.cz * dz)) + t - hi
				part.pos = { ax + off * dx, ay + off * dy, az + off * dz }
				local parts = withPart(base, part)
				if parts then add(list, "oddPoke", fmt("%s #%d %s t%.3f", bn, k, shape, t), parts) end
			end
		end
	end

	-- a curved grip: segments of cylinders, wrap rings a little wider, gaps between them
	function F.curvedGrip()
		for _, n in ipairs({ 3, 4, 5, 6 }) do
			for _, ext in ipairs({ 0.002, 0.005, 0.01, 0.02, 0.04 }) do
				for _, gap in ipairs({ 0.0005, 0.001, 0.003, 0.006, 0.012, 0.03, 0.06 }) do
					for _, bend in ipairs({ 0, 4 }) do
						local parts = hilt()
						parts[2].shape = "Cylinder"
						-- the core of the grip
						local rg, Lg, yg = 0.08, 0.9, 0.88
						local q0 = Quat.hemisphere(Quat.normalize(Quat.mul(V.axisAngle(0, 0, 1, bend), V.Z90)))
						parts[2].rot = q0
						local w = (Lg - (n + 1) * gap) / n
						if w > 0.02 then
							for k = 1, n do
								local y = yg - Lg / 2 + gap * k + w * (k - 0.5)
								local ring = V.part("Ring", "Cylinder", "Guard", { 0, y, 0 }, q0, { w, 2 * (rg + ext), 2 * (rg + ext) })
								ring.slot = freeSlot(parts, "Guard")
								table.insert(parts, ring)
							end
							table.insert(parts, V.part("Blade", "Block", "Blade", { 0, 2.65, 0 }, I, { 0.2, 2.5, 0.06 }))
							add(list, "curvedGrip", fmt("n%d ext%.3f gap%.4f bend%d", n, ext, gap, bend), parts)
						end
					end
				end
			end
		end
	end

	-- a plate lying in the blade, tilted a little, so that a corner or an edge pokes out
	function F.tiltPlate()
		for _, bn in ipairs({ "C05", "F4", "C08", "C02 Arming (Iron)" }) do
			local base = V.fixture(bn)
			local h = base[MAIN[bn]]
			for _, t in ipairs({ 0.02, 0.03, 0.05 }) do
				for _, sx in ipairs({ 0.5, 0.8, 0.97 }) do
					for _, sy in ipairs({ 0.4, 0.8 }) do
						for _, deg in ipairs({ 0.2, 0.5, 1, 2, 4, 8 }) do
							for _, axis in ipairs({ { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 }, { 1, 1, 0 }, { 1, 0, 1 } }) do
								for _, off in ipairs({ 0, 0.5, 0.9 }) do
									local q = V.axisAngle(axis[1], axis[2], axis[3], deg)
									local size = { h.size[1] * sx, h.size[2] * sy, t }
									local p = V.part("Plate", "Block", "Blade", { h.pos[1] + off * h.size[1] * (1 - sx) / 2, h.pos[2], h.pos[3] }, q, size)
									local parts = withPart(base, p)
									if parts then add(list, "tiltPlate", fmt("%s t%.2f sx%.2f sy%.1f deg%.1f axis%d%d%d off%.1f", bn, t, sx, sy, deg, axis[1], axis[2], axis[3], off), parts) end
								end
							end
						end
					end
				end
			end
		end
	end

	-- thin things at MIN_DIM: a plate 0.02 thick inlaid, flush or a hair proud; wedges and corner wedges 0.02 on a side
	function F.thinPart()
		for _, bn in ipairs(BASES) do
			local base = V.fixture(bn)
			local h = base[MAIN[bn]]
			for _, shape in ipairs({ "Block", "Wedge", "CornerWedge", "Cylinder" }) do
				for _, L in ipairs({ 0.6, 1.2, 2.0 }) do
					for _, w in ipairs({ 0.02, 0.04, 0.1, 0.3 }) do
						for _, proud in ipairs({ -0.002, 0, 0.0005, 0.001, 0.002, 0.004, 0.008, 0.015 }) do
							for ti = 1, #TURNS, 3 do
								local q = TURNS[ti]
								local size = if shape == "Cylinder" then { L, 0.02, 0.02 } else { L, 0.02, w }
								local part = V.part("Thin", shape, "Blade", { h.pos[1], h.pos[2], h.pos[3] }, Quat.hemisphere(Quat.normalize(Quat.mul(V.Z90, q))), size)
								local P = V.Shapes.prepare(part, 1)
								local _, top = V.Shapes.extentAlong(P, 0, 0, 1)
								part.pos[3] = h.pos[3] + h.size[3] / 2 + proud - (top - part.pos[3])
								local parts = withPart(base, part)
								if parts and P.volume >= 0.0002 then add(list, "thinPart", fmt("%s %s L%.1f w%.2f proud%.4f turn%d", bn, shape, L, w, proud, ti), parts) end
							end
						end
					end
				end
			end
		end
	end

	-- at the hitbox's walls: the largest parts there are, patches at their largest, covered by others up to a slit
	function F.wall()
		for _, depth in ipairs({ 0.6, 0.3, 0.1 }) do
			for _, width in ipairs({ 1.6, 1.2 }) do
				for _, L in ipairs({ 3.5, 2.5 }) do
					for _, g in ipairs({ 0.02, 0.05, 0.1, 0.2, 0.3 }) do
						for _, gx in ipairs({ -0.35, -0.267, -0.2, -0.133, -0.07, 0, 0.1 }) do
							local y = 1.48 + L / 2
							local parts = hilt()
							local K = V.part("K", "Block", "Blade", { 0, y, 0 }, I, { width, L, depth })
							table.insert(parts, K)
							-- a lid each side, of the blade's whole face but a slit along Y at gx, flush with the walls
							local tt = (0.6 - depth) / 2
							if tt >= 0.02 then
								for _, s in ipairs({ 1, -1 }) do
									local left, right = -width / 2, width / 2
									local a, b = gx - g / 2, gx + g / 2
									if a - left >= 0.02 and right - b >= 0.02 then
										table.insert(parts, V.part("LidA", "Block", "Blade", { (left + a) / 2, y, s * (depth / 2 + tt / 2) }, I, { a - left, L, tt }))
										table.insert(parts, V.part("LidB", "Block", "Blade", { (right + b) / 2, y, s * (depth / 2 + tt / 2) }, I, { right - b, L, tt }))
									end
								end
								if width < 1.6 then
									local sw = (1.6 - width) / 2
									table.insert(parts, V.part("SideA", "Block", "Guard", { width / 2 + sw / 2, y, 0 }, I, { sw, L, 0.6 }))
									table.insert(parts, V.part("SideB", "Block", "Guard", { -width / 2 - sw / 2, y, 0 }, I, { sw, L, 0.6 }))
								end
								table.insert(parts, V.part("TipCap", "Block", "Guard", { 0, y + L / 2 + 0.05, 0 }, I, { 1.6, 0.1, 0.6 }))
								add(list, "wall", fmt("depth%.1f width%.1f L%.1f slit%.2f at%.3f", depth, width, L, g, gx), parts)
							end
						end
					end
				end
			end
		end
	end

	-- a fuller: a blade's core under cover strips, the core showing along one or two grooves
	function F.fuller()
		for _, w in ipairs({ 0.2, 0.3, 0.4, 0.6, 0.8, 1.0 }) do
			for _, L in ipairs({ 2.5, 2.0 }) do
				for _, t in ipairs({ 0.02, 0.04, 0.08 }) do
					for _, c in ipairs({ 0.015, 0.03, 0.05 }) do
						for _, g in ipairs({ 0.01, 0.02, 0.03, 0.05, 0.08, 0.12 }) do
							for _, gc in ipairs({ 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7 }) do
								for _, twin in ipairs({ false, true }) do
									local y = 1.45 + L / 2
									local parts = hilt()
									table.insert(parts, V.part("Core", "Block", "Blade", { 0, y, 0 }, I, { w, L, t }))
									local x = gc * w / 2
									local cuts = if twin then { { -x - g / 2, -x + g / 2 }, { x - g / 2, x + g / 2 } } else { { x - g / 2, x + g / 2 } }
									local ok = true
									if twin and x - g / 2 < 0.01 then ok = false end
									local a = -w / 2
									local strips = {}
									for _, cut in ipairs(cuts) do
										if cut[1] - a < 0.02 then ok = false end
										table.insert(strips, { a, cut[1] })
										a = cut[2]
									end
									if w / 2 - a < 0.02 then ok = false end
									table.insert(strips, { a, w / 2 })
									if ok then
										for _, s in ipairs({ 1, -1 }) do
											for _, st in ipairs(strips) do
												table.insert(parts, V.part("Strip", "Block", "Blade", { (st[1] + st[2]) / 2, y, s * (t / 2 + c / 2) }, I, { st[2] - st[1], L, c }))
											end
										end
										-- the rims and the tip closed
										table.insert(parts, V.part("Tip", "Block", "Guard", { 0, 1.45 + L + 0.02, 0 }, I, { w + 0.08, 0.04, t + 2 * c }))
										table.insert(parts, V.part("Rim", "Block", "Guard", { w / 2 + 0.02, y, 0 }, I, { 0.04, L, t + 2 * c }))
										table.insert(parts, V.part("Rim", "Block", "Guard", { -w / 2 - 0.02, y, 0 }, I, { 0.04, L, t + 2 * c }))
										add(list, "fuller", fmt("w%.1f L%.1f t%.2f c%.3f g%.2f at%.1f %s", w, L, t, c, g, gc, if twin then "twin" else "one"), parts)
									end
								end
							end
						end
					end
				end
			end
		end
	end

	-- a bead: a ball held between two plates, showing a band; and between a plate and a guard
	function F.bead()
		for _, d in ipairs({ 0.1, 0.14, 0.2, 0.3, 0.4, 0.5 }) do
			local r = d / 2
			for _, gapf in ipairs({ 0.02, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.5, 0.7 }) do
				for t = 1, 4 do
					local R = rng(t * 97 + math.floor(d * 100) + math.floor(gapf * 1000))
					local q = if t == 1 then I elseif t == 2 then V.axisAngle(0, 0, 1, 45) else R.quat()
					local parts = hilt()
					local y = 1.48 + 1.25
					table.insert(parts, V.part("Web", "Block", "Blade", { 0, y, 0 }, I, { 0.8, 2.5, 0.02 }))
					local gap = gapf * d
					-- the bead sits in the Y = const slit of the plates: a window between two plates above and below it along Y
					local yb = y
					local ball = V.part("Bead", "Ball", "Guard", { 0, yb, 0 }, q, { d, d, d })
					table.insert(parts, ball)
					local thick = 0.3
					table.insert(parts, V.part("Plate", "Block", "Blade", { 0, yb + gap / 2 + thick / 2, 0 }, I, { 0.8, thick, math.min(0.6, d + 0.05) }))
					table.insert(parts, V.part("Plate", "Block", "Blade", { 0, yb - gap / 2 - thick / 2, 0 }, I, { 0.8, thick, math.min(0.6, d + 0.05) }))
					add(list, "bead", fmt("d%.2f gap%.2f t%d", d, gapf, t), parts)
				end
			end
		end
	end

	-- a comb over a block: stripes that stand on its reading points, slits between them
	function F.comb()
		for _, def in ipairs({ { 1.0, 2.0, 0.2 }, { 1.0, 1.0, 0.2 }, { 0.6, 2.0, 0.1 }, { 1.2, 2.5, 0.2 } }) do
			local w, L, t = def[1], def[2], def[3]
			local y = 1.48 + L / 2
			local P = V.Shapes.prepare(V.part("K", "Block", "Blade", { 0, y, 0 }, I, { w, L, t }), 1)
			local h = V.Sampling.ladder(0.04, function(s)
				local a, b, c = math.ceil(w / s), math.ceil(L / s), math.ceil(t / s)
				return 2 * (a * b + b * c + a * c) <= 64
			end)
			local na = math.ceil(w / h)
			local pw = w / na
			-- stripes along Y: one over each patch centre and its two near sub-columns (centreCover), one over each patch boundary and its far sub-columns; the slits between them
			for _, centreOpen in ipairs({ false, true }) do
				for _, stripeExtra in ipairs({ 0.002, 0.0005 }) do
					local parts = hilt()
					table.insert(parts, V.part("K", "Block", "Blade", { 0, y, 0 }, I, { w, L, t }))
					local hw = pw / 2
					local function stripe(a, b, s)
						table.insert(parts, V.part("Stripe", "Block", "Blade", { (a + b) / 2, y, s * (t / 2 + 0.015) }, I, { b - a, L, 0.03 }))
					end
					local ok = true
					for _, s in ipairs({ 1 }) do
						for i = 0, na do
							local bx = -w / 2 + i * pw
							-- over a boundary: sub-columns at bx +- 0.25 hw inside the patch? the far ones are at 0.75 hw from the centre: bx -+ 0.25 hw
							local a, b = math.max(-w / 2, bx - 0.25 * hw - stripeExtra), math.min(w / 2, bx + 0.25 * hw + stripeExtra)
							if b - a < 0.02 then ok = false end
							stripe(a, b, s)
						end
						if not centreOpen then
							for i = 0, na - 1 do
								local cx = -w / 2 + (i + 0.5) * pw
								local a, b = cx - 0.25 * hw - stripeExtra, cx + 0.25 * hw + stripeExtra
								if b - a < 0.02 then ok = false end
								stripe(a, b, s)
							end
						end
					end
					table.insert(parts, V.part("Back", "Block", "Blade", { 0, y, -t / 2 - 0.015 }, I, { w, L, 0.03 }))
					table.insert(parts, V.part("Tip", "Block", "Guard", { 0, y + L / 2 + 0.02, 0 }, I, { w + 0.08, 0.04, t + 0.06 }))
					table.insert(parts, V.part("Rim", "Block", "Guard", { w / 2 + 0.02, y, 0 }, I, { 0.04, L, t + 0.06 }))
					table.insert(parts, V.part("Rim", "Block", "Guard", { -w / 2 - 0.02, y, 0 }, I, { 0.04, L, t + 0.06 }))
					if ok then
						for i, p in ipairs(parts) do
							if p.label == "Stripe" then
								p.slot = "Blade"
							end
						end
						local c = { Blade = 0, Guard = 0, Pommel = 0, Grip = 0 }
						local fits = true
						for _, p in ipairs(parts) do
							if c[p.slot] >= MAXES[p.slot] then
								local s2 = freeSlot({}, nil)
								local moved = false
								for _, sl in ipairs(slotOrder) do
									if c[sl] < MAXES[sl] then
										p.slot = sl
										moved = true
										break
									end
								end
								fits = fits and moved
							end
							c[p.slot] += 1
						end
						if fits then add(list, "comb", fmt("%.1f x %.1f x %.1f, %s, extra %.4f", w, L, t, if centreOpen then "centre open" else "centre covered", stripeExtra), parts) end
					end
				end
			end
		end
	end

	-- the study's plausible families, as the repo's port builds them
	function F.plausible()
		local Plausible = require("./tree/tests/Physics/PlausibleDesigns")
		for _, d in ipairs(Plausible.all()) do
			local parts = V.copyParts(d.parts)
			table.insert(list, { family = "plausible", name = d.name, parts = parts })
		end
	end

	F[family]()
	return list
end

return S
