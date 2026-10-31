# Blacksmithing Game — Spec evidence appendix

> Roblox · Rojo 7.7.0-rc.1 · Luau --!strict · ProfileStore · Evidence for Spec v1.0 · 2026-10-31

Evidence cited from `SPEC.md` as `Evidence: E-Sx.y` or `(E-Sx.y)`: calibration tables, simulation outputs, proofs,
prototype logs and the alternatives that were measured. Prototype paths are relative to `docs/spec/prototypes/<S>/`
(Lune 0.8.9: `lune run <file>`), for example S8's `v2/checkreq.luau` (copied from the R7 review for T-META-07),
`studies/fixtures_bp.luau`, `studies/anticheat_bots.luau`, `studies/kat_xorshift32.py` and `repo/tests/run.luau`.
S1–S8 are the section owners listed in SPEC §0.3. Review finding ids (such as `R1-04`) appear only in this appendix
and refer to `docs/spec/review/findings-all.md`. Section numbers (§N.M) refer to `SPEC.md` (at the repository root).

---

## Contents

1. [Evidence S1](#evidence-s1) (data model, blueprint data, persistence data): [E-S1.1](#e-s11-canonical-form-idempotency-and-the-renormalization-threshold) · [E-S1.2](#e-s12-rotation-matrix-and-the-instance-round-trip) · [E-S1.3](#e-s13-json-storage-precision) · [E-S1.4](#e-s14-size-budget-sizes2luau--sizes2outtxt) · [E-S1.5](#e-s15-names-namesluau--namesv1outtxt-unchanged-by-the-revision) · [E-S1.6](#e-s16-migration-order-migrateluau--migratev1outtxt) · [E-S1.7](#e-s17-material-rows-phase-2-rows-blurbs-and-rationale) · [E-S1.8](#e-s18-mass-display-check-r4a-22) · [E-S1.9](#e-s19-size-guard-thresholds-and-the-per-key-write-limit)
2. [Evidence S2](#evidence-s2) (geometry and difficulty): [E-S2.1](#e-s21-shapes-against-the-engine) · [E-S2.2](#e-s22-min_dim--002-and-sensitivity-mindim-checksluau) · [E-S2.3](#e-s23-contact) · [E-S2.4](#e-s24-why-no-global-grid) · [E-S2.5](#e-s25-regression-fixtures-base-f5-reg-checksluau) · [E-S2.6](#e-s26-mirror) · [E-S2.7](#e-s27-grip-independent-difficulty-and-the-two-deviations-adv-variantsluau) · [E-S2.8](#e-s28-performance-and-checkpoints-perf-gapsluau) · [E-S2.9](#e-s29-calibration-and-the-full-fixture-tables) · [E-S2.10](#e-s210-validation-invariance-determinism-val-inv-det)
3. [Evidence S3](#evidence-s3) (minigames): [E-S3.1](#e-s31-prng-test-vectors-unchanged-module-cross-checked-bit-for-bit-against-the-python-reference-rng_refpy) · [E-S3.2](#e-s32-final-bot-table-distluau-2000-outfinal_tabletxt) · [E-S3.3](#e-s33-full-parameter-columns-and-resolved-values-paramsluau-goldenluau) · [E-S3.4](#e-s34-timingstrike-golden-values-and-grade-bands-goldenluau) · [E-S3.5](#e-s35-precisiontrace-edge-mapping-golden-values-and-costs-costluau-worstluau-goldenluau) · [E-S3.6](#e-s36-determinism-and-codec-detluau) · [E-S3.7](#e-s37-holdzone-why-strokes-hztuneluau-goldenluau) · [E-S3.8](#e-s38-check-margins-and-cheats-checksluau) · [E-S3.9](#e-s39-tuning-log-multisweepluau-sweepluau-2003000-runs-per-setting)
4. [Evidence S4](#evidence-s4) (crafting and outcome): [E-S4.1](#e-s41-stat-constants-rationale-ranges-placeholders) · [E-S4.2](#e-s42-fixture-inputs-and-outcomes-s2-live-analysis) · [E-S4.3](#e-s43-golden-outcome-cases-t-cr-02-weights-025--040--035-pass--050) · [E-S4.4](#e-s44-γ-gamma_fit-bold-s3s-code-1000-runs-per-cell-600-for-precisiontrace-same-seeds-at-every-x) · [E-S4.5](#e-s45-properties-and-the-recompute-check) · [E-S4.6](#e-s46-sensitivity-thresholds-055--084--104) · [E-S4.7](#e-s47-grid-search-and-the-full-rarity-table-simluau-tune-table) · [E-S4.8](#e-s48-cap-rule-alternatives-r3-05-designer-default-q10--max)
5. [Evidence S5](#evidence-s5) (server, networking, persistence lifecycle): [E-S5.1](#e-s51-guard-fuzz-and-cost-guard_fuzzluau-libguardluau) · [E-S5.2](#e-s52-session-machine-scenarios-session_scenariosluau-libsessionmachineluau) · [E-S5.3](#e-s53-timing-model-timing_simluau) · [E-S5.4](#e-s54-analysisqueue-arithmetic) · [E-S5.5](#e-s55-rate-limits-ratelimit_simluau-libratelimitluau) · [E-S5.6](#e-s56-rojo-project-verification) · [E-S5.7](#e-s57-payload-sizes-and-paging-payload_sizeluau-s1s-measured-json-sizes) · [E-S5.8](#e-s58-save-cadence-and-datastore-budgets) · [E-S5.9](#e-s59-telemetry-volume-and-field-combinations) · [E-S5.10](#e-s510-alternatives-considered)
6. [Evidence S6](#evidence-s6) (client UX: editor, forge UI): [E-S6.1](#e-s61-stage-scale-containment-and-camera-fit-camera_fitluau) · [E-S6.2](#e-s62-ui-scale-and-layout-fit-ui_scaleluau) · [E-S6.3](#e-s63-snap-cleaning-for-any-positive-step-snap_cleanluau) · [E-S6.4](#e-s64-gizmo-jitter-and-the-custom-handles-gizmo_mathluau) · [E-S6.5](#e-s65-euler-display-round-trip-euler_quatluau) · [E-S6.6](#e-s66-history-memory-history_memluau) · [E-S6.7](#e-s67-mirror-exactness-mirrorluau-mirror_quatluau) · [E-S6.8](#e-s68-orthographic-read-back-and-telephoto-fallback-r5a-01) · [E-S6.9](#e-s69-forge-pacing-flow_timingluau) · [E-S6.10](#e-s610-trace-canvas-band-widths-and-mapping) · [E-S6.11](#e-s611-platform-facts-used-creator-docs-checked-in-review) · [E-S6.12](#e-s612-player-facing-copy-initial-uistrings) · [E-S6.13](#e-s613-preview-panel-example-illustrative-values) · [E-S6.14](#e-s614-theme-tokens-initial-values-rgb)
7. [Evidence S7](#evidence-s7) (smithy world, rendering, inspect): [E-S7.1](#e-s71-build-list-definitionsworld-data) · [E-S7.2](#e-s72-world-checks-checks_worldluau-results_worldtxt) · [E-S7.3](#e-s73-budgets) · [E-S7.4](#e-s74-render-checks-render_plan_partdataluau-render_planluau-render_plan_nativeluau) · [E-S7.5](#e-s75-test-cases-for-14) · [E-S7.6](#e-s76-presentation-data-definitionspresentation) · [E-S7.7](#e-s77-platform-facts-relied-on) · [E-S7.8](#e-s78-changes-from-the-draft-for-0)
8. [Evidence S8](#evidence-s8) (testing and verification): [E-S8.1](#e-s81-lune-089-facts-runner-prototype-require-resolver) · [E-S8.2](#e-s82-testprojectjson) · [E-S8.3](#e-s83-fixtures-f1f5-and-the-independent-oracle) · [E-S8.4](#e-s84-adversarial-and-regression-fixtures) · [E-S8.5](#e-s85-case-catalogue) · [E-S8.6](#e-s86-studio-bridge-scenario-assertions-shots-manual-steps) · [E-S8.7](#e-s87-statistical-sizing) · [E-S8.8](#e-s88-slice-and-checkpoint-arithmetic) · [E-S8.9](#e-s89-traceability-what-other-sections-expect-from-s8) · [E-S8.10](#e-s810-names-changed-from-the-draft)

---

## Evidence S1

Prototypes are cited relative to `docs/spec/prototypes/S1/` (Lune 0.8.9, `lune run <file>`). Files ending in
`.v1.out.txt` are the draft's runs (storage grid, `B<n>` ids, 48 parts), kept for comparison; the revision's runs are
`canon2`, `sizes2`, `renorm_drift`.

### E-S1.1 Canonical form: idempotency and the renormalization threshold

`canon2.luau` → `canon2.out.txt`. 10⁶ random parts: editor-like unit quaternions, sloppy clients (norm off by up to
4e-3), quaternions right at the 1e-9 threshold, near the 1e-2 input tolerance, axis-aligned, qw = 0, −0 components.

| Measure | Result |
|---|---|
| bit-exact idempotency failures (−0 distinguished) | **0 / 1,000,000**; rejected 0 |
| branch counts | kept as given 750,209 · renormalized 249,791 · hemisphere flips 474,555 |
| max \|‖q‖² − 1\| after one renormalization | 6.661e-16 (threshold 1e-9; kept-branch max 1.000e-9) |
| max orthonormality error of R(q), s = 2/\|q\|² | 1.332e-15 |
| bound edge cases (±16, MIN_DIM, MAX_DIM, just outside) | 0 / 9 wrong |
| S2 hook | Ball {0.3, 0.5, 0.4} → {0.3, 0.3, 0.3}; Cylinder {1, 0.3, 0.2} → {1, 0.2, 0.2} |
| −0 | `pos[1] = −0` → `0` (1/x = +inf); `rot {−0, 0, 0, 1}` → `{0, 0, 0, 1}` |

`renorm_drift.luau` → `renorm_drift.out.txt`: why C3 has a threshold. Of 200,000 editor-like unit quaternions
(max |‖q‖² − 1| = 5.6e-16), a second `q / ‖q‖` changes the bits of **66,468 (33.2 %)**, and 2,062 still change after
10 passes. An always-renormalize rule would rewrite a third of the stored rotations on every save and never settle;
with the 1e-9 threshold none of them is touched.

Proof sketch (§3.5): C1/C2/C7 are predicates and a sort; C3's output is within a few ulps of unit, below the
threshold, so the next pass keeps it; C4 negates exactly (norm unchanged) and its sign test then holds; C5 and C6
(min side) are fixed points. Draft comparison (`canon.v1.out.txt`): the 1e-4 / 1e-6 grid was also idempotent (0 /
200,000) but moved corners by up to 9.06e-5 stud, ≈ 0.42 px at S6's maximum zoom (R5a-15), which the review removed (§3.5).

### E-S1.2 Rotation matrix and the Instance round trip

- R(q) with s = 2/|q|² equals `CFrame.new(0, 0, 0, qx, qy, qz, qw):GetComponents()` to 6.2e-7 over 2,000 random
  quaternions (Studio probe, read-only `execute_luau`; CFrame rotations are float32). Orthonormality: E-S1.1.
- float32 round trip (`canon2`, 1 part in 10 sampled): position components changed 292,308 / 300,000 (97.4 %, max
  4.77e-7 stud); rotation components changed 400,000 / 400,000 (max 2.98e-8). Hence §3.4: Instances are views; the
  editor model is the plain table.

### E-S1.3 JSON storage precision

- `canon2`: 0 round-trip failures over 200,000 doubles printed with 17 significant digits.
- Studio probe of `HttpService:JSONEncode` (2026-10-31): shortest round-trip digits, ECMAScript number layout
  (plain for 1e-6 ≤ |x| < 1e21), `"-0"` for negative zero (folded by C5), `{}` → `[]`, UTF-8 raw; NaN and ±inf are
  encoded silently as `{"m":null,"t":"numeric","v":"nan"}`-style objects (hence the finiteness rules).
- `sizes2` encoder vs Studio: 0 / 24 length mismatches on probe values; in bulk (6 classes × 3,000 numbers) Studio
  prints +0…3 characters per class (≤ 0.005 %) with the same maximum length. Longest legal numbers: position 25
  characters (`-0.0000021366226676248005`), tiny quaternion component 25, qw 18, size 20.
- `GenerateGUID(false)` returns 36 characters (Studio probe); the server upper-cases ids, so case never matters.

### E-S1.4 Size budget (`sizes2.luau` → `sizes2.out.txt`)

Shapes: the §9.3 / §9.4 records, camelCase, raw-double transforms, GUIDs, `MAX_PARTS` 24. Worst = Pommel /
CornerWedge / Obsidian part with 25-character numbers, 64-byte names (32 × "é"), 8 issues, 6 flags per step,
`displaySlot` 6, 64 uiFlags of 32 bytes, 300-B ProfileStore wrapper. Typical = Move/Scale-snapped values, 1 part in
3 freely rotated.

| Record | N = 4 | N = 12 | N = 24 |
|---|---|---|---|
| blueprint record, worst / typical | 2,079 / 1,114 | 4,767 / 2,200 | 8,799 / 3,900 |
| item record MVP worst / Phase 2+ worst / typical | 3,012 / 4,626 / 1,946 | 5,700 / 7,314 / 3,032 | 9,732 / 11,346 / 4,732 |

Part 335 B worst, 113 B axis-aligned, 184 B rotated. Step record 298 B with 6 flags, 201 B without. Owner item view
9,438 B. Template 399 B; settings 230 B default, 318 B worst; uiFlags 2,561 B worst.

| Profile (P = 24) | Bytes | % of 4,194,304 |
|---|---|---|
| 40 / 150, MVP item shape | 1,822,966 | 43.5 |
| 40 / 150, Phase 2+ item shape (8 steps, 9 stats) | 2,076,306 | 49.5 |
| 60 / 250 · 80 / 300, MVP shape | 2,976,946 · 3,642,326 | 71.0 · 86.8 |
| 40 / 150 full of typical editor parts | 892,719 | 21.3 |
| typical heavy player (15 / 80, 12 parts) | 280,319 | 6.7 |

Formula (P ≥ 1) `W = 3,606 + B·(775 + 336·P) + I·(1,708 + 336·P)`: records of 735 B and 1,668 B plus 336 B per part
(the empty records measure 736 B and 1,669 B) and a 40-B map key each; the Phase 2+ item record is 3,282 B + 336 B per
part. It reproduces the measured 40 / 150, 60 / 250 and 80 / 300 cases exactly (the script's own check, which uses
335.96 B per part, prints 1,822,968). Wire: draft 8,175 B (+54 B `blueprintId` envelope); `BlueprintSummary` 735 B;
`ItemSummary` 277 B; summaries at caps 70,950 B.

Draft comparison (`sizes.v1.out.txt`): the grid saved ≈ 40 % per part only at the 48-part placeholder; at 24 parts
raw doubles keep 40 / 150 inside the 50 % target, which is why the caps are unchanged (R2-01, R4a-15).

### E-S1.5 Names (`names.luau` → `names.v1.out.txt`, unchanged by the revision)

Accepted: `"Épée du Roi"` (11 cp, 13 B), `"   Big    Sword  "` → `"Big Sword"`, `"Œuvre d'Ætheling"`, `"Łódź Blade #2"`,
32 × "a", 32 × "é" (64 B). Rejected: `"<b>Sword</b>"`, zero-width space, emoji, tab, decomposed `e + U+0301`,
`"Multiplication × sign"` → `BadChar`; 33 characters → `TooLong`; `"..."` → `NoAlnum`; `""` → `Empty`; invalid bytes →
`InvalidUtf8`.

### E-S1.6 Migration order (`migrate.luau` → `migrate.v1.out.txt`)

A v1 profile written before the version field existed in the template, with two test migrations (v1 → v2 splits
an item field into `Rarity` + `RarityAtForge`; v2 → v3 renames a counter): migrate-then-reconcile ends at version 3
with the migrated values (`Rare`, counter 7); reconcile-then-migrate also ends at version 3 but with
`RarityAtForge = nil` and the counter reset to 0, because reconcile filled the version from the template and every
migration was skipped. A version-4 profile on a version-3 server is refused (`Newer`). (The draft's PascalCase
names; the order rule is independent of casing.)

### E-S1.7 Material rows: Phase 2 rows, blurbs and rationale

Rows with `enabled = false` (same shape as §2.5; owner columns filled by S2 and S4 when enabled; S4's `qualityTier` placeholders: E-S4.1):

| id | order | class | density | hardness | toughness | color | robloxMaterial | reflectance |
|---|---|---|---|---|---|---|---|---|
| `Bronze` | 3 | Metal | 8.80 | 30 | 70 | 176, 124, 64 | Metal | 0.10 |
| `Mithril` | 4 | Metal | 3.20 | 75 | 72 | 182, 222, 236 | Foil | 0.30 |
| `Obsidian` | 5 | Mineral | 7.20 | 92 | 8 | 34, 26, 44 | Glass | 0.25 |
| `Wood` | 6 | Organic | 0.65 | 25 | 45 | 120, 82, 50 | Wood | 0 |
| `Leather` | 7 | Organic | 0.90 | 20 | 55 | 90, 58, 38 | Leather | 0 |

| id | blurb (tooltip, from the design draft) |
|---|---|
| Iron | Reliable baseline, forgiving minigames |
| Steel | Better edges, slightly tighter windows |
| Bronze | Heavy and durable, poor edge |
| Mithril | Light and strong, very tight windows |
| Obsidian | Brutal edge, shatters on failure |
| Wood, Leather | Grips, hafts and light armor |

- Iron 45/50: dead-centre Medium, the baseline everything else is read against.
- Steel 70/55: High hardness is its identity (edges); toughness +5 so it is never strictly worse.
- Densities: real ratios (Steel 7.85 vs Iron 7.87, Bronze 1.12 × iron, Wood 0.65, Leather 0.90), so an Iron/Steel
  swap never changes mass noticeably; Mithril 3.20 is light but clearly metal; Obsidian keeps the draft's Medium
  density (real ≈ 2.4) because the draft's identity wins.
- Render values are S7's proposal merged into one set (R1-47): dark matte iron vs bright polished steel on the same
  `Metal`; Mithril `Foil`, Obsidian `Glass`, Wood and Leather native materials (`Enum.Material.Leather` checked in
  Studio). Rarity colours are S7's; tier colours escalate green → crimson (S6 may restyle).

### E-S1.8 Mass display check (R4a-22)

The draft's example sword (1.32 kg) was 5.05 studs long and did not fit S2's 5.0-stud hitbox. S2's reference designs
in Iron: arming sword 0.83 kg, rapier 0.42 kg, dagger 0.34 kg, greatsword 1.52 kg (S2 calibration run). Real arming
swords weigh 1.1–1.5 kg, so "typical swords about 0.8–1.5 kg" is what players will see; no display scale factor is
added.

### E-S1.9 Size-guard thresholds and the per-key write limit

Saves per key per minute: at most one coalesced explicit save (`SAVE_MIN_INTERVAL_S` = 60, S5) plus at most one
ProfileStore autosave (300 s period) can fall in the same minute: 2 writes. With the documented 4 MB/min per-key
write limit, 2 × W ≤ 4,000,000 ⇒ W ≤ 2,000,000 B = `PROFILE_SIZE_BLOCK_BYTES`. The MVP worst case (1,822,966 B)
gives 3.65 MB/min. `PROFILE_SIZE_WARN_BYTES` = 1,000,000 B (about 55 % of the worst case; telemetry only) flags
unusually heavy profiles early. The draft's "2 MiB can be written twice a minute" was wrong (4.19 MB/min).

---

## Evidence S2

Prototype: `prototypes/S2/v2/` (Lune 0.8.9; `run.luau -- cal golden adv reg val inv det mirror mindim perf`), the
reference implementation for the goldens. Outputs: `out_v2.txt` (correctness: 35 checks pass, 0 fail),
`out_v2_perf.txt`, `out_v2_gaps.txt`, `out_v2_tables.md`, `out_v2_variants.txt`, `out_v2_checks.txt`, `out_raw.csv`
(range-fit input for `calib.py`, `calib2.py`). Fixtures: `fixtures.luau` (C01–C15 calibration swords, F1–F5 in S8's
§14 coordinates, A25–A27, X01–X07, validation cases, perf P1–P5). The v1 prototype and its `out_final.txt` stay in
`prototypes/S2/` for comparison.

### E-S2.1 Shapes against the engine
Studio read-only probe (unparented parts, Plastic density 0.7), unchanged from the draft:

| Probe | Engine | Model |
|---|---|---|
| Wedge 2×4×6 | mass 16.80 (½ block), CoM (0, −0.6667, +1.0000) | (0, −hy/3, +hz/3) |
| CornerWedge 2×4×6 | mass 11.20 (⅓ block), CoM (+0.25, −1.00, −0.75) | (+hx/4, −hy/2, −hz/4) |
| Cylinder 4×2×3 and 4×3×2 | mass 8.79646 both | π·1²·4·0.7: diameter = min(Y, Z), length = X |
| Ball 1×2×3 and 3×2×1 | mass 0.36652 both | (π/6)·1³·0.7: diameter = min |
| Block 0.0001×1×1 | Size read back 0.001 | engine minimum 0.001 (MIN_DIM 0.02 is far above it) |

### E-S2.2 MIN_DIM = 0.02 and sensitivity (`mindim`, `checks.luau`)
F5 with its blade (no tip) at decreasing thickness: mass is exact (Δ = 0.03274 per 0.01 = 7.87 × 0.16 × 2.6 × 0.01),
Thinness rises continuously and saturates where τ ≤ L/130; the raster does not depend on thickness.

| Blade thickness | 0.060 | 0.050 | 0.040 | 0.035 | 0.030 | 0.025 | 0.020 |
|---|---|---|---|---|---|---|---|
| mass | 0.79017 | 0.75743 | 0.72469 | 0.70832 | 0.69195 | 0.67558 | 0.65921 |
| Thinness All / Blade | 0.243 / 0 | 0.398 / 0.082 | 0.629 / 0.235 | 0.795 / 0.345 | 1 / 0.490 | 1 / 0.694 | 1 / 1 |
| EdgeLength | 5.3404 | 5.3404 | 5.3404 | 5.3404 | 5.3404 | 5.3404 | 5.3404 |
| Hammering d | 0.0973 | 0.1591 | 0.2518 | 0.3180 | 0.4000 | 0.4000 | 0.4000 |

- A 0.02 × 2.6 × 0.02 needle at x offsets 0 … 0.015 (sub-cell): EdgeLength 5.2216 / 5.2000 (±0.4 %), volume exact.
- Blades 0.02–0.05 wide × 0.03 thick: EdgeLength 5.22–5.26. A23 (0.02 plate) and A24 (needle) are valid and finite;
  A24's Thinness is 1.000 on both sets, never above.
- Verdict: 0.02 measures cleanly (every part keeps ≥ 2 samples per axis, overlaps are exact for polyhedra, the
  dilated raster resolves a 0.02 feature). MIN_DIM stays 0.02.
- Real edits: arming blade +0.15 / +0.20 / +0.25 → Sharpening 0.1889 / **0.2056** / 0.2314; F5 blade 0.050 / 0.047 /
  **0.045** thick → Hammering 0.1658 / 0.1895 / **0.2070**.

### E-S2.3 Contact
GJK `within` is unchanged from v1: targeted cases correct (flush, 0.005 gap → contact, 0.015 → none, edge on face,
crossed edges, ball on face, rotated cylinder at 0.009 / 0.012, CornerWedge apex), 300 random pairs agree with
brute-force point-pair distances in 256/256 decisive cases, mean 3.1 iterations, max 9 (`prototypes/S2/test_gjk2.luau`).
v2 adds `Gjk.distance` for floating components (pommel 0.03 below the grip: gap 0.0300, dir (0, 1, 0), nearest #2).

### E-S2.4 Why no global grid
A 0.20 × 2.50 × 0.06 blade (exact volume 0.03000) on a 0.05 global cell-centre grid measures 0.0500 (+67 %) at z
shifts 0–0.005 and 0.0250 (−17 %) at 0.010–0.025; per-part sampling gives 0.03000 everywhere (v1 prototype).

### E-S2.5 Regression fixtures (base F5; `reg`, `checks.luau`)

| Fixture | Result | Bound |
|---|---|---|
| X01 2 blade copies at z ±0.003, vs the union blade (0.066 thick) | ΔD max 0.0002 (vs F5: Hammering −0.0281, the real thickening) | 0.01 |
| X02 6 copies at z = k·0.002, vs the union blade (0.072) | ΔD max 0.0005 | 0.01 |
| X03 F4 + a 0.0003 stud³ fin | ΔThinness 0.0000, Hammering +0.0003 | 0.02 |
| X04 4 strips; strips with seams at ±0.05 and 0; 5 and 10 segments with 0.004 / 0.006 / 0.009 gaps; grip nudges 0.005–0.020 | EdgeLength 5.4330 in every case (0.00 %), one chain | 2 % |
| X05 5 segments, gaps 0.002–0.009, overlaps 0.005–0.05 | ΔG max 0.0007 | 0.01 |
| X06 blade offset 0–0.05 in X vs a 120-probe oracle | max error 0.0030 (Asym Blade 0 / 0 / 0.040 / 0.153 / 0.280 / 0.408) | 0.02 |
| X07 laminates 2 × 0.03, 2 × 0.035 overlapping 0.01; 4 segments overlapping 0.07 | ΔG max 0.0007; mass 0.000 % / 0.000 % / −0.014 % (a real, 0.01 shorter union) | 0.01, 0.5 % |
| A16 F1 + parts inside blade and guard; A17 F2 + 3 exact blade copies | cleaned Enclosed; D and all factors bit-identical; mass identical | bit-identical |

Before the boundary sub-grid, X05 overlaps 0.02 / 0.05 failed (0.0115 / 0.0149) and X07b failed (0.029): one sample
row across a 0.035 face was all-or-nothing. A17 needed pass 2's own sub-grid budget (the copies used up pass 1's).

### E-S2.6 Mirror
10,000 random point tests (5 shapes × 20 random parts × 2 planes × 50 points): `inside(reflect(p), x) ==
inside(p, mirror(x))` with 0 mismatches, max |Δsd| 1.67e-16. C13 (guard and CornerWedge finials built as half +
`reflect`): Asymmetry 0.000000 on both sets.

### E-S2.7 Grip-independent difficulty, and the two deviations (`adv`, `variants.luau`)

| Fixture (bound) | Fixed +Y frame (written) | Kept-grip axis (the review's ruling text) |
|---|---|---|
| A25 F1 + enclosed 20° grip core (0.01) | 0.0000 | 0.0000 |
| A26 F1 ring grip + visible 40° strap (0.02) | **0.0011** | **0.0989**: axis tilts 40°, EdgeLength 5.433 → 2.823, Sharpening 0.0989 → 0 |
| A27 F1 hilt shifted 0.04 in X, Sharpening (0.02) | 0.0000 (Hammering 0.1037 → 0.1537, a visible asymmetry) | 0.0000 |

Physics follows the ruling: A26's physics axis is (−0.643, 0.766) and its balance 0.038 (ring-grip base 0.051).

| Thin-share reference | A24 needle Thinness / Hammering | F3, F5, C02, C04, C10 |
|---|---|---|
| striking metal of the set (written) | 1.000 / 0.4000 | — |
| whole work set (R3-03 text) | 0.063 / 0.0254 | identical to the row above |

### E-S2.8 Performance and checkpoints (`perf`, `gaps.luau`)
Lune best of 5; Studio estimate ×2.6 (R4a-10's side-effect-free probe). Typical swords never hit a budget.

| Fixture | parts | total ms Lune | ≈ Studio | longest checkpoint gap, median / max of 15 runs (ms Lune) |
|---|---|---|---|---|
| F5 Starter | 5 | 4.7 | 12.3 | 0.38 / 1.00 |
| C02 Arming | 6 | 5.5 | 14.2 | 0.26 / 0.33 |
| C09 Ornate | 18 | 14.6 | 38.1 | 0.35 / 0.85 |
| C05 Cleaver (widest blade, 7906 raster cells) | 6 | 15.9 | 41.3 | 0.39 / 0.85 |
| P1 24 large overlapping tilted blocks | 24 | 26.3 | 68.3 | 0.52 / 0.74 |
| P2 24 rotated cylinders | 24 | 22.1 | 57.5 | 0.44 / 0.85 |
| P3 24 rotated wedges / corner wedges | 24 | 20.9 | 54.4 | 0.45 / 0.86 |
| P4 24 overlapping balls | 24 | 12.2 | 31.8 | 0.34 / 0.87 |
| P5 comb blade | 15 | 7.1 | 18.3 | 0.24 / 0.33 |

Cuts that produced this (P1 was 85–99 ms Lune): work budgets instead of sample counts (surface samples × candidates,
sub-grid tests, overlap cells × parts, raster cells × row parts, asymmetry probes × mirror candidates), a corner
pre-test before sub-gridding, ownership tested only for Thinness probes, allocation-free slab tests, a longer
coarsening ladder, quick validation exits before measurement, and no measurement for invalid saves. Gaps above
≈ 0.5 ms are Lune GC pauses.

### E-S2.9 Calibration and the full fixture tables
Fit (`calib.py`, `calib2.py` over `out_raw.csv`): grid over σ (40–60 / 130–150), SC lo/hi and EdgeLength lo/hi;
constraints: arming family (C02, C12, C14, F1, F5) every step ≤ 0.15; minimal, dagger, filler, F2 and C13 Normal;
rapier and sabre Hammering + Sharpening, cleaver Smelting + Sharpening, F3 and F4 Hard; objective = the smallest of
three margins, with greatsword Sharpening and ornate Hammering as wanted Hard steps. Chosen: σ 45–130, SC 2.3–2.9,
EdgeLength 4.8–8.0 (arming 0.068 below Hard, required Hard ≥ 0.30, wanted Hard ≥ 0.249). A wider edge range
(5.0–9.5) puts the arming sword at 0.08 but leaves the greatsword Normal (0.155).

#### Physics (mass units = kg; Iron 7.87, Steel 7.85)
| Fixture | parts (kept) | mass | volume st³ | balance | reach | blade length | edge (main chain) | cutIndex |
|---|---|---|---|---|---|---|---|---|
| F1 ArmingSword | 5 (5) | 0.7924 | 0.10075 | 0.127 | 3.310 | 2.770 | 5.433 | 0.72 |
| F2 MinimalSword | 4 (4) | 1.0813 | 0.13740 | -0.057 | 3.102 | 2.500 | 4.980 | 0.43 |
| F3 Rapier | 7 (7) | 0.3065 | 0.03904 | -0.063 | 4.230 | 3.740 | 7.409 | 1.00 |
| F4 Cleaver | 5 (5) | 3.2303 | 0.41046 | 0.913 | 3.257 | 2.675 | 5.724 | 0.13 |
| F5 StarterSword | 5 (5) | 0.7929 | 0.10075 | 0.128 | 3.310 | 2.770 | 5.433 | 0.72 |
| C01 Minimal | 4 (4) | 1.4717 | 0.18700 | 0.108 | 3.103 | 2.500 | 5.060 | 0.30 |
| C02 Arming (Iron) | 6 (6) | 0.8305 | 0.10553 | 0.180 | 3.420 | 2.900 | 5.644 | 0.77 |
| C02 Arming (Steel) | 6 (6) | 0.8284 | 0.10553 | 0.180 | 3.420 | 2.900 | 5.644 | 0.77 |
| C04 Rapier (Steel blade) | 7 (7) | 0.4150 | 0.05282 | 0.239 | 4.130 | 3.654 | 7.107 | 1.00 |
| C05 Cleaver | 6 (6) | 3.7185 | 0.47249 | 0.985 | 3.278 | 2.670 | 5.972 | 0.16 |
| C06 Sabre (Steel) | 10 (10) | 0.6831 | 0.08695 | 0.361 | 3.815 | 3.272 | 6.480 | 0.89 |
| C07 Dagger | 6 (6) | 0.3415 | 0.04339 | 0.071 | 1.890 | 1.540 | 2.968 | 0.31 |
| C08 Greatsword | 6 (6) | 1.5152 | 0.19253 | 0.326 | 3.950 | 3.270 | 6.392 | 0.62 |
| C09 Ornate (18 parts) | 18 (18) | 0.6300 | 0.08005 | 0.188 | 3.320 | 2.776 | 5.411 | 1.00 |
| C10 Gamey filler, symmetric | 24 (20) | 1.5183 | 0.19292 | 0.122 | 3.103 | 2.493 | 4.980 | 0.27 |
| C11 Gamey filler, lopsided | 24 (20) | 1.5168 | 0.19274 | 0.124 | 3.103 | 2.493 | 5.020 | 0.27 |
| C12 Arming, blade in 5 overlapping segments | 10 (10) | 0.8305 | 0.10553 | 0.180 | 3.420 | 2.900 | 5.644 | 0.77 |
| C13 Arming, guard = half + mirror (+CornerWedges) | 9 (9) | 0.8428 | 0.10709 | 0.175 | 3.420 | 2.896 | 5.644 | 0.77 |
| C14 Arming translated (0, +0.27, +0.05) | 6 (6) | 0.8305 | 0.10553 | 0.180 | 3.420 | 2.900 | 5.644 | 0.77 |
| C15 Arming rotated 4 deg about Z at the grip | 6 (6) | 0.8296 | 0.10542 | 0.181 | 3.420 | 2.900 | 5.626 | 0.77 |

#### Factors on work set All (Smelting, Hammering) (raw / x)
| Fixture | PartCount | Thinness | Asymmetry | SurfaceComplexity | EdgeLength | Joints | MaterialMix | Volume |
|---|---|---|---|---|---|---|---|---|
| F1 ArmingSword | 4.176 / 0.090 | 0.2594 / 0.259 | 0 / 0.000 | 2.2 / 0.000 | 5.433 / 0.198 | 5.284 / 0.109 | 2 / 0.333 | 0.1008 / 0.029 |
| F2 MinimalSword | 4 / 0.077 | 0.04412 / 0.044 | 0 / 0.000 | 2.079 / 0.000 | 4.98 / 0.056 | 3.766 / 0.036 | 1 / 0.000 | 0.1374 / 0.080 |
| F3 Rapier | 4.544 / 0.119 | 0.9131 / 0.913 | 0.001199 / 0.002 | 2.453 / 0.255 | 7.409 / 0.815 | 6.336 / 0.159 | 1 / 0.000 | 0.03904 / 0.000 |
| F4 Cleaver | 5 / 0.154 | 0 / 0.000 | 0.3144 / 0.524 | 2 / 0.000 | 5.724 / 0.289 | 4.01 / 0.048 | 1 / 0.000 | 0.4105 / 0.459 |
| F5 StarterSword | 4.176 / 0.090 | 0.2594 / 0.259 | 0 / 0.000 | 2.2 / 0.000 | 5.433 / 0.198 | 5.284 / 0.109 | 1 / 0.000 | 0.1008 / 0.029 |
| C01 Minimal | 4 / 0.077 | 0 / 0.000 | 0 / 0.000 | 2.068 / 0.000 | 5.06 / 0.081 | 3.574 / 0.027 | 1 / 0.000 | 0.187 / 0.149 |
| C02 Arming (Iron) | 4.6 / 0.123 | 0.2843 / 0.284 | 0 / 0.000 | 2.26 / 0.000 | 5.644 / 0.264 | 5.709 / 0.129 | 1 / 0.000 | 0.1055 / 0.035 |
| C02 Arming (Steel) | 4.6 / 0.123 | 0.2843 / 0.284 | 0 / 0.000 | 2.26 / 0.000 | 5.644 / 0.264 | 5.709 / 0.129 | 1 / 0.000 | 0.1055 / 0.035 |
| C04 Rapier (Steel blade) | 5.169 / 0.167 | 0.5934 / 0.593 | 0 / 0.000 | 2.499 / 0.332 | 7.107 / 0.721 | 6.655 / 0.174 | 2 / 0.333 | 0.05282 / 0.000 |
| C05 Cleaver | 6 / 0.231 | 0 / 0.000 | 0.2726 / 0.454 | 2.24 / 0.000 | 5.972 / 0.366 | 8.709 / 0.272 | 1 / 0.000 | 0.4725 / 0.545 |
| C06 Sabre (Steel) | 8.486 / 0.422 | 0.3514 / 0.351 | 0.2569 / 0.428 | 2.36 / 0.100 | 6.48 / 0.525 | 11.52 / 0.406 | 2 / 0.333 | 0.08695 / 0.010 |
| C07 Dagger | 4.405 / 0.108 | 0 / 0.000 | 0 / 0.000 | 1.985 / 0.000 | 2.968 / 0.000 | 6.009 / 0.143 | 1 / 0.000 | 0.04339 / 0.000 |
| C08 Greatsword | 5.2 / 0.169 | 0.1882 / 0.188 | 0 / 0.000 | 2.348 / 0.080 | 6.392 / 0.497 | 6.953 / 0.188 | 1 / 0.000 | 0.1925 / 0.156 |
| C09 Ornate (18 parts) | 10.16 / 0.551 | 0.3858 / 0.386 | 0 / 0.000 | 2.604 / 0.506 | 5.411 / 0.191 | 20.25 / 0.821 | 1 / 0.000 | 0.08005 / 0.000 |
| C10 Gamey filler, symmetric | 6.916 / 0.301 | 0 / 0.000 | 0 / 0.000 | 2.139 / 0.000 | 4.98 / 0.056 | 8.871 / 0.280 | 1 / 0.000 | 0.1927 / 0.156 |
| C11 Gamey filler, lopsided | 6.916 / 0.301 | 0 / 0.000 | 0.002488 / 0.004 | 2.128 / 0.000 | 5.02 / 0.069 | 10.04 / 0.335 | 1 / 0.000 | 0.1925 / 0.156 |
| C12 Arming, blade in 5 overlapping segments | 8.6 / 0.431 | 0.2843 / 0.284 | 0 / 0.000 | 2.263 / 0.000 | 5.644 / 0.264 | 9.72 / 0.320 | 1 / 0.000 | 0.1055 / 0.035 |
| C13 Arming, guard = half + mirror (+CornerWedges) | 5.984 / 0.230 | 0.2831 / 0.283 | 0 / 0.000 | 2.278 / 0.000 | 5.644 / 0.264 | 11.17 / 0.389 | 1 / 0.000 | 0.1071 / 0.038 |
| C14 Arming translated (0, +0.27, +0.05) | 4.6 / 0.123 | 0.2843 / 0.284 | 0 / 0.000 | 2.26 / 0.000 | 5.644 / 0.264 | 5.709 / 0.129 | 1 / 0.000 | 0.1055 / 0.035 |
| C15 Arming rotated 4 deg about Z at the grip | 4.6 / 0.123 | 0.2824 / 0.282 | 0.3144 / 0.524 | 2.262 / 0.000 | 5.626 / 0.258 | 5.709 / 0.129 | 1 / 0.000 | 0.1054 / 0.035 |

#### Factors on work set {Blade} (Sharpening) (raw / x)
| Fixture | PartCount | Thinness | Asymmetry | SurfaceComplexity | EdgeLength | Joints | MaterialMix | Volume |
|---|---|---|---|---|---|---|---|---|
| F1 ArmingSword | 1.176 / 0.000 | 0.001614 / 0.002 | 0 / 0.000 | 2.258 / 0.000 | 5.433 / 0.198 | 0.2483 / 0.000 | 1 / 0.000 | 0.02531 / 0.000 |
| F2 MinimalSword | 1 / 0.000 | 0 / 0.000 | 0 / 0.000 | 1.991 / 0.000 | 4.98 / 0.056 | 0 / 0.000 | 1 / 0.000 | 0.0384 / 0.000 |
| F3 Rapier | 1.092 / 0.000 | 0.7143 / 0.714 | 0.005451 / 0.009 | 2.98 / 1.000 | 7.409 / 0.815 | 0.1792 / 0.000 | 1 / 0.000 | 0.008698 / 0.000 |
| F4 Cleaver | 2 / 0.000 | 0 / 0.000 | 0.3954 / 0.659 | 1.778 / 0.000 | 5.724 / 0.289 | 1 / 0.000 | 1 / 0.000 | 0.3264 / 0.342 |
| F5 StarterSword | 1.176 / 0.000 | 0.001614 / 0.002 | 0 / 0.000 | 2.258 / 0.000 | 5.433 / 0.198 | 0.2483 / 0.000 | 1 / 0.000 | 0.02531 / 0.000 |
| C01 Minimal | 1 / 0.000 | 0 / 0.000 | 0 / 0.000 | 1.854 / 0.000 | 5.06 / 0.081 | 0 / 0.000 | 1 / 0.000 | 0.06 / 0.000 |
| C02 Arming (Iron) | 1.6 / 0.000 | 0.03922 / 0.039 | 0 / 0.000 | 2.281 / 0.000 | 5.644 / 0.264 | 1.563 / 0.000 | 1 / 0.000 | 0.0324 / 0.000 |
| C02 Arming (Steel) | 1.6 / 0.000 | 0.03922 / 0.039 | 0 / 0.000 | 2.281 / 0.000 | 5.644 / 0.264 | 1.563 / 0.000 | 1 / 0.000 | 0.0324 / 0.000 |
| C04 Rapier (Steel blade) | 1.169 / 0.000 | 0.3222 / 0.322 | 0 / 0.000 | 2.63 / 0.550 | 7.107 / 0.721 | 0.4657 / 0.000 | 1 / 0.000 | 0.01552 / 0.000 |
| C05 Cleaver | 3 / 0.000 | 0 / 0.000 | 0.327 / 0.545 | 2.048 / 0.000 | 5.972 / 0.366 | 3.606 / 0.029 | 1 / 0.000 | 0.3974 / 0.441 |
| C06 Sabre (Steel) | 5.486 / 0.191 | 0.1089 / 0.109 | 0.6682 / 1.000 | 2.397 / 0.162 | 6.48 / 0.525 | 6.932 / 0.187 | 1 / 0.000 | 0.0337 / 0.000 |
| C07 Dagger | 1.405 / 0.000 | 0 / 0.000 | 0 / 0.000 | 1.844 / 0.000 | 2.968 / 0.000 | 1.084 / 0.000 | 1 / 0.000 | 0.01458 / 0.000 |
| C08 Greatsword | 2.2 / 0.000 | 0 / 0.000 | 0 / 0.000 | 2.217 / 0.000 | 6.392 / 0.497 | 2.891 / 0.000 | 1 / 0.000 | 0.072 / 0.000 |
| C09 Ornate (18 parts) | 3.46 / 0.035 | 0.164 / 0.164 | 0 / 0.000 | 2.585 / 0.474 | 5.411 / 0.191 | 7.047 / 0.193 | 1 / 0.000 | 0.02712 / 0.000 |
| C10 Gamey filler, symmetric | 2.822 / 0.000 | 0 / 0.000 | 0 / 0.000 | 1.935 / 0.000 | 4.98 / 0.056 | 2.885 / 0.000 | 1 / 0.000 | 0.06365 / 0.000 |
| C11 Gamey filler, lopsided | 2.822 / 0.000 | 0 / 0.000 | 0.004773 / 0.008 | 1.939 / 0.000 | 5.02 / 0.069 | 2.885 / 0.000 | 1 / 0.000 | 0.06365 / 0.000 |
| C12 Arming, blade in 5 overlapping segments | 5.6 / 0.200 | 0.03922 / 0.039 | 0 / 0.000 | 2.289 / 0.000 | 5.644 / 0.264 | 5.563 / 0.122 | 1 / 0.000 | 0.0324 / 0.000 |
| C13 Arming, guard = half + mirror (+CornerWedges) | 1.6 / 0.000 | 0.03922 / 0.039 | 0 / 0.000 | 2.281 / 0.000 | 5.644 / 0.264 | 1.563 / 0.000 | 1 / 0.000 | 0.0324 / 0.000 |
| C14 Arming translated (0, +0.27, +0.05) | 1.6 / 0.000 | 0.03922 / 0.039 | 0 / 0.000 | 2.281 / 0.000 | 5.644 / 0.264 | 1.563 / 0.000 | 1 / 0.000 | 0.0324 / 0.000 |
| C15 Arming rotated 4 deg about Z at the grip | 1.6 / 0.000 | 0.0392 / 0.039 | 0.8242 / 1.000 | 2.281 / 0.000 | 5.626 / 0.258 | 1.563 / 0.000 | 1 / 0.000 | 0.0324 / 0.000 |

#### Steps (g / d -> tier; tierRaw in brackets when it differs)
| Fixture | Smelting | Hammering | Sharpening | tiers |
|---|---|---|---|---|
| F1 ArmingSword | 0.0288 / 0.0288 Normal | 0.1037 / 0.1037 Normal | 0.0989 / 0.0989 Normal | N/N/N |
| F2 MinimalSword | 0.0797 / 0.0797 Normal | 0.0176 / 0.0176 Normal | 0.0282 / 0.0282 Normal | N/N/N |
| F3 Rapier | 0.0000 / 0.0000 Normal | 0.4423 / 0.4423 Hard (Expert) | 0.6104 / 0.6104 Hard (Master) | N/H/H |
| F4 Cleaver | 0.4590 / 0.4590 Hard (Expert) | 0.1572 / 0.1572 Normal | 0.3420 / 0.3420 Hard | H/N/H |
| F5 StarterSword | 0.0288 / 0.0288 Normal | 0.1037 / 0.1037 Normal | 0.0989 / 0.0989 Normal | N/N/N |
| C01 Minimal | 0.1486 / 0.1486 Normal | 0.0000 / 0.0000 Normal | 0.0407 / 0.0407 Normal | N/N/N |
| C02 Arming (Iron) | 0.0355 / 0.0355 Normal | 0.1137 / 0.1137 Normal | 0.1318 / 0.1318 Normal | N/N/N |
| C02 Arming (Steel) | 0.0355 / 0.0355 Normal | 0.1137 / 0.1137 Normal | 0.1318 / 0.1318 Normal | N/N/N |
| C04 Rapier (Steel blade) | 0.0000 / 0.0000 Normal | 0.3368 / 0.3368 Hard | 0.4703 / 0.4703 Hard (Expert) | N/H/H |
| C05 Cleaver | 0.5451 / 0.5451 Hard (Expert) | 0.1363 / 0.1363 Normal | 0.3466 / 0.3466 Hard | H/N/H |
| C06 Sabre (Steel) | 0.0097 / 0.0097 Normal | 0.2991 / 0.2991 Hard | 0.5948 / 0.5948 Hard (Expert) | N/H/H |
| C07 Dagger | 0.0000 / 0.0000 Normal | 0.0000 / 0.0000 Normal | 0.0000 / 0.0000 Normal | N/N/N |
| C08 Greatsword | 0.1563 / 0.1563 Normal | 0.0992 / 0.0992 Normal | 0.2487 / 0.2487 Hard | N/N/H |
| C09 Ornate (18 parts) | 0.0001 / 0.0001 Normal | 0.3061 / 0.3061 Hard | 0.1904 / 0.1904 Normal | N/H/N |
| C10 Gamey filler, symmetric | 0.1565 / 0.1565 Normal | 0.0000 / 0.0000 Normal | 0.0282 / 0.0282 Normal | N/N/N |
| C11 Gamey filler, lopsided | 0.1562 / 0.1562 Normal | 0.0012 / 0.0012 Normal | 0.0368 / 0.0368 Normal | N/N/N |
| C12 Arming, blade in 5 overlapping segments | 0.0355 / 0.0355 Normal | 0.1137 / 0.1137 Normal | 0.1318 / 0.1318 Normal | N/N/N |
| C13 Arming, guard = half + mirror (+CornerWedges) | 0.0376 / 0.0376 Normal | 0.1133 / 0.1133 Normal | 0.1318 / 0.1318 Normal | N/N/N |
| C14 Arming translated (0, +0.27, +0.05) | 0.0355 / 0.0355 Normal | 0.1137 / 0.1137 Normal | 0.1318 / 0.1318 Normal | N/N/N |
| C15 Arming rotated 4 deg about Z at the grip | 0.0353 / 0.0353 Normal | 0.2701 / 0.2701 Hard | 0.4291 / 0.4291 Hard (Expert) | N/H/H |

Steel versions match Iron in d (difficultyTerm 0); masses differ by density only.

### E-S2.10 Validation, invariance, determinism (`val`, `inv`, `det`)

| Case | Result |
|---|---|
| Pommel 0.03 below the grip | `Disconnected#1`, floating {1}, gap 0.0300, dir (0, 1, 0), nearest #2 |
| Tip wedges raised to y 5.30 | `OutOfHitbox#5`, `OutOfHitbox#6` (quick exit, no measurement) |
| No grip / upside down | `SlotMissing{Grip}` / `BladeNotAboveGrip` |
| A22 only Blade part dust / enclosed; only Grip part enclosed | `SlotMissing{Blade, Cleaned}` (Dust#4 / Enclosed#4); `SlotMissing{Grip, Cleaned}` (Enclosed#6) |
| Y/Z translations (6 offsets) of F1, F3, F5, C02, C06 | MVP factors Δx ≤ 0.0017, ΔG ≤ 0.0007 (F1, F5); 0 for the others |
| F5 blade re-cut flush into 2, 3 and 7 pieces | Δx ≤ 0.00001, ΔG 0 |
| q → −q on every part (raw, not re-canonicalized) | bit-identical |
| Two runs of 20 fixtures | 0 mismatches (d, g, every raw factor, mass, EdgeLength) |

---

## Evidence S3

Prototype: `docs/spec/prototypes/S3/v2/` (Lune 0.8.9, `lune run <file>`; files and commands in its `README.md`). The
v1 files one level up are the draft's prototype and are superseded.

### E-S3.1 PRNG test vectors (unchanged module; cross-checked bit for bit against the Python reference `rng_ref.py`)

| Check | Expected |
|---|---|
| FNV-1a32 `""` / `"a"` / `"foobar"` | `0x811C9DC5` / `0xE40C292C` / `0xBF9CF968` (published vectors) |
| FNV-1a32 `"TimingStrike.Offsets"` | `0xBDE3CD3F` |
| raw xoshiro128\*\* from state (1, 2, 3, 4), first 10 | 11520, 0, 5927040, 70819200, 2031721883, 1637235492, 1287239034, 3734860849, 3729100597, 4258142804 |
| `Rng.new(1, "")` state | `0x283F5546 0xD3E69993 0xE0DFBA52 0xF9D93A6F` |
| `Rng.new(1, "")` u32 ×6, then float ×2 | 3296685081, 292216795, 3203276040, 3343330025, 3022133357, 443753119; 0.70098106143996119, 0.34134213626384735 |
| `Rng.new(3735928559, "")` state | `0x8D72B72A 0x53A3D0FD 0xD068308F 0x22AE1FC7` |
| `Rng.new(3735928559, "")` u32 ×6, then float ×2 | 3856547673, 1244478788, 63559405, 3329023417, 1418849053, 466841299; 0.89875514479354024, 0.75457527255639434 |
| `Rng.new(1, "TimingStrike.Offsets")` u32 ×6 | 2172563110, 3751778701, 3705501078, 924797711, 2910597952, 64598121 |
| `Rng.new(3735928559, "TimingStrike.Offsets")` u32 ×6 | 3201755939, 1102565783, 4063799498, 528979833, 2160534696, 2194535758 |

### E-S3.2 Final bot table (`dist.luau 2000`, `out/final_table.txt`)

2,000 runs per cell, seeds `Sim.seedOf(i, 1)`, design factors of the step's weight list at x = 0.10 (Normal) / 0.30
(Hard), HoldZone tap policy, `timingOffsetMs = 0`, PrecisionTrace on S3's reference arming edge (`Blades.arming`: S2's
draft arming chain, 6 points, 5.604 studs). Cell: mean ± SD [p10–p90] fail %. Flag rate 0.00 % in every cell. A
final-check re-run on the final chains (2,000 runs per cell) moved PrecisionTrace means by ≤ 0.003; Average fail rates
IN / SN / IH / SH are 7.2 / 9.8 / 26.9 / 31.2 % on F5 (5.433 studs) and 6.1 / 8.1 / 26.3 / 30.6 % on C02
(5.644 studs), against 7.0 / 7.8 / 25.0 / 30.2 % below: inside Q8.

| Config | Elite | Good | Average | Poor |
|---|---|---|---|---|
| HoldZone Iron/Normal | 0.858 ± 0.074 [0.76–0.94] 0.0 | 0.799 ± 0.068 [0.71–0.89] 0.0 | 0.615 ± 0.074 [0.52–0.71] 5.3 | 0.481 ± 0.080 [0.38–0.58] 58.5 |
| HoldZone Steel/Normal | 0.870 ± 0.061 [0.79–0.94] 0.0 | 0.800 ± 0.064 [0.71–0.88] 0.0 | 0.599 ± 0.075 [0.51–0.69] 9.0 | 0.466 ± 0.082 [0.36–0.57] 65.6 |
| HoldZone Iron/Hard | 0.825 ± 0.069 [0.74–0.91] 0.0 | 0.748 ± 0.068 [0.66–0.83] 0.0 | 0.550 ± 0.071 [0.46–0.64] 24.9 | 0.421 ± 0.075 [0.32–0.52] 85.6 |
| HoldZone Steel/Hard | 0.830 ± 0.061 [0.75–0.91] 0.0 | 0.743 ± 0.067 [0.66–0.83] 0.0 | 0.535 ± 0.070 [0.44–0.63] 32.3 | 0.408 ± 0.073 [0.32–0.50] 89.8 |
| TimingStrike Iron/Normal | 0.864 ± 0.049 [0.80–0.93] 0.0 | 0.792 ± 0.079 [0.69–0.89] 0.1 | 0.648 ± 0.108 [0.50–0.78] 9.3 | 0.389 ± 0.117 [0.24–0.54] 81.9 |
| TimingStrike Steel/Normal | 0.858 ± 0.050 [0.79–0.92] 0.0 | 0.784 ± 0.082 [0.67–0.88] 0.2 | 0.636 ± 0.109 [0.49–0.77] 11.7 | 0.380 ± 0.117 [0.23–0.53] 83.9 |
| TimingStrike Iron/Hard | 0.808 ± 0.058 [0.73–0.88] 0.0 | 0.719 ± 0.091 [0.60–0.83] 1.6 | 0.555 ± 0.103 [0.41–0.68] 28.9 | 0.312 ± 0.096 [0.19–0.43] 97.3 |
| TimingStrike Steel/Hard | 0.806 ± 0.058 [0.73–0.88] 0.0 | 0.713 ± 0.092 [0.59–0.82] 1.8 | 0.547 ± 0.105 [0.41–0.68] 31.7 | 0.306 ± 0.098 [0.18–0.43] 97.4 |
| PrecisionTrace Iron/Normal | 0.957 ± 0.011 [0.94–0.97] 0.0 | 0.874 ± 0.027 [0.84–0.91] 0.0 | 0.633 ± 0.083 [0.52–0.73] 7.0 | 0.405 ± 0.102 [0.27–0.54] 81.4 |
| PrecisionTrace Steel/Normal | 0.955 ± 0.011 [0.94–0.97] 0.0 | 0.870 ± 0.027 [0.84–0.90] 0.0 | 0.624 ± 0.083 [0.51–0.73] 7.8 | 0.393 ± 0.103 [0.26–0.52] 84.3 |
| PrecisionTrace Iron/Hard | 0.949 ± 0.013 [0.93–0.96] 0.0 | 0.848 ± 0.032 [0.81–0.89] 0.0 | 0.559 ± 0.092 [0.44–0.67] 25.0 | 0.332 ± 0.099 [0.21–0.46] 94.8 |
| PrecisionTrace Steel/Hard | 0.947 ± 0.013 [0.93–0.96] 0.0 | 0.844 ± 0.034 [0.80–0.89] 0.0 | 0.549 ± 0.096 [0.42–0.67] 30.2 | 0.321 ± 0.099 [0.20–0.45] 95.6 |

Variants (1,000 runs; mean · fail %):

| Config | Average 30 fps | Good x = 1 | Average x = 1 | Calibrated: Elite / Good / Average · Average fail; Average 30 fps |
|---|---|---|---|---|
| HoldZone Iron/Normal | 0.587 · 11.5 | 0.740 · 0 | 0.544 · 26.4 | – (hold-only policy scores 0.000) |
| HoldZone Steel/Normal | 0.576 · 14.7 | 0.734 · 0.1 | 0.528 · 33.9 | – |
| HoldZone Iron/Hard | 0.522 · 40.0 | 0.697 · 0.2 | 0.497 · 52.4 | – |
| HoldZone Steel/Hard | 0.510 · 46.6 | 0.685 · 0.3 | 0.478 · 61.8 | – |
| TimingStrike Iron/Normal | 0.583 · 24.9 | 0.744 · 1.1 | 0.587 · 22.6 | 0.967 / 0.872 / 0.717 · 0.9; 0.711 · 1.7 |
| TimingStrike Steel/Normal | 0.566 · 27.8 | 0.730 · 1.2 | 0.567 · 28.5 | 0.965 / 0.868 / 0.706 · 1.4; 0.703 · 1.5 |
| TimingStrike Iron/Hard | 0.488 · 53.3 | 0.675 · 4.3 | 0.503 · 48.8 | 0.940 / 0.812 / 0.617 · 9.5; 0.610 · 11.5 |
| TimingStrike Steel/Hard | 0.484 · 54.3 | 0.668 · 6.4 | 0.495 · 50.6 | 0.939 / 0.810 / 0.611 · 11.8; 0.604 · 12.7 |
| PrecisionTrace Iron/Normal | 0.630 · 7.3 | 0.844 · 0 | 0.553 · 29.1 | – |
| PrecisionTrace Steel/Normal | 0.618 · 9.6 | 0.839 · 0 | 0.540 · 33.8 | – |
| PrecisionTrace Iron/Hard | 0.554 · 25.8 | 0.821 · 0 | 0.495 · 51.2 | – |
| PrecisionTrace Steel/Hard | 0.541 · 32.4 | 0.815 · 0 | 0.478 · 57.4 | – |

Calibrated offsets = round(lag + mean bias): Elite 28, Good 30, Average 35 ms; Average at 30 fps 51 ms. Perfect (raw):
HoldZone 0.9839 / 0.9872 / 0.9660 / 0.9690 (Iron N, Steel N, Iron H, Steel H; every run ≥ 0.897), TimingStrike 1.0000
at 60 fps and 0.9965 / 0.9959 / 0.9868 / 0.9860 at 30 fps (worst run 0.9655), PrecisionTrace 1.0000; Idle 0. Normal →
Hard mean drops (Iron / Steel): Average HoldZone 0.065 / 0.064, TimingStrike 0.093 / 0.089, PrecisionTrace 0.074 /
0.075; Good 0.051 / 0.057, 0.073 / 0.071, 0.026 / 0.026; Elite 0.033 / 0.040, 0.056 / 0.052, 0.008 / 0.008.

### E-S3.3 Full parameter columns and resolved values (`Params.luau`, `golden.luau`)

Tier columns Normal / Hard / Expert / Master / Hell (the last three are placeholders): HoldZone `zoneWidth` 1 / 0.96 /
0.88 / 0.80 / 0.72, `driftSpeed` 1 / 1.05 / 1.15 / 1.25 / 1.35, `heatDecay` 1 / 1.05 / 1.12 / 1.20 / 1.28,
`durationMs` 1 / 1 / 1.1 / 1.2 / 1.3, `segMinMs` and `segMaxMs` 1 / 0.9 / 0.8 / 0.7 / 0.6, `holdChance` 1 / 0.8 / 0.6 /
0.4 / 0.2; TimingStrike `strikes` 1 / 1.25 / 1.5 / 1.75 / 2, `beatMs` 1 / 0.85 / 0.75 / 0.65 / 0.58, `windowMs` 1 /
0.94 / 0.80 / 0.70 / 0.60, `perfectFrac` 1 / 0.80 / 0.70 / 0.60 / 0.50, `edgePoints` 1 / 0.50 / 0.40 / 0.30 / 0.20,
`tempoJitter` 1 / 1.5 / 2 / 2.5 / 3; PrecisionTrace `halfWidth` 1 / 0.95 / 0.85 / 0.76 / 0.68, `pacerSpeed` 1 / 1.05 /
1.15 / 1.25 / 1.35, `paceTol` and `paceFall` 1 / 0.85 / 0.7 / 0.6 / 0.5, `perturbAmp` 1 / 1.25 / 1.5 / 1.75 / 2,
`bumpDensity` 1 / 1.3 / 1.6 / 1.9 / 2.2, `bumpWidth` 1 / 0.9 / 0.8 / 0.7 / 0.6.

Resolved at x = 0 | x = 1, for Iron/Normal, Iron/Hard, Steel/Normal, Steel/Hard: HoldZone `zoneWidth` 0.090|0.081,
0.0864|0.0778, 0.0882|0.0794, 0.0847|0.0762; `driftSpeed` 0.210|0.2415, 0.2205|0.2536, 0.2121|0.2439, 0.2227|0.2561;
`durationMs` 15000|18000. TimingStrike `windowMs` 110|94, 103|88, 108|92, 101|86; `beatMs` 900|810, 765|689, 882|794,
750|675; `tempoJitter` 0.08|0.12 (Normal), 0.12|0.18 (Hard). PrecisionTrace `halfWidth` 0.0410|0.0369,
0.0390|0.0351, 0.0402|0.0362, 0.0382|0.0344; `pacerSpeed` 0.300|0.345, 0.315|0.362, 0.303|0.348, 0.318|0.366;
`perturbAmp` 0.020|0.030 (Normal), 0.025|0.0375 (Hard).

### E-S3.4 TimingStrike golden values and grade bands (`golden.luau`)

Seed 1, Iron/Normal, x = 0: N 12, W 110, core 13.2, M 200, durationMs 10971, hash `0xE2D4F2AE`; targets 489, 1479,
2354, 3031 ms (periods 847, 896, 871, 878). Errors 0, +6, −15, +35, +79, none, −81, then 5 exact strikes, give points
1, 1, 0.9851, 0.8198, 0.4562, 0, 0.4397, 1 ×5: score **0.8084**. Grade bands (Perfect ≥ 0.9 / Good ≥ 0.6 points):
Iron/Normal x = 0 25.3 / 61.6 ms (W 110); x = 1 21.6 / 52.6 (W 94); Iron/Hard x = 0 20.3 / 51.3 (W 103, core 10);
x = 1 18.7 / 44.7 (W 88); Steel/Hard x = 1 18.4 / 43.8 (W 86). Perfect at 30 fps with a 9 ms core floor had a worst
run of 0.9499 (Iron/Hard, x = 1); the 10 ms floor raises it to 0.9600.

### E-S3.5 PrecisionTrace edge mapping, golden values and costs (`cost.luau`, `worst.luau`, `golden.luau`)

Arming sword (S2's draft arming chain, 6 points, 5.60 studs; the final F1/F5 main chain is 5.433 and C02's 5.644),
seed 1, Iron/Normal, x = 0: sides of 3 and 4 points; source
`(10912,10158) (34996,10158) (38240,8389) (38142,7799) (34996,6226) (10912,6226)` (the +X side has v > 0.5: down);
path 337 points, L 3.3526, travel 11180 ms, duration 12180 ms, hash `0xF0B5CD03`. Fallback: 402 points, L 4.0083,
travel 13380 ms, hash `0x405C00EA`. The same sword with its grip axis tilted 30° gives the identical source.

| Blade | Chain pts / studs | Sides | Source pts | E | DP tol | Path pts | L (u) | Travel N / H (s) | generate ms | replay + checks ms (samples) |
|---|---|---|---|---|---|---|---|---|---|---|
| arming | 6 / 5.60 | 2 | 6 | 2.00 | – | 337 | 3.359 | 11.0 / 10.3 | 0.93 | 1.27 (596) |
| longsword | 5 / 7.27 | 2 | 5 | 2.00 | – | 431 | 4.293 | 14.1 / 13.0 | 0.80 | 1.51 (749) |
| dagger | 5 / 3.06 | 2 | 5 | 2.00 | – | 185 | 1.835 | 6.0 / 6.0 | 0.49 | 0.57 (347) |
| sabre (one edge) | 18 / 3.48 | 1 | 18 | 2.00 | – | 215 | 2.140 | 7.0 / 6.6 | 0.47 | 0.69 (397) |
| flamberge (voxel 0.05) | 123 / 8.36 | 2 | 123 | 2.00 | – | 574 | 5.703 | 18.7 / 17.4 | 1.20 | 2.06 (981) |
| arming, grip tilted 30° | 6 / 5.60 | 2 | 6 | 2.00 | – | 337 | 3.359 | 11.0 / 10.3 | 0.61 | 0.96 (596) |
| serrated (pitch 0.10, depth 0.10) | 71 / 10.34 | 2 | 71 | 1.62 | – | 595 | 5.900 | 19.4 / 18.9 | 1.89 | 1.85 (1013) |
| saw (pitch 0.05, depth 0.15) | 139 / 22.28 | 2 | 5 | 1.00 | 0.128 | 447 | 4.462 | 14.7 / 13.6 | 0.85 | 2.04 (777) |
| zigzag, 256 points ±0.30 | 256 / 153 | 1 | 2 | 1.00 | 0.512 | 209 | 2.073 | 6.8 / 6.3 | 0.35 | 0.57 (386) |

Worst case: a 256-point source at the length bound (8.54 of 8.55 u) gives an 860-point path, L 8.564, travel 28.56 s,
1,479 samples: generate 2.53 ms, replay + checks 2.59 ms. Decode of 1,551 records (10,869 B): 0.12 ms. The draft's
O(n²) clearance cost 18–21 ms on a sawtooth (R3-08); the grid search returns the same clamp. The nearest-point search
became nearest vertex + two segments: 2.6× faster (29,434 queries: 53.8 → 21.0 ms), |Δd| ≤ 1.0·10⁻⁴ u, bot means
unchanged at 3 decimals. The zigzag is a residual: it saturates EdgeLength yet plays a 2-point line; S2's chain
extraction (pommel-facing segments are not sharpenable) cannot produce such a chain. HoldZone generate 0.04 ms,
replay + checks 0.35 ms (1,000 records); TimingStrike 0.03 / 0.04 ms (`cost2.luau`).

### E-S3.6 Determinism and codec (`det.luau`)

150 runs per family (profiles, tiers and materials rotated, arbitrary frame partitions): live session = server replay =
encode → decode → replay, **0 mismatches** in every family. Timeline bytes min / mean / max: HoldZone 198 / 293 / 396,
TimingStrike 34 / 39 / 48, PrecisionTrace 2,322 / 3,663 / 4,240. Malformed buffers return `NotBuffer`, `Short`,
`Version`, `Family`, `Duration`, `NotAlternating`, `PastEnd`, `NotIncreasing` and `OutOfPanel` as specified.

### E-S3.7 HoldZone: why strokes (`hztune.luau`, `golden.luau`)

The draft's hold model (hold Space to heat), both bot policies with identical perception
(`out/hz_holdmodel_v2params.txt`, 300 runs per cell, Iron/Normal means):

| Params | Elite hold / tap | Good hold / tap | Average hold / tap | Average tap fails IN / SN / IH / SH |
|---|---|---|---|---|
| draft (zone 0.14) | 0.853 / 0.991 | 0.732 / 0.965 | 0.607 / 0.868 | 0 / 0.3 / 0.3 / 1.0 % |
| narrowed (zone 0.12) | 0.716 / 0.972 | 0.606 / 0.929 | 0.519 / 0.779 | 0 / 0.7 / 5.7 / 20 % |

Tapping beats holding by 0.14–0.32 for every profile, so a "hold" control misleads players, and tuning for tappers
fails holders. The stroke model makes tapping the designed skill and bounds it. Steady T at 1.0 / 1.7 / 2.5 / 3.3 /
4.0 / 6.7 / 10 taps per s: 0.335 / 0.516 / 0.702 / 0.854 / 0.958 / 0.930 / 0.916 (ripple 0.07 → 0.002). From cold at
the refill rate (T(t) = the state after every tick with 10k < t): T(1 s) 0.49, T(2 s) 0.77, T(3 s) 0.885; one stroke from rest peaks at +0.166 after 750 ms. Golden
(seed 1, Iron/Normal, x = 0): 10 keys, first (0, 0.6323) (3000, 0.6323) (5060, 0.4000) (7180, 0.6523), hash
`0x4E2677F2`. Softening the Volume drift term from +0.25 to +0.15 cut Average's maximal-design Hard fails from 62–72 %
to 52–62 %.

### E-S3.8 Check margins and cheats (`checks.luau`)

TimingStrike: 0 flags in 100,000 runs each for Elite at 240 and 60 fps, Good, and Average at 30 fps, at Normal and
Hard (S8 sizes the 10⁻⁵ claim at 300,000 runs); exact times flagged 100 %; σ 4 ms synthesized input 0 % (score 1.000).
PrecisionTrace (1,000 runs per row): minimum mean deviation Elite 0.0029–0.0032 u (240 / 60 / 30 fps, 520 or 360 px),
Good 0.0052–0.0054; minimum mean jerk 0.0038–0.0053 (threshold 0.0002); 0 flags; on-pacer and 200 ms-sparse cheats
flagged 100 %; 0.004 u white noise 0 % (scores 0.985–0.987). A final-check re-run of 3,000 runs per configuration
(Iron Normal and Hard; Elite at 30 fps / 360 px and at 60 fps / 520 px) measured minima of 0.00279–0.00290 u
(×3.48–×3.63 of `PT_PRECISE_MEAN_DEV`), with 14–18 of every 3,000 runs below 4 × the threshold, hence §14.8's
3 × margin. HoldZone (500 runs per row): Elite, Good and Average tappers peak at 7–9 presses per 1 s window (a
final-check re-run of 20,000 pumping runs per configuration, Iron Normal and Hard, Elite at 60 and 30 fps, Good,
Average at 30 fps: at most 9, within §14.8's 10); the exact-state controller presses up to 50/s (flagged 100 %); a
30/s autoclicker is flagged.

### E-S3.9 Tuning log (`multisweep.luau`, `sweep.luau`; 200–3,000 runs per setting)

- TimingStrike: under 25 ms render lag the draft's ±80 ms window (Hard ×0.80, Steel ×0.92) fails Average 40 % on
  Normal and 77 % on Hard and Good 5 % / 24 % (`out/ts_draft_window.txt`). `windowMs` 110 with Hard ×0.85 and Steel
  ×0.95 left Steel/Hard at 41 %; the final Hard ×0.94 with `perfectFrac` ×0.80 and `edgePoints` ×0.50 keeps Normal
  fails at 9–12 % while Elite still drops ≥ 0.05. `strikes` lost its design term, so Q15's "12 (15 on Hard)" holds.
- PrecisionTrace: `halfWidth` 0.037 (Steel ×0.95, Hard ×0.92, pacer Hard ×1.08) failed Average 16 / 31 / 56 / 68 %
  (IN / SN / IH / SH). Dropping Good by ≥ 0.05 at Hard needs `halfWidth` 0.050, Hard ×0.80, pacer ×1.10, perturbation
  ×1.5 (Good 0.901 → 0.846) and then Average fails 0 % on Normal, below the 3 % floor; narrowing the base instead
  pushes Average's Hard fails above 40 %. The chosen 0.041 / ×0.95 / ×1.05 meets every Q8 band.
- HoldZone: `strokeGain` × `fullHeat` ≈ 0.6 keeps the profile order (0.4 × 2.4 made Elite score below Good);
  `fullHeat` 2.4 keeps Steel's higher band reachable; zone 0.090 with Hard ×0.96 centres the Average fail rates.

---

## Evidence S4

Prototype: `prototypes/S4/v2/` (Lune 0.8.9), the reference for §7.1–7.5 and §8. It requires S2's
`prototypes/S2/v2/{analyze, fixtures}` (live physics, no copied constants, R4a-13), S3's `prototypes/S3/v2/Sim` and
`prototypes/S3/v2/out/S3-score-distributions.luau`. `Crafting/Defs.luau` holds the values,
`Crafting/Core.luau` every formula. The v1 prototype (draft model) stays one level up for comparison.

| Script | Output | Evidence |
|---|---|---|
| `examples.luau` | `out/examples.txt` | E-S4.2, E-S4.3, E-S4.5 (R2-06) |
| `gamma_sweep.luau 1000 600` (≈ 6 min) → `gamma_fit.luau`, `bold.luau` | `out/gamma_sweep.txt`, `gamma_data.luau`, `gamma_fit.txt`, `bold.txt` | E-S4.4 |
| `props.luau 200000` | `out/props.txt` | E-S4.5 |
| `sim.luau table` (`WIDE=1`: 20,000 crafts), `sim.luau tune`, `sim.luau alt` | `out/table.txt`, `table_wide.txt`, `tune.txt`, `alt.txt` | E-S4.6–E-S4.8 |

### E-S4.1 Stat constants: rationale, ranges, placeholders

- Floors: a botched step keeps 70 % purity, 30 % of the edge, 50 % of the toughness, 60 % of the damage, so skill
  spans ×1.4 (Purity) to ×3.3 (Sharpness). `EDGE_REF` 6.0 = F1/F5's main chain 5.433 / 0.91; `EDGE_GAIN` 1.0: a
  fully edged Steel blade at Sharpness 70 hits ×1.7 a blunt bar of equal mass. `MASS_REF` 0.80 kg (F5 0.7929);
  `MASS_BIAS` 0.4: ×2 mass → +25 %, ×0.5 → −18 %; `MASS_FACTOR_MAX` 1.3 reached at ≈ 2.25 × the reference mass
  (F4 cleaver, 3.23 kg). `DAMAGE_BASE` 28 keeps flawless swords at 36–44 with headroom to 100. Balance: real swords
  balance 5–15 % of their length in front of the guard; plateau 0.04–0.12 of reach, F4 cleaver (β 0.280) 47.
- Damage uses the cutting profile `c = cutIndex · clamp(L / EDGE_REF)` (R2-12 accepted; R1-48 answered: cutIndex stays
  in S2's report). The cleaver's `c` falls from 1.00 (edge only) to 0.13, so wide and heavy designs lean on mass and
  no design dominates: flawless F1 40.7, C08 greatsword 43.9, C06 sabre 43.4, F4 38.5, F3 36.7, F5 36.2.
- Ranges (Iron | Steel): Sharpness 9.45–45 | 14.7–70, Durability 17.5–50 | 19.3–55, Damage 10.1–61.9 (Steel, c = 1,
  mass cap), Reach ≤ 5.28 (hitbox diagonal).
- Phase 2+ `qualityTier` placeholders for S1's disabled rows: Bronze 1.05, Mithril 1.35, Obsidian 1.30, Wood and
  Leather 1.00, re-tuned with the material economy (a free material with a high T is a rarity slider).
- Phase 2 stat hooks: SwingSpeed = `clamp(60·sqrt(I_ref / I_grip), 0, 100)` (prices heavy designs, then
  `MASS_FACTOR_MAX` can relax); Quench bias `q ∈ [−1, 1]`: `h ← h·(1 + 0.2q)`, `k ← k·(1 − 0.2q)`; Assembly
  `Balance ← Balance·lerp(0.85, s_asm)`.

### E-S4.2 Fixture inputs and outcomes (S2 live analysis)

| Fixture | mass | reach | balance | edge | cut | c | F_mass | Balance | H | K | T | D S/H/Sh | tiers | ceiling | cap |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F1 Arming (Steel blade) | 0.7924 | 3.310 | 0.127 | 5.433 | 0.72 | 0.656 | 0.997 | 99 | 0.70 | 0.5126 | 1.0050 | .0288/.1037/.0989 | N/N/N | 1.0176 | Rare |
| F2 Minimal | 1.0813 | 3.102 | −0.057 | 4.980 | 0.43 | 0.353 | 1.098 | 81 | 0.45 | 0.50 | 1.0000 | .0797/.0176/.0282 | N/N/N | 1.0055 | Rare |
| F3 Rapier (Steel) | 0.3065 | 4.230 | −0.063 | 7.409 | 1.00 | 1.000 | 0.771 | 82 | 0.70 | 0.55 | 1.0200 | 0/.4423/.6104 | N/H/H | 1.2573 | Epic (Ham.) |
| F4 Cleaver | 3.2303 | 3.257 | 0.913 | 5.724 | 0.13 | 0.128 | 1.300 | 47 | 0.45 | 0.50 | 1.0000 | .4590/.1572/.3420 | H/N/H | 1.1809 | Epic (Sm.) |
| F5 Starter (Iron) | 0.7929 | 3.310 | 0.128 | 5.433 | 0.72 | 0.656 | 0.997 | 100 | 0.45 | 0.50 | 1.0000 | .0288/.1037/.0989 | N/N/N | 1.0125 | Rare |
| C02 Arming Iron · Steel | 0.8305 · 0.8284 | 3.420 | 0.180 | 5.644 | 0.77 | 0.721 | 1.011 | 100 | .45 · .70 | .50 · .55 | 1 · 1.02 | .0355/.1137/.1318 | N/N/N | 1.0151 · 1.0354 | Rare |
| C06 Sabre (Steel) | 0.6831 | 3.815 | 0.361 | 6.480 | 0.89 | 0.891 | 0.954 | 100 | 0.70 | 0.5332 | 1.0133 | .0097/.2991/.5948 | N/H/H | 1.2374 | Epic (Ham.) |
| C08 Greatsword | 1.5152 | 3.950 | 0.326 | 6.392 | 0.62 | 0.617 | 1.226 | 100 | 0.45 | 0.50 | 1.0000 | .1563/.0992/.2487 | N/N/H | 1.1025 | Epic (Sh.) |

F5, Good mean scores 0.7993 / 0.7917 / 0.8736 (passed): P 0.9398, h 0.4229, k 0.4699, Sharpness 38.5487, Durability
42.0955, c 0.6557, F_mass 0.9973, F_edge 1.2528, F_forge 0.9167, Damage 32.0698, β 0.0387, Balance 99.56; Q terms
0.25·0.7993·1.0043 + 0.40·0.7917·1.0156 + 0.35·0.8736·1.0148 = 0.8326 → Uncommon (Rare from 0.84). F1, same player:
Sharpness 59.8337, Damage 35.5240, T 1.0050, Q 0.8329. Damage / Sharpness / Durability at S3's mean scores:

| Fixture | Poor | Average | Good | Elite | Perfect |
|---|---|---|---|---|---|
| F5 | 22.5 / 18.6 / 26.1 | 28.6 / 29.6 / 36.4 | 32.1 / 38.5 / 42.1 | 33.6 / 41.8 / 44.6 | 36.2 / 45.0 / 50.0 |
| F1 | 23.7 / 28.5 / 26.5 | 30.9 / 45.4 / 36.9 | 35.5 / 59.8 / 43.0 | 37.6 / 65.1 / 45.7 | 40.7 / 70.0 / 51.3 |
| F3 | 18.9 / 26.4 / 27.2 | 25.1 / 42.1 / 37.4 | 30.3 / 58.6 / 44.3 | 32.8 / 64.8 / 47.7 | 36.7 / 70.0 / 55.0 |
| F4 | 26.7 / 17.0 / 25.7 | 32.4 / 26.9 / 35.6 | 35.0 / 37.2 / 41.4 | 36.2 / 41.1 / 44.2 | 38.5 / 45.0 / 50.0 |

### E-S4.3 Golden outcome cases (T-CR-02; weights 0.25 / 0.40 / 0.35, pass ≥ 0.50)

| Case | Mat | Tiers | D | Scores | d | Q | By score | Cap | Rarity |
|---|---|---|---|---|---|---:|---|---|---|
| A Average, F5 | Iron | N/N/N | .0288/.1037/.0989 | .62/.64/.63 | 1.0043/1.0156/1.0148 | 0.6394 | Uncommon | Rare | Uncommon |
| B Good+, F5 | Iron | N/N/N | same | .82/.80/.90 | same | 0.8505 | Rare | Rare | Rare |
| C Perfect, just Normal | Steel | N/N/N | .1999 ×3 | 1/1/1 | 1.0300 ×3 | 1.0506 | Epic | Rare | **Rare** (cap binds) |
| D Good, F3 | Steel | N/H/H | 0/.4423/.6104 | .80/.72/.85 | 1.0000/1.2954/1.3270 | 0.9872 | Rare | Epic (Ham.) | Rare |
| E D, Sharpening failed | Steel | N/H/H | same | .80/.72/.45 ✗ | same | 0.7444 | Uncommon | Epic (Ham.) | Uncommon |
| F Elite, F4 | Iron | H/N/H | .4590/.1572/.3420 | .83/.86/.95 | 1.2986/1.0236/1.2766 | 1.0460 | Epic | Epic (Sm.) | Epic |
| G F, both Hard failed | Iron | H/N/H | same | .48 ✗/.86/.49 ✗ | same | 0.6332 | Uncommon | Rare | Uncommon |
| H Good, Smelting Hard only | Steel | H/N/N | .2000/.1037/.0989 | .75/.79/.87 | 1.2500/1.0156/1.0148 | 0.8816 | Rare | Epic (Sm.) | Rare |
| I Hammering timed out | Iron | N/N/N | as A | .80/0/.87 | as A | 0.5099 | Common | Rare | Common |

### E-S4.4 γ (`gamma_fit`, `bold`; S3's code, 1,000 runs per cell, 600 for PrecisionTrace, same seeds at every x)

Least-squares slope of the mean effective score against `a = D − dMin`: relative drop β; a step's expected
contribution `(1 + γa)·m(a)` is non-decreasing iff `γ ≥ β / (1 − 2β·aMax)`. Good: β Hard HoldZone 0.097 / 0.109
(Iron / Steel), TimingStrike 0.090 / 0.094, PrecisionTrace 0.045 / 0.047; γ needed 0.076 (Normal) and **0.133**
(Hard, HoldZone Steel); Elite 0.060 / 0.097; Average 0.216 / 0.424. At γ = 0.15, Good's top/bottom ratio is ≥ 1.015
in every family × tier × material; Average's Hard ratio is 0.90–0.97. Expected Q of a craft, every step at D:

| Profile, material | γ | N 0.00 | N 0.10 | N 0.20 | H 0.20 | H 0.30 | H 0.45 | H 0.60 | H 0.80 | H 1.00 |
|---|---|---|---|---|---|---|---|---|---|---|
| Elite, Iron | 0 · 0.15 | 0.899 · 0.899 | 0.896 · 0.909 | 0.893 · 0.919 | 1.080 · 1.080 | 1.077 · 1.093 | 1.072 · 1.112 | 1.062 · 1.126 | 1.052 · 1.147 | 1.046 · 1.172 |
| Good, Iron | 0 · 0.15 | 0.828 · 0.828 | 0.822 · 0.835 | 0.819 · 0.844 | 0.968 · 0.968 | 0.963 · 0.977 | 0.954 · 0.989 | 0.941 · 0.998 | 0.923 · 1.007 | 0.912 · 1.022 |
| Good, Steel | 0 · 0.15 | 0.840 · 0.840 | 0.836 · 0.848 | 0.833 · 0.858 | 0.980 · 0.980 | 0.975 · 0.990 | 0.963 · 0.999 | 0.947 · 1.004 | 0.935 · 1.019 | 0.919 · 1.030 |
| Average, Iron | 0 · 0.15 | 0.635 · 0.635 | 0.628 · 0.637 | 0.618 · 0.637 | 0.667 · 0.667 | 0.658 · 0.668 | 0.639 · 0.663 | 0.614 · 0.651 | 0.582 · 0.634 | 0.557 · 0.624 |

### E-S4.5 Properties and the recompute check

`props.luau`: 200,000 random crafts (random tiers, D, scores, materials) and the exhaustive cap grid (2³ tier
patterns × 11³ scores × 2 materials = 21,296 cases): 0 failures for d monotone in D inside each tier, Hard at 0.2 >
Normal at 0.1999, rarity ≤ cap and ≤ byScore, no Epic without a passed Hard step, Q monotone in each score (same pass
pattern), in T and in D, pass ≥ fail, stats in [0, 100], Reach = physics reach, inclusive thresholds, cleaned parts
change neither T nor H. R2-06: F5 flawless Q 1.0125 under the MVP plan and 1.0125 recomputed under a synthetic 6-step
plan (weights 0.15/0.24/0.21 + 0.15/0.15/0.10, renormalized to 0.25/0.40/0.35).

### E-S4.6 Sensitivity (thresholds 0.55 / 0.84 / 1.04)

| Variation | Effect |
|---|---|
| φ = 0.5 · 1.0 (instead of 0.75) | every target holds; Average Commons, all-Normal Iron 16 · 6 % (12 %), all-Hard 26 · 2 % (13 %) |
| equal weights 1/3 | every target holds (min margin 5.4); largest moves Elite N/H/H Epic 62 → 45 %, H/N/H 45 → 56 %, Good H/N/N Rare 77 → 84 % |
| 20,000 crafts (`WIDE=1`) instead of 2,000 | every target within 0.7 points of the 2,000-craft value; min margin 6.2 |

### E-S4.7 Grid search and the full rarity table (`sim.luau tune`, `table`)

Grid U 0.40–0.69, R 0.70–0.95, E 0.90–1.25 (0.01 steps) per Steel T, γ 0.15, targets T1–T11 of §8.4:

| T Steel | feasible triples | U | R | E | best min margin |
|---|---:|---|---|---|---:|
| 1.00 | 300 | 0.40–0.64 | 0.83–0.85 | 1.02–1.05 | 8.2 |
| **1.02** | 225 | 0.40–0.64 | 0.83–0.85 | 1.03–1.05 | **6.15** (at 1.04; T4 18.85 %) |
| 1.03 · 1.04 | 150 · 75 | 0.40–0.64 | 0.83–0.85 | 1.04–1.05 · 1.05 | 2.2 · 0.1 |
| ≥ 1.05 (1.10 = draft) | 0 | — | — | — | T4: Good all-Hard Steel Epic 71 %, T8: 94 % at 1.10 |

Chosen 0.55 (T9/T10 margins 38/29) / 0.84 (T2 centre) / 1.04 with T Steel 1.02. Mean Q (Iron · Steel) and crafts
with a failed step: Elite 0.909 · 0.926 (N/N/N) to 1.093 · 1.114 (H/H/H), no fails; Good 0.835 · 0.847 to 0.978 ·
0.990, ≤ 2 %; Average 0.635 · 0.633 to 0.668 · 0.660, fails 20 · 26 % (N/N/N) to 61 · 68 % (H/H/H); Poor 0.34–0.35,
99–100 %. Cap-bound crafts (byScore above the cap): 0 % in every row at the reference D; the Normal cap binds only on
near-flawless Steel all-Normal crafts with D ≈ 0.2 (case C).

### E-S4.8 Cap-rule alternatives (R3-05; designer default Q10 = Max)

| Rule | Difference from Max (`sim.luau alt`) |
|---|---|
| Weight-majority (Hard on ≥ 50 % of the weight) | only N/N/H, Elite: Epic 2 → 0 % Iron, 13 → 0 % Steel; contradicts the draft's "Hell on sharpening" example |
| Striking step (Smelting cannot lift the cap) | none for human profiles: Smelting-Hard-only gives 0 % Epic under Max too (Elite's mean Q 0.953 Iron, 0.97 at Smelting D = 1.0) |

The residual is bots: a Perfect-input bot on a Smelting-Hard-only design scores Q ≈ 1.06 (D 0.2) to 1.10 (D 1.0),
an Epic. The striking-step rule would remove that cheapest lever but not the Sharpening one, so the accepted risk
stays "Epic is botable in the MVP" (Q17, S8 §14.8).

---

## Evidence S5

Prototypes: `docs/spec/prototypes/S5/` (Lune 0.8.9: `lune run <file>`; rojo 7.7.0-rc.1). Every output below is the
saved `*.out.txt` of the run made for this revision.

### E-S5.1 Guard fuzz and cost (`guard_fuzz.luau`, `lib/Guard.luau`)

50 000 random hostile payloads (NaN, ±inf, −0, 2^53, huge strings, bad UTF-8, NUL, a newline + fake log prefix,
mixed tables, functions, nested 5 deep, buffers of 0…20 000 B) × 6 validators: **0 exceptions**, 3 876 accepted,
0 error strings with control characters, 2.12 µs per check on average.

| Case | Result | Cost | Nodes |
|---|---|---|---|
| Submit, buffer at the 14 348 B cap | ok | 0.79 µs | 5 |
| Submit, 14 349 B | `args.timeline: buffer too large` | 0.80 µs | 5 |
| Submit, timeline sent as a table | `args.timeline: expected buffer` | 0.89 µs | 5 |
| Blueprint.Save `plain(4)`, 24 parts | ok | 117.26 µs | 439 |
| SetSettings with 64 uiFlags | ok | 22.75 µs | 80 |
| SetSettings with 300 uiFlags | `payload too large` (256-node cap) | 80.46 µs | 316 |
| ReportDesync · TeleportHome · Showcase.Place | ok | 0.73 · 0.08 · 0.58 µs | 4 · 1 · 3 |
| 5-deep draft | `args.draft.a.b.c.d: too deep` | — | — |
| hostile key inside a path | printed as `args.draft.<key>.a.b.c` | — | — |

The same harness applies unchanged to S1's `Canonical.draft` and S3's `Timeline.decode` (S8 reuses it).

### E-S5.2 Session machine scenarios (`session_scenarios.luau`, `lib/SessionMachine.luau`)

**50 / 50 checks pass.** Covered: happy path (3 steps, judge called exactly 3 times, complete once); re-open returns
the same seed and pattern hash with the remaining countdown (0 after the countdown); duplicate submit keeps the first
run; out-of-order open or submit refused; too early refused with the state unchanged and accepted exactly at the
early bound; late allowance = `LATE_SOFT_MS + A`; no flag at the soft bound, LateSubmit beyond it; scored at the hard
bound, timed out beyond it with the session continuing; no timeout exactly at the deadline, a timeout event after
it; idle abort after (not at) the limit; no submit after an abort; HIGH flag: clamped score, passed, flag kept, no
ScoreMismatch; Invalid → Aborted(InvalidInput); a judge throw leaves the state unchanged and the caller aborts
Internal; open refused after expiry and the sweep aborts the expired session; abandon once, no open after it; a
last-step timeout finalizes and a late duplicate gets the stored timeout; the median ignores one inflated ping
(A = 200 ms) and a submission beyond `D + LATE_SOFT + A(median)` is flagged; the sample count is bounded at 160;
ScoreMismatch when `clientScore ≠ rawScore`; desync refused in Ready and aborting with Internal in Playing; a second
open while one is in flight → `E_BUSY`; the sweep skips an opening session; idle abort after a cancelled open.
Fixed in this revision: a timed-out run records `durationMs = D`. The early-submit and foreign-step cases ran the
refuse-and-continue rule; §7.6 now aborts the craft (re-run: §17.2).

Durations: compliant worst case = Σ (`READY_IDLE` 120 s + C 3 s + D + `LATE_HARD` 5 s + A 2 s) with S3's MVP maxima D
= 18 s (Smelting, Volume ×1.2), 13.9 s (Hammering: 15 strikes × 903 ms + 400 ms at Hard, Asymmetry 1), 31 s
(Sharpening) = **≈ 452.9 s** < `SESSION_MAX_MS` 600 s (the 11.5 s used before is a typical Hard Hammering length;
20,000 seeds at Iron/Hard x = 0 reach 12.6 s). Nominal session (4 s results card, 200 ms RTT, D = 15 / 10.8 / 20 s)
= **67.4 s**.

### E-S5.3 Timing model (`timing_sim.luau`)

Model (assumptions, not measurements): per-player base RTT lognormal (median 120 ms, σ 0.6; p90 ≈ 260 ms, p99
≈ 490 ms); each ping sample and the submission RTT = base × lognormal(0, 0.25); 2 % of submissions carry a spike of
+0.3…4 s; 1 % are delayed by a client hitch of 0.1…1.5 s; frame quantization 3 × U(0, 16.7) ms; client clock drift
±100 ppm. 400 000 honest submissions per D; A from the first sample ("open") or the median of 4 Hz samples.

| D | early refusals | beyond D + tol + A, tol = 1000 / **1500** / 2500 / **5000** / 10 000 ms (A = median) |
|---|---|---|
| 7 000 ms | 0 | 1.862 % / **1.305 %** / 0.760 % / **0.0003 %** / 0 |
| 15 000 ms | 0 | 1.808 % / **1.271 %** / 0.740 % / **0 %** / 0 |
| 31 000 ms | 0 | 1.832 % / **1.283 %** / 0.759 % / **0.0003 %** / 0 |

A from one sample gives the same rates within 0.01 points; the median removes the single-sample inflation exploit
(R3-20). One strict bound would either fail ≈ 1 % of honest steps or let slow motion through, hence the two bounds:
`LATE_SOFT_MS` only flags (≈ 1.3 % honest rate, meaningful per player only well above it), `LATE_HARD_MS` times out.
R4b-06's alternative `LATE_HARD_MS` = 10 000 removes the last ≈ 3 per 10⁶ honest timeouts but lets 2× slow motion
on a 7 s step pass as a mere flag; 5000 is kept (slow motion is flagged-only anyway, Q17).

Slow motion at speed 1/k (flagged when `(k − 1)·D > LATE_SOFT + A − RTT`, timed out when
`(k − 1)·D > LATE_HARD + A − RTT`, RTT = the submission's round trip; a 100 ms ping gives A = 200 and RTT = 100, a
ping held at 1 s gives A = 2,000, the cap, and RTT = 1,000):

| D | flagged above k (ping 100 ms / held at 1 s) | timed out above k (ping 100 ms / held at 1 s) |
|---|---|---|
| 7 s | 1.229 / 1.357 | 1.729 / 1.857 |
| 11.5 s | 1.139 / 1.217 | 1.443 / 1.522 |
| 15 s | 1.107 / 1.167 | 1.340 / 1.400 |
| 31 s | 1.052 / 1.081 | 1.165 / 1.194 |

### E-S5.4 AnalysisQueue arithmetic

At 60 Hz, 4 ms per Heartbeat = 240 ms of work per second. A conservative 75 ms in Lune × 2.6 (Studio
factor, §4.9) = 195 ms (S2's own ceiling is 75 ms in Studio, so the real drain is shorter) → 49 Heartbeats ≈ 0.81 s per job; a full queue of 16 jobs ≈ 13 s, under
`REQUEST_TIMEOUT_S` 20 (R5b-08 computed 19 frames and ≈ 5 s with Lune costs). The checkpoint must sit at top-level
loop points: Luau cannot yield inside `table.sort` comparators, string callbacks or metamethods (yielding inside
`pcall` is fine). P0 (`Minigames.prepare`) is one burst within S3's generate budget (≤ 5 ms in Lune ≈ 13 ms in
Studio), queued first so a StartStep never waits behind analyses. `Minigames.judge` (≤ `REPLAY_BUDGET_MS` 8 ms in
Lune ≈ 21 ms Studio) runs in the Submit handler: a yield there would split the arrival-stamped step result from its
commit for no gain, since judge has no checkpoint (engineering item in §17). Recompute (P2) uses only idle worker
time: 150 stale items at the worst-case cost ≈ 2 min of background, and only items actually shown are queued.
An Actor is feasible (Rojo `init.meta.json {"className": "Actor"}` gives `AnalysisWorker (Actor)` in the sourcemap,
R5b-08) but not needed (§1.6).

### E-S5.5 Rate limits (`ratelimit_sim.luau`, `lib/RateLimit.luau`)

Flood at 500 req/s for 60 s on every action (Roblox's per-client ceiling is ≈ 500/s):

| Action | accepted / 30 000 | Action | accepted / 30 000 |
|---|---|---|---|
| Profile.Hello | 3 | Craft.Submit | 34 |
| Profile.Sync | 8 | Craft.Abandon · Resume | 14 · 14 |
| Profile.SetSettings | 34 | Craft.ReportDesync | 8 |
| Blueprint.Get | 129 | Showcase.Place · Clear | 65 · 65 |
| Blueprint.Save | 23 | Showcase.Scrap | 34 |
| Blueprint.Rename · Delete | 34 · 34 | Showcase.Inspect | 189 |
| Craft.Begin | 8 | Showcase.GetItems | 129 |
| Craft.StartStep | 34 | Showcase.TeleportHome | 20 |
| global (all channels) | 929 (15.48/s) | | |

Legit traces, all fully accepted except where noted: 5 back-to-back crafts with 8 s steps (Begin 5/5, StartStep
30/30 including one desync re-open per step, Submit 15/15); autosave every 60 s plus a manual save every 10 s for 30
min (210/210); browsing 30 stands in 15 s (30/30); a 150-item grid in 13 calls of 12 ids within 4 s (13/13);
rearranging 6 slots in 3 s (6/6); TeleportHome every 3 s for a minute (20/20). Ctrl+S mashed 6× in 2 s → 4/6 (S6
disables Save while one is in flight).

### E-S5.6 Rojo project verification

`prototypes/S5/rojo/` (draft tree) and `docs/spec/review/R5b/rojo-alt/` (the self-contained tree adopted here), rojo
7.7.0-rc.1: `rojo build` and `rojo sourcemap --include-non-scripts` succeed. The sourcemap lists
`Blacksmith.Remotes` (Folder from `src/shared/Remotes.model.json`) with the 4 RemoteEvents, and
`BlacksmithServer.Vendor.ProfileStore` as a ModuleScript from `src/server/Vendor/ProfileStore.project.json` →
`vendor/ProfileStore/ProfileStore.luau`; `tests/` is absent from the place. `out_alt.rbxlx` contains
`<bool name="StreamingEnabled">false</bool>` and `<bool name="EnableMouseLockOption">false</bool>`. Nodes without
`$path` ignore unknown instances, so existing Workspace content (Terrain, Camera) is untouched. Whether the live-sync
plugin applies service `$properties` is unverified (build checklist item 4). World size with streaming off: ≈ 946
static + ≤ 1 392 dynamic parts (S7 E-S7).

### E-S5.7 Payload sizes and paging (`payload_size.luau`; S1's measured JSON sizes)

Model for remote sizes (not a measurement): number 9 B, boolean 2 B, string 2 B + length, table 3 B + entries,
buffer 3 B + bytes before compression.

| Payload | Size |
|---|---|
| Craft.Submit: honest timelines (measured, E-S3.6) HoldZone 198–396 B · TimingStrike 34–48 B · PrecisionTrace 2,322–4,240 B · cap 14 348 B; the model adds 127 B | 0.32–0.51 · 0.16–0.17 · 2.39–4.26 · 14.14 KB |
| Blueprint.Save, raw doubles: 12 parts · 24 parts (model) / S1's worst JSON draft at 24 parts | 2.19 · 4.24 KB / 8 175 B |
| Craft.StartStep reply: PrecisionTrace (256-point source) · TimingStrike | 4.90 · 0.40 KB |
| Showcase.Inspect reply (S7 InspectView) | 0.91 KB |
| Join snapshot at caps (S1: 40 × 735 B + 150 × 277 B summaries) | 70 950 B → 3 pages of ≤ 32 768 |
| Blueprint.Get / Showcase.GetItems worst record (S1: 8 799 B / owner view 9 438 B at 24 parts) | 3 per page; the rest listed |

### E-S5.8 Save cadence and DataStore budgets

Vendored ProfileStore (commit 45c9847) facts used: `Profile:Save()` removes the profile from the autosave list and
re-inserts it right behind the autosave index (lines 1172–1189), so its next autosave comes after a full cycle;
the autosave loop advances one profile every `AUTO_SAVE_PERIOD / n` and skips profiles loaded less than 150 s ago
(2115–2160); `OnSave` fires before every save (715) and `OnLastSave(reason)` with "Manual", "External" or
"Shutdown" when a session ends (717); `ProfileStore.DataStoreState` is "NotReady" until probed; `OnError(message,
store, key)` carries the key.

Per-key write limit 4 MB/min (Creator Docs, data store limits; a throttled key queues the request and skips it
temporarily, it does not drop it):

| Profile size | Steady (1 write/min) | Burst (2 writes in a minute) |
|---|---|---|
| S1 typical heavy player 280 319 B | 0.28 MB (7 %) | 0.56 MB (14 %) |
| S1 worst case at 40 / 150 / 24 parts: 1 822 966 B | 1.82 MB (46 %) | 3.65 MB (91 %) |
| S1 storage block 2 000 000 B | 2.00 MB (50 %) | 4.00 MB (100 %) |

A burst needs the autosave or the final EndSession save inside the same minute as an explicit save; because the
explicit save waits 60 s after any write and resets the autosave position, this happens only around a join burst
(the autosave index catching up) or on leave. Server budget: `UpdateAsync` counts against both `StandardRead` and
`StandardWrite`, 60 + 40 × 8 = 380/min each; worst case ≈ 8 explicit + 8/5 autosaves + ≈ 4 join/leave saves ≈
14/min (4 %). The size-aware interval of R3-09 / R4a-11 / R5b-07 (`max(10, ceil(60·bytes/2 000 000))`) gives the
same bound at large sizes but saves small profiles more often; the review fixed 60 s for simplicity (§9.7).

### E-S5.9 Telemetry volume and field combinations

Combinations per event (fields multiplied; 7 rarity ids, 3 steps, 2 tiers, 8 tier signatures): DataLoaded 5 × 2 =
10 · DataIssue 7 · BlueprintSaved 2 × 9 × 3 = 54 · BlueprintRejected 10 · CraftStarted 8 × 3 × 3 = 72 · StepScored
3 × 2 × 4 = 24 · CraftCompleted 7 × 8 × 7 = 392 · CraftAborted 9 × 3 = 27 · ItemDisplayed 7 · AntiCheatFlag ≈ 14
flags × 22 places × 2 = 616 · Desync 3 · RateLimited 19 · FilterFailed 1 · Perf 4 → **≈ 1 250** (≤ 1 400 with 8
rarity ids), against the 8 000 limit. Volume: a nominal craft (67 s) emits CraftStarted + 3 StepScored +
CraftCompleted ≈ 4.5/min, plus one BlueprintSaved per autosave and sampled Perf: under the 15/min bucket and the
platform share of 20/min/CCU (+120 per experience). The draft's `Tiers` field must change to "max tier + count of
Hard+" in Phase 2 (7 steps × 5 tiers = 78 125 signatures).

### E-S5.10 Alternatives considered

| Choice | Alternative | Why not |
|---|---|---|
| per-(player, channel) FIFO for mutating handlers (R5b-21) | expected revision on Save, re-checked after the yield | the lane fixes every yielding handler at once (Save vs Delete, Begin vs Begin) |
| batched `Get` with `rest` | a parts-only thumbnail payload | one record shape, S6 caches by `(id, revision)` |
| paging at 32 KB | one ≈ 70 KB snapshot message | no documented cap; paging is cheap and S1 asked for it |
| GUID upserts and `itemId = sessionId` | a request-id cache | idempotency without server memory (R1-03) |
| `LATE_HARD_MS` 5000 | 10 000 (R4b-06) | E-S5.3 |
| fixed 60 s save interval | size-aware interval | E-S5.8 |
| judge in the handler | judge in the AnalysisQueue | E-S5.4 |

---

## Evidence S6

Prototypes are Lune 0.8.9 scripts in `docs/spec/prototypes/S6/` (run `lune run <script>.luau` from that folder).
All outputs below were re-run for this revision.

### E-S6.1 Stage scale, containment and camera fit (`camera_fit.luau`)

FOV 50° vertical → focal 1158 px at 1080 px of viewport height (horizontal FOV 79.3°).

| k | frame-all d (display studs) | px per bp stud at frame | 0.05-bp detail at min distance | zoom range | float32 ulp at y = 1000 (bp) |
|---:|---:|---:|---:|---:|---:|
| 1 | 5.25 | 220.6 | 57.9 px | 21× | 6.1e-5 |
| 2 | 10.50 | 220.6 | 115.8 px | 42× | 3.1e-5 |
| **4** | **21.00** | 220.6 | 231.6 px | 84× | 1.5e-5 |
| 6 | 31.49 | 220.6 | 347.4 px | 126× | 1.0e-5 |

- k = 4: orthographic frame-all `OrthographicSize` 18.46 display studs (length-limited; width-limited 8.15); 0.0181
  display studs per px at frame-all; `CAM_MIN_DIST` 1.0, `CAM_MAX_DIST` 84 = 4 × 21.0.
- A `MIN_DIM` 0.02 side at `CAM_MIN_DIST`: 0.02 × 4 = 0.08 display studs × 1158 px = 92.6 px.
- Containment per axis: |x|, |z| ≤ 16 and |y − 2.5| ≤ 18.5 for a part centre (`POS_ABS_MAX` 16, HC y = 2.5), plus the
  half-diagonal of a 6³ part 3√3 = 5.196 → ≤ 23.70 bp = 94.8 display studs < 120 (enclosure half-size). With 64 the
  same bound is 71.7 bp = 287 display studs, outside the reserved 256-stud cube (why `POS_ABS_MAX` is 16).

### E-S6.2 UI scale and layout fit (`ui_scale.luau`)

| Resolution | uiScale | left / right panel px | viewport area | fits | body px |
|---|---:|---|---|---|---:|
| 1024 × 640 | 0.75 | 210 / 255 | 559 × 522 | no (unsupported) | 12.0 |
| 1280 × 720 | 0.75 | 210 / 255 | 815 × 602 | yes | 12.0 |
| 1366 × 768 | 0.75 | 210 / 255 | 901 × 650 | yes | 12.0 |
| 1920 × 1080 | 1.00 | 280 / 340 | 1300 × 942 | yes | 16.0 |
| 2560 × 1440 | 1.33 | 373 / 453 | 1733 × 1275 | yes | 21.3 |
| 3840 × 2160 | 2.00 | 560 / 680 | 2600 × 1942 | yes | 32.0 |

A user multiplier above 1.1 broke the 1080p layout (right panel 738 px of 942 needed), one reason the saved UI-size
setting is cut (R2-09); `UI_SCALE_MIN` 0.75 keeps body text at 12 px (0.67, the pure 720p ratio, gives 10.7 px).

### E-S6.3 Snap cleaning for any positive step (`snap_clean.luau`)

| Variant | delta mismatches | sum mismatches (x0 + delta vs typed literal) |
|---|---:|---:|
| draft `floor(v·1e9 + 0.5)/1e9` | 0 / 16 020 | 0 / 176 220, but a 1e-10 step snaps to 0 |
| `%.12g` (relative) | 0 / 16 020 | 7 / 176 220 (steps 0.05 … 1) |
| **`round(v·1e12)/1e12`, steps ≥ 1e-9, abs < 1e3** | 0 / 16 020 | 0 / 176 220 |

- Step 1e-10, delta 3.7e-10 → the raw product 4.0000000000000001e-10 is kept (below `SNAP_CLEAN_MIN_STEP`).
- Guard: step 5e-324 with delta 0.5 → treated as free (|Δ/s| > 1e12), no infinity.
- Largest change over 200 000 values in [−16, 16]: 5.01e-13 stud.

### E-S6.4 Gizmo jitter and the custom handles (`gizmo_math.luau`)

| angle between axis and view ray | bp studs per 1 px at frame-all | gain vs 90° |
|---:|---:|---:|
| 90° | 0.00453 | 1.00× |
| 30° | 0.00908 | 2.00× |
| 15° | 0.01757 | 3.88× |
| 12° | 1/sin 12° | 4.81× |
| 10° | 0.02624 | 5.79× |
| 5° | 0.05254 | 11.59× |

Handles hide below 12° (gain ≤ 4.8×) and fade from 18°. Custom HandleAdornments instead of runtime `Handles` /
`ArcHandles`: those lack plane handles, a constant screen size, on-top drawing and blueprint-space axes. A 110-px arm
is 0.0237–1.90 bp studs long depending on depth (scale 1.0).

### E-S6.5 Euler display round trip (`euler_quat.luau`)

- 200 000 random rotations: max (1 − |q·q'|) = 3.3e-16; max angle error 2.96e-6° (near gimbal, where asin loses
  precision).
- Gimbal (90, 30, 20) → canonical (90, 10, 0), with the cache → (90, 30, 20), rotation error 0.
- Typed (170, 0, 0): canonical pick (10, 180, 180); smallest Σ|angle| and continuity pick (170, 0, 0) (R6-18).
- X sweep 0…360° in 7.5° steps: field jumps > 30°: canonical 2, continuity 0.

### E-S6.6 History memory (`history_mem.luau`)

200 commands × 64 part patches: 23 285 KB, 1 863 B per patch (before + after) → 931 B per part record →
`HISTORY_RECORD_BUDGET` 6000 records ≈ 5.6 MB. Packed transform-only patches would be 497 B; not needed at this budget.

### E-S6.7 Mirror exactness (`mirror.luau`, `mirror_quat.luau`)

- Block, Wedge, CornerWedge mirrored across x = 0 and z = 0 for every CornerWedge apex convention: max vertex error 0,
  0 and 1.0e-15; mirroring twice restores the part exactly; 0 improper (det −1) results.
- Block rotZ(+30°) at x = +0.4 → rotZ(−30°) at x = −0.4. Using the wrong CornerWedge σ gives a 0.6-stud error, so the
  only implementation is `Blueprint/Mirror` (S2's math).
- Closed-form quaternion mirrors = matrix forms within 1.1e-15 over 20 000 random q.

### E-S6.8 Orthographic read-back and telephoto fallback (R5a-01)

- Studio 0.745 accepts `ProjectionType`/`OrthographicSize` writes without error and ignores them, so a pcall never
  detects the lack of support; only reading the property back does.
- Fallback: FOV 20°, `d = OS/(2·tan 10°)` = 2.8356·OS. Frame-all OS 18.46 → d = 52.3; `ORTHO_FALLBACK_MAX_OS` 38.8 →
  d = 110.0 < 120 (enclosure half-size). The draft's 6° fallback put the eye at 18.46/(2·tan 3°) = 176 display
  studs, outside the enclosure. `ViewStretch` is never relied on.

### E-S6.9 Forge pacing (`flow_timing.luau`)

| Step | presentation (s) | play (s) |
|---|---:|---:|
| Smelting (HoldZone) | 12.9 | 15.0 |
| Hammering (TimingStrike) | 12.9 | 11.2 |
| Sharpening (PrecisionTrace) | 12.9 | 17.7 |

First time 101.8 s per sword (43.9 s play, 58.0 s presentation including reading); experienced (skips the text)
75.8 s (31.9 s presentation). S3's draft durations; showing the step title during S7's camera move keeps the
experienced overhead near 30 s.

### E-S6.10 Trace canvas, band widths and mapping

| Resolution | canvas px | band at halfWidth 0.037 | at 0.0156 |
|---|---|---:|---:|
| 1280 × 720 | 1152 × 384 | 28.4 | 12.0 |
| 1920 × 1080 | 1560 × 520 | 38.5 | 16.2 |
| 2560 × 1440 | 2080 × 693 | 51.3 | 21.6 |

Band = 2·halfWidth·H px. 0.037 is S3's draft Iron/Normal value (illustrative; S3's retune sets the final ones).
Mapping: `InputObject.Position` and a ScreenGui's `AbsolutePosition` share the CoreUISafeInsets origin whatever
`IgnoreGuiInset` says (docs, GuiBase2d), so `u, v` from `AbsolutePosition/AbsoluteSize.Y` hold for any ScreenInsets;
S3's IgnoreGuiInset assumption is not needed (R5a-07).

### E-S6.11 Platform facts used (Creator Docs, checked in review)

- `GuiObject.Rotation` turns an object about its own centre, never its AnchorPoint; rotated frames do not clip
  descendants (R5a-04).
- `TextSize`, `UITextSizeConstraint.MaxTextSize` and `TextScaled` cap at 100 (R5a-11).
- `Path2D` exposes Closed, Color3, Thickness, Visible, ZIndex: no transparency, no fill; `SetControlPoints` warns
  above 50 points (R5a-10).
- Default camera scripts stop updating `Camera.Focus` under Scriptable; lighting detail and PointLights follow Focus
  (R5a-02).
- Fog is ignored while an Atmosphere exists, and Atmosphere has no Enabled switch (R5a-12).
- Turntables should move the viewport camera; lights and particles do not render in ViewportFrames (R5a-14, §13).
- `Active` GuiObjects mark mouse input as gameProcessed; releases over UI can be filtered too (R5a-05, R6-12).
- `GetStringForKeyCode` returns layout labels: AZERTY's M sits on `KeyCode.Semicolon`, digits read "&", "É" (R5a-03).
- `GuiService.ReducedMotionEnabled`, `PreferredTextSize`, `PreferredTransparency` are the player's Roblox settings
  (R6-11); TextChatService's chat window defaults to the top left (R6-10).
- HandleAdornments receive input only under `PlayerGui`.

### E-S6.12 Player-facing copy (initial `UI/Strings`)

| Key | Text |
|---|---|
| `OutOfHitbox` | "{n} part(s) stick out of the sword envelope (up to +{d} studs)" · "Move or shrink them into the blue box — Ctrl+I nudges inside" |
| `SlotMissing` | "A sword needs a {slot}" · "Add a part and assign it (Ctrl+{n})"; `Cleaned`: "Your {slot} is too small or hidden inside another part to count" |
| `SlotTooMany` · part-count hint | "Too many {slot} parts: {n}/{max}" · "{n} parts — a sword uses {min} to {max}" |
| `Disconnected` | "{Slot} floats {gap} studs from the {nearest slot}" · [Snap to touch] |
| `BladeNotAboveGrip` | "The blade must be on the tip side of the grip" · "Blade parts go toward +Y (right in the Flat view)" |
| `Dust` · `Enclosed` | "{n} tiny part(s) are ignored for difficulty (< {v} st³)" · "{n} part(s) are hidden inside others and ignored" |
| part limit · clamps | "A sword has at most 24 parts" · "max 16 from the origin" · "min 0.02" |
| snap hints | "Snap {step} — hold Shift for free, change it in the snap bar"; Rotate: "Free rotation — hold Shift to snap to {step}°"; toast "Snapping off — S" |
| Steel swatch | "Steel — better edge, +2 % quality, slightly tighter minigames; it does not make a step harder" |
| preview | "Very hard design — plays as Hard for now"; "Bolder designs pay inside a tier: each +0.1 difficulty adds ×{x}" |
| duplicate · delete | "Duplicated {n} parts — they overlap the originals until moved" · "Delete '{name}'? This cannot be undone. Items already forged keep their own copy." |
| StepResult fail | "47 % — needed 50 % · counts as 35 % · Epic not unlocked" |
| results lock · hint | "Epic needs a passed Hard step — bolder designs play Hard" · "Thinner or longer blades, asymmetry and surface detail play Hard. A passed Hard step unlocks Epic." |
| offset | "Your strikes were on average {n} ms late/early" · "[Use {−n} ms offset]" |
| HoldZone | "IN ZONE ✓" · "TOO COLD — pump ▲" · "TOO HOT — ease off ▼" · "Heat it up" · "Hold it" · hint "Tap to pump" · fire meter "Tap!" |
| empty states | "No blueprint ready — [Open the drafting table]" · "Forge a sword at the anvil first" · "No blueprints yet" |
| focus, menu | "The forge doesn't pause" |
| `E_NOT_READY` · `E_TIMEOUT` | "Waiting for your smithy…" · "No answer from the server — checking…" |
| `E_RATE_LIMITED` · `E_BUSY` | "Slow down a little" · "The forge office is busy — retrying" |
| `E_LIMIT_REACHED` | "Blueprint shelf full (40/40)" · "Storage full (150/150) — scrap an item" |
| `E_TOO_FAR` | "Go back to your smithy to do that" [My smithy] |
| `E_SESSION_ACTIVE` | "A forging is already in progress" [Resume] [Abandon] |
| aborts | `SessionExpired` "The forge went cold — this forging was cancelled"; `InvalidInput` "We couldn't verify that step, so this forging was cancelled"; `Idle` "You were away too long"; `SessionTimeout` "Time ran out for this forging"; `ServerClosing` "The server is restarting"; `DataUnavailable` "Your data can't be reached right now"; `CharacterLost` "Your smith left the forge — this forging was cancelled"; `Internal` "Something went wrong — nothing was lost" |
| banners | "Server restarting — your saved work is safe" · "Saving is delayed" · "That stand isn't available" |

### E-S6.13 Preview panel example (illustrative values)

```
PREVIEW                                                updated · "…" while editing
Mass 0.84 kg   Balance +0.57 st from the guard · Balance 100   Reach 4.12 st   Parts 14/24
Potential   Damage 28–41 · Sharpness 39–70 · Durability 32–50                  (all steps 50 % → 100 %)
Smelting    [Normal] 0.12 ▮▮▯▯▯  0.08 to Hard
Hammering   [Hard]   0.27 ▮▮▮▯▯  +0.07 · quality ×1.26                          hover: breakdown
Sharpening  [Hard]   0.38 ▮▮▮▮▯  +0.18 · quality ×1.28
Rarity cap Epic (Hammering: Hard) · Quality ceiling 121
hover: Hammering D = 0.27 → Hard (≥ 0.20) · Thinness 0.55 × 0.40 = 0.220 · Asymmetry (about x = 0) 0.10 × 0.30 =
       0.030 · Surface complexity 0.07 × 0.30 = 0.021 · material term 0 · works on all kept parts (14)
```

### E-S6.14 Theme tokens (initial values, RGB)

| Token | Value |
|---|---|
| `surface.1` / `.2` / `.3` | (28, 24, 22) / (38, 33, 30) / (16, 14, 13) |
| `border.subtle` / `.strong` | (58, 52, 48) / (84, 76, 70) |
| `text.primary` / `.secondary` / `.muted` / `.inverse` | (232, 220, 190) / (176, 164, 140) / (110, 104, 96) / (20, 17, 13) |
| `accent` / `.hover` / `.press` | (255, 104, 32) / (255, 176, 92) / (224, 84, 20) (S7's Ember and Flame) |
| `focus` | (255, 209, 102) |
| `ok` / `warn` / `danger` / `info` | (108, 200, 112) / (242, 193, 78) / (255, 77, 94) / (111, 168, 220) |
| `axis.x` / `.y` / `.z` | (242, 95, 92) / (123, 216, 143) / (90, 169, 242) |
| `stage.backdrop` / `.floor` / `.grid` / `.hitbox` | (27, 36, 51) / (20, 27, 38) / (46, 74, 102) / (127, 211, 255) |
| `sel.outline` / `sel.active` | (255, 154, 60) / (255, 224, 163) |
| slots Blade / Guard / Grip / Pommel | (143, 184, 222) / (224, 176, 80) / (168, 111, 72) / (180, 142, 219) |

Sizes (design px): display 48 / 64, heading 20 / 24, body 16, small 14, caption 13, mono 15; spacing 4 / 8 / 12 / 16 /
24 / 32; radii 6 / 10 / 16; motion 120 / 200 / 350 ms, enter Quad Out, exit Quad In. Tier and rarity colours come from
`Definitions` (S1).

---

## Evidence S7

Prototype paths are relative to `docs/spec/prototypes/S7/` (Lune 0.8.9: `lune run <file>`). Results files sit next
to the scripts.

### E-S7.1 Build list (`Definitions/World` data)

`Definitions/World.luau` starts from this data verbatim, as ordered arrays of camelCase rows. Shell parts are
plot-local; station parts are in the station frame (roots below); stand parts in the stand frame (repeated for the 6
stands). Cylinder sizes are Roblox-native (length along local X), so `rotZ(90)` stands a cylinder upright; rotations
are single-axis `CFrame.Angles`, in degrees. Source: `layout.luau` (data), `gen_table.luau` (this table).

**Plot plan** (plot-local, top view, front = −Z = plaza at the bottom):
```
 z=+20 ┌──────────────────────────────────────────────────┐ plot pad 40 x 40 (Cobblestone)
 z=+18 │ ████████████████ back wall (Brick) ███████████████│
       │ █ [chimney]                         [tool rack] █│ forge floor (Slate) z 4..17
       │ █ ┌──Furnace──┐ coal    (barrel)   ┌Grindstone┐ █│
 z≈+10 │ █ └───────────┘          Anvil      └─────────┘ █│
       │ █     S·F               S·A            S·G     █│ S· = stand points (smith's feet)
  z=+4 │ █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀ tie beam ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█│
       │ ▌[Draft]S·D                                      │ gallery floor (WoodPlanks) z −12..4
       │ ▌ table        (home = HomeSpawn)                │
  z=−4 │ ●                                               ● │ side posts
  z=−9 │  [D1]   [D2]   [D3]  · aisle ·  [D4]   [D5]   [D6] │ display stands, pitch 5 / 7 / 5
z=−12.5│ ●──────lantern──────●═══[ SIGN ]═══●───lantern───● │ front posts + beam (Wood)
       │ front yard: visitors read the stands from here   │
 z=−20 └──────────────────────────────────────────────────┘
       x=−20                                           x=+20                  → plaza
```

**Station frames** (root at floor level; station-local −Z is the front, where the smith stands facing +Z):

| Station | Root (plot-local) | Yaw | Parts | Stand point | Work point | Prompt |
|---|---|---:|---|---|---|---|
| `DraftingTable` | (−13.5, 0.5, 0) | −90° (front faces plot +X) | 9 | (0, 0, −2.0) | (0, 3.15, 0.2) parchment | (0, 3.5, −0.4) Draft |
| `Furnace` | (−9, 0.5, 9.5) | 0° | 6 | (0, 0, −3.0) | (0, 2.45, −0.35) crucible | — |
| `Anvil` | (0, 0.5, 8.0) | 0° | 7 | (0, 0, −2.5) | (0, 3.0, 0) face top | (0, 3.3, −0.2) Forge |
| `Grindstone` | (9, 0.5, 10.5) | 0° | 6 | (0, 0, −2.4) | (0, 2.6, −1.35) wheel rim | — |

**Stands:** plot-local x ∈ {−13.5, −8.5, −3.5, 3.5, 8.5, 13.5}, z = −9, floor y 0.5, yaw 0 (front faces the plaza);
pitch 5 studs (7 across the central aisle), caps 2.3 wide (2.7-stud gaps, 4.7-stud aisle); cradle stand-local
(0, 1.55, 0) → plot y 2.05; prompt stand-local (0, 1.6, −1.2). **Home pose:** plot-local (0, 0.5, −4), yaw 180°.
**Phase 2 reserved floor:** a quench trough beside the anvil barrel (3.4, 0.5, 9.4), an assembly bench mirroring
the drafting table at (13.5, 0.5, 0) yaw +90°, a second grindstone wheel for finishing.

**Build list** (one row per part; `HomeSpawn` is the SpawnLocation, `Transparency` 1, `CanQuery`/`CanTouch` false,
`Neutral`, `Duration` 0):

| Component | Part | Shape | Size | Position | Rotation | Collide | Material | Colour |
|---|---|---|---|---|---|---|---|---|
| Ground | Pad | Block | 40, 1, 40 | 0, -0.5, 0 | - | yes | Cobblestone | Cobble |
| Floor | ForgeFloor | Block | 32, 0.5, 13 | 0, 0.25, 10.5 | - | yes | Slate | Slate |
| Floor | GalleryFloor | Block | 32, 0.5, 16 | 0, 0.25, -4 | - | yes | WoodPlanks | Planks |
| Walls | BackWall | Block | 34, 12.5, 1 | 0, 6.25, 17.5 | - | yes | Brick | Brick |
| Walls | LeftWall | Block | 1, 12.5, 14 | -16.5, 6.25, 11 | - | yes | Brick | Brick |
| Walls | RightWall | Block | 1, 12.5, 14 | 16.5, 6.25, 11 | - | yes | Brick | Brick |
| Walls | Partition | Block | 1, 4.5, 7.5 | -16.5, 2.25, 0.25 | - | yes | Brick | Brick |
| Frame | FrontPost1 | Block | 1, 12.5, 1 | -16.5, 6.25, -12.5 | - | yes | Wood | Timber |
| Frame | FrontPost2 | Block | 1, 12.5, 1 | -5.5, 6.25, -12.5 | - | yes | Wood | Timber |
| Frame | FrontPost3 | Block | 1, 12.5, 1 | 5.5, 6.25, -12.5 | - | yes | Wood | Timber |
| Frame | FrontPost4 | Block | 1, 12.5, 1 | 16.5, 6.25, -12.5 | - | yes | Wood | Timber |
| Frame | SidePostL | Block | 1, 12.5, 1 | -16.5, 6.25, -4 | - | yes | Wood | Timber |
| Frame | SidePostR | Block | 1, 12.5, 1 | 16.5, 6.25, -4 | - | yes | Wood | Timber |
| Frame | FrontBeam | Block | 34, 1, 1 | 0, 13, -12.5 | - | yes | Wood | Timber |
| Frame | SideBeamL | Block | 1, 1, 31 | -16.5, 13, 2.5 | - | yes | Wood | Timber |
| Frame | SideBeamR | Block | 1, 1, 31 | 16.5, 13, 2.5 | - | yes | Wood | Timber |
| Frame | TieBeam | Block | 32, 0.8, 0.8 | 0, 12.9, 4 | - | yes | Wood | Timber |
| Roof | RoofFront | Block | 35, 0.5, 16.686 | 0, 16.238, -5.327 | rotX(-17.88) | yes | Slate | RoofTile |
| Roof | RoofBack | Block | 35, 0.5, 16.686 | 0, 16.238, 10.327 | rotX(17.88) | yes | Slate | RoofTile |
| Roof | Ridge | Block | 35.4, 0.7, 0.7 | 0, 18.85, 2.5 | rotX(45.00) | no | Wood | Timber |
| Roof | GableFrontL | Wedge | 1, 5, 15.5 | -16.5, 16, -5.25 | - | yes | Brick | Brick |
| Roof | GableBackL | Wedge | 1, 5, 15.5 | -16.5, 16, 10.25 | rotY(180.00) | yes | Brick | Brick |
| Roof | GableFrontR | Wedge | 1, 5, 15.5 | 16.5, 16, -5.25 | - | yes | Brick | Brick |
| Roof | GableBackR | Wedge | 1, 5, 15.5 | 16.5, 16, 10.25 | rotY(180.00) | yes | Brick | Brick |
| Chimney | Chimney | Block | 4, 11, 4 | -9, 15, 15 | - | yes | Brick | BrickDark |
| Chimney | ChimneyCap | Block | 4.6, 0.6, 4.6 | -9, 20.8, 15 | - | yes | Slate | Slate |
| Sign | SignBoard | Block | 10, 2, 0.3 | 0, 10.5, -12.5 | - | no | Wood | plot accent |
| Sign | SignChainL | Block | 0.12, 1, 0.12 | -4, 12, -12.5 | - | no | Metal | IronDark |
| Sign | SignChainR | Block | 0.12, 1, 0.12 | 4, 12, -12.5 | - | no | Metal | IronDark |
| Lanterns | LanternChain1 | Block | 0.1, 1.2, 0.1 | -11, 11.9, -12.5 | - | no | Metal | IronDark |
| Lanterns | LanternFrame1 | Block | 0.8, 1, 0.8 | -11, 10.8, -12.5 | - | no | Metal | IronDark |
| Lanterns | LanternFlame1 | Ball | 0.4, 0.4, 0.4 | -11, 10.8, -12.5 | - | no | Neon | Flame |
| Lanterns | LanternChain2 | Block | 0.1, 1.2, 0.1 | 11, 11.9, -12.5 | - | no | Metal | IronDark |
| Lanterns | LanternFrame2 | Block | 0.8, 1, 0.8 | 11, 10.8, -12.5 | - | no | Metal | IronDark |
| Lanterns | LanternFlame2 | Ball | 0.4, 0.4, 0.4 | 11, 10.8, -12.5 | - | no | Neon | Flame |
| Decor | ToolRack | Block | 4, 2.5, 0.2 | 12.5, 6, 16.9 | - | no | Wood | Timber |
| Decor | Hammer1Handle | Block | 0.15, 1.6, 0.15 | 11.3, 5.8, 16.72 | - | no | Wood | Timber |
| Decor | Hammer1Head | Block | 0.7, 0.35, 0.35 | 11.3, 6.7, 16.72 | - | no | Metal | IronDark |
| Decor | Hammer2Handle | Block | 0.15, 1.4, 0.15 | 12.4, 5.9, 16.72 | - | no | Wood | Timber |
| Decor | Hammer2Head | Block | 0.5, 0.3, 0.3 | 12.4, 6.7, 16.72 | - | no | Metal | IronDark |
| Decor | TongsA | Block | 0.1, 1.8, 0.1 | 13.6, 5.9, 16.72 | rotZ(8.00) | no | Metal | IronDark |
| Decor | TongsB | Block | 0.1, 1.8, 0.1 | 13.8, 5.9, 16.72 | rotZ(-8.00) | no | Metal | IronDark |
| Decor | Coal1 | Ball | 0.9, 0.9, 0.9 | -4.4, 0.95, 14.6 | - | no | Slate | Soot |
| Decor | Coal2 | Ball | 0.8, 0.8, 0.8 | -3.6, 0.9, 15.2 | - | no | Slate | Soot |
| Decor | Coal3 | Ball | 0.7, 0.7, 0.7 | -4.9, 0.85, 15.5 | - | no | Slate | Soot |
| Decor | Coal4 | Ball | 0.7, 0.7, 0.7 | -4, 1.5, 15 | - | no | Slate | Soot |
| Decor | Coal5 | Ball | 0.6, 0.6, 0.6 | -3.3, 0.8, 14.2 | - | no | Slate | Soot |
| Decor | CrateA | Block | 2.2, 2.2, 2.2 | 14.5, 1.6, 15.2 | - | yes | WoodPlanks | Planks |
| Decor | CrateB | Block | 2, 2, 2 | 14.6, 3.7, 15.1 | rotY(12.00) | yes | WoodPlanks | Planks |
| Spawn | HomeSpawn | Block | 4, 0.2, 4 | 0, 0.4, -4 | rotY(180.00) | no | SmoothPlastic | Slate |
| Furnace | Body | Block | 7, 6, 5 | 0, 3, 2.5 | - | yes | Brick | BrickDark |
| Furnace | Hood | Block | 5, 3.5, 4 | 0, 7.75, 3 | - | yes | Brick | BrickDark |
| Furnace | Mouth | Block | 3, 2.2, 0.3 | 0, 2.6, -0.05 | - | no | Slate | Soot |
| Furnace | CoalBed | Block | 2.6, 0.35, 0.8 | 0, 1.65, -0.2 | - | no | Neon | Ember |
| Furnace | Bellows | Wedge | 1.6, 0.9, 2.4 | 4.6, 0.45, 0.8 | - | yes | Wood | Timber |
| Furnace | Crucible | Cylinder | 0.8, 0.9, 0.9 | 0, 2.2, -0.35 | rotZ(90.00) | no | Metal | IronDark |
| Anvil | Stump | Cylinder | 1.5, 2.2, 2.2 | 0, 0.75, 0 | rotZ(90.00) | yes | Wood | Timber |
| Anvil | Base | Block | 1.6, 0.5, 1.1 | 0, 1.75, 0 | - | yes | Metal | IronDark |
| Anvil | Waist | Block | 0.9, 0.55, 0.7 | 0, 2.275, 0 | - | yes | Metal | IronDark |
| Anvil | Face | Block | 2.4, 0.45, 0.95 | 0, 2.775, 0 | - | yes | Metal | IronDark |
| Anvil | Horn | Wedge | 0.7, 0.45, 1.1 | 1.75, 2.775, 0 | rotY(-90.00) | yes | Metal | IronDark |
| Anvil | Barrel | Cylinder | 2, 1.6, 1.6 | 3.4, 1, 1.4 | rotZ(90.00) | yes | Wood | Timber |
| Anvil | Water | Cylinder | 0.1, 1.4, 1.4 | 3.4, 1.95, 1.4 | rotZ(90.00) | no | Glass | Water |
| Grindstone | LegL | Block | 0.35, 2.6, 1.4 | -0.6, 1.3, 0 | - | yes | Wood | Timber |
| Grindstone | LegR | Block | 0.35, 2.6, 1.4 | 0.6, 1.3, 0 | - | yes | Wood | Timber |
| Grindstone | Axle | Cylinder | 1.8, 0.22, 0.22 | 0, 2.6, 0 | - | no | Metal | IronDark |
| Grindstone | Wheel | Cylinder | 0.45, 2.6, 2.6 | 0, 2.6, 0 | - | yes | Slate | Stone |
| Grindstone | Trough | Block | 0.9, 0.5, 2 | 0, 0.85, 0 | - | yes | Wood | Timber |
| Grindstone | Crank | Block | 0.15, 0.15, 0.7 | 1, 2.6, -0.3 | - | no | Metal | IronDark |
| DraftingTable | Top | Block | 4, 0.25, 2.4 | 0, 3, 0.2 | rotX(-12.00) | yes | Wood | Planks |
| DraftingTable | Leg1 | Block | 0.25, 2.9, 0.25 | -1.75, 1.45, -0.8 | - | yes | Wood | Timber |
| DraftingTable | Leg2 | Block | 0.25, 2.9, 0.25 | 1.75, 1.45, -0.8 | - | yes | Wood | Timber |
| DraftingTable | Leg3 | Block | 0.25, 2.9, 0.25 | -1.75, 1.45, 1.2 | - | yes | Wood | Timber |
| DraftingTable | Leg4 | Block | 0.25, 2.9, 0.25 | 1.75, 1.45, 1.2 | - | yes | Wood | Timber |
| DraftingTable | Parchment | Block | 2.6, 0.02, 1.8 | 0, 3.14, 0.2 | rotX(-12.00) | no | SmoothPlastic | Parchment |
| DraftingTable | InkPot | Cylinder | 0.3, 0.3, 0.3 | 1.6, 3.38, 0.95 | rotZ(90.00) | no | Glass | Soot |
| DraftingTable | Candle | Cylinder | 0.5, 0.18, 0.18 | -1.6, 3.5, 0.95 | rotZ(90.00) | no | SmoothPlastic | Parchment |
| DraftingTable | CandleFlame | Ball | 0.16, 0.16, 0.16 | -1.6, 3.83, 0.95 | - | no | Neon | Flame |
| Stand (each) | Plinth | Block | 2, 1.2, 2 | 0, 0.6, 0 | - | yes | Slate | Stone |
| Stand (each) | Cap | Block | 2.3, 0.2, 2.3 | 0, 1.3, 0 | - | yes | Slate | Stone |
| Stand (each) | Band | Block | 2.04, 0.12, 2.04 | 0, 0.95, 0 | - | no | Neon | rarity colour |
| Stand (each) | Nameplate | Block | 1.6, 0.45, 0.08 | 0, 0.75, -1.06 | rotX(15.00) | no | Wood | Planks |

**Plaza** (world space; no SpawnLocation): ground disc Cylinder (1, 240, 240) at (0, −0.55, 0) `rotZ(90)` Grass;
plaza disc Cylinder (1, 128, 128) at (0, −0.5, 0) `rotZ(90)` PlazaStone; per lamp (8, radius 60): post Cylinder
(9, 0.5, 0.5) upright, arm Block (0.3, 0.3, 1.6), lantern Block (0.8, 1, 0.8), flame Ball 0.45 Neon + PointLight;
per tree (8, radius 92): trunk Cylinder (7, 1.2, 1.2) upright, crowns Ball 6 at +8 and Ball 4.5 at +10.5 (Foliage,
no collide); per boundary segment k (36, angle 10°·k, radius 116, tangent-aligned): wall Block (20.6, 3, 1.2)
PlazaStone and an invisible colliding barrier Block (20.6, 27, 1.2) above it.

**Instance tree:**
```
Workspace.BlacksmithWorld
+-- Plaza       Ground, PlazaDisc, Lamps/Lamp_1..8, Trees/Tree_1..8, Boundary/Wall_01..36, Barrier_01..36
+-- Plots/Plot_1..8 [BS_Plot]
    +-- Shell   HomeSpawn, SignBoard[SurfaceGui], LanternFlame1..2[PointLight], Chimney[Smoke], ...
    +-- Stations/<StationId>  CoalBed[Fire, PointLight, Embers], Face/PromptAttachment[ProximityPrompt],
    |                         Face|Wheel/WorkAttachment[Sparks], Workpiece (while forging)
    +-- Displays/Stand_1..6 [BS_Stand]  Plinth/PromptAttachment[ProximityPrompt], Cap/Cradle, Band,
                Nameplate[SurfaceGui]; occupied: Item, InspectHitbox[ClickDetector, RarityLight, RaritySparkles]
```

**Flags** (all parts `Anchored`, `Locked`, `CanTouch` false, smooth surfaces):

| Category | CanCollide | CanQuery | CastShadow |
|---|---|---|---|
| Structure: pad, floors, walls, posts, beams, roof, gables, chimney, crates, station bodies, plinths, caps, trunks | true | true | true |
| Decor: ridge, chains, lantern parts, sign board, tools, coal, mouth, coal bed, crucible, axle, crank, parchment, ink pot, candle, band, nameplate, water, crowns, `HomeSpawn` | false | false | false (sign: true) |
| Display item and workpiece parts | false | false | true |
| `InspectHitbox` (`Transparency` 1) | false | true | false |
| Boundary barrier (`Transparency` 1) | true | (engine: always) | false |

`WorldBuilder.build()` first calls `PhysicsService:RegisterCollisionGroup("BS_Characters")` and
`CollisionGroupSetCollidable("BS_Characters", "BS_Characters", false)` (registration cost grows with the part count,
so it runs before the world exists); on `CharacterAdded` the server sets the group on every `BasePart` descendant and
on later `DescendantAdded` parts (accessories).

**Sign** (`SignBoard` front face `SurfaceGui`): `PixelsPerStud` 50 (500 × 100 px); title `TextScaled`, max 52 px,
subtitle max 26 px; `Font.fromEnum(Enum.Font.Merriweather)` Bold (built-in; §12 may swap it for its font token);
text (245, 226, 190) with a black `UIStroke` at 0.5; vacant title (190, 180, 165); `LightInfluence` 0.4,
`Brightness` 1.2; `RichText` and `AutoLocalize` false. Nameplate: same style, item name line plus a rarity line in
the rarity colour; disabled on an empty stand.

**Prompts:** `KeyboardKeyCode` E, `HoldDuration` 0, `Exclusivity` OnePerButton, `ClickablePrompt` true,
`RequiresLineOfSight` false, `MaxActivationDistance` 7 (stations) or 8 (stands); positions in the station table and
the stand row above.

**Palette** (`Definitions/World.PALETTE`, RGB 0–255, built-in `Enum.Material`):

| Token | RGB | Material | Used for |
|---|---|---|---|
| `Cobble` | 118, 110, 102 | Cobblestone | plot pads |
| `PlazaStone` | 160, 150, 136 | Cobblestone | plaza disc, boundary wall |
| `Grass` / `Foliage` | 84, 104, 62 / 72, 96, 52 | Grass | ground disc / tree crowns |
| `Slate` | 92, 90, 88 | Slate | forge floor, chimney cap |
| `Planks` | 124, 88, 58 | WoodPlanks / Wood | gallery floor, crates, table top, nameplates |
| `Brick` / `BrickDark` | 134, 82, 60 / 96, 60, 48 | Brick | walls, gables / furnace, chimney |
| `Timber` | 86, 60, 40 | Wood | posts, beams, stump, legs, tools |
| `RoofTile` | 112, 52, 40 | Slate | roof slabs |
| `IronDark` | 58, 58, 62 | Metal | anvil, chains, lantern frames, tool heads |
| `Soot` | 26, 22, 20 | Slate | furnace mouth, coal |
| `Ember` | 255, 104, 32 | Neon | coal bed (lit plots) |
| `Stone` | 150, 144, 136 | Slate | plinths, grindstone wheel |
| `Parchment` | 232, 220, 190 | SmoothPlastic | parchment, candle |
| `Flame` | 255, 176, 92 | Neon | lantern and candle flames |
| `Water` | 64, 110, 140 | Glass | barrel water |

Plot accents (`PLOT_ACCENTS`, sign board colour), plots 1–8: (150, 52, 44) crimson, (52, 84, 150) azure,
(56, 112, 64) forest, (176, 128, 44) amber, (104, 64, 136) violet, (44, 120, 124) teal, (160, 92, 56) copper,
(96, 104, 112) slate.

**Lighting** (set by `WorldBuilder`, replicates): `LightingStyle` Realistic, `PrioritizeLightingQuality` true,
`ClockTime` 17 [Q20], `GeographicLatitude` 30, `Brightness` 2, `Ambient` (44, 36, 32), `OutdoorAmbient` (128, 112,
100), `ColorShift_Top` (255, 220, 180), `EnvironmentDiffuseScale` 0.5, `EnvironmentSpecularScale` 0.8,
`ShadowSoftness` 0.3, `GlobalShadows` true, `ExposureCompensation` 0; no `Sky` instance (built-in sky). Children
(`LIGHTING_FX` names): `BS_Atmosphere` Density 0.26, Offset 0.1, Color (199, 170, 146), Decay (110, 86, 70), Glare
0.2, Haze 1.2; `BS_Grade` ColorCorrection Brightness 0.02, Contrast 0.08, Saturation 0.05, Tint (255, 244, 232);
`BS_Bloom` Intensity 0.5, Size 24, Threshold 1.3; `BS_SunRays` Intensity 0.03, Spread 0.5.

**Forge glow** (lit plot): coal bed `Fire` Size 5, Heat 9, Color (255, 110, 40), Secondary (255, 190, 90) ·
`PointLight` (255, 140, 60), Brightness 3, Range 18, `Shadows` true · `Embers` emitter (default texture) Rate 8,
Lifetime 1.2–2.0 s, Speed 1.5–3, Size 0.10 → 0, LightEmission 1, Color (255, 160, 60) → (255, 60, 20),
Acceleration (0, 2, 0), SpreadAngle (25, 25). Chimney `Smoke` (70, 66, 62), Opacity 0.12, RiseVelocity 4, Size 4.
Lanterns `PointLight` (255, 176, 100), Brightness 1.3, Range 16 [`BS_Flicker`]; candle (255, 190, 120), 0.9, Range 8
[`BS_Flicker`]; plaza lamps (255, 190, 130), 1.2, Range 22. Sparks (anvil, grindstone): default texture, Speed 8–14,
Lifetime 0.25–0.5 s, Size 0.06, LightEmission 1, Color (255, 200, 120), SpreadAngle (60, 60), Acceleration
(0, −30, 0), Rate 0 unless active. Vacant plots: coal bed Slate (60, 36, 28), Fire, lights, embers and smoke off,
lantern flames SmoothPlastic (90, 80, 70). Flicker: `FLICKER_AMPLITUDE` 0.08, `FLICKER_FREQUENCY` 6, updated at
`FLICKER_HZ` 20 for lights within `FLICKER_RADIUS` 80 studs of the camera.

**Framings** (station-local; world = `stationCF * eye`, `CFrame.lookAt(eyeW, atW)`):

| Station | Eye | Look-at | FOV | Eye, plot-local | NDC head · work (16:9) | Eye clearance |
|---|---|---|---:|---|---|---:|
| `Furnace` | (5.5, 5.2, −9.0) | (0, 2.4, 0) | 50 | (−3.5, 5.7, 0.5) | (0.24, 0.40) · (0.02, −0.01) | 5.20 |
| `Anvil` | (4.2, 5.4, −6.2) | (0, 2.9, 0) | 45 | (4.2, 5.9, 1.8) | (0.35, 0.43) · (0.00, 0.03) | 5.40 |
| `Grindstone` | (5.8, 5.4, −3.6) | (0, 2.9, −1.3) | 50 | (14.8, 5.9, 6.9) | (0.22, 0.54) · (0.01, −0.09) | 1.20 |
| `DraftingTable` | (0, 8.6, −3.2) | (0, 3.1, 0.3) | 40 | (−10.3, 9.1, 0) | (0.00, −0.78) · (0.00, −0.02) | 4.95 |

Composition rule for the three forging stations: the work point at screen centre and the smith right of centre
(head NDC x 0.22–0.35, y 0.40–0.54), so the minigame UI can use the lower half and the left third. The drafting
table framing is a top-down transition shot before the editor takes the camera. The grindstone framing is a side
view on purpose (a 3/4-front try had the smith covering the wheel).

### E-S7.2 World checks (`checks_world.luau`, `results_world.txt`)

| Ring radius R | Adjacent-plot gap | Plot front from plaza centre | Back-corner radius |
|---:|---:|---:|---:|
| 76 | 5.91 | 56.0 | 98.06 |
| 84 | 12.03 | 64.0 | 105.91 |
| **86** | **13.56** | **66.0** | **107.87** |
| 92 | 18.15 | 72.0 | 113.77 |

R = 86 keeps walkable gaps between plots and a plaza walk of 66 studs (4.1 s at WalkSpeed 16); neighbouring plot
fronts are 50.5 studs apart (3.2 s). Boundary wall radius 116 (back corners + 8), ground disc 240. Plot 3: φ = 90°,
centre (86, 0, 0), LookVector (−1, 0, 0). Other checks, all passing on the data above:
- per-plot part budget 102 (CanCollide 57, decor 45); plot-local extents x [−20, 20], y [−1, 21.1], z [−20, 20];
- 0 unintended overlaps between colliding parts of different components (0.02 tolerance; the chimney through the
  roof and on the furnace hood is intended);
- a 2 × 5.2 × 1.4 character box at every stand point and at the home point touches no colliding part; `HomeSpawn`
  top y 0.500 = floor top;
- framings: no colliding or queryable part between eye and look-at, the smith never covers the work point, every
  eye ≥ 1.2 studs from any part (near plane ≤ 0.5);
- prompts: closest pair 5.0 studs (neighbouring stands); Anvil prompt 2.44 studs from its stand point, drafting
  prompt 1.89; a visitor outside the front posts (z = −14) is 3.91 studs from a stand prompt;
- stands: cradle plot y 2.05, a 6-stud item would top out at 8.05 (sign bottom 9.5, front beam 12.5); the 1.6-wide
  hitbox fits the 5-stud pitch (pitch ≥ width + 2.5);
- walks: furnace → anvil 9.1 studs (0.57 s), anvil → grindstone 9.4 studs (0.59 s), camera paths 7.8 and 11.8
  studs, all unobstructed.

### E-S7.3 Budgets

| Item | Worst case | Breakdown |
|---|---:|---|
| Static parts | 946 | 8 plots × 102 + plaza 130 (2 discs, 32 lamp parts, 24 tree parts, 72 boundary parts) |
| All parts | 2 338 | + 48 displayed items × `MAX_PARTS` 24 (1 152) + 48 hitboxes + 8 workpieces × 24 (192) |
| `PointLight` | 96 | 8 × (furnace, 2 lanterns, candle) + 8 plaza lamps + 48 rarity lights + 8 workpiece heat lights |
| Shadow-casting lights | 8 | furnaces only |
| `ParticleEmitter` | 72 | 8 embers + 16 sparks + 48 rarity sparkles; plus 8 `Fire`, 8 `Smoke` |
| Live particles | ≈ 700 | embers ≤ 40 per furnace, sparks ≈ 30 per active station, Epic ≈ 3.3 per item |
| Prompts / ClickDetectors / Highlights | 64 / 48 / 1 | 8 per plot; one per occupied stand; hover only in the MVP |

The draft's light count (88) left out the workpiece heat light (`setHeat`), one per forging plot.

### E-S7.4 Render checks (`render_plan_partdata.luau`, `render_plan.luau`, `render_plan_native.luau`)

- PartData + `Quat.toMatrix` path: arming-sword fixture bounds (−0.55, 0.15, −0.15) → (0.55, 4.30, 0.15), max
  error 0; `toMatrix(k·q) = toMatrix(q)` (max diff 1.1e-16); orthonormal columns and det +1 over 20 000 random q
  (1.1e-15, 1.2e-15); size below MIN_DIM → `BadSize`; 25 parts → `TooManyParts`; no parts → `Empty`; 0 failures.
- Rotated-cylinder closed-form bounds vs 7 202-point sampling: max difference 1.1e-9 studs.
- Arming sword on a stand: plot y 2.05 → 6.20; Blade-slot bounds (−0.10, 1.40, −0.03) → (0.10, 4.30, 0.03);
  `InspectHitbox` 1.70 × 4.75 × 0.90; a full-hitbox item (1.6 × 5 × 0.6) tops out at plot y 7.05 with a 2.2 × 5.6 ×
  1.2 hitbox.
- Orientations: `FLAT` and `VIEW_H` det +1; blueprint +Z faces the plaza on a stand (dot 1.000).
- On the anvil, the Center pivot sits at y 3.0 + 0.15 and the sword overhangs the 2.4-stud face by 1.75 studs.
- Viewport fit at FOV 30, margin 1.08: 4.85 studs (16:9 results card), 6.42 (4:3 inspect), 8.51 (1:1 tile);
  projected corners reach |NDC| 0.926 = 1/1.08.
- Sizes render as stored: `MIN_DIM·k ≥ 0.001` (Roblox's smallest part size) for every scale k ≥ 0.05.

### E-S7.5 Test cases (for §14)

Lune:
- **T-WLD** `Layout`: poses for i = 1..8 (centre and LookVector as in E-S7.2); `toWorld ∘ toPlotLocal` = identity
  (1e-9); `isInsidePlot` on the square's edges at margins 0 and 6; `plotAt` at every plot centre, every gap centre
  (nil) and the plaza centre (nil); stand points, framings and cradles equal the data. World data: re-run the
  E-S7.2 checks on `Definitions/World` (overlaps, clear stand points, camera lines and walks, eye clearance ≥ 1.0).
- **T-RND** `RenderPlan`: golden bounds of every fixture; rotated cylinder vs sampling (≤ 1e-6); Wedge and
  CornerWedge vertex sets inside §4's solids with tight bounds; BaseCenter puts min Y at 0; scale k multiplies sizes
  and positions; `toMatrix(k·q)`; every `PlanError`; determinism.
- **T-SHW** `ShowcaseRules`: place, move (changed {i, j}), `NoChange`, swap, clear, `BadSlot` for 0 / 7 / 1.5 /
  "1", `SlotLocked`, `NotOwned` (also for a 65-character unknown id), `BadItem` (number, empty string), `sanitize`
  (duplicates, unknown keys, non-strings, locked slots, unowned ids), `fromStore`/`toStore` round trip.
- **T-INS** `InspectView`: mapping from a golden item; `defaultName` ("Steel Sword", "Iron-Steel Sword"); JSON round
  trip; ≤ 1 KB at 24 parts; no `flags`, `seed` or `parts` key at any depth.

Studio (MCP, play mode):
1. Shape agreement: per `ShapeId`, a 4 × 4 × 4 part at several rotations; raycasts on a grid match §4's solids.
2. Boot builds 946 static parts, and the built instances (sizes and CFrames read back) pass the E-S7.2 checks.
3. Two clients: plots 1 and 2 claimed, signs show the display names, forges lit, vacant plots cold; client 2 sees no
   Draft/Forge prompt and no "Display an item" on plot 1.
4. Place 6 items, move one, swap one, take one down, rejoin: stands restore; a visitor's panel shows the forging
   record and closes on take-down.
5. Forge session: `Camera.CFrame` within 0.05 of each framing, character within 0.75 of each stand point, the
   workpiece appears and glows, client 2 sees sparks and the spinning wheel.
6. Names: the nameplate shows the filtered text; a forced filter error shows `defaultName`.
7. S-VIS-06/07 (Rare lights its plinth, Epic sparkles); S-E2E-02 (spawn within 10 studs of the home pose).

Prototype `showcase_rules.luau` (revised: no id-length constant, no serial): 17 checks, 0 failures
(`results_showcase.txt`).

### E-S7.6 Presentation data (`Definitions/Presentation`)

**Station stage.** `enter`: prompts suppressed; §12 disables controls (`PlayerModule:GetControls():Disable()`);
camera `Scriptable`, `TweenService` on `CFrame` and `FieldOfView`: `CAM_ENTER_S` 0.8 from the free camera,
`CAM_MOVE_S` 0.9 between stations (Sine InOut); meanwhile `Humanoid:MoveTo(stand point)` (≈ 0.6 s walk). On
`MoveToFinished` or after `WALK_TIMEOUT_S` 1.4: if the root is more than `ARRIVE_TOLERANCE` 0.75 from the stand
point, `PivotTo(stand pose + root height)`; then `PivotTo(CFrame.lookAt(root, (stationX, rootY, stationZ)))`;
`onArrived()` once the tween has finished and the smith is placed. `Camera.Focus = CFrame.new(atW)` every
Scriptable frame. `leave`: `CAM_EXIT_S` 0.6, Sine Out, to `root.CFrame * CFrame.new(0, 2.5, 9)` looking at
`root.Position + (0, 1.5, 0)`, then `Custom`. Reduced motion (Roblox setting or §12 override): cuts, same end states.

**Station activity** (`StationActivity` set):

| Station | Server (replicates) | Every viewer's `StationFx` |
|---|---|---|
| Furnace | `Fire` Size 5 → 8, Heat 9 → 14; light 3 → 4.5; embers Rate 8 → 24 | flicker continues |
| Anvil | — | `Sparks:Emit(ANVIL_SPARK_COUNT)` (12) every `ANVIL_SPARK_INTERVAL` 0.7 s; the owner per real strike (`StationFx.strike()`) |
| Grindstone | sparks Rate `GRINDSTONE_SPARK_RATE` 30 | wheel spins `GRINDSTONE_SPIN` 270°/s (local CFrame; the server never moves it) |
| DraftingTable | candle light 0.9 → 1.2 | — |

**Workpiece** (station-local pivots, scale 1):

| Step (station) | Model | Orientation | Pivot | Heat h |
|---|---|---|---|---:|
| Smelting (Furnace) | one ingot (Block `INGOT_SIZE` 0.5 × 0.25 × 1.0, material colour) per distinct work-set material | yaw 0 | (0, 2.45, −0.35), ingots at x ± 0.3 | 0.9 |
| Hammering (Anvil) | full item | `FLAT`, Center | (0, 3.0 + e_z, 0) | 0.7 |
| Sharpening (Grindstone) | full item | `FLAT`, Center | (0, 2.6, −1.3 − (bladeMax.x − centre.x) − 0.05) | 0 |

`bladeMax.x` = `plan.slotBounds.Blade.max.x`, `centre` = the plan bounds centre. Heat: `HEAT_COLOR` (255, 96, 32),
`HEAT_BLEND` 0.85, `HEAT_NEON_THRESHOLD` 0.55, light colour `HEAT_COLOR`, `HEAT_LIGHT_RANGE` 8, `HEAT_LIGHT_BRIGHTNESS` 2.5 × h.

**Rarity FX** (`RARITY_FX`):

| Rarity | Band | `RarityLight` | `RaritySparkles` | Highlight | MVP |
|---|---|---|---|---|---|
| Common | Slate, no glow | — | — | — | yes |
| Uncommon | Neon | — | — | — | yes |
| Rare | Neon | Range 6, Brightness 0.8 | — | — | yes |
| Epic | Neon | 7, 1.1 | Rate 3, life 0.8–1.4 s | — | yes |
| Legendary | Neon | 8, 1.3 | 5, 0.9–1.5 s | outline transparency 0.4 | data only |
| Mythic | Neon | 9, 1.5 | 7, 1.0–1.6 s | 0.3 | data only |
| Divine | Neon | 10, 1.8 | 9, 1.0–1.8 s | 0.2, fill 0.85 | data only |

Sparkles: default texture, `Shape` Box, `ShapeStyle` Volume (they spawn inside `InspectHitbox`, around the blade),
Size 0.12 → 0, Speed 0.1–0.3, Drag 2, LightEmission 1, LightInfluence 0, rarity colour, Transparency 0.2 → 1.
Highlight `DepthMode` Occluded. Rarity colours are S1's `Rarities` rows (S7's proposed values were merged there):
Common (170, 170, 170), Uncommon (96, 196, 96), Rare (72, 140, 232), Epic (168, 92, 224), Legendary (240, 164, 48),
Mythic (232, 64, 64), Divine (255, 236, 180).

**Viewports:** `Ambient` (110, 100, 92), `LightColor` (255, 240, 220), `LightDirection` (−1, −1, −0.6); the default
`Sky` uses built-in textures (asset-free). Inspect turntable `INSPECT_TURNTABLE_SPEED` 24°/s, camera orbit about
the blade axis.

**Inspect panel:** one panel on the right side; movement stays on; close button; a new `ItemId` on the stand closes
it with the toast "This item was taken down". Rows: preview; name and rarity badge; "Forged by <DisplayName>
(@<Name>) · <date>" with `FormatLocalTime("LL", RobloxLocaleId)`; materials per slot; Mass (kg), Balance point,
Reach; stats; Forging record, one row per step "<Step> · <Tier> · <score> % · PASS | FAIL | NO INPUT", then
"Quality N · Rarity cap X (Hard <step>)"; owner buttons Swap… (item picker for that stand) and Take down
(`Showcase.Clear`).

### E-S7.7 Platform facts relied on

- A `PointLight` lights and a `ParticleEmitter` emits only as a direct child of a `BasePart` or `Attachment`; under
  a Folder they do nothing (R5a-06), hence the build rule.
- `Model.ModelStreamingMode` is a server-side setting (client writes are not supported, R5a-13) and does nothing
  with `StreamingEnabled` false; the builder never writes it.
- `Part.Shape` covers Ball, Block, Cylinder, Wedge and CornerWedge, so every `ShapeId` is a plain `Part` and a shape
  change happens in place (`render_plan_native.luau`).
- Roblox's smallest part size is 0.001 studs; `CanQuery` only takes effect when `CanCollide` is false.
- A `ViewportFrame` renders no lights, particles or post effects (only its own Ambient, LightColor and
  LightDirection), so rarity in viewports is a UI colour.
- `Camera.Focus` drives streaming and lighting detail around the camera and is not updated for a Scriptable camera
  (R5a-02), hence the per-frame write.
- `Player.RespawnLocation` picks the player's SpawnLocation; a `Neutral` spawn accepts any team; `Duration` 0 gives no
  ForceField. An R15 root sits `HipHeight + RootPart.Size.Y/2` above the floor.

### E-S7.8 Changes from the draft (for §0)

- Spawn: plaza SpawnLocation and PivotTo-on-spawn replaced by one `HomeSpawn` per plot and `RespawnLocation`; the
  NoPlot visitor mode is gone (no free plot = kick).
- Streaming off: `RequestStreamAroundAsync`, `ModelStreamingMode` writes and the `atomic` build option are gone;
  `Atomic` models are a Phase 2 hook.
- Rendering takes S1's `PartData` and `Blueprint/Quat.toMatrix` (no `PartView`, no `Geometry.partMatrix`), S1's render
  values (`robloxMaterial`), and rejects sizes outside [MIN_DIM, MAX_DIM]; `MAX_RENDER_PARTS_HARD` 64 is replaced by
  `Limits.MAX_PARTS` 24.
- Display flow: no 5-s filter wait (`NAME_FILTER_TIMEOUT` removed); the stand renders at once with the fallback
  name and a late label is guarded by `(ItemId, Rev)`. `MAX_ITEM_ID_BYTES` removed (the Guard checks the GUID).
- Names: no per-owner serial ("Steel Sword No. 7" → "Steel Sword"); no item rename.
- Rarity FX are direct children of `InspectHitbox` (no Fx folder); light budget 88 → 96.
- `World.TeleportHome` and `HOME_TELEPORT_COOLDOWN` → S5's `Showcase.TeleportHome` and its rate bucket.
- `SoundHooks` with empty ids → S6's `Definitions/Audio` cues `FurnaceLoop`, `GrindLoop`.
- `InspectView`: camelCase, no flags, `physics.balance`, `history {step, tier, score, passed, timedOut}`.
- Design-draft deviations (R2-14): floor stands only (racks and mannequins later); the blueprint is shown as the 3D
  item; same-server visits only; no likes, categories or levels (hooks kept) — justified. The minimal Forging record
  and the single Forge prompt with automatic movement are defaults to confirm (Q20).

---

## Evidence S8

Prototype paths are relative to `docs/spec/prototypes/S8/`.

### E-S8.1 Lune 0.8.9 facts, runner prototype, require resolver

Runner prototype `repo/tests/run.luau`: 6 spec files, 26 cases, 0.51 s full / 0.38 s `--quick` (measured). Exit codes
verified in Git Bash and Windows PowerShell 5.1 (`$LASTEXITCODE`); `repo/tests_demo/{fail, broken, identity}` are the
runner self-test roots (T-META-05). Facts the suite relies on, each verified by a probe in `probe/`:

| Fact | Consequence |
|---|---|
| Flags after the script path are Lune's own; `lune run tests/run --quick` exits 2 from Lune | script arguments follow `--` |
| `bit32` maps NaN/±inf to 0 and truncates fractions silently; reduces inputs mod 2^32 below 2^53 | seeds and hashes validated explicitly (T-RNG-03); `fnv1a32` splits products exactly |
| `string.gmatch(s, "[^\n]*")` yields extra empty matches | line scans use `string.split` |
| `%a` unsupported; `%.17g` round-trips doubles | `Dump.canonical` uses `%.17g` |
| `@lune/serde` JSON encodes 1e-300 as 0 | goldens never use serde JSON |
| uncaught error → exit 1; `process.exit(n)` → n | runner maps harness faults to 2 |
| aftman shims resolve versions from the nearest `aftman.toml` | always run from the repo root |
| modules are cached per resolved file | one `Prop`/`Golden` instance carries `--seed`, `--bless` |

T-META-07 reference: `v2/checkreq.luau` (from the R7 review) resolves every string require of a sourcemap the way
Roblox does (`./` = `script.Parent`, each `../` one more parent, `@game/`, `@self/`). Run on `repo/` with
`test.sourcemap.json`: `RESULT ok=6 fail=0`. T-META-07 adds the on-disk Lune resolution, the same-module check, the
cross-root and `tests/lib` → `src/` bans and cycle detection.

### E-S8.2 `test.project.json`

Self-contained per R5b-12 (structure verified by R5b in `docs/spec/review/R5b/rojo-alt/`: Remotes from `Remotes.model.json`,
ProfileStore through the nested project `src/server/Vendor/ProfileStore.project.json` → `../../../vendor/...`).
Copy every other `$properties` entry S5's `default.project.json` sets (R5b-18); T-META-08 enforces the superset.

```json
{ "name": "BlacksmithTest",
  "tree": { "$className": "DataModel",
    "ReplicatedStorage": { "$className": "ReplicatedStorage",
      "Blacksmith": { "$path": "src/shared" },
      "BlacksmithTests": { "$className": "Folder",
        "lib": { "$path": "tests/lib" }, "fixtures": { "$path": "tests/fixtures" }, "golden": { "$path": "tests/golden" } } },
    "ServerScriptService": { "$className": "ServerScriptService",
      "BlacksmithServer": { "$path": "src/server" },
      "BlacksmithTestServer": { "$path": "tests/studio/bridge/server" } },
    "StarterPlayer": { "$className": "StarterPlayer", "$properties": { "EnableMouseLockOption": false },
      "StarterPlayerScripts": { "$className": "StarterPlayerScripts",
        "BlacksmithClient": { "$path": "src/client" },
        "BlacksmithTestClient": { "$path": "tests/studio/bridge/client" } } },
    "Workspace": { "$className": "Workspace", "$properties": { "StreamingEnabled": false } } } }
```

### E-S8.3 Fixtures F1–F5 and the independent oracle

Blueprint space, hitbox x ∈ [−0.8, 0.8], y ∈ [0, 5], z ∈ [−0.3, 0.3]. `R = 0.70710678118654757`; `I = {0,0,0,1}`,
`Z45 = {0, 0, 0.38268343236508978, 0.92387953251128674}`, `Z90 = {0, 0, R, R}`, `Y90 = {0, R, 0, R}`. The draft's
fixture frame is gone: F1, F3, F4 moved +1.20 in y and F2 +1.35 (R4a-16's per-fixture option, which keeps F2's
flush contacts instead of raising its pommel into the grip).

```
id slot   shape    material pos               rot  size
F1 ArmingSword (two-part blade, 45° tip overlapping the blade)
1  Pommel Ball     Iron     (0, 0.17, 0)      I    0.26 0.26 0.26
2  Grip   Block    Iron     (0, 0.75, 0)      I    0.16 0.90 0.16
3  Guard  Block    Iron     (0, 1.29, 0)      I    1.00 0.18 0.24
4  Blade  Block    Steel    (0, 2.68, 0)      I    0.16 2.60 0.06
5  Blade  Block    Steel    (0, 3.98, 0)      Z45  0.113 0.113 0.055
F2 MinimalSword
1  Pommel Block    Iron     (0, 0.20, 0)      I    0.30 0.30 0.30
2  Grip   Block    Iron     (0, 0.85, 0)      I    0.20 1.00 0.20
3  Guard  Block    Iron     (0, 1.45, 0)      I    0.80 0.20 0.20
4  Blade  Block    Iron     (0, 2.75, 0)      I    0.20 2.40 0.08
F3 Rapier (X-axis cylinder grip, ball quillons overlapping the guard, single-edged wedge tip)
1  Pommel Ball     Steel    (0, 0.16, 0)      I    0.28 0.28 0.28
2  Grip   Cylinder Steel    (0, 0.75, 0)      Z90  0.90 0.13 0.13
3  Guard  Block    Steel    (0, 1.24, 0)      I    0.90 0.08 0.08
4  Guard  Ball     Steel    (-0.45, 1.24, 0)  I    0.12 0.12 0.12
5  Guard  Ball     Steel    (0.45, 1.24, 0)   I    0.12 0.12 0.12
6  Blade  Block    Steel    (0, 2.98, 0)      I    0.07 3.40 0.035
7  Blade  Wedge    Steel    (0, 4.83, 0)      Y90  0.035 0.30 0.07
F4 Cleaver
1  Pommel Block    Iron     (0, 0.20, 0)      I    0.30 0.20 0.30
2  Grip   Block    Iron     (0, 0.75, 0)      I    0.22 0.90 0.22
3  Guard  Block    Iron     (0, 1.275, 0)     I    0.50 0.15 0.30
4  Blade  Block    Iron     (0.175, 2.45, 0)  I    0.85 2.20 0.16
5  Blade  Wedge    Iron     (0.175, 3.75, 0)  Y90  0.16 0.40 0.85
F5 StarterSword = F1 with parts 4 and 5 in Iron
```

Analytic oracle, `studies/fixtures_bp.luau` → `fixtures_bp.out.txt` (independent of S2's code; densities Iron 7.87,
Steel 7.85; union = overlaps counted once, sampled at 0.002 stud; COM and balance as COM_y − grip_y):

| | min side | margin | V_union | mass (kg) | COM_y | grip y | reach | balance |
|---|---|---|---|---|---|---|---|---|
| F1 | 0.055 | 0.040 | 0.10076 | 0.7925 | 1.4174 | 0.75 | 3.3100 | 0.6674 |
| F2 | 0.080 | 0.050 | 0.13740 | 1.0813 | 1.3930 | 0.85 | 3.1019 | 0.5430 |
| F3 | 0.035 | 0.020 | 0.03907 | 0.3067 | 1.1767 | 0.75 | 4.2302 | 0.4267 |
| F4 | 0.150 | 0.100 | 0.41046 | 3.2303 | 2.1882 (COM_x 0.1485) | 0.75 | 3.2567 | 1.4382 |
| F5 | 0.055 | 0.040 | 0.10076 | 0.7930 | 1.4182 | 0.75 | 3.3100 | 0.6682 |

Reach = Euclidean distance from the grip point to the farthest exact Blade vertex. S2's E-S2.9 physics table must
agree within TOL_MASS_REL, TOL_BALANCE_ABS, TOL_REACH_ABS (T-PHY-03); if S2 defines balance or reach differently,
T-PHY-03 maps S2's definition onto these primitives.

### E-S8.4 Adversarial and regression fixtures

| Id | Construction | Expected (S1 CanonError / S2 ValidationCode / wire code) |
|---|---|---|
| A01, A02 | F2 blade top 0.01 out; F2 guard turned 30° about Z, a corner out | stored `valid = false`, `OutOfHitbox` |
| A03 | Cylinder at 45° near a wall: box corners out, solid in | valid (exact extents) |
| A04, A05 | face flush; 0.5·EPS_CONTAIN out; 2·EPS_CONTAIN out | valid; valid; `OutOfHitbox` |
| A06, A07 | F2 + guard part 0.1 away; gaps 0.5·CONTACT_TOL and 2·CONTACT_TOL | `Disconnected`; connected; `Disconnected` |
| A08, A09 | F2 without Grip; without Blade / Guard / Pommel | S2's full list; `SlotMissing` (no Blade); `Disconnected` (no Guard: the blade floats); valid (no Pommel) |
| A10 | NaN, ±inf in each component | `E_INVALID_BLUEPRINT` (`Malformed`), never a throw |
| A11 | size 0, −0.2, MIN_DIM − 1e-6, MAX_DIM + 1e-6; \|pos\| = POS_ABS_MAX + 1e-6 | refused `OutOfRange` (never clamped) |
| A12 | q {0,0,0,0}, {1e-20,0,0,0}; {0,0,0,2}; ‖q‖² = 1 + 1e-3 | refused; renormalized per S1's rule; never NaN |
| A13 | F1 with every q negated | bit-identical to F1 |
| A14 | F1 + 19 attached 0.05 cubes (dust) within slot maxima | valid; D non-increasing, \|ΔG\| ≤ TOL_DUST_G |
| A15, A18 | F1 + 2,000 parts; 10,000 parts, 1 MB strings, 100-deep nesting | `TooManyParts` / Guard `E_BAD_REQUEST` before per-part work |
| A16, A17 | F1 + parts inside blade and guard; F2 + 3 exact blade copies | Enclosed; D bit-identical |
| A19 | draft as string, number, array; parts as a map; wrong types; unknown fields | `Malformed`, never a throw |
| A20 | shape "Sphere", slot "Hilt", a disabled material | `UnknownId`, `SlotNotInType`, `DisabledId` |
| A21 | 13 Blade parts | `SlotTooMany` |
| A22 | only Blade part dust; only Blade part enclosed in the guard; only Grip part enclosed | `SlotMissing` (Cleaned) each |
| A23, A24 | a side exactly MIN_DIM; blade 0.02 × 3.0 × 0.02 | valid, finite; Thinness = 1, never above; A24 plays Hammering Hard (0.40) |
| A25–A27 | F1 + enclosed 20° grip core / ring grip + 40° strap / hilt shifted 0.04 in X (R3-01) | ΔD ≤ 0.01 / ≤ 0.02 / Sharpening ΔD ≤ 0.02 |
| X01, X02 | F5 + 2 blade copies at ±0.003; 6 copies at k·0.002 (R3-02) | \|ΔD\| ≤ 0.01 against the union-equivalent single blade (0.066 / 0.072 thick); against F5 the change is the real thickening (E-S2.5) |
| X03 | F4 + a 0.0003 stud³ fin (R3-03) | ΔThinness ≤ 0.02 |
| X04 | blade from 4 strips; 5 and 10 segments with 0.004–0.009 gaps; grip nudge 0–0.02 (R4a-02) | \|ΔEdgeLength\| ≤ 2 % |
| X05 | segment gaps 0.002–0.009, overlaps 0.005–0.05 (R4a-03) | \|ΔG\| ≤ 0.01 |
| X06 | blade offset sweep 0–0.05 in X (R4a-04) | \|Asymmetry − continuous oracle\| ≤ 0.02 |
| X07 | laminated plates, overlapping segments (R4a-07) | \|ΔG\| ≤ 0.01, mass error ≤ 0.5 % |
| X08 | 24 rotated cylinders; 24 hitbox-sized blocks; sawtooth blade; 256-point zigzag edge (R3-07, R3-08) | §14.11 |

### E-S8.5 Case catalogue

- **T-DEF** 00 `validateAll() == {}`, one planted error per check · 01 ids PascalCase, unique, append-only (golden id
  lists) · 02 MVP enabled set; all 5 tiers and 7 rarities present · 03 ordered arrays, references resolve, weights
  Σ = 1 ± 1e-9 · 04 hardness, toughness integers 0–100; `difficultyTerm` 0 · 05 thresholds increasing, caps
  non-decreasing · 06 finite, frozen, `JsonSafe`; `Limits` consistent, fixtures inside · 07 `MAX_TIMELINE_BYTES` =
  header + largest cap; Audio cues well formed.
- **T-BP** 01 total, code + path · 02 idempotent · 03 output: known fields, finite, ‖q‖² within 1e-9, hemisphere,
  sizes in [MIN_DIM, MAX_DIM], \|pos\| ≤ POS_ABS_MAX, Ball/Cylinder rules, sorted ids, no shared tables · 04 bounds
  rejected (A11), GUID ids · 05 24-part draft ≤ S1's wire size · 11 Mirror: 10,000 points per shape and plane,
  `inside(mirror(p), x) == inside(p, reflect(x))`, CornerWedge X/Z swap · 12 Quat orthonormal 1e-12, q ≡ −q,
  `fromMatrix` round trip · 13 Names accept/reject list, `Views.snapshot` deep copy · 14 WorkSet kept parts,
  Sharpening Blade only.
- **T-VAL** 01 A fixtures' exact lists, fixed order · 02 containment vs exact brute force, 1,000 boundary parts · 03
  `Gjk` vs brute force, 300 pairs · 04 F1–F5, calibration swords, 500 `Gen.validSword` valid.
- **T-PHY** 01 Monte Carlo volume and centroid, 10⁵ points (0.5 %, 0.005·max size) · 02 fixtures = E-S2.9 · 03 E-S2.9
  = oracle (E-S8.3) · 04 Y/Z translation: mass within TOL_ANALYTIC_REL, COM moves by δ · 05 any rotation keeps mass;
  about the grip axis keeps reach and balance · 06 q ↔ −q bit-identical · 07 density scaling; pommel mass moves
  balance toward the hand · 08 grip point from Grip parts; difficulty frame from kept parts · 09 cleaning: Dust and
  Enclosed only, duplicates Enclosed (lowest id kept), partial overlaps kept · 10 overlap mass error ≤ 0.5 % (X07).
- **T-DIF** 01 P-RANGE, caps · 02 soft-OR identities, 101 × 101 grid · 03 boundary, NaN errors, `tierRaw` unclamped ·
  04 enclosed and duplicates bit-identical, dust · 05 Iron ↔ Steel · 06 monotone Thinness, PartCount, EdgeLength ·
  07 invariances · 08 mirrored Asymmetry · 09 step scoping · 10–13 as §14.6.
- **T-RNG** 01 vectors from `kat/` (`studies/kat_xorshift32.py`) · 02 determinism · 03 seed validation · 04 χ² over
  16 buckets < CHI2_CRIT · 05 1,000 derived tags collision-free · 06 independence.
- **T-MG** 01 `prepare`/`judge` deterministic, StepSpec complete · 02 `passed` ⇔ Ok ∧ score ≥ pass line · 03
  solvability · 04 bands, fail rates (L3) · 05 profile order, Normal → Hard drop · 06 Iron − Steel · 07 `Params` =
  product of modifiers, S3's clamp and quantum · 08 2,000 garbage buffers · 09 live session = `judge` on 1,000 random
  frame partitions · 10 FP and TP runs (L3) · 11, 13, 14 as §14.6 · 12 fairness · 15 `timingOffsetMs` keeps flag
  decisions, press times floored at 0 · 16 releases always recorded (focus loss, menu open).
- **T-CR** 01 plan from CraftPlans, work sets non-empty · 02 S4's worked examples · 03 Q monotone, fail factor · 04 d
  grows with D in a tier · 05 exhaustive cap test, 2³ tiers × 11³ scores × 2 materials · 06 failed ≤ passed, timeout
  = 0, stat ranges, Reach = physics reach, ignored parts change nothing, Steel T = 1.02 · 07 outcome block, recompute
  · 08 goldens F1–F5 × 4 profiles × 5 seeds · 09 rarity targets, 2,000 crafts per row (L3) · 10 a 3-step record
  under a synthetic 6-step plan keeps its Q (R2-06).
- **T-ITM** 01 `fromCraft` fields, quantized, `JsonSafe` · 02 recompute, rarity floor · 03 I1–I13 on template, maximal
  and 200 fuzzed profiles. **T-PER** 01 `JsonSafe` classes · 02 worst case (40 / 150, 24 parts, GUIDs, raw doubles): W ≤ 50 % of `DATASTORE_VALUE_LIMIT`, Phase 2+ shape reported ·
  03 every `v<N>` fixture, idempotent · 04 Ok / Newer / Corrupt, quarantine, migrate before reconcile · 05
  `Settings.sanitize` (offset −120…+120, volume, snap steps) and `Settings.DEFAULT` (Rotate off, Move/Scale 0.05,
  timingOffsetMs 0, grindToggle false) · 06 starter grant once.
- **T-ED** 01 Snap (any step, off, Shift, typed-decimal cleanup) · 02 Expr · 03 Rotation round trip 1e-9, continuity ·
  04 History merge, budget, dirty flag · 05 Commands · 06 EditorState part ids · 07 GizmoMath · 08 EditorLayout ·
  09 Keymap with injected AZERTY/QWERTZ label tables (M → Semicolon, Z → W, A → Q) and `Config` values = §16.
- **T-NET** 01 Guard fuzzer, node budget, `buffer(maxBytes)` · 02 S5's rate-limit traces · 03 payload shapes,
  StepOpenView = StepSpec + session fields, module codes → one ErrorCode · 04 dispatch order (S5's pure decision
  helper, R7-15), 10th Hard strike kicks. **T-SES** 01–37 S5's scenarios · 38 the step-outcome table.
- **Prop** runs PROP_N cases per property from PROP_BASE_SEED; `Gen.validSword` properties use FUZZ_N_VALID designs.
- **Cheats**: Exact (Perfect timeline, unquantized) · Fast (honest timeline sent before `D − EARLY_TOL_MS`) · Flood
  (records past the family cap) · Malformed (one per decode reason) · Replay (same step twice; an old timeline on a new
  seed) · Forged (extra keys, other session id). **Gen**: `validSword`, `garbage`, `withFiller`, `segmented`, `translated`.

### E-S8.6 Studio bridge, scenario assertions, shots, manual steps

| Cmd | Data |
|---|---|
| S `ping` | {balanceVersion, players} |
| S `waitReady {userId, timeoutS}` | {loaded, plotIndex} |
| S `profileSnapshot {userId}` | `DataService.read` as JSON |
| S `simulateRejoin {userId}` | `Lifecycle.simulateRejoinForTest` result (no OnSessionEnd wait, R5b-11) |
| S `displays {userId}`, `telemetry {sinceSeq}`, `fillPlots {count}` | stands; {events, lastSeq}; plots filled |
| C `call {channel, action, args}` | `NetClient.request` Response |
| C `rawFire {channel, action, rid, args}` | fires the RemoteEvent past the client throttle, collects replies by rid |
| C `awaitPush {channel, kind, timeoutS}`, `uiState`, `loadBlueprint`, `openStation` | push; {screen, editor, minigame}; UI actions |
| C `autoplay {profile}`, `cameraShot {name}` | S3's bot via `MinigameHost.setInputSource`; S7 framing |

- S-E2E-01 `ping` ≤ 20 s, S7's world counts, clean console · 02 profile ≤ 5 s, plot assigned in PlayerAdded, character
  ≤ 10 studs from the home pose, F5 granted once, prompts reachable by `character_navigation`, `Showcase.TeleportHome`
  returns home, 1 per 3 s, refused during a craft · 03 F1–F5 summaries equal · 04 A10–A12, A19, A20 →
  `E_INVALID_BLUEPRINT`, count unchanged; A18 → `E_BAD_REQUEST`; A01, A02, A06, A08, A22 stored `valid = false`,
  count + 1 · 05 `Craft.Begin`; per step `Craft.StartStep` → `Minigames.start(spec)` → Good bot → `Craft.Submit
  {sessionId, stepIndex, timeline: buffer, clientScore}` at countdownMs + durationMs + E2E_SUBMIT_MARGIN_MS after the reply; server
  score = snippet `judge` (bit-identical), clientScore = rawScore, score > E2E_SANITY_MIN_SCORE; last reply
  `next = "Completed"` with the item · 06 F3 through the UI: shown score = server score, results screen · 07 §9 field
  list exact; `Recompute.item` = stored; rarity ≤ cap; owner payloads without flags · 08 `Showcase.Place` slot 1 →
  model ≤ 2 s, replicated, part count = RenderPlan, bounds ≤ scaled hitbox + 0.01; Clear, Scrap; a second viewer's
  `Showcase.Inspect` = InspectView · 09 snapshots equal except volatile keys, stands ≤ 5 s · 10 Flood →
  `E_INVALID_INPUT`; Malformed (Length), new-seed Replay (HashMismatch) → `E_INVALID_INPUT`; foreign session or step →
  `E_SESSION_MISMATCH` / `E_WRONG_STATE`; Fast → `E_TOO_EARLY`; each: craft aborted `InvalidInput`, no item, Hard
  strike (`Config.STRIKE_KICK = false`); Exact → clamped pass, flag stored; same step twice → stored reply
  `duplicate = true`; buffer > MAX_TIMELINE_BYTES or extra keys → `E_BAD_REQUEST`; a key with a newline → one log
  line · 11 second `Craft.Begin` → `E_SESSION_ACTIVE` + `data.session`; 30 saves in 1 s → `E_RATE_LIMITED`, ≤ 5
  replies/s, rest silent; no submit → `StepTimedOut` push, score 0, `timedOut`, craft continues; `Craft.ReportDesync`
  → abort `Internal`, no strike · 12 `user_keyboard_input` / `user_mouse_input` with ±20–40 ms offsets: completes,
  client = server, no flags; LMB held on the canvas through GO grinds; release over Abandon recorded; Esc during
  HoldZone then release recorded (R6-12) · 13 plots disjoint, farthest station reachable.
- S-PAR-01 per shape × 20 sizes × random rotations, built as `ItemModelBuilder` builds it (density 1): `Mass` =
  S2 volume (TOL_PARITY_MASS_REL), `CenterOfMass` = S2 centroid (TOL_PARITY_COM_ABS), 200 margin points via
  `GetPartsInPart` agree 100 % · 02 digest of `Pipeline.analyze` (fixtures + 200 `Gen.validSword`), 50
  judged bot runs per family and T-CR-08's outcomes, in both datamodels = `parity.bv<N>.digest` · 03 0.1, 1/3,
  2^53 + 1, 1e-300, 123456.789012345678 through `JSONEncode/Decode`, a Mock save/load and a real key
  (`BS_DataMode = "Live"`) · 04 (R7-22) live `Blueprint.Save` summaries of F1–F5 = client preview; one craft per
  family with clientScore = rawScore.
- S-VIS 01 smithy overview · 02, 03 editor with F1 and A01 on the telephoto path, overflow highlighted · 04 each
  minigame mid-play, reticle on the pointer at 1920 × 1080 and 1280 × 720, trace band 2·halfWidth·H ± 1 px at UI
  scales 0.75 and 1.0 · 05 results card · 06 stands with F1, F3,
  F4, a Rare item lights its plinth · 07 inspect panel, an Epic item sparkles · 08 F3's thin blade, no z-fighting ·
  09 editor and results at 1280 × 720, Text Size Largest, no clipped label (R6-11).
- M-01 build F1 from a picture with free transforms and typed steps · M-03 names each sword's hardest step and why ·
  M-04 explains rarity, stats and the cap · M-08 Normal Trace ≥ 0.5 with Space grinding, orbit and pan; AZERTY: every
  hotkey reachable (M mirrors).

### E-S8.7 Statistical sizing

- Zero flags in N runs bounds the per-step false-positive rate below 3/N at 95 % (rule of three): `FP_RUNS_TS` 300,000
  → < 1e-5, S3's claim (R4b-11), about 37 s per profile in Lune (≈ 0.12 ms per bot run, generate + replay included);
  `FP_RUNS` 20,000 → < 1.5e-4, hence the margin assertions for HoldZone and Trace.
- `studies/anticheat_bots.luau` (S3 owns the final rules): with 8 strikes and sample SD < 2 ms, Elite (σ 12 ms,
  240 fps) flags 5e-6, Good (σ 25) < 5e-6, an exact cheat 100 %, a σ 3 ms cheat 12 %. Trace SD over ≥ 60 samples
  < 0.5 px: humans 0 / 20,000, on-path cheat 100 %.
- `BOT_RUNS` 400: SE of a mean ≈ 0.005 (score SD ≈ 0.1); of a 10 % fail rate ≈ 0.015, inside the 3–15 % band. L3
  total: 3 families × 2 tiers × 2 materials × 6 profiles × 400 ≈ 29,000 runs, plus 4 × 300,000 TimingStrike FP runs
  (≈ 150 s) and one 20,000-run Trace FP case (≈ 130 s at ≈ 6.5 ms per run): ≈ 7 min, inside 10 min.

### E-S8.8 Slice and checkpoint arithmetic

Studio runs this Luau ≈ 2.6× slower than Lune (§4 Performance). A slice overruns its budget by at most one checkpoint
gap: server 4 + 2.6 × 0.35 = 4.9 ms ≤ `SERVER_SLICE_MAX_MS` 5; client 6 + 0.9 = 6.9 ms ≤ `CLIENT_SLICE_MAX_MS` 8
(S6's acceptance). A 4 ms Lune gap (R3-07's wording) would allow 4 + 10.4 = 14.4 ms Studio slices. The X08 cost
cases at `ANALYSIS_LUNE_MAX_MS` 60 (R3-07) take ≈ 156 ms in Studio ≈ 39 server slices ≈ 0.65 s at 60 Hz.
`REPLAY_BUDGET_MS` 8 and `PT_GENERATE_BUDGET_MS` 5 are S3's targets at the 31 s maximum duration (R4b-08).

### E-S8.9 Traceability: what other sections expect from S8

| Expectation (section) | Test |
|---|---|
| invariants I1–I13 (S1 §9) | T-ITM-03 |
| two runs bit-identical, client = server (S2) | T-DIF-10, S-PAR-02, S-E2E-03 |
| Rng vectors, codec, live = replay, goldens (S3) | T-RNG, T-MG-09/13, golden outcomes |
| medium/low flags feed the balance analyses (S3) | §14.13 AntiCheatFlag |
| `Σw = 1 ± 1e-9` and the outcome properties (S4) | T-DEF-03, T-CR-01…10 |
| SessionMachine pure, Guard fuzzer reused on S1/S3 decoders, log lines, `FIXED_SEED` (S5) | T-SES, T-NET-01, T-BP-01, T-MG-08, console hygiene, bridge |
| pure S6 modules, editor acceptance on the minimum-spec PC (S6 §11) | T-ED, M-09, S-PERF-01 |
| S7's Lune list and Studio checks (S7 §13) | T-WLD, T-RND, T-SHW, T-INS, S-E2E-02/08, S-VIS-06/07 |

Fields §14.13 reads from S5's `[TLM]` records: BlueprintSaved (per-step x_f raw and normalized, G, D, tierRaw, tiers;
error codes when `valid = false`) · StepScored (family, tier, material, score, rawScore, clientScore, passed, timedOut,
flags, durationMs, meanErrMs) · CraftCompleted (tiers, materialTier, Q, rarityByScore, rarityCap, capStep, rarity,
`bp`) · CraftAborted (reason, step; `Internal` = desync) · AntiCheatFlag (flag, where, severity) · funnel steps.

### E-S8.10 Names changed from the draft

Bridge InvokeServer → `NetClient.request` (+ `rawFire`) · StepStarted → the `Craft.StartStep` reply · SubmitStep →
`Craft.Submit` · ItemCreated → `next = "Completed"` · TooFast → `E_TOO_EARLY` with abort · AlreadySubmitted →
`duplicate = true` · Busy → `E_SESSION_ACTIVE` · RateLimited → `E_RATE_LIMITED` · `DataService.getData` →
`DataService.read` · `[Blacksmith][E]` → `[blacksmith:<tag>] ERROR` · `tid` → per-join `sid` · DataStore telemetry
sink → cut · FIXTURE_ORIGIN → blueprint space · S8 bot profiles → S3's `Minigames/Bots` · `balance_hash.luau` →
T-BAL-01 over `Definitions/Manifest` · copied `test.project.json` → self-contained + T-META-08 · T-PHY-12 → T-PHY-09.
