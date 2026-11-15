--!nocheck
-- m2r5: the design sets. Deterministic: each process rebuilds the same list, so a shard is (set, shard, nshards).
--   fixtures   the prototype's calibration, golden, adversarial, regression, validation, perf; the repo's F1-F5 and A01-A24
--   plausible  decoration on real swords (C02, C05, C06, C09, F1-F5), the sink depth swept across 2 %
--   fuzz       tests/lib/Gen validSword + withFiller, and PhysicsHelpers.anyDesign
--   poke       random shape, random turn, sunk into a random part of a real sword or of a random design, across 2 %
local Shapes = require("./tree/src/shared/Physics/Shapes")
local Quat = require("./tree/src/shared/Blueprint/Quat")
local Balance = require("./tree/src/shared/Definitions/Balance")
local EquipmentTypes = require("./tree/src/shared/Definitions/EquipmentTypes")
local Limits = require("./tree/src/shared/Definitions/Limits")
local Materials = require("./tree/src/shared/Definitions/Materials")
local Versions = require("./tree/src/shared/Definitions/Versions")
local Canonical = require("./tree/src/shared/Blueprint/Canonical")
local Gen = require("./tree/tests/lib/Gen")
local TestRng = require("./tree/tests/lib/TestRng")
local H = require("./tree/tests/Physics/PhysicsHelpers")
local Blueprints = require("./tree/tests/fixtures/Blueprints")
local Adversarial = require("./tree/tests/fixtures/Adversarial")
local Fx = require("./proto/fixtures")
local L = require("./lib")
local fmt = string.format

local Sets = {}
local I = { 0, 0, 0, 1 }
local SQ = 0.70710678118654757

local function axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.hemisphere(Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
end
Sets.axisAngle = axisAngle

local function compose(a, b)
	return Quat.hemisphere(Quat.normalize(Quat.mul(a, b)))
end

local function clean(parts)
	local out = table.create(#parts)
	for i, p in ipairs(parts) do
		out[i] = { id = i, label = p.label, slot = p.slot, shape = p.shape, material = p.material or "Iron", pos = { p.pos[1] + 0, p.pos[2] + 0, p.pos[3] + 0 }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] }, size = { p.size[1], p.size[2], p.size[3] } }
	end
	return out
end

-- ── fixtures ──────────────────────────────────────────────────────────────────────────────────────────────────────

function Sets.fixtures()
	local out = {}
	local seen = {}
	local function add(group, name, parts)
		local key = group .. "|" .. name
		if not seen[key] and parts and #parts >= 1 and #parts <= 24 then
			seen[key] = true
			table.insert(out, { name = key, set = "fixtures", family = group, parts = clean(parts) })
		end
	end
	for _, b in ipairs(Fx.calibration()) do add("calibration", b.name, b.parts) end
	for _, b in ipairs(Fx.golden()) do add("golden", b.name, b.parts) end
	for _, r in ipairs(Fx.adversarial()) do
		add("adversarial", r.fixture.name, r.fixture.parts)
		add("adversarial", r.base.name, r.base.parts)
	end
	for _, r in ipairs(Fx.regression()) do
		add("regression", r.fixture.name, r.fixture.parts)
		if r.base then add("regression", "base " .. r.base.name, r.base.parts) end
	end
	for _, b in ipairs(Fx.validation()) do add("validation", b.name, b.parts) end
	for _, b in ipairs(Fx.perf()) do add("perf", b.name, b.parts) end
	for _, id in ipairs(Blueprints.order) do
		local core = Blueprints.core(id)
		add("repoF", id, core.parts)
	end
	for _, v in ipairs(Adversarial.variants) do
		local ok, draft = pcall(v.draft)
		if ok and type(draft) == "table" then
			local ok2, res = pcall(Canonical.draft, draft)
			if ok2 and res.ok and type(res.value.parts) == "table" then
				add("repoA", v.key, res.value.parts)
			end
		end
	end
	return out
end

-- ── plausible decoration ──────────────────────────────────────────────────────────────────────────────────────────

local SHARES = { 0.005, 0.01, 0.015, 0.0175, 0.02, 0.0225, 0.025, 0.03, 0.04, 0.05, 0.06, 0.075, 0.09, 0.10, 0.125, 0.15, 0.2, 0.25, 0.3 }

