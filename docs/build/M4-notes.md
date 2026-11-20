# M4 build notes

Open items and deviations reported while building M4 (minigames: `src/shared/Minigames/*` with the facade and `Bots`,
T-RNG and T-MG), by its four builders, one after another. The plan is `.build-notes/m4-plan/plan-r2.md`; the lead's
decisions on it, `lead-decisions.md` (L1–L11), take precedence over it. M4 is built in a detached git worktree of
`f7ac37d` while the whole-design shift fix is reviewed in the main tree (L1): where the plan and the code or SPEC at
`f7ac37d` disagree, the code and the SPEC win, and the difference is recorded here. SPEC.md, SPEC-evidence.md and
README.md stay untouched in the worktree; their edits are in `docs/build/M4-handoff.md`, which the lead applies after
the shift fix's commit. Read the part for your step before building it. The items are point-in-time, so check them
against the code and SPEC.md; strike what is done.

## Baseline (before builder 1)

- The worktree at `f7ac37d` (M0–M3), `git status` clean. The main tree holds the shift fix, uncommitted and under
  review; nothing of it is in the worktree, and the worktree's Physics is `f7ac37d`'s (L1).
- L1 baseline, `lune run tests/run -- --quick` in the untouched worktree: 707 pass, 42 skip, 62 files.
  - 17:32, no other Lune process, the machine 59–90 % busy (median 68): 55.34 s wall, 53.99 s by the runner.
  - 19:09, the shift fix's two reviewers' Lune processes running beside it, the machine 23–60 % busy (median 44):
    41.26 s wall, 40.48 s by the runner.
  - Both far over the 30 s gate from load alone (§14.1 records 25.9 s quiet), so every timing below is an indication,
    with its load, until the lead's quiet runs (L2). M4's share is timed as the `--filter "Minigames/"` run alone.
- The load is sampled every 3 s by `Win32_Processor.LoadPercentage` beside each timed run (builder 1's
  `m4-b1/timed.sh`, later `m4-b1/work/bounded.py`, and `load.ps1` in the session scratch folder), reported as min–max
  (median).

## B1 The runner tier (L5), Types, Rng, Params, Checks and D3

**What was built**

