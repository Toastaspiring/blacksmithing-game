--!strict
-- T-PHY-09's Enclosed verdict (SPEC §4.4, §5, E-S2.11): each part on a grid of its own, against every part but exact copies and
-- Dust, with no budget. What other parts and ids cannot do to it, and how it reads a patch, rule by rule on designs small enough
-- to work out by hand. It keeps no number: H.verdictReads reads it off a planted threshold.

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
local Mirror = require("../../src/shared/Blueprint/Mirror")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

type Rng = TestRng.TestRng

local Geo = Balance.Geometry
local EPS = Geo.EPS_GEOM -- what a hide test grants at a part's edge: a slit between two reads this much narrower each side
local ROD1_READS, ROD2_READS, BULGE_READS = 0.99699700288840931, 0.98430422513855187, 0.22830150632389962
local POST_READS = 0.93619791666666741
local UNITS_LIDS, UNITS_WEDGE, UNITS_ROD, UNITS_RAISED = 70312, 8599, 84935, 53822

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

-- ── a plate on a grid worked out by hand ──────────────────────────────────────────────────────────────────────────

-- 0.5 × 0.5 × 0.02, on a slab, between 4 walls whose tops are flush with its top at y = 0, so only the top shows: each of them is
-- smaller than the plate, which keeps the top (a host round it would take it, by rank). Spacing 0.16 fits VERDICT_SAMPLES
-- (2 · 4 · 4 + 4 · 4 · 1 = 48): 4 × 4 patches of half-width 0.0625 a face. Lines stand at ±0.25 and ±0.75 of that, corners at
-- 0.98. Lids stand on the top, each { x0, x1, z0, z1 }; FAR is past the plate's rim.
local PLATE_AREA, PATCH, PATCH_WIDTH = 2 * 0.25 + 4 * 0.5 * 0.02, 0.125 * 0.125, 0.125
local FAR = 0.5
local WALLS = 6 -- the parts of the plate's surround and the plate itself

local function partsUnder(lids: { { number } }): { any }
	local parts = {
		H.solid(1, "Block", { 0, -0.01, 0 }, H.I, { 0.5, 0.02, 0.5 }),
		H.solid(2, "Block", { 0, -0.0275, 0 }, H.I, { 0.5, 0.015, 0.5 }),
		H.solid(3, "Block", { 0.26, -0.02, 0 }, H.I, { 0.02, 0.04, 0.54 }),
		H.solid(4, "Block", { -0.26, -0.02, 0 }, H.I, { 0.02, 0.04, 0.54 }),
		H.solid(5, "Block", { 0, -0.02, 0.26 }, H.I, { 0.5, 0.04, 0.02 }),
		H.solid(6, "Block", { 0, -0.02, -0.26 }, H.I, { 0.5, 0.04, 0.02 }),
	}
	for k, lid in ipairs(lids) do
		table.insert(parts, H.solid(WALLS + k, "Block", { (lid[1] + lid[2]) / 2, 0.05, (lid[3] + lid[4]) / 2 }, H.I, { lid[2] - lid[1], 0.1, lid[4] - lid[3] }))
	end
	return parts
end

local function underLids(lids: { { number } }): { any }
	return H.prepared({ parts = partsUnder(lids) })
end

