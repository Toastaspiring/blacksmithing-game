--!strict
-- tests/Physics/PlausibleDesigns.luau — the plausible families of E-S2.11's study, for VerdictPrecision.spec: decoration a
-- player would add to a real sword (C02, C05, C06, C09, F1–F5), its sink depth swept across 2 %. Not a spec (the runner loads
-- *.spec.luau only). First the same designs, in the same order, as docs/spec/prototypes/S2/verdict/sets.luau's Sets.plausible,
-- 23,009 designs in 13 families; then fullers, ribbed blades, combs and walled blades, whose cover parts leave slits between
-- them; then the verifiers' ribbed bars, caged Balls, grilles and tilings (E-S2.12). Deterministic, and reference data: the
-- bases come from the prototype's fixtures.

local Balance = require("../../src/shared/Definitions/Balance")
local Quat = require("../../src/shared/Blueprint/Quat")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

-- Through a cast, as in Reference.spec: the prototype is reference data, not game code.
local Fx: any = (require :: any)("../../docs/spec/prototypes/S2/v2/fixtures")

local fmt = string.format
local I = { 0, 0, 0, 1 }
local SQ = 0.70710678118654757
local MAXES: { [string]: number } = { Blade = 12, Guard = 8, Grip = 6, Pommel = 4 }
local HIT_MIN, HIT_MAX = { -0.8, 0, -0.3 }, { 0.8, 5, 0.3 }

local function row(...: any): { any }
	return { ... }
end

local function axisAngle(ax: number, ay: number, az: number, deg: number): { number }
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.hemisphere(Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
end

local function compose(a: { number }, b: { number }): { number }
	return Quat.hemisphere(Quat.normalize(Quat.mul(a, b)))
end

local function copyPart(p: any): any
	return { id = p.id, label = p.label, slot = p.slot, shape = p.shape, material = p.material, pos = { p.pos[1], p.pos[2], p.pos[3] },
		rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] }, size = { p.size[1], p.size[2], p.size[3] } }
end

local function copyParts(parts: { any }): { any }
	local out = table.create(#parts)
	for i, p in ipairs(parts) do
		out[i] = copyPart(p)
	end
	return out
end

local function clean(parts: { any }): { any }
	local out = table.create(#parts)
	for i, p in ipairs(parts) do
		out[i] = { id = i, label = p.label, slot = p.slot, shape = p.shape, material = p.material or "Iron",
			pos = { p.pos[1] + 0, p.pos[2] + 0, p.pos[3] + 0 }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] },
			size = { p.size[1], p.size[2], p.size[3] } }
	end
	return out
end

local function slotCounts(parts: { any }): { [string]: number }
	local c: { [string]: number } = { Blade = 0, Guard = 0, Grip = 0, Pommel = 0 }
	for _, p in ipairs(parts) do
		c[p.slot] += 1
	end
	return c
end

-- Slot counts and the hitbox: a design a player could save.
local function quickValid(parts: { any }): boolean
	if #parts > 24 then
		return false
	end
	local c = slotCounts(parts)
	if c.Blade < 1 or c.Grip < 1 or c.Blade > MAXES.Blade or c.Guard > MAXES.Guard or c.Grip > MAXES.Grip or c.Pommel > MAXES.Pommel then
		return false
	end
	local e = 1e-4
	for _, p in ipairs(parts) do
		local P = Shapes.prepare(p, 1)
		if P.minx < HIT_MIN[1] - e or P.miny < HIT_MIN[2] - e or P.minz < HIT_MIN[3] - e or P.maxx > HIT_MAX[1] + e
			or P.maxy > HIT_MAX[2] + e or P.maxz > HIT_MAX[3] + e
		then
			return false
		end
	end
	return true
end

-- A free slot (nil when there is none), preferring `want`.
local function freeSlot(counts: { [string]: number }, want: string): string?
	if counts[want] < MAXES[want] then
		return want
	end
	for _, s in ipairs({ "Blade", "Guard", "Grip", "Pommel" }) do
		if counts[s] < MAXES[s] then
			return s
		end
	end
	return nil
end

local SHARES = { 0.005, 0.01, 0.015, 0.0175, 0.02, 0.0225, 0.025, 0.03, 0.04, 0.05, 0.06, 0.075, 0.09, 0.10, 0.125, 0.15, 0.2, 0.25, 0.3 }

local function bases(): { any }
	local out: { any } = {}
	local want: { [string]: boolean } = { C02 = true, C05 = true, C06 = true, C09 = true, F1 = true, F2 = true, F3 = true, F4 = true, F5 = true }
	for _, b in ipairs(Fx.calibration()) do
		local tag = string.sub(b.name, 1, 3)
		if want[tag] and string.find(b.name, "Steel", 1, true) == nil or tag == "C06" then
			if want[tag] then
				table.insert(out, { tag = tag, parts = copyParts(b.parts) })
			end
		end
	end
	for _, b in ipairs(Fx.golden()) do
		local tag = string.sub(b.name, 1, 2)
		if want[tag] then
			table.insert(out, { tag = tag, parts = copyParts(b.parts) })
		end
	end
	return out
end

-- the largest part of a slot
local function largest(parts: { any }, slot: string, shape: string?): any
	local best: any, bv = nil, 0
	for _, p in ipairs(parts) do
		if p.slot == slot and (shape == nil or p.shape == shape) then
			local P = Shapes.prepare(p, 1)
			if not best or P.volume > bv then
				best, bv = p, P.volume
			end
		end
	end
	return best
end

local function atLocal(host: any, lx: number, ly: number, lz: number): { number }
	local P = Shapes.prepare(host, 1)
	return { host.pos[1] + lx * P.ux + ly * P.vx + lz * P.wx, host.pos[2] + lx * P.uy + ly * P.vy + lz * P.wy,
		host.pos[3] + lx * P.uz + ly * P.vz + lz * P.wz }
end

-- local rotations: which local axis of the decoration runs along the host's axes
local X_TO_Z = axisAngle(0, 1, 0, -90) -- cylinder axis along the host's Z
local X_TO_Y = axisAngle(0, 0, 1, 90) -- cylinder axis along the host's Y
local CYCLE = { 0.5, 0.5, 0.5, 0.5 } -- local X -> host Y, local Y -> host Z, local Z -> host X

local BALL_TURNS: { any } = { row("unrot", I), row("z45", axisAngle(0, 0, 1, 45)), row("xy30", axisAngle(1, 1, 0, 30)), row("r47", axisAngle(1, 2, 3, 47)) }