- L5's runner tier. `tests/lib/Test.luau`: `t.volume` (a slow case, so `--quick` skips it and its budget is
  `SLOW_CASE_BUDGET_MS`). `tests/run.luau`: `--volume`; a plain run skips each `t.volume` case and prints
  `  SKIP  <suite › case> (t.volume: run with -- --volume)`; `--list` tags it `[volume]`; `--quick --volume` is a
  harness error (exit 2); the `--seed` message names a missing `--volume`. `scripts/verify.luau`: `--quick` or
  `--volume` passed through to its tests stage, both together exit 2, `VERIFY GREEN (--volume)`. The cases later
  slices tag `t.volume` (L5: T-MG-10's false-positive runs, T-MG-03, T-MG-06, T-MG-12) do not exist yet.
- The self-test's recursion guard (after the incident below). `Test.SELFTEST_CHILD = "BLACKSMITH_SELFTEST_CHILD"`
  and `Test.SELFTEST_SPEC = "Meta/Runner.spec.luau"`. `tests/Meta/Runner.spec.luau` sets the variable on every process
  it spawns and spawns nothing when it carries it; `tests/run` under it refuses (exit 2, before loading a spec) a
  root whose specs include a `.../Meta/Runner.spec.luau`, so `tests/`, `tests/Meta` and any parent; `scripts/verify`
  under it runs no stage and exits 2 naming the command its tests stage would run (the first check after its
  arguments, before the repo-root check). Every runner the self-test spawns names a root under
  `tools/runner-selftest/`, the exit-2 cases included; verify takes no root, so it is spawned from `tools/`, where a
  verify that lost its guard (or a child that lost the variable) stops at the repo-root check. The last three cases
  of the runner part test the three guards: in-process (the variable set, `runner()` must refuse), on the `holder`
  root (a stand-in `Meta/Runner.spec.luau`: exit 2 there; a broken check runs its one case and exits 0), and on
  verify (`--quick` and `--volume` each named, plus a lexical check that stage 4 spawns that same `testArgs`).
- New self-test roots: `volume`, `bless` (the `--bless` probe's golden moved here from `--root tests/Meta --filter`),
  `nospec` (specs only under `lib/` and `studio/`, which discovery skips), `holder`; rows in `tools/README.md`.
- `src/shared/Minigames/Types.luau`: §6.2's types, the three views (with `credit` and `coveredRuns`, G14) and the
  Recorder with `horizonMs` and `since` (D4); S2's `Vec2`, `EdgeChain`, `FactorValue` as structural copies (D5). It
  returns `table.freeze({})`.
- `Rng.luau` as the plan's [3.2]: every `%` of §6.3 is `mod(x, m) = x − floor(x/m)·m` (I6); `hashU32` (moved from the
  prototype's HoldZone), `TAGS`, `fromState`; seeds and words that are not u32 integers are refused.
- `Params.luau` as [3.3]: `resolve`, `explain` (base, `mMaterial`, `mTier`, `mDesign`, `final`), `resolveDef`,
  `refFactors`; the prototype's expression order (D1). `Checks.luau` as [3.5]: `mean`, `sampleSd` (two passes),
  `maxInWindow` (two pointers), `value`, `level`, `anyHigh`, `sorted`.
- D3: `PT_SMOOTH_DT_MIN_MS` 10 and `PT_SMOOTH_DT_MAX_MS` 40 in PrecisionTrace's `checks`, after `PT_SMOOTH_MIN_MOVE`;
  T-DEF-05's list and a min < max check in `tests/Definitions/MinigameFamilies.spec.luau`; the fingerprint re-blessed
  as [5.3] says (golden deleted, then `-- --bless --filter "Definitions/BalanceGuard"`; `git status tests/golden`
  shows the fingerprint alone).
- Tests: `tests/Minigames/Rng.spec` (T-RNG-01…06), `Source.spec` (§6.4's whitelist with 20 planted violations and a
  clean sample, P-PURE with every module deep-frozen, the folder holds §1.2's modules only), `Properties.spec` (the
  Rng, Params and Checks rows), `Params.spec` (T-MG-07, P-ORDER, the S3 prototype's `resolve` bit for bit, x beyond
  [0, 1] included), `Checks.spec` (the prototype's TimingStrike variance bit for bit, `maxInWindow` against brute
  force, levels, order).

**Measured** (each a single Lune process; the load is the machine's, the other team's reviewers running beside it)

- Rng against the v2 prototype (`m4-b1/work/rngcheck.luau`, 0.96 s): 3,000 streams × 64 draws of every method, 0
  differences; 20,000 `mul32` and `fmix32` pairs, 0. χ² as `Rng.spec` computes them, each equal to critic B's
  precompute: T-RNG-04's 20 streams highest 30.87 (seed 0xC0FFEE, "TimingStrike.Tempo"); `int(1, 16)` at seed 1 22.50
  / 9.41 / 9.24 / 12.15 / 7.62 (tags "", HoldZone, Tempo, Offsets, Perturb); the fast cases 15.74 / 16.37; T-RNG-06's
  32 cases highest 28.20 (seeds 1000 and 1001, "PrecisionTrace.Perturb").
- Slice checks, 18 Nov 20:10–20:11: `--filter "Minigames/Rng"` (χ² included) 11 pass, 1.00 s by the runner (1.81 s
  wall, 51 % busy); `--filter "Minigames/Params"` 10 pass, 0.04 s; `--filter "Minigames/Checks"` 6 pass, under
  0.01 s; `--filter "Definitions/"` 149 pass, 1.76 s (2.52 s wall, 65 %).
- M4's L1 share, `--quick --filter "Minigames/"`: after slice 1 (19:19–19:21) 14 and 16 pass, 2 skip, 0.04–0.05 s
  by the runner, about 1.0 s wall, 59–66 % busy; after slice 2, 34 pass, 2 skip, 0.15 s by the runner, 0.90–0.95 s
  wall (Lune's start and the load of all 67 specs included), three runs at 36–68 % busy (20:11).
- `Meta/Runner` with `--quick`: 22 pass, 1.09–1.11 s by the runner (1.83–1.85 s wall, 54–67 %). Per case, in one
  process: f7ac37d's spec 1,215 ms, this one 1,219 ms (63 %), so the tier and the guard cost L1 nothing net: 9 more
  child runners, while the `--bless` children load one spec instead of `tests/Meta`'s.
- Lune 0.8.9: `process.spawn` with an `env` option costs about 85 ms more per child (median 33 → 119 ms over 6
  children each, 70 % busy, `m4-b1/work/spawncost.luau`); the spec therefore sets its variables in its own process
  around each spawn (the children inherit them) and restores them after. With the option, `Meta/Runner` took 3.8–4.0 s.
- The fingerprint: `{bytes=13372, fnv1a32=3275947958, version=1}` (was `{bytes=13286, fnv1a32=162842818,
  version=1}`). The 86 bytes are the two rows' canonical text with their `[6]=` and `[7]=` keys (2 × 42) and one digit
  more for each of the two rows now at `[10]` and `[11]`.
- `lune run scripts/verify -- --quick` at the end of builder 1 (20:22, 17–62 % busy, median 31, three of the
  reviewers' Lune processes running): exit 0, `VERIFY GREEN (--quick) (50.9 s)`; T-META-07 150 files, 1,037
  requires; luau-lsp A and B 0 errors; `RESULT pass=746 fail=0 skip=44 files=67 time=43.99s` (the baseline's 707 /
  42 / 62 plus Minigames' 34 cases and 2 slow ones, and `Meta/Runner`'s 5 new cases).
- Mutation checks (`m4-b1/work/mutate2.py`), on a copy of the worktree without `.git`, each run of
  `--quick --filter <suite>` bounded at 120 s in a job object: 40 mutants of `Rng`, `Types`, `Params`, `Checks`,
  `MinigameFamilies`, `tests/run`, `Test`, `Runner.spec` and `verify` (among them each guard switched off, the guard
  after verify's repo-root check, the variable not passed or not restored, `SELFTEST_SPEC` renamed, the volume skip,
  list tag and refusal off, the pass-through broken). 39 caught at once; one survived (`Params`' x clamp: the planted
  row's design clamp hid it, so `Params.spec` now uses a row whose clamp cannot, and compares x beyond [0, 1] with the
  prototype), then caught. None hung, none left a process, and the copy equalled the worktree after.
- Re-checked on 19 Nov after the usage pause, on top of builder 2's slices 3 and 4 (01:39–01:41, no other Lune
  process running, the machine 5–48 % busy): the files above as I left them, but for builder 2's planned additions
  (`Properties.spec`'s family rows, `Tol.PROP_N_FAST`, the Definitions spec reading `TS_PERFECT_CORE_MIN_MS` from
  `TimingStrike`). The 40 mutants re-run on a new `.git`-free copy of the worktree: 40 caught, none hung, none left a
  process, the copy equal to the worktree after (59 s in all). `--quick --filter "Minigames/"`: 58 pass, 5 skip,
  0.37–0.41 s by the runner (1.09–1.13 s wall). `lune run scripts/verify -- --quick`, 5–26 % busy (median 10): exit 0,
  `VERIFY GREEN (--quick) (35.3 s)`; T-META-07 154 files, 1,074 requires; luau-lsp A and B 0 errors;
  `RESULT pass=770 fail=0 skip=47 files=69 time=29.35s`.

**The incident (18 Nov, 19:31–19:43)**

- My first mutation script edited the worktree in place. A mutant that switched off the `--quick --volume` refusal
  made `Runner.spec`'s rootless case `--volume --quick` run the whole quick suite in a child, whose `Runner.spec` did
  the same: 41 nested runs, one every 9 s from 19:32:48, the machine at 85 %, until the lead stopped it (19:39:07).
  Two more runs, started by a second copy of me working at the same time, recursed the same way, because each stop
  left its mutant in `tests/run.luau`; the lead stopped them at 19:41:55 and 19:42:46. The worktree was restored
  (three lines of `tests/run.luau`) and checked file by file. The shift fix's reviewers set aside their timings from
  19:32 to 19:43.
- What changed: the guard above, every runner spawn rooted, and mutation runs only on a `.git`-free copy, each run
  bounded (a 120 s timeout killing the tree by its own PID, a job object whose process list must be empty after each
  mutant, a state file naming the mutant in flight).

**Open issues**

- ~~For builder 2 (slice 3): T-MG-07's "TimingStrike's core ≥ 9 ms on every tier × material × x" needs
  `TS_PERFECT_CORE_MIN_MS`, so it is `TimingStrike.spec`'s, not `Params.spec`'s~~ (done in slice 3). ~~[5.2]: line 31 of
  `tests/Definitions/MinigameFamilies.spec.luau` still hard-codes `PT_TRAVEL_MAX_MS` until slice 5 exports it
  (`TS_PERFECT_CORE_MIN_MS` is read from `TimingStrike` since slice 3).~~ (done in slice 5: both are read from their
  modules).
- For later builders: `Source.spec`'s `MODULES` is §1.2's list; a new file in `src/shared/Minigames/` fails it, and
  every authoritative one is checked against §6.4's whitelist from the moment it exists. `Properties.spec` ran its
  first rows (Rng, Params, Checks) at `PROP_N` in the quick run (0.15 s for slices 1–2); `PROP_N_FAST` is in
  `tests/lib/Tol` since slice 4, the other D10 rows are not yet (slices 7–9).
- For the Input builder (slice 7): `Types` already declares the Recorder with `horizonMs` and `since` (D4) and the
  views with `credit` and `coveredRuns` (G14); the SPEC edits for them (§6.2, §12.5, §6.10, the plan's [12]) are not in
  the handoff yet, and belong with the slices that build their behaviour. (Builder 2: §6.10's view, with `credit`,
  `coveredRuns` and `runningScore`, is in the handoff since slice 5; §6.2 and §12.5 stay slice 7's.) (Builder 3: §6.2,
  §6.4 rule 7, §6.6 and §12.5 are in the handoff since slice 7.)
- For the lead: after the shift fix's commit, if it changed any Definitions the fingerprint hashes, re-bless once more
  after applying M4 (M4's own change is the two rows above). The handoff's §14.3, §14.4 and §16.12 edits carry the
  guard, the whitelist and D3.
- Not done, by the rules of this build: the optional Studio snippet of the plan's [7] (T-RNG-01's vectors in a Play
  session).
- Spawning in tests: set environment variables in the process around `process.spawn`, not through its `env` option
  (85 ms per child, above). Processes started through the shell (PowerShell's `Start-Process`) leave a job object;
  `process.spawn` children stay in it.

**Deviations from the SPEC and the plan**

- §6.3's `%` is written `mod(x, m) = x − floor(x/m)·m` (I6): the same values; the handoff rewrites §6.3 and §6.4.
- The step's brief cites §4.1's list (`sqrt/floor/ceil/abs/min/max`, without `round` and `clamp`); the Minigames
  modules keep §6.4 rule 2, which lists `round` and `clamp`: §6.5's `round_q(clamp(…))` and the prototype parity (D1)
  need `math.round` itself (`floor(x + 0.5)` differs, at 0.49999999999999994 for one). `Source.spec` allows `floor`,
  `ceil`, `round`, `abs`, `min`, `max`, `clamp`, `sqrt` and `huge`.
- T-RNG-01's vectors are E-S3.1's, not E-S8.5's `kat/` (I1); T-RNG-03 and 05 as the plan reads them (G12); T-RNG-06
  takes lag-1 pairs non-overlapping and so has 32 cases: the plan's "37" counts critic B's run, which also had the 5
  overlapping pairs. Its highest χ² is 28.20 either way.
- Files beyond L1's list, all for L5 and the guard: `tests/lib/Test.luau` (`t.volume`, the guard's two constants),
  `tools/runner-selftest/{volume, bless, nospec, holder}/` and `tools/README.md`'s rows.
- T-META-05's earlier cases changed for the guard: the argument faults run on the pass root, `--root scripts` became
  the `nospec` root, `--root ../outside` became `tools/runner-selftest/pass/../pass` (the same refusal of `..`), the
  working-directory case names `runner-selftest/pass`, and the `--bless` probe runs the `bless` root.
- The runner's guard refuses a root that holds the self-test, found by its spec's path, rather than the root
  `tests` by name: the refusal can then be tested on a small root, and it also covers `tests/Meta` and any parent.

## B2 The three families: TimingStrike, HoldZone, PrecisionTrace (slices 3–5)

**What was built**

- `src/shared/Minigames/TimingStrike.luau` (slice 3, 18 Nov): the plan's [3.8], every expression the v2 prototype's
  (D1). `generate`, `hash`, `points`, `grade`, `bandMs`, `judgeErrors` (the one path `finish` and `checks` share),
  the session (`push` = a press, `advance`, `finish` with §6.14's breakdown), `checks` (thresholds from Definitions),
  `view` on the raw clock (D12) and feedback; `TS_PERFECT_CORE_MIN_MS`, `TS_GRADE_PERFECT`, `TS_GRADE_GOOD` and
  `TS_OFFSET_OFFER_MIN_JUDGED` exported. The combo (O13) and the live score (O14) as L4 says, each marked
  **[Decision to confirm]** in the header.
- `src/shared/Minigames/HoldZone.luau` (slice 4, 18 Nov): the plan's [3.7]; the session keeps the prototype's field
  names (`T`, `F`, `pressT`, `credit`, `n`, `inZone`, `strokes`, `events`, `ei`, `k`) and its forward key pointer
  (`seg`), and an optional `hist = { T, C }` that `advance` fills per tick (the bots' perception, tests); `centerAt` is
  the stateless lookup. The live score (O14) is marked as above.
- `src/shared/Minigames/PrecisionTrace.luau` (slice 5, 19 Nov): the plan's [3.9]. §16.22's 27 constants are exported
  (`PT_FALLBACK_EDGE` as deep-frozen sides, grip point and axis; the grid stride `NCU` 64 stays private). Then
  `sidesFromChains`, `edgeToPanel`, `edgeToPanelInfo` (the source and how it was fitted: E, shrink steps,
  Douglas–Peucker attempts and tolerance, lengths, or the reason there is none), `fallbackSource` (no memo),
  `generate`, `hash`, `pacerArc`, `pointAt`, `nearest`, the session, `measures` (the four checks' measures in sample
  order: mean deviation, mean jerk, teleports and samples in travel, with their counts), `checks` over it, `view` (with
  `credit`, `coveredRuns` and `runningScore`) and feedback. The Douglas–Peucker tolerance is doubled per attempt (no
  `^`), every generic `for` is over `ipairs`, and `//` is `math.floor(/)`. `advance(S, now)` evaluates ticks only up to
  the latest pushed sample's time (§6.4 rule 7); `finish` evaluates the rest.
- `Minigames/Types`: `PrecisionTraceView` gains `runningScore` (deviation 2 below).
- `tests/fixtures/Edges.luau` (slice 5): the nine reference edges of the prototype's `Blades.luau` in its order, each
  `{ name, chains = { { points, length } }, gripPoint = { 0, 0.88, 0 }, gripAxis }`, and `order`. A one-off Lune script
  (`m4-b2/work/genedges.luau`) pasted them as Luau's shortest round-trip literals (`tostring`, each checked to read back
  to the same double). The table is deep-frozen with `Build.freeze`. In `tests/fixtures/Cost.luau`, `X08_EDGE =
  Edges.zigzag` (one source), and its header line says so.
- Tests:
  - `tests/Minigames/TimingStrike.spec`, 13 cases: FamilyModule typing, E-S3.4's golden and grade bands, M = T_1 for an
    early first target, points and grades, a press decides once, the checks at their thresholds, core ≥ 9 ms at every
    tier × material × x, the dial on the raw clock, feedback and D13's shared array, the combo and the live score,
    live = replay, the prototype bit for bit.
  - `HoldZone.spec`, 11 fast and 2 slow cases: E-S3.7's golden and 300 ms taps, the stroke curves, holding alone scores
    0, the pointer = `centerAt` per tick, `hist` changes no result, `HzInhumanRate` at 29 / 30 presses, feedback, the
    view and the live score from the first tick, live = replay, the prototype's session sums bit for bit.
  - `PrecisionTrace.spec`, 14 fast and 2 slow cases: §16.22's constants and `Edges` against the prototype, E-S3.5's
    golden and all nine blade rows, the edge hand-off's bounds, the worst source at the length bound, the travel clamp,
    the tick rules on a straight path, each flag at its threshold (PtTooSmooth's dt 9 / 10 / 40 / 41 included), the view,
    feedback, live = replay, the prototype bit for bit.
  - `Properties.spec`: rows for the three families and the edge hand-off. The trace rows and HoldZone's take
    `PROP_N_FAST` cases in the quick run and `PROP_N` under `t.slow` (`sized`); `Tol.PROP_N_FAST` = 25 is D10's row.
  - `tests/Definitions/MinigameFamilies.spec` reads `TS_PERFECT_CORE_MIN_MS` (slice 3) and `PT_TRAVEL_MAX_MS` (slice 5)
    from their modules ([5.2]).

**Measured** (each a single Lune process; the load is the machine's, with the shift fix's reviewers running beside it
at times)

- E-S3.5, reproduced exactly:
  - the arming golden: sides of 3 and 4 points, the six source points, 337 path points, L 3.3526, travel 11180 ms,
    duration 12180 ms, speed 0.2999, hash 0xF0B5CD03; the fallback's 402 points, L 4.0083, 13380 ms, 0x405C00EA; the
    tilted grip's identical source;
  - all nine rows of its blade table (sides, source points, E, tolerance, path points, L, travel Normal / Hard);
  - for every blade, the source, the path arrays and the hash equal the prototype's bit for bit
    (`m4-b2/work/ptprobe.luau`, 19 Nov 01:58, 9 % busy).
- Slice ends, `--quick --filter "Minigames/"`, three runs each:
  - slice 3 (18 Nov 20:41): 47 pass, 2 skip, 0.31–0.39 s by the runner, 1.00–1.11 s wall, 18–24 % busy;
  - slice 4 (20:49): 58 pass, 5 skip, 0.36–0.37 s, 1.05–1.09 s, 16–22 %;
  - slice 5 (19 Nov 02:18): 74 pass, 9 skip, 0.71–0.72 s by the runner, 1.47–1.49 s wall, 14–21 % busy, no other Lune
    process.
- Slice 5's fast cases, in one process (02:17, 11 % busy): `PrecisionTrace.spec` 208 ms (the prototype parity 84 ms,
  live = replay 65 ms) and `Properties.spec` 285 ms (the trace session row 113 ms, the hand-off row 18 ms). Two trims
  brought them down from 877 ms:
  - raw test sources are random walks of at most 12 points: sources anywhere in the panel made 27 u paths whose
    `generate` took up to 25 ms (`m4-b2/work/ptcost2.luau`);
  - big tables go through a check that builds no string, and only a mismatch calls `A.deepEq` for its message
    (`A.deepEq` builds a path string and sorts keys for every element).
- Filtered runs with `t.slow`: `Minigames/PrecisionTrace` 16 pass, 1.47 s by the runner (8 % busy);
  `Minigames/Properties` 11 pass, 1.79 s (30 %); `Definitions/MinigameFamilies` 14 pass; `Minigames/Source` 5 pass.
  luau-lsp passes A and B: 0 errors, after `rojo sourcemap` of both projects (a planted error is reported).
- Mutation checks (`m4-b2/work/mutate_b2.py`) under the SAFETY rules: a `.git`-free copy, one Lune process at a time,
  each mutant's `--quick --filter <suite>` bounded at 120 s in a job object. 85 mutants of the three families, `Edges`
  and `Cost.X08_EDGE`:
  - the first pass caught 76 of 84. The five real gaps got cases: a blade 1 stud wide (the only case where the
    cross-axis clamp binds); 301 points that fit the length bound and are still simplified; an early first target (M =
    T_1); `hist` changes no result; the live score at the first ticks. The 250 ms gap rules gained their exact
    boundaries;
  - the final pass (19 Nov 02:28–02:30): 82 of 85 caught, none hung, no process left behind, and the copy equal to the
    worktree afterwards.
  - The 3 not caught, and why: HoldZone's `F − F·10/fireDecayMs` grouping (finding 3: caught by plain L3 only); the key
    pointer with `<` at a key's exact time (`c0 + (c1 − c0)·1` is exactly `c1`, since the centres lie within a factor of
    2 and the subtraction is exact); a ×1.5 on the trace view's `coverage`, run against `Properties` alone (its row
    checks ranges; the family spec pins the value and catches it).
- `lune run scripts/verify -- --quick` at the end of builder 2 (19 Nov 02:37, 37–63 % busy, median 49, three to five of
  the shift fix team's Lune processes running): exit 0, `VERIFY GREEN (--quick) (47.1 s)`; T-META-07 157 files, 1,099
  requires; luau-lsp A and B 0 errors, no lint warning; `RESULT pass=788 fail=0 skip=51 files=70 time=39.42s` (builder
  1's 770 / 47 / 69 plus 18 fast cases, 4 slow ones and `PrecisionTrace.spec`). Over 35 s from the load alone: an
  indication until the lead's quiet runs (L2); builder 1's nearly quiet run was 29.35 s at slices 0–4, and slice 5 adds
  about 0.35 s quiet.

**Findings**

1. luau-lsp 1.70.1 under `--!strict` accepts each family module (a wider table) as `Types.FamilyModule<P, R, S, V>`,
   and refuses it with a wrong record type R (checked in slice 3). Width subtyping works in this case, which bears on
   G13 and §17.2's S1 row (`StepRecord`).
2. A HoldZone down after the last tick's start (t > durationMs − 10) is never integrated, in the prototype too. No
   scored tick could read it, so no score changes.
3. §6.8's `F·10/fireDecayMs` and the prototype's `F·(10/fireDecayMs)` (D1, G8) differ in the last bit for 0.10 % of
   uniformly random F at `fireDecayMs` 600, the only value the data gives (no tier, material or design column), 1.0 % at
   300 and 1.8 % at 550; `m4-b2/work/groupcheck.luau`'s float LCG keeps about 23 fraction bits, which is why it saw none
   at 600. The regrouping fails plain L3 (HoldZone's slow parity property; `Minigames/Reference`'s HoldZone sums,
   Iron/Normal Elite run 55), not the quick run: the pin matters at the shipped value. (Corrected in fix round 1, from
   reviewer V2.)
4. The trace's cross-axis clamp `E = min(2, 0.76/(s·range c))` never binds on E-S3.5's nine blades (the widest are
   0.6 stud across: 0.76/0.36 = 2.11). Only a test blade 1 stud wide exercises it.
5. `generate` on a source the hand-off did not bound takes up to 25 ms (30 random points across the panel, L 27 u),
   against about 1 ms for the reference edges. The hand-off's length bound (0.95 · 30 s · pacerSpeed) is what keeps
   `prepare` inside its budget. Clients never send a source (the server makes it), so nothing is exposed; T-PERF-02
   must time sources the hand-off bounded, as the plan's [6.8] has it.

**Open issues**

- For the next builders:
  - ~~`Timeline` (slice 6) reads `PrecisionTrace.PT_PANEL_ASPECT` and `PT_FIXED_POINT` (U_MAX = 49152, V_MAX = 16384).~~
    (done in slice 6)
  - ~~The facade (slice 7) maps an edge with `PrecisionTrace.edgeToPanel(PrecisionTrace.sidesFromChains(edge.chains,
    edge.gripPoint, edge.gripAxis), edge.gripPoint, edge.gripAxis, params.pacerSpeed)`.~~ (done in slice 7)
  - ~~`Bots` (slice 8): the trace bot has `pacerArc`, `pointAt`, `PT_FIXED_POINT` (the prototype's `PT.Q`),
    `PT_PANEL_ASPECT` (`PT.PANEL_W`) and `PT_EVAL_MS`. HoldZone's perception is `S.hist = { T = {}, C = {} }`, which
    `advance` fills per tick and which changes no result.~~ (done in slice 8)
  - ~~T-MG-10 (slice 9) reads each run's trace mean deviation and mean jerk from `PrecisionTrace.measures`.~~ (done:
    `FalsePositives.spec`, builder 4)
  - T-PERF-02 (slice 10) generates on `Cost.X08_EDGE`, an edge with its grip (`{ name, chains, gripPoint, gripAxis }`).
- M4's L1 share is 0.71–0.72 s after slice 5 (nearly quiet), which leaves about 2.3 s of the 3 s for slices 6–8.
- For the lead:
  - O13 (the combo) and O14 (the live score) carry **[Decision to confirm]** in the three family modules' headers, and
    the handoff adds their §17.1 rows.
  - The `Edges` provenance check compares the sabre, flamberge and tilted edges through this machine's libm (`^`, sin
    and cos in the prototype's `Blades.luau`). If it fails after a Windows update, the cause is the libm, not the code.
- Not done, by this build's rules: the optional Studio snippet of the plan's [7].

**Deviations from the SPEC and the plan**

1. TimingStrike's `push` returns the `Miss` of each span its press closes, before its `Strike` or `Whiff`. The plan's
   [3.8] lists `Miss` under `advance` only, but a press does close spans, and the host should hear them. A `Miss` is
   stamped `T_i + M`, and `End` `T_N + M`.
2. `PrecisionTraceView` gains `runningScore`. §12.2's Playing screen shows a live score for every step and O14 defines
   the trace's (the plan's [9.1]), but neither §6.10's view nor the plan's [3.1] has the field. It is the score's
   formula on the ticks so far, with the coverage counted over the bins the pacer has passed, so it ends equal to the
   score.
3. `edgeToPanelInfo` and `measures` are exported. The plan keeps the diagnostics private, but tests can only reach
   exported functions, and T-MG-10 needs the measures: the prototype's `checks` returned them as a second value, while
   a `FamilyModule.checks` returns flags only.
4. `Cost.X08_EDGE` is the whole zigzag edge with its grip, not a bare `EdgeChain`: generating from it needs the grip.
5. The plan's "17-digit literals" are Luau's shortest round-trip literals (at most 17 significant digits).
6. The fixture check (`Edges` against `Blades`) lives in `PrecisionTrace.spec`, because `tests/FixtureSet/` is outside
   L1's file list.
7. `generate` raises an error if the fallback edge does not fit the travel bound, which needs a pacer under about
   0.14 u/s (the MVP's is 0.30 or more); there the prototype would fail on a nil index. Its inputs are server-made.
8. The path's P-RANGE ([0.05, 2.95] × [0.05, 0.95] in the plan's [6.7]) holds before quantization. After
   `round(·16384)` the bounds are 819–48333 by 819–15565, in units of 1/16384 (0.04999 to 2.95001).
9. The feedback the SPEC names but does not define (G7) is built as follows. The trace's `OnPath` / `OffPath` fire on
   grinding ticks only (off before the first); `PaceWarn` only on ticks on the band, where pace is scored; `Coverage`
   at the tick that reaches each quarter; `End` at `leadInMs + travelMs`; `GrindStart` / `GrindStop` from `push` (not
   grinding before the first sample). The trace has no `Go` (§6.10 lists none). HoldZone's and TimingStrike's are as in
   the plan's [3.7] and [3.8]. The handoff states all three in §6.8–§6.10.

## B3 The wire format, the Recorder and the facade (slices 6–7), L6

**What was built**

- `src/shared/Minigames/Timeline.luau` (slice 6): §6.7's codec as the plan's [3.4], one codec per family in a frozen
  table (`increasing`, `time`, `check`, `write`, `read`: the Phase 2 hook). `decode` is total on any value and refuses
  in §6.7's order, first failure wins; D8's oversize buffer reads `TooMany` in that slot, before the record loop, so it
  costs O(1). `encode` refuses every record `decode` would refuse (a count past `MAX_RECORDS`, a time that goes back,
  passes `durationMs` or jumps more than 65,535 ms, a HoldZone state that does not alternate from down, a trace time
  that does not increase, a point off the panel, a non-boolean flag), so an encoded timeline always decodes to the same
  records: a Recorder bug stops the client's submit instead of costing the player a strike. `capBytes(family)`;
  `U_MAX` 49152 and `V_MAX` 16384 are derived from `PrecisionTrace`'s `PT_PANEL_ASPECT` and `PT_FIXED_POINT`.
- `src/shared/Minigames/Input.luau` (slice 7): the Recorder of the plan's [3.6] with D4's `horizonMs` and `since`, D7's
  stamps, D9 and G5. The stamps are §6.6's: a button at its frame's centre, floored at 0, then TimingStrike's offset,
  floored at 0, then never before the last record or the horizon; a trace sample at its frame. HoldZone records the
  OR-state's changes (no new press once `MAX_RECORDS − 1` are recorded); TimingStrike records presses (an up → down
  change; a key held through GO is no press); the trace records the cursor at GO (t = 0, I7) and then one sample at the
  first frame at or after each due time (the next multiple of `PT_EVAL_MS` after the last record), its u, v rounded to
  1/16384 and clamped to the panel (NaN reads 0). `release()` records HoldZone's up at the latest known time (the last
  record's or the horizon) and lets TimingStrike's next press count. Records past `durationMs` are dropped, records are
  frozen when made, and `records()` is a frozen copy; `since` hands out one shared empty array when nothing is new.
- `src/shared/Minigames/Minigames.luau` (slice 7): the facade of the plan's [3.10]: `prepare`, `start`, `judge`,
  `replay`, `encode`, `get`, the `TS_OFFSET_OFFER_MIN_JUDGED` re-export, and `recordCap(spec)` for L6. `prepare`
  freezes the spec, its params and its source, and drops the source when the pattern plays the fallback. `judge`:
  decode, then L6's cap (`TooMany`), then the hash, then `replay` (push all, finish, checks sorted, the HIGH clamp).
- L6, the trace's record cap, adopted after its proof (below): `judge` refuses a PrecisionTrace timeline of more than
  `floor(durationMs / PT_EVAL_MS) + 1` records as `TooMany`, an O(1) check after decode and before the hash.
- `tests/lib/Cheats.luau` (slices 6–7): `Cheats.new({ Timeline, MinigameFamilies, Minigames?, Bots? })` with
  `reasons`, `malformed`, `flood`, `replay`, `garbageBuffers`, `fast`, `forged` and `exact` (deviations 4–6).
  `tests/lib/Tol.luau`: `FUZZ_N_STRUCT_FAST` 200 (D10).
- `tests/Minigames/MinigamesHelpers.luau`: `stepInputFrom` (§4.8's `Pipeline.stepInput` with the narrow edge, G13; typed
  from `Analyze`'s exports, so luau-lsp checks D5's structural copies against S2's types: it accepts them), `inputFor`,
  `prepared`, `configSalt`, the scripted timelines (`presses`, `taps`, `onPacer`), random honest records
  (`randomRecords`), and S6's host loop as a driver: `frames` (frame times with a random phase, jitter and hitches) and
  `play(spec, pattern, opts)`, which feeds the frame's inputs to a Recorder (InputCapture's logical OR-state included:
  after a focus loss a held button counts only through a new press), pushes `since`, advances to `horizonMs`, views,
  and at GO + durationMs records the inputs since the last frame, pushes once more and finishes. Its `rawClock` and
  `skipFinalPush` options are the two negatives (D4's raw frame time; no final push). The E-S3.2 table (slice 9's
  T-MG-04) is not in it yet.
- Tests:
  - `tests/Minigames/Timeline.spec` (11 fast, 2 slow): the wire constants and caps; one hand-written byte golden per
    family on E-S3.4's, E-S3.5's and E-S3.7's patterns (header and three records, the hex written by hand from §6.7);
    round trips at the format's extremes (dt 65,535, t = durationMs, the panel's edges, `MAX_RECORDS`); encode's
    refusals; T-MG-08's decode level: every planted timeline reads exactly its reason in every family it can occur
    in, the first failure wins (each header pair, record order, the order inside a record), flood (D8), garbage values
    and structured buffers.
  - `Input.spec` (16 fast, 2 slow): stamps; D7 (the 372 integers ≤ 60,000 whose t/1000 falls short, and a 7th of the
    rest); the Recorder's stamps against the S3 prototype's `Bots.stamp` and `ptHuman`'s sampling rule on random
    frames (12 runs, 30–240 fps), which slice 8's bots rely on; T-MG-15's stamps and offsets (TimingStrike's alone)
    and the unquantized Exact presses (every error −offset: `TsLowVariance` at every offset, `TsExactHits` at 0);
    T-MG-16; each family's records and caps; the horizon; D4's reason (below); `records` and `since`; the host loop
    finishing as the judge on random frames, offsets, focus losses and inputs after the last frame, with the live score
    ending at the score (O14) in all three families; the final push; L6's proof as a property.
  - `Minigames.spec` (13 fast, 2 slow): `get` and the re-export; T-MG-01 (every config × 4 seeds: prepare twice, a
    complete frozen StepSpec, start, judge twice; no edge, an edge with no usable side, and the rounding-bound edge
    below play the fallback with no source; the input's balance version); the edge hand-off on all nine reference
    blades (the tilted grip gives arming's source); desyncs (seed + 1, a moved source point, a nudged generation
    parameter; a nudged scoring parameter does not); T-MG-02's pass line (6 of 12 → 0.5000 passed; 5 and one 0.9851 →
    0.4988 failed), every malformed, flooded and replayed timeline Invalid and scored 0, and random honest records;
    T-MG-08's judge level; the Replay cheat; L6's cap in `judge`; T-MG-14 on scripted presses; `encode`, `fast` and
    `forged`; and F5's and C02's steps from `Analyze.run` prepared, started and judged through a Recorder, asserting
    no Physics value (L1).
  - `Properties.spec`: rows for `Timeline` (P-DET, P-NOMUT, P-RANGE, P-TOTAL), the facade (prepare, start, replay,
    judge, encode on random configs, the placeholder tiers and other materials included), `judge`'s P-TOTAL, and the
    Recorder (the same calls give the same records; times, panel and caps).

**L6: the proof that no Recorder makes more than floor(durationMs / PT_EVAL_MS) + 1 trace records**

- By construction: calls before `go` record nothing and `go` records once, at t = 0, setting the due time to 20. After
  that a `cursor` call records only at a time t with t ≥ due, t > the last record's t and t ≤ durationMs, and then sets
  due to the smallest multiple of 20 above t. So every record after the first lies in a later 20 ms slot `floor(t/20)`
  than the one before, starting at slot 1, and no slot past `floor(durationMs/20)` can hold one: at most
  `floor(durationMs/20) + 1` records in all, whatever the frames, clocks, hitches, focus losses or button calls
  (`button` and `release` record nothing for the trace). The bound does not depend on the clock being monotonic.
- As a property (`Input.spec`, `PROP_N_FAST` cases in the quick run and `PROP_N` under `t.slow`): every MVP tier's
  longest step (`leadInMs` + `PT_TRAVEL_MAX_MS` + `tailMs` = 31,000 ms at Iron and Steel, Normal and Hard, x 0 and 1:
  1,551 records) and random durations, frame times 1–100 ms with a random phase and ±1 ms jitter, hitches up to 250 ms,
  focus losses, button changes and horizon calls at random; every output is within the bound, holds the slot invariant
  and decodes; and on real reference-blade steps at 1–3 ms frames `judge` returns Ok. `Properties.spec`'s Recorder row
  checks the bound on random call scripts too.
- Slice 8's bots drive every record through the Recorder (D7), so their timelines are within it by construction; the
  plan's "every bot timeline of slice 8" is then `Bots.spec` judging each one Ok (builder 4).
- The rule changes T-PERF-02's trace case: the 2,048-sample decode-cap timeline is now refused as `TooMany` after decode,
  so the longest timeline `judge` replays is the honest maximum (L6's "the decode-cap trace is the honest maximum"). The
  cap bounds the count, not the cost: the same count spread over travel, every sample grinding, costs about 2 % more
  than the honest timeline (fix round 1 below), and T-PERF-02 times that arrangement.

**Measured** (each a single Lune process; the load is the machine's, the other team's processes running at times)

- Slice 6's end (19 Nov 03:00, 3 other Lune processes): `--filter "Minigames/Timeline"` 13 pass (slow included),
  0.61 s by the runner (37 % busy); `Minigames/Source` 5 pass; `--quick --filter "Minigames/"` three runs: 86 pass,
  12 skip, 0.85–0.92 s by the runner, 1.65–3.35 s wall, 37–54 % busy.
- Slice 7's end (03:17, no other Lune process): `--filter "Minigames/"` with `t.slow`: 136 pass, 7.30 s by the runner,
  2–10 % busy. `--quick --filter "Minigames/"` three runs: 118 pass, 18 skip, 1.15–1.18 s by the runner, 1.93–1.94 s
  wall, 12–23 % busy. After the mutation pass's four cases (03:23): 119 pass, 18 skip, 1.56 s at 71 % busy with 4–5
  other Lune processes (an indication only).
- Fast cases in one process (`m4-b3/work/casetimes.luau`, one load sample each): `Timeline.spec` 60.6 ms (02:58,
  17 % busy); `Input.spec` 78.6 ms (03:10, 33 %); `Minigames.spec` 264.3 ms (03:13, 10 %; T-MG-01 136 ms of it, and
  the judge's fuzz case 72 ms before it shared its garbage values across the families); `Properties.spec` 491.1 ms
  (03:16, 2 %), 171 ms of it the Recorder row at `PROP_N`, which now runs `PROP_N_FAST` (25 of 200 cases) in the quick
  run. The four files as finished, at 60 % busy with 6 other Lune processes (03:28): 97.9 / 164.5 / 401.0 / 675.0 ms.
- luau-lsp passes A and B: 0 errors and no lint warning (`m4-b3/lsp.sh`: both `rojo sourcemap` lines, then verify's
  two `luau-lsp analyze` passes).
- As finished (03:33, 48–71 % busy, 6–8 of the other team's Lune processes running): `--quick --filter "Minigames/"`
  three runs, 119 pass, 18 skip, 1.52–1.61 s by the runner (2.51–2.67 s wall); the nearly quiet figure is slice 7's
  1.15–1.18 s above, four small cases ago.
- `lune run scripts/verify -- --quick` at the end of builder 3 (03:32, 38–72 % busy, median 57, six to eight of the
  other team's Lune processes running): exit 0, `VERIFY GREEN (--quick) (53.2 s)`; T-META-07 165 files, 1,205
  requires; luau-lsp A and B 0 errors; `RESULT pass=831 fail=0 skip=60 files=73 time=44.67s` (builder 2's 788 / 51 /
  70 plus 43 fast and 9 slow cases in `Timeline.spec`, `Input.spec`, `Minigames.spec` and `Properties.spec`). Again
  after the last edits (comment and line rewraps; 03:36, 45–85 % busy, median 66, nine of the other team's Lune
  processes): exit 0, `VERIFY GREEN (--quick) (55.7 s)`, `RESULT pass=831 fail=0 skip=60 files=73 time=46.40s`; and
  `--filter "Minigames/"` with `t.slow` 137 pass, 10.67 s by the runner (57–74 %). Over 35 s from the load alone: an
  indication until the lead's quiet runs (L2).
- Mutation checks (`m4-b3/work/mutate_b3.py`) under the SAFETY rules: a `.git`-free copy (`m4-b3/mutwt`), one Lune
  process at a time, each mutant's `--quick --filter <suite>` bounded at 120 s in a job object. 75 mutants of
  `Timeline`, `Input`, the facade and `Cheats` (decode's order and checks; a header layout and a flag bit changed alike
  in encode and decode, which only the byte goldens see; encode's refusals; the stamps, the offset, the caps, the
  horizon, the due times; L6's cap, after the hash or off by one; the clamp; the edge hand-off):
  - the first pass (03:20:40–03:22:19) caught 68 of 75. Four cases closed the real gaps: TimingStrike's floor at 0
    before the offset (a press whose frame's centre falls before GO, at offset −120: 120, not 114); `go`'s grind flag
    over `held`; the spec's balance version is the input's; and the rounding-bound edge (finding 1);
  - the final pass (03:24:28–03:26:10): 72 of 75 caught, none hung, no process left behind, no state file, and the
    copy equal to the worktree afterwards.
  - The 3 not caught are equivalent: (a) the floor at 0 after the offset (every stamp also passes `max(…, last t,
    horizon)`, and both start at 0); (b) "no new press at `MAX_RECORDS − 1`" against "at `MAX_RECORDS`" (a HoldZone
    press only comes at an even count, and 1,024 is even); (c) the grip point in `sidesFromChains` (the split is the
    argmax along the axis, which a translation cannot move).

**Findings**

1. The hand-off's length bound is checked before the 1/16384 rounding and `generate`'s after it. The 2-point chain
   (0, 0.88) → (0.005740714073181153, 1.5465725111961365) maps to 0.4000028 u, so `edgeToPanel` returns the source
   {21300, 8136, 27852, 8248}, which is 0.39996 u long, so `generate` plays the fallback (`m4-b3/work/fallbackprobe.luau`
   found it near the bound). Client and server agree either way (`start` reruns `generate` on the same source);
   `prepare` drops such a source, so the spec says what plays. No score moves; §6.10 could say it (the handoff does).
2. D4's reason, pinned on E-S3.4's pattern (`Input.spec`): with `timingOffsetMs` +120, a press physically at T₁ + M +
   15 = 704 ms is recorded at 579 (its frame's centre 699, less 120), an error of +90 inside W. A host advancing to the
   raw frame time closes span 1 as a Miss at the frame before (694 > 689) and then hears the press as a whiff, so the
   client's score falls short of the server's; advancing to the horizon (569 at that frame) judges it as the replay.
3. The final push matters (`Input.spec`): a press 12 ms before the end of a 30 fps HoldZone step, after the last frame,
   is stamped before the last tick (which reads it) and after the last horizon, so only the push before `finish` shows
   it to the client's session (its stroke count differs without it).
4. `Network.EARLY_TOL_MS` (250) exists at `f7ac37d`; the plan's [6.6] says it is not in Definitions yet. `Cheats.fast`
   still takes it from the caller (`tests/lib` requires nothing in `src/`), and `Minigames.spec` passes Network's.
5. luau-lsp: a local that takes a `FamilyId` field without an annotation (`local family = spec.family`) widens the
   singleton union to `string` and then fails where a `FamilyId` is expected; annotate it. A generic `for` over a
   `FamilyId` array widens the same way (M1's lesson, on locals).

**Open issues**

- For builder 4 (slices 8–10):
  - The Recorder's API is `Types.Recorder`; the trace's `go` needs the cursor (u, v). Exact-time bots pass
    `clockS = (tMs + 0.5) / 1000` and `frameDtS = 0` (D7). The trace bot on its first frame passes one drawn position to
    `go` and to `cursor` (the Recorder records the second only when floor(f₁) ≥ 20, [3.11]). HoldZone's bot advances
    its own session to `rec:horizonMs(f / 1000, dt / 1000)` after the frame's button calls.
  - `Input.spec` already checks the Recorder's stamps against the prototype's `Bots.stamp` and `ptHuman`'s due rule.
  - `MinigamesHelpers.play` and `frames` are S6's host loop for T-MG-09 (b); `rawClock` is T-MG-09 (c)'s negative
    (`Input.spec` pins the scripted case).
  - ~~`Cheats.exact(spec, pattern)` returns `Bots.play(spec, pattern, "Exact", 0)`'s records once `Cheats.new` is given
    `Bots`; untested until then.~~ (done in slice 8: `Minigames.spec` and `FalsePositives.spec`)
  - ~~L6: `Bots.spec`'s "decode accepts every bot timeline" should judge each one (`Minigames.judge`, status Ok), so the
    trace cap is checked on every bot timeline.~~ (done in slice 8)
  - T-PERF-02's trace case: the 2,048-sample timeline is refused after decode (`TooMany`); time the cap of the
    length-bound pattern (`Minigames.recordCap(spec)` records, 1,479, floor(29,560/20) + 1), spread over travel (fix
    round 1), for the replay, and decode alone of the 2,048-sample buffer for the refusal.
  - ~~The E-S3.2 table for T-MG-04 is not in `MinigamesHelpers` yet.~~ (done in slice 8: `MinigamesHelpers.ES32`)
- For the lead: L6 is adopted, with the SPEC edits in the handoff (§6.6 Caps, §6.7, §10.5, §17.2 S5). The quick share
  after slices 6–7 is about 1.2 s nearly quiet (12–23 % busy), leaving about 1.8 s of the 3 s for slice 8.
- Kept in `m4-b3/` for re-runs (the lead can delete them after the M4 commit): `mutwt` (a `.git`-free copy equal to the
  worktree at 03:26), `work/mutate_b3.py`, `work/fallbackprobe.luau`, `work/casetimes.luau`, `work/bounded.py`,
  `run.sh`, `lsp.sh`, `out/` (every run's output and load samples).

**Deviations from the SPEC and the plan**

1. `Input` requires `PrecisionTrace` (for `PT_FIXED_POINT`, `PT_PANEL_ASPECT` and `PT_EVAL_MS`) and the facade
   `Timeline`, beyond the plan's [3.12] (`Input` → Definitions and Types); no literal copies (D2), and no cycle.
2. `encode` refuses every record decode would refuse, not only a dt out of range or a field off its range (the plan's
   [3.4]); `Timeline` also exports `U_MAX` and `V_MAX`.
3. The facade exports `recordCap(spec)` (not in §6.2): the cap `judge` applies (L6), for `Cheats.flood` and T-PERF-02.
4. `Cheats.new` takes `Timeline` (the codec) as well as `MinigameFamilies`, `Minigames` (optional: `flood`'s judge-cap
   timeline) and `Bots` (optional: `exact`), where the plan's [6.6] passes `Minigames`, `Bots` and `MinigameFamilies`:
   the decode-level cheats need only the codec, and slice 6 comes before the facade.
5. `Cheats.malformed(spec, reason)` returns every planted value for the reason (each decodes to exactly it; M7 takes
   the first), not one buffer; `flood` returns `{ overCount, overLength, overCap }`; `garbageBuffers(rng, spec,
   records, n)` takes a spec (for the header) and honest records (for the byte flips), where the plan wrote `(rng,
   family, n)`; `replay`'s stale timeline has its duration rewritten to the other spec's so that the hash refuses it
   (otherwise a TimingStrike or trace step of another duration reads `Duration`, which `Minigames.spec` also checks).
6. `Cheats.fast` and `forged`, which the plan's [6.6] lists but no slice builds, are built here (`fast`'s timeline
   judges Ok; `forged` has its shape); `exact` is written and errors without `Bots`.
7. Decoded records are not frozen (judge's hot path); the Recorder's are.
8. The Recorder's `go` refuses a trace with no cursor (a caller bug); `cursor` is a no-op for the other families and
   `button` and `release` record nothing for the trace; `Input.new` refuses a timing offset that is not an integer
   (§9.3: the sanitized setting is one).
9. The trace's next due time is computed in closed form, (floor(t/20) + 1)·20, which equals the prototype bot's
   `while due <= t do due += 20 end` for the multiples of 20 it starts from.
10. T-MG-09's bot cases stay slice 8's; slice 7 adds the scripted host loop (random frames, offsets, focus losses,
    inputs after the last frame), D4's negative and the final-push negative in `Input.spec`.
11. The integration case (F5, C02) runs now, at `f7ac37d`'s Physics, and asserts no Physics value (L1), not the plan's
    `usedFallback = 0`.

## B4 The bots, the frozen timelines, Reference and the L3 statistics (slice 8), L9's precomputes

Builder 4 started on 19 Nov at 03:39, was cut off at about 04:11 and resumed at 06:34 from its notes
(`m4-b4/NOTES.md` in the session scratch folder). The earlier builders' claims were checked first: the worktree's
quick `Minigames/` run was green (134 pass, 0 fail), `Cheats.exact` errors without `Bots` and is `Bots.play`'s Exact
with it, `judge` applies L6's cap, and the Recorder's API is `Types.Recorder` as builder 3 wrote.

**What was built**

- `src/shared/Minigames/Bots.luau` (not authoritative, §6.4): §6.12's four profiles with the S3 prototype's policy
  fields (`hzBand`, `hzMinGapMs`, `hzMinHoldMs`, `panelPx`), `variant`, `play`, `run`, `autoplaySource`, `stats`,
  `seedOf` and §16.23's constants. `play(spec, pattern, who, seed, opts?)` takes a profile (the human model), "Perfect",
  "Exact" or "Idle"; `opts` carries `offsetMs` (the Recorder's `timingOffsetMs`), `policy` (HoldZone's "pump", the
  default, or "hold"), `fps` (TimingStrike Perfect's device, 60) and the trace Perfect's `noise` and `everyMs` (T-MG-10's
  cheats). The policies are the prototype's (`tsHuman`, `tsPerfect`, `hzHuman`, `hzPerfect`, `ptHuman`, `ptPerfect`),
  with its Rng tags and its draw order, so the build reproduces its scores (Reference below). What changed on the way:
  - every record goes through `Input`'s Recorder (§6.2), so a bot's timeline is one an unmodified client could send,
    and it is within the judge's caps (L6) by construction. Bots that act at an exact integer ms (every Exact,
    HoldZone's Perfect, the trace's Perfect) pass `clockS = (t + 0.5)/1000` and `frameDtS = 0` (D7);
  - HoldZone's human pushes the Recorder's new records into its own live session and advances it to
    `rec:horizonMs(f/1000, dt/1000)` each frame (its perception reads `S.hist`), which is the prototype's
    `clamp(stamp(frames, k), 0, durationMs)`;
  - the trace's human draws its tremor only on the frames where a sample is due (the Recorder's rule, the prototype's
    `nextDue`), and on its first frame passes one drawn position to `go` and to `cursor` ([3.11]);
  - HoldZone's Perfect computes the zone centre per tick once per pattern (the same values the prototype recomputes
    for each look-ahead step);
  - `run(cell)` is the prototype's `Sim.run` through `Minigames.prepare` and `Minigames.replay`, the trace on `cell.edge`
    (no blade data in `src`), and returns the raw scores (the prototype's never clamp), `passed` and `flagged`;
    `cell.each(i, spec, pattern, records, result)` sees every run. Box–Muller and the OU step carry
    `-- allow-transcendental: player model noise (§6.12)`; `seedOf` and the seed reduction use `%`, allowed outside
    §6.4 (`Source.spec` skips `Bots`).
- `tests/fixtures/MinigameTimelines.luau` (D14): 24 frozen bot timelines, one per family × tier × profile (Iron, the
  tier's `BOT_REF_X`, the trace on `Edges.arming`, HoldZone pumping, offset 0), each run 1 of its cell of the shipped
  `S3-score-distributions.luau` (pattern seed `Bots.seedOf(1, 1)`, bot seed 7967), as lowercase hex, with `hex` and
  `bytes`. Made once by `m4-b4/work/gentimelines.luau` (19 Nov 04:04), which checked each judges Ok at its cell's first
  shipped score: 32,187 bytes of timelines (HoldZone 246–354 B, TimingStrike 36–44 B, the trace 2,301–4,261 B), a
  74,256-byte file.
- `tests/golden/minigames.bv1.golden.txt`, golden (b): blessed once (04:08) with
  `lune run tests/run -- --bless --filter "Minigames/Minigames"` (21 pass, the slow T-MG-09 included, 15.94 s by the
  runner); 25,406 bytes, one canonical line: 144 pattern rows (every config × seeds 1, 2, 0xDEADBEEF, 2^32 − 1, each
  with `durationMs`, `patternHash` and the family's shape), 12 scripted results and the 24 frozen timelines' results.
  `git status --short tests/golden` shows the fingerprint (builder 1's) and this file alone. Reviewed
  (`m4-b4/work/review_golden.luau`): seed 1 Iron/Normal x = 0 carries E-S3.7's 0x4E2677F2 (10 keys), E-S3.5's
  0xF0B5CD03 (337 points, L 3.3525733639359867, 12,180 ms) and E-S3.4's 0xE2D4F2AE (N 12, M 200, W 110, core 13.2,
  10,971 ms); E-S3.4's presses 0.8084 (8 perfect, 1 good, 2 ok, 1 miss, best combo 6); the 300 ms taps 0.0000; the
  exact presses 1.0000 clamped to 0.5000 with both TimingStrike flags; the trace on the pacer 1.0000 clamped, flagged
  `PtTooPrecise` and `PtTooSmooth`; every frozen bot row Ok, unflagged, at its cell's first shipped score.
- Tests:
  - `tests/Minigames/Bots.spec` (8 fast, 2 slow): the profiles against §6.12's table and the prototype's fields;
    `seedOf` = `Sim.seedOf`; variants; every bot timeline honest (encoded and decoded back, within decode's cap and the
    judge's L6 cap, judged Ok, the client's `finish` = the judge's `rawScore`) for every player (the four profiles,
    Elite@240, Average@30/360, Perfect, Exact, Idle; the quick case gives the trace two of its six human players) on
    both tiers, plus the hold policy and offsets ±120 (slow: every player, both materials, ten seeds); P-DET; Perfect,
    Exact and Idle (below); T-MG-11 fast (50 runs per cell) and slow (1,000),
    each cell's lowest run equal to its precompute; `autoplaySource`; `stats` = the prototype's; D14's frozen
    timelines byte for byte; the libm canary (`fnv1a32` over `%.17g` of `math.log`, `cos` and `exp` at 1,000 draws and
    the 8 OU exponents: 572967914).
  - `Reference.spec` (6 slow, plain L3): parity, E-S3.2's table, full precision (below).
  - `Minigames.spec`: `Cheats.exact` = Bots' Exact; T-MG-02 with bots (every profile, Idle and Exact on Steel/Hard);
    T-MG-14 with bots (HoldZone's exact-state Perfect clamped at the line, `clientScore` = `rawScore`); T-MG-09 fast
    (20 / 30 / 6 runs) and slow (1,000 per family, printing E-S3.6's byte sizes); golden (b).
  - `Input.spec`: T-MG-15 with bots, fast (20 runs per profile and offset) and slow (1,000).
  - `Properties.spec`: the Bots row (P-DET of `play` and `run`, P-FINITE and P-RANGE of their results).
  - `Statistics.spec` and `FalsePositives.spec`: slice 9's L3 cases, written now so that L5's volume tags and the
    pinned outcomes exist; the lead runs them quiet (L2). `Statistics`: T-MG-06 (a) fast (every Steel column as tight as
    Iron's at every MVP tier and x); T-MG-04 with its Q8 fail rates and T-MG-05, one case per family (plain L3);
    T-MG-03, T-MG-06 (b) and T-MG-12, one case per family (`t.volume`). `FalsePositives`: T-MG-10's false positives
    (`t.volume`: TimingStrike per device and tier, HoldZone, the trace's two halves and its other devices) and its
    true positives and known limits, one case per family (plain L3). Every outcome is pinned at the printed precision
    of its precompute, and each case prints its figures (E-S3.10's).
  - `MinigamesHelpers.ES32`: E-S3.2's table (mean and SD per cell), which T-MG-04's bands read.
- `tests/lib/Tol.luau`: D10's rows `BOT_RUNS_FAIL` 1000, `TP_RUNS` 2000, `PERFECT_HZ_RUN_MIN_SCORE` 0.85,
  `FAIRNESS_SEEDS` 100, `FAIRNESS_BOT_RUNS` 20, `STEEL_DROP_RUNS` {TimingStrike 20000, HoldZone 4000, PrecisionTrace
  4000}, and `STEEL_MEAN_DROP` {0.005, 0.08} with O4's **[Decision to confirm]** (L3).

**L6 on every bot timeline.** Every timeline a bot makes is judged Ok within `Minigames.recordCap(spec)`: in
`Bots.spec` every player on both tiers (and both materials and ten seeds slow), in `Reference` the 4,800 parity runs, in
T-MG-09 the 3,000 slow runs and their replays on another device. The trace's Perfect (one sample per 20 ms from GO to
`durationMs`) makes exactly the cap, `floor(durationMs/20) + 1` records (a trace step's duration is a multiple of 20).

**Perfect, Exact and Idle** (`Bots.spec`, one pattern each): TimingStrike's Perfect@60 scores 1 unflagged; Exact errs
by 0 on every span (−60 at offset +60), is flagged `TsExactHits` and `TsLowVariance`, rawScore 1, score clamped to 0.5,
passed. HoldZone's Exact is its Perfect (no randomness): `HzInhumanRate` alone, far from the record cap, clamped,
passed. The trace's Exact is its Perfect: exactly the judge's cap, rawScore 1, `PtTooPrecise` among its flags, clamped;
every 200 ms on the pacer reads `{PtSparse, PtTooPrecise}`; 0.004 u of noise is not too precise and scores ≥ 0.9.
Idle records nothing (not even GO's cursor) and scores 0 in every family (the trace's Idle reads `PtSparse`).

**Reference** (`Reference.spec`, plain L3; 19 Nov 04:09, its first 5 cases, 19.22 s by the runner at 11–51 % busy,
median 31; the sixth, E-S3.2's table, added at 06:50, passes in the plain L3 run below):
- Parity: `Bots.run` with the prototype's seeds (salt 1, i = 1…100) gives the first 100 scores of each of the 48 cells
  of `docs/spec/prototypes/S3/v2/out/S3-score-distributions.luau` exactly: 4,800 of 4,800. Each of those timelines is
  judged Ok within L6's cap, `judge` = `replay`, and the prototype's own session fed the same records ends on the
  build's unquantized sums (HoldZone credit, n and in-zone ticks; TimingStrike each span's error and Σ points; the
  trace's accuracy and pace sums and covered bins). A first check of 48 × 20 (`m4-b4/work/parity.luau`, 03:51, 54 %
  busy) had 0 mismatches.
- E-S3.2's table as `MinigamesHelpers.ES32` copies it is the distributions' mean and SD per cell at 3 decimals.
- Full precision (D1): resolved params for 3 families × 2 materials × 5 tiers × x ∈ {0, 0.1, 0.3, 1}, and the pattern
  arrays (HoldZone keys; TimingStrike cycles, M, W, core; the trace's `pu`, `pv`, `arc`, L, speed, travel and
  fallback; durations and hashes) for seeds 1…20 per family, tier and material, equal the prototype's to the bit.
- With parity, every fixed-seed L3 outcome of the build is the prototype's (D11): the precomputes below.

**The build's per-run costs through the Recorder** (`m4-b4/work/costs.luau`, 19 Nov 03:54, `Bots.run` = prepare,
`Bots.play` through the Recorder, replay and checks; 44–66 % busy, median 57, so upper figures):
- HoldZone, pumping: 0.88–1.35 ms a run (Elite@30 0.90, Average@30 1.04, Elite@60 1.18, Good@60 1.29); its Perfect
  1.94 ms.
- TimingStrike: 0.12–0.28 ms (Elite@240 0.61–0.62, Elite@60 and Good@60 0.19–0.20, Average@30 0.13–0.14); Perfect@60
  0.18, Perfect@30 0.12.
- PrecisionTrace on the arming sword: 7.4–8.9 ms (Elite@30/360 7.42, Elite@240/520 8.58); on the pacer 1.96 ms.
- Against the plan's prototype figures (TimingStrike 0.109–0.512 ms at 42–69 % busy, HoldZone ≈ 1, the trace ≈ 6.5),
  the Recorder, `prepare`, the checks and the sorted flags add about 15–30 %.

**D10's sizes and L5's volume tags.** The sizes stay D10's (above); the costs above put M4's plain L3 at about 3 to 3.5
minutes at this machine's load (T-MG-04 with Q8 ≈ 92 s, T-MG-09 slow ≈ 30 s, Reference ≈ 19 s, the rest ≈ 40 s), so with
the M2–M3 slow cases (≈ 5 minutes at M3's close) plain L3 stays inside 10 minutes quiet, and T-MG-04's Q8 extension
stays plain. `t.volume` (L5): T-MG-10's false positives, T-MG-03, T-MG-06 (b) and T-MG-12; T-MG-06 (a) is a fast case.
The volume part was estimated at 9–12 minutes at this load and measured 9.6 minutes at 3–27 % busy (below: T-MG-10's
TimingStrike 4.9, its trace 2.4, its HoldZone 0.3, T-MG-03, T-MG-06 (b) and T-MG-12 1.9).

**L9's precomputes on the S3 prototype**, with the pinned names (D11). Each ran as one bounded Lune process from the
worktree root (`m4-b4/run.sh` → `m4-b4/work/bounded.py`: a job object, a 290 s timeout, no process left), on copies of
the v2 prototype in `m4-b4/proto/` (`precompute.sh`, 19 Nov 03:57–04:02, 5–56 % busy, one other Lune process). Seeds as
`Sim.run`: pattern seeds `Sim.seedOf(i, fnv1a32(name))`, bot seeds `i·7919 + salt·31 + 17`.
- T-MG-03 (`lune run <m4-b4>/proto/pre_tmg03.luau <family> [<tier>]`; 33 s in all): the Perfect bot (TimingStrike at 60
  fps), 1,000 runs per cell, "T-MG-03 <family> <tier> <material>". HoldZone mean / lowest run: Normal Iron 0.985583 /
  0.9285, Normal Steel 0.987971 / 0.9176, Hard Iron 0.965925 / 0.8828, Hard Steel 0.969914 / 0.9147, every run
  flagged `HzInhumanRate`; TimingStrike every run 1.0000, none flagged; PrecisionTrace every run 1.0000, every run
  flagged (`PtTooPrecise`). So the means pass §14.6 (0.95 / 0.98) and the per-run floors (0.85 / 0.98) hold, the
  lowest HoldZone run 0.0328 above its floor.
- T-MG-11 slow (`pre_misc.luau 11`): TimingStrike Perfect@30, 1,000 runs per cell, "T-MG-11 <tier> <material> x=<x>"
  (x as %d). Lowest run (and over the first 50, the fast case): Normal Iron x=0 0.9897 (0.9913), x=1 0.9746 (0.9792);
  Normal Steel x=0 0.9858 (0.9858), x=1 0.9731 (0.9813); Hard Iron x=0 0.9671 (0.9774), x=1 0.9623 (0.9700); Hard
  Steel x=0 0.9684 (0.9749), x=1 0.9613 (0.9684). None under 0.95, none flagged; the thinnest margin 0.0113 (Hard
  Steel x = 1), where E-S3.4's 0.9600 was Iron/Hard's over fewer runs.
- T-MG-15 slow (`pre_misc.luau 15`): TimingStrike Iron/Normal at x = 0.10, "T-MG-15 <profile> <offset>" (Elite@240 or
  Good; offsets −120, −60, 0, 60, 120 as %d), 1,000 runs: 0 flagged in every one, the first 100 included. Means
  Elite@240 0.0126 / 0.4780 / 0.9358 / 0.7222 / 0.1761, Good 0.0285 / 0.3439 / 0.7945 / 0.7860 / 0.3253 (an offset
  shifts every press, which costs the score, never a flag).
- T-MG-10 TimingStrike (`pre_tmg10ts.luau <profile> <fps> <tier>`, 11 s to 62 s per half): "T-MG-10 TimingStrike
  <device> <tier>", 150,000 runs per half, Iron and Steel alternating by run, x = `BOT_REF_X[tier]`, offset 0. 0
  flagged in all eight halves (1.2 million runs). Smallest sample SD (flag < 1.5 ms) / largest share of |e| ≤ 1 ms
  (flag ≥ 0.90): Elite@240 Normal 2.78 / 0.500, Hard 4.24 / 0.400; Elite@60 3.37 / 0.364, 5.13 / 0.333; Good@60
  7.24 / 0.417, 8.93 / 0.333; Average@30 11.95 / 0.333, 16.75 / 0.308.
- T-MG-10 HoldZone (`pre_misc.luau hz`): "T-MG-10 HoldZone <device> <tier>", Elite@60, Elite@30, Good@60, Average@30 ×
  Normal, Hard, Iron, pumping, 2,500 runs each (`FP_RUNS` in all): 0 flagged; the most presses in any 1 s window 9, 9,
  8, 8, 8, 8, 7, 7 (≤ `HZ_RATE_MAX_PRESSES`/3 = 10).
- T-MG-10 the trace's other devices (`pre_misc.luau pt`): "T-MG-10 PrecisionTrace <device>", Elite@240/520,
  Elite@60/520, Good@60/520, 1,000 runs each, Iron, Normal and Hard alternating: 0 flagged; smallest mean deviation
  0.00284 (×3.55), 0.00296 (×3.70), 0.00543 (×6.78); smallest mean jerk 0.00382, 0.00454, 0.00535 (×19–27).
- From critic B (the plan's [6.3], not re-run): T-MG-04/05 (`t45`), T-MG-06 (`t6`), T-MG-12 (`fair`) and the trace's
  30 fps halves (`ptmargin`, `tail`). The build reproduces each (below).

**The build against the precomputes** (one Lune process each; the load is the machine's):
- Plain L3, `lune run tests/run -- --filter "Minigames/Statistics"` (06:47, 5–47 % busy, median 16): 4 pass, 9 volume
  cases listed as SKIP, 91.84 s by the runner. Every T-MG-04 mean and fail count equals critic B's `t45` (the worst
  mean at 0.67 of its band, TimingStrike; the smallest Q8 margin 2.3 points, HoldZone Iron/Normal Average 5.3 %
  against 3 %), and T-MG-05 holds (Average drops 0.068–0.098; the smallest other drop PrecisionTrace Steel Elite
  0.0052).
- `--filter "Minigames/FalsePositives › T-MG-10 TP"` (06:48, 18–20 %): 3 pass, 11.17 s. TimingStrike Exact flagged
  2,000 of 2,000 and clamped to 0.50; σ 4 ms noise flagged 2 of 2,000 (finding 1), mean 0.9999. The trace on the
  pacer `PtTooPrecise` 2,000 of 2,000 (and `PtTooSmooth` 2,000: reported, not asserted); every 200 ms `PtSparse` 2,000
  of 2,000; 0.004 u noise 0 flagged, mean 0.9856. HoldZone Perfect 100 of 100 (up to 50 presses in 1 s); the 30/s
  autoclicker 2,000 of 2,000.
- The volume cases once, as an indication of slice 9 (`m4-b4/volume.sh`, `--volume --filter` per group, 19 Nov
  06:48–): T-MG-03 3 pass, 13.88 s (8–18 % busy); T-MG-06 (b) 3 pass, 70.38 s (6–27 %): Iron − Steel 0.0153 / 0.0086 /
  0.0130 (HoldZone / TimingStrike / PrecisionTrace) inside [0.005, 0.08]; T-MG-12 3 pass, 29.12 s (3–21 %): SDs
  0.0463 / 0.0510, 0.0220 / 0.0213, 0.0246 / 0.0136 (Normal / Hard) against 0.08; T-MG-10 HoldZone 1 pass, 18.80 s
  (11–21 %): 0 of 20,000, most presses 9 / 9 / 8 / 8 / 8 / 8 / 7 / 7; T-MG-10 TimingStrike, both tiers per device, 0
  of 300,000 each and every smallest SD and largest exact share as precomputed: Elite@240 150.45 s (3–23 %), Elite@60
  53.88 s (6–25 %), Good@60 53.93 s (3–18 %), Average@30 37.78 s (3–20 %); T-MG-10 the trace 3 pass, 145.24 s (4–27 %):
  0 of 23,000, the halves' smallest mean deviation 0.00279 / 0.00259 u (×3.49 / ×3.24), 0.1 % quantile 0.00304 /
  0.00303 (×3.80 / ×3.79), smallest jerk 0.00409 / 0.00404, the other devices 0.00284 / 0.00296 / 0.00543 u. Each
  equals its precompute. The volume cases took 573.5 s in all (9.6 minutes) at 3–27 % busy, no other Lune process.
- The offset offer in the Recorder's terms, the plan's [6.3] T-MG-15 report (added in fix round 1: reviewer V1's
  `offset.luau`, re-run by the fixer with the same figures): Average Iron/Normal TimingStrike (x = 0.10, salt 1),
  2,000 runs through `Bots.run`, scores 0.6482 at offset 0 (the mean `meanErrMs` of the runs with ≥ 8 judged +33.5),
  0.7124 at +35 (−0.9) and 0.4790 at −35 (+67.1): the results card's offer `timingOffsetMs += round(meanErrMs)` moves
  the right way.

**Slice 8's checks at the end** (19 Nov, after the last edits; each one Lune process)

- luau-lsp passes A and B (`m4-b4/lsp.sh`: both `rojo sourcemap` lines, then verify's two `luau-lsp analyze` passes):
  0 errors, after typing the TimingStrike FP table's run counts as strings and the cell functions' locals.
- M4's L1 share, `lune run tests/run -- --quick --filter "Minigames/"`, three runs at 07:01: 135 pass, 56 skip,
  1.85 / 1.90 / 1.88 s by the runner (2.76–3.84 s wall), 17–32 % busy, no other Lune process. Earlier in slice 8: 2.13 s
  at 56 % with two other Lune processes (04:07), 2.02 s at 36 % with one (06:37). Under L5's 3 s, an indication until
  the lead's quiet runs.
- Plain L3 for M4 (L10), `lune run tests/run -- --filter "Minigames/"` (07:01–07:04): exit 0, `RESULT pass=170 fail=0
  skip=21 files=77 time=173.33s`, the 21 skips the `t.volume` cases, each listed; 6–76 % busy (median 49), the other
  team's Lune processes 0 at the start and 3 at the end. T-MG-09's slow case printed its timelines' bytes (min / mean
  / max over 1,000 runs, the players mixed with Perfect and both tiers): HoldZone 189 / 363 / 1,128 (the exact-state
  Perfect makes the long ones), TimingStrike 30 / 39 / 46, the trace 2,294 / 3,741 / 4,317 (E-S3.6, humans only: 198 /
  293 / 396, 34 / 39 / 48, 2,322 / 3,663 / 4,240).
- `lune run scripts/verify -- --quick` in the worktree (07:05, 31–67 % busy, median 49, three of the other team's
  Lune processes running): exit 0, `VERIFY GREEN (--quick) (45.3 s)`; T-META-07 171 files, 1,285 requires; luau-lsp A
  and B 0 errors; `RESULT pass=847 fail=0 skip=98 files=77 time=38.30s` (builder 3's 831 / 60 / 73 plus 16 fast cases,
  38 slow or volume ones and the four new specs). Over 35 s from the load alone: an indication until the lead's quiet
  runs (L2).
- `git status --short tests/golden`: the fingerprint (builder 1's) and `minigames.bv1.golden.txt` alone. No process of
  builder 4 is left running.

**Findings**

1. A careful TimingStrike cheater, every target plus N(0, 4 ms) (`FalsePositives`, "T-MG-10 TP TimingStrike noise
   4 ms"), is flagged in 2 of 2,000 runs, `TsLowVariance` alone, where E-S3.8 printed 0.0 % (`checks.luau`, 2,000 runs
   per tier on its own seeds). The rate is the chance that the errors drawn with σ ≈ 4 ms spread less than
   `TS_MIN_SD_MS` (1.5 ms): about 4 in 10,000 runs with Normal's 12 strikes (a χ² with 11 degrees of freedom under
   11 · (1.5/4)² = 1.55: 4.4·10⁻⁴) and 0.8 in 10,000 with Hard's 15 (7.6·10⁻⁵); with the tiers alternating, 2,000 runs
   expect 0.52 flags, and 2 or more come with probability 0.096, which both counts fit. Such a cheater is still accepted
   99.9 % of the time (Q17), and no honest run comes near: the smallest SD over the 1.2 million human runs is 2.78 ms
   (Elite@240, Normal). The case pins 2; the handoff corrects E-S3.8's wording.
2. The trace on the pacer every 20 ms is flagged `PtTooSmooth` as well as `PtTooPrecise`, in all 2,000 runs. The plan
   reported the first rather than asserting it (critic A 13); measured, it is 100 % too.
3. T-MG-11 holds on its pinned seeds with a thin but positive margin: the lowest Perfect@30 run over 8,000 is 0.9613
   (Hard Steel x = 1), 0.0113 above `PERFECT_30FPS_MIN_SCORE`.
4. T-MG-03's per-run floors hold: HoldZone Perfect's lowest run on its pinned seeds is 0.8828 (Hard Iron; the shipped
   2,000-run table's lowest is 0.8969), 0.033 above `PERFECT_HZ_RUN_MIN_SCORE`; TimingStrike@60 and the trace score 1
   on every run.
5. The libm canary is 572967914 on this machine (Windows 11, Lune 0.8.9's UCRT). If `Bots.spec`'s frozen-timeline case
   fails together with the canary, the C runtime changed, not the code (D14); golden (b) cannot move either way.

**Open issues**

- For the lead (slices 9–11, L2): the handoff's last section gives the commands and the expected outcome of each case.
  Slice 9's two specs exist and pin their outcomes; their volume cases ran once here (above), so slice 9 is their
  quiet re-run and the timings. Slice 10's `tests/Minigames/Perf.spec.luau` (T-PERF-02) is not written: the handoff
  says what it holds after L6. Slice 11 is the full `scripts/verify -- --volume` and the README's Status.
- For M5:
  - S-PAR-02's minigame lines: judge the Lune-made timelines of `tests/fixtures/MinigameTimelines` in both data models
    (D14; the plan's [7]): per entry, `name`, a tab and `Dump.canonical(Minigames.judge(spec, pattern,
    MinigameTimelines.bytes(e.hex), 0))`, the spec and pattern from `Minigames.prepare` of the entry's input (Iron,
    `Params.refFactors(e.x)`, `Edges.arming` for the trace). A live `Bots.play` line in Studio is reported only: the
    bots use libm (R6), the judge does not.
  - T-CR-09's 2,000 crafts per row: `Bots.run` per cell with salt 1 reproduces the shipped `S3-score-distributions.luau`
    (Reference checks the first 100 runs of every cell, D11 the rest), so either may feed it.
  - `Pipeline.stepInput` builds the narrow edge (G13); `MinigamesHelpers.stepInputFrom` is the mapping T-PIPE compares.
  - The integration case (F5, C02 from `Analyze.run`) ran on `f7ac37d`'s Physics; it runs again after the shift fix
    with no change (it asserts no Physics value).
- For M7:
  - The Recorder and the facade are the client's and the server's only seams (§6.2): `Input.new(spec,
    timingOffsetMs, goClock)`, `go`, `button`, `cursor`, `release`, `since`, `horizonMs`, `records`; `prepare`,
    `start`, `judge`, `replay`, `encode`, `get`, `recordCap`. Seeds from `SeedRng:NextInteger(0, 4294967295)` are
    valid `Rng.new` seeds; anything else is refused.
  - `judge`'s Studio budget (I8 with L6): the longest timeline it replays is the trace's honest maximum, 1,551 records
    at 31 s; the cap bounds the count, not the cost, and the same count spread over travel costs about 2 % more, so
    S-PERF-01 measures that arrangement; §10.5's 7 ms is the target; × 2.6 (20.8 ms) triggers §17.2's S5 fallback.
  - S-E2E-10's cheats from `tests/lib/Cheats` (`Cheats.new({ Timeline, MinigameFamilies, Minigames, Bots })`): `exact`
    (Bots' Exact: passes at the line, flagged), `fast` (its `earlyTolMs` from `Network.EARLY_TOL_MS`, 250), `flood`,
    `malformed`, `replay`, `forged`. S-E2E-05: `Bots.play(spec, pattern, Bots.PROFILES.Good, seed)` in the client
    data model, `Minigames.encode`, Submit; `clientScore` is a session's `finish` over the same records, which equals
    the server's `rawScore`.
- For M8:
  - The views (`Types.HoldZoneView`, `TimingStrikeView`, `PrecisionTraceView` with `credit`, `coveredRuns` and
    `runningScore`) and the FeedbackEvents are presentation (G7, G14, O14); S6 may reshape them without a BALANCE
    change.
  - The host loop of §12.5 as the handoff rewrites it: push `rec:since(pushed)`, `advance` to `rec:horizonMs(clock,
    dt)`, `view` at the raw time, and at GO + durationMs push once more before `finish` (D4); TimingStrike's
    `CycleStart` at GO and whenever the view's `cycle` changes, on the raw clock (D12; the view's `cycle` is 1 from the
    countdown through cycle 1). `MinigamesHelpers.play` is that loop as a test driver.
  - V-08 (§17.2's S8): releases while the Esc menu is open; `rec:release()` and §6.6's per-frame rule cover a missed
    release, S-E2E-12 verifies it.
  - Autoplay: `MinigameHost.setInputSource(Bots.autoplaySource(Bots.play(spec, pattern, profile, seed)))`. The offset
    offer reads `breakdown.judged ≥ Minigames.TS_OFFSET_OFFER_MIN_JUDGED` and `breakdown.meanErrMs`.
- Kept in `m4-b4/` (session scratch, which loses week-old files; the lead may copy what it keeps into `.build-notes`):
  `proto/` (copies of the v2 prototype with `pre_misc.luau`, `pre_tmg03.luau`, `pre_tmg10ts.luau`, `probe_hz.luau`),
  `work/` (`bounded.py`, `parity.luau`, `costs.luau`, `gentimelines.luau`, `review_golden.luau`, `casetimes.luau`),
  `run.sh`, `precompute.sh`, `volume.sh`, `lsp.sh`, `out/` (every run's output and load samples).
- Not done, by this build's rules: the optional Studio snippet of the plan's [7]; no Studio session was opened.

**Deviations from the SPEC and the plan**

1. Slice 9's `Statistics.spec` and `FalsePositives.spec` are written in slice 8: L5's volume tags and D11's pinned
   outcomes live in them. Their volume cases stay the lead's (L2) and ran here once as an indication; slice 10's
   `Perf.spec` is not written.
2. The slow cases of T-MG-09, T-MG-11 and T-MG-15 sit beside their fast ones (`Minigames.spec`, `Bots.spec`,
   `Input.spec`), not in `Statistics.spec` as the plan's [6.1] lists; T-MG-06 (a), deterministic, is a fast case of
   `Statistics.spec`.
3. Smaller quick runs, for L5's 3 s share: T-MG-15 with bots 20 runs per profile and offset (the plan: 100), T-MG-09 20
   / 30 / 6 runs (HoldZone / TimingStrike / trace; the plan: 30), and `Bots.spec`'s quick case plays two of the trace's
   six human players (Elite and Average@30/360; all six in its slow case and in the frozen timelines).
4. The libm canary is a literal in `Bots.spec`, not a third golden file (L1 names two goldens).
5. `Bots.run` returns raw scores (the prototype's `Sim.run` never clamps) with `passed` and `flagged`, and takes
   `cell.each` (Reference's per-run checks); `play`'s options add `noise` and `everyMs` (T-MG-10's trace cheats) to the
   plan's [3.11].
6. T-MG-10's true positives use the names "T-MG-10 TP <family> <cheat>" with the cheats "Exact", "noise 4 ms", "on the
   pacer", "sparse 200 ms", "noise 0.004 u", "Perfect" and "autoclicker 30/s", Iron with the tiers alternating by run;
   the σ 4 ms limit is pinned at 2 flagged of 2,000 (finding 1), not the plan's 0 %; the autoclicker runs `TP_RUNS`
   at exact clocks.
7. T-MG-10's trace margin keeps §14.8's assertion (L7) and pins and prints the 0.1 % quantile (critic B's linear rule).
8. T-MG-03 adds 20 Idle runs per cell for its "Idle scores 0 everywhere".
9. T-MG-04's bands read E-S3.2's printed means and SDs (`MinigamesHelpers.ES32`), which `Reference` checks against the
   shipped distributions.
10. `MinigameTimelines.luau` is 74,256 bytes, not the plan's "about 60 KB" (hex doubles its 32,187 bytes).

## Fix round 1 (the M4 fixer, 19 Nov 08:02–09:00)

The lead's ruling on review round 1 (`.build-notes/m4/m4_journal.txt`, 08:05; reviewers V1 and V2), applied in the
worktree. Probes and mutants ran on a `.git`-free copy in the session scratch folder (`m4-fix-1/`: `copy/`, `work/`,
`out/`, `NOTES.md`), one Lune process at a time, each bounded (a job object, 120 s, no process left), with the shift
fix's reviewers running beside it; every timing states its load. Each ruling item, done and how it was checked:

**Majors**

- **M1, the hand-off's Douglas–Peucker (V1).** `PrecisionTrace`'s `douglasPeucker` is now V1's `splitTree` + `keptFor`
  with the lead's guard: a segment gets children only when its loop found a farthest point (`imax > a`, so dmax ≥ 0).
  The hand-off builds the tree on its first attempt, and every attempt keeps the splits whose dmax exceeds its
  tolerance, from the root down. Checked:
  - the same points by construction (a segment's first farthest point does not depend on the tolerance), and on a
    probe (`work/dpprobe.luau`): 300 random chains (zigzags, walks, combs, straight runs, repeated points, closed loops;
    3–300 points; turned grips) at the 12 MVP pacer speeds, 3,600 hand-offs, 1,050 through Douglas–Peucker, 0
    differences from the prototype's `edgeToPanel` (source, E, its shrinks, the attempts, the tolerance, the reason);
  - NaN: a 300-point chain whose first point is NaN returns at once with the guard (one attempt, a 2-point source, the
    prototype's); V1's unguarded tree (children whenever b > a + 1) grows on the same chain to a 1 GB job cap in
    14.9 s and dies ("memory allocation … failed"), so the guard is load-bearing. Not in the suite: a test of it would
    hang and eat memory on its own mutant;
  - the pin, `PrecisionTrace.spec`'s "the hand-off's Douglas–Peucker keeps the prototype's points on turned blades and
    random chains": quick, the saw and the zigzag turned 13° and `PROP_N_FAST` random chains (`dpEdge`) at the slowest
    and the fastest MVP pacer, 54 hand-offs of which 15 go through Douglas–Peucker (31 ms at 57 % busy); `t.slow`,
    `PROP_N` chains at all 12 pacers, 2,424 hand-offs, 678 through it (1.0 s). Each asserts that count > 0. Mutants on
    the copy (`out/mut4.txt`, on the final tests): the tie rule (the last farthest point) is killed by the quick case
    alone (that mutant changes the turned saw's and zigzag's sources on 469 and 267 of 720 turn × pacer pairs, the
    upright ones' never) and by the slow case; `keptFor` dropping the right child, the right child cut one point short
    and the tree rebuilt from each attempt's points are killed by the quick case alone; `keptFor`'s `>=` at dmax = tol
    survives both (equality only: a distance of exactly 0.004·2^k);
  - the measurement (`work/x08cost.luau`, medians of 401 rounds alternating with `m4-r1/repo`, a collection before
    each): `prepare` on `Cost.X08_EDGE` 1.091 / 1.080 ms (Iron/Normal x = 0 / Steel/Hard x = 1: the hand-off 0.815 /
    0.810, `generate` 0.240 / 0.259) against round 1's 4.100 / 4.048 (the hand-off 3.797 / 3.749), 3–19 % busy, no
    other Lune process; at 11–43 % busy 1.11–1.16 against 4.13–4.36. The other eight reference blades' hand-off (the
    ninth, the zigzag, is `Cost.X08_EDGE`) takes ≤ 0.021 ms but the saw's 0.254 (0.555 before); a 256-point chain at the
    length bound (7 E shrinks, no Douglas–Peucker) 0.115 ms, its `generate` 1.974 (14 % busy). Where one attempt
    suffices the whole tree costs more than that attempt: a straight chain of 257 or 300 points along the axis
    (Douglas–Peucker by the count) 0.103 / 0.131 ms against round 1's 0.034 / 0.038 (`work/degenerate.luau`, 5 % busy),
    far inside the budget;
  - the handoff: slice 10's T-PERF-02 expects `prepare` = the hand-off + `generate` with these figures; §10.5's cost
    table (a new Old → New, lines 2731–2737) names the hand-off; §10.5's intro and E-S3.10 (fix round 1) say why.
- **M2, §6.11's lag (V1).** V1's corrected text; §6.9's sentence gains "or lead it for a negative offset"; the same
  claim fixed in the handoff's D12 intro, TimingStrike's header ("lag it by the frame and the timing offset") and
  Input's `horizonMs` comment (grep of lag, lags, max(0, "after the frame" and "never early" over the handoff, the
  notes, `src/shared/Minigames` and `tests/Minigames`; §6.4 rule 7's intro already says "With a positive"). V1's
  `lead.luau` re-run on the fix gives the same Miss times (588.3 / 655.0 / 705.0 / 771.7 / 821.7 ms at −120 … +120),
  now in E-S3.10.
- **M3, §6.4 rule 2 (V2).** "no other `math` member but the constant `math.huge`". `math.huge` is in TimingStrike,
  PrecisionTrace and Input (grep); no other copy of the claim (`Source.spec`'s header and B1 list `huge`).
- **M4, the fire-decay groupings (V2).** V2's four edits (the handoff's §6.8 note and E-S3.10 bullet; finding 3 and the
  mutation summary above). Checked on another source (`work/group.luau`, TestRng, 64 random bits per value):
  `F − F·(10/d)` and `F − F·10/d` differ for 0.10 % of 10^6 values at 600, 1.02 % at 300, 1.83 % at 550 (V2: 0.10 /
  1.01 / 1.83); on a 2^-53 grid, whose values below 0.5 keep their low bits zero, 0.05 % at 600, so a source with short
  fractions undercounts, as groupcheck's LCG did. The regrouping mutant passes the quick run and fails
  `Minigames/Reference`'s HoldZone parity. HoldZone's header already said "rounds differently".

**Minors**

- **V1 #3, the whitelist.** `Source.spec`: V1's `BANNED_GLOBALS` (getfenv, setfenv, _G, rawget, rawset as non-member
  names) and calls of `next`, seven planted rows (V1's four and setfenv, rawget, rawset), `next(t)` and `_G` in the
  clean sample's comment, and a header that names what still slips (a module-level memo the export does not reach,
  printf rounding, `next` taken as a value). The tree passes (5 of 5); each new check switched off fails the planted
  case. T-META-03/04: the lead's item below.
- **The seven behaviour-changing survivors.** H17 (`HoldZone.spec`: 30 downs whose last release is 2 s later flag; 29
  quick downs after a long hold, 30 ups in a window, do not), A13 (a U-shaped path: nearest's first minimum, and the
  prototype's), A20 (a pacer at 0.125 u/s still covers at 1 u/s: the gate's floor), A36 (a doubled source point gives
  the same pattern), S18 (`TimingStrike.spec`: |e| 20 at W 100, core 10 scores exactly 0.9 and counts as perfect), all
  V1's; B10 (Exact presses 1,800 targets exactly, 12 of them among the integers t/1000 misses) and B11 (a record is due
  at its own time), V2's; no duplicates. On the copy each mutant is killed by the quick run, by its own test
  (`out/mut1.txt`, and again on the final tests, `out/mut4.txt`).
- **V1 #5, the cap's cost.** §10.5 (intro and lines 2739–2740), §17.2's S5 row, B3's L6 section, B4's M7 note and slice
  10: the cap bounds the count, not the cost; T-PERF-02 times `recordCap(spec)` records spread over travel. V1's
  `hostile.luau` part 2 re-run (`work/capcost.luau`): × 1.017–1.043 over six runs of 401–1,201 rounds at 34–68 % busy
  (an earlier 201-round run at 53 % busy with seven other Lune processes gave × 0.986, noise); V1 × 1.019–1.027 at
  7–26 %.
- **V1 #6, `CycleStart` at GO.** §6.9's and §12.5's texts, the D12 intro, TimingStrike's header and B4's M8 note: the
  host plays it at GO and whenever the view's `cycle` changes, on the raw clock. V1's `cyclego.luau` re-run: `cycle` 1
  at −3,000 and 0 ms, cues at 850 and 1,745 ms only.
- **V1 #7, §10.3.** `Timeline.decode` refuses an oversize buffer (a count over `MAX_RECORDS` or more bytes than the
  family's cap) right after its four header checks, before `table.create` and the record loop: O(1). So the text says
  Submit relies on `judge` (no re-export); `Timeline`'s `capBytes` comment says the same.
- **V1 #8, the offset offer.** V1's `offset.luau` re-run gives V1's figures (0.4790 / 0.6482 / 0.7124 at −35 / 0 / +35,
  the mean `meanErrMs` +67.1 / +33.5 / −0.9): in B4 above and in E-S3.10.
- **V2 #3, the marks.** **[Decision to confirm]** before (O14) in §6.8's, §6.9's and §6.10's views and before (O13) in
  §6.9's combo.
- **V2 #6, L3V's rationale.** Reference catches porting changes to the judge or the four human players; the Perfect
  controllers are pinned by T-MG-11 and L3V's T-MG-03. (The lead's L5 "Why" stays as written, per the ruling.)
- **V2 #7–#12.** "exceed 37.70" (E-S8.5 and `Rng.spec`'s comment); 1,479 records (slice 10, B3's open issue); the σ 4 ms
  rates per strike count, checked with the χ² CDF (11 degrees of freedom under 1.5469: 4.42·10⁻⁴; 14 under 1.9688:
  7.56·10⁻⁵; 0.517 flags expected in 2,000 alternating runs, P(≥ 2) 0.096) and the strike counts (12 on Normal and 15
  on Hard at `BOT_REF_X`, on all 2,000 seeds, Iron and Steel), in E-S3.8, finding 1 and `FalsePositives`' comment; "a
  few 1/16384 u" with the per-point bound; the README's lines 40–42 and 45–46 (and its Status paragraph ends at line
  130, not 131); the canary's "1,000 draws and the 8 OU exponents" (`Bots.spec`'s case name, B4); `FalsePositives`'
  header (the σ 4 ms TP pins the build's own count); §6.6's Caps (the Recorder never exceeds the judge's trace cap).

**For the lead: T-META-03/04 (not M4's file, L1)**

`m4-fix-1/out/rules_meta.diff` (session scratch), for `tests/Meta/Rules.luau` and `tests/Meta/Source.spec.luau`, to
apply with M4 in the main tree (`git apply -p0` from the repo root; `.gitattributes` keeps LF). T-META-03 flags
getfenv, setfenv, _G, rawget and rawset as non-member names, which no allow-transcendental tag exempts; T-META-04 flags
a call of `next` that is not an emptiness test (`next(t) == nil` or `~= nil`, one argument), which keeps
`Blueprint/Canonical`'s `next(rawParts) ~= nil`. Planted rows: seven for T-META-03, four for T-META-04, three clean
ones. Tried on the copy: `Meta/Source` 16 pass with the patch; with the worktree's `Rules.luau` and the patched spec, 2
fail (T-META-03's getfenv row and T-META-04's next row not caught); `scripts/verify -- --quick` on the copy with the
patch and this round: GREEN, luau-lsp 0 errors, 852 pass. Still slips T-META-03: `math` taken as a value
(`local m = math`), which `Minigames/Source` catches in Minigames only.

**Checks**

- No golden, fingerprint, frozen timeline, Definitions file, pinned name or precomputed outcome changed:
  `tests/golden`, `tests/fixtures/MinigameTimelines.luau` and `src/shared/Definitions` are byte-identical to
  `m4-r1/repo`, and the statistical specs' names and pins are untouched.
- Every Old block of the handoff (59, with §10.5's table) occurs exactly once in SPEC.md, SPEC-evidence.md or
  README.md (V2's `oldblocks.py`).
- M4's L1 share, `--quick --filter "Minigames/"`, alternating with `m4-r1/repo`, no other Lune process, 11–32 % busy:
  1.88 / 1.83 / 1.87 s by the runner (140 pass, 57 skip) against round 1's 1.92 / 1.84 / 1.88 s (135, 56).
- Plain L3 for M4, `lune run tests/run -- --filter "Minigames/"`: 176 pass, 0 fail, 21 skip (the volume cases),
  162.11 s by the runner at 5–71 % busy (median 25), two to four other Lune processes; Reference parity and full
  precision pass.
- `lune run scripts/verify -- --quick` in the worktree: `VERIFY GREEN (--quick) (38.2 s)`, luau-lsp A and B 0 errors,
  `RESULT pass=852 fail=0 skip=99 files=77 time=31.88s`, 4–47 % busy (median 14), up to two other Lune processes.

**Deviations from the ruling's letter**

- The quick parity case also checks the saw and the zigzag turned 13°: its random chains alone did not kill the
  tie-rule mutant in the quick run. `turned` was split out of `randomEdge` for it (the same expressions).
- `Source.spec` plants three rows more than V1 (setfenv, rawget, rawset), so every banned name bites, and names `next`
  taken as a value among what slips.
- V1's tests are taken as written but for two rewraps to 120 columns (the U path's comment, the floor case's sample
  line). The parity case's loop variable is annotated (`DT.MaterialId`): luau-lsp widened it to string.
- The README's "after line 131" (the Status paragraph) is corrected to 130 too, the same off-by-one as V2's #11.

## Fix round 3 (the M4 fixer, 19 Nov 18:23–18:52)

The lead's ruling on review round 2 (`.build-notes/m4/m4_journal.txt`, 18:25; reviewers V1 and V2), applied in the
worktree. In `src/` only PrecisionTrace's header comment changes; in the tests, `Source.spec`'s whitelist (two more ways
to call next, two planted rows, its header) and one comment. Probes and mutants ran on a `.git`-free copy in the session
scratch folder (`m4-fix-3/`: `copy/`, `hw/`, `meta/`, `work/`, `out/`, `NOTES.md`), one Lune process at a time, each
bounded (a job object, 120 s, no process left); every timing states its load. Each ruling item, done and how it was
checked:

**The major**

- **The zigzag is a reference blade (V1, V2).** It is the ninth of E-S3.5's blades (`Edges.order`) and `Cost.X08_EDGE`
  is `Edges.zigzag`, so the three texts that set it apart were false. Now §10.5's cost cell has V2's wording (every
  reference blade but the zigzag, of theirs the saw's Douglas–Peucker the costliest; 0.82 + 0.25 on the zigzag, eight
  attempts, the costliest hand-off), and E-S3.10's fix-round-1 bullet and the M1 bullet of "Fix round 1" above have V1's
  (the other eight reference blades; the zigzag is `Cost.X08_EDGE`). No other copy: a grep of the handoff, these notes,
  `src/shared/Minigames`, `tests/Minigames` and the fixtures for reference blade, costliest, the saw, zigzag and the
  hand-off figures finds no other cost claim that leaves the zigzag out (§10.5's Old block keeps E-S3.5's `generate`
  figures; B2's finding 5 is about `generate`). Re-measured (`work/onecost.luau` part C: the worktree's hand-off in
  `hw/` against `m4-r1/repo`, medians of 101 alternating rounds, Iron/Normal x = 0.10, 17–27 % busy, no other Lune
  process): the zigzag's hand-off 0.853 ms (round 1: 3.947), 8 attempts, tolerance 0.512; the saw's 0.239 (0.549), 6
  attempts, 0.128; the other seven ≤ 0.020 ms.

**The minors**

- **V1 #2, PrecisionTrace's header.** The tree keeps the same points at a fraction of the cost of several attempts;
  where one attempt suffices, the whole tree can cost far more than that attempt, which may stop at its first segment:
  up to about 0.5 ms on 256 points, where every split sheds one point. The ruling's figures for that case ("up to about
  3× that attempt, under 0.5 ms") were not taken: see the deviations.
- **V1 #3, the whitelist.** `Source.spec` also flags `next{}` and `next 'x'` (V1's clause: a brace or a string after
  `next`), with two planted rows; its header names the over-matches (a table key or type field named after a banned
  global, a local function or local named next that is called; none in the tree) and what still slips (`(next)(t)`
  beside `local f = next`). Checked: the tree passes (5 of 5); each clause dropped fails its own planted row (W3a, W3b
  in `out/mut3.txt`); a probe spec on the copy (deleted after) flags `{ getfenv = 1 }`, `{ rawget: number }`,
  `{ _G = 1 }`, `local function next` and a called parameter named next, catches the other string forms (`next "x"`,
  `next [[x]]`, an interpolated string), and lets `(next)(list)` and `local f = next` through; members and keys named
  next stay clean. T-META-03/04's half is the lead's, below.
- **V2 #2, the floor case's comment.** "14 bins; 1 at 6 × speed": the A20 mutant (the gate without its floor) fails the
  case with "covered 1" (`out/mut3.txt`).
- **V2 #3, slice 10's judge expectation.** V2's wording: near the prototype's 2.59 ms on its honest timeline, the build
  2.34 ms at 12 % busy (review round 2); the "plus the build's 15–30 %" (Bots.run's overhead, not `judge`'s) is gone.

**For the lead: T-META-03/04 (not M4's file, L1)**

`m4-fix-3/out/rules_meta.diff` (session scratch) replaces `m4-fix-1/out/rules_meta.diff`: the same patch with the change
above, to apply with M4 in the main tree as before (`git apply -p0` from the repo root). T-META-04's next rule takes
Rules' `isCallOpener`, so `next{…}` and `next 'x'` are calls, and only a call in parentheses can be the emptiness test
(`next{} == nil` is flagged). The comments above the two rules name the over-matches (a table key or type field named
after a banned global; a local function or local named next that is called) and what still slips (math taken as a value,
`local m = math` or `math["cos"]`; next taken as a value, `local f = next` or `(next)(t)`). Two planted rows:
`local k = next{}` and `local k = next 'x'`. Tried on the copy: it applies cleanly (GNU patch -p0, LF kept);
`Meta/Source` 16 pass; round 1's rule fails the `next{}` row and a rule without string calls the `next 'x'` row (M3,
M3b); `work/metaprobe3.luau` (V1's rows and mine) shows each over-match and slip named;
`lune run scripts/verify -- --quick` on the copy with the patch and this round: GREEN, luau-lsp A and B 0 errors, 852
pass, 37.7 s, 10–40 % busy (median 18), no other Lune process.

**Checks**

- `src/` differs from `m4-r2/repo` in PrecisionTrace's header comment only (its lines 34–38, all comment lines);
  `tests/golden`, `tests/fixtures` and `src/shared/Definitions` are byte-identical to `m4-r2/repo`.
- Every Old block of the handoff (59) occurs exactly once in SPEC.md, SPEC-evidence.md or README.md, where it did before
  (V2's `oldblocks.py`).
- M4's L1 share, `lune run tests/run -- --quick --filter "Minigames/"`: 140 pass, 0 fail, 57 skip, 1.92 s by the runner,
  22 % busy, no other Lune process; again at the end, 2.00 s at 26 % busy beside three other Lune processes (not mine).
- `lune run scripts/verify -- --quick` in the worktree: `VERIFY GREEN (--quick) (38.1 s)`, luau-lsp A and B 0 errors,
  `RESULT pass=852 fail=0 skip=99 files=77 time=31.76s`, 13–42 % busy (median 20), no other Lune process; again at the
  end, with this section written: `VERIFY GREEN (--quick) (41.2 s)`, luau-lsp A and B 0 errors,
  `RESULT pass=852 fail=0 skip=99 files=77 time=34.59s`, 13–43 % busy (median 23), three other Lune processes (not
  mine).

**Deviations from the ruling's letter**

- V1 #2's figures. "Up to about 3× that attempt" is the whole hand-off's ratio to round 1's (V1: × 3.43 on its chains),
  not the tree's to the attempt: on V1's own chains (its `fewcost.luau` draws) the tree and `keptFor` cost up to × 46
  round 1's single attempt (0.245 against 0.005 ms), since that attempt stops after one scan when the root's farthest
  point is within the tolerance. And "under 0.5 ms on 256 points" fails where the tree peels: a 256-point zigzag whose
  teeth run along the grip axis (base to tip and back, 6 studs) and drift 0.004 stud across in all, which one attempt
  settles, costs 0.514–0.518 ms in the tree against the attempt's 0.005, the whole hand-off 0.61–0.62 against round 1's
  0.10 (`work/onecost.luau` parts A and B, 101 rounds, 17–27 % busy, no other Lune process). The peel is the tree's
  worst case (each split sheds one point: `(n − 1)(n − 2)/2` distances), so the header bounds it at about 0.5 ms.
- The rewrapped paragraphs (slice 10, E-S3.10's bullet, M1's bullet, the two headers) never break inside inline code, so
  slice 10's command stays on one line.

**After the round-3 check (the lead, 19 Nov 19:20)**

- The round-3 verifier passed the round (no blocker or major) and named one optional minor: the header's split left out
  two attempts, where the tree costs up to × 3 the old attempts (one attempt × 5.9–36, two × 1.09–3.04, three
  × 0.63–1.26, four to eight at most × 0.84; its `cost3.luau` part S, 7–28 % busy). The lead applied its tried
  wording to PrecisionTrace's header ("Where one or two attempts suffice, the whole tree can cost more than they do,
  and far more than one attempt, …"), a comment only: `--quick --filter "Minigames/PrecisionTrace"` 18 pass.
