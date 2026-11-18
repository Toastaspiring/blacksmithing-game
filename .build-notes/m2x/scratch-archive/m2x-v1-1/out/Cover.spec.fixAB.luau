--!strict
-- Physics/Cover (SPEC §4.4, §4.9, E-S2.12): the Enclosed verdict's reading, exact on a polyhedral model of each part.
--   (a) exact on its model: against CoverBrute's 3D clip and slab union, every part within EXACT of its area, unless a tie (a
--       face on the hide test's boundary to rounding) brackets it: then each facet lies between the brute force with every
--       piece grown and shrunk by TIE
--   (b) the closed forms E-S2.12 quotes, on the plate under lids
--   (c) the attack designs with their truth (CoverAttacks): the truth's verdict, within the model's band of its share
--   (d) what it does not depend on: the order of the parts, a mirror image, an exact copy first or last, Dust
--   (e) the model: frames the world fixes, mirror images, the brute force's own construction, the sag
--   (f) the cap: units in any order, designs past it TooComplex at once, the real designs at least 2 × under it

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Blueprints = require("../fixtures/Blueprints")
local H = require("./PhysicsHelpers")
local Brute = require("./CoverBrute")
local Attacks = require("./CoverAttacks")
local Plausible = require("./PlausibleDesigns")
local Balance = require("../../src/shared/Definitions/Balance")
local Mirror = require("../../src/shared/Blueprint/Mirror")
local Quat = require("../../src/shared/Blueprint/Quat")
local Analyze = require("../../src/shared/Physics/Analyze")
local Cover = require("../../src/shared/Physics/Cover")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

-- Through a cast, as in Reference.spec: reference data, not game code.
local Fixtures: any = (require :: any)("../../docs/spec/prototypes/S2/v2/fixtures")
local Worst: any = (require :: any)("../../docs/spec/prototypes/S2/cover/worst_designs")

type Rng = TestRng.TestRng
type Prepared = Shapes.Prepared

local Geo = Balance.Geometry
local EXACT = 1e-9 -- a part's reading against the brute force, in share of its area, outside a tie (E-S2.12: 2.6e-13 at worst)
local TIE = 1e-11 -- the bracket: every moved half-space out and in by this much
local BAND_FLAT, BAND_ROUND = 0.003, 0.03 -- a reading against the truth: the oracle's lattice; that and the round model's band

