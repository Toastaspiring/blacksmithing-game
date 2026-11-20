# What M3 changed in SPEC.md

Every change M3 made to SPEC.md since M2's commit (`git diff 7eb9914 f7ac37d -- SPEC.md`), grouped by section and said
in plain words, then the decisions waiting for you and a fault I am fixing next. Each change carries one tag:

- **Rule**: a behaviour or rule change.
- **Decision**: a change that carries or concerns a **[Decision to confirm]**, with a written default already applied,
  since no designer was available.
- **Numbers**: a number or evidence update.

M3 adds 21 **[Decision to confirm]** marks: 11 point to O11 (one of them to its class (j), one to its class (k)), 9 to
O10 and 1 to O7. O10 and O11 are new rows of §17.1; O7 and O8 changed; O9 and the 22 questions of §0.4 did not. One
older mark now points to O1 instead of §17 as a whole. No tunable you approved changed value, and no new tunable joins
§16.10. §16.18 lists 7 new fixed constants (and repeats one), and §16.32 gains 4 test settings.

This list covers M3 as committed (f7ac37d, 2026-11-17), after five review rounds. The recommendations are the lead's,
and the "I" in this document is the lead too.

## Words used below

- **Stud**: Roblox's unit of length, the only one the SPEC uses. A sword fits in 1.6 × 5.0 × 0.6 studs, the Starter
  Sword's blade is 0.060 stud thick, and no part may be thinner than 0.02 stud.
- **d** (also written D): a forging step's difficulty, from 0 to 1, measured from the design. **G** is the part of it
  that comes from the shape, a weighted mix of the step's factors. Materials add nothing in the MVP, so d = G; "G moves
  0.0007" means the difficulty changes by that much.
- **Tier**: a step with d under 0.2 plays **Normal**; from 0.2 it plays **Hard**. Higher labels (Expert from 0.4, then
  Master and Hell) are shown but play as Hard. "A tier" below means a step that changes between Normal and Hard.
- **Factors**: the shape measures each step reads. Smelting: Volume. Hammering: Thinness, Asymmetry and
  SurfaceComplexity (weights 0.40, 0.30, 0.30). Sharpening, on Blade parts only: EdgeLength, Asymmetry and
  SurfaceComplexity (0.50, 0.30, 0.20).
- **Thinness**: how thin the metal is for the sword's length. It is read at up to 400 **probe points** in the metal; at
  each, the thickness is the shortest of a few **measuring lines** through it, along the sword's thickness and along the
  part's own axes (the SPEC's "chords").
- **SurfaceComplexity**: visible area against volume (a cube scores 1). **Asymmetry**: how much the left and right
  halves differ.
