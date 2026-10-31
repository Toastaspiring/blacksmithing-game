# RULINGS — shared contract for the final SPEC.md

Written by the lead after triaging the 203 review findings. Read fully before revising. Order of authority:
**this file > review/verdicts.md > the finding's proposed fix > your draft > BRIEF.md**.

## 0. Paths and tools

- Spec folder: the folder holding this file. Outputs go to `final/` inside it.
- Lune 0.8.9: `C:/Users/louis/.aftman/tool-storage/lune-org/lune/0.8.9/lune.exe` (call it directly: `<exe> run <file> -- <args>`).
- Rojo 7.7.0-rc.1: under `C:/Users/louis/.aftman/tool-storage/rojo-rbx/`.
- Repo (read-only for you): `C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game/`.

## 1. Fragment map, subsection ownership, size budgets

SPEC.md section order is fixed. Each reviser writes the files in its row. Budgets are soft caps in KB (UTF-8)
for the main fragment; evidence goes to `final/appendix-<S>.md`.

| § | Title | Fragment file(s) | Writer | Budget |
|---|---|---|---|---|
| 0 | Summary, scope, changes from the draft, decisions to confirm | written at assembly | assembler | 8 |
| 1 | Architecture | `final/01-architecture.md` | S5 | 8 |
| 2 | Domain model and Definitions | `final/02-domain.md` | S1 | 12 |
| 3 | Blueprint format | `final/03a-blueprint-data.md` (S1), `final/03b-blueprint-geometry.md` (S2) | S1 + S2 | 9 + 7 |
| 4 | Geometry pipeline | `final/04-geometry.md` | S2 | 16 |
| 5 | Difficulty | `final/05-difficulty.md` | S2 | 10 |
| 6 | Minigames | `final/06-minigames.md` | S3 | 20 |
| 7 | Crafting pipeline | `final/07a-crafting-rules.md` (S4), `final/07b-craft-protocol.md` (S5) | S4 + S5 | 6 + 8 |
| 8 | Item outcome | `final/08-outcome.md` | S4 | 10 |
| 9 | Persistence | `final/09a-persistence-data.md` (S1), `final/09b-persistence-lifecycle.md` (S5) | S1 + S5 | 10 + 5 |
| 10 | Networking and anti-cheat | `final/10a-networking.md` (S5), `final/10b-replay-checks.md` (S3) | S5 + S3 | 12 + 5 |
| 11 | Client: blueprint editor | `final/11-editor.md` | S6 | 18 |
| 12 | Client: forge flow, minigame UI, results | `final/12-forge-ui.md` | S6 | 10 |
| 13 | Smithy world, displays, item rendering, inspect | `final/13-smithy.md` | S7 | 14 |
| 14 | Testing and verification | `final/14-testing.md` | S8 | 12 |
| 15 | MVP non-goals and phase hooks | merged from `final/<S>-rows.md` | assembler | 5 |
| 16 | Constants reference | merged from `final/<S>-rows.md` | assembler | 14 |
| 17 | Open questions | merged from `final/<S>-rows.md` | assembler | 4 |
| 18 | Implementation milestones | `final/18-milestones.md` | S8 | 3 |

