# M4 build plan, revision 2: Minigames (SPEC §18, "M4 Minigames")

**Revision 2** (2026-11-18, the M4 plan reviser): `plan.md` (r1, the M4 planner's) revised with `critique-coverage.md`
(critic A) and `critique-determinism.md` (critic B). Every critique point was checked against SPEC.md,
SPEC-evidence.md, the S3 prototype, the repo and the critics' own scripts and outputs before it was taken; [14] lists
what changed and [15] the points not taken, with reasons. Designer calls are in [9.1]; the lead's engineering calls are
the decisions of [1], the I- and G-items of [9.2] and slice 0 of [11].

Written first, on 2026-11-18, by the M4 planner on the working tree of branch `mvp` at HEAD `f7ac37d` (M0–M3 committed). Another
team is finishing a fix to M3's Physics ranks in the same working tree (`src/shared/Physics/*`, `tests/Physics/*`, the
difficulty goldens, SPEC §4–§5 text). That fix changes no type or interface M4 uses, so this plan builds on
`Analyze.run`'s output as it is and does not plan the fix. Nothing in the repo was edited for this plan or its revision.

**References.** `§` is SPEC.md; `E-Sx.y` is `docs/spec/SPEC-evidence.md`. A number in square brackets, such as [3.6],
is a section of this plan. Line numbers are "near line N" of the 2026-11-18 working tree: the in-flight fix edits
§4–§5, so lines after §5 can move by a few; search for the quoted anchor. "Prototype" means
`docs/spec/prototypes/S3/v2/` unless "v1" is written (v1, one level up, is superseded: E-S3 lead, v2 README).
The figures marked *measured* were taken for this plan ([13] lists how); *precomputed* marks an L3 outcome critic B
computed on the prototype with this plan's pinned config names (D11); everything else is read from the repo.

| SPEC anchor | Quoted | Near line |
|---|---|---|
| §1.2 module map | "Minigames/    Minigames Types Rng Params Timeline Checks Input HoldZone TimingStrike PrecisionTrace Bots [S3]" | 171 |
| §1.3 L2 | "Definitions → Util → Blueprint → Physics → Minigames, Crafting → Pipeline → …" | 195 |
| §1.6 | "P0 `Minigames.prepare` (StartStep; one burst within S3's generate budget)"; "`Minigames.judge` runs synchronously in the Submit handler" | 282, 286 |
| §2.8 | "CraftPlans · MinigameFamilies \| all · all but display text" | 495 |
| §4.7 | "export type StepAnalysis = { step, g, m, d, tierRaw, tier, material, terms, factors }" | 1215 |
| §4.8 | "Pipeline.stepInput(report: Report, stepIndex: number, seed: number): Minigames.PrepareInput" | 1255 |
| §6.2 | "`Minigames` (facade; with `Input.new` and `Params.explain`, the only API S5 and S6 call)" | 1647 |
| §6.3 | "xoshiro128\*\* 1.1 … with `bit32` ops and integer `+ * %` below 2^53" | 1695 |
| §6.4 | "Determinism rules (all of `Minigames/` except `Bots`)" | 1703 |
| §6.5 | "`p_final = round_q(clamp(p_base · m_material · m_tier · m_design, min, max))`" | 1715 |
| §6.6 | "`t = max(0, floor((os.clock() − goClock)·1000 − frameDtMs/2))`" | 1744 |
| §6.7 | "Decode order, first failure wins: `NotBuffer`, `Short` (< 12 B), `Version`, …" | 1759 |
| §6.8–§6.10 | the three families' pseudo-code and parameter tables | 1764–1890 |
| §6.12 | "Every human profile: frames at `fps` ±1 ms with a random phase against GO" | 1900 |
| §6.13 | "2,000 runs per cell, design factors at the tier's reference `x` (Normal 0.10, Hard 0.30)" | 1930 |
| §6.11 | "Views come from `advance(now)` each RenderStepped (≤ 1 frame + 10 ms latency); FeedbackEvents drive audio and VFX only" | 1894 |
| §10.5 | "1 decode … 2 hash … 3 replay … 4 checks … 5 clamp … 6 result" | 2781 |
| §10.6 | "`PtTooSmooth` \| ≥ 150 moving triplets (span > 0.002 u, both dt 10–40 ms)" | 2824 |
| §12.5 | "`BindToRenderStep("MinigameView", Camera + 1)`: InputCapture pushes the frame's records, the host calls `advance`" | 3344 |
| §12.8 | "trail of the last `TRACE_TRAIL_SAMPLES` 24 positions by accuracy credit … covered runs tinted" | 3404 |
| §14.1 L1 | "all pass, ≤ 30 s (… 29.3–29.6 s quiet after the shift fix's pins … 29.64 and 29.99 s at 3–20 % busy after its round 2's …)" | 3787 |
| §14.1 | "L3 Statistical \| … \| `lune run tests/run` (adds `t.slow`) \| … \| all pass, ≤ 10 min" | 3789 |
| §14.6 | "T-RNG-01…06, T-MG-01…16 `Minigames/*` incl. facade and `Bots` [S3]" | 3868 |
| §14.8 | "Each config seeds from `fnv1a32(config name)`, so L3 is pass/fail per code version, never flaky." | 4036 |
| §14.9 | "Before the first release no item is stored, so a round that changes outcome code re-blesses its goldens at the same version" | 4046 |
| §14.11 | "T-PERF-02 \| longest legal timeline per family: decode + replay + checks; Trace `generate` on X08" | 4092 |
| §16.12, §16.19–§16.23, §16.32 | the M4 constant tables | 4423, 4617–4664, 4755 |
| §17.2 | S3: "Re-measure the `PtTooPrecise` human minimum … if it nears 3 ×, retune"; S5: "above `REPLAY_BUDGET_MS` × 2.6"; S8: "**V-08** releases while the Esc menu is open reach the game" | 4863–4878 |
| §18 | "M4 Minigames \| `Minigames/*` incl. the facade and `Bots` (S3) \| T-RNG, T-MG with L3, T-PERF-02" | 4920 |
| E-S8.5 | "**T-RNG** 01 vectors from `kat/` …"; "**T-MG** 01 `prepare`/`judge` deterministic …"; "**Cheats**: Exact …" | 3473–3498 |

---

## 0. What M4 delivers

- `src/shared/Minigames/`: `Types`, `Rng`, `Params`, `Timeline`, `Checks`, `Input`, `HoldZone`, `TimingStrike`,
  `PrecisionTrace`, `Minigames` (the facade) and `Bots` (§1.2, §6.2): eleven pure modules, all but `Bots`
  authoritative under §6.4. Exact APIs in [3].
- One Definitions change: two PtTooSmooth check rows in `Definitions/MinigameFamilies` (D3), with the pre-release
  fingerprint re-bless [5.3].
- Tests: `tests/Minigames/*.spec.luau` (T-RNG-01…06, T-MG-01…16, T-PERF-02, the generic properties, the prototype
  goldens, a prototype-parity and full-precision check), `tests/lib/Cheats.luau` (new), `tests/fixtures/Edges.luau`
  (new: reference edges), `tests/fixtures/MinigameTimelines.luau` (new: frozen bot timelines, D14), X08's zigzag edge in
  `tests/fixtures/Cost.luau`, a blessed `tests/golden/minigames.bv1.golden.txt` [6].
- No Studio scenario: §18 lists none for M4; Lune = Studio parity of the replay is S-PAR-02's M5 extension [7].
- Exit (§18 and §14.1): `scripts/verify` green with L3 (`lune run tests/run` without `--quick`, since M4 touches
  `Minigames/`), T-RNG, T-MG with L3 and T-PERF-02 passing; README Status and `docs/build/M4-notes.md` written; one
  commit for the milestone.