- **The edge**: the sharpenable edge. The blade is seen from the side on a grid of 0.02-stud cells; its thin rim is
  traced into chains, and only the longest, the **main chain**, counts. EdgeLength is its length, and Sharpening's trace
  follows it. **cutIndex** (the blade's length against its mean thickness: 1 = thin and long, 0 = wide and heavy) feeds
  the Damage stat, not the difficulty.
- **The verdict and the 2 % rule**: before anything is measured, every part gets a verdict. A part is **cleaned**,
  ignored for difficulty, when it is Dust (a speck under 0.0002 stud³) or Enclosed (under 2 % of its surface shows).
  Every other part is **kept**. Then **the measure** reads the kept parts for the factors (their visible surface, volume
  and contacts). It ranks the parts (the larger first, then where each stands), and that ranking settles which part
  keeps a face two parts share, which owns an overlap and which uses a limited sampling budget first.
- **The hide distance** (`HIDE_OFFSET`, 0.012 stud): a face counts as hidden when the point 0.012 stud straight out from
  it, its **hide point**, lies inside another part (a face buried in another part, or lying flat on the face of a part
  that ranks higher, is hidden too). Two faces closer than that hide each other: a **hidden gap**, too narrow to see.
- **Flush**: touching exactly, with no gap and no overlap. A **flush cut** splits a part into pieces that look like the
  whole; a **seam** is where two such pieces meet. A **laminate** is a blade built of plates stacked through its
  thickness; "turned 30°" means tilted 30° about its length.
- **Typed another way**: the same part described by other numbers, as a Block typed 0.15 × 0.05 × 0.12, or
  0.05 × 0.15 × 0.12 with a quarter turn. It looks identical (the SPEC says "written").
- **Test swords** (the SPEC's **fixtures**): F1–F5 (F5 is the Starter Sword), C01–C15 (calibration swords: C02 the plain
  iron arming sword, C09 the ornate one) and the X, A and P sets (regression checks, invalid or edge cases, slow
  designs). The **plausible designs** are 33,389 generated swords of the kinds players might build; the **worst valid
  designs** are the slowest valid designs the reviewers found.
- **Times**: measured in Lune, the test tool on this PC; the SPEC estimates Roblox Studio at about 2.6 × Lune. The
  **speed guard** is a test limit, not a game rule: the speed test fails if a design takes more than 60 ms in Lune
  (`ANALYSIS_LUNE_MAX_MS`). The **57 ms gate** is my stricter limit for adopting a change (the slowest valid design must
  stay at or under 57 ms); the SPEC names it without defining it. The server runs the analysis 4 ms per **Heartbeat**
  (one server frame).

## In short

- **Every step's difficulty now comes from the game's own code.** Three new modules measure the edge (Edge), the factors
  (Factors) and each step's d and tier (Difficulty). The calibration table (§5.5) now holds what the game computes: a
  few values moved a little (C04, C05, C09, C13) and no tier changed. C02 still plays Normal on every step (highest
  0.1318), and so does the Starter Sword (highest 0.1037).
- **A hidden part no longer tilts the sword or moves its balance.** The grip point, the sword's axis and the guard line
  now come from kept parts only, so a hidden part moves none of the balance, reach, blade length or cutIndex a player is
  shown. Before, a hidden strap could tilt the sword (cutIndex 0.7242 → 0.5080) and a hidden Guard block could move the
  balance point (−0.057 → −0.131).
- **The same solid reads more nearly the same.** Thinness now reads along all three of a part's own axes and places its
  probe points by a fixed rule, so a part typed another way gives Thinness the same probe points (the other factors can
  still follow how round parts, Wedges and some Blocks are typed: G up to 0.0093, no tier, O11 (i)). A measuring line
  along another part's face counts as touching it, and plates with a hidden gap between them read as one solid at any
  slant, except at a slanted slit's open end and beside a flush seam (O10, O11). Moving a sword up no longer changes the
  edge or Thinness (a face typed exactly on the tie, O11 (h), is the one exception), though G can still move through
  M2's older sampling (the fault below).
- **§5's promise now names three limits.** Hidden filler, specks, invisible construction choices and the material cannot
  move a tier, but for round parts (O9, from M2), what the 2 % rule itself lets through (O10: hollow blades, flush
  layers, a face against a very thin part and a slanted slit's open end, among others) and how parts are read rather
  than the solid they make (O11: eleven classes, (a)–(k)). Each has measured figures and a default. The largest moves
  need designs built to show them, but a few reach ordinary designs: a face against a very thin part plays 197 of the
  plausible designs a tier harder than a segment test would (O10).
- **A fault to fix next.** Moving a whole sword can move G: along its thickness on 2,081 of the 10,883 plausible designs
  tested (11 change tier), and up on 357 of 11,129 (2 change tier) (O11 (j)). It comes from M2's code, and I am fixing
  it on its own before M4.
- **Speed.** Real swords take at most 14.2 ms in Lune (C09; about 37 ms in Studio). The slowest valid design takes about
  55 ms in Lune (about 143 ms in Studio, over about 36 Heartbeats), about 5 ms under the 60 ms guard, so the speed test
  needs a quiet machine (O7).
- **Tests.** New test contracts cover the edge, the factors and the difficulty, and the Studio parity check (S-PAR-02)
  now compares the whole analysis on server, client and Lune.

## By section

### §0.5 What changed from the design draft

- **Decision** (O10, O11): the row on the factors ("filler cannot buy a tier") now says the factors are unchanged by
  splitting a blade, by how a part is typed and by moving a sword up, then lists the known exceptions with some figures
  and points to O9, O10 and O11: for example a flush seam in a tilted, split blade (Hammering 0.1734 → 0.3095 Hard), a
  blade made a sealed hollow box (Hammering 0.1035 → 0.5355 Hard) and a whole design moved along its thickness (a tier
  on 11 of 10,883 plausible designs). O11 gives every class with its largest figure.

### §1.3 Layering and requires

- **Rule**: Physics gains Edge, Factors and Difficulty. Its order is now Shapes → Gjk, Cover → Sampling → MassProps →
  Edge → Factors → Difficulty → Analyze.

### §4.1 Overview, modules and determinism

- **Rule**: the edge and the factors visit parts in the measure's ranking (the larger part first, then where it stands),
  never in the order the parts were added, so neither a part's internal number (its id) nor the order of the parts can
  change a factor.
- **Rule**: the places where the build departs on purpose from the prototype (the reference code written with the SPEC)
  now include the physics frame (§4.5), how the edge's grid is read (§4.6) and Thinness (§5.2).
- **Numbers**: on the prototype's 66 fixtures, the build's Thinness differs by up to 0.237 (P3) and EdgeLength by up to
  0.083 (P2), and 15 step values of 14 fixtures differ (C04, C05, C09 and C13 among them). Tests hold the other factors
  to the prototype; Thinness and EdgeLength are the build's own, held by goldens (stored expected results), and the 12
  fixtures whose edge differs are listed (`OFF_PROTOTYPE`).

### §4.2 Validation

- **Rule** (wording; nothing changes for players): V4, the "blade above the grip" check, still uses every Grip part,
  hidden or not, because it is asked before the verdict. Only the physics frame moved to kept parts (§4.5).

### §4.4 Exposure and cleaning

- **Rule** (wording): a hidden gap hides the faces across it only where the part beyond is thick enough to hold the hide
  point.
- **Decision** (O10): the hide test checks a single point, so where a face lies flush against a part thinner than
  0.012 stud, the hide point lands beyond that part and the face shows (on whichever of the two parts ranks higher). A
  Wedge bevel's thin edge on a Block shows a narrow band (5.9 % of C09's visible area), and a blade cut flush along its
  diagonal into two Wedges shows about a quarter of the cut (F5's Sharpening 0.0989 → 0.1563).
- **Decision** (O11 (j)): the measure ranks parts of equal size by where they stand, including their distance from the
  plane z = 0 (the middle of the hitbox's thickness), so moving a whole sword along its thickness can reorder them and
  move mass and the measure. This is the fault I am fixing next (last section).
- **Rule**: a cleaned part still counts for validation (part counts, staying in the hitbox, connection, V4), for mass
  and the centre of mass by what it owns (what no visible part holds: an Enclosed part inside a visible one nothing, a
  filler in a sealed cavity its volume, a Dust speck its own volume; it can also change how finely another hidden part's
  shared space is measured, round 5 of the shift fix, below) and for the total length. It never counts for the grip
  frame, the guard line, reach, the blade's length, cutIndex, any factor or the edge. Before, it counted for the grip
  frame and the guard line.

### §4.5 Mass properties

- **Rule**: the grip frame (the grip point and the sword's axis, from which balance, reach and blade length are
  measured) and the guard line (where the balance point is counted from) come from the kept Grip and Guard parts only.
  Before, a strap hidden in A26's ring grip, turned 40°, tilted the axis (cutIndex 0.7242 → 0.5080), and a Guard block
  hidden in F2's blade moved the balance point (−0.057 → −0.131); now neither moves anything. The frame that difficulty
  uses was already fixed, pointing straight up.

### §4.6 Sharpenable edge (rewritten)

- **Rule**: each grid cell is read at a point a hair off its centre (0.0013 stud towards the centre plane, 0.0017 stud
  up), so that no face of a design snapped to a step of 0.0005 stud, or a multiple of it (the editor's default snap is
  0.05 stud), lies on it. Moving a sword up or along its thickness now keeps every cell, and a mirror image's cells are
  its mirror. Before, moving C09 0.037 stud along its thickness changed 240 cells (cutIndex 1 → 0.884).
- **Decision** (O11 (k)): one exception. Where a part lies flush with the face a measuring line leaves to cross a
  slanted hidden gap, rounding decides which part ends the line, and a move along the thickness decides again, so the
  edge's thickness, and cutIndex, depend on position (F5's blade turned 30° and split, five thin ribs flush under it:
  cutIndex 0.6740 or 0.6568). No tier moves.
- **Rule**: the blade's thickness joins plates across any gap the verdict hides, however slanted the line that crosses
  it, where the faces on both sides hide each other (a corner beside a face joins nothing). A laminate with a hidden gap
  is one solid here, but for the next two bullets (a slit's open end, a flush seam). Before, gaps joined only along the
  line, so F5's blade turned 30° and split read as two thin plates. The SPEC shows that the only air read as metal this
  way is the hidden gap's own (checked on 179,928 lines across round faces), except beside a part thinner than the hide
  distance (O10).
- **Decision** (O10): a slanted slit stays open where it meets the blade's outline, its mouth. A line entering there
  runs into air and stops, so the rim reads thinner (F5's blade turned 30°, whole and then split 0.0119 stud apart: mean
  thickness 0.0611 → 0.0591, cutIndex 0.7069 → 0.7381; EdgeLength the same).
- **Decision** (O11): the hidden-gap test checks only the part directly across, so a plate cut into flush pieces right
  where a line crosses reopens the gap there (F5's blade turned 30° and split 0.0105 stud apart, the upper plate in 4
  flush pieces: Hammering 0.3095 Hard, against 0.1734 for the same pieces 0.0100 apart). A rule that asked every part
  (fix round 3) joined visible air across an open slot (Sharpening 0.2728 Hard → 0.0720 Normal, the edge cut in two) and
  was withdrawn.
- **Rule**: the outline is smoothed (Douglas–Peucker) on whole-number grid points, exactly, so a move up keeps every
  chain and length to the last digit.
- **Rule**: as before, only the main chain counts; the SPEC now notes that a visible fin that breaks it measures the
  longer piece (X03, §5.6). cutIndex is 0 when the blade has no thickness, and it uses the kept-part frame: a visible
  grip part that tilts the frame moves it, a hidden one cannot.

### §4.7 Analysis types

- **Rule** (for developers; nothing changes for players): `measureInvalid` measures a design that fails V3–V5
  (connection, blade above the grip, a kept Blade and Grip part), never one refused earlier or "Too complex to analyse".
  Edge, Factors and Difficulty define their own result types.

### §4.9 Execution model and cost

- **Numbers**: times with M3 (Lune; Studio about 2.6 ×): real swords (the F, C and X fixtures) 3.5–14.2 ms (C09, about
  37 in Studio), the slow test designs P1–P5 6.6–29.0 (P1, about 75), the worst valid designs 20.3–53.4 (about 139).
  "Too complex to analyse" is answered in 10.1–24.4 ms. The slowest real sword is now C09 (was C05).
- **Numbers**: the longest stretch without a pause point (where the server can stop the analysis and do other work)
  stays under the 0.35 ms limit on the fixtures (0.079–0.239 ms) on a quiet machine. Under ordinary load a few fixtures
  pass it (F2 up to 0.489 ms), and when the whole test suite runs as one process, memory clean-up can pass it (P1 with a
  speck 0.36–0.60 ms, the worst designs up to about 0.7).
- **Decision** (O7): under the cap, the slowest valid design's whole analysis now takes about 143 ms in Studio (was
  about 94), about 36 Heartbeats of 4 ms (was about 24).

### §5 Difficulty (opening)

- **Decision** (O9, O10, O11): the promise that hidden filler, specks, invisible construction choices and the material
  cannot move a tier now names three limits that the SPEC measures and you decide: round filler at a round part's
  surface (O9, as in M2), what the 2 % rule itself lets through (O10), and what remains of cutting, typing and moving
  parts (O11). A closing note says O11 gathers every class and asks whether Thinness and the edge should read the solid
  itself.

### §5.2 Factors

- **Rule**: Thinness' probe points follow the solid, not how a part is typed: parts are visited in the measure's
  ranking, each part's sample points in a fixed order, and each part's share of probe points is spread over it by a
  fixed pattern that starts from its middle. A generated blade typed 24 ways used to spread over Hammering 0.0734–0.1226
  and, made 0.0475 stud thick, over 0.1893 Normal to 0.2051 Hard; it now plays 0.1032 in every one (0.1983 Normal when
  0.0475 stud thick).
- **Rule**: at each probe point the thickness is the shortest measuring line along Z (the sword's thickness) or along
  any of the part's own three axes (a Cylinder: its axis and two directions across it; a Ball: the world's axes).
  Before, it was Z and the part's thinnest axis only, which a cut could change: a fin cut into 9 flush pieces moved G
  0.3823 and a tier; now 0.0005. A Wedge's taper now reads as thin metal, so two of the slow test designs, P3 and P5,
  now play Hammering Hard (they played Normal; E-S2.13).
- **Rule**: measuring lines join across a gap up to the hide distance, or across any gap the verdict hides at any slant
  (before: up to 0.01 stud along the line). F5's blade turned 30° and split, its faces hidden 0.0105 stud apart, plays
  Hammering 0.1319 Normal; joined along the line only, it played 0.4095 Expert.
- **Rule**: a measuring line that runs exactly along another part's face counts as meeting it (every other part is read
  1e-10 stud, a ten-billionth of a stud, larger: `TIE`), so rounding no longer decides. Before, 53 of 3,000 generated
  designs moved up changed G, by up to 0.0055. Deciding these ties as touching changed d on 839 of the 33,389 plausible
  designs and the tier on 53 (47 of them swords with a fuller, a groove along the blade), against M3's earlier build,
  where rounding decided them. Only a face typed exactly 1e-10 stud from a line is rounding's call again (F5's tip so
  typed: G 0.0007 under 26 of 120 moves, no tier).
