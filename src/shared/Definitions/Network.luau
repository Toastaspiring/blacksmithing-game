--!strict
-- Definitions/Network (SPEC §1.6, §7.6–§7.8, §9.1, §9.7, §10, §16.13; owner S5): server and protocol tunables, one
-- deep-frozen table. They never change an outcome (§1.3 L5): the BALANCE Manifest excludes this module, so an edit
-- here needs no BALANCE_VERSION bump.
--   RATE      token buckets per (player, action), keyed <Channel><Action>, plus Global (§10.2, §10.4): `capacity`
--             tokens refilled continuously at `refillPerSec`, one token per request. The client self-throttles at
--             capacity − 1 and refill × 0.9.
--   KICK      kick texts (§9.1); S6 may restyle them.
-- Guard bounds owned elsewhere: MAX_TIMELINE_BYTES (Definitions/MinigameFamilies), DISPLAY_SLOTS and PLOT_COUNT
-- (Definitions/World).

local Catalog = require("./Catalog")

export type BucketSpec = { capacity: number, refillPerSec: number } -- Net/RateLimit's bucket (§10.4)

export type Network = {
	COUNTDOWN_MS: number,
	EARLY_TOL_MS: number,
	LATE_SOFT_MS: number,
	LATE_HARD_MS: number,
	RTT_ALLOW_MAX_MS: number,
	MAX_PING_SAMPLES: number,
	TICK_INTERVAL_MS: number,
	READY_IDLE_TIMEOUT_MS: number,
	SESSION_MAX_MS: number,
	TOMBSTONE_MS: number,
	MAX_STEPS: number,
	MAX_PAYLOAD_NODES: number,
	MAX_SETTINGS_NODES: number,
	MAX_DRAFT_DEPTH: number,
	MAX_BATCH_IDS: number,
	REPLY_PAGE_BYTES: number,
	REQUEST_TIMEOUT_S: number,
	HELLO_TIMEOUT_S: number,
	LANE_CAP: number,
	ANALYSIS_SLICE_MS: number,
	ANALYSIS_QUEUE_CAP: number,
	ANALYSIS_JOBS_PER_PLAYER: number,
	RECOMPUTE_QUEUE_CAP: number,
	RATE_LIMITED_REPLIES_PER_S: number,
	FLOOD_KICK_DROPS_PER_MIN: number,
	HARD_STRIKES_KICK: number,
	RATE: { [string]: BucketSpec },
	TELEMETRY_BUCKET: BucketSpec,
	TELEMETRY_RING: number,
	LOG_BUCKET: BucketSpec,
	LOG_PLAYER_BUCKET: BucketSpec,
	LOG_VALUE_MAX_BYTES: number,
	SAVE_MIN_INTERVAL_S: number,
	LOAD_TIMEOUT_S: number,
	KICK: { [string]: string },
}

