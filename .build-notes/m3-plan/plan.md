# M3 build plan: Difficulty (SPEC §18, SPEC.md:4409)

Written 2026-11-06 from a read-only survey of `C:\Users\louis\Documents\RANDOM\ROBLOX\Blacksmithing Game`, branch `mvp`
(spec 0935f8c, M0 55fd2ec, M1 4c7e9e7 committed; M2 built and uncommitted). Line numbers are the working tree's on that
day. `src/shared/Physics/Sampling.luau` was last written 2026-11-04 03:39; another team is replacing the Enclosed verdict's
reading inside `Sampling.exposure` (today lines 675–1033: `lineShown`, `flatShown`, `sidePoint`, `hiddenByNear`,
`shownArea`, the verdict loop). This plan uses only the verdict's interface and the `Exposure` fields
(Sampling.luau:139–147). Under the recommended decisions it does not touch the measure block either.

**Revision 2 (same day, after `critique.md`).** Every point of the critique was checked against the sources and re-run
here, one short Lune process at a time (`verify/out_verify.txt`). What changed:

- **D1** now recommends option 0. Option B does not close the sandwich class: on 9 sandwiches it flips 5 step tiers
  where option 0 flips 6.
- **D2's ladder grid is withdrawn.** T-DIF-07's re-segmentation fails on general designs under every probe rule tried,
  mainly through θ's axis rule and Asymmetry's grid. D2 is now the decision on T-DIF-07(b)'s scope.
- **Four test definitions are corrected:** T-EDG-01 items 2 and 6, T-DIF-07(c) and T-DIF-08.
- **Smaller fixes** follow.

§9 lists each critique point and says whether it was taken, qualified or rejected.

M3 row of §18: build `Physics/{Edge, Factors, Difficulty, Analyze}`; fixtures C01, C02, C04–C15, A25–A27, X01–X08, P1–P5
(S2, S8); exit tests T-EDG, T-DIF; S2's §5 table blessed for every fixture (from `Analyze.run`); T-PERF-01; the first
S-PAR-02 digest of `Analyze.run`. Plus §18's rule (SPEC.md:4401): `scripts/verify` green (L0–L2) and the Studio scenario
passing in 3 fresh Play sessions.