local function bases()
	local out = {}
	local want = { C02 = true, C05 = true, C06 = true, C09 = true, F1 = true, F2 = true, F3 = true, F4 = true, F5 = true }
	for _, b in ipairs(Fx.calibration()) do
		local tag = string.sub(b.name, 1, 3)
		if want[tag] and string.find(b.name, "Steel", 1, true) == nil or tag == "C06" then
			if want[tag] then
				table.insert(out, { tag = tag, parts = L.copyParts(b.parts) })
			end
		end
	end
	for _, b in ipairs(Fx.golden()) do
		local tag = string.sub(b.name, 1, 2)
		if want[tag] then
			table.insert(out, { tag = tag, parts = L.copyParts(b.parts) })
		end
	end
	return out
end
Sets.bases = bases

-- the largest part of a slot
local function largest(parts, slot, shape)
	local best, bv
	for i, p in ipairs(parts) do
		if p.slot == slot and (shape == nil or p.shape == shape) then
			local P = Shapes.prepare(p, 1)
			if not best or P.volume > bv then
				best, bv = p, P.volume
			end
		end
	end
	return best
end

local function atLocal(host, lx, ly, lz)
	local P = Shapes.prepare(host, 1)
	return { host.pos[1] + lx * P.ux + ly * P.vx + lz * P.wx, host.pos[2] + lx * P.uy + ly * P.vy + lz * P.wy, host.pos[3] + lx * P.uz + ly * P.vz + lz * P.wz }
end

-- local rotations: which local axis of the deco runs along the host's axes
local X_TO_Z = axisAngle(0, 1, 0, -90) -- cylinder axis along the host's Z
local X_TO_Y = axisAngle(0, 0, 1, 90) -- cylinder axis along the host's Y
local CYCLE = { 0.5, 0.5, 0.5, 0.5 } -- local X -> host Y, local Y -> host Z, local Z -> host X

local BALL_TURNS = { { "unrot", I }, { "z45", axisAngle(0, 0, 1, 45) }, { "xy30", axisAngle(1, 1, 0, 30) }, { "r47", axisAngle(1, 2, 3, 47) } }

