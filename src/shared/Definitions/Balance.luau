--!strict
-- Definitions/Balance (SPEC §2.8, §4, §5, §8, §16.10; container S1, Geometry and Difficulty S2, Stats and Quality
-- S4, Display S1): the tunables that are not catalog columns, one deep-frozen module.
-- Geometry, Difficulty, Stats and Quality are in the BALANCE Manifest (any change bumps BALANCE_VERSION);
-- Display is not. Physics, Crafting and the tests read these values from here only.

local Catalog = require("./Catalog")
local DT = require("./Types")

-- ── Geometry (S2, §4) ─────────────────────────────────────────────────────────────────────────────────────────

export type GeometryBalance = {
	EPS_GEOM: number,
	HIDE_OFFSET: number,
	MIN_PART_VOLUME: number,
	ENCLOSED_EXPOSED_MAX: number,
	H_VOL: number,
	N_MIN_AXIS: number,
	N_MAX_AXIS: number,
	N_MAX_PART: number,
	N_VOL_TOTAL: number,
	H_SURF: number,
	NS_MAX: number,
	N_SURF_WORK: number,
	N_SUB_WORK: number,
	H_LADDER: { number },
	MAX_EXACT: number,
	H_OVERLAP: number,
	OVERLAP_N_MIN: number,
	OVERLAP_N_MAX: number,
	N_OVERLAP_WORK: number,
	GJK_MAX_ITER: number,
	AXIS_ELONGATION: number,
	AXIS_MAX_TILT_COS: number,
	EDGE_CELL: number,
	RASTER_TOL: number,
	EDGE_MAX_CELLS: number,
	EDGE_MAX_WORK: number,
	EDGE_MAX_THICK: number,
	EDGE_DOWN_COS: number,
	EDGE_SIMPLIFY: number,
	EDGE_GAP_BRIDGE: number,
	EDGE_MIN_CHAIN: number,
	EDGE_MAX_POINTS: number,
	CUT_LO: number,
	CUT_HI: number,
}

local Geometry: GeometryBalance = {
	EPS_GEOM = 1e-7, -- stud; signed epsilon of every boundary predicate
	HIDE_OFFSET = 0.012, -- stud; = CONTACT_TOL + 0.002: faces across a connected gap are hidden
	MIN_PART_VOLUME = 0.0002, -- stud³; Dust floor
	ENCLOSED_EXPOSED_MAX = 0.02, -- fraction; Enclosed: < 2 % of the area exposed
	H_VOL = 0.05, -- stud; volume-sample spacing
	N_MIN_AXIS = 2, -- samples per axis, at least
	N_MAX_AXIS = 48, -- samples per axis, at most
	N_MAX_PART = 3000, -- volume samples per part
	N_VOL_TOTAL = 12000, -- volume samples in all
	H_SURF = 0.04, -- stud; surface-sample spacing
	NS_MAX = 64, -- surface samples per edge, at most
	N_SURF_WORK = 40000, -- surface samples × (1 + candidate parts)
	N_SUB_WORK = 24000, -- boundary corner + 4 × 4 sub-grid tests per pass
	H_LADDER = { 1, 1.25, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10, 12, 16 }, -- × spacing; deterministic coarsening
	MAX_EXACT = 3, -- parts; exact clipping up to 3 higher overlapping parts
	H_OVERLAP = 0.0125, -- stud; refined overlap sampling otherwise
	OVERLAP_N_MIN = 4, -- cells per axis
	OVERLAP_N_MAX = 24, -- cells per axis
	N_OVERLAP_WORK = 40000, -- refined overlap cells × (1 + higher parts)
	GJK_MAX_ITER = 48, -- iterations; mean 3.1, max 9 measured
	AXIS_ELONGATION = 1.5, -- ratio; physics grip axis eligibility
	AXIS_MAX_TILT_COS = 0.7071, -- cos; a grip axis tilted > 45° falls back to +Y
	EDGE_CELL = 0.02, -- stud; blade raster cell
	RASTER_TOL = 0.005, -- stud; dilation = CONTACT_TOL / 2 (seams never open)
	EDGE_MAX_CELLS = 12000, -- cells; raster budget
	EDGE_MAX_WORK = 30000, -- cell × part tests; raster budget
	EDGE_MAX_THICK = 0.25, -- stud; a spine is not an edge
	EDGE_DOWN_COS = 0.5, -- cos; pommel-facing segments are not sharpenable
	EDGE_SIMPLIFY = 1, -- × cell; Douglas–Peucker tolerance
	EDGE_GAP_BRIDGE = 3, -- × cell; joint bridging
	EDGE_MIN_CHAIN = 3, -- × cell; noise chains dropped
	EDGE_MAX_POINTS = 256, -- points; bounded trace source
	CUT_LO = 10, -- ratio; cutIndex = clamp((length/thickness − CUT_LO)/(CUT_HI − CUT_LO), 0, 1)
	CUT_HI = 60, -- ratio
}

-- ── Difficulty (S2, §5) ───────────────────────────────────────────────────────────────────────────────────────

