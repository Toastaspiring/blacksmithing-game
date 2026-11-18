# M3 build plan, revision 2: Difficulty (SPEC §18, "M3 Difficulty")

Written 2026-11-14 on the M2 snapshot `m2x-r4-base` (M2 as the round-4 verifiers saw it: branch `mvp`, spec 0935f8c,
M0 55fd2ec and M1 4c7e9e7 committed, M2 uncommitted). It replaces `plan.md` for the builders, who need nothing else from
`plan.md` or `critique.md`. Those two stay as the history of the first plan.

Since `plan.md` was written, M2 replaced the sampled Enclosed verdict with an exact reading on a polyhedral model
(`Physics/Cover`, §4.4, E-S2.12). It gave the verdict and the measure each a rank of its own (`Sampling.ranked`,
`Sampling.measureRanked`), capped the verdicts' work (`VERDICT_WORK_MAX`, the code `TooComplex`), replaced `worst_P.json`
with `docs/spec/prototypes/S2/cover/worst_designs.luau`, and left an emulator of M3 on the build
(`docs/spec/prototypes/S2/verdict/analyze_build.luau`). Every number below was measured again on the snapshot through
that emulator, with the method given beside it ([15] lists them all). A number carried over from `plan.md` without a new
measurement is marked **unchecked**.

The M2 fix round under way while this was written changes how flat faces read against a Ball, units and text, and no
M3 interface. Re-run [15]'s scripts on the merged tree before blessing anything ([11], "Before builder 1").

**References.**

- `§` always means SPEC.md. A number in square brackets, such as [7.6], is a section of this plan.
- A SPEC reference gives a section and a short quoted anchor; the index below holds one anchor for every section the plan
  cites, and the text quotes more where it leans on a sentence.
- A line number appears only as "near line N of the snapshot": SPEC.md moves, so search for the anchor.
- Code references give the file and, where useful, "near line N" of the snapshot's copy.

| SPEC section | Anchor (quoted) | Near line |
|---|---|---|
| §0.3 How to review | "**[Decision to confirm]** marks carry their Q number (§0.4) or O number (§17.1)" | 64 |
| §0.4 Decisions to confirm | Q7: "a plain iron arming sword (calibration sword C02, 6 parts) plays Normal on all three steps" | 70–98 |
| §1.2 Module map | "Physics/      Shapes Gjk Cover Sampling MassProps Edge Factors Difficulty Analyze [S2]" | 170 |
| §1.3 Layering and requires | "Inside Physics: Shapes → Gjk, Cover → Sampling → MassProps → Analyze"; L3 "relative string requires (`./X`, `../Dir/X`)" | 197, 200 |
| §1.6 Server execution: AnalysisQueue | "for at most `ANALYSIS_SLICE_MS` 4 per Heartbeat" | 277 |
| §4.1 Overview, modules and determinism | "sums in part order, then sample order"; "handing the prototype the parts in the measure's rank order (`Sampling.measureRanked`)" | 832, 839 |
| §4.4 Exposure and cleaning | "in the measure's rank order (`Sampling.measureRanked`, which also settles who keeps a face two kept parts share)"; "in one whose name comes first it takes over" | 1002, 920 |
| §4.5 Mass properties | "**Difficulty frame** = point of the kept Grip parts, axis fixed at blueprint +Y" | 1033 |
| §4.6 Sharpenable edge | "The F5 starter's main chain is 5.433 (one chain)"; "the main chain of a symmetric blade starts at the +X base" | 1057, 1053 |
| §4.7 Analysis types | "-- nil while invalid; TooComplex: cleaned {}"; "`steps` follows CraftPlans order and holds enabled steps only" | 1087, 1095 |
| §4.9 Execution model and cost | "once `CHECK_UNITS = 500` work units have been reported"; "With M3's share emulated (E-S2.11), fixtures and specks stay under 33 ms Lune"; "S8's T-PERF-01 bounds every gap by `CHECKPOINT_GAP_LUNE_MS` 0.35"; "Ceiling ≤ 75 ms Studio on real designs" | 1126, 1151, 1160, 1163 |
| §5 Difficulty (lead) | "Hidden filler, specks, invisible construction choices and the material cannot move a tier" | 1176 |
| §5.1 Structure | "q(x) = Util/Quantize.q(x, 1e4), applied at production, before any threshold" | 1192 |
| §5.2 Factors | "every k-th volume sample of W (part order, then sample order)"; "owner's thinnest local axis" | 1214, 1218 |
| §5.3 Weights, reference ranges and the material term | "Sharpening \| {Blade} \| EdgeLength 0.50, Asymmetry 0.30, SurfaceComplexity 0.20" | 1251 |
| §5.4 Tier mapping | "the tier boundary is exact (0.1999 Normal, 0.2000 Hard)" | 1279 |
| §5.5 Calibration and fixture tiers | "d per step (Smelting / Hammering / Sharpening)"; C09's row "0.0001 \| 0.3170 \| 0.1904" | 1289, 1304 |
| §5.6 Anti-gaming (measured) | "4 flush plates in F5 / C02 / C05 \|ΔD\| 0.0000"; "C10/C11 = C01 + 20 filler parts"; "X01/X02 vs the union-equivalent blade ΔD ≤ 0.0010 (0.0002 / 0.0006)"; "comb blade: 11 chains, EdgeLength 1.678" | 1319, 1320, 1321, 1326 |
| §11.13 Live preview | "runs `Pipeline.analyze(core, {checkpoint = slice})`" | 2898 |
| §14.1 Layers and gates | "L1 Unit/property … all pass, ≤ 30 s"; "L3 Statistical … ≤ 10 min" | 3495, 3497 |
| §14.2 Layout and the test project | "`.digest.txt` ≤ 1 KB for Studio" | 3507 |
| §14.5 Generic properties | "P-NOMUT inputs unchanged" | 3564 |
| §14.6 Module test plans | "T-EDG-01, T-DIF-01…13"; "**T-DIF-03** D = 0.1999999999 is Normal, 0.2 Hard"; "**T-DIF-07** Y/Z translation and flush re-segmentation give"; "**T-DIF-10** client analysis path = server path, 500 designs" | 3574, 3591, 3593, 3595 |
| §14.7 Fixtures | "every part ≥ 0.02 stud inside the hitbox"; "the cost fixtures X08 (S8, E-S8.4) and P1–P5" | 3607 |
| §14.9 Goldens and the BALANCE guard | "Goldens are `Dump.canonical` text per version (`<name>.bv<N>.golden.txt`)" | 3637 |
| §14.10 Studio integration (L4) | "S-PAR-01 shapes · 02 Server = Client = Lune digest"; "three fresh sessions, all green" | 3673, 3668 |
| §14.11 Performance | T-PERF-01: "every checkpoint gap ≤ CHECKPOINT_GAP_LUNE_MS"; "P1 and the worst valid designs also reported against 29 ms (75 ms ÷ 2.6)" | 3684 |
| §16.2, §16.4–§16.7, §16.11, §16.17 | the rows of `CONTACT_TOL`, Materials, EquipmentTypes ("refs Thinness \| σ 45–130"), Steps, Tiers, "CraftPlans.Sword \| Smelting 0.25 \"All\"", "`SCALAR_SCALE` \| 10000" | 3839, 3866, 3887, 3893, 3904, 4007, 4187 |
| §16.10 `Definitions/Balance` | "`THICK_BUDGET` \| 400"; "`VERDICT_WORK_MAX` \| 700000"; "`EDGE_CELL`, `RASTER_TOL` \| 0.02, 0.005" | 3963, 3945, 3950 |
| §16.18 `Physics/Analyze` | "`CHECK_UNITS` \| 500"; "numeric guards, in `Physics/*`" | 4193, 4198 |
| §16.32 `tests/lib/Tol` | "ANALYSIS_LUNE_MAX_MS \| 60"; "CHECKPOINT_GAP_LUNE_MS \| 0.35" | 4371, 4372 |
| §17.1 Product questions | O7 "The verdicts' cap"; O8 "A part's slot label moves the Sharpening work set" | 4415, 4416 |
| §17.2 Engineering items | "Checkpoint gaps" 4424; "What hidden parts can still reach" 4426; "What ids and order still reach" 4429; "**[Decision to confirm]** (§17.1 O8) A label moves Sharpening's tier" 4430; "The measure keeps its rank" 4431; "What the 2 % rule itself admits" 4432; "Design question for M3" 4433; "Overlap budget" 4434; "The cost of the verdict" 4435; S8 "confirm bit-identical factor digests" 4451 | 4424–4451 |
| §18 Implementation milestones | "Every milestone ends with `scripts/verify` green"; the "M3 Difficulty" row | 4485, 4493 |

| SPEC-evidence | Anchor (quoted) | Near line |
|---|---|---|
| E-S2.2 | "Real edits: arming blade +0.15 / +0.20 / +0.25 → Sharpening 0.1889 / **0.2056** / 0.2314" | 208 |
| E-S2.5 | "X04 … EdgeLength 5.4330 in every case (0.00 %), one chain" | 228 |
| E-S2.9 | "#### Factors on work set All (Smelting, Hammering) (raw / x)" | 310 |
| E-S2.10 | "F5 blade re-cut flush into 2, 3 and 7 pieces \| Δx ≤ 0.00001, ΔG 0" | 393 |
| E-S2.11 | "**Cost.** Median of 21, M2 + M3 = total ms Lune" | 528 |
| E-S2.12 | "**What the 2 % rule itself admits**" | 644 |
| E-S8.4 | X08: "24 rotated cylinders; 24 hitbox-sized blocks; sawtooth blade; 256-point zigzag edge" | 2217 |
| E-S8.5 | "**T-DIF** 01 P-RANGE, caps … 10–13 as §14.6" | 2240 |
| E-S8.6 | "02 digest of `Pipeline.analyze` (fixtures + 200 `Gen.validSword`) … = `parity.bv<N>.digest`" | 2307 |
| E-S8.8 | "Slice and checkpoint arithmetic" | 2333 |

