--!strict
-- Definitions/Validate (SPEC §2.3, §16.3; owner S1, owners append their checks): the Definitions self-checks.
-- validateAll runs at server boot (non-empty → Log ERROR and the Router answers every request with
-- E_SERVER_CLOSING, §1.5), on the client (warn) and in Lune (== {}). Checks from higher layers arrive through
-- `extra` (Main.server, Main.client and the tests pass S4's Plan.validateDefs, §7.1): Definitions requires nothing
-- above it. An extra check that raises is reported as a problem, never rethrown.
--
--   Validate.validateAll(extra?)  check(current()) followed by each extra check's problems
--   Validate.check(bundle)        the base checks D1–D7 on a bundle of raw rows; total: a malformed bundle gives
--                                 problems, never an error (the tests plant one error per check this way)
--   Validate.current()            the bundle of the shipped Definitions
-- Each problem is one line "<check> <module>: <what>", e.g. "D1 Materials: duplicate id Iron", in check order.
--
-- Base checks (§2.3), plus the owners' columns:
--   D1 ids PascalCase and unique, `order` finite, unique and ascending, `enabled` boolean, per catalog; Tiers and
--      Rarities `order` = 1..n
--   D2 every reference resolves, and enabled rows reference only enabled rows: Steps.family → MinigameFamilies,
--      Tiers.rarityCap → Rarities, Materials.allowedSlots → the slots of the equipment types
--   D3 enabled tiers and rarities form `order` prefixes; Normal (the first tier) dMin = 0, dMin(k) = dMax(k−1),
--      dMin < dMax, last dMax = 1
--   D4 materials: class known, density > 0, hardness and toughness integers 0–100, reflectance in [0, 1],
--      robloxMaterial in KNOWN_PART_MATERIALS (the Roblox-bound boot also asserts Enum.Material[name]); every
--      `color` (materials, tiers, rarities) 3 integers 0–255
--   D5 equipment types: slot ids unique, ≥ 1 required slot, 0 ≤ min ≤ max ≤ MAX_PARTS with required ⇔ min ≥ 1,
--      ranks unique integers, partsMin ≤ partsMax ≤ MAX_PARTS, hitboxMin < hitboxMax within ±POS_ABS_MAX, the
--      striking, grip and guard slots are slots of the type, thicknessAxis a unit vector
--   D6 enabled rows carry their owner columns: materials difficultyTerm in [0, 1] and qualityTier > 0 (S2, S4);
--      step factor weights in FactorId order, w > 0, Σ w = 1 ± WEIGHT_SUM_TOL (S2; non-empty when enabled);
--      tiers qualityMultiplier > 0 and increasing with order, failScoreFactor in [0, 1], failOutcome known,
--      rarityCap order non-decreasing (S4); rarities minQuality ≥ 0 from Common 0, increasing (S4); stats unit and
--      decimals (S4); equipment types geometry.refs = the 8 factors in FactorId order with lo < hi (S2); family
--      parameters named records with a finite base, a tier column of one factor > 0 per tier, design terms only
--      with a {lo, hi} designClamp, and an enabled family carries its pass line passThreshold in [0, 1] (S3, §6.5)
--   D7 Versions.* positive integers; every Definitions module in Manifest.hashed or Manifest.excluded, and the
--      Manifest names no other module

local Balance = require("./Balance")
local EquipmentTypes = require("./EquipmentTypes")
local Limits = require("./Limits")
local Manifest = require("./Manifest")
local Materials = require("./Materials")
local MinigameFamilies = require("./MinigameFamilies")
local Rarities = require("./Rarities")
local Stats = require("./Stats")
local Steps = require("./Steps")
local Tiers = require("./Tiers")
local Versions = require("./Versions")

-- Enum.Material names Materials rows may use (§16.3): MVP Metal; Phase 2 rows Foil, Glass, Wood, Leather.
local KNOWN_PART_MATERIALS: { string } = { "Metal", "Foil", "Glass", "Wood", "Leather" }

-- "FactorId order" (Definitions/Types, §5.2): every factor array follows it.
local FACTOR_ORDER: { string } = {
	"PartCount", "Thinness", "Asymmetry", "SurfaceComplexity", "EdgeLength", "Joints", "MaterialMix", "Volume",
}

-- The Definitions modules of SPEC §1.2's module map, in its order (D7; T-BAL-02 checks it against the disk).
local MODULES: { string } = {
	"Types", "Catalog", "Versions", "Limits", "Materials", "EquipmentTypes", "Steps", "Tiers", "Rarities", "Stats",
	"Balance", "Validate", "Manifest", "MinigameFamilies", "CraftPlans", "Network", "World", "Presentation", "Audio",
}

local MATERIAL_CLASSES: { string } = { "Metal", "Mineral", "Organic" }
local FAIL_OUTCOMES: { string } = { "LowerQuality", "DestroyMaterial" }

-- Raw rows and tables, untyped on purpose: a planted bundle may hold any value anywhere.
export type Bundle = {
	materials: any,
	equipmentTypes: any,
	steps: any,
	tiers: any,
	rarities: any,
	stats: any,
	families: any, -- MinigameFamilies rows (S3)
	versions: any,
	limits: any,
	weightSumTol: any,
	manifest: any, -- { hashed: { {module} }, excluded: { {module, keys?} } }
	modules: any, -- the Definitions module names D7 covers
}

-- ── helpers ───────────────────────────────────────────────────────────────────────────────────────────────────

local function isFinite(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function isInteger(v: any): boolean
	return isFinite(v) and v % 1 == 0
end

local function isPascal(v: any): boolean
	return type(v) == "string" and string.match(v, "^%u%w*$") ~= nil
end

local function isArray(v: any): boolean
	if type(v) ~= "table" then
		return false
	end
	local n, count = #v, 0
	for k in v do
		count += 1
		if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
			return false
		end
	end
	return count == n
end

local function contains(list: { string }, v: any): boolean
	return table.find(list, v) ~= nil
end

local function show(v: any): string
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

local function rowName(row: any, i: number): string
	if type(row) == "table" and type(row.id) == "string" then
		return row.id
	end
	return "row " .. i
end

-- The rows of a catalog that are records, with their positions (D1 reports the others).
local function records(rows: any): { { i: number, row: any } }
	local out: { { i: number, row: any } } = {}
	if type(rows) ~= "table" then
		return out
	end
	for i = 1, #rows do
		if type(rows[i]) == "table" then
			table.insert(out, { i = i, row = rows[i] })
		end
	end
	return out
end

local function byId(rows: any): { [string]: any }
	local map: { [string]: any } = {}
	for _, rec in records(rows) do
		local id = rec.row.id
		if type(id) == "string" and map[id] == nil then
			map[id] = rec.row
		end
	end
	return map
end

local function isRgb(v: any): boolean
	if not isArray(v) or #v ~= 3 then
		return false
	end
	for i = 1, 3 do
		if not isInteger(v[i]) or v[i] < 0 or v[i] > 255 then
			return false
		end
	end
	return true
end

local function isVec3(v: any): boolean
	return isArray(v) and #v == 3 and isFinite(v[1]) and isFinite(v[2]) and isFinite(v[3])
end

type Out = { string }

local function add(out: Out, check: string, label: string, message: string)
	table.insert(out, check .. " " .. label .. ": " .. message)
end

-- ── D1 catalogs ───────────────────────────────────────────────────────────────────────────────────────────────

local function d1(out: Out, label: string, rows: any, oneToN: boolean)
	if not isArray(rows) then
		add(out, "D1", label, "rows must be a plain array of records")
		return
	end
	local ids: { [string]: boolean } = {}
	local orders: { [number]: boolean } = {}
	local prev: number? = nil
	for i = 1, #rows do
		local row = rows[i]
		if type(row) ~= "table" then
			add(out, "D1", label, string.format("row %d is a %s, not a record", i, type(row)))
			continue
		end
		local name = rowName(row, i)
		if not isPascal(row.id) then
			add(out, "D1", label, string.format("row %d: id %s is not a PascalCase string", i, show(row.id)))
		elseif ids[row.id] then
			add(out, "D1", label, "duplicate id " .. row.id)
		else
			ids[row.id] = true
		end
		if not isFinite(row.order) then
			add(out, "D1", label, name .. ": order " .. show(row.order) .. " is not a finite number")
		else
			if orders[row.order] then
				add(out, "D1", label, name .. ": duplicate order " .. tostring(row.order))
			end
			orders[row.order] = true
			if prev ~= nil and row.order <= prev then
				add(out, "D1", label, name .. ": rows are not in ascending order")
			end
			prev = row.order
			if oneToN and row.order ~= i then
				add(out, "D1", label, string.format("%s: order %s, expected %d (orders are 1..n)", name, tostring(row.order), i))
			end
		end
		if type(row.enabled) ~= "boolean" then
			add(out, "D1", label, name .. ": enabled must be a boolean")
		end
	end
end

-- ── D2 references ─────────────────────────────────────────────────────────────────────────────────────────────

local function d2(out: Out, b: Bundle)
	local families = byId(b.families)
	for _, rec in records(b.steps) do
		local step = rec.row
		local name = rowName(step, rec.i)
		local fam = if type(step.family) == "string" then families[step.family] else nil
		if fam == nil then
			add(out, "D2", "Steps", name .. " names the unknown family " .. show(step.family))
		elseif step.enabled == true and fam.enabled ~= true then
			add(out, "D2", "Steps", "enabled " .. name .. " uses the disabled family " .. tostring(step.family))
		end
	end

	local rarities = byId(b.rarities)
	for _, rec in records(b.tiers) do
		local tier = rec.row
		local name = rowName(tier, rec.i)
		local cap = if type(tier.rarityCap) == "string" then rarities[tier.rarityCap] else nil
		if cap == nil then
			add(out, "D2", "Tiers", name .. " caps at the unknown rarity " .. show(tier.rarityCap))
		elseif tier.enabled == true and cap.enabled ~= true then
			add(out, "D2", "Tiers", "enabled " .. name .. " caps at the disabled rarity " .. tostring(tier.rarityCap))
		end
	end

	local anySlot: { [string]: boolean } = {}
	local enabledSlot: { [string]: boolean } = {}
	for _, rec in records(b.equipmentTypes) do
		local et = rec.row
		for _, slotRec in records(et.slots) do
			local id = slotRec.row.id
			if type(id) == "string" then
				anySlot[id] = true
				if et.enabled == true then
					enabledSlot[id] = true
				end
			end
		end
	end
	for _, rec in records(b.materials) do
		local mat = rec.row
		local name = rowName(mat, rec.i)
		local allowed = mat.allowedSlots
		if allowed == nil then
			continue
		end
		if not isArray(allowed) or #allowed == 0 then
			add(out, "D2", "Materials", name .. ": allowedSlots must be nil (any slot) or a non-empty array of slots")
			continue
		end
		for _, slot in allowed do
			if type(slot) ~= "string" or not anySlot[slot] then
				add(out, "D2", "Materials", name .. " allows the unknown slot " .. show(slot))
			elseif mat.enabled == true and not enabledSlot[slot] then
				add(out, "D2", "Materials", "enabled " .. name .. " allows " .. slot .. ", a slot of no enabled type")
			end
		end
	end
end

-- ── D3 tiers and rarities ─────────────────────────────────────────────────────────────────────────────────────

local function prefix(out: Out, label: string, rows: any)
	local list = records(rows)
	if #list == 0 or list[1].row.enabled ~= true then
		add(out, "D3", label, "the first row must be enabled")
	end
	for k = 2, #list do
		local row, before = list[k].row, list[k - 1].row
		if row.enabled == true and before.enabled ~= true then
			add(out, "D3", label, string.format("enabled rows must form an order prefix: %s is enabled after %s",
				rowName(row, list[k].i), rowName(before, list[k - 1].i)))
		end
	end
end

local function d3(out: Out, b: Bundle)
	prefix(out, "Tiers", b.tiers)
	prefix(out, "Rarities", b.rarities)
	local tiers = records(b.tiers)
	for k, rec in tiers do
		local tier = rec.row
		local name = rowName(tier, rec.i)
		if not isFinite(tier.dMin) or not isFinite(tier.dMax) then
			add(out, "D3", "Tiers", name .. ": dMin and dMax must be finite numbers")
			continue
		end
		if tier.dMin >= tier.dMax then
			add(out, "D3", "Tiers", string.format("%s: dMin %s must be below dMax %s", name, tostring(tier.dMin),
				tostring(tier.dMax)))
		end
		if k == 1 and tier.dMin ~= 0 then
			add(out, "D3", "Tiers", name .. " (the first tier) must start at dMin = 0, got " .. tostring(tier.dMin))
		end
		if k > 1 then
			local before = tiers[k - 1].row
			if isFinite(before.dMax) and tier.dMin ~= before.dMax then
				add(out, "D3", "Tiers", string.format("%s: dMin %s must equal the dMax %s of %s", name, tostring(tier.dMin),
					tostring(before.dMax), rowName(before, tiers[k - 1].i)))
			end
		end
		if k == #tiers and tier.dMax ~= 1 then
			add(out, "D3", "Tiers", name .. " (the last tier) must end at dMax = 1, got " .. tostring(tier.dMax))
		end
	end
end

-- ── D4 materials and colours ──────────────────────────────────────────────────────────────────────────────────

local function d4(out: Out, b: Bundle)
	for _, rec in records(b.materials) do
		local m = rec.row
		local name = rowName(m, rec.i)
		if not contains(MATERIAL_CLASSES, m.class) then
			add(out, "D4", "Materials", name .. ": class " .. show(m.class) .. " is not Metal, Mineral or Organic")
		end
		if not isFinite(m.density) or m.density <= 0 then
			add(out, "D4", "Materials", name .. ": density must be a finite number > 0, got " .. show(m.density))
		end
		for _, field in { "hardness", "toughness" } do
			local v = m[field]
			if not isInteger(v) or v < 0 or v > 100 then
				add(out, "D4", "Materials", name .. ": " .. field .. " must be an integer 0–100, got " .. show(v))
			end
		end
		if not isFinite(m.reflectance) or m.reflectance < 0 or m.reflectance > 1 then
			add(out, "D4", "Materials", name .. ": reflectance must be in [0, 1], got " .. show(m.reflectance))
		end
		if not contains(KNOWN_PART_MATERIALS, m.robloxMaterial) then
			add(out, "D4", "Materials", name .. ": robloxMaterial " .. show(m.robloxMaterial)
				.. " is not in KNOWN_PART_MATERIALS")
		end
	end
	for _, cat in { { label = "Materials", rows = b.materials }, { label = "Tiers", rows = b.tiers },
		{ label = "Rarities", rows = b.rarities } } do
		for _, rec in records(cat.rows) do
			if not isRgb(rec.row.color) then
				add(out, "D4", cat.label, rowName(rec.row, rec.i) .. ": color must be 3 integers 0–255")
			end
		end
	end
end

-- ── D5 equipment types ────────────────────────────────────────────────────────────────────────────────────────

local function d5(out: Out, b: Bundle)
	local limits = if type(b.limits) == "table" then b.limits else {}
	local maxParts = limits.MAX_PARTS
	local posMax = limits.POS_ABS_MAX
	if not isInteger(maxParts) or maxParts < 1 then
		add(out, "D5", "Limits", "MAX_PARTS must be a positive integer, got " .. show(maxParts))
		maxParts = math.huge
	end
	if not isFinite(posMax) or posMax <= 0 then
		add(out, "D5", "Limits", "POS_ABS_MAX must be a finite number > 0, got " .. show(posMax))
		posMax = math.huge
	end
	for _, rec in records(b.equipmentTypes) do
		local et = rec.row
		local name = rowName(et, rec.i)
		local slotIds: { [string]: boolean } = {}
		local ranks: { [number]: boolean } = {}
		local required = 0
		if not isArray(et.slots) or #et.slots == 0 then
			add(out, "D5", "EquipmentTypes", name .. ": slots must be a non-empty array of records")
		end
		for _, slotRec in records(et.slots) do
			local s = slotRec.row
			local sname = name .. "." .. rowName(s, slotRec.i)
			if not isPascal(s.id) then
				add(out, "D5", "EquipmentTypes", sname .. ": slot id must be a PascalCase string")
			elseif slotIds[s.id] then
				add(out, "D5", "EquipmentTypes", name .. ": duplicate slot " .. s.id)
			else
				slotIds[s.id] = true
			end
			if type(s.required) ~= "boolean" then
				add(out, "D5", "EquipmentTypes", sname .. ": required must be a boolean")
			elseif s.required then
				required += 1
			end
			if not isInteger(s.min) or not isInteger(s.max) or s.min < 0 or s.min > s.max or s.max > maxParts then
				add(out, "D5", "EquipmentTypes", string.format("%s: needs integers 0 ≤ min ≤ max ≤ MAX_PARTS, got %s..%s",
					sname, show(s.min), show(s.max)))
			elseif type(s.required) == "boolean" and s.required ~= (s.min >= 1) then
				add(out, "D5", "EquipmentTypes", sname .. ": a slot is required exactly when its min is ≥ 1")
			end
			if not isInteger(s.rank) then
				add(out, "D5", "EquipmentTypes", sname .. ": rank must be an integer")
			elseif ranks[s.rank] then
				add(out, "D5", "EquipmentTypes", name .. ": duplicate slot rank " .. tostring(s.rank))
			else
				ranks[s.rank] = true
			end
		end
		if required < 1 then
			add(out, "D5", "EquipmentTypes", name .. ": needs at least one required slot")
		end
		local g = et.geometry
		if type(g) ~= "table" then
			add(out, "D5", "EquipmentTypes", name .. ": geometry must be a record")
			continue
		end
		if not isInteger(g.partsMin) or not isInteger(g.partsMax) or g.partsMin < 0 or g.partsMin > g.partsMax
			or g.partsMax > maxParts
		then
			add(out, "D5", "EquipmentTypes", string.format("%s: needs integers 0 ≤ partsMin ≤ partsMax ≤ MAX_PARTS, got %s..%s",
				name, show(g.partsMin), show(g.partsMax)))
		end
		if not isVec3(g.hitboxMin) or not isVec3(g.hitboxMax) then
			add(out, "D5", "EquipmentTypes", name .. ": hitboxMin and hitboxMax must be 3 finite numbers")
		else
			for k = 1, 3 do
				local lo, hi = g.hitboxMin[k], g.hitboxMax[k]
				if lo >= hi or math.abs(lo) > posMax or math.abs(hi) > posMax then
					add(out, "D5", "EquipmentTypes", string.format(
						"%s: hitbox axis %d must satisfy -POS_ABS_MAX ≤ min < max ≤ POS_ABS_MAX, got %s..%s", name, k,
						tostring(lo), tostring(hi)))
				end
			end
		end
		for _, field in { "strikingSlot", "gripSlot" } do
			if type(g[field]) ~= "string" or not slotIds[g[field]] then
				add(out, "D5", "EquipmentTypes", name .. ": geometry." .. field .. " " .. show(g[field]) .. " is not a slot of the type")
			end
		end
		if g.guardSlot ~= nil and (type(g.guardSlot) ~= "string" or not slotIds[g.guardSlot]) then
			add(out, "D5", "EquipmentTypes", name .. ": geometry.guardSlot " .. show(g.guardSlot) .. " is not a slot of the type")
		end
		local axis = g.thicknessAxis
		if not isVec3(axis) or math.abs(axis[1] * axis[1] + axis[2] * axis[2] + axis[3] * axis[3] - 1) > 1e-9 then
			add(out, "D5", "EquipmentTypes", name .. ": geometry.thicknessAxis must be a unit vector")
		end
	end
end

-- ── D6 owner columns ──────────────────────────────────────────────────────────────────────────────────────────

local function factorIndex(f: any): number?
	return table.find(FACTOR_ORDER, f)
end

local function weights(out: Out, label: string, list: any, mustHave: boolean, tol: number)
	if not isArray(list) then
		add(out, "D6", "Steps", label .. ": factorWeights must be an array")
		return
	end
	if #list == 0 then
		if mustHave then
			add(out, "D6", "Steps", label .. " is enabled and needs factor weights")
		end
		return
	end
	local sum = 0
	local last = 0
	for i = 1, #list do
		local fw = list[i]
		if type(fw) ~= "table" then
			add(out, "D6", "Steps", string.format("%s: weight %d is not a record", label, i))
			continue
		end
		local idx = factorIndex(fw.factor)
		if idx == nil then
			add(out, "D6", "Steps", label .. ": unknown factor " .. show(fw.factor))
		elseif idx <= last then
			add(out, "D6", "Steps", label .. ": factor weights must follow FactorId order without repeats (at "
				.. tostring(fw.factor) .. ")")
		else
			last = idx
		end
		if not isFinite(fw.w) or fw.w <= 0 then
			add(out, "D6", "Steps", label .. ": weight of " .. tostring(fw.factor) .. " must be a finite number > 0")
		else
			sum += fw.w
		end
	end
	if math.abs(sum - 1) > tol then
		add(out, "D6", "Steps", string.format("%s: weights sum to %.17g, not 1 ± %g", label, sum, tol))
	end
end

local function d6(out: Out, b: Bundle)
	local tol = if isFinite(b.weightSumTol) and b.weightSumTol >= 0 then b.weightSumTol else 1e-9

	for _, rec in records(b.materials) do
		local m = rec.row
		if m.enabled ~= true then
			continue
		end
		local name = rowName(m, rec.i)
		if not isFinite(m.difficultyTerm) or m.difficultyTerm < 0 or m.difficultyTerm > 1 then
			add(out, "D6", "Materials", name .. ": difficultyTerm must be in [0, 1], got " .. show(m.difficultyTerm))
		end
		if not isFinite(m.qualityTier) or m.qualityTier <= 0 then
			add(out, "D6", "Materials", name .. ": qualityTier must be a finite number > 0, got " .. show(m.qualityTier))
		end
	end

	for _, rec in records(b.steps) do
		local s = rec.row
		weights(out, rowName(s, rec.i), s.factorWeights, s.enabled == true, tol)
	end

	local rarityOrder: { [string]: number } = {}
	for _, rec in records(b.rarities) do
		if type(rec.row.id) == "string" and isFinite(rec.row.order) then
			rarityOrder[rec.row.id] = rec.row.order
		end
	end
	local prevMult: number? = nil
	local prevCap: number? = nil
	for _, rec in records(b.tiers) do
		local t = rec.row
		local name = rowName(t, rec.i)
		local mult = t.qualityMultiplier
		if isFinite(mult) and mult > 0 then
			if prevMult ~= nil and mult <= prevMult then
				add(out, "D6", "Tiers", name .. ": qualityMultiplier must increase with the tier order")
			end
			prevMult = mult
		elseif t.enabled == true then
			add(out, "D6", "Tiers", name .. ": qualityMultiplier must be a finite number > 0, got " .. show(mult))
		end
		local capOrder = if type(t.rarityCap) == "string" then rarityOrder[t.rarityCap] else nil
		if capOrder ~= nil then
			if prevCap ~= nil and capOrder < prevCap then
				add(out, "D6", "Tiers", name .. ": rarityCap must not fall below the previous tier's")
			end
			prevCap = capOrder
		end
		if t.enabled == true then
			if not isFinite(t.failScoreFactor) or t.failScoreFactor < 0 or t.failScoreFactor > 1 then
				add(out, "D6", "Tiers", name .. ": failScoreFactor must be in [0, 1], got " .. show(t.failScoreFactor))
			end
			if not contains(FAIL_OUTCOMES, t.failOutcome) then
				add(out, "D6", "Tiers", name .. ": failOutcome " .. show(t.failOutcome) .. " is not LowerQuality or DestroyMaterial")
			end
		end
	end

	local prevQ: number? = nil
	for k, rec in records(b.rarities) do
		local r = rec.row
		local name = rowName(r, rec.i)
		local q = r.minQuality
		if not isFinite(q) or q < 0 then
			if r.enabled == true then
				add(out, "D6", "Rarities", name .. ": minQuality must be a finite number ≥ 0, got " .. show(q))
			end
			continue
		end
		if k == 1 and q ~= 0 then
			add(out, "D6", "Rarities", name .. " (the first rarity) must have minQuality 0, got " .. tostring(q))
		end
		if prevQ ~= nil and q <= prevQ then
			add(out, "D6", "Rarities", name .. ": minQuality must increase with the rarity order")
		end
		prevQ = q
	end

	for _, rec in records(b.stats) do
		local s = rec.row
		if s.enabled == true then
			if type(s.unit) ~= "string" then
				add(out, "D6", "Stats", rowName(s, rec.i) .. ": unit must be a string")
			end
			if not isInteger(s.decimals) or s.decimals < 0 then
				add(out, "D6", "Stats", rowName(s, rec.i) .. ": decimals must be an integer ≥ 0")
			end
		end
	end

	for _, rec in records(b.equipmentTypes) do
		local et = rec.row
		if et.enabled ~= true then
			continue
		end
		local name = rowName(et, rec.i)
		local refs = if type(et.geometry) == "table" then et.geometry.refs else nil
		if not isArray(refs) or #refs ~= #FACTOR_ORDER then
			add(out, "D6", "EquipmentTypes", name .. ": geometry.refs must list the 8 factors in FactorId order")
			continue
		end
		for i, factor in FACTOR_ORDER do
			local r = refs[i]
			if type(r) ~= "table" or r.factor ~= factor then
				add(out, "D6", "EquipmentTypes", string.format("%s: geometry.refs[%d] must be %s", name, i, factor))
			elseif not isFinite(r.lo) or not isFinite(r.hi) or r.lo >= r.hi then
				add(out, "D6", "EquipmentTypes", string.format("%s: geometry.refs %s needs finite lo < hi", name, factor))
			end
		end
	end

	-- MinigameFamilies (S3, §6.5): the shape of every parameter on every row (a disabled row's are enabled later),
	-- and an enabled family needs its parameters, the pass line among them
	local tierCount: number? = if isArray(b.tiers) then #b.tiers else nil
	for _, rec in records(b.families) do
		local f = rec.row
		local name = rowName(f, rec.i)
		local params = f.params
		if not isArray(params) then
			add(out, "D6", "MinigameFamilies", name .. ": params must be an array")
			continue
		end
		local hasPass = false
		for i = 1, #params do
			local p = params[i]
			if type(p) ~= "table" or type(p.name) ~= "string" then
				add(out, "D6", "MinigameFamilies", string.format("%s: parameter %d must be a record with a name", name, i))
				continue
			end
			local where = name .. "." .. p.name
			if not isFinite(p.base) then
				add(out, "D6", "MinigameFamilies", where .. ": base must be a finite number, got " .. show(p.base))
			elseif p.name == "passThreshold" then
				hasPass = true
				if p.base < 0 or p.base > 1 then
					add(out, "D6", "MinigameFamilies", where .. " must be in [0, 1], got " .. show(p.base))
				end
			end
			local tier = p.tier
			if tier ~= nil then
				local good = isArray(tier) and (tierCount == nil or #tier == tierCount)
				if good then
					for k = 1, #tier do
						if not isFinite(tier[k]) or tier[k] <= 0 then
							good = false
						end
					end
				end
				if not good then
					add(out, "D6", "MinigameFamilies", string.format("%s: the tier column needs one finite factor > 0 per "
						.. "tier (%s)", where, if tierCount then tostring(tierCount) else "?"))
				end
			end
			local clamp = p.designClamp
			if (p.design == nil) ~= (clamp == nil) then
				add(out, "D6", "MinigameFamilies", where .. ": design terms and designClamp come together")
			elseif clamp ~= nil then
				if not (isArray(p.design) and #p.design > 0) then
					add(out, "D6", "MinigameFamilies", where .. ": design must be a non-empty array of terms")
				end
				local pair = isArray(clamp) and #clamp == 2 and isFinite(clamp[1]) and isFinite(clamp[2])
				if not (pair and clamp[1] <= clamp[2]) then
					add(out, "D6", "MinigameFamilies", where .. ": designClamp must be {lo, hi} with finite lo ≤ hi")
				end
			end
		end
		if f.enabled == true and not hasPass then
			add(out, "D6", "MinigameFamilies", name .. " is enabled and needs its parameters, passThreshold among them")
		end
	end
end

-- ── D7 versions and the Manifest ──────────────────────────────────────────────────────────────────────────────

local function d7(out: Out, b: Bundle)
	local versions = b.versions
	if type(versions) ~= "table" then
		add(out, "D7", "Versions", "must be a table")
	else
		for _, key in { "DATA_VERSION", "BLUEPRINT_SCHEMA", "BALANCE_VERSION" } do
			if versions[key] == nil then
				add(out, "D7", "Versions", key .. " is missing")
			end
		end
		local keys: { { name: string, key: any } } = {}
		for k in versions do
			table.insert(keys, { name = tostring(k), key = k })
		end
		table.sort(keys, function(a, b): boolean
			return a.name < b.name
		end)
		for _, entry in keys do
			local v = versions[entry.key]
			if type(entry.key) ~= "string" then
				add(out, "D7", "Versions", "holds the non-string key " .. entry.name)
			elseif not isInteger(v) or v < 1 then
				add(out, "D7", "Versions", entry.name .. " must be a positive integer, got " .. show(v))
			end
		end
	end

	local manifest = b.manifest
	local listed: { [string]: boolean } = {}
	local hashedNames: { [string]: boolean } = {}
	local names: { string } = {}
	local function note(entry: any, list: string, whole: boolean)
		if type(entry) ~= "table" or type(entry.module) ~= "string" then
			add(out, "D7", "Manifest", list .. " holds an entry without a module name")
			return
		end
		if not listed[entry.module] then
			table.insert(names, entry.module)
		end
		listed[entry.module] = true
		if list == "hashed" then
			hashedNames[entry.module] = true
		elseif whole and hashedNames[entry.module] then
			add(out, "D7", "Manifest", entry.module .. " is both hashed and excluded as a whole")
		end
	end
	if type(manifest) ~= "table" or not isArray(manifest.hashed) or not isArray(manifest.excluded) then
		add(out, "D7", "Manifest", "needs the arrays hashed and excluded")
	else
		for _, entry in manifest.hashed do
			note(entry, "hashed", false)
		end
		for _, entry in manifest.excluded do
			note(entry, "excluded", type(entry) == "table" and entry.keys == nil)
		end
	end
	if not isArray(b.modules) then
		add(out, "D7", "Manifest", "the list of Definitions modules must be an array")
	end
	local modules = if isArray(b.modules) then b.modules else {}
	local known: { [string]: boolean } = {}
	for _, name in modules do
		if type(name) ~= "string" then
			add(out, "D7", "Manifest", "the list of Definitions modules holds a " .. type(name))
			continue
		end
		known[name] = true
		if not listed[name] then
			add(out, "D7", "Manifest", "the Definitions module " .. name .. " is in neither Manifest.hashed nor Manifest.excluded")
		end
	end
	for _, name in names do
		if not known[name] then
			add(out, "D7", "Manifest", "names " .. name .. ", which is not a Definitions module")
		end
	end
end

-- ── API ───────────────────────────────────────────────────────────────────────────────────────────────────────

local function current(): Bundle
	return {
		materials = Materials.ordered,
		equipmentTypes = EquipmentTypes.ordered,
		steps = Steps.ordered,
		tiers = Tiers.ordered,
		rarities = Rarities.ordered,
		stats = Stats.ordered,
		families = (MinigameFamilies :: any).ordered,
		versions = Versions,
		limits = Limits,
		weightSumTol = Balance.Quality.WEIGHT_SUM_TOL,
		manifest = Manifest,
		modules = MODULES,
	}
end

local function check(b: Bundle): { string }
	local out: Out = {}
	local ok, err = pcall(function(): any
		if type(b) ~= "table" then
			add(out, "D1", "Definitions", "the bundle must be a table")
			return nil
		end
		d1(out, "Materials", b.materials, false)
		d1(out, "EquipmentTypes", b.equipmentTypes, false)
		d1(out, "Steps", b.steps, false)
		d1(out, "Tiers", b.tiers, true)
		d1(out, "Rarities", b.rarities, true)
		d1(out, "Stats", b.stats, false)
		d1(out, "MinigameFamilies", b.families, false)
		d2(out, b)
		d3(out, b)
		d4(out, b)
		d5(out, b)
		d6(out, b)
		d7(out, b)
		return nil
	end)
	if not ok then
		table.insert(out, "Validate: internal error: " .. tostring(err))
	end
	return out
end

local function validateAll(extra: { () -> { string } }?): { string }
	local out = check(current())
	if extra ~= nil then
		for i, fn in extra do
			local ok, result = pcall(fn)
			if not ok then
				table.insert(out, string.format("extra check %d raised: %s", i, tostring(result)))
			elseif type(result) ~= "table" then
				table.insert(out, string.format("extra check %d returned a %s, not a list of problems", i, type(result)))
			else
				for _, problem in result do
					table.insert(out, tostring(problem))
				end
			end
		end
	end
	return out
end

export type Validate = {
	KNOWN_PART_MATERIALS: { string },
	FACTOR_ORDER: { string },
	MODULES: { string },
	current: () -> Bundle,
	check: (bundle: Bundle) -> { string },
	validateAll: (extra: { () -> { string } }?) -> { string },
}

local Validate: Validate = {
	KNOWN_PART_MATERIALS = table.freeze(KNOWN_PART_MATERIALS),
	FACTOR_ORDER = table.freeze(FACTOR_ORDER),
	MODULES = table.freeze(MODULES),
	current = current,
	check = check,
	validateAll = validateAll,
}

return table.freeze(Validate)