-- The base's parts first, as a player adds decoration last.
local function addDeco(out: { any }, family: string, base: any, params: string, deco: { any })
	local parts = copyParts(base.parts)
	local counts = slotCounts(parts)
	for _, d in ipairs(deco) do
		local slot = freeSlot(counts, d.slot)
		if slot == nil then
			return
		end
		d.slot = slot
		counts[slot] += 1
		d.material = d.material or "Iron"
		table.insert(parts, d)
	end
	if #parts > 24 or not quickValid(parts) then
		return
	end
	table.insert(out, { name = fmt("%s|%s|%s", family, base.tag, params), family = family, parts = clean(parts) })
end

-- balls sunk in a host's face, a cap of share s showing
local function ballRivets(out: { any }, base: any)
	local guard, blade = largest(base.parts, "Guard", "Block"), largest(base.parts, "Blade", "Block")
	local pommel = largest(base.parts, "Pommel", "Block")
	local grip = largest(base.parts, "Grip", "Block")
	local rows: { any } = {}
	if guard then
		local hx = guard.size[1] / 2
		table.insert(rows, row("guardZ", guard, { 0.08, 0.10, 0.14 }, { { 0.6 * hx, 0, 1 }, { -0.6 * hx, 0, 1 } }))
		table.insert(rows, row("guardX", guard, { 0.08, 0.10, 0.14 }, { { 0, 0, 2 } }))
	end
	if blade then
		local hy = blade.size[2] / 2
		table.insert(rows, row("bladeZ", blade, { 0.08, 0.10, 0.14 }, { { 0, -0.5 * hy, 1 }, { 0, 0, 1 }, { 0, 0.5 * hy, 1 } }))
	end
	if pommel or grip then
		table.insert(rows, row("hiltZ", pommel or grip, { 0.10, 0.14, 0.20 }, { { 0, 0, 1 } }))
	end
	for _, r0 in ipairs(rows) do
		local tag, host, diam, spots = r0[1], r0[2], r0[3], r0[4]
		for _, d in ipairs(diam) do
			local r = d / 2
			for _, turn in ipairs(BALL_TURNS) do
				for _, s in ipairs(SHARES) do
					local deco = {}
					for _, spot in ipairs(spots) do
						local lp
						if spot[3] == 2 then -- on the +X end
							lp = { host.size[1] / 2 - r * (1 - 2 * s), 0, 0 }
						else
							lp = { spot[1], spot[2], host.size[3] / 2 - r * (1 - 2 * s) }
						end
						table.insert(deco, { label = "Rivet", slot = host.slot, shape = "Ball", pos = atLocal(host, lp[1], lp[2], lp[3]),
							rot = compose(host.rot, turn[2]), size = { d, d, d } })
					end
					addDeco(out, "ballRivet", base, fmt("%s d%.2f %s cap%.4f", tag, d, turn[1], s), deco)
				end
			end
		end
	end
end

local POKES = { -0.01, -0.002, 0, 0.0005, 0.001, 0.002, 0.005, 0.01, 0.02, 0.03, 0.05 }

-- a pin the length of the host's thickness, poking t out of +Z
local function cylRivets(out: { any }, base: any)
	local guard, blade = largest(base.parts, "Guard", "Block"), largest(base.parts, "Blade", "Block")
	for _, r0 in ipairs({ row("guard", guard, 1), row("blade", blade, 3) }) do
		local tag, host, n = r0[1], r0[2], r0[3]
		if host then
			for _, r in ipairs({ 0.03, 0.05, 0.08 }) do
				for _, tilt in ipairs({ 0, 8, 20 }) do
					for _, t in ipairs(POKES) do
						local hz = host.size[3] / 2
						local len = 2 * hz
						local deco = {}
						for k = 1, n do
							local along = if n == 1 then 0 else (k - 2) * 0.5 * host.size[2] / 2
							local across = if n == 1 then 0.6 * host.size[1] / 2 else 0
							local lp = { across, along, hz + t - len / 2 }
							local q = compose(host.rot, compose(axisAngle(1, 0, 0, tilt), X_TO_Z))
							table.insert(deco, { label = "Pin", slot = host.slot, shape = "Cylinder", pos = atLocal(host, lp[1], lp[2], lp[3]), rot = q,
								size = { len, 2 * r, 2 * r } })
						end
						addDeco(out, "cylRivet", base, fmt("%s r%.2f tilt%d poke%.4f", tag, r, tilt, t), deco)
					end
				end
			end
		end
	end
end

local RIB_FRACTIONS = { 0.002, 0.005, 0.01, 0.02, 0.03, 0.05, 0.075, 0.1, 0.15, 0.2, 0.3, 0.4, 0.5 }

-- a cylinder half sunk, its axis along the host's face
local function cylRibs(out: { any }, base: any)
	local guard, blade, grip = largest(base.parts, "Guard", "Block"), largest(base.parts, "Blade", "Block"), largest(base.parts, "Grip", "Block")
	for _, r0 in ipairs({ row("blade", blade, 2), row("guard", guard, 1), row("grip", grip, 2) }) do
		local tag, host, longAxis = r0[1], r0[2], r0[3]
		if host then
			for _, r in ipairs({ 0.02, 0.03, 0.05, 0.08 }) do
				for _, psi in ipairs({ 0, 11.25, 22.5 }) do
					for _, f in ipairs(RIB_FRACTIONS) do
						local len = 0.8 * host.size[longAxis]
						local t = f * 2 * r -- the height above the face
						local lz = host.size[3] / 2 + t - r
						local q
						if longAxis == 2 then
							q = compose(host.rot, compose(X_TO_Y, axisAngle(1, 0, 0, psi)))
						else
							q = compose(host.rot, axisAngle(1, 0, 0, psi))
						end
						local deco = { { label = "Rib", slot = host.slot, shape = "Cylinder", pos = atLocal(host, 0, 0, lz), rot = q, size = { len, 2 * r, 2 * r } } }
						addDeco(out, "cylRib", base, fmt("%s r%.2f psi%.2f height%.3f", tag, r, psi, f), deco)
					end
				end
			end
		end
	end
end

local EDGE_POKES = { -0.005, 0, 0.001, 0.002, 0.003, 0.005, 0.0075, 0.01, 0.0125, 0.015, 0.02, 0.03, 0.05, 0.075 }