local Network: Network = {
	-- ── step timing (§7.8): E = t_recv − t_open − C; judged in [D − EARLY_TOL_MS, D + LATE_SOFT_MS + A] ────────
	COUNTDOWN_MS = 3000, -- ms; 3-2-1 before each step, copied into StepSpec.countdownMs
	EARLY_TOL_MS = 250, -- ms; 0 honest refusals in 10⁶ simulated submissions
	LATE_SOFT_MS = 1500, -- ms; LateSubmit flag only, honest rate ≈ 1.3 %
	LATE_HARD_MS = 5000, -- ms; honest timeouts ≤ 3 per 10⁶
	RTT_ALLOW_MAX_MS = 2000, -- ms; cap of A = min(2 · median ping, cap)
	MAX_PING_SAMPLES = 160, -- samples; 40 s of 4 Hz samples (longest step 31 s + countdown + lateness)
	TICK_INTERVAL_MS = 250, -- ms; deadline and idle sweep, ping sampling
	READY_IDLE_TIMEOUT_MS = 120000, -- ms; results card plus walking to the next station
	SESSION_MAX_MS = 600000, -- ms; backstop above the ≈ 453 s compliant worst case
	TOMBSTONE_MS = 60000, -- ms; duplicates after the end get the stored reply

	-- ── Guard bounds and paging (§10.1–§10.3) ──────────────────────────────────────────────────────────────────
	MAX_STEPS = 8, -- steps; Phase 2 plans have up to 7 steps
	MAX_PAYLOAD_NODES = 6000, -- nodes; ≈ 13 × a 24-part Save (439 nodes)
	MAX_SETTINGS_NODES = 256, -- nodes; SetSettings budget, settings + 64 flags use 80
	MAX_DRAFT_DEPTH = 4, -- levels; nesting of S1's wire draft
	MAX_BATCH_IDS = 12, -- ids per Blueprint.Get / Showcase.GetItems (a visible page of tiles)
	REPLY_PAGE_BYTES = 32768, -- B (JSON length) per message; a snapshot at the caps ≈ 70 KB → 3 pages

	-- ── requests and lanes (§10.1, §10.3) ──────────────────────────────────────────────────────────────────────
	REQUEST_TIMEOUT_S = 20, -- s; above a full AnalysisQueue drain (≈ 13 s)
	HELLO_TIMEOUT_S = 120, -- s; Hello waits for the whole profile load (≈ 75–95 s worst, §9.1)
	LANE_CAP = 4, -- waiting mutating requests per (player, channel)

	-- ── AnalysisQueue (§1.6) ───────────────────────────────────────────────────────────────────────────────────
	ANALYSIS_SLICE_MS = 4, -- ms of server work per Heartbeat (§4.9)
	ANALYSIS_QUEUE_CAP = 16, -- P0 + P1 jobs; at most PLOT_COUNT × ANALYSIS_JOBS_PER_PLAYER = 8 are ever held
	ANALYSIS_JOBS_PER_PLAYER = 1, -- one P0/P1 job in flight per player
	RECOMPUTE_QUEUE_CAP = 64, -- stale-item recomputes (P2), deduped by item id

	-- ── rate limits and kicks (§10.4) ──────────────────────────────────────────────────────────────────────────
	RATE_LIMITED_REPLIES_PER_S = 5, -- replies/s per player: a flood must not double outbound traffic
	FLOOD_KICK_DROPS_PER_MIN = 300, -- global drops in 60 s; 10 × what a buggy honest client produces
	HARD_STRIKES_KICK = 10, -- Hard strikes per server session; honest clients produce 0
	RATE = {
		ProfileHello = { capacity = 2, refillPerSec = 1 / 30 }, -- once per join plus one client restart
		ProfileSync = { capacity = 3, refillPerSec = 1 / 10 }, -- resync after an error; paged snapshot
		ProfileSetSettings = { capacity = 5, refillPerSec = 1 / 2 }, -- S6 debounces settings
		BlueprintGet = { capacity = 10, refillPerSec = 2 }, -- library thumbnails, 12 ids per call
		BlueprintSave = { capacity = 4, refillPerSec = 1 / 3 }, -- manual saves + 60 s autosave; one analysis each
		BlueprintRename = { capacity = 5, refillPerSec = 1 / 2 }, -- list management
		BlueprintDelete = { capacity = 5, refillPerSec = 1 / 2 }, -- list management
		CraftBegin = { capacity = 3, refillPerSec = 1 / 10 }, -- a craft lasts ≥ 30 s
		CraftStartStep = { capacity = 5, refillPerSec = 1 / 2 }, -- 3 steps per craft plus desync re-opens
		CraftSubmit = { capacity = 5, refillPerSec = 1 / 2 }, -- one per step
		CraftAbandon = { capacity = 3, refillPerSec = 1 / 5 }, -- rare
		CraftResume = { capacity = 3, refillPerSec = 1 / 5 }, -- client UI restart
		CraftReportDesync = { capacity = 3, refillPerSec = 1 / 10 }, -- rare; never a re-roll
		ShowcasePlace = { capacity = 6, refillPerSec = 1 }, -- rearranging the smithy
		ShowcaseClear = { capacity = 6, refillPerSec = 1 }, -- rearranging the smithy
		ShowcaseScrap = { capacity = 5, refillPerSec = 1 / 2 }, -- inventory clean-up
		ShowcaseInspect = { capacity = 10, refillPerSec = 3 }, -- browsing stands; cache-only names
		ShowcaseGetItems = { capacity = 10, refillPerSec = 2 }, -- inventory grid, 12 ids per call
		ShowcaseTeleportHome = { capacity = 1, refillPerSec = 1 / 3 }, -- one per 3 s (S6 HUD "My smithy")
		Global = { capacity = 30, refillPerSec = 15 }, -- all of a player's requests, ≈ 10 × the honest peak
	},

	-- ── telemetry and logs (§10.9) ─────────────────────────────────────────────────────────────────────────────
	TELEMETRY_BUCKET = { capacity = 20, refillPerSec = 0.25 }, -- ≤ 15 events/min/player (platform 20/min/CCU)
	TELEMETRY_RING = 2000, -- records; the Studio/playtest ring S8's bridge reads
	LOG_BUCKET = { capacity = 20, refillPerSec = 2 }, -- lines per (tag, event), then one `suppressed=N` line
	LOG_PLAYER_BUCKET = { capacity = 5, refillPerSec = 0.5 }, -- lines per (player, tag, event): no log flooding
	LOG_VALUE_MAX_BYTES = 64, -- B; client-originated strings in log values

	-- ── persistence (§9.1, §9.7) ───────────────────────────────────────────────────────────────────────────────
	SAVE_MIN_INTERVAL_S = 60, -- s after any write: ≤ 2 writes/min ≤ 4 MB/min at S1's size block
	LOAD_TIMEOUT_S = 75, -- s; longer than a session steal (≈ 45 s) plus back-off
	KICK = { -- never a blank profile
		LOAD_FAILED = "We couldn't load your smithy. Please rejoin in a minute.",
		SESSION_ENDED = "Your smithy was opened on another server. Please rejoin.",
		NEWER_SCHEMA = "A newer version of the game is available. Please rejoin.",
		DATA_ERROR = "We couldn't open your smithy. Please contact support.",
		CLOSING = "This server is restarting. Please rejoin.",
		FULL = "This server is full. Please join another server.",
	},
}

return Catalog.deepFreeze(Network)
