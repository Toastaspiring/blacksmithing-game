# M4 plan critique A: coverage and fidelity

Critic A, 2026-11-18, on `ROBLOX/.build-notes/m4-plan/plan.md` (1,307 lines, 16:05). Read against SPEC.md §0.4, §1.2–§1.6,
§2, §4.8, §5.1, §6 (every line), §7.1–§7.8, §9.4, §10.3–§10.7, §12.1–§12.10, §14.1–§14.12, §15, §16.6–§16.12,
§16.19–§16.23, §16.32, §17, §18; SPEC-evidence E-S3.1–E-S3.9, E-S8.4–E-S8.9; the S3 prototype (v1 `rng_vectors.luau`,
`rng_ref.py`, every v2 `.luau`, `out/*.txt`); M1/M2/M3 notes; the repo's Definitions, Physics/Analyze, MassProps, Edge,
tests/lib, tests/Meta. Nothing in the repo was edited; no Lune process was run; one Python re-derivation (below).

"Plan L" = plan.md line, "SPEC L" = SPEC.md line, "Ev L" = docs/spec/SPEC-evidence.md line.

## Findings, most serious first

### 1. The L1 gate (≤ 30 s quick suite) is not budgeted, and it is already full (High)

- Evidence: SPEC L3787 (§14.1 L1 row): "all pass, ≤ 30 s … past 27 s quiet, fast corpora … move to `t.slow` … 29.3–29.6 s
  quiet after the shift fix's pins … 29.64 and 29.99 s at 3–20 % busy after its round 2's". The plan sizes only L3
  (I4, Plan L886–912, L1181–1184) and never mentions the L1 budget or `CASE_BUDGET_MS` per fast case (grep: no "L1",
  "30 s" or "27 s" in the plan's gate analysis).
- Problem: every new fast case lands on a suite that is at 29.3–30 s before M4. A rough count from the plan's own per-run
  costs (PrecisionTrace ≈ 6.5 ms per bot run, replay ≈ 1.3 ms, generate ≈ 1 ms) gives 5–8 s of new fast work: T-MG-01
  (every config × 4 seeds, prepare twice, start, judge twice), T-MG-02's 200 record sets per family, T-MG-08's 2,000
  structured buffers per family (byte-flipped valid trace timelines mostly decode `Ok` and replay: up to ≈ 2.6 s in one
  case, over `CASE_BUDGET_MS` 2,000), T-MG-09's 30 runs per family, the goldens, and above all `Properties.spec`
  (Plan L961: `Prop.check(PROP_N = 200, …)` per row, with ≥ 5 rows that generate and replay PrecisionTrace patterns:
  200 × 2 replays × several rows is seconds per row, each row near or over the 2 s per-case budget).
- Fix: add an L1 row to [6.4]: per-file fast cost, measured in each slice with `--quick --filter "Minigames/<File>"`;
  a fast budget for all of M4 (for example ≤ 3 s); PrecisionTrace property rows and T-MG-08's structured fuzz at a
  reduced count in the fast set with the full count in `t.slow` (§14.1's own rule); and, beside I4, a second lead
  decision: raise L1's gate or accept the moves. Slice 11 cannot pass without one of the two.

### 2. T-PERF-02 measures the honest maximum, not the "longest legal timeline" (High)

- Evidence: SPEC L4092 (§14.11): "T-PERF-02 | longest legal timeline per family: decode + replay + checks"; SPEC L4793
  (§16.32): `REPLAY_BUDGET_MS` "decode + replay + checks of a 31 s timeline"; SPEC L2809–2810 (§10.5): `judge` runs
  synchronously in the Submit handler, "each ≤ 7 ms in Studio"; §6.7: decode accepts up to `MAX_RECORDS` 1024 / 512 /
  2048. Plan L985–991: HoldZone "1,023 alternating records (the cap less one)", PrecisionTrace "≈ 1,480 records; or the
  honest maximum 1,551 at 31 s".
- Problem: "legal" is what decode accepts, and Submit judges whatever a modified client sends. A PrecisionTrace timeline
  of 2,048 grinding samples (dt ≈ 14 ms over the 29.6 s length-bound pattern, all in travel) decodes `Ok` and runs
  `nearest` in `checks` for ≈ 38 % more samples than the 1,479 the prototype timed (`out/worst.txt`: replay + checks
  2.59 ms). The plan's own Studio projection of the honest case is already 2.6 × 2.59 ≈ 6.7 ms against §10.5's 7 ms
  (Plan L996–997, R7); the hostile case is the one that can pass it. HoldZone's decode cap is 1,024, not 1,023.
- Fix: T-PERF-02 asserts on the decode-cap timelines (HoldZone 1,024 alternating at 18 s; TimingStrike 512;
  PrecisionTrace 2,048 grinding samples on the length-bound pattern) and reports the honest maxima beside them; the
  hostile figure × 2.6 goes into M4-notes for M7's S-PERF-01 and §17.2's S5 row (checkpointed judge).

### 3. The trace view cannot serve §12.8's "covered runs tinted" (and its credit-coloured trail) (Medium)

- Evidence: SPEC L3405 (§12.8): "trail of the last `TRACE_TRAIL_SAMPLES` 24 positions by accuracy credit (≥ 0.9, ≥ 0.6,
  > 0, 0) … coverage bar, pace arrow, covered runs tinted." SPEC L1889 (§6.10) and Plan L231–233, L505–512: the view
  carries `coverage` (a fraction) and `accuracySoFar` (a mean); the feedback has `Coverage(25…100)` only.
- Problem: M8 needs which arc bins are covered to tint the covered runs, and a per-position credit for the trail; neither
  is in `PrecisionTraceView` or the FeedbackEvents, so M8 would read session internals or re-implement §6.10's scoring
  in UI code. The task brief says the facade must serve §12; this is a SPEC gap (§6.10's view list vs §12.8) the plan
  does not list.
- Fix: add read-only `covered: { boolean }` (or `coveredRuns: { {from, to} }`) and `credit: number?` (the latest
  evaluated tick's accuracy credit) to `PrecisionTraceView`, or a `BinCovered(i)` FeedbackEvent; list it as a G-item and
  a §6.10 view edit in [12] (presentation only, no BALANCE change).

### 4. "Exact prototype parity" has three unstated traps in the Recorder routing (Medium)

- Evidence: prototype `v2/Bots.luau` L385–397 (ptHuman draws tremor, two `gauss`, only on frames where a sample is due:
  `if fm >= nextDue …`), L172 (tsHuman clamps late presses to `durationMs` and keeps them), L222 (hzHuman drops events
  at `t ≥ durationMs`); its first trace sample is stamped `floor(frames[1])`. Plan L563–566: "at each simulated frame it
  calls the Recorder (… `rec:cursor(u, v, grind, f / 1000)`, `rec:go(...)` at the first frame)"; Plan L370: `go` records
  the trace at `t = 0`; Plan L362: records with `t > durationMs` dropped; Plan L877–882: parity on the first 100 scores
  of all 48 cells, "exactly".
- Problems:
  (a) If the trace bot calls `rec:cursor` every frame with a fresh tremor draw, or draws tremor for both `go` and the
  first `cursor` (at 30 fps the first frame falls at ≥ 20 ms in about 40 % of runs and records twice), the Rng stream
  diverges from the prototype and every later OU and lift draw moves: parity fails on PrecisionTrace cells, Poor's 30 fps
  ones first.
  (b) The first trace record: §6.6's "Trace samples" row (SPEC L1745) stamps it `floor(...)` at the first frame at or
  after due time 0, as the prototype does; §6.2 (L1686–1687) and §12.5 (L3348) say `t = 0`. The plan follows §6.2
  without listing the inconsistency; scores are unaffected (ticks start at `leadInMs + 20`), records are not.
  (c) End-of-step handling differs from both bots (kept at `durationMs` / dropped at `= durationMs` vs dropped past it):
  score-neutral (a press at `durationMs` is always a whiff since `T_N + M < durationMs`; no tick reads a down at
  `durationMs`), but records and `whiffs` differ.
- Fix: in [3.11] require the trace bot to decide "a sample is due" itself (the Recorder's rule: stamp ≥ due and > last)
  and draw tremor, then call `cursor`, only on those frames, passing the same drawn position to `go` and to a
  same-frame `cursor`; add (b) to [9.2] as an I-item; state (a)–(c) in [6.3]'s Reference paragraph so a builder does not
  chase record-level differences, and keep parity on scores (and flags) only.

### 5. D4 moves TimingStrike's presentation cues by the offset; §6.11 is never cited (Medium–Low)

- Evidence: SPEC L1894 (§6.11): "Views come from `advance(now)` each RenderStepped (≤ 1 frame + 10 ms latency)";
  SPEC L1823 (§6.9): "A `CycleStart` tick keeps the rhythm audible". Plan L449–450: `CycleStart` fires "as `advance`
  passes `start_i`"; Plan L375–377 (D4): TimingStrike's horizon is the offset-shifted stamp. Plan grep: §6.11 cited 0
  times.
- Problem: with `timingOffsetMs` = +120 the audible beat plays 120 ms after the dial's cycle starts (with −120, 120 ms
  before it), while the view's `cycle` and `marker` use raw `nowMs` (Plan L443–444): cue and dial disagree, and a late
  beat pulls the player later, against what the offset corrects. Span decisions (`Miss`, `lastGrade`, `combo`,
  `runningScore`) lag by the offset by design, which §6.11's latency figure does not allow for.
- Fix: emit `CycleStart` on the raw clock (from `view`'s `cycle` change, or an `advance(S, horizonMs, nowMs)` whose
  second time drives presentation cues only), keep decisions on the horizon; add §6.11 to [12] (latency of TimingStrike
  decisions = frame + max(0, offset)).

### 6. The host loop at submit drops records made after the last frame's push (Medium–Low)

- Evidence: Plan L1110–1111 ([8.4]): "At GO + durationMs: `Minigames.encode(spec, rec:records())`, `clientScore =
  Family.finish(session).score`". SPEC §7.7 (L2141) and §10.5: `clientScore ≠ rawScore` is ScoreMismatch; §6.11: no
  "mismatch" state.
- Problem: a record made between the last RenderStepped push and the `task.delay` callback (a release on focus loss,
  an input in the last partial frame) is encoded but never pushed, so an honest client's `finish` differs from the
  server's replay.
- Fix: "push `rec:since(pushed)`, then `finish`" in [8.4] and in T-MG-09 (b)'s host loop; note it in M4-notes for M8.

### 7. T-MG-15: the calibrated offset has the wrong sign, and its Exact case cannot show a kept flag (Low)

- Evidence: Plan L869–872: "the Exact cheat played through the Recorder at 60 fps keeps its `TsLowVariance` decision …
  (Average Iron/Normal 0.648 → about 0.717 at −35 ms)". Prototype `v2/dist.luau` L104–105: `off = round(renderLag +
  biasMean)` = +35 passed as `offsetMs` (subtracted from stamps); the "cal(−35 ms)" label is the card's "[Use −N ms
  offset]". `out/final_table.txt`: "TimingStrike … Perfect@60 … flagged 0%".
- Problem: in the Recorder's terms the calibrated run is `timingOffsetMs = +35`; −35 lowers the score. A Perfect/Exact
  run quantized to 60 fps frames is never flagged (E-S3.2), so "keeps its decision" only re-checks "unflagged" and
  cannot catch an offset bug that breaks a flag.
- Fix: write `timingOffsetMs = +35`; play the unquantized Exact cheat (D7 clocks, `frameDtS = 0`): errors all equal
  −offset, so `TsLowVariance` at every offset and `TsExactHits` only at |offset| ≤ 1 (which also qualifies E-S8.5's
  "keeps flag decisions" for exact inputs; say so in [9.2]).

### 8. T-MG-01's Desync case is wrong for most parameters (Low)

- Evidence: Plan L789–790: "`start` on a spec with one param nudged … returns `nil, "Desync"`". §6.8–§6.10 hash only the
  pattern: HoldZone keys `(t_j, round(c_j·10^6))`, TimingStrike `(S_i, P_i, T_i)`, PrecisionTrace `(uQ_i, vQ_i)`.
- Problem: nudging `zoneWidth`, `softFrac`, `windowMs`, `missPadMs`, `edgePoints`, `halfWidth`, `paceTol`, `tailMs`,
  `passThreshold` … leaves the hash unchanged, so `start` returns the pattern and the case fails.
- Fix: nudge a generation parameter per family (`driftSpeed` or `segMinMs`; `beatMs` or `tempoJitter`; `perturbAmp` or
  `bumpWidth`), and add the converse case (a scoring parameter does not desync: the client uses `params` verbatim,
  §6.4 rule 5).

### 9. T-MG-11 cites the wrong prototype margin (Low)

- Evidence: Plan L856: "prototype worst run 0.9655" (E-S3.2, x = `BOT_REF_X`). T-MG-11 runs x ∈ {0, 1}; Ev L2284–2285
  (E-S3.4): "the 10 ms floor raises it to 0.9600" (Iron/Hard, x = 1), so the margin over `PERFECT_30FPS_MIN_SCORE` 0.95
  is 0.010, from fewer runs than the slow case's 8,000. §14.6 says "at every tier"; the plan asserts MVP tiers only and
  reports placeholders (§16.21's "every MVP tier" supports that, but it is a reading).
- Fix: cite 0.9600 at x = 1, expect the slow case's minimum near the bound, treat a failure as a finding; name the
  "every tier" reading in [9.2].

### 10. The `%` / `//` ban contradicts §6.3's text and is not listed as a deviation (Low)

- Evidence: SPEC L1695–1696 (§6.3): "with `bit32` ops and integer `+ * %` below 2^53; u32 products via `mul32(a, b) =
  ((a >> 16)·b % 65536·65536 + (a & 0xFFFF)·b) % 2^32`". Plan L180–181: "per §6.4's whitelist, **no `%` and no `//`**";
  Plan L188–190: a new `Source.spec` failing on `%` and `//`.
- Problem: behaviour is identical (Luau's `a % b` is `a − floor(a/b)·b`, exact here), but the plan reads §6.4 against the
  more specific §6.3, invents a meta rule S8 does not have, and lists neither in [9.2] nor [12].
- Fix: either keep `%` in `Rng` as §6.3 writes it and scope `Source.spec` to the other files, or keep the ban and add an
  I-item plus §6.3/§6.4/§14.4 edits to [12].

### 11. §17.2's V-08 names S3 and is missing (Low)

- Evidence: SPEC L4878 (§17.2 S8 row): "**V-08** releases while the Esc menu is open reach the game and `MenuOpened`
  fires on Esc (S3, S6)". Plan: no mention. T-MG-16 and `Input.release()` assume the event fires.
- Fix: list V-08 in [7] as M8's (S-E2E-12: "Esc during HoldZone then release recorded"), with the Recorder's fallback if
  it does not fire (InputCapture's per-frame `IsKeyDown` / `IsMouseButtonPressed` reconciliation calls
  `button(false)`), and in M4-notes.

### 12. `Cheats.new(Minigames, MinigameFamilies)` cannot build its own `exact` and `fast` (Low)

- Evidence: Plan L946–957. `exact` needs PrecisionTrace's `pacerArc`/`pointAt` and Bots' Perfect HoldZone controller
  (E-S8.5 "Exact (Perfect timeline, unquantized)"); neither is in the facade or the `FamilyModule` type. `fast` needs
  `EARLY_TOL_MS` (S5's, not in `Definitions/Network` yet), which `tests/lib` may not require.
- Fix: `Cheats.new({ Minigames, Bots, PrecisionTrace, MinigameFamilies, earlyTolMs })`, or build `exact` from
  `Bots.play(spec, pattern, "Perfect", …)` with D7 clocks.

### 13. T-MG-10's trace TP asserts a flag no evidence shows (Low)

- Evidence: Plan L850: "on the pacer every 20 ms → 100 % (`PtTooPrecise`, also `PtTooSmooth`)". `out/checks.txt` and
  E-S3.8 say only "perfect … flagged 100%"; §10.6 promises the catch through the HIGH flag.
- Fix: assert `PtTooPrecise` at 100 % and report the `PtTooSmooth` rate (curvature of the bumps plus 1/16384
  quantization can put mean |Δ²p| near 0.0002 on Hard patterns).

### 14. Statistics the plan states that do not hold as written (Low)

- T-MG-04 cell means (Plan L895): the "≈ 6e-5 per cell, ≈ 3e-3 in all" odds model the shipped first 400 runs (a subset
  of the 2,000), but T-MG-04 draws fresh `configSalt` seeds, so the difference's SD is SE₄₀₀·√(1 + 400/2000) ≈ 1.10 SE₄₀₀
  and the 4 SE + 0.0005 band is ≈ 3.7 σ: ≈ 2e-4 per cell, ≈ 1 % over 48 cells.
- Q8 extension cost (Plan L896, "+ 16 s"): 24 cells (Average and Good) × 600 extra runs is ≈ 37 s (PrecisionTrace 8 ×
  600 × 6.5 ms = 31 s); 16 s is Average alone.
- O4 (Plan L1145 "fails PrecisionTrace for certain") vs Plan L898 ("PT ≈ 0.7"): fresh seeds give a new sample; ≈ 0.7 is
  the consistent figure.
- Two plan-made readings are not listed with G6 and G10: T-MG-04's band width (§14.8 names the table, no width), and
  FP "per human profile" (§14.8 L4031, §16.32 L4780) run on E-S3.8's four device configurations, so Poor is never run.
  Fix: list both in [9.2]/[12]; for the second, either add Poor@30 (≈ 36 s) or record the reading.

### 15. [12] omits SPEC edits for the plan's own deviations (Low)

- Missing: G8's grouping (§6.8 `F·(10/fireDecayMs)`, §6.10 `ceil(L/pacerSpeed·1000/20)·20`); the `%`/`//` source rule
  (§14.4, finding 10); the new fixture module `tests/fixtures/Edges.luau` (§14.7 lists the fixture modules); T-MG-04's
  band; §4.8's `edge = analysis.edge` vs the narrow table (G13, only in M4-notes); §6.11 (finding 5); §6.10's view
  additions (finding 3); the first trace record (finding 4b).

### 16. Misattributions and small inaccuracies (Very low)

- Plan L1012: "M3-notes: S-PAR-02 gains '50 judged bot runs per family'" is Ev L3541 (E-S8.6); M3-notes hold no M4 item.
- Plan L242 and G13: §17.2's S1 row (SPEC L4847) is about `StepRecord` against `StepFacts`/`StepRun`, not `EdgeProfile`
  against `PrepareInput.edge`.
- Plan L1036–1038 (R6): Studio and Lune are separate programs, not "the same Windows process"; nothing says their libm
  agree (M2-notes already warned that `Reference.spec` relies on Lune's libm). Keep the fallback, drop the reasoning.
- Plan L1114: S6 reading `TimingStrike.TS_OFFSET_OFFER_MIN_JUDGED` directly bypasses §6.2's "the only API S5 and S6
  call" (SPEC L1647); re-export it from the facade.
- Plan L547: the profiles are "§6.12's table, verbatim" plus the hold policy's `hzBand`, `hzMinGapMs`, `hzMinHoldMs`
  (prototype `Bots.luau` L114–129), which §6.12 does not list.
- `PrepareInput` (Plan L211–213): `gripPoint: { number }` where §6.2 writes `Vec3` (`DT.Vec3` exists).

### 17. A §6.8 claim no test pins (Very low)

- SPEC L1771: "holding alone scores 0" (Q15's reason for strokes). No planned case holds one press through the step or
  runs the `hold` policy (E-S3.2 variants: "hold-only policy scores 0.000"). Fix: one `HoldZone.spec` case.

## Checked and consistent

- T-RNG-01's vectors (Plan L744–762): every value re-derived independently from §6.3 in Python (my own implementation,
  not the planner's script): FNV-1a of the 7 strings, the 5 `mul32` cases, both `hashU32` cases, raw xoshiro from
  (1, 2, 3, 4), and the 6 seeded streams' states, u32s and floats all match; E-S3.1's 17-digit floats equal the plan's
  shortest forms.
- §6 line by line: the API, types, FlagIds, InvalidReasons, decode order, the three families' pseudo-code, parameter
  tables, views and feedback kinds, §6.12's profile values (every cell against `Bots.PROFILES`), §6.13, §6.14's breakdown
  keys: all carried, except the items above.
- `Definitions/MinigameFamilies` equals §6.8–§6.10, §16.12 and the prototype's `Params.luau` value for value; `Tol` holds
  every §16.32 row M4 needs; §16.19–§16.23 constants match the prototype's names and values (27 PrecisionTrace names).
- Every prototype function (Rng, Params, HoldZone, TimingStrike, PrecisionTrace, Timeline, Bots, Sim, Blades) maps to a
  module in [4.1]; the [4.2] pins match the prototype's expressions.
- M3 seam: `Analyze` re-exports at L57–61, `MassProps.difficultyFrame` returns `{0, 1}` (L554–562), `EdgeProfile`'s
  fields; M5 (`StepView.durationMs` = `StepSpec.durationMs`, SPEC §9.4), M7 (`SessionMachine.submit`, §7.7–§7.8,
  `Cheats.fast`'s bound) and §18's row (no Studio scenario for M4) as the plan says.
- The shipped distributions are the final run's (HoldZone Iron/Normal Average 5.3 % fail = `out/final_table.txt`, the
  post-Volume-change run), so score parity is a fair target once finding 4 is handled. E-S8.5's T-RNG/T-MG ids, §14.8's
  cheats, §17.1 O4/O6, §17.2's S3 and S5 rows and the M1-notes items are all covered.

Scratch: `C:\Users\louis\AppData\Local\Temp\claude\C--Users-louis-Documents-RANDOM-ROBLOX\93ae48b4-72b9-4dc1-aa5d-451af1abf9a0\scratchpad\m4-plan-critic-a\`
(`NOTES.md`, `rngcheck.py`).
