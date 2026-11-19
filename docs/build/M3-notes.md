# M3 build notes

Open items and deviations reported while building M3 (difficulty: `Physics/Edge`, `Factors`, `Difficulty` and their
place in `Analyze.run`), by its four builders, one after another. The plan is `.build-notes/m3-plan/plan-r2.md`; the
lead's decisions on its review, `lead-decisions-r2.md` (L1–L17), take precedence over it. Read the part for your step
before building it. The items are point-in-time, so check them against the code and SPEC.md; strike what is done.

## Baseline (before builder 1)

The plan was measured on the M2 snapshot `m2x-r4-base`, before M2's last fix rounds. Its baseline scripts were re-run on
a copy of the committed tree (HEAD 7eb9914, M0–M2, identical to the working tree), with `proto-r2`'s scripts beside it.

- `tab.luau`: identical to the plan's `tab.txt`, every fixture, both orders.
- `es29.luau -- rank`: identical to `es29_rank.txt` (C09's Thinness on All 0.3898 and Hammering 0.3186 in rank order).
- `orders.luau -- 100 C09 P5`: in part order C09's Hammering spans 0.3170–0.3190 (100 distinct outcomes) and P5's
  0.1853–0.1902 (95); in rank order one outcome each, equal to the fixture's own (0.0001 / 0.3186 / 0.1904,
  0.0328 / 0.1902 / 0.1202). With the plan's own counts (300 C09, 60 P5) the lines equal `orders.txt`'s
  (0.3170–0.3195, 298 distinct; 60).
- `contracts.luau -- dif04`: identical; the 11 T-DIF-04 cases bit-identical.
- `dump_fixtures.luau`: identical literals, so the fixture rows pasted below are the committed tree's bits.
- So fix rounds 5 and 6 moved nothing [7] reads, and there was no difference to trace.
- Suite times on the committed tree, no other Lune process, the machine 3–16 % busy: `--quick` 18.96 s and 18.90 s (590
  pass, 16 skip, 51 files); the full suite 163.57 s (606 pass). The plan's snapshot took 16.94 s (580) and 168.88 s
  (596).

## B1 Fixtures and Edge

**What was built**

- `tests/fixtures`: `Build.YM90` and the shared record type `Build.Measured` (expectations without Blueprints' oracle);
  `Calibration` (C01, C02, C02s, C04–C15), `Regression` (34 records: X01–X07, every variant, and the union blades
  X01base and X02base), `Cost` (P1–P5; P1–P3 with a floating and an attached speck; `X08`; `TPERF`, T-PERF-01's 39
  cases), `WorstDesigns` (a copy of `docs/spec/prototypes/S2/cover/worst_designs.luau`); `Adversarial` gains A25, A26
  (with its base as the variant `A26base`) and A27, and A14's relation becomes `BitIdentical`.
- `tests/FixtureSet/{Calibration, Regression, Cost}.spec.luau` and their shared `Measured.luau`: records, structure,
  margins, the canonical fixed point, every row bit for bit against the prototype, Physics' verdict (validity, errors,
  cleaned lists), `WorstDesigns` against the docs file bit for bit.
- `src/shared/Physics/Edge.luau` and `tests/Physics/Edge.spec.luau` (T-EDG-01, defined in the plan's [8.1]).
- `tests/lib/Tol.luau`: `TOL_EDGE_REL` 0.02 (L5).

**Measured**

- L1. cutIndex on the committed tree, on `MassProps`' bladeLength: F1 = F5 0.724180, F2 0.425000, F3 1, F4 0.134375,
  C01 0.300000, C02 = C02s = C12 = C14 = C15 0.766667, C04 1, C05 0.158369, C06 0.890676, C07 0.313333, C08 0.617500,
  C09 1, C10 = C11 0.271528, C13 0.765380: L1's column on every row. Also A26 0.507963, P5 0.814442. EdgeLength is
  within 4.3e-5 of [7.1]'s 4-decimal column on every row (C07 the farthest).
- L3, option (a) first. Douglas–Peucker on the doubled crack-vertex lattice (vertex (i, j) → (2i, 2j), an edge's
  midpoint → (fi + ti, fj + tj)), the distance to the segment compared as integers (cross², |ap|²·|ab|² or |bp|²·|ab|²
  against tol²·|ab|²), ties to the first maximum, lengths as lattice length × h/2. Against the M3 emulator in the
  measure's rank order on the 64 fixtures:
  - 59 edges equal within 1e-12;
  - C15: 5.6261 → 5.6311, one exact tie in one span (cross 12 = 12; the float version took the later point
    (−0.28, 4.1418), the first maximum is (−0.26, 4.2418)), so Sharpening 0.4291 → 0.4299 (+0.0008), no tier;
  - P1: 1 → 4 chains (three of exactly 3 cells, 0.18 at h 0.06, where the float sum gives 0.17999999999999972);
  - P2: 15 → 16 chains, EdgeLength 1.315298 → 1.315099 (x 0 either way);
  - P4, P5: the same lengths and counts, other points.
  - So a §5.5 value moves by more than 0.0005, and L3 fell back to its option (b). Edge runs the prototype's
    Douglas–Peucker in blueprint XY, with the prototype's tie rule and its 1e-24 degenerate-span guard. (Fix round 1,
    fixer C: option (a) adopted on the raster read off the centres, where C15's tie is gone; the guard went with it.)
- Under (b), every fixture's edge equals the emulator's to the bit (64 of 64), and the pure prototype's in rank order
  (63; P1 keeps its own verdict). Y translation on Gen designs reproduces the critic: 2 of 300 designs (TestRng
  0x5EED0007, Y alone; #89 6.696057 → 6.691727) and 1 of 598 shifted copies (0x5EED0001, E-S2.10's Y offsets; #131 at
  +0.2, 6.450091 over 10 points → 6.426299 over 8, Sharpening |ΔG| 0.0037).
- For the lead: option (a) made Y shifts exact on all 898 copies (0 changes, lengths and raster to the bit). The same
  lattice rule with ties to the last maximum passes L3's criterion on the 64 fixtures (no §5.5 or E-S2.9 value moves;
  P1 1 → 4 chains, P2 EdgeLength −0.0597 with x 0). It was not adopted: L3 fixed the first maximum, and choosing the tie
  rule to fit the fixtures fits noise. The lattice version is in the builder's scratch (`m3-b1\work\out\
  Edge_lattice_a.luau`).
- L6. With one unit per kept part per row of each rung the ladder tries, Edge's longest median stretch between
  checkpoints (CHECK_UNITS 500) is 0.080 ms (worst valid 9; valid 8 0.064, P1 0.064, C05 0.065), against 0.298 / 0.267
  without the ladder's charge. Edge alone takes 0.58 ms (F5) to 5.48 ms (valid 9). Median of 15 rounds, Edge's inputs
  built outside the timing, the machine 0–4 % busy, no other Lune process.
- L7. P2's build frame: axis (−0.707107, 0.707107), bladeLength 2.107263, cutIndex 0. The emulator's prototype frame
  gives (0, 1), 2.988013 and 0.022514 (P2 + a speck 0.010131). P2's golden takes 0; Edge.spec pins it.
- L12, L16. The fast Gen corpus is 20 designs (`FUZZ_N_VALID` slow); Edge.profile has P-DET and P-NOMUT (frozen inputs,
  two runs, `Dump.canonical`) and gives the same profile for its list in any order.
- Suite times with builder 1's work, the machine 0–6 % busy, no other Lune process: `--quick` 21.31 s (633 pass, 17
  skip, 55 files; 18.90 s before), of which Edge.spec's fast cases take 2.4 s and the three FixtureSet specs about
  0.3 s; `scripts/verify` in full 165.9 s and 166.8 s, its tests 161.50 s and 162.37 s (650 pass; 163.57 s before).
  Edge.spec's slow case, 500 Gen designs, takes about 4.8 s.

**Open issues**

- L3 fell back to (b), so §17.1 O11 **[Decision to confirm]** carries the Y-translation figure for builder 4: "Y
  translation moves G up to 0.0037 through EdgeLength's simplification (Gen #131, TestRng 0x5EED0001, +0.2)".
  T-DIF-07(a) (builder 3) asserts |ΔG| ≤ `TOL_G_INVARIANT` on the fixtures and only reports it on Gen designs. If the
  lead prefers exact Y shifts, the lattice rule above is ready, with the C15 change (or its last-maximum variant) to
  bless. (Done by B4: O11 carries it. Fix round 1, fixer C: the lattice adopted, O11's Y-shift tie gone.)
- The raster is not translation-exact either, on 4 of the 20 F and C fixtures. A cell centre that lies exactly on a
  face whose plane holds the Z line, exactly `RASTER_TOL` from one, or on a thin Wedge's sharp edge, is decided by
  rounding, and a shift rounds it again. The prototype does the same, bit for bit (the emulator shows each case). Under
  E-S2.10's six offsets, 11 of the 370 shifted copies of the 64 fixtures change:
  - C05 + 0.125: one cell (the Wedge top's slope through the cell centre (0.33, 3.93)).
  - C09 − 0.037 in Z: 240 cells. Its bevels' sharp edges lie on the cell centres x = ±0.11, where the plain chord
    measures 4.34e-18 before the shift and 0 after it. bladeArea goes 0.620 → 0.524 and the mean thickness 0.0433 →
    0.0512, so cutIndex 1 → 0.8842.
  - C10 / C11 + 0.3317: a guard stud's top (y 1.745) lies `RASTER_TOL` under a cell row, so a hilt flag flips and buries
    one more edge a side. EdgeLength drops 0.04 / 0.02, and Sharpening's G moves 0.0063 / 0.0031 (the emulator's
    factors), past `TOL_G_INVARIANT` 0.002.
  - X03 (10 cells), X07c (2 cells) and P5 (12 cells) at + 0.3317, and P1 at (0, 0.2, 0.05) (1 → 2 chains, the same
    EdgeLength), are of the same kind. P5's three other Y offsets only swap two chains of equal length, whose lengths
    then differ in the last bit.
  - D moves only through the outline (C10, C11); bladeArea and the mean thickness reach cutIndex (S4). The plan's
    T-DIF-07(a) fixtures (F1, F3, F5, C02, C06) are not among them, so builder 3's case as planned passes.
  - §4.6's "Y translation-exact" does not hold at such ties. A fix needs tie-proof chord predicates in
    `Physics/Shapes` (M2's, so not done here) or a rule that keeps cell centres off part faces; either moves fixture
    values. Edge.spec asserts every other shifted copy exact and lists these four as known moves (`MOVES`). For the
    lead; builder 4 words §4.6 and §17.2. (Done by B4: §4.6 row 1, §5.6, O11 and §17.2's new row. Fixed in fix round 1
    by fixer A: the raster reads each cell off its centre, and every shifted copy is exact; `MOVES` is gone.)
- Builder 3: Edge's long loops are the local functions `rungFits`, `raster`, `crackEdges`, `traceLoops`, `emitRun` and
  `simplify`; add them to Analyze.spec's names list. Edge.spec already checks that each reaches a checkpoint at 500
  units.
- Builder 3: Edge defines `Vec2`, `EdgeChain` and `EdgeProfile` as Analyze does today; Analyze re-exports Edge's.
  `Edge.profile` returns `RasterStats` {cells, work} as a second value, for the budgets.
- Builder 3: the tiers in `Regression` and `Cost` come from the plan's [7.2] (the emulator, rank order); a floating
  speck's are those of its `measureInvalid` run. T-DIF-12's goldens come from `Analyze.run`: trace any difference.
- Where the plan says "printed, not asserted" (T-EDG-01 item 6's worst EdgeLength change), the specs print nothing:
  the runner is quiet, and no spec prints. The measured values are here and in the failure messages.
- `tests/fixtures/WorstDesigns.luau` is a 212 KB copy. When the docs file changes, copy it again
  (`FixtureSet/Cost.spec` fails until then).

**Deviations from the SPEC**

- Edge exports beyond §4.6's rows, as the plan's [3.2] has them: `profile` (with a second value, `RasterStats`),
  `cutIndex`, `simplify` (an optional spend) and `mergedLength` (on a copy). Edge required `Definitions/Limits` for
  `CONTACT_TOL`, the chords' merging tolerance, beyond the plan's list of its requires (no longer since fix round 1:
  the chords merge at `HIDE_OFFSET` + `EPS_GEOM`, Balance's).
- §4.6's chain order ("ties: first point x, then y") gains a last key, the order the chains were found, so the order is
  total. It decides only between two chains of one length that start at one point.
- The fixtures' core names are valid blueprint names (at most 32 code points, no "=", "°" or "×"), so they differ from
  the prototype's names; their labels keep the prototype's.
- A26's base is the variant `A26base` of case A26, and A26's relation names it (`to` may now be a variant key). A25 and
  A27 are built from F1's parts, A26 from the prototype's rows; their 20° and 40° turns are pasted.
- `Cost.TPERF` holds cores (P1 once, as "P1 (X08b)"), with the worst designs wrapped as cores named "Worst valid k" and
  "TooComplex k".
- §4.6 row 1's "Y translation-exact" does not hold at exact ties (above). (It holds since fix round 1.)

## B2 Factors and Difficulty

**What was built**

- `src/shared/Physics/Factors.luau` (the plan's [3.3]): `measure(ctx, set, spend?)` returns the set's 8 `FactorValue`s in
  FactorId order and a `FactorBudget` {thinStride, thinProbes, asymSpacing, asymWork}; `ORDER`; for tests `norm`,
  `cbrt`, `unionChord`, `thinAxis`, `thinness(ctx, set)` and `asymmetry(ctx, set)`. `FactorContext` = {parts, rank,
  probes, exposure, owned, touching, edgeLength, geometry}. Every walk is in the measure's rank order; the code is the
  prototype's `setFactors` without `%`, with L13's share term.
- `src/shared/Physics/Difficulty.luau` ([3.4]): `q`, `softOr`, `governing(parts, set)` (nil on an empty set),
  `planSteps(type)` (the enabled plan steps in order) and `step(stepId, factors, material)`; `StepAnalysis`.
- `tests/Physics/DifficultyHelpers.luau`: the factors' inputs built as Analyze's phases hold them, with no validation,
  and the steps as phase 6 will play them (WorkSet.select, then Factors.measure once per distinct set, then
  Difficulty.governing and Difficulty.step; nil when a set is empty); the prototype in the measure's rank order.
- `tests/Physics/Factors.spec.luau`: T-DIF-01 on Gen designs and the caps, T-DIF-06, T-DIF-08 (C13, and Gen swords built
  half and mirrored, L11), T-DIF-13's X06 oracle, [8.2]'s comparison with the prototype (L2), ORDER, cbrt, norm,
  unionChord, thinAxis, L13's share term, the budgets, the checkpoints, P-DET and P-NOMUT (L16).
- `tests/Physics/Difficulty.spec.luau`: T-DIF-02, T-DIF-03, T-DIF-05, governing, step, planSteps, P-DET and P-NOMUT
  (L16), P-ORDER, and one pass over every fixture: d per step against [7.1]–[7.2], the records' tiers and T-DIF-01's
  ranges.

**Measured** (Lune 0.8.9; the machine 0–4 % busy, no other Lune process)

- Against the plan's emulator (proto-r2 on a copy of the working tree with builder 1's work, the measure's rank order):
  every factor raw and every step's d bit-identical on all 64 fixtures.
- L2, against the pure prototype in the measure's rank order: PartCount, Thinness, Asymmetry, EdgeLength and
  MaterialMix bit for bit on the 63 fixtures whose verdict the build shares (all but P1); Volume within 1.4e-17;
  SurfaceComplexity within 1.3e-15 where hSurf agrees. X02 (hSurf 0.04 against 0.06): SurfaceComplexity raw 0.0069 and
  Joints 0.159 from the prototype's on All (0.00091 and 0.0225 on the Blade), and within 1e-12 of the build's own
  measure; its d equal. d equal on all 63. P1 has its own verdict: d 1.0000 / 0.0000 / 0.0086 ([7.2]),
  SurfaceComplexity and Joints within 1e-12 of its own measure.
- d per step equals [7.1]–[7.2]'s rank-order column on every fixture of the repo (70, with A24 and the six specks: C09
  0.0001 / 0.3186 / 0.1904, X02 Hammering 0.0510, P1–P3 with a speck 1 / 0 / 0.0048, 1 / 0.0674 / 0.0479 and
  0.2622 / 0.1759 / 0.1612, A24 0.0281 / 0.4000 / 0.3909), and every played and raw tier equals the records'. m is 0, so
  g = d everywhere. C09's Thinness on All is 0.3898 ([7.3]).
- [7.6] reproduced: F5's blade 0.060 → 0.043 thick gives Hammering 0.1037 / 0.1322 / 0.1658 / 0.1895 / 0.2070 (Hard) /
  0.2263 and Thinness on All 0.2594 → 0.5657; C02's blade +0.15 / +0.20 / +0.25 gives Sharpening 0.1889 / 0.2056 (Hard)
  / 0.2314 and EdgeLength 5.9635 / 6.0435 / 6.1635; PartCount C01 4 → C10 6.916; A24's Thinness 1 on both sets,
  Hammering 0.4000 Hard (raw Expert); Volume x 1 on P1 (2.2682), P2 (0.9968) and P4 (1.2608); F3's Blade
  SurfaceComplexity 2.9804 (x 1); the EdgeLength cap case valid at 8.2001 (x 1).
- T-DIF-13's oracle: Factors and Sampling planted with ASYM_N_MIN 120, ASYM_WORK 1e9 and N_MAX_AXIS 400 give X06's
  Asymmetry on the Blade 0 / 0 / 0.0413 / 0.1559 / 0.2817 / 0.4075 against 0 / 0 / 0.0396 / 0.1529 / 0.2804 / 0.4078
  measured, a largest error of 0.0030 (bound 0.02).
- L11, measured before asserting. The recipe as written (keep the parts with centre x ≥ 0, mirror those with x > 0)
  gives Asymmetry raw up to 0.1563 on All and 0.4590 on the Blade over 20 designs (PROP_BASE_SEED's stream), and 0.3296
  and 0.6026 over 500. `Gen.validSword` turns blocks about Y on the plane x = 0 (22 such parts in 20 designs, 465 in
  500), and the recipe leaves them unmirrored, so those designs are not symmetric. Mirroring as well the parts on the
  plane that are not their own image (`Mirror.isSelfSymmetric`), as the editor's mirror copy does (§11.10), gives
  Asymmetry 0 on all 20 and all 500, on both sets. One design in 20 had its blade at x < 0, which the recipe drops; such
  a sword is reflected first.
- T-DIF-07 on Gen designs through the real code (the plan's stream, TestRng 0x5EED0007, 300 designs): translated
  |ΔG| 0.0009 (#270), Thinness x 0.0022; segmented |ΔG| 0.0236 (#51), Thinness 0.0591, Asymmetry 0.0197 (Blade
  0.0143), SurfaceComplexity 0.0036 / 0.0056, no tier flip. That is the plan's `seg300.txt` to the digit (§17.1 O11).
- Cost: inputs built outside the timing; Factors.measure on each distinct set and Difficulty.step on each plan step;
  median of 15 rounds, odd rounds forward and even backward, a full collection before each case. 1.43 ms (F5) to 3.02
  (C05); P1–P5 1.66–3.93; P1–P3 with a speck 1.65–3.64; the worst valid designs 1.50–8.07 (valid 9). The longest
  stretch between checkpoints at CHECK_UNITS 500, with a phase before each set: the F and C fixtures 0.071–0.127 ms,
  P1–P5 and the specks 0.048–0.162, the worst valid designs 0.060–0.200 (valid 9). Thinness' per-probe charge ends it
  in 15 or 16 of 16 runs on every case, as the critic found (about 0.21 ms). With builder 1's Edge (0.58–5.48 ms), M3
  adds about 2–14 ms to `Analyze.run`.
- Suite times with builder 2's work: `scripts/verify` green in full, 179.9 s and 178.1 s, its tests 175.36 s and
  173.60 s (685 pass, 57 files; 162.37 s and 650 before); `scripts/verify -- --quick` green, its tests 23.74 s (665
  pass, 20 skip; 21.31 s before).
  Factors.spec's fast cases take about 1.6 s, the largest 0.45 s (the prototype comparison on A25–A27 and X01–X07);
  Difficulty.spec's take 0.9 s, the largest 0.53 s (every fixture's d). Slow cases: the mirrored swords on 500 designs
  3.6 s, T-DIF-01 on PROP_N designs 0.86 s, the material swap on 500 designs 4.4 s.

**Open issues**

- Builder 3, phase 6: build the `FactorContext` from what phases 1–5 hold: `parts`, the rank from
  `Sampling.measureRanked(parts)`, `probes`, `exposure`, `owned`, `graph.touching`, `edge.length` and `geometry`. For
  each row of `Difficulty.planSteps(core.type)`, take `set = WorkSet.select(core.parts, kept, row.worksOn)`; steps are
  nil if a set is empty (D5). Run `Factors.measure(ctx, set, spend)` once per selector key, with `phase()` after each,
  then `Difficulty.step(row.step, values, Difficulty.governing(parts, set))`. `DifficultyHelpers.steps` does exactly
  this without spend, so comparing `Analyze.run`'s steps with it on the fixtures checks the wiring.
- Builder 3: re-export `FactorValue` from Factors and `StepAnalysis` from Difficulty. Factors' long loops are the local
  functions `thinness` and `asymmetry` (with `Sampling.volumeSamples`, already M2's); add them to Analyze.spec's names
  list. Planted maps: Factors requires Balance, Types, Limits, Materials, MassProps, Sampling and Shapes; Difficulty
  requires CraftPlans, Types, Materials, Steps, Tiers, Util/Quantize, Factors and Shapes. Difficulty.spec's P-ORDER
  plants reordered Materials, Steps and Tiers modules (their rows handed to Catalog.build shuffled) into both, which
  Analyze.spec's P-ORDER can reuse.
- Builder 3: Factors.measure's budget (stride, probes, spacing, work) is its second value, for P1's budget case near
  Analyze.spec line 709; `AnalysisBudget` keeps §4.7's five fields.
- Builder 4: §5.2's Thinness line says "(Σ_W w if no Blade part)"; the build follows L13 (the weight of the probes
  taken in the striking slot, or of all of them where none is). §14.6's T-DIF-08 gains the mirrored Gen recipe above.
  §1.3 L2: Factors also requires Definitions/Materials and Difficulty Physics/Shapes (below). Factors.luau's header
  carries **[Decision to confirm]** (§17.1 O10) for cleaned parts inert in every factor (D1), and (§17.1 O11) for the
  stride and θ following the parts as built (D2, G up to 0.0236); renumber them if §17.1 numbers the new rows
  otherwise. (Done by B4: §5.2, §14.6; O10 and O11 keep their numbers; the header's G figure is B3's.)
- M2's verdict and measure: nothing found wrong. X02's grid differs from the prototype's by M2's rule (the measure's
  grid over the kept parts), which L2 accounts for.

**Deviations from the plan and the SPEC**

- `FactorContext` has no `kept`: nothing reads it, since a set holds kept parts only (WorkSet.select).
- Factors requires `Definitions/Materials`, beyond [3.1]'s list: MaterialMix counts the Materials rows the set holds,
  walking `Materials.ordered`, as [3.3]'s table says. Difficulty requires `Physics/Shapes` for the `Prepared` type of
  `governing`'s parts.
- L11's recipe gains two steps, measured above: the parts on the plane that are not their own image are mirrored too,
  and a sword with no Blade part at x ≥ 0 is reflected first. The bound is on the normalized factor (x ≤
  TOL_ASYM_ZERO; §16.32's unit is "factor"); every design measures 0.
- T-DIF-01's ranges on every fixture run in Difficulty.spec's pass over the fixtures (with [7.1]–[7.2]'s d and the
  tiers), not in Factors.spec, so each fixture is measured once; Factors.spec keeps the Gen corpora and the caps.
- Charges: per Thinness probe taken, its part's higher parts (the ownership test), plus 2 per part of the set only where
  it is measured; per Asymmetry part, the set and its higher parts (the candidate lists), besides 1 + its candidates per
  sample. The plan charged 2·#set + #higher per probe taken.
- Difficulty.spec adds P-ORDER for Factors and Difficulty; L16 asks for it in Analyze.spec (builder 3).

## B3 Analyze's integration, T-DIF and T-PERF

**What was built**

- `src/shared/Physics/Analyze.luau` (the plan's [3.5], D5): phase 6 walks the parts in the measure's rank order
  (`Sampling.measureRanked`), kept indexed alike, takes the difficulty frame on them (`MassProps.difficultyFrame`) and
  the edge (`Edge.profile`), and fills `physics.edgeLength`, `physics.cutIndex` (`Edge.cutIndex` on the physics'
  `bladeLength`) and `budget.edgeCell`, then a checkpoint. Phase 7 takes every enabled plan step's work set first
  (`Difficulty.planSteps`, `WorkSet.select`); if any is empty, which only `measureInvalid` reaches, `steps` is nil and
  no factor is measured (D5). Otherwise `Factors.measure` runs once per distinct selector ("All", or the slots joined
  by "+"; a keyed cache, looked up and never iterated) with a checkpoint after each, then `Difficulty.governing` and
  `Difficulty.step` per step. `Vec2`, `EdgeChain`, `EdgeProfile`, `FactorValue` and `StepAnalysis` are re-exported from
  Edge, Factors and Difficulty. The header's steps 6 and 7 are rewritten.
- `tests/Physics/Analyze.spec.luau`:
  - the §4.7 report case asserts the edge and the steps: `physics.edgeLength = edge.length`, the main chain's;
    `cutIndex = Edge.cutIndex(bladeLength, bladeMeanThickness)`, 0.724180; `edgeCell = edge.cell`; the frame; plan
    order; F1's d (L14);
  - A06 with `measureInvalid` carries an edge and 3 steps; a new D5 case (a Blade part enclosed in its guard,
    `measureInvalid`) has `steps` nil and the empty edge;
  - P1's budget case checks M3's budgets on `H.p1()`: the raster's rung fits or is the last; Thinness ≤
    `THICK_BUDGET` probes and Asymmetry ≤ `ASYM_WORK` or the last rung, per work set; the report's edge and factors
    are the ones measured with those budgets ([10]);
  - phases only: 5 → 8 checkpoints on F2 (edge, All, {Blade}), the same analysis; the long loops gain Edge's
    `rungFits`, `raster`, `crackEdges`, `traceLoops`, `emitRun`, `simplify` and Factors' `thinness`, `asymmetry`
    (`emitRun` and `simplify` reach a checkpoint on P5's comb, not on `H.p1()`);
  - P-ORDER plants Materials, Steps and Tiers rebuilt in shuffled order into MassProps, Factors and Difficulty, and
    those into Analyze, on F1–F5, C09 and P1 (L16).
- `tests/Physics/DifficultyHelpers.luau` gains `analyzeRequires` (Analyze's requires, as it names them),
  `plantedPhysics` (MassProps, Factors, Difficulty and Analyze anew on planted Definitions) and `reordered`.
- `tests/Physics/Invariance.spec.luau`: T-DIF-04 ([7.6]'s designs, the A variants' BitIdentical relations and A25,
  `Gen.withFiller`), T-DIF-07 ((a) the fixtures × E-S2.10's offsets and `Gen.translated`; (b) F5's cuts, C12 against
  C02 and `Gen.segmented`; (c) shuffled ids on C09, P5 and P1), T-DIF-09 (step scoping, a planted CraftPlans through
  Analyze, A27, O8's label rule) and T-DIF-10 (a yielding checkpoint = none = `measureInvalid`).
- `tests/Physics/DifficultyTable.spec.luau`: T-DIF-11 (every record's tiers and raw tiers, F5's margin), T-DIF-12
  (the goldens below) and T-DIF-13 (the Regression records' relations, the A variants', C10 and C11 against C01, X03's
  fin, L15).
- `tests/Physics/Perf.spec.luau`: T-PERF-01 as §14.11 states it (below). `tests/lib/Tol.luau`: `PERF_RUNS` 15.
- `tests/golden/difficulty_{calibration, regression, cost}.bv1.golden.txt`, per fixture `{id, valid, cleaned, physics
  = {mass, volume, balance, reach, bladeLength, edgeLength, cutIndex}, edge = {chains, lengths, cell, bladeArea,
  bladeMeanThickness}, steps = {{step, g, m, d, tier, tierRaw, material, factors}}}` ([8.3]): calibration holds F1–F5
  and C01–C15 with C02s, regression the 34 Regression records and A24–A27 with A26base, cost P1–P5 and the 6 specks;
  42,266, 84,811 and 23,900 bytes.

**Measured** (Lune 0.8.9, Analyze.run as built, the measure's rank order)

- [8.3] before blessing, on a scratch copy of the working tree with `proto-r2`'s scripts: `tab.luau` and
  `es29.luau -- rank` identical to the plan's `tab.txt` and `es29_rank.txt`. Then Analyze.run on the 70 fixtures of the
  repo (F, C, X, P, the specks, A24–A27): every d equals [7.1]–[7.2]'s rank-order column (C09 0.0001 / 0.3186 /
  0.1904; X02 Hammering 0.0510; P1 1 / 0 / 0.0086; P1–P3 with a speck 1 / 0 / 0.0048, 1 / 0.0674 / 0.0479,
  0.2622 / 0.1759 / 0.1612), every tier and raw tier its record's, every step bit-identical to builder 2's
  `DifficultyHelpers.steps`, and every factor raw bit-identical to the emulator's rank-order dump (`tab.luau -- dump`)
  on the 63 prototype fixtures (1,512 raws, 0 differ). EdgeLength and cutIndex as builder 1 measured (P2's cutIndex 0,
  L7; A25 0.724130, its hidden grip core in the physics frame; A26 0.507963). (Fix round 1, fixer B: A25 0.724180,
  F1's, the physics frame being the kept Grip parts'.)
- `lune run tests/run -- --bless` (the whole suite, 708 pass): `git diff tests/golden` shows the three new files and no
  change to `balance_fingerprint`, `definition_ids` or `world_build_list`.
- T-DIF-04: the 11 cases of [7.6] bit-identical (steps and edge), each filler cleaned; the bases' d C04 with a 0.075
  blade 0.0000 / 0.1863 / 0.3835, C09 0.05 longer 0.0008 / 0.3299 / 0.2153, C09 + the plate 0.0009 / 0.3599 / 0.2542
  (Hard; C09 alone 0.1904, Normal). `Gen.withFiller` on 500 designs × 3 kinds (the slow case): every filler cleaned,
  every step and edge bit-identical.
- T-DIF-07 (a): F1 and F5 |Δx| 0.0017 and |ΔG| 0.0007 over the 6 offsets; F3 (3 inside the hitbox), C02 and C06 at
  most 2.2e-15 and 0. (b): F5 in 2, 3 and 7 pieces |Δx| ≤ 7.2e-16, |ΔG| 0; C12 against C02 8.3e-16, 0. (c): C09, P5
  and P1 with shuffled ids, steps and edge bit-identical, physics within 1e-12 part by part.
- T-DIF-07 on Gen designs, on the specs' own stream (the Prop cases of `PROP_BASE_SEED`), 500 designs, every weighted
  factor (`s/inv_measure.luau` in the builder's scratch):
  - translated: |Δx| ≤ 0.0040 (Hammering's Thinness), |ΔG| ≤ 0.0016 (#344), no flip;
  - re-cut flush (all 500 have a cut): Volume and EdgeLength 0; |ΔG| 0.1250 (#152), then 0.0615, 0.0448, 0.0378,
    0.0325; 5 designs past 0.024, 2 past 0.05, **one tier flip**. #152 (case seed 515583194): two short tip Blocks,
    0.0911 × 0.2637 × 0.1184 and 0.0846 × 0.3197 × 0.1184, are each cut into 3 pieces 0.0879 and 0.1066 long, so each
    piece's thinnest local axis turns from X to Y (θ, §5.2): Thinness on All 0.3395 → 0.0269, Hammering 0.2158 Hard →
    0.0908 Normal. Asymmetry moves by up to 0.0730 on All and 0.1261 on the Blade (#115).
  - D2's "G up to 0.0236, no flip" (300 designs of TestRng 0x5EED0007, which builder 2 reproduced) understates it
    (open issues).
- T-DIF-08, a whole design against its X mirror image (`Blueprint/Mirror`; "printed" in the plan): F1–F5 and C01–C15
  identical; 150 Gen designs of the Prop stream |ΔD| ≤ 0.0081 (#48, Thinness x 0.0203), EdgeLength ≤ 0.37 % (#132), no
  flip (the plan: 0.0069 on TestRng 0x5EED0008).
- T-DIF-09: F3's blade labelled Guard plays Sharpening 0.6104 → 0.0645, C08's 0.2487 → 0, Smelting and Hammering
  unchanged (§17.1 O8); a plan with Hammering disabled and Finishing appended plays Smelting, Sharpening, Finishing.
- T-DIF-13: X01 0.0002, X02 0.0010 (bounds 0.01); X01raw against F5 0.0281 (0.05); X03's Thinness 0.00034 (0.02);
  X04's EdgeLength 0.00 % (2 %); X05 and X07 |ΔG| 0.0007 (0.01), X07's mass 0.014 % (0.5 %); A25 0.0000, A26 0.0011,
  A27's Sharpening 0.0000 (Hammering 0.1037 → 0.1537); C10 / C11 against C01 +0.0079 / +0.0076 at most, all Normal.
  X03 (L15): F4's one chain of 5.7237 splits in two, the main one 4.7564, and Sharpening goes 0.3420 Hard → 0.1980
  Normal.
- T-PERF-01 (`--filter Physics/Perf`, run alone, the machine about 1 % busy before it, no other Lune process; the case
  takes 36 s), medians of 15:
  - the F, C and X fixtures: total 2.90–12.12 ms (C05), longest stretch 0.078–0.230 ms (F2), under 0.35;
  - reported against 0.35: P1–P5 and the specks 0.084–0.321 (P4), the worst valid designs 0.123–0.242, past the cap
    0.077–0.112, none past 0.35;
  - totals: P1 28.21 ms (≈ 73 Studio at 2.6 ×); the worst valid designs 19.24–48.95 (valid 8, `tclimb_3.json #6`,
    ≈ 127 Studio), 10 of 11 past 28.8 ms (75 ÷ 2.6); P1–P5 and the specks 5.60–28.21; `TooComplex` answered in
    10.24–24.22 ms. All under `ANALYSIS_LUNE_MAX_MS` 60 (11 ms to spare on valid 8), as [9.3] measured on the
    emulator (48.99, P1 28.52).
  - A first version took no collection before the stretch run: the stretches then reached 0.287 on the fixtures (X03),
    0.346 (P3 + a floating speck) and 0.433 (worst valid 11, `tclimb_1.json #5`), collections (§4.9's note). The
    plan's `perf.luau` collects before both runs, and so does the spec.
  - In `scripts/verify`'s full run T-PERF-01 comes after the specs before it in path order (not after every other spec,
    as first written here: fixer E), in one process with a larger heap: the fixtures' stretches stayed at 0.077–0.226 ms
    (F2), but P1 with a speck reported 0.58–0.60 and worst valid 10 (`tclimb_4.json #4`) 0.65, past 0.35 (reported, as
    §14.11 has it); totals P1 28.57, valid 8 49.37.
- M3's share (`work/perf_share.luau`: HEAD's Analyze against the working tree's, 15 rounds, a collection before each
  run, alone): 1.61–7.10 ms on the F, C and X fixtures (C05), 3.17–7.95 on P1–P5, 5.23–9.03 with a speck, 4.07–14.25 on
  the worst valid designs (valid 9); nothing past the cap. M3's longest stretch ends in Thinness' per-probe charge on
  nearly every case (now and then in the raster, Asymmetry, `simplify` or `rungFits`): 0.07–0.26 ms on the fixtures, at
  most 0.23 on the worst valid designs.
- Checkpoints at `CHECK_UNITS` 500 with `measureInvalid`: F2 97 (Analyze.spec's bound < 150; 41 before M3), F5 108,
  P5 222, `H.p1()` 1,248.
- `scripts/verify` in full, with these specs: green, 707 pass, its tests 244.67 s and 245.56 s, the whole 249.3 s and
  250.2 s (before this step: 178–180 s, 685 pass); T-PERF-01 takes about 36 s of it, Invariance's slow cases about
  23 s.
- Suites (quiet, no other Lune process): `--quick` 23.93 s before this step (665 pass, 20 skip); 25.49 s with phase 6
  wired and nothing else (+1.56 s: every analysis of the earlier specs now measures M3); 27.75 s with the new specs and
  their 20-design Gen corpora fast; 26.81 s with those in `t.slow` (683 pass, 24 skip, 60 files). Fast cases:
  Invariance 0.71 s, DifficultyTable 0.58 s (76 analyses, shared by its cases).

**Open issues**

- For the lead (D2, **[Decision to confirm]** (§17.1 O11)): flush re-segmentation moves G by up to 0.1250 with a tier
  flip on the specs' own Gen stream (#152 above), against D2's "about 0.024, no flip" from another stream. The
  mechanism is D2's (θ follows a piece shorter than the part is thin), at 5 × the figure. O11's text, §5.6 and §17.2
  need it; T-DIF-07(b) asserts only Volume and EdgeLength on Gen designs, as D2 says, so nothing fails. Reproduce with
  `Gen.validSword`, `Gen.translated` and `Gen.segmented` in that order on `TestRng.new(515583194)` (Prop case 152),
  whole against re-cut. (Fix round 1, fixer A: chiefly the stride, not θ — its main blade, turned, took one outer
  layer whole and the middle one cut; with θ on every local axis, the canonical walk and the lattice pick, ΔG 0.0006.)
- `--quick` is 26.8 s: past [9.4]'s 25 s, under §14.1's 30 s. Invariance's Gen corpora run in `t.slow` only. If builder
  4's SPar02 fast case takes `--quick` past 30 s, builders 1 and 2's 20-design fast corpora (Edge item 6, Factors'
  T-DIF-01 and T-DIF-08, Difficulty's T-DIF-05; about 0.64 s together) can follow them.
- Builder 4, SPEC: §4.7's comment for D5 as built; §14.11's T-PERF-01 row with the spec's cases (the F, C and X
  fixtures and `Cost.TPERF`), a collection before each run and the median of `PERF_RUNS`; §16.32's `PERF_RUNS` row;
  §4.9, §5.6's CPU attacks row, §16.10, §16.32 and O7 with the totals as built (valid 8 48.95 ms Lune ≈ 127 Studio,
  P1 28.21 ≈ 73) **[Decision to confirm]** (§17.1 O7); T-DIF-08's whole-design mirror figure, 0.0081 on the Prop
  stream. (Done by B4; the mirror figure is in E-S2.13.)
- T-PERF-01 is the one spec that prints: §14.11 makes its report the test's output (three lines, slow runs only).
- M2's verdict and measure: nothing found wrong.

**Deviations from the plan and the SPEC**

- T-DIF-07's |Δx_f| is on the factors each step weighs (its terms: E-S2.10's "MVP factors"). PartCount and Joints
  count the pieces of a flush re-cut, as they should (F5 in 2 pieces: PartCount x +0.077).
- The Gen corpora of T-DIF-04, T-DIF-07 and T-DIF-10 run `FUZZ_N_VALID` designs in `t.slow` only, not also 20 fast as
  [8.2] with L12 has them: [9.4] moves corpora to `t.slow` past 25 s. T-DIF-10's fast case runs F1–F5 and C09; T-DIF-04
  and T-DIF-07 keep their fixture designs fast.
- T-PERF-01 follows §14.11 as M2 left it rather than [8.4]'s list: the F, C and X fixtures are cases too, and the
  stretch is asserted on them only. It collects before the stretch run as well as before the timed one (the plan's
  `perf.luau` does). `collectgarbage` runs from a `luau.load` chunk, since luau-lsp's standard platform declares none.
  75 ms and 2.6 are local to the spec (§4.9's), not Tol rows.
- The goldens' names carry `Versions.BALANCE_VERSION` (bv1 today), §14.9's `<name>.bv<N>`.
- T-DIF-13's X06 relation (Asymmetry against the 120-probe oracle) stays in Factors.spec, builder 2's; DifficultyTable
  checks the other kinds. DifficultyTable analyses each fixture once and shares it between its cases.
- T-DIF-08's whole design against its mirror image is in no spec ("printed, not asserted"); its numbers are above.
- Analyze requires Edge, Factors, Difficulty and Blueprint/WorkSet, not CraftPlans ([3.1]): `Difficulty.planSteps`
  reads the plan.
- P-ORDER shuffles Materials, Steps and Tiers (L16); CraftPlans has one row, so there is nothing to shuffle.

## B4 S-PAR-02's digest and the SPEC

**What was built**

- `tests/fixtures/Parity.luau`: S-PAR-02's list, in digest order: F1–F5, C01–C15 (C02s included), every Adversarial
  variant, the X fixtures, P1–P5 and the six specks, then WorstDesigns' valid and TooComplex designs named as
  `Cost.TPERF`'s cores ("Worst valid k", "TooComplex k"). A fixture cannot require src/, so an Adversarial variant comes
  as its draft: Parity.spec and the snippet hand it to `Canonical.draft` and drop it when Canonical refuses it (L17);
  43 of the 149 pass.
- `tests/lib/Tol.luau`: `PARITY_DESIGNS` 200, `PARITY_SEED` 0x5EED0002. `tests/lib/Golden.luau`: `Golden.digest(name,
  value)` writes `<name>.digest.txt`, at most `DIGEST_MAX_BYTES` 1024 (§14.2), compared and blessed as `check` is (the
  two share one comparison), and `Golden.readDigest`. `tests/Meta/Runner.spec.luau` has a case for them.
- `tests/Physics/Parity.spec.luau`: the list, fast (its order, unique names, Canonical as each variant's record says);
  the digest, slow (about 2.5 s): `{version = 1, analyze = {fixtures, generated}}`, each group `{bytes, designs,
  fnv1a32}` of its lines (a name, a tab, `Dump.canonical(Analyze.run(core, {measureInvalid = true}))`, a newline), in
  `tests/golden/parity.bv1.digest.txt` (131 bytes); every design's name and the fnv1a32 of its line in
  `parity_designs.bv1.golden.txt` (13,781 bytes), for diffs.
- `tests/ItemRender/FakeRoblox.luau`: `RunService:IsClient()` (the inverse of `Options.server`), `IsA`, `GetChildren`;
  `tests/golden` as StringValues named by the file's stem, as Rojo maps a `.txt`; `Options.goldenRewrite(stem, text)`;
  `Options.omit` takes golden paths too.
- `tests/studio/e2e/S-PAR-02.luau`: the snippet in S-PAR-01's style ([8.5]): preflight (a Play session's Server or
  Client data model, a known `GROUP`), the golden before any analysis, one `analyze` line per group against the
  golden's entry, a `digest` line for the whole text when `GROUP` is "all", the summary. `Analyze.run(core,
  {measureInvalid = true, checkpoint = slice})`, `slice` yielding once `SLICE_MS` 4 of work is used, between designs
  too. After an `analyze` FAIL, `hashes` lines give every design's [name, fnv1a32], 20 to a line.
- `tests/Physics/SPar02.spec.luau`: the snippet on FakeRoblox. Slow (L17): the whole digest in the Server and in the
  Client data model, every line PASS, each group's entry the golden's, a yield per slice; `GROUP` "fixtures", then
  "generated". Fast (0.45 s): a short run (the generated group's first 25 designs) passes on a golden entry made for it
  and fails on one whose hash is 1 off, its `hashes` lines equal to `parity_designs`' entries; preflight (not running,
  in either data model; an unknown `GROUP`); a missing digest (a `golden` FAIL naming the folder's children, no frame
  spent); a missing module (a crash line that names it); the snippet run as one text.
- SPEC.md and SPEC-evidence.md (below); `docs/spec/prototypes/S2/m3/` (`limits.luau`, `out/limits.txt`, a README), the
  script behind E-S2.13's 2 % rule figures; README.md's Layout and Status; the header comment of
  `src/shared/Physics/Factors.luau`, whose O11 figure was D2's 0.024 and is now B3's (0.125 and a tier).

**Measured** (Lune 0.8.9; no other Lune process ran)

- The digest (`s/digest_time.luau` in the builder's scratch, the machine about 1 % busy): the fixtures' group 136
  designs (106 drafts refused), 424,515 bytes, fnv1a32 945249129, 1.46 s (1.42 s of it `Analyze.run`); the generated
  group 200 designs, 706,909 bytes, 440098388, 0.94 s; the longest line 7,543 bytes (worst valid 3). On FakeRoblox the
  snippet takes 2.54 s in the Server data model and 2.38 s in the Client one, about 590 yields at `SLICE_MS` 4, every
  line PASS. In Studio, at 4 ms of work a frame and Studio 2.6 × Lune (§4.9's assumption), about 26 s a call; not
  measured.
- `rojo sourcemap test.project.json --include-non-scripts` (Rojo 7.7.1) names the goldens' StringValues by stem, e.g.
  `golden/difficulty_cost.bv1.golden` for `difficulty_cost.bv1.golden.txt`: the snippet looks for
  `golden["parity.bv1.digest"]`.
- L4 and O11 again, through `Analyze.run` as built (the plan and its critic measured through the emulator on the M2
  snapshot): `docs/spec/prototypes/S2/m3/limits.luau`, 27 s, its output `out/limits.txt`.
  - The critic's proud-core family: 96 families, 12 crossings, |ΔD| 0.2696–0.4070, 7 tier flips on 6 crossings, the
    critic's figures to the digit. Hammering's jump: Thinness 0.1038–0.3588 (all of it on 7 crossings), SurfaceComplexity
    up to 0.3000; Smelting down 0.0660–0.0996 (Volume).
  - The plan's recessed sandwiches, core against core + sheet: 7 flips over the 9 designs, the largest 0.3713 (0.8 ×
    2.5 × 0.04, core 0.60: 2 flips; Thinness −0.1911, SurfaceComplexity −0.1802); rows 7–9 0.1521 / 0.2566 / 0.3713
    with 0 / 1 / 2 flips; LAM1 0.3235 (SurfaceComplexity +0.2876, Thinness +0.0359).
  - TestRng 0x5EED0001's design 131 at +0.2 in Y: EdgeLength 6.450091 over 10 points → 6.426299 over 8, the raster
    equal, Sharpening's g 0.4580 → 0.4543 (|ΔG| 0.0037).
- Suites: `scripts/verify -- --quick` green with this step's code, its tests 27.22 s (690 pass, 28 skip, 62 files;
  26.81 s and 683 before): the new fast cases take about 0.5 s (Runner's digest case 0.01 s, Parity's list 0.01 s,
  SPar02's five 0.45 s). `--filter S-PAR-02` (SPar02's 8 cases and Parity's digest): 9 pass, 10.48 s.
- `scripts/verify` in full, three times: green, 718 pass, 62 files, its tests 255.28 s, 254.20 s and 252.86 s, the
  whole 260.0 s, 258.9 s and 257.7 s (707 pass and 249–250 s before this step; no other Lune process, the machine 5 %
  busy before the first). In those runs T-PERF-01, after the specs before it in path order in one process, reported the
  F, C and X fixtures at 2.872–12.322 ms (C09) with stretches 0.077–0.231 (F2), P1 28.56–28.80, the worst valid designs
  19.608–49.829 (valid 8), and past 0.35 P1 with a floating or an attached speck 0.433–0.479, worst valid 9 0.365–0.378
  (twice) and worst valid 10 0.567–0.620: reported, collections (B3 saw 0.52–0.65 there).

**SPEC and evidence edits** (every value measured on this tree, by B1–B3 above or here)

- §1.3 L2: Physics' chain gains Edge → Factors → Difficulty. §4.1: sums in part order, Edge's and Factors' walks in the
  measure's rank order (L9); S-PAR-02 named as the digest `--!native` waits for.
- §4.6: row 1's "Y translation-exact" with its exact ties (B1); row 4: Douglas–Peucker in blueprint XY, ties to the first
  point, which a Y shift can tip (L3 (b), O11; fix round 1, fixer C: on the integer lattice); row 5: the chains' third key (B1), cutIndex 0 with no thickness, X03's
  fin, the rank-order walk and the ladder's charge (L6).
- §4.7: D5 as built (B3), and where the M3 types live. §4.9: M3's totals, share and stretches as built (B3's T-PERF-01;
  B1's ladder figure), the median of `PERF_RUNS`, C05 ≈ 32 Studio, O7's 127 ms and 32 Heartbeats (D7, L10).
- §5.2: the probes walk the measure's rank; L13's share term; cleaned parts inert (O10); the stride and θ (O11). §5.5:
  C09's Hammering 0.3186; the table's note names the rank order and T-DIF-12's goldens.
- §5.6: the ids-and-order row (T-DIF-07's shuffled ids); X01/X02 (0.0002 / 0.0010); X03's fin (L15); the translation and
  re-segmentation row (E-S2.10's cuts, the generated designs' 0.0016 and 0.1250, the ties; O11); CPU attacks with M3
  (L10, measured: 49.0 ms, P1 28.2 ≈ 73; O7); the 2 % rule's row with the sandwiched core (L4, O10).
- §14.6: T-DIF-04/05 with dust bit-identical; T-DIF-07 (a)–(c) as built; T-DIF-08 with B2's recipe; T-DIF-12, T-DIF-13
  and T-EDG-01 defined (D4). §14.7: P4's margin (D6), X08's aliases (D4), the specks, the fixture modules. §14.10:
  S-PAR-02's M3 part. §14.11: T-PERF-01's cases and method as built (B3).
- §16.10: `VERDICT_WORK_MAX` with M3's 49 ms. §16.18: Edge's and Factors' numeric guards (`BLADE_LENGTH_FLOOR`,
  `DEGENERATE_SPAN2`, `TAU_FLOOR`). §16.32: `TOL_EDGE_REL`, `PARITY_DESIGNS`, `PARITY_SEED`, `PERF_RUNS`;
  `ANALYSIS_LUNE_MAX_MS` with M3's totals.
- §17.1: O7 with M3's figures (D7); O10 (D1 with L4's reason and numbers, X03's fin under it, L15); O11 (D2 with B3's
  0.1250, B1's Y-shift ties). Both new rows follow M2's O9. The mark at §13's displayed items read "(§17)"; it now
  carries its number, "(§17.1 O1)", so every **[Decision to confirm]** mark carries one.
- §17.2: the checkpoint gaps with M3; what ids and order still reach (done, measured); the measure keeps its rank; what
  the 2 % rule admits (O10); the sandwiched core rewritten (L4: "0.27–0.41 over 12 crossings in 96 families", "because
  cleaning it opens the chord in Thinness" kept, "and, for a recessed core, SurfaceComplexity and Volume" added; 0.34–0.47
  and "M3 decides" gone); new rows for the edge's main chain (L15) and for invisible construction choices (O11); the cost
  of the verdict with M3; S8's digest row names S-PAR-02; the slivers row's X02.
- Evidence: E-S2.5 (X02 0.0010, X03's fin), E-S2.9 (its lead names the rank order; C09's Thinness on All 0.3898 / 0.390,
  Hammering 0.3186), E-S8.4 (A14 bit-identical, X03, X08's aliases), E-S8.5 (T-DIF 04, 12, 13; T-EDG), E-S8.6
  (S-PAR-02's M3 digest), and a new E-S2.13, M3 as built, which §4.9, §5.6 and §17.2 cite.

**Open issues**

- For the lead: S-PAR-02's Studio runs, 3 fresh Play sessions of the test place, each with `execute_luau` on the
  snippet's text in datamodel_type "Server", then "Client", the console clean (§14.10). Not tried in Studio: the call's
  length (about 26 s; if `execute_luau` stops it, set `GROUP` to "fixtures", then "generated"), JSONEncode of 10-digit
  integers, the replicated StringValue in the Client data model. On a FAIL, diff the `hashes` lines against
  `tests/golden/parity_designs.bv1.golden.txt`.
- For the lead, B1's finding, now written into §4.6, §5.6, §17.1 O11 and §17.2: C10 and C11, calibration fixtures, move
  Sharpening's G by 0.0063 / 0.0031 under E-S2.10's +0.3317 Y offset, past `TOL_G_INVARIANT`, at an exact raster tie.
  T-DIF-07(a) asserts F1, F3, F5, C02 and C06 only, as planned. A fix belongs to M2's `Shapes` (tie-proof chord
  predicates) or to a raster rule, and moves fixture values. (Fix round 1, fixer A: the raster rule, each cell read off
  its centre; T-DIF-07(a) now asserts every F and C fixture.)
- L4's "Thinness carries 0.31–0.36 of the jump" is two of the critic's three breakdowns (`c_proud2.txt`: 0.3122, 0.1038,
  0.3588); over all 12 crossings Thinness carries 0.10–0.36 of Hammering's jump, all of it on 7. The SPEC says so.
- L10's "49.0 ms … P1 28.5 (≈ 74)" were the plan's emulated figures; the SPEC carries B3's T-PERF-01 medians, 49.0
  (48.95) and P1 28.2 (≈ 73).
- O11 carries B3's 0.1250 and its tier flip (the specs' stream), D2's 0.0236 (the plan's stream) beside it.
- The snippet's `hashes` lines are FAIL lines but not assertions (§14.10: one line per assertion); its summary counts the
  assertions alone.

**Deviations from the plan and the SPEC**

- The digest's layout: per group `{bytes, designs, fnv1a32}` under `analyze`, not [8.5]'s `{designs, fixtures,
  generated, bytes}`, so that `GROUP` can compare one group alone; the snippet prints an `analyze` line per group and,
  with `GROUP` "all", a `digest` line for the whole text (its version included), not one line with both hashes.
- A second golden, `parity_designs.bv1.golden.txt`, every design's fnv1a32, so a Studio FAIL's `hashes` lines can be
  diffed without running Lune; the snippet never reads it (§14.2: Studio reads digests).
- Between designs the snippet calls its slice (a yield once 4 ms are used), not an unconditional `task.wait()`: about
  336 frames, 5.6 s, fewer a call in Studio.
- `Golden.readDigest` beside `Golden.digest`. `SPar02.spec` lives in tests/Physics, as [11] has it, and requires
  `../ItemRender/FakeRoblox`.
- A new evidence section, E-S2.13, and `docs/spec/prototypes/S2/m3/`, so that the SPEC's M3 figures cite evidence in the
  repo (§4.9, §5.6, §17.2), not these notes.

## Fix round 1, fixer A: Thinness and the raster

The lead's items 1–4 of `.build-notes/m3/m3_journal_r1.txt`, on V1's majors 1–3 (`m3_v1_adversary_r1.json`), V2's
major (`m3_v2_numbers_and_text_r1.json`) and B1's raster ties; the tree before the round is the Temp scratch
`m3-r1-base`. Measured with Lune 0.8.9 through `Analyze.run`; the scripts are in the Temp scratch `m3-fix1a/work`
(`dumpfix`, `gapwin`, `theta`, `prop500`, `recutx`, `shifts`, `genshifts`, `rewrite`, `ballturn`), with a step-by-step
`NOTES.md`; no more than 3 Lune processes ran at once, and none during the timings.

**What was built**

- `src/shared/Physics/Factors.luau`:
  - one gap window: the union chord merges every gap up to `HIDE_OFFSET` + `EPS_GEOM` (`MERGE_GAP`, what the verdict
    hides across, §4.4), not `CONTACT_TOL`; Factors no longer requires `Definitions/Limits`;
  - θ is `thinDirections(p, z)`: a polyhedron's three local axes; a Cylinder's axis, r1 = axis × z made unit (where the
    axis lies along z within `AXIS_TIE`, Cover's 1e-9, the world axis most across it, Y then X then Z, made square to
    it) and r2 = axis × r1; a Ball's world axes; a direction equal to ±z to the bit is left out. τ is the shortest of the
    union chords along z and θ, and a measured probe charges its higher parts and nW per chord;
  - the stride's walk is `canonicalWalk(p, S, spend)`: a polyhedron's local axes from the smallest half extent to the
    largest, the last innermost (equal ones: signed y, then x, components within `AXIS_TIE` tying, then z), each signed
    up the world (+Y, else +X, else +Z). A Block's counts come from its first sample's local coordinates and its cells by
    arithmetic; a Wedge's or a CornerWedge's samples are slotted by their local coordinates, the counts from the
    outermost (h/(h − max |l|)), charged a unit a sample in rows of `WALK_ROW` 64. Round parts keep their own order;
  - the pick: a part takes the stride's count of probes (every k-th of W's walk, the skip carried across parts as
    before), placed by a rank-1 lattice over its walk, from floor(n/2) in steps of `latticeStep(n)`, the integer nearest
    `GOLDEN`·n (0.618…) raised until coprime to n;
  - exports for tests: `thinDirections`, `canonicalWalk`, `latticeStep` (`thinAxis` is gone); the header rewritten.
- `src/shared/Physics/Edge.luau`: the chord thickness merges at `MERGE_GAP`; a cell is read at a sample `SAMPLE_X`
  0.0013 towards x = 0 and `SAMPLE_Y` 0.0017 up from its centre (the raster's rows and cells, and the ladder's rows);
  Edge no longer requires `Definitions/Limits`; the header's Raster and Translation paragraphs.
- Tests (each new case fails on `m3-r1-base`, checked by running the new spec files there: 6 in Invariance, 5 in Edge,
  5 in Factors):
  - `Factors.spec`: the union chord's window (a 0.011 gap merged, 0.0121 not); θ's directions, their writings (a
    Block's 24, a rod spun, a Ball turned: the same lines); the canonical walk (a Block's 24 writings walk one sequence
    of points; the thinnest axis outermost; the step coprime); [8.2] compares PartCount, Asymmetry and MaterialMix to
    the bit, Volume, SurfaceComplexity and Joints as before, Smelting's g and d, EdgeLength with the edge's, not
    Thinness or EdgeLength with the prototype's; C09's Thinness on All 0.3935;
  - `Edge.spec`: `OFF_PROTOTYPE` (12 prototype fixtures whose edge is not the prototype's, each asserted to differ, every
    other the prototype's to the bit); the cutIndex and EdgeLength columns as moved; P1 2 chains, 0.2286; a new item-5
    case (a laminate 0.011 / 0.0121 apart; a 0.09 blade's cells `RASTER_TOL` off its faces covered, outline at ±0.06);
    item 6: every shifted copy of F1–F5 and C01–C15 exact with its cutIndex, 111 copies, `MOVES` gone;
  - `Invariance.spec`: T-DIF-04's [7.6] bases as moved and a laminate across the gap window (F5, C02, C05, C08, F2);
    T-DIF-07 (a) on every F and C fixture, cutIndex too; (b) V1's fin in 9 pieces and case 152 within
    `TOL_G_INVARIANT`, tiers held; (d) a rib and a rod written two ways, #244's blade in its 24 writings, and, slow,
    `FUZZ_N_VALID` designs with every Block written (b, a, c);
  - `Difficulty.spec`'s d table, `Cost.luau`'s P3, P5 and P3-speck tiers, `DifficultyHelpers` (`writings`, `written`;
    the planted Factors without Limits; so the Factors plants of Factors.spec and Difficulty.spec).
- Goldens re-blessed after all four: `difficulty_{calibration, regression, cost}.bv1` (42,410, 84,808, 24,262 bytes),
  `parity.bv1.digest.txt` (133 bytes) and `parity_designs.bv1.golden.txt`; field by field (`golddiff`) only Thinness,
  g, d, tiers, the edge, EdgeLength and cutIndex moved, on the fixtures listed below; `balance_fingerprint`,
  `definition_ids` and `world_build_list` unchanged.
- SPEC: §4.6 row 1; §5.2 (the Thinness block, the walk's paragraph); §5.6 (the laminates row, the translation and
  re-segmentation row, the CPU row, the 2 % row's 0.3680); §17.1 O11 (and O10's 0.3680); §17.2 (invisible construction
  choices with the round parts' writing as M2's limit; the sandwiched core's 0.3680 and LAM1 0.3111); E-S2.13.
  `docs/spec/prototypes/S2/m3/out/limits.txt` re-run on this tree, its README line.

**Measured** (the machine 0–5 % busy unless said)

- Item 1, the gap window. F5's blade split through its thickness, outer faces kept (V1's `gapwin`): Hammering 0.1035
  Normal, Thinness on All 0.2588 and cutIndex 0.7242 at every gap up to 0.0120 (before: 0.3981 Hard, Thinness 0.9952,
  cutIndex 0.9063–0.9489 from 0.0101); from 0.0121, where the faces show, 0.6900 Master. `gapwin2` 0.0099 → 0.0101: no
  flip on F5, C02, C08, C05, F2 (all five before; |ΔG| now ≤ 0.0031); 0.0099 → 0.0119: |ΔG| ≤ 0.0167, and C02's
  Sharpening 0.1871 → 0.2016 Hard through SurfaceComplexity (the gap's volume out of V: V1's minor 8, O10's, fixer B's).
  Every fixture: only P3's and its specks' mean thickness (+2.6e-5 / +3.0e-5); X05 and X07 unchanged.
- Item 2, θ. Gate: every §5.5 tier holds, and the slowest valid design 52.874 ms with the chords charged (T-PERF-01
  alone, fixes 1–2), 53.091 and 53.218 with all four (two runs, the machine 0 → 12 % and 3 → 4 %): adopted, not V1's
  tied-axes θ. Fixture moves with θ alone, every §5.5 tier held: F4 0.1572 → 0.1590, C05 0.1363 → 0.1369, C06 0.2991 →
  0.2994, C08 0.0992 → 0.1013, C13 0.1133 → 0.1134, X03 0.1575 → 0.1592; a Wedge's taper is thin along its local
  axes, so P3 0.1804 Normal → 0.3851 Hard, P5 0.1902 Normal → 0.2167 Hard, P3 with a speck 0.1759 → 0.2594 Hard ([7.2]'s
  P3 and P5 rows). V1's tied-axes θ moved only C13 (0.1133 → 0.1134). `writing2` (28 sizes): 5 flips, the rib up to
  0.0728 and the rod 0.0604 apart → 0 and 0 (tied axes too). V1's fins (`recut`): 0.2229, 0.3298, 0.2962, 0.3823, each
  a tier → 0.0053, 0.0018, 0, 0.0003 with θ alone (tied axes: unchanged). Case 152: θ alone leaves it (0.2158 Hard →
  0.0907 Normal): its mechanism is the stride (`c152`: a main blade turned, 3 × 48 × 3 whole, 3 × 18 × 3 in pieces; a
  stride of 3 with an inner count of 3 took one outer Z layer whole, where the Z line crosses its corners (τ 0.0528),
  and the middle one cut). On 500 Prop-stream designs θ alone widened the re-cut spread: 0.1251, then 0.0824, 0.0637,
  0.0615, 0.0492, 11 past 0.024 (0.1250 and 5 before), τ varying more over a part.
- Item 3, the walk and the pick. The canonical walk with a plain stride: #244's 24 writings one value, case 152 0, the
  re-cut corpus 0.0824, 9 past 0.024, one boundary flip, but every fixture moved a little (F5 0.1037 → 0.1040, C04
  0.3368 → 0.3347, C09 0.3186 → 0.3222). The rank-1 lattice (`takencheck`: the same count as the stride on every set of
  every fixture): the re-cut corpus 0.0378 (#115, Asymmetry on the Blade), then 0.0339, 0.0294, 0.0215, 0.0196, 3 past
  0.024, one flip at a boundary (#297, seed 4102300182: Hammering 0.2011 → 0.1978); Thinness' x up to 0.0846 (0.3126
  before), Asymmetry's 0.0730 / 0.1261 unchanged; case 152 0.0006 (0.2088 → 0.2082); V1's fins 0.0104, 0.0111, 0.0185,
  0.0005, no flip; #244's 24 writings one value (0.1032, and 0.1983 at 0.0475 thick; 0.0734–0.1226 and 0.1893 Normal –
  0.2051 Hard before); every Block of 300 Gen designs (0x5EED0042) written (b, a, c): ΔG 0 (0.0298 on 21 before); and
  most fixtures back on their values before the round (F1–F5's Thinness to the bit). Taken, as the lead's item 3 asked:
  same count, no layer skipped, no §5.5 tier moved.
- Item 4, the raster. Variants of the sample's offset (`mkr4.py`), E-S2.10's offsets on every fixture (`shifts`): towards
  x = 0 by 0.0013 and up by 0.0017 moved the fewest fixtures (19) and leaves every F and C copy's edge and cutIndex
  exact, ΔG ≤ 0.0007 (other factors); away from x = 0, 29, A24's 0.02 needle losing its plain cells (cutIndex 1 → 0), C09's
  cutIndex 1 → 0.897; downward, 59. Adopted. Raster changes under the offsets, 410 copies of the 71 fixtures: 6 → 0;
  outline-only changes 12 → 11, all on P1, P2 with a speck and P5 (Douglas–Peucker and equal chains, G ≤ 0.0003). Gen
  (0x5EED0001, 300 designs, 1,793 copies): raster 0, outline 4, #131 |ΔG| 0.0037 as before; X mirror rasters all equal.
  Edges that move on the fixtures (vs the prototype: `OFF_PROTOTYPE`): F4 4 cells fewer; C04 EdgeLength 7.1067 →
  7.1487 (the cells `RASTER_TOL` off its blade's faces at ±0.045, which 0.045 + 0.005 < 0.05 left out, are in),
  Sharpening 0.4703 → 0.4769; C05 cutIndex 0.158369 → 0.161483; C06 6.4797 → 6.4795; C09 mean thickness 0.0433 →
  0.0440 (cutIndex 1); C15 5.6261 → 5.6260; X03, X07c; P1 1 → 2 chains (0.1897 → 0.2286), P2 15 → 14, P4 6 → 5, P3, P5
  (cutIndex 0.814442 → 0.820973); P1's specks 0 → 1 chain.
- Every fixture against the tree before the round (`cmpfix`), d: C04 0.3368 / 0.4703 → 0.3379 / 0.4769, C05 0.1363 →
  0.1369, C09 0.3186 → 0.3201, C13 0.1133 → 0.1137, X01 and X01raw 0.0756 → 0.0749, X05-0.050 0.1038 → 0.1037, P3
  0.1804 → 0.2752 (Hard), P5 0.1902 → 0.2167 (Hard), P3 with a speck 0.1759 → 0.2559 (Hard); every §5.5 tier held. The
  T-DIF-04 bases: C04 with a 0.075 blade 0.1863 / 0.3835 → 0.1888 / 0.3901, C09 0.05 longer 0.3299 / 0.2153 → 0.3313 /
  0.2155, C09 + the plate 0.3599 → 0.3595. T-DIF-06's sweeps unchanged. Checkpoints with `measureInvalid`: F2 97 → 100,
  F5 108 → 112, P5 222 → 236, P1 1,248 → 1,252.
- Round parts (`rewrite`, `ballturn`, `spinwhy`; M2's limit, recorded in §17.2): every Ball of 0x5EED0042's first 300
  turned 70°: 51 of the 94 designs with a Ball move, ΔG up to 0.0093 (#201), mass 6.6e-4, no flip (V1's 0.0065 was over
  those whose mass moves), through SurfaceComplexity, Joints, Volume and Asymmetry (x ≤ 0.0018); Cylinders spun 30°: ΔG
  ≤ 0.0048, SurfaceComplexity and Joints; Thinness 0 on both. As before the round.
- `limits.luau` again: the proud family unchanged; the sandwich's largest jump 0.3713 → 0.3680, LAM1 0.3235 → 0.3111;
  design 131 at +0.2: EdgeLength 6.413334 → 6.389542 (6.450091 → 6.426299 on centred cells), |ΔG| 0.0037.
- T-PERF-01, run alone (fixes 1–4; the first run 0 → 12 % busy, the second 3 → 4 %): the F, C and X fixtures 3.519–14.185
  ms (C09), longest stretch 0.082–0.236 (F2); P1–P5 and the specks 6.58–28.94 (P1), stretch ≤ 0.276; the worst valid
  designs 20.17–53.22 (valid 8, ≈ 138 Studio), stretch ≤ 0.332; past the cap 10.30–24.30. A first walk charged each
  pass as one lump and ran every polyhedron's samples: valid 8 54.356, F4's stretch 0.332 on a fixture; the Block path
  and per-row charges fixed both. Inside the whole suite: valid 8 53.887, the fixtures' stretches ≤ 0.236, P1 with a
  speck 0.367 / 0.399 and worst valid 9 / 10 0.465 / 0.553 (reported, collections).
- Suites (no other Lune process; the machine 4–6 % busy): `scripts/verify` in full green, 727 pass, its tests 273.43 s,
  the whole 278.2 s (718 and 257–262 s before the round), T-PERF-01 inside it valid 8 53.651, the fixtures' stretches
  ≤ 0.239, past 0.35 the specks 0.366 / 0.420 and worst valid 1, 9, 10, 11 0.359 / 0.594 / 0.593 / 0.351 (reported,
  collections); `--quick` 29.15 s, 696 pass, 31 skip (27.3–27.7 before): this round's fast cases add about 1.2 s
  (Invariance's 0.71 → 1.64 s) and the extra chords the rest. The fast T-DIF-07 (a) keeps 9 fixtures, the 20 are slow.

**Open issues**

- For fixer B, text with this round's figures: §4.9 and O7 (`Analyze.run`'s slowest valid design 53.1–53.2 ms Lune ≈
  138 Studio, was 49.0 ≈ 127; P1 28.8–28.9 ≈ 75; the fixtures 3.5–14.2, C09 ≈ 37 Studio; `TooComplex` 10.3–24.3), §16.10
  and §16.32 (`ANALYSIS_LUNE_MAX_MS` 60 keeps about 7 ms over valid 8 quiet, 11 before), §16.18's numeric guards
  (Factors' `AXIS_TIE`, `GOLDEN`, `WALK_ROW`; Edge's `SAMPLE_X`, `SAMPLE_Y`), §5.5's cells (C04 0.3379 / 0.4769, C05
  0.1369, C09 0.3201, C13 0.1137) and E-S2.9's rows, §14.6 (T-DIF-07 (a) every F and C fixture; (b) the fin and case 152;
  (d) writings; T-EDG-01's `OFF_PROTOTYPE`), §5's promise and §0.5 (a re-cut now moves G up to 0.0378, a tier only at a
  boundary; another writing nothing but round parts' grids), O10's laminate-gap SurfaceComplexity (C02 0.1871 → 0.2016
  at 0.0119). (Done by fixer B, with this tree's figures: the slowest valid design 53.3–53.4 ms, the re-cut 0.0379.)
- The 57 ms gate held by about 4 ms: T-PERF-01's 60 ms guard has less room under load than before (V1 saw 62–77 ms at
  27–38 % busy on the tree before the round). (Fixer B: 6.6 ms to spare quiet; §14.11 and §17.2 now say it needs a quiet
  machine.)
- `--quick` is 29.15 s, under §14.1's 30 s by less than a second (fixer B's margin item): the cheapest to move to `t.slow`
  are T-DIF-07 (a)'s 9 fixtures (about 0.5 s; the slow case covers all 20), T-DIF-07 (d)'s #244 writings (0.3 s) and
  the laminate case (0.2 s). (Done by fixer B: 25.9 s, below.)
- What still moves G under a flush re-cut is Asymmetry's grid (the pieces' own samples) and the pieces' own probe counts:
  a study for O11's redesign, with the round parts' grids (M2's).
- Thinness now reads a Wedge's taper (P3 and P5 play Hard Hammering): the definition the lead asked for (every local
  axis); a designer reading P3 or P5 may want it named (it is in §5.2).

**Deviations from the plan and the SPEC**

- The sample offsets and `AXIS_TIE`, `GOLDEN`, `WALK_ROW` are numeric guards local to Edge and Factors, not Balance rows.
- [8.2] and T-EDG-01 2 no longer hold Thinness and every edge to the prototype: the build's chords, walk, pick and raster
  samples are its own (the goldens hold them).
- The lattice pick also places round parts' probes (in their own order), so the count of every part is the stride's.

## Fix round 1, fixer B: the physics frame, the verifiers' tests and the text

The lead's items 5–8 of `.build-notes/m3/m3_journal_r1.txt`: V2's last minor (the physics frame), the test gaps V1 and
V2 found by mutation, §5's promise and the text minors, after fixer A. The tree before the round is the Temp scratch
`m3-r1-base`, fixer A's its `m3-fix1b/a-final`. Measured with Lune 0.8.9 through `Analyze.run`; the scripts are in the
Temp scratch `m3-fix1b/work` (`channels`, `bits`, `physdump` with `cmpphys.py` and `movestats.py`, `framerate`,
`charges`, `bounds`, `gapsc`, `latcmp` and `latshift` on `var/lattice` (`mklattice.py`), `numbers` and `es29apply.py`,
`golddiff`, `casetimes`, `checks`, and fixer A's `prop500`, `ballturn`, `rewrite`), the mutants in `m3-fix1b/mut`
(`mutants.py`, `drive.py`), with a step-by-step `NOTES.md`; no more than 3 Lune processes ran at once, and none beside the
timings.

**What was built**

- `src/shared/Physics/MassProps.luau`: `physicsFrame(parts, kept, gripSlot)` takes the kept Grip parts (the vote's rules
  unchanged; none kept, which only `measureInvalid` reaches, gives the origin and +Y, as no Grip part does);
  `validationFrame(parts, gripSlot)` every Grip part, for V4; `report`'s guard line and the grip's top count kept parts
  only; the header. `Analyze.luau`: V4 on `validationFrame` in phase 2, before the verdict; the physics frame in phase 4,
  after it; the header. `PhysicsHelpers.measure` passes the verdict's kept flags.
- Tests, the frame's (each kills a mutant that puts its rule back, `mut/mutants.py` M1–M4):
  - `MassProps.spec`: T-PHY-08 rewritten (the physics frame the kept Grip parts', V4's every Grip part's, A25's physics
    F1's); a case from V2's `hiddengrip` (a strap 0.05 × 0.20 × 0.05 hidden in A26's rings, turned 20° and 40°: A26base's
    physics, cutIndex 0.72417951973367989, steps and edge); the cleaned-parts case with a Guard block hidden in the guard
    and one high in F2's blade; the guardless grip's top with a Dust cube above it and a Grip block hidden in the blade;
    the vote and mirror cases on `validationFrame` (the mirror case renamed "the grip frame mirrors").
  - `Reference.spec`: P1's guard line is the build's own (its Enclosed Guard parts 6, 8, 11 and 12), its guardPos and
    bladeLength exempt from the prototype's and pinned with its balance; the header names the departure. No other
    prototype fixture differs: C10 and C11 clean two Dust specks of the grip, a mirrored pair at its height, which leave
    its frame to the bit.
- Tests, item 7 (each fails on its mutant and passes on the tree, `mut/drive.py`: 23 of 23 killed):
  - `Difficulty.spec` T-DIF-02: softOr(0.5, 0.5) 0.75, (0.3, 0.4) 0.58, (0.2, 0.3) 0.44, the grid against
    q(1 − (1 − m)(1 − g)); the planted term (Steel 0.25) against the formula and above max(m, g), C15's Hammering 0.4526
    (kills D6, softOr = max).
  - `Invariance.spec` T-DIF-07 (c): C09 4 shuffles, P5 and P1 2, and 6 grip stacks of 3–6 Blocks (V1's framesearch, TestRng
    0xF4A3E) 3 each (kills A7, the frame summed in blueprint order).
  - `Edge.spec`: each loop's units by caller (`debug.info(2, "n")`) on F5, F4 and P5 (kills E9 / V2's E10, E10b, E10c,
    E11, E27, E3, E14); the boundaries case: F2's blade `EDGE_MAX_THICK` thick (E13), a 1.12 × 3.92 blade of exactly
    `EDGE_MAX_CELLS` cells and a 3.94 one a rung coarser (E2), a lone 0.30 blade off the plane, its chain pinned (E15).
  - `Factors.spec`: each loop's units by caller on F5, F4 and P5, both work sets (F15, F15b, F15c, F16 the walk's rows,
    F22, F22b); a missing reference range raises, naming Asymmetry (F25).
- `--quick` past 27 s quiet (29.20 s): the fast corpora of generated designs became `t.slow`, names kept (M2's T-VAL-04
  60, §4.9 any design 30, T-PHY-09 duplicates, enclosed and dust 40 each, the measure's ladder fill 40, §5 random fill 40,
  T-PHY-04 on generated swords 40; M3's T-EDG-01 6 Gen with #89 and #131, T-DIF-01, T-DIF-05 and T-DIF-08 Gen), and
  T-DIF-07 (a)'s fast case keeps C10 and C11 at +0.3317 only (the slow case keeps every F and C fixture; T-EDG-01 6 holds
  their 111 copies' edges fast). Comments: Factors' header and Invariance's 0.0378 → 0.0379.
- Goldens re-blessed (`--bless --filter T-DIF-12` and `"the digest"`): `difficulty_regression.bv1` (A25),
  `difficulty_cost.bv1` (P1 with and without its specks), `parity.bv1.digest.txt`, `parity_designs.bv1.golden.txt`;
  `difficulty_calibration.bv1`, `balance_fingerprint`, `definition_ids`, `world_build_list` unchanged.
- SPEC: §0.5's row and §5's promise (three limits, each with its mark: O9, O10, O11); §4.1 (the departure), §4.2 V4,
  §4.4 (what cleaned parts count for), §4.5 (the table and the frame paragraph), §4.6 row 5 (cutIndex on the physics
  frame); §4.9, §5.6's CPU row, §16.10, §16.32, O7 and §17.2's cost row with this tree's T-PERF-01; §5.5's cells and
  note; §5.6 (laminates with the hidden gap's numbers, the grip row, the re-cut 0.0379); §14.1 (the margin), §14.6
  (T-PHY-08, T-DIF-02, T-DIF-07 (a)–(d), T-EDG-01), §14.11 (a quiet machine); §16.18's guards (`SAMPLE_X`, `SAMPLE_Y`,
  `AXIS_TIE`, `GOLDEN`, `WALK_ROW`); O10 (the hidden gap), O11 (0.0379, each way out with its cost); §17.2 (the checkpoint
  gaps and a quiet machine, the 2 % rule's hidden gap, the writings row's 0.0379 and lattice line, the grip axis).
  Evidence: E-S2.7 (a hidden grip part), E-S2.9 (14 rows fixer A's round moved, its lead), E-S2.13 (the intro, the
  goldens, the lattice re-tried, the physics frame, 0.0379, the hidden gap, cost, the digest).

**Measured** (the machine 0–9 % busy unless said)

- The channel (`channels`, before → after): V2's strap hidden in A26's rings turned 20° / 40°: axis (−0.342, 0.940) /
  (−0.643, 0.766), bladeLength 2.7699 → 2.6029 / 2.1219, cutIndex 0.724180 → 0.668445 / 0.507963, balance 0.0511 →
  0.0480 / 0.0392 → A26base's to the bit; A25: axis (−0.010383, 0.999946), cutIndex 0.724130 → F1's (but COM x's last
  bits, 1.8e-20 against −1.6e-20: the core's owned sliver); a Guard block 0.1 × 0.4 × 0.04 hidden in F2's blade at y 2,
  3, 3.7: guardPos 0.600 → 0.626, 0.674, 0.707, balance −0.0570 → −0.0832, −0.1308, −0.1641, cutIndex 0.425 → 0.4185,
  0.4065, 0.3982 → F2's to the bit; such a Grip block in a guardless F2 at y 1.6, 2.4, 3.2: the grip's top 0.50 →
  0.92, 1.69, 2.46, cutIndex 0.40 → 0.2875, 0.0875, 0 → the guardless F2's.
- Bit-compare against `m3-r1-base` (`physdump`, M2's physics fields to 17 digits, kept flags and owned volumes): the 136
  Parity fixtures, 15 move, each with a cleaned Grip or Guard part: Grip only A22c and A25; Guard only P1, P1-floating,
  P1-attached, worst valid 4, 5, 10, 11; both A14 and worst valid 2, 6, 7, 8, 9. A22c (`measureInvalid`, its only Grip
  part cleaned) takes the origin and +Y: guardPos 0.65 → 1.45, reach 3.152 → 3.951. The largest fixture moves: worst
  valid 7's balance 0.2174 → 0.0497 (bladeLength 2.239 → 2.071), worst valid 10's cutIndex 0.1794 → 0.1582. The 33,389
  plausible designs (8–9 min a tree, two at once): 1,785 move, 676 of the 782 with a cleaned Grip part and 1,109 of the
  2,329 with a cleaned Guard part (ballRivet 588, plateEdge 233, wrapRings 229, wedgeInGuard 214, rod 193, tiled 192,
  cylRib 75, grille 42, cylRivet 15, cage 4), none else; listed in `m3-fix1b/out/pl_moved.txt`. cutIndex moves on 705 of
  them, by at most 0.0043 (`plateEdge|F1|guard w0.5 k0.8 l1.0 poke0.0000` 0.71989 → 0.72418); guardPos by up to 0.1776
  (`wrapRings|C09|n5 extra0.04 gap0.0020`: the grip point 0.787 → 0.609); balance by up to 0.0143; the axis on none.
  Against fixer A's tree every design's steps, edge, kept flags and owned volumes hash the same; fixer A's tree against
  `m3-r1-base`: no physics move on any. The 200 generated designs of `PARITY_SEED` clean no Grip or Guard part.
- Goldens, field by field (`golddiff`): A25's balance 0.1272063 → 0.1272132, bladeLength 2.7697538 → 2.7699031, cutIndex
  0.7241297 → 0.7241795 (F1's); P1's balance 0.1682265 → 0.2054938, bladeLength 2.4645307 → 2.5017979, with a speck
  0.1113208 / 0.1114462 → 0.1485880 / 0.1487135 and 2.3859850 → 2.4232522; sizes 42,410, 84,808 and 24,262 bytes as
  before. The digest: the fixtures' group 424,727 → 424,595 bytes, fnv1a32 3894788252 → 2087286482; the generated group
  unchanged (709,434, 2874446443); 15 designs' hashes move (the 15 above), 188 of 336 over the whole round.
- E-S2.9 regenerated from `Analyze.run` (V2's `numbers`): the 14 rows fixer A's round moved (C04, C05, C09, C13; F3, C06,
  C08 on the Blade's Thinness; no physics row by this change).
- The hidden gap (V1's `gapsc`, this tree): C02's blade split 0.005, 0.0099, 0.0119, 0.0121 apart: Sharpening 0.1318 →
  0.1535, 0.1871, 0.2016 Hard, 0.3318 (the faces show), Thinness and cutIndex the same up to 0.0119; that blade 0.15
  longer 0.1889 → 0.2173 Hard, 0.2516, 0.2664; F5 0.0989 → 0.1109, 0.1430, 0.1567 (V1's 0.1430 was at 0.0099).
- Douglas–Peucker on the integer lattice, ported onto this tree's Edge (`var/lattice`): no F, C, X or A fixture's d,
  tier or EdgeLength moves at 4 decimals (C15 0.4291 either way); P1 2 → 4 chains, its specks 1 → 2, P2 14 → 15, P4 5 →
  6, worst valid 3 15 → 16 and 7 2 → 4, worst valid 9's Sharpening 0.0549 → 0.0543; on 1,793 shifted copies of 0x5EED0001's
  first 300 designs no edge changes (#131 at (0, 0.2, 0.05) 6.413334 either way), worst |ΔG| 0.0005, where this tree
  changes some length's bits on 291 and #131 by 0.0037 (`latshift`).
- Fixer A's corpora on this tree: the re-cut 500 |ΔG| ≤ 0.0379 (#115), then 0.0339, 0.0294, 0.0215, 0.0195, 3 past
  0.024, one flip (#297, 0.2011 → 0.1978), translated ≤ 0.0016; fixer A's tree gives the same, so its 0.0378 and 0.0196
  were measured before its raster fix. Balls turned: 51 of 94 move, ≤ 0.0093, no flip; Cylinders spun 30° ≤ 0.0048;
  Blocks swapped and Cylinders spun 90°: 0. `limits.luau`: `out/limits.txt` the same. Checkpoints with
  `measureInvalid`: F2 100, F5 112, P5 236, P1 1,252, as on fixer A's tree.
- `framerate`: a blueprint-order frame moves on 0–33 of 40 shuffles of each of 12 grip stacks (about half overall), C09
  on 9 of 40; the rank order's on none.
- T-PERF-01 alone, the final tree (two runs, the machine 4 → 3 % and 9 → 5 %): the F, C and X fixtures 3.526–14.158 ms
  (C09), stretch 0.079–0.239 (F2); P1–P5 and the specks 6.597–28.987 (P1 28.98–28.99), stretch 0.085–0.302; the worst
  valid designs 20.345–53.442 (valid 8, ≈ 139 Studio), 0.123–0.256; past the cap 10.092–24.353, 0.077–0.110.
- Suites: `--quick` 29.20 s before the moves (701 pass, 31 skip; the machine 0 → 2 %), 26.44 s after the corpora (689,
  43), 25.87 s after T-DIF-07 (a) (689, 43; 1 → 1 %); `scripts/verify -- --quick` green, 30.7 s. The whole suite
  (`lune run tests/run`, 1 % busy at its start): 732 pass, 0 fail, 274.80 s; in it T-PERF-01's valid 8 53.54, the
  fixtures' stretches up to 0.241, past 0.35 P1 with an attached speck 0.360 and worst valid 9, 10, 11 0.603, 0.474,
  0.403 (reported, collections). `scripts/verify` in full, last: VERIFY GREEN (277.7 s), 732 pass, 0 fail, its tests
  272.91 s (727 and 273.43 s after fixer A), the machine 1 % busy at its start and 13 % at its end, no other Lune
  process; in it T-PERF-01's valid 8 53.30, the fixtures' stretches up to 0.235, past 0.35 P1 with an attached speck
  0.355 and worst valid 9, 10, 11 0.554, 0.485, 0.356.

**Open issues**

- For the lead: the guard line and the grip's top went with the frame (deviations below), so designs with a cleaned
  Guard part move too, not only those with a cleaned Grip part (1,109 plausible ones, P1 and its specks, worst valid
  4, 5, 10, 11).
- For the lead: on this tree L3's option (a), Douglas–Peucker on the integer lattice, would meet L3's own criterion (no
  §5.5 or E-S2.9 value moves, C15's tie gone with the centred raster) and make every Y shift exact; O11 now states it
  as a way out with its cost, its default still "accept". (Fixer C: adopted.)
- V4 still takes every Grip part, before the verdict, as V1–V3 count every part: a hidden Grip part can still make a
  design invalid (`BladeNotAboveGrip`) or valid, an error the player sees. The total length counts every part (an
  enclosed part lies within `HIDE_OFFSET` of the kept ones; no stat reads it).
- S-PAR-02's digest moved again (424,595 bytes, 2087286482): the Studio runs must use this `parity.bv1.digest.txt`.
- T-PERF-01 keeps 6.6 ms under `ANALYSIS_LUNE_MAX_MS` quiet: a full `scripts/verify` needs a quiet machine.
- My scripts are in the session's Temp scratch, `m3-fix1b`, which loses week-old files: the numbers are here and in
  E-S2.13; the lead may want `work/`, `mut/` and `out/pl_moved.txt` archived to `.build-notes`.

**Deviations from the plan and the SPEC**

- The lead's item 5 named the frame's point and vote; the guard line (kept Guard parts) and the grip's top (kept Grip
  parts) follow the same rule, since a cleaned Guard or Grip part steered bladeLength, cutIndex and the balance through
  them (measured above); "a cleaned part steers nothing" is the lead's own aim.
- V4 keeps every Grip part (`validationFrame`): it is asked before the verdict, and moving it after would change
  validation for `TooComplex` designs.
- M2's tests change: T-PHY-08 and the cleaned-parts and no-guard cases now pin the kept parts' frame; M2's fast corpora of
  generated designs are `t.slow` (names kept), as the lead's item 8 allows past 27 s.
- The charge tests read the charging function's name with `debug.info(2, "n")`, V1's way: renaming a loop's local
  function fails them, as a lost charge does.

## Fix round 1, fixer C: Douglas–Peucker on the integer lattice

The lead's decision after fixers A and B (`.build-notes/m3/m3_journal_r1.txt`): fixer B found that L3's option (a) now
meets L3's own criterion, so Edge adopts it. The tree before is the Temp scratch `m3-r1b-base` (fixers A and B).
Measured with Lune 0.8.9 through `Analyze.run`; the scripts are in the Temp scratch `m3-fix1c/work` (`dump` with
`cmp.py`, `dptrace` on the instrumented copy `var/trace`, the hybrid `var/hyb` (the lattice's picks, blueprint XY's
points and lengths), `protocmp`, `yshift`, `propy`, `thinwhy`, `thinface`, `item6`, `critic`, `mirror`, `unit`,
`golddiff`, fixer A's `shifts`, fixer B's `latshift` and `checks`), with a step-by-step `NOTES.md`; at most 4 Lune
processes ran at once.

**What was built**

- `src/shared/Physics/Edge.luau`:
  - `simplify` on lattice points: a span's farthest point by its squared distance times the span's squared length, so
    every comparison is between integers (cross² inside the segment, |ap|²·|ab|² or |bp|²·|ab|² past either end, against
    tol²·|ab|²; tol² alone where the ends meet), the first maximum by index; `DEGENERATE_SPAN2` is gone;
  - `emitRun` builds a run on the doubled vertex lattice (a vertex (2i, 2j), an edge's midpoint the sum of its ends) at
    2·`EDGE_SIMPLIFY`, doubled as before; a segment's length is its lattice length × h/2, and a kept point (X, Y) is
    ((i0 + X/2)·h, Y0 + (j0 + Y/2)·h);
  - the header: the intro, simplify's row, Geometry, Translation, and the magnitudes (a design within Canonical's bounds
    spans under 42.4 studs: a squared lattice distance stays under 2^25 at a rung of ≤ `EDGE_MAX_CELLS` cells (at most
    2,124 × 5 at 0.02) and under 2^18 at the last rung, every product compared under 2^52).
- Tests (each new or changed case fails on the tree before: the new Edge.spec and Invariance.spec on `m3-r1b-base`, the
  Temp scratch `m3-fix1c/var/r1bnew`, fail 6 T-EDG-01 cases and 3 T-DIF-07 cases, the fast ones among them):
  - `Edge.spec`: the header; `OFF_PROTOTYPE`'s comment and P2's and P4's rows (15 and 6 chains as the prototype, their
    rasters the build's); P1's 4 chains, 0.1897, its other three exactly `EDGE_MIN_CHAIN` cells; the lone 0.30 blade's
    pinned chain (a point's y 3.9700000000000002 → 3.9699999999999998); Douglas–Peucker on lattice points (a bump at tol
    dropped, past either end measured from it, a tie to the first, a long diagonal exactly tol off, which blueprint XY
    measured 0.020000000000003126 and kept, and a step farther kept); item 6: a Y or Z shift keeps the raster's cells
    and the outline (chains, points' x and lengths to the bit, the points' y moved by Δy) on F1–F5 and C01–C15's 111
    copies, on the critic's designs (TestRng 0x5EED0007 #89 by its own draw, 0x5EED0001 #131 at (0, 0.2, 0.05), each
    axis alone; fast) and on `FUZZ_N_VALID` Gen designs (slow; the 20-design slow case folded in: Prop's first 20 cases
    are its first 20).
  - `Invariance.spec`: `yKept` (a Y shift that keeps the raster's cells keeps every step's EdgeLength raw and g to the
    bit, unless Thinness moved, then G within `TOL_G_INVARIANT`) and `THIN_TIES` (F1 and F5 at +0.125, each asserted to
    move); T-DIF-07 (a) fast: C10, C11 and F1 at +0.3317 exact, F1 at +0.125 moving with Thinness; slow: every F and C
    fixture's Y offsets; the Gen corpus: each design's Y draw alone, its raster kept.
- Goldens re-blessed (`--bless --filter "T-DIF-12"`, then `"the digest"`): `difficulty_{calibration, regression,
  cost}.bv1` (42,414, 84,891 and 24,409 bytes), `parity.bv1.digest.txt` (132 bytes), `parity_designs.bv1.golden.txt`;
  `balance_fingerprint`, `definition_ids` and `world_build_list` unchanged.
- SPEC: §0.5's row; §4.6 row 4; §5's promise (O11's bullet); §5.2 (a probe on another part's face); §5.6's translation
  row; §14.6 (T-DIF-07 (a), T-EDG-01); §16.18 (`DEGENERATE_SPAN2` gone); §16.32's `TOL_EDGE_REL`; §17.1 O11 (the Y-shift
  tie out of its exceptions, the Thinness probe on a face in, the cost paragraph with what the lattice moved); §17.2's
  S2 row. Evidence: E-S2.13 (the intro, the table's goldens, the edge, Douglas–Peucker, ties under a shift, invariance
  with the X mirror's figure, the digest).

**Measured** (the machine 44–66 % busy with programs not mine for most of the round, which only timings feel; said where
a timing was taken)

- The bit-compare against `m3-r1b-base` (`dump`: M2's physics to 17 digits, kept flags, owned volumes, the edge's
  chains, points and lengths, the raster, every step's d, tier, g and factors; `cmp.py`): M2's physics, cutIndex and the
  raster never move.
  - The 136 Parity fixtures: 33 identical, 91 in the last bits only (lengths and points ≤ 1.8e-15, points equal at 1e-9,
    d and tiers equal; every F, C, X and A fixture is among these two), 12 for real, no tier: P1 2 → 4 chains
    (EdgeLength 0.228637 → 0.189737), P1 with either speck 1 → 2 (0.228637 → 0.18), P2 14 → 15 (1.232237 → 1.232481), P2
    with either speck two chains re-picked (0.1345 → 0.1308, 0.0728 → 0.0806), P4 5 → 6, P5 two pairs of equal chains in
    the other order, worst valid 3 15 → 16, 7 2 → 4, 9 EdgeLength 5.084028 → 5.080588 and Sharpening 0.0549 → 0.0543
    (the only d that moves), 10 its second chain 3 → 2 points (3.4838 → 3.48). Fixer B's figures to the digit; P2's
    specks, P5's order and worst valid 10 are new.
  - Parity's 200 generated designs: 56 identical, 141 last bits, 3 real (Gen 5 EdgeLength 7.027087 → 7.027017, Gen 92
    its points, Gen 176 3.941608 → 3.941115), no d (g is quantized to 4 decimals).
  - The 33,389 plausible designs (13 min a tree, two at once): 17,504 identical, 15,857 last bits, 28 real; 12 d values
    move, by at most 0.0012 (`plateEdge|C02|blade … poke0.0300` ×6, Sharpening 0.1825 → 0.1837, EdgeLength 5.6593 →
    5.6670; `plateEdge|C09|blade … poke0.0750` ×6, −0.0001), no tier; the others' minor chains (`wrapRings|C09` ×10,
    `cage` ×6).
  - Every real move is one of four exact ties that blueprint XY decided by rounding (`dptrace` replays both rules on
    every run Edge simplifies; `var/hyb` separates the picks from the lengths): a point exactly 1 cell from its segment,
    measured a hair farther (P1's 0.060000000000000053 against 0.06) and kept, now dropped (12 of the fixtures' 20 runs
    that pick other points, out of 261; 22 of the plausible designs' 28); two points tied for the farthest, where the
    float rule took a later one (8; 6); a chain exactly `EDGE_MIN_CHAIN` cells long, whose length in blueprint XY fell
    short (0.17999999999999972 against 0.18), now kept (6·(h/2) is 3h to the bit: P1's three, its specks', worst valid
    7's two, `wrapRings|C09|n5 extra0.01` and `cage r0.18`'s); two chains of one length, now equal to the bit and
    ordered by their first point (P2, its specks, P5).
- `OFF_PROTOTYPE` (`protocmp`): the same 12 differ from the prototype, P2 with 15 chains and P4 with 6 again; every
  other prototype fixture's edge is the prototype's within 1e-12.
- Goldens, field by field (`golddiff`, classified): of the 70 entries 55 move in the last bits only, all in the chains'
  lengths (115 values), `physics.edgeLength` (53) and EdgeLength's raw (53 a step) and x (49 a step); 7 for real (P1,
  P2, P4 and P1's and P2's specks: chains, lengths, EdgeLength's raw); no g, m, d, tier, raw tier or other physics
  field. The digest: the fixtures' group 424,595 → 425,752 bytes, fnv1a32 2087286482 → 3014135086; the generated group
  709,434 → 709,377 bytes, 2874446443 → 410604535; 247 of the 336 designs' hashes move (103 fixtures, 144 generated),
  293 over the whole round.
- Y shifts (`yshift`, `propy`, `item6`, `critic`, `shifts`, `latshift`):
  - F1–F5 and C01–C15 × E-S2.10's offsets (111 copies): the outline exact on all (16 changed their lengths' last bits
    before); the 71 fixtures × the offsets (410): no edge moves (11 before: P1, P2 with a speck, P5); TestRng
    0x5EED0001's first 300 × the offsets (1,793): no edge moves (291 before), worst |ΔG| 0.0005, no flip (fixer B's to
    the digit); the critic's #89 (6.696057 → 6.691727 before) and #131 at +0.2 (6.413334 over 10 points → 6.389542 over
    8 before) exact; the Prop stream's 500 designs by their own draw, Y alone and Z alone: no raster, no outline and no
    EdgeLength raw moves.
  - What G still does under a Y shift is Thinness: on F1 and F5 at +0.125 (`thinwhy`: F1's tip, a Block turned 45° about
    Z and centred on its blade's top face, y 3.98, has a row of probes on that face; unmoved, the union chord along z
    meets the blade there, τ 0.06; at +0.125 y rounds to 3.98 + 4e-16 and it does not, τ 0.055: Thinness 0.0017, ΔG
    0.0007); on 43 of the 410 fixture copies, the edge kept (F1, F5 and the X and A fixtures on them 0.0006–0.0017, X02
    and X02base at +0.125 0.0031, past `TOL_G_INVARIANT` (Hammering 0.0510 → 0.0541, Thinness 0.1274 → 0.1353), P5
    0.0003), and the 44th, C09 0.037 down in Z, through SurfaceComplexity (0.0007); on 12 of the Prop stream's 500 Y
    draws, up to 0.0016 (#344: B3's "translated ≤ 0.0016" was this all along), every one with Thinness moved; on 4 of
    0x5EED0001's 1,193 Y-only copies, ≤ 0.0005. `thinface`: on all 12 Prop designs every probe whose τ moves lies within
    3e-16 of another part's face. No flip anywhere.
- The X mirror (`mirror`, builder 3's method; reported, as the lead said): 150 Prop designs EdgeLength ≤ 0.3710 % (#132:
  its mirror's outline runs the other way, so Douglas–Peucker keeps 8 points of 10, 6.413334 → 6.389542), ΔD ≤ 0.0621,
  no flip, on this tree and on `m3-r1b-base` alike; before fix round 1 (`m3-r1-base`) ΔD ≤ 0.0081 (#48), as B3 measured.
  #24 moves Hammering 0.1585 → 0.0964 through Thinness on All 0.394 → 0.239: fixer A's θ, walk and pick, not the
  lattice. E-S2.13 carried B3's 0.0081.
- Checkpoints with `measureInvalid` (`checks`): F2 100, F5 112, P5 236, P1 1,252, as before.
- Edge alone (`edgecost`: the inputs built outside the timing, the two trees alternating round by round, medians of
  41; under load, about 50 % busy): blueprint XY / the lattice F5 0.832 / 0.840 ms, P1 5.381 / 5.597, P2 5.050 / 5.001,
  P5 1.405 / 1.401, worst valid 3, 8 and 9 3.370 / 3.324, 5.861 / 5.653 and 8.022 / 7.918: the same cost within ±4 %,
  either way.
- Suites, every one under load (the game and other programs 40–73 % busy from 09:30 to 13:41; four waits of 55
  minutes for a quiet machine timed out): `--quick` 690 pass, 0 fail, 42 skip, 44.70 s; the whole suite 731 pass, 1
  fail, 487.01 s, the failure T-PERF-01's F2 stretch 0.513 ms (≤ 0.24 quiet); `scripts/verify` (12:38–12:45, about 51 %
  busy): tools, sourcemaps, T-META-07 and luau-lsp's two passes clean, then 731 pass, 1 fail (T-PERF-01, F2's stretch
  0.468 ms), TESTS FAILED (449.9 s), exit 1. 732 cases as after fixer B (a slow case folded in, a fast one added).

**Open issues**

- For the lead: T-DIF-07 (a) cannot assert |ΔG| = 0 for every Y shift that keeps the raster. Thinness reads a probe that
  lies exactly on another part's face by rounding, and a shift rounds it again: F1's and F5's tip at +0.125 (0.0007),
  X02 at +0.125 (0.0031, past `TOL_G_INVARIANT`, outside T-DIF-07 (a)'s F and C fixtures), 12 of 500 Prop designs (≤
  0.0016). The test asserts EdgeLength and G to the bit but where Thinness moved, and lists the two F fixtures. A way
  out would read a probe's chords off the faces, as fixer A's raster reads its cells; not tried, its cost unmeasured.
  §5's promise, §5.2, §5.6, O11 and §17.2 now name this channel **[Decision to confirm]** (§17.1 O11).
- For the lead: a whole design's X mirror image moves D up to 0.0621 on 150 Prop designs since fixer A's Thinness
  (0.0081 before the round); reported in E-S2.13 only, as T-DIF-08 has it. Its cause is not traced; the walk's sign
  rule is not it (signing an axis by z before x, `var/mirrorfix`, leaves #24 at 0.0621). Traced in review round 2 (V1,
  V2) and re-measured on fix round 2's tree (fixer E, below): it is the walk's world sign on #24's Wedge tip, whose
  smallest local axis lies along X, signed +X in the design and its image alike, so the lattice takes other samples
  (2 of the image's 4 probes mirror the design's; τ 0.0235, 0.0549, 0.0392, 0.0392 against 0.0392, 0.0392, 0.0549,
  0.0549; every sample read, both 0.3697). No world sign follows an X mirror on an axis along X.
- S-PAR-02's digest moved (fixtures 425,752 bytes, 3014135086; generated 709,377, 410604535): the Studio runs must use
  this `parity.bv1.digest.txt`.
- For the lead: `scripts/verify` is not yet green on a quiet machine. The machine stayed 40–73 % busy (a game and other
  programs, not mine) for the whole round; under that load only T-PERF-01's timed stretch fails (F2 0.468–0.513 ms
  against 0.35), every other case passes. Re-run it quiet before review round 2 counts on it.
- My scripts are in the session's Temp scratch, `m3-fix1c`, which loses week-old files: the numbers are here and in
  E-S2.13.

**Deviations from the plan and the SPEC**

- T-DIF-07 (a) asserts |ΔG| = 0 under a Y shift but where Thinness moves (the fixtures' `THIN_TIES`, any Thinness move
  on Gen designs), not wherever the raster is unchanged as the lead wrote: it does not hold there (above).
- O11 names the Thinness probe on a face among what a Y shift still moves, where the lead had the Y-shift tie leave its
  exceptions: the Douglas–Peucker tie left them; this channel was always there, unnamed (B3's 0.0016).
- Beyond the listed sections: §0.5's row, §5's promise, §5.2, §16.18 (`DEGENERATE_SPAN2`) and §16.32 (`TOL_EDGE_REL` for
  X mirrors only), which named the old rule.
- A kept point is ((i0 + X/2)·h, Y0 + (j0 + Y/2)·h), one rounding, not the mean of its edge's two ends as before, so a
  kept midpoint's last bits move too (the 91 fixtures above).
- T-EDG-01 6's 20-design slow Gen case is gone, folded into the `FUZZ_N_VALID` one (the same first 20 cases); the
  critic's two designs run fast.

## Fix round 2, fixer D: thinness and the edge

The lead's items D1–D5 of `.build-notes/m3/m3_journal_r2.txt`, on V1's majors 1 and 2 and its FA2/FA8 minors
(`m3_v1_adversary_r2.json`) and V2's major and its Wedge re-cuts (`m3_v2_numbers_and_text_r2.json`); the tree before
the round is the Temp scratch `m3-r2-base` (after fixer C). Measured with Lune 0.8.9 through `Analyze.run` (the
0.8.9 binary itself, one process a run, at most 4 at once); the scripts are in the Temp scratch `m3-fix2d/work`
(`turned`, `neighbours`, `linesweep`, `labcorpus` on the rules' lab `var/lab`; `obliq` (V1's `obliq` and `wedgediag`),
`ydraw`, `fixshift`, `fcshift`, `invariance` (V2's), `treecmp`, `attrib`, `tiecheck`, `tietrace`, `ytrace`,
`recutaim`, `recutdown`, `recutwedge` (V2's), `probecount`, `timing`, `phasetime`, `counts`, `charges`), the trees in
`m3-fix2d/var` (`final2`, this round's code; `e3d1` and `dzd2`, its D1 and D2 halves; `dz`; `floor8`; the nudge's `e3`
and octants `s1`–`s8`; the mutants `m_*`), with a step-by-step `NOTES.md`. The machine was 6–40 % busy with programs not
mine all round; every timing below says its load.

**What was built**

- `src/shared/Physics/Edge.luau`:
  - `hiddenGap(p, e, q, f)`, exported: does the verdict hide the gap a line crosses from p (left at e) to q (met at f)?
    The measure's own hide test (Sampling.exposure) at the two points: each face's probe, `HIDE_OFFSET` along its
    outward normal (`normalAt`: the largest term of `Shapes.sdLocal` there, a Block's faces in x, y, z order, then a
    Wedge's or a CornerWedge's slopes, a Cylinder's cap before its side, a Ball's radius), within `EPS_GEOM` of the other
    part. Each face is looked at only where the other part lies within `REACH` = `HIDE_OFFSET` + 2·`EPS_GEOM` of its
    point, its box and then its sd (1-Lipschitz, so the pre-test is exact); it returns its shape queries (an sd, a
    normal or a probe each);
  - `mergeSorted` carries each interval's part through its insertion sort and, past `MERGE_GAP` along the cell's Z line,
    joins the next interval where `hiddenGap` hides the gap from the part whose chord ends the run; a covered cell with
    one plain chord takes its length without the call (bit-identical: 0 + x = x); the cell charges the queries;
  - the header: the function list, the Raster paragraph, a Hidden gaps paragraph, the Work paragraph.
- `src/shared/Physics/Factors.luau` (requires Edge):
  - `unionChord(list, owner, o, u)` returns the length and `hiddenGap`'s queries: its intervals in one table of triples
    (ends and the part's place in the list); the plain closure from [0, 0] as before; when it stops with chords left,
    the nearest one past each end (smallest start beyond hi, largest end below lo) joins where `hiddenGap` hides the gap
    from the part that ends the chord there (of parts that end it at one t, the first in the list), and the closure runs
    again; a test's list with no chord through the probe skips that step;
  - every part but the probe's own is read grown by `TIE` = 1e-10 (a numeric guard): `lineMeetsBox`'s box and
    `Shapes.chord`'s dilate, so a line along another part's face meets it, closed, whatever the rounding (M2's Shapes
    untouched);
  - `thinness` passes the owner and charges the queries with each probe's units;
  - the header: the Thinness paragraph, a Face ties paragraph (why, the numbers against Canonical's bounds), the re-cut
    sentence (a corpus's figures, not a bound, and why), the Work paragraph.
- Tests (each fails on its mutant or on the tree before; `NOTES.md`, step 6):
  - `Edge.spec`: T-EDG-01 5 hidden gaps: two plates turned 30° about Y, 0.0105 apart across and 0.0121 along Z, hidden
    with 6 queries; 0.0121 across shown; a square rod's edge 0.002 over a plate, the point on its flank 0.0119 up: not
    hidden, though V1's two-sided distance test holds there; a part out of reach costs no query. The header.
  - `Factors.spec`: the union chord with its owner (1e-10 in the expectation), a laminate turned 30° merged at 0.0105
    across and not at 0.0121; a probe on another part's face (its line along the face, by Z and by X) meets the part at
    six Y offsets; the canonical walk of a Block turned about Z alone, one local axis along ±Z, in its 24 writings (V1's
    FA8); the charges pinned anew (F5 on All 4,801 → 4,911 units, P5 14,656 → 14,794, on the Blade 8,217 → 8,273: the
    hidden-gap queries). Factors' plantings in `Factors.spec`, `Difficulty.spec` and `DifficultyHelpers` get `./Edge`.
  - `Invariance.spec`: T-DIF-04 the window's edge (V1's FA2: F5 laminated 0.01200005 apart = 0.0119); T-DIF-04 slanted
    laminates (V1's: F5's blade turned 30° about its length and split 0.0100 / 0.0105 / 0.0119 apart, or cut along its
    X-Z diagonal 0.0112 / 0.0113 / 0.0115: Thinness within 0.005, the mean thickness within 0.001, Hammering's tier the
    same; at 0.0121 the plates read thin); `yKept` asserts EdgeLength to the bit, Thinness within 1e-12 and G within a
    tolerance (0 on fixtures, `TOL_G_INVARIANT` on the Gen corpus's Y draws); `THIN_TIES` is gone and F1 at +0.125 holds
    G to the bit; the old laminate case's Thinness within 1e-9 (a chord that ends on another part's slanted face moves by
    about `TIE`); the header.
  - `Difficulty.spec`: X04-5-0.006, X05+0.002, X05+0.006 and X05-0.020's Hammering 0.1044 → 0.1037 in `D_RANK`, noted.
- Goldens re-blessed (`--bless --filter "T-DIF-12"`, then `"the digest"`): `difficulty_{calibration, cost,
  regression}.bv1` (42,408, 24,405 and 84,793 bytes), `parity.bv1.digest.txt` (130 bytes),
  `parity_designs.bv1.golden.txt`; `balance_fingerprint`, `definition_ids` and `world_build_list` unchanged.
- SPEC: §0.5's row, §4.6 row 1, §5's promise (O11's bullet), §5.2 (τ, the paragraph), §5.5's introduction, §5.6
  (laminates, translation and re-segmentation, CPU), §14.6 (T-DIF-04, T-DIF-07, T-EDG-01), §16.18's guards (`TIE`),
  §17.1 O10 and O11, §17.2's S2 rows (what the 2 % rule admits, invisible construction choices). Evidence: E-S2.13 (the
  introduction, ties under a shift, invariance, a fix round 2 bullet, the digest).

**Measured**

- *D1, against the verdict's real hide test.* Four rules side by side in `var/lab`: plain (the tree before), V1's
  two-sided distance test (the end part within `MERGE_GAP` of the next one's crossing point and back), the measure's hide
  test at the two crossing points (adopted), and each in a sorted sweep and in V1's closure.
  - Laminates turned 0°, 15°, 30°, 45°, 60° and 75° about the blade's length (F5's hilt) and across it (a long grip, a
    deep guard, a blade min(2.2, 0.48/sin a) long), gaps 0.0100, 0.0119, 0.01200005, 0.0120002, 0.0121, 0.0125:
    SurfaceComplexity jumps between 0.01200005 and 0.0120002 at every angle (2.22 → 2.88 about Y); plain Thinness jumps
    from 15° at 0.0119 (Z gap 0.0123); V1's and the adopted rule give the same values everywhere, continuous to
    0.01200005 and jumping with SurfaceComplexity. A laminate's level differs from its whole blade's from 30° (0.2870
    against 0.2531 about Y): its pieces' probes, O11's re-cut, not the gap.
  - Neighbours without facing faces, 9,600 lines each (40 × 40 points a part, along Z and both local axes): a facing
    laminate and a half stair, the same joins for both rules; a corner-to-corner stair, no join; a square rod's edge over
    a plate, V1's rule 32–41 joins where a face shows at the crossing (15°–30°), the adopted rule none; a roof of two
    plates ±20° edge to edge, V1's 9–44 at every gap including 0.013 (past the window), the adopted none. On F5's hilt,
    the corner at 30° and 0.008: V1's merged 130 raster cells (mean thickness 0.04019 → 0.04185), the adopted none.
  - Corpora, against plain: the 136 Parity fixtures, V1's rule moved 8 (205 joins, 132 where a face shows; worst valid
    4's Hammering 0.2215 Hard → 0.1994 Normal, worst valid 8 0.6153 → 0.6143, P3 and P3-attached's mean thickness
    +5e-5), the adopted 4 (no d); Parity's 200 generated, neither (V1's 49 joins, all where a face shows); the 33,389
    plausible designs, V1's 65 designs, 4 a tier (ribbed bars Hard → Normal; 5,207 joins, 4,164 where a face shows),
    the adopted 14 (ribbed bars r 0.16 and 0.25, Hammering down by up to 0.0386, no tier: the ribs' inner faces lie 1e-4
    off the rod at the tangent and the chords cross them 0.0121 apart along the line, where the faces are hidden). The
    sorted sweep and V1's closure gave the same chords on all of it (the closure made 8 × the tests: 189,117 against
    23,989 on the fixtures).
  - V1's figures on the final tree (`obliq`): the turned laminate 0.3017 / 0.3021 / 0.3033 at 0.0100 / 0.0105 / 0.0119,
    0.9987 at 0.0121; 15° 0.2580 to 0.0119; 45° 0.4432 at 0.0100 … 0.4695 at 0.0119 (Hard from 0.0110, continuous: ~~the
    tip, turned 45° about Z, against the plates turned 45° about Y~~ [fixer G: not the tip; without it the rise stays,
    0.3743 → 0.4421, Hammering 0.1714 → 0.1964 over 0.005 → 0.0119: it is the slit's mouth at the rims, where a chord
    that enters the gap leaves into air, and with the mouths closed by a scratch closure the blade reads 0.1833 Normal
    at 0.0119 (fix round 3's section)]; crossings V1's rule merged at 0.4300 … 0.4548); the diagonal 0.1442 / 0.1433 /
    0.1416 at 0.0112 / 0.0113 / 0.0115.
- *D1's gate.* `timing` (the tree before and this one alternating in one process, a warm-up, a full collection before
  each run, order A B / B A by round; every worst valid design and P1): a null run, the tree against an identical copy,
  0.957–1.033 at 21 rounds (load 17 → 15 %), so a case is ±4 %. The first form (sorted triples of parts, every test
  computing a normal) measured up to × 1.065 (projected 56.9 ms; `phasetime`: Thinness +18–25 %, the edge +2–25 %, even
  on P1 with no test); a table of triples instead of a second table of parts, the one-chord cell, and the sd pre-test
  (98 % of the tests past the box stopped at the first probe, and sd(q, e) > `REACH` on nearly all) brought it to
  0.995–1.023 (41 rounds, 14 → 8 %). The final tree: 0.995–1.028 (41 rounds, load 17 % → 6 %), worst valid 8, the
  53.4 ms design, × 1.0255 → 54.8 ms projected, the largest worst valid 5 × 1.0277 → 54.9: under 57. The tie rule
  alone (`dzd2`) 0.985–1.045 (21 rounds, 18 → 12 %).
- *D2.* V2's channel on the tree before: the Y draw alone moved G on 53 of 3,000 designs of six streams (up to 0.0055;
  `ydraw` on 100 of 0x5EED0001: Thinness past 1e-9 on 2 steps, its last bits on 93 of 300, L's and the chords'
  rounding, so "to the bit" cannot hold). The lead's first option, a nudge of the other parts' line, chosen
  generic ((−0.491, −0.237, 0.838)·1e-9, its least part along 56,808 face normals 1.57e-12) and lateral (its part along
  the line removed, so the laminate's chords stay exact), passed: G moved on none of the 3,000, Thinness within 1.14e-14.
  Its 8 sign octants on the fixtures: Y down moves 4 (X04/X05: 0.1044 → 0.1037), Y up 41 (every tip on its blade's top
  face); X and Z signs nothing. But on the plausible set it moved 1,270 designs, 82 a tier, deciding each tie by its
  direction (`tietrace`: a fuller's core probes at x = 0.025, exactly the groove's edge, a strip's side face; the Z
  chord along it met the strip by rounding, τ 0.08, and the nudge put it in the groove, τ 0.02: Hammering 0.0564 Normal
  → 0.2295 Hard; the groove's other edge goes the other way). The closed rule (`TIE`): its first form grew the chord but
  not the box test, and the box test still decided by rounding (G moved on 2–10 designs a stream); grown both, the six
  streams and V2's 0x0C0FFFE1: G moves on none but one of 0x0C0FFFE1 (0.0001, Thinness unmoved: M2's owned volumes),
  Thinness within 1.14e-14, the Blocks written (b, a, c) none; the fixtures' 544 shifted copies (`fixshift`): along Y
  G moved on 45 before (X02 0.0031), on none now, Thinness on no step past 1e-12; in all only C09 0.037 down in Z
  (SurfaceComplexity 0.0007); the property stream's 500 translated in Y and Z: ΔG 0.0016 → 0, Δx 0.0040 → under 5e-5.
  Moves (`attrib`, base against the tree, its D1 and D2 halves; every move attributed, none unexplained): X04-5-0.006,
  X05+0.002, X05+0.006, X05-0.020 0.1044 → 0.1037 (F5's: their tip's probes on the blade's face); Gen 17, 19, 131, 161,
  193 (up to 0.0012); ~~850~~ [fixer G: 839, by V2's dumps of the trees with the tie rule alone, re-counted] plausible
  designs, 53 a tier (fullers 560 / 47, wedges in guards ~~108~~ 107, plate edges 57, grilles 36, cylinder ribs ~~35~~
  29, rods ~~29~~ 26, bevels 24 / 6, ~~a ribbed bar~~; with D1's 14 ribbed bars, 853 for the round), |Δd| up to 0.3932.
  `tiecheck`: on 57 of them (8 a
  family), every one of the 1,672 probes whose τ moved runs a line (Z or θ) along another part's face within 1e-11.
  Six-seed runs of `tests/Physics` (T-PERF-01 aside) in copies: 339 / 339 on each of 0x5EED0001, 0xDEADBEEF,
  0x0C0FFEE1, 0x13579BDF, 0x2468ACE0 and 0x7A11C0DE (327–362 s, four at once).
- *D3* (`recutaim`, `recutdown`, `recutwedge` on the final tree, = the tree before): V1's plate 0.1075 Normal whole,
  0.1608 / 0.1786 / 0.2141 Hard / 0.2853 / 0.3242 / 0.3254 in 3 / 4 / 6 / 8 / 10 / 11 pieces (Thinness 0.2667 → 0.8116);
  mirrored (overhanging +X by 0.05) 0.1253 → 0.0008 from 6 pieces; overhanging +X by 0.08, 0.2158 Hard → 0.1446 Normal in
  4 pieces, 0.0024 in 11 (the re-cut that lowers G a tier); V2's Wedge re-cuts 450, ΔG up to 0.0521 (Prop 231), 16 past
  0.024, flips on Prop 425 (0.2037 → 0.1645) and Prop 297 (0.2011 → 0.1993). The Prop stream's `Gen.segmented` 500:
  0.0379 (#115), 0.0339, 0.0294, 0.0215, 0.0195, 3 past 0.024, 1 flip, unchanged. O11 (ii), `var/floor8` (at least 8
  probes a part, the j-th in the middle of the j-th of t equal stretches of its walk, each weighing the part's share
  over t): V1's plate 0.1075 → 0.0808 from 3 pieces (ΔG 0.0267), mirrored 0.1253 → 0.0808, the 0.08 overhang 0.2158 →
  0.2424; a 0.025 plate overhanging 0.11 still 0.1871 Normal → 0.2101 Hard in 4 pieces; probes on the worst valid
  designs and P1 9,086 → 9,193 (worst valid 11 +17 % on All), on the fixtures at most C10's and C11's 605 → 748; time
  against the round's tree 0.985–1.042 (21 rounds, 17 → 16 %), within the noise. O11 (iii) described only.
- *D4* (`out/mutants.txt`): FA8 (−Z never flipped) fails the walk case; `TIE` = 0 fails the face-tie case and T-DIF-07
  (a)'s F1 at +0.125; V1's distance rule (charging 6, as the real test) fails the hidden-gaps case's corner; no oblique
  merge fails the slanted laminates, the hidden-gaps case and the union chord's; the slanted laminates fail on the tree
  before; the window's edge passes on the tree before and kills FA2 there, but FA2 alone is equivalent on this tree (a
  perpendicular gap 0.01200005 apart now merges through the hidden-gap test, whose probe lands 5e-8 short, within
  `EPS_GEOM`); FA2 with the hidden-gap test's `EPS_GEOM` dropped fails it.
- *D5.* Against the tree before: the 136 fixtures, 4 D1 moves and 4 D2 (above), ~~52~~ 53 last-bits only [fixer G, by
  V2's `fcmp`: 61 moved]; Parity's 200, 5 D2, 14 last bits; the 33,389 plausible designs, 14 D1 and ~~850~~ 839 D2, the
  rest last bits or none; this tree equals `dz` (the
  attributed tree) bit for bit on all three sets. M2's physics (mass, volume, COM, balance, reach, bladeLength) never
  moves. The digest: the fixtures' group 425,752 →
  425,658 bytes, fnv1a32 3014135086 → 60321529; the generated group 709,377 → 709,366 bytes, 410604535 → 611215233; 61
  fixtures' and 19 generated designs' hashes moved. `--quick` on the repo: 694 pass, 0 fail, 42 skip, 30.66 s (load
  7 → 14 %).
- Suites, under the user's programs (not quiet): `scripts/verify` (17:05–17:11, the machine 14 % busy at its start and
  10 % at its end): tools, sourcemaps, T-META-07 (141 files, 985 requires) and luau-lsp's two passes clean, then 735
  pass, 1 fail, TESTS FAILED (329.7 s), exit 1: T-PERF-01, worst valid 8 62.11 ms over `ANALYSIS_LUNE_MAX_MS` 60. Run
  alone it failed again (worst valid 5 60.25 ms, 14–45 % busy, median 18 %), and so did the tree before, alone, right
  after (worst valid 8 60.97 ms, 9–30 % busy): under this machine's ordinary load the totals sit at the guard, as
  V2 found (58.9–59.8 ms at 7–26 %); quiet, the round projects 54.8 ms (above). The last `scripts/verify`, on the final tree (17:14–17:20, the machine
  10–40 % busy, median 23 %, sampled every 5 s): the same stages clean, 735 pass, 1 fail, TESTS FAILED (332.5 s), exit
  1, T-PERF-01's worst valid 8 at 61.47 ms; every functional case passes.

**Open issues**

- For the lead: the closed tie rule decides ~~850~~ 839 [fixer G] plausible designs' face ties once and for all, 53 a played tier, mostly
  fullers whose groove edge lies on a column of samples and bevels; any rule that ends rounding's say moves about that
  many (the nudge 1,270), and closed is `Shapes.chord`'s own convention. **[Decision to confirm]** (§17.1 O11).
- For the lead: the timing gate holds on a projection from loaded, alternating runs (54.8 ms for worst valid 8); a quiet
  T-PERF-01 has not been run on this tree.
- FA2 alone is equivalent now (D4); the window's edge is held by the plain window and the hidden-gap test's `EPS_GEOM`
  together, and the case kills the pair.
- Not mine, for fixer E: V1's major 3 (the diagonal Wedge split's flush faces show where the partner is thinner than
  `HIDE_OFFSET`: the diagonal at 0.0000 still plays Sharpening 0.1563 against the whole blade's 0.0989), a Wedge written
  its other way (C09's bevel 15, O11's "another writing moves nothing"), §4.1's departures, §16.18's `SAMPLE_X`/`SAMPLE_Y`,
  timing and README's Status. O11's re-cut text here is D3's; O10's slant here is D1's.
- V2's seed list had 0x0C0FFFE1 where the lead's has 0x0C0FFEE1; both were run.
- S-PAR-02's digest moved again (above): the Studio runs must use this `parity.bv1.digest.txt`.
- My scripts are in the session's Temp scratch, `m3-fix2d`, which loses week-old files: the numbers are here and in
  E-S2.13.

**Deviations from the plan and the SPEC**

- D1: the merge test is the measure's own hide test at the two crossing points, not V1's two-sided distance test, which
  failed the lead's own check (it merged a corner or an edge beside a face where the verdict shows them: 4,164 joins on
  the plausible set, 4 tiers, worst valid 4 a tier). On facing gaps the two agree everywhere tried. The cheaper form
  tests only the nearest chord past each end after the plain closure, which gave V1's closure's chords on every corpus.
- D2: the lead's second option, an exact tie rule inside Factors (every part but the owner grown by `TIE`, closed), not
  the nudge, which passed the same gates but decided ties by its direction and moved half as many plausible designs
  again.
- D2's tests assert Thinness within 1e-12, not to the bit: its last bits follow the rounding of L and of the chords
  under a Y draw (395–462 of 1,500 steps a stream, up to 1.14e-14) and under another writing (188–253, up to 7.9e-15).
- Beyond the listed sections: §0.5's row, §5.5's introduction, §14.6's T-EDG-01, §16.18's guards, and `Difficulty.spec`'s
  `D_RANK` (the four X fixtures), which named the old values.
- The laminate case of fix round 1 holds Thinness within 1e-9, not 1e-12: a chord ending on another part's slanted face
  is read `TIE`/cos longer.

## Fix round 2, fixer E: the text, the remaining tests and the minors

The lead's items E1–E5 of `.build-notes/m3/m3_journal_r2.txt`, on V1's major 3 and minors (`m3_v1_adversary_r2.json`)
and V2's minors (`m3_v2_numbers_and_text_r2.json`), after fixer D. No code changes but comments: M2's code untouched.
Measured with Lune 0.8.9 through `Analyze.run` and `Sampling.exposure` on the live tree (the 0.8.9 binary itself, one
process a run, at most 4 at once); the scripts are in the Temp scratch `m3-fix2e/work` (`diagflush`, `diagwhy`,
`wedgewrite` (V1's), `bevel`, `segcmp`, `timing` (fixer D's), `proto_cmp`, `numbers`, `dump` with `cmp.py` (V2's),
`rounds.py`, `segpl.py`, `updesign`, `mirror24`, `mirror24d`, `dense`, `parts`, `slowcases.py`, `slownotes.py`,
`evidence.py`, `reflow.py`), the trees in `m3-fix2e/var` (`segprobe` and `segprobe2`, the measure's probe a segment;
`ea5`, `SAMPLE_X`/`SAMPLE_Y` 0.0012 / 0.0018; `null`, an identical copy for the timing's noise; `nullbig` and `segbig`,
`N_SUB_WORK` × 100), with a step-by-step `NOTES.md`. The machine was 11–82 % busy with programs not mine; every timing
below says its load.

**What was built**

- No module's behaviour changed. Comments: `Sampling.luau`'s header (a gap validation calls connected hides the faces
  across it where the part beyond holds the probe; a face flush on a part thinner than `HIDE_OFFSET` shows, the probe a
  point; M2's file, its code untouched; `Cover.luau`'s header claims nothing else and is unchanged); `Edge.luau`'s
  `SAMPLE_X`/`SAMPLE_Y` comment (they move values and go with `BALANCE_VERSION`); `Perf.spec`'s header (where the full
  suite runs it, the ordinary load).
- Tests (comments only): `Invariance.spec`, a line on each T-DIF-04 base pin that fix round 1 moved ([7.6]'s 0.1863 /
  0.3835, 0.3299 / 0.2153 and 0.3599); a line above each of the 11 cases fixer B moved to `t.slow` (`Analyze` 2,
  `Difficulty` 1, `Factors` 2, `MassProps` 1, `Sampling` 4, `Verdict` 1: why it is slow, and that its designs are the
  first of its `FUZZ_N_VALID` or `PROP_N` sibling's, or for T-PHY-04's that `--quick` keeps its fixtures' case).
- SPEC: §0.5's row (a face flush on a thin part, O10; a Wedge's surface samples, O11); §4.1 (the build's departures
  from the prototype since fix round 1, §4.6 and §5.2, with their size); §4.4 (the point probe and the thin partner);
  §4.9 (where the full suite runs T-PERF-01); §5's promise (O10's gloss and the thin partner, O11's Wedge); §5.2 (a
  Wedge's surface samples; the paragraph re-wrapped); §5.6 (the writing row, the 2 % rule's row); §14.1 (`--quick`
  under load); §14.11 (T-PERF-01 under load, where verify runs it); §16.18 (`SAMPLE_X`/`SAMPLE_Y`); §17.1 O10 (the thin
  partner: what the build does, ordinary builds' bands, options (i) and (ii) with their costs, the question and
  default) and O11 (a Wedge written its other way); §17.2 (the checkpoint row's "runs it last", the 2 % rule's row, the
  invisible construction row). Evidence E-S2.13: the introduction, a Wedge's writing, the X mirror's cause, the
  physics frame's bit-identity sentence rescoped, two bullets (fix round 1 beyond the 70 fixtures; a face flush on a
  thin part) and the cost under the machine's ordinary load. README's Status no longer claims verify green. Fixer C's
  open issue on the X mirror gets its cause.
- Nothing re-blessed: no value moved.

**Measured**

- *E1, a face flush on a thin part* (V1's `diagflush` and `diagwhy` on this tree): the main blade cut flush along its
  X-Z diagonal into two Wedges (the same solid): F5 (= F1) Sharpening 0.0989 → 0.1563 (SurfaceComplexity on the Blade
  2.2584 → 2.4721); F5 0.05 thick 0.1440 Normal → 0.2224 Hard; F5 0.04 thick 0.2280 → 0.2989 (Hard both); C02, C02s,
  C13, C14 0.1318 → 0.1832; C09 (its core) 0.1904 Normal → 0.2225 Hard, Hammering 0.3201 → 0.3443; F3's Hammering
  0.4423 → 0.5146; C04 0.3379 / 0.4769 → 0.4047 / 0.5670; C08 0.0992 / 0.2487 → 0.1328 / 0.2643; C12's Sharpening
  0.1318 → 0.1381; C05's Hammering 0.1369 → 0.1391; F2, F4, C01, C07 under 0.002; Thinness the same on every one (C06
  and C15 have no axis-aligned Blade Block). F5's blade's exposed area 1.1440 → 0.5720 (the lower Wedge, rank 4) +
  0.6826 (the higher, rank 3): its slope shows 0.1106 of 0.4443 (24.9 %), where the partner is under 0.012 thick along
  the normal over 0.0320 + 0.0045 of the 0.1709 diagonal (21.4 %; the rest is the sub-grid). `bevel`: a Block 2.6 long,
  a Wedge bevel on its side over a 0.06 contact: the Block ranking higher shows 0.0585 / 0.0390 / 0.0195 / 0 stud² for
  a bevel 0.03 / 0.05 / 0.10 / 0.20 wide (δ·a/b·L 0.0624 / 0.0374 / 0.0187 / 0.0094, the last under the 4 × 4
  sub-grid's reach); the Wedge ranking higher (a Block 0.03 × 1.0 × 0.06, a bevel 0.30 wide), nothing.
- *E1, the bands on the §5.5 fixtures and option (ii)* (`segcmp`: `var/segprobe`, the measure's probe a segment, a part
  grown by `EPS_GEOM` met anywhere from 2·`EPS_GEOM` to `HIDE_OFFSET` along the normal hiding the sample, by
  `Shapes.chord`, near-tested by the chord grown by the patch's reach and deep-tested at the overlap's middle; `Cover`
  untouched): exposedKept less the variant's, C09 2.9259 → 2.7543 (5.86 %: core 12 0.0690, bevels 14 0.0570 and 16
  0.0431, tip 18 0.0024; δ·a/b·L 4 × 2.4 × 0.0072 = 0.069 on the core's sides, 2.4 × 0.02 = 0.048 a back-to-back
  pair), C13 0.0101 (0.33 %: tip 0.0030, guard Blocks 6 and 7 under the CornerWedges 0.0035 each), C04 0.0042
  (0.20 %), C07 0.0023 (0.15 %), C06 0.0030 (0.11 %), C02, C02s, C12, C14, C15 0.0030 (0.10 %: the higher tip Wedge's
  back face, 0.048 × 0.06 = 0.00288), F4 0.0046 (0.07 %) and C05 0.0044 (0.05 %, a tip on its blade's top), C08 0.0024
  (0.05 %), F1, F2, F3, F5, C01, C10, C11 0. Steps: no §5.5 tier moves; C09 Hammering 0.3201 → 0.2432, Sharpening
  0.1904 → 0.0955 (SurfaceComplexity on All 2.6254 → 2.4715, on the Blade 2.5846 → 2.2679); C04 0.3379 / 0.4769 →
  0.3354 / 0.4731; C06 0.2991 / 0.5948 → 0.2978 / 0.5932; C08's Hammering 0.0992 → 0.0986; every other d the same
  (SurfaceComplexity under 2.3 where it moves). `var/segprobe2` (the segment only where the point rules leave a
  sample showing: one chord grown by the patch's reach, then one by `EPS_GEOM`) gives the same exposed areas and d. With
  it the diagonal cut plays its whole blade's d (`diagflush` on `segprobe2`: F1, F5 at 0.06 / 0.05 / 0.04, F3, C02,
  C02s, C04, C07, C08, C12–C14; F4 0.1557 / 0.3401 against 0.1572 / 0.3420, as on this tree: the re-cut's own grids; C05
  within 0.0010; C09's core 0.0003). The plausible set (`dump` on `segprobe2`, two processes, 18:00–18:09, `segpl.py`
  against this tree's): d moves on 5,191 of 33,389 (5,167 down, 24 up), up to 0.2053 (`ribBar|r0.10 L3.0 n12 roll11.25
  f0.7`), 2,212 by 0.05 or more; the played tier on 197, all Hard → Normal: 185 built on C09 (`wrapRings` 67,
  `plateEdge` 54, `bevel` 28, `cylRib` 18, `plateC09` 6, `pommelInBlock` 6, `ballRivet` 4, `cylRivet` 1, `plateTilt` 1),
  whose own bevels' band goes as on C09 (0.3201 → 0.2432, 0.1904 → 0.0955), 8 on C02 (its tip's band: `bevel` 5,
  `plateEdge` 2, `laminate` 1; `updesign` on `plateEdge|C02|blade w0.5 k0.6 l1.0 poke0.0300`: only Wedge 6 moves,
  0.06774 → 0.06474), `bevel` on F1 and F5, a `lamHilt` and a `ribBar` (`ribBar|r0.06 L3.0 n6 roll0.00 f0.7`: its rod
  0.41086 → 0.13695, the rod's side beside its narrow ribs' edges); Hammering 104 steps, Sharpening 95; kept flags and
  owned volumes on none. The 24 up (by up to 0.0207, `bevel|F3|a0.05 b0.08 height0.030`; laminates 10, bevels 10,
  `lamHilt` 2, `ribBar` 2) are the measure's sub-grid budget, spent sooner: `updesign` on that design and on
  `laminate|C02|k0.02 wf1.5 proud0.0150` with `N_SUB_WORK` × 100 reads every part alike on both trees but the band (the
  C02 laminate's core 0.20852 → 0.21288 at the real budget, 0.27691 on both at the large one).
- *E1, its cost* (`timing`: this tree and the variant alternating in one process, a collection before each run, order A
  B / B A by round, medians of 31): `segprobe2` × 1.041–1.267 on the worst valid designs and P1, worst valid 8 × 1.1917
  (54.8 ms quiet → about 65), the sum × 1.1952 (load 35–82 %); × 0.941–1.157 on F1–F5 and C01–C15, C09 × 1.1558, the sum
  × 1.0550 (26–48 %). `segprobe` (the segment on every candidate) × 1.049–1.402 (sum × 1.2244, 43–79 %) and, first, ×
  1.080–1.360 (sum × 1.2285, 48–76 %). The noise: this tree against `var/null`, an identical copy, × 0.970–1.035 (sum ×
  1.0030, 40–76 %).
- *E2* (`proto_cmp`, V2's): against the reference prototype on its 66 fixtures, Thinness same-grid max |Δraw| 0.237
  (P3, Smelting), EdgeLength 0.0828 (P2), d, g or raw tier on 15 steps of 14 fixtures (C04 ×2, C05, C09, C13, X01,
  X01raw, X04-5-0.006, X05+0.002, X05+0.006 and X05-0.020 (0.1037 against 0.1044, fixer D's `TIE`), X05-0.050, P1,
  P3, P5); on `m3-r1-base` (V2's run) both exact, 1 step (P1, another grid). `numbers` (V2's) on `var/ea5`: 14 of the
  70 golden entries differ (C06's EdgeLength 6.479507 → 6.479723, C09's mean thickness, C15's blade area, P1, P2's
  chains 15 → 14, P3, P4, P5's cutIndex 0.820973 → 0.820798, the six specks), no d; the live tree 70 of 70 equal.
- *E2, fix round 1 beyond the 70 fixtures* (V2's `dump` on this tree: the 33,389 plausible designs in two processes,
  about 16 min each, Parity's 136 fixtures and 200 generated designs; against V2's dumps of `m3-r1-base` and
  `m3-r2-base`; `rounds.py`): fix round 1 moved d on 14,230 plausible designs (up to 0.3122, `ribBar|r0.06 L3.0 n4
  roll45.00 f0.3`), the played tier on 164 (fullers 73, ribbed bars 52, ribbed blades 27, bevels 10, plate edges 2),
  the raw tier alone on 222, kept flags and owned volumes on none (V2's figures to the digit); fix round 2 d on 853
  (up to 0.3932, a fuller), the played tier on 53 (fullers 47, bevels 6), the raw tier alone on 30; both rounds d on
  14,333, the tier on 197 (fullers 104, ribbed bars 52, ribbed blades 27, bevels 12, plate edges 2), the raw tier alone
  on 242. Fix round 2 moves 10 of fix round 1's 164 flips again (8 fullers; `bevel|C02|a0.05 b0.05 height0.750`, 0.1358
  Normal → 0.2164 Hard → 0.1358, and F2's), every one back to its tier from before fix round 1. Generated: fix round 1
  d on 78, the tier on Gen 57 (Hammering 0.1095 Normal → 0.2589 Hard) and Gen 126 (Sharpening 0.2000 Hard → 0.1938
  Normal, Hammering 0.0992 → 0.0612); fix round 2 d on 5 (up to 0.0012), no tier. Fixtures: fix round 1 d on 19 (C04,
  C05, C09, C13, X01, X01raw, X05-0.050, P3, P5, P3's specks, worst valid 2, 3, 4, 5, 6, 8, 9, 10), the tier on P3, P5,
  P3's specks and worst valid 4 (Hammering 0.0434 Normal → 0.2215 Hard); fix round 2 d on 4 (X04-5-0.006, X05+0.002,
  X05+0.006, X05-0.020), no tier. `dense` (every owned sample a probe, V2's `densefx` rule): Gen 57 Thinness on All
  0.6456 on 286 probes, 0.4669 dense; Gen 126 0.1495 on 338, 0.2265; worst valid 4 0.4791 on 364, 0.4673.
- *E2, the order* (`--list`): T-PERF-01 is the 601st of 736 cases, in path order (`tests/Physics/Perf.spec`), 135
  after it.
- *E3* (`wedgewrite`, V1's): every Wedge of the 19 fixtures with one (F3, F4, C02, C02s, C04–C09, C12–C15, X03, P3, P5,
  P3's specks) written (x, z, y), turned (x, y, z) → (−x, −z, −y): Thinness the same everywhere; only C09's bevel 15
  moves, SurfaceComplexity −1.05e-3 on All and −2.15e-3 on the Blade, Hammering 0.3201 → 0.3196, Sharpening 0.1904 →
  0.1897, mass to the bit; on `segprobe2` the same SurfaceComplexity move (not the band: M2's surface samples).
  `mirror24` and `mirror24d` (V1's `mir24` and `probes`, V2's `mirror24`): #24 Hammering 0.1585 → 0.0964 (Thinness on
  All 0.3941 → 0.2388, stride 2, 377 probes each), 0.3697 dense both; every part's probes the same τ but the Wedge
  tip's (part 4, 0.0894 × 0.1817 × 0.0628, 90° about Y, 8 samples, 4 probes): its smallest local axis along X, the walk
  outermost on it and signed +X in both (x −0.016 then +0.016), so the design's walk is 2 samples then 6 and the
  image's 6 then 2; the lattice (from slot 4, step 5) takes slots 4, 1, 6, 3 of each: τ 0.0235, 0.0549, 0.0392, 0.0392
  against 0.0392, 0.0392, 0.0549, 0.0549, 2 of the image's 4 the mirrors of the design's.
- *E4*: the figures V2 and fixer D measured under the machine's ordinary load are now in §14.1, §14.11, §17.2 and
  E-S2.13. A wait for a quiet machine (17:57–18:27, three samples at most 20 % wanted, 84 samples: 17–99 %, median 45 %,
  my plausible dumps of 18:00–18:09 among them) found none. The last `scripts/verify` (18:27:52–18:34:42, the machine
  28–74 % busy, median 40 %, sampled every 5 s): tools, sourcemaps, T-META-07 (141 files, 985 requires) and luau-lsp's
  two passes clean, then 735 pass, 1 fail, TESTS FAILED (409.6 s), exit 1: T-PERF-01, F2's longest stretch 0.489 ms over
  `CHECKPOINT_GAP_LUNE_MS` 0.35, where fixer D's two failed on worst valid 8's total; every functional case passes. Docs
  only changed after it (§14.11, §17.2, README, E-S2.13, these notes: the run's line).
- *E5*, the read of §0.5, §5's promise and §17.1 as a whole: of the SPEC's 88 **[Decision to confirm]** marks every one
  carries its number (4 from before M3 in other forms: "(Q2)" after a comma in §1.4, "(Q11)" before the mark in §6.5,
  "Q20" and "Q6 autosave" in §16's tables); every limit the SPEC states against §5's promise is named there with its
  O-number, newly the thin partner (O10), a Wedge's surface samples and a round part's sampled overlap under a shift
  (O11), and §0.5's row names the same; O7 (the cap makes a design visibly invalid) and O8 (a label is visible) are not
  exceptions to it; each of O7–O11 states what the build does and what each way out costs, O10 now with (i) and (ii).

**Open issues**

- For the lead: §17.1 O10's thin partner, **[Decision to confirm]** (§17.1 O10). The default is the point probe as
  built (i): in the measure the band only adds exposed area, but an invisible diagonal cut moves a tier (C09's core
  0.1904 Normal → 0.2225 Hard), and C09's own Hammering and Sharpening carry 0.077 and 0.095 of band; in the verdict a
  band can keep a part whose faces only bands show (not measured). The segment probe (ii) removes it in the measure,
  plays 197 plausible designs a tier lower (185 built on C09, whose bevels carry the band) and costs about a fifth of
  the slowest design's time (worst valid 8 would pass the 60 ms guard quiet); its verdict half is
  described, unbuilt, and would move verdicts and E-S2.12's figures.
- For the lead: T-PERF-01 needs a quiet machine and has not run on one on this tree; README's Status says so.
- The segment variant's cost was timed under heavy load (26–82 %); a quiet re-time would firm up the × 1.19.
- My scripts are in the session's Temp scratch, `m3-fix2e`, which loses week-old files: the numbers are here and in
  E-S2.13.

**Deviations from the plan and the SPEC**

- E2's order: the SPEC used "after every other spec" only to explain the larger heap behind the stretches it reports
  past 0.35 (collections); its asserted figures are taken run alone. That reason holds at T-PERF-01's place in path
  order, so the text now says where it runs; the runner and `scripts/verify` are unchanged (§14.3's byte-wise order).
- E2's slow cases: one line each, not one sentence in a shared header, so a case moved back to fast takes its note
  with it.
- E1: `Cover.luau`'s header is unchanged: it describes the probe as a point and claims nothing about thin partners.
- Beyond the listed sections: §5.2's paragraph (re-wrapped after a Wedge's sentence), §14.1's `--quick` row (E4's
  `--quick` figure), §5.6's two rows, §17.2's invisible construction row, fixer C's open issue, and a round part's
  sampled overlap under a shift at §5's promise and §0.5 (fixer D's 0.0001, so far only in O11's question and
  E-S2.13).

## Fix round 3, fixer F: the hidden-gap rule (withdrawn in fix round 4)

**Withdrawn in fix round 4** (fixer H, below; `.build-notes/m3/m3_journal_r4.txt` H1). The set rule this section built
merged visible air: nothing asked whether the air between the two crossing points is a gap, so at a grazing slant both
probes were held by parts beside the line while it crossed an open slot (M3's review round 4, V1's slot sword:
Sharpening 0.2728 Hard → 0.0720 Normal, the edge cut in two; Thinness' union chord 0.0421 → 0.2905), the same mechanism
as the 40 joins on 4 ribbed bars its own open issue counted. The code is back to the pair rule (each face's probe asked
of the part across), and the seam it was built for is a named residual under §17.1 O11. What follows is fix round 3's
record, as measured.

The lead's items F1–F3 of `.build-notes/m3/m3_journal_r3.txt`, on V1's major (a flush seam beside a slanted crossing)
and the round's tests (`m3_v1_adversary_r3.json`, `m3_v2_numbers_and_text_r3.json`); the tree before the round is the
Temp scratch `m3-r3-base` (after fixer E). Measured with Lune 0.8.9 through `Analyze.run` and Edge's and Factors' own
calls (the 0.8.9 binary itself, one process a run, at most 4 at once); the scripts are in the Temp scratch
`m3-fix3f/work` (`seam` (V1's seam and seam2), `sweep`, `neighbours` and `linesweep` (fixer D's), `dump` with `fcmp.py`
and `tiers.py` (V2's), `rasterdiff`, `bridge`, `joinscan`, `joinwhy`, `guardseam`, `guardcomb`, `seam45`, `vee`,
`stack3`, `runlast`, `runorder`, `charges`, `counts`, `adv`, `advcheck`, `advcost`, `timing` (V1's), `plone`), the
trees in `m3-fix3f/var` (`fix4`, V1's; `B`, the rule with every kept part a hider; `Bw`, this round's code; `Blog`,
`Bwlog`, `Bnx`, `Bwnx` and `Bcnt`, their join-logging, no-bound and query-counting copies; `base_tests`, the tree before
with this round's specs), the mutants in `m3-fix3f/mut`, with a step-by-step `NOTES.md`. The machine was 5–45 % busy
with programs not mine; every timing below says its load.

**What was built**

- `src/shared/Physics/Edge.luau`:
  - `hiddenGap(p, e, q, f, set)`: the gap across, (f − e)·n_p, at most `REACH` (a normal; past it nothing more is
    asked); p's probe held by q, else by any part of `set` but p and q (`held`: a unit a box test, a unit an sd); then
    the same from f, along q's normal. Without a set it is the pair rule of fix round 2 with the bound across. V1's
    fix4, but for its reach pre-tests: a probe within `EPS_GEOM` of a part puts that part within `REACH` of the point,
    box and sd alike, so they decided nothing, and their loop over the list charged none of its box tests;
  - `mergeSorted` passes the set on; the raster's set is the striking slot's kept parts;
  - the header: the function list, the Raster paragraph, the Hidden gaps paragraph (the set and why, the seam, the
    bound across and the channel it keeps out), the Work paragraph (every hider looked at is charged).
- `src/shared/Physics/Factors.luau`: `unionChord` passes its list, W in the measure's rank order, as the set at both
  calls (fix4's); the Thinness paragraph and unionChord's comment.
- Tests (each fails on its mutant or on the tree before, and passes on this tree; `NOTES.md`, step 5):
  - `Edge.spec`: the hidden-gaps case on two shared builders (`turnedPair`, `rodOverPlate`), its units read as a normal,
    a box test and an sd per face (6), and the cheap exit as one normal for a point 0.05 across (it was "out of reach:
    no query", 0); V1's V1R3Edge (the window's edge crossed at 30°, the rod's flank to the plate), V1R3Normals (every
    shape's face), V1R3Seam's 45° case with the set, its units (pair 2, set 7), the set in any order and the seam at the
    window's edge (0.01200005 hidden, 0.0120002 shown), a V of two plates whose faces a third hides (`vee`: merged at
    0.0104 across at both points, open at 0.0155 at either), V1R3Merge's raster runs with three more that are not
    parallel (a flat block, a Wedge on it, a plate over its slope, in two orders; a flat plate under the laminate), and
    V1R3Three's raster charges; the header.
  - `Factors.spec`: V1R3Three's union chord (three plates, from each) with V1's seam in the list; the charges by
    caller pinned anew (F5 on All 4,911 → 4,921, F4 5,600 → 5,644, P5 14,794 → 14,848, on the Blade 8,273 → 8,351: a
    normal first where the pre-test's box was free, the probes' box tests charged); `type Prepared`; the header.
  - `Invariance.spec`: V1R3Seam's T-DIF-04 case (`seamedLaminate`: 3 seams 0.0105 apart, one 0.0119 apart, against the
    same pieces at 0.0100) and V2's three and four plates (`slantStack`, Thinness within 0.01 for ~~the gaps' mouths at
    the rims~~ [fixer G: the plates' grids as they thin; a scratch closure of the mouths reads them the same], 0.0073 and
    0.0075 at 0.0119); the header.
- Nothing re-blessed: no fixture, generated design, golden or digest value moved.
- SPEC: §4.6 row 1, §5.2 (τ and the paragraph), §5.5's introduction, §5.6's laminates row, §14.6 T-DIF-04 and
  T-EDG-01. Evidence: E-S2.13's introduction and a fix round 3 bullet.

**Measured**

- *F1, V1's seam* (`seam` v1 on `base`, `fix4`, `B`, `Bw` and the tree): the base reproduces V1 to the digit (0.2186 /
  0.3095 / 0.3322 Hard, the lower-plate seam 0.1742, 0.0119 apart 0.2104 Hard) and every rule of this round reads
  0.1734 / 0.1734 / 0.2102 / 0.1264 / 0.1343, within 0.0006 of the same pieces at 0.0100. At 45° (`seam` s45, s45c),
  48 of 49 single seams Hard (up to 0.2513) before, 26 (up to 0.2228) now: the whole laminate plays 0.1994 at 0.0105
  and 0.1765 at 0.005, and each seam's move against its own pieces at 0.005, less the whole's, lies within −0.0095 …
  +0.0078 (median −0.0015), the pieces' grids (O11) on the gap's drift at the rims (V2's major, fixer G's).
- *The set.* Asked of every kept part (`B`, the measure's own hiders), the rule moved the edge of 7 Parity fixtures
  (`fcmp.py`: P3 and its specks +8.6e-6 / +9.7e-6, worst valid 3, 4, 5, 8 +4.6e-5 / +1.1e-4 / +1.1e-5 / +1.1e-5,
  cutIndex down by up to 3.8e-4), 13 plausible ribbed bars' edges and 2 ribbed bars' Sharpening Thinness, no d;
  asked of the caller's own set (`Bw`), none of those. `rasterdiff` and `bridge`: every join the larger set adds, 10 on
  the fixtures and 48 on the ribbed bars, runs the line through a guard, a grip or a pommel part between two blade
  chords (`joinwhy`: P3's #13 → #14 inside Gu#12 all along, sd −0.0073; worst valid 4's six inside Gu#12, Gu#9, Gr#4),
  which the raster then counted into the blade's thickness (`guardcomb`: a laminate whose upper plate alternates Blade
  and Guard strips reads 0.0503 against 0.0484). Only beside a gap does a part of another slot hide it without lying in
  it (`guardseam`, V1's 30° laminate cut at −0.035, the piece beside labelled Guard: the edge 0.0413 at 0.0100, 0.0411
  with every kept part a hider, 0.0395 with the blade's), and its label is visible (O8). On All, W is every kept part.
- *Nothing the verdict shows merges.* `sweep` Y and X (0–75°, F5's hilt, 0.0100 … 0.0125): the tree equals the base on
  all 84 designs, continuous to 0.01200005 and jumping at 0.0120002 with SurfaceComplexity. `neighbours` (stairs,
  corners, roofs on F5's hilt, 55 designs): base = `Bw` = `B`. `linesweep` (120 two-part cases, 1,152,000 lines): every
  chord the base's. `joinscan` (each join the rule makes; per join the normals, the gap across, who holds each probe,
  and whether 9 points along the air crossed each lie within `MERGE_GAP` of two kept parts): fixtures 24 joins on 5
  designs, 6 by a part other than the one across, all sandwiched; generated none; plausible 1,026 on 50 ribbed bars, 301
  by another part, 40 not sandwiched on 4 (`ribBar|r0.16 … n16 roll11.25 f0.5`: a Z line grazing the rod 0.0003–0.001
  off its surface between two staves whose inner faces the rod hides, 0.0297 along the line; a line 0.001 lower crosses
  the rod and merges the same span plainly; no value moves). Without the bound across (`Bwnx`): P3's #19 → #18 (and
  its specks'), 0.110 along the line and 0.088 across, held by #16 (V1's fix2 channel), and one on worst valid 4, not
  sandwiched; with every kept part a hider and no bound (`Bnx`), 1,060.
- *Moves* (`dump` on the 136 Parity fixtures, the 200 generated designs and the 33,389 plausible designs, against V2's
  dump of the tree before, checked on 400 lines): fixtures and generated bit for bit; plausible d on 10 ribbed bars
  (`tiers.py`: V1's 10, |Δd| ≤ 0.0173), no tier, no edge. `--quick`'s goldens and the digest pass unchanged.
- *The gate* (`timing`, the tree before and this one alternating in one process, a collection before each run, every
  worst valid design and P1): 31 rounds, the machine 19–45 % busy (median 24 %), × 0.978–1.013, sum × 0.991, worst valid
  8 × 0.978 → 53.6 ms projected from 54.8; 41 rounds, the order swapped, 23–40 % (median 31 %), × 0.973–1.023, sum
  × 0.995, worst valid 8 × 0.991 → 54.3 (the largest ratio, worst valid 2's × 1.023, → 56.0). The set of every kept part,
  31 rounds at 5–23 %: × 0.988–1.005. Under 57 in every case.
- *The adversarial cost* (`adv`, valid designs on F5's hilt, the slots filled to their maxima): stacks of 4, 8, 12, 16
  and 21 plates turned 60°, 10 / 7 / 5 plates cut in 2 / 3 / 4 pieces with the seams staggered by g·tan 30°, a 0.40
  laminate's upper plate in 8, 12 and 19 pieces, a laminate beside 19 rods turned 45° about Z. `counts` (`Bcnt`, the
  code counting its own normals, box tests and sds): on each of the 136 fixtures and these 13 the units the calls
  returned sum to the queries they made (25,647 calls on the fixtures, 42,329 on the attacks); the largest call 46 units
  (worst valid 9), 39 on the attacks, against a cap of 2 + 2·(2 + 2·22) = 94 with 24 parts; a union chord makes at
  most 2 calls a pass and a pass joins a chord or ends it, and a probe reports its chords' queries with its own units.
  `advcost` (15 rounds, 21–40 % busy, alternating with the tree before): the attacks 19.0–30.1 ms, × 0.95–1.06, longest
  stretch 0.205–0.282 ms; in the same runs worst valid 8 68.3 ms (0.720) and P1 35.7 (0.371). So the slowest such
  design takes about half of `ANALYSIS_LUNE_MAX_MS` and stretches no longer than the slowest valid design's.
- *F2, the mutants* (`mut/mutants.py`, `drive.py`: each on a copy, the whole `--quick`): V1's EH1, EH3, EH4, EH6, EH9,
  EH10, EH12, EH13, EH14, EH15, EH17, EH23, FT7, FT8, FT13, re-expressed where the code changed, V2's m_edgelast and
  m_factorsplain, and this round's NA1–NA3 (either bound across dropped, or `HIDE_OFFSET` for it), NS1–NS6 (the set
  ignored, not passed by the raster or by either union-chord call, p not left out, the set's tolerance 0), NU1–NU4 (a
  charge dropped): all 30 killed. EH13, EH14, EH15 and m_edgelast first survived: with a set, asking the wrong part of a
  run of parallel plates is equivalent, since the right one is in the set and holds the probe, so V1R3Merge's and V2's
  stacks no longer see them; the non-parallel runs (`runlast`, `runorder`: EH13 −0.0101, EH14 −0.0076, EH15 with the
  Wedge first −0.0101, against the tree's +0.0005 and −0.00007) do. NS6 and NU4 first survived too: the seam at the
  window's edge and the pair's 2 units kill them. On the tree before (`var/base_tests`), Edge's hidden-gaps case and its
  set case, Factors' union chord and charges, and Invariance's seamed laminate fail (0.0105 with 3 seams: Thinness
  0.74572 against 0.40514); the rest pass there and kill their mutants.
- `--quick` on the tree: 702 pass, 0 fail, 42 skip, 32.86 s (28–33 % busy), 8 cases more than fixer E's 694, each of
  them 0.00–0.12 s, so none went to `t.slow`.
- The last `scripts/verify` (21:49:00–21:54:57, the machine 26–61 % busy, median 40 %, sampled every 5 s): tools,
  sourcemaps, T-META-07 (141 files, 985 requires) and luau-lsp's two passes clean, then 743 pass, 1 fail, TESTS FAILED
  (356.9 s), exit 1: T-PERF-01, worst valid 5 at 62.14 ms over `ANALYSIS_LUNE_MAX_MS` 60; every functional case passes.
  T-PERF-01 alone right after (25–62 %, median 52 %): F2's longest stretch 0.404 ms over 0.35. Docs only changed after
  it (§4.6 row 1's wording, E-S2.13 and these notes).

**Open issues**

- ~~For fixer G: V2's major, the gaps' mouths at a slanted blade's rims, is untouched; this round's text leaves §4.6's "at
  any angle", §5.2's "however slantwise" and §5.6's row for G to bound, and says nothing of the mouths but the three
  and four plates' tolerance (0.01, for 0.0073 and 0.0075).~~ [Done by fixer G, next section; the three and four
  plates' drift is their grids, not mouths.] At 45° the seams' residue (above) rides on the mouths' drift there.
- For the lead: the set is the caller's own, not the measure's whole list of hiders, which is a choice (Deviations).
  A gap whose only hider is a part of another slot beside it reads open in the raster and in the Blade set
  (`guardseam`: the edge's mean thickness −4.5 %); O8 covers it as a label.
- For the lead: the timing gate holds on projections from loaded, alternating runs; T-PERF-01 has not run on a quiet
  machine on this tree (the last `scripts/verify` below).
- My scripts are in the session's Temp scratch, `m3-fix3f`, which loses week-old files: the numbers are here and in
  E-S2.13.

**Deviations from the plan and the SPEC**

- F1, the set: the caller's own (Thinness its W, the raster the striking slot's kept parts), not the measure's hiders.
  Every kept part a hider is the measure's own test, but a part outside the set that holds a probe lies in the gap or
  beside it: in it, the larger set bridged its metal into the blade's thickness (all 10 joins it adds on the fixtures,
  all 48 on the ribbed bars); beside it, the label shows. The larger set would have moved 7 fixtures' edges and the
  goldens and the digest with them, for joins that are not gaps.
- F1, fix4's reach pre-tests dropped and the bound across tested first: the same answers (`Bw` = `fix4` on every
  fixture, generated and plausible design), every query charged, and a far chord settled by one normal.
- F2: V1's T-EDG-01 5 "units = 6" holds (a normal, a box test and an sd per face); "a part out of reach: no query" is
  now "a point 0.05 across: the normal alone" (1); the charges by caller are pinned anew; V1R3Merge's stacks gained
  three non-parallel runs, without which EH13–EH15 survive under the set.
- Beyond the listed sections: §5.5's introduction (a clause: fix round 3 moved no fixture), Factors.spec's
  `type Prepared`.

## Fix round 3, fixer G: the slit's mouth, the minors and the text

The lead's items G1–G3 of `.build-notes/m3/m3_journal_r3.txt`, on V2's major (a slanted slit's mouth at the rims) and
the round's minors (`m3_v2_numbers_and_text_r3.json`, `m3_v1_adversary_r3.json`), after fixer F. No module's behaviour
changed: comments in `Edge.luau`, `Factors.luau`, `Invariance.spec` and `Perf.spec` only. Measured with Lune 0.8.9
through `Analyze.run` and Factors' and Edge's own calls on the live tree (fixer F's, its code unchanged since; the 0.8.9
binary itself, one process a run, at most 3 at once); the scripts are in the Temp scratch `m3-fix3g/work` (`slant`,
`slantfixed`, `slantedge`, `slantwhy2`, `slantgrid`, `obliq`, `ckcount`, `dump` (an index list added) and `tiers.py`
(V2's); `tieoff` (V1's); `timing` (fixer F's, the reference figure an argument); `mouthcount`, `closecmp`,
`stackcmp`, `seamcmp`, `diagcmp`, `mouthline`, `rastercols`, `tablecheck.py`), the trees in `m3-fix3g/var` (`close0`, Thinness' union chord testing the face at
each end of its chords; `close1`, the mouth closed: measuring tools, not proposals), with a step-by-step `NOTES.md`.
The machine was 9–79 % busy with programs not mine; every timing below says its load.

**What was built**

- No behaviour. Comments: `Edge.luau`'s Hidden gaps paragraph (a slanted slit's mouth stays open, why, the 30° figures;
  a dangling line re-wrapped); `Factors.luau`'s Thinness paragraph (the mouth) and Face ties paragraph (a face typed
  exactly `TIE` from a probe's line); `Invariance.spec`'s header (not a mouth) and its slanted cases' comments (their
  drift is the pieces' grids and the edge's mouth columns, not mouths in Thinness); `Perf.spec`'s case count (608 of
  744) and load.
- SPEC: §0.5's row (a slanted gap's mouth, O10; a face typed exactly `TIE` from a probe's line, O11); §4.6 row 1 (one
  solid where the line crosses from one plate to the other; the mouth, its strip and its 30° figures); §4.9 (the case
  count; O7's 143 ms and 36 Heartbeats); §5's promise (the mouth under O10, the `TIE` boundary under O11); §5.2 (τ, the
  mouth, the `TIE` boundary); §5.5's introduction ("to the next part"); §5.6 (laminates: "from one part to the next",
  0.0016 / 0.0026, "jump alike, only where the faces show", the mouth; Y/Z: the `TIE` boundary; CPU: about 55 ms);
  §14.6 T-DIF-04 (what its slanted cases pin and allow, and the mouth they do not cover); §14.11 (about 55 ms, about 5 of
  headroom, fix round 3's runs, 609th of 744); §16.10 `VERDICT_WORK_MAX` and §16.32 `ANALYSIS_LUNE_MAX_MS` (about 55);
  §17.1 O7 (about 143, 36 Heartbeats),
  O10 (the set since fix round 3; the mouth, its figures and its options (i)–(iii) with costs; the question and the
  default) and O11 (the `TIE` boundary; 839; what the grid (iii) closes and what it needs); §17.2's rows (checkpoints:
  about 55, about 5, fix round 3's load; ties: `TIE`'s boundary; the 2 % rule: the mouth; invisible construction: 839,
  `TIE`; the verdict's cost: about 55 and 36 Heartbeats).
- Evidence E-S2.13: the introduction ("to the next part"; fixer G's sentence), the §5 table's golden sizes, the fix
  round 2 bullet ("continuous, not flat"; 839 with the family list, 853 for the round), a bullet *A slanted slit's
  mouth*, the cost bullet (about 5 ms of headroom, the projection, fix round 3's runs, the checkpoints).
- These notes: fixer D's 45° attribution (not the tip), his 850 (839) and 52 (53); fixer F's three-plate attribution
  (grids, not mouths); this section; `m3-fix3g` in the evidence list. Nothing re-blessed: no value moved.

**Measured**

- *G1, the mouth, re-measured* (V2's scripts on the live tree): every figure of V2's `slant`, `slantfixed` and
  `slantedge` the same to the printed digit (diffed against V2's outputs on the tree before fixer F). F5's blade turned
  45° about its length and split, the outer 0.06 kept: Hammering 0.1765 / 0.1969 / 0.2020 Hard / 0.2068 Hard at 0.005 /
  0.0100 / 0.0110 / 0.0119 (Thinness on All 0.3885 → 0.4695), whole 0.1497, split flush 0.1725; without the tip 0.1714
  → 0.1964; 60° 0.1679 → 0.1896 (whole 0.1253, flush 0.1552); 30° 0.1308 → 0.1321 (whole 0.1199). Two plates 0.024 thick:
  45° flush 0.2315 against 0.2146, 0.0119 apart 0.2075 Hard against 0.1501; 30°, 0.1325 against 0.1204. The raster at
  30°: the mean thickness 0.061085 → 0.060040 / 0.059326 / 0.059055, cutIndex 0.706898 → 0.722693 / 0.733789 /
  0.738076, EdgeLength 5.4494; at 45° and 60° the same to the bit. `slantwhy2` (45°, 0.0119, no tip): 96 of 384, Z
  0.0495 → 0.0340, the plate's chord [−0.021213, 0.012799], the other plate missed; `slantgrid` 45°: the plates'
  samples 0.4419 through the laminate, 0.3961 through the whole blade.
- *G1, the mouth's own share* (`var/close1`: where a union chord ends at a flat face whose probe a candidate holds, the
  chord goes on until the face's foot point leaves the face, `Shapes.chord` of that part in the face's plane, or the
  probe leaves the hiders, their union along its path, at most (`HIDE_OFFSET` + `EPS_GEOM`)/(u·n); then the plain
  closure again; a Ball and a Cylinder's side left open): `closecmp` 45° 0.1812 / 0.1823 / 0.1833 at 0.0100 / 0.0110 /
  0.0119 (Thinness 0.4106, 73 chords continued; 0.005: none), without the tip 0.1781 (71), 60° 0.1656 → 0.1758 (69–73);
  30°: none continued at any gap, so its 0.1308 → 0.1321 is the plates' grids. Fixed plates: 45° 0.0119 closed 0.1836
  (0.0100: 0.1877; 0.005: 0.2041 Hard, against 0.2187), 60° 0.1762; 30° none. `mouthline` (30°, 0.0119): a Z line from
  mid-plate at local x ±0.070 / ±0.072 crosses a mouth (0.02777 → 0.03389 / 0.02989; 0.03389 the whole blade's chord
  there, by hand); no probe's line falls there. `stackcmp`: three and four plates at 30°, closed = tree (3 plates none
  continued; 4 plates 7–9, Thinness unmoved): their 0.0073 / 0.0075 are grids. `seamcmp`: the laminate with 3 seams at
  30° puts its pieces' probes on mouths, 25 chords continued at 0.0100 and 0.0105 alike (Thinness 0.4051 / 0.4053,
  closed 0.3707 / 0.3715; Hammering 0.1734, closed 0.1596), so its T-DIF-04 case compares like with like; one seam,
  none. `diagcmp`: the diagonal, none continued at
  any gap; its Thinness falls as its outline thickens (the mean thickness 0.0599 → 0.0710 over 0 → 0.0119).
  `rastercols`: at 30° and 0.0119 the columns at x ±0.0687 read 0.02777 against the whole blade's 0.03599, every other
  column the same; at 45° none differs.
- *G1, the closure's reach and cost*: `mouthcount` (`var/close0`) on F1–F5, C01–C15, P1 and the 11 worst valid designs:
  no F, C or P1 chord ends at a face a candidate holds; worst valid 3 (2), 4 (47), 5 (36), 8 (10), 9 (12), 10 (2), of
  103,894 chord ends; the end tests make 564,247 units on these 31 designs (worst valid 9 91,617). On the 33,389
  plausible designs (three processes, 134–265 s): 203 designs (ribbed bars 130, wedges in guards 51, cylinder rivets 11,
  cages 5, cylinder ribs 3, bevels 2, wrap rings 1). `dump` of those 203 on `close1` against the tree (`tiers.py`): d
  on 96 (ribbed bars 92, wedges in guards 4; 70 steps down, 26 up), the played tier on 2 (`ribBar|r0.10 L3.0 n4
  roll45.00 f0.5` Hammering 0.3219 → 0.1779, `ribBar|r0.10 L3.0 n6 roll11.25 f0.7` 0.2386 → 0.1584), at most 0.1440.
  `closecmp` fixtures: F1–F5, C01–C15 and P1 the same; worst valid 4 0.2215 → 0.2244 (Thinness 0.4791 → 0.4864, up:
  the self-weighted mean), 8 0.6153 → 0.6143. `timing` repo against `close0` (21 rounds, 14–24 % busy, median 17 %):
  × 1.024–1.206, sum × 1.121, worst valid 8 × 1.198 (54.8 × = 65.7 ms).
- *G2, the `TIE` boundary* (`tieoff`, V1's, on the tree and the tree before alike): F5's tip at y 3.98 + 1e-10, 26 of
  the 120 valid Y shifts (E-S2.10's 4 and 200 drawn) move Thinness, up to 1.66e-3, and G 0.0007 (+0.125: 0.1037 →
  0.1044), no flip; at +0, +0.99e-10 and +1.01e-10, none.
- *G2, §5.6's 0.0016* (`obliq`, V2's): the turned laminate 0.3017 / 0.3021 / 0.3033 at 0.0100 / 0.0105 / 0.0119
  (0.0016), the diagonal 0.1442 / 0.1433 / 0.1416 at 0.0112 / 0.0113 / 0.0115 (0.0026), as V2 found.
- *G2, 839* (`tiers.py` on V2's dumps `pl_r2`, `pl_noobl`, `pl_tie0`, `pl_repo`; the variant trees diffed: `m_noobl`
  is the tree before with `hiddenGap` false, `m_tie0` with `TIE` 0): the tie rule alone moves d on 839 both ways (r2 →
  no oblique merge; `TIE` 0 → the tree), fullers 560, wedges in guards 107, plate edges 57, grilles 36, cylinder ribs 29,
  rods 26, bevels 24; the played tier on 53 (fullers 47, bevels 6), the raw tier alone on 30, at most 0.3932; with the
  slanted merge (r2 → the tree) 853, the 14 more ribbed bars. `fcmp` (V2's) on fix round 2's fixtures: 61 moved, 8 by
  D1 or D2, 53 in Thinness' last digits (fixer D wrote 52).
- *G2, the goldens and the checkpoints*: `difficulty_{calibration, regression, cost}.bv1` 42,408, 84,793 and 24,405
  bytes, the digest 130, each the tree before's to the byte; `ckcount` F2 100, F5 112, P5 237, P1 1,252 on the tree and
  the tree before (fix round 1's tree: P5 236).
- *G2, the slowest valid design* (`timing`, alternating with fix round 1's tree `m3-r2-base`, where its 53.4 ms was
  measured quiet; a collection before each run): 41 rounds, 20–64 % busy (median 34 %), × 0.996–1.049, sum × 1.018,
  worst valid 8 × 1.0246 → 54.71 ms; 41 rounds, the order swapped, 9–33 % (median 13 %), × 1.003–1.047, sum × 1.024,
  worst valid 8 × 1.0312 → 55.07. With fixer F's 53.6 and 54.3 (through fix round 2's 54.8), 53.6–55.1: about 55, about
  5 under `ANALYSIS_LUNE_MAX_MS`. Absolute medians in those runs: worst valid 8 61.3–66.2 ms, P1 33.1–36.0.
- *G2, the order* (`--list`): 744 cases, T-PERF-01 the 609th (608 before it, 135 after).
- `--quick --filter` Physics/Invariance 16 pass, Physics/Edge 26, Physics/Factors 23, 0 fail, after the comments. Every
  table row of SPEC.md and SPEC-evidence.md keeps its header's pipe count (`tablecheck.py`); 92 **[Decision to
  confirm]** marks, each with its Q or O number but the conventions line.
- The last `scripts/verify` (22:41:16–22:47:24, the machine 24–79 % busy, median 42 %, sampled every 5 s): tools,
  sourcemaps, T-META-07 (141 files, 985 requires) and luau-lsp's two passes clean, then 743 pass, 1 fail, TESTS FAILED
  (367.6 s), exit 1: T-PERF-01, worst valid 5 at 63.89 ms over `ANALYSIS_LUNE_MAX_MS` 60; every functional case
  passes. T-PERF-01 alone right after (22:47:39–22:48:41, 24–65 %, median 34 %): F4's longest stretch 0.398 ms over
  0.35. Docs only changed after it (§14.11, §17.2's checkpoint row, E-S2.13's cost bullet and these notes: the runs'
  lines).

**Open issues**

- For the lead: O10's mouth, **[Decision to confirm]** (§17.1 O10). The default is the mouth as built (i): a tier on
  F5's blade turned 45° and split (0.1765 → 0.2068, 0.0235 of it the mouth's), and at 30° the edge's rim columns. The
  exact closure (ii) needs the gap's lateral bound per chord end and its end tests alone cost about a fifth of the
  slowest design's time (× 1.198, past `ANALYSIS_LUNE_MAX_MS`); it would move 96 plausible designs, 2 a tier, ribbed
  bars Hard → Normal, where a rib's face hidden by its rod ends a chord the same way. Convergence: the mouth is the
  same family as O11's re-cuts (sampled lines through parts are not the solid's outline), which the lead's rule puts to
  the designer as O11 (iii) if round 4 finds a new class.
- For the lead: the three and four plates' 0.01 tolerance in T-DIF-04 is the plates' grids, not mouths (fixer F's text
  and V2's said mouths); the test is right, its comment and the SPEC now say why.
- T-PERF-01 has not run on a quiet machine on this tree; the last `scripts/verify` (above) ran under load and failed
  only there, so the lead's quiet verify and S-PAR-02's Studio runs are still needed before the commit (the digest did
  not move this round).
- My scripts and trees are in the session's Temp scratch, `m3-fix3g`, which loses week-old files: the numbers are here
  and in E-S2.13.

**Deviations from the plan and the SPEC**

- G1 (ii): the lead asked for the closure described, and measured only if exact and cheap. I built it as a measuring
  tool (`var/close1`, exact on flat faces) to split the mouth's share from the pieces' grids, and its floor
  (`var/close0`) to cost it: it is not cheap, so it is described in O10 with those figures and not proposed.
- G1 (iii): O11's grid closes the re-cuts and their seams; the text says it closes a mouth only where its lines read
  the solid's outline with the hidden gaps filled, which needs the same lateral bound: a line through a mouth leaves
  the parts whatever grid it starts from.
- G1: V2's "gap's own share about 0.04" (two plates at 45°, against the solid of their outline) is 0.024 against the
  closure; the rest was the solid's own grid as its thickness changed. The SPEC quotes the closure's figures.
- G2: the projection is about 55 ms (my direct runs against fix round 1's tree, 54.7–55.1), where fixer F's chain gave
  53.6–54.3; the SPEC quotes about 55 and about 5 of headroom.
- Beyond the listed sections: §4.9 (case count, O7's figures), §5.5's introduction, §5.6's CPU row, §16.10's
  `VERDICT_WORK_MAX` row, §17.2's ties, 2 % rule, invisible construction and verdict-cost rows, `Invariance.spec`'s and
  `Perf.spec`'s comments, fixer F's three-plate note.

## Fix round 4, fixer H: the set withdrawn

The lead's items H1–H3 of `.build-notes/m3/m3_journal_r4.txt`, on V1's round-4 major (the set rule merges visible air:
`m3_v1_adversary_r4.json`) and the tests and text it leaves (`m3_v2_numbers_and_text_r4.json` for the mutants); fixer I
writes O11's structural entry and the round's other minors after this. The tree before the round is the Temp scratch
`m3-r4-base` (fixer G's), the tree before fix round 3 `m3-r3-base`. Measured with Lune 0.8.9 through `Analyze.run` and
Edge's and Factors' own calls (the 0.8.9 binary itself, one process a run, at most 4 at once); the scripts are in the
Temp scratch `m3-fix4h/work` (`lib`, fixer F's with the trees `repo`, `r3`, `r4`, `fixB`, `fixB2`; `dump`, `cmp.py`,
`fcmp.py`, `tiers.py` and `tablecheck.py` (V2's); `slotsword`, `slotchord` and `railslot` (V1's); `joinscan`, `sweep`,
`neighbours`, `linesweep` and `seam` (fixer F's); `curved`, `seamfig`, `veechord`, `floorslot`, `mh3`, `hreach`,
`timing3`; the edit scripts), the trees in `m3-fix4h/var` (`Hlog`, this round's with a join log; `r4T`, the tree before
with this round's specs; `mutA`–`mutC`, full copies for the mutants; `null`, a byte copy for the timing), the mutants in
`m3-fix4h/mut`, with a step-by-step `NOTES.md`. The machine was 2–60 % busy with programs not mine; every timing below
says its load.

**What was built**

- `src/shared/Physics/Edge.luau`: `held(q, x, y, z)` (a unit its box test, a unit its sd) and `hiddenGap(p, e, q, f)`
  without a set: the gap across from p's normal first, (f − e)·n_p at most `REACH` (an exact pre-test: p holding f's
  probe implies it, so a far chord ends at one query); e's probe asked of q; f's normal; f's probe asked of p.
  `mergeSorted` back to fix round 2's signature, the raster passing no set. The bound at f is gone: q holding e's probe
  implies it (q lies behind its face's plane at f, so (f − e)·n_q ≥ −`HIDE_OFFSET` − `EPS_GEOM` > −`REACH`), so it could
  fire only where a third part held e's probe, which the set allowed (V2's `nobound2` and its loosened twin survived the
  suite as equivalent mutants). The header: the function list, the Raster paragraph, the Hidden gaps paragraph (the
  pair; why the air it merges is the gap's own, flat and round; the set tried and withdrawn, with the slot; the seam
  beside a slanted crossing as §17.1 O11's residual), the Work paragraph.
- `src/shared/Physics/Factors.luau`: `unionChord`'s two calls without the list as a set; its comment and the Thinness
  paragraph (each face's probe asked of the part across; the seam; the set withdrawn).
- Tests (each new or changed case passes on the tree and fails on its mutant or on the tree before, `NOTES.md` steps 5
  and 6):
  - `Edge.spec`: "asked of the set" becomes "asked of the part across alone": the 45° seam at 0.0105 and at the window's
    edge (0.01200005) not hidden, the probe in the piece beside, 2 queries; fixer F's V not hidden in its four forms.
    New: V1's open slot (`slot`: the closed channel and the slot 0.15 long, not hidden; `slotSword`, F5 with the slot
    over its blade, one chain of 6.0851 through `edgeOf`, which fails on the tree before with 2); V1's MH1 case (the
    window's edge against a face along the world axes, its cut-plate half now the pair's "not hidden"); V1's MH6 case (a
    chord inside the run does not ask); a case for faces that are not parallel (f's probe along f's own face's normal,
    where q's other face lies nearer e; a probe 1.5·`EPS_GEOM` short of `HIDE_OFFSET`: shown), which kills MH3 and my
    Hreach. The header, the V's helper comment, the raster runs' comment (with the set, parallel plates had answered
    alike).
  - `Factors.spec`: the union chord's case keeps its three plates; the piece beside a flush seam now leaves the lower
    plate's chord, and a V whose faces a third plate hides leaves p's chord (0.030463; the tree before reads 0.120926).
    New: V1's open slot through the union chord, the closed channel and the slot both B and p alone (the tree before:
    0.2905 for the slot). The charges by caller unchanged. The header.
  - `Invariance.spec`: the seamed laminate pins §17.1 O11's residual against the same pieces at 0.0100: 3 seams 0.0105
    apart Hammering 0.3095 Hard, Thinness 0.74572, the mean thickness 0.05779, against 0.1734 Normal, 0.40514 and
    0.05933; one seam 0.0119 apart 0.2104 Hard, 0.49866, 0.05740, against 0.1337 Normal, 0.30620. The header.
- Nothing re-blessed: no fixture, generated design, golden or digest value moved.
- SPEC: §0.5's row, §4.6 row 1, §5's promise (O11's bullet), §5.2 (τ and the paragraph), §5.5's introduction, §5.6's
  laminates row, §14.6 T-DIF-04 and T-EDG-01, §17.1 O10's clause and O11's seam passage (the set, B and B2, costed).
  Evidence E-S2.13: the introduction, the goldens' sentence, fixer F's bullet marked withdrawn, a fix round 4 bullet.
  These notes: fixer F's section marked withdrawn, this section, `m3-fix4h` in the evidence list.

**Measured**

- *H1, bit for bit* (`dump`, V2's, on the tree): the 136 Parity fixtures and the 200 generated designs byte for byte
  V2's round-4 dumps of the tree before fix round 3 (`fx_r3`, `gen_r3`), and the 33,389 plausible designs byte for byte
  V2's round-3 dump of that tree (`m3-v2-3/out/pl_repo.txt`, 3 processes, 166–297 s); against fix round 3's tree exactly
  V1's 10 ribbed bars move back (`cmp.py`). Run again after the bound at f went: the same, byte for byte. `--quick`
  passed Factors' charges by caller unchanged (4,921, 5,644, 14,848, 8,351) and the raster's charge case: on F5, F4 and
  P5 the set's loop had never charged a unit.
- *The slot sword* (`slotsword`, V1's design: beta 3, s 0.0119, c 0.15, the column 0.0087, 0.4 long, bridges 0.025 ×
  0.04 at +0.036 and −0.047): the tree and the tree before fix round 3, 0.0318 / 0.1573 / 0.2728 Hard, one chain of
  6.0851 (the mean thickness 0.06275, cutIndex 0.7849); fix round 3's, 0.0720 Normal, 3.0433 in 2 chains (0.06686,
  0.7243). `slotchord`: 0.0421 (2 queries; 0 on the tree before, its free pre-test), against 0.2905 (11).
- *Fixer F's checks*: `joinscan` on `Hlog`: fixtures 17 joins on 5 designs, generated none, plausible 725 on 32 designs,
  every one by the pair, facing (n_p·n_q ≤ −0.5) and sandwiched at 9 points (fix round 3's: 1,026 on 50, 301 by another
  part, 40 not sandwiched on 4: gone). `sweep` Y and X (84 designs), `neighbours` (55) and `linesweep` (120 cases,
  1,152,000 lines) against the tree before fix round 3: 0 rows, 0 designs, 0 lines differ. P3's channel: its dump, and
  its specks', byte for byte.
- *Curved faces* (`curved`: two parts, p below and q above, their nearest points g apart on Z; lines through a 17 × 17
  grid in the gap at g/2, at 12 elevations 0.5–80° and 16 headings; for each merged line, 39 points: w, the Euclidean
  distances to p and q summed, and the verdict at each part's face point nearest to the point, its probe along the
  direction to the point): plate/Ball, plate/Cylinder side, Ball/plate, Cylinder/plate, Ball/Ball, Cylinder/Cylinder
  parallel, crossed and 30° skew, Ball/Cylinder and Cylinder/Ball at 0.05 and 0.2 across, plates tilted 5°, 15°, 30° and
  60°, a Cylinder's cap: 25 configurations × g 0.001, 0.004, 0.008, 0.010, 0.0115, 0.0119, 0.0120, 0.01205, 0.0121,
  0.0125: 13,872,000 lines, 2,876,754 past `MERGE_GAP` along, 179,928 merged, none with w past `MERGE_GAP` (at most
  0.0120), none beside a face the verdict shows, none from 0.01205 across. So on round faces too the pair merges only
  air within the window between two hidden faces; the plane argument (each point of e → f within `MERGE_GAP` of the two
  faces' planes summed: t·(f − e)·n_p + (1 − t)·(e − f)·n_q, each term at most `HIDE_OFFSET` + `EPS_GEOM` by the other
  probe) holds for any convex parts.
- *A thin partner* (`curved` plate/thinwedge: a Wedge 0.014 thick tapering to nothing over 0.1, its flat face g over a
  plate): 1,139, 1,615 and 1,751 merged lines at g 0.002, 0.004 and 0.008 pass a plate face that the verdict shows
  because its probe passes through the thin Wedge; w at most g, metal on both sides. §17.1 O10's thin partner, which the
  plain merge across the same gap along its normal reads alike: no new class.
- *The seam, re-measured* (`seam` v1 on the tree before fix round 3, the tree and fix round 3's; `seamfig`, Invariance's
  own construction): 30°, 0.0105: one seam (at 0.015) 0.2186 Hard (0.1733 at 0.0100), 3 seams 0.3095 Hard (Thinness
  0.7457, the mean thickness 0.05779, cutIndex 0.7586) against 0.1734 (0.4051, 0.05933, 0.7338), both plates cut 0.3322
  Hard (0.2102), a lower-plate seam 0.1742 (0.1263); 0.0119, one seam (at −0.035) 0.2104 Hard (0.1337); the tree the
  tree before's on every row; fix round 3's 0.1734 / 0.1734 / 0.2102 / 0.1264 / 0.1343. `seam` s45: 48 of 49 single
  seams Hard (up to 0.2513), each the tree before's; the whole laminate 0.1994 at 0.0105, 0.1765 at 0.005.
- *Two flush pieces of one layer* (`floorslot`: V1's slot with a floor under it, its top in p's top plane, cut flush at
  the u of each of the sandwich checks' points, n = ceil(|f − e|/`REACH`), so each point over the slot lies over a seam,
  the two pieces within `REACH`, both below the line): `fixB` merges the slot 0.15 long at s 0.0119 (14 pieces; the line
  up to 0.0094 over the floor) and a slot 0.05 long at s 0.0119 and 0.005 (5 pieces); `fixB2` merges the two 0.05 slots
  (the line within 0.0042 of the floor: two distances summing under `REACH`) but not the 0.15 one (0.0094 over it); fix
  round 3's tree merges all six designs with or without the floor, the tree none. So both checks count two pieces of one
  layer beside a point as a sandwich: the lead's suspicion holds.
- *Cost* (`timing3`: three trees alternating in one process in a rotating order, a collection before each run, worst
  valid 1–11 and P1, medians of 31 rounds): the tree, the tree before fix round 3 and fix round 3's at 2–10 % busy
  (in-script; 3–18 % sampled every 5 s): the tree × 1.0003–1.0240 of the tree before fix round 3 (sum × 1.0090, worst
  valid 8 × 1.0088) and × 0.988–1.017 of fix round 3's (sum × 1.0065, × 1.0087); the tree before fix round 3, the tree
  and a byte copy of the tree at 2–19 %: the tree × 1.005 and the copy × 1.0075 of the tree before on the sums, worst
  valid 8 × 1.011 and × 1.001: within the noise. Medians there: worst valid 8 58.4–59.4 ms, P1 31.1–31.4 (three trees in
  one heap). T-PERF-01 alone at 00:58 (9–18 % busy): worst valid 8 at 60.06 ms, 0.06 over `ANALYSIS_LUNE_MAX_MS` (fix
  round 3's tree, M3's review round 4: 61.10 ms at 3–17 %).
- *H2, the mutants* (`mut/mutants.py`, `drive.py`: each on a full copy, the whole `--quick`): the round-4 mutants that
  still apply, re-expressed on this code (V1's MH1, MH3, MH6, MH11, MF1; V2's noq, qeps0, nobound1, nobound2, reach,
  boundloose and its twin at f, nucheap, nunormal, edgelast, edgelastnew, ownsort) and mine (an uncharged box test or
  sd, either probe never asked, f's probe asked of q, the raster or the union chord without hidden joins, e's probe
  `REACH` out): 21 of 25 killed at once; MH3 and Hreach survived until the non-parallel case, which kills both (Edge
  30/1 each); nobound2 and its twin were equivalent, the bound at f dead, and went with it. V1's MH2, MH12, MH15, MR1
  and V2's set mutants (setbox0 among them) no longer apply: there is no set.
- *On the tree before* (`var/r4T`: fix round 3's code with this round's specs): Edge.spec fails the slot sword (2
  chains), Factors.spec the piece beside (0.0827 against 0.0339) and the open slot (0.2905 against 0.0421 with c = 0),
  Invariance.spec the seamed laminate (0.1734 against 0.3095); `veechord`: the V's union chord 0.120926 there, 0.030463
  here.
- `--quick` on the tree: 707 pass, 0 fail, 42 skip, 31.1 s (16–48 % busy), five cases more than fix round 3's 702.
- The last `scripts/verify` (01:09:52–01:15:07, the machine 3–32 % busy, median 14 %, sampled every 5 s): tools,
  sourcemaps, T-META-07 (141 files, 985 requires) and luau-lsp's two passes clean, then 749 pass, 0 fail, VERIFY GREEN
  (309.8 s), exit 0: T-PERF-01 passed, the slowest valid design worst valid 9 at 59.31 ms and the F, C and X fixtures'
  longest stretch 0.274 ms (C01). Docs only changed after it (this section's verify line and open issue, E-S2.13's cost
  sentence).

**Open issues**

- For fixer I: O11's structural entry (H4) and the round's other minors (H5) are untouched: §4.1's "however slantwise",
  T-EDG-01's "at least 6 queries" (the test asks 3 a covered cell; to re-measure on the pair), E-S2.13's 0.1733 in fixer
  F's bullet, §5.6's mirror clause, O10's lean closure cost, and E-S2.13's attack figures, which were built for the
  set's loop and have no loop to stress now. The seam passage I added to O11 sits before its options for the re-cut.
  (Done: fixer I's section, next.)
- For the lead: on the pair, the residuals of §17.1 O11 stand as named, the seam among them; the sandwich checks B and
  B2 are costed and both pass two flush pieces of one layer beside a point, so neither closes the class.
- For the lead: a partner thinner than `HIDE_OFFSET` there lets the verdict show a face whose gap the merge reads solid,
  slanted or plain alike (§17.1 O10's thin partners).
- T-PERF-01 passed in the last `scripts/verify` (3–32 % busy: worst valid 9 at 59.31 ms, under the 60 ms guard by 0.7)
  and failed alone at 9–18 % (worst valid 8 at 60.06 ms): it sits at the guard. S-PAR-02's Studio runs (the digest
  unchanged) are still needed before the commit.
- My scripts and trees are in the session's Temp scratch, `m3-fix4h`, which loses week-old files: the numbers are here
  and in E-S2.13.

**Deviations from the lead's decisions and the SPEC**

- H1: the bound at f is removed, not kept with the bound at e as fixer F's form had it: without the set it is implied by
  the probe before it and never fires (an equivalent mutant), and the lead asked for what the set leaves dead to go.
  Answers and charges unchanged (dumps byte for byte; the charges' pins pass).
- H2: Edge.spec's open-slot case reads V1's slot sword through `edgeOf`, a raster, since a direct `hiddenGap` call can
  no longer carry a set to fail on the tree before; the V's flip is pinned through Factors' union chord as well as
  directly; Factors' open-slot case pins the closed channel (c = 0) open too, the seam residual, where V1's case merged
  it with the set; V1's MH1 case keeps its first half, its cut-plate half flipped to the pair's answer; V2's setbox0
  case is not added (no set). The case for MH3 and Hreach is beyond the lead's list.
- H3: E-S2.13's fix-round-3 bullet stays as the record, marked withdrawn, its rule's statements in the past tense; §14.6
  T-DIF-04 drops fixer G's clause on the seamed laminate's mouths (0.4051 and 0.4053 at both gaps), which the pinned
  residual no longer compares.

## Fix round 4, fixer I: O11's structural question, the minors and the text

The lead's items I1–I3 of `.build-notes/m3/m3_journal_r4.txt` (the round's H4 and H5): the designer's structural
question in §17.1 O11, the round's minors that still hold after fixer H (`m3_v1_adversary_r4.json`,
`m3_v2_numbers_and_text_r4.json`), and §0.5, §5's promise and §17.1 read as a whole. No module's behaviour changed:
SPEC.md, SPEC-evidence.md, README.md and these notes only. Measured with Lune 0.8.9 through `Analyze.run` and Edge's and
Factors' own calls on the live tree (fixer H's, its code unchanged since; the 0.8.9 binary itself, one process a run, at
most 3 at once); the scripts are in the Temp scratch `m3-fix4i/work` (`lib`, fixer H's with the trees `repo`, `r3`,
`r4`, `close0` and `close0L` (fixer G's and V2's end-test floors on fix round 3's tree); V1's `hollow`, `write4` and
`write4b` (two 30° rows added); V2's `mirror`, `rastercharge`, `advab` with `adv`, and `timingN`; fixer H's `seam`;
mine: `phases`, `solidgrid`, and the edits `specedit.py`, `edit_spec_i.py`, `edit_o11.py`, `edit_spec_i2.py`,
`rewrap_o11bullet.py`, `edit_evidence_i.py`, `edit_notes_i.py`), the docs before the round in `m3-fix4i/var`, with a
step-by-step `NOTES.md`. The machine was 5–36 % busy with programs not mine; every timing below says its load.

**What was built**

- No behaviour, no test: nothing re-blessed, no value moved.
- SPEC §17.1 O11 (I1) opens with the structural question in plain words: Thinness and the edge read each part's own
  chords and join them by rules, and M2's samples lie on each part as written, so invisible constructions move G. Then
  every class the SPEC states, each with its largest measured figure, the design that shows it and where it is stated:
  (a) a slanted slit's mouth, (b) a seam beside a slanted crossing, (c) aimed re-cuts, (d) Wedge re-cuts, (e) thin
  partners in flush contact, (f) the empty sealed cavity, (g) a hidden gap's volume in SurfaceComplexity, (h) face ties
  exactly `TIE` off, (i) a part's writing (round parts, Wedges, a Block straddling a hiding boundary), (j) round parts'
  sampled overlaps; the 2 % rule's own classes left to O10. Then (iii), a measure that follows the solid: what it would
  close ((a)–(d)), what it would leave ((e)–(j), Asymmetry's share), what it would move (§5.5's fixtures, estimated) and
  cost (from the edge's raster as measured). The row's record follows as it was (θ, the walk, ties, the re-cut corpus,
  the ways out tried, the seam's tried rules, (ii) for the re-cut), its old (iii) for the re-cut replaced by the new
  one; the question ends **[Decision to confirm]** (§17.1 O11), the default as built.
- SPEC elsewhere: §0.5's row (a Block's writing, the empty cavity, the pointer to O11's question); §4.1 ("from one part
  to the next however slantwise", a slit's mouth and a seam beside the crossing aside); §4.6 row 1 (the laminate is one
  solid but beside a flush seam); §5's promise (the empty cavity under O10, a Block's writing under O11, a closing
  paragraph pointing to O11's question with its mark); §5.2 (a Block's writing; the merge sentence: each face's probe in
  the part across); §5.6 (the mirror clause gains Thinness' walk, the laminates row "the gaps", not "every gap", the Y/Z
  row as T-DIF-07 (d) tests it and the Block straddling a boundary, the sealed-cavity row, the CPU row's set); §14.6
  T-DIF-07 (d) (what it does not cover) and T-EDG-01 (the charges as the test asserts them, 8.40 measured); §14.11 (this
  round's runs); §17.1 O8 (its option unmeasured), O10 (the empty cavity; "each by the part across"; the closure's end
  tests written lean; (iii) as O11's, needing no lateral bound where the outline is square to the gap; the accept
  column's tenth); §17.2's 2 % rule row (the empty cavity; a seam beside the crossing) and invisible-construction row (a
  Block's writing). Every table row keeps its pipe count.
- Evidence E-S2.13: the introduction (fix round 2's rule "each by the part across"; fixer I's sentence), the fix round 2
  bullet (the same), fixer F's withdrawn bullet (0.1734, not 0.1733; fix round 2's projection, not a quiet run; its
  attacks never walked the set), a bullet *Fix round 4: O11's structural question and the round's minors*, the mouth's
  bullet (the end tests written lean), the cost bullet (this round's T-PERF-01 runs).
- README's Status: O11 named as the structural question.
- These notes: this section; fixer H's open issue for fixer I marked done; `m3-fix4i` in the evidence list.

**Measured**

- *I2, the empty sealed cavity* (V1's `hollow` on the tree): F5's blade as a sealed box, walls and end caps 0.03 wide at
  its full thickness, plates over a cavity c thick, every part kept: c 0.0100 / 0.0119 Hammering 0.1035 / 0.1051 Normal
  (Sharpening 0.1914 / 0.2036 Hard, the cavity's volume out of SurfaceComplexity's V); c 0.0121 / 0.013 / 0.018 0.5355 /
  0.5368 / 0.5433 Hard (Thinness on All 0.2588 → 0.8702, cutIndex 0.7242 → 0.8810 / 0.8948 / 0.9785, Sharpening 0.2989,
  EdgeLength 5.4330 throughout): V1's figures. F5 solid 0.0288 / 0.1037 / 0.0989.
- *I2, a Block's writing* (V1's `write4` and `write4b`, two 30° rows added): every F and C fixture ΔG 0; F5's laminate,
  upper plate in 3 flush seams, at 0.0105: turned 30° ΔG 0.0005 (Sharpening 0.2008 → 0.2003, SurfaceComplexity on the
  Blade 2.442958 → 2.441603), at 0.0100 0.0004 (0.1973 → 0.1969), flat 0.0002 (0.1437 → 0.1439); one Block at a time,
  F5's tip (the design's part 4) carries it all; 5 symmetric seams, the 0.4-wide laminate and the flush one: 0. So
  T-DIF-07 (d)'s cases hold, and "a Block in any of its 24 writings" (§5.6, O11) was wider than the test: restated as
  tested.
- *I2, the X mirror* (fixer C's `mirror`, V2's copy): F1–F5 and C01–C15 the same; 150 Prop designs ΔD up to 0.0621
  (#24), EdgeLength 0.371 % (#132), no flip: V2's figures; §5.6's mirror clause states it with E-S2.13's cause.
- *I2, T-EDG-01's charges* (V2's `rastercharge`): three plates turned 30°, 0.0105 against 0.0100 apart: +10,920 units
  over 1,300 covered cells, 8.40 a cell (mean thickness 0.066125 against 0.065201); the same on fix round 3's tree. The
  test asserts at least 3 a covered cell (6 × cells / 2); a merged gap's test makes 6 queries (two normals, two box
  tests, two sds).
- *I2, E-S2.13's 0.1733* (fixer H's `seam` on fix round 3's tree and the tree): there the one-seam laminate read 0.1734
  at 0.0105 (0.1733 is its pieces at 0.0100); the tree reads r3's 0.2186 / 0.3095 / 0.3322 / 0.1742 / 0.2104.
- *I2, the attacks at the window's edge* (V2's `advab`, the tree against fix round 3's, 9 rounds, 6–7 % busy, 01:30):
  0.01200015 across, 12 plates turned 30° 27.52 ms against 31.12 (× 1.131 for the set), turned 60° 24.14 against 26.41,
  21 plates 24.66 against 25.75; at 0.0105 29.85 against 29.48, 24.59 / 24.78, 26.18 / 26.40; zigzags 22.97–24.06
  against 22.88–25.50; longest stretches 0.17–0.26 ms; worst valid 8 59.38 / 59.04. The same d on both trees but one
  zigzag's Hammering (0.5733 the pair, 0.5911 the set).
- *I2, O10's closure cost* (V2's `timingN`: fix round 3's tree, its lean end tests `close0L`, fixer G's `close0`, the
  tree; 31 rounds, 01:32–01:34, 5 / 13 / 8 % busy in the script, 6–36 % sampled, median 14 %): `close0L` × 1.012–1.091
  of its tree (sum × 1.055, worst valid 8 × 1.070), `close0` × 1.027–1.179 (× 1.112, × 1.160), the tree × 0.981–1.017 (×
  0.997, × 0.991). With V2's two runs (× 1.085 and × 1.117): the lean end tests cost about a tenth of the slowest
  design's time (55 ms × 1.07–1.12, about 59–61), fixer G's form about a fifth.
- *I1, the raster's cost* (`phases`, 15 rounds, a collection before each, 01:30, 6–8 % busy in the script, 8–29 %
  sampled): `Edge.profile` as built 0.43–3.47 ms on F1–F5 and C01–C15 (C05), 0.89–3.84 on P1–P5, 2.23–6.74 on the worst
  valid designs (worst valid 9; 8: 5.49), its chosen rung 1,386–6,705 cells and 19,849–28,865 cell × part tests,
  451–2,707 covered; every kept part relabelled Blade, All's union: 0.89–3.98, 1.67–7.55, 2.67–11.70 (worst valid 8
  9.65); `Factors.thinness` on All 0.92–2.68 ms on the fixtures (273–395 probes) and 0.82–6.99 on the worst valid
  designs (wv9; wv8 6.10, 400 probes), on the Blade 0.37–1.09 and 0.78–4.74; `Factors.measure` on All up to 8.43, on the
  Blade up to 6.05; `Analyze.run` 4.12–16.10, 7.88–32.31 and 25.23–58.50 in the same runs.
- *I1, what (iii)'s grid would move* (`solidgrid`, an estimate: Thinness at a probe in each covered cell's metal run of
  the edge's grid, 0.02 cells, x from the plane x = 0, y from the set's lowest point, read 0.0013 / 0.0017 off the
  centre; the run's middle, weighted by length × cell area, owned by the highest-ranked part holding it, Balls and
  Cylinders moved as Thinness moves them; τ through `Factors.unionChord` along Z and the owner's θ; every covered run a
  probe, 1,170–7,687, where (iii) would stride to 400): F1–F5 and C01–C15, max \|Δd\| 0.0425 (C09's Hammering 0.3201 →
  0.3626, Thinness on All 0.3935 → 0.4998), C13 0.0091, C07 0.0054, C02, C12 and C14 0.0039, C08 0.0034, F3 0.0030, C06
  0.0028, C15 0.0024, the rest ≤ 0.0011, Smelting and Sharpening 0 (no Thinness weight), no tier; C02's highest step
  0.1318 and F5's 0.1039 unmoved. Fixer D's `recutaim` design (V1's aimed plate, overhanging by 0.05): −X 0.1075 /
  0.2141 / 0.3254 and +X 0.1253 / 0.0008 / 0.0008 as built (1 / 6 / 11 pieces), 0.1271 in all six on the grid.
- *I3*: 88 **[Decision to confirm]** marks in SPEC.md (two more: §5's promise and O11), each with its Q or O number but
  the conventions line and two whose Q stands just before or after them (Q2's and Q11's, unchanged); O1–O11 all exist;
  `tablecheck` 0 rows off in SPEC.md, SPEC-evidence.md and these notes. A scan for "hides both faces", "every gap the
  verdict hides", "however slantwise" and "one solid" finds every merge statement qualified by the part across, the seam
  or the mouth.
- The last `scripts/verify` (01:51:48–01:57:09, the machine 2–27 % busy, median 8 %, sampled every 5 s; no other Lune
  process): tools, sourcemaps, T-META-07 (141 files, 985 requires) and luau-lsp's two passes clean, then 749 pass, 0
  fail, 0 skip (62 files, 308.78 s), VERIFY GREEN (314.8 s), exit 0: T-PERF-01 passed, the slowest valid design worst
  valid 8 at 57.52 ms and the F, C and X fixtures' longest stretch 0.270 ms (C01). Docs only changed after it (this
  line, E-S2.13's cost sentence and §14.11's runs; during it, O11's wording and §17.2's checkpoint row).

**Open issues**

- For the lead: O11's structural question **[Decision to confirm]** (§17.1 O11). The default is as built (i). Option
  (iii), a measure that follows the solid, would close the mouth, the seam and the re-cuts together (Thinness' share;
  Asymmetry's needs its own reading of the raster), for about 4–12 ms more on the slowest designs (about 59–67 ms
  against the 57 ms gate) and new goldens; it would leave the thin partner, the empty cavity, a hidden gap's volume, the
  `TIE` boundary, M2's samples of a part's writing and of round overlaps, and it reads air narrower than the window
  across as metal where the verdict may show a face beside it (a V's narrow end). Its §5.5 figures are an estimate of
  its grid alone, through today's chords; its fill is described, not built.
- T-PERF-01 passed in my `scripts/verify` (2–27 % busy, worst valid 8 at 57.52 ms) but sits near the guard under load
  (60.06 ms alone at 9–18 %, fixer H); the lead's quiet `scripts/verify` and S-PAR-02's Studio runs (the digest
  unchanged since fix round 2) are still needed before the commit.
- My scripts and the docs' before-copies are in the session's Temp scratch, `m3-fix4i`, which loses week-old files: the
  numbers are here and in E-S2.13.

**Deviations from the lead's decisions and the SPEC**

- I1: (iii) is written as a column raster of the union, its chords exact and its gaps filled by a two-sided test of the
  solid along the face's normal at points `MERGE_GAP`/2 apart, the voxel raster costed only beside it: a voxel raster
  fine enough for the window costs about 11 × the edge's raster on its own, past the budget, where exact chords on the
  edge's grid need no finer cells. The fill needs no lateral bound where the outline is square to the gap, which O10's
  (iii) now says (fixer G's text said it took (ii)'s bound).
- I1: "no prototype needed": I built none of (iii); `solidgrid` estimates what its grid moves through today's chords (on
  the §5.5 fixtures no chord crosses a slanted gap, seam or mouth, so the fill would change nothing there).
- I1: the class list adds (g), a hidden gap's volume in SurfaceComplexity (O10's, a tier on C02 split 0.0119 apart),
  which the lead's list did not name, and points (j), round overlaps, to §5's promise and T-DIF-07 (a), with O9's band
  beside them: O9 itself does not state the overlaps.
- I2: E-S2.13's attack figures are kept as fixer F's record, said never to have walked the set; the pair's cost at the
  window's edge is measured and stated in the new bullet (V2's `advab` against fix round 3's tree).
- I3, beyond the listed minors: §5.2's merge sentence, §4.6's laminate sentence, §5.6's "every gap", §17.2's 2 % row,
  O10's "hides both faces" and E-S2.13's introduction and fix round 2 bullet now say the part across holds the probe or
  name the seam, so no statement reads as merging it; O8's option is stated as unmeasured; fixer F's "54.8 ms quiet" (a
  projection, V2's slip) is corrected; §5's promise's O11 bullet re-wrapped whole (two short lines from earlier edits).

## Fix round 5, the minors' fixer: the reviewers' minors

M3's review round 5 found no blocker or major; its minors came to this round: V1's four (two sets of mutants that pass
`--quick`, a shift on the plausible set, a part flush at a slanted gap) and V2's three (`fprobereach`, which is V1's
R5p1, two stale case counts, O10's closure cost written lean). Each was checked against the code on the live tree before
acting. No module's behaviour changed: tests, comments, SPEC.md, SPEC-evidence.md and these notes. Measured with Lune
0.8.9 through `Analyze.run`, `Sampling` and Edge's and Factors' own calls on a byte copy of the live tree (the 0.8.9
binary itself, one process a run, at most 4 at once); the scripts are in the Temp scratch `m3-fix5m/work` (V1's `libT`,
`dump`, `dumpshift`, `shiftcmp.py`, `zown`, `zvol`, `zexp`, `flushrib_lib`, `flushrib`, `flushscan`; V2's
`tablecheck.py`; mine: `dumps3.sh`, `rankcmp`, `rankjoin.py`, `expdiag`, `explog`, `czrank.sh`, `flushtilt`,
`verify.sh`, `widths.py`, `edit_spec_m.py`), the trees in `m3-fix5m/var` (`repo`, the live tree's byte copy; `mut`, the
live tree with this round's specs; `subwork`, `N_SUB_WORK` × 10,000; `explog`, `Sampling` logging each measured sample;
`czrank`, the measure's rank by z, not \|z\|; `before`, the files before the round), the mutants in `m3-fix5m/mut`, with
a step-by-step `NOTES.md`. The machine was 2–80 % busy with programs not mine; every timing below says its load.

**What was built**

- Tests (each new assertion passes on the tree and fails on its mutant, `mut/mutants.py`):
  - `Edge.spec`, "hidden gaps where the faces are not parallel": the same line asked the other way, from q at f to p at
    e, not hidden (V1's R5p1, V2's `fprobereach`: with the second probe sent `REACH` out, q held it). "Hidden gaps at
    the window's edge": V1's block turned 45° about Z, its lower face at the case's g (0.01200005) over the lower
    plate, e's probe 1.4·`EPS_GEOM` past its box beside its vertical edge and within `EPS_GEOM` by its sd: held (V1's
    R5h1, the box test with `EPS_GEOM` alone, reads it not hidden; the verdict's own test keeps 2·`EPS_GEOM`). The
    case's title, the header.
  - `Factors.spec`, the union chord's three-plate case: V1's upper plate 0.03 apart, the chord from the middle plate
    growing down through the lower one past lo (R5c3: a join past lo skipped where a chord lies past hi); V1's ties,
    flat plates and strips 0.006 wide with their z extents on a line 30° off Z, the plates first merged up from the
    plate under and down from the one over, the strips first not (R5c1, R5c2, R5c6, R5c7: the last of a tie asked).
    Names chosen so that nothing shadows the case's later `r` and `p1`, as V1's draft did. The comment above the case,
    its title, the header.
  - `Perf.spec`'s comment: after 613 of its 749 cases.
- Comments: `Edge.luau`'s Translation paragraph and `Factors.luau`'s Thinness paragraph name the part flush with the
  face a line leaves for a slanted hidden gap (§17.1 O11 (k)).
- SPEC: §0.5's factors row; §4.4's measure rank (a Z shift reorders parts of one volume, y and x, by \|z\|); §4.6 row 1
  (the raster's cells translation-exact, and their thickness but where a part lies flush with the face a line leaves
  for a slanted hidden gap); §4.9's count; §5's promise (its (j) clause widened, (k), the closing paragraph); §5.6's Y/Z
  row (the plausible set moved, (k)); §14.6 T-EDG-01 (the two Edge assertions); §14.11's T-PERF-01 row (the 614th of 749
  cases, this round's verify runs); §17.1 O10 ((ii)'s end tests × 1.00–1.17 written lean and × 1.02–1.24 as fixer G
  wrote them, about 59–64 ms; the accept column's tenth to a sixth); O11 (the opening, (j) rewritten, (k) new, (iii)
  closing (a)–(d) and (k), the question's (a)–(k)). Every table row keeps its pipe count (`tablecheck`), and no line
  passes 120 columns that did not before (`widths.py`).
- Evidence E-S2.13: a bullet *Fix round 5*, and V2's runs in the mouth bullet's cost.
- These notes: this section, `m3-fix5m` in the evidence list. Nothing re-blessed: no value moved.

**Measured**

- *The tests* on the tree: Physics/Edge 31/0, Physics/Factors 28/0; `--quick` 707 pass, 0 fail, 42 skip, 28.3 s (7 %
  busy before it, 9 % after). *The mutants* (`mut/mutants.py`, each applied in turn to `var/mut`, its spec run, the file
  restored): R5h1 and R5p1 Edge 30/1, each at its new assertion ("the turned block holds the probe"; "from q to p: e's
  face shows, not hidden"); R5c1 and R5c7 Factors 27/1 at "the same, down from the plate over" (0.046188 against
  0.081406), R5c2 and R5c6 at "a tie at each end, the plates first" (the same), R5c3 at "the upper plate apart"
  (0.023094 against 0.058312). *The counts* (`--list`): 749 cases, T-PERF-01 the 614th; this round's assertions sit in
  existing cases.
- *A shift on the plausible set* (V1's `dump` and `dumpshift` on designs 22,261–33,389, every part moved, three lanes,
  237–241 s, 13–71 % busy: byte for byte V1's `pl_repo_3`, `pl3_z037` and `pl3_y3317`; `shiftcmp.py`): moved 0.037 down
  Z, 246 leave the hitbox and of the 10,883 still valid G moves on 2,081, 621 past `TOL_G_INVARIANT`, up to 0.0354
  (#32977), 11 a tier, M2's volume on 73; moved 0.3317 along Y, G on 357, 103 past it, up to 0.0363 (#32816), 2 a tier
  (#32923's Smelting 0.1906 Normal → 0.2030 Hard), M2's volume on 698; the raster and the edge beyond 1e-12 on none.
  V1's figures, every one.
- *What moves them.* V1 named M2's sampled ownership and the exposure's boundary ties (§17.2). The first holds; the
  second is not what moves the fuller, nor most designs along Z:
  - `zown` and `zvol`, on this tree and on M2's (`m3-base`): #32977's Guard bars 9–11, each under the 7 Blade blocks,
    own 0.00728875 → 0.00245 (Pommel block 15 0.00588 → 0.003675), M2's volume 0.440571824 → 0.423850574 on both:
    the ownership M2 samples past `MAX_EXACT`.
  - `zexp`, on both trees: #24151's exposed area 5.232950664 → 5.351950664. `expdiag`: its core (part 4, 0.3 × 2.5 ×
    0.02) 0.245 → 0.35875, its cheeks 6 and 9 (0.12 × 2.5 × 0.05, the core's volume) 0.539 → 0.5445 and 0.54025 →
    0.54, sub-sampled patches 241 → 245; with `N_SUB_WORK` × 10,000 (`subwork`) 878 both ways and no part moves.
    `explog` (each measured sample's part, near count and budget left): from the 801st call the parts come in another
    order, the core first as built, the upper cheek first moved. `Sampling.measureRanked` keys on −volume, y, \|x\|, x,
    \|z\|, z, and the core and cheeks share volume, y and x: \|z\| 0 < 0.035 as built, 0.037 > 0.002 moved. So the shift
    reorders the rank, and the sub-grid budget, spent in rank order, runs out at other patches. No reading of a patch
    is a tie here.
  - `rankcmp` (the kept parts' measure-rank order as built and moved; 4 lanes, 110 s) with `rankjoin.py`: along Z the
    order changes on 10,174 of the 11,129 designs, among them 2,027 of the 2,081 whose G moves (1,987 with no owned
    volume moved: 573 past 0.002, 9 tiers, up to 0.0306); the other 54 move an owned volume (39 past, 2 tiers, up to
    0.0354). Along Y it changes on none, and each of the 357 moves an owned volume (348 M2's volume, 9 within 1e-9).
  - `czrank` (the rank by z, not \|z\|, so a Z shift keeps its order; a scratch variant, 4 lanes, 134 s, 13–80 % busy):
    the Z shift moves G on 110 (47 past it, 2 tiers, up to 0.0354, #32977 first), the raster and the edge on none; as
    built it reads 6 of the 11,129 otherwise than the tree (up to 0.0306, #24151; no tier).
- *A part flush with the face a line leaves for a slanted hidden gap* (V1's `flushrib` and `flushscan` on this tree:
  V1's outputs line for line): the ribs flush, the mean thickness 0.063386 as built and 0.064654 at Z −0.037; over 31
  shifts k·0.0013 along Z, 0.063386 at 22 and 0.064654 at 9 (cutIndex 0.6740, 0.6568); over 19 valid k·0.0131 along Y,
  0.063386 at all; steps 0.0260 / 0.1119 / 0.1362, Thinness 0.258665 and EdgeLength 5.449406 in one chain at every
  shift. The ribs' tops 0.001 lower: 0.064654 at every shift, 0.0260 / 0.1121 / 0.1363, Thinness 0.259156. `flushtilt`
  (the whole design turned a further 2° about X, so its parts are not turned about Y alone): Y shifts one mean thickness
  (0.063895), Z shifts 22 (0.063758–0.064376), Hammering 0.1157 and Thinness 0.268243 throughout; at 5° no shift is
  valid. So Z shifts carry it; no Y shift did here.
- *O10's closure cost*: V2's `timing3` and `timing4` (`m3-v2-5/out`), read, not re-run: written lean × 1.0458–1.1675
  (worst valid 8 × 1.1635) and × 1.0187–1.1142 (× 1.1106), fixer G's form × 1.0604–1.2366 (× 1.2161) and × 1.0356–1.1737
  (× 1.1735), 31 rounds each, V2's process alone, 1–28 % busy. With the earlier rounds' runs: lean × 1.00–1.17, worst
  valid 8 × 1.07–1.16, about 59–64 ms from 55; fixer G's × 1.02–1.24.
- The last `scripts/verify` (10:13:15–10:18:16, the machine 0–37 % busy, median 9 %, sampled every 5 s; no other Lune
  process): tools, sourcemaps, T-META-07 (141 files, 985 requires) and luau-lsp's two passes clean, then 749 pass, 0
  fail, 0 skip (62 files, 295.82 s), VERIFY GREEN (301.0 s), exit 0: T-PERF-01 passed, the slowest valid design worst
  valid 9 at 57.55 ms and the F, C and X fixtures' longest stretch 0.277 ms (C01). The run before it (10:07:50–10:12:51,
  3–31 %, median 11 %), on the same tree but `Factors.luau`'s new comment worded otherwise: GREEN, 749 pass, worst
  valid 9 at 57.41 ms, 0.280 ms (C01). Docs only changed after it (this line, §14.11's runs, E-S2.13's cost
  sentence).

**Open issues**

- For the lead: O11 (j) as found here is mostly M2's measure rank, not rounding. On a third of the plausible set a
  0.037 Z shift moves G on 2,081 designs and a tier on 11, where a rank by z alone (scratch) leaves 110 and 2, and as
  built reads only 6 of those 11,129 designs otherwise (no tier). It is a rule change (M2's rank, the verdict owner's;
  the verdict's rank `Sampling.ranked` has the same \|z\| key), so it is stated, not made: **[Decision to confirm]**
  (§17.1 O11), the default as built. The fixtures' goldens and S-PAR-02's digest under such a rank are not measured.
- T-PERF-01 passed in both my `scripts/verify` runs (0–37 % and 3–31 % busy: worst valid 9 at 57.55 and 57.41 ms,
  under the 60 ms guard by about 2.5); the lead's quiet `scripts/verify` and S-PAR-02's Studio runs (the digest
  unchanged since fix round 2) are still needed before the commit.
- My scripts and trees are in the session's Temp scratch, `m3-fix5m`, which loses week-old files: the numbers are here
  and in E-S2.13.

**Deviations from the lead's decisions and the SPEC**

- V1's text named "a face on the hide test's boundary (§17.2's ties)" as (j)'s second mechanism; the measure's rank by
  \|z\| and the sub-grid budget it orders are what move the fuller and most of the 2,081 (`subwork`, `explog`,
  `rankcmp`, `czrank`), so O11 (j), §5's promise, §5.6 and §0.5 say that, and §4.4's rank paragraph says a Z shift
  reorders it.
- O10's range for fixer G's form is widened to × 1.02–1.24 (V2's runs reach × 1.2366 on worst valid 9), beyond V2's
  text, which changed the lean range alone.
- (k) says which shift carries it (Z; no Y shift, also turned 2° about X), beyond V1's text; V1's (k) reads the same
  otherwise.
- V1's and V2's R5p1 tests are one assertion (the same call); V1's R5h1 block takes the case's g for its lower face (V1
  wrote `HIDE_OFFSET` + 0.5·`EPS_GEOM`, the same gap).
- §14.6 T-EDG-01 gains the two Edge assertions; the union chord's unit cases are not listed in §14.6, so nothing there.

## The lead's close-out (2026-11-17)

- Review round 5 passed (V1 and V2, minors only; the minors' fixer above). The lead's own `lune run scripts/verify` on
  the final tree, 10:24–10:29, the machine about 12 % busy: VERIFY GREEN, 749 pass, 0 fail, 295 s of tests; T-PERF-01's
  worst valid designs 22.2–56.5 ms (worst valid 9), the F, C and X fixtures' longest stretch 0.276 ms (C01).
- S-PAR-02 passed in 3 fresh Play sessions of the test place (Project 215 on `rojo serve test.project.json`, port
  34873), `execute_luau` on the snippet's code in datamodel_type "Server", then "Client", each session: fixtures 136
  designs, 425,658 bytes, fnv1a32 60321529 (106 Adversarial drafts dropped by Canonical, as in Lune); generated 200
  designs, 709,366 bytes, 611215233; the 130-byte digest equal to `parity.bv1.digest.txt`; one call held both groups
  (25.2–25.8 s, 1,509–1,543 yields at 4 ms); the console held the `[E2E]` lines alone. The sources' sha1 at the time:
  `ROBLOX/.build-notes/m3/spar02_hashes.txt`.
- Next, before M4: the shift class, §17.1 O11 (j). A whole design moved along Z moves G through M2's measure rank by
  \|z\| (and its sampled overlaps), the same on M2's tree; a whole-design move is invisible in the game, so it is an
  engineering fault to fix on its own (which moves a player can make, then normalising the design's position, a rank on
  the design's own centre or sampling fixed to the design), verified and committed apart, with S-PAR-02 run again if
  the digest moves.

## After M3: the whole-design shift fix, fixer S

The lead's ruling of 2026-11-17 (`.build-notes/shift/shift_journal.txt`, its last entry): §17.1 O11 (j) is an
engineering fault, since a whole design moved along X, Y or Z is invisible in the game, so the census's fix R goes in
with all six guards, guard 2's margin chosen by measurement, the verdict's rank placed from every Grip part and the
measure's from the kept Grip parts; then measure it on every corpus, update the tests and goldens, and leave the SPEC
and evidence text to fixer T. Built on the tree after M3 (`f7ac37d`, the base snapshot `shift-base`), uncommitted. Each
guard was checked against the code first (`shift_frame.json`, `shift_census.json`; the census's variant tree diffed
against its copy of `f7ac37d`). Measured with Lune 0.8.9 through `Analyze.run`, `Sampling` and `MassProps`' own calls on
byte copies of the working tree, at most 4 Lune processes of mine at once; the scripts are in the Temp scratch
`shift-fix-s/work` (the census's `census`, with random moves added, `dumpfull`, with design lists, `mirror`, `timing`,
`csum.py`, `drift.py`, `table.py`; the frame analyst's `idshuffle`; mine: `owncmp`, `ownsum.py`, `candidates.py`,
`realmoves.py`, `ydelta.py`, `driftfam.py`, `attrib3.py`, `mircmp.py`, `goldiff.py`, `mkvar.py`, `sync.sh`, `queue.sh`
and the probes), the trees in `shift-fix-s/var` (`live`, the working tree's byte copy; `vo` and `vop`, guard 2's two
forms; `m1v` … `m6r`, each guard reverted alone, and some of them combined), the outputs in `shift-fix-s/out`, with a
step-by-step `NOTES.md`. The machine was 0–100 % busy with programs not mine while the corpora ran (median 45 %) and
0–22 % for the timings; every timing below says its load.

**What was built**

- Source, the six guards (§4.1's rules kept: + − × ÷ and floor, numeric loops, no state, every sort a strict total
  order with the index last):
  1. *The ranks.* `Sampling.ranked(parts, gripSlot)` and `Sampling.measureRanked(parts, kept, gripSlot)` read where a
     part stands as its height, then |q(c − ref)| before q(c − ref) for x and for z, q(v) = sign(v)·floor(|v|/`RANK_Q`
     + 0.5), `RANK_Q` = 1e-9 (a numeric guard): q is odd, so a mirror image's places are its original's negated. The
     verdict's ref is the point of every part of the grip slot (V4's, known before any verdict), the measure's the
     point of the kept ones (the physics and difficulty frames'), so no cleaned part moves the measure; both are
     `MassProps.gripFrame`'s sums in blueprint order (V4's and the physics frame's point to the bit). With none, the
     origin, as the frames have it: only `measureInvalid` reaches a design with no kept Grip part (A22c), whose measure
     is then placed from the world's centre planes as on `f7ac37d`, and whose reach, guard line and balanceFromHand the
     physics frame reads from the origin, so they move with any shift (below). `Sampling.exposure(parts, gripSlot,
     spend)` ranks the measure once the verdicts are in; `MassProps.ownership(parts, kept, rankOf, gripSlot, spend)`
     and `Analyze.run`'s phase 6 pass the kept flags and the type's grip slot (EquipmentTypes' geometry, no literal).
  2. *Ownership.* `OVERLAP_TOL` 1e-9 → 1e-7 (above GJK's 4e-8 on a round pair), and the box test before GJK at
     −`OVERLAP_TOL`: boxes overlap by `OVERLAP_TOL` on every axis or the pair is not asked, so two parts flush along a
     world axis are never above each other (the sign by measurement, below).
  3. *Overlap cells.* `MassProps`' `CELL_EPS` 1e-9: a box no thicker than it has no cell, else ceil(extent/h − 1e-9).
  4. *Asymmetry's candidates.* `Factors`' `MIRROR_GUARD` 1e-9 widens the mirror candidates' box past reach.
  5. *G's sum.* `Difficulty`'s `X_GRID` 1e9: each x on the 1e-9 grid inside Σ w·x; the stored terms keep x.
  6. *Contact.* `Sampling.CONTACT_REACH` = `CONTACT_TOL` + 1e-9: V3's box test and GJK (`Analyze.run` and the
     editor's `Analyze.quick`), the contact rows' box margin and their d0 test. The measure's ladder and candidates
     keep δ + `CONTACT_TOL` + h.
  The comments say so: `Sampling`'s header and both ranks', `MassProps`' header and guards, `Analyze`'s phase 2,
  `Factors`' Asymmetry paragraph, `Difficulty`'s step.
- Tests:
  - The callers given the grip slot: 120 calls of `exposure` and `ranked` (`"Grip"`, as the frames' tests write it;
    `work/addgrip.py`), the `measureRanked` and `ownership` calls by hand; `DifficultyHelpers` (`measured`,
    `inRankOrder`, its V3 at `CONTACT_REACH`), `PhysicsHelpers` (`measure`; `plantedSampling` plants
    `Definitions/Types`), `Edge.spec`'s inputs and `inRankOrder`, `Reference.spec`'s `inRankOrder` (on the build's kept
    parts), `Analyze.spec`, `Verdict.spec`'s measure-rank case (every part kept).
  - `Invariance.spec`, T-DIF-07 (a) to the bit: `sameSteps` asserts validity, the kept flags, every step's g, m, d,
    tierRaw and tier to the bit, every factor's raw within 1e-12 and cutIndex within 1e-12; the fast Y case, every F
    and C fixture × E-S2.10's offsets (slow) and the Gen corpus, translated and along its Y draw (slow), now hold to
    it, and `yKept` keeps EdgeLength to the bit along Y; `TOL_G_INVARIANT` stays for the re-cuts (b) alone. The header
    says so.
  - The pins, each failing with its guard reverted alone (the mutant trees `var/m*` with the tree's tests), all fast:
    in `Invariance.spec` the ranks (X01's near copies 0.037 along ±Z keep the copy kept: the verdict's rank by |z|
    swapped it; C09 0.0013 along −Z and +Z keeps its steps: the measure's rank by |z|, then the places unquantised,
    moved SurfaceComplexity 0.00105; P5 0.0013 along −X keeps every factor but Asymmetry and EdgeLength: |x| moved its
    Thinness 0.0662), the hidden Grip part (C09 with a Grip block enclosed in its grip off the axis reads C09's steps
    and edge: from every Grip part the measure moved 0.3201 → 0.3196), the flush part (C09's pommel housed in a block,
    moved along Y: at margin 0 ten owned volumes moved), the cells (C09 at the hitbox's Z edges: ceil alone moved three
    owned volumes and Smelting 0.0001 → 0), G's grid (F4 with a plate on its guard, moved along Y: 0.4593 → 0.4592 on
    the sum as measured) and contact (C07 ±0.0013 and C02 with a plate on its guard moved along Y keep Joints: the
    contact rows moved 0.176, V3 1.58); in `MassProps.spec` a bar flush on a blade 0.037 along Z (at margin 0 the moved
    copy took the blade above it), a Ball tangent to a Cylinder at 30° above it however moved (GJK stops 1.2e-8 to
    2.4e-8 above the gap: at 1e-9, never), an extent a hair past 4 cells keeping 4 (80 cells by ceil alone) and a box
    1e-17 thick none (64); in `Factors.spec` Asymmetry's estimate with a block exactly reach under another's mirror
    image, the same at every 0.037 step up Y (at reach alone 800 → 640 at 0.111); in `Difficulty.spec` Volume's x an
    ulp either side of 0.45925 giving one g (0.4593 → 0.4592 as measured). Every one passes on the tree.
  - `Factors.spec`: the units by caller (F5 on All Thinness 4921 → 4715, Asymmetry 11069 → 9746; F4 5644 → 5564,
    19264 → 17849, on the Blade 2208 → 2178, 10069 → 9796; P5 14848 → 14642, 21409 → 20086: a probe or a sample
    charges a unit per higher part, and a flush part is one no more); [8.2] compares Joints on the build's own measure
    on the ten fixtures whose contact rows now take samples at exactly `CONTACT_TOL` (`OWN_CONTACT`) and C04's Volume
    and SurfaceComplexity on its own ownership (`OWN_OVERLAP`).
  - `Reference.spec`: the refined cells of seven fixtures, fewer than the prototype's now that a flush part makes no
    job (`FLUSH_CELLS`: C04 2016 → 1184, C06 1352 → 676, C09 5320 → 4240, F1 676 → 0, F3 1282 → 490, F5 676 → 0, P5
    676 → 0), and C04's mass, volume, balance, balanceFromHand and COM y pinned to the build's own (`OWN_OVERLAP`);
    `Difficulty.spec`'s step case sums each x on the grid; `Perf.spec`'s comment (T-PERF-01 after 622 of 758 cases).
- Goldens re-blessed at `BALANCE_VERSION` 1, as M1–M3's rounds did: §16.18 ties only `GOLDEN`, `SAMPLE_X` and
  `SAMPLE_Y` to it (M2's notes add Cover's units), and §14.9's workflow and §16's `BALANCE_VERSION` row ask a bump of
  outcome-affecting code because it stales stored items, of which none exist before release (M1's pre-release
  re-bless, M2's and M3's rounds alike); §17.2 asks none (S8: S-PAR-02 runs again on the new digest). Every leaf that
  moved (`goldiff.py` against `f7ac37d`'s): T-DIF-12's calibration golden, C04 (balance 0.2387999 → 0.2388022, mass
  0.4150461 → 0.4150382, volume 0.0528178 → 0.0528168, Smelting's and Hammering's SurfaceComplexity 2.4989453 →
  2.4989769, Joints 6.6552 → 6.4792, Volume) and Joints alone on C05, C07, C08, C11 and C13; its regression golden,
  Joints alone on X03, X04b, X04g0.010, X06-0.01 and A24; the Parity digest's fixtures group 425,658 → 425,673 bytes,
  fnv1a32 60321529 → 1001114566 (the generated group 709,366 bytes, 611215233, unchanged) and those 11 fixtures'
  hashes in `parity_designs.bv1`. No g, d or tier moved; the cost golden and every other golden are unchanged. The
  mutants place each move (`dumpfull` per mutant): with the contact rows at `CONTACT_TOL` only C04's ownership is
  left, with the box test at margin 0 only the 11 Joints; no other guard moves a fixture as built.
- These notes: this section, `shift-fix-s` in the evidence list.

**Measured**

- *Guard 2's sign* (`owncmp` on every corpus, the trees `vo` and `vop`, the same verdicts): owned volumes differ on
  10,359 designs (22,146 parts: C04 among the fixtures, DEADBEEF#297 and 2468ACE0#491 among the generated, 10,356
  plausible). Each such part against a reference, exact by inclusion–exclusion where it and its higher parts are
  polyhedra and at most 10 (20,121 parts), otherwise sampled 8 × finer than the finer form's cells on every axis
  (2,019; 6 cleaned parts past 30 million cells left out): `vo` (−`OVERLAP_TOL`) is closer on 9,947 designs, `vop`
  on 271, equal on 141; summed |V_own − reference| 0.391 against 4.873; per part 21,000 / 686 / 454. Where the
  reference is exact `vo` hits it on 19,501 parts (median error 0, `vop`'s 1.3e-4); the sampled ones' medians 1.13e-5
  and 1.38e-5. The fullers (8,352) read exact under `vo` (0 against 2.90 summed), the grilles 0.29 against 1.60;
  `vop` is closer on 133 wrapRings, 37 plate edges and 20 housed pommels, where a coarser global spacing happens to
  land nearer. C04's Cylinder guard: 0.0075577 (`vo`), 0.0075587 (`vop`, `f7ac37d`'s), 0.0075563 the reference.
  Adopted `vo`. Drift against `f7ac37d` of each form as built: `vo` moves C04 and Joints on 11 fixtures, DEADBEEF#297's
  owned volumes (no G) among the 3,200 generated, and on the plausible set G on 9,748 designs (max 0.0371, #32977 a
  grille), 29 a played tier (25 fullers within 0.0016 of 0.2 either side, 4 grilles) and 9 a raw tier; `vop` Joints
  alone on the same 11 fixtures, 2468ACE0#491's G 0.0002, and on the plausible set G on 703 (max 0.0354), 2 played
  tiers and 3 raw.
- *Whole-design moves on the tree* (`census`: the census's 21 moves, ±0.0013, ±0.037, ±0.3317 and each design's room
  less 0.001 along X, Y and Z alone, plus 2 random Y/Z moves inside the hitbox, on all 136 Parity fixtures, Parity's
  200 generated designs, the 500 generated designs of each of the six `PROP_BASE_SEED`s and all 33,389 plausible
  designs; 6,205 s on 3 lanes, 3–100 % busy, median 45 %):
  - Along Y, Z and the random moves, no G, d, tier, kept flag, owned volume, Joints or validity moves on any design
    but where a move leaves or enters the hitbox (64,036 valid copies leave it, 413 invalid ones, fixture A01 enters
    it), and A22c (no kept Grip part: reach, guard line and balanceFromHand from the origin move with the design; no
    factor moves). The largest deltas, last-bit rounding: Thinness 4.35e-13 (#10341, F1 with a cylinder rib on its
    blade, 0.037 up Z), every other factor under 3.2e-14, owned volumes 1.6e-15; on the fixtures Volume 2.1e-14, on
    the generated designs Thinness 1.1e-14. `f7ac37d` under the same moves (the census's tables, and mine on the
    seeds): along Z G on up to 5,125 plausible designs (22 a played tier, max 0.0472), along Y up to 547 (2, 0.0363),
    C09 0.0007 and X01's kept copy among the fixtures, 2468ACE0#491 0.0002 among the generated; the 2 random moves on
    every 11th plausible design (3,036): G on 272 and 265 (1 a tier, max 0.0249), owned volumes on 118 and 127, Joints
    on 250 and 248.
  - Along X only Asymmetry and the edge move, which stand on x = 0 (§5.2, §4.6): with both held as built, G moves on no
    design (`f7ac37d`: up to 6,041 plausible, 15 played tiers, max 0.0666; P5 0.0265 a tier at −0.0013). With them,
    on the plausible set x+0.0013 moves G on 13,129 designs (7,646 past 0.002, 32 played tiers, max 0.0071), x−0.0013
    on 12,825 (5,470, 33, max 0.2688), ±0.037 and the rooms on 32,825–32,985 (10,106–26,538 played tiers, max 0.3774);
    on the fixtures as on `f7ac37d` (x+0.0013 36 G, 1 tier, max 0.2337, worst valid 8's chains 2 → 1); on the 3,200
    generated 1,802–3,197 a move (11–2,567 tiers, max 0.3300).
- *Mirror images* (`mirror`, every part reflected across x = 0 and z = 0, then Canonical, on both trees): the fixtures
  read as on `f7ac37d` but 5 whose images moved Joints there and now read their original (C05, C11, X04g0.010, X06-0.01,
  X06-0.05: the contact rows), every generated design to the bit. On the plausible set the images' readings follow the
  as-built drift: X, G moves on 3,066 images (`f7ac37d` 3,115; 43 tier flips against 44, max 0.0849 both), Z 3,247
  (3,219; 25 against 26, max 0.1174 both); the image's |ΔG| grows on 436 (X) and 594 (Z) designs, by more than 0.002 on
  none and 5 (max 0.0038, #8003), and shrinks on 479 and 515, by more than 0.002 at G's 4 decimals on 8 and 5 (max
  0.0068; in raw doubles, which put 3 and 2 shrinks of exactly 0.0020 a hair past it, 11 and 7: fixer V); the medians
  0.0001, mostly fullers. Joints aside, 16 (X) and 73 (Z) images that read their original on `f7ac37d` do not on the
  tree, and 47 and 19 the other way: where the kept grip stands off a centre plane (#9113, C09 with a Grip rod off its
  axis) the measure orders C09's bevel twins by their distance to it, mirrored in the image, but a mirrored Wedge's
  surface samples follow its writing (§17.1 O11 (i)), so the twin walked first is not sampled as the other's image;
  `f7ac37d` walked the −z twin first in both, which C09's own symmetry makes the same written part. The tier flips that
  one tree has and the other not (`f7ac37d` 6, the tree 4: the X and Z images whose played or raw tier flips; played
  tiers alone, 4 step flips on 3 designs each, fixer V) are designs whose G sits within 0.0012 of a tier boundary and
  moved as built (#25397 Hammering 0.1994 → 0.2006).
- *Ids* (`idshuffle`, 3 shuffles a design: steps and edge by `Dump.canonical`, kept flags and owned volumes by the
  original part): 0 differ on the generated (3,200) and on every 3rd plausible design (11,130) on both trees; on the
  fixtures A17 on both, whose two exact copies take the index's tie (which one is kept; steps and edge the same).
- *As built against `f7ac37d`, every move explained* (`dumpfull` on every corpus, then each mutant's on the designs
  that moved): fixtures, the golden moves above; Parity's 200 generated designs and 2,999 of the seeds' 3,000 bit for
  bit, DEADBEEF#297's owned volumes, SurfaceComplexity and Volume (guard 2; no G); plausible 14,582 designs' Parity
  line, G on 9,748 (max 0.0371), Joints on 8,608. Joints: the contact rows alone 6,852, V3 alone 1,013, both 743.
  The rest (11,232): guard 2's margin alone 10,793; the cells' ceil alone 101 and with guard 2 149; the measure's
  rank 123 alone (its places quantised alone 88, ribbed bars whose |x| tied within 1e-17) and 23 with others; G's
  grid 3 alone and 10 with guard 2; guards 2 and 3's flat box together 24 (housed pommels, wrapRings, ribbed bars:
  only both reverted read `f7ac37d`'s); guard 2 in part 6. Alone, the verdict's rank, the hidden-Grip rule,
  `OVERLAP_TOL`'s value and Asymmetry's candidates move no design as built. Validity moved on no design of any corpus.
- *Cost* (`timing`, `Analyze.run` alternating with `shift-base` in one process, a collection before each run, every
  worst valid design and P1): 31 rounds, `f7ac37d` first, 1–9 % busy (median 4 %), the tree / `f7ac37d` 0.9716–1.0023,
  sum 0.9938; 31 the tree first, 2–22 % (5 %), 0.9753–1.0104, sum 0.9990; 61 `f7ac37d` first, 1–18 % (5 %),
  0.9837–1.0072, sum 0.9977; 61 the tree first, 0–16 % (5 %), 0.9896–1.0032, sum 0.9931. Per case the four runs'
  means 0.9891–1.0015: worst valid 8 × 0.9977 (57.0–57.9 ms in this harness), worst valid 9 × 0.9963, worst valid 5
  × 1.0015 (the largest), P1 × 0.9933: nothing measurable. The close-out's 56.5 ms (worst valid 9, T-PERF-01) projects
  to 56.3–56.6, within the 57 ms gate (57.1 with the largest single run's × 1.0103).
- `--quick`, the machine 4–6 % busy: 716 pass, 0 fail, 42 skip, 29.25 s and 29.59 s; `f7ac37d` in the same minute
  707 pass in 28.99 s (the 9 new cases about 0.5 s). `scripts/verify` on the final tree, no other Lune process, the
  load sampled every 5 s, at 18:17:54–18:22:55 (1–76 % busy, median 8 %), 18:30:09–18:35:09 (1–23 %, 7 %) and
  18:37:22–18:42:22 (0–15 %, 7 %): tools, sourcemaps, T-META-07 (141 files, 987 requires) and luau-lsp's two passes
  clean, then 758 pass, 0 fail, 0 skip (62 files; 295.67 s, 294.34 s, 294.71 s), VERIFY GREEN (300.9 s, 299.5 s,
  299.9 s), exit 0. T-PERF-01 passed: the worst valid designs 22.386–57.319, 22.789–57.783 and 22.156–59.409 ms
  (worst valid 8 each time), the F, C and X fixtures 3.642–14.426, 3.761–15.282 and 3.678–14.625 ms (C09), their
  longest stretch 0.276, 0.277 and 0.276 ms (C01). Worst valid 8 is past the close-out's 56.5 ms and the 57 ms gate
  this evening on both trees: in the cost runs above (18:10–18:15, median 4–5 % busy) it reads 57.04–57.90 ms on
  `f7ac37d`, 56.97–57.70 ms on the tree. A fourth run on the same tree, 18:50:29–18:56:14 with a Roblox Player
  running (12–100 % busy, median 31 %), failed T-PERF-01 alone: worst valid 5 60.84 ms past the 60 ms guard (757
  pass, 1 fail, 339.28 s; TESTS FAILED, exit 1); the machine then stayed 16–69 % busy (about 31 %) for the 28
  minutes I waited for quiet. The last run, 19:27:27–19:33:24 (25–62 %, median 40 %), after the Gen slow case's name
  was made to say what it asserts, failed T-PERF-01 alone on another count: F2's longest stretch 0.357 ms past the
  0.35 ms guard (757 pass, 1 fail, 350.37 s; TESTS FAILED, exit 1).
- *T-PERF-01 by process* (`work/alt_perf.sh`: `tests/run --filter T-PERF-01` on a byte copy of `f7ac37d` and on the
  tree, alternating, 18:43:46–18:48:42): the slowest valid design 57.238, 57.421 and 57.149 ms on `f7ac37d` (6–9.5 %
  busy, each run's median), 56.781, 58.583 and 58.949 ms on the tree (5.5 %, 10 %, 16 %): the tree's two slower runs
  are the two busiest windows and its quietest the fastest of the six; the alternation in one process above, which
  gives both trees the machine's same state, finds worst valid 8 × 0.9977.

**Open issues**

- S-PAR-02 must run again in Studio (the lead): the fixtures' digest moved (136 designs, 425,673 bytes, fnv1a32
  1001114566; the generated group 200, 709,366, 611215233 as before). S-PAR-01's modules are untouched.
- For fixer T, the SPEC and evidence text: §0.5; §4.2 (V3 at `CONTACT_TOL` + 1e-9); §4.3 (`OVERLAP_TOL` 1e-7, the
  box test at −`OVERLAP_TOL`, the cells' guard); §4.4 (both ranks placed from the design's grip in `RANK_Q`, the
  verdict's from every Grip part, which a hidden Grip part can move between parts tied on volume, slot and height; the
  measure's from the kept ones; the contact rows); §5's promise and §5.6's rows (Y/Z translation, ids and mirrors, with
  the figures above); §5.1 (G's sum on the 1e-9 grid); §5.2 (Asymmetry's candidates); §14.6 T-DIF-07 (a); §14.11's runs
  (this section's `--quick` and verify, T-PERF-01 after 622 of 758 cases); §16.18 (`RANK_Q`, `CELL_EPS`, `MIRROR_GUARD`,
  `X_GRID`, `CONTACT_REACH`, `OVERLAP_TOL` 1e-7; the 1e-9 guards); §17.1 O11 (j) closed, and the lead's two designer
  questions (O12 the X move, O11 (l) the mirror image); §17.2's S2 rows; E-S2.13 and E-S8.6's digest.
- A22c, and any design with no kept Grip part (invalid, `measureInvalid` only): its physics frame stands at the
  origin, so reach, the guard line and balanceFromHand move with the design (the census's finding; no factor moves).
- A design whose kept grip stands off a centre plane can read its mirror image otherwise than `f7ac37d` did (above,
  73 under Z): mirrored Wedges' samples follow their writing (O11 (i)), which the new rank order exposes where
  `f7ac37d`'s did not, and hides where it did.
- `--quick` is 29.6 s quiet, under §14.1's 30 s by less than half a second (`f7ac37d` 29.0): under ordinary load it
  passes 30 s (35.6 s at 45–57 % busy); the new pins are fast on purpose, as each guards its rule.
- The 57 ms gate: this evening the slowest valid design (worst valid 8) reads 57.0–57.9 ms on `f7ac37d` in the cost
  harness and 57.1–57.4 ms in T-PERF-01 by process, 56.8–59.4 ms in T-PERF-01 on the tree (the verify runs and by
  process), against the close-out's 56.5 ms (worst valid 9, the morning, 12 % busy). The fix costs nothing measurable
  in one process (worst valid 8 × 0.9977 over the four cost runs); the gate's margin is gone on this machine at this
  hour whichever tree runs, and T-PERF-01's 60 ms guard keeps 0.6–3.2 ms quiet: at 31 % busy it failed (worst valid
  5 60.84 ms, above), so the lead's verify of this round needs a quiet machine (§14.11).

**Deviations from the lead's decisions and the SPEC**

- Guard 2's reference is exact up to 10 higher polyhedra, not MAX_EXACT's 3 (exact is the better reference, and cheap
  there), and samples 8 × finer per axis than the finer of the two forms' cells, not their spacing; 6 cleaned parts
  whose fine reference passed 30 million cells are left out of the comparison.
- The random Y/Z moves are 2 per design on every design of every corpus (tags `rYZ1`, `rYZ2`, added to the census's
  tool), not 4 per every 22nd design.
- Three pins are unit-level only (`OVERLAP_TOL`'s value, the flat box, Asymmetry's candidates): under −`OVERLAP_TOL` no
  design of the corpora showed them (their mutants moved nothing on 120 candidate designs each), so a whole-design
  pin could not fail on its mutant.
- The specs pass the literal `"Grip"` as the frames' tests do; the helpers pass the type's grip slot.

## After M3: the whole-design shift fix, fixer T

The lead's decisions T1–T5 for this round (task of 2026-11-17, after fixer S): write the fix into the SPEC and the
evidence, measure the two designer questions the groundwork found (§17.1 O12, a whole design moved along X; O11 (l), a
mirror image), fold in the wording items of M3's plain-words write-up (`.build-notes/shift/shift_journal.txt`, 11:23),
read §0.5, §5's promise, §5.6 and §17.1 as a whole, and add the plain-words update for the designer. No module or test
changed: `SPEC.md`, `docs/spec/SPEC-evidence.md`, `README.md` and these notes, and outside the repo
`.build-notes/m3/M3-spec-changes.md`. Each claim was checked against the code first (the source diff against `f7ac37d`,
fixer S's outputs re-read, the census's and the frame analyst's figures traced to theirs). Measured with Lune 0.8.9
through `Analyze.run` with `measureInvalid` on byte copies of the working tree, at most 4 Lune processes of mine; the
scripts are in the Temp scratch `shift-fix-t/work` (`xsweep` and `xsum.py`, the X moves, as G with Asymmetry, EdgeLength
or both held as built; `optx` and `oxsum.py`, O12's options as transforms of the analysed copy and a Grip block hidden
off the grip's axis; fixer S's `mirror` with a list mode, `mirclass.py`, `flipfam.py`; `vdrift`; `probe_mir`,
`probe_hg`; V1's `flushrib` and `tieoff` in `work/v1`; `edit_spec_all.py`, `edit_docs_t.py`, `textlib.py`,
`paralib.py`), the trees in `shift-fix-t/var` (`live`, the working tree's byte copy; `wide`, its hitbox ±1.6 along X, V2
being the hitbox's only reader; `subwork`, `N_SUB_WORK` × 10,000; `walkc`, Thinness' walk signed from the design's
centre), the outputs in `shift-fix-t/out`, with a step-by-step `NOTES.md`. The machine was 14–100 % busy during the
corpus runs, 19:53–20:45 (median 41 %; three or four Lune processes of mine among it, and a Roblox Player and Studio of
the user's open throughout).

**What was written**

- `SPEC.md` (T1, T3, T4; `edit_spec_all.py`, every edit an exact match, every table row its pipe count, no new line past
  120 columns):
  - §0.5: the factors row (a whole design's move along Y or Z, every step to the bit; the hidden Grip part and the
    mirror image among O11's classes; (iii) closing (b), (c) and (k), most of (a) and (d)); the Asymmetry row (the X
    move, O12).
  - §4.2: contact at `CONTACT_TOL` + 1e-9 (`CONTACT_REACH`), the contact rows alike. §4.3: higher(p) by the box test at
    −`OVERLAP_TOL` (1e-7) and GJK within it, the sign's measurement; the cells' ceil(extent/h − 1e-9) and `CELL_EPS`.
    §4.4: both ranks' places (\|q(c − ref)\| then q(c − ref), `RANK_Q`), their references, the verdict's moved by a
    hidden Grip part (X01, X01raw, X02, none of the 32,680 plausible designs that take one), the measure's from the kept
    Grip parts and ranked after the verdicts, the mirror's reversal (O11 (l)); the locality sentence but for the rank's
    point; the measure's contact rows; the closing sentence limited to the physics (balance, reach, the blade's length,
    cutIndex), O10's absence and the near copies named. §4.5: the frames' fallback (A22c) and the ranks' points. §4.6:
    the raster item ends on the X move (O12). §4.9: T-PERF-01 after 622 of 758 cases.
  - §5's promise: four limits; the third bullet with the Y/Z move to the bit but (h) and (k), the hidden Grip part and
    the mirror image; a fourth, O12; the closing paragraph's (iii) corrected and O12 named. §5.1: x9(x), G's sum on the
    1e-9 grid. §5.2: the walk sentence (no whole-design move; the walk's sign and the mirror), Asymmetry's candidates
    (`MIRROR_GUARD`) and the fixed plane's X move (O12). §5.5: the shift fix moved no cell of the table.
  - §5.6: the ids-and-mirrors row (the ranks' references; the mirror figures, O11 (l)); the near-copy row (the hidden
    Grip part, O11 (j)); the Y/Z row (the lever, the counter's guards, E-S2.10's offsets and every corpus to the bit,
    `f7ac37d`'s figures, A22c).
  - §14.1 (`--quick` 29.3–29.6 s, 716 cases); §14.6 T-DIF-04 (C09 with a hidden Grip block), T-DIF-07 (a) to the bit
    with every guard's pin, X moves real (O12); §14.11 T-PERF-01 (the 623rd of 758, fixer S's and this round's runs) and
    the 57 ms gate defined, the lead's adoption gate.
  - §16.2 `CONTACT_TOL` (its guard; the chords merge up to `MERGE_GAP`, not this); §16.10's note and `MAX_EXACT`'s row;
    §16.18 `OVERLAP_TOL` out of the old guards' row, a row for the shift fix's guards (`RANK_Q`, `CONTACT_REACH`,
    `OVERLAP_TOL` 1e-7, `CELL_EPS`, `MIRROR_GUARD`, `X_GRID`) and one for `MERGE_GAP` and `REACH`; §16.32
    `TOL_FACTOR_ABS`, `TOL_G_INVARIANT` (the re-cuts alone) and `ANALYSIS_LUNE_MAX_MS` (the gate).
  - §17.1 O11: the opening (places from the design's grip; moved, mirrored), (j) rewritten as closed with what remains,
    (l) new, (iii) closing (b), (c) and (k) and most of (a) and (d), what (iii) leaves, the question and the default;
    O12 new. §17.2: the hidden parts' row (the Grip part and the near copies), the ids-and-order row (the ranks'
    reference, the budget's order under a mirror), the measure's rank row (what its places moved), the invisible
    construction row (the Y/Z move closed).
- `SPEC-evidence.md`: E-S2.14, new (the census, the mechanisms, each guard and its measurements, the moves on the tree,
  the as-built drift, the goldens and digest, ids and mirrors, the mirror's mechanisms, the hidden Grip part, the X
  sweep, O12's options, cost, tests); E-S2.13's digest bullet (425,673 bytes, 1001114566); the contents line. E-S8.6
  holds the digest's procedure, not its numbers, so it is unchanged.
- `README.md`'s Status: the fix, its state and its two design calls.
- `.build-notes/m3/M3-spec-changes.md`: "Update: the shift fault is fixed" (T5).

**Measured**

- *Checked against the code* (`git diff f7ac37d -- src/shared/Physics`): the six guards as fixer S and the census state
  them (`Sampling`'s `gripPlace`, `place`, `RANK_Q`, `CONTACT_REACH`; `MassProps`' `OVERLAP_TOL` 1e-7, the box test at
  −`OVERLAP_TOL`, `CELL_EPS`; `Factors`' `MIRROR_GUARD`; `Difficulty`'s `X_GRID`; `Analyze` passing the grip slot and
  the kept flags); fixer S's `var/live` differs from the tree in a comment of `MassProps` alone, so its corpora and
  mirrors measure this tree. The test list (`tests/run -- --list`): 758 cases, T-PERF-01 the 623rd. No test reads
  `SPEC.md`.
- *A whole design moved along X* (`xsweep`, 16 moves, every third plausible design, 11,130, of which 11,043 valid as
  built, every fixture and Parity's 200 generated designs; G as built, and with Asymmetry, EdgeLength or both held as
  built; 3 lanes, 19:53–20:14, 14–80 % busy, median 29 %): with both held G moved on no design at any move. On the valid
  plausible designs, G moved by 1e-6 on 43 (up to 0.0012: a plate poking exactly 0.05 out, at Asymmetry's reach, flips
  its ladder's rung), by 1e-4 on 2,553 (none past 0.002), 5e-4 3,479, 7e-4 3,575, −7e-4 3,496 (one tier, by Asymmetry, a
  step 0.0014 over Hard), 0.0013 4,347 (2,548 past 0.002, 9 a tier, up to 0.0071), 0.002 5,206 (10), 0.005 7,942 (39, up
  to 0.4173: a riveted rapier's edge 1 → 4 chains), −0.005 7,903 (40, 0.4397), 0.01 8,057 (24), 0.02 10,981 of 10,981
  (76; the edge on 23 alone, its columns a whole cell over), 0.03 10,959 (1,557), 0.05 10,897 (4,775, up to 0.3079), 0.1
  all 10,154 still inside the hitbox (6,865), a random move inside the hitbox 10,804 and 10,820 of 10,997 (6,376 and
  6,377, up to 0.3694). The edge moved G on 108 at 1e-4, 1,792 at 0.0013, 6,697 at 0.005, 23 at 0.02, 138 at 0.1;
  Asymmetry on 2,504 at 1e-4 and on all from 0.02. The 96 valid fixtures inside the hitbox: 0.0013 33 (1 a tier, worst
  valid 8, 2 → 1 chains, also at 0.002, 0.005 and 0.0034, 2 → 3 at −0.005 and −0.0103), 0.05 89 of 89 (55). Parity's
  200: 0.0013 106 (Gen 98, Sharpening 0.2027 Hard → 0.1931 Normal), 0.05 200 (104).
- *O12's options* (`optx`: the copy moved by −ref and analysed on `var/wide`, every plausible design, every fixture,
  Parity's 200; closure on every third, k ≡ 0 mod 3, under +0.0013 and the census's rX1; 3 lanes, 20:05–20:45, 16–100 %
  busy, median 48 %): (ii) the kept Grip parts' point, on 21 of the 98 valid fixtures the point is off x = 0, and G
  moves on 20 (17 past 0.002), 2 a tier (A27: Sharpening 0.0989 Normal → 0.2391 Hard, the blade now read 0.04 off its
  plane; worst valid 11, Hammering 0.1803 → 0.4389 Hard); on the 33,109 valid plausible designs, 93 (none a tier, up to
  0.0047, rods set in the grip off its axis); Parity's 200, none; (iii) every part's extents, 24 valid fixtures off
  centre, G on 23 (19 past 0.002), 4 a tier (F4 and C05, Sharpening 0.3420 → 0.1636 and 0.3466 → 0.1964 Normal; A07a and
  A27 Normal → Hard; up to 0.1784, F4); plausible 7,787 (24 %), 5,076 a tier, up to 0.2214, every flip on a cleaver's
  base (F4 2,635, C05 2,441), Sharpening Hard → Normal but 8 Hammering, the sabre C06's 2,203 moving without a tier;
  Parity's 200, 8 (up to 0.0312, no tier); (iii') the kept parts' extents, the same, plausible 7,779, 5,076 a tier.
  Closure: each option on a design moved +0.0013 or by rX1 reads as on the design (G the same on every one, Asymmetry
  within 1.3e-14).
- *A Grip part hidden off the grip's axis* (`optx`'s hg, `probe_hg`): of the 98 valid fixtures, 93 take the block: X01,
  X01raw and X02 keep the other near copy (X01: part 4 kept → cleaned, SurfaceComplexity 2.1634 → 2.1954, Joints 12.27 →
  8.28, PartCount one less; X02 the reverse; G the same, SurfaceComplexity under its range), worst valid 8 turns
  `BladeNotAboveGrip` (V4 counts every Grip part), the other 89 read to the bit; Parity's 200, none; of the valid
  plausible designs, 32,680 take the block (429 have no kept Grip Block or Cylinder, or a full slot) and none moves.
- *Mirror images* (fixer S's `mirror` outputs on this tree, every design, restricted to designs valid as built;
  `mirclass.py`, `flipfam.py`, `flipdist.py`): the X images move G on 3,066 plausible designs (1,549 past 0.002, 22 a
  played tier, 43 a raw one, up to 0.0849), the Z images on 3,247 (904, 25, up to 0.1174), the same counts as fixer S's
  on every design measured; Thinness moves on 2,482 of the X ones, SurfaceComplexity alone on 2,473 of the Z ones, every
  Z tier among them; the played flips by family X fullers 16, ribbed bars 4, plate edges 2, Z laminates and laminated
  hilts 16, fullers 6, ribbed bars 2, a rivet, every flip within 0.033 of the tier line (\|ΔG\| up to 0.0471). Probes
  (`probe_mir`): Gen 57's X image, Thinness on All 0.6456 → 0.2722, the same on `subwork`, and 0.1874 both on
  `allprobes` (`THICK_BUDGET` 1e6); #21865's Z image, SurfaceComplexity 2.4308 → 2.3641, alike on `subwork` (Hammering
  0.2113, Sharpening 0.2677 Hard). On the corpora: with the budget unlimited (`subwork`, `N_SUB_WORK` × 10,000) on the
  4,713 plausible designs whose X or Z image moves G, the Z images moving G 3,247 → 782 (SurfaceComplexity alone 2,473 →
  14, up to 0.0006), the Z tiers 25 → 0, the X images 3,066 → 2,559 (tiers 22 → 16, Thinness's); `walkc`, of the same
  4,713, the X images moving G 3,066 → 2,834 (tiers 22 → 20), the Z images 3,247 → 3,227 (25 tiers); Parity's 200, X 30
  → 21, Z 6 → 1; the valid fixtures, X 4 → 4, Z 6 → 4 (P3's 0.0363 closed); Gen 57 not at all, its tip centred on the
  grip's planes, where that sign ties and keeps the world's; as built it moves G on 5 valid fixtures (P5's Hammering
  0.2167 Hard → 0.1902 Normal, P3's 0.2752 → 0.3115), 5 of Parity's 200 (up to 0.0179) and 114 of the 11,043 valid
  designs of every third plausible one (no tier, up to 0.0666). With every volume sample a probe (`allprobes`,
  `THICK_BUDGET` 1e6, stride 1), Thinness reads every image as its original: of every eighth plausible design whose
  image moves Thinness (364), the X images moving G 311 → 76 and the Z images 198 → 106, the rest SurfaceComplexity's
  (the budget) and EdgeLength's (up to 0.0006), no tier (2 before); Parity's 200, X 30 → 3 (EdgeLength, 0.0002), Z 6 →
  0; Gen 57 Hammering 0.1874 both (as built 0.2589 and 0.1095). So Thinness' share is the probes' choice, the walk's
  sign and the stride's phase, which carries from part to part in the rank's order and follows twins swapped in the
  image.
- *(h) and (k) on the tree* (V1's scripts, `work/v1`): F5's tip typed 1e-10 over its blade, 26 of 120 Y moves, Thinness
  1.66e-3, G 0.0007 (typed 0, 0.99e-10 or 1.01e-10 over it: none); F5's laminate turned 30° with five Blade ribs 0.02
  wide flush under it, the mean thickness 0.063386 as built, 0.064654 at −0.037 along Z, Hammering 0.1119 throughout;
  the ribs' tops 0.001 lower, 0.064654 throughout. V1's and fixer 5m's figures, byte for byte.
- *`scripts/verify`* on the final tree (20:46:03–20:53:23, the machine 28–77 % busy, median 57 %, sampled every 5 s, no
  other Lune process of mine; the user's Roblox Player, Studio and Discord open): tools, sourcemaps, T-META-07 (141
  files, 987 requires) and luau-lsp's two passes clean, then 757 pass, 1 fail, 0 skip (62 files, 429.76 s), TESTS FAILED
  (439.5 s), exit 1: T-PERF-01 alone, C01's longest stretch 0.382 ms past the 0.35 ms guard. I then waited the 30
  minutes the rules allow for a quiet machine (`work/wait_quiet.sh`, a one-minute median of 12 % or less): the
  medians stayed at 37–65 % (20:55–21:25). The last run, 21:25:09–21:32:16, 19–82 % busy (median 56 %), every
  document edit in: the same clean checks, then 757 pass, 1 fail, 0 skip (62 files, 418.28 s), TESTS FAILED (427.0 s),
  exit 1, T-PERF-01 alone, F2's longest stretch 0.411 ms. No module or test changed in this round; fixer S's three
  green runs at medians 7–8 % stand for the code.

**Open issues**

- For the lead, from fixer S and still open: S-PAR-02 runs again in Studio on the new digest (the fixtures' group 136
  designs, 425,673 bytes, fnv1a32 1001114566; the generated group 200 designs, 709,366 bytes, 611215233, unchanged). My
  two `scripts/verify` runs at medians 57 and 56 % busy failed on T-PERF-01's timing alone (C01's and F2's longest
  stretch 0.382 and 0.411 ms past 0.35), with no quiet half hour between them: the lead's verify needs a quiet
  machine, as fixer S's did.
- O11 (j)'s remainder is real, not only possible: placed from every Grip part's point (the lead's ruling), the verdict's
  rank lets a Grip block hidden off the grip's axis swap which of X01's, X01raw's and X02's near copies is kept (more
  exactly, it cleaned X01's and X01raw's middle copy and kept one more of X02's: Reviewer V2, review round 1; on round
  2's ranks it moves nothing, fixer V; SurfaceComplexity and Joints move, G does not there, SurfaceComplexity being
  under its range); none of the 32,680 plausible designs that took such a block moved. The SPEC states it (§4.4, §5's
  promise, §5.6's near-copy row, §17.1 O11 (j), §17.2). Placed from the box of every non-Dust part (the census's vck),
  only a part that widens the box would steer it; not measured against the hidden block.
- O12: option (iii) re-tiers 5,076 plausible designs as built, every one on a cleaver (F4, C05), and 4 valid fixtures;
  option (ii) moves little as built (no plausible tier) but A27's Sharpening goes Hard. Both close the move to the last
  bits. The default (i) leaves a lever a forged item does not show (F5 slid 0.05: Hammering 0.1037 → 0.2250 and
  Sharpening 0.0989 → 0.3030, Hard both; F4 slid −0.161: Sharpening Hard → Normal).
- O11 (l): the way out the lead named, Thinness' walk signed from the design's own centre, closes little (X images 3,066
  → 2,834 on the plausible movers, Gen 57 not at all) and moves P5's Hammering a tier as built. What closes the Thinness
  share is the choice of probes: with every sample a probe, a design and its image read alike (cost up to 30 × the
  probes); a pick a mirror keeps (each part's count from its own samples, probes in mirrored pairs) is unbuilt and
  unmeasured. The SurfaceComplexity share is the sub-grid budget's order (unlimited, it closes). The SPEC says so.
- `--quick` at 29.3–29.6 s quiet (fixer S) is past §14.1's 27 s mark with no fast corpus of generated designs left to
  move to `t.slow`, and within half a second of the 30 s gate.
- `BALANCE_VERSION` stays at 1 (the lead's ruling; M1–M3's pre-release re-bless). §14.9 and §16.1 ask a bump for any
  outcome-affecting code change and do not state the pre-release practice; the lead may want a sentence there.
- The 57 ms gate's margin (fixer S): worst valid 8 reads 57.0–57.9 ms quiet on `f7ac37d` and on the tree alike this
  evening; the gate is now defined in §14.11 as the lead's adoption gate.

**Deviations from the lead's decisions and the SPEC**

- G's sum guard is written in §5.1, where g's formula is (the decisions name §5.2); §5.2 has Asymmetry's candidates.
- Every count of designs is over designs valid as built (the census and fixer S counted every design measured with
  `measureInvalid`): the mirror figures are the same either way; the X sweep's differ by a few (the invalid plateEdge
  #15934's 0.1018 at −0.0007 is out).
- The X sweep runs on every third plausible design (11,130) at 16 offsets, beside fixer S's six offsets on every design;
  the options' drift and the hidden Grip block on every design, their closure on every third.
- The options (ii), (iii) and (iii') are measured as transforms of the analysed copy (the tree being X-exact but for the
  two reads), not as code variants.
- The mirror's way out: the lead's walk signed from the design's centre is stated with its measured effect (small) and
  what would close the class instead; the class's mechanisms are three (the walk's sign, the stride's phase across
  twins, the sub-grid budget's order), each measured on a scratch variant.
- The hidden Grip part rule is stated with a measured verdict flip (X01, X01raw, X02), beyond the "can move it" the
  ruling asked for.
- Beyond the lead's list: §4.9's case count, §14.1's `--quick` figure, §16.32's `TOL_FACTOR_ABS` and `TOL_G_INVARIANT`
  rows, §5.6's near-copy row, §17.2's hidden parts row, README's M3 sentence ("is green" → "was green" with 749). E-S8.6
  states the digest's procedure, not its numbers, so it is unchanged.

## After M3: the shift fix, round 2, fixer U

The lead's decisions U1–U3 (`.build-notes/shift/shift_journal.txt`, the entry of 2026-11-18 00:23), after review round 1
(`shift_v1_r1.json`, `shift_v2_r1.json`) failed fix round 1 on three majors: twin parts whose heights differ in the last
bit, reordered by a Y move (both ranks compared the raw height); a hidden Grip part moving the verdict's point and,
through the near copy kept, the measure's (P5 0.2167 Hard → 0.1902 Normal); ids deciding between places one `RANK_Q`
step apart. U1: both ranks place a part across from the centre of the parts it ties with (V1's `grp`), the height keyed
in `RANK_Q` as the raw place(cy) unless a measurement favours V1's grip-relative form; no point of the design's own, so
`gripPlace` goes. U2: measure it on every corpus with the reviewers' tools. U3: adopt the reviewers' pins, adapted where
they pinned the grip's point, each failing on its mutant or on the round-1 tree, and re-bless if values moved. The SPEC
and evidence text is fixer V's. Built on the round-1 tree (`shift-r1`, uncommitted; `shift-base` = `f7ac37d`), every
reviewer claim checked against the code first. Measured with Lune 0.8.9 through `Analyze.run`, `Sampling` and
`MassProps`' own calls on byte copies of the working tree, at most 4 Lune processes of mine; the scripts are in the Temp
scratch `shift-fix-u/work` (V1's `census`, `cmp`, `drift2`, `attack_ulp`, `attack_chain`, `attack_grip`, `mirror`,
`timing`, `idshuffle`, `snapmove`, `summ.py`; V2's `hgkept`; fixer S's `dumpfull`, `drift.py`, `mircmp.py`, `csum.py`,
`queue.sh`; mine: `probe_p5`, `straddle`, `check_straddle`, `probe_hq`, `probe_copies`, `probe_c11`, `probe_design`,
`probe_tooth`, `probe_subwork`, `mutants_u.py`, `mutrun.sh`, `drop_grip_arg.py`, `mk_uhq.py`), the trees in
`shift-fix-u/var` (`u`, the candidate's byte copy; `u_hq`, its height placed from the grip's point; `mt` and `mx`, the
mutant trees; `r1t`, the round-1 source under this round's tests), the outputs in `shift-fix-u/out`, with a step-by-step
`NOTES.md`. The machine was 6–97 % busy during the corpus runs (median 51 %, up to 4 Lune processes of mine among
it) and 1–40 % for the timings and the verify (medians 3–10 %).

**What was built**

- Source (`Sampling`, with the callers' signatures; §4.1's rules kept: + − × ÷ and floor, numeric loops, no state, both
  sorts a strict total order on keys fixed per part, the index last):
  - `acrossTies(parts, keys, bySlot, kept)` writes each part's place across, keys[3..6] = |q(cx − c̄)|, q(cx − c̄),
    |q(cz − c̄)|, q(cz − c̄), with c̄ the mean of the centres' x and z of the parts tied with it on keys[1] (the volume)
    and keys[2] (the height), itself among them, summed in blueprint order; the verdict's ties also share the slot's
    name (`bySlot`), the measure's the verdict (`kept`). It is O(N²), N ≤ 24.
  - `Sampling.ranked(parts)`: keys { −v, q(cy), places…, h1, h2, h3 }; `Sampling.measureRanked(parts, kept)`:
    { −V, q(cy), places…, half extents and turn as given }. The height in `RANK_Q` is the raw q(cy) (U1, measured
    below). Every key is a number fixed before the sort and the comparators end on the index, so both stay strict total
    orders; a part's own centre is always among its ties, so c̄ is finite.
  - `gripPlace` is gone, and with it the grip slot the ranks took: `Sampling.ranked(parts)`,
    `Sampling.measureRanked(parts, kept)`, `Sampling.exposure(parts, spend)` and `MassProps.ownership(parts, kept,
    rankOf, spend)` are `f7ac37d`'s signatures again but for the measure's kept flags, and `Sampling` no longer requires
    `Definitions/Types`. `Analyze.run`'s three calls follow. The comments say so (`Sampling`'s header, `place`,
    `acrossTies`, both ranks, the exposure's measure; `MassProps`' header).
- Tests:
  - The callers: the grip slot fixer S gave 132 calls of `exposure`, `ranked`, `measureRanked` and `ownership` in
    `tests/` taken out again (`work/drop_grip_arg.py`, balanced-argument edits checked against `f7ac37d`'s lines:
    `CoverBrute`, `VisibleOracle`, `VerdictPrecision.spec` and `PhysicsHelpers` read as at `f7ac37d`, the rest keep
    the measure's kept flags); `PhysicsHelpers.plantedSampling` no longer plants `Definitions/Types`.
  - Adapted, the grip-centred order: `Verdict.spec`'s ranked case (three tied parts at z 0.3, 0.5 and 0 rank 0.3, 0.5,
    0 from their centre, and so in the image; twins at z −0.6 and −0.4 by z, not |z|) and measure-rank case (three
    tied at x −0.1, 0 and 0.1 of three slots); the copies of F5's blade 0.002 apart (their centre, copy 3, ranks first
    and is kept with the blade and copy 6; copies 4 and 5 read their strip exactly, 1 and 2 0.9776 and 0.9702 of it,
    where F5's tip covers the top of theirs: without the tip, exactly); X02's fixture and its spec (four of six copies
    cleaned); Cover's units of the sealed rod (23687.25 → 23662.125: its 16 walls, tied in two slots, read in their
    new order); `Invariance.spec`'s header, the whole-design rank case's title, the hidden Grip block's comment;
    `Perf.spec`'s comment (T-PERF-01 after 632 of 769 cases).
  - Adopted from the reviewers, as tried: V1's `pins_guards.diff` (MassProps: an extent 1e-10 past 4 cells keeps 4, a
    box 1e-10 thick none, 7e-8 of overlap no part above, 5e-7 one; Difficulty: 0.459249996 → 0.4592, 0.4592499996 →
    0.4593; Factors: Asymmetry's candidates at exactly reach along Z at 8 moves and along X at 16 places, 1e-6 past
    reach none; Invariance: F2's pommel 0.01 down valid when moved, at 3 of V1's 24 Y moves, those its mutants fail
    at, a Ball pommel 0.01 under the grip keeping its steps at 3 moves, 0.0100005 down invalid), V1's twin-height pin
    and V2's (merged: P5's tooth 7 at 1.4 + 0.2 moved 0.13, tooth 6 an ulp up moved 0.411), V1's and V2's speck pins
    (merged: the grip copied 4e-8 with a 0.05 speck at its +X face, 4e-9 with a 0.02 speck inside it).
  - Adapted from them, the grip's point gone: the half step (three tied parts whose x sum to 0 exactly, at −1.5e-9,
    1.2e-9 and 3e-10, rank 3e-10, 1.2e-9, −1.5e-9), `RANK_Q`'s size (tied at 3e-7, −1e-7 and −2e-7 rank by 100, 200,
    300 steps; at 2e-10, −1e-10 and −1e-10 tie to the index), the centre from the centres, not the centroids (a Wedge
    turned a quarter about Y, its centroid 1/6 off its centre, tied with Blocks at x ∓0.3, first), the hidden part and
    ownership (F5's Iron and Steel twins with a third twin hidden in its blade, not a Grip block, since no Grip point
    remains: owned volumes, mass and steps). Dropped: the grip point's volume weighting (`mI_unweighted`; tied parts
    share one volume) and V2's frame part for the box's centre (`vby`, not adopted).
  - New: the ids (P5's grip and a copy 3e-10 apart with the teeth typed at ±0.1400000004: the same steps whichever has
    the lower id); the grip nudged 1e-9 along +X and +Z (P5's steps); F2's blade again an ulp lower (the blade kept
    as built and moved 0.4 along Y; by the raw height the copy was kept as built); a Wedge of P5's teeth's size in the
    Guard slot hidden in its blade at x 0.02 (P5's steps and edge: the walks), and the same with `N_SUB_WORK` planted
    at 3240 and 3280 (`Sampling.spec`: the kept parts' exposure as without it, where the budget ends between the twin
    teeth).
- Goldens re-blessed at `BALANCE_VERSION` 1 (the pre-release practice of M1–M3 and round 1, which the lead's ruling puts
  in §14.9; filters "T-DIF-12" and "the digest: every Parity fixture"), every leaf that moved against `shift-r1`'s: the
  regression golden, X02's record alone (84,808 → 84,817 bytes: cleaned 6, 7, 9, 10; PartCount 5.1756 → 6.1756,
  SurfaceComplexity 2.1886 → 2.1580, Joints 8.2930 → 12.2853, Thinness 9e-10 lower on All; on the Blade 2.1756 → 3.1756,
  0.001614 → 0.000807, 2.1409 → 2.0665, 1.5138 → 3.7621; mass, volume and balance in their last bits; g, d and tiers the
  same); `parity_designs.bv1`, C11's and X02's hashes; the digest's fixtures 425,673 → 425,707 bytes, fnv1a32 1001114566
  → 262377556, the generated 709,366 and 611215233 unchanged (`parity.bv1.digest.txt` 132 → 131 bytes). The calibration
  and cost goldens and every other golden are unchanged.

**Measured**

- *The reviewers' cases on P5* (`probe_p5`, the tree against `shift-r1` and `f7ac37d`): with its grip copied 4e-8, 2e-8,
  4e-9 or 3e-10 along +X, and a 0.05 Grip speck at the grip's ±X face, a 0.02 one inside it at ±0.03 or a Grip block
  buried in the pommel at ±X, the copy is cleaned and Hammering reads 0.2167 Hard in all 28 cases (the round-1 tree:
  0.1902 Normal in the 9 at +X with the copy at 4e-9 or more, the grip cleaned; `f7ac37d` 0.2167 in all). The grip and a
  copy 3e-10 apart, ids either way round: the same steps, with the teeth at ±0.14 or ±0.1400000004 (round 1, with the
  teeth at ±0.1400000004: 0.2167 or 0.1902 by the ids; `f7ac37d` the same either way, the copy at x 0 kept). The grip
  alone moved 1e-9 along ±X or ±Z, 4e-8, 1e-6 or 1e-4 along X: 0.2167 (round 1: 0.1902 at +1e-9, +4e-8, +1e-6, +1e-4
  along X). Tooth 7 typed 1.4 + 0.2: 0.2167 as built, P5's own reading (round 1 and `f7ac37d` 0.2117: the lower twin
  first), and no step moves at 41 Y moves over its room (theirs 12 of 41). With the grip copy and a hidden exact copy of
  the near copy (`probe_residual`), the verdict keeps the copy and cleans the grip, the residual U1 names, and G is the
  same (0.2167; round 1 0.1902).
- *The height, raw or from the grip* (U1; `straddle`, then `check_straddle` and `probe_hq` on the tree, `u_hq`, round 1
  and `f7ac37d`): of the plausible set's twins tied on volume and height, one of each pair moved an ulp (as V1's
  `attack_ulp` does: 20,676 designs, 64,037 pairs), both height keys tie as built; under 200 free drags a design (12.8
  million pair-moves, uniform in the room) the raw form's keys split on 4 (3.1e-7 per pair and move: #26620 three
  pairs at one move, #32090), the grip-relative form's on none; under the snapped moves k·0.05 (1.5 million) neither.
  Through `Analyze.run` those 4 moves change no G or kept flag on any tree (last-bit deltas alike). Built on purpose,
  each form fails a typed sub-1e-9 case the other passes: the raw form a typed move landing the twins on a half step
  (P5's tooth 7 at 1.4 + 0.2 moved 0.2000000005 or 0.6000000005: Hammering 0.2167 → 0.2117; `u_hq` 0.2167), the
  grip-relative form a grip typed 5e-10 off a round height (P5 with its grip at 0.7500000005 and tooth 7 at 1.4 + 0.2:
  0.2117 as built and 0.2167 at every one of its 18 snapped moves; the raw form 0.2167 throughout), besides its point
  a hidden Grip part moves. No measurement showed the raw form failing where the grip-relative one passes outside
  typed digits, so the height is the raw q(cy), as the lead decided.
- *As built against `shift-r1` and `f7ac37d`* (`dumpfull` on every corpus; fixer S's dumps of both trees, his `live`
  being `shift-r1`'s analysis, checked: its fixtures' dump and mine of `shift-r1` byte-identical; `drift.py`):
  - Fixtures, two move: X02 (the goldens above: its blades' centre, copy 3, now keeps the rim with the blade and copy
    6) and C11, whose guard row of six 0.09 cubes overlapping by 0.015 now ranks from its centre, x 0.3075: the middle
    cube 17 owns both its overlaps (0.00030375 → 0.0003645) and cube 15 cedes one (0.000162 → 0.00010125), 6.07e-5
    at most, no factor past 1e-12. No g, d, tier, validity or other kept flag moves.
  - Parity's 200 generated designs and the 3,000 of the six seed streams: bit for bit (the digest's generated group
    as before).
  - Plausible (33,389): G moves on 43 designs, max 0.0167, no tier, kept flag, owned volume or validity. 36 are C09
    with a Grip rod off its axis, whose bevel twins round 1 placed from the kept grip's point, which the rod moves: now
    from their own centre on z = 0, they read `f7ac37d`'s G again on 35 (#9142 0.0002 from it, round 1's other
    guards). 7 fullers (and 2 more whose SurfaceComplexity moved under G's step) carry a core plate and two walls of
    one volume and height, 0.3 × 0.02 and 0.12 × 0.05 in section, which now rank walls first: the measure spends its
    sub-grid budget in another order (#24143: SurfaceComplexity 2.4225 → 2.4560, Hammering 0.1117 → 0.1284). Against
    `f7ac37d`: G on 9,713 (round 1 9,748), 38 tier flips, max 0.0371, all round 1's guards.
- *Whole-design moves* (the census's `census`: its 21 moves, ±0.0013, ±0.037, ±0.3317 and each design's room less
  0.001 along X, Y and Z alone, and 2 random Y/Z moves inside the hitbox, on all 136 Parity fixtures, Parity's 200
  generated designs, the 3,000 of the six `PROP_BASE_SEED` streams and all 33,389 plausible designs; 5,192 s on 3
  lanes and a fourth from the second half, 6–97 % busy, median 51 %):
  - Along Y, Z and the random moves (550,875): no G, d, tier, kept flag, owned volume, Joints or validity moves on any
    design but where a move leaves the hitbox (8,439 valid copies leave it, 86 invalid ones, A01 enters it at 4) and
    A22c (no kept Grip part: reach, the guard line and balanceFromHand from the origin move with the design; no
    factor moves). The largest deltas, last-bit rounding: on the plausible set Thinness 4.35e-13 (#10341, F1 with a
    cylinder rib, 0.037 up Z) and every other field under 3.5e-14; on the fixtures, generated and seed designs mass
    1.6e-13 (worst valid 7) and every factor under 2.2e-14. The same as round 1's tree.
  - Along X only Asymmetry and the edge move: with both held as built, G moves on no design of any corpus; with them,
    as on round 1 (plausible x+0.0013 13,129 designs, 7,646 past 0.002, max 0.0071; x−0.0013 12,825, 5,470, max
    0.2688; ±0.037 and the rooms 32,825–32,985 designs).
- *The reviewers' sweeps*: twins an ulp apart (V1's `attack_ulp`, its seeds: 20,676 plausible designs × 4 random Y
  moves, the 24 fixtures and 35 generated designs that have twins × 8): G 0, kept flags 0 (round 1 and `f7ac37d`: 857
  plausible designs, 5 tiers, max 0.0506; #102's 0.005 and A17's kept copy among the fixtures). The Grip parts alone
  moved 1e-9 (V1's `attack_grip`, every 3rd plausible design, 11,130): along Z none, along X 13, by Asymmetry alone
  (1.3e-4–3.9e-4, G's last step, max 0.0002; holding Asymmetry and EdgeLength restores every one: O12's class) (round
  1: Z 1,274 with 8 tiers, X 858 with 1; `f7ac37d`, every 9th: Z 0, X 5); the fixtures none (round 1: 3, 1 tier). The
  hidden-speck chain (V1's `attack_chain`: every Grip part copied 4e-8 along +X, a 0.05 Grip speck at the largest's
  +X face against one at its −X face): 93 fixtures and every 9th plausible design (3,598), G and kept flags on none
  (round 1: 85 G, 1 tier, kept flags on 3,333; `f7ac37d` none). V2's Grip block hidden off the grip's axis
  (`hgkept`): X01, X01raw and X02 read the same kept flags, factors and G with it (round 1: X01's and X01raw's middle
  copy cleaned, one more of X02's kept; `f7ac37d` none). Snapped moves (V1's `snapmove`, k·0.05 cleaned, along Y and
  Z, on the fixtures, the generated designs and every 7th plausible design) and tiny ones (±1e-12 to ±0.001 on the
  fixtures and generated designs): no G or kept flag; validity only by the hitbox.
- *Mirror images* (`mirror`, every part reflected across x = 0 and z = 0, then Canonical; fixer S's outputs for
  `f7ac37d` and round 1): every image of the 3,200 generated and seed designs reads as on both trees; the fixtures'
  images move G on the same 4 (X) and 7 (Z), max 0.0093 and 0.0363, and C11's X image and X02's Z image now differ
  from their originals below G (their as-built changes). On the plausible set the images that change a tier are round
  1's, design for design (X 43, Z 25; `f7ac37d` 44 and 26, the same differences as round 1's), G moves on 3,065 X
  images (round 1 3,066) and 3,220 Z images (3,247), max 0.0849 and 0.1174. Against round 1, Joints aside, no X image
  and one Z image (#24771) newly differ from their originals and 29 Z images read theirs again; an image's |ΔG| grows
  by more than 0.002 against both trees on two fullers (#24177 0.0003 → 0.0144 on X and 0.0149 on Z; #24771 0.0066 →
  0.0111 and 0 → 0.0118; no tier) and shrinks by as much on 3 (X) and 2 (Z) (#8687 by 0.0091). On those two fullers
  the walls tied with the core plate are twins about their centre, so the image walks them the other way round and
  the sub-grid budget runs out in another order (§17.1 O11 (l)'s budget mechanism, on new members).
- *Ids* (`idshuffle`, 3 shuffles a design: steps and edge by `Dump.canonical`, kept flags and owned volumes by the
  original part): the 109 fixtures with physics, Parity's 200, the 3,000 seed designs and every 3rd plausible design
  (11,130): none differs but A17, whose exact copies take the index's tie, as on both trees.
- *Mutants* (`mutants_u.py`, 33 on the tree; the quick suite on each, `mutrun.sh`): the ranks' 17 (places from the
  world's planes; the ties' centre from centroids; the verdict's ties without the slot; the measure's without the kept
  flag in all its callers, and in ownership, phase 6 or the exposure alone; the height raw in both ranks or either;
  truncation, half up on both sides, sign before magnitude, z raw, `RANK_Q` 1e-6 and 1e-12) and the guards' 16 as V1
  made them. Every one fails the suite on assertions, none on timing alone: the first batch, with the tests as they
  stood, left phase 6's walks and the verdict's raw height alive, which the hidden Wedge and F2's blade an ulp lower
  then caught. The round-1 source under this round's tests (`r1t`) fails the speck, ids, twin-height, grip-nudge,
  X02, Cover-units, golden, blade-copies and ranked pins, as meant (its other failures are the API's: the exposure's
  spend in the slot's place, `plantedSampling` without the Types plant).
- *Cost* (V1's `timing`: `Analyze.run` alternating in one process, a collection before each run, every worst valid
  design and P1, 21 rounds in each order; the machine 1–12 % busy, medians 3–6 %): the tree / round 1 per case, the
  two orders' geometric mean, median 1.0097 (0.980–1.033), the sums × 1.0097 and × 1.0034; the tree / `f7ac37d`
  median 1.0026 (0.982–1.013), sums × 1.0074 and × 0.9968; worst valid 8 × 0.9986 and × 1.0026 (56.5–58.6 ms on
  every tree). The ranks alone (`rankcost`: one `ranked` and three `measureRanked`, as a run calls them, 200 calls a
  round, 15 rounds alternating) take 61–70 µs a run on these 24-part designs against round 1's 31–36 µs: 0.03 ms, 0.05
  % of the slowest design, so the runs' spread is the machine's.
- `--quick`, alternating with round 1's tree, 3–20 % busy (median 10 %): 727 pass, 0 fail, 42 skip in 29.99 s and
  29.64 s; round 1 716 in 29.20 s and 29.56 s. The new and adapted cases cost about 0.25 s together, each timed alone
  (the speck 0.03 s, the twins 0.05, F2's contact 0.02 after V1's 24 moves were cut to the three that tell: its GJK
  mutant fails at 15 of them, its box-test one at k = 20 alone).
- `scripts/verify`, no other Lune process, the load sampled every 5 s: at 02:34:38 (before the twin case's table was
  typed) luau-lsp's pass B failed on it (4 type errors, exit 3); at 02:35:22–02:40:22 (1–40 % busy, median 8 %), the
  tree as final but `Perf.spec`'s comment and these notes: tools, sourcemaps, T-META-07 (141 files, 986 requires) and
  luau-lsp's two passes clean, then 769 pass, 0 fail, 0 skip (62 files, 295.18 s), VERIFY GREEN (300.4 s), exit 0.
  T-PERF-01 passed: the F, C and X fixtures 3.659–14.626 ms (C09), their longest stretch 0.109–0.271 ms (F2); the worst
  valid designs 22.207–57.236 ms (worst valid 8). The last, 02:42:47–02:47:48 (1–29 %, median 7 %), on the final tree
  but for these notes' last edits: the same stages clean, 769 pass, 0 fail, 0 skip (296.27 s), VERIFY GREEN (301.6 s),
  exit 0; T-PERF-01 the fixtures 3.689–14.714 ms (C09), longest stretch 0.095–0.277 ms (C01), the worst valid designs
  22.260–58.136 ms (worst valid 9).

**Open issues**

- S-PAR-02 must run again in Studio (the lead): the fixtures' digest moved again (136 designs, 425,707 bytes, fnv1a32
  262377556; the generated group 200, 709,366, 611215233 as before). S-PAR-01's modules are untouched.
- For fixer V, the SPEC and evidence text, every figure in this section: §4.4's rank paragraph (the height in
  `RANK_Q`; the place across from the centre of the parts tied on volume and height, the verdict's on the slot too, the
  measure's on the verdict, summed in blueprint order; no point of the design's own), §4.4's and §5's hidden-Grip
  sentences, §5.6's near-copy and Y/Z rows, §16.18's `RANK_Q` row, §17.1 O11 (j) and §17.2's hidden-parts and ids
  rows, E-S2.14; X02 keeps four of six copies cleaned; and the residuals below.
- Residuals, each needing a hidden tied part or typed sub-1e-9 digits (the lead's minors):
  - A hidden part tied with visible ones on volume, height and slot moves their centre in the verdict's rank, so it can
    decide which of two near copies is kept and who keeps a face they share: P5 with its grip copied 4e-8 along +X and
    an exact copy of that copy keeps the copy and cleans the grip (G the same, 0.2167; round 1 0.1902). The measure's
    ties are kept parts, so no cleaned part reaches it.
  - Parts whose heights or places lie within half a `RANK_Q` of each other tie, and the index settles them as it does
    exact copies (A17): of P5's grip and a copy 3e-10 apart the lower id is kept (the same steps either way).
  - Twins whose heights differ in the last bit: a free drag lands their keys on either side of a half step about 3e-7
    of the time a pair (4 in 12.8 million, no G moved); a typed move that puts them there can move G (P5's tooth at 1.4
    + 0.2 moved 0.2000000005 or 0.6000000005: Hammering 0.2167 → 0.2117).
  - A tie group's centre is summed in blueprint order, so with three or more tied parts its last bits follow the order;
    an id shuffle could move a place only where typed digits put it within an ulp of a half step (none of the
    14,439 designs shuffled above).
- Mirror images: two plausible fullers (#24177, #24771) whose core plate and walls tie read their images up to 0.0149
  further from their originals than on round 1 or `f7ac37d` (no tier), where three others read theirs nearer; the
  class is §17.1 O11 (l)'s (the budget's order), its members now the tie groups' twins about their centre.
- `--quick` stays under §14.1's 30 s by 0.01–0.36 s at 3–20 % busy (29.99 and 29.64 s; round 1's tree 29.20 and 29.56
  s in the same minutes): the margin is the machine's state as much as the cases'.
- Every as-built move above is explained; S-PAR-02's rerun and the SPEC text are the round's remaining steps.

**Deviations from the lead's decisions**

- Beyond `gripPlace`, the grip slot the ranks took is gone from `Sampling.ranked`, `Sampling.measureRanked`,
  `Sampling.exposure` and `MassProps.ownership` ("anything else the ranks no longer need"): nothing else used it, and
  the 132 test calls fixer S gave it read as at `f7ac37d` again, the measure's kept flags aside.
- Pins beyond the reviewers' tried ones, for the cases their reports measured without a pin and for the two mutants
  their pins left alive here: the ids (3e-10 copies), the grip nudged 1e-9, F2's blade again an ulp lower (the verdict's
  height), the hidden Wedge in P5's blade (phase 6's walks) and the same under a planted `N_SUB_WORK` (the exposure's
  measure).
- Changed or dropped among the tried pins, the grip's point gone: V1's ownership pin hides a Blade twin instead of a
  Grip block (no Grip point remains to steer; the twin is what would move the ties' centre); V1's Grip Wedge pin
  becomes a Wedge among tied parts (the centres', not the centroids', mean); V1's volume-weighted grip pin is dropped
  (tied parts share one volume); V2's frame part for the box's centre is not taken (`vby` not adopted). V1's and V2's
  twin-height pins are merged into one case, and their speck pins into another.

## After M3: the shift fix, round 2, fixer V

The lead's decisions V1–V3 (task of 2026-11-18, after fixer U; `.build-notes/shift/shift_journal.txt`, its entry of
00:23): write fixer U's ranks into the SPEC wherever it describes them or their effects (§4.4's ranks, §0.5, §5's
promise, §5.6, §16.18, §17.1 O11 (j) and §17.2, E-S2.14), with the residual a hidden part in a tie group leaves and what
it can and cannot steer as measured, and take out what round 1 wrote that no longer holds (V1); the review's text
minors, each checked first (V2); and read §0.5, §4.4, §5's promise, §5.6 and §17.1 as a whole (V3). No module or test
changed: `SPEC.md`, `docs/spec/SPEC-evidence.md`, `README.md` and these notes, and outside the repo
`.build-notes/m3/M3-spec-changes.md`. Each claim was checked against the code first (`Sampling`'s `acrossTies`, `place`,
both ranks and their callers, against round 1's tree), and every figure written was measured on this tree: fixer U's
outputs re-read (`shift-fix-u/out`; his `var/u` is byte-identical to the working tree's `src`), the rest with Lune 0.8.9
through `Analyze.run` with `measureInvalid` on a byte copy of the working tree, at most 3 Lune processes of mine at
once. The scripts are in the Temp scratch `shift-fix-v/work` (`hidden`, new; fixer T's `mirror` and `vdrift`; Reviewer
V1's `probe10`; fixer U's `lib`; `xdelta.py`, `valcount.py`, `tiers.py`, `mircount.py`, `mircount2.py`, `hidsum.py`;
fixer T's `mirclass.py`, `flipfam.py`, `flipdist.py` and `vdsum.py`; the edits, `editlib.py`, `edit_spec_v.py`,
`edit_evid_v.py`, `edit_readme_v.py`, `edit_notes_v.py` and `edit_changes_v.py`), the trees in `shift-fix-v/var` (`v`,
the working tree's byte copy; `subwork`, `walkc` and `allprobes`, fixer T's three variants rebuilt on it), the outputs
in `shift-fix-v/out`, with a step-by-step `NOTES.md`. The machine was 1–66 % busy during the corpus runs (03:03–03:22,
median 29 %).

**What was written**

- `SPEC.md` (`edit_spec_v.py`, every edit an exact match, prose rewrapped at 120 columns, every table row its pipe
  count):
  - §0.5's factors row: the ranks' height and ties' centre, every step to the bit on every design measured; a hidden
    part in a tie group and a value typed onto a guard's boundary among O11's classes.
  - §4.3: the measure's rank among the kept parts each ties with; only an overlap typed to exactly `OVERLAP_TOL` left to
    rounding (O11 (j)). §4.4: the ranks paragraph (the height in `RANK_Q`; the place across from the centre of the parts
    each ties with, summed in blueprint order; no point of the design's own; the measure's ties kept parts alone), what
    a hidden part in a tie group reaches as measured, ties within half a `RANK_Q`, twins an ulp apart in height; the
    locality sentence ('but for its ties' centre') and the cleaned parts' list. §4.5: neither rank reads the frames'
    points. §4.9: T-PERF-01 after 632 of 769 cases.
  - §5's promise, the third limit: the ranks; the typed boundaries (a half step of `RANK_Q`, an overlap of exactly
    `OVERLAP_TOL`, a gap of exactly `CONTACT_TOL` + 1e-9) beside O11 (h)'s; the hidden part in a tie group; twins about
    their ties' centre, as in §5.2.
  - §5.6: the ids row (the ranks; this tree's mirror figures, the unlimited budget's); the near-copy row (X02's kept
    copies; the hidden tied part as measured); the Y/Z row (the guards' boundaries at typed values; Y's +0.3317, which
    Z's list lacks; round 1's twin and nudge figures against this tree's).
  - §14.1 (`--quick` 29.64 and 29.99 s, 727 pass); §14.6 T-DIF-04 (the hidden-part pins) and T-DIF-07 (a) and (c) (round
    2's pins); §14.9, the pre-release practice in the lead's words; §14.11, T-PERF-01 the 633rd of 769 and the runs of
    fixer U and this round; §16.1, `BALANCE_VERSION`'s row pointing at §14.9; §16.18, `RANK_Q` and the guards' rationale
    (their typed boundaries; the drift with round 2).
  - §17.1 O11: the opening; (j) rewritten (round 2's ranks; round 1's three majors and the grip's nudge; what remains:
    each guard's typed boundary with its figures, ties within half a `RANK_Q`, the blueprint-order sum, A22c, a hidden
    tied part with what it moved, the box of every part but Dust as tried); (l) (twins about their ties' centre; this
    tree's figures; the walk variant's); the question, (j)'s residuals accepted as built. O12: 'to the bit' → by
    rounding alone, Thinness within 1.1e-12; fixer T's sweep named as the first tree's.
  - §17.2: the hidden parts row; the ids row (typed ties, the blueprint-order sum); the measure's rank row (round 2's
    drift); the invisible construction row (typed boundaries).
- `SPEC-evidence.md` (`edit_evid_v.py`): E-S2.13's digest (425,707 bytes, 262377556, the file 131 bytes); E-S2.14's
  opening, guard (1), the whole-design moves (round 2's census, the hitbox count, the X move's rounding), a new bullet
  for round 2 (the majors and their closures, the height form, the drift, the residuals with their measurements, cost),
  the goldens, ids and mirrors (round 2; fixer S's counts explained), the mirror's mechanisms with this tree's figures,
  the hidden Grip block, the X sweep's tree, the tests.
- `README.md`'s Status: the ranks, 769 tests, the digest's movers.
- These notes: fixer S's two mirror counts say how they are counted; fixer T's open issue on the hidden Grip block
  corrected; this section; the evidence list.
- `.build-notes/m3/M3-spec-changes.md`: the update section brought to round 2 in plain words ("23 ways" → the 15 up,
  down, forward and back moves, the 8 sideways ones being O12's; the new order; what remains), and O11 (l)'s twins and
  walk.

**Measured**

- *Checked against the code*: `Sampling.ranked` keys { −v, q(cy), \|q(x − x̄)\|, q(x − x̄), \|q(z − z̄)\|, q(z − z̄),
  extents … } through `acrossTies(parts, keys, true, nil)` (ties on keys[1], keys[2] and the slot), `measureRanked` {
  −V, q(cy), …, extents and turn } through `acrossTies(parts, keys, false, kept)` (ties on the kept flag); no
  `gripPlace`; the sums in `parts` order, the blueprint's. The test list: 769 cases, T-PERF-01 the 633rd (`tests/run --
  --list`; round 1 758). Against round 1's goldens: the regression golden (84,808 → 84,817 bytes), `parity_designs.bv1`
  and the digest (132 → 131 bytes: 425,707, 262377556) differ; the calibration, cost, fingerprint, ids and world goldens
  are byte-identical.
- *What a hidden part in a tie group reaches* (`hidden`: on each valid design up to three of the verdict's tie groups
  (volume, height in `RANK_Q`, slot) whose places differ, each given an exact copy of its last-ranked member under a
  fresh id, which pulls that member forward; and fixer T's Grip block hidden off the grip's axis; each against the
  design as built: validity, the kept flags of its own parts, every step's g and tier, every factor past 1e-12, the
  edge): the plausible set, 33,109 valid, 20,396 with such a group, 43,014 copies on 19,968 designs (1,108 skipped for a
  full slot or 24 parts), none moves anything, and the block on 32,656, none; Parity's 200, 35 copies and the block on
  all 200, none; the fixtures, 21 copies on the 17 valid fixtures with room (P5, C10, C11 and A14 have full slots) and
  the block on 77 (the worst valid designs and P1–P4 have 24 parts), none. With fixer U's `probe_residual` (P5 with its
  grip copied 4e-8 and an exact copy of the copy: the copy kept, the grip cleaned, G the same), what a hidden tied part
  reaches is which of two near copies is kept and who keeps a face they share; no corpus design moved.
- *The guards' typed boundaries* (Reviewer V1's `probe10` on this tree, 41 moves along Y and 41 along Z over each
  design's room): F5's guard lowered exactly 1e-7 onto its grip, 2 of 82 moves move its owned volume 2.56e-9, the mass
  2.01e-8 and the balance 5.54e-9, no G; F3's Cylinder grip so overlapped, last bits alone; F5's guard raised to a gap
  of exactly 0.01 + 1e-9, invalid as built and valid at 5 of 82 moves; at exactly 0.01, valid at all 82 (`f7ac37d` 6 of
  82 invalid, V1's). V1's figures on round 1, byte for byte.
- *The X move's other factors* (`xdelta.py` on fixer U's census of this tree): Asymmetry, the edge's raster, chains and
  lengths and cutIndex left out, Thinness moves by up to 1.09e-12 (#10328, F1 with a cylinder rib, at the hitbox's X
  edges), every other factor under 1.6e-14 (the fixtures', generated and seed designs' Volume 1.51e-14), and G with
  Asymmetry and EdgeLength held on none. Reviewer V2's 'up to 4e-13' (his own moves, 3.68e-13) would be false at the
  rooms' edges, so O12 says 1.1e-12.
- *The census's hitbox count* (`valcount.py` on the same census): Y, Z and random moves take 8,439 valid copies out of
  the hitbox and change 86 invalid ones, X moves 55,597 and 331. E-S2.14's 64,036 and 413 (fixer S's, round 1) took the
  X moves in, though its sentence was about Y and Z: now round 2's 8,439 and 86.
- *Against `f7ac37d`* (`tiers.py` on fixer S's and fixer U's dumps): the plausible set's G on 9,713 designs (round 1
  9,748), 29 a played tier and 9 a raw one only, as round 1; round 1 → round 2, 43 and no tier.
- *Mirror images on this tree* (fixer T's `mirclass.py`, `flipfam.py` and `flipdist.py` on fixer U's mirror outputs,
  designs valid as built): X images move G on 3,065 plausible designs (1,548 past 0.002, 22 played tiers, max 0.0849;
  Thinness on 2,482, alone on 1,534; SurfaceComplexity alone on 463; EdgeLength alone on 119), Z images on 3,220 (904,
  25, 0.1174; SurfaceComplexity alone on 2,446, Thinness alone on 704); the flips' families as before (X fullers 16,
  ribbed bars 4, plate edges 2; Z laminates 10 and laminated hilts 6, fullers 6, ribbed bars 2, a rivet), the 51 step
  flips within 0.0322 of the tier line, \|ΔG\| up to 0.0471; the 98 valid fixtures X 4 and Z 6 (0.0093, 0.0363);
  Parity's 200 X 30 (17 past 0.002) and Z 6; the seeds' 3,000 X 514 (15 tiers, up to 0.2552) and Z 122 (1).
- *Fixer S's mirror counts* (`mircount.py`, `mircount2.py` on his outputs of both trees): 'shrinks … by more than 0.002
  on 8 and 5' counts at G's 4 decimals (0.0021 or more); in raw doubles, where 3 X and 2 Z images shrink by exactly
  0.0020 a hair past it, 11 and 7, Reviewer V2's; 'grows … on none and 5' either way. 'The tier flips that one tree has
  and the other not (`f7ac37d` 6, the tree 4)' count the X and Z images whose played or raw tier flips (`f7ac37d` X 2
  and Z 4, the tree 1 and 3); played tiers alone, 4 step flips on 3 designs each (`f7ac37d` #25650, #29104 under X and
  Z, #29083; the tree #25397 under X and Z, #27524, #31981), Reviewer V2's. Round 1 → round 2: \|ΔG\| grows past 0.002
  on 2 and 2 images and shrinks on 3 and 2, either way; the flips the same.
- *O11 (l)'s ways out, on this tree* (fixer T's variants rebuilt on `var/v`: `subwork`, `N_SUB_WORK` × 10,000; `walkc`,
  the walk's horizontal axes signed from the kept grip's point; `allprobes`, `THICK_BUDGET` 1e6; on the 4,685 plausible
  designs whose X or Z image moves G here, round 1's 4,713 but 28, and on fixer T's every-eighth sample of the designs
  whose image moves G with Thinness, 364, the same designs): `subwork`, X 3,065 → 2,559 images moving G (tiers 22 → 16),
  Z 3,220 → 782 (SurfaceComplexity alone 2,446 → 14, up to 0.0006; tiers 25 → 0), the fixtures X 4 → 3 and Z 6 → 5,
  Parity's 200 as built; `walkc`, X 3,065 → 2,833 (22 → 20), Z 3,220 → 3,191 (25), Parity's 200 X 30 → 21 and Z 6 → 1,
  the fixtures X 4 and Z 6 → 4, and as built (`vdrift`) G on 114 of the 11,043 valid designs of every third plausible
  one (21 past 0.002, no tier, max 0.0666), 5 fixtures (P5's Hammering 0.2167 Hard → 0.1902 Normal, P3's 0.2752 →
  0.3115) and 5 of Parity's 200 (max 0.0179); `allprobes` on the 364, X 311 → 76 and Z 198 → 105 (round 1 106), no tier
  (2 before), EdgeLength up to 0.0006, Parity's 200 X 30 → 3 (EdgeLength 0.0002) and Z 6 → 0. Fixer T's figures within a
  few designs; `subwork`'s 782 and 14 and the drift's 114 exactly.
- *`scripts/verify`*, no other Lune process, the load sampled every 5 s (no module or test changed in this round, so
  each run checks the code as fixer U left it): at 03:31:13–03:36:16 (1–36 % busy, median 8 %), tools, sourcemaps,
  T-META-07 (141 files, 986 requires) and luau-lsp's two passes clean, then 769 pass, 0 fail, 0 skip (62 files, 296.42
  s), VERIFY GREEN (302.6 s), exit 0; T-PERF-01 passed, the F, C and X fixtures 3.724–14.589 ms (C09), their longest
  stretch 0.096–0.277 ms (C01), the worst valid designs 22.762–57.750 ms (worst valid 8). The last, 03:38:09–03:43:14
  (5–37 % busy, median 10 %), on the final tree but for this bullet's last sentence and the open issue on the 57 ms
  gate: the same stages clean, 769 pass, 0 fail, 0 skip (62 files, 299.10 s), VERIFY GREEN (304.4 s), exit 0; T-PERF-01
  passed, the fixtures 3.717–14.750 ms (C09), their longest stretch 0.100–0.270 ms (C01), the worst valid designs
  22.470–58.716 ms (worst valid 8).

**Open issues**

- For the lead, from fixers S and U and still open: S-PAR-02 runs again in Studio on the new digest (the fixtures' group
  136 designs, 425,707 bytes, fnv1a32 262377556; the generated group 200 designs, 709,366 bytes, 611215233, unchanged).
  S-PAR-01's modules are untouched.
- O12's X sweep (16 moves on every third plausible design) and its options were measured on round 1's tree and not
  re-run; the census's X moves read the same on round 2's (x ± 0.0013 on 13,129 and 12,825 plausible designs, ±0.037 and
  the rooms 32,825–32,985), and the SPEC now names the tree.
- The residuals of O11 (j), minors by the lead's round-2 severity, each need a hidden part built into a tie group of
  near copies or a value typed to a sub-1e-9 digit: no corpus design moved under any of them.
- The 57 ms gate (§14.11): worst valid 8 read 57.75 and 58.72 ms in this round's two verify runs (medians 8 and 10 %
  busy), past the lead's gate as on every tree that night (fixer U: 56.5–58.6 ms on `f7ac37d`, round 1 and round 2
  alike); T-PERF-01's 60 ms guard passed both times.

**Deviations from the lead's decisions**

- Beyond the passages the lead listed: §4.3, §4.5, §4.9, §5.2, §14.1, §14.6, §14.11 and §16.1, README's Status, and
  fixer T's open issue in these notes, where round 1's ranks, counts or wording stood.
- O12's 'to the bit' reads 'by rounding alone, Thinness within 1.1e-12', not Reviewer V2's 'up to 4e-13': the census's X
  moves to the rooms' edges reach 1.09e-12.
- E-S2.14's hitbox count (fixer S's, which took the X moves in) is corrected to the Y and Z moves'.
- O11 (l)'s ways-out figures (`subwork`, `walkc`, `allprobes`) were measured again on this tree, rather than kept as
  round 1's.
- What a hidden part in a tie group reaches was measured on every corpus (`hidden`), beyond fixer U's three designs.
- This section goes before 'Where the evidence lives', where fixers S, T and U put theirs.

## After M3: the shift fix, round 3, fixer W

The lead's decisions W1–W3 (`.build-notes/shift/shift_journal.txt`, the entry of 2026-11-18 11:49), after review round 2
(`shift_v1_r2.json`, `shift_v2_r2.json`) failed round 2 on two majors, each a regression against `f7ac37d`: the
verdict's tie centre counted hidden parts, so an exact duplicate of a cleaned near copy (Ctrl+D) decided which copy is
kept (C09 with its core typed 2.3 long, Sharpening 0.2110 Hard → 0.1967 Normal; plausible #22338, Hammering 0.1175 →
0.7000 Hard; 107 tier changes on 71 of V1's 2,644 near-copy designs; Cover (d)'s exact-copy property failing on three
`PROP_BASE_SEED`s), and near twins became twins about their own centre, so a mirror image swapped the copy kept (#1940's
Z image, Sharpening 0.1950 Normal → 0.2099 Hard). W1: the verdict's rank goes back to `f7ac37d`'s world keys for x and z
(|cx|, cx, |cz|, cz after the volume), the height alone kept in `RANK_Q`, so that twins an ulp apart in height still tie
and fall to x; the measure's rank keeps round 2's places across from the centre of the kept parts it ties with; guards
2–6 stay; what round 2 added that the verdict no longer uses goes. W2: measure it against `f7ac37d`, round 1 and round 2
on every corpus and every reviewer case. W3: the reviewers' tried pins, pins for the hidden-duplicate and mirror
near-copy cases that fail on round 2's tree, X02's blade copies pinned to their measured shares, round 2's
verdict-centre pins adapted or dropped, the goldens re-blessed. The SPEC and evidence text is fixer X's. Built on the
round-2 tree (`shift-r2/repo`, the working tree at the start, `diff -rq` equal but for `.git`, `docs.rar` and the
sourcemaps; `shift-r1/repo` before round 2; `shift-base/repo` = `f7ac37d`), every reviewer claim checked on the trees
first. Measured with Lune 0.8.9 through `Analyze.run`, `Sampling` and `MassProps`' own calls on byte copies of the
working tree, at most 4 Lune runs of mine; the scripts are in the Temp scratch `shift-fix-w/work` (fixer U's `lib`,
`census`, `cmp`, `dumpfull`, `mirror`, `idshuffle`, `attack_ulp`, `attack_grip`, `attack_chain`, `hgkept`, `snapmove`,
`timing`, `rankcost`, `probe_p5`, `probe_residual`, `queue.sh`, `csum.py`, `drift.py`, `mircmp.py`, `summ.py`,
`ydelta.py`; Reviewer V1's as `v1_*`: `nearcopy`, `nearcopy2`, `demo_c09`, `demo_c09b`, `show22338`, `ncsum.py`;
Reviewer V2's as `v2_*`: `hsteer`, `hsteer2`, `hcase`, `hphys`, `mirnear`; mine: `ncmoves` (the residual), `ncmirror`
(near copies under the mirror), `probe_x01`, `probe_copies`, `protoorder`, `mkmut.py`, `mutrun.sh`, `seedrun.sh`,
`timings.sh`), the trees in `shift-fix-w/var` (`w`, the candidate's byte copy; `r2t`, round 2's source under this
round's tests; `mut_*`, the mutants; `seed_*`, `w` with another `PROP_BASE_SEED`; `r2q`, a copy of `shift-r2/repo`), the
outputs in `shift-fix-w/out`, with a step-by-step `NOTES.md`.

**What was built**

- Source (`Sampling` alone; §4.1's rules kept: + − × ÷ and floor, numeric loops, no state, both sorts a strict total
  order on keys fixed per part, the index last):
  - `Sampling.ranked(parts)`: keys { −v, q(cy), |cx|, cx, |cz|, cz, h1, h2, h3 }, `f7ac37d`'s but for the height, which
    is the raw q(cy) = place(cy) in `RANK_Q` as in round 2. No other part enters a part's keys, so no part, hidden or
    not, can move where another stands in it, and a mirror image across x = 0 or z = 0 swaps only parts tied on all of
    it (twins about the plane), as on `f7ac37d`. Its comparator is `f7ac37d`'s.
  - `Sampling.measureRanked(parts, kept)`: round 2's, unchanged: { −V, q(cy), |q(cx − c̄)|, q(cx − c̄), |q(cz − c̄)|,
    q(cz − c̄), half extents and turn as given }, c̄ the mean of the centres of the parts tied with it on volume, height
    and verdict.
  - `acrossTies(parts, keys, kept)`: the measure's alone now, so its slot argument (`bySlot`) and its verdict-free case
    (`kept == nil`) are gone.
  - The comments say so (`Sampling`'s header: the ranks paragraph and the verdict's, which reads only the part and what
    covers it again; `place`, `acrossTies`, both ranks). `MassProps`, `Analyze`, `Factors` and `Difficulty` are round
    2's: guards 2–6 and the measure's kept flags stay.
- Tests:
  - Back to `f7ac37d`'s, byte for byte: `tests/fixtures/Regression.luau` and `FixtureSet/Regression.spec` (X02: five of
    its six copies Enclosed, the one at z 0.012 showing its +Z face) and `Physics/Cover.spec` (the sealed rod's units
    23687.25: its 16 walls read in the world planes' order again).
  - `Verdict.spec`'s ranked case: round 2's verdict-centre assertions dropped (three tied parts at z 0.3, 0.5 and 0
    ranked from their centre and so in the image; twins at z −0.6 and −0.4 by z, not |z|), `f7ac37d`'s back (|z| before
    z: 0.1 before −0.2, and so in the image; twins at ±0.1 by z); its half-step pin moved to the measure's case, where
    places still round (three tied parts summing to 0 exactly at −1.5e-9, 1.2e-9 and 3e-10). The copies of F5's blade
    0.002 apart are `f7ac37d`'s case again: copies 1–5 cleaned, each reading its rim's strip within 1e-9 (all five
    measure the strip less 3.4e-10, 0.9999999627 of it; in round 2 copies 1 and 2 read 0.9776 and 0.9702 of it, held
    only in a band, and copy 3 was kept).
  - The reviewers' tried pins: V1's `pin_tieheight.diff` in both ranks' cases (twins at x ±0.3 whose heights are 1.4 +
    0.2 and 1.6 tie on height: the −x one first, whatever the ids; kills the raw height in either rank and the measure's
    ties grouped on it) and V2's `pin_ulp_tests.diff` in the measure's case, where tie groups remain (twins at heights 2
    and 2 less an ulp form one: kills grouping on the raw height); in the verdict's case it could not tell the raw
    height from `RANK_Q`'s, the lower twin being the −x one.
  - New, each failing on round 2's source under this round's tests (`var/r2t`) and passing on `f7ac37d`'s behaviour:
    V1's `pin_nearcopy.diff` (C09 with its core 2.3 long and the core again 0.001 along +X, then that copy again exactly
    or the core again 0.0005 along +X: copies 19 and 20 cleaned, C09's steps and edge to the bit; round 2 kept the
    copy); #1940's laminate built on C02 (a Steel core 0.03 between cheeks 0.02) with the core again 0.002 along +Z and
    that copy again exactly (cleaned 4, 10, 11; round 2 cleaned the core); and its image across z = 0 (cleaned 4 and 10
    as the original, every step's g, m, d and tiers; round 2's image kept the copy, Sharpening 0.1950 → 0.2099 Hard).
    X01's whole-design move case now pins the residual: moved ±0.037 along Z, the blade between its copies is cleaned,
    as on `f7ac37d`, and every step's g, m, d and tiers are as built (round 2 kept all three).
  - Adapted: `Invariance.spec`'s header and the comments of round 2's hidden-Grip, speck, hidden-tooth and ids cases
    (the verdict's rank reads the world's planes; the ids case keeps the copy at x 0, from the world's planes, whichever
    has the lower id). The prototype's order (`Reference.spec`, `DifficultyHelpers.inRankOrder`, `Edge.spec`): the parts
    in the verdict's rank order, the kept ones among their places in the measure's, since the prototype lets its lower
    index keep a face in its verdict and in its measure alike while the build's two ranks now place a part from
    different points; against the measure's order alone it changes only X02's input (the prototype kept copy 3 in that
    order), and the prototype then cleans what the build cleans on every compared fixture but P1 (its own verdict,
    `OWN_VERDICT`).
  - From the mutants (below): the measure's tie group without the height or without the volume, and `RANK_Q` 5e-10,
    survived the suite; pinned in the measure's case (twins at x ±0.3 with a part of their volume at another height, or
    of another volume at theirs, at x 0.6: the −x twin first; tied parts 4e-10, −2e-10 and −2e-10 off their centre tie
    to the index, where steps of 5e-10 would put the first last). V2's other four constant survivors, each now pinned
    below the value that survived: `MassProps.spec` (1.5e-7 of overlap: the part above; an extent 5e-9 cells past 4
    takes 5; a box 5e-9 thick has cells), `Factors.spec` (a candidate box 5e-9 past reach is none) and `Invariance.spec`
    (F2's pommel 0.010000003 under its grip floats, the case now looping over it and 0.0100005); within twice the guard
    only for `OVERLAP_TOL`, the other three at 5, 3 and 5 times (review round 3; fixer Y's round 4 pins each within 1.5
    times).
- Goldens re-blessed at `BALANCE_VERSION` 1 (the pre-release practice §14.9 states; filters "T-DIF-12" and "the digest:
  every Parity fixture"), every leaf that moved against round 2's: the regression golden is `shift-r1`'s again byte for
  byte (84,817 → 84,808 bytes: X02's record, cleaned 6–10, PartCount 6.1756 → 5.1756, SurfaceComplexity 2.1580 → 2.1886,
  Joints 12.2853 → 8.2930, Thinness 9e-10 higher on All; on the Blade 3.1756 → 2.1756, 0.000807 → 0.001614, 2.0665 →
  2.1409, 3.7621 → 1.5138; g, d and tiers the same); `parity_designs.bv1` differs from round 2's in X02's hash alone and
  from round 1's in C11's alone (round 2's measure); the digest's fixtures 425,707 → 425,675 bytes, fnv1a32 262377556 →
  892272501, the generated 709,366 and 611215233 unchanged (`parity.bv1.digest.txt` 131 bytes). The calibration, cost
  and every other golden are unchanged.

**Measured** (the corpus runs on 4 lanes, 11,732 s, the machine 18–100 % busy, median 77 %; the probes and mutants
beside them on a fourth lane until it joined the queue)

- *Review 2's hidden duplicates* (V1's `demo_c09`, `demo_c09b`, `show22338`, `ncone`; V2's `hcase`, `hphys`; on the
  tree, round 2, round 1 and `f7ac37d`): C09 with its core typed 2.3 long and the core again 0.001 along +X, then that
  copy again exactly, or the core again 0.0005 along +X: the copies cleaned, Sharpening 0.2110 Hard, as on round 1 and
  `f7ac37d` (round 2: the copy kept, 0.1967 Normal). #22338 with plate 6 again 0.01 along +Z and that copy again: both
  copies cleaned, Hammering 0.1175 Normal, cutIndex 0.3971, mass and balance as without the duplicate, as on `f7ac37d`
  (round 2: the plate and both copies cleaned, 0.7000 Hard, cutIndex 0.6200). #1851 at 0.005 along Z: 0.1983 Normal
  (round 2 0.2035 Hard; `f7ac37d` 0.1982, round 1's drift). V2's #1940 (its core again 0.002 along Z, that copy again
  exactly): copies 10 and 11 cleaned, Sharpening 0.1950 Normal, the balance as without the duplicate (round 2: the core
  cleaned, 0.2099 Hard); F3's guard, Gen 200's guard bar and C09's core (0.002 along X): the duplicate cleaned and
  nothing else moves (round 2: Hammering 0.4423 → 0.4427, 0.2110 → 0.2156, C09 both copies kept). P5 with its grip
  copied 4e-8 and a hidden copy of the copy keeps the grip, 0.2167 (round 2 kept the copy, round 1 played 0.1902).
- *The sweeps*: V1's `nearcopy` (every 25th plausible design from 1 at 0.001 and 0.005, from 13 at 0.002 and 0.01, along
  X and Z; an exact copy of whichever copy the verdict cleans): 2,644 designs, 13,522 near-copy cases, no copy swapped,
  no G moved (round 2: 3,307 swaps, G on 1,220 designs, a played tier on 71); the fixtures' 98 cases and the generated
  designs' 104 likewise, on the tree and on `f7ac37d`. V2's `hsteer` (an in-place duplicate of the cleaned copy, 0.002
  and 0.004): the fixtures' 22 pairs, the generated designs' 59 and every 10th plausible design's 800 (to #4850): none
  swapped, no G (round 2: 5, 19 and 289 swapped, G on 3, 5 and 25, 2 tiers; `f7ac37d` on the fixtures and generated
  designs none); its duplicate 0.0005 beyond the copy (`hsteer2`) moves G on one fixture pair alone, where that
  duplicate is kept and so a visible part, on the tree and on `f7ac37d` alike. V1's in-between copy (`nearcopy2`: a
  third copy halfway, often kept, so visible): the fixtures' 46 cases read as on `f7ac37d` (G on X02's 5 by 0.0001),
  every 50th plausible design's 3,131 swap no copy and move G in 74 cases on 42 designs, up to 0.0820, a played tier on
  #25907 (3 cases), where `f7ac37d` moves 75 on the same 42, its one more by the measure, the same tier (round 2: 905 on
  304, up to 0.5368, tiers on 14).
- *Cover (d)*, "an exact copy first or last … every other reading the same bits", with the whole of `Physics/Cover` (36
  cases) under each `PROP_BASE_SEED` planted in a copy of the tree (`seedrun.sh`): passes at 0x5EED0001, 0xDEADBEEF,
  0x0C0FFEE1, 0x13579BDF, 0x2468ACE0, 0x7A11C0DE and 0x600DCAFE; round 2's source fails it at 0x0C0FFEE1 (case 39/40,
  seed 2242187965, part 6 0.6727 → 0.1351, V2's), and there, under load, (f)'s "answered at once" timing too.
- *Mirror images of near copies* (V2's `mirnear` on #1940, C09, F3 and Gen 200; my `ncmirror` over V1's selection: every
  near-copy case's image across x = 0 and across z = 0, then Canonical): the image keeps what the original keeps in
  every case on the tree and on `f7ac37d` alike, the fixtures' 98 cases, the generated designs' 47 and every 50th
  plausible design's 2,537 (round 2: #1940's Z image 0.1950 Normal → 0.2099 Hard, C09's X image both copies kept). Where
  the images differ from their originals they do so on both trees: the fixtures' Z images on 4 cases (C09's bevel copied
  along Z, twins about z = 0: 2 played tiers, §17.1 O11 (l)'s class), every 50th plausible design's Z images on 45 cases
  with no played tier; G on 4 X and 4 Z fixture images and 496 X and 452 Z plausible ones (`f7ac37d` 490 and 438: the
  measure's rounds 1–2), no tier on one tree alone.
- *Review 1's cases* (fixer U's `probe_p5`; V1's `attack_chain`, `attack_grip`, `attack_ulp`): P5 with its grip copied
  4e-8, 2e-8, 4e-9 or 3e-10 and a speck at either face, inside, or a Grip block buried at ±X: Hammering 0.2167 in all
  (round 1 0.1902 at +X); the speck chain over the fixtures and every 9th plausible design (3,598): no G or kept flag
  (round 1: 85 G, kept flags on 3,333; `f7ac37d` none). The grip and a copy 3e-10 apart, ids either way, teeth at ±0.14
  or ±0.1400000004: the same steps, the copy at x 0 kept, as on `f7ac37d` (round 1: 0.2167 or 0.1902 by the ids). The
  grip alone 1e-9 along ±X or ±Z, 4e-8, 1e-6, 1e-4 along X: 0.2167 (round 1 0.1902 along +X); every 3rd plausible design
  (11,130) along Z none, along X 13, by Asymmetry's last step alone (1.3e-4–3.9e-4, max 0.0002; O12's class, as round
  2); the fixtures none. Tooth 7 typed 1.4 + 0.2: 0.2167, P5's own, and no step moves at 41 Y moves (round 1 and
  `f7ac37d` 0.2117, 12 of 41); twins an ulp apart: 20,676 plausible designs × 4 random Y moves, the fixtures' 24 and the
  generated designs' 35 × 8: no G or kept flag (round 1 and `f7ac37d`: 857 designs, 5 tiers). A17's exact copies follow
  the index, as on every tree.
- *Whole-design moves* (the census's `census`, its 21 moves and 2 random Y/Z moves, on the 136 Parity fixtures, Parity's
  200, the 3,000 of the six `PROP_BASE_SEED` streams and all 33,389 plausible designs: 36,725 designs):
  - Along Y, Z and at random (550,875 moves): no G, d, tier, owned volume, Joints or validity moves on any design but
    where a move leaves the hitbox (8,525 copies) and A22c's frame. The plausible set's largest deltas are last-bit
    rounding, Thinness 4.35e-13 (#10341) and every other field under 3.5e-14; the fixtures', generated and seed designs'
    mass 1.63e-13 (worst valid 7). Kept flags move on three fixtures only, X01, X01raw and X02, whose blade copies stand
    about z = 0 (X01's at ±0.003, X02's from 0 to 0.012): at ±0.037, the rooms along Z and both random moves X01's and
    X01raw's blade, between its copies, is cleaned, and at −0.0013 and the first random move one more of X02's copies is
    kept, G the same every time: the residual below, as on `f7ac37d`.
  - Along X: with Asymmetry and EdgeLength held as built, G moves on no design of any corpus; with them, as in round 2
    (plausible x+0.0013: 13,129 designs, 7,646 past 0.002, max 0.0071; x−0.0013: 12,825, 5,470, max 0.2688; ±0.037 and
    the rooms 32,825–32,985).
  - Snapped moves k·0.05, cleaned (V1's `snapmove`: the fixtures, the generated designs, every 7th plausible design) and
    tiny ones (±1e-12 to ±0.001 on the fixtures and generated designs): no G; kept flags on X01 and X01raw alone, under
    snapped Z moves (the residual); validity only by the hitbox.
- *The residual* (my `ncmoves`: V1's near-copy selection, a part again 0.001 or 0.005 along X or Z where the verdict
  keeps exactly one of the two, with room for that one part, every 25th plausible design: 7,288 cases on 1,091 designs;
  the fixtures' 98 cases at 0.001–0.01, the generated designs' 47 at 0.002 and 0.01; each case moved whole ±0.0013 and
  ±0.037 along X and along Z, on the tree and on `f7ac37d`): the verdict's kept flags move on exactly the same cases on
  both trees under every move: along Z, −0.0013 swaps 392 cases on 207 designs and −0.037 482 on 207 (+0.0013 and +0.037
  none: the copies sit on +z of the part); along X, −0.0013 969 on 667, −0.037 1,734 on 667, +0.037 60 on 16, +0.0013 1.
  G (along X with Asymmetry and EdgeLength held):
  - z −0.0013: the tree 316 cases on 132 designs, 296 past 0.002, max 0.1259 (bevel|C09), a played tier in 147 cases on
    75 designs; `f7ac37d` 1,293 on 202, 483 past 0.002, max 0.1253, 149 on 77.
  - z −0.037: 359 on 135, 329, max 0.5094 (lamHilt w0.8 l2.0 c0.025 k0.02 proud−0.020 capped), 156 on 83; `f7ac37d`
    1,340 on 205, 527, 0.5094, 157 on 83.
  - z +0.0013 and +0.037: none; `f7ac37d` 26 on 3 and 84 on 9 (its measure's |z|).
  - x −0.0013: 563 on 512, 182 past 0.002, max 0.4623 (fuller w0.2 L2.5 t0.02 c0.050 g0.03 at0.4), a tier played or raw
    in 17 cases on 16 designs; `f7ac37d` 2,370 on 516, 393, 0.4626, 28 on 20.
  - x −0.037: 1,103 on 546, 408, 0.4632, 37 on 24; `f7ac37d` 3,058 on 546, 627, 0.4626, 48 on 28. x +0.037: 33 on 12,
    0.0196, 1; `f7ac37d` 1,785 on 161, 8. x +0.0013: 1; `f7ac37d` 1,151 on 106.
  - The fixtures: Z −0.0013 swaps 44 cases on 4 designs and moves G on 14 (C09, X02), 4 past 0.002, up to 0.0384, a
    played tier on 2 (C09's bevel copied 0.001 along Z: Sharpening Hard → Normal); −0.037 26 cases, G 4, the same 2
    tiers; `f7ac37d` the same swaps, G 18 and 8, 0.0383, the same tiers. Along X −0.0013 G 4 (up to 0.0143, C09's core;
    `f7ac37d` 10, 0.0215), −0.037 10 (`f7ac37d` 16). The generated designs: Z none, X −0.0013 and −0.037 3 and 4 cases,
    up to 0.0052 (Gen 200), on both trees.
- *As built against `f7ac37d`, round 1 and round 2* (`dumpfull` on every corpus; fixer S's dumps of `f7ac37d` and round
  1, fixer U's of round 2; `drift.py`): against round 2 only X02 moves, its record above (the fixtures' digest 425,707 →
  425,675 bytes); Parity's 200, the six seed streams and all 33,389 plausible designs are bit for bit, no near copies
  there tying in a way the two verdict ranks order apart. Against round 1, C11's owned volumes (round 2's measure) and
  on the plausible set round 2's 43 G moves (max 0.0167, #24143), no tier. Against `f7ac37d`, round 1's and round 2's
  drift as they reported it: C04's and C11's owned volumes, Joints on 11 fixtures, DEADBEEF#297's owned volumes, and on
  the plausible set G on 9,713 designs, 38 tiers, max 0.0371; no validity or kept flag anywhere.
- *Mirror images* (`mirror`, fixer S's outputs for `f7ac37d` and round 1, fixer U's for round 2): the tree reads every
  image as round 2 does, line for line, on every corpus but X02's images, which follow its as-built change (copies 6–10
  cleaned again, G the same; review round 3, Reviewer V2's `mdump`); against `f7ac37d` the plausible X images move G on
  3,065 (3,115) with 43 played tiers (44) and the Z images on 3,220 (3,219) with 25 (26), the fixtures' on 4 and 7 as on
  every tree, C11's X image and X02's Z image now differing from their originals below G (the measure's twins about
  their centre, round 2's); Parity's 200 and the seed streams as on `f7ac37d`.
- *Ids* (`idshuffle`, 3 shuffles a design): the 109 fixtures with physics, Parity's 200, the 3,000 seed designs and
  every 3rd plausible design (11,130): none differs but A17, whose exact copies take the index's tie, as on every tree.
- *The prototype's order* (`protoorder`, on the 62 fixtures `Reference.spec`, `Factors.spec` [8.2] and `Edge.spec` hand
  the prototype): the new order differs from the measure's alone only on X02, and from the verdict's alone on C01, C10,
  C11 and P2–P4 (the kept parts' relative order); in the measure's order alone the prototype would clean otherwise than
  the build on X02 and P1, in the new one on P1 alone (its own verdict, `OWN_VERDICT`).
- *Mutants* (`mkmut.py`, `mutrun.sh`: the quick suite on each, the tests as final; none failed on timing alone): of the
  verdict's rank, the raw height, signed places (x, x, z, z), z before x and no x; of the measure's, the raw height, the
  ties grouped on the raw height, without the kept flag, without the height, without the volume, from the centroids,
  signed places, z before x, from the world's planes and rounding half up; `RANK_Q` 1e-6, 1e-12, 5e-10 and 2e-9. 15 of
  18 failed on the suite as it stood; the three survivors (the measure's ties without the height or the volume, and
  `RANK_Q` 5e-10) fail the pins above. V2's four guard survivors (`OVERLAP_TOL` 2e-7, `CELL_EPS` 1e-8, `CONTACT_REACH`
  at + 5e-9, `MIRROR_GUARD` 1e-8) each fail its new pin, which passes on the tree. Round 2's source under this round's
  tests (`r2t`) fails the four pins aimed at it (both hidden duplicates, the mirror, X01's move) and `f7ac37d`'s
  (`baset`) passes the three hidden-duplicate and mirror pins and X01's move (that case's C09 part, round 1's measure
  fix, is what it then fails).
- *Cost* (V1's `timing`, `Analyze.run` alternating in one process, the worst valid designs and P1, 21 rounds in each
  order; the machine 34–71 % busy, medians 45–57 %, with Roblox Studio, Discord and a voice changer running): the tree /
  round 2, the sums, × 1.0029 with the tree first and × 0.9923 with round 2 first (per case 0.961–1.033), × 0.9976 over
  both; the tree / `f7ac37d` × 1.0069 and × 1.0017 (0.929–1.081), × 1.0043 over both. The ranks alone (`rankcost`: one
  `ranked` and three `measureRanked` a run, 15 rounds of 200 calls alternating) take 81–106 µs a run on the 24-part
  designs, round 2's 94–121 µs (its verdict placed every tie group too) and `f7ac37d`'s 51–61 µs: 0.04 ms more than
  `f7ac37d`, under 0.1 % of the slowest design.
- `--quick` alternating with a copy of round 2's tree, the machine 40–83 % busy (median 63 %): 730 pass, 0 fail, 42 skip
  in 49.57 s and 48.87 s; round 2 727 in 47.80 s and 47.74 s. Timed case by case (a copy of the runner printing each
  pass's time, both trees in the same minutes): 49.79 and 48.93 s of cases against round 2's 49.76 s; this round's new
  and changed cases take 0.73–0.75 s against 0.65 s for those they replace (C09's hidden duplicate 0.10 s, #1940's 0.05
  and its mirror 0.05; X01's move case 0.14 against 0.19, X02's 0.38 against 0.45): about 0.1 s more, under the noise of
  the busy machine. No quiet half hour came for the 30 s gate itself (polled 16:01–16:28, 35–68 % busy).
- `scripts/verify`, no other Lune process of mine, the load sampled every 5 s: at 15:51:49–16:00:08 (41–84 % busy,
  median 65 %: Roblox Studio, Discord, a voice changer and a game client running) tools, sourcemaps, T-META-07 (141
  files, 987 requires) and luau-lsp's two passes clean, then 771 pass, 1 fail, 0 skip (62 files, 484.20 s), TESTS FAILED
  (494.2 s), exit 1: T-PERF-01 alone, F1's longest stretch 0.469 ms against 0.35, the load's (§14.11). A quiet window
  was awaited for 30 minutes (16:01–16:28, the machine 35–68 % busy) and none came, so T-PERF-01's quiet run, and the
  `--quick` gate's, are left to the lead before the commit, as in the earlier rounds.

**Open issues**

- S-PAR-02 must run again in Studio (the lead): the fixtures' digest moved again (136 designs, 425,675 bytes, fnv1a32
  892272501; the generated group 200, 709,366, 611215233 as before). S-PAR-01's modules are untouched.
- The residual the lead named (§17.1 O11 (j)), as measured above: near copies tied on volume, slot and height, which a
  whole-design move along X or Z carries across x = 0 or z = 0, swap which one the verdict keeps on exactly the cases
  `f7ac37d` swaps them; on V1's near-copy corpus G then moves on up to 546 of its 1,091 designs (along X, Asymmetry and
  the edge held) and 135 (along Z), by up to 0.46 and 0.51, a tier on 16–24 designs along X and a played one on 75–83
  along Z, every count at or under `f7ac37d`'s and the largest moves within 0.0006 of its. On the fixtures, X01, X01raw
  and X02 swap under Z moves with G the same, and C09 with a bevel copied 0.001 along Z plays Sharpening Hard → Normal
  moved 0.0013 or 0.037 down Z, as on `f7ac37d`. None of the 33,389 plausible designs, Parity's 200 or the seed streams
  has such a pair (the census: no kept flag moves there).
- The residuals round 2 named for the measure stand (its ties' centre summed in blueprint order; ties within half a
  `RANK_Q`; twins an ulp apart in height on a typed half step); the verdict's hidden-tied-part residual of round 2 is
  gone with its tie centre.
- `--quick`'s margin: round 2's tree read 29.64–29.99 s quiet (fixer U) and 30.04–30.35 s at 4–19 % (Reviewer V2); this
  round adds about 0.1 s. Quiet, round 2's 29.64–30.35 s and this round's 0.1 s sit at the gate; should the lead's quiet
  run read over 30 s, C09's hidden-duplicate pin (0.1 s) is the one to move to `t.slow`, where the full suite still runs
  it.

**For fixer X: the SPEC and evidence text** (none of it touched here). Passages that describe the verdict's rank from
its ties' centre, or its effects, and so no longer match the code: §0.5's factors row (l. 114: the ranks' ties' centre,
a hidden part in a tie group); §4.4's ranks paragraph (l. ~933–960: the verdict placed across from the centre of the
parts of its volume, slot and height, and what a hidden tied part reaches), l. ~1069 ("ties' centre: a part tied with it
on volume, slot and height moves that, hidden or not") and l. ~1097–1098 (which of two near copies a hidden tied part
leaves kept); §4.5 l. ~1124; §5's third limit (l. ~1378–1383); §5.6's ids and mirrors row (l. 1611), near-copy row (l.
1613) and Y/Z row (l. 1619); §14.1's `--quick` figure (l. 3787: 730 pass and 42 skip, the times above); §14.6's T-DIF-04
and T-DIF-07 pins (l. ~3927–3932: the verdict's ties' centre in `Verdict.spec`; this round's four pins); §14.11's
T-PERF-01 (the 636th of 772 cases) and this round's runs; §16.18's `RANK_Q` row (l. ~4613); §17.1 O11 (j) (l. ~4839) and
(l); §17.2's hidden-parts row (l. ~4850), ids and order row (l. 4853: near twins stacked in z no longer swap under the Z
mirror, true again for the verdict) and the measure's rank row (l. ~4855); E-S2.13's digest and E-S2.14; README's Status
(772 tests, the digest); `.build-notes/m3/M3-spec-changes.md`. The figures, all above: the verdict's keys; X02's record
and the goldens; the digest; the hidden-duplicate and mirror cases on the four trees; the sweeps (13,522 cases and 2,644
designs, 0; hsteer 22, 59 and 800 pairs, 0; the in-between copies 74 against `f7ac37d`'s 75; the near copies' images,
kept flags as `f7ac37d`'s in every case); Cover (d) on the seven seeds; review 1's cases; the census (550,875 moves,
8,525 leaving the hitbox, the kept flags of X01, X01raw and X02, the last-bit deltas, X with its anchors held); the
residual's table; the as-built drift (against round 2 X02 alone); mirrors and ids as round 2; the mutants; cost;
`--quick`; the verify.

**Deviations from the lead's decisions**

- The prototype's order (`Reference.spec`, `DifficultyHelpers.inRankOrder`, `Edge.spec`) is the verdict's rank order
  with the kept parts in the measure's, where it was the measure's alone: the build's two ranks no longer share a frame
  for x and z, and in the measure's order alone the prototype cleaned otherwise than the build on X02. It changes the
  prototype's input on X02 alone.
- Pins beyond those asked for: the measure's tie group without the height or the volume and `RANK_Q` 5e-10 (survivors of
  this round's mutants), and V2's four guard-constant survivors (review 2's minor), each pinned below the value that
  survived, within twice the guard only for `OVERLAP_TOL` (review round 3; within 1.5 times since fixer Y's round 4).
- V2's `pin_ulp_tests.diff` stands in the measure's case, not the verdict's: the verdict has no tie groups now, and in
  its case the pin could not tell the raw height from `RANK_Q`'s; V1's twin pin covers the verdict's height.
- The base copies of V1's full near-copy sweep and of V2's plausible `hsteer` were dropped once the tree read 0 on them
  (13,522 cases; 800 pairs); V1's own run of `f7ac37d` on round 2's 2,377 moved cases read 0 too.

## After M3: the shift fix, round 3, fixer X

The lead's decisions X1–X3 (task of 2026-11-18, after fixer W; `.build-notes/shift/shift_journal.txt`, its entry of
11:49): write round 3's two ranks into the SPEC wherever it describes them or their effects (§4.4's ranks, §0.5, §5's
promise, §5.6, §16.18, §17.1 O11 (j) and (l), §17.2, E-S2.14), with the residual, near copies a whole design's move
carries across x = 0 or z = 0, as a **[Decision to confirm]** (§17.1 O11 (j)) with fixer W's figures, why the verdict
keeps the world's planes, with what each other reference tried did, and every statement of round 2's verdict tie centres
taken out (X1); review 2's text minors, each checked first (X2); and read §0.5, §4.4, §5's promise, §5.6 and §17.1 O11
and O12 as a whole (X3). No module or test changed: `SPEC.md`, `docs/spec/SPEC-evidence.md`, `README.md` and these
notes, and outside the repo `.build-notes/m3/M3-spec-changes.md`. Each claim was checked against the code first
(`Sampling.ranked`, `measureRanked`, `acrossTies` and `place` against `f7ac37d`'s: the verdict's keys { −v, q(cy),
\|cx\|, cx, \|cz\|, cz, h1, h2, h3 } after the slot's name, `f7ac37d`'s but for q(cy); the measure's round 2's, its ties
on the volume, q(cy) and the kept flag), and every figure written was measured on this tree: fixer W's outputs re-read
(his `var/w` is byte-identical to the working tree's `src`; his residual table re-derived with his `rsum.py`, his
snapped moves' largest factor deltas with `snapmax.py`, his census's X moves with fixer V's `xdelta.py`), the rest with
Lune 0.8.9 through `Analyze.run` with `measureInvalid` on a byte copy of the working tree (`var/x`), at most 3 Lune
processes of mine at once (M4's planners worked beside). The scripts are in the Temp scratch `shift-fix-x/work` (fixer
W's `lib` and `queue.sh`; fixer U's `probe_hq` and `check_straddle`; fixer V's `probe10` and `editlib.py`; `snap2`,
Reviewer V2's `shift2` with its snapped moves alone; `probe_c11`, `snapmax.py`, `snapsum.py`, `seedrun.sh`; the edits,
`edit_spec_x.py` with `patch1.py`–`patch3.py`, `edit_evid_x.py` with `patch4.py` and `fix_evid_x.py`,
`edit_readme_x.py`, `edit_changes_x.py`, `edit_notes_x.py` with `fix_notes_x.py`, `rewrap_x.py` and `fill_verify_x.py`;
`verify.sh`, fixer W's), the trees in `shift-fix-x/var` (`x`; `seed_<hex>`, byte copies of the repo with a
`PROP_BASE_SEED` planted), the outputs in `shift-fix-x/out`, with a step-by-step `NOTES.md`.

**What was written**

- `SPEC.md` (`edit_spec_x.py`, every edit an exact match, prose rewrapped at 120 columns, every table row its pipe
  count):
  - §0.5's factors row: both ranks' height in `RANK_Q`, the verdict's x and z from the world's centre planes, the
    measure's place from its kept ties; near copies a move carries across a centre plane, in place of round 2's hidden
    tied part.
  - §4.4's ranks paragraph rewritten (X1, X2): the verdict's rank as at M3's commit but for its height in `RANK_Q`; a
    part's keys its own, so no part, hidden or not, moves another's place, and a mirror image swaps only twins about the
    plane; heights that round to one step of `RANK_Q` (review 2's wording: within a `RANK_Q` of each other, typed digits
    or an ulp of arithmetic) tie and x and z decide, a free drag reaching a half step about 3e-7 of the times it moves
    such a pair; x and z unrounded (P5's 3e-10 copies go by x); the residual, near copies a move along X or Z carries
    across x = 0 or z = 0, with X01's and X02's cases and the plausible reach, **[Decision to confirm]** (§17.1 O11
    (j)); why the world's planes, each other reference tried with what it broke; the measure's rank (kept ties, its
    places in `RANK_Q`, ties within a step to the index, kept twins about their centre under the mirror). Further in
    §4.4, the locality sentence back to `f7ac37d`'s and the cleaned parts' list (another part's place in either rank).
    §4.5: neither rank reads the frames' points. §4.9 and §14.11: T-PERF-01 after 635 of 772 cases. §5.2: kept twins.
  - §5's promise, the third limit: the ranks; every factor within 4.4e-13 under an exact move and within 1.5e-11 under
    the editor's snapped one, whose cleaning moves each coordinate by up to 5e-13 (review 2's minor, at this tree's
    figure); the residual with its mark; round 2's hidden tied part gone; kept twins. The fourth limit points near
    copies across x = 0 to the third.
  - §5.5: the shift fix moved C04's and C11's owned volumes and Joints on 11 fixtures, no d (review 2's minor; X02's
    copies no longer).
  - §5.6: the ids row (the ranks as built; kept twins in the measure, twins about the plane in the verdict); the
    near-copy row (the world's planes; no hidden part moves the pick; the mirror keeps it but where twins about the
    plane share a face; the residual's figures and mark); the Y/Z row (the ranks; kept flags only on X01, X01raw and X02
    under Z moves; the snapped moves' bound; before the fix, the measure's rank by \|z\|).
  - §14.1's `--quick` after round 3; §14.6's T-DIF-04 (the hidden duplicates), T-DIF-07 (a) (X01's case pins the
    residual; C09 the measure's rank; the unit pins of round 2 that remain and round 3's guard pins), (c) (the mirror's
    near copy) and the seeds' sentence; §14.11's runs; §16.18's `RANK_Q` row; §16.32's `TOL_FACTOR_ABS` row (review 2's
    minor).
  - §17.1 O11: the opening (kept parts); (j) rewritten: the ranks, the census's closure with this tree's kept-flag and
    snapped figures, round 1's and round 2's majors and that none moves G now, the residual (X01, X02, C09's bevel and
    fixer W's `ncmoves` table against `f7ac37d`'s) under its mark, why the world's planes (each reference tried: the
    grip's point, the outline's box, the ties' centre, an exact copy counted once, the signed place), the other
    residuals (each guard's typed boundary, half steps, one step of `RANK_Q`, the blueprint-order sum, A22c); (l) the
    measure's kept twins, the verdict's near copies under the mirror, the figures line for line on round 2's tree; the
    default, (j)'s residuals and why the planes. O12: near copies across x = 0 under an X move and under option (ii).
  - §17.2: the hidden parts row (no hidden part moves another's place in either rank); the ids row (one step of
    `RANK_Q`; P5's 3e-10 copies by x; the mirror sentence true again for the verdict, near copies keeping their pick but
    where twins about the plane share a face, round 2's swap named; the measure's kept twins); the measure's rank row
    (round 3); the invisible construction row (the kept flags, the near copies).
- `SPEC-evidence.md` (`edit_evid_x.py`): E-S2.13's digest (425,675 bytes, 892272501, the file 131 bytes); E-S2.14's
  opening and scratch list, the mechanisms (the verdict's \|x\| and \|z\| on round 3's tree), guard (1), the moves on
  the tree (round 3's census, its kept flags, the X moves' rounding, the snapped moves), round 2's residual as review
  round 2 found it, a new bullet for round 3 (review 2's majors, every reference tried, the closures, review 1's cases,
  the residual's table, the as-built drift, mirrors, ids, cost, tests), the goldens, ids and mirrors, the mirror's
  mechanisms, the hidden Grip block, the X move's trees, the tests.
- `README.md`'s Status: the ranks, the near copies, the tests, the digest's movers, three design calls.
- `.build-notes/m3/M3-spec-changes.md`: the update brought to round 3 in plain words (the fix's two orders, round 3's
  reason and closures, what it means, what moved, what remains) and a new item, O11 (j)'s near copies as a decision,
  with the options tried and the recommendation.
- These notes: this section; the evidence list.

**Measured**

- *Code and lists*: `Sampling` as above; the test list 772 cases, T-PERF-01 the 636th (`tests/run -- --list`; round 2
  769, its new cases the two hidden duplicates, the mirror's near copy and the contact case's second gap); the
  regression golden `shift-r1`'s again (84,808 bytes), the calibration golden round 1's and round 2's, the digest
  425,675 bytes and 892272501 in a 131-byte file.
- *As built* (`probe_c11`, the tree against `f7ac37d`): C04's Cylinder guard owns 0.007557654222 (0.007558654222), C11's
  cubes 15 and 17 0.00010125 and 0.0003645 (0.000162 and 0.00030375), X02 keeps 11111000001 (copies 6–10 cleaned) and
  X01 all seven on both trees: §5.5's sentence.
- *Fixer W's residual* (`rsum.py` on his `rs_w_*` and `rs_base_*`): his table, case for case (above, E-S2.14); and his
  census's summary: no kept flag moves under an X move on any corpus, and under Y, Z and random moves only X01's,
  X01raw's and X02's, so no corpus design but those holds a pair a move swaps.
- *The near copies' mirror images* (fixer W's `nm_w_*`): the 45 plausible Z images whose kept parts differ from their
  originals are all C09-based designs with its bevel (part 13, a Wedge) copied 0.002 along X (one along Z), and the 4
  fixture images C09's bevels 13 and 15 copied 0.001–0.002, twins about z = 0 that share a face (2 played tiers: z
  0.001, Sharpening 0.2247 Hard → 0.1863 Normal); `f7ac37d`'s the same, so §17.2's "near twins stacked in z no longer
  swap" holds again for the verdict, with that clause.
- *Snapped moves* (`snap2`, Reviewer V2's ys+0.15, ys−0.35, zs+0.1 and zs−0.05, each coordinate `clean`ed, on the
  fixtures, Parity's 200, the plausible designs k ≡ 0, 4, 8 mod 12 and every 5th design of the six seed streams; queue
  `m1`, 293 s on 3 lanes, 48–99 % busy, median 73 %): 9,283 designs, 27,027 moves, no G or tier, the kept flags only
  X01's and X01raw's at zs+0.1 and zs−0.05 (the blade cleaned), every factor else within SurfaceComplexity 1.19e-11
  (plateTilt\|F3\|tilt4 poke0.015 at zs+0.1) and Thinness 1.05e-11 (worst valid 10), Reviewer V2's round-2 figures
  exactly; fixer W's own snapped moves (`snap_w_*`, k = ±1, 3 and 7 along Y, ±1 and 3 along Z) reach SurfaceComplexity
  1.43e-11 (plateTilt\|F3\|tilt4 poke0.005 at +0.05 along Z) and Thinness 9.07e-12 on every 7th plausible design. So the
  SPEC says 1.5e-11, not the 1.2e-11 review 2 proposed from its own sweep.
- *The X moves' rounding* (`xdelta.py` on fixer W's census): Thinness 1.09e-12 (#10328 at xL+), every other factor under
  1.6e-14 (worst valid 7's Volume 1.51e-14), G with Asymmetry and EdgeLength held on none: O12's figures hold.
- *Twins and typed boundaries* (queue `m1`): fixer U's `probe_hq` on this tree, P5 with tooth 7 at 1.4 + 0.2 as built
  0.2167, moved a typed 0.2000000005 or 0.6000000005 along Y 0.2117, 0.4000000004–0.4000000006 0.2167, its grip at
  0.7500000005 0.2167 at all 18 snapped moves; his `check_straddle` on the 4 free-drag splits (#26620 three times,
  #32090), last bits alone; fixer V's `probe10`, F5's guard 1e-7 into its grip owned 2.56e-9 more at 2 of 82 moves (no
  G), at a gap of 0.01 + 1e-9 valid at 5 of 82, at 0.01 at all 82; round 2's figures, so the SPEC keeps them.
- *Every case of `tests/Physics` on six `PROP_BASE_SEED`s* (`seedrun.sh`, the whole of it, slow cases too, in a copy of
  the repo per seed, 3 lanes): 1,095 s, the machine 46–100 % busy (median 76 %): every assertion holds on all six
  (373–375 of 376 cases pass a seed); only timings failed: T-PERF-01 on all six (F1's longest stretch 0.435–0.656 ms),
  Cover (f), a design past the cap, on 0x0C0FFEE1 and 0x13579BDF by its own 'answered at once' (90.75 and 61.48 ms, the
  best of 3) and on 0xDEADBEEF and 0x7A11C0DE by the 2 s a case may take (2,197 and 2,205 ms), and that budget again for
  Cover (a) on 0x0C0FFEE1 (2,000.5 ms) and T-DIF-01 on 0x5EED0001 (2,026 ms). Cover (d), which round 2's source failed
  on 0x0C0FFEE1 and 0x2468ACE0, passes on all six.
- *Marks*: 101 **[Decision to confirm]** marks in the SPEC, its whitespace folded (99 before), each with its O or Q
  number but §0.3's convention, which speaks of them; the two new ones are O11 (j)'s, in §5's promise and in O11 (j)'s
  residual, and §4.4's moved from the hidden tied part to the near copies.
- *`scripts/verify`*: no other Lune process of mine, the load sampled every 5 s (`verify.sh`, fixer W's): at
  17:19:54–17:28:43, the machine 37–94 % busy (median 73 %; Roblox Studio, Discord, a voice changer and a game client
  running), tools, sourcemaps, T-META-07 (141 files, 987 requires) and luau-lsp's two passes clean, then 770 pass, 2
  fail, 0 skip (62 files, 516.94 s), TESTS FAILED (526.0 s), exit 1: T-PERF-01, F1's longest stretch 0.474 ms against
  0.35, and Cover (f), a design past the cap, over the 2 s a case may take (2,101.5 ms), both the load's (§14.11; fixer
  W's run at 41–84 % failed T-PERF-01 alone, and Cover (f) failed so on four of the six seeds above). Only `SPEC.md`'s
  T-PERF-01 row, `README.md`'s Status sentence and this section were written after it.

**Review 2's minors, as checked and written**

- §17.2's mirror sentence: true again for the verdict on this tree (Reviewer V2's `mirnear` and fixer W's `ncmirror`);
  the row now says where near copies' images still differ (twins about the plane sharing a face with them, C09's bevels)
  and names round 2's swap, and the measure's kept twins.
- §5.5's list: C11's owned volumes added; X02's copies, back to `f7ac37d`'s, not.
- The `RANK_Q` wordings: 'round to one step' with 'within a `RANK_Q` of each other, typed digits or an ulp of
  arithmetic'; 'a free drag about 3e-7 of the times it moves such a pair'; and, new this round, the verdict rounds only
  heights, so near copies a hair apart along X go by x, not by the index.
- The factor bounds under the snapped move: §5's promise, §5.6, §16.32 and O11 (j) say 1.5e-11 (1.43e-11 measured) and G
  to the bit, beside 4.4e-13 for an exact move.
- E-S2.14 and the plain-words update: as written above.

**Open issues**

- For the lead, from fixer W and still open: S-PAR-02 runs again in Studio on the new digest (the fixtures' group 136
  designs, 425,675 bytes, fnv1a32 892272501; the generated group 200 designs, 709,366 bytes, 611215233, unchanged);
  S-PAR-01's modules are untouched. A quiet `scripts/verify` and `--quick`: the machine stayed 37–94 % busy through this
  round as through fixer W's (no quiet half hour since 16:01), so T-PERF-01, Cover (f)'s 2 s and the 30 s gate of
  `--quick` are left to the lead's quiet run before the commit; fixer W's case-by-case timing puts round 3 about 0.1 s
  over round 2's quiet 29.64–30.35 s.
- O11 (j)'s residual is now a designer's question with a default (the world's planes, as at M3's commit): every
  reference tried for the verdict's near copies broke moves, mirrors or hidden-part robustness, and a rule for near
  copies themselves, if the lead takes it to Louis, is not built or measured.
- §14.6's seeds sentence rests on this round's runs under load: every assertion held, and only the timing cases failed
  (named above); a quiet run of the six would read them too.

**Deviations from the lead's decisions**

- The snapped move's factor bound is 1.5e-11, not the 1.2e-11 the lead's X2 quotes: that is Reviewer V2's corpus's
  1.19e-11, which this tree reproduces, while fixer W's snapped moves on this tree reach 1.43e-11.
- Beyond the passages the lead listed, where round 2's verdict or its figures stood: §4.5, §4.9, §5.2, §5.5, §14.1,
  §14.6, §14.11, §16.32, O12, E-S2.13, README's Status, and the plain-words file's new O11 (j) item.
- `tests/Physics` was run on the six seeds (about 18 minutes on 3 lanes) to back §14.6's sentence, which review 2 found
  false on round 2's tree.
- This section goes before 'Where the evidence lives', where fixers S to W put theirs, rather than after it.

## After M3: the shift fix, round 4, fixer Y

The lead's decisions Y1–Y6 (task of 2026-11-19, after review round 3; `.build-notes/shift/shift_journal.txt`, its entry
of 01:35): Reviewer V2's repair (B) in the measure's rank, a cleaned part with no place among its ties (Y1); the
reviewers' pins, each failing on its mutant (Y2); the text, each point checked first (Y3); the measurements (Y4); the
`--quick` gate (Y5); the goldens (Y6). Changed: `src/shared/Physics/Sampling.luau` (the measure's rank) and
`MassProps.luau`'s header; `tests/Physics/{Invariance, Factors, MassProps, Verdict}.spec.luau`; `SPEC.md`,
`docs/spec/SPEC-evidence.md`, `README.md`, these notes and `.build-notes/m3/M3-spec-changes.md`. Every claim was checked
against the code first, and every figure written was measured with Lune 0.8.9 through `Analyze.run` with
`measureInvalid` on byte copies of the working tree (`var/y1`, `y3`, `y5`, the last the working tree's source and tests
as this round leaves them), the trees `shift-r3` (round 3's), `shift-r2` and `shift-base` (`f7ac37d`), and the
reviewers' variants, at most 3 Lune processes of mine at once (no other agent's Lune process ran beside mine whenever I
looked). The scripts are in the Temp scratch `shift-fix-y/work` (`lib.luau`, Reviewer V1's with Reviewer V2's dump
fields; Reviewer V2's `dump`, `mdump`, `cmpdump.py`, `hmass`, `hmass3`, `ncsweep`'s case builder in `nccheck`,
`timing3`; Reviewer V1's `cs1`–`cs4`, `csids`, `idshuffle`; my `idtwins`, `probes_y`, `mirtwins`, `img8776`, `x01moves`,
`mkmut.py`, `mutrun.sh`, `lane.sh`, `quick_time.sh`, `alt_times.sh`, the runner with a time per case
`var/y2/tests/runtimes.luau`, and the edits `textedit.py`, `spec_edits.py`–`spec_edits4.py`, `evidence_edits.py`,
`evidence_edits2.py`, `plain_edits.py`, `port_b5.py`, `pins_b5.py`), the trees in `shift-fix-y/var` (`B`, V2's repair as
given; `B2`, my first form; `B5`, the form adopted; `mut_*`, the mutants), the outputs in `shift-fix-y/out`, with a
step-by-step `NOTES.md`.

**What was built: a cleaned part placed from the kept parts' centre, after its material**

Review round 3's major, checked in the code: `acrossTies` grouped a part with the parts of its volume, height and
verdict (`kept[q] == kept[p]`), so a cleaned part was placed from the centre of the cleaned parts it tied with, and
`MassProps.ownership` orders cleaned parts by that rank (after the kept ones and the slots); a hidden part moved that
centre and chose which of two hidden parts owns their overlap. On round 3's tree every reviewers' probe moves
(`probes_y`): V2's sealed box with a Ctrl+D copy of its Steel filler, mass 1.29371984 → 1.29358464 kg and balance
0.387402095 → 0.387165618; V1's Dust specks with a buried speck or a copy, −9.0e-7 kg; his cavity copies, −2.03e-4 kg; G
never. `f7ac37d` none.

V2's repair as given (`var/B` = his `hfix0`, checked against the code: a cleaned part keys 0 for its place, so between
cleaned parts of one volume and height the half extents and turn as given decide, then the slot, the material and the
index) closes the major, but the lead's premise that the index's split "moves no mass, COM or balance" holds only where
the overlap is clipped exactly (`idtwins`, ids swapped): Blocks, the two owned volumes swap and nothing else; two Iron
Dust Balls 0.07 across on F2's guard face 0.03 apart along X, the COM's x 2.37e-6 (Reviewer V1's `csids`); Cylinders
4.3e-6; and along Z, one 0.005 into the face so that their overlap is sampled in one box with the guard's in the lower
one's frame, the mass 1.08372 or 1.08351 kg (2.05e-4) and the balance 1.08e-5 by the ids. And it leaves the editor's
mirror copies to their turn, which a mirror image rewrites (`mirtwins`: two Dust Wedges or Blocks 0.07, Iron and Steel,
mirror copies across x = 0 overlapping on F2's guard face, turned 30° about Z or 20° about (1, 1, 1): the Z image's mass
1.2e-6 to 1.44e-6 kg off; `f7ac37d` and round 3 to the bit). My first form (`var/B2`, the index alone replaced by the
place from the kept parts' centre) closed the ids but kept the turn's flip, and read plausible #8742's and #8776's Z
images (two Enclosed Iron Wedges at x ±0.02) 4.3e-19 apart in their owned volumes (`img8776`).

As built (`measureRanked`, `acrossTies`): the larger first, then the height in `RANK_Q`, then the kept parts before the
cleaned ones (every reader takes the kept parts alone: the measure's hide test compares kept parts, the walks and
`inRankOrder` take the kept order, ownership puts them first); kept parts as before, by the place across from the centre
of the kept parts they tie with, the half extents and turn, slot, material, index; cleaned parts by the material, then
the place from the centre of every kept part (their centres' mean x and z summed in blueprint order, the origin with
none kept), then the half extents and turn, slot, index. `acrossTies` writes both places into keys 3–6; the comparator
is a strict total order (the kept flag splits it before either branch). So no hidden part (the centre is the kept
parts'), no id (the place decides before the index) and no whole design's move (the centre moves with it) chooses a
hidden overlap's owner, and a turn decides only between parts that stand together. The residual, named in §4.3: cleaned
twins of one material exactly about the kept parts' centre (to `RANK_Q`) tie but for the sign of their place and swap
under that mirror image, which moves their owned volumes, and the mass by the overlap's sampling difference where it is
sampled beside other parts (F2 with a stud at x 0.12 and two Dust Balls at x 0.004 and 0.044 about the centre x 0.024,
one overlapping the stud: 1.61e-5 kg; round 3 the same, `f7ac37d` none; V2's box with two Iron fillers about x = 0, the
owned volumes alone, as on `f7ac37d`), where `f7ac37d` swapped twins of any material about the world's planes (V2's box,
Iron and Steel, under the X mirror: 1.42e-4 kg).

**Pins, each failing on its mutant** (`mkmut.py` on a byte copy of the tree, `mutrun.sh`, `out/mut_*.txt`, the failing
assertion read)

- `Invariance.spec` 'T-DIF-04 a hidden part steers no ownership among hidden parts' (V2's pin, laid along Z, the copy on
  Iron and Steel fillers and a move 0.05 down Z on two Iron ones; `boxedF2`): round 3's measure (`r3measure`) fails on
  the copy, owned volume 11 0.012168 → 0.005408; V1's world planes for cleaned parts (`worldCleaned`) on the move, the
  same.
- 'T-DIF-07 (c) ids decide nothing between hidden twins' (the Dust Balls along Z): V2's repair as given (`leadB`) fails,
  the nearer Ball 9.70e-5 against 1.7755e-4.
- 'T-DIF-07 (c) a mirror image keeps who owns a hidden overlap' (the Dust Wedges turned 30° about Z, mirror copies, Iron
  and Iron, Iron and Steel, the Z image part by part): `leadB`, my first form (`B2`) and the material first with the
  turn before the place (`turnBeforePlace`) fail, owned volume 5 9.78e-5 → 1.68e-4.
- V2's guard pins at 1.5 times (`pin_guards_15.diff`): `CELL_EPS` 2e-9 fails 'an extent 1.5e-9 cells past 4 takes 5' (64
  cells, not 80); `MIRROR_GUARD` 2e-9 '1.5e-9 past reach: no candidate' (800, not 640); `CONTACT_REACH` + 2e-9 '1.5e-09
  past CONTACT_TOL: no contact'.
- V1's sub-1e-9 pins (`pin_halfstep.diff`, `pin_mirror_guard.diff`, the contact case of `pins_invariance.diff`): place
  rounding half toward 0 on the + side (`halfDown`) fails 'half a step out on either side rounds away from 0';
  `MIRROR_GUARD` 1e-10 '5e-10 past reach, inside MIRROR_GUARD: a candidate'; `CONTACT_REACH` + 1e-10 '5e-10 past
  CONTACT_TOL: contact'.
- V2's `pin_quantxz.diff`: the verdict's x and z in `RANK_Q` (`quantXZ`) fails 'x not rounded: the one at x 0 first'.
- Not pinned: `X_GRID` within 10 times (a 1e-8 grid fails 'the x 4e-9 under 0.45925', a 2e-9 grid passes
  `Physics/Difficulty`), as §14.6 now says. Not taken: V1's specks pin (V2's box pins the same chain) and his ids pin as
  written (it asserts the twins along X, which V2's repair moves by the COM's x only; the pin along Z moves the mass).

**Measured**

- *As built against round 3* (`dump` at 17 digits, every output of `Analyze.run`; `var/y5`, the source as committed
  here, and `var/B5`): byte for byte on the 136 fixtures, Parity's 200, the six seed streams and `0xBADC0FFE` and
  `0x31415927` (4,000), and all 33,389 plausible designs; my dumps of round 3's fixtures and Parity's 200 equal Reviewer
  V2's `d_live_*`, so his are round 3's for the rest. Mirror images (`mdump`, X and Z): the fixtures, Parity's 200 and
  plausible 1–11,130 byte for byte round 3's (my first form differed on #8742's and #8776's Z images, above). Ids
  (`idshuffle`, 3 shuffles): the fixtures A17 alone (its exact copies, the index's tie), Parity's 200 none, every 25th
  plausible design (1,336) none (on `y3`).
- *The probes* (`probes_y`, on this tree, round 3, `f7ac37d` and `B`; `hmass`, `hmass3`, `cs1`–`cs4`, `idtwins`,
  `mirtwins`): every hidden copy and buried part leaves the owned volumes, the mass and the balance to the bit; the
  twins' ids swapped too (the balance's last bit where the swap reorders the parts summed, 2.2e-16); moves along Y and Z
  (+0.0137, −0.0457, +0.3001, +0.0021, −0.0333, ±0.05, one random) the mass to the bit, the owned volumes within 8.7e-18
  and the balance within 8.9e-16, along X the same, G moving by Asymmetry and the edge alone; mirror images: above.
- *The near copies* (`nccheck`, Reviewer V2's examples): G and kept flags cannot follow the cleaned parts' order (kept
  parts own first; the walks read kept parts), and #7517 (bevel 15 again 0.0007 along Z: Sharpening 0.2222 Hard; moved
  0.037 down Z 0.1923 Normal, `f7ac37d` 0.2005 Hard), #7017 (bevel 13 again 0.0007: its Z image 0.2247 Hard → 0.1870
  Normal, `f7ac37d` 0.2255 → 0.1879) and #7661 (0.001: 0.2070 → 0.1498, `f7ac37d` 0.2055 → 0.1491) read them on this
  tree. X01 moved 0.0021 or ±0.037 along Z cleans its blade, PartCount 6.1756 → 5.1756, Joints 12.2682 → 8.2759,
  SurfaceComplexity 2.1634 → 2.1954, an owned volume 0.025, the mass and G the same; X02 at −0.0013 keeps copy 6, Joints
  8.2930 → 12.2853 (`x01moves`).
- *The goldens*: none moved (the dumps above; `--quick` compares them), so nothing was blessed: the regression golden,
  the calibration and cost goldens, `parity_designs.bv1` and the digest are round 3's byte for byte.
- *Cost* (`timing3`, Reviewer V2's: the tree `y5`, round 3 and `f7ac37d` rotated in one process, every T-PERF-01 case
  and C09, C04, F5, a collection before each run, 21 rounds in each of two orders, no other Lune process, the machine
  2–14 % busy, medians 8 and 7 %): the tree / round 3 × 1.0008 and × 1.0006 (per case 0.966–1.024), the tree / `f7ac37d`
  × 0.998 and × 0.995: nothing measurable, as the rank's work (a loop over the parts per call) is microseconds.
- *`--quick`* (`quick_time.sh`, the runner's time, `typeperf` every 2 s, whose figure counts this run's own Lune, 8 % of
  the 12 threads; the machine's own background, Roblox Studio and Player, Discord, a voice changer, about 8–10 %): round
  3's tree 30.55 and 30.62 s at 01:45 (medians 20 %), so over §14.1's 30 s; per case three times (`runtimes.luau`,
  `times_y2_*`), the shift fix's added fast cases ranked (renamed old cases, as C10, C11 and F1 at + 0.3317, not
  counted), and the heaviest moved to `t.slow` until it read under 30 s: 'a whole design moved keeps the measure's rank'
  (95 ms), 'a part that only touches another face to face' (88), 'a hidden part chooses no near copy: C09' (67), 'twins
  whose heights differ in the last bit' (51), 'a sampled overlap's cells keep their count' (49), 'G sums each factor's x
  on a 1e-9 grid' (49), 'a gap of exactly CONTACT_TOL is contact' (44) and 'a hidden part chooses no near copy: a
  laminate on C02' (37), 0.48 s. A tree run second in a pair reads about 1 % slower (the same case 646 against 657 ms
  one way, 645 against 653 the other), so the trees alternate ABBA: after the moves and with this round's pins, 725 pass
  and 50 skip, 29.21, 29.66 and 30.08 s (medians 16, 17 and 19 %, the last through a spike to 37 %) against round 3's
  29.94, 29.90 and 29.78 s (medians 16–17 %) in the same minutes; before this round's pins, 29.61, 30.00 (a spike to 35
  %) and 29.54.
- *`scripts/verify`* (`verify.sh`: alone, the load sampled every 2 s by `typeperf`, its figure counting the run's own
  Lune): at 02:55 it stopped at luau-lsp's pass B, 7 type errors in the hidden-ownership pin, whose cases were a
  positional list typed by its first element (now named fields); then at 02:56:07–03:01:12, 12–51 % busy (median 17 %),
  tools, sourcemaps, T-META-07 (141 files, 987 requires) and luau-lsp's two passes clean, 775 pass, 0 fail, 0 skip (62
  files, 300.11 s), VERIFY GREEN (305.3 s), exit 0: T-PERF-01's F, C and X fixtures' longest stretch 0.273 ms (F2), the
  worst valid designs up to 58.33 ms (worst valid 9). Only these notes' verify line, `SPEC.md`'s T-PERF-01 row,
  E-S2.14's cost line and `README.md`'s Status sentence were written after it.

**What was written**

- `SPEC.md` (`spec_edits.py`–`spec_edits4.py`, every edit an exact match, prose rewrapped from its first changed line):
  §4.3's ownership (the rule, why not the cleaned ties' centre, the index or the turn, the mirror residual); §4.4's
  measure's rank and the cleaned parts' list (what an enclosed part owns: what no kept part holds, a filler that fills a
  sealed cavity its volume); §4.5 (no hidden part moves the mass or the balance but by what it owns, which review round
  4 found false where a hidden part changes how another's overlap is measured: round 5, below, says so); §5.6's hidden
  filler, ids and mirror, hidden cores and Y/Z rows (the Joints and owned volumes X01's, X01raw's and X02's kept flags
  bring); §14.1's gate; §14.6's T-DIF-04 and T-DIF-07 (a) and (c) (the pins, the guard sentence true at 1.5 times,
  `X_GRID` within 10, the cases now in `t.slow`); §16.18's `RANK_Q` row; §17.1 O11 (j) (round 3's major, the Joints with
  the kept flags, `f7ac37d`'s G "in count, not case for case" with #7517, the near-copy class at other figures
  with #7017); §17.2's hidden parts, ids and measure rows; §0.5's factors row.
- `SPEC-evidence.md` (`evidence_edits.py`, `evidence_edits2.py`): E-S2.14's opening and scratch list, guard (1), the
  moves' Joints and owned volumes, round 3's mirror images line for line but X02's, the guard pins' reach, a new bullet
  for round 4, the goldens, cost and tests.
- `README.md`'s Status; `.build-notes/m3/M3-spec-changes.md`, a round-4 item in plain words and the joint-count
  sentence; these notes: this section, the guard sentences and the mirror line of fixer W's section corrected in place,
  and the evidence list (the build notes are in the repo since 078df1c).

**Review 3's minors, as checked and written**

- The near-copy class at other figures (V2, both instances): §17.2's ids row and O11 (j) give V2's every-50th sweep (168
  Z images on 42 C09-based designs, 77 a played tier) and #7017's and #7661's tiers, each as on `f7ac37d`; checked on
  this tree with `nccheck`.
- 'In count, not case for case' (V2): O11 (j) with #7517 (Sharpening Hard → Normal on the tree, Hard on `f7ac37d`).
- The Joints and owned volumes that the kept flags bring (V2): §5.6's Y/Z row, O11 (j), E-S2.14's moves and the plain
  words, with X01's and X02's figures.
- Mirror images line for line but X02's (V2): E-S2.14 (twice) and fixer W's section here.
- V1's and V2's survivors and the guard sentence: the pins above; §14.6, E-S2.14 and fixer W's section true at 1.5
  times.
- T-PERF-01 under load (V1, V2): alone, twice, at medians 16 % (the machine's background about 8 %), it passes: worst
  valid 8 at 57.70 and 57.19 ms against the 60 ms guard, the F, C and X fixtures' longest stretch 0.274 and 0.279 ms
  (C01) against 0.35; inside `scripts/verify`, below.

**Open issues**

- For the lead: the adopted form departs from Y1's wording (below), on the measured grounds above; V2's repair as given
  and my first form stand in `var/B` and `var/B2` if the lead prefers one, each with its failing pins named above.
- S-PAR-02 runs in Studio on round 3's digest, which this round leaves byte for byte (the fixtures' group 136 designs,
  425,675 bytes, fnv1a32 892272501; the generated group 200 designs, 709,366 bytes, 611215233).
- The `--quick` gate holds by about 0.3 s quiet; the next heaviest fast cases the shift fix added, should it need more:
  'a mirror image keeps the near copy kept' (#1940, 37 ms), 'a hidden Grip part steers no rank' (C09, 32), this round's
  hidden-ownership pin (about 40) and `Sampling.spec`'s 'a cleaned part reorders no kept part's sub-grid budget' (29).
  M4's handoff raises the gate to 35 s.
- The residual §4.3 names (cleaned twins of one material exactly about the kept parts' centre, under that mirror image)
  moves the mass by a sampling difference only; it is an engineering residual, not a design question, so it carries no
  'Decision to confirm' mark.

**Deviations from the lead's decisions**

- Y1: not V2's repair as given but its material first, with the place from the centre of the kept parts in place of the
  index and before the turn (above): as given it let the ids move the mass shown by 2.05e-4 kg on an ordinary Ctrl+D
  build and a Z mirror image move it by 1.4e-6 kg where `f7ac37d` did not, so §4.3 states no place where an id decides
  between parts that are not the same in every way. The adopted form keeps everything the lead chose (B) for: no hidden
  part, no whole design's move, and the material deciding between twins of two materials, so that no mirror image moves
  their mass; it is round 3's byte for byte on every corpus and every mirror image dumped.
- Y2: the hidden-ownership pin also moves a box of two Iron fillers (V1's world planes pass it otherwise), and two pins
  were added for the adopted form (the ids along Z, the mirror copies).
- Y5: 8 cases moved to `t.slow` (heaviest first, until `--quick` read under 30 s quiet in alternating runs).
- MassProps' header and §4.4 and §5.6 now say what an Enclosed part owns (what no kept part holds), a pre-existing
  inaccuracy Reviewer V2 noted.

## After M3: the shift fix, round 5, fixer Z

The lead's decisions Z1–Z6 (task of 2026-11-19, after review round 4; `.build-notes/shift/shift_journal.txt`, its entry
of 07:05): Reviewer V1's fix A in `MassProps.ownership`, measured against round 4 (Z1); the reviewers' pins merged
without duplicates, each failing on its mutant (Z2); the text, each point checked first (Z3); `--quick` timed against
round 4 and the heaviest fast cases moved to `t.slow` (Z4); §14.1's L1 row cut to its rule and today's figures, its
history moved here (Z5); the goldens (Z6). Changed: `src/shared/Physics/MassProps.luau` (`ownership`'s higher sets, and
its header), `Sampling.luau`'s header; `tests/Physics/{Invariance, Verdict, MassProps, Cover}.spec.luau`; `SPEC.md`,
`docs/spec/SPEC-evidence.md`, `README.md`, these notes and `.build-notes/m3/M3-spec-changes.md`. Every claim was checked
against the code first, and every figure written was measured with Lune 0.8.9 through `Analyze.run` with
`measureInvalid` on byte copies: `var/z`, built from `shift-r4` (round 4's tree, equal to the working tree when this
round began) and copied into the working tree at the end, against `shift-r4`, `shift-r3` and `shift-base` (`f7ac37d`),
at most 3 Lune processes of mine at once, beside the M4 team's (its reviewers ran Lune from 07:09 on, 2 to 4 processes).
The scripts are in the Temp scratch `shift-fix-z/work`: fixer Y's `lib.luau` (with `r4`), `dump`, `mdump`, `idshuffle`,
`cmpdump.py`, `timing3` and `textedit.py` (which now keeps a word "#n" off a line's start); Reviewer V1's `ctrld`,
`hsteer2`, `mirturn` and `mirturnk` and Reviewer V2's `probe4`, `probe6b`, `probe7`, `ctrldone`, `sweepdup` and
`sweepspeck`, copied as `v1_*` and `v2_*`; my `lane.sh`, `after.sh`, `pins_z.py`, `mkmut_z.py`, `mutrun_z.sh`,
`cost_session.sh`, `quick_time.sh`, `casetimes.sh`, `rank_cases.py`, `moves_z.py`, `quickab.sh`, `text_z.py`,
`text_z2.py`, `text_z3.py`, `fix_43block.py`, `notes_z.py` and `verify.sh`. The trees are in `shift-fix-z/var` (`z`;
`mut_*`, the mutants; `zt`, `zm` and `r4t`, the trees with fixer Y's runner that times each case), the outputs in
`shift-fix-z/out`, with a step-by-step `NOTES.md`.

**What was built: an exact copy joins no higher set that holds its original (Z1)**

Review round 4's major A, checked in the code: `MassProps.ownership` builds each part's higher set H from the parts
before it in its order that overlap it, and measures a cleaned part's overlap exactly (polyhedra, `#H` ≤ `MAX_EXACT`) or
by sampling (a box from H's boxes, at the cleaned parts' one spacing `hCleaned`, which fits what the kept jobs leave of
`N_OVERLAP_WORK`, a job's work its cells × (1 + `#H`)). A Ctrl+D copy left in place, cleaned as an exact copy, entered
the H of every part below it that its original overlaps: an exact job could pass `MAX_EXACT` and be sampled, and every
sampled job's work grew, coarsening `hCleaned`. As built, Reviewer V1's hunk verbatim: in the loop that builds H, a part
whose solid is `Shapes.sameSolid` with one already in H is not added. Checked against the code: H's union is unchanged
(an exact copy is the same point set); kept parts never hold two exact copies (the verdict's `isCopy` cleans the lower
of any pair, and a kept part's H holds kept parts alone), so the kept parts' H, `hOverlap`, what is left for the cleaned
parts, the kept owned volumes, `owned.higher` as the factors read it (Thinness and Asymmetry take W's parts, kept
alone), every factor and G cannot move; a cleaned part's copy flag (`sameSolid` is bitwise, so transitive), its
`allPolyhedra` (the same shape code) and its box (`overlapBox` takes a minimum and a maximum over H's boxes) cannot
either; what can is how it is measured: exact again where the copy had made `#H` more than `MAX_EXACT` (the copy's
subsets gone), its sampled job's work (`nz` × (1 + `#H`) a row, the same cells and the same first part found at each),
and so `hCleaned` for every cleaned job, the units reported reaching Analyze's checkpoints alone (§4.9), no output. The
loop compares a part with H's members only, at most 23 on 24 parts, and reports no unit.

- *Against round 4* (`dump` at 17 digits, every output of `Analyze.run`): byte for byte on the 136 fixtures, Parity's
  200, the six seed streams and `0xBADC0FFE` and `0x31415927` (4,000) and all 33,389 plausible designs (37,725), against
  fixer Y's dumps of round 4's source (`y5`, whose `src` equals `shift-r4`'s; my dumps of `shift-r4`'s fixtures and
  Parity's 200 equal his byte for byte); the X and Z mirror images of the fixtures, Parity's 200 and plausible 1–11,130
  byte for byte; the id shuffles (3 a design) A17 alone on the fixtures, none on Parity's 200, as on round 4.
- *Ctrl+D copies* (Reviewer V1's `ctrld`: every part of a design with a cleaned part again in place, the copy cleaned
  and owning nothing; G, the tiers, the mass, the balance, the COM and every owned volume to the bit): every 5th
  plausible design from #1, 1,230 designs, 12,217 copies: none moves, not even in the last bits (930 of them take a slot
  past its maximum, which leaves nothing measured: round 6; round 4: 5 past 1e-12 on 2 designs, `wrapRings|C09|n4
  extra0.02 gap0.0010`, #8871, +5.641 g and `wrapRings|C09|n3 extra0.04 gap0.0020` +1.033 g, and 35 in the last bits;
  `f7ac37d`, V1's: 14 on 7 `pommelInBlock|C09` designs and 73); from #3, 1,206 designs, 12,004 copies: none (928 past a
  slot's maximum; round 4, V1's: 6 on 2 `wedgeInGuard|C05` designs, up to +0.52 g, and 26; `f7ac37d`, both reviewers' in
  review round 5: 24 on 12 designs, up to −6.908 g, and 73). Reviewer V2's `ctrldone` on the 39 `wrapRings|C09|n4`
  designs, every part copied: none on the tree, #8871's guard and two Blade Cylinders +5.641 g on round 4, none on
  `f7ac37d`. V1's `hsteer2`: `S3` (a Pommel filler under walls and two Guard fillers, one of them copied) and `S5`, `S6`
  (with the cleaned parts' share at 39,946 of 40,000, a copy of a wall or of a speck) no longer move (round 4:
  −3.148e-4, +2.5611e-3 and +2.5611e-3 kg).
- *What stays*, the residual the text names: V1's `S1` (in his own box, walls 0.02 and two Guard fillers: a Blade Dust
  Ball 0.015 buried in a wall on a filler, owning 8e-8) +1.1793e-3 kg, `S2` (two Block specks there, owning nothing)
  +1.1787e-3, `S4` (a Dust Ball buried in F2's guard at that share) +2.5843e-3, as on round 4 and `f7ac37d` (specks
  0.015 across, under `MIN_DIM`, which `Canonical` refuses; at 0.02, round 6: +1.1802e-3, +1.1787e-3 and +2.5843e-3);
  V2's `probe6b` (the sealed box with a filler 0.258 across and a Ball 0.22 buried in F2's pommel) +0.04231 kg, the
  balance +0.0688, the filler's owned volume 0.011797 → 0.017174, G the same, on the tree, round 4 and `f7ac37d`;
  `probe7`, fillers 0.256–0.264 with that Ball: 41.3, 42.3, 7.9, 8.1 and 5.2 g, the rest of its 0.002 grid over
  0.242–0.280 nothing (between its points about 0.2555–0.2655: round 6). On real designs (V2's sweeps, on the tree): a
  hidden exact copy of up to three cleaned parts a design, every 10th plausible design from #3 (633 designs, 824 copies
  of their 872 cleaned parts), moves nothing; a Dust Ball buried in the largest kept part, every 5th from #2 (1,151
  designs with a cleaned part, 1,011 with the speck), moves no part away from it.
- *The turn under a mirror image* (review round 4's major B; the tree's figures, each as round 4's and `f7ac37d`'s):
  V2's `probe4` reads line for line as his round-4 run (two Iron Dust Cylinders 0.07 × 0.05 crossed at one point on F2's
  guard face, one along Y and one along Z: either image swaps 6.94e-5 of owned volume, the mass 2.38e-5 kg, the balance
  1.25e-6; kept, an Iron and a Steel one crossed in the box's cavity, 1.41e-5 kg, and two Iron ones off its centre
  plane, Hammering 0.4355 → 0.4366); V1's `mirturn`, two crossed at 30° and 70° about Z at (0.2, 1.54), the Z image
  +1.405e-5 kg, and at (0.2, 1.45) the owned volumes swapped, the mass to the bit; `mirturnk`, two kept Iron Cylinders
  0.4 × 0.1 crossed at (0.2, 1.5, 0.16), 30° and 70° about Z: the Z image swaps their owned volumes and plays Hammering
  0.0324 → 0.0321, the mass to the bit, on the tree and `f7ac37d` alike.
- *Cost* (`timing3`: the tree, round 4 and `f7ac37d` rotated in one process, every T-PERF-01 case and C09, C04, F5, a
  collection before each run, 21 rounds in each of two orders, 07:19–07:22, no other Lune process, the machine 4–24 %
  and 6–40 % busy, medians 10 and 18 %): the tree / round 4 × 0.995 and × 0.997 (per case 0.947–1.057), the tree /
  `f7ac37d` × 0.996 and × 1.001: nothing measurable.
- *The goldens*: none moved (the dumps above, and `tests/golden` equal to round 4's byte for byte after the suite ran),
  so nothing was blessed: the regression, calibration and cost goldens, `parity_designs.bv1` and `parity.bv1.digest.txt`
  are round 4's (the fixtures' group 136 designs, 425,675 bytes, fnv1a32 892272501; the generated group 200 designs,
  709,366 bytes, 611215233).

**Pins, each failing on its mutant (Z2)** (`pins_z.py` after Reviewer V1's `pins_round4.diff`, applied whole;
`mkmut_z.py` builds each mutant on a byte copy of the tree, `mutrun_z.sh` runs its pin alone, `out/mut_*.txt`; the
failing assertion read)

- `Invariance.spec` 'T-DIF-04 a hidden part steers no ownership among hidden parts' gains V1's cases, an Iron box with a
  copy of its +z filler and the move along ±Z (V2's own Iron copy case is the same design, kept once): V2's
  `m4TiedCleaned` and V1's `mA_cleanedOwnTies` (a cleaned part placed from the cleaned parts it ties with) and
  `m4CentreAll` (the kept centre taken over every part) fail on the copy, owned volume 11 0.012168 → 0.005408;
  `mA_noMean` (the kept centres summed) on the move up Z, the same.
- 'T-DIF-04 a Ctrl+D copy left in place joins no higher set' (fix A's own, V1's, verbatim: the box with two Guard
  fillers and a Pommel filler under them and a wall, one Guard filler copied): fix A undone fails, owned volume 13
  4.0e-5 → 6.0e-17.
- 'T-DIF-07 (c) ids decide nothing between hidden twins' gains V2's Z image: `m4Signed` (a cleaned part's signed place
  first) fails, owned volume 5 1.7755e-4 → 9.70e-5.
- 'T-DIF-07 (c) a mirror image keeps who owns a hidden overlap' gains the X image, in one loop with the Z image: the
  mass and the balance for both materials (V1's) and with Iron and Steel the owned volumes part by part (V2's; of one
  material the copies are twins about the kept parts' centre and swap their owned volumes there, the residual §4.3
  names): `m4NoMaterial` (V1's `mC_noMaterial`) fails, Iron and Steel's X image, owned volume 5 9.78e-5 → 1.68e-4.
- `Verdict.spec`'s measure's rank (V1's): 'no part kept: from the origin, the −x one first' fails on `mA_noGuard` (0 /
  0); 'the lower first, then the kept ones from their centre, then the cleaned one' on `mC_noKeptSplit`; 'kept twins of
  two materials: the −x one first, Steel before Iron' on `mC_materialAll`.
- `MassProps.spec` (V1's): 'an extent 5e-10 cells past 4 keeps 4' (and 'a box 5e-10 thick has none') fails on
  `mG_cell04` (`CELL_EPS` 4e-10: 80 cells, not 64); 'a face 1.3e-12 past the other's' on `mG_clip16` (`CLIP_EPS`
  1.6e-12: 0.0080000000000000071 against 0.0079999999999480018) and 'a face 7e-13 past the other's' on `mG_clip04`
  (4e-13: 2.8e-14 off).
- The tree passes all seven cases, and `Invariance`, `Verdict` and `MassProps` whole with their `t.slow` cases (44, 41
  and 37 pass). The suite has 776 cases, 1 new (fix A's pin), T-PERF-01 the 640th.

**`--quick` (Z4)**

The M4 team's reviewers ran Lune from 07:09 on (2 to 4 processes, the machine 17–37 % busy, medians), so the cases were
first timed one by one against round 4 in the same minutes, as Z4 allows, and the quiet figure projected; at 07:45 a
quiet window came (no other Lune process at any run's end) and `--quick` was read alternating with round 4. Per-case
times: fixer Y's runner with a time per case (`runtimes`), `--quick`, the trees alternating ABBA, 3 runs each
(`casetimes.sh`, 07:26–07:30, medians 28–37 % busy; `rank_cases.py`). Round 5's pins add about 0.07 s against round 4
(the hidden-ownership pin's new cases +23 ms, the mirror pin's X images +13, the ids pin's Z image +7, fix A's pin 21.5,
`MassProps.spec`'s cells 3). The shift fix's fast cases of 30 ms or more went first, heaviest first, then the heaviest
Physics cases, each to `t.slow`, until the projection read 29 s or less with room for the spread between quiet sessions.

- *Moved* (round 5's tree, per-case medians at 28–37 % busy; in round 4's tree in the same minutes, `q6`, 17–23 %):
  'T-DIF-04 a hidden part steers no ownership among hidden parts' 66.0 ms (37.8, round 4's version, without this round's
  cases), 'T-DIF-07 (c) a mirror image keeps the near copy kept' (#1940) 46.6 (36.2), 'T-DIF-07 (c) a mirror image keeps
  who owns a hidden overlap' 35.6 (20.2, round 4's version), 'T-DIF-04 a hidden Grip part steers no rank' (C09) 35.1
  (32.4), the next of the shift fix's being `Sampling.spec`'s 'a cleaned part reorders no kept part's sub-grid budget'
  at 29.8; then `Cover.spec`'s '(f) a design past the cap' 1,170 (985.5) and '(a) exact on its model, against a brute
  force: tilted rods in a turned Cylinder, and near its axis' 1,019 (872.4), the two heaviest fast cases of all. Named
  in §14.6 where their pins are.
- *The projection* (`project_quick.py`): over the cases both trees run unchanged, the sum of round 5's runs over round
  4's in the same minutes is their load factor; round 5's sum at round 4's load over round 4's sum, times round 4's
  quiet figures (fixer Y's 29.21, 29.66 and 30.08 s, Reviewer V2's 29.97, 30.09 and 30.77 s), is round 5's quiet figure.
  With the first five moves (`q5`, 07:32–07:35, load factor 1.044): × 0.961, 28.1–29.6 s, median 28.9, at the line, so
  the sixth went too; with all six (`q6`, 07:35–07:39, 1.043): × 0.935, 27.3–28.8 s, median 28.1. The totals themselves
  swing with such load more than the moves do (`q5`: round 5 31.19, 32.35 and 31.77 s, round 4 31.21, 30.36 and 32.96
  s), so none of them is taken as a quiet figure; `q6`'s own runs read 30.24, 28.75 and 29.11 s for round 5 (720 pass,
  56 skip; medians 25, 21 and 26 % busy) and 30.86, 30.21 and 29.95 s for round 4 (725, 50; 23, 18 and 18 %). Read quiet
  (`quiet_session.sh`, the plain runner, ABBA, 07:45–07:49, no other Lune process at any run's end, medians 17–20 % busy
  with each run's own Lune, as fixer Y's quiet runs were read): round 5 28.08, 27.46 and 27.74 s (720 pass, 56 skip),
  round 4 29.76, 29.53 and 29.37 s (725, 50): 1.8 s under round 4, the projection's figure.
- *`scripts/verify`*: `verify.sh` samples the load every 2 s with `typeperf`, whose figure counts the run's own Lune
  (about 8 % of the 12 threads), and counts the other Lune processes at its start and end. On `var/z` at 07:39–07:44,
  13–32 % busy (median 20 %), and in the working tree at 07:48–07:54, 12–42 % (median 23 %), the M4 team's Lune back by
  its end, luau-lsp's two passes were clean and every case passed but T-PERF-01, on its timing alone (worst valid 8 at
  60.28 and 66.41 ms against the 60 ms guard). In a quiet window (`waitquiet.sh`: no Lune process, the load 2 % on three
  polls in a row), in the working tree at 07:55:11–08:00:13, 12–43 % busy (median 17 %), no other Lune process at its
  start or end: tools, sourcemaps, T-META-07 (141 files, 987 requires) and luau-lsp's two passes clean, 776 pass, 0
  fail, 0 skip (62 files, 296.01 s), VERIFY GREEN (301.2 s), exit 0; T-PERF-01's F, C and X fixtures' longest stretch
  0.273 ms (C01), the worst valid designs up to 57.78 ms (worst valid 8). What was written after it (§14.1's row,
  §14.6's `t.slow` names, §4.9's and §14.11's counts and runs, E-S2.14's goldens, cost and tests lines, README's verify
  sentence, the plain words' round-5 sentence and M3 rule, and this section) touches no source or test file.

**§14.1's L1 row (Z5)**

The row now holds its rule and today's figures; its history, word for word as round 4 left it, between its parentheses
after "all pass, ≤ 30 s":

> 25.9 s at M3's fix round 1, the machine quiet; 30.2–30.7 s under ordinary load, 7–29 % busy, in M3's review round 2
> and fix round 2, so the gate too needs a quiet machine; past 27 s quiet, fast corpora of generated designs move to
> `t.slow`, which L3 runs, as every one has since M3's fix round 1; 29.3–29.6 s quiet after the shift fix's pins, 716
> pass and 42 skip, and 35.6 s at 45–57 % busy; 29.64 and 29.99 s at 3–20 % busy after its round 2's, 727 pass and 42
> skip; after its round 3's, 730 pass and 42 skip, its cases timed one by one about 0.1 s over round 2's in the same
> minutes, 48.87 and 49.57 s at 40–83 % busy, fixer W, no quiet half hour to be had; 30.55 and 30.62 s at 15–29 % busy
> at night, the machine's own background about 10 %, fixer Y, so its round 4 moved to `t.slow` the 8 heaviest fast cases
> the shift fix had added, 0.48 s of them (§14.6, M3-notes): after it 725 pass and 50 skip, 29.21, 29.66 and 30.08 s
> against round 3's 29.94, 29.90 and 29.78 s, alternating, medians 16–19 % busy, the 30.08 s run through a spike to 37 %

**What was written (Z3)**

- `SPEC.md` (`text_z.py`, 18 edits; `fix_43block.py` keeps §4.3's paragraph after the overlap list at column 0, as it
  stood; `text_z3.py`, the figures measured last): §4.3, fix A where higher(p) is defined; the residual (how a hidden
  part has another's overlap measured, the mass and the balance point shown and with them the Damage and Balance stats,
  never G, a tier, Q or rarity; V2's sealed box and its band of filler sizes; the sweeps; what fix A closed, #8871); a
  turn as given deciding between parts at one place (V2's crossed Dust Cylinders); §4.4, the cleaned parts after the
  kept ones of their volume and height, and the mirror image's list with parts at one place (kept: V1's crossed Iron
  Cylinders, Hammering 0.0324 → 0.0321; V2's Iron and Steel ones, 1.4e-5 kg); §4.4's cleaned parts and §4.5 (the mass
  and the balance point by what a hidden part owns and by how it has another's overlap measured); §5.6's ids and mirror
  row and its hidden cores row; §16.10's `MAX_EXACT` row; §17.2's hidden parts, ids and measure rows; §14.1's L1 row
  (Z5); §14.6's T-DIF-04 and T-DIF-07 (a) and (c) (the pins above, `CELL_EPS` from below at half, `CLIP_EPS` from both
  sides, the cases moved to `t.slow`); §4.9's and §14.11's case counts and T-PERF-01's runs.
- `SPEC-evidence.md` E-S2.14: its opening and scratch list, a round-5 bullet, the goldens, cost and tests bullets.
- `README.md`'s Status; the MassProps and Sampling headers; `.build-notes/m3/M3-spec-changes.md`, the round-4 item's
  "only" and "one rare case" corrected, a round-5 item in plain words; these notes: this section, fixer Y's §4.5 line
  marked, and the evidence list.

**Open issues**

- `--quick` read 27.5–28.1 s at 17–20 % busy (round 4 29.4–29.8 s in the same minutes). Without the sixth move,
  `Cover.spec`'s tilted rods (about 0.9 s quiet), it would read about 28.4–29.0 s, at the line; the lead may move it
  back if the quiet re-time before the commit allows.
- S-PAR-02 runs in Studio on round 3's digest, which rounds 4 and 5 leave byte for byte (the fixtures' group 136
  designs, 425,675 bytes, fnv1a32 892272501; the generated group 200 designs, 709,366 bytes, 611215233).
- The residual §4.3 names (a hidden part changing how another hidden part's overlap is measured) moves the mass and the
  balance point shown, by up to 42 g of 1.32 kg on V2's constructed box, never G; it is M2's sampled measure, an
  engineering residual, so it carries no 'Decision to confirm' mark. A per-job cleaned spacing (V2's `F1`) closes the
  Ball case but moves 757 plausible masses by up to 54 g; a code fix whose cleaned jobs' spacings do not depend on each
  other within the cost bound is the lead's call, not tried here.

**Deviations from the lead's decisions**

- Z4: six cases moved, not five: with five the projection's median was 28.9 s, at the line, and round 4's own quiet runs
  spread over 1.6 s between sessions (29.21–30.77 s). Z3: beyond the listed passages, §16.10's `MAX_EXACT` row states
  fix A, fixer Y's section here keeps its §4.5 line with a note rather than a rewrite (it records what round 4 wrote),
  and the plain words' M3 rule ("an Enclosed part nothing") now says what an Enclosed part owns, which the SPEC already
  said since round 4. `textedit.py` keeps a word "#n" off a line's start (a line "#8871, ..." is no heading, but it
  ended the paragraph for the next edit).

## After M3: the shift fix, round 6, fixer AA

The lead's decisions AA1–AA3 (task of 2026-11-19, after review round 5; `.build-notes/shift/shift_journal.txt`, its
entry of 09:15): Reviewer V1's pin of fix A, shown on copies to pass on the tree and to fail on six of his mutants
(AA1); the text converged, SPEC §4.3's residual and §17.2's hidden-parts row cut to the mechanism, what moves and what
never moves and why, fix A's rule scoped to the original's slot (a scope review round 6 found false; round 7 states the
rule by §4.3's priority, below), one example and "rare on real designs", every sweep figure and every claim of none on a
sweep out of the SPEC and README into E-S2.14, these notes and the plain words with its experiment, sample, comparison
and measurer, both reviewers' tried texts merged (AA2); no golden or digest moving, README's Status naming the round,
this section, a round-6 bullet in E-S2.14 and a Round 6 item in the plain words (AA3). Changed:
`tests/Physics/Invariance.spec.luau` (fix A's pin), `SPEC.md`, `docs/spec/SPEC-evidence.md`, `README.md`, these notes
and `.build-notes/m3/M3-spec-changes.md`; no source (`src` byte for byte `shift-r5`'s, the tree after round 5, which the
working tree equalled when this round began). Every claim was checked against the code and the reviewers' outputs
(`shift-v1-5/out`, `shift-v2-5/out`), and every figure written is in one of them or was measured again here, with Lune
0.8.9 through `Analyze.run` with `measureInvalid` on byte copies (`var/tree`, `shift-r5`'s tree with the pin), against
`shift-r4` and `shift-base` (`f7ac37d`), at most 3 Lune processes of mine at once, beside the M4 team's. The scripts are
in the Temp scratch `shift-fix-aa/work`: Reviewer V1's `relabel`, `cwmirror` and `lib` (his round-5 scripts, the lib's
tree mine) and `mkmut6.py` (his `mkmut5.py` on `var/tree`); mine, `pinrun.sh`, `probes.sh`, `dupcount`, `ctrlcount2`,
`ballcells`, `wd.py` (a word diff), `textlib.py` and `text6.py` (the text, with `text6_round6.py` and `text6_notes.py`),
`textcheck6.py`. The outputs are in `shift-fix-aa/out`, with a step-by-step `NOTES.md`.

**The pin (AA1)**

V1's `pins_round5.diff` applies to round 5's `Invariance.spec.luau` as it stands, and the result equals his `var/pins5`
copy byte for byte. Fix A's case, 'T-DIF-04 a Ctrl+D copy left in place joins no higher set', keeps its box (F2 with a
sealed Iron box on its blade's top, walls 0.02, two Guard fillers that overlap, a Pommel filler under them and a wall)
and copies one Guard filler in place, then the same copy relabelled Pommel, in Steel, or wall 13 again, each against the
box without it (every owned volume within 1e-15, the mass and the balance within 1e-12, the fillers and the copy
cleaned); then a Pommel filler in the cavity's corner under walls 13 and 15, owning 2.78e-5, with wall 13 again; then
two Guard fillers at one centre, the second 0.258 × 0.19 × 0.2, which is no copy (the Pommel filler under them owns
4e-5 + 0.069 × (0.2 × 0.034 + 0.01 × 0.005), exactly). Run alone (`pinrun.sh`, `out/pin_*.txt`), it passes on the tree
and fails on each of V1's mutants (`mkmut6.py`, one edit of `MassProps.ownership`'s loop each) on the case aimed at it:

- `fixA_undone` (every earlier part that overlaps counted, round 4's): 'F2 + a filled box + a Guard filler again: owned
  volume 13: expected 4.0000000000004008e-05 ± 1e-15, got 5.9847959921199845e-17';
- `fixA_lastOnly` (a new part compared with the higher set's last member alone) and `fixA_sameSlot` (the mutant: a copy
  deduped only in its original's slot): '... + it relabelled Pommel', the same;
- `fixA_sameMaterial` (deduped only in its original's material): '... + it in Steel', the same;
- `fixA_cleanedOriginal` (only when the original is cleaned): '... + wall 13 again', the same;
- `fixA_centreOnly` (a part at a counted part's centre left out, a copy or not): 'the Pommel filler under two fillers at
  one centre: expected 0.00051265000000000013 ± 1e-15, got 0.0005782000000000031'.

V1 found the last five passing the whole `--quick` suite and `Invariance`, `MassProps` and `Parity` with their `t.slow`
cases (his `out/mutrun5b.log`). The case stays in `--quick`: the suite keeps its 776 cases.

**The text (AA2)**

The SPEC now keeps, in §4.3 after the overlap list and in §17.2's hidden-parts row: the mechanism (above another hidden
part, a hidden part joins its higher parts, which takes the overlap from exact clipping to sampling or samples a larger
box; a sampled overlap of its own draws on the cleaned parts' share of `N_OVERLAP_WORK` and coarsens their one spacing);
what moves (the mass and the balance point shown, and with them the Damage and Balance stats) and what never does, and
why (G, a tier, Q and rarity: no factor reads a cleaned part, the kept parts' overlaps are measured first and among kept
parts alone, T sums kept parts only, stats never feed Q or rarity); fix A's rule (round 6 scoped it by the slot, which
review round 6 found false both ways; round 7 states it by §4.3's priority, below); Reviewer V2's sealed box as the one
example; and that it is an engineering residual of M2's sampled measure, present at M3's commit and rare on real
designs, the sweeps in E-S2.14. Out of the SPEC went the band, V1's specks, the 824 copies, the 1,011 Balls, the 24,221
Ctrl+D copies, #8871 and `f7ac37d`'s Ctrl+D figure (§4.3, §17.2's hidden-parts row), the 24,221 copies and #8871 (§5.6's
hidden-cores row), and in §17.2's hidden-parts row V1's near-copy sweep (13,522 cases on 2,644 designs) and round 2's 71
designs; each is in E-S2.14, scoped (the round-3 bullet holds the last two). The CornerWedge joins §4.4's lists, §5.6's
and §17.2's ids rows and README; §14.6 describes the pin. E-S2.14's round-5 bullet, round 5's section here and the plain
words' Round 5 item are corrected in place where they were false, and E-S2.14's round-6 bullet, this section and the
plain words' Round 6 item carry the figures. Where the reviewers' tried texts differ, the one scoped to its measurement
is taken:

- the exact-copy rule: V1's scope by the slot (false, review round 6; round 7 states the rule by §4.3's priority,
  below), with "where the design stays valid" added, which round 7 keeps, since a copy that takes a slot past its
  maximum makes the design invalid (`SlotTooMany`, §4.2) and nothing is measured;
- V1's specks: in his own box (V1's wording) and in V2's, where they move the mass by what they own alone (both);
- `f7ac37d`'s Ctrl+D figure: over the whole sweep, 38 copies on 19 designs, up to 6.9 g (V2's), with V1's 0.89 g kept as
  the half from #1;
- the band: about 0.2555–0.2655 (V1's `band`), with V2's `probe7b` on its 0.001 grid;
- the buried Balls: no other part's owned volume moves (both); on 8 the Ball, wholly inside its Block, owns 8.1e-6 by
  its own sampled overlap (V2's reading; V1's "not wholly inside" does not hold, below);
- the counts: V1's, with his 1,978 split by cause (below); the CornerWedge: V1's.

**Checked and measured again** (my runs; the tree, `shift-r4` and `f7ac37d`)

- Fix A's scope, in the code: `MassProps.ownership` orders the parts kept first, then by slot rank (§3.7), then by the
  measure's rank, and adds to a part's higher set H each earlier part that overlaps it, unless an exact copy of it is in
  H already. A Ctrl+D copy in its original's slot and material ties its original on every key but the index, so it comes
  after it, or after every kept part if the original is kept: whatever H it would join holds the original already, and
  its own H holds the original, so it owns nothing and makes no job. A hidden original's copy relabelled into an
  outranking slot comes first instead and joins the H of the hidden parts between the two; the original then finds it in
  its own H and owns nothing, which is the original relabelled (`relabel`, below). Both are examples of the rule round 7
  states by this order (below).
- V1's `relabel` (`out/relabel_*.txt`; his box as `S4`, the fillers 0.23 and 0.22 long, two Dust Balls 0.02 in its wall,
  every build through `Canonical.draft`): the copy of filler 18 relabelled Blade, mass 1.288800782 kg +2.3865e-3, the
  balance +4.1979e-3, G the same (0.0928, 0.4204, 0.1939), and 18 itself relabelled Blade the same, on the tree, round 4
  and `f7ac37d`; in `S3` that copy leaves the mass on the tree (the balance −4.4e-16), and moves it −3.148e-4 kg on
  round 4 and `f7ac37d`; in `S0`, nothing.
- V1's `cwmirror` (`out/cwmirror_*.txt`): F2 with kept CornerWedges 0.3 × 0.1 × 0.1, Iron, and 0.1 × 0.1 × 0.3, Steel,
  at (0.2, 1.5, 0.12) against its guard's front face: the X and the Z image own their overlap the other way, 3.81444e-4
  / 3.90685e-4 → 5.635e-4 / 2.08630e-4, the mass +3.641e-6 kg, the balance +2.516e-7, G the same; both Iron, the owned
  volumes so swapped and the mass the same; `f7ac37d` the same.
- `dupcount` (`out/dupcount_live.txt`): V2's `sweepdup` sample, every 10th plausible design from #3 with a cleaned part,
  is 633 designs holding 872 cleaned parts; it copies the first three of each, 871 copies, of which 824 were measured
  (his `out/sd_live_pl10.txt`).
- `ctrlcount2` (`out/ctrlcount2_*.txt`): of `ctrld`'s 24,221 copies, 1,858 take a slot past its maximum (`SlotTooMany`,
  which stops `Analyze.run`'s quick stage, so nothing is measured) and 120 only take the design past `MAX_PARTS`, which
  `Canonical` alone asks (`TooManyParts`), so `ctrld`, which calls `Analyze.run` directly, measured them, and none
  moved; V1's 1,978 (`ctrlcount`) are both, and the 22,243 others keep the design within those limits (Reviewer V2's
  `ctrlvalid`, review round 6: 21,628 on valid designs, 615 on 105 `grille` and `tiled` designs that are invalid without
  any copy, their Blade keeping no kept part, `SlotMissing`, which `ctrld` measured through `measureInvalid`). V1's
  report and the task named all 1,978 `SlotTooMany` and unmeasured; the text says what `ctrlcount2` found.
- `ballcells` (`out/ballcells_live.txt`): a Ball 0.07 across inside a Block owns its volume less the cells whose
  midpoint lies in it: 8.0944e-6 at 4 cells a side (32 midpoints × 0.0175³ = 1.715e-4 against 1.795944e-4), 0 at 5 and 6
  (the estimate passes the Ball's volume and is capped), and its box can have no other count (6 at `H_OVERLAP`, 4 at the
  coarsest). `sweepspeck` buries its Ball at the centre of a Block with every side over 0.09, so wholly inside; on the 8
  designs the cleaned parts' spacing gives its box 4 cells a side, so it owns 8.094e-6 and the mass moves +6.37e-5 kg
  (V1's `speckall`, V2's `ss2_live_pl5.txt`): V1's "not wholly inside", which the task repeated, does not hold, and V2's
  reading is written.

**Tests run** (in the working tree with the pin, `timed.sh` and `quietverify.sh`; no test reads the text, which
was finished after all but the last `--quick`)

- `lune run tests/run -- --quick` (18:25:21–18:25:51, no other Lune process at its start or end, `typeperf` 18–29 %
  busy, median 22 %, its own Lune counted): `RESULT pass=720 fail=0 skip=56 files=62 time=29.39s`, exit 0; round 5 read
  27.46–28.08 s quiet at medians 17–20 %, and V1 put the pin's new cases at about 0.08 s.
- `lune run tests/run -- --quick` again on the final tree, the text in (18:56:01–18:56:31, no other Lune process at its
  start or end, 16–35 %, median 20 %): `RESULT pass=720 fail=0 skip=56 files=62 time=28.74s`, exit 0.
- `lune run tests/run -- --filter Physics/Invariance`, the pin's file whole with its `t.slow` cases (18:26:04–18:26:49,
  no other Lune process at its start or end, 14–30 %, median 20 %): `RESULT pass=44 fail=0 skip=0 files=62 time=44.78s`,
  exit 0.
- `lune run scripts/verify` (18:27:08–18:32:32, 16–89 %, median 22 %, no other Lune process at its start or end, the
  load up to 89 % between 18:29:43 and 18:31:11, Roblox Studio open): tools, sourcemaps, T-META-07 and luau-lsp's two
  passes clean, `RESULT pass=775 fail=1 skip=0 files=62 time=317.94s`, `TESTS FAILED (323.4 s)`, exit 1: T-PERF-01
  failed on its timing alone, worst valid 8 at 62.42 ms against the 60 ms guard.
- `lune run scripts/verify` (18:33:37–18:38:55, 15–42 %, median 22 %, no other Lune process at its start or end, started
  after three polls 10 s apart with no Lune process and the load at most 15 %): tools, sourcemaps, T-META-07 and
  luau-lsp's two passes clean, `RESULT pass=775 fail=1 skip=0 files=62 time=311.99s`, `TESTS FAILED (317.5 s)`, exit 1:
  T-PERF-01 failed on its timing alone, worst valid 9 at 60.88 ms against the 60 ms guard.
- `lune run scripts/verify` (18:48:29–18:53:46, 16–36 %, median 22 %, no other Lune process at its start or end, started
  after three polls 10 s apart with no Lune process and the load at most 10 %): tools, sourcemaps, T-META-07 and
  luau-lsp's two passes clean, `RESULT pass=776 fail=0 skip=0 files=62 time=311.26s`, `VERIFY GREEN (316.8 s)`, exit 0;
  T-PERF-01's worst valid designs up to 59.165 ms (worst valid 8), the F, C and X fixtures' longest stretch 0.285 ms
  (C05).

**What was written (AA2, AA3)**

- `SPEC.md` (`text6.py`, exact single edits, each edited paragraph rewrapped at 120 columns as it stood): §4.3's
  residual; §4.4's mirror lists (the CornerWedge); §5.6's ids row (the CornerWedge) and hidden-cores row (fix A scoped,
  its figures out); §14.6's T-DIF-04 (the pin's cases); §17.2's hidden-parts row (the residual as §4.3 keeps it, V1's
  near-copy sweep out) and ids row (the CornerWedge).
- `SPEC-evidence.md` E-S2.14: its opening and scratch list, the round-5 bullet corrected, a round-6 bullet, the goldens
  and tests bullets.
- `README.md`'s Status (the CornerWedge, fix A scoped, round 6 named, verify's run); these notes (round 5's section
  corrected where it was false: its heading, `ctrld`'s counts and `f7ac37d` from #3, V1's specks' size, the band,
  `sweepdup`'s scope; this section; the evidence list); `.build-notes/m3/M3-spec-changes.md` (the header's date, the
  Round 5 item corrected, a Round 6 item, "Rounds 4, 5 and 6").
- `tests/Physics/Invariance.spec.luau`: V1's pin, as his diff has it; no other test.

**Open issues**

- The lead's quiet verify and `--quick` re-time before the commit (here, with Roblox Studio open, verify was green once
  in three at a median of 22 % busy, worst valid 8 at 59.165 ms against 60, and `--quick` read 29.39 and 28.74 s at
  medians of 22 and 20 %, about the 29 s that §14.1 keeps for the noise and under its 30 s gate). S-PAR-02 passed on
  round 5's code (the lead, 18:17–18:21, `.build-notes/shift/spar02_hashes_r5.txt`); round 6 leaves the 76 files its
  sha1 list names as they were (`sha1sum -c`), and the digest is round 3's, which rounds 4 to 6 leave byte for byte (the
  fixtures' group 136 designs, 425,675 bytes, fnv1a32 892272501; the generated group 200 designs, 709,366 bytes,
  611215233).
- AA2's rule on sweep figures was applied to what the SPEC and README say of hidden parts' reach (the residual, fix A,
  the Ctrl+D copies, the specks, the band, the hidden copies and Balls, and V1's near-copy sweep in §17.2's hidden-parts
  row). The shift fix's other sweep figures stay where earlier rounds wrote and the reviewers checked them: §4.3's
  guard-2 sign, §4.4's twin-height drags, §5.6's and §17.2's mirror counts (O11 (l)) and near-copy figures, §17.2's
  measure row's drift by round (its "nothing on any corpus" for rounds 4 and 5) and README's "on every fixture and
  generated or plausible design measured"; the lead may want those moved too.

**Deviations from the lead's decisions**

- AA2 (5): the 8 buried Balls are written wholly inside their Block, owning 8.1e-6 by their own coarse sampled overlap,
  not "not wholly inside" (`ballcells`, above). AA2 (6): the 1,978 Ctrl+D copies are 1,858 past a slot's maximum,
  unmeasured, and 120 past `MAX_PARTS` alone, which `ctrld` measured (`ctrlcount2`), not all `SlotTooMany`. AA2 (1):
  "where the design stays valid" added to the exact-copy sentence.
- Beyond the listed passages: §14.6's T-DIF-04 now names the pin's new cases; E-S2.14's round-5 bullet, round 5's
  section here and the plain words' Round 5 item are corrected in place, each pointing to round 6.

## After M3: the shift fix, round 7, fixer AB

The lead's decisions AB1–AB4 (task of 2026-11-19, after review round 6; `.build-notes/shift/shift_journal.txt`, its
entry of 19:50): fix A's rule stated by the order alone, in one canonical sentence used wherever the copy rule appears,
its measured cases labelled as examples in E-S2.14 (AB1); the summaries quoting the sweep, V1's text (AB2); the 22,243
split, V2's wording (AB3); the minors (AB4). Changed: `SPEC.md`, `docs/spec/SPEC-evidence.md`, `README.md`, these notes
and `.build-notes/m3/M3-spec-changes.md`; no source and no test (`src` and `tests` byte for byte `shift-r6`'s, the tree
after round 6, which the working tree equalled when this round began). The scripts are in the Temp scratch
`shift-fix-ab/work`: Reviewer V1's `lib.luau` (its tree `shift-r6`), my `rankslot.luau` and `keptcopy.luau`, fixer AA's
`textlib.py`, my `text7.py` and `textcheck7.py`; the outputs are in `shift-fix-ab/out`, with a step-by-step `NOTES.md`.

**The rule (AB1)**

SPEC §4.3 now states fix A's rule in the ruling's two sentences but for one phrase: "An exact copy of a part already
among another part's higher parts is not counted there again (above). So where the design stays valid (§4.2), of a part
and its Ctrl+D copy left in place the one that comes later in the priority above (kept parts, then slot rank, then the
measure's rank of §4.4) adds nothing: a copy that comes after its original changes nothing measured, and one that comes
before it takes its original's place, as its original given the copy's slot and material would (E-S2.14 has measured
examples of both)." The ruling has "in the measure's rank (§4.4)". Checked in the code first: `MassProps.ownership`
orders the parts kept first, then by the slot's rank (§3.7), then by `Sampling.measureRanked`, whose cleaned parts go by
the material's name first and by the slot's name late (Grip before Guard). Read with the measure's rank alone, the
sentence is false across slots three ways, and with §4.3's priority every case holds (`rankslot`, `out/rankslot.txt`,
and `keptcopy`, `out/keptcopy.txt`, on the tree and `f7ac37d`; the figures are in E-S2.14's round-7 bullet). §17.2's
hidden-parts row states the same sentence ("§4.3's priority"), §5.6's hidden-cores row and README the same with the
parentheses dropped, E-S2.14's round-6 item (1) the same with its measured cases labelled (V2's `relabel6`, V1's
`material` and `relabel`), and the plain words the same in plain words. Round 6's slot-scoped statements, in round 6's
section here, E-S2.14 and the plain words, now point to it, and `fixA_sameSlot` is described as the mutant, a copy
deduped only in its original's slot (E-S2.14's tests bullet, round 6's section here).

**The rest (AB2–AB4)**

- E-S2.14's round-6 bullet and the plain words' Round 6 item quote the sweep (V1's: no Ctrl+D copy of `ctrld`'s sweep
  moving anything where it was measured; none of the copies the reviewers measured, left in place in their original's
  slot and material, changes anything).
- The 22,243 split (V2's `ctrlvalid`): 21,628 on valid designs and 615 on 105 `grille` and `tiled` designs invalid
  without any copy (E-S2.14's round-6 bullet, round 6's section here, the plain words' Round 5 and Round 6 items).
- §5.6's near-copy row and §17.1 O11 point to E-S2.14 for V1's near-copy sweep (V2's wording); README and the plain
  words say S-PAR-02 passed on round 5's code (3 fresh Play sessions, 2026-11-19) and that rounds 6 and 7 change none of
  the files it reads; "right after" became "after" (round 6's section).
- README's Status names round 7; E-S2.14 has a round-7 bullet, and its opening and scratch list name review round 6 and
  round 7; the plain words have a Round 7 item (and "Rounds 4 to 7 moved nothing").

**Checked**

- `src` and `tests` byte for byte `shift-r6`'s (`diff -rq`), and the 76 files of
  `.build-notes/shift/spar02_hashes_r5.txt` unchanged (`sha1sum -c`: 76 OK).
- `textcheck7.py` against `shift-r6`'s texts: table rows and pipes unchanged (SPEC 1,160 rows, the evidence 715), the
  decision marks unchanged, no new or changed prose line over 120 columns.
- A grep for the copy rule's old scopes ("original's slot", "outranks", "more important slot", "slot and material", "no
  Ctrl+D copy") finds only examples with their builds, the sweep's sample as measured, round 6's history pointing to
  round 7, the mutants' descriptions and the pin's case name, V1's, which stays with the frozen tests.
- `lune run tests/run -- --quick` in the working tree, once (20:10:14–20:10:42, no other Lune process at its start or
  end, `typeperf` every 2 s 12–18 % busy, median 15 %, its own Lune counted): `RESULT pass=720 fail=0 skip=56 files=62
  time=27.06s`, exit 0. The lead re-runs `scripts/verify` quiet.

**Open issues**

- The ruling's sentence changed in one phrase (above); the lead may prefer another wording of §4.3's priority.
- `MassProps.ownership`'s comment ("so a Ctrl+D copy left in place changes no part's count of higher parts, its overlap
  box or the cleaned parts' budget") and the pin's case name ('T-DIF-04 a Ctrl+D copy left in place joins no higher
  set') overstate the rule the same way; both wait for M4's merge, since S-PAR-02's record freezes `src` and this round
  leaves `tests` as they are.
- The lead's quiet verify and `--quick` re-time before the commit.

**Deviations from the lead's decisions**

- AB1: "in the measure's rank (§4.4)" became "in the priority above (kept parts, then slot rank, then the measure's rank
  of §4.4)" in §4.3 and "in §4.3's priority" elsewhere, since the ruling's phrase reads false across slots (above);
  every other word of the sentence is the ruling's.

## After M3: the shift fix, rounds 8 to 10, the lead

Review round 7 (V1, V2) confirmed round 7's copy rule, fixer AB's phrase included, on every case measured (V2's 717),
and found four case summaries that did not say whether the original is kept or hidden. Review round 8 (V1, V2) confirmed
the lead's merge of those words, classed every sentence about copies in the five texts (531; V2's `shift-v2-8/NOTES.md`)
and found three statements broader than what was measured; round 9's checker found one more, in a word the lead had
applied. In the fix's rounds 8 to 10 the lead applied the reviewers' tried words, each tried in their copies with the
layout checks, and nothing else: no source, test or golden changed, and S-PAR-02's 76 files are as recorded (their sha1
checked). The findings, the measurements behind each and the rulings are in `.build-notes/shift/shift_journal.txt` (its
rulings on review rounds 7, 8 and 9) with the reports beside it; the measuring scripts are in the Temp scratch
`shift-v1-7`, `shift-v2-7`, `shift-v1-8`, `shift-v2-8` and `shift-chk-9`. The minors the reviewers listed wait for after
the commit (the same journal). Before the commit the lead's `scripts/verify` was green on the final tree, 776 pass in
291.7 s at 10–36 % busy (median 14 %), worst valid 8 at 57.573 ms, after one run that failed on T-PERF-01's timing alone
at 7–30 % (median 16 %, agents writing notes beside it: worst valid 8 at 61.17 ms); `--quick` 720 pass, 56 skip, 28.02 s
at 13–18 % (median 15 %); S-PAR-02's 76 files match their record (their sha1 checked).

## Where the evidence lives

- `SPEC.md`: §0.5, §4.1–§4.7, §4.9, §5 (its promise), §5.1, §5.2, §5.5, §5.6, §14.1, §14.6, §14.7, §14.10, §14.11,
  §16.1, §16.2, §16.10, §16.18, §16.32, §17.1 O7 and O10–O12, and §17.2's S2 rows.
- `docs/spec/SPEC-evidence.md`: E-S2.13 (M3 as built), E-S2.14 (the shift fix, after M3), and the rows changed in
  E-S2.5, E-S2.7, E-S2.9, E-S8.4, E-S8.5 and E-S8.6. `docs/spec/prototypes/S2/m3/`: `limits.luau` and its output.
- `tests/Physics/`: Edge, Factors, Difficulty, Invariance, DifficultyTable, Perf, Parity and SPar02 specs,
  `DifficultyHelpers.luau`; `tests/FixtureSet/{Calibration, Regression, Cost}.spec.luau` and `Measured.luau`;
  `tests/fixtures/{Calibration, Regression, Cost, WorstDesigns, Parity}.luau`; `tests/golden/difficulty_*.bv1`,
  `parity.bv1.digest.txt`, `parity_designs.bv1.golden.txt`; `tests/studio/e2e/S-PAR-02.luau`; after M3, the shift fix's
  source and tests (fixer S's, fixer U's, fixer W's, fixer Y's and fixer Z's sections, and fixer AA's pin) and its text
  (fixer T's, fixer V's, fixer X's, fixer Y's, fixer Z's, fixer AA's and fixer AB's).
- In the repo since 078df1c (outside it before): `.build-notes/m3-plan/` (the plan, its companion scripts and outputs,
  the critique and the lead's decisions), `.build-notes/m3/` (the builders' and verifiers' reports, the journal) and
  `.build-notes/shift/` (the shift fix's groundwork, fixers' and reviewers' reports and the lead's journal). The
  builders' and fixers' scratch scripts (`m3-b1` to `m3-b4`, `m3-fix1a`, `m3-fix1b`, `m3-fix1c`, `m3-fix2d`, `m3-fix2e`,
  `m3-fix3f`, `m3-fix3g`, `m3-fix4h`, `m3-fix4i`, `m3-fix5m`, and after M3 `shift-frame`, `shift-census`, `shift-fix-s`,
  `shift-fix-t`, `shift-fix-u`, `shift-fix-v`, `shift-fix-w`, `shift-fix-x`, `shift-fix-y`, `shift-fix-z`,
  `shift-fix-aa` and `shift-fix-ab`, and the reviewers' `shift-v1-1`, `shift-v2-1`, `shift-v1-2`, `shift-v2-2`,
  `shift-v1-3`, `shift-v2-3`, `shift-v1-4`, `shift-v2-4`, `shift-v1-5`, `shift-v2-5`, `shift-v1-6` and `shift-v2-6`, in
  the session's Temp scratch) lose week-old files: what they measured is in the sections above and in E-S2.13 and
  E-S2.14, and the 2 % rule's script is kept in `prototypes/S2/m3/`.