- **Decision** (O10): a cleaned part belongs to no factor, and a measuring line opens where it was. The slit's mouth
  thins Thinness too (F5's blade turned 45° and split 0.005 → 0.0119 stud apart: Hammering 0.1765 Normal → 0.2068 Hard).
- **Decision** (O11): the flush seam beside a slanted crossing (§4.6) reopens the gap for Thinness too, and a flush cut
  aimed at where its pieces' probe points fall can move G a tier.

### §5.5 Calibration and fixture tiers

- **Numbers**: the table now holds what the game's analysis measures, kept as goldens. Changes: C04's Hammering 0.3368 →
  0.3379 and Sharpening 0.4703 → 0.4769, C05's Hammering 0.1363 → 0.1369, C09's Hammering 0.3170 → 0.3201, C13's
  Hammering 0.1133 → 0.1137 (within its row's ≤ 0.1137). Every tier held.
- **Decision** (O9, O10, O11): the target "filler cannot buy a tier" now points to the limits §5 names.

### §5.6 Anti-gaming (measured)

- **Numbers**: ids and part order: any order gives the same edge and steps (C09, P5, P1). A whole mirror image of a
  generated design can move D up to 0.0621 (over 150 designs, no tier), because Thinness picks its probe points in the
  same direction along X in a design and in its mirror image, so the two sets of points are not mirrors of each other.
  Near-copies: X02 now 0.0010 from its one-piece blade (was 0.0006).
- **Numbers**: hidden gaps: F5, C02, C05, C08 and F2 with the main blade split through its thickness 0.0099, 0.0101 or
  0.0119 stud apart keep Thinness and cutIndex at every gap. Under the old rule (lines joined only up to 0.01 stud),
  F5's Hammering went 0.1035 Normal → 0.3981 Hard past 0.010, all five a tier.
- **Numbers**: grip decoration: a hidden part now leaves the physics alone. Taking the frame from kept parts changed the
  physics of 1,785 of the plausible designs, each with a cleaned Grip or Guard part (cutIndex by at most 0.0043).
- **Decision** (O10): a visible fin of 0.0003 stud³ (X03, kept because it shows) breaks F4's edge in two, and only the
  main chain counts: EdgeLength 5.7237 → 4.7564, Sharpening 0.3420 Hard → 0.1980 Normal.
- **Decision** (O7, O10, O11): the rows on gaps, on moves, cuts and typings, on speed and on what the 2 % rule itself
  lets through now carry the figures given under O7, O10 and O11 below: the seam, the mouth, a hidden gap's volume, a
  sealed hollow blade, a sandwiched core, a diagonal cut, a bevel's thin edge, every move and cut, and the slowest
  design's time.

### §13.10 Inspect

- **Rule** (the document only): the mark on "a modified client can copy a design" now points to §17.1 O1.

### §14.1 Layers and gates

- **Numbers**: the quick tests' 30 s gate: 25.9 s on a quiet machine, 30.2–30.7 s under ordinary load, so it too needs a
  quiet machine; past 27 s, fast batches of generated designs move to the long run.

### §14.6 Module test plans

- **Rule**: new or rewritten test contracts:
  - T-PHY-08: the physics frame and the guard line come from kept parts.
  - T-DIF-02: the formula that joins the material term and G into d.
  - T-DIF-04/05: enclosed parts, plain duplicates (same slot and material), dust and Iron ↔ Steel leave D, the steps and
    the edge unchanged to the bit; a hidden laminate gap reads as one solid; the flush seam (O11) is pinned, so a change
    that closes it must update the SPEC.
  - T-DIF-07, in four parts: moves, flush cuts, ids and order, and one solid typed another way.
  - T-DIF-08 (mirrored designs), T-DIF-12 (every fixture's goldens, from the game's analysis), T-DIF-13 (the regression
    cases' bounds) and T-EDG-01 (the edge's rules, its exactness and its costs).

### §14.7 Fixtures

- **Rule**: goldens come from the game's analysis (T-DIF-12). P4 may sit 0.01 stud from the hitbox, as in the prototype.
  X08's three cost cases are other names for P2, P1 and P5; P1–P3 also run with a Dust speck, floating or attached; a
  256-point zigzag edge is kept for M4's speed test (T-PERF-02).

### §14.10 Studio integration

- **Rule**: S-PAR-02 (server = client = Lune) now runs the whole analysis on every fixture and 200 generated designs and
  compares a digest, a fingerprint of all the results; M5 will add the forging pipeline's results. It passed in Studio
  before the commit.

### §14.11 Performance

- **Rule**: T-PERF-01 runs each case 15 times (`PERF_RUNS`) after a warm-up, alternating direction, with a memory
  clean-up before each timed run, and reads the medians. It runs alone, on a quiet machine.
- **Numbers**: the slowest valid design's 53.4 ms (about 55 projected) leaves about 5 ms under the 60 ms guard; under
  the machine's ordinary load the case fails (61.5–76.9 ms at 27–38 % busy).

### §16.10 Definitions/Balance

- **Decision** (O7): `VERDICT_WORK_MAX` keeps 700,000; its note adds M3's time (about 53 ms in Lune, about 139 in
  Studio; about 55 and 143 projected).

### §16.18 Physics/Analyze

- **Numbers**: new fixed constants, not tunables: `SAMPLE_X` 0.0013 and `SAMPLE_Y` 0.0017 (where a grid cell is read),
  `GOLDEN` 0.6180339887498949 (the probe points' step), `TIE` 1e-10 (the face-tie growth), `TAU_FLOOR` and
  `BLADE_LENGTH_FLOOR` 1e-6 (small floors in two formulas) and `WALK_ROW` 64 (pause points only); Cover's `AXIS_TIE`
  1e-9 is reused. `GOLDEN`, `SAMPLE_X` and `SAMPLE_Y` place points, so a change to any of them moves results and needs a
  new `BALANCE_VERSION`, the version number of the balance rules (0.0012 and 0.0018 would move 14 of the 70 golden
  entries, no d).

### §16.32 tests/lib/Tol

- **Numbers**: new test settings: `TOL_EDGE_REL` 0.02 (how far an edge length may differ, as a share), `PARITY_DESIGNS`
  200 and `PARITY_SEED` 0x5EED0002 (S-PAR-02's generated designs) and `PERF_RUNS` 15. `ANALYSIS_LUNE_MAX_MS` keeps
  60 ms; its note gives M3's times.

### §17.1 Product questions

- **Decision**: O7's times updated for M3; O8's alternative now marked "not built, unmeasured"; new rows O10 and O11. O9
  is unchanged. Details under "Decisions waiting for you".

### §17.2 Engineering items

- **Numbers**: pause-point gaps and times with M3, and the speed test needs a quiet machine; slivers between
  near-copies: X02 −0.0010 in the measure's ranked order (+0.0006 in part order).
- **Rule**: M3 visits parts in the measure's ranking, and §5.5 was measured that way (C09's Hammering 0.3170 → 0.3186,
  no tier). Thinness' face-tie rule has its own boundary (O11 (h)). A hidden strap no longer tilts the sword (§4.5). M3
  stores S-PAR-02's Lune digest of the whole analysis.
- **Decision** (O10): M3 adds no rule for what the 2 % rule lets through: a cleaned part counts for nothing in every
  factor, and a 2 % rule that looks through cavities or layers would be the verdict's change. The sandwiched core,
  measured again on the game's analysis: D jumps 0.27–0.41 over 12 crossings in 96 families (7 tier changes). A new row
  on the edge's main chain (X03's fin) sits under O10's text.
- **Decision** (O11): a new row on invisible building choices in general designs: what M3's fixes closed and what
  remains, with every figure.
- **Decision** (O7): the cost row adds M3's times.

## Evidence sections (docs/spec/SPEC-evidence.md)

New:

- E-S2.13 Difficulty as built (`m3/`): The §5 table · The edge · Douglas–Peucker on the outline's integer lattice · Ties
  under a shift · Invariance · Fix rounds 2–5 · A slanted slit's mouth · What the 2 % rule itself admits · The physics
  frame · Fix round 1 beyond the 70 fixtures · A face flush on a thin part · Cost · S-PAR-02's Lune digest

Changed:

- Contents
- E-S2.5 Regression fixtures (base F5; `reg`, `checks.luau`)
- E-S2.7 Grip-independent difficulty, and the two deviations (`adv`, `variants.luau`)
- E-S2.9 Calibration and the full fixture tables
- E-S8.4 Adversarial and regression fixtures
- E-S8.5 Case catalogue
- E-S8.6 Studio bridge, scenario assertions, shots, manual steps

M3's hand-off notes are new too: `docs/build/M3-notes.md`.

## Decisions waiting for you

Each gives the question, what M3 changed, what the game does now (the default, already applied), the options with what
the SPEC measured for them, and the lead's recommendation. M3 changed neither O9 (round parts, from M2) nor any question
of §0.4: O9 still waits as M2's list explains (`.build-notes\m2\M2-spec-changes.md`), and Q7's figures still hold (C02's
highest step 0.1318, the Starter Sword's 0.1037).

### O7: the cap on the hidden-part check (changed)

- **The question**: a design whose verdict would cost more than 700,000 work units (the check's own cost count) is
  refused as "Too complex to analyse" and never measured. Is that right, and is the slowest valid design's time
  acceptable: about 78 ms in Studio for the verdict and, with M3, about 143 ms for the whole analysis, over about 36
  Heartbeats of 4 ms?
- **What M3 changed**: before M3's difficulty, the slowest valid design's whole analysis took about 94 ms in Studio
  (about 24 Heartbeats); with it, about 55 ms in Lune, about 143 in Studio.
- **What the game does now**: the cap as stated. Real designs stay about 2 × under it: P1, the heaviest, spends 330,993
  units (29.0 ms in Lune, about 75 in Studio), and the plausible designs at most 104,573. But a regular sword of 24 rods
  0.12 stud thick, every part showing, spends 471,161 units (1.49 × under), and honest variants of it pass the cap and
  are refused.
- **Options**:
  - Keep the cap (default): no frame hitch, one analysis at a time per player; those rare honest variants are refused.
  - Another cap: a higher one lets those variants through but admits slower designs (with no cap, searches for slow
    designs reached 273 ms in Lune for the verdict alone); a lower one refuses more honest designs. The SPEC measures no
    other value.
- **Lead's recommendation**: keep it as stated. Real swords stay about 2 × under the cap, and the slowest valid design
  is sliced into 4 ms pieces, so no player sees a hitch.

### O8: a slot label moves Sharpening (changed a little)

- **The question**: Sharpening reads only parts labelled Blade, so a label moves it: F3 with its main blade labelled
  Guard drops from 0.6104 Hard to 0.0645 Normal, and so does F3 with a Guard part a hair larger enclosing its blade.
  Accept it, or choose Sharpening's parts by shape instead of label?
- **What M3 changed**: the SPEC now says the shape-based rule is not built, so what it would move and cost is
  unmeasured.
- **What the game does now**: the label of the part that shows counts. Hidden copies cannot take a blade out of the
  Blade set, and a copy brings a part in no more than relabelling it does.
- **Options**: accept (default); or tie Sharpening's set to the shape, so that no label moves it (not built: what else
  it would move, and its cost, are unmeasured).
- **Lead's recommendation**: accept. The label is visible and the player's choice, and the enclosing trick does no more
  than an open relabel.

### O10: what the 2 % rule itself lets through (new)

- **The question**: the 2 % rule (a part showing under 2 % is cleaned; a face is hidden when its hide point lies in
  another part) lets some invisible building choices change d. Accept these limits for the MVP, or change how cleaned
  parts and hidden faces are read?
- **What it lets through** (largest figures):
  - A cleaned part counts for nothing, and a Thinness line opens where it was: a core between two cheek plates, where a
    slight change takes its visible share across 2 %, makes D jump 0.27–0.41 (12 crossings in 96 test families, 7 tier
    changes); a recessed core cleaned by a sheet over it moves D up to 0.3680 (2 tier changes).
  - A sealed cavity: a filler inside it shows (Smelting 0.1376 Normal → 0.4463 Hard); an empty one wider than the hide
    distance shows its inner faces, and its walls read as thin plates (F5's blade made a sealed box, cavity 0.0121 stud
    thick: Hammering 0.1035 Normal → 0.5355 Hard).
  - Flush layers, each under 2 %, are each cleaned (a blade in 8 flush layers: Hammering 0.0582 Normal → 0.7000 Hard);
    hidden sheets can clean a core that shows 11.92 %.
  - A face flush against a part thinner than 0.012 stud shows (C09's core cut along its diagonal into two Wedges:
    Sharpening 0.1904 Normal → 0.2225 Hard; a Wedge bevel's thin edge: 5.9 % of C09's visible area).
  - A slanted hidden slit stays open at its mouth (F5's blade turned 45° and split 0.005 → 0.0119 stud apart: Hammering
    0.1765 Normal → 0.2068 Hard).
  - A hidden gap's own volume raises SurfaceComplexity (C02's blade split 0.0119 stud apart: Sharpening 0.1318 → 0.2016
    Hard).
  - Related, though visible: a fin that breaks the edge's main chain (X03 on F4: Sharpening 0.3420 Hard → 0.1980
    Normal).
