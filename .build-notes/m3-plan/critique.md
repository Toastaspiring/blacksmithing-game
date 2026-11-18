# Critique of the M3 build plan (`plan.md`)

Read-only review against SPEC.md, SPEC-evidence.md, M1-notes.md, the M2 code and tests, the S2 prototype and the plan's own
`proto/` runs. I re-ran the plan's experiments at a larger scale with my own scripts in `critic/` (one Lune process at a
time, 0.2–44 s each). The repo and Studio were not touched; `git status` is unchanged.

## Verdict

The plan is careful. Its references are right, and its constants and fixture sources are complete. But both of its headline
recommendations fail at the scale their own tests run:

- **D2 does not make T-DIF-07 pass.** The evidence was 30 designs. On 300 designs with the same seed, D2 gives |Δx| 0.0513
  and |ΔG| 0.0205. Even "every sample a probe" fails, so the stride is not the main cause. D2 at 400 probes is also *less*
  accurate than the stride.
- **Option B (D1) does not remove the 2 % tier flips.** §17.2's own sandwich with 0.03 cheeks flips three tiers under B.
  The channel left open is the cleaned core's volume in SurfaceComplexity's denominator and in Smelting's Volume.

Three test definitions fail as written: T-EDG-01 item 6, T-DIF-08's "equal d" and T-DIF-07(c)'s "edge bit-identical". A
handful of smaller items follow.

## Findings, most severe first

### C1 [blocker] D2 is not the fix for T-DIF-07, and the stride is not the main cause

**Claim.** plan.md:27 and :470 say "It passes with D2: 0.0028 / 0.0011". :695 says "The cause is the stride". R3 at :710
says the same.

**Evidence.** proto/m3q.luau hard-codes `local N = 30`. I ran `critic_proto.luau -- gen 300` with the same seed
(0x5EED0007) and the same stream, so designs 1–30 are the plan's. Bounds: |Δx| ≤ 0.02, |ΔG| ≤ 0.002.

