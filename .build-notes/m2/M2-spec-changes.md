# What M2 changed in SPEC.md

Every change M2 made to SPEC.md since M1's commit (`git diff 4c7e9e7 -- SPEC.md`), grouped by section and said in plain
words. Each change carries one tag:

- **Rule**: a behaviour or rule change.
- **Decision**: a new **[Decision to confirm]**, with a written default, since no designer was available.
- **Numbers**: a number or evidence update.

M2 adds 12 **[Decision to confirm]** marks, all pointing to three new rows of §17.1: O7, O8 and O9. No tunable you
approved changed value. Two new tunables join §16.10 (`COVER_BALL_GRID`, `VERDICT_WORK_MAX`), and §16.18 lists the new
fixed constants.

This list covers M2 as committed (7eb9914, 2026-11-15), after its sixth round of checks.

## In short

- **What counts as hidden filler is decided exactly, part by part.** Each part is read on a faceted model of itself, and
  what shows of every face is computed exactly. A part is cleaned (ignored for difficulty) when under 2 % of its model
  shows. Ids, the order of the parts, how many other parts there are and sampling budgets no longer move that verdict;
  only a part that really covers another does. Factors then read the kept parts alone.
- **A new answer, "Too complex to analyse" (`TooComplex`).** A design whose check would cost more than 700,000 work
  units is invalid and never measured. Real swords stay about 2 × under, but honest variants of a sword of 24 thin rods
  pass the cap (O7).
- **Slot labels still count.** If a visible part encloses another, its label is what counts for Sharpening (O8).
- **Round parts are read on faceted models**, which err both ways near their surface (O9).
  - Filler that pokes a hair out of a round part can count and buy a tier.
  - A thin plate lying flat on a round guard's side can be ignored while nearly half of it shows (up to about 48 %).
  - On a ball the error is a few percent (2.4 % at sword sizes).
  - Filler wholly inside one round part never counts.
- **The grip axis.** A grip part steers the sword's axis only if it points within 45° of straight up.
- **Studio tests run in the game's own place**, Project 215, and their test scripts must come out before the first
  publish.

## By section

### §0.3 How to review

- **Rule** (the document only): a **[Decision to confirm]** mark now carries a Q number (§0.4) or an O number (§17.1).

### §0.5 What changed from the design draft

- **Decision** (O9): the row that ends "filler cannot buy a tier" now adds "but for round filler a hair out of a round
  part".

### §1.2 Module map and §1.3 Layering

- **Rule**: Physics gains `Cover`, the module that reads what shows of each part. Inside Physics the order is Shapes →
  Gjk, Cover → Sampling → MassProps → Analyze, and Cover requires only Definitions/Balance and Shapes.

### §1.4 Project files and toolchain

- **Rule**: the build checklist gains item (5): before the first publish, the test tree (§14.10) comes out of the place.

### §3.8 Mirror math

- **Rule**: new function `Mirror.isSelfSymmetric(part, plane)`: true when the part is its own mirror image, within
  `EPS_GEOM`. The editor's mirror tool uses it (§11.10).

### §4.1 Overview, modules and determinism

- **Rule**: the pipeline now runs "the verdict, per part" (what gets cleaned), then "the measure" (surface samples,
  exposure and contact of the kept parts only). The module table gains Cover and rewords Sampling.
- **Rule**: the determinism rules now say where the build departs from S2's prototype on purpose (§4.3's copies, overlap
  budget and cut faces; §4.4's ranks, exact verdict, cap and kept-only measure; §4.5's vote). A test (`Reference.spec`)
  pins the rest to the prototype.

### §4.2 Validation

- **Rule**: a new last row. When a design's verdicts pass `VERDICT_WORK_MAX`, there is no verdict: the design is invalid
  with `TooComplex`, which names no part, slot or reason, after any V3–V4 errors. V5 is not asked and nothing is
  measured, even when the caller asks to measure invalid designs.

### §4.3 Measurement representation

- **Rule**: who owns an overlap. After "kept parts first" and the slot's rank, the tie now goes by the measure's rank
  (the larger part, then where it stands) instead of the part index, so no id decides.
- **Rule**: an exact copy of a higher part owns nothing, a part that owns no volume adds no moment, and the
  refined-overlap budget serves kept parts first. Exact clipping builds each cut face from the cutting plane.
- **Numbers**: "≤ 8 half-spaces per part" (was "≤ 7 planes": a CornerWedge has 8). The new cut faces differ from the
  prototype by up to about 3e-4 of a part's volume, on faces nearly coplanar with a cut.

### §4.4 Exposure and cleaning (rewritten)