- **What the game does now**: all of the above, as built.
- **Options**:
  - Cleaned parts: keep them inert (default), or join Thinness lines through them. That removes Thinness' share of the
    sandwich jump (up to about 0.36) but gives hidden filler between plates a way to move Thinness, which §5 forbids.
    The full fix is a 2 % rule that looks through sealed cavities or stacks of layers: not built, and the SPEC gives no
    cost.
  - The hide point: (i) one point, as built: in the measure it only adds visible area, so designs read harder, never
    easier (an invisible diagonal cut can still make a step Hard), and in the verdict it can keep a part that only such
    thin bands show. (ii) A segment test (hidden if any part lies within 0.012 stud straight out): closes the diagonal
    cut and changes no calibration tier (C09's Hammering 0.3201 → 0.2432, Sharpening 0.1904 → 0.0955), but moves d on
    5,191 of the 33,389 plausible designs and the tier on 197, all Hard → Normal (185 of them built on C09). It costs
    about a fifth more time on the slowest design (about 55 → about 65 ms, past the 60 ms guard); its verdict half is
    not built, and every verdict figure of M2 would be measured again.
  - The slit's mouth: (i) as built; it mostly reads designs harder. (ii) An exact closure (exact on flat faces), tried
    for Thinness only: moves no calibration sword, d on 96 plausible designs and the tier on 2 (ribbed bars Hard →
    Normal); its end tests alone cost about a tenth to a sixth of the slowest design's time (about 59–64 ms: at or past
    the 60 ms guard and past the 57 ms gate), before the rest is built. A cheaper closure that grows every part would
    lengthen lines near every edge of every design. (iii) O11's measure that follows the solid.
