--!strict
-- Definitions/MinigameFamilies (SPEC §2.6, §6.5–§6.10, §10.6, §16.12, E-S3.3; owner S3): the six minigame families
-- as one catalog (Catalog.build: ordered, enabled, byId, get, isEnabled) with every family parameter, material, tier
-- and design columns included, the inhuman-input thresholds (`checks`) and flag levels (`flagLevels`), plus the
-- timeline wire constants (§6.7). Definitions hold no other minigame modifiers (§2.4). Deep-frozen at require time.
-- In the BALANCE Manifest: everything but the display `name` (§2.8), so any value change bumps BALANCE_VERSION.
--
-- p_final = round_q(clamp(base · m_material · m_tier · m_design, min, max))        (§6.5; Minigames/Params applies it)
--   material     lookup by the step's governing material (§7.2); a missing material means × 1
--   tier         columns Normal, Hard, Expert, Master, Hell (Tiers order); Expert…Hell are placeholders, not enabled
--                (E-S3.3); a missing column means × 1
--   design       m_design = clamp(1 + Σ k·clamp(x_f, 0, 1), designClamp[1], designClamp[2]) over the terms, which
--                are in FactorId order; x_f from PrepareInput.factors (missing = 0). Design sets (§5.2): Smelting
--                Volume; Hammering Thinness, Asymmetry, SurfaceComplexity; Sharpening SurfaceComplexity, Asymmetry
--                (EdgeLength acts through the path length)
--   min, max     clamp bounds; nil = unbounded
--   quantum      round_q(v) = quantum · math.round(v / quantum): 1 for counts and TimingStrike ms, 10 ms for HoldZone
--                and TimingStrike durations, 20 ms for Trace durations; nil = not rounded
-- Every family carries passThreshold = 0.50 as a parameter (one pass line "everywhere", §6.5, §16.12, Q8; a tier
-- column is the Phase 2 hook for per-tier pass lines, §15.1). MVP: HoldZone (Smelting), TimingStrike (Hammering),
-- PrecisionTrace (Sharpening); RhythmSequence, ReleaseTiming and FitPuzzle are Phase 2 rows that carry only the pass
-- line so far (no other parameters, checks or flags yet).

local Catalog = require("./Catalog")
local DT = require("./Types")

-- ── record types (§6.5) ───────────────────────────────────────────────────────────────────────────────────────

export type DesignTerm = { factor: DT.FactorId, k: number } -- ordered arrays, FactorId order
export type MinigameParamDef = {
	name: string,
	base: number,
	material: { [DT.MaterialId]: number }?,
	tier: { number }?,
	design: { DesignTerm }?,
	designClamp: { number }?,
	quantum: number?,
	min: number?,
	max: number?,
}
export type MinigameFamilyDef = {
	id: DT.FamilyId,
	name: string,
	order: number,
	enabled: boolean,
	params: { MinigameParamDef },
	checks: { { name: string, value: number } }, -- thresholds (§10.6)
	-- FlagId values (§6.2); read by the judge's clamp (§10.5), fromCraft's order (§9.4) and S8
	flagLevels: { { flag: string, level: "High" | "Medium" } },
}

-- ── rows ──────────────────────────────────────────────────────────────────────────────────────────────────────

-- One design term. A typed constructor, because a literal inside the optional `design` column would widen its
-- factor to `string`.
local function term(factor: DT.FactorId, k: number): DesignTerm
	return { factor = factor, k = k }
end