-- a plate inside a host, one rim poking past the host's edge by p; on C09, the verifier's plates and their kin
local function plateEdges(out: { any }, base: any)
	local guard, blade = largest(base.parts, "Guard", "Block"), largest(base.parts, "Blade", "Block")
	for _, r0 in ipairs({ row("blade", blade), row("guard", guard) }) do
		local tag, host = r0[1], r0[2]
		if host then
			local W, Ln, T = host.size[1], host.size[2], host.size[3]
			if tag == "guard" then
				W, Ln = host.size[2], host.size[1] -- across the guard's height, along its width
			end
			for _, fw in ipairs({ 0.5, 0.8, 1.0 }) do
				for _, fk in ipairs({ 0.6, 0.8 }) do
					for _, fl in ipairs({ 0.6, 0.8, 1.0 }) do
						for _, p in ipairs(EDGE_POKES) do
							local w, k, len = fw * W, math.max(fk * T, 0.02), fl * Ln
							local off = W / 2 + p - w / 2
							local deco
							if tag == "guard" then
								deco = { { label = "Plate", slot = host.slot, shape = "Block", pos = atLocal(host, 0, off, 0), rot = host.rot, size = { len, w, k } } }
							else
								deco = { { label = "Plate", slot = host.slot, shape = "Block", pos = atLocal(host, off, 0, 0), rot = host.rot, size = { w, len, k } } }
							end
							addDeco(out, "plateEdge", base, fmt("%s w%.1f k%.1f l%.1f poke%.4f", tag, fw, fk, fl, p), deco)
						end
					end
				end
			end
		end
	end
	if base.tag == "C09" then
		for _, def in ipairs({ { 0.12, 2.0, 0.05, -0.03 }, { 0.09, 2.0, 0.04, -0.05 }, { 0.10, 2.0, 0.05, -0.04 }, { 0.08, 2.0, 0.04, -0.05 }, { 0.11, 1.2, 0.056, -0.03 },
			{ 0.11, 1.2, 0.056, 0.03 }, { 0.11, 2.0, 0.056, -0.03 }, { 0.08, 2.0, 0.04, -0.05 }, { 0.06, 2.0, 0.03, -0.07 }, { 0.06, 1.0, 0.03, -0.07 } }) do
			addDeco(out, "plateC09", base, fmt("%.2f x %.1f x %.3f at x %.2f", def[1], def[2], def[3], def[4]),
				{ { label = "X", slot = "Blade", shape = "Block", pos = { def[4], 2.6, 0 }, rot = I, size = { def[1], def[2], def[3] } } })
		end
	end
end

-- a plate turned about the host's Y so that one rim rises above the face
local function plateTilts(out: { any }, base: any)
	local blade = largest(base.parts, "Blade", "Block")
	if not blade then
		return
	end
	local W, Ln, T = blade.size[1], blade.size[2], blade.size[3]
	for _, tilt in ipairs({ 1, 2, 4, 8 }) do
		for _, p in ipairs({ 0, 0.001, 0.002, 0.005, 0.01, 0.015, 0.02, 0.03 }) do
			local w, k, len = 0.8 * W, math.max(0.5 * T, 0.02), 0.8 * Ln
			local a = math.rad(tilt)
			-- the high rim's top corner at z = T/2 + p
			local z = T / 2 + p - (w / 2 * math.sin(a) + k / 2 * math.cos(a))
			addDeco(out, "plateTilt", base, fmt("tilt%d poke%.3f", tilt, p), { { label = "Tilted", slot = "Blade", shape = "Block", pos = atLocal(blade, 0, 0, z),
				rot = compose(blade.rot, axisAngle(0, 1, 0, -tilt)), size = { w, len, k } } })
		end
	end
end

local FRACTIONS = { 0.02, 0.03, 0.05, 0.075, 0.1, 0.15, 0.2, 0.3, 0.5, 0.75, 1.0 }

-- a wedge along the blade near its edge, its base sunk into the face
local function bevels(out: { any }, base: any)
	local blade = largest(base.parts, "Blade", "Block")
	if not blade then
		return
	end
	local centred = math.abs(blade.pos[1]) < 1e-9 and blade.rot[1] == 0 and blade.rot[2] == 0 and blade.rot[3] == 0
	for _, a in ipairs({ 0.02, 0.03, 0.05 }) do
		for _, b in ipairs({ 0.03, 0.05, 0.08 }) do
			for _, f in ipairs(FRACTIONS) do
				local len = 0.85 * blade.size[2]
				local lx = blade.size[1] / 2 - b / 2
				local lz = blade.size[3] / 2 + f * a - a / 2
				local w = { label = "Bevel", slot = "Blade", shape = "Wedge", pos = atLocal(blade, lx, 0, lz), rot = compose(blade.rot, CYCLE), size = { len, a, b } }
				local deco: { any } = { w }
				if centred then
					local m = Fx.mirrorX(w, "BevelL")
					table.insert(deco, { label = "BevelL", slot = "Blade", shape = m.shape, pos = m.pos, rot = m.rot, size = m.size })
				end
				addDeco(out, "bevel", base, fmt("a%.2f b%.2f height%.3f", a, b, f), deco)
			end
		end
	end
end

-- two cheeks and a core around the blade block, wider or not, the core recessed or proud at the rims, with or without a cap on
-- top. The study meant to drop the block and did not (its test compared a copy); lamHilt has the laminates with no block
local function laminates(out: { any }, base: any)
	local blade = largest(base.parts, "Blade", "Block")
	if not blade or base.tag == "C09" or base.tag == "C06" then
		return
	end
	for _, k in ipairs({ 0.02, 0.03 }) do
		for _, wf in ipairs({ 1, 1.5, 2 }) do
			for _, p in ipairs({ -0.02, -0.01, -0.005, 0, 0.003, 0.005, 0.0075, 0.01, 0.015, 0.02 }) do
				for _, cap in ipairs({ false, true }) do
					local c = math.max((blade.size[3] - k) / 2, 0.02)
					local w = math.min(blade.size[1] * wf, 1.2)
					local deco: { any } = {
						{ label = "CheekA", slot = "Blade", shape = "Block", pos = atLocal(blade, 0, 0, k / 2 + c / 2), rot = blade.rot, size = { w, blade.size[2], c } },
						{ label = "CheekB", slot = "Blade", shape = "Block", pos = atLocal(blade, 0, 0, -(k / 2 + c / 2)), rot = blade.rot, size = { w, blade.size[2], c } },
					}
					if cap then
						table.insert(deco, { label = "Top", slot = "Blade", shape = "Block", pos = atLocal(blade, 0, blade.size[2] / 2 + 0.02, 0), rot = blade.rot, size = { w, 0.04, k + 2 * c } })
					end
					table.insert(deco, { label = "LamCore", slot = "Blade", shape = "Block", material = "Steel", pos = atLocal(blade, 0, 0, 0), rot = blade.rot, size = { w + 2 * p, blade.size[2], k } })
					addDeco(out, "laminate", base, fmt("k%.2f wf%.1f proud%.4f cap%s", k, wf, p, tostring(cap)), deco)
				end
			end
		end
	end