- **Lead's recommendation**: accept them all for the MVP. Cleaned parts stay inert, as §5 needs (reading through them
  would let hidden filler move Thinness). In the measure, the single hide point errs one way only, towards harder; the
  segment test would correct that, playing 197 plausible designs a tier lower (all Hard → Normal, most of them built on
  C09), but it costs about a fifth of the slowest design's time, past the 60 ms guard, and its verdict half is not
  built. The mouth stays as built: an exact closure would change the tier of only 2 plausible designs, and its end tests
  alone would cost a tenth to a sixth of that time. Revisit if playtests or telemetry meet laminates, slanted slits,
  sealed cavities, diagonal cuts or fins on edges.

### O11: how parts are read, rather than the solid they make (new)

- **The idea in plain words**: Thinness and the edge do not measure the sword as one solid shape. They measure each part
  on its own, along lines through its metal, and join those pieces of line by rules where parts touch, overlap or face
  each other across a gap too narrow to see. SurfaceComplexity, Asymmetry and, where round parts or many parts overlap,
  Volume count sample points laid on each part as it is typed, in an order set by where the parts stand. So some
  invisible ways of building the same-looking sword (cut into flush pieces, split by a hidden gap, a part typed another
  way, hollowed, moved) read differently: G, and at times the tier, follows how and where a sword is built, not only
  what it looks like.
- **The question**: accept the classes below for the MVP, or have Thinness and the edge read the solid itself (option
  (iii))?
- **The classes, as built**, each with its largest effect and the design that shows it:
  - **(a) A slanted slit's mouth.** A measuring line that enters a slanted hidden gap where it meets the blade's outline
    runs into air and stops, so the rim reads thinner (also O10). d up to 0.1440 and a tier: a plausible ribbed bar
    plays Hammering 0.3219 Hard, 0.1779 Normal with the mouth closed; F5's blade turned 45° and split 0.0119 stud apart
    plays 0.2068 Hard (0.1833 Normal closed).
  - **(b) A flush seam beside a slanted crossing.** The plate beyond a slanted hidden gap, cut into flush pieces right
    where a line crosses, reopens the gap there. +0.1361 and a tier: F5's blade turned 30° and split 0.0105 stud apart,
    the far plate in 4 flush pieces, plays Hammering 0.3095 Hard, against 0.1734 Normal for the same pieces 0.0100
    apart.
  - **(c) An aimed flush cut.** Each piece of a cut part takes its own probe points, from its middle, so a cut can
    choose where they fall. G 0.218 and a tier either way: a plate overhanging a thick blade, cut into 11 pieces,
    Hammering 0.1075 Normal → 0.3254 Hard; overhanging the other edge by 0.08 stud, 0.2158 Hard → 0.0024 Normal. Unaimed
    cuts of 500 generated designs: up to 0.0379, one tier (a step 0.0011 over the Hard line).
  - **(d) A Blade Wedge cut along its length.** The same, for a Wedge cut flush along its length. G 0.0521 (a generated
    design, Hammering 0.2815 → 0.2294); a tier on 2 of 450 such cuts (0.2037 Hard → 0.1645 Normal).
  - **(e) A face against a very thin part.** The hide point, 0.012 stud out, lands beyond a part thinner than that, so
    the face counts as showing (also O10). +0.0784 and a tier: F5 with a 0.05-stud blade cut along its diagonal into two
    Wedges, Sharpening 0.1440 → 0.2224 Hard; C09's core so cut, 0.1904 Normal → 0.2225 Hard.
  - **(f) An empty sealed cavity.** A cavity wider than the hide distance shows its inner faces, and its walls read as
    thin plates (also O10). 0.43 and a tier: F5's blade made a sealed box, cavity 0.0121 stud thick, Hammering 0.1035
    Normal → 0.5355 Hard.
  - **(g) A hidden gap's volume.** SurfaceComplexity takes the gap's air out of the volume while its hidden faces add no
    area, so the score rises (also O10). 0.0698 and a tier: C02's blade split 0.0119 stud apart, Sharpening 0.1318 →
    0.2016 Hard.
  - **(h) A face typed on the tie.** A face typed exactly 1e-10 stud from a measuring line is decided by rounding; only
    typing can put it there. G 0.0007 under 26 of 120 moves up, no tier: F5's tip typed 1e-10 stud over its blade.
  - **(i) A part typed another way.** M2's sample points follow how a part is typed: a Ball turned, a Cylinder spun, a
    Wedge typed its other way, a Block whose faces straddle where another part's hiding stops. G up to 0.0093, no tier
    (a Ball turned); a Cylinder spun 30°: 0.0048; C09's bevel: 0.0007; F5's tip on a cut, tilted laminate: 0.0005.
  - **(j) A whole-sword move.** M2's ranking of equal-sized parts and its sampled overlaps follow where the sword
    stands. Moved 0.037 stud along its thickness, G moves on 2,081 of 10,883 plausible designs tested, up to 0.0354, and
    11 change tier; moved 0.3317 stud up, on 357 of 11,129, up to 0.0363, and 2 change tier. The SPEC lists it with the
    default "as built"; I treat it as an engineering fault, not a design call, and am fixing it (last section).
  - **(k) A part flush at a slanted gap.** A rib flush under a split blade, where a line leaves for a slanted hidden
    gap: rounding picks which part the gap's test asks, and a move along the thickness picks again. No tier: cutIndex
    0.6740 or 0.6568 by position, Hammering the same (F5's blade turned 30° and split 0.0105 stud apart, five 0.02-stud
    ribs flush under it).
- **What the game does now**: every class as built (option (i)), with tests that hold today's figures; (j) too, until
  its fix lands.
- **Option (iii), a measure that follows the solid** (described in the SPEC, not built):
  - **The idea**: measure the visible solid itself. The kept parts are merged into one shape, gaps too narrow to see are
    filled, and Thinness and the edge read it on one grid fixed to the sword (the edge's grid), not to its parts;
    Thinness' probe points become the grid's metal columns.
  - **It would close** (b), (c), (k), Thinness' share of (d), and (a) where the blade's outline meets the gap square-on.
    Where the outline meets it at a slant (a bevelled rim, a round face), the reading can run up to about the hide
    distance past the mouth.
  - **It would leave** (e) and (g), which are O10's; (f), since a cavity wider than the hide distance is air between
    metal; (h), moved to the grid's sample points; (i) and (j), which are M2's; and Asymmetry's share of (c) and (d),
    unless Asymmetry reads the grid too. It would also read air narrower than the hide distance as metal where the
    verdict may show a face beside it (the narrow end of a V).
  - **What it would move**: every design's Thinness. Estimated on the calibration swords: d by up to 0.0425 (C09's
    Hammering 0.3201 → 0.3626), every other value by 0.0091 or less, Smelting and Sharpening not at all, no tier; C02
    and the Starter Sword keep their margins. The plate of (c), overhanging by 0.05 stud, would play 0.1271 whole and in
    6 or 11 pieces (as built: 0.1075, 0.2141 and 0.3254). The calibration table, the goldens and the Studio parity
    digest would all be made again.
  - **What it would cost**: about 4–12 ms more on the two slowest designs, whose about 55 ms would become about
    59–67 ms: at or past the 60 ms guard and past the 57 ms gate, unless the analysis budget is cut again (which touches
    O7). A 3D grid fine enough to see the gaps themselves would cost some 60 ms on one of them by itself.
- **Other options**:
  - (ii), for the aimed cut alone: at least 8 probe points per part (tried, not adopted). The aimed plate then keeps its
    tier (0.1075 whole, 0.0808 in 3–11 pieces), but a whole part and its pieces still differ and can still change tier
    (a 0.025-stud plate: 0.1871 Normal whole, 0.2101 Hard in 4 pieces); 1.2 % more probe points, time within the noise.
  - O10's options, for (e)–(g).
  - Sample grids for Asymmetry, round parts and Wedge surfaces that follow the solid: a separate study, cost unmeasured.
- **Lead's recommendation**: accept every class but (j) as built for the MVP. The largest moves need designs built to
  show them (a laminate turned and split or seamed, an aimed cut, a diagonal cut, a hollow box). On the plausible
  designs, (e) plays 197 designs a tier harder than a segment test would, and (a) 2 harder than a closure would. (iii)
  would close (b), (c) and (k), and most of (a) and (d), for about 4–12 ms more on the slowest designs, past the 57 ms
  gate: a study for a later phase. Revisit if playtests or telemetry show segmented, laminated or hollow designs moving
  tiers. (j) is not a design call: see the next section.

## A fault I am fixing next