- **Rule**: a face two parts share is kept by the part that ranks higher, not by the lower index.
- **Rule**: two ranks replace the index. The verdict's rank: the larger part first, then the slot's name, then where it
  stands (lower, then nearer the centre planes), then sizes and material; the index only breaks a tie between parts that
  are the same in every way. It settles which of two exact copies survives and who keeps a shared face. The measure
  keeps a rank of its own (the larger part, then where it stands; slot and material last), so mass and factors move only
  where a verdict moves.
- **Rule**: the cleaning classes are Dust (as before, now with no samples and hiding nothing), Exact copy (a copy of a
  higher-ranked part, Enclosed) and Enclosed (under 2 % of the part's model shows).
- **Rule**: the verdict is exact on a model of each part. Blocks, Wedges and CornerWedges are their own model; a
  Cylinder is the prism over its inscribed 32-gon; a Ball is 128 triangles (95.07 % of its area). The models stand in
  frames the world fixes, so a copy spun about its own axis, or a mirror image, reads like its original. What shows of
  each face is computed exactly, so no sample spacing, budget, id or part count moves it. Near round parts, extra rules
  keep the reading honest: a flat face reads a Ball on its true sphere, a round part wholly inside a round part reads
  nothing, and a round part's faces look a little further for what hides them.
- **Decision** (O8): the label of what shows counts. A part that encloses another by any margin is what shows, so a part
  a hair larger round F3's blade, labelled Guard, takes the blade out of Sharpening's set, as relabelling it would.
- **Decision** (O9): the round-part model band errs both ways.
  - Round filler that pokes a hair out of a round part, or sits where a round part meets another, can be kept and buy
    a tier.
  - A flat face just out of a round part's true surface can be cleaned while it truly shows. On a Cylinder's side this
    can be nearly half a thin part's surface (37–48 %): 10 such plates on a disk guard take Sharpening from Hard to
    Normal. On a Ball it is a few percent (up to 2.4 % at sword sizes, found by search).
- **Rule**: a round part wholly inside another round part reads nothing, exactly, at any tilt. This was fixed in round
  5: before, 10 hidden pucks inside a disk guard took Sharpening from Normal to Hard.
- **Decision** (O7): the cap. All the verdicts of a design spend at most 700,000 work units; past it the design is
  `TooComplex`. The cap never changes a verdict, so hidden parts can only make their own design visibly invalid.
- **Rule**: the measure reads the kept parts against kept parts only, with their own sample grid and sub-grid budget.
  Cleaned parts neither hide kept surfaces nor change their grid, so enclosed parts leave D unchanged to the bit while
  the kept set is unchanged. The old "pass 2" text is gone.

### §4.5 Mass properties

- **Rule**: the grip axis. A grip part votes only if its own axis tilts 45° or less from +Y, measured in 3D. A level bar
  or a handle along Z no longer tilts the sword or breaks its mirror image; with no vote the axis is +Y. Before, a
  part's tilt was read on its XY projection, and the whole sum fell back to +Y past 45°. D is unaffected (its frame is
  fixed).

### §4.7 Analysis types

- **Rule**: `ValidationCode` gains `TooComplex`. A `TooComplex` analysis has an empty cleaned list and no physics, edge
  or steps.

### §4.9 Execution model and cost

- **Rule**: checkpoints come once 500 work units have been reported since the last. Cover reports every 256 units at its
  next step, so one report can carry up to 1,088 units. Nothing changes for players; the text is now exact.
- **Rule**: the 75 ms Studio ceiling applies to real designs (the F, C and X fixtures; the slowest, C05, ≈ 37 ms). The
  fallback (halve `N_SURF_WORK` and `EDGE_MAX_WORK`) no longer reaches the verdict, whose cap bounds hostile designs.
  T-PERF-01 and S-PERF-01 also run `worst_designs.luau`.
- **Numbers**: the budget table: `N_SURF_WORK` and `N_SUB_WORK` are now the measure's, thin cylinders sample about 2 ×
  the Block estimate, a `VERDICT_WORK_MAX` row is added, and `N_OVERLAP_WORK` serves kept parts first.
- **Numbers**: measured times with the new verdict. Fixtures: verdict ≤ 1.7 ms, whole exposure ≤ 7.1 ms (C09). P1:
  verdict 11.8–12.0 ms, exposure 19.1–19.4 ms. With M3 emulated, fixtures stay under 33 ms Lune (C05 14.2 ms ≈ 37
  Studio; P1 31.7 ≈ 82). The slowest valid design under the cap: verdict 30.2 ms (≈ 78 Studio), `Analyze.run` 34.7;
  climbed designs up to 36.2 ms (≈ 94 Studio). `TooComplex` is answered in 10.7–24.5 ms.
- **Decision** (O7): `VERDICT_WORK_MAX` = 700,000, about 24 Heartbeats of 4 ms for the slowest valid design.