**Companion scripts** (`.build-notes\m3-plan\proto-r2\`). Copy them into one folder named `proto` placed beside a copy
of the tree to measure, named `repo`. The emulator `require`s `../repo/src/shared/Physics/*`. Then run, from inside
`repo`, `lune run <abs>/proto/<script>.luau -- <args>`. `out/` holds each script's output on the snapshot.

| File | What it does | Output |
|---|---|---|
| `analyze_build.luau` | M2's emulator of M3, a copy of `docs/spec/prototypes/S2/verdict/analyze_build.luau`. With `build = true` it takes the kept row, `exposedKept`, contact rows and ownership from the build. It then runs the S2/v2 prototype's edge and factors on them, walking the parts in the order it is handed | — |
| `analyze_gap.luau` | the emulator plus one hook, `opts.mark()`, called where M3's phases start (edge, then factors), for timing M3's stretches between checkpoints | — |
| `analyze, fixtures, shapes, gjk, overlap, num, quat, mirror .luau` | copies of `docs/spec/prototypes/S2/v2/`, which the emulator requires | — |
| `lib.luau` | what the runners share: every prototype fixture with a short id; `inRankOrder` (the measure's rank, `Sampling.measureRanked`, as `Reference.spec`'s `inRankOrder` builds it); `inVerdictOrder`; `shuffled` | — |
| `tab.luau` | every fixture in its part order and in the measure's rank order: d per step, tiers, EdgeLength, cutIndex, the cleaned ids, which factor raws move with the order | `tab.txt` |
| `es29.luau -- part\|rank` | E-S2.9's four tables in E-S2.9's own format (physics from the snapshot's `Analyze.run`; edge, factors and steps from the emulator), for a diff against SPEC-evidence | `es29_*.txt` |
| `orders.luau -- n ids…` | n random permutations per fixture: d ranges walking part order, distinct outcomes walking rank order | `orders.txt` |
| `vrank.luau` | the verdict's rank against the measure's as the walking order | `vrank.txt` |
| `gorder.luau` | g summed in `Definitions/Steps`' order with `Util/Quantize`, against the emulator's g | `gorder.txt` |
| `contracts.luau -- sweep\|dif04\|edge\|caps` | T-DIF-06's edits, T-DIF-04's cases, T-EDG-01's items, T-DIF-01's caps | `contracts.txt` |
| `t13.luau` | T-DIF-13's relations (X01–X07, A25–A27, C10/C11 against C01) | `t13.txt` |
| `gen.luau -- cuts\|seg N\|mirror N` | T-DIF-07 (E-S2.10's cuts; `Gen.segmented` and `Gen.translated` on N designs) and T-DIF-08's mirror images | `cuts.txt`, `seg300.txt`, `mirror150.txt` |
| `sandwich.luau`, `sealed.luau` | §17.2's sandwiched core; the sealed cavity, flush layers and sheets | `sandwich.txt`, `sealed.txt` |
| `perf.luau -- rounds` | T-PERF-01's cases: the snapshot's `Analyze.run` plus M3's emulated share, medians, longest gaps | `perf15.txt` |
| `vshare.luau` (+ `SamplingV.luau.txt`) | the verdict alone, the whole exposure and `Analyze.run`. Put `SamplingV.luau.txt` in the copy's `src/shared/Physics/` as `SamplingV.luau` for the run, then delete it | `vshare.txt` |
| `m3gap.luau`, `checks.luau` | which loop ends M3's longest stretches; how many checkpoints M3 adds | `m3gap.txt`, `checks.txt` |
| `dump_fixtures.luau` | every prototype fixture as `Build.part` rows with this machine's bits, with its smallest side, hitbox margin, verdict and d | `fixtures_literals.txt` |
| `p1bits.luau` | `PhysicsHelpers`' `H.p1()` and `H.ornate()` against the prototype's P1 and C09 | `p1bits.txt` |
| `translate.luau`, `ztrans.luau` | T-DIF-07(a) and T-EDG-01 item 6 on the fixtures: E-S2.10's 6 offsets; the Z offsets' chains to the bit | `translate.txt`, `ztrans.txt` |
| `filler.luau -- N` | T-DIF-04 on N `Gen.withFiller` designs per kind, and T-DIF-05's material swap | `filler.txt` |
| `specks.luau`, `o8.luau` | P1–P3 + a speck (floating, attached): validation, cleaned list, d; §17.1 O8's relabelling | `specks.txt`, `o8.txt` |

`quick.txt` and `full.txt` hold the snapshot's own suite times (`lune run tests/run -- --quick`, `lune run tests/run`).

---

## 0. What M3 delivers

§18's M3 row (near line 4493): "`Physics/{Edge, Factors, Difficulty, Analyze}`; fixtures C01, C02, C04–C15, A25–A27,
X01–X08, P1–P5 (S2, S8) | T-EDG, T-DIF; S2's §5 table blessed for every fixture (from `Analyze.run`); T-PERF-01; first
S-PAR-02 digest of `Analyze.run`". Then §18's rule (near line 4485): "Every milestone ends with `scripts/verify` green
(L0–L2 …) and its Studio scenarios passing in 3 fresh Play sessions (§14.10)".

The §17.2 rows that name M3 ([10] resolves each):

- "M3 is to walk its parts in the measure's rank order (`Sampling.measureRanked`), §5.2's probes and budgets included, and
  bless §5.5 on that" ("What ids and order still reach", near line 4429).
- "M3 calibrates on the ranks as they are" ("The measure keeps its rank", near line 4431).
- "M3 and the designer: whether the rule should look through a sealed cavity or a stack of layers" ("What the 2 % rule
  itself admits", near line 4432).
- "Design question for M3: where a core sandwiched between cheeks crosses 2 % … M3 decides how a cleaned part affects
  Thinness' chords" (near line 4433).

No builder commits. The project commits once per milestone, after independent verification ("M3: difficulty …", with
the attribution line from the session's reminder).

---

## 1. Decisions

No designer is available. Where the SPEC needs a designer's call, the default below is what M3 builds, marked
**[Decision to confirm]** with its §17.1 O-number, as §0.3 asks ("**[Decision to confirm]** marks carry their Q number (§0.4)
or O number (§17.1)", near line 64). §17.1 holds O1–O8 on the snapshot. The M2 fix round under way adds O9, the round-part
band (project notes), so M3's two new rows are written O10 and O11 here. Builder 4 takes the next free numbers when it
edits §17.1 and renumbers the marks to match.

| # | Question | Default (what M3 builds) | Evidence (measured on the snapshot unless marked) | Designer call |
|---|---|---|---|---|
| D1 | The 2 % rule's own limits in D: a core sandwiched between cheeks that crosses 2 % (§17.2, near line 4433), a filler in a sealed cavity, flush layers through the thickness, sheets over a core (§17.2, near line 4432; §5.6's last row) | **Option 0.** Cleaned parts are inert in every factor. A cleaned part is in no work set, so Thinness' union chord through it stays open, and the chords merge gaps ≤ `CONTACT_TOL` as §5.2 says. Document the class with [7.8]'s numbers | Option 0 on the 9 sandwiches (core kept against the same design hollow): 6 tier flips on 4 designs, largest \|ΔD\| 0.3235 (LAM1). In LAM1, SurfaceComplexity carries +0.2876 of Hammering's +0.3235 and all of Sharpening's +0.2000. Thinness carries +0.0359 and Volume moves Smelting −0.0520. The rule's other limits are larger and no M3 rule reaches them: a sealed cavity's filler shows 100 % (Smelting 0.1376 → 0.4463); flush layers (Hammering 0.0582 → 0.7000) sit 0.12 apart, past any gap rule; sheets over a core (\|ΔD\| 0.3639). Option B ("void faces hidden") would now be an edit to M2's measure in `Sampling.exposure`. Its old numbers came from the prototype's verdict and are **unchecked** (on the 9 sandwiches it flipped 5 tiers to option 0's 6, up to +23 % cost). A verdict-side rule is the only complete fix, and it belongs to the verdict's owner | **[Decision to confirm]** (§17.1 O10, new) |
| D2 | T-DIF-07(b), flush re-segmentation: §14.6's "\|Δx_f\| ≤ TOL_FACTOR_ABS, \|ΔG\| ≤ TOL_G_INVARIANT" on general designs (`Gen.segmented`) | **(i)** Keep §5.2's stride, walked in the measure's rank order. Assert (b) on E-S2.10's F5 cuts (2, 3 and 7 pieces) and C12 against C02. On `Gen.segmented`, assert Volume and EdgeLength and report Thinness, Asymmetry, SurfaceComplexity and G. Record the sensitivity in §5.6 and §17.2. (ii), a redesign of θ, the probe grid and Asymmetry's grid, is a separate study | E-S2.10's cuts and C12 against C02: \|Δx\| ≤ 7.2e-16, \|ΔG\| 0, with the stride and with FINE (every owned sample a probe). On 300 `Gen.segmented` designs (TestRng 0x5EED0007, the critique's stream), with the stride: Thinness 0.0591 (#51), Asymmetry 0.0197 (#152), SurfaceComplexity 0.0056, G 0.0236 (#51), 0 tier flips. Volume and EdgeLength 0.0000. FINE still moves G 0.0191 (#51), so the stride is not the main cause: θ (the owner's thinnest local axis) moves when a cut piece comes out shorter than the part is thin, and Asymmetry's grid moves with the part count | **[Decision to confirm]** (§17.1 O11, new): §5's "invisible construction choices … cannot move a tier" holds on general designs only to within about 0.024 of D |
| D3 | `CHECK_UNITS` 500 or 250 | **500**, as §17.2 now says ("`CHECK_UNITS` stays 500", near line 4424). M3 charges its loops finely enough ([3.2], [3.3]) | Quiet machine, median of 15: M2's longest stretch ≤ 0.261 ms on every T-PERF-01 case. M3's share, with the prototype's own charges, ≤ 0.317 ms (worst valid design 8). The longest end at the raster's per-cell charge ([9.4]) | not a designer call (S2/S8, settled by M2) |
| D4 | T-EDG-01, T-DIF-12, T-DIF-13 and X08 are named and nowhere defined (§14.6 near line 3574, "T-EDG-01, T-DIF-01…13"; E-S8.5 "10–13 as §14.6"; E-S8.4's X08 row) | Definitions in [8]. X08 = aliases of P2 (24 rotated cylinders), P1 (the first P1 was "24 overlapping hitbox-sized blocks") and P5 (sawtooth comb). The 256-point zigzag edge is an `EdgeChain` for M4's T-PERF-02, not a blueprint | the SPEC text as of the snapshot | not a designer call (S8, S2) |
| D5 | `measureInvalid` with an empty work set (§4.7, "nil while invalid; TooComplex: cleaned {}") | The quick-stage stop and the `TooComplex` stop stay as they are. Otherwise, with `measureInvalid`, edge and steps are measured. `steps = nil` only when an enabled step's work set is empty. Write this into §4.7's comment | `Analyze.run`'s stops near lines 367–418 of the snapshot | not a designer call |
| D6 | The digest golden's name; P4's margin against §14.7's 0.02 | `tests/golden/parity.bv1.digest.txt` through a new `Golden.digest` (E-S8.6: "= `parity.bv<N>.digest`"). Keep P4 bit-identical to the prototype and exempt it from the margin check, with a note | P4's margin measures 0.010000000000000009 (`fixtures_literals.txt`) | not a designer call |
| D7 | O7's figures once M3 is in: §17.1 O7 asks whether "about 94 for `Analyze.run`" in Studio is acceptable for the slowest valid designs under the cap. That figure is M2's phases alone | Accept. T-PERF-01 asserts ≤ `ANALYSIS_LUNE_MAX_MS` 60 and S-PERF-01 reports. Builder 4 updates O7, §4.9, §16.10 and §16.32 with the measured totals | M2 + M3 emulated, median of 15, quiet: the slowest valid design 48.99 ms Lune (worst valid 8, `tclimb_3.json #6`), ≈ 127 ms Studio at 2.6×, 11 ms under 60 ([9]) | **[Decision to confirm]** (§17.1 O7) |
| — | O8: the label of what shows counts (§17.1 O8; §17.2 near line 4430) | M3 builds Sharpening's work set from the label (`WorkSet.select(…, {"Blade"})`), as the SPEC says. T-DIF-09 asserts the current behaviour | unchanged from the SPEC | **[Decision to confirm]** (§17.1 O8), unchanged |

**Why D1 and D2 keep their defaults.** Every measurement behind them came out the same on the snapshot as on the first
plan's prototype. Option 0's sweep reproduces flip for flip. `Gen.segmented` fails under every probe rule, at the same
designs and to the same digits. E-S2.10's cuts pass exactly. Nothing measured here favours option B or a redesign.

**Fingerprint.** Under D1–D7 no Balance data changes, so `balance_fingerprint.golden.txt` is not re-blessed. M3 adds
code, fixtures, goldens and test constants (`tests/lib/Tol`), none of which is in the Manifest.

---

## 2. What M3 plugs into (checked on the snapshot)

### 2.1 `Physics/Analyze.luau` (464 lines)

- **Header.** Steps 1–6 near lines 10–19. Step 6 reads "EDGE, FACTORS, STEPS arrive with M3 … Until then edge and steps
  are nil and those three numbers 0".
- **Constants.** `local CHECK_UNITS = 500` near line 116, exported as `Analyze.CHECK_UNITS` near line 322;
  `UNITS_PER_CONTACT_TEST` 20 and `UNITS_PER_DISTANCE` 40.
- **Types, near lines 46–109.** M3's types are already declared here: `Vec2`, `EdgeChain`, `EdgeProfile`, `FactorValue`
  and `StepAnalysis`. M3 moves them down into Edge, Factors and Difficulty, and Analyze re-exports them under the same
  names ([3.1]). `PhysicsReport` already has `edgeLength` and `cutIndex`, and `AnalysisBudget` has `edgeCell`.
- **`run`, phase by phase.**

| Phase | Near line | What it leaves for M3 |
|---|---|---|
| `spend(n)` and `phase()` closures | 342–357 | per run; `spend` checkpoints once `units ≥ CHECK_UNITS` |
| 1 prepare, quick | 362–378 | `parts: {Prepared}` in blueprint order, `rankOf` (slot rank), `typeDef`, `geometry`. Returns early with `edge`, `steps` nil |
| 2 V3, V4 | 380–387 | `graph.touching[i][j]` (within `CONTACT_TOL`), `graph.components`; the physics frame `gripPoint`, `gripAxis` |
| 3 exposure, V5 | 389–419 | `exposure` (`exposedKept`, `contact`, `kept`, `cleaned`, `capped`, `verdictWork`). `capped` returns `TooComplex` with `edge`, `steps` nil; invalid returns unless `measureInvalid` |
| 4 mass properties | 421–442 | `owned` (`ownedVolume`, `higher`), the `physics` table with `edgeLength = 0`, `cutIndex = 0` |
| 5 volume probes | 444–447 | `probes` (`h`, `total`, `byPart`), `budget.hVol`, `budget.volSamples` |
| 6 (M3) | 449–452 (comment), return 453–461 | the plug-in spot: today it returns `edge = nil`, `steps = nil` |

### 2.2 `Physics/Sampling.luau` (838 lines)

- **Exports.**
  - `ladder(base, fits)` near line 133.
  - `volumeSamples(P, h, spend?, minX?, minY?, minZ?)` near line 152: charges `ny·nz` per x slice.
  - `volumeProbes(parts, kept, spend?)` near line 194: kept parts only; `byPart` in blueprint order, empty for cleaned
    parts.
  - `surfaceSamples`.
  - `ranked(parts)` near line 482 and `measureRanked(parts)` near line 539. Each returns `(rank: {number}, order:
    {Prepared})`, with `rank[index]` 1 for the highest.
  - `exposure(parts, spend?)` near line 576.
  - Constants `COS`, `SIN` and `INSIDE_MARGIN` (1e-9).
- **Types.** `Spend`, `VolumeSamples {n, x, y, z, w}`, `VolumeProbes {h, total, byPart}`, `SurfaceSamples`, `CleanReason`,
  `Cleaned`, and `Exposure {hSurf, surfSamples, subSampled, exposedKept, contact, kept, cleaned, capped, verdictWork}`.
  `contact[p][q]` is p's sampled area within `CONTACT_TOL` of q, kept pairs only.
- **The two ranks.**
  - `measureRanked` sorts by the key `{−volume, cy, |cx|, cx, |cz|, cz, hx, hy, hz, ux, uy, uz, vx, vy, vz}`, then slot,
    then material, then index (near line 546). §17.2 says M3 walks in this rank.
  - `ranked`, the verdict's rank, puts the slot's name second, after a Block's volume taken from its sorted half
    extents.
  - On the 64 prototype fixtures the two orders differ on C01, C10, C11, P2, P3 and P4. The emulator's d and factors
    agree to 1e-12 either way (`vrank.txt`), but not to the bit, and the goldens are bits: walk `measureRanked`.

### 2.3 `Physics/MassProps.luau`, `Shapes.luau`, `Cover.luau`, `Gjk.luau`

- **`MassProps.ownership(parts, kept, rankOf, spend?)`** returns `Ownership {ownedVolume, overlapVolume, overlapX/Y/Z,
  higher, hOverlap, refinedCells}`.
  - Its order is kept first, then slot rank, then `measureRanked` (near lines 340–352).
  - `higher[p.index]` lists the parts above p that overlap it, in that order: M3's owned-probe test.
- **The other MassProps functions.** `gripFrame(list)`, `physicsFrame(parts, gripSlot)`, `difficultyFrame(parts, kept,
  gripSlot)` and `report(…)`; types `MassReport`, `Ownership`, `Vec2`.
  - `difficultyFrame` (near line 530) walks the list it is given, with `kept[i]` indexed like that list, and returns
    axis `{0, 1}`.
  - Handed `byRank` and a kept array in the same order, it sums the kept Grip parts in rank order. No MassProps edit is
    needed.
- **`Shapes`.** `chord(P, ox, oy, oz, ux, uy, uz, dilate?) → (hit, t0, t1)` near line 319; `extentAlong(P, ax, ay, az) →
  (lo, hi)` near line 438; `sd`, `sdLocal`, `aabbContains`, `aabbOverlap`, `maxDist`, `support`, `toWorld`, `toLocal`,
  `prepare`, `sameSolid`, `planes`, `faces`. Constants `PI`, `BLOCK`, `WEDGE`, `CORNER`, `CYLINDER`, `BALL`.
  - `Prepared` (near lines 79–104) carries `index`, `id`, `code`, `slot`, `material`, the centre, the basis `u`, `v`,
    `w`, the half extents, `r`, `volume`, `area`, the local and world centroids, the exact AABB, `poly`, `lverts`,
    `wverts` and `faceIdx`.
  - `Shapes.chord` and `Sampling.volumeSamples` are the prototype's own: `Reference.spec` pins every surface sample, and
    the emulator's numbers below come from them.
- **`Cover`** (`model`, `shown`) and **`Gjk`** (`within`, `distance`). M3 calls neither. Joints' contact graph is
  Analyze's `graph.touching`.

### 2.4 Blueprint, Definitions, Util

- **Blueprint.**
  - `Blueprint/WorkSet.select(parts: {PartData}, kept, selector)` near line 16 returns ascending indices of kept parts
    that match.
  - `Blueprint/Mirror.reflect(part, "X" | "Z")` near line 69.
- **`EquipmentTypes.get("Sword").geometry`.** `strikingSlot` "Blade", `gripSlot` "Grip", `guardSlot` "Guard",
  `thicknessAxis` {0, 0, 1}, and `refs` (8 rows, FactorId order: PC 3–16, Th 45–130, As 0–0.6, SC 2.3–2.9, EL 4.8–8.0,
  Jo 3–24, MM 1–4, Vo 0.08–0.80).
- **Steps, plans, tiers, materials.**
  - `Steps.get(id).factorWeights`, in FactorId order: Smelting Vo 1.00; Hammering Th .40, As .30, SC .30; Sharpening
    As .30, SC .20, EL .50.
  - `CraftPlans.get("Sword").steps`: Smelting "All", Hammering "All", Sharpening {"Blade"}, all three enabled.
  - `Tiers.tierFor` and `tierRawFor` near lines 108 and 112 error on NaN or on D outside [0, 1]. Normal and Hard are
    enabled.
  - `Materials.get(id).difficultyTerm` is 0 on every row; `hardness`, `ordered`.
- **`Util/Quantize.q(x, scale)`** near line 26: errors on non-finite values, folds −0; `SCALAR_SCALE` 10000.
- **`Balance`.**
  - `Balance.Geometry` (near line 51): `H_VOL`, `N_MIN_AXIS`, `N_MAX_AXIS`, `N_MAX_PART`, `H_LADDER`, `EDGE_*` near
    line 76, `CUT_LO`/`CUT_HI` near line 86.
  - `Balance.Difficulty` (near line 107): `V_PART_FULL`, `JOINT_BOOST`, `A_JOINT_REF`, `THICK_BUDGET`, `SIGMA_LO`/`HI`,
    `THIN_SHARE_MIN`, `ASYM_*`.
  - `Limits.CONTACT_TOL` 0.01.
- **`Definitions/Types`.** `FactorId`, `StepId`, `TierId`, `MaterialId`, `GeometryRules`, `StepDef`.

### 2.5 Tests and documents

- **`tests/lib`.**
  - `Dump.canonical` and `Dump.fnv1a32` (near line 190).
  - `Golden.check` and `Golden.read`. `Golden` writes only `<name>.golden.txt`.
  - `Gen.validSword`, `withFiller(rng, ctx, core, kind?)`, `segmented`, `translate`, `translated`, `context`.
  - `TestRng`, `Prop`.
  - `Tol` has no `TOL_EDGE_REL`, `PERF_RUNS` or `PARITY_*` yet.
- **`tests/fixtures`.**
  - `Build` has `I`, `Z45`, `Z90`, `Y90`, `Y45` and `Z180`, and no `YM90`.
  - `Blueprints` (F1–F5) has a `Fixture`/`Expect` type whose `oracle` and `starter` are required.
  - `Adversarial` holds A01–A24 and A28 (`order` near line 1046). A14's relation is `d = "NonIncreasing", gTol =
    "TOL_DUST_G"` (near line 576), and near line 1005 a comment reads "A25–A27 are M3's hidden-grip variants".
- **`tests/Physics/Analyze.spec.luau`.**
  - The M3 placeholders: near line 672, "nil edge and steps until M3", with `edgeLength`, `cutIndex` and `edgeCell` 0 and
    `CHECK_UNITS` 500.
  - P1's budgets near 709; checkpoints near 726.
  - The phases-only count near 744–770: `A.eq(count, 5, …)` with a `modules` map of Analyze's requires.
  - The long loops near 774, with a names list; the F2 bound "checkpoints on F2 < 150" near 813.
  - P-ORDER's planted maps near 885; `worst_designs.luau` (slow) near 944.
- **`tests/Physics/Reference.spec.luau`.**
  - `inRankOrder` uses `Sampling.measureRanked` (near lines 64–75).
  - P1's own verdict is near line 41.
  - SurfaceComplexity is compared against the prototype near lines 179–193.
  - The `flipCase` cases are near lines 240–324, and the `H.ornate` check near line 326.
- **`tests/Physics/PhysicsHelpers.luau`.**
  - `H.measure(core) → (report, exposure, owned)` near line 87.
  - `H.p1()` near line 318 is not the prototype's P1: 43 rotation fields differ in the last bits (`H.axisAngle`
    normalizes; `p1bits.txt`). Pin no M3 number on it.
  - `H.ornate()` near line 332 is C09, bit for bit.
- **`tests/ItemRender/FakeRoblox.luau`.** `Options.server` gives `IsServer`; there is no `IsClient`. It maps `src/shared`,
  `tests/lib` and `tests/fixtures`, not `tests/golden`. `tests/studio/e2e/S-PAR-01.luau` is the snippet style to follow.
- **`docs/spec/prototypes/S2`.**
  - `v2/` holds the reference prototype, unchanged: every line it cites below was re-checked.
  - `verdict/analyze_build.luau` is the emulator.
  - `cover/worst_designs.luau` holds `valid` (11 designs, with `units` and `verdictMs`) and `tooComplex` (17). It
    replaces `verdict/worst_P.json`, which its README calls superseded.
  - `docs/` is not a Rojo root.

---

## 3. Module APIs

### 3.1 Layering and the rules every new module keeps

- **Layering.**
  - §1.2's module map (near line 170) already lists `Physics/ Shapes Gjk Cover Sampling MassProps Edge Factors
    Difficulty Analyze [S2]`.
  - §1.3 L2 (near line 197) reads "Inside Physics: Shapes → Gjk, Cover → Sampling → MassProps → Analyze". M3 inserts
    Edge → Factors → Difficulty before Analyze (builder 4 writes it into L2):
    - `Edge` → Balance, Types, Schema (Vec3), Shapes, Sampling (`Spend`, `ladder`).
    - `Factors` → Balance, Limits (`CONTACT_TOL`), Types, Shapes, Sampling (`VolumeProbes`, `Exposure`, `Spend`,
      `volumeSamples`, `ladder`), MassProps (`Ownership`).
    - `Difficulty` → Types, Steps, Materials, Tiers, CraftPlans, Util/Quantize, Factors (`FactorValue`).
    - `Analyze` adds Edge, Factors, Difficulty, Blueprint/WorkSet and CraftPlans.
- **Types.** Each type lives in the lowest module that produces it, and Analyze re-exports it under the same name, as
  M2 does with `MassProps.MassReport`. That means `export type EdgeProfile = Edge.EdgeProfile` and likewise for
  `EdgeChain`, `FactorValue` and `StepAnalysis`. No Physics module requires Analyze (T-META-07, no cycles).
- **Purity (§1.3 L3, near line 200).** Relative string requires only. Line 1 is `--!strict`. No `game`, `script`, `task`,
  services or Roblox datatypes. No `math.sin…`, no `^`, no `--!native` (T-META-03). No float sum while iterating a
  keyed table (T-META-04): the per-selector factor cache is keyed and never iterated.
- **Determinism (§4.1, "Determinism rules for `Blueprint/`, `Physics/` and `Pipeline`", near line 828).**
  - Arithmetic is `+ − × ÷` and `math.sqrt/floor/ceil/abs/min/max`; `math.round` appears only inside `Util/Quantize`.
  - No `%` or `//`. `Rules.luau` does not check them, but no Physics or Blueprint module uses them (checked), so keep it
    that way.
  - Numeric `for` and `ipairs` over arrays. Sorts use total orders.
  - Every sum runs in the measure's rank order, then sample order.
- **luau-lsp.** Annotate the locals that hold `DT.FactorId`, `DT.StepId`, `DT.TierId` or `DT.MaterialId` values: string
  literals inside tables widen to `string` (M1-notes).

### 3.2 `Physics/Edge.luau` (§4.6; types §4.7)

```lua
--!strict
-- Physics/Edge (SPEC §4.6; owner S2): the blade raster, its outline, the sharpenable chains, cutIndex.
export type Vec2 = { number }                                         -- {x, y}, blueprint XY
export type EdgeChain = { points: { Vec2 }, length: number }
export type EdgeProfile = { chains: { EdgeChain }, length: number, cell: number, bladeArea: number,
	bladeMeanThickness: number, gripPoint: Schema.Vec3, gripAxis: Vec2 }  -- the difficulty frame (§4.5)
export type RasterStats = { cells: number, work: number }              -- the chosen rung's, for T-EDG-01's budgets

Edge.profile(list: { Prepared }, kept: { boolean }, geometry: DT.GeometryRules, gripPoint: Schema.Vec3,
	gripAxis: Vec2, spend: Sampling.Spend?): (EdgeProfile, RasterStats)
	-- list in the order to walk (the measure's rank order), kept indexed like list: MassProps.difficultyFrame's convention
Edge.cutIndex(bladeLength: number, bladeMeanThickness: number): number
	-- clamp((max(bladeLength, 1e-6)/t − CUT_LO)/(CUT_HI − CUT_LO), 0, 1); 0 when t = 0
Edge.simplify(xs: { number }, ys: { number }, tol: number): { number }    -- Douglas–Peucker, the kept indices
Edge.mergedLength(ivs: { number }, n: number, tol: number): number        -- sorts a copy (P-NOMUT, §14.5)
```

- **§4.6's five rows** ("Raster", "Outline", "Eligibility", "Geometry", "Output"; near lines 1039–1055):
  - **Raster.** The cell starts at `EDGE_CELL` and steps up `H_LADDER` (`Sampling.ladder`) until cells ≤ `EDGE_MAX_CELLS`
    and cell × part tests ≤ `EDGE_MAX_WORK`, counting kept parts (the last rung if none fits). x is anchored at 0 and y at
    the lowest kept striking-slot point. A cell is covered when its centre's Z line passes within `RASTER_TOL` of a kept
    striking part (`Shapes.chord` with `dilate`). Thickness is the merged chord length (tolerance `CONTACT_TOL`); `hilt`
    is a dilated chord through a kept non-striking part.
  - **Outline.** Crack edges with the covered cell on the left, traced 8-connected; only outer (CCW) loops count.
  - **Eligibility.** Not buried and thickness ≤ `EDGE_MAX_THICK`. A fully eligible loop opens at its lowest vertex.
  - **Geometry.** Douglas–Peucker at `EDGE_SIMPLIFY` × cell, doubled until ≤ `EDGE_MAX_POINTS`. Pommel-facing segments
    (`n·A < −EDGE_DOWN_COS`) are dropped, gaps < `EDGE_GAP_BRIDGE` cells bridged, chains < `EDGE_MIN_CHAIN` cells dropped.
  - **Output.** Chains sorted by length, ties by the first point's x then y; `length` is the main chain's.
- **No kept striking part** (only reachable with `measureInvalid`) gives `{chains = {}, length = 0, cell = 0, bladeArea
  = 0, bladeMeanThickness = 0}` and the frame.
- **No `%` or `//`** where the prototype has them (`v2/analyze.luau` near lines 559–564, 642, 676, 683, 689, 707–715):
  - store each crack edge's integer endpoints;
  - turn right through `RIGHT = {3, 0, 1, 2}`;
  - advance cyclic indices as `k += 1; if k > m then k -= m end`;
  - compare the lowest vertex on (y, x) rather than `y·1e6 + x`;
  - give chains a total order (length desc, first x, first y, then emission index).
- **Mirror images are not exact, and stay so.** A design's X mirror image has the mirrored raster, but its CCW outline
  runs the other way and Douglas–Peucker keeps the first maximum. On Gen #31 (TestRng 0x5EED0008), EdgeLength is
  6.935592 over 11 points against the image's 6.915188 over 9, a 0.2942 % change, with the raster equal on all 169
  designs tried (`mirror150.txt`). Keep the prototype's rule: T-EDG-01 compares with it bit for bit.
- **Charges, one unit per shape query.**
  - **Per raster cell: `1 + 2·#rowBlade + #rowHilt`**, two chords per blade part in the row (dilated and plain). The
    prototype charged `1 + #rowB + #rowH`, and that per-cell charge ends M3's longest stretches: 0.29–0.30 ms median on
    the worst valid designs (`m3gap.txt`).
  - Per crack row `NI`; per traced edge 1; Douglas–Peucker per split (`b − a` points). The prototype charged `4 · #run`
    once per run (near line 567), an O(n²) loop left uncharged.

### 3.3 `Physics/Factors.luau` (§5.2; refs §5.3)

```lua
export type FactorValue = { factor: DT.FactorId, raw: number, x: number }
export type FactorBudget = { thinStride: number, thinProbes: number, asymSpacing: number, asymWork: number }
export type FactorContext = {
	parts: { Prepared },               -- blueprint order
	rank: { number },                  -- Sampling.measureRanked: rank per part index (1 = highest)
	kept: { boolean },                 -- blueprint order
	probes: Sampling.VolumeProbes,     -- phase 5: byPart[i] at spacing h
	exposure: Sampling.Exposure,       -- exposedKept[i], contact[i][j]
	owned: MassProps.Ownership,        -- ownedVolume[i], higher[i]
	touching: { { boolean } },         -- Analyze's contact graph
	edgeLength: number,                -- EdgeProfile.length, the same on every set
	geometry: DT.GeometryRules,        -- refs, strikingSlot, thicknessAxis
}
Factors.ORDER: { DT.FactorId }         -- FactorId order; a test ties it to Validate's and to refs
Factors.measure(ctx: FactorContext, set: { number }, spend: Sampling.Spend?): ({ FactorValue }, FactorBudget)
	-- set = WorkSet.select(...), ascending indices; measure sorts a copy by ctx.rank before every walk
-- for tests: norm, cbrt, unionChord, thinAxis, thinness, asymmetry
```

| Factor | raw (§5.2, near lines 1202–1240) | x | Reads |
|---|---|---|---|
| PartCount | Σ min(1, V_p/`V_PART_FULL`), V_p = `Prepared.volume` | norm(n, refs) | parts |
| Thinness | (Σw·φ²/Σw·φ)·min(1, Σ_{φ>0}w / (`THIN_SHARE_MIN`·Σ_{W∩striking}w)), with Σ_W w if no striking part | = raw | [3.3.1] |
| Asymmetry | 1 − Σw·c/Σw | norm(raw, 0, 0.6) | [3.3.2] |
| SurfaceComplexity | r = A/(6·cbrt(V)²), A = Σ `exposedKept[p]`, V = Σ `ownedVolume[p]`; 0 if V ≤ 0 | norm(r, 2.3, 2.9) | exposure, owned |
| EdgeLength | `ctx.edgeLength` | norm(E, 4.8, 8.0) | edge |
| Joints | Σ over pairs i < j in rank order with `touching[i][j]`: min(s_i, s_j)·(1 + `JOINT_BOOST`·clamp01(1 − a_ij/`A_JOINT_REF`)), a_ij = (contact[i][j] + contact[j][i])/2, s = min(1, V/`V_PART_FULL`) | norm(J, 3, 24) | touching, contact |
| MaterialMix | distinct materials, counted by walking `Materials.ordered` and testing each against the set array (no keyed set) | norm(k, 1, 4) | parts |
| Volume | Σ `ownedVolume[p]` | norm(V, 0.08, 0.80) | owned |

`lo` and `hi` come from `geometry.refs` in FactorId order. Thinness's σ range is `Balance.Difficulty.SIGMA_LO/HI`, and
`tests/Definitions/EquipmentTypes.spec.luau` near lines 83–87 already asserts the refs row equals it. Every Σ walks the
set in the measure's rank order, and each part's samples in sample order.

#### 3.3.1 Thinness (§5.2, "robust to how the shape is split", near lines 1211–1224)

- **L** is the set's extent along +Y: the min and max of `Shapes.extentAlong(p, 0, 1, 0)`.
- **Probes (§5.2's stride, walked in rank order, §17.2).**
  - Walk the set's parts in rank order, and each part's `ctx.probes.byPart[p.index]` samples in order.
  - n_W = Σ n over the set; k = max(1, ceil(n_W / `THICK_BUDGET`)).
  - A running counter takes samples 1, 1 + k, 1 + 2k, … This is the prototype's `(idx − 1) % stride == 0` (near line
    1391) without `%`. At most ceil(n_W/k) ≤ `THICK_BUDGET` probes, and phase 5's samples keep their consumer.
- **Owned.** A probe counts unless it is strictly inside a part of `owned.higher[p.index]` (`sd < −INSIDE_MARGIN`), as
  the prototype's `ownedAt` (near lines 1210–1224).
- **Round parts.** A Ball probe moves to the ball's centre; a Cylinder probe to its projection on the axis.
- **θ, the owner's thinnest local axis:** Ball X; Cylinder X if hx ≤ r, else local Y; polyhedra the smallest half
  extent, ties X < Y < Z (near lines 1373–1388).
- **τ and φ.** τ = min(unionChord(set, s, Z), unionChord(set, s, θ)), with Z = `geometry.thicknessAxis`. The union chord
  grows from [0, 0] and merges gaps ≤ `CONTACT_TOL`. φ = norm(L/max(τ, 1e-6), `SIGMA_LO`, `SIGMA_HI`).
- **Charges.** `2·#set + #higher` per probe taken, the ownership test counted. The prototype charged `2·#W` and nothing
  for a probe that failed the test.

#### 3.3.2 Asymmetry (§5.2, "left/right about the fixed plane x = 0", near lines 1228–1240; `v2/analyze.luau` near 1424–1502)

- `axisMins(p)` gives `ASYM_N_MIN` on the local axes with |axis·X| ≥ `ASYM_AXIS_X`, else `N_MIN_AXIS`.
- The reach is `ASYM_TOL + ASYM_RAMP`. Mirror candidates are the set's parts whose AABB meets p's mirrored AABB widened by
  the reach. Higher candidates are `owned.higher[p.index]` ∩ set.
- **Spacing.** `Sampling.ladder(H_VOL, …)`: the first spacing with Σ min(a·b·c, `N_MAX_PART`)·(1 + #mc + #hc) ≤
  `ASYM_WORK`.
- **Samples.** `Sampling.volumeSamples(p, hA, spend, mx, my, mz)`.
- **Coverage.** d = min over the mirror candidates of `sd(q, −x, y, z)` for owned samples, stopping once d ≤
  `ASYM_TOL`; c = clamp01((reach − d)/`ASYM_RAMP`).
- **Charges.** `1 + #mc + #hc` per sample.

#### 3.3.3 `cbrt` and `norm`

- `cbrt` is a verbatim port of `v2/num.luau`'s: power-of-8 range reduction by while loops, 8 Newton steps from 1.5, then
  ×2 or ÷2 k times (§4.1, "`cbrt` = power-of-8 range reduction + 8 fixed Newton steps").
- `norm(v, lo, hi)` = clamp((v − lo)/(hi − lo), 0, 1).
- Neither exists in `src/` (checked).

### 3.4 `Physics/Difficulty.luau` (§5.1, §5.3, §5.4)

```lua
export type StepAnalysis = { step: DT.StepId, g: number, m: number, d: number, tierRaw: DT.TierId, tier: DT.TierId,
	material: DT.MaterialId, terms: { { factor: DT.FactorId, w: number, x: number } }, factors: { Factors.FactorValue } }
Difficulty.q(x: number): number                       -- Quantize.q(x, Quantize.SCALAR_SCALE)
Difficulty.softOr(m: number, g: number): number       -- q(1 − (1 − m)(1 − g))
Difficulty.governing(parts: { Prepared }, set: { number }): DT.MaterialId?
	-- the set's material with the highest (difficultyTerm, hardness), ties by Materials order; nil on an empty set
Difficulty.planSteps(typeId: DT.EquipmentTypeId): { CraftPlans.PlanStepDef }   -- enabled, in plan order
Difficulty.step(stepId: DT.StepId, factors: { Factors.FactorValue }, material: DT.MaterialId): StepAnalysis
```

- **g** = q(Σ w·x), with weights from `Steps.get(step).factorWeights`, summed in their stored order, which is FactorId
  order. m = q(difficultyTerm), 0 for every MVP material. d = softOr(m, g).
- **Tiers.** `tierRaw = Tiers.tierRawFor(d)`, `tier = Tiers.tierFor(d)`. `terms` follow the weights' order; `factors`
  are all 8, copied.
- **Measured.** The prototype sums Sharpening as EL, As, SC (`v2/analyze.luau` near line 109). On the 64 fixtures' 192
  steps, the Steps order with `Quantize.q` changes no g and no d (`gorder.txt`).

### 3.5 `Analyze.run`'s phase 6 (§4.1's pipeline; §4.7)

```lua
-- 6 the difficulty frame and EDGE (§4.5, §4.6), every walk in the measure's rank order (§17.2)
local N = #parts
local rank, byRank = Sampling.measureRanked(parts)
local keptByRank: { boolean } = table.create(N, false)
for r = 1, N do
	keptByRank[r] = kept[byRank[r].index]
end
local dPoint, dAxis = MassProps.difficultyFrame(byRank, keptByRank, geometry.gripSlot)
local edge = Edge.profile(byRank, keptByRank, geometry, dPoint, dAxis, spend)
physics.edgeLength = edge.length
physics.cutIndex = Edge.cutIndex(physics.bladeLength, edge.bladeMeanThickness)
budget.edgeCell = edge.cell
phase()
-- 7 FACTORS per distinct work set, STEPS in CraftPlans order (enabled only)
local ctx: Factors.FactorContext = { parts = parts, rank = rank, kept = kept, probes = probes, exposure = exposure,
	owned = owned, touching = graph.touching, edgeLength = edge.length, geometry = geometry }
-- for each enabled plan step: set = WorkSet.select(core.parts, kept, worksOn); an empty set ⇒ steps = nil (D5);
-- key = "All" or table.concat(slots, "+") into a keyed cache that is never iterated; a new set: Factors.measure, phase();
-- then Difficulty.step(step, factors, Difficulty.governing(parts, set))
```

- **The frame.** `MassProps.difficultyFrame(byRank, keptByRank, …)` sums the kept Grip parts in rank order. Physics
  (`MassProps.report`, `physicsFrame`) keeps M2's blueprint-order sums.
- **Measured.** In rank order, every factor, d, the edge's chains and points, `bladeArea`, `bladeMeanThickness` and the
  frame's point are bit-identical over 100–300 random permutations of each fixture's parts (`orders.txt`).
- **What the order reaches.** The budgets' ladders (the raster's cell, Thinness' k, Asymmetry's spacing) sum integers, so
  no order moves them. The stride's choice of samples and every float sum can move, which is why §17.2 asks for "§5.2's
  probes and budgets included" in rank order: every walk in Edge and Factors goes through the measure's rank.
- **`budget`** stays exactly §4.7's five fields; the Thinness stride and the Asymmetry spacing come back through
  `Factors.measure`'s second value, for tests.
- **Phases.** `phase()` after the edge and after each distinct set: F2's phases-only count goes from 5 to 8 (edge, All,
  Blade).
- **Header.** Rewrite step 6 of the module header (near lines 17–19) and the comment at the plug-in spot.

---

## 4. Prototype → build map

The reference is `docs/spec/prototypes/S2/v2/` (§4.1, "Sampling details are pinned by the reference prototype", near line
835). Every line number below was re-checked on the snapshot's copy, which is unchanged. The emulator
(`verdict/analyze_build.luau`) runs the same edge and factor code, so every number in [7] is this code's, on the build's
verdict, measure and ownership.

| Prototype (`v2/analyze.luau`) | Build | On the way |
|---|---|---|
| `:20–124` CFG | `Balance.Geometry`, `Balance.Difficulty`, `Limits.CONTACT_TOL`, `EquipmentTypes.Sword.geometry`, `Steps`, `CraftPlans.Sword`, `Materials`, `Tiers` | no literal in Physics; refs in FactorId order |
| `num.luau` clamp01, norm, q4, cbrt | `Factors.norm`, `Factors.cbrt`, `Difficulty.q` → `Quantize.q` | same arithmetic; q also folds −0 |
| `:185` mergedLength | `Edge` local + `Edge.mergedLength` | the export sorts a copy |
| `:211` slab, `:224` lineHitsAabb, `:238` unionChordAt | `Factors` locals, `Factors.unionChord` | the list in rank order |
| `:272` simplify | `Edge.simplify` | the same tie rule (`d > best` keeps the first maximum); charged per split |
| `:316` gripFrame | `MassProps.gripFrame`/`difficultyFrame` (M2) | called on `byRank` |
| `:403–723` edgeProfile | `Edge.profile` | no `%` or `//` ([3.2]) |
| `:1274–1293` frame, edge, cutIndex | `Analyze.run` phase 6, `Edge.cutIndex` | the frame's axis is fixed {0, 1} |
| `:1300–1318` workSet | `Blueprint/WorkSet.select` (M2) | ascending; `Factors` sorts by rank |
| `:1325–1357` Volume, PartCount, MaterialMix, SC, EdgeLength, Joints | `Factors.measure` | V from `ownedVolume`; A from `exposedKept`; `conn` → `graph.touching`; no keyed `mats` set |
| `:1358–1423` Thinness | `Factors.thinness` | rank order; phase 5's samples; the running counter; `ownedAt` → `owned.higher` |
| `:1424–1502` Asymmetry | `Factors.asymmetry` | rank order |
| `:1503–1510` normalization | `Factors.measure` | refs from geometry |
| `:1513–1529` keyOf, cache | `Analyze.run` | the same keys |
| `:1530–1536` g | `Difficulty.step` | the weights' stored order (FactorId) |
| `:1537–1552` governing, m, d | `Difficulty.governing`, `softOr` | `Materials.ordered`; nil on an empty set |
| `:1553–1569` tiers, factors, terms | `Tiers`, `StepAnalysis` | as is |
| `:726–747` tick, phase | `spend`, `phase` (Analyze near 342–357) | charges as in [3.2]–[3.3] |

---

## 5. Constants

Every Balance constant M3 reads already exists with §16's value. The values were checked in `Balance.luau`,
`Limits.luau`, `EquipmentTypes.luau`, `Steps.luau`, `CraftPlans.luau`, `Tiers.luau`, `Materials.luau` and
`Quantize.luau`.

| Constant | Value | Lives in | §16 row |
|---|---|---|---|
| `EDGE_CELL`, `RASTER_TOL`; `EDGE_MAX_CELLS`, `EDGE_MAX_WORK`; `EDGE_MAX_THICK`, `EDGE_DOWN_COS`; `EDGE_SIMPLIFY`, `EDGE_GAP_BRIDGE`, `EDGE_MIN_CHAIN`; `EDGE_MAX_POINTS`; `CUT_LO`, `CUT_HI` | 0.02, 0.005; 12000, 30000; 0.25, 0.5; 1, 3, 3; 256; 10, 60 | `Balance.Geometry` (near lines 76–87) | §16.10 near line 3950 |
| `H_LADDER`; `H_VOL`, `N_MIN_AXIS`, `N_MAX_AXIS`, `N_MAX_PART` | {1 … 16}; 0.05, 2, 48, 3000 | `Balance.Geometry` | §16.10 |
| `V_PART_FULL`; `JOINT_BOOST`, `A_JOINT_REF`; `THICK_BUDGET`; `SIGMA_LO`, `SIGMA_HI`; `THIN_SHARE_MIN`; `ASYM_TOL`, `ASYM_RAMP`; `ASYM_N_MIN`, `ASYM_AXIS_X`, `ASYM_WORK` | 0.004; 1.0, 0.05; 400; 45, 130; 0.25; 0.02, 0.03; 10, 0.6, 30000 | `Balance.Difficulty` (near lines 107–120) | §16.10 near line 3963 |
| `CONTACT_TOL` | 0.01 | `Limits` | §16.2 |
| refs, slots, `thicknessAxis` | [2.4] | `EquipmentTypes.Sword.geometry` | §16.5 |
| weights; plan; tiers; materials | [2.4] | `Steps`, `CraftPlans`, `Tiers`, `Materials` | §16.6, §16.11, §16.7, §16.4 |
| `SCALAR_SCALE` | 10000 | `Util/Quantize` | §16.17 |
| `CHECK_UNITS` | **500** (D3) | `Analyze.luau` (local) | §16.18 near line 4193 |
| numeric guards, new | τ floor 1e-6, bladeLength floor 1e-6, Douglas–Peucker's degenerate-segment test `ll > 1e-24` | locals | add to §16.18's guards row (near line 4198) |
| `TOL_FACTOR_ABS`, `TOL_G_INVARIANT`, `TOL_DUST_G`, `TOL_ASYM_ZERO`, `STARTER_MARGIN`; `ANALYSIS_LUNE_MAX_MS`, `CHECKPOINT_GAP_LUNE_MS`; `FUZZ_N_VALID`, `PROP_N`, `CASE_BUDGET_MS`, `SLOW_CASE_BUDGET_MS` | 0.02, 0.002, 0.005, 0.02, 0.05; 60, 0.35; 500, 200, 2000, 300000 | `tests/lib/Tol` | §16.32 |
| **new** `TOL_EDGE_REL` | 0.02 (E-S8.4's X04 bound, "\|ΔEdgeLength\| ≤ 2 %") | `tests/lib/Tol` | §16.32, new row |
| **new** `PERF_RUNS` | 15 (the median rule) | `tests/lib/Tol` | §16.32, new row |
| **new** `PARITY_DESIGNS`, `PARITY_SEED` | 200, 0x5EED0002 | `tests/lib/Tol` | §16.32, new rows |

---

## 6. Fixtures

### 6.1 Sources and the modules they become

`tests/fixtures` is a Rojo root (`ReplicatedStorage.BlacksmithTests.fixtures`, `test.project.json`). Its modules require
only `./Build` and each other, use exact arithmetic and pasted literals, and never recompute trigonometry (Build.luau's
header).

| Fixtures | Source | Build module |
|---|---|---|
| C01, C02 (Iron), C02s (Steel), C04–C15, in the prototype's list order | `v2/fixtures.luau` `calibration()` (near line 280) | `tests/fixtures/Calibration.luau` (new) |
| A25, A26 and its base ("F1 ring grip"), A27 | `adversarial()` (near line 337) | `tests/fixtures/Adversarial.luau`: three new cases, A26's base as a variant |
| X01–X07, every variant and every union base | `regression()` (near line 387) | `tests/fixtures/Regression.luau` (new) |
| P1–P5 | `perf()` (near line 585) | `tests/fixtures/Cost.luau` (new) |
| P1–P3 + a floating Dust speck | `verdict/lines/d_cost.luau`'s `speck` (near lines 28–36): the 24th part replaced by a 0.05 Block at (0.7, 0.2, 0.2) in its slot. `Disconnected`, so measured only with `measureInvalid`. Kept for comparison with E-S2.11 | `Cost.luau` |
| P1–P3 + an attached Dust speck (new) | the same Block at part 23's centre: connected, cleaned as Dust, valid. This is the production path, since §11.13's preview call (near line 2898) passes no `measureInvalid` | `Cost.luau` |
| X08 (D4) | aliases: X08a = P2, X08b = P1, X08c = P5 | `Cost.luau` (`Cost.X08`) |
| the worst designs | `docs/spec/prototypes/S2/cover/worst_designs.luau` (`valid` 11, `tooComplex` 17) | `tests/fixtures/WorstDesigns.luau` (new): a copy that Studio can read for S-PERF-01, checked in Lune against the docs file bit for bit |
| the S-PAR-02 list | everything above, plus F1–F5 and the canonical A variants | `tests/fixtures/Parity.luau` (builder 4) |

### 6.2 Rows, records and checks

- **Rows.**
  - Each part is `Build.part(id, slot, shape, material, pos, rot, size)`, with ids 1..n in the prototype's list order,
    copied from `proto-r2/out/fixtures_literals.txt` (64 fixtures, 577 rows, this machine's bits).
  - Named rotations are `I`, `Z45`, `Z90`, `Y90`, and a new `Build.YM90 = table.freeze({ 0, -R, 0, R })`: the
    prototype's `RY_M90`, bit for bit, used 10 times by the tips.
  - Ten fixtures need pasted rotations, which the dump marks: C06, C09, C13, C15, A25, A26, P1, P2, P3 and P5.
  - P2–P4's positions use `math.sin(i)`, so they are pasted too.
- **Records.** `{id, label, what, core, expect}`, with `expect = {canon = {ok = true, equals = "draft"}, validation =
  {valid = true}, tiers, tierRaw (§5.5), cleaned, save = "Valid"}`. `Blueprints`' `Expect` type makes `oracle` and
  `starter` required, so give `Calibration`, `Regression` and `Cost` a type of their own, without the oracle.
- **A14's expectation** (Adversarial.luau near line 576) changes from `d = "NonIncreasing", gTol = "TOL_DUST_G"` to `d =
  "BitIdentical"`. Measured bit-identical to F1 ([7.6]). There is no mass relation: Dust counts for mass. Extend the
  relation type's comment with `"Within"` and add `bound` and `steps` fields for A25–A27.
- **Checks** (`tests/FixtureSet/{Calibration, Regression, Cost}.spec.luau`, in `Blueprints.spec`'s style):
  - **Canonical fixed point.** `Canonical.draft(core)` is ok and returns `core` bit for bit.
  - **Margins** ≥ 0.02 − 1e-12 (`Blueprints.spec` near line 79). F3 and C08 measure 0.019999999999999574; P4 measures
    0.010000000000000009 and is exempt, with its note (D6).
  - **Structure.** Ids in order, slots within their maxima, sizes in [MIN_DIM, MAX_DIM], every Ball and Cylinder in
    canonical size.
  - **The port, in Lune only.** Bit for bit against `docs/spec/prototypes/S2/v2/fixtures`, through `(require :: any)`
    as `Reference.spec` does (near lines 26–29).
  - **Validity.** Every fixture is valid, as `fixtures_literals.txt`'s headers show for all 64; the floating specks are
    `Disconnected`.
  - **Cleaned lists** (the snapshot's verdict):
    - C10/C11: E21, E22, D23, D24. X02: E6–E10. A25: E6.
    - P1: E6, E8, E11, E12, E13, E15, E16, E18, E22 (`Reference.spec`'s `OWN_VERDICT`).
    - P1 + either speck: E6, E8, E11, E12, E13, E16, E18, E22, D24. Without Giant24, E15 is kept.
    - P2 or P3 + either speck: D24 alone.
- **`PhysicsHelpers`.** Leave `H.p1()` and `H.ornate()` alone; M2's specs use them. `H.p1()` is not P1's bits
  (`p1bits.txt`), so every M3 number on P1 uses `Cost`'s literal.

---

## 7. Expected numbers (measured on the snapshot)

**Method** ([15] lists each script and output):

- The emulator runs with `build = true, measureInvalid = true`. It takes the build's verdict, measure, contact rows and
  ownership, and the prototype's edge and factors.
- "Part order" is the fixture's own list, how §5.5 and E-S2.9 were measured.
- "Rank order" is `Sampling.measureRanked`, built as `Reference.spec`'s `inRankOrder`: what M3 builds, and what the
  goldens will bless.
- Lune 0.8.9 on this machine; these numbers do not depend on load.

### 7.1 §5.5's table (§5.5, "d per step (Smelting / Hammering / Sharpening)", near lines 1285–1311)

In part order the emulator reproduces every cell of §5.5. In the measure's rank order one cell moves: **C09's Hammering
0.3170 → 0.3186**. That cell is what §17.2's "bless §5.5 on that" changes. No tier changes.

| Fixture | §5.5 | part order | **rank order (M3)** | tiers (raw) | EdgeLength / cutIndex |
|---|---|---|---|---|---|
| F1 = F5 | 0.0288 / 0.1037 / 0.0989 | = | = | N N N | 5.4330 / 0.72 |
| F2 | 0.0797 / 0.0176 / 0.0282 | = | = | N N N | 4.9803 / 0.43 |
| F3 | 0.0000 / 0.4423 / 0.6104 | = | = | N H(Ex) H(Ma) | 7.4089 / 1.00 |
| F4 | 0.4590 / 0.1572 / 0.3420 | = | = | H(Ex) N H | 5.7237 / 0.13 |
| C01 | 0.1486 / 0.0000 / 0.0407 | = | = | N N N | 5.0602 / 0.30 |
| C02 Iron = Steel | 0.0355 / 0.1137 / 0.1318 | = | = | N N N | 5.6435 / 0.77 |
| C04 | 0.0000 / 0.3368 / 0.4703 | = | = | N H H(Ex) | 7.1067 / 1.00 |
| C05 | 0.5451 / 0.1363 / 0.3466 | = | = | H(Ex) N H | 5.9721 / 0.16 |
| C06 | 0.0097 / 0.2991 / 0.5948 | = | = | N H H(Ex) | 6.4797 / 0.89 |
| C07 | 0 / 0 / 0 | = | = | N N N | 2.9683 / 0.31 |
| C08 | 0.1563 / 0.0992 / 0.2487 | = | = | N N H | 6.3917 / 0.62 |
| **C09** | 0.0001 / **0.3170** / 0.1904 | 0.0001 / 0.3170 / 0.1904 | 0.0001 / **0.3186** / 0.1904 | N H N | 5.4113 / 1.00 |
| C10 / C11 | 0.1565 / 0.0000 / 0.0282 · 0.1562 / 0.0012 / 0.0368 | = | = | N N N | 4.9802, 5.0202 / 0.27 |
| C12 / C14 | 0.0355 / 0.1137 / 0.1318 | = | = | N N N | 5.6435 / 0.77 |
| C13 | 0.0376 / 0.1133 / 0.1318 | = | = | N N N | 5.6435 / 0.77 |
| C15 | 0.0353 / 0.2701 / 0.4291 | = | = | N H H(Ex) | 5.6261 / 0.77 |

- **Starter margin.** F5's highest step is 0.1037 ≤ 0.2 − `STARTER_MARGIN` (Q7, Q21: "highest step 0.104").
- **Tiers and §5.5's prose.** All of §5.5's tiers hold. Its prose ("the arming blade 0.20 stud longer makes Sharpening
  Hard (0.2056) … thinned … to 0.045 makes Hammering Hard (0.2070)") holds in rank order ([7.6]).

### 7.2 The other fixtures, rank order (the goldens' values; part order where it differs)

| Fixture | d (rank order) | tiers (raw) | cleaned | part order, where it differs |
|---|---|---|---|---|
| A25 | 0.0288 / 0.1037 / 0.0989 | N N N | E6 | |
| A26 base / A26 | 0.0468 / 0.1037 / 0.0989 · 0.0471 / 0.1048 / 0.0989 (A26 cutIndex 0.51) | N N N | — | |
| A27 | 0.0288 / 0.1537 / 0.0989 | N N N | — | |
| X01 base (0.066) / X01 / X01raw | 0.0323 / 0.0754 / 0.0989 · 0.0323 / 0.0756 / 0.0989 · same | N N N | — | |
| X02 base (0.072) / X02 | 0.0358 / 0.0520 / 0.0989 · 0.0358 / **0.0510** / 0.0989 | N N N | X02: E6–E10 | X02 Hammering 0.0526 |
| X03 base (= F4) / X03 | 0.4590 / 0.1572 / 0.3420 · 0.4594 / 0.1575 / 0.1980 (X03: 2 chains, EdgeLength 4.7564) | H(Ex) N H · H(Ex) N N | — | |
| X04a, X04b | 0.0289 / **0.1035** / 0.0989 | N N N | — | Hammering 0.1041 |
| X04-5-0.004 / -0.006 / -0.009 | 0.0286 / 0.1037 · 0.0285 / 0.1044 · 0.0283 / 0.1037 (Sharpening 0.0989 throughout X04–X07) | N N N | — | |
| X04-10-0.004 / -0.006 / -0.009 | 0.0283 / 0.1037 · 0.0281 / 0.1037 · 0.0277 / 0.1038 | N N N | — | |
| X04g 0.005 / 0.010 / 0.015 / 0.020 | 0.0288 / 0.1037 · 0.1037 · 0.1045 · 0.1082 | N N N | — | |
| X05 +0.002 / +0.004 / +0.006 / +0.009 | 0.0287 / 0.1044 · 0.0286 / 0.1037 · 0.0285 / 0.1044 · 0.0283 / 0.1037 | N N N | — | |
| X05 −0.005 / −0.020 / −0.050 | 0.0288 / 0.1037 · 0.1044 · **0.1038** | N N N | — | −0.050: 0.1037 |
| X06 0.00 … 0.05 | Hammering 0.1037, 0.1037, 0.1087, 0.1227, 0.1385, 0.1543; Sharpening 0.0989, 0.0991, 0.1187, 0.1756, 0.2391, 0.3030 | N N N to N N H | — | |
| X07a / X07b / X07c | 0.0288 / **0.1035** · **0.1035** · **0.1044** | N N N | — | 0.1041 · 0.1042 · 0.1043 |
| P1 | 1.0000 / 0.0000 / 0.0086 (EdgeLength 0.1897) | H(He) N N | [6.2] | |
| P2 | 1.0000 / 0.0571 / 0.0308 (15 chains) | H(He) N N | — | |
| P3 | 0.2777 / 0.1804 / 0.1821 (7 chains) | H N N | — | |
| P4 | 1.0000 / 0.1389 / 0.1556 (6 chains) | H(He) N N | — | |
| P5 | 0.0328 / 0.1902 / 0.1202 (11 chains, cutIndex 0.81) | N N N | — | |
| P1 / P2 / P3 + a speck (either kind; `specks.txt`) | 1.0000 / 0.0000 / 0.0048 · 1.0000 / 0.0674 / 0.0479 · 0.2622 / 0.1759 / 0.1612 | H(He) N N · H(He) N N · H N N | [6.2] | |

### 7.3 E-S2.9's tables

`es29.luau` prints E-S2.9's four tables (physics, factors on All, factors on {Blade}, steps) in E-S2.9's own formats. In
part order all 80 rows equal SPEC-evidence's character for character (`diff` in `out/`). The physics columns are the
snapshot's `Analyze.run`; edge, factors and steps are the emulator's. In rank order exactly two cells move:

- C09's Thinness on All: 0.3858 / 0.386 → **0.3898 / 0.390**;
- C09's Hammering: 0.3170 → **0.3186**.

Every other raw factor agrees at E-S2.9's 4 significant digits. The order moves last bits elsewhere: SurfaceComplexity
4e-16, Joints 2e-15, Volume 1e-17, Asymmetry 7e-14 (`tab.txt`'s last column).

### 7.4 Order dependence (§17.2, near line 4429)

- **Part order.**
  - C09 in 300 random permutations (xorshift32 seeds 0x5EED0100 + k, `lib.shuffled`): Hammering **0.3170–0.3195**, Smelting
    and Sharpening exact, 298 distinct outcomes. This reproduces §17.2's "Hammering 0.3170–0.3195".
  - P5 in 60: Hammering **0.1853–0.1902**, as §17.2.
  - X01 in 100: 0.0749–0.0764; X02: 0.0510–0.0542.
  - Every other F, C, A and P fixture keeps its 4-decimal d, but 2–100 distinct outcomes in the last bits.
- **Rank order.** One outcome per fixture over all 100–300 permutations, equal to the fixture's own rank-order run: every
  factor raw, d, the edge's chains and points, `bladeArea`, `bladeMeanThickness` and the difficulty frame's point, to
  the bit (`orders.txt`).

So walking `measureRanked` removes the order dependence §17.2 describes. It changes §5.5 in one cell (C09, +0.0016)
and a few regression rows, all within their bounds ([7.6]): X02 −0.0016; X04a/b and X07a −0.0006; X07b −0.0007; X05
−0.050 and X07c +0.0001.

### 7.5 The edge (T-EDG-01)

- **F5.** One chain, 5.4330, 5 points, first (0.080, 1.380), last (−0.080, 1.380); cell 0.02; cutIndex 0.72. The chain
  starts at the +X base, runs over the tip and ends at the −X base (§4.6, "the main chain of a symmetric blade starts at
  the +X base").
- **P5's comb.** 11 chains [1.678, 0.552, 0.552, 0.541, 0.541, 0.532, 0.532, 0.521, 0.521, 0.170, 0.170]; EdgeLength
  1.6777 (§5.6, "comb blade: 11 chains, EdgeLength 1.678").
- **X04.** All 12 cases give one chain of 5.4330, a 0.00 % change.
- **A thick blade.** F2 with a 0.30-thick blade is valid, with EdgeLength 0 and no chain.
- **The cap case.** F2's hilt with a 1.4 × 3.43 × 0.06 Block blade standing on the guard (centre y 1.55 + 3.43/2, top
  4.98) is valid, with one chain of **8.2001** and EdgeLength x = 1. No fixture reaches 8 (F3 is 7.4089).
- **Translation.** Y moves the main chain's points by exactly Δy (within 8.9e-16) and EdgeLength within 1.8e-15, on F1,
  F3, F5, C02 and C06 under E-S2.10's 6 offsets. F3 leaves the hitbox on 3 of them, which are skipped as `v2/run.luau`
  skips them (`translate.txt`). Z (0.01 and −0.037) leaves the chains bit-identical and `bladeArea` and the mean
  thickness unchanged on the same five (`ztrans.txt`).
- **The X mirror image.** The raster (`bladeArea`, mean thickness) agrees within 1e-12 on 169 of 169 designs (19
  fixtures, 150 Gen). EdgeLength changes by up to 0.2942 % (Gen #31: 6.935592 / 11 points against 6.915188 / 9).

### 7.6 Contracts (T-DIF-01, 04, 06, 13)

- **T-DIF-01's caps.** A24 is valid: Thinness 1.0000 on All and Blade, Hammering 0.4000 Hard. Volume x = 1 on P1
  (2.2682), P2 (0.9968) and P4 (1.2608). SurfaceComplexity x = 1 on F3's Blade (r 2.9804). EdgeLength x = 1 on the cap
  case.
- **T-DIF-04: bit-identical steps and edge against the base, in rank order** (`contracts.txt`, `dif04`):

| Case | base d | cleaned |
|---|---|---|
| C04 with a 0.075 blade + 9 nested blocks (×(0.96 − 0.02k), `Reference.spec` near line 276) | 0.0000 / 0.1863 / 0.3835 N N H | the 9 |
| C09 with core, bevels and tips 0.05 longer + 6 blocks (×(0.75 − 0.005k), 5 Blade + 1 Pommel, near line 297) | 0.0008 / 0.3299 / 0.2153 N H H | the 6 |
| C09 + a plate 0.12 × 2 × 0.05 at (−0.03, 2.6, 0) + 5 hidden blocks (×(0.8 − 0.01j), slots G G G B B, `verdict/lines/limit2.luau`) | 0.0009 / 0.3599 / **0.2542** N H H (the plate kept, §17.2's "Sharpening 0.2542 Hard, with 0 and with 5 hidden blocks") | the 5 |
| X07a + a Dust hairline 0.02 × 0.4 × 0.02 at (0, 2.68, 0) | 0.0288 / 0.1035 / 0.0989 | D7 |
| F5, C02, C05 + 4 flush plates in the main blade, listed first (`Verdict.spec`'s skins near line 349: Guard on ±Z, Pommel on ±X) | the fixture's own | the 4 plates |
| A14 (19 Dust cubes) vs F1; A16 vs F1; A17 vs F2; A25 vs F1 | the base's own | D6–D24; E6 E7; E5–E7; E6 |

- **T-DIF-06's real edits** (E-S2.2's, in rank order):
  - F5's blade 0.060 / 0.055 / 0.050 / 0.047 / **0.045** / 0.043 thick gives Hammering 0.1037 / 0.1322 / 0.1658 /
    0.1895 / **0.2070 Hard** / 0.2263, with Thinness on All 0.2594 → 0.5657, non-decreasing.
  - C02's blade +0.15 / **+0.20** / +0.25 gives Sharpening 0.1889 / **0.2056 Hard** / 0.2314, with EdgeLength 5.9635 /
    6.0435 / 6.1635.
  - PartCount: C01 4.000 → C10 6.916.
- **T-DIF-13's relations** (`t13.txt`, rank order):
  - X01 and X02 against their union blades: \|ΔD\| 0.0002 and **0.0010**. X02 is 0.0006 in part order, so §5.6's
    "(0.0002 / 0.0006)" becomes "(0.0002 / 0.0010)", inside its own "ΔD ≤ 0.0010".
  - X03 against F4: Thinness 0.0000 on All, +0.00034 on the Blade; Hammering +0.0003.
  - X05 and X07 against F5: \|ΔG\| ≤ 0.0007.
  - X06's Asymmetry on the Blade against the 120-probe oracle (`v2/run.luau`'s `asymOracle`: `ASYM_N_MIN` 120,
    `ASYM_WORK` 1e9, `N_MAX_AXIS` 400): 0 / 0 / 0.040 / 0.153 / 0.280 / 0.408 against 0 / 0 / 0.041 / 0.156 / 0.282 /
    0.408, a largest error of 0.0030.
  - A25 \|ΔD\| 0.0000, A26 0.0011, A27's Sharpening 0.0000 (its Hammering 0.1037 → 0.1537).
  - C10 / C11 against C01: Smelting +0.0079 / +0.0076, Hammering +0.0000 / +0.0012, Sharpening −0.0125 / −0.0039, all
    Normal.
- **Production.** g and d through `Steps`' order and `Quantize.q` equal the emulator's on all 192 steps (`gorder.txt`).

### 7.7 Invariances (T-DIF-07, T-DIF-08)

- **(a) Y/Z translation.**
  - Fixtures (E-S2.10's 6 offsets): F1 and F5 \|Δx\| 0.0017 (Smelting's Thinness, unweighted there), \|ΔG\| 0.0007;
    F3, C02 and C06 0.
  - 300 `Gen.translated` designs: \|ΔG\| ≤ 0.0009 (#270), \|Δx\| ≤ 0.0022, 0 flips. Both pass `TOL_FACTOR_ABS` and
    `TOL_G_INVARIANT`.
- **(b) Flush re-segmentation.**
  - E-S2.10's F5 cuts (2, 3, 7 pieces) and C12 against C02: \|Δx\| ≤ 7.2e-16, \|ΔG\| 0 (stride and FINE).
  - 300 `Gen.segmented` designs, all with a cut, TestRng 0x5EED0007 (validSword, segmented, translated per design, the
    critique's stream):

| Probes | Thinness \|Δx\| | Asymmetry \|Δx\| | SurfaceComplexity | EdgeLength, Volume | \|ΔG\| | flips |
|---|---|---|---|---|---|---|
| §5.2 stride, rank order | 0.0591 (#51) | 0.0197 (#152); Sharpening 0.0143 (#55) | 0.0036; Sharpening 0.0056 | 0.0000 | 0.0236 (#51) | 0 |
| FINE (every owned sample a probe) | 0.0476 (#51) | 0.0197 (#152) | 0.0036; 0.0056 | 0.0000 | 0.0191 (#51) | 0 |

- **(c) Ids and order.** In rank order, every permutation tried gives steps and edge bit-identical ([7.4]).
- **T-DIF-08.** C13, built as half + mirror, has Asymmetry 0 on both sets (E-S2.9, reproduced). A whole design against
  its X mirror image (`Blueprint/Mirror.reflect`), on 19 fixtures and 150 Gen designs (TestRng 0x5EED0008): \|ΔD\| ≤
  0.0069 (Gen #136, Thinness x 0.0172), 0 flips. Reported, not asserted.

### 7.8 The 2 % rule's own limits (D1; §17.2 near lines 4432–4433; §5.6's last row)

**The sandwich.** `verdict/lines/limit2.luau`'s hilt (Ball d 0.30 at y 0.30, Cylinder 0.90 × 0.16 at y 0.88, Guard 1.10 ×
0.16 × 0.30 at y 1.40). Two cheeks w × l × c sit at z = ±(0.01 + c/2), so the gap is 0.02, with a top cap w × 0.04 ×
(0.02 + 2c). A Steel core wc × l × 0.02 sits in the gap. The build's verdict keeps the core in every design.

- **Hollow = cleaned.** Cleaned parts are inert under option 0, so "the core crosses 2 %" is the design with the core
  against the same design without it (hollow).
- **Rows 1–6.** A sheet wh wide over the core's rims makes the verdict clean both core and sheet, and that design
  measures exactly as the hollow one (checked).
- **Rows 7–9.** The sheet as built shows 2.05 % (0.025 of air beside it) and is kept. That is a visible change, not this
  class, so those rows compare with the hollow design.

| Cheeks w × l × c, core wc | core kept | hollow (core cleaned) | flips | \|ΔD\| |
|---|---|---|---|---|
| 1.1 × 2.0 × 0.06, 0.95 (LAM1, §17.2's) | 0.4282 H(Ex) / 0.0374 N / 0.0594 N | 0.3762 H / 0.3609 H / 0.2594 H | 2 | 0.3235 |
| 1.1 × 2.0 × 0.04, 0.95 | 0.3053 H / 0.2670 H / 0.1339 N | 0.2534 H / 0.4812 H(Ex) / 0.2594 H | 1 | 0.2142 |
| 1.1 × 2.0 × 0.03, 0.95 | 0.2439 H / 0.4346 H(Ex) / 0.2430 H | 0.1919 N / 0.6122 H(Ma) / 0.2594 H | 1 | 0.1776 |
| 1.1 × 2.0 × 0.02, 0.95 | 0.1825 N / 0.5352 H(Ex) / 0.2594 H | 0.1305 N / 0.6987 H(Ma) / 0.2594 H | 0 | 0.1635 |
| 1.2 × 2.5 × 0.05, 0.90 (LAM2) | 0.4883 H(Ex) / 0.4310 H(Ex) / 0.3850 H | 0.4265 H(Ex) / 0.4496 H(Ex) / 0.4250 H(Ex) | 0 | 0.0618 |
| 1.2 × 2.5 × 0.03, 0.90 | 0.3208 H / 0.6433 H(Ma) / 0.4250 H(Ex) | 0.2590 H / 0.6903 H(Ma) / 0.4250 H(Ex) | 0 | 0.0618 |
| 1.0 × 2.5 × 0.06, 0.80 | 0.4808 H(Ex) / 0.1655 N / 0.1929 N | 0.4259 H(Ex) / 0.3919 H / 0.3844 H | 2 | 0.2264 |
| 1.0 × 2.5 × 0.04, 0.80 | 0.3414 H / 0.4311 H(Ex) / 0.3595 H | 0.2865 H / 0.5400 H(Ex) / 0.3844 H | 0 | 0.1089 |
| 0.8 × 2.5 × 0.04, 0.60 | 0.2716 H / 0.4781 H(Ex) / 0.3163 H | 0.2305 H / 0.5400 H(Ex) / 0.3531 H | 0 | 0.0619 |
| **9 sandwiches** | | | **6 on 4** | **largest 0.3235** |

- **What carries the jump (LAM1).**
  - Hammering +0.3235: SurfaceComplexity +0.2876 (x 0.041 → 1.000, the cheeks' inner faces now show) and Thinness
    +0.0359 (x 0.062 → 0.152).
  - Sharpening +0.2000: SurfaceComplexity alone.
  - Smelting −0.0520: Volume.
- **Thinness is the minor channel.** §17.2's wording, "because cleaning it opens the chord in Thinness", names the
  smaller term; builder 4 rewrites it ([12]).
- **§17.2's "D jumps 0.34–0.47 whatever the precision".** Not reproduced on these 9 designs (largest 0.3235), and E-S2.12
  holds no row for it. The sheet designs below jump 0.33–0.36. Builder 4 replaces it with this table.

**The rule's other limits** (`sealed.txt`; part and rank order agree to 4 decimals but one cell, noted):

| Design (the r2 verifier's, scratch `m2r5-v1-2/a_void.luau`, `a_lam.luau`, `a_sheets.luau`) | before → after | \|ΔD\| | flips |
|---|---|---|---|
| closed box 0.60 × 3.0 × 0.20, walls 0.02 + a block in the cavity 0.03 clear, on a strut | Smelting 0.1376 N → **0.4463 H(Ex)** (§5.6's numbers) | 0.3087 | 1 |
| closed box 0.60 × 3.0 × 0.10 / 1.00 × 3.0 × 0.20 walls 0.03 / 0.30 × 3.0 × 0.12 walls 0.02 | Smelting +0.0882 / +0.5374 (H → H(He)) / +0.0856 | ≤ 0.5374 | 0 |
| 1.6 × 3.5 × 0.16 blade against 8 flush layers (6 cleaned) | Hammering 0.0582 N → **0.7000 H(Ma)** (§5.6's numbers); Smelting 1.0000 → 0.3500 | 0.6500 | 1 |
| 1.5 × 3.4 × 0.08 in 4 layers (2 cleaned) / × 0.12 in 6 (4) / × 0.14 in 7 (5) / 1.6 × 3.5 × 0.20 in 10 (8) | Hammering 0.3659 → 0.7000 (Smelting 0.6048 → 0.3223) / 0.2254 → 0.7000 / 0.1223 N → 0.7000 / 0.0000 N → 0.7000 | 0.3341 / 0.5650 / 0.6777 / 0.7000 | 0 / 0 / 1 / 1 |
| 0.6 × 3.0 × 0.14 and 1.0 × 3.0 × 0.14 in 7 layers (none cleaned) | Sharpening −0.0023 / −0.0016 | ≤ 0.0028 | 0 |
| a laminate whose core 0.95 shows, under 4 / 6 / 10 / 14 sheets in gaps 0.04 / 0.06 / 0.10 / 0.14 | the core cleaned with every sheet; Hammering 0.0222 N → 0.3502 H … 0.0257 N → 0.3688 H (rank order: 0.0231 → 0.3687) | 0.3280 / 0.3302 / 0.3378 / 0.3639 | 2 each |

None of these is reachable by an M3 rule, which is why D1 stays at option 0:

- the filler in the sealed cavity truly shows 100 %, so it is kept and nothing in the measure hides it;
- the layers are 0.12 apart at most;
- the sheets clean a core that truly shows 11.92 %.

The fix, if wanted, is the verdict's (O10).

---

## 8. Tests

New spec files under `tests/Physics/` are discovered automatically. A fast case must stay under `CASE_BUDGET_MS` 2000 ms;
anything longer goes in `t.slow`. "Rank order" below means "the analysis as M3 builds it". Compare a fixture with the
prototype through `Proto.run(inRankOrder(b), {measureInvalid = true})`, as `Reference.spec` does, never through the
emulator, which `require`s a sibling `repo/` and cannot run from the repo.

### 8.1 T-EDG-01: `tests/Physics/Edge.spec.luau` (D4: §14.6 names it near line 3574 and defines it nowhere)

1. **F5 and F1.** One chain of 5.4330 with 5 points, first (0.080, 1.380) and last (−0.080, 1.380); cell 0.02;
   `physics.edgeLength = edge.length`; cutIndex 0.72.
2. **E-S2.9's edge and cutIndex columns** for F1–F5 and C01–C15, within 5e-4 ([7.1]'s column).
   - Then against `Proto.run(inRankOrder(b)).edge` within 1e-12 (chains, points, lengths, cell, `bladeArea`,
     `bladeMeanThickness`) on every prototype fixture whose verdict the build shares: calibration, golden, adversarial,
     regression, P2–P5.
   - P1's verdict is the build's own, so its edge is blessed alone.
3. **X04's 12 cases.** One chain each, EdgeLength 5.4330. The bound is `TOL_EDGE_REL`; the measured change is 0.00 %.
4. **P5's comb.** 11 chains with [7.5]'s lengths; EdgeLength 1.6777 is the main chain's.
5. **Rules.**
   - A 0.30-thick blade (F2's) gives EdgeLength 0.
   - The cap case gives 8.2001 (T-DIF-01 uses it).
   - Outline cells next to a hilt cell are ineligible; pommel-facing segments are dropped.
   - Every chain has ≤ `EDGE_MAX_POINTS` points and ≥ `EDGE_MIN_CHAIN`·cell length, and the chain order is total.
6. **Invariance.**
   - Y translation by E-S2.10's offsets moves every point by Δy (within 1e-9) and keeps lengths within 1e-12; offsets
     that leave the hitbox are skipped.
   - Z translation leaves the chains bit-identical, with `bladeArea` and the mean thickness within 1e-12 (measured
     unchanged).
   - The X mirror image (`Blueprint/Mirror`, plane "X"): `bladeArea` and `bladeMeanThickness` within 1e-12; EdgeLength
     within `TOL_EDGE_REL`, with the largest change printed (measured 0.2942 %).
   - Run on F1–F5, C01–C15 and 40 `Gen.validSword` designs fast, `FUZZ_N_VALID` slow.
7. **Budgets on P1** (`Cost`'s literal). Cells ≤ `EDGE_MAX_CELLS` and work ≤ `EDGE_MAX_WORK` at the chosen cell, or
   the last rung.

### 8.2 T-DIF-01…13: `tests/Physics/{Factors, Difficulty, Invariance, DifficultyTable}.spec.luau`

Catalogue names are E-S8.5's ("T-DIF 01 P-RANGE, caps · 02 soft-OR identities, 101 × 101 grid · 03 boundary …", near
line 2240 of SPEC-evidence). Contract text is §14.6's (near lines 3591–3596).

| Id | Asserts (measured value) | Inputs | Tolerance |
|---|---|---|---|
| T-DIF-01 P-RANGE, caps | every x ∈ [0, 1]; raw finite and ≥ 0, Thinness and Asymmetry raw ≤ 1; g, m, d ∈ [0, 1] on the 1e-4 grid (`q(v) == v`). Caps as [7.6]: A24 (1.0000 / 1.0000, Hammering 0.4000), Volume (P1, P2, P4), SC (F3 Blade), EdgeLength (the cap case first asserted valid with E ≥ 8) | every fixture; 60 `Gen.validSword` fast, `PROP_N` slow | exact |
| T-DIF-02 soft OR | on m, g ∈ {0, 0.01, …, 1}: softOr(0, g) = g, softOr(m, 0) = m, symmetric, ≥ max, softOr(1, g) = 1, non-decreasing, on the grid | `Difficulty.softOr` | exact |
| T-DIF-03 boundary | `Tiers.tierFor(0.1999999999)` Normal, `tierFor(0.2)` Hard (§14.6, "D = 0.1999999999 is Normal, 0.2 Hard"); production quantizes first: q(0.19995) = 0.2 → Hard, q(0.199949) = 0.1999 → Normal; NaN errors (`Quantize.q` "non-finite", `Tiers`); tierRaw unclamped (F3 Expert/Master, P1's Smelting Hell) | `Tiers`, `Difficulty` | exact |
| T-DIF-04 enclosed, duplicates, dust | the cases of [7.6] bit-identical (`Dump.canonical` on steps and edge); then `Gen.withFiller(…, "Enclosed" \| "Duplicate" \| "Dust")` on 40 designs fast, `FUZZ_N_VALID` slow (measured on 100 designs × 3 kinds, TestRng 0x5EED0009: every filler cleaned, all bit-identical, `filler.txt`). Excluded: a copy in a slot whose name sorts first (§4.4, "in one whose name comes first it takes over") | fixtures, Gen | bit-identical, Dust included (stronger than §14.6's \|ΔG\| ≤ `TOL_DUST_G`) |
| T-DIF-05 Iron ↔ Steel | C02 Iron vs Steel: every g, m, d, tier, tierRaw and factor bit-identical, `material` Iron/Steel; F1 vs F5 d identical (F1's MaterialMix raw 2, unweighted); Gen with every material swapped: d bit-identical, m = 0 (measured: 100 of 100 designs bit-identical but for `material`, `filler.txt`) | fixtures, Gen | exact |
| T-DIF-06 monotone | [7.6]'s sweeps: Thinness (All) and Hammering non-decreasing as F5's blade thins, 0.045 Hard (0.2070); EdgeLength non-decreasing as C02's blade grows, +0.20 Hard (0.2056); PartCount C01 → C10 rises | variants built in the spec | exact order |
| T-DIF-07 invariances | (a) translation: F1, F3, F5, C02, C06 × E-S2.10's offsets (skip those out of the hitbox) and 40 `Gen.translated` fast / `FUZZ_N_VALID` slow: \|Δx_f\| ≤ `TOL_FACTOR_ABS`, \|ΔG\| ≤ `TOL_G_INVARIANT`. (b) per D2: F5's 2/3/7 cuts and C12 vs C02 at those tolerances; on 40 `Gen.segmented` fast / `FUZZ_N_VALID` slow, Volume and EdgeLength within `TOL_FACTOR_ABS`, Thinness, Asymmetry, SurfaceComplexity and G printed. (c) C09, P5 and P1 with shuffled ids (canonicalized, so the parts reorder): steps and edge bit-identical; physics within 1e-12 (M2 sums it in blueprint order). X shifts and whole-sword turns are real changes; C15 is not asserted | fixtures, Gen | as stated |
| T-DIF-08 mirrored Asymmetry | C13 Asymmetry 0 on both sets; Gen swords built half and mirrored with `Blueprint/Mirror`: ≤ `TOL_ASYM_ZERO` (all §14.6 asks; **unchecked** here). A whole design against its X mirror image: printed, not asserted (\|ΔD\| ≤ 0.0069 measured) | fixtures, Gen | `TOL_ASYM_ZERO` |
| T-DIF-09 step scoping | `steps` = the enabled CraftPlans steps in order; Sharpening's factors on `WorkSet.select(…, {"Blade"})`; Smelting and Hammering share All's; `terms` in `Steps`' order, Σw = 1; A27: Sharpening = F1's (0.0989) while Hammering 0.1037 → 0.1537; cleaned parts in no set; a planted CraftPlans with a disabled or an extra step is followed (`Drafts.planted`); O8's label rule: F3 with its blade relabelled Guard plays Sharpening 0.6104 → 0.0645, C08 0.2487 → 0 (§17.1 O8's numbers, measured, `o8.txt`) | fixtures | exact |
| T-DIF-10 client = server | `Analyze.run(core)` = the same run with `checkpoint = coroutine.yield` resumed in a loop = with `measureInvalid = true`, by `Dump.canonical` (§14.6, "client analysis path = server path, 500 designs") | 50 `Gen.validSword` fast, `FUZZ_N_VALID` slow | bit-identical |
| T-DIF-11 fixture tiers | every fixture's tier and tierRaw = §5.5 (`expect.tiers`, `expect.tierRaw`; `Blueprints.spec` near line 162 extended); F5's max d ≤ Hard.dMin − `STARTER_MARGIN` | F1–F5, C01–C15 | exact |
| **T-DIF-12** (D4) | the §5 table golden ([8.3]) | every fixture | golden |
| **T-DIF-13** (D4) | the relations of [7.6] at E-S8.4's bounds: A25 ≤ 0.01, A26 ≤ 0.02, A27 Sharpening ≤ 0.02; X01/X02 ≤ 0.01; X03 ΔThinness ≤ 0.02; X05, X07 \|ΔG\| ≤ 0.01; X06 \|Asym − oracle\| ≤ 0.02 (the oracle: `Factors.asymmetry` with `ASYM_N_MIN` 120, `ASYM_WORK` 1e9, `N_MAX_AXIS` 400 planted); C10/C11 − C01 ≤ 0.008 on every step and all Normal (§5.6); A23 finite | A, X, C fixtures | E-S8.4's and §5.6's bounds |

**The factor-level comparison with the prototype** (in `Factors.spec`, on every shared-verdict fixture; builder 2):

- PartCount, Thinness, Asymmetry, EdgeLength and MaterialMix bit for bit;
- Volume, SurfaceComplexity and Joints within `Reference.spec`'s `ABS` 1e-12, since the build's owned volumes differ by
  up to about 4e-15 (MassProps' header);
- g and d equal on every fixture ([7.6]).

### 8.3 T-DIF-12: the §5 table golden

- **Files.** `tests/golden/difficulty_{calibration, regression, cost}.bv1.golden.txt`, in §14.9's `<name>.bv<N>` naming.
  Three files keep each fast case under 2 s.
- **One entry per fixture.** `{id, valid, cleaned, physics = {mass, volume, balance, reach, bladeLength, edgeLength,
  cutIndex}, edge = {chains = n, lengths, cell, bladeArea, bladeMeanThickness}, steps = {{step, g, m, d, tier, tierRaw,
  material, factors = {{factor, raw, x} × 8}} × 3}}`, through `Golden.check` (`Dump.canonical`, %.17g).
- **Bless only after the M2 fix round is merged and verified** (R1):
  1. Re-run `tab.luau` and `es29.luau -- rank` on the merged tree.
  2. Print `Analyze.run`'s d for every fixture beside [7.1]–[7.2]'s rank-order column.
  3. Accept exact matches; trace anything else to the fix round's change before going on.
  4. Run `lune run tests/run -- --bless`. Review `git diff tests/golden`: no existing golden may change,
     `balance_fingerprint` included.
  5. Record the comparison in `docs/build/M3-notes.md`.

### 8.4 T-PERF-01: `tests/Physics/Perf.spec.luau`, `t.slow` (§14.11, near line 3684)

- **Cases (`Cost.TPERF`).**
  - X08's aliases: P2 (X08a), P1 (X08b, also §14.11's "adversarial fixture P1", run once under both names), P5
    (X08c).
  - P3, P4.
  - P1, P2 and P3 + a floating speck (with `measureInvalid`), and + an attached speck.
  - `WorstDesigns.valid` (11) and `WorstDesigns.tooComplex` (17).
- **Method** (`verdict/lines/d_cost.luau`'s; `perf.luau`):
  1. One warm-up run per case.
  2. `PERF_RUNS` = 15 rounds, odd rounds forward and even rounds backward.
  3. Each round: `collectgarbage("collect")`, a timed run without a checkpoint, then a separate run whose checkpoint
     records the longest stretch (run start to the first call, call to call, the last call to the run's end).
- **Assertions.**
  - Per case: median total ≤ `ANALYSIS_LUNE_MAX_MS` 60.
  - Median longest stretch ≤ `CHECKPOINT_GAP_LUNE_MS` 0.35.
  - A `TooComplex` design answered within 60.
  - Print P1 and the worst valid designs against 29 ms (75 ÷ 2.6) without asserting it, as §14.11 says.
- **Wording.** §14.11 reads "every checkpoint gap ≤ `CHECKPOINT_GAP_LUNE_MS`". Single runs reach about 1 ms with GC
  (§17.2), so the rule is the median of `PERF_RUNS`; builder 4 writes that wording into §14.11 and §4.9.
- **Load.** Run it alone (`--filter Perf`). The medians in [9] were taken on a quiet machine; §17.2 records P4 at 0.37 ms
  with the machine 5–20 % busy. A failure under load is re-run once alone before anyone reads it as a regression.

### 8.5 The first S-PAR-02 digest (§14.10, "02 Server = Client = Lune digest", near line 3673; E-S8.6's "02 digest of `Pipeline.analyze` …")

At M5, S-PAR-02 digests `Pipeline.analyze`, judged bot runs and T-CR-08's outcomes. At M3 it is the first part:
`Analyze.run` over every fixture plus `PARITY_DESIGNS` 200 `Gen.validSword` designs. The Lune digest must equal the
digests computed in the Studio Server and Client data models. That shows no FMA contraction, `--!native` off, and the
same `string.format`, `math.round` and `table.sort`.

- **Lune side.**
  - `tests/fixtures/Parity.luau` returns the ordered `{name, core}` list: Blueprints, Calibration, Adversarial (A25–A27
    and every canonical A variant), Regression, Cost (both specks), WorstDesigns.
  - `tests/lib/Tol` gains `PARITY_DESIGNS` 200 and `PARITY_SEED` 0x5EED0002.
  - Digest: `{version = 1, analyze = {designs = n, fixtures = fnv1a32(lines₁), generated = fnv1a32(lines₂), bytes = …}}`.
    Each line is `name .. "\t" .. Dump.canonical(Analyze.run(core, {measureInvalid = true})) .. "\n"`, and
    `Dump.fnv1a32` is Dump.luau's (near line 190). Leave room for M5's `judge` and `outcomes` keys.
  - `tests/lib/Golden.luau` gains `Golden.digest(name, value)`: like `check`, but it writes `<name>.digest.txt` and
    asserts ≤ 1024 bytes (§14.2, "`.digest.txt` ≤ 1 KB for Studio", near line 3507).
  - `tests/Physics/Parity.spec.luau`, `t.slow`, calls `Golden.digest("parity.bv1", digest)`.
- **Studio side.** `tests/studio/e2e/S-PAR-02.luau`, in `S-PAR-01.luau`'s style: a "HOW TO RUN" and "OUTPUT" header,
  `emit`, `run()` in `xpcall`, a summary line, `return table.concat(lines)`.
  - **Preflight.** `RunService:IsRunning()` and `IsServer()`/`IsClient()`, reported as `datamodel`.
  - **Requires.** `ReplicatedStorage.Blacksmith.Physics.Analyze`; the Definitions `Gen.context` needs;
    `ReplicatedStorage.BlacksmithTests.lib.{Dump, Gen, TestRng, Tol}`; `…fixtures.Parity`.
  - **Yields.** `Analyze.run(core, {measureInvalid = true, checkpoint = slice})`, where `slice` calls `task.wait()` once
    4 ms are used (§1.6), plus a `task.wait()` between designs.
  - **Compare.** `Dump.canonical(digest) .. "\n"` against `ReplicatedStorage.BlacksmithTests.golden["parity.bv1.digest"]
    .Value`. Rojo makes `parity.bv1.digest.txt` a StringValue named by its stem; confirm the name at the first run. If
    it is missing, fail with `{"check":"golden"}` listing `golden:GetChildren()`. No `loadstring`.
  - **Output.** `[E2E] S-PAR-02 PASS|FAIL {"check":"analyze","datamodel":…,"designs":n,"fixtures":h1,"generated":h2,
    "expected":…}`. On a FAIL, print every design's own fnv1a32 so a Lune run can diff them.
- **The dry run in Lune.** `tests/Physics/SPar02.spec.luau` runs the snippet on `tests/ItemRender/FakeRoblox.luau`.
  FakeRoblox needs two additions: `RunService:IsClient()` (the inverse of `Options.server`), and `tests/golden` mapped
  as StringValues named by stem. This is the proof M2 gave S-PAR-01 (`ItemRender/SPar01.spec`).
- **Running it.**
  - The test place is Project 215, Rojo-connected on port 34873 from `test.project.json`. Play sessions only; nothing
    changes in Edit.
  - `list_roblox_studios`, `get_studio_state`, `start_stop_play(true)`.
  - `execute_luau` with the file's text, `datamodel_type = "Server"`, then `"Client"`.
  - `get_console_output`, `start_stop_play(false)`.
  - 3 fresh Play sessions, all green, with a clean console (§14.10). If one call runs too long, a `GROUP` constant
    selects "fixtures" or "generated".

---

## 9. The time budget (§4.9, §14.11, §16.32)

### 9.1 What bounds it

- **`ANALYSIS_LUNE_MAX_MS` 60** (§16.32, near line 4371): "coarse Lune regression guard (≈ 156 ms Studio); the 75 ms Studio
  ceiling of §4.9 is gated by S-PERF-01 only (C05 14.2 ms Lune ≈ 37 ms Studio, P1 31.7 ≈ 82; under `VERDICT_WORK_MAX` the
  slowest design found 36.0 ms for `Analyze.run`, §17.2)". The 36.0 is M2's phases alone.
- **`CHECKPOINT_GAP_LUNE_MS` 0.35** (near line 4372): "keeps Studio slices ≤ 5 / 8 ms (E-S8.8)".
- **§4.9's ceiling** (near line 1163): "≤ 75 ms Studio on real designs (the F, C and X fixtures; the slowest, C05, ≈ 37)".
- **§17.1 O7.** The verdicts' cap and "about 94 for `Analyze.run`" in Studio for the slowest valid designs (D7).

### 9.2 The verdict's share (`vshare.luau`, median of 15 rounds, quiet machine)

The machine was 1.6–10.6 % busy before the run, with no other Lune process. Times are ms Lune 0.8.9.

| Design | Cover units | verdict | whole exposure | `Analyze.run` (M2) |
|---|---|---|---|---|
| F5 / C02 / C05 / C09 | 2,033 / 2,644 / 1,165 / 21,851 | 0.20 / 0.25 / 0.12 / 1.41 | 1.24 / 1.46 / 4.61 / 6.87 | 1.44 / 1.83 / 5.47 / 8.15 |
| P1 / P2 / P3 / P4 / P5 | 330,993 / 27,108 / 8,354 / 172,903 / 2,973 | 10.95 / 1.87 / 0.56 / 9.40 / 0.31 | 18.32 / 8.84 / 7.78 / 11.66 / 2.18 | 21.98 / 11.54 / 10.67 / 13.33 / 2.50 |
| V1's cluster of 24 Balls (valid 1) | 687,304 | **29.13** | 31.67 | 33.31 |
| the 10 climbed valid designs | 370,029–655,542 | 11.41–21.02 | 17.06–30.32 | 18.61–**35.36** |

These agree with §4.9 and §17.2 ("the verdict on the F, C and X fixtures at most 1.5 ms (C09) and the whole exposure at
most 7.1"; "30.2 ms for the verdict … 34.7 for `Analyze.run` … at most … 36.0"), on a slightly quieter machine. The
verdict takes at most 29.1 ms, about half of the 60 ms guard. M2's phases together take at most 35.4 ms.

### 9.3 T-PERF-01's cases with M3 (`perf.luau -- 15`, median of 15 rounds, quiet machine)

The machine was 1.8–2.9 % busy before the run and 6.5–13.4 % during it, the run's own Lune process taking about 8 % of
the 12 threads. M2 is the snapshot's `Analyze.run`. M3 is the emulator's edge + factors, in rank order. The gaps are
each run's longest stretch between checkpoints; M3's uses the prototype's own charges.

| Design | M2 | M3 | **M2 + M3** | × 2.6 (Studio est.) | gap M2 | gap M3 |
|---|---|---|---|---|---|---|
| F5 | 1.49 | 2.70 | 4.19 | 10.9 | 0.086 | 0.205 |
| C02 | 1.89 | 2.91 | 4.80 | 12.5 | 0.080 | 0.132 |
| C05 | 5.43 | 7.81 | 13.24 | 34.4 | 0.140 | 0.128 |
| C09 | 8.18 | 4.88 | 13.06 | 34.0 | 0.111 | 0.100 |
| P1 (= X08b) | 22.39 | 6.13 | **28.52** | 74.1 | 0.231 | 0.226 |
| P2 (= X08a) | 11.23 | 8.79 | 20.02 | 52.1 | 0.127 | 0.165 |
| P3 | 10.81 | 6.39 | 17.19 | 44.7 | 0.119 | 0.124 |
| P4 | 13.91 | 6.75 | 20.65 | 53.7 | 0.162 | 0.147 |
| P5 (= X08c) | 2.55 | 3.76 | 6.31 | 16.4 | 0.078 | 0.184 |
| P1 / P2 / P3 + floating speck (`Disconnected`, `measureInvalid`) | 20.44 / 10.81 / 10.91 | 5.85 / 9.99 / 6.10 | 26.28 / 20.79 / 17.01 | 68.3 / 54.1 / 44.2 | ≤ 0.251 | ≤ 0.216 |
| P1 / P2 / P3 + attached speck (valid) | 20.85 / 10.82 / 11.04 | 5.94 / 10.25 / 6.07 | 26.80 / 21.08 / 17.10 | 69.7 / 54.8 / 44.5 | ≤ 0.261 | ≤ 0.215 |
| valid 1, V1's cluster | 33.60 | 5.59 | 39.19 | 101.9 | 0.148 | 0.120 |
| valid 2–11, the climbed designs | 18.81–35.22 | 4.96–14.72 | 23.88–**48.99** (valid 8, `tclimb_3.json #6`) | 62.1–127.4 | ≤ 0.179 | ≤ **0.317** (valid 8) |
| the 17 `tooComplex` designs | 10.17–23.88 | — | 10.17–23.88 | 26.4–62.1 | ≤ 0.182 | — |

- **Totals.** Every case is under `ANALYSIS_LUNE_MAX_MS` 60. The largest, 48.99 ms, leaves 11 ms of headroom.
- **`TooComplex`.** Answered in 10.2–23.9 ms (§4.9: "10.8–24.3").
- **Against §4.9's 75 ms Studio ceiling.** Real designs estimate at most about 34 ms Studio (C05, C09). P1 sits at 74.1
  estimated, and the climbed valid designs at 62–127. §14.11 has those "reported against 29 ms (75 ms ÷ 2.6)": P1 28.5
  passes, and 10 of the 11 valid designs do not.
- **Studio is not measured here.** The 2.6× factor is §4.9's assumption; S-PERF-01 measures it (M7–M8).
- **Against E-S2.11's emulated totals** ("F5 … 4.33, C02 4.90, C05 14.16, C09 13.71 … P1 … 31.73 … P4 12.74 … all under
  33 ms"), these are equal or lower everywhere but P4. The exact verdict costs P4 9.4 ms against the line reading's
  0.8, which is §4.9's "P4 about 20".

### 9.4 What M3 adds

- **Time.** M3's share is 2.7–7.8 ms on the F and C fixtures, 3.8–8.8 on P1–P5, 5.9–10.3 with a speck, and 5.0–14.7 on
  the worst valid designs, where it raises the slowest total from 35.4 to 49.0 ms (D7). The real code should cost about
  what the emulator does: it is the same arithmetic plus one `measureRanked` sort and a rank sort per work set. Builder
  3 measures it ([11]) and records it in M3-notes.
- **Checkpoints.** At `CHECK_UNITS` 500 with the prototype's charges, M3 adds 48 on F2 (41 → 89; `Analyze.spec`'s bound
  near line 813 is < 150), 55 on F5, 176 on C05, 138 on C09, 185 on P1 and 131 on P5 (`checks.txt`). [3.2]'s finer raster
  charge adds more, so builder 3 re-checks the F2 bound.
- **Stretches.**
  - M2's longest stretch is at most 0.261 ms (median) on every case. M3's emulated stretches reach 0.317 ms (0.33 on
    single runs) on the worst valid designs.
  - The loops that end them (`m3gap.txt`, 9 runs each):
    - the raster's per-cell charge (`edgeProfile`, `tick(1 + #rowB + #rowH)`): 0.29–0.30 ms median on valid designs 8
      and 9;
    - Thinness' per-probe charge: 0.21–0.24;
    - Asymmetry's `volumeSamples` and per-sample charge: 0.16–0.23.
  - [3.2]–[3.3]'s charges (two units per blade chord, the ownership tests counted) bring the raster's stretch toward
    0.15–0.2 ms. `CHECK_UNITS` stays 500 (D3).
- **The suites.**
  - The snapshot's `--quick` takes **16.94 s** (580 pass, 16 skip, 51 files) and the full suite **168.88 s** (596
    pass), both on a quiet machine.
  - M3's fast cases add roughly 1,300 analyses at about 5–15 ms each, plus the prototype comparisons, about 10–13 s in
    all. Hold the fast Gen corpora at 20 designs each (not 40–60). Builder 3 times `--quick` and moves corpora to
    `t.slow` past 25 s; the goldens and fixtures stay in `--quick`, because L2 runs on every change.
  - The slow additions (`FUZZ_N_VALID` corpora, T-PERF-01 about 40 s, Parity about 5 s) fit §14.1's 10 minutes.

---

## 10. Open items M3 inherits

| Item (source) | Resolution |
|---|---|
| Walk the measure's rank order, §5.2's probes and budgets included, and bless §5.5 on that (§17.2, "What ids and order still reach", near line 4429) | [3.5]. Measured: order dependence gone ([7.4]); §5.5 moves in C09's Hammering alone, 0.3170 → 0.3186 ([7.1]). Builder 4 rewrites the row's "M3's probes are still in part order …" with this |
| "M3 calibrates on the ranks as they are" (§17.2, "The measure keeps its rank", near line 4431) | `measureRanked` as the walking order; no rank changes; E-S2.9's tables reproduce ([7.3]) |
| A core sandwiched between cheeks: how a cleaned part affects Thinness' chords (§17.2, "Design question for M3", near line 4433) | D1, option 0: cleaned parts are inert and Thinness' chords open where a cleaned part was. [7.8]'s sweep shows SurfaceComplexity and Volume carry the jump, not Thinness. **[Decision to confirm]** (§17.1 O10, new) |
| A sealed cavity, flush layers, sheets (§17.2, "What the 2 % rule itself admits", near line 4432: "M3 and the designer: whether the rule should look through a sealed cavity or a stack of layers") | D1: no M3 rule reaches them ([7.8]). The verdict's owner decides, under O10 |
| The label of what shows counts (§17.1 O8; §17.2 near line 4430) | as the SPEC says; T-DIF-09 asserts it (F3 0.6104 → 0.0645, C08 0.2487 → 0, measured). **[Decision to confirm]** (§17.1 O8) |
| Checkpoint gaps, `CHECK_UNITS` (§17.2, "Checkpoint gaps", near line 4424) | D3: 500 stays; M3's charges ([3.2]–[3.3]); T-PERF-01 on medians ([8.4]) |
| The verdict's cost and the cap (§17.2 near line 4435; §17.1 O7) | D7: M3's measured share added to O7, §4.9, §16.10, §16.32. **[Decision to confirm]** (§17.1 O7) |
| Overlap budget: P1, P2, P4 mass −10.3 / −4.4 / −5.6 % (§17.2 near line 4434) | no M3 action. The goldens pin the budgeted numbers; `TOL_MASS_REL` is not asserted on P1–P5 |
| Round filler in a round part's model band (§17.2 near line 4426; the fix round's O9) | no M3 action; the goldens follow the merged verdict (R1) |
| Bit-identical factor digests Lune = Studio client = server (§17.2's S8 row near line 4451) | S-PAR-02 ([8.5]) |
| M1-notes (near line 76): (a) `withFiller` "Duplicate" moved d in the prototype; (b) `Gen.segmented` breaks T-DIF-07 | (a) the build cleans exact copies of every shape (`Shapes.sameSolid`): 100 Gen designs per filler kind bit-identical (`filler.txt`). (b) D2 |
| M1-notes (near line 89): F1–F5's d values blessed from `Analyze.run` in M3 | T-DIF-12 |
| From M2's plan: P2/P3 + a speck and the worst designs in T-PERF-01 and S-PERF-01; the median of 15; M3's budgets on 24 overlapping blocks; T-DIF-04's cases; the plug-in spot | `Cost.TPERF` and `WorstDesigns.luau`; `PERF_RUNS`; `Analyze.spec`'s P1 case near line 709 extended (raster cells and work within budget or the last rung, Thinness probes ≤ `THICK_BUDGET`, Asymmetry work ≤ `ASYM_WORK` or the last rung); [7.6]; [3.5] |
| `Reference.spec`'s comparisons that M3 supersedes | none must go. Its SurfaceComplexity stand-in, the `flipCase` prototype tiers and the `H.ornate` check all still hold under M3. Retiring them is optional, after M2's commit, so as not to collide with M2's fixer |

---

## 11. Order of work: four builders, one after another

**Before builder 1.**

- M2's fix round is merged and verified, and `lune run scripts/verify` is green on that tree.
- Copy the tree to a scratch folder as `repo`, put `proto-r2`'s files beside it as `proto`, and re-run `tab.luau`,
  `es29.luau -- rank`, `orders.luau -- 100 C09 P5` and `contracts.luau -- dif04`.
- Compare with [7]. A difference is the fix round's (flat faces against a Ball can move F1–F5's pommel faces in the last
  bits). Record it in a new `docs/build/M3-notes.md` (M1-notes' format), then go on.
- Time `--quick` and the full suite on that tree; the snapshot's were 16.94 s and 168.88 s.

Every builder's step ends with `lune run scripts/verify` green and its new cases passing. No builder commits.

### Builder 1: fixtures and Edge

| Files | What |
|---|---|
| `tests/fixtures/Build.luau` | `Build.YM90 = table.freeze({ 0, -R, 0, R }) :: Vec` with a comment ("the prototype's RY_M90, the tips") |
| `tests/fixtures/Calibration.luau` (new) | C01, C02, C02s, C04–C15 ([6]), rows from `fixtures_literals.txt`, records with `tiers`/`tierRaw` from §5.5 and `cleaned` |
| `tests/fixtures/Regression.luau` (new) | X01–X07, every variant and base, keyed as the prototype's ids (`X01`, `X01raw`, `X04-5-0.004`, …) |
| `tests/fixtures/Cost.luau` (new) | P1–P5, the specks (`floating`, `attached`), `X08 = {X08a = "P2", X08b = "P1", X08c = "P5"}`, `TPERF` ([8.4]'s list) |
| `tests/fixtures/WorstDesigns.luau` (new) | `valid`, `tooComplex` copied from `docs/spec/prototypes/S2/cover/worst_designs.luau` |
| `tests/fixtures/Adversarial.luau` | A25, A26 (+ base variant), A27 with `relation = {to, d = "Within", bound, steps}`; A14's relation → `"BitIdentical"`; the type comment; `ORDER`'s comment |
| `tests/FixtureSet/{Calibration, Regression, Cost}.spec.luau` (new) | [6.2]'s checks; `Cost.spec` also checks `WorstDesigns` against the docs file bit for bit |
| `src/shared/Physics/Edge.luau` (new) | [3.2] |
| `tests/Physics/Edge.spec.luau` (new) | T-EDG-01 ([8.1]). Until builder 3, build Edge's inputs from the snapshot's modules: `H.prepared(core)`, `Sampling.exposure(parts).kept`, `Sampling.measureRanked(parts)`, `MassProps.difficultyFrame(byRank, keptByRank, "Grip")`; cutIndex from `H.measure(core)`'s `bladeLength` |

**Numbers that must come out.**

- [7.5] to the digits given.
- [7.1]'s EdgeLength and cutIndex columns within 5e-4.
- `Proto.run(inRankOrder(b)).edge` within 1e-12 on every shared-verdict fixture.
- Every fixture valid, with its [6.2] cleaned list; the margins as [6.2].

**Check with** `lune run tests/run -- --filter Edge`, `--filter FixtureSet`, and `lune run scripts/verify` (luau-lsp
included).

### Builder 2: Factors and Difficulty

| Files | What |
|---|---|
| `src/shared/Physics/Factors.luau` (new) | [3.3]: `measure`, `ORDER`, and `norm`, `cbrt`, `unionChord`, `thinAxis`, `thinness`, `asymmetry` for tests |
| `src/shared/Physics/Difficulty.luau` (new) | [3.4] |
| `tests/Physics/Factors.spec.luau` (new) | T-DIF-01 (factor ranges, caps), T-DIF-06, T-DIF-08 (C13), X06's oracle (a copy of `Balance` with `ASYM_N_MIN` 120, `ASYM_WORK` 1e9 and `N_MAX_AXIS` 400, planted with `Drafts.planted` into `Sampling.luau`, whose `volumeSamples` reads `N_MAX_AXIS` itself, and into `Factors.luau` with that planted Sampling), `cbrt` against a reference on random inputs, `Factors.ORDER` = `Validate`'s FactorId order = `refs`' order, and [8.2]'s prototype comparison |
| `tests/Physics/Difficulty.spec.luau` (new) | T-DIF-02, T-DIF-03, T-DIF-05 (C02 Iron/Steel, F1/F5, `governing` ties by `Materials.ordered`, nil on an empty set), `step`'s terms in `Steps`' order |

- **The context.** Until builder 3, a `FactorContext` comes from a local helper in `Factors.spec`: `H.measure(core)` for
  `exposure` and `owned`; `Sampling.volumeProbes(parts, kept)`; `Sampling.measureRanked(parts)` for `rank`;
  `touching` built as `Analyze`'s V3 builds it (`Shapes.aabbOverlap(a, b, CONTACT_TOL)` then `Gjk.within(a, b,
  CONTACT_TOL)`); `edgeLength` from `Edge.profile`.
- **Numbers.**
  - E-S2.9's factor tables in rank order, C09's Thinness on All 0.3898 among them ([7.3]), within [8.2]'s tolerances.
  - T-DIF-06's sweeps ([7.6]); A24's caps; X06's 0.0030.
  - g and d equal to [7.1]–[7.2] on every fixture.
- **Check with** `--filter Factors`, `--filter Difficulty`, `scripts/verify`.

### Builder 3: Analyze's integration, T-DIF and T-PERF

| Files | What |
|---|---|
| `src/shared/Physics/Analyze.luau` | phase 6 ([3.5]); the types re-exported from Edge, Factors and Difficulty; D5's `measureInvalid` rule; the header's step 6 and the plug-in comment rewritten |
| `tests/Physics/Analyze.spec.luau` | near line 672: the report now carries `edge`, `steps`, `edgeLength`, `cutIndex`, `edgeCell` (assert them, not nil and 0). Near 744–770: add Edge, Factors, Difficulty, WorkSet, CraftPlans, Steps, Tiers, Materials, Quantize and Balance to the `modules` map; the phases-only count 5 → 8. Near 774: add M3's loop functions to the names list (local functions, so `debug.info` names them). Near 813: re-check F2 < 150. Near 885: the planted maps gain the same modules. Near 709: P1's M3 budgets ([10]). The quick-stage and `TooComplex` cases (near 156, 224) still see `edge` and `steps` nil |
| `tests/Physics/Invariance.spec.luau` (new) | T-DIF-04, T-DIF-07, T-DIF-09, T-DIF-10 |
| `tests/Physics/DifficultyTable.spec.luau` (new) | T-DIF-11, T-DIF-12 (goldens), T-DIF-13 |
| `tests/Physics/Perf.spec.luau` (new) | T-PERF-01 ([8.4]) |
| `tests/lib/Tol.luau` | `TOL_EDGE_REL` 0.02, `PERF_RUNS` 15 |
| `tests/golden/difficulty_{calibration, regression, cost}.bv1.golden.txt` | blessed per [8.3], after the fix round is merged |
| `docs/build/M3-notes.md` | the comparison against [7], timings, `--quick` and full-suite times |

**Numbers that must come out.**

- [7.1]–[7.2] to 4 decimals, rank order: C09 0.0001 / 0.3186 / 0.1904, every tier as §5.5.
- [7.6]'s T-DIF-04 cases bit-identical, and [7.7]'s invariances.
- T-PERF-01 medians as [9.3] (totals ≤ 60 ms; gaps ≤ 0.35 ms, M3's charges included). Measure T-PERF-01 alone, and
  record the load.
- `--quick` ≤ 30 s (cut the fast Gen corpora to 20 first); the full suite ≤ 10 min.

**Check with** `--filter Invariance`, `--filter DifficultyTable`, `--filter Perf` (alone), `--quick` timed, the full
suite, `scripts/verify`.

### Builder 4: S-PAR-02's digest and the SPEC

| Files | What |
|---|---|
| `tests/lib/Golden.luau` | `Golden.digest(name, value)`: writes `<name>.digest.txt`, ≤ 1024 bytes, `--bless` as `check` |
| `tests/lib/Tol.luau` | `PARITY_DESIGNS` 200, `PARITY_SEED` 0x5EED0002 |
| `tests/fixtures/Parity.luau` (new) | the ordered list ([8.5]) |
| `tests/Physics/Parity.spec.luau` (new, slow) | the Lune digest; `tests/golden/parity.bv1.digest.txt` blessed |
| `tests/ItemRender/FakeRoblox.luau` | `RunService:IsClient()`; `tests/golden` mapped as StringValues |
| `tests/Physics/SPar02.spec.luau` (new) | the snippet on FakeRoblox, server and client |
| `tests/studio/e2e/S-PAR-02.luau` (new) | [8.5] |
| `SPEC.md`, `docs/spec/SPEC-evidence.md` | [12]'s edits |
| `README.md`, `docs/build/M3-notes.md` | Status; the notes completed |

**Studio** ([8.5]): 3 fresh Play sessions, Server and Client each. Every digest equals the Lune golden, and the console
is clean (§14.10). Then `lune run scripts/verify` green in full, with `t.slow` (§14.1), then independent verification,
then the milestone commit.

---

## 12. SPEC and evidence edits (builder 4)

Each edit carries the measured value and its script. Lines are "near line N of the snapshot".

| Where (anchor) | Edit |
|---|---|
| §1.3 L2 ("Inside Physics: Shapes → Gjk, Cover → Sampling → MassProps → Analyze", near 197) | "… → MassProps → Edge → Factors → Difficulty → Analyze" |
| §4.1 ("sums in part order, then sample order", near 832) | "sums in the measure's rank order (`Sampling.measureRanked`), then sample order" |
| §4.7's comment ("nil while invalid; TooComplex: cleaned {}", near 1087) | D5: with `measureInvalid`, edge and steps are measured past V3–V5; nil after the quick stage and at `TooComplex`, and `steps` nil when an enabled step's work set is empty |
| §4.9 ("With M3's share emulated (E-S2.11) …", near 1151; "bounds every gap by …", near 1160) | M3's measured share and totals ([9.3]); the median of `PERF_RUNS`; O7's figure (D7) |
| §5.2 ("every k-th volume sample of W (part order, then sample order)", near 1214) | "(the measure's rank order, then sample order)" |
| §5.5's table (C09's row, near 1304) | Hammering 0.3170 → the blessed 0.3186 (rank order, §17.2). The note under the table names the rank order |
| §5.6 (X01/X02's row, near 1321; "Y/Z translation, re-segmentation along the length and width" row) | "(0.0002 / 0.0010)". Re-segmentation: E-S2.10's cuts exact; general designs per D2, with the measured sensitivity and O11 |
| §5.6's last row ("A filler in a sealed cavity …") | add the sandwich ([7.8]) and O10 |
| §14.6 ("T-EDG-01, T-DIF-01…13", near 3574; "**T-DIF-04/05**", near 3591; "**T-DIF-07**", near 3593) | define T-EDG-01, T-DIF-12, T-DIF-13 ([8.1]–[8.3]); T-DIF-04's dust bit-identical; T-DIF-07's (b) per D2 |
| §14.7 ("S2's calibration swords C01 …", near 3607) | X08's aliases (D4); P4's margin exemption (D6) |
| §14.11 (T-PERF-01's row, near 3684) | the median rule; the cases ([8.4]) |
| §16.10 (`VERDICT_WORK_MAX`'s rationale, near 3945) | with M3 the slowest valid design takes about 49 ms Lune for `Analyze.run` |
| §16.18 (numeric guards, near 4198) | add τ's floor 1e-6, bladeLength's floor 1e-6, Douglas–Peucker's `ll > 1e-24` |
| §16.32 (near 4339–4380) | new rows `TOL_EDGE_REL`, `PERF_RUNS`, `PARITY_DESIGNS`, `PARITY_SEED`; `ANALYSIS_LUNE_MAX_MS`'s rationale with M3's totals |
| §17.1 | O7's default with M3's figure (D7); new rows O10 (D1) and O11 (D2), numbered after the fix round's O9 |
| §17.2 | the rows near 4429 (order: done, measured), 4432–4433 (D1: [7.8]'s table, the mechanism, the residual "where a sandwiched core crosses 2 %, D can jump up to about 0.32 and flip up to 2 tiers"; drop "0.34–0.47"), 4424 (M3's gaps), and a new row for D2's sensitivity |
| E-S2.5 (X01, X02 rows) | rank-order values 0.0002 / 0.0010 |
| E-S2.9 (C09's rows) | Thinness on All 0.3898 / 0.390; Hammering 0.3186; "the parts in the measure's rank order" in the section's lead |
| E-S8.4 (A14's and X08's rows, near 2217) | A14 "D bit-identical"; X08's aliases and the zigzag's move to M4 |
| E-S8.5 (near 2240) | T-EDG-01, T-DIF-12, T-DIF-13 named and pointed at §14.6 |

---

## 13. Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | The M2 fix round under way changes how flat faces read against a Ball. F1–F5's pommel, C09's finials and P4's Balls touch flat faces, so last bits, or a cleaned list, may move | bless after the merge ([8.3]); re-run `tab`, `es29`, `orders` and `contracts` first ([11]) and trace every difference |
| R2 | Cost: the slowest valid design takes 49.0 ms with M3 emulated, 11 ms under 60. The real M3 may cost more (finer charges, the rank sorts) | profile per phase (raster, Thinness, Asymmetry); a real overrun is O7's designer call (D7), not a silent change to the guard |
| R3 | M3's stretches reach 0.317 ms (median) with the prototype's charges, close to 0.35 | [3.2]–[3.3]'s charges; T-PERF-01 on medians, run alone; §17.2's GC note (polygons reused, or an incremental GC step at each checkpoint) stays M2's |
| R4 | T-DIF-07(b) fails on general designs under every probe rule | D2 (i), O11 |
| R5 | The build's sums differ from the prototype's in the last bits (owned volumes up to about 4e-15; rank-order sums) | compare per [8.2]; the goldens come from the build |
| R6 | The emulator is not the build | its numbers are the 4-decimal targets; bit-for-bit and 1e-12 comparisons go against the pure prototype in rank order (`Reference.spec`'s way) |
| R7 | S-PAR-02 in Studio: `execute_luau`'s time limit, the Client data model, the StringValue's name | yield per design; the `GROUP` split; the FakeRoblox dry run; check the golden's name first |
| R8 | Timing noise from other agents (this machine runs several) | median of 15, T-PERF-01 alone, the load recorded beside every timing |
| R9 | Fixture literals carry this machine's libm bits | never recompute trigonometry in a fixture module; the port check runs in Lune only |
| R10 | `--quick` past 30 s | fast Gen corpora at 20; time it after builder 3 |
| R11 | M3's edits to M2's specs collide with M2's fixer | M3 touches only `Analyze.spec`'s M3 placeholders and adds new spec files; `Reference.spec` and `PhysicsHelpers` stay as they are |
| R12 | luau-lsp widens singleton unions | annotate the id locals ([3.1]) |

---

## 14. critique.md's points, as they stand on the snapshot

| Point | Where it stands now |
|---|---|
| C1 [blocker]: D2 does not make T-DIF-07 pass, and the stride is not the main cause | **Holds, re-measured on the snapshot to the same digits** (stride: Thinness 0.0591, G 0.0236 at #51; Asymmetry 0.0197 at #152; FINE: 0.0476, 0.0191). Taken in `plan.md` revision 2; here D2 (i) with O11 |
| C1's data point for (ii): τ over 4 axes; P3 and P5 cross to Hard with FINE | **unchecked** (it ran on the first plan's prototype verdict). It matters only to the (ii) study |
| C2: D2's grid at 400 is less accurate than the stride; phase 5 orphaned; `THICK_BUDGET` no cap | **moot**: the grid is withdrawn. The stride keeps phase 5's consumer and probes ≤ `THICK_BUDGET` ([3.3.1]). These are the conditions any (ii) grid must meet |
| C3 [blocker for D1's claim]: option B does not remove the tier flips | **Holds.** Option 0's sweep reproduces flip for flip on the snapshot (6 on 4 sandwiches, largest 0.3235). B is not re-measured (**unchecked**) and would now edit M2's measure. D1 = option 0, O10 |
| C3's mechanism: SurfaceComplexity's denominator and Smelting's Volume carry the jump | **Holds, measured** in LAM1 ([7.8]). The flush layers' Smelting drop is measured too (0.6048 → 0.3223) |
| C4: the mirror claims fail | **Holds, re-measured**: Gen #31 6.935592 / 11 points against 6.915188 / 9, raster equal; \|ΔD\| up to 0.0069 (#136). T-EDG-01 item 6 asserts the raster and gives EdgeLength `TOL_EDGE_REL`; T-DIF-08 reports |
| C5: T-DIF-07(c)'s "edge bit-identical" fails on `gripPoint` | **Fixed by the rank-order frame**: `difficultyFrame` on the measure's rank list. Measured bit-identical over 100–300 permutations per fixture ([7.4]) |
| C6: bit-for-bit factor comparison; T-EDG item 2 "on the same kept row"; `mergedLength` and P-NOMUT; A14's expectation; the EdgeLength cap; C08's margin | **All taken.** Volume, SurfaceComplexity and Joints within 1e-12 ([8.2]); `Proto.run(inRankOrder(b)).edge` with P1 blessed alone; the export sorts a copy; A14 → `BitIdentical` (measured); the cap case measured 8.2001; C08's and F3's margins 0.019999999999999574 |
| C7: §5.6's flush plates and C10/C11 rows unasserted; the 30 s gate; the specks; P1 twice; Factors' Limits require; σ's test exists; T-DIF-06 under D2 | **All taken.** The 4 flush plates bit-identical on F5, C02, C05 and C10/C11 ≤ 0.008 (+0.0079), both measured. `--quick` 16.94 s on the snapshot with a budget in [9.4]. The attached speck added. P1 run once under both names. Limits required. `EquipmentTypes.spec` near lines 83–87 already ties σ. T-DIF-06 is moot with the stride and measures E-S2.2's 0.2070 / 0.2056 |
| "Checked and correct": references, constants, fixture sources, the map, the expected numbers | Re-checked here on the snapshot: the v2 prototype's line numbers are unchanged; every constant exists with §16's value; §5.5 and E-S2.9 reproduce in part order |

---

## 15. Measurement index

Every number in this plan, with the design, the method and where it came from. "Quiet" means the machine was otherwise
under about 5 % busy. Every run used Lune 0.8.9 on the snapshot `m2x-r4-base` (copied 2026-11-14 19:45), through
`proto-r2`'s scripts.

| Numbers | Designs | How | Script → output |
|---|---|---|---|
| §5.5's table, part and rank order; the other fixtures' d, tiers, EdgeLength, cutIndex, cleaned lists | the 64 prototype fixtures (F1–F5, C01–C15 with C02s, A25–A27 + base, X01–X07 + variants and bases, P1–P5) | the emulator (`build = true`), the fixture's part order and `Sampling.measureRanked` | `tab.luau` → `tab.txt` |
| E-S2.9's tables, characters | F1–F5, C01–C15 | physics from the snapshot's `Analyze.run`; the rest from the emulator; `diff` against SPEC-evidence's rows | `es29.luau -- part`, `-- rank` → `es29_*.txt` |
| order dependence | C09 (300), P5 (60), 31 other fixtures (100) | permutations by xorshift32 seeds 0x5EED0100 + k; d ranges in part order; distinct outcomes in rank order (factors, d, chains, points, frame) | `orders.luau` → `orders.txt` |
| the two ranks as walking orders | 64 fixtures | `measureRanked` against `ranked` | `vrank.luau` → `vrank.txt` |
| g and d through `Steps` and `Quantize` | 64 fixtures, 192 steps | recomputed from the emulator's x | `gorder.luau` → `gorder.txt` |
| T-DIF-06, T-DIF-04, T-EDG-01, T-DIF-01's caps | [7.5]–[7.6]'s designs | emulator, rank order; T-DIF-04 compares steps and edge to the bit | `contracts.luau` → `contracts.txt` |
| T-DIF-04 on Gen; T-DIF-05's swap | 100 `Gen.validSword` (TestRng 0x5EED0009) × Enclosed, Duplicate, Dust | emulator, rank order, bit comparison | `filler.luau -- 100` → `filler.txt` |
| T-DIF-13 | X01–X07, A25–A27, C10/C11/C01 | emulator, rank order; X06's oracle by planting `ASYM_N_MIN` 120, `ASYM_WORK` 1e9, `N_MAX_AXIS` 400 | `t13.luau` → `t13.txt` |
| T-DIF-07 (a) fixtures | F1, F3, F5, C02, C06 × 6 offsets | emulator, rank order, out-of-hitbox offsets skipped | `translate.luau` → `translate.txt` |
| the edge under Z translation | F1, F3, F5, C02, C06 at Δz 0.01, −0.037 | emulator, rank order, chains compared to the bit | `ztrans.luau` → `ztrans.txt` |
| T-DIF-07 (a) Gen, (b), FINE | 300 Gen (TestRng 0x5EED0007; validSword, segmented, translated per design) | emulator, rank order, stride and `THICK_BUDGET` 1e9 | `gen.luau -- seg 300` → `seg300.txt` |
| E-S2.10's cuts | F5 in 2, 3, 7; C12 vs C02 | the same | `gen.luau -- cuts` → `cuts.txt` |
| mirror images | 19 fixtures + 150 Gen (TestRng 0x5EED0008) | `Blueprint/Mirror.reflect(p, "X")`, rank order | `gen.luau -- mirror 150` → `mirror150.txt` |
| O8's relabelling | F3 (part 6), C08 (part 4) relabelled Guard | emulator, rank order | `o8.luau` → `o8.txt` |
| the sandwich | 9 sandwiches (`limit2.luau`'s hilt) | emulator, rank order, the build's verdict, core kept / hollow / core + sheet | `sandwich.luau` → `sandwich.txt` |
| the sealed cavity, layers, sheets | the r2 verifier's 4 boxes, 7 laminates, 4 sheet stacks | emulator, part and rank order | `sealed.luau` → `sealed.txt` |
| the specks' verdicts and d | P1–P3 + floating / attached | the snapshot's `Analyze.run` with `measureInvalid`; the emulator in rank order | `specks.luau` → `specks.txt` |
| fixture rows, margins, rotations | the 64 fixtures | the snapshot's `Shapes.prepare` AABB; shortest round-tripping decimals | `dump_fixtures.luau` → `fixtures_literals.txt` |
| `H.p1()` and `H.ornate()` against the prototype | P1, C09 | field by field | `p1bits.luau` → `p1bits.txt` |
| T-PERF-01 times and gaps | F5, C02, C05, C09, P1–P5, P1–P3 + specks, `worst_designs.luau`'s 11 + 17 | [8.4]'s method, 15 rounds; M3 = the emulator's `T.edge + T.factors` in rank order; quiet (1.8–2.9 % before, 6.5–13.4 % during with the run's own ≈ 8 %) | `perf.luau -- 15` → `perf15.txt` |
| the verdict's share | F5, C02, C05, C09, P1–P5, the 11 valid worst designs | verdict alone (`SamplingV`), exposure, `Analyze.run`; 15 rounds; quiet (1.6–10.6 % before, no other Lune) | `vshare.luau -- 15` → `vshare.txt` |
| where M3's stretches end | valid 5, 8, 9, F5, P1, C05 | `analyze_gap.luau`'s mark; the caller of each checkpoint; 9 runs | `m3gap.luau` → `m3gap.txt` |
| checkpoints added | F2, F5, C05, C09, P1, P5 | counted at `CHECK_UNITS` 500 | `checks.luau` → `checks.txt` |
| suite times | the snapshot's tests | `lune run tests/run -- --quick`; `lune run tests/run`; quiet | `quick.txt`, `full.txt` |
| **unchecked** (carried from `plan.md`, not re-measured) | option B's sweep and cost ([1] D1); C1's (ii) data point ([14]); T-DIF-08's half-and-mirrored Gen swords ([8.2]) | — | — |
