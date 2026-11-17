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

## Where the evidence lives

- `SPEC.md`: §0.5, §4.1, §4.2, §4.4, §4.5, §4.6, §4.7, §4.9, §5 (its promise), §5.2, §5.5, §5.6, §14.1, §14.6, §14.7,
  §14.10, §14.11, §16.10, §16.18, §16.32, §17.1 O7, O10 and O11, and §17.2's S2 rows.
- `docs/spec/SPEC-evidence.md`: E-S2.13 (M3 as built), and the rows changed in E-S2.5, E-S2.7, E-S2.9, E-S8.4, E-S8.5
  and E-S8.6. `docs/spec/prototypes/S2/m3/`: `limits.luau` and its output.
- `tests/Physics/`: Edge, Factors, Difficulty, Invariance, DifficultyTable, Perf, Parity and SPar02 specs,
  `DifficultyHelpers.luau`; `tests/FixtureSet/{Calibration, Regression, Cost}.spec.luau` and `Measured.luau`;
  `tests/fixtures/{Calibration, Regression, Cost, WorstDesigns, Parity}.luau`; `tests/golden/difficulty_*.bv1`,
  `parity.bv1.digest.txt`, `parity_designs.bv1.golden.txt`; `tests/studio/e2e/S-PAR-02.luau`.
- Outside the repo: `ROBLOX/.build-notes/m3-plan/` (the plan, its companion scripts and outputs, the critique and the
  lead's decisions) and `ROBLOX/.build-notes/m3/` (the builders' and verifiers' reports, the journal). The builders' and
  fixers' scratch scripts (`m3-b1` to `m3-b4`, `m3-fix1a`, `m3-fix1b`, `m3-fix1c`, `m3-fix2d`, `m3-fix2e`, `m3-fix3f`,
  `m3-fix3g`, `m3-fix4h`, `m3-fix4i`, `m3-fix5m` in the session's Temp scratch) lose week-old files: what they measured
  is in the sections above, and the 2 % rule's script is kept in `prototypes/S2/m3/`.