- **Blockers to clear with the lead in slice 0, before the gate can be green:** O4 (T-MG-06 fails TimingStrike at the
  SPEC's 0.01 floor, [9.1]) and I4, both test-time gates: L1 (`--quick`) already takes 29.3–30.0 s of its 30 s and M4
  adds about 3 s; L3 would take about 16–18 minutes quiet against 10 ([6.4]).

## 1. Decisions this plan takes (engineering defaults, for the lead)

Designer calls are in [9.1]; these are build choices the SPEC leaves to the implementer. r2 changed D1, D5, D7 and D10
and added D11–D14.

| # | Decision | Why |
|---|---|---|
| D1 | Port the prototype's arithmetic **expression by expression** (same operand order and grouping), not the SPEC's pseudo-code where the two differ in rounding ([4.2] lists each pin); `Reference.spec` checks it at full precision against the prototype modules ([6.3]). | Exact equality with the prototype makes any difference a porting bug and keeps E-S3's goldens, hashes and the shipped distributions valid. Hashes and scores are quantized (HoldZone keys × 10⁶, 1/16384, integer ms, `q`), so a regrouping reaches them only about once in 10¹⁰ values and no hash or golden can see it; only the full-precision check can (critic B 10). |
| D2 | Thresholds, flag levels, wire constants, `passThreshold` and every parameter are read from `Definitions/MinigameFamilies`; the module constants of §16.19–§16.23 are named, exported, frozen constants at the top of their module. No literal copies. | §10.6 "thresholds and each flag's level … live in `Definitions/MinigameFamilies` … and S8 reads them from there"; one source per value (§2). |
| D3 | Add `PT_SMOOTH_DT_MIN_MS` = 10 and `PT_SMOOTH_DT_MAX_MS` = 40 as PrecisionTrace check rows (§10.6's "both dt 10–40 ms"), re-bless the fingerprint at version 1. | M1-notes B2: "PtTooSmooth's 'both dt 10–40 ms' bounds (§10.6) have no §16 constant … S3 should decide in M4." They are thresholds, so they live with the others. |
| D4 | `Input`'s Recorder gets two additions beside the §6.2 methods: `:horizonMs(clockS, frameDtS)` and `:since(count)` [3.6]; every record is clamped to at least the largest horizon handed out. The host advances HoldZone and TimingStrike to the horizon, PrecisionTrace to its latest sample. | Makes "live = replay" hold by construction, including TimingStrike with a positive `timingOffsetMs`, where advancing to the raw frame time can close a span before an offset-shifted press arrives ([9.2] G1). |
| D5 | `Minigames/Types` declares `Vec2`, `EdgeChain` and `FactorValue` as **structural copies** of S2's types (a comment names `Physics/Edge` and `Physics/Factors` as their owners) and requires nothing from Physics. | Luau has no type-only `require`: `require("../Physics/Analyze")` loads Analyze and the thirteen modules it requires into every Minigames module and suite, the in-flight fix's uncommitted code included (critic B 13(d)). Luau types are structural, so the copies are the same types; `MinigamesHelpers.stepInputFrom` (typed from `Analyze`'s exports) and M5's `Pipeline.stepInput` make luau-lsp check that the two stay compatible. |
| D6 | M4's goldens and statistical tests use the **reference edges** of `tests/fixtures/Edges.luau` (S3's `Blades.luau`, pasted as 17-digit literals), never `Analyze.run` output; only T-PERF-02's X08 and one integration case read `Analyze.run`. | The prototype's PrecisionTrace evidence (E-S3.2, E-S3.5) is on `Blades.arming`; and the in-flight Physics fix cannot move an M4 golden. |
| D7 | `Bots` drives every record through `Input` (§6.2 "the only producer of records"); bots that act at an exact integer ms (every "Exact", HoldZone's and the trace's Perfect) pass `clockS = (tMs + 0.5) / 1000` **and `frameDtS = 0`**. | `(t/1000)·1000` lands one ulp below t for 372 integers t ≤ 60,000 and `floor` would drop a millisecond; `(t + 0.5)/1000` fixes every one; and with a frame time the Recorder subtracts half a frame (1000 → 995 at a 10 ms frame; critic B 13(a), `stamp_check`). |
| D8 | `Minigames.judge` also refuses a buffer longer than its family's cap `12 + MAX_RECORDS · RECORD_BYTES` with `TooMany`, checked in decode's `TooMany` slot (after `Family`), O(1). | §10.3: "Submit also checks the step family's own cap … over it is an S3 Invalid (`TooMany`)"; keeps M7's refusal cheap (T-PERF-03). |
| D9 | TimingStrike's `:go(held)` records nothing: a strike needs a fresh press after GO. HoldZone's records `{t = 0, down = true}` when held; PrecisionTrace's records the cursor at `t = 0`. | §6.6's "a press held at GO records {t = 0, down} (one stroke)" is HoldZone's wording; "Holding a key does not repeat" (§6.9). [9.2] G4. |
| D10 | The L3 statistical tests size their runs per assertion ([6.4]): `BOT_RUNS` for means, order and drops; `BOT_RUNS_FAIL` 1,000 for the Q8 fail-rate bands; `STEEL_DROP_RUNS` for T-MG-06; `FAIRNESS_SEEDS` × `FAIRNESS_BOT_RUNS`; `TP_RUNS`; `PERFECT_HZ_RUN_MIN_SCORE` 0.85 for T-MG-03's per-run floor; and the quick-run sizes `PROP_N_FAST` 25 and `FUZZ_N_STRUCT_FAST` 200 ([6.7], [6.3] T-MG-08). All new `tests/lib/Tol` rows ([5.1]). | At 400 runs two Average fail-rate cells sit about 2 % from a fixed-seed failure each and T-MG-06 has no power ([6.4]); the quick sizes keep M4's L1 share near 3 s ([6.4] L1). |
| D11 | Every statistical configuration has a **pinned name** ([6.4]'s table); its seeds come from `fnv1a32(name)` (§14.8). The outcomes of T-MG-04, 05, 06, 12 and T-MG-10's trace margin are **precomputed** on the prototype with those names (critic B) and written in [6.3]; slice 8 precomputes the rest before slice 9. A name is never changed after a failure (that would be re-seeding); changing one before a run means recomputing its outcome first. | With Reference parity the build reproduces the prototype's scores, so a fixed-seed L3 outcome is known before the build: a slice-9 difference is a porting bug, not a statistics question (critic B 5). |
| D12 | TimingStrike's beat cue follows the raw clock: the host plays `CycleStart` when `view(session, nowMs).cycle` changes; `advance` (to the horizon, D4) returns only decisions (`Miss`, `End`). | With D4 the horizon is the offset-shifted time, so a `CycleStart` from `advance` would sound `timingOffsetMs` late (or early) against the dial and pull the player the wrong way; decisions must lag by the offset to equal the replay (critic A 5). §6.11's latency text gets the TimingStrike case (G15). |
| D13 | `push` and `advance` return one shared frozen empty array when no event fires; `replay` discards events. | `judge` runs synchronously in Submit; most calls fire nothing, and a table per record costs time at the decode cap ([6.8]; critic B 7). No result changes. |
| D14 | Golden (b)'s bot rows judge **frozen timelines** (`tests/fixtures/MinigameTimelines.luau`: encoded buffers as hex, made once by `Bots.play` in slice 8), not live bot runs; `Bots.spec` checks that `Bots.play` still reproduces them and carries a libm canary (a blessed `fnv1a32` over `%.17g` of `math.log`, `math.cos`, `math.exp` at about 1,000 fixed inputs). | `lune.exe` 0.8.9 imports the system UCRT's math (`api-ms-win-crt-math-l1-1-0.dll`, checked for r2), whose `log`, `cos`, `exp` can change with Windows updates or the CPU's FMA path; the bots use them, the judge does not. A golden that pins only authoritative code cannot be broken by the machine, and a libm change shows as its own failure (critic B 9). |

## 2. What M4 plugs into (checked on the working tree)

### 2.1 Definitions

- `src/shared/Definitions/MinigameFamilies.luau` (M1, 303 lines) **is complete**: six rows through `Catalog.build`
  (HoldZone 1, TimingStrike 2, RhythmSequence 3, PrecisionTrace 4, ReleaseTiming 5, FitPuzzle 6; the last three
  disabled, carrying only `passThreshold`); every §6.8–§6.10 parameter with its material, five tier columns (E-S3.3),
  design terms (typed `term()` constructor), `designClamp`, `quantum`, `min`, `max`; `checks` with §16.12's UPPER_SNAKE
  names; `flagLevels`; and the wire constants `TIMELINE_FORMAT_VERSION` 1, `TIMELINE_HEADER_BYTES` 12, `FAMILY_CODE`,
  `RECORD_BYTES`, `MAX_RECORDS`, `MAX_TIMELINE_BYTES` 14348. Its values equal the prototype's `Params.luau` (param order
  inside a family differs, which changes nothing: `resolve` writes a map). The module is deep-frozen; its type
  `MinigameFamilies` exposes the catalog views plus the wire constants.
- `tests/Definitions/MinigameFamilies.spec.luau` already pins T-DEF-01/02/03/05/06/07 for that data, including an
  independent §6.5 resolver against E-S3.3 (near line 61), the checks list (near line 452, which D3 extends) and two
  hard-coded Minigames constants (lines 31–32: `PT_TRAVEL_MAX_MS = 30000`, `TS_PERFECT_CORE_MIN_MS = 10`; M1-notes:
  "They can read them from Minigames/* once M4 lands").
- `Definitions/Types`: `FamilyId`, `MaterialId`, `TierId`, `StepId`, `FactorId` (FactorId order: PartCount, Thinness,
  Asymmetry, SurfaceComplexity, EdgeLength, Joints, MaterialMix, Volume). No `FlagId`: §6.2 puts it in
  `Minigames/Types`.
- `Definitions/Steps`: Smelting → HoldZone, Hammering → TimingStrike, Sharpening → PrecisionTrace (and Phase 2 rows).
  `Definitions/Tiers`: `order` 1…5 is the tier-column index. `Definitions/Network.COUNTDOWN_MS` = 3000 ("copied into
  StepSpec.countdownMs"). `Definitions/Limits.MAX_STEP_FLAGS` = 10. `Definitions/Versions.BALANCE_VERSION` = 1.
- `Definitions/Manifest` hashes MinigameFamilies with `select = "Data"`, `exclude = { "name" }`: every value but the
  display name, wire constants included. Fingerprint golden today: `{bytes=13286,fnv1a32=162842818,version=1}`.
- `tests/Definitions/BalanceGuard.spec.luau` (T-BAL-01): "Changed data under an unchanged BALANCE_VERSION fails, even
  with --bless". The pre-release practice (M2's brief, shift fix) is: delete the fingerprint golden, then `--bless`
  [5.3].

### 2.2 Util

`Util/Quantize.q(x, scale)` = `math.round(x · scale) / scale`, −0 → 0, errors on non-finite input and on |n| ≥ 2^51;
`SCALAR_SCALE` = 10000. The prototype's `round4(x) = math.round(x·10000)/10000` is the same function on finite input.

### 2.3 Physics (what M3 hands over)

- `Physics/Analyze` re-exports `Vec2` = `{number}`, `EdgeChain` = `{points: {Vec2}, length}`, `EdgeProfile`,
  `FactorValue` = `{factor: FactorId, raw, x}`, `StepAnalysis` (near lines 57–61 of `Analyze.luau`).
- `analysis.steps[i]` (enabled steps, CraftPlans order: Smelting, Hammering, Sharpening): `material` (the governing
  material), `tier` (played, enabled-prefix clamp: Normal or Hard), `factors` (all 8, FactorId order, `x` normalized to
  [0, 1]). `analysis.edge.gripAxis` is always `{0, 1}`: Analyze hands `Edge.profile` the difficulty frame
  (`MassProps.difficultyFrame` returns `point, { 0, 1 }`, near line 562), so `edgeToPanel` always runs with N = (1, 0),
  +X down. `analysis.balanceVersion` = `BALANCE_VERSION`.
- `Pipeline.stepInput` (§4.8) does not exist until M5; M4's tests build the same `PrepareInput` with a helper [6.1].

### 2.4 Tests, meta rules, runner

- `tests/lib`: `Test` (`t.it`, `t.slow`, `t.skip`; `CASE_BUDGET_MS` 2000, `SLOW_CASE_BUDGET_MS` 300000), `Assert`
  (`eq`, `near`, `rel`, `within`, `deepEq`, `throws`, `finite`, …), `Prop.check(n, gen, property)` (case seeds from
  `PROP_BASE_SEED`, replay with `--seed`), `TestRng` (xorshift32, independent of `Minigames/Rng`), `Dump`
  (`canonical`, `fnv1a32`, `byteLess`), `Golden` (`check`, `digest`, `--bless`), `Gen` (`garbage` makes zeroed buffers
  only), `Tol` (every §16.32 row M4 needs is present: `BOT_RUNS` 400, `FP_RUNS_TS` 300000, `FP_RUNS` 20000,
  `SOLVABILITY_SEEDS` 1000, `PERFECT_*`, `FAIRNESS_MAX_SD`, `TIER_MIN_MEAN_DROP`, `STEEL_MEAN_DROP` {0.01, 0.08},
  `CHI2_CRIT` 37.70, `REPLAY_BUDGET_MS` 8, `PT_GENERATE_BUDGET_MS` 5, `REJECT_BUDGET_MS` 2, `PERF_RUNS` 15). No
  `tests/lib/Cheats.luau` yet (§14.2 lists it).
- `tests/Meta/Rules.luau`: `src/shared/Minigames/` is in `AUTHORITATIVE`, so T-META-03 bans `math.sin cos tan exp log
  pow atan asin acos` (by prefix), `^`, `^=`, `--!native` and `@native` there, **Bots included**, unless the line carries
  `-- allow-transcendental: <reason>`; T-META-04 flags float accumulation inside a generic `for` that is not `ipairs` or
  a call (so `for _, x in arr do sum += x end` fails: use `ipairs` or a numeric `for`). T-META-02 bans `os.clock`,
  `math.random`, `Random.new`, `task.`, `print`, … in all of `src/shared`. The meta rules do not ban `%`, `//`,
  `math.lerp`, `vector.*` or float buffer reads, all outside §6.4's whitelist ("Only `+ − × ÷`, `sqrt`,
  `floor/ceil/round`, `abs`, `min/max/clamp`"), while §6.3 writes the Rng with integer `%` ([3.0], I6).
- `tests/Meta/Requires.luau` (T-META-07, run by `scripts/verify` before any spec): `LAYERS` gives `Minigames = 5`
  (Definitions 1, Util 2, Blueprint 3, Physics 4, Crafting 5, Pipeline 6, …); a `src/shared` require that goes up a
  layer fails, as do cycles and unresolved or case-mismatched requires.
- `tests/run.luau`: discovers `tests/**/*.spec.luau` in byte-wise order, one uniquely named suite per spec, `--quick`
  skips `t.slow`, `--filter`, `--seed`, `--bless`. `scripts/verify`: sourcemaps → T-META-07 → luau-lsp passes A and B →
  tests. `tests/Physics/Perf.spec.luau` is the method T-PERF-02 copies (warm-up, `PERF_RUNS` rounds odd forward / even
  backward, a full collection before each timed run through `luau.load('collectgarbage("collect")')`, medians).
- `tests/fixtures/Cost.luau` maps X08a/b/c to P2/P1/P5 and says (near line 14) "Its 256-point zigzag edge is an
  EdgeChain for M4's T-PERF-02, not a blueprint"; the chain itself is not in the repo yet.
- **Time gates today** (§14.1): L1 (`--quick`, "≤ 30 s") already measures 29.3–29.6 s quiet after the shift fix's
  pins and 29.64–29.99 s at 3–20 % busy after its round 2; L3 ("≤ 10 min") already holds about 5 minutes of M2–M3
  `t.slow` cases (295 s at M3's close-out); `CASE_BUDGET_MS` is 2,000 per fast case. M4's share of both is I4 ([6.4]).
- `tests/lib` requires nothing in `src/` (§14.2: "specs pass modules in"), so `Cheats` gets its modules from the spec
  ([6.6]). `Dump.fnv1a32` is the standard FNV-1a 32 (the prime as `h · 403 + (h & 0xFF) << 24`), so `configSalt` equals
  the critics' prototype salts.

### 2.5 The prototype and its recorded outputs

- v2 (`README.md`): `Rng.luau` (unchanged from v1), `Params.luau`, `HoldZone.luau`, `TimingStrike.luau`,
  `PrecisionTrace.luau`, `Timeline.luau` (unchanged from v1), `Blades.luau`, `Bots.luau`, `Sim.luau`; scripts
  `dist.luau` (the generator of the score distributions), `golden.luau`, `det.luau`, `cost.luau`, `worst.luau`,
  `cost2.luau`, `checks.luau`, tuning tools. Outputs in `v2/out/`: `golden.txt`, `det.txt`, `checks.txt`, `cost.txt`,
  `cost2.txt`, `worst.txt`, `final_table.txt` (= E-S3.2), `S3-score-distributions.luau` (48 cells × 2,000 quantized
  scores). v1's `out_*.txt` and `sim_*.luau`, `Bots{HZ,PT,TS}.luau`, `tune_*.luau`, `run_all.luau` are the draft's
  hold-model era and feed nothing in M4.
- What the prototype does not have, so M4 writes it new: views and FeedbackEvents (no `view`, `push`/`advance` return
  nothing); TimingStrike's breakdown beyond `errors`, `whiffs`, `meanErrMs`, `perfect` (no `judged`, `good`, `ok`,
  `miss`, `bestCombo`, `meanAbsErrMs`); the Recorder (`Input`); the facade; flags spelled `HZ_InhumanRate`,
  `TS_ExactHits`, `PT_TooPrecise` … (the SPEC's FlagIds are `HzInhumanRate`, `TsExactHits`, `PtTooPrecise` …);
  `PtSparse` exists, `PtTooSmooth`'s dt bounds are literals.
- Stale recorded lines (use the evidence, not the file): `out/golden.txt`'s `HoldZone.driftSpeed: IN 0.21|0.2625 …`
  predates the Volume term's change from +0.25 to +0.15 (E-S3.7); E-S3.3's `0.210|0.2415` is right and so is the repo.
  `out/det.txt`'s HoldZone bytes 198 / 295 / 408 differ from E-S3.6's 198 / 293 / 396 (another run). Neither moves a
  golden M4 asserts.

---

## 3. Module APIs (`src/shared/Minigames/`)

### 3.0 Rules every module keeps

- **Layer (§1.3).** `src/shared/Minigames/<Name>.luau`, `--!strict` on line 1, pure (no `-- @roblox-bound`, no
  `init.luau`). Relative string requires only: `./X` inside the folder, `../Definitions/X`, `../Util/Quantize`;
  nothing from Physics (D5: S2's three types are structural copies). T-META-07's `LAYERS` puts Minigames at 5: it may require layers 1–4 and its own
  folder, never `Crafting` (also 5, a sibling nothing here needs), `Pipeline` or anything above. Nothing below may
  require Minigames (Physics never does). No cycles inside the folder ([3.12]).
- **Determinism (§6.4), every module but `Bots`.** Integer ms from GO; ticks are multiples of `HZ_TICK_MS` /
  `PT_EVAL_MS`. Arithmetic `+ − × ÷`, `math.sqrt`, `math.floor/ceil/round`, `math.abs`, `math.min/max/clamp`; no
  trigonometry, `exp`, `log`, no `^` (repeated multiplication or doubling), and, per §6.4's whitelist (read over §6.3's `%`, I6), **no `%` and no
  `//`** (use `math.floor(a / b)` and bit32; the Rng's reductions in [3.2]). Randomness only from `Rng`; no
  `math.random`, `Random`, `os.clock` (T-META-02 already enforces those in all of `src/shared`). Sums are plain
  left-to-right additions over arrays in index order; loops are numeric `for` or `ipairs`; maps are looked up, never
  iterated. Sorts only with strict total orders (flag strings; finite numbers). No `--!native` / `@native`.
- **No module-level state.** Every module table is frozen at the end of the file; constants are frozen tables; no
  caches (the prototype's `FALLBACK_SOURCE` memo and `Sim.sourceCache` are dropped: the fallback source is five points,
  recomputed). Sessions and Recorders are plain tables made by `new…` functions.
- **Enforcement.** T-META-03/04 cover the folder already, but T-META-03 is a list of banned prefixes (sin, cos, tan,
  exp, log, pow, atan, asin, acos, and `^`), so `math.lerp`, `math.map`, `math.noise`, `math.fmod`, `vector.*` and
  float32 buffer reads pass it (`math.lerp` is one C++ expression a compiler may fuse into an FMA on ARM64 clients). M4
  adds `tests/Minigames/Source.spec.luau`, which lexes every authoritative Minigames file with `tests/Meta/Lex` and
  enforces §6.4 as a **whitelist** (critic B 11): every `math.` member is one of `floor`, `ceil`, `round`, `abs`,
  `min`, `max`, `clamp`, `sqrt`, `huge`; no `vector.`; no `buffer.readf32/readf64/writef32/writef64`; no `%`, `%=`, `//`,
  `//=` (I6). `Bots` is excluded. It does not edit `tests/Meta/Rules.luau` (S8's).
- **Authoritative**: `Types`, `Rng`, `Params`, `Timeline`, `Checks`, `Input`, `HoldZone`, `TimingStrike`,
  `PrecisionTrace`, `Minigames`. **Not authoritative**: `Bots` (§6.4 "except `Bots`"; tests, tuning, Studio autoplay). It
  stays pure and seeded (no clock), may use libm on lines tagged `-- allow-transcendental: <reason>` (§6.12, T-META-03),
  and must still pass T-META-04.

### 3.1 `Minigames/Types` (types only; returns `table.freeze({})`)

All §6.2 types, verbatim, plus the ones §6.8–§6.10 describe in prose:

```lua
--!strict
local DT = require("../Definitions/Types")
-- S2's types (Physics/Edge, Physics/Factors) as structural copies: Minigames requires nothing from Physics (D5)
export type Vec2 = { number }                                      -- {x, y}
export type EdgeChain = { points: { Vec2 }, length: number }
export type FactorValue = { factor: DT.FactorId, raw: number, x: number }
export type FlagId = "HzInhumanRate" | "TsLowVariance" | "TsExactHits" | "PtTooPrecise" | "PtTooSmooth"
	| "PtTeleport" | "PtSparse"
export type InvalidReason = "NotBuffer" | "Short" | "Version" | "Family" | "TooMany" | "Length" | "Duration"
	| "NotIncreasing" | "PastEnd" | "BadKind" | "NotAlternating" | "OutOfPanel" | "BadFlags" | "HashMismatch"
export type PrepareInput = { family: DT.FamilyId, seed: number, material: DT.MaterialId, tier: DT.TierId,
	factors: { FactorValue }, edge: { chains: { EdgeChain }, gripPoint: DT.Vec3, gripAxis: Vec2 }?,
	balanceVersion: number }
export type StepSpec = { family: DT.FamilyId, seed: number, params: { [string]: number }, source: { number }?,
	durationMs: number, countdownMs: number, patternHash: number, balanceVersion: number }
export type MinigameResult = { status: "Ok" | "Invalid", score: number, rawScore: number, passed: boolean,
	flags: { FlagId }, invalidReason: InvalidReason?, breakdown: { [string]: number }, elapsedMs: number }
export type FeedbackEvent = { kind: string, t: number, i: number?, value: number?, label: string? }
export type HoldRecord = { t: number, down: boolean }              -- TimingStrike's record is the press time t
export type TraceRecord = { t: number, u: number, v: number, grind: boolean }   -- u, v in 1/16384 panel units
export type FamilyModule<P, R, S, V> = { id: DT.FamilyId, generate: (number, { [string]: number }, { number }?) -> P,
	hash: (P) -> number, newSession: (P) -> S, push: (S, R) -> { FeedbackEvent },
	advance: (S, nowMs: number) -> { FeedbackEvent }, view: (S, nowMs: number) -> V,
	finish: (S) -> MinigameResult, checks: (P, { R }, MinigameResult) -> { FlagId } }
export type Grade = "Perfect" | "Good" | "Ok" | "Miss"
export type HoldZoneView = { t: number, phase: "Ramp" | "Hold" | "Done", temperature: number, fire: number,
	zoneCenter: number, zoneHalf: number, softBand: number, inZone: boolean, runningScore: number, timeLeftMs: number }
export type TimingStrikeView = { t: number, cycle: number, cycles: number, marker: number, windowCenter: number,
	windowHalf: number, perfectHalf: number, goodHalf: number, next: { windowCenter: number, windowHalf: number }?,
	lastGrade: Grade?, lastErrorMs: number?, combo: number, runningScore: number, timeLeftMs: number }
export type PrecisionTraceView = { t: number, pacerU: number, pacerV: number, pacerArc: number, cursorArc: number?,
	distance: number?, onPath: boolean, grinding: boolean, accuracySoFar: number, coverage: number,
	paceLag: number?, credit: number?, coveredRuns: { number }, timeLeftMs: number }   -- credit, coveredRuns: G14
export type Recorder = { go: (Recorder, boolean, number?, number?, boolean?) -> (),
	button: (Recorder, boolean, number, number) -> (), cursor: (Recorder, number, number, boolean, number) -> (),
	release: (Recorder) -> (), records: (Recorder) -> { any },
	horizonMs: (Recorder, number, number) -> number, since: (Recorder, number) -> { any } }   -- last two: D4
```

The three Pattern types are exported by their family modules ([3.7]–[3.9]); the facade treats them as `any`.
`PrepareInput.edge.gripPoint` is `DT.Vec3` (§6.2); M5's `Pipeline.stepInput` builds this narrow table from
`analysis.edge` rather than passing the `EdgeProfile`: whether Luau's width subtyping accepts the wider table under
`--!strict` is unconfirmed (§17.2's S1 row asks the same question of `StepRecord`)
[8.2]. Luau note from M1 (B1, B3): string literals inside optional table fields widen to `string` under luau-lsp, so
build FlagId, InvalidReason and Grade values through typed locals or a typed constructor, as M1's `term()` does.

### 3.2 `Minigames/Rng` (§6.3, §16.19; T-RNG)

```lua
Rng.new(seed: number, tag: string?): Rng       -- error unless seed is an integer in [0, 2^32); nil tag ≡ ""
Rng.fromState(s0: number, s1: number, s2: number, s3: number): Rng      -- tests (the raw xoshiro vector)
r:nextU32(): number    r:nextFloat(): number   -- u32 / 2^32, in [0, 1)
r:range(lo, hi): number                        -- lo + (hi − lo) · r:nextFloat()      (exactly this expression)
r:int(lo, hi): number                          -- lo + math.floor(r:nextFloat() · (hi − lo + 1))   (inclusive)
r:chance(p): boolean                           -- r:nextFloat() < p
r:sign(): number                               -- if r:nextFloat() < 0.5 then −1 else 1
Rng.mul32(a, b), Rng.fnv1a32(s), Rng.fmix32(z) -- §6.3's exports
Rng.hashU32(h, v): number                      -- FNV-1a step over v's 4 bytes, little-endian (pattern hashes)
Rng.FNV_BASIS 0x811C9DC5, Rng.FNV_PRIME 0x01000193, Rng.RNG_SPLITMIX_GAMMA 0x9E3779B9,
Rng.RNG_FMIX_C1 0x85EBCA6B, Rng.RNG_FMIX_C2 0xC2B2AE35   -- §16.19
Rng.TAGS = { HoldZoneTarget = "HoldZone.Target", TimingStrikeTempo = "TimingStrike.Tempo",
	TimingStrikeOffsets = "TimingStrike.Offsets", PrecisionTracePerturb = "PrecisionTrace.Perturb" }
```

- State `{s0, s1, s2, s3}` in a table whose metatable is the frozen method table (`setmetatable` with a frozen
  metatable is fine; the instance stays mutable).
- **Integer arithmetic inside §6.4's whitelist.** Every intermediate is a non-negative integer below 2^53, so it is
  exact; the reductions the prototype writes with `%` become `mod(x, m) = x − math.floor(x / m) · m` for m = 65536 and
  m = 4294967296 (division by a power of two, `floor`, a product by a power of two and the subtraction are each exact
  for integers below 2^53). `bit32.band/bxor/rshift/lshift/lrotate` only ever receive values already in [0, 2^32).
  - `mul32(a, b)`: `ah = rshift(a, 16)`, `al = band(a, 0xFFFF)`; `hi = mod(ah · b, 65536)` (ah·b < 2^48);
    `return mod(hi · 65536 + al · b, 2^32)` (the sum < 2^49).
  - `fnv1a32(s)`: `h = FNV_BASIS; for i = 1, #s do h = mul32(bxor(h, string.byte(s, i)), FNV_PRIME) end`.
  - `fmix32(z)`: `z = mul32(bxor(z, rshift(z, 16)), C1); z = mul32(bxor(z, rshift(z, 13)), C2); return bxor(z, rshift(z, 16))`.
  - `new`: `x = bxor(seed, fnv1a32(tag or ""))`; four times `x = mod(x + GAMMA, 2^32)`, `s_i = fmix32(x)` (at most one
    word can be 0, never all four).
  - `nextU32` (xoshiro128\*\* 1.1): `result = mod(lrotate(mod(s1 · 5, 2^32), 7) · 9, 2^32)`; `t = lshift(s1, 9)`;
    `s2 = bxor(s2, s0); s3 = bxor(s3, s1); s1 = bxor(s1, s2); s0 = bxor(s0, s3); s2 = bxor(s2, t); s3 = lrotate(s3, 11)`.
  - `hashU32(h, v)`: assert v is an integer in [0, 2^32); four times `h = mul32(bxor(h, band(v, 0xFF)), FNV_PRIME);
    v = rshift(v, 8)` (the prototype's `v % 256`, `v // 256`, equal for u32 v).
  - Patterns hash a word stream: `h = FNV_BASIS`, then `h = hashU32(h, w)` per word, in the family's order.
- §6.3 calls renaming a tag a BALANCE change; the tags are constants, pinned by T-MG-13's hashes.

### 3.3 `Minigames/Params` (§6.5; T-MG-07)

```lua
Params.resolve(family: FamilyId, material: MaterialId, tier: TierId, factors: { FactorValue }): { [string]: number }
Params.explain(family, material, tier, factors)
	: { [string]: { base: number, mMaterial: number, mTier: number, mDesign: number, final: number } }   -- §12.2 Intro
Params.resolveDef(def: MinigameFamilyDef, material, tier, factors): { [string]: number }   -- the core; P-ORDER
Params.refFactors(x: number): { FactorValue }   -- all 8 factors at raw = x, x = x, FactorId order (Bots, tests)
```

Per parameter row, in the row's array order (pinned, D1):
`mMat = if def.material then (def.material[material] or 1) else 1`;
`mTier = if def.tier then def.tier[Tiers.get(tier).order] else 1` (error on an unknown tier: a caller bug);
`mDesign = 1` or, with a design array, `sum = 1; for _, term in ipairs(def.design) do sum += term.k ·
math.clamp(x(term.factor), 0, 1) end; mDesign = math.clamp(sum, designClamp[1], designClamp[2])`, where `x(f)` is the
`x` of the first `FactorValue` whose `factor == f` (ipairs), 0 when missing;
`v = def.base · mMat · mTier · mDesign` (left to right); `if def.min then v = math.max(v, def.min) end`;
`if def.max then v = math.min(v, def.max) end`; `if def.quantum then v = math.round(v / q) · q end`.
`resolve` errors on an unknown or disabled family (prepare's input is server-made). `explain` returns the four factors
and `final` = the resolved value for every parameter, so `explain(...)[p].final == resolve(...)[p]`. `passThreshold`
is a parameter like any other (Phase 2's per-tier pass line is a tier column, §15.1).

### 3.4 `Minigames/Timeline` (§6.7; T-MG-08)

```lua
Timeline.encode(family: FamilyId, durationMs: number, patternHash: number, records: { any }): buffer
Timeline.decode(b: unknown, family: FamilyId, durationMs: number): ({ any }?, number | InvalidReason)
Timeline.capBytes(family: FamilyId): number          -- 12 + MAX_RECORDS[family] · RECORD_BYTES[family] (D8)
```

- Constants come from `Definitions/MinigameFamilies` (`TIMELINE_FORMAT_VERSION`, `TIMELINE_HEADER_BYTES`,
  `FAMILY_CODE`, `RECORD_BYTES`, `MAX_RECORDS`); `U_MAX` = 3 · 16384 = 49152 and `V_MAX` = 16384 derive from
  PrecisionTrace's `PT_PANEL_ASPECT` and `PT_FIXED_POINT` (no literal 49152 in Timeline; [3.12]).
- Layout: header `u8 version, u8 family code, u16 count, u32 durationMs, u32 patternHash`, little-endian; records
  start with `u16 dtMs` from the previous record (t₀ = 0); HoldZone adds `u8 kind` (1 = down); TimingStrike nothing;
  PrecisionTrace `u16 uQ, u16 vQ, u8 flags` (bit0 grind).
- Decode order, first failure wins (§6.7): `NotBuffer` (`typeof(b) ~= "buffer"`), `Short` (< 12 B), `Version`,
  `Family`, `TooMany` (n > `MAX_RECORDS`, or `buffer.len(b)` > `capBytes`, D8), `Length` (≠ 12 + n · size),
  `Duration` (≠ the spec's); per record: `NotIncreasing` (Trace dt = 0 after the first), `PastEnd` (t > durationMs),
  `BadKind` (HoldZone kind > 1), `NotAlternating` (kinds alternate starting with down), `OutOfPanel` (uQ > 49152 or
  vQ > 16384), `BadFlags` (flags > 1). Success returns `(records, patternHash)`; comparing the hash is the judge's job.
- A per-family codec table `{ write(b, o, r), read(b, o, i, state) → (record?, reason?) }` is the Phase 2 hook: a new
  family adds a codec, a Definitions row with its wire constants, a family module, a Bots policy and an Input rule
  (§15; §18's "new families plug into M4's facade and bots").
- `encode` is for honest records (Input, Bots, tests): it errors on a dt outside 0…65535 or a field out of range (a
  caller bug). `decode` never throws on any value (P-TOTAL), reads only inside `buffer.len(b)`, and refuses an oversize
  buffer in O(1), before the record loop.

### 3.5 `Minigames/Checks` (§6.2 "sample SD, windows"; §10.5–§10.6)

```lua
Checks.mean(xs: { number }): number                     -- left-to-right sum / n; 0 for n = 0
Checks.sampleSd(xs: { number }): number                 -- two passes: mean, then Σ (x − mean)², / (n − 1), sqrt; n ≥ 2
Checks.maxInWindow(times: { number }, windowMs: number): number   -- most entries in any [t_j, t_j + windowMs)
Checks.value(family: FamilyId, name: string): number    -- a `checks` row of MinigameFamilies (error if missing)
Checks.level(family: FamilyId, flag: FlagId): "High" | "Medium"
Checks.anyHigh(family: FamilyId, flags: { FlagId }): boolean
Checks.sorted(flags: { FlagId }): { FlagId }            -- a new array in byte order (§10.5 "sorted by id")
```

`sampleSd`'s two passes reproduce the prototype's TimingStrike variance bit for bit (sum in cycle order, mean = sum / n,
then the squares). `maxInWindow` is the prototype's two-pointer loop (`while times[i] − times[j] ≥ window do j += 1`).

### 3.6 `Minigames/Input`: the Recorder (§6.2, §6.6; T-MG-09, 15, 16)

```lua
Input.new(spec: StepSpec, timingOffsetMs: number, goClockS: number): Recorder
rec:go(held: boolean, u: number?, v: number?, grind: boolean?)  -- first call, on the first frame at or after GO
rec:button(down: boolean, clockS: number, frameDtS: number)     -- Space OR LMB logical state changes (S6 ORs them)
rec:cursor(u: number, v: number, grind: boolean, clockS: number) -- every frame, PrecisionTrace only (u ∈ [0,3], v ∈ [0,1])
rec:release()                                                    -- focus lost, menu opened (§6.6 "Focus, menu")
rec:records(): { any }                                           -- a frozen copy, at submit time
rec:horizonMs(clockS: number, frameDtS: number): number          -- D4: the time the session may advance to
rec:since(count: number): { any }                                -- D4: records count+1…#, for per-frame pushing
```

- Stamps (§6.6): a button stamp is `max(0, math.floor((clockS − goClockS) · 1000 − frameDtS · 1000 / 2))`; for
  TimingStrike then `max(0, t − timingOffsetMs)`; then `t = max(t, lastT, horizonMax)` (non-decreasing, never before a
  time the session was advanced to). A trace stamp is `max(0, math.floor((clockS − goClockS) · 1000))`. Records with
  t > `spec.durationMs` are dropped. Record tables are frozen when made. `timingOffsetMs` is not clamped here (S6
  passes the sanitized setting; `TIMING_OFFSET_MAX_MS` lives in `Persistence/Settings`, layer 8, which Input may not
  require).
- **HoldZone**: `go(true)` records `{t = 0, down = true}`; `button` records OR-state changes only and refuses a new
  press once `#records ≥ MAX_RECORDS − 1` (the matching release always fits); `release()` records an up at
  `max(lastT, horizonMax)` if down (ups never move a HoldZone score: the simulation reads downs only).
- **TimingStrike**: press times only: `button(true)` while up is a press (dropped past `MAX_RECORDS`); `button(false)`
  and `release()` only reset the state; `go(held)` records nothing and sets the state (D9).
- **PrecisionTrace**: `go(held, u, v, grind)` records `{t = 0, uQ, vQ, grind}` (grind, or `held` when grind is nil; t = 0 as §6.2 and §12.5 write, I7) and sets the next due
  time to 20; `cursor` records at the first call whose stamp t ≥ the due time and t > lastT, with `uQ =
  clamp(round(u · 16384), 0, 49152)`, `vQ = clamp(round(v · 16384), 0, 16384)`, then `while due ≤ t do due += 20` (the
  prototype bot's rule); `button` and `release` record nothing (the host's next `cursor` carries its grind state). At
  most `durationMs / 20 + 1` records (1,551 at 31 s), under the 2,048 cap.
- `horizonMs`: HoldZone and TimingStrike return `horizonMax = max(horizonMax, the button stamp of (clockS, frameDtS))`;
  PrecisionTrace returns the latest record's t. Host loop (M8, §12.5): push `rec:since(pushed)` into the session,
  then `advance(session, rec:horizonMs(clock, dt))`, then `view(session, nowMs)`; at GO + durationMs it pushes `rec:since(pushed)` once more, then
  calls `finish` (a record InputCapture makes after the last frame's push, such as a HoldZone press the last scored
  tick reads, would otherwise be encoded but never pushed: a ScoreMismatch; critics A 6, B 13(e)). Calls before `go`
  are ignored
  (countdown inputs are ignored, §6.6).
- Why D4: with `timingOffsetMs` = +60, a span whose `T_i + M` falls between the offset-shifted press time and the raw
  frame time is closed as a Miss live but judged on replay. Advancing to the horizon (already in the records' time
  base) and clamping later records to it means the live session sees every record before any tick or span close that
  the replay would process after it. T-MG-09 runs both drivers and pins the difference [6.3].
  TimingStrike's decisions (`Miss`, `End`, `lastGrade`, `combo`, `runningScore`) therefore lag the raw clock by the
  frame and max(0, `timingOffsetMs`), up to 120 ms, as they must to equal the replay; its beat cue does not (D12, G15).

### 3.7 `Minigames/HoldZone` (§6.8, §16.20; Smelting)

Constant `HZ_TICK_MS` = 10. Pattern `{ p, keysT, keysC, durationMs, rampMs, hash }`.

- `generate(seed, p)`: the prototype's `HZ.generate` exactly: `rng = Rng.new(seed, "HoldZone.Target")`;
  `c0 = lo + (hi − lo) · rng:range(0.3, 0.7)` with lo, hi = `targetMin`, `targetMax`; keys `(0, c0)`, `(rampMs, c0)`;
  `while t < durationMs`: `seg = rng:int(segMinMs, segMaxMs)`; unless `rng:chance(holdChance)`:
  `mag = driftSpeed · seg / 1000 · rng:range(0.5, 1.0)`, `s = rng:sign()`, `nc = c + s · mag`, reflected to `c − s ·
  mag` when outside [lo, hi], then clamped; `t += seg`; key `(t, nc)`. Hash words per key: `keysT[i]`, then
  `math.round(keysC[i] · 1000000)`.
- `centerAt(pattern, t)`: stateless (the largest key index j ≤ #keys − 1 with `keysT[j] ≤ t`), `s = min(1, (t − t0) /
  (t1 − t0))`, `e = s · s · (3 − 2 · s)`, `c0 + (c1 − c0) · e`, `c0` when `t1 ≤ t0`. The simulation may keep the
  prototype's forward pointer for speed; a unit test pins the two equal on every tick.
- Session `{ T = 0, F = 0, pressT = −refillMs, k = 0, credit = 0, n = 0, inZone = 0, strokes = 0, ei = 1, events }`;
  `push(S, rec)` appends; `advance(S, nowMs)` integrates ticks k (t = 10k) while `k < floor(durationMs / 10)` and
  `10k < nowMs`: consume every pushed record with `e.t ≤ t` (a down: `g = strokeGain · min(1, (e.t − pressT) /
  refillMs)`, `F = F + g · (1 − F)`, `pressT = e.t`, `strokes += 1`; ups skipped); `F = F − F · decay` with `decay = 10 /
  fireDecayMs` computed once (the prototype's grouping, D1, not §6.8's `F·10/fireDecayMs`); `T = T + heatDecay ·
  (fullHeat · F − T) · dts` with `dts = 10 / 1000`, clamped to [0, 1]; if `t + 10 > rampMs`: `d = |T − centerAt(t +
  10)|`, credit 1 when `d ≤ zoneWidth / 2` (`inZone += 1`), else `max(0, 1 − (d − h) / (softFrac · zoneWidth))`;
  `credit += cr; n += 1`.
- `finish(S)`: advance to `durationMs + 1`; `rawScore = score = q(credit / n)` (0 when n = 0); `passed = score ≥
  p.passThreshold`; `breakdown = { inZone = inZone / n, strokes = strokes }`; flags `{}`; status "Ok"; elapsedMs 0.
- `checks(P, records, result)`: `HzInhumanRate` when `Checks.maxInWindow(down times, HZ_RATE_WINDOW_MS) ≥
  HZ_RATE_MAX_PRESSES` (both from Definitions).
- View at `nowMs` (the session advanced to the horizon): `phase` "Ramp" while `nowMs < rampMs`, "Hold" while
  `nowMs < durationMs`, else "Done"; `temperature` = T and `fire` = F after the last integrated tick; `zoneCenter` =
  `centerAt(nowMs)`; `zoneHalf` = `zoneWidth / 2`; `softBand` = `softFrac · zoneWidth`; `inZone` = |T − zoneCenter| ≤
  zoneHalf; `runningScore` = `q(credit / n)` so far (0 before the ramp ends); `timeLeftMs` = max(0, durationMs − nowMs).
- Feedback: `push` of a down returns `Stroke` with `value` = that stroke's `g`, computed from the pushed press times
  (not the simulation's state, so it fires at once); `advance` returns `Go` on its first call, `RampEnd` when the
  first scored tick is integrated, `EnterZone` / `LeaveZone` when a scored tick's in-zone state changes, `End` when the
  last tick is integrated.

### 3.8 `Minigames/TimingStrike` (§6.9, §16.21; Hammering)

Constants `TS_PERFECT_CORE_MIN_MS` 10, `TS_GRADE_PERFECT` 0.9, `TS_GRADE_GOOD` 0.6, `TS_OFFSET_OFFER_MIN_JUDGED` 8 (S6's
results card reads the last through the facade's re-export, [3.10]). Pattern `{ p, cycles = {{start, period, target}}, M, W, core, durationMs, hash }`.

- `generate(seed, p)`: `rT = Rng.new(seed, "TimingStrike.Tempo")`, `rO = Rng.new(seed, "TimingStrike.Offsets")`,
  `S = 0`; for i = 1…`strikes`: `P = math.round(beatMs · (1 + tempoJitter · (2 · rT:nextFloat() − 1)))`,
  `f = offsetMin + (offsetMax − offsetMin) · rO:nextFloat()`, `T = S + math.round(f · P)`, cycle `{S, P, T}`, `S += P`.
  `minGap` over consecutive targets; `M = windowMs + missPadMs`, then `min(M, math.floor((minGap − 1) / 2))` when there
  are ≥ 2 strikes, then `min(M, T_1)`; `W = min(windowMs, M)`; `core = min(W, max(perfectFrac · W,
  TS_PERFECT_CORE_MIN_MS))`; `durationMs = S + tailMs`. Hash words per cycle: start, period, target.
- `points(P, e)`: 0 for nil; `a = |e|`; 0 if a > W; 1 if a ≤ core; else `1 − (1 − edgePoints) · (a − core) / (W − core)`
  (left to right, D1). `grade(points)`: Perfect ≥ 0.9, Good ≥ 0.6, Ok > 0, else Miss. `bandMs(P, pts) = core + (1 − pts)
  / (1 − edgePoints) · (W − core)` (the |e| where points = pts; E-S3.4's grade bands).
- Session `{ i = 1, err = {}, judged = {}, whiffs = 0, combo = 0, bestCombo = 0, … }`: `push(S, t)` =
  `closeBefore(t)`, then the current span judges the first press with `T_i − M ≤ t ≤ T_i + M` (err = t − T_i), else a
  whiff; `closeBefore(t)` closes spans with `T_i + M < t` as misses (`err = false`); `advance(S, nowMs)` =
  `closeBefore(nowMs)`; `finish` closes everything (`closeBefore(durationMs + 1)`).
- `finish`: `score = rawScore = q(Σ_i points(err_i) / N)` (sum in cycle order); breakdown `judged` (spans with a press
  within ±M), `perfect` / `good` / `ok` (judged presses by grade; a judged 0-point press counts in `judged` only),
  `miss` (spans closed with no judged press), `whiffs`, `bestCombo`, `meanAbsErrMs` and `meanErrMs` (signed) over the
  judged errors in cycle order (0 when none). `judgeErrors(P, presses)` returns the judged errors in cycle order and is
  the one code path `finish` and `checks` share.
- `checks`: with n = #errors ≥ `TS_MIN_JUDGED`: `TsExactHits` when `#{|e| ≤ TS_EXACT_MS} ≥ math.ceil(TS_EXACT_FRAC · n)`;
  `TsLowVariance` when `Checks.sampleSd(errors) < TS_MIN_SD_MS`. Sorted by id.
- View (sweep units = fractions of the current cycle): `cycle` = the i with `start_i ≤ nowMs < start_i + P_i` (1 before
  GO, N in the tail); `marker` = `(nowMs − start_i) / P_i` clamped to [0, 1]; `windowCenter` = `(T_i − start_i) / P_i`;
  `windowHalf` = `W / P_i`; `goodHalf` = `bandMs(0.6) / P_i`; `perfectHalf` = `bandMs(0.9) / P_i`; `next` = cycle i + 1's
  `windowCenter` and `windowHalf` in its own sweep units (nil on the last); `lastGrade` / `lastErrorMs` from the latest
  decided span; `combo`; `runningScore` = q(Σ points of decided spans / decided spans), 0 before the first;
  `timeLeftMs`.
- Feedback: `push` returns `Strike` (i, `label` = grade, `value` =
  errMs) or `Whiff`; `advance` returns `Miss` (i) per span closed unjudged; `End` once every span is closed. Combo
  (feedback only, [9.1] new O "A" default): +1 per span decided with points > 0, back to 0 when a span is decided with 0
  points (a miss, or a judged press past W); whiffs do not touch it.
  `CycleStart` is not an `advance` event: the host plays it when the view's `cycle` changes, on the raw clock (D12); a
  case pins that `view(S, t).cycle` changes exactly at each `start_i`, whatever the session was advanced to.

### 3.9 `Minigames/PrecisionTrace` (§6.10, §16.22; Sharpening)

Constants (all §16.22, exported): `PT_PANEL_ASPECT` 3.0, `PT_FIXED_POINT` 16384, `PT_MARGIN_U` 0.15, `PT_MARGIN_V`
0.12, `PT_BLADE_REF_LEN` 4.5, `PT_EXAG_MAX` 2.0, `PT_EXAG_SHRINK` 0.9, `PT_LEN_MARGIN` 0.95, `PT_MAX_SOURCE_POINTS` 256,
`PT_SIMPLIFY_TOL` 0.004, `PT_SIMPLIFY_STEPS` 8, `PT_MIN_SOURCE_LEN` 0.4, `PT_FALLBACK_EDGE` (sides (±0.22, 0) → (±0.22,
2.6) → (0, 3.4), grip (0, 0, 0), axis (0, 1)), `PT_CHAIKIN_ITERS` 3, `PT_DS` 0.01, `PT_TAPER` 0.15, `PT_CLEAR_SKIP` 0.30,
`PT_CLEAR_FRAC` 0.35, `PT_CLEAR_CELL` 0.30, `PT_EVAL_MS` 20, `PT_SEARCH` 0.5, `PT_BIN` 0.02, `PT_VMAX_FACTOR` 6,
`PT_VMAX_MIN` 1.5, `PT_MAX_GAP_MS` 250, `PT_TRAVEL_MIN_MS` 6000, `PT_TRAVEL_MAX_MS` 30000; plus the prototype's
clearance-grid key stride `NCU` = 64 (no §16 row; it moves nothing while cell indices stay below it, and u ≤ 3 gives
at most 10). Pattern `{ p, pu, pv, arc, L, speed, leadInMs, travelMs, durationMs, usedFallback, hash }`.

- `sidesFromChains(chains, gripPoint, gripAxis)`: the prototype's: the main chain `chains[1]`, k = first index of the
  maximum of `(p − g) · A`; side A = points 1…k, side B = points n…k; a side is kept with ≥ 2 points; `{}` for no
  chain or fewer than 2 points.
- `edgeToPanel(sides, gripPoint, gripAxis, pacerSpeed): { number }?`: the prototype's (§6.10): `N = (A_y, −A_x)`;
  A and C per point; `Lb = aMax − aMin` (nil when ≤ 0); `s = 2.7 / max(4.5, Lb)`; `E = PT_EXAG_MAX`, or `min(E, 0.76 / (s ·
  (cMax − cMin)))` when cMax > cMin; `u0 = (3 − Lb · s) / 2`; `map(E)`: `u = u0 + (A − aMin) · s`, `v = 0.5 + (C −
  cMid) · s · E`, consecutive duplicates dropped; `maxLen = PT_LEN_MARGIN · (PT_TRAVEL_MAX_MS / 1000) · pacerSpeed`;
  shrink `E = max(1, E · 0.9)` while too long; then Douglas–Peucker (iterative stack, first maximum, keep when `dmax >
  tol`) with `tol` = 0.004 doubled per attempt (**by repeated `· 2`, not `2 ^ (steps − 1)`**, T-META-03; both exact), at
  most 8 attempts, else nil; nil when < 2 points or shorter than 0.4 u; output `{round(u · 16384), round(v · 16384),
  …}`.
- `fallbackSource(pacerSpeed)`: `edgeToPanel(PT_FALLBACK_EDGE's sides, {0, 0, 0}, {0, 1}, pacerSpeed)`, recomputed on
  every call (no memo).
- `generate(seed, p, source?)`: the prototype's `PT.generate` exactly: load the source (u, v / 16384, consecutive
  duplicates dropped), fallback when < 2 points or shorter than 0.4 u (`usedFallback`); Chaikin × 3 (`0.75a + 0.25b`,
  `0.25a + 0.75b`, ends kept); `resample(DS)` (the prototype's, with its last-point rule `acc > ds · 0.25`); arc
  lengths; left normals of `p_{i+1} − p_{i−1}` (ends one-sided); `rng = Rng.new(seed, "PrecisionTrace.Perturb")`;
  `K = max(1, math.round(L · bumpDensity))`; per bump: centre `(k − 1 + rng:range(0.2, 0.8)) · L / K`, width
  `bumpWidth · rng:range(0.7, 1.3)`, amplitude `perturbAmp · rng:range(0.5, 1.0) · rng:sign()` (draw order: centre,
  width, amplitude, sign); offsets `Σ amp · (1 − x²)²` for |x| < 1; clearance on the 0.30-u grid (`key = floor(y / G) ·
  64 + floor(x / G)`, a lookup map, never iterated; neighbour cells within `ceil(r / G)`, `|Δarc| > 0.30`, `best`
  starting at r²), clamp `|o| ≤ 0.35 · sqrt(best)` when found; taper `min(1, arc / 0.15, (L − arc) / 0.15)`; displace
  along the normal, clamp to [0.05, 2.95] × [0.05, 0.95]; resample; quantize `round(· 16384)` (hash words uQ, vQ per
  point); `pu, pv = q / 16384`; arc and L measured again; `travel0 = math.ceil(L / pacerSpeed · 1000 / PT_EVAL_MS) ·
  PT_EVAL_MS` (**this grouping**, not §6.10's `ceil(L/pacerSpeed·50)·20`, D1); `travelMs = clamp(travel0, 6000,
  30000)`; `speed = L / (travelMs / 1000)`; `durationMs = leadInMs + travelMs + tailMs`.
- `pacerArc(P, t) = clamp((t − leadInMs) · speed / 1000, 0, L)`; `pointAt(P, s)`; `nearest(P, cu, cv, sStar)`: the
  prototype's two-stage search (vertex window `[clamp(floor((s* − 0.5) / DS), 1, n − 1), clamp(ceil((s* + 0.5) / DS)
  + 1, 1, n − 1) + 1]`, first minimum; then the exact distance to segments (j − 1, j) and (j, j + 1), first minimum).
- Session: `push` appends a sample; `advance(S, nowMs)` evaluates ticks `t_k = leadInMs + 20k`, k = 1…`travelMs / 20`,
  with `t_k ≤ min(nowMs, latest sample t)` (§6.4 rule 7); `finish` evaluates every remaining tick up to `durationMs`
  regardless of samples. Tick evaluation, cursor interpolation (the `PT_MAX_GAP_MS` hold rule), tick 1's previous
  cursor at `t_1 − 20`, the accuracy, pace and coverage credits and the speed gate are the prototype's `evalTick`.
- `finish`: `A = accSum / K`, `Pc = paceSum / K`, `C = covered / ceil(L / 0.02)`, `score = rawScore = q(C · (wAccuracy
  · A + (1 − wAccuracy) · Pc))`; breakdown `{ accuracy = A, pacing = Pc, coverage = C, usedFallback = 0 or 1 }`.
- `checks(P, samples)`: the prototype's loop over samples in order, thresholds from Definitions, PtTooSmooth's dt
  bounds from D3's rows: `PtTooPrecise` (≥ 40 grinding samples in travel, mean nearest distance < 0.0008),
  `PtTooSmooth` (≥ 150 moving triplets: neighbours grinding, outer span > 0.002 u, both dt in [10, 40]; mean |Δ²p| <
  0.0002), `PtTeleport` (≥ 3 grinding steps with a jump > 0.25 u in ≤ 40 ms), `PtSparse` (samples in travel < 0.5 ·
  travelMs / 20); sorted.
- View: `pacerArc` = `pacerArc(nowMs)`, `pacerU/V` = `pointAt(pacerArc)`; from the latest sample, when there is one:
  `distance` and `cursorArc` = `nearest(…, pacerArc)`, `onPath` = distance ≤ halfWidth, `grinding` = its grind flag,
  `paceLag` = cursorArc − pacerArc when on the path; `accuracySoFar` = accSum / ticks evaluated (0 before the first);
  `coverage` = covered / nBins; `credit` = the accuracy credit of the latest evaluated tick (0 when that tick was not
  grinding or had no cursor, nil before the first), which M8 keeps for its 24-position trail (§12.8: colours at ≥ 0.9,
  ≥ 0.6, > 0, 0); `coveredRuns` = the covered bins as a flat list of runs `{first1, last1, first2, last2, …}` (bin b
  spans arc [(b − 1) · `PT_BIN`, b · `PT_BIN`)), built fresh on each call from the session's bins, so M8 tints the
  covered runs (§12.8) without holding session state (G14; critic A 3); `timeLeftMs`. The static path is the pattern's `pu`, `pv` (M8 draws it once).
- Feedback: `push` returns `GrindStart` / `GrindStop` when the samples' grind flag changes; `advance` returns `OnPath` /
  `OffPath` when an evaluated grinding tick's `d ≤ halfWidth` changes, `PaceWarn` (`value` +1 ahead, −1 behind) when
  |s_c − s\*| first exceeds `paceTol` after being within it, `Coverage` (`value` 25, 50, 75, 100) when coverage first
  reaches each quarter, `End` after the last tick.

### 3.10 `Minigames/Minigames`: the facade (§6.2, §10.5; T-MG-01, 02, 09, 13, 14)

```lua
Minigames.prepare(input: PrepareInput): (StepSpec, any)
Minigames.start(spec: StepSpec): (any?, "Desync"?)
Minigames.judge(spec: StepSpec, pattern: any, timeline: unknown, elapsedMs: number): MinigameResult
Minigames.replay(spec: StepSpec, pattern: any, records: { any }): MinigameResult
Minigames.encode(spec: StepSpec, records: { any }): buffer
Minigames.get(family: FamilyId): FamilyModule<any, any, any, any>   -- errors for a family with no module
Minigames.TS_OFFSET_OFFER_MIN_JUDGED: number   -- re-export for S6's results card (§6.2: S6 calls the facade only)
```

- `prepare`: require an enabled family with a module; `params = Params.resolve(family, material, tier, factors)`;
  for PrecisionTrace `source = edgeToPanel(sidesFromChains(edge.chains, edge.gripPoint, edge.gripAxis),
  edge.gripPoint, edge.gripAxis, params.pacerSpeed)` (nil without an edge, so the fallback plays); `pattern =
  generate(seed, params, source)`; `spec = { family, seed, params, source, durationMs = pattern.durationMs,
  countdownMs = Network.COUNTDOWN_MS, patternHash = hash(pattern), balanceVersion = input.balanceVersion }`. No
  checkpoint: one P0 burst (§1.6), bounded by T-PERF-02.
- `start(spec)`: `pattern = generate(spec.seed, spec.params, spec.source)` (params used verbatim, §6.4 rule 5);
  `nil, "Desync"` when `hash(pattern) ≠ spec.patternHash`.
- `judge` (§10.5, never throws on any `timeline`): `records, h = Timeline.decode(timeline, spec.family,
  spec.durationMs)`; Invalid(reason) on failure; Invalid("HashMismatch") when `h ≠ spec.patternHash`; else
  `replay(spec, pattern, records)` with `elapsedMs` copied in. Invalid ⇒ `score = rawScore = 0`, `passed = false`,
  `flags = {}`, `breakdown = {}`, `invalidReason` set. `judge` emits nothing (S5 logs `StepScored`).
- `replay`: `S = newSession(pattern)`; push every record in order; `result = finish(S)`; `flags =
  Checks.sorted(checks(pattern, records, result))`; when `Checks.anyHigh(family, flags)`: `score = min(rawScore,
  passThreshold)`; `passed = score ≥ passThreshold` (the same as `rawScore ≥ passThreshold`, T-MG-14); `rawScore` kept.
- `encode(spec, records) = Timeline.encode(spec.family, spec.durationMs, spec.patternHash, records)`.
- The registry `{ HoldZone = HoldZone, TimingStrike = TimingStrike, PrecisionTrace = PrecisionTrace }` is a frozen
  constant (Phase 2 adds rows).

### 3.11 `Minigames/Bots` (§6.12, §16.23; not authoritative)

```lua
Bots.PROFILES: { Elite: Profile, Good: Profile, Average: Profile, Poor: Profile }   -- §6.12's table + policy fields
Bots.variant(profile, fps: number, panelPx: number?): Profile                      -- e.g. Average@30, Elite@30/360px
Bots.play(spec: StepSpec, pattern: any, who: Profile | "Perfect" | "Exact" | "Idle", seed: number,
	opts: { offsetMs: number?, policy: ("pump" | "hold")?, fps: number? }?): { any }   -- records, through Input
Bots.run(cell: { family, material, tier, x: number?, profile: string, n: number, salt: number?, edge: any?,
	fps: number?, policy: string?, offsetMs: number? }): ({ number }, { boolean }, { boolean })  -- scores, passes, flagged
Bots.autoplaySource(records: { any }): (t: number) -> { any }   -- for MinigameHost.setInputSource (§12.5)
Bots.stats(scores, passes, flags?): { mean, p10, p50, p90, pass, flag, n }
Bots.seedOf(i: number, salt: number): number   -- (i · 2654435761 + salt · 40503 + 12345) mod 2^32 (Sim.seedOf)
BOT_REF_X = { Normal = 0.10, Hard = 0.30 }, BOT_EXTRA_LAG_MS = 8, BOT_PANEL_PX = 520,
BOT_HZ_PERFECT_LOOKAHEAD_MS = 300, BOT_RUNS_PER_CELL = 2000                       -- §16.23
```

- Profiles are §6.12's values plus the policy fields §6.12 does not list but the prototype carries (`hzBand`,
  `hzMinGapMs`, `hzMinHoldMs` for the hold policy; the pump fields; `panelPx`), value for value from v2 `Bots.luau`
  (critic A 16).
- `who`: a profile (the human model); "Perfect" (§6.12: TimingStrike exact intent at `opts.fps` 60 or 30, frame-quantized,
  never flagged; HoldZone the exact-state controller; PrecisionTrace on the pacer every 20 ms); "Exact" (E-S8.5's cheat:
  TimingStrike presses at the exact targets, unquantized; HoldZone and PrecisionTrace as "Perfect"); "Idle".
- Each policy is the prototype's (`tsHuman`, `tsPerfect`, `hzHuman` with "pump" and "hold", `hzPerfect`, `ptHuman`,
  `ptPerfect`, `frames`, `stamp`, `gauss`, `ou`), with the same Rng tags ("bot-ts", "bot-ts-perfect", "bot-hz-<policy>",
  "bot-pt", "bot-pt-cheat") and the same draw order, so the build reproduces the prototype's scores ([6.3] Reference).
  The change: a bot no longer writes stamps; at each simulated frame it calls the Recorder (`rec:button(down, f / 1000,
  dt / 1000)`, `rec:cursor(u, v, grind, f / 1000)`, `rec:go(...)` at the first frame), and HoldZone's bot advances its own
  live session to `rec:horizonMs(...)`, which equals the prototype's `clamp(stamp(frames, k), 0, durationMs)`.
  Exact-time bots (Perfect HoldZone and trace, every "Exact") pass `clockS = (tMs + 0.5) / 1000` and `frameDtS = 0` (D7).
- **The trace bot's draw order** (critic A 4(a)): `ptHuman` keeps the prototype's own `nextDue` rule and draws the
  tremor (two `gauss`) only on frames where the prototype samples (`floor(f) ≥ nextDue` and `≤ durationMs`), then calls
  `rec:cursor` with that position; on the first frame it draws once and passes the same position to `rec:go` and to
  `rec:cursor` (the Recorder records the second only when `floor(f₁) ≥ 20`, about 40 % of 30 fps runs). A fresh draw per
  frame, or one for `go` and another for the first `cursor`, shifts every later OU and lift draw and breaks parity.
- **Record-level differences that change no score or flag** (critic A 4(b, c)): the trace's first record is at t = 0
  where the prototype's is at `floor(f₁)` (ticks start at `leadInMs + 20`; I7); the Recorder drops records past
  `durationMs` where the prototype's TimingStrike bot clamps them to `durationMs` (always a whiff: `T_N + M <
  durationMs`) and its HoldZone bot drops t ≥ `durationMs` (no scored tick reads a down at `durationMs`). Records,
  `whiffs` and byte counts can differ; parity is on scores ([6.3]).
- `Bots.run` is the prototype's `Sim.run`: pattern seeds `Bots.seedOf(i, salt)` (salt 1 by default), bot seeds `i · 7919
  + salt · 31 + 17`, design factors `Params.refFactors(x or BOT_REF_X[tier])`, the HoldZone pump policy by default,
  PrecisionTrace on `cell.edge` (the caller passes an edge: tests use `tests/fixtures/Edges.arming`; `src` holds no
  blade data); it goes through `Minigames.prepare` and `Minigames.replay`.
- libm: `gauss` (Box–Muller: `math.log`, `math.cos`) and `ou` (`math.exp`) carry `-- allow-transcendental: player
  model noise (§6.12)` on each such line; `math.pi` is fine. No `^`. Generic `for` loops that accumulate use `ipairs`.
  `Bots.seedOf` may use integer `%` (Bots is outside §6.4 and `Source.spec`), or the Rng's `mod`. Because the bots use
  libm and the judge does not, bot outputs depend on the machine's C runtime (D14, [10] R6).

### 3.12 Require graph (no cycles; every edge downward or inside the folder)

`Types` → Definitions/Types (D5: nothing from Physics). `Rng` → nothing. `Checks` → Definitions/MinigameFamilies,
Types. `Params` → Definitions/{MinigameFamilies, Tiers, Types}, Types. `HoldZone`, `TimingStrike`, `PrecisionTrace` →
Rng, Checks, Types, Util/Quantize, Definitions/MinigameFamilies. `Timeline` → Definitions/MinigameFamilies, Types and
PrecisionTrace's exported panel constants (so `Timeline` is built after `PrecisionTrace`, [11]). `Input` →
Definitions/MinigameFamilies, Types. `Minigames` → Params, Timeline, Checks, the three families,
Definitions/{MinigameFamilies, Network}, Types. `Bots` → Minigames, Input, Params, Rng, the three families, Types. No
Minigames module requires Physics; only the tests that read `Analyze.run` do (D6).

---

## 4. Prototype → build map

### 4.1 Function by function (v2; v1 only where noted)

| Prototype (`docs/spec/prototypes/S3/v2/…`) | Becomes | What changes on the way |
|---|---|---|
| `Rng.luau` `mul32`, `fnv1a32`, `fmix32` | `Rng.mul32`, `Rng.fnv1a32`, `Rng.fmix32` | `%` → `mod(x, m) = x − floor(x/m)·m` [3.2]; same values (T-RNG-01) |
| `Rng.new`, `Rng.fromState`, `nextU32`, `nextFloat`, `range`, `int`, `chance`, `sign` | same names in `Rng` | `assert` → `error` with a message; frozen metatable; `% M32` → `mod`; expressions unchanged |
| `HZ.hashU32` (in HoldZone) | `Rng.hashU32` | moved to the Rng (all three families hash with it); `v % 256`, `v // 256` → `band(v, 0xFF)`, `rshift(v, 8)`; asserts a u32 |
| `HZ.round4`, the `round4` uses in TS and PT | `Util/Quantize.q(x, Quantize.SCALAR_SCALE)` | the same function on finite input (§6.4 rule 6) |
| `Params.DEFS`, `TIER_INDEX`, `FACTOR_ORDER` | `Definitions/MinigameFamilies` (exists), `Definitions/Tiers.order`, `Definitions/Types`' FactorId order | no copies in Minigames (D2) |
| `Params.resolve`, `factorX`, `refFactors`, `find` | `Params.resolve` / `resolveDef`, private `xOf`, `Params.refFactors`, (find → `Checks.value` for checks; params by name inside `resolveDef`) | factors are `{FactorValue}` arrays only (the map form was for scripts); tier index from `Tiers.get(tier).order`; returns 8 FactorValues for `refFactors` (raw = x) |
| — | `Params.explain` | new (§6.2, §12.2 Intro) |
| `HZ.generate`, `centerAt`, `newSession`, `push`, `advance`, `finish`, `checks`, `replay` | `HoldZone.generate`, `centerAt` (stateless + the pointer variant), `newSession`, `push`, `advance`, `finish`, `checks`; `replay` → `Minigames.replay` | thresholds from Definitions; `HZ_InhumanRate` → `HzInhumanRate`; `//` → `math.floor(/)`; `finish` returns a full `MinigameResult` (breakdown `inZone`, `strokes`); `push`/`advance` return FeedbackEvents; `s.hist` (bot perception) stays a bot-only optional field filled by `advance` when present, or the bot keeps its own history [3.11] |
| — | `HoldZone.view`, feedback | new |
| `TS.generate`, `points`, `newSession`, `closeBefore`, `press`, `advance`, `finish`, `checks`, `replay` | `TimingStrike.generate`, `points`, `grade`, `bandMs`, `judgeErrors`, `newSession`, `push` (= press), `advance`, `finish`, `checks` | `(minGap − 1) // 2` → `math.floor((minGap − 1) / 2)`; `math.huge` sentinel kept; breakdown adds `judged`, `good`, `ok`, `miss`, `bestCombo`, `meanAbsErrMs`; `TS_ExactHits`/`TS_LowVariance` → `TsExactHits`/`TsLowVariance`; `checks` takes `(P, presses, result)` and recomputes the errors through `judgeErrors` |
| v1 `TS.grade` | `TimingStrike.grade` | thresholds `TS_GRADE_PERFECT` / `TS_GRADE_GOOD` |
| — | `TimingStrike.view`, feedback, combo | new ([9.1] new O "A") |
| `PT.sidesFromChains`, `polyLen`, `douglasPeucker`, `edgeToPanel`, `FALLBACK_SIDES`, `chaikin`, `resample`, `quant` | `PrecisionTrace.sidesFromChains`, private helpers, `edgeToPanel`, `PT_FALLBACK_EDGE` | `2 ^ (steps − 1)` → a tolerance doubled each attempt; the diagnostic `info` second return is dropped from the public `edgeToPanel` (a private `edgeToPanelInfo` may keep it for tests) |
| `PT.fallbackSource` (memoized in `FALLBACK_SOURCE`) | `PrecisionTrace.fallbackSource` | no memo (no module-level state) |
| `PT.generate`, `pacerArc`, `pointAt`, `nearest`, `newSession`, `push`, `cursorAt`, `evalTick`, `advance`, `finish`, `checks`, `replay` | same names (`cursorAt`, `evalTick` private) | the clearance grid's `for _, j in list` → `ipairs`; `//` → `floor`; `advance(S, nowMs)` caps at the latest sample; `checks` reads thresholds and D3's dt bounds from Definitions; flags renamed (`PtTooPrecise`, `PtTooSmooth`, `PtTeleport`, `PtSparse`); breakdown `usedFallback` as 0/1; the pattern drops the diagnostics `clampedTravel`, `clearChecks` (tests may recompute them) |
| — | `PrecisionTrace.view`, feedback | new |
| `Timeline.luau` `encode`, `decode`, constants | `Timeline.encode`, `decode`, `capBytes` | constants from Definitions; `for _, r in records` → `ipairs`; D8's oversize `TooMany`; per-family codec table |
| — | `Input` (Recorder), `Checks`, `Minigames` facade, `Types` | new (§6.2) |
| `Bots.rng`, `gauss`, `ou`, `frames`, `firstFrameAtOrAfter`, `stamp`, `PROFILES`, `variant`, `renderLag`, `tsHuman`, `tsPerfect`, `hzHuman`, `hzPerfect`, `normalAt`, `q16`, `ptHuman`, `ptPerfect`, `stats` | `Bots.*` (same names; `rng`, `stamp`, `q16` private) | records go through `Input` (D7); libm lines tagged; `seed % 4294967296` kept (Bots) or `Rng`'s `mod`; `table.clone` and `for _, x in t` loops that accumulate → `ipairs` |
| `Sim.REF_X`, `seedOf`, `run`, `summary`, `source` (cached) | `Bots.BOT_REF_X`, `Bots.seedOf`, `Bots.run`, `Bots.stats` | `source` takes the edge from the caller (no blades and no cache in `src`) |
| `Blades.luau` (arming, longsword, dagger, sabre, flamberge, tilted, serrated, saw, zigzag, `ORDER`) | `tests/fixtures/Edges.luau` (all nine, 17-digit literals); the zigzag also as `Cost.X08_EDGE` in `tests/fixtures/Cost.luau` | computed once with the prototype, pasted as literals (no `^`, `sin`, `cos` at load); each with `{ chains, gripPoint = {0, 0.88, 0}, gripAxis }` |
| `dist.luau` | not ported | its cells become T-MG-04's; `S3-score-distributions.luau` stays S4's artifact in `docs/` and the parity reference [6.3] |
| `golden.luau` | T-MG-13 (hand-written E-S3 expectations) + `minigames.bv1.golden.txt` | — |
| `det.luau` | T-MG-09 (live = replay = codec) and part of T-MG-08 | adds the four decode reasons det.luau never planted (`TooMany`, `Length`, `BadKind`, `BadFlags`) |
| `cost.luau`, `worst.luau`, `cost2.luau` | T-PERF-02 (`tests/Minigames/Perf.spec.luau`) | worst.luau's sine path is built with exact arithmetic in the test (a triangle wave) or with `math.sin` (tests are not authoritative; only the timing matters) |
| `checks.luau` | T-MG-10 | sizes from §14.8 / §16.32, not the script's 100,000 / 1,000 / 500 |
| `perfect.luau` | T-MG-03, T-MG-11 | — |
| `multisweep.luau`, `sweep.luau`, `hztune.luau`, `base.luau`, `nearest2.luau`, `dbg_hz.luau`, `make_appendix_table.py` | not ported | tuning tools (E-S3.9) |
| `rng_vectors.luau`, `rng_ref.py` (v1 folder) | T-RNG-01's vectors | [6.2] lists them, every value checked by running `rng_ref.py` for this plan |
| v1 `HoldZone`, `TimingStrike`, `PrecisionTrace`, `Params`, `Bots*`, `sim_*`, `tune_*`, `run_all`, `golden`, `probe`, `out_*.txt` | nothing | the draft's hold model and older tunings, superseded (E-S3 lead) |

### 4.2 Bit-level pins (D1): write these expressions exactly so

Anything below regrouped changes last bits. Hashes and scores are quantized (keys × 10⁶, 1/16384, integer ms, `q`),
so that reaches a hash, a golden or a score only about once in 10¹⁰ values: `Reference.spec`'s full-precision
side-by-side check ([6.3]) is what sees it (D1).

- Rng: `range = lo + (hi − lo) · nextFloat()`; `int = lo + floor(nextFloat() · (hi − lo + 1))`.
- Params: `base · mMat · mTier · mDesign`, left to right; design `sum = 1` then `sum += k · clamp(x, 0, 1)` per term;
  `clamp(sum, lo, hi)`; `max(min)`, then `min(max)`; `math.round(v / q) · q`.
- HoldZone: `c0 = lo + (hi − lo) · rng:range(0.3, 0.7)`; `mag = driftSpeed · seg / 1000 · rng:range(0.5, 1.0)`;
  `F = F + g · (1 − F)` with `g = strokeGain · min(1, (e.t − pressT) / refillMs)`; `F = F − F · decay`, `decay = 10 /
  fireDecayMs`; `T = T + heatDecay · (fullHeat · F − T) · dts`, `dts = 10 / 1000`; `h = zoneWidth / 2`, `soft =
  softFrac · zoneWidth`, credit `1 − (d − h) / soft`; smoothstep `s · s · (3 − 2 · s)`, `c0 + (c1 − c0) · e`.
- TimingStrike: `P = math.round(beatMs · (1 + tempoJitter · (2 · u − 1)))`; `f = offsetMin + (offsetMax − offsetMin) ·
  u'`; `T = S + math.round(f · P)`; `1 − (1 − edgePoints) · (a − core) / (W − core)`; mean then squares (two passes).
- PrecisionTrace: `usableU = PANEL_W − 2 · MARGIN_U`, `usableV = 1 − 2 · MARGIN_V` (computed, as the prototype does),
  `s = usableU / max(BLADE_REF_LEN, Lb)`, `E = min(E, usableV / (s · (cMax − cMin)))`, `u0 = (PANEL_W − Lb · s) / 2`,
  `cMid = (cMin + cMax) / 2`, `v = 0.5 + (C − cMid) · s · e`, `maxLen = LEN_MARGIN · (TRAVEL_MAX_MS / 1000) ·
  pacerSpeed`; Chaikin `0.75 · x0 + 0.25 · x1`; bump centre `(k − 1 + r) · L / K`; `ba = perturbAmp · r1 · sign`; the
  offset sum in bump order; `lim = CLEAR_FRAC · sqrt(best)`; `travel0 = ceil(L / pacerSpeed · 1000 / EVAL_MS) · EVAL_MS`;
  `speed = L / (travel / 1000)`; `pacerArc = (t − leadInMs) · speed / 1000`; the tick speed `sqrt(…) / (EVAL_MS / 1000)`;
  `score = q(C · (wAccuracy · A + (1 − wAccuracy) · Pc))`.

---

## 5. Constants

### 5.1 What M4 reads or defines

"Repo" says whether the constant exists in the working tree today; "Manifest" whether `Definitions/Manifest` hashes it
(a change then moves the BALANCE fingerprint, [5.3]). Every value below is the SPEC's.

| Constant(s) | Value | Lives in | SPEC row | Repo | Manifest |
|---|---|---|---|---|---|
| every family parameter (§6.8–§6.10 tables: base, Steel, tier columns incl. Expert…Hell placeholders, design k and clamp, quantum, min, max) | §6.8–§6.10, E-S3.3 | `Definitions/MinigameFamilies` `params` | §16.12 | yes (M1) | yes |
| `passThreshold` (every family) | 0.50 | MinigameFamilies `params` | §16.12 | yes | yes |
| `TIMELINE_FORMAT_VERSION` / `TIMELINE_HEADER_BYTES` | 1 / 12 | MinigameFamilies | §16.12 | yes | yes |
| `FAMILY_CODE` / `RECORD_BYTES` / `MAX_RECORDS` / `MAX_TIMELINE_BYTES` | 1,2,3 / 3,2,7 / 1024, 512, 2048 / 14348 | MinigameFamilies | §16.12 | yes | yes |
| `HZ_RATE_WINDOW_MS` / `HZ_RATE_MAX_PRESSES` | 1000 / 30 | MinigameFamilies `checks` | §16.12 | yes | yes |
| `TS_MIN_JUDGED`, `TS_MIN_SD_MS`, `TS_EXACT_MS`, `TS_EXACT_FRAC` | 8, 1.5, 1, 0.90 | `checks` | §16.12 | yes | yes |
| `PT_PRECISE_MIN_SAMPLES`, `PT_PRECISE_MEAN_DEV`, `PT_SMOOTH_MIN_TRIPLETS`, `PT_SMOOTH_MEAN_JERK`, `PT_SMOOTH_MIN_MOVE`, `PT_TELEPORT_DIST`, `PT_TELEPORT_MAX_DT`, `PT_TELEPORT_COUNT`, `PT_SPARSE_FRAC` | 40, 0.0008, 150, 0.0002, 0.002, 0.25, 40, 3, 0.5 | `checks` | §16.12 | yes | yes |
| **`PT_SMOOTH_DT_MIN_MS` / `PT_SMOOTH_DT_MAX_MS`** (D3) | 10 / 40 | `checks` (PrecisionTrace) | §10.6 text only; **new §16.12 row** | **no** | yes → re-bless |
| `flagLevels` | HzInhumanRate, TsLowVariance, TsExactHits, PtTooPrecise High; PtTooSmooth, PtTeleport, PtSparse Medium | MinigameFamilies | §16.12 | yes | yes |
| `RNG_SPLITMIX_GAMMA`, `RNG_FMIX_C1`, `RNG_FMIX_C2`; `FNV_BASIS` / `FNV_PRIME` | 0x9E3779B9, 0x85EBCA6B, 0xC2B2AE35; 0x811C9DC5 / 0x01000193 | `Minigames/Rng` | §16.19 | no | no (code; pinned by T-RNG-01 and T-MG-13) |
| `HZ_TICK_MS` | 10 | `Minigames/HoldZone` | §16.20 | no | no |
| `TS_PERFECT_CORE_MIN_MS`; `TS_GRADE_PERFECT` / `TS_GRADE_GOOD`; `TS_OFFSET_OFFER_MIN_JUDGED` | 10; 0.9 / 0.6; 8 | `Minigames/TimingStrike` | §16.21 | no (10 is hard-coded in `tests/Definitions/MinigameFamilies.spec.luau` line 32) | no |
| `PT_PANEL_ASPECT` … `PT_TRAVEL_MAX_MS` (the 27 names of [3.9]) | §16.22 | `Minigames/PrecisionTrace` | §16.22 | no (30000 hard-coded in the same spec, line 31) | no |
| `NCU` (clearance grid stride) | 64 | `Minigames/PrecisionTrace` (private) | none (prototype only) | no | no |
| `BOT_REF_X`, `BOT_EXTRA_LAG_MS`, `BOT_PANEL_PX`, `BOT_HZ_PERFECT_LOOKAHEAD_MS`, `BOT_RUNS_PER_CELL`; the §6.12 profile table | {0.10, 0.30}, 8, 520, 300, 2000; §6.12 | `Minigames/Bots` | §16.23, §6.12 | no | no |
| `COUNTDOWN_MS` | 3000 | `Definitions/Network` | §16.13 | yes | no (Network excluded, §1.3 L5) |
| `SCALAR_SCALE` | 10000 | `Util/Quantize` | §16.17 | yes | — |
| `MAX_STEP_FLAGS` | 10 | `Definitions/Limits` | §16.2 | yes | excluded |
| `BOT_RUNS`, `FP_RUNS_TS`, `FP_RUNS`, `SOLVABILITY_SEEDS`, `PERFECT_MIN_SCORE`, `PERFECT_30FPS_MIN_SCORE`, `PERFECT_HZ_MIN_SCORE`, `FAIRNESS_MAX_SD`, `TIER_MIN_MEAN_DROP`, `STEEL_MEAN_DROP`, `CHI2_CRIT`, `REPLAY_BUDGET_MS`, `PT_GENERATE_BUDGET_MS`, `REJECT_BUDGET_MS`, `PERF_RUNS`, `CASE_BUDGET_MS`, `SLOW_CASE_BUDGET_MS`, `FUZZ_N_GARBAGE`, `PROP_N` | 400, 300000, 20000, 1000, 0.98, 0.95, 0.95, 0.08, 0.05, [0.01, 0.08], 37.70, 8, 5, 2, 15, 2000, 300000, 2000, 200 | `tests/lib/Tol` | §16.32 | yes | — |
| **new Tol rows** (D10): `BOT_RUNS_FAIL`; `STEEL_DROP_RUNS`; `FAIRNESS_SEEDS` × `FAIRNESS_BOT_RUNS`; `TP_RUNS`; `PERFECT_HZ_RUN_MIN_SCORE`; `PROP_N_FAST`; `FUZZ_N_STRUCT_FAST` | 1000; {TimingStrike 20000, HoldZone 4000, PrecisionTrace 4000}; 100 × 20; 2000; 0.85; 25; 200 | `tests/lib/Tol` | **new §16.32 rows** | no | — |

`TS_GRADE_*`, the views and the FeedbackEvents are presentation: they move no score. Everything else in the table
moves outcomes: a change to a Manifest row moves the fingerprint, a change to a code constant moves T-MG-13's goldens
and hashes; either is a BALANCE change once released (§14.9).

### 5.2 The two hard-coded test constants (M1-notes B2)

When `PrecisionTrace` and `TimingStrike` exist (slices 3 and 5, [11]), replace lines 31–32 of
`tests/Definitions/MinigameFamilies.spec.luau` with requires of the modules' exported `PT_TRAVEL_MAX_MS` and
`TS_PERFECT_CORE_MIN_MS` (tests may require any `src/shared` module), so the evidence checks read the one source.

### 5.3 The fingerprint re-bless (D3), at BALANCE_VERSION 1

1. Add the two rows to `PrecisionTrace.checks` in `src/shared/Definitions/MinigameFamilies.luau` (after
   `PT_SMOOTH_MIN_MOVE`, UPPER_SNAKE, positive), and extend T-DEF-05's expected PrecisionTrace list in
   `tests/Definitions/MinigameFamilies.spec.luau` (near line 458).
2. Leave `BALANCE_VERSION` at 1 (no item exists before release; §14.9: "a round that changes outcome code re-blesses
   its goldens at the same version").
3. T-BAL-01 refuses changed data under an unchanged version even with `--bless` ("--bless alone never accepts this"),
   so delete `tests/golden/balance_fingerprint.golden.txt` first; the guard then writes it on `--bless` (its "golden
   missing" branch). This is how M1, M2 and the shift fix did it.
4. Bless **only** the guard's suite: `lune run tests/run -- --bless --filter "Definitions/BalanceGuard"`. Never a
   whole-suite `--bless` while another team's work sits in the tree: it would rewrite their difficulty goldens too.
5. `git status --short tests/golden` must show the fingerprint alone (then later `minigames.bv1.golden.txt`, new);
   review the new `{bytes, fnv1a32, version = 1}` (bytes grow by the two rows' canonical text); then
   `lune run tests/run -- --filter "Definitions/"` passes.
6. Hand the lead the SPEC row for §16.12 ([12]).

M4's own golden (`minigames.bv1.golden.txt`, [6.5]) is new, so `-- --bless --filter "Minigames/Minigames"` writes it once, in slice 8; no version
question arises until the first release.

---

## 6. Tests

### 6.1 Files

Suites are named after their file (`"Minigames/Rng"`, …), so `--filter "Minigames/"` selects all of M4. "Slice" is
[11]'s.

| File | Holds |
|---|---|
| `tests/Minigames/MinigamesHelpers.luau` | `stepInputFrom(analysis, stepIndex, seed)` = §4.8's `Pipeline.stepInput` mapping (`family = Steps.get(step).family`, `material`, `tier`, `factors`, `edge = {chains, gripPoint, gripAxis}` for PrecisionTrace only, `balanceVersion`), typed from `Analyze`'s exports so luau-lsp checks D5's structural copies; M5's T-PIPE compares the real one with it; `inputFor(family, material, tier, x, seed, edge?)` (with `Params.refFactors`); `configSalt(name) = Dump.fnv1a32(name)` (§14.8); the E-S3.2 table as literals; scripted timelines (TimingStrike presses, HoldZone strokes, trace samples) for slices 6–7 |
| `Rng.spec.luau` | T-RNG-01…06 and Rng's generic properties (slice 1) |
| `Params.spec.luau` | T-MG-07 (slice 2) |
| `Checks.spec.luau` | `mean`, `sampleSd`, `maxInWindow` (exact boundaries), `value` / `level` / `anyHigh` / `sorted` (slice 2) |
| `TimingStrike.spec.luau`, `HoldZone.spec.luau`, `PrecisionTrace.spec.luau` | each family's rules, E-S3 goldens (T-MG-13 (a)), checks at their thresholds on scripted input, views and feedback; HoldZone's "holding alone scores 0"; TimingStrike's `view.cycle` at each `start_i` (slices 3–5) |
| `Timeline.spec.luau` | codec round trips on scripted records, one hand-written byte golden per family, T-MG-08's decode-level cases (slice 6) |
| `Input.spec.luau` | stamping, caps, due times, horizon, T-MG-15's stamping and offset cases, T-MG-16 (slice 7); T-MG-15's bot cases (slice 8) |
| `Minigames.spec.luau` | the facade: T-MG-01, T-MG-02's scripted and `Prop` cases, T-MG-08's judge-level cases, T-MG-14 on scripted TimingStrike presses (slice 7); T-MG-02's bot rows, T-MG-09, T-MG-14's HoldZone Exact, and golden (b), written with all its rows (the scripted ones and the frozen bot timelines) and blessed once (slice 8); one integration case from `Analyze.run` (F5, C02: prepare plays each step, Sharpening on the real main chain with `usedFallback = 0`), once the Physics fix is committed |
| `Bots.spec.luau` | profiles = §6.12's table plus the policy fields, determinism, Perfect, Exact and Idle, `autoplaySource`, records valid (decode accepts every bot timeline), T-MG-11 fast, `Bots.play` reproduces `MinigameTimelines`, the libm canary (slice 8) |
| `Reference.spec.luau` | prototype parity and the full-precision side-by-side check (`t.slow`, Lune only, [6.3] "Reference"; slice 8) |
| `Statistics.spec.luau` | L3: T-MG-03, 04, 05, 06, 09 (slow), 11 (slow), 12, 15 (slow); one case per family × assertion group so each stays under `SLOW_CASE_BUDGET_MS` (slice 9) |
| `FalsePositives.spec.luau` | L3: T-MG-10, one case per TimingStrike device and tier (8), two PrecisionTrace halves, HoldZone, the other trace devices, TP (slice 9) |
| `Properties.spec.luau` | §14.5's generic properties across the public functions ([6.7]); the PrecisionTrace and bot rows at `PROP_N_FAST` in the quick run, `PROP_N` under `t.slow` |
| `Source.spec.luau` | §6.4's whitelist on the authoritative Minigames files ([3.0]; slice 1, then at every slice) |
| `Perf.spec.luau` | T-PERF-02 (`t.slow`; slice 10) |
| `tests/lib/Cheats.luau` | new ([6.6]): `malformed`, `flood`, `replay`, `garbageBuffers` in slice 6, `exact` in slice 8 |
| `tests/fixtures/Edges.luau` | new: the nine reference edges of `Blades.luau` as `{ name, chains, gripPoint, gripAxis }`, 17-digit literals, `order` list (slice 5) |
| `tests/fixtures/MinigameTimelines.luau` | new (D14): golden (b)'s bot timelines as hex buffers, one per family × tier × profile (24, about 60 KB), written once in slice 8 from `Bots.play` and `Minigames.encode` |
| `tests/fixtures/Cost.luau` | add `X08_EDGE` (the 256-point zigzag, ±0.30 stud, y from 1.48 to 4.88) beside the X08 aliases (slice 5) |
| `tests/golden/minigames.bv1.golden.txt` | new, blessed once, in slice 8 ([6.5]) |

### 6.2 T-RNG-01…06 (`Rng.spec.luau`)

E-S8.5 sources T-RNG-01 from "`kat/` (`studies/kat_xorshift32.py`)": that is S8's xorshift32 stand-in, superseded by
S3's xoshiro128\*\* ([9.2] I1). The vectors below are E-S3.1's, every one re-derived for this plan by running
`docs/spec/prototypes/S3/rng_ref.py` (independent Python big integers); the tagged streams' states and floats and the
extra rows were not in E-S3.1 and come from the same run. Both critics re-derived every vector again from [3.2]'s own
text (critic B: 0 mismatches over 300,169 `mul32` pairs, 20,000 `fmix32` values and 2,000 streams × 50 draws).

- **01 vectors** (exact integers; floats exact doubles):
  - FNV-1a32: `""` 0x811C9DC5, `"a"` 0xE40C292C, `"foobar"` 0xBF9CF968, `"TimingStrike.Offsets"` 0xBDE3CD3F,
    `"HoldZone.Target"` 0x364C5DC9, `"TimingStrike.Tempo"` 0x6AE6E414, `"PrecisionTrace.Perturb"` 0xCE7A16CE.
  - `mul32`: (0xFFFFFFFF, 0xFFFFFFFF) → 1; (0x80000000, 2) → 0; (0x01000193, 0x811C9DC5) → 84696351;
    (123456789, 987654321) → 4227814277; (0, 0xFFFFFFFF) → 0. `hashU32(FNV_BASIS, 0)` = 0x4B95F515,
    `hashU32(FNV_BASIS, 0xDEADBEEF)` = 0x90879FCB.
  - Raw xoshiro128\*\* from state (1, 2, 3, 4), first 10: 11520, 0, 5927040, 70819200, 2031721883, 1637235492,
    1287239034, 3734860849, 3729100597, 4258142804.
  - `Rng.new(1, "")`: state 0x283F5546 0xD3E69993 0xE0DFBA52 0xF9D93A6F; u32 × 6: 3296685081, 292216795, 3203276040,
    3343330025, 3022133357, 443753119; then floats 0.7009810614399612, 0.34134213626384735.
  - `Rng.new(3735928559, "")`: state 0x8D72B72A 0x53A3D0FD 0xD068308F 0x22AE1FC7; u32 × 6: 3856547673, 1244478788,
    63559405, 3329023417, 1418849053, 466841299; floats 0.8987551447935402, 0.7545752725563943.
  - `Rng.new(1, "TimingStrike.Offsets")`: state 0xC4A92F6A 0xFC1C82C9 0x630FE6FF 0xA1A56D9E; u32 × 6: 2172563110,
    3751778701, 3705501078, 924797711, 2910597952, 64598121; floats 0.44087175047025084, 0.931851631263271.
  - `Rng.new(3735928559, "TimingStrike.Offsets")`: state 0x20BDFADC 0x84BE86B5 0x7D60DDAC 0x97CC1BD1; u32 × 6:
    3201755939, 1102565783, 4063799498, 528979833, 2160534696, 2194535758; floats 0.6990435346961021, 0.9730237319599837.
  - `Rng.new(0, "")`: state 0x09CEF78C 0x79661DE2 0xEA0EB7EE 0xE8B2C241; u32 × 4: 2040553127, 2671230994, 3535833209,
    446703493. `Rng.new(4294967295, "")`: state 0xE7469B4A 0x67ECDB64 0x47A974D7 0xAAEBFA63; u32 × 4: 1363692059,
    3358058105, 1851661954, 1516388948.
  - Helpers (critic B 12; re-derived for r2 with an independent implementation): one `Rng.new(1, "HoldZone.Target")`
    drawn in this order gives `range(0.3, 0.7)` = 0.5807066061533988, `int(900, 2200)` = 2060, `chance(0.25)` = false,
    `range(0.5, 1.0)` = 0.8602050932822749, `sign()` = 1, `int(1, 16)` = 16 (E-S3.7's keys 0.6323, 5060 and 0.4000
    follow). Floats are compared as numbers, never as strings.
- **02 determinism**: the same (seed, tag) gives identical 10,000-draw streams for `nextU32`, `nextFloat`, `range`,
  `int`, `chance`, `sign`; `Rng.new` with `nil` and `""` agree; two instances never share state (drawing from one
  leaves the other's next value unchanged).
- **03 seed validation**: `Rng.new` errors (`A.throws`, message contains "u32") for NaN, ±inf, −1, −0.5, 1.5,
  2^32, a string, nil; accepts 0, 1, 2^32 − 1. `hashU32` errors on a non-u32 word.
- **04 χ² uniformity** (`t.slow`): top 4 bits of `nextU32` into 16 buckets, n = 160,000 per stream, χ² < `CHI2_CRIT`
  37.70 (15 dof, p = 0.001), for seeds {1, 2, 3, 0xC0FFEE} × tags {"", the four game tags} (20 streams); and
  `int(1, 16)` over the same n for seed 1. Fast case: n = 16,000 on two streams.
- **05 derived tags collision-free**: tags `"T-RNG-05/<i>"`, i = 1…1000, plus the four game tags: 1,004 distinct
  `fnv1a32` values; for seeds {0, 1, 0xFFFFFFFF} the 1,004 initial states (and first outputs) are distinct.
- **06 independence** (`t.slow`): 2-D χ² on 4 × 4 buckets (top 2 bits of a draw from stream a, top 2 bits of the
  paired draw from stream b), n = 160,000, < 37.70: every pair of the four game tags at seeds {1, 0xDEADBEEF}; the same
  tag at seeds s and s + 1 (s = 1, 1000, 0xFFFFFFFE); lag-1 pairs inside one stream, taken non-overlapping ((x₁, x₂), (x₃, x₄), …; overlapping pairs exceed 37.70 with
  probability 0.0049, not 0.001: critic B 12).
- Seeds are fixed, so each χ² case is pass or fail per code version (§14.8), and for an exact port each outcome is
  known (*precomputed*, critic B `rng_check`, from [3.2]'s text): T-RNG-04's 20 streams pass with the highest χ² 30.87
  (seed 0xC0FFEE, "TimingStrike.Tempo"), `int(1, 16)` at most 22.50 and the fast cases at most 16.37; T-RNG-05's 1,004
  hashes, states and first outputs are distinct; T-RNG-06's 37 cases pass with the highest 28.20. r1's "≈ 4 % one-time
  chance" is therefore 0: a failing χ² case means a stream bug (T-RNG-01 fails with it) or, for `int(1, 16)`, an `int`
  bug. It is never re-seeded (that would be cherry-picking).

### 6.3 T-MG-01…16

Inputs come from `MinigamesHelpers.inputFor` unless named. "Every config" = 3 families × {Iron, Steel} × {Normal,
Hard} × x ∈ {0, 0.3, 1}; PrecisionTrace on `Edges.arming` unless a blade is named. *Precomputed* outcomes are critic
B's prototype runs with the pinned names of [6.4] (D11).

- **T-MG-01 deterministic, StepSpec complete** (`Minigames.spec`, slice 7): for every config × seeds {0, 1, 0xDEADBEEF,
  2^32 − 1}: `prepare` twice gives deep-equal specs and patterns; the spec has every field, `params` deep-equals
  `Params.resolve`, `durationMs` = the pattern's, `countdownMs` = `Network.COUNTDOWN_MS`, `patternHash` = the family's
  `hash(pattern)`, `balanceVersion` = the input's, `source` set only for PrecisionTrace (nil with no edge or a
  fallback); `start(spec)` rebuilds a deep-equal pattern; `start` returns `nil, "Desync"` for the seed + 1, a moved
  source point, or a nudged **generation** parameter (HoldZone `driftSpeed`, TimingStrike `beatMs`, PrecisionTrace
  `perturbAmp`); and the converse: a nudged **scoring** parameter (`zoneWidth`, `windowMs`, `halfWidth`,
  `passThreshold`) does not desync, since hashes cover the pattern only and the client uses `params` verbatim (§6.4
  rule 5; critics A 8, B 13(b): hashing params to "fix" the case would break E-S3's hashes); `judge` twice on one
  buffer gives deep-equal results.
- **T-MG-02 passed ⇔ Ok ∧ score ≥ pass line** (`Minigames.spec`): scripted (slice 7): boundary runs (TimingStrike
  N = 12 with exactly 6 full-point presses → score 0.5000, passed; 5 full and one 0.9851 press → 0.4988, failed), every
  Malformed cheat (Invalid → `passed = false`, score 0), a `Prop.check` over random record sets per family
  (`PROP_N_FAST` in the quick run, 200 under `t.slow`); with Bots (slice 8): every bot profile's runs (Idle → 0) and the
  Exact cheats (clamped to 0.5 → passed).
- **T-MG-03 solvability** (L3, `Statistics.spec`): the Perfect bot, `SOLVABILITY_SEEDS` (1,000) pattern seeds per cell
  (3 families × 2 tiers × 2 materials, x = `BOT_REF_X[tier]`): mean rawScore ≥ `PERFECT_MIN_SCORE` 0.98 (TimingStrike
  at 60 fps, PrecisionTrace) and ≥ `PERFECT_HZ_MIN_SCORE` 0.95 (HoldZone), as §14.6 writes; and, because a mean cannot
  see the rare impossible pattern `SOLVABILITY_SEEDS` is sized to find (§16.32; one in 1,000 moves a mean by at most
  0.001; critic B 8), **every run** ≥ 0.98 for TimingStrike@60 and PrecisionTrace and ≥ `PERFECT_HZ_RUN_MIN_SCORE` 0.85
  for HoldZone (prototype, 2,000 runs per cell: TimingStrike@60 and PrecisionTrace every run 1.0000; HoldZone means
  0.966–0.987, lowest run 0.8969 at Iron/Hard; `out/final_table.txt`; slice 8 precomputes the pinned seeds); Idle
  scores 0 everywhere. `Bots.hzPerfect` precomputes the zone centre per tick once per pattern (the same values; the
  prototype recomputes them, about 10× slower).
- **T-MG-04 bands and fail rates** (L3): the 48 cells (family × tier × material × Elite/Good/Average/Poor), x =
  `BOT_REF_X`, HoldZone pump, offset 0, PrecisionTrace on `Edges.arming`; seeds `Bots.seedOf(i, configSalt("T-MG-04
  <family> <tier> <material> <profile>"))`, i = 1…`BOT_RUNS` (400). Per cell: |mean − E-S3.2's mean| ≤ 4 · sd / √400 +
  0.0005 (E-S3.2's sd; the 0.0005 covers its 3-decimal rounding; the band is the plan's reading, G16); no run flagged
  (E-S3.2: "Flag rate 0.00 % in every cell"). Q8 targets on `BOT_RUNS_FAIL` (1,000; the same seed list extended):
  Average fails (score < 0.5) in [3 %, 15 %] on Normal and [15 %, 40 %] on Hard; Good ≤ 5 % on Normal and ≤ 15 % on
  Hard. *Precomputed* (`t45`): worst cell mean at 0.67 of its band, smallest Q8 margin 2.3 points (HoldZone Iron/Normal
  Average 5.3 % against 3 %), no run flagged: pass.
- **T-MG-05 profile order and the Normal → Hard drop** (L3, from T-MG-04's runs, unpaired across tiers): per family ×
  tier × material, mean Elite > Good > Average > Poor; per family × material × profile, mean(Normal) − mean(Hard) ≥
  `TIER_MIN_MEAN_DROP` 0.05 for Average and > 0 for the others. *Precomputed*: Average drops 0.068 / 0.069 (HoldZone
  Iron / Steel), 0.098 / 0.088 (TimingStrike), 0.079 / 0.074 (PrecisionTrace); the smallest other drop PrecisionTrace
  Elite 0.0077 / 0.0052: pass.
- **T-MG-06 Iron − Steel** (L3): (a) deterministic: every Steel column is at least as tight as Iron's (`zoneWidth`,
  `beatMs`, `windowMs`, `halfWidth` × 0.98; `driftSpeed`, `pacerSpeed` × 1.01; `targetMin` × 1.08, `targetMax` × 1.04);
  (b) Average, Normal, per family, paired (Iron and Steel on one seed list, `configSalt("T-MG-06 <family>")`),
  `STEEL_DROP_RUNS[family]` runs each: mean(Iron) − mean(Steel) ∈ `STEEL_MEAN_DROP`. *Precomputed* (`t6`): HoldZone
  0.0153 (4,000 runs), **TimingStrike 0.0086** (20,000), PrecisionTrace 0.0130 (4,000); pooled with the shipped runs
  0.0155 ± 0.0010, **0.0089 ± 0.0010**, 0.0117 ± 0.0014. So at the SPEC's 0.01 floor T-MG-06 **fails TimingStrike**,
  not PrecisionTrace (§6.13 and §17.2's S3 row read the noisier 2,000-run table); at O4's default floor 0.005 all three
  pass, with margins 0.0103 / 0.0036 / 0.0080 ([9.1]).
- **T-MG-07 Params** (`Params.spec`): the product of modifiers, the clamp and the quantum on hand-worked rows (§6.5's
  example: Iron/Hard, Thinness x = 0.30 → `windowMs` 110 · 1 · 0.94 · 0.955 = 98.747 → 99); E-S3.3's resolved values
  at x = 0 and x = 1 for the four (material, tier) pairs (integers exact, others within half a unit of the printed
  digit, as the Definitions spec does); `explain`'s `final` = `resolve`; a missing material (Bronze) multiplies by 1; a
  missing factor reads 0; x below 0 or above 1 is clamped; `halfWidth` ≥ 0.0156 on every MVP config (§17.2 S3: "keep
  trace half-widths ≥ 0.0156"; the MVP minimum is 0.0344 at Steel/Hard x = 1); TimingStrike's core ≥ 9 ms on every
  tier × material × x ∈ {0, 0.1, …, 1} (T-MG-11's deterministic half); P-ORDER ([6.7]).
- **T-MG-08 garbage and planted buffers.** Decode-level (`Timeline.spec`, slice 6): `FUZZ_N_GARBAGE` values from
  `Gen.garbage` and structured buffers per family from `Cheats.garbageBuffers` (random bytes after a valid header;
  lengths 0 to cap + 16; valid scripted timelines with 1–3 random byte flips; truncations and extensions;
  `FUZZ_N_STRUCT_FAST` per family in the quick run, `FUZZ_N_GARBAGE` under `t.slow`): `decode` never throws and returns
  records or a reason in `InvalidReason`; one planted buffer per reason gives exactly that reason (`Cheats.malformed`):
  `NotBuffer` ("abc", nil, a table), `Short` (11 B), `Version` (byte 0 = 2), `Family` (another family's code),
  `TooMany` (n = MAX + 1; and D8's length past the cap), `Length`, `Duration`, `NotIncreasing` (Trace dt 0), `PastEnd`,
  `BadKind` (HoldZone kind 2), `NotAlternating` (two downs), `OutOfPanel` (uQ 49153; vQ 16385), `BadFlags` (2); first
  failure wins (a buffer with a Version and a Length fault reads `Version`); and one **hand-written byte golden per
  family** (header and three records as hex, for example E-S3.4's first presses), decoded to the expected records and
  re-encoded to the same bytes, which a layout error made alike in encode and decode cannot pass (critic B 13(c)).
  Judge-level (`Minigames.spec`, slice 7): the same buffers through `judge` never throw, give `Ok` or `Invalid` with a
  reason, an `Ok` result has a finite score and breakdown, and `HashMismatch` comes from an honest timeline of seed + 1
  (the Replay cheat). `decode(encode(r)) = r` for every bot timeline (`Bots.spec`, slice 8).
- **T-MG-09 live session = judge** (`Minigames.spec`, fast 30 per family; `Statistics.spec`, slow 1,000 per family;
  slice 8): (a) session level: for a bot timeline, a random sequence of pushes (in record order) and advances (TestRng
  frame steps 1–40 ms with hitches up to 120 ms) in which every `advance(h)` comes after the push of every record with
  t < h; `finish(live).score` = `judge(spec, pattern, encode(records)).rawScore`, bit for bit, and equals `replay`'s;
  (b) end to end through `Input`: bot physical actions fed to a Recorder at random frame clocks (offsets −120…+120 for
  TimingStrike), the host loop of [3.6] (push `since`, advance to `horizonMs`, and at the end push `since` once more
  before `finish`, with a record made after the last frame's push: for HoldZone a down the last scored tick reads), same
  equality; (c) a pinned negative case: TimingStrike with `timingOffsetMs` = +60, advancing to the raw frame time misses
  a press the replay judges (the reason for D4); E-S3.6's sizes reported (bytes min / mean / max per family).
- **T-MG-10 false and true positives** (L3, `FalsePositives.spec`): sizes and names in [6.4]. FP: TimingStrike
  `FP_RUNS_TS` (300,000) runs for each of Elite@240, Elite@60, Good@60 and Average@30 (E-S3.8's four devices; §14.8's
  "per human profile" read so, Poor not run: G17), each as a Normal and a Hard case of 150,000 (material cycled by run),
  0 flags; HoldZone `FP_RUNS` (20,000) pump runs over Elite@60, Elite@30, Good and Average@30 × Iron Normal/Hard, 0 flags
  and at most `HZ_RATE_MAX_PRESSES / 3` = 10 presses in any 1 s window (E-S3.8: ≤ 9); PrecisionTrace `FP_RUNS` on
  Elite@30 fps / 360 px (Iron, a Normal and a Hard half of 10,000), 0 flags, smallest mean deviation ≥ 3 ·
  `PT_PRECISE_MEAN_DEV` = 0.0024 u as §14.8 writes, with the 0.1 % quantile reported beside it, smallest mean jerk ≥ 3 ·
  `PT_SMOOTH_MEAN_JERK`. *Precomputed* (`ptmargin`): 0 flags; minimum 0.00279 u (×3.49) Normal and **0.00259 u (×3.24)
  Hard**; 0.1 % quantile 0.00303–0.00304 (×3.8); minimum jerk 0.00404: pass. ×3.24 is §17.2's S3 re-measure, handed to
  the lead (G19). Its other devices (Elite@240/520 px, Elite@60/520 px, Good@60/520 px) 1,000 runs each, 0 flags. TP
  (`TP_RUNS` 2,000 per cheat unless named): TimingStrike Exact → 100 % flagged `TsExactHits` and `TsLowVariance`;
  PrecisionTrace on the pacer every 20 ms → 100 % `PtTooPrecise` (the HIGH flag §10.6 relies on), with the `PtTooSmooth`
  rate reported, not asserted (no evidence shows it at 100 %; critic A 13); 200 ms-sparse → 100 % (`PtSparse`); HoldZone
  exact-state Perfect (100 runs) → 100 % `HzInhumanRate`; a 30/s autoclicker → flagged. Known limits pinned so a change
  is noticed (Q17): TimingStrike σ 4 ms synthetic → 0 % flagged, mean ≥ 0.99; a trace with 0.004 u white noise → 0 %
  flagged, mean ≥ 0.98.
- **T-MG-11 Perfect at 30 fps** (fast in `Bots.spec`, slow in `Statistics.spec`; slice 8): TimingStrike Perfect@30,
  every MVP tier × material × x ∈ {0, 1}: every run ≥ `PERFECT_30FPS_MIN_SCORE` 0.95 (fast: 50 seeds per cell; slow:
  `SOLVABILITY_SEEDS`). The margin is thin at x = 1: E-S3.4's worst run there is 0.9600 (Iron/Hard, raised from 0.9499
  by the 10 ms core floor), 0.010 over the bound and from fewer runs than the slow case's 8,000, so the slow minimum may
  land near 0.95 (critic A 9); slice 8 precomputes it, and a failure is a finding for the lead, never re-seeded. The
  full-points core ≥ 9 ms (deterministic, T-MG-07). §14.6's "at every tier" is read as the MVP tiers (§16.21's "every
  MVP tier"); the placeholder tiers are reported (G18).
- **T-MG-12 fairness** (L3): per family × tier (Iron, x = `BOT_REF_X`): `FAIRNESS_SEEDS` (100) pattern seeds ×
  `FAIRNESS_BOT_RUNS` (20) Average runs each, the bot seeds shared across patterns; the SD over pattern seeds of the
  per-pattern mean ≤ `FAIRNESS_MAX_SD` 0.08. This definition is the plan's ([9.2] G6). *Precomputed* (`fair`): highest
  0.051 (HoldZone Hard), TimingStrike 0.021–0.022, PrecisionTrace 0.014–0.025: pass (R9 retired).
- **T-MG-13 goldens** ([6.5]): (a) E-S3's values, hand-written; (b) `minigames.bv1.golden.txt`, blessed.
- **T-MG-14 HIGH clamp** (`Minigames.spec`): scripted (slice 7): TimingStrike Exact presses (judged errors all 0) →
  flags `{TsExactHits, TsLowVariance}` (sorted), rawScore 1.0, score 0.5, passed; judged presses all at the same
  0-point error (W + 1 ms) → `TsLowVariance`, rawScore 0, score 0, failed (the flag never fails a step: it failed by its
  raw score); a medium-only result (`PtSparse`) is not clamped; with Bots (slice 8): HoldZone's exact-state Perfect,
  clamped the same way; the client's `finish(session).score` equals the server's `rawScore` in every case
  (ScoreMismatch compares those two, §7.7).
- **T-MG-15 `timingOffsetMs`** (`Input.spec`): offsets {−120, −60, 0, +60, +120}: a press stamped t records
  `max(0, t − offset)`, presses in the first `offset` ms floor to 0; HoldZone and PrecisionTrace records are identical at
  every offset (the offset is TimingStrike's alone; critic B 13(f)); the **unquantized** Exact cheat (D7 clocks,
  `frameDtS = 0`) through the Recorder has every error = −offset, so `TsLowVariance` at every offset and `TsExactHits`
  only at |offset| ≤ 1: a shift moves every error alike (the 60 fps Perfect is never flagged, so it could not show a kept
  flag; critic A 7). With Bots (slice 8): Elite@240 and Good stay unflagged at every offset (fast: 100 runs each; slow:
  1,000). E-S3.2's calibrated offsets reported in the Recorder's terms: Average Iron/Normal 0.648 → about 0.717 at
  `timingOffsetMs` = **+35** (`dist.luau` subtracts `off` = round(renderLag + biasMean) from its stamps; its "cal(−35
  ms)" label is the card's "[Use −N ms offset]").
- **T-MG-16 releases always recorded** (`Input.spec`): HoldZone `go(true)` then `release()` → an up; `button(true)`,
  `release()`, `button(false)` → one up, not two; `release()` while up → nothing; after `release()` a held key counts
  only through a new `button(true)`; TimingStrike `release()` lets the next `button(true)` press; PrecisionTrace records
  nothing on `release()`; every resulting timeline decodes (alternation holds) and judges `Ok`.
- **Reference: prototype parity and full precision** (`Reference.spec`, `t.slow`, Lune only, slice 8):
  - Parity: `Bots.run` with the prototype's seeds (`salt` 1, i = 1…100) reproduces the first 100 scores of every one of
    the 48 cells of `docs/spec/prototypes/S3/v2/out/S3-score-distributions.luau` (required by relative path, as
    `tests/Physics/Reference.spec` requires S2's prototype) **exactly**. Scores only: records differ in ways that move
    no score ([3.11]), and the trace bot must keep the prototype's draw order ([3.11]). A mismatch is a porting bug until
    shown otherwise; the failure message names the machine's libm as the one cause outside the code (D14).
  - Full precision (D1; critic B 10): the prototype's `Params`, `HoldZone`, `TimingStrike` and `PrecisionTrace`,
    required by relative path, against the build at `%.17g`: resolved params for 3 families × 2 materials × 5 tiers ×
    x ∈ {0, 0.1, 0.3, 1}; pattern arrays (HoldZone keys; TimingStrike cycles; PrecisionTrace `pu`, `pv`, `arc`, `L`,
    `speed`) for seeds 1…20 per family and tier; and the unquantized session sums (HoldZone credit and n, TimingStrike
    Σ points, PrecisionTrace `accSum`, `paceSum` and covered count) on the parity runs' timelines, the prototype's
    session fed the same records.

### 6.4 L1 and L3: seeds, names, outcomes, false-failure rates, cost

Seeds: every statistical configuration seeds its pattern stream with `Bots.seedOf(i, salt)` and its bots with
`i · 7919 + salt · 31 + 17`, `salt = Dump.fnv1a32(<config name>)` (§14.8: "pass/fail per code version, never flaky").
A config that fails is never re-seeded; it is a finding. The names are pinned (D11):

| Config | Name (`salt = fnv1a32(name)`) | Outcome on the prototype |
|---|---|---|
| T-MG-03 | `"T-MG-03 <family> <tier> <material>"` | slice 8 precomputes (the per-run floors are new) |
| T-MG-04, 05 | `"T-MG-04 <family> <tier> <material> <profile>"` | *precomputed*: pass ([6.3]) |
| T-MG-06 | `"T-MG-06 <family>"` (Iron and Steel share it: paired) | *precomputed*: HoldZone 0.0153, TimingStrike 0.0086, PrecisionTrace 0.0130 |
| T-MG-09 slow | `"T-MG-09 <family>"` | exact equalities, no statistics |
| T-MG-10 TimingStrike | `"T-MG-10 TimingStrike <device> <tier>"`, device ∈ {Elite@240, Elite@60, Good@60, Average@30} | optional precompute in slice 8 (E-S3.8: 0 flags in 100,000 per device and tier) |
| T-MG-10 HoldZone | `"T-MG-10 HoldZone <device> <tier>"` | optional precompute in slice 8 (E-S3.8: at most 9 presses in 1 s) |
| T-MG-10 PrecisionTrace | `"T-MG-10 PrecisionTrace Elite@30/360 <tier>"`; `"T-MG-10 PrecisionTrace <device>"` for the 1,000-run devices | *precomputed* for the 30 fps device: 0 flags, ×3.49 / ×3.24 |
| T-MG-10 TP | `"T-MG-10 TP <family> <cheat>"` | 100 % by construction |
| T-MG-11 slow | `"T-MG-11 <tier> <material> x=<x>"` | slice 8 precomputes (E-S3.4's 0.9600 margin) |
| T-MG-12 | `"T-MG-12 <family> <tier>"` | *precomputed*: highest 0.051 |
| T-MG-15 slow | `"T-MG-15 <profile> <offset>"` | slice 8 precomputes |

**L1 (`--quick`, §14.1 "≤ 30 s").** The suite already takes 29.3–30.0 s quiet, so M4 gets an explicit share,
proposed **≤ 3 s quiet** for all of `--quick --filter "Minigames/"` (I4), and every fast case stays under
`CASE_BUDGET_MS` 2 s (critics A 1, B 1). Estimates from the prototype's per-call costs (generate ≈ 1 ms, replay and
checks ≈ 1.3 ms, a human trace bot ≈ 4 ms), *measured* per file at every slice check:

| Fast work | Estimate quiet | How it stays small |
|---|---|---|
| `Properties.spec` (PrecisionTrace and bot rows) | 3–6 s at `PROP_N` 200 | `PROP_N_FAST` 25 in the quick run, 200 under `t.slow`: ≈ 0.5 s |
| T-MG-08 structured buffers (byte-flipped trace timelines decode `Ok` and replay) | ≈ 2.6 s per family at 2,000 | `FUZZ_N_STRUCT_FAST` 200 in the quick run, 2,000 under `t.slow`: ≈ 0.3 s |
| T-MG-01 (36 configs × 4 seeds), golden (b), T-MG-02 scripted | ≈ 0.6 s | — |
| T-MG-09 fast, T-MG-11 fast, T-MG-15 fast, `Bots.spec` | ≈ 0.8 s | 30 / 50 / 100 runs |
| Rng, Params, Checks, Timeline, Input, the family goldens | ≈ 0.3 s | — |
| **M4 total** | **≈ 2–3 s** | a slice check that passes 3 s stops and re-sizes |

Every second over 30 s breaks L1, so the lead decides with I4: raise L1's gate (proposed 35 s), or move about 3 s of
existing fast cases to `t.slow`, which adds them to an L3 that is already over.

**L3 (`lune run tests/run`, §14.1 "≤ 10 min").** Per-run costs: prototype, Lune; TimingStrike's measured by critic B
at 42–69 % busy (`tscost`: Elite@240 0.512 ms, Elite@60 0.165, Good@60 0.157, Average@30 0.109), so an upper figure;
HoldZone pump ≈ 1 ms; PrecisionTrace ≈ 6.5 ms (§16.32). Odds are *predictive* (critic B, `l3_odds`): the chance that a
fresh fixed-seed draw fails an honest build, counting the 2,000-run estimate's own error. They matter at the next
re-draw (any BALANCE change): with the pinned names the outcomes are known now (D11).

| Assertion | Runs | Outcome with the pinned names | Odds of a false failure at a re-draw | Quiet Lune cost |
|---|---|---|---|---|
| T-MG-04 cell means within 4 SE | 400 per cell, 48 cells | pass (worst at 0.67 of its band) | 0.74 % in all (r1: 0.3 %) | PT 42 s, HZ 6 s, TS 1 s |
| T-MG-04 Q8 fail rates | `BOT_RUNS_FAIL` 1,000 (Average, Good) | pass (smallest margin 2.3 points) | 0.57 % in all (TimingStrike Steel/Normal Average 0.46 %) | + 37 s (24 cells × 600 more runs; r1: 16 s) |
| T-MG-05 order and drops | T-MG-04's (unpaired) | pass | 0.86 % (0.2 % if paired, [15]) | 0 |
| T-MG-06 Iron − Steel | TS 20,000, HZ 4,000, PT 4,000, paired | floor 0.01: **fails TimingStrike**; floor 0.005: pass | at 0.005: PT 9.6 % on the 2,000-run estimate (less on the pooled 0.0117), TS 1.2 % | 65–90 s |
| T-MG-03 solvability | 1,000 per cell, 12 cells | means: E-S3.2's margins; per-run floors: slice 8 | ≈ 0 for the means | 18 s |
| T-MG-10 FP | TS 4 devices × 2 tiers × 150,000; HZ 20,000; PT 2 × 10,000 + 3 × 1,000 | PT pass (×3.24); TS and HZ: E-S3.8's 0 flags | the trace minimum: 1–10 % per half (tail fits); its 0.1 % quantile ≈ 0 | **TS 283 s** (r1: 144 s), PT 150 s, HZ 20 s |
| T-MG-10 TP | 2,000 / 200 / 100 | 100 % flagged | 0 | 5 s |
| T-MG-12 fairness | 6 × 100 × 20 | pass (highest 0.051 against 0.08) | small | 31–40 s |
| T-MG-09, 11, 15 slow; Reference | 3 × 1,000; 8 × 1,000; 10 × 1,000; 48 × 100 and the side-by-side | exact, or E-S3.4's margin (T-MG-11) | T-MG-11: the 0.9600 margin | 10 s, 1 s, 3 s, 15 s |
| T-RNG χ² | ≈ 40 × 160,000 draws | pass (highest 30.87) | 0 for an exact port | ≈ 10 s |
| T-PERF-02 | 15 rounds | about 2× under budget at the decode cap ([6.8]) | load-dependent | ≈ 5 s |

**Total M4 L3 ≈ 11–13 minutes** (r1 said 9: TimingStrike's FP runs cost about twice r1's E-S8.7 figure, the Q8
extension twice r1's, and the build adds the Recorder, `prepare`, `checks` and `Checks.sorted` to every run; critic B
2). With the existing `t.slow` cases (about 5 minutes), `lune run tests/run` takes **about 16–18 minutes quiet**, more
at this machine's usual 40–60 % load, against §14.1's 10 ([9.2] I4, [10] R1). Every case stays well under
`SLOW_CASE_BUDGET_MS` 300 s: the largest are the Elite@240 TimingStrike halves (≈ 77 s each at the busy cost) and the
PrecisionTrace FP halves (≈ 75 s each). Slice 8 measures the build's per-run costs through the Recorder before slice 9
fixes the sizes.

### 6.5 Goldens

- **(a) Hand-written, from the evidence** (fast; in the family specs):
  - TimingStrike (E-S3.4, `out/golden.txt`): seed 1, Iron/Normal, x = 0: N 12, W 110, core 13.2, M 200, durationMs
    10971, hash 0xE2D4F2AE; targets 489, 1479, 2354, 3031 (periods 847, 896, 871, 878); errors 0, +6, −15, +35, +79,
    none, −81, then 5 exact → points 1, 1, 0.9851, 0.8198, 0.4562, 0, 0.4397, 1 × 5 (4 decimals), score 0.8084,
    meanErrMs 2.18 (2 decimals). Grade bands (ms): Iron/Normal x = 0: Perfect ≤ 25.3, Good ≤ 61.6 (W 110); x = 1: 21.6 /
    52.6 (W 94, core 11.3, M 184); Iron/Hard x = 0: 20.3 / 51.3 (W 103, core 10, M 193); x = 1: 18.7 / 44.7 (W 88);
    Steel/Hard x = 0: 20.1 / 50.4 (W 101); x = 1: 18.4 / 43.8 (W 86).
  - HoldZone (E-S3.7): seed 1, Iron/Normal, x = 0: 10 keys, first (0, 0.6323) (3000, 0.6323) (5060, 0.4000) (7180,
    0.6523) (9060, 0.4000), hash 0x4E2677F2; scripted taps every 300 ms (80 ms presses) score 0.0000; the stroke
    curves (flat 60 s pattern at 0.5, full strokes, 50 ms presses, mean T over ticks 4000–5999): every 1000 / 600 / 400
    / 300 / 250 / 200 / 150 / 100 ms → 0.335 / 0.516 / 0.702 / 0.854 / 0.958 / 0.944 / 0.930 / 0.916; from cold at the
    refill rate T(1 s) 0.490, T(2 s) 0.774, T(3 s) 0.885; one stroke from rest peaks at 0.166 at 750 ms; one press held from GO to the end scores 0 (§6.8's
    "holding alone scores 0"; critic A 17).
  - PrecisionTrace (E-S3.5): `Edges.arming`, seed 1, Iron/Normal, x = 0: sides 2 (A 3 points, B 4 points); source
    (10912, 10158) (34996, 10158) (38240, 8389) (38142, 7799) (34996, 6226) (10912, 6226) exactly; path 337 points,
    L 3.3526, travel 11180 ms, duration 12180 ms, speed 0.2999, hash 0xF0B5CD03; fallback 402 points, L 4.0083,
    travel 13380 ms, hash 0x405C00EA; the grip tilted 30° (`Edges.tilted`) gives the identical source. E-S3.5's blade
    table (sides, source points, E, Douglas–Peucker tolerance, path points, L, travel Normal / Hard) for all nine edges
    as `cost.luau` computes them (x = 0.10 / 0.30; path points and L for seed 20), e.g. saw: 139-point chain → 5-point
    source, E 1.00, tolerance 0.128; zigzag: 2-point source, E 1.00, tolerance 0.512, 209 path points, L 2.073.
  - E-S3.3's resolved parameters (T-MG-07).
  - One hand-written byte golden per family (`Timeline.spec`, [6.3] T-MG-08).
- **(b) Blessed** `tests/golden/minigames.bv1.golden.txt` (`Golden.check("minigames.bv1", …)` in `Minigames.spec`):
  for every config × seeds {1, 2, 0xDEADBEEF, 2^32 − 1}: `{durationMs, patternHash}` plus the family's shape
  (HoldZone key count; TimingStrike N, M, W, core; PrecisionTrace path points, L, travelMs, usedFallback); and the full
  `MinigameResult` of fixed timelines per family and tier: the scripted ones above and the 24 frozen bot timelines of
  `tests/fixtures/MinigameTimelines.luau` (one per profile, D14), so the golden pins authoritative code only, never the
  machine's libm. Hashes and summaries only, no paths, so the file stays small (tens of KB). It is the "outcome golden"
  of §14.9: an outcome-changing code edit shows as a diff. Blessed once, in slice 8, when every row exists:
  `-- --bless --filter "Minigames/Minigames"` (a new file; nothing else is blessed while the other team's goldens sit in
  the tree).
- Studio reads no M4 golden; M5 decides whether S-PAR-02's minigame lines need a digest ([7]).

### 6.6 `tests/lib/Cheats.luau` (§14.2, §14.3, §14.8, E-S8.5)

Requires nothing in `src/` (§1.3 L1; §14.2 "specs pass modules in"): `Cheats.new({ Minigames = …, Bots = …,
MinigameFamilies = … })` returns the builders, using `TestRng` for randomness. `Bots` is optional (slice 6 builds the
decode-level cheats before `Bots` exists) and `exact` errors without it (critic A 12).

| Builder | Produces | Used by |
|---|---|---|
| `exact(spec, pattern)` | `Bots.play(spec, pattern, "Exact", 0)`: TimingStrike presses at the exact targets, unquantized (D7 clocks, `frameDtS = 0`); a trace on the pacer every 20 ms; HoldZone's exact-state controller | T-MG-10 TP, T-MG-14, T-MG-15, M7's S-E2E-10 ("Exact passes at the pass line, flagged") |
| `fast(spec, records, earlyTolMs)` | an honest buffer plus `sendAtMs` = countdownMs + durationMs − earlyTolMs − 1 (`EARLY_TOL_MS` is S5's and not in Definitions yet, so the caller passes it) | M7 (S-E2E-10 `E_TOO_EARLY`); M4 checks only that the buffer judges `Ok` |
| `flood(spec)` | MAX_RECORDS + 1 records (`TooMany`), and a buffer longer than `capBytes` (D8) | T-MG-08, M7 |
| `malformed(spec, reason)` | one buffer per decode reason | T-MG-08, M7 (`Length` in S-E2E-10) |
| `replay(spec, records, otherSpec)` | the same timeline twice (judged alike: S5 answers `duplicate`), and an old timeline on a new seed (`HashMismatch`) | T-MG-08, M7 |
| `forged(args)` | Submit args with an extra key or another session id | M7's Guard (`E_BAD_REQUEST`, `E_SESSION_MISMATCH`); M4 checks the shape only |
| `garbageBuffers(rng, family, n)` | structured garbage ([6.3] T-MG-08) | T-MG-08 |

### 6.7 Generic properties (§14.5), every public pure function

`Properties.spec.luau` runs `Prop.check(PROP_N, …)` per row under `t.slow`, and `Prop.check(PROP_N_FAST, …)` in
the quick run for the rows that generate or replay PrecisionTrace patterns or run bots (M4's L1 share, [6.4]);
`FUZZ_N_GARBAGE` for P-TOTAL (`FUZZ_N_STRUCT_FAST` structured buffers per family in the quick run).

| Function(s) | P-DET | P-NOMUT | P-TOTAL | P-FINITE | P-RANGE | P-ORDER |
|---|---|---|---|---|---|---|
| `Rng` methods, `mul32`, `fnv1a32`, `fmix32`, `hashU32` | streams | — | (bad seeds error by design: server-made) | yes | `nextFloat` ∈ [0, 1), `int` ∈ [lo, hi], `range` ∈ [lo, hi) | — |
| `Params.resolve`, `explain`, `resolveDef`, `refFactors` | yes | factors, rows | — | yes | — | rows' params shuffled, factor arrays shuffled, material maps rebuilt in another order: bit-identical |
| `Timeline.decode` / `encode` | yes | the buffer / records | decode: any value | — | records within [0, durationMs], panel bounds | — |
| `Checks.*` | yes | inputs | — | yes | — | `checks` and `flagLevels` arrays shuffled |
| family `generate`, `hash` | yes | params, source | — | keys, cycles, path | HoldZone centres ∈ [targetMin, targetMax]; path ∈ [0.05, 2.95] × [0.05, 0.95]; durations quantized | — |
| family `newSession`, `push`, `advance`, `view`, `finish`, `checks` | yes | pattern, records | — | views, breakdown | score, rawScore, `inZone`, `accuracy`, `pacing`, `coverage`, `marker` ∈ [0, 1]; flags ⊂ the family's FlagIds | — |
| `sidesFromChains`, `edgeToPanel` | yes | chains | degenerate chains (none, one point, flat, a zero-length chain) → `{}` / nil, no error | yes | source u ∈ [0, 49152], v ∈ [0, 16384] | — |
| `Minigames.prepare`, `start`, `replay`, `encode` | yes | input, spec, pattern | — | yes | as above | — |
| `Minigames.judge` | yes | spec, pattern, buffer | any timeline | yes | as above | — |
| `Input` Recorder | same calls → same records | — | — | — | times within [0, durationMs]; u, v in the panel; caps held | — |
| `Bots.play`, `run` | same seed → same records and scores | — | — | yes | — | — |

Two more: a `view` called any number of times at any times never changes `finish`'s result (views are read-only); and
P-PURE: a case requires every Minigames module under Lune (T-META-02 already proves no Roblox API).

### 6.8 T-PERF-02 (`tests/Minigames/Perf.spec.luau`, `t.slow`; §14.11)

Method: T-PERF-01's (a warm-up per case, `PERF_RUNS` 15 rounds, odd forward and even backward, a full collection
before each timed run, the medians count). §14.11 times "the longest **legal** timeline per family": legal is what
decode accepts, and Submit judges whatever a modified client sends, so the asserted cases are the decode caps and the
honest maxima are reported beside them (critics A 2, B 7). Cases and budgets:

- `Minigames.judge` (decode + replay + checks) at the decode cap, ≤ `REPLAY_BUDGET_MS` 8: HoldZone at Steel/Hard
  x = 1 (18 s) with 1,024 alternating records (512 down/up pairs: the cap, which an honest client can also reach, since
  a press is still allowed at 1,022 records; prototype `cost2.luau`: 1,000 records 0.35 ms); TimingStrike at Steel/Hard
  x = 1 with 512 presses (the cap; prototype 0.04 ms for 309); PrecisionTrace on a 256-point source at the length bound
  at the slowest pacer (Iron/Normal x = 0: `maxLen` = 0.95 · 30 · 0.30 = 8.55 u; a triangle or sine wave across the
  panel whose length just fits, as `worst.luau` builds it: about 860 path points, travel ≈ 28.5 s) with **2,048
  grinding samples about 14 ms apart near the pacer** (the cap). Reported beside it: the honest maximum, one sample per
  20 ms (≈ 1,476 records on that pattern; 1,551 at 31 s). *Measured* by critic B on the prototype at 59–68 % busy
  (`worstcap`): honest 3.31 ms, cap 3.68 ms (×1.11); quiet, the prototype's honest case is 2.59 ms (E-S3.5).
- PrecisionTrace generate (`Minigames.prepare` for Sharpening) on X08 ≤ `PT_GENERATE_BUDGET_MS` 5: the edges of P2
  (X08a), P1 (X08b), P5 (X08c) from `Analyze.run(Cost.core(Cost.X08.X08a))` and so on (the analysis outside the timed
  part; after the Physics fix commits), `Cost.X08_EDGE` (the zigzag; prototype 0.35 ms), and the length-bound source
  above (prototype 2.53 ms), each at Iron/Normal x = 0 and Steel/Hard x = 1.
- Reported, not asserted: HoldZone and TimingStrike generate (0.04 / 0.03 ms), decode alone of 2,048 trace records, and
  every median × 2.6 against §10.5's "each ≤ 7 ms in Studio". The decode-cap trace projects to about 2.59 × 1.11 × 2.6
  ≈ **7.5 ms in Studio, over 7** (the honest case ≈ 6.7): R7 is likely, not borderline. M4-notes hand both projections
  to M7's S-PERF-01 and §17.2's S5 row (a checkpointed `judge` in the AnalysisQueue), with I8 (the SPEC's two
  thresholds) and the option of a decode cap on trace records ([10] R7).
- Busy machine: the 8 ms budget keeps about 2× margin at the cap even at 59–68 % busy (3.68 ms), so the medians survive
  ordinary load. Run it alone, `lune run tests/run -- --filter "Minigames/Perf"`, and record the machine's CPU load
  beside the numbers; a failure under load is re-run alone before it counts (§14.11's rule for T-PERF-01). While the
  other team's measurements run, do not take T-PERF-02 figures for the notes.

### 6.9 The M1–M3 notes' M4 items

- M1-notes B2, "PtTooSmooth's 'both dt 10–40 ms' bounds … no §16 constant": D3, T-DEF-05 extended, and
  `PrecisionTrace.spec` cases at dt 9, 10, 40 and 41 ms (only 10 and 40 count).
- M1-notes B2, "The tests hard-code … PT_TRAVEL_MAX_MS 30000 … and TS_PERFECT_CORE_MIN_MS 10": [5.2].
- M1-notes B2 on MinigameFamilies' shape (catalog views at top level plus the wire constants; checks with §16.12's
  UPPER_SNAKE names; the `term()` constructor because luau-lsp widens literals): M4 reads it as it is; the same
  widening hits FlagId and InvalidReason literals ([3.1]).
- M2-notes: "M4 Minigames — No item from M2."
- M3-notes hold no M4 item (r1 misattributed this one, critic A 16): E-S8.6 says S-PAR-02 gains "50 judged bot runs
  per family" at M5; M4 makes that possible by keeping `Bots`, `Input` and the facade pure and seeded, and recommends
  judging Lune-made timelines there (D14, [7]). M2-notes' precedent: M2's `Reference.spec` already relies on Lune's
  libm matching its literals.

---

## 7. Studio

- **M4 owns no §14.10 scenario.** §18's M4 row names only Lune tests ("T-RNG, T-MG with L3, T-PERF-02"); §14.10's
  list (S-E2E-01…13, S-PAR-01…04, S-VIS-01…09) has no M4 entry; the M2 and M3 notes hand M4 none. §18's "its Studio
  scenarios passing in 3 fresh Play sessions" is empty for M4, so the M4 exit needs no Studio session.
- **Where Lune = Studio parity of the replay is checked**:
  - **S-PAR-02 at M5**: §14.10 "M5 adds `Pipeline.analyze`, judged bot runs and T-CR-08's outcomes"; E-S8.6 "M5: of
    `Pipeline.analyze`, 50 judged bot runs per family and T-CR-08's outcomes too", in the Server and the Client data
    models against `parity.bv<N>.digest`. Run as M3 ran it: `rojo serve test.project.json --port 34873` into the test
    place (Project 215), a Play session, `execute_luau` with the text of `tests/studio/e2e/S-PAR-02.luau` in
    datamodel_type "Server", then "Client", reading the `[E2E]` lines; three fresh Play sessions, console clean.
  - **S-E2E-05 at M7**: per step `Minigames.start(spec)` → S3's Good bot → `Craft.Submit`; "server score = snippet
    `judge` (bit-identical), clientScore = rawScore".
  - **S-E2E-12 at M8** (real input, client = server) and **S-PAR-04 at M9** ("one craft per family with clientScore =
    rawScore" on live servers).
- **What M4 does for them**: `Minigames`, `Input` and `Bots` are pure and seeded (no clock), so they load from
  `ReplicatedStorage.Blacksmith` in both data models; results are plain tables `Dump.canonical` can print. The natural
  M5 digest line judges a frozen timeline (D14): `name, a tab, Dump.canonical(Minigames.judge(spec, pattern,
  buffer, 0))`, with `buffer` from `MinigameTimelines`; a line from a live `Bots.play` in Studio is reported only.
- **Risk for M5** ([10] R6): `Bots` uses libm (Box–Muller, the OU process), and Lune and Studio are separate programs:
  `lune.exe` takes `log`, `cos` and `exp` from the system UCRT (`api-ms-win-crt-math-l1-1-0.dll`), Studio's libm is
  unverified, and the UCRT itself can change with Windows updates or take a CPU-specific (FMA) path. A bot run's
  timeline can therefore differ between them where the judge cannot (it uses no libm). Recommended for M5 (its
  decision): S-PAR-02's minigame lines judge timelines made in Lune and shipped as a fixture (`MinigameTimelines`, D14)
  as the primary design, with live bot runs only reported. (r1's "the same Windows process" reasoning was wrong; critics
  A 16, B 9.)
- **V-08** (§17.2's S8 row: "releases while the Esc menu is open reach the game and `MenuOpened` fires on Esc (S3, S6)")
  is M8's to verify, in S-E2E-12 ("Esc during HoldZone then release recorded"). The Recorder needs no change if it fails:
  §6.6's per-frame rule ("a press with neither `IsKeyDown(Space)` nor `IsMouseButtonPressed(MouseButton1)` records its
  release") makes InputCapture call `button(false)`. M4-notes carry the item (critic A 11).
- Optional, not part of M4's exit: a short snippet in a Play session that prints T-RNG-01's vectors and T-MG-13's
  E-S3 hashes would catch an engine difference in `bit32` or float rounding at M4 instead of M5 (about 10 minutes of the
  lead's Studio time). This plan touched no Studio session.

---

## 8. The seams

### 8.1 What M4 takes from M3

| From | Field | M4 use |
|---|---|---|
| `Analyze.run(core)` | `steps[i].step` (StepId) | `Steps.get(step).family` → `PrepareInput.family` |
| | `steps[i].tier` (TierId, the played tier: Normal or Hard) | `m_tier` column (`Tiers.get(tier).order`) |
| | `steps[i].material` (MaterialId, the governing material) | `m_material` column |
| | `steps[i].factors` (8 `FactorValue` {factor, raw, x}, FactorId order, x ∈ [0, 1], on the step's work set) | `m_design` (x only) |
| | `edge.chains` (`EdgeChain`s, the main chain first: `points` {x, y} in blueprint XY studs, `length`) | `sidesFromChains` (Sharpening only) |
| | `edge.gripPoint` (Vec3), `edge.gripAxis` (Vec2, always {0, 1}: the difficulty frame) | `sidesFromChains`, `edgeToPanel` |
| | `balanceVersion` | `StepSpec.balanceVersion` |

Not used: `g`, `m`, `d`, `tierRaw`, `terms`, the physics report, `edge.length`, `cell`, `bladeArea`,
`bladeMeanThickness`. Difficulty tightens a minigame only through the design `x` columns and the tier (Q11); `tierRaw`
above Hard plays as Hard in the MVP. The in-flight Physics fix changes none of these types; it can move factor values
and edges on some designs, which no M4 golden reads (D6).

### 8.2 What M5 (crafting) calls

- `Pipeline.stepInput(report, i, seed)` returns `{ family = Steps.get(steps[i].step).family, seed, material =
  steps[i].material, tier = steps[i].tier, factors = steps[i].factors, edge = (PrecisionTrace) and { chains =
  edge.chains, gripPoint = edge.gripPoint, gripAxis = edge.gripAxis } or nil, balanceVersion }`: the narrow `edge`
  table, not the `EdgeProfile` itself ([9.2] G13). `MinigamesHelpers.stepInputFrom` is the reference T-PIPE can compare.
- `Crafting.StepRun` from a `MinigameResult`: `score`, `passed`, `flags`; `seed` = `spec.seed`; `durationMs` =
  `spec.durationMs`; `timedOut` is S5's.
- T-CR-09 composes 2,000 crafts per row "from the same distributions": `Bots.run` per cell, or the shipped
  `S3-score-distributions.luau` that `Reference.spec` ties to the build.
- S-PAR-02's minigame lines ([7]): judging Lune-made timelines (D14) is the recommended primary design.

### 8.3 What M7 (server, anti-cheat) calls

- StartStep's AnalysisQueue P0 job: `Minigames.prepare(Pipeline.stepInput(report, i, seed))`, `(spec, pattern)` kept
  in the session; seeds from `SeedRng:NextInteger(0, 4294967295)` (valid `Rng.new` seeds); `Config.FIXED_SEED` in
  Studio. `StepOpenView = StepSpec & {sessionId, stepIndex, stepId, tier, lateAllowanceMs}`; a re-open replaces only
  `countdownMs`.
- Submit: Guard `G.buffer(MAX_TIMELINE_BYTES)` (exists in MinigameFamilies); the family cap (`Timeline.capBytes`, which
  `judge` also enforces, D8); the wall-clock rules (§7.8) first; then `Minigames.judge(spec, pattern, timeline, E)`
  synchronously. `status = "Invalid"` → abort `InvalidInput`, Hard strike; `Ok` → the run; `clientScore ≠ rawScore` →
  `ScoreMismatch`; HIGH flags already applied. `StepScored` reads `score`, `rawScore`, `status`, `invalidReason`,
  `flags`, `breakdown`, `elapsedMs` from the result and `durationMs` from the spec.
- `Session/SessionMachine` is pure with `judge` injected: `submit(s, judge, index, recvMs, timeline, clientScore)`.
- Flags: the 7 FlagIds are M4's; `LateSubmit` and `ScoreMismatch` are S5's; `Items/Create.fromCraft` orders by
  `MinigameFamilies.flagLevels` and cuts at `MAX_STEP_FLAGS` (10 ≥ 9 kinds).
- Desync: the client's `start(spec)` returns `nil, "Desync"`; a re-open, then `ReportDesync {clientHash}` (the
  client pattern's hash); telemetry `Desync` with `serverHash = spec.patternHash`.
- S-PERF-01 times `judge` in Studio, at the decode cap as T-PERF-02 does (≈ 7.5 ms projected for the trace, [6.8],
  I8); §17.2's S5 row moves it into the AnalysisQueue with a checkpoint if it exceeds
  `REPLAY_BUDGET_MS` × 2.6. `replay`'s loop (push each record, then finish) can take a checkpoint between records
  without changing results; M4 does not build that variant.
- S-E2E-05 (`Bots.play` Good in the client data model, the `judge` snippet), S-E2E-10 (`Cheats`: Flood, Malformed,
  Replay, Fast, Forged, Exact), S-E2E-11 and T-PERF-03 (decode refuses oversize buffers in O(1), D8) use M4's code.

### 8.4 What M8 (client: InputCapture, views) calls

- On the StartStep reply: `pattern, err = Minigames.start(spec)` (the Desync flow of §12.1); `goClock = os.clock() +
  spec.countdownMs / 1000`; `rec = Input.new(spec, settings.timingOffsetMs, goClock)`; `rec:go(held, u, v, grind)` at
  the first frame at or after GO.
- Each frame (`BindToRenderStep("MinigameView", Camera + 1)`): InputCapture calls `rec:button`, `rec:cursor`,
  `rec:release`; the host pushes `rec:since(pushed)` through `Family.push`, calls `Family.advance(session,
  rec:horizonMs(os.clock(), dt))` (D4; §12.5 today says the raw frame time), routes the FeedbackEvents to §12.10's cues
  and VFX (`Go`, `Stroke` → Bellows, `Strike` by grade → StrikePerfect / StrikeGood / StrikeOk, `Miss`, `GrindStart` /
  `GrindStop` → GrindLoop, …), plays TimingStrike's `CycleStart` when `view.cycle` changes (raw clock, D12), and
  renders `Family.view(session, nowMs)` (the three view types of [3.1]; the trace trail from `view.credit` and the
  covered runs tinted from `view.coveredRuns`, G14).
- At GO + durationMs: push `rec:since(pushed)` once more ([3.6]; otherwise a last-frame record is in the timeline but
  not in the session), then `Minigames.encode(spec, rec:records())`, `clientScore = Family.finish(session).score`, then
  `Craft.Submit`.
- Intro: `Params.explain(family, material, tier, factors)` with the factors of the client's own `Pipeline` preview of
  the same record (bit-identical to the server's). StepResult: the breakdown keys of §6.14; the offset offer reads
  `breakdown.judged ≥ Minigames.TS_OFFSET_OFFER_MIN_JUDGED` (the facade's re-export) and `meanErrMs`. The trace canvas draws `pattern.pu`,
  `pattern.pv` and the band `2 · spec.params.halfWidth · H`.
- Test hook: `MinigameHost.setInputSource(Bots.autoplaySource(Bots.play(spec, pattern, profile, seed)))` behind the
  bridge's `autoplay {profile}`.
- Overview's "~duration" (§12.2 "durations S3's params"): HoldZone `durationMs` is a parameter; TimingStrike is about
  `strikes · beatMs + tailMs`; PrecisionTrace's comes from a `prepare` on the preview's step input. No new API.

### 8.5 Phase 2 (§15, §18's last line)

A new family is a Definitions row (params, checks, flagLevels, and its `FAMILY_CODE`, `RECORD_BYTES`, `MAX_RECORDS`),
a `FamilyModule`, a Timeline codec entry, an Input rule, a Bots policy and a registry row. Tier columns already have
five entries; a per-tier pass line is a tier column on `passThreshold` (§15.1); practice mode (O6) is `start` plus a
local session that never submits.

---

## 9. Designer calls, SPEC inconsistencies and gaps

### 9.1 Designer calls

Already decided by default in the SPEC and simply built by M4 (listed so nothing is re-opened silently): Q8 (pass line
0.50, fail bands; T-MG-04 checks them), Q11 (design factors tighten a minigame inside its tier), Q13 (Steel's tighter
columns), Q15 (tap to pump; 12 / 15 strikes on a dial with a timing offset; trace the blade's own edge, a generic edge
when it has none), Q16 (no pause; losing focus releases inputs: `Input`'s `release`), Q17 (a HIGH flag caps the score
at the pass line; medium flags are telemetry; careful cheaters are accepted), O6 (no practice mode).

Needed before M4's L3 can be green:

- **O4: how much tighter Steel plays.** §17.1: "Does 'Steel plays slightly tighter' mean an average player scores 1–8
  points lower (of 100 %) on Normal steps in Steel than in Iron? | 1–8 points, `STEEL_MEAN_DROP` [0.01, 0.08]
  (PrecisionTrace measures 0.009, see §17.2 S3)". On the larger sample (critic B: T-MG-06 as pinned, 4,000 / 20,000 /
  4,000 paired runs, pooled with the shipped 2,000) the drops are HoldZone 0.0155 ± 0.0010, **TimingStrike (hammering)
  0.0089 ± 0.0010** and PrecisionTrace 0.0117 ± 0.0014: it is hammering, not sharpening, whose Steel plays less than one
  point harder for an average player, and T-MG-06 at the 0.01 floor fails TimingStrike (0.0086 on the pinned seeds).
  **Default the build applies: a floor of 0.005 (half a point) for every family, the data unchanged**
  **[Decision to confirm]** (§17.1 O4). On the pinned seeds all three pass it (margins 0.0103 / 0.0036 / 0.0080). Cost:
  none in balance (a test bound; no Manifest change; S4's rarity tables stand); "slightly tighter" then means 0.5–8
  points, and Steel hammering stays about 0.9 points harder for an average player. Alternative: retune TimingStrike's
  Steel column (for example `windowMs` × 0.98 → × 0.97) until its drop clears 0.01: a fingerprint change, new
  distributions, a re-check of S4's Steel rarity rows (E-S4.7) and a new precompute of T-MG-04 to 06. Either way §6.13's
  sentence and §17.2's S3 row are corrected ([12]).

New calls (the lead numbers them; the build applies the default meanwhile):

- **New O "A": the TimingStrike combo.** The SPEC shows a combo ("combo ×5", §12.7; `bestCombo` in the breakdown,
  §6.9; "combo is feedback only", §0.5) with no rule. **Default: +1 for each span decided with points above 0
  (Perfect, Good or Ok); a span decided with 0 points (a miss, or a press past the window) resets it; stray presses do
  not count** **[Decision to confirm]** (new O). Cost: none (feedback only, never stored, no score effect).
  Alternative: only Good or better keeps a combo (harder to hold).
- **New O "B": the live score shown while playing.** §12.2's Playing screen shows a "live score"; the views carry
  `runningScore` without a definition. **Default: the mean so far (HoldZone: credit over the scored ticks so far;
  TimingStrike: points over the spans decided so far; PrecisionTrace: accuracy so far with the coverage of the arc
  already passed), so the number says how well the player is doing now** **[Decision to confirm]** (new O). Cost: none
  (display only; the server's result replaces it). Alternative: points earned so far over the whole step, a bar that
  fills from 0 to the final score.

### 9.2 SPEC inconsistencies (I) and gaps (G), with the build's answer

- **I1 T-RNG-01's vectors.** E-S8.5: "**T-RNG** 01 vectors from `kat/` (`studies/kat_xorshift32.py`)"; but §6.3:
  "xoshiro128\*\* 1.1 … Vectors: E-S3.1", and E-S3.1 is "cross-checked bit for bit against the Python reference
  `rng_ref.py`". The kat file is S8's xorshift32 stand-in (`prototypes/S8/repo/src/shared/Minigames/Rng.luau`:
  "PROTOTYPE stand-in for S3's Minigames/Rng"). Build: E-S3.1's vectors ([6.2]). Fix E-S8.5.
- **I2 T-MG-13 is undefined.** E-S8.5: "11, 13, 14 as §14.6", but §14.6 defines only "**T-MG-11** …" and
  "**T-MG-14** …"; E-S8.9 implies goldens ("Rng vectors, codec, live = replay, goldens (S3) | T-RNG, T-MG-09/13").
  Build: [6.5]. Proposed §14.6 text: "T-MG-13 the S3 goldens: E-S3.3–E-S3.5 and E-S3.7's patterns, hashes and scores, and
  `minigames.bv<N>.golden.txt`".
- **I3 T-MG-06 cannot pass as specified.** §14.6: "Iron − Steel mean in STEEL_MEAN_DROP (Q13)"; §16.32:
  "`STEEL_MEAN_DROP` | [0.01, 0.08] | … Average on Normal (Q13)"; §17.2: "PrecisionTrace's Average Iron − Steel drop on
  Normal is 0.009 (§6.13: 0.633 → 0.624), below `STEEL_MEAN_DROP`'s 0.01 floor". On the larger sample the family under
  the floor is TimingStrike (0.0089 ± 0.0010 pooled; PrecisionTrace 0.0117 ± 0.0014; [9.1] O4; critic B 3). `BOT_RUNS`
  400 cannot resolve it either: the paired difference's SD is 0.08–0.14, so its SE at 400 runs is 0.004–0.007 against
  margins of 0.002–0.006. Build: O4's default and D10's `STEEL_DROP_RUNS`; SPEC edits to §6.13 and §17.2's S3 row.
- **I4 Both test-time gates.** §14.1: L1 "≤ 30 s" (already 29.3–30.0 s) and L3 "≤ 10 min"; E-S8.7: "L3 total: … ≈ 7
  min, inside 10 min" counts M4's cases alone, at S8's stand-in bot costs, while M2's and M3's slow cases already take
  about 5 minutes. With M4: L1 about 33 s quiet and L3 about 16–18 minutes quiet ([6.4]; critics A 1, B 1, B 2).
  Proposed (S8, the lead): L1's gate 35 s with M4's share ≤ 3 s, and L3's gate 20 minutes. Alternatives: keep 30 s and
  move about 3 s of existing fast cases to `t.slow`; keep L3 at 10 minutes for the per-change run and run the volume
  cases (T-MG-10's `FP_RUNS_TS` and `FP_RUNS`, T-MG-03, T-MG-12: about 9 minutes) only at milestone exit and before a
  playtest, through a runner flag (an S8 change to `tests/run.luau` and §14.1's layers). Decided in slice 0: slice 11
  cannot pass without it.
- **I5 Evidence lines that no longer match.** `out/golden.txt`'s `HoldZone.driftSpeed: IN 0.21|0.2625` (before the
  Volume term went from +0.25 to +0.15; E-S3.3's 0.2415 is right); `out/det.txt`'s HoldZone bytes 198 / 295 / 408 against
  E-S3.6's 198 / 293 / 396; v2 `Bots.luau`'s comment "an 800 ms look-ahead" against its code (30 ticks = 300 ms, §16.23's
  `BOT_HZ_PERFECT_LOOKAHEAD_MS` 300); §6.13 and the v2 README place the distributions file in `final/` ("copied to
  `final/`"), which does not exist (`out/load_final.luau` requires it). None moves a value M4 asserts.
- **I6 `%` in the Rng.** §6.3: "with `bit32` ops and integer `+ * %` below 2^53; u32 products via `mul32(a, b) = ((a >>
  16)·b % 65536·65536 + (a & 0xFFFF)·b) % 2^32`"; §6.4 rule 2: "Only `+ − × ÷`, `sqrt`, `floor/ceil/round`, `abs`,
  `min/max/clamp`". Build: §6.4's whitelist over §6.3 (`mod(x, m) = x − floor(x/m)·m`, [3.2]; the values are identical,
  since Luau's `%` is that expression and every operand is an integer below 2^53) and `Source.spec`'s whitelist, which
  bans `%` and `//` in the authoritative files ([3.0]; critics A 10, B 13(h)). SPEC edits: §6.3's formula written with
  `mod`, §6.4 and §14.4 naming the rule.
- **I7 The trace's first record.** §6.2: ":go(held, u?, v?, grind?) records the state at GO (t = 0)"; §12.5: "held state
  and cursor at GO at t = 0"; but §6.6's Trace row: "One record at the first frame at or after each due time 0, 20, 40 …
  ms, `t = floor((os.clock() − goClock)·1000)`", as the prototype stamps it (`floor(f₁)`). Build: t = 0 (§6.2 and §12.5);
  scores cannot differ (ticks start at `leadInMs + 20`), records can (critic A 4(b)). SPEC edit: §6.6's row "the first
  record at t = 0, then one at the first frame at or after each due time 20, 40 …".
- **I8 Two Studio thresholds for `judge`.** §10.5: `judge` "≤ 7 ms in Studio"; §17.2's S5 row moves it into the
  AnalysisQueue only "above `REPLAY_BUDGET_MS` × 2.6", that is 20.8 ms. The decode-cap trace projects to about 7.5 ms
  ([6.8]): over the first, far under the second. M7 needs one threshold; proposed: §10.5's 7 ms, applied to the
  decode-cap timeline, in both places. (The lead's, with S5 and S8; M4 only measures.)
- **G1 Live = replay with a timing offset.** §6.4 rule 7: "Live = replay because the client advances HoldZone only to
  its latest record time, TimingStrike closes a span only once `now > T_i + M`"; §6.6: "TimingStrike then subtracts
  `timingOffsetMs`"; §12.5: "`t = floor((os.clock() − goClock)·1000)` ms … the host calls `advance`". With a positive
  offset the records' times trail the frame clock by up to 120 ms, so a span can close live before an offset-shifted
  press arrives. Build: D4 (`horizonMs`, clamping), T-MG-09 (c).
- **G2 PtTooSmooth's dt bounds have no constant.** §10.6: "≥ 150 moving triplets (span > 0.002 u, both dt 10–40 ms)";
  §16.12 lists `PT_SMOOTH_MIN_TRIPLETS`, `PT_SMOOTH_MEAN_JERK`, `PT_SMOOTH_MIN_MOVE` only. Build: D3.
- **G3 No combo rule** (§6.9 "bestCombo", §12.7 "combo ×5"): new O "A".
- **G4 TimingStrike at GO.** §6.6: "a press held at GO records `{t = 0, down}` (one stroke)" is HoldZone's case;
  TimingStrike's is unstated. Build: D9 (no strike from a key held through GO; "Holding a key does not repeat", §6.9).
- **G5 The Recorder's API.** §6.2's `:release()` takes no clock, and there is no per-frame accessor for new records
  nor a time base for `advance`. Build: `release()` stamps at the latest known time (harmless: HoldZone scores read
  downs only), `since` and `horizonMs` (D4).
- **G6 T-MG-12 "fairness"** is only "per-seed SD ≤ FAIRNESS_MAX_SD" (§14.6), with no prototype figure. Build: [6.3]'s
  definition, which passes on the prototype (*precomputed*: highest 0.051 against 0.08).
- **G7 Views and FeedbackEvents** are named (fields, kinds) but not defined (§6.8–§6.10). Build: [3.7]–[3.9];
  presentation only, so M8 may adjust them without a BALANCE change.
- **G8 Bit-level grouping.** §6.8 writes "F −= F·10/fireDecayMs" and §6.10 "travelMs = clamp(ceil(L/pacerSpeed·50)·20,
  …)"; the prototype that produced E-S3's hashes and the shipped distributions computes `F − F·(10/fireDecayMs)` and
  `ceil(L/pacerSpeed·1000/20)·20`. Build: the prototype's grouping (D1); the SPEC's pseudo-code is read as the math.
- **G9 An oversize buffer's reason.** §10.3: "Submit also checks the step family's own cap 12 + MAX_RECORDS ·
  RECORD_BYTES before judging; over it is an S3 Invalid (`TooMany`)", while §6.7's order would read a long buffer with
  a small count as `Length`. Build: D8.
- **G10 FP_RUNS per what?** §14.8: "HoldZone and Trace `FP_RUNS` (Trace: `FP_RUNS` on the 30 fps / 360 px Elite device
  only, its other devices 1,000 runs as in E-S3.8)". Build: HoldZone 20,000 in all over four configurations; Trace as
  quoted.
- **G11 X08's zigzag edge** is named for M4's T-PERF-02 (§14.7; `tests/fixtures/Cost.luau`'s header) but not in the
  repo. Build: `Cost.X08_EDGE` from `Blades.zigzag`.
- **G12 The "kat" seed validation and "derived tags".** T-RNG-03 and 05 come from S8's stub (`Rng.isValidSeed`,
  `Rng.derive`); S3's Rng derives streams by tag, not by salt. Build: [6.2]'s reading (seed validation of `Rng.new`;
  1,000 tags collision-free).
- **G13 `PrepareInput.edge` and `EdgeProfile`.** §6.2 types `edge` as `{ chains, gripPoint, gripAxis }?`; §4.8 writes
  "edge = analysis.edge" (an `EdgeProfile`, with more fields); whether Luau's width subtyping accepts the wider table
  under `--!strict` is unconfirmed (§17.2's S1 row asks the same question of `StepRecord`). Build: M5 passes the narrow
  table ([8.2]); SPEC edit: §4.8 writes the narrow table.
- **G14 The trace view and §12.8.** §12.8: "trail of the last `TRACE_TRAIL_SAMPLES` 24 positions by accuracy credit
  (≥ 0.9, ≥ 0.6, > 0, 0) … coverage bar, pace arrow, covered runs tinted"; §6.10's view carries only `coverage` (a
  fraction) and `accuracySoFar` (a mean), so M8 would have to read session internals or re-score in UI code. Build:
  `credit` and `coveredRuns` in `PrecisionTraceView` ([3.9]; critic A 3); presentation only, no BALANCE change; SPEC
  edit to §6.10's view list.
- **G15 TimingStrike's cue latency.** §6.11: "Views come from `advance(now)` each RenderStepped (≤ 1 frame + 10 ms
  latency)"; with D4, TimingStrike's decisions (`Miss`, `lastGrade`, `combo`, `runningScore`) lag the raw clock by the
  frame and max(0, `timingOffsetMs`), up to 120 ms, which they must to equal the replay, and an `advance`-driven
  `CycleStart` would drift by the offset against the dial. Build: D12. SPEC edits: §6.9 (`CycleStart` from the view's
  `cycle`) and §6.11 (the TimingStrike latency).
- **G16 T-MG-04's band width.** §14.8 names "S3's per-(family × tier × material × profile) table … `BOT_RUNS` seeds per
  cell" but no tolerance. Build: |mean − E-S3.2's mean| ≤ 4 · sd / √400 + 0.0005 ([6.3]); SPEC edit to §14.6.
- **G17 FP "per human profile".** §14.8 and §16.32 run `FP_RUNS_TS` "per human profile"; E-S3.8 ran four device
  configurations (Elite@240, Elite@60, Good@60, Average@30), and Poor (σ 90 ms) is never run. Build: E-S3.8's four, each
  split by tier ([6.3]); adding Poor@30 would cost about 33 s more with no realistic chance of a 1.5 ms-SD flag. SPEC
  edit: §14.8 names the four.
- **G18 T-MG-11 "at every tier".** §14.6: "Perfect at 30 fps ≥ PERFECT_30FPS_MIN_SCORE at every tier"; §16.21: "every
  MVP tier". Build: the MVP tiers asserted, the placeholders reported.
- **G19 The trace margin statistic** (§17.2's S3 re-measure). §14.8 asserts the smallest mean deviation over `FP_RUNS`
  ≥ 3 × `PT_PRECISE_MEAN_DEV`, and the minimum of N runs keeps falling as N grows. On the pinned halves: ×3.49 Normal,
  **×3.24 Hard**; tail fits give a fresh pair of halves a 2–20 % chance to fall under ×3 with no run flagged; the 0.1 %
  quantile is stable at ×3.8 (critic B 4). §17.2 says "if it nears 3 ×, retune `PT_PRECISE_MEAN_DEV` (with S8)". Build
  default: keep §14.8's assertion (the pinned seeds pass) and report the quantile beside it. Proposed to the lead and
  S8: from the next re-draw on, assert the 0.1 % quantile ≥ 3× instead of the minimum, rather than retune the flag (a
  Manifest change that would loosen it slightly).

---

## 10. Risks

| # | Risk | Effect | Mitigation |
|---|---|---|---|
| R1 | Both time gates (I4): L1 about 33 s quiet against 30; L3 about 16–18 minutes quiet against 10, longer on this busy machine | the M4 gate misses §14.1 | M4's L1 share ≤ 3 s, measured at every slice ([6.4]); the build's per-run costs measured in slice 8 through the Recorder and every L3 case's time in slice 9; HoldZone Perfect with a per-tick centre table (≈ 10× faster); FP cases split by device and tier; the lead decides both gates in slice 0 |
| R2 | O4 undecided | T-MG-06 fails TimingStrike at 0.01 (precomputed) | decide in slice 0; meanwhile the default floor 0.005 (all three pass, precomputed) and the measured drops in the notes |
| R3 | A regrouped expression or a changed draw order | E-S3 hashes, goldens or parity differ (a regrouping rarely, a draw order at once) | D1's pins; T-MG-13 (a) first, then Reference's parity and full-precision checks; port line by line from v2 |
| R4 | Machine contention with the other team's measurements | flaky timings, slow L3, a `--bless` that rewrites their goldens | one Lune process at a time; filtered runs; T-PERF-02 and L3 in quiet windows agreed with the lead; bless only with `--filter` and check `git status tests/golden` |
| R5 | The Physics fix lands mid-M4 | merge friction; T-PERF-02's X08 edges move | M4 touches no Physics file and no Minigames module requires Physics (D5); D6 keeps goldens on fixture edges; the integration case and X08 wait for the fix's commit or run filtered |
| R6 | Bots' libm (the system UCRT in Lune; unverified in Studio; can change with Windows updates or the CPU's FMA path) | a bot-run line differs between Lune and Studio at M5, between two machines, or on this one after an update | golden (b) judges frozen timelines (D14); `Bots.spec`'s libm canary and frozen-timeline check name the cause; Reference's message names libm first; M5 judges Lune-made timelines ([7]) |
| R7 | `judge` in Studio ≈ 7.5 ms at the decode-cap trace (2.59 × 1.11 × 2.6), over §10.5's 7 ms; ≈ 6.7 for the honest case | a Submit handler over its budget for a hostile client | T-PERF-02 times the cap ([6.8]); D13 (no event tables in `replay`); M7's S-PERF-01 measures; §17.2's S5 fallback (a checkpointed `judge` in the AnalysisQueue); I8 picks the threshold. An option for the lead (a §6.7 change): decode refuses a trace of more than `floor(durationMs / PT_EVAL_MS) + 1` records as `TooMany`; an unmodified client never sends more (each record after the first is at or past the next 20 ms due time, §6.6 Caps), so the hostile case shrinks to the honest one |
| R8 | luau-lsp strictness on `FamilyModule<P, R, S, V>` and string-literal unions | slow type fixes | typed constructors (M1's `term()` lesson); the facade stores modules as `FamilyModule<any, any, any, any>` |
| R9 | (retired in r2) T-MG-12 fairness had no prior figure | — | *precomputed*: highest 0.051 against 0.08 (HoldZone carries real between-pattern spread, 0.045–0.050: a fairness observation, not a failure) |
| R10 | A flag in 1.2 million TimingStrike FP runs | the FP claim (< 1e-5 per step) is wrong for some profile | report it as a finding (threshold or bot), never re-seed |
| R11 | Exact prototype parity is stricter than needed | time spent on a harmless difference | parity is on scores only; the record-level differences are listed ([3.11]); if a benign cause is proven, record the matching count per cell and keep the bands |
| R12 | The trace anti-cheat margin is thin (×3.24 against ×3, G19) | a future re-draw fails T-MG-10 with no run flagged (2–20 %) | the pinned seeds pass; the quantile is reported; the lead and S8 choose the statistic (G19) before the next re-draw |
| R13 | T-MG-03's per-run floors are new and T-MG-11's margin at x = 1 is 0.010 | a fixed-seed L3 failure | slice 8 precomputes both on the prototype; a failure is a finding for the lead (an impossible pattern is what the floors look for) |

---

## 11. Order of work: slices a builder can verify one by one

Every check below is a single Lune process, filtered, from the repo root; "pass" means exit 0. Full `scripts/verify`
and unfiltered `tests/run` happen only in slice 11, in a window the lead clears. One commit for the milestone, at the
end (the lead's). Each slice ends with its tests green, `lune run tests/run -- --quick --filter "Minigames/"` timed
against M4's L1 share (≤ 3 s quiet; past it, stop and re-size), and a line in `docs/build/M4-notes.md`'s draft. r2's
order builds every module before the first test that needs it (critic B 6): the three families before `Timeline`
(which reads PrecisionTrace's panel constants), `Input` and the facade on scripted timelines, then `Bots` with every
bot-dependent case, so golden (b) is blessed once.

| Slice | Build | Tests | Check |
|---|---|---|---|
| 0 | Preconditions: the Physics fix committed (HEAD past `f7ac37d`), or the lead's go-ahead to work in M4's files only; the lead's answers (or "use the defaults") on O4, new O "A" and "B", I4 (both gates), D3, D4, D8, D10–D14, G19 and I8 | — | `git status` shows no M4 file; this plan's [1] and [9] acknowledged |
| 1 | `Types` (D5: no Physics require), `Rng` | `Rng.spec` (T-RNG-01…06), `Source.spec`, Rng's rows of `Properties.spec` | `lune run tests/run -- --quick --filter "Minigames/Rng"`, then without `--quick` (the χ² cases, each value as [6.2] precomputes); types: §14.4's two `rojo sourcemap` lines and two `luau-lsp analyze` passes (what `scripts/verify`'s stages 1 and 3 run), or `lune run scripts/verify -- --quick` once the lead clears the machine; repeat at every slice |
| 2 | `Params`, `Checks`; D3's two rows in `Definitions/MinigameFamilies`; T-DEF-05's list; the fingerprint re-bless ([5.3]) | `Params.spec` (T-MG-07, P-ORDER), `Checks.spec` | `--filter "Minigames/Params"`, `--filter "Minigames/Checks"`, `--filter "Definitions/"`; `git status --short tests/golden` = the fingerprint only |
| 3 | `TimingStrike` (generate, session, finish, checks, view, feedback, combo); `TS_PERFECT_CORE_MIN_MS` read by the Definitions spec ([5.2]) | `TimingStrike.spec` (E-S3.4 goldens, grade bands, checks at their thresholds on scripted presses, `view.cycle` at each `start_i`) | `--filter "Minigames/TimingStrike"`, `--filter "Definitions/MinigameFamilies"` |
| 4 | `HoldZone` | `HoldZone.spec` (E-S3.7 goldens and stroke curves, holding alone scores 0, `centerAt` pointer = stateless, `HzInhumanRate` at 29 / 30 presses) | `--filter "Minigames/HoldZone"` |
| 5 | `PrecisionTrace` (with `credit` and `coveredRuns`); `tests/fixtures/Edges.luau`; `Cost.X08_EDGE`; `PT_TRAVEL_MAX_MS` read by the Definitions spec | `PrecisionTrace.spec` (E-S3.5 source, path, fallback and blade table; PtTooSmooth dt 9/10/40/41; each flag at its threshold) | `--filter "Minigames/PrecisionTrace"` |
| 6 | `Timeline`; `tests/lib/Cheats.luau` (malformed, flood, replay, garbageBuffers) | `Timeline.spec` (round trips on scripted records, byte goldens, T-MG-08 decode-level) | `--filter "Minigames/Timeline"` |
| 7 | `Input`, the `Minigames` facade; `MinigamesHelpers.luau` (scripted timelines) | `Input.spec` (stamping, T-MG-15's stamping and offset cases with the unquantized Exact presses, T-MG-16), `Minigames.spec` (T-MG-01, T-MG-02 scripted and `Prop`, T-MG-08 judge-level, T-MG-14 scripted; F5 and C02 from `Analyze.run` once the fix is committed), the non-bot rows of `Properties.spec` | `--quick --filter "Minigames/"`; nothing blessed yet |
| 8 | `Bots` (with "Exact"); `Cheats.exact`; `tests/fixtures/MinigameTimelines.luau` | `Bots.spec` (profiles, determinism, T-MG-11 fast, the frozen timelines, the libm canary, decode of every bot timeline), the bot cases of `Minigames.spec` (T-MG-02, 09, 14) and `Input.spec` (T-MG-15), the bot rows of `Properties.spec`; `Reference.spec` (parity and full precision) | `--quick --filter "Minigames/"`; `--filter "Minigames/Reference"` (≈ 15 s quiet): exact on 48 × 100 runs; then bless `minigames.bv1` once with `-- --bless --filter "Minigames/Minigames"` and review it; measure the per-run costs through the Recorder (T-MG-04's three families, T-MG-10's four devices) and fix the L3 sizes; precompute on the prototype the pinned configs not yet computed (T-MG-03's per-run floors, T-MG-11 and T-MG-15 slow; T-MG-10 TimingStrike and HoldZone optional), one process at a time, each under 5 minutes, outcomes into M4-notes |
| 9 | the new Tol rows (D10) | `Statistics.spec`, `FalsePositives.spec` (L3) | in a quiet window, one after the other: `--filter "Minigames/Statistics"`, `--filter "Minigames/FalsePositives"` (no `--quick`); every outcome must equal its precomputed one (a difference is a porting bug, D11); record each case's time, T-MG-06's drops, T-MG-12's SDs, the trace deviation minimum and 0.1 % quantile, and the M4 L3 total with slices 1 and 8's slow cases |
| 10 | — | `Perf.spec` (T-PERF-02 at the decode caps) | alone and quiet: `--filter "Minigames/Perf"`; record the medians, the honest maxima and the CPU load |
| 11 | README Status and Layout; `docs/build/M4-notes.md`; the SPEC and evidence edits of [12] handed to the lead | everything | `lune run scripts/verify` (full, with `t.slow`) green under the gates the lead set in slice 0, in a window the lead clears; then the lead's commit "M4: minigames" |

Builder hygiene (the house rules): append a plain-words line to `ROBLOX/.build-notes/PROGRESS.md` at each slice
(`printf` append only); keep a NOTES file in the builder's scratch folder so a cut-off can resume; never bless a golden
another team owns; never kill processes by name.

---

## 12. SPEC, evidence and README edits M4 hands the lead

- §16.12: `PT_SMOOTH_DT_MIN_MS` 10 / `PT_SMOOTH_DT_MAX_MS` 40 (D3); §10.6's PtTooSmooth row names them.
- §16.32: `BOT_RUNS_FAIL`, `STEEL_DROP_RUNS`, `FAIRNESS_SEEDS`, `FAIRNESS_BOT_RUNS`, `TP_RUNS`,
  `PERFECT_HZ_RUN_MIN_SCORE`, `PROP_N_FAST`, `FUZZ_N_STRUCT_FAST` (D10); `STEEL_MEAN_DROP` per O4's outcome.
- §6.2 and §12.5: the Recorder's `horizonMs` and `since`, the host advancing to the horizon and pushing once more before
  `finish` (D4, [3.6]); §6.4 rule 7 reworded with it; §6.6: TimingStrike at GO (D9) and the trace's first record at
  t = 0 (I7); §6.7 / §10.3: `TooMany` for an oversize buffer (D8).
- §6.3, §6.4, §14.4: `mul32` and the SplitMix step written with `mod` (or §6.4 listing integer `%`), and the Minigames
  source whitelist (I6, [3.0]).
- §6.8 and §6.10: the prototype's grouping, `F − F·(10/fireDecayMs)` and `ceil(L/pacerSpeed·1000/20)·20` (G8).
- §6.8–§6.10: the view fields and FeedbackEvents as built (or a pointer to `Minigames/Types`), with §6.10's `credit` and
  `coveredRuns` (G14); §6.9: the combo rule (new O "A") and `CycleStart` from the view's `cycle` (D12); the live score
  (new O "B"); §6.11: TimingStrike's decisions lag by the frame and max(0, `timingOffsetMs`), its beat cue does not
  (G15).
- §6.12: the policy fields the prototype carries beyond the table ([3.11]).
- §4.8: `edge` = the narrow `{ chains, gripPoint, gripAxis }` table (G13).
- §6.13 and §17.2's S3 row: the Steel drops on the larger sample (TimingStrike 0.0089, not PrecisionTrace, under 0.01;
  O4).
- §10.5 and §17.2's S5 row: one Studio threshold for `judge`, applied to the decode-cap timeline (I8), with the
  decode-cap projection (≈ 7.5 ms).
- §14.1 and E-S8.7: both gates (I4), with M4's measured L1 share and L3 total.
- §14.6: T-MG-13 (I2), T-MG-12's definition (G6), T-MG-06's paired runs (I3), T-MG-04's band (G16), T-MG-03's per-run
  floors, T-MG-11's MVP tiers (G18). §14.7: the new fixture modules `Edges` and `MinigameTimelines`. §14.8: the four FP
  devices (G17) and the trace margin statistic (G19). E-S8.5: T-RNG-01 from E-S3.1 with the helper vectors (I1), 03 and
  05 as built (G12), T-RNG-06's non-overlapping lag-1 pairs, and T-MG-15's "keeps flag decisions" stated for the
  unquantized Exact.
- §17.1: O4's outcome; the two new O rows. §17.2's S3 rows: the trace deviation minimum re-measured (×3.24, G19) and the
  Steel drop (O4); S8's V-08 with M8 as its verifier ([7]).
- A new evidence section "E-S3.10 M4 as built" with the measured L3 values, the precomputed outcomes and the build's
  agreement with them, the parity and full-precision results and T-PERF-02's medians (as E-S2.13 did for M3); fix I5's
  stale lines or note them there.
- README: Status (M4 built), Layout (`tests/Minigames/`, `tests/lib/Cheats.luau`, `tests/fixtures/Edges.luau`,
  `tests/fixtures/MinigameTimelines.luau`).
- `docs/build/M4-notes.md`: open items for M5 (S-PAR-02 on Lune-made timelines, T-CR-09's distributions, `stepInput`'s
  narrow edge), M7 (the Recorder seams, `judge`'s Studio budget at the decode cap and I8, `Cheats` for S-E2E-10 with
  `earlyTolMs`) and M8 (views with `credit` and `coveredRuns`, feedback, the horizon host loop with its final push,
  `CycleStart` from the view, V-08), with the deviations above.

---

## 13. Measurement index (how this plan's own numbers were taken)

No Lune process was run for this plan, no repo file was edited, and Studio was not touched. Copies of the two scripts
and their outputs are in `ROBLOX/.build-notes/m4-plan/measure/`.

- `rng_ref_out.txt`: `python -I rng_ref.py` (Python 3.12.5, a copy of `docs/spec/prototypes/S3/rng_ref.py`): every
  E-S3.1 vector reproduced bit for bit, plus the tagged streams' states and floats. `rng_extra.py` /
  `rng_extra_out.txt`: the four game tags' FNV values, `mul32` cases, `hashU32` cases, seeds 0 and 2^32 − 1.
- `dist_stats.py` / `dist_stats_out.txt`: over `docs/spec/prototypes/S3/v2/out/S3-score-distributions.luau` (48 cells ×
  2,000 scores): per-cell means and SDs, first-400 against 2,000, Q8 fail rates and their 400-run normal-approximation
  failure odds, paired Iron − Steel and Normal − Hard drops with their SEs at 400 runs, profile-order margins. The
  per-run costs come from the prototype's recorded outputs (`out/final_table.txt`'s "(main cells 243.3 s)" for 96,000
  runs, `cost.txt`, `cost2.txt`, `worst.txt`) and §16.32's 6.5 ms per trace run.
- r2 (the M4 plan reviser): no Lune process was run, no repo file was edited, Studio was not touched. Taken from critic
  B's scripts and outputs in `ROBLOX/.build-notes/m4-plan/critic-b/` (each run on the prototype, one Lune process at a
  time): `t45` (T-MG-04/05 with the pinned names, 112 s), `t6` (T-MG-06, 90 s), `fair` (T-MG-12, 40 s), `ptmargin` and
  `tail` (T-MG-10's trace margin, 2 × 10,000 runs, 147 s), `tscost` (TimingStrike FP per-run cost, 42–69 % busy),
  `worstcap` (the trace judge, honest against the decode cap, 59–68 % busy), `l3_odds` (predictive odds), `rng_check`
  (T-RNG exactness and χ² outcomes), `stamp_check` (Recorder stamps, D7), `helpers_vec` (T-RNG-01's helper vectors).
  Checked for r2: the helper vectors, re-derived with an independent Python implementation of §6.3 (identical; script
  in the reviser's scratch folder, `m4-plan-reviser/helpers_check.py`); `lune.exe` 0.8.9's imports (the UCRT's
  `api-ms-win-crt-math-l1-1-0.dll`, D14); `tests/lib/Dump.fnv1a32` (the standard FNV-1a 32); `Physics/Analyze`'s
  thirteen requires (D5); and the SPEC, evidence and prototype lines each critique point cites.

---

## 14. What changed in r2

Critic A = `critique-coverage.md`, critic B = `critique-determinism.md`; the number is the critic's finding.

| Change | Where | From |
|---|---|---|
| L1 budgeted: M4's share ≤ 3 s, quick sizes `PROP_N_FAST` and `FUZZ_N_STRUCT_FAST`, timed at every slice; I4 now covers both gates | [2.4], [6.4], [6.7], [9.2] I4, [11] | A 1, B 1 |
| L3 re-costed: TimingStrike FP 283 s (not 144), the Q8 extension 37 s (not 16); M4 ≈ 11–13 minutes, all of L3 ≈ 16–18; FP cases split by device and tier; per-run costs measured in slice 8 | [6.4], [10] R1, [11] | B 2, A 14 |
| O4 re-worded: TimingStrike (hammering), not PrecisionTrace, is under 0.01 (pooled 0.0089 ± 0.0010); the retune alternative names TimingStrike's Steel column; the 0.005 default passes all three on the pinned seeds | [6.3] T-MG-06, [9.1], [9.2] I3, [12] | B 3, A 14 |
| Trace anti-cheat margin: ×3.24 reported as §17.2's re-measure; the 0.1 % quantile reported; the statistic is the lead's call | [6.3] T-MG-10, [9.2] G19, [10] R12 | B 4 |
| Odds replaced by the predictive figures; L3 config names pinned with their precomputed outcomes (D11) | [1], [6.3], [6.4] | B 5, A 14 |
| Slices reordered so every module exists before its first test; golden (b) blessed once | [6.1], [11] | B 6 |
| T-PERF-02 at the decode caps (HoldZone 1,024, TimingStrike 512, trace 2,048), honest maxima reported; R7 likely (≈ 7.5 ms); no event tables in `replay` (D13); I8 | [6.8], [10] R7, [9.2] I8, [1] | A 2, B 7, B 13(g) |
| T-MG-03's per-run floors (`PERFECT_HZ_RUN_MIN_SCORE` 0.85; 0.98 for TimingStrike@60 and the trace) | [6.3], [5.1] | B 8 |
| Golden (b) on frozen timelines, a libm canary, R6's reasoning fixed, Lune-made timelines recommended for S-PAR-02 | [1] D14, [6.5], [7], [10] R6 | B 9, A 16 |
| D1 made testable: the full-precision side-by-side check in `Reference.spec` | [1] D1, [4.2], [6.3] | B 10 |
| `Source.spec` enforces §6.4 as a whitelist | [3.0] | B 11 |
| T-RNG: χ² outcomes precomputed (r1's ≈ 4 % risk is 0), lag-1 pairs non-overlapping, helper vectors added | [6.2] | B 12 |
| Trace view: `credit` and `coveredRuns` for §12.8's trail and tint | [3.1], [3.9], [8.4], [9.2] G14 | A 3 |
| Parity traps: the trace bot's due-frame draw rule; record-level differences listed; parity on scores; I7 | [3.11], [6.3], [9.2] I7 | A 4 |
| TimingStrike's `CycleStart` on the raw clock (D12); §6.11 cited | [1], [3.6], [3.8], [8.4], [9.2] G15 | A 5 |
| Push the last records before `finish` | [3.6], [6.3] T-MG-09, [8.4] | A 6, B 13(e) |
| T-MG-15: +35 ms; the unquantized Exact; HoldZone and the trace ignore the offset | [6.3] | A 7, B 13(f) |
| T-MG-01: generation parameters desync, scoring parameters do not | [6.3] | A 8, B 13(b) |
| T-MG-11: E-S3.4's 0.9600 at x = 1; the MVP-tier reading | [6.3], [9.2] G18 | A 9 |
| The `%` ban listed as I6, with SPEC edits | [3.0], [9.2], [12] | A 10, B 13(h) |
| V-08 listed for M8, with §6.6's per-frame fallback | [7] | A 11 |
| `Cheats.new` takes `Bots`; `exact` through Bots' "Exact"; `fast` takes `earlyTolMs` | [3.11], [6.6] | A 12 |
| The trace TP asserts `PtTooPrecise` and reports `PtTooSmooth` | [6.3] T-MG-10 | A 13 |
| Two plan readings listed: T-MG-04's band (G16), the FP devices (G17) | [9.2] | A 14 |
| [12] completed with every deviation | [12] | A 15 |
| Slips: E-S8.6, not M3-notes; G13 reworded; the facade re-exports `TS_OFFSET_OFFER_MIN_JUDGED`; profiles carry policy fields; `gripPoint: DT.Vec3` | [6.9], [9.2], [3.10], [3.11], [3.1] | A 16 |
| "Holding alone scores 0" pinned | [6.5], [11] slice 4 | A 17 |
| D7: exact-time button bots pass `frameDtS = 0` | [1] | B 13(a) |
| One hand-written byte golden per family | [6.3] T-MG-08, [6.5] | B 13(c) |
| D5: structural copies, no Physics require | [1], [3.1], [3.12] | B 13(d) |

---

## 15. Critique points not taken, and why

- **B 5: pairing T-MG-04 with one salt per family and profile** (and T-MG-06 reusing T-MG-04's cells). The current
  names' outcomes are precomputed and pass ([6.3]), and T-MG-06's own pinned name has its precomputed result too.
  Renaming needs a new prototype run before the build, for a gain that only matters at the next re-draw (T-MG-05's odds
  0.86 % → 0.2 %). Taken instead: the corrected odds, and the rule that a name may change before a run, never after a
  failure (D11). At the next BALANCE re-draw the lead can adopt the paired names, recomputing their outcomes first.
- **B 4: "report the minimum only" or "assert 2.5×".** §14.8 asserts the minimum at 3×, and the pinned seeds pass
  (×3.24); weakening the SPEC's assertion with no failure to justify it is the lead's and S8's call, not the build's.
  Taken: the quantile reported beside it and proposed as the statistic for future re-draws (G19).
- **A 14: adding Poor@30 to the TimingStrike FP runs.** L3 is already over its gate, and a profile with σ 90 ms has no
  realistic path to a 1.5 ms-SD flag; the reading is listed instead (G17), with the cost (≈ 33 s) if the lead wants it.
- **A 10: keeping `%` in `Rng`.** The ban is kept (critic B 11 asks for it), uniform across the folder and listed as I6
  with its SPEC edits; the values are identical either way.
- **A 3's `BinCovered(i)` event and A 5's `advance(S, horizonMs, nowMs)`.** The other option of each finding was taken:
  covered runs are state, which §6.11 puts in views ("FeedbackEvents drive audio and VFX only"), and the view's `cycle`
  already runs on the raw clock, so `CycleStart` needs no change to §6.2's `advance` signature.
- **A 16: "G13 cites the wrong §17.2 S1 row".** Partly: the row is about `StepRecord`, not `EdgeProfile`, but it is the
  same unconfirmed width-subtyping question, so G13 now cites it as a parallel.
- **B 13(d)'s "hold D5 until the fix commits" and B 12's Good's ψ² statistic.** The other option of each was taken
  (structural copies; non-overlapping pairs).
- **Superseded figures, not rejected points:** A 14's "≈ 1 % over 48 cells" (critic B's computed 0.74 % is used); A 2's
  "≈ 38 % more work" (critic B's measured ×1.11 on the whole judge is used); B 2's split of Elite@240 alone (every
  TimingStrike device is split by tier, for uniform names).
- **B 9: "Lune-made timelines the primary design for S-PAR-02".** Taken as a recommendation only: S-PAR-02's design is
  M5's decision.