end

-- the verifier's laminated hilt
local function lamHilt(out: { any })
	local RZ90 = { 0, 0, SQ, SQ }
	for _, w in ipairs({ 0.6, 0.8, 0.9, 1.0, 1.1, 1.2 }) do
		for _, l in ipairs({ 2.0, 3.0 }) do
			for _, c in ipairs({ 0.025, 0.05 }) do
				for _, k in ipairs({ 0.02, 0.03 }) do
					for _, p in ipairs({ -0.02, -0.01, 0, 0.005, 0.01, 0.02, 0.03 }) do
						for _, cap in ipairs({ false, true }) do
							local y = 1.45 + l / 2
							local parts: { any } = {
								{ label = "Pommel", shape = "Ball", slot = "Pommel", material = "Iron", pos = { 0, 0.30, 0 }, rot = I, size = { 0.30, 0.30, 0.30 } },
								{ label = "Grip", shape = "Cylinder", slot = "Grip", material = "Iron", pos = { 0, 0.88, 0 }, rot = RZ90, size = { 0.90, 0.16, 0.16 } },
								{ label = "Guard", shape = "Block", slot = "Guard", material = "Iron", pos = { 0, 1.40, 0 }, rot = I, size = { 1.10, 0.16, 0.30 } },
								{ label = "CheekA", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, y, k / 2 + c / 2 }, rot = I, size = { w, l, c } },
								{ label = "CheekB", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, y, -(k / 2 + c / 2) }, rot = I, size = { w, l, c } },
							}
							if cap then
								table.insert(parts, { label = "Top", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, 1.45 + l + 0.02, 0 }, rot = I, size = { w, 0.04, k + 2 * c } })
							end
							table.insert(parts, { label = "LamCore", shape = "Block", slot = "Blade", material = "Steel", pos = { 0, y, 0 }, rot = I, size = { w + 2 * p, l, k } })
							if quickValid(parts) then
								table.insert(out, { name = fmt("lamHilt|hilt|w%.1f l%.1f c%.3f k%.2f proud%.3f cap%s", w, l, c, k, p, tostring(cap)), family = "lamHilt", parts = clean(parts) })
							end
						end
					end
				end
			end
		end
	end
end

-- rings around a grip, covering it all but the gaps between them
local function wrapRings(out: { any }, base: any)
	local grip = largest(base.parts, "Grip")
	if not grip or grip.shape == "Ball" then
		return
	end
	local cylinder = grip.shape == "Cylinder"
	local long = if cylinder then grip.size[1] else grip.size[2]
	local d = if cylinder then grip.size[2] else math.max(grip.size[1], grip.size[3])
	for _, n in ipairs({ 3, 4, 5 }) do
		for _, extra in ipairs({ 0.01, 0.02, 0.04 }) do
			for _, g in ipairs({ 0.001, 0.002, 0.003, 0.004, 0.005, 0.006, 0.0075, 0.01, 0.0125, 0.015, 0.02, 0.03, 0.05 }) do
				local ring = (long - (n - 1) * g) / n
				local deco = {}
				for k = 1, n do
					local along = -long / 2 + (k - 0.5) * ring + (k - 1) * g
					if cylinder then
						table.insert(deco, { label = "Ring", slot = "Grip", shape = "Cylinder", pos = atLocal(grip, along, 0, 0), rot = grip.rot, size = { ring, d + extra, d + extra } })
					else
						table.insert(deco, { label = "Ring", slot = "Grip", shape = "Block", pos = atLocal(grip, 0, along, 0), rot = grip.rot, size = { grip.size[1] + extra, ring, grip.size[3] + extra } })
					end
				end
				addDeco(out, "wrapRings", base, fmt("n%d extra%.2f gap%.4f", n, extra, g), deco)
			end
		end
	end
end

