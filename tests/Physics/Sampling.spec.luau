--!strict
-- T-PHY-09 and the sampling of Physics/Sampling (SPEC §4.3, §4.4, §4.9, E-S2.5, E-S8.5): volume and surface samples in a
-- part's own frame, the budget ladder, exposure, Dust and Enclosed cleaning and the measure on the kept parts (the
-- verdict's reading rules: Verdict.spec; its precision: VerdictPrecision.spec). Budgets are exercised on planted Definitions
-- (H.plantedSampling).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Gen = require("../lib/Gen")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Drafts = require("../Blueprint/Drafts")
local Blueprints = require("../fixtures/Blueprints")
local H = require("./PhysicsHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Versions = require("../../src/shared/Definitions/Versions")
local Quat = require("../../src/shared/Blueprint/Quat")
local Cover = require("../../src/shared/Physics/Cover")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

type Rng = TestRng.TestRng

local Geo = Balance.Geometry
local SHAPES = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
local CTX = Gen.context(Limits, EquipmentTypes.get("Sword") :: any, Materials.enabled, Versions.BLUEPRINT_SCHEMA, Geo)

local function randomPart(rng: Rng, shape: string): any
	local size = { rng:range(0.02, 0.9), rng:range(0.02, 0.9), rng:range(0.02, 0.9) }
	if shape == "Ball" then
		size = { size[1], size[1], size[1] }
	elseif shape == "Cylinder" then
		size = { size[1], size[2], size[2] }
	end
	return H.solid(1, shape, { rng:range(-1, 1), rng:range(0, 5), rng:range(-1, 1) }, H.randomQuat(rng), size)
end

local function exposureOf(parts: { any }): (any, any)
	local list = {}
	for i, p in ipairs(parts) do
		list[i] = Shapes.prepare(p, i)
	end
	return Sampling.exposure(list), list
end

return Test.suite("Physics/Sampling", function(t)
	t.it("§4.1 the 32-direction unit circle: literal, within 1e-15 of math.cos and math.sin", function()
		A.eq(#Sampling.COS, 32)
		A.eq(#Sampling.SIN, 32)
		for k = 0, 31 do
			local a = 2 * Shapes.PI * k / 32
			A.near(Sampling.COS[k + 1], math.cos(a), 1e-15, "COS " .. k)
			A.near(Sampling.SIN[k + 1], math.sin(a), 1e-15, "SIN " .. k)
		end
		A.truthy(table.isfrozen(Sampling.COS) and table.isfrozen(Sampling.SIN))
	end)

	t.it("§4.9 ladder: the first H_LADDER factor that fits, the last when none does", function()
		local seen: { number } = {}
		local h = Sampling.ladder(0.04, function(spacing: number): boolean
			table.insert(seen, spacing)
			return spacing >= 0.1
		end)
		A.eq(h, 0.04 * 2.5)
		A.deepEq(seen, { 0.04 * 1, 0.04 * 1.25, 0.04 * 1.5, 0.04 * 2, 0.04 * 2.5 })
		A.eq(Sampling.ladder(0.04, function(): boolean
			return true
		end), 0.04, "the base spacing when it fits")
		A.eq(Sampling.ladder(0.04, function(): boolean
			return false
		end), 0.04 * Geo.H_LADDER[#Geo.H_LADDER], "the last factor when nothing fits")
	end)

	t.it("§4.3 volume samples: local X outermost, cell centres, n_k = clamp(ceil(size/h), 2, 48), weight V/count", function()
		local P = H.prepare(H.solid(1, "Block", { 1, 2, 3 }, H.I, { 0.2, 0.1, 0.02 }))
		local S = Sampling.volumeSamples(P, 0.05)
		-- 4 × 2 × 2 cells (0.02 / 0.05 ceils to 1, clamped up to N_MIN_AXIS 2)
		A.eq(S.n, 16)
		A.rel(S.w, P.volume / 16, 1e-15)
		local expected = {}
		for i = 0, 3 do
			for j = 0, 1 do
				for k = 0, 1 do
					table.insert(expected, { 1 - 0.1 + (i + 0.5) * 0.05, 2 - 0.05 + (j + 0.5) * 0.05, 3 - 0.01 + (k + 0.5) * 0.01 })
				end
			end
		end
		for n, e in ipairs(expected) do
			A.near(S.x[n], e[1], 1e-12, "x order")
			A.near(S.y[n], e[2], 1e-12, "y order")
			A.near(S.z[n], e[3], 1e-12, "z order")
		end
		-- N_MAX_AXIS caps an axis: 6 long at 0.05 would be 120 cells
		local long = H.prepare(H.solid(1, "Block", { 0, 0, 0 }, H.I, { 6, 0.02, 0.02 }))
		A.eq(Sampling.volumeSamples(long, 0.05).n, Geo.N_MAX_AXIS * 4)
		-- per-axis minima (M3's Asymmetry)
		A.eq(Sampling.volumeSamples(P, 0.05, nil, 10, 3).n, 10 * 3 * 2)
	end)

	t.it("§4.3 volume samples stay inside and under N_MAX_PART, and their weights sum to V; only analytic V counts", function()
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			return randomPart(rng, SHAPES[rng:int(1, 5)])
		end, function(part: any)
			local P = Shapes.prepare(part, 1)
			local S = Sampling.volumeSamples(P, Geo.H_VOL)
			A.truthy(S.n >= 1, "at least one sample")
			A.truthy(S.n <= Geo.N_MAX_PART, "at most N_MAX_PART")
			A.rel(S.w * S.n, P.volume, 1e-12, "weights sum to V")
			for k = 1, S.n do
				A.truthy(Shapes.sd(P, S.x[k], S.y[k], S.z[k]) < 0, "inside")
			end
		end)
		-- a large block coarsens its spacing until it fits
		local big = H.prepare(H.solid(1, "Block", { 0, 0, 0 }, H.I, { 1.6, 5, 0.6 }))
		local S = Sampling.volumeSamples(big, Geo.H_VOL)
		A.truthy(S.n <= Geo.N_MAX_PART and S.n > Geo.N_MAX_PART / 8, "coarsened only as far as it must: " .. S.n)
	end)

	t.it("§4.3 the volume samples of a moved part are the same local cells: a 0.01 nudge cannot change the count", function()
		local base = H.solid(1, "Wedge", { 0, 1, 0 }, H.axisAngle(1, 2, 3, 40), { 0.3, 0.6, 0.2 })
		local moved = H.solid(1, "Wedge", { 0.01, 1.01, 0.01 }, base.rot, base.size)
		local a, b = Sampling.volumeSamples(H.prepare(base), Geo.H_VOL), Sampling.volumeSamples(H.prepare(moved), Geo.H_VOL)
		A.eq(a.n, b.n)
		A.eq(a.w, b.w)
		for k = 1, a.n do
			A.near(b.x[k] - a.x[k], 0.01, 1e-12)
		end
	end)

	t.it("§4.9 volumeProbes: kept parts only, within N_VOL_TOTAL, in part order", function()
		local core = H.f("F1")
		local parts = H.prepared(core)
		local kept = { true, true, false, true, true }
		local probes = Sampling.volumeProbes(parts, kept)
		A.eq(probes.h, Geo.H_VOL)
		A.eq(probes.byPart[3].n, 0, "a cleaned part has no samples")
		local total = 0
		for i = 1, #parts do
			total += probes.byPart[i].n
		end
		A.eq(probes.total, total)
		-- 24 hitbox-sized blocks: 13 ladder steps are there for this
		local big = H.p1()
		local all: { boolean } = {}
		for i = 1, #big.parts do
			all[i] = true
		end
		local coarse = Sampling.volumeProbes(H.prepared(big), all)
		A.truthy(coarse.h > Geo.H_VOL, "coarsened")
		A.truthy(coarse.total <= Geo.N_VOL_TOTAL, "within budget: " .. coarse.total)
		local planted = H.plantedSampling({ N_VOL_TOTAL = 100 })
		local tiny = planted.volumeProbes(parts, { true, true, true, true, true })
		A.truthy(tiny.h > Geo.H_VOL, "a smaller budget coarsens")
	end)

	-- It coarsens itself to N_MAX_PART (§4.3), so it must not coarsen everyone else as well.
	t.it("§4.9 volumeProbes: a part above N_MAX_PART counts as N_MAX_PART while the ladder picks h", function()
		local big = H.prepared(H.core("big", {
			H.part(1, "Grip", "Block", "Iron", { 0, 0.5, 0 }, H.I, { 0.2, 0.9, 0.2 }),
			H.part(2, "Blade", "Block", "Iron", { 0, 3, 0 }, H.I, { 1.6, 4, 0.6 }),
		}))
		A.eq(Sampling.volumeProbes(big, { true, true }).h, Geo.H_VOL)
	end)

	t.it("§4.3 surface samples: on the surface, unit outward normals, weights summing to the area, every shape", function()
		Prop.check(Tol.PROP_N, function(rng: Rng): any
			return randomPart(rng, SHAPES[rng:int(1, 5)])
		end, function(part: any)
			local P = Shapes.prepare(part, 1)
			local S = Sampling.surfaceSamples(P, Geo.H_SURF)
			local sum = 0
			for k = 1, S.n do
				sum += S.w[k]
				local x, y, z = S.x[k], S.y[k], S.z[k]
				A.near(Shapes.sd(P, x, y, z), 0, 1e-12, part.shape .. " on the surface")
				local nx, ny, nz = S.nx[k], S.ny[k], S.nz[k]
				A.near(nx * nx + ny * ny + nz * nz, 1, 1e-12, part.shape .. " unit normal")
				local probe = 1e-3
				A.truthy(Shapes.sd(P, x + probe * nx, y + probe * ny, z + probe * nz) > 0, part.shape .. " normal points out")
				-- the patch lies in the tangent plane
				A.near(S.e1x[k] * nx + S.e1y[k] * ny + S.e1z[k] * nz, 0, 1e-12, part.shape .. " e1 tangent")
				A.near(S.e2x[k] * nx + S.e2y[k] * ny + S.e2z[k] * nz, 0, 1e-12, part.shape .. " e2 tangent")
			end
			A.rel(sum, P.area, 1e-12, part.shape .. " weights sum to the area")
		end)
	end)

	t.it("§4.3 surface grids: ceil(edge/h) per edge up to NS_MAX, 8/16/32 cylinder directions, ball faces, flat flags", function()
		local block = H.prepare(H.solid(1, "Block", { 0, 0, 0 }, H.I, { 0.2, 0.4, 0.08 }))
		-- at 0.04: 5, 10 and 2 cells per edge
		A.eq(Sampling.surfaceSamples(block, 0.04).n, 2 * (10 * 2 + 5 * 2 + 5 * 10))
		local huge = H.prepare(H.solid(1, "Block", { 0, 0, 0 }, H.I, { 6, 6, 6 }))
		A.eq(Sampling.surfaceSamples(huge, 0.04).n, 6 * Geo.NS_MAX * Geo.NS_MAX, "NS_MAX per edge")
		local function sideDirections(diameter: number): number
			local P = H.prepare(H.solid(1, "Cylinder", { 0, 0, 0 }, H.I, { 0.01, diameter, diameter }))
			local S = Sampling.surfaceSamples(P, 0.04)
			local side = 0
			for k = 1, S.n do
				if not S.flat[k] then
					side += 1
				end
			end
			return side
		end
		A.eq(sideDirections(0.1), 8, "circumference/h ≤ 8")
		A.eq(sideDirections(0.2), 16, "≤ 16")
		A.eq(sideDirections(0.6), 32, "above")
		local ball = H.prepare(H.solid(1, "Ball", { 0, 0, 0 }, H.I, { 0.4, 0.4, 0.4 }))
		local S = Sampling.surfaceSamples(ball, 0.04)
		local perAxis = math.ceil((Shapes.PI * 0.2 / 2) / 0.04)
		A.eq(S.n, 6 * perAxis * perAxis)
		A.falsy(S.flat[1], "curved samples keep the centre verdict")
		A.truthy(Sampling.surfaceSamples(block, 0.04).flat[1], "planar samples get the boundary test")
	end)

	t.it("§4.3 a thin cylinder's caps keep 2 cells per axis, however far below the spacing", function()
		local thin = H.prepare(H.solid(1, "Cylinder", { 0, 1, 0 }, H.I, { 0.3, 0.02, 0.02 }))
		local S = Sampling.surfaceSamples(thin, Geo.H_SURF)
		local flat = 0
		for k = 1, S.n do
			flat += if S.flat[k] then 1 else 0
		end
		A.eq(flat, 2 * 4, "2 caps × a 2 × 2 grid, all four cells inside the disk")
	end)

	t.it("§4.4 an isolated part is fully exposed, every shape", function()
		for _, shape in ipairs(SHAPES) do
			local e, list = exposureOf({ H.solid(1, shape, { 0, 2, 0 }, H.axisAngle(1, 1, 0, 25), { 0.3, 0.4, 0.4 }) })
			A.rel(e.exposedKept[1], list[1].area, 1e-12, shape)
			A.truthy(e.kept[1], shape .. " kept")
			A.eq(#e.cleaned, 0, shape)
			H.verdictReads(list, 1, 1, shape .. ", its whole model")
		end
	end)

	t.it("§4.4 a flush contact hides the faces across it, on both parts", function()
		local a = H.solid(1, "Block", { 0, 1, 0 }, H.I, { 0.4, 0.4, 0.4 })
		local b = H.solid(2, "Block", { 0, 1.4, 0 }, H.I, { 0.4, 0.4, 0.4 })
		local e = exposureOf({ a, b })
		local face = 0.4 * 0.4
		A.rel(e.exposedKept[1], 6 * face - face, 1e-9, "a: one face hidden")
		A.rel(e.exposedKept[2], 6 * face - face, 1e-9, "b: one face hidden")
		-- contact areas: each part's own face within CONTACT_TOL of the other (Joints)
		A.rel(e.contact[1][2], face, 1e-9)
		A.rel(e.contact[2][1], face, 1e-9)
		A.eq(e.contact[1][1], 0)
	end)

	t.it("§4.4 a part on a larger face hides exactly its footprint (the boundary sub-grid works)", function()
		local base = H.solid(1, "Block", { 0, 1, 0 }, H.I, { 1, 0.4, 1 })
		-- a footprint that crosses sample rows: 0.33 is no multiple of any sample spacing
		local top = H.solid(2, "Block", { 0.017, 1.3, 0.023 }, H.I, { 0.33, 0.2, 0.33 })
		local e = exposureOf({ base, top })
		local areaBase = 2 * (1 * 0.4 + 1 * 0.4 + 1 * 1)
		A.near(e.exposedKept[1], areaBase - 0.33 * 0.33, 4e-4, "the base loses its footprint, to a fraction of a sample's area")
		A.truthy(e.subSampled > 0, "the patches on the footprint's rim used the sub-grid")
	end)

	t.it("§4.4 a curved sample keeps its centre verdict: a half-hidden cylinder's side is a whole number of samples", function()
		-- a cylinder along X, a block over its +X half: 20 rows of 16 directions, the block's face at x = 0.1055 cuts the row
		-- centred on x = 0.1 (not hidden), so 13 whole rows show, and the −X cap
		local e, list = exposureOf({
			H.solid(1, "Cylinder", { 0, 2, 0 }, H.I, { 0.8, 0.2, 0.2 }),
			H.solid(2, "Block", { 0.3055, 2, 0 }, H.I, { 0.4, 0.6, 0.6 }),
		})
		local S = Sampling.surfaceSamples(list[1], e.hSurf)
		local sideWeight = 0
		for k = S.n, 1, -1 do
			if not S.flat[k] then
				sideWeight = S.w[k]
				break
			end
		end
		A.near((e.exposedKept[1] - Shapes.PI * 0.1 * 0.1) / sideWeight, 13 * 16, 1e-9, "whole rows of side samples")
	end)

	t.it("§4.4 gaps: a gap validation calls connected hides the faces across it, a larger one does not", function()
		local function exposedAt(gap: number): number
			local a = H.solid(1, "Block", { 0, 1, 0 }, H.I, { 0.4, 0.4, 0.4 })
			local b = H.solid(2, "Block", { 0, 1.4 + gap, 0 }, H.I, { 0.4, 0.4, 0.4 })
			return exposureOf({ a, b }).exposedKept[1]
		end
		local full, hidden = 6 * 0.16, 5 * 0.16
		for _, gap in ipairs({ 0, 0.002, 0.004, 0.009, Limits.CONTACT_TOL, Geo.HIDE_OFFSET - 1e-6 }) do
			A.rel(exposedAt(gap), hidden, 1e-9, "gap " .. gap .. " hides")
		end
		A.eq(Geo.HIDE_OFFSET, Limits.CONTACT_TOL + 0.002, "HIDE_OFFSET = CONTACT_TOL + 0.002")
		A.rel(exposedAt(Geo.HIDE_OFFSET + 1e-6), full, 1e-9, "just past HIDE_OFFSET")
		A.rel(exposedAt(0.05), full, 1e-9, "a real gap")
	end)

	-- What Joints reads (§5.2, M3): the faces across a gap, not only flush ones.
	t.it("§4.4 contact areas count up to CONTACT_TOL across a gap", function()
		local function contactAt(gap: number): number
			local a = H.solid(1, "Block", { 0, 1, 0 }, H.I, { 0.4, 0.4, 0.4 })
			local b = H.solid(2, "Block", { 0, 1.4 + gap, 0 }, H.I, { 0.4, 0.4, 0.4 })
			return exposureOf({ a, b }).contact[1][2]
		end
		A.rel(contactAt(0.005), 0.16, 1e-9, "within CONTACT_TOL")
		A.eq(contactAt(0.015), 0, "past it")
		A.eq(contactAt(0.011), 0, "past CONTACT_TOL, within HIDE_OFFSET")
		-- once: the verdict counts none, and a speck elsewhere changes nothing
		local a = H.solid(1, "Block", { 0, 1, 0 }, H.I, { 0.4, 0.4, 0.4 })
		local b = H.solid(2, "Block", { 0, 1.4, 0 }, H.I, { 0.4, 0.4, 0.4 })
		local speck = H.solid(3, "Block", { 0.225, 1, 0 }, H.I, { 0.05, 0.05, 0.05 })
		A.rel(exposureOf({ a, b, speck }).contact[1][2], 0.16, 1e-9, "counted once")
		A.eq(exposureOf({ a, b, speck }).contact[1][3], 0, "no row for a cleaned part")
		A.eq(exposureOf({ a, b, speck }).contact[3][1], 0, "nor from it")
	end)

	t.it("§4.4 coincident faces count once: the higher rank keeps them, whatever the ids; buried samples are hidden", function()
		-- b ⊂ a, as thick in X and Y, half as thick in Z: their ±X and ±Y faces share bands, and b's ±Z faces are buried
		local a = H.solid(1, "Block", { 0, 1, 0 }, H.I, { 0.4, 0.4, 0.4 })
		local b = H.solid(2, "Block", { 0, 1, 0 }, H.I, { 0.4, 0.4, 0.2 })
		local e = exposureOf({ a, b })
		A.deepEq(e.cleaned, { { partId = 2, reason = "Enclosed" } }, "b, the smaller: buried or coincident everywhere")
		A.eq(e.exposedKept[2], 0, "b measures nothing")
		A.rel(e.exposedKept[1], 6 * 0.16, 1e-9, "a, the larger, keeps its whole surface")
		-- the same pair the other way round: the same
		local swapped = exposureOf({ b, a })
		A.deepEq(swapped.cleaned, { { partId = 2, reason = "Enclosed" } }, "the id is no help to the smaller part")
		A.rel(swapped.exposedKept[2], 6 * 0.16, 1e-9, "a keeps it all")
		-- 2 of the same size overlapping along X, the same Y and Z ranges: the lower one keeps the bands they share
		local left = H.solid(3, "Block", { -0.2, 1, 0 }, H.I, { 0.6, 0.3, 0.1 })
		local right = H.solid(4, "Block", { 0.2, 1, 0.0 }, H.I, { 0.6, 0.3, 0.1 })
		local shared = 0.2 * (2 * 0.3 + 2 * 0.1)
		local end_ = 0.3 * 0.1
		local total = 2 * (0.6 * 0.3 + 0.6 * 0.1 + 0.3 * 0.1)
		for _, pair in ipairs({ { left, right }, { right, left } }) do
			local pairs_ = exposureOf(pair)
			local first = if pair[1] == left then 1 else 2
			A.rel(pairs_.exposedKept[first], total - end_, 1e-9, "the left, by where it stands: |x| ties, then x")
			A.rel(pairs_.exposedKept[3 - first], total - end_ - shared, 1e-9, "the right gives the bands up")
		end
	end)

	t.it("T-PHY-09 cleaning classes are Dust and Enclosed only, Dust first, in part order", function()
		local host = H.solid(1, "Block", { 0, 2, 0 }, H.I, { 0.4, 1, 0.4 })
		local inside = H.solid(2, "Block", { 0, 2, 0 }, H.I, { 0.2, 0.2, 0.2 })
		-- 0.05³ = 0.000125 < MIN_PART_VOLUME: flush on the host and also buried in it
		local dustOut = H.solid(3, "Block", { 0.225, 2, 0 }, H.I, { 0.05, 0.05, 0.05 })
		local dustIn = H.solid(4, "Block", { 0, 2.2, 0 }, H.I, { 0.05, 0.05, 0.05 })
		local e = exposureOf({ host, inside, dustOut, dustIn })
		A.deepEq(e.kept, { true, false, false, false })
		A.deepEq(e.cleaned, {
			{ partId = 2, reason = "Enclosed" },
			{ partId = 3, reason = "Dust" },
			{ partId = 4, reason = "Dust" },
		})
		-- the Dust floor: strictly below MIN_PART_VOLUME
		local side = 0.2
		local thick = Geo.MIN_PART_VOLUME / (side * side)
		local onFloor = exposureOf({ H.solid(1, "Block", { 0, 2, 0 }, H.I, { side, side, thick }) })
		A.truthy(onFloor.kept[1], "exactly the floor is kept")
		local below = exposureOf({ H.solid(1, "Block", { 0, 2, 0 }, H.I, { side, side, thick * 0.999 }) })
		A.deepEq(below.cleaned, { { partId = 1, reason = "Dust" } })
	end)

	t.it("T-PHY-09 Enclosed: under ENCLOSED_EXPOSED_MAX of its surface shows, partial overlaps kept", function()
		local host = H.solid(1, "Block", { 0, 2, 0 }, H.I, { 0.4, 2.4, 0.4 })
		-- a 0.1 × 2 × 0.1 rod sticking out of the host's top by t: it shows 0.01 + 4 · 0.1 · t of its 0.82 stud²
		local function rod(stick: number): any
			return H.solid(2, "Block", { 0, 2 + 1.2 + stick - 1, 0 }, H.I, { 0.1, 2, 0.1 })
		end
		local low = exposureOf({ host, rod(0.005) })
		A.deepEq(low.cleaned, { { partId = 2, reason = "Enclosed" } }, "1.7 % shows")
		A.eq(low.exposedKept[2], 0, "a cleaned part measures nothing")
		local high = exposureOf({ host, rod(0.1) })
		A.eq(#high.cleaned, 0, "6.1 % shows: kept")
		A.near(high.exposedKept[2], 0.05, 0.002, "and measures it")
		-- on either side of the threshold: 2 % of 0.82 is t = 0.016
		A.deepEq(exposureOf({ host, rod(0.012) }).cleaned, { { partId = 2, reason = "Enclosed" } }, "1.8 % shows")
		A.eq(#exposureOf({ host, rod(0.02) }).cleaned, 0, "2.2 % shows")
		-- what the verdict reads there: the cap shows whole, and the 4 sides what stands clear of the host, exactly
		local eps = Geo.EPS_GEOM
		H.verdictReads(H.prepared({ parts = { host, rod(0.012) } }), 2, (0.01 + 4 * 0.1 * (0.012 - eps)) / 0.82, "t = 0.012")
		H.verdictReads(H.prepared({ parts = { host, rod(0.02) } }), 2, (0.01 + 4 * 0.1 * (0.02 - eps)) / 0.82, "t = 0.02")
		-- half inside another part is a partial overlap, kept
		local half = exposureOf({ host, H.solid(2, "Ball", { 0.2, 2, 0 }, H.I, { 0.2, 0.2, 0.2 }) })
		A.eq(#half.cleaned, 0, "a ball half inside")
		local corner = exposureOf({ host, H.solid(2, "Block", { 0.2, 3.2, 0.2 }, H.axisAngle(1, 1, 1, 30), { 0.2, 0.2, 0.2 }) })
		A.eq(#corner.cleaned, 0, "a tilted block over the host's corner")
	end)

	t.it("T-PHY-09 duplicates: exact copies are Enclosed and the lowest id kept, every shape, any pose", function()
		local rng = TestRng.new(Tol.PROP_BASE_SEED)
		for _, shape in ipairs(SHAPES) do
			for _ = 1, 8 do
				local original = randomPart(rng, shape)
				local copy, third = Drafts.deepCopy(original), Drafts.deepCopy(original)
				copy.id, third.id = 2, 3
				if Shapes.prepare(original, 1).volume >= Geo.MIN_PART_VOLUME then
					local e, list = exposureOf({ original, copy, third })
					A.deepEq(e.kept, { true, false, false }, shape .. " lowest id kept")
					A.deepEq(e.cleaned, { { partId = 2, reason = "Enclosed" }, { partId = 3, reason = "Enclosed" } }, shape)
					A.rel(e.exposedKept[1], list[1].area, 1e-12, shape .. " the kept copy is fully exposed again")
				end
			end
		end
	end)

	t.it("T-PHY-09 duplicates: a copy turned about its own symmetry axis is the same solid, and Enclosed", function()
		local cylinder = H.solid(1, "Cylinder", { 0, 2, 0 }, H.Z90, { 0.6, 0.24, 0.24 })
		-- local X stays the axis: 37° about it
		local spin = Quat.hemisphere(Quat.mul(H.Z90, H.axisAngle(1, 0, 0, 37)))
		local e = exposureOf({ cylinder, H.solid(2, "Cylinder", { 0, 2, 0 }, spin, { 0.6, 0.24, 0.24 }) })
		A.deepEq(e.cleaned, { { partId = 2, reason = "Enclosed" } }, "cylinder spun 37° about its axis")
		local ball = H.solid(1, "Ball", { 0, 2, 0 }, H.I, { 0.3, 0.3, 0.3 })
		local turned = H.solid(2, "Ball", { 0, 2, 0 }, H.axisAngle(1, 2, 3, 77), { 0.3, 0.3, 0.3 })
		-- no sameSolid (the frames differ), so the rank decides between the 2 and one is left, whichever comes first
		A.eq(#exposureOf({ ball, turned }).cleaned, 1, "ball turned any way")
		A.eq(exposureOf({ ball, turned }).cleaned[1].partId, exposureOf({ turned, ball }).cleaned[1].partId, "the same one")
	end)

	-- Every added copy cleaned Enclosed; kept parts measure as without the copies, to the bit.
	local function duplicatesOnSwords(count: number)
		Prop.check(count, function(rng: Rng): any
			local core = Gen.validSword(rng, CTX)
			local out, added = Gen.withFiller(rng, CTX, core, "Duplicate")
			return { core = core, out = out, added = added }
		end, function(c: any)
			local before = Sampling.exposure(H.prepared(c.core))
			local after = Sampling.exposure(H.prepared(c.out))
			A.eq(#after.cleaned, #before.cleaned + #c.added, "one cleaned part per copy")
			local isCopy: { [number]: boolean } = {}
			for _, id in ipairs(c.added) do
				isCopy[id] = true
			end
			for _, cleaned in ipairs(after.cleaned) do
				if isCopy[cleaned.partId] then
					A.eq(cleaned.reason, "Enclosed", "copy " .. cleaned.partId)
				end
			end
			A.eq(after.surfSamples, before.surfSamples, "copies are not sampled")
			A.eq(after.subSampled, before.subSampled, "copies use none of the sub-grid budget")
			H.sameKeptMeasure(after, before, #c.core.parts)
		end)
	end
	t.it("T-PHY-09 duplicates on generated swords, 40 designs", function()
		duplicatesOnSwords(40)
	end)
	t.slow("T-PHY-09 duplicates on generated swords, FUZZ_N_VALID designs", function()
		duplicatesOnSwords(Tol.FUZZ_N_VALID)
	end)

	-- Gen's Enclosed and Dust filler is cleaned as such, and kept parts measure as without it, to the bit (T-DIF-04).
	local function fillerOnSwords(kind: Gen.FillerKind, count: number)
		Prop.check(count, function(rng: Rng): any
			local core = Gen.validSword(rng, CTX)
			local out, added = Gen.withFiller(rng, CTX, core, kind)
			return { core = core, out = out, added = added }
		end, function(c: any)
			local before = Sampling.exposure(H.prepared(c.core))
			local after = Sampling.exposure(H.prepared(c.out))
			A.eq(#after.cleaned, #before.cleaned + #c.added, "one cleaned part per filler")
			for _, cleaned in ipairs(after.cleaned) do
				A.eq(cleaned.reason, kind, "part " .. cleaned.partId)
			end
			A.eq(after.surfSamples, before.surfSamples, "fillers are not measured")
			A.eq(after.subSampled, before.subSampled, "fillers use none of the sub-grid budget")
			H.sameKeptMeasure(after, before, #c.core.parts)
		end)
	end
	t.it("T-PHY-09 enclosed filler on generated swords, 40 designs", function()
		fillerOnSwords("Enclosed", 40)
	end)
	t.it("T-PHY-09 dust filler on generated swords, 40 designs", function()
		fillerOnSwords("Dust", 40)
	end)
	t.slow("T-PHY-09 enclosed and dust filler on generated swords, FUZZ_N_VALID designs each", function()
		fillerOnSwords("Enclosed", Tol.FUZZ_N_VALID)
		fillerOnSwords("Dust", Tol.FUZZ_N_VALID)
	end)

	t.it("§4.9 a pile of exact copies: no coarser grid, no budget used, the same areas to the bit", function()
		-- F4's huge blade 9 times over would be far past N_SURF_WORK if it were sampled
		local base = Blueprints.get("F4").core
		local pile = Drafts.deepCopy(base)
		for k = 1, 8 do
			local copy = Drafts.deepCopy(base.parts[4])
			copy.id = 10 + k
			table.insert(pile.parts, copy)
		end
		local before, after = Sampling.exposure(H.prepared(base)), Sampling.exposure(H.prepared(pile))
		A.eq(after.subSampled, before.subSampled)
		A.eq(after.surfSamples, before.surfSamples)
		H.sameKeptMeasure(after, before, 5)
		A.eq(#after.cleaned, 8)
		-- q and −q are the same solid
		local neg = H.solid(2, "Wedge", { 0, 2, 0 }, { 0, 0, -0.6, -0.8 }, { 0.3, 0.4, 0.5 })
		local wedge = H.solid(1, "Wedge", { 0, 2, 0 }, { 0, 0, 0.6, 0.8 }, { 0.3, 0.4, 0.5 })
		A.truthy(Shapes.sameSolid(Shapes.prepare(wedge, 1), Shapes.prepare(neg, 2)))
		neg.size = { 0.3, 0.4, 0.50001 }
		A.falsy(Shapes.sameSolid(Shapes.prepare(wedge, 1), Shapes.prepare(neg, 2)), "any other size is another solid")
	end)

	t.it("§4.4 the measure: A16 and A17 leave every kept part's exposed area bit-identical", function()
		local function second(baseId: string, extra: { any }): (any, any)
			local base = Blueprints.get(baseId).core
			local parts = Drafts.deepCopy(base.parts)
			for _, p in ipairs(extra) do
				table.insert(parts, p)
			end
			return Sampling.exposure(H.prepared(base)), Sampling.exposure(H.prepared({ parts = parts }))
		end
		local before, after = second("F1", {
			H.part(6, "Blade", "Block", "Steel", { 0, 2.68, 0 }, H.I, { 0.10, 1.00, 0.04 }),
			H.part(7, "Guard", "Block", "Iron", { 0, 1.29, 0 }, H.I, { 0.60, 0.10, 0.16 }),
		})
		A.deepEq(after.cleaned, { { partId = 6, reason = "Enclosed" }, { partId = 7, reason = "Enclosed" } })
		for i = 1, 5 do
			A.eq(after.exposedKept[i], before.exposedKept[i], "A16 part " .. i)
		end
		local blade = Blueprints.get("F2").core.parts[4]
		local extras = {}
		for id = 5, 7 do
			local copy = Drafts.deepCopy(blade)
			copy.id = id
			table.insert(extras, copy)
		end
		before, after = second("F2", extras)
		A.eq(#after.cleaned, 3)
		for i = 1, 4 do
			A.eq(after.exposedKept[i], before.exposedKept[i], "A17 part " .. i)
		end
	end)

	t.it("§4.4 the measure on a real overlap: a cleaned part hides nothing, a kept one does", function()
		-- the inner rod sticks out by a sliver: Enclosed, and the host's whole top is exposed. Further out it is kept and hides
		-- its footprint
		local host = H.solid(1, "Block", { 0, 2, 0 }, H.I, { 0.4, 2.4, 0.4 })
		local rod = H.solid(2, "Block", { 0, 2 + 1.2 + 0.005 - 1, 0 }, H.I, { 0.1, 2, 0.1 })
		local e, list = exposureOf({ host, rod })
		A.deepEq(e.kept, { true, false })
		A.rel(e.exposedKept[1], list[1].area, 1e-12, "cleaned parts hide nothing")
		local out = exposureOf({ host, H.solid(2, "Block", { 0, 2 + 1.2 + 0.1 - 1, 0 }, H.I, { 0.1, 2, 0.1 }) })
		A.deepEq(out.kept, { true, true })
		A.near(out.exposedKept[1], list[1].area - 0.01, 1e-9, "a kept rod hides the host's top under it")
	end)

	t.it("§4.4 the measure on a sword that uses up N_SUB_WORK: hidden parts leave every kept part bit-identical", function()
		local base = H.ornate()
		local before = Sampling.exposure(H.prepared(base))
		A.eq(#before.cleaned, 0)
		local lifted = H.plantedSampling({ N_SUB_WORK = 1e9 }).exposure(H.prepared(base))
		local rationed = false
		for i = 1, #base.parts do
			rationed = rationed or lifted.exposedKept[i] ~= before.exposedKept[i]
		end
		A.truthy(rationed, "the budget does run out on this design")
		-- 4 Blocks enclosed in the blade's core, none next to the parts the budget runs out on, and a Dust speck on the guard
		local filled = Drafts.deepCopy(base)
		for k = 1, 4 do
			table.insert(filled.parts, H.part(18 + k, "Blade", "Block", "Iron", { 0, 1.6 + k * 0.4, 0 }, H.I, { 0.1, 0.1, 0.05 }))
		end
		table.insert(filled.parts, H.part(23, "Guard", "Block", "Iron", { 0, 1.41, 0.13 + 0.025 }, H.I, { 0.05, 0.05, 0.05 }))
		local after = Sampling.exposure(H.prepared(filled))
		A.deepEq(after.cleaned, {
			{ partId = 19, reason = "Enclosed" },
			{ partId = 20, reason = "Enclosed" },
			{ partId = 21, reason = "Enclosed" },
			{ partId = 22, reason = "Enclosed" },
			{ partId = 23, reason = "Dust" },
		})
		A.eq(after.subSampled, before.subSampled)
		H.sameKeptMeasure(after, before, #base.parts)
	end)

	-- samples as the ladder counts them, faces as if every part were a Block, × (1 + the parts within its margin)
	local function estimate(p: any, h: number): number
		local function cells(size: number): number
			return math.clamp(math.ceil(size / h), 1, Geo.NS_MAX)
		end
		local a, b, c = cells(2 * p.hx), cells(2 * p.hy), cells(2 * p.hz)
		return 2 * (a * b + b * c + a * c)
	end
	local function candidatesOf(parts: { any }, i: number, h: number, counts: (number) -> boolean): number
		local c = 0
		for j, q in ipairs(parts) do
			if j ~= i and counts(j) and Shapes.aabbOverlap(parts[i], q, Geo.HIDE_OFFSET + Limits.CONTACT_TOL + h) then
				c += 1
			end
		end
		return c
	end
	local function ladderWork(parts: { any }, h: number, counts: (number) -> boolean): number
		local total = 0
		for i, p in ipairs(parts) do
			if counts(i) then
				total += estimate(p, h) * (1 + candidatesOf(parts, i, h, counts))
			end
		end
		return total
	end
	local function everyPart(_: number): boolean
		return true
	end

	-- Past this, hidden parts could buy or dodge a tier (§5, E-S2.9's inputs; Reference.spec has the flips themselves).
	t.it("§4.4 the measure's ladder counts kept parts only: parts that would coarsen it leave every kept part bit-identical", function()
		local base = H.ornate()
		local before = Sampling.exposure(H.prepared(base))
		local filled = Drafts.deepCopy(base)
		for k = 1, 6 do
			local slot = if k <= 5 then "Blade" else "Pommel"
			table.insert(filled.parts, H.part(18 + k, slot, "Block", "Iron", { 0, 1.6 + (k - 0.5) * (2 / 6), 0 }, H.I, { 0.1, 0.3, 0.05 }))
		end
		local after = Sampling.exposure(H.prepared(filled))
		A.eq(#after.cleaned, 6, "all six are enclosed")
		A.truthy(ladderWork(H.prepared(filled), before.hSurf, everyPart) > Geo.N_SURF_WORK, "counted, they would coarsen it")
		A.eq(after.surfSamples, before.surfSamples, "not sampled")
		H.sameKeptMeasure(after, before, #base.parts)
	end)

	local function coreFill(rng: Rng): any
		local base = H.ornate()
		local core = base.parts[1]
		for _, p in ipairs(base.parts) do
			if p.size[2] > core.size[2] then
				core = p -- the longest part: the blade's core
			end
		end
		local filled = Drafts.deepCopy(base)
		local count = rng:int(4, 6)
		for k = 1, count do
			local slot = if k <= 5 then "Blade" else "Pommel"
			local f = rng:range(0.4, 0.97)
			table.insert(filled.parts, H.part(18 + k, slot, "Block", "Iron", core.pos, core.rot,
				{ core.size[1] * f, core.size[2] * f, core.size[3] * f }))
		end
		return { base = base, filled = filled, count = count }
	end

	local function fillInCore(count: number)
		local before = Sampling.exposure(H.prepared(H.ornate()))
		local coarser = 0
		Prop.check(count, coreFill, function(c: any)
			local list = H.prepared(c.filled)
			local after = Sampling.exposure(list)
			A.eq(#after.cleaned, c.count, "the fill is enclosed")
			if ladderWork(list, before.hSurf, everyPart) > Geo.N_SURF_WORK then
				coarser += 1
			end
			H.sameKeptMeasure(after, before, #c.base.parts)
		end)
		A.truthy(coarser > count / 2, "most fills would coarsen a ladder over all parts: " .. coarser .. " of " .. count)
	end
	t.it("§4.4 the measure's ladder: random fill inside a large design's core, kept parts bit-identical, 40 designs", function()
		fillInCore(40)
	end)
	t.slow("§4.4 the measure's ladder: random fill inside a large design's core, kept parts bit-identical, FUZZ_N_VALID designs", function()
		fillInCore(Tol.FUZZ_N_VALID)
	end)

	-- K + F = K alone, the whole of what the measure returns on K (K here has its own Enclosed parts or not, past a budget or not).
	local function measuresAsAlone(core: any, what: string)
		local e = Sampling.exposure(H.prepared(core))
		local alone: { any } = {}
		local origin: { number } = {}
		for i, part in ipairs(core.parts) do
			if e.kept[i] then
				table.insert(alone, part)
				origin[#alone] = i
			else
				A.eq(e.exposedKept[i], 0, what .. ": cleaned part " .. i .. " measures nothing")
				for j = 1, #core.parts do
					A.eq(e.contact[i][j], 0, what .. ": no row from cleaned part " .. i)
					A.eq(e.contact[j][i], 0, what .. ": no row to cleaned part " .. i)
				end
			end
		end
		local own = Sampling.exposure(H.prepared({ parts = alone }))
		A.eq(#own.cleaned, 0, what .. ": the kept parts alone stay kept")
		A.eq(own.hSurf, e.hSurf, what .. ": the same ladder")
		A.eq(own.surfSamples, e.surfSamples, what .. ": the same samples")
		A.eq(own.subSampled, e.subSampled, what .. ": the same patches")
		for k = 1, #alone do
			A.eq(e.exposedKept[origin[k]], own.exposedKept[k], what .. ": kept part " .. origin[k])
			for l = 1, #alone do
				A.eq(e.contact[origin[k]][origin[l]], own.contact[k][l], what .. ": contact " .. origin[k] .. ", " .. origin[l])
			end
		end
		return e
	end

	t.it("§4.4 K + F measures as K alone, past N_SURF_WORK: P1, whose kept parts alone are the same 15", function()
		local e = measuresAsAlone(H.p1(), "P1")
		A.eq(#e.cleaned, 9)
		A.truthy(e.hSurf > Geo.H_SURF, "past the budget")
	end)

	t.it("§4.4 K + F measures as K alone, past N_SUB_WORK: C09 + 4 hidden blocks + a speck", function()
		local filled = H.ornate()
		for k = 1, 4 do
			table.insert(filled.parts, H.part(18 + k, "Blade", "Block", "Iron", { 0, 1.6 + k * 0.4, 0 }, H.I, { 0.1, 0.1, 0.05 }))
		end
		table.insert(filled.parts, H.part(23, "Guard", "Block", "Iron", { 0, 1.41, 0.13 + 0.025 }, H.I, { 0.05, 0.05, 0.05 }))
		local e = measuresAsAlone(filled, "C09 + fill")
		A.eq(#e.cleaned, 5)
	end)

	t.it("§4.4 nothing cleaned, or exact copies only: the measure's ladder is the design's own", function()
		local plain = Sampling.exposure(H.prepared(Blueprints.get("F5").core))
		A.eq(#plain.cleaned, 0)
		A.eq(plain.hSurf, Geo.H_SURF, "nothing cleaned")
		A.truthy(ladderWork(H.prepared(H.p1()), Geo.H_SURF, everyPart) > Geo.N_SURF_WORK, "a design past the budget")
		local ornate = H.prepared(H.ornate())
		local e = Sampling.exposure(ornate)
		A.eq(#e.cleaned, 0, "a large design with nothing cleaned")
		A.truthy(ladderWork(ornate, e.hSurf, everyPart) <= Geo.N_SURF_WORK, "within the budget by the estimate")
		-- exact copies never reach the ladder, so they cannot coarsen it
		local base = Blueprints.get("F4").core
		local pile = Drafts.deepCopy(base)
		for k = 1, 8 do
			local copy = Drafts.deepCopy(base.parts[4])
			copy.id = 10 + k
			table.insert(pile.parts, copy)
		end
		local piled = Sampling.exposure(H.prepared(pile))
		A.eq(piled.hSurf, Sampling.exposure(H.prepared(base)).hSurf, "exact copies only")
	end)

	t.it("§4.4 the verdict uses none of the measure's sub-grid budget", function()
		-- a plate enclosed in the kept base, with the lowest index: its verdict reads patches on the base's rim first
		local plate = H.part(1, "Guard", "Block", "Iron", { 0, 1.3, 0 }, H.I, { 0.9, 0.16, 0.2 })
		local guard = H.part(2, "Guard", "Block", "Iron", { 0, 1.3, 0 }, H.I, { 1, 0.18, 0.24 })
		local blade = H.part(3, "Blade", "Block", "Iron", { 0.017, 1.5, 0.023 }, H.I, { 0.33, 0.22, 0.1 })
		local planted = H.plantedSampling({ N_SUB_WORK = 1400 })
		local without = planted.exposure({ H.prepare(guard, 1), H.prepare(blade, 2) })
		local with = planted.exposure({ H.prepare(plate, 1), H.prepare(guard, 2), H.prepare(blade, 3) })
		A.deepEq(with.cleaned, { { partId = 1, reason = "Enclosed" } }, "the plate is cleaned")
		A.truthy(without.subSampled > 0, "the budget is in use")
		A.eq(with.subSampled, without.subSampled, "the same patches get it")
		A.eq(with.exposedKept[2], without.exposedKept[1], "the kept guard measures as without the plate")
		A.eq(with.exposedKept[3], without.exposedKept[2], "the kept blade measures as without the plate")
	end)

	t.it("§4.9 surface budget: the ladder keeps samples × (1 + candidates) within N_SURF_WORK, deterministically", function()
		local parts = H.prepared(H.p1())
		local e = Sampling.exposure(parts)
		A.truthy(e.hSurf > Geo.H_SURF, "24 overlapping blocks coarsen the grid")
		local ratio = e.hSurf / Geo.H_SURF
		local rung = 0
		for r, factor in ipairs(Geo.H_LADDER) do
			if math.abs(ratio - factor) < 1e-12 then
				rung = r
			end
		end
		A.truthy(rung > 1, "a ladder factor: " .. ratio)
		A.eq(Dump.canonical(Sampling.exposure(parts)), Dump.canonical(e), "the same bits")
		-- over the kept parts: within the budget by the estimate, on samples as real as the estimate on Blocks, and one rung
		-- finer would not fit
		local function kept(i: number): boolean
			return e.kept[i]
		end
		A.truthy(ladderWork(parts, e.hSurf, kept) <= Geo.N_SURF_WORK, "within the budget: " .. ladderWork(parts, e.hSurf, kept))
		local finer = Geo.H_SURF * Geo.H_LADDER[rung - 1]
		A.truthy(ladderWork(parts, finer, kept) > Geo.N_SURF_WORK, "one rung finer does not fit: " .. ladderWork(parts, finer, kept))
		for _, h in ipairs({ e.hSurf, finer }) do
			local real = 0
			for i, p in ipairs(parts) do
				if e.kept[i] then
					real += Sampling.surfaceSamples(p, h).n * (1 + candidatesOf(parts, i, h, kept))
				end
			end
			A.eq(real, ladderWork(parts, h, kept), "real samples are the estimate on Blocks")
		end
		-- F5 stays at the base spacing
		A.eq(Sampling.exposure(H.prepared(Blueprints.get("F5").core)).hSurf, Geo.H_SURF)
		-- a planted budget: every smaller budget coarsens more, and the areas stay close
		local base = Sampling.exposure(H.prepared(Blueprints.get("F5").core))
		local tiny = H.plantedSampling({ N_SURF_WORK = 2000 }).exposure(H.prepared(Blueprints.get("F5").core))
		A.truthy(tiny.hSurf > base.hSurf, "coarser")
		A.truthy(tiny.surfSamples < base.surfSamples, "fewer samples")
		for i = 1, 5 do
			A.near(tiny.exposedKept[i], base.exposedKept[i], 0.15 * base.exposedKept[i], "part " .. i)
		end
	end)

	-- The header's words on what the estimate leaves out: 8 directions against a Block's 4 faces. 24 rods this tangled pass the
	-- verdicts' cap (TooComplex), so the measure is read with the cap lifted.
	t.it("§4.9 N_SURF_WORK holds by the estimate: thin cylinders sample about 2 × that", function()
		local rods: { any } = {}
		for i = 1, 24 do
			rods[i] = H.solid(i, "Cylinder", { 0.004 * ((i - 1) % 8), 2.5 + 0.0001 * i, 0.01 * ((i - 1) // 8) }, H.Z90, { 1.2, 0.02, 0.02 })
		end
		local parts = H.prepared({ parts = rods })
		A.truthy(Sampling.exposure(parts).capped, "past the cap")
		local e = H.plantedSampling({ VERDICT_WORK_MAX = math.huge }).exposure(parts)
		local function kept(i: number): boolean
			return e.kept[i]
		end
		local real = 0
		for i, p in ipairs(parts) do
			if e.kept[i] then
				real += Sampling.surfaceSamples(p, e.hSurf).n * (1 + candidatesOf(parts, i, e.hSurf, kept))
			end
		end
		A.truthy(ladderWork(parts, e.hSurf, kept) <= Geo.N_SURF_WORK, "the estimate fits")
		A.within(real / Geo.N_SURF_WORK, 1.7, 2.1, "real tests, of the budget")
	end)

	t.it("§4.9 sub-grid budget: when spent, a boundary patch keeps its centre verdict; each patch charges it", function()
		local base = H.solid(1, "Block", { 0, 1, 0 }, H.I, { 1, 0.4, 1 })
		local top = H.solid(2, "Block", { 0.017, 1.3, 0.023 }, H.I, { 0.33, 0.2, 0.33 })
		local list = { Shapes.prepare(base, 1), Shapes.prepare(top, 2) }
		local none = H.plantedSampling({ N_SUB_WORK = 0 }).exposure(list)
		A.eq(none.subSampled, 0, "no budget, no sub-grid")
		local full = Sampling.exposure(list)
		A.truthy(full.subSampled > 0)
		A.near(none.exposedKept[1], full.exposedKept[1], 0.05 * full.exposedKept[1], "the centre verdict is close")
		local small = H.plantedSampling({ N_SUB_WORK = 200 }).exposure(list)
		A.truthy(small.subSampled > 0, "some patches fit")
		A.truthy(small.subSampled * 20 <= 200, "a patch costs at least 4 + 16 tests: " .. small.subSampled)
	end)

	-- What exposure charges on Blocks when no tested sample has a patch near a hiding boundary (§4.9: a checkpoint can only
	-- fire where work is reported): N per part per rung of the measure's ladder; the verdict's units, which the exposure returns
	-- and Cover counts (each hider's model, its look over the N boxes, its reading); the measure, 4 per sample written and
	-- 1 + candidates per sample tested, every sample of every kept part.
	local function verdictUnits(parts: { any }): number
		local N = #parts
		local units = 0
		local models: { [number]: any } = {}
		local rank = Sampling.ranked(parts)
		for i, p in ipairs(parts) do
			local copy = false
			for j = 1, N do
				if j ~= i and Shapes.sameSolid(p, parts[j]) and rank[j] < rank[i] then
					copy = true
				end
			end
			if p.volume >= Geo.MIN_PART_VOLUME and not copy then
				models[i] = Cover.model(p)
				units += models[i].work
			end
		end
		for i in ipairs(parts) do
			if models[i] then
				local _, higher, hm = H.hidersOf(parts, i, models)
				local _, used = Cover.shown(models[i], hm, higher, Geo.ENCLOSED_EXPOSED_MAX * models[i].total, math.huge)
				units += Cover.UNITS_PER_BOX * N + used
			end
		end
		return units
	end
	local function chargedUnits(parts: { any }, e: any): number
		local N = #parts
		local function kept(j: number): boolean
			return e.kept[j]
		end
		local rungs = 0
		for r, factor in ipairs(Geo.H_LADDER) do
			if math.abs(e.hSurf - Geo.H_SURF * factor) < 1e-12 then
				rungs = r
			end
		end
		A.truthy(rungs > 0, "hSurf on the ladder")
		A.eq(e.verdictWork, verdictUnits(parts), "the verdict's units are Cover's")
		local total = N * N * rungs + e.verdictWork
		for i, p in ipairs(parts) do
			if e.kept[i] then
				local n = Sampling.surfaceSamples(p, e.hSurf).n
				total += 4 * n + n * (1 + candidatesOf(parts, i, e.hSurf, kept))
			end
		end
		return total
	end
	local function unitsOf(sampling: any, parts: { any }): (number, any)
		local units = 0
		local e = sampling.exposure(parts, function(n: number)
			units += n
		end)
		A.eq(e.subSampled, 0, "no patch near a boundary: the sum is exact")
		return units, e
	end
	local function block(id: number, x: number, y: number, size: number): any
		return H.part(id, "Blade", "Block", "Iron", { x, y, 0 }, H.I, { size, size, size })
	end
	-- A Block's model: 6 facets of 4 vertices, UNITS_PER_FACET 8 and 0.5 a vertex each (Cover's header)
	local BLOCK_MODEL = 6 * (8 + 4 * 0.5)

	t.it("§4.9 spend reports the verdict's work and the measure's: every rung, model, look, reading and sample, each at its own margin", function()
		-- two cubes across a gap: candidates at the measure's margin, past the verdict's reach (HIDE_OFFSET + 2·EPS_GEOM)
		local gap = 0.055
		A.truthy(gap < Geo.HIDE_OFFSET + Limits.CONTACT_TOL + Geo.H_SURF, "a candidate at the measure's margin")
		A.truthy(gap > Geo.HIDE_OFFSET + 2 * Geo.EPS_GEOM, "none at the verdict's")
		local a = block(1, 0, 2, 0.4)
		local b = block(2, 0.2, 2 + 0.4 + gap, 0.4)
		local two = H.prepared({ parts = { a, b } })
		local units, e = unitsOf(Sampling, two)
		A.deepEq(e.kept, { true, true })
		A.eq(units, chargedUnits(two, e), "two kept parts")
		A.eq(e.verdictWork, 2 * (BLOCK_MODEL + 2 / 8), "by hand: 2 models, 2 looks over 2 boxes, no reading")
		A.eq(units, 2 * 2 + 2 * (BLOCK_MODEL + 2 / 8) + 2 * (4 * 600 + 600 * 2), "by hand: 600 samples each, 1 candidate")
		-- a hidden block in each: a hider for the verdicts, not for the measure; its facets lie in the host's inner ball. A Dust speck
		-- and an exact copy have no model and no look: they cost the ladder its count of parts
		local full = H.prepared({ parts = { a, b, block(3, 0, 2, 0.06), block(4, 0.2, 2 + 0.4 + gap, 0.06),
			H.part(5, "Pommel", "Block", "Iron", { 2, 0.2, 2 }, H.I, { 0.05, 0.05, 0.05 }), block(6, 0, 2, 0.4) } })
		local unitsFull, filled = unitsOf(Sampling, full)
		A.deepEq(filled.kept, { true, true, false, false, false, false })
		A.eq(unitsFull, chargedUnits(full, filled), "kept, hidden, Dust and a copy")
		-- by hand: 4 models; 4 looks over 6 boxes; each cube's first facet (set up: 1 + 4 vertices × 2 × 0.5; its box against the
		-- hidden block's: 1/8; summed: 1/8) shows 2 % alone; each hidden block's 6 facets (set up; a box; the inner-ball test, 4
		-- vertices × 2 × 0.5) all lie in the inner ball
		local cube = 5 + 1 / 8 + 1 / 8
		local hidden = 6 * (5 + 1 / 8 + 4)
		A.eq(filled.verdictWork, 4 * BLOCK_MODEL + 4 * 6 / 8 + 2 * cube + 2 * hidden, "by hand: the verdict")
		A.eq(unitsFull, 6 * 6 + filled.verdictWork + 2 * (4 * 600 + 600 * 2), "by hand: the whole")
	end)

	t.it("§4.9 spend reports each rung tried, and the measure takes candidates at its own grid's margin, not the base's", function()
		-- 0.32 cubes: 6 cells at 0.06, 4 at 0.08. Across a gap the base spacing's margin misses: at 0.06 they are no candidates
		-- and 2 × 216 samples do not fit 400; at 0.08 they are, and (2 × 96) × 2 fit
		local gap = 0.097
		A.truthy(gap > Geo.HIDE_OFFSET + Limits.CONTACT_TOL + 0.06 and gap < Geo.HIDE_OFFSET + Limits.CONTACT_TOL + 0.08, "the gap is between the margins")
		local planted = H.plantedSampling({ N_SURF_WORK = 400 })
		local parts = H.prepared({ parts = { block(1, 0, 2, 0.32), block(2, 0.16, 2 + 0.32 + gap, 0.32) } })
		local units, e = unitsOf(planted, parts)
		A.eq(e.hSurf, 0.08, "the rung that fits")
		A.deepEq(e.kept, { true, true })
		A.eq(units, chargedUnits(parts, e))
		A.eq(units, 2 * 2 * 4 + 2 * (BLOCK_MODEL + 2 / 8) + 2 * (4 * 96 + 96 * 2), "by hand: 4 rungs, 1 candidate each on 96 samples")
	end)

	t.it("§4.9 spend reports the verdict's work as Cover counts it: a buried plate under a lid, 1 lid or 2", function()
		-- a plate buried in a host under a lid: its 6 facets read against both, the host's and the lid's readings against it
		local plate = H.solid(1, "Block", { 0, -0.01, 0 }, H.I, { 0.5, 0.02, 0.5 })
		local host = H.solid(2, "Block", { 0, -2, 0 }, H.I, { 4, 4, 4 })
		local lid = H.solid(3, "Block", { 0, 0.25, 0 }, H.I, { 4, 0.5, 4 })
		local function unitsWith(parts: { any }): (number, any)
			local units = 0
			local list = H.prepared({ parts = parts })
			local e = Sampling.exposure(list, function(n: number)
				units += n
			end)
			A.eq(e.verdictWork, verdictUnits(list), "the verdict's units are Cover's")
			return units, e
		end
		local without, before = unitsWith({ host, lid })
		local with, after = unitsWith({ plate, host, lid })
		A.deepEq(after.kept, { false, true, true })
		A.eq(after.hSurf, before.hSurf)
		-- the ladder's count of parts, then the verdict's units: the plate's model, its look and its reading, one more box in each
		-- look, and what the host's and the lid's readings do with it; the measure is the same (the plate is cleaned)
		local rungs = 0
		for r, factor in ipairs(Geo.H_LADDER) do
			if math.abs(after.hSurf - Geo.H_SURF * factor) < 1e-12 then
				rungs = r
			end
		end
		A.eq(with - without, (9 - 4) * rungs + after.verdictWork - before.verdictWork)
		A.truthy(after.verdictWork - before.verdictWork >= BLOCK_MODEL + 3 * 3 / 8 - 2 * 2 / 8 + 6 * 5, "the plate's model, the looks and its facets at least")
		-- 2 lids that meet on the plate's top: the seam between them is subtracted from the plate's top, a polygon at a time
		local right = H.solid(4, "Block", { 2.03125 + 0.0625, 0.25, 0 }, H.I, { 4, 0.5, 4 })
		local left = H.solid(3, "Block", { -2 + 0.0625, 0.25, 0 }, H.I, { 4, 0.5, 4 })
		local seamed = unitsWith({ plate, host, left, right })
		local plain = unitsWith({ plate, host, left })
		A.truthy(seamed > plain, "2 lids cost more than 1: " .. seamed .. " against " .. plain)
	end)

	t.it("§4.9 spend reports work, and a raising spend stops the call (a checkpoint may cancel)", function()
		local parts = H.prepared(Blueprints.get("F5").core)
		local total = 0
		Sampling.exposure(parts, function(n: number)
			total += n
		end)
		A.truthy(total > 1000, "work reported: " .. total)
		-- a part alone, with no patch to refine: each sample of the measure reports when it is written (4) and when it is
		-- tested (1), and the verdict's model comes on top
		for _, shape in ipairs(SHAPES) do
			local units = 0
			local alone = Sampling.exposure({ H.prepare(H.solid(1, shape, { 0, 2, 0 }, H.I, { 0.3, 0.4, 0.4 })) }, function(n: number)
				units += n
			end)
			A.truthy(units > 5 * alone.surfSamples, shape .. ": " .. units .. " units for " .. alone.surfSamples .. " samples")
		end
		local err = A.throws(function()
			Sampling.exposure(parts, function()
				error("CANCELLED")
			end)
		end, "CANCELLED")
		A.contains(err, "CANCELLED")
	end)

	t.it("P-DET, P-NOMUT, P-FINITE: exposure on the frozen fixtures, twice, bit for bit", function()
		for _, id in ipairs(Blueprints.order) do
			local core = Blueprints.get(id).core
			local a = Sampling.exposure(H.prepared(core))
			local b = Sampling.exposure(H.prepared(core))
			A.eq(Dump.canonical(a), Dump.canonical(b), id)
			H.finite(a, id)
			A.eq(a.hSurf, Geo.H_SURF, id .. " a fixture never hits the budget")
		end
	end)
end)
