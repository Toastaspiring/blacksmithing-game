# M3: the lead's decisions on plan-r2.md and its critique (2026-11-14)

The builders follow `plan-r2.md` with the changes below. They take precedence over the plan where the two differ. The
critique is `plan_r2_critique_result.json` (its scripts are under the Temp scratch `m3-plan-r2-critic\proto\c_*.luau`,
which loses week-old files; copy what you reuse). Every item here was reported by the critic and re-measured by it on
`m2x-r4-base`. Fix round 4 moved no fixture verdict (only 14 plausible wrap-ring grips), so the plan's fixture numbers
stand. Re-run the plan's baseline scripts on the committed M2 tree anyway, as [11] says.

## Majors

**L1. T-EDG-01 item 2: precision (critique major 1).** [7.1]'s cutIndex column goes to 6 decimals:

- F1 = F5 0.724180; F2 0.425000; F3 1; F4 0.134375
- C01 0.300000; C02 = C12 = C14 = C15 0.766667; C04 1; C05 0.158369; C06 0.890676; C07 0.313333; C08 0.617500; C09 1;
  C10 = C11 0.271528; C13 0.765380

Item 2 then reads: "cutIndex within 1e-6 of [7.1]'s 6-decimal column; EdgeLength within 5e-5 of its 4-decimal column".
The same change applies in builder 1's "Numbers that must come out". Builder 1 re-measures both columns on the committed
tree first.

**L2. [8.2]: the factor-level comparison with the prototype (major 2).** Replace the Volume / SurfaceComplexity / Joints
bullet with the following.

- Volume is within 1e-12 on every shared-verdict fixture.
- SurfaceComplexity and Joints are within 1e-12 where `Analyze.run`'s `budget.hSurf` equals the prototype's hSurf.
- Where the hSurf values differ (X02: 0.04 against 0.06; P1), check SurfaceComplexity and Joints against the build's own
  exposure, as Reference.spec does: SurfaceComplexity = Σ exposedKept / (6·cbrt(Σ ownedVolume)²) over `WorkSet.select`,
  and Joints from `exposure.contact` and the touching graph.

Delete "since the build's owned volumes differ by up to about 4e-15" as the reason.

**L3. Y translation: make the outline exact (major 3, option (a)).** T-DIF-07(a) is a SPEC contract, and §5 promises
that invisible construction choices cannot move a tier. The outline therefore becomes exact by construction.

- Run Douglas–Peucker on the integer crack-vertex lattice. Vertices are (i, j); midpoints, if used, sit at doubled
  coordinates.
- The tolerance is `EDGE_SIMPLIFY` (doubled per step, as now) in cell units. Compare squared distances as `cross² >
  tol²·len²`, with every coordinate an integer. Check that the magnitudes stay below 2^53. Ties take the first maximum,
  by index.
- Convert only the kept points to blueprint XY: x = (i0 + i)·H, y = Y0 + (j0 + j)·H. Compute each segment's length from
  its integer differences × H, so equal lattices give bit-equal lengths.
- Before adopting it, compare against the prototype on the 64 fixtures (chains, points, EdgeLength, cutIndex).
  - If no fixture tier moves and no §5.5 / E-S2.9 4-decimal value moves by more than 0.0005, keep (a). Record every
    difference in `docs/build/M3-notes.md`, and have builder 4 update the SPEC values that change at 4 decimals.
  - Otherwise fall back to the critic's option (b): item 6 is exact on F1–F5 and C01–C15 only, and EdgeLength on Gen is
    within `TOL_EDGE_REL`. T-DIF-07(a) asserts |ΔG| ≤ `TOL_G_INVARIANT` on the fixtures and only prints it on Gen. The
    Gen #131 figure (|ΔG| 0.0037) goes into §17.1 O11 **[Decision to confirm]**. Say which of the two happened.
- Under (a), item 6 asserts bit-identical edges under Y shifts on Gen designs. These include TestRng 0x5EED0007 #89 and
  0x5EED0001 #131 at +0.2, which must be in the test. T-DIF-07(a) holds on Gen with |ΔG| exactly 0 for Y shifts. X
  mirrors stay as the plan says: not exact, T-DIF-08 reports.

**L4. D1's evidence and text (major 4).**

- In [7.8], add the proud-core family (the M2 verifier's `c_lam.luau` family, the critic's `c_proud.luau` /
  `c_proud2.luau`): 96 families, 12 core crossings, |ΔD| 0.27–0.41, 7 tier flips on 6 crossings. Thinness carries
  0.31–0.36 of the jump. Also add the plan's own sandwich rows 7–9 K → K+S: |ΔD| up to 0.3713, 2 flips.
- D1 stays option 0 under §17.1 O10 **[Decision to confirm]**, with its real reason stated:
  - merging Thinness' chords through cleaned parts would remove the Thinness term of the jump (up to about 0.36);
  - but it would give hidden filler between plates a Thinness channel, against §5's promise;
  - the verdict-side fix belongs to the verdict.
- §17.2 keeps the jump figure, re-measured: "0.27–0.41 over 12 crossings in 96 families". It keeps "because cleaning it
  opens the chord in Thinness" and adds "and, for a recessed core, SurfaceComplexity and Volume".
