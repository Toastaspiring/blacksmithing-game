--!strict
-- T-PHY-09's Enclosed verdict (SPEC §4.4, §5, E-S2.11, E-S2.12): each part's polyhedral model against every part but exact
-- copies and Dust, with no budget of its own (Physics/Cover). What other parts, ids and order cannot do to it, and what it
-- reads, to the bit, on designs small enough to have a closed form. Cover.spec holds the model itself, the subtraction against
-- a brute force, the attack designs and the cap.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Drafts = require("../Blueprint/Drafts")
local Blueprints = require("../fixtures/Blueprints")
local H = require("./PhysicsHelpers")
local Oracle = require("./VisibleOracle")
local Balance = require("../../src/shared/Definitions/Balance")
local Quat = require("../../src/shared/Blueprint/Quat")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

-- Through a cast, as in Reference.spec: reference data, not game code.
local Fixtures: any = (require :: any)("../../docs/spec/prototypes/S2/v2/fixtures")

type Rng = TestRng.TestRng

local Geo = Balance.Geometry
local EPS = Geo.EPS_GEOM -- what a hide test grants at a part's edge: a slit between two reads this much narrower each side
local EXACT = 1e-12 -- what rounding leaves of a reading, in share of the area (E-S2.12 measures 2.6e-13 at worst)

local function shareOf(list: { any }, i: number): number
	local _, _, hider = Oracle.flags(list)
	return Oracle.measure(list, i, hider, Oracle.COARSE_POINTS)
end

-- A smaller copy of a part about its centroid, inside it whatever its shape.
local function shrunk(host: any, f: number, id: number, slot: string): any
	local P = H.prepare(host)
	return H.part(id, slot, host.shape, "Iron", { P.gx + f * (host.pos[1] - P.gx), P.gy + f * (host.pos[2] - P.gy), P.gz + f * (host.pos[3] - P.gz) },
		host.rot, { host.size[1] * f, host.size[2] * f, host.size[3] * f })
end

-- The next free slot, Blade first (fill need not show where it stands).
local function slotFor(parts: { any }): string
	local MAX: { [string]: number } = { Blade = 12, Guard = 8, Grip = 6, Pommel = 4 }
	local count: { [string]: number } = { Blade = 0, Guard = 0, Grip = 0, Pommel = 0 }
	for _, p in ipairs(parts) do
		count[p.slot] += 1
	end
	for _, slot in ipairs({ "Blade", "Guard", "Grip", "Pommel" }) do
		if count[slot] < MAX[slot] then
			return slot
		end
	end
	error("no slot left")
end

-- One filler that cannot cover anything its host does not: well inside a part, Dust anywhere, or an exact copy (in front of its
-- original a copy would be the original, and so it would in a slot whose name comes first: `copies` says whether it may come).
local function fillerFor(rng: Rng, K: { any }, id: number, slot: string, copies: boolean): any
	local host = rng:pick(K)
	local kind = rng:int(1, 5)
	if kind == 5 then
		local d = rng:range(0.02, 0.0575)
		return H.part(id, slot, rng:pick({ "Block", "Ball", "Wedge", "Cylinder" }), "Iron", { rng:range(-0.7, 0.7), rng:range(0.1, 4.9), rng:range(-0.25, 0.25) },
			H.randomQuat(rng), { d, d, d })
	elseif kind == 4 and copies and slot >= host.slot then
		local copy = Drafts.deepCopy(host)
		copy.id, copy.slot = id, slot
		return copy
	elseif kind == 3 and host.shape == "Block" then
		-- turned, half its diagonal under half the host's least size
		local P = H.prepare(host)
		local d = math.min(host.size[1], host.size[2], host.size[3]) * rng:range(0.15, 0.4)
		return H.part(id, slot, rng:pick({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }), "Iron", { P.gx, P.gy, P.gz }, H.randomQuat(rng), { d, d, d })
	end
	return shrunk(host, if rng:float() < 0.5 then rng:range(0.1, 0.6) else rng:range(0.6, 0.97), id, slot)
end