| Thinness probes | segmented vs whole: max \|Δx_Thinness\| | max \|ΔG\| |
|---|---|---|
| §5.2 stride | 0.0591 (#51) | 0.0236 (#51) |
| D2 (ladder grid, 400) | 0.0513 (#51) | 0.0205 (#51) |
| FINE: every owned volume sample a probe | 0.0476 (#51) | 0.0191 (#51) |

Three causes, each measured:

1. **θ flips with the piece's proportions.** This is the dominant cause. In #51, an unturned part 0.0713 × 0.1700 × 0.1030
   is cut into three pieces 0.0567 long. Its thinnest local axis moves from X to Y, the θ chord then runs along the flush
   stack, and τ goes from 0.0713 to 0.1030. FINE fails on this design too.
2. **Asymmetry's grid moves with the part count.** Ha.Asymmetry |Δx| reaches 0.0197 (#152), so |ΔG| is 0.0059 in every
   variant. On the 241 designs whose cuts leave θ unchanged (`gen 300 safe`), D2's Thinness change is 0.0028, but |ΔG| is
   still 0.0045 (#55) for D2 and FINE alike.
3. **The stride's aliasing**, which is what the plan found. D2 does remove it: on the θ-safe subset the stride gives
   0.0570 / 0.0228 and D2 gives 0.0028.

**Fix.**
- Withdraw "passes with D2" at :27, :470, :692–693 and R3, and correct the cause at :695 and §8.3 item 4.
- T-DIF-07(b)'s Gen.segmented corpus cannot meet TOL_G_INVARIANT with today's θ rule and Asymmetry grid, with or without
  the stride. Put it to Louis as a SPEC decision:
  - **(i)** Narrow (b) to E-S2.10's F5 cuts plus C12 vs C02. This works with the stride, so D2 is not needed. Record the
    measured general sensitivity (Thinness 0.06, G 0.024 on 300 designs) at §5.6:1252 and in §17.2.
  - **(ii)** Redesign: θ by union chord, a per-part grid with a budget sized for accuracy, and an Asymmetry grid that does
    not depend on the part count. Accept it only on FUZZ_N_VALID = 500 designs.
- A data point for (ii), from `t3:gen 300`: with τ = min(C(Z), C(local X), C(local Y), C(local Z)), FINE's Thinness change
  falls to 0.0031. D2 still moves 0.0123 (Ha) and 0.0193 (Sh), and the stride jumps to 0.3960. The same rule raises
  wedge-heavy designs: P3 Hammering 0.1804 → 0.2724 with FINE (a tier) and P5 0.1902 → 0.2171. F/C fixtures move ≤ 0.0021
  (`t3:fixtab`).

### C2 [major] D2 at THICK_BUDGET 400 is less accurate than the stride, and it orphans phase 5

**Evidence.** Each variant against FINE, same 300 designs:

| Variant | max \|ΔThinness\| | max \|ΔD\| | tier flips |
|---|---|---|---|
| Stride | 0.0561 | 0.0224 | 0 |
| D2 | 0.1414 (#117) | 0.0566 | 1 |

On the fixtures (`fixtab`):
- F3 Hammering: FINE 0.4423 = stride, D2 0.4405.
- P5: FINE 0.1905, stride 0.1902, D2 0.1698. P5's Blade Thinness drops from 0.1755 to 0.0729.

With THICK_BUDGET 1600 (`gen 150 all b1600`), D2's error falls to 0.0082 / 0.0033. Its cost was not measured, and R2 has
only 5.4 ms of headroom.

D2 also leaves three things unaddressed:
- Phase 5 (`Sampling.volumeProbes`, N_VOL_TOTAL; Analyze.luau:423–425) has no consumer, yet §4.7's `budget.hVol` and
  `volSamples` still report it, and tests assert them (Reference.spec.luau:113–114, :132–133; Analyze.spec.luau:570, :639,
  :661). It also costs time against R2.
- THICK_BUDGET stops being a cap. When no rung fits, the last rung is used: 24 kept 1.0 × 3.5 × 0.4 blocks give 480 probes
  at h 0.8. The P1 row of §6 still asserts "Thinness probes ≤ THICK_BUDGET".
- §4.3, §4.9 and §16.10's N_VOL_TOTAL row need text.

**Fix.** If a per-part grid is pursued, size its budget against FINE, cost it, and state what happens to phase 5 and to the
§4.7, §4.9 and §16.10 rows.

### C3 [blocker for D1's claim] Option B does not remove the tier flips at the 2 % threshold

**Claim.**
- plan.md:656: "It removes the tier flips at the 2 % threshold for every core up to 0.05 thick".
- :642: "no flip … it can only lower D".
- Residual 1 at :663: "≤ 0.06".

**Evidence.** From `critic_proto.luau -- lam`, which uses the plan's own sandwich builder and forced verdict rows as in
out_lam_late.txt. The late form (B05late) and D1 + D2 give identical numbers. d is shown Sm / Ha / Sh.

| Design (Steel core 0.02 in a 0.02 gap; sheet over its rims) | K: core kept | K + sheet: both cleaned |
|---|---|---|
| §17.2's 1.1 × 2.0, core 0.95, **cheeks 0.03** | 0.2439 H / 0.1951 N / 0.1553 N | 0.1919 N / 0.3000 H / 0.2594 H: **3 flips** |
| same, cheeks 0.04 | 0.3053 / 0.0814 / 0.0594 | 0.2534 / 0.1971 / 0.1434 (Ha +0.116) |
| 1.0 × 2.5, cheeks 0.04, core 0.80 | 0.3414 H / 0.1385 N / 0.2190 H | 0.2865 H / **0.2495 H** / 0.3073 H |
| LAM2 (the plan's row) | 0.4883 / 0.0897 / 0.2250 | 0.4265 / 0.1740 / 0.2792 (Ha +0.084, above the stated ≤ 0.06) |

**Mechanism.** B hides the void faces and merges the chords. The cleaned core still leaves V, which is the denominator of
SurfaceComplexity (r = S/(6·V^⅔)) and Smelting's Volume. In the 0.03 case r goes from 2.690 to 2.997. LAM1 hid this because
its r stays under the 2.3 floor under B. Flush layers show the same channel: the 4-layer plate's Smelting falls from 0.6048
to 0.3223 under B (out_lam_late.txt), and the residual list leaves this out.

Three smaller errors in §7.2:
- "It can only lower D" holds for SurfaceComplexity but not for Thinness. With M = Σwφ²/Σwφ,
  ∂M/∂φ_i = w_i(2φ_i − M)/Σwφ. Merging chords lowers φ_i, which raises M wherever φ_i < M/2.
- The option C row at :643 calls Sharpening 0.2250 "N". It is Hard (out_lam_late.txt: "C … HNH"). Only Hammering changes
  tier.
- The cost "+2–10 %" at :642: out_cost2.txt shows C04 at +23 % in the late form.

**Fix.** D1 cannot be presented as resolving §17.2:4349. The real choices for Louis:
- **0:** accept, and document the class with these numbers.
- **B plus a volume rule:** this is option C's volume half, and it lets hidden parts move D.
- **A verdict-side rule** for cores sandwiched within VOID_GAP.

If B is kept as a partial mitigation:
- Restate its claims.
- Make its acceptance set a sweep of sandwiches with cheeks 0.02–0.06 and widths and hilt offsets that put r in
  [2.3, 2.9].
- Add the 4-layer plate's Smelting drop to the residuals.

### C4 [major] The mirror claims in T-EDG-01 item 6 and T-DIF-08 fail

**Claim.**
- :454: "mirrored … keeps lengths within 1e-12, because x is anchored at 0".
- :471: "a whole design and its X mirror image: equal d, except true twins … ≤ 0.0054".

**Evidence.** From `mirrordiag 31` and `mirror 150`:
- **Gen #31** (seed 0x5EED0008):
  - The design has EdgeLength 6.935592 over 11 DP points, chain from (0.140, 0.678).
  - Its X mirror image has 6.915188 over 9 points, chain from (0.160, 0.678).
  - The raster is identical: bladeArea and mean thickness are equal.
- **Over 20 fixtures and 150 Gen designs**, the largest |ΔD|:
  - 0.0069 with the stride (gen #136, Thinness x 0.0172), already over the 0.0054 allowance.
  - 0.0032 with D2 (gen #31, EdgeLength x 0.0064).

**Cause.** The mirror image's CCW outline runs the other way along the mirrored edges. The loop opens at its lowest, then
leftmost, vertex, and Douglas–Peucker keeps the first maximum, so the simplified chain differs.

**Fix.**
- **Item 6:** assert that the raster mirrors exactly (cells, bladeArea, bladeMeanThickness), and give EdgeLength a
  tolerance. Alternatively, make the opening vertex and DP ties mirror-symmetric and re-bless.
- **T-DIF-08:** drop "equal d" or give it a tolerance. §14.6 only asks for Asymmetry ≤ TOL_ASYM_ZERO on a design mirrored
  with the tool.

### C5 [major, small fix] T-DIF-07(c) "edge bit-identical" fails on EdgeProfile.gripPoint

**Evidence.** plan.md:201 calls `MassProps.difficultyFrame(parts, kept, …)` in blueprint order. MassProps.luau:529–538 sums
the kept Grip parts in list order. `critic_build.luau` runs the build's MassProps: 6 of the 24 orders of C09's 4 Grip
parts change the frame point's last bit (2.2e-16). EdgeProfile.gripPoint is that point (§4.7:1018). Steps are not
affected.

**Fix.** Compute the difficulty frame over the kept Grip parts in rank order (pass `byRank`; this edits M2's MassProps), or
exclude gripPoint from (c).

### C6 [moderate] Comparisons and assertions that will not hold as written

- **Bit-for-bit factor comparison.** "Compare factors bit for bit with the prototype" (:192) and "exact for … Volume,
  Joints" (:606) cannot hold for Volume, SurfaceComplexity and Joints. The build's owned volumes differ from the prototype's
  by up to about 4e-15 (MassProps.luau:13–18). Use Reference.spec's ABS of 1e-12 for those three. PartCount, Thinness,
  Asymmetry, EdgeLength and MaterialMix can be compared bit for bit.
- **T-EDG item 2 (:443), "on the same kept row".** The reference prototype has no forced kept row and does not export
  `edgeProfile`. Compare through `Proto.run(...).edge` on the fixtures whose verdicts agree (all but P1), and bless P1 alone.
- **`Edge.mergedLength`.** It is exported (:76) and uses an "in-place insertion sort" (:243), so the public function fails
  P-NOMUT (§14.5). Keep it local, or copy its input.
- **A14's expectation.** Adversarial.luau:576 still records `d = "NonIncreasing", gTol = "TOL_DUST_G"`. If T-DIF-04 asserts
  bit-identity (:467), update the fixture's expectation too. Bit-identity is plausible: in the build, Dust is outside every
  kept-first budget.
- **T-DIF-01's EdgeLength cap.** "EdgeLength x = 1 for E ≥ 8" (:464) names no design, and no §5 fixture reaches 8 (F3 is
  7.409). Name or build one.
- **C08's margin.** It is 0.019999999999999574 in doubles (`critic/margin.luau`), not "exactly 0.02" (:378). The new
  FixtureSet check must keep Blueprints.spec.luau:79's `>= 0.02 - 1e-12`.

### C7 [moderate / minor] Coverage and detail gaps

- **§5.6 rows with no M3 assertion.**
  - "C10/C11 = C01 + 20 filler parts: D rises by at most 0.008" (SPEC.md:1245).
  - "4 flush plates in F5 / C02 / C05 |ΔD| 0.0000" (SPEC.md:1244).

  Add both to T-DIF-04 or T-DIF-13.
- **§14.1's L1 gate.** The ≤ 30 s budget for `--quick` is not planned against. M3 adds roughly 600–700 fast analyses
  (T-DIF-01/04/07/10 and the goldens). Time it after step 9 and move corpora to `t.slow` as needed.
- **The "+ a Dust speck" cases.** They are Disconnected (:342) and measured only with `measureInvalid`. Production never
  measures a disconnected design (SPEC.md:862–863; §11.13 runs without `measureInvalid`). An attached speck (Dust, valid) is
  the production path. Keep the floating one only for comparability with E-S2.11.
- **P1 runs twice in T-PERF-01:** once as the X08b alias and once as P1 (:502–503).
- **Factors' require list (:53)** lacks Limits (CONTACT_TOL), unless D1 replaces it with VOID_GAP.
- **σ's duplicate.** The test the plan proposes already exists: tests/Definitions/EquipmentTypes.spec.luau:83–87.
- **T-DIF-06 under D2.** F5 at 0.045 gives 0.2073 (still Hard), and C02 +0.20 gives 0.2056 Hard. §5.5's prose
  (SPEC.md:1235–1236) and E-S2.2:209 quote 0.2070, so they move if D2 lands.

## Checked and correct

- **References.** About 80 sampled line references into SPEC, evidence, M1-notes, M2 code and the prototype point where the
  plan says.
- **Constants.** Every value and location in §3 matches Balance, EquipmentTypes, Steps, Tiers, Materials, CraftPlans,
  Quantize and Tol. Only VOID_GAP and three test constants are new.
- **Fixtures.** The fixture sources check out:
  - v2/fixtures.luau, d_cost.luau:28–36 and worst_P.json (11 designs; totals 35.24–54.55 ms; M3's share 4.25–16.05 ms).
  - P4's margin of 0.01.
  - X08 has no construction ("hitbox-sized" P1 per out_v2_perf_before.txt:25).
  - T-EDG-01, T-DIF-12 and T-DIF-13 are undefined: §14.6 defines only 03, 04/05, 07, 10 and 11.
- **Map and rules.** The prototype → build map, the determinism list and the layering all hold: types live below Analyze
  and are re-exported, so there is no cycle.
- **Expected numbers.** §4.3's numbers reproduce (`fixtab`): C09 0.3186 / 0.3180 / 0.3101, F3 0.4405, C04 0.3366,
  C13 0.1136, F1 = F5 0.1038, P5 0.1698 / 0.1439. Every other §5.5 value matches in rank order, and LAM1 and LAM2
  reproduce.
- **T-DIF-06's real edits** keep their tiers and order under D2 and D1.

## Reproduce

From the repo root, `lune run <abs>/m3-plan/critic/critic_proto.luau -- <section>`:

| Section | What it reproduces |
|---|---|
| `gen 300` | C1, C2 |
| `gen 300 safe` | C1 |
| `t3:gen 300`, `t3:fixtab` | C1 (min-over-axes chords) |
| `gen 150 all b1600` | C2 (4× probe budget) |
| `fixtab` | §4.3's numbers |
| `lam` | C3 |
| `mirror 150`, `mirrordiag 31` | C4 |
| `sweep` | T-DIF-06 edits |

Separately, `critic_build.luau` reproduces C5 and `margin.luau` reproduces C08's margin. `critic/analyze_t3.luau` is a copy
of `proto/analyze.luau` with a `THETA3` switch.
