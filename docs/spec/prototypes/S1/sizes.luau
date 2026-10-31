--!strict
-- S1 prototype: JSON size budget of the FINAL record shapes in the S1 draft (§3.2, §9.3, §9.4).
-- Encoder mimics Roblox HttpService:JSONEncode as probed in Studio on 2026-10-31:
--   integers plain, decimals shortest round-trip in plain notation, {} -> [], no whitespace, UTF-8 raw.
--   (byte counts verified identical to Studio for a worst-case part (181 B) and a typical part (127 B))
-- Throwaway: run with lune 0.8.9.

local function fmtNumber(x: number): string
	assert(x == x and x ~= math.huge and x ~= -math.huge, "non-finite")
	if x == math.floor(x) and math.abs(x) < 2 ^ 53 then
		return string.format("%d", x)
	end
	for d = 1, 17 do
		local s = string.format("%." .. d .. "g", x)
		if tonumber(s) == x then
			if string.find(s, "e") then
				local mant, ex = string.match(s, "^(-?[%d%.]+)e([-+]%d+)$")
				local frac = string.match(mant :: string, "%.(%d+)") or ""
				local k = math.max(0, #frac - (tonumber(ex) :: number))
				s = string.format("%." .. k .. "f", x)
			end
			return s
		end
	end
	return string.format("%.17g", x)
end

local function encodeString(s: string): string
	local out = string.gsub(s, '[%c"\\]', function(c: string)
		if c == '"' then
			return '\\"'
		elseif c == "\\" then
			return "\\\\"
		end
		return string.format("\\u%04x", string.byte(c))
	end)
	return '"' .. out .. '"'
end

local function encode(v: any): string
	local t = type(v)
	if t == "number" then
		return fmtNumber(v)
	elseif t == "string" then
		return encodeString(v)
	elseif t == "boolean" then
		return if v then "true" else "false"
	elseif t == "table" then
		local n = #v
		if n > 0 then
			local parts = table.create(n)
			for i = 1, n do
				parts[i] = encode(v[i])
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = {}
		for k in pairs(v) do
			table.insert(keys, k)
		end
		if #keys == 0 then
			return "[]"
		end
		table.sort(keys)
		local parts = {}
		for _, k in keys do
			table.insert(parts, encodeString(k) .. ":" .. encode(v[k]))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("unsupported " .. t)
end
local function size(v: any): number
	return #encode(v)
end

------------------------------------------------------------------------------------------------
local STEP_IDS = { "Smelting", "Hammering", "Sharpening", "Casting", "Quenching", "Assembly", "Finishing", "Riveting" }
local FAMILIES = { "HoldZone", "TimingStrike", "PrecisionTrace", "HoldZone", "ReleaseTiming", "FitPuzzle", "RhythmSequence", "TimingStrike" }
local MATS = { "Iron", "Steel", "Bronze", "Mithril", "Obsidian", "Wood", "Leather" }
local NAME_WORST = string.rep("é", 32) -- 32 code points, 64 bytes (longest legal name in bytes)

local function worstPart(id: number)
	return {
		Id = id,
		Slot = "Pommel",
		Shape = "CornerWedge",
		Material = "Obsidian",
		Pos = { -0.9876, -1.4567, -0.3456 },
		Rot = { -0.123457, -0.234568, -0.345679, 0.901235 },
		Size = { 1.9876, 6.9876, 0.7654 },
	}
end
local function typicalPart(id: number)
	local rotated = id % 3 == 0
	return {
		Id = id,
		Slot = "Blade",
		Shape = "Block",
		Material = "Steel",
		Pos = { 0, 2.35, 0 },
		Rot = if rotated then { 0, 0, 0.382683, 0.92388 } else { 0, 0, 0, 1 },
		Size = { 0.3, 3.6, 0.08 },
	}
end
local function parts(n: number, f: (number) -> any): { any }
	local p = {}
	for i = 1, n do
		p[i] = f(i)
	end
	return p
end
local function physics()
	return { Mass = 12.3456, BalancePoint = -0.4123, Reach = 12.3456 }
end
local function analysis(nSteps: number)
	local steps = {}
	for i = 1, nSteps do
		steps[STEP_IDS[i]] = { D = 0.1234, Tier = "Master" }
	end
	local issues = {}
	for i = 1, 8 do
		issues[i] = "PartOutsideHitbox"
	end
	return { BalanceVersion = 999, GeometryVersion = 999, Valid = false, Issues = issues, Physics = physics(), Steps = steps }
end
local function blueprintRecord(n: number, f: (number) -> any, name: string, nSteps: number)
	return {
		Schema = 1,
		Id = "B99999",
		Name = name,
		Type = "Sword",
		Revision = 99999,
		Created = 1793404800,
		Updated = 1793491200,
		Parts = parts(n, f),
		Analysis = analysis(nSteps),
	}
end
local function snapshot(n: number, f: (number) -> any, name: string)
	return { Schema = 1, SourceId = "B99999", SourceRevision = 99999, Name = name, Type = "Sword", Parts = parts(n, f) }
end
local function stepRecord(i: number)
	return {
		Step = STEP_IDS[i],
		Family = FAMILIES[i],
		Tier = "Master",
		D = 0.1234,
		Seed = 4294967295,
		Score = 0.8734,
		Passed = false,
		DurationMs = 123456,
		Flags = { "SuspectTiming", "ClientScoreMismatch", "LateInput", "Retimed" },
	}
end
local function itemRecord(n: number, f: (number) -> any, name: string, nSteps: number, nMats: number, nMeasures: number)
	local steps = {}
	for i = 1, nSteps do
		steps[i] = stepRecord(i)
	end
	local byMat, list = {}, {}
	for i = 1, nMats do
		byMat[MATS[i]] = { Volume = 0.123456, Moment = { -0.012345, 0.345678, -0.001234 } }
		list[i] = MATS[i]
	end
	local measures = {}
	for i = 1, nMeasures do
		measures["Measure" .. string.format("%02d", i) .. "Name"] = -12.345678
	end
	local stats = {}
	for _, k in { "Damage", "Sharpness", "Durability", "Reach", "SwingSpeed", "Purity" } do
		stats[k] = 123.4567
	end
	return {
		Id = "I99999",
		Name = name,
		CrafterUserId = 9876543210,
		Created = 1793404800,
		Blueprint = snapshot(n, f, name),
		Materials = list,
		Steps = steps,
		AtForge = { BalanceVersion = 999, GeometryVersion = 999, Quality = 0.6123, Rarity = "Legendary" },
		GeometryVersion = 999,
		Geometry = { ByMaterial = byMat, Measures = measures },
		BalanceVersion = 999,
		Physics = physics(),
		Stats = stats,
		Quality = 0.6123,
		Rarity = "Legendary",
		RarityCap = "Legendary",
	}
end

local function template()
	return {
		DataVersion = 1,
		NextIds = { Blueprint = 1, Item = 1 },
		Blueprints = {},
		Items = {},
		Smithy = { Level = 1, Displays = {} },
		Inventory = { Materials = {} },
		EditorPrefs = {
			Snap = { Move = { On = true, Step = 0.05 }, Rotate = { On = true, Step = 15 }, Scale = { On = true, Step = 0.05 } },
			Presets = {
				Move = { 0.01, 0.05, 0.1, 0.25, 0.5, 1 },
				Rotate = { 1, 5, 15, 22.5, 45, 90 },
				Scale = { 0.01, 0.05, 0.1, 0.25, 0.5, 1 },
			},
			Space = "Local",
			Overlays = { Grid = true, Hitbox = true, Physics = true },
		},
		UiFlags = {},
		Counters = {
			BlueprintsCreated = 0,
			BlueprintSaves = 0,
			BlueprintsDeleted = 0,
			CraftsStarted = 0,
			CraftsCompleted = 0,
			CraftsAbandoned = 0,
			ItemsScrapped = 0,
			BestQuality = 0,
			PlaySeconds = 0,
			StepsPlayed = {},
			StepsPassed = {},
			TierPlays = {},
			RarityCounts = {},
		},
		Quarantine = { Blueprints = {}, Items = {} },
	}
end

local LIMIT = 4194304
local WRAP = 300 -- ProfileStore wrapper: MetaData, GlobalUpdates, UserIds, RobloxMetaData

local function filledProfile(nBp: number, nItems: number, nParts: number, nSteps: number, nMats: number, nMeasures: number, f: (number) -> any, name: string)
	local d: any = template()
	for i = 1, nBp do
		d.Blueprints["B" .. (90000 + i)] = blueprintRecord(nParts, f, name, nSteps)
	end
	for i = 1, nItems do
		d.Items["I" .. (90000 + i)] = itemRecord(nParts, f, name, nSteps, nMats, nMeasures)
	end
	for i = 1, 12 do
		d.Smithy.Displays["D" .. i] = "I" .. (90000 + i)
	end
	for i = 1, 40 do
		d.UiFlags["SeenTutorialStep" .. i] = true
	end
	d.EditorPrefs.Presets.Move = { 0.001, 0.005, 0.01, 0.0125, 0.025, 0.05, 0.1, 0.125, 0.25, 0.5, 1, 2 }
	for _, s in STEP_IDS do
		d.Counters.StepsPlayed[s] = 9999999
		d.Counters.StepsPassed[s] = 9999999
	end
	for _, t in { "Normal", "Hard", "Expert", "Master", "Hell" } do
		d.Counters.TierPlays[t] = 9999999
	end
	for _, r in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine" } do
		d.Counters.RarityCounts[r] = 9999999
	end
	return size(d) + WRAP
end

print("== per part ==")
print(("worst-case part %d B | typical axis-aligned %d B | typical rotated %d B"):format(size(worstPart(65535)), size(typicalPart(1)), size(typicalPart(3))))

local bpOverhead = size(blueprintRecord(0, worstPart, NAME_WORST, 3))
local bp48 = size(blueprintRecord(48, worstPart, NAME_WORST, 3))
local perPart = (bp48 - bpOverhead) / 48
print(("== blueprint record == overhead (no parts, worst analysis, MVP 3 steps) %d B; per worst part %.1f B"):format(bpOverhead, perPart))
for _, n in { 4, 12, 24, 32, 48, 64 } do
	print(("  N=%2d  worst %6d B   typical %6d B"):format(n, size(blueprintRecord(n, worstPart, NAME_WORST, 3)), size(blueprintRecord(n, typicalPart, "Long Sword", 3))))
end

local itMvp0 = size(itemRecord(0, worstPart, NAME_WORST, 3, 2, 16))
local itP2_0 = size(itemRecord(0, worstPart, NAME_WORST, 8, 7, 16))
print(("== item record == overhead (no parts) MVP-worst %d B (3 steps, 2 mats, 16 measures); Phase2+-worst %d B (8 steps, 7 mats)"):format(itMvp0, itP2_0))
for _, n in { 4, 12, 24, 32, 48, 64 } do
	print(("  N=%2d  MVP-worst %6d B   Phase2+-worst %6d B   typical %6d B"):format(n, size(itemRecord(n, worstPart, NAME_WORST, 3, 2, 16)), size(itemRecord(n, worstPart, NAME_WORST, 8, 7, 16)), size(itemRecord(n, typicalPart, "Long Sword", 3, 2, 12))))
end
print(("one worst step record %d B"):format(size(stepRecord(2))))

print("== profile ==")
print(("empty template %d B"):format(size(template())))
for _, c in {
	{ 40, 150, 48, 3, 2, "MVP item shape, placeholder MAX_PARTS_ABS=48" },
	{ 40, 150, 48, 8, 7, "Phase 2+ item shape" },
	{ 30, 120, 64, 8, 7, "if S2 picks 64" },
	{ 50, 200, 32, 8, 7, "if S2 picks 32" },
	{ 60, 250, 24, 8, 7, "if S2 picks 24" },
} do
	local s = filledProfile(c[1], c[2], c[3], c[4], c[5], 16, worstPart, NAME_WORST)
	print(("  bp=%d items=%d parts=%d (%s): %8d B = %4.1f%% of 4 MiB"):format(c[1], c[2], c[3], c[6], s, 100 * s / LIMIT))
end
local typ = filledProfile(15, 80, 12, 3, 2, 12, typicalPart, "Long Sword")
print(("  typical heavy player (15 bp, 80 items, 12 parts each): %d B = %.1f%%"):format(typ, 100 * typ / LIMIT))

print("== wire ==")
local draft = { Schema = 1, Id = "B99999", Name = NAME_WORST, Type = "Sword", Parts = parts(48, worstPart) }
print(("  worst BlueprintDraft @48 parts %d B; @64 parts %d B"):format(size(draft), size({ Schema = 1, Id = "B99999", Name = NAME_WORST, Type = "Sword", Parts = parts(64, worstPart) })))
local bpSummary = { Id = "B99999", Name = NAME_WORST, Type = "Sword", Revision = 99999, Updated = 1793491200, PartCount = 48, Analysis = analysis(3) }
local itemSummary = { Id = "I99999", Name = NAME_WORST, Type = "Sword", Created = 1793404800, Materials = { "Iron", "Steel" }, Quality = 0.6123, Rarity = "Legendary", Tiers = { "Master", "Master", "Master" }, DisplaySlot = "D12" }
print(("  BlueprintSummary %d B; ItemSummary %d B; join payload at caps (40+150) %d B"):format(size(bpSummary), size(itemSummary), 40 * size(bpSummary) + 150 * size(itemSummary)))

-- caps formula coefficients: W(B, I, P) = W0 + B*(bpOverhead + p*P) + I*(itOverhead + p*P)
print(("== formula == W0=%d  bpOverhead=%d  itemOverhead(MVP)=%d  itemOverhead(Phase2+)=%d  p=%.1f"):format(filledProfile(0, 0, 0, 3, 2, 16, worstPart, NAME_WORST), bpOverhead, itMvp0, itP2_0, perPart))