Companion files, all in this folder (`...\scratchpad\m3-plan\`):

| File | What |
|---|---|
| `fixtures_literals.txt` | Every prototype fixture this milestone ports (C01–C15 incl. C02 in Steel, A25–A27 and A26's base, X01–X07 with every variant and base, P1–P5) as `P(id, slot, shape, material, pos, rot, size)` rows with the bits this machine's Lune computes. Rotations from trigonometry are pasted literals. Each fixture has a header: part count, smallest side, hitbox margin, the prototype's verdict and cleaned list |
| `proto/` | A patched copy of `docs/spec/prototypes/S2/v2/` used for §7's numbers. `analyze.luau` gains CFG flags `THIN_MERGE`, `VOID_GAP`, `VOID_LATE`, `BODY`, `RECOMPUTE`, `THIN_LADDER` and `opts.forceKept`; runners `m3q.luau`, `m3c09.luau`, `m3ns.luau`, `m3cost.luau`, `m3cost2.luau`, `dump_fixtures.luau`; outputs `out_*.txt` |
| `critic/` | The critique's scripts. `critic_proto.luau -- <section>`: `gen N [d \| safe] [bN]`, `mirror N`, `mirrordiag N`, `lam`, `fixtab`, `sweep`, and `t3:<section>` (τ over 4 axes). `critic_build.luau` (grip-frame order), `margin.luau` (C08) |
| `verify/` | This revision's checks. `v_m3.luau -- cuts \| lam0` (E-S2.10's cuts and C12 vs C02 in rank order; option 0 against option B on 9 sandwiches) and `out_verify.txt`, every re-run quoted in this plan |

Run any of them from the repo root, for example `lune run <abs path>/verify/v_m3.luau -- lam0`.

## 0. Decisions to settle at M3's start

| # | Decision | Recommendation | Where |
|---|---|---|---|
| D1 | §17.2's design question (SPEC.md:4349): a core sandwiched between cheeks that crosses 2 % makes D jump | **Option 0**: cleaned parts stay inert everywhere, and Thinness chords merge gaps ≤ `CONTACT_TOL` as §5.2 says. Document the class in §17.2 with §7's sweep. No M3-side rule examined closes it. Option B cuts the largest jump from 0.32 to 0.12 but flips about as many tiers (5 against 6 on 9 sandwiches), at other proportions. **[Decision to confirm]** B stays a measured alternative. A verdict-side rule is the only complete fix, and it is outside M3 | §7 |
| D2 | T-DIF-07(b), flush re-segmentation, on general designs (`Gen.segmented`). It fails under every probe rule tried (300 designs): θ, the owner's thinnest local axis, moves when a cut piece comes out shorter than the part's thinnest side, and Asymmetry's grid moves with the part count. The stride adds aliasing | **(i)** Keep §5.2's stride, walked in rank order. Assert (b) on E-S2.10's F5 cuts (2, 3 and 7 pieces) and C12 vs C02 (\|Δx\| < 1e-6, \|ΔG\| 0 here). On `Gen.segmented`, assert only the union-only factors and report the rest. Record the measured sensitivity (Thinness \|Δx\| 0.059, \|ΔG\| 0.024) in §5.6 and §17.2. **[Decision to confirm]** (ii) A redesign of θ, the probe grid and Asymmetry's grid is a separate study | §7.5, §5 T-DIF-07 |
| D3 | `CHECK_UNITS` 500 or 250 | Measure first. Expect 250: E-S2.11 already measured median gaps up to 0.37 ms > 0.35 at 500 | §5 T-PERF-01 |
| D4 | SPEC gaps: T-EDG-01, T-DIF-12, T-DIF-13 and X08 are named but not defined | Definitions proposed in §5 and §4.1 | §5, §4.1 |
| D5 | `measureInvalid` and empty work sets (§4.7) | Measure edge and steps for invalid designs. Set `steps = nil` only when an enabled step's work set is empty | §1.5 |
| D6 | The digest golden's file name; P4's 0.01 margin against §14.7's 0.02 | `tests/golden/parity.bv1.digest.txt` through a new `Golden.digest`. Keep P4 bit-identical to the prototype and exempt it | §5 S-PAR-02, §4.2 |

Under D1 and D2 as recommended, no Balance data changes, so the BALANCE fingerprint is not re-blessed. SPEC §4.4 and
§16.10 are not edited. §5.2 changes only the wording of its walking order (:1139, "rank order", §8.3 item 3). M3 does
not touch `Sampling.exposure`.

---

## 1. Module APIs

### 1.1 Layer rules the new modules must keep

- §1.2 (SPEC.md:170): `Physics/  Shapes Gjk Sampling MassProps Edge Factors Difficulty Analyze [S2]`. All four are pure modules
  in `src/shared/Physics/` (Rojo maps them through `src/shared`, so no project edit is needed; `scripts/verify` regenerates
  both sourcemaps).
- §1.3 L1–L3 (SPEC.md:193–201): relative string requires only (`./X`, `../Dir/X`). No `game`, `script`, `task`, services,
  Roblox datatypes or `init.luau`. Line 1 is `--!strict` (T-META-01), the file is pure (T-META-02), and it uses no
  `math.sin…`, `^` or `--!native` (T-META-03, Rules.luau:596–632).
- L2 (SPEC.md:195): lower layers only. Physics may require `Definitions/*`, `Util/Quantize`, `Blueprint/*` (`WorkSet`,
  `Schema`) and other Physics modules. L4 (SPEC.md:205): Physics never requires Crafting; `CraftPlans` is Definitions and
  `WorkSet` is Blueprint, so both are allowed.
- **No cycles** (T-META-07, §14.4 SPEC.md:3482, `tests/Meta/Requires.luau`). The §4.7 types live in `Analyze.luau` today
  (:42–99). `Edge`, `Factors` and `Difficulty` must not require `Analyze`. Define each type in the lowest module that
  produces it and re-export it from `Analyze` under the same names, as M2 does with `MassProps.MassReport`. The require
  graph is then:
  - `Analyze → {Edge, Factors, Difficulty, WorkSet, CraftPlans, MassProps, Sampling, Shapes, Gjk, …}`
  - `Difficulty → {Factors (type only), Steps, Materials, Tiers, CraftPlans, Quantize, Types}`
  - `Factors → {Sampling (VolumeProbes, Exposure, Spend types), MassProps (Ownership type), Shapes, Balance, Limits
    (CONTACT_TOL), Types, Schema}`
  - `Edge → {Sampling (Spend type, ladder), Shapes, Balance, Limits, Types, Schema}`
- T-META-04 (Rules.luau:807): never accumulate floats while iterating a keyed table. The per-selector factor cache is keyed
  and never iterated. MaterialMix must count materials without iterating a keyed set.
- luau-lsp (M1-notes.md:56): annotate locals that hold `DT.FactorId`, `DT.StepId`, `DT.TierId` or `DT.MaterialId` values,
  and pass ids through typed locals, because string literals inside tables are widened to `string`.

### 1.2 `Physics/Edge.luau` (§4.6 SPEC.md:978–999; types §4.7 :1016–1018)

```lua
--!strict
-- Physics/Edge (SPEC §4.6; owner S2): the blade raster, its outline, the sharpenable chains, cutIndex.
export type Vec2 = { number }                                   -- {x, y}, blueprint XY
export type EdgeChain = { points: { Vec2 }, length: number }
export type EdgeProfile = { chains: { EdgeChain }, length: number, cell: number, bladeArea: number,
	bladeMeanThickness: number, gripPoint: Schema.Vec3, gripAxis: Vec2 }   -- difficulty frame (§4.5 :974–976)
export type RasterStats = { cells: number, work: number, loops: number }  -- budgets, for tests

Edge.profile(parts: { Prepared }, byRank: { Prepared }, kept: { boolean }, geometry: DT.GeometryRules,
	gripPoint: Schema.Vec3, gripAxis: Vec2, spend: Sampling.Spend?): (EdgeProfile, RasterStats)
Edge.cutIndex(bladeLength: number, bladeMeanThickness: number): number
	-- clamp((max(bladeLength, 1e-6)/t − CUT_LO)/(CUT_HI − CUT_LO), 0, 1); 0 when t = 0 (§4.6 :995–996)
Edge.simplify(xs: { number }, ys: { number }, tol: number): { number }   -- Douglas–Peucker, kept indices (tests)
Edge.mergedLength(ivs: { number }, n: number, tol: number): number
	-- tests only: sorts a copy of ivs (P-NOMUT, §14.5); profile's own loop sorts a reused scratch array in place
```

- **Rows (SPEC).** §4.6 steps 1–5:
  - The cell starts at `EDGE_CELL` and is coarsened by `H_LADDER` until cells ≤ `EDGE_MAX_CELLS` and cell × part
    work ≤ `EDGE_MAX_WORK`, counting kept parts only (the last rung if none fits). x is anchored at 0; y is anchored
    at the lowest kept striking-slot point.
  - A cell is covered iff its centre's Z line passes within `RASTER_TOL` of a kept striking part. Thickness is the
    merged chord length (tolerance `CONTACT_TOL`). `hilt` is a dilated chord through a kept non-striking part.
  - Crack edges have the covered cell on the left and are traced 8-connected; only outer (CCW) loops count.
    Eligibility: not buried and thickness ≤ `EDGE_MAX_THICK`. A fully eligible loop opens at its lowest vertex.
  - Douglas–Peucker runs at `EDGE_SIMPLIFY` × cell, doubled until ≤ `EDGE_MAX_POINTS`. Pommel-facing segments
    (`n·A < −EDGE_DOWN_COS`) are dropped, gaps < `EDGE_GAP_BRIDGE` cells are bridged, and chains < `EDGE_MIN_CHAIN`
    cells are dropped.
  - Chains are sorted by length; `length` is the main chain's.
- **Mirror images are not exact.** A design's X mirror image has the mirrored raster, but its CCW outline runs the other
  way along the mirrored edges. The loop opens at its lowest-then-leftmost vertex, and Douglas–Peucker keeps the first
  maximum, so the simplified chain can differ. On Gen #31 (seed 0x5EED0008), EdgeLength is 6.935592 over 11 points and
  6.915188 over 9 for its mirror image, with the same bladeArea and mean thickness (`verify/out_verify.txt`). Keep the
  prototype's rule, which E-S2.9 and T-EDG-01 item 2 compare against bit for bit. T-EDG-01 item 6 asserts what does hold.
- **`gripPoint` and `gripAxis`** come from `MassProps.difficultyFrame` over the kept Grip parts **in rank order** (§1.5);
  the axis is `{0, 1}`. In blueprint order, 6 of the 24 orders of C09's 4 Grip parts move the point's last bit
  (`critic_build.luau`). M4's `PrecisionTrace.sidesFromChains` receives the same pair.
- No kept striking part (only reachable with `measureInvalid`) gives `{chains = {}, length = 0, cell = 0, bladeArea = 0,
  bladeMeanThickness = 0}` plus the frame.
- Iterate the blade and hilt lists in rank order (`byRank` from `Sampling.ranked`), as §17.2 SPEC.md:4347 requires of every
  M3 walk.
- **Checkpoint charges**, one unit per shape query:
  - per cell, `1 + #rowBlade + #rowHilt`;
  - per crack row, `NI`;
  - per traced edge, `1`;
  - Douglas–Peucker per split (`b − a` points). The prototype charged it once per run (`tick(4 * #run)`,
    v2/analyze.luau:567); a long run's DP is O(n²) and would otherwise be an uncheckpointed gap.

### 1.3 `Physics/Factors.luau` (§5.2 SPEC.md:1123–1168, refs §5.3 :1179–1189)

```lua
export type FactorValue = { factor: DT.FactorId, raw: number, x: number }
export type FactorBudget = { thinStride: number, thinProbes: number, asymSpacing: number, asymWork: number }
export type FactorContext = {
	parts: { Prepared },              -- blueprint order
	rank: { number },                 -- Sampling.ranked: rank per part index (1 = highest)
	kept: { boolean },
	probes: Sampling.VolumeProbes,    -- phase 5: byPart[p] samples at spacing h (Sampling.luau:112–116)
	exposure: Sampling.Exposure,      -- exposedKept[p], contact[p][q]   (Sampling.luau:139–147)
	owned: MassProps.Ownership,       -- ownedVolume[p], higher[p]       (MassProps.luau:57–66)
	touching: { { boolean } },        -- Analyze's contact graph (Analyze.luau:174–178, :265)
	edgeLength: number,               -- EdgeProfile.length
	geometry: DT.GeometryRules,       -- refs, strikingSlot, thicknessAxis
	axis: Vec2,                       -- difficulty axis {0, 1}
}
Factors.ORDER: { DT.FactorId }        -- FactorId order (Types.luau:22–23); a test ties it to Validate.FACTOR_ORDER and refs
Factors.measure(ctx: FactorContext, set: { number }, spend: Sampling.Spend?): ({ FactorValue }, FactorBudget)
	-- set = WorkSet.select(...) (ascending indices); measure copies it and sorts it by rank before every walk
-- exported for tests: norm, cbrt, unionChord, thinAxis, thinness, asymmetry
```

| Factor | raw (SPEC §5.2) | x | Inputs |
|---|---|---|---|
| PartCount | Σ min(1, V_p/`V_PART_FULL`), V_p = `Prepared.volume` | norm(n, refs) | parts |
| Thinness | (Σw·φ²/Σw·φ)·min(1, Σ_{φ>0}w / (`THIN_SHARE_MIN`·Σ_{W∩striking}w)), with Σ_W w if no striking part | = raw | §1.3.1 |
| Asymmetry | 1 − Σw·c/Σw | norm(raw, 0, 0.6) | §1.3.2 |
| SurfaceComplexity | r = A/(6·cbrt(V)²), A = Σ `exposure.exposedKept[p]`, V = Σ `owned.ownedVolume[p]`; 0 if V ≤ 0 | norm(r, 2.3, 2.9) | exposure, owned |
| EdgeLength | `ctx.edgeLength` (the same on every set) | norm(E, 4.8, 8.0) | edge |
| Joints | Σ over pairs i<j in rank order with `touching[i][j]`: min(s_i, s_j)·(1 + `JOINT_BOOST`·clamp01(1 − a_ij/`A_JOINT_REF`)), a_ij = (contact[i][j] + contact[j][i])/2, s = min(1, V/`V_PART_FULL`) | norm(J, 3, 24) | touching, exposure.contact |
| MaterialMix | distinct materials in the set, counted by walking `Materials.ordered` and testing membership on the set array | norm(k, 1, 4) | parts |
| Volume | Σ `owned.ownedVolume[p]` | norm(V, 0.08, 0.80) | owned |

`lo` and `hi` come from `geometry.refs` in FactorId order (EquipmentTypes.luau:40–49). Thinness's σ range comes from
`Balance.Difficulty.SIGMA_LO/HI`; `tests/Definitions/EquipmentTypes.spec.luau:83–87` already asserts the refs row equals
it. Every Σ walks parts in rank order and samples in sample order.

#### 1.3.1 Thinness (§5.2 SPEC.md:1136–1151)

- **L** = extent of the set along `ctx.axis`: min and max of `Shapes.extentAlong(p, 0, 1, 0)` (Shapes.luau:442–446).
- **Probes, as specified** (SPEC.md:1139; rank order per §17.2 :4347):
  - Walk the set's parts in rank order, and each part's phase-5 samples `ctx.probes.byPart[p.index]` in sample order.
  - n_W = Σ n over the set (kept parts only; phase 5 samples kept parts only, Sampling.luau:220–247).
    k = max(1, ceil(n_W / `THICK_BUDGET`)).
  - A running counter takes samples 1, 1 + k, 1 + 2k, … This is the prototype's `(idx − 1) % stride == 0`
    (v2/analyze.luau:1391) without `%`.
  - At most ceil(n_W/k) ≤ `THICK_BUDGET` probes are taken, so the P1 budget row's "probes ≤ THICK_BUDGET" holds.
  - `budget.hVol` and `volSamples` keep their meaning: Thinness strides over those samples.
- **Owned test.** A probe counts only if it is not strictly inside any part of `owned.higher[p]` (`sd < −1e-9`,
  `Sampling.INSIDE_MARGIN`). The prototype's `ownedAt`, v2/analyze.luau:1210–1224, does the same.
- **Round parts.** A Ball probe moves to the ball's centre. A Cylinder probe moves to its projection on the axis.
- **θ, the owner's thinnest local axis:** Ball X; Cylinder X if hx ≤ r, else local Y; polyhedra the smallest half extent,
  ties X < Y < Z (v2/analyze.luau:1373–1388). θ belongs to the piece, so cutting a part can change it (§7.5).
- **τ** = min(unionChord(set, s, Z), unionChord(set, s, θ)). Z is `geometry.thicknessAxis` = {0,0,1}. The union chord is
  grown from [0, 0], merging gaps ≤ `Limits.CONTACT_TOL`.
- **φ** = norm(L/max(τ, 1e-6), `SIGMA_LO`, `SIGMA_HI`). The share term's striking metal is the parts of
  `geometry.strikingSlot`.
- **Charges:** `2·#set` per probe.

#### 1.3.2 Asymmetry (§5.2 SPEC.md:1153–1165; v2/analyze.luau:1424–1502)

- `axisMins(p)` gives `ASYM_N_MIN` on local axes with |axis·X| ≥ `ASYM_AXIS_X`, else `N_MIN_AXIS`.
- Reach is `ASYM_TOL + ASYM_RAMP`. Mirror candidates of p are the set's parts whose AABB meets p's mirrored AABB widened by
  the reach. Higher candidates are `owned.higher[p]` ∩ set.
- **Spacing:** the first `H_VOL`·k with Σ min(a·b·c, `N_MAX_PART`)·(1 + #mc + #hc) ≤ `ASYM_WORK`. The candidate counts
  enter the estimate, so re-cutting a part can move every part's grid (§7.5).
- **Samples:** `Sampling.volumeSamples(p, hA, spend, mx, my, mz)`; the min-per-axis arguments exist for this.
- **Coverage.** For each owned sample, d = min over the mirror candidates of `sd(q, −x, y, z)`, breaking early once
  d ≤ `ASYM_TOL`, and c = clamp01((reach − d)/`ASYM_RAMP`).
- **Charges:** `1 + #mc + #hc` per sample.

#### 1.3.3 `cbrt` and `norm`

- `cbrt` is a verbatim port of v2/num.luau:37–63: power-of-8 range reduction by while loops, 8 Newton steps from 1.5,
  then ×2 or ÷2 k times (§4.1 SPEC.md:828–829).
- `norm(v, lo, hi)` = clamp((v − lo)/(hi − lo), 0, 1).
- Both are new: nothing in `src/` has them today.

### 1.4 `Physics/Difficulty.luau` (§5.1 :1106–1121, §5.3 :1170–1194, §5.4 :1196–1208)

```lua
export type StepAnalysis = { step: DT.StepId, g: number, m: number, d: number, tierRaw: DT.TierId, tier: DT.TierId,
	material: DT.MaterialId, terms: { { factor: DT.FactorId, w: number, x: number } }, factors: { Factors.FactorValue } }
Difficulty.q(x: number): number                       -- Util/Quantize.q(x, Quantize.SCALAR_SCALE) (Quantize.luau:26)
Difficulty.softOr(m: number, g: number): number       -- q(1 − (1 − m)(1 − g))
Difficulty.governing(parts: { Prepared }, set: { number }): DT.MaterialId?
	-- the set's material with the highest (difficultyTerm, hardness), ties by Materials order; nil for an empty set
Difficulty.planSteps(typeId: DT.EquipmentTypeId): { CraftPlans.PlanStepDef }   -- CraftPlans.get(type).steps, enabled, in order
Difficulty.step(stepId: DT.StepId, factors: { Factors.FactorValue }, material: DT.MaterialId): StepAnalysis
```

`step()`:

- Weights are `Steps.get(stepId).factorWeights`, stored in FactorId order (Steps.luau:60–64: Sharpening is As .30, SC .20,
  EL .50). g = q(Σ w·x) summed in that order.
- m = q(`Materials.get(material).difficultyTerm`), 0 for Iron and Steel (Materials.luau:31, :48). d = softOr(m, g).
- `tierRaw = Tiers.tierRawFor(d)` and `tier = Tiers.tierFor(d)` (Tiers.luau:92–114). Both error on NaN or on D outside
  [0, 1].
- `terms` = `{factor, w, x}` in the weights' order. `factors` = all 8, copied.
- **Comparing with the prototype** (parts in rank order, as Reference.spec does):
  - PartCount, Thinness, Asymmetry, EdgeLength and MaterialMix: bit for bit.
  - Volume, SurfaceComplexity and Joints: within Reference.spec's `ABS` 1e-12. The build's owned volumes differ from the
    prototype's by up to about 4e-15 (MassProps.luau:13–18).
  - g and d: equal, except that the prototype summed Sharpening as EL, As, SC (v2/analyze.luau:109, :1532–1535), so g
    can round across a q step (±1e-4).

### 1.5 What `Analyze.run` gains (Analyze.luau:327–440; plug-in spot :427–430)

After phase 5 (`volumeProbes`, :423–425):

```
local rank, byRank = Sampling.ranked(parts)                           -- once; cheap
local keptByRank = table.create(N)                                    -- kept, indexed like byRank
for r = 1, N do keptByRank[r] = kept[byRank[r].index] end
-- 6 difficulty frame (kept Grip parts, rank order) and EDGE
local dPoint, dAxis = MassProps.difficultyFrame(byRank, keptByRank, geometry.gripSlot)
local edge, raster = Edge.profile(parts, byRank, kept, geometry, dPoint, dAxis, spend)
physics.edgeLength = edge.length
physics.cutIndex   = Edge.cutIndex(physics.bladeLength, edge.bladeMeanThickness)
budget.edgeCell    = edge.cell
phase()
-- 7 FACTORS per distinct work set, STEPS in CraftPlans order (enabled only)
ctx = {parts, rank, kept, probes, exposure, owned, touching = graph.touching, edgeLength = edge.length, geometry, axis = dAxis}
for each planStep in Difficulty.planSteps(core.type):
	set = WorkSet.select(core.parts, kept, planStep.worksOn)          -- WorkSet.luau:16–37
	if #set == 0 then steps = nil; break end                          -- only under measureInvalid (V5 otherwise, §3.7 :703)
	key = "All" or table.concat(slots, "+")                           -- keyed cache, never iterated
	factors = cache[key] or Factors.measure(ctx, set, spend), then phase()
	steps[#steps+1] = Difficulty.step(planStep.step, factors, Difficulty.governing(parts, set))
return {…, edge = edge, steps = steps, budget = budget}
```

- **The frame in rank order** needs no MassProps edit. `difficultyFrame` (MassProps.luau:529–538) iterates the list it
  is given, so it gets `byRank` with a `kept` array indexed the same way. `physicsFrame` and `MassProps.report` still sum
  in blueprint order, as M2 wrote them. Physics is therefore compared within 1e-12, not bit for bit, when parts reorder
  (T-DIF-07(c)).
- **Types.** `Analysis`, `PhysicsReport`, `AnalysisBudget` and `AnalyzeOptions` keep their shapes (§4.7 SPEC.md:1003–1031).
  `EdgeChain`, `EdgeProfile`, `FactorValue` and `StepAnalysis` become re-exports. `budget` stays exactly the five §4.7
  fields; the Thinness stride and the Asymmetry spacing come back through `Factors.measure`'s second value, for tests.
- **`measureInvalid` (D5).** Quick-stage errors still stop before measurement (Analyze.luau:357–367). Full-stage errors
  with `measureInvalid` get physics as today, plus edge (empty if no kept striking part) and steps. Steps are nil when an
  enabled step's work set is empty. Write this into §4.7's comment (SPEC.md:1027 says only "nil while invalid").
- **Checkpoints.** Add `phase()` after the edge and after each work set's factors. The phase count for F2 rises from 5
  (Analyze.spec.luau:692–720 asserts 5) to 8: edge plus the two sets All and {Blade}.
- **Header comment.** Rewrite step 6 of Analyze.luau:16–18 ("arrive with M3") and the phase-6 comment at :427–430.

---

## 2. Prototype → build map

The reference is `docs/spec/prototypes/S2/v2/` (§4.1 SPEC.md:833–837). The v1 files (`S2/analyze.luau`, `swords.luau`,
`out_final.txt`) are history, superseded by v2 (SPEC-evidence.md:174–179); nothing in them is ported. The §5.5 and
E-S2.9 numbers come from `docs/spec/prototypes/S2/verdict/analyze_build.luau`, which emulates M3: the prototype's edge and
factors on M2's kept row, areas and ownership, with probes in part order. M3 walks in rank order (§17.2 SPEC.md:4347).

| Prototype (`v2/…`) | Build | What changes on the way |
|---|---|---|
| `analyze.luau:20–124` CFG | `Balance.Geometry`, `Balance.Difficulty`, `Limits.CONTACT_TOL`, `EquipmentTypes.Sword.geometry` (refs, slots, thicknessAxis), `Steps.factorWeights`, `CraftPlans.Sword`, `Materials`, `Tiers` | no literal in Physics; refs in FactorId order; tiers from the catalog (enabled prefix) |
| `num.luau:17` clamp01, `:26` norm | `Factors.norm` (local clamp01) | same arithmetic |
| `num.luau:31` q4 | `Difficulty.q` → `Util/Quantize.q(x, 10000)` | same `math.round`; errors on non-finite and on \|n\| ≥ 2^51 (M1-notes.md:61) |
| `num.luau:37` cbrt | `Factors.cbrt` | verbatim |
| `analyze.luau:185` mergedLength | `Edge` local + `Edge.mergedLength` (tests) | the local sorts a reused scratch array in place; the export sorts a copy; same sums |
| `:211` slab, `:224` lineHitsAabb | `Factors` locals | same |
| `:238` unionChordAt | `Factors.unionChord` | list in rank order; `used` from `table.create`; tolerance `CONTACT_TOL` |
| `:272` simplify | `Edge.simplify` | same tie rule (`d > best` keeps the first maximum); charge per split |
| `:316` gripFrame | `MassProps.gripFrame` / `difficultyFrame` (M2) | done; M3 calls `difficultyFrame` on `byRank` |
| `:403–723` edgeProfile | `Edge.profile` | see "No `%` or `//`" below |
| `:1274–1287` difficulty frame, edge call | `Analyze.run` phase 6 | `DIFF_FRAME = "Fixed"` (axis {0,1}) is M2's `difficultyFrame` |
| `:1288–1293` cutIndex, edgeLength | `Edge.cutIndex` + `Analyze.run` | the guard `max(bladeLength, 1e-6)` is kept as a named numeric guard |
| `:1300–1318` workSet | `Blueprint/WorkSet.select` (M2) | ascending indices; `Factors` re-sorts by rank |
| `:1325–1336` Volume, PartCount, MaterialMix | `Factors.measure` | V from `owned.ownedVolume`; s from `p.volume`; MaterialMix without the keyed `mats` set |
| `:1337–1343` SurfaceComplexity | `Factors.measure` | A = Σ `exposure.exposedKept` (M2's measure, kept parts only) |
| `:1344–1345` EdgeLength | `Factors.measure` | = `edge.length` |
| `:1346–1357` Joints | `Factors.measure` | `conn` → `graph.touching`; `contact` → `exposure.contact`; pairs in rank order |
| `:1358–1423` Thinness | `Factors.thinness` | rank order; phase 5's samples (`ctx.probes`); the `(idx − 1) % stride` stride (:1391) becomes a running counter; `ownedAt` → test against `owned.higher` |
| `:1424–1502` Asymmetry | `Factors.asymmetry` | rank order; otherwise the same |
| `:1503–1510` normalization | `Factors.measure` | refs from geometry |
| `:1513–1529` keyOf, cache | `Analyze.run` | the same keys |
| `:1530–1536` g | `Difficulty.step` | weight order from `Steps` (FactorId order) |
| `:1537–1550` governing | `Difficulty.governing` | `Materials.ordered`; nil on an empty set |
| `:1551–1552` m, d | `Difficulty.step`, `softOr` | `Quantize.q` |
| `:1553–1561` tiers | `Tiers.tierFor/tierRawFor` | as is |
| `:1562–1569` factors, terms | `StepAnalysis` | `{factor, raw, x}` and `{factor, w, x}` |
| `:728–744` tick/phase | `spend`/`phase` (Analyze.luau:333–347) | charges as in §1.2–1.3 |
| `shapes.luau:230` chord, `:345` extentAlong, `:456` volumeSamples | `Shapes.chord` (Shapes.luau:390), `Shapes.extentAlong` (:442), `Sampling.volumeSamples` (Sampling.luau:178) | identical code (checked) |

**No `%` or `//` in `Edge.profile`** (prototype :403–723):

- Store each crack edge's integer endpoints (fi, fj, ti, tj) instead of `vx(v) = (i0 + (v−1) % VI)·H` and
  `vy(v) = … (v−1) // VI` (:559–564).
- Find the right turn with a lookup, `RIGHT = {3, 0, 1, 2}` for dir 0..3, instead of `(eDir+3) % 4` (:642).
- Use cyclic indices `k = bk + s; if k > m then k −= m end` instead of `% m` (:683, :689).
- Build the vertex maps `outA`/`outB` as `table.create` arrays with 0 = none.
- Compare the lowest vertex on (y, x) rather than `y·1e6 + x` (:676).
- Sort chains with a total order: length desc, first x, first y, then emission index (:707–715).

**Determinism (§4.1 SPEC.md:826–832), for every new line:**

- Only `+ − × ÷`, `math.sqrt/floor/ceil/abs/min/max` and comparisons; `math.round` only inside `Util/Quantize`.
- No `^` (T-META-03 enforces it). No `%` or `//`: Rules.luau does not check them today, so review for them, or add both
  tokens to `Rules.transcendental` for the authoritative folders.
- No trigonometry, `exp`/`log` or `math.random`. No `--!native`.
- Numeric `for` and `ipairs` over arrays; no `pairs` or `next`.
- Fixed summation order: rank order, then sample order. Sorts use total orders.
- Every Balance and refs value is read from Definitions; no literal tunables in Physics.
- q is applied at production (§5.1 :1117) to g, m and d only. Raw factors, physics and edge stay unquantized (§4.7 :1035).

---

## 3. Constants M3 uses

Every Balance constant M3 reads already exists. The only new rows are four test constants.

| Constant | Value | Lives in | §16 row | In repo |
|---|---|---|---|---|
| `EDGE_CELL`, `RASTER_TOL` | 0.02, 0.005 | `Balance.Geometry` (Balance.luau:84–85) | §16.10 SPEC.md:3873 | yes |
| `EDGE_MAX_CELLS`, `EDGE_MAX_WORK` | 12000, 30000 | `Balance.Geometry` | :3874 | yes |
| `EDGE_MAX_THICK`, `EDGE_DOWN_COS` | 0.25, 0.5 | `Balance.Geometry` | :3875 | yes |
| `EDGE_SIMPLIFY`, `EDGE_GAP_BRIDGE`, `EDGE_MIN_CHAIN` | 1, 3, 3 (× cell) | `Balance.Geometry` | :3876 | yes |
| `EDGE_MAX_POINTS` | 256 | `Balance.Geometry` | :3877 | yes |
| `CUT_LO`, `CUT_HI` | 10, 60 | `Balance.Geometry` (:94–95) | :3878 | yes |
| `H_LADDER` | {1, 1.25, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10, 12, 16} | `Balance.Geometry` | :3869 | yes |
| `H_VOL`, `N_MIN_AXIS`, `N_MAX_AXIS`, `N_MAX_PART` | 0.05, 2, 48, 3000 | `Balance.Geometry` | :3861 | yes |
| `CONTACT_TOL` | 0.01 | `Limits` | §16.2 :3759 | yes |
| `V_PART_FULL` | 0.004 | `Balance.Difficulty` (Balance.luau:115–128) | §16.10 :3884 | yes |
| `JOINT_BOOST`, `A_JOINT_REF` | 1.0, 0.05 | `Balance.Difficulty` | :3885 | yes |
| `THICK_BUDGET` | 400 | `Balance.Difficulty` (:119) | :3886 (unchanged) | yes |
| `SIGMA_LO`, `SIGMA_HI` | 45, 130 | `Balance.Difficulty` | :3887 (also refs Thinness :3807) | yes |
| `THIN_SHARE_MIN` | 0.25 | `Balance.Difficulty` | :3888 | yes |
| `ASYM_TOL`, `ASYM_RAMP` | 0.02, 0.03 | `Balance.Difficulty` | :3889 | yes |
| `ASYM_N_MIN`, `ASYM_AXIS_X`, `ASYM_WORK` | 10, 0.6, 30000 | `Balance.Difficulty` (:127) | :3890 | yes |
| refs (8, FactorId order) | PC 3–16, Th 45–130, As 0–0.6, SC 2.3–2.9, EL 4.8–8.0, Jo 3–24, MM 1–4, Vo 0.08–0.80 | `EquipmentTypes.Sword.geometry.refs` (:40–49) | §16.5 :3806–3811 | yes |
| `strikingSlot`, `gripSlot`, `thicknessAxis` | Blade, Grip, {0,0,1} | `EquipmentTypes.Sword.geometry` (:35–39) | :3803–3804 | yes |
| factor weights | Sm Vo 1.00; Ha Th .40 As .30 SC .30; Sh As .30 SC .20 EL .50 (stored in FactorId order) | `Steps` (:19, :37, :60) | §16.6 :3819–3821 | yes |
| plan | Smelting "All", Hammering "All", Sharpening {Blade} | `CraftPlans.Sword` (:29–38) | §16.11 :3930 | yes |
| tier `dMin`, `enabled` | 0, 0.2, 0.4, 0.6, 0.8; Normal and Hard enabled | `Tiers` | §16.7 :3830 | yes |
| `difficultyTerm`, `hardness`, `order` | Iron 0/45/1, Steel 0/70/2 | `Materials` | §16.4 :3792, §2.5 | yes |
| `SCALAR_SCALE` | 10000 | `Util/Quantize` (:23) | §16.17 :4110 | yes |
| `CHECK_UNITS` | 500, or 250 after T-PERF-01 (D3) | `Analyze.luau:106` (local) | §16.18 :4116 | yes; edit with D3 |
| `UNITS_PER_*` | 4, 250, 20, 20, 40 | locals in Sampling, MassProps, Analyze | §16.18 :4117 | yes; M3 charges one unit per shape query |
| numeric guards | `INSIDE_MARGIN` 1e-9 (reused); new: τ floor 1e-6, bladeLength floor 1e-6, DP `ll > 1e-24` | locals | §16.18 :4118 | add the new ones to the row |
| `TOL_FACTOR_ABS`, `TOL_G_INVARIANT`, `TOL_DUST_G`, `TOL_ASYM_ZERO`, `STARTER_MARGIN` | 0.02, 0.002, 0.005, 0.02, 0.05 | `tests/lib/Tol.luau` | §16.32 :4272–4278 | yes |
| `ANALYSIS_LUNE_MAX_MS`, `CHECKPOINT_GAP_LUNE_MS` | 60, 0.35 | `tests/lib/Tol.luau` | :4290–4291 | yes |
| `FUZZ_N_VALID`, `PROP_N`, `CASE_BUDGET_MS` | 500, 200, 2000 | `tests/lib/Tol.luau` | :4262–4267 | yes |
| **`TOL_EDGE_REL`** | 0.02 (E-S8.4's X04 bound: strips, seams, mirror images) | `tests/lib/Tol.luau` (new) | §16.32 (new row) | no |
| **`PERF_RUNS`** | 15 (median rule) | `tests/lib/Tol.luau` (new) | §16.32 (new row) | no |
| **`PARITY_DESIGNS`, `PARITY_SEED`** | 200, 0x5EED0002 | `tests/lib/Tol.luau` (new) | §16.32 (new rows) | no |

**Fingerprint.** No Manifest data changes under D1 option 0 and D2 (i), so `balance_fingerprint.golden.txt` stays as it
is. `CHECK_UNITS` is not Balance. Only option B would add Balance data (`VOID_GAP` in `Balance.Geometry`, hashed per
§2.8 SPEC.md:487–494). If Louis picks B:

1. Edit `Balance.luau`, `Balance.spec.luau`'s `GEOMETRY` table and §16.10.
2. Delete `tests/golden/balance_fingerprint.golden.txt`.
3. Run `lune run tests/run -- --bless` from the repo root.
4. Review `git diff tests/golden`: only `bytes` and `fnv1a32` may change; `version = 1` stays.
5. Commit the golden with the data change. The M1 notes did the same at M1-notes.md:94.

---

## 4. Fixtures

### 4.1 Where each fixture is defined, and what is missing

| Fixtures | Prototype source | Notes |
|---|---|---|
| C01–C15 | `v2/fixtures.luau`: `minimal` :118, `arming` :106 (C02, Iron and Steel), `rapier` :127, `cleaver` :139, `sabre` :150, `dagger` :227, `greatsword` :238, `ornate` :203, `gamey(true/false)` :176 (C10/C11), `armingSegmented` :249, `armingMirrored` :264, `transform` :61 (C14 translate, C15 4° about Z at (0, 0.88, 0)); list order in `calibration()` :280–299 | trigonometry via `Quat.axisAngle` and `quatFromMatrix`: paste the literals (`fixtures_literals.txt`) |
| A25–A27 | `adversarial()` :337–366 (A26 has its own base, "F1 ring grip") | bounds 0.01 / 0.02 / Sharpening 0.02 (E-S2.7 SPEC-evidence.md:244–248) |
| X01–X07 | `regression()` :387–499 via `withBlade` :374 (F5 base; X01/X02 against union blades 0.066 / 0.072; X03 on F4) | pure arithmetic, so a fixture module may also build them from F5 as the prototype does |
| P1–P5 | `perf()` :585–631 (`PERF_SLOTS` :583) | P2–P4 positions use `math.sin(i)`: paste |
| "+ a Dust speck", floating | `verdict/lines/d_cost.luau:28–36`: the 24th part replaced by a 0.05 Block at (0.7, 0.2, 0.2) in that part's slot | the speck floats, so the design is `Disconnected` and runs with `measureInvalid = true`. Kept for comparability with E-S2.11's timings |
| "+ a Dust speck", attached (new) | the same replacement, with the 0.05 Block placed touching a kept part | the production path: valid, the speck cleaned as Dust, no `measureInvalid`. A Save measures only valid designs (SPEC.md:862), and §11.13's preview call does not pass `measureInvalid`, although :863 allows it (§8.3 item 16) |
| worst designs | `verdict/worst_P.json` (11 designs, canonical and valid per Analyze.spec.luau:892–900) | docs/ is not a Rojo root: convert to `tests/fixtures/WorstP.luau` so Studio (S-PERF-01) can read it |
| **X08** | **nowhere.** E-S8.4 SPEC-evidence.md:1784 names only "24 rotated cylinders; 24 hitbox-sized blocks; sawtooth blade; 256-point zigzag edge (R3-07, R3-08)". R3's scripts are not in the repo | **Proposal (D4):** X08a = P2 (24 rotated cylinders), X08b = P1 (the pre-cut P1 was "24 overlapping hitbox-sized blocks", `v2/out_v2_perf_before.txt:25`), X08c = P5 (sawtooth comb). The 256-point zigzag is an `EdgeChain` for M4's T-PERF-02 (`S3/v2/Blades.luau:104–111`), not a blueprint. Record the aliases in E-S8.4 |

### 4.2 How they become `tests/fixtures` records

`tests/fixtures` is a Rojo root (`ReplicatedStorage.BlacksmithTests.fixtures`, test.project.json:11). Its modules require
only `./Build` and `./Blueprints`. They use exact arithmetic and pasted literals; they never recompute trigonometry
(Build.luau:4–6).

- **New modules:**
  - `Calibration.luau`: C01, C02, C02s (Steel), C04…C15.
  - `Regression.luau`: X01…X07 with every variant and the union bases.
  - `Cost.luau`: P1–P5, P1/P2/P3 + a floating and an attached speck, the X08 aliases, and the T-PERF-01 case list
    `Cost.TPERF` that S-PERF-01 reuses.
  - `WorstP.luau`: generated once from the JSON; a FixtureSet test checks it equals the JSON bit for bit.
  - `Parity.luau`: the ordered S-PAR-02 design list.
- **A25–A27** are added to `Adversarial.luau` as cases in its existing shape (Adversarial.luau:28–70), A26's base as a
  variant. Extend the `analysis.relation` type with `d = "Within"` plus `bound` and `steps` fields.
- **A14's expectation** changes from `d = "NonIncreasing", gTol = "TOL_DUST_G"` (Adversarial.luau:576) to
  `d = "BitIdentical"` (no `mass`, since Dust counts for mass), with a note: the build measures kept parts only, and Dust
  sits outside every kept-first budget, phase 5's included (Sampling.luau:220–247). Update the relation type's comment
  (:42).
- **Record shape.** As `Blueprints.Fixture` (Blueprints.luau:34–54): `{id, label, what, core, expect}`, with `expect = {canon
  = {ok = true, equals = "draft"}, validation = {valid}, tiers, tierRaw (§5.5), cleaned, save = "Valid"}`. Calibration
  fixtures have no E-S8.3 oracle, so make `oracle` optional.
- **Rows.** `Build.part(id, slot, shape, material, pos, rot, size)` with ids 1..n in the prototype's list order (its `bp`
  numbers them so). Named rotations: `Build.I`, `Z45`, `Z90`, `Y90`, and a new `Build.YM90 = {0, −R, 0, R}`, the
  prototype's `RY_M90` and the tips' rotation. The dump shows `axisAngle(0,0,1,90)` equals `Z90` bit for bit. Every other
  rotation and every trigonometric position is the dump's literal.
- **Replace the trig-built helpers.**
  - `PhysicsHelpers.p1` (PhysicsHelpers.luau:315–325) becomes `Cost.core("P1")`.
  - `PhysicsHelpers.ornate` (:329–360) becomes `Calibration.core("C09")`.
  - Callers: Analyze.spec :658 :685 :688 :737 :765 :790; MassProps.spec :940; Sampling.spec :147 :546 :605 :620
    :639 :691 :697 :710 :711 :743; Verdict.spec :80 :82 :103 :158.
  - `H.axisAngle` normalizes and the prototype does not, so the literal P1 is the prototype's bits; any test that pins
    P1 numbers must use it.

**Checks** (`tests/FixtureSet/{Calibration, Regression, Cost}.spec.luau`, in the style of Blueprints.spec.luau:52–170):

- **Canonical fixed point.** `Canonical.draft(core)` is ok and returns `core` bit for bit (as FixtureSet/Canonical.spec
  :30 does for F1–F5).
- **Margins.** Every part is ≥ 0.02 inside the hitbox (§14.7 SPEC.md:3527–3528), asserted as Blueprints.spec.luau:79
  does, `margin >= 0.02 - 1e-12`.
  - C08 needs that tolerance: its margin is 0.019999999999999574 in doubles (`critic/margin.luau`).
  - **P4 is at 0.01** (balls of d 0.58 against z ±0.3). Keep it bit-identical to the prototype and exempt it with a
    note (D6).
- **Structure.** Ids, slots within maxima, sizes in [MIN_DIM, MAX_DIM], every Ball and Cylinder in canonical size.
- **Port check, Lune only.** Equal to `docs/spec/prototypes/S2/v2/fixtures` bit for bit (id, slot, shape, material, pos,
  rot, size), through `(require :: any)` as Reference.spec.luau:26–29 does. This replaces Reference.spec :308–321.
- **Validity.** `Analyze.run` is valid for every C, F, A25–A27, X and P fixture, every attached-speck variant and every
  `WorstP` design. The prototype finds all of these valid (dump headers); Reference.spec already agrees on calibration,
  golden and perf. The floating-speck variants are `Disconnected`.
- **Cleaned lists.**
  - C10/C11: Enclosed #21 #22 and Dust #23 #24. A25: Enclosed #6.
  - X01/X02: as Reference.spec :213–220 asserts.
  - P1: pinned in Reference.spec :40–53; it may change with the verdict replacement.
  - Each attached speck: Dust.

### 4.3 Expected numbers

d per step (Smelting / Hammering / Sharpening). Tiers and tierRaw are §5.5's (SPEC.md:1216–1232), unchanged in every
row.

The expected column is the prototype on rank-ordered parts with §5.2's stride (`proto/out_fix.txt`,
`out_final_late.txt`; reproduced by the critique's `fixtab`). That is what M3 produces under D1 option 0 and D2 (i),
given that the build's measure equals the prototype's when nothing near a part is cleaned (Reference.spec). Only C09
moves against §5.5.

| Fixture | §5.5 | expected (rank order, stride) | tiers (raw) |
|---|---|---|---|
| F1 = F5 | 0.0288 / 0.1037 / 0.0989 | same | N N N |
| F2 | 0.0797 / 0.0176 / 0.0282 | same | N N N |
| F3 | 0.0000 / 0.4423 / 0.6104 | same | N H(Ex) H(Ma) |
| F4 | 0.4590 / 0.1572 / 0.3420 | same | H(Ex) N H |
| C01 | 0.1486 / 0.0000 / 0.0407 | same | N N N |
| C02 Iron = Steel | 0.0355 / 0.1137 / 0.1318 | same | N N N |
| C04 | 0.0000 / 0.3368 / 0.4703 | same | N H H(Ex) |
| C05 | 0.5451 / 0.1363 / 0.3466 | same | H(Ex) N H |
| C06 | 0.0097 / 0.2991 / 0.5948 | same | N H H(Ex) |
| C07 | 0 / 0 / 0 | same | N N N |
| C08 | 0.1563 / 0.0992 / 0.2487 | same | N N H |
| C09 | 0.0001 / 0.3170 / 0.1904 | 0.0001 / **0.3186** / 0.1904 (probes in rank order; the emulator's 300 part orders gave 0.3170–0.3195) | N H N |
| C10 / C11 | 0.1565 / 0.0000 / 0.0282 · 0.1562 / 0.0012 / 0.0368 | same | N N N |
| C12 / C14 | 0.0355 / 0.1137 / 0.1318 | same | N N N |
| C13 | 0.0376 / 0.1133 / 0.1318 | same | N N N |
| C15 | 0.0353 / 0.2701 / 0.4291 | same | N H H(Ex) |
| A25 / A26 base / A26 / A27 | (E-S2.7: ΔD 0 / 0.0011 / Sh 0) | 0.0288/0.1037/0.0989 · 0.0468/0.1037/0.0989 · 0.0471/0.1048/0.0989 · 0.0288/0.1537/0.0989 | N N N |
| P1 / P2 / P3 / P4 / P5 | (E-S2.11: P1 Sh 0.0086 with the build's verdict) | 1/0/0.0114 · 1/0.0571/0.0308 · 0.2777/0.1804/0.1821 · 1/0.1389/0.1556 · 0.0328/0.1902/0.1202 | P1–P4 H N N; P5 N N N |

- F5 stays ≥ STARTER_MARGIN below Hard (max 0.1037 ≤ 0.15; Q7/Q21 quote "0.104").
- **T-DIF-06's edits hold as specified** (`critic_proto.luau -- sweep`, R0). F5's blade at 0.050 / 0.047 / 0.045 gives
  Hammering 0.1658 / 0.1895 / **0.2070** Hard. C02's blade +0.15 / +0.20 / +0.25 gives Sharpening 0.1889 / **0.2056** Hard /
  0.2314. These are E-S2.2's numbers.
- **P1** will differ from the prototype through the verdict. The build cleans #2 6 8 11 12 13 15 16 18 22
  (Reference.spec :40–53), and the exact reading may move Giant2 (true 2.04 %, E-S2.11 SPEC-evidence.md:520–521).
  Bless it after the verdict replacement.
- **E-S2.9's edge and cutIndex columns** (SPEC-evidence.md:289–308), which T-EDG checks: F1 = F5 5.433/0.72, F2
  4.980/0.43, F3 7.409/1.00, F4 5.724/0.13, C01 5.060/0.30, C02 = C12 = C13 = C14 5.644/0.77, C04 7.107/1.00, C05
  5.972/0.16, C06 6.480/0.89, C07 2.968/0.31, C08 6.392/0.62, C09 5.411/1.00, C10 4.980/0.27, C11 5.020/0.27, C15
  5.626/0.77. Physics columns as E-S2.9; the C rows are new to the build's tests.
- **Factor tables.** E-S2.9's All and Blade tables (:310–356) are the reference for every raw/x. With rank-order probes,
  C09's Thinness All is 0.3898 (E-S2.9 says 0.3858).

---

## 5. Tests

New spec files under `tests/Physics/` are discovered automatically (tests/run.luau:12–14). Fast cases must stay under
`CASE_BUDGET_MS` 2000 ms; anything over goes in `t.slow`.

**Quick-suite budget (§14.1 L1: `--quick` ≤ 30 s).**

- M1 measured 11.9 s for `--quick` (M1-notes.md:79). M2 adds its physics suites. M3 adds roughly 600–700 fast analyses
  (T-DIF-01/04/07/10 corpora and the goldens), about 10 s at 15 ms each.
- Time `--quick` after M2's commit and again after step 9 of §8.4.
- Past 25 s, cut the fast Gen corpora (40–60 designs each) to 20 first; `t.slow` keeps the `FUZZ_N_VALID` runs. The
  goldens stay in `--quick`, because L2 runs on every change.

### T-EDG-01: `tests/Physics/Edge.spec.luau` (D4: the SPEC names it at SPEC.md:3497 and defines it nowhere)

Proposed contents, from §4.6 and E-S2.5:

1. **F5 and F1.**
   - One chain. Main chain 5.433 (§4.6 :998).
   - 5 points, first (0.080, 1.380), last (−0.080, 1.380) (`v2/out_v2_checks.txt:14`). It starts at the +X base, runs
     over the tip and ends at the −X base (§4.6 :994–995).
   - `cell = 0.02`, `physics.edgeLength = edge.length`, cutIndex 0.72.
2. **E-S2.9's edge and cutIndex columns** for F1–F5 and C01–C15 (§4.3), within 5e-4.
   - Compare with `Proto.run(core).edge` within 1e-12 (chains, points, lengths, cell, bladeArea,
     bladeMeanThickness), with the prototype handed the parts in rank order as Reference.spec does.
   - Run it on every prototype fixture whose verdict the build shares: calibration, golden, adversarial and regression
     sets, and P2–P5.
   - The reference prototype exports only `run` (no `edgeProfile`, no forced kept row). P1's verdict differs
     (Reference.spec :34–51), so P1's edge is blessed alone.
3. **X04.**
   - Cases: 4 strips; strips with seams at ±0.05 and 0; 5 and 10 segments with 0.004 / 0.006 / 0.009 gaps; grip
     nudges 0.005–0.020.
   - Each gives one chain and EdgeLength 5.4330 = F5's. The bound is `TOL_EDGE_REL` 2 % (E-S8.4 :1780); the measured
     change is 0.00 % (E-S2.5 :228).
4. **P5 comb.** 11 chains of lengths [1.678, 0.552, 0.552, 0.541, 0.541, 0.532, 0.532, 0.521, 0.521, 0.170, 0.170]
   (out_v2_checks.txt:13). EdgeLength 1.678 is the main chain (§5.6 :1251).
5. **Rules.**
   - A blade thicker than `EDGE_MAX_THICK` (F2 with a 0.30-thick blade) gives EdgeLength 0.
   - Outline cells next to a hilt cell are ineligible: the guard buries the blade's base corners.
   - Pommel-facing segments are dropped.
   - Every chain has ≤ `EDGE_MAX_POINTS` points and ≥ `EDGE_MIN_CHAIN`·cell length.
   - The chain order is total.
6. **Invariance.**
   - **Y translation** (E-S2.10's offsets) moves the chains by Δy (points within 1e-9) and keeps lengths within 1e-12.
   - **Z translation** leaves the chains bit-identical, with thickness within 1e-12.
   - **X mirror image** (`Blueprint/Mirror` across x = 0) mirrors the raster: bladeArea and bladeMeanThickness within
     1e-12. EdgeLength stays within `TOL_EDGE_REL`; it is not exact (§1.2: Gen #31 of seed 0x5EED0008 measures
     6.935592 against 6.915188).
   - Run the mirror case on F1–F5, C01–C15 and 40 `Gen.validSword` designs (`FUZZ_N_VALID` slow), and print the
     largest relative change.
7. **Budgets on P1.** cells ≤ `EDGE_MAX_CELLS` and work ≤ `EDGE_MAX_WORK` at the chosen cell, or the cell is the last
   rung.

### T-DIF-01…13: `tests/Physics/{Factors, Difficulty, Invariance, Parity}.spec.luau`

Catalogue names are from E-S8.5 SPEC-evidence.md:1807–1809; contract text is §14.6 SPEC.md:3512–3517.

| Id | Asserts | Inputs | Tolerance |
|---|---|---|---|
| T-DIF-01 P-RANGE, caps | every `x` ∈ [0,1]; raw finite and ≥ 0, with Thinness and Asymmetry raw ≤ 1; g, m, d ∈ [0,1] and on the 1e-4 grid (`q(v) == v`). Caps: A24 Thinness = 1 on All and Blade, never above, Hammering 0.40 (E-S8.4 :1776); Volume x = 1 for V ≥ 0.8 (P1, P2, P4); SC x = 1 for r ≥ 2.9 (F3 Blade); EdgeLength x = 1 for E ≥ 8 on a case built in the spec, since no fixture reaches 8 (F3 is 7.409): F2's hilt with a 1.4 × 3.43 × 0.06 Block blade standing on the guard up to y 4.98, outline ≈ 2 × 3.43 + 1.4 ≈ 8.3 by §4.6. The case first asserts that it is valid and that E ≥ 8, then x = 1 | every fixture; 60 `Gen.validSword` fast, `PROP_N` slow | exact |
| T-DIF-02 soft OR | on m, g ∈ {0, 0.01, …, 1} (101 × 101): softOr(0,g) = g, softOr(m,0) = m, symmetric, ≥ max(m,g), softOr(1,g) = 1, non-decreasing in each argument, result on the grid | `Difficulty.softOr` | exact |
| T-DIF-03 boundary | `tierFor(0.1999999999)` = Normal and `tierFor(0.2)` = Hard (SPEC.md:3512). Production quantizes first: q(0.19995) = 0.2 → Hard, q(0.199949) = 0.1999 → Normal. NaN errors (`Quantize.q` "non-finite", `Tiers`). tierRaw unclamped: 0.85 is raw Hell, played Hard; F3 is raw Expert/Master | `Tiers`, `Difficulty.step` | exact |
| T-DIF-04 enclosed, duplicates, dust | Steps and edge bit-identical (`Dump.canonical`) to the base for the cases listed below the table. Then `Gen.withFiller(…, "Enclosed" / "Duplicate" / "Dust")` on 40 designs fast and `FUZZ_N_VALID` slow. Excluded: a copy in a slot whose name sorts first (§4.4 :908–909) | fixtures, Gen | bit-identical, Dust included (§14.6's \|ΔG\| ≤ `TOL_DUST_G` is the looser bound, §8.3 item 12) |
| T-DIF-05 Iron ↔ Steel | C02 Iron vs Steel: every g, m, d, tier, tierRaw and factor bit-identical; `material` Iron/Steel. F1 vs F5: d identical (F1's MaterialMix raw is 2 on All, unweighted). On Gen swords with every material swapped, d is bit-identical and m = 0 | fixtures, Gen | exact |
| T-DIF-06 monotone | F5 blade 0.060 → 0.055 → 0.050 → 0.047 → 0.045 → 0.043 thick: Thinness All and Hammering d non-decreasing; 0.045 is Hard (0.2070, E-S2.2 :208–209). C02 blade +0.15/+0.20/+0.25 (size y += dL, pos y += dL/2, tips += dL; v2/checks.luau:38–44): EdgeLength non-decreasing; +0.20 gives Sharpening Hard (0.2056, §5.5 :1235). PartCount non-decreasing from C01 to C10 | variants built in the spec | exact order |
| T-DIF-07 invariances | Parts (a), (b) and (c) are listed below the table. Compared on the five weighted factors (Thinness, Asymmetry, SurfaceComplexity, EdgeLength, Volume) and G; PartCount and Joints count parts by design | fixtures, Gen | as stated |
| T-DIF-08 mirrored Asymmetry | C13 (half + `Blueprint/Mirror`) Asymmetry 0 on both sets (E-S2.6 :239–240); Gen swords built half and mirrored: ≤ `TOL_ASYM_ZERO`, which is all §14.6 asks. A whole design and its X mirror image are **reported, not asserted**: the critique measured \|ΔD\| up to 0.0069 with the stride over 20 fixtures and 150 Gen designs (gen #136, Thinness x 0.0172: the stride visits the mirrored samples in another order; EdgeLength moves through the chain's opening vertex, §1.2) | fixtures, Gen | `TOL_ASYM_ZERO` |
| T-DIF-09 step scoping | `steps` = the enabled CraftPlans steps in order; Sharpening's factors are on `WorkSet.select(…, {"Blade"})`; Smelting and Hammering share All's values; `terms` follow the `Steps` order with Σw = 1; A27 (hilt shifted 0.04 in X): Sharpening d = F1's while Hammering moves 0.1037 → 0.1537 (E-S2.7 :248); cleaned parts in no set; a planted CraftPlans with a disabled or extra step is followed (`Drafts.planted`, as P-ORDER at Analyze.spec :833) | fixtures | exact |
| T-DIF-10 client = server | `Analyze.run(core)` = `Analyze.run(core, {checkpoint = coroutine.yield})` resumed in a loop (as Analyze.spec :782–815) = the same with `measureInvalid = true`, by `Dump.canonical` | 50 `Gen.validSword` fast, `FUZZ_N_VALID` slow | bit-identical |
| T-DIF-11 fixture tiers | every fixture's tier and tierRaw = §5.5 (`expect.tiers/tierRaw`, Blueprints.spec :162 extended to Calibration); F5's max d ≤ Hard.dMin − `STARTER_MARGIN` | F1–F5, C01–C15 | exact |
| **T-DIF-12** (D4, proposed) | the §5 table golden (below) | all fixtures | golden |
| **T-DIF-13** (D4, proposed) | The A and X relation contracts and two §5.6 rows, listed below the table | A, X, C fixtures | E-S8.4's bounds; §5.6's |

**T-DIF-04 cases** (bit-identical steps and edge against the base):

- C04 with a 0.075 blade + 9 nested enclosed blocks (sizes ×0.96−0.02k, Reference.spec :258–277): Hammering Normal.
- C09 with core, bevels and tips 0.05 longer + 6 blocks (×0.75−0.005k, 5 Blade + 1 Pommel, Reference.spec
  :279–306): Sharpening Hard.
- C09 + plate X (Block Blade (−0.03, 2.6, 0) 0.12 × 2 × 0.05) + 5 hidden blocks (×(0.8−0.01j), slots G G G B B,
  `verdict/lines/limit2.luau:57–67`): the plate is kept, Sharpening ≈ 0.2542 (§17.2 :4343).
- X07a + a Dust hairline (Block 0.02 × 0.4 × 0.02 = 0.00016 stud³ on the seam).
- **F5, C02 and C05 + 4 flush plates** (§5.6 SPEC.md:1244), using Verdict.spec.luau:349's construction: 2 Guard plates
  on the blade's Z faces and 2 Pommel plates on its X faces, with lower ids. Assert first that the 4 plates are cleaned.
  The prototype's id rule moved these designs 0.4834 / 0.5756 / 0.7159.
- A16 and A17 (BitIdentical, mass identical).
- A14 (19 dust cubes): bit-identical, with the fixture's expectation updated (§4.2). This is stronger than §14.6's
  \|ΔG\| ≤ `TOL_DUST_G`.
- A25.

**T-DIF-07 parts:**

- **(a) Y/Z translation.**
  - Inputs: F1, F3, F5, C02 and C06 by the 6 offsets of `v2/run.luau:218` ({0,0.013,0}, {0,0.125,0}, {0,0.3317,0},
    {0,0,0.01}, {0,0,−0.037}, {0,0.2,0.05}), and `Gen.translated` (40 fast, `FUZZ_N_VALID` slow).
  - Assert \|Δx_f\| ≤ `TOL_FACTOR_ABS` and \|ΔG\| ≤ `TOL_G_INVARIANT`. E-S2.10 measured ≤ 0.0017 / 0.0007; 30 Gen
    designs here measured 0.
- **(b) Flush re-segmentation, D2 (i).**
  - **Asserted at the §14.6 tolerances:**
    - F5's blade cut flush into 2, 3 and 7 pieces (E-S2.10 :393, `v2/run.luau:240–252`).
    - C12 vs C02.
    - Both measure \|Δx\| < 1e-6 and \|ΔG\| 0 in rank order with the stride (`verify/v_m3.luau -- cuts`).
  - **`Gen.segmented`** (40 fast, `FUZZ_N_VALID` slow):
    - Assert Volume and EdgeLength within `TOL_FACTOR_ABS`. They depend on the union only (30 designs: 0.0000).
    - Run SurfaceComplexity on the 500 designs before deciding whether it is asserted or reported (30 designs: ≤ 0.0013).
    - **Report, not assert**, the largest Thinness, Asymmetry and G changes. On 300 designs: Thinness 0.0591,
      Asymmetry 0.0197, G 0.0236 (§7.5).
- **(c) Ids and order.**
  - Shuffled ids on C09, P5 and P1 (canonicalized, so the parts reorder) give steps and edge bit-identical
    (§17.2 :4347), with the difficulty frame in rank order (§1.5).
  - Physics is summed in blueprint order by M2's MassProps, so it is compared within 1e-12.
  - X shifts and whole-sword turns are real changes; C15 is not asserted.

**T-DIF-13 contents:**

- A14 and A16/A17 (asserted in T-DIF-04), A24 (in T-DIF-01), A23 finite.
- A25 ≤ 0.01, A26 ≤ 0.02, A27 Sharpening ≤ 0.02 (E-S2.7).
- X01/X02 against their union blades: \|ΔD\| ≤ 0.01 (0.0010 / 0.0006, E-S2.5).
- X03: ΔThinness ≤ 0.02.
- X05: \|ΔG\| ≤ 0.01.
- X06: \|Asym − oracle\| ≤ 0.02. The oracle is `Factors.asymmetry` planted with `ASYM_N_MIN` 120, `ASYM_WORK` 1e9 and
  `N_MAX_AXIS` 400 (run.luau:130–135).
- X07: \|ΔG\| ≤ 0.01 (mass is T-PHY-10).
- **C10 and C11 against C01** (§5.6 SPEC.md:1245): on every step, d − d_C01 ≤ 0.008, and all Normal. Smelting is
  0.1486 → 0.1565, +0.0079.

**Where T-DIF-12 and T-DIF-13 go.** E-S8.5 says "10–13 as §14.6", but §14.6 defines only 10 and 11. Write both
definitions into §14.6 or E-S8.5 (§8.3 item 1).

**The §5 table golden (T-DIF-12).**

- **Files:** `tests/golden/difficulty_{calibration, regression, cost}.bv1.golden.txt` (§14.9's `<name>.bv<N>` naming).
  Three files keep each fast case under 2 s.
- **Each entry:** `{id, valid, cleaned, physics = {mass, volume, balance, reach, bladeLength, edgeLength, cutIndex}, edge =
  {chains = n, lengths, cell, bladeArea, bladeMeanThickness}, steps = {{step, g, m, d, tier, tierRaw, material, factors =
  {{factor, raw, x} ×8}} ×3}}`, written by `Golden.check` through `Dump.canonical` (%.17g).
- **How to bless.**
  1. Implement M3 after the verdict replacement has merged.
  2. Print `Analyze.run`'s d for every fixture beside §4.3's expected column with a scratch script.
  3. Accept only exact matches within ±0.0001. Investigate anything else.
  4. Run `lune run tests/run -- --bless`. Review `git diff tests/golden`: existing goldens, `balance_fingerprint`
     included, must not change.
  5. Record the comparison in `docs/build/M3-notes.md`. Edit the §5.5 and E-S2.9 rows that moved: C09 Hammering
     0.3170 → the blessed value, and E-S2.9's C09 Thinness All. §17.2 :4347 anticipates "bless §5.5 on that".
- **What it pins.** Every fixture's outcome to the bit: physics, edge, the 8 factors per step, g, m, d and tiers. Any
  outcome-changing code change shows as a diff (§14.9 SPEC.md:3562).

### T-PERF-01: `tests/Physics/Perf.spec.luau`, `t.slow` (§14.11 SPEC.md:3604)

- **Cases (`Cost.TPERF`):**
  - X08 aliases: P2 (X08a), P1 (X08b, which is also §14.11's "adversarial fixture P1"; it is run once, under both
    names), and P5 (X08c).
  - P1, P2 and P3 + a floating Dust speck, with `measureInvalid = true`, comparable with E-S2.11's 30.2 / 22.5 /
    19.3 ms.
  - P1, P2 and P3 + an attached speck: valid, no `measureInvalid`, the production path.
  - The 11 `WorstP` designs. Their recorded totals are 35.2–54.6 ms Lune, and M3's share is 4.3–16.1 ms
    (`worst_P.json` `lune_ms`).
- **Method** (`verdict/lines/d_cost.luau:61–100`):
  1. One warm-up run per case.
  2. `PERF_RUNS` = 15 rounds; odd rounds forward, even rounds backward.
  3. In each round, `collectgarbage("collect")`, then a timed run without a checkpoint for the total.
  4. Then a separate run whose checkpoint records the longest gap: run start to first call, call to call, last call to
     run end.
- **Assertions.**
  - Per case: median total ≤ `ANALYSIS_LUNE_MAX_MS` 60, and median longest gap ≤ `CHECKPOINT_GAP_LUNE_MS` 0.35.
  - Print the max gap. Print P1 and the worst designs against 29 ms (75 ÷ 2.6) without asserting.
  - The median rule needs a §14.11 wording edit: today it reads "every checkpoint gap" (§8.3 item 9).
- **D3 decision rule.**
  1. Measure at `CHECK_UNITS` 500 first and record the medians in M3-notes.
  2. If any case's median longest gap exceeds 0.35, which E-S2.11 :531 predicts (0.06–0.37, "the long ones end at
     MassProps' GJK, charged 20 units"), set `CHECK_UNITS` = 250. That halves every gap (expected ≤ 0.25) for about twice
     the checkpoint calls, a few µs per run. Re-measure.
  3. If a single loop still dominates, fix that loop's charge (e.g. `UNITS_PER_OVERLAP_TEST` 20 → 40, MassProps.luau:79)
     rather than lowering `CHECK_UNITS` further.
  4. With 250, edit §16.18 :4116 and Analyze.spec :640 (`A.eq(Analyze.CHECK_UNITS, 500, "§16.18")`), and re-check
     Analyze.spec :761 ("F2 < 150 checkpoints"). E-S8.8's slice arithmetic holds (4 + 2.6 × 0.35 ≤ 5).
- **Machine.** Other agents are timing on this machine; the prototype ran 1.5–2× slower than E-S2.8 today. Run T-PERF-01
  alone (`--filter Perf`).

### The first S-PAR-02 digest (§14.10 SPEC.md:3593; E-S8.6 SPEC-evidence.md:1874–1875; §17.2 S8 :4367)

**What it is.** At M5, S-PAR-02 digests `Pipeline.analyze` plus judged bot runs and T-CR-08's outcomes. At M3 it is
the first part: `Analyze.run` over every fixture plus 200 `Gen.validSword` designs. The Lune digest must equal the
digest computed in the Studio **Server** and **Client** datamodels. That proves no FMA contraction, `--!native` off, and
identical `string.format`, `math.round` and `table.sort`.

**Lune side.**

- `tests/fixtures/Parity.luau` returns the ordered `{name, core}` list: Blueprints, Calibration, Adversarial A25–A27 and
  the canonical A variants, Regression, Cost (with both specks), WorstP.
- `tests/lib/Tol` gains `PARITY_DESIGNS` 200 and `PARITY_SEED`. The 200 swords are `Gen.validSword(TestRng.new(PARITY_SEED),
  ctx)` in sequence.
- Digest:
  `{version = 1, analyze = {designs = n, fixtures = fnv1a32(lines₁), generated = fnv1a32(lines₂), bytes = …}}`, where
  each line is `name .. "\t" .. Dump.canonical(Analyze.run(core, {measureInvalid = true})) .. "\n"` and `Dump.fnv1a32`
  is Dump.luau:190.
- `tests/lib/Golden.luau` gains `Golden.digest(name, value)`: like `check`, but it writes `<name>.digest.txt` and
  asserts ≤ 1024 bytes (§14.2 SPEC.md:3430). `Golden.check` only knows `.golden.txt` today.
- Spec `tests/Physics/Parity.spec.luau`, `t.slow` (about 3–5 s): `Golden.digest("parity.bv1", digest)`.
- Leave room for M5's `judge` and `outcomes` keys.

**Studio side.** `tests/studio/e2e/S-PAR-02.luau`, in the style of `S-PAR-01.luau` (header "HOW TO RUN" and "OUTPUT",
`emit`, `run()` in `xpcall`, a summary line, `return table.concat(lines)`).

- **Preflight.** `RunService:IsRunning()`, and `IsServer()` or `IsClient()`, reported as `datamodel`.
- **Requires.** `ReplicatedStorage.Blacksmith.Physics.Analyze`; the five Definitions for `Gen.context`;
  `ReplicatedStorage.BlacksmithTests.lib.{Dump, Gen, TestRng, Tol}`; `…fixtures.Parity`.
- **Yields.** `Analyze.run(core, {measureInvalid = true, checkpoint = slice})`, with the AnalysisQueue's 4 ms slice
  calling `task.wait()` (§1.6 SPEC.md:278), plus a `task.wait()` between designs. Studio freezes while execute_luau code
  does not yield.
- **Compare.** `Dump.canonical(digest) .. "\n"` against `ReplicatedStorage.BlacksmithTests.golden["parity.bv1.digest"].Value`.
  - Rojo turns `parity.bv1.digest.txt` into a StringValue. Confirm the name at the first run.
  - If it is absent, fail with `{"check":"golden"}` listing `golden:GetChildren()`.
  - No `loadstring`, which is off on servers and absent on clients.
- **Output.** `[E2E] S-PAR-02 PASS|FAIL {"check":"analyze","datamodel":"Server","designs":n,"fixtures":h1,"generated":h2,"expected":…}`.
  On FAIL, print every design's own fnv1a32 so a Lune run can diff them.
- **Lune test of the snippet.** `tests/Physics/SPar02.spec.luau` runs it on `tests/ItemRender/FakeRoblox.luau`.
  - FakeRoblox already maps `src/shared`, `tests/lib` and `tests/fixtures`.
  - Extend it with `tests/golden` as StringValues and `RunService:IsClient()` (`Options.server = false`).
  - This is the same proof M2 gave for S-PAR-01 (ItemRender/SPar01.spec.luau).

**Running it.** The test place is Project 215, Rojo-connected on port 34873 from `test.project.json`. Play sessions only;
nothing changes in Edit.

1. `list_roblox_studios`, then `get_studio_state`.
2. `start_stop_play(true)`.
3. `execute_luau(code = file text, datamodel_type = "Server")`, then the same with `datamodel_type = "Client"`. The MCP
   offers Edit, Client and Server.
4. `get_console_output`, then `start_stop_play(false)`.
5. Repeat in 3 fresh Play sessions; all green with a clean console (§14.10 :3597).

If one call runs too long, a `GROUP` constant at the top selects "fixtures" or "generated" and the digest is checked per
group.

---

## 6. Open items M3 inherits

| Item (source) | Resolution in this plan |
|---|---|
| Checkpoint gaps above 0.35 (§17.2 S2 :4341) | T-PERF-01 with D3 |
| Rank order for M3's probes and budgets, bless §5.5 on it (§17.2 :4347) | rank order everywhere, the difficulty frame included (§1, §2); C09 0.3186 (§4.3) |
| Design question for M3 (§17.2 :4349) | D1: option 0 **[Decision to confirm]**, with §7's sweep written into §17.2 |
| Overlap budget, P1/P2/P4 mass off by −10.3/−4.4/−5.6 % (§17.2 :4350) | no M3 action; P1's goldens pin the budgeted numbers; `TOL_MASS_REL` is not asserted on P1–P5 |
| Verdict cost, 75 ms ceiling only on real designs (§17.2 :4351, Decision to confirm) | T-PERF-01 runs WorstP; risk R2 |
| A label moves Sharpening's tier (§17.2 :4348, Decision to confirm) | out of M3's scope; T-DIF-09 documents the current behaviour |
| Bit-identical factor digests Lune vs Studio client vs server (§17.2 S8 :4367) | S-PAR-02 (§5) |
| M1-notes.md:76 (a): withFiller "Duplicate" moves d in the prototype | the build's `sameSolid` cleans copies of every shape (T-PHY-09); T-DIF-04 asserts at the D level |
| M1-notes.md:76 (b): `Gen.segmented` breaks T-DIF-07 | confirmed on 300 designs. Causes: θ's axis rule first, then Asymmetry's grid and the stride (§7.5). D2 (i) narrows (b) and records the sensitivity |
| M1-notes.md:89: F1–F5's d values blessed from `Analyze.run` in M3 | T-DIF-12 |
| M1-notes.md:48: tests hard-code Minigames constants | M4, not M3 |
| M2: add P2 and P3 + speck and worst_P to T-PERF-01 and S-PERF-01 | `Cost.TPERF` and `WorstP.luau` (Studio-readable), with floating and attached specks |
| M2: T-PERF-01 asserts the median of 15 runs | `PERF_RUNS` 15 and median assertions; §14.11 wording edit |
| M2: M3's factor and edge budgets on 24 overlapping blocks | Extend Analyze.spec :657–672 (P1), through `Factors.measure`'s budget and `Edge`'s stats: raster cells and work within budget or the last rung; Thinness probes ≤ `THICK_BUDGET` (it holds with the stride, §1.3.1); Asymmetry work ≤ `ASYM_WORK` or the last rung |
| M2: T-DIF-04 cases | §5 T-DIF-04 (all four, plus the flush plates) |
| M2: T-DIF-07 flush re-segmentation | §5 T-DIF-07(b) under D2 |
| M2: Analyze's plug-in spot | Analyze.luau:427–430 → §1.5 |
| M2: retire Reference.spec's comparisons that M3 supersedes | Three retirements and four Analyze.spec updates, listed below the table |

**Reference.spec retirements:**

1. **:161–175**, M2's SurfaceComplexity stand-in. Replace it with a factor-level comparison against the prototype in rank
   order, on every fixture but P1:
   - PartCount, Thinness, Asymmetry, EdgeLength and MaterialMix bit for bit;
   - Volume, SurfaceComplexity and Joints within `ABS` 1e-12.
2. **:222–306**, the `flipCase` prototype-tier assertions (:250–252). Drop them and move both designs to T-DIF-04. Keep
   the exposure-level K + F assertions (:253–255), which duplicate T-PHY-09.
3. **:308–321**, `PhysicsHelpers.ornate is the prototype's C09`. Replace it with the FixtureSet port checks and delete
   `H.ornate`.

**Analyze.spec updates:**

- :620–641: the report no longer has a nil edge and nil steps.
- :692–720: the phase count goes from 5 to 8. Add `Edge`, `Factors`, `Difficulty`, `WorkSet`, `CraftPlans`, `Steps`,
  `Tiers`, `Materials`, `Quantize` and `Balance` to the `modules` map.
- :722–762: add M3's loop functions to the names list. Name them as local functions so `debug.info` sees them.
- :833–862: the P-ORDER planted maps gain M3's modules.

---

## 7. The design question: a core sandwiched between cheeks (§17.2 SPEC.md:4349)

### 7.1 What happens today, measured

The designs are §17.2's own (`verdict/lines/limit2.luau:32–51`):

- **Hilt:** Ball d 0.30 at y 0.30, Cylinder 0.90 × 0.16 at y 0.88, Guard 1.10 × 0.16 × 0.30 at y 1.40.
- **Sandwich:** two cheeks w × l × c at z = ±(0.01 + c/2), so the gap is 0.02, and a top cap w × 0.04 × (0.02 + 2c).
  A Steel core wc × l × 0.02 sits in the gap. Adding a sheet wh wide over the core's rims makes both Enclosed.
- **Flush layers** (`m2r5-v1-2/a_lam.luau`): a solid plate against the same plate in n layers whose interior layers are
  cleaned.

The emulator in `proto/` is the prototype's factors on rank-ordered parts, with the verdict forced through
`opts.forceKept` (`proto/out_lam2.txt`, `out_lam_late.txt`). The exact verdict replacement may read these designs
differently, so re-run the sweep after the merge.

| Design | solid union | core kept | core + sheet cleaned | hollow (no core) |
|---|---|---|---|---|
| LAM1 = §17.2's, cheeks 1.1 × 2.0 × 0.06, core 0.95 | 0.4364/0.0000/0.0594 HNN | 0.4282/**0.0374**/**0.0594** HNN | 0.3762/**0.3609**/**0.2594** HHH | = cleaned |
| LAM2 1.2 × 2.5 × 0.05, core 0.90 | 0.5090/0.0578/0.2250 HNH | 0.4883/0.4310/0.3850 HHH | 0.4265/0.4496/0.4250 HHH | = cleaned |
| 8 layers 1.6 × 3.5 × 0.16 | 1.0000/0.0582/0.5000 HNH | all kept 1.0000/0.0481/0.5000 | interior cleaned 0.3500/**0.7000**/0.7000 HHH | — |
| 4 layers 1.5 × 3.4 × 0.08 | 0.6048/0.3659/0.7000 HHH | 0.6050/0.3659/0.7000 | 0.3223/0.7000/0.7000 | — |

- **LAM1** reproduces §17.2's "Hammering 0.0374 Normal → 0.3609 Hard". It also flips **Sharpening** (0.0594 → 0.2594,
  N → H), so two tiers flip.
