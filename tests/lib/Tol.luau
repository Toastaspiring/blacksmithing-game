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
	FUZZ_N_GARBAGE = 2000,
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
	TOL_PARITY_MASS_REL = 1e-3,
	TOL_PARITY_COM_ABS = 1e-3,
	STARTER_MARGIN = 0.05,

	-- statistics (§14.8)
	BOT_RUNS = 400,
	FP_RUNS_TS = 300000,
	FP_RUNS = 20000,
	SOLVABILITY_SEEDS = 1000,
	PERFECT_MIN_SCORE = 0.98,
	PERFECT_30FPS_MIN_SCORE = 0.95,
	PERFECT_HZ_MIN_SCORE = 0.95,
	FAIRNESS_MAX_SD = 0.08,
	TIER_MIN_MEAN_DROP = 0.05,
	STEEL_MEAN_DROP = table.freeze({ 0.01, 0.08 }), -- {min, max}
	CHI2_CRIT = 37.70,

	-- performance (§14.11)
	ANALYSIS_LUNE_MAX_MS = 60,
	CHECKPOINT_GAP_LUNE_MS = 0.35,
	REPLAY_BUDGET_MS = 8,
	PT_GENERATE_BUDGET_MS = 5,
	REJECT_BUDGET_MS = 2,
	SERVER_SLICE_MAX_MS = 5,
	CLIENT_SLICE_MAX_MS = 8,
}

return table.freeze(Tol)