### §5 Difficulty (opening)

- **Decision** (O9): "hidden filler, specks, invisible construction choices and the material cannot move a tier" now
  adds "but for round filler against a Ball's or a Cylinder's true surface that pokes a hair out of it or reaches
  another part".
- **Rule**: "hidden" now means the 2 % rule of §4.4, read exactly on each part's model; what that rule itself admits (a
  sealed cavity, flush layers, sheets) is listed in §5.6.

### §5.2 Factors, §5.3 Reference ranges, §5.5 Calibration

- **Rule** (wording): SurfaceComplexity reads the measure's exposed area (was "pass-2").
- **Numbers**: the ornate sword's SurfaceComplexity reference 2.60 → 2.63.
- **Decision** (O9): §5.5's target "filler cannot buy a tier" adds the same round-filler exception.
- **Numbers**: C09 Hammering 0.3061 → 0.3170 (still Hard; no tier in the table moves).

### §5.6 Anti-gaming (measured)

- **Numbers**: the hidden filler row: what counters it now (the per-part verdict with no budget of its own, a cap that
  changes no verdict, the kept-only measure, the round-part rules) and the evidence (an attack corpus of 1,340 designs
  reads the truth's rows; filler inside round parts is cleaned). Marked O9.
- **Numbers**: new row on fillers behind a hairline, pins over a core, fullers, combs, ribs, slats and cages. On 33,389
  plausible designs nothing that shows 4 % is cleaned (highest 3.615 %) and nothing under 2 % is kept (lowest 2.002 %).
- **Numbers**: new row on ids, part order, mirror images, flush plates, skins and exact copies: the same bits in any
  order; skins inside F5's guard are cleaned; points to O8.
- **Numbers**: near-duplicate copies: ΔD ≤ 0.0010 (X01 0.0002, X02 0.0006), was ≤ 0.0005.
- **Rule**: the translation row now covers re-segmentation along the length and width only; layers through the thickness
  go to §17.2.
- **Numbers**: the CPU row: the cap and the new times.
- **Numbers**: new row on what the 2 % rule itself admits: a closed box with a block inside, Smelting 0.1376 Normal
  → 0.4463 Hard; a blade in 8 flush layers, Hammering 0.0582 Normal → 0.7000 Hard; 14 sheets clean a core that shows
  11.92 %.

### §10.3 Validation (Guard) and error codes

- **Rule**: a validation error is `{code, partId?, slot?, reason?}`; `TooComplex` names no part.

### §11.10 Parts, slots, materials, mirror

- **Rule**: mirror copy now skips only parts that are their own mirror image (`Mirror.isSelfSymmetric`), not every part
  centred on the plane. So mirroring a single-edged tip on the plane makes it double-edged.

### §11.12 Validation feedback

- **Rule**: a new issue, `TooComplex`: no part is highlighted, and the message reads "Too complex to analyse: use fewer
  overlapping parts, or overlap them less".

### §14.6 Module test plans, §14.7 Fixtures

- **Rule**: the Physics test plan names Cover and what `Cover.spec` checks. T-PHY-09's contract is rewritten: exact on
  its model against a brute force, ids decide nothing, the kept-only measure, `TooComplex` past the cap, and against a
  truth oracle nothing that shows 4 % cleaned and nothing under 1.9 % kept.
- **Rule**: T-DIF-04/05 are qualified: a duplicate in a slot whose name comes before its original's is not covered, and
  D stays bit-identical while the kept set is unchanged. Named cases are added.
- **Rule**: a new fixture, A28: 24 thin rods in a bundle, past `VERDICT_WORK_MAX`, `TooComplex`.

### §14.10 Studio integration, §14.12 Definition of Done

- **Rule**: the test place is the game's own place, Project 215, by your choice of 2026-11-03, served on port 34873.
  Checks run in Play sessions only and change nothing in Edit. The test tree stays in the place's live session, so it
  comes out before the first publish.
- **Rule**: Definition of Done item (9): the test tree is out of the place before its first publish.

### §14.11 Performance

- **Rule**: T-PERF-01 adds P1–P3 with a Dust speck and `worst_designs.luau` (the slowest valid designs and the
  `TooComplex` ones, which must be answered within `ANALYSIS_LUNE_MAX_MS`). S-PERF-01 runs the same cases and holds the
  75 ms total on the F, C and X fixtures only; the rest are reported against it.
- **Rule**: T-PERF-01 asserts the checkpoint gap (0.35 ms Lune, the median run's longest of 15) on the F, C and X
  fixtures, and reports P1–P5 and the worst designs against it. Longer single stretches are garbage collection, not
  uncounted work.

### §16.10 Definitions/Balance

- **Numbers**: new `COVER_BALL_GRID` = 4 (a Ball's verdict model: 128 triangles).
- **Decision** (O7): new `VERDICT_WORK_MAX` = 700,000.
- **Numbers**: rationale text only: `N_SURF_WORK` and `N_SUB_WORK` are the measure's (the verdict has no budget of its
  own, which closes hidden parts' last channel); a grip part tilted past 45° has no vote (`AXIS_MAX_TILT_COS`).

### §16.18 Physics/Analyze, §16.32 tests/lib/Tol

- **Numbers**: new rows:
  - Analyze's work-unit weights (4, 250, 20, 20, 40; checkpoints only).
  - Cover's work-unit weights (0.5, 0.125, 1, 8, and 28 for a searched cap rim). They set where the cap falls, so they
    go with `BALANCE_VERSION`.
  - `SPEND_EVERY` 256; `TooComplex`.
  - The numeric guards (fixed, not tunables), with `AXIS_TIE` 1e-9.
  - `OVER_BALL` 0.03 r and `OVER_CYLINDER` 0.005 r.
- **Numbers**: `ANALYSIS_LUNE_MAX_MS` keeps 60 ms; its note now gives C05 14.2 ms (≈ 37 Studio), P1 31.7 ms (≈ 82) and
  36.2 ms for the slowest design under the cap.

### §17.1 Product questions

- **Decision**: O7, the verdicts' cap (default: as stated).
- **Decision**: O8, a slot label moves Sharpening's set (default: accept).
- **Decision**: O9, the round-part model band (default: accept for the MVP; revisit if playtests meet it).

### §17.2 Engineering items (S2 rows, and one S8 row)

- **Numbers**: checkpoint gaps, rewritten: `CHECK_UNITS` stays 500; the long stretches come from memory allocation and
  garbage collection, not missed work (P4 0.37 ms against the 0.35 ms bound).
- **Numbers**: slivers between near-copies: X02's +0.0006 added.
- **Decision** (O9): new row, what hidden parts can still reach: a part that really covers another, and round filler in
  a round part's band. Count, budget, order and ids reach no verdict.
- **Rule**: new row, the round-part model band, accepted with its numbers; revisit if playtests meet beads, ribs or
  caged Balls at 2.5–25 %.
- **Rule**: new row, ties: a face exactly on the hide test's boundary is decided by rounding. Accepted.
- **Rule**: new row, what ids and order still reach: nothing in the build. Mirror images can swap a shared face between
  parts that tie in the rank, and near the cap a design and its mirror image can differ by up to about 30 % in units. M3
  must walk its parts in the measure's rank. Accepted.
- **Decision** (O8): new row, a label moves Sharpening's tier (F3 0.6104 Hard → 0.0645 Normal).
- **Rule**: new row, the measure keeps its own rank, so mass and D move only where a verdict moves.
- **Rule**: new row, what the 2 % rule itself admits (a sealed cavity, flush layers, sheets): a question for M3 and you.
- **Rule**: new row, a design question for M3: a core sandwiched between cheeks that crosses 2 % makes D jump 0.34–0.47.
  Re-measured on the exact verdict: 0.27–0.41. M3 proposes a decision to confirm, O10, with the default "cleaned parts
  count for nothing".
- **Numbers**: new row, the overlap budget: P1, P2 and P4 measure −10.3, −4.4 and −5.6 % against their true volume; the
  mass and balance tolerances hold only within the budget.
- **Decision** (O7): new row, the verdict's cost and the cap, with the 24-rod sword that passes it.
- **Rule**: new row, the grip axis: the no-vote rule is a step at 45° (a part crossing it drops its whole vote at once).
  Accepted unless playtests find it.
- **Rule**: the S8 row now applies §4.9's fallback above 75 ms "on real designs" only.

## Evidence sections (docs/spec/SPEC-evidence.md)

New:

- E-S2.11 The Enclosed verdict against the truth (`verdict/`): Truth · Sets · Variants · What each reading rule buys ·
  Slits between cover parts · Ids · L's reading · L on the fixtures · Grids · Cost · The build
- E-S2.12 The exact verdict (`cover/`): Two prototypes · The cross-check · The model's channels · Accuracy against the
  truth · Cost · Units and the cap · Invariance · The measure stays · What the 2 % rule itself admits · Checkpoints ·
  After the verifiers' round · After the second verifiers' round · After the third verifiers' round · After the fourth
  verifiers' round · Not done here

Changed:

- Contents
- E-S2.5 Regression fixtures (base F5; `reg`, `checks.luau`)
- E-S2.9 Calibration and the full fixture tables
- E-S6.12 Player-facing copy (initial `UI/Strings`)
- E-S8.4 Adversarial and regression fixtures
- E-S8.5 Case catalogue
