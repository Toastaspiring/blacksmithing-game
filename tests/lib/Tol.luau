--!strict
-- tests/lib/Tol.luau — test budgets, run sizes and tolerances (SPEC §16.32; rationale per row there).
-- Pure Luau with no requires: the runner, the test library and the specs read every number from here.

local Tol = {
	-- runner budgets (§14.3)
	CASE_BUDGET_MS = 2000, -- a slower fast case is a perf bug or belongs in t.slow
	SLOW_CASE_BUDGET_MS = 300000, -- largest statistical case (a Trace FP case, ≈ 130 s) with margin

	-- property runs (§14.5)
	PROP_BASE_SEED = 0x5EED0001,
	PROP_N = 200,
	PROP_N_FAST = 25, -- the quick run's count for properties that replay whole minigame sessions (M4's L1 share); PROP_N under t.slow
	FUZZ_N_GARBAGE = 2000,
	FUZZ_N_STRUCT_FAST = 200, -- the quick run's structured timelines per family (T-MG-08, M4's L1 share); FUZZ_N_GARBAGE under t.slow
	FUZZ_N_VALID = 500,

	-- physics and difficulty
	TOL_ANALYTIC_REL = 1e-9,
	TOL_MASS_REL = 0.005,
	TOL_BALANCE_ABS = 0.01,
	TOL_REACH_ABS = 0.005,
	TOL_FACTOR_ABS = 0.02,
	TOL_G_INVARIANT = 0.002,
	TOL_DUST_G = 0.005,
	TOL_ASYM_ZERO = 0.02,
	TOL_EDGE_REL = 0.02, -- |ΔEdgeLength| / EdgeLength: E-S8.4's X04 bound (T-EDG-01)
	TOL_PARITY_MASS_REL = 1e-3,
	TOL_PARITY_COM_ABS = 1e-3,
	PARITY_DESIGNS = 200, -- S-PAR-02's Gen.validSword designs beside the fixtures (E-S8.6)
	PARITY_SEED = 0x5EED0002, -- their TestRng stream
	STARTER_MARGIN = 0.05,

	-- statistics (§14.8)
	BOT_RUNS = 400,
	BOT_RUNS_FAIL = 1000, -- T-MG-04's Q8 fail-rate bands (Average, Good): BOT_RUNS' seed list extended (M4's D10)
	FP_RUNS_TS = 300000,
	FP_RUNS = 20000,
	TP_RUNS = 2000, -- T-MG-10's runs per cheat unless named (D10)
	SOLVABILITY_SEEDS = 1000,
	PERFECT_MIN_SCORE = 0.98,
	PERFECT_30FPS_MIN_SCORE = 0.95,
	PERFECT_HZ_MIN_SCORE = 0.95,
	PERFECT_HZ_RUN_MIN_SCORE = 0.85, -- T-MG-03: every HoldZone Perfect run (the prototype's lowest: 0.8969, D10)
	FAIRNESS_MAX_SD = 0.08,
	FAIRNESS_SEEDS = 100, -- T-MG-12: pattern seeds per family × tier (D10)
	FAIRNESS_BOT_RUNS = 20, -- T-MG-12: Average runs per pattern seed, their bot seeds shared across patterns (D10)
	TIER_MIN_MEAN_DROP = 0.05,
	-- {min, max}: Average, Normal, Iron − Steel. The floor 0.005 is O4's default (M4's L3), where §16.32 had 0.01:
	-- hammering's drop is 0.0089 ± 0.0010 **[Decision to confirm]** (§17.1 O4)
	STEEL_MEAN_DROP = table.freeze({ 0.005, 0.08 }),
	-- T-MG-06's paired runs per family (D10): the drop's standard error ≈ 0.001 at these sizes
	STEEL_DROP_RUNS = table.freeze({ HoldZone = 4000, TimingStrike = 20000, PrecisionTrace = 4000 }),
	CHI2_CRIT = 37.70,

	-- performance (§14.11)
	ANALYSIS_LUNE_MAX_MS = 60,
	CHECKPOINT_GAP_LUNE_MS = 0.35,
	PERF_RUNS = 15, -- T-PERF-01's rounds per case: its numbers are the medians (single runs meet collections, §4.9)
	REPLAY_BUDGET_MS = 8,
	PT_GENERATE_BUDGET_MS = 5,
	REJECT_BUDGET_MS = 2,
	SERVER_SLICE_MAX_MS = 5,
	CLIENT_SLICE_MAX_MS = 8,
}

return table.freeze(Tol)
