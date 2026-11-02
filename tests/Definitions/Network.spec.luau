--!strict
-- Definitions/Network (SPEC §7.8, §9.1, §10, §16.13; T-DEF-01/05/06): every server and protocol tunable, the rate
-- buckets of the request catalogue, the kick texts, and the arithmetic the SPEC derives from them (§7.8's deadline
-- example, §10.7's slow-motion bounds, the ping window, the queue and write budgets).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local CraftPlans = require("../../src/shared/Definitions/CraftPlans")
local Limits = require("../../src/shared/Definitions/Limits")
local MF = require("../../src/shared/Definitions/MinigameFamilies")
local Network = require("../../src/shared/Definitions/Network")
local World = require("../../src/shared/Definitions/World")

local PT_TRAVEL_MAX_MS = 30000 -- Minigames/PrecisionTrace (§16.22): the longest Trace travel

-- §16.13, every scalar
local SCALARS: { [string]: number } = {
	COUNTDOWN_MS = 3000,
	EARLY_TOL_MS = 250,
	LATE_SOFT_MS = 1500,
	LATE_HARD_MS = 5000,
	RTT_ALLOW_MAX_MS = 2000,
	MAX_PING_SAMPLES = 160,
	TICK_INTERVAL_MS = 250,
	READY_IDLE_TIMEOUT_MS = 120000,
	SESSION_MAX_MS = 600000,
	TOMBSTONE_MS = 60000,
	MAX_STEPS = 8,
	MAX_PAYLOAD_NODES = 6000,
	MAX_SETTINGS_NODES = 256,
	MAX_DRAFT_DEPTH = 4,
	MAX_BATCH_IDS = 12,
	REPLY_PAGE_BYTES = 32768,
	REQUEST_TIMEOUT_S = 20,
	HELLO_TIMEOUT_S = 120,
	LANE_CAP = 4,
	ANALYSIS_SLICE_MS = 4,
	ANALYSIS_QUEUE_CAP = 16,
	ANALYSIS_JOBS_PER_PLAYER = 1,
	RECOMPUTE_QUEUE_CAP = 64,
	RATE_LIMITED_REPLIES_PER_S = 5,
	FLOOD_KICK_DROPS_PER_MIN = 300,
	HARD_STRIKES_KICK = 10,
	TELEMETRY_RING = 2000,
	LOG_VALUE_MAX_BYTES = 64,
	SAVE_MIN_INTERVAL_S = 60,
	LOAD_TIMEOUT_S = 75,
}
local BUCKETS = { "RATE", "TELEMETRY_BUCKET", "LOG_BUCKET", "LOG_PLAYER_BUCKET" }

-- §10.2's request catalogue: {capacity, refill per s}
local RATE: { [string]: { number } } = {
	ProfileHello = { 2, 1 / 30 },
	ProfileSync = { 3, 1 / 10 },
	ProfileSetSettings = { 5, 1 / 2 },
	BlueprintGet = { 10, 2 },
	BlueprintSave = { 4, 1 / 3 },
	BlueprintRename = { 5, 1 / 2 },
	BlueprintDelete = { 5, 1 / 2 },
	CraftBegin = { 3, 1 / 10 },
	CraftStartStep = { 5, 1 / 2 },
	CraftSubmit = { 5, 1 / 2 },
	CraftAbandon = { 3, 1 / 5 },
	CraftResume = { 3, 1 / 5 },
	CraftReportDesync = { 3, 1 / 10 },
	ShowcasePlace = { 6, 1 },
	ShowcaseClear = { 6, 1 },
	ShowcaseScrap = { 5, 1 / 2 },
	ShowcaseInspect = { 10, 3 },
	ShowcaseGetItems = { 10, 2 },
	ShowcaseTeleportHome = { 1, 1 / 3 },
	Global = { 30, 15 },
}

local function walkData(v: any, path: string, seen: { [any]: string })
	if type(v) == "number" then
		A.finite(v, path)
	elseif type(v) == "table" then
		if seen[v] then
			A.fail(path .. " shares a table with " .. seen[v])
		end
		seen[v] = path
		A.truthy(table.isfrozen(v), path .. " is frozen")
		for k, child in v do
			A.eq(type(k), "string", path .. ": keys are strings")
			walkData(child, path .. "." .. tostring(k), seen)
		end
	elseif type(v) ~= "string" then
		A.fail(path .. " holds a " .. type(v))
	end
end

return Test.suite("Definitions/Network", function(t)
	t.it("§16.13 scalars, and no key the reference does not list", function()
		local net = Network :: any
		for _, name in Dump.sortedKeys(SCALARS) do
			A.eq(net[name], SCALARS[name], name)
		end
		for _, name in Dump.sortedKeys(net) do
			A.truthy(SCALARS[name] ~= nil or table.find(BUCKETS, name) ~= nil or name == "KICK", "unexpected key " .. name)
			A.truthy(string.match(name, "^%u[%u%d_]*$") ~= nil, name .. " is UPPER_SNAKE")
		end
		for name, value in SCALARS do
			A.truthy(value > 0 and value % 1 == 0, name .. " is a positive integer")
		end
	end)

	t.it("T-DEF-01 RATE has one bucket per request-catalogue action plus Global (§10.2)", function()
		local names = Dump.sortedKeys(Network.RATE)
		A.deepEq(names, Dump.sortedKeys(RATE), "bucket names")
		for _, name in names do
			local spec = Network.RATE[name]
			A.truthy(string.match(name, "^%u%a+$") ~= nil, name .. " is <Channel><Action>")
			A.eq(spec.capacity, RATE[name][1], name .. ".capacity")
			A.near(spec.refillPerSec, RATE[name][2], 1e-15, name .. ".refillPerSec")
			A.truthy(spec.capacity >= 1 and spec.capacity % 1 == 0, name .. ": integer capacity ≥ 1")
			A.truthy(spec.refillPerSec > 0, name .. ": refills")
			if name ~= "Global" then
				A.truthy(spec.capacity <= Network.RATE.Global.capacity, name .. " fits under the global bucket")
			end
		end
		local channels = { Profile = true, Blueprint = true, Craft = true, Showcase = true }
		for _, name in names do
			local channel = string.match(name, "^(%u%l+)")
			A.truthy(name == "Global" or channels[channel :: string] == true, name .. " starts with a channel")
		end
	end)

	t.it("T-DEF-05 telemetry and log buckets (§10.9)", function()
		A.deepEq(Network.TELEMETRY_BUCKET, { capacity = 20, refillPerSec = 0.25 }, "TELEMETRY_BUCKET")
		A.deepEq(Network.LOG_BUCKET, { capacity = 20, refillPerSec = 2 }, "LOG_BUCKET")
		A.deepEq(Network.LOG_PLAYER_BUCKET, { capacity = 5, refillPerSec = 0.5 }, "LOG_PLAYER_BUCKET")
		A.eq(Network.TELEMETRY_BUCKET.refillPerSec * 60, 15, "≤ 15 events/min/player")
		A.truthy(Network.LOG_PLAYER_BUCKET.capacity < Network.LOG_BUCKET.capacity, "a player cannot fill a tag's log")
	end)

	t.it("T-DEF-05 step timing windows (§7.8, §10.7)", function()
		local C, early, soft, hard = Network.COUNTDOWN_MS, Network.EARLY_TOL_MS, Network.LATE_SOFT_MS, Network.LATE_HARD_MS
		A.truthy(early < soft and soft < hard, "early < soft < hard")
		-- §7.8's example: D = 15 000, median ping 100 ms → A = 200
		local D, A_ = 15000, math.min(2 * 100, Network.RTT_ALLOW_MAX_MS)
		A.eq(D - early, 14750, "judged from E = 14 750")
		A.eq(D + soft + A_, 16700, "LateSubmit beyond 16 700")
		A.eq(D + hard + A_, 20200, "timed out beyond 20 200")
		A.eq(C + D + hard + A_ + Network.TICK_INTERVAL_MS, 23450, "swept by t_open + 23 450")
		-- §10.7's slow-motion bounds for that step with RTT = 100: flagged above k = 1.107, timed out above 1.340
		A.near(1 + (soft + A_ - 100) / D, 1.107, 5e-4, "flag bound")
		A.near(1 + (hard + A_ - 100) / D, 1.340, 5e-4, "timeout bound")
		-- the ping window covers the longest step, its countdown and full lateness at 4 Hz
		local longest = 0
		for _, row in MF.enabled do
			for _, p in row.params do
				if p.name == "durationMs" then
					longest = math.max(longest, p.base)
				end
			end
		end
		local trace = MF.get("PrecisionTrace")
		A.truthy(trace ~= nil, "PrecisionTrace")
		local leadIn, tail = 0, 0
		for _, p in (trace :: any).params do
			if p.name == "leadInMs" then
				leadIn = p.base
			elseif p.name == "tailMs" then
				tail = p.base
			end
		end
		longest = math.max(longest, leadIn + PT_TRAVEL_MAX_MS + tail) -- 31 s
		A.eq(longest, 31000, "longest step")
		A.eq(Network.MAX_PING_SAMPLES * Network.TICK_INTERVAL_MS, 40000, "40 s of 4 Hz samples")
		A.truthy(longest + C + hard <= Network.MAX_PING_SAMPLES * Network.TICK_INTERVAL_MS, "the window holds a step")
		-- clocks around a session
		A.truthy(Network.READY_IDLE_TIMEOUT_MS < Network.SESSION_MAX_MS, "idle limit below the session backstop")
		A.truthy(Network.SESSION_MAX_MS >= 453000, "above the ≈ 453 s compliant worst case")
		A.truthy(Network.TOMBSTONE_MS >= Network.TICK_INTERVAL_MS, "a tombstone outlives a sweep")
	end)

	t.it("T-DEF-05 request, queue and save budgets (§1.6, §9.7, §10.1)", function()
		A.truthy(Network.HELLO_TIMEOUT_S > Network.LOAD_TIMEOUT_S, "Hello outlasts the profile load")
		A.truthy(Network.REQUEST_TIMEOUT_S > 13, "above a full AnalysisQueue drain (≈ 13 s)")
		A.truthy(Network.ANALYSIS_QUEUE_CAP >= World.PLOT_COUNT * Network.ANALYSIS_JOBS_PER_PLAYER,
			"every player can hold a job")
		A.truthy(Network.MAX_STEPS >= #CraftPlans.Sword.steps and Network.MAX_STEPS >= 7, "Phase 2 plans fit the bound")
		A.truthy(Network.REPLY_PAGE_BYTES > MF.MAX_TIMELINE_BYTES, "the largest request (a Submit) fits a message")
		A.truthy(2 * Limits.PROFILE_SIZE_BLOCK_BYTES <= Limits.KEY_WRITE_BYTES_PER_MIN
			and Network.SAVE_MIN_INTERVAL_S >= 60, "≤ 2 writes a minute stay under the per-key limit")
		A.truthy(Network.MAX_SETTINGS_NODES < Network.MAX_PAYLOAD_NODES, "SetSettings has the tighter budget")
		A.eq(Network.ANALYSIS_SLICE_MS, 4, "4 ms slices (§1.6)")
	end)

	t.it("T-DEF-01 kick texts (§9.1)", function()
		A.deepEq(Network.KICK, {
			LOAD_FAILED = "We couldn't load your smithy. Please rejoin in a minute.",
			SESSION_ENDED = "Your smithy was opened on another server. Please rejoin.",
			NEWER_SCHEMA = "A newer version of the game is available. Please rejoin.",
			DATA_ERROR = "We couldn't open your smithy. Please contact support.",
			CLOSING = "This server is restarting. Please rejoin.",
			FULL = "This server is full. Please join another server.",
		}, "KICK")
		for _, key in Dump.sortedKeys(Network.KICK) do
			local text = Network.KICK[key]
			A.truthy(string.match(key, "^%u[%u_]*$") ~= nil, key .. " is UPPER_SNAKE")
			A.falsy(string.find(text, "%c"), key .. " has no control characters")
			A.truthy(string.match(text, "%.$") ~= nil, key .. " is a sentence")
		end
	end)

	t.it("T-DEF-06 finite and frozen", function()
		A.truthy(table.isfrozen(Network), "module frozen")
		walkData(Network, "Network", {})
	end)
end)
