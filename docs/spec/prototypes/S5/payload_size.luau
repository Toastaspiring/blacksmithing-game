--!strict
-- Rough wire-size estimates for the main remote payloads (Lune 0.8.9): lune run payload_size.luau
-- MODEL (not a measurement; Roblox does not expose remote payload sizes): number 9 B, boolean 2 B, nil 1 B,
-- string 2 B + bytes, table 3 B + entries, dictionary key = string encoding, buffer 3 B + bytes (before compression).
-- Revised: Submit carries S3's buffer; StartStep reply = S3 StepSpec + session fields (incl. a 256-point source);
-- Save = {blueprintId, draft} with raw doubles and camelCase; GUID ids.
local function est(v: any): number
	local t = type(v)
	if t == "nil" then
		return 1
	elseif t == "boolean" then
		return 2
	elseif t == "number" then
		return 9
	elseif t == "string" then
		return 2 + #v
	elseif t == "buffer" then
		return 3 + buffer.len(v)
	elseif t == "table" then
		local n = 3
		local len = rawlen(v)
		for k, x in next, v do
			if type(k) == "number" and k >= 1 and k <= len and k % 1 == 0 then
				n += est(x)
			else
				n += est(tostring(k)) + est(x)
			end
		end
		return n
	end
	return 0
end

local GUID = "0F8FAD5B-D9CB-469F-A165-70867728950E"
local function row(name: string, v: any)
	print(string.format("  %-52s ~%8.2f KB", name, est(v) / 1024))
end
local function envelope(action: string, args: any)
	return { action, 41, args }
end
local function submit(bytes: number)
	return envelope("Submit", { sessionId = GUID, stepIndex = 3, timeline = buffer.create(bytes), clientScore = 0.734 })
end
print("Craft.Submit (C->S), S3 buffer sizes:")
row("HoldZone typical 96 B", submit(96))
row("TimingStrike typical 42 B", submit(42))
row("PrecisionTrace typical 5,381 B", submit(5381))
row("PrecisionTrace cap 14,348 B (= MAX_TIMELINE_BYTES)", submit(14348))

local function part(i: number)
	return { id = i, slot = "Blade", shape = "Wedge", material = "Steel", pos = { 0.12345678901234, i * 0.2034567, -0.01234567 },
		rot = { 0.01234567, 0.0123, 0.70710678118655, 0.70699999999999 }, size = { 0.40123456789, 1.2512345678, 0.1012345678 } }
end
local function save(n: number)
	local parts = {}
	for i = 1, n do
		parts[i] = part(i)
	end
	return envelope("Save", { blueprintId = GUID, draft = { schema = 1, name = "Lame du Nord", type = "Sword", parts = parts } })
end
print("Blueprint.Save (C->S), raw doubles:")
row("12 parts", save(12))
row("24 parts (MAX_PARTS)", save(24))

local source = {}
for i = 1, 512 do
	source[i] = (i * 7919) % 49152
end
local spec = { family = "PrecisionTrace", seed = 3735928559, params = { pacerSpeed = 0.3, bandWidth = 0.05, travelMs = 26000, passThreshold = 0.5 },
	source = source, durationMs = 27000, countdownMs = 3000, patternHash = 2882400001, balanceVersion = 1 }
local open = table.clone(spec) :: any
open.sessionId, open.stepIndex, open.stepId, open.tier, open.lateAllowanceMs = GUID, 3, "Sharpening", "Hard", 1740
print("Other S->C:")
row("Craft.StartStep reply, PrecisionTrace (256-point source)", envelope("StartStep", { ok = true, data = { step = open } }))
local ts = table.clone(spec) :: any
ts.family, ts.source, ts.params = "TimingStrike", nil, { strikes = 15, cycleMs = 765, windowMs = 54, perfectMs = 15, passThreshold = 0.5 }
ts.sessionId, ts.stepIndex, ts.stepId, ts.tier, ts.lateAllowanceMs = GUID, 2, "Hammering", "Hard", 1740
row("Craft.StartStep reply, TimingStrike", envelope("StartStep", { ok = true, data = { step = ts } }))
local stats = {}
for _, id in { "Damage", "Sharpness", "Durability", "Purity", "Balance", "Reach" } do
	table.insert(stats, { id = id, value = 41.3 })
end
local history = {}
for _, st in { "Smelting", "Hammering", "Sharpening" } do
	table.insert(history, { step = st, tier = "Hard", score = 0.8125, passed = true })
end
local view = { v = 1, itemId = GUID, plotIndex = 3, slotIndex = 2, displayName = "Lame du Nord", equipmentType = "Sword",
	rarity = "Epic", rarityCap = "Epic", capStep = "Smelting", quality = 1.0412, crafter = { userId = 1234567890, displayName = "Louis", name = "lmarec" },
	createdAt = 1793404800, materials = { { slot = "Blade", materials = { "Steel" } }, { slot = "Grip", materials = { "Iron" } } },
	physics = { mass = 2.07, balanceOffset = 0.31, reach = 4.2 }, stats = stats, history = history, hardestTier = "Hard", balanceVersion = 1 }
row("Showcase.Inspect reply (S7 InspectView)", envelope("Inspect", { ok = true, data = { view = view } }))
