# M4 plan critique B: determinism, tests and risk

Critic B, 2026-11-18, on `plan.md` (1,306 lines) as written at 16:05. Lens: the §4.1/§6.4 arithmetic, Lune = Studio
replay, whether each test can fail, L3 power and false-failure odds, T-PERF-02 under load, golden reproducibility,
slice order. Nothing in the repo was edited and Studio was not touched. I ran Python, plus six short Lune 0.8.9 runs
of the S3 v2 prototype. Each was one process at a time, from a scratch copy, and none is still running. Scripts and
outputs are in `ROBLOX/.build-notes/m4-plan/critic-b/` (index at the end). "Line N" means `plan.md` unless a file is
named.

**Short version.** The determinism design holds. The plan's PRNG arithmetic is exact and its vectors reproduce. The
Recorder's stamps equal the prototype's. Live = replay holds by construction with D4, and the judge needs no libm.
The plan's statistics and budgets are where the risk is. In order:

- Both test-time gates are blown, not only L3.
- The O4 numbers point at the wrong family.
- The PrecisionTrace anti-cheat margin is thin.
- The L3 odds are understated.
- The slices cannot be built in the order written.

Running the planned L3 configurations on the prototype now, with the plan's own config names, settles most of the
statistical questions before any code is written (findings 3–5).

---

## Findings, most serious first

### 1. High: the L1 `--quick` gate (≤ 30 s) has no room left, and the plan never budgets M4's fast cases

- **Problem.** §14.1 (SPEC line 3787) records the L1 run at 29.3–29.6 s quiet after the shift fix's pins, and
  29.64–29.99 s after its round 2. The plan puts a large set of M4 cases into `--quick` and never mentions L1's 30 s.
  A grep of `plan.md` for "30 s", "L1" or a quick budget finds nothing. The cases:
  - T-MG-08: 2,000 garbage buffers plus 2,000 structured buffers per family, many of which replay in full.
  - T-MG-01: 36 configs × 4 seeds × (2 prepares, 4 starts, 2 judges).
  - T-MG-02: 3 × 200 `Prop` runs. T-MG-09 fast: 3 × 30. Golden (b): 144 configs.
  - Properties: PROP_N 200 per row, plus FUZZ_N_GARBAGE judges. Bots.spec.
  - T-MG-11 fast: 400 runs. T-MG-15 fast: 1,000 runs.
- **Evidence.** A rough estimate from E-S3.5's per-call costs: PrecisionTrace generate 0.5–1 ms, replay plus checks
  about 1.3 ms, a human trace bot about 4 ms (the rest of the 6.5 ms per run). The PrecisionTrace-heavy property,
  T-MG-08 and bot rows alone come to about **5–10 s quiet**. L1 would then take about 35–40 s against a 30 s gate.
- **Fix.**
  - Agree an explicit M4 share of L1 with the lead now, in slice 0 together with I4 (for example ≤ 3 s).
  - Size the fast cases to that share: PrecisionTrace rows at n = 50 in `--quick` and full n in `t.slow`, and bot
    property rows only in `t.slow`.
  - Record `--quick --filter "Minigames/"` time at every slice check, and stop to re-size once the cumulative time
    passes the share.
  - §14.1's own remedy (move to `t.slow`) collides with I4, so the two gates must be re-budgeted together. Extend
    [9.2] I4 to L1.

### 2. High: the L3 time is worse than the plan's 9 minutes

- **Problem.** Lines 900 and 907 cost T-MG-10's TimingStrike runs at 0.12 ms each (4 × 300,000 = 144 s). That figure
  is E-S8.7's, measured with S8's stand-in bot. S3's frame-model bots draw randomness every frame, and Elite@240 has
  four times the frames of 60 fps.
