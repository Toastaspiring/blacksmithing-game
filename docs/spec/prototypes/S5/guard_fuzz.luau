--!strict
-- Fuzz + cost measurement for the Guard prototype (Lune 0.8.9): lune run guard_fuzz.luau
-- Revised to the final catalogue: Submit carries a buffer timeline, Save = {blueprintId, draft},
-- SetSettings = {settings, uiFlags}, ReportDesync, TeleportHome.
local G = require("./lib/Guard")

local MAX_TIMELINE_BYTES = 12 + 2048 * 7 -- 14,348 (S3 header + largest family cap)
local MAX_PAYLOAD_NODES = 6000
local MAX_SETTINGS_NODES = 256

local submitArgs = G.rec({
	sessionId = G.guid(),
	stepIndex = G.int(1, 8),
	timeline = G.buffer(MAX_TIMELINE_BYTES),
	clientScore = G.num(0, 1),
})
local placeArgs = G.rec({ slotIndex = G.int(1, 6), itemId = G.guid() })
local saveArgs = G.rec({ blueprintId = G.guid(), draft = G.plain(4) })
local settingsArgs = G.rec({ settings = G.plain(3), uiFlags = G.plain(1) })
local desyncArgs = G.rec({ sessionId = G.guid(), stepIndex = G.int(1, 8), clientHash = G.int(0, 4294967295) })
local homeArgs = G.rec({})

local VALIDATORS = {
	{ "Submit", submitArgs, MAX_PAYLOAD_NODES },
	{ "Place", placeArgs, MAX_PAYLOAD_NODES },
	{ "Save", saveArgs, MAX_PAYLOAD_NODES },
	{ "SetSettings", settingsArgs, MAX_SETTINGS_NODES },
	{ "ReportDesync", desyncArgs, MAX_PAYLOAD_NODES },
	{ "TeleportHome", homeArgs, MAX_PAYLOAD_NODES },
}

math.randomseed(12345)
local weird = { 0 / 0, math.huge, -math.huge, -0, 2 ^ 53, -2 ^ 63, 0.5, 1e308, -1, 1, 3, 4096, 2 ^ 31, 2 ^ 32 }
local strings = { "", "Blade", "Sword", "\255\254", "a\0b", string.rep("x", 5000), "ÉpéeÉpée",
	"00000000-0000-0000-0000-000000000000", "\n[blacksmith:craft][E] forged", "Steel", "settings", "timeline" }