- Delete "up to about 0.32", "Thinness is the minor channel", "no M3-side rule reaches the sandwich" and the
  instruction to drop 0.34–0.47.

**L5. TOL_EDGE_REL moves to builder 1 (major 5).** `tests/lib/Tol.luau`'s `TOL_EDGE_REL` 0.02 goes in builder 1's file
table. Builder 3 keeps `PERF_RUNS`, and builder 4 keeps `PARITY_*`.

**L6. Charge the edge's cell-size ladder (major 6).**

- [3.2] Charges gains: "Ladder: spend(#blade + #hilt) for each row of each rung tried (inside the ladder's fit
  test)". The per-cell charge stays as listed.
- [9.4], R3 and D3 cite the measured figures:
  - the plan's per-cell charge alone gives 0.273 / 0.274 ms (valid 8 / 9);
  - with the ladder charged, the raster's stretch is 0.078 / 0.077 ms, and M3's longest becomes Thinness' per-probe
    charge at about 0.21 ms.
- T-PERF-01 asserts every gap ≤ 0.35 ms on medians, run alone. Exception: M2's fix round 5 may narrow §14.11's
  T-PERF-01 row to assert gaps on the F, C and X fixtures only, reporting P1–P5 and `worst_designs.luau` against them.
  That happens if M2's longest stretches are found to be allocation and collection. Build T-PERF-01 to whatever §14.11
  says once M2 is committed.

## Minors (all taken as the critic wrote them)

- **L7.** [7.2] and [15] get a note: "tab.txt's cutIndex and physics use the prototype's frame. P2's golden takes the
  build's cutIndex 0 (axis −45°, bladeLength 2.1073)".
- **L8.** [7.4]'s rank-order evidence becomes: "M2's outputs are permutation-invariant by id (c_perm: 64 fixtures × 10
  permutations), so walks in Sampling.measureRanked order are too". T-DIF-07(c) stays the real test.
- **L9.** The §4.1 edit reads: "sums in part order (Edge's and Factors' walks: the measure's rank order,
  `Sampling.measureRanked`), then sample order". MassProps and physicsFrame keep blueprint-order sums.
- **L10.** [12] gains §5.6's CPU-attacks row: "`Analyze.run` with M3 49.0 ms Lune for the slowest valid design (≈ 127
  Studio); P1 28.5 (≈ 74)". It uses the measured values and D7's **[Decision to confirm]** (O7).
- **L11.** T-DIF-08's mirrored Gen swords go to builder 2 in Factors.spec:
  - Take `validSword`, keep the parts with centre x ≥ 0, and add `Mirror.reflect(p, "X")` of those with x > 0 under
    fresh ids. Then `Canonical.draft`.
  - Assert Asymmetry ≤ `TOL_ASYM_ZERO`: 20 designs fast, `FUZZ_N_VALID` slow.
  - Measure it once before blessing. A spec under tests/Physics may require src/shared modules.
- **L12.** Every fast Gen corpus is 20 designs, in [8] as in [9.4].
- **L13.** Thinness' share term uses the probes taken: the striking-slot probes' weight, or all probes' weight when none
  of them is in the striking slot (the prototype's `swStrike > 0`).
- **L14.** "physics.edgeLength = edge.length; cutIndex in physics" moves to builder 3's Analyze.spec placeholder case.
- **L15.** X03's near-dust fin (0.0003 stud³ on F4) splits the edge into 2 chains (EdgeLength 5.7237 → 4.7564) and moves
  Sharpening from 0.3420 Hard to 0.1980 Normal.
  - Builder 4 records this in §5.6 and §17.2 as the main-chain rule's effect.
  - T-DIF-13 asserts it as measured.
  - If the comb row carries a designer mark, the fin joins that mark's row. Otherwise it goes under O10's text as a
    related limit of what shows; no new O-number.
- **L16.** §14.5's generic properties for the new pure functions:
  - Edge.profile, Factors.measure and Difficulty.step each get P-DET and P-NOMUT (deep-freeze the inputs, run twice,
    compare by `Dump.canonical`).
  - P-ORDER (Analyze.spec near 885) plants shuffled Steps, Tiers and Materials into Difficulty and Factors, and those
    into Analyze.
- **L17.** S-PAR-02:
  - SPar02.spec is `t.slow`, or its fast case runs only the 'fixtures' group.
  - `Parity.luau` lists the A-variant keys. Both the Lune spec and the Studio snippet call `Blueprint/Canonical.draft`
    on them and drop the ones that fail.

## Designer calls M3 carries (§17.1)

- O7: the cap's figures now include M3 (D7). The slowest valid design takes about 49 ms Lune, ≈ 127 ms Studio.
  Default: accept.
- O8: unchanged.
- O9: M2's round-part band. No M3 action.
- O10 (new): D1, option 0, with L4's reason and numbers.
- O11 (new): D2 (i), flush re-segmentation sensitivity on general designs (G up to 0.0236). It also carries the Y
  translation figure if L3 falls back to (b).

Builder 4 numbers the new rows after O9, and checks that every **[Decision to confirm]** mark carries its O-number.