- **Evidence.** `tscost.luau`: the prototype, 20,000 runs per device, tiers and materials cycled, the machine 42–69 %
  busy.

  | Device | ms per run | 300,000 runs |
  |---|---|---|
  | Elite@240 | 0.512 | 154 s |
  | Elite@60 | 0.165 | 49 s |
  | Good@60 | 0.157 | 47 s |
  | Average@30 | 0.109 | 33 s |
  | **Total** | | **283 s** (plan: 144 s) |

  Line 910's "Each TimingStrike FP case (≈ 36 s)" is about 4× low for Elite@240.

  The build adds work the prototype does not do (expected cost, not measured):
  - every bot record goes through `Input`;
  - every run goes through `prepare` and `replay`, with checks, `Checks.sorted` and FeedbackEvent tables.

  Revised totals, quiet: about 10 min for M4 on the prototype's costs, about 11–12 min with the build's overhead. The
  full L3, with the existing 295 s, is about 16–17 min against ≤ 10, and more at this machine's usual 40–60 % load.
- **Fix.**
  - Hand the lead the corrected figure in slice 0, not slice 9.
  - Measure per-run costs in slice 8, with bots going through the Recorder, before slice 9 fixes the sizes.
  - Split Elite@240 into a Normal case and a Hard case, to stay well inside the 300 s case budget.
  - Whether FP_RUNS_TS runs on every L3 pass or only at milestone exits is S8's and the lead's call. Put it in I4.

### 3. High: O4 names the wrong family; on the larger sample TimingStrike, not PrecisionTrace, is under 0.01

- **Problem.** Lines 1142–1150, I3 (lines 1176–1180), line 898 and the planner's summary all say T-MG-06 "fails
  PrecisionTrace for certain and TimingStrike about one time in five". §6.13 and §17.2's S3 row (SPEC line 4863) read
  the same 2,000-run table. Those 2,000-run drops carry standard errors of 0.0025–0.0031, which is as large as the
  margins being argued.
- **Evidence.** `t6.luau` runs T-MG-06 (b) exactly as the plan words it: Average, Normal, Iron and Steel paired, salt
  `fnv1a32("T-MG-06 <family>")`, STEEL_DROP_RUNS of 4,000 / 20,000 / 4,000. The build reproduces this bit for bit if
  the Reference parity holds.

  | Family | This run | Shipped 2,000 runs | Pooled | P(true drop < 0.01) |
  |---|---|---|---|---|
  | HoldZone | 0.0153 | 0.0158 | 0.0155 ± 0.0010 | ≈ 0 |
  | TimingStrike | **0.0086** | 0.0124 | **0.0089 ± 0.0010** | ≈ 0.87 |
  | PrecisionTrace | **0.0130** | 0.0090 | **0.0117 ± 0.0014** | ≈ 0.12 |

- **Consequence.**
  - At the SPEC's 0.01 floor, T-MG-06 as planned fails on **TimingStrike** and passes PrecisionTrace.
  - At the default 0.005, all three pass. The margins are 0.0103 / 0.0036 / 0.0080 (HZ / TS / PT), with SEs of about
    0.0012 / 0.0010 / 0.0018.
  - O4's alternative ("retune PrecisionTrace's Steel column") is aimed at the wrong family: TimingStrike's Steel column
    would need it.
- **Fix.**
  - Re-word O4 for the lead with the pooled figures.
  - Pin the T-MG-06 config names in the plan, so this precomputed outcome is the one the build gets.
  - Correct §17.2's S3 row and §6.13's sentence in the M4 SPEC edits ([12]).

### 4. High/medium: T-MG-10's PrecisionTrace margin (minimum mean deviation ≥ 0.0024 u over 20,000 runs) is thin

- **Problem.** Lines 846–847 assert the *minimum* over FP_RUNS. The minimum of N runs keeps falling as N grows.
  E-S3.8's ×3.48 came from 3,000 runs; the plan uses 20,000.