local ROWS: { MinigameFamilyDef } = {
	{
		-- Smelting (§6.8): each press is one bellows stroke; keep the ore in the drifting zone
		id = "HoldZone",
		name = "Hold Zone",
		order = 1,
		enabled = true,
		params = {
			{ -- gauge; 117 °C band on the 300–1600 °C gauge
				name = "zoneWidth",
				base = 0.090,
				material = { Steel = 0.98 },
				tier = { 1, 0.96, 0.88, 0.80, 0.72 },
				design = { term("Volume", -0.10) },
				designClamp = { 0.9, 1 },
			},
			{ -- gauge/s, zone speed while moving
				name = "driftSpeed",
				base = 0.21,
				material = { Steel = 1.01 },
				tier = { 1, 1.05, 1.15, 1.25, 1.35 },
				design = { term("Volume", 0.15) },
				designClamp = { 1, 1.15 },
			},
			{ name = "heatDecay", base = 1.0, tier = { 1, 1.05, 1.12, 1.20, 1.28 } }, -- 1/s, needle responsiveness
			{ name = "fullHeat", base = 2.4 }, -- gauge; steady T ≤ 0.96 at the refill rate
			{ name = "strokeGain", base = 0.25 }, -- fire; one stroke from rest: +0.17 T
			{ name = "refillMs", base = 250, quantum = 10 }, -- useful tap rate ≤ 4/s
			{ name = "fireDecayMs", base = 600, quantum = 10 }, -- fire dies down between strokes
			{ name = "targetMin", base = 0.40, material = { Steel = 1.08 } }, -- zone centre range; Steel needs more heat
			{ name = "targetMax", base = 0.80, material = { Steel = 1.04 } },
			{ name = "segMinMs", base = 900, tier = { 1, 0.9, 0.8, 0.7, 0.6 }, quantum = 10 }, -- zone direction changes
			{ name = "segMaxMs", base = 2200, tier = { 1, 0.9, 0.8, 0.7, 0.6 }, quantum = 10 },
			{ name = "holdChance", base = 0.25, tier = { 1, 0.8, 0.6, 0.4, 0.2 } }, -- stationary breathers
			{ -- 12 s scored after a heat-up
				name = "durationMs",
				base = 15000,
				tier = { 1, 1, 1.1, 1.2, 1.3 },
				design = { term("Volume", 0.20) },
				designClamp = { 1, 1.2 },
				quantum = 10,
			},
			{ name = "rampMs", base = 3000, quantum = 10 }, -- unscored heat-up
			{ name = "softFrac", base = 0.5 }, -- × zoneWidth: partial credit near the zone
			{ name = "passThreshold", base = 0.50 },
		},
		checks = {
			{ name = "HZ_RATE_WINDOW_MS", value = 1000 }, -- ms
			{ name = "HZ_RATE_MAX_PRESSES", value = 30 }, -- presses per window; humans ≤ 9
		},
		flagLevels = {
			{ flag = "HzInhumanRate", level = "High" },
		},
	},
	{
		-- Hammering (§6.9): strike on the beat, 12 strikes at Normal, 15 at Hard
		id = "TimingStrike",
		name = "Timing Strike",
		order = 2,
		enabled = true,
		params = {
			{ -- count; ≥ 8 for the variance check
				name = "strikes",
				base = 12,
				tier = { 1, 1.25, 1.5, 1.75, 2 },
				quantum = 1,
				min = 8,
				max = 32,
			},
			{ -- ms, rhythm speed
				name = "beatMs",
				base = 900,
				material = { Steel = 0.98 },
				tier = { 1, 0.85, 0.75, 0.65, 0.58 },
				design = { term("SurfaceComplexity", -0.10) },
				designClamp = { 0.9, 1 },
				quantum = 1,
				min = 450,
			},
			{ -- ms, the half-window in which a strike scores; sized for about 25 ms of display lag
				name = "windowMs",
				base = 110,
				material = { Steel = 0.98 },
				tier = { 1, 0.94, 0.80, 0.70, 0.60 },
				design = { term("Thinness", -0.15) },
				designClamp = { 0.85, 1 },
				quantum = 1,
				min = 20,
			},
			{ name = "perfectFrac", base = 0.12, tier = { 1, 0.80, 0.70, 0.60, 0.50 } }, -- × W: full-points core
			{ name = "edgePoints", base = 0.20, tier = { 1, 0.50, 0.40, 0.30, 0.20 } }, -- points at the window edge
			{ -- ± × P, irregular rhythm
				name = "tempoJitter",
				base = 0.08,
				tier = { 1, 1.5, 2, 2.5, 3 },
				design = { term("Asymmetry", 0.5) },
				designClamp = { 1, 1.5 },
				max = 0.30,
			},
			{ name = "offsetMin", base = 0.40 }, -- × P; read each cycle, spans never overlap
			{ name = "offsetMax", base = 0.75 },
			{ name = "missPadMs", base = 90, quantum = 1 }, -- near presses are Misses
			{ name = "tailMs", base = 400, quantum = 10 }, -- tail after the last cycle
			{ name = "passThreshold", base = 0.50 },
		},
		checks = {
			{ name = "TS_MIN_JUDGED", value = 8 }, -- judged strikes
			{ name = "TS_MIN_SD_MS", value = 1.5 }, -- ms, sample SD; FP ≤ 1.1e-5 at σ 10 ms
			{ name = "TS_EXACT_MS", value = 1 }, -- ms; exact-time macros
			{ name = "TS_EXACT_FRAC", value = 0.90 },
		},
		flagLevels = {
			{ flag = "TsLowVariance", level = "High" },
			{ flag = "TsExactHits", level = "High" },
		},
	},
	{
		id = "RhythmSequence", -- Phase 2 (Finishing)
		name = "Rhythm Sequence",
		order = 3,
		enabled = false,
		params = { { name = "passThreshold", base = 0.50 } },
		checks = {},
		flagLevels = {},
	},
	{
		-- Sharpening (§6.10): grind the blade's own edge behind the pacer spark; u = panel units (height 1)
		id = "PrecisionTrace",
		name = "Precision Trace",
		order = 4,
		enabled = true,
		params = {
			{ -- u; 21 px at 520 px
				name = "halfWidth",
				base = 0.041,
				material = { Steel = 0.98 },
				tier = { 1, 0.95, 0.85, 0.76, 0.68 },
				design = { term("SurfaceComplexity", -0.10) },
				designClamp = { 0.9, 1 },
				min = 0.012,
			},
			{ -- u/s; sets the duration
				name = "pacerSpeed",
				base = 0.30,
				material = { Steel = 1.01 },
				tier = { 1, 1.05, 1.15, 1.25, 1.35 },
				design = { term("Asymmetry", 0.15) },
				designClamp = { 1, 1.15 },
			},
			{ name = "paceTol", base = 0.12, tier = { 1, 0.85, 0.7, 0.6, 0.5 } }, -- arc u; ±0.4 s at full credit
			{ name = "paceFall", base = 0.24, tier = { 1, 0.85, 0.7, 0.6, 0.5 } },
			{ -- u, grind irregularities
				name = "perturbAmp",
				base = 0.020,
				tier = { 1, 1.25, 1.5, 1.75, 2 },
				design = { term("SurfaceComplexity", 0.5) },
				designClamp = { 1, 1.5 },
			},
			{ name = "bumpDensity", base = 1.0, tier = { 1, 1.3, 1.6, 1.9, 2.2 } }, -- /u, path complexity
			{ name = "bumpWidth", base = 0.25, tier = { 1, 0.9, 0.8, 0.7, 0.6 } }, -- u
			{ name = "coreFrac", base = 0.10 }, -- × w; accuracy stays a gradient
			{ name = "wAccuracy", base = 0.70 }, -- accuracy is the skill, pace the guard
			{ name = "leadInMs", base = 600, quantum = 20 }, -- the spark waits at the start
			{ name = "tailMs", base = 400, quantum = 20 },
			{ name = "passThreshold", base = 0.50 },
		},
		checks = {
			{ name = "PT_PRECISE_MIN_SAMPLES", value = 40 }, -- grinding samples in travel
			{ name = "PT_PRECISE_MEAN_DEV", value = 0.0008 }, -- u (0.4 px at 520 px); human minimum × 3.5
			{ name = "PT_SMOOTH_MIN_TRIPLETS", value = 150 }, -- moving triplets
			{ name = "PT_SMOOTH_MEAN_JERK", value = 0.0002 }, -- u; human minimum × 19
			{ name = "PT_SMOOTH_MIN_MOVE", value = 0.002 }, -- u, a moving triplet's span
			{ name = "PT_SMOOTH_DT_MIN_MS", value = 10 }, -- ms; a moving triplet's two intervals lie in [min, max]
			{ name = "PT_SMOOTH_DT_MAX_MS", value = 40 }, -- ms
			{ name = "PT_TELEPORT_DIST", value = 0.25 }, -- u
			{ name = "PT_TELEPORT_MAX_DT", value = 40 }, -- ms
			{ name = "PT_TELEPORT_COUNT", value = 3 }, -- grinding steps
			{ name = "PT_SPARSE_FRAC", value = 0.5 }, -- × travelMs/20
		},
		flagLevels = {
			{ flag = "PtTooPrecise", level = "High" },
			{ flag = "PtTooSmooth", level = "Medium" },
			{ flag = "PtTeleport", level = "Medium" },
			{ flag = "PtSparse", level = "Medium" },
		},
	},
	{
		id = "ReleaseTiming", -- Phase 2 (Quenching)
		name = "Release Timing",
		order = 5,
		enabled = false,
		params = { { name = "passThreshold", base = 0.50 } },
		checks = {},
		flagLevels = {},
	},
	{
		id = "FitPuzzle", -- Phase 2 (Assembly)
		name = "Fit Puzzle",
		order = 6,
		enabled = false,
		params = { { name = "passThreshold", base = 0.50 } },
		checks = {},
		flagLevels = {},
	},
}

