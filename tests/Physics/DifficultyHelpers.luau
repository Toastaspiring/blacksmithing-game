--!strict
-- tests/Physics/DifficultyHelpers.luau — what the Physics specs of M3 share (T-EDG, T-DIF). Not a spec (the runner
-- loads *.spec.luau only). The factors' inputs are built here as Analyze's phases hold them, with no validation, so an
-- invalid design can be measured too, and each module can be tested on its own; Analyze.run plays the same steps.
--   measured(core)      the FactorContext and what it came from: the parts, the verdict and the measure
--                       (Sampling.exposure), ownership, the volume probes, the measure's rank, the contact graph as V3
--                       builds it (boxes within CONTACT_REACH, then Gjk.within), the edge on the parts in the measure's
--                       rank order, in the difficulty frame (MassProps.difficultyFrame)
--   set(m, sel)         a work set's part indices, WorkSet.select's ("All" or a list of slots)
--   factors(m, sel)     the 8 FactorValues of a work set
--   steps(m)            the enabled plan steps as Analyze.run's phase 7 plays them: WorkSet.select → Factors.measure →
--                       Difficulty.governing → Difficulty.step, a work set measured once; nil if a set is empty (D5)
--   inRange             T-DIF-01 on a step list: every x in [0, 1], every raw finite and ≥ 0, Thinness' and
--                       Asymmetry's at most 1, the factors in FactorId order; g, m and d on the 1e-4 grid
--   stepOf, valueOf     a step of a list by id; a factor of a list by id
--   inRankOrder, proto  a prototype blueprint with its parts in the verdict's rank order, the kept ones in the
--                       measure's, ids kept (Reference.spec's), and the prototype's run on it, measureInvalid
--   analyzeRequires     Physics/Analyze's requires as it names them: the real modules, but where a spec plants its own
--   plantedPhysics      MassProps, Factors, Difficulty and Analyze anew on planted Definitions (Materials, Steps,
--                       Tiers, CraftPlans; Drafts.planted), each handed the planted modules below it: P-ORDER, a
--                       planted plan
--   reordered           a Definitions catalog module loaded anew, its rows handed to Catalog.build in the given order
--   writings, written   the 24 writings of one Block (signed permutations of its local axes, det +1, as {perm, q}),
--                       and a part written one of those ways (rot·q, size permuted): the same solid (§5.2, §17.1 O11)

local A = require("../lib/Assert")
local Gen = require("../lib/Gen")
local Drafts = require("../Blueprint/Drafts")
local Build = require("../fixtures/Build")
local Balance = require("../../src/shared/Definitions/Balance")
local Catalog = require("../../src/shared/Definitions/Catalog")
local CraftPlans = require("../../src/shared/Definitions/CraftPlans")
local EquipmentTypes = require("../../src/shared/Definitions/EquipmentTypes")
local Limits = require("../../src/shared/Definitions/Limits")
local Materials = require("../../src/shared/Definitions/Materials")
local Steps = require("../../src/shared/Definitions/Steps")
local Tiers = require("../../src/shared/Definitions/Tiers")
local Types = require("../../src/shared/Definitions/Types")
local Versions = require("../../src/shared/Definitions/Versions")
local Quantize = require("../../src/shared/Util/Quantize")
local Schema = require("../../src/shared/Blueprint/Schema")
local WorkSet = require("../../src/shared/Blueprint/WorkSet")
local Difficulty = require("../../src/shared/Physics/Difficulty")
local Edge = require("../../src/shared/Physics/Edge")
local Factors = require("../../src/shared/Physics/Factors")
local Gjk = require("../../src/shared/Physics/Gjk")
local MassProps = require("../../src/shared/Physics/MassProps")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

-- Through a cast, so luau-lsp stays out of the prototype's loose types: it is reference data, not game code.
local Proto: any = (require :: any)("../../docs/spec/prototypes/S2/v2/analyze")

type Prepared = Shapes.Prepared
type FactorContext = Factors.FactorContext
type FactorValue = Factors.FactorValue
type StepAnalysis = Difficulty.StepAnalysis