- **Evidence.** `ptmargin.luau`: Elite 30 fps / 360 px, Iron, x = REF_X, 10,000 runs per half, plan-style names.
  - No flags in any run.
  - Minimum mean deviation: Normal 0.00279 u (×3.49), **Hard 0.00259 u (×3.24)**, against the floor of 0.0024 (×3).
  - `tail.py` fits on the 20,000 values put the chance that a half's minimum falls below 0.0024 at about 1 %
    (lognormal) to 10 % (generalized Pareto on the lowest 2 %). The Hard half has 3 runs under 0.0028, a heavier
    tail than lognormal.
  - That is 2–20 % for a fresh pair of halves. The 0.1 % quantile, by contrast, is stable: 0.00303–0.00304 (×3.8).
  - §17.2's S3 row (SPEC line 4865) says to retune `PT_PRECISE_MEAN_DEV` "if it nears 3 ×". ×3.24 is near.
- **Fix.** Decide before slice 9, with S8 and the lead. Either:
  - assert a quantile, for example the 0.1 % quantile ≥ 3 × `PT_PRECISE_MEAN_DEV`, and report the minimum; or
  - keep the minimum as reported only, beside the hard 0-flag assertion; or
  - if the minimum stays asserted, set it at 2.5×.

  Hand ×3.24 to the lead now as the §17.2 re-measure.

### 5. Medium: the plan's L3 odds are understated, and T-MG-05 is unpaired

- **Problem.** [6.4]'s probabilities treat the shipped 2,000-run estimates as the truth. But the plan's `configSalt`
  seeds are new seeds, so the build draws a fresh sample, and the estimate it is compared with has its own error.
  Separately, line 897 uses the *paired* SE (0.004). T-MG-04's salts include tier and material (lines 802–803), so
  Normal and Hard runs are independent, and the SE is 0.0051–0.0054.
- **Evidence.** `l3_odds.py`, predictive odds on the shipped cells:

  | Assertion | Predictive odds | Plan's figure |
  |---|---|---|
  | T-MG-04 means | 0.74 % | 0.3 % |
  | Q8 bands at 1,000 runs | 0.57 % (TimingStrike Steel/Normal Average alone 0.46 %) | 0.15 % |
  | T-MG-05 | 0.86 % (0.2 % if paired) | ≈ 3e-4 per cell |
  | T-MG-06 at floor 0.005, fresh seeds | PrecisionTrace 9.6 %, TimingStrike 1.2 % | ≈ 2 % |

  On the 2,000-run evidence alone, P(true PrecisionTrace drop < 0.005) is already 5.5 %. With the plan's actual names
  the draws came out passing (finding 3, and `t45_eval.py`):
  - T-MG-04: worst mean at 0.67 of its band; smallest Q8 margin 2.3 points; no run flagged.
  - T-MG-05: Average drops 0.068 / 0.069 (HoldZone), 0.098 / 0.088 (TimingStrike), 0.079 / 0.074 (PrecisionTrace);
    PrecisionTrace Elite drops 0.0077 / 0.0052, all > 0.
- **Fix.**
  - Use one salt per (family, profile), shared by the four tier × material cells: `configSalt("T-MG-04 <family>
    <profile>")`. Tier drops and Iron − Steel are then paired, and T-MG-06 can reuse T-MG-04's Average Normal cells
    extended to STEEL_DROP_RUNS.
  - Name every L3 config in the plan and precompute its fixed-seed outcome on the prototype before slice 9. This file
    does it for the current names of T-MG-04/05/06/12 and the PrecisionTrace margin; renaming means redoing it.
  - Write the expected statistics into the plan, so a slice-9 difference reads as a porting bug, not a statistics
    question.

### 6. Medium: the slice order cannot be built as written