- **SurfaceComplexity carries most of the jump, not Thinness.** The cleaned core leaves the cheeks' inner faces exposed
  (r 2.325 → 3.718, x 0.04 → 1.0): +0.29 of Hammering's +0.3235 and all of Sharpening's +0.20.
- Thinness adds +0.036 (x 0.062 → 0.152). Volume drops Smelting by 0.052.
- Flush layers jump 0.65; the review journal recorded 0.6500 for the 8-layer plate.

### 7.2 Options and what they do

The options' effects on §5's fixtures were measured together with the withdrawn D2 (`proto/out_fix2.txt`,
`out_final_late.txt`). Re-measure them alone if one is chosen.

| Option | §5 table | LAM1 (kept → cleaned) | LAM2 | Layers | Contracts and cost |
|---|---|---|---|---|---|
| **0 Accept**: SPEC as written | unchanged | 2 tiers flip, \|ΔD\| 0.3235 | 0.4310 → 0.4496 Ha, already Hard | 8 layers 0.65; 4 layers Ha +0.33, Sm −0.28 | none; cleaned parts inert everywhere |
| **A** Thinness chords merge gaps ≤ 0.05, kept parts only | 0.0000 on every fixture | Ha 0.3165, Sh 0.2594: still 2 flips | Ha 0.3021 → 0.3000, Hard both (`out_lam2.txt`) | 8 layers unchanged (gap 0.12); 4 layers Hammering fixed (SC already saturated), Smelting still 0.6048 → 0.3223 | cleaned parts inert; cost nil. Insufficient: S_exp dominates |
| **B** A + **void faces hidden** (late form): a kept sample is hidden if its normal ray crosses ≥ `HIDE_OFFSET` of air and then enters a kept part ≥ `CONTACT_TOL` deep within `VOID_GAP` 0.05, tested once per sample the other rules leave exposed | with D2: C09 −0.0085, F3 −0.0018, P5 −0.046; no tier changes | 0.4282/0.0000/0.0594 → 0.3762/0.0165/0.0594: no flip | 0.0897 → 0.1740 Ha (+0.084), Sh 0.2250 → 0.2792, no flip | 8 layers unchanged (0.12 > 0.05); 4 layers Hammering fixed, but Smelting still 0.6048 → 0.3223 | Cleaned parts stay inert, so T-DIF-04, T-PHY-09's "K + F as K alone" and §4.4 :955–956 hold. It lowers SurfaceComplexity, but Thinness can move either way: in M = Σwφ²/Σwφ, lowering a φ_i below M/2 raises M. Cost, best of 5 on a loaded machine: −12 % to +23 % per fixture (C04 +23 %, `out_cost2.txt`); the noise is about ±10 % |
| **C** Body rule: cleaned non-Dust parts fill chords, hide in the measure and add their owned volume | 0.0000 | 0.0374 → 0.0000 (sheet adds metal): no flip | **a hidden sheet moves a tier**: K 0.4310 H → K + sheet 0.0603 N; Sharpening 0.3850 → 0.2250 stays Hard | ≈ solid (≤ 0.05) | breaks §5's "hidden filler cannot move a tier"; breaks T-DIF-04 as worded; Volume picks up MassProps' sampled-ownership noise for hidden curved parts; contradicts §4.4 :955–956 |