local function prepared(parts: { any }): { Prepared }
	local out: { Prepared } = table.create(#parts)
	for i, p in ipairs(parts) do
		out[i] = Shapes.prepare(p, i)
	end
	return out
end

local function models(parts: { Prepared }): { [number]: Cover.Model }
	local out: { [number]: Cover.Model } = {}
	local _, order = Sampling.ranked(parts)
	for r = 1, #order do
		local q = order[r]
		if not (r > 1 and Shapes.sameSolid(q, order[r - 1])) and q.volume >= Geo.MIN_PART_VOLUME then
			out[q.index] = Cover.model(q)
		end
	end
	return out
end

-- Every hider's reading, whole: its shown area, against its hiders as Sampling hands them over.
local function readings(parts: { Prepared }): { [number]: number }
	local m = models(parts)
	local out: { [number]: number } = {}
	for i = 1, #parts do
		if m[i] then
			local index, higher = H.hidersOf(parts, i)
			local hm: { Cover.Model } = {}
			for k, j in ipairs(index) do
				hm[k] = m[j]
			end
			out[i] = (Cover.shown(m[i], hm, higher, math.huge, math.huge))
		end
	end
	return out
end

-- Model m with facet f alone, as a reading's target.
local function oneFacet(m: Cover.Model, f: number): Cover.Model
	local b = 6 * (f - 1)
	return {
		part = m.part, round = m.round, n = 1, poly = { m.poly[f] }, nx = { m.nx[f] }, ny = { m.ny[f] }, nz = { m.nz[f] },
		area = { m.area[f] }, box = { m.box[b + 1], m.box[b + 2], m.box[b + 3], m.box[b + 4], m.box[b + 5], m.box[b + 6] },
		total = m.area[f], np = 0, planes = {}, sag = { if m.round then m.sag[f] else 0 }, inner = 0, work = 0,
	}
end

-- (a): every hider of a design against the brute force on Cover's own model. Returns the parts checked, those a tie settled,
-- and those past the brute force's edge limit.
local function exactOn(parts: { Prepared }, what: string): (number, number, number)
	local m = models(parts)
	local b: { [number]: Brute.Model } = {}
	for i = 1, #parts do
		if m[i] then
			b[i] = Brute.fromCover(m[i])
		end
	end
	local checked, ties, past = 0, 0, 0
	for i = 1, #parts do
		if m[i] then
			local index, higher = H.hidersOf(parts, i)
			local hm: { Cover.Model }, bh: { Brute.Model } = {}, {}
			for k, j in ipairs(index) do
				hm[k], bh[k] = m[j], b[j]
			end
			local brute: number? = 0
			for f = 1, m[i].n do
				local s = Brute.facetShown(b[i], f, bh, higher)
				if s == nil then
					brute = nil
					break
				end
				brute = (brute :: number) + s
			end
			if brute == nil then
				past += 1
			else
				checked += 1
				local shown = Cover.shown(m[i], hm, higher, math.huge, math.huge)
				if math.abs(shown - brute) > EXACT * m[i].total then
					for f = 1, m[i].n do
						local lo = Brute.facetShown(b[i], f, bh, higher, TIE)
						local hi = Brute.facetShown(b[i], f, bh, higher, -TIE)
						if lo and hi then
							local c = Cover.shown(oneFacet(m[i], f), hm, higher, math.huge, math.huge)
							local tol = 1e-11 * m[i].area[f] + 1e-15
							A.truthy(c >= lo - tol and c <= hi + tol, what .. ", part " .. i .. ", facet " .. f .. ": " .. c .. " outside [" .. lo .. ", " .. hi .. "]")
						end
					end
					ties += 1
				end
			end
		end
	end
	return checked, ties, past
end

-- A tangle: n overlapping parts of every shape, faces against faces at offsets of 0, EPS_GEOM and its multiples, HIDE_OFFSET and
-- its neighbours, hairlines from 1e-9 to 1e-5, exact copies, round copies turned about their own symmetry, Dust, thin sheets.
-- No sword: the reading must be exact on any set of parts (the judge's tangles.luau, on TestRng).
local SHAPES = { "Block", "Block", "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
local OFFSETS = { 0, 0, 0, 1e-7, -1e-7, 2e-7, -2e-7, 1e-8, -1e-8, 1.5e-8, -1.5e-8, 3e-8, -3e-8, 1e-9, -1e-9, 1e-6, -1e-6, 1e-5, -1e-5,
	0.012, -0.012, 0.0119999, 0.0120001, 0.012 + 1e-7, 0.012 - 1e-7, 0.001, -0.001, 0.05 }
local R = 0.70710678118654757
local AXIS_ROTS = { { 0, 0, 0, 1 }, { 0, 0, R, R }, { 0, R, 0, R }, { R, 0, 0, R }, { 0, 0, 1, 0 }, { 0.5, 0.5, 0.5, 0.5 } }

local function sized(shape: string, s: { number }): { number }
	if shape == "Ball" then
		local m = math.min(s[1], s[2], s[3])
		return { m, m, m }
	elseif shape == "Cylinder" then
		local m = math.min(s[2], s[3])
		return { s[1], m, m }
	end
	return s
end

local function tangle(rng: Rng): { any }
	local parts: { any } = {}
	local function add(shape: string, pos: { number }, rot: { number }, size: { number })
		table.insert(parts, H.solid(#parts + 1, shape, pos, rot, sized(shape, size)))
	end
	local function rsize(): { number }
		return { rng:range(0.02, 0.82), rng:range(0.02, 0.82), rng:range(0.02, 0.82) }
	end
	for k = 1, rng:int(3, 10) do
		local mode = rng:int(1, 10)
		local shape = rng:pick(SHAPES)
		if k == 1 or mode <= 3 then
			local rot = if rng:float() < 0.6 then rng:pick(AXIS_ROTS) else H.randomQuat(rng)
			add(shape, { rng:range(-0.3, 0.3), rng:range(-0.3, 0.3), rng:range(-0.3, 0.3) }, rot, rsize())
		elseif mode <= 7 then -- a face against a face of an earlier part, the same turn, at an offset of the list
			local host = rng:pick(parts)
			local axis = rng:int(1, 3)
			local side = if rng:float() < 0.5 then -1 else 1
			local size = sized(shape, rsize())
			local off = rng:pick(OFFSETS)
			local d = side * (host.size[axis] / 2 + size[axis] / 2 + off)
			if rng:float() < 0.25 then
				d = side * (host.size[axis] / 2 - size[axis] / 2 + off)
			end
			local l = { 0, 0, 0 }
			l[axis] = d
			for a = 1, 3 do
				if a ~= axis then
					l[a] = if rng:float() < 0.3 then (if rng:float() < 0.5 then -1 else 1) * (host.size[a] / 2 - size[a] / 2) + rng:pick(OFFSETS)
						else (rng:float() - 0.5) * host.size[a]
				end
			end
			local w = Quat.rotate(host.rot, l)
			add(shape, { host.pos[1] + w[1], host.pos[2] + w[2], host.pos[3] + w[3] }, table.clone(host.rot), size)
		elseif mode == 8 then -- an exact copy, a round copy turned about its symmetry, or a copy nudged
			local host = rng:pick(parts)
			local rot: { number }, pos: { number } = table.clone(host.rot), table.clone(host.pos)
			local r = rng:float()
			if r < 0.3 and (host.shape == "Cylinder" or host.shape == "Ball") then
				rot = Quat.hemisphere(Quat.normalize(Quat.mul(host.rot, H.axisAngle(1, 0, 0, rng:range(0, 90)))))
			elseif r < 0.6 then
				local a = rng:int(1, 3)
				pos[a] += rng:pick(OFFSETS)
			end
			table.insert(parts, H.solid(#parts + 1, host.shape, pos, rot, table.clone(host.size)))
		elseif mode == 9 then -- a Dust speck on a face
			local host = rng:pick(parts)
			add("Block", { host.pos[1] + host.size[1] / 2, host.pos[2], host.pos[3] }, H.I, { 0.05, 0.05, 0.05 })
		else -- a thin sheet over a face
			local host = rng:pick(parts)
			local axis = rng:int(1, 3)
			local size = { host.size[1] * rng:range(0.3, 1.3), host.size[2] * rng:range(0.3, 1.3), host.size[3] * rng:range(0.3, 1.3) }
			size[axis] = math.max(rng:pick({ 0.02, 0.013, 0.012, 0.011, 0.03 }), 0.02)
			local l = { 0, 0, 0 }
			l[axis] = host.size[axis] / 2 + size[axis] / 2 + rng:pick(OFFSETS)
			local w = Quat.rotate(host.rot, l)
			add("Block", { host.pos[1] + w[1], host.pos[2] + w[2], host.pos[3] + w[3] }, table.clone(host.rot), size)
		end
	end
	return parts
end

local function attackParts(d: any): { Prepared }
	return prepared(d.parts)
end

local function shuffled(rng: Rng, list: { any }): { any }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:int(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- A part's class among exact copies of one another: the parts whose solid is its.
local function copiesOf(parts: { any }, i: number): number
	local P = Shapes.prepare(parts[i], 1)
	local n = 0
	for j = 1, #parts do
		if Shapes.sameSolid(P, Shapes.prepare(parts[j], 2)) then
			n += 1
		end
	end
	return n
end

-- (a)'s designs: the F fixtures, C09 and the attack designs (the calibration and regression fixtures, P2–P5 and more tangles: slow).
local function exactOnDesigns(cores: { any }, what: string)
	local checked = 0
	for _, core in ipairs(cores) do
		checked += (exactOn(prepared(core.parts), what .. " " .. tostring(core.name)))
	end
	A.truthy(checked > 0, what .. ": parts checked")
end

local function exactOnTangles(count: number)
	local checked, ties, past = 0, 0, 0
	Prop.check(count, function(rng: Rng): any
		return tangle(rng)
	end, function(parts: any)
		local c, t, p = exactOn(prepared(parts), "a tangle")
		checked, ties, past = checked + c, ties + t, past + p
	end)
	A.truthy(checked > 4 * count, "parts checked: " .. checked .. " (ties " .. ties .. ", past the edge limit " .. past .. ")")
	A.truthy(past <= checked / 20, "most parts within the brute force's edge limit: " .. past)
end

return Test.suite("Physics/Cover", function(t)
	-- ── (a) exact on its model ───────────────────────────────────────────────────────────────────────────────────

	t.it("(a) exact on its model, against a brute force: the F fixtures, C09 and the attack designs", function()
		local cores: { any } = {}
		for _, id in ipairs(Blueprints.order) do
			table.insert(cores, Blueprints.core(id))
		end
		table.insert(cores, H.ornate())
		exactOnDesigns(cores, "fixture")
		exactOnDesigns(Attacks, "attack")
	end)

	t.it("(a) exact on its model, against a brute force: 40 tangles of overlapping, near-touching parts of every shape", function()
		exactOnTangles(40)
	end)

	t.slow("(a) exact on its model: the calibration and regression fixtures, P2–P5, and 600 tangles", function()
		local cores: { any } = {}
		for _, set in ipairs({ Fixtures.calibration(), Fixtures.regression(), Fixtures.perf() }) do
			for _, b in ipairs(set) do
				if b.parts and string.sub(b.name, 1, 2) ~= "P1" then
					table.insert(cores, b)
				end
			end
		end
		exactOnDesigns(cores, "fixture")
		exactOnTangles(600)
	end)

	-- ── (b) the closed forms ─────────────────────────────────────────────────────────────────────────────────────

	t.it("(b) what shows of the plate under lids, to the 6 decimals E-S2.12 quotes, kept or cleaned", function()
		local function pct(lids: { { number } }): number
			return 100 * H.reads(H.underLids(lids), 1)
		end
		local function kept(lids: { { number } }): boolean
			return Sampling.exposure(H.underLids(lids)).kept[1]
		end
		local s, FAR = 0.008, 0.5
		local ring = { { -0.25 + s, 0.25 - s, -0.25 + s, 0.25 - s } }
		A.near(pct(ring), 2.915520, 5e-7, "a strip 0.008 all round")
		A.truthy(kept(ring), "kept")
		local three = { { -0.25 + s, 0.25 - s, -FAR, 0.25 - s } }
		A.near(pct(three), 2.198491, 5e-7, "the strip on 3 sides")
		A.truthy(kept(three), "kept")
		A.near(pct({ { -0.248, 0.248, -0.248, 0.248 } }), 0.737741, 5e-7, "a hair 0.002 all round")
		A.near(pct({ { -0.249, 0.249, -0.249, 0.249 } }), 0.369593, 5e-7, "a hair 0.001 all round")
		for _, def in ipairs({ { 0.03, 2.777759 }, { 0.00001, 0.000907 } }) do
			local g = def[1]
			A.near(pct({ { -FAR, 0.0625 - g / 2, -FAR, FAR }, { 0.0625 + g / 2, FAR, -FAR, FAR } }), def[2], 5e-7, "a slit " .. g)
		end
		local x0, x1 = 0.0625 + 0.26 * 0.0625, 0.0625 + 0.74 * 0.0625
		A.near(pct({ { -FAR, x0, -FAR, FAR }, { x1, FAR, -FAR, FAR }, { x0, x1, -FAR, x0 }, { x0, x1, x1, FAR } }), 0.166664, 5e-7, "a window")
		-- the laminated core of Verdict.spec: its proud rims, 5.540 %
		local parts = prepared({
			H.part(1, "Pommel", "Ball", "Iron", { 0, 0.3, 0 }, H.I, { 0.3, 0.3, 0.3 }),
			H.part(2, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, H.Z90, { 0.9, 0.16, 0.16 }),
			H.part(3, "Guard", "Block", "Iron", { 0, 1.4, 0 }, H.I, { 1.1, 0.16, 0.3 }),
			H.part(4, "Blade", "Block", "Iron", { 0, 2.45, 0.0225 }, H.I, { 1, 2, 0.025 }),
			H.part(5, "Blade", "Block", "Iron", { 0, 2.45, -0.0225 }, H.I, { 1, 2, 0.025 }),
			H.part(6, "Blade", "Block", "Iron", { 0, 3.47, 0 }, H.I, { 1, 0.04, 0.07 }),
			H.part(7, "Blade", "Block", "Steel", { 0, 2.45, 0 }, H.I, { 1.04, 2, 0.02 }),
		})
		A.near(100 * H.reads(parts, 7), 5.540, 5e-4, "the laminated core")
	end)

	-- ── (c) the attack designs ───────────────────────────────────────────────────────────────────────────────────

	t.it("(c) the attack designs read their truth: the truth's verdict, the share within the model's band", function()
		A.truthy(#Attacks >= 15, "designs: " .. #Attacks)
		for _, d in ipairs(Attacks) do
			local parts = attackParts(d)
			local target = parts[d.target]
			local band = if target.code == Shapes.CYLINDER or target.code == Shapes.BALL then BAND_ROUND else BAND_FLAT
			A.eq(Sampling.exposure(parts).kept[d.target], d.kept, d.name .. ": the truth's verdict")
			A.near(H.reads(parts, d.target), d.truth, band, d.name .. ": the share")
		end
	end)

	-- T-PHY-09's copies: a Cylinder spun about its axis, a Ball turned any way, are their originals to the model
	t.it("(c) a round copy spun or turned about its own symmetry is hidden by its original, which shows whole", function()
		local cylinder = H.solid(1, "Cylinder", { 0, 2, 0 }, H.Z90, { 0.6, 0.24, 0.24 })
		local spun = H.solid(2, "Cylinder", { 0, 2, 0 }, Quat.hemisphere(Quat.mul(H.Z90, H.axisAngle(1, 0, 0, 37))), { 0.6, 0.24, 0.24 })
		local ball = H.solid(1, "Ball", { 0, 2, 0 }, H.I, { 0.3, 0.3, 0.3 })
		local turned = H.solid(2, "Ball", { 0, 2, 0 }, H.axisAngle(1, 2, 3, 77), { 0.3, 0.3, 0.3 })
		for _, pair in ipairs({ { cylinder, spun }, { ball, turned }, { spun, cylinder }, { turned, ball } }) do
			local parts = prepared(pair)
			local first = H.reads(parts, 1)
			local second = H.reads(parts, 2)
			A.near(math.min(first, second), 0, 1e-12, pair[1].shape .. ": one of the 2 reads nothing")
			A.near(math.max(first, second), 1, 1e-12, pair[1].shape .. ": the other its whole model")
			A.eq(#Sampling.exposure(parts).cleaned, 1, pair[1].shape .. ": one cleaned")
		end
	end)

	-- A Ball (r 0.2) in 6 walls 0.0028 off it and 12 edge blocks: its facets probe HIDE_OFFSET + their sag, past a facet box
	-- grown by HIDE_OFFSET alone, so a box test that short would lose the walls and read 2.345 %; the hide test reads 0.447 %
	-- (the truth 0.502 %): Enclosed.
	t.it("(c) a Ball sealed in walls its own probe reaches: what the hide test reads, Enclosed", function()
		local r, g, b, E = 0.2, 0.002769, 0.051018, 0.26
		local parts: { any } = { H.solid(1, "Ball", { 0, 2.5, 0 }, H.I, { 2 * r, 2 * r, 2 * r }) }
		for a = 1, 3 do
			for _, s in ipairs({ -1, 1 }) do
				local pos, size = { 0, 2.5, 0 }, { 2 * r + 0.1, 2 * r + 0.1, 2 * r + 0.1 }
				pos[a] += s * (r + g + 0.01)
				size[a] = 0.02
				table.insert(parts, H.solid(#parts + 1, "Block", pos, H.I, size))
			end
		end
		for a = 1, 3 do
			for c = a + 1, 3 do
				for _, sa in ipairs({ -1, 1 }) do
					for _, sc in ipairs({ -1, 1 }) do
						local lo, hi = { -E, -E, -E }, { E, E, E }
						if sa > 0 then lo[a] = b else hi[a] = -b end
						if sc > 0 then lo[c] = b else hi[c] = -b end
						local pos, size = { 0, 2.5, 0 }, { 0, 0, 0 }
						for k = 1, 3 do
							pos[k] += (lo[k] + hi[k]) / 2
							size[k] = hi[k] - lo[k]
						end
						table.insert(parts, H.solid(#parts + 1, "Block", pos, H.I, size))
					end
				end
			end
		end
		local P = prepared(parts)
		A.near(100 * H.reads(P, 1), 0.447, 5e-4, "the caged Ball reads its hide test")
		A.falsy(Sampling.exposure(P).kept[1], "Enclosed")
	end)

	-- The same solid in another frame (a Block turned 180° about Y, or its size permuted with a quarter turn) is no exact copy
	-- by its bits, but it is one by its solid: in the Guard it must not take F3's blade out of the Blade (§17.2, O8).
	t.it("(c) the blade of F3 again in the Guard, turned or described another way: the blade stays kept", function()
		local base = Blueprints.core("F3")
		for _, v in ipairs({ { { 0, 1, 0, 0 }, { 0.07, 3.4, 0.035 } }, { { 1, 0, 0, 0 }, { 0.07, 3.4, 0.035 } }, { H.axisAngle(0, 1, 0, 90), { 0.035, 3.4, 0.07 } } }) do
			local parts: { any } = {}
			for i, p in ipairs(base.parts) do
				parts[i] = p
			end
			local blade = base.parts[6]
			table.insert(parts, { id = 8, slot = "Guard", shape = "Block", material = blade.material, pos = blade.pos, rot = v[1], size = v[2] })
			local e = Sampling.exposure(prepared(parts))
			A.truthy(e.kept[6], "the blade kept")
			A.falsy(e.kept[8], "its copy in the Guard cleaned")
		end
	end)

	-- ── (d) what it does not depend on ───────────────────────────────────────────────────────────────────────────

	-- By part id: any order gives every reading the same bits. Exact copies of one solid compare as a class: which of them the
	-- index keeps is the rank's last key (§4.4).
	local function sameInAnyOrder(rng: Rng, parts: { any }, what: string)
		local base = readings(prepared(parts))
		for _ = 1, 3 do
			local order = shuffled(rng, parts)
			local now = readings(prepared(order))
			for k, p in ipairs(order) do
				local i = table.find(parts, p) :: number
				if copiesOf(parts, i) == 1 then
					A.eq(now[k], base[i], what .. ": part " .. p.id .. "'s reading")
				end
			end
		end
	end

	t.it("(d) any order of the parts: every reading the same bits, tangles and attack designs", function()
		Prop.check(40, function(rng: Rng): any
			return { parts = tangle(rng), seed = rng:u32() }
		end, function(c: any)
			sameInAnyOrder(TestRng.new(c.seed), c.parts, "a tangle")
		end)
		local rng = TestRng.new(Prop.baseSeed)
		for _, d in ipairs(Attacks) do
			sameInAnyOrder(rng, d.parts, d.name)
		end
	end)

	-- The image across the centre plane X or Z: its parts read what the original's do, to rounding, and keep the same verdicts.
	-- True twins (one part the image of another) swap who keeps a face they share: their readings swap, their verdicts too.
	local function mirrored(parts: { any }, plane: any, what: string)
		local images: { any } = {}
		for i, p in ipairs(parts) do
			images[i] = Mirror.reflect(p, plane)
		end
		local P, Q = prepared(parts), prepared(images)
		local a, b = readings(P), readings(Q)
		local ka, kb = Sampling.exposure(P).kept, Sampling.exposure(Q).kept
		for i = 1, #parts do
			local twin = false
			for j = 1, #parts do
				if j ~= i and Shapes.sameSolid(Q[j], P[i]) then
					twin = true
				end
			end
			if not twin then
				A.eq(kb[i], ka[i], what .. " across " .. plane .. ": part " .. i .. "'s verdict")
				if a[i] then
					A.near(b[i] / Q[i].area, a[i] / P[i].area, 1e-9, what .. " across " .. plane .. ": part " .. i .. "'s reading")
				end
			end
		end
	end

	t.it("(d) a mirror image across X or Z reads the original's, part for part: fixtures, C09, attack designs", function()
		for _, plane in ipairs({ "X", "Z" } :: { any }) do
			for _, id in ipairs(Blueprints.order) do
				mirrored(Blueprints.core(id).parts, plane, id)
			end
			mirrored(H.ornate().parts, plane, "C09")
			for _, d in ipairs(Attacks) do
				mirrored(d.parts, plane, d.name)
			end
		end
	end)

	t.it("(d) an exact copy first or last, a Dust speck on a face: every other reading the same bits", function()
		Prop.check(40, function(rng: Rng): any
			local parts = tangle(rng)
			return { parts = parts, pick = rng:int(1, #parts) }
		end, function(c: any)
			local parts = c.parts
			local base = readings(prepared(parts))
			local p = parts[c.pick]
			local copy = table.clone(p)
			copy.id = 99
			local speck = H.solid(98, "Block", { p.pos[1] + p.size[1] / 2, p.pos[2], p.pos[3] }, H.I, { 0.05, 0.05, 0.05 })
			local first, last, dusted = { copy }, {}, {}
			for _, q in ipairs(parts) do
				table.insert(first, q)
				table.insert(last, q)
				table.insert(dusted, q)
			end
			table.insert(last, copy)
			table.insert(dusted, speck)
			local a, b, d = readings(prepared(first)), readings(prepared(last)), readings(prepared(dusted))
			for i = 1, #parts do
				if not Shapes.sameSolid(Shapes.prepare(parts[i], 1), Shapes.prepare(p, 2)) then
					A.eq(a[i + 1], base[i], "a copy first: part " .. i)
					A.eq(b[i], base[i], "a copy last: part " .. i)
				end
				A.eq(d[i], base[i], "a speck: part " .. i)
			end
			A.eq(d[#dusted], nil, "the speck has no reading: Dust")
		end)
	end)

	-- ── (e) the model ────────────────────────────────────────────────────────────────────────────────────────────

	-- Every vertex of a model, sorted, for set comparisons.
	local function vertices(m: Cover.Model): { { number } }
		local out: { { number } } = {}
		for f = 1, m.n do
			local poly = m.poly[f]
			for k = 1, #poly, 3 do
				table.insert(out, { poly[k], poly[k + 1], poly[k + 2] })
			end
		end
		table.sort(out, function(p: { number }, q: { number }): boolean
			for c = 1, 3 do
				if math.abs(p[c] - q[c]) > 1e-9 then
					return p[c] < q[c]
				end
			end
			return false
		end)
		return out
	end
	local function sameSet(a: { { number } }, b: { { number } }, tol: number, what: string)
		A.eq(#a, #b, what .. ": as many vertices")
		for k = 1, #a do
			for c = 1, 3 do
				A.near(a[k][c], b[k][c], tol, what .. ": vertex " .. k)
			end
		end
	end

	t.it("(e) frames the world fixes: a round part spun or turned about its symmetry has its original's model", function()
		local rng = TestRng.new(Prop.baseSeed)
		for _ = 1, 20 do
			local q = H.randomQuat(rng)
			local d = rng:range(0.05, 0.8)
			local cylinder = H.solid(1, "Cylinder", { 0.1, 2, -0.05 }, q, { rng:range(0.1, 2), d, d })
			local spun = table.clone(cylinder)
			spun.rot = Quat.hemisphere(Quat.normalize(Quat.mul(q, H.axisAngle(1, 0, 0, rng:range(-180, 180)))))
			local flipped = table.clone(cylinder)
			flipped.rot = Quat.hemisphere(Quat.normalize(Quat.mul(q, H.axisAngle(0, 0, 1, 180))))
			local base = vertices(Cover.model(H.prepare(cylinder)))
			sameSet(vertices(Cover.model(H.prepare(spun))), base, 1e-15 * (1 + d + cylinder.size[1]) * 4, "a Cylinder spun about its axis")
			sameSet(vertices(Cover.model(H.prepare(flipped))), base, 1e-15 * (1 + d + cylinder.size[1]) * 4, "a Cylinder end for end")
			local ball = H.solid(1, "Ball", { -0.2, 2.5, 0.1 }, H.randomQuat(rng), { d, d, d })
			local turned = table.clone(ball)
			turned.rot = H.randomQuat(rng)
			sameSet(vertices(Cover.model(H.prepare(turned))), vertices(Cover.model(H.prepare(ball))), 0, "a Ball turned any way")
		end
	end)

	t.it("(e) the model of a mirror image is the mirror image of the model, every shape", function()
		local rng = TestRng.new(Prop.baseSeed)
		for _, shape in ipairs({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }) do
			for _ = 1, 8 do
				local size = sized(shape, { rng:range(0.05, 1), rng:range(0.05, 1), rng:range(0.05, 1) })
				local part = H.solid(1, shape, { rng:range(-0.5, 0.5), rng:range(1, 4), rng:range(-0.2, 0.2) }, H.randomQuat(rng), size)
				for _, plane in ipairs({ "X", "Z" } :: { any }) do
					local image = Cover.model(H.prepare(Mirror.reflect(part, plane)))
					local m = Cover.model(H.prepare(part))
					local reflected: { { number } } = {}
					for _, v in ipairs(vertices(m)) do
						table.insert(reflected, if plane == "X" then { -v[1], v[2], v[3] } else { v[1], v[2], -v[3] })
					end
					table.sort(reflected, function(p: { number }, q: { number }): boolean
						for c = 1, 3 do
							if math.abs(p[c] - q[c]) > 1e-9 then
								return p[c] < q[c]
							end
						end
						return false
					end)
					sameSet(vertices(image), reflected, 1e-14, shape .. " across " .. plane)
					A.near(image.total, m.total, 1e-12 * m.total, shape .. " across " .. plane .. ": its area")
				end
			end
		end
	end)

	t.it("(e) the model as §4.4 words it: the brute force's own construction, its half-spaces' sag, a Ball's 128 triangles", function()
		local rng = TestRng.new(Prop.baseSeed)
		for _, shape in ipairs({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }) do
			for _ = 1, 6 do
				local size = sized(shape, { rng:range(0.05, 1), rng:range(0.05, 1), rng:range(0.05, 1) })
				local P = H.prepare(H.solid(1, shape, { rng:range(-0.5, 0.5), rng:range(1, 4), rng:range(-0.2, 0.2) }, H.randomQuat(rng), size))
				local m, b = Cover.model(P), Brute.model(P)
				A.eq(m.n, #b.facets, shape .. ": facets")
				A.eq(m.np, #b.planes, shape .. ": half-spaces")
				A.near(m.total, b.total, 1e-12 * b.total, shape .. ": area")
				local bv: { { number } } = {}
				for _, poly in ipairs(b.facets) do
					for k = 1, #poly, 3 do
						table.insert(bv, { poly[k], poly[k + 1], poly[k + 2] })
					end
				end
				table.sort(bv, function(p: { number }, q: { number }): boolean
					for c = 1, 3 do
						if math.abs(p[c] - q[c]) > 1e-9 then
							return p[c] < q[c]
						end
					end
					return false
				end)
				sameSet(vertices(m), bv, 1e-14, shape .. ": the vertices")
				-- sag: 0 on a polyhedron and a cap; on a round facet the true support past its plane, its probe's lead
				local ms, bs = table.clone(m.sag), table.clone(b.sag)
				table.sort(ms)
				table.sort(bs)
				for i = 1, m.np do
					A.near(ms[i], bs[i], 1e-13, shape .. ": sag " .. i)
					A.truthy(m.sag[i] >= 0, "never negative")
					if not m.round then
						A.eq(m.sag[i], 0, shape .. ": a polyhedron's half-spaces are its faces")
					end
				end
				if shape == "Cylinder" then
					A.truthy(m.sag[33] + m.sag[34] <= 1e-14, "the caps: " .. m.sag[33] + m.sag[34])
					A.truthy(m.sag[1] > 0, "a side")
				elseif shape == "Ball" then
					A.eq(m.n, 8 * Geo.COVER_BALL_GRID * Geo.COVER_BALL_GRID, "128 triangles")
					local largest = 0
					for f = 1, m.n do
						largest = math.max(largest, m.area[f] / m.total)
					end
					A.within(largest, 0.012, 0.0121, "the largest triangle, 1.21 % of the model: none alone keeps a Ball")
					A.within(m.total / (4 * Shapes.PI * P.r * P.r), 0.95, 0.96, "inscribed: 95.1 % of the sphere's area")
				end
			end
		end
	end)

	-- ── (f) the cap ──────────────────────────────────────────────────────────────────────────────────────────────

	local function unitsOf(parts: { Prepared }): (number, boolean)
		local e = Sampling.exposure(parts)
		return e.verdictWork, e.capped
	end

	t.it("(f) the real designs stay at least 2 × under VERDICT_WORK_MAX: F, C and X fixtures, P1–P5", function()
		local heaviest, name = 0, ""
		local function see(parts: { any }, what: string)
			local units, capped = unitsOf(prepared(parts))
			A.falsy(capped, what)
			A.truthy(2 * units <= Geo.VERDICT_WORK_MAX, what .. ": " .. units .. " units")
			if units > heaviest then
				heaviest, name = units, what
			end
		end
		for _, id in ipairs(Blueprints.order) do
			see(Blueprints.core(id).parts, id)
		end
		for _, set in ipairs({ Fixtures.calibration(), Fixtures.regression(), Fixtures.perf() }) do
			for _, b in ipairs(set) do
				if b.parts then
					see(b.parts, b.name)
				elseif b.fixture then
					see(b.fixture.parts, b.fixture.name)
				end
			end
		end
		A.eq(string.sub(name, 1, 2), "P1", "the heaviest is P1")
	end)

	-- Every design of 20 parts or more (1,083; the heaviest, 5 wrap rings over C09, 136,032 units) and every 4th of the rest
	-- (the heaviest of them all 55,968): 9,153 designs in 58 s, where all 33,389 take 191.
	t.slow("(f) the plausible designs stay at least 2 × under VERDICT_WORK_MAX: all of 20 parts or more, every 4th of the rest", function()
		local count, heaviest = 0, 0
		for k, d in ipairs(Plausible.all()) do
			if #d.parts >= 20 or k % 4 == 0 then
				local units = unitsOf(prepared(d.parts))
				heaviest = math.max(heaviest, units)
				count += 1
				A.truthy(2 * units <= Geo.VERDICT_WORK_MAX, d.name .. ": " .. units .. " units")
			end
		end
		A.truthy(count > 9000, "designs: " .. count)
		A.truthy(heaviest > 100000, "the wrap rings over C09 are in the sweep: " .. heaviest)
	end)

	t.it("(f) a design past the cap: no verdict, TooComplex, answered at once; its units in any order", function()
		A.truthy(#Worst.tooComplex >= 6, "designs past the cap: " .. #Worst.tooComplex)
		local rng = TestRng.new(Prop.baseSeed)
		for k, d in ipairs(Worst.tooComplex) do
			if k <= 4 then
				local core: any = { schema = 1, name = "worst", type = "Sword", parts = d.parts }
				-- the best of 3 runs, so that a GC step or another process does not time the design (quiet: 12–26 ms)
				local e: any, ms = nil, math.huge
				for _ = 1, 3 do
					local parts = prepared(d.parts)
					local t0 = os.clock()
					e = Sampling.exposure(parts)
					ms = math.min(ms, (os.clock() - t0) * 1000)
				end
				A.truthy(e.capped, d.name .. ": capped")
				A.deepEq(e.cleaned, {}, d.name .. ": no verdict")
				A.truthy(e.verdictWork > Geo.VERDICT_WORK_MAX and e.verdictWork <= Geo.VERDICT_WORK_MAX + 16384, d.name .. ": stopped past the cap, at once: " .. e.verdictWork)
				A.truthy(ms <= Tol.ANALYSIS_LUNE_MAX_MS, d.name .. ": " .. ms .. " ms, the best of 3")
				local run = Analyze.run(core, { measureInvalid = true })
				A.eq(run.validation.ok, false)
				A.eq(run.validation.errors[#run.validation.errors].code, "TooComplex", d.name)
				A.eq(run.physics, nil, d.name .. ": measured never")
				local again = Sampling.exposure(prepared(shuffled(rng, d.parts)))
				A.truthy(again.capped, d.name .. ": capped in another order")
			end
		end
	end)

	t.it("(f) units depend on no order: P1 and the slowest valid designs, the same total in 3 orders", function()
		local rng = TestRng.new(Prop.baseSeed)
		local designs: { any } = { H.p1().parts }
		for k = 1, math.min(2, #Worst.valid) do
			table.insert(designs, Worst.valid[k].parts)
		end
		for _, parts in ipairs(designs) do
			local units, capped = unitsOf(prepared(parts))
			A.falsy(capped)
			for _ = 1, 3 do
				A.eq((unitsOf(prepared(shuffled(rng, parts)))), units, "the same units")
			end
		end
	end)
end)