export type Measured = {
	core: any,
	ctx: FactorContext,
	parts: { Prepared },
	kept: { boolean },
	edge: Edge.EdgeProfile,
}

local SWORD: any = EquipmentTypes.get("Sword")
local GEOMETRY = SWORD.geometry
local CONTACT_REACH = Sampling.CONTACT_REACH

local D = {}

D.GEOMETRY = GEOMETRY

local function rankOfSlot(): { [string]: number }
	local out: { [string]: number } = {}
	for _, slot in ipairs(SWORD.slots) do
		out[slot.id] = slot.rank
	end
	return out
end

-- V3's contact graph: parts i and j within CONTACT_REACH (CONTACT_TOL + 1e-9).
local function touchingOf(parts: { Prepared }): { { boolean } }
	local N = #parts
	local touching: { { boolean } } = table.create(N)
	for i = 1, N do
		touching[i] = table.create(N, false)
	end
	for i = 1, N - 1 do
		for j = i + 1, N do
			local a, b = parts[i], parts[j]
			if Shapes.aabbOverlap(a, b, CONTACT_REACH) and (Gjk.within(a, b, CONTACT_REACH)) then
				touching[i][j], touching[j][i] = true, true
			end
		end
	end
	return touching
end

function D.measured(core: any): Measured
	local parts: { Prepared } = {}
	for i, p in ipairs(core.parts) do
		parts[i] = Shapes.prepare(p, i)
	end
	local exposure = Sampling.exposure(parts)
	assert(not exposure.capped, "DifficultyHelpers: a design past the verdicts' cap has no measure")
	local kept = exposure.kept
	local owned = MassProps.ownership(parts, kept, rankOfSlot())
	local probes = Sampling.volumeProbes(parts, kept)
	local rank, byRank = Sampling.measureRanked(parts, kept)
	local keptByRank: { boolean } = table.create(#byRank, false)
	for r, p in ipairs(byRank) do
		keptByRank[r] = kept[p.index]
	end
	local point, axis = MassProps.difficultyFrame(byRank, keptByRank, GEOMETRY.gripSlot)
	local edge = Edge.profile(byRank, keptByRank, GEOMETRY, point, axis)
	local ctx: FactorContext = {
		parts = parts,
		rank = rank,
		probes = probes,
		exposure = exposure,
		owned = owned,
		touching = touchingOf(parts),
		edgeLength = edge.length,
		geometry = GEOMETRY,
	}
	return { core = core, ctx = ctx, parts = parts, kept = kept, edge = edge }
end

function D.set(m: Measured, selector: any): { number }
	return WorkSet.select(m.core.parts, m.kept, selector)
end

function D.factors(m: Measured, selector: any, factors: any?): { FactorValue }
	return ((factors or Factors) :: any).measure(m.ctx, D.set(m, selector))
end

-- modules: planted Factors and Difficulty, where a spec hands them other Definitions.
function D.steps(m: Measured, modules: { factors: any?, difficulty: any? }?): { StepAnalysis }?
	local factors: any = (modules and modules.factors) or Factors
	local difficulty: any = (modules and modules.difficulty) or Difficulty
	local cache: { [string]: { FactorValue } } = {} -- keyed by selector, never iterated
	local out: { StepAnalysis } = {}
	for _, row in ipairs(difficulty.planSteps("Sword")) do
		local set = D.set(m, row.worksOn)
		if #set == 0 then
			return nil
		end
		local key = if row.worksOn == "All" then "All" else table.concat(row.worksOn, "+")
		local values = cache[key]
		if values == nil then
			values = factors.measure(m.ctx, set)
			cache[key] = values
		end
		table.insert(out, difficulty.step(row.step, values, difficulty.governing(m.parts, set)))
	end
	return out
end

local function onGrid(v: number): boolean
	return v >= 0 and v <= 1 and Difficulty.q(v) == v
end

function D.inRange(steps: { StepAnalysis }, what: string)
	for _, s in ipairs(steps) do
		A.truthy(onGrid(s.g) and onGrid(s.m) and onGrid(s.d),
			string.format("%s %s: g %.17g, m %.17g, d %.17g", what, s.step, s.g, s.m, s.d))
		A.eq(#s.factors, #Factors.ORDER, what .. " factors")
		for k, v in ipairs(s.factors) do
			local label = what .. " " .. s.step .. " " .. v.factor
			A.eq(v.factor, Factors.ORDER[k], label .. " in FactorId order")
			A.finite(v.raw, label)
			A.truthy(v.raw >= 0, label .. " raw ≥ 0: " .. v.raw)
			if v.factor == "Thinness" or v.factor == "Asymmetry" then
				A.truthy(v.raw <= 1, label .. " raw ≤ 1: " .. v.raw)
			end
			A.within(v.x, 0, 1, label .. " x")
		end
	end
end

function D.stepOf(steps: { StepAnalysis }, id: string): StepAnalysis
	for _, s in ipairs(steps) do
		if s.step == id then
			return s
		end
	end
	return A.fail("no step " .. id)
end

function D.valueOf(values: { FactorValue }, id: string): FactorValue
	for _, v in ipairs(values) do
		if v.factor == id then
			return v
		end
	end
	return A.fail("no factor " .. id)
end

-- The prototype's lower index keeps a coincident face, in its verdict and in its measure alike, where the build's
-- verdict ranks from the world's planes and its measure from the kept parts' ties (§4.4): the parts in the verdict's
-- rank order, the kept ones among their places in the measure's (Reference.spec's).
function D.inRankOrder(b: any): any
	local list: { Prepared } = {}
	for i, part in ipairs(b.parts) do
		list[i] = Shapes.prepare(part, i)
	end
	local kept = Sampling.exposure(list).kept
	local _, verdictOrder = Sampling.ranked(list)
	local _, measureOrder = Sampling.measureRanked(list, kept)
	local keptOrder: { Prepared } = {}
	for _, p in ipairs(measureOrder) do
		if kept[p.index] then
			table.insert(keptOrder, p)
		end
	end
	local parts: { any } = {}
	local k = 0
	for r, p in ipairs(verdictOrder) do
		local q = p
		if kept[p.index] then
			k += 1
			q = keptOrder[k]
		end
		parts[r] = b.parts[q.index]
	end
	return { name = b.name, parts = parts }
end

function D.proto(b: any): any
	return Proto.run(D.inRankOrder(b), { measureInvalid = true })
end

function D.analyzeRequires(planted: { [string]: any }?): { [string]: any }
	local modules: { [string]: any } = {
		["../Definitions/Types"] = Types,
		["../Definitions/EquipmentTypes"] = EquipmentTypes,
		["../Definitions/Limits"] = Limits,
		["../Definitions/Versions"] = Versions,
		["../Blueprint/Schema"] = Schema,
		["../Blueprint/WorkSet"] = WorkSet,
		["./Difficulty"] = Difficulty,
		["./Edge"] = Edge,
		["./Factors"] = Factors,
		["./Gjk"] = Gjk,
		["./MassProps"] = MassProps,
		["./Sampling"] = Sampling,
		["./Shapes"] = Shapes,
	}
	local overrides: { [string]: any } = planted or {}
	for spec, m in overrides do
		assert(modules[spec] ~= nil, "Physics/Analyze requires no " .. spec)
		modules[spec] = m
	end
	return modules
end

export type Defs = { materials: any?, steps: any?, tiers: any?, craftPlans: any? }
export type Planted = { massProps: any, factors: any, difficulty: any, analyze: any }

function D.plantedPhysics(defs: Defs): Planted
	local materials = defs.materials or Materials
	local massProps = Drafts.planted("src/shared/Physics/MassProps.luau", {
		["../Definitions/Balance"] = Balance,
		["../Definitions/Types"] = Types,
		["../Definitions/Materials"] = materials,
		["../Blueprint/Schema"] = Schema,
		["./Gjk"] = Gjk,
		["./Sampling"] = Sampling,
		["./Shapes"] = Shapes,
	})
	local factors = Drafts.planted("src/shared/Physics/Factors.luau", {
		["../Definitions/Balance"] = Balance,
		["../Definitions/Types"] = Types,
		["../Definitions/Materials"] = materials,
		["./Edge"] = Edge,
		["./MassProps"] = massProps,
		["./Sampling"] = Sampling,
		["./Shapes"] = Shapes,
	})
	local difficulty = Drafts.planted("src/shared/Physics/Difficulty.luau", {
		["../Definitions/CraftPlans"] = defs.craftPlans or CraftPlans,
		["../Definitions/Types"] = Types,
		["../Definitions/Materials"] = materials,
		["../Definitions/Steps"] = defs.steps or Steps,
		["../Definitions/Tiers"] = defs.tiers or Tiers,
		["../Util/Quantize"] = Quantize,
		["./Factors"] = factors,
		["./Shapes"] = Shapes,
	})
	local analyze = Drafts.planted("src/shared/Physics/Analyze.luau",
		D.analyzeRequires({ ["./MassProps"] = massProps, ["./Factors"] = factors, ["./Difficulty"] = difficulty }))
	return { massProps = massProps, factors = factors, difficulty = difficulty, analyze = analyze }
end

function D.reordered(path: string, order: { number }): any
	return Drafts.planted(path, {
		["./Catalog"] = {
			build = function(rows: { any }): any
				return Catalog.build(Drafts.rows(rows, order))
			end,
			deepFreeze = Catalog.deepFreeze,
		},
		["./Types"] = Types,
	})
end

export type Writing = { perm: { number }, q: { number } }

-- The unit quaternion of a rotation matrix m (rows), Shepperd's method.
local function quatOf(m: { { number } }): { number }
	local tr = m[1][1] + m[2][2] + m[3][3]
	if tr > 0 then
		local s = math.sqrt(tr + 1) * 2
		return { (m[3][2] - m[2][3]) / s, (m[1][3] - m[3][1]) / s, (m[2][1] - m[1][2]) / s, s / 4 }
	elseif m[1][1] > m[2][2] and m[1][1] > m[3][3] then
		local s = math.sqrt(1 + m[1][1] - m[2][2] - m[3][3]) * 2
		return { s / 4, (m[1][2] + m[2][1]) / s, (m[1][3] + m[3][1]) / s, (m[3][2] - m[2][3]) / s }
	elseif m[2][2] > m[3][3] then
		local s = math.sqrt(1 + m[2][2] - m[1][1] - m[3][3]) * 2
		return { (m[1][2] + m[2][1]) / s, s / 4, (m[2][3] + m[3][2]) / s, (m[1][3] - m[3][1]) / s }
	end
	local s = math.sqrt(1 + m[3][3] - m[1][1] - m[2][2]) * 2
	return { (m[1][3] + m[3][1]) / s, (m[2][3] + m[3][2]) / s, s / 4, (m[2][1] - m[1][2]) / s }
end

-- Writing k maps new local axis j to ± old local axis perm[j] (V1's writings.luau).
function D.writings(): { Writing }
	local out: { Writing } = {}
	for _, perm in { { 1, 2, 3 }, { 1, 3, 2 }, { 2, 1, 3 }, { 2, 3, 1 }, { 3, 1, 2 }, { 3, 2, 1 } } do
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				for sz = -1, 1, 2 do
					local signs = { sx, sy, sz }
					local m = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
					for j = 1, 3 do
						m[perm[j]][j] = signs[j]
					end
					local det = m[1][1] * (m[2][2] * m[3][3] - m[2][3] * m[3][2])
						- m[1][2] * (m[2][1] * m[3][3] - m[2][3] * m[3][1]) + m[1][3] * (m[2][1] * m[3][2] - m[2][2] * m[3][1])
					if det > 0 then
						table.insert(out, { perm = perm, q = quatOf(m) })
					end
				end
			end
		end
	end
	assert(#out == 24, "24 writings")
	return out
end

-- part written another way: a fresh part, the same solid.
function D.written(part: any, w: Writing): any
	local out = Build.copy(part)
	out.rot = Gen.hemisphere(Gen.mul(part.rot, w.q))
	out.size = { part.size[w.perm[1]], part.size[w.perm[2]], part.size[w.perm[3]] }
	return out
end

return table.freeze(D)
