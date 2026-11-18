# M4: the lead's decisions on plan-r2.md and its critiques (2026-11-18)

The builders follow `plan-r2.md` with the decisions below. Where the two differ, these decisions take precedence. The
critiques are `critique-coverage.md` (critic A) and `critique-determinism.md` (critic B). Critic B's scripts and outputs
are in `critic-b\`, and the planner's are in `measure\`. The plan's numbers are taken on the prototype; where the plan
and the code or SPEC at `f7ac37d` disagree, the code and the SPEC win. Record each difference in
`docs/build/M4-notes.md` and go on.

## Slice 0: where and when M4 is built

**L1. A worktree of f7ac37d.** The whole-design shift fix is under review in the main working tree, and it gets its own
commit first. Meanwhile M4 is built in a detached git worktree of `f7ac37d`, which the lead created at
`C:\Users\louis\AppData\Local\Temp\claude\C--Users-louis-Documents-RANDOM-ROBLOX\93ae48b4-72b9-4dc1-aa5d-451af1abf9a0\scratchpad\m4-wt`.
Nothing in the main working tree changes.

- In the worktree, change only M4's files:
  - `src/shared/Minigames/*`;
  - `src/shared/Definitions/MinigameFamilies.luau` (D3's two rows), and the Definitions tests that list its rows (T-DEF-05);
  - `tests/Minigames/*`;
  - `tests/lib/Cheats.luau` (new) and `tests/lib/Tol.luau` (D10's rows);
  - `tests/fixtures/Edges.luau` and `tests/fixtures/MinigameTimelines.luau` (new), and `Cost.X08_EDGE`;
  - `tests/golden/balance_fingerprint.golden.txt` and `tests/golden/minigames.bv1.golden.txt`;
  - `tests/run.luau`, `scripts/verify.luau` and `tests/Meta/Runner.spec.luau`, for L5;
  - `docs/build/M4-notes.md` and `docs/build/M4-handoff.md` (new).
- `SPEC.md`, `docs/spec/SPEC-evidence.md` and `README.md` stay untouched in the worktree, because the shift fix rewrites
  them in the main tree.
  - Every edit the plan's [12] lists goes into `docs/build/M4-handoff.md` instead. Where the old text is in
    `f7ac37d`, write it as exact old → new text; otherwise, as new text with its place.
  - After the shift fix's commit, the lead applies it and reconciles it with that fix's text.
- No git command that writes, in either tree: no `commit`, `stash`, `checkout`, `reset`, `add` or `worktree`.
  `git status` and `git diff` are fine.
- The worktree's Physics is `f7ac37d`'s. No M4 test pins a number Physics produces (D5, D6). Slice 7's integration case
  asserts only that the facade accepts `Analyze.run`'s step input for F5 and C02 and judges it, not their values.

**L2. Slices 1–8 now; 9–11 after the shift fix.**
- The build workflow runs slices 1–8 and their review.
- Slices 9 (the volume statistics), 10 (T-PERF-02) and 11 (the full verify) need a quiet machine and the shift fix
  committed. The lead runs them in the main tree after applying M4's patch.
- Until then, the shift fix's reviewers run up to four processes beside you:
  - run one Lune process at a time in the worktree;
  - take no timing as a gate, only as an indication, with the load stated.

## Designer calls (the build applies the default, **[Decision to confirm]**)

**L3. O4: a floor of 0.005.** `STEEL_MEAN_DROP` becomes [0.005, 0.08], and the game data stays unchanged, as the plan's
[9.1] proposes.
- §17.1 O4's row is re-worded with the larger sample: the family under 0.01 is TimingStrike (hammering), at
  0.0089 ± 0.0010 pooled, not PrecisionTrace.
- The alternative is to retune TimingStrike's Steel column. That means a fingerprint change, new distributions and a
  re-check of S4's Steel rarity rows.
- **[Decision to confirm]** (§17.1 O4).

**L4. O13 and O14.** Both keep the plan's defaults, and both carry **[Decision to confirm]** with their numbers.
- **O13** (the plan's new O "A"), TimingStrike's combo: +1 for each span decided with points above 0. A span decided
  with 0 resets it. Stray presses do not count.
- **O14** (the plan's new O "B"), the live score: the mean so far.

Both are feedback only: no stored value, no effect on the score, no BALANCE change.

## Engineering calls

**L5. I4, the gates.**
- **L1:** the `--quick` gate becomes ≤ 35 s quiet (was 30 s).
  - M4's share is ≤ 3 s quiet, timed at every slice; under load, say the load.
  - The trigger for moving fast cases to `t.slow` becomes 32 s quiet (was 27 s).
- **L3 gets a volume tier:**
  - Which cases: one whose outcome is fixed by the BALANCE data, the bots and its pinned name alone is tagged
    `t.volume` (D11: Reference parity pins the scores). These are T-MG-10's false-positive runs, T-MG-03, T-MG-06 and
    T-MG-12, plus T-MG-04's Q8 fail-rate extension if plain L3 is still over 10 minutes without it. `t.volume`
    implies `t.slow`.
  - The runner: `lune run tests/run` skips `t.volume` cases and lists them as skipped; `lune run tests/run -- --volume`
    runs everything; `--quick --volume` is a harness error (exit 2); `scripts/verify -- --volume` passes the flag
    through.
  - Gates: plain L3 stays ≤ 10 min quiet. The volume run (L3V in §14.1) has a gate of ≤ 20 min quiet for the whole
    run. It is due at milestone exit, before a playtest, and after any change to `Definitions/MinigameFamilies`,
    `Definitions/Balance`'s minigame rows, `Minigames/Bots` or a pinned name.
  - `tests/Meta/Runner.spec.luau` covers the new flag and tag, in the runner self-test's style. The handoff states
    §14.1's new rows.
- **Why:** every fixer and reviewer of every later milestone runs the full verify. With the volume cases it takes about
  17 minutes quiet, or 25–30 at this machine's usual load, which would triple each round's cost. Yet those cases cannot
  change unless the data, the bots or a name changes, and `Reference.spec` (plain L3, about 15 s) catches any porting
  change at once.

**L6. I8 and R7: the trace's record cap.** Take R7's option. §6.7's Caps row already says an unmodified client makes at
most `durationMs/20 + 1` trace records.
- **The rule:** `Minigames.judge` refuses a PrecisionTrace timeline with more records than
  `floor(durationMs / PT_EVAL_MS) + 1`, using the step's own `durationMs`, as `TooMany`. The check is O(1), after
  decode and `prepare` and before any replay.
- **First, the proof:** before adopting the rule, the builder proves that no Recorder output exceeds it.
  - It is a property over frame times 1–100 ms with a random phase, hitches up to 250 ms, focus loss and release, at
    every MVP tier's longest step, plus every bot timeline of slice 8.
  - If the proof fails, keep decode's 2,048 and report the counterexample to the lead.
- **What it changes:**
  - With the cap, the decode-cap trace is the honest maximum, and §10.5's 7 ms is the one Studio target for `judge`, on
    that timeline.
  - §17.2's S5 row keeps 20.8 ms as the trigger for the AnalysisQueue fallback, which M7's S-PERF-01 measures.
  - T-PERF-02 times all three families at their caps.

**L7. G19, the trace margin.** Keep the plan's default. T-MG-10 keeps §14.8's assertion: the smallest mean deviation
over the pinned halves is ≥ 3 × `PT_PRECISE_MEAN_DEV` (precomputed: ×3.49 on Normal, ×3.24 on Hard). It reports the
0.1 % quantile beside it. §17.2's S3 row records ×3.24 and says that at the next re-draw the 0.1 % quantile replaces the
minimum, with no flag retune.

**L8. The rest of the plan.**
- The plan's D1–D14 are accepted as written.
- So are its [15] points not taken:
  - B 5's paired names wait for the next re-draw, and are recomputed first;
  - B 4's weaker assertion is not taken;
  - A 14's Poor@30 is not added.
- D5 matters more here, because the worktree's Physics is `f7ac37d`'s.

**L9. Precomputes.**
- Every expected outcome is precomputed on the prototype in slice 8, with the pinned names:
  - T-MG-03's per-run floors, T-MG-11 slow and T-MG-15 slow;
  - T-MG-10's TimingStrike and HoldZone runs, no longer optional.
- Run them one Lune process at a time, each under 5 minutes; split a longer run by device and tier.
- Record each outcome and its command in `docs/build/M4-notes.md`.
- The volume run waits for the lead (L2), and the lead's slice 9 compares against these outcomes.

**L10. Checks per slice.**
- Each slice ends with its own filtered tests green and with `lune run tests/run -- --quick --filter "Minigames/"`
  timed.
- Each builder ends with `lune run scripts/verify -- --quick` in the worktree: L0 and L1, one process, with the load
  stated.
- Builder 4 also runs `lune run tests/run -- --filter "Minigames/"`: plain L3 for M4, without `--volume`.

**L11. The review's severity.** A blocker or major is only one of these:
- live ≠ replay, or a build score that differs from the prototype's on the same seeds;
- a §6.4 rule broken in an authoritative module;
- an honest Recorder timeline refused or flagged;
- a cheat that the SPEC says is refused or flagged, which passes;
- a test that cannot fail;
- a precomputed outcome, or a number in the notes or the handoff, that the build does not reproduce;
- M4's L1 share over 3 s quiet;
- a crash, a NaN or an unbounded cost on any buffer that decodes;
- a SPEC statement that the handoff's text would leave false.

Everything else is minor.
