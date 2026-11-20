# M4 handoff: SPEC, evidence and README edits

Applied to SPEC.md, SPEC-evidence.md and README.md at M4's commit; kept as the record of the patch.

The edits of `.build-notes/m4-plan/plan-r2.md`'s [12], written as the lead's L1 says: SPEC.md, SPEC-evidence.md and
README.md stay untouched in M4's worktree, because the whole-design shift fix rewrites them in the main tree. Where the
old text is in `f7ac37d`, an edit gives it as exact old → new text (line numbers are `f7ac37d`'s); otherwise as new
text with its place. After the shift fix's commit the lead applies these and reconciles them with that fix's text:
where the fix rewrote the same line (§14.1's L1 row is one), keep the fix's measured figures and apply the change the
edit names. Each section names the builder who wrote it; later builders add theirs, and every figure here is the
build's, measured as `docs/build/M4-notes.md` says.

## Builder 1: the test tiers (L5), `Minigames/Rng`, `Params`, `Checks`, D3

### §14.1 Layers and gates: the L1 row (SPEC.md line 3717)

The lead's L5: L1's gate 35 s quiet, M4's share 3 s quiet, the `t.slow` trigger 32 s quiet. The shift fix rewrote this
row's measured figures (the plan quotes "29.3–29.6 s quiet after the shift fix's pins … 29.64 and 29.99 s at 3–20 %
busy after its round 2's"); keep those and apply the three numbers.

Old:

```
| L1 Unit/property | pure modules (§14.6) | `lune run tests/run -- --quick` | every change | all pass, ≤ 30 s (25.9 s at M3's fix round 1, the machine quiet; 30.2–30.7 s under ordinary load, 7–29 % busy, in M3's review round 2 and fix round 2, so the gate too needs a quiet machine; past 27 s quiet, fast corpora of generated designs move to `t.slow`, which L3 runs) |
```

New:

```
| L1 Unit/property | pure modules (§14.6) | `lune run tests/run -- --quick` | every change | all pass, ≤ 35 s quiet, of which M4's `Minigames/` cases (`--quick --filter "Minigames/"`) ≤ 3 s quiet (25.9 s at M3's fix round 1, the machine quiet; 30.2–30.7 s under ordinary load, 7–29 % busy, in M3's review round 2 and fix round 2, so the gate too needs a quiet machine; past 32 s quiet, fast corpora of generated designs move to `t.slow`, which L3 runs) |
```

(Slice 11, the lead: add M4's measured quiet L1 total and `Minigames/` share in the parenthesis.)

### §14.1 Layers and gates: the L3 row (line 3719) and a new L3V row after it

Old:

```
| L3 Statistical | bands, false positives, rarity (§14.8) | `lune run tests/run` (adds `t.slow`) | milestone exit, before a playtest, any change in `Minigames/`, `Crafting/` or their Definitions | all pass, ≤ 10 min |
```

New (two rows):

```
| L3 Statistical | bands, false positives, rarity (§14.8) | `lune run tests/run` (adds `t.slow`; skips the `t.volume` cases and lists each as `SKIP`) | milestone exit, before a playtest, any change in `Minigames/`, `Crafting/` or their Definitions | all pass, ≤ 10 min quiet |
| L3V Volume | L3 plus the `t.volume` cases: statistics whose outcome only the BALANCE data, the bots and a pinned config name decide (§14.8; T-MG-10's false-positive runs, T-MG-03, T-MG-06, T-MG-12) | `lune run tests/run -- --volume` | milestone exit, before a playtest, after any change to `Definitions/MinigameFamilies`, `Definitions/Balance`'s minigame rows, `Minigames/Bots` or a pinned config name | all pass, ≤ 20 min quiet for the whole run |
```

(If builder 4 or the lead also tags T-MG-04's Q8 fail-rate extension `t.volume` because plain L3 stays over 10 minutes
without it, add it to the L3V row's list.)

New paragraph after the table (after line 3723, "Ids: `T-` Lune, …"):

```
L3V exists because every fixer and reviewer runs the full L3 at each round: a `t.volume` case cannot change unless
the data, the bots or a pinned name changes, and `Minigames/Reference` (plain L3) catches any porting change to the
judge or the four human players at once (the Perfect controllers are pinned by T-MG-11 and L3V's T-MG-03), so the
per-change L3 skips them; `scripts/verify -- --volume` runs the gate with them.
```

### §14.3 Runner and test library (lines 3740–3752)

Old (lines 3740–3741):

```
lune run tests/run [-- --quick | --filter <text> | --seed <n> | --bless | --list | --root <dir>]
lune run scripts/verify [-- --quick]          -- Lune 0.8.9: script arguments must follow "--"
```

New:

```
lune run tests/run [-- --quick | --volume | --filter <text> | --seed <n> | --bless | --list | --root <dir>]
lune run scripts/verify [-- --quick | --volume]   -- Lune 0.8.9: script arguments must follow "--"
```

Old (lines 3744–3749):

```
`tests/run` exits 0, 1 (a `FAIL` assertion or `ERROR` crash) or 2 (harness: not at the repo root, bad argument, no
specs, a spec fails to load or returns no suite, duplicate suite, empty filter); `scripts/verify` exits 0, 1 (tests),
2 (harness, sourcemap, T-META-07), 3 (luau-lsp), 4 (missing tool). Discovery: `tests/**/*.spec.luau` except `lib/` and
`studio/`, byte-wise order, one uniquely named suite per spec, each case in `xpcall`; a case over `CASE_BUDGET_MS`
(`SLOW_CASE_BUDGET_MS` for `t.slow`) fails. Runner and specs share one `Prop`/`Golden` instance (module cache), which
carries `--seed` and `--bless`. Lune facts relied on: E-S8.1.
```

New:

```
`tests/run` exits 0, 1 (a `FAIL` assertion or `ERROR` crash) or 2 (harness: not at the repo root, bad argument,
`--quick` with `--volume`, no specs, a spec fails to load or returns no suite, duplicate suite, empty filter, a root
that holds the runner self-test asked of a runner that self-test spawned); `scripts/verify` passes `--quick` or
`--volume` through to `tests/run` and exits 0, 1 (tests), 2 (harness, sourcemap, T-META-07), 3 (luau-lsp), 4 (missing
tool). Discovery: `tests/**/*.spec.luau` except `lib/` and `studio/`, byte-wise order, one uniquely named suite per
spec, each case in `xpcall`; a case over `CASE_BUDGET_MS` (`SLOW_CASE_BUDGET_MS` for `t.slow`, and for `t.volume`,
which is a slow case) fails. A plain run skips every `t.volume` case and prints a `SKIP` line naming it; `--volume`
runs them (L3V, §14.1). Runner and specs share one `Prop`/`Golden` instance (module cache), which carries `--seed` and
`--bless`. The runner self-test (T-META-05) never starts the suite that holds it: every runner it spawns takes a root
under `tools/runner-selftest/`, and every process it spawns carries `BLACKSMITH_SELFTEST_CHILD`
(`Test.SELFTEST_CHILD`), under which the self-test spawns nothing, `tests/run` refuses (exit 2) a root that holds
the self-test (a spec at `Meta/Runner.spec.luau`, so `tests/` itself) and `scripts/verify` runs no stage (exit 2,
naming the command its tests stage would run). Lune facts relied on: E-S8.1.
```

Old (line 3752):

```
Test.suite(name: string, body: (t: {it: Case, slow: Case, skip: Case}) -> ()): Suite   -- A.eq/near/…/fail raise "assert:"
```

New:

```
Test.suite(name: string, body: (t: {it: Case, slow: Case, skip: Case, volume: Case}) -> ()): Suite   -- A.eq/near/…/fail raise "assert:"
```

### §14.4 Static analysis and meta rules: the T-META-05 row (line 3780)

Old:

```
| T-META-05, 06 | runner self-test (`tools/runner-selftest/{pass, fail, broken}` exit 0 / 1 / 2); no `:Reconcile(` in `src/` |
```

New:

```
| T-META-05, 06 | runner self-test (`tools/runner-selftest/{pass, fail, broken, nospec}` exit 0 / 1 / 2 / 2; `volume`: a plain run skips and lists its `t.volume` case, `--volume` runs it, `--quick --volume` exits 2, and `scripts/verify` passes the flag through; `bless`: `--bless` writes a golden, plain runs compare it; `holder`: a runner the self-test spawned refuses a root that holds the self-test, and `scripts/verify` spawned by it runs no stage, so the self-test never starts its own suite, §14.3); no `:Reconcile(` in `src/` |
```

The T-META-05 change behind `holder` comes from an incident while M4 was built (18 Nov, 19:31–19:43): a mutation run
broke the runner's `--quick --volume` refusal, and the self-test's harness-fault cases, which then named no root, ran
the whole suite in a child, whose self-test did the same, 41 levels deep, until the lead stopped it.
`docs/build/M4-notes.md` (builder 1) has the account and the three guards' mutants.

### §14.4: the Minigames whitelist in the T-META-03 row (line 3778)

Old:

```
| T-META-03 | `Blueprint/ Physics/ Minigames/ Crafting/ Pipeline Items/ Session/` use no `math.sin cos tan exp log pow atan asin acos` and no `^`, except lines tagged `-- allow-transcendental: <reason>` |
```

New:

```
| T-META-03 | `Blueprint/ Physics/ Minigames/ Crafting/ Pipeline Items/ Session/` use no `math.sin cos tan exp log pow atan asin acos` and no `^`, except lines tagged `-- allow-transcendental: <reason>`; `Minigames/` but `Bots` also keeps §6.4 rule 2 as a whitelist (`tests/Minigames/Source.spec.luau`): every `math.` member one of `floor ceil round abs min max clamp sqrt huge`, no `vector.`, no float buffer access, no `%`, `//` or their compound forms, every generic `for` over `ipairs(...)` and no `pairs` |
```

### §6.3 PRNG: `mul32` and SplitMix32 with `mod` (lines 1625–1631; M4's plan I6)

§6.4 rule 2 allows only `+ − × ÷` and its math functions, while §6.3 writes the reductions with `%`. The build keeps
§6.4 and writes each reduction as `mod(x, m) = x − floor(x / m)·m`: for the integers below 2^53 that §6.3 uses, every
step is exact, so the values are those of `%` (T-RNG-01's vectors, and 0 differences from the S3 prototype over
192,000 draws of 3,000 streams).

Old (lines 1625–1628):

```
xoshiro128\*\* 1.1 (four u32 words, period 2^128 − 1) with `bit32` ops and integer `+ * %` below 2^53; u32 products
via `mul32(a, b) = ((a >> 16)·b % 65536·65536 + (a & 0xFFFF)·b) % 2^32`. `Rng.new(seed, tag)`: `x = seed ⊕
FNV1a32(tag)` (basis `0x811C9DC5`, prime `0x01000193`, `nil` ≡ `""`), then SplitMix32 per word: `x = (x + 0x9E3779B9)
% 2^32`, `s_i = fmix32(x)` (constants `0x85EBCA6B`, `0xC2B2AE35`). Tags (renaming one bumps BALANCE_VERSION):
```

New:

```
xoshiro128\*\* 1.1 (four u32 words, period 2^128 − 1) with `bit32` ops and integer `+ − ×` below 2^53, reduced by
`mod(x, m) = x − floor(x/m)·m` (exact there; §6.4 has no `%`); u32 products via `mul32(a, b) = mod(mod((a >> 16)·b,
65536)·65536 + (a & 0xFFFF)·b, 2^32)`. `Rng.new(seed, tag)`: `x = seed ⊕ FNV1a32(tag)` (basis `0x811C9DC5`, prime
`0x01000193`, `nil` ≡ `""`; a seed that is not a u32 integer is refused), then SplitMix32 per word: `x = mod(x +
0x9E3779B9, 2^32)`, `s_i = fmix32(x)` (constants `0x85EBCA6B`, `0xC2B2AE35`). Tags (renaming one bumps BALANCE_VERSION):
```

Old (line 1630, its end):

```
(u32 / 2^32), `range`, `int` (inclusive), `chance`, `sign`; exports `mul32`, `fnv1a32`, `fmix32`. Pattern hashes:
```

New:

```
(u32 / 2^32), `range`, `int` (inclusive), `chance`, `sign`; exports `mul32`, `fnv1a32`, `fmix32`, `hashU32` (one
FNV-1a step over a u32's four bytes, low byte first). Pattern hashes:
```

### §6.4 rule 2 (lines 1635–1636)

Old:

```
1. Integer ms from GO; ticks are multiples of `HZ_TICK_MS` / `PT_EVAL_MS`. 2. Only `+ − × ÷`, `sqrt`,
`floor/ceil/round`, `abs`, `min/max/clamp`; no `sin cos exp log` and no `^` (powers by repeated multiplication). 3.
```

New:

```
1. Integer ms from GO; ticks are multiples of `HZ_TICK_MS` / `PT_EVAL_MS`. 2. Only `+ − × ÷`, `sqrt`,
`floor/ceil/round`, `abs`, `min/max/clamp`; no `sin cos exp log`, no `^` (powers by repeated multiplication), no `%`
or `//` (integer reductions are `x − floor(x/m)·m`, §6.3), no other `math` member but the constant `math.huge`
(`math.lerp` may fuse into an FMA), no `vector` and no float buffer access; a whitelist test enforces it (§14.4,
T-META-03's row). 3.
```

### §10.6 PtTooSmooth's dt bounds (line 2754; M4's D3)

Old:

```
| `PtTooSmooth` | ≥ 150 moving triplets (span > 0.002 u, both dt 10–40 ms) and mean \|Δ²p\| < 0.0002 u | medium → telemetry | human minimum 0.0038 (×19) |
```

New:

```
| `PtTooSmooth` | ≥ 150 moving triplets (span > 0.002 u, both dt 10–40 ms: `PT_SMOOTH_DT_MIN_MS`, `PT_SMOOTH_DT_MAX_MS`) and mean \|Δ²p\| < 0.0002 u | medium → telemetry | human minimum 0.0038 (×19) |
```

### §16.12: D3's two rows (after line 4364)

Old:

```
| `PT_SMOOTH_MIN_TRIPLETS`, `PT_SMOOTH_MEAN_JERK`, `PT_SMOOTH_MIN_MOVE` | 150, 0.0002, 0.002 | –, u, u | S3 | human minimum ×19 |
```

New (two rows):

```
| `PT_SMOOTH_MIN_TRIPLETS`, `PT_SMOOTH_MEAN_JERK`, `PT_SMOOTH_MIN_MOVE` | 150, 0.0002, 0.002 | –, u, u | S3 | human minimum ×19 |
| `PT_SMOOTH_DT_MIN_MS` / `PT_SMOOTH_DT_MAX_MS` | 10 / 40 | ms | S3 | a moving triplet's two intervals (§10.6) |
```

They are `checks` rows of `Definitions/MinigameFamilies` (PrecisionTrace, after `PT_SMOOTH_MIN_MOVE`), so the BALANCE
fingerprint moved at version 1, before any item exists (§14.9): `{bytes=13372, fnv1a32=3275947958, version=1}`, was
`{bytes=13286, fnv1a32=162842818, version=1}`. If the shift fix's commit changes any hashed Definitions, re-bless
after applying both (delete the golden, then `lune run tests/run -- --bless --filter "Definitions/BalanceGuard"`).

### SPEC-evidence.md E-S8.5: T-RNG (lines 3204–3205; M4's plan I1, G12)

Old:

```
- **T-RNG** 01 vectors from `kat/` (`studies/kat_xorshift32.py`) · 02 determinism · 03 seed validation · 04 χ² over
  16 buckets < CHI2_CRIT · 05 1,000 derived tags collision-free · 06 independence.
```

New:

```
- **T-RNG** 01 vectors from E-S3.1 (cross-checked against `rng_ref.py`), with the four game tags' FNV-1a values,
  `mul32` and `hashU32` cases, seeds 0 and 2^32 − 1 and one HoldZone stream's `range`, `int`, `chance` and `sign`
  (`kat/`'s xorshift32 was S8's stand-in, superseded by S3's xoshiro128\*\*) · 02 determinism, every method, 10,000
  draws · 03 `Rng.new` refuses a seed that is not a u32 integer · 04 χ² over 16 buckets < CHI2_CRIT, 20 streams
  (seeds 1, 2, 3, 0xC0FFEE × "" and the four tags) and `int(1, 16)`, n = 160,000 · 05 1,000 derived tags
  ("T-RNG-05/<i>") and the four game tags: distinct hashes, initial states and first outputs at seeds 0, 1, 2^32 − 1 ·
  06 independence, 2-D χ² on 4 × 4 cells: the game-tag pairs, seeds s and s + 1, and lag-1 pairs taken
  non-overlapping (overlapping pairs exceed 37.70 with probability 0.0049, not 0.001). With fixed seeds every χ² is
  known for an exact port (highest 30.87, 22.50 for `int`, 28.20 for 06).
```

### README.md: how to test (lines 90–98)

Old (lines 91–92):

```
lune run tests/run                                                 # all tests, statistical ones included (L3)
lune run scripts/verify                                            # the gate: sourcemaps → T-META-07 → luau-lsp → tests
```

New:

```
lune run tests/run                                                 # all tests, statistical ones included (L3)
lune run tests/run -- --volume                                     # L3 plus the t.volume statistics (L3V)
lune run scripts/verify                                            # the gate: sourcemaps → T-META-07 → luau-lsp → tests
```

Old (lines 95–98, the start of the paragraph):

```
Lune 0.8.9 passes script arguments only after `--`. Runner flags: `--quick`, `--filter <text>`, `--seed <n>`
(replays one property case), `--bless` (rewrites goldens: review the diff), `--list`, `--root <dir>`. The runner
exits 0, 1 (a FAIL or an ERROR) or 2 (harness, including a `--filter` that matches no case and a `--seed` that
replays none); `scripts/verify [-- --quick]` exits 0 green, 1 tests, 2 harness (a crash of verify itself included),
```

New:

```
Lune 0.8.9 passes script arguments only after `--`. Runner flags: `--quick`, `--volume` (also runs the `t.volume`
cases, which a plain run skips and lists; due at milestone exit, before a playtest and after a change to the minigame
data, the bots or a pinned config name, SPEC §14.1), `--filter <text>`, `--seed <n>` (replays one property case),
`--bless` (rewrites goldens: review the diff), `--list`, `--root <dir>`. The runner exits 0, 1 (a FAIL or an ERROR)
or 2 (harness, including `--quick` with `--volume`, a `--filter` that matches no case and a `--seed` that replays
none); `scripts/verify [-- --quick | --volume]` passes its flag to the runner and exits 0 green, 1 tests, 2 harness (a
crash of verify itself included),
```

## Builder 2: the three families (slices 3–5), the reference edges, O13 and O14

These edits state what `Minigames/TimingStrike`, `HoldZone` and `PrecisionTrace` do as built: the prototype's
groupings (G8, M4's D1), the views and feedback the SPEC names but does not define (G7, G14), the combo (O13) and the
live score (O14), with L4's defaults, and the reference-edge fixture. `docs/build/M4-notes.md` (B2) has the
measurements.

### §6.8 HoldZone: the fire decay's grouping (line 1710; M4's G8)

The prototype that made E-S3's hashes, goldens and distributions computes `decay = 10 / fireDecayMs` once and then
`F − F·decay`, and the build does the same. The two groupings differ in the last bit for about 0.1 % of uniformly
random F at `fireDecayMs` 600, the only value the data gives (1.0 % / 1.8 % at 300 / 550), and on the shipped runs that
shows in the unquantized sums (`Minigames/Reference` refuses the regrouping), so the grouping is pinned at the shipped
value too.

Old:

```
  F −= F·10/fireDecayMs;  T = clamp(T + heatDecay·(fullHeat·F − T)·0.010, 0, 1)
```

New:

```
  F −= F·(10/fireDecayMs);  T = clamp(T + heatDecay·(fullHeat·F − T)·0.010, 0, 1)
```

### §6.8 HoldZone: the view and feedback (lines 1728–1729; G7, O14)

Old:

```
View `{t, phase, temperature, fire, zoneCenter, zoneHalf, softBand, inZone, runningScore, timeLeftMs}`; feedback `Go`,
`Stroke(value)`, `RampEnd`, `EnterZone`, `LeaveZone`, `End`.
```

New:

```
View `{t, phase, temperature, fire, zoneCenter, zoneHalf, softBand, inZone, runningScore, timeLeftMs}`
(`Minigames/Types`): T and F after the last integrated tick, the zone at `now`; `runningScore` = q(credit / scored ticks
so far), 0 before the ramp ends **[Decision to confirm]** (O14). Feedback `Go` (the first `advance`), `Stroke(value)`
(from `push`, its gain from the pushed press times), `RampEnd` (the first scored tick), `EnterZone` / `LeaveZone` (a
scored tick's zone state changes; out before the first), `End` (the last tick).
```

### §6.9 TimingStrike: `CycleStart` and the combo (lines 1750–1753; M4's D12, O13)

The plan's D12: the host advances TimingStrike to the Recorder's horizon (D4), which lags the frame by the timing
offset (or leads it, for a negative offset), so a beat cue raised by `advance` would sound `timingOffsetMs` off the
dial; the view's `cycle` follows the raw clock instead. The view's `cycle` is 1 from the countdown through cycle 1, so
the host also plays the cue at GO (M4's fix round 1).

Old (the paragraph's last sentence, line 1753):

```
round(meanErrMs)`, clamped ±120); Settings has the same slider (S6). A `CycleStart` tick keeps the rhythm audible.
```

New:

```
round(meanErrMs)`, clamped ±120); Settings has the same slider (S6). A `CycleStart` tick keeps the rhythm audible: the
host plays it at GO and whenever the view's `cycle` changes, on the raw clock, not from `advance` (whose decisions lag
the frame by the timing offset, or lead it for a negative offset, §6.11). Combo, feedback only: +1 for each span
decided with points above 0; a span decided with 0 points (a miss, or a press past W) resets it; whiffs leave it alone
**[Decision to confirm]** (O13).
```

### §6.9 TimingStrike: the view and feedback (lines 1765–1766; G7, O14)

Old:

```
View `{t, cycle, cycles, marker, windowCenter, windowHalf, perfectHalf, goodHalf, next?, lastGrade?, lastErrorMs?,
combo, runningScore, timeLeftMs}` (sweep units); feedback `CycleStart`, `Strike(grade, errMs)`, `Miss`, `Whiff`, `End`.
```

New:

```
View `{t, cycle, cycles, marker, windowCenter, windowHalf, perfectHalf, goodHalf, next?, lastGrade?, lastErrorMs?,
combo, runningScore, timeLeftMs}` (sweep units, `Minigames/Types`): the dial at `now` on the raw clock (cycle i with
start_i ≤ now < start_i + P_i; 1 before GO, N in the tail; the bands are `bandMs` of 0.9 and 0.6 points), and the
decisions as the session was advanced; `runningScore` = q(Σ points / spans decided so far), 0 before the first
**[Decision to confirm]** (O14). Feedback: `push` returns the `Miss` of each span its press closes, then
`Strike(grade, errMs)` or `Whiff`; `advance` returns `Miss` per span closed unjudged and `End` once every span is
closed; `CycleStart` comes from the view (above).
```

### §6.10 PrecisionTrace: the travel time's grouping (line 1794; G8)

The prototype computes `ceil(L/pacerSpeed·1000/20)·20`; the same number as §6.10's `ceil(L/pacerSpeed·50)·20`, but
rounded differently, so the build writes the prototype's (D1).

Old:

```
  travelMs = clamp(ceil(L/pacerSpeed·50)·20, 6000, 30000); speed = L/(travelMs/1000); durationMs = leadInMs +
```

New:

```
  travelMs = clamp(ceil(L/pacerSpeed·1000/20)·20, 6000, 30000); speed = L/(travelMs/1000); durationMs = leadInMs +
```

### §6.10 PrecisionTrace: live ticks, the view and feedback (lines 1817–1820; G7, G14, O14)

`credit` and `coveredRuns` are G14 (critic A 3): §12.8 draws the trail by accuracy credit and tints the covered runs,
which §6.10's view could not serve. `runningScore` is O14: §12.2 shows a live score for every step, and §6.10 named
none for the trace.

Old:

```
Costs: §10.5; the reference arming edge travels 11.2 s at Iron/Normal (12.2 s step; the F5 starter 10.8 s / 11.8 s).
View
`{t, pacerU, pacerV, pacerArc, cursorArc?, distance?, onPath, grinding, accuracySoFar, coverage, paceLag?, timeLeftMs}` + the
static path; feedback `GrindStart/Stop`, `OnPath/OffPath`, `PaceWarn(sign)`, `Coverage(25…100)`, `End`.
```

New:

```
Costs: §10.5; the reference arming edge travels 11.2 s at Iron/Normal (12.2 s step; the F5 starter 10.8 s / 11.8 s).
`advance(now)` evaluates a tick only once a sample at or after it is known (§6.4 rule 7); `finish` evaluates the rest.
View `{t, pacerU, pacerV, pacerArc, cursorArc?, distance?, onPath, grinding, accuracySoFar, coverage, paceLag?,
credit?, coveredRuns, runningScore, timeLeftMs}` + the static path (`Minigames/Types`): the pacer at `now`; the cursor
from the latest sample (`distance` and `cursorArc` from the path's nearest point around the pacer, `onPath` = distance ≤
halfWidth, `paceLag` = cursorArc − pacerArc on the path); `accuracySoFar` = A over the ticks so far; `credit` = the
latest tick's accuracy (0 when it did not grind, nil before the first tick) and `coveredRuns` = the covered bins as runs
{first, last, …}, for §12.8's trail and tint; `runningScore` = q(C·(wAccuracy·A + (1 − wAccuracy)·P)) over the ticks
so far, C over the bins the pacer has passed, so it ends equal to the score **[Decision to confirm]** (O14). Feedback
`GrindStart/Stop` (a sample's grind flag changes), `OnPath/OffPath` (a grinding tick's d ≤ halfWidth changes; off
before the first), `PaceWarn(±1)` (|s_c − s*| first exceeds paceTol on the band; +1 ahead), `Coverage(25…100)` (the
tick that reaches each quarter of the bins), `End` (after the last tick).
```

### §6.11 Feedback contract: TimingStrike's latency (lines 1824–1826; G15)

This goes with the Recorder's horizon (D4), whose §6.2 and §12.5 edits are slice 7's: the host advances HoldZone and
TimingStrike to `rec:horizonMs(...)`, which for TimingStrike is the offset-shifted press time base.

Old:

```
Views come from `advance(now)` each RenderStepped (≤ 1 frame + 10 ms latency); FeedbackEvents drive audio and VFX
only; every state is shown by shape or position and by colour; the server's result replaces the provisional score
with no "mismatch" state.
```

New:

```
Views come from `advance` each RenderStepped (≤ 1 frame + 10 ms latency), except TimingStrike's decisions (`Miss`,
`lastGrade`, `combo`, `runningScore`), which follow the Recorder's horizon, the frame's centre less `timingOffsetMs`:
up to 120 ms after the frame for a positive offset, up to 120 ms before it for a negative one (a `Miss` can show while
the needle is still in the drawn window), as they must to equal the replay; its dial and `CycleStart` follow the raw
clock (§6.9). FeedbackEvents drive audio and VFX only; every state is shown by shape or position and by colour; the
server's result replaces the provisional score with no "mismatch" state.
```

### §14.6: T-MG-13 (lines 3906–3907; M4's I2)

E-S8.5 cites "11, 13, 14 as §14.6", but §14.6 defines no T-MG-13. Its part (a), the hand-written E-S3 goldens, is in
slices 3–5's family specs; part (b), the blessed golden, is slice 8's.

Old:

```
- **T-MG-11** Perfect at 30 fps ≥ PERFECT_30FPS_MIN_SCORE at every tier; TimingStrike full-points core ≥ 9 ms.
- **T-MG-14** a HIGH flag gives score = min(rawScore, pass line), `passed` = (rawScore ≥ pass line), rawScore kept for
```

New:

```
- **T-MG-11** Perfect at 30 fps ≥ PERFECT_30FPS_MIN_SCORE at every tier; TimingStrike full-points core ≥ 9 ms.
- **T-MG-13** the S3 goldens: E-S3.3–E-S3.5 and E-S3.7's patterns, hashes and scores (the trace's on
  `tests/fixtures/Edges`), and `minigames.bv<N>.golden.txt`.
- **T-MG-14** a HIGH flag gives score = min(rawScore, pass line), `passed` = (rawScore ≥ pass line), rawScore kept for
```

### §14.7 Fixtures: `Edges` and X08's edge (lines 3920 and 3929–3931)

Old (line 3920):

```
and expected codes: E-S8.4. Modules: `tests/fixtures/{Blueprints, Adversarial, Calibration, Regression, Cost}`, the
```

New:

```
and expected codes: E-S8.4. Modules: `tests/fixtures/{Blueprints, Adversarial, Calibration, Regression, Cost, Edges}`, the
```

Old (lines 3929–3931, the end of the X08 bullet):

```
  P1 (X08b, 24 overlapping hitbox-sized blocks) and P5 (X08c, the sawtooth blade), E-S8.4's 256-point zigzag edge an
  `EdgeChain` for M4's T-PERF-02; P1–P5 S2's cost fixtures (P1 the adversarial one, §4.9), and P1–P3 with a Dust speck,
  floating (measured with `measureInvalid`) or attached (valid).
```

New (and a new bullet after it):

```
  P1 (X08b, 24 overlapping hitbox-sized blocks) and P5 (X08c, the sawtooth blade), E-S8.4's 256-point zigzag edge
  `Cost.X08_EDGE` (= `Edges.zigzag`, the chain with its grip) for M4's T-PERF-02; P1–P5 S2's cost fixtures (P1 the
  adversarial one, §4.9), and P1–P3 with a Dust speck, floating (measured with `measureInvalid`) or attached (valid).
- `Edges`: S3's nine reference blade edges (E-S3.5: arming, longsword, dagger, sabre, flamberge, the arming sword with
  its grip tilted 30°, serrated, saw, zigzag) as S2 hands an edge to Sharpening (`{ chains, gripPoint, gripAxis }`),
  the doubles of the S3 prototype's `Blades.luau` pasted as literals. M4's goldens and statistics trace them, never
  `Analyze.run`'s edges, so a change in Physics cannot move them (M4's D6).
```

### §17.1: O13 and O14 (new rows after O11, and after the shift fix's own new row if it adds one; L4)

New:

```
| O13 | (S3, S6) TimingStrike's combo (§6.9, §12.7's "combo ×5", `bestCombo` in §6.14's breakdown): +1 for each span decided with points above 0 (Perfect, Good or Ok); a span decided with 0 points (a miss, or a press past the window) resets it; stray presses (whiffs) leave it alone? Feedback only: never stored, no effect on the score or BALANCE. | as stated; the alternative: only Good or better keeps a combo (harder to hold) |
| O14 | (S3, S6) The live score shown while playing (§12.2): the mean so far, so it says how well the player is doing now (HoldZone: the credit of the scored ticks so far; TimingStrike: the points of the spans decided so far; PrecisionTrace: the accuracy and pace means so far times the coverage of the arc the pacer has passed)? Display only: the server's result replaces it. | as stated; the alternative: the points earned so far over the whole step, a bar that fills to the final score |
```

### SPEC-evidence.md: for E-S3.10 "M4 as built" (a new section the plan's [12] gives the lead at slice 11)

From slices 3–5, measured as `docs/build/M4-notes.md` (B2) says:

- The build reproduces E-S3.4's TimingStrike golden (N 12, W 110, core 13.2, M 200, 10971 ms, 0xE2D4F2AE, the
  worked presses' points and score 0.8084), E-S3.7's HoldZone golden (10 keys, 0x4E2677F2, the 300 ms taps' 0, the
  stroke curves) and E-S3.5's trace golden and all nine rows of its blade table exactly. On random configurations it
  matches the prototype's generate, replay and checks bit for bit (TimingStrike's judged errors; HoldZone's
  unquantized credit, n, T and F; the trace's source, path arrays, hash and unquantized accuracy, pace and coverage
  sums).
- The S3 prototype's groupings that differ from the SPEC's pseudo-code: HoldZone's `F − F·(10/fireDecayMs)` and
  `F − F·10/fireDecayMs` differ in the last bit for 0.10 % of uniformly random F at 600 (1.0 % / 1.8 % at 300 / 550),
  which the full-precision parity sees in the shipped runs; the trace's travel time is `ceil(L/pacerSpeed·1000/20)·20`.
- The trace's cross-axis clamp (`E = 0.76/(s·range c)` under 2) never binds on the nine reference blades (the widest
  0.6 stud: 2.11).

## Builder 3: the wire format, the Recorder and the facade (slices 6–7), L6

These edits state what `Minigames/Timeline`, `Input`, the `Minigames` facade and `tests/lib/Cheats` do as built: the
Recorder's horizon and per-frame push (M4's D4), its stamps and caps (D7, D9, I7, G5), the oversize-buffer refusal
(D8), the trace's record cap the lead adopted after its proof (L6), the narrow edge of `Pipeline.stepInput` (G13), and
the cheat builders. `docs/build/M4-notes.md` (B3) has the proof and the measurements.

### §4.8 `Pipeline.stepInput`: the narrow edge (lines 1212–1214; M4's G13)

M5 builds `PrepareInput.edge` as the narrow table §6.2 types, not the `EdgeProfile` itself;
`tests/Minigames/MinigamesHelpers.stepInputFrom` is that mapping, typed from `Analyze`'s exports, and luau-lsp accepts
it.

Old:

```
Pipeline.stepInput(report: Report, stepIndex: number, seed: number): Minigames.PrepareInput
	-- { family = Steps[step].family, seed, material = steps[i].material, tier = steps[i].tier,
	--   factors = steps[i].factors, edge = analysis.edge (PrecisionTrace only), balanceVersion }
```

New:

```
Pipeline.stepInput(report: Report, stepIndex: number, seed: number): Minigames.PrepareInput
	-- { family = Steps[step].family, seed, material = steps[i].material, tier = steps[i].tier,
	--   factors = steps[i].factors, edge = { chains, gripPoint, gripAxis } of analysis.edge (PrecisionTrace only),
	--   balanceVersion }
```

### §6.2 Modules and API: the facade's cap and re-export, the Recorder's horizon (lines 1607–1608, 1615–1618; D4, L6)

Old (lines 1607–1608):

```
Minigames.encode(spec: StepSpec, records: { any }): buffer
Minigames.get(family: FamilyId): FamilyModule<any, any, any, any>
```

New (lines 1607–1608):

```
Minigames.encode(spec: StepSpec, records: { any }): buffer
Minigames.get(family: FamilyId): FamilyModule<any, any, any, any>
Minigames.recordCap(spec: StepSpec): number   -- the most records judge accepts: MAX_RECORDS, Trace floor(durationMs/20) + 1
Minigames.TS_OFFSET_OFFER_MIN_JUDGED: number  -- TimingStrike's, re-exported for S6's results card (§6.9)
```

Old (lines 1615–1618):

```
Input.new(spec: StepSpec, timingOffsetMs: number, goClockS: number): Recorder   -- clockS below is on goClockS's clock
	-- (os.clock() in S6's InputCapture; seconds with GO = 0 in Bots and autoplay). :go(held, u?, v?, grind?) records the
	-- state at GO (t = 0); :button(down, clockS, frameDtS), :cursor(u, v, grind, clockS), :release(), :records();
	-- the only producer of records (S6 InputCapture, Bots, autoplay)
```

New (lines 1615–1618):

```
Input.new(spec: StepSpec, timingOffsetMs: number, goClockS: number): Recorder   -- clockS below is on goClockS's clock
	-- (os.clock() in S6's InputCapture; seconds with GO = 0 in Bots and autoplay). :go(held, u?, v?, grind?) records the
	-- state at GO (t = 0; the trace needs u, v); :button(down, clockS, frameDtS), :cursor(u, v, grind, clockS),
	-- :release(), :records(); :horizonMs(clockS, frameDtS), the time the host may advance the session to, and
	-- :since(count), the records after the first count, for its per-frame push (§12.5); the only producer of records
	-- (S6 InputCapture, Bots, autoplay)
```

### §6.4 rule 7: live = replay with the horizon (lines 1640–1643; D4, G1)

With a positive `timingOffsetMs` the records trail the frame clock by up to 120 ms, so a host advancing TimingStrike to
the raw frame time can close a span as a Miss before the offset press that decides it arrives (`Input.spec` pins the
case: E-S3.4's span 1, offset +120). The Recorder hands out a horizon in the records' time base and stamps every later
record at or after it. Builder 1's edit of rule 2 (lines 1635–1636) is separate.

Old:

```
`Util/Quantize.q(x, 1e4)` and `passed` is computed on it. 7. SD = sample SD (n − 1); trace normals are left normals
`(−Δv, Δu)/|Δ|`. Live = replay because the client advances HoldZone only to its latest record time, TimingStrike
closes a span only once `now > T_i + M`, and PrecisionTrace evaluates only ticks up to its latest sample
(0 mismatches, E-S3.6).
```

New:

```
`Util/Quantize.q(x, 1e4)` and `passed` is computed on it. 7. SD = sample SD (n − 1); trace normals are left normals
`(−Δv, Δu)/|Δ|`. Live = replay because the client advances HoldZone and TimingStrike only to the Recorder's horizon
(`horizonMs`: the latest button stamp it handed out, in the records' time base, so TimingStrike's after the timing
offset), and every later record is stamped at or after it; TimingStrike closes a span only once `now > T_i + M`;
PrecisionTrace evaluates only ticks up to its latest sample; and at GO + durationMs the host pushes the records made
since the last frame before `finish` (§12.5; 0 mismatches, E-S3.6).
```

### §6.6 Step timing and input capture: the rows the Recorder settles (lines 1673–1675, 1679–1680; D7, D9, I7, G5, L6)

The Clock row gains TimingStrike at GO (D9); the Button time row the order of the floors (`Input.spec` pins a press
whose frame's centre falls before GO: at offset −120 it records 120, not 114), the clamp to the horizon and D7's exact
clocks; the Trace samples row the first record at t = 0 as §6.2 and §12.5 write it (I7); the Focus row the release's
stamp (G5); the Caps row the exact bound and the judge that enforces it (L6).

Old (lines 1673–1675):

```
| Clock | `goClock` = StepOpenView receipt + `countdownMs` (`COUNTDOWN_MS` 3000, `Definitions/Network`). The pattern shows during the countdown, inputs are ignored; a press held at GO records `{t = 0, down}` (one stroke), the trace records its cursor at GO. |
| Button time | `t = max(0, floor((os.clock() − goClock)·1000 − frameDtMs/2))` (latest RenderStepped delta). TimingStrike then subtracts `timingOffsetMs` (−120…+120, default 0, S1 settings), floored at 0. |
| Trace samples | One record at the first frame at or after each due time 0, 20, 40 … ms, `t = floor((os.clock() − goClock)·1000)`, with that frame's grind state; grind changes make no records. |
```

New (lines 1673–1675):

```
| Clock | `goClock` = StepOpenView receipt + `countdownMs` (`COUNTDOWN_MS` 3000, `Definitions/Network`). The pattern shows during the countdown, inputs are ignored; a press held at GO records `{t = 0, down}` (one stroke), the trace records its cursor at GO, TimingStrike records nothing (a strike needs a press after GO; holding does not repeat). |
| Button time | `t = max(0, floor((os.clock() − goClock)·1000 − frameDtMs/2))` (latest RenderStepped delta). TimingStrike then subtracts `timingOffsetMs` (−120…+120, default 0, S1 settings), floored at 0. Then `t = max(t, the last record's t, the horizon)`: no record precedes a time the session was advanced to (§6.4 rule 7). Bots and autoplay pass an exact ms t as `clockS = (t + 0.5)/1000` with `frameDtS = 0` (t/1000 falls one ulp short for 372 integers t ≤ 60,000). |
| Trace samples | The first record at t = 0 (`:go`, the cursor at GO), then one at the first frame at or after each due time 20, 40 … ms (the next multiple of 20 after the last record), `t = floor((os.clock() − goClock)·1000)`, with that frame's grind state; grind changes make no records. |
```

Old (lines 1679–1680):

```
| Focus, menu | `WindowFocusReleased` and `GuiService.MenuOpened` release the OR-state (up record if down) and reset key state; a held key counts after a new InputBegan. Each frame, a press with neither `IsKeyDown(Space)` nor `IsMouseButtonPressed(MouseButton1)` records its release. No pause **[Decision to confirm]** (Q16). |
| Caps | HoldZone records OR-state changes only, no new press at `MAX_RECORDS − 1`; TimingStrike drops presses past the cap; Trace makes ≤ `durationMs/20 + 1` = 1,551. **An unmodified client never sends a timeline decode rejects.** |
```

New (lines 1679–1680):

```
| Focus, menu | `WindowFocusReleased` and `GuiService.MenuOpened` release the OR-state (up record if down, stamped at the latest known time: the last record's or the horizon) and reset key state; a held key counts after a new InputBegan. Each frame, a press with neither `IsKeyDown(Space)` nor `IsMouseButtonPressed(MouseButton1)` records its release. No pause **[Decision to confirm]** (Q16). |
| Caps | HoldZone records OR-state changes only, no new press at `MAX_RECORDS − 1`; TimingStrike drops presses past the cap; Trace makes ≤ `floor(durationMs/20) + 1` (the one at GO, then at most one per 20 ms slot: 1,551 at the longest MVP step, 31 s), which `judge` enforces (§6.7). **An unmodified client never sends a timeline decode or judge rejects**: `Timeline.encode` refuses any record decode would, and the Recorder never exceeds the judge's trace cap (§6.7). |
```

### §6.7 Timeline wire format: D8 and the judge's trace cap (lines 1689–1692; D8, G9, L6)

§10.3 has Submit refuse an oversize buffer as `TooMany`, while §6.7's order would read a long buffer with a small count
as `Length` (G9); decode now refuses it in the `TooMany` slot, before reading any record. L6: the lead's rule, adopted
after the proof in `docs/build/M4-notes.md` (B3).

Old:

```
2.3–4.2 KB. Decode order, first failure wins: `NotBuffer`, `Short` (< 12 B), `Version`, `Family`, `TooMany`, `Length`
(≠ 12 + n·size), `Duration` (≠ pattern's); per record `NotIncreasing` (Trace dt = 0 after the first), `PastEnd`,
`BadKind`, `NotAlternating` (kinds alternate from down), `OutOfPanel` (uQ > 49152, vQ > 16384), `BadFlags`. Then
`judge` checks `HashMismatch`.
```

New:

```
2.3–4.2 KB. Decode order, first failure wins: `NotBuffer`, `Short` (< 12 B), `Version`, `Family`, `TooMany` (count >
`MAX_RECORDS`, or more bytes than the family's cap 12 + `MAX_RECORDS`·size, §10.3, refused before any record is
read), `Length` (≠ 12 + n·size), `Duration` (≠ pattern's); per record `NotIncreasing` (Trace dt = 0 after the first),
`PastEnd`, `BadKind`, `NotAlternating` (kinds alternate from down), `OutOfPanel` (uQ > 49152, vQ > 16384), `BadFlags`.
Then `judge` refuses a Trace timeline of more than `floor(durationMs/20) + 1` records as `TooMany` (`Minigames.recordCap`;
no unmodified client makes more, §6.6 Caps), then checks `HashMismatch`. `Timeline.encode` refuses any record decode
would; `Timeline.capBytes(family)` is a family's cap.
```

### §6.10: a source at the length bound (lines 1784–1785)

The hand-off's length bound is checked before the 1/16384 rounding and `generate`'s after it (M4-notes B3, finding 1: a
2-point chain mapped to 0.4000028 u gives a source 0.39996 u long). Client and server agree either way.

Old:

```
A main chain up to 10 studs long (S2's EdgeLength range is 4.8–8.0) always plays whole (E-S3.5). Fallback edge
**[Decision to confirm]** (Q15; alternative: S4 skips Sharpening).
```

New:

```
A main chain up to 10 studs long (S2's EdgeLength range is 4.8–8.0) always plays whole (E-S3.5). A source within
a few 1/16384 u of 0.4 (rounding moves each point up to 0.71/16384 u) can pass the hand-off's bound and fall under
`generate`'s once rounded: the fallback plays, and `prepare` then sends no source. Fallback edge
**[Decision to confirm]** (Q15; alternative: S4 skips Sharpening).
```

### §10.3: the family cap (lines 2664–2666; D8)

S5 calls only the facade (§6.2), and `judge` already refuses a buffer over its family's cap: decode's size checks come
right after the header's four, before any record is read (`Timeline.decode`), so the check costs O(1) and Submit relies
on it rather than calling `Timeline.capBytes` (M4's fix round 1).

Old:

```
`MAX_TIMELINE_BYTES` = S3's header + largest family cap (12 + 2048 · 7 = 14 348), derived from
`Definitions/MinigameFamilies`. Submit also checks the step family's own cap `12 + MAX_RECORDS · RECORD_BYTES`
before judging; over it is an S3 Invalid (`TooMany`).
```

New:

```
`MAX_TIMELINE_BYTES` = S3's header + largest family cap (12 + 2048 · 7 = 14 348), derived from
`Definitions/MinigameFamilies`. The step family's own cap 12 + MAX_RECORDS · RECORD_BYTES is `judge`'s: over it is an
S3 Invalid (`TooMany`), which decode returns in its `TooMany` slot (§6.7's order), an O(1) check of the header's count
and the buffer's length before any record is read; Submit relies on it and makes no `Timeline` call (§6.2).
```

### §10.5 Minigame replay: the cap step, the hand-off's cost and one Studio target (lines 2711–2712, 2731–2737, 2739–2740; L6, I8)

L6: the trace cap bounds the records `judge` replays at the honest maximum, `floor(durationMs/20) + 1`. It bounds their
count, not their cost: the same count spread over travel, every sample grinding (each sample in travel pays the
checks' nearest-point search), costs about 2 % more than the honest timeline, one sample per 20 ms from GO (1,479
records on the length-bound source: reviewer V1 in M4's review round 1, 2.53 / 2.46 / 2.46 ms against 2.49 / 2.41 /
2.40 ms at 26 / 8 / 7 % busy; the fix round, × 1.017–1.043 at 34–68 % busy). So §10.5's 7 ms is the one Studio target
for `judge`, on that spread timeline; §17.2's S5 row keeps × 2.6 (20.8 ms) as the trigger for the AnalysisQueue
fallback, which M7's S-PERF-01 measures. T-PERF-02 times all three families at their caps (the lead's slice 10).

The table's `prepare` for Sharpening was `generate` alone, but `prepare` also runs the edge hand-off, whose
Douglas–Peucker attempts were most of it on X08's zigzag (3.75–3.80 of 4.05–4.10 ms, the machine quiet) until M4's
fix round 1 gave the attempts one split tree (now 0.81–0.82 of 1.08–1.09 ms); E-S3.10 (fix round 1) has the
measurements.

Old (lines 2711–2712):

```
1 decode   records, hash = Timeline.decode(timeline, spec.family, spec.durationMs)   → Invalid(reason)   (§6.7)
2 hash     hash ≠ spec.patternHash                                                   → Invalid("HashMismatch")
```

New (lines 2711–2712):

```
1 decode   records, hash = Timeline.decode(timeline, spec.family, spec.durationMs)   → Invalid(reason)   (§6.7)
  cap      #records > Minigames.recordCap(spec) (Trace: floor(durationMs/20) + 1)    → Invalid("TooMany")
2 hash     hash ≠ spec.patternHash                                                   → Invalid("HashMismatch")
```

Old (lines 2731–2737):

```
Server cost of one step (Lune ms; Studio ≈ ×2.6, §4.9), worst honest cases (E-S3.5):

| Family | `prepare` (generate) | `judge` (decode + replay + checks) |
|---|---|---|
| HoldZone | 0.04 | 0.35 (1,000 records, 18 s) |
| TimingStrike | 0.03 | 0.04 |
| PrecisionTrace | ≤ 1.9 on every reference blade, 2.5 at the length bound | ≤ 2.6 (29.6 s, 1,479 records; decode 0.12) |
```

New (lines 2731–2737):

```
Server cost of one step (Lune ms; Studio ≈ ×2.6, §4.9), worst honest cases (E-S3.5; the trace's hand-off, E-S3.10):

| Family | `prepare` (hand-off + generate) | `judge` (decode + replay + checks) |
|---|---|---|
| HoldZone | 0.04 (no hand-off) | 0.35 (1,000 records, 18 s) |
| TimingStrike | 0.03 (no hand-off) | 0.04 |
| PrecisionTrace | ≤ 0.3 + 1.9 on every reference blade but the zigzag (of theirs, the saw's Douglas–Peucker the costliest hand-off), 0.82 + 0.25 on the zigzag (X08's 256-point edge: eight attempts, the costliest hand-off), 0.1 + 2.5 at the length bound | ≤ 2.6 (29.6 s, 1,479 records; decode 0.12) |
```

Old (lines 2739–2740):

```
`judge` runs synchronously in the Submit handler and `prepare` as one P0 burst of S5's AnalysisQueue (§1.6), each
≤ 7 ms in Studio; S8's `REPLAY_BUDGET_MS` and `PT_GENERATE_BUDGET_MS` follow (§14.11).
```

New (lines 2739–2740):

```
`judge` runs synchronously in the Submit handler and `prepare` as one P0 burst of S5's AnalysisQueue (§1.6), each
≤ 7 ms in Studio, `judge` on the longest timeline it accepts with its records spread over travel (the Trace's cap
bounds the records at the honest maximum, 1,551 at 31 s, not their cost: spread so, they cost about 2 % more than the
honest timeline); S8's `REPLAY_BUDGET_MS` and `PT_GENERATE_BUDGET_MS` follow (§14.11).
```

### §12.5 Minigame host and input: the host loop (lines 3271–3277; D4, D12, [3.6])

The host advances to the Recorder's horizon and pushes once more before `finish`; without that push a record made after
the last frame's push (a focus-loss release, a last press) is in the timeline but not in the session, and the client's
score differs from the server's (`Input.spec` pins a HoldZone press the last tick reads).

Old:

```
- StartStep reply: `Minigames.start(spec)` (S3) rebuilds the pattern (mismatch → §12.1);
  `goClock = os.clock() + spec.countdownMs/1000` at receipt; the host creates
  `Input.new(spec, settings.timingOffsetMs, goClock)` and calls `:go(…)` on the first frame at or after GO;
  `t = floor((os.clock() − goClock)·1000)` ms. `BindToRenderStep("MinigameView", Camera + 1)`: InputCapture pushes the
  frame's records, the host calls `advance` (FeedbackEvents → §12.10), then `render(view(session, t))`. Submit via
  `task.delay` at goClock + durationMs: `Minigames.encode(spec, records)` → buffer,
  `clientScore = finish(session).score`.
```

New:

```
- StartStep reply: `Minigames.start(spec)` (S3) rebuilds the pattern (mismatch → §12.1);
  `goClock = os.clock() + spec.countdownMs/1000` at receipt; the host creates
  `Input.new(spec, settings.timingOffsetMs, goClock)` and calls `:go(…)` on the first frame at or after GO;
  `t = floor((os.clock() − goClock)·1000)` ms. `BindToRenderStep("MinigameView", Camera + 1)`: InputCapture feeds the
  frame's inputs to the Recorder, the host pushes `rec:since(pushed)` into the session, calls `advance(session,
  rec:horizonMs(os.clock(), dt))` (FeedbackEvents → §12.10; TimingStrike's `CycleStart` at GO and whenever
  `view.cycle` changes, on the raw clock, §6.9), then `render(view(session, t))`. Submit via `task.delay` at goClock +
  durationMs: push `rec:since(pushed)` once more, then `Minigames.encode(spec, rec:records())` → buffer,
  `clientScore = finish(session).score`.
```

### §14.3: `Cheats` (line 3758)

Old:

```
`Gen` builds swords and garbage; `Cheats` builds the §14.8 cheat inputs with the passed-in `Minigames` (E-S8.5).
```

New:

```
`Gen` builds swords and garbage; `Cheats.new({ Timeline, MinigameFamilies, Minigames?, Bots? })` builds the §14.8
cheat inputs from the passed-in modules (E-S8.5): the decode-level ones from the codec alone, `flood`'s judge-cap
timeline with the facade, `exact` with `Bots`.
```

### §16.32 `tests/lib/Tol`: the quick sizes (lines 4661–4662; D10)

`PROP_N_FAST` has been in `tests/lib/Tol` since slice 4 (builder 2) without its row; `FUZZ_N_STRUCT_FAST` is slice 6's.
Builder 4 adds D10's other rows.

Old:

```
| PROP_N | 200 | cases | S8 | cases per property in the fast set |
| FUZZ_N_GARBAGE | 2000 | values | S8 | hostile values per untrusted-input function (P-TOTAL) |
```

New:

```
| PROP_N | 200 | cases | S8 | cases per property in the fast set |
| PROP_N_FAST | 25 | cases | S8 | the quick run's cases for a property that replays whole minigame sessions (M4's L1 share); `PROP_N` under `t.slow` |
| FUZZ_N_GARBAGE | 2000 | values | S8 | hostile values per untrusted-input function (P-TOTAL) |
| FUZZ_N_STRUCT_FAST | 200 | values | S8 | the quick run's structured timelines per family (T-MG-08, M4's L1 share); `FUZZ_N_GARBAGE` under `t.slow` |
```

### §17.2's S5 row: the judge's timeline (line 4767; L6, I8)

Old:

```
| S5 | `Minigames.judge` runs synchronously in Submit: if S-PERF-01 measures it above `REPLAY_BUDGET_MS` × 2.6 in the Studio server, S3 adds a checkpoint and CraftService moves it into the AnalysisQueue (with S3). |
```

New:

```
| S5 | `Minigames.judge` runs synchronously in Submit: if S-PERF-01 measures it, on the longest timeline it accepts with its records spread over travel (the Trace's record cap bounds their count at the honest maximum, §6.7, not their cost: spread so, they cost about 2 % more than the honest timeline, §10.5), above `REPLAY_BUDGET_MS` × 2.6 in the Studio server, S3 adds a checkpoint and CraftService moves it into the AnalysisQueue (with S3); §10.5's 7 ms is the target. |
```

### SPEC-evidence.md E-S8.5: T-MG-08 and 15, and the cheats (lines 3206–3210, 3228–3230)

T-MG-08 as built (decode and judge levels); T-MG-15's "keeps flag decisions" stated for the unquantized Exact presses
(the plan's [12]: a 60 fps Perfect run is never flagged, so it could not show a kept flag); the cheats as
`tests/lib/Cheats` builds them. T-MG-09's text stays slice 8's.

Old (lines 3206–3210):

```
- **T-MG** 01 `prepare`/`judge` deterministic, StepSpec complete · 02 `passed` ⇔ Ok ∧ score ≥ pass line · 03
  solvability · 04 bands, fail rates (L3) · 05 profile order, Normal → Hard drop · 06 Iron − Steel · 07 `Params` =
  product of modifiers, S3's clamp and quantum · 08 2,000 garbage buffers · 09 live session = `judge` on 1,000 random
  frame partitions · 10 FP and TP runs (L3) · 11, 13, 14 as §14.6 · 12 fairness · 15 `timingOffsetMs` keeps flag
  decisions, press times floored at 0 · 16 releases always recorded (focus loss, menu open).
```

New (lines 3206–3210):

```
- **T-MG** 01 `prepare`/`judge` deterministic, StepSpec complete · 02 `passed` ⇔ Ok ∧ score ≥ pass line · 03
  solvability · 04 bands, fail rates (L3) · 05 profile order, Normal → Hard drop · 06 Iron − Steel · 07 `Params` =
  product of modifiers, S3's clamp and quantum · 08 2,000 garbage values and structured timelines per family (200 in
  the quick run), one hand-written byte golden per family, one planted timeline per decode reason, first failure
  wins, never a throw, through `decode` and `judge` · 09 live session = `judge` on 1,000 random frame partitions · 10
  FP and TP runs (L3) · 11, 13, 14 as §14.6 · 12 fairness · 15 `timingOffsetMs` is TimingStrike's alone and shifts
  every press alike, so the unquantized Exact presses keep `TsLowVariance` at every offset and `TsExactHits` only at
  \|offset\| ≤ 1; press times floored at 0 · 16 releases always recorded (focus loss, menu open).
```

Old (lines 3228–3230):

```
- **Cheats**: Exact (Perfect timeline, unquantized) · Fast (honest timeline sent before `D − EARLY_TOL_MS`) · Flood
  (records past the family cap) · Malformed (one per decode reason) · Replay (same step twice; an old timeline on a new
  seed) · Forged (extra keys, other session id). **Gen**: `validSword`, `garbage`, `withFiller`, `segmented`, `translated`.
```

New (lines 3228–3230):

```
- **Cheats**: Exact (Perfect timeline, unquantized) · Fast (honest timeline sent before `D − EARLY_TOL_MS`) · Flood
  (records past the family cap, bytes past it, a Trace one record past its judge cap) · Malformed (planted values per
  decode reason, each reading exactly it) · Replay (same step twice; an old timeline on a new seed, its duration
  rewritten so the hash refuses it) · Forged (extra keys, other session id). **Gen**: `validSword`, `garbage`,
  `withFiller`, `segmented`, `translated`.
```

### README.md: `tests/lib` (lines 28–29)

The lead's slice 11 adds `tests/Minigames/` and the new fixtures to the tree.

Old:

```
├── lib/                   Test, Assert, Prop, TestRng, Dump, Golden, Tol, Gen (requires nothing in src/: specs
│                          pass Definitions in); Cheats arrives with M4 (SPEC §14.2)
```

New:

```
├── lib/                   Test, Assert, Prop, TestRng, Dump, Golden, Tol, Gen, Cheats (requires nothing in src/:
│                          specs pass the modules in)
```

### SPEC-evidence.md: for E-S3.10 "M4 as built" (slices 6–7)

From `docs/build/M4-notes.md` (B3):

- The Recorder's stamps equal the S3 prototype bots' on random frames (12 runs at 30–240 fps: every press at
  `Bots.stamp`, every trace sample at `ptHuman`'s due rule, the first at t = 0 instead of floor(f₁)); D7's exact clocks
  give every integer ms up to 60,000, where t/1000 falls short for 372 of them.
- L6's proof: after GO's record each trace record lies in a later 20 ms slot than the one before, so a Recorder makes at
  most `floor(durationMs/20) + 1` (1,551 at 31 s) whatever its frames, hitches or focus losses; a property over frame
  times 1–100 ms with hitches up to 250 ms at the longest MVP step confirms it, and `judge` refuses more.
- The host loop (§12.5 with the horizon and the final push) finishes as `judge` on random frames, offsets −120…+120,
  focus losses and inputs after the last frame, in all three families, its live score ending at the score; advancing
  TimingStrike to the raw frame time with offset +120 turns a judged press into a whiff (E-S3.4's span 1).
- The codec: one hand-written byte golden per family; every decode reason planted and read; 2,000 garbage values and
  structured timelines per family never throw.

## Builder 4: the bots, the frozen timelines and the L3 statistics (slice 8), and slices 9–11 for the lead

These edits state what `Minigames/Bots`, `tests/fixtures/MinigameTimelines` and the L3 statistics do as built, with
O4's default (L3), the FP devices (G17), the trace margin (G19, L7), the tests' new definitions (G6, G16, G18, I3) and
D10's sizes. `docs/build/M4-notes.md` (B4) has the precomputes and the measurements. Two edits below change text an
earlier builder's edit wrote (§14.6's T-MG-11, §14.7's module list, E-S8.5's T-MG row): apply those first.

### §6.12 Player models: the policy fields, Exact and the Recorder (lines 1851–1854; the plan's [3.11])

Old:

```
HoldZone uses the tap policy (hold-and-release scores 0 under strokes). Test-only extremes: **Perfect** (TimingStrike:
exact intent, no lag, 60 or 30 fps; HoldZone: strokes chosen by a 300 ms look-ahead on the exact state, flagged
`HzInhumanRate`; PrecisionTrace: on the pacer every 20 ms, flagged) and **Idle** (no input). Bots may use libm
(lines tagged `-- allow-transcendental: <reason>`, §14.4).
```

New:

```
HoldZone uses the tap policy (hold-and-release scores 0 under strokes; the hold policy, kept for tuning, adds per
profile a hysteresis band of 0.15 / 0.25 / 0.30 / 0.40 × zoneWidth/2, a minimum gap of 70 / 90 / 130 / 170 ms and a
minimum hold of 60 / 70 / 90 / 120 ms). A device variant changes `fps` and the panel (`Bots.variant`: Average@30,
Elite@30/360). Every bot input goes through `Input`'s Recorder (§6.2) at the frame that delivers it; a bot acting at an
exact ms passes `clockS = (t + 0.5)/1000` and `frameDtS = 0`. Test-only extremes: **Perfect** (TimingStrike: exact
intent, no lag, 60 or 30 fps; HoldZone: strokes chosen by a 300 ms look-ahead on the exact state, flagged
`HzInhumanRate`; PrecisionTrace: on the pacer every 20 ms, flagged), **Exact** (E-S8.5's cheat: TimingStrike's presses
at the exact targets, unquantized; HoldZone and PrecisionTrace as Perfect) and **Idle** (no input). Bots may use libm
(lines tagged `-- allow-transcendental: <reason>`, §14.4), so their records can differ between C runtimes where the
judge's results cannot: goldens judge frozen bot timelines (§14.7's `MinigameTimelines`).
```

### §6.13 Calibration: the Steel drops on paired runs (lines 1858–1860; O4, L3)

Old:

```
Steel's columns are tighter in every family (above); Average and Poor score lower on Steel everywhere (Average Normal
−0.016 / −0.012 / −0.009), but at HoldZone the Elite scores slightly higher on Steel (+0.012 Normal, +0.005 Hard; Good
+0.001 Normal), where Steel's zone sits higher on the gauge **[Decision to confirm]** (Q13). 2,000 runs per cell,
```

New:

```
Steel's columns are tighter in every family (above); Average and Poor score lower on Steel everywhere (Average Normal
−0.016 / −0.012 / −0.009 in this table; on paired runs, T-MG-06's with the table's, −0.0155 ± 0.0010 / −0.0089 ±
0.0010 / −0.0117 ± 0.0014, so hammering, not sharpening, plays less than a point harder: `STEEL_MEAN_DROP`'s floor is
0.005 **[Decision to confirm]** (O4)), but at HoldZone the Elite scores slightly higher on Steel (+0.012 Normal, +0.005
Hard; Good +0.001 Normal), where Steel's zone sits higher on the gauge **[Decision to confirm]** (Q13). 2,000 runs per cell,
```

### §14.1: the L3V row's list (on Builder 1's new row) and the measured figures

In Builder 1's new L3V row, "T-MG-06" becomes "T-MG-06's paired runs". T-MG-04's Q8 fail-rate extension stays in plain
L3: M4's plain L3 measures about 3–4 minutes at this machine's ordinary load (below), so L3 stays inside 10 minutes
quiet with it (L5). Builder 1's parenthetical note under the rows can go. For slice 11's parenthesis of the L1 row, M4's
`Minigames/` share at slice 8's end: 1.85–1.90 s by the runner at 17–32 % busy, no other Lune process (19 Nov 07:01);
the whole `--quick` run (verify's tests stage) 38.30 s at 31–67 % busy beside three of the other team's Lune
processes, so the quiet figure is the lead's. M4's plain L3 (`--filter "Minigames/"`): 173.33 s at 6–76 % busy.

### §14.6 Module test plans: T-MG-03 to 06, 11 and 12 (lines 3909–3911, and T-MG-11 in Builder 2's new text; G6, G16, G18, I3)

Old (Builder 2's new T-MG-11 line, which is `f7ac37d`'s line 3906):

```
- **T-MG-11** Perfect at 30 fps ≥ PERFECT_30FPS_MIN_SCORE at every tier; TimingStrike full-points core ≥ 9 ms.
```

New:

```
- **T-MG-11** Perfect at 30 fps ≥ PERFECT_30FPS_MIN_SCORE on every run, at every MVP tier × material × x ∈ {0, 1}
  (`SOLVABILITY_SEEDS` runs per cell in L3, 50 in L1; the placeholder tiers Expert…Hell are untuned, §17.2's S3);
  TimingStrike full-points core ≥ 9 ms.
```

Old (lines 3909–3911):

```
- L3: Perfect's mean rawScore over SOLVABILITY_SEEDS seeds per cell ≥ PERFECT_MIN_SCORE (HoldZone ≥
  PERFECT_HZ_MIN_SCORE, §6.13); Average's Normal → Hard mean drop ≥ TIER_MIN_MEAN_DROP and every other profile's
  drop positive; Iron − Steel mean in STEEL_MEAN_DROP (Q13); per-seed SD ≤ FAIRNESS_MAX_SD.
```

New:

```
- L3, each configuration seeded from its pinned name (§14.8): T-MG-03 Perfect's mean rawScore over SOLVABILITY_SEEDS
  seeds per cell ≥ PERFECT_MIN_SCORE (HoldZone ≥ PERFECT_HZ_MIN_SCORE, §6.13), and every run ≥ PERFECT_MIN_SCORE
  (HoldZone ≥ PERFECT_HZ_RUN_MIN_SCORE), since a mean cannot see the rare impossible pattern; Idle scores 0. T-MG-04
  per cell, BOT_RUNS runs: |mean − E-S3.2's mean| ≤ 4 · E-S3.2's SD/√BOT_RUNS + 0.0005 (its 3 decimals), no run
  flagged; Average and Good on BOT_RUNS_FAIL runs inside Q8's fail bands. T-MG-05 Elite > Good > Average > Poor per cell; Average's
  Normal → Hard mean drop ≥ TIER_MIN_MEAN_DROP and every other profile's drop positive. T-MG-06 every Steel column at
  least as tight as Iron's, and Average on Normal with Iron and Steel paired on one seed list, STEEL_DROP_RUNS runs:
  Iron − Steel mean in STEEL_MEAN_DROP (Q13). T-MG-12 per family × tier, FAIRNESS_SEEDS patterns × FAIRNESS_BOT_RUNS
  Average runs, the bot seeds shared across patterns: the SD over patterns of the per-pattern mean ≤ FAIRNESS_MAX_SD.
```

### §14.7 Fixtures: `MinigameTimelines` (on Builder 2's new text)

In Builder 2's new modules list, `{Blueprints, Adversarial, Calibration, Regression, Cost, Edges}` becomes
`{Blueprints, Adversarial, Calibration, Regression, Cost, Edges, MinigameTimelines}`. After Builder 2's new `Edges`
bullet, a new bullet:

```
- `MinigameTimelines`: 24 frozen bot timelines, one per family × tier × profile (Iron, the tier's reference x, the
  arming edge, run 1 of S3's distributions), as hex, made once by `Bots.play`. Golden (b) judges them (§14.9), so no
  golden depends on the bots' libm; `Minigames/Bots` checks that the bots still make them, beside a libm canary.
```

### §14.8 Player models, cheats and statistics: the FP devices and the trace margin (lines 3939–3944; G17, G19, L7)

Old:

```
- False positives, thresholds read from `Definitions/MinigameFamilies` (no copies): TimingStrike
  `FP_RUNS_TS` runs per human profile (0 flags ⇒ < 1e-5 per step at 95 %); HoldZone and Trace `FP_RUNS` (Trace:
  `FP_RUNS` on the 30 fps / 360 px Elite device only, its other devices 1,000 runs as in E-S3.8) plus margins
  (smallest mean deviation ≥ 3 × `PT_PRECISE_MEAN_DEV`, that is 0.0024 u, where S3's humans measure ≥ 0.0028 u, ×3.5,
  over 3,000 runs, E-S3.8; most presses in 1 s ≤ `HZ_RATE_MAX_PRESSES` / 3), with a 30 fps / 360 px device and the
  pumping policy (E-S8.7).
```

New:

```
- False positives, thresholds read from `Definitions/MinigameFamilies` (no copies): TimingStrike `FP_RUNS_TS` runs
  per device of E-S3.8 (Elite@240, Elite@60, Good@60, Average@30; Poor, σ 90 ms, is not run), half on Normal and half
  on Hard (0 flags ⇒ < 1e-5 per step at 95 %); HoldZone `FP_RUNS` pumping runs over Elite@60, Elite@30, Good@60 and
  Average@30 × Normal and Hard; Trace `FP_RUNS` on the 30 fps / 360 px Elite device, half per tier, and its other
  devices (Elite@240, Elite@60, Good@60, 520 px) 1,000 runs each as in E-S3.8; plus margins (smallest mean deviation ≥
  3 × `PT_PRECISE_MEAN_DEV`, that is 0.0024 u, where the pinned halves measure 0.00279 u, ×3.49, on Normal and 0.00259
  u, ×3.24, on Hard, the 0.1 % quantile 0.00304 / 0.00303 u, ×3.8, reported beside it; smallest mean jerk ≥ 3 ×
  `PT_SMOOTH_MEAN_JERK`; most presses in 1 s ≤ `HZ_RATE_MAX_PRESSES` / 3) (E-S8.7, E-S3.10). True positives,
  `TP_RUNS` runs per cheat: Exact, the trace on the pacer and 200 ms apart, HoldZone's exact-state Perfect (100) and a
  30/s autoclicker, each flagged every time; two accepted careful cheaters (Q17) are pinned: σ 4 ms TimingStrike noise
  and 0.004 u trace noise.
```

### §16.32 `tests/lib/Tol`: D10's statistical rows and O4's floor (lines 4678–4688)

Old:

```
| BOT_RUNS | 400 | seeds per cell | S8 | SE of a mean ≈ 0.005 |
| FP_RUNS_TS | 300000 | runs per human profile | S8 | 0 flags ⇒ < 1e-5 per step at 95 % |
| FP_RUNS | 20000 | runs | S8 | HoldZone and Trace; margin assertions cover the rest |
| SOLVABILITY_SEEDS | 1000 | seeds per cell | S8 | finds rare impossible patterns |
| PERFECT_MIN_SCORE | 0.98 | score | S8 | mean rawScore of the Perfect bot (TimingStrike at 60 fps, PrecisionTrace), else the pattern is unfair |
| PERFECT_30FPS_MIN_SCORE | 0.95 | score | S8 | playable at 30 fps (§6 TimingStrike latency, T-MG-11) |
| PERFECT_HZ_MIN_SCORE | 0.95 | score | S8 | HoldZone's exact-state Perfect controller tops out at 0.97–0.99 raw (§6.13) |
| FAIRNESS_MAX_SD | 0.08 | score | S8 | one seed must not be much harder than another |
| TIER_MIN_MEAN_DROP | 0.05 | score | S8 | Average's Normal → Hard drop must be felt (Q8); other profiles only > 0 (§6.13) |
| STEEL_MEAN_DROP | [0.01, 0.08] | score | S8 | Steel "slightly tighter", Average on Normal (Q13) |
| CHI2_CRIT | 37.70 | — | S8 | χ² critical value, 16 buckets (15 dof), p = 0.001 |
```

New:

```
| BOT_RUNS | 400 | seeds per cell | S8 | SE of a mean ≈ 0.005 |
| BOT_RUNS_FAIL | 1000 | seeds per cell | S8 | T-MG-04's Q8 fail rates (Average, Good): BOT_RUNS' seed list extended; at 400 two Average cells sit about 2 % from a fixed-seed failure each |
| FP_RUNS_TS | 300000 | runs per human profile | S8 | 0 flags ⇒ < 1e-5 per step at 95 %; half on Normal, half on Hard |
| FP_RUNS | 20000 | runs | S8 | HoldZone and Trace; margin assertions cover the rest |
| TP_RUNS | 2000 | runs per cheat | S8 | T-MG-10's true positives, unless named |
| SOLVABILITY_SEEDS | 1000 | seeds per cell | S8 | finds rare impossible patterns |
| PERFECT_MIN_SCORE | 0.98 | score | S8 | mean rawScore of the Perfect bot (TimingStrike at 60 fps, PrecisionTrace), else the pattern is unfair; also every such run (T-MG-03) |
| PERFECT_30FPS_MIN_SCORE | 0.95 | score | S8 | playable at 30 fps (§6 TimingStrike latency, T-MG-11) |
| PERFECT_HZ_MIN_SCORE | 0.95 | score | S8 | HoldZone's exact-state Perfect controller tops out at 0.97–0.99 raw (§6.13) |
| PERFECT_HZ_RUN_MIN_SCORE | 0.85 | score | S8 | every HoldZone Perfect run (T-MG-03; the lowest of S3's 8,000 is 0.8969, of M4's pinned 4,000 0.8828) |
| FAIRNESS_MAX_SD | 0.08 | score | S8 | one seed must not be much harder than another |
| FAIRNESS_SEEDS | 100 | pattern seeds | S8 | T-MG-12's patterns per family × tier |
| FAIRNESS_BOT_RUNS | 20 | runs per pattern | S8 | T-MG-12's Average runs per pattern, their bot seeds shared across patterns |
| TIER_MIN_MEAN_DROP | 0.05 | score | S8 | Average's Normal → Hard drop must be felt (Q8); other profiles only > 0 (§6.13) |
| STEEL_MEAN_DROP | [0.005, 0.08] | score | S8 | Steel "slightly tighter", Average on Normal (Q13); the floor 0.005, half a point, is O4's default: hammering drops 0.0089 ± 0.0010 **[Decision to confirm]** (O4) |
| STEEL_DROP_RUNS | TimingStrike 20000, HoldZone 4000, PrecisionTrace 4000 | paired runs | S8 | T-MG-06: the drop's SE ≈ 0.001 (the paired difference's SD is 0.08–0.14) |
| CHI2_CRIT | 37.70 | — | S8 | χ² critical value, 16 buckets (15 dof), p = 0.001 |
```

### §17.1 O4 (line 4731; L3)

Old:

```
| O4 | (Q13; S8) Does "Steel plays slightly tighter" mean an average player scores 1–8 points lower (of 100 %) on Normal steps in Steel than in Iron? | 1–8 points, `STEEL_MEAN_DROP` [0.01, 0.08] (PrecisionTrace measures 0.009, see §17.2 S3) |
```

New:

```
| O4 | (Q13; S8) Does "Steel plays slightly tighter" mean an average player scores 0.5–8 points lower (of 100 %) on Normal steps in Steel than in Iron? On paired runs (§6.13) hammering (TimingStrike) drops 0.0089 ± 0.0010, under one point; smelting 0.0155, sharpening 0.0117. | 0.5–8 points, `STEEL_MEAN_DROP` [0.005, 0.08], the data unchanged; the alternative, TimingStrike's Steel column retuned (e.g. `windowMs` × 0.98 → × 0.97) until its drop clears 0.01, is a BALANCE change (new distributions; S4's Steel rarity rows re-checked) |
```

### §17.2 Engineering items: the two S3 rows and V-08 (lines 4761, 4763 and 4776; O4, G19, L7, the plan's [7])

Old (line 4761):

```
| S3 | PrecisionTrace's Average Iron − Steel drop on Normal is 0.009 (§6.13: 0.633 → 0.624), below `STEEL_MEAN_DROP`'s 0.01 floor (§14.6); HoldZone (0.016) and TimingStrike (0.012) pass. Retune the Steel column or lower the floor with S8 (O4). |
```

New:

```
| S3 | The Average Iron − Steel drop on Normal, on paired runs (T-MG-06 with §6.13's runs): HoldZone 0.0155 ± 0.0010, TimingStrike 0.0089 ± 0.0010, PrecisionTrace 0.0117 ± 0.0014 (the table's 0.009 for PrecisionTrace was noise). `STEEL_MEAN_DROP`'s floor is 0.005 until O4 is confirmed; otherwise TimingStrike's Steel column is retuned (with S8). |
```

Old (line 4763):

```
| S3 | Re-measure the `PtTooPrecise` human minimum over `FP_RUNS` runs on the 30 fps / 360 px device (3,000 runs give 0.0028 u, ×3.5, against §14.8's 3 × `PT_PRECISE_MEAN_DEV` floor); if it nears 3 ×, retune `PT_PRECISE_MEAN_DEV` (with S8). |
```

New:

```
| S3 | The `PtTooPrecise` human minimum over `FP_RUNS` runs on the 30 fps / 360 px device, re-measured at M4 (E-S3.10): 0.00279 u (×3.49) on Normal and 0.00259 u (×3.24) on Hard, the 0.1 % quantile ×3.8. The pinned seeds pass §14.8's 3 ×, but a fresh draw of 10,000 runs falls under it with no run flagged in about 1–10 % of draws; at the next re-draw (any BALANCE change) §14.8 asserts the 0.1 % quantile ≥ 3 × instead of the minimum, with no retune of the flag (with S8). |
```

In line 4776 (S8's row), old:

```
**V-08** releases while the Esc menu is open reach the game and `MenuOpened` fires on Esc (S3, S6)
```

New:

```
**V-08** releases while the Esc menu is open reach the game and `MenuOpened` fires on Esc (S3, S6; M8's S-E2E-12 verifies it; if a release is lost, §6.6's per-frame rule records it)
```

### SPEC-evidence.md E-S3.8: the σ 4 ms cheat (lines 2073–2074; M4-notes B4, finding 1)

Old:

```
TimingStrike: 0 flags in 100,000 runs each for Elite at 240 and 60 fps, Good, and Average at 30 fps, at Normal and
Hard (S8 sizes the 10⁻⁵ claim at 300,000 runs); exact times flagged 100 %; σ 4 ms synthesized input 0 % (score 1.000).
```

New:

```
TimingStrike: 0 flags in 100,000 runs each for Elite at 240 and 60 fps, Good, and Average at 30 fps, at Normal and
Hard (S8 sizes the 10⁻⁵ claim at 300,000 runs); exact times flagged 100 %; σ 4 ms synthesized input 0 % of these
2 × 2,000 runs (score 1.000), about 0.04 % of 12-strike runs (Normal), 0.008 % of 15-strike ones (Hard): their errors
spread less than 1.5 ms by chance (M4's pinned 2,000 runs, the tiers alternating, flag 2, E-S3.10).
```

### SPEC-evidence.md E-S8.5: T-MG 03, 09 and 10 (on Builder 3's new text)

In Builder 3's new T-MG row: "03 solvability" becomes "03 solvability (the mean and every run)"; "09 live session =
`judge` on 1,000 random frame partitions" becomes "09 live session = `judge`: 1,000 bot timelines per family pushed in
any order §6.4 rule 7 allows, and their inputs played again through a Recorder and §12.5's host loop on another
device"; "10 FP and TP runs (L3)" becomes "10 FP runs (L3V) and TP runs (L3), §14.8".

### SPEC-evidence.md E-S8.7: L3's cost as built (lines 3294–3296; I4)

Old:

```
- `BOT_RUNS` 400: SE of a mean ≈ 0.005 (score SD ≈ 0.1); of a 10 % fail rate ≈ 0.015, inside the 3–15 % band. L3
  total: 3 families × 2 tiers × 2 materials × 6 profiles × 400 ≈ 29,000 runs, plus 4 × 300,000 TimingStrike FP runs
  (≈ 150 s) and one 20,000-run Trace FP case (≈ 130 s at ≈ 6.5 ms per run): ≈ 7 min, inside 10 min.
```

New:

```
- `BOT_RUNS` 400: SE of a mean ≈ 0.005 (score SD ≈ 0.1); of a 10 % fail rate ≈ 0.015, inside the 3–15 % band. As
  built (M4, E-S3.10), a bot run through the Recorder, `prepare`, the replay and the checks costs 0.12–0.62 ms in
  TimingStrike (0.61 at 240 fps), 0.9–1.4 ms in HoldZone and 7.4–8.9 ms in the trace (44–66 % busy). M4's plain L3
  cases (T-MG-04 with its Q8 extension, T-MG-05, T-MG-09, 11 and 15 slow, the true positives, Reference) take about 3
  minutes; the volume cases (§14.1's L3V) 9.6 minutes more at 3–27 % busy: T-MG-10's FP runs (TimingStrike's 1.2
  million 4.9 minutes, the trace's 23,000 2.4, HoldZone's 20,000 0.3), T-MG-03, T-MG-06's paired runs and T-MG-12 1.9.
```

### SPEC-evidence.md: for E-S3.10 "M4 as built" (slice 8)

From `docs/build/M4-notes.md` (B4):

- Parity: `Bots.run` with the prototype's seeds reproduces the first 100 scores of each of the 48 cells of
  `S3-score-distributions.luau` exactly (4,800 of 4,800), each timeline judged Ok within the judge's caps and the
  prototype's own session ending on the build's unquantized sums; resolved params (3 families × 2 materials × 5 tiers ×
  4 x) and pattern arrays (seeds 1–20 per family, tier and material) equal the prototype's to the bit. Every fixed-seed
  L3 outcome is therefore the prototype's, precomputed before the build (D11).
- Golden (b), `minigames.bv1`: 144 pattern rows, 12 scripted results and the results of 24 frozen bot timelines
  (`MinigameTimelines`, 32,187 bytes: HoldZone 246–354 B, TimingStrike 36–44 B, the trace 2,301–4,261 B, its first
  record the cursor at GO). The libm canary on the build machine: 572967914.
- The build's per-run costs through the Recorder (44–66 % busy): HoldZone 0.88–1.35 ms (Perfect 1.94), TimingStrike
  0.12–0.28 ms (Elite@240 0.61), the trace 7.4–8.9 ms (on the pacer 1.96), about 15–30 % over the prototype's.
- T-MG-03 (1,000 runs per cell): HoldZone Perfect's means 0.9856 / 0.9880 / 0.9659 / 0.9699 (Iron N, Steel N, Iron H,
  Steel H) and lowest run 0.8828 (floor 0.85), every run flagged `HzInhumanRate`; TimingStrike@60 and the trace 1.0000 on
  every run. T-MG-11 (1,000 per cell): the lowest Perfect@30 run 0.9613 (Hard Steel x = 1; floor 0.95).
- T-MG-04 (400 runs per cell; 1,000 for Average and Good): every mean within its band (the worst at 0.67 of it), no run
  flagged, Q8's fail rates inside their bands (the smallest margin 2.3 points, HoldZone Iron/Normal Average 5.3 %).
  T-MG-05: every profile order holds; Average's Normal → Hard drops 0.068–0.098, the smallest other 0.0052.
- T-MG-06 (paired): Iron − Steel 0.0153 (HoldZone, 4,000), 0.0086 (TimingStrike, 20,000), 0.0130 (PrecisionTrace,
  4,000). T-MG-12: the SD of the per-pattern means 0.046 / 0.051 (HoldZone N / H), 0.022 / 0.021 (TimingStrike), 0.025
  / 0.014 (the trace), against 0.08.
- T-MG-10 false positives, 0 flagged in every case: TimingStrike 1.2 million runs (the smallest SD of the judged errors
  2.78 ms at Elite@240 Normal, flag < 1.5; the largest exact share 0.500, flag ≥ 0.90); HoldZone 20,000 (at most 9
  presses in 1 s, flag 30); the trace's 30 fps / 360 px halves (smallest mean deviation 0.00279 / 0.00259 u, ×3.49 /
  ×3.24; 0.1 % quantile ×3.8; smallest mean jerk 0.00409 / 0.00404, ×20) and its other devices (×3.55 / ×3.70 / ×6.78).
- T-MG-10 true positives (2,000 runs each): Exact flagged `TsExactHits` and `TsLowVariance` every time, clamped to the
  pass line; the trace on the pacer `PtTooPrecise` and `PtTooSmooth` every time, every 200 ms `PtSparse` every time;
  HoldZone's exact-state Perfect 100 of 100 (up to 50 presses in 1 s) and a 30/s autoclicker 2,000 of 2,000. Accepted
  (Q17): σ 4 ms TimingStrike noise flagged 2 of 2,000, mean 0.9999; 0.004 u trace noise 0, mean 0.9856.
- T-MG-15 (1,000 runs per profile and offset): Elite@240 and Good unflagged at every offset −120…+120. The offset
  offer in the Recorder's terms (the plan's [6.3]): Average Iron/Normal TimingStrike (x = 0.10, salt 1), 2,000 runs,
  scores 0.6482 at offset 0 (its mean `meanErrMs` +33.5), 0.7124 at +35 (−0.9) and 0.4790 at −35, so the results
  card's offer `timingOffsetMs += round(meanErrMs)` moves the right way.
- T-MG-09 (1,000 bot runs per family, the four profiles and Perfect on both tiers and materials): the live session
  equals the judge on every run, and so does §12.5's host loop replaying the inputs on another device; the timelines'
  bytes min / mean / max HoldZone 189 / 363 / 1,128 (the exact-state Perfect makes the long ones), TimingStrike 30 /
  39 / 46, the trace 2,294 / 3,741 / 4,317 (its first record the cursor at GO).
- The build's L3 times (indications, the machine shared): M4's plain L3 173.33 s at 6–76 % busy; its volume cases
  573.5 s at 3–27 %.
- I5's stale lines stay where they are, noted here: `out/golden.txt`'s HoldZone `driftSpeed` 0.2625 predates the Volume
  term's +0.15 (E-S3.3's 0.2415 is right); `out/det.txt`'s HoldZone bytes 198 / 295 / 408 are another run's (E-S3.6:
  198 / 293 / 396); v2 `Bots.luau`'s comment "an 800 ms look-ahead" is 300 ms in its code (§16.23); §6.13 and the v2
  README place the distributions in a `final/` folder that does not exist (they are `v2/out/`). None moves a value M4
  asserts.

### README.md: Layout and Status (lines 28–68 and 115–130)

The tree (after Builder 3's `lib/` edit), new lines after `├── Physics/ …`'s block (after line 38):

```
├── Minigames/             T-RNG-01…06 (Rng.spec), T-MG-01…16 per module (Params, Checks, the three families,
│                          Timeline, Input, the facade, Bots), Properties (§14.5), Source (§6.4's whitelist),
│                          Reference (the bots against S3's prototype and its shipped distributions), Statistics and
│                          FalsePositives (L3; their t.volume cases L3V), MinigamesHelpers (step inputs, the host loop)
```

Old (lines 40–42, the fixtures entry):

```
├── fixtures/              Build (shared record helpers), Blueprints (F1–F5), Adversarial (A01–A28), Calibration
│                          (C01–C15), Regression (X01–X07), Cost (P1–P5, the specks, X08, T-PERF-01's cases),
│                          WorstDesigns, Parity (S-PAR-02's list): a Rojo root, so Studio tests load them too
```

New:

```
├── fixtures/              Build (shared record helpers), Blueprints (F1–F5), Adversarial (A01–A28), Calibration
│                          (C01–C15), Regression (X01–X07), Cost (P1–P5, the specks, X08 and its edge, T-PERF-01's
│                          cases), WorstDesigns, Parity (S-PAR-02's list), Edges (S3's nine reference blade edges),
│                          MinigameTimelines (24 frozen bot timelines): a Rojo root, so Studio tests load them too
```

Old (lines 45–46, the golden entry):

```
├── golden/                balance_fingerprint, definition_ids, world_build_list, the §5 table (difficulty_*.bv1),
│                          S-PAR-02's parity.bv1.digest and parity_designs.bv1 (`--bless` rewrites them: review the diff)
```

New:

```
├── golden/                balance_fingerprint, definition_ids, world_build_list, the §5 table (difficulty_*.bv1),
│                          S-PAR-02's parity.bv1.digest and parity_designs.bv1, minigames.bv1 (T-MG-13) (`--bless`
│                          rewrites them: review the diff)
```

Old (line 57): `docs/build/                M1–M3 build notes: open items, deviations from the SPEC, what each builder measured`
New: `docs/build/                M1–M4 build notes: open items, deviations from the SPEC, what each builder measured`
(and `M4-handoff.md`, once applied, can be deleted or kept as the record of this patch: the lead's call).

Old (line 65, the end of the paragraph's M3 sentence):

```
`Physics/{Edge, Factors, Difficulty}`, which `Analyze.run` calls for the edge and the steps (SPEC §4.6, §5).
```

New:

```
`Physics/{Edge, Factors, Difficulty}`, which `Analyze.run` calls for the edge and the steps (SPEC §4.6, §5). M4 added
`Minigames/{Types, Rng, Params, Checks, HoldZone, TimingStrike, PrecisionTrace, Timeline, Input, Minigames, Bots}`:
the three MVP minigames, their wire format, the input Recorder and the facade the server and client call (SPEC §6).
```

Status (slice 11, the lead's, after the full verify; the figures in brackets are the lead's quiet runs), a new
paragraph after the M3 one (after line 130):

```
M4, the minigames, is built: `Minigames/*` with the facade and the bots (SPEC §6); T-RNG-01…06 and T-MG-01…16 pass in
Lune, with L3 and its volume tier (SPEC §14.1: `lune run tests/run -- --volume`, [N] minutes quiet), and T-PERF-02
[medians]. The bots reproduce S3's prototype score for score (4,800 runs) and every fixed-seed statistic is the one
precomputed on it (`docs/build/M4-notes.md`). M4 has no Studio scenario (SPEC §18); Lune = Studio parity of the judge
is S-PAR-02's M5 extension, on the frozen bot timelines. Its open design calls are SPEC §17.1 O4 (Steel's drop
floor), O13 (the combo) and O14 (the live score), each built with its default.
```

### Slices 9–11, for the lead (L2): commands and expected outcomes

In the main tree, after the shift fix's commit and this handoff applied, on a quiet machine, one Lune process at a
time. Every statistical outcome below is pinned in its spec at the precision shown, so a case fails on any other value;
a failure is a porting bug or a libm change (`Minigames/Bots`' canary says which), never a reason to re-seed (D11).
Every case prints its figures; time each case with `--filter "<suite> › <case text>"` when a per-case time is needed.

- **Slice 9, the statistics.** Plain L3 first, then the volume tier:
  - `lune run tests/run -- --filter "Minigames/Statistics"`: 4 pass (T-MG-06 (a), T-MG-04 and 05 per family), 9
    `t.volume` cases listed as SKIP. Builder 4: 91.84 s by the runner at 5–47 % busy (median 16). Prints per family
    the worst mean's share of its band (HoldZone 0.51, TimingStrike 0.67, PrecisionTrace 0.65), the smallest Q8
    margin and the smallest non-Average drop (0.0352, 0.0501, 0.0052).
  - `lune run tests/run -- --filter "Minigames/FalsePositives"`: 3 pass (the true positives), 12 SKIP; 11.17 s at
    18–20 %. Prints: Exact 2,000 of 2,000 flagged, σ 4 ms noise 2 of 2,000 (mean 0.9999); on the pacer 2,000
    `PtTooPrecise` (`PtTooSmooth` 2,000), 200 ms apart 2,000 `PtSparse`, 0.004 u noise 0 (mean 0.9856); HoldZone
    Perfect 100 of 100 (up to 50 presses in 1 s), the autoclicker 2,000 of 2,000.
  - `lune run tests/run -- --volume --filter "Minigames/Statistics"`: 13 pass. Builder 4's volume cases alone (3–27 %
    busy): T-MG-03 13.88 s, T-MG-06 (b) 70.38 s, T-MG-12 29.12 s. Expected: T-MG-03's means and lowest runs as
    M4-notes B4 lists them; T-MG-06 Iron / Steel / drop 0.6144 / 0.5991 / 0.0153, 0.6489 / 0.6403 / 0.0086, 0.6337 /
    0.6207 / 0.0130; T-MG-12 0.0463 / 0.0510, 0.0220 / 0.0213, 0.0246 / 0.0136.
  - `lune run tests/run -- --volume --filter "Minigames/FalsePositives"`: 15 pass. Builder 4 (3–25 % busy): TimingStrike
    Elite@240 150.45 s (both tiers), Elite@60 53.88 s, Good@60 53.93 s, Average@30 37.78 s; HoldZone 18.80 s; the trace
    145.24 s (its three cases); 573.5 s for all the volume cases. Expected: 0 flagged everywhere; TimingStrike's smallest SD / largest exact share 2.78 / 0.500,
    4.24 / 0.400 (Elite@240 N / H), 3.37 / 0.364, 5.13 / 0.333 (Elite@60), 7.24 / 0.417, 8.93 / 0.333 (Good@60), 11.95 /
    0.333, 16.75 / 0.308 (Average@30); HoldZone's most presses 9 / 9 / 8 / 8 / 8 / 8 / 7 / 7; the trace's halves
    0.00279 / 0.00259 u (quantile 0.00304 / 0.00303, jerk 0.00409 / 0.00404), its other devices 0.00284 / 0.00296 /
    0.00543 u (jerk 0.00382 / 0.00454 / 0.00535).
  - Record each case's time and the totals: plain `lune run tests/run` (L3, the gate ≤ 10 min quiet) and
    `lune run tests/run -- --volume` (L3V, ≤ 20 min quiet); E-S8.7's new text above takes the quiet figures.
- **Slice 10, T-PERF-02** (`tests/Minigames/Perf.spec.luau`, `t.slow`, not written yet): the plan's [6.8] with L6's
  change. Method T-PERF-01's (a warm-up, `PERF_RUNS` rounds odd forward and even backward, a full collection before
  each timed run, medians). Asserted ≤ `REPLAY_BUDGET_MS` (8): `Minigames.judge` at each family's cap, HoldZone
  Steel/Hard x = 1 with 1,024 alternating records, TimingStrike Steel/Hard x = 1 with 512 presses, and the trace at
  `Minigames.recordCap(spec)` on a 256-point source at the length bound (Iron/Normal x = 0, 8.55 u: 1,479 records,
  floor(29,560/20) + 1) spread over travel: sample i = 0 … 1,478 at `leadInMs + floor(i·travelMs/1,478)`, grinding on
  the pacer (reviewer V1's `hostile.luau`, part 2). The cap bounds the count, not the cost: this arrangement costs
  about 2 % more than the honest timeline (one sample per 20 ms from GO), which is timed and reported beside it.
  Asserted ≤ `PT_GENERATE_BUDGET_MS` (5): `prepare` for Sharpening, the edge hand-off plus `generate`, on X08's edges
  (`Analyze.run` of `Cost.X08.X08a/b/c`, outside the timed part), `Cost.X08_EDGE` and a 256-point chain at the length
  bound (a sine of 0.331 stud and 10 periods along 4.4 studs: 7 E shrinks, no Douglas–Peucker, 8.53 of 8.55 u), at
  Iron/Normal x = 0 and Steel/Hard x = 1. Reported: the hand-off and `generate` apart, decode alone of a 2,048-sample
  trace (refused `TooMany` by the judge's cap after decode), HoldZone and TimingStrike `generate`, and every median ×
  2.6 against §10.5's 7 ms. Expected: the trace judge near the prototype's 2.59 ms quiet on its honest timeline (3.31 ms
  at 59–68 % busy; the build 2.34 ms at 12 % busy, review round 2), and about 2 % more spread over travel (the build,
  M4's fix round 1: 2.48–2.67 ms honest, 2.53–2.79 ms spread, at 34–68 % busy); the length-bound chain's hand-off 0.12
  ms and `generate` 1.97 ms (14 % busy; the prototype's `generate` on worst.luau's source 2.53 ms); `prepare` = the
  hand-off + `generate`: on `Cost.X08_EDGE` 1.08–1.09 ms, the hand-off 0.81–0.82 and `generate` 0.24–0.26, at
  Iron/Normal x = 0 and Steel/Hard x = 1 (M4's fix round 1, medians of 401 rounds alternating with the round-1 build,
  3–19 % busy and no other Lune process; the round-1 build's `prepare` 4.05–4.10 ms, its hand-off's 8 Douglas–Peucker
  attempts 3.75–3.80 of it; at 11–43 % busy 1.11–1.16 against 4.13–4.36). Run alone and quiet:
  `lune run tests/run -- --filter "Minigames/Perf"`, with the CPU load beside the medians; a failure under load is
  re-run alone first.
- **Slice 11, the gate.** `lune run scripts/verify -- --volume` (sourcemaps, T-META-07, luau-lsp A and B, then every
  case with `t.slow` and `t.volume`) green under L5's gates: L1 ≤ 35 s quiet with `--quick --filter "Minigames/"` ≤ 3 s
  quiet, plain L3 ≤ 10 min quiet, L3V ≤ 20 min quiet. Then this handoff applied with the measured figures, the README's
  Status above, and the commit "M4: minigames". If the shift fix's commit changed any hashed Definitions, re-bless the
  fingerprint first (Builder 1's §16.12 note); golden (b) depends on no Physics or shift-fix file and needs no re-bless.

## Fix round 1: the review's ruling (19 Nov; the lead's journal, 08:05)

The edits above carry the ruling's text changes in place: §6.4 rule 2's `math.huge`; §6.8's and E-S3.10's fire-decay
groupings; the **[Decision to confirm]** marks of O13 and O14; `CycleStart` at GO (§6.9, §12.5); the lead for a negative
offset (§6.11, §6.9); §6.6's Caps; §6.10's rounding window; §10.3's cap through `judge`; §10.5's intro, its cost table
with the hand-off and the cap's cost; §17.2's S5 row; E-S3.8's rates per strike count; E-S8.5's "exceed"; E-S3.10's
offset offer; the L3V rationale; the README's line numbers; and slice 10's T-PERF-02. `docs/build/M4-notes.md` ("Fix
round 1") lists every ruling item with how it was checked. One evidence addition:

### SPEC-evidence.md: for E-S3.10 "M4 as built" (fix round 1)

- The edge hand-off's Douglas–Peucker attempts share one split tree: each segment's first farthest point is found once,
  a tolerance keeps the splits whose distance exceeds it from the root down, and a segment splits only when its loop
  found a farthest point, so a NaN coordinate cannot loop. The sources are the prototype's by construction;
  `Minigames/PrecisionTrace` pins them (the saw and the zigzag turned 13° and 25 random chains at the slowest and
  fastest MVP pacer in the quick run, 200 chains at all 12 under `t.slow`), and a probe of 300 random chains (zigzags,
  walks, combs, straight runs, repeated points, closed loops, up to 300 points) at the 12 pacers gave 3,600 hand-offs,
  1,050 through Douglas–Peucker, 0 differences. `prepare` on `Cost.X08_EDGE`, E-S3.5's zigzag, takes 1.08–1.09 ms (the
  hand-off 0.81–0.82, its eight attempts; `generate` 0.24–0.26) at 3–19 % busy, against the round-1 build's 4.05–4.10 ms
  (its hand-off 3.75–3.80) in the same alternating runs. On the other eight reference blades the hand-off takes ≤ 0.03
  ms but on the saw (0.25, its six attempts; 0.56 before), and on a 256-point chain at the length bound 0.12 ms (seven E
  shrinks, no Douglas–Peucker).
- The trace's record cap bounds the count `judge` replays, not its cost: on the length-bound source, 1,479 records
  spread over travel cost × 1.017–1.043 the honest timeline's (six runs of 401–1,201 rounds at 34–68 % busy; reviewer
  V1: × 1.019–1.027 at 7–26 %).
- TimingStrike's decisions follow the Recorder's horizon, so with a negative timing offset they come early: on E-S3.4's
  span 1 (T 489, M 200, W 110, the drawn window 379–599 ms), at 60 fps with no press, the live `Miss` fires at 588.3 ms
  on the raw clock at offset −120, 100.7 ms before T + M with the needle still in the drawn window, and at 655.0 /
  705.0 / 771.7 / 821.7 ms at −60 / 0 / +60 / +120. The view's `cycle` is 1 from the countdown through cycle 1 (2 from
  847 ms), so the host plays the first `CycleStart` at GO.
