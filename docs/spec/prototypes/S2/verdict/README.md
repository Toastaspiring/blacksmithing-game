# The study behind §4.4's verdict (E-S2.11)

Evidence, not game code: nothing in the repo requires these files, and no test runs them. They are what the numbers in
`docs/spec/SPEC-evidence.md` E-S2.11 and SPEC §17.2 come from, kept as they ran. Their relative paths assume the study's
layout, a scratch folder holding them beside `tree/` (this repo with the variants patched in by `patch_param.py` and
`patch_param2.py`), `rec/` (the recommended rule as a file, written by `make_rec.py`), `repo/` (the build before the rule),
`cand/` (the first candidate), `proto/` (`S2/v2/` + `analyze_build.luau`, the emulator of M3 on the build's measure) and
`out/`, so they do not run from here. What does run: `tests/Physics/VisibleOracle.luau` and `PlausibleDesigns.luau`, ports
of `oracle.luau` and of `sets.luau`'s plausible families, in `tests/Physics/VerdictPrecision.spec.luau`. Everything here but
`lines/`, `analyze_build.luau` and `worst_P.json` is about rule P, the rule before the lines; the rule as built is L (E-S2.11).

| File | What |
|---|---|
| `report.txt` | the study's report, every variant's numbers (its scratch paths shortened to `<study>`) |
| `oracle.luau`, `oracle_check.luau`, `truth_run.luau` | the truth, its closed-form checks, its run over a set |
| `sets.luau`, `lib.luau` | the design sets, and what the probes share |
| `variants.luau`, `patch_param.py`, `patch_param2.py` | the variants, as settings of a parametric `Sampling` |
| `eval_run.luau`, `summ.py`, `summ_fam.py` | a variant against the truth: false Enclosed and false kept, ΔD through the emulator |
| `flip_x.luau`, `flip_x2.luau`, `flip_lam.luau`, `flip_rand.luau`, `summ_flips.py` | searches for a verdict that hidden parts flip: X placements, hidden copies inside X, laminates, random fill |
| `c09_plates.luau`, `limit_demo.luau` | the verifier's C09 plates; what hidden parts can still reach |
| `fixture_diff.luau` | the prototype's 71 fixtures, cleaned lists and D |
| `cost_run.luau`, `climb.luau`, `climb_m2.luau`, `decomp.luau`, `gap_run.luau` | cost: fixtures, hill climbing, M2 + M3 split, checkpoint gaps |
| `analyze_build.luau` | the emulator of M3 every \|ΔD\| in E-S2.11 and §17.2 goes through: the prototype's edge and factors on the build's kept row, areas and ownership; `require`s `../repo/` |
| `worst_P.json` | the 11 worst designs climbed against rule L, canonical and valid: T-PERF-01's and S-PERF-01's until M2 replaced L (E-S2.12); `../cover/worst_designs.luau` now holds them: `from` a climb or a bundle, `lune_ms` as measured, `parts` (JSON, not bit-exact: Lune's serde) |
| `lines/` | rule L's study, beside a copy of the repo in `tree/`, with `force/`, `plain/` and `count/` the Sampling instrumented by `sync.py`: `truth.luau` the truth, written apart from the build; `v1.luau` what the probes share; `b_sets.luau`, `b_run.luau`, `b_summ.py` the design sets, a family against the truth, the summary; `a20_all.luau`, `a30_more.luau`, `limit2.luau` the attacks and §17.2's rows; `climb_read.luau`, `d_climb.luau`, `d_cost.luau`, `merge_worst.luau`, `pick_worst.py` climbs on the reading and on counted queries, cost, what goes in `worst_P.json`; `mirror.luau`, `flip2.luau`, `same_bits.*`, `a6_order.luau`, `grid_max.luau`, `tables2.luau`, `union2.luau` the mirror images, hidden fill, the shortcuts that change no bit, id orders, grids, E-S2.5's and E-S2.9's rows; `mutants2.py` the mutants. V1 and V2 in their comments are the 2 reviews they came from |
| `make_rec.py`, `check_rec.luau` | the rule as a file, and that file against the parametric variant, bit for bit |
| `check_port.luau` | the build's `Physics/Sampling` (a copy in `port/`, beside the study's folder) against that file, bit for bit, on every set |