-- ── module ────────────────────────────────────────────────────────────────────────────────────────────────────

local catalog = Catalog.build(ROWS)

-- Catalog.Catalog<MinigameFamilyDef> (the catalog views, as every catalog module returns them) plus the wire constants
export type MinigameFamilies = {
	ordered: { MinigameFamilyDef },
	enabled: { MinigameFamilyDef },
	byId: { [string]: MinigameFamilyDef },
	get: (id: string) -> MinigameFamilyDef?,
	isEnabled: (id: string) -> boolean,
	TIMELINE_FORMAT_VERSION: number,
	TIMELINE_HEADER_BYTES: number,
	FAMILY_CODE: { [DT.FamilyId]: number },
	RECORD_BYTES: { [DT.FamilyId]: number },
	MAX_RECORDS: { [DT.FamilyId]: number },
	MAX_TIMELINE_BYTES: number,
}

local MinigameFamilies: MinigameFamilies = {
	ordered = catalog.ordered,
	enabled = catalog.enabled,
	byId = catalog.byId,
	get = catalog.get,
	isEnabled = catalog.isEnabled,

	-- timeline wire format (§6.7): a little-endian buffer, a 12-byte header (u8 version, u8 family code, u16 count,
	-- u32 durationMs, u32 patternHash), then at most MAX_RECORDS records of RECORD_BYTES each: HoldZone u16 dtMs +
	-- u8 kind, TimingStrike u16 dtMs, PrecisionTrace u16 dtMs + u16 uQ + u16 vQ + u8 flags. The caps sit above every
	-- honest maximum (Trace 1,551 records); a family's own cap is 12 + MAX_RECORDS · RECORD_BYTES (Submit, §10.3).
	TIMELINE_FORMAT_VERSION = 1,
	TIMELINE_HEADER_BYTES = 12, -- B
	FAMILY_CODE = { HoldZone = 1, TimingStrike = 2, PrecisionTrace = 3 }, -- header byte 1
	RECORD_BYTES = { HoldZone = 3, TimingStrike = 2, PrecisionTrace = 7 }, -- B
	MAX_RECORDS = { HoldZone = 1024, TimingStrike = 512, PrecisionTrace = 2048 }, -- records
	MAX_TIMELINE_BYTES = 14348, -- B: 12 + 2048 × 7, the largest family cap; the S5 Guard bound (§10.3)
}

return Catalog.deepFreeze(MinigameFamilies)
