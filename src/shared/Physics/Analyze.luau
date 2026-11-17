--!strict
-- Physics/Analyze (SPEC §4.1, §4.2, §4.7, §4.9; owner S2): orchestration, validation, budgets and checkpoints, and the
-- Analysis types (§4.7) everything above Physics reads. Input: a canonical BlueprintCore (Pipeline asserts it, §4.8);
-- rules come from Definitions for core.type. Pure, and no module-level state: `Analyze.run` is re-entrant and its
-- checkpoint may raise to cancel a stale run (§4.9).
--
--   quick(core, opts)  V1–V2, every edit (Pipeline.quick). opts.connectivity adds V3 and the floating components, for
--                      the editor's live outline (§11.12): then the list holds V1, V2 and V3 errors together, because a
--                      part dragged out of the hitbox must not hide what floats.
--   run(core, opts)    the whole pipeline (§4.1):
--     1 prepare, QUICK        V1 slot counts, V2 containment; errors stop here, whatever measureInvalid says
--     2 V3, V4                the contact graph (AABB broad phase, then GJK within CONTACT_TOL) and the blade's side of
--                             the grip, in the frame of every Grip part (MassProps.validationFrame): no verdict yet
--     3 exposure, CLEAN, V5   a required slot keeps a kept part; invalid stops here unless opts.measureInvalid. Verdicts
--                             past VERDICT_WORK_MAX stop it before V5 as TooComplex, measured never: there is no verdict
--     4 MASS PROPERTIES       owned volumes, mass, COM, the physics frame and guard line of the kept parts (§4.5: a
--                             cleaned part steers nothing), balance, reach
--     5 volume probes         Thinness and Asymmetry measure on them
--     6 EDGE                  the difficulty frame (§4.5) and the edge (§4.6) on the parts in the measure's rank order
--                             (Sampling.measureRanked, §17.2): physics.edgeLength, physics.cutIndex, budget.edgeCell
--     7 FACTORS, STEPS        per enabled CraftPlans step, in plan order: its work set (Blueprint/WorkSet), the 8
--                             factors once per distinct set (Physics/Factors), then g, m, d and the tiers
--                             (Physics/Difficulty). A step whose set is empty leaves steps nil, the edge measured; on
--                             the Sword's plan only measureInvalid reaches one (V5 keeps a striking part)
--
-- Validity (§4.2): every error of the first failing stage (quick, then full) is returned, in rule then part order;
-- valid ⇔ none. Main component = the most Grip volume, else the largest volume, else the lowest index. Each other
-- component reports its closest pair to the main one: {partIds, gap, dir, nearestPartId}, with dir moving it toward the
-- main component (S6's "Snap to touch").
--
-- Checkpoints: between phases and once CHECK_UNITS work units have been reported since the last (one unit ≈ one shape
-- query; Cover reports once 256 have built up, a step of work at most past that, but for a test that ends early, which
-- charges the lines it skipped in its report: a few thousand units, 1,088 at most on the fixtures, the attack designs and
-- the worst designs), only at top-level loop points, never inside a sort comparator.
-- budget fields of a phase that did not run are 0.

local DT = require("../Definitions/Types")
local EquipmentTypes = require("../Definitions/EquipmentTypes")
local Limits = require("../Definitions/Limits")
local Versions = require("../Definitions/Versions")
local Schema = require("../Blueprint/Schema")
local WorkSet = require("../Blueprint/WorkSet")
local Difficulty = require("./Difficulty")
local Edge = require("./Edge")
local Factors = require("./Factors")
local Gjk = require("./Gjk")
local MassProps = require("./MassProps")
local Sampling = require("./Sampling")
local Shapes = require("./Shapes")

type Prepared = Shapes.Prepared
type Spend = Sampling.Spend
type Vec3 = Schema.Vec3

-- M3's types live in the modules that produce them (§1.3); Analyze names them for everything above Physics (§4.7).
export type Vec2 = Edge.Vec2 -- {x, y} array, blueprint XY
export type EdgeChain = Edge.EdgeChain
export type EdgeProfile = Edge.EdgeProfile
export type FactorValue = Factors.FactorValue
export type StepAnalysis = Difficulty.StepAnalysis

export type ValidationCode =
	"SlotMissing"
	| "SlotTooMany"
	| "OutOfHitbox"
	| "Disconnected"
	| "BladeNotAboveGrip"
	| "TooComplex"
export type ValidationError = { code: ValidationCode, partId: number?, slot: DT.SlotId?, reason: "Cleaned"? }
export type FloatingComponent = { partIds: { number }, gap: number, dir: Vec3, nearestPartId: number }
export type ValidationResult = { ok: boolean, errors: { ValidationError }, components: { FloatingComponent } }
export type PhysicsReport = {
	mass: number,
	volume: number,
	com: Vec3,
	gripPoint: Vec3,
	gripAxis: Vec2,
	guardPos: number,
	balance: number,
	balanceFromHand: number,
	reach: number,
	bladeLength: number,
	totalLength: number,
	comOffAxis: number,
	edgeLength: number,
	cutIndex: number,
	kept: { boolean }, -- per part, in blueprint order
	ownedVolume: { number }, -- per part, in blueprint order
}
export type CleanedPart = { partId: number, reason: "Dust" | "Enclosed" }
export type AnalysisBudget = { hSurf: number, hVol: number, edgeCell: number, surfSamples: number, volSamples: number }
export type Analysis = {
	balanceVersion: number,
	validation: ValidationResult,
	cleaned: { CleanedPart },
	physics: PhysicsReport?, -- nil while invalid (unless opts.measureInvalid got it measured)
	edge: EdgeProfile?,
	steps: { StepAnalysis }?,
	budget: AnalysisBudget,
}
export type AnalyzeOptions = { checkpoint: (() -> ())?, measureInvalid: boolean? }

local sqrt = math.sqrt

local CONTACT_TOL = Limits.CONTACT_TOL
local EPS_CONTAIN = Limits.EPS_CONTAIN

local CHECK_UNITS = 500 -- §16.18: checkpoint cadence, not outcome-affecting
local UNITS_PER_CONTACT_TEST = 20 -- one GJK query with early outs
local UNITS_PER_DISTANCE = 40 -- one converged GJK query

local function noSpend(_: number) end

local function problem(code: ValidationCode, partId: number?, slot: DT.SlotId?, reason: "Cleaned"?): ValidationError
	return { code = code, partId = partId, slot = slot, reason = reason }
end

-- The Definitions row of core.type and the rank of its slots. Canonical data always has both; anything else is a bug.
local function rulesOf(core: Schema.BlueprintCore): (DT.EquipmentTypeDef, { [string]: number })
	local typeDef = EquipmentTypes.get(core.type)
	if typeDef == nil then
		error("Analyze: unknown equipment type " .. tostring(core.type), 3)
	end
	local rankOf: { [string]: number } = {}
	for _, slot in ipairs(typeDef.slots) do
		rankOf[slot.id] = slot.rank
	end
	return typeDef, rankOf
end

local function prepareAll(core: Schema.BlueprintCore, rankOf: { [string]: number }): { Prepared }
	local list = core.parts
	local parts: { Prepared } = table.create(#list)
	for i = 1, #list do
		if rankOf[list[i].slot] == nil then
			error("Analyze: part " .. tostring(list[i].id) .. " has the slot " .. tostring(list[i].slot)
				.. ", not one of its type's", 3)
		end
		parts[i] = Shapes.prepare(list[i], i)
	end
	return parts
end

-- ── quick stage: V1, V2 ───────────────────────────────────────────────────────────────────────────────────────────

local function quickErrors(typeDef: DT.EquipmentTypeDef, parts: { Prepared }): { ValidationError }
	local errors: { ValidationError } = {}
	for _, slot in ipairs(typeDef.slots) do
		local count = 0
		for i = 1, #parts do
			if parts[i].slot == slot.id then
				count += 1
			end
		end
		if count < slot.min then
			table.insert(errors, problem("SlotMissing", nil, slot.id))
		elseif count > slot.max then
			table.insert(errors, problem("SlotTooMany", nil, slot.id))
		end
	end
	local lo, hi = typeDef.geometry.hitboxMin, typeDef.geometry.hitboxMax
	local e = EPS_CONTAIN
	for i = 1, #parts do
		local p = parts[i]
		if p.minx < lo[1] - e or p.miny < lo[2] - e or p.minz < lo[3] - e or p.maxx > hi[1] + e or p.maxy > hi[2] + e
			or p.maxz > hi[3] + e
		then
			table.insert(errors, problem("OutOfHitbox", p.id))
		end
	end
	return errors
end

-- ── V3: the contact graph ─────────────────────────────────────────────────────────────────────────────────────────

type Connectivity = {
	touching: { { boolean } }, -- touching[i][j]: parts i and j are within CONTACT_TOL (Joints, §5.2)
	errors: { ValidationError }, -- Disconnected per part outside the main component, in part order
	components: { FloatingComponent }, -- by lowest part index
}

local function connectivity(parts: { Prepared }, gripSlot: DT.SlotId, spend: Spend): Connectivity
	local N = #parts
	local touching: { { boolean } } = table.create(N)
	local parent: { number } = table.create(N, 0)
	for i = 1, N do
		touching[i] = table.create(N, false)
		parent[i] = i
	end
	local function root(i: number): number
		while parent[i] ~= i do
			parent[i] = parent[parent[i]]
			i = parent[i]
		end
		return i
	end
	for i = 1, N - 1 do
		local a = parts[i]
		for j = i + 1, N do
			local b = parts[j]
			if Shapes.aabbOverlap(a, b, CONTACT_TOL) then
				if (Gjk.within(a, b, CONTACT_TOL)) then
					touching[i][j], touching[j][i] = true, true
					local ri, rj = root(i), root(j)
					if ri < rj then -- the lowest index is each component's root
						parent[rj] = ri
					elseif rj < ri then
						parent[ri] = rj
					end
				end
				spend(UNITS_PER_CONTACT_TEST)
			end
		end
	end

	-- the main component: the most Grip volume, else the largest volume, else the lowest index
	local gripVolume: { number } = table.create(N, 0)
	local totalVolume: { number } = table.create(N, 0)
	for i = 1, N do
		local r = root(i)
		totalVolume[r] += parts[i].volume
		if parts[i].slot == gripSlot then
			gripVolume[r] += parts[i].volume
		end
	end
	local main = 0
	for i = 1, N do
		if root(i) == i then
			if main == 0 or gripVolume[i] > gripVolume[main]
				or (gripVolume[i] == gripVolume[main] and totalVolume[i] > totalVolume[main])
			then
				main = i
			end
		end
	end

	local components: { FloatingComponent } = {}
	for i = 1, N do
		if root(i) == i and i ~= main then
			local ids: { number } = {}
			local gap, vx, vy, vz, nearest = math.huge, 0, 0, 0, 0
			for f = 1, N do
				if root(f) == i then
					table.insert(ids, parts[f].id)
					for m = 1, N do
						if root(m) == main then
							local d, x, y, z = Gjk.distance(parts[f], parts[m])
							spend(UNITS_PER_DISTANCE)
							if d < gap then
								gap, vx, vy, vz, nearest = d, x, y, z, parts[m].id
							end
						end
					end
				end
			end
			local l = sqrt(vx * vx + vy * vy + vz * vz)
			local dir: Vec3 = if l > 0 then { -vx / l, -vy / l, -vz / l } else { 0, 0, 0 }
			table.insert(components, { partIds = ids, gap = gap, dir = dir, nearestPartId = nearest })
		end
	end
	local errors: { ValidationError } = {}
	for i = 1, N do
		if root(i) ~= main then
			table.insert(errors, problem("Disconnected", parts[i].id))
		end
	end
	return { touching = touching, errors = errors, components = components }
end

-- V4: the volume-weighted centroid of all parts of the striking slot lies beyond the grip point along the grip axis,
-- both of every Grip part (MassProps.validationFrame).
local function bladeAboveGrip(parts: { Prepared }, strikingSlot: DT.SlotId, gripPoint: Vec3, gripAxis: Vec2): boolean
	local volume, moment = 0, 0
	for i = 1, #parts do
		local p = parts[i]
		if p.slot == strikingSlot then
			volume += p.volume
			moment += p.volume * ((p.gx - gripPoint[1]) * gripAxis[1] + (p.gy - gripPoint[2]) * gripAxis[2])
		end
	end
	return volume <= 0 or moment / volume > 0
end

-- V5: each required slot keeps a kept part, or SlotMissing{slot, reason = "Cleaned"}.
local function cleanedSlotErrors(typeDef: DT.EquipmentTypeDef, parts: { Prepared },
	kept: { boolean }): { ValidationError }
	local errors: { ValidationError } = {}
	for _, slot in ipairs(typeDef.slots) do
		if slot.required then
			local any = false
			for i = 1, #parts do
				if parts[i].slot == slot.id and kept[i] then
					any = true
					break
				end
			end
			if not any then
				table.insert(errors, problem("SlotMissing", nil, slot.id, "Cleaned"))
			end
		end
	end
	return errors
end

local function appendAll(list: { ValidationError }, more: { ValidationError })
	for i = 1, #more do
		table.insert(list, more[i])
	end
end

-- ── public ────────────────────────────────────────────────────────────────────────────────────────────────────────

local Analyze = {}

Analyze.CHECK_UNITS = CHECK_UNITS

function Analyze.quick(core: Schema.BlueprintCore, opts: { connectivity: boolean? }?): ValidationResult
	local typeDef, rankOf = rulesOf(core)
	local parts = prepareAll(core, rankOf)
	local errors = quickErrors(typeDef, parts)
	local components: { FloatingComponent } = {}
	if opts ~= nil and opts.connectivity == true then
		local graph = connectivity(parts, typeDef.geometry.gripSlot, noSpend)
		appendAll(errors, graph.errors)
		components = graph.components
	end
	return { ok = #errors == 0, errors = errors, components = components }
end

function Analyze.run(core: Schema.BlueprintCore, opts: AnalyzeOptions?): Analysis
	local checkpoint = if opts then opts.checkpoint else nil
	local measureInvalid = if opts then opts.measureInvalid == true else false

	-- work units → checkpoints; per run, so a cancelled run leaves nothing behind
	local units = 0
	local function spend(n: number)
		units += n
		if units >= CHECK_UNITS then
			units = 0
			if checkpoint then
				checkpoint()
			end
		end
	end
	local function phase()
		units = 0
		if checkpoint then
			checkpoint()
		end
	end

	local budget: AnalysisBudget = { hSurf = 0, hVol = 0, edgeCell = 0, surfSamples = 0, volSamples = 0 }
	local balanceVersion = Versions.BALANCE_VERSION

	-- 1 prepare, quick stage
	local typeDef, rankOf = rulesOf(core)
	local geometry = typeDef.geometry
	local parts = prepareAll(core, rankOf)
	local quickFound = quickErrors(typeDef, parts)
	if #quickFound > 0 then
		return {
			balanceVersion = balanceVersion,
			validation = { ok = false, errors = quickFound, components = {} },
			cleaned = {},
			physics = nil,
			edge = nil,
			steps = nil,
			budget = budget,
		}
	end
	phase()

	-- 2 V3 connectivity, V4 orientation (before the verdict: every Grip part's frame)
	local graph = connectivity(parts, geometry.gripSlot, spend)
	local errors = graph.errors
	local v4Point, v4Axis = MassProps.validationFrame(parts, geometry.gripSlot)
	if not bladeAboveGrip(parts, geometry.strikingSlot, v4Point, v4Axis) then
		table.insert(errors, problem("BladeNotAboveGrip"))
	end
	phase()

	-- 3 exposure, cleaning, V5. Past the verdicts' cap there is no verdict to clean or measure by: TooComplex
	local exposure = Sampling.exposure(parts, spend)
	if exposure.capped then
		table.insert(errors, problem("TooComplex"))
		return {
			balanceVersion = balanceVersion,
			validation = { ok = false, errors = errors, components = graph.components },
			cleaned = {},
			physics = nil,
			edge = nil,
			steps = nil,
			budget = budget,
		}
	end
	budget.hSurf, budget.surfSamples = exposure.hSurf, exposure.surfSamples
	local kept = exposure.kept
	local cleaned: { CleanedPart } = exposure.cleaned
	appendAll(errors, cleanedSlotErrors(typeDef, parts, kept))
	local validation: ValidationResult = { ok = #errors == 0, errors = errors, components = graph.components }
	if not validation.ok and not measureInvalid then
		return {
			balanceVersion = balanceVersion,
			validation = validation,
			cleaned = cleaned,
			physics = nil,
			edge = nil,
			steps = nil,
			budget = budget,
		}
	end
	phase()

	-- 4 mass properties, in the physics frame of the kept Grip parts (a cleaned part steers nothing, §4.5)
	local owned = MassProps.ownership(parts, kept, rankOf, spend)
	local gripPoint, gripAxis = MassProps.physicsFrame(parts, kept, geometry.gripSlot)
	local mass = MassProps.report(parts, kept, owned, geometry, gripPoint, gripAxis)
	local physics: PhysicsReport = {
		mass = mass.mass,
		volume = mass.volume,
		com = mass.com,
		gripPoint = mass.gripPoint,
		gripAxis = mass.gripAxis,
		guardPos = mass.guardPos,
		balance = mass.balance,
		balanceFromHand = mass.balanceFromHand,
		reach = mass.reach,
		bladeLength = mass.bladeLength,
		totalLength = mass.totalLength,
		comOffAxis = mass.comOffAxis,
		edgeLength = 0, -- phase 6: the main chain's length (§4.6)
		cutIndex = 0, -- phase 6: Edge.cutIndex(bladeLength, the edge's bladeMeanThickness)
		kept = kept,
		ownedVolume = mass.ownedVolume,
	}
	phase()

	-- 5 volume probes, the samples Thinness and Asymmetry measure on
	local probes = Sampling.volumeProbes(parts, kept, spend)
	budget.hVol, budget.volSamples = probes.h, probes.total
	phase()

	-- 6 the difficulty frame and the EDGE, walking the parts in the measure's rank order (§17.2), kept indexed alike
	local N = #parts
	local rank, byRank = Sampling.measureRanked(parts)
	local keptByRank: { boolean } = table.create(N, false)
	for r = 1, N do
		keptByRank[r] = kept[byRank[r].index]
	end
	local framePoint, frameAxis = MassProps.difficultyFrame(byRank, keptByRank, geometry.gripSlot)
	local edge = Edge.profile(byRank, keptByRank, geometry, framePoint, frameAxis, spend)
	physics.edgeLength = edge.length
	physics.cutIndex = Edge.cutIndex(physics.bladeLength, edge.bladeMeanThickness)
	budget.edgeCell = edge.cell
	phase()

	-- 7 FACTORS once per distinct work set, STEPS in plan order; every set chosen first, so an empty one (steps nil,
	-- §4.7) costs no factor work
	local plan = Difficulty.planSteps(core.type)
	local sets: { { number } } = table.create(#plan)
	local empty = false
	for k = 1, #plan do
		sets[k] = WorkSet.select(core.parts, kept, plan[k].worksOn)
		empty = empty or #sets[k] == 0
	end
	local steps: { StepAnalysis }? = nil
	if not empty then
		local ctx: Factors.FactorContext = {
			parts = parts,
			rank = rank,
			probes = probes,
			exposure = exposure,
			owned = owned,
			touching = graph.touching,
			edgeLength = edge.length,
			geometry = geometry,
		}
		local measured: { [string]: { FactorValue } } = {} -- by selector, looked up and never iterated
		local list: { StepAnalysis } = table.create(#plan)
		for k = 1, #plan do
			local row = plan[k]
			local selector = row.worksOn
			local key = if type(selector) == "table" then table.concat(selector, "+") else selector
			local values = measured[key]
			if values == nil then
				values = (Factors.measure(ctx, sets[k], spend))
				measured[key] = values
				phase()
			end
			local material: DT.MaterialId = Difficulty.governing(parts, sets[k]) :: DT.MaterialId -- the set has parts
			list[k] = Difficulty.step(row.step, values, material)
		end
		steps = list
	end
	return {
		balanceVersion = balanceVersion,
		validation = validation,
		cleaned = cleaned,
		physics = physics,
		edge = edge,
		steps = steps,
		budget = budget,
	}
end

return table.freeze(Analyze)