- **Evidence.**
  - [3.12] (lines 579–580): Timeline requires PrecisionTrace's panel constants. But Timeline is slice 3 and
    PrecisionTrace is slice 6.
  - Slice 3's `Timeline.spec` holds T-MG-08 (line 1256), which needs:
    - `judge` (slice 7);
    - every family's `hash` (`HashMismatch`);
    - "decode(encode(r)) = r for every bot timeline" (Bots, slice 8).
  - Slice 3's `Cheats.exact` needs HoldZone's exact-state controller from Bots, and `Cheats.replay` needs `judge`.
  - Slice 4's "T-MG-11 fast" (line 1257) needs a Perfect@30 bot through `Input`.
  - Slice 7's cases need Bots (slice 8): T-MG-02 (bot profiles, Exact cheats), T-MG-09 (bot timelines), T-MG-13 (b)
    ("one bot run per profile"), T-MG-14 (the Exact cheat, HoldZone's included), T-MG-15 (Elite@240, Good). Bots, in
    turn, needs slice 7's `prepare` and `replay`.
  - Golden (b) is blessed in slice 7, before its bot rows exist, so it is blessed twice.
- **Fix.** Reorder:
  1. Rng.
  2. Params and Checks, with D3's re-bless.
  3. TimingStrike.
  4. HoldZone.
  5. PrecisionTrace, with Edges.
  6. Timeline. PrecisionTrace exists now and owns the panel constants. Decode-level T-MG-08 on scripted records.
  7. `Input` and the facade, on scripted timelines only: T-MG-01; T-MG-02's boundary and `Prop` cases; T-MG-08's
     judge-level cases; T-MG-14 on scripted exact TimingStrike presses; T-MG-16.
  8. Bots and `Cheats.new(Minigames, MinigameFamilies, Bots)`, every bot-dependent case, golden (b)'s bless, and
     Reference.
  9. L3. 10. Perf. 11. Verify.

### 7. Medium: T-PERF-02 uses the honest maximum, not the decode-legal maximum, and R7 is likely, not borderline

- **Problem.** Lines 985–991 time PrecisionTrace at about 1,480 or 1,551 records and HoldZone at 1,023. Decode
  accepts 2,048 and 1,024 records (§6.7), and the server judges whatever decodes. `PT.checks` runs a nearest search
  for every grinding, in-travel sample (prototype `PrecisionTrace.luau` line 656), so cost grows with the record count.
- **Evidence.** `worstcap.luau`: the prototype, decode + replay + checks, medians of 15 alternating rounds, the machine
  59–68 % busy.
  - 1,476 samples: 3.31 ms. 2,048 samples: 3.68 ms (×1.11).
  - Projection to Studio: 2.59 ms quiet × 1.11 × 2.6 ≈ **7.5 ms**, before the build's additions. That is over §10.5's
    "≤ 7 ms in Studio" (SPEC line 2810); R7 (line 1237) assumed 6.7 ms. A cheater can choose this timeline.
  - T-PERF-02's own 8 ms Lune budget still passes on a busy machine, with about 2× margin.
- **Fix.**
  - T-PERF-02 uses decode-cap timelines: PrecisionTrace 2,048 grinding samples about 14 ms apart near the pacer;
    HoldZone 1,024 records.
  - M4-notes reports that case's Studio projection against 7 ms, for M7's S-PERF-01.
  - `replay` should not allocate FeedbackEvent tables: return a shared frozen empty array when nothing fires. This
    changes no result.

### 8. Medium: T-MG-03 cannot find the rare impossible pattern it is sized for

- **Problem.** Line 797 asserts only the mean over SOLVABILITY_SEEDS, whose §16.32 rationale is "finds rare impossible
  patterns" (SPEC line 4782).
- **Evidence.** One impossible pattern in 1,000 moves a mean by at most 0.001. HoldZone Perfect sits at 0.966–0.987
  against a floor of 0.95.
- **Fix.** Add per-run floors: HoldZone every run ≥ 0.85 (the prototype's minimum is 0.897, E-S3.2); TimingStrike@60
  and PrecisionTrace every run ≥ 0.98 (the prototype gives 1.0000). Keep the mean, which is the SPEC's assertion.

### 9. Medium/low: golden (b) and Reference depend on the machine's libm

- **Problem.** Golden (b) (line 939) holds "one bot run per profile at fixed seeds". Bots use `math.log`, `math.cos`
  and `math.exp` (prototype `Bots.luau` lines 18–27).
- **Evidence.**
  - `lune.exe` 0.8.9 imports `api-ms-win-crt-math-l1-1-0.dll`, which is the system UCRT. Its math routines change
    with Windows updates and pick code paths by CPU (FMA3).
  - Golden (b) and Reference parity (lines 877–882) therefore pin this PC's runtime as well as M4's code.
  - Line 1037's reason for R6 ("the same Windows process as Lune's host machine, so the C runtime is the same") is
    wrong: Lune and Studio are separate binaries, and whether Studio uses the UCRT's libm is unverified.
- **Fix.**
  - Freeze golden (b)'s bot timelines as encoded buffers (hex) in `tests/fixtures`, so the golden pins only
    authoritative code.
  - Add a libm canary to `Bots.spec`: a blessed `fnv1a32` over `%.17g` of log, cos and exp at about 1,000 fixed inputs.
  - Make Reference's failure message name "libm changed" as the first suspect.
  - Make Lune-made timelines the primary design for S-PAR-02 at M5, not the fallback.

### 10. Medium/low: D1's grouping pins cannot be tested by the planned tests

- **Problem.** D1 pins expression grouping, but no planned test can see a grouping change.
- **Evidence.**
  - Pattern hashes quantize before hashing: HoldZone `round(c·1e6)` (`HoldZone.luau` line 66); PrecisionTrace
    1/16384 (`PrecisionTrace.luau` lines 424–428); TimingStrike integer times (`TimingStrike.luau` lines 43–47).
  - Scores pass through `q(·, 1e4)`, and T-MG-07 compares to printed precision (line 819).
  - A last-bit regrouping therefore changes a hash or a q-score with probability around 1e-10 to 1e-12, and passes
    T-MG-07, T-MG-13 and Reference.
  - For the same reason, D1's stated harm (line 67, "q can turn that into a different 1e-4 score") almost never
    happens. Client = server holds with any grouping, because both sides run the same code.
- **Fix.** Either call D1 "follow the prototype" without a test claim, or make it testable. In `Reference.spec`
  (Lune only, as it already requires the distributions file), require the prototype's Params, HoldZone, TimingStrike
  and PrecisionTrace, and compare side by side at `%.17g`:
  - resolved params: 3 families × 2 materials × 5 tiers × x ∈ {0, 0.1, 0.3, 1};
  - pattern arrays: keysC, cycles, pu, pv, arc, L, speed;
  - unquantized session sums: credit/n, Σ points, accSum, paceSum, nCovered;
  - inputs: random seeds and bot timelines.

### 11. Low/medium: `Minigames/Source.spec` enforces a blacklist, not §6.4's whitelist

- **Problem.** Line 188 bans only `%`, `%=`, `//` and `//=`. T-META-03 bans by prefix sin, cos, tan, exp, log, pow,
  atan, asin, acos, and `^` (`tests/Meta/Rules.luau` lines 583 and 596–620).
- **Evidence.**
  - Not caught: `math.lerp`, `math.map`, `math.noise`, `math.fmod` / `modf` / `frexp` / `ldexp`, `vector.*` (float32),
    and `buffer.readf32` / `writef32`.
  - `math.lerp` computes `a + (b − a)·t` in C++, which compilers may fuse into one FMA on ARM64 clients. A client's
    live score could then differ from the x64 server's (ScoreMismatch) while Lune and Studio on this PC agree.
- **Fix.** Make the spec positive. Every `math.` member in an authoritative Minigames file must be one of floor, ceil,
  round, abs, min, max, clamp, sqrt or huge. No `vector.`. Only integer buffer reads and writes. Keep the `%` and `//`
  ban.

### 12. Low: the χ² outcomes are known now, and the lag-1 statistic needs a definition

- **Evidence.** `rng_check.py` implements the plan's [3.2] text in IEEE doubles.
  - T-RNG-04: all 20 streams pass, the highest χ² being 30.87 (seed 0xC0FFEE, tag "TimingStrike.Tempo");
    `int(1, 16)` ≤ 22.50.
  - T-RNG-05: all 1,004 hashes, states and first outputs are distinct.
  - T-RNG-06: all 37 cases pass, the highest χ² being 28.20.
  - So line 776's "≈ 4 % one-time" risk is 0 for an exact port. With fixed streams, T-RNG-04 and 06 can fail only
    when T-RNG-01 already fails, except `int(1, 16)`, which tests `int`.
  - "Lag-1 pairs inside one stream" (line 775) is unspecified. On *overlapping* pairs, the 16-cell statistic is
    Σλχ²₁ with λ = 2, 2, 2, 1 × 9 and P(> 37.70) = **0.0049**, not 0.001.
- **Fix.**
  - Write "non-overlapping pairs (x₂ᵢ₋₁, x₂ᵢ)", or use Good's ψ²₂ − ψ²₁ with 12 degrees of freedom.
  - Record the precomputed χ² values in the plan.
  - Add helper vectors to T-RNG-01, which has none for `range`, `int`, `chance` or `sign`. From
    `Rng.new(1, "HoldZone.Target")`: `range(0.3, 0.7)` = 0.58070660615339875, `int(900, 2200)` = 2060,
    `chance(0.25)` = false, `range(0.5, 1.0)` = 0.8602050932822749, `sign()` = 1, `int(1, 16)` = 16. These reproduce
    E-S3.7's keys 0.6323, 5060 and 0.4000.

### 13. Low: small items

- **(a) D7 (lines 73, 566).** Exact-time *button* bots must also pass `frameDtS = 0`. The Recorder subtracts half a
  frame: `stamp_check.py` gives 995, not 1000, for `clockS = 1.0005` with a 10 ms frame. D7's premise is real:
  `(t/1000)·1000 < t` for 372 integers t ≤ 60,000, and `(t + 0.5)/1000` fixes every one of them.
- **(b) T-MG-01 (line 789).** "One param nudged → Desync" fails for scoring-only params (halfWidth, coreFrac,
  wAccuracy, paceTol, edgePoints, passThreshold): hashes cover only the pattern. Name a pattern-shaping param per
  family (HZ `driftSpeed`, TS `beatMs`, PT `perturbAmp`). Otherwise a builder may "fix" the test by hashing params,
  which breaks E-S3's hashes.
- **(c) T-MG-08.** Encode/decode round trips cannot see a layout error made identically in both (for example a
  big-endian `dt`). Add one hand-written byte golden per family, for example E-S3.4's presses as hex.
- **(d) D5 (line 71).** Luau has no type-only `require`. `Minigames/Types` requiring `../Physics/Analyze` loads the
  whole Physics stack in every Minigames suite, including the other team's uncommitted edits while the fix is open.
  Either define structural copies of the three small types (Luau types are structural), or hold D5 until the fix
  commits (slice 0).
- **(e) Client finish (line 1110).** Push `rec:since(pushed)` once more before `Family.finish(session)` at GO +
  durationMs. Otherwise a record made in the last frame (a release, a press) is in the timeline but not in the
  session, and clientScore ≠ rawScore.
- **(f) T-MG-15.** Also assert that HoldZone and PrecisionTrace ignore `timingOffsetMs`. As written, an offset applied
  to every family passes.
- **(g) HoldZone's legal maximum.** It is 1,024 records (512 down/up pairs), not 1,023 (line 986).
- **(h) SPEC inconsistency.** §6.3 (SPEC line 1695) allows integer `%` in the Rng, while §6.4's whitelist omits it.
  The plan's stricter reading is harmless: Luau's `%` is exactly `x − floor(x/m)·m`, so the values are identical. List
  it among [9.2]'s I-items.

---

## Can each planned test fail?

For each test: a plausible bug it catches, and one it would miss.

| Test | Catches | Misses (cover) |
|---|---|---|
| T-RNG-01 | Seeding that mixes before adding GAMMA; a `mod` written `mod(ah·b·65536, 2^32)` (inexact above 2^53, fails 0xFFFFFFFF²) | Off-by-one `int` or a regrouped `range` (no helper vectors; add 12's) |
| T-RNG-02 | State kept on the shared metatable | A stream that is deterministic but wrong (T-RNG-01) |
| T-RNG-03 | The prototype's bare `assert`: a string seed errors inside `math.floor`, without "u32"; bit32 silently truncating 1.5 (E-S8.1) | Bots' silent `seed % 2^32` (by design) |
| T-RNG-04 | `int(lo, hi)` returning lo…hi−1 (bucket 16 empty) | Nothing beyond T-RNG-01 on the raw stream (fixed streams, precomputed to pass) |
| T-RNG-05 | A tag hash that ignores characters after the 8th | A future tag colliding with an existing one |
| T-RNG-06 | The tag ignored in seeding (identical streams per tag) | Correlation at other lags |
| T-MG-01 | A module-level memo mutated by a caller; `start` using another param set | Scoring-only params (13(b)) |
| T-MG-02 | `passed` taken from the clamped score; `>` for `≥` (the 6-of-12 case) | (none found) |
| T-MG-03 | A HoldZone zone unreachable on most seeds | A rare impossible pattern (8) |
| T-MG-04 | The Steel column applied to Iron; a wrong default x | A 1–2 point shift (band ≈ ±4 SE); Reference catches it exactly |
| T-MG-05 | Tier columns swapped | A tier effect halved but still ≥ 0.05 |
| T-MG-06 | The Steel column ignored (drop ≈ 0) | A Steel factor off by about a percent |
| T-MG-07 | Quantum applied before the clamp; `Tiers.order` off by one | A regrouped product (10) |
| T-MG-08 | Decode reading past the end; wrong first-failure order; a missing cap | A layout error symmetric in encode and decode (13(c)) |
| T-MG-09 | Advancing live to the raw frame time with a +60 ms offset (G1); a view moving HoldZone's key pointer | A bug shared by the live and replay paths |
| T-MG-10 | PtTooSmooth's dt bounds swapped; a flag never raised | A threshold loosened while the exact cheat still flags (accepted, Q17) |
| T-MG-11 | The core floor back at 9 ms (E-S3.4: worst run 0.9499 < 0.95) | (none found) |
| T-MG-12 | `segMinMs` / `segMaxMs` swapped (wildly different patterns) | Spread under 0.08 |
| T-MG-13 (a) | A changed draw order or tag; a lost Chaikin end point | Last-bit regrouping (10) |
| T-MG-13 (b) | Any later outcome change | (Machine libm, 9) |
| T-MG-14 | The clamp applied to rawScore; Medium flags clamping | (none found) |
| T-MG-15 | `t + offset`; no floor at 0 | The offset applied to every family (13(f)) |
| T-MG-16 | Two ups for one press; no up on focus loss | (none found) |
| Reference | A changed bot draw order; HoldZone's perception history off by a tick | Runs 101–2,000, Perfect/Idle, offsets, last bits under q |
| Source.spec | A `%` in a new authoritative file | `math.lerp`, `math.map`, `vector.*` (11) |
| P-ORDER | A resolver iterating a material map with `pairs` | (Design-term order is not shuffled, rightly) |
| T-PERF-02 | An O(n²) clearance search (the draft's 18–21 ms) | The decode-cap timeline (7) |

## What holds (checked)

- **PRNG ([3.2]).** The plan's formulas in IEEE doubles (`mod(x, m) = x − floor(x/m)·m`, no `%` or `//`) are exact:
  - 0 mismatches against exact integer arithmetic over 300,169 `mul32` pairs (edge cases included, such as
    0xFFFFFFFF²), 20,000 `fmix32` values, and 2,000 streams × 50 draws;
  - every partial product stays below 2^53;
  - every T-RNG-01 vector in [6.2] reproduces from the plan's own text, independently of `rng_ref.py`.
- **Stamps.** The Recorder's stamps (seconds in, ms out, `goClockS = 0`) equal the prototype bot's ms stamps on 14.3
  million random frames (the `Bots.frames` model, 30–240 fps): 0 mismatches for button and for trace stamps. The
  Reference check's "exact" expectation is sound for stamping. The prototype's remaining differences change no score:
  - TimingStrike and HoldZone clamp at durationMs where the Recorder drops (whiffs, breakdown only);
  - PrecisionTrace's first sample is at `floor(f₁)` where the Recorder writes t = 0 (before the lead-in).
- **Live = replay with D4.**
  - HoldZone integrates only ticks with 10k < horizon, and later records are clamped to ≥ the horizon.
  - TimingStrike closes a span only when T + M < horizon.
  - PrecisionTrace evaluates only ticks up to its latest sample.
  - With a positive offset, G1's failure is real as §12.5 is written, and D4 removes it.
- **Judge, Lune = Studio, by construction.** Integers out of decode, arithmetic inside §6.4's list, sorts on distinct
  strings (Luau compares bytes), no libm anywhere. Libm is in Bots only.
- **T-MG-12 (R9 retired).** `fair.luau` with the plan's definition: highest SD of per-pattern means 0.051 (HoldZone
  Hard) against 0.08; TimingStrike 0.022, PrecisionTrace 0.025. HoldZone does carry real between-pattern spread
  (0.045–0.050), which is a fairness observation, not a failure.
- **The rest of L3 and T-PERF-02.** With the plan's names, T-MG-04 and T-MG-05 pass (finding 5). T-PERF-02's 8 ms
  holds on a busy machine (3.68 ms at the decode cap, 59–68 % busy).

## Measurement index (`ROBLOX/.build-notes/m4-plan/critic-b/`)

Python 3.12.5; Lune 0.8.9 from the repo root. Each Lune script ran beside copies of
`docs/spec/prototypes/S3/v2/*.luau`, one process at a time, each under 5 minutes.

| Script | Output | What |
|---|---|---|
| `rng_check.py` | `rng_check_out.txt` | [3.2] exactness, the plan's T-RNG-01 vectors, T-RNG-04/05/06 outcomes, the overlapping-pair null distribution |
| `helpers_vec.py` | `helpers_vec_out.txt` | Helper vectors (12) |
| `stamp_check.py` | `stamp_check_out.txt` | Recorder vs prototype stamps; D7 |
| `l3_odds.py` | `l3_odds_out.txt` | Predictive L3 odds on the shipped 48 × 2,000 cells |
| `fair.luau` | `fair_out.txt` | T-MG-12 (40 s) |
| `ptmargin.luau`, `tail.py` | `ptmargin_out.txt`, `ptmargin_devs.txt`, `tail_out.txt` | T-MG-10 PrecisionTrace margin, 2 × 10,000 runs (147 s) |
| `t6.luau` | `t6_out.txt` | T-MG-06 with the plan's names (90 s) |
| `tscost.luau` | `tscost_out.txt` | TimingStrike FP per-run cost (19 s, 42–69 % busy) |
| `worstcap.luau` | `worstcap_out.txt` | PrecisionTrace judge, honest vs decode cap (59–68 % busy) |
| `t45.luau`, `t45_eval.py` | `t45_out.txt`, `t45_eval_out.txt` | T-MG-04/05 with the plan's names (112 s) |
