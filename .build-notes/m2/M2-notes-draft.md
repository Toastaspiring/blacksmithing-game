# M2 build notes

Open items and deviations reported while building M2 (geometry core and engine parity), from its builders, fixers and
verifiers, trimmed and in their words where possible. M2 went through 10 verification rounds, and its Enclosed verdict
was rebuilt twice: first as a sampled rule, then as an exact reading on a polyhedral model of each part
(`Physics/Cover`). Every item was checked against the tree of 2026-11-14 after fix round 4: what later rounds fixed is
left out, and (check) marks an item that could not be confirmed. Brackets name the source, the workflow run and the
agent's label (the run journals are kept outside the repo). Read the part for your milestone before building it, and
strike what is done.

## Decisions to confirm

No designer was available during M2, so each item carries a written default. O7, O8 and O9 are rows of SPEC §17.1. The
last two items are questions in §17.2's S2 rows.

### O7 The verdicts' cap (§4.4, §4.9, §16.10)

- Question: past `VERDICT_WORK_MAX` = 700,000 Cover work units, a design is invalid (`TooComplex`) and never measured.
  Is that right, and are about 78 ms Studio for the verdict (about 94 ms for `Analyze.run`) acceptable for the slowest
  valid designs under the cap, sliced at 4 ms a Heartbeat?
- Default: as stated.
- Figures: real designs stay about 2 × under the cap. P1, the heaviest, spends 330,993 units; the 33,389 plausible
  designs at most 104,573. But a regular sword of 24 rods 0.12 thick, every part showing, spends 471,161 units (1.49 ×
  under), and honest variants of it (two grip rods turned 9.0° and 4.6° into the guard stack) pass the cap and are
  `TooComplex`. The slowest valid design known, a cluster of 24 Balls (687,304 units), takes 30.2 ms Lune for the
  verdict (≈ 78 ms Studio) and 34.7 ms for `Analyze.run`. Climbed designs take up to 36.2 ms for `Analyze.run` (≈ 94 ms
  Studio, about 24 Heartbeats). A design past the cap is answered in 10.7–24.5 ms. Studio is assumed to be 2.6 × Lune;
  it was never measured.
- A mirror image, or one solid written another way, can spend up to about 30 % more or fewer units (F5 +96 %, C05 +689 %
  on small designs), so a design near the cap can be valid while its image is `TooComplex` (§17.2).
- With M3's share emulated, the slowest valid design takes 48.99 ms Lune (≈ 127 ms Studio); the M3 plan (D7) updates
  O7's figures. [wf_2263d132-7b2, M3 planner]
- Source: [wf_79258f42-9b2, Builder: exact verdict; the 24-rod sword from V1 adversary r2; figures from wf_2263d132-7b2,
  Fixer r4]

### O8 A slot label moves Sharpening's work set (§4.4, §17.2)

- Question: F3 with its main blade labelled Guard plays Sharpening 0.6104 Hard → 0.0645 Normal (C08: 0.2487 Hard → 0
  Normal). Accept it, or tie Sharpening's set to geometry?
- Default: accept. Geometry decides what shows, and the label of what shows counts: it is visible and the player's
  choice.
- What the rule does. A part that encloses another by any margin is what shows: a copy 1e-12 to 1e-4 larger round F3's
  blade, labelled Guard, takes the blade out of the Blade (0.6104 → 0.0645). A part wholly inside another, flush with
  its faces, gives them up whatever its label: 4 skins 0.02 thick inside F5's guard, labelled Blade, are cleaned (when
  the slot ranked before the volume, they were kept: Sharpening 0.0989 → 0.4201). Of parts of one volume that coincide,
  the slot's name decides, so an invisible copy (exact, turned, described another way, a hair lower or smaller) cannot
  take a blade out of the Blade. A copy in the Blade brings a part in, no more than relabelling does (F3 + a copy of its
  guard: 0.6104 → 0.6770).
- Tried and dropped: a near-copy rule (`COPY_NEAR` = 0.001). A copy 0.0012 larger still moved the blade, and 0.01 broke
  10 Physics cases.
- Source: [wf_79258f42-9b2, Builder: exact verdict; rewritten by Fixer r2 after V2 numbers and text r2 (the skins) and
  V1 adversary r2 (the enclosing copy)]