Single-owner sections (1, 2, 4, 5, 6, 8, 11, 12, 13, 14, 18): the fragment starts with the `## N. Title` heading.
Shared sections (3, 7, 9, 10): the assembler writes the `##` heading; each writer writes only its assigned
`###` subsections, with exactly these numbers and titles (adjust a title's wording if needed, never the number):

**§3 Blueprint format**
| # | Subsection | Writer |
|---|---|---|
| 3.1 | Blueprint space and the Sword hitbox | S2 |
| 3.2 | Shapes and per-shape size rules | S2 |
| 3.3 | Record schema (Luau types) | S1 |
| 3.4 | Transform representation and Roblox conversions | S1 |
| 3.5 | Canonical form and storage precision | S1 |
| 3.6 | Structural limits and wire sanitization | S1 |
| 3.7 | Slots and part limits | S2 |
| 3.8 | Mirror math | S2 |
| 3.9 | Names and text rules | S1 |
| 3.10 | Network shapes and sizes | S1 |
| 3.11 | Module APIs (Blueprint/*) | S1 |

**§7 Crafting pipeline**
| # | Subsection | Writer |
|---|---|---|
| 7.1 | Step plan (CraftPlans) | S4 |
| 7.2 | Work sets and the governing material | S4 |
| 7.3 | Session rules | S4 |
| 7.4 | Failure, timeout and abandon effects | S4 |
| 7.5 | Crafting history semantics (schema lives in §9 Item record) | S4 |
| 7.6 | Craft session state machine | S5 |
| 7.7 | Craft protocol: requests, replies, pushes | S5 |
| 7.8 | Step timing and deadlines | S5 |
| 7.9 | Finalize and item commit | S5 |

**§9 Persistence**
| # | Subsection | Writer |
|---|---|---|
| 9.1 | Store, key and session lifecycle | S5 |
| 9.2 | Data rules (ProfileStore / DataStore) | S1 |
| 9.3 | Profile.Data types and template | S1 |
| 9.4 | Item record: frozen facts vs derived values | S1 |
| 9.5 | Quantization of persisted numbers | S1 |
| 9.6 | Versioning, migration and the load pipeline | S1 |
| 9.7 | Saving, budgets and failure handling | S5 |
| 9.8 | Size budgets and caps | S1 |
| 9.9 | Invariants | S1 |

**§10 Networking and anti-cheat**
| # | Subsection | Writer |
|---|---|---|
| 10.1 | Transport, channels and envelope | S5 |
| 10.2 | Request catalogue | S5 |
| 10.3 | Validation (Guard) and error codes | S5 |
| 10.4 | Rate limits and kicks | S5 |
| 10.5 | Minigame replay and verdicts | S3 |
| 10.6 | Impossible and inhuman input checks | S3 |
| 10.7 | Timing checks | S5 |
| 10.8 | Text filtering | S5 |
| 10.9 | Telemetry and logging | S5 |
| 10.10 | Threat model and residual risks | S5 |

## 2. Shared contract (overrides every draft)

Findings referenced as `R1-03` etc. are in `review/findings-all.md`. Where this section and a finding's proposed
fix differ, this section wins. **[DtC]** = decision to confirm: keep the stated default, mark it
**[Decision to confirm]** in your text, and list it in your §17 rows with the §0 question number (§3 below).

### 2.1 Naming
- Every plain-data **field** (persisted records, wire payloads, Definitions rows, module result records) is
  **camelCase**: `id`, `slot`, `shape`, `material`, `pos`, `rot`, `size`, `blueprints`, `balanceVersion` (R7-07).
  This is the Roblox Lua style guide and the user's Combat System style; S1 renames its PascalCase fields.
- Id **values** stay PascalCase strings (`"Sword"`, `"Blade"`, `"Steel"`, `"HoldZone"`, `"Hard"`, `"Epic"`).
- Module files and exported types are PascalCase; functions and locals camelCase; constants UPPER_SNAKE.
- Booleans are `passed`, never `pass`. Stats are keyed by StatId values (`stats.Damage`).

### 2.2 Module map (authoritative; R7-04 with the rulings below)
P = pure (Lune-tested, no Roblox APIs); RB = Roblox-bound. `[owner]`. An owner may add private helpers inside its own
folder; any new cross-section module goes in your notes as a cross-section request.

`src/shared` → `ReplicatedStorage.Blacksmith`
- `Definitions/` P: `Types, Catalog, Versions, Limits, Materials, EquipmentTypes, Steps, Tiers, Rarities, Stats, Balance, Validate, Manifest` [S1 shapes; values from S2/S3/S4], `MinigameFamilies` [S3], `CraftPlans` [S4], `Network` [S5], `World, Presentation` [S7], `Audio` [S6].
- `Util/Quantize` [S1] P (scalar quantization only); `Util/Signal` [S5] RB.
- `Blueprint/` P: `Schema, Canonical, Quat, Names, Views` [S1], `Mirror` [S2 math; S6 wraps it], `WorkSet` [S4].
- `Physics/` P [S2]: `Shapes, Gjk, Sampling, MassProps, Edge, Factors, Difficulty, Analyze`.
- `Minigames/` P [S3]: `Minigames` (facade), `Types, Rng, Params, Timeline, Checks, Input, HoldZone, TimingStrike, PrecisionTrace`, `Bots` (the player models, §2.16).
- `Crafting/` P [S4]: `Types, Plan, Quality, Rarity, Stats, Outcome`.
- `Pipeline` P [S2 with S4] (§2.12).
- `Items/` P [S1]: `Schema, Create, Recompute`.
- `Persistence/` P [S1]: `Types, Template, Migrations, Prepare, JsonSafe, Settings`.
- `Session/SessionMachine` P [S5].
- `EditorCore/` P [S6]: `EditorState, Commands, History, Snap, Rotation, GizmoMath, Expr, EditorLayout`.
- `World/Layout`, `ItemRender/RenderPlan`, `Showcase/ShowcaseRules`, `Showcase/InspectView` P [S7]; `ItemRender/ItemModelBuilder` RB [S7].
- `Net/Protocol, Net/Guard, Net/RateLimit` P [S5]; `Net/Remotes, Net/Client` RB [S5].
- `Remotes` (4 RemoteEvents: Profile, Blueprint, Craft, Showcase) declared in the Rojo project (e.g. `Remotes.model.json`, R5b-12).

`src/server` → `ServerScriptService.BlacksmithServer` (RB): `Main.server, Lifecycle, Config, Log, Telemetry, Safe, TextFilter, Router, Handlers, DataService, BlueprintService, AnalysisQueue, CraftService, PlotService` [S5]; `ShowcaseService, World/WorldBuilder, World/PlotWorld` [S7]; `Vendor/ProfileStore` (project mapping).

`src/client` → `StarterPlayerScripts.BlacksmithClient` (RB): `Main.client, UI/*, Input/*, Editor/*` (controllers, stage, gizmos, panels, PreviewScheduler), `Forge/*, Minigames/{MinigameHost, InputCapture, views}, Inventory/*, Onboarding/*` [S6]; `Smithy/{PromptController, StationStage, StationFx, InspectPanel, PlotPresence}` [S7].

`tests/` (one folder per `src/shared` folder plus `Meta/`, `lib/`, `fixtures/`, `golden/`, `studio/{bridge,e2e}`), `scripts/verify.luau`, `tools/` [S8].

### 2.3 Layering and requires (R7-01, R7-10)
- Every module that runs under Lune lives in `src/shared`. `src/client` and `src/server` hold only RB code.
  No string require crosses a Rojo root. `tests/lib` requires nothing in `src/`; specs pass game modules in.
- Layers, each requiring only lower ones: Definitions → Util → Blueprint → Physics → Minigames / Crafting → Pipeline →
  Items / Persistence / Session / EditorCore / Showcase / ItemRender → RB services and controllers.
  Cross-layer calls upward go through injected callbacks, never requires (no cycles; Roblox errors on them).

### 2.4 Core types (owner S1, `Blueprint/Schema`; nobody redefines them)
- `Vec3 = {number}` array `{x, y, z}`; `Quat = {number}` array `{qx, qy, qz, qw}` (w last = `CFrame.new` order).
- `PartData = {id: number, slot: SlotId, shape: ShapeId, material: MaterialId, pos: Vec3, rot: Quat, size: Vec3}`.
- One quaternion module, `Blueprint/Quat` (S1): `toMatrix` (s = 2/|q|²), `fromMatrix`, `normalize`, hemisphere
  rule. S2's math, S6's Euler display (`EditorCore/Rotation`) and S7's rendering all call it (R1-17, R7-02).
- Every other shared type has exactly one owner per R7-07: ids → `Definitions/Types`; blueprint records →
  `Blueprint/Schema`; item and step records → `Items/Schema`; analysis → `Physics/Analyze`; StepSpec /
  MinigameResult → `Minigames/Types`; CraftPlan / Outcome → `Crafting/Types`; InspectView → `Showcase/InspectView`;
  wire-only types → `Net/Protocol` (re-exports, never copies).

### 2.5 Transforms: raw doubles, one canonical form (R1-04, R2-01, R4a-01, R7-02, R2-02, R1-16, R4a-20, R3-14)
- **No storage grid.** Positions, sizes and quaternions are stored and sent as raw finite doubles. S1 deletes the
  1e-4 / 1e-6 grid and its rationale; derived scalars are still quantized (§2.9).
- One canonical form (`Blueprint/Canonical`, S1; S2 supplies per-shape hooks), applied by the editor on every commit
  and re-applied by the server, idempotent: finite numbers; bounds checked and **rejected, never clamped**;
  quaternion renormalized only if `|‖q‖² − 1| > 1e-9`, then the hemisphere rule; Ball sizes uniform, Cylinder
  Y = Z (editor enforces these at edit time, so the hook is a no-op for honest data); parts sorted by `id`.
  The stored, analysed and rendered design is exactly what the player built. S2's sanitizer is removed.
- Bounds (one table in `Definitions/Limits`; S1 owns the table, S2 owns the MIN/MAX_DIM values):
  `POS_ABS_MAX = 16` stud per component (keeps every part inside S6's ×4 editor stage; 64 would not fit);
  `MIN_DIM = 0.02` **[DtC Q4]** (S2 verifies with its prototype after the factor fixes; if 0.02 breaks
  measurement, S2 sets the smallest value that works, at most 0.05, and shows the measurement);
  `MAX_DIM = 6.0`; `MAX_PARTS = 24` = the structural cap (S1's 48 placeholder goes); slot maxima are validation rules.
- Tolerances: `EPS_CONTAIN = 1e-4`, `CONTACT_TOL = 0.01`; S1's "≥ 1e-3" requirement goes (R4a-18).
- The editor clamps every transform path (drags, typed values, nudges, mirror, shape change) to these bounds
  visibly; a server rejection of an editor value is a logged bug.

### 2.6 Ids (R1-03, R5b-03)
- `BlueprintId` = client-minted GUID (`HttpService:GenerateGUID(false)`), upper-cased and format-checked by the
  server; `Blueprint.Save` is an upsert keyed by it. `ItemId` = the craft session GUID. NextIds goes.
- Definition ids are PascalCase and append-only (retire with `enabled = false`).

### 2.7 Store, versions, load pipeline (R5b-06, R1-22, R5b-04, R5b-05, R7-09, R7-18)
- `ProfileStore.New("PlayerData", template)`, key `"User_" .. userId` (Roblox's recommended pattern for automated
  right-to-be-forgotten); the README/build checklist adds configuring the Creator Dashboard deletion template.
  No `_v1` suffix.
- Versions: `DATA_VERSION`, `BLUEPRINT_SCHEMA`, `BALANCE_VERSION`. **GEOMETRY_VERSION and GeometrySummary are
  dropped** (R7-18, R2-11): BALANCE_VERSION covers any outcome-affecting data or code.
- S5 calls S1's `Prepare.run` right after the session starts; it works on a deep copy, then swaps `profile.Data`;
  nobody calls `profile:Reconcile()`. A corrupt profile is never written: end the session without mutating and
  kick with a clear message; unreadable records go to `quarantine` (R5b-05).

### 2.8 Profile.Data (owner S1; camelCase)
`dataVersion, blueprints {[BlueprintId]: BlueprintRecord}, items {[ItemId]: ItemRecord},
smithy {level, displays {D1..D6 → ItemId}}, settings, uiFlags {[string]: boolean}, quarantine, starterGranted`.
- `settings` = S1's base editor prefs trimmed per R2-09 (per-type snap on/off + step; no per-axis, no absolute
  mode, no user presets) + `reducedMotion` + `timingOffsetMs` (§2.17) + `sfxVolume` (§2.28).
  `Persistence/Settings.sanitize(raw)` rebuilds it from the schema (R1-05, R3-11).
- Persistent `Counters` are cut (R2-11, R1-44); `starterGranted` replaces their onboarding use (R6-01).
- Caps stay **40 blueprints / 150 items** (raw doubles at 24 parts ≈ 40 % of the 4 MiB key); S1 re-measures with
  GUIDs and raw doubles and keeps the worst case ≤ 50 % (R4a-15 modified).

### 2.9 Item record (R1-20, R7-08; owner S1 `Items/Schema`, content from S4)
- One `StepRecord = {step, family, tier, difficulty, material, seed, score, passed, timedOut, durationMs, flags}`
  (`difficulty` is D_s). One outcome block `outcome = {stats, quality, materialTier, rarity, rarityByScore,
  rarityCap, capStep?}`. `atForge = {balanceVersion, quality, rarity}`. Plus `id, name, type, crafterUserId,
  createdAt, blueprint (snapshot), steps, physics, balanceVersion`. No per-step balanceVersion, no breakdown.
- Constructor `Items/Create.fromCraft(...)` (S1), called by S5's finalize; it replaces S4's `Outcome.record`.
- Recompute: one pure path, `Items/Recompute.item(item)` = `Pipeline.analyze(snapshot)` → `Plan.fromHistory`
  (current weights renormalized over the recorded steps; CraftPlans rows are append-only, R2-06) →
  `Outcome.compute` → `Create`. Run lazily through the AnalysisQueue when a stale item is rendered, inspected or
  fetched. Rarity floor = `atForge.rarity` (never the max of earlier recomputes, R3-19) **[DtC Q19]**.
- Quantization of derived scalars (R1-39, R4a-19, R7-20): D, scores, Q, T and stats at 1e-4 with the one function
  `Util/Quantize.q(x, 1e4)` (`math.round(x·1e4)/1e4`); quantize at production, before thresholds.

### 2.10 Definitions (R1-18, R7-06, R2-07, R1-47)
- Catalog rows are camelCase records in **ordered arrays**; consumers iterate the ordered lists, never `pairs`.
  Field owners: S1 identity, physical and render values; S2 `difficultyTerm`, factor weights, geometry rules;
  S3 family parameters, including the material and tier columns (S1 drops FamilyModifiers/FamilyMultipliers);
  S4 CraftPlans, `qualityTier` (T), `qualityMultiplier` (d), caps, rarity thresholds, stat constants;
  S5 Network; S6 Audio; S7 World and Presentation (render values come from S1, S7 consumes them).
- Materials: hardness and toughness are integers 0–100; formulas use `/100` (R1-19, R4a-12).
  MVP values Iron 7.87 / 45 / 50, Steel 7.85 / 70 / 55 **[DtC Q13]**.
- **Material term in D_s: `difficultyTerm` = 0 for both Iron and Steel in the MVP** (R4a-14 option b) **[DtC Q13]**:
  materials are free, so a tier-raising material would be a difficulty slider (design draft: "players are pushed
  toward bold designs instead of a difficulty slider"). The m_s machinery stays for Phase 2+ materials. Steel
  still plays tighter minigames (S3's material columns) and gives T = 1.10 (S4). Correct every example and
  calibration table that assumed m_Steel = 0.10.
- Governing material of a step = the kept work-set material with the highest `(difficultyTerm, hardness)`, ties by
  Materials order (so Steel governs a steel blade in the MVP). It drives m_s and S3's m_material.
- One BALANCE guard (R1-36, R7-23): `Definitions/Manifest` (S1) lists every outcome-affecting table (S2/S3/S4
  data included); S8's fingerprint test hashes it.

### 2.11 Craft plan and work sets (R1-14, R2-07)
`Definitions/CraftPlans` (S4) is the single source: per equipment type an ordered, append-only list of
`{step, weight, worksOn = "All" | {SlotId}, feeds = {StatId}, enabled}`. MVP Sword: Smelting 0.25 All,
Hammering 0.40 All, Sharpening 0.35 {Blade}. Work sets contain kept parts only. `Blueprint/WorkSet` is the selector
both Physics and Crafting use. S1's StepDef loses AppliesTo/QualityWeight/MainStat; S2 drops StepRule.workingSet.

### 2.12 Pipeline and the analysis hand-offs (R7-05, R1-12, R1-13, R1-34)
- `Pipeline.luau` (S2 writes it, S4 co-owns the plan/preview parts) is the only composition used by the editor
  preview, BlueprintService, CraftService, recompute and tests: `analyze(core, opts?) → Report`;
  `quick(core)` (structural + containment, every edit); `summary(report) → BlueprintAnalysis`;
  `stepInput(report, stepIndex, seed) → Minigames.PrepareInput`.
- S2's Analysis exposes camelCase names: `physics = {mass, reach, balance, gripPoint, …, kept, ownedVolume}`,
  per-step `{step, g, m, d, tierRaw, tier, material, terms, factors}` with every factor's value on that step's work
  set, and `edge = {chains, length, …}`.
- S3's m_design uses the step's own factor values, restricted to the factors in that step's S2 weight list
  (Hammering: Thinness, Asymmetry, SurfaceComplexity; Sharpening: SurfaceComplexity, Asymmetry, with EdgeLength
  acting through the path; Smelting: Volume).
- Edge hand-off: S3 owns `PrecisionTrace.sidesFromChains(chains, gripPoint, gripAxis)`; S6's canvas mapping wins
  (R5a-07); EdgeLength (the factor) measures the edge the trace actually plays (R3-04).

### 2.13 Asymmetry and the mirror tool: one fixed plane (supersedes R3-01, R4a-05, R1-35, R2-13, R6-17, R7-13)
- Asymmetry is measured left/right about the **fixed blueprint plane x = 0**, the hitbox's own centre plane. This
  is the design draft's definition ("overlap with the mirrored grid"). Nothing a player cannot see can move it,
  which closes R3-01's hidden-grip exploits and R4a-05's frame drift.
- Use soft coverage and dense asymmetry probes (R4a-04), on the kept parts of the step's work set.
- The editor's mirror tool reflects across x = 0 (left/right) and z = 0 (front/back) through `Blueprint/Mirror`
  (S2's math, the only implementation). The editor draws the x = 0 plane, and a "Centre on axis" action recentres
  a selection. A design mirrored with the tool measures exactly symmetric.
- The physics grip frame (grip point, axis) is unchanged for balance and reach; for difficulty-related uses it
  takes kept parts only.
- Invariance tests (S8): translation along Y and Z and rebuilding a part from flush segments change factors by
  ≤ 0.02. A shift along X or a rotation of the whole sword is a real design change against the fixed frame.

### 2.14 Geometry measurement fixes and calibration (S2)
- Apply the tested fixes for R3-02, R3-03, R3-04, R4a-02, R4a-03, R4a-06 and R4a-07 (R4a's patched copies are in
  `review/R4a/`).
- Validation requires at least one **kept** Blade part and one kept Grip part (R1-15, R2-08, R4a-09).
- Recalibrate the reference ranges so the iron arming sword fixture sits at least **0.05** below the Hard
  threshold on every MVP step (R4a-08) **[DtC Q7]**. Publish the final tier table for every fixture (§2.29).
- Report analysis cost under the Studio factor (Studio runs this Luau about 2.6× slower than Lune) and cut the
  worst case: budgets, early exits, bounded trace path (R3-08, R4b-08).

### 2.15 Design difficulty pays inside a tier (R6-04 option b) **[DtC Q11]**
`d_i = d(tier_i) · (1 + γ·(D_i − DMin(tier_i)))`, with γ tuned by S4 so a good player's expected Q does not fall
as D rises. S3 keeps m_design. S6's preview tooltip says what extra difficulty buys.

### 2.16 One player model, one target table (R1-29, R2-04, R4b-02, R4b-03, R6-03)
- **S3 owns the player-model table** in `Minigames/Bots` (S8 implements it verbatim in its tests; S4 uses S3's
  per-run score distributions, e.g. `review/R4b/protoS3/dump_dist.luau`). Profiles: Elite, Good, Average, Poor,
  plus the test-only extremes Perfect and Idle. The parameters merge S3's bots with S8's (σ 12 / 25 / 45 / 90 ms),
  add render and input latency (§2.17), 60 and 30 fps, and HoldZone pumping (R4b-04). Document every parameter.
- Fail-rate targets **[DtC Q8]**: Average fails 3–15 % of Normal steps and 15–40 % of Hard steps; Good rarely
  fails (≤ 5 % Normal, ≤ 15 % Hard). S3 retunes p_base / m_tier / material columns per family × tier × material
  to hit them with a Normal → Hard mean drop ≥ 0.05. One pass line of 0.50 is preferred; per-(family, tier)
  thresholds within [0.40, 0.60] are allowed only if parameters cannot do it.
- Rarity targets **[DtC Q12]** (S4 owns, restated in these profile names, checked for Iron and Steel, R4b-10):
  Average on all-Normal Iron: mostly Common/Uncommon (Rare ≤ 15 %); Good on all-Normal Iron: Rare 30–60 %;
  Good on all-Hard: Epic 5–25 %; Elite on all-Hard: Epic ≥ 40 %; Epic never without a passed Hard step.
  S4 re-runs its grid search after S3's retune and publishes thresholds inside the feasible box.

### 2.17 TimingStrike latency (R4b-05, R6-05)
Centre the input wait (press time = clock − goClock − frameDt/2, floored at 0). A persisted `timingOffsetMs`
(−120…+120, default 0) is subtracted client-side before encoding. The results card shows the mean early/late error
and offers "[Use −31 ms offset]"; Settings has a slider. No separate calibration screen. Full-points core ≥ 9 ms at
every MVP tier. Bots include +25 ms render lag and a residual bias; S8's T-MG-11 asserts ≥ 0.95 for Perfect at 30 fps.

### 2.18 HoldZone pumping (R4b-04)
Holding and tapping are both legitimate. Tune against the better policy for each profile (S3 picks a retune or a
stroke-based bellows and justifies it with the bots).

### 2.19 Step outcomes (R1-08, R1-09, R1-11, R3-13, R4b-06, R5b-02, R7-12, R3-06, R1-10, R4b-09)
| Event | Result |
|---|---|
| Malformed or impossible timeline, hash mismatch, wrong step/session, early submit (`E < D − EARLY_TOL_MS`) | Invalid: craft aborted (reason `InvalidInput`), no item, Hard strike |
| HIGH inhuman-input flag | Step score clamped to the pass line, step passes, flag stored server-side |
| Telemetry-only flag (incl. LateSubmit) | Recorded only |
| No submission by the deadline | Step fails: score 0, `timedOut = true`, craft continues (item still forged after the last step) |
| Abandon (player), disconnect, idle/session timeout, character death | Craft discarded, no item |
| Pattern-hash desync | Client re-opens `Craft.StartStep` (same seed); if it persists, `Craft.ReportDesync` → abort, reason `Internal`, no strike. **Never a new seed.** |
- **S5 owns all wall-clock rules** (E, A, EARLY_TOL_MS 250, LATE_SOFT_MS, LATE_HARD_MS, RTT allowance from a median
  of pings, R3-20). S3 deletes TooFast/SlowClock. Abandon is session-level only (S3's "Esc forfeits the step" goes).
- Client-side input limits keep honest input inside the timeline caps (R4b-07), so Invalid never hits an honest player.

### 2.20 Minigame ↔ session contract (R7-03, R1-07, R1-01, R1-02, R4b-01, R5b-01, R3-12)
- S3's facade is the only minigame API: `Minigames.prepare(PrepareInput) → (StepSpec, pattern)` and
  `Minigames.judge(spec, pattern, timeline, elapsedMs) → MinigameResult`. S5's SessionMachine calls it via injection.
- `StepOpenView` = S3's `StepSpec` (including `source` and `patternHash`) + `{sessionId, stepIndex, stepId, tier,
  lateAllowanceMs}`. `Craft.Submit` args = `{sessionId, stepIndex, timeline: buffer, clientScore}`.
- S5's Guard adds `buffer(maxBytes)`; `MAX_TIMELINE_BYTES = 14348` (S3's header + largest family cap);
  all structural checks stay in S3's `Timeline.decode`. `ScoreMismatch` compares against the unclamped server
  score (R1-42, R4b-12). `MAX_STEP_FLAGS` covers every flag kind (R1-43).

### 2.21 Remotes and payloads (S5)
4 RemoteEvents (Profile, Blueprint, Craft, Showcase), action strings, request ids. Add `Showcase.TeleportHome {}`
(bucket 1 per 3 s, refused during a craft; replaces S7's `World.TeleportHome`) and `Craft.ReportDesync`.
`Profile.SetSettings {settings, uiFlags}` goes through `Persistence/Settings.sanitize`. Autosave uses `Blueprint.Save`.
Owners receive their items without anti-cheat flags; other players only ever receive `InspectView` (R3-10).
One error vocabulary on the wire (S5 `ErrorCode`); module codes (S1 CanonError, S2 ValidationCode, S3 Invalid
reasons, S7 ShowcaseCode) map to it in one S5 table (R1-32, R7-11).

### 2.22 Analysis execution (R1-30, R3-07, R4a-10, R5b-08, R7-14, R5a-09)
One model on client and server: `Analyze.run` takes a checkpoint callback, and the caller runs it in a coroutine
that yields once its slice is used: **4 ms per Heartbeat on the server, 6 ms per frame on the client**. Server
AnalysisQueue: FIFO, cap 16, one job in flight per player. No Actors in the MVP.

### 2.23 Saving (R1-31, R3-09, R4a-11, R5b-07)
Explicit saves coalesce to at most one per `SAVE_MIN_INTERVAL_S = 60` per profile (+ ProfileStore's 300 s
autosave), which keeps the worst-case profile under the 4 MB/min per-key write limit. A save failure stays local to
that player (no server-wide SaveDegraded broadcast). Size-guard thresholds are re-derived by S1/S5 from the new
worst case.

### 2.24 World, plots, spawn, place settings (R7-11, R1-06 modified, R5b-09, R1-25, R5a-08, R1-37, R5b-18, R7-25)
- S7 owns `ShowcaseService` logic, `Showcase/*`, `World/WorldBuilder`, `World/PlotWorld` and the single
  `InspectView` (S1's ItemPublicView goes). S5 owns the transport and handlers, lifecycle order, `PlotService` and
  rate limits.
- Spawn: one SpawnLocation per plot at the plot's home pose (Neutral, Duration 0, invisible pad);
  `PlotService.assign` runs synchronously in PlayerAdded before any yield and sets `RespawnLocation`; LoadCharacter
  only in the Studio race; kick when no plot is free. No plaza spawn, no PivotTo-on-spawn, no NoPlot visitor mode.
- `PLOT_COUNT` lives once in `Definitions/World`. S5 enforces `Layout.isInsidePlot` at `Craft.Begin` and
  `Showcase.Place/Clear`, and calls `PlotWorld.setActivity` on step start/end.
- Place settings live in the Rojo project: `Workspace.StreamingEnabled = false` (S7 drops streaming code and
  `RequestStreamAroundAsync`), `StarterPlayer.EnableMouseLockOption = false`, and the rest R5b-18 lists.
  `Players.MaxPlayers = 8` is a Creator Dashboard step in the README.

### 2.25 Text and names (R1-41, R2-11, R5b-20, R3-15)
Raw names are stored; anything shown to another player is broadcast-filtered (S5's TextFilter, retry per the docs).
Item name = blueprint name at forge; **no item rename in the MVP**; fallback `"<Material> <Type>"` (blade material)
while filtering is pending or fails.

### 2.26 Telemetry and logging (R1-26, R5b-13, R7-17, R1-27, R3-16)
One event catalogue, owned by S5 (§10.9), with fields from S2/S3/S4. S8 maps its analyses onto it. S8's raw
DataStore sink and Open Cloud export are cut. Onboarding funnel events via `LogOnboardingFunnelStepEvent` (R6-01).
Log format `[blacksmith:<tag>] <event> k=v` (S5); S8's checks match it. Attacker strings are sanitized.

### 2.27 Editor scope (R2-09; S6)
Keep: per-type snapping with typed steps, built-in presets, on/off and Shift inversion; expression input; undo/redo;
physics overlays; label-resolved hotkeys with the AZERTY fix (R5a-03); Flat/Edge/Tip views with R5a-01's
orthographic read-back check and telephoto fallback. Simplify and cut exactly as R2-09 lists.
**Rotate snapping is off by default; Move and Scale snap at 0.05 stud** **[DtC Q5]** (R6-18).

### 2.28 Player-experience additions
- First session (R6-01, R6-02) **[DtC Q21]**: grant a saved, valid "Starter Sword" (new fixture F5 = F1 all in Iron,
  Normal on every step) at first load (`starterGranted`); empty states; a dismissible 4-step "First steps" tracker.
  Hint copy must name what actually raises tiers (design factors), since Steel no longer does in the MVP.
- Autosave (R6-09) **[DtC Q6]**: every 60 s while dirty, never during a drag, overwrite in place via Blueprint.Save.
- Audio (R6-06) **[DtC Q20]**: about 12 cues in `Definitions/Audio` (hook, id, volume, pitchRange), filled with
  Roblox-published free Creator Store sound ids during the build (an empty id is legal and silent); one SFX
  SoundGroup with a volume slider; every cue keeps a visual counterpart.
- Also apply R6-07, R6-08, R6-10 … R6-14, R6-19, R5a-02 … R5a-07 and R5a-10 … R5a-14.

### 2.29 Testing (S8)
Adapt every test to the final names, protocol, log format and outcomes above (R5b-10, R5b-11, R5b-12, R7-15, R7-16,
R1-46, R4b-11). One fixture set: S2's calibration swords + F1–F5 + A01–A27 (A25–A27 from R3-01), all in PartData
and blueprint space, with S2's final measured tiers. Golden goldens per BALANCE_VERSION. Lune tests for every pure
module listed in §2.2. A self-contained `test.project.json`. §18 milestones follow R7-19's M0–M9.

### 2.30 Cut or deferred to phase hooks
GEOMETRY_VERSION / GeometrySummary / stale queues; persistent Counters; item rename; S8's raw telemetry sink;
per-axis snapping, absolute snap mode, user presets, scrubbing, editable delta badge, eyedropper, slot paint,
auto-ortho, rulers, view triad, saved UI scale / orbit settings; group scale; client Actors; practice mode
(§17, R6-16); Epic-forge announcements (§17, R6-15).

## 3. Decisions to confirm (the §0 list; revisers mark them in the text with these numbers)

| Q | Decision and default |
|---|---|
| Q1 | Scope: Phase 1 only — one sword, Iron + Steel, Smelting/Hammering/Sharpening, Normal + Hard (any step with D ≥ 0.2 plays Hard), standalone PC-only place, display-only items, free unlimited materials. |
| Q2 | Server: 8 players, each with a smithy in a ring around a plaza; anyone may walk into any smithy and inspect its stands; players do not collide. |
| Q3 | Envelope: one 1.6 × 5.0 × 0.6-stud hitbox; the only placement rule is "blade above the grip"; left/right symmetry is measured about the hitbox centre plane, the same plane the mirror tool uses. |
| Q4 | Parts: Blade and Grip required, Guard and Pommel optional, at most 24 parts (Blade 12, Guard 8, Grip 6, Pommel 4); smallest side 0.02 stud (alternative 0.05). |
| Q5 | Editor: sword lies horizontally on an enlarged private stage; Move and Scale snap at 0.05 stud, Rotate snapping off by default; any typed step; Shift toggles snapping; mirror across the centre planes. |
| Q6 | Work in progress: invalid blueprints can be saved, only valid ones forged; the editor autosaves the open blueprint every 60 s while it has unsaved changes. |
| Q7 | Difficulty: a plain iron arming sword plays Normal on all three steps with a safe margin; thinner or longer blades, asymmetry and surface detail push steps to Hard; the editor shows each step's difficulty and its factor breakdown. |
| Q8 | Failure risk: an average player fails about 1 step in 10 on Normal and 1 in 4 on Hard (bands 3–15 % / 15–40 %); pass line 50 %. |
| Q9 | Fail cost: a failed step counts at 75 % of its score and unlocks no rarity cap; nothing is destroyed on Normal or Hard. |
| Q10 | Rarity cap: one passed Hard step unlocks Epic (alternative: Hard on steps carrying at least half the weight). |
| Q11 | Bold designs pay: inside a tier, a step's quality multiplier grows with its difficulty, so going past the Hard threshold is rewarded (alternative: tier-only multipliers). |
| Q12 | Rarity targets: an average player's all-Normal iron swords are mostly Common/Uncommon; a good player gets Rare on 30–60 % of all-Normal crafts and Epic on 5–25 % of all-Hard crafts; step weights 25/40/35 %; Quality shown on an open scale where 100 = flawless all-Normal iron. |
| Q13 | Materials: Iron 7.87 / 45 / 50 and Steel 7.85 / 70 / 55 (density / hardness / toughness); mass in kg. Steel plays slightly tighter minigames and gives +10 % quality but does not raise a step's tier in the MVP (materials are free; alternative: the draft's material term, under which most steel swords play Hard). Items show Damage, Sharpness, Durability, Purity, Balance and Reach. |
| Q14 | Mixed materials: chosen per part in the editor; each step plays once at the hardest material it touches; the quality bonus is volume-weighted. |
| Q15 | Minigames: Smelting = hold or tap Space/LMB to work the bellows for 15 s; Hammering = 12 timed strikes (15 on Hard) on a circular dial, first click counts, with a timing-offset setting; Sharpening = trace the blade's real edge behind a guiding spark; a blade with no usable edge gets a generic edge. |
| Q16 | Interruptions: no pause; losing focus releases inputs; chat hidden during minigames; a step with no input fails and the craft goes on; abandoning or disconnecting discards the craft with no item. |
| Q17 | Anti-cheat: impossible input aborts the craft; clearly inhuman input caps the step at the pass line; slow motion is only flagged; a careful cheater faking human input is an accepted risk until Phase 2 (items are display-only). |
| Q18 | Storage and names: 40 blueprints and 150 items per player; items can be scrapped; names 1–32 Latin characters; an item takes its blueprint's name; no renaming in the MVP. |
| Q19 | Rebalancing: after a balance update stats and quality follow the new numbers, but an item's rarity never drops below what it was awarded at forge. |
| Q20 | Smithy and look: 6 display stands; one Forge prompt with automatic walking between furnace, anvil and grindstone; visitors see forging live; inspect shows a short forging record; asset-free visuals; about 12 sound effects from Roblox's free Creator Store audio (alternative: silent MVP). |
| Q21 | First session: new players receive a ready Starter Sword (all iron, Normal on every step) and a 4-step "First steps" tracker. |
| Q22 | Done bar: at least 3 testers (one new) finish the loop unaided within 20 minutes, 2 of 3 start a second sword unprompted, you sign off that it is fun, and you can provide a published private test place for one real-save check. |
