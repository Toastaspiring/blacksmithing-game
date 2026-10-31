--!strict
-- S1 prototype v2 (revision): JSON size budget of the FINAL record shapes.
-- Changes vs sizes.luau (v1, outputs kept in sizes.v1.out.txt):
--   camelCase fields; raw-double transforms (no 1e-4/1e-6 grid); GUID ids (36 chars); MAX_PARTS = 24;
--   item record per RULINGS 2.9 (steps, physics, outcome, atForge; no GeometrySummary/Materials list);
--   Profile.Data per RULINGS 2.8 (no Counters, NextIds, Inventory; settings trimmed; starterGranted).
-- Encoder = Roblox HttpService:JSONEncode as probed in Studio on 2026-10-31 (see PROBE below):
--   shortest round-trip digits, ECMAScript Number::toString layout (plain for 1e-6 <= |x| < 1e21,
--   otherwise d.ddde-N without '+'), "-0" for negative zero, {} -> [], no whitespace, UTF-8 raw.
-- Run: lune run sizes2.luau

local function digitsOf(x: number): (string, string, number)
	for p = 1, 17 do
		local s = string.format("%." .. (p - 1) .. "e", x)
		if tonumber(s) == x then
			local sign, m, e = string.match(s, "^(%-?)(%d[%.%d]*)e([%-+]%d+)$")
			assert(sign and m and e, s)
			local d = string.gsub(m :: string, "%.", "")
			d = string.gsub(d, "0+$", "")
			if d == "" then
				d = "0"
			end
			return sign :: string, d, (tonumber(e) :: number) + 1
		end
	end
	error("no round trip for " .. tostring(x))
end

local function fmtNumber(x: number): string
	assert(x == x and x ~= math.huge and x ~= -math.huge, "non-finite")
	if x == 0 then
		return if 1 / x < 0 then "-0" else "0"
	end
	local sign, d, n = digitsOf(x)
	local k = #d
	if k <= n and n <= 21 then
		return sign .. d .. string.rep("0", n - k)
	elseif 0 < n and n <= 21 then
		return sign .. string.sub(d, 1, n) .. "." .. string.sub(d, n + 1)
	elseif -6 < n and n <= 0 then
		return sign .. "0." .. string.rep("0", -n) .. d
	end
	local e = n - 1
	local es = if e < 0 then "-" .. tostring(-e) else tostring(e)
	if k == 1 then
		return sign .. d .. "e" .. es
	end
	return sign .. string.sub(d, 1, 1) .. "." .. string.sub(d, 2) .. "e" .. es
end

-- Studio probe (HttpService:JSONEncode, 2026-10-31): input -> exact output
local PROBE: { { any } } = {
	{ 5.551115123125783e-17, "5.551115123125783e-17" },
	{ -5.551115123125783e-17, "-5.551115123125783e-17" },
	{ 0.1 + 0.2, "0.30000000000000007" },
	{ 1 / 3, "0.3333333333333333" },
	{ 2 / 3 * 16, "10.666666666666666" },
	{ -15.999999999999998, "-15.999999999999999" },
	{ -2.2250738585072009e-308, "-2.225073858507201e-308" },
	{ 4.9406564584124654e-324, "5e-324" },
	{ 1e-5, "0.00001" },
	{ 1.2345678901234567e-05, "0.000012345678901234568" },
	{ 0.00012345678901234567, "0.00012345678901234567" },
	{ 0.0012345678901234567, "0.0012345678901234568" },
	{ math.sqrt(0.5), "0.7071067811865476" },
	{ -0.12345678901234568, "-0.12345678901234568" },
	{ 1e21, "1e21" },
	{ 123456789012345680000, "123456789012345680000" },
	{ 0.05, "0.05" },
	{ -0.0, "-0" },
	{ 9876543210, "9876543210" },
	{ 4294967295, "4294967295" },
	{ 0.8734, "0.8734" },
	{ -0.9876, "-0.9876" },
	{ 1e-7, "1e-7" },
	{ 3e-10, "3e-10" },
}
-- Roblox sometimes picks a different (still round-tripping) last digit when 17 digits are needed, so the
-- check is on LENGTH (what the budget needs); digit-content differences are reported separately.
local probeLenBad, probeDigitDiff = 0, 0
for _, c in PROBE do
	local got = fmtNumber(c[1])
	if #got ~= #c[2] then
		probeLenBad += 1
		print("PROBE LENGTH MISMATCH", c[2], got)
	elseif got ~= c[2] then
		probeDigitDiff += 1
		assert(tonumber(c[2]) == c[1], "Studio string must round-trip")
	end