local function keptOf(list: { any }, i: number): boolean
	return Sampling.exposure(list).kept[i]
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

	t.it("§5 random fill around a large design: kept parts bit-identical, 40 designs", function()
		fillLeavesKept(40)
	end)
	t.slow("§5 random fill around a large design: kept parts bit-identical, FUZZ_N_VALID designs", function()
		fillLeavesKept(Tol.FUZZ_N_VALID)
	end)

	-- The candidates' order is the parts' order, so any order of the fill shuffles what each verdict tries first.
	local function shuffled(rng: Rng, list: { any }): { any }
		local out = table.clone(list)
		for i = #out, 2, -1 do
			local j = rng:int(1, i)
			out[i], out[j] = out[j], out[i]
		end
		return out
	end

	t.it("§4.4 the hider-first order changes no bit: any order of the fill, before or among the kept parts, 20 designs", function()
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

	-- Candidates in every order, by exact numbers: the slit through 3 patches' centres under 3 lids, and the slab, the plate first.
	t.it("§4.4 the hider-first order changes no bit: what the verdict reads, every order of 4 candidates", function()
		local g = 0.03
		local list = partsUnder({ { -FAR, 0.0625 - g / 2, -FAR, FAR }, { 0.0625 + g / 2, FAR, -FAR, FAR }, { -FAR, FAR, 0.125, FAR } })
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
		local reads = 3 * (PATCH * (g - 2 * EPS) / PATCH_WIDTH) / PLATE_AREA
		local under = H.plantedSampling({ ENCLOSED_EXPOSED_MAX = reads * (1 - 1e-9) })
		local over = H.plantedSampling({ ENCLOSED_EXPOSED_MAX = reads * (1 + 1e-9) })
		permutations(#others, function()
			local order = H.prepared({ parts = { plate, others[1], others[2], others[3], others[4], walls[1], walls[2], walls[3], walls[4] } })
			A.truthy(under.exposure(order).kept[1], "reads at least the 3 patches")
			A.falsy(over.exposure(order).kept[1], "reads at most the 3 patches")
		end)
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

	-- A real blade, a plate wholly inside it flush with a face. By id the plate kept the face and the blade, its faces all taken,
	-- read nothing: solid in mass, hollow in D. The larger part keeps the face, whatever the ids.
	t.it("§4.4 flush plates inside a real blade are the ones cleaned, whatever their ids", function()
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
			local tz = math.min(0.02, h.size[3] / 3)
			local tx = math.min(0.02, h.size[1] / 3)
			local before = Sampling.exposure(H.prepared(design))
			local skin = {
				H.part(101, "Guard", "Block", "Iron", { h.pos[1], h.pos[2], h.pos[3] + (h.size[3] - tz) / 2 }, h.rot, { h.size[1], h.size[2], tz }),
				H.part(102, "Guard", "Block", "Iron", { h.pos[1], h.pos[2], h.pos[3] - (h.size[3] - tz) / 2 }, h.rot, { h.size[1], h.size[2], tz }),
				H.part(103, "Pommel", "Block", "Iron", { h.pos[1] + (h.size[1] - tx) / 2, h.pos[2], h.pos[3] }, h.rot, { tx, h.size[2], h.size[3] }),
				H.part(104, "Pommel", "Block", "Iron", { h.pos[1] - (h.size[1] - tx) / 2, h.pos[2], h.pos[3] }, h.rot, { tx, h.size[2], h.size[3] }),
			}
			if h.shape == "Block" and h.rot[4] == 1 then
				checked += 1
				local first: { any } = table.clone(skin)
				for _, p in ipairs(design.parts) do
					table.insert(first, p)
				end
				local after = Sampling.exposure(H.prepared({ parts = first }))
				for k = 1, 4 do
					A.falsy(after.kept[k], name .. ": plate " .. k .. " is cleaned, the blade keeps its faces")
				end
				for i = 1, #design.parts do
					A.eq(after.kept[4 + i], before.kept[i], name .. " part " .. i)
					A.eq(after.exposedKept[4 + i], before.exposedKept[i], name .. " part " .. i .. " measures as without them")
				end
			end
		end
		A.truthy(checked >= 3, "main blades that are upright Blocks: " .. checked)
	end)

	-- An exact copy hides nothing and takes nothing, in front of its original or in another slot, while the original's slot's name
	-- comes first (a copy in one that comes before it is no more than relabelling the part).
	t.it("§4.4 an exact copy changes nothing: first or last, in a slot that comes later, in another material", function()
		for _, name in ipairs({ "F1", "F3", "F4" }) do
			local design = H.f(name)
			local before = Sampling.exposure(H.prepared(design))
			for i, p in ipairs(design.parts) do
				if p.slot == "Blade" then
					local later = Drafts.deepCopy(p)
					later.id, later.slot = 200, "Guard"
					local other = Drafts.deepCopy(p)
					other.id, other.material = 201, "Tin" -- a name that comes after any of them
					local first: { any } = { later, other }
					for _, q in ipairs(design.parts) do
						table.insert(first, q)
					end
					local after = Sampling.exposure(H.prepared({ parts = first }))
					A.deepEq({ after.kept[1], after.kept[2] }, { false, false }, name .. " part " .. i .. ": the copies are cleaned")
					for j = 1, #design.parts do
						A.eq(after.exposedKept[2 + j], before.exposedKept[j], name .. " part " .. j)
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

	t.it("§4.4 Sampling.ranked: the larger first, then by where it stands, |x| before x, whatever the order", function()
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
		local want = { 1, 2, 3, 6, 5, 4 }
		A.deepEq(row({ big, low, middle, right, left, back }), want)
		A.deepEq(row({ back, left, right, middle, low, big }), want)
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
		local rank = Sampling.ranked(H.prepared({ parts = { low, big } }))
		A.deepEq(rank, { 2, 1 }, "rank per part")
	end)

	-- ── reading a patch ───────────────────────────────────────────────────────────────────────────────────────────

	-- On a laminated hilt: 2 proud rims of the core, 0.02 past the cheeks, its faces hidden by them, a cap over its top. Cleaned, the
	-- chord through the blade opens and Hammering jumps 0.47 (§17.2): the worst of the old rule's tier flips.
	t.it("§5 a laminated core that shows 5.54 % is kept: its proud rims are measured", function()
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
		-- spacing 0.4: 3 × 5 patches on a large face. Its 10 rim patches read the strip's 0.02 of their width, on lines that all stand
		-- above the guard; the rims show from the guard up, and the top rim where the cap stops
		local area = 2 * (1.04 * 2 + 1.04 * 0.02 + 2 * 0.02)
		local strip = 0.02 - EPS
		H.verdictReads(list, 7, (2 * 10 * strip * 0.4 + 2 * 0.02 * (2 - 0.03 - EPS) + 2 * strip * 0.02) / area, "the strips")
	end)

	t.it("§4.4 a strip along the rim is measured, on the lines that cross it", function()
		-- each of the 12 patches it passes reads s of its width: on a corner patch too, whose second strip lies along its lines and
		-- between them. It shows 0.25 − 0.484², so the corners read short of that
		local s = 0.008
		local inner, outer = -0.25 + s, 0.25 - s
		local function strip(width: number): number
			return PATCH * (width - EPS) / PATCH_WIDTH
		end
		local ring = underLids({ { inner, outer, inner, outer } })
		H.verdictReads(ring, 1, 12 * strip(s) / PLATE_AREA, "all round: the 12 patches of the ring")
		A.truthy(keptOf(ring, 1), "reads 2.22 %, shows 2.92 %: kept")
		local three = underLids({ { inner, outer, -FAR, outer } })
		H.verdictReads(three, 1, 10 * strip(s) / PLATE_AREA, "on 3 sides: 10 patches")
		A.falsy(keptOf(three, 1), "reads 1.85 %, shows 2.20 %: cleaned")
		H.verdictReads(underLids({ { -FAR, outer, -FAR, FAR } }), 1, 4 * strip(s) / PLATE_AREA, "on 1 side: 4 patches")
		-- a hair reads a hair, past the corners' reach; inside it one part hides all that is tested
		local hair = 0.002
		H.verdictReads(underLids({ { -0.25 + hair, 0.25 - hair, -0.25 + hair, 0.25 - hair } }), 1, 12 * strip(hair) / PLATE_AREA, "a hair round the rim")
		H.verdictReads(underLids({ { -0.25 + 0.001, 0.25 - 0.001, -0.25 + 0.001, 0.25 - 0.001 } }), 1, 0, "inside the corners")
		-- on a line's far side: 0.02 holds the outer lines. Those that lie in a strip read whole and disagree with the rest: on a side
		-- patch the other family, which crosses it, agrees and wins; on a corner patch both disagree alike, and the first reads 3 lines
		-- across a strip and one in the other
		local wide = 0.02
		local cross = (wide - EPS) / PATCH_WIDTH
		H.verdictReads(underLids({ { -0.25 + wide, 0.25 - wide, -0.25 + wide, 0.25 - wide } }), 1, (8 * PATCH * cross + 4 * PATCH * (3 * cross + 1) / 4) / PLATE_AREA, "wider")
	end)

	t.it("§4.4 a strip through the centres is measured: a hairline reads a hairline", function()
		-- along the column of patches centred on x = 0.0625
		local function slit(g: number, extra: { { number } }?): { any }
			local lids = { { -FAR, 0.0625 - g / 2, -FAR, FAR }, { 0.0625 + g / 2, FAR, -FAR, FAR } }
			for _, lid in ipairs(extra or {}) do
				table.insert(lids, lid)
			end
			return underLids(lids)
		end
		local g = 0.03
		local reads = PATCH * (g - 2 * EPS) / PATCH_WIDTH / PLATE_AREA
		local four = slit(g)
		H.verdictReads(four, 1, 4 * reads, "through 4 patches")
		A.truthy(keptOf(four, 1), "shows 2.78 %: kept")
		local three = slit(g, { { -FAR, FAR, 0.125, FAR } })
		H.verdictReads(three, 1, 3 * reads, "through 3 patches")
		A.truthy(keptOf(three, 1), "shows 2.08 %: kept")
		local two = slit(g, { { -FAR, FAR, 0, FAR } })
		H.verdictReads(two, 1, 2 * reads, "through 2 patches")
		A.falsy(keptOf(two, 1), "shows 1.39 %: cleaned")
		-- a filler behind a hairline stays cleaned: a credit that stood on the centre alone kept it at 1/4 of each patch
		local hairline = slit(0.00001)
		H.verdictReads(hairline, 1, 4 * PATCH * (0.00001 - 2 * EPS) / PATCH_WIDTH / PLATE_AREA, "a hairline")
		A.falsy(keptOf(hairline, 1), "shows 0.00 %: cleaned")
		-- on the line of the crossing family: the family that lies in it reads one line whole and disagrees, so the other decides
		local onLine = 0.0625 + 0.25 * 0.0625
		H.verdictReads(underLids({ { -FAR, onLine - 0.00001, -FAR, FAR }, { onLine + 0.00001, FAR, -FAR, FAR } }), 1, 4 * PATCH * (0.00002 - 2 * EPS) / PATCH_WIDTH / PLATE_AREA, "a hairline on a line")
	end)

	t.it("§4.4 the lines read a slit wherever it passes: between the points of the patch, and in pairs", function()
		-- the fullered blade: 2 slits on one column of patches, between its centre and corners and between the old sub-points
		local function reads(lids: { { number } }, shows: number, what: string)
			H.verdictReads(underLids(lids), 1, 4 * (PATCH * shows / PATCH_WIDTH) / PLATE_AREA, what)
		end
		reads({ { -FAR, 0.1, -FAR, FAR }, { 0.12, FAR, -FAR, FAR } }, 0.02 - 2 * EPS, "past a sub-point")
		reads({ { -FAR, 0.0825, -FAR, FAR }, { 0.1025, FAR, -FAR, FAR } }, 0.02 - 2 * EPS, "between sub-points")
		reads({ { -FAR, 0.04, -FAR, FAR }, { 0.05, 0.085, -FAR, FAR }, { 0.095, FAR, -FAR, FAR } }, 0.02 - 4 * EPS, "2 slits of 0.01 either side of a centre")
		-- past the corners' reach of a patch, the lid hiding centre and corners of its neighbours: 1 part hides those, this one is measured
		reads({ { -FAR, 0.12, -FAR, FAR }, { 0.1235, FAR, -FAR, FAR } }, 0.0035 - 2 * EPS, "by a patch's rim")
		-- what shows lies between one family's lines: the family that reads nothing loses, whichever it is
		local across = { { -FAR, FAR, -FAR, 0.1 }, { -FAR, FAR, 0.12, FAR } }
		reads(across, 0.02 - 2 * EPS, "the other way")
		local partial = underLids({ { -FAR, 0.1, -FAR, FAR }, { 0.12, FAR, -FAR, FAR }, { 0.09, 0.13, 0, FAR } })
		H.verdictReads(partial, 1, 2 * (PATCH * (0.02 - 2 * EPS) / PATCH_WIDTH) / PLATE_AREA, "a slit that stops on a patch's rim")
		-- a cross of slits on both families' lines reads a line each way: the rule's blind spot, 1/4 of a patch for what hardly shows
		local x, z = 0.0625 + 0.25 * 0.0625, 0.0625 + 0.25 * 0.0625
		local e = 0.00001
		local cross = underLids({ { -FAR, x - e, -FAR, z - e }, { x + e, FAR, -FAR, z - e }, { -FAR, x - e, z + e, FAR }, { x + e, FAR, z + e, FAR } })
		local hair = (2 * e - 2 * EPS) / PATCH_WIDTH
		H.verdictReads(cross, 1, (6 * PATCH * hair + PATCH * (1 + 3 * hair) / 4) / PLATE_AREA, "3 + 3 patches a hairline, the one where they cross 1/4")
		A.falsy(keptOf(cross, 1), "1 patch is under 2 %")
	end)

	t.it("§4.4 a part that cannot reach the patch's plane changes no line, and neither does one far along it", function()
		-- each lid in turn lifted past the probe, or sunk past the rim: a near part, by distance, that hides nothing
		local g = 0.03
		local lids = { { -FAR, 0.0625 - g / 2, -FAR, FAR }, { 0.0625 + g / 2, FAR, -FAR, FAR } }
		local parts = partsUnder(lids)
		-- a thin bar just above the probe, along the slit: it hides nothing, at a hair below the probe it closes the slit
		local function bar(y: number): any
			return H.solid(20, "Block", { 0.0625, y + 0.05, 0 }, H.I, { 0.06, 0.1, 0.6 })
		end
		local above = table.clone(parts)
		table.insert(above, bar(Geo.HIDE_OFFSET + 3 * Geo.EPS_GEOM))
		H.verdictReads(H.prepared({ parts = above }), 1, 4 * (PATCH * (g - 2 * EPS) / PATCH_WIDTH) / PLATE_AREA, "over the probe")
		local under = table.clone(parts)
		table.insert(under, bar(Geo.HIDE_OFFSET - 3 * Geo.EPS_GEOM))
		H.verdictReads(H.prepared({ parts = under }), 1, 0, "under the probe")
	end)

	t.it("§4.4 corners at VERDICT_CORNER: the one part must hide them, or the patch is measured", function()
		-- F5 and 6 copies of its blade at z = k · 0.002. Each of the first 5 has a true strip 0.002 wide on its rim, by rank: the copy
		-- below it keeps the rest of the rim. Spacing 0.2 on the 0.16 × 2.6 × 0.06 copy: 13 patches a rim side, crossed by lines at
		-- 0.002 of their 0.06, and one end. They all stay cleaned, read to the bit
		local design = H.f("F5")
		local blade = design.parts[4]
		for k = 1, 6 do
			table.insert(design.parts, H.part(10 + k, "Blade", "Block", "Iron", { blade.pos[1], blade.pos[2], k * 0.002 }, H.I, blade.size))
		end
		local list = H.prepared(design)
		local e = Sampling.exposure(list)
		local cleaned: { any } = {}
		for k = 1, 5 do
			cleaned[k] = { partId = 10 + k, reason = "Enclosed" }
		end
		A.deepEq(e.cleaned, cleaned, "the copies under another, the last one kept")
		local area = 2 * (0.16 * 2.6 + 0.16 * 0.06 + 2.6 * 0.06)
		local rim, tip = 0.06 * 2.6 / 13, 0.16 * 0.06
		for k = 1, 5 do
			H.verdictReads(list, #design.parts - 6 + k, (2 * 13 * rim + tip) * ((0.002 - EPS) / 0.06) / area, "copy " .. k)
		end
		-- a lid over the centre and short of the corners of a column of patches: the rest is measured, the next column shows whole
		local reach = 0.0625 + 0.9 * 0.0625
		local rest = 0.1 * 0.0625 - EPS
		H.verdictReads(underLids({ { -FAR, reach, -FAR, FAR } }), 1, (4 * PATCH * rest / PATCH_WIDTH + 4 * PATCH) / PLATE_AREA, "short of the corners")
		-- past them: within the last 2 %, one part hides it all, and a rim that thin goes unread
		local past = 0.0625 + 0.99 * 0.0625
		H.verdictReads(underLids({ { -FAR, past, -FAR, FAR } }), 1, 4 * PATCH / PLATE_AREA, "past the corners")
	end)

	t.it("§4.4 one part must hide the whole patch: a slit between two hiders shows", function()
		-- the slit passes between the centre and the corners of the patches centred on x = 0.0625: all five points are hidden, by two parts
		local slit = underLids({ { -FAR, 0.0625 + 0.03, -FAR, FAR }, { 0.0625 + 0.0575, FAR, -FAR, FAR } })
		H.verdictReads(slit, 1, 4 * (PATCH * (0.0275 - 2 * EPS) / PATCH_WIDTH) / PLATE_AREA, "the slit's width on 4 patches")
		A.truthy(keptOf(slit, 1), "reads 2.55 %: kept")
		H.verdictReads(underLids({ { -FAR, FAR, -FAR, FAR } }), 1, 0, "one lid")
	end)

	-- A lid over the centre and 3 corners of the patch centred on (0.0625, 0.0625), its edge x + z = 0.2 past the 4th: all 4 corners
	-- count. Straight lids over the rest of the plate leave only that corner's triangle, which the lines at z = 0.078 and 0.109 read.
	t.it("§4.4 the one part must hide all 4 corners: a lid with a corner off is measured", function()
		local c, D = 0.2, 1
		local n = math.sqrt(0.5)
		local dist = c * n - D
		local parts = partsUnder({ { 0.125, FAR, -FAR, FAR }, { -FAR, 0.125, 0.125, FAR } })
		table.insert(parts, H.solid(20, "Block", { n * dist, 0.05, n * dist }, H.axisAngle(0, 1, 0, -45), { 2 * D, 0.1, 3 }))
		local function line(z: number): number
			return ((0.125 - EPS) - (c - z + EPS / n)) / PATCH_WIDTH
		end
		H.verdictReads(H.prepared({ parts = parts }), 1, PATCH * (line(0.078125) + line(0.109375)) / 4 / PLATE_AREA, "2 lines of 4 cross what shows")
	end)

	t.it("§4.4 the one part: asked among all that hide the centre, its corners by probe as well, its centre hidden too", function()
		-- a hair round the rim, inside the corners' reach of a lid that hides all five. A second lid hides only the centres, so that it
		-- comes first on some patches: the one that hides all five is still found, and the hair goes unread
		local hair = 0.001
		local ring = { -0.25 + hair, 0.25 - hair, -0.25 + hair, 0.25 - hair }
		H.verdictReads(underLids({ { -0.2, 0.2, -0.2, 0.2 }, ring }), 1, 0, "2 lids")
		H.verdictReads(underLids({ ring, { -0.2, 0.2, -0.2, 0.2 } }), 1, 0, "2 lids, the other order")
		-- the same lid 0.005 over the top: it hides the corners by the probe alone
		local raised = partsUnder({})
		table.insert(raised, H.solid(20, "Block", { 0, 0.005 + 0.05, 0 }, H.I, { 2 * ring[2], 0.1, 2 * ring[2] }))
		H.verdictReads(H.prepared({ parts = raised }), 1, 0, "raised")
		-- a thin plate slanting through the surface. At the surface it holds the 2 corners at x = 0.124, at the probe's height the 2 at
		-- x = 0.001, and the centre neither: the patch is measured, on lines that cross the 2 bands, and so are the 2 patches beside it
		local cot = 10
		local angle = math.deg(math.atan(1 / cot))
		local halfBand, xc = 0.02, 0.0625 + 0.06
		local t = 2 * halfBand * math.sin(math.rad(angle))
		local slanted = partsUnder({})
		table.insert(slanted, H.solid(20, "Block", { xc, 0, 0.0625 }, H.axisAngle(0, 0, 1, -angle), { 0.5, t, 0.13 }))
		local list = H.prepared({ parts = slanted })
		A.truthy(list[#list].volume >= Geo.MIN_PART_VOLUME, "it hides")
		-- 2 × 0.04 of hidden line in all, on the 3 patches; the eps the probe's band grows by the surface's band shrinks by
		H.verdictReads(list, 1, (0.25 - PATCH * (2 * 2 * halfBand) / PATCH_WIDTH) / PLATE_AREA, "2 bands with a gap between them")
	end)

	t.it("§4.4 a part reaches a patch on any of its own axes: a lid reads the same turned so that each of them lies along each of the patch's", function()
		-- a slit between 2 lids, each given by world extents: (x, y, z) → (y, z, x) and (z, x, y), and a lid that hides the slit's end
		-- short of the centre of a patch: it reaches that patch by e2 alone. The last line of that patch reads nothing and the lines
		-- along the slit stand beside it, so it reads 3/4 of the slit's width
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
			H.verdictReads(H.prepared({ parts = parts }), 1, 2.75 * (PATCH * (g - 2 * EPS) / PATCH_WIDTH) / PLATE_AREA, "turn " .. turn)
			-- and a lid lying on the plate: its bottom on the surface at each turn. Only the rim of its own patch shows
			local whole = partsUnder({})
			table.insert(whole, lid(13, -FAR, FAR, -FAR, FAR, turn))
			H.verdictReads(H.prepared({ parts = whole }), 1, 0, "whole, turn " .. turn)
		end
	end)

	t.it("§4.4 of 2 families that agree alike the smaller reading stands: a bar between the lines along it", function()
		-- 0.02 wide along x, between the lines at z = 0.078 and 0.109 of the patches centred on z = 0.0625: the lines along x all show
		-- whole, the lines along z all cross it
		local parts = underLids({ { -FAR, FAR, 0.0825, 0.1025 } })
		H.verdictReads(parts, 1, (16 * PATCH - 4 * PATCH * (0.02 + 2 * EPS) / PATCH_WIDTH) / PLATE_AREA, "the bar's width on 4 patches")
	end)

	-- The designs of §17.2's reading rows: blades whose cover parts leave slits. The hilt and the frame are common; a core or a filler
	-- stands between 2 cheeks.
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

	t.it("§5 a hairline keeps no filler: a core behind a slit 0.00001 wide through its patches' centres is cleaned, K + F measures as K", function()
		local K, y = cheeks(0.05, 0.02, 0.00001, false)
		withIds(K)
		local filled = Drafts.deepCopy(K)
		table.insert(filled, core(y, 0.02, "Guard"))
		withIds(filled)
		local list = H.prepared({ parts = filled })
		A.near(shareOf(list, #filled), 0, 0.0005, "it hardly shows")
		local after = Sampling.exposure(list)
		A.deepEq(after.cleaned, { { partId = #filled, reason = "Enclosed" } }, "a credit on the centre kept it")
		H.sameKeptMeasure(after, Sampling.exposure(H.prepared({ parts = K })), #K)
	end)

	t.it("§5 pins cannot clean a kept core: 3 wedges at its reading points, poking or 1e-8 under, whatever their ids", function()
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
		check(p, i, 0.162, true, "core 0.2, twin 0.02 between where sub-columns stood")
		p, i = fuller(0.2, 0.02, 0.05, { { -0.075, -0.025 }, { 0.025, 0.075 } })
		check(p, i, 0.4459, true, "core 0.2, twin 0.05")
		p, i = fuller(0.8, 0.08, 0.03, { { -0.005, 0.005 } })
		check(p, i, 0.0111, false, "core 0.8, a groove 0.01 through the patch centres")
	end)

	t.it("§5 a comb is seen: 7 stripes on one face of a blade that shows 20 %", function()
		local w, L, t = 1.2, 2.5, 0.2
		local y = 1.48 + L / 2
		local parts = hiltFor(1.1)
		table.insert(parts, H.part(0, "Blade", "Block", "Iron", { 0, y, 0 }, H.I, { w, L, t }))
		local index = #parts
		-- spacing 0.32: 4 columns of half-width 0.15; a stripe over each boundary's near lines and over each centre's
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

	-- A Cylinder's side keeps points: a strip under the sub-grid's reach is a credit.
	local function inSlit(spin: number, g: number): ({ any }, number)
		local r, L = 0.1, 0.5
		local rod = H.solid(1, "Cylinder", { 0, 0, 0 }, H.axisAngle(1, 0, 0, spin), { L, 2 * r, 2 * r })
		local upper = H.solid(2, "Block", { 0, 0, g / 2 + 1 }, H.I, { 4, 4, 2 })
		local lower = H.solid(3, "Block", { 0, 0, -g / 2 - 1 }, H.I, { 4, 4, 2 })
		local end1 = H.solid(4, "Block", { L / 2 + 1, 0, 0 }, H.I, { 2, 4, 4 })
		local end2 = H.solid(5, "Block", { -L / 2 - 1, 0, 0 }, H.I, { 2, 4, 4 })
		return H.prepared({ parts = { rod, upper, lower, end1, end2 } }), 2 * math.pi * r * L / 40 / (2 * math.pi * r * L + 2 * math.pi * r * r)
	end

	-- What the reading charges, in all, on a slit between lids (lines, their chords, the reach, the search) and on a Cylinder's side
	-- (its corners, its search, its sub-grid): the checkpoints go by it, so a shortcut that spends differently shows here.
	t.it("§4.9 spend reports the reading's work", function()
		local function unitsOf(parts: { any }): number
			local units = 0
			Sampling.exposure(H.prepared({ parts = parts }), function(n: number)
				units += n
			end)
			return units
		end
		local g = 0.03
		A.eq(unitsOf(partsUnder({ { -FAR, 0.0625 - g / 2, -FAR, FAR }, { 0.0625 + g / 2, FAR, -FAR, FAR }, { -FAR, FAR, 0.125, FAR } })), UNITS_LIDS, "a slit under 3 lids")
		-- lids that stand clear of the surface: no chord there
		local raised = partsUnder({})
		table.insert(raised, H.solid(10, "Block", { (-FAR + 0.0625 - g / 2) / 2, 0.055, 0 }, H.I, { FAR + 0.0625 - g / 2, 0.1, 2 * FAR }))
		table.insert(raised, H.solid(11, "Block", { (FAR + 0.0625 + g / 2) / 2, 0.055, 0 }, H.I, { FAR - 0.0625 - g / 2, 0.1, 2 * FAR }))
		A.eq(unitsOf(raised), UNITS_RAISED, "2 lids 0.005 over the top")
		local turned = H.solid(9, "Wedge", { 0, 0.05, 0 }, H.axisAngle(0, 1, 0, 30), { 0.4, 0.1, 0.4 })
		A.eq(unitsOf({ turned, H.solid(10, "Block", { 0.1, 0.05, 0 }, H.I, { 0.2, 0.2, 0.2 }), H.solid(11, "Block", { -0.1, 0.05, 0.05 }, H.I, { 0.25, 0.1, 0.1 }) }), UNITS_WEDGE, "a wedge among blocks")
		local rod = inSlit(0, 0.01)
		local parts: { any } = {}
		for i, p in ipairs(rod) do
			parts[i] = H.solid(i, p.shape, { p.cx, p.cy, p.cz }, H.I, { 2 * p.hx, 2 * p.hy, 2 * p.hz })
		end
		A.eq(unitsOf(parts), UNITS_ROD, "a rod in a slit")
	end)

	-- "the first H_LADDER factor ... with at most VERDICT_SAMPLES": exactly 64 fits. 0.6 × 0.6 × 0.3 at 0.16 is 4, 4, 2 cells: 2 (16 + 8 + 8)
	-- = 64. The charge shows the grid: 64 samples written at 0.16, fewer on the next rung.
	t.it("§4.4 a part whose Block estimate is exactly VERDICT_SAMPLES stays on that rung", function()
		local units = 0
		Sampling.exposure(H.prepared({ parts = { H.solid(1, "Block", { 0, 2, 0 }, H.I, { 0.6, 0.6, 0.3 }) } }), function(n: number)
			units += n
		end)
		A.eq(units, 4909)
	end)

	t.it("§4.9 the measure's ladder: exactly N_SURF_WORK fits", function()
		local e = H.plantedSampling({ N_SURF_WORK = 96 }).exposure(H.prepared({ parts = { H.solid(1, "Block", { 0, 2, 0 }, H.I, { 0.32, 0.32, 0.32 }) } }))
		A.eq(e.hSurf, 0.08, "a cube 0.32 alone: 96 samples at 0.08")
	end)

	-- §17.2 says what the rule cannot see. These read short of the truth, and they are pinned so that a change shows.
	t.it("§4.4 what the reading cannot see: a Ball's band between its samples, a window between the lines", function()
		-- a Ball between 2 plates: a band of ±11° round its waist holds no sample
		local d, gap = 0.5, 0.1
		local ball = H.solid(1, "Ball", { 0, 2, 0 }, H.I, { d, d, d })
		local above = H.solid(2, "Block", { 0, 2 + gap / 2 + 0.15, 0 }, H.I, { 0.8, 0.3, 0.55 })
		local below = H.solid(3, "Block", { 0, 2 - gap / 2 - 0.15, 0 }, H.I, { 0.8, 0.3, 0.55 })
		local bead = H.prepared({ parts = { ball, above, below } })
		A.near(shareOf(bead, 1), 0.192, 0.002, "it shows")
		H.verdictReads(bead, 1, 0, "and reads nothing")
		-- a window on the plate's top, in the cell between 2 lines each way: all 8 lines covered, and 4 parts round it
		local x0, x1, z0, z1 = 0.0625 + 0.26 * 0.0625, 0.0625 + 0.74 * 0.0625, 0.0625 + 0.26 * 0.0625, 0.0625 + 0.74 * 0.0625
		H.verdictReads(underLids({ { -FAR, x0, -FAR, FAR }, { x1, FAR, -FAR, FAR }, { x0, x1, -FAR, z0 }, { x0, x1, z1, FAR } }), 1, 0, "a window")
	end)

	-- What the verifier's mutants asked for, on designs reduced from random ones where they differ: what the build reads is the number.
	t.it("§4.4 a part is near by the sample or by the probe: two rods at MIN_DIM, either clause alone reads otherwise", function()
		local rod1 = H.prepared({ parts = {
			H.part(1, "Blade", "Cylinder", "Iron", { -0.12705730491266404, 1.9100787007808684, -0.18276514195837079 }, { 0, 0, 0, 1 }, { 0.68347896140767261, 0.02, 0.02 }),
			H.part(2, "Blade", "Wedge", "Iron", { -0.24642740437083449, 1.4307990954428178, -0.23203837481203946 }, { -0.1787916095927358, 0.099936245009303107, 0.27585212883609139, 0.93912294737658064 }, { 0.044698467295966104, 1.7593068920518269, 0.4697745784487341 }),
		} })
		H.verdictReads(rod1, 1, ROD1_READS, "the clause on the probe")
		local rod2 = H.prepared({ parts = {
			H.part(1, "Grip", "Cylinder", "Iron", { 0.37687721040564603, 1.7107382666962456, 0.074789842592359879 }, { -0.14342184131965041, 0.53129827277734876, 0.76178878931697336, 0.34180427330164681 }, { 0.7174923553143161, 0.02, 0.02 }),
			H.part(2, "Blade", "CornerWedge", "Iron", { 0.63378416801191217, 1.4289896728143696, 0.040498652912922151 }, { -0.44975806167349219, -0.88754160515964031, -0.056525465837356632, 0.082416362345241093 }, { 0.33639887814060782, 0.20586710478877648, 0.42732540757278908 }),
		} })
		H.verdictReads(rod2, 1, ROD2_READS, "the clause on the sample")
	end)

	-- "one part hides all five": on a Cylinder's side a part can hide 4 corners and not the centre, the curve bulging out of it.
	t.it("§4.4 a part that hides a curved patch's 4 corners and not its centre does not hide it all", function()
		local list = H.prepared({ parts = {
			H.part(1, "Grip", "Block", "Iron", { -0.055506200874210987, 3.6885043828650814, 0.0032231362405770667 }, { -0.78887291299179196, 0.21492199273779988, -0.55961621251415083, 0.13534311536526142 }, { 0.10003531135426108, 0.92919141374690672, 0.02 }),
			H.part(2, "Blade", "Cylinder", "Iron", { -0.038807575251856075, 3.7179023346320275, -0.039105003467455907 }, { 0, 0, 0, 1 }, { 0.16679639678914099, 0.041938998214900491, 0.041938998214900491 }),
			H.part(3, "Pommel", "Block", "Iron", { -0.0029138063657900837, 3.7294401099057852, -0.060554360296211057 }, { 0, 0, 0, 1 }, { 0.20734714446589347, 0.83396020497893908, 0.082835659161210065 }),
		} })
		H.verdictReads(list, 2, BULGE_READS, "the build's reading")
	end)

	t.it("§4.3 every triangular face has the verdict's minimum on both edges, the measure's grid stays the prototype's", function()
		local wedge = H.prepare(H.solid(1, "Wedge", { 0, 2, 0 }, H.I, { 0.3, 0.3, 0.3 }))
		local corner = H.prepare(H.solid(1, "CornerWedge", { 0, 2, 0 }, H.I, { 0.3, 0.3, 0.3 }))
		A.eq(Sampling.surfaceSamples(wedge, 10, nil, Geo.VERDICT_TRIANGLE_CELLS).n, 3 + 2 * 3, "a Wedge: 3 rectangles, 2 triangles of 3")
		A.eq(Sampling.surfaceSamples(corner, 10, nil, Geo.VERDICT_TRIANGLE_CELLS).n, 1 + 4 * 3, "a CornerWedge: 1 rectangle, 4 triangles of 3")
		A.eq(Sampling.surfaceSamples(wedge, 10).n, 3 + 2, "the measure's")
		A.eq(Sampling.surfaceSamples(corner, 10).n, 1 + 4, "the measure's")
	end)

	-- §3.8's image of a CornerWedge swaps its slopes: on the verdict's grid their samples stand at mirror images, so that a part reads
	-- the same on either side of a design. The measure keeps the prototype's samples.
	t.it("§4.3 a CornerWedge's verdict grid is its mirror image's, sample for sample", function()
		local part = H.solid(1, "CornerWedge", { 0.3, 2, 0.1 }, H.axisAngle(1, 2, 3, 40), { 0.3, 0.5, 0.2 })
		for _, plane in ipairs({ "X", "Z" } :: { any }) do
			local image = Mirror.reflect(part, plane)
			local a = Sampling.surfaceSamples(H.prepare(part), 0.16, nil, Geo.VERDICT_TRIANGLE_CELLS)
			local b = Sampling.surfaceSamples(H.prepare(image), 0.16, nil, Geo.VERDICT_TRIANGLE_CELLS)
			A.eq(a.n, b.n)
			local axis = if plane == "X" then 1 else 3
			for k = 1, a.n do
				local mx, my, mz = a.x[k], a.y[k], a.z[k]
				if axis == 1 then
					mx = -mx
				else
					mz = -mz
				end
				local found = false
				for l = 1, b.n do
					if math.abs(b.x[l] - mx) < 1e-9 and math.abs(b.y[l] - my) < 1e-9 and math.abs(b.z[l] - mz) < 1e-9 then
						A.near(b.w[l], a.w[k], 1e-12, "its weight")
						found = true
					end
				end
				A.truthy(found, plane .. ": sample " .. k .. " has its image")
			end
		end
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

	-- A lid over the top direction's patch, its edge x + z = 0.055 past the corner (+, +), a post over that corner: all five points
	-- hidden, by 2 parts, and the sub-point at (+0.75, +0.75) between them. Its 1/16 is the patch's reading.
	t.it("§4.4 on a Cylinder's side the one part must hide all 4 corners too: a lid with a corner off and a post over it", function()
		local r, L = 0.1, 0.5
		local rod = H.solid(1, "Cylinder", { 0, 0, 0 }, H.I, { L, 2 * r, 2 * r })
		local c, D = 0.055, 1
		local n = math.sqrt(0.5)
		local dist = c * n - D
		local lid = H.solid(2, "Block", { n * dist, r + 0.05, n * dist }, H.axisAngle(0, 1, 0, -45), { 2 * D, 0.1, 3 })
		local post = H.solid(3, "Block", { 0.049, r + 0.5, 0.0358 }, H.I, { 0.012, 1, 0.02 })
		A.truthy(H.prepare(post).volume >= Geo.MIN_PART_VOLUME, "a post that hides")
		H.verdictReads(H.prepared({ parts = { rod, lid, post } }), 1, POST_READS, "what the build reads")
	end)

	t.it("§4.4 a strip on a Cylinder's side reads VERDICT_STRIP_CENTRE through a direction, VERDICT_STRIP_RIM by its corners", function()
		-- 8 directions × 5 rows, the slit in the plane z = 0 at the top and the bottom: 2 directions, their sub-points ±5.6° off it
		local through, patch = inSlit(0, 0.01)
		H.verdictReads(through, 1, 2 * 5 * patch * Geo.VERDICT_STRIP_CENTRE, "2 directions, 5 rows")
		-- spun 22.5°, the slit falls between 2 directions, within the corners' reach of each and short of their sub-points
		local rim = inSlit(22.5, 0.01)
		H.verdictReads(rim, 1, 2 * 2 * 5 * patch * Geo.VERDICT_STRIP_RIM, "4 directions, 5 rows")
	end)

	t.it("§4.4 a Cylinder's side has the same test: a narrow arc between its directions shows", function()
		-- 0.5 long, diameter 0.2, spacing 0.1: 8 directions × 5 rows. Spun 22.5° so that no direction points up, sunk in a host
		-- so that ±10° of its top shows, end walls over its caps: the 2 patches beside the arc read their sub-points at ±5.6°, 4 of 16
		local r, L = 0.1, 0.5
		local spun = H.solid(1, "Cylinder", { 0, 0, 0 }, H.axisAngle(1, 0, 0, 22.5), { L, 2 * r, 2 * r })
		local host = H.solid(2, "Block", { 0, r * math.cos(math.rad(10)) - 2, 0 }, H.I, { 4, 4, 4 })
		local wall1 = H.solid(3, "Block", { L / 2 + 1, 0, 0 }, H.I, { 2, 4, 4 })
		local wall2 = H.solid(4, "Block", { -L / 2 - 1, 0, 0 }, H.I, { 2, 4, 4 })
		local list = H.prepared({ parts = { spun, host, wall1, wall2 } })
		local side, area = 2 * math.pi * r * L, 2 * math.pi * r * L + 2 * math.pi * r * r
		H.verdictReads(list, 1, 5 * 2 * (side / 40 * 4 / 16) / area, "the arc")
		A.truthy(keptOf(list, 1), "reads 5.21 %, shows 4.63 %: kept, on no direction's centre")
	end)

	t.it("§4.4 a Cylinder's sub-points are back on the surface: a lid over its top reads as the curve does", function()
		-- not spun, under a lid at y = 0.109: a point's probe rises to 0.112 · cos(angle from the top), so the top direction's
		-- patch is hidden at its centre and its sub-points at ±5.6° and shows at ±16.9°, 8 of 16. On the tangent plane all of them
		-- would be hidden. The other 7 directions show whole, and the caps
		local r, L = 0.1, 0.5
		local list = H.prepared({ parts = { H.solid(1, "Cylinder", { 0, 0, 0 }, H.I, { L, 2 * r, 2 * r }), H.solid(2, "Block", { 0, 0.109 + 1, 0 }, H.I, { 4, 2, 4 }) } })
		local side, caps = 2 * math.pi * r * L, 2 * math.pi * r * r
		H.verdictReads(list, 1, (5 * 7.5 * side / 40 + caps) / (side + caps), "7.5 of 8 directions, 5 rows")
		-- each with its own normal: the probe at ±16.4° rises to 0.112 · cos(16.4°) = 0.1074, on the top direction's normal it would
		-- reach 0.1 · cos(16.4°) + 0.012 = 0.1079, in a lid at 0.1077
		local own = H.prepared({ parts = { H.solid(1, "Cylinder", { 0, 0, 0 }, H.I, { L, 2 * r, 2 * r }), H.solid(2, "Block", { 0, 0.1077 + 1, 0 }, H.I, { 4, 2, 4 }) } })
		H.verdictReads(own, 1, (5 * 7.5 * side / 40 + caps) / (side + caps), "the probes follow the curve")
	end)

	t.it("§4.4 a patch's points off the part's own surface read nothing: a near copy of a wedge is Enclosed", function()
		-- patches on a triangle spill over its rim, past the part around it too. Those points are nobody's surface: no strip
		for _, shape in ipairs({ "Wedge", "CornerWedge" }) do
			local host = H.solid(1, shape, { 0, 2, 0 }, H.axisAngle(1, 2, 3, 40), { 0.4, 0.5, 0.3 })
			local list = H.prepared({ parts = { host, shrunk(host, 0.99, 2, "Blade") } })
			H.verdictReads(list, 2, 0, shape)
		end
	end)

	t.it("§4.4 a thin CornerWedge's tip is seen: triangles have VERDICT_TRIANGLE_CELLS cells per edge", function()
		-- 0.1 × 1 × 0.1, apex up, sunk to y = 0.05: its four triangles show the top 0.45 of their height, 19.3 % of its surface. With
		-- 1 cell on the short edge every sample stands below the host's top
		local list = H.prepared({ parts = { H.solid(1, "CornerWedge", { 0, 0, 0 }, H.I, { 0.1, 1, 0.1 }), H.solid(2, "Block", { 0, 0.05 - 2, 0 }, H.I, { 4, 4, 4 }) } })
		A.near(shareOf(list, 1), 0.45 * 0.45 * (2 * 0.05 + 2 * 0.1 * math.sqrt(1 + 0.01) / 2) / list[1].area, 0.002, "by the areas")
		A.truthy(keptOf(list, 1), "kept")
		A.falsy(H.plantedSampling({ VERDICT_TRIANGLE_CELLS = 1 }).exposure(list).kept[1], "with 1 cell per edge it reads nothing")
	end)

	t.it("§4.4 a Ball has VERDICT_BALL_NF cells whatever its radius, and its largest sample weighs under 2 %", function()
		-- the weights of a cube-face grid of 4 × 4: the 4 cells nearest a face's centre are the largest
		local total, largest = 0, 0
		for i = 0, Geo.VERDICT_BALL_NF - 1 do
			for j = 0, Geo.VERDICT_BALL_NF - 1 do
				local a, b = -1 + (i + 0.5) * 2 / Geo.VERDICT_BALL_NF, -1 + (j + 0.5) * 2 / Geo.VERDICT_BALL_NF
				local s = 1 + a * a + b * b
				local weight = 1 / (math.sqrt(s) * s)
				total += 6 * weight
				largest = math.max(largest, weight)
			end
		end
		local biggest = largest / total
		A.truthy(biggest < Geo.ENCLOSED_EXPOSED_MAX, "a lone sample reads " .. biggest)
		-- (0.25, 1, 0.25) turned to +Y: that sample alone stands above a plane at 0.95 r
		local n = math.sqrt(1.125)
		local turn = H.axisAngle(-0.25 / n, 0, 0.25 / n, math.deg(math.acos(1 / n)))
		for _, d in ipairs({ 0.08, 0.1, 0.3, 0.8, 1.6 }) do
			local r = d / 2
			-- a plane at 0.85 r: the 4 cells around the top, which show a cap of 7.5 %
			local cap = H.prepared({ parts = { H.solid(1, "Ball", { 0, 0, 0 }, H.I, { d, d, d }), H.solid(2, "Block", { 0, 0.85 * r - 2, 0 }, H.I, { 4, 4, 4 }) } })
			H.verdictReads(cap, 1, 4 * biggest, "d " .. d .. ": a cap")
			A.truthy(keptOf(cap, 1), "reads 6.57 %, shows 7.5 %: kept, d " .. d)
			local lone = H.prepared({ parts = { H.solid(1, "Ball", { 0, 0, 0 }, turn, { d, d, d }), H.solid(2, "Block", { 0, 0.95 * r - 2, 0 }, H.I, { 4, 4, 4 }) } })
			H.verdictReads(lone, 1, biggest, "d " .. d .. ": a lone sample")
			A.falsy(keptOf(lone, 1), "no sample alone keeps a ball, d " .. d)
		end
		-- and no patch: half a sample's cell above the plane counts for all of it, or for nothing
		local below = H.prepared({ parts = { H.solid(1, "Ball", { 0, 0, 0 }, H.I, { 0.3, 0.3, 0.3 }), H.solid(2, "Block", { 0, 0.15 * 0.96 - 2, 0 }, H.I, { 4, 4, 4 }) } })
		H.verdictReads(below, 1, 0, "above every sample: reads nothing, shows 2 %")
	end)

	t.it("§4.4 Dust hides nothing: a speck over a strip leaves what the verdict reads", function()
		-- the ring of the strip case, a speck over the strip of the +X side's two middle patches: its volume is under the Dust floor
		-- by a hair, and were it a hider, 2 patches of the 12 would read nothing, and the plate 1.85 %
		local s = 0.008
		local speck = H.part(9, "Blade", "Block", "Iron", { 0.25 - 0.01 + 0.002, 0.0175, 0 }, H.I, { 0.02, 0.035, 0.26 })
		A.truthy(H.prepare(speck).volume < Geo.MIN_PART_VOLUME, "it is Dust")
		local parts = underLids({ { -0.25 + s, 0.25 - s, -0.25 + s, 0.25 - s } })
		table.insert(parts, Shapes.prepare(speck :: any, #parts + 1))
		H.verdictReads(parts, 1, 12 * (PATCH * (s - EPS) / PATCH_WIDTH) / PLATE_AREA, "the 12 patches, speck or no speck")
		A.truthy(keptOf(parts, 1), "kept")
		A.deepEq(Sampling.exposure(parts).cleaned, { { partId = 9, reason = "Dust" } })
	end)

	t.it("§4.4 exact copies hide nothing: a stack of a lid's copies leaves what the verdict reads, and they have no verdict", function()
		local s = 0.008
		local lid = { -0.25 + s, 0.25 - s, -0.25 + s, 0.25 - s }
		local parts = underLids({ lid, lid, lid, lid })
		H.verdictReads(parts, 1, 12 * (PATCH * (s - EPS) / PATCH_WIDTH) / PLATE_AREA, "the 12 patches, copies or no copies")
		A.deepEq(Sampling.exposure(parts).cleaned, { { partId = WALLS + 2, reason = "Enclosed" }, { partId = WALLS + 3, reason = "Enclosed" }, { partId = WALLS + 4, reason = "Enclosed" } })
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
end)
