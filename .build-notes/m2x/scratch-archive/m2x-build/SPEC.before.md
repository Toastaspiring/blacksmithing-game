# Blacksmithing Game — Technical Specification (Phase 1 MVP)

> Roblox · Rojo 7.7.1 · Luau --!strict · ProfileStore · Spec v1.0 for designer review · 2026-10-31

---

## Table of Contents

0. [Summary](#0-summary)
1. [Architecture](#1-architecture)
2. [Domain model and Definitions](#2-domain-model-and-definitions)
3. [Blueprint format](#3-blueprint-format)
4. [Geometry pipeline](#4-geometry-pipeline)
5. [Difficulty](#5-difficulty)
6. [Minigames](#6-minigames)
7. [Crafting pipeline](#7-crafting-pipeline)
8. [Item outcome](#8-item-outcome)
9. [Persistence](#9-persistence)
10. [Networking and anti-cheat](#10-networking-and-anti-cheat)
11. [Client: blueprint editor](#11-client-blueprint-editor)
12. [Client: forge flow, minigame UI, results](#12-client-forge-flow-minigame-ui-results)
13. [Smithy world, displays, item rendering, inspect](#13-smithy-world-displays-item-rendering-inspect)
14. [Testing and verification](#14-testing-and-verification)
15. [MVP non-goals and phase hooks](#15-mvp-non-goals-and-phase-hooks)
16. [Constants reference](#16-constants-reference)
17. [Open questions](#17-open-questions)
18. [Implementation milestones](#18-implementation-milestones)

---

## 0. Summary

### 0.1 What the MVP is

A player draws a sword from up to 24 primitive parts inside a 1.6 × 5.0 × 0.6-stud envelope, picks Iron or Steel per
part, and forges it through three skill minigames (Smelting, Hammering, Sharpening). The server measures the design
and sets each step's difficulty and tier (Normal or Hard). It replays every input timeline with the same pure Luau
code and seed, then computes stats, a quality score Q and a rarity (Common to Epic) capped by the hardest passed
step. Items go on display stands in the player's smithy, one of eight on a server, where visitors can walk in and
inspect them. Everything that decides an outcome is pure Luau shared by client and server and tested under Lune;
Roblox-bound code only transports, persists and draws.

### 0.2 Scope

| In the MVP | Phase hook only (§15) |
|---|---|
| One Sword type, slots Blade · Guard · Grip · Pommel, free-transform editor with server validation (§3, §11) | Axe, Spear, Hammer, armor dummy (Phase 3) |
| Physics: mass, balance point, reach; analytic geometry (§4) | Inertia and swing speed (Phase 2) |
| Iron and Steel, free and unlimited (§2.5) | Bronze, Mithril, Obsidian, Wood, Leather; material sourcing (Phase 2, 4) |
| Smelting (HoldZone), Hammering (TimingStrike), Sharpening (PrecisionTrace) (§6) | Quenching, Assembly, Finishing; three more families (Phase 2) |
| Tiers Normal and Hard; any step with D ≥ 0.2 plays Hard (§5.4) | Expert, Master, Hell and their rarities (Phase 2) |
| Server-seeded replay scoring, stats, Q, rarity, lazy recompute (§7, §8) | Material loss on a Hell failure (Phase 2) |
| A smithy with 6 stands on an 8-plot server, inspect, live forging for visitors (§13) | Likes, categories, history card, offline visits (Phase 3) |
| ProfileStore persistence, telemetry, Lune and Studio test gates (§9, §10, §14) | Items used in combat, trading (Phase 4) |

### 0.3 How to review

- **Decide**: the 22 questions of §0.4 (each links to where it is built), then §17.1, and check §0.5 (every change
  from your design draft).
- **Formulas**: physics §4.5; difficulty §5.1–5.3; minigame parameters and scoring §6.5, §6.8–6.10; stats, quality
  and rarity §8.2–8.4. **Tuning numbers**: §5.3, §5.5, the tables of §6.8–6.13, §8.4, and §16 (every constant with
  its rationale). **Minigame rules**: §6 (play and scoring), §12.5–12.8 (what the player sees), §7.4 (what a
  failure, timeout or abandon costs). **Data formats**: §3.3, §9.3–9.4, §10.2.
- **Conventions**: **[Decision to confirm]** marks carry their Q number; **Phase N hook:** lines say what later phases
  plug into; `E-Sx.y` points to `docs/spec/SPEC-evidence.md`; review finding ids appear only in the evidence appendix
  and refer to `docs/spec/review/findings-all.md`. Owners: S1 data model and persistence data, S2 geometry and
  difficulty, S3 minigames, S4 crafting and outcome, S5 server, networking and persistence lifecycle, S6 client UX, S7
  smithy world and rendering, S8 testing.

### 0.4 Decisions to confirm

Defaults are what the spec implements. Rows marked *changed* differ from the default first proposed for that question;
each says what it was and why it moved.

| Q | Decision and default | Built in |
|---|---|---|
| Q1 | Scope: Phase 1 only — one sword, Iron + Steel, Smelting/Hammering/Sharpening, Normal + Hard (any step with D ≥ 0.2 plays Hard), standalone PC-only place, display-only items, free unlimited materials. | [§2.7](#27-tiers-and-rarities), [§5.4](#54-tier-mapping), [§15](#15-mvp-non-goals-and-phase-hooks) |
| Q2 | Server: 8 players, each with a smithy in a ring around a plaza; anyone may walk into any smithy and inspect its stands; players do not collide. | [§1.4](#14-project-files-and-toolchain), [§13.2](#132-world-layout), [§13.4](#134-plot-build) |
| Q3 | Envelope: one 1.6 × 5.0 × 0.6-stud hitbox; besides staying inside the hitbox and touching each other (gaps up to 0.01 stud count as touching), the only placement rule is "blade above the grip"; left/right symmetry is measured about the hitbox centre plane x = 0, the plane the mirror tool uses. | [§3.1](#31-blueprint-space-and-the-sword-hitbox), [§4.2](#42-validation), [§5.2](#52-factors) |
| Q4 | Parts: Blade and Grip required (each must keep a part that is not ignored as dust or hidden), Guard and Pommel optional, at most 24 parts (Blade 12, Guard 8, Grip 6, Pommel 4); smallest side 0.02 stud, verified by measurement (alternative 0.05). | [§3.1](#31-blueprint-space-and-the-sword-hitbox), [§3.7](#37-slots-and-part-limits), [§4.4](#44-exposure-and-cleaning) |
| Q5 | Editor: the sword lies horizontally on an enlarged private stage; Move and Scale snap at 0.05 stud, Rotate snapping off by default; any typed step; Shift toggles snapping; mirror across the centre planes. | [§11.2](#112-entering-leaving-and-the-stage), [§11.8](#118-snapping), [§9.3](#93-profiledata-types-and-template) |
| Q6 | Work in progress: invalid blueprints can be saved, only valid ones forged; the editor autosaves the open blueprint every 60 s while it has unsaved changes. | [§10.2](#102-request-catalogue), [§11.14](#1114-library-saving-and-autosave) |
| Q7 | Difficulty: a plain iron arming sword (calibration sword C02, 6 parts) plays Normal on all three steps (highest step 0.132, 0.068 below Hard; the Starter Sword 0.104); thinner or longer blades, asymmetry and surface detail push steps to Hard; the editor shows each step's difficulty and its factor breakdown. | [§5.5](#55-calibration-and-fixture-tiers-decision-to-confirm-q7), [§11.13](#1113-live-preview) |
| Q8 | Failure risk: an average player fails about 1 step in 10 on Normal and 1 in 4 on Hard (bands 3–15 % / 15–40 %; tuned result 5–12 % / 25–32 %; at the boldest possible design, every factor at its maximum, an average player fails 49–62 % of Hard steps); pass line 50 %. | [§6.5](#65-parameters-p_final--round_qclampp_base--m_material--m_tier--m_design-min-max), [§6.13](#613-calibration-results-and-score-distributions) |
| Q9 | Fail cost: a failed step counts at 75 % of its score and unlocks no rarity cap; nothing is destroyed on Normal or Hard. | [§7.4](#74-failure-timeout-and-abandon-effects), [§8.2](#82-stats) |
| Q10 | Rarity cap: one passed Hard step unlocks Epic (alternative: Hard on steps carrying at least half the weight; among the simulated plans it changes only Sharpening-Hard-only swords, where an elite player's Epic share drops from 2 % in iron and 13 % in steel to 0 %). | [§8.4](#84-rarity) |
| Q11 | Bold designs pay: inside a tier a step's quality multiplier (Normal ×1.00, Hard ×1.25) grows with its difficulty (γ = 0.15: +0.1 of D adds 1.5 % of the tier multiplier), so going past the Hard threshold is rewarded; design factors also tighten that step's minigame a little (alternative: tier-only multipliers, under which a good player's expected Q falls about 6 % as every step's difficulty rises from 0.2 to 1.0). | [§6.5](#65-parameters-p_final--round_qclampp_base--m_material--m_tier--m_design-min-max), [§8.3](#83-quality-score-q), [§11.13](#1113-live-preview) |
| Q12 | Rarity targets: an average player's all-Normal iron swords are mostly Common/Uncommon; a good player gets Rare on 30–60 % of all-Normal iron crafts (47 %; in steel 61 %, outside the band, which is set for iron only) and Epic on 5–25 % of all-Hard crafts (11–19 %); step weights 25/40/35 %; Quality shown on an open scale where 100 = a flawless all-Normal Iron sword of the plainest design (D = 0), with rarity thresholds Uncommon 55, Rare 84, Epic 104 on that scale (Q 0.55 / 0.84 / 1.04). | [§7.1](#71-step-plan-craftplans), [§8.3](#83-quality-score-q), [§8.4](#84-rarity) |
| Q13 | *Changed.* Materials: Iron 7.87 / 45 / 50 and Steel 7.85 / 70 / 55 (density / hardness / toughness); mass in kg. Steel plays slightly tighter minigames and gives **+2 % quality** (was +10 %: from +5 % up no rarity thresholds meet the Steel targets) but does not raise a step's tier in the MVP (materials are free; alternative: the draft's material term, under which most steel swords play Hard). Items show Damage, Sharpness, Durability, Purity, Balance and Reach. | [§2.5](#25-materials), [§5.3](#53-weights-reference-ranges-and-the-material-term), [§6.13](#613-calibration-results-and-score-distributions), [§8.2](#82-stats), [§8.3](#83-quality-score-q) |
| Q14 | Mixed materials: chosen per part in the editor; each step plays once at the hardest material it touches; the quality bonus is volume-weighted. | [§7.2](#72-work-sets-and-the-governing-material), [§8.3](#83-quality-score-q) |
| Q15 | *Changed.* Minigames: Smelting = **tap Space or LMB to pump the bellows (each press is one stroke) for about 15 s** (was "hold or tap": tapping beat holding by 0.14–0.32 for every player profile); Hammering = 12 timed strikes (15 on Hard) on a circular dial, first click counts, with a timing-offset setting; Sharpening = trace the blade's real edge behind a guiding spark; a blade with no usable edge gets a generic edge (alternative: skip Sharpening). | [§6.8](#68-holdzone-smelting-pump-the-bellows-keep-the-ore-in-the-zone)–[§6.10](#610-precisiontrace-sharpening-grind-the-blades-own-edge), [§12.6](#126-smelting-hold-zone)–[§12.8](#128-sharpening-precision-trace) |
| Q16 | Interruptions: no pause; losing focus releases inputs; chat hidden during minigames; a step with no input fails and the craft goes on; abandoning or disconnecting discards the craft with no item. | [§6.6](#66-step-timing-and-input-capture-minigamesinput-s6s-inputcapture-feeds-it), [§7.4](#74-failure-timeout-and-abandon-effects), [§7.6](#76-craft-session-state-machine), [§12.1](#121-flow-and-rules) |
| Q17 | Anti-cheat: impossible input aborts the craft; clearly inhuman input caps the step at the pass line; slow motion is only flagged; a careful cheater faking human input is an accepted risk until Phase 2 (items are display-only). | [§10.5](#105-minigame-replay-and-verdicts)–[§10.7](#107-timing-checks), [§10.10](#1010-threat-model-and-residual-risks) |
| Q18 | Storage and names: 40 blueprints and 150 items per player; items can be scrapped; names 1–32 Latin characters; an item takes its blueprint's name; no renaming in the MVP. | [§3.9](#39-names-and-text-rules), [§9.8](#98-size-budgets-and-caps), [§10.2](#102-request-catalogue) |
| Q19 | Rebalancing: after a balance update stats and quality follow the new numbers, but an item's rarity never drops below what it was awarded at forge. | [§7.5](#75-crafting-history-semantics), [§9.4](#94-item-record-frozen-facts-vs-derived-values) |
| Q20 | *Changed.* Smithy and look: 6 display stands that show each sword upright at true size; one Forge prompt with automatic walking between furnace, anvil and grindstone; visitors see forging live; inspect shows a short forging record; asset-free visuals at a fixed golden hour; **about 14 sound effects** (was about 12: the final cue list) from Roblox's free Creator Store audio (alternative: silent MVP). | [§12.10](#1210-audio-cues), [§12.11](#1211-ui-kit-and-accessibility), [§13.4](#134-plot-build)–[§13.11](#1311-look-audio-budgets) |
| Q21 | First session: new players receive a ready Starter Sword (a plain 5-part sword, fixture F1 built all in Iron; Normal on every step, highest step 0.104) and a 4-step "First steps" tracker. | [§9.6](#96-versioning-migration-and-the-load-pipeline), [§12.9](#129-smithy-hud-settings-help-first-session) |
| Q22 | Done bar: at least 3 testers (one new) finish the loop unaided within 20 minutes, 2 of 3 start a second sword unprompted, you sign off that it is fun, and you can provide a published private test place for one real-save check. | [§14.12](#1412-acceptance-criteria-and-definition-of-done) |

### 0.5 What changed from the design draft

Verdict: **J** = justified; **Qn** = justified default you confirm in §0.4; **removed** = an idea from an earlier spec
draft (not from your design draft), dropped. Per-section logs of alternatives and renamings: E-S5.10, E-S7.8, E-S8.10.

| Draft → spec | Why | Verdict |
|---|---|---|
| Grid snapping → free transforms stored as raw doubles, snapping chosen per transform type (§3.5, §11.8) | your free-transform decision | Q5 |
| Mirror "within limits" → exact copy or flip across the fixed planes x = 0, z = 0 (§3.8) | the plane Asymmetry uses | J |
| Editor on a ×4 private stage, sword horizontal, Flat / Edge / Tip views (§11.2) | precise editing of a 5-stud object | Q5 |
| "Validated before forging" → invalid work in progress saved and autosaved; validation gates forging (§11.14) | no lost work | Q6 |
| "Pick materials" step → material is a per-part blueprint field (§3.3) | the live preview needs it | J, Q14 |
| Voxel grid → analytic per-part geometry, local samples, a 2D blade raster (§4.3) | a grid mis-measures a thin blade by +67 % / −17 % (E-S2.4) | J |
| Mass = union volume, overlaps counted once; balance point measured from the guard (§4.5) | stacking buys nothing; the draft's "near the guard" focus | J |
| Factors per step on the parts it works; volume-weighted counts; Thinness from union chords; "enclosed" = < 2 % exposed; dust < 0.0002 stud³; PartCount range 3–16 (§4.4, §5.1–5.2) | invariant to splitting a blade; filler cannot buy a tier | J |
| Asymmetry about the fixed hitbox plane x = 0, soft 0.02 tolerance; Z asymmetry deferred (§5.2) | the draft's "mirrored grid"; nothing hidden moves it | Q3 |
| Validation adds "blade above the grip", slot maxima, a kept Blade and Grip part (§3.7, §4.2) | recognizable swords, bounded filler | Q3, Q4 |
| Material term in D = 0 for Iron and Steel; the step's material = highest (difficultyTerm, hardness) (§5.3, §7.2) | free materials would be a difficulty slider | Q13 |
| Tier table D 0.4–1 (Expert, Master, Hell) → every step with D ≥ 0.2 plays Hard; the higher tier is still measured and shown (§2.7, §5.4) | the MVP has two tiers | Q1 |
| Tier multiplier grows inside a tier (γ 0.15); design factors tighten minigames inside a tier (§6.5, §8.3) | every D ≥ 0.2 plays Hard in the MVP | Q11 |
| Minigame material and tier modifiers are columns of each family's table (§6.5) | the same data, grouped for tuning | J |
| Smelting hold → tap to pump; Sharpening traces the blade's own edge; Hammering on a dial with a timing offset; combo is feedback only (§6.8–6.10) | tapping beat holding by 0.14–0.32 (E-S3.7); design-driven paths | Q15 |
| One player model and one pass line 0.50, tuned to fail bands (§6.12–6.13) | one source for tuning, tests and rarity | Q8 |
| Inhuman input clamps to the pass line; impossible input aborts; slow motion only flagged (§10.5–10.7) | no false failures; items are display-only | Q17 |
| No pause; session-level abandon; a step with no input fails, the craft goes on (§6.6, §7.4) | simple rules that cannot be gamed | Q16 |
| "A fail lowers quality" → counts at 75 %, lifts no cap; "cap follows the hardest steps" → highest cap among passed steps (§7.4, §8.4) | exact rules; nothing destroyed before Hell | Q9, Q10 |
| Q on an open scale (1.00 = flawless all-Normal Iron at D = 0), thresholds from simulation (§8.3–8.4) | every target met with at least 6.15 percentage points to spare | Q12 |
| Steel's material tier T = 1.02 (+2 % quality; the draft gives no value, the first proposal was +10 %) (§8.3) | from +5 % up no rarity thresholds meet the steel targets (E-S4.7) | Q13 |
| Durability from toughness, purity and hammering (Quenching is Phase 2); Damage from mass, edge × cutIndex and hammering; hardness and toughness as integers 0–100; stats never feed Q (§2.5, §8.2) | MVP steps only, one scale | J, Q13 |
| Item stats add Purity and Balance; Balance comes from the balance point alone until Assembly ships (§8.2) | the draft's Phase 1 physics is mass, balance point and reach | Q13 |
| One `BALANCE_VERSION`; lazy recompute; rarity floored at forge (§9.4, §9.6) | one version, one recompute path | Q19 |
| Timelines not stored; items keep per-step facts (§9.4) | profile budget; scores are final | J |
| Caps 40 / 150, a size guard, a Scrap action; names 1–32 Latin characters, no item rename (§3.9, §9.8) | 43.5 % of the 4 MiB key at the caps | Q18 |
| Floor stands only; the blueprint shown as the 3D item; a minimal Forging record; same-server visits in the MVP (the draft lists visiting in Phase 3); no likes or levels yet; one Forge prompt with automatic movement, visitors see forging (§13) | eight smithies share a server; Phase 3 features keep hooks; the draft does not say where forging happens | J, Q2, Q20 |
| Added: Starter Sword and "First steps" tracker; about 14 sound cues (§12.9–12.10) | first-session guidance and feedback | Q21, Q20 |
| Remotes declared in the Rojo project; AnalyticsService telemetry; persistence checked on Mock plus one real-save check (§1.4, §10.9, §14.10) | static, testable tree; platform tools | J, Q22 |
| Not from your draft (ideas from earlier spec drafts): a 1e-4 transform storage grid, a separate geometry version, per-axis snapping, a raw DataStore telemetry sink, an asymmetry plane tied to the grip axis | complexity or exploits without a player benefit | removed |

---

## 1. Architecture

> **Principle (design draft, "Technical architecture").** The server is the only authority on blueprints, scores,
> stats and items. The client edits, plays and previews with the same pure modules, and sends intents and raw
> inputs only.

### 1.1 Authority model and data flow

```
CLIENT (untrusted)                                          SERVER (authoritative)
Editor: Pipeline preview ── Blueprint.Save ──────────────►  Router (buckets · Guard · lanes) ─► BlueprintService:
                            {blueprintId, draft}            Canonical.draft → AnalysisQueue: Pipeline.analyze → DataService
Forge: Minigames.start(spec) ─ Craft.StartStep / Submit ─►  CraftService: SessionMachine · seeds · clocks ·
       local score preview      {timeline: buffer}          Minigames.prepare / judge → Pipeline.outcome → Items/Create
Smithy: Showcase.Place / Inspect / GetItems ─────────────►  ShowcaseService (S7) · TextFilter · PlotWorld (S7)
Net/Client ◄─ replies · Notice · StepTimedOut · Aborted ─── DataService (ProfileStore) · PlotService · Telemetry · Log
Never from the client: physics, D, tiers, scores (clientScore is advisory), stats, rarity, item records, seeds.
```

### 1.2 Module map

Authoritative tree (P = pure, Lune-tested; RB = Roblox-bound; `[owner]`). Owners add private helpers inside their
own folder; a new cross-section module needs a change here.
```
src/shared → ReplicatedStorage.Blacksmith                                                         P unless RB
  Definitions/  Types Catalog Versions Limits Materials EquipmentTypes Steps Tiers Rarities Stats Balance Validate
                Manifest [S1 shapes; values S2/S3/S4] · MinigameFamilies [S3] · CraftPlans [S4] · Network [S5] ·
                World Presentation [S7] · Audio [S6]
  Util/         Quantize [S1] · Signal [S5] RB
  Blueprint/    Schema Canonical Quat Names Views [S1] · Mirror [S2] · WorkSet [S4]
  Physics/      Shapes Gjk Sampling MassProps Edge Factors Difficulty Analyze [S2]
  Minigames/    Minigames Types Rng Params Timeline Checks Input HoldZone TimingStrike PrecisionTrace Bots [S3]
  Crafting/     Types Plan Quality Rarity Stats Outcome [S4]
  Pipeline      [S2 + S4]
  Items/        Schema Create Recompute Views [S1]
  Persistence/  Types Template Migrations Prepare JsonSafe Settings [S1]
  Session/      SessionMachine [S5]
  EditorCore/   EditorState Commands History Snap Rotation GizmoMath Expr EditorLayout Keymap Config [S6]
  World/Layout · ItemRender/RenderPlan · Showcase/ShowcaseRules · Showcase/InspectView [S7] · ItemRender/ItemModelBuilder [S7] RB
  Net/          Protocol Guard RateLimit [S5] · Remotes Client [S5] RB
  Remotes.model.json   Folder "Remotes" with RemoteEvents Profile, Blueprint, Craft, Showcase [S5]
src/server → ServerScriptService.BlacksmithServer                                                 all RB
  Main.server Lifecycle Config Log Telemetry Safe TextFilter Router Handlers DataService BlueprintService
  AnalysisQueue CraftService PlotService [S5] · ShowcaseService World/WorldBuilder World/PlotWorld [S7]
  Vendor/ProfileStore.project.json   ModuleScript ProfileStore ← vendor/ProfileStore/ProfileStore.luau
src/client → StarterPlayerScripts.BlacksmithClient                                                all RB
  Main.client UI/* Input/* Editor/* Forge/* Minigames/{MinigameHost, InputCapture, views} Inventory/* Onboarding/* [S6]
  Smithy/{PromptController, StationStage, StationFx, InspectPanel, PlotPresence} [S7]
tests/ · scripts/verify.luau · tools/ [S8] · vendor/ProfileStore (MadStudio 45c9847, Apache-2.0, never edited)
```

### 1.3 Layering and requires

- **L1** Every Lune-run module lives in `src/shared`; `src/client` and `src/server` hold only RB code. No string
  require crosses a Rojo root; `tests/lib` requires nothing in `src/` (specs pass modules in).
- **L2** Layers, each requiring only lower ones: Definitions → Util → Blueprint → Physics → Minigames, Crafting →
  Pipeline → Items → Persistence, EditorCore, Showcase, World, ItemRender → Net → Session → RB code;
  `Session/SessionMachine` uses `Net/Protocol`'s wire types and no Net module requires Session. Upward calls go
  through injected callbacks or Signals; no cycles (Roblox errors on them; S8's T-META-07 checks both trees).
- **L3** Pure modules: relative string requires (`./X`, `../Dir/X`), no `game`, `script`, `task`, services or Roblox
  datatypes, no `init.luau`. RB files in `src/shared` start `--!strict` + `-- @roblox-bound`; no pure module
  requires them. RB code requires by instance path (`script.Parent.X`; clients `WaitForChild`).
- **L4** `Main.server` / `Main.client` are the only composition roots and wire every Signal. PlotWorld is called
  only by ShowcaseService (`setSlot`, `setLabel`), CraftService (`setActivity`), the `Showcase.TeleportHome` handler
  (`teleportHome`) and, through Signals, PlotService (`claim`, `release`); Telemetry never requires DataService,
  Physics never requires Crafting, `Smithy/*` never requires S6's controllers. Only `DataService` requires
  `Vendor.ProfileStore`.
- **L5** `Definitions/Network` tunables never change outcomes (no `BALANCE_VERSION` bump).

### 1.4 Project files and toolchain

```json
{ "name": "BlacksmithingGame", "tree": { "$className": "DataModel",
  "ReplicatedStorage": { "$className": "ReplicatedStorage", "Blacksmith": { "$path": "src/shared" } },
  "ServerScriptService": { "$className": "ServerScriptService", "BlacksmithServer": { "$path": "src/server" } },
  "StarterPlayer": { "$className": "StarterPlayer", "$properties": { "EnableMouseLockOption": false },
    "StarterPlayerScripts": { "$className": "StarterPlayerScripts", "BlacksmithClient": { "$path": "src/client" } } },
  "Workspace": { "$className": "Workspace", "$properties": { "StreamingEnabled": false } } } }
```
`src/shared/Remotes.model.json` = `{"className": "Folder", "children": [{"name": "Profile", "className":
"RemoteEvent"}, … Blueprint, Craft, Showcase]}`; `src/server/Vendor/ProfileStore.project.json` = `{"name":
"ProfileStore", "tree": {"$path": "../../../vendor/ProfileStore/ProfileStore.luau"}}`. With only `$path` nodes the
tree is self-contained: `test.project.json` (S8 §14) repeats these nodes and `$properties` and adds
`ReplicatedStorage.BlacksmithTests.{lib, fixtures, golden}`, `ServerScriptService.BlacksmithTestServer` and
`StarterPlayerScripts.BlacksmithTestClient` (rojo 7.7.0-rc.1 build and sourcemap verified, Evidence: E-S5.6).
Place settings: `StreamingEnabled = false` (S7 has no streaming code), `EnableMouseLockOption = false` (S6).
```toml
[tools]   # aftman.toml
rojo = "rojo-rbx/rojo@7.7.1"         # = the Studio plugin (rojo plugin install); 7.7.x serves MessagePack, rc.1 served JSON
lune = "lune-org/lune@0.8.9"
luau-lsp = "JohnnyMorganz/luau-lsp@1.70.1"   # >= 1.67.0: named --definitions, sourcemap-aware string requires
```
README commands: `aftman install`, `rojo serve`, `rojo build default.project.json -o Blacksmith.rbxlx`,
`rojo sourcemap default.project.json --include-non-scripts -o sourcemap.json`, `lune run tests/run`,
`lune run scripts/verify` (S8 §14 gives the luau-lsp line).

**Build checklist (README).** (1) Creator Dashboard: Max Players 8 (= `PLOT_COUNT`, one smithy each
**[Decision to confirm]**, Q2). (2) Data stores → deletion
template for automated right to be forgotten: standard key, store `PlayerData`, key pattern `User_{UserId}`, scope
`global`; test it with a dummy account; every later store holding user data gets its own. (3) Studio API access only
on S8's separate test experience. (4) After the first `rojo serve`, check both place properties in Studio. (5) Before
the first publish, the test tree (§14.10) comes out of the place (§14.12).

### 1.5 Boot and player lifecycle

```
Main.server: each step completes before the next
1 Remotes.assertPresent()
2 Validate.validateAll({Plan.validateDefs}) (§2.3): problems → Log ERROR; the Router answers every request,
  Profile.Hello included, with E_SERVER_CLOSING (banner, §12.12)
3 world = WorldBuilder.build()     -- S7: {plots = {{index, model, spawn}}}
4 PlotService.init(world.plots)    -- PLOT_COUNT ≥ Players.MaxPlayers, else Log ERROR live / WARN in Studio (reads 30)
5 DataService.init() (§9.1)        6 AnalysisQueue, BlueprintService, CraftService (250 ms sweep), ShowcaseService,
                                     TextFilter, Telemetry
7 wire Signals: PlotService.Assigned → PlotWorld.claim, Released → PlotWorld.release; DataService.ProfileLoaded →
  Router (Hello) + ShowcaseService.renderAll; ProfileReleased → CraftService.abort; ItemSaved, ItemRefreshed,
  SaveState → Profile.Notice (+ ShowcaseService.refresh)
8 Handlers.registerAll(Router); Router.bind()
9 PlayerAdded → Lifecycle.join; PlayerRemoving → Lifecycle.leave; join players already present; BindToClose (§9.1)
```
`Lifecycle.join(player)`, once per player and before any yield: `PlotService.assign` takes the lowest free plot,
sets `RespawnLocation` to its `HomeSpawn` (S7) and fires `Assigned`; no free plot → kick FULL; a character that
already exists (Studio race) gets `LoadCharacter()`; then `DataService.loadAsync` (§9.1). Players spawn on
their own plot (§13.3); "My smithy" sends `Showcase.TeleportHome`. `Lifecycle.leave`: `CraftService.abort(Left)` →
`ShowcaseService.unrenderAll` → `DataService.release` → `PlotService.release` → `TextFilter.forget` → `Router.forget`.
`Config` (server): `DATA_MODE`, `LOG_LEVEL`, `TELEMETRY_ECHO`, `FIXED_SEED`, `CHECK_MUTATE_YIELD`, `STRIKE_KICK`,
`TEST_HOOKS` (Studio + S8's bridge: `Lifecycle.simulateRejoinForTest`, `Router.resetStrikesForTest`). Expected
failures return `Err{code}`; `error()` is for bugs (→ `E_INTERNAL` + logged traceback); background work uses
`Safe.spawn` (`task.spawn` + `xpcall`); a handler that yields re-checks its preconditions afterwards.

`Main.client` wires `Net/Client`, S6's controllers and S7's `Smithy/*`: `PromptController.Triggered(kind, plotIndex,
slotIndex)` opens the editor (Draft), the forge flow (Forge), the item picker (Display) or the inspect panel
(Inspect) (§11.2, §12.1, §13.5).

### 1.6 Server execution: AnalysisQueue

One worker on Heartbeat runs the heavy pure jobs off the request path, one at a time, for at most
`ANALYSIS_SLICE_MS` 4 per Heartbeat (§4.9; the client's PreviewScheduler uses 6 ms, §11.13). The job receives
`checkpoint = function() if os.clock() - sliceStart > 0.004 then task.wait(); sliceStart = os.clock() end end`;
S2 calls it between phases and in long loops, never inside sort comparators or metamethods. Lanes, by priority:
P0 `Minigames.prepare` (StartStep; one burst within S3's generate budget), P1 `Pipeline.analyze` (Save, Begin),
P2 `Items/Recompute.item` (stale items, §9.7; deduped by item id, ≤ `RECOMPUTE_QUEUE_CAP` 64). P0 and P1 hold at
most `ANALYSIS_QUEUE_CAP` 16 jobs and one job per player, else `E_BUSY`; a throw gives `E_INTERNAL` and an ERROR log
with the blueprint hash. Inputs are deep copies; callers re-check state after the yield. A full queue drains in
≤ 13 s (a conservative bound; Evidence: E-S5.4). `Minigames.judge` runs synchronously in the Submit handler (S3 bound
`REPLAY_BUDGET_MS`). No Actors in the MVP.
```lua
AnalysisQueue.run<T>(player: Player?, lane: "Prepare" | "Analyze" | "Recompute",
	job: (checkpoint: () -> ()) -> T, dedupeKey: string?): (boolean, T | Protocol.ErrorCode)   -- yields
```

---

## 2. Domain model and Definitions

> One owner per type, one source per value. Definitions are pure frozen code, identical on client and server;
> player data is JSON-safe tables in one ProfileStore key; Instances are built from records and never read back.

### 2.1 Entities and where they live

```
DEFINITIONS  src/shared/Definitions (pure, deep-frozen; code is the only writer)
 EquipmentTypeDef -1:n- SlotDef, geometry (S2)     StepDef --> family row (S3 MinigameFamilies)
 MaterialDef   TierDef --rarityCap--> RarityDef    StatDef    CraftPlans[type] (S4): steps, weights, work sets
PLAYER DATA  Profile.Data, key "User_<UserId>" (§9.2)
 BlueprintRecord [GUID] --forge: deep copy--> ItemRecord [GUID = craft session id]
   parts: {PartData} --> SlotDef, ShapeId,       blueprint: BlueprintSnapshot, steps: {StepRecord} (frozen)
                         MaterialDef             physics, outcome (derived) --> RarityDef, StatDef
 smithy.displays {D1..D6 -> ItemId}, settings, uiFlags, quarantine, starterGranted
TRANSIENT  CraftSession (S5, memory) --> StepRecords + one ItemRecord (Items/Create.fromCraft)
WORLD      Instances built from records (S7)
```

A blueprint has 0..`MAX_PARTS` parts while edited and changes only through its owner's saves (`revision + 1`). An
item has 1 snapshot and 1..n step records, and only its derived block changes (§9.4). A display slot holds 0..1
item; an item sits in at most 1 slot.

### 2.2 Identifiers

```lua
--!strict
-- Definitions/Types.luau (S1): the only module that declares id unions (types only, returns {})
export type EquipmentTypeId = "Sword" | "Axe" | "Spear" | "Hammer" | "Armor"
export type SlotId = "Blade" | "Guard" | "Grip" | "Pommel"                                 -- Sword (MVP)
	| "Head" | "Haft" | "Tip" | "Shaft" | "Butt" | "Handle"                                 -- reserved: Axe, Spear, Hammer
	| "Helmet" | "Pauldrons" | "Chestplate" | "Bracers" | "Belt" | "LegPlates" | "Boots"   -- reserved: Armor
export type ShapeId = "Block" | "Wedge" | "CornerWedge" | "Cylinder" | "Ball"
export type MaterialId = "Iron" | "Steel" | "Bronze" | "Mithril" | "Obsidian" | "Wood" | "Leather"
export type StepId = "Smelting" | "Casting" | "Hammering" | "Quenching" | "Sharpening" | "Assembly" | "Riveting" | "Finishing"
export type FamilyId = "HoldZone" | "TimingStrike" | "RhythmSequence" | "PrecisionTrace" | "ReleaseTiming" | "FitPuzzle"
export type TierId = "Normal" | "Hard" | "Expert" | "Master" | "Hell"
export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Divine"
export type StatId = "Damage" | "Sharpness" | "Durability" | "Purity" | "Balance" | "Reach"   -- MVP (S4)
	| "SwingSpeed" | "Defense" | "Mobility"                                                      -- reserved
export type FactorId = "PartCount" | "Thinness" | "Asymmetry" | "SurfaceComplexity" | "EdgeLength" | "Joints"
	| "MaterialMix" | "Volume"          -- this order is "FactorId order" for every factor array (S2, §5.2)
export type StationId = "DraftingTable" | "Furnace" | "Anvil" | "Grindstone"                -- S7 (§13)
```

1. **Definition ids** are PascalCase, persisted verbatim and append-only: once an id can appear in `Profile.Data` it
   is never renamed or deleted, only retired with `enabled = false` (a rename needs a migration).
2. **`BlueprintId`**: client-minted GUID (`HttpService:GenerateGUID(false)`), upper-cased and format-checked by the
   server (`Canonical.guid`); `Blueprint.Save {blueprintId, draft}` is an upsert keyed by it (S5). **`ItemId`**: the
   craft session GUID, so a retried finalize never makes a second item. There are no id counters.
3. **Part ids**: integers 1..`MAX_PART_ID`, unique in a blueprint, allocated by the editor from a counter that starts
   at `max(id) + 1` when the blueprint opens and only grows (§11.5), and kept through undo and redo (S6); canonical
   order is ascending `id`.
4. Untrusted strings become typed ids only through `Catalog.get` / `isEnabled`; any other cast is a review error.
5. Every id value is PascalCase, flag ids included (S3's `HzInhumanRate` … `PtSparse`, S5's `LateSubmit`). The one
   exception is `ItemModelBuilder`'s `Orientation` (`STAND`, `FLAT`, `VIEW_H`, `VIEW_V`, §13.7): render presets,
   never stored or sent, spelled in capitals (`FLAT` is not the editor's Flat view, which is `VIEW_H`).

### 2.3 Definitions modules

`src/shared/Definitions/`, pure. S1 modules (shapes S1; owner columns as marked in §2.4): `Types`, `Catalog`,
`Versions` (§9.6), `Limits` (§3.6, §9.8), `Materials` (2 of 7 rows enabled), `EquipmentTypes` (1/1), `Steps` (3/8),
`Tiers` (2/5), `Rarities` (4/7), `Stats` (6/9, rows S4), `Balance`, `Validate`, `Manifest`. Other owners:
`MinigameFamilies` (3/6) S3, `CraftPlans` S4, `Network` S5, `World` and `Presentation` S7, `Audio` S6. Rows are
camelCase records written as ordered arrays, frozen at require time and never stored in `Profile.Data`.

```lua
export type Catalog<Def> = {
	ordered: { Def },            -- all rows, ascending `order`: the list consumers iterate
	enabled: { Def },            -- enabled rows, ascending `order`
	byId: { [string]: Def },     -- lookup only, never iterated (pairs order differs between Lune and Roblox)
	get: (id: string) -> Def?,   -- nil for unknown ids
	isEnabled: (id: string) -> boolean,
}
Catalog.build<Def>(rows: { Def }): Catalog<Def>   -- reads row.id/order/enabled; errors on a duplicate id or order
Catalog.deepFreeze<T>(t: T): T                    -- recursive table.freeze
```

`Validate.validateAll(extra: { () -> { string } }?): {string}` runs at server boot (non-empty → Log ERROR and the
Router answers every request with `E_SERVER_CLOSING`, §1.5), on the client (`warn`) and in Lune (`== {}`). Checks from
higher layers are injected through `extra` by the callers (`Main.server`, `Main.client` and the tests pass S4's
`Plan.validateDefs`, §7.1), since Definitions requires nothing above it. S1's base checks, to which owners append
theirs: **D1** ids and `order` unique per catalog, Tiers and Rarities `order` = 1..n; **D2** enabled rows reference
only enabled rows (`family`, `rarityCap`, `allowedSlots`); **D3** enabled tiers and rarities form `order` prefixes,
`Normal.dMin = 0`, `dMin(k) = dMax(k−1)`, last `dMax = 1`; **D4** `density > 0`, `hardness` and `toughness` integers
0–100, `color` 3 integers 0–255, `reflectance` ∈ [0, 1], `robloxMaterial` in `KNOWN_PART_MATERIALS` (Roblox-bound boot
also asserts `Enum.Material[name]`); **D5** slot ids unique, ≥ 1 required, `partsMin ≤ partsMax ≤ MAX_PARTS`,
`hitboxMin < hitboxMax` within ±`POS_ABS_MAX`; **D6** enabled rows carry their owner columns, step weights in S2's
factor order with Σ w = 1 ± 1e-9; **D7** `Versions.*` positive integers, every Definitions module in `Manifest.hashed`
or `Manifest.excluded`.

### 2.4 Definition record types

```lua
--!strict
-- Definitions/Types.luau (continued)
export type RGB = { number }       -- {r, g, b}, integers 0–255 (Color3.fromRGB at the edge)
export type Vec3 = { number }      -- {x, y, z}; Blueprint/Schema re-exports it
export type MaterialDef = {
	id: MaterialId, name: string, order: number, enabled: boolean,  -- order breaks governing-material ties (§7.2)
	class: "Metal" | "Mineral" | "Organic", blurb: string,
	density: number,               -- mass units per stud³, shown as kg
	hardness: number, toughness: number,   -- integers 0–100; S4's formulas divide by 100
	color: RGB, robloxMaterial: string, reflectance: number,   -- render values S7 consumes
	allowedSlots: { SlotId }?,     -- nil = any slot
	difficultyTerm: number,        -- S2: m in D_s, 0–1
	qualityTier: number,           -- S4: T in Q
}
export type SlotDef = { id: SlotId, name: string,
	required: boolean, min: number, max: number, rank: number }   -- rule columns S2 (§3.7)
export type FactorWeight = { factor: FactorId, w: number }
export type FactorRange = { factor: FactorId, lo: number, hi: number }
export type GeometryRules = {      -- field list and values S2 (§3.1, §5)
	hitboxMin: Vec3, hitboxMax: Vec3, partsMin: number, partsMax: number,
	strikingSlot: SlotId, gripSlot: SlotId, guardSlot: SlotId?, thicknessAxis: Vec3,
	refs: { FactorRange },         -- S2's factor order
}
export type EquipmentTypeDef = { id: EquipmentTypeId, name: string, order: number, enabled: boolean,
	kind: "Weapon" | "Armor", slots: { SlotDef }, geometry: GeometryRules }
export type StepDef = { id: StepId, name: string, order: number, enabled: boolean,
	family: FamilyId, factorWeights: { FactorWeight } }            -- weights S2; plan data in CraftPlans (S4)
export type TierDef = { id: TierId, name: string, order: number, enabled: boolean,
	dMin: number, dMax: number,    -- [dMin, dMax) on D_s; the last tier includes 1
	risk: string, color: RGB,
	rarityCap: RarityId, qualityMultiplier: number, failScoreFactor: number,   -- S4 (§8)
	failOutcome: "LowerQuality" | "DestroyMaterial" }                          -- S4; DestroyMaterial: Hell, Phase 2
export type RarityDef = { id: RarityId, name: string, order: number, enabled: boolean,
	color: RGB, minQuality: number }                                           -- minQuality S4
export type StatDef = { id: StatId, name: string, order: number, enabled: boolean, unit: string, decimals: number }
```

Family rows are S3's `MinigameFamilyDef` (`Definitions/MinigameFamilies`): the same identity columns plus every
family parameter, material and tier columns included. Definitions hold no other minigame modifiers.

### 2.5 Materials

`density` is in mass units per stud³ with Iron = 7.87 (iron's g/cm³), so mass shows in kg and typical swords weigh
about 0.8–1.5 kg (S2's calibration arming sword C02: 0.83 kg in Iron; the Starter Sword: 0.79 kg; E-S1.8)
**[Decision to confirm]** (Q13). Draft word bands: density Low < 6.0 ≤ Medium < 8.5 ≤ High; hardness, toughness Very
low ≤ 15 < Low ≤ 35 < Medium ≤ 60 < High ≤ 80 < Very high.

| id | order | MVP | class | density | hardness | toughness | color | robloxMaterial | reflectance |
|---|---|---|---|---|---|---|---|---|---|
| `Iron` | 1 | yes | Metal | 7.87 | 45 | 50 | 112, 114, 120 | Metal | 0.05 |
| `Steel` | 2 | yes | Metal | 7.85 | 70 | 55 | 196, 202, 210 | Metal | 0.18 |

MVP values **[Decision to confirm]** (Q13). Bronze, Mithril, Obsidian, Wood and Leather (orders 3–7) exist with
`enabled = false`; their rows, the blurbs and the rationale are in E-S1.7. Owner columns for Iron / Steel:
`difficultyTerm` (S2) 0 / 0, because materials are free and a tier-raising material would be a difficulty slider;
`qualityTier` (S4) 1.00 / 1.02. Steel's tighter minigames are S3's material columns.

### 2.6 Equipment types, steps and families

- **Sword** (order 1, Weapon): slots Blade, Guard, Grip, Pommel; Blade and Grip required; at most 12 / 8 / 6 / 4 parts,
  24 in total **[Decision to confirm]** (Q4); hitbox 1.6 × 5.0 × 0.6 stud **[Decision to confirm]** (Q3). Rule values
  and `geometry` are S2's (§3.1, §3.7). Axe, Spear, Hammer and Armor ids are reserved (Phase 3).
- **Steps** (order, family): **Smelting** 10 HoldZone · Casting 20 HoldZone (placeholder) · **Hammering** 30
  TimingStrike · Quenching 40 ReleaseTiming · **Sharpening** 50 PrecisionTrace · Assembly 60 FitPuzzle · Riveting 65
  TimingStrike · Finishing 70 RhythmSequence (bold = MVP; `order` is 10-spaced catalogue order). Which steps a type
  plays, in which order, on which parts, with which weight and feeding which stats lives only in `CraftPlans` (§7.1).
- **Families** (order): **HoldZone** 1 · **TimingStrike** 2 · RhythmSequence 3 · **PrecisionTrace** 4 ·
  ReleaseTiming 5 · FitPuzzle 6; rows and parameters S3 (§6).

### 2.7 Tiers and rarities

| Tier | order | MVP | dMin | dMax | risk | color | | Rarity | order | MVP | color |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `Normal` | 1 | yes | 0.0 | 0.2 | Low | 111, 191, 115 | | `Common` | 1 | yes | 170, 170, 170 |
| `Hard` | 2 | yes | 0.2 | 0.4 | Medium | 242, 193, 78 | | `Uncommon` | 2 | yes | 96, 196, 96 |
| `Expert` | 3 | – | 0.4 | 0.6 | High | 242, 140, 40 | | `Rare` | 3 | yes | 72, 140, 232 |
| `Master` | 4 | – | 0.6 | 0.8 | Very high | 217, 68, 43 | | `Epic` | 4 | yes | 168, 92, 224 |
| `Hell` | 5 | – | 0.8 | 1.0 | Extreme | 142, 27, 27 | | `Legendary` | 5 | – | 240, 164, 48 |
| | | | | | | | | `Mythic` / `Divine` | 6 / 7 | – | 232, 64, 64 / 255, 236, 180 |

```
tierFor(D)    = the enabled tier with the greatest order such that D ≥ dMin   (D on the 1e-4 grid, S2)
tierRawFor(D) = the same over all tiers (S2 reports both: the MVP clamp is data, not code)
MVP: D < 0.2 → Normal, D ≥ 0.2 → Hard [Decision to confirm] (Q1);  0.1999 → Normal, 0.2000 → Hard, 0.85 → Hard
```

S4 owns `rarityCap`, `qualityMultiplier`, `failScoreFactor`, `failOutcome`, `minQuality` (§8) and the Stats rows
(MVP Damage, Sharpness, Durability, Purity, Balance, Reach **[Decision to confirm]** (Q13); items key stats by
`StatId`). The MVP enables Common..Epic because its tiers cap at Epic. The UI prints a rarity's name next to its
colour.

### 2.8 Balance container and the BALANCE guard

`Definitions/Balance` (deep-frozen) holds the tunables that are not catalog columns: `Geometry` (S2, §4),
`Difficulty` (S2, §5), `Stats` (S4: rows per EquipmentTypeId, `MATERIAL_SCALE` = 100), `Quality` (S4, including γ)
and `Display` (S1: `MASS_UNIT_LABEL = "kg"`). `BALANCE_VERSION` changes with any outcome-affecting data or code
change. `Definitions/Manifest` lists the outcome-affecting data; S8's T-BAL-01 hashes exactly that list (changed
data under an unchanged version fails), and S8's pattern and outcome goldens catch outcome-changing code.

| `Manifest.hashed` | Fields |
|---|---|
| Materials | id, order, enabled, class, density, hardness, toughness, allowedSlots, difficultyTerm, qualityTier |
| EquipmentTypes · Steps | id, order, enabled, kind, slots (all but name), geometry · id, enabled, family, factorWeights |
| Tiers | id, order, enabled, dMin, dMax, rarityCap, qualityMultiplier, failScoreFactor, failOutcome |
| Rarities · Stats | id, order, enabled, minQuality · id, enabled |
| CraftPlans · MinigameFamilies | all · all but display text |
| Balance · Limits | Geometry, Difficulty, Stats, Quality · MIN_DIM, MAX_DIM, EPS_CONTAIN, CONTACT_TOL |

`Manifest.excluded`: Types, Catalog, Versions, Validate, Manifest, Network, World, Presentation, Audio, the other
Limits, `Balance.Display` and every display column (name, blurb, color, robloxMaterial, reflectance, risk, unit,
decimals), so a colour edit never forces a rebalance.

---

## 3. Blueprint format

### 3.1 Blueprint space and the Sword hitbox

| Axis | Direction | Meaning |
|---|---|---|
| +Y | along the blade, toward the tip | sword axis; pommel at low Y |
| +X | across the guard | blade plane = XY; cutting edges face ±X |
| +Z | through the blade's thickness | thickness axis |

- Right-handed, studs, never scaled. **Origin = centre of the hitbox's bottom face.** The hitbox is fixed and centred
  on the two **centre planes x = 0** (left/right) and **z = 0** (front/back): the mirror tool reflects across them
  (§3.8) and Asymmetry is measured about x = 0 (§5.2). The editor draws the x = 0 plane, and z = 0 while Shift+M
  is used (§11.2).
- A part renders as a Roblox `Part` with `Shape`, `Size = size`, `CFrame = root * CFrame.new(px, py, pz, qx, qy, qz, qw)`
  (conversions: §3.4).

```
   y = 5.00 ---+--------+--------+      HITBOX_MIN = (-0.80, 0.00, -0.30)
               |        |        |      HITBOX_MAX = (+0.80, 5.00, +0.30)
               |  any slot, any  |      1.60 wide x 5.00 long x 0.60 thick
               |  place inside   |
   y = 0.00 ---+--------o--------+--> +X        o = origin, x = 0 plane drawn
```

**[Decision to confirm]** (Q3) One envelope for all parts, no per-slot zones; the only rules beyond containment and
connectivity (§4.2 V3) are "blade above the grip" (§4.2 V4) and the slot counts (§3.7). 5.0 ≈ a character's height
(greatswords fit); 1.6 fits crossguards and cleavers.

Bounds `POS_ABS_MAX` 16, `MIN_DIM` 0.02 **[Decision to confirm]** (Q4), `MAX_DIM` 6.0 and `EPS_CONTAIN` 1e-4 live in
`Definitions/Limits` (§3.6; rationale §16.2). Bounds are **rejected, never clamped** (S1 Canonical); the editor clamps
visibly first.

### 3.2 Shapes and per-shape size rules

Local half extents `hx, hy, hz = size/2`; normalized `a = x/hx, b = y/hy, c = z/hz`.

| Shape | Solid (local) | Volume | Centroid (local) |
|---|---|---|---|
| `Block` | `|x|≤hx, |y|≤hy, |z|≤hz` | `8hxhyhz` | 0 |
| `Wedge` | Block and `c ≥ b` (full −Y and +Z faces, slope toward −Z/+Y) | `4hxhyhz` | `(0, −hy/3, +hz/3)` |
| `CornerWedge` | Block and `b ≤ a` and `b ≤ −c` (apex over (+hx, −hz)) | `8hxhyhz/3` | `(+hx/4, −hy/2, −hz/4)` |
| `Cylinder` | `|x| ≤ hx` and `y²+z² ≤ r²`, `r = min(hy, hz)` (axis = local X) | `2πr²hx` | 0 |
| `Ball` | `x²+y²+z² ≤ r²`, `r = min(hx, hy, hz)` | `4πr³/3` | 0 |

Areas, vertices, signed distances and supports: §4.3. Every row was checked against the engine in Studio
(mass and `CenterOfMass` of probe parts, E-S2.1).

**Per-shape hook for S1's Canonical** (S2 owns the rule, S1 calls it; the function lives in `Blueprint/Canonical`, S2
supplying its body, since Blueprint may not require Physics, §1.3 L2; idempotent, a no-op for editor data because the
editor enforces both rules at edit time):

```lua
-- Blueprint/Canonical (S1) calls this per part after the bound checks
canonicalSize(shape: ShapeId, size: Vec3): Vec3
--   Ball:     d = min(sx, sy, sz)  -> {d, d, d}
--   Cylinder: d = min(sy, sz)      -> {sx, d, d}    (Roblox draws exactly this; sx = length)
--   others:   unchanged
```

So the stored, analysed and rendered sizes are identical.

### 3.3 Record schema (Luau types)

```lua
--!strict
-- Blueprint/Schema.luau (S1): blueprint types every section uses; nobody redefines them
local DT = require("../Definitions/Types")
export type Vec3 = DT.Vec3             -- {x, y, z}: raw finite doubles, studs
export type Quat = { number }          -- {qx, qy, qz, qw} (CFrame.new order), canonical form §3.5
export type BlueprintId = string       -- upper-case GUID
export type PartData = {
	id: number,                -- integer 1..MAX_PART_ID, unique in the blueprint
	slot: DT.SlotId,           -- a slot of the blueprint's type
	shape: DT.ShapeId,
	material: DT.MaterialId,   -- per part (Q14); enabled and allowed for the slot
	pos: Vec3, rot: Quat,      -- part centre and orientation, blueprint space (§3.1)
	size: Vec3,                -- Part.Size along local X, Y, Z (Cylinder axis = local X)
}
export type BlueprintCore = { schema: number, name: string, type: DT.EquipmentTypeId, parts: { PartData } }
export type BlueprintDraft = BlueprintCore   -- client → server; the id travels as Save.blueprintId
export type PhysicsView = { mass: number, balance: number, reach: number }   -- S2 names and semantics (§4)
export type StepPreview = { step: DT.StepId, difficulty: number, tier: DT.TierId }
export type BlueprintAnalysis = {      -- Pipeline.summary(report); written by the server only
	balanceVersion: number, valid: boolean,
	issues: { string },                -- distinct S2 ValidationCode values, ≤ MAX_ISSUES_STORED
	physics: PhysicsView?,             -- absent when structural validation failed
	steps: { StepPreview },            -- plan order; empty when not analysed
}
export type BlueprintRecord = BlueprintCore & {   -- Profile.Data.blueprints[id]
	id: BlueprintId, revision: number,            -- revision 1 on creation, +1 per accepted save
	createdAt: number, updatedAt: number,         -- os.time(), server clock
	analysis: BlueprintAnalysis?,
}
export type BlueprintSnapshot = BlueprintCore & { sourceId: BlueprintId, sourceRevision: number }  -- in an item
export type BlueprintSummary = { id: BlueprintId, name: string, type: DT.EquipmentTypeId, revision: number,
	updatedAt: number, partCount: number, materials: { DT.MaterialId }, analysis: BlueprintAnalysis? }
return {}
```

- `schema` (`BLUEPRINT_SCHEMA` = 1) makes a blueprint self-describing outside the profile (fixtures, Phase 3
  sharing). After load every record and snapshot has the current value (§9.6); the wire accepts only it.
- `analysis` is a cache: stale when absent (the Starter Sword that Prepare grants has none, §9.6) or when
  `balanceVersion ≠ BALANCE_VERSION`; rewritten on every save, recomputed by the client for display when stale.
  Summary `materials` = distinct part materials in Materials order.
- Work in progress: saving needs only §3.6; S2's validation gates forging **[Decision to confirm]** (Q6). There is
  no mirrored flag: every shape mirrors to a rotated copy of itself (§3.8).

### 3.4 Transform representation and Roblox conversions

`pos` = part centre (`Part.Position`), `rot` = orientation, `size` = `Part.Size`, all in blueprint space (§3.1). The
matrix is exact for any non-zero quaternion, with no square root (orthonormal to 1.3e-15; E-S1.2):

```
s = 2 / (qx² + qy² + qz² + qw²)
R = | 1 − s(qy²+qz²)     s(qx·qy − qz·qw)   s(qx·qz + qy·qw) |
    | s(qx·qy + qz·qw)   1 − s(qx²+qz²)     s(qy·qz − qx·qw) |
    | s(qx·qz − qy·qw)   s(qy·qz + qx·qw)   1 − s(qx²+qy²)   |
world = pos + R·local;  columns of R = local X, Y, Z axes;  R(q) = R(−q)
```

| Conversion (Roblox-bound code only) | Formula |
|---|---|
| record → CFrame | `CFrame.new(x, y, z, Quat.toMatrix(rot))` (R00…R22, row-major) = `CFrame.new(x, y, z, qx, qy, qz, qw)` |
| record → size, shape | `Vector3.new(size[1], size[2], size[3])`, `Enum.PartType[shape]` |
| material → look | `Color3.fromRGB(table.unpack(def.color))`, `Enum.Material[def.robloxMaterial]`, `def.reflectance` |

> Instances are one-way views: `Vector3` and `CFrame` are float32 and a read-back changes almost every component
> (E-S1.2). The editor model is the plain table; nothing re-derives a stored transform from an Instance. Editor
> results (gizmo drags, typed Euler angles, mirror) are computed on doubles by `EditorCore/GizmoMath`,
> `EditorCore/Rotation` and `Blueprint/Mirror` through `Blueprint/Quat` (§11.6, §11.9); no record value is ever taken
> from `CFrame:GetComponents()`.

### 3.5 Canonical form and storage precision

`Blueprint/Canonical` (S1, with S2's per-shape hook) runs in the editor on every commit and again on the server
(Save, Begin). **No storage grid**: positions, sizes and quaternions stay the doubles the editor produced, so the
stored, analysed and rendered design is exactly what the player built. There is no second sanitizer.

| # | Rule | On violation |
|---|---|---|
| C1 | every number finite | reject `NonFinite` |
| C2 | \|pos_k\| ≤ `POS_ABS_MAX`; `MIN_DIM` ≤ size_k ≤ `MAX_DIM`; \|‖q‖² − 1\| ≤ `QUAT_INPUT_TOL` | reject `OutOfRange` / `BadRotation`, never clamp |
| C3 | if \|‖q‖² − 1\| > `QUAT_NORM_TOL` (1e-9): q ← q / ‖q‖ | — |
| C4 | hemisphere: negate q if qw < 0, or if qw = 0 and the first non-zero of (qx, qy, qz) is negative | — |
| C5 | −0 → +0 in `pos` and `rot` | — |
| C6 | S2 hook: Ball sides = min side; Cylinder Y = Z = min(Y, Z) (what Roblox draws; the editor enforces both) | — |
| C7 | parts sorted by ascending `id` | duplicate: reject `DuplicatePartId` |

**Idempotent** (`Canonical(Canonical(x)) = Canonical(x)` bit for bit):
- C1, C2 and C7 are predicates and a sort, and every canonical output passes them (after C3 ‖q‖² is within 1e-15
  of 1; C6's min of in-range sides is in range).
- C3 fires only above 1e-9, and one renormalization lands within a few ulps of unit (measured max 6.7e-16), so a
  second pass keeps q. Renormalizing on every pass would not be idempotent: a second q / ‖q‖ changes the bits of
  33 % of unit quaternions, so stored records would drift on every save. Editor quaternions (≈ 1e-16 off) are never
  touched.
- C4 is a sign choice: negation is exact and keeps the norm, after one pass the sign test holds, and q and −q are
  the same rotation. C5 and C6 are fixed points by construction.
- Measured: 0 failures over 10⁶ parts, including sloppy norms, threshold-hugging and qw = 0 cases (E-S1.1).

**Storage is lossless**: `JSONEncode` writes shortest round-trip digits that decode bit-identically (E-S1.3; S8's
S-PAR-03 checks a real key). A number costs ≤ 25 characters, the worst case §9.8 uses. The editor shows
≤ 4 decimals but keeps and sends the full double, and stores typed values as typed (S6).

### 3.6 Structural limits and wire sanitization

`Canonical.draft(raw)` is the only entry point for client blueprint data: it rebuilds a new table from known fields
(never stores or `pairs`-iterates a client table) and checks counts before looping.

| # | Check, in order | `CanonError` |
|---|---|---|
| 1 | `raw` is a table | `Malformed` |
| 2 | `schema == BLUEPRINT_SCHEMA` | `UnsupportedSchema` |
| 3 | `Names.sanitize(name)` (§3.9) | `BadName` |
| 4 | `type` known and enabled | `UnknownId` / `DisabledId` |
| 5 | `parts` an array, `#parts ≤ MAX_PARTS` | `Malformed` / `TooManyParts` |
| 6 | each part a table; `id` integer 1..`MAX_PART_ID`; `slot` of the type; `shape` known; `material` known, enabled, allowed for the slot | `Malformed` / `UnknownId` / `DisabledId` / `SlotNotInType` / `MaterialNotAllowed` |
| 7 | `pos`, `size` exactly 3 numbers, `rot` exactly 4 | `Malformed` |
| 8 | C1–C7 (§3.5) | `NonFinite` / `OutOfRange` / `BadRotation` / `DuplicatePartId` |

Errors carry a path (`"parts[7].rot"`); S5 maps `CanonError` to wire codes (§10.3). S2's geometric rules
gate forging, not saving. The editor clamps every transform path to these bounds visibly; a server rejection of an
editor value is a logged bug.

`Definitions/Limits` (one table, rationale in §16): `POS_ABS_MAX` 16 stud per component (inside S6's ×4 stage);
S2 values `MIN_DIM` 0.02 stud **[Decision to confirm]** (Q4, at most 0.05), `MAX_DIM` 6.0 stud, `EPS_CONTAIN` 1e-4,
`CONTACT_TOL` 0.01; `MAX_PARTS` 24 (the Sword limit); `MAX_PART_ID` 65,535; `QUAT_NORM_TOL` 1e-9; `QUAT_INPUT_TOL`
1e-2; `MAX_ISSUES_STORED` 8; names 1–32 code points, ≤ 256 input bytes; persistence limits in §9.8.

### 3.7 Slots and part limits

| Slot | Required | Min | Max | Ownership rank | Role |
|---|---|---|---|---|---|
| `Blade` | yes | 1 | 12 | 1 | striking slot: reach, edge, Sharpening work set |
| `Guard` | no | 0 | 8 | 2 | guard line for balance |
| `Grip` | yes | 1 | 6 | 3 | hand position (grip point) and physics axis |
| `Pommel` | no | 0 | 4 | 4 | counterweight |

- **[Decision to confirm]** (Q4) Blade and Grip required, Guard and Pommel optional; `MAX_PARTS = 24` is S1's
  structural cap (`Definitions/Limits`); slot maxima are validation rules (`SlotTooMany`, anti-filler). The
  Sword's `geometry.partsMin` 2 and `partsMax` 24 feed only the editor's part-count hint.
- A required slot must also keep **at least one kept part** (not Dust, not Enclosed, §4.4), else
  `SlotMissing{slot, reason = "Cleaned"}`. Validity therefore guarantees a non-empty Sharpening work set.
- Rank orders overlap ownership (§4.3): an overlap takes the material of the Blade first.

### 3.8 Mirror math

`Blueprint/Mirror` (pure; S2's math, the only mirror implementation; S6's tool wraps it) reflects parts across the
fixed planes x = 0 or z = 0. No negative scale: if a shape has a local reflection symmetry F, the image of
`R·S + c` is `(M·R·F)·S + M·c` and `M·R·F` is a proper rotation.

| Shape | Local symmetry F | Size after mirroring |
|---|---|---|
| Block, Wedge, Cylinder, Ball | reflect local X | unchanged |
| CornerWedge | diagonal `(x, y, z) → (−z, y, −x)` (maps CornerWedge(hx,hy,hz) onto CornerWedge(hz,hy,hx)) | `(sz, sy, sx)` |

Closed forms on `q = {qx, qy, qz, qw}` (`⊗` = Hamilton product, `H = 0.70710678118654757`), then S1's hemisphere rule:

| Plane | position | Block, Wedge, Cylinder, Ball | CornerWedge |
|---|---|---|---|
| `"X"` (x = 0) | `(−px, py, pz)` | `{qx, −qy, −qz, qw}` | `{qx, −qy, −qz, qw} ⊗ {0, H, 0, H}`, size `(sz, sy, sx)` |
| `"Z"` (z = 0) | `(px, py, −pz)` | `{−qx, −qy, qz, qw} ⊗ {0, 1, 0, 0}` | `{−qx, −qy, qz, qw} ⊗ {0, −H, 0, H}`, size `(sz, sy, sx)` |

```lua
--!strict
-- src/shared/Blueprint/Mirror.luau (pure)
Mirror.reflect(part: Schema.PartData, plane: "X" | "Z"): Schema.PartData   -- same id; the caller assigns new ids
Mirror.isSelfSymmetric(part: Schema.PartData, plane: "X" | "Z"): boolean   -- the solid is its own image, within EPS_GEOM
```

Verified: 10,000 random point tests over all shapes and both planes, 0 membership mismatches (max |Δsd| 1.7e-16); a
guard built as half + `reflect` measures Asymmetry 0.000000 (E-S2.6). "Centre on axis" (S6) recentres a selection on
x = 0 before mirroring.

### 3.9 Names and text rules

`Blueprint/Names.sanitize` (pure) checks blueprint names; an item takes its blueprint's name at forge.

| Rule | Value |
|---|---|
| Raw input | string ≤ 256 bytes, valid UTF-8 |
| Whitespace | ASCII space only; runs collapse to one; trimmed; tabs and newlines rejected |
| Length | 1–32 code points after normalization (≤ 64 bytes) |
| Letters | A–Z a–z, U+00C0–U+00FF except × ÷, U+0100–U+017F: Latin only **[Decision to confirm]** (Q18) |
| Digits, punctuation | 0–9 and `- _ ' . , ! ? & ( ) # + : /` (no `< >`: RichText stays inert; no quotes or backslash) |
| Content | at least one letter or digit; names need not be unique |

Errors: `NotString`, `TooLong`, `InvalidUtf8`, `BadChar`, `Empty`, `NoAlnum` (cases: E-S1.5).
- No item rename in the MVP **[Decision to confirm]** (Q18). `Profile.Data` stores the raw sanitized name, never a
  filtered one; the author's own UI shows it raw.
- Text shown to another player (plaques, `InspectView.name`) is broadcast-filtered by S5's `TextFilter`, cached by
  (itemId, raw); while pending or failed it shows S7's `InspectView.defaultName` ("Iron-Steel Sword"), never the raw
  text. `FilterStringAsync` needs the author in the server, which holds in the MVP.

### 3.10 Network shapes and sizes

Payloads obey the storage rules; remotes, envelopes and paging are S5's. Worst cases at 24 parts (E-S1.4):
`Blueprint.Save {blueprintId, draft}` 8,175 B + 54 B; `BlueprintRecord` to the owner 8,799 B; join-snapshot rows
`BlueprintSummary` 735 B and `ItemSummary` 277 B (70,950 B at 40 / 150); `OwnerItemView` 9,438 B; other players get
only S7's `InspectView` (≈ 0.9 KB in E-S5.7's model, no parts, flags or seeds);
`Profile.SetSettings {settings, uiFlags}` ≤ 2.9 KB. The server never accepts `analysis`, `revision`, timestamps or
item data from a client, and `Craft.Begin` names a stored blueprint by id. Summaries carry no parts: thumbnails fetch
records lazily (S6) through S5's batched get. No payload uses an `UnreliableRemoteEvent` (1,000-byte limit).

### 3.11 Module APIs (Blueprint/*, pure)

```lua
--!strict
-- Blueprint/Canonical.luau
export type CanonError = "Malformed" | "UnsupportedSchema" | "UnknownId" | "DisabledId" | "SlotNotInType"
	| "MaterialNotAllowed" | "TooManyParts" | "DuplicatePartId" | "NonFinite" | "OutOfRange" | "BadRotation" | "BadName"
export type CanonResult<T> = { ok: true, value: T } | { ok: false, code: CanonError, path: string }
Canonical.draft(raw: unknown): CanonResult<Schema.BlueprintDraft>   -- untrusted input (§3.6)
Canonical.quat(q: Schema.Quat): Schema.Quat                         -- C3–C5 on a quaternion that passed C1–C2
Canonical.isCanonical(core: Schema.BlueprintCore, opts: { bounds: boolean? }?): boolean
	-- schema, name, type and parts structurally valid and a fixed point; other keys (a record's id, revision, times,
	-- analysis; a snapshot's sourceId, sourceRevision) are ignored; bounds = false skips C2's bound tests and the enabled and allowed-slot checks (stored data: a row retired later stays readable)
Canonical.guid(raw: unknown): string?                               -- upper-cased 8-4-4-4-12 hex, else nil

-- Blueprint/Quat.luau: the only quaternion module (S2 math, S6 display, S7 rendering)
Quat.IDENTITY: Schema.Quat                                          -- {0, 0, 0, 1}
Quat.toMatrix(q: Schema.Quat): (number, number, number, number, number, number, number, number, number)  -- R00..R22
Quat.fromMatrix(r00: number, r01: number, r02: number, r10: number, r11: number, r12: number,
	r20: number, r21: number, r22: number): Schema.Quat             -- Shepperd; unit, C4–C5 applied
Quat.normalize(q: Schema.Quat): Schema.Quat
Quat.hemisphere(q: Schema.Quat): Schema.Quat                        -- C4 + C5
Quat.mul(a: Schema.Quat, b: Schema.Quat): Schema.Quat               -- a ⊗ b: rotate by b, then by a
Quat.rotate(q: Schema.Quat, v: Schema.Vec3): Schema.Vec3            -- R(q)·v
-- axis-angle and Euler conversions use trigonometry: EditorCore/Rotation (S6)

-- Blueprint/Names.luau, Blueprint/Views.luau
export type NameError = "NotString" | "TooLong" | "InvalidUtf8" | "BadChar" | "Empty" | "NoAlnum"
Names.sanitize(raw: unknown): (string?, NameError?)
Views.snapshot(r: Schema.BlueprintRecord): Schema.BlueprintSnapshot   -- deep copy, shares no table
Views.summary(r: Schema.BlueprintRecord): Schema.BlueprintSummary
```

---

## 4. Geometry pipeline

### 4.1 Overview, modules and determinism

```
BlueprintCore (canonical, §3) ─► Shapes.prepare (basis via Blueprint/Quat, AABB, analytic V / centroid / area)
 ─► QUICK: slot counts, containment ─────────────── errors? stop (editor highlight, Save stores the result)
 ─► V3 connectivity (GJK) + V4 orientation
 ─► the verdict, per part: CLEAN (Dust, Enclosed) ─► the measure: kept parts' surface samples, exposure, contact
 ─► V5 kept Blade + Grip ── invalid? stop
 ─► owned volumes (exact clipping / refined sampling) ─► MASS PROPERTIES (mass, COM, grip, balance, reach)
 ─► blade raster ─► outline ─► EDGE (chains, main-chain length)
 ─► per enabled step: work set (kept parts, CraftPlans) ─► 8 factors ─► g, m, d ─► tierRaw, tier   (§5)
```

| Module (`src/shared/Physics/`, pure) | Holds |
|---|---|
| `Shapes` | `prepare`, `sd`, `chord`, `chordLocal`, `support`, `aabb` (S6's extents), `extentAlong`, `maxDist` |
| `Gjk` | `within(a, b, tol)`, `distance(a, b)` |
| `Sampling` | volume and surface samples, the rank, exposure: the verdict (cleaning) and the measure |
| `MassProps` | owned volumes (convex clipping), mass, COM, grip frames, guard line, balance, reach |
| `Edge` | blade raster, outline, chains, `cutIndex` |
| `Factors`, `Difficulty` | §5 |
| `Analyze` | orchestration, validation, budgets, checkpoints; the `Analysis` types (§4.7) |

Determinism rules for `Blueprint/`, `Physics/` and `Pipeline` (one result on Lune, client and server):
- Arithmetic `+ − × ÷`, `math.sqrt/floor/ceil/abs/min/max`, comparisons. No trig, `^`, `exp/log`, `math.random`.
  Literal constants: `PI = 3.141592653589793`, a 32-direction unit circle pasted with 17 digits, `cbrt` = power-of-8
  range reduction + 8 fixed Newton steps.
- Numeric `for`/`ipairs` only; iterated tables are arrays; sums in part order, then sample order; sorts with total
  orders. No `--!native` unless S8's cross-platform digest passes.
- Every boundary predicate uses `EPS_GEOM = 1e-7`: buried iff `sd < −EPS_GEOM`, on a surface iff `|sd| ≤ EPS_GEOM`.
- Sampling details are pinned by the reference prototype `docs/spec/prototypes/S2/v2/` (loops: local X outermost, then
  Y, Z; cell centres `−h_k + (i + ½)·2h_k/n_k`); goldens come from it. The build differs on purpose where §4.3 (what an
  exact copy owns, the overlap budget, the cut face), §4.4 (the rank, the Enclosed verdict, the measure on the kept parts
  alone) and §4.5 (a grip part's vote) say so; `tests/Physics/Reference.spec` pins the rest, handing the prototype the parts
  in rank order: its lower index is the build's higher rank.

### 4.2 Validation

| # | Rule | Error record `{code, partId?, slot?, reason?}` |
|---|---|---|
| — | Canonical form, ids, bounds, ≤ 24 parts | S1 Canonical (§3.5–3.6), before S2 |
| V1 | per slot `min ≤ count ≤ max` (§3.7) | `SlotMissing{slot}`, `SlotTooMany{slot}` |
| V2 | world AABB inside the hitbox ± `EPS_CONTAIN` | `OutOfHitbox{partId}` |
| V3 | contact graph has one component | `Disconnected{partId}` per part outside the main component |
| V4 | volume-weighted centroid of all Blade parts beyond the grip point along the physics grip axis | `BladeNotAboveGrip` |
| V5 | each required slot keeps a kept part (§4.4) | `SlotMissing{slot, reason = "Cleaned"}` |

- V1–V2 = `Pipeline.quick` (every edit). Every error of the first failing stage (quick, then full) is returned, in
  rule then part order; valid ⇔ none.
- **Containment is exact**: polyhedra use their world vertices; a cylinder with axis `u` extends
  `hx·|u_k| + r·sqrt(max(0, 1 − u_k²))` per world axis; a ball `c ± r`. Parts flush with a wall pass.
- **Contact**: distance ≤ `CONTACT_TOL = 0.01` (overlap = 0), AABB broad phase with 0.01 margin, then GJK on the
  supports (Block `(sgn·h)`, polyhedra = max-dot vertex in fixed order, Cylinder `(sgn dx·hx, r·(dy,dz)/|·|)`, Ball
  `r·d/|d|`), ≤ `GJK_MAX_ITER = 48`, early outs on the lower bound `v·w/|v| > tol` and the upper bound `|v| ≤ tol`.
  256 decisive pairs of 300 random ones agree with brute force (the other 44 fall inside its tolerance band; mean
  3.1, max 9 iterations; E-S2.3).
- **Main component** = the one with the most Grip volume, else the largest volume, else the lowest index. Each
  floating component reports `{partIds, gap, dir, nearestPartId}` (GJK closest pair; `dir` moves it toward the main
  component), which S6 uses for "Snap to touch".
- `Blueprint.Save` of an invalid design stores the validation result only; measurement runs only when valid
  (`opts.measureInvalid` lets the editor preview measure anyway).

### 4.3 Measurement representation

No global voxel grid (it changes mass by 2× under a 0.01 nudge, E-S2.4): analytic per-part quantities, corrected by
samples in each part's **own** frame.

```
signed distance (local; exact inside, lower bound outside, 1-Lipschitz, ≤ 0 = inside)
Block        max(|x|−hx, |y|−hy, |z|−hz)
Wedge        max(Block, (y·hz − z·hy)/sqrt(hy²+hz²))
CornerWedge  max(Block, (y·hx − x·hy)/sqrt(hx²+hy²), (y·hz + z·hy)/sqrt(hy²+hz²))
Cylinder     max(|x|−hx, sqrt(y²+z²) − r)          Ball  sqrt(x²+y²+z²) − r
```

| Structure | Definition |
|---|---|
| Volume samples | local grid `n_k = clamp(ceil(size_k/h), 2, 48)`, ≤ 3000 per part (coarser `h` per part until it fits), kept iff `sd < −1e-9`; weight `V/count` |
| Surface samples | per face `ceil(edge/h_s)` per edge (≤ 64); triangles keep `s + t ≤ 1`; cylinder caps a disk grid, side 8/16/32 directions (circumference/h_s ≤ 8, ≤ 16, else) × axial; ball cube-sphere grid `clamp(ceil((πr/2)/h_s), 2, 64)` per cube-face axis, Jacobian weights normalized to `4πr²`. Each sample has a normal and patch half-vectors `e1, e2`. The verdict's grid (§4.4) keeps at least 2 cells per triangle edge, fixes a ball's cells and lays a CornerWedge's second slope from the corner that mirrors the first's, so that a part and its mirror image read alike |
| Blade raster | XY cells (§4.6) |

**Overlap ownership.** An overlap counts once, for its owner. Priority: kept parts, then slot rank (§3.7), then the
rank of §4.4 (the larger part), so no id decides. `V_own(p) = V_p − V(p ∩ ∪ higher(p))`, with the first moment likewise:
- all polyhedra and ≤ `MAX_EXACT = 3` higher overlapping parts: **exact** convex clipping (≤ 8 half-spaces per part),
  inclusion–exclusion over the subsets, volume and moment by tetrahedra;
- otherwise (a Ball or Cylinder involved, or more parts): midpoint sampling of the overlap box in p's frame at
  `H_OVERLAP = 0.0125` (4–24 cells per axis).
An exact copy of a higher part owns nothing, whatever its shape; an owned volume of 0 contributes no moment;
`N_OVERLAP_WORK` serves kept parts first. Exact clipping builds each cut face from the plane, not from the vertices found on
it as the prototype does: within 4e-15 of the prototype, up to about 3e-4 of a part's volume on faces nearly coplanar with a
cut.
Laminated plates measure their exact mass (error 0.000 %, X07); segmented blades within 0.01 of G (E-S2.5).

### 4.4 Exposure and cleaning

A surface sample `s` of part p (normal n) is **hidden** by another part q if: it is buried (`sd_q(s) < −EPS_GEOM`);
or it lies on q's surface and q **ranks** higher (coincident face, counted once); or its probe
`s + δ·n`, `δ = HIDE_OFFSET = 0.012` (= CONTACT_TOL + 0.002), is inside q. Any gap that validation calls connected
therefore hides the faces across it, and faces 0.002–0.004 apart are no longer both exposed.

**Rank** (`Sampling.ranked`): the larger part first, then by where it stands (lower y, then smaller \|x\|, x, z), then by
half extents and turn; exact copies, which tie on all of that, by the names of their slot and material; only what is the
same in every way falls to the index. It settles who keeps a coincident face, which of two exact copies survives, who
owns an overlap within a slot (§4.3) and who spends the measure's budget first, so that invisible choices of id and order
cannot move a tier (§5). A part wholly inside another, flush with its face, gives the face up to it, whatever the ids: 4 such
plates in a real blade are cleaned, and the blade stays. An exact copy in a slot whose name comes after its original's changes
nothing; in one whose name comes first it takes over, which is no more than relabelling the part (§17.2).

First the **verdict**, per part: what gets cleaned. Then the **measure**: what factors read, on the kept parts alone.

| Class | Test | Effect |
|---|---|---|
| Dust | `V_p < MIN_PART_VOLUME = 0.0002` stud³ | cleaned: no samples, hides nothing |
| Exact copy | `Shapes.sameSolid` with a higher-ranked part (it lies wholly on that part's surface) | Enclosed: no samples, hides nothing |
| Enclosed | the verdict reads under `ENCLOSED_EXPOSED_MAX = 0.02` of the part's area | cleaned |

**Verdict.** Each other part, on a grid of its own: the first `H_LADDER` factor of `H_SURF` with at most
`VERDICT_SAMPLES = 64` samples by its Block estimate (`2(ab + bc + ca)`, `a = ceil(size_x/h)`…; the last factor if none
fits); a Ball `VERDICT_BALL_NF = 4` cells per cube-face axis, whatever its radius (its largest sample weighs 1.64 %, so no
lone sample keeps it); triangles at least `VERDICT_TRIANGLE_CELLS = 2` cells per edge. Against every part but copies and
Dust, with no budget, stopping once 2 % shows. How many other parts there are changes neither the grid nor which patches
get looked at: only a part that really covers this one changes what it reads (§17.2). A part too far to change over the patch
(`|sd_q| > |e1| + |e2|` at s and at its probe) that hides the centre hides all of it; with no part near, all of it shows.
Otherwise a sample's patch reads:
- **Flat** (a polyhedron's faces, a Cylinder's caps): nothing if one part hides its centre and 4 corners, at
  `VERDICT_CORNER = 0.98` of the half-vectors (the hiding regions are convex, and two parts can leave a slit between them).
  Otherwise it is **measured** on 4 lines along `e1` and 4 along `e2`, at ±0.25 and ±0.75 of the other half-vector. A convex
  part hides one interval of a line at the surface and one on the probe's line (`Shapes.chordLocal`, at the hide test's own
  level sets), so what shows of a line is exact, however narrow, and past the part's own rim nothing counts. A boundary across
  a line is read to the bit and one along a line not at all, so a family's mean stands for the patch if its lines agree: the
  family whose lines agree better wins; a family that reads nothing loses to one that reads something (what shows lies between
  its lines); of two that agree alike, the smaller reading stands.
- **A Cylinder's side**, which has no straight lines across it: uniform (all of it or nothing) if its centre and 4 corners all
  show, or one part hides all five; otherwise the exposed fraction of its 4 × 4 sub-grid, the sub-points back on the surface
  with their own normals; if no sub-point shows, `VERDICT_STRIP_CENTRE = ¼` of the patch if the centre showed,
  `VERDICT_STRIP_RIM = 1/16` if a corner did, else nothing.
- **A Ball** keeps the centre verdict.

What each of these cannot see is in §17.2.

**Measure.** The kept parts against kept parts only, once, on a ladder (`N_SURF_WORK`) and a sub-grid budget
(`N_SUB_WORK`) of their own, in rank order. A planar sample whose patch may straddle a hiding boundary (some q with
`|sd_q| ≤ |e1| + |e2|` at s or at its probe; every other q's verdict is constant over the patch) is tested at its 4
corners; if they disagree with the centre, its weight is the exposed fraction of a 4 × 4 sub-grid. Curved samples keep
the centre verdict. Contact areas (§5.2) are read on the same grid. Cleaned parts neither hide kept surfaces nor coarsen
their grid nor use their budget, so enclosed parts leave D bit-identical while the kept set is unchanged.

This is where the build departs from the prototype, which decides Enclosed from one pass over all parts, on one grid and
one sub-grid budget, so that other parts move the verdict, and which goes by index where the build goes by rank; its rule is
what the measure keeps (E-S2.11).

Cleaned parts count for validation counts, containment, connectivity, V4, mass, COM and the physics
grip frame (a lead core is a legal balance trick; an enclosed part owns no volume); they never count for reach, any
factor, the work sets, the edge or the governing material.

### 4.5 Mass properties

```
U = Σ_p V_own(p)          M = Σ_p ρ_p·V_own(p)          COM = Σ_p ρ_p·M1_own(p) / M
```
`ρ` = `Definitions/Materials.density` (mass units = kg in the UI). Exact for polyhedra.

| Output | Definition (unit: studs unless noted) |
|---|---|
| `gripPoint` g | volume-weighted centroid of all Grip parts (hand = Motor6D binding point) |
| `gripAxis` A | normalized Σ V·ê over the Grip parts that vote, XY projection, `ê_y ≥ 0`. A part votes if it has an axis (Cylinders: local X; polyhedra whose longest half extent ≥ 1.5 × the middle one; never Balls or dust) and that axis tilts ≤ 45° from +Y, in 3D, so a level bar or a handle along Z, which has no way up, neither tilts the sword nor breaks its mirror image. `(0, 1)` if no part votes |
| `guardPos` | `(c_Guard − g)·A` (volume-weighted Guard centroid); no Guard → top of the grip |
| `balance` | `(COM − g)·A − guardPos` (point of balance from the guard toward the tip); `balanceFromHand = (COM − g)·A` |
| `reach` | max distance from g over **kept** Blade parts (vertices; cylinder caps `sqrt(|c±−g|² + r² + 2r·|(c±−g)⊥|)`; ball `|c−g| + r`) |
| `bladeLength`, `totalLength`, `comOffAxis` | kept Blade top along A − g·A − guardPos; extent of all parts along A; `(COM − g)·N` |

Physics frame = all Grip parts (balance, reach, display pivot). **Difficulty frame** = point of the kept Grip parts,
axis fixed at blueprint +Y (Thinness length, edge facing test, the trace's frame), consistent with the fixed plane
x = 0: no grip part, visible or hidden, can steer a factor (A25–A27, E-S2.7).

### 4.6 Sharpenable edge

1. **Raster.** Cells `EDGE_CELL = 0.02` (coarsened by the ladder until ≤ `EDGE_MAX_CELLS = 12000` cells and
   ≤ `EDGE_MAX_WORK = 30000` cell × part tests), x anchored at the plane x = 0 (mirror-symmetric cells), y at the lowest
   kept Blade point (Y translation-exact). A cell is covered iff its centre's Z line passes within
   `RASTER_TOL = 0.005` of a kept Blade part (slab, half-space and AABB tests dilated), so seams and connected gaps
   never open. Thickness = merged chord length; `hilt` = a dilated chord through a kept non-Blade part.
2. **Outline.** Crack edges with the covered cell on the left, traced into loops (8-connected), outer (CCW) loops only.
3. **Eligibility.** Not buried (outer cell not `hilt`) and inner thickness ≤ `EDGE_MAX_THICK = 0.25`; a fully eligible
   loop opens at its lowest vertex.
4. **Geometry.** Runs → Douglas–Peucker (tolerance 1 cell, doubled until ≤ `EDGE_MAX_POINTS = 256` points); segments
   whose outward normal faces the pommel (`n·A < −EDGE_DOWN_COS = −0.5`) are dropped, such gaps < 3 cells bridged,
   chains < 3 cells dropped.
5. **Output.** Chains sorted by length (ties: first point x, then y). **EdgeLength = the main (longest) chain** — the
   chain `PrecisionTrace.sidesFromChains(chains, gripPoint, gripAxis)` (S3) splits at its point farthest along the axis;
   other chains count for nothing, so an edge broken by pommel-facing flanks plays and measures its longest
   run. Outer loops are CCW: the main chain of a symmetric blade starts at the +X base, runs over the tip and ends at
   the −X base. `cutIndex = clamp((bladeLength/bladeMeanThickness − 10)/50, 0, 1)` is reported
   for S4 (1 = thin and long, 0 = wide and heavy).

The F5 starter's main chain is 5.433 (one chain); 4 strips, 5–10 segments with 0.004–0.009 gaps and grip nudges up to
0.02 all measure 5.433 (X04, E-S2.5).

### 4.7 Analysis types

```lua
--!strict
-- src/shared/Physics/Analyze.luau (pure)
export type ValidationCode = "SlotMissing" | "SlotTooMany" | "OutOfHitbox" | "Disconnected" | "BladeNotAboveGrip"
export type ValidationError = { code: ValidationCode, partId: number?, slot: SlotId?, reason: "Cleaned"? }
export type FloatingComponent = { partIds: { number }, gap: number, dir: Vec3, nearestPartId: number }
export type ValidationResult = { ok: boolean, errors: { ValidationError }, components: { FloatingComponent } }
export type PhysicsReport = {
	mass: number, volume: number, com: Vec3, gripPoint: Vec3, gripAxis: Vec2, guardPos: number,
	balance: number, balanceFromHand: number, reach: number, bladeLength: number, totalLength: number,
	comOffAxis: number, edgeLength: number, cutIndex: number,
	kept: { boolean }, ownedVolume: { number },              -- per part, in blueprint order
}
export type EdgeChain = { points: { Vec2 }, length: number }  -- Vec2 = {x, y} array, blueprint XY
export type EdgeProfile = { chains: { EdgeChain }, length: number, cell: number, bladeArea: number,
	bladeMeanThickness: number, gripPoint: Vec3, gripAxis: Vec2 }   -- difficulty frame, for sidesFromChains
export type FactorValue = { factor: FactorId, raw: number, x: number }
export type StepAnalysis = {
	step: StepId, g: number, m: number, d: number, tierRaw: TierId, tier: TierId, material: MaterialId,
	terms: { { factor: FactorId, w: number, x: number } },   -- the step's weight list (§5)
	factors: { FactorValue },                                -- all 8, FactorId order, on this step's work set
}
export type Analysis = {
	balanceVersion: number, validation: ValidationResult, cleaned: { { partId: number, reason: "Dust" | "Enclosed" } },
	physics: PhysicsReport?, edge: EdgeProfile?, steps: { StepAnalysis }?,    -- nil while invalid
	budget: { hSurf: number, hVol: number, edgeCell: number, surfSamples: number, volSamples: number },
}
export type AnalyzeOptions = { checkpoint: (() -> ())?, measureInvalid: boolean? }
Analyze.run(core: Schema.BlueprintCore, opts: AnalyzeOptions?): Analysis   -- reads Definitions for core.type
Analyze.quick(core: Schema.BlueprintCore, opts: { connectivity: boolean? }?): ValidationResult
```

`steps` follows CraftPlans order and holds enabled steps only. Physics is not quantized; g, m, d are
(§5). No cached geometry summary and no inertia in the MVP.

### 4.8 Pipeline

`src/shared/Pipeline.luau` (pure; S2, with S4 for the plan and preview) is the only composition used by S6's
PreviewScheduler, S5's BlueprintService and CraftService (as the AnalysisQueue job), `Items/Recompute` and the tests.

```lua
--!strict
export type Report = {
	core: Schema.BlueprintCore, analysis: Analyze.Analysis,
	plan: Crafting.CraftPlan?, preview: Crafting.Preview?,   -- S4; only when analysis.validation.ok
}
Pipeline.analyze(core: Schema.BlueprintCore, opts: Analyze.AnalyzeOptions?): Report
	-- asserts Canonical.isCanonical(core); Analyze.run; then (valid only) S4's Plan.build and preview
Pipeline.quick(core: Schema.BlueprintCore, opts: { connectivity: boolean? }?): Analyze.ValidationResult
Pipeline.summary(report: Report): Schema.BlueprintAnalysis   -- S1's compact record; Blueprint.Save stores only this
Pipeline.summaryOf(validation: Analyze.ValidationResult): Schema.BlueprintAnalysis
	-- a Save that fails `quick`: valid = false, issues = distinct codes, no physics, steps = {}
Pipeline.stepInput(report: Report, stepIndex: number, seed: number): Minigames.PrepareInput
	-- { family = Steps[step].family, seed, material = steps[i].material, tier = steps[i].tier,
	--   factors = steps[i].factors, edge = analysis.edge (PrecisionTrace only), balanceVersion }
Pipeline.outcome(report: Report, runs: { Crafting.StepRun }): Crafting.Outcome   -- S4's part (§8.5)
```

Work sets come from `Definitions/CraftPlans` through `Blueprint/WorkSet` (kept parts only); Physics never requires
Crafting.

### 4.9 Execution model and cost

`Analyze.run` calls `opts.checkpoint()` between phases and at least every `CHECK_UNITS = 500` work units (one unit ≈
one shape query), only at top-level loop points (never inside sort comparators or metamethods), and keeps no
module-level state, so a checkpoint may raise to cancel a stale run (S6's PreviewScheduler does). Callers run it in a coroutine whose checkpoint yields once the slice is used: **4 ms per
Heartbeat on the server** (S5's AnalysisQueue, §1.6: priority lanes, FIFO in each, cap 16, one job in flight per player), **6 ms per frame on the
client** (S6's PreviewScheduler, which also abandons stale revisions). No Actors.

| Budget (deterministic coarsening: first `H_LADDER` factor that fits) | Value |
|---|---|
| `H_LADDER` | {1, 1.25, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10, 12, 16} |
| `H_VOL`, `N_VOL_TOTAL`, `N_MAX_PART` | 0.05, 12,000 volume samples, 3,000 per part |
| `H_SURF`, `N_SURF_WORK` | 0.04, 40,000 surface samples × (1 + candidate parts) of the measure (§4.4), by the ladder's Block estimate: a thin cylinder samples about 2 × that |
| `N_SUB_WORK` | 24,000 boundary sub-point × candidate tests of the measure |
| The verdict (§4.4) | no budget: at most about 70 samples on a polyhedron, 96 on a Ball, 128 on a thin Cylinder (the estimate treats every part as a Block) × up to 8 lines of 2 chords (25 tests on a Cylinder's side) × 23 near parts per part; other parts cost it time, never an outcome |
| `N_OVERLAP_WORK` | 40,000 refined overlap cells × (1 + higher parts), kept parts first |
| `EDGE_MAX_CELLS`, `EDGE_MAX_WORK` | 12,000 cells, 30,000 cell × part tests |
| `THICK_BUDGET`, `ASYM_WORK` | 400 Thinness probes, 30,000 Asymmetry probe × candidate tests, per work set |

Measured (Lune best of 5; Studio ≈ 2.6 × Lune): F5 4.7 ms (≈ 12 ms Studio), arming 5.5 (14), ornate 18 parts 14.6
(38), cleaver 15.9 (41); worst constructed cases, 24 large overlapping blocks 26.3 (68) and 24 rotated cylinders or
wedges 22.1 / 20.9 (57 / 54), down from 36–57 ms Lune in the first prototype. Those are the prototype's rule; with §4.4's
verdict, median of 21 with M3's share emulated, fixtures and specks stay under 33 ms Lune (C05 14.2, ≈ 37 Studio; P1 31.7,
≈ 82) and the worst designs found reach 54.6 (≈ 142), the verdict alone 30.7 (≈ 80), §17.2. The median longest run between
checkpoints is ≤ 0.52 ms Lune (≈ 1.3 ms Studio; worst observed 1.0 ms Lune with GC), so a server frame carries the
4 ms slice plus at most one such run (E-S2.8). S8's T-PERF-01 bounds every gap by `CHECKPOINT_GAP_LUNE_MS` 0.35
(§14.11): the build lowers `CHECK_UNITS` until the measured gaps meet it (§17.2). The adversarial cost fixture is P1
(24 large overlapping tilted blocks; P1–P5 in E-S2.8), used by T-PERF-01, S-PERF-01 and M-09; the first two also run
`docs/spec/prototypes/S2/verdict/worst_P.json`, canonical and valid designs, the worst a climb found against §4.4's verdict.
The editor's preview cadence (debounce, rate) is S6's client constant, outside BALANCE. Ceiling ≤ 75 ms Studio on real designs
(the F, C and X fixtures; the slowest, C05, ≈ 37), checked by S8's S-PERF-01; if a Studio measurement exceeds it there, halve
`N_SURF_WORK` and `EDGE_MAX_WORK`. That fallback does not reach the verdict, which has no budget to halve: one that counted
near parts would be the hidden-part channel again (§4.4). **[Decision to confirm]** A hostile design takes about 142 ms
Studio, sliced at 4 ms a Heartbeat: about 36 Heartbeats, no frame hitch, one job per player (§17.2).

---

## 5. Difficulty

> A step's difficulty comes from the design alone in the MVP: what the player built, measured on the parts that step
> works. Hidden filler, specks, invisible construction choices and the material cannot move a tier.

### 5.1 Structure

```
W_s     = kept parts of step s's work set (Definitions/CraftPlans.worksOn via Blueprint/WorkSet;
          MVP: Smelting All, Hammering All, Sharpening {Blade})
x_f     = factor f measured on W_s, normalized to [0, 1] (§5.2); all 8 factors are output for every step
g_s     = q( Σ_f w_{s,f} · x_f )                    w from Definitions/Steps (arrays, FactorId order, Σ = 1)
m_s     = q( difficultyTerm(governing material) )   governing = kept W_s material with the highest
                                                     (difficultyTerm, hardness), ties by Materials order
d_s     = q( 1 − (1 − m_s)(1 − g_s) )               soft OR, in [0, 1]; stored as the step's difficulty
tierRaw = highest tier of all tiers with dMin ≤ d_s;  tier = highest enabled tier with dMin ≤ d_s
q(x)    = Util/Quantize.q(x, 1e4), applied at production, before any threshold
norm(v, lo, hi) = clamp((v − lo)/(hi − lo), 0, 1)
```

The governing material also drives S3's `m_material` (copied by `Plan.build`, passed by `Pipeline.stepInput`).

### 5.2 Factors

| Factor | Raw value on W_s | x |
|---|---|---|
| `PartCount` | `n = Σ min(1, V_p / V_PART_FULL)`, `V_PART_FULL = 0.004` stud³ | `norm(n, 3, 16)` |
| `Thinness` | below | in [0, 1] |
| `Asymmetry` | below | `norm(Asym, 0, 0.6)` |
| `SurfaceComplexity` | `r = S_exp / (6·cbrt(V)²)`, `S_exp` = the measure's exposed area (§4.4), V = owned volume; a cube scores 1 | `norm(r, 2.3, 2.9)` |
| `EdgeLength` | main-chain length E (§4.6), studs; the same on every work set | `norm(E, 4.8, 8.0)` |
| `Joints` | `J = Σ_{kept contacting pairs} min(s_p, s_q)·(1 + clamp(1 − a_pq/0.05, 0, 1))`, `s = min(1, V/V_PART_FULL)`, `a_pq` = mean contact area (stud²) | `norm(J, 3, 24)` |
| `MaterialMix` | k = distinct materials | `norm(k, 1, 4)` |
| `Volume` | `V = Σ V_own` (stud³) | `norm(V, 0.08, 0.80)` |

**Thinness** ("minimum thickness / length", robust to how the shape is split):

```
probes   = every k-th volume sample of W (part order, then sample order), k = max(1, ceil(n_W / THICK_BUDGET = 400)),
           kept if owned (not inside a higher-priority part); a Ball probe moves to its centre, a Cylinder probe to
           its projection on the axis (round parts are not thin)
tau(s)   = min( C(s, Z), C(s, theta) )   C = union chord through s over W, gaps ≤ CONTACT_TOL merged, grown from [0, 0]
theta    = owner's thinnest local axis (Ball X; Cylinder X if 2hx ≤ 2r else local Y; polyhedra the smallest
           half extent, ties X < Y < Z)
L        = extent of W along +Y;   sigma = L / max(tau, 1e-6);   phi = norm(sigma, SIGMA_LO = 45, SIGMA_HI = 130)
Thinness = (Σ w·phi² / Σ w·phi) · min(1, Σ_{phi>0} w / (THIN_SHARE_MIN · Σ_{W∩Blade} w))     (Σ_W w if no Blade part)
```

The self-weighted mean lets the thin metal set the factor; the share term (`THIN_SHARE_MIN = 0.25`, relative to
the striking metal of the set) stops a tiny fin from doing so (X03: fin ΔThinness 0.000). φ saturates at
τ ≤ L/130 (≈ 0.034 for a 4.4-stud sword), reachable since MIN_DIM = 0.02.

**Asymmetry** (left/right about the fixed plane x = 0, §3.1):

```
probes = owned volume samples of W, at least ASYM_N_MIN = 10 per local axis with |axis·X| ≥ ASYM_AXIS_X = 0.6
         (2 otherwise), spacing H_VOL coarsened within ASYM_WORK
c(s)   = clamp((ASYM_TOL + ASYM_RAMP − d)/ASYM_RAMP, 0, 1),  d = min_{q ∈ W} sd_q(−s_x, s_y, s_z),
         ASYM_TOL = 0.02, ASYM_RAMP = 0.03 (soft coverage)
Asym   = 1 − Σ w·c / Σ w
```

Offsets up to 0.02 count as symmetric, with a linear ramp to 0.05. Against a 120-probe continuous oracle the error is
≤ 0.003 over a 0–0.05 blade offset sweep (X06). A design mirrored with `Blueprint/Mirror` measures 0. Thickness (Z)
asymmetry is not measured (Phase 2).

S3's `m_design` uses only the factors of the step's own weight list (§6 Minigames): Hammering Thinness, Asymmetry,
SurfaceComplexity; Sharpening SurfaceComplexity, Asymmetry (EdgeLength acts through the trace path); Smelting Volume.

### 5.3 Weights, reference ranges and the material term

| Step | Work set | Weights (`Definitions/Steps`) | MVP |
|---|---|---|---|
| Smelting | All | Volume 1.00 | yes |
| Hammering | All | Thinness 0.40, Asymmetry 0.30, SurfaceComplexity 0.30 | yes |
| Sharpening | {Blade} | EdgeLength 0.50, Asymmetry 0.30, SurfaceComplexity 0.20 | yes |
| Quenching / Assembly / Finishing | All | Thinness .60 PartCount .40 / Joints .45 PartCount .35 MaterialMix .20 / SC 1.00 | Phase 2 hook, not computed |

Reference ranges (`EquipmentTypes.Sword.geometry.refs`, FactorId order), fitted so the iron arming sword
(C02) sits ≥ 0.05 below Hard on every step while each characteristic design keeps its Hard steps (fit: E-S2.9):

| Factor | lo | hi | Raw values (prototype) |
|---|---|---|---|
| Volume (stud³) | 0.08 | 0.80 | dagger 0.043, F5 0.101, arming 0.106, greatsword 0.193, cleaver 0.472 |
| Thinness σ | 45 | 130 | Thinness on All: F5 0.26, arming 0.28, sabre 0.35, rapier 0.59, F3 0.91 |
| Asymmetry | 0 | 0.6 | symmetric 0.000, lopsided filler 0.004, cleaver 0.27 / 0.33, sabre 0.26 / 0.67 (All / Blade) |
| SurfaceComplexity r | 2.3 | 2.9 | dagger 1.98, F5 2.20, arming 2.26, rapier 2.50, ornate 2.63, F3 blade 2.98 |
| EdgeLength (studs) | 4.8 | 8.0 | dagger 2.97, F2 4.98, F5 5.43, arming 5.64, greatsword 6.39, sabre 6.48, rapier 7.11 |
| PartCount, Joints, MaterialMix | 3 / 3 / 1 | 16 / 24 / 4 | Phase 2 factors (reported, unweighted in the MVP) |

**Material term.** `difficultyTerm` = **0 for Iron and Steel in the MVP** **[Decision to confirm]** (Q13): materials
are free, so a tier-raising material would be a difficulty slider. Steel still plays tighter minigames (S3's material
columns) and gives T = 1.02 (S4, §8.3). The m_s machinery stays for Phase 2 materials; under it, Iron and Steel give
bit-identical d (T-DIF).

### 5.4 Tier mapping

| Tier | dMin | MVP |
|---|---|---|
| Normal | 0.0 | played |
| Hard | 0.2 | played |
| Expert / Master / Hell | 0.4 / 0.6 / 0.8 | `tierRaw` only; plays as Hard (enabled-prefix clamp) |

Thresholds live in `Definitions/Tiers`; the tier boundary is exact (0.1999 Normal, 0.2000 Hard). `tierRaw` feeds the
preview text and telemetry; caps use the played tier (S4).

Worked example (F5 Starter, Hammering): Thinness 0.2593, Asymmetry 0, SC r = 2.20 → x = 0;
g = 0.40 · 0.2593 = 0.1037; m = 0; d = 0.1037 → Normal, 0.096 below Hard.

### 5.5 Calibration and fixture tiers **[Decision to confirm]** (Q7)

Target: a plain iron arming sword (S2's C02) plays Normal on all three steps with ≥ 0.05 margin; thinner or longer
blades, asymmetry and surface detail push steps to Hard; filler cannot buy a tier. d per step (Smelting / Hammering
/ Sharpening); full physics and the 8 factors per step: E-S2.9.

| Fixture | Smelting | Hammering | Sharpening | Tiers |
|---|---|---|---|---|
| F1 ArmingSword (Steel blade) = F5 StarterSword (all Iron) | 0.0288 | 0.1037 | 0.0989 | N/N/N |
| F2 MinimalSword | 0.0797 | 0.0176 | 0.0282 | N/N/N |
| F3 Rapier | 0.0000 | 0.4423 (Expert) | 0.6104 (Master) | N/H/H |
| F4 Cleaver | 0.4590 (Expert) | 0.1572 | 0.3420 | H/N/H |
| C01 Minimal 4-part | 0.1486 | 0.0000 | 0.0407 | N/N/N |
| C02 Arming, Iron or Steel | 0.0355 | 0.1137 | 0.1318 | N/N/N |
| C04 Rapier | 0.0000 | 0.3368 | 0.4703 (Expert) | N/H/H |
| C05 Cleaver | 0.5451 (Expert) | 0.1363 | 0.3466 | H/N/H |
| C06 Curved sabre | 0.0097 | 0.2991 | 0.5948 (Expert) | N/H/H |
| C07 Dagger | 0 | 0 | 0 | N/N/N |
| C08 Greatsword | 0.1563 | 0.0992 | 0.2487 | N/N/H |
| C09 Ornate, 18 parts | 0.0001 | 0.3170 | 0.1904 | N/H/N |
| C10 / C11 24-part filler, symmetric / lopsided | 0.1565 / 0.1562 | 0.0000 / 0.0012 | 0.0282 / 0.0368 | N/N/N |
| C12 / C13 / C14 Arming: 5 segments / mirrored guard / moved (0, +0.27, +0.05) | ≤ 0.0376 | ≤ 0.1137 | 0.1318 | N/N/N |
| C15 Arming rotated 4° about Z (a real change against the fixed frame) | 0.0353 | 0.2701 | 0.4291 (Expert) | N/H/H |

The iron C02 arming sword's highest step is 0.1318 (0.068 below Hard); the starter's is 0.1037 (0.096). Real edits flip
them: the arming blade 0.20 stud longer makes Sharpening Hard (0.2056); the starter's blade thinned from 0.060 to
0.045 makes Hammering Hard (0.2070) (E-S2.2).

### 5.6 Anti-gaming (measured)

| Lever | Counter | Effect |
|---|---|---|
| Hidden filler, duplicates | Enclosed (< 2 % shows) owns nothing; a verdict per part with no budget; the measure on kept parts alone | A16/A17 bit-identical; A25 ΔD 0.0000; no verdict moved on 18,000 designs of random fill or 20,000 with hidden copies inside a part (E-S2.11); what a part that really covers another can still do: §17.2 |
| Fillers behind a hairline, pins over a core, fullers and combs | a flat patch is measured on lines, with no credit for a point (§4.4) | \|ΔD\| 0.0000 on each of §17.2's designs; Blocks and Wedges 0 wrong of 651,985 parts, 0 tier flips (E-S2.11) |
| Ids, the order of the parts, flush plates inside a blade, exact copies | the rank (§4.4): the larger part keeps a shared face, owns an overlap within its slot, spends a budget first | any order of a design's parts: the same exposure, to the bit; 4 flush plates in F5 / C02 / C05 \|ΔD\| 0.0000 (0.4834 / 0.5756 / 0.7159 by id); what ids still reach: §17.2 |
| Specks, studs | Dust (< 0.0002 stud³); slot maxima; share term | C10/C11 = C01 + 20 filler parts (16 studs, 2 hidden, 2 dust): D rises by at most 0.008 on any step (Smelting 0.1486 → 0.1565), all Normal |
| Near-duplicate copies | burial + δ = 0.012 probe + the verdict's lines + the measure | X01/X02 vs the union-equivalent blade ΔD ≤ 0.0010 |
| Thin fin on a chunky sword | thin share of the striking metal | X03 ΔThinness 0.000 |
| Strips, seams, gaps, grip nudges | dilated raster, main chain | X04 EdgeLength change 0.00 % |
| Segment gaps 0.002–0.009, overlaps 0.005–0.05, laminates | probe δ, boundary sub-grid, exact clipping | X05/X07 ΔG ≤ 0.0007, mass error ≤ 0.014 % |
| Grip decoration, hidden cores, hilt offsets | fixed plane x = 0 and fixed +Y frame | A25 0.0000, A26 0.0011, A27 (Sharpening) 0.0000 |
| Serrated / comb edges | only the main chain counts and is traced; DP at 1 cell; cap 8.0 | comb blade: 11 chains, EdgeLength 1.678 = the traced run (other runs 4.6 ignored) |
| Y/Z translation, flush re-segmentation | local sampling, Y-anchored raster | Δx_f ≤ 0.0017 and ΔG ≤ 0.0007 / Δx_f ≤ 0.00001 (E-S2.10) |
| CPU attacks | work budgets, checkpoints (§4.9) | worst found 54.6 ms Lune (≈ 142 Studio), P1 31.7 (≈ 82): §4.9, §17.2 |

Telemetry: every analysis returns raw and normalized factors per step; S5's `StepScored` carries `g, m, d, tierRaw`
and the terms with the BALANCE_VERSION, so the ranges can be re-fitted from real drafts.

---

## 6. Minigames

> **Inputs, not results.** The server replays the client's input timeline with the same pure code, seed and
> parameters. The client's score is a preview; nothing the client claims is trusted.

### 6.1 Principles and step flow

Three families, one pure module each: Smelting → `HoldZone`, Hammering → `TimingStrike`, Sharpening →
`PrecisionTrace` (`Definitions/Steps`, S1). Material, tier and design change numbers only (§6.5). The same module runs
live on the client and in the server's replay; patterns come from a server u32 seed, bit-identical on both sides.

```
S5: spec, pattern = Minigames.prepare(Pipeline.stepInput(report, i, seed)) ─ StepOpenView ─► S6: Minigames.start(spec)
S5 keeps (spec, pattern); a re-open returns the same spec        countdown → GO → Minigames/Input → live session
S5: wall-clock rules → Minigames.judge(...) → verdict ◄─ Craft.Submit {sessionId, stepIndex, timeline, clientScore}
```

### 6.2 Modules and API

Pure, `src/shared/Minigames/`: `Minigames` (facade; with `Input.new` and `Params.explain`, the only API S5 and S6
call), `Types`, `Rng`, `Params`, `Timeline`, `Checks` (sample SD, windows), `Input` (§6.6), the three families, `Bots`
(§6.12; tests, tuning, Studio autoplay). Data: `Definitions/MinigameFamilies`. Ids from `Definitions/Types`;
`FactorValue`, `EdgeChain`, `Vec2` (S2).

```lua
--!strict  -- Minigames/Types (owner S3)
export type FlagId = "HzInhumanRate" | "TsLowVariance" | "TsExactHits" | "PtTooPrecise" | "PtTooSmooth"
	| "PtTeleport" | "PtSparse"
export type InvalidReason = "NotBuffer" | "Short" | "Version" | "Family" | "TooMany" | "Length" | "Duration"
	| "NotIncreasing" | "PastEnd" | "BadKind" | "NotAlternating" | "OutOfPanel" | "BadFlags" | "HashMismatch"
export type PrepareInput = { family: FamilyId, seed: number, material: MaterialId, tier: TierId,
	factors: { FactorValue },  -- all 8 factors on this step's work set, FactorId order (S2)
	edge: { chains: { EdgeChain }, gripPoint: Vec3, gripAxis: Vec2 }?, balanceVersion: number }  -- edge: Sharpening
export type StepSpec = { family: FamilyId, seed: number, params: { [string]: number }, source: { number }?,
	durationMs: number, countdownMs: number, patternHash: number, balanceVersion: number }
export type MinigameResult = { status: "Ok" | "Invalid", score: number, rawScore: number, passed: boolean,
	flags: { FlagId }, invalidReason: InvalidReason?, breakdown: { [string]: number }, elapsedMs: number }
export type FeedbackEvent = { kind: string, t: number, i: number?, value: number?, label: string? }
export type HoldRecord = { t: number, down: boolean }  -- TimingStrike record = press time t
export type TraceRecord = { t: number, u: number, v: number, grind: boolean }  -- u, v in 1/16384 panel units
export type FamilyModule<P, R, S, V> = { id: FamilyId, generate: (number, { [string]: number }, { number }?) -> P,
	hash: (P) -> number, newSession: (P) -> S, push: (S, R) -> { FeedbackEvent },
	advance: (S, nowMs: number) -> { FeedbackEvent }, view: (S, nowMs: number) -> V,
	finish: (S) -> MinigameResult, checks: (P, { R }, MinigameResult) -> { FlagId } }

Minigames.prepare(input: PrepareInput): (StepSpec, any)     -- server: params, source, pattern, hash
Minigames.start(spec: StepSpec): (any?, "Desync"?)          -- client: pattern, or nil when hash ≠ patternHash
Minigames.judge(spec: StepSpec, pattern: any, timeline: unknown, elapsedMs: number): MinigameResult -- §10.5
Minigames.replay(spec: StepSpec, pattern: any, records: { any }): MinigameResult  -- push all, finish, checks, clamp
Minigames.encode(spec: StepSpec, records: { any }): buffer
Minigames.get(family: FamilyId): FamilyModule<any, any, any, any>
Params.resolve(family: FamilyId, material: MaterialId, tier: TierId, factors: { FactorValue }): { [string]: number }
Params.explain(family: FamilyId, material: MaterialId, tier: TierId, factors: { FactorValue })
	: { [string]: { base: number, mMaterial: number, mTier: number, mDesign: number, final: number } }  -- §12.2 Intro
Timeline.decode(b: unknown, family: FamilyId, durationMs: number): ({ any }?, number | InvalidReason)
PrecisionTrace.sidesFromChains(chains: { EdgeChain }, gripPoint: Vec3, gripAxis: Vec2): { { Vec2 } }
PrecisionTrace.edgeToPanel(sides: { { Vec2 } }, gripPoint: Vec3, gripAxis: Vec2, pacerSpeed: number): { number }?
Input.new(spec: StepSpec, timingOffsetMs: number, goClockS: number): Recorder   -- clockS below is on goClockS's clock
	-- (os.clock() in S6's InputCapture; seconds with GO = 0 in Bots and autoplay). :go(held, u?, v?, grind?) records the
	-- state at GO (t = 0); :button(down, clockS, frameDtS), :cursor(u, v, grind, clockS), :release(), :records();
	-- the only producer of records (S6 InputCapture, Bots, autoplay)
```

`elapsedMs` is S5's E, copied into the result for telemetry only. `judge` emits nothing; S5 logs `StepScored`.

### 6.3 PRNG (`Minigames/Rng`)

xoshiro128\*\* 1.1 (four u32 words, period 2^128 − 1) with `bit32` ops and integer `+ * %` below 2^53; u32 products
via `mul32(a, b) = ((a >> 16)·b % 65536·65536 + (a & 0xFFFF)·b) % 2^32`. `Rng.new(seed, tag)`: `x = seed ⊕
FNV1a32(tag)` (basis `0x811C9DC5`, prime `0x01000193`, `nil` ≡ `""`), then SplitMix32 per word: `x = (x + 0x9E3779B9)
% 2^32`, `s_i = fmix32(x)` (constants `0x85EBCA6B`, `0xC2B2AE35`). Tags (renaming one bumps BALANCE_VERSION):
`HoldZone.Target`, `TimingStrike.Tempo`, `TimingStrike.Offsets`, `PrecisionTrace.Perturb`. API `nextU32`, `nextFloat`
(u32 / 2^32), `range`, `int` (inclusive), `chance`, `sign`; exports `mul32`, `fnv1a32`, `fmix32`. Pattern hashes:
FNV-1a over u32 little-endian words. Vectors: E-S3.1.

### 6.4 Determinism rules (all of `Minigames/` except `Bots`)

1. Integer ms from GO; ticks are multiples of `HZ_TICK_MS` / `PT_EVAL_MS`. 2. Only `+ − × ÷`, `sqrt`,
`floor/ceil/round`, `abs`, `min/max/clamp`; no `sin cos exp log` and no `^` (powers by repeated multiplication). 3.
Randomness only from `Rng`; no `math.random`, `Random`, `os.clock`. 4. Sums are plain left-to-right IEEE-754 additions
over arrays in index order (no compensated or pairwise sums, never `pairs`). 5. Inputs are quantized at the boundary;
the live session gets exactly the records sent; the client uses `params` verbatim. 6. No `--!native`; scores use
`Util/Quantize.q(x, 1e4)` and `passed` is computed on it. 7. SD = sample SD (n − 1); trace normals are left normals
`(−Δv, Δu)/|Δ|`. Live = replay because the client advances HoldZone only to its latest record time, TimingStrike
closes a span only once `now > T_i + M`, and PrecisionTrace evaluates only ticks up to its latest sample
(0 mismatches, E-S3.6).

### 6.5 Parameters: `p_final = round_q(clamp(p_base · m_material · m_tier · m_design, min, max))`

`m_design = clamp(1 + Σ k_{p,f}·clamp(x_f, 0, 1), lo, hi)` over the param's design array, `x_f` from
`PrepareInput.factors` (missing = 0). `m_material`: lookup by the governing material (missing = 1). `m_tier`: columns
Normal, Hard, then Expert…Hell placeholders (not enabled; values E-S3.3). `round_q(v) = q·math.round(v/q)`: q = 1 for
counts and TimingStrike ms, 10 ms for HoldZone and TimingStrike durations, 20 ms for Trace durations. Design factor
sets (§5.2): **Smelting** Volume; **Hammering** Thinness, Asymmetry, SurfaceComplexity; **Sharpening**
SurfaceComplexity, Asymmetry, EdgeLength through the path length. Design moves widths and speeds ≤ 15 % (zone −10 %)
and shape knobs ≤ +50 %; extra difficulty inside a tier is paid by S4's multiplier (Q11) **[Decision to confirm]**.
**Pass line** `passThreshold = 0.50` everywhere **[Decision to confirm]** (Q8). Example: Hammering's `windowMs` (the
half-window in which a strike scores) for Iron at Hard with Thinness x = 0.30: 110 × 1 (Iron) × 0.94 (Hard) ×
clamp(1 − 0.15·0.30, 0.85, 1) = 98.7 → 99 ms.

```lua
export type DesignTerm = { factor: FactorId, k: number }   -- Definitions/MinigameFamilies (ordered arrays)
export type MinigameParamDef = { name: string, base: number, material: { [MaterialId]: number }?,
	tier: { number }?, design: { DesignTerm }?, designClamp: { number }?, quantum: number?, min: number?, max: number? }
export type MinigameFamilyDef = { id: FamilyId, name: string, order: number, enabled: boolean,  -- Catalog.build
	params: { MinigameParamDef },
	checks: { { name: string, value: number } },                       -- thresholds (§10.6)
	flagLevels: { { flag: string, level: "High" | "Medium" } } }       -- FlagId values (§6.2); read by the judge's
	                                                                   -- clamp (§10.5), fromCraft's order (§9.4), S8
```

### 6.6 Step timing and input capture (`Minigames/Input`; S6's InputCapture feeds it)

| Rule | Behaviour |
|---|---|
| Clock | `goClock` = StepOpenView receipt + `countdownMs` (`COUNTDOWN_MS` 3000, `Definitions/Network`). The pattern shows during the countdown, inputs are ignored; a press held at GO records `{t = 0, down}` (one stroke), the trace records its cursor at GO. |
| Button time | `t = max(0, floor((os.clock() − goClock)·1000 − frameDtMs/2))` (latest RenderStepped delta). TimingStrike then subtracts `timingOffsetMs` (−120…+120, default 0, S1 settings), floored at 0. |
| Trace samples | One record at the first frame at or after each due time 0, 20, 40 … ms, `t = floor((os.clock() − goClock)·1000)`, with that frame's grind state; grind changes make no records. |
| End | `task.delay` to `goClock + durationMs`: finish, encode, submit; records past `durationMs` dropped. |
| Bindings | Space OR LMB (logical OR) for strokes, strikes and grinding; S6 offers a grind toggle. |
| gameProcessed | Filters InputBegan only; an InputEnded for an accepted press is always recorded. Cursor: S6's `TraceCanvas.toPanel` each frame (§12 minigame UI; S6's mapping wins), then `round(·16384)`. |
| Focus, menu | `WindowFocusReleased` and `GuiService.MenuOpened` release the OR-state (up record if down) and reset key state; a held key counts after a new InputBegan. Each frame, a press with neither `IsKeyDown(Space)` nor `IsMouseButtonPressed(MouseButton1)` records its release. No pause **[Decision to confirm]** (Q16). |
| Caps | HoldZone records OR-state changes only, no new press at `MAX_RECORDS − 1`; TimingStrike drops presses past the cap; Trace makes ≤ `durationMs/20 + 1` = 1,551. **An unmodified client never sends a timeline decode rejects.** |
| Abandon, desync | Abandon is session-level only (§7 Session rules); Esc never forfeits a step. `start` → `nil, "Desync"`: re-open `Craft.StartStep` (same seed); if it persists, `Craft.ReportDesync` → abort `Internal`, no strike. Never a new seed. |

### 6.7 Timeline wire format (`Minigames/Timeline`)

Little-endian `buffer`: header 12 B (`u8 version 1`, `u8 family 1/2/3`, `u16 count`, `u32 durationMs`, `u32
patternHash`), then records starting with `u16 dtMs` (from the previous record, t_0 = 0): HoldZone 3 B (`u8 kind`,
1 = down), TimingStrike 2 B, PrecisionTrace 7 B (`u16 uQ, u16 vQ, u8 flags`, bit0 grind). `MAX_RECORDS` 1024 / 512 /
2048 → 3,084 / 1,036 / 14,348 B; `MAX_TIMELINE_BYTES = 14,348` (S5 Guard). Honest sizes 0.2–0.4 KB / 34–48 B /
2.3–4.2 KB. Decode order, first failure wins: `NotBuffer`, `Short` (< 12 B), `Version`, `Family`, `TooMany`, `Length`
(≠ 12 + n·size), `Duration` (≠ pattern's); per record `NotIncreasing` (Trace dt = 0 after the first), `PastEnd`,
`BadKind`, `NotAlternating` (kinds alternate from down), `OutOfPanel` (uQ > 49152, vQ > 16384), `BadFlags`. Then
`judge` checks `HashMismatch`.

### 6.8 HoldZone (Smelting): pump the bellows, keep the ore in the zone

Gauge `T ∈ [0, 1]` (shown as 300–1600 °C, §12.6). **Each press of Space or LMB is one bellows stroke**
**[Decision to confirm]** (Q15; an earlier hold-to-heat control let tappers beat holders by 0.14–0.32, E-S3.7);
holding adds nothing, and a stroke right after another is smaller (the bellows refills). Fire `F` dies down between
strokes; `T` relaxes toward `fullHeat·F`; a zone drifts on a seeded path; the first `rampMs` are unscored. Steady
tapping holds a temperature (2.5/s → 0.70); faster than one stroke per `refillMs` gains nothing (E-S3.7). The hint
reads "Tap to pump"; holding alone scores 0.

```
zone: rng = Rng.new(seed, "HoldZone.Target"); c0 = lo + (hi − lo)·rng:range(0.3, 0.7); keys (0, c0), (rampMs, c0)
  until t ≥ durationMs: seg = rng:int(segMinMs, segMaxMs); unless rng:chance(holdChance): mag = driftSpeed·seg/1000·
  rng:range(0.5, 1), s = rng:sign(), nc = c + s·mag (reflected to c − s·mag outside [lo, hi], then clamped);
  t += seg; key (t, nc).  center(t): smoothstep between keys.  hash over (t_j, round(c_j·10^6)).  lo, hi = targetMin, Max
sim (HZ_TICK_MS 10, T = F = 0, last = −refillMs), tick k, t = 10k:
  each new down record with e.t ≤ t: F += strokeGain·min(1, (e.t − last)/refillMs)·(1 − F); last = e.t   (ups ignored)
  F −= F·10/fireDecayMs;  T = clamp(T + heatDecay·(fullHeat·F − T)·0.010, 0, 1)
  if t + 10 > rampMs: d = |T − center(t + 10)|, credit += d ≤ h ? 1 : max(0, 1 − (d − h)/(softFrac·zoneWidth))
score = q(credit / scored ticks), h = zoneWidth/2;  breakdown inZone, strokes
```

| Param | Base | Steel | Hard | Design (k, clamp) |
|---|---|---|---|---|
| `zoneWidth` | 0.090 | ×0.98 | ×0.96 | Volume −0.10 [0.9, 1] |
| `driftSpeed` (/s) | 0.21 | ×1.01 | ×1.05 | Volume +0.15 [1, 1.15] |
| `heatDecay` (/s) | 1.0 | – | ×1.05 | – |
| `fullHeat` / `strokeGain` | 2.4 / 0.25 | – | – | – |
| `refillMs` / `fireDecayMs` | 250 / 600 | – | – | – |
| `targetMin` / `targetMax` | 0.40 / 0.80 | ×1.08 / ×1.04 | – | – |
| `segMinMs` / `segMaxMs` | 900 / 2200 | – | ×0.9 | – |
| `holdChance` | 0.25 | – | ×0.8 | – |
| `durationMs` / `rampMs` | 15000 / 3000 | – | – | Volume +0.20 [1, 1.2] on duration |
| `softFrac` | 0.5 | – | – | – |

View `{t, phase, temperature, fire, zoneCenter, zoneHalf, softBand, inZone, runningScore, timeLeftMs}`; feedback `Go`,
`Stroke(value)`, `RampEnd`, `EnterZone`, `LeaveZone`, `End`.

### 6.9 TimingStrike (Hammering): strike on the beat

A marker sweeps the dial over each cycle of `P_i` ms; the player strikes as it crosses the cycle's window (the next
window shows as a ghost). 12 strikes at Normal, 15 at Hard.

```
rT, rO = Rng.new(seed, "TimingStrike.Tempo"), Rng.new(seed, "TimingStrike.Offsets"); S = 0;  for i = 1 … N:
  P_i = round(beatMs·(1 + tempoJitter·(2·rT:nextFloat() − 1)));  T_i = S + round((offsetMin + (offsetMax −
  offsetMin)·rO:nextFloat())·P_i);  S += P_i
M = min(windowMs + missPadMs, floor((minGap − 1)/2), T_1);  W = min(windowMs, M);  durationMs = S + tailMs
minGap = min over i = 1 … N − 1 of (T_{i+1} − T_i)
core = min(W, max(perfectFrac·W, TS_PERFECT_CORE_MIN_MS = 10));  hash over (S_i, P_i, T_i)
per press t: spans with T_i + M < t close as Miss; |t − T_i| ≤ M and unjudged → err_i = t − T_i (first press
  decides), else a whiff (no effect).  points = Miss or |e| > W → 0; |e| ≤ core → 1; else 1 − (1 − edgePoints)·(|e| −
  core)/(W − core).  score = q(Σ points / N);  breakdown judged (spans with a press within ±M), perfect, good, ok,
  miss (spans closed with no judged press; a judged 0-point press counts in judged only), whiffs, bestCombo,
  meanAbsErrMs, meanErrMs (signed)
```

Grades from points (E-S3.4): Perfect ≥ 0.9, Good ≥ 0.6, Ok > 0 (Iron x = 0: Normal W 110, core 13.2, Perfect ≤ 25 ms, Good ≤
61 ms; Hard W 103, core 10, Perfect ≤ 20 ms, Good ≤ 51 ms). Holding a key does not repeat. After ≥ 8 judged strikes
the results card shows "On average N ms late/early" and offers **[Use −N ms offset]** (`timingOffsetMs +=
round(meanErrMs)`, clamped ±120); Settings has the same slider (S6). A `CycleStart` tick keeps the rhythm audible.

| Param | Base | Steel | Hard | Design (k, clamp) |
|---|---|---|---|---|
| `strikes` [8, 32] | 12 | – | ×1.25 | – |
| `beatMs` (≥ 450) | 900 | ×0.98 | ×0.85 | SurfaceComplexity −0.10 [0.9, 1] |
| `windowMs` half (≥ 20) | 110 | ×0.98 | ×0.94 | Thinness −0.15 [0.85, 1] |
| `perfectFrac` / `edgePoints` | 0.12 / 0.20 | – | ×0.80 / ×0.50 | – |
| `tempoJitter` ±×P (≤ 0.30) | 0.08 | – | ×1.5 | Asymmetry +0.5 [1, 1.5] |
| `offsetMin` / `offsetMax` (×P) | 0.40 / 0.75 | – | – | – |
| `missPadMs` / `tailMs` | 90 / 400 | – | – | – |

View `{t, cycle, cycles, marker, windowCenter, windowHalf, perfectHalf, goodHalf, next?, lastGrade?, lastErrorMs?,
combo, runningScore, timeLeftMs}` (sweep units); feedback `CycleStart`, `Strike(grade, errMs)`, `Miss`, `Whiff`, `End`.

### 6.10 PrecisionTrace (Sharpening): grind the blade's own edge

**Edge hand-off.** `sidesFromChains` takes S2's main chain `chains[1]` (EdgeLength measures that same chain, §4 Edge),
splits it at its point farthest along the grip axis `A` (first maximum) and returns side A = points 1…k and side B =
points n…k, each base → tip (a side under 2 points is dropped: one side for a single edge). `edgeToPanel` maps `A ++ reverse(B)` into the 3:1 panel
(height 1; usable u 0.15–2.85, v 0.12–0.88) in the grip frame `N = (A_y, −A_x)`, **+N down** like S6's canvas and
S7's `VIEW_H`:

```
a = (p − g)·A, c = (p − g)·N;  Lb = range(a);  s = 2.7/max(4.5, Lb);  E = min(2, 0.76/(s·range(c))) (2 if flat)
u = (3 − Lb·s)/2 + (a − min a)·s;  v = 0.5 + (c − mid c)·s·E;  drop consecutive duplicates
panel length > PT_LEN_MARGIN·30 s·pacerSpeed (0.95·30 s·pacerSpeed) → E ×= 0.9 per step down to 1; then while > 256 points or
too long: Douglas–Peucker, tol 0.004 doubled after each attempt, at most 8 attempts, else no source.  source = {round(u·16384), round(v·16384), …}
no source, < 2 points or < 0.4 u → PT_FALLBACK_EDGE: sides (±0.22, 0) → (±0.22, 2.6) → (0, 3.4) studs, usedFallback = 1
```

A main chain up to 10 studs long (S2's EdgeLength range is 4.8–8.0) always plays whole (E-S3.5). Fallback edge
**[Decision to confirm]** (Q15; alternative: S4 skips Sharpening).

```
generate: load → Chaikin ×3 (0.75a + 0.25b, 0.25a + 0.75b; ends kept) → resample DS = 0.01 → left normals of
  p_{i+1} − p_{i−1};  rng = Rng.new(seed, "PrecisionTrace.Perturb"), K = max(1, round(L·bumpDensity)); bump k: centre
  (k − 1 + rng:range(0.2, 0.8))·L/K, width bumpWidth·rng:range(0.7, 1.3), amp perturbAmp·rng:range(0.5, 1)·rng:sign()
  o_i = Σ amp·(1 − x²)² (|x| < 1, x = (arc_i − centre)/width), |o_i| ≤ 0.35·clearance_i (nearest point with |Δarc| >
  0.30, searched on a 0.30-u grid within |o_i|/0.35: same clamp as a full scan, O(n)), × min(1, arc/0.15, (L − arc)/
  0.15); p + o·normal clamped to [0.05, 2.95] × [0.05, 0.95] → resample DS → quantize 1/16384 → arc, L
  travelMs = clamp(ceil(L/pacerSpeed·50)·20, 6000, 30000); speed = L/(travelMs/1000); durationMs = leadInMs +
  travelMs + tailMs; hash over (uQ_i, vQ_i)
pacer s*(t) = clamp((t − leadInMs)·speed/1000, 0, L).  cursor(t): last sample a ≤ t, next b: t = a.t → a; no b → a,
  grinding while t − a.t ≤ 250; b.t − a.t > 250 → a, not grinding; else lerp, grinding = a.grind; none before sample 1
ticks t_k = leadInMs + 20k, k = 1 … travelMs/20 (tick 1's speed uses c(t_1 − 20)):
  nearest vertex j, indices [floor((s* − 0.5)/DS), ceil((s* + 0.5)/DS) + 2] clamped to 1…n (first minimum), then
  exact d, s_c on segments (j−1, j), (j, j+1) inside that range;  w = halfWidth, core = coreFrac·w
  acc = grinding ? (d ≤ core ? 1 : max(0, 1 − (d − core)/(w − core))) : 0;  pace = grinding ∧ d ≤ w ? (|s_c − s*|
  ≤ paceTol ? 1 : max(0, 1 − (|s_c − s*| − paceTol)/paceFall)) : 0;  bin min(floor(s_c/0.02) + 1, nBins) covered if
  grinding ∧ d ≤ w ∧ |Δc|/0.02 s ≤ max(6·speed, 1.5) (no cursor at the previous tick → no coverage)
score = q(C·(wAccuracy·A + (1 − wAccuracy)·P)), A, P tick means, C = covered/ceil(L/0.02)
```

| Param | Base | Steel | Hard | Design (k, clamp) |
|---|---|---|---|---|
| `halfWidth` u (≥ 0.012) | 0.041 | ×0.98 | ×0.95 | SurfaceComplexity −0.10 [0.9, 1] |
| `pacerSpeed` (u/s) | 0.30 | ×1.01 | ×1.05 | Asymmetry +0.15 [1, 1.15] |
| `paceTol` / `paceFall` | 0.12 / 0.24 | – | ×0.85 | – |
| `perturbAmp` (u) | 0.020 | – | ×1.25 | SurfaceComplexity +0.5 [1, 1.5] |
| `bumpDensity` / `bumpWidth` | 1.0 / 0.25 | – | ×1.3 / ×0.9 | – |
| `coreFrac` / `wAccuracy` | 0.10 / 0.70 | – | – | – |
| `leadInMs` / `tailMs` | 600 / 400 | – | – | – |

Costs: §10.5; the reference arming edge travels 11.2 s at Iron/Normal (12.2 s step; the F5 starter 10.8 s / 11.8 s).
View
`{t, pacerU, pacerV, pacerArc, cursorArc?, distance?, onPath, grinding, accuracySoFar, coverage, paceLag?, timeLeftMs}` + the
static path; feedback `GrindStart/Stop`, `OnPath/OffPath`, `PaceWarn(sign)`, `Coverage(25…100)`, `End`.

### 6.11 Feedback contract

Views come from `advance(now)` each RenderStepped (≤ 1 frame + 10 ms latency); FeedbackEvents drive audio and VFX
only; every state is shown by shape or position and by colour; the server's result replaces the provisional score
with no "mismatch" state.

### 6.12 Player models (`Minigames/Bots`; S8 uses them verbatim, S4 uses their distributions)

Every human profile: frames at `fps` ±1 ms with a random phase against GO and 30–120 ms hitches; inputs reach the game
at the next frame and are stamped by §6.6; the player sees the game `lag = 8 ms + 1 frame` late (24.7 ms at 60 fps,
41.3 at 30); `timingOffsetMs = 0` unless stated; panel 520 px, integer mouse pixels.

| Parameter | Elite | Good | Average | Poor | Meaning |
|---|---|---|---|---|---|
| fps / hitch per frame | 60 / 0.3 % | 60 / 0.3 % | 60 / 0.3 % | 30 / 0.6 % | device |
| TS σ (ms) | 12 | 25 | 45 | 90 | × (1 + 0.2·max(0, 1000/P − 1))(1 + tempoJitter) |
| TS bias per run (ms) | N(3, 5) | N(5, 10) | N(10, 15) | N(25, 20) | on top of `lag` |
| TS lapse / extra press | 0.5 % / 0 | 2 % / 2 % | 5 % / 2 % | 10 % / 4 % | lapse: no press or ±300 ms; extra +80–150 ms |
| HZ perception delay (ms) | 160 | 210 | 300 | 380 | + `lag`; 100 ms velocity window |
| HZ needle noise σ | 0.004 | 0.008 | 0.020 | 0.035 | gauge units |
| HZ prediction / zone lead (s) | 0.30 / 0.5 | 0.22 / 0.3 | 0.08 / 0 | 0 / 0 | look-ahead beyond the delay |
| HZ tap period / press (ms) | 130±20 / 65±8 | 140±25 / 70±10 | 180±40 / 90±10 | 220±50 / 110±15 | tap if predicted T < target |
| HZ lapses | 0 | 1 %/s · 400 ms | 4 %/s · 700 ms | 8 %/s · 900 ms | no decisions |
| PT hand lag τ (ms) | 70 | 100 | 160 | 200 | first-order chase |
| PT cross-track σ (u) / τ (s) | 0.006 / 0.30 | 0.012 / 0.35 | 0.025 / 0.40 | 0.038 / 0.45 | OU, × √(speed/0.3) |
| PT along-track μ / σ (u) / τ (s) | −0.02 / 0.02 / 1.0 | −0.04 / 0.04 / 1.0 | −0.07 / 0.08 / 1.2 | −0.09 / 0.11 / 1.4 | OU lag behind the pacer |
| PT tremor σ (u) / lifts | 0.0012 / 0 | 0.0015 / 0.3 %/s | 0.002 / 1.5 %/s | 0.003 / 2.5 %/s | lifts 150–400 ms |
| PT start σ (u) / late grind | 0.005 / 0 | 0.01 / 150 ms | 0.03 / 350 ms | 0.05 / 500 ms | 30 % of runs |

HoldZone uses the tap policy (hold-and-release scores 0 under strokes). Test-only extremes: **Perfect** (TimingStrike:
exact intent, no lag, 60 or 30 fps; HoldZone: strokes chosen by a 300 ms look-ahead on the exact state, flagged
`HzInhumanRate`; PrecisionTrace: on the pacer every 20 ms, flagged) and **Idle** (no input). Bots may use libm
(lines tagged `-- allow-transcendental: <reason>`, §14.4).

### 6.13 Calibration results and score distributions

Steel's columns are tighter in every family (above); Average and Poor score lower on Steel everywhere (Average Normal
−0.016 / −0.012 / −0.009), but at HoldZone the Elite scores slightly higher on Steel (+0.012 Normal, +0.005 Hard; Good
+0.001 Normal), where Steel's zone sits higher on the gauge **[Decision to confirm]** (Q13). 2,000 runs per cell,
design factors at the tier's reference `x` (Normal 0.10, Hard 0.30), S3's reference arming edge (`Blades.arming`: S2's
draft arming chain, 6 points, 5.604 studs; the final F1/F5 and C02 chains move means by ≤ 0.003 and Average fail rates
by ≤ 2 points, still inside Q8, E-S3.2); mean score · fail %. Targets (Q8): Average fails 3–15 % Normal, 15–40 % Hard;
Good ≤ 5 % / ≤ 15 %; Average mean drops ≥ 0.05 from Normal to Hard. All met (E-S3.2; tuning log E-S3.9).

| Family / tier | Elite Iron · Steel | Good Iron · Steel | Average Iron · Steel | Poor Iron · Steel |
|---|---|---|---|---|
| HoldZone Normal | 0.86·0 · 0.87·0 | 0.80·0 · 0.80·0 | 0.61·5.3 · 0.60·9.0 | 0.48·58 · 0.47·66 |
| HoldZone Hard | 0.82·0 · 0.83·0 | 0.75·0 · 0.74·0 | 0.55·24.9 · 0.54·32.3 | 0.42·86 · 0.41·90 |
| TimingStrike Normal | 0.86·0 · 0.86·0 | 0.79·0.1 · 0.78·0.2 | 0.65·9.3 · 0.64·11.7 | 0.39·82 · 0.38·84 |
| TimingStrike Hard | 0.81·0 · 0.81·0 | 0.72·1.6 · 0.71·1.8 | 0.56·28.9 · 0.55·31.7 | 0.31·97 · 0.31·97 |
| PrecisionTrace Normal | 0.96·0 · 0.95·0 | 0.87·0 · 0.87·0 | 0.63·7.0 · 0.62·7.8 | 0.41·81 · 0.39·84 |
| PrecisionTrace Hard | 0.95·0 · 0.95·0 | 0.85·0 · 0.84·0 | 0.56·25.0 · 0.55·30.2 | 0.33·95 · 0.32·96 |

Perfect (raw): HoldZone 0.966–0.987, TimingStrike 1.000 (≥ 0.986 at 30 fps, every run ≥ 0.965), PrecisionTrace
1.000; Idle 0. Normal → Hard drops: Average 0.06–0.09, Good 0.03–0.07, Elite 0.01–0.06. Uncalibrated Average at 30 fps
fails Hard HoldZone 40–47 % and TimingStrike 53–54 % (12–13 % with its offset); a maximal design (every factor 1) costs
Good 0.03–0.07 (largest: HoldZone Steel Normal, 0.800 → 0.734) and lifts Average's Hard fails to 49–62 % (E-S3.2).

`S3-score-distributions.luau` (shipped next to this SPEC; generator `docs/spec/prototypes/S3/v2/dist.luau`): for every
family × tier × material × profile, 2,000 quantized per-run scores and `passThreshold = 0.5`. S4 tunes rarity on it.

### 6.14 Result handed to crafting

S5 maps `MinigameResult` into S1's `StepRecord` (`score`, `passed`, `flags`; `timedOut` and `durationMs` are S5's).
`breakdown` feeds the results card and is not persisted (HoldZone `inZone, strokes`; TimingStrike
`judged, perfect, good, ok, miss, whiffs, bestCombo, meanAbsErrMs, meanErrMs`; PrecisionTrace
`accuracy, pacing, coverage, usedFallback`). Timelines are never stored; scores are kept as earned.

---

## 7. Crafting pipeline

### 7.1 Step plan (CraftPlans)

`Definitions/CraftPlans` (S4) is the only source of which steps a type plays, in which order, on which parts, with
which weight and feeding which stats: per `EquipmentTypeId` an ordered, **append-only** list of
`{step, weight, worksOn = "All" | {SlotId}, feeds = {StatId}, enabled}` (family from `Definitions/Steps`).

| # | Step | Family | `worksOn` | `feeds` (UI) | `weight` |
|---|---|---|---|---|---:|
| 1 | `Smelting` | `HoldZone` | `"All"` | Purity | 0.25 |
| 2 | `Hammering` | `TimingStrike` | `"All"` | Damage, Durability | 0.40 |
| 3 | `Sharpening` | `PrecisionTrace` | `{"Blade"}` | Sharpness, Damage | 0.35 |

- Weights **[Decision to confirm]** (Q12); equal thirds keep every target in its band (E-S4.6).
- `Plan.validateDefs` (injected into `Validate.validateAll`, §2.3): enabled weights sum to 1 ± `WEIGHT_SUM_TOL`
  (1e-9); steps, slots and `feeds` exist. Rows are never deleted or reordered: a retired row keeps its weight with
  `enabled = false`, so every recorded step can still be weighted on recompute (§7.5).
- Order is fixed; the player never picks a tier or skips a step; each step plays once.
- **Phase 2 hook:** Quenching (`{"Blade","Guard"}`), Assembly and Finishing (`"All"`) are appended and the enabled
  weights rebalanced; another type is one more entry (a hammer has no Sharpening).

### 7.2 Work sets and the governing material

- **Kept part**: kept by S2's cleaning (§4 Exposure and cleaning). Cleaned parts are in no work set and give no
  material share (T, H, K in §8), so hidden cores and specks buy nothing.
- **Work set** `W_s = Blueprint/WorkSet.select(parts, kept, worksOn)`: matched kept parts, ascending index. Physics
  and Crafting call this one module, so difficulty and rewards use the same parts and Physics never requires Crafting.
- Validity implies a kept Blade part (S2's V5); `Plan.build` asserts every work set non-empty (S8 T-CR-01).
- **Governing material** `mat_s`: the kept `W_s` material with the highest `(difficultyTerm, hardness)`, ties by
  Materials `order`; S2 outputs it (`StepAnalysis.material`), `Plan.build` copies it. It drives `m_s` (0 in the
  MVP) and S3's `m_material`: Steel governs every step whose work set holds a kept Steel part.
- **Mixed materials [Decision to confirm]** (Q14): each step plays once at `mat_s`; T, H and K are
  kept-volume-weighted, so a small steel pommel tightens two steps and adds almost nothing.
- **Phase 2 hook:** one round per material group, a volume-blended round, or a metal-only selector.

### 7.3 Session rules

S5 owns the protocol and every clock (§7.6–7.9); these are the rules it enforces.

| # | Rule |
|---|---|
| R1 | **Open.** Begin re-validates and runs `Pipeline.analyze` on the server's copy; plan, snapshot and `BALANCE_VERSION` are frozen in the session. Later edits never touch it. |
| R2 | **One live session per player**, in memory only, never resumed after a disconnect. |
| R3 | **In order.** Step k opens only after step k−1 is recorded; its seed is drawn at its first StartStep. |
| R4 | **Once, final.** No retry or redo; a re-open returns the same seed and spec, never a new seed. |
| R5 | **A fail continues.** Failed or timed-out steps never end the craft; after the last step an item is always made. |
| R6 | **Retry = new session**: new seeds, plan rebuilt from the current blueprint, under S5's rate limit. |
| R7 | **Materials commit at open**: a no-op while materials are free. **Phase 4 hook:** the debit happens at R1, atomically, with no refund on abandon. |
| R8 | **Atomic completion**: `Pipeline.outcome` → `Items/Create.fromCraft` → profile write in one server step without a yield (§7.9); Begin is refused when there is no room for an item. |

### 7.4 Failure, timeout and abandon effects

| Event (S3 decides pass; §7.6–7.8, §10.5) | Step | Craft |
|---|---|---|
| Failed: `score < passThreshold` (0.50, S3) | `s_eff = s·φ`, φ = `failScoreFactor` 0.75, in stats and Q; counts as `FAILED_STEP_CAP_TIER` (Normal) for the cap | continues |
| No submission by the deadline | `score 0, passed false, timedOut true` → `s_eff = 0` | continues |
| HIGH inhuman-input flag | score capped at the pass line by S3, `min(rawScore, 0.50)`; it passes or fails as the raw score did (the flag never fails a step) | continues |
| Invalid timeline, hash mismatch, early submit, wrong session or step | — | aborted `InvalidInput`, Hard strike, no item |
| Desync that a same-seed re-open does not fix | — | aborted `Internal`, no strike, no item |
| Abandon, disconnect, idle or session timeout, character loss, shutdown | — | discarded, nothing written |

- **[Decision to confirm]** (Q9): φ = 0.75, no cap lift, nothing destroyed on Normal or Hard
  (`failOutcome = "LowerQuality"`). A Hard fail costs more through its larger multiplier and the lost Epic cap.
  φ = 0.5 or 1.0 only moves Common shares (E-S4.6). Abandon is session-level; there is no step forfeit.
- **Phase 2 hook:** Hell's `failOutcome = "DestroyMaterial"`. Material loss needs the Phase 4 material economy, so
  Phase 2 brings a minimal inventory or destroys the item instead (§17).

### 7.5 Crafting history semantics

S1's `StepRecord` list (§9 Item record), one per played step in plan order, holds the **frozen facts**: step,
family, played tier (after the clamp), `difficulty` (S2's 1e-4 D_s, stored as produced), `material` (`mat_s`), seed,
score (1e-4, after any HIGH clamp), passed, timedOut, durationMs, flags; plus `atForge`. Timelines, weights,
multipliers and breakdowns are not stored. Scores are final; a rebalance only changes how they become an outcome.

Recompute (`Items/Recompute.item`, S1): `Pipeline.analyze(snapshot)` → `Plan.fromHistory` → `Outcome.compute` →
`Create.fromCraft`. `Plan.fromHistory` gives each recorded step its **current** CraftPlans row (enabled or not) and
renormalizes over the recorded steps, `w'_i = w_i / Σ_recorded w`; recorded tier, D and material are kept;
multipliers, γ, caps, φ, T, thresholds and stat constants are current; physics comes from the re-analysis. A recorded
step without a row is an error: `Recompute.item` returns nil and the item keeps its values. The rarity floor is
S1's `max(recomputed, atForge.rarity)`, from `atForge` only **[Decision to confirm]** (Q19). A 3-step record under a
synthetic 6-step plan keeps its Q (T-CR-10, E-S4.5).

**Phase 3 hook:** the history card and its categories ("Master craft" = Q, "Hell forged" = Hell steps passed) read
these facts; nothing new is stored.

### 7.6 Craft session state machine

S4 owns what a craft is (§7.1–7.5); S5 owns how it is played. `Session/SessionMachine` is pure (clock, seeds, pings,
spec and `Minigames.judge` injected); `CraftService` (RB) adds remotes, the AnalysisQueue, timers and persistence.

- **One live session per player** (`Ready`/`Playing`), looked up by player, never by id; in memory only, so a
  disconnect or server hop discards the craft **[Decision to confirm]** (Q16).
- `sessionId` = `HttpService:GenerateGUID(false)` upper-cased, and it is the `ItemId`. Begin deep-copies the stored
  blueprint and re-runs `Pipeline.analyze`; the plan is frozen; seeds are drawn per step. A terminal session answers
  duplicates for `TOMBSTONE_MS` 60 000 or until the next Begin.

| From | Event | Guard | To | Effect |
|---|---|---|---|---|
| — | Begin | §7.7 checks | Ready(1) | `{session}`, telemetry CraftStarted |
| Ready(i) | StartStep(i) | `canOpen` = nil | opening | seed drawn, prepare job queued (a 2nd StartStep waits in the Craft lane, §10.3, then gets the re-open reply; `E_BUSY` only from a full lane or the machine's own guard) |
| opening | job done | `canOpen` still nil | Playing(i) | `t_open`, first ping; `PlotWorld.setActivity(plot, step, parts)` |
| Playing(i) | StartStep(i) | — | Playing(i) | same spec, `countdownMs` = remaining |
| Playing(i) | Submit(i) | on time or late (§7.8) | Ready(i+1) / Finalizing | judged run recorded |
| Ready(i) / Playing(i) | Submit | `E < D − EARLY_TOL_MS` (Playing); a foreign `sessionId`; a `stepIndex` neither open nor recorded | Aborted(InvalidInput) | `E_TOO_EARLY` / `E_SESSION_MISMATCH` / `E_WRONG_STATE`, Hard strike |
| Playing(i) | Submit(i) | judge `status = "Invalid"` | Aborted(InvalidInput) | `E_INVALID_INPUT`, Hard strike |
| Playing(i) | Submit late / sweep | `now > t_dead` | Ready(i+1) / Finalizing | score 0, `timedOut`; push StepTimedOut (sweep) |
| Playing(i) | ReportDesync(i) | — | Aborted(Internal) | no strike, telemetry Desync; never a new seed |
| Ready(i) | sweep | idle / lifetime, not opening | Aborted(Idle / SessionTimeout) | push Aborted |
| Finalizing | commit | `mutate` ok / refused | Completed / Aborted(DataUnavailable) | §7.9 |

Any live state also aborts on Abandon, leave, character loss, profile session end and shutdown. `AbortReason = "Abandoned" | "Left" | "Idle" | "SessionTimeout" | "ServerClosing" | "InvalidInput" |
"DataUnavailable" | "CharacterLost" | "Internal"`. CharacterLost = `Humanoid.Died` or `CharacterRemoving` while live;
Internal = a judge throw (logged with seed and timeline hash) or a desync. Every step end and every abort calls
`setActivity(plot, nil)`; an abort also pushes `Craft.Aborted` if the player is present and logs CraftAborted; S4
§7.4 gives its effect (no item).

```lua
--!strict
-- src/shared/Session/SessionMachine.luau (pure); error results are Protocol.ErrorCode strings
export type Timing = { countdownMs: number, earlyTolMs: number, lateSoftMs: number, lateHardMs: number,
	rttAllowMaxMs: number, readyIdleMs: number, sessionMaxMs: number, maxPingSamples: number }
export type StepRun = CT.StepRun & { rawScore: number, elapsedMs: number,
	breakdown: { [string]: number }? }                          -- S4 StepRun (flags included) + server-only fields
export type SubmitResult = { run: StepRun, duplicate: boolean, next: "Ready" | "Finalize", violation: "Soft"? }
export type Event = { kind: "StepTimedOut", stepIndex: number, run: StepRun, next: "Ready" | "Finalize" }
	| { kind: "Aborted", reason: Protocol.AbortReason }
new(id: string, userId: number, blueprintId: string, plan: { CT.PlannedStep }, nowMs: number, t: Timing): Session
canOpen(s, index, nowMs): string?        -- nil = may open | "Reopen" | ErrorCode;  beginOpen(s), cancelOpen(s)
open(s, index, nowMs, seed: number, spec: MT.StepSpec, pattern: any, pingMs: number)    -- → Playing(i)
openView(s, index, nowMs): Protocol.StepOpenView?;   ping(s, pingMs)                   -- sweep RTT sample
submit(s, judge, index, recvMs, timeline: buffer, clientScore: number): (string?, SubmitResult?)
desync(s, index): string?;  tick(s, nowMs): { Event };  complete(s): boolean;  abort(s, reason): boolean
view(s, nowMs): Protocol.SessionView
```
Prototype: 50/50 scenario checks (Evidence: E-S5.2).

### 7.7 Craft protocol: requests, replies, pushes

Channel `Craft`; buckets and Guard specs in §10 Request catalogue; types in `Net/Protocol`. No strike unless marked
Hard. Every action naming a session may also return `E_NO_SESSION`, `E_SESSION_MISMATCH` or `E_WRONG_STATE` (no
strike, except that a `Submit` naming a wrong session or step while a session is live aborts the craft with a Hard
strike, §7.6).

| Action | Args → reply `data` | Errors |
|---|---|---|
| `Begin` | `{blueprintId, revision?}` → `{session: SessionView}` | `E_SESSION_ACTIVE` (+ `data.session`), `E_NOT_FOUND`, `E_WRONG_STATE` (revision moved), `E_INVALID_BLUEPRINT` (details = ValidationCodes, or `{"OutOfRange"}` for a record outside today's bounds), `E_LIMIT_REACHED`, `E_TOO_FAR`, `E_BUSY` |
| `StartStep` | `{sessionId, stepIndex}` → `{step: StepOpenView}` | `E_SESSION_EXPIRED`, `E_BUSY` |
| `Submit` | `{sessionId, stepIndex, timeline: buffer, clientScore}` → `{result: StepResultView, next: "Ready" \| "Completed", item: ItemSummary?, duplicate: boolean}` | `E_TOO_EARLY` Hard (aborted), `E_INVALID_INPUT` Hard (aborted), `E_SESSION_MISMATCH` / `E_WRONG_STATE` Hard (aborted, while a session is live), `E_DATA_UNAVAILABLE` |
| `Abandon` / `Resume` | `{sessionId}` → `{}` (also with no session) / `{}` → `{session: SessionView?}` | — |
| `ReportDesync` | `{sessionId, stepIndex, clientHash}` → `{}` | — |
| push `StepTimedOut` / `Aborted` | `{sessionId, result, next, item?}` / `{sessionId, reason}` | — |

Begin checks in order: no live session; blueprint owned (`revision` equal when sent); the record passes
`Canonical.isCanonical` (else `E_INVALID_BLUEPRINT {"OutOfRange"}`; the editor clamps the part on the next edit);
items < MAX_ITEMS and the profile under S1's storage block;
`Layout.isInsidePlot(ownPlot, root position, PLOT_INTERACT_MARGIN)`; then the job
`Pipeline.analyze(copy, {checkpoint})`, a re-check after the yield, and the record's cached `Pipeline.summary`
refreshed if its revision is unchanged.

```lua
export type StepOpenView = MT.StepSpec & { sessionId: string, stepIndex: number, stepId: DT.StepId,
	tier: DT.TierId, lateAllowanceMs: number }  -- spec: seed, params, source?, patternHash, durationMs, countdownMs
export type StepResultView = { stepIndex: number, stepId: DT.StepId, tier: DT.TierId, score: number,
	passed: boolean, timedOut: boolean, breakdown: { [string]: number }? }      -- never flags
export type StepPlanView = { stepIndex: number, stepId: DT.StepId, family: DT.FamilyId, tier: DT.TierId,
	difficulty: number, material: DT.MaterialId, result: StepResultView? }
export type SessionView = { sessionId: string, blueprintId: string, state: "Ready" | "Playing", current: number,
	steps: { StepPlanView }, step: StepOpenView?, expiresInMs: number }
```
`lateAllowanceMs` = `LATE_SOFT_MS + A` with the current A (E-S5.2): informational, a Submit later than D plus it is
flagged LateSubmit; the client does not act on it. `expiresInMs` = in Ready, `READY_IDLE_TIMEOUT_MS` minus the time
since the step became Ready, capped by `SESSION_MAX_MS` minus the session's age; in Playing, `t_dead − now` (§7.8).
§12.1's idle warning counts down from it and restarts from `READY_IDLE_TIMEOUT_MS` at each Submit reply.

StartStep's job is `Minigames.prepare(Pipeline.stepInput(report, i, seed))`; `(spec, pattern)` stay in the session.
The client's `Minigames.start(spec)` checks the pattern hash; on a mismatch it re-sends StartStep, then `ReportDesync`
if it still differs. It counts down `countdownMs`, plays D and submits on Heartbeat at GO + D (`task.delay`). Submit
runs `Minigames.judge(spec, pattern, timeline, E)` synchronously after the §7.8 checks; `clientScore ≠ rawScore` (both
quantized to 1e-4, compared exactly) adds the telemetry flag ScoreMismatch. The client's score is never used; HIGH
flags arrive already applied by S3 (score capped at the pass line, §7.4; flags stay server-side).

Idempotency: a re-open returns the same seed, spec and deadline, `countdownMs = max(0, C − (now − t_open))`; a Submit
for a recorded step returns the stored result (`duplicate = true`, no second judge; the tombstone adds `item`);
`itemId = sessionId` plus an existence check gives at most one item per session. After `E_TIMEOUT` on `Submit` the
client re-sends the same Submit once (idempotent: the stored result, and the tombstone adds `item`); after other
`E_TIMEOUT`s it resyncs with `Craft.Resume`.

### 7.8 Step timing and deadlines

S5 owns every wall-clock rule; S3's judge applies none (§10.5). Integer ms, server `os.clock()·1000`.

| Symbol | Definition |
|---|---|
| `t_open`, `t_recv` | first StartStep(i) reply fired; Router arrival stamp of Submit(i), taken before any lane or yield |
| `C` | `COUNTDOWN_MS` 3000 (`Definitions/Network`; `Minigames.prepare` copies it into `StepSpec.countdownMs`, `SessionMachine.openView` replaces it with `max(0, C − (now − t_open))` on a re-open); timeline origin = receipt + `countdownMs` |
| `D` | `StepSpec.durationMs`, fixed per pattern (no early finish) |
| `A` | `min(2·median(pings), RTT_ALLOW_MAX_MS 2000)`; pings = `GetNetworkPing()·1000` at `t_open` and every sweep while Playing, ≤ `MAX_PING_SAMPLES` 160 |
| `E` | `t_recv − t_open − C`, passed to `judge` as `elapsedMs` (informational) |

```
E < D − EARLY_TOL_MS                              too early: E_TOO_EARLY, craft aborted (InvalidInput), Hard strike
D − EARLY_TOL_MS ≤ E ≤ D + LATE_SOFT_MS + A        on time: judged
D + LATE_SOFT_MS + A < E ≤ D + LATE_HARD_MS + A    late: judged + telemetry flag LateSubmit (no score effect)
E > D + LATE_HARD_MS + A                          timed out: score 0, passed false, timedOut true; craft goes on
t_dead = t_open + C + D + LATE_HARD_MS + A        swept every TICK_INTERVAL_MS 250 (A from the current median)
EARLY_TOL_MS = 250   LATE_SOFT_MS = 1500   LATE_HARD_MS = 5000
```
Example: D = 15 000, median ping 100 ms → A = 200: judged from E = 14 750, LateSubmit beyond 16 700, timed out
beyond 20 200, swept by `t_open + 23 450`. Honest model (10⁶ samples): 0 early submits, LateSubmit ≈ 1.3 %,
timeouts ≤ 3 per 10⁶ (Evidence: E-S5.3). Seeds: `SeedRng:NextInteger(0, 4294967295)` from one server
`Random.new()`, revealed only by the StartStep reply, fixed for the step; `Config.FIXED_SEED` overrides in Studio.
Clocks: `READY_IDLE_TIMEOUT_MS` 120 000 per Ready step; `SESSION_MAX_MS` 600 000 (compliant worst case ≈ 453 s).

### 7.9 Finalize and item commit

Runs in the thread that recorded the last step (Submit handler or sweep). **No yield in steps 1–5**, so the commit
is atomic with respect to PlayerRemoving and EndSession (Luau threads are never preempted).
```
1 outcome = Pipeline.outcome(s.report, s.runs)                                              -- S2/S4, pure
2 item = Items/Create.fromCraft({ id = s.id, name = s.snapshot.name, crafterUserId = player.UserId,
         createdAt = os.time(), snapshot = s.snapshot, plan = s.report.plan, runs = s.runs, outcome = outcome,
         physics = s.report.analysis.physics, balanceVersion = BALANCE_VERSION })
3 ok = DataService.mutate(player, function(d) if d.items[item.id] == nil then d.items[item.id] = item end end)
4 not ok → abort(DataUnavailable), reply E_DATA_UNAVAILABLE, stop
5 complete(s); PlotWorld.setActivity(plot, nil); DataService.requestSave(player); watchItemSaved(player, item.id)
6 telemetry CraftCompleted (+ funnel ItemForged)
7 reply {result, next = "Completed", item = Items/Views.summary(item, 0)}, or push StepTimedOut{…, item}
```
`Items/Create.fromCraft` (step 2) deduplicates, orders and cuts each run's flags (§9.4). The item takes the
blueprint's name (raw; no rename, §3.9). After the next write containing the item the owner gets
`Profile.Notice{code = "ItemSaved", itemId}` (≤ `SAVE_MIN_INTERVAL_S` later, §9.7). Residual risk: a crash before that
write loses the item.

---

## 8. Item outcome

> **Rarity is earned by forging; stats show what was forged.** Quality Q rewards skill (scores), boldness (tier and
> design difficulty) and, slightly, the metal. Stats never feed Q or rarity.

### 8.1 Inputs

Flow: `Pipeline.analyze` → `Plan.build` (plan frozen at Begin) → one `StepRun` per step → `Pipeline.outcome` →
`Items/Create.fromCraft` (§7.9). S2 `physics`: mass `M` (kg), `reach` `R`, `balance` `b` (balance point from the guard
toward the tip, signed), main-chain `edgeLength` `L` (studs), `cutIndex` `cut` (1 = thin and long), `ownedVolume`
`V_p`, `kept`. S1: hardness, toughness (integers 0–100; Iron 45 / 50, Steel 70 / 55). S3, S2: score `s_i`,
difficulty `D_i` (1e-4), `passed_i`. `clamp(x, a, b) = min(b, max(a, x))` (NaN → a), `lerp(f, s) = f + (1 − f)·s`,
`q(x) = Util/Quantize.q(x, 1e4)`; sums in part or plan order; only `+ − × ÷ sqrt min max abs floor`.

### 8.2 Stats

```
(1)  s_eff,i = s_i if passed_i, else s_i · Tiers[tier_i].failScoreFactor                    (§7.4)
(2)  P = lerp(PURITY_FLOOR, s_eff,Smelting)                                                [0.70, 1]
(3)  H = Σ_{W_Sharpening} V_p·hardness_p / (MATERIAL_SCALE·Σ V_p);  K = same, toughness, W_Hammering;  h = H·P, k = K·P
(4)  Sharpness  = clamp(100·h·lerp(SHARP_FLOOR, s_eff,Sharpening), 0, 100)
(5)  Durability = clamp(100·k·lerp(DURA_FLOOR, s_eff,Hammering), 0, 100)
(6)  c      = clamp(cut, 0, 1) · clamp(L / EDGE_REF, 0, 1)                                  cutting profile
(7)  F_mass = clamp(MASS_BIAS + (1 − MASS_BIAS)·sqrt(M / MASS_REF), MASS_FACTOR_MIN, MASS_FACTOR_MAX)
(8)  F_edge = 1 + EDGE_GAIN·c·Sharpness/100;   F_forge = lerp(FORGE_FLOOR, s_eff,Hammering)
(9)  Damage = clamp(DAMAGE_BASE · F_mass · F_edge · F_forge, 0, 100)
(10) Reach  = max(R, 0)
(11) β = b / max(R, BALANCE_REACH_MIN);  e = max(0, |β − BALANCE_IDEAL| − BALANCE_TOLERANCE)
     Balance = 100·clamp(1 − e/BALANCE_FALLOFF, 0, 1)
(12) Purity = 100·P;  every stat stored as q(x), keyed by StatId (stats.Damage …)
```

MVP ranges: Damage 10.1–61.9, Sharpness 9.5–70, Durability 17.5–55, Purity 70–100, Balance 0–100, Reach ≤ 5.28.
`Definitions/Balance.Stats.Sword` (rows per EquipmentTypeId; rationale and sensitivity E-S4.1):

| Constant | Value |
|---|---|
| `MATERIAL_SCALE` | 100 |
| `PURITY_FLOOR` · `SHARP_FLOOR` · `DURA_FLOOR` · `FORGE_FLOOR` | 0.70 · 0.30 · 0.50 · 0.60 |
| `EDGE_REF` · `EDGE_GAIN` | 6.0 studs (F5's edge 5.433 → 0.91) · 1.0 |
| `MASS_REF` · `MASS_BIAS` · `MASS_FACTOR_MIN` · `MASS_FACTOR_MAX` | 0.80 kg (F5 0.793 kg) · 0.4 · 0.6 · 1.3 |
| `DAMAGE_BASE` | 28 (flawless F5 36, F1 41, F4 39, F3 37) |
| `BALANCE_IDEAL` · `_TOLERANCE` · `_FALLOFF` · `_REACH_MIN` | 0.08 · 0.04 · 0.30 · 1.0 stud (full marks 4–12 % of reach) |

`Definitions/Stats` (`unit`, `decimals`): Damage, Sharpness, Durability, Balance ("", 0); Purity ("%", 0); Reach
("studs", 1); SwingSpeed, Defense, Mobility reserved. Example, F5 starter, Good (0.7993 / 0.7917 / 0.8736, passed):
Damage 32.07, Sharpness 38.55, Durability 42.10, Purity 93.98, Balance 99.56, Reach 3.31 (E-S4.2).

### 8.3 Quality score Q

```
(13) T   = q( Σ_{kept p} V_p·Materials[mat_p].qualityTier / Σ_{kept p} V_p )
(14) d_i = Tiers[tier_i].qualityMultiplier · (1 + DESIGN_GAMMA·(D_i − Tiers[tier_i].dMin))
(15) Q   = q( T · Σ_i w_i·s_eff,i·d_i )
```

| Tier | dMin | d | `rarityCap` | `failScoreFactor` | `failOutcome` |
|---|---:|---:|---|---:|---|
| Normal · Hard (MVP) | 0.0 · 0.2 | 1.00 · 1.25 | Rare · Epic | 0.75 | LowerQuality |
| Expert · Master · Hell (placeholders) | 0.4 · 0.6 · 0.8 | 1.55 · 1.90 · 2.30 | Legendary · Mythic · Divine | 0.75 | LowerQuality (Hell: DestroyMaterial) |

- **T** `qualityTier` **[Decision to confirm]** (Q13, Q14): Iron 1.00, **Steel 1.02** (F1: 1.0050); the targets need
  ≤ 1.04 (at 1.10 a Good player gets Epic on 71 % of all-Hard Steel crafts, E-S4.7). Phase 2 placeholders: E-S4.1.
- **γ** `DESIGN_GAMMA` = 0.15 **[Decision to confirm]** (Q11): +0.1 of D adds ×0.015·d(tier); a Hard step at D = 1
  weighs 1.40, and Hard at its threshold (1.25) still beats Normal's top (1.03). Smallest round value for which a
  Good player's expected Q never falls as D rises; Average players lose a little, so boldness is a skill bet (E-S4.4).
- **Scale**: Q = 1.00 is a flawless all-Normal Iron sword at D = 0 (F5: 1.0125), never renormalized;
  `Quality = floor(Q·100 + 0.5)`; MVP maximum 1.02 × 1.25 × 1.12 = 1.428.
- **Preview** (`Outcome.preview`): `qualityCeiling = q(T·Σ w_i·d_i)`, `planCap`, `capStep`, each d_i, γ, and
  `potential` = stats at every step 0.5 and 1.0, passed (F5: 1.0125, Rare; F3 rapier: 1.2573, Epic via Hammering).

### 8.4 Rarity

```
(16) capTier_i = tier_i if passed_i, else FAILED_STEP_CAP_TIER ("Normal")
(17) cap = highest Tiers[capTier_i].rarityCap, base Tiers.Normal.rarityCap; capStep = first step giving it (absent at base)
(18) byScore = highest enabled rarity with Q ≥ minQuality (inclusive; Common 0)
(19) rarity = byScore if order(byScore) ≤ order(cap), else cap
```

Example: the F5 starter forged by a Good player (scores 0.7993 / 0.7917 / 0.8736, all passed, all Normal):
Q = 0.25·0.7993·1.0043 + 0.40·0.7917·1.0156 + 0.35·0.8736·1.0148 = 0.8326 → Quality 83; by score Uncommon (Rare
needs 0.84), cap Rare → Uncommon (E-S4.2).

`minQuality`: Common 0, **Uncommon 0.55, Rare 0.84, Epic 1.04**; placeholders Legendary 1.29, Mythic 1.58, Divine 1.91
(d(tier) × 1.04 / 1.25). Cap rule **[Decision to confirm]** (Q10): the hardest passed step sets the cap; Q gates single
Hard steps (Smelting-Hard-only: 0 % Epic for every human profile at the reference designs; alternatives: E-S4.8).

Targets **[Decision to confirm]** (Q12) on S3's distributions, 2,000 crafts per row (craft i = run i of each step's
cell; S8's T-CR-09 replays it). All pass; minimum margin 6.15 points (T4):

| # | Profile · plan · material | Target | Result |
|---|---|---|---:|
| T1 · T2 | Average · Good, all-Normal, Iron | Rare ≤ 15 % · Rare 30–60 % | 0 · 47.0 % |
| T3 · T4 | Good, all-Hard, Iron · Steel | Epic 5–25 % | 11.4 · 18.85 % |
| T5 · T6 | Elite, all-Hard, Iron · Steel | Epic ≥ 40 % | 92.0 · 97.1 % |
| T7 · T8 | Elite, Sharpening Hard only, Iron · Steel | Epic ≤ 60 % | 2.1 · 12.6 % |
| T9 · T10 · T11 | Average Iron · Poor Iron · Average Steel, all-Normal | Uncommon+ ≥ 50 % · Common ≥ 70 % · Rare ≤ 25 % | 88.2 · 99.4 · 0 % |
| — | all crafts | no Epic without a passed Hard step | 0 |

Rarity mix (% C/U/R/E, Iron \| Steel; D at S3's reference 0.10 / 0.30; Poor 99–100 % Common everywhere; E-S4.7):

| Plan S/H/Sh | Elite | Good | Average |
|---|---|---|---|
| N/N/N | 0/1/99/0 \| 0/0/100/0 | 0/53/47/0 \| 0/39/61/0 | 12/88/0/0 \| 14/86/0/0 |
| H/N/N | 0/0/100/0 \| 0/0/100/0 | 0/23/77/0 \| 0/17/83/0 | 11/89/0/0 \| 12/88/0/0 |
| N/N/H | 0/0/98/2 \| 0/0/87/13 | 0/7/93/0 \| 0/5/95/0 | 13/87/0/0 \| 16/84/0/0 |
| N/H/H (F3) | 0/0/38/62 \| 0/0/18/82 | 0/3/95/2 \| 0/3/92/5 | 13/86/1/0 \| 15/84/1/0 |
| H/N/H (F4) | 0/0/55/45 \| 0/0/32/68 | 0/2/98/0 \| 0/1/99/0 | 11/89/0/0 \| 14/86/0/0 |
| H/H/H | 0/0/8/92 \| 0/0/3/97 | 0/2/87/11 \| 0/2/79/19 | 13/85/2/0 \| 15/83/2/0 |

### 8.5 Luau API (pure; Crafting requires only Definitions, Util, Blueprint and Physics types)

```lua
--!strict
-- DT = Definitions/Types, BS = Blueprint/Schema, PA = Physics/Analyze
-- Definitions/CraftPlans (S4)
export type WorkSelector = "All" | { DT.SlotId }
export type PlanStepDef = { step: DT.StepId, weight: number, worksOn: WorkSelector, feeds: { DT.StatId }, enabled: boolean }
export type CraftPlanDef = { type: DT.EquipmentTypeId, steps: { PlanStepDef } }
-- Blueprint/WorkSet (S4): ascending indices of the kept parts the selector matches
WorkSet.select(parts: { BS.PartData }, kept: { boolean }, selector: WorkSelector): { number }
-- Crafting/Types (S4)
export type PlannedStep = { index: number, step: DT.StepId, family: DT.FamilyId, weight: number, tier: DT.TierId,
	tierRaw: DT.TierId, difficulty: number, material: DT.MaterialId, workParts: { number } }
export type CraftPlan = { type: DT.EquipmentTypeId, balanceVersion: number, steps: { PlannedStep } }
export type StepScore = { score: number, passed: boolean }
export type StepRun = StepScore & { seed: number, timedOut: boolean, durationMs: number, flags: { string } }
export type StepFacts = { step: DT.StepId, family: DT.FamilyId, tier: DT.TierId, difficulty: number, material: DT.MaterialId }
export type Stats = { [DT.StatId]: number }
export type StatInputs = { mass: number, reach: number, balance: number, edgeLength: number, cutIndex: number,
	hardness: number, toughness: number, smelting: number, hammering: number, sharpening: number }  -- H, K, s_eff
export type StatBreakdown = { [string]: number }  -- purity hEff kEff sharpness durability c fMass fEdge fForge damage beta balance reach
export type QualityTerm = { step: DT.StepId, weight: number, effectiveScore: number, multiplier: number, contribution: number }
export type QualityResult = { q: number, materialTier: number, terms: { QualityTerm } }
export type RarityResult = { rarity: DT.RarityId, byScore: DT.RarityId, cap: DT.RarityId, capStep: DT.StepId? }
export type Outcome = { stats: Stats, quality: QualityResult, rarity: RarityResult }
export type Preview = { materialTier: number, qualityCeiling: number, rarityCap: DT.RarityId, capStep: DT.StepId?,
	multipliers: { number }, gamma: number, potential: { low: Stats, high: Stats } }
-- core: BS.BlueprintCore, physics: PA.PhysicsReport, analysis: PA.Analysis, scores: { StepScore }, tier: DT.TierId
Plan.build(core, analysis): CraftPlan;   Plan.fromHistory(core, analysis, steps: { StepFacts }): CraftPlan;   Plan.validateDefs(): { string }
Quality.effectiveScore(score, passed, tier) (1) · .multiplier(tier, difficulty) (14) · .materialTier(core, physics) (13)
	· .compute(plan, scores, materialTier): QualityResult (15) · .ceiling(plan, materialTier): number
Rarity.fromQuality(q) (18) · .cap(plan, scores): (DT.RarityId, DT.StepId?) (16, 17) · .planCap(plan) · .resolve(q, plan, scores): RarityResult (19)
Stats.inputs(core, physics, plan, scores): StatInputs · .breakdown(type, inputs) (2–11) · .compute(type, inputs): Stats (12)
Outcome.compute(core, physics, plan, scores): Outcome · .preview(core, physics, plan): Preview
-- Pipeline.luau, S4's part: analyze sets report.plan (Plan.build) and report.preview (Outcome.preview) when valid
Pipeline.outcome(report, runs: { StepRun }): Outcome   -- Outcome.compute(report.core, report.analysis.physics, report.plan, runs)
```

- Asserts: `#scores == #plan.steps`; three MVP steps, positive kept volume per work set (`Stats.inputs`); S2's steps
  in CraftPlans order, enabled tiers (`Plan.build`). S1's `StepRecord` is a `StepFacts` and a `StepRun`.
- `Create.fromCraft` stores `stats`, `quality = quality.q`, `materialTier`, `rarity = rarity.rarity` (S1's floor on
  recompute), `rarityByScore`, `rarityCap`, `capStep`.
- Arrays in index order, Definitions via `Catalog.ordered`/`byId`, never `pairs`, no clocks or randomness.
  `Balance.Quality = {FAILED_STEP_CAP_TIER = "Normal", DESIGN_GAMMA = 0.15, WEIGHT_SUM_TOL = 1e-9}`. CraftPlans,
  `Balance.Stats`, `Balance.Quality` and S4's catalog columns are in the BALANCE Manifest (§2).

### 8.6 Tests and telemetry

S8's T-CR cases replay E-S4.2 (fixtures), E-S4.3 (golden cases), the cap grid, the target table and the 6-step plan
(prototype: 0 failures in 200,000 random crafts and 21,296 cap-grid cases, E-S4.5). S5's CraftStarted carries the
plan steps `{step, tier, tierRaw, difficulty, material}`, CraftCompleted the outcome block, for re-fitting from play.

---

## 9. Persistence

### 9.1 Store, key and session lifecycle

`DataService` (RB) is the only module that requires `Vendor.ProfileStore`; S1 owns `Profile.Data` and the load
pipeline it calls. Store `ProfileStore.New(PROFILE_STORE_NAME = "PlayerData", Template.TEMPLATE)`,
key `PROFILE_KEY_PREFIX .. userId` = `"User_<UserId>"` (both in S1's `Definitions/Limits`; Roblox's pattern for automated right to be
forgotten, with the deletion template in the build checklist, §1). Studio uses `store.Mock` (nothing persists)
unless the ServerScriptService attribute `BS_DataMode = "Live"` is set, which only S8's test experience does; live
servers always use the real store. The mode is logged once `ProfileStore.DataStoreState ~= "NotReady"`.

```
loadAsync(player)                                                  -- called by Lifecycle.join after plot assignment
1 profile = store:StartSessionAsync(key, {Cancel = isGone(player) or elapsed > LOAD_TIMEOUT_S} :: any)
  nil → "PlayerLeft" if gone; IsClosing → kick CLOSING; else kick LOAD_FAILED. Never a blank profile.
  Every kick path fires LoadFailed first, so a pending Hello gets E_DATA_UNAVAILABLE.
2 profile:AddUserId(player.UserId)
3 report, prepared = Prepare.run(profile.Data, {displaySlots = World.DISPLAY_SLOT_KEYS, now = os.time(),
    newGuid = function() return HttpService:GenerateGUID(false):upper() end})   -- works on a deep copy
4 "Newer" → EndSession (untouched), kick NEWER_SCHEMA · "Corrupt" → EndSession, DataIssue, kick DATA_ERROR
  "Ok" → profile.Data = prepared                                   -- never profile:Reconcile()
5 connect OnLastSave (keep reason), OnSave (last-write clock), OnAfterSave (ItemSaved, SaveRecovered), OnSessionEnd
6 gone meanwhile → EndSession, "PlayerLeft"
7 size = #JSONEncode(profile.Data); ProfileLoaded:Fire → Hello answered, renderAll; DataLoaded (+ funnel Joined)
```
`Prepare.run` adds the Starter Sword under `ctx.newGuid()` while `starterGranted` is false (§9.6, Q21). `isGone` = our
`leaving` flag or `player.Parent ~= Players` (PlayerRemoving fires while the player is still parented).
**OnSessionEnd** drops the profile and fires `ProfileReleased` (CraftService aborts with DataUnavailable); it kicks
with SESSION_ENDED only if the player is still here and the last-save reason was `"External"` or none fired (a
steal). It never kicks on `"Shutdown"`, while `ProfileStore.IsClosing`, or after our own release.
**Release** (Lifecycle.leave, after the craft abort and `unrenderAll`): set `leaving`, `profile:EndSession()` (final
save and lock release, retried by ProfileStore). **Shutdown**: `BindToClose` → `Router.setClosing(true)`,
`CraftService.abortAll("ServerClosing")`, Notice ServerClosing; ProfileStore's own handler saves every profile
within the 30 s engine budget; a join meanwhile gets nil and the CLOSING kick.

| Constant | Value | Why |
|---|---|---|
| `LOAD_TIMEOUT_S` | 75 | a `Cancel` disables ProfileStore's 120 s timeout; a steal takes ≈ 45 s plus back-off; the real wait is ≈ 75–95 s (checked between retries) |
| Kick texts | LOAD_FAILED "We couldn't load your smithy. Please rejoin in a minute." · SESSION_ENDED "Your smithy was opened on another server. Please rejoin." · NEWER_SCHEMA "A newer version of the game is available. Please rejoin." · DATA_ERROR "We couldn't open your smithy. Please contact support." · CLOSING "This server is restarting. Please rejoin." · FULL "This server is full. Please join another server." | S6 may restyle |

```lua
DataService.loadAsync(player): LoadResult   -- "Ok" | "PlayerLeft" | "Timeout" | "Closing" | "Newer" | "Corrupt"
DataService.release(player); isReady(player): boolean; read(player): PT.PlayerData?   -- read-only
DataService.mutate(player, fn: (d: PT.PlayerData) -> ()): boolean    -- sync iff ready; fn never yields
DataService.requestSave(player); watchItemSaved(player, itemId); refreshItem(player, itemId); sizeBytes(player)
-- signals: ProfileLoaded(player, data), LoadFailed(player, result), ProfileReleased(player),
--          ItemSaved(player, itemId), ItemRefreshed(player, itemId), SaveState(player, degraded)
```
Vendored ProfileStore (45c9847): its params type lacks `Cancel` (cast `:: any`, `profile.Data :: PT.PlayerData`);
`store.Mock` drops the params; `IsActive()` holds only until a yield, hence the no-yield `mutate` (Studio:
`Config.CHECK_MUTATE_YIELD`); Studio `OnSave` runs `JsonSafe.check`. Test hook `Lifecycle.simulateRejoinForTest`:
leave, assert `not profile:IsActive()`, clear the join guards, join, return the load result.

### 9.2 Data rules (ProfileStore / DataStore)

- **Store and key**: `ProfileStore.New(PROFILE_STORE_NAME = "PlayerData", TEMPLATE)`, key `PROFILE_KEY_PREFIX ..
  userId` = `"User_<UserId>"`: Roblox's pattern, eligible for automated right-to-be-forgotten once the deletion
  template is configured (README, S5).
- **JSON-safe only**: string-keyed records; arrays (`parts`, `steps`, `flags`, `issues`, `materials`, `tiers`, the
  Vec3 / Quat / RGB tuples) built fresh, without holes, never mixed; no Instances, functions or Definitions tables.
  NaN and ±inf encode silently, so numbers are checked finite where produced (`Canonical`, `Quantize.q`).
  `JsonSafe.check` rejects every violation, including a table shared by two records (snapshots are deep copies).
- **≤ 4,194,304 JSON characters per key**: worst case 43.5 % (§9.8).
- `Reconcile` never enters maps that are empty in the template, so a new field inside a record needs a migration;
  migrations run before reconcile (§9.6).

### 9.3 Profile.Data types and template

```lua
--!strict
-- Persistence/Types.luau (S1)
export type SnapSetting = { on: boolean, step: number }   -- stud (move, scale) or degrees (rotate)
export type Settings = {
	snap: { move: SnapSetting, rotate: SnapSetting, scale: SnapSetting },
	space: "Blueprint" | "Local", overlays: { grid: boolean, hitbox: boolean, physics: boolean },
	reducedMotion: boolean,
	timingOffsetMs: number,   -- integer −120…+120, subtracted from TimingStrike presses (§6)
	sfxVolume: number,        -- 0–1, the SFX SoundGroup volume
	grindToggle: boolean,     -- Sharpening grind: false = hold, true = toggle (§12.5)
}
export type SmithyData = { level: number,                -- 1 (Phase 2: stands grow with level)
	displays: { [string]: IS.ItemId } }                  -- ["D1".."D6" (S7)] = ItemId; empty slots absent
export type PlayerData = {
	dataVersion: number,
	blueprints: { [BS.BlueprintId]: BS.BlueprintRecord }, items: { [IS.ItemId]: IS.ItemRecord },
	smithy: SmithyData, settings: Settings,
	uiFlags: { [string]: boolean },                      -- client UI state; key names S6
	quarantine: { blueprints: { [string]: any }, items: { [string]: any } },   -- records that failed repair
	starterGranted: boolean,
}
```

- `Template.TEMPLATE`: `dataVersion = DATA_VERSION`, empty maps, `smithy = {level = 1, displays = {}}`,
  `settings = Settings.DEFAULT`, `starterGranted = false`; deep-frozen (ProfileStore copies it); 399 B.
  `Template.STARTER`: the Starter Sword blueprint core = fixture F5 (F1 ArmingSword all in Iron, Normal on every
  step); tests import this one copy.
- `Settings.DEFAULT`: the defaults of §12.9's table (fields and values S6; Move and Scale snap on at 0.05 stud,
  Rotate off) **[Decision to confirm]** (Q5).
- `Settings.sanitize(raw)` (every `Profile.SetSettings`, and Prepare) rebuilds a fresh table: unknown keys dropped;
  wrong type or non-finite → default; snap steps in (0, 16] stud and (0, 180]° (≤ 0 → default, above → maximum; any
  positive typed step is honoured); `timingOffsetMs` rounded, clamped to ±120; `sfxVolume` clamped to [0, 1]; a non-boolean `grindToggle` → false.
- `Settings.sanitizeFlags(raw)` keeps keys matching `^(TipsHidden|Onboarding|Hint)%.%w+$`, ≤ 32 bytes, value `true`,
  at most 64 (first in sorted order); the result replaces the stored map. Worst sizes: 318 B (≈ +20 B for `grindToggle`, added after the measurement) and 2,561 B.

### 9.4 Item record: frozen facts vs derived values

```lua
--!strict
-- Items/Schema.luau (S1; content from S2–S5)
export type ItemId = string                -- the craft session GUID, upper-case
export type StepView = {                   -- one played step as its owner may see it; frozen
	step: DT.StepId, family: DT.FamilyId, tier: DT.TierId,   -- tier played, after the MVP clamp
	difficulty: number,                    -- D_s, 1e-4 grid (S2)
	material: DT.MaterialId,               -- governing material (§7.2)
	score: number,                         -- server replay score, 1e-4 grid, after any HIGH-flag clamp (S3)
	passed: boolean, timedOut: boolean,    -- timedOut: no submission by the deadline (score 0)
	durationMs: number,                    -- D = StepSpec.durationMs (pattern length), also when timed out; E: telemetry
}
export type StepRecord = StepView & {      -- as stored; seed and flags never leave the server
	seed: number,                          -- u32, server-issued
	flags: { string },                     -- anti-cheat flags, ≤ MAX_STEP_FLAGS
}
export type StoredOutcome = {              -- S4 (§8); scalars on the 1e-4 grid
	stats: { [DT.StatId]: number }, quality: number, materialTier: number,   -- stats.Damage …, Q, T
	rarity: DT.RarityId,                   -- final, after the rarity floor
	rarityByScore: DT.RarityId, rarityCap: DT.RarityId, capStep: DT.StepId?,  -- capStep absent = base cap
}
export type ForgeFacts = { balanceVersion: number, quality: number, rarity: DT.RarityId }
export type ItemBase = {
	id: ItemId, name: string, type: DT.EquipmentTypeId,
	crafterUserId: number, createdAt: number,  -- UserId (exact double, never bit32); os.time() at grant
	blueprint: BS.BlueprintSnapshot, atForge: ForgeFacts,                    -- frozen (and steps)
	balanceVersion: number, physics: BS.PhysicsView, outcome: StoredOutcome, -- derived
}
export type ItemRecord = ItemBase & { steps: { StepRecord } }               -- play order
export type ItemSummary = { id: ItemId, name: string, type: DT.EquipmentTypeId, createdAt: number,
	materials: { DT.MaterialId }, quality: number, rarity: DT.RarityId, tiers: { DT.TierId },
	displaySlot: number }                  -- 1..6, 0 = not displayed
export type OwnerItemView = ItemBase & { steps: { StepView } }
```

- **Frozen**: identity, the snapshot (a migration may change its format, never its geometry), `steps` and `atForge`
  (inputs are not stored, so scores cannot be re-derived). **Derived**: `balanceVersion`, `physics`, `outcome`.
- **Construction**: `Create.fromCraft` (S5's finalize, §7.9): `steps[i]` = plan step i {step, family, tier,
  difficulty, material} + run i {seed, score, passed, timedOut, durationMs, flags}; flags deduplicated, ordered HIGH
  (S3), S5's LateSubmit and ScoreMismatch, then telemetry-only, and cut at `MAX_STEP_FLAGS`; `physics` = S2's {mass,
  balance, reach}; values copied as produced, never re-quantized.
- **Recompute** (one pure path): `Pipeline.analyze(snapshot)` → `Plan.fromHistory` (current weights renormalized
  over the recorded steps, played tiers kept; §7.5) → `Outcome.compute` on the recorded scores → `Create.fromCraft`
  with the stored facts. **Rarity floor**: `outcome.rarity = max(recomputed, atForge.rarity)` by order, from
  `atForge` only **[Decision to confirm]** (Q19); stats and Q follow the current balance.
- Stale = `balanceVersion < BALANCE_VERSION` (a newer stamp is left alone); S5 recomputes lazily through the
  AnalysisQueue when a stale item is rendered, inspected or fetched. A snapshot that no longer passes
  `Canonical.isCanonical` (checked before `Pipeline.analyze`, which asserts) or validation makes `Recompute.item`
  return nil, and the item keeps its stored values (DataIssue telemetry).
- Not persisted: minigame input timelines, filtered names, craft sessions (§7.6).

```lua
-- Items/Create, Recompute, Views (CT = Crafting/Types, PA = Physics/Analyze, IS = Items/Schema)
export type CraftFacts = { id: IS.ItemId, name: string, crafterUserId: number, createdAt: number,
	snapshot: BS.BlueprintSnapshot, plan: CT.CraftPlan,
	runs: { CT.StepRun },                  -- runs[i] belongs to plan.steps[i]; StepRun carries flags
	outcome: CT.Outcome, physics: PA.PhysicsReport, balanceVersion: number,
	atForge: IS.ForgeFacts? }              -- nil at forge; the stored block on recompute
Create.fromCraft(f: CraftFacts): IS.ItemRecord
Recompute.isStale(item: IS.ItemRecord): boolean
Recompute.item(item: IS.ItemRecord, checkpoint: (() -> ())?): IS.ItemRecord?     -- new record; input untouched
ItemViews.summary(item: IS.ItemRecord, displaySlot: number): IS.ItemSummary
ItemViews.owner(item: IS.ItemRecord): IS.OwnerItemView
```

### 9.5 Quantization of persisted numbers

A derived scalar that is stored and feeds a later computation is quantized once, where it is produced and before
any threshold, with `Util/Quantize.q(x, SCALAR_SCALE)` = `math.round(x · 1e4) / 1e4` (errors on non-finite and on
|round(x · 1e4)| ≥ 2^51, where it stops being idempotent; −0 → 0; idempotent): G_s, m_s, D_s (S2, before `tierFor`);
step scores (S3, before the pass line, `ScoreMismatch` and the outcome); T, Q and stats (S4, before the rarity
mapping). Transforms and physics stay raw doubles; seeds, `durationMs`, times and ids are integers. Persistence
and server-only code never quantize. A recompute at the same versions is therefore bit-identical.

### 9.6 Versioning, migration and the load pipeline

| `Definitions/Versions` | Bump when | Stored data |
|---|---|---|
| `DATA_VERSION` = 1 | a record field added, renamed, removed or retyped; an id format change; any schema bump | migration chain at load |
| `BLUEPRINT_SCHEMA` = 1 | blueprint format change | the same migration upgrades records and snapshots |
| `BALANCE_VERSION` = 1 | any outcome-affecting data (§2.8 Manifest) or code change | items recomputed lazily; analyses go stale |

`difficulty`, `tier`, `score` and `passed` never change after forging. `Prepare.run` is pure; S5 calls it right
after the session starts (§9.1) and sets `profile.Data = prepared` only on `Ok`. Nobody calls `profile:Reconcile()`.

```
0  data = deepCopy(stored)               -- the live profile.Data is never mutated; not a table → "Corrupt"
1  v = data.dataVersion or 1;  v > DATA_VERSION → "Newer" (an older server never rewrites newer data)
2  for k = v .. DATA_VERSION − 1: Migrations[k](data); data.dataVersion = k + 1    (an error → "Corrupt")
3  reconcile(data, TEMPLATE)             -- add missing string keys, recursive (ProfileStore semantics)
4  repair(data, ctx)                     -- unreadable records move to quarantine
5  if not starterGranted: add Template.STARTER (id ctx.newGuid(), revision 1, times ctx.now);
   starterGranted = true                 [Decision to confirm] (Q21)
6  JsonSafe.check(data) fails → "Corrupt", else "Ok"
```

- On `Newer` or `Corrupt` S5 ends the session without writing, logs DataIssue and kicks with a clear message.
  Reconciling before migrating would fill `dataVersion` from the template and skip every migration (E-S1.6).
- **Repair**: the map key wins over a record's `id`; a non-GUID key, a blueprint or snapshot that fails
  `Canonical.isCanonical(core, {bounds = false})`, or a failed item check, moves the record to `quarantine` (never
  deleted); a record that breaks only a later, tighter `MIN_DIM`, `MAX_DIM` or `POS_ABS_MAX` stays (listed in
  `repairs`); `displays` entries with an unknown slot key, a missing item or a repeated item (first slot in layout
  order wins) are dropped; `settings` and `uiFlags` are sanitized; a bad `smithy.level` → 1; a non-boolean
  `starterGranted` → true. Over-cap profiles are never truncated.

```lua
export type PrepareContext = { displaySlots: { string }, now: number, newGuid: () -> string }   -- S7 keys
export type PrepareReport = { status: "Ok" | "Newer" | "Corrupt", fromVersion: number, repairs: { string },
	quarantined: { string }, granted: boolean, error: string? }
Prepare.run(stored: any, ctx: PrepareContext): (PrepareReport, PT.PlayerData?)   -- never mutates `stored`
Migrations: { [number]: (data: any) -> () }  -- v → v+1 in place: pure, total, never deletes content; empty at launch
JsonSafe.check(v: unknown, maxDepth: number?): (boolean, string?)                -- path of the first violation
Settings.DEFAULT: PT.Settings;  Settings.sanitize(raw: unknown): PT.Settings
Settings.sanitizeFlags(raw: unknown): { [string]: boolean }
Template.TEMPLATE: PT.PlayerData;  Template.STARTER: BS.BlueprintCore
```

### 9.7 Saving, budgets and failure handling

Every successful `mutate` marks the profile dirty. An explicit `profile:Save()` runs only when dirty and at least
`SAVE_MIN_INTERVAL_S` 60 after the profile's last write of any kind (`OnSave` clock); ProfileStore's 300 s autosave
and the final EndSession save stay as they are. `Profile:Save()` moves the profile behind the autosave index
(vendored code), so the next autosave comes a full cycle later.

Per-key limit 4 MB/min (E-S5.8): steady ≤ 1 write/min, at most 2 in a minute when the autosave or the final save falls
inside it. S1's worst case 1 822 966 B gives 1.82 MB/min (46 %), 3.65 MB in a burst (91 %); at S1's
`PROFILE_SIZE_BLOCK_BYTES` 2 000 000 B, 2.0 / 4.0 MB (a throttled key queues, it does not drop). Server budget:
UpdateAsync uses read and write, 60 + 40 × 8 = 380/min; worst ≈ 8 explicit + 1.6 auto + ≈ 4 join/leave ≈ 14/min.

| Case | Behaviour |
|---|---|
| Size guard (S1 thresholds) | measured at load, tracked by deltas; ≥ WARN → DataIssue SizeWarn; ≥ BLOCK → new blueprint, Begin → `E_LIMIT_REACHED {"StorageFull"}` |
| Crafted item | committed without a yield (§7.9), save requested, `Notice{ItemSaved}` once `LastSavedData` holds it (S6's tick may lag ≤ 60 s); a crash before that write loses it |
| `OnError(msg, store, key)` | Log WARN, DataIssue; `Notice{SaveDegraded}` to that key's player only (≤ 1/min); next `OnAfterSave` → `SaveRecovered` |
| `OnCriticalToggle` · `OnOverwrite` | Log ERROR/INFO and DataIssue only (no broadcast) · Log ERROR |
| Write after the session ended | `mutate` → false → `E_DATA_UNAVAILABLE` |
| Stale item (`Recompute.isStale`: `balanceVersion < BALANCE_VERSION`) | served as stored; S7 calls `refreshItem` when it is rendered, inspected or fetched → AnalysisQueue P2 job `Items/Recompute.item` (deduped, ≤ `RECOMPUTE_QUEUE_CAP` 64, ≤ 6 per plot claim) → replace if unchanged → `ItemRefreshed` → `ShowcaseService.refresh` + `Notice{ItemUpdated}`; a nil result is remembered per (itemId, `BALANCE_VERSION`) for the server's lifetime, so that item is not queued again (one DataIssue per item and server) |

### 9.8 Size budgets and caps

Measured on the final shapes (encoder checked against Studio's `JSONEncode`; worst case = GUIDs, 64-byte names,
25-character numbers, full lists, 64 uiFlags; E-S1.4): a part costs 335 B worst (113–184 B typical), a blueprint
record 735 B + 336 B per part (8,799 B at 24; 736 B with no parts), an MVP item record 1,668 B + 336 B per part
(9,732 B at 24), so `W(B, I, P) = 3,606 + B·(775 + 336·P) + I·(1,708 + 336·P)` bytes for P ≥ 1, wrapper and map keys
included. At the caps **40 blueprints / 150 items** **[Decision to confirm]** (Q18) and P = 24: **1,822,966 B =
43.5 %** of the 4,194,304 limit (Phase 2+ item shape 49.5 %; 60 / 250 would be 71.0 %; E-S1.4). Second target:
≤ 2,000,000 B, so two writes a minute (one explicit save per `SAVE_MIN_INTERVAL_S` 60 plus the 300-s autosave, §9.7)
stay under the 4 MB/min per-key limit (2 × 1.82 MB = 3.65 MB/min). At the item cap `Craft.Begin` is refused until an
item is scrapped, so a finalize never fails; the blueprint cap counts new ids only.

**Size guard** (S5 implements; thresholds E-S1.9): `#JSONEncode(profile.Data)` after Prepare, then `+ new − old` per record write.
≥ `PROFILE_SIZE_WARN_BYTES` 1,000,000 → DataIssue; ≥ `PROFILE_SIZE_BLOCK_BYTES` 2,000,000 → refuse new blueprints and
items (`E_LIMIT_REACHED`); unreachable under the MVP caps. **Phase 2 hook:** the Phase 2+ item shape reaches 2.08 MB,
above the block: before its steps ship, deduplicate snapshots by `sourceId@sourceRevision` or page items into their
own keys, and re-run S8's budget test.

### 9.9 Invariants

After `Prepare` and any `Recompute` (S8's T-PER and T-ITM):

| # | Invariant |
|---|---|
| I1 | `blueprints[k].id == k`, `items[k].id == k`; every key is an upper-case GUID |
| I2 | records and snapshots pass `Canonical.isCanonical(core, {bounds = false})` (§9.6), current `schema`, ≤ `MAX_PARTS` parts with unique ascending ids |
| I3 | `displays` keys are current slot keys; values are existing items, each at most once |
| I4 | numbers finite; D, scores, T, Q, stats on the 1e-4 grid; transforms and physics raw doubles |
| I5 | no table shared between records, no cycles |
| I6 | `item.balanceVersion ≤ BALANCE_VERSION`, except a newer stamp met by an older server during an update, which is left untouched (not stale, not quarantined); equal after `Recompute.item` |
| I7 | rarity order ≥ `atForge.rarity`; inflating then deflating versions give max(last result, `atForge.rarity`) |
| I8 | the whole `Data` passes `JsonSafe.check` |
| I9 | at current versions `Recompute.item` reproduces the derived fields bit for bit |
| I10 | creation refused at the caps and the size block; nothing truncated; quarantine never deleted |
| I11 | `Canonical` idempotent bit for bit on 10⁵ drafts and every S6 command output; ‖q‖² within 1e-9; Save → load bit-identical |
| I12 | `settings == Settings.sanitize(settings)`; `uiFlags` pass `sanitizeFlags`; starter granted at most once |
| I13 | no client payload carries step flags or seeds (`OwnerItemView`, `InspectView`) |

---

## 10. Networking and anti-cheat

### 10.1 Transport, channels and envelope

> **Principle.** The client sends intents and raw inputs; the server recomputes every outcome. One registry, one
> Guard, one rate limiter and one error vocabulary cover every remote.

Four reliable `RemoteEvent`s (`Profile`, `Blueprint`, `Craft`, `Showcase`; `Remotes.model.json`) carry an action
string and a request id (Combat System §11.4). No RemoteFunction (ordering; client-side timeouts) and no
UnreliableRemoteEvent (nothing continuous crosses the wire). Every message ≤ `REPLY_PAGE_BYTES` 32 768 (JSON
length): the snapshot and batched reads are paged; the largest request is a Submit, ≤ 14 348 B (sizes: E-S5.7).
```
client → server   remote:FireServer(action: string, rid: number, args: {[string]: any})    rid 1..2^31−1 per client
server → client   remote:FireClient(player, kind, rid, body)   reply: kind = action, same rid, body = Response<T>
                                                               push:  rid = 0, kind = push name
export type Response<T> = { ok: true, data: T } | { ok: false, code: ErrorCode, details: { string }?, data: any? }
```
`Net/Client.request(channel, action, args?, timeoutS?) → Response` yields; `E_TIMEOUT` after `REQUEST_TIMEOUT_S` 20
(> a full AnalysisQueue, §1); `onPush(channel, kind, fn) → disconnect`; it assembles snapshot pages before Hello returns.
`Profile.Hello` passes `timeoutS` = `HELLO_TIMEOUT_S` 120, above the worst profile load (`LOAD_TIMEOUT_S` 75 plus a
retry interval, ≈ 75–95 s, §9.1), so a slow load ends in the snapshot or in `E_DATA_UNAVAILABLE`, never in
`E_TIMEOUT`.

### 10.2 Request catalogue

Bucket = capacity, refill/s, per player and action. **M** = mutating: serialized per (player, channel), refused
while closing. Craft rows: types, errors and rules in §7.7.

| Channel.Action | Args → reply `data` | Checks beyond Guard | Bucket | M | Profile |
|---|---|---|---|---|---|
| `Profile.Hello` | `{}` → `ProfileSnapshot` | answered once loaded (client timeout `HELLO_TIMEOUT_S`, §10.1) | 2, 1/30 | | waits |
| `Profile.Sync` | `{}` → `ProfileSnapshot` | — | 3, 1/10 | | yes |
| `Profile.SetSettings` | `{settings, uiFlags?}` → `{settings, uiFlags}` | `Settings.sanitize` (S1); uiFlags merged into the stored map (`false` deletes), then `Settings.sanitizeFlags` (≤ 64 keys), whose result replaces it | 5, 1/2 | M | yes |
| `Blueprint.Get` | `{blueprintIds}` (1–12) → `{blueprints, rest}` | own ids; packed ≤ 32 KB, the rest listed | 10, 2 | | yes |
| `Blueprint.Save` | `{blueprintId, draft}` → `{summary, valid, errors, analysis?}` | `Canonical.draft`; a new id needs < MAX_BLUEPRINTS and no storage block; `Pipeline.quick`, then the AnalysisQueue if it passes (a quick failure stores `Pipeline.summaryOf(validation)`); invalid work in progress is stored with `valid = false` **[Decision to confirm]** (Q6) | 4, 1/3 | M | yes |
| `Blueprint.Rename` · `Delete` | `{blueprintId, name}` → `{summary}` · `{blueprintId}` → `{}` | own; `Names.sanitize` · own | 5, 1/2 | M | yes |
| `Craft.Begin` · `StartStep` · `Submit` | §7.7 | §7.6–7.8 | 3, 1/10 · 5, 1/2 · 5, 1/2 | M | yes |
| `Craft.Abandon` · `Resume` · `ReportDesync` | §7.7 | §7.7 | 3, 1/5 · 3, 1/5 · 3, 1/10 | | yes |
| `Showcase.Place` · `Clear` | `{slotIndex, itemId}` · `{slotIndex}` → `{displays}` | no live craft (`E_SESSION_ACTIVE`); `isInsidePlot` (`E_TOO_FAR`); S7 `place` · `clear` | 6, 1 | M | yes |
| `Showcase.Scrap` | `{itemId}` → `{displays}` | S7 `scrap` (clears its stand, deletes the item; Q18) | 5, 1/2 | M | yes |
| `Showcase.Inspect` | `{plotIndex, slotIndex}` → `{view: InspectView}` | S7 `inspect` | 10, 3 | | yes |
| `Showcase.GetItems` | `{itemIds}` (1–12) → `{items: {OwnerItemView}, rest}` | own; S7 `getItem`; packed ≤ 32 KB | 10, 2 | | yes |
| `Showcase.TeleportHome` | `{}` → `{}` | no live craft; character present; `PlotWorld.teleportHome` | 1, 1/3 | | no |
| *global* | | | 30, 15 | | |

Pushes: `Profile.Notice {code: "ItemSaved" | "ItemUpdated" | "SaveDegraded" | "SaveRecovered" | "ServerClosing",
itemId?}`, `Profile.SnapshotPage {page, of, blueprints?, items?}`, `Craft.StepTimedOut`, `Craft.Aborted`. Guard
bounds come from their owners: `slotIndex` `G.int(1, DISPLAY_SLOTS)`, `plotIndex` `G.int(1, PLOT_COUNT)` (S7
`Definitions/World`), id lists `G.arr(G.guid(), MAX_BATCH_IDS)`.

```lua
export type ProfileSnapshot = { userId: number, plotIndex: number, dataVersion: number, balanceVersion: number,
	limits: { maxBlueprints: number, maxItems: number, displaySlots: number, maxNameChars: number },
	blueprints: { BlueprintSummary }, items: { ItemSummary }, pages: number,   -- page 1 of `pages`
	displays: { string }, settings: PT.Settings, uiFlags: { [string]: boolean }, session: SessionView? }
```
`Net/Protocol` defines the wire types and re-exports S1's `BlueprintRecord`, `BlueprintSummary`, `ItemSummary`,
`OwnerItemView` and S7's `InspectView`; `displays` = `ShowcaseRules.fromStore`. Owners get their records without
anti-cheat flags; others only `InspectView`.

### 10.3 Validation (Guard) and error codes

```
OnServerEvent(player, action, rid, args)          recvMs = now (first line)
1 global bucket → silent drop (flood count)      2 registered action string ≤ 32 B, else drop + strike BadAction
3 rid integer 1..2^31−1, else drop + strike BadRid                4 action bucket → E_RATE_LIMITED
5 needsProfile, not loaded → E_NOT_READY; mutating while closing → E_SERVER_CLOSING
6 Guard.check → E_BAD_REQUEST + Hard strike      7 M: per (player, channel) FIFO, ≤ LANE_CAP 4 waiting, else E_BUSY
8 xpcall(handler): throw → E_INTERNAL + ERROR log "<userId>-<rid>"; FireClient(reply)
```
Steps 1–7 are one pure decision helper in `Net/` (injected clock and buckets; its name is S5's, §17.2), so T-NET-04
tests the order without remotes. `Net/Guard` (pure, never throws, fuzzed): `int(min, max)`, `num(min, max)`
(finite), `bool()`, `str(maxBytes, maxChars)` (UTF-8, no control chars), `guid()` (`Canonical.guid`, §3.11), `enum(list)`, `opt(v)`, `arr(v, maxLen)` (dense), `rec(fields)`
(unknown keys rejected), `plain(maxDepth)` (nil, boolean, finite number, string ≤ 256 B, tables with string or
integer keys), **`buffer(maxBytes)`** (`typeof(v) == "buffer"`, `buffer.len(v) ≤ maxBytes`, O(1)). Checks spend a
node budget (`MAX_PAYLOAD_NODES` 6000; SetSettings `MAX_SETTINGS_NODES` 256) and return `"path: reason"` with
unknown keys printed as `<key>`. Cost ≈ 2 µs per check, 117 µs for a 24-part Save (Evidence: E-S5.1). Guarded ids
are then upper-cased.
```lua
export type HandlerSpec = { args: Guard.Validator, nodes: number?, limit: RateLimit.BucketSpec, mutating: boolean,
	needsProfile: boolean, handler: (player: Player, args: any, recvMs: number) -> Response<any> }
-- Craft.Submit args: G.rec({ sessionId = G.guid(), stepIndex = G.int(1, MAX_STEPS),
--                            timeline = G.buffer(MAX_TIMELINE_BYTES), clientScore = G.num(0, 1) })
-- Blueprint.Save: G.rec({ blueprintId = G.guid(), draft = G.plain(MAX_DRAFT_DEPTH) })
-- Profile.SetSettings: G.rec({ settings = G.plain(3), uiFlags = G.opt(G.plain(1)) }), nodes = MAX_SETTINGS_NODES
```
`MAX_TIMELINE_BYTES` = S3's header + largest family cap (12 + 2048 · 7 = 14 348), derived from
`Definitions/MinigameFamilies`. Submit also checks the step family's own cap `12 + MAX_RECORDS · RECORD_BYTES`
before judging; over it is an S3 Invalid (`TooMany`).

| `ErrorCode` | Meaning → client | Strike |
|---|---|---|
| `E_BAD_REQUEST` | Guard failure → report a bug | Hard |
| `E_RATE_LIMITED` · `E_NOT_READY` · `E_SERVER_CLOSING` | bucket empty → wait · profile not loaded → wait · shutdown → banner | — |
| `E_BUSY` | queue full, open in flight, lane full → retry ≥ 1 s | — |
| `E_NOT_FOUND` | not in own profile, empty stand → resync | — |
| `E_LIMIT_REACHED` | MAX_BLUEPRINTS, MAX_ITEMS, storage block (`details = {"StorageFull"}`) → delete or scrap | — |
| `E_INVALID_BLUEPRINT` | canonical or name failure, invalid at Begin → show `details` | — |
| `E_SESSION_ACTIVE` | live craft (Begin adds `data.session`) → resume or finish | — |
| `E_NO_SESSION` · `E_SESSION_EXPIRED` | session races, lifetime over → resync | — |
| `E_SESSION_MISMATCH` · `E_WRONG_STATE` | stale ids, moved revision → resync | Hard for a `Submit` while a session is live (craft aborted, §7.6), else — |
| `E_TOO_EARLY` · `E_INVALID_INPUT` | `E < D − EARLY_TOL_MS` · invalid timeline, craft aborted | Hard |
| `E_SLOT_INVALID` · `E_TOO_FAR` | bad or locked slot · outside own plot → walk home | — |
| `E_DATA_UNAVAILABLE` · `E_INTERNAL` · `E_TIMEOUT` | profile inactive → rejoin · exception → one retry if idempotent · client-only, no reply → resync | — |

| Module code (owner) | Where | Wire result |
|---|---|---|
| `CanonError` (S1) · `NameError` (S1) | Save · Rename | `E_INVALID_BLUEPRINT`, `details = {code, path}` · `{"BadName", code}` |
| `ValidationCode` `{code, partId, slot}` (S2) | Save · Begin | ok, `valid = false`, `errors` stored · `E_INVALID_BLUEPRINT`, `details` = codes |
| `InvalidReason`, `HashMismatch` (S3) | Submit | `E_INVALID_INPUT`, abort InvalidInput, Hard strike |
| `ShowcaseCode` (S7) | Showcase.* | Ok, NoChange → ok · BadSlot, SlotLocked → `E_SLOT_INVALID` · BadItem, NotOwned, Empty → `E_NOT_FOUND` · NotLoaded → `E_NOT_READY` |
| AnalysisQueue · DataService | Save, Begin, StartStep · writes | full → `E_BUSY`, throw → `E_INTERNAL` · refused → `E_DATA_UNAVAILABLE` |

**Strikes:** only Guard failures, BadAction, BadRid and the Invalid Submit outcomes (S3 Invalid,
`E_TOO_EARLY`, a wrong session or step, §7.6) strike, and an unmodified client produces none (S6 pre-runs `Names.sanitize` and `Canonical.draft`; S3/S6 cap input; submit at GO + D).

### 10.4 Rate limits and kicks

`Net/RateLimit` (pure, injected clock): `tokens = min(capacity, tokens + Δt·refill)`, one token per request, per
(player, action) (§10.2) plus the global bucket (≈ 10× honest peak). The client self-throttles at `capacity − 1`,
`refill × 0.9`. Replies to rate-limited requests: ≤ `RATE_LIMITED_REPLIES_PER_S` 5 per player, the rest silent.
Flood kick: > `FLOOD_KICK_DROPS_PER_MIN` 300 global drops in 60 s → `Kick("Disconnected: too many requests.")`.
Strike kick: ≥ `HARD_STRIKES_KICK` 10 Hard strikes per server session → `Kick("Disconnected: unexpected client
behaviour.")`, disabled by `Config.STRIKE_KICK = false` under the test bridge. No persistent bans (Phase 2 hook).
`RateLimited` telemetry at most once per (player, action) per minute. A 500 req/s flood passes ≤ 15.5 req/s; every
legit trace passes in full (Evidence: E-S5.5).

### 10.5 Minigame replay and verdicts

S5 runs its wall-clock rules first (§10 Timing checks: E, early submit, LateSubmit, timeout), then calls the pure
`Minigames.judge(spec, pattern, timeline, elapsedMs)` with the `(spec, pattern)` it kept from `prepare`:

```
1 decode   records, hash = Timeline.decode(timeline, spec.family, spec.durationMs)   → Invalid(reason)   (§6.7)
2 hash     hash ≠ spec.patternHash                                                   → Invalid("HashMismatch")
3 replay   newSession(pattern), push every record, finish → rawScore   (the client's own code path)
4 checks   flags = Family.checks(pattern, records, result), sorted by id   (§10.6)
5 clamp    any HIGH flag → score = min(rawScore, passThreshold), else score = rawScore   (server only)
6 result   passed = status == "Ok" and score ≥ passThreshold;  Invalid → score = rawScore = 0, passed = false, flags = {}
```

| `MinigameResult` | S5 verdict (§7.4) |
|---|---|
| `Invalid` (any decode reason or `HashMismatch`) | craft aborted, reason `InvalidInput`, Hard strike, no item |
| `Ok` with a HIGH flag | score clamped, the step passes if the clamped score does, the flag is stored server-side only |
| `Ok` with telemetry flags | recorded only |

S5 also owns: early submit (`E < D − EARLY_TOL_MS`) → Invalid abort; no submission by the deadline → score 0,
`timedOut`, craft continues; `LateSubmit` → telemetry flag. **ScoreMismatch** ⇔ `clientScore ≠ rawScore` (exact
equality of two `Quantize.q` values); the clamp never causes one. Owners receive their items without flags.
Guarantees: the same pure code, seed and params on both sides (0 mismatches in E-S3.6), and an unmodified client
never produces an Invalid timeline (§6.6 caps), so Invalid only ever hits a modified client.

Server cost of one step (Lune ms; Studio ≈ ×2.6, §4.9), worst honest cases (E-S3.5):

| Family | `prepare` (generate) | `judge` (decode + replay + checks) |
|---|---|---|
| HoldZone | 0.04 | 0.35 (1,000 records, 18 s) |
| TimingStrike | 0.03 | 0.04 |
| PrecisionTrace | ≤ 1.9 on every reference blade, 2.5 at the length bound | ≤ 2.6 (29.6 s, 1,479 records; decode 0.12) |

`judge` runs synchronously in the Submit handler and `prepare` as one P0 burst of S5's AnalysisQueue (§1.6), each
≤ 7 ms in Studio; S8's `REPLAY_BUDGET_MS` and `PT_GENERATE_BUDGET_MS` follow (§14.11).

### 10.6 Impossible and inhuman input checks

**Impossible** input is `Invalid` (§6.7 reasons, `HashMismatch`): structure an unmodified client cannot produce.
**Inhuman** input is flagged; thresholds and each flag's level (HIGH or medium; `Items/Create.fromCraft` orders flags
by it) live in `Definitions/MinigameFamilies` (`checks` thresholds, `flagLevels`), and S8 reads them from there.

| Flag | Condition | Level → effect | Measured margin on human bots (E-S3.8) |
|---|---|---|---|
| `HzInhumanRate` | ≥ 30 presses in any 1,000 ms window | HIGH → clamp | humans ≤ 9 per window |
| `TsLowVariance` | ≥ 8 judged strikes and sample SD of the errors < 1.5 ms | HIGH → clamp | 0 / 100,000 per profile (Elite at 240 fps included); analytic 1.1·10⁻⁵ at σ 10 ms, n = 8 |
| `TsExactHits` | ≥ 8 judged and ≥ 90 % with \|e\| ≤ 1 ms | HIGH → clamp | 0 / 100,000 |
| `PtTooPrecise` | ≥ 40 grinding samples in travel and mean distance to the path < 0.0008 u (0.4 px at 520 px) | HIGH → clamp | human minimum 0.0028 (×3.5 over 3,000 runs, 30 fps / 360 px included) |
| `PtTooSmooth` | ≥ 150 moving triplets (span > 0.002 u, both dt 10–40 ms) and mean \|Δ²p\| < 0.0002 u | medium → telemetry | human minimum 0.0038 (×19) |
| `PtTeleport` | ≥ 3 grinding steps with a jump > 0.25 u in ≤ 40 ms | medium → telemetry | the coverage speed gate already gives them no credit |
| `PtSparse` | samples in travel < 50 % of `travelMs/20` | medium → telemetry | low-fps devices can trip it |

Mechanical rules come first, detection second: the bellows refill bounds the useful stroke rate; the first press in a
span decides it; Trace credit needs the pacer-relative search and the coverage speed gate; durations are fixed. Flag
kinds: these 7 plus S5's `LateSubmit` and `ScoreMismatch` = 9 ≤ S1's `MAX_STEP_FLAGS`; at most 4 S3 flags co-occur
(Trace). A HIGH flag only removes the top-quality contribution of that step: it never fails it **[Decision to
confirm]** (Q17). Cheats caught: exact TimingStrike times and exact or 200 ms-sparse traces (100 %), 30/s
autoclickers, the exact-state HoldZone controller (it needs up to 50 presses/s).

**Known limits (accepted, Q17).** The client must know the whole pattern to draw it, so a careful cheater can
synthesize human-looking input offline: TimingStrike σ 4 ms scores 1.000 unflagged, a trace with 0.004 u noise 0.985,
and a HoldZone controller kept under 30 presses/s is not detectable by rate. Server-side scoring still stops score
injection; items are display-only, and Epic is botable in the MVP. **Phase 2 hook:** progressive pattern reveal with
streamed inputs; HoldZone reaction-latency analysis; a Trace pixel-lattice check in S6's `toPanel` space; cross-session
statistics per player.

### 10.7 Timing checks

Rules and constants: §7.8. The early bound aborts pre-computed submissions (0 honest early submits in 10⁶). Slow
motion (playing at 1/k speed) is flagged when `(k − 1)·D > LATE_SOFT_MS + A − RTT` and times out when
`(k − 1)·D > LATE_HARD_MS + A − RTT` (RTT = the submission's round trip; 15 s step, ping 100 ms so A = 200 and RTT
= 100: flagged above k = 1.107, timed out above 1.340); it is **flagged, never punished** in the MVP
**[Decision to confirm]** (Q17). `A` is a median, so one inflated ping changes nothing; a ping held high all step
raises `A` to `RTT_ALLOW_MAX_MS` at most (Evidence: E-S5.3).

### 10.8 Text filtering

Blueprint names reach only their owner. An item takes its blueprint's name (no rename): raw for its owner, else
broadcast-filtered, or `InspectView.defaultName(item)` ("Iron-Steel Sword") until a result exists. Plot signs use
`Player.DisplayName`. `TextFilter` is the only caller: `TextService:FilterStringAsync(raw, ownerUserId,
Enum.TextFilterContext.PublicChat)` → `GetNonChatStringForBroadcastAsync()`, in `pcall`, while the owner is present.
Cache key `(itemId, raw)`, dropped when the owner leaves. No timed retry: a failure keeps the fallback until the
item's next `Showcase.Place` or session and logs `FilterFailed`. Handlers never wait; `PlotWorld.setLabel(plot,
slot, itemId, rev, text)` applies a late result only while the stand still holds `(itemId, rev)`; Inspect reads the
cache only. Player text never enters `Instance.Name`, attributes other than `ItemName`, logs or telemetry.
```lua
TextFilter.label(owner: Player, item: ItemRecord, onReady: (text: string) -> ()): string   -- cached or fallback
TextFilter.cached(itemId: string, raw: string): string?;  TextFilter.forget(owner: Player): ()
```

### 10.9 Telemetry and logging

`Telemetry.emit(player: Player?, event: TelemetryEvent, value: number, fields: { string }?, payload: { [string]:
string | number | boolean }?)`. Live: `AnalyticsService:LogCustomEvent` (value + ≤ 3 fields) in `pcall` behind
`TELEMETRY_BUCKET` {20, 0.25/s} per player. Studio/private playtests (`Config.TELEMETRY_ECHO`): a `TELEMETRY_RING`
2000 ring for S8's bridge (`Telemetry.since(seq)`) plus one `[TLM] <json>` line each. Records carry `sid` (random,
per join). Field values come from closed enums only (else `<Key> - Unknown`).

| Event | When · value | Fields | Payload (field owner) |
|---|---|---|---|
| `DataLoaded` | load end · ms | `Result - Ok\|Timeout\|Newer\|Corrupt\|Closing`, `Profile - New\|Returning` | bytes, fromVersion, repairs, quarantined (S1) |
| `DataIssue` | store error, critical, overwrite, size warn/block, quarantine · 1 | `Kind - …` | — |
| `BlueprintSaved` | Save ok · parts | `Valid - Yes\|No`, `Tiers - NHH`, `Materials - Iron\|Steel\|Mixed` | validation codes when invalid; per step g, d, tierRaw, tier and the 8 factors (raw, x); analysis ms (S2, S8) |
| `BlueprintRejected` | canonical/name failure · 1 | `Code - <CanonError>` | path |
| `CraftStarted` | Begin · steps | `Tiers`, `Materials`, `Parts - 1-8\|9-16\|17-24` | plan steps (S4) |
| `StepScored` | each step result · round(100·score) | `Step`, `Tier`, `Result - Pass\|Fail\|Timeout\|Invalid` | family, material, g, m, d, tierRaw, terms, score, rawScore, clientScore, status, invalidReason, flags, breakdown, elapsedMs, durationMs, A, balanceVersion (S2, S3, S8) |
| `CraftCompleted` | commit · round(100·Q) | `Rarity`, `Tiers`, `Cap` | `bp` (canonical blueprint hash), quality, rarityByScore, rarityCap, capStep, materialTier, stats (S4, S8) |
| `CraftAborted` · `ItemDisplayed` | abort · step reached / Place · slot | `Reason - <AbortReason>`, `Step` / `Rarity` | — |
| `AntiCheatFlag` | flag or strike · 1 | `Flag`, `Where - <Channel.Action\|StepId>`, `Severity - Hard\|Soft` | ping samples (LateSubmit) |
| `Desync` | ReportDesync · 1 | `Step` | clientHash, serverHash, family, balanceVersion |
| `RateLimited` · `FilterFailed` | first drop per minute · drops / failure · 1 | `Where` / `Context - Display` | — |
| `Perf` | 1 in 10 queue jobs, any judge over budget · ms | `Job - Analyze\|Prepare\|Judge\|Recompute` | slices, longest slice, queue wait, parts |

`Tiers - NHH` = tier initials in plan order. ≈ 1 250 field combinations (limit 8 000), ≤ 15 events/min/player
(platform share 20/min/CCU). Onboarding funnel (`LogOnboardingFunnelStepEvent`, a profile's first session only,
each step once): 1 Joined, 2 EditorOpened (the first `Profile.SetSettings` that sets S6's `uiFlags["Onboarding.1"]`),
3 BlueprintSaved, 4 ForgeStarted, 5 ItemForged, 6 ItemDisplayed, 7 VisitedNeighbour (first Inspect of another plot
or first `uiFlags["Onboarding.4"]`, whichever comes first).

**Logs** (S8's console gate matches them): `[blacksmith:<tag>] <LEVEL> <event> key=value …` (`<event>` = the telemetry
event name, or a PascalCase log-only name such as `RenderFailed`); LEVEL ∈ `DEBUG` (Studio only), `INFO` (`print`),
`WARN`, `ERROR` (`warn`); tags `boot data net bp craft show plot filter ac tlm`; keys sorted; control characters
escaped (`\x0A`), quotes escaped, values with spaces quoted, client strings cut to 64 B. Limits `LOG_BUCKET` {20, 2/s}
per (tag, event) and `LOG_PLAYER_BUCKET` {5, 0.5/s} per (player, tag, event), then one `suppressed=N` line. Example:
`[blacksmith:craft] INFO StepScored user=12345 step=Hammering passed=true`.

### 10.10 Threat model and residual risks

| A modified client can… | Defence | Residual risk (MVP) |
|---|---|---|
| flood any remote (≈ 500/s) | Guard, buckets, lanes, flood kick | µs per dropped request |
| compute perfect inputs from public code and seeds | server judge on real inputs; S3 inhuman-input clamp | a careful human-like bot passes: **accepted**, items are display-only **[Decision to confirm]** (Q17) |
| submit early, slow time | early bound; LateSubmit flag, timeout | slow motion under §10.7's k passes |
| fake outcomes, re-roll seeds, replay or race requests | recomputed; seed fixed per step; first submission wins; lanes; GUID upserts | crafting again is free |
| read others' data or flags | own-profile lookups; views carry no flags | displayed geometry is visible (S7, §17) |
| disconnect strategically | abort = no item; nothing consumed | Phase 2: debit materials at Begin |

---

## 11. Client: blueprint editor

> **Principle.** The editor edits a local copy of one blueprint. Every number it shows is a preview from the same
> pure `Pipeline` the server runs; only the server's result counts. Transforms are free: snapping is a tool the
> player sets per transform type, never a storage grid.

Units: **bp** = blueprint studs (stored); **display studs** = editor-stage studs (k × bp); **design px** = px at UI
scale 1 (§12.11). Constants not restated here: §16 (`EditorCore/Config`). Player-facing copy: `UI/Strings` (E-S6.12).

### 11.1 Rules and modules

1. One data path: Command → `History` → `SceneSync` → `Pipeline.quick` → preview. Instances are views: nothing is
   read back from a Part, no rotation is re-derived from a CFrame.
2. The document is S1's draft of `PartData` with raw doubles (§3 Record schema); typed values are stored as typed.

`src/shared/EditorCore/` (P): `EditorState` (§11.5), `Commands` and `History` (§11.11), `Snap` (§11.8), `Expr` and
`Rotation` (display-only Euler via `Blueprint/Quat`, §11.9), `GizmoMath` (§11.6), `EditorLayout` (§11.4), `Keymap`
(§11.15), `Config` (editor and preview-cadence constants, outside Balance and the BALANCE hash). They require
only `Definitions`, `Blueprint/*`, `Physics/Shapes`, `Pipeline`; trigonometry carries S8's `-- allow-transcendental:
editor display`. RB `src/client/Editor/`: `EditorController`, `StageSpace`, `Stage`, `SceneSync`, `EditorCamera`,
`Picking`, `Gizmo/*`, `PreviewScheduler`, `Autosave`, `Panels/*`; events use `Util/Signal`; `Main.client` connects
S7's `PromptController.Triggered` (§1).

### 11.2 Entering, leaving and the stage

Entry: S7's Draft prompt → Library; "Edit blueprint" in the forge flow; the Choose empty state (§12.2).

Open: `PlayerModule:GetControls():Disable()` (again on `CharacterAdded`) → `StationStage.enter(plotIndex,
"DraftingTable", onArrived)` (§13) → on arrival `BS_Fx` fades to `stage.backdrop` (`FADE_MS` 250) → PlayerList,
Backpack, EmotesMenu off, `ResetButtonCallback` false, `ChatWindowConfiguration.VerticalAlignment` Bottom →
`EDITOR_LIGHTING` → stage built, `CameraType` Scriptable → Library. Close (✕, or Forge ▸ which then enters the
Furnace, §12.1) reverses each step: under the fade `StationStage.enter(…, "DraftingTable", nil, true)` cuts to
the table framing, then `leave()`. Character death (reset is off) autosaves a dirty draft and closes the editor.
`Esc` exits only if the engine delivers it.

**Stage transform.** `k = EDITOR_DISPLAY_LENGTH / max(hitbox size) = 20/5 = 4`; every legal part stays inside the
enclosure (E-S6.1).
```
HC               = (HITBOX_MIN + HITBOX_MAX)/2 = (0, 2.5, 0)        -- §3 hitbox centre, bp
STAGE_ORIGIN     = World.EDITOR_STAGE_ORIGIN = (0, 1000, 0)          -- §13's reserved 256-stud cube; HC sits here
STAGE_CF         = CFrame.fromMatrix(STAGE_ORIGIN, −Y, +X, +Z)      -- VIEW_H: bp +X down, +Y right, +Z to camera
worldPoint(p)    = STAGE_CF:PointToWorldSpace(k·(p − HC))
partCFrame(p, q) = STAGE_CF · CFrame.new(k·(p − HC)) · CFrame.new(0, 0, 0, Quat.toMatrix(q))   -- Size k·size; §13.7's path
rayToBp(ray)     = (HC + STAGE_CF:PointToObjectSpace(ray.Origin)/k, STAGE_CF:VectorToObjectSpace(ray.Direction))
```
Gizmo, snap and pick math run in bp space on doubles. The Flat view (camera on bp +Z, tip right) is §13's `VIEW_H`:
the sword lies horizontally **[Decision to confirm]** (Q5).

Stage (`workspace.BlacksmithLocal.EditorStage/{Backdrop, Parts, Helpers}`, adornments under
`PlayerGui.BS_EditorAdorn`): `STAGE_ENCLOSURE`; `EDITOR_LIGHTING`: neutral Lighting, §13's `LIGHTING_FX`
neutralised (`BS_Atmosphere` Density, Haze, Glare 0; `BS_Grade`, `BS_SunRays` off; `BS_Bloom` 0.3; no Fog), all
restored on close, no other client script driving Lighting meanwhile; the `HEADLIGHT` PointLight on an invisible
part that follows the camera (lights need a BasePart parent); the hitbox ghost
(wireframe + faces, AlwaysOnTop); the **centre plane** x = 0 that Asymmetry and the mirror use (§5 Asymmetry), brighter
while `M` is hovered or held (z = 0 only for `Shift+M`); grid `G` on z = 0 (minor = move step if 0.05 ≤ step ≤ 1,
else 0.25; major 1).

### 11.3 Camera

State `{P, ψ, φ, d}` in stage (world) space; `look = (−sinψ·cosφ, −sinφ, −cosψ·cosφ)`, `eye = P − look·d` (Flat:
ψ = φ = 0; Tip: ψ = 90°). `EditorCamera` binds at `RenderPriority.Camera` and sets `Camera.Focus = CFrame.new(P)`
every frame while it owns the camera.

| Input | Effect |
|---|---|
| RMB drag; Space+LMB | orbit `ψ −= Δx·ORBIT_DEG_PER_PX`, `φ += Δy·ORBIT_DEG_PER_PX`, φ ∈ [−89.9°, 89.9°]; cursor locked |
| MMB, Shift+RMB, Space+Shift+LMB | pan `P −= wpp·(Δx·r̂ − Δy·û)`, `wpp = 2d·tan(FOV/2)/VH` (no perspective: `OS/VH`) |
| wheel, pinch | `d' = clamp(d·ZOOM_STEP^−n, CAM_MIN_DIST, dMax)`, `P' = X + (P − X)·d'/d`, X = cursor hit or the ray point at depth d |
| `F` · `Home` · double-click | focus selection (fill 0.8) · frame all (0.9) · recentre on the point; 200 ms ease |
| `Alt+1/2/3` (+Shift opposite), Numpad `1/3/7` | Flat (camera on bp +Z), Edge (bp −X, φ = 89.9°), Tip (bp +Y): orientation only |
| `O`, Numpad `5` | **No perspective** toggle |

- Walls: P stays `CAM_WALL_MARGIN` 2 inside the enclosure; `dMax = min(CAM_MAX_DIST, exit distance along −look −
  CAM_WALL_MARGIN)`.
- Fit: `d = e_z + max(e_w/(T_h·f_w), e_h/(T_v·f_h))`, `T_v = tan(FOV/2)`, `T_h = T_v·VW/VH`, `f = fill·area/viewport`
  (area between panels); the pivot shifts by `(areaCentreX − VW/2)·wpp`. Frame-all: d = 21.0, OS = 18.46 (E-S6.1).
  A blueprint opens at ψ = −20°, φ = 12°, framed.
- **No perspective**: at each editor open write `ProjectionType = Orthographic`, `orthoOK = (read-back ==
  Orthographic)`, restore Perspective. The toggle keeps OS = visible height at P. orthoOK: Vertical mode,
  `OrthographicSize = OS`, eye `min(ORTHO_EYE_DIST 100, dMax)` behind P, zoom scales OS. Otherwise telephoto:
  `FieldOfView = ORTHO_FALLBACK_FOV` 20°, `d = OS/(2·tan 10°) = 2.836·OS`, `OS ≤ ORTHO_FALLBACK_MAX_OS` 38.8 (d ≤ 110,
  ≤ dMax), zoom changes d, `wpp = OS/VH`. Never `ViewStretch` (E-S6.8).

### 11.4 Screen layout

Design px at 1920 × 1080. Top bar 52: ◂ Library · name ✎ · "Saved 12 s ago" / ● · ↶ ↷ · tools · Blueprint | Local ·
snap strip · "✕ 2 ⚠ 1" · Save · Forge ▸ · ⚙ · ? · ✕. Left 280: Add part, active slot and material, parts list.
Viewport 1300 × 942. Right 340, scrolling: Properties, Preview, Issues. Status bar 28: hint · cursor (bp) · selection
count · tier line. `EditorLayout`: under 750 of height Issues collapses to a chip; under 1700 of top-bar width the snap
strip becomes "Snap ▾"; fits 1280 × 720 at UI scale 0.75 (E-S6.2).

### 11.5 Document and state

```lua
--!strict
-- parts: S1's PartData (§3), immutable values (an edit replaces the table): History stores references
export type EditorDoc = {
	blueprintId: string,            -- client-minted GUID (HttpService:GenerateGUID(false)): New, Save as, Duplicate
	draft: Schema.BlueprintDraft,   -- {schema, name, type, parts}
	stored: boolean,                -- a server record exists (first save or autosave)
	manual: Schema.BlueprintDraft?, -- as opened or last saved by hand; Discard restores it (§11.14)
}
export type ToolId = "Select" | "Move" | "Scale" | "Rotate" | "Paint"
export type EditorState = {
	doc: EditorDoc, history: History.History,
	selection: { number },          -- part ids in click order; the last is the active part
	tool: ToolId, space: "Blueprint" | "Local",
	slotHidden: { [DT.SlotId]: boolean }, activeSlot: DT.SlotId, activeMaterial: DT.MaterialId,
	euler: { [number]: { e: Schema.Vec3, q: Schema.Quat } },   -- session Euler cache (§11.9)
	nextPartId: number,             -- max(id) + 1 at load, monotonic
	revision: number,               -- +1 per applied command (undo/redo too); tags previews
}
```
Every commit runs `Blueprint/Canonical` (§3): with raw doubles it only renormalizes q when `|‖q‖² − 1| > 1e-9` and
applies the hemisphere rule. Edit time: Ball keeps x = y = z, Cylinder y = z (axis = local X). Display ≤ 4 decimals
(trimmed to ≥ 2); a focused field shows the shortest round-trip form of the double.

### 11.6 Selection and gizmos

Click (< `CLICK_DRAG_THRESHOLD_PX` 4) selects; Shift/Ctrl+click toggles; Alt+click selects through (next part on the
ray); click empty clears; drag from empty = marquee replace (Shift adds; projected true-shape vertices inside);
`Ctrl+A` all visible; the parts list (Shift range, Ctrl toggle) and issue rows select and focus. Picking:
`workspace:Raycast` with an Include filter on `Parts` (hidden: `CanQuery = false`), handles first, never over UI
(§12.11). One pooled `Highlight` per part (≤ 24), AlwaysOnTop: outline `sel.outline` / `sel.active` / white 0.5
(hover); fill = overflow (§11.12).

Gizmos are custom HandleAdornments (E-S6.4), length `px·uiScale·wpp(pivot)` (`GIZMO_*` sizes), colours `axis.*`.

| Tool | Handles | Drag rule per selected part i (start p_i, q_i, s_i) |
|---|---|---|
| Move `2` | 3 arrows, 3 plane squares, centre sphere (camera-facing bp plane) | `p_i + snap(Δ)·A`; plane `p_i + snap(Δu)·U + snap(Δv)·V` |
| Rotate `4` | 3 rings ⟂ the space axes, view ring; sector + angle readout | `θ = snap(Δθ)`; `q_i' = q(N, θ) ⊗ q_i`, `p_i' = c + R(N, θ)·(p_i − c)` (the same angle for every part and for its centre) |
| Scale `3` | 6 face cubes, centre cube | active part only: `s_a' = s_a + snap(Δ)`, `p' = p + σ·(s_a' − s_a)/2·a`; Ctrl: `s_a' = s_a + 2·snap(Δ)`, p fixed; centre or Alt+face: uniform `f = 2^(px/UNIFORM_SCALE_PX_PER_DOUBLE)`; with Scale snapping on (Shift inverts), f is chosen so the largest side changes by a multiple of the Scale step (relative, §11.8); with it off, f is continuous |

```
axisParam(P, A, O, D): w = P − O; b = A·D; den = 1 − b² (no hit if < 1e-9); t = (b·(D·w) − A·w)/den
planeHit(P, N, O, D):  den = N·D (no hit if |den| < 1e-9); O + D·((P − O)·N/den)
ringAngle(c, u, v, h): atan2((h − c)·v, (h − c)·u); Δθ += wrap(θ − θprev) into (−π, π]
```
- A = handle axis, U/V = plane axes, N = ring normal, c = pivot, a/σ = dragged face axis and side (±1); Δ, Δu, Δv
  come from `axisParam`/`planeHit` minus their drag-start values, Δθ from `ringAngle`, all in bp.
- Rays: `rayToBp(Camera:ViewportPointToRay(mouse))`; each frame recomputes from the drag-start snapshot, so snapping
  and cancel are exact. RMB or Esc mid-drag restores the snapshot; `WindowFocusReleased` commits it.
- Handles fade from 18° to 12° off the view direction and hide below 12° (jitter ≤ ×4.8, E-S6.4); a ring within 12°
  of edge-on (`|N·D| < 0.208`) uses `Δθ = (m − m₀)·t̂/r_px`. Pick tolerance 8 px (10 for spheres and cubes); ties
  centre > plane > axis > ring.
- `Ctrl+L`: blueprint or active-part axes (Scale always local). Pivot c = centre of the selection's exact extents
  (`Physics/Shapes.aabb`). **Phase 2 hook:** group scale.
- LMB drag on a selected part moves from the grab point (`Ctrl+R`/`Ctrl+T` meanwhile turn 90° about the view axis
  / view right); with a selection they turn exactly 90° about the nearest bp axis (`q = {√½·axis, √½}`). Arrows and
  PageUp/PageDown nudge by the Move step value from the snap strip, whether Move snapping is on or off (Shift ×10,
  Alt ×0.1; merged within `HISTORY_MERGE_MS` 600, §11.11). `Ctrl+I` moves the selection inside the hitbox (a toast names
  axes that cannot fit). A read-only readout shows the drag delta.

### 11.7 Bounds on every transform path

`Definitions/Limits` (§3): `|pos_k| ≤ POS_ABS_MAX` 16; `MIN_DIM` 0.02 **[Decision to confirm]** (Q4) `≤ size_k ≤
MAX_DIM` 6.0; ≤ `MAX_PARTS` 24.

| Path | Rule |
|---|---|
| move drag, nudge, `Ctrl+I`, Snap to touch, Centre on axis, typed/relative position | delta clamped so every moved part keeps `|pos_k| ≤ 16`; a group stops as a whole |
| rotate drag, `Ctrl+R/T`, "Rotate by" | an angle putting a part centre beyond 16 is refused; the ring stops at the last valid angle |
| scale drag (Ctrl, uniform), typed/relative size | each side clamped to [MIN_DIM, MAX_DIM]; uniform clamps f so every side fits |
| shape change | → Ball: d = min(size); → Cylinder: length = x, d = min(y, z) |
| add, duplicate, mirror copy | disabled at 24 parts; mirror copy says how many would not fit |

A clamp is visible: handle or field turns `warn`, the readout names the limit ("max 16 from the origin", "min 0.02").
The hitbox is not a constraint (overflow is shown, §11.12); slot maxima are issues, not blocks.

### 11.8 Snapping

`settings.snap` (§12.9) per type `{on, step}`; presets are built-in.

| Type | Default | Presets | Step |
|---|---|---|---|
| Move | on, 0.05 stud | 0.01, 0.05, 0.1, 0.25, 0.5, 1 | (0, 16] |
| Rotate | **off**, 15° | 1, 5, 15, 22.5, 45, 90 | (0, 180] |
| Scale | on, 0.05 stud | as Move | (0, 16] |

**[Decision to confirm]** (Q5): Move and Scale snap at 0.05 for tidy joints; Rotate is free by default.

```
step(T, shift) = settings.snap[T].step if (settings.snap[T].on XOR shift), else free
delta(Δ, s)    = clean(round(Δ/s)·s)            relative only: the moved amount is a multiple of s
result         = clean(x0 + delta(Δ, s))         snapped results only; free values are never touched
clean(v)       = round(v·1e12)/1e12 if s ≥ SNAP_CLEAN_MIN_STEP (1e-9) and |v| < 1e3, else v
free when s is not finite, s ≤ 0 or |Δ/s| > 1e12
```
`clean` yields the double the player would type (0.3 + 0.25 → 0.55), moving a value ≤ 5.01e-13 (E-S6.3). Shift during
a drag inverts snapping; `S` toggles all three with a toast; letter hotkeys pause while RMB is held. Typed values are
never snapped. Palette placement snaps its two tangential coordinates to multiples of the Move step only while Move
snapping is on (Shift inverts, as in drags); the contact coordinate never snaps, and with snapping off placement is
free. Nudges and the 90° turns (Ctrl+R / Ctrl+T) are optional shortcuts; drags and typed values stay continuous and
are never rounded to them. First drag per tool: a one-time hint naming the step and Shift (`Hint.Snap<Tool>`). Snap
strip per type: toggle, value (expressions), ▾ presets.

### 11.9 Property panel and number fields

One part: Position, Rotation (°), Size (Ball Ø; Cylinder length, Ø), Slot, Material, Shape, extents ("inside ✓" or
the overflow), volume. Several: Position = pivot (moves the group); "Rotate by" (relative, about the pivot); Size of
the active part; Slot, Material, Shape show "Mixed" and apply to all.

`Rotation` (Roblox Orientation): `R = Ry(Y)·Rx(X)·Rz(Z)` from `Blueprint/Quat.toMatrix`; `X = asin(clamp(−R23))`,
`Y = atan2(R13, R33)`, `Z = atan2(R21, R22)`, alternative `(180° − X, Y + 180°, Z + 180°)`; at gimbal (cos X ≤ 1e-6)
the cached Z is kept. Shown: the solution nearest the session cache, else the smallest Σ|angle| (typed (170, 0, 0)
reopens as typed). Editing one component rebuilds q from the full-precision cached triple with only that component
replaced (never from the rounded display) and stores that triple as the new cache. Round trip 1 − |q·q'| ≤ 4e-16,
≤ 3e-6° near gimbal (E-S6.5).

`Expr`: `expr := term (± term)*`, `term := unary ((× | * | ÷ | /) unary)*`, `unary := ±unary | number | (expr)`;
decimal `.` or `,`; units ignored (°, deg, st, studs); ≤ `EXPR_MAX_LEN` 64; finite result; `+=` `-=` `*=` `/=` apply
per selected part. Commit on Enter, Tab or blur (one command); invalid → border flashes `danger` 400 ms, reverts,
tooltip `Syntax` / `NotFinite` / `TooLong`.

### 11.10 Parts, slots, materials, mirror

Palette (`Shift+A` at the cursor), default bp sizes: Block 0.30 × 0.60 × 0.10; Wedge, CornerWedge 0.30 × 0.30 × 0.10;
Cylinder length 0.80, Ø 0.16, turned 90° about Z (axis +Y); Ball Ø 0.30. A ghost follows the cursor, flush on the hit
face (`pos = hit + n·h_n`) or on the camera-facing bp plane through the pivot; LMB places (Shift+LMB keeps placing),
RMB/Esc cancels; the part takes the active slot, material and next id.

- Slots: Properties, context menu or `Ctrl+1…4`; required slots marked; per-slot eye toggle (hidden parts still
  count). Materials: Properties, Paint tool `5` (click or drag, one command per stroke), "Apply to selection". The
  Steel swatch says it gives a better edge and +2 % quality, tightens minigames slightly and does not make a step
  harder **[Decision to confirm]** (Q13).
- Mirror: `M` copies across x = 0, `Shift+M` across z = 0, ▾ "Flip in place" (replaces each selected part by
  `Mirror.reflect(part, plane)`: same id, no copy, one command); math = `Blueprint/Mirror` (§3),
  then canonicalized; copies keep slot and material, get new ids and become the selection; parts on the plane
  (`Mirror.isSelfSymmetric`: the solid is its own image, not merely centred there) are skipped (toast). A tool-mirrored
  design measures exactly symmetric (E-S6.7). `C` **Centre on axis** moves the
  selection so the centre of its extents is on x = 0.
- `Ctrl+D` duplicates in place (toast: they overlap until moved); Delete/Backspace deletes. Context menu (RMB released
  within 4 px and `RMB_CLICK_MAX_MS` 250): Delete, Duplicate, Mirror copy X / Z, Snap to touch (floating part).

### 11.11 Undo and redo

```lua
--!strict
export type PartPatch = { id: number, before: Schema.PartData?, after: Schema.PartData? }  -- nil before = added
export type Command = { label: string, patches: { PartPatch }, nameBefore: string?, nameAfter: string?,
	selBefore: { number }, selAfter: { number }, mergeKey: string?, atMs: number? }
History.push(h: History, cmd: Command): ()           -- clears redo; merges on equal mergeKey within HISTORY_MERGE_MS (600 ms)
History.undo(h: History, doc: EditorDoc): Command?   -- History.redo likewise
History.markSaved(h: History): ()                     History.isDirty(h: History): boolean
Commands.apply(doc: EditorDoc, cmd: Command, dir: "Forward" | "Backward"): { number }     -- changed ids
```
In history: add, delete, transform, slot, material, shape, mirror, duplicate, rename, paint stroke, nudge inside,
centre on axis, snap to touch; not selection, camera, visibility, tool, settings. One drag, field commit or stroke =
one command; undo mid-drag cancels it. `HISTORY_MAX_COMMANDS` 200 and `HISTORY_RECORD_BUDGET` 6000 part records
(≈ 5.6 MB, E-S6.6), oldest out first; cleared on open. Every `Commands` output passes `Canonical` unchanged (T-ED).

### 11.12 Validation feedback

After every command `Pipeline.quick(core)` (structure, containment). While dragging: containment of the dragged parts
each frame (`Physics/Shapes.aabb`) and `Pipeline.quick(core, {connectivity = true})` on the transient draft at ≤
`CONNECTIVITY_MAX_HZ` 10, so floating parts are outlined live. Overflow: Highlight fill `danger`,
FillTransparency 0.45 ↔ 0.70 over `OVERFLOW_PULSE_PERIOD_MS` 1200 (reduced motion 0.55), a red plate on the crossed
hitbox face, the overflow ("+0.12") at the worst point.

Issues sort errors → warnings → info, then slot; a click selects and focuses; errors block Forge. Each §4 record
`{code, partId, slot, reason?}` (`OutOfHitbox`, `SlotMissing`, `SlotTooMany`, `Disconnected`,
`BladeNotAboveGrip`; cleaned `Dust` ⚠, `Enclosed` ℹ) has a message and a fix in plain words
(E-S6.12): `OutOfHitbox` names the overflow and `Ctrl+I`; `SlotMissing` with reason `Cleaned` says the slot's parts are
too small or hidden to count; `Disconnected` names the gap ("Pommel floats 0.02 studs from the Grip") and offers
[Snap to touch]. Server codes: §12.12.

Floating components (§4: main = most Grip volume, else largest; each other one has its closest pair `{gap, dir,
nearestPartId}`) are outlined `warn`. **Snap to touch** moves one along `dir` by `gap − CONTACT_TOL/2` as one command
(clamped, §11.7). Ignored parts get an "ignored" badge and, with overlays on, Transparency 0.35.

### 11.13 Live preview

`PreviewScheduler`: after `quick`, a `PREVIEW_DEBOUNCE_MS` 120 debounce and ≤ `PREVIEW_MAX_HZ` 4 runs/s; a coroutine
runs `Pipeline.analyze(core, {checkpoint = slice})`; `slice` calls `task.wait()` once `PREVIEW_SLICE_MS` 6 of the
frame are used (§4.9) and raises `CANCELLED` when `state.revision` moved on; results carry their
revision. No Actors. While editing the panel dims ("…"). Cost: §4.9. Acceptance (§14 M-09): minimum-spec PC,
S2's adversarial fixture P1 (§4.9), no frame over 33 ms, no slice over `CLIENT_SLICE_MAX_MS` 8 ms, preview ready
≤ 500 ms after the debounce.

Panel (example E-S6.13), from the report (§4 `physics`, per-step `d`, `tierRaw`, `tier`, `terms`; §8 preview block):
Mass, Balance (offset from the guard, and the Balance stat), Reach, parts n/24; **Potential**: stats at all
step scores 0.5 and 1.0 (passed), green/red deltas after each commit, `Stats.breakdown` tooltip; per step: tier chip,
D bar, distance, quality multiplier; rarity cap with `capStep`, quality ceiling.
- Bars span D ∈ [0, 1] with `Definitions/Tiers` ticks; the chip is the played tier (raw tier above Hard shows
  "Hard", tooltip "Very hard design — plays as Hard for now"); beside D the distance to the next tier or above the
  played threshold, "≈" within 0.02. The status bar repeats the three tiers.
- "quality ×d" = the step's multiplier (§8); tooltip: bolder designs pay inside a tier, each +0.1 difficulty adds
  ×(γ·0.1·d(tier)) **[Decision to confirm]** (Q11).
- Hover breakdown from `terms` **[Decision to confirm]** (Q7): D and the tier threshold, each factor's value × weight
  (Asymmetry "about x = 0"), the material term (0 in the MVP) and the work set ("all kept parts (14)").
- Overlays (`B`, on): centre of mass, grip point, balance point, reach line, each labelled.

### 11.14 Library, saving and autosave

Library modal 1100 × 680: rows (static thumbnail, name, parts and materials, **Valid** / **Needs fixes**, tier
chips); the selected blueprint (drag orbits its view camera) with its stored analysis; Open, Forge, Duplicate,
Rename, Delete; "Blueprints 7/40"; New ▾ (Empty / Starter sword = F5, `Template.STARTER`, §12.9). Data: S1's `BlueprintSummary`;
thumbnails per §12.4, cached by `(blueprintId, revision)`. Empty: "No blueprints yet" + New ▾.

| Action | Rule (requests: §10 catalogue) |
|---|---|
| Save `Ctrl+S` | `Names.sanitize` + `Canonical.draft` first; disabled in flight; "Saving…" → "Saved ✓"; sets `doc.manual`; `Blueprint.Save {blueprintId, draft}` → `{summary, valid, errors, analysis?}` |
| Autosave **[Decision to confirm]** (Q6) | same upsert every `AUTOSAVE_S` 60 while dirty, after `AUTOSAVE_IDLE_S` 2 without edits, never during a drag or a save in flight; the first creates the record. New ▾ names a new doc "Sword <n>" at creation (n = the smallest positive integer no "Sword <k>" in the library uses), so every draft passes `Names.sanitize` |
| Save as `Ctrl+Shift+S`, Duplicate | new GUID, "‹name› copy"; disabled at `MAX_BLUEPRINTS` 40, as is New ▾ |
| Invalid (Q6) | saves; "Needs fixes"; Forge disabled with the error count |
| Rename · Delete | top-bar name (undoable, saved with the draft) or Library → `Blueprint.Rename` · confirm (forged items keep their own copy) → `Blueprint.Delete` |
| Exit, Open, Forge ▸ with changes since `doc.manual` | [Save] [Discard] [Cancel]; Discard re-saves `doc.manual`, or deletes a record only autosave created |

"Saved" means the server stored the record in the profile; it reaches the DataStore on §9's cadence.

### 11.15 Hotkeys

Letters bind by label: `Keymap.resolve(label, labelOf)` scans A–Z, Semicolon, Quote, Comma, Period, Slash,
LeftBracket, RightBracket, BackSlash, Minus, Equals, Backquote for `string.upper(labelOf(key)) == label`, prefers A–Z
on ties, else the QWERTY key; `labelOf` = `GetStringForKeyCode`, injected for Lune tests (AZERTY: M → Semicolon, Z
→ W, A → Q); re-run at each open. Digits, F-keys and navigation keys bind by position with canonical labels ("1",
"F1", "PageUp"). No hotkey uses `/`, Tab, F9, F11; Esc is best effort; Shift is free because the project sets
`EnableMouseLockOption` false (§1). **Phase 2 hook:** rebinding (bindings are data). Sheet (Help, §12.9): tools
`1`–`5` Select, Move, Scale, Rotate, Paint; `Ctrl+Z`, `Ctrl+Y`/`Ctrl+Shift+Z`; `Ctrl+D`; Delete; `Ctrl+S`,
`Ctrl+Shift+S`, `Ctrl+O` library, `F1` help; the others as given in §11.3–§11.10.

---

## 12. Client: forge flow, minigame UI, results

> **Principle.** The forge UI draws the shared S3 simulation and never decides a score: the server's replayed
> result replaces the local one. Every state shows by shape and colour; every sound has a visual twin.

### 12.1 Flow and rules

```
Idle ─► Choose ─► Overview ─Begin─► per step i: Transition ─arrived─► Intro ─Start─► Countdown ─► Playing
        ─► Submitting ─► StepResult ─► next step | Results (Place | Done | Forge again | Edit | Scrap)
any forge screen ─Abandon─► Idle;  push Craft.Aborted{reason} ─► modal ─► Idle;  push StepTimedOut ─► StepResult
```
Requests (§7): `Craft.Begin`; `Craft.StartStep` → `StepOpenView` (S3's `StepSpec` incl. `source`, `patternHash`, +
session fields); `Craft.Submit {sessionId, stepIndex, timeline: buffer, clientScore}`; `Craft.Abandon`;
`Craft.ReportDesync`; `Craft.Resume` (a UI start with a live session offers [Resume] [Abandon]).

| Rule (§7 step outcomes) | UI |
|---|---|
| plan order, each step once, final | no retry or skip |
| a fail counts at φ (`Definitions`, 0.75), lifts no cap, the craft goes on | StepResult shows score, pass line, the counted score, and on Hard "Epic not unlocked" |
| no submission by the deadline: score 0, `timedOut` | StepResult "Time's up — no input received" |
| abandon (2 clicks within `ABANDON_CONFIRM_MS` 3000, Esc if delivered), disconnect, timeouts, death: no item | no penalty text; modal per reason (§12.12) |
| invalid timeline → abort `InvalidInput` | modal, never a FAILED stamp; an unmodified client never sends one (§12.5) |
| `hash(pattern) ≠ spec.patternHash` on the client | re-open `Craft.StartStep` once (same seed); if it persists `Craft.ReportDesync` → abort `Internal`, no strike |
| idle in Ready(i) (§7 deadlines) | Intro countdown "The forge cools in 0:25" under `IDLE_WARN_S` 30 |
| storage full (`MAX_ITEMS` 150) | Begin disabled, [Open items] |
| countdown `COUNTDOWN_MS` (server) from the StartStep reply | not skippable; pattern visible |

Entry: S7's Forge prompt → Choose; the editor's Forge ▸ and the Library's Forge → Overview of that blueprint (pacing: E-S6.9).
Stations: `StationStage.enter(plotIndex, station, onArrived)` per S7's step → station map; the Intro opens in
`onArrived` (no step clock during a move); "Forge ▸" first cuts to the table framing (§11.2). During the flow controls
are off, PlayerList/Backpack/EmotesMenu hidden, reset off; chat off in Countdown and Playing **[Decision to confirm]**
(Q16); `StationStage.leave()` at the end. A primary key (Space/Enter) fires only on a fresh press starting ≥
`PRIMARY_KEY_GUARD_MS` 600 after its screen appears; held or repeated keys are ignored.

### 12.2 Screens

- **Choose** (modal): cards with thumbnail, name, tier chips, rarity cap, "Needs fixes"; none valid: "No blueprint
  ready — [Open the drafting table]" (opens the editor). **Overview**: turntable; materials per slot; per step
  minigame, works on, D, tier, weight, ~duration; rarity cap (`capStep`), quality ceiling; "a failed step lowers
  quality; nothing is destroyed"; mass, balance, reach; [Begin] [Edit] [Back]. D, tiers and physics are the
  server's (`BlueprintSummary.analysis`, §3.3); rarity cap, `capStep` and quality ceiling come from the client's
  `Pipeline` preview of the same record (bit-identical, §11.13); works-on and weights `Definitions/CraftPlans`,
  durations S3's params.
- **Transition**: "STEP 2/3 · HAMMERING" + tier chip during S7's move. **Intro**: 2-line how-to, KeyHints with both
  bindings, tier effect (S3 `Params.explain`), pass line, fed stats, idle warning, "Hide tips for steps I
  know" (`TipsHidden.<StepId>`); [Start] [Abandon]. **Countdown**: widget at t = 0, "3 · 2 · 1" per
  `COUNTDOWN_BEAT_MS` 1000, "GO" for `GO_VISIBLE_MS` 400 into play. **Playing**: widget, step header, timer ring,
  live score, KeyHints, Abandon top-left outside the widget. **Submitting**: widget frozen, provisional score greyed.
- **StepResult**: `floor(score·100 + 0.5)` %, PASS/FAILED, S3's breakdown keys (§6: in-zone %; Perfect/Good/Ok/Miss,
  whiffs, mean early/late; coverage, accuracy, pace, "generic edge" when `usedFallback`), fail cost, fed stats;
  [Next step] / [See the result]. The local result is sent as `clientScore`; the reply's result replaces it.

### 12.3 Results card

- Name, rarity colour + name, turntable, Quality `floor(Q·100 + 0.5)` on a bar Q ∈ [0, `QUALITY_BAR_MAX` 1.45] with
  `Definitions/Rarities` ticks. Past the cap the bar is hatched with a lock: "Epic needs a passed Hard step — bolder
  designs play Hard" + [Edit blueprint] (Steel raises no tier, §5). Stats per `Definitions/Stats`, hover = S4's
  `Stats.breakdown`; history: step, tier, score %, ✓ / ✕ / no input. Data: on `next = "Completed"` (or a final
  `StepTimedOut` carrying `item`) the card requests `Showcase.GetItems {itemIds = {item.id}}` and draws Quality, the
  stats, the lock (`outcome.rarityByScore` above `outcome.rarityCap`, `capStep`) and the history from the returned
  `OwnerItemView`; the reply's `ItemSummary` only updates the Items list.
- Reveal, skippable by click or primary key: fade in 300 ms; the bar fills over `RARITY_FILL_MS` 1600 (cubic out),
  ticks light as passed, a capped fill stops at the lock with a 6-px shake; the rarity stamps in over
  `RARITY_STAMP_MS` 700. Reduced motion: end state at once.
- Timing offset (§6 TimingStrike): when `breakdown.judged` ≥ `TS_OFFSET_OFFER_MIN_JUDGED` 8, if Hammering's signed
  `meanErrMs` has `|meanErrMs| ≥ OFFSET_SUGGEST_MIN_MS` 15: "Your
  strikes were on average 31 ms late" + [Use −31 ms offset] → `timingOffsetMs = clamp(timingOffsetMs +
  round(meanErrMs), −120, 120)`; button and slider show −timingOffsetMs (the shift applied to presses).
- [Place on display] → StandPicker → `Showcase.Place {slotIndex, itemId}`; [Done] (the item is already stored);
  [Forge again]; [Edit blueprint]; secondary [Scrap] (`Showcase.Scrap`, confirm). The item's summary comes with the last
  Submit reply (§7) and its full view is fetched as above; "✓ Saved" appears on `Profile.Notice{ItemSaved}`, which can
  take about a minute (§9).
- First item: a one-time hint (`Hint.Bolder`): thinner or longer blades, asymmetry and surface detail play
  Hard, and a passed Hard step unlocks Epic.
- Turntable: `ItemModelBuilder.mountInViewport(vp, plan, "VIEW_H")` → (Model, Camera); the camera orbits, the model
  stays; rarity = frame colour.

### 12.4 Items and pickers

**Items** panel (HUD): the player's items newest first (thumbnail, name, rarity frame, Quality, "On Stand 3");
Inspect (§13), Display…, Take down (`Showcase.Clear`), Scrap (confirm). **Item picker** (S7's Display prompt on an
empty stand): the same grid, displayed items marked, pick → `Showcase.Place`; empty: "Forge a sword at the anvil
first". **StandPicker** (Results, "Display…"): the 6 stands, empty or ‹item›; an occupied one confirms the swap. Every
grid (Choose, Library, Items, pickers) is virtualized: only visible tiles hold a ViewportFrame, ≤ `VIEWPORT_LIVE_MAX`
24 pooled; thumbnails static; geometry fetched for visible tiles only, cached by `(blueprintId, revision)` or `itemId`.
No item rename (§3 Names).

### 12.5 Minigame host and input

```lua
--!strict
export type ViewContext = { spec: StepSpec, pattern: any, tier: DT.TierId, material: DT.MaterialId, uiScale: number }
export type MinigameView<V> = {
	mount: (self: MinigameView<V>, parent: GuiObject, ctx: ViewContext) -> (),
	render: (self: MinigameView<V>, view: V) -> (),                  -- S3's read-only snapshot
	onFeedback: (self: MinigameView<V>, ev: FeedbackEvent) -> (),    -- cues and VFX only
	unmount: (self: MinigameView<V>) -> (),
}
MinigameHost.setInputSource(fn: ((t: number) -> { any })?): ()   -- test hook (S8 autoplay with S3 bots)
```
- StartStep reply: `Minigames.start(spec)` (S3) rebuilds the pattern (mismatch → §12.1);
  `goClock = os.clock() + spec.countdownMs/1000` at receipt; the host creates
  `Input.new(spec, settings.timingOffsetMs, goClock)` and calls `:go(…)` on the first frame at or after GO;
  `t = floor((os.clock() − goClock)·1000)` ms. `BindToRenderStep("MinigameView", Camera + 1)`: InputCapture pushes the
  frame's records, the host calls `advance` (FeedbackEvents → §12.10), then `render(view(session, t))`. Submit via
  `task.delay` at goClock + durationMs: `Minigames.encode(spec, records)` → buffer,
  `clientScore = finish(session).score`.
- `Minigames/InputCapture` applies S3's client rules (§6): records from GO (held state and cursor at GO at t = 0);
  TimingStrike press = centred time − `timingOffsetMs`, floored at 0; HoldZone records OR-state changes only;
  grind sampled on the 20 ms schedule; record caps never exceeded. Bindings: HoldZone Space or LMB taps (each press is
  one bellows stroke, §6.8); TimingStrike LMB or Space press; Trace LMB or Space held, or toggled with `grindToggle`.
- Input safety: in Countdown and Playing every GuiObject over the play area has `Active` and
  `Selectable` false; the only button is Abandon, outside the widget. gameProcessed filters InputBegan only; an
  InputEnded for an input recorded down is always recorded; the cursor comes from InputChanged regardless; each frame
  held state is reconciled with `IsKeyDown(Space)` and `IsMouseButtonPressed(MouseButton1)` (not in toggle mode);
  `WindowFocusReleased` and `GuiService.MenuOpened` record releases and show "The forge doesn't pause" (Q16); a key
  held across refocus counts only after a new InputBegan.
- At Countdown the focused TextBox is released and chat turned off; during Trace `MouseIconEnabled = false`;
  both restored at StepResult. Widgets sit on a `surface.3` backdrop at transparency 0.35. Feel (S3): no
  camera shake while scored, key elements on top with an outline, ≤ 1 frame of visual latency.
- Bridge hooks (§14.10, Studio test experience only): `MinigameHost.setInputSource`, a read-only UI state query
  (screen, editor preview summary, minigame view) and the controller actions behind the bridge's `loadBlueprint` and
  `openStation`; S6 names the last two in the build (§17.2).

### 12.6 Smelting: hold zone

Reads S3's `HoldZoneView` (§6). Vertical gauge `GAUGE_SIZE` at (0.70, 0.52), 0 at the bottom: zone `zoneCenter ±
zoneHalf` notched on both sides, dashed soft band `± (zoneHalf + softBand)`, needle (gold while `inZone`), heat
column; state "IN ZONE ✓" / "TOO COLD — pump ▲" / "TOO HOT — ease off ▼"; phase "Heat it up" (Ramp, zone
desaturated) then "Hold it"; hint "Tap to pump", and the fire meter pulses "Tap!" while the fire is low; cosmetic
°C = 300 + 1300·temperature; the bellows icon squashes on each `Stroke` event; vignette ∝
temperature; `ItemModelBuilder.setHeat(workpiece, temperature)` ≤ 15 Hz.

### 12.7 Hammering: timing strike

Reads S3's `TimingStrikeView` (§6). Circular dial **[Decision to confirm]** (Q15), `DIAL_DIAMETER` at (0.5, 0.62),
ring r 200, one turn per cycle: needle `θ = 360°·marker` clockwise from 12 o'clock; window centre
`360°·windowCenter`, Ok/Good/Perfect `± 360°·{windowHalf, goodHalf, perfectHalf}`.
- Needle: a transparent square container (2r = 400, AnchorPoint (0.5, 0.5) on the dial centre, Rotation = θ)
  holds the 4 × 200 bar (Position (0.5, 0, 0, 0), AnchorPoint (0.5, 0)) and the tip dot; only the container rotates
  (E-S6.11).
- Track: Frame + UICorner(0.5) + UIStroke; window arcs: opaque Path2D (pre-blended colours, tangent control points,
  4 per circle, ≤ 50 points each) with radial notches; the `next` window as a ghost arc.
- Pips with grade colour and glyph (★ ● ◐ ✕); popup "PERFECT ▸ +8 ms" / "◂ GOOD −21 ms" rising over `GRADE_POPUP_MS`
  600; combo "×5". `StationFx.strike()` per real strike (§13).

### 12.8 Sharpening: precision trace

Reads S3's `PrecisionTraceView` (§6); path from the pattern (3 : 1 panel, blade +X down as in `VIEW_H`). `TraceCanvas`:
UIAspectRatioConstraint 3.0, `TRACE_CANVAS` design size at (0.5, 0.53), fitted to 90 % of the width and the height
between header and hints, laid out once at Countdown, in `BS_Forge`, **outside any UIScale** so Path2D thickness is
the scored band in px. Mapping, S3's input contract (any ScreenInsets):
```
p = InputObject.Position   (or GetMouseLocation() − GuiService:GetGuiInset())
u = clamp((p.X − canvas.AbsolutePosition.X)/canvas.AbsoluteSize.Y, 0, 3)
v = clamp((p.Y − canvas.AbsolutePosition.Y)/canvas.AbsoluteSize.Y, 0, 1)        -- S3 quantizes round(·16384)
TraceCanvas.toPanel(p: Vector2): (number, number)      TraceCanvas.toScreen(u: number, v: number): Vector2
```
- Band: opaque Path2D, thickness `2·halfWidth·H` px (H = canvas height; ≤ 100), core `2·coreFrac·halfWidth·H` (≥ 2);
  ≤ 50 points per Path2D, neighbours share a point, long paths every 2nd point. A band ≥ 12 px at 720p (H = 384)
  needs halfWidth ≥ 0.0156 (E-S6.10).
- Blade silhouette = a ViewportFrame of the blade behind the canvas (ImageTransparency 0.85); pacer spark, the next
  0.5 u brightened; the start point pulses in the countdown (holding through GO is allowed); trail of the last
  `TRACE_TRAIL_SAMPLES` 24 positions by accuracy credit (≥ 0.9, ≥ 0.6, > 0, 0); reticle solid while grinding, dashed
  lifted, ✕ off path; coverage bar, pace arrow, covered runs tinted.

### 12.9 Smithy HUD, settings, help, first session

`BS_Hud` top-left: **Items**, **My smithy** (`Showcase.TeleportHome {}`, refused during a craft),
**Settings**, **Help**, then the First steps tracker. S7's `PlotPresence` shows "‹DisplayName›'s smithy" once per
visit. Settings is also the editor's ⚙; its record (S6 owns the fields, S1's `Persistence/Settings` shapes and
sanitizes it, §9 Profile.Data):

| Field | Default | Range · control |
|---|---|---|
| `snap.move`, `snap.scale` / `snap.rotate` | `{on = true, step = 0.05}` / `{on = false, step = 15}` | step (0, 16] / (0, 180] · snap strip (§11.8) |
| `reducedMotion` | false | "Reduce motion" (also on when Roblox's is) |
| `timingOffsetMs` | 0 | integer −120…120 · "Strike timing" slider, 1 ms |
| `sfxVolume` | 1.0 | 0…1 · "Sound effects" |
| `grindToggle` | false | "Grind: hold / toggle" |
| `space` · `overlays` | `"Local"` · grid, hitbox and physics on | editor top bar Blueprint / Local, `Ctrl+L` (§11.6) · `G`, `B` (§11.2, §11.13) |

Changes apply at once and go out as `Profile.SetSettings {settings, uiFlags}` after `SETTINGS_SAVE_DEBOUNCE_S` 2.
`uiFlags` keys: `Onboarding.1`…`.4`, `Onboarding.Hidden`, `Hint.SnapMove`, `Hint.SnapScale`, `Hint.SnapRotate`,
`Hint.Bolder`, `TipsHidden.<StepId>`. Help (`F1`, ? in the editor): the loop in four lines and the hotkey sheet.

First session **[Decision to confirm]** (Q21): the saved Starter Sword (§9 `starterGranted`; F5, all Iron, Normal on
every step) is in Choose and the Library at once; empty states per §11.14, §12.2, §12.4; a dismissible "First steps"
tracker: 1 Open the drafting table, 2 Forge a sword at the anvil, 3 Put it on a stand, 4 Visit a neighbour's smithy
(PlotPresence sees another plot). Each step sets `Onboarding.<n>`, × sets `Onboarding.Hidden`; the next station gets a
client-side Highlight. The server logs the funnel (§10 Telemetry).

### 12.10 Audio cues

`Definitions/Audio` (S6, P): ordered rows `{hook, id, volume, pitchRange}`; `id` = a Roblox-published free Creator
Store sound picked during the build, `""` legal and silent **[Decision to confirm]** (Q20). `UI/Sfx.play(hook)`: one
pooled Sound per hook in SoundGroup `SFX` (Volume = `sfxVolume`), pitch random in `pitchRange`. Hooks `Go`,
`CountdownTick`, `CycleStart`, `StrikePerfect`, `StrikeGood`, `StrikeOk`, `Miss`, `Bellows`, `FurnaceLoop`,
`GrindLoop`, `Pass`, `Fail`, `RarityReveal`, `UiClick`, fired by the countdown, S3 FeedbackEvents, StepResult, the
reveal stamp and buttons; `FurnaceLoop`, `GrindLoop` are 3D on the active station (S7's `StationFx`).

### 12.11 UI kit and accessibility

- No UI library: `Component<P> = {instance, update(self, props), destroy(self)}`, `Create.new(className, props,
  children?)`, `Value.new<T>(v)` (`get`, `set`, `observe`); events `Util/Signal`; strings from `UI/Strings`; pooled
  instances, none created per frame; `BindToRenderStep` only for live widgets.
- ScreenGuis (`ResetOnSpawn` false, Sibling, `CoreUISafeInsets`): `BS_Hud` 10, `BS_Editor` 20, `BS_Forge` 30,
  `BS_Overlay` 35 (3D labels), `BS_Modal` 40; `BS_Fx` 50 (`None`, non-interactive).
- `UI/Theme` tokens (values E-S6.14): surfaces, text, `accent`, `focus`, `ok`, `warn`, `danger`, `info`, `axis.*`,
  `stage.*`, `sel.*`, slots; tier and rarity colours from `Definitions`, always beside their name. Fonts GrenzeGotisch,
  Merriweather Bold, BuilderSans Medium, RobotoMono Medium (numbers) **[Decision to confirm]** (§17.1 O5).
- Text: TextSize ≤ 100, larger via a local UIScale (countdown TextSize 80 under UIScale 2.0, pop 2.6 →
  2.0); labels use AutomaticSize + TextWrapped or `TextService:GetTextSize`, so Roblox's Text Size never clips.
- `uiScale = clamp(min(VW/1920, VH/1080), UI_SCALE_MIN 0.75, UI_SCALE_MAX 2.0)`, automatic, one UIScale per top-level
  panel (not the trace canvas), recomputed on `ViewportSize` changes.
- Reduced motion = `GuiService.ReducedMotionEnabled` OR `reducedMotion`, refreshed on change (`UI/Motion.reduced()`,
  read by S7 too): tweens jump to end states, pulses hold, no shakes. Panel transparency × `PreferredTransparency`.
- Tooltips after 500 ms (action + hotkey); ≤ 3 toasts, 3 s (errors 6 s); modals trap focus. Input contexts, top
  first: Modal → TextEntry (hotkeys off) → Minigame → Forge → Editor → World; "over UI" = `GetGuiObjectsAtPosition`
  hits a visible `Active` object of ours; the wheel over a ScrollingFrame never zooms.

### 12.12 Errors and server states

Replies are `Ok`/`Err` with S5's `ErrorCode` (§10). After `E_TIMEOUT` (`REQUEST_TIMEOUT_S`) the client resyncs
(`Profile.Sync`, `Craft.Resume`) and never re-sends, except one `Craft.Submit` retry (§7.7); "Still working…" after
`UI_SLOW_HINT_MS` 3000. Copy: E-S6.12.

| Code or push | UI |
|---|---|
| `E_NOT_READY` | waiting spinner; Save, Forge disabled until the snapshot |
| `E_TIMEOUT`; `E_NOT_FOUND`, `E_SESSION_MISMATCH`, `E_WRONG_STATE`, `E_NO_SESSION` | resync (toast for the first only) |
| `E_RATE_LIMITED` · `E_BUSY` | button greyed 2 s · one retry after 1 s |
| `E_INVALID_BLUEPRINT` (Save: `details` = `{code, path}`; Rename: `{"BadName", code}`; Begin: the §4 codes, or `{"OutOfRange"}`) | Save, Rename: toast naming the field, logged as a bug (the editor pre-runs `Names.sanitize` and `Canonical.draft`); Begin: modal + [Open in editor]. A Save's §4 records come in its ok reply's `errors` and fill the issues list |
| `E_LIMIT_REACHED` · `E_TOO_FAR` | names the cap (40 / 150) · "Go back to your smithy" + [My smithy] |
| `E_SESSION_ACTIVE` (`data.session`) | [Resume] [Abandon] |
| `E_SESSION_EXPIRED`, `E_INVALID_INPUT`, `E_TOO_EARLY`, push `Craft.Aborted{reason}` | modal per reason (`Idle`, `SessionTimeout`, `ServerClosing`, `DataUnavailable`, `CharacterLost`, `InvalidInput`, `Internal`; none for `Abandoned`, `Left`) |
| `E_SERVER_CLOSING`, `Profile.Notice{ServerClosing / SaveDegraded / SaveRecovered}` (own save, §9) | banner |
| `E_SLOT_INVALID` · `E_DATA_UNAVAILABLE` · `E_INTERNAL` | refresh stands · rejoin modal · toast, one retry if idempotent |
| `E_BAD_REQUEST`; local ≠ server score | not expected, logged; the server score is shown |
| `Profile.Notice{ItemUpdated}` (lazy recompute, §9.7) | refetch that item (`Showcase.GetItems`) and redraw it |

Disconnect: Roblox's dialog; the craft is discarded (§7).

---

## 13. Smithy world, displays, item rendering, inspect

> **Principle.** The server builds the world at boot from pure data (`Instance.new`, no assets, nothing in the
> place file). One builder draws every item, on stands, stations, viewports and in the editor, so everyone sees
> exactly the part list that was measured.

### 13.1 Modules

Pure: `World/Layout`, `ItemRender/RenderPlan`, `Showcase/{ShowcaseRules, InspectView}`, data `Definitions/World`
(layout, Build list, framings, prompts, palette, Lighting; E-S7.1) and `Definitions/Presentation` (orientations,
FX, heat, viewport and stage values; E-S7.6). Roblox-bound: `ItemRender/ItemModelBuilder`, server
`World/{WorldBuilder, PlotWorld}` and `ShowcaseService`, client `Smithy/{PromptController, StationStage, StationFx,
InspectPanel, PlotPresence}`. PlotWorld's callers are listed in §1.3 L4; `Main.*` wire signals
(`PromptController.Triggered: Signal<(kind, plotIndex, slotIndex)>` → §12). `DT.StationId = "DraftingTable" |
"Furnace" | "Anvil" | "Grindstone"`. Instances, attributes and tags are PascalCase.

### 13.2 World layout

Plot i (1..`PLOT_COUNT` 8): `φ_i = (i − 1)·360°/8` counter-clockwise from +Z seen from above, centre `(R·sin φ_i,
0, R·cos φ_i)` with `R = PLOT_RING_RADIUS` 86, `plotCF_i = CFrame.new(centre_i) * CFrame.Angles(0, rad(φ_i), 0)`, so
plot-local −Z faces the plaza; ground top y = 0; square plots, `PLOT_SIZE` 40 (distances E-S7.2). Eight smithies
in a ring around a plaza **[Decision to confirm]** (Q2).

```lua
-- World/Layout.luau (pure); Vec3 = Schema.Vec3
export type Pose = { pos: Vec3, yaw: number }                -- upright, yaw in degrees about +Y
export type Framing = { eye: Vec3, at: Vec3, fov: number }   -- world space
Layout.plotPose(i: number): Pose
Layout.toPlotLocal(i: number, p: Vec3): Vec3
Layout.toWorld(i: number, p: Vec3): Vec3
Layout.stationPose(i: number, s: DT.StationId): Pose   -- root, floor level
Layout.standPose(i: number, s: DT.StationId): Pose     -- smith's feet, facing the station
Layout.workPose(i: number, s: DT.StationId): Pose      -- workpiece pivot
Layout.framing(i: number, s: DT.StationId): Framing
Layout.cradlePose(i: number, slot: number): Pose       -- displayed item's bounds bottom-centre
Layout.homePose(i: number): Pose                       -- spawn and teleport target
Layout.isInsidePlot(i: number, p: Vec3, margin: number): boolean
Layout.plotAt(p: Vec3): number?
```
`isInsidePlot`: `l = toPlotLocal(i, p)`, true iff `|l.x|, |l.z| ≤ PLOT_SIZE/2 + margin`. `plotAt`: `θ =
deg(atan2(p.x, p.z)) mod 360`, `k = floor((θ + 22.5)/45) mod 8 + 1`; k if `isInsidePlot(k, p, 0)`, else nil.

### 13.3 Plot lifecycle, spawn, names

In the §1 lifecycle: boot → `WorldBuilder.build()` (collision group first); PlayerAdded, before any yield,
`PlotService.assign` (sets `RespawnLocation`) → `PlotWorld.claim`; ProfileLoaded → `ShowcaseService.renderAll`;
leaving → craft abort → `unrenderAll` → profile release → `PlotWorld.release`. Players spawn only at their own
plot's `HomeSpawn`; with no free plot the player is kicked (there is no visitor-only mode).

```lua
-- server World/WorldBuilder, World/PlotWorld (RB)
WorldBuilder.build(): { plots: { { index: number, model: Model, spawn: SpawnLocation } } }
PlotWorld.claim(i: number, player: Player): ()   -- owner attributes, BS_PlotIndex, sign, forge lit
PlotWorld.release(i: number): ()                 -- stands emptied, vacant sign, forge cold
PlotWorld.teleportHome(i: number, character: Model): ()
PlotWorld.setActivity(i: number, step: DT.StepId?, parts: { Schema.PartData }?): ()
export type SlotContent = { itemId: string, plan: RenderPlan.RenderPlan?, rarity: DT.RarityId, name: string }
PlotWorld.setSlot(i: number, slot: number, content: SlotContent?): number   -- returns the new Rev
PlotWorld.setLabel(i: number, slot: number, itemId: string, rev: number, text: string): ()
```
`HomeSpawn`: one invisible, non-colliding `SpawnLocation` per plot, `Neutral`, `Duration` 0, top flush with the
floor at the home pose (plot-local (0, 0.5, −4), yaw 180°, facing the forge row). "My smithy" sends
`Showcase.TeleportHome {}` (§10.2) → `teleportHome`: `PivotTo(home + (0, HipHeight + RootPart.Size.Y/2, 0))` (R15).

Sign: `"<DisplayName>'s Smithy"` (vacant `"Vacant Smithy"`), subtitle `"@<Name>"` unless equal. Item names shown
to anyone are §10.8's filtered text, else `InspectView.defaultName(item)` while pending or failed. Player text never
goes into `Instance.Name`, another attribute than `ItemName`, logs or telemetry; its labels set `RichText` and
`AutoLocalize` false.

### 13.4 Plot build

102 parts per plot (57 colliding): shell 49, `HomeSpawn` 1, stations 28, stands 24 (tree and Build list E-S7.1).
`STEP_STATION = { Smelting = "Furnace", Hammering = "Anvil", Sharpening = "Grindstone" }` (**Phase 2 hook:** new
stations on reserved floor). `DISPLAY_SLOTS = 6` stands **[Decision to confirm]** (Q20) at plot-local x ∈ {±3.5,
±8.5, ±13.5}, z = −9, facing the plaza, keyed `DISPLAY_SLOT_KEYS = {"D1" … "D6"}` in `smithy.displays` (§9.3); an
item's bounds bottom-centre sits `CRADLE_HEIGHT` 1.55 above the stand base.

Clients bind only through tags (`BS_Plot`, `BS_Stand`, `BS_Prompt`, `BS_Flicker`, `BS_RarityFx`) and attributes:
plot `PlotIndex`, `OwnerUserId` (0 = vacant), `OwnerName`, `OwnerDisplayName`, `StationActivity` ("" or
StationId); station `StationId`; stand `SlotIndex`, `ItemId`, `Rarity`, `ItemName` ("" = empty), `Rev` (+1 per
change); player `BS_PlotIndex`; prompt `PromptKind`. Rules:
- Every `Light`, `ParticleEmitter`, `Fire`, `Smoke` is a direct child of a `BasePart` or `Attachment`.
- Parts are anchored, `Locked`, `CanTouch` false. Structure collides and is queryable; decor and `HomeSpawn`
  neither; item and workpiece parts neither but cast shadows; the invisible `InspectHitbox` is queryable only.
- Group `BS_Characters` does not self-collide and holds every character part: players never block each other
  **[Decision to confirm]** (Q2).

### 13.5 Interactions

| Prompt | ActionText / ObjectText | Distance | Enabled for | Opens |
|---|---|---:|---|---|
| Draft | Draft / Drafting table | 7 | owner, not in a stage | editor (§11) via `StationStage.enter(i, "DraftingTable")` |
| Forge | Forge / Anvil | 7 | owner, not in a stage | forge flow (§12) |
| Display | Display an item / Empty stand | 8 | owner, empty stand | item picker (§12) |
| Inspect | Inspect / `ItemName` | 8 | everyone, occupied stand | inspect panel (§13.10) |

Distances are `STATION_PROMPT_DISTANCE` and `DISPLAY_PROMPT_DISTANCE`. The server sets texts; attributes and
`PromptController.setSuppressed(reason, on)` set `Enabled` locally; every action is a re-validated request
(§10.2). An occupied stand's `InspectHitbox` (item bounds + `INSPECT_PAD` 0.3 per side, ≥ `INSPECT_MIN_THICKNESS`
0.8) also opens the panel (`ClickDetector` at `INSPECT_CLICK_DISTANCE` 24, hover `Highlight`). One Forge prompt: the
client walks the smith and the camera between stations, and visitors see it all **[Decision to confirm]** (Q20).
`PlotPresence` (`plotAt` at `PRESENCE_HZ` 4) shows §12's entry toast once per visit.

### 13.6 Station stage, activity, workpiece

```lua
StationStage.enter(plotIndex: number, station: DT.StationId, onArrived: (() -> ())?, instant: boolean?): ()
StationStage.leave(): ()
StationStage.current(): DT.StationId?
```
`enter` suppresses prompts, walks the smith to the stand point and tweens a `Scriptable` camera to
`Layout.framing` (a cut if `instant` or reduced motion, `UI/Motion.reduced()` §12.11; timings E-S7.6), setting `Camera.Focus` every frame; then
`onArrived()` (no step clock runs during a move). `leave` returns the camera to `Custom`; character loss →
`leave()` (the server aborts, `CharacterLost`).

CraftService (§7.6) calls `PlotWorld.setActivity(i, step, parts)` at each step start (snapshot parts) and
`(i, nil)` at the end or on abort: it sets `StationActivity` and raises the station FX; each viewer's `StationFx` adds anvil sparks (the owner's
per real strike, `StationFx.strike()`) and the spinning wheel (E-S7.6). The workpiece (server, scale 1) is one
ingot per distinct material at the furnace, then the item in `FLAT` (Center) on the anvil face and against the
wheel (poses E-S7.6). `setHeat(model, h)`, h = `WORKPIECE_HEAT[step]`: `Color = lerp(base, HEAT_COLOR,
HEAT_BLEND·h)`, `Neon` if `h ≥ HEAT_NEON_THRESHOLD`, `Reflectance = base·(1 − h)`, and for h > 0 one PointLight
(Range `HEAT_LIGHT_RANGE` 8, Brightness `HEAT_LIGHT_BRIGHTNESS·h`).

### 13.7 Item rendering

Stands (`STAND`, BaseCenter) and workpieces (`FLAT`, Center) render on the server, viewports in `VIEW_H` (Center),
the editor (§11) per part via `RenderPlan.primitive`. Shapes map one to one (§3.2): `Part.Shape =
Enum.PartType[shape]`, `Size = size` as stored, always class `Part`; rotation only via `Quat.toMatrix(rot)` (§3.4)
→ `CFrame.new(x, y, z, R00 … R22)`; look from the `Materials` row's `color`, `robloxMaterial`, `reflectance` (§2).
Only the builder creates item Parts; it never yields, builds unparented and parents once.

Bounds (`p` centre, `R` columns = local axes, `h` half size): polyhedra, min/max of `p + R·v` over the vertices
(Block 8 corners; Wedge (±hx, −hy, ±hz), (±hx, hy, hz); CornerWedge (±hx, −hy, ±hz), (hx, hy, −hz)); Cylinder
`p_i ± (|a_i|·hx + r·√(1 − a_i²))`, `a` = first column, `r = min(hy, hz)`; Ball `p_i ± min(hx, hy, hz)`. Anchors
`BaseCenter = (cx, minY, cz)`, `Center`, `Origin`; primitive position `scale·(p − anchor)` (fixtures: E-S7.4).

| Orientation | Blueprint +X / +Y / +Z become | R00..R22 |
|---|---|---|
| `STAND` | stand −X / up / −Z (toward the viewer) | −1,0,0, 0,1,0, 0,0,−1 |
| `FLAT` | station +Z / +X / up | 0,1,0, 0,0,1, 1,0,0 |
| `VIEW_H` (= editor Flat view) | down / right / toward the camera | 0,1,0, −1,0,0, 0,0,1 |
| `VIEW_V` | right / up / toward the camera | identity |

A stand shows the +Z face, +X on the viewer's right, upright at true size **[Decision to confirm]** (Q20).

```lua
-- ItemRender/RenderPlan.luau (pure)
export type Anchor = "BaseCenter" | "Center" | "Origin"
export type RenderPrimitive = { partId: number, slot: DT.SlotId, shape: DT.ShapeId, material: DT.MaterialId,
	size: Vec3, cf: { number },        -- scaled; cf = x, y, z, R00..R22 from the plan pivot
	color: DT.RGB, robloxMaterial: string, reflectance: number }
export type Bounds = { min: Vec3, max: Vec3 }
export type RenderPlan = { primitives: { RenderPrimitive }, bounds: Bounds, slotBounds: { [DT.SlotId]: Bounds },
	anchor: Anchor, scale: number }
export type PlanError = "Empty" | "TooManyParts" | "BadShape" | "BadMaterial" | "NonFinite" | "BadSize"
RenderPlan.fromBlueprint(parts: { Schema.PartData }, opts: { anchor: Anchor?, scale: number? }?): (RenderPlan?, PlanError?)
RenderPlan.primitive(part: Schema.PartData, anchor: Vec3, scale: number): (RenderPrimitive?, PlanError?)
-- ItemRender/ItemModelBuilder.luau (-- @roblox-bound)
export type Orientation = "STAND" | "FLAT" | "VIEW_H" | "VIEW_V"
export type BuildOptions = { pivot: CFrame, name: string?, parent: Instance?, transparency: number? }
ItemModelBuilder.build(plan: RenderPlan, opts: BuildOptions): Model
ItemModelBuilder.buildPart(prim: RenderPrimitive, pivot: CFrame): Part
ItemModelBuilder.applyPrimitive(part: Part, prim: RenderPrimitive, pivot: CFrame): ()
ItemModelBuilder.placeholder(pivot: CFrame, parent: Instance?): Model      -- grey PLACEHOLDER_SIZE block
ItemModelBuilder.setHeat(model: Model, heat: number): ()
ItemModelBuilder.applyRarityFx(hitbox: BasePart, model: Model, rarity: DT.RarityId): ()
ItemModelBuilder.mountInViewport(vp: ViewportFrame, plan: RenderPlan, o: Orientation): (Model, Camera)
```
Defaults Center, scale 1. Checks in order: count (`Empty`; > `Limits.MAX_PARTS` → `TooManyParts`), shape,
material, finite numbers, each size in [MIN_DIM, MAX_DIM] (`BadSize`). Canonical data never fails; on an error the
caller builds `placeholder` and logs `RenderFailed`; server builds run under `pcall`. Parts are named
`P%02d_<slot>` with attribute `PartId`; models carry `ItemId` and `Rarity`.

Viewports: a `WorldModel`, model at the origin, default `Sky`; camera on +Z, `VIEWPORT_FOV` 30,
`d = ez + m·max(ex/(a·tan(φ/2)), ey/tan(φ/2))` (`e` half extents on screen x, y and depth, `φ` vertical FOV, `a`
aspect, `m = VIEWPORT_MARGIN` 1.08). Turntables orbit the camera. No lights or particles render there: rarity is
§12's frame colour. **Phase 4 hook:** welded mode to hold an item.

### 13.8 Rarity presentation

Rare and above get a `RarityLight` (no shadows), Epic and above `RaritySparkles` (`Shape` Box, `ShapeStyle`
Volume), both direct children of `InspectHitbox`; the band glows Neon from Uncommon up; Legendary and above add a
Highlight on the Item (data only in the MVP; values E-S7.6). Colour: the `Rarities` row's `color` (§2), also on
the nameplate. Item parts are never recoloured.

### 13.9 Display slots

The `Showcase.Place` and `Showcase.Clear` handlers (§10.2) first refuse a live craft (`E_SESSION_ACTIVE`) and a player
outside `Layout.isInsidePlot(own plot, root, PLOT_INTERACT_MARGIN 6)` (`E_TOO_FAR`); `Showcase.Scrap` has neither
check. Rules: own items only; an item shown elsewhere **moves**; an occupant is **swapped** out (a display is a
reference); slots above `unlockedSlots(level)` (6 at every MVP level) are `SlotLocked`; Scrap clears the item's stand
first.

```lua
-- Showcase/ShowcaseRules.luau (pure)
export type SlotView = { string }           -- dense, length DISPLAY_SLOTS, "" = empty
export type Code = "Ok" | "NoChange" | "BadSlot" | "SlotLocked" | "BadItem" | "NotOwned"
ShowcaseRules.fromStore(displays: { [string]: string }): SlotView   -- smithy.displays {D1..D6 -> ItemId}
ShowcaseRules.toStore(view: SlotView): { [string]: string }
ShowcaseRules.place(view: SlotView, unlocked: number, slotIndex: unknown, itemId: unknown,
	owns: (string) -> boolean): (Code, { number })                  -- mutates view; changed slots
ShowcaseRules.clear(view: SlotView, unlocked: number, slotIndex: unknown): (Code, { number })
ShowcaseRules.removeItem(view: SlotView, itemId: string): { number }
ShowcaseRules.sanitize(view: SlotView, unlocked: number, owns: (string) -> boolean): { number }
ShowcaseRules.unlockedSlots(smithyLevel: number): number
-- server/ShowcaseService.luau (RB)
export type ShowcaseCode = Code | "Empty" | "NotLoaded"        -- Empty: inspect of an empty stand
ShowcaseService.renderAll(player: Player): ()                  -- sanitize, then render every stand
ShowcaseService.unrenderAll(player: Player): ()
ShowcaseService.place(player: Player, slotIndex: number, itemId: string): (ShowcaseCode, SlotView?)
ShowcaseService.clear(player: Player, slotIndex: number): (ShowcaseCode, SlotView?)
ShowcaseService.scrap(player: Player, itemId: string): (ShowcaseCode, SlotView?)   -- deletes the item
ShowcaseService.inspect(viewer: Player, plotIndex: number, slotIndex: number): (ShowcaseCode, InspectView?)
ShowcaseService.getItem(player: Player, itemId: string): (ShowcaseCode, Items.OwnerItemView?)  -- Items/Views.owner
ShowcaseService.refresh(player: Player, itemId: string): ()    -- after a lazy recompute
```
`slotIndex` must be an integer in 1..DISPLAY_SLOTS (0, 7, 1.5, "1" → `BadSlot`); `itemId` a non-empty string
(`BadItem`; the Guard checks the GUID, an unknown id is `NotOwned`). `sanitize` drops and logs unknown keys,
non-strings, unowned ids, duplicates (lowest slot wins) and locked slots. Wire `displays` and summary slot numbers
come from `fromStore`; §10.3 maps the codes.

No step yields, so requests apply in arrival order:
```
rules -> DataService.mutate(displays <- toStore(view); Scrap also deletes the item)
each changed slot k:  name <- TextFilter cached text, else InspectView.defaultName(item)
                      rev <- PlotWorld.setSlot(plot, k, {itemId, plan, rarity, name})   (pcall; plan nil = placeholder)
                      cache miss: TextFilter request -> onReady(text) -> PlotWorld.setLabel(plot, k, itemId, rev, text)
reply (code, view)
```
`setSlot` rebuilds the Item (at `cradle * STAND`), InspectHitbox (from `plan.bounds`), FX, band, nameplate and
prompt texts, sets `ItemId`, `Rarity`, `ItemName` and `Rev += 1`; nil empties the stand. `setLabel` writes
`ItemName`, nameplate and `ObjectText` (bumping `Rev`) only while `ItemId` and `Rev` equal the captured pair, so a
late filter result never repaints a changed stand. A stale item (`Recompute.isStale`, §9.4) shows its
stored record at once and is queued with `DataService.refreshItem` (§9.7); `refresh` re-renders it.

### 13.10 Inspect

Opened by the stand prompt, a click on the item or the owner's inventory (§12, built client-side, raw name);
replies cached per `(itemId, Rev)`. It closes on Esc, distance > `INSPECT_AUTOCLOSE_DISTANCE` 16 or a new `ItemId`
on the stand, and is disabled in a stage. Content (layout E-S7.6): rotatable preview (clone of the stand's Item),
name, rarity, "Forged by <DisplayName> (@<Name>) · <date>", materials, Mass, Balance point, Reach, stats, a
**Forging record [Decision to confirm]** (Q20: per step tier, score %, PASS / FAIL / NO INPUT, then quality and
rarity cap), owner buttons Swap…, Take down. Quality `floor(Q·100 + 0.5)`, score `floor(score·100 + 0.5)` %, stats
by the `Stats` rows' `unit`/`decimals`.

```lua
-- Showcase/InspectView.luau (pure); Net/Protocol re-exports it. No parts, flags or seeds.
export type Crafter = { userId: number, displayName: string, name: string }
export type InspectView = {
	v: number,                                             -- INSPECT_VIEW_VERSION = 1
	itemId: string, plotIndex: number, slotIndex: number,  -- 0, 0 from the inventory
	name: string,                                          -- filtered or fallback (raw only for the owner)
	equipmentType: DT.EquipmentTypeId, rarity: DT.RarityId, rarityCap: DT.RarityId, capStep: DT.StepId?,
	quality: number, createdAt: number, balanceVersion: number, crafter: Crafter,
	materials: { { slot: DT.SlotId, materials: { DT.MaterialId } } },   -- slot order, then Materials order
	physics: { mass: number, balance: number, reach: number },
	stats: { { id: DT.StatId, value: number } },                        -- Stats order
	history: { { step: DT.StepId, tier: DT.TierId, score: number, passed: boolean, timedOut: boolean } },
}
export type InspectContext = { name: string, crafter: Crafter, plotIndex: number, slotIndex: number }
InspectView.fromItem(item: Items.OwnerItemView, ctx: InspectContext): InspectView   -- the server passes Items/Views.owner(item)
InspectView.defaultName(item: Items.ItemRecord): string     -- "Steel Sword", "Iron-Steel Sword"
```
`fromItem` alone reads item fields (§9 Item record); ≈ 0.9 KB (E-S5.7 model). `defaultName`: the distinct Blade
materials in Materials order joined by "-", then the type. MVP crafter = owner (**Phase 4 hook:** other crafters).
**[Decision to confirm]** (§17): displayed items and workpieces are replicated Parts, so a modified client can copy a
design; the MVP accepts it, with "Forged by" as attribution.

### 13.11 Look, audio, budgets

Built-in materials only, no MaterialVariant, SurfaceAppearance, mesh or decal (palette, Lighting, FX: E-S7.1; platform facts: E-S7.7).
`ClockTime` 17, golden hour, no cycle **[Decision to confirm]** (Q20). `Definitions/World.LIGHTING_FX` names the
Lighting children (`BS_Atmosphere`, `BS_Grade`, `BS_Bloom`, `BS_SunRays`) for the editor. Owned plots glow (the
furnace light is the only shadow caster), lanterns flicker client-side (`base·(1 + FLICKER_AMPLITUDE·
math.noise(t·FLICKER_FREQUENCY, seed))` at `FLICKER_HZ` 20 within `FLICKER_RADIUS` 80); vacant plots are cold. Audio (Q20): `StationFx`
plays the `Definitions/Audio` cues `FurnaceLoop` and `GrindLoop` (§12) in 3D on the active station.

Budgets (E-S7.3): 946 static parts, worst case 2 338; ≤ 96 PointLights, ≤ 72 emitters. `StreamingEnabled` is false
(§1): no `ModelStreamingMode` writes, no `RequestStreamAroundAsync`. **Phase 2 hook:** with streaming on, server
code alone sets `Atomic` on Shell, stations, stands, Item and Workpiece.

### 13.12 Contracts, failures, tests

The editor's stage (§11) is the reserved 256-stud cube at `EDITOR_STAGE_ORIGIN` (0, 1000, 0). §12 owns fonts,
colours, chrome, toasts and the item picker; §13 the inspect content and rules. An owner leaving mid-craft ends the
session, then `release` clears the plot and visitors' panels close; an unreadable snapshot shows the placeholder,
the stand stays usable. Tests (§14): T-WLD, T-RND, T-SHW, T-INS, Studio checks; cases E-S7.5. S8's `cameraShot` needs named framings for
S-VIS-01…09 beyond `Layout.framing`; S7 names them in the build (§17.2).

---

## 14. Testing and verification

> **Principle.** Everything that decides an outcome is pure Luau in `src/shared` and runs under Lune on every change.
> Studio is used only for what needs the engine: remotes, the ProfileStore lifecycle, the world, UI and engine parity.

### 14.1 Layers and gates

| Layer | Scope | Command | When | Gate |
|---|---|---|---|---|
| L0 Static | luau-lsp, meta rules (§14.4) | `lune run scripts/verify` | every change | 0 errors, ≤ 20 s |
| L1 Unit/property | pure modules (§14.6) | `lune run tests/run -- --quick` | every change | all pass, ≤ 30 s |
| L2 Golden | fixtures, outcomes, BALANCE guard (§14.9) | part of L1 | every change | no diff unless `BALANCE_VERSION` bumped |
| L3 Statistical | bands, false positives, rarity (§14.8) | `lune run tests/run` (adds `t.slow`) | milestone exit, before a playtest, any change in `Minigames/`, `Crafting/` or their Definitions | all pass, ≤ 10 min |
| L4 Studio | §14.10 | Studio MCP procedure | milestone exit, before a playtest | 3 fresh Play sessions green, ≤ 10 min |
| L5 Playtest | §14.12, §14.13 | M-01…M-09, telemetry | per playtest | Definition of Done |

Ids: `T-` Lune, `S-` Studio, `M-` manual. No CI server: the gate runs locally before every commit to `main`.

### 14.2 Layout and the test project

`tests/`: `run.luau`; `lib/` (Test, Assert, Prop, TestRng, Dump, Golden, Gen, Cheats, Tol; requires nothing in `src/`,
specs pass modules in); `<Folder>/*.spec.luau` per `src/shared` folder plus `Pipeline/`, `Meta/`; `fixtures/` (§14.7);
`golden/` (`<name>.bv<N>.golden.txt`, `.digest.txt` ≤ 1 KB for Studio); `studio/{bridge, e2e, reference}`. Also
`scripts/verify.luau` (sourcemaps → T-META-07 → luau-lsp → tests) and `tools/` (globalTypes, runner self-test,
`telemetry_csv.luau`). **`test.project.json` is self-contained**: S5's tree maps only `$path` nodes (Remotes from
`src/shared/Remotes.model.json`, ProfileStore from the nested `src/server/Vendor/ProfileStore.project.json`), so the
file is hand-written: every node and `$properties` of `default.project.json`, plus `ReplicatedStorage.BlacksmithTests
.{lib, fixtures, golden}`, `ServerScriptService.BlacksmithTestServer` and `StarterPlayerScripts.BlacksmithTestClient`
(E-S8.2). Never published; Studio reads digests only (StringValues hold at most 200,000 characters).

### 14.3 Runner and test library

```
lune run tests/run [-- --quick | --filter <text> | --seed <n> | --bless | --list | --root <dir>]
lune run scripts/verify [-- --quick]          -- Lune 0.8.9: script arguments must follow "--"
```

`tests/run` exits 0, 1 (a `FAIL` assertion or `ERROR` crash) or 2 (harness: not at the repo root, bad argument, no
specs, a spec fails to load or returns no suite, duplicate suite, empty filter); `scripts/verify` exits 0, 1 (tests),
2 (harness, sourcemap, T-META-07), 3 (luau-lsp), 4 (missing tool). Discovery: `tests/**/*.spec.luau` except `lib/` and
`studio/`, byte-wise order, one uniquely named suite per spec, each case in `xpcall`; a case over `CASE_BUDGET_MS`
(`SLOW_CASE_BUDGET_MS` for `t.slow`) fails. Runner and specs share one `Prop`/`Golden` instance (module cache), which
carries `--seed` and `--bless`. Lune facts relied on: E-S8.1.

```lua
Test.suite(name: string, body: (t: {it: Case, slow: Case, skip: Case}) -> ()): Suite   -- A.eq/near/…/fail raise "assert:"
Prop.check<T>(n: number, gen: (rng: TestRng) -> T, property: (T) -> ())   -- failure prints case seed + Dump
TestRng.new(seed: number): TestRng   -- xorshift32 + Irwin–Hall, independent of Minigames/Rng
Dump.canonical(v: any): string       -- sorted keys, %.17g, −0 → 0;  Golden.check(name: string, value: any)
```

`Gen` builds swords and garbage; `Cheats` builds the §14.8 cheat inputs with the passed-in `Minigames` (E-S8.5).

### 14.4 Static analysis and meta rules

`aftman.toml` pins lune 0.8.9, rojo 7.7.1, luau-lsp ≥ 1.67.0 (1.70.1); `globalTypes.None.d.luau` (pinned tag's
`scripts/` folder) is committed; `.luaurc` is strict.

```
rojo sourcemap default.project.json --include-non-scripts --output sourcemap.json
rojo sourcemap test.project.json --include-non-scripts --output test.sourcemap.json
luau-lsp analyze --platform=roblox --sourcemap=test.sourcemap.json --definitions:@roblox=tools/luau-lsp/globalTypes.None.d.luau --ignore="vendor/**" --formatter=plain src tests/studio
luau-lsp analyze --platform=standard --ignore="tests/studio/**" --formatter=plain tests
```

Any error fails (exit 3); `UnknownGlobal`, `DeprecatedApi` and `ImplicitReturn` lints must be fixed.

| Id | Rule (token scans skip strings and comments) |
|---|---|
| T-META-01 | every `.luau` under `src/` and `tests/` starts with `--!strict` |
| T-META-02 | a `src/shared` file is pure unless line 2 is `-- @roblox-bound` and it is on the `tests/Meta` allowlist (`Net/Remotes`, `Net/Client`, `Util/Signal`, `ItemRender/ItemModelBuilder`); pure files use none of `game workspace script Instance.new Vector3 CFrame Color3 Random.new math.random os.time os.clock os.date tick( DateTime task. wait( print warn`, no other Roblox datatype (`Enum Vector2 UDim UDim2 Rect Ray Region3 BrickColor TweenInfo NumberRange NumberSequence ColorSequence PhysicalProperties RaycastParams OverlapParams Font`) and no `init.luau`, and require no `@roblox-bound` file |
| T-META-03 | `Blueprint/ Physics/ Minigames/ Crafting/ Pipeline Items/ Session/` use no `math.sin cos tan exp log pow atan asin acos` and no `^`, except lines tagged `-- allow-transcendental: <reason>` |
| T-META-04 | the same folders never accumulate floats while iterating a keyed table |
| T-META-05, 06 | runner self-test (`tools/runner-selftest/{pass, fail, broken}` exit 0 / 1 / 2); no `:Reconcile(` in `src/` |
| T-META-07 | require resolver, before any spec loads: each string require in a Rojo root resolves to the same module on disk (Lune) and in both sourcemaps (Roblox rules, E-S8.1); fails on unresolved or mismatched requires, crossing a Rojo root, `tests/lib` → `src/`, or a cycle |
| T-META-08 | `test.project.json` = every node and property of `default.project.json`, unchanged, + exactly the 3 test nodes |

### 14.5 Generic properties (every public pure function)

P-DET same input → deep-equal output, bit-identical numbers · P-NOMUT inputs unchanged · P-TOTAL untrusted input
returns an error, never throws (`FUZZ_N_GARBAGE` values) · P-FINITE · P-RANGE normalized outputs in [0, 1] ·
P-ORDER Definitions maps rebuilt in shuffled order leave results bit-identical · P-PURE loads under Lune.

### 14.6 Module test plans

One suite per pure module of §1's module map [owner]; every case of every id: E-S8.5.
T-DEF-00…07 `Definitions/*`, all 19 [S1; values S2–S7] (T-DEF-00: `Validate.validateAll() == {}` + one planted error
per check) · T-UTIL-01 `Util/Quantize` [S1] · T-BP-01…05, 12, 13 `Blueprint/{Schema, Canonical, Quat, Names, Views}`
[S1], T-BP-11 `Mirror` [S2], T-BP-14 `WorkSet` [S4] · T-UD-01 editor transforms survive Save → load bit-identically ·
T-VAL-01…04, T-PHY-01…10, T-EDG-01, T-DIF-01…13 `Physics/{Analyze, Gjk, Shapes, Sampling, MassProps, Edge, Factors,
Difficulty}` [S2] · T-PIPE-01 `Pipeline` [S2, S4] · T-RNG-01…06, T-MG-01…16 `Minigames/*` incl. facade and `Bots` [S3] ·
T-CR-01…10 `Crafting/*` [S4] · T-ITM-01…03, T-PER-01…06 `Items/*`, `Persistence/*` [S1] · T-SES-01…38
`Session/SessionMachine` [S5] (S5's 37 scenarios on a fake clock + every row of §7's step outcomes) · T-ED-01…09
`EditorCore/*`, all 10 incl. `Keymap` and `Config` [S6] · T-WLD-01, 02, T-RND-01, T-SHW-01, T-INS-01 `World/Layout`, `ItemRender/RenderPlan`,
`Showcase/*` [S7] (S7's §13 list) · T-NET-01…04 `Net/{Protocol, Guard, RateLimit}` [S5] (50,000 hostile payloads per
validator, 0 throws).

Contract tests other sections rely on:
- **T-PHY-09** Dust and Enclosed only, duplicates Enclosed with the lowest id kept among copies of one slot and material,
  partial overlaps kept, a verdict on each side of `ENCLOSED_EXPOSED_MAX`; each of §4.4's reading rules on a design worked by
  hand; ids decide nothing (any order of a design's parts, the same exposure by id, to the bit), and the hider-first order
  changes no bit; K + F measures as K alone, also past `N_SURF_WORK` and `N_SUB_WORK`; and, against a truth oracle on a
  sweep of plausible designs (E-S2.11, fullers, combs and walled blades among them), nothing that shows 10 % is cleaned and
  nothing under 0.25 % kept.
- **T-DIF-03** D = 0.1999999999 is Normal, 0.2 Hard. **T-DIF-04/05** enclosed parts, duplicates (not in a slot whose name
  comes before the original's: §4.4) and Iron ↔ Steel leave
  D bit-identical (while the kept set is unchanged, §17.2; the cases include C04 with a 0.075 blade + 9 enclosed blocks, C09 with a blade 0.05 longer + 6, C09 + a plate + hidden blocks, a laminated blade + a Dust hairline); dust gives \|ΔG\| ≤ TOL_DUST_G. **T-DIF-07** Y/Z translation and flush re-segmentation give
  \|Δx_f\| ≤ TOL_FACTOR_ABS, \|ΔG\| ≤ TOL_G_INVARIANT; a design mirrored with the tool has Asymmetry ≤ TOL_ASYM_ZERO
  (X shifts and whole-sword rotations are real changes). **T-DIF-10** client analysis path = server path, 500 designs.
- **T-DIF-11** every fixture's tiers = §5; F5 has D ≤ 0.2 − STARTER_MARGIN on every step (Q7, Q21).
- **T-MG-11** Perfect at 30 fps ≥ PERFECT_30FPS_MIN_SCORE at every tier; TimingStrike full-points core ≥ 9 ms.
- **T-MG-14** a HIGH flag gives score = min(rawScore, pass line), `passed` = (rawScore ≥ pass line), rawScore kept for
  ScoreMismatch.
- L3: Perfect's mean rawScore over SOLVABILITY_SEEDS seeds per cell ≥ PERFECT_MIN_SCORE (HoldZone ≥
  PERFECT_HZ_MIN_SCORE, §6.13); Average's Normal → Hard mean drop ≥ TIER_MIN_MEAN_DROP and every other profile's
  drop positive; Iron − Steel mean in STEEL_MEAN_DROP (Q13); per-seed SD ≤ FAIRNESS_MAX_SD.

### 14.7 Fixtures

One set, all `PartData` (§3 Record schema) in blueprint space (origin = centre of the hitbox's bottom face), every
part ≥ 0.02 stud inside the hitbox: S2's calibration swords C01, C02, C04–C15, F1–F5, A01–A27, X01–X07, and the cost
fixtures X08 (S8, E-S8.4) and P1–P5 (S2, E-S2.8). **Expected D and tiers are S2's §5.5 table; expected physics and
factors are E-S2.9's tables**, blessed into goldens; S8 keeps no copy. Coordinates and the independent
oracle: E-S8.3; constructions and expected codes: E-S8.4.

- F1 ArmingSword (Iron hilt, two-part Steel blade, 45° tip) · F2 MinimalSword (one Iron Block per slot) · F3 Rapier
  (Steel, 0.035-stud blade: needs MIN_DIM ≤ 0.035, else F3 takes the new MIN_DIM) · F4 Cleaver (wide Iron blade
  offset to +X) · F5 StarterSword = F1 all Iron, the granted starter (Q21).
- A01–A24: one invalid or edge-case draft per S1 CanonError, S2 ValidationCode and wire code; A25–A27 hidden-grip
  variants; X01–X07 regressions of S2's measurement fixes; X08 cost cases; P1–P5 S2's cost fixtures (P1 the
  adversarial one, §4.9).

### 14.8 Player models, cheats and statistics

- **Profiles are S3's** (§6 Minigames/Bots), used verbatim: Perfect, Elite, Good, Average, Poor, Idle and S3's
  device variants; S8 defines none. Cheats: Exact, Fast, Flood, Malformed, Replay, Forged (E-S8.5).
- Bands: S3's per-(family × tier × material × profile) table and the Q8 fail targets, `BOT_RUNS` seeds per cell;
  T-CR-09 checks S4's rarity targets (Q12) on 2,000 crafts per row composed from the same distributions.
- False positives, thresholds read from `Definitions/MinigameFamilies` (no copies): TimingStrike
  `FP_RUNS_TS` runs per human profile (0 flags ⇒ < 1e-5 per step at 95 %); HoldZone and Trace `FP_RUNS` (Trace:
  `FP_RUNS` on the 30 fps / 360 px Elite device only, its other devices 1,000 runs as in E-S3.8) plus margins
  (smallest mean deviation ≥ 3 × `PT_PRECISE_MEAN_DEV`, that is 0.0024 u, where S3's humans measure ≥ 0.0028 u, ×3.5,
  over 3,000 runs, E-S3.8; most presses in 1 s ≤ `HZ_RATE_MAX_PRESSES` / 3), with a 30 fps / 360 px device and the
  pumping policy (E-S8.7).
- Each config seeds from `fnv1a32(config name)`, so L3 is pass/fail per code version, never flaky.
- Accepted risk (Q17): human-like synthetic timelines pass, so Epic is botable in the MVP (display-only items).

### 14.9 Goldens and the BALANCE guard

Goldens are `Dump.canonical` text per version (`<name>.bv<N>.golden.txt`); old versions stay for recompute tests.
**One guard**. T-BAL-01: `balance_fingerprint.golden.txt = {version, bytes, fnv1a32}` over exactly the
tables and fields `Definitions/Manifest` lists. Changed data with an unchanged version fails, even with `--bless`; a
bumped version fails a plain run and passes `--bless`; versions strictly increase. T-BAL-02: every Definitions
module is in the Manifest or its exclusion list (Network, World, Presentation, Audio, display fields). Changed
outcome code shows as a golden diff, which also needs a bump. Workflow: edit → bump `BALANCE_VERSION` →
`lune run tests/run -- --bless` → review the diff → commit.

### 14.10 Studio integration (L4)

**Preconditions.** `rojo serve test.project.json --port 34873` into the test place (confirm the instance) with Max
Players 8; ProfileStore Mock. The test place is the game's own place, Project 215, by the designer's choice
(2026-11-03). Checks run in Play sessions only and change nothing in Edit, and nobody edits in that window while one
runs. Rojo's sync does leave the test tree in the place's live session (`ReplicatedStorage.BlacksmithTests`,
`ServerScriptService.BlacksmithTestServer`, `StarterPlayer.StarterPlayerScripts.BlacksmithTestClient`), so it comes out
before the first publish (§14.12). Expected noise: S5's Max Players warning, ProfileStore's
API-services prints and `____PS` probe key. Snippets (`tests/studio/e2e/`) print one `[E2E] <id> PASS|FAIL <json>`
line per assertion and play at most one craft step per call.

**Test hooks**, active only with the bridge. S5: `Config.STRIKE_KICK = false`, `Lifecycle.simulateRejoinForTest`,
`Telemetry.since(seq)`, `Config.FIXED_SEED`, attribute `BS_DataMode = "Live"` (S-PAR-03 on the test experience only).
S6: `MinigameHost.setInputSource(fn)` and a read-only UI state. S7: named camera framings.

```lua
export type BridgeRequest = { cmd: string, args: { [string]: any }? }
export type BridgeResponse = { ok: boolean, data: any?, err: string? }
-- BindableFunctions ServerStorage.BlacksmithTest.Bridge and PlayerScripts.BlacksmithTest.Bridge
```

Commands (E-S8.6) include `call` (`NetClient.request`), `rawFire` (past the client throttle) and `autoplay`.
Procedure: `list_roblox_studios` → `get_studio_state` → `start_stop_play(true)` → `ping`, `waitReady`
(≤ E2E_READY_TIMEOUT_S) → scenarios → shots → `get_console_output` → stop; three fresh sessions, all green.

Scenarios (assertions: E-S8.6): S-E2E-01 boot · 02 join · 03 save parity (server summary = snippet `Pipeline.summary`
= digest = preview) · 04 hostile drafts · 05 protocol craft, S3's Good bot · 06 UI craft · 07 item record · 08
showcase · 09 rejoin · 10 hostile crafts · 11 busy, rate limit, timeout, desync · 12 real input · 13 plot fill
(optional); S-PAR-01 shapes · 02 Server = Client = Lune digest · 03 doubles · 04 live servers; S-VIS-01…09 shots.
**S-E2E-10** asserts every Invalid row of §7's step outcomes (Flood, Malformed, new-seed Replay, foreign session or
step, Fast): S5's code, craft aborted `InvalidInput`, no item, Hard strike; Exact passes at the pass line, flagged.

**Console hygiene:** fail on `^%[blacksmith:%l+%] ERROR ` (§10 Telemetry and logging) or an engine traceback; list
`WARN` lines; whitelist the expected noise.

### 14.11 Performance

| Id | Measure | Pass |
|---|---|---|
| T-PERF-01 | `Analyze.run`, X08 cost cases, S2's adversarial fixture P1, P1–P3 + a Dust speck, and the worst designs in `docs/spec/prototypes/S2/verdict/worst_P.json` (§4.9, Lune) | ≤ ANALYSIS_LUNE_MAX_MS; every checkpoint gap ≤ CHECKPOINT_GAP_LUNE_MS; P1 and those worst designs also reported against 29 ms (75 ms ÷ 2.6) |
| T-PERF-02 | longest legal timeline per family: decode + replay + checks; Trace `generate` on X08 | ≤ REPLAY_BUDGET_MS; ≤ PT_GENERATE_BUDGET_MS |
| T-PERF-03 | refusal of A15, A18 and oversize buffers | ≤ REJECT_BUDGET_MS |
| S-PERF-01 | Studio: AnalysisQueue (4 ms slices), PreviewScheduler (6 ms), same cases (P1, the specks and `worst_P.json` included); `Minigames.judge` in the Submit handler | total ≤ 75 ms on the F, C and X fixtures (§4.9), the rest reported against it; longest slice ≤ SERVER_SLICE_MAX_MS / CLIENT_SLICE_MAX_MS (E-S8.8) on all; judge time reported |

### 14.12 Acceptance criteria and Definition of Done

| MVP item (design draft, Phase 1) | Accepted when | Verified by |
|---|---|---|
| Editor: 4 slots, hitbox check, server validation | F1 built by hand (Q5); overflow shown live; server verdict = preview on all fixtures and 500 fuzzed designs; each hostile draft gets its code; autosave (Q6); mirrored designs measure symmetric | T-BP, T-VAL, T-ED, T-DIF-07/10, S-E2E-03/04/09, M-01/02 |
| Physics: mass, balance, reach | E-S2.9 physics = oracle (E-S8.3) within tolerance; invariances; engine parity, 5 shapes | T-PHY, S-PAR-01 |
| Materials: Iron, Steel | only these enabled; density sets mass; Steel: same D, tighter minigames, T = 1.02 (Q13) | T-DEF, T-DIF-05, T-MG, T-CR-06 |
| Steps: smelting, hammering, sharpening | solvable, in bands; FP sizes met; cheats caught; client = server; real input completes | T-MG, S-E2E-05/06/10/12 |
| Tiers: Normal, Hard | boundary exact; Hard ≥ 0.05 lower mean for Average, better rewarded (Q10, Q11); tiers = §5, F5 margin (Q7) | T-DIF-03/11, T-MG, T-CR-04/05 |
| Server-side seeded scoring and stats | seeds server-made, fixed on re-open; nothing client-sent trusted; items recompute to stored values; others see InspectView only | T-RNG, T-SES, T-CR-07, S-E2E-05/07/08/10 |
| Smithy with display slots | plot and spawn at join; place, clear, scrap; model = RenderPlan; persists, replicates; 8 join/leave cycles leave nothing | S-E2E-01/02/08/09/13, S-VIS-01/06/07, M-05 |
| First session (Q21) | Starter Sword granted once, forgeable at once; empty states; tracker; every audio cue has a visual twin | T-PER-06, S-E2E-02, M-03 |

**Definition of Done.** (1) `scripts/verify` exits 0 with `t.slow`. (2) S-E2E-01…12, S-PAR-01…03, S-PERF-01 pass in
3 consecutive fresh Play sessions, clean console. (3) The designer approves S-VIS-01…09. (4) **[Decision to
confirm]** (Q22): ≥ 3 testers, one new, finish the loop unaided within 20 minutes, 2 of 3 start a second sword
unprompted, the designer signs off that it is fun. (5) Playtest telemetry inside §14.13's targets, or retuned with
`BALANCE_VERSION` bumped. (6) M-06 with S-PAR-03/04. (7) No open severity-1 (crash, data loss, wrong authority,
exploit beyond §10's accepted risks) or severity-2 (blocked loop step) defect. (8) SPEC and README updated (Status,
build checklist incl. deletion template and Max Players 8). (9) The test tree (§14.10) is out of the place before its
first publish.

Manual checks (steps: E-S8.6): M-01 build F1 from a picture ≤ 10 min · M-02 explain an invalid sword from the UI ·
M-03 new player's first 3 swords · M-04 results card understood, offset button used · M-05 2 players, stands, live
forging · M-06 private test experience (own universe, live servers): rejoin on a new server intact, S-PAR-04 · M-07
4–8 players: no cross-talk, no `ERROR`, saves answered ≤ 2 s · M-08 trackpad and AZERTY · M-09 minimum-spec PC:
§11's editor acceptance, 30 fps minigames.

### 14.13 Balance telemetry

S5 owns the catalogue (§10 Telemetry and logging). Studio and private playtests: `[TLM] <json>` lines and the bridge
`telemetry` ring → `tools/telemetry_csv.luau` → CSV. Live: S5's AnalyticsService events and the onboarding funnel.
No raw DataStore sink, no persistent id (a per-join random `sid` groups a player's events). Targets
(`TLM_*` in `tools/telemetry_csv`) are **[Decision to confirm]** (§17.1 O3).

| Event (fields: E-S8.9) | Target | Tunes |
|---|---|---|
| BlueprintSaved | ≤ 20 % of x at ≥ 0.99 or ≤ 0.01; Hard 20–50 %; D in [0.18, 0.22] ≤ 1.5 × [0.14, 0.18] | S2 ranges, weights |
| StepScored | median in S3's Average band; Q8 fail bands; ±30 % of design duration; ScoreMismatch 0 | S3 parameters |
| CraftCompleted (`bp` = canonical blueprint hash) | S4's targets; cap-bound share reported (≈ 0 % at the reference designs, E-S4.7); no `bp` with median Q > 1.5 × its signature's (≥ 20 crafts) | S4 thresholds, S2 cleaning |
| AntiCheatFlag, CraftAborted, invalid saves, funnel | flags ≤ 0.1 % of steps; `Internal` aborts 0; abandons < 10 % per step; top code < 30 % of saves; 2 of 3 new players reach "item displayed" | S3, S6 |

Build-phase checks of tool and engine facts (V-01…V-09) are §17.2 engineering items.

---

## 15. MVP non-goals and phase hooks

Merged from every section; the owner is in brackets. A hook is what exists now that a later phase plugs into.

### 15.1 Not in the MVP

| Non-goal | Hook or reason |
|---|---|
| Stored input timelines, replays shown to visitors [S1, S3] | scores are frozen facts; `StepRecord` keeps `seed` and `score`; families are deterministic, so a replay archive is its own key later |
| Item rename [S1, S5]; non-Latin names; binary record encodings [S1] | `Names.sanitize` already accepts item names; the filter cache is keyed by raw text; one range-table line per script |
| Persistent player counters [S1] | telemetry covers them; a feature that needs one adds it by migration |
| RemoteFunction, UnreliableRemoteEvent, cross-server messaging, OrderedDataStore [S5] | one Router registry and 4 channels take new actions without new remotes |
| Persistent bans or item marks; resumable crafts [S5, S6] | `Router.strike`, `StepRecord.flags`; SessionMachine is plain data (`Craft.Resume` only covers a UI restart in the same server) |
| Parallel Luau Actors [S2, S5] | `Analyze.run` is re-entrant and checkpointed; `AnalysisQueue.run` keeps its job interface |
| Raw telemetry sink, Open Cloud export [S5, S8] | `Telemetry.emit` payloads, the `[TLM]` ring and `tools/telemetry_csv.luau` |
| Voxel or sample visualization, CSG, MeshParts, negative scale [S2] | mirroring is a rotation (§3.8) |
| Inertia and swing speed; thickness-direction (Z) asymmetry [S2, S4] | owned volume samples give ∫r² dm about the grip; `Blueprint/Mirror` already reflects across z = 0 |
| Edge chains stored on items [S2] | recomputed from the snapshot by `Pipeline.analyze` |
| Pause, gamepad, touch, key remapping beyond Space and LMB [S3, S6] | `Minigames/Input` takes logical button events; `EditorCore/Keymap` bindings are data; input contexts in `UI/InputRouter` |
| Per-(family, tier) pass lines [S3] | `passThreshold` is a family parameter with a tier column |
| Retrying a step, re-rolling a seed [S4] | retry = a new session (§7.3 R6); a re-open always returns the same seed |
| Editor extras left out of the MVP: per-axis snapping, absolute snap mode, user presets, scrubbing, editable delta badge, eyedropper, slot paint, auto-ortho, rulers, view triad, saved UI-scale and orbit settings, group scale, clipboard, part groups, per-part names, locking [S6] | `settings.snap` is per type, presets are data, `GizmoMath` already computes the selection pivot |
| A straight-bar TimingStrike view [S6] | the same `TimingStrikeView` feeds any view |
| Instance streaming, world-text localization [S7] | clients bind only through tags and attributes; only player text has `AutoLocalize` false |
| CI server, coverage or mutation tooling, pixel-diff screenshots, automated multi-client tests, load tests beyond one 8-player server [S8] | the local `scripts/verify` gate; S-VIS references in `tests/studio/reference/`; bridge `fillPlots` |

### 15.2 Phase 2: depth

- **Materials** Bronze, Mithril, Obsidian, Wood, Leather [S1, S2, S3, S4]: rows exist with `enabled = false`
  (`allowedSlots`, `class`); the `difficultyTerm` machinery is live at 0; a missing minigame material column means ×1;
  `qualityTier` placeholders 1.05 / 1.35 / 1.30 / 1.00 / 1.00, re-tuned with material costs.
- **Tiers** Expert, Master, Hell and rarities Legendary to Divine [S1, S2, S3, S4]: `tierRaw` is reported; enabling
  tiers lifts the enabled-prefix clamp; every minigame parameter has five tier columns; d, caps, φ and `minQuality`
  are data (`minQuality = d(tier) × Epic / d(Hard)`).
- **Steps** Casting, Quenching, Assembly, Finishing [S1, S2, S4, S7]: disabled `Steps` rows and weights, append-only
  `CraftPlans` (`Plan.fromHistory` renormalizes old records), the `STEP_STATION` map and reserved floor; Assembly first
  needs filler-proof Joints (for example `V_PART_FULL` raised from 0.004 to 0.01).
- **Hell failure** [S4, S5]: `failOutcome = "DestroyMaterial"`; materials would be debited at Begin so abandoning
  cannot dodge it; it needs the Phase 4 material economy, or Hell destroys the item instead (§17.3).
- **Stats** [S4]: swing speed, quench hardness/toughness bias, assembly balance term (`Balance.Stats[type]`,
  `StatInputs`; formulas sketched in E-S4.1).
- **Profile growth** [S1]: the Phase 2+ item shape measures 2.08 MB at 40 / 150, above `PROFILE_SIZE_BLOCK_BYTES`;
  deduplicate snapshots by `sourceId@sourceRevision` or page items into their own keys, then re-run the budget test.
- **Smithy growth** [S1, S7]: `smithy.level`, `ShowcaseRules.unlockedSlots(level)`, the `SlotLocked` code, wall space
  for racks and decorations; a cached geometry summary returns only if recompute cost demands it [S1].
- **Anti-cheat hardening** [S3, S5]: progressive pattern reveal with streamed inputs, HoldZone reaction-latency
  analysis, a Trace pixel-lattice check, cross-session statistics, a ≤ 2 Hz `Craft.Beat` slow-motion probe, a
  persistent strike count and flagged-item review (hooks: `MinigameResult.flags`, `StepScored`, ping sampling).
- **Engine and tooling** [S5, S7, S8]: an AnalysisWorker Actor if `Perf` telemetry asks for it; a read-only support
  view (`ProfileStore:GetAsync`); `Atomic` models if streaming is ever enabled; a raw telemetry sink with an Open
  Cloud export; bands, goldens, fixtures and milestones extend per tier, family and material.
- **Player features** [S3, S6, S7]: practice mode (the pure simulations run a local, unscored step), Epic-forge
  announcements and personal-best ribbons (§17.1), hotkey rebinding, group scale, day/night and weather (Lighting is
  `Definitions/World` data), display turntables and a forge "reveal".

### 15.3 Phase 3: breadth and social

- **Equipment types** Axe, Spear, Hammer, Armor [S1, S2, S4, S6, S7]: ids reserved in `Definitions/Types`; a type is
  one `EquipmentTypes.<Type>.geometry` row plus one `CraftPlans` entry and one `Balance.Stats` row; the editor stage,
  camera, gizmos, snapping and history are type-agnostic; armor zones reuse §4's surface samples against zone shells;
  mannequin stands reuse `ShowcaseRules`.
- **Blueprint sharing** [S1, S6]: records are self-describing through `schema`; snapshots keep `sourceId`;
  cross-player references as `"<UserId>/<ItemId>"`.
- **Likes, categories, rankings, history card** [S1, S4, S5, S7]: a separate small store per item or one
  OrderedDataStore per category (never the profile key, which the 2 MB size block already caps, §9.8), batched under
  `OrderedWrite` 30 + 5 × players/min; `InspectView` already carries quality, rarity cap and the step history; "Master
  craft" and "Hell forged" read the frozen step facts.
- **Visits** [S1, S5, S7]: offline and cross-server smithies through `ProfileStore:GetAsync` view mode, with a
  broadcast-filtered copy of item names persisted while the owner is online (filtering needs the author present);
  `PlotWorld.setSlot` takes plain content, so a vacant plot can show any profile's displays.

### 15.4 Phase 4: use and economy

- **Material sourcing** [S1, S4]: an `inventory` field added by a `DATA_VERSION` migration; materials commit at Begin
  (§7.3 R7) with no refund on abandon.
- **Items in combat or on a test dummy** [S2, S7]: a welded `ItemModelBuilder` mode pivoting on `physics.gripPoint`
  with `physics.gripAxis` as +Y.
- **Other crafters in "Forged by"** [S7]: `InspectView.crafter`, `UserService:GetUserInfosByUserIdsAsync`.
- **Trading** [S1, S5]: atomic two-profile transfers on GUID item ids; revisit right-to-be-forgotten then.

---

## 16. Constants reference

Every tunable and fixed constant, merged from the sections, one table per Luau module in layer order. A row may
hold a small group of coupled constants as their owner wrote them; no constant appears twice. Values here are the
ones the text uses; Owner names the section that sets the value.

### 16.1 `Definitions/Versions`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `DATA_VERSION` | 1 | — | S1 | Profile.Data layout; +1 with a migration for every structural change |
| `BLUEPRINT_SCHEMA` | 1 | — | S1 | blueprint format of records, drafts and snapshots |
| `BALANCE_VERSION` | 1 | — | S1 | +1 with any outcome-affecting data (Manifest) or code change |

### 16.2 `Definitions/Limits`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `POS_ABS_MAX` | 16 | stud | S1 | per component; keeps every part inside S6's ×4 editor stage |
| `MIN_DIM` | 0.02 | stud | S1 · value S2 | smallest side S2 measures cleanly (E-S2.2); at most 0.05 [Decision to confirm] (Q4) |
| `MAX_DIM` | 6.0 | stud | S1 · value S2 | > hitbox diagonal 5.28; bounds sample counts |
| `EPS_CONTAIN` | 1e-4 | stud | S1 · value S2 | float noise on parts flush with the hitbox wall |
| `CONTACT_TOL` | 0.01 | stud | S1 · value S2 | connectivity distance; chord merging |
| `MAX_PARTS` | 24 | parts | S1 | structural cap = Sword part limit (S2); budgets and S7's render cap use it |
| `MAX_PART_ID` | 65535 | — | S1 | part id range; the editor's id counter starts at max + 1 (§11.5) |
| `QUAT_NORM_TOL` | 1e-9 | — | S1 | renormalize only above it: idempotent, editor quaternions untouched |
| `QUAT_INPUT_TOL` | 1e-2 | — | S1 | reject wire quaternions further from unit (client bug, zero, overflow) |
| `NAME_MIN_CP` | 1 | code points | S1 | no empty names |
| `NAME_MAX_CP` | 32 | code points | S1 | fits a plaque; ≤ 64 bytes with the Latin set |
| `NAME_MAX_INPUT_BYTES` | 256 | bytes | S1 | cheap rejection before parsing |
| `MAX_ISSUES_STORED` | 8 | entries | S1 | `analysis.issues` kept per blueprint |
| `MAX_STEP_FLAGS` | 10 | flags | S1 | ≥ the 9 flag kinds (S3's 7, S5's LateSubmit and ScoreMismatch), so no flag is dropped |
| `MAX_BLUEPRINTS` | 40 | records | S1 | worst profile 43.5 % of the key [Decision to confirm] (Q18) |
| `MAX_ITEMS` | 150 | records | S1 | same budget; scrap frees a slot [Decision to confirm] (Q18) |
| `MAX_UI_FLAGS` | 64 | entries | S1 | bounds `uiFlags` (worst 2,561 B) |
| `UI_FLAG_KEY_MAX_BYTES` | 32 | bytes | S1 | bounds `uiFlags` keys |
| `DATASTORE_VALUE_LIMIT` | 4194304 | characters | S1 | Roblox per-key value limit; the budget test targets ≤ 50 % |
| `KEY_WRITE_BYTES_PER_MIN` | 4000000 | bytes/min | S1 | Roblox per-key write throughput; derives the size block |
| `PROFILE_SIZE_WARN_BYTES` | 1000000 | bytes | S1 | DataIssue telemetry for unusually heavy profiles |
| `PROFILE_SIZE_BLOCK_BYTES` | 2000000 | bytes | S1 | refuse new records: 2 writes/min × 2 MB = 4 MB/min |
| `PROFILE_STORE_NAME` | "PlayerData" | — | S1 | Roblox's recommended store name |
| `PROFILE_KEY_PREFIX` | "User_" | — | S1 | key = prefix .. UserId, the pattern automated right-to-be-forgotten needs |

### 16.3 `Definitions/Validate`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `KNOWN_PART_MATERIALS` | the `Enum.Material` names Materials rows may use (MVP: Metal; Phase 2 rows: Foil, Glass, Wood, Leather) | — | S1 | pure check D4 (§2.3); the Roblox-bound boot also asserts `Enum.Material[name]` |

### 16.4 `Definitions/Materials`

Catalog rows: §2.5 (S1 columns); owner columns `difficultyTerm` (§5.3) and `qualityTier` (§8.3).

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `difficultyTerm` | Iron 0, Steel 0 | – | S2 | materials are free: no difficulty slider (Q13) |
| Materials.qualityTier | Iron 1.00 · Steel 1.02 | × | S4 | Steel ≤ 1.04 keeps the Steel rarity targets (Q13) |

### 16.5 `Definitions/EquipmentTypes`

Sword `geometry` (S2 values).

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `HITBOX_MIN`, `HITBOX_MAX` | (−0.80, 0.00, −0.30), (0.80, 5.00, 0.30) | stud | S2 | origin at the bottom-face centre; greatswords and cleavers fit (Q3) |
| `SLOTS` | Blade 1–12 r1 striking, Guard 0–8 r2, Grip 1–6 r3, Pommel 0–4 r4 | parts | S2 | required Blade + Grip; maxima are anti-filler rules (Q4) |
| `strikingSlot`, `gripSlot`, `guardSlot` | Blade, Grip, Guard | SlotId | S2 | reach and edge; grip frame; guard line (§4.5) |
| `thicknessAxis` | (0, 0, 1) | — | S2 | blueprint +Z (§3.1) |
| `partsMin`, `partsMax` | 2, 24 | parts | S2 | the required slots' minima and `MAX_PARTS`; read only by the editor's part-count hint (slot rules and `MAX_PARTS` validate) |
| refs Volume | 0.08–0.80 | stud³ | S2 | cleaver Smelting Hard, arming 0.036 |
| refs Thinness | σ 45–130 | ratio | S2 | see SIGMA_LO/HI |
| refs Asymmetry | 0–0.6 | fraction | S2 | sabre blade saturates, cleaver ≈ 0.5 |
| refs SurfaceComplexity | 2.3–2.9 | ratio | S2 | plain blades 0; ornate 0.5; cap 2.9 |
| refs EdgeLength | 4.8–8.0 | stud | S2 | arming Sharpening 0.132, greatsword Hard 0.249 |
| refs PartCount, Joints, MaterialMix | 3–16, 3–24, 1–4 | parts, joint units, materials | S2 | Phase 2 factors (reported) |

### 16.6 `Definitions/Steps`

Factor weights per step (S2).

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| weights Smelting | Volume 1.00 | – | S2 | material through S3 and S4 |
| weights Hammering | Thinness 0.40, Asymmetry 0.30, SurfaceComplexity 0.30 | – | S2 | "thin parts warp under the hammer" |
| weights Sharpening | EdgeLength 0.50, Asymmetry 0.30, SurfaceComplexity 0.20 | – | S2 | edge leads grinding |
| weights Quenching / Assembly / Finishing | Th .60 PC .40 / Jo .45 PC .35 MM .20 / SC 1.00 | – | S2 | Phase 2 hooks |

### 16.7 `Definitions/Tiers`

Catalog rows and colours: §2.7.

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| tier `dMin` | Normal 0, Hard 0.2, Expert 0.4, Master 0.6, Hell 0.8 | – | S2 | draft values; MVP enables Normal, Hard (Q1) |
| Tiers.qualityMultiplier | Normal 1.00 · Hard 1.25 · Expert 1.55 · Master 1.90 · Hell 2.30 | × | S4 | Hard pays for skill; placeholders steepen toward Hell |
| Tiers.rarityCap | Rare · Epic · Legendary · Mythic · Divine | RarityId | S4 | the hardest passed step sets the cap (Q10) |
| Tiers.failScoreFactor | 0.75 (every tier) | × | S4 | a failed step counts at 75 % (Q9) |
| Tiers.failOutcome | LowerQuality (Hell: DestroyMaterial) | enum | S4 | nothing destroyed on Normal or Hard |

### 16.8 `Definitions/Rarities`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| Rarities.minQuality | Common 0 · Uncommon 0.55 · Rare 0.84 · Epic 1.04 · Legendary 1.29 · Mythic 1.58 · Divine 1.91 | Q | S4 | grid search on S3's distributions, min margin 6.15 points; placeholders by the ladder (Q12) |

### 16.9 `Definitions/Stats`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| Stats rows (unit, decimals) | Damage, Sharpness, Durability, Balance ("", 0) · Purity ("%", 0) · Reach ("studs", 1) | — | S4 | display rule shared by S6 and S7; Purity stored as 100·P |
| Quality display (rule) | floor(Q·100 + 0.5) | points | S4 | open scale, Q = 1.00 = flawless all-Normal Iron at D = 0 |

### 16.10 `Definitions/Balance`

One deep-frozen module; groups as in §2.8. Geometry, Difficulty, Quality and Stats are in the BALANCE Manifest.

**`Balance.Geometry`**

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `EPS_GEOM` | 1e-7 | stud | S2 | signed epsilon of every boundary predicate |
| `HIDE_OFFSET` | 0.012 | stud | S2 | = CONTACT_TOL + 0.002: faces across a connected gap are hidden |
| `MIN_PART_VOLUME` | 0.0002 | stud³ | S2 | Dust floor |
| `ENCLOSED_EXPOSED_MAX` | 0.02 | fraction | S2 | Enclosed: < 2 % of the area exposed |
| `H_VOL`, `N_MIN_AXIS`, `N_MAX_AXIS`, `N_MAX_PART`, `N_VOL_TOTAL` | 0.05, 2, 48, 3000, 12000 | stud, samples | S2 | volume-sample grid and budget |
| `H_SURF`, `NS_MAX`, `N_SURF_WORK` | 0.04, 64, 40000 | stud, samples, tests | S2 | surface grid; the measure's samples × candidates budget, by the ladder's Block estimate |
| `N_SUB_WORK` | 24000 | tests | S2 | the measure's boundary corner + 4 × 4 sub-grid tests; the verdict has no such budget, and that closes hidden parts' last channel (E-S2.11) |
| `VERDICT_SAMPLES` | 64 | samples | S2 | a part's own grid for its verdict, by its Block estimate: more buys nothing (E-S2.11) |
| `VERDICT_BALL_NF` | 4 | cells | S2 | per cube-face axis of a Ball's verdict grid, whatever its radius: largest sample 1.64 %, no lone sample keeps it |
| `VERDICT_CORNER` | 0.98 | × half-vector | S2 | the verdict's corner test, for the one part that hides a patch and on a Cylinder's side: a corner exactly on another part's rim is no strip |
| `VERDICT_STRIP_RIM`, `VERDICT_STRIP_CENTRE` | 0.0625, 0.25 | of a patch | S2 | on a Cylinder's side, where a corner, or the centre, showed and no sub-point did: a strip under 1/8, or 1/4, of the patch wide. Flat patches measure theirs on lines |
| `VERDICT_TRIANGLE_CELLS` | 2 | cells per edge | S2 | triangles in the verdict: with 1 the far half of a thin one has no sample |
| `H_LADDER` | {1, 1.25, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10, 12, 16} | × spacing | S2 | deterministic coarsening |
| `MAX_EXACT`, `H_OVERLAP`, `OVERLAP_N_MIN/MAX`, `N_OVERLAP_WORK` | 3, 0.0125, 4/24, 40000 | parts, stud, cells, tests | S2 | exact clipping up to 3 higher parts, refined sampling otherwise |
| `GJK_MAX_ITER` | 48 | iterations | S2 | mean 3.1, max 9 measured |
| `AXIS_ELONGATION`, `AXIS_MAX_TILT_COS` | 1.5, 0.7071 | ratio, cos | S2 | physics grip axis: a part's eligibility; tilted > 45° from +Y it has no vote |
| `EDGE_CELL`, `RASTER_TOL` | 0.02, 0.005 | stud | S2 | raster cell; dilation = CONTACT_TOL/2 (seams never open) |
| `EDGE_MAX_CELLS`, `EDGE_MAX_WORK` | 12000, 30000 | cells, tests | S2 | raster budgets |
| `EDGE_MAX_THICK`, `EDGE_DOWN_COS` | 0.25, 0.5 | stud, cos | S2 | a spine is not an edge; pommel-facing segments are not sharpenable |
| `EDGE_SIMPLIFY`, `EDGE_GAP_BRIDGE`, `EDGE_MIN_CHAIN` | 1, 3, 3 | × cell | S2 | DP tolerance; joint bridging; noise chains |
| `EDGE_MAX_POINTS` | 256 | points | S2 | bounded trace source |
| `CUT_LO`, `CUT_HI` | 10, 60 | ratio | S2 | cutIndex = length/thickness ramp |

**`Balance.Difficulty`**

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `V_PART_FULL` | 0.004 | stud³ | S2 | part significance for PartCount and Joints |
| `JOINT_BOOST`, `A_JOINT_REF` | 1.0, 0.05 | –, stud² | S2 | small contacts count up to 2× |
| `THICK_BUDGET` | 400 | probes | S2 | Thinness probes per work set |
| `SIGMA_LO`, `SIGMA_HI` | 45, 130 | L/τ | S2 | arming Hammering 0.114, rapiers Hard (E-S2.9) |
| `THIN_SHARE_MIN` | 0.25 | fraction | S2 | thin metal must be ≥ 25 % of the set's striking metal (fins cannot set Thinness) |
| `ASYM_TOL`, `ASYM_RAMP` | 0.02, 0.03 | stud | S2 | soft coverage: symmetric up to 0.02, ramp to 0.05 |
| `ASYM_N_MIN`, `ASYM_AXIS_X`, `ASYM_WORK` | 10, 0.6, 30000 | probes, cos, tests | S2 | ≥ 10 probes across the mirror direction; budget |

**`Balance.Quality`**

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| WEIGHT_SUM_TOL | 1e-9 | — | S4 | enabled weights per type sum to 1 |
| FAILED_STEP_CAP_TIER | "Normal" | TierId | S4 | a failed step lifts no cap (Q9) |
| DESIGN_GAMMA | 0.15 | per unit D | S4 | smallest round γ keeping a Good player's expected Q non-decreasing in D (Q11) |

**`Balance.Stats.Sword`**

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| MATERIAL_SCALE | 100 | — | S4 | S1 stores hardness and toughness as integers 0–100 |
| PURITY_FLOOR | 0.70 | fraction | S4 | a ruined smelt keeps 70 % of the metal |
| SHARP_FLOOR | 0.30 | fraction | S4 | sharpening is the main Sharpness lever (×3.3) |
| DURA_FLOOR | 0.50 | fraction | S4 | hammering refines toughness (×2) |
| FORGE_FLOOR | 0.60 | fraction | S4 | a botched hammering keeps 60 % of the damage |
| EDGE_REF | 6.0 | studs | S4 | F1/F5's main chain 5.433 gives 0.91 |
| EDGE_GAIN | 1.0 | × | S4 | full edge at Sharpness 70 hits ×1.7 a blunt bar |
| MASS_REF | 0.80 | kg | S4 | F5 starter 0.793 kg → F_mass ≈ 1 |
| MASS_BIAS | 0.4 | — | S4 | ×2 mass → +25 % damage |
| MASS_FACTOR_MIN, MASS_FACTOR_MAX | 0.6, 1.3 | × | S4 | heavy designs capped until swing speed (Phase 2) |
| DAMAGE_BASE | 28 | points | S4 | flawless fixtures 36–44, headroom to 100 |
| BALANCE_IDEAL | 0.08 | balance / reach | S4 | centre of the 4–12 % plateau before the guard |
| BALANCE_TOLERANCE | 0.04 | balance / reach | S4 | wide plateau, sensible designs score 100 |
| BALANCE_FALLOFF | 0.30 | balance / reach | S4 | F4 cleaver (β 0.28) scores 47 |
| BALANCE_REACH_MIN | 1.0 | studs | S4 | division guard |

**`Balance.Display`**

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `MASS_UNIT_LABEL` | "kg" | — | S1 | Iron 7.87 per stud³ makes swords read 0.8–1.5 kg [Decision to confirm] (Q13) |

### 16.11 `Definitions/CraftPlans`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| CraftPlans.Sword | Smelting 0.25 "All" · Hammering 0.40 "All" · Sharpening 0.35 {"Blade"} | weight | S4 | play order, work sets and quality weights of the sword (Q12) |

### 16.12 `Definitions/MinigameFamilies`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `passThreshold` (every family) | 0.50 | score | S3 | one pass line; parameters carry difficulty (Q8) |
| `TIMELINE_FORMAT_VERSION` / `TIMELINE_HEADER_BYTES` | 1 / 12 | –, B | S3 | timeline header |
| `FAMILY_CODE` | HoldZone 1, TimingStrike 2, PrecisionTrace 3 | – | S3 | header byte 1 |
| `RECORD_BYTES` | 3 / 2 / 7 | B | S3 | per family, in that order |
| `MAX_RECORDS` | 1024 / 512 / 2048 | records | S3 | above every honest maximum (Trace 1,551) |
| `MAX_TIMELINE_BYTES` | 14348 | B | S3 | 12 + 2048 × 7 (PrecisionTrace cap); the S5 Guard bound (§10.3) |
| `HoldZone.zoneWidth` | 0.090 | gauge | S3 | 117 °C band on the 300–1600 °C gauge; Steel, Hard and design columns in §6.8 |
| `HoldZone.driftSpeed` | 0.21 | gauge/s | S3 | zone speed while moving |
| `HoldZone.heatDecay` | 1.0 | 1/s | S3 | needle responsiveness |
| `HoldZone.fullHeat` | 2.4 | gauge | S3 | steady T ≤ 0.96 at the refill rate |
| `HoldZone.strokeGain` | 0.25 | fire | S3 | one stroke from rest: +0.17 T |
| `HoldZone.refillMs` | 250 | ms | S3 | useful tap rate ≤ 4/s |
| `HoldZone.fireDecayMs` | 600 | ms | S3 | fire dies down between strokes |
| `HoldZone.targetMin` / `targetMax` | 0.40 / 0.80 | gauge | S3 | zone centre range; Steel needs more heat |
| `HoldZone.segMinMs` / `segMaxMs` | 900 / 2200 | ms | S3 | zone direction changes |
| `HoldZone.holdChance` | 0.25 | – | S3 | stationary breathers |
| `HoldZone.durationMs` / `rampMs` | 15000 / 3000 | ms | S3 | 12 s scored after a heat-up |
| `HoldZone.softFrac` | 0.5 | ×zoneWidth | S3 | partial credit near the zone |
| `TimingStrike.strikes` | 12 | count | S3 | 15 at Hard (Q15); ≥ 8 for the variance check |
| `TimingStrike.beatMs` | 900 | ms | S3 | rhythm speed |
| `TimingStrike.windowMs` | 110 | ms (half) | S3 | sized for about 25 ms of display lag |
| `TimingStrike.perfectFrac` / `edgePoints` | 0.12 / 0.20 | ×W, points | S3 | full-points core, edge slope |
| `TimingStrike.tempoJitter` | 0.08 | ±×P | S3 | irregular rhythm |
| `TimingStrike.offsetMin` / `offsetMax` | 0.40 / 0.75 | ×P | S3 | read each cycle; spans never overlap |
| `TimingStrike.missPadMs` / `tailMs` | 90 / 400 | ms | S3 | near presses are Misses; tail after the last cycle |
| `PrecisionTrace.halfWidth` / `coreFrac` | 0.041 / 0.10 | u, ×w | S3 | 21 px at 520 px; accuracy stays a gradient |
| `PrecisionTrace.pacerSpeed` | 0.30 | u/s | S3 | sets the duration |
| `PrecisionTrace.paceTol` / `paceFall` | 0.12 / 0.24 | arc u | S3 | ±0.4 s at full credit |
| `PrecisionTrace.perturbAmp` | 0.020 | u | S3 | grind irregularities |
| `PrecisionTrace.bumpDensity` / `bumpWidth` | 1.0 / 0.25 | /u, u | S3 | path complexity |
| `PrecisionTrace.leadInMs` / `tailMs` | 600 / 400 | ms | S3 | the spark waits at the start |
| `PrecisionTrace.wAccuracy` | 0.70 | – | S3 | accuracy is the skill, pace the guard |
| `HZ_RATE_WINDOW_MS` / `HZ_RATE_MAX_PRESSES` | 1000 / 30 | ms, presses | S3 | humans ≤ 9 |
| `TS_MIN_JUDGED`, `TS_MIN_SD_MS` | 8, 1.5 | strikes, ms | S3 | FP ≤ 1.1e-5 at σ 10 ms |
| `TS_EXACT_MS` / `TS_EXACT_FRAC` | 1 / 0.90 | ms, – | S3 | exact-time macros |
| `PT_PRECISE_MIN_SAMPLES` / `PT_PRECISE_MEAN_DEV` | 40 / 0.0008 | samples, u | S3 | human minimum ×3.5 (3,000 runs) |
| `PT_SMOOTH_MIN_TRIPLETS`, `PT_SMOOTH_MEAN_JERK`, `PT_SMOOTH_MIN_MOVE` | 150, 0.0002, 0.002 | –, u, u | S3 | human minimum ×19 |
| `PT_TELEPORT_DIST`, `PT_TELEPORT_MAX_DT`, `PT_TELEPORT_COUNT` | 0.25, 40, 3 | u, ms, – | S3 | jump detector (telemetry) |
| `PT_SPARSE_FRAC` | 0.5 | ×travelMs/20 | S3 | sparse timelines (telemetry) |
| `flagLevels` | HzInhumanRate, TsLowVariance, TsExactHits, PtTooPrecise High; PtTooSmooth, PtTeleport, PtSparse Medium | – | S3 | the judge's clamp (§10.5) and fromCraft's order (§9.4); §10.6 |

### 16.13 `Definitions/Network`

Server and protocol tunables; they never change outcomes (§1.3 L5).

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `COUNTDOWN_MS` | 3000 | ms | S5 | 3-2-1 before each step; copied into `StepSpec.countdownMs` |
| `EARLY_TOL_MS` | 250 | ms | S5 | 0 honest refusals in 10⁶ simulated submissions |
| `LATE_SOFT_MS` | 1500 | ms | S5 | LateSubmit flag only; honest rate ≈ 1.3 % |
| `LATE_HARD_MS` | 5000 | ms | S5 | honest timeouts ≤ 3 per 10⁶ |
| `RTT_ALLOW_MAX_MS` | 2000 | ms | S5 | cap of A = min(2·median ping, cap) |
| `MAX_PING_SAMPLES` | 160 | samples | S5 | 40 s of 4 Hz samples (longest step 31 s + countdown + lateness) |
| `TICK_INTERVAL_MS` | 250 | ms | S5 | deadline and idle sweep, ping sampling |
| `READY_IDLE_TIMEOUT_MS` | 120000 | ms | S5 | results card plus walking to the next station |
| `SESSION_MAX_MS` | 600000 | ms | S5 | backstop above the ≈ 453 s compliant worst case |
| `TOMBSTONE_MS` | 60000 | ms | S5 | duplicates after the end get the stored reply |
| `MAX_STEPS` | 8 | steps | S5 | Guard bound; Phase 2 plans have up to 7 steps |
| `MAX_PAYLOAD_NODES` | 6000 | nodes | S5 | Guard node budget, ≈ 13× a 24-part Save (439 nodes) |
| `MAX_SETTINGS_NODES` | 256 | nodes | S5 | SetSettings budget; settings + 64 flags use 80 |
| `MAX_DRAFT_DEPTH` | 4 | levels | S5 | nesting of S1's wire draft |
| `MAX_BATCH_IDS` | 12 | ids | S5 | ids per Blueprint.Get / Showcase.GetItems (a visible page of tiles) |
| `REPLY_PAGE_BYTES` | 32768 | B (JSON) | S5 | per-message cap; snapshot at caps ≈ 70 KB → 3 pages |
| `REQUEST_TIMEOUT_S` | 20 | s | S5 | above a full AnalysisQueue drain (≈ 13 s) |
| `HELLO_TIMEOUT_S` | 120 | s | S5 | Hello waits for the whole profile load (≈ 75–95 s worst, §9.1) |
| `LANE_CAP` | 4 | requests | S5 | waiting mutating requests per (player, channel) |
| `ANALYSIS_SLICE_MS` | 4 | ms | S5 | server work per Heartbeat (§1.6, §4.9) |
| `ANALYSIS_QUEUE_CAP` | 16 | jobs | S5 | P0 + P1 jobs; at most `PLOT_COUNT` × `ANALYSIS_JOBS_PER_PLAYER` = 8 are ever held (≈ 6.5 s drain at E-S5.4's 0.81 s per job), so 16 is headroom |
| `ANALYSIS_JOBS_PER_PLAYER` | 1 | jobs | S5 | one P0/P1 job in flight per player |
| `RECOMPUTE_QUEUE_CAP` | 64 | jobs | S5 | stale-item recomputes (P2), deduped by item id |
| `RATE_LIMITED_REPLIES_PER_S` | 5 | replies/s | S5 | a flood must not double outbound traffic |
| `FLOOD_KICK_DROPS_PER_MIN` | 300 | drops | S5 | 10× what a buggy honest client produces |
| `HARD_STRIKES_KICK` | 10 | strikes | S5 | per server session; honest clients produce 0 |
| `RATE.ProfileHello` | 2, 1/30 | cap, per s | S5 | once per join plus one client restart |
| `RATE.ProfileSync` | 3, 1/10 | cap, per s | S5 | resync after an error; paged snapshot |
| `RATE.ProfileSetSettings` | 5, 1/2 | cap, per s | S5 | S6 debounces settings |
| `RATE.BlueprintGet` | 10, 2 | cap, per s | S5 | library thumbnails, 12 ids per call |
| `RATE.BlueprintSave` | 4, 1/3 | cap, per s | S5 | manual saves + 60 s autosave; one analysis each |
| `RATE.BlueprintRename` | 5, 1/2 | cap, per s | S5 | list management |
| `RATE.BlueprintDelete` | 5, 1/2 | cap, per s | S5 | list management |
| `RATE.CraftBegin` | 3, 1/10 | cap, per s | S5 | a craft lasts ≥ 30 s |
| `RATE.CraftStartStep` | 5, 1/2 | cap, per s | S5 | 3 steps per craft plus desync re-opens |
| `RATE.CraftSubmit` | 5, 1/2 | cap, per s | S5 | one per step |
| `RATE.CraftAbandon` | 3, 1/5 | cap, per s | S5 | rare |
| `RATE.CraftResume` | 3, 1/5 | cap, per s | S5 | client UI restart |
| `RATE.CraftReportDesync` | 3, 1/10 | cap, per s | S5 | rare; never a re-roll |
| `RATE.ShowcasePlace` | 6, 1 | cap, per s | S5 | rearranging the smithy |
| `RATE.ShowcaseClear` | 6, 1 | cap, per s | S5 | rearranging the smithy |
| `RATE.ShowcaseScrap` | 5, 1/2 | cap, per s | S5 | inventory clean-up |
| `RATE.ShowcaseInspect` | 10, 3 | cap, per s | S5 | browsing stands; cache-only names |
| `RATE.ShowcaseGetItems` | 10, 2 | cap, per s | S5 | inventory grid, 12 ids per call |
| `RATE.ShowcaseTeleportHome` | 1, 1/3 | cap, per s | S5 | one per 3 s (S6 HUD "My smithy") |
| `RATE.Global` | 30, 15 | cap, per s | S5 | ≈ 10× honest peak |
| `TELEMETRY_BUCKET` | 20, 0.25 | cap, per s | S5 | ≤ 15 events/min/player (platform 20/min/CCU) |
| `TELEMETRY_RING` | 2000 | records | S5 | Studio/playtest ring read by S8's bridge |
| `LOG_BUCKET` | 20, 2 | lines, per s | S5 | per (tag, event), then one `suppressed=N` line |
| `LOG_PLAYER_BUCKET` | 5, 0.5 | lines, per s | S5 | per (player, tag, event): no log flooding |
| `LOG_VALUE_MAX_BYTES` | 64 | B | S5 | client-originated strings in log values |
| `SAVE_MIN_INTERVAL_S` | 60 | s | S5 | ≥ 60 s after any write: ≤ 2 writes/min ≤ 4 MB/min at S1's block |
| `LOAD_TIMEOUT_S` | 75 | s | S5 | longer than a session steal (≈ 45 s) plus back-off |
| `KICK` | LOAD_FAILED, SESSION_ENDED, NEWER_SCHEMA, DATA_ERROR, CLOSING, FULL (texts §9.1) | text | S5 | never a blank profile; S6 may restyle |

### 16.14 `Definitions/World`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `PLOT_COUNT` | 8 | plots | S7 | One smithy per player, = `Players.MaxPlayers` (Q2); the only definition (S5's boot check reads it). |
| `PLOT_SIZE` | 40 | studs | S7 | Square plot: pavilion plus a front yard where visitors read the stands. |
| `PLOT_RING_RADIUS` | 86 | studs | S7 | 13.6-stud gaps between plots, plot fronts 66 studs (4.1 s walk) from the plaza centre (E-S7.2). |
| `PLAZA_RADIUS` | 64 | studs | S7 | Paved disc just inside the plot fronts (66). |
| `WORLD_WALL_RADIUS` | 116 | studs | S7 | Plot back corners (107.9) + 8. |
| `GROUND_DISC_DIAMETER` | 240 | studs | S7 | Covers everything inside the boundary wall. |
| `FLOOR_TOP` | 0.5 | studs | S7 | Smithy floor one step above the ground. |
| `HOME_POSE` | pos (0, 0.5, −4), yaw 180 | plot-local studs, degrees | S7 | Spawn and teleport target on the gallery floor, facing the forge row. |
| `PLOT_INTERACT_MARGIN` | 6 | studs | S7 | Distance beyond the plot square that still counts as "at your smithy" for Place, Clear and Begin. |
| `STEP_STATION` | Smelting → Furnace, Hammering → Anvil, Sharpening → Grindstone | — | S7 | Step-to-station map; new stations are data. |
| `EDITOR_STAGE_ORIGIN` | (0, 1000, 0) | studs | S7 | Centre of the 256-stud cube reserved for the editor stage (§11); nothing else is built there. |
| `DISPLAY_SLOTS` | 6 | stands | S7 | Stands per plot (Q20); also the Guard's slot bound. |
| `DISPLAY_SLOT_KEYS` | "D1" … "D6" | — | S7 | Keys of `smithy.displays`, read by `Persistence/Prepare` and `ShowcaseRules`. |
| `DISPLAY_SLOT_X` | −13.5, −8.5, −3.5, 3.5, 8.5, 13.5 | studs, plot-local | S7 | Pitch 5, 7 across the central aisle; fits the 1.6-wide hitbox. |
| `DISPLAY_SLOT_Z` | −9 | studs, plot-local | S7 | One row behind the front posts, readable from the front yard. |
| `CRADLE_HEIGHT` | 1.55 | studs above the stand base | S7 | Item floats 0.15 above the cap; a 5-stud item tops out under the sign. |
| `INSPECT_PAD` | 0.3 | studs per side | S7 | Easier click target around the item bounds. |
| `INSPECT_MIN_THICKNESS` | 0.8 | studs | S7 | Thin blades stay clickable edge-on. |
| `STATION_PROMPT_DISTANCE` | 7 | studs | S7 | Reached from the station's stand point (prompts 1.9–2.4 studs away). |
| `DISPLAY_PROMPT_DISTANCE` | 8 | studs | S7 | Reached from outside the front posts (3.9 studs). |
| `INSPECT_CLICK_DISTANCE` | 24 | studs | S7 | Click an item from across the gallery. |
| `PRESENCE_HZ` | 4 | Hz | S7 | `PlotPresence` check rate; cheap and fast enough for the entry toast. |
| `CLOCK_TIME` | 17 | hours | S7 | Fixed golden hour, no cycle (Q20). |
| `FLICKER_AMPLITUDE` | 0.08 | fraction of base brightness | S7 | Subtle flame flicker. |
| `FLICKER_FREQUENCY` | 6 | 1/s | S7 | `math.noise` frequency. |
| `FLICKER_HZ` | 20 | Hz | S7 | Client update rate of flickering lights. |
| `FLICKER_RADIUS` | 80 | studs | S7 | Only lights near the camera flicker. |
| `LIGHTING_FX` | BS_Atmosphere, BS_Grade, BS_Bloom, BS_SunRays | — | S7 | Named Lighting children the editor neutralises (§11). |
| `PALETTE`, `PLOT_ACCENTS` | E-S7.1 | RGB 0–255 | S7 | Asset-free look; accents tell plots apart. |

### 16.15 `Definitions/Presentation`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `DISPLAY_SCALE` | 1.0 | — | S7 | Items show at true size on stands and stations. |
| `VIEWPORT_FOV` | 30 | degrees | S7 | Low distortion in item viewports. |
| `VIEWPORT_MARGIN` | 1.08 | — | S7 | 8 % margin around the fitted item. |
| `HEAT_COLOR` | (255, 96, 32) | RGB | S7 | Hot-metal orange. |
| `HEAT_BLEND` | 0.85 | — | S7 | Colour lerp factor at h = 1. |
| `HEAT_NEON_THRESHOLD` | 0.55 | heat | S7 | Above it the workpiece turns Neon and blooms. |
| `HEAT_LIGHT_BRIGHTNESS` | 2.5 | × heat | S7 | Workpiece glow; no light at h = 0. |
| `HEAT_LIGHT_RANGE` | 8 | studs | S7 | Glow stays on the station. |
| `WORKPIECE_HEAT` | Smelting 0.9, Hammering 0.7, Sharpening 0 | heat 0–1 | S7 | Cooling as the craft goes on. |
| `INGOT_SIZE` | 0.5 × 0.25 × 1.0 | studs | S7 | Smelting workpiece, one per distinct material. |
| `PLACEHOLDER_SIZE` | 0.8 | studs | S7 | Grey block shown when a plan fails. |
| `INSPECT_TURNTABLE_SPEED` | 24 | degrees/s | S7 | Slow camera orbit in the inspect preview. |
| `INSPECT_AUTOCLOSE_DISTANCE` | 16 | studs | S7 | The panel closes when you walk away. |
| `CAM_ENTER_S` | 0.8 | s | S7 | Free camera to the first station. |
| `CAM_MOVE_S` | 0.9 | s | S7 | Station to station; covers the ≈ 0.6 s walk. |
| `CAM_EXIT_S` | 0.6 | s | S7 | Back to the free camera. |
| `WALK_TIMEOUT_S` | 1.4 | s | S7 | After it the smith is placed on the stand point. |
| `ARRIVE_TOLERANCE` | 0.75 | studs | S7 | Closer than this, no snap is needed. |
| `ANVIL_SPARK_INTERVAL` | 0.7 | s | S7 | Visitors' spark rhythm while Hammering. |
| `ANVIL_SPARK_COUNT` | 12 | particles | S7 | Sparks per burst. |
| `GRINDSTONE_SPIN` | 270 | degrees/s | S7 | Wheel speed while Sharpening. |
| `GRINDSTONE_SPARK_RATE` | 30 | particles/s | S7 | Sparks while Sharpening. |
| `RARITY_FX` | E-S7.6 | — | S7 | Light, sparkles and highlight per rarity; Legendary and above are data only. |

### 16.16 `Definitions/Audio`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| Audio cues | 14 hooks, ids picked in the build (`""` silent) | — | S6 | [Decision to confirm] Q20 |

### 16.17 `Util/Quantize`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `SCALAR_SCALE` | 10000 | 1/unit | S1 | D, scores, T, Q and stats on the 1e-4 grid |

### 16.18 `Physics/Analyze`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `CHECK_UNITS` | 500 | work units | S2 | checkpoint cadence (≈ 0.1–0.5 ms Lune); not outcome-affecting |
| `UNITS_PER_SAMPLE`, `UNITS_PER_SUBSET`, `UNITS_PER_OVERLAP_TEST`, `UNITS_PER_CONTACT_TEST`, `UNITS_PER_DISTANCE` | 4, 250, 20, 20, 40 | work units | S2 | checkpoint weights; not outcome-affecting |
| numeric guards, in `Physics/*` | `INSIDE_MARGIN` 1e-9, `OVERLAP_TOL` 1e-9, `CLIP_EPS` 1e-12, `Shapes.AXIAL2` 1e-18, `Gjk`'s `ZERO_LENGTH2` 1e-24, `CONVERGED` 1e-12, `DEGENERATE_EDGE2` 1e-30, `DEGENERATE_VOLUME` 1e-18 | stud, stud², stud³ | S2 | fixed, not tunables; they separate rounding from geometry |

### 16.19 `Minigames/Rng`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `RNG_SPLITMIX_GAMMA`, `RNG_FMIX_C1`, `RNG_FMIX_C2` | 0x9E3779B9, 0x85EBCA6B, 0xC2B2AE35 | – | S3 | SplitMix32 seeding |
| `FNV_BASIS` / `FNV_PRIME` | 0x811C9DC5 / 0x01000193 | – | S3 | FNV-1a 32 for tags and hashes |

### 16.20 `Minigames/HoldZone`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `HZ_TICK_MS` | 10 | ms | S3 | integer tick boundaries |

### 16.21 `Minigames/TimingStrike`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `TS_PERFECT_CORE_MIN_MS` | 10 | ms | S3 | ≥ 9 ms (full-points core at every MVP tier, §6.9); Perfect at 30 fps ≥ 0.965 per run |
| `TS_GRADE_PERFECT` / `TS_GRADE_GOOD` | 0.9 / 0.6 | points | S3 | grade labels from points |
| `TS_OFFSET_OFFER_MIN_JUDGED` | 8 | strikes | S3 | offset offered from ≥ 8 errors |

### 16.22 `Minigames/PrecisionTrace`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `PT_PANEL_ASPECT`, `PT_FIXED_POINT`, `PT_MARGIN_U`, `PT_MARGIN_V` | 3.0, 16384, 0.15, 0.12 | –, /u, u, u | S3 | panel and fixed point (u ≤ 49152, v ≤ 16384) |
| `PT_BLADE_REF_LEN` | 4.5 | stud | S3 | a 4.5-stud blade spans the panel |
| `PT_EXAG_MAX` / `PT_EXAG_SHRINK` | 2.0 / 0.9 | – | S3 | cross-axis exaggeration and its shrink step |
| `PT_LEN_MARGIN` | 0.95 | – | S3 | source ≤ 0.95 × 30 s × pacerSpeed |
| `PT_MAX_SOURCE_POINTS` | 256 | points | S3 | bounded source |
| `PT_SIMPLIFY_TOL` / `PT_SIMPLIFY_STEPS` | 0.004 / 8 | u, steps | S3 | Douglas–Peucker, doubling |
| `PT_MIN_SOURCE_LEN` | 0.4 | u | S3 | shorter edges use the fallback |
| `PT_FALLBACK_EDGE` | (±0.22, 0) → (±0.22, 2.6) → (0, 3.4) | stud | S3 | generic double edge (Q15) |
| `PT_CHAIKIN_ITERS`, `PT_DS`, `PT_TAPER` | 3, 0.01, 0.15 | –, u, u | S3 | smoothing, spacing, calm ends |
| `PT_CLEAR_SKIP`, `PT_CLEAR_FRAC`, `PT_CLEAR_CELL` | 0.30, 0.35, 0.30 | u, –, u | S3 | no self-crossing; O(n) grid |
| `PT_EVAL_MS`, `PT_SEARCH`, `PT_BIN` | 20, 0.5, 0.02 | ms, arc u, arc u | S3 | tick = sampling cadence; pacer window; coverage bin |
| `PT_VMAX_FACTOR` / `PT_VMAX_MIN` | 6 / 1.5 | ×speed, u/s | S3 | coverage speed gate |
| `PT_MAX_GAP_MS` | 250 | ms | S3 | longer gaps hold, not grinding |
| `PT_TRAVEL_MIN_MS` / `PT_TRAVEL_MAX_MS` | 6000 / 30000 | ms | S3 | travel clamp |

### 16.23 `Minigames/Bots`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `BOT_REF_X` | Normal 0.10, Hard 0.30 | factor | S3 | reference design for §6.13 |
| `BOT_EXTRA_LAG_MS` / `BOT_PANEL_PX` | 8 / 520 | ms, px | S3 | latency beyond a frame; S6 canvas height |
| `BOT_HZ_PERFECT_LOOKAHEAD_MS` | 300 | ms | S3 | Perfect HoldZone controller |
| `BOT_RUNS_PER_CELL` | 2000 | runs | S3 | distributions for S4 |

### 16.24 `Persistence/Settings`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `SNAP_LEN_STEP_MAX` | 16 | stud | S1 | sanity cap on move and scale snap steps; any positive step honoured |
| `SNAP_ROT_STEP_MAX` | 180 | degrees | S1 | sanity cap on the rotate snap step |
| `TIMING_OFFSET_MAX_MS` | 120 | ms | S1 | `timingOffsetMs` range ±120 (§6 TimingStrike) |
| `Settings.DEFAULT.snap` | move on 0.05, rotate off 15, scale on 0.05 | stud, degrees | S1 · values S6 | tidy joints, free rotation (S6 values) [Decision to confirm] (Q5) |
| `Settings.DEFAULT` (rest) | space Local, overlays on, reducedMotion false, timingOffsetMs 0, sfxVolume 1, grindToggle false | — | S1 · values S6 | neutral defaults (field list and values S6, §12.9) |

### 16.25 `Showcase/InspectView`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `INSPECT_VIEW_VERSION` | 1 | — | S7 | Payload version for clients. |

### 16.26 `EditorCore/Config`

Client UX constants, outside Balance and the BALANCE hash.

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `EDITOR_DISPLAY_LENGTH` | 20 | display stud | S6 | k = 4; the stage sits at `World.EDITOR_STAGE_ORIGIN` (0, 1000, 0), §13 |
| `STAGE_ENCLOSURE` | inner 240³, slabs 2, SmoothPlastic `stage.backdrop`/`.floor`, no shadow or query | display stud | S6 | fits every legal part (E-S6.1) |
| `EDITOR_LIGHTING` | ClockTime 14, Brightness 2, Ambient (70,72,80), OutdoorAmbient (110,112,120), EnvDiffuse 0.5, EnvSpecular 1, ShadowSoftness 0.3, Exposure 0; `LIGHTING_FX` neutral (§11.2) | — | S6 | true material colours |
| `HEADLIGHT` | PointLight Range 60, Brightness 0.6, no shadows | stud | S6 | faces turned from the sun |
| `CAM_FOV` · `CAM_MIN_DIST` / `CAM_MAX_DIST` · `CAM_WALL_MARGIN` | 50° · 1.0 / 84 · 2 | ° · display stud | S6 | low distortion · 2 × near plane / 4 × frame-all · eye stays inside |
| `ORBIT_DEG_PER_PX` · `ZOOM_STEP` · `CAM_SMOOTH_TAU_MS` · `CAM_EASE_MS` | 0.30 · 1.15 · 60 · 200 | °/px · /notch · ms · ms | S6 | 360°/1200 px · 5 notches ≈ ×2 |
| `FOCUS_FILL` / `FRAME_FILL` | 0.8 / 0.9 | — | S6 | framing margins |
| `ORTHO_EYE_DIST` · `ORTHO_FALLBACK_FOV` · `ORTHO_FALLBACK_MAX_OS` | 100 · 20° · 38.8 | display stud · ° · display stud | S6 | d = 2.836·OS ≤ 110 < 120 |
| `CLICK_DRAG_THRESHOLD_PX` · `DOUBLE_CLICK_MS` · `RMB_CLICK_MAX_MS` | 4 · 350 · 250 | px · ms · ms | S6 | click vs drag; RMB menu vs orbit |
| `GIZMO_*` arm, plane, sphere r, ring r, view ring r, cube | 110; 22 at 35; 8; 100; 118; 12 at 16 (centre 14) | design px | S6 | screen-constant handles |
| `GIZMO_PICK_TOL_PX` · `GIZMO_HIDE_ANGLE_DEG` / `GIZMO_FADE_ANGLE_DEG` · `RING_EDGE_ON_SIN` | 8 (10 spheres, cubes) · 12 / 18 · 0.208 | px · ° · — | S6 | jitter ≤ ×4.8 (E-S6.4) |
| `UNIFORM_SCALE_PX_PER_DOUBLE` | 200 | px | S6 | ×2 per 200 px |
| `EXPR_MAX_LEN` | 64 | chars | S6 | expression length (§11.9); nudges use the Move step and History's merge window |
| `PREVIEW_DEBOUNCE_MS` · `PREVIEW_MAX_HZ` · `PREVIEW_SLICE_MS` · `CONNECTIVITY_MAX_HZ` | 120 · 4 · 6 · 10 | ms · Hz · ms/frame · Hz | S6 | client UX outside Balance; live floating outline |
| `OVERFLOW_PULSE_PERIOD_MS` · `AUTOSAVE_S` · `AUTOSAVE_IDLE_S` | 1200 · 60 · 2 | ms · s · s | S6 | [Decision to confirm] Q6 autosave |

### 16.27 `EditorCore/Snap`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `SNAP_PRESETS` · `SNAP_CLEAN_MIN_STEP` | 0.01, 0.05, 0.1, 0.25, 0.5, 1 / 1, 5, 15, 22.5, 45, 90 · 1e-9 | stud / ° | S6 | built-in only · clean ≤ 5e-13 (E-S6.3) |

### 16.28 `EditorCore/History`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `HISTORY_MAX_COMMANDS` · `HISTORY_RECORD_BUDGET` · `HISTORY_MERGE_MS` | 200 · 6000 · 600 | — · part records · ms | S6 | ≈ 5.6 MB (E-S6.6) |

### 16.29 `UI/Config`

Client (`src/client/UI/Config`).

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `FADE_MS` · `PRIMARY_KEY_GUARD_MS` | 250 · 600 | ms | S6 | editor cuts · Space from play never skips a screen |
| `UI_BASE` · `UI_SCALE_MIN` / `UI_SCALE_MAX` | 1920 × 1080 · 0.75 / 2.0 | px · — | S6 | body ≥ 12 px at 720p (E-S6.2) |
| `COUNTDOWN_BEAT_MS` · `GO_VISIBLE_MS` · `GRADE_POPUP_MS` | 1000 · 400 · 600 | ms | S6 | 3-2-1 over the server's `COUNTDOWN_MS` |
| `RARITY_FILL_MS` / `RARITY_STAMP_MS` | 1600 / 700 | ms | S6 | 2.6 s reveal, skippable |
| `UI_SLOW_HINT_MS` · `IDLE_WARN_S` · `ABANDON_CONFIRM_MS` | 3000 · 30 · 3000 | ms · s · ms | S6 | before `REQUEST_TIMEOUT_S` and the idle limit |
| `TOAST_MS` / `TOAST_ERROR_MS` · `TOOLTIP_DELAY_MS` · `SETTINGS_SAVE_DEBOUNCE_S` | 3000 / 6000 · 500 · 2 | ms · ms · s | S6 | one SetSettings per burst |
| `GAUGE_SIZE` · `DIAL_DIAMETER` · `TRACE_CANVAS` | 140 × 600 · 440 · 1560 × 520 | design px | S6 | canvas ≥ 384 px tall at 720p (E-S6.10) |
| `TRACE_TRAIL_SAMPLES` · `HEAT_UPDATE_MAX_HZ` · `TEMP_LABEL_C` | 24 · 15 · 300 + 1300·t | samples · Hz · °C | S6 | ≈ 400 ms trail; cosmetic heat |
| `QUALITY_BAR_MAX` · `OFFSET_SUGGEST_MIN_MS` | 1.45 · 15 | Q · ms | S6 | above the MVP maximum Q 1.428 (§8.3) · clear bias only |
| `VIEWPORT_LIVE_MAX` · `WIDGET_BACKDROP_TRANSPARENCY` | 24 · 0.35 | frames · — | S6 | pooled tile viewports (§12.4) · widgets readable over the scene (§12.5) |

### 16.30 `server/Config`

Server (`src/server/Config`), resolved at boot.

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `Config.DATA_MODE` | "Mock" in Studio ("Live" with attribute `BS_DataMode`), "Live" on servers | enum | S5 | playtests never touch live data |
| `Config.LOG_LEVEL` | "DEBUG" in Studio, "INFO" live | enum | S5 | DEBUG lines only in Studio |
| `Config.TELEMETRY_ECHO` | Studio or private server | bool | S5 | AnalyticsService only sends from published games |
| `Config.FIXED_SEED` | nil | u32? | S5 | Studio only: reproducible playtests |
| `Config.CHECK_MUTATE_YIELD` | Studio | bool | S5 | errors if a `mutate` callback yields |
| `Config.STRIKE_KICK` | true (false under the test bridge) | bool | S5 | hostile E2E scenarios share one session |
| `Config.TEST_HOOKS` | false (Studio + S8 bridge only) | bool | S5 | enables `simulateRejoinForTest`, `resetStrikesForTest` |

### 16.31 `Vendor/ProfileStore`

Vendored, unchanged.

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| `AUTO_SAVE_PERIOD` | 300 | s | S5 | ProfileStore default, unchanged |

### 16.32 `tests/lib/Tol`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| CASE_BUDGET_MS | 2000 | ms | S8 | a slower fast case is a perf bug or belongs in `t.slow` |
| SLOW_CASE_BUDGET_MS | 300000 | ms | S8 | largest statistical case: a Trace FP case, 20,000 bot runs × ≈ 6.5 ms ≈ 130 s, with margin |
| PROP_BASE_SEED | 0x5EED0001 | — | S8 | fixed so property runs are reproducible |
| PROP_N | 200 | cases | S8 | cases per property in the fast set |
| FUZZ_N_GARBAGE | 2000 | values | S8 | hostile values per untrusted-input function (P-TOTAL) |
| FUZZ_N_VALID | 500 | designs | S8 | generated valid swords per property; hits every shape × slot |
| TOL_ANALYTIC_REL | 1e-9 | relative | S8 | analytic mass, COM, reach under rigid transforms (measured ≤ 1e-12) |
| TOL_MASS_REL | 0.005 | relative | S8 | invisible to players; stats about linear in mass |
| TOL_BALANCE_ABS | 0.01 | stud | S8 | 0.25 % of a 4-stud sword |
| TOL_REACH_ABS | 0.005 | stud | S8 | reach is shown with 2 decimals |
| TOL_FACTOR_ABS | 0.02 | factor | S8 | §4 invariance bound for Y/Z translation and flush segments |
| TOL_G_INVARIANT | 0.002 | G | S8 | S2's stated invariance of G |
| TOL_DUST_G | 0.005 | G | S8 | dust on surfaces may shift G this much |
| TOL_ASYM_ZERO | 0.02 | factor | S8 | asymmetry of a design mirrored with the tool |
| TOL_PARITY_MASS_REL | 1e-3 | relative | S8 | engine `Mass` (float32 sizes) vs pure volume |
| TOL_PARITY_COM_ABS | 1e-3 | stud | S8 | engine `CenterOfMass` vs pure centroid |
| STARTER_MARGIN | 0.05 | D | S8 | F5 plays Normal with this margin on every step (Q7) |
| BOT_RUNS | 400 | seeds per cell | S8 | SE of a mean ≈ 0.005 |
| FP_RUNS_TS | 300000 | runs per human profile | S8 | 0 flags ⇒ < 1e-5 per step at 95 % |
| FP_RUNS | 20000 | runs | S8 | HoldZone and Trace; margin assertions cover the rest |
| SOLVABILITY_SEEDS | 1000 | seeds per cell | S8 | finds rare impossible patterns |
| PERFECT_MIN_SCORE | 0.98 | score | S8 | mean rawScore of the Perfect bot (TimingStrike at 60 fps, PrecisionTrace), else the pattern is unfair |
| PERFECT_30FPS_MIN_SCORE | 0.95 | score | S8 | playable at 30 fps (§6 TimingStrike latency, T-MG-11) |
| PERFECT_HZ_MIN_SCORE | 0.95 | score | S8 | HoldZone's exact-state Perfect controller tops out at 0.97–0.99 raw (§6.13) |
| FAIRNESS_MAX_SD | 0.08 | score | S8 | one seed must not be much harder than another |
| TIER_MIN_MEAN_DROP | 0.05 | score | S8 | Average's Normal → Hard drop must be felt (Q8); other profiles only > 0 (§6.13) |
| STEEL_MEAN_DROP | [0.01, 0.08] | score | S8 | Steel "slightly tighter", Average on Normal (Q13) |
| CHI2_CRIT | 37.70 | — | S8 | χ² critical value, 16 buckets (15 dof), p = 0.001 |
| ANALYSIS_LUNE_MAX_MS | 60 | ms | S8 | coarse Lune regression guard (≈ 156 ms Studio); the 75 ms Studio ceiling of §4.9 is gated by S-PERF-01 only (C05 14.2 ms Lune ≈ 37 ms Studio, P1 31.7 ≈ 82, the worst design found 54.6 ≈ 142, §17.2) |
| CHECKPOINT_GAP_LUNE_MS | 0.35 | ms | S8 | keeps Studio slices ≤ 5 / 8 ms (E-S8.8) |
| REPLAY_BUDGET_MS | 8 | ms | S8 | decode + replay + checks of a 31 s timeline |
| PT_GENERATE_BUDGET_MS | 5 | ms | S8 | Trace pattern generation |
| REJECT_BUDGET_MS | 2 | ms | S8 | hostile payloads must be cheap to refuse |
| SERVER_SLICE_MAX_MS | 5 | ms | S8 | Studio: 4 ms slice + one checkpoint gap |
| CLIENT_SLICE_MAX_MS | 8 | ms | S8 | S6's editor acceptance (§11) |

### 16.33 `tests/studio/e2e`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| E2E_READY_TIMEOUT_S | 15 | s | S8 | Mock profile load + plot build, with margin |
| E2E_SANITY_MIN_SCORE | 0.25 | score | S8 | single-sample floor for the Good bot (bands are L3's job) |
| E2E_SUBMIT_MARGIN_MS | 200 | ms | S8 | submit at countdownMs + durationMs + margin after the StartStep reply |

### 16.34 `tools/telemetry_csv`

| Name | Value | Unit | Owner | Rationale |
|---|---|---|---|---|
| TLM_SATURATION_MAX | 0.20 | share | S8 | factor values at ≥ 0.99 or ≤ 0.01 (Q8, Q12 targets) |
| TLM_HARD_SHARE | [0.20, 0.50] | share | S8 | Hard steps among saved designs |
| TLM_HUG_RATIO_MAX | 1.5 | ratio | S8 | designs in D [0.18, 0.22] vs [0.14, 0.18] |
| TLM_DURATION_TOL | 0.30 | relative | S8 | step duration vs design duration |
| TLM_CAPBOUND_SHARE | reported | share | S8 | good players' crafts capped by rarityCap; ≈ 0 % expected at the reference designs (E-S4.7) |
| TLM_BP_Q_RATIO_MAX | 1.5 | ratio | S8 | one blueprint's median Q vs its signature's, ≥ 20 crafts |
| TLM_FLAG_RATE_MAX | 0.001 | per step | S8 | anti-cheat flags |
| TLM_ABANDON_MAX | 0.10 | per step | S8 | abandons |
| TLM_TOP_CODE_MAX | 0.30 | share of saves | S8 | the most frequent validation code |

---

## 17. Open questions

### 17.1 Product questions beyond §0.4

| Id | Question | Default |
|---|---|---|
| O1 | (S1, S7) Displayed and in-progress designs are replicated Parts, so a modified client can copy a design. Accept it, with "Forged by" as attribution (§13.10)? | accept |
| O2 | (S1, S6, S7) No server-wide announcement when a player forges a Rare or Epic item, and no personal-best ribbons, in the MVP? | none (Phase 2 candidate) |
| O3 | (Q8, Q12; S8) Are §14.13's playtest targets right: Hard on 20–50 % of saved designs' steps, ≤ 0.1 % flagged steps, < 10 % abandons per step, the most frequent validation code < 30 % of saves, the cap-bound share reported? | as listed |
| O4 | (Q13; S8) Does "Steel plays slightly tighter" mean an average player scores 1–8 points lower (of 100 %) on Normal steps in Steel than in Iron? | 1–8 points, `STEEL_MEAN_DROP` [0.01, 0.08] (PrecisionTrace measures 0.009, see §17.2 S3) |
| O5 | (Q20; S6) Fonts GrenzeGotisch, Merriweather Bold, BuilderSans Medium, RobotoMono Medium, and a charcoal, parchment and ember UI on a blueprint-blue stage (§12.11, E-S6.14)? | as stated |
| O6 | (S3, S6) No practice mode in the MVP (a local, unscored run of a step's minigame from the forge flow)? | none (Phase 2 hook, §15.2) |

### 17.2 Engineering items

| Owner | Item |
|---|---|
| S1 | Re-run `sizes2.luau` and the budget test with the Phase 2+ item shape before Phase 2 steps ship (2.08 MB exceeds the size block today); re-measure `settings` with `grindToggle` (≈ +20 B, added after the measurement). |
| S1 | Confirm under `--!strict` that `StepRecord` passes where `CT.StepFacts` / `CT.StepRun` are expected (width subtyping); otherwise `Items/Recompute` maps the fields explicitly (S4's request). |
| S2 | Checkpoint gaps: the prototype's longest run between checkpoints is 0.24–0.52 ms Lune (median of 15 runs; up to 1.0 ms with GC, E-S2.8), above S8's `CHECKPOINT_GAP_LUNE_MS` 0.35 (§14.11; with §4.4's verdict median 0.06–0.37 on the fixtures and the worst designs, up to about 0.5 on the worst designs; the long ones end at `MassProps`' GJK, charged 20 units): raise `UNITS_PER_OVERLAP_TEST`, lower `CHECK_UNITS` or add checkpoints until T-PERF-01 passes. S8 tests. |
| S2 | Slivers thinner than a quarter sample patch between near-duplicate parts are under-counted (deflation only; X01 measures +0.0010 against its union blade). Accepted. |
| S2 | What hidden parts can still reach: only a part that really covers another (§4.4). Count, grid, budget and id reach no verdict: C09 + a plate 0.12 × 2 × 0.05 that shows 20.00 % stays kept, Sharpening 0.2542 Hard, with 0 and with 5 hidden blocks, where one pass over all parts cleans it (0.1904 Normal). The limit is the 2 % rule itself, and the truth agrees: hilt + cheeks 1.1 × 2.0 × 0.06 + a core 0.95 wide and 0.02 thick, true 2.01 %, kept; add a sheet 1.08 wide in the same gap, true 1.77 %, over the core's rims, and both are Enclosed: Hammering 0.0374 Normal → 0.3609 Hard, \|ΔD\| 0.3235. On a real sword it does little: C05 + a strip poking 0.003 past the rim, true 5.92 %, + a buried sheet 1.0 × 1.8 × 0.02 with its rim 0.001 further: the strip now shows nothing, the sheet 1.35 %, both cleaned, \|ΔD\| 0.0002. Accepted. |
| S2 | False kept. A flat patch reads what shows: C05 + a buried sheet 1.0 × 2.0 × 0.02 with its rim up to 0.008 past the blade, true 1.74 %, stays cleaned; a climb on 20 lids over a plate got a part kept at 1.77 % true and no lower. A slit that lies along a line of both families reads that line whole: where 2 hairlines cross, ¼ of the patch, which takes a part per side of each crossing. A Cylinder's side keeps its strip credit: a slit through a direction reads ¼ of each patch it passes, whatever its width. It reaches little, since what a Cylinder fills it fills alone: a rod in a solid split by a slit 0.00001 wide, true 0.00 %, reads 6.10 %, kept, \|ΔD\| 0.0000; worst on the plausible set C06 + wrap rings, grip true 0.74 %, Hammering 0.2930 → 0.3180, \|ΔD\| 0.0250, no tier. The lowest true share kept is 0.22 %, a grip under 4 rings with gaps of 0.0005, each read through a patch's centre. Accepted. |
| S2 | The verdict's precision against a truth (E-S2.11; 105,626 designs, 953,279 parts, fullers, combs, walled blades and beads among them; band counts reflect the sweep's density, not how often players do this): cleaned at a true share of 2.5 / 3 / 5 / 7.5 / 10 / 15 / 20 % or more: 320 / 151 / 25 / 19 / 12 / 5 / 0 parts, all of them Balls (the highest 18.59 %), Cylinders (4.45 %) and CornerWedges (4.63 %), kept under 1.5 / 1 / 0.5 / 0.25 %: 104 / 38 / 16 / 5, all but 1 of them Balls and Cylinders; Blocks and Wedges, 651,985 parts, 0 wrong on either band. 0 tier flips, worst \|ΔD\| 0.0964 (the bead below); on the plausible set 0.0250. Accepted. |
| S2 | What the reading cannot see. **A Ball's band**: its samples leave a band of ±11° round each waist, so a Ball d 0.5 between 2 plates, true 18.59 %, reads nothing and is cleaned: \|ΔD\| 0.0964 and no tier on the 264 beads swept, but near a tier's edge it would flip one. **A window on a flat patch**: what shows between 2 lines each way, under ¼ of the patch each way, reads nothing; a climb on 20 lids over a plate got a part cleaned at 4.94 % true and no higher. **A rim**: under 1 % of a patch on a side, inside the corners' reach of a part that hides all five, goes unread. **A Cylinder's side**: a narrow arc between its sub-points, up to 4.45 % true, \|ΔD\| 0.0002. Accepted. |
| S2 | What ids and order still reach. In the build, nothing: any order of a design's parts gives the same verdicts, areas and contact rows to the bit (§4.4). M3's probes are still in part order in the emulator: C09 in 300 random orders, Smelting and Sharpening exact, Hammering 0.3170–0.3195; P5 Hammering 0.1853–0.1902 in 60; 9 other fixtures exact. M3 is to walk its parts in rank order (`Sampling.ranked`), §5.2's probes and budgets included, and bless §5.5 on that. A mirror image keeps every verdict (92,860 images on 4 sets) but for true twins with a face in common, which swap who keeps it: 2 of 8,696 images of pokes into C09's mirrored tip, \|ΔD\| 0.0054, no tier. Accepted. |
| S2 | **[Decision to confirm]** A label moves Sharpening's tier: F3 with its main blade labelled Guard, Sharpening 0.6104 Hard → 0.0645 Normal; C08 0.2487 Hard → 0 Normal; no hidden part is needed, so it is outside the verdict, but §5 says invisible construction choices cannot move a tier, and `Slot` is a free property (§11.10). An exact copy cannot take a part out of the Blade (the Blade's name comes first, so F3 + a copy of its blade in the Guard stays bit-identical); it can bring one in, no more than relabelling does (F3 + a copy of its guard in the Blade, 0.6104 → 0.6770, the relabelled guard's number). Accept it, or tie Sharpening's set to geometry. |
| S2 | Design question for M3: where a core sandwiched between cheeks crosses 2 %, D jumps 0.34–0.47 whatever the precision, because cleaning it opens the chord in Thinness. M3 decides how a cleaned part affects Thinness' chords. |
| S2 | Overlap budget: designs past `N_OVERLAP_WORK` trade accuracy for time. P1, P2 and P4 measure about −10.3, −4.4 and −5.6 % against the union's volume (P1's COM y off by 0.021); with the budget lifted, within about 1.2 %. `TOL_MASS_REL` and `TOL_BALANCE_ABS` hold for designs within the budget (the F, C and X fixtures), not for P1–P5. |
| S2 | The cost of the verdict and the measure (`Analyze.run` with M3's share emulated, Lune, median of 21; Studio assumed 2.6 × Lune, not measured; this machine runs about 9 % slower than the runs of E-S2.8): fixtures and specks stay under 33 ms (F5 4.3 ≈ 11 Studio, C09 13.7, C05 14.2 ≈ 37, P3 + a speck 19.3, P2 + a speck 22.5, P1 + a speck 30.2, P1 31.7 ≈ 82). Designs climbed against the verdict's counted shape queries, and made legal, reach 54.6 ms ≈ 142 Studio, the verdict alone 30.7 ≈ 80, against §4.9's 75 ms ceiling (`docs/spec/prototypes/S2/verdict/worst_P.json`, 11 canonical, valid designs; 7 climbs of 12,000 to 25,000 evaluations and hand-built bundles of rods; under the reading before the lines the same climbed designs reach 76.7 and 35.6). So the ceiling is met on real designs only, and §4.9's fallback does not reach the verdict: hidden parts cost time but no outcome, each is read on its full grid, and a budget that counted near parts would be the hidden-part channel again. There is no formal bound below about 70 patches × 8 lines × 2 chords × 23 near parts per part, or 128 × 25 × 23 on a thin Cylinder. Most of what that bound allows is not spent: a part that cannot reach a patch on its own 3 axes is dropped before the lines, and a line ends when it is covered. **[Decision to confirm]** with no designer to ask at M2: a hostile design takes about 142 ms Studio, sliced at 4 ms a Heartbeat, about 36 Heartbeats, no frame hitch, one job per player; raise the 75 ms instead if it is meant for every design. T-PERF-01 and S-PERF-01 run P1, the specks and `worst_P.json`. |
| S2 | Grip axis: the no-vote rule is a step at 45°: a grip part crossing it drops its whole vote at once (F4 + equal parts at −45.1° and +44.9° about its grip: axis −22.45°, balance 0.634; at ±45°: axis 0°, balance 0.740), and a small strap beside a level bar sets the whole axis, as on a ring grip (A26). D is unaffected: its frame is fixed at +Y. Accepted unless playtests find it. |
| S3 | PrecisionTrace's Average Iron − Steel drop on Normal is 0.009 (§6.13: 0.633 → 0.624), below `STEEL_MEAN_DROP`'s 0.01 floor (§14.6); HoldZone (0.016) and TimingStrike (0.012) pass. Retune the Steel column or lower the floor with S8 (O4). |
| S3 | Replace the bot models with playtest distributions from `StepScored` and retune `Definitions/MinigameFamilies` (one `BALANCE_VERSION` bump); tune the Expert…Hell placeholder columns before Phase 2; keep trace half-widths ≥ 0.0156 (band ≥ 12 px at 720p; the MVP minimum is 0.034). |
| S3 | Re-measure the `PtTooPrecise` human minimum over `FP_RUNS` runs on the 30 fps / 360 px device (3,000 runs give 0.0028 u, ×3.5, against §14.8's 3 × `PT_PRECISE_MEAN_DEV` floor); if it nears 3 ×, retune `PT_PRECISE_MEAN_DEV` (with S8). |
| S4 | Re-fit rarity thresholds, γ and Steel T from playtest telemetry (`CraftCompleted`, `StepScored`) once real score distributions exist. |
| S5 | Re-run `session_scenarios.luau` under §7.6's abort rule for early submits and wrong-session or wrong-step submits (E-S5.2 ran the earlier refuse-and-continue rule). |
| S5 | Name the pure dispatch-order helper in `Net/` that T-NET-04 tests (§10.3). |
| S5 | `Minigames.judge` runs synchronously in Submit: if S-PERF-01 measures it above `REPLAY_BUDGET_MS` × 2.6 in the Studio server, S3 adds a checkpoint and CraftService moves it into the AnalysisQueue (with S3). |
| S5 | Measure join latency with a capped profile and raise `REPLY_PAGE_BYTES` if paging adds latency (with S8). |
| S5 | Tune `FLOOD_KICK_DROPS_PER_MIN`, `HARD_STRIKES_KICK`, `LATE_SOFT_MS` and `LATE_HARD_MS` (a 10 000 ms alternative, E-S5.3) from playtest telemetry; re-count AnalyticsService field combinations once flag and rarity ids are final (≈ 1 250 of 8 000, E-S5.9); watch AnalysisQueue wait and slice times (`Perf`) and take the Actor hook if Save or Begin replies take more than a few seconds. |
| S5 | Configure and test the right-to-be-forgotten deletion template for `PlayerData` / `User_{UserId}` (README checklist, §1.4). |
| S6 | Define the bridge's read-only UI state query (screen, editor preview summary, minigame view) and the controller actions behind `loadBlueprint` and `openStation` (§12.5, §14.10; with S8). |
| S6 | Re-check the orthographic read-back on the shipping client; while it fails, S8 runs the editor scenarios on the telephoto path. Pick the 14 audio ids from Roblox-published Creator Store sounds and check their licence lines. |
| S7 | Define the named camera framings for the bridge's `cameraShot` (S-VIS-01…09; with S8). Confirm that the invisible, non-colliding `HomeSpawn` puts first spawns and respawns on the floor at the home pose (S-E2E-02, ≤ 10 studs) and that §13.7's Wedge and CornerWedge vertex sets match Roblox's rendered shapes before the bounds goldens freeze (with S8). |
| S7 | If `MIN_DIM` or `MAX_DIM` is ever tightened after launch, records kept under the older bound (§9.6) fail `RenderPlan`'s size check (`BadSize`) and show the placeholder: decide then whether the builder accepts stored sizes (with S1). |
| S8 | Measure the analysis in the Studio server DataModel on the final modules (S-PERF-01) and apply §4.9's fallback above 75 ms on real designs; confirm bit-identical factor digests Lune vs Studio client vs server (no FMA contraction, `--!native` off); confirm the double round trip on a live DataStore key and the JSONEncode length model (S-PAR-03, with S1). |
| S8 | Tool and engine facts to verify in the build: **V-01** luau-lsp flags at the pinned version (named definitions, sourcemap, `--ignore`, `--formatter`, exit code), checked with `--help` and a planted type error · **V-02** Lune typedefs for luau-lsp pass B (`lune setup`, the `lune` alias; commit `tests/.luaurc`) · **V-03** whether `execute_luau` shares the game's module cache · **V-04** `screen_capture` honours a camera set by a client snippet (with S7) · **V-05** timing precision of `user_keyboard_input` (sets S-E2E-12's offsets) · **V-06** `execute_luau` time limit for yielding snippets · **V-07** buffers replicate through RemoteEvents intact (S5) · **V-08** releases while the Esc menu is open reach the game and `MenuOpened` fires on Esc (S3, S6) · **V-09** engine shape conventions and float survival (S-PAR-01, S-PAR-03; S2, S1). |

### 17.3 Carried from the design draft

1. **Standalone or part of the forge and mining project?** MVP: standalone; the pure modules are portable (Q1).
2. **What are items for after crafting?** MVP: display only (Q1); Phase 4 adds combat or a test dummy through the
   welded render mode (§15.4).
3. **Few weapon types in depth, or many?** Open for Phase 3; the data model supports either (one `EquipmentTypes` row
   plus one `CraftPlans` entry per type).
4. **Does a failed Hell step destroy the material, the item, or only lower quality?** Open for Phase 2. Material loss
   needs a material economy, which the roadmap adds only in Phase 4: decide whether Phase 2 brings a minimal
   inventory or Hell destroys the item instead.
5. **Can blueprints be shared or copied?** Open for Phase 3 (records are self-describing; no MVP UI). Note O1: a
   modified client can already copy a displayed design.
6. **How are materials obtained?** Open for Phase 4; free in the MVP (an `inventory` field comes by migration).

| Draft risk | Spec mitigation | Owner |
|---|---|---|
| Content explosion | three parameterized families; materials and tiers are parameter columns (§6.5) | S3 |
| Stat balance | one main stat per step, simulated rarity targets, goldens and one BALANCE guard, playtest telemetry (§8, §14.9, §14.13) | S4, S8 |
| Design vs craft (physics) | physics once per blueprint on the server; mass, balance and reach only; cleaning stops filler (§4) | S2 |
| Showcase bias toward looks | a Forging record on every inspect; categories in Phase 3 (§13.10, §15.3) | S7 |
| Cheating | server replay with fixed seeds, rate limits, inhuman-input clamp; human-like bots accepted while items are display-only (§10) | S3, S5 |
| Platform | PC only; trackpad and AZERTY checks (M-08) | S6, S8 |
| Scope | one sword; editor cuts and deferred features listed in §15 | all |

---

## 18. Implementation milestones

> Build bottom-up along §1's layers and prove the riskiest engine facts early: shape conventions (M2), Lune ↔ Studio
> determinism (M3) and the ProfileStore lifecycle (M7). Coding starts after the designer signs off this SPEC (§0).

Every milestone ends with `scripts/verify` green (L0–L2, plus L3 when it touches `Minigames/` or `Crafting/`) and
its Studio scenarios passing in 3 fresh Play sessions (§14.10).

| M | Build (owner) | Exit tests |
|---|---|---|
| M0 Toolchain | repo tree (§1), `aftman.toml` (lune, rojo, luau-lsp), `default.project.json` with `Remotes.model.json` and the nested ProfileStore project, hand-written `test.project.json`, runner, `tests/lib`, `scripts/verify` (S8, S5) | T-META-01…08 on stubs; `rojo build` of both projects |
| M1 Data contracts | `Definitions/*` incl. `Manifest`, `Validate`; `Util/Quantize`; `Blueprint/{Schema, Canonical, Quat, Names, Views}`; fixtures F1–F5, A01–A24 (S1, values S2–S4) | T-DEF, T-UTIL, T-BP-01…05/12/13, T-UD-01, T-BAL-01/02 |
| M2 Geometry core, engine parity | `Physics/{Shapes, Gjk, Sampling, MassProps}`, validation in `Analyze`, `Blueprint/{Mirror, WorkSet}`; minimal `ItemRender/RenderPlan` + `ItemModelBuilder` (S2, S4, S7) | T-PHY, T-VAL, T-BP-11/14, S-PAR-01 |
| M3 Difficulty | `Physics/{Edge, Factors, Difficulty, Analyze}`; fixtures C01, C02, C04–C15, A25–A27, X01–X08, P1–P5 (S2, S8) | T-EDG, T-DIF; S2's §5 table blessed for every fixture (from `Analyze.run`); T-PERF-01; first S-PAR-02 digest of `Analyze.run` |
| M4 Minigames | `Minigames/*` incl. the facade and `Bots` (S3) | T-RNG, T-MG with L3, T-PERF-02 |
| M5 Crafting and items | `Crafting/*`, `Pipeline`, `Items/*` (S4, S2, S1) | T-CR with L3, T-PIPE, T-ITM; S-PAR-02 with outcomes |
| M6 World | `World/Layout`, `WorldBuilder`, `PlotWorld`, full `ItemRender`, `Showcase/{ShowcaseRules, InspectView}` (S7) | T-WLD, T-RND, T-SHW, T-INS; S-VIS-01 |
| M7 Headless server | `Net/{Protocol, Guard, RateLimit}`, `Session/SessionMachine`, `Persistence/*`; then `DataService` (Mock), `Router`, `Handlers`, `BlueprintService`, `AnalysisQueue`, `CraftService`, `PlotService`, `Lifecycle`, `Log`, `Telemetry`, `ShowcaseService`, `TextFilter`, server bridge; `Net/Client` and the client bridge commands `call`, `rawFire`, `awaitPush` (S5, S1, S7) | T-NET, T-SES, T-PER, T-PERF-03; S-E2E-01/02/03/04/05/07/08/09/10/11/13 without UI; S-VIS-06; S-PERF-01 (server) |
| M8 Client | UI kit, `EditorCore/*` (T-ED first), `Editor/*`, `PreviewScheduler`, `Forge/*`, `Minigames/{MinigameHost, InputCapture, views}`, `Inventory/*`, `Onboarding/*`, `Smithy/*`, client bridge (S6, S7) | T-ED; S-E2E-06/12; S-VIS-02…05/07/08/09; S-PERF-01 (client); M-09 |
| M9 Playtest and Done | audio ids, polish, `tools/telemetry_csv.luau`, the private test experience (S6, S8) | M-01…M-08, S-PAR-03/04 with M-06, §14.13 targets; §14.12 Definition of Done |

Phase 2 hook: later phases add rows after M9 (new families plug into M4's facade and bots, new steps into
CraftPlans and M5's goldens).