A first form of B, without the two conditions "crosses ≥ `HIDE_OFFSET` of air" and "enters ≥ `CONTACT_TOL` deep", fired
on grazing rays in concave corners, for example C09's bevels against its core: −0.0949 on C09 (`proto/out_c09.txt`).

### 7.3 The sandwich sweep: option 0 against option B

These are §17.2's sandwich with other cheek thicknesses, widths and lengths. K is the core kept; K + sheet has the core
and the sheet forced cleaned. d is Sm / Ha / Sh (`verify/v_m3.luau -- lam0`).

| Cheeks w × l × c, core wc | option 0: K → K + sheet | flips | option B: K → K + sheet | flips |
|---|---|---|---|---|
| 1.1 × 2.0 × 0.06, 0.95 (LAM1) | 0.4282 H / 0.0374 N / 0.0594 N → 0.3762 H / 0.3609 H / 0.2594 H | 2 | 0.4282 H / 0.0000 N / 0.0594 N → 0.3762 H / 0.0165 N / 0.0594 N | 0 |
| 1.1 × 2.0 × 0.04, 0.95 | 0.3053 H / 0.2670 H / 0.1339 N → 0.2534 H / 0.4812 H / 0.2594 H | 1 | 0.3053 H / 0.0814 N / 0.0594 N → 0.2534 H / 0.1971 N / 0.1434 N | 0 |
| 1.1 × 2.0 × 0.03, 0.95 | 0.2439 H / 0.4346 H / 0.2430 H → 0.1919 N / 0.6122 H / 0.2594 H | 1 | 0.2439 H / 0.1951 N / 0.1553 N → 0.1919 N / 0.3000 H / 0.2594 H | 3 |
| 1.1 × 2.0 × 0.02, 0.95 | 0.1825 N / 0.5352 H / 0.2594 H → 0.1305 N / 0.6987 H / 0.2594 H | 0 | 0.1825 N / 0.3502 H / 0.2594 H → 0.1305 N / 0.3502 H / 0.2594 H | 0 |
| 1.2 × 2.5 × 0.05, 0.90 (LAM2) | 0.4883 H / 0.4310 H / 0.3850 H → 0.4265 H / 0.4496 H / 0.4250 H | 0 | 0.4883 H / 0.0897 N / 0.2250 H → 0.4265 H / 0.1740 N / 0.2792 H | 0 |
| 1.2 × 2.5 × 0.03, 0.90 | 0.3208 H / 0.6433 H / 0.4250 H → 0.2590 H / 0.6903 H / 0.4250 H | 0 | 0.3208 H / 0.3141 H / 0.4250 H → 0.2590 H / 0.3141 H / 0.4250 H | 0 |
| 1.0 × 2.5 × 0.06, 0.80 | 0.4808 H / 0.1655 N / 0.1929 N → 0.4259 H / 0.3919 H / 0.3844 H | 2 | 0.4808 H / 0.0021 N / 0.1844 N → 0.4259 H / 0.0290 N / 0.1844 N | 0 |
| 1.0 × 2.5 × 0.04, 0.80 | 0.3414 H / 0.4311 H / 0.3595 H → 0.2865 H / 0.5400 H / 0.3844 H | 0 | 0.3414 H / 0.1385 N / 0.2190 H → 0.2865 H / 0.2495 H / 0.3073 H | 1 |
| 0.8 × 2.5 × 0.04, 0.60 | 0.2716 H / 0.4781 H / 0.3163 H → 0.2305 H / 0.5400 H / 0.3531 H | 0 | 0.2716 H / 0.0927 N / 0.1531 N → 0.2305 H / 0.1826 N / 0.2273 H | 1 |
| **total, largest \|ΔD\|** | | **6 flips on 4 designs; 0.3235** | | **5 flips on 3 designs; 0.1157** |