-- a ball pommel mostly inside a block, poking out of its bottom
local function pommelInBlock(out: { any }, base: any)
	local ball = largest(base.parts, "Pommel", "Ball")
	local block = largest(base.parts, "Pommel", "Block")
	for _, turn in ipairs({ BALL_TURNS[1], BALL_TURNS[3], BALL_TURNS[4] }) do
		for _, s in ipairs(SHARES) do
			if ball then
				-- a block housing around the ball, its bottom plane cut so that the ball shows a cap of share s below
				local d = ball.size[1]
				local r = d / 2
				local side = d + 0.04
				local c = ball.pos[2] - r * (1 - 2 * s) -- the bottom plane's y
				local params = fmt("housing %s cap%.4f", turn[1], s)
				addDeco(out, "pommelInBlock", base, params, { { label = "Housing", slot = "Pommel", shape = "Block", pos = { ball.pos[1], c + side / 2, ball.pos[3] }, rot = I, size = { side, side, side } } })
				-- the ball itself with the turn
				local last = out[#out]
				if last and last.family == "pommelInBlock" and string.find(last.name, params, 1, true) then
					for _, q in ipairs(last.parts) do
						if q.label == ball.label and q.shape == "Ball" then
							q.rot = compose(ball.rot, turn[2])
						end
					end
				end
			elseif block then
				-- a ball nut in a block pommel, poking out of its bottom
				local d = math.min(block.size[1], block.size[2], block.size[3]) * 0.8
				local r = d / 2
				local lp = { 0, -block.size[2] / 2 + r * (1 - 2 * s), 0 }
				addDeco(out, "pommelInBlock", base, fmt("nut %s cap%.4f", turn[1], s), { { label = "Nut", slot = "Pommel", shape = "Ball", pos = atLocal(block, lp[1], lp[2], lp[3]),
					rot = compose(block.rot, turn[2]), size = { d, d, d } } })
			end
		end
	end
end

-- wedges and corner wedges sunk in the guard's top, apex up
local function wedgesInGuard(out: { any }, base: any)
	local guard = largest(base.parts, "Guard", "Block")
	if not guard then
		return
	end
	for _, shape in ipairs({ "Wedge", "CornerWedge" }) do
		for _, size in ipairs({ { 0.12, 0.12, 0.16 }, { 0.2, 0.15, 0.1 }, { 0.1, 0.25, 0.1 } }) do
			for _, spin in ipairs({ 0, 30 }) do
				for _, f in ipairs({ 0.02, 0.03, 0.05, 0.075, 0.1, 0.15, 0.2, 0.3, 0.5, 0.75 }) do
					local lx = 0.7 * guard.size[1] / 2
					local ly = guard.size[2] / 2 + f * size[2] - size[2] / 2
					local q = compose(guard.rot, axisAngle(0, 1, 0, spin))
					local a = { label = "Finial", slot = "Guard", shape = shape, pos = atLocal(guard, lx, ly, 0), rot = q, size = { size[1], size[2], size[3] } }
					local deco: { any } = { a }
					if math.abs(guard.pos[1]) < 1e-9 and guard.rot[4] == 1 then
						local m = Fx.mirrorX(a, "FinialL")
						table.insert(deco, { label = "FinialL", slot = "Guard", shape = m.shape, pos = m.pos, rot = m.rot, size = m.size })
					end
					addDeco(out, "wedgeInGuard", base, fmt("%s %.2f %.2f %.2f spin%d height%.3f", shape, size[1], size[2], size[3], spin, f), deco)
				end
			end
		end
	end
end

-- a rod inside the grip or the guard, poking sideways past its surface
local function rods(out: { any }, base: any)
	local grip = largest(base.parts, "Grip")
	local guard = largest(base.parts, "Guard", "Block")
	local PK = { -0.002, 0, 0.001, 0.002, 0.005, 0.01, 0.015, 0.02, 0.03, 0.04 }
	if grip and grip.shape ~= "Ball" then
		local cylinder = grip.shape == "Cylinder"
		local long = if cylinder then grip.size[1] else grip.size[2]
		local rad = if cylinder then grip.size[2] / 2 else grip.size[1] / 2
		for _, shape in ipairs({ "Block", "Cylinder" }) do
			for _, d in ipairs({ 0.04, 0.06 }) do
				for _, p in ipairs(PK) do
					local off = rad + p - d / 2
					local len = 0.8 * long
					local q, size, pos
					if cylinder then
						pos = atLocal(grip, 0, 0, off) -- across: the grip's local Z
						size, q = { len, d, d }, grip.rot
					else
						pos = atLocal(grip, off, 0, 0)
						if shape == "Block" then
							size, q = { d, len, d }, grip.rot
						else
							size, q = { len, d, d }, compose(grip.rot, X_TO_Y)
						end
					end
					addDeco(out, "rod", base, fmt("grip %s d%.2f poke%.4f", shape, d, p), { { label = "Rod", slot = "Grip", shape = shape, pos = pos, rot = q, size = size } })
				end
			end
		end
	end
	if guard then
		for _, shape in ipairs({ "Block", "Cylinder" }) do
			for _, d in ipairs({ 0.04, 0.06 }) do
				for _, p in ipairs(PK) do
					local off = guard.size[2] / 2 + p - d / 2
					local len = 0.8 * guard.size[1]
					addDeco(out, "rod", base, fmt("guard %s d%.2f poke%.4f", shape, d, p), { { label = "Rod", slot = "Guard", shape = shape, pos = atLocal(guard, 0, off, 0),
						rot = guard.rot, size = { len, d, d } } })
				end
			end
		end
	end
end

-- ── slits between cover parts ─────────────────────────────────────────────────────────────────────────────────────

local function hilt(guardWidth: number): { any }
	return {
		{ label = "Pommel", shape = "Ball", slot = "Pommel", material = "Iron", pos = { 0, 0.30, 0 }, rot = I, size = { 0.30, 0.30, 0.30 } },
		{ label = "Grip", shape = "Cylinder", slot = "Grip", material = "Iron", pos = { 0, 0.88, 0 }, rot = { 0, 0, SQ, SQ }, size = { 0.90, 0.16, 0.16 } },
		{ label = "Guard", shape = "Block", slot = "Guard", material = "Iron", pos = { 0, 1.40, 0 }, rot = I, size = { guardWidth, 0.16, 0.30 } },
	}
end

local function block(label: string, slot: string, pos: { number }, size: { number }): any
	return { label = label, shape = "Block", slot = slot, material = "Iron", pos = pos, rot = I, size = size }
end

local function addSlits(out: { any }, family: string, params: string, parts: { any })
	if quickValid(parts) then
		table.insert(out, { name = family .. "|" .. params, family = family, parts = clean(parts) })
	end
end

-- The strips of a face between cuts { x0, x1 } (nil if one comes out under MIN_DIM).
local function stripsBetween(w: number, cuts: { { number } }): { { number } }?
	local strips: { { number } } = {}
	local a = -w / 2
	for _, cut in ipairs(cuts) do
		if cut[1] - a < 0.02 then
			return nil
		end
		table.insert(strips, { a, cut[1] })
		a = cut[2]
	end
	if w / 2 - a < 0.02 then
		return nil
	end
	table.insert(strips, { a, w / 2 })
	return strips
end

-- A core under cover strips, a groove or a twin through them, the rims and the tip closed.
local function fullers(out: { any })
	for _, w in ipairs({ 0.2, 0.3, 0.4, 0.6, 0.8, 1.0 }) do
		for _, L in ipairs({ 2.5, 2.0 }) do
			for _, t in ipairs({ 0.02, 0.04, 0.08 }) do
				for _, c in ipairs({ 0.015, 0.03, 0.05 }) do
					for _, g in ipairs({ 0.01, 0.02, 0.03, 0.05, 0.08, 0.12 }) do
						for _, gc in ipairs({ 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7 }) do
							for _, twin in ipairs({ false, true }) do
								local y, x = 1.45 + L / 2, gc * w / 2
								local strips = stripsBetween(w, if twin then { { -x - g / 2, -x + g / 2 }, { x - g / 2, x + g / 2 } } else { { x - g / 2, x + g / 2 } })
								if strips and not (twin and x - g / 2 < 0.01) then
									local parts = hilt(1.10)
									table.insert(parts, block("Core", "Blade", { 0, y, 0 }, { w, L, t }))
									for s = 1, -1, -2 do
										for _, st in ipairs(strips) do
											table.insert(parts, block("Strip", "Blade", { (st[1] + st[2]) / 2, y, s * (t / 2 + c / 2) }, { st[2] - st[1], L, c }))
										end
									end
									table.insert(parts, block("Tip", "Guard", { 0, 1.45 + L + 0.02, 0 }, { w + 0.08, 0.04, t + 2 * c }))
									table.insert(parts, block("Rim", "Guard", { w / 2 + 0.02, y, 0 }, { 0.04, L, t + 2 * c }))
									table.insert(parts, block("Rim", "Guard", { -w / 2 - 0.02, y, 0 }, { 0.04, L, t + 2 * c }))
									addSlits(out, "fuller", fmt("w%.1f L%.1f t%.2f c%.3f g%.2f at%.1f %s", w, L, t, c, g, gc, if twin then "twin" else "one"), parts)
								end
							end
						end
					end
				end
			end
		end
	end
end

-- Ribs on both faces of a plate, 1 gap or a symmetric pair between them, with and without bars along the rims.
local function ribbed(out: { any })
	for _, w in ipairs({ 0.3, 0.5, 0.8, 1.2 }) do
		for _, L in ipairs({ 1.5, 2.5 }) do
			for _, k in ipairs({ 0.02, 0.04 }) do
				for _, edges in ipairs({ false, true }) do
					for _, g in ipairs({ 0.02, 0.05, 0.08 }) do
						for step = 0, 5 do
							local off = (0.12 + 0.16 * step) * w / 2
							for _, pair in ipairs({ true, false }) do
								local gaps = if pair then { { -off - g / 2, -off + g / 2 }, { off - g / 2, off + g / 2 } } else { { off - g / 2, off + g / 2 } }
								local strips = stripsBetween(w, gaps)
								if strips and off + g / 2 < w / 2 - 0.02 and off - g / 2 > 0.01 then
									local th, y = 0.03, 1.45 + L / 2
									local parts = hilt(math.max(0.6, w + 0.2))
									table.insert(parts, block("Core", "Blade", { 0, y, 0 }, { w, L, k }))
									for s = -1, 1, 2 do
										for _, st in ipairs(strips) do
											table.insert(parts, block("Rib", "Blade", { (st[1] + st[2]) / 2, y, s * (k / 2 + th / 2) }, { st[2] - st[1], L, th }))
										end
									end
									if edges then
										for s = -1, 1, 2 do
											table.insert(parts, block("Edge", "Guard", { s * (w / 2 + 0.01), y, 0 }, { 0.02, L, k + 2 * th }))
										end
									end
									table.insert(parts, block("Tip", "Guard", { 0, 1.45 + L + 0.02, 0 }, { w + (if edges then 0.04 else 0), 0.04, k + 2 * th }))
									addSlits(out, "ribbed", fmt("w%.1f L%.1f k%.2f edges %s g%.2f at%.3f %s", w, L, k, tostring(edges), g, off, if pair then "pair" else "one"), parts)
								end
							end
						end
					end
				end
			end
		end
	end
end

-- Stripes on one face of a thick blade, over the boundaries and centres of the patches an earlier, sampled reading took (a
-- grid of PATCH_SAMPLES), the slits between them where its sub-points could not see them. The designs stay as they were.
local PATCH_SAMPLES = 64
local function combs(out: { any })
	local Geo = Balance.Geometry
	for _, def in ipairs({ { 1.0, 2.0, 0.2 }, { 1.0, 1.0, 0.2 }, { 0.6, 2.0, 0.1 }, { 1.2, 2.5, 0.2 } }) do
		local w, L, t = def[1], def[2], def[3]
		local y = 1.48 + L / 2
		local h = Sampling.ladder(Geo.H_SURF, function(s: number): boolean
			local a, b, c = math.ceil(w / s), math.ceil(L / s), math.ceil(t / s)
			return 2 * (a * b + b * c + a * c) <= PATCH_SAMPLES
		end)
		local na = math.ceil(w / h)
		local hw = w / na / 2
		for _, centreOpen in ipairs({ false, true }) do
			for _, extra in ipairs({ 0.002, 0.0005 }) do
				local parts = hilt(1.10)
				table.insert(parts, block("K", "Blade", { 0, y, 0 }, { w, L, t }))
				local fits = true
				local function stripe(a: number, b: number)
					fits = fits and b - a >= 0.02
					table.insert(parts, block("Stripe", "Blade", { (a + b) / 2, y, t / 2 + 0.015 }, { b - a, L, 0.03 }))
				end
				for i = 0, na do
					local bx = -w / 2 + i * 2 * hw
					stripe(math.max(-w / 2, bx - 0.25 * hw - extra), math.min(w / 2, bx + 0.25 * hw + extra))
				end
				if not centreOpen then
					for i = 0, na - 1 do
						local cx = -w / 2 + (2 * i + 1) * hw
						stripe(cx - 0.25 * hw - extra, cx + 0.25 * hw + extra)
					end
				end
				table.insert(parts, block("Back", "Blade", { 0, y, -t / 2 - 0.015 }, { w, L, 0.03 }))
				table.insert(parts, block("Tip", "Guard", { 0, y + L / 2 + 0.02, 0 }, { w + 0.08, 0.04, t + 0.06 }))
				table.insert(parts, block("Rim", "Guard", { w / 2 + 0.02, y, 0 }, { 0.04, L, t + 0.06 }))
				table.insert(parts, block("Rim", "Guard", { -w / 2 - 0.02, y, 0 }, { 0.04, L, t + 0.06 }))
				local counts: { [string]: number } = { Blade = 0, Guard = 0, Grip = 0, Pommel = 0 }
				for _, p in ipairs(parts) do
					local slot = freeSlot(counts, p.slot)
					if slot then
						p.slot = slot
						counts[slot] += 1
					else
						fits = false
					end
				end
				if fits then
					addSlits(out, "comb", fmt("%.1f x %.1f x %.1f %s extra %.4f", w, L, t, if centreOpen then "centre open" else "centre covered", extra), parts)
				end
			end
		end
	end
end

-- A thick blade between the hitbox's walls, a lid each side with a slit along it.
local function walls(out: { any })
	for _, depth in ipairs({ 0.6, 0.3, 0.1 }) do
		for _, width in ipairs({ 1.6, 1.2 }) do
			for _, L in ipairs({ 3.5, 2.5 }) do
				for _, g in ipairs({ 0.02, 0.05, 0.1, 0.2, 0.3 }) do
					for _, gx in ipairs({ -0.35, -0.267, -0.2, -0.133, -0.07, 0, 0.1 }) do
						local y, tt = 1.48 + L / 2, (0.6 - depth) / 2
						if tt >= 0.02 then
							local parts = hilt(1.10)
							table.insert(parts, block("K", "Blade", { 0, y, 0 }, { width, L, depth }))
							local left, right, a, b = -width / 2, width / 2, gx - g / 2, gx + g / 2
							if a - left >= 0.02 and right - b >= 0.02 then
								for s = 1, -1, -2 do
									table.insert(parts, block("LidA", "Blade", { (left + a) / 2, y, s * (depth / 2 + tt / 2) }, { a - left, L, tt }))
									table.insert(parts, block("LidB", "Blade", { (right + b) / 2, y, s * (depth / 2 + tt / 2) }, { right - b, L, tt }))
								end
							end
							if width < 1.6 then
								local sw = (1.6 - width) / 2
								table.insert(parts, block("SideA", "Guard", { width / 2 + sw / 2, y, 0 }, { sw, L, 0.6 }))
								table.insert(parts, block("SideB", "Guard", { -width / 2 - sw / 2, y, 0 }, { sw, L, 0.6 }))
							end
							table.insert(parts, block("TipCap", "Guard", { 0, y + L / 2 + 0.05, 0 }, { 1.6, 0.1, 0.6 }))
							addSlits(out, "wall", fmt("depth%.1f width%.1f L%.1f slit%.2f at%.3f", depth, width, L, g, gx), parts)
						end
					end
				end
			end
		end
	end
end

-- The verifiers' families of regular decoration (E-S2.12; their b_mine.luau, on a grid of their parameters instead of a random
-- draw): ribs round a bar, a Ball in a cage of blocks, grilles of strips and tiles with gaps or hairlines over a core. Slots go
-- where there is room, the hilt's and the core's first.
local function place(parts: { any }, fixed: { [any]: boolean }): { any }
	local counts: { [string]: number } = { Blade = 0, Guard = 0, Grip = 0, Pommel = 0 }
	for _, p in ipairs(parts) do
		if fixed[p] then
			counts[p.slot] += 1
		end
	end
	for _, p in ipairs(parts) do
		if not fixed[p] then
			for _, s in ipairs({ "Guard", "Pommel", "Blade", "Grip" }) do
				if counts[s] < MAXES[s] then
					p.slot = s
					counts[s] += 1
					break
				end
			end
		end
	end
	return parts