local function randBuffer(): buffer
	local sizes = { 0, 1, 11, 12, 13, 1036, 3084, 14347, 14348, 14349, 20000 }
	local b = buffer.create(sizes[math.random(1, #sizes)])
	for i = 0, math.min(buffer.len(b), 64) - 1 do
		buffer.writeu8(b, i, math.random(0, 255))
	end
	return b
end

local function randValue(depth: number): any
	local r = math.random(1, 11)
	if r == 1 then
		return nil
	elseif r == 2 then
		return math.random() < 0.5
	elseif r <= 4 then
		if math.random() < 0.5 then
			return weird[math.random(1, #weird)]
		end
		return (math.random() - 0.5) * 10 ^ math.random(0, 12)
	elseif r <= 6 then
		return strings[math.random(1, #strings)]
	elseif r == 7 then
		return randBuffer()
	else
		if depth > 4 then
			return {}
		end
		local t = {}
		local kind = math.random(1, 4)
		local big = depth == 0 and math.random() < 0.05
		if big then
			kind = 4
		end
		local n = math.random(0, if big then 6000 else 6)
		for i = 1, n do
			if kind == 1 then
				t[i] = randValue(depth + 1)
			elseif kind == 2 then
				t[strings[math.random(1, #strings)] .. tostring(i % 3)] = randValue(depth + 1)
			elseif kind == 3 then
				t[if math.random() < 0.5 then i else "k" .. i] = randValue(depth + 1)
			else
				t[math.random(1, 2 * n + 1)] = math.random(-1000000, 1000000) * 2000
			end
		end
		if math.random() < 0.3 then -- plausible keys so deeper branches run
			t.sessionId = "0f8fad5b-d9cb-469f-a165-70867728950e"
			t.stepIndex = math.random(0, 9)
			t.timeline = randBuffer()
			t.clientScore = weird[math.random(1, #weird)]
			t.settings = { snapMove = { on = true, step = 0.05 }, ["\nevil"] = 1 }
			t.uiFlags = { ["TipsHidden.Smelting"] = true }
		end
		return t
	end
end

local N = 50000
local exceptions, accepted, ctrlInErr = 0, 0, 0
local t0 = os.clock()
for _ = 1, N do
	local v = randValue(0)
	for _, spec in VALIDATORS do
		local ok, res, err = pcall(G.check, spec[2], v, spec[3])
		if not ok then
			exceptions += 1
			if exceptions <= 3 then
				print("EXCEPTION:", res)
			end
		elseif res == true then
			accepted += 1
		elseif type(err) == "string" and string.find(err, "[%c\127]") then
			ctrlInErr += 1
		end
	end
end
local dt = os.clock() - t0
print(string.format("fuzz: %d payloads x %d validators: %d exceptions, %d accepted, %d errors with control chars, %.2f us/check",
	N, #VALIDATORS, exceptions, accepted, ctrlInErr, dt / (#VALIDATORS * N) * 1e6))

local GUID = "0F8FAD5B-D9CB-469F-A165-70867728950E"
local function bench(name: string, validator, value, iters: number, nodes: number)
	local ok, err = G.check(validator, value, nodes)
	local t = os.clock()
	for _ = 1, iters do
		G.check(validator, value, nodes)
	end
	local b = { nodes = 1e9 }
	validator(value, "args", b)
	print(string.format("%-40s ok=%-5s %-28s %7.2f us/check  nodes %d", name, tostring(ok), tostring(err), (os.clock() - t) / iters * 1e6, 1e9 - b.nodes))
end
bench("Submit, Trace cap 14,348 B", submitArgs, { sessionId = GUID, stepIndex = 3, timeline = buffer.create(14348), clientScore = 0.734 }, 20000, MAX_PAYLOAD_NODES)
bench("Submit, 14,349 B (oversize)", submitArgs, { sessionId = GUID, stepIndex = 3, timeline = buffer.create(14349), clientScore = 0.734 }, 20000, MAX_PAYLOAD_NODES)
bench("Submit, timeline as a table", submitArgs, { sessionId = GUID, stepIndex = 3, timeline = { 1, 2, 3 }, clientScore = 0.734 }, 20000, MAX_PAYLOAD_NODES)
local parts = {}
for i = 1, 24 do
	parts[i] = { id = i, slot = "Blade", shape = "Wedge", material = "Steel", pos = { 0.1234567891, i * 0.2, 0 }, rot = { 0, 0, 0.70710678118, 0.70710678118 }, size = { 0.4, 1.2, 0.1 } }
end
local draft = { schema = 1, name = "Lame du Nord", type = "Sword", parts = parts }
bench("Blueprint.Save, plain(4), 24 parts", saveArgs, { blueprintId = GUID, draft = draft }, 5000, MAX_PAYLOAD_NODES)
local settings = { snap = { move = { on = true, step = 0.05 }, rotate = { on = false, step = 15 }, scale = { on = true, step = 0.05 } },
	reducedMotion = false, timingOffsetMs = -31, sfxVolume = 0.8 }
local flags = {}
for i = 1, 64 do
	flags["TipsHidden.S" .. i] = true
end
bench("SetSettings (64 uiFlags)", settingsArgs, { settings = settings, uiFlags = flags }, 20000, MAX_SETTINGS_NODES)
local flags2 = table.clone(flags)
for i = 65, 300 do
	flags2["TipsHidden.S" .. i] = true
end
bench("SetSettings (300 uiFlags: over node cap)", settingsArgs, { settings = settings, uiFlags = flags2 }, 2000, MAX_SETTINGS_NODES)
bench("ReportDesync", desyncArgs, { sessionId = GUID, stepIndex = 2, clientHash = 123456789 }, 20000, MAX_PAYLOAD_NODES)
bench("TeleportHome", homeArgs, {}, 20000, MAX_PAYLOAD_NODES)
bench("Showcase.Place", placeArgs, { slotIndex = 3, itemId = GUID }, 20000, MAX_PAYLOAD_NODES)
local okDeep, errDeep = G.check(saveArgs, { blueprintId = GUID, draft = { a = { b = { c = { d = { 1 } } } } } }, MAX_PAYLOAD_NODES)
print("5-deep draft rejected:", not okDeep, errDeep)
local okKey, errKey = G.check(saveArgs, { blueprintId = GUID, draft = { ["x\n[blacksmith:ac][E] fake"] = { a = { b = { c = { 1 } } } } } }, MAX_PAYLOAD_NODES)
print("hostile key in a path is masked:", errKey)