-- A large design: C09 as it stands, or P1 less a third or a half of its parts, whose kept parts are past N_SURF_WORK all the same.
local function largeDesign(rng: Rng): any
	if rng:float() < 0.7 then
		return H.ornate()
	end
	local base = H.p1()
	for _ = 1, rng:int(8, 12) do
		table.remove(base.parts, rng:int(1, #base.parts))
	end
	for i, p in ipairs(base.parts) do
		p.id = i
	end
	return base
end

local function randomFill(rng: Rng, copies: boolean): any
	local base = largeDesign(rng)
	local filled = Drafts.deepCopy(base)
	local count = rng:int(1, 24 - #base.parts)
	for k = 1, count do
		table.insert(filled.parts, fillerFor(rng, base.parts, 100 + k, slotFor(filled.parts), copies))
	end
	return { base = base, filled = filled, count = count }
end

local function fillLeavesKept(count: number)
	local ornate = Sampling.exposure(H.prepared(H.ornate()))
	Prop.check(count, function(rng: Rng): any
		return randomFill(rng, true)
	end, function(c: any)
		local before = if c.base.name == "C09" then ornate else Sampling.exposure(H.prepared(c.base))
		local after = Sampling.exposure(H.prepared(c.filled))
		A.eq(#after.cleaned, #before.cleaned + c.count, "all the fill is cleaned")
		A.eq(after.surfSamples, before.surfSamples, "and not measured")
		A.eq(after.subSampled, before.subSampled, "and uses none of the sub-grid budget")
		H.sameKeptMeasure(after, before, #c.base.parts)
	end)
end
-- ── a plate under lids ────────────────────────────────────────────────────────────────────────────────────────────

-- H.partsUnder's plate: only its top shows, lids stand on it, each { x0, x1, z0, z1 }; FAR is past the plate's rim.
local PLATE_AREA = H.PLATE_AREA
local FAR = 0.5
local WALLS = 6 -- the parts of the plate's surround and the plate itself
local partsUnder, underLids = H.partsUnder, H.underLids

local function keptOf(list: { any }, i: number): boolean
	return Sampling.exposure(list).kept[i]
end

-- What the verdict reads on part i, against its closed form, to rounding.
local function exactly(list: { any }, i: number, want: number, what: string)
	A.near((H.reads(list, i)), want, EXACT, what)
end

-- A slit of width g along Z through the plate's top, centred on x = c, between 2 lids, and more lids.
local function slit(g: number, c: number, extra: { { number } }?): { any }
	local lids = { { -FAR, c - g / 2, -FAR, FAR }, { c + g / 2, FAR, -FAR, FAR } }
	for _, lid in ipairs(extra or {}) do
		table.insert(lids, lid)
	end
	return underLids(lids)
end

return Test.suite("Physics/Verdict", function(t)
	-- ── independence: a verdict depends on the part and on what covers it ─────────────────────────────────────────

	-- { width, length, thickness, x } in C09's blade. The old rule cleaned each with 0–5 hidden blocks: Hard to Normal.
	local PLATES = { { 0.12, 2, 0.05, -0.03 }, { 0.09, 2, 0.04, -0.05 }, { 0.10, 2, 0.05, -0.04 }, { 0.08, 2, 0.04, -0.05 }, { 0.06, 2, 0.03, -0.07 },
		{ 0.06, 1, 0.03, -0.07 } }
	t.it("§5 hidden blocks cannot clean a plate that shows: C09 + a plate that shows 17–27 %, with and without fill", function()
		local SLOTS = { "Guard", "Guard", "Guard", "Blade", "Blade", "Blade" }
		for _, plate in ipairs(PLATES) do
			local base = H.ornate()
			table.insert(base.parts, H.part(50, "Blade", "Block", "Iron", { plate[4], 2.6, 0 }, H.I, { plate[1], plate[2], plate[3] }))
			local core = base.parts[12]
			local index = #base.parts
			local list = H.prepared(base)
			local what = "plate " .. plate[1] .. " × " .. plate[2]
			local before = Sampling.exposure(list)
			A.deepEq(before.cleaned, {}, what .. " is kept with the rest")
			A.within(shareOf(list, index), 0.17, 0.27, what .. " shows")
			for n = 1, #SLOTS do
				local filled = Drafts.deepCopy(base)
				for k = 1, n do
					local g = 0.8 - 0.01 * k
					table.insert(filled.parts, H.part(100 + k, SLOTS[k], "Block", "Iron", core.pos, core.rot, { core.size[1] * g, core.size[2] * g, core.size[3] * g }))
				end
				local after = Sampling.exposure(H.prepared(filled))
				A.eq(#after.cleaned, n, what .. ": only the fill is cleaned, n = " .. n)
				H.sameKeptMeasure(after, before, #base.parts)
			end
		end
	end)

	t.it("§5 a Dust hairline hides nothing: a laminated blade's core stays kept with a speck along its rim", function()
		local y = 1.45 + 2.5 / 2
		local base = H.core("laminated", {
			H.part(1, "Pommel", "Ball", "Iron", { 0, 0.3, 0 }, H.I, { 0.3, 0.3, 0.3 }),
			H.part(2, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, H.Z90, { 0.9, 0.16, 0.16 }),
			H.part(3, "Guard", "Block", "Iron", { 0, 1.4, 0 }, H.I, { 1.1, 0.16, 0.3 }),
			H.part(4, "Blade", "Block", "Iron", { 0, y, 0.035 }, H.I, { 1.2, 2.5, 0.05 }),
			H.part(5, "Blade", "Block", "Iron", { 0, y, -0.035 }, H.I, { 1.2, 2.5, 0.05 }),
			H.part(6, "Blade", "Block", "Steel", { 0, y, 0 }, H.I, { 1.2, 2.5, 0.02 }),
		})
		local before = Sampling.exposure(H.prepared(base))
		A.truthy(before.kept[6], "the core is kept")
		local filled = Drafts.deepCopy(base)
		table.insert(filled.parts, H.part(7, "Blade", "Block", "Iron", { 0.6095, 2.7, 0 }, H.I, { 0.019, 0.5, 0.02 }))
		local list = H.prepared(filled)
		local after = Sampling.exposure(list)
		A.deepEq(after.cleaned, { { partId = 7, reason = "Dust" } })
		A.eq(after.surfSamples, before.surfSamples)
		H.sameKeptMeasure(after, before, 6)
	end)

	-- The channel a budget leaves: hidden copies stand near every sample of X, so each sample would pay for them. With no
	-- budget there is nothing to use up. X pokes out of F4's blade, on either side of its threshold.
	t.it("§4.4 hidden copies inside a part use up nothing: the same verdict with 3, 9 and 18 of them", function()
		local F4 = H.f("F4")
		local host = F4.parts[4]
		local size = { host.size[1] * 0.95, host.size[2] * 0.95, host.size[3] * 0.5 }
		local function designOf(poke: number, n: number): any
			local design = Drafts.deepCopy(F4)
			local X = H.part(50, "Blade", "Block", "Iron", { host.pos[1], host.pos[2] - (host.size[2] / 2 - size[2] / 2 + poke), host.pos[3] }, host.rot, size)
			table.insert(design.parts, X)
			for k = 1, n do
				table.insert(design.parts, shrunk(X, 0.985 - 0.012 * k, 100 + k, slotFor(design.parts)))
			end
			return design
		end
		local index = #F4.parts + 1
		local kept = Sampling.exposure(H.prepared(designOf(0.0747, 0)))
		A.truthy(kept.kept[index], "kept at this poke")
		local cleaned = Sampling.exposure(H.prepared(designOf(0.001, 0)))
		A.falsy(cleaned.kept[index], "cleaned at that one")
		for _, n in ipairs({ 3, 9, 18 }) do
			local after = Sampling.exposure(H.prepared(designOf(0.0747, n)))
			A.eq(#after.cleaned, n, "only the copies are cleaned, n = " .. n)
			H.sameKeptMeasure(after, kept, index)
			H.sameKeptMeasure(Sampling.exposure(H.prepared(designOf(0.001, n))), cleaned, index)
		end
	end)

	-- Fast until M3's fix round 1 (§14.1's 27 s); its designs are the first of the FUZZ_N_VALID case's.
	t.slow("§5 random fill around a large design: kept parts bit-identical, 40 designs", function()
		fillLeavesKept(40)
	end)
	t.slow("§5 random fill around a large design: kept parts bit-identical, FUZZ_N_VALID designs", function()
		fillLeavesKept(Tol.FUZZ_N_VALID)
	end)

	-- Any order of the fill, before or among the kept parts: Cover takes its hiders in rank order, so the order reaches nothing.
	local function shuffled(rng: Rng, list: { any }): { any }
		local out = table.clone(list)
		for i = #out, 2, -1 do
			local j = rng:int(1, i)
			out[i], out[j] = out[j], out[i]
		end
		return out
	end

	t.it("§4.4 the order of the fill changes no bit: before or among the kept parts, 20 designs", function()
		Prop.check(20, function(rng: Rng): any
			local c = randomFill(rng, false)
			local fill = shuffled(rng, { table.unpack(c.filled.parts, #c.base.parts + 1) })
			-- the kept parts in their order, the fill anywhere among them
			local parts: { any } = {}
			local a, b = 1, 1
			while a <= #c.base.parts or b <= #fill do
				if b > #fill or (a <= #c.base.parts and rng:float() < 0.5) then
					table.insert(parts, c.base.parts[a])
					a += 1
				else
					table.insert(parts, fill[b])
					b += 1
				end
			end
			return { base = c.base, parts = parts, count = #fill }
		end, function(c: any)
			local before = Sampling.exposure(H.prepared(c.base))
			local after = Sampling.exposure(H.prepared({ parts = c.parts }))
			A.eq(#after.cleaned, #before.cleaned + c.count, "all the fill is cleaned")
			local position: { [number]: number } = {}
			for i, p in ipairs(c.parts) do
				position[p.id] = i
			end
			A.eq(after.hSurf, before.hSurf)
			A.eq(after.surfSamples, before.surfSamples)
			for i, p in ipairs(c.base.parts) do
				local at = position[p.id]
				A.eq(after.kept[at], before.kept[i], "part " .. i .. "'s verdict")
				A.eq(after.exposedKept[at], before.exposedKept[i], "part " .. i .. "'s area")
				for j, q in ipairs(c.base.parts) do
					A.eq(after.contact[at][position[q.id]], before.contact[i][j], "contact " .. i .. ", " .. j)
				end
			end
		end)
	end)

	-- Candidates in every order, by exact numbers: the slit under 3 lids, and the slab, the plate first. Cover takes its hiders in
	-- rank order, so the order of the parts reaches nothing, to the bit.
	t.it("§4.4 the order of the parts changes no bit: what the verdict reads, every order of 4 candidates", function()
		local g = 0.03
		local lids = { { -FAR, 0.0625 - g / 2, -FAR, FAR }, { 0.0625 + g / 2, FAR, -FAR, FAR }, { -FAR, FAR, 0.125, FAR } }
		local list = partsUnder(lids)
		local plate, walls = list[1], { list[3], list[4], list[5], list[6] }
		local others = { list[2], list[7], list[8], list[9] }
		local function permutations(n: number, visit: () -> ())
			if n <= 1 then
				visit()
				return
			end
			for i = 1, n do
				others[i], others[n] = others[n], others[i]
				permutations(n - 1, visit)
				others[i], others[n] = others[n], others[i]
			end
		end
		local first: number? = nil
		local orders = 0
		permutations(#others, function()
			local order = H.prepared({ parts = { plate, others[1], others[2], others[3], others[4], walls[1], walls[2], walls[3], walls[4] } })
			local share = H.reads(order, 1)
			first = first or share
			A.eq(share, first, "the same bits in every order")
			orders += 1
		end)
		A.eq(orders, 24)
		A.near(first :: number, (g - 2 * EPS) * (0.375 - EPS) / PLATE_AREA, EXACT, "the slit's area")
		A.truthy(keptOf(underLids(lids), 1), "2.08 %: kept")
	end)

	-- The verdict, the measure and its budgets go by the solids. Any order of a design's parts, the same parts by id, to the bit: past
	-- N_SUB_WORK too, on the large designs.
	local function sameInAnyOrder(parts: { any }, order: { any })
		local a, b = Sampling.exposure(H.prepared({ parts = parts })), Sampling.exposure(H.prepared({ parts = order }))
		A.eq(a.hSurf, b.hSurf)
		A.eq(a.surfSamples, b.surfSamples)
		A.eq(a.subSampled, b.subSampled)
		local position: { [number]: number } = {}
		for i, p in ipairs(order) do
			position[p.id] = i
		end
		for i, p in ipairs(parts) do
			local at = position[p.id]
			A.eq(a.kept[i], b.kept[at], "part " .. p.id .. "'s verdict")
			A.eq(a.exposedKept[i], b.exposedKept[at], "part " .. p.id .. "'s area")
			for j, q in ipairs(parts) do
				A.eq(a.contact[i][j], b.contact[at][position[q.id]], "contact " .. p.id .. ", " .. q.id)
			end
		end
	end

	t.it("§4.4 ids play no part: any order of a design's parts, 20 designs and 5 past N_SUB_WORK", function()
		Prop.check(20, function(rng: Rng): any
			local design = H.anyDesign(rng)
			return { parts = design.parts, order = shuffled(rng, design.parts) }
		end, function(c: any)
			sameInAnyOrder(c.parts, c.order)
		end)
		Prop.check(5, function(rng: Rng): any
			local design = largeDesign(rng)
			return { parts = design.parts, order = shuffled(rng, design.parts) }
		end, function(c: any)
			sameInAnyOrder(c.parts, c.order)
		end)
	end)

	-- Plates wholly inside a part flush with its faces, which they cover. By id a plate kept the face and the part, its faces all
	-- taken, read nothing: solid in mass, hollow in D. The larger part keeps the face, whatever the ids and whatever the
	-- labels: plates in the Blade lose the faces of a Guard they lie in as those in the Guard or the Pommel lose a blade's.
	local function skins(h: any, slots: { string }): { any }
		local tz = math.min(0.02, h.size[3] / 3)
		local tx = math.min(0.02, h.size[1] / 3)
		return {
			H.part(101, slots[1], "Block", "Iron", { h.pos[1], h.pos[2], h.pos[3] + (h.size[3] - tz) / 2 }, h.rot, { h.size[1], h.size[2], tz }),
			H.part(102, slots[1], "Block", "Iron", { h.pos[1], h.pos[2], h.pos[3] - (h.size[3] - tz) / 2 }, h.rot, { h.size[1], h.size[2], tz }),
			H.part(103, slots[2], "Block", "Iron", { h.pos[1] + (h.size[1] - tx) / 2, h.pos[2], h.pos[3] }, h.rot, { tx, h.size[2], h.size[3] }),
			H.part(104, slots[2], "Block", "Iron", { h.pos[1] - (h.size[1] - tx) / 2, h.pos[2], h.pos[3] }, h.rot, { tx, h.size[2], h.size[3] }),
		}
	end

	-- Every plate cleaned, every part of the design kept and measured as without them.
	local function skinsCleaned(design: any, plates: { any }, what: string)
		local before = Sampling.exposure(H.prepared(design))
		local first: { any } = table.clone(plates)
		for _, p in ipairs(design.parts) do
			table.insert(first, p)
		end
		local after = Sampling.exposure(H.prepared({ parts = first }))
		for k = 1, #plates do
			A.falsy(after.kept[k], what .. ": plate " .. k .. " in the " .. plates[k].slot .. " is cleaned, its host keeps the faces")
		end
		for i = 1, #design.parts do
			A.eq(after.kept[#plates + i], before.kept[i], what .. " part " .. i)
			A.eq(after.exposedKept[#plates + i], before.exposedKept[i], what .. " part " .. i .. " measures as without them")
		end
	end

	t.it("§4.4 flush plates inside a real blade are the ones cleaned, whatever their ids and slots", function()
		local checked = 0
		for _, name in ipairs({ "F1", "F5", "F4", "F3" }) do
			local design = H.f(name)
			local main = 0
			for i, p in ipairs(design.parts) do
				if p.slot == "Blade" and (main == 0 or H.prepare(p).volume > H.prepare(design.parts[main]).volume) then
					main = i
				end
			end
			local h = design.parts[main]
			if h.shape == "Block" and h.rot[4] == 1 then
				checked += 1
				for _, slots in ipairs({ { "Guard", "Pommel" }, { "Blade", "Blade" }, { "Blade", "Grip" } }) do
					skinsCleaned(design, skins(h, slots), name)
				end
			end
		end
		A.truthy(checked >= 3, "main blades that are upright Blocks: " .. checked)
	end)

	-- §5: filler buys no face. With the slot's name before the size, 4 plates 0.02 thick flush inside F5's guard, labelled
	-- Blade, kept the guard's faces and Sharpening went 0.0989 Normal → 0.4201 Hard, past relabelling the guard (0.2804); one
	-- plate over a guard built in two halves, thinner than either, 0.3367. The larger part first, they are cleaned.
	t.it("§5 plates flush inside a guard, labelled Blade or Grip, are cleaned: F5, F3, a guard in two halves", function()
		for _, name in ipairs({ "F5", "F3" }) do
			local design = H.f(name)
			local guard: any = nil
			for _, p in ipairs(design.parts) do
				if p.slot == "Guard" and p.shape == "Block" then
					guard = p
				end
			end
			A.truthy(guard ~= nil and guard.rot[4] == 1, name .. ": an upright Block guard")
			for _, slots in ipairs({ { "Blade", "Blade" }, { "Grip", "Grip" } }) do
				skinsCleaned(design, skins(guard, slots), name .. "'s guard")
			end
			-- the guard as two halves side by side, one plate over both along its face
			local halves = H.f(name)
			for _, p in ipairs(halves.parts) do
				if p.slot == "Guard" and p.shape == "Block" then
					p.pos = { guard.pos[1] - guard.size[1] / 4, guard.pos[2], guard.pos[3] }
					p.size = { guard.size[1] / 2, guard.size[2], guard.size[3] }
				end
			end
			table.insert(halves.parts, H.part(#halves.parts + 1, "Guard", "Block", guard.material, { guard.pos[1] + guard.size[1] / 4, guard.pos[2], guard.pos[3] },
				H.I, { guard.size[1] / 2, guard.size[2], guard.size[3] }))
			local plate = H.part(101, "Blade", "Block", "Iron", { guard.pos[1], guard.pos[2], guard.pos[3] + (guard.size[3] - 0.02) / 2 }, H.I,
				{ guard.size[1], guard.size[2], 0.02 })
			skinsCleaned(halves, { plate }, name .. "'s guard in two halves")
		end
	end)

	-- An exact copy hides nothing and takes nothing, in front of its original or behind it, in another slot, while the original's
	-- slot's name comes first (a copy in one that comes before it is no more than relabelling the part).
	t.it("§4.4 an exact copy changes nothing: first or last, in a slot that comes later, in another material", function()
		for _, name in ipairs({ "F1", "F3", "F4" }) do
			local design = H.f(name)
			local before = Sampling.exposure(H.prepared(design))
			local n = #design.parts
			for i, p in ipairs(design.parts) do
				if p.slot == "Blade" then
					local later = Drafts.deepCopy(p)
					later.id, later.slot = 200, "Guard"
					local other = Drafts.deepCopy(p)
					other.id, other.material = 201, "Tin" -- a name that comes after any of them
					local first: { any } = { later, other }
					local last: { any } = {}
					for _, q in ipairs(design.parts) do
						table.insert(first, q)
						table.insert(last, q)
					end
					table.insert(last, Drafts.deepCopy(later))
					table.insert(last, Drafts.deepCopy(other))
					local after = Sampling.exposure(H.prepared({ parts = first }))
					A.deepEq({ after.kept[1], after.kept[2] }, { false, false }, name .. " part " .. i .. ": the copies are cleaned")
					local behind = Sampling.exposure(H.prepared({ parts = last }))
					A.deepEq({ behind.kept[n + 1], behind.kept[n + 2] }, { false, false }, name .. " part " .. i .. ": the copies last, cleaned")
					for j = 1, n do
						A.eq(after.exposedKept[2 + j], before.exposedKept[j], name .. " part " .. j)
						A.eq(behind.kept[j], before.kept[j], name .. " part " .. j .. ", the copies last: its verdict")
						A.eq(behind.exposedKept[j], before.exposedKept[j], name .. " part " .. j .. ", the copies last")
					end
				end
			end
		end
		-- among copies of one slot and material the lowest index stays; a copy of a part in a slot whose name comes after it loses
		local a = H.solid(1, "Block", { 0, 2, 0 }, H.I, { 0.2, 0.2, 0.2 }, "Guard")
		local b = H.solid(2, "Block", { 0, 2, 0 }, H.I, { 0.2, 0.2, 0.2 }, "Blade")
		A.deepEq(Sampling.exposure(H.prepared({ parts = { a, b } })).cleaned, { { partId = 1, reason = "Enclosed" } })
		A.deepEq(Sampling.exposure(H.prepared({ parts = { b, a } })).cleaned, { { partId = 1, reason = "Enclosed" } })
	end)

	t.it("§4.4 Sampling.ranked: the larger, the slot's name, then where it stands, |x| before x, |z| before z, whatever the order", function()
		local function row(parts: { any }): { number }
			local out: { number } = {}
			local _, order = Sampling.ranked(H.prepared({ parts = parts }))
			for i, p in ipairs(order) do
				out[i] = p.id
			end
			return out
		end
		local big = H.solid(1, "Block", { 0, 3, 0 }, H.I, { 0.4, 0.4, 0.4 })
		local low = H.solid(2, "Block", { 0.3, 1, 0 }, H.I, { 0.2, 0.2, 0.2 })
		local middle = H.solid(3, "Block", { 0.1, 2, 0 }, H.I, { 0.2, 0.2, 0.2 })
		local right = H.solid(4, "Block", { 0.3, 2, 0 }, H.I, { 0.2, 0.2, 0.2 })
		local left = H.solid(5, "Block", { -0.3, 2, 0 }, H.I, { 0.2, 0.2, 0.2 })
		local back = H.solid(6, "Block", { -0.3, 2, -0.1 }, H.I, { 0.2, 0.2, 0.2 })
		local want = { 1, 2, 3, 5, 6, 4 }
		A.deepEq(row({ big, low, middle, right, left, back }), want)
		A.deepEq(row({ back, left, right, middle, low, big }), want)
		-- |z| before z: an image across z = 0 keeps the order of 2 parts that differ in |z|; only true twins at ±z swap
		local near = H.solid(1, "Block", { 0, 2, 0.1 }, H.I, { 0.2, 0.2, 0.2 })
		local far = H.solid(2, "Block", { 0, 2, -0.2 }, H.I, { 0.2, 0.2, 0.2 })
		A.deepEq(row({ far, near }), { 1, 2 }, "the nearer the centre plane first")
		local nearImage = H.solid(1, "Block", { 0, 2, -0.1 }, H.I, { 0.2, 0.2, 0.2 })
		local farImage = H.solid(2, "Block", { 0, 2, 0.2 }, H.I, { 0.2, 0.2, 0.2 })
		A.deepEq(row({ farImage, nearImage }), { 1, 2 }, "and so in the image")
		local plus = H.solid(1, "Block", { 0, 2, 0.1 }, H.I, { 0.2, 0.2, 0.2 })
		local minus = H.solid(2, "Block", { 0, 2, -0.1 }, H.I, { 0.2, 0.2, 0.2 })
		A.deepEq(row({ plus, minus }), { 2, 1 }, "twins: z decides")
		-- the height in RANK_Q (the shift fix, §17.1 O11 (j)): twins whose heights differ in the last bit (1.4 + 0.2 beside a
		-- typed 1.6) tie on it, so where they stand across decides, the −x one first, whatever their ids (by the raw height
		-- the lower came first, and a move that rounds the two to one height swapped them)
		A.deepEq(row({ H.solid(1, "Block", { 0.3, 1.4 + 0.2, 0 }, H.I, { 0.2, 0.2, 0.2 }),
			H.solid(2, "Block", { -0.3, 1.6, 0 }, H.I, { 0.2, 0.2, 0.2 }) }), { 2, 1 }, "twins an ulp apart in height: x decides")
		-- x and z are not rounded (only the height is, in RANK_Q): of two parts 3e-10 apart along X the one at x 0 comes
		-- first, whatever their ids
		A.deepEq(row({ H.solid(1, "Block", { 3e-10, 2, 0 }, H.I, { 0.2, 0.2, 0.2 }),
			H.solid(2, "Block", { 0, 2, 0 }, H.I, { 0.2, 0.2, 0.2 }) }), { 2, 1 }, "x not rounded: the one at x 0 first")
		-- the same volume and place: the half extents, then the turn
		local wedge = H.solid(1, "Wedge", { 0, 2, 0 }, H.I, { 0.4, 0.2, 0.2 })
		local block = H.solid(2, "Block", { 0, 2, 0 }, H.I, { 0.2, 0.2, 0.2 })
		A.deepEq(row({ wedge, block }), { 2, 1 })
		local wide = H.solid(1, "Block", { 0, 2, 0 }, H.I, { 0.4, 0.1, 0.2 })
		local deep = H.solid(2, "Block", { 0, 2, 0 }, H.I, { 0.2, 0.1, 0.4 })
		A.deepEq(row({ wide, deep }), { 2, 1 })
		local tall = H.solid(3, "Block", { 0, 2, 0 }, H.I, { 0.2, 0.2, 0.2 })
		local turned = H.solid(4, "Block", { 0, 2, 0 }, H.axisAngle(0, 1, 0, 30), { 0.2, 0.2, 0.2 })
		A.deepEq(row({ tall, turned }), row({ turned, tall }))
		-- a copy: by the slot's name, the material's, then the index
		local function copy(id: number, slot: string, material: string): any
			return H.part(id, slot, "Block", material, { 0, 2, 0 }, H.I, { 0.2, 0.2, 0.2 })
		end
		A.deepEq(row({ copy(1, "Guard", "Iron"), copy(2, "Blade", "Iron") }), { 2, 1 })
		A.deepEq(row({ copy(1, "Blade", "Steel"), copy(2, "Blade", "Iron") }), { 2, 1 })
		A.deepEq(row({ copy(1, "Blade", "Iron"), copy(2, "Blade", "Iron") }), { 1, 2 })
		-- the larger before the slot's name: a large part in the Guard before a small one in the Blade, and a copy a hair larger
		-- in the Guard before its original; of one volume the slot's name before where it stands, so a copy a hair lower in the
		-- Guard comes after its original, and a part high in the Blade before one of its size low in the Guard
		local small = H.part(1, "Blade", "Block", "Iron", { 0, 3, 0 }, H.I, { 0.1, 0.1, 0.1 })
		local large = H.part(2, "Guard", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.4, 0.4, 0.4 })
		A.deepEq(row({ small, large }), { 2, 1 })
		local larger = H.part(2, "Guard", "Block", "Iron", { 0, 3, 0 }, H.I, { 0.1, 0.1, 0.1 + 1e-9 })
		A.deepEq(row({ small, larger }), { 2, 1 })
		local lower = H.part(2, "Guard", "Block", "Iron", { 0, 3 - 1e-12, 0 }, H.I, { 0.1, 0.1, 0.1 })
		A.deepEq(row({ lower, small }), { 1, 2 })
		local guardLow = H.part(2, "Guard", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.1, 0.1, 0.1 })
		A.deepEq(row({ guardLow, small }), { 1, 2 })
		-- one Block's solid however its size and frame describe it: its half extents sorted, so the material decides
		local given = H.part(1, "Blade", "Block", "Steel", { 0, 2, 0 }, H.I, { 0.4, 0.1, 0.2 })
		local described = H.part(2, "Blade", "Block", "Iron", { 0, 2, 0 }, H.axisAngle(0, 1, 0, 90), { 0.2, 0.1, 0.4 })
		A.deepEq(row({ given, described }), { 2, 1 }, "Iron first, the size 0.2 × 0.1 × 0.4 turned")
		given.material, described.material = "Iron", "Steel"
		A.deepEq(row({ described, given }), { 1, 2 }, "Iron first, the size 0.4 × 0.1 × 0.2")
		-- the volume from the sorted half extents: 0.0231 × 0.37 × 0.0388 and the same Block as 0.0388 × 0.37 × 0.0231 turned
		-- 90° about Y have Shapes volumes an ulp apart (8·hx·hy·hz in another order), the sorted ones none, so the half extents
		-- as given decide; and a Wedge of 1.02 stud³ comes before a Block of 1
		local thin = H.solid(1, "Block", { 0, 1, 0 }, H.I, { 0.0231, 0.37, 0.0388 })
		local turned90 = H.solid(2, "Block", { 0, 1, 0 }, H.axisAngle(0, 1, 0, 90), { 0.0388, 0.37, 0.0231 })
		A.truthy(H.prepare(thin).volume < H.prepare(turned90).volume, "Shapes' volumes an ulp apart")
		A.deepEq(row({ turned90, thin }), { 1, 2 }, "the smaller hx as given first")
		local wedge2 = H.solid(1, "Wedge", { 0, 0, 0.52 }, H.I, { 1, 1, 2.04 })
		local unit = H.solid(2, "Block", { 0, 0, 0 }, H.I, { 1, 1, 1 })
		A.deepEq(row({ unit, wedge2 }), { 1, 2 }, "the Wedge, 1.02 against 1, first")
		-- a Wedge 0.1 × 0.058 × 0.098 and the same solid as 0.1 × 0.098 × 0.058 half turned about its local (0, 1, −1):
		-- Shapes' volumes an ulp apart (4·hx·hy·hz in another order), the rank's none (hy and hz in order), so the slot's
		-- name decides
		local S = 0.70710678118654757
		local tip = H.part(1, "Blade", "Wedge", "Iron", { 0, 2, 0 }, H.I, { 0.1, 0.058, 0.098 })
		local writ = H.part(2, "Guard", "Wedge", "Iron", { 0, 2, 0 }, { 0, S, -S, 0 }, { 0.1, 0.098, 0.058 })
		A.truthy(H.prepare(writ).volume > H.prepare(tip).volume, "Shapes' volumes an ulp apart")
		A.deepEq(row({ writ, tip }), { 1, 2 }, "the Blade first, whichever writing")
		-- two Wedges of one volume, slot and place, hx equal: hy and hz in order, the lesser first (0.1 before 0.2; V1)
		local flatter = H.part(1, "Blade", "Wedge", "Iron", { 0, 2, 0 }, H.I, { 0.1, 0.2, 0.8 })
		local squarer = H.part(2, "Blade", "Wedge", "Iron", { 0, 2, 0 }, H.I, { 0.1, 0.4, 0.4 })
		A.deepEq(row({ squarer, flatter }), { 1, 2 }, "hy and hz in order: (0.1, 0.4) before (0.2, 0.2)")
		local rank = Sampling.ranked(H.prepared({ parts = { low, big } }))
		A.deepEq(rank, { 2, 1 }, "rank per part")
	end)

	-- The measure's rank, which also settles ownership within a slot (§4.3): the larger, then where it stands, then the half
	-- extents and turn as given, and the slot's name only when all of that ties, so it is the rank the measure always had.
	t.it("§4.4 Sampling.measureRanked: the larger, then where it stands, then the slot's name, whatever the order", function()
		local function row(parts: { any }): { number }
			local out: { number } = {}
			local list = H.prepared({ parts = parts })
			local _, order = Sampling.measureRanked(list, table.create(#list, true))
			for i, p in ipairs(order) do
				out[i] = p.id
			end
			return out
		end
		local small = H.part(1, "Blade", "Block", "Iron", { 0, 3, 0 }, H.I, { 0.1, 0.1, 0.1 })
		local large = H.part(2, "Guard", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.4, 0.4, 0.4 })
		A.deepEq(row({ small, large }), { 2, 1 }, "the larger first")
		local guardLow = H.part(2, "Guard", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.1, 0.1, 0.1 })
		A.deepEq(row({ small, guardLow }), { 2, 1 }, "of one volume the lower first, whatever the slot")
		-- from the centre of the parts of its volume and height, whatever their slots: of three at x −0.1, 0 and 0.1
		local left = H.part(3, "Pommel", "Block", "Iron", { -0.1, 3, 0 }, H.I, { 0.1, 0.1, 0.1 })
		local right = H.part(4, "Guard", "Block", "Iron", { 0.1, 3, 0 }, H.I, { 0.1, 0.1, 0.1 })
		A.deepEq(row({ right, left, small }), { 1, 3, 4 }, "|x| before x")
		local turned = H.part(2, "Blade", "Block", "Iron", { 0, 3, 0 }, H.axisAngle(0, 1, 0, 30), { 0.1, 0.1, 0.1 })
		local copy = H.part(3, "Guard", "Block", "Iron", { 0, 3, 0 }, H.I, { 0.1, 0.1, 0.1 })
		A.deepEq(row({ copy, small, turned }), { 2, 1, 3 }, "the turn before the slot's name, then the slot's name")
		A.deepEq(row({ copy, turned, small }), row({ small, turned, copy }), "whatever the order")
		-- the height in RANK_Q: twins whose heights differ in the last bit tie on it and form one tie group, so they rank
		-- from their centre, the −x one first, whatever their ids (by the raw height the lower came first; grouped on it,
		-- each ranks alone, its place 0, and the id decides)
		A.deepEq(row({ H.part(1, "Blade", "Block", "Iron", { 0.3, 1.4 + 0.2, 0 }, H.I, { 0.1, 0.1, 0.1 }),
			H.part(2, "Blade", "Block", "Iron", { -0.3, 1.6, 0 }, H.I, { 0.1, 0.1, 0.1 }) }), { 2, 1 },
			"twins an ulp apart in height tie on it: x decides, not the id")
		A.deepEq(row({ H.part(1, "Blade", "Block", "Iron", { 0.3, 2, 0 }, H.I, { 0.1, 0.1, 0.1 }),
			H.part(2, "Blade", "Block", "Iron", { -0.3, 1.9999999999999998, 0 }, H.I, { 0.1, 0.1, 0.1 }) }), { 2, 1 },
			"twins an ulp apart in height: one tie group")
		-- a place rounds half a RANK_Q away from 0 on either side (q(v) = sign(v)·floor(|v|/RANK_Q + ½)), so a mirror image
		-- negates it: of three tied parts about x = 0 (their x sum to 0 exactly), 1.5e-9 short of it is 2 steps, 1.2e-9 past
		-- it 1, 3e-10 past it 0, the nearer first
		local short = H.part(1, "Blade", "Block", "Iron", { -1.5e-9, 2, 0 }, H.I, { 0.1, 0.1, 0.1 })
		local past = H.part(2, "Blade", "Block", "Iron", { 1.2e-9, 2, 0 }, H.I, { 0.1, 0.1, 0.1 })
		local onIt = H.part(3, "Blade", "Block", "Iron", { -(-1.5e-9 + 1.2e-9), 2, 0 }, H.I, { 0.1, 0.1, 0.1 })
		A.deepEq(row({ short, past, onIt }), { 3, 2, 1 }, "half a step rounds away from 0")
		-- on either side: twins at x ±5e-10, their centre 0 exactly, are half a step out each way (5e-10 / RANK_Q is 0.5
		-- exactly), 1 and −1 steps, so they tie on |q| and the −x one comes first (rounded toward 0 on the + side, the +x
		-- twin would stand at 0 and come first, and its mirror image would not negate it)
		A.deepEq(row({ H.part(1, "Blade", "Block", "Iron", { 5e-10, 2, 0 }, H.I, { 0.1, 0.1, 0.1 }),
			H.part(2, "Blade", "Block", "Iron", { -5e-10, 2, 0 }, H.I, { 0.1, 0.1, 0.1 }) }), { 2, 1 },
			"half a step out on either side rounds away from 0")
		-- places count in RANK_Q (1e-9) from the ties' centre: three tied parts whose x sum to 0 exactly, 3e-7, −1e-7 and
		-- −2e-7 off it, are 300, 100 and 200 steps, the nearer first; 4e-10, −2e-10 and −2e-10 off it are all 0, a tie the
		-- index settles (in steps of 5e-10 the first would be 1 and come last)
		local far = H.part(1, "Blade", "Block", "Iron", { 3e-7, 2, 0 }, H.I, { 0.1, 0.1, 0.1 })
		local near = H.part(2, "Blade", "Block", "Iron", { -1e-7, 2, 0 }, H.I, { 0.1, 0.1, 0.1 })
		local mid = H.part(3, "Blade", "Block", "Iron", { -(3e-7 + -1e-7), 2, 0 }, H.I, { 0.1, 0.1, 0.1 })
		A.deepEq(row({ far, near, mid }), { 2, 3, 1 }, "1e-7 off, 2e-7 off, then 3e-7 off")
		local hair = H.part(1, "Blade", "Block", "Iron", { 4e-10, 2, 0 }, H.I, { 0.1, 0.1, 0.1 })
		local hairOther = H.part(2, "Blade", "Block", "Iron", { -2e-10, 2, 0 }, H.I, { 0.1, 0.1, 0.1 })
		local hairThird = H.part(3, "Blade", "Block", "Iron", { -(4e-10 + -2e-10), 2, 0 }, H.I, { 0.1, 0.1, 0.1 })
		A.deepEq(row({ hair, hairOther, hairThird }), { 1, 2, 3 }, "under half a RANK_Q off: a tie, the index")
		-- the ties are the parts of one volume and one height: twins at x ±0.3, and a part of their volume at another
		-- height, or of another volume at theirs, at x 0.6, which counted among them would move their centre to x 0.2 and
		-- put the +x twin first
		local twinPlus = H.part(1, "Blade", "Block", "Iron", { 0.3, 2, 0 }, H.I, { 0.1, 0.1, 0.1 })
		local twinMinus = H.part(2, "Blade", "Block", "Iron", { -0.3, 2, 0 }, H.I, { 0.1, 0.1, 0.1 })
		local higher = H.part(3, "Blade", "Block", "Iron", { 0.6, 3, 0 }, H.I, { 0.1, 0.1, 0.1 })
		local smaller = H.part(3, "Blade", "Block", "Iron", { 0.6, 2, 0 }, H.I, { 0.05, 0.1, 0.1 })
		A.deepEq(row({ twinPlus, twinMinus, higher }), { 2, 1, 3 }, "a part of another height is not among the ties")
		-- of kept parts the place comes before the material (the material first is the cleaned parts' rule alone)
		A.deepEq(row({ twinPlus, H.part(2, "Blade", "Block", "Steel", { -0.3, 2, 0 }, H.I, { 0.1, 0.1, 0.1 }) }), { 2, 1 },
			"kept twins of two materials: the −x one first, Steel before Iron")
		A.deepEq(row({ twinPlus, twinMinus, smaller }), { 2, 1, 3 }, "nor one of another volume")
		-- the ties' centre is the mean of their centres, not of their centroids: a Wedge 0.25 × 0.5 × 1 turned a quarter
		-- about Y, of one volume with Blocks 0.25 × 0.25 × 1 at x ∓0.3, has its centroid 1/6 along X from its centre, at
		-- the centre of the three; it comes first, then the Block at −x
		local R = 0.70710678118654757
		local wedge = H.part(1, "Blade", "Wedge", "Iron", { 0, 2, 0 }, { 0, R, 0, R }, { 0.25, 0.5, 1 })
		local minusX = H.part(2, "Blade", "Block", "Iron", { -0.3, 2, 0 }, H.I, { 0.25, 0.25, 1 })
		local plusX = H.part(3, "Blade", "Block", "Iron", { 0.3, 2, 0 }, H.I, { 0.25, 0.25, 1 })
		A.truthy(math.abs(H.prepare(wedge).gx - H.prepare(wedge).cx) > 0.1, "the Wedge's centroid off its centre along X")
		A.deepEq(row({ plusX, minusX, wedge }), { 1, 2, 3 }, "from the mean of the centres")
		-- with no part kept, which only measureInvalid reaches, the cleaned parts stand from the origin: the twins at x ±0.3,
		-- the −x one first (the mean of no kept part's centre, 0 / 0, would rank them by nothing)
		local none = H.prepared({ parts = { twinPlus, twinMinus } })
		local _, unkept = Sampling.measureRanked(none, table.create(#none, false))
		A.deepEq({ unkept[1].id, unkept[2].id }, { 2, 1 }, "no part kept: from the origin, the −x one first")
		-- the kept parts before the cleaned ones of their volume and height, whatever their materials: kept Steel and Bronze
		-- at x −0.15 and 0 rank from their own centre, x −0.075, the −x one first, then the cleaned Steel one (the material
		-- asked of a cleaned part alone, a kept one met before it would be ranked by its material on one side of the
		-- comparison and by its place on the other)
		local mixed = H.prepared({ parts = {
			H.part(1, "Guard", "Block", "Steel", { -0.1, 1.5, 0 }, H.I, { 0.1, 0.1, 0.1 }),
			H.part(2, "Guard", "Block", "Steel", { -0.15, 1.5, 0.05 }, H.I, { 0.1, 0.1, 0.1 }),
			H.part(3, "Guard", "Block", "Bronze", { 0, 1.5, -0.05 }, H.I, { 0.1, 0.1, 0.1 }),
			H.part(4, "Guard", "Block", "Bronze", { -0.15, 1, 0.05 }, H.I, { 0.1, 0.1, 0.1 }),
		} })
		local _, byMeasure = Sampling.measureRanked(mixed, { false, true, true, false })
		local ids: { number } = {}
		for i, p in ipairs(byMeasure) do
			ids[i] = p.id
		end
		A.deepEq(ids, { 4, 2, 3, 1 }, "the lower first, then the kept ones from their centre, then the cleaned one")
	end)

	-- §17.1 O8: the label is visible, so the slot decides between parts of one size that coincide. F3's blade, or C08's, again in
	-- the Guard, the Pommel or the Grip, exact, turned 180°, with its size described another way, a hair lower or a hair
	-- smaller, is cleaned; the blade stays kept and every other part's measure bit-identical. Under the rank by place and frame
	-- first, every such copy but the exact one kept the faces (F3's Sharpening 0.6104 Hard → 0.0645 Normal, C08's 0.2487 Hard
	-- → 0, through the emulator). A copy a hair larger encloses the blade and hides it: it takes the blade's place in its own
	-- slot, with every other verdict as when the blade is relabelled, which is all it can do (0.0645 and 0 again).
	t.it("§4.4 the slot decides between parts of one size that coincide: no such copy of F3's or C08's blade takes it out", function()
		local C08: any = nil
		for _, b in ipairs(Fixtures.calibration()) do
			if string.sub(b.name, 1, 3) == "C08" then
				C08 = b
			end
		end
		local cases: { { any } } = { { "F3", Blueprints.core("F3").parts, 6 }, { "C08", C08.parts, 4 } }
		for _, case in ipairs(cases) do
			local base: { any }, i: number = case[2], case[3]
			local blade = base[i]
			A.eq(blade.slot, "Blade", case[1] .. ": its blade")
			local before = Sampling.exposure(H.prepared({ parts = base }))
			A.truthy(before.kept[i], case[1] .. ": the blade kept")
			local sx, sy, sz = blade.size[1], blade.size[2], blade.size[3]
			local copies: { { any } } = {
				{ "exact", blade.rot, blade.size, 0 },
				{ "turned 180° about Y", { 0, 1, 0, 0 }, blade.size, 0 },
				{ "turned 180° about X", { 1, 0, 0, 0 }, blade.size, 0 },
				{ "its size described z, y, x, turned 90° about Y", H.axisAngle(0, 1, 0, 90), { sz, sy, sx }, 0 },
				{ "1e-12 lower", blade.rot, blade.size, -1e-12 },
				{ "5e-8 lower", blade.rot, blade.size, -5e-8 },
				{ "1e-9 smaller in every size", blade.rot, { sx - 1e-9, sy - 1e-9, sz - 1e-9 }, 0 },
				{ "1e-4 smaller in every size", blade.rot, { sx - 1e-4, sy - 1e-4, sz - 1e-4 }, 0 },
			}
			for _, c in ipairs(copies) do
				for _, slot in ipairs({ "Guard", "Pommel", "Grip" }) do
					local what = case[1] .. " + its blade " .. c[1] .. " in the " .. slot
					local parts = table.clone(base)
					table.insert(parts, H.part(#base + 1, slot, blade.shape, blade.material, { blade.pos[1], blade.pos[2] + c[4], blade.pos[3] }, c[2], c[3]))
					local after = Sampling.exposure(H.prepared({ parts = parts }))
					A.truthy(after.kept[i], what .. ": the blade kept")
					A.falsy(after.kept[#parts], what .. ": the copy cleaned")
					H.sameKeptMeasure(after, before, #base)
				end
			end
			for _, grow in ipairs({ 1e-12, 1e-9, 2e-7, 1e-6, 1e-4 }) do
				for _, slot in ipairs({ "Guard", "Grip" }) do
					local what = case[1] .. " + its blade " .. grow .. " larger in every size in the " .. slot
					local relabelled = table.clone(base)
					relabelled[i] = table.clone(blade)
					relabelled[i].slot = slot
					local parts = table.clone(base)
					table.insert(parts, H.part(#base + 1, slot, blade.shape, blade.material, table.clone(blade.pos), blade.rot, { sx + grow, sy + grow, sz + grow }))
					local after = Sampling.exposure(H.prepared({ parts = parts }))
					local moved = Sampling.exposure(H.prepared({ parts = relabelled }))
					A.falsy(after.kept[i], what .. ": the blade hidden")
					A.truthy(after.kept[#parts], what .. ": the copy kept")
					for j = 1, #base do
						if j ~= i then
							A.eq(after.kept[j], moved.kept[j], what .. ": part " .. j .. " as with the blade relabelled")
						end
					end
				end
			end
		end
	end)

	-- A Wedge (sx, sy, sz) is the same solid as (sx, sz, sy) half turned about its local (0, 1, −1), to the bit of its
	-- vertices; Shapes' volume 4·hx·hy·hz rounds the two descriptions an ulp apart, so the rank takes hy and hz in order.
	-- F4's tip and C08's two tips, again in the Guard so described, are cleaned and the tips kept, every other measure
	-- bit-identical (with the volume as given, the copies kept the faces: F4's Sharpening 0.3420 Hard → 0.1814 Normal,
	-- C08's 0.2487 Hard → 0.0076).
	t.it("§4.4 a Wedge described the other way ties with itself: F4's and C08's tips again in the Guard are cleaned", function()
		local C08: any = nil
		for _, b in ipairs(Fixtures.calibration()) do
			if string.sub(b.name, 1, 3) == "C08" then
				C08 = b
			end
		end
		local S = 0.70710678118654757
		local cases: { { any } } = { { "F4", Blueprints.core("F4").parts, 5 }, { "C08", C08.parts, 5 }, { "C08", C08.parts, 6 } }
		for _, case in ipairs(cases) do
			local base: { any }, i: number = case[2], case[3]
			local tip = base[i]
			A.eq(tip.shape, "Wedge", case[1] .. ": its tip")
			local before = Sampling.exposure(H.prepared({ parts = base }))
			local parts = table.clone(base)
			local q = Quat.hemisphere(Quat.normalize(Quat.mul(tip.rot, { 0, S, -S, 0 })))
			table.insert(parts, H.part(#base + 1, "Guard", "Wedge", tip.material, table.clone(tip.pos), q, { tip.size[1], tip.size[3], tip.size[2] }))
			local list = H.prepared({ parts = parts })
			local a, b = list[i].wverts, list[#parts].wverts
			for k = 1, #b, 3 do
				local nearest = math.huge
				for m = 1, #a, 3 do
					nearest = math.min(nearest, math.abs(b[k] - a[m]) + math.abs(b[k + 1] - a[m + 1]) + math.abs(b[k + 2] - a[m + 2]))
				end
				A.truthy(nearest <= 1e-15, case[1] .. ": the same solid")
			end
			local after = Sampling.exposure(list)
			local what = case[1] .. " + its tip " .. i .. " described the other way in the Guard"
			A.truthy(after.kept[i], what .. ": the tip kept")
			A.falsy(after.kept[#parts], what .. ": the copy cleaned")
			H.sameKeptMeasure(after, before, #base)
		end
	end)

	-- A Wedge (sx, sy, sz) and its other writing (sx, sz, sy) half turned about its local (0, 1, −1), coinciding in one slot in
	-- two materials: the rank takes its half extents from hy and hz in order, as a Block's sorted, so the material's name
	-- decides which is kept, whichever writing it has (with the extents as given the writing did: F4's tip in Steel with its
	-- other writing in Iron kept the Steel tip, mass 3.229776 against 3.230320).
	t.it("§4.4 a Wedge and its other writing in one slot: the material decides, whichever writing it has", function()
		local S = 0.70710678118654757
		local base = Blueprints.core("F4").parts
		local tip = base[5]
		A.eq(tip.shape, "Wedge", "F4's tip")
		local masses: { number } = {}
		for k, mats in ipairs({ { "Iron", "Steel" }, { "Steel", "Iron" } }) do
			local parts = table.clone(base)
			parts[5] = H.part(5, tip.slot, "Wedge", mats[1], table.clone(tip.pos), tip.rot, table.clone(tip.size))
			local q = Quat.hemisphere(Quat.normalize(Quat.mul(tip.rot, { 0, S, -S, 0 })))
			table.insert(parts, H.part(6, tip.slot, "Wedge", mats[2], table.clone(tip.pos), q, { tip.size[1], tip.size[3], tip.size[2] }))
			local report, e = H.measure(H.core("F4 + its tip's other writing", parts))
			local iron = if mats[1] == "Iron" then 5 else 6
			A.truthy(e.kept[iron], mats[1] .. " tip, " .. mats[2] .. " writing: the Iron one kept")
			A.falsy(e.kept[11 - iron], mats[1] .. " tip, " .. mats[2] .. " writing: the Steel one cleaned")
			masses[k] = report.mass
		end
		A.eq(masses[1], masses[2], "the same mass either way")
	end)

	-- A flat face against a Ball reads its true sphere (§4.4): F5 with its pommel a Ball 0.6 across and its blade 0.27 longer,
	-- and 4 Blade studs 0.06 × 0.1 × 0.06 along (0.828, ±0.451, ±0.451), where the Ball's half-spaces moved out by their sag
	-- stand 0.0452 r past the sphere, their tops 0.004 out of it: each truly shows 16.2 %. On the moved half-spaces they read
	-- 1.73–1.75 % and were cleaned (Sharpening 0.1907 Normal through the emulator, the truth's row 0.2047 Hard); on the circles
	-- their faces' planes cut from the sphere they read 15.8 %, kept: the truth's row.
	t.it("§4.4 studs a hair out of a Ball's true surface show what they truly show: kept", function()
		local R = 0.3
		local parts = table.clone(Blueprints.core("F5").parts)
		parts[1] = H.part(1, "Pommel", "Ball", "Iron", { 0, R, 0 }, H.I, { 2 * R, 2 * R, 2 * R })
		local blade, tip = parts[4], parts[5]
		parts[4] = H.part(4, blade.slot, blade.shape, blade.material, { blade.pos[1], blade.pos[2] + 0.135, blade.pos[3] }, blade.rot,
			{ blade.size[1], blade.size[2] + 0.27, blade.size[3] })
		parts[5] = H.part(5, tip.slot, tip.shape, tip.material, { tip.pos[1], tip.pos[2] + 0.27, tip.pos[3] }, tip.rot, table.clone(tip.size))
		for _, s in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
			local x, y, z = 0.2484, s[1] * 0.1353, s[2] * 0.1353
			local l = math.sqrt(x * x + y * y + z * z)
			local k = R + 0.004 - 0.05
			table.insert(parts, H.part(#parts + 1, "Blade", "Block", "Iron", { k * x / l, R + k * y / l, k * z / l },
				H.axisAngle(z / l, 0, -x / l, math.deg(math.acos(y / l))), { 0.06, 0.1, 0.06 }))
		end
		local list = H.prepared({ parts = parts })
		local kept = Sampling.exposure(list).kept
		for i = 6, 9 do
			A.truthy(Shapes.sd(list[1], list[i].cx, list[i].cy, list[i].cz) < 0, "stud " .. i .. ": its centre in the pommel")
			A.truthy(shareOf(list, i) > 0.15, "stud " .. i .. ": truly shows 16 %")
			A.truthy(H.reads(list, i) > 0.15, "stud " .. i .. ": reads it, its top on no circle")
			A.truthy(kept[i], "stud " .. i .. ": kept")
		end
	end)

	-- Filler against a round part's true surface lies in its model's band, between the inscribed facets and the sphere
	-- (0.0572 r deep along (1, 1, 1)): F5 with its pommel a Ball 0.6 across, and 4 Blade Blocks along (1, ±1, ±1)/√3,
	-- their outer faces 0.011 under the sphere; or 4 Blade Balls r 0.1, 0.002 or 0.0002 under it. Every vertex buried, the
	-- truth reads 0. On the hider's inscribed half-spaces the Blocks read 10 % and the Balls 3.3 % and 4.1 %, kept,
	-- Sharpening 0.0989 Normal → 0.2169 and 0.2958 Hard through the emulator; the facets' hulls in the true solid keep the
	-- Balls 0.002 under it under 2 % (1.2 %), but 0.0002 under it they read 3.6 % (0.2964 Hard). The Blocks' faces on the
	-- circles their planes cut from the sphere and the Balls' true solids in the pommel's: all cleaned, F5's measure.
	t.it("§4.4 filler wholly inside a Ball, against its true surface, is cleaned, flat or round: none buys a face in the model's band", function()
		local S3 = 1 / math.sqrt(3)
		local R = 0.3
		local base = table.clone(Blueprints.core("F5").parts)
		base[1] = H.part(1, "Pommel", "Ball", "Iron", { 0, R, 0 }, H.I, { 2 * R, 2 * R, 2 * R })
		local before = Sampling.exposure(H.prepared({ parts = base }))
		local cases: { { any } } = { { "Block", 0.011 }, { "Ball", 0.002 }, { "Ball", 0.0002 } }
		for _, case in ipairs(cases) do
			local kind: string, e: number = case[1], case[2]
			local parts = table.clone(base)
			for _, d in ipairs({ { S3, S3, S3 }, { S3, -S3, S3 }, { S3, S3, -S3 }, { S3, -S3, -S3 } }) do
				local k = R - e - 0.1
				if kind == "Block" then
					table.insert(parts, H.part(#parts + 1, "Blade", "Block", "Iron", { k * d[1], R + k * d[2], k * d[3] },
						H.axisAngle(d[3], 0, -d[1], math.deg(math.acos(d[2]))), { 0.1, 0.2, 0.1 }))
				else
					table.insert(parts, H.part(#parts + 1, "Blade", "Ball", "Iron", { k * d[1], R + k * d[2], k * d[3] }, H.I, { 0.2, 0.2, 0.2 }))
				end
			end
			local list = H.prepared({ parts = parts })
			for i = #base + 1, #parts do
				local P = list[i]
				local deepest = if P.poly then -math.huge else Shapes.sd(list[1], P.cx, P.cy, P.cz) + P.r
				for j = 1, #P.wverts, 3 do
					deepest = math.max(deepest, Shapes.sd(list[1], P.wverts[j], P.wverts[j + 1], P.wverts[j + 2]))
				end
				A.truthy(deepest < -1e-4, kind .. " " .. i .. ", " .. e .. " under: wholly inside the Ball")
			end
			local after = Sampling.exposure(list)
			for i = #base + 1, #parts do
				A.falsy(after.kept[i], kind .. " " .. i .. ", " .. e .. " under the pommel's surface: cleaned")
			end
			H.sameKeptMeasure(after, before, #base)
		end
	end)

	-- The same under a Cylinder's side, its 32-gon 0.0048 r under the circle: a plate 0.03 thick inside a Cylinder r 0.3,
	-- its outer face 0.0003 to 0.001 under the side, read 20–30 % on the inscribed half-spaces; a rod r 0.066 along a
	-- Cylinder r 0.2, 0.0002 under its side at 30°, 3.80 % (3.37 % with the facets' hulls alone). Both read nothing now.
	t.it("§4.4 a plate or a rod inside a Cylinder, against its true side, reads nothing", function()
		local r, a = 0.3, math.pi / 32
		for _, e in ipairs({ 0.0003, 0.0006, 0.001 }) do
			local w = 2 * math.sqrt((r - 1e-4) ^ 2 - (r - e) ^ 2) * 0.95
			local k = r - e - 0.015
			local list = H.prepared({ parts = {
				H.solid(1, "Cylinder", { 0, 1, 0 }, H.I, { 1.4, 2 * r, 2 * r }),
				H.solid(2, "Block", { 0, 1 + k * math.cos(a), k * math.sin(a) }, H.axisAngle(1, 0, 0, math.deg(a)), { 1.2, 0.03, w }),
			} })
			for j = 1, #list[2].wverts, 3 do
				A.truthy(Shapes.sd(list[1], list[2].wverts[j], list[2].wverts[j + 1], list[2].wverts[j + 2]) < 0, "the plate " .. e .. " under: inside")
			end
			exactly(list, 2, 0, "the plate " .. e .. " under the side")
		end
		local rod = H.prepared({ parts = {
			H.solid(1, "Cylinder", { 0, 2, 0 }, H.I, { 2.4, 0.4, 0.4 }),
			H.solid(2, "Cylinder", { 0, 2 + (0.2 - 0.0002 - 0.066) * math.cos(math.rad(30)), (0.2 - 0.0002 - 0.066) * math.sin(math.rad(30)) }, H.I,
				{ 1, 0.132, 0.132 }),
		} })
		exactly(rod, 2, 0, "the rod 0.0002 under the side")
	end)

	-- Round filler wholly inside one Cylinder, across its axis, reads nothing (§4.4: a Cylinder in a Cylinder by its cap
	-- circles' farthest point from the axis, exactly, at any tilt). F5 with its guard a disk r 0.8 (a Cylinder along Z, 0.5
	-- long, where the guard stands) and its blade 0.8 longer, and 10 Blade pucks r 0.1, 0.1 long, each tangent to the disk's
	-- rim at 30° + 11.25°·j from +Y, every point of them 1e-4 inside it (V1's puck_sword.luau). By the caps' centres'
	-- distance + r, which stands 1.2e-4 out at that tilt, and their facets' hulls, 0.0048 r past it, they read 2.33 % each
	-- and were kept, Sharpening 0.1302 Normal → 0.3739 Hard through the emulator (the truth's row 0.1302). Now cleaned, the
	-- guard's measure.
	t.it("§4.4 pucks wholly inside a round guard, tilted across its axis, are cleaned: the guard's measure", function()
		local R, m, rho, hx = 0.8, 1e-4, 0.1, 0.05
		local base = table.clone(Blueprints.core("F5").parts)
		base[3] = H.part(3, "Guard", "Cylinder", "Iron", { 0, 1.29, 0 }, H.Y90, { 0.5, 2 * R, 2 * R })
		local blade, tip = base[4], base[5]
		base[4] = H.part(4, blade.slot, blade.shape, blade.material, { blade.pos[1], blade.pos[2] + 0.4, blade.pos[3] }, blade.rot,
			{ blade.size[1], blade.size[2] + 0.8, blade.size[3] })
		base[5] = H.part(5, tip.slot, tip.shape, tip.material, { tip.pos[1], tip.pos[2] + 0.8, tip.pos[3] }, tip.rot, table.clone(tip.size))
		local before = Sampling.exposure(H.prepared({ parts = base }))
		local parts = table.clone(base)
		local y0 = math.sqrt((R - m) ^ 2 - hx * hx) - rho -- the cap rims' farthest point sqrt((y0 + ρ)² + hx²) = R − m
		for j = 0, 9 do
			local a = math.rad(30 + 11.25 * j)
			local rx, ry = math.sin(a), math.cos(a)
			table.insert(parts, H.part(#parts + 1, "Blade", "Cylinder", "Iron", { y0 * rx, 1.29 + y0 * ry, 0 },
				H.axisAngle(0, 0, 1, math.deg(math.atan2(-rx, ry))), { 2 * hx, 2 * rho, 2 * rho }))
		end
		local list = H.prepared({ parts = parts })
		for i = #base + 1, #parts do
			local P = list[i]
			local deepest = -math.huge
			for s = -1, 1, 2 do
				for k = 0, 359 do
					local c, sn = math.cos(math.rad(k)), math.sin(math.rad(k))
					deepest = math.max(deepest, Shapes.sd(list[3], P.cx + s * P.hx * P.ux + P.r * (c * P.vx + sn * P.wx),
						P.cy + s * P.hx * P.uy + P.r * (c * P.vy + sn * P.wy), P.cz + s * P.hx * P.uz + P.r * (c * P.vz + sn * P.wz)))
				end
			end
			A.truthy(deepest < -0.9 * m and deepest > -1.1 * m, "puck " .. i .. ": its rims 1e-4 inside the disk (" .. deepest .. ")")
		end
		A.eq(shareOf(list, #base + 1), 0, "a puck truly shows nothing")
		local after = Sampling.exposure(list)
		for i = #base + 1, #parts do
			A.falsy(after.kept[i], "puck " .. i .. ": cleaned")
			A.eq(H.reads(list, i), 0, "puck " .. i .. ": reads 0")
		end
		H.sameKeptMeasure(after, before, #base)
	end)

	-- ── what the verdict reads, to the bit ───────────────────────────────────────────────────────────────────────────

	-- On a laminated hilt: 2 proud rims of the core, 0.02 past the cheeks, its faces hidden by them, a cap over its top. Cleaned, the
	-- chord through the blade opens and Hammering jumps 0.47 (§17.2).
	t.it("§5 a laminated core that shows 5.54 % is kept: its proud rims, its ends, its top", function()
		local core = H.part(7, "Blade", "Block", "Steel", { 0, 2.45, 0 }, H.I, { 1.04, 2, 0.02 })
		local parts = {
			H.part(1, "Pommel", "Ball", "Iron", { 0, 0.3, 0 }, H.I, { 0.3, 0.3, 0.3 }),
			H.part(2, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, H.Z90, { 0.9, 0.16, 0.16 }),
			H.part(3, "Guard", "Block", "Iron", { 0, 1.4, 0 }, H.I, { 1.1, 0.16, 0.3 }),
			H.part(4, "Blade", "Block", "Iron", { 0, 2.45, 0.0225 }, H.I, { 1, 2, 0.025 }),
			H.part(5, "Blade", "Block", "Iron", { 0, 2.45, -0.0225 }, H.I, { 1, 2, 0.025 }),
			H.part(6, "Blade", "Block", "Iron", { 0, 3.47, 0 }, H.I, { 1, 0.04, 0.07 }),
			core,
		}
		local list = H.prepared({ parts = parts })
		A.near(shareOf(list, 7), 0.0554, 0.002, "it shows")
		A.deepEq(Sampling.exposure(list).cleaned, {}, "kept with the rest")
		-- from the guard's top (y 1.48) to the cap (y 3.45): the 4 rims 0.02 past the cheeks and the 2 ends 0.02 thick; on the top, the
		-- 2 corners past the cap's ends
		local area = 2 * (1.04 * 2 + 1.04 * 0.02 + 2 * 0.02)
		local tall = 3.45 - 1.48 - EPS
		exactly(list, 7, (4 * (0.02 - EPS) * tall + 2 * 0.02 * tall + 2 * (0.02 - EPS) * 0.02) / area, "rims, ends and top")
	end)

	t.it("§4.4 a strip along the rim shows what it is: all round, on 3 sides, on 1, a hair", function()
		local s = 0.008
		local inner, outer = -0.25 + s, 0.25 - s
		local ring = underLids({ { inner, outer, inner, outer } })
		exactly(ring, 1, (0.25 - (0.5 - 2 * s + 2 * EPS) ^ 2) / PLATE_AREA, "all round")
		A.truthy(keptOf(ring, 1), "2.92 %: kept")
		local three = underLids({ { inner, outer, -FAR, outer } })
		exactly(three, 1, (0.25 - (0.5 - 2 * s + 2 * EPS) * (0.5 - s + EPS)) / PLATE_AREA, "on 3 sides")
		A.truthy(keptOf(three, 1), "2.20 %: kept")
		local one = underLids({ { -FAR, outer, -FAR, FAR } })
		exactly(one, 1, 0.5 * (s - EPS) / PLATE_AREA, "on 1 side")
		A.falsy(keptOf(one, 1), "0.74 %: cleaned")
		for _, hair in ipairs({ 0.002, 0.001 } :: { number }) do
			local lid = { -0.25 + hair, 0.25 - hair, -0.25 + hair, 0.25 - hair }
			exactly(underLids({ lid }), 1, (0.25 - (0.5 - 2 * hair + 2 * EPS) ^ 2) / PLATE_AREA, "a hair " .. hair .. " round the rim")
		end
		local wide = 0.02
		local lid = { -0.25 + wide, 0.25 - wide, -0.25 + wide, 0.25 - wide }
		exactly(underLids({ lid }), 1, (0.25 - (0.5 - 2 * wide + 2 * EPS) ^ 2) / PLATE_AREA, "wider")
	end)

	t.it("§4.4 a slit shows what it is, wherever it passes: its width times its length, a hairline a hairline", function()
		local g = 0.03
		local whole = slit(g, 0.0625)
		exactly(whole, 1, 0.5 * (g - 2 * EPS) / PLATE_AREA, "across the plate")
		A.truthy(keptOf(whole, 1), "2.78 %: kept")
		local most = slit(g, 0.0625, { { -FAR, FAR, 0.125, FAR } })
		exactly(most, 1, (0.375 - EPS) * (g - 2 * EPS) / PLATE_AREA, "three quarters of it")
		A.truthy(keptOf(most, 1), "2.08 %: kept")
		local half = slit(g, 0.0625, { { -FAR, FAR, 0, FAR } })
		exactly(half, 1, (0.25 - EPS) * (g - 2 * EPS) / PLATE_AREA, "half of it")
		A.falsy(keptOf(half, 1), "1.39 %: cleaned")
		-- a filler behind a hairline stays cleaned
		local hairline = slit(0.00001, 0.0625)
		exactly(hairline, 1, 0.5 * (0.00001 - 2 * EPS) / PLATE_AREA, "a hairline")
		A.falsy(keptOf(hairline, 1), "0.0009 %: cleaned")
		-- wherever it stands: where an earlier reading had its lines, sub-points or corners, and between them
		for _, c in ipairs({ 0.11, 0.0925, 0.0625 + 0.25 * 0.0625, 0.124, -0.2 } :: { number }) do
			exactly(slit(0.02, c), 1, 0.5 * (0.02 - 2 * EPS) / PLATE_AREA, "a slit 0.02 at x = " .. c)
		end
		local pair = underLids({ { -FAR, 0.04, -FAR, FAR }, { 0.05, 0.085, -FAR, FAR }, { 0.095, FAR, -FAR, FAR } })
		exactly(pair, 1, 0.5 * (0.02 - 4 * EPS) / PLATE_AREA, "2 slits of 0.01")
		exactly(slit(0.0035, 0.12175), 1, 0.5 * (0.0035 - 2 * EPS) / PLATE_AREA, "0.0035")
		exactly(underLids({ { -FAR, FAR, -FAR, 0.1 }, { -FAR, FAR, 0.12, FAR } }), 1, 0.5 * (0.02 - 2 * EPS) / PLATE_AREA, "the other way")
		exactly(slit(0.02, 0.11, { { 0.09, 0.13, 0, FAR } }), 1, (0.02 - 2 * EPS) * (0.25 - EPS) / PLATE_AREA, "a slit that stops")
		-- a cross of hairlines: what both show counts once
		local x, z, e = 0.0625 + 0.25 * 0.0625, 0.0625 + 0.25 * 0.0625, 0.00001
		local cross = underLids({ { -FAR, x - e, -FAR, z - e }, { x + e, FAR, -FAR, z - e }, { -FAR, x - e, z + e, FAR }, { x + e, FAR, z + e, FAR } })
		local w = 2 * e - 2 * EPS
		exactly(cross, 1, (0.5 * w + 0.5 * w - w * w) / PLATE_AREA, "a cross of hairlines")
		A.falsy(keptOf(cross, 1), "cleaned")
	end)

	t.it("§4.4 one part or two: a slit between two hiders shows; a lid with a corner off shows its triangle", function()
		local between = slit(0.0275, 0.10625)
		exactly(between, 1, 0.5 * (0.0275 - 2 * EPS) / PLATE_AREA, "the slit's width")
		A.truthy(keptOf(between, 1), "2.55 %: kept")
		exactly(underLids({ { -FAR, FAR, -FAR, FAR } }), 1, 0, "one lid")
		-- straight lids over x ≥ 0.125 and over x ≤ 0.125, z ≥ 0.125, a lid turned 45° over x + z ≤ 0.2: the triangle between them, its
		-- legs short by the EPS_GEOM each lid grows by (√2·EPS_GEOM across the turned one)
		local c, D = 0.2, 1
		local n = math.sqrt(0.5)
		local dist = c * n - D
		local parts = partsUnder({ { 0.125, FAR, -FAR, FAR }, { -FAR, 0.125, 0.125, FAR } })
		table.insert(parts, H.solid(20, "Block", { n * dist, 0.05, n * dist }, H.axisAngle(0, 1, 0, -45), { 2 * D, 0.1, 3 }))
		local leg = 2 * (0.125 - EPS) - (c + math.sqrt(2) * EPS)
		exactly(H.prepared({ parts = parts }), 1, leg * leg / 2 / PLATE_AREA, "the triangle")
	end)

	t.it("§4.4 a part hides by the probe up to HIDE_OFFSET and no further; a lid on a lid changes nothing", function()
		-- a bar along the slit, lifted just past the probe: it hides nothing; just under it, the whole slit
		local g = 0.03
		local function bar(y: number): any
			return H.solid(20, "Block", { 0.0625, y + 0.05, 0 }, H.I, { 0.06, 0.1, 0.6 })
		end
		local slitLids = { { -FAR, 0.0625 - g / 2, -FAR, FAR }, { 0.0625 + g / 2, FAR, -FAR, FAR } }
		local above = partsUnder(slitLids)
		table.insert(above, bar(Geo.HIDE_OFFSET + 3 * EPS))
		exactly(H.prepared({ parts = above }), 1, 0.5 * (g - 2 * EPS) / PLATE_AREA, "over the probe")
		local under = partsUnder(slitLids)
		table.insert(under, bar(Geo.HIDE_OFFSET - 3 * EPS))
		exactly(H.prepared({ parts = under }), 1, 0, "under the probe")
		-- a hair round the rim under a lid with a second lid on it, either order; the same lid 0.005 over the top, by the probe alone
		local hair = 0.001
		local ring = { -0.25 + hair, 0.25 - hair, -0.25 + hair, 0.25 - hair }
		local want = (0.25 - (0.5 - 2 * hair + 2 * EPS) ^ 2) / PLATE_AREA
		exactly(underLids({ { -0.2, 0.2, -0.2, 0.2 }, ring }), 1, want, "2 lids")
		exactly(underLids({ ring, { -0.2, 0.2, -0.2, 0.2 } }), 1, want, "2 lids, the other order")
		local raised = partsUnder({})
		table.insert(raised, H.solid(20, "Block", { 0, 0.005 + 0.05, 0 }, H.I, { 2 * ring[2], 0.1, 2 * ring[2] }))
		exactly(H.prepared({ parts = raised }), 1, want, "raised")
	end)

	t.it("§4.4 a part reads the same whatever axes it is built on: a lid turned so that each of its axes lies along each of the plate's", function()
		local function lid(id: number, x0: number, x1: number, z0: number, z1: number, turn: number): any
			local sx, sy, sz = x1 - x0, 0.1, z1 - z0
			local pos = { (x0 + x1) / 2, 0.05, (z0 + z1) / 2 }
			if turn == 1 then
				return H.solid(id, "Block", pos, H.I, { sx, sy, sz })
			elseif turn == 2 then
				return H.solid(id, "Block", pos, { 0.5, 0.5, 0.5, 0.5 }, { sy, sz, sx })
			end
			return H.solid(id, "Block", pos, { -0.5, -0.5, -0.5, 0.5 }, { sz, sx, sy })
		end
		local g = 0.03
		for turn = 1, 3 do
			local parts = partsUnder({})
			table.insert(parts, lid(10, -FAR, 0.0625 - g / 2, -FAR, FAR, turn))
			table.insert(parts, lid(11, 0.0625 + g / 2, FAR, -FAR, FAR, turn))
			table.insert(parts, lid(12, -FAR, FAR, 0.1, FAR, turn))
			exactly(H.prepared({ parts = parts }), 1, (0.35 - EPS) * (g - 2 * EPS) / PLATE_AREA, "turn " .. turn)
			local whole = partsUnder({})
			table.insert(whole, lid(13, -FAR, FAR, -FAR, FAR, turn))
			exactly(H.prepared({ parts = whole }), 1, 0, "whole, turn " .. turn)
		end
	end)

	t.it("§4.4 a bar across and a window: what shows between parts, however it lies", function()
		exactly(underLids({ { -FAR, FAR, 0.0825, 0.1025 } }), 1, (0.25 - 0.5 * (0.02 + 2 * EPS)) / PLATE_AREA, "a bar")
		-- a window: 4 lids round a square 0.03 wide
		local x0, x1 = 0.0625 + 0.26 * 0.0625, 0.0625 + 0.74 * 0.0625
		local window = underLids({ { -FAR, x0, -FAR, FAR }, { x1, FAR, -FAR, FAR }, { x0, x1, -FAR, x0 }, { x0, x1, x1, FAR } })
		exactly(window, 1, (x1 - x0 - 2 * EPS) ^ 2 / PLATE_AREA, "a window")
		A.falsy(keptOf(window, 1), "0.17 %: cleaned")
	end)

	t.it("§4.4 Dust hides nothing: a speck over a strip leaves what the verdict reads", function()
		-- the ring of the strip case, a speck over the strip of its +X side: its volume is under the Dust floor by a hair, and were it a
		-- hider, the plate would read less
		local s = 0.008
		local speck = H.part(9, "Blade", "Block", "Iron", { 0.25 - 0.01 + 0.002, 0.0175, 0 }, H.I, { 0.02, 0.035, 0.26 })
		A.truthy(H.prepare(speck).volume < Geo.MIN_PART_VOLUME, "it is Dust")
		local parts = underLids({ { -0.25 + s, 0.25 - s, -0.25 + s, 0.25 - s } })
		table.insert(parts, Shapes.prepare(speck :: any, #parts + 1))
		exactly(parts, 1, (0.25 - (0.5 - 2 * s + 2 * EPS) ^ 2) / PLATE_AREA, "the ring, speck or no speck")
		A.truthy(keptOf(parts, 1), "kept")
		A.deepEq(Sampling.exposure(parts).cleaned, { { partId = 9, reason = "Dust" } })
	end)

	t.it("§4.4 exact copies hide nothing: a stack of a lid's copies leaves what the verdict reads, and they have no verdict", function()
		local s = 0.008
		local lid = { -0.25 + s, 0.25 - s, -0.25 + s, 0.25 - s }
		local parts = underLids({ lid, lid, lid, lid })
		exactly(parts, 1, (0.25 - (0.5 - 2 * s + 2 * EPS) ^ 2) / PLATE_AREA, "the ring, copies or no copies")
		local copies = { { partId = WALLS + 2, reason = "Enclosed" }, { partId = WALLS + 3, reason = "Enclosed" }, { partId = WALLS + 4, reason = "Enclosed" } }
		A.deepEq(Sampling.exposure(parts).cleaned, copies)
		-- no budget to share and no candidates to add: the base's bits, on what a verdict sees
		local base: any = Blueprints.get("F1").core
		local pile = Drafts.deepCopy(base)
		for k = 1, 4 do
			local copy = Drafts.deepCopy(base.parts[k])
			copy.id = 20 + k
			table.insert(pile.parts, copy)
		end
		H.sameKeptMeasure(Sampling.exposure(H.prepared(pile)), Sampling.exposure(H.prepared(base)), #base.parts)
	end)

	-- F5 and 6 copies of its blade at z = k · 0.002. Each of the first 5 shows at most a strip 0.002 wide round its rim, by rank: the
	-- copy nearer the centre plane keeps the rest of the rim, and the one past it buries a face. All but the last are cleaned.
	t.it("§4.4 copies of a blade 0.002 apart: each shows what its neighbours leave of its rim, the last one its face", function()
		local design = H.f("F5")
		local blade = design.parts[4]
		for k = 1, 6 do
			table.insert(design.parts, H.part(10 + k, "Blade", "Block", "Iron", { blade.pos[1], blade.pos[2], k * 0.002 }, H.I, blade.size))
		end
		local list = H.prepared(design)
		local cleaned: { any } = {}
		for k = 1, 5 do
			cleaned[k] = { partId = 10 + k, reason = "Enclosed" }
		end
		A.deepEq(Sampling.exposure(list).cleaned, cleaned, "the copies under another, the last one kept")
		-- a strip 0.002 wide round both sides and the tip end (the guard takes the bottom): 0.002 − EPS_GEOM on the side
		-- faces past the copy below, and the rim EPS_GEOM wide on the top face that the copy above, which ranks lower, leaves
		local area = 2 * (blade.size[1] * blade.size[2] + blade.size[1] * blade.size[3] + blade.size[2] * blade.size[3])
		local strip = (2 * blade.size[2] + blade.size[1]) * 0.002 / area
		for k = 1, 5 do
			A.near(H.reads(list, #design.parts - 6 + k), strip, 1e-9, "copy " .. k .. ": its rim's strip")
		end
	end)

	t.it("§4.4 a smaller copy of a wedge inside it reads nothing; a thin CornerWedge's tip reads what stands above its host", function()
		for _, shape in ipairs({ "Wedge", "CornerWedge" }) do
			local host = H.solid(1, shape, { 0, 2, 0 }, H.axisAngle(1, 2, 3, 40), { 0.4, 0.5, 0.3 })
			exactly(H.prepared({ parts = { host, shrunk(host, 0.99, 2, "Blade") } }), 2, 0, shape)
		end
		-- 0.1 × 1 × 0.1, apex up, sunk to y = 0.05: its four triangles show the top 0.45 of their height, less EPS_GEOM
		local list = H.prepared({ parts = { H.solid(1, "CornerWedge", { 0, 0, 0 }, H.I, { 0.1, 1, 0.1 }), H.solid(2, "Block", { 0, 0.05 - 2, 0 }, H.I, { 4, 4, 4 }) } })
		local sides = 2 * 0.05 + 2 * 0.05 * math.sqrt(1.01)
		A.near(shareOf(list, 1), 0.45 * 0.45 * sides / list[1].area, 0.002, "by the areas")
		exactly(list, 1, (0.45 - EPS) ^ 2 * sides / list[1].area, "the tip")
		A.truthy(keptOf(list, 1), "kept")
	end)

	-- A Ball between 2 plates shows a band round its waist: its model's band, kept. The probe's spread takes a strip off each
	-- edge of it: 17.71 % against the truth's 19.2 % (without the spread a little more than the truth's).
	t.it("§4.4 a Ball between 2 plates: its band is read on its model, within the model's band of the truth", function()
		local d, gap = 0.5, 0.1
		local ball = H.solid(1, "Ball", { 0, 2, 0 }, H.I, { d, d, d })
		local above = H.solid(2, "Block", { 0, 2 + gap / 2 + 0.15, 0 }, H.I, { 0.8, 0.3, 0.55 })
		local below = H.solid(3, "Block", { 0, 2 - gap / 2 - 0.15, 0 }, H.I, { 0.8, 0.3, 0.55 })
		local bead = H.prepared({ parts = { ball, above, below } })
		local truth = shareOf(bead, 1)
		A.near(truth, 0.192, 0.002, "it shows")
		A.near(H.reads(bead, 1), truth, 0.02, "its model reads within 0.02 of the truth")
		A.truthy(keptOf(bead, 1), "kept")
	end)

	-- Blades whose cover parts leave slits (§5.6's rows). The hilt and the frame are common; a core or a filler stands between 2
	-- cheeks.
	local function hiltFor(guard: number): { any }
		return {
			H.part(1, "Pommel", "Ball", "Iron", { 0, 0.3, 0 }, H.I, { 0.3, 0.3, 0.3 }),
			H.part(2, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, H.Z90, { 0.9, 0.16, 0.16 }),
			H.part(3, "Guard", "Block", "Iron", { 0, 1.4, 0 }, H.I, { guard, 0.16, 0.3 }),
		}
	end

	local function withIds(parts: { any }): { any }
		for i, p in ipairs(parts) do
			p.id = i
		end
		return parts
	end

	local function cheeks(c: number, k: number, g: number, oneFace: boolean): ({ any }, number)
		local L, w = 2, 1
		local y = 1.45 + L / 2
		local parts = hiltFor(1.1)
		local sw = (w - g) / 2
		local at = g / 2 + sw / 2
		table.insert(parts, H.part(0, "Blade", "Block", "Iron", { at, y, k / 2 + c / 2 }, H.I, { sw, L, c }))
		table.insert(parts, H.part(0, "Blade", "Block", "Iron", { -at, y, k / 2 + c / 2 }, H.I, { sw, L, c }))
		if oneFace then
			table.insert(parts, H.part(0, "Blade", "Block", "Iron", { 0, y, -k / 2 - c / 2 }, H.I, { w, L, c }))
		else
			table.insert(parts, H.part(0, "Blade", "Block", "Iron", { at, y, -k / 2 - c / 2 }, H.I, { sw, L, c }))
			table.insert(parts, H.part(0, "Blade", "Block", "Iron", { -at, y, -k / 2 - c / 2 }, H.I, { sw, L, c }))
		end
		table.insert(parts, H.part(0, "Blade", "Block", "Iron", { 0, 1.45 + L + 0.02, 0 }, H.I, { w + 0.08, 0.04, k + 2 * c }))
		table.insert(parts, H.part(0, "Blade", "Block", "Iron", { w / 2 + 0.02, y, 0 }, H.I, { 0.04, L, k + 2 * c }))
		table.insert(parts, H.part(0, "Blade", "Block", "Iron", { -w / 2 - 0.02, y, 0 }, H.I, { 0.04, L, k + 2 * c }))
		return parts, y
	end

	local function core(y: number, k: number, slot: string): any
		return H.part(0, slot, "Block", "Iron", { 0, y, 0 }, H.I, { 1, 2, k })
	end

	-- A CornerWedge with its apex at (ax, ay, az), its long axis along Z, standing in the far cheek.
	local function pin(ax: number, ay: number, az: number, b: number, h: number): any
		local Sq = math.sqrt(0.5)
		return H.part(0, "Guard", "CornerWedge", "Iron", { ax - b / 2, ay - b / 2, az - h / 2 }, { Sq, 0, 0, Sq }, { b, h, b })
	end

	t.it("§5 a hairline keeps no filler: a core behind a slit 0.00001 wide is cleaned, K + F measures as K", function()
		local K, y = cheeks(0.05, 0.02, 0.00001, false)
		withIds(K)
		local filled = Drafts.deepCopy(K)
		table.insert(filled, core(y, 0.02, "Guard"))
		withIds(filled)
		local list = H.prepared({ parts = filled })
		A.near(shareOf(list, #filled), 0, 0.0005, "it hardly shows")
		local after = Sampling.exposure(list)
		A.deepEq(after.cleaned, { { partId = #filled, reason = "Enclosed" } }, "the filler")
		H.sameKeptMeasure(after, Sampling.exposure(H.prepared({ parts = K })), #K)
	end)

	t.it("§5 pins cannot clean a kept core: 3 wedges in its slit, poking or 1e-8 under, whatever their ids", function()
		for _, def in ipairs({ { 0.05, 0.0125, 0.082, 0.12 }, { 0.08, -1e-8, 0.098, 0.14 } }) do
			local c, above, h, b = def[1], def[2], def[3], def[4]
			local K, y = cheeks(c, 0.02, 0.08, true)
			local plain = table.clone(K)
			table.insert(plain, core(y, 0.02, "Guard"))
			withIds(plain)
			A.deepEq(Sampling.exposure(H.prepared({ parts = plain })).cleaned, {}, "kept alone")
			local pinned = {}
			for _, yc in ipairs({ 1.65, 2.05, 2.45 }) do
				table.insert(pinned, pin(0, yc, 0.01 + above, b, h))
			end
			for _, p in ipairs(plain) do
				table.insert(pinned, Drafts.deepCopy(p))
			end
			withIds(pinned)
			local e = Sampling.exposure(H.prepared({ parts = pinned }))
			A.truthy(e.kept[#pinned], "the core is still kept, " .. c)
		end
	end)

	t.it("§5 a fuller is seen: a core under cover strips, a groove or a twin, kept by what shows, cleaned by what does not", function()
		local function fuller(w: number, t: number, c: number, gaps: { { number } }): ({ any }, number)
			local L = 2.5
			local y = 1.45 + L / 2
			local parts = hiltFor(1.1)
			table.insert(parts, H.part(0, "Blade", "Block", "Iron", { 0, y, 0 }, H.I, { w, L, t }))
			local index = #parts
			local a = -w / 2
			local cuts: { { number } } = {}
			for _, g in ipairs(gaps) do
				table.insert(cuts, { a, g[1] })
				a = g[2]
			end
			table.insert(cuts, { a, w / 2 })
			for s = -1, 1, 2 do
				for _, st in ipairs(cuts) do
					table.insert(parts, H.part(0, "Blade", "Block", "Iron", { (st[1] + st[2]) / 2, y, s * (t / 2 + c / 2) }, H.I, { st[2] - st[1], L, c }))
				end
			end
			table.insert(parts, H.part(0, "Guard", "Block", "Iron", { 0, 1.45 + L + 0.02, 0 }, H.I, { w + 0.08, 0.04, t + 2 * c }))
			table.insert(parts, H.part(0, "Guard", "Block", "Iron", { w / 2 + 0.02, y, 0 }, H.I, { 0.04, L, t + 2 * c }))
			table.insert(parts, H.part(0, "Guard", "Block", "Iron", { -w / 2 - 0.02, y, 0 }, H.I, { 0.04, L, t + 2 * c }))
			return withIds(parts), index
		end
		local function check(parts: { any }, i: number, share: number, kept: boolean, what: string)
			local list = H.prepared({ parts = parts })
			A.near(shareOf(list, i), share, 0.002, what .. " shows")
			A.eq(Sampling.exposure(list).kept[i], kept, what)
		end
		local p, i = fuller(0.3, 0.04, 0.03, { { -0.005 + 0.09, 0.005 + 0.09 } })
		check(p, i, 0.0285, true, "core 0.3, a groove 0.01")
		p, i = fuller(0.2, 0.04, 0.03, { { -0.06, -0.04 }, { 0.04, 0.06 } })
		check(p, i, 0.162, true, "core 0.2, twin 0.02")
		p, i = fuller(0.2, 0.02, 0.05, { { -0.075, -0.025 }, { 0.025, 0.075 } })
		check(p, i, 0.4459, true, "core 0.2, twin 0.05")
		p, i = fuller(0.8, 0.08, 0.03, { { -0.005, 0.005 } })
		check(p, i, 0.0111, false, "core 0.8, a groove 0.01 at its centre")
	end)

	t.it("§5 a comb is seen: 7 stripes on one face of a blade that shows 20 %", function()
		local w, L, t = 1.2, 2.5, 0.2
		local y = 1.48 + L / 2
		local parts = hiltFor(1.1)
		table.insert(parts, H.part(0, "Blade", "Block", "Iron", { 0, y, 0 }, H.I, { w, L, t }))
		local index = #parts
		-- 4 columns of half-width 0.15 (where an earlier reading's patches stood); a stripe over each boundary and over each centre
		local hw, extra = 0.15, 0.0005
		local function stripe(a: number, b: number)
			table.insert(parts, H.part(0, "Blade", "Block", "Iron", { (a + b) / 2, y, t / 2 + 0.015 }, H.I, { b - a, L, 0.03 }))
		end
		for k = 0, 4 do
			local bx = -w / 2 + k * 2 * hw
			stripe(math.max(-w / 2, bx - 0.25 * hw - extra), math.min(w / 2, bx + 0.25 * hw + extra))
		end
		for k = 0, 3 do
			local cx = -w / 2 + (2 * k + 1) * hw
			stripe(cx - 0.25 * hw - extra, cx + 0.25 * hw + extra)
		end
		table.insert(parts, H.part(0, "Guard", "Block", "Iron", { 0, y, -t / 2 - 0.015 }, H.I, { w, L, 0.03 }))
		table.insert(parts, H.part(0, "Guard", "Block", "Iron", { 0, y + L / 2 + 0.02, 0 }, H.I, { w + 0.08, 0.04, t + 0.06 }))
		table.insert(parts, H.part(0, "Guard", "Block", "Iron", { w / 2 + 0.02, y, 0 }, H.I, { 0.04, L, t + 0.06 }))
		table.insert(parts, H.part(0, "Guard", "Block", "Iron", { -w / 2 - 0.02, y, 0 }, H.I, { 0.04, L, t + 0.06 }))
		local list = H.prepared({ parts = withIds(parts) })
		A.within(shareOf(list, index), 0.15, 0.25, "the slits show")
		A.truthy(Sampling.exposure(list).kept[index], "the blade is kept")
	end)

	t.it("§4.9 the measure's ladder: exactly N_SURF_WORK fits", function()
		local e = H.plantedSampling({ N_SURF_WORK = 96 }).exposure(H.prepared({ parts = { H.solid(1, "Block", { 0, 2, 0 }, H.I, { 0.32, 0.32, 0.32 }) } }))
		A.eq(e.hSurf, 0.08, "a cube 0.32 alone: 96 samples at 0.08")
	end)

	t.it("§4.4 a part exactly on the Dust floor hides like any other", function()
		local side = 0.125 -- a power of 2, so the volume comes back exact
		local thick = Geo.MIN_PART_VOLUME / (side * side)
		-- a plate on a slab, between 4 walls, all smaller than it: only its top shows, the floor part lies on it, taller than the probe
		local function around(lid: any?): { any }
			local parts = {
				H.solid(1, "Block", { 0, -0.01, 0 }, H.I, { side, 0.02, side }),
				H.solid(2, "Block", { 0, -0.0275, 0 }, H.I, { side, 0.015, side }),
				H.solid(3, "Block", { side / 2 + 0.01, -0.03, 0 }, H.I, { 0.02, 0.06, 0.2 }),
				H.solid(4, "Block", { -side / 2 - 0.01, -0.03, 0 }, H.I, { 0.02, 0.06, 0.2 }),
				H.solid(5, "Block", { 0, -0.03, side / 2 + 0.01 }, H.I, { 0.2, 0.06, 0.02 }),
				H.solid(6, "Block", { 0, -0.03, -side / 2 - 0.01 }, H.I, { 0.2, 0.06, 0.02 }),
			}
			if lid then
				table.insert(parts, lid)
			end
			return parts
		end
		local on = H.solid(7, "Block", { 0, thick / 2, 0 }, H.I, { side, thick, side })
		A.eq(H.prepare(on).volume, Geo.MIN_PART_VOLUME, "exactly the floor")
		A.truthy(thick > Geo.HIDE_OFFSET, "over the probe")
		A.truthy(keptOf(H.prepared({ parts = around() }), 1), "its top shows")
		A.falsy(keptOf(H.prepared({ parts = around(on) }), 1), "the top is under it: Enclosed")
	end)
end)