end
print(("encoder vs Studio probe: %d / %d length mismatches (%d same-length last-digit differences)"):format(
	probeLenBad, #PROBE, probeDigitDiff))
-- Bulk check (6 classes x 3000 deterministic values, same generator run in Studio): Studio totals were
-- 72501 / 52513 / 53927 / 56303 / 60530 / 66479 chars, max 25 / 20 / 21 / 22 / 22 / 25.
local STUDIO_BULK = { { 72501, 25 }, { 52513, 20 }, { 53927, 21 }, { 56303, 22 }, { 60530, 22 }, { 66479, 25 } }
local function gen(cls: number, i: number): number
	local u = (i * 0.6180339887498949) % 1
	local v = (i * 0.41421356237309503) % 1
	if cls == 1 then
		return -1e-5 + u * 9e-6
	elseif cls == 2 then
		return 0.02 + u * 5.98
	elseif cls == 3 then
		return -16 + u * 32
	elseif cls == 4 then
		local a, b, c, d = u - 0.5, v - 0.5, ((i * 0.7320508075688772) % 1) - 0.5, ((i * 0.2360679774997898) % 1) - 0.5
		return a / math.sqrt(a * a + b * b + c * c + d * d)
	elseif cls == 5 then
		return u * 1e-7
	end
	return (u - 0.5) * 1e-3
end
for cls = 1, 6 do
	local total, maxLen = 0, 0
	for i = 1, 3000 do
		local l = #fmtNumber(gen(cls, i))
		total += l
		maxLen = math.max(maxLen, l)
	end
	print(("  bulk class %d: Lune %d chars (Studio %d, +%d), max %d (Studio %d)"):format(cls, total, STUDIO_BULK[cls][1],
		STUDIO_BULK[cls][1] - total, maxLen, STUDIO_BULK[cls][2]))
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
-- Longest legal numbers (searched, deterministic seed)
math.randomseed(7)
local function longest(lo: number, hi: number, tries: number): number
	local best, bestLen = lo, 0
	for _ = 1, tries do
		local x = lo + math.random() * (hi - lo)
		local l = #fmtNumber(x)
		if l > bestLen then
			best, bestLen = x, l
		end
	end
	return best
end
local POS_W = longest(-1e-5, -1e-6, 20000) -- |pos| <= 16: tiny negatives print longest (plain notation, 17 digits)
local TINY_Q = longest(-1e-5, -1e-6, 20000) -- three tiny quaternion components
local QW_W = math.sqrt(1 - 3 * TINY_Q * TINY_Q) -- fourth component keeps |q| = 1 (no renormalization needed)
local SIZE_W = longest(0.02, 0.1, 20000) -- MIN_DIM 0.02 .. 0.1 prints "0.0" + 17 digits
local RAW_W = longest(-1e-5, -1e-6, 20000) -- any unquantized derived double (physics)
print(("longest numbers: pos %d chars (%s) | quat tiny %d, qw %d (%s) | size %d (%s) | raw %d"):format(
	#fmtNumber(POS_W), fmtNumber(POS_W), #fmtNumber(TINY_Q), #fmtNumber(QW_W), fmtNumber(QW_W),
	#fmtNumber(SIZE_W), fmtNumber(SIZE_W), #fmtNumber(RAW_W)))

local GUID = "93E32E8A-59BA-4037-9A7F-AA5613CD6213" -- 36 chars, server upper-cases
local NAME_WORST = string.rep("é", 32) -- 32 code points, 64 bytes
local STEP_IDS = { "Smelting", "Hammering", "Sharpening", "Casting", "Quenching", "Assembly", "Finishing", "Riveting" }
local FAMILIES = { "HoldZone", "TimingStrike", "PrecisionTrace", "HoldZone", "ReleaseTiming", "FitPuzzle", "RhythmSequence", "TimingStrike" }
local FLAGS_MVP = {
	{ "HZ_InhumanRate", "HZ_NearPerfect", "LateSubmit", "ScoreMismatch" },
	{ "LateSubmit", "ScoreMismatch", "TS_ExactHits", "TS_LowVariance" },
	{ "LateSubmit", "PT_Sparse", "PT_Teleport", "PT_TooPrecise", "PT_TooSmooth", "ScoreMismatch" },
}
local FLAGS_LONG6 = { "HZ_InhumanRate", "HZ_NearPerfect", "PT_TooPrecise", "ScoreMismatch", "TS_LowVariance", "TS_ExactHits" }
local STATS_MVP = { "Damage", "Sharpness", "Durability", "Purity", "Balance", "Reach" }
local STATS_P2 = { "Damage", "Sharpness", "Durability", "Purity", "Balance", "Reach", "SwingSpeed", "Defense", "Mobility" }

local function worstPart(id: number)
	return {
		id = id,
		slot = "Pommel",
		shape = "CornerWedge",
		material = "Obsidian", -- longest material id (Phase 2 row); MVP ids are shorter
		pos = { POS_W, POS_W, POS_W },
		rot = { TINY_Q, TINY_Q, TINY_Q, QW_W },
		size = { SIZE_W, SIZE_W, SIZE_W },
	}
end
-- typical editor output: Move/Scale snapped at 0.05 and cleaned by S6 (short decimals), 1 part in 3 freely rotated
local FREE_Q = { 0.12345678901234568, -0.23456789012345678, 0.3456789012345679, 0.9010215234023523 }
local function typicalPart(id: number)
	local rotated = id % 3 == 0
	return {
		id = id,
		slot = "Blade",
		shape = "Block",
		material = "Steel",
		pos = { 0, 2.35, 0 },
		rot = if rotated then FREE_Q else { 0, 0, 0, 1 },
		size = { 0.2, 2.5, 0.06 },
	}
end
local function parts(n: number, f: (number) -> any): { any }
	local p = {}
	for i = 1, n do
		p[i] = f(65535 - n + i)
	end
	return p
end
local function physics(worst: boolean)
	if worst then
		return { mass = RAW_W, balance = RAW_W, reach = RAW_W }
	end
	return { mass = 0.8352154327761091, balance = 0.17712345678901234, reach = 3.4201234567890123 }
end
local function analysis(nSteps: number, worst: boolean)
	local steps = {}
	for i = 1, nSteps do
		steps[i] = { step = STEP_IDS[i], difficulty = 0.1234, tier = "Master" }
	end
	local issues = {}
	for i = 1, (if worst then 8 else 0) do
		issues[i] = "BladeNotAboveGrip" -- 17 chars: longest S2 code
	end
	return { balanceVersion = 999, valid = not worst, issues = issues, physics = physics(worst), steps = steps }
end
local function blueprintRecord(n: number, f: (number) -> any, name: string, nSteps: number, worst: boolean)
	return {
		schema = 1,
		id = GUID,
		name = name,
		type = "Sword",
		parts = parts(n, f),
		revision = 9999999,
		createdAt = 1793404800,
		updatedAt = 1793491200,
		analysis = analysis(nSteps, worst),
	}
end
local function snapshot(n: number, f: (number) -> any, name: string)
	return { schema = 1, sourceId = GUID, sourceRevision = 9999999, name = name, type = "Sword", parts = parts(n, f) }
end
local function stepRecord(i: number, flags: { string })
	return {
		step = STEP_IDS[i],
		family = FAMILIES[i],
		tier = "Master",
		difficulty = 0.1234,
		material = "Obsidian",
		seed = 4294967295,
		score = 0.8734,
		passed = false,
		timedOut = false,
		durationMs = 123456,
		flags = flags,
	}
end
local function itemRecord(n: number, f: (number) -> any, name: string, nSteps: number, stats: { string }, worst: boolean)
	local steps = {}
	for i = 1, nSteps do
		local fl = if not worst then {} elseif nSteps == 3 then FLAGS_MVP[i] else FLAGS_LONG6
		steps[i] = stepRecord(i, fl)
	end
	local st = {}
	for _, k in stats do
		st[k] = 99.9999
	end
	return {
		id = GUID,
		name = name,
		type = "Sword",
		crafterUserId = 9876543210,
		createdAt = 1793404800,
		blueprint = snapshot(n, f, name),
		steps = steps,
		physics = physics(worst),
		outcome = {
			stats = st,
			quality = 1.2345,
			materialTier = 1.2345,
			rarity = "Legendary",
			rarityByScore = "Legendary",
			rarityCap = "Legendary",
			capStep = "Sharpening",
		},
		atForge = { balanceVersion = 999, quality = 1.2345, rarity = "Legendary" },
		balanceVersion = 999,
	}
end
local function ownerView(item: any)
	local v = table.clone(item)
	v.steps = {}
	for i, s in item.steps do
		local c = table.clone(s)
		c.flags = nil
		c.seed = nil
		v.steps[i] = c
	end
	return v
end

local function settings(worst: boolean)
	local step = if worst then RAW_W * -1 else 0.05
	return {
		snap = {
			move = { on = true, step = step },
			rotate = { on = false, step = if worst then RAW_W * -1 else 15 },
			scale = { on = true, step = step },
		},
		space = "Local",
		overlays = { grid = true, hitbox = true, physics = true },
		reducedMotion = false,
		timingOffsetMs = if worst then -120 else 0,
		sfxVolume = if worst then RAW_W * -1 else 1,
	}
end
local function template()
	return {
		dataVersion = 1,
		blueprints = {},
		items = {},
		smithy = { level = 1, displays = {} },
		settings = settings(false),
		uiFlags = {},
		quarantine = { blueprints = {}, items = {} },
		starterGranted = false,
	}
end

local LIMIT = 4194304
local WRAP = 300 -- ProfileStore wrapper allowance (MetaData, GlobalUpdates, UserIds)

local function filledProfile(nBp: number, nItems: number, nParts: number, nSteps: number, stats: { string }, f: (number) -> any, name: string, worst: boolean)
	local d: any = template()
	d.settings = settings(worst)
	d.starterGranted = true
	for i = 1, nBp do
		d.blueprints[string.sub(GUID, 1, 30) .. string.format("%06d", i)] = blueprintRecord(nParts, f, name, nSteps, worst)
	end
	for i = 1, nItems do
		d.items[string.sub(GUID, 1, 30) .. string.format("%06d", 500000 + i)] = itemRecord(nParts, f, name, nSteps, stats, worst)
	end
	for i = 1, 6 do
		d.smithy.displays["D" .. i] = GUID
	end
	if worst then -- Settings.sanitizeFlags bound: MAX_UI_FLAGS = 64 keys of UI_FLAG_KEY_MAX_BYTES = 32 bytes
		for i = 1, 64 do
			d.uiFlags["Onboarding." .. string.format("%021d", i)] = true
		end
	end
	return size(d) + WRAP
end

print("== per part ==")
print(("worst-case part %d B | typical axis-aligned %d B | typical free-rotated %d B"):format(
	size(worstPart(65535)), size(typicalPart(1)), size(typicalPart(3))))

local bp0 = size(blueprintRecord(0, worstPart, NAME_WORST, 3, true))
local bp24 = size(blueprintRecord(24, worstPart, NAME_WORST, 3, true))
local perPart = (bp24 - bp0) / 24
print(("== blueprint record == overhead (no parts, worst analysis, 3 steps) %d B; per worst part %.1f B"):format(bp0, perPart))
for _, n in { 4, 12, 24 } do
	print(("  N=%2d  worst %6d B   typical %6d B"):format(n, size(blueprintRecord(n, worstPart, NAME_WORST, 3, true)),
		size(blueprintRecord(n, typicalPart, "Long Sword", 3, false))))
end

local it0 = size(itemRecord(0, worstPart, NAME_WORST, 3, STATS_MVP, true))
local it0p2 = size(itemRecord(0, worstPart, NAME_WORST, 8, STATS_P2, true))
print(("== item record == overhead (no parts) MVP-worst %d B (3 steps, 6 stats); Phase2+-worst %d B (8 steps, 9 stats)"):format(it0, it0p2))
for _, n in { 4, 12, 24 } do
	print(("  N=%2d  MVP-worst %6d B   Phase2+-worst %6d B   typical %6d B"):format(n,
		size(itemRecord(n, worstPart, NAME_WORST, 3, STATS_MVP, true)),
		size(itemRecord(n, worstPart, NAME_WORST, 8, STATS_P2, true)),
		size(itemRecord(n, typicalPart, "Long Sword", 3, STATS_MVP, false))))
end
print(("one worst step record (6 flags) %d B; MVP PrecisionTrace step with its 6 flags %d B; no flags %d B"):format(
	size(stepRecord(3, FLAGS_LONG6)), size(stepRecord(3, FLAGS_MVP[3])), size(stepRecord(3, {}))))
print(("owner item view (no flags/seeds) @24 worst parts %d B"):format(size(ownerView(itemRecord(24, worstPart, NAME_WORST, 3, STATS_MVP, true)))))

print("== profile ==")
print(("empty template %d B; settings default %d B, worst %d B"):format(size(template()), size(settings(false)), size(settings(true))))
do
	local f = {}
	for i = 1, 64 do
		f["Onboarding." .. string.format("%021d", i)] = true
	end
	print(("uiFlags worst (64 keys x 32 B) %d B"):format(size(f)))
end
local cases = {
	{ 40, 150, 24, 3, STATS_MVP, "MVP item shape (caps 40/150, MAX_PARTS 24)" },
	{ 40, 150, 24, 8, STATS_P2, "Phase 2+ item shape (8 steps, 9 stats)" },
	{ 60, 250, 24, 3, STATS_MVP, "caps 60/250, MVP shape" },
	{ 80, 300, 24, 3, STATS_MVP, "caps 80/300, MVP shape" },
}
for _, c in cases do
	local s = filledProfile(c[1], c[2], c[3], c[4], c[5], worstPart, NAME_WORST, true)
	print(("  bp=%d items=%d parts=%d (%s): %8d B = %4.1f%% of 4 MiB"):format(c[1], c[2], c[3], c[6], s, 100 * s / LIMIT))
end
local honest = filledProfile(40, 150, 24, 3, STATS_MVP, typicalPart, NAME_WORST, false)
print(("  caps full of typical editor parts (40/150 x 24 parts, 64-B names): %d B = %.1f%%"):format(honest, 100 * honest / LIMIT))
local typ = filledProfile(15, 80, 12, 3, STATS_MVP, typicalPart, "Long Sword", false)
print(("  typical heavy player (15 bp, 80 items, 12 parts each): %d B = %.1f%%"):format(typ, 100 * typ / LIMIT))

print("== wire ==")
local draft = { schema = 1, name = NAME_WORST, type = "Sword", parts = parts(24, worstPart) }
print(("  worst BlueprintDraft @24 parts %d B (+ Save envelope: blueprintId %d B)"):format(size(draft), size({ blueprintId = GUID })))
local bpSummary = { id = GUID, name = NAME_WORST, type = "Sword", revision = 9999999, updatedAt = 1793491200, partCount = 24, materials = { "Steel", "Iron" }, analysis = analysis(3, true) }
local itemSummary = { id = GUID, name = NAME_WORST, type = "Sword", createdAt = 1793404800, materials = { "Steel", "Iron" }, quality = 1.2345, rarity = "Legendary", tiers = { "Normal", "Normal", "Normal" }, displaySlot = 6 }
local bpS, itS = size(bpSummary), size(itemSummary)
print(("  BlueprintSummary %d B; ItemSummary %d B; summaries at caps (40+150) %d B"):format(bpS, itS, 40 * bpS + 150 * itS))

local W0 = filledProfile(0, 0, 0, 3, STATS_MVP, worstPart, NAME_WORST, true)
local KEY = #('"' .. GUID .. '":') + 1 -- map key + comma per record
print(("== formula == W(B,I,P) = %d + B*(%d + %.1f*P) + I*(%d + %.1f*P)   [incl. %d B map key per record; Phase 2+ item overhead %d]"):format(
	W0, bp0 + KEY, perPart, it0 + KEY, perPart, KEY, it0p2 + KEY))
print(("  check: formula at 40/150/24 = %d B (measured above)"):format(math.floor(W0 + 40 * (bp0 + KEY + perPart * 24) + 150 * (it0 + KEY + perPart * 24) + 0.5)))
for _, w in { 1000000, 2000000 } do
	print(("  %d B profile: %d writes/min = %.2f MB/min (limit 4 MB/min)"):format(w, 2, 2 * w / 1e6))
end