end

local function ribBars(out: { any })
	for _, r in ipairs({ 0.06, 0.1, 0.16, 0.25 }) do
		for _, len in ipairs({ 2.0, 3.0 }) do
			for _, n in ipairs({ 4, 6, 8, 12, 16 }) do
				for _, roll in ipairs({ 0, 180 / n, 11.25 }) do
					for _, f in ipairs({ 0.3, 0.5, 0.7 }) do
						local parts = hilt(1.10)
						parts[3].size = { 1.10, 0.16, math.min(0.6, 2 * r + 0.1) }
						local fixed: { [any]: boolean } = { [parts[1]] = true, [parts[2]] = true, [parts[3]] = true }
						local y = 1.40 + len / 2
						local rod = { label = "Rod", shape = "Cylinder", slot = "Blade", material = "Iron", pos = { 0, y, 0 }, rot = { 0, 0, SQ, SQ }, size = { len, 2 * r, 2 * r } }
						table.insert(parts, rod)
						fixed[rod] = true
						table.insert(parts, block("Cap", "Guard", { 0, y + len / 2 + 0.02, 0 }, { 2 * r + 0.1, 0.04, math.min(0.6, 2 * r + 0.1) }))
						local t = 0.02
						local a = r + t / 2 + 1e-4
						local w = math.max(0.02, f * 2 * math.pi * (r + 0.012) / n)
						for k = 0, n - 1 do
							local ang = roll + k * 360 / n
							table.insert(parts, { label = "Rib", shape = "Block", slot = "Guard", material = "Iron",
								pos = { a * math.cos(math.rad(ang)), y, a * math.sin(math.rad(ang)) }, rot = axisAngle(0, 1, 0, -ang + 90), size = { w, len - 0.04, t } })
						end
						addSlits(out, "ribBar", fmt("r%.2f L%.1f n%d roll%.2f f%.1f", r, len, n, roll, f), place(parts, fixed))
					end
				end
			end
		end
	end