### O9 The round-part model band (§4.4, §5, §5.5, §17.2)

- Question: hidden filler cannot move a tier (§5), but a round part is read on an inscribed model (a Cylinder on its
  32-gon prism, a Ball on 128 triangles), and the band between the model and the true surface errs both ways. Accept the
  band for the MVP, or take one of the rules tried?
- Default: accept for the MVP; revisit if playtests or telemetry meet filler or flush parts at round parts.
- (a) Kept though it truly shows under 2 %: round filler that pokes a hair out of a round part's true surface, or lies
  where a round part meets another part. F5 with its pommel a Ball 0.6 across and 4 Blade Balls r 0.08–0.15 poking
  0.0001–0.002 out along (1, ±1, ±1)/√3 plays Sharpening Hard in 16 of 20 swords (up to 0.3284; the truth's row 0.0989);
  in random directions, 3 of 240. 4 Blade rods where F5's grip enters that pommel, every point at least 0.002 inside,
  read 6.57 % each and are kept: Sharpening 0.1827 Normal → 0.2083 Hard (with F5's blade 0.25 longer).
- (b) Cleaned though it truly shows: a flat face that stands out of a round part's true surface by less than the model
  stands past it is buried. On a Cylinder's prism this reaches 0.0048 r at the 32-gon's corners: a plate 0.0005–0.001
  out of a round guard r 0.8, truly 17.8–18.1 %, reads 0–0.5 %. Since fix round 4 a flat face reads a Ball on its true
  sphere, so on a Ball this happens only where the face's plane passes near the centre: at most 2.1 % true cleaned in a
  sword's sizes, 5.2 % on a Ball r 3.
- Rules tried, with their prices. Hiding a round facet whole when its vertices lie in the round part moves no plausible
  verdict (P4 −3.4 % units) but leaves 5 of 33 such swords a wrong tier, either way (12 as built), and cleans pokes that
  truly show up to 3.9 %. Its buried piece on the moved half-spaces wherever a vertex is buried cleans a plausible rivet
  that truly shows 6.3 % (P4 +18.8 % units). V1's hull test on what a facet has left after its hiders moves no plausible
  verdict (+0.16 % units) but leaves crease Balls at 4.4 % and depends on how the subtraction cuts a facet. A finer
  model halves the band at 2–6 × the cost.
- Source: [wf_2263d132-7b2, Fixer r4, on the lead's decision 2 of fix round 4; raised by wf_b2999a59-aba, V2 numbers and
  text r4 and V1 adversary r4]

### §17.2 design question: a sandwiched core that crosses 2 %

- §17.2: where a core sandwiched between cheeks crosses 2 %, D jumps 0.34–0.47 whatever the precision, because cleaning
  it opens the chord in Thinness. M3 decides how a cleaned part affects Thinness' chords.
- The study's case: hilt and cheeks 1.1 × 2.0 × 0.06 with a cap, and a core 0.95 wide and 0.02 thick that truly shows
  2.01 %. The core is kept: Smelting 0.4282 Hard, Hammering 0.0250 Normal, Sharpening 0.0594 Normal. A sheet 1.08 wide
  in the same gap (truly 1.77 %) cleans both: 0.3762, 0.3609 and 0.2594, all Hard; |ΔD| 0.3359, two steps Normal → Hard.
  The sheet does show. It is the 2 % threshold on a part that fills a gap, and no sample count changes it.
  [wf_ecdcc820-4b9, Verdict study]
- The figures disagree (check). The M3 planner found at most |ΔD| 0.3235 on its 9 sandwiches and no E-S2.12 row behind
  "0.34–0.47". The M3 plan critic re-ran §17.2's own proud-core laminate on the M2 snapshot: 0.27–0.41, with 7 tier
  flips on 6 crossings, carried by Thinness. The M3 plan proposes O10 with "option 0: cleaned parts are inert in every
  factor". [wf_2263d132-7b2, M3 planner; M3 plan critic]

### §17.2 question for M3 and the designer: what the 2 % rule itself admits

- "Hidden" means within `HIDE_OFFSET` of other parts, so no reading changes these. A filler in a sealed cavity shows: a
  closed box + a block inside it, Smelting 0.1376 Normal → 0.4463 Hard. Flush layers through the thickness, each under
  2 %, are each cleaned: a 1.6 × 3.5 × 0.16 blade in 8 flush layers, Hammering 0.0582 Normal → 0.7000 Hard. k hidden
  sheets clean a part that shows up to about 2 % × k × their area / its area: 14 sheets clean a core that shows 11.92 %.
- Question: should the rule look through a sealed cavity or a stack of layers? §17.2 writes no default. The M3 plan's D1
  adds no M3 rule for them and leaves them to the verdict's owner, under its O10.
- Source: [wf_0c84c119-711, V1 adversary r2; reproduced on the exact verdict by wf_79258f42-9b2, V2 numbers and text r2]

Other limits M2 accepted without a designer call are in §17.2's S2 rows: the rest of the round-part band, exact ties at
`EPS_GEOM`, what ids and mirror images still reach (units near the cap), the 45° step of the grip-axis vote, and the
overlap budget's mass error on P1–P5.

## Open items by later milestone

### M3 Difficulty

Read `.build-notes/m3-plan/plan-r2.md` first: its §10 lists what M3 inherits from M2, and `plan_r2_critique_result.json`
is its review (6 major points). The plan was measured on the round-4 snapshot (`m2x-r4-base`), so re-run its scripts on
the committed tree before blessing anything. The items below are what a builder must know beside it.

- The plug-in spot is phase 6 of `Analyze.run` ("M3 plugs in here"): fill edge, steps, `physics.edgeLength`,
  `physics.cutIndex` and `budget.edgeCell`. `Analyze.spec`'s §4.7 report case asserts them nil or 0, and `CHECK_UNITS`
  500; its "phases only" case counts exactly 5 checkpoints and injects Analyze's requires by hand. Both change with M3.
  [wf_dada5829-913, build B1; fix M2 r1]
- T-VAL-04 and T-PHY-02 cover F1–F5 in the repo. Add C01, C02, C04–C15 and E-S2.9's edge and cutIndex columns. Until
  M3's fixtures exist, the Physics specs read the C, X and P fixtures from `docs/spec/prototypes/S2/v2/fixtures` and the
  worst designs from `cover/worst_designs.luau` by cast requires, and `PhysicsHelpers.ornate` stands in for C09.
  [wf_dada5829-913, build B1; fix M2 r1]
- `WorkSet.select` is written and tested, but nothing calls it. Analyze's steps should call
  `WorkSet.select(parts, physics.kept, row.worksOn)`. T-DIF-08 can build its half + reflect designs on `Mirror.reflect`,
  but Gen has no such generator and `tests/lib` cannot require Mirror. [wf_dada5829-913, build B2; wf_2263d132-7b2, M3
  plan critic]
- Do not assert `TOL_MASS_REL` or `TOL_BALANCE_ABS` on P1–P5: past `N_OVERLAP_WORK` they measure about −10.3, −4.4 and
  −5.6 % against the union's volume (§17.2). Refined overlap sampling is not analytic either: overlap error reached 8 %
  of a part's owned volume on a test plate, and a touching part can move the grid by rounding (0.05 % of mass under
  translation) (check). [wf_dada5829-913, verify V2 r1; build B1]
- Checkpoint gaps (T-PERF-01, §14.11). `CHECK_UNITS` stays 500. The median run's longest stretch passed 0.35 ms on 1 of
  75 designs (P4, 0.37 ms), and single quiet runs reached 0.36–0.39 ms (P3, tclimb_4 #1). The cause is allocation and GC
  in Cover, not uncounted work: `CHECK_UNITS` 250 or 125 did not shorten them. §14.11 bounds "every checkpoint gap", so
  bound the median of 15 runs, and consider reusing Cover's polygons or an incremental GC step at each checkpoint.
  [§17.2; wf_79258f42-9b2, Builder: exact verdict; wf_b2999a59-aba, V1 adversary r4]
- Precision as handed over: on the 33,389 plausible designs, 455 / 3 / 0 parts that truly show 2.5 / 3 / 4 % or more are
  cleaned (the highest 3.615 %, a Ball in a pommel housing), and no part under 2 % is kept (the lowest 2.002 %).
  `VerdictPrecision.spec` passes on any seed only while that highest share stays under its 4 % bound. Fix round 4 moved
  14 plausible verdicts (wrap-ring grips, now kept, D the truth's row) and units on 10,364 plausible, 803 attack-corpus
  and 87 fixture-set designs; no design crossed the cap. [wf_2263d132-7b2, Fixer r4; wf_b2999a59-aba, V1 adversary r4]
- `Reference.spec` compares with the prototype's own budgets, and its exact checks rely on Lune's libm matching the
  literals. Retire it if Balance.Geometry is retuned (§4.9's fallback). [wf_dada5829-913, fix M2 r1]
- Studio (S-PAR-02's first digest): the test place is Project 215, Play sessions only (§14.10). The console line
  `ContentId: rbxassetid://203785492 failed` predates every test. After a GPU reset (`Device removed 0x887a0005` in the
  Studio log), reopen the place and reconnect Rojo. [the lead's project notes]

### M4 Minigames

- No item from M2.

### M5 Crafting and items

- S4's `Plan.build` should call `WorkSet.select(parts, physics.kept, row.worksOn)`. It raises an error when
  `#kept ~= #parts` or when the selector is neither "All" nor a table, because treating missing flags as not kept would
  give wrong difficulty. [wf_dada5829-913, build B2]
- `Pipeline` (§4.8) must carry `TooComplex`. Such an analysis is invalid, with `cleaned = {}` and no physics, edge or
  steps (§4.7), and its error names no part, slot or reason. The 6 ValidationCodes fit `MAX_ISSUES_STORED` (T-DEF-06
  asserts ≥ 6). [wf_79258f42-9b2, Builder: exact verdict; V2 numbers and text r2]
- S-PAR-02 with outcomes: see the M3 plan's [8.5] and the critic's two gaps there (SPar02.spec's dry run takes about 5 s
  and is not marked slow; nothing says who canonicalizes the A variants). [wf_2263d132-7b2, M3 plan critic]

### M6 World

- Extend ItemRender beside the four M2 functions, whose signatures match §13.7 (`RenderPlan.fromBlueprint` and
  `primitive`, `ItemModelBuilder.buildPart` and `applyPrimitive`): add `build`, `placeholder`, `setHeat`,
  `applyRarityFx`, `mountInViewport` and the `Orientation` and `BuildOptions` types, and extend
  `tests/ItemRender/FakeRoblox.luau` as needed. Bless T-RND-01's goldens: none exists yet, and RenderPlan.spec holds
  hand-worked F1–F5 numbers. [wf_dada5829-913, build B3]
- `plan.bounds` and `plan.slotBounds` are in blueprint space, neither anchored nor scaled (§13.7 does not state the
  frame). Consumers on the plan pivot derive extents as scale·(max − min)/2, and InspectHitbox and the viewport code
  must follow it. [build B3]
- SPEC gap: `RenderPlan` has no lower bound on scale, while E-S7.4 guarantees that sizes render as stored only for a
  scale of 0.05 or more. No MVP caller goes below 1. [build B3]
- S-PAR-01 passed 3 fresh Play sessions on 2026-11-14. It loads Canonical, ItemModelBuilder, Limits, Quat, RenderPlan,
  Shapes and World (and what they require) plus tests/lib's Dump, TestRng and Tol, so re-run it when M6 changes any of
  them; the passing run's hashes are in `.build-notes/m2x/spar01_hashes.txt`. To run it, pass the text of
  `tests/studio/e2e/S-PAR-01.luau` to `execute_luau` with datamodel_type "Server" in a Play session and read the `[E2E]`
  lines. [wf_b2999a59-aba, V2 numbers and text r4; wf_dada5829-913, build B3]
- §17.2's S7 row (Wedge and CornerWedge vertex sets match Roblox before the bounds goldens freeze) is met in two steps:
  T-RND-01 ties the vertex sets to Shapes' solids, and S-PAR-01's overlap check ties those solids to the engine.
  S-PAR-01 has passed, but the row still reads as open (check). [build B3]
- Record S-PAR-01's engine facts, as B3 asked once it had run. Physics treats sides below 0.05 as 0.05, so the snippet's
  20 sizes keep every side ≥ 0.05 (say so in E-S8.6). Its thin-size lines report whether Mass and CenterOfMass follow
  the true size, the physics size or neither (E-S2.1 or §17.2's V-09). The run's output is kept neither in the repo nor
  in `.build-notes` (check). [wf_dada5829-913, build B3; fix M2 r1]

### M7 Headless server

- Test-place cleanup. The scenarios sync `test.project.json` into Project 215 itself (§14.10), so its live session holds
  `ReplicatedStorage.BlacksmithTests`, `ServerScriptService.BlacksmithTestServer` and
  `StarterPlayer.StarterPlayerScripts.BlacksmithTestClient`. M7's server bridge goes into that tree. Before the first
  publish, reconnect Rojo to `rojo serve` (port 34872) and delete those three by hand (README checklist item 5,
  §1.4 (5), §14.12 (9)). [SPEC §14.10, §14.12; README]
- `TooComplex` on the wire (§10.3): a Save stores it with `valid = false`, and a Begin answers `E_INVALID_BLUEPRINT`
  with the codes. It names no part. Each such answer costs the AnalysisQueue 10.7–24.5 ms Lune. [wf_79258f42-9b2,
  Builder: exact verdict; wf_2263d132-7b2, Fixer r4]
- AnalysisQueue: the slowest valid design under the cap takes about 94 ms Studio for `Analyze.run` (M2's phases only),
  about 24 Heartbeats at 4 ms, one job per player (O7). [§4.9]
- S-PERF-01 (server): run P1, the specks and `worst_designs.luau`'s 11 valid and 17 `TooComplex` designs. The 75 ms
  total holds on the F, C and X fixtures; the rest are reported against it. §4.9's fallback (halve `N_SURF_WORK` and
  `EDGE_MAX_WORK`) does not reach the verdict, whose cap bounds hostile designs instead. The M3 plan copies the worst
  designs to `tests/fixtures/WorstDesigns.luau` so that Studio can read them. [§14.11; wf_79258f42-9b2, Builder: exact
  verdict; wf_2263d132-7b2, M3 planner]

### M8 Client

- Mirror copy (§11.10): skip a part with `Mirror.isSelfSymmetric(part, plane)`, not with a "centre on the plane" test,
  which would refuse the copy that makes F3's or F4's single-edged tip double-edged. Canonicalize after
  `Mirror.reflect`: it applies the hemisphere rule and −0 → +0 but not C3, so a quaternion within about 2e-16 of
  `QUAT_NORM_TOL` can need that pass after a CornerWedge flip. Reflecting a CornerWedge twice restores its rotation only
  to about 1e-15. [wf_dada5829-913, build B2]
- `Pipeline.quick(core, {connectivity = true})` returns V1, V2 and V3 errors together, so a part dragged out of the
  hitbox does not hide what floats (§11.12). `Analyze.run` keeps "first failing stage". [build B1]
- `TooComplex` in the issues list (§11.12, E-S6.12) highlights no part: "Too complex to analyse: use fewer overlapping
  parts, or overlap them less". [wf_79258f42-9b2, Builder: exact verdict]
- PreviewScheduler may cancel a stale run by raising from a checkpoint: 287 checkpoints raised mid-run (P4, C09, the
  cluster, a design past the cap, P1) left no trace in the next run. Snap to touch moves along `FloatingComponent.dir`,
  a unit vector to about 1e-7. [wf_b2999a59-aba, V1 adversary r4; wf_dada5829-913, verify V1 r3]

### M9 Playtest and Done

- Playtest triggers written into M2's defaults: O9 (filler or flush parts at round parts); the round-part band (revisit
  Balls and Cylinders, and the probe's spread on caged Balls, if playtests meet beads, ribs or caged Balls at 2.5–25 %);
  the grip axis's 45° step ("accepted unless playtests find it"); O7 (honest designs that come out `TooComplex`).
  [§17.1, §17.2]
- Every Studio time in M2's text is Lune × 2.6, assumed. S-PERF-01 (M7 server, M8 client) is the first measurement.
  [every round]
- S-PAR-03 and S-PAR-04: §17.2's V-09 still lists "engine shape conventions and float survival (S-PAR-01, S-PAR-03)";
  S-PAR-01 covered the shapes. The test tree must be out of the place before its first publish (§14.12 (9), above in
  M7).

## Deviations from the SPEC that stand

### API additions and names

- Shapes exports, beyond §4.1's `prepare`, `sd`, `chord`, `support`, `aabb`, `extentAlong` and `maxDist`: `sdLocal`,
  `toWorld`, `toLocal`, `sameSolid`, `aabbContains`, `aabbOverlap`, `planes`, `faces`, `PI`, `CODE` and the type
  `Prepared`, Physics' internal working copy (outside Physics, `Shapes.aabb` takes PartData). RenderPlan uses `aabb` and
  `CODE`; the specs and S-PAR-01 use `prepare`, `sd` and `toWorld`. [wf_dada5829-913, build B1]
- Sampling exports `ladder`, `volumeSamples`, `volumeProbes`, `surfaceSamples`, `exposure` (its result carries `capped`
  and `verdictWork`) and `INSIDE_MARGIN`; §4.4 names `ranked` and `measureRanked`. MassProps exports `exactOverlap`,
  `overlapBox`, `sampledOverlap`, `ownership`, `gripFrame`, `physicsFrame`, `difficultyFrame` and `report`. Gjk adds
  `MAX_ITER`. Cover exports `model`, `shown`, `UNITS_PER_BOX` and the types `Model` (with a per-facet `flat`) and
  `Spend`. [build B1; wf_79258f42-9b2, Builder: exact verdict; wf_2263d132-7b2, Fixer r4]
- No function is named `Analyze.validate`: V1–V2 are `Analyze.quick`, and V3–V5 the full stage inside `Analyze.run`.
  Analyze also exports `CHECK_UNITS` and the helper types `CleanedPart` and `AnalysisBudget`. [build B1]
- Mirror exports `type Plane = "X" | "Z"`; any other plane raises an error, as a caller bug. [wf_dada5829-913, build B2]

### Values and behaviour the SPEC left open

- `Analyze.quick` with `connectivity = true` returns V1–V3 together (M8 above). `measureInvalid` bypasses only the
  full-stage stop; a quick-stage failure always stops. With `measureInvalid` and no kept Blade part, `reach` and
  `bladeLength` are 0 (the prototype gave −inf). [build B1]
- `TooComplex` keeps any V3 or V4 errors already found, comes last and keeps the floating components. A design that
  fails V1 or V2 returns before the verdict. [wf_79258f42-9b2, Builder: exact verdict]
- `Mirror.reflect` copies known fields only, into a new record with the same id. `isSelfSymmetric` compares solids, not
  records or centres (polyhedra by vertex permutation, a Cylinder by centre and axis, a Ball by centre), within
  `EPS_GEOM`. [build B2]
- RenderPlan takes its bounds from `Shapes.aabb` rather than a copy of §13.7's formula, so the solids have one owner.
  Hostile inputs map onto PlanError: a non-table part or a non-string slot is BadShape; a missing or wrong-length tuple,
  or a non-finite id or scale, is NonFinite; scale ≤ 0 is BadSize; a non-table parts is Empty. An unknown anchor name
  throws. Each check runs across all parts before the next. [build B3]
- S-PAR-01 beyond E-S8.6: its 20 sizes per shape keep every side in [0.05, MAX_DIM], not [MIN_DIM, MAX_DIM], and 5
  thinner sizes per shape run apart and are only reported. Its 200 margin points are 100 inside and 100 outside, probed
  with a 0.05 Ball. The slack is 0.05 stud plus 3 % of the radius for curved solids. CenterOfMass is compared in world
  space. The only changes to a built Part are CanQuery = true and density 1. [build B3]
- Test choices. T-PHY-01's Monte Carlo is jittered-stratified (47³ points). T-PHY-04 holds `TOL_ANALYTIC_REL` on F1–F5
  but only `TOL_MASS_REL` and `TOL_BALANCE_ABS` on generated swords. T-VAL-03's brute force decides outside a ±0.006
  band round `CONTACT_TOL`. Cover.spec's plausible sweep checks 9,153 of the 33,389 designs (all of 20 parts or more,
  every 4th of the rest). The spread widened Cover.spec's `BAND_ROUND` to 0.05 and Verdict.spec's Ball between plates to
  0.02. [build B1; wf_79258f42-9b2, Builder: exact verdict; Fixer r2]

### Beyond the SPEC's text

- Gjk differs from S2's prototype where §4.1 lists no difference. Once a support proves the solids apart, "inside" is
  refused (the prototype read a pair 0.028 apart as touching), and `Gjk.distance` keeps the shortest v seen (the
  prototype's could cycle and report a gap of 0.33 for 0.014). `within` gives the prototype's verdicts on 6,000 pairs.
  [build B1; wf_dada5829-913, fix M2 r1; verify V2 r2]
- `docs/spec/prototypes/S2/v2/overlap.luau` keeps the old clip that §4.3's near-coplanar fix replaced. The two agree to
  one ulp on its fixtures, so `Reference.spec` cannot see the difference. [wf_dada5829-913, fix M2 r2]
- T-META-03 also bans `--!native` and `@native` in authoritative modules (§4.1); §14.4's T-META-03 row does not say so.
  [fix M2 r2]
- The BALANCE fingerprint was re-blessed under `BALANCE_VERSION` 1 for `COVER_BALL_GRID` and `VERDICT_WORK_MAX`, the
  pre-release re-bless M1 used: `{bytes=13286, fnv1a32=162842818, version=1}`. No other golden changed.
  [wf_79258f42-9b2, Builder: exact verdict]
- Cover's work-unit weights (`UNITS_PER_TEST` 0.5, `UNITS_PER_BOX` 0.125, `UNITS_PER_POLYGON` 1, `UNITS_PER_FACET` 8)
  set where `VERDICT_WORK_MAX` falls, so they change outcomes, and §16.18 ties them to `BALANCE_VERSION`. But they live
  in Cover.luau, outside the fingerprint: `UNITS_PER_BOX` 0.25 passes T-BAL. Only Cover.spec (f)'s unit pins catch a
  change, so bump the version by hand. [wf_79258f42-9b2, V2 numbers and text r2]
- `tests/ItemRender/FakeRoblox.luau` (a float32 engine model with fault switches) and two extra specs run the
  Roblox-bound builder and S-PAR-01's logic at the gate. They prove nothing about Roblox. [build B3]

## Not done in M2

- No mutation pass on the final Cover. Fix rounds 3 and 4 ran none of their own. V1's run on round 3's lines (99
  mutants) left 22 alive; its new case killed 11, and the rest are threshold-level, equivalent, or the conservative hull
  origins. Fix round 4's code (a flat face reading a Ball's sphere) has had none. [wf_2263d132-7b2, Fixer r4;
  wf_b2999a59-aba, V1 adversary r4; E-S2.12 "Not done here"]
- No Studio timing: every Studio figure is Lune × 2.6, assumed. [every round]
- Checkpoint gaps were not measured again after fix rounds 3 and 4. V1 last measured them in round 4: a median of
  medians of 0.126 ms over the fixtures, 0.126–0.275 ms on the worst valid designs. [wf_b2999a59-aba, Fixer r3; V1
  adversary r4; wf_2263d132-7b2, Fixer r4]
- §4.9's older P1 and P4 times stand as recorded (P1 11.8–12.0 / 19.1–19.4 ms, P4 10.3 / 12.8–13.3 ms). Fix round 4
  measured P1 at 11.14 / 18.74 / 22.50 ms and P4 at 9.97 / 12.23 / 14.91 ms (verdict / exposure / `Analyze.run`) with
  1–7 % other load. Its bit-compares and seed runs ran under its own load. [wf_2263d132-7b2, Fixer r4]
- Not tried: a Cylinder's cap reading a Cylinder hider on its moved half-spaces, as a polyhedron's face does (a cap
  keeps the inscribed buried piece) [Fixer r4]; a tighter spread, growing each hider half-space by the facet's probe
  displacement projected on its normal [wf_79258f42-9b2, Fixer r2]. The finer Ball model was not climbed. The verifiers'
  12 families ran only in the judge's sample (every 8th), 4 of them ported in full. [E-S2.12]
- Rule A (a round part inside a round hider's true solid shows nothing) is exact for a Ball and for a Cylinder in a
  Ball. For a Cylinder tilted in a Cylinder it is a bound: of 242 rods truly inside, it misses 100, none of which reads
  2 % (worst 0.347 %). [wf_b2999a59-aba, Fixer r3; V1 adversary r4]
- Untested, at tie level: a polyhedron's `over` is 0, but a needle-sharp Wedge's half-spaces grown by `EPS_GEOM` can
  stand about 6e-5 past its box along its sharp edge, more than the 2·`EPS_GEOM` slack. So a probe sliver about
  `EPS_GEOM` wide could be skipped. Not seen in 18,000 tangles (check). [wf_79258f42-9b2, Fixer r1]
- Test gap: V1's two GJK pairs whose closest feature is a simplex edge (a wedge's top edge 0.012 under a plate; a cube's
  corner 0.0101 under a CornerWedge) were never added to Gjk.spec. The mutant they kill, in `Gjk.luau`'s edge branch,
  survived the suite then (check). [wf_dada5829-913, verify V1 r3]
- Evidence outside the repo: the 1,340-design attack corpus (`m2x-protoA/out/corpus_all.jsonl`, 3 MB), the climbs of A,
  B and the judge, and the verifiers' 12 families (`m2x-protoB/b_sets.luau`) are read by absolute path from the session
  scratchpad, which loses week-old files. Only `tests/Physics/CoverAttacks.luau` (17 attack designs) and
  `worst_designs.luau` are kept in the repo. [wf_79258f42-9b2, V2 numbers and text r1; `cover/README.md`]
- Evidence script `cover/fix3/rivet.luau` builds one-facet models without `flat`, so it would read a cap as round. No
  test uses it. [wf_2263d132-7b2, Fixer r4]
- Other seeds: on any `PROP_BASE_SEED` but the default, Meta/Runner's 2 pins of the default seed fail by design; the
  Physics suites pass. [wf_79258f42-9b2, Builder: exact verdict]
- Timing-bound tests are load-sensitive: Cover.spec (f)'s `TooComplex` answer (≤ `ANALYSIS_LUNE_MAX_MS`, best of 3) took
  64.8–72.1 ms with the CPU at 88–100 %, and T-META-05's 2 s case once took 2.33 s. [wf_79258f42-9b2, V2 numbers and
  text r2; wf_dada5829-913, verify V2 r3]
- No inertia. The M2 brief listed it, but SPEC §4.7 and §15.1 have none in the MVP, and the build follows the SPEC.
  [wf_dada5829-913, build B1]

## Where the evidence lives

- `SPEC.md`: §4.1–§4.9, §5 and §5.5–§5.6, §16.10 and §16.18, §17.1 O7–O9, and §17.2's S2 rows.
- `docs/spec/SPEC-evidence.md`: E-S2.11 (the sampled verdict against the truth, now history) and E-S2.12 (the exact
  verdict: the prototypes and the judge, the build, four verifier rounds, "Not done here"; its history sections keep
  each round's units and times). Rows changed in E-S2.5, E-S2.9, E-S6.12, E-S8.4 and E-S8.5.
- `docs/spec/prototypes/S2/cover/`: `README.md` (what each folder holds), `worst_designs.luau` (T-PERF-01 and S-PERF-01:
  11 valid designs and 17 `TooComplex`), and `build/`, `judge/`, `protoA/`, `protoB/`, `fix/`, `fix2/`, `fix3/`, `fix4/`
  (each round's scripts and logs).
- `docs/spec/prototypes/S2/verdict/`: E-S2.11's study, and `analyze_build.luau`, the emulator of M3 on the build behind
  every ΔD since.
- `docs/spec/prototypes/S2/v2/`: S2's reference prototype, which `tests/Physics/Reference.spec.luau` compares with.
- `tests/Physics/`: the Shapes, Gjk, Sampling, MassProps, Analyze, Cover, Verdict, VerdictPrecision and Reference specs;
  `CoverBrute.luau` (an independent brute force), `CoverAttacks.luau`, `VisibleOracle.luau` (the truth),
  `PlausibleDesigns.luau` (33,389 designs) and `PhysicsHelpers.luau`.
- `tests/Blueprint/{Mirror, WorkSet}.spec.luau`; `tests/ItemRender/` (the RenderPlan, ItemModelBuilder and SPar01 specs,
  FakeRoblox); `tests/studio/e2e/S-PAR-01.luau`.
- `tests/fixtures/Adversarial.luau` (A28), `tests/FixtureSet/{Adversarial, Gen}.spec.luau`, `tests/lib/Gen.luau` and
  `tests/golden/balance_fingerprint.golden.txt`.
- Outside the repo: `ROBLOX/.build-notes/m2x/` (the fixers' and verifiers' results of rounds 2–4, the lead's decisions
  in `m2x_journal_r4.txt`, `spar01_hashes.txt`) and `.build-notes/m3-plan/`.