O11 (j) is not a design call. It is an engineering fault, and I am fixing it on its own before M4. Until then the SPEC
keeps it under O11 as a decision to confirm, with the default "as built"; you need not decide it.

- **What happens**: when parts have the same size, M2 orders them by where they stand: height, then distance from the
  centre plane x = 0, then distance from the plane z = 0, the middle of the hitbox through its thickness. That order
  decides which part keeps a face two parts share, which owns an overlap, and which is measured first while a limited
  measuring budget lasts. Moving every part of a sword together along its thickness changes those distances, so it can
  change the order, and with it G. M2 also estimates some overlaps from sample points instead of computing them exactly
  (a round part's, or a part's under more than 3 higher-ranked parts), and those estimates can come out differently once
  the sword has moved: this is what moves G when a sword is moved up.
- **How much**: moved 0.037 stud along its thickness, G moves on 2,081 of the 10,883 plausible designs tested (a third
  of the set, those still inside the hitbox after the move), up to 0.0354, and 11 change tier. Ranked by where parts
  stand along the thickness rather than by their distance from the middle (a test variant), 110 still move and 2 change
  tier, through the sampled overlaps. Moved 0.3317 stud up, which keeps the order, 357 of 11,129 move, up to 0.0363, and
  2 change tier. The edge did not move on any of them.