end

local function cages(out: { any })
	for _, r in ipairs({ 0.1, 0.18, 0.28 }) do
		for _, k in ipairs({ 2, 4, 6, 8 }) do
			for _, open in ipairs({ 0.1, 0.19, 0.3, 0.4 }) do
				for _, roll in ipairs({ 0, 22.5 }) do
					local parts = hilt(1.10)
					local fixed: { [any]: boolean } = { [parts[1]] = true, [parts[2]] = true, [parts[3]] = true }
					local y = 1.48 + r
					local q = axisAngle(0, 1, 0, roll)
					local ball = { label = "Ball", shape = "Ball", slot = "Blade", material = "Iron", pos = { 0, y, 0 }, rot = I, size = { 2 * r, 2 * r, 2 * r } }
					local bladePart = block("Blade", "Blade", { 0, y + r - 0.01 + 1.0, 0 }, { 0.3, 2.0, 0.05 })
					table.insert(parts, ball)
					table.insert(parts, bladePart)
					fixed[ball], fixed[bladePart] = true, true
					local c, s = open * (r + 0.012), r + 0.02
					local function add(x0: number, x1: number, y0: number, y1: number, z0: number, z1: number)
						local w = Quat.rotate(q, { (x0 + x1) / 2, 0, (z0 + z1) / 2 })
						table.insert(parts, { label = "Box", shape = "Block", slot = "Guard", material = "Iron", pos = { w[1], y + (y0 + y1) / 2, w[3] }, rot = q,
							size = { x1 - x0, y1 - y0, z1 - z0 } })
					end
					local function span(sg: number): (number, number)
						return math.min(sg * c, sg * s), math.max(sg * c, sg * s)
					end
					if k == 2 then
						add(-s, s, c, s, -s, s)
						add(-s, s, -s, -c, -s, s)
					elseif k == 4 then
						for _, sx in ipairs({ -1, 1 }) do
							for _, sz in ipairs({ -1, 1 }) do
								local x0, x1 = span(sx)
								local z0, z1 = span(sz)
								add(x0, x1, -s, s, z0, z1)
							end
						end
					elseif k == 6 then
						add(-s, s, c, s, -s, s)
						add(-s, s, -s, -c, -s, s)
						add(c, s, -c, c, -s, s)
						add(-s, -c, -c, c, -s, s)
						add(-c, c, -c, c, c, s)
						add(-c, c, -c, c, -s, -c)
					else
						for _, sx in ipairs({ -1, 1 }) do
							for _, sy in ipairs({ -1, 1 }) do
								for _, sz in ipairs({ -1, 1 }) do
									local x0, x1 = span(sx)
									local y0, y1 = span(sy)
									local z0, z1 = span(sz)
									add(x0, x1, y0, y1, z0, z1)
								end
							end
						end
					end
					addSlits(out, "cage", fmt("r%.2f k%d open%.2f roll%.1f", r, k, open, roll), place(parts, fixed))
				end
			end
		end
	end