export type DifficultyBalance = {
	V_PART_FULL: number,
	JOINT_BOOST: number,
	A_JOINT_REF: number,
	THICK_BUDGET: number,
	SIGMA_LO: number,
	SIGMA_HI: number,
	THIN_SHARE_MIN: number,
	ASYM_TOL: number,
	ASYM_RAMP: number,
	ASYM_N_MIN: number,
	ASYM_AXIS_X: number,
	ASYM_WORK: number,
}

local Difficulty: DifficultyBalance = {
	V_PART_FULL = 0.004, -- stud³; part significance for PartCount and Joints
	JOINT_BOOST = 1.0, -- small contacts count up to 2×
	A_JOINT_REF = 0.05, -- stud²
	THICK_BUDGET = 400, -- Thinness probes per work set
	SIGMA_LO = 45, -- L/τ; arming Hammering 0.114, rapiers Hard (E-S2.9)
	SIGMA_HI = 130, -- L/τ
	THIN_SHARE_MIN = 0.25, -- thin metal must be ≥ 25 % of the set's striking metal (fins cannot set Thinness)
	ASYM_TOL = 0.02, -- stud; soft coverage: symmetric up to 0.02, ramp to 0.05
	ASYM_RAMP = 0.03, -- stud
	ASYM_N_MIN = 10, -- probes across the mirror direction, at least
	ASYM_AXIS_X = 0.6, -- cos
	ASYM_WORK = 30000, -- probe × candidate tests per work set
}

-- ── Stats (S4, §8.2): rows per EquipmentTypeId ────────────────────────────────────────────────────────────────

export type StatConstants = {
	MATERIAL_SCALE: number,
	PURITY_FLOOR: number,
	SHARP_FLOOR: number,
	DURA_FLOOR: number,
	FORGE_FLOOR: number,
	EDGE_REF: number,
	EDGE_GAIN: number,
	MASS_REF: number,
	MASS_BIAS: number,
	MASS_FACTOR_MIN: number,
	MASS_FACTOR_MAX: number,
	DAMAGE_BASE: number,
	BALANCE_IDEAL: number,
	BALANCE_TOLERANCE: number,
	BALANCE_FALLOFF: number,
	BALANCE_REACH_MIN: number,
}

export type StatsBalance = { Sword: StatConstants }

local Stats: StatsBalance = {
	Sword = {
		MATERIAL_SCALE = 100, -- S1 stores hardness and toughness as integers 0–100
		PURITY_FLOOR = 0.70, -- a ruined smelt keeps 70 % of the metal
		SHARP_FLOOR = 0.30, -- sharpening is the main Sharpness lever (×3.3)
		DURA_FLOOR = 0.50, -- hammering refines toughness (×2)
		FORGE_FLOOR = 0.60, -- a botched hammering keeps 60 % of the damage
		EDGE_REF = 6.0, -- studs; F1/F5's main chain 5.433 gives 0.91
		EDGE_GAIN = 1.0, -- full edge at Sharpness 70 hits ×1.7 a blunt bar
		MASS_REF = 0.80, -- kg; F5 starter 0.793 kg → F_mass ≈ 1
		MASS_BIAS = 0.4, -- ×2 mass → +25 % damage
		MASS_FACTOR_MIN = 0.6, -- heavy designs capped until swing speed (Phase 2)
		MASS_FACTOR_MAX = 1.3,
		DAMAGE_BASE = 28, -- points; flawless fixtures 36–44, headroom to 100
		BALANCE_IDEAL = 0.08, -- balance / reach; centre of the 4–12 % plateau before the guard
		BALANCE_TOLERANCE = 0.04, -- balance / reach; wide plateau, sensible designs score 100
		BALANCE_FALLOFF = 0.30, -- balance / reach; F4 cleaver (β 0.28) scores 47
		BALANCE_REACH_MIN = 1.0, -- studs; division guard
	},
}

-- ── Quality (S4, §8.3, §8.4) ──────────────────────────────────────────────────────────────────────────────────

export type QualityBalance = {
	WEIGHT_SUM_TOL: number,
	FAILED_STEP_CAP_TIER: DT.TierId,
	DESIGN_GAMMA: number,
}

local Quality: QualityBalance = {
	WEIGHT_SUM_TOL = 1e-9, -- enabled weights per type sum to 1
	FAILED_STEP_CAP_TIER = "Normal", -- a failed step lifts no cap (Q9)
	DESIGN_GAMMA = 0.15, -- per unit D; smallest round γ keeping a Good player's expected Q non-decreasing in D (Q11)
}

-- ── Display (S1; not in the BALANCE Manifest) ─────────────────────────────────────────────────────────────────

export type DisplayBalance = { MASS_UNIT_LABEL: string }

local Display: DisplayBalance = {
	MASS_UNIT_LABEL = "kg", -- Iron 7.87 per stud³ makes swords read 0.8–1.5 kg [Decision to confirm] (Q13)
}

export type Balance = {
	Geometry: GeometryBalance,
	Difficulty: DifficultyBalance,
	Stats: StatsBalance,
	Quality: QualityBalance,
	Display: DisplayBalance,
}

local Balance: Balance = {
	Geometry = Geometry,
	Difficulty = Difficulty,
	Stats = Stats,
	Quality = Quality,
	Display = Display,
}

return Catalog.deepFreeze(Balance)