- **What B changes.** B reads a kept laminate's rim slits as solid, so the K state is often Normal under B where it is
  already Hard under option 0. The cleaned core's volume still leaves V, which is SurfaceComplexity's denominator and
  Smelting's Volume: in the 0.03 case, r goes from 2.690 to 2.997 and V from 0.2556 to 0.2182. The flips therefore move
  to other proportions instead of going away.
- **An offset hilt** (the critique's `lam`, guard shifted 0.20 in X) brings LAM2 under B to Hammering 0.1131 → 0.1981,
  just under Hard.
- **Smelting falls under both options:** 0.04–0.06 on every sandwich, which flips 1.1 × 2.0 × 0.03 from Hard to Normal.

### 7.4 Recommendation

**Option 0. [Decision to confirm]**

- **M3's decision on the question.** Cleaned parts affect nothing in D, Thinness' chords included, and the chords merge
  gaps ≤ `CONTACT_TOL` as §5.2 says. The evidence is that Thinness is a minor channel (+0.036 of LAM1's +0.3235), and
  that no rule examined closes the class without letting hidden parts move D.
- **Why not B.**
  - B removes §17.2's own example's two flips and cuts the largest jump from 0.32 to 0.12. But it flips about as many
    tiers on the sweep (5 against 6).
  - It costs up to +23 % analysis time against R2's 5.4 ms of headroom on the worst designs.
  - It needs `VOID_GAP` in Balance (a fingerprint re-bless), SPEC edits in §4.4, §5.2, §5.6 and §16.10, and code in
    the measure block that the verdict team is replacing now.
  - It moves C09, F3 and P5 (with D2: −0.0085 / −0.0018 / −0.046). It is additive, so it can land later as its own
    change.
- **If Louis picks B:**
  - Implement it after the verdict merge (§8.4 step 8).
  - State its claims as measured: it lowers SurfaceComplexity, Thinness can move either way, and it leaves flips at
    other proportions.
  - Accept it on a sandwich sweep: cheeks 0.02–0.06, widths 0.6–1.2, and hilt offsets 0–0.25 that put r in
    [2.3, 2.9].
  - Add the 4-layer plate's Smelting drop (0.6048 → 0.3223) to its residuals.
- **The other choices for Louis:**
  - **B + a volume rule** (option C's volume half, counting a cleaned core's owned volume) would close more of the
    class, but it lets hidden parts move D through Smelting's Volume, against §5's principle.
  - **A verdict-side rule** (a core within `VOID_GAP` of kept parts on both faces stays kept, or reads as one body
    with them) is the only complete fix. It belongs to the verdict's owner, not to M3.

**What goes into §17.2 :4349.** Replace the question with:

- the decision;
- §7.1's mechanism: SurfaceComplexity and Volume carry the jump; Thinness is minor;
- §7.3's sweep, under both options;
- the flush-layer numbers: 8 layers 0.65; 4 layers Hammering +0.33, Smelting −0.28;
- the residual statement: where a sandwiched core crosses 2 %, D can jump up to about 0.32 and flip one or two tiers;
  accepted with the 2 % rule (§17.2 :4343).

### 7.5 Thinness probes and T-DIF-07: why D2's ladder grid is withdrawn

The first version of this plan traced T-DIF-07's failure to §5.2's stride and proposed a per-part ladder grid. That rested
on 30 designs. On 300 designs (seed 0x5EED0007, the same stream, so designs 1–30 are the plan's), the critique measured
the following (`critic_proto.luau -- gen 300`). The worst designs were re-run here (`verify/out_verify.txt`).

| Thinness probes | `Gen.segmented` vs whole: max \|Δx_Thinness\| / \|ΔG\| | θ-safe subset (241 designs) | against FINE: max \|ΔThinness\| / \|ΔD\| / tier flips |
|---|---|---|---|
| §5.2 stride, rank order | 0.0591 / 0.0236 (#51) | Thinness 0.0570, G 0.0228 | 0.0561 / 0.0224 / 0 |
| D2: ladder grid within `THICK_BUDGET` 400 | 0.0513 / 0.0205 (#51) | Thinness 0.0028, G 0.0045 (#55, Asymmetry) | 0.1414 / 0.0566 (#117) / 1 |
| FINE: every phase-5 sample a probe | 0.0476 / 0.0191 (#51) | G 0.0045 (#55) | reference |
| D2 at `THICK_BUDGET` 1600 | — | — | 0.0082 / 0.0033 on 150 designs; cost not measured |

**The causes, in order:**

1. **θ follows the piece's proportions.** In #51, an unturned 0.0713 × 0.1700 × 0.1030 Blade part is cut into three pieces
   0.0567 long. θ moves from local X to Y, the θ chord then runs along the flush stack, and τ goes from 0.0713 to 0.1030.
   FINE fails on this design too.
2. **Asymmetry's grid moves with the part count.** The spacing estimate multiplies by (1 + #mc + #hc), and each piece
   gets its own grid. Ha.Asymmetry moves 0.0197 on #152 and 0.0147 on #55 under every probe rule, so \|ΔG\| reaches
   0.0059 regardless of Thinness.
3. **The stride's aliasing** over the concatenated x-major sample lists. D2 removes it on the θ-safe subset (0.0570 →
   0.0028). But at 400 probes, its coarse grid is less accurate than the stride (#117: Thinness 0.1414 off, one tier
   flip), and on the fixtures it moves F3 to 0.4405 and P5 to 0.1698.

D2 also left phase 5 without a consumer (`budget.hVol`, `volSamples`, asserted by Reference.spec :113–114 and :132–133
and Analyze.spec :570, :639, :661). It stopped `THICK_BUDGET` from being a cap: 24 kept 1.0 × 3.5 × 0.4 blocks take 480
probes on the last rung. None of this arises with the stride.

**D2, as now proposed.**

- **(i), recommended for M3.** Keep §5.2's stride, walked in rank order. At the same budget it is more accurate than
  D2's grid, it gives §5.5's numbers, and it passes E-S2.10's cuts and C12 vs C02 exactly (`verify/v_m3.luau -- cuts`).
  - **§14.6 T-DIF-07:** "flush re-segmentation of a straight, symmetric blade along its length (E-S2.10's F5 cuts, C12
    vs C02) gives …; on general designs the change is reported (§17.2)". A θ-safe scope would not be enough:
    Asymmetry's grid still moves G 0.0045 on #55.
  - **§5.6 :1252:** the same scope.
  - **§17.2:** the measured sensitivity on general designs. Thinness \|Δx\| up to 0.059 and G up to 0.024 on 300
    designs, through θ, Asymmetry's grid and the stride. An invisible construction choice can therefore move a step by
    up to about 0.024, a tier only within that distance of 0.2.
- **(ii), a separate study before any playtest, if Louis wants the general contract.**
  - The redesign: θ by union chord, a per-part grid whose budget is sized against FINE and costed against R2, and an
    Asymmetry grid that does not depend on the part count. Accept it only on `FUZZ_N_VALID` = 500 designs.
  - One data point (`critic_proto.luau -- t3:…`): τ = min over world Z and the owner's 3 local axes brings FINE's
    re-segmentation change down to 0.0031. D2 still moves 0.0123 (Ha) and 0.0193 (Sh), the stride jumps to 0.396,
    and the rule raises wedge-heavy designs.
  - With FINE, P3's Hammering goes 0.1804 → 0.2724 and P5's 0.1902 → 0.2171: **both cross to Hard**. F and C
    fixtures move ≤ 0.0021.

---

## 8. Risks, SPEC inconsistencies and gaps, order of work

### 8.1 Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | The verdict replacement is in flight. Cleaned lists (P1's Giant2 at 2.04 % true), verdict cost and Sampling's line numbers will move | build Edge, Factors and Difficulty first (they read only the interface); bless every golden after the merge; re-run §7.3's sweep after it |
| R2 | Cost. WorstP reaches 54.6 ms Lune against `ANALYSIS_LUNE_MAX_MS` 60 (E-S2.11 :529; M3 emulated at 4–16 ms). The real M3 code and the new verdict reading (unknown) can cross 60 | profile per phase (raster, factors); charge DP; if a real overrun remains it is a designer decision: raise the guard (SPEC.md:4290) or accept with §4.9's Decision to confirm. Option B (up to +23 %) only if Louis picks it |
| R3 | T-DIF-07(b) fails on `Gen.segmented` under every probe rule (measured, §7.5) | D2 (i): narrow the assertion, report the rest, record the sensitivity; (ii) is a separate study |
| R4 | §5.5 values move: C09 0.3170 → 0.3186 (rank order). No tier changes | update the §5.5 and E-S2.9 rows with the evidence at blessing |
| R5 | Float order differs from the prototype: Sharpening's weight order, rank-order sums, owned volumes within 4e-15 | compare five factors bit for bit, Volume/SC/Joints within 1e-12, g/d to ±1e-4; goldens come from the build |
| R6 | S-PAR-02 in Studio: execute_luau running time; `Client` datamodel behaviour; the StringValue name of a `.digest.txt`; `%.17g` formatting | yields per design; `GROUP` split; check the golden's name first; FakeRoblox dry run |
| R7 | Timing noise from other agents | run T-PERF-01 alone; median of 15 |
| R8 | luau-lsp widening of singleton unions (M1-notes.md:56) | annotate |
| R9 | Fixture literals carry this machine's libm bits | never recompute trigonometry in fixture modules; FixtureSet compares with the prototype only in Lune on this machine |
| R10 | `CHECK_UNITS` 250 doubles checkpoint counts | update Analyze.spec :640 and :761 |
| R11 | Edge's Douglas–Peucker is O(n²) and was charged once per run in the prototype | charge per split |
| R12 | `measureInvalid` with empty work sets (D5) | `steps = nil`; §4.7 note |
| R13 | `--quick` past §14.1's 30 s | time it after M2's commit and after step 9; cut the fast Gen corpora first, keep the goldens |

### 8.2 Where the repo and the SPEC already agree

- All M3 constants exist with §16's values.
- `Shapes.chord` and `Sampling.volumeSamples` equal the prototype's.
- `MassProps.difficultyFrame` returns axis {0, 1} and iterates the list it is given.
- `Steps` stores weights in FactorId order (M1-notes.md:21).
- `Tiers.tierFor` and `tierRawFor` exist (M1-notes.md:18).
- Phase 5 samples kept parts only.
- `EquipmentTypes.spec.luau:83–87` already ties the refs Thinness row to `SIGMA_LO/HI`.

### 8.3 SPEC inconsistencies and gaps (with the lines)

1. **T-EDG-01, T-DIF-12 and T-DIF-13 are undefined.** SPEC.md:3497 lists "T-EDG-01, T-DIF-01…13"; E-S8.5 :1809 says
   "10–13 as §14.6"; §14.6 :3512–3517 defines only T-DIF-03, 04/05, 07, 10 and 11. Definitions are proposed in §5.
2. **X08 has no construction.** E-S8.4 :1784: "X08 | 24 rotated cylinders; 24 hitbox-sized blocks; sawtooth blade;
   256-point zigzag edge". Proposal: alias P2, P1 and P5, and move the zigzag to M4 (§4.1).
3. **Part order or rank order.** SPEC.md:830: "sums in part order, then sample order"; §5.2 :1139: "every k-th volume
   sample of W (part order, then sample order)". §17.2 :4347: "M3 is to walk its parts in rank order (`Sampling.ranked`),
   §5.2's probes and budgets included". Edit :830 and :1139 to "rank order".
4. **The re-segmentation contract against §5.2's definitions.**
   - §14.6 :3514–3515 asks \|Δx_f\| ≤ TOL_FACTOR_ABS and \|ΔG\| ≤ TOL_G_INVARIANT for flush re-segmentation in
     general. §5.6 :1252's evidence is F5's straight blade only (E-S2.10 :393).
   - On general designs no probe rule meets it. θ (SPEC.md:1143) is the owner part's thinnest local axis, which a cut
     can change. Asymmetry's spacing (SPEC.md:1156–1157, "coarsened within ASYM_WORK") depends on the candidate
     counts. Then comes the stride (SPEC.md:1139).
   - D2 (§7.5).
5. **The design question names only Thinness.** SPEC.md:4349: "because cleaning it opens the chord in Thinness. M3 decides
   how a cleaned part affects Thinness' chords". §7.1: S_exp carries most of the jump, Volume adds to it, and no M3-side
   rule closes the class (§7.3). D1.
6. **σ's range is stored twice.** §16 :3740 says "no constant appears twice", yet §16.5 :3807 has "refs Thinness | σ
   45–130" and §16.10 :3887 has "`SIGMA_LO`, `SIGMA_HI` | 45, 130". `EquipmentTypes.spec.luau:83–87` already asserts that
   they agree; only the wording remains.
7. **`measureInvalid` is underspecified.** SPEC.md:1027 says `steps: { StepAnalysis }?, -- nil while invalid`, with no
   word on it, and `material: MaterialId` (:1021) is non-optional, although an empty work set has no governing material.
   D5.
8. **P4 against §14.7.** SPEC.md:3527–3528 requires every part ≥ 0.02 inside the hitbox for "the cost fixtures X08 (S8,
   E-S8.4) and P1–P5". P4 measures 0.01 (dump header).
9. **The perf assertion basis.** SPEC.md:3604 reads "every checkpoint gap ≤ CHECKPOINT_GAP_LUNE_MS", while E-S2.8 :262–276
   and the M2 notes use medians of 15; single-run gaps reach about 1.0 ms with GC (§17.2 :4341). Write "median of
   `PERF_RUNS` runs".
10. **The digest file.** SPEC.md:3430 names "`.digest.txt` ≤ 1 KB for Studio"; `tests/lib/Golden.luau` writes only
    `.golden.txt`. Add `Golden.digest`.
11. **T-DIF-03's literal.** SPEC.md:3512 "D = 0.1999999999 is Normal" can only be tested on `Tiers` directly, because
    every produced D is on the 1e-4 grid (§5.1 :1117), where q(0.19995) = 0.2.
12. **T-DIF-04's dust bound.** "dust gives \|ΔG\| ≤ TOL_DUST_G" (:3514) is weaker than what the build guarantees: Dust is
    inert, so D is bit-identical. Assert bit-identity, and update A14's fixture expectation (Adversarial.luau:576).
13. **S-PAR-02's subject.** E-S8.6 :1874 digests `Pipeline.analyze`; at M3 the subject is `Analyze.run`. Name the golden
    `parity.bv1` and let M5 extend its keys.
14. **CHECK_UNITS.** §4.9 :1066 says `CHECK_UNITS = 500` while §17.2 :4341 expects it lowered. Whatever T-PERF-01
    decides goes into §16.18 :4116.
15. **E-S8.4 against the fixtures** (A10, A12, A19). M1-notes.md:54 and :85 already settled these; no M3 action.
16. **`measureInvalid` in the preview.** SPEC.md:862–863 says `opts.measureInvalid` "lets the editor preview measure
    anyway", but §11.13 SPEC.md:2821 calls `Pipeline.analyze(core, {checkpoint = slice})` without it. §14.11's "P1–P3 +
    a Dust speck", built as E-S2.11 built it (floating, so `Disconnected`), is measured only under `measureInvalid`.
    T-PERF-01 runs both the floating and an attached speck. Settle :863 with S6.
17. **Mirror images and D.** §17.2 :4347 says a mirror image keeps every verdict; D is not claimed equal, and it is not.
    The stride visits the mirrored samples in another order: each part's local frame is mirrored, and the rank key's cx
    sign decides between parts that tie on |cx|. The main chain also opens at another vertex. §4.6 :981's
    "mirror-symmetric cells" holds for the raster only. T-DIF-08 asserts what §14.6 asks and reports the rest.

### 8.4 Order of work

1. **Preconditions.** M2 committed, its S-PAR-01 green, and the verdict replacement merged and verified. If the merge
   lags, steps 3–6 can start, since Edge, Factors and Difficulty use only the interface. Write
   `docs/build/M3-notes.md` as you go (format of M1-notes.md). Time `--quick` once M2 is committed.
2. **Settle D1–D6.** Record them as **[Decision to confirm]** in SPEC.md:
   - §4.1 :830 and §5.2 :1139 ("rank order");
   - §4.7 (measureInvalid) and §5.6 (:1252's scope);
   - §14.6 (T-DIF-07's scope, T-DIF-12/13), §14.7 (P4) and §14.11 (median);
   - §16.18 and §16.32 (the new Tol rows);
   - §17.2 (:4349's decision with §7.3's sweep; the re-segmentation sensitivity).

   Record the X08 aliases in E-S8.4 and the test definitions in E-S8.5.
3. **Fixtures** (§4): Calibration, Regression, Cost (both specks), WorstP, the A25–A27 cases, A14's expectation,
   Parity, `Build.YM90`. FixtureSet specs for canonical form, margins (−1e-12) and the bit-for-bit port. Replace `H.p1` and
   `H.ornate`. Verify green.
4. **`Edge.luau`** and T-EDG-01. Compare with `Proto.run(…).edge` on every fixture but P1.
5. **`Factors.luau`** (cbrt, unionChord, Thinness with the stride over phase 5's samples, Asymmetry, Joints…), unit tests
   T-DIF-01/06/08 and the factor-level prototype comparison that replaces Reference.spec :161–175.
6. **`Difficulty.luau`** with T-DIF-02, 03 and 05.
7. **`Analyze.run` integration** (§1.5): the rank-ordered difficulty frame, `probes` in the context, types re-exported,
   `measureInvalid`, phases. Update Analyze.spec :620–641, :692–720, :722–762, :833–862 and the P1 budget case (:657).
8. **Only if Louis picks option B:** the void rule in Sampling's measure plus `VOID_GAP` (Balance, Balance.spec,
   §16.10, fingerprint re-bless), after the verdict merge, accepted on §7.4's sweep.
9. **T-DIF-04, 07, 09, 10, 11 and 13**, then T-DIF-12: review against §4.3, bless, and edit §5.5/E-S2.9 (C09). Time
   `--quick` and cut the fast Gen corpora if needed (§5).
10. **Reference.spec retirements** (§6).
11. **T-PERF-01**, D3, and the §16.18 edit.
12. **S-PAR-02.** `Golden.digest`, the Tol constants, Parity.spec (slow), SPar02.spec on FakeRoblox, then the Studio
    snippet, run in 3 fresh Play sessions × Server + Client.
13. **Close.** `lune run scripts/verify` green in full, with `t.slow` (§14.1). README Status. Independent verification.
    Commit "M3: difficulty …" with the attribution line from the session reminder, one commit per verified milestone.

---

## 9. Critique disposition (`critique.md`)

Each point was checked against the sources. Where it rested on a run, its worst case was re-run here, one short Lune
process at a time (`verify/out_verify.txt`). Nothing in the repo or in Studio was touched.

| Point | Disposition | What changed |
|---|---|---|
| C1 D2 does not make T-DIF-07 pass; the stride is not the main cause | **Taken.** Re-ran #51 (θ flip: Thinness 0.0591 / 0.0513 / 0.0476, G 0.0236 / 0.0205 / 0.0191), #152 and #55 (Asymmetry 0.0197 / 0.0147 in every variant). Verified option (i) here: F5's 2/3/7 cuts and C12 vs C02 give \|Δx\| < 1e-6, \|ΔG\| 0 with the stride in rank order | D2 rewritten as T-DIF-07(b)'s scope (§0, §5, §7.5, §8.3 item 4, R3, §6). "Passes with D2" and "the cause is the stride" withdrawn |
| C1's data point for (ii) | **Taken, with one addition.** P5's 0.1902 → 0.2171 is also a tier (N → H), not only P3's (t3:fixtab re-run) | §7.5 |
| C2 D2 at 400 is less accurate than the stride; phase 5 orphaned; `THICK_BUDGET` not a cap | **Taken** (#117 re-run: 0.1414 / 0.0566). Moot once D2 is withdrawn; kept as the conditions any (ii) grid must meet | §7.5, §1.3.1 (the stride keeps `hVol`/`volSamples` meaningful and probes ≤ `THICK_BUDGET`) |
| C3 option B does not remove the 2 % tier flips; "can only lower D" is false; option C row wrong; cost understated | **Taken.** The critique's `lam` was re-run, and option 0 was added on 9 sandwiches (`lam0`): option 0 flips 6, B 5. B therefore does not dominate, and the recommendation moves to option 0. Option C's row is corrected (one tier). Cost restated as −12 % to +23 % | D1, §7.2–7.4, §3 (no `VOID_GAP`), §8.4 step 8 conditional |
| C3, two wordings | **Qualified.** (1) "§17.2's own sandwich with 0.03 cheeks" is a variant: §17.2's design has 0.06 cheeks (LAM1, SPEC.md:4343), where B does remove both flips. (2) "B alone and D1 + D2 give identical numbers" holds after cleaning and for every flip, but not in the kept state (LAM2 K Hammering 0.0897 vs 0.0876) | §7.3 wording |
| C3's fix "if B is kept, make its acceptance set a sweep…" | **Taken, conditionally.** It applies only if Louis picks B | §7.4 |
| C4 mirror claims fail (T-EDG-01 item 6, T-DIF-08) | **Taken.** Re-ran Gen #31: 6.935592 / 11 points against 6.915188 / 9, same raster. Item 6 now asserts the raster mirror and gives EdgeLength `TOL_EDGE_REL`; T-DIF-08 reports whole-design mirror \|ΔD\| | §1.2, §5 T-EDG-01 item 6, T-DIF-08, §3 `TOL_EDGE_REL`, §8.3 item 17 |
| C4's alternative "make the opening vertex and DP ties mirror-symmetric and re-bless" | **Rejected.** A traversal that runs the other way cannot be made symmetric by a tie rule alone, and changing the rule would end the bit-for-bit comparison with the reference prototype and E-S2.9's edge column (T-EDG-01 item 2) for a 0.3 % effect | §1.2 |
| C5 T-DIF-07(c) "edge bit-identical" fails on `gripPoint` | **Taken, with a different fix.** `critic_build.luau` re-run (6 of 24 orders). No MassProps edit is needed: `difficultyFrame` iterates the list it is given, so Analyze passes `byRank` with a `kept` array indexed the same way. Physics stays in blueprint order and is compared within 1e-12 under (c) | §1.2, §1.5, §5 T-DIF-07(c) |
| C6 bit-for-bit factor comparison | **Taken.** Volume, SurfaceComplexity and Joints within 1e-12. Joints may well be bit-identical (it reads part volumes and contact rows), but 1e-12 costs nothing | §1.4, §6 |
| C6 T-EDG item 2 "on the same kept row" | **Taken.** The reference exports only `run` (checked); compare `Proto.run(…).edge` on every shared-verdict fixture, P1 blessed alone | §5 T-EDG-01 item 2 |
| C6 `Edge.mergedLength` fails P-NOMUT | **Taken.** The export sorts a copy | §1.2, §2 |
| C6 A14's expectation | **Taken.** Adversarial.luau:576 → `d = "BitIdentical"` (no mass relation: Dust counts for mass) | §4.2, T-DIF-04, §8.3 item 12 |
| C6 EdgeLength cap names no design | **Taken.** A cap case is built in T-DIF-01, which checks E ≥ 8 before asserting x = 1 | §5 T-DIF-01 |
| C6 C08's margin | **Taken** (re-run: 0.019999999999999574). Keep `>= 0.02 - 1e-12` | §4.2 |
| C7 §5.6 rows without an assertion | **Taken.** 4 flush plates in F5 / C02 / C05 go to T-DIF-04 (Verdict.spec.luau:349's construction); C10/C11 vs C01 ≤ 0.008 goes to T-DIF-13 | §5 |
| C7 §14.1's 30 s gate | **Taken.** M1's 11.9 s is the baseline; time it twice; the fast Gen corpora are cut first, the goldens stay | §5 intro, R13, §8.4 |
| C7 the Dust-speck cases | **Taken, qualified.** The attached speck is added as the production path, and the floating one is kept for E-S2.11's numbers. "Production never measures a disconnected design" holds for §11.13's call, but SPEC.md:863 says the preview may pass `measureInvalid`; noted as a SPEC gap | §4.1, T-PERF-01, §8.3 item 16 |
| C7 P1 twice in T-PERF-01 | **Taken.** Run once, under both names | T-PERF-01 |
| C7 Factors' require list lacks Limits | **Taken** | §1.1 |
| C7 the σ test already exists | **Taken.** No new test | §1.3, §8.2, §8.3 item 6 |
| C7 T-DIF-06 under D2 (0.2073) | **Moot.** With the stride, the sweep re-run gives E-S2.2's 0.2070 and 0.2056, so §5.5's prose stands | §4.3 |
| "Checked and correct" | No action | — |