local function addDeco(out, family, base, params, deco, extra)
	-- deco: a list of new parts; the base's parts first, as a player adds decoration last
	local parts = L.copyParts(base.parts)
	if extra and extra.without then
		for i = #parts, 1, -1 do
			if extra.without(parts[i]) then
				table.remove(parts, i)
			end
		end
	end
	local counts = L.slotCounts(parts)
	for _, d in ipairs(deco) do
		local slot = L.freeSlot(counts, d.slot)
		if slot == nil then
			return
		end
		d.slot = slot
		counts[slot] += 1
		d.material = d.material or "Iron"
		table.insert(parts, d)
	end
	if #parts > 24 or not L.quickValid(parts) then
		return
	end
	local c = clean(parts)
	table.insert(out, { name = fmt("%s|%s|%s", family, base.tag, params), set = "plausible", family = family, base = base.tag, parts = c, decoFrom = #parts - #deco + 1 })
end

local function ballRivets(out, base)
	local guard, blade = largest(base.parts, "Guard", "Block"), largest(base.parts, "Blade", "Block")
	local pommel = largest(base.parts, "Pommel", "Block")
	local grip = largest(base.parts, "Grip", "Block")
	local rows = {}
	if guard then
		local hx = guard.size[1] / 2
		table.insert(rows, { "guardZ", guard, { 0.08, 0.10, 0.14 }, { { 0.6 * hx, 0, 1 }, { -0.6 * hx, 0, 1 } }, 3 })
		table.insert(rows, { "guardX", guard, { 0.08, 0.10, 0.14 }, { { 0, 0, 2 } }, 1 })
	end
	if blade then
		local hy = blade.size[2] / 2
		table.insert(rows, { "bladeZ", blade, { 0.08, 0.10, 0.14 }, { { 0, -0.5 * hy, 1 }, { 0, 0, 1 }, { 0, 0.5 * hy, 1 } }, 3 })
	end
	if pommel or grip then
		local host = pommel or grip
		table.insert(rows, { "hiltZ", host, { 0.10, 0.14, 0.20 }, { { 0, 0, 1 } }, 3 })
	end
	for _, row in ipairs(rows) do
		local tag, host, diam, spots, axis = row[1], row[2], row[3], row[4], row[5]
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
						table.insert(deco, { label = "Rivet", slot = host.slot, shape = "Ball", pos = atLocal(host, lp[1], lp[2], lp[3]), rot = compose(host.rot, turn[2]), size = { d, d, d } })
					end
					addDeco(out, "ballRivet", base, fmt("%s d%.2f %s cap%.4f", tag, d, turn[1], s), deco)
				end
			end
		end
	end
end

local POKES = { -0.01, -0.002, 0, 0.0005, 0.001, 0.002, 0.005, 0.01, 0.02, 0.03, 0.05 }

local function cylRivets(out, base)
	local guard, blade = largest(base.parts, "Guard", "Block"), largest(base.parts, "Blade", "Block")
	for _, row in ipairs({ { "guard", guard, 1 }, { "blade", blade, 3 } }) do
		local tag, host, n = row[1], row[2], row[3]
		if host then
			for _, r in ipairs({ 0.03, 0.05, 0.08 }) do
				for _, tilt in ipairs({ 0, 8, 20 }) do
					for _, t in ipairs(POKES) do
						local hz = host.size[3] / 2
						-- a pin: the length of the host's thickness, poking t out of +Z and buried or poking at the other side
						local len = 2 * hz
						local deco = {}
						for k = 1, n do
							local along = if n == 1 then 0 else (k - 2) * 0.5 * host.size[2] / 2
							local across = if n == 1 then 0.6 * host.size[1] / 2 else 0
							local lp = { across, along, hz + t - len / 2 }
							local q = compose(host.rot, compose(axisAngle(1, 0, 0, tilt), X_TO_Z))
							table.insert(deco, { label = "Pin", slot = host.slot, shape = "Cylinder", pos = atLocal(host, lp[1], lp[2], lp[3]), rot = q, size = { len, 2 * r, 2 * r } })
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
local function cylRibs(out, base)
	local guard, blade, grip = largest(base.parts, "Guard", "Block"), largest(base.parts, "Blade", "Block"), largest(base.parts, "Grip", "Block")
	for _, row in ipairs({ { "blade", blade, 2 }, { "guard", guard, 1 }, { "grip", grip, 2 } }) do
		local tag, host, longAxis = row[1], row[2], row[3]
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

-- a plate inside a host, one rim poking past the host's edge by p
local function plateEdges(out, base)
	local guard, blade = largest(base.parts, "Guard", "Block"), largest(base.parts, "Blade", "Block")
	for _, row in ipairs({ { "blade", blade }, { "guard", guard } }) do
		local tag, host = row[1], row[2]
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
	-- the verifier's C09 plates, and their kin
	if base.tag == "C09" then
		for _, def in ipairs({ { 0.12, 2.0, 0.05, -0.03 }, { 0.09, 2.0, 0.04, -0.05 }, { 0.10, 2.0, 0.05, -0.04 }, { 0.08, 2.0, 0.04, -0.05 }, { 0.11, 1.2, 0.056, -0.03 }, { 0.11, 1.2, 0.056, 0.03 }, { 0.11, 2.0, 0.056, -0.03 }, { 0.08, 2.0, 0.04, -0.05 }, { 0.06, 2.0, 0.03, -0.07 }, { 0.06, 1.0, 0.03, -0.07 } }) do
			addDeco(out, "plateC09", base, fmt("%.2f x %.1f x %.3f at x %.2f", def[1], def[2], def[3], def[4]), { { label = "X", slot = "Blade", shape = "Block", pos = { def[4], 2.6, 0 }, rot = I, size = { def[1], def[2], def[3] } } })
		end
	end
end

-- a plate turned about the host's Y so that one rim rises above the face
local function plateTilts(out, base)
	local blade = largest(base.parts, "Blade", "Block")
	if not blade then return end
	local W, Ln, T = blade.size[1], blade.size[2], blade.size[3]
	for _, tilt in ipairs({ 1, 2, 4, 8 }) do
		for _, p in ipairs({ 0, 0.001, 0.002, 0.005, 0.01, 0.015, 0.02, 0.03 }) do
			local w, k, len = 0.8 * W, math.max(0.5 * T, 0.02), 0.8 * Ln
			local a = math.rad(tilt)
			-- the high rim's top corner at z = T/2 + p
			local z = T / 2 + p - (w / 2 * math.sin(a) + k / 2 * math.cos(a))
			local deco = { { label = "Tilted", slot = "Blade", shape = "Block", pos = atLocal(blade, 0, 0, z), rot = compose(blade.rot, axisAngle(0, 1, 0, -tilt)), size = { w, len, k } } }
			addDeco(out, "plateTilt", base, fmt("tilt%d poke%.3f", tilt, p), deco)
		end
	end
end

local FRACTIONS = { 0.02, 0.03, 0.05, 0.075, 0.1, 0.15, 0.2, 0.3, 0.5, 0.75, 1.0 }

-- a wedge along the blade near its edge, its base sunk into the face
local function bevels(out, base)
	local blade = largest(base.parts, "Blade", "Block")
	if not blade then return end
	local centred = math.abs(blade.pos[1]) < 1e-9 and blade.rot[1] == 0 and blade.rot[2] == 0 and blade.rot[3] == 0
	for _, a in ipairs({ 0.02, 0.03, 0.05 }) do
		for _, b in ipairs({ 0.03, 0.05, 0.08 }) do
			for _, f in ipairs(FRACTIONS) do
				local len = 0.85 * blade.size[2]
				local lx = blade.size[1] / 2 - b / 2
				local lz = blade.size[3] / 2 + f * a - a / 2
				local w = { label = "Bevel", slot = "Blade", shape = "Wedge", pos = atLocal(blade, lx, 0, lz), rot = compose(blade.rot, CYCLE), size = { len, a, b } }
				local deco = { w }
				if centred then
					local m = Fx.mirrorX(w, "BevelL")
					table.insert(deco, { label = "BevelL", slot = "Blade", shape = m.shape, pos = m.pos, rot = m.rot, size = m.size })
				end
				addDeco(out, "bevel", base, fmt("a%.2f b%.2f height%.3f", a, b, f), deco)
			end
		end
	end
end

-- the blade block replaced by two cheeks and a core, recessed or proud at the rims, with or without a cap on top
local function laminates(out, base)
	local blade = largest(base.parts, "Blade", "Block")
	if not blade or base.tag == "C09" or base.tag == "C06" then return end
	for _, k in ipairs({ 0.02, 0.03 }) do
		for _, wf in ipairs({ 1, 1.5, 2 }) do
			for _, p in ipairs({ -0.02, -0.01, -0.005, 0, 0.003, 0.005, 0.0075, 0.01, 0.015, 0.02 }) do
				for _, cap in ipairs({ false, true }) do
					local c = math.max((blade.size[3] - k) / 2, 0.02)
					local w = math.min(blade.size[1] * wf, 1.2)
					local deco = {
						{ label = "CheekA", slot = "Blade", shape = "Block", pos = atLocal(blade, 0, 0, k / 2 + c / 2), rot = blade.rot, size = { w, blade.size[2], c } },
						{ label = "CheekB", slot = "Blade", shape = "Block", pos = atLocal(blade, 0, 0, -(k / 2 + c / 2)), rot = blade.rot, size = { w, blade.size[2], c } },
					}
					if cap then
						table.insert(deco, { label = "Top", slot = "Blade", shape = "Block", pos = atLocal(blade, 0, blade.size[2] / 2 + 0.02, 0), rot = blade.rot, size = { w, 0.04, k + 2 * c } })
					end
					table.insert(deco, { label = "LamCore", slot = "Blade", shape = "Block", material = "Steel", pos = atLocal(blade, 0, 0, 0), rot = blade.rot, size = { w + 2 * p, blade.size[2], k } })
					addDeco(out, "laminate", base, fmt("k%.2f wf%.1f proud%.4f cap%s", k, wf, p, tostring(cap)), deco, { without = function(q) return q == blade end })
				end
			end
		end
	end
end

-- the verifier's laminated hilt
local function lamHilt(out)
	local RZ90 = { 0, 0, SQ, SQ }
	for _, w in ipairs({ 0.6, 0.8, 0.9, 1.0, 1.1, 1.2 }) do
		for _, l in ipairs({ 2.0, 3.0 }) do
			for _, c in ipairs({ 0.025, 0.05 }) do
				for _, k in ipairs({ 0.02, 0.03 }) do
					for _, p in ipairs({ -0.02, -0.01, 0, 0.005, 0.01, 0.02, 0.03 }) do
						for _, cap in ipairs({ false, true }) do
							local y = 1.45 + l / 2
							local parts = {
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
							if L.quickValid(parts) then
								table.insert(out, { name = fmt("lamHilt|hilt|w%.1f l%.1f c%.3f k%.2f proud%.3f cap%s", w, l, c, k, p, tostring(cap)), set = "plausible", family = "lamHilt", base = "hilt", parts = clean(parts), decoFrom = #parts })
							end
						end
					end
				end
			end
		end
	end
end

-- rings around a grip, covering it all but the gaps between them
local function wrapRings(out, base)
	local grip = largest(base.parts, "Grip")
	if not grip or grip.shape == "Ball" then return end
	local cylinder = grip.shape == "Cylinder"
	-- the grip's long axis and its thickness
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

-- a ball pommel mostly inside a block: the ball pokes out of the block's bottom
local function pommelInBlock(out, base)
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
				local deco = { { label = "Housing", slot = "Pommel", shape = "Block", pos = { ball.pos[1], c + side / 2, ball.pos[3] }, rot = I, size = { side, side, side } } }
				-- the ball itself with the turn: replace it
				addDeco(out, "pommelInBlock", base, fmt("housing %s cap%.4f", turn[1], s), deco, { without = function(q)
					return false
				end })
				local row = out[#out]
				if row and row.family == "pommelInBlock" and string.find(row.name, fmt("housing %s cap%.4f", turn[1], s), 1, true) then
					for _, q in ipairs(row.parts) do
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
				local deco = { { label = "Nut", slot = "Pommel", shape = "Ball", pos = atLocal(block, lp[1], lp[2], lp[3]), rot = compose(block.rot, turn[2]), size = { d, d, d } } }
				addDeco(out, "pommelInBlock", base, fmt("nut %s cap%.4f", turn[1], s), deco)
			end
		end
	end
end

-- wedges and corner wedges sunk in the guard's top, apex up
local function wedgesInGuard(out, base)
	local guard = largest(base.parts, "Guard", "Block")
	if not guard then return end
	for _, shape in ipairs({ "Wedge", "CornerWedge" }) do
		for _, size in ipairs({ { 0.12, 0.12, 0.16 }, { 0.2, 0.15, 0.1 }, { 0.1, 0.25, 0.1 } }) do
			for _, spin in ipairs({ 0, 30 }) do
				for _, f in ipairs({ 0.02, 0.03, 0.05, 0.075, 0.1, 0.15, 0.2, 0.3, 0.5, 0.75 }) do
					local lx = 0.7 * guard.size[1] / 2
					local ly = guard.size[2] / 2 + f * size[2] - size[2] / 2
					local q = compose(guard.rot, axisAngle(0, 1, 0, spin))
					local deco = {}
					local a = { label = "Finial", slot = "Guard", shape = shape, pos = atLocal(guard, lx, ly, 0), rot = q, size = { size[1], size[2], size[3] } }
					table.insert(deco, a)
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
local function rods(out, base)
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
						size = if shape == "Block" then { len, d, d } else { len, d, d }
						q = grip.rot
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
					local size = { len, d, d }
					addDeco(out, "rod", base, fmt("guard %s d%.2f poke%.4f", shape, d, p), { { label = "Rod", slot = "Guard", shape = shape, pos = atLocal(guard, 0, off, 0), rot = guard.rot, size = size } })
				end
			end
		end
	end
end

function Sets.plausible()
	local out = {}
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
	return out
end

-- ── fuzz ──────────────────────────────────────────────────────────────────────────────────────────────────────────

function Sets.fuzz()
	local out = {}
	local ctx = Gen.context(Limits, EquipmentTypes.get("Sword"), Materials.enabled, Versions.BLUEPRINT_SCHEMA, Balance.Geometry)
	local rng = TestRng.new(20261103)
	for k = 1, 2000 do
		local sword = Gen.validSword(rng:fork(k), ctx)
		local filled = Gen.withFiller(rng:fork(100000 + k), ctx, sword)
		table.insert(out, { name = "validSword+filler|" .. k, set = "fuzz", family = "validSword", parts = clean(filled.parts) })
	end
	local rng2 = TestRng.new(19700101)
	for k = 1, 3000 do
		local d = H.anyDesign(rng2:fork(k))
		table.insert(out, { name = "anyDesign|" .. k, set = "fuzz", family = "anyDesign", parts = clean(d.parts) })
	end
	return out
end

-- ── poke: any shape, any turn, sunk across 2 % ────────────────────────────────────────────────────────────────────

function Sets.poke()
	local out = {}
	local rng = L.rng(424242)
	local list = bases()
	local SHAPES = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
	for k = 1, 5000 do
		local base = rng.pick(list)
		local parts = L.copyParts(base.parts)
		local host = parts[rng.int(1, #parts)]
		local P = Shapes.prepare(host, 1)
		local shape = rng.pick(SHAPES)
		local a = rng.range(0.03, 0.3)
		local size
		if shape == "Ball" then
			size = { a, a, a }
		elseif shape == "Cylinder" then
			size = { rng.range(0.03, 1.0), a, a }
		else
			size = { rng.range(0.03, 0.5), rng.range(0.03, 1.0), rng.range(0.03, 0.3) }
		end
		local rot = if rng.float() < 0.5 then rng.quat() elseif rng.float() < 0.5 then rng.smallTilt(30) else I
		local X = { label = "X", slot = host.slot, shape = shape, material = "Iron", pos = { P.gx, P.gy, P.gz }, rot = rot, size = size }
		-- the direction it leaves the host along, in the host's frame: a random unit vector, biased to the axes
		local dx, dy, dz = rng.range(-1, 1), rng.range(-1, 1), rng.range(-1, 1)
		if rng.float() < 0.5 then
			local ax = rng.int(1, 3)
			dx, dy, dz = if ax == 1 then 1 else 0, if ax == 2 then 1 else 0, if ax == 3 then 1 else 0
			if rng.float() < 0.5 then dx, dy, dz = -dx, -dy, -dz end
		end
		local n = math.sqrt(dx * dx + dy * dy + dz * dz) + 1e-9
		dx, dy, dz = dx / n, dy / n, dz / n
		local wx = dx * P.ux + dy * P.vx + dz * P.wx
		local wy = dx * P.uy + dy * P.vy + dz * P.wy
		local wz = dx * P.uz + dy * P.vz + dz * P.wz
		-- bisect the push along that direction until the oracle-free cheap test: the share of the host-only hiding crosses a target, via a small lattice
		-- (the real share is the oracle's later): find the push at which the part's far end has just left the host, then back off by a random small amount
		local Q = Shapes.prepare(X, 2)
		local lo, hi = 0, 3
		local function outsideAt(t)
			-- is the farthest point along d outside the host?
			local x0, y0, z0 = Shapes.support(Shapes.prepare(X, 2), wx, wy, wz)
			return Shapes.sd(P, x0 + t * wx, y0 + t * wy, z0 + t * wz) > 0
		end
		if not outsideAt(0) then
			for _ = 1, 30 do
				local mid = (lo + hi) / 2
				if outsideAt(mid) then hi = mid else lo = mid end
			end
		else
			hi = 0
		end
		local extent = math.max(size[1], size[2], size[3])
		local push = hi + extent * rng.pick({ 0.002, 0.005, 0.01, 0.02, 0.03, 0.05, 0.075, 0.1, 0.15, 0.2, 0.3 })
		X.pos = { X.pos[1] + push * wx, X.pos[2] + push * wy, X.pos[3] + push * wz }
		local counts = L.slotCounts(parts)
		local slot = L.freeSlot(counts, host.slot, rng)
		if slot then
			X.slot = slot
			if rng.float() < 0.25 then
				table.insert(parts, 1, X) -- a lower index than everything
			else
				table.insert(parts, X)
			end
			if L.quickValid(parts) then
				table.insert(out, { name = fmt("poke|%s|%d %s", base.tag, k, shape), set = "poke", family = "poke", base = base.tag, parts = clean(parts) })
			end
		end
	end
	return out
end

function Sets.get(name)
	if name == "fixtures" then
		return Sets.fixtures()
	elseif name == "plausible" then
		return Sets.plausible()
	elseif name == "fuzz" then
		return Sets.fuzz()
	elseif name == "poke" then
		return Sets.poke()
	end
	error("no set " .. tostring(name))
end

return Sets