end

-- The stage of a grille or tiling: a grip, a tang, a back plate and 4 bars round a core's place.
local function stage(sx: number, sy: number, sz: number, cy: number): ({ any }, { [any]: boolean })
	local b = 0.06
	local grip = { label = "Grip", shape = "Cylinder", slot = "Grip", material = "Iron", pos = { 0, 0.6, 0 }, rot = { 0, 0, SQ, SQ }, size = { 0.9, 0.16, 0.16 } }
	local tang = block("Tang", "Grip", { 0, (1.0 + cy - sy / 2) / 2, 0 }, { 0.1, cy - sy / 2 - 1.0 + 0.02, 0.1 })
	local parts = {
		grip,
		block("Back", "Blade", { 0, cy, -sz / 2 - b / 2 }, { sx + 2 * b, sy + 2 * b, b }),
		block("Bar", "Blade", { sx / 2 + b / 2, cy, 0 }, { b, sy + 2 * b, sz + 2 * b }),
		block("Bar", "Blade", { -sx / 2 - b / 2, cy, 0 }, { b, sy + 2 * b, sz + 2 * b }),
		block("Bar", "Blade", { 0, cy + sy / 2 + b / 2, 0 }, { sx, b, sz + 2 * b }),
		block("Bar", "Blade", { 0, cy - sy / 2 - b / 2, 0 }, { sx, b, sz + 2 * b }),
		tang,
	}
	return parts, { [grip] = true, [tang] = true }
end

local function grilles(out: { any })
	for _, sx in ipairs({ 0.6, 1.0 }) do
		for _, sy in ipairs({ 1.2, 2.8 }) do
			for _, sz in ipairs({ 0.02, 0.08 }) do
				for _, nx in ipairs({ 2, 4, 6 }) do
					for _, ny in ipairs({ 2, 4, 8 }) do
						for _, f in ipairs({ 0.5, 0.7, 0.9 }) do
							local cy = 2.2 + sy * 0.1
							local parts, fixed = stage(sx, sy, sz, cy)
							local core = block("Core", "Blade", { 0, cy, 0 }, { sx, sy, sz })
							table.insert(parts, core)
							fixed[core] = true
							local zc, px, py = sz / 2 + 0.03, sx / nx, sy / ny
							for i = 0, nx - 1 do
								table.insert(parts, block("Strip", "Guard", { -sx / 2 + (i + 0.5) * px, cy, zc }, { math.max(0.02, f * px), sy, 0.06 }))
							end
							for j = 0, ny - 1 do
								table.insert(parts, block("Strip", "Guard", { 0, cy - sy / 2 + (j + 0.5) * py, zc }, { sx, math.max(0.02, f * py), 0.06 }))
							end
							addSlits(out, "grille", fmt("%.1f x %.1f x %.2f %d x %d f%.1f", sx, sy, sz, nx, ny, f), place(parts, fixed))
						end
					end
				end
			end
		end
	end
end

local function tilings(out: { any })
	for _, sx in ipairs({ 0.6, 1.0 }) do
		for _, sy in ipairs({ 1.2, 2.8 }) do
			for _, sz in ipairs({ 0.02, 0.08 }) do
				for nx = 1, 4 do
					for ny = 1, 4 do
						for _, hair in ipairs({ 1e-5, 1e-3, 0.005 }) do
							local cy = 2.2 + sy * 0.1
							local parts, fixed = stage(sx, sy, sz, cy)
							local X, Y = { -sx / 2 }, { -sy / 2 }
							for i = 1, nx - 1 do
								table.insert(X, -sx / 2 + i * sx / nx)
							end
							for j = 1, ny - 1 do
								table.insert(Y, -sy / 2 + j * sy / ny)
							end
							table.insert(X, sx / 2)
							table.insert(Y, sy / 2)
							for i = 1, #X - 1 do
								for j = 1, #Y - 1 do
									local x0, x1 = X[i] + (if i > 1 then hair / 2 else 0), X[i + 1] - (if i < #X - 1 then hair / 2 else 0)
									local y0, y1 = Y[j] + (if j > 1 then hair / 2 else 0), Y[j + 1] - (if j < #Y - 1 then hair / 2 else 0)
									table.insert(parts, block("Tile", "Guard", { (x0 + x1) / 2, cy + (y0 + y1) / 2, sz / 2 + 0.03 }, { x1 - x0, y1 - y0, 0.06 }))
								end
							end
							local core = block("Core", "Blade", { 0, cy, 0 }, { sx, sy, sz })
							table.insert(parts, core)
							fixed[core] = true
							addSlits(out, "tiled", fmt("%.1f x %.1f x %.2f tiles %d x %d hair %g", sx, sy, sz, nx, ny, hair), place(parts, fixed))
						end
					end
				end
			end
		end
	end
end

local Plausible = {}

-- Every design, as { name, family, parts }; a part's id is its index.
function Plausible.all(): { any }
	local out: { any } = {}
	for _, base in ipairs(bases()) do
		ballRivets(out, base)
		cylRivets(out, base)
		cylRibs(out, base)
		plateEdges(out, base)
		plateTilts(out, base)
		bevels(out, base)
		laminates(out, base)
		wrapRings(out, base)
		pommelInBlock(out, base)
		wedgesInGuard(out, base)
		rods(out, base)
	end
	lamHilt(out)
	fullers(out)
	ribbed(out)
	combs(out)
	walls(out)
	ribBars(out)
	cages(out)
	grilles(out)
	tilings(out)
	return out
end

return table.freeze(Plausible)