- **Why it is a fault**: the same sword, moved as a whole, looks the same and should play the same. The cause is M2's
  code (M2's own version gives the same numbers), not a rule M3 chose.
- **The plan** (`.build-notes\m3\m3_journal_r5.txt`): first establish which whole-sword moves a player can make in the
  editor, and why the ranking uses distances from the centre planes (so that mirror images read alike). Then choose the
  smallest fix: put every design in a standard position before analysis, rank parts from the design's own centre, or
  anchor M2's sampling to the design. Verify it, commit it on its own, run the Studio parity check again if results
  move, and update O11 (j).

## Update: the shift fault is fixed

Written after M3 (2026-11-17), when the fix described in the last section was built and measured, and brought up to date
on 2026-11-18 after the fix's second and third rounds and on 2026-11-19 after its fourth to tenth. It is not committed
yet: the Studio check that compares Lune with Roblox (S-PAR-02) had to run again first, because the fix changed some
stored results (below); it passed on round 5's code on 2026-11-19 (3 Play sessions), and rounds 6 to 10 changed none of
the files it reads. The SPEC now says all of this (§4.3, §4.4, §5, §5.6, §17.1 O11 and O12; the evidence in E-S2.14).

### What changed

- **The fault**: moving a whole sword, every part together, along its thickness or up and down could change its
  difficulty. Parts of the same size were ordered by their distance from the build box's centre planes, and a few tests
  (does this part only touch that one, how many sample points fit in an overlap, is a gap exactly 0.01 stud) were
  decided by the last digit of the arithmetic, which a move changes. Before the fix, up to 5,125 of the 33,389 sample
  swords changed difficulty when moved along their thickness (22 changed tier), and up to 547 when moved up (2 tiers).
- **The fix**: for measuring, visible parts of the same size and height are now ordered by where they stand from the
  middle of the group of visible parts they match, counted in billionths of a stud so that rounding cannot reorder them;
  for the hidden-part check, parts of the same size, slot and height are ordered as at M3, by their distance from the
  build box's centre planes (round 3, below). Heights are counted in billionths of a stud in both. And the five tests
  that rounding used to decide now have a tiny fixed margin: two parts that only touch face to face never count as
  overlapping, an overlap's sample grid keeps its size, the symmetry check's neighbour list keeps a part at exactly its
  reach, the final 4-decimal rounding of G ignores a factor's last digits, and a gap of exactly 0.01 stud always counts
  as touching.
- **Round 2** (2026-11-18): the first version ordered those parts from the sword's grip point, and the reviewers found
  three ways around it, each needing an unusual build: two twin parts whose heights differ in the sixteenth digit (one
  dragged up 0.2 from 1.4, its twin typed at 1.6) could swap places when the sword moved up; a hidden speck in the grip
  could move the grip point and so choose which of two almost identical grip copies was kept, which turned a test
  sword's Hammering from Hard to Normal; and part numbers could decide between parts less than a billionth of a stud
  apart. Ordering from the middle of each group closes all three: the 20,676 sample swords given such twins no longer
  change when moved, and no hidden speck or part number changes a tier.
- **Round 3** (2026-11-18): the reviewers found that round 2's order for the hidden-part check could itself be steered
  by a hidden part. Copy a part, nudge the copy a hair (one of the two is then hidden), and copy the hidden one again in
  place: that extra hidden copy moved the middle of the group, and so decided which copy the game kept. The ornate test
  sword C09, its blade core made 2.3 stud long, went from Sharpening Hard (0.2110) to Normal (0.1967) this way, a
  laminated sample hilt from Hammering Normal (0.1175) to Hard (0.7000), and 71 of 2,644 sample swords given such a copy
  changed a tier. A mirror image could also swap which copy was kept (a sample laminate, Sharpening Normal 0.1950 → Hard
  0.2099). Every rule tried for this order fails one of three things: moving the whole sword, mirroring it, or ignoring
  hidden parts. The distance from the centre planes, M3's own rule, fails only the first, so the hidden-part check uses
  it again (keeping round 2's height fix), while measuring keeps round 2's order, which counts visible parts only. Now
  none of the hidden-copy tricks changes anything (13,522 tries on those 2,644 swords), mirror images keep the same copy
  as at M3, and round 1's three problems stay fixed.
- **Round 4** (2026-11-19): the reviewers found that a hidden part could still nudge the weight shown, though never the
  difficulty. When two hidden pieces overlap each other, one of them counts for the shared space, and the order that
  decided which one could be moved by a third hidden piece, such as a copy made with Ctrl+D: on a test sword with a
  closed box filled by an iron and a steel piece, that copy moved the mass by 0.135 grams (out of 1.29 kg) and the
  balance point slightly, and another build moved it by 0.2 grams. At M3 this could not happen. Now a hidden piece is
  placed in that order from the middle of the visible parts: between two hidden pieces of the same size and height, the
  material decides, then where each stands from that middle, which no hidden piece, no part number and no slide of the
  whole sword can change, and a mirror image only in the rare cases below. The reviewers' own repair left that choice to
  how each piece is turned, then to the part numbers: a mirror image of the whole sword could then swap a piece and its
  mirror copy, and the order in which two identical hidden pieces were made could move the mass by 0.2 grams on a small
  test build, so it was changed. Nothing moved on any test, generated or sample sword. Two rare cases are left: two
  identical hidden pieces of one material placed exactly symmetrically about the middle of the visible parts swap under
  a mirror image, which can move the mass by a few hundredths of a gram (0.016 grams on a test build), as such pairs
  about the centre planes did at M3; and so do two pieces that stand at the same place, turned differently (a piece and
  a Ctrl+D copy of it rotated where it stands), 0.024 grams on a test build, as at M3 (round 5 corrected this note,
  which said one). The text was corrected where it said a hidden part never moves the weight, and where it said no joint
  count changed when a whole sword moves (the three stacked-copy test swords do change it, with the same difficulty). To
  keep the quick test run under its 30 seconds, the 8 slowest checks this fix had added now run only in the full test
  run, which still runs before every commit.
- **Round 5** (2026-11-19): the reviewers found that a hidden piece could still change the weight shown, never the
  difficulty, in a second way: not by choosing which hidden piece counts for a shared space, but by changing how finely
  that space is measured. The game measures the space hidden pieces share with one common budget of sample points, each
  hidden piece against the pieces that overlap it and come before it. A copy made with Ctrl+D and left in place did
  this: on one sample sword such a copy moved the weight shown by 5.6 grams (of 660 grams), which M3 did not do on that
  sword (it did on 19 others, by up to 6.9 grams: round 6, below). An exact copy sitting on its original adds nothing to
  what covers a piece, so it is no longer counted twice: on a sword that stays valid, a copy made with Ctrl+D and left
  in place changes nothing, unless its slot or material puts it ahead of the original in the game's measuring order;
  then it counts instead of the original, as if the original had been given that slot or material (rounds 6 and 7,
  below). Of 22,243 such copies made in their original's slot and material that keep the sword within its piece limits
  (615 of them on 105 sample swords that are invalid anyway, no visible piece left in their blade), one of every part of
  every fifth sample sword with a hidden piece (counted from two starting swords; 1,978 more put too many pieces in one
  slot or in the sword, which makes it invalid), none changes anything now (11 did). The rest stays as at M3, now
  written down: a hidden piece that adds space of its own to measure, such as a ball buried in the pommel, can make the
  shared budget coarser for the others; on one test sword with a sealed box filled by one piece, that moved the weight
  shown by 42 grams of 1,320 and the balance point a little, but only for filler pieces in a narrow band of sizes, and
  on the sample swords tried it moved no other piece's share (824 hidden copies, 1,011 buried balls; on 8 of those
  swords the buried ball's own share moves the weight by 0.06 grams: round 6, below). It can change only the weight and
  the balance point shown, and with them the Damage and Balance stats, never the difficulty, a tier, the quality or the
  rarity. The text also said a mirror image could swap hidden pieces only in one rare case; it can also swap two pieces
  standing at the same place turned differently, or two corner wedges there whose sizes are swapped (round 6), as at M3
  (above). Nothing moved on any test, generated or sample sword, and it costs no measurable time. To keep the quick test
  run inside its time limit with room to spare, six more slow checks now run only in the full test run, which still runs
  before every commit: four this fix had added and the two slowest of all. On a quiet computer the quick run now takes
  about 28 seconds, where round 4 took about 29.5 in the same minutes.
- **Round 6** (2026-11-19): the reviewers found round 5's game code right and final: on all 37,725 test, generated and
  sample swords, and on the mirror images of the test swords, 200 generated swords and a third of the sample swords, it
  gives exactly round 4's results, and none of the Ctrl+D copies they measured, left in place in their original's slot
  and material, changes anything. But five sentences round 5 wrote said more than the measurements show, so this round
  changed only the text and one test, no game code. The rules now say only how a hidden piece can still change the
  weight shown (by changing how finely another hidden piece's shared space is measured), that it never changes the
  difficulty, a tier, the quality or the rarity and why, the copy rule (as round 7 words it, below), one example (the
  sealed box above, 42 grams of 1,320) and that it is rare on real swords; every count moved to the evidence file, each
  with the test that measured it, the swords it tried, what it compared and who ran it. What was corrected, with the
  measurements behind it. First, a copy of a hidden piece given a more important slot than its original's (the order is
  blade, guard, grip, pommel) counts again among the pieces that cover others, as relabelling the original
  would: on the first reviewer's test sword, a sealed box with two filler pieces, such a copy moves the weight shown by
  2.4 grams of 1,289 and leaves the difficulty alone, as at M3 (his test `relabel`, run again by the fixer on this
  round's code, on round 4's and on M3's). Second, the first reviewer's buried specks moved the weight shown by 1.2 and
  2.6 grams in a box of his own, not in the second reviewer's (his tests `hsteer2` and, with specks of the smallest size
  the editor allows, `hsteer3`); in the second reviewer's box they move it only by their own share, 0.0015 and 0.023
  grams (`specks6b`, `probe6s`). Third, M3 itself moved the weight with Ctrl+D copies on 19 sample swords, by up to 6.9
  grams, not on 7 by 0.89 grams, which was half the sample: both reviewers copied every part of every fifth sample sword
  with a hidden piece, counted from two starting swords, on M3's code (`ctrld`). Fourth, the narrow band of filler sizes
  in the second reviewer's box is about 0.2555 to 0.2655 stud, not 0.256 to 0.264 (the first reviewer's `band`, between
  the earlier test's steps; the second reviewer's `probe7b`, every 0.001 stud). Fifth, of 1,011 sample swords given a
  ball buried in their largest visible block, none had another piece's share changed, but on 8 of them the ball itself
  counts for 0.06 grams, because its own sample points fall a little short of its volume when the shared budget is
  coarse (both reviewers, `speckall` and `sweepspeck2`; the fixer's `ballcells` shows the shortfall). Two smaller ones:
  of the 24,221 Ctrl+D copies, the 22,243 that keep the sword within its piece limits were measured (1,978 put too many
  pieces in one slot or in the sword; 615 of the 22,243 are on 105 sample swords that are invalid even without the copy,
  no visible piece being left in their blade), and the 824 hidden copies were of up to three hidden pieces a sword (633
  sample swords holding 872); and a mirror image also swaps two corner wedges standing at the same place with their
  sizes swapped, which moved the weight shown by 0.004 grams on a test build of the first reviewer's, as at M3
  (`cwmirror`, run again by the fixer). The copy rule's test gains the first reviewer's cases: it now catches six
  deliberately broken versions of that rule, five of which slipped through every test he ran on them before. Nothing in
  the game changed: every stored result and the Studio check's fingerprint are round 5's.
- **Round 7** (2026-11-19): the reviewers found round 6's game code and test right and final, and four of its sentences
  wrong. Round 6 had written the copy rule for one case only (a copy left in its original's slot), and each correction
  tried added cases but missed one: a copy of a hidden steel piece painted iron counts instead of the original, as
  repainting the original would (0.24 grams on the second reviewer's box with a steel filler; the first reviewer's
  `material`), and a copy of a hidden piece given a less important slot changes nothing (the second reviewer's
  `relabel6`). So the rule is now one sentence, the same everywhere: on a sword that stays valid, a copy made with
  Ctrl+D and left in place changes nothing, unless its slot or material puts it ahead of the original in the game's
  measuring order; then it counts instead of the original, as if the original had been given that slot or material. That
  order puts visible pieces first, then the more important slot (blade, guard, grip, pommel), and only then, between
  hidden pieces of one size and height, iron before steel. The lead's wording named only that last step; measured, it
  gave the wrong answer for a copy moved to another slot and repainted (an iron copy of a hidden steel piece in a less
  important slot changes nothing, though iron comes first; a steel copy of a hidden iron piece in the blade counts
  instead of it, 2.1 grams on the first reviewer's box: the fixer's `rankslot`), so the sentence names the whole order.
  Of a visible piece and its copy, the one whose slot's name comes first in the alphabet stays visible, so a guard
  piece's copy relabelled grip takes the guard piece's place, and in one slot iron before steel. Also corrected: the
  summaries now say only what was measured (none of the copies the reviewers made in their original's slot and material
  changes anything); of the 22,243 copies measured, 615 are on 105 sample swords that are invalid even without the copy
  (the second reviewer's `ctrlvalid`); and the notes now say the Studio check passed on round 5's code (3 Play
  sessions), which rounds 6 and 7 leave as it was. Nothing in the game or its tests changed.
- **Rounds 8 to 10** (2026-11-19): only words, which I applied from what the reviewers had tried and checked in their
  copies. Their checks confirmed the one-sentence copy rule on every case measured (717, then 210 more), and found a few
  sentences that still said more than was measured: four summaries that did not say whether the piece copied is visible
  or hidden (between a visible piece and its copy the slot's name decides, for a hidden piece the slot's importance); a
  rounding bound that one test build exceeds by a hair; an almost-copy of a visible piece said to change nothing, when
  it keeps a sliver of its own weight and can change how finely hidden pieces are measured (2.6 grams of 1,289 on the
  first reviewer's sealed box), though never a visible piece or the difficulty; and a sentence about a piece wrapped in
  a slightly larger one, true only when the wrapped piece is visible. Nothing in the game, its tests or the files the
  Studio check reads changed.
- **What it means for players**: a sword moved whole up, down, forward or back now plays the same. On all 136 test
  swords, 3,200 generated swords and 33,389 sample swords, each moved 15 ways up, down, forward or back (twice of them
  at random), no difficulty or tier changed; which parts count, and with it the joint count, changed only on the three
  test swords built with stacked, almost identical blade copies (X01, X01raw, X02), as at M3 and with the same
  difficulty (the 8 sideways moves measured with them are O12's, below). It costs no measurable time. Only a position
  typed to a billionth of a stud can still land exactly on one of the new boundaries; the SPEC names those cases under
  O11 (j).
- **What moved on swords that are not moved**: some old readings had themselves been decided by rounding. On the test
  swords, no difficulty or tier moved: only the ornate rapier C04's overlap volume (now closer to the exact value) and
  the joint count of 11 test swords (joints do not count for difficulty in the MVP yet). On the sample swords,
  difficulty moved on 9,748 (9,713 after round 2) by at most 0.037, and 29 change tier, 25 of them fullers already
  within 0.0016 of the Normal/Hard line. The new overlap rule is the more accurate one: against exact volumes it is
  closer on 9,947 of the 10,359 sample swords where the two choices differ, with 12 times less total error. Round 2
  changed two test swords a little, with no difficulty change: X02, a blade with six almost identical copies of it, now
  keeps its middle copy too, and on C11 a row of six touching guard cubes shares its overlaps differently. On the sample
  swords, 43 moved by at most 0.017 against round 1, none a tier, 35 of them back to their reading from before the fix;
  the 29 tier changes counted from before the fix are the same swords. Round 3 put X02 back as it was at M3 (five of its
  six copies hidden); C11 keeps round 2's change, and nothing else moved against round 2. Rounds 4 to 10 moved nothing
  at all on any test, generated or sample sword.
- **What remains of moves**: two rare cases already named still move when a sword is moved, as before (a face typed
  exactly 1e-10 stud from a probe line, O11 (h); a part flush with the face of a slanted hidden gap, O11 (k)). An
  invalid sword with no counted grip part measures its reach from the build box's origin. A position typed to a
  billionth of a stud can sit exactly on one of the new boundaries, as at any threshold (two twin teeth a sixteenth
  digit apart, the whole sword moved by a typed 0.2000000005 stud: Hammering 0.2167 → 0.2117). And almost identical
  copies of a part, a part and a copy of it nudged a hair, can still swap which one counts when the whole sword is moved
  so that the point halfway between them crosses the centre line or the front plane, exactly as at M3 (a decision to
  confirm, next). This is stated under O11 (j), which is otherwise closed.

### O11 (j): almost identical copies slid across the centre (what is left)

- **The idea in plain words**: when two parts are the same size, in the same slot and at the same height, the
  hidden-part check orders them by their distance from the build box's centre planes, as M3 did. Two such parts that
  almost coincide (a part copied and nudged a hair) share faces, and the one that comes first keeps them, so the other
  is usually hidden. Sliding the whole sword so that the point halfway between the two copies crosses a centre plane
  swaps which comes first, and so which copy counts. Nobody can see this on a forged sword, which is drawn from its own
  outline; in the editor the slide shows against the centre plane.
- **How much**: as built, no test, generated or sample sword has such a pair, except three test swords built with
  stacked blade copies (X01, X01raw, X02), whose copies swap with the same difficulty. To measure it, the reviewers'
  trick was applied to every 25th sample sword (a part copied 0.001 or 0.005 stud sideways or front to back, where the
  game keeps one of the two: 7,288 cases on 1,091 swords). Slid 0.037 stud backwards, which copy counts changes in 482
  cases and difficulty in 359, by up to 0.51, and 83 swords play another tier; slid sideways (the symmetry reading held,
  O12 aside), difficulty moves in up to 1,103 cases, by up to 0.46, and the tier label changes on 24 swords. M3 itself
  swapped exactly the same cases and moved difficulty in more of them, though not always on the same cases (on one
  sample sword slid back 0.037 stud the fix plays Sharpening Normal where M3 played Hard). On the test swords, C09 with
  a bevel copied 0.001 stud front to back plays Sharpening Hard, and Normal once slid back.
- **The question**: keep ordering such parts by their distance from the centre planes, or use another rule?
- **The options**, each tried in the fix's rounds: (i) the centre planes, as built and as at M3: no hidden part can
  choose the copy and a mirror image keeps it, but sliding the whole sword can; (ii) the sword's grip point (round 1): a
  hidden speck in the grip chose the copy (a test sword's Hammering Hard → Normal); (iii) the middle of the sword's
  outline: a hidden part poking out a hair moved it; (iv) the middle of the group of matching parts (round 2): a hidden
  copy chose (71 sample swords changed tier) and a mirror image swapped the copies; (v) the position alone, left before
  right: a mirror image reverses the order.
- **Lead's recommendation**: keep the centre planes (i). A whole-sword slide cannot be seen on a forged sword, while
  every other rule tried lets a hidden part or a mirror image change difficulty. Revisit if players build such copies.

### O12: a sword moved sideways (new)

- **The idea in plain words**: left/right symmetry (Asymmetry) is measured about the build box's centre line, and the
  edge's measuring grid is lined up on that line too. So a sword slid sideways, as a whole, reads as lopsided, although
  it is the same sword. In the game nobody can see this: a forged sword is drawn from its own outline. In the editor it
  shows, against the centre line, and "Centre on axis" puts it back.
- **How much**: on 11,000 sample swords slid sideways: by 0.0001 stud, 23 % change difficulty a little (none by more
  than 0.002); by 0.002 stud, 47 %; by 0.05 stud (the symmetry check's full tolerance), all of them change and 44 %
  play a harder tier, the Starter Sword among them (Hammering 0.10 → 0.23, Sharpening 0.10 → 0.30, both Hard); slid
  further, a sword reads fully lopsided (+0.30 at most). The edge's chains can also break or join: one of the
  slowest test swords goes from Sharpening 0.52 to 0.76 when slid 0.0013 stud. A lopsided sword can go the other way: a
  cleaver slid 0.16 stud plays Sharpening Normal instead of Hard.
- **The question**: keep measuring symmetry about the centre line, or measure it about the sword itself?
- **The options**:
  - (i) Keep the centre line (default, as built): what the editor shows is what is measured, and nothing on the sword
    can move the line; but sliding a sword is an invisible way to make it harder (or a cleaver easier).
  - (ii) Measure about the grip's centre: sliding changes nothing, but the grip's own build decides where the centre is,
    so a hilt built off to one side makes a straight blade read lopsided (A27: Sharpening Normal → Hard). On the sample
    swords it changes difficulty on 93 (no tier), since nearly all have their grip on the centre line; on the test
    swords on 20 (2 tiers).
  - (iii) Centre every sword automatically before measuring, as "Centre on axis" does: sliding changes nothing, but
    every sword whose outline is not symmetric about its own middle reads differently, the cleavers most (F4 and C05:
    Sharpening Hard → Normal). On the sample swords it changes difficulty on 24 % and the tier on 5,076, every one built
    on a cleaver; on the test swords 4 tiers. Done to the saved sword it would no longer be what the player built; done
    to a copy, the editor's centre line would no longer show where symmetry is measured.
- **Lead's recommendation**: change to (ii), measuring about the grip's centre. The default is (i), as built and as the
  SPEC you approved has it, and the game keeps it until you decide. One arrow-key press (0.05 stud at the editor's
  default step) changes the Starter Sword's tier while the forged sword looks the same, and (ii) changed no sample
  sword's tier; its price is that a hilt built off to one side makes a straight blade read lopsided (A27).

### O11 (l): a mirror image (new class)

- **The idea in plain words**: a sword and its mirror image (the editor's mirror across the centre line or the front
  plane) are equally fair designs and should play the same. Mostly they do, but two rules read them differently.
  Thinness walks each part's sample points in a fixed world direction (up, then right, then forward), the same in a
  sword and in its mirror, so the mirror's walk starts from the other end, and it walks the parts in the measure's
  order, where twin parts on either side of their group's middle swap places in the mirror: either way it picks other
  probe points. And a limited sampling budget is spent part by part in that order, so it runs out in other places.
- **How much**: Parity's generated sword Gen 57 plays Hammering Hard (0.2589), its left/right mirror Normal (0.1095),
  from its tip alone. Of the 33,389 sample swords, difficulty moves by up to 0.08 mirrored left/right and 0.12 mirrored
  front/back, and 22 and 25 play another tier, each within 0.033 of the Normal/Hard line; the test swords keep their
  tiers.
- **Ways out, described, not built**: walk each part's points from the grip's point (tried on a test copy, it fixes only
  about 8 % of the left/right differences and almost none of the front/back ones, because most differing points sit in
  parts on the centre line, like Gen 57's tip, or are picked by the order the parts are walked in); what does close it
  is choosing the probe points as a mirror keeps them (each part's points counted from its own samples and taken in
  mirrored pairs; taking every sample point makes a sword and its mirror agree, at up to 30 times the work). And spend
  the sampling budget the same way on twin parts, or give it room enough (with no limit, a laminate blade and its mirror
  read the same).
- **Lead's recommendation**: state the class and accept it for the MVP, as O11's other classes are: the swords that
  change tier sit within 0.033 of the Normal/Hard line, and the ways out touch the factors' sampling, a study for later.
