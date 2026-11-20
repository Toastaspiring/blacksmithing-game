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
2. [Evidence S2](#evidence-s2) (geometry and difficulty): [E-S2.1](#e-s21-shapes-against-the-engine) · [E-S2.2](#e-s22-min_dim--002-and-sensitivity-mindim-checksluau) · [E-S2.3](#e-s23-contact) · [E-S2.4](#e-s24-why-no-global-grid) · [E-S2.5](#e-s25-regression-fixtures-base-f5-reg-checksluau) · [E-S2.6](#e-s26-mirror) · [E-S2.7](#e-s27-grip-independent-difficulty-and-the-two-deviations-adv-variantsluau) · [E-S2.8](#e-s28-performance-and-checkpoints-perf-gapsluau) · [E-S2.9](#e-s29-calibration-and-the-full-fixture-tables) · [E-S2.10](#e-s210-validation-invariance-determinism-val-inv-det) · [E-S2.11](#e-s211-the-enclosed-verdict-against-the-truth-verdict) · [E-S2.12](#e-s212-the-exact-verdict-cover) · [E-S2.13](#e-s213-difficulty-as-built-m3) · [E-S2.14](#e-s214-a-whole-design-moved-the-shift-fix-after-m3)
3. [Evidence S3](#evidence-s3) (minigames): [E-S3.1](#e-s31-prng-test-vectors-unchanged-module-cross-checked-bit-for-bit-against-the-python-reference-rng_refpy) · [E-S3.2](#e-s32-final-bot-table-distluau-2000-outfinal_tabletxt) · [E-S3.3](#e-s33-full-parameter-columns-and-resolved-values-paramsluau-goldenluau) · [E-S3.4](#e-s34-timingstrike-golden-values-and-grade-bands-goldenluau) · [E-S3.5](#e-s35-precisiontrace-edge-mapping-golden-values-and-costs-costluau-worstluau-goldenluau) · [E-S3.6](#e-s36-determinism-and-codec-detluau) · [E-S3.7](#e-s37-holdzone-why-strokes-hztuneluau-goldenluau) · [E-S3.8](#e-s38-check-margins-and-cheats-checksluau) · [E-S3.9](#e-s39-tuning-log-multisweepluau-sweepluau-2003000-runs-per-setting) · [E-S3.10](#e-s310-m4-as-built)
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
| X01 2 blade copies at z ±0.003, vs the union blade (0.066 thick) | ΔD max 0.0002, with the rank of §4.4 (\|z\| before z; 0.0010 under the rank before it) (vs F5: Hammering −0.0281, the real thickening) | 0.01 |
| X02 6 copies at z = k·0.002, vs the union blade (0.072) | ΔD max 0.0010 walking the measure's rank, as M3 builds it (Hammering 0.0510 against 0.0520; 0.0006 in part order) | 0.01 |
| X03 F4 + a 0.0003 stud³ fin | ΔThinness 0.0000 (All; Blade +0.00034), Hammering +0.0003; the fin splits F4's one chain of 5.7237 into two, the main 4.7564, so Sharpening 0.3420 Hard → 0.1980 Normal (only the main chain counts, §4.6; SPEC §17.1 O10) | 0.02 |
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

Physics follows the ruling: A26's physics axis is (−0.643, 0.766) and its balance 0.038 (ring-grip base 0.051). Since
M3's fix round 1 the physics frame and the guard line are the kept parts' (SPEC §4.5), so a hidden grip part steers no
physics either: A25's enclosed core leaves F1's (with every Grip part it tilted the axis to (−0.010, 1.000), cutIndex
0.724130 against 0.724180), and the M3 verifier's strap hidden in A26's rings, turned 20° or 40°, A26base's (the axis
(−0.342, 0.940) or (−0.643, 0.766), bladeLength 2.7699 → 2.6029 or 2.1219, cutIndex 0.6684 or 0.5080) (E-S2.13).

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

The tables are the parts in the measure's rank order (`Sampling.measureRanked`), as M3 builds `Analyze.run` and as
T-DIF-12's goldens bless them: as M3 was first built, walking each fixture's own part order, as the fit did, gave the
same values at these digits but for C09's Thinness on All (0.3858 / 0.386) and Hammering (0.3170). M3's fix round 1 (θ
on every local axis, the canonical walk and its lattice pick, SPEC §5.2; the raster read off its cells' centres, §4.6)
then moved Thinness on All for C04, C05, C09 and C13 and on the Blade for F3, C06, C08 and C09, C04's edge 7.107 →
7.149, Hammering on C04, C05, C09 and C13 (0.3368 → 0.3379, 0.1363 → 0.1369, 0.3186 → 0.3201, 0.1133 → 0.1137) and
C04's Sharpening (0.4703 → 0.4769), no tier (E-S2.13); these tables are `Analyze.run`'s after that round, its physics
frame the kept Grip parts' (no row here cleans a Grip or Guard part the frame feels). Physics, mass and balance stay sums in
blueprint order (SPEC §4.1).

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
| C04 Rapier (Steel blade) | 7 (7) | 0.4150 | 0.05282 | 0.239 | 4.130 | 3.654 | 7.149 | 1.00 |
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
| C04 Rapier (Steel blade) | 5.169 / 0.167 | 0.596 / 0.596 | 0 / 0.000 | 2.499 / 0.332 | 7.149 / 0.734 | 6.655 / 0.174 | 2 / 0.333 | 0.05282 / 0.000 |
| C05 Cleaver | 6 / 0.231 | 0.001539 / 0.002 | 0.2726 / 0.454 | 2.24 / 0.000 | 5.972 / 0.366 | 8.709 / 0.272 | 1 / 0.000 | 0.4725 / 0.545 |
| C06 Sabre (Steel) | 8.486 / 0.422 | 0.3514 / 0.351 | 0.2569 / 0.428 | 2.36 / 0.100 | 6.48 / 0.525 | 11.52 / 0.406 | 2 / 0.333 | 0.08695 / 0.010 |
| C07 Dagger | 4.405 / 0.108 | 0 / 0.000 | 0 / 0.000 | 1.985 / 0.000 | 2.968 / 0.000 | 6.009 / 0.143 | 1 / 0.000 | 0.04339 / 0.000 |
| C08 Greatsword | 5.2 / 0.169 | 0.1882 / 0.188 | 0 / 0.000 | 2.348 / 0.080 | 6.392 / 0.497 | 6.953 / 0.188 | 1 / 0.000 | 0.1925 / 0.156 |
| C09 Ornate (18 parts) | 10.16 / 0.551 | 0.3935 / 0.394 | 0 / 0.000 | 2.625 / 0.542 | 5.411 / 0.191 | 20.25 / 0.821 | 1 / 0.000 | 0.08005 / 0.000 |
| C10 Gamey filler, symmetric | 6.916 / 0.301 | 0 / 0.000 | 0 / 0.000 | 2.139 / 0.000 | 4.98 / 0.056 | 8.871 / 0.280 | 1 / 0.000 | 0.1927 / 0.156 |
| C11 Gamey filler, lopsided | 6.916 / 0.301 | 0 / 0.000 | 0.002488 / 0.004 | 2.128 / 0.000 | 5.02 / 0.069 | 10.04 / 0.335 | 1 / 0.000 | 0.1925 / 0.156 |
| C12 Arming, blade in 5 overlapping segments | 8.6 / 0.431 | 0.2843 / 0.284 | 0 / 0.000 | 2.263 / 0.000 | 5.644 / 0.264 | 9.72 / 0.320 | 1 / 0.000 | 0.1055 / 0.035 |
| C13 Arming, guard = half + mirror (+CornerWedges) | 5.984 / 0.230 | 0.2843 / 0.284 | 0 / 0.000 | 2.278 / 0.000 | 5.644 / 0.264 | 11.17 / 0.389 | 1 / 0.000 | 0.1071 / 0.038 |
| C14 Arming translated (0, +0.27, +0.05) | 4.6 / 0.123 | 0.2843 / 0.284 | 0 / 0.000 | 2.26 / 0.000 | 5.644 / 0.264 | 5.709 / 0.129 | 1 / 0.000 | 0.1055 / 0.035 |
| C15 Arming rotated 4 deg about Z at the grip | 4.6 / 0.123 | 0.2824 / 0.282 | 0.3144 / 0.524 | 2.262 / 0.000 | 5.626 / 0.258 | 5.709 / 0.129 | 1 / 0.000 | 0.1054 / 0.035 |

#### Factors on work set {Blade} (Sharpening) (raw / x)
| Fixture | PartCount | Thinness | Asymmetry | SurfaceComplexity | EdgeLength | Joints | MaterialMix | Volume |
|---|---|---|---|---|---|---|---|---|
| F1 ArmingSword | 1.176 / 0.000 | 0.001614 / 0.002 | 0 / 0.000 | 2.258 / 0.000 | 5.433 / 0.198 | 0.2483 / 0.000 | 1 / 0.000 | 0.02531 / 0.000 |
| F2 MinimalSword | 1 / 0.000 | 0 / 0.000 | 0 / 0.000 | 1.991 / 0.000 | 4.98 / 0.056 | 0 / 0.000 | 1 / 0.000 | 0.0384 / 0.000 |
| F3 Rapier | 1.092 / 0.000 | 0.7171 / 0.717 | 0.005451 / 0.009 | 2.98 / 1.000 | 7.409 / 0.815 | 0.1792 / 0.000 | 1 / 0.000 | 0.008698 / 0.000 |
| F4 Cleaver | 2 / 0.000 | 0 / 0.000 | 0.3954 / 0.659 | 1.778 / 0.000 | 5.724 / 0.289 | 1 / 0.000 | 1 / 0.000 | 0.3264 / 0.342 |
| F5 StarterSword | 1.176 / 0.000 | 0.001614 / 0.002 | 0 / 0.000 | 2.258 / 0.000 | 5.433 / 0.198 | 0.2483 / 0.000 | 1 / 0.000 | 0.02531 / 0.000 |
| C01 Minimal | 1 / 0.000 | 0 / 0.000 | 0 / 0.000 | 1.854 / 0.000 | 5.06 / 0.081 | 0 / 0.000 | 1 / 0.000 | 0.06 / 0.000 |
| C02 Arming (Iron) | 1.6 / 0.000 | 0.03922 / 0.039 | 0 / 0.000 | 2.281 / 0.000 | 5.644 / 0.264 | 1.563 / 0.000 | 1 / 0.000 | 0.0324 / 0.000 |
| C02 Arming (Steel) | 1.6 / 0.000 | 0.03922 / 0.039 | 0 / 0.000 | 2.281 / 0.000 | 5.644 / 0.264 | 1.563 / 0.000 | 1 / 0.000 | 0.0324 / 0.000 |
| C04 Rapier (Steel blade) | 1.169 / 0.000 | 0.3222 / 0.322 | 0 / 0.000 | 2.63 / 0.550 | 7.149 / 0.734 | 0.4657 / 0.000 | 1 / 0.000 | 0.01552 / 0.000 |
| C05 Cleaver | 3 / 0.000 | 0 / 0.000 | 0.327 / 0.545 | 2.048 / 0.000 | 5.972 / 0.366 | 3.606 / 0.029 | 1 / 0.000 | 0.3974 / 0.441 |
| C06 Sabre (Steel) | 5.486 / 0.191 | 0.1093 / 0.109 | 0.6682 / 1.000 | 2.397 / 0.162 | 6.48 / 0.525 | 6.932 / 0.187 | 1 / 0.000 | 0.0337 / 0.000 |
| C07 Dagger | 1.405 / 0.000 | 0 / 0.000 | 0 / 0.000 | 1.844 / 0.000 | 2.968 / 0.000 | 1.084 / 0.000 | 1 / 0.000 | 0.01458 / 0.000 |
| C08 Greatsword | 2.2 / 0.000 | 0.003108 / 0.003 | 0 / 0.000 | 2.217 / 0.000 | 6.392 / 0.497 | 2.891 / 0.000 | 1 / 0.000 | 0.072 / 0.000 |
| C09 Ornate (18 parts) | 3.46 / 0.035 | 0.1676 / 0.168 | 0 / 0.000 | 2.585 / 0.474 | 5.411 / 0.191 | 7.047 / 0.193 | 1 / 0.000 | 0.02712 / 0.000 |
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
| C04 Rapier (Steel blade) | 0.0000 / 0.0000 Normal | 0.3379 / 0.3379 Hard | 0.4769 / 0.4769 Hard (Expert) | N/H/H |
| C05 Cleaver | 0.5451 / 0.5451 Hard (Expert) | 0.1369 / 0.1369 Normal | 0.3466 / 0.3466 Hard | H/N/H |
| C06 Sabre (Steel) | 0.0097 / 0.0097 Normal | 0.2991 / 0.2991 Hard | 0.5948 / 0.5948 Hard (Expert) | N/H/H |
| C07 Dagger | 0.0000 / 0.0000 Normal | 0.0000 / 0.0000 Normal | 0.0000 / 0.0000 Normal | N/N/N |
| C08 Greatsword | 0.1563 / 0.1563 Normal | 0.0992 / 0.0992 Normal | 0.2487 / 0.2487 Hard | N/N/H |
| C09 Ornate (18 parts) | 0.0001 / 0.0001 Normal | 0.3201 / 0.3201 Hard | 0.1904 / 0.1904 Normal | N/H/N |
| C10 Gamey filler, symmetric | 0.1565 / 0.1565 Normal | 0.0000 / 0.0000 Normal | 0.0282 / 0.0282 Normal | N/N/N |
| C11 Gamey filler, lopsided | 0.1562 / 0.1562 Normal | 0.0012 / 0.0012 Normal | 0.0368 / 0.0368 Normal | N/N/N |
| C12 Arming, blade in 5 overlapping segments | 0.0355 / 0.0355 Normal | 0.1137 / 0.1137 Normal | 0.1318 / 0.1318 Normal | N/N/N |
| C13 Arming, guard = half + mirror (+CornerWedges) | 0.0376 / 0.0376 Normal | 0.1137 / 0.1137 Normal | 0.1318 / 0.1318 Normal | N/N/N |
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

### E-S2.11 The Enclosed verdict against the truth (`verdict/`)

L, the rule this study ended with, was replaced in M2 by an exact reading on a polyhedral model of each part: E-S2.12.
One pass over all parts, with a grid and a sub-grid budget they share, let other parts move a verdict: on C09, hidden
blocks clean a plate that shows 20 %, Hard to Normal, against §5. The fix is a verdict per part, then one measure of the
kept parts alone (§4.4). This study chose its rule, P below, against a high-resolution truth. Two reviews then found what its
sets did not hold, slits between cover parts and ids, and the rule became L: the rank, and flat patches measured on lines.
Tools, report and every variant's numbers: `prototypes/S2/verdict/` (`report.txt` for P, `lines/` for L); Lune, Studio assumed
2.6 × Lune and not touched.

**Truth** (`oracle.luau`). Per-face golden-ratio lattices, a Fibonacci sphere, at least 40,000 points or spacing 0.0075, the
same hide test per point as §4.4, no budgets, against all parts but exact copies and Dust; 4,000 points settle a share over
30 %. 320 closed-form checks (ball cap, cylinder arc and slot, sunk block, cut wedge, coincident faces, probe gap, each in 5
whole-design turns): worst error 0.0246 points of a share.

**Sets** (`sets.luau`). 32,175 designs, 290,241 parts. Band counts reflect how densely each sweep samples, not how often
players do this. A verdict on a true share from 1.5 to 2.5 % is not counted wrong. L is measured on these 4 and on more
(`lines/b_sets.luau`), against a truth written apart from the build (`lines/truth.luau`: faces split until each cell is settled,
minimum cell 0.0004, the same hide test): 105,626 designs, 953,279 parts in all.

| Set | Designs | What |
|---|---|---|
| fixtures | 117 | the prototype's calibration, golden, adversarial, regression, validation and perf fixtures; the repo's F1–F5, A01–A24 |
| plausible | 23,009 | decoration on C02, C05, C06, C09, F1–F5, its sink depth swept across 2 %: ball rivets 7,296, cylinder ribs 3,432 and rivets 1,782, plate edges 4,518, plate tilts 288, C09's plates 10, bevels 891, laminates 760 and laminated hilts 672, wrap rings 1,053, a pommel in a block 507, wedges in a guard 1,080, rods 720 |
| fuzz | 5,000 | `Gen.validSword` + filler 2,000, `anyDesign` 3,000 |
| poke | 4,049 | a random shape and turn sunk across 2 % into a part of a real or random design |
| slits (`PlausibleDesigns`, with plausible above: 32,349) | 9,340 | fullers 5,568: a core under cover strips, a groove 0.01–0.12 or a twin; ribbed plates 3,616, with and without edge bars; combs 16, walled blades 140 |
| the first review's | 64,111 | pokes in odd orientations, chamfers, tilted plates, thin parts, rods, pin rivets, ball rivets on 8 bases, curved grips, beads 264, and the fullers, combs and walled blades above once more |

The laminates keep the blade block inside the cheeks (`sets.luau` means to drop it and compares a copy, so it never does); the
laminated hilts have none.

**Variants.** False Enclosed: parts cleaned at a true share of at least 2.5 / 3 / 5 / 7.5 / 10 / 15 / 20 %, all sets. Plausible:
designs whose wrong verdicts move D by \|ΔD\| ≥ 0.02, by ≥ 0.05, and tier flips, against the truth's verdict on the same
measure, through the emulator. Flips: designs whose kept set hidden parts change, on 18,000 of random fill and about 110,000
with hidden copies inside a part. Cost: total ms Lune, median of 21 (15 on climbs), P1 and the worst of 93 climbed designs.

| Variant | False Enclosed | False kept < 1.5 / 1 % | Plausible | Flips: fill / copies | P1 | Worst climbed (≈ Studio) |
|---|---|---|---|---|---|---|
| R: one pass over all parts, shared budget (the build before) | 1942/1428/768/442/105/18/5 | 526/250 | 134/101/59 | 194 of 12,000 / not run | 28.47 | 36.01 (93.6) |
| A: 64 samples, Block estimate, sub-grid budget 6000 | 2338/1792/1012/510/137/30/6 | 553/270 | 189/116/67 | 50 / 20 | 25.38 | 35.82 (93.1) |
| B: A, a Ball on the first rung with 6 nf² ≤ 64 | 2302/1760/983/496/136/29/6 | 560/279 | 189/116/67 | 51 / not run | 25.18 | 35.06 (91.1) |
| C: 96 samples | 2206/1678/931/461/120/29/6 | 534/263 | 173/113/67 | 66 / not run | 30.23 | 37.13 (96.5) |
| D: 128 samples | 2139/1611/902/466/119/28/6 | 522/254 | 176/109/65 | 64 / 138 | 30.01 | 42.09 (109.4) |
| D, budget 12000 | 2139/1611/902/466/119/28/6 | 522/254 | 176/109/65 | 13 / not run | 29.77 | 42.29 (110.0) |
| A, budget 12000 | 2338/1792/1012/510/137/30/6 | 553/270 | 189/116/67 | 0 / 0 | 26.16 | 35.12 (91.3) |
| P: 5 points, a 4 × 4 sub-grid, strip credit | 371/91/5/1/0/0/0 | 221/46 | 3/0/0 | 0 / 0 | 25.54 | 33.79 (87.9) |
| **L: §4.4's rule: the rank, flat patches on lines** | **265/109/5/1/0/0/0** | **77/23** | **6/0/0** | **0 / 0** | **31.73** | **54.55 (141.8)** |

L's columns are its own run, on a machine about 9 % slower than the others', on designs climbed against its own counted shape
queries (P's 33.79 was climbed on a clock, which lies: see Cost; the designs those counted climbs found take 76.70 under P).
Its plausible column holds the 9,340 slit designs too, which add nothing to it.

Sample count is not the lever. Totals as above, the Ball by its real count: 192 samples 1964/1447/775/421/89/16/6, tier flips
59; 256: 1985/1447/736/410/67/0/0, 49; 512: 1765/1274/652/370/54/0/0, 37. P at 48 samples: 364/91/5/1/0/0/0, 3 tier flips; at 96:
380/95/5/1/0/0/0, 0; at 128: 372/85/5/1/0/0/0, 0. So 64 stays: fewer loses tiers, more buys nothing. The misses are structural: a
strip narrower than 1/8 of a patch at its rim or 1/4 through its centre falls between sub-points (every laminate tier flip);
corners and centre hidden by different parts count as uniform, so a slit is missed (bevels and plates up to 32 %); a Cylinder's
side has no sub-grid, and thin rods have 8 directions on every rung; a triangle with 1 cell on an edge has no sample in its far
half (CornerWedge tips up to 10.61 %); a Ball under d 0.12 is nf = 2 on every rung, under any budget.

**What each reading rule buys**, one removed from P (false Enclosed; plausible):

| Without | False Enclosed | Plausible |
|---|---|---|
| strip credit | 1069/613/242/44/28/9/0 | 160/103/67 |
| one part hiding the whole patch | 474/185/65/34/18/3/0 | 27/9/0 |
| a sub-grid on a Cylinder's side | 752/450/258/164/80/2/0 | 43/9/0 |
| those two | 801/493/285/179/89/5/0 | 43/9/0 |
| the triangle minimum | 373/93/7/2/1/0/0 | 3/0/0, but a CornerWedge poke at 6.47 %, \|ΔD\| 0.0393, returns |
| a Ball's own grid (Block estimate) | 1311/889/478/261/2/1/0 | 3/0/0 |

Strip credit 1/12 keeps X02's 5 copies again, and 1/24 gives 8 tier flips; corners at 1.0 also keep X02 (true 0.92 %, read 3.96 %,
\|ΔD\| 0.0012 against the prototype). The budget binds on no design of the 4 sets at 6000 or 12000 (3000 adds only P1's Giant23): it
exists for cost, and it is the last channel for hidden parts, which count in its charge. P with 6000: 75 random-fill designs flip, worst
\|ΔD\| 0.0108; D with 3000: laminate tier flips, \|ΔD\| 0.4166. Going without is affordable only with the hider-first order, which
changes no bit: worst climbed 33.79 ms with it, 40.91 without. Reading a ball's cap by nf (largest sample; share at which an axis cap
reads 2 %; worst share in any direction still under 2 %): nf 2: 4.17 %, 9.18 %, 9.18 %; nf 3: 3.44 %, 0 %, 5.93 %; nf 4: 1.64 %, 2.86 %,
4.69 %; nf 5: 1.26 %, 3.58 %, 3.58 %. On real swords wrong Ball verdicts move D by at most 0.0037 (0.0070 once, on F3), since the sunk
volume belongs to the host.

**Slits between cover parts.** P's sets had none, and it failed on them, both ways. Its sub-grid is blind between its columns, up to
½ of a patch, and its credit stands on one point, whatever the strip's width. False Enclosed: a twin fuller is an ordinary blade, and a
core 0.2 × 2.5 × 0.04 under twin grooves 0.02 wide, true 16.2 %, read nothing, \|ΔD\| 0.5645 and a tier; a core 0.2 × 2.5 × 0.02 under twin
grooves 0.05 wide, true 44.59 %, read nothing; a comb, true 20.12 %, read 0.13 %, \|ΔD\| 0.7147. On 5,568 fullers 1398/1278/792/474/270/114/62/14/8
were cleaned at 2.5/3/5/7.5/10/15/20/30/40 %, 1,434 tier flips; on 71,616 ribbed plates 10,094 / 5,996 / 3,550 / 1,760 / 544 / 144 at 2.5/5/7.5/10/15/20 %,
5,992 tier flips, of which the rule before P cleaned 2,001 / 644 / 189 / 32 / 0 / 0. False kept: a core behind 2 strips with a slit 0.00001 wide through its patches'
centres, true 0.00 %, read 8.09 %, and K + F moved 2 tiers, \|ΔD\| 0.3772; 3 wedges at the reading points cleaned a core that truly shows 3.8 %, \|ΔD\| 0.3855. More samples do not
cure it: 128 cleans 1,456 / 946 / 526 / 188 / 30 / 0 of a sample where 64 cleans 2,834 / 2,128 / 1,506 / 808 / 252 / 72. The second review tried points between the old ones (a quarter of the ribbed
plates: 10 at 2.5 %), which leaves the over-read. The first tried lines, read exactly: that is L.

**Ids.** P kept a coincident face for the lower index, and spent the measure's budget in part order. Plates 0.02 thick wholly inside a real blade, flush with its
faces, with lower ids: the blade read 0 % and was cleaned, solid in mass and hollow in D, F5 \|ΔD\| 0.4834, C02 0.5756, C05 0.7159. An exact copy with a lower id took the original's turn, and its
slot: F3 + a copy of its blade in the Guard, Sharpening 0.6104 → 0.0645. 300 random orders of C09: Hammering 0.2601–0.3185, Sharpening 0.1385–0.1904. L ranks the parts by the
solids (§4.4), in the verdict, the measure and ownership: every one of these \|ΔD\| 0.0000, or 0.0009 for 5 exact copies of C09's parts in front, and 300 orders of C09 keep Smelting and Sharpening exactly, Hammering
0.3170–0.3195: what is left is M3's probes in part order, in the emulator. The rank moves D on real designs only where it moves who keeps a band: C09 Hammering 0.3061 → 0.3170, X01 0.0756 → 0.0764, X04a/b Smelting +0.0001, X04-10 and X07c
Hammering −0.0001; in ownership P3 Smelting 0.2789 → 0.2777, Hammering 0.1846 → 0.1804, Sharpening 0.1828 → 0.1821. No tier. On the parts in rank order the prototype's rules are the build's, so `Reference.spec` hands it them that way, and everything still agrees.

**L's reading**, on all 105,626 designs, 953,279 parts, false Enclosed at 2.5/3/5/7.5/10/15/20/30/40 %, false kept under 1.5/1/0.5/0.25 %:

| Shape | Parts | False Enclosed | False kept | Highest cleaned | Lowest kept |
|---|---|---|---|---|---|
| Block | 487,961 | 0 | 0 | | |
| Wedge | 164,024 | 0 | 0 | | |
| CornerWedge | 19,081 | 10/7/0/0/0/0/0/0/0 | 1/0/0/0 | 4.63 %, \|ΔD\| 0.0043 | 1.27 % |
| Cylinder | 134,312 | 236/90/0/0/0/0/0/0/0 | 80/37/16/5 | 4.45 %, \|ΔD\| 0.0002 | 0.22 % |
| Ball | 147,901 | 74/54/25/19/12/5/0/0/0 | 23/1/0/0 | 18.59 %, \|ΔD\| 0.0964 | 0.61 % |

0 tier flips, of 407 designs with a wrong verdict; \|ΔD\| ≥ 0.005 / 0.01 / 0.02 / 0.05 / 0.1 on 39 / 32 / 22 / 9 / 0. Worst on the plausible set 0.0250, wrap rings on C06; the beads 0.0964. The 17,904 ribbed plates of the review's sweep it ran on
(10 of 40 shards): 0 wrong. P1 tracks the truth to about 0.3 points: Giant2 true 2.04, read 1.91; Giant13 1.72, 1.75; Giant15 1.78, 1.79; Giant21 2.09, 2.06; Giant23 5.59, 5.31.
Climbs on the reading itself, a plate under up to 20 lids with edges snapped to its lines, centres and corners, 3 sizes, 4,000 to 6,000 evaluations each: nothing cleaned above 4.94 % true (windows between the lines) and nothing kept below 1.77 %.

| Trial | Result |
|---|---|
| the first form: no search, the 2 lines through the centre first, the spread alone | tilted plates 9/3 false Enclosed at 2.5/3 %, odd pokes 3/3; here 0 and 2/2, and a window off those 2 lines is read |
| 4 × 4 sub-grid, then points between its columns where 2 parts hide all (V2's) | fullers mostly mended, the over-read not |
| a family that reads nothing, by the spread alone | a groove that stops inside a patch reads nothing there; so a family that reads nothing loses |
| the reach test off | no reading moves, 0 of 69,350 parts; chords × 2 to × 6 |
| a covered line not ended; B read when A agrees on a fraction; no part moved up | no reading moves, 0 of 69,350 parts, once a line's union goes run by run |

124 mutants of the rank, the reading, the near list and a Cylinder's side (what a review's 22 survivors became among them): 121 killed, by the quick Physics suite. Alive: `a1 <= a0` (a line past the patch: the caller skips it anyway), a tie read from the second family (`min` is there for the symmetry; no design found differs), and a Ball's spacing without its −0.5 (at nf = 4 the same number).

L at other sample counts, on a fifth of the plausible set and of the fullers, odd pokes and chamfers, 12,778 designs: at 64 false Enclosed 52/19/0, kept 14/4, 0 tier flips; at 48 the same; at 96 63/22/0, kept 14/5, 0. More buys nothing here either.

**L on the fixtures.** Of the prototype's 71 fixtures, handed over in rank order, only P1 differs, in its cleaned list: Enclosed #6, 8, 11, 12, 13, 15, 16, 18, 21, 22, 23 in the prototype, #2, 6, 8, 11, 12, 13, 15, 16, 18, 22 here
(Giant2 truly shows 2.04 %, Giant21 and 23 2.09 and 5.59 %), Sharpening 0.0114 → 0.0086, no tier. X01 and X02 against their union blades \|ΔD\| 0.0010 and 0.0006. No false verdict on the repo's F1–F5 or the canonical A01–A24. Flips: 0 of 18,000 designs of random
fill and of 20,000 with hidden copies inside a part (`lines/flip2.luau`). A mirror image reads the same: 0 parts differ on 92,860 images of the plausible set, fuzz, poke and chamfers, now a CornerWedge's second slope on the verdict's grid starts from
the corner that mirrors the first's, which also takes its largest grid from 169 samples to 64. Only true twins with a face in common swap who keeps it: 2 of 8,696 images of odd pokes into C09's tip, \|ΔD\| 0.0054.

**Grids.** The most samples a verdict reads, over parts that are not Dust and fit the hitbox (`lines/grid_max.luau`, `grid_max2.luau`, a dense list and 150,000 random sizes a shape): Block 70 (1.6 × 4.48 × 0.6), Wedge 67, CornerWedge 64, Ball 96, Cylinder 128 (0.56 × 0.022).

**Cost.** Median of 21, M2 + M3 = total ms Lune, on a machine about 9 % slower than E-S2.8's: F5 1.47 + 2.86 = 4.33, C02 4.90, C05 14.16, C09 13.71, C10 11.08, P1 23.70 + 8.02 = 31.73, P1 + a speck 30.21, P2 21.55, P2 + a speck 22.49, P3 18.88, P3 + a speck 19.31, P4 12.74,
P5 6.72: all under 33 ms; under P on the same machine, P1 28.47, C05 15.23, C09 13.64, F5 4.26. The verdict: P1 12.04, against 10.18. A climb's score on a clock lies under load (up to 91.5 ms for designs that measure 34–41 alone), so the climbs count shape queries: 4 seeds × 25,000 evaluations against P found
designs P's own 36,000 clocked evaluations had not, 76.70 ms ≈ 199 Studio, the verdict 35.57; 4 seeds × 12,000 against L, 2 of them with those as starts: the worst valid design 54.55 ≈ 142, and the worst verdict 30.73 ≈ 80 (24 parts, thin Cylinders and CornerWedges). `worst_P.json` holds the 11 worst of 34 climbed designs that are canonical and, after relabelling (labels move no verdict), valid.
So the 75 ms holds on real designs, not on hostile ones (§4.9, §17.2). §4.9's fallback does not reach the verdict: `N_SURF_WORK` 20000 and `EDGE_MAX_WORK` 15000 took the worst of P's from 77.95 to 73.88, the verdict still 35.93. Dropping the one-part search changed no bit and saved nothing. The lines cost no more than the sub-grid because a part must reach the patch to be asked,
on its own 3 axes at the surface and at the probe: most near parts stand clear of the plane, and that takes the chords on the worst of the plates from about 229,000 to about 37,000. Longest run between checkpoints: median 0.06–0.37 ms, up to about 0.5 on single runs; the long ones end at `MassProps`' GJK, charged 20 units.

**The build.** M2 replaced L by a reading exact on a polyhedral model of each part (E-S2.12): what follows is the history of L. `Physics/Sampling` was L as written here; P is what `check_port.luau` compared, bit for bit, on all 32,175 designs, and it is history. `tests/Physics/VisibleOracle` and `PlausibleDesigns` are ports of the study's: the first 23,009 designs come out bit for bit, and the oracle takes its rank from `Sampling.ranked`. `VerdictPrecision.spec`'s sweep took a tenth of the 32,349 and asserted nothing that shows 10 %
cleaned and nothing under 0.25 % kept under L, which measured 6.33 % (a ball rivet) and 0.26 % (a grip under 4 rings); with the exact reading it takes a
tenth of 33,389 and the 17 attack designs (about 49 s alone) and asserts 4 % and 1.9 % (E-S2.12).

### E-S2.12 The exact verdict (`cover/`)

L, E-S2.11's line reading, held on every set it was measured on and fell to three rounds of attack: any finite set of probe
lines loses to geometry aligned with it. Hairlines on its lines keep a hidden core, ribs over every line clean one that shows,
slats round a bar and blocks round a Ball open bands between its points: on the 1,340 designs the verifiers recorded, 84 rows
differ from the truth's, 48 of them tier flips, worst \|ΔD\| 0.796. M2 replaces it with a reading that is exact on a polyhedral
model of each part (§4.4). Tools, logs and data: `prototypes/S2/cover/` (its `README.md`); Lune 0.8.9, Studio assumed 2.6 ×
Lune and not touched.

**Two prototypes.** A subtracts: what a facet shows is a list of disjoint convex polygons from which each piece (§4.4) is cut
in turn, every area a polygon's own. B integrates the union's boundary (Green's theorem), each piece edge clipped against the
others, with a tolerance rule for collinear edges (lines within 2e-8 are one line: the earlier piece keeps it, opposite senses
both drop it). A is 742 lines, B 897, L was 372. A judge built the model a third time from the words alone, clipped every
facet in 3D and took the union's area by vertical slabs, every vertex and edge crossing an event (`CoverBrute`, ported to the
tests).

**The cross-check.** On the natural corpora, 223,862 parts (the fixtures, the attack corpus, every 4th plausible design,
the verifiers' 12 families, the climbed designs), A = B = the brute force to 2.61e-13 of a part's area. On 8,000 fuzz
tangles (55,911 parts: offsets 0, ±1e-9…±1e-5, ±1.5e-8, ±3e-8, ±EPS, HIDE_OFFSET ± EPS, coincident faces, exact and turned
copies, Dust, sheets), 916 parts differ by more than 1e-9; 811 of them are exact ties (a hider's face parallel to the facet
at EPS or HIDE_OFFSET + EPS exactly, where rounding decides, up to 0.459 of a part), with A and B inside the brute force's
±1e-11 bracket; A is outside it on 0 parts, B on 491 (up to 0.0273 of a part). B's rule is not transitive: 3 edge lines g
apart, LINE_TOL/2 < g ≤ LINE_TOL, pieces taken inner, middle, outer, leave no copy of the edge, and Green's sum loses
½(a × b), the size of the facet. In valid C01 swords: a filler that truly shows 0 % reads 5.625 % and is kept (\|ΔD\| 0.388, a
tier); a part that shows 5.000 % reads 0 (\|ΔD\| 0.371, a tier). A reads 0.000 and 5.000 %. The build is A.

**The model's channels.** In each part's own frame a round copy spun or turned about its symmetry does not coincide with
its original on the model: a Cylinder spun 37° reads 41.8 % and is kept, a Ball turned 77° 50.4 % (true 0 %). Frames the world
fixes (a Ball's octahedron on the world axes, a Cylinder's circle from the world axis most across its own) read 0 and 100 %,
at no cost (P2 1.41 against 3.43 ms). Every inscribed model also has a window one sagitta wide under HIDE_OFFSET: a rod sealed
in 16 flat walls whose corners stand 0.0115–0.0119 off it truly shows nothing and read 5.1–9.5 % (r 0.20, \|ΔD\| 0.41–0.44)
and 5.9–8.1 % (r 0.10, \|ΔD\| 0.24, tier flips) on every model tried, finer ones included (32 sides below r 0.415). The
conservative probe closes it: a round part's facet probes HIDE_OFFSET + its sagitta, a round hider's half-spaces move out to
its true surface for the probe only, the buried piece keeps them inscribed. Every sealed rod reads 0.000 %; exact on its model
as before (2.6e-13); the same cost.

**Accuracy against the truth** (VisibleOracle, fine lattice where a verdict could be wrong):

| Set | L (the build before) | A, world frames | A, world frames + conservative probe (the build before its spread) |
|---|---|---|---|
| attack corpus, 1,340 designs: rows ≠ the truth's, tier flips, worst \|ΔD\| | 84, 48, 0.796 | 2 (1 invalid design, twice), 0 | 0, 0 |
| plausible, every 4th (77,205 parts): cleaned at ≥ 2.5 / 3 %; kept under 1.5 %, lowest kept | — | 121 / 0; 3, 1.290 % | 121 / 0, highest 2.945 %; 0, 2.002 % |
| the verifiers' 12 families, every 8th (71,309 parts): cleaned at ≥ 2.5 / 3 % | — | 12 / 0 | 13 / 1 (a bead truly 3.863 %, read 1.674 %) |
| **the build on all 33,389 plausible designs** (323,577 parts, the verifiers' ribbed bars, cages, grilles and tilings added): cleaned at ≥ 2.5 / 3 / 4 %; kept under 2 / 1.5 % | | | **447 / 0 / 0, highest 2.945 % (a Ball rivet); 0 / 0, lowest kept 2.002 %** |
| the build on the 17 attack designs of `Cover.spec` (c) | | | 0 wrong of 326 parts |

Every wrong verdict left is a round part near 2 %, the inscribed model's band (§17.2), or a flat part next to a round hider,
which can read less than the truth past 2 % (§17.2's band row). A finer model (Cylinder up to 128 sides, Ball grid 6–8)
halves the band (false Enclosed 192, all thin ribs, at most 2.82 %), costs 2–6 × (P4 51 ms, 1.22 M units) and does not
close the sealed window. The probe's spread (below, "After the second verifiers' round") moves the last column: on the
plausible set 463 / 3 / 0, the highest 3.615 % (a Ball in a pommel housing); 0 / 0, the lowest kept 2.002 %; and a flat
facet reading a Ball on its sphere (below, "After the fourth verifiers' round") 455 / 3 / 0, the same highest and lowest.

**Cost.** Lune, median of 15, the machine otherwise quiet (Studio, Voicemod and a Riot client idle, about a third of a core),
verdict / whole exposure, the build against L on the same designs (`build/out/final_real.log`):

| Design | Units | Build | L |
|---|---|---|---|
| F5 | 2,033 | 0.32 / 1.40 | 0.13 / 1.36 |
| C05 | 1,165 | 0.59 / 5.18 | 0.22 / 5.70 |
| C09 | 21,482 | 2.24 / 8.11 | 1.00 / 8.26 |
| X01 | 3,624 | 0.54 / 4.96 | 0.46 / 3.92 |
| P1 | 330,993 | 11.99 / 20.08 | 12.15 / 19.97 |
| P2 | 27,403 | 2.37 / 9.04 | 1.19 / 9.46 |
| P4 | 154,857 | 8.78 / 11.34 | 0.85 / 3.54 |

Hostile designs cost 10–70 × L's: the judge's 4 climbs on A's units (10,000 evaluations each) reached 273 ms for the verdict
(L's worst 30.4), about 0.7 s in Studio. Hence the cap.

**Units and the cap.** The judge found A's units (2 vertex tests a unit) blind to the scan of the shown list, the box tests,
polygon making and model building: 19–350 ns a unit across designs. The build counts all four (Cover's header: a vertex test
0.5, a box test 0.125, a polygon 1 on top of its vertices, a model facet 8 on top of its vertices; dyadic, so a sum is the same
in any order) and pre-sizes each polygon it cuts (P1's verdict 14.9 → 10.9 ms, the same units). Near the cap the build spends
26–33 ns a unit (the 24 designs the climbs kept, re-timed alone), P1 36; under 20,000 units fixed costs dominate (75–506
ns), far from the cap. 4 climbs on
the verdict's wall time (`build/tclimb.luau`; 4,500 evaluations each, 18,000 in all, run 4 at a time; the judge's families of
rod bundles, near copies, wedges, plates, ball clusters, grilles, balls on a plate, rod lattices, and restarts from every
climbed design on record; canonical designs passing V1–V3; units within 700,000) found bundles of 21–24 Cylinders and mixes of
Blocks. Re-timed alone (`build/out/retime_climb700.log`), the slowest verdict is 22.54 ms (694,179 units, 32.5 ns a unit), the
slowest fully valid design's 21.90 (692,796), the highest rate 33.4 ns a unit; the whole exposure at most 31.3 ms;
`Analyze.run` at most 36 ms (median of 15). The heaviest real designs: P1 330,993 units, P4 154,857, the plausible set 136,032
(a C09 under 5 wrap rings), the F, C and X fixtures 21,482 (C09). So `VERDICT_WORK_MAX = 700,000`: P1 2.11 × under it, every
other real design at least 4.5 × (P4 4.0 × with the probe's spread, below), and the slowest design found at the cap 22.5 ms
for the verdict, under the 30 ms the lead set. Past it the exposure stops at the next report (within a few thousand units then; within 256 now, below) and `Analyze.run` answers `TooComplex` in
11–24 ms (median of 15; `worst_designs.luau`: 17 designs of 1.18–15.3 M units; `build/tcap.luau`). A design and its mirror
image can differ by up to about 30 % of their units (V1, below), so one that far under the cap can be valid while its image is
not (§17.2).

**Invariance** (the judge's runs, then `Cover.spec` and `Verdict.spec` on the build). 12,000 permuted runs of 4,000 tangles
and 2,010 of the attack corpus: bit-identical (kept, cleaned, every reading; exact copies compared as a class). 8,000 X / Z
mirror images of tangles: 548 verdicts differ, 545 of them near twins stacked in z that swap which keeps a coincident face,
because the rank took cz directly, and 3 exact ties; the build ranks \|cz\| before cz, as \|x\| before x (§4.4). 1,340 images of
the attack corpus: 0. Exact copies first or last and Dust specks: every other reading bit-identical. A round copy spun or
turned about its symmetry has its original's vertex set; the model of a mirror image is the mirror of the model.

**The measure stays.** On every design whose verdicts the two readings agree on, the build's measure (kept, exposedKept,
contact, surfSamples, subSampled, hSurf) is L's to the bit: 49,019 designs (the fixtures 74, the attack corpus 1,256, climbed
designs 27, all plausible designs 31,686, every 4th of the verifiers' families 15,976; `build/measure_eq.luau`) with L's rank
key; with \|cz\| before cz, 20 differ, every one where that key changes the rank's order. On P1 the reading keeps Giant2 (truly
2.042 %, read 2.042 %), which L cleaned: 9 cleaned parts where L had 10, mass, volume and COM unchanged, volume samples
6,741 → 7,245. On the set as it then stood (33,389 plausible designs, the 4 ported families included) 32,684 designs keep L's
kept rows, and 26 of them measure differently, every one from the rank key. The rank key also moves who owns an overlap within
a slot (§4.3) where no verdict moves: 8 of the attack corpus (`v12/a_sheets`; mass up to +0.27 %, balance +0.0006); and it
moves X01's verdict, whose original blade now ranks above its copies at z ±0.003 and keeps their shared rim: kept, Hammering
0.0764 → 0.0756, the prototype's number (ΔD against the union blade 0.0002; E-S2.11's 0.0010 and 0.0764 were under the rank
before). All of this before the slot came first in the rank (below).

**What the 2 % rule itself admits** (§5.6, §17.2; the r2 verifier's designs, `v12/a_void`, `a_lam`, `a_sheets` in the attack
corpus), through the emulator on the build: a closed box 0.60 × 3.0 × 0.20 with walls 0.02 and a block in its cavity 0.03
clear, Smelting 0.1376 Normal → 0.4463 Hard (the block shows 100 %); a 1.6 × 3.5 × 0.16 blade in 8 flush layers, Hammering
0.0582 Normal → 0.7000 Hard (6 layers cleaned); a core 0.95 wide that shows 11.92 % alone under 14 sheets, the core and every
sheet cleaned.

**Checkpoints.** Cover reports its units every 256 (between polygons) and Sampling each model and look; the median run's
longest stretch between checkpoints over the fixtures and the climbed designs is 0.16 ms (0.11 under L), the worst design's
0.50. `CHECK_UNITS` 250 or 125 does not shorten them (0.57, 0.59): they are allocation and GC, not uncounted work (§17.2).
(Before the verifiers' round; how the reports go now: below.)

**After the verifiers' round** (V1 and V2 on the build above; the fixer's measures with the scripts in `cover/fix/`, Lune
0.8.9; "the build before" is the tree the verifiers read).

*Reach.* A round part's facet probes δ + its sagitta (a Ball's largest 0.0572 r) and a round hider's half-spaces, moved out by
theirs, stand up to 0.0260 r (Ball) or 0.0048 r (Cylinder) past its box; but the build chose hiders, and each facet asked them,
within δ + 2·`EPS_GEOM` of its box, and `CoverBrute` tested boxes the same way, so `Cover.spec` (a) could not see it. V1: a
valid, canonical sword of 23 parts with a Ball d 0.40 in its blade, sealed by 6 walls 0.02 thick 0.002769 off it and 12 edge
blocks; the Ball truly shows 0.502 % and the hide test reads 0.447 %, but the build read 2.345 % and kept it, Smelting 0.1707
Normal → 0.2176 Hard (0.2218 with the Ball as Pommel); a search over 1,800 cages found 17 such flips. Each model now carries
its reach (δ + its largest sagitta) and its over (0.03 r on a Ball, 0.005 r on a Cylinder, 0 on a polyhedron; `Cover.spec` (e)
measures 0.0260 r where the 4 facets round a Ball's axis meet, at most 0.0048 r at a Cylinder's circumscribed 32-gon), Sampling
hands over every part within reach + over + 2·`EPS_GEOM`, a facet asks those whose box grown by its over comes within its own
probe, and the brute force tests no box and takes every part that hides. Against it no part falls outside the ±1e-11 bracket on
12,000 tangles of `Cover.spec`'s kind (64,808 parts) or 6,000 of V1's degenerate ones with every part in a random slot (29,948
parts; `fix/exact.luau`, `exact2.luau`); the build before left 4, 22 and 20 parts outside on 150, 1,500 and 1,500 tangles, up to
0.0042 of a part. The caged sword read 0.447 %, was cleaned, and its D was the truth's (0.000 % with the spread, below). On all 33,389 plausible designs no kept
row moves, and `build/precision.luau`'s output is the same to the byte (447 / 0 / 0, 2.945 %; 0 / 0, 2.002 %); on the attack
corpus no kept row moves and every one is the truth's (19,430 parts).

*The slot first.* V1: under the rank by size, place, half extents and turn, an invisible copy took the blade out of the Blade,
in the build and in the truth, which uses the same rank: F3 + its blade turned 180° about Y or X, its size given as 0.035 ×
3.4 × 0.07 with a quarter turn, or 1e-12 to 5e-8 lower, in the Guard, the Pommel or the Grip, Sharpening 0.6104 Hard → 0.0645
Normal; C08 0.2487 → 0. The rank then went by the slot's name first, a Block's half extents sorted and its volume taken from
them, then the material, then half extents as given and the turn; an exact copy is one of any part above it with the same
centre. Every such copy was cleaned, the blade kept, every other part's measure and D bit-identical (`Verdict.spec`; through V1's
emulator, 0.6104 and 0.2487). What else the slot first moved, against the build before (the second round put the volume
before the slot and gave the measure its own rank, below):
- units, the hiders' order moving the subtraction: P1 330,993 → 235,061, P4 154,857 → 166,945 (the reach too), C09 21,482 →
  21,920, X01 3,624 → 3,504, P2 27,403 → 26,212, F5 2,033 → 1,997; the plausible set at most 113,705 (136,032; under 20 parts
  56,262);
- `worst_designs.luau`: 4 of its 8 valid designs passed the cap (`tclimb_1.json #1` 775,324 units, `tclimb_2.json #4` 857,305,
  `tclimb_4.json #1` 753,793, `#3` 776,808), and so did V1's 4 climbs (719,345–809,665). It is derived again (`fix/cands.luau`,
  `mkworst.luau`, `reemit.luau`): the 8 climbed designs that stay valid (415,185–686,350 units) and V1's cluster of 24 Balls with
  its spacing set at 0.06 (697,683), slowest first; its 17 designs past the cap stay past it (1.11–8.54 M units);
- the measure: where two kept parts of different slots share a face it now goes to the slot whose name comes first, and the
  sub-grid budget goes to the Blade's parts first. 12,547 of the 33,389 plausible designs measure differently (`exposedKept` on
  12,198, the patches sub-sampled on 12,208, contact on none; `fix/digest.luau`), and through the emulator D moves on 7,664 of
  them (`fix/dsweep.luau`): by 0.01 or more on 816, by 0.05 or more on 8 (6 grilles, 2 fullers; a grille's Sharpening 0.0000 →
  0.1769, its Blade bars now keeping the faces they share with Guard and Pommel bars), and 95 tiers flip, 60 of them by under
  0.01 (all 95: fullers 50, laminates 15, ribbed plates 10, bevels 9, others 11). On the fixtures and the 17 attack designs 6 of
  74 move: C09 Hammering 0.3170 → 0.3182 and Sharpening 0.1904 → 0.1826, 5 attack designs by up to 0.0056, no tier. Owned
  volumes move on 4 grilles where no verdict moves (who owns an overlap within a slot, the Blocks' volumes from their sorted
  half extents): mass −0.143 % and −0.102 % on 2 of them, their COM x leaving the mirror plane (−0.00032, −0.00023), the same
  mass swapped between bars on the other 2; the attack corpus measures differently on 1,009 of its 1,340 designs, its mass on
  none. Measured for the lead: with the new keys but the slot in the measure, 33 of the 33,389 plausible designs measure
  differently (the fixer's mutC); with the measure and the overlaps ranked exactly as the build before ranked them, none (V2).

*Reports.* V1: single reports reached 4,206 units and each Ball's model was reported whole (1,216; P4's longest stretch between
checkpoints 0.67 ms under load); V2: a run of polygons kept whole was never reported, 40,093 units at once past the cap. Now a
model reports as it is built, and a reading once `SPEND_EVERY` units have built up, at the next facet, polygon, piece or hider.
Over the fixtures and `worst_designs.luau` the largest single report was then 3,712 units (9,190 with reports at hiders and
polygons alone; 38,082 past the cap without the report in a run of polygons kept whole), and a design past the cap stopped
within 328 units of it. With the machine 15–20 % busy, the median run's longest stretch between checkpoints was 0.12 ms over
the fixtures (the median of their medians; P4 0.40, P2 0.37, C10 0.36), 0.24–0.49 over the worst designs, past 0.35 on 6 of
73 designs (`fix/gaps.luau`; the second round's: below).

*Cost* then (median of 15, every design once a round, the machine 15–20 % busy with other programs; `fix/timing*.luau`; the
second round's: below). The verdict
/ whole exposure: F5 0.24 / 1.32 ms, C05 0.20 / 5.29, C09 1.53–1.61 / 7.20–7.98 (the slowest of the F, C and X fixtures), X01
0.45 / 4.65, P1 9.4–10.3 / 17.1–19.3, P2 2.0–2.5 / 9.2–10.1, P4 8.5–9.4 / 10.8–13.1. The slowest valid design known, V1's
cluster: the verdict 26.3 ms (37.7 ns a unit), the whole exposure 29.7, `Analyze.run` 32.2; the climbed designs at most 31.2 and
41.5 (`tclimb_2.json #5`), 26–35 ns a unit; past the cap `TooComplex` in 12.6–24.1 ms.

*Smaller.* A Cylinder whose axis has its two smallest components equal and not 0 (two 45° snaps) is framed by its axis's last
bits (§4.4): a copy spun about it reads up to 41.8 % where it truly shows nothing (two such Cylinders 0.6 × 0.24 alone, in one
slot, both kept in 33–72 of 180 spins; V1's figure: `fix/a1tie.luau` printed 31.6 %, the second part's shown area in stud²,
which `math.min` took with the two shares), and as a rod 0.5 × 0.08 in the Guard of F5 or F3 with a spun copy 14 of 72 designs
keep a truly hidden part, \|ΔD\| up to 0.0007 with the slot's name first in the measure (0.051 under the rank before, the copy
in the Blade; the second round's: below); V1: the image of such a model is up to 0.0245 off the mirror of the model. A design and its mirror image
differ by up to 26.5 % of their units (`tclimb_3.json #3`, 627,808 → 461,422 under the Z mirror; P4 +6.5 % under X; P1 −0.8 %;
V1 measured 29 % under the rank before), because a reading stops at 2 % in its model's facet order, which an image does not keep
in the world. Of 20,744 part images of 2,000 tangles, 86 verdicts differ from the original's: 84 round copies (V2: 79 of
23,394) and 2 a face exactly `EPS_GEOM` off a parallel one, a tie. Two plates that tie on volume, height and \|z\| swap who keeps
a shared window under the Z mirror (0 % and cleaned, then 3.000 % and kept, the truth agreeing; V1). The conservative probe
under-reads a Ball in a cage of walls its probe reaches by up to 3.8 points (r 0.05, truly 4.52 %, read 0.71 %; r 0.10, 5.55 %
read 1.99 %, cleaned, \|ΔD\| 0.014 in a sword; in a sword r 0.20, 3.59 % read 1.89 %, Smelting 0.2057 Hard → 0.1974 Normal; V1,
by the hide test, which the build reads), and missed hiders beside a facet's patch: below. A part's units count the parts (its look over their boxes:
a Dust speck adds 0.125 a part). V2: on the plausible set a round part strays from the truth by up to 1.5 points (a rib 0.002 of
its diameter proud, true 2.82 %, read 1.29 %), and a Cylinder poking less than its sagitta, 0.0048 r, through a flat face reads
nothing there (a long rib that pokes 0.0048–0.006 r, truly 3.0–3.4 %, reads 0.00 or 1.89 % and is cleaned).

**After the second verifiers' round** (V1 and V2 on the build above; the fixer's measures with the scripts in `cover/fix2/`,
Lune 0.8.9; "the build before" is the build before the first fixer's round, `m2x-fix-1/base`, unless named otherwise).

*The ranks.* V1: burial does not depend on rank, so under the slot first a copy of F3's main blade 2.5e-7 to 1e-4 larger in
every size, in the Guard, the Pommel or the Grip, still buried the blade, Sharpening 0.6104 Hard → 0.0645 Normal (C08's from
2e-7 larger, 0.2487 → 0), and the truth agrees. V2: the slot first let filler buy faces: 4 skins 0.02 thick flush inside F5's
guard, labelled Blade, were kept and took the guard's faces, Sharpening 0.0989 Normal → 0.4201 Hard (relabelling the guard
gives 0.2804; F3 0.6104 → 0.7020); and it moved the measure and mass where no verdict moved (above). Geometry now decides
what shows and a label only breaks exact ties (§4.4): the verdict's rank goes by volume (a Block's from its sorted half
extents), then by the slot's name, then by where a part stands, a Block's sorted half extents, the material, the half extents
and frame as given, the index; the measure and the ownership of overlaps keep the rank of the build before
(`Sampling.measureRanked`). The skins are cleaned (F5 and F3: D their own, `Verdict.spec`); every copy of F3's or C08's blade
of one volume or smaller (exact, turned 180° about Y or X, its size given another way with a quarter turn, 1e-12 or 5e-8
lower, 1e-9 or 1e-4 smaller, in the Guard, the Pommel or the Grip) is cleaned, every other part's measure bit-identical; a
copy 1e-12 to 1e-4 larger in the Guard or the Grip encloses the blade and is what shows, every other verdict as with the blade
relabelled (through V2's emulator Sharpening 0.0645 and 0, the relabelled blades' numbers; `fix2/o8d.luau`). No near-copy
rule: V1's (`COPY_NEAR` 0.001) still let a copy 0.0012 larger move the blade, and 0.01 broke 10 Physics cases. Against the
build before, bit for bit (`fix2/bc` through the previous fixer's `bc.luau`: verdict, measure, mass and report, volume probes):
on all 33,389 plausible designs the verdicts move on 35, all the spread's (below), and the measure, mass and probes are the
same on every other; on the 1,340 attack designs nothing moves; on the 191 fixture-set designs (the 17 past the cap among
them, which `bc.luau` left out until the third round: they move nothing) 2 verdicts move (V1's cluster at
its old spacing, now past the cap; a Cylinder of `tclimb_2.json #5` that truly shows 2.097 %, cleaned by the spread) and
nothing else. C09 is the build before's again: 0.0001 / 0.3170 / 0.1904 (§5.5); in 300 orders Hammering 0.3170–0.3195; C09 +
a plate that shows 20.12 %, kept, Sharpening 0.2542 Hard with 0 or 5 hidden blocks, 0.1904 cleaned (`fix/orders.luau` on the
build). The measure's rank can give a face to a part the verdict keeps though the truth hides it: of a rod whose axis ties in
F3's Guard and its copy spun 55° in the Blade, both kept (the rod truly hidden), Sharpening 0.5845 against the truth's row's
0.6996 through V2's emulator, no tier, on the build and before its spread (`fix/a1d.luau`; 0.0007 with the slot's name first in
the measure). The copy alone still reads up to 41.8 % (`fix/a1tie.luau`).

*The spread.* V1: the conservative probe was conservative only along a facet's normal: the true points of a round facet's
patch probe radially, so a hider beside the patch could be missed. In V1's family of caged Balls (6 walls and 12 edge blocks,
half of them turned) 4 of 1,000 Balls that truly show 1.75–1.95 % read 2.10–2.34 % and were kept, and in a valid 23-part sword
one (r 0.08, truly 1.93 %) took Hammering 0.2020 Hard → 0.1548 Normal (V2's emulator on the build's measure; V1's 0.2053 /
0.1615 on the slot first's). V1's trial grew a round facet's probe pieces and box margin by HIDE_OFFSET × the sine of the
largest angle between its normal and its vertices' radii from the part's centre. On a Cylinder's side that radius runs along
the axis and the sine comes near 1 on a long rod, where the true normals lie within π/32 of the facet's: on the plausible set
it cleans 450 parts more, all truly showing 2 % or more, 186 of them 5 % or more (up to 51.7 %, ribbed bars), and flips 84
tiers (\|ΔD\| up to 0.66; `fix2/fxc.luau`, `fxsum.py`, `fxemu.luau`). The build takes the true normals instead (§4.4: a Ball's
radii, a Cylinder side's radii from its axis, a cap's own): the **spread**, 0.0027–0.0040 on a Ball's facets, 0.0012 on a
Cylinder's sides, which the model's reach takes in and `CoverBrute` builds again from the words. Against VisibleOracle:
- all 33,389 plausible designs: 35 parts more cleaned, every one truly showing 2.0–3.6 % (19 under 2.5 %, 13 under 3 %, 3
  Balls in a pommel housing at 3.6 %; 29 of them wrap rings), no tier flip, \|ΔD\| at most 0.041 (a caged Ball); no kept part
  truly under 2 % before or after; cleaned at 2.5 / 3 / 4 % or more 463 / 3 / 0 (447 / 0 / 0 before);
- the verifiers' 12 families, every 8th (8,016 designs): 2 beads more, truly 4.44 and 7.03 %, no tier, \|ΔD\| 0.033 (V1's
  trial 11);
- the attack corpus: no verdict moves; the 17 attack designs keep the truth's verdicts, the round ones reading up to 4.2
  points under their truth (a bar r 0.15 behind 16 slats 36.49 % against 40.67 %, before 40.26; a Ball d 0.56 in 8 corner
  blocks 44.03 against 47.98, before 47.10), so `Cover.spec`'s round band is 0.05;
- V1's cages, 2,000 (seeds 1, 2, 61, 62): it closes the 5 kept under 2 % (1.75–1.995 %, V1's 4 among them) and cleans 253
  Balls more that truly show 2 % or more, 148 of them 5 % or more, up to 25.9 % (r 0.05), of every radius from 0.05 to 0.25;
  the swords: the round-1 cage (r 0.20, truly 0.502 %) reads 0.000 % (0.447 % before), V1's cage flip 0.000 % (2.330 %),
  cleaned, Hammering the truth's 0.2020 Hard; a cage sword r 0.20 that truly shows 3.585 % reads 0.068 % (1.885 %), cleaned
  as before, Smelting 0.1974 Normal against the truth's 0.2057 Hard.
The lead's rule was to adopt it unless it cleaned a part truly showing 5 % or flipped a tier on the plausible set; it did
neither. It costs units where round facets meet hiders: on 21,132 of the plausible designs (the heaviest 138,520 → 125,174, a
C09 under 5 wrap rings; the largest rise ×1.54 on a small design), P2 26,212 → 26,422, P4 166,945 → 175,199, C09 22,008 →
21,954, and V1's cluster at spacing 0.06 passed the cap (734,399 uncapped). `worst_designs.luau` is derived again
(`fix/cands.luau`, a `mkworst.luau` taking the spacing, `reemit.luau`): the cluster at 0.0614, 691,272 units, and the 10
climbed designs that stay valid (418,625–680,325; `tclimb_1.json #1` at 718,455 and `tclimb_4.json #3` at 725,627 pass the cap,
as do V1's 4 climbs, 721,509–782,138); its 17 designs past the cap stay past it (1.24–15.0 M units).

*Reports.* V1: a piece was built whole, so a Cylinder's cap clipped by most of a small Ball's 128 lines made one report of
5,362 units (5,047 in a valid sword), and `within`, `apart` and the projections charged their cost up front. Now each line
clipped or split, each line or edge tested and each half-space projected reports once `SPEND_EVERY` has built up, a test that
ends early charging the lines it skipped with its last, and the reading reports nothing after the report that passes its
budget; the units are the same to the unit on all 33,389 plausible designs. The largest single report over the fixtures, the
attack designs, `worst_designs.luau` and V1's two caps under a Ball is 3,570 units (that charge; the caps now under 1,100),
and every design past the cap stops at most 256 units past it (`fix2/reports.luau`, `uncapped.luau`). With the machine 5–20 %
busy the median run's longest stretch between checkpoints is 0.107 ms over the fixtures (the median of their medians; P4
0.371, F4 0.27, P1 0.26, P2 0.26), 0.15–0.29 over the worst valid designs, 0.09–0.14 past the cap; past 0.35 on 1 of 75
designs (`fix/gaps.luau` on the build).

*Cost* (median of 15, every design once a round, the build and the build before the spread in turn, the machine 2–14 % busy
with other programs; `fix2/timing.luau`, `fix/timing3.luau`). The verdict / whole exposure / `Analyze.run`: F5 0.36 / 1.42 /
1.82 ms, C05 0.22 / 5.10 / 6.23, C09 1.64 / 7.58 / 8.73 (the F, C and X fixtures at most 1.54 / 7.09, C09), X01 0.41 / 4.54 /
6.05, P1 11.83 / 19.43 / 23.89, P2 2.19 / 9.07 / 11.83, P4 10.32 / 13.31 / 14.65 (before the spread 8.82 / 10.55 / 13.12).
V1's cluster 31.72 / 34.01 / 36.33 (45.9 ns a unit; at the same spacing before the spread, 672,369 units, 25.15 ms); the
climbed designs at most 24.03 / 32.89 / 37.95 (`tclimb_3.json #6` the slowest `Analyze.run`), 28–37 ns a unit; past the cap
`Analyze.run` answers `TooComplex` in 10.9–27.0 ms.

*Smaller.* V1: a Ball that pokes through flat faces by less than its model's depth there reads nothing there (the model lies
up to 0.0572 r under the sphere along (1, 1, 1)/√3, 0.0474 r under it along three perpendicular directions at once): a Ball r
0.10–0.20 set 0.046 r through a turned block's corner truly shows 6.885 % (3 faces) or 4.578 % (2) and reads 0; in F5 with its
pommel a turned cube 0.34 and a Ball r 0.10 at its corner or edge, truly 2.50 / 4.56 %, \|ΔD\| 0.0000 in the Pommel, 0.0047
(Sharpening) in the Blade. A round hider's probe half-spaces stand up to 0.026 r past its true surface at a Ball's axis tips,
so a plate framed but for a window 0.05 wide under a Ball r 0.3 whose bottom is HIDE_OFFSET + 0.0005 above it truly shows
3.905 % and reads 0.079 % (V2: a plate 0.10 under a window 0.06, truly 12.857 %, reads 1.612 % under a Ball d 0.6 hovering
0.0125 over it). A regular sword of 24 rods 0.12 thick, every part showing, spends 471,362 units (482,821 under the slot
first; `h_bundle.json`), 1.49 × under the cap, and V1's honest variants of it pass the cap (`pastcap_32…34.json`). Every Block
described another way (X and Y sizes swapped, a quarter turn about its Z) keeps every verdict and moves the units: P1 330,993 →
320,332 (−3.2 %), C09 21,954 → 18,880 (−14.0 %), `tclimb_3.json #4` −3.2 %, F5 2,033 → 3,458 (V1's `c_redescribe.luau`). A
design and its mirror image: P1 −0.5 % under either mirror, P4 +4.0 % under X, `tclimb_3.json #3` −27.3 % under Z, and
`tclimb_4.json #1`, valid at 680,325, is `TooComplex` at 722,733 under X (`fix/mirror_units.luau` on the build). A28 spends
1,066,374 units uncapped (E-S8.4).

*Tests* added by the round (V1's mutation run: 830 line mutants of Cover and of Sampling's rank, copy check and verdict loop,
104 survivors, the ones that change behaviour killed by these): every report of a model and a reading sums to its work (C09, F3);
a Cylinder's 32-gon starts from Y across an axis along X or Z, from X across Y; a Block's rank volume comes from its sorted
half extents, and a Wedge of 1.02 stud³ ranks before a Block of 1; Sampling's kept row is the one every part asked gives (a
Block walled 0.005 off on 5 sides and HIDE_OFFSET − EPS/2 on the 6th; the framed plate under a Ball's tip); a design past the
cap reports nothing after the report that passes it (of the reading's 15 stops, dropping 4 makes it report again and fails it;
dropping any of the other 11 runs on less than `SPEND_EVERY` units, unreported, to the next stop, which no report can show;
`fix2/mutstop.py`); no single report over 4,096 units (V1's caps under a Ball included). V2:
Sampling hands over a round hider within its over (a Ball hovering 0.015 over a window in the lids: the plate reads 1.280 %,
cleaned); P1's exempt measure pinned (area 15.870818…, contact 1196.9545, 58 patches sub-gridded, hOverlap 0.2, 6,940 refined
cells); the flush plates in the Blade itself; `Cover.spec` (d)'s mirror images one case a plane; `Limits.spec`'s 6
ValidationCodes. The round: the skins and the guard in two halves, the hair-larger copies, the caged-Ball swords (both read
0.000 %), the spread on the models against the brute force's.

**After the third verifiers' round** (V1 and V2 on the build above; the fixer's measures with the scripts in `cover/fix3/`,
Lune 0.8.9; "the build before" is the tree the verifiers read).

*The band.* V1: a part wholly inside a Ball or a Cylinder, against its true surface, lies in its model's band, between the
inscribed facets and the true surface (up to 0.0572 r deep along a Ball's (±1, ±1, ±1), 0.0048 r under a Cylinder's sides),
where the hider's inscribed half-spaces leave it showing though the truth buries it. F5 with its pommel a Ball 0.6 across and
4 Blade Blocks 0.1 × 0.2 × 0.1 along (1, ±1, ±1)/√3, their outer faces 0.011 under the sphere: 10.000 % each, kept,
Sharpening 0.0989 Normal → 0.2169 Hard; 4 Blade Balls r 0.1, 0.002 under it, 3.278 %, 0.2958 Hard; 4 Blocks in each of F3's,
C04's and C09's own pommels 4.4 % (F3's Sharpening 0.6104 → 0.5238); a plate 0.0003–0.001 under a Cylinder r 0.3's side
20.3–29.3 % (`fix3/e1_band.luau`). The lead's decision, V1's trial: a flat facet's buried piece takes a round hider's
half-spaces moved out to its true surface, as the probe's do, and a round facet whose hull (its vertices and each pushed out
to the plane parallel to it that the true solid touches; a cap's circumscribed 32-gon) lies in a round hider's true solid, as
the buried or coincident piece asks, is hidden whole; `CoverBrute` builds both from the words. That hull stands out of the
true patch by the patch's own sagitta (up to 0.0607 r on a Ball's facets), so it hides a facet only well inside: over 1,800
Balls in Balls, 3,050 Cylinders in Balls and 4,050 rods along Cylinders (half of them turned 0.5°: the script turned them 1°
until the fourth round, so that they poked 0.004 out, and its logs are run again), all 0.0002–0.02 under the true surface
(`fix3/e2_inside.luau`), 146, 2 and 132 still read 2 % or more (up to 5.4 %, 2.4 % and 5.6 %; truth 0), and in F5 and F3
(`e4_open.luau a`) 7 of 57 swords keep a tier the truth's row does not: 4 Blade Balls r 0.1 0.0002–0.001 under the pommel's
surface read 3.4–3.6 %, Sharpening 0.2961–0.2964 Hard, r 0.15 up to 0.002 under it 2.5–4.4 %. So the build adds the part's
own test: a round part whose true solid lies in a round hider's, as the buried or coincident piece asks, shows nothing. Its
farthest point from the hider (`Cover`'s `farthest`): a Ball's is its centre's `Shapes.sd` + r, exactly, against either; a
Cylinder's in a Ball `Shapes.maxDist` (since the fourth round the farthest point of its cap circles, below), exactly; a
Cylinder's in a Cylinder its support along the axis and its caps' centres' distance from the axis + r, exact for parallel
axes and above it otherwise (by r·(1 − cos of their angle) at most; since the fifth round the farthest point of its cap
circles from the axis, exact at any tilt, below). `CoverBrute` reads it by `Shapes.sd` at the points of the part that stand
farthest out. Then none of the 8,900 reads 1 % (the base up to 9.0, 4.9 and 8.9 %, the last an untilted rod r 0.08 in a
Cylinder r 0.8, 0.0002 under its side) and the 57 swords are the truth's rows; the 4 Balls 0.0002 under the pommel read 0.000
%. It also hides a round copy coinciding with a higher part's true solid whose model differs: V1's copies spun about a tied
axis read 0 (41.8 % before for two 0.6 × 0.24 rods, 47.3 % for 1.0 × 0.12; `tieaxis.luau`), and `fix/a1d.luau`'s rods in F3's
Guard keep no truly hidden copy (14 of 72 spins before; the Sharpening 0.5845 against the truth's row's 0.6996 is gone;
`a1d3.luau`).

*What is still open against round hiders* (`e4_open.luau`, `e5_pokeround.luau`, `e6_roundpoke.luau`; the truth by
VisibleOracle, D through V1's emulator on each tree's measure). A flat filler straddling a round hider and another part
(Blocks against F5's big pommel half under its grip): its band piece is buried; where its corners stand out of the pommel's
true surface (up to 0.005), the price below (on the circles of the fourth round, within 0.3 points of the truth). Round
filler where a round part meets another part, truly hidden (every point of it at least 0.002 inside one of them), reads its
facets in the round part's band too (V1, the fourth round, on the build after it: `crease_flip.luau`, `union_search.luau`,
`c09_rods.luau`): 4 Blade rods r 0.043 × 0.137 where F5's grip enters that pommel read 6.57 % each and are kept, Sharpening
0.1827 Normal → 0.2083 Hard with the blade 0.25 longer (the truth's row 0.1827); Balls there read up to 4.8 %, rods in C09's
grip reaching into its guard 2.4 % (Sharpening 0.1904 → 0.1664, no tier), Balls in the crease of two pommel Balls or of a
pommel Ball and a grip Cylinder up to 2.7 and 2.8 %, all kept and truly 0. The 2.044 % of one Ball "straddling" the pommel
and the grip (1 of 15, \|ΔD\| 0.010) was read on V1's trial alone, without the part's own test: those 15 Balls lie wholly in
the pommel and read 0 on the build, and in the crease of two pommel Balls at most 1.218 %. A round filler that pokes a hair
out of a round part's true surface reads the facets that cross it in the band, buried by the truth: F5 + 4 Blade Balls r
0.06–0.15 in the big pommel, 0.0001–0.002 out (truly 0.06–1.5 % each), read 2.0–7.1 % and are kept (110 parts), 12 of the 33
swords in the hitbox (the other 12 of the 45 are `OutOfHitbox`) keeping a tier the truth's row does not (Sharpening 0.0989
Normal → up to 0.2965 Hard), as in the build before (V2: r 0.06–0.15 along (1, ±1, ±1)/√3, 16 of 20, up to 0.3284 Hard at r
0.12; in 80 swords with Balls in random directions of the pommel's upper half, 0). Of 1,440 Balls and rods poked 0.0002–0.03
out of a Ball or a Cylinder alone (r 0.15–0.8), 159 truly under 2 % are kept and 20 truly 2 % or more cleaned. Two rules were
tried. A round facet's buried piece on the moved half-spaces too wherever a vertex of it lies in the round hider (deeper than
`EPS_GEOM`; a round copy coinciding with it, or a round part round it, has none, so it keeps its faces): no poke kept that
truly shows under 2 % (the 12 swords the truth's), but 170 that truly show 2.0–7.7 % cleaned, 3 swords keeping a tier the
other way (4 Balls truly 2.6–3.0 % each), F3's rods along its grip poked 0.0001 out (truly 3.4–3.5 %) cleaned (\|ΔD\| up to
0.20, no tier), and on the plausible set a ball rivet set in F3's guard Ball that truly shows 6.32 % read 1.17 % and cleaned
(`ballRivet|F3|guardX d0.10 cap0.3000`, its 4 turns, Hammering 0.4493 → 0.4423, no tier: the rivet lies within the guard
Ball's over of its surface where the two cross at a shallow angle); units P4 +19 %, P2 +11 %, V1's cluster past the cap
(700,079; `rivet.luau`, `bc.luau`). A round facet hidden whole when its vertices alone lie in it: 23, 1 and 18 kept in the 3
families of pokes that move, 12, 19 and 2 cleaned (truly up to 3.9 %), 5 of the 33 swords keeping a tier the truth's row does
not, either way (V2: no verdict moves on the plausible set, P4 −3.4 % units). Neither is adopted (§17.2); a finer model
narrows the band (above: a Cylinder of up to 128 sides and a Ball grid of 6–8 halve it, at 2–6 × the cost).

*The price of the buried piece moved out* (`e3_poke.luau`: a Block a × 0.2 × a whose top stands e out of a round hider's true
surface, the rest inside, e from 0.05 to 1.25 of the hider's over). Balls of a sword's size (r ≤ 0.3): a Block 0.04 wide out
of the pole (where 4 moved half-spaces meet 0.026 r out) by 0.0004–0.004 at r 0.3 truly shows 5.1–6.7 % and reads 0–1.9 %, by
0.0003–0.0013 at r 0.2 5.3–5.7 % and 0.7–1.9 %, cleaned; between the pole and an octant's middle by 0.0003–0.0004, 5.1–5.3 %
read 1.3–1.7 %; across an octant's middle, where the moved half-space touches the sphere, the reading is the build before's;
wider Blocks keep (0.075 wide, truly 9.4 %, reads 3.2 %; 0.1, 12.4 %, 7.7 %). A Cylinder's side across a 32-gon vertex (0.0048
r out): r 0.3 by 0.00007–0.00014, truly 4.8 %, reads 1.5–1.9 %; r 0.8 (along Z, the largest a sword holds) by 0.0002–0.0019,
truly 4.7–5.5 %, reads 0–0.05 %. Past a sword's hitbox the price grows with the over (Balls r 0.6–3: truly up to 33.6 %, read
0, 5.7 % before through the probe; Cylinders r 1.5–3 up to 13.0 %). In swords (`e4_open.luau b`): Blocks against F5's big
pommel half under its grip, their corners up to 0.005 out, truly 2.9–11.7 %, read 0.005–1.8 %, \|ΔD\| up to 0.012, no tier. On
the 33,389 plausible designs, the 1,340 attack designs and the 193 fixture-set designs no verdict moves (below). V1: the probe
is conservative but for a hider that ends within a facet's sagitta past the true probe (`m2x-v1-3/cap2.luau`): a Ball r 0.3
buried but for a top cap 0.004–0.008 high under a Wedge 0.013–0.015 thick over the pole reads 0.11–0.22 % where the truth
reads 0.00–0.09 %, no verdict. V2: the spread grows a hider's half-spaces round its corners and edges past both box tests'
margins (up to √3 × (spread + `EPS_GEOM`) past a Block's corner): a Block turned corner-down 0.0013–0.0021 past a Cylinder
side's probe reads up to 1.3e-6 stud² (0.0003 %) more than the brute force, no verdict (`m2x-v2-3/corner_probe2.luau`).

*The Wedge.* V1: a Wedge (sx, sy, sz) is the same solid as (sx, sz, sy) half turned about its local (0, 1, −1), the world
vertices bit-identical, but `Shapes.prepare`'s 4·hx·hy·hz rounds the two an ulp apart (of 10,000 random sizes the other
writing larger on 1,725, smaller on 1,802), and the rank compared the volume before the slot's name: F4 + its tip described
the other way in the Guard, the copy kept and the tip cleaned, Sharpening 0.3420 Hard → 0.1814 Normal; C08 0.2487 Hard →
0.0076. The rank takes a Wedge's volume from hy and hz in order (`Verdict.spec`: the three tips, and a Wedge 0.1 × 0.058 ×
0.098 whose Shapes volumes differ by an ulp). The other shapes: a Block's 24 writings tie on its sorted half extents; a
Cylinder's and a Ball's volume is their radius's and length's whatever the frame or the larger size; a CornerWedge has one
writing, its apex over one corner of its one rectangular face, which no turn of the frame keeps.

*Bit for bit* (`fix3/bc.luau`, `bcsum.py`: per design the verdict row, hSurf, surface samples, sub-sampled patches,
exposedKept, contact, the mass report and owned volumes, the volume probes, the verdict's units and the measure's order), the
build against the build before: on all 33,389 plausible designs, the 1,340 attack designs and the 193 fixture-set designs (the
17 past the cap included) no verdict, measure, mass or probe moves; units move on 21,070, 1,199 and 57 of them (on the
plausible set 18,976 up and 2,094 down, the most ×1.99 on a caged Ball, 11,465 → 22,839, its walls' faces cut against the
Ball's moved half-spaces; the plausible set's heaviest 125,174 → 109,405, a C09 under 5 wrap rings: the part test hides a
round part that lies in another whole, before its facets are read, 84,086 with the hull test alone on another of them where
the build before spent 82,966; the heaviest of every 4th under 20 parts 55,970 → 59,018). `fix2/bc.luau`, given
`Worst.tooComplex` (it looked for `Worst.capped`), counts 191 of round 2's fixture-set designs and the same 2 verdicts
(above); on the set as it now stands, 193 and 1 (V2).

*Units* (uncapped, `units2.luau`), the build before → the build: P1 330,993 (its images 329,190), P2 26,422 → 27,108, P4
175,199 → 172,903 (its X image +3.5 %, +4.0 % before), C09 21,954 → 21,851, F3 11,362 → 13,504 (its guard Block against the
guard Balls' moved half-spaces), F5 2,033; V1's cluster 691,272 → 687,304, the climbed designs 370,029–655,542 (`tclimb_1.json
#5` 495,062 → 370,029, its round parts and facets hidden whole), every one under the cap; the 17 past it 1.23–15.0 M; A28
1,066,374 → 1,083,869 (E-S8.4); V1's regular sword of 24 rods (`h_bundle.json`) 471,362 → 471,161 and its 3 honest variants
770,936, 761,149 and 826,152, past the cap as before. Mirror images: `tclimb_3.json #3` 655,542 → 475,890 under Z (−27.4 %),
`tclimb_4.json #1` 638,320 → 685,385 under X (+7.4 %; no longer past the cap). Every Block described another way: P1 −3.2 %,
C09 +7.6 % (−14.0 % before), `tclimb_3.json #4` −4.0 %, F5 +87 %, C05 +689 % (+308 % before; 1,165 → 9,195 units). The largest
single report over the fixtures, the attack designs and `worst_designs.luau` is 2,335 units (3,570 before, from `tclimb_1.json
#5`, whose round parts and facets are now hidden whole; `fix3/reports.luau`). `worst_designs.luau` keeps its designs, every
valid one under the cap: its units and Lune ms again, the valid ones slowest first (`fix3/reunits.py`).

*Cost* (`fix3/timing.luau`, median of 15, every design once a round on each tree in turn, the machine 1–6 % busy): the verdict
/ whole exposure / `Analyze.run` on the build before → the build: F5 0.22 / 1.29 / 1.63 → 0.25 / 1.32 / 1.72 ms, F3 0.82 /
1.48 / 1.80 → 0.90 / 1.65 / 2.01, C09 2.04 / 6.95 / 8.13 → 1.70 / 7.10 / 8.42, P1 11.02 / 18.58 / 22.19 → 11.00 / 18.35 /
22.13, P2 1.76 / 8.88 / 11.50 → 2.32 / 8.79 / 11.89, P4 9.64 / 11.37 / 13.92 → 10.09 / 12.02 / 14.78; V1's cluster 28.96 /
32.74 / 34.25 → 30.16 / 32.31 / 34.67 (43.9 ns a unit); the climbed designs at most 21.43 / 30.76 / 35.98 (29–35 ns a unit;
`tclimb_3.json #6` the slowest `Analyze.run`); past the cap `Analyze.run` answers `TooComplex` in 10.8–24.3 ms. The hull test
and the part test charge a vertex test's units a point and a part, `UNITS_PER_TEST`.

*Tests* added by the round: the band (F5's big pommel with 4 Blocks, or 4 Balls 0.002 and 0.0002 under its surface: cleaned,
F5's measure bit-identical) and a plate and a rod under a Cylinder's side (read 0), in `Verdict.spec`; the Wedge's tips
described the other way and the rank's tie (`Verdict.spec`); a copy spun about a tied axis reads 0 (`Cover.spec` (c)); every
round facet's hull, its points pushed out onto the planes the true solid touches (`Cover.spec` (e)); V1's three stops at the
budget, kill 16 of 83 surviving Cover mutants by V1's count (a reading entered past the budget does nothing; a plate ringed by
20 Balls reports in stretches of `SPEND_EVERY` and one step; a reading stops at the first report past its budget whatever step
passes it); the blade copies' strip to its closed form, (2·2.6 + 0.16)·0.002 / area to 1e-9 (V2). `VerdictPrecision.spec`
cleans nothing that truly shows 4 % (V2: 3 Balls in pommel housings truly 3.595–3.615 %, read 1.939 %, cleaned since the
spread, failed 3 % under the seeds 0x0000002A and 0x600DCAFE); it passes on the default seed and on 0x0000002A, 0x600DCAFE,
0x31415926, 0x27182818 and 0x55AA55AA (the five runs together, about 70 s each). The plausible set's highest cleaned true
share and lowest kept are unchanged: no verdict moves.

**After the fourth verifiers' round** (V1 and V2 on the build above; the fixer's measures with the scripts in `cover/fix4/`,
Lune 0.8.9; "the build before" is the tree the verifiers read).

*What they found.* V1: round filler where a round part meets another part, truly hidden, reads its facets in the band (4
Blade rods where F5's grip enters its pommel made a Ball 0.6 across, 6.57 % each, Sharpening 0.1827 Normal → 0.2083 Hard),
and the third round's 2.04 % for such a Ball was read without the part's own test; and the price of the buried piece on a
round hider's moved half-spaces was understated: on a Ball they stand up to 0.0452 r past the sphere where three or more meet
off its axes (0.026 r is their over past its box), so of 440 Blocks poked out of a Ball r 0.3, 91 that truly show 2 % or more
were cleaned (up to 17.3 %), and 4 studs in a sword, truly 16.2 % each, were cleaned and Sharpening went 0.2047 Hard → 0.1907
Normal. Minors: of two writings of one Wedge in one slot the writing chose the material kept (V1's fixW2); rule A's Cylinder
in a Ball took `Shapes.maxDist`, which on the rod's axis line leaves the square root of rounding, about 1e-9 (fixD);
`CoverBrute`'s `away` took a part across the axis of 1e-17 for a direction, and a Cover.spec case kills 11 of 22 surviving
mutants of rule A. V2: §5's exception had no Decision mark; 12 of the fixer's 45 swords were `OutOfHitbox` (12 of 33 valid
move a tier); the rule of the vertices alone moves no plausible verdict (P4 −3.4 % units), the witness the 4 rivets (P4 +18.8
%); stale numbers and notes (below).

*Decision 1: a flat facet against a Ball reads its sphere.* A flat facet (a polyhedron's face, a Cylinder's cap) against a
Ball takes for each piece the circumscribed 32-gon of the circle that its plane, or the probe's δ further along n, cuts from
the true sphere (R ± `EPS_GEOM` as the buried test asks, R + `EPS_GEOM` for the probe), about the foot of the centre: 32
lines on §4.1's directions in a frame from the facet's normal and the world alone (`Cover`'s `across`: the world axis most
across n, Y, then X, then Z, components within `AXIS_TIE` = 1e-9 tying, made square to n; v = n × u), none where the plane
misses the sphere, charged as 32 of the Ball's half-spaces. A Cylinder keeps its prism for a polyhedron's facet (0.0048 r),
and a round model's facets keep everything they had, a cap's against a Cylinder too. A cap is flat and takes the circle too:
the inscribed piece keeps the faces of a round copy where it coincides with its hider, and of a round part round it, but no
sphere coincides with a cap and a Cylinder round a Ball has its caps' planes past it; on the three sets it moves 14 plausible
verdicts, all to the truth: the grips of wrap-ring swords, their lower caps against the pommel Ball, truly 2.13–2.97 %, read
1.75–1.96 % and cleaned, now 2.01–2.22 % and kept, D the truth's row's (`moved.luau`; 8 of them were among the 463 cleaned at
2.5 % or more); without the caps no verdict moves on any set. `CoverBrute` reads the circle by its own arithmetic (v = n ×
the axis made a unit, u = v × n; each side a half-space across the plane, w·x ≤ w·C + ρ; `shift` grows the sphere) and
decides flat facets by their index, `Cover` by a facet's `flat` (a one-facet model keeps it).

*The 32-gon* (`circle.luau`): what a Ball r 0.3 hides of a plate's top 2.4 r wide at height h over its centre is the
circumscribed 32-gon of its circle, to 5e-13 at every h from −0.99 r to 0.999 r; its corners stand past the sphere 0.0048 R
through the centre, 0.0044 R at 0.3 R, 0.0036 R at 0.5 R, 0.0025 R at 0.7 R, 0.0009 R at 0.9 R, 0.0001 R at 0.99 R, within
`OVER_BALL`, and it holds the inner ball's circle, so the box tests and the inner-ball shortcut stand (`exactc.luau`: 1,200
clusters of Balls cut by Blocks, Wedges, CornerWedges and Cylinders, faces at 0, ±`EPS_GEOM`, ±1e-9, ±1e-6 and `HIDE_OFFSET`
± `EPS_GEOM` from a sphere, both ranks, 13,084 parts: the brute force's reading to 3.6e-13 of a part, no tie to bracket; the
Physics suite's tangles and the new cases as well). Its frame: a Block written another way and its images across X and Z read
the same against a Ball to rounding, two 45° snaps included (Cover.spec (e); with the tie taken exactly, as a Cylinder's
circle takes it, the image across Z of a Block so turned reads 4.6e-6 of it more, its normal's last bits picking another
axis); V1's `c_writing.luau` (2,300 tangles, 14,833 parts written another way) moves no verdict but 66 twin swaps,
`c_mirror4.luau` keeps every verdict but the 10 round copies coinciding on the model of 4,680 images (V1's count) and a twin
pair of the old tangles (the build before the same), and `c_order.luau` none in 4 orders of 300 tangles.

*Its measure* (the truth by VisibleOracle, D through V1's emulator on each tree's measure; the build before → the build).
V1's studs (`stud_price.luau`): 1.73–1.75 % → 15.79 % each, kept (truly 16.18 %), Sharpening 0.1907 Normal → 0.2047 Hard, the
truth's row's (blade +0: 0.0989 → 0.1195, the truth's); in Verdict.spec. V1's radial pokes (`poke_sweep.luau`, 440 Blocks
0.03–0.1 wide 0.002–0.045 r out a radius): cleaned truly 2 % or more at r 0.2, 0.3, 0.5, 1, 2 and 3: 27, 91, 188, 270, 307
and 320 (up to the whole Block at r 3) → 0 at every r; kept under 2 %: 0 on both. fix3's `e3_poke.luau` on Balls (315 Blocks
at a pole, an octant's middle and between, r 0.2–3): 44 verdicts move, all to the truth, none cleaned truly 2 % or more (the
pole Blocks 0.04 wide, truly 5.1–6.7 %, read 0–1.9 % → within 0.2 points of it). Blocks poked out by a corner 0.0001–0.006 r
in random directions (`pokerand.luau`, about 400 a radius): r 0.2 and 0.3 none cleaned truly 2 % or more on either, r 1 3 (up
to 4.8 %) → 0, r 3 78 (up to 18.7 %) → 25 (2.0–3.4 %). The 32-gon's corners in planes near the centre (`pokeplane.luau`,
Blocks laid with a face in a plane 0–0.3 r from the centre, poking out up to 0.0048 r at a corner of the 32-gon or a side's
middle, 288 or 540 a radius): cleaned truly 2 % or more at r 0.2 156 (up to 5.7 %) → 0, at r 0.3 298 (up to 5.9 %) → 14
(2.0–2.1 %), at r 1 283 (up to 8.4 %) → 18 (up to 2.9 %), at r 3 264 (up to 17.2 %) → 8 (up to 5.2 %); kept under 2 %: 0. Not
the worst place (the fifth round, below: climbs with several faces poking out near corners of their 32-gons, in planes
0.15–0.75 R from the centre, find 2.40 % at r 0.3 and 9.63 % at r 3). V1's band designs (`bands.luau`, V2's `e1v.luau`): F5's
big pommel with 4 Blocks 0.011 under its surface or 4 Balls 0.002 and 0.0002 under, 4 Blocks in F3's, C04's and C09's
pommels, the plates under a Cylinder's side: 0.000 % on both, cleaned, D the fixtures' own. Blocks straddling F5's big pommel
and its grip (fix3's `e4_open.luau b`), truly 0.36–11.7 %: 0–1.84 % → 0.29–11.47 %, D the truth's row's on all 15. V2's
window plates under a Ball hovering 0.0121–0.014 over them (`flatband.luau`): each reads its window whole, its truth (12.857
% where it read 1.612 %), and the framed plate under a Ball r 0.3's tip reads 3.906 % (`framed.luau`; truly 3.907 %, 0.079 %
before), so Cover.spec (c)'s two designs at the edge of the box tests now hover a Cylinder (1.679 % and 1.629 %, cleaned,
truly 2.050 % and 3.907 %). Unchanged, the Cylinder's prism: a plate 0.06 × 0.1 × 0.4 0.0005–0.001 out of a round guard r 0.8
across a 32-gon corner, truly 17.80–18.14 %, reads 0–0.53 % (`poke_cyl.luau`; a thin one far more, anywhere on the side: the
fifth round, below), and `e3_poke.luau` on Cylinders cleans 33 truly 2 % or more (up to 13.0 % at r 3); a round facet's probe
still meets a Ball's half-spaces moved out, 0.0452 r past its sphere (`over_poly.luau`).

*O9* (§17.1, **[Decision to confirm]**): what is left of the band, on the build. (a) Round filler a hair out of a round part
or where it meets another part: V2's `e5v.luau` along (1, ±1, ±1)/√3, 16 of 20 swords move a tier (Sharpening up to 0.3284
Hard at r 0.12 against the truth's 0.0989; every one of r 0.08 or more; 76 parts kept that truly show 0.06–1.5 %, read
4.0–7.1 %), in random directions of the pommel's upper half 3 of 240 (seeds 1–3: 3, 0, 0; up to 0.2032 Hard; 880 parts kept
truly under 2 %; V2's 80 are seed 3's), the build before the same; V1's crease rods 6.574 % each, Sharpening 0.1827 → 0.2083
Hard (`crease_flip.luau`); V1's `union_search.luau` with V1's seeds: Balls where F5's grip Block enters that pommel up to
4.770 % (79 kept truly under 0.001 %), rods there 6.576 % (4 kept, 23 before: their caps read the pommel's sphere now), Balls
where a grip Cylinder enters it 2.762 %, rods in a grip Cylinder into a guard Block 2.515 %, Balls in the crease of two
pommel Balls 2.704 %; C09's rods in its grip 2.396 %, Sharpening 0.1904 → 0.1664 (`c09_rods.luau`). (b) Flat faces: above.
The rules tried, ported to the build (`p_witness.py`, `p_vertices.py`, `bc.luau`): the witness moves exactly the 4
`ballRivet|F3|guardX d0.10 cap0.3000` rivets and costs P4 +18.80 % (205,402 units), P2 +11.3 %, and V1's cluster passes the
cap (700,078.5); the vertices alone move no plausible verdict, P4 −3.43 % (166,972.375), P2 −1.1 %, the cluster −5.1 %. V1's
`fixP`, a hull test on the polygons a round facet has left after every hider (on the build before; not adopted, §17.2): the
crease rods read 0.000 %, no plausible verdict moves, units +0.16 % (at most +2.7 % on one design; C09 21,851.25 → 21,881.5),
but crease Balls still read up to 4.41 %, rods 3.86 % and the crease of two Balls 2.68 % at truth 0, its result depends on
how the subtraction fragments a facet, and `CoverBrute` would need the same rule.

*The minors.* fixW2: a Wedge's rank keys h2 and h3 from hy and hz in order, so of two writings of one Wedge in one slot the
material decides, as for a Block (`wedge_mat.luau`: F4 + its tip written the other way in the Blade in the other material,
the Iron one kept both ways and the mass 3.230320 both ways, where the Steel tip was kept, 3.229776; in Verdict.spec). fixD:
rule A's Cylinder in a Ball from its two cap centres, its distance across the axis taken by its parts (V1's 52 strict-tie
misses on 2,500 tangles → 0). `CoverBrute`'s `away` takes a part across the axis of 1e-9 or less as rounding, and V1's
Cover.spec (a) case reads round parts a hair inside and out of round hiders. V2's text: 8.9 % for the base's rods in
Cylinders, §16.10's units row, §4.9's C09 at most 1.7 ms (1.58 on the build), §17.2's other-writing bound (F5 +96 %, C05 +689
%, on the build), README's Status (S-PAR-01 passed 3 fresh Play sessions of the test place on 2026-11-14) and its Layout's
golden line, the cover README's notes on `e1_` and the `p_*.py`, `e2_inside.luau`'s rotation (its tilted rods turned by their
tilt; `e2_cylInCyl` and `e2A_cylInCyl` again: V1's trial alone 132 of 4,050 at 2 % or more, up to 5.62 %, the build 0, the
base up to 8.884 %, the numbers above corrected), the test names and comments.

*Bit for bit* (`bc.luau`, `bcsum.py`; the designs from the build before; 4 trees: the build before, it with fixW2 and fixD
alone, the circle without the caps, the build): the minors move nothing on any set, not even units; the circle without the
caps moves no verdict, measure, mass or probe on any of the 33,389 plausible, 1,340 attack and 193 fixture-set designs (the
17 past the cap included), only units; the caps move the 14 plausible verdicts and those designs' measures, mass and probes,
and nothing on the corpus or the fixtures. Units move on 10,364 plausible designs (10,309 down, 55 up: −66.6 % on a caged
Ball, 22,839 → 7,633, its walls' faces cut on 32 lines, not 128; at most +5.0 %, a wrap-ring sword; −9.8 % in all), on 803 of
the corpus (all down) and on 87 of the fixture set (86 down; a design past the cap stops 16 units later). The plausible set's
heaviest 109,405 → 104,573 (a C09 under 5 wrap rings), every 4th under 20 parts 59,018 → 56,666. No design crosses the cap.
The build against the tree the measures above ran on (a cap told by its facet's index, before the model's `flat`): nothing
moves on any of the three sets, not even units (`bc_final`).

*Units* (uncapped, `units2.luau`), the build before → the build: P1 330,993 (its images 329,190), P2 27,108, P3 8,354, P4
172,903 (its X image +3.5 %), C09 21,851 → 17,512, F3 13,504 → 10,973, F5 2,033 → 1,793, P5 2,973 → 2,733; V1's cluster
687,304; the climbed designs 174,411–655,542 (`tclimb_1.json #5` 370,029 → 174,411, `tclimb_3.json #4` 578,172 → 518,340,
`tclimb_2.json #6` 562,398 → 505,238), every one under the cap; the 17 past it 1.23–14.96 M (`judge seed 4` 12.47 M → 4.31
M); A28 1,083,869; `h_bundle.json` 471,161 and its 3 variants 770,936, 761,149 and 826,152. Mirror images as before
(`tclimb_3.json #3` 655,542 → 475,890 under Z, `tclimb_4.json #1` 638,320 → 685,385 under X), but `tclimb_3.json #4` −1.5 %
and −1.6 %, `tclimb_2.json #6` +5.1 % and +2.6 %, `tclimb_1.json #5` +1.9 % and −2.9 %. Every Block written another way: P1
−3.2 %, C09 +21.3 % (+7.6 % before), `tclimb_3.json #4` −4.5 %, F5 +95.8 %, C05 +689 %. The largest single report over the
fixtures, the attack designs and `worst_designs.luau`: 1,088 units (`A climb_2 1`, past the cap; 1,065 under it; 2,335
before: a test that ends early on a Ball's circle charges 32 lines, not 128; `reports.luau`). `worst_designs.luau` keeps its
designs, every valid one under the cap: its units and Lune ms again, the valid ones slowest first (`tclimb_2.json #5` now
before `#6` and `tclimb_3.json #4`).

*Cost* (`timing.luau`, median of 15, every design once a round on each tree in turn, the machine 9–15 % busy with the run,
1–7 % without it): the verdict / whole exposure / `Analyze.run` on the build before → the build: F5 0.28 / 1.35 / 1.74 → 0.38
/ 1.34 / 2.00 ms, F3 0.76 / 1.55 / 2.00 → 0.88 / 1.72 / 1.88, C05 0.13 / 4.61 / 5.77 → 0.21 / 4.85 / 5.93 (its units the
same: 0.1 ms is noise here), C09 2.13 / 7.12 / 8.36 → 1.58 / 7.01 / 8.23, P1 11.12 / 18.70 / 22.20 → 11.14 / 18.74 / 22.50,
P4 10.54 / 12.65 / 14.53 → 9.97 / 12.23 / 14.91; V1's cluster 30.79 / 34.18 / 34.57 → 30.20 / 32.68 / 34.71 (43.9 ns a unit);
the climbed designs at most 31.25 for the exposure (`tclimb_2.json #4`) and 36.21 for `Analyze.run` (`tclimb_3.json #6`),
30–34 ns a unit (`tclimb_1.json #5`, now 174,411 units, 46); past the cap `Analyze.run` answers `TooComplex` in 10.7–24.5 ms
(10.8–24.3 in the third round's timing).

*Precision.* The plausible set's Enclosed parts (V2's truths from `prec4.luau`, less the 14 now kept): 7,860; 455 / 3 / 0
truly show 2.5 / 3 / 4 % or more, the highest 3.615 % (a Ball in a pommel housing); the 14 kept truly show 2.13–2.97 %, so
the lowest kept stays 2.002 %. `VerdictPrecision.spec` passes on the default seed and on 0x0000002A, 0x600DCAFE, 0x31415926,
0x27182818 and 0x55AA55AA (four at once, about 66 s each, the fifth alone in 49 s).

*Tests* added by the round: Cover.spec (a) flat faces cutting a Ball at every height from its centre to past its pole, near
tangent, both ranks, then turned Blocks, Wedges, CornerWedges and Cylinders' caps against it; V1's round parts a hair inside
and a hair out of round hiders; (e) the 32-gon's area at 7 heights to 1e-12 of it, and its frame (another writing, the images
across X and Z, two 45° snaps); the `flat` of every facet; (c) the hovering hider and the framed plate under a Cylinder's
edge, the Ball over the window hiding nothing; (f) the units again. Verdict.spec: the studs kept; a Wedge and its other
writing in one slot in two materials, the Iron one kept both ways, the same mass. Every new case fails on the build before's
src with this round's tests: the circle against the brute force, the 32-gon's area, the hovering Ball, the units, the Steel
tip kept, the studs at 1.7 %; V1's hair-in, hair-out case on design 4's cap, against the brute force's circle (on that src
with its own brute force it passes once `away` is fixed, as V1 found).

**Not done here.** No Studio timing. The finer model was not climbed. The verifiers' 12 families ran in the judge's sample
(every 8th), the 4 of them ported into `PlausibleDesigns` in full. The third round did not measure checkpoint gaps again or
run a mutation pass of its own, nor did the fourth (V1's mutants of the third round's lines are V1's count).


**After the fifth verifiers' round** (V1 and V2 on the build above; the fixer's measures with the scripts in `cover/fix5/`,
Lune 0.8.9; "the build before" is the tree the verifiers read).

*What they found.* V1: round filler wholly inside one Cylinder was kept. Rule A bounded a Cylinder in a Cylinder by its caps'
centres' distance from the axis + r, which at a tilt θ stands up to r·(1 − cos θ) above its farthest rim point, so a rod or
puck a hair inside failed it, and while its margin was under the prism's 0.0048 r its facets' hulls stood past the side too:
10 Blade pucks r 0.1, 0.1 long, tangent to the rim of F5's guard made a disk r 0.8, every point 1e-4 inside it, read 2.33 %
each and were kept, truly 0 (Sharpening 0.1302 Normal → 0.3739 Hard); of 1,904 rods tangent to that rim 200 were kept, up to
4.8 %. Both verifiers: O9 (b)'s price was stated as about 18 %, but a thin part lying on a Cylinder's side truly shows nearly
half its surface and reads 0 (V1: a Block 0.07 × 0.02 × 0.5 0.0002 out across a 32-gon corner of that disk 38.9 %, a Wedge
44.2 %, a CornerWedge 46.5 %; 10 on F5's guard, Sharpening 0.2114 Hard on the truth's row and 0.1302 Normal as built; V2:
0.065 × 0.02 × 0.4 along a corner line, 38.0–38.4 %). Minors: the Ball circle's price came from samples (V2's climb 2.4 % at
r 0.3 and 9.6 % at r 3, V1's 5.94 % at r 3); at the `AXIS_TIE` boundary one solid has two verdicts (V1: a Block 2.000 %,
kept, written another way 1.992 %, cleaned); 3 mutants of the fourth round's lines that change behaviour survived the tests
(the X/Z tie, fixD, the Wedge's hy and hz order); checkpoint gaps past 0.35 on `tclimb_4.json #1` (0.358 and 0.377);
Analyze's and Sampling's headers stale; `fix4/circle.luau` and `fix4/exactc.luau` without the model's `flat`.

*Decision 1: rule A exact for a Cylinder in a Cylinder.* Across the axis each cap circle's farthest point from it, V1's
search (`Cover`'s `rimFarthest`): in a frame (a, e) of the cap's plane with a = n × u made a unit (square to the axis u) and
e = n × a, a point (cos φ, sin φ) = (c, s) of the circle stands D off the axis, D² = K + A·c + B·s − C·s² (K = |m|² + r², A =
2r·m·a, B = 2r·m·e, C = r²·(e·u)² ≥ 0, m the centre's offset across the axis); for each s the best c has A's sign, so the
largest D² is the largest over s in [−1, 1] of K + |A|·sqrt(1 − s²) + B·s − C·s², concave (a concave root, a linear term and
−C·s²), whose derivative's sign, that of (B − 2C·s)·sqrt(1 − s²) − |A|·s, turns from + to − once: 60 halvings find it.
Against a 50-digit truth (mpmath: 1,024 points of the circle, then 170 golden sections on the 4 best; 450 random circles,
tilts from 1e-15 to 90°; `rim.luau`, `rim_acc.luau`, `rim_acc.py`), V1's form, on the whole offset (K = |d|² + r² − (d·u)²),
errs by up to 1.5e-11 where the cap's centre lies far along the axis; taken across the axis by its parts, within 5e-16 at
every tilt, with its parallel cut at 1e-8 (|m| + r there, r·(1 − cos) ≤ 5e-17·r above the truth; V1's 1e-6 leaves 1.8e-13
just under it, and a cut at 1e-12 errs by 7e-11, n × u being a few bits of rounding). §4.1's rules hold: + − × ÷, sqrt, abs,
max, a numeric loop. The search costs 1.19 µs a cap circle against 43 ns a unit (`t_rim.luau`, median of 15, the machine 1–2
% busy, no other Lune process: 27.2–27.8 units), so it is charged `UNITS_PER_RIM` = 28 and runs only where two bounds leave a
cap open: above sqrt(|m|² + 2r·|p| + r²), p the offset in the cap's plane (on P's local Y and Z), since a point r·w off the
centre stands |m|² + 2r·p·w + r²·|w⊥|² off in D²; below, the circle's point toward p, an actual point of it. They differ by
r²·(p's direction along the axis)² in D², agree for parallel axes and for a cap whose plane holds the axis (the tangent
puck), and hold against the 50-digit truth (above at most 2e-16 under it, below at most 3.4e-16 over it). The lead's
root-mean-square bound, sqrt(|m|² + r²/2), holds (the mean of D² over the rim is |m|² + r²·(1 + cos²θ)/2) but stands up to
0.67 under the truth, so it would leave far more caps open. A test charges `UNITS_PER_TEST` and 28 a cap its bounds leave
open, whichever cap decides, so that the order of the caps (a writing's) cannot move units; the rule-A loop reports at each
round hider, where a run of searches would build up.

*Its decisions, bit for bit* against the always-exact rule (both caps searched, `mkvar.py`'s `exact`; `dec.luau`, every
ordered pair of round parts of every design, both ranks): on the 193 fixture-set designs 12,812 Cylinder-in-Cylinder tests,
on the 1,340 attack designs 19,924, on the 33,389 plausible designs 118,976: the bounds decide every one, no search, and no
decision differs from the always-exact rule's or from the tree before's bound's; on V1's rods and pucks (`rods5.luau`: V1's
`rodtilt.luau` draws, seeds 1–3, 500 each, and rods r 0.02–0.1 tangent to a disk's rim r 0.8 and 0.5, turned 0, 2, 10, 45 and
90° about the radius, 2e-7 to 5e-4 inside by the exact value) 35,352 tests, 6,235 with a cap left open and searched, none
differing.

*Its measure* (V1's scripts beside the build, `v1b`, and the build before, `v1o`; `p_rodrim.py` lets `rodrim.luau` print when
no rod reads above 0): `rodrim.luau` R 0.8, 1,904 rods wholly inside: 200 kept, up to 4.813 % → 0, none above 0; R 0.5 36
(2.176 %) → 0; `rodrim2.luau` every cell 0.00 %; `puck_sword.luau`: the 10 pucks cleaned, D the truth's row's, Sharpening
0.3739 Hard → 0.1302 Normal; `rodtilt.luau` seeds 1–3 (500 draws): 9, 8, 7 kept → 0, 1, 1, the two a rod at a tilt near 0°
whose farthest point stands past the side by more than `EPS_GEOM` (its 720-point placement errs by up to 1e-5 r; O9 (a)),
reading 3.385 % and 2.200 %. By the exact value (`rods5.luau`): wholly inside 326, 323 and 338 of them, 9, 7 and 6 kept (up
to 7.145 %) → 0; tangent and turned, 8,330 at R 0.8 (965 kept, up to 7.220 %) and 8,330 at R 0.5 (250, up to 6.328 %) → 0.

*Bit for bit* (`bc.luau`, fix4's, the designs from the build before; `bcsum.py`): the build against the build before on all
33,389 plausible, 1,340 attack and 193 fixture-set designs (the 17 past the cap included): nothing moves, not a verdict row,
hSurf, sample count, sub-sampled patch, exposedKept, contact row, mass report, owned volume, volume probe, unit or the
measure's order. So `worst_designs.luau`, Cover.spec (f) and the units of §4.9, §16.18, §17.1 O7 and the rounds above stand.

*Cost* (`fix4/timing.luau` on the build before and the build, median of 15, every design once a round on each tree in turn,
the machine 2–6 % busy, no other Lune process; then the trees' order reversed): no unit moves, and the times agree within the
noise of the order: P2's verdict 2.28 → 2.40 ms (2.49 → 2.37 reversed), V1's cluster 29.55 → 30.06 (32.63 → 31.53), the
sub-millisecond ones (F5, F3, C05, C09, X01) faster on whichever tree runs first. A design that searches (`searchcost.luau`:
23 rods along a disk's radii, tilted asin(ρ/x) ≈ 4.4° out of its plane, 1e-4 or 2e-7 inside): 23 caps searched, one a rod,
644 units of its 13,165; its 1.3–1.5 ms are the models' (`t_model.luau`: a model costs 97–116 ns a unit, the reading about
43, so models are charged about 0.4 of their time; at most 24 a design, a Ball's 1,216 units in 0.14 ms).

*Decision 2: O9 (b)'s price, measured* (no change to flat faces against a Cylinder). Anywhere on the side, not only at the
corners (`plate_side.luau`, VisibleOracle on 400,000 points): plates 0.02 thick lying flat on a side of the disk's prism (r
0.8 along Z, 0.5 long), their outer face's plane δ inside the true side on the side's middle line, stand y²/2r − δ out of it
at y from that line and inside the prism over the side's length (2r·tan(π/32) = 0.158): every one of 81 reads 0.000 % and is
cleaned; centred on the middle, δ 1e-6 / 1e-5 / 1e-4 r, a Block 0.15 × 0.02 × 0.5 truly shows 44.1 / 42.8 / 38.3 %, 0.07 ×
0.02 × 0.5 37.3 / 34.7 / 26.3 %, V2's 0.065 × 0.02 × 0.4 36.3 / 33.5 / 24.7 %; off the middle, toward a corner, Blocks
34.3–40.0 %, Wedges 40.8–45.3 %, CornerWedges 43.4–48.3 %; Wedges up to 47.4 % and CornerWedges 48.2 % on the middle. Ways to
narrow it, tried in copies. A finer prism (`mkprism.py`: 64 or 128 sides, its directions by math.cos and math.sin) stands
0.0012 r or 0.0003 r past the side, 66 or 130 half-spaces for 34, but a plate as wide as one of its sides still lies in it:
0.075 × 0.02 × 0.5 on a 64-gon's side truly 37.9 % (a Wedge 43.0 %, a CornerWedge 45.2 %), 0.037 × 0.02 × 0.5 on a 128-gon's
30.1 %, read 0 (of the 32-gon's 81 plates 21 and 6 still cleaned); its units (`timing.luau` on the three trees, the machine
5–7 % busy): P2 27,108 → 78,984 → 226,534 (verdict 1.96 → 4.67 → 11.48 ms, `Analyze.run` 11.89 → 13.68 → 21.09), F3 10,973 →
20,029 → 54,621, C09 17,512 → 20,752 → 27,674, V1's cluster of Balls unchanged, and 5 then 6 of the 10 worst valid designs
past the cap. The side's cut by the face's own plane (`mkstrip.py`, for a face whose plane is parallel to the axis within
1e-9): a strip, 4 lines (the two where the plane meets the side, sqrt(R² − h²) either side of the axis's foot, h the axis's
distance from the plane, and the caps), exact with no trigonometry for a face that pokes out and for one just inside alike,
so the lead's worry that a near-tangent face just inside lies within any circumscribed polygon of its cut does not hold there
(the cut is no polygon round anything): every one of the 81 plates reads within 0.29 points of its truth; on the three sets
no verdict, measure, mass or probe moves and units fall on 1,999 designs (1,909 plausible, at most −9.3 %; 77 attack designs,
−26.1 %; 13 fixture-set designs, −12.6 %: 4 lines read where 34 half-spaces were; `bcs/`). An oblique face's cut is part of
an ellipse, whose exact area against a polygon needs trigonometry (§4.1 forbids it), so it would take a polygon round the
ellipse, as a Ball's circle does, standing past it by up to 0.48 % of its half-axes (the half-minor sqrt(R² − h²), the
half-major that over the sine of the plane's angle with the axis); and `CoverBrute` would have to read both. Not adopted this
round (the lead's decision): O9 states the price and these ways, the default accept for the MVP.

*Decision 3: the Ball circle's price from the climbs* (no change). Reproduced on the build (`ballprice.luau`, each climb's
top part from the verifiers' logs, its Ball alone, VisibleOracle on 400,000 points): V2 at r 0.3 a Block 0.0365 × 0.0592 ×
0.0933 reads 1.9998 %, cleaned, truly 2.3965 %, and 0.0609 × 0.0345 × 0.0963 1.9986 % → 2.3895 %, a Wedge 2.2775 %, a
CornerWedge 2.3177 %; at r 0.2 2.2317 %, at r 1 3.3037 %, at r 3 9.6347 %; V1 at r 3 a CornerWedge 0.1404 × 0.2116 × 0.0206
reads 1.9620 % → 5.9400 %, at r 0.3 2.1750 %, at r 0.2 2.1182 %. V2's report quotes a Block 0.0635 × 0.0341 × 0.0925 at r
0.3, 1.9986 % → 2.3957 %, whose literals its logs do not keep. The text now says where: a face poking out near a corner of
the 32-gon its plane cuts, the plane anywhere (V2).

*Decision 4: checkpoint gaps, allocation and collection.* What runs in `tclimb_4.json #1`'s longest stretch (`gapwhy.luau` on
`mkgaps.py`'s tree, whose checkpoint is told the units since the last; 15 runs, the bookkeeping outside the stretches): every
stretch past 0.25 ms (12 in 15 runs, up to 0.52 ms) lies in the building of its Cylinder models or at its end
(`Cover.model`'s side facets, 736 units, two models' worth; it is 23 Cylinders and a Ball), and the heap drops 1.2–4.3 MB in
each: a collection runs in it. With a full collection at every checkpoint, outside the stretches, no stretch passes 0.15 ms
and the median run's longest is 0.12. Over all 85 designs (`gaps5.luau`, V1's `t_time.luau` measure: the median of 15 runs of
the run's longest stretch, from the start, between checkpoints, to the end; the machine 1–4 % busy, no other Lune process),
the build: the F, C and X fixtures 0.073–0.240 ms (median 0.113, F5 0.240; single runs up to 0.447), P1–P5 0.144–0.287 (P3;
up to 0.397), the worst valid designs 0.155–0.279 (`tclimb_4.json #1` 0.187; up to 0.744, the cluster), past the cap
0.099–0.237 (up to 0.427), none past 0.35; with a collection at every checkpoint 0.062–0.200, 0.086–0.223, 0.109–0.137 and
0.085–0.129, no single run past 0.26 in these runs (the sixth round's pass it now and then, their medians never: below). So
the stretches past 0.35 are collections, not work the units miss; models are charged
about 0.4 of their time (above), which makes theirs the longest stretches without one. T-PERF-01 asserts
`CHECKPOINT_GAP_LUNE_MS` on the F, C and X fixtures and reports P1–P5 and the worst designs against it, as S-PERF-01 does
with the 75 ms total (§4.9, §14.11, §17.2).

*The minors.* §4.4, §17.2's ties row and Cover's header say where the circle's frame still follows a normal's last bits (V1's
text). V1's tests: Cover.spec (e) four Blocks with two 45° snaps whose normal's X and Z tie, (0.5, 0.7071, −0.5); (a) the rod
on a Ball's centre line, its rims `EPS_GEOM` − 2e-10 out (fixD); Verdict.spec two Wedges of one volume whose hy and hz in
order decide. V2's: `fix4/circle.luau` and `fix4/exactc.luau` give their one-facet models `flat`; Analyze's header gives a
test's skipped lines' charge as on the fixtures (1,088 at most), Sampling's that a flat facet reads a Ball's sphere.

*Tests* added by the round: Cover.spec (a) tilted rods r 0.03, 0.2 long and pucks r 0.1, 0.1 long in a disk r 0.8, tangent to
its rim and turned 0–90° about its radius, on the tangent point written with their axis the other way or 0.4 of their half
length along it either way, 1e-9, `EPS_GEOM` ∓ 2e-10, 1e-6 and 0.01 r inside or out, both ranks: 720 readings against the
brute force at ±`TIE`, the 360 the rule holds read 0 for their test's units and 28 a searched cap, some searched;
Verdict.spec F5 with a round guard and the 10 pucks, cleaned, the guard's measure; V1's three. `CoverBrute` reads a cap rim's
farthest point from a Cylinder's axis by its own means: 720 points by math.cos and math.sin, then every arc whose bound (the
larger end + M·h²/8, M = 2r·|m| + 4r² bounding D²'s second derivative) reaches the best point halved up to 40 times; its
point and its bound bracket the decision, the shift choosing between them. On the build before's src the tilted rods fail (a
rod 1e-9 inside reads 0.000286 of its area against the brute force's 0) and so do the pucks (kept); the other three pass
there, guarding code it has. `mut5.py`: 12 mutants, V1's three and 9 of rule A's lines (open caps held or not, either bound
wrong, the search on the old bound, A's sign, 10 halvings, the second cap never searched, the search charged nothing), all
killed (the tilted case without the shifted and other-way rods left three alive).

*Precision.* No verdict moves, so the plausible set's numbers stand (7,860 Enclosed; 455 / 3 / 0 truly 2.5 / 3 / 4 % or more,
the highest 3.615 %; the lowest kept 2.002 %). `VerdictPrecision.spec` passes on the default seed and on 0x0000002A,
0x600DCAFE, 0x31415926, 0x27182818 and 0x55AA55AA (default 3/3 in 53 s, 0x0000002A 3/3 in 61 s, 0x600DCAFE 3/3 in 59 s,
0x31415926 3/3 in 62 s, 0x27182818 3/3 in 62 s, 0x55AA55AA 3/3 in 63 s; three at a time).

**Not done here.** No Studio timing. The strip and the finer prism are trials in copies, neither in the build nor in
`CoverBrute`; an oblique face's ellipse was not tried, and the finer prism's units were measured on P2, F3, C09, the cluster
and the worst designs only. The checkpoint gaps were measured on the build alone.


**After the sixth verifiers' round** (V1 and V2 on the build above, which this round leaves as it is: tests and text only;
the fixer's measures with the scripts in `cover/fix6/`, Lune 0.8.9).

*What they found.* No blocker or major. V1: of 158 mutants of the fifth round's own lines (136 line mutants of `held`,
`rimFarthest`, `capBounds`, `lies` and the rule-A loop, 22 by hand), 41 survived the quick Physics suite, 20 of them
changing behaviour, unseen for three reasons: every search ran against one disk along Z centred on x = z = 0, where a wrong
term in X or Y of its axis drops out (the search's frame, the lower bound's point, `along`); no rod leaned less than 2° from
the disk's axis, so a parallel cut raised to 1e-3 or 0.03 (the axes taken as parallel up to that tilt, r·(1 − cos θ) above
the rim: up to 4e-7 at r 0.8, past `EPS_GEOM`) never showed; and no test counted what a search is charged (the tilted case
asked only that a held reading's units be 0.5, 28.5 or 56.5) or ran a run of searched tests (the rule-A loop's report
dropped, a puck against 20 disks reports 579 units at once). The other 21 are equivalent or act at a tie only (cutoffs from
1e-12 to 1e-4, 15 to 30 halvings, the returns past the budget), but for one in the older `along` line (`P.cx + Q.cx`): no
case puts a part near a hider's cap off x = 0. The fifth round's count (12 mutants, all killed) holds for those 12. V2: two
more of rule A's charge survive, the second cap charged only once the first one's search passes (the units then follow the
order of the caps, which `lies`, §4.4 and the fifth round say cannot happen; no reading had both caps open, one held and the
other not) and the lower bound always from P's local Y (more caps open and charged, the decisions exact). O9 and Decision 2
above said the strip read all 81 plates within 0.25 points of their truth, where its own log has 6 at 0.271–0.289 (a Block
0.040 × 0.02 × 0.5 0.0587 from the side's middle reads 35.977 %, truly 36.266 %). §4.9, §17.2 and Decision 4 said that with
a full collection at every checkpoint no run of the 85 designs passes 0.26 ms: V2's runs, quiet, twice, give medians at most
0.227 and 0.229 ms but single runs past 0.26 on 4 and 3 designs, up to 0.432 (P1) and once 1.264 (`uclimb_3`); in 60 runs
C05 3 (up to 0.369), P1 4 (up to 0.315).

*Tests* added by the round (V1's and V2's, as they tried them). Cover.spec's tilted case is now `tiltedRods(T, c, turns)`:
the disk and its rods turned by T about the disk's centre c, each rod turned about the radius and leaned about the tangent
by a {turn, lean} of `turns`, the units of every reading counted, held or not. The case as it was (T the identity,
c (0, 2, 0), no lean) pins its counts: 720 readings checked, 360 held, 136 caps searched, 709,562 units. A new case turns
the disk 37° about (1, 2, 3) and centres it at (0.13, 2.07, −0.11), so that no component of its axis, its centre or a rod's
axis is 0 (turns of 2° and 60°, and 90° leaned 0.03° and 0.0046°: 480 checked, 240 held, 78 searched, 478,107 units), and
leans rods along the disk's axis in the first frame (240 checked, 120 held, 6 searched, 226,227 units). At a lean of 0.03°
the bounds leave a cap open in 6 of the pucks' 60 tests (the rods' stand 1.5e-10 apart and decide), where a cut taking the
axes as parallel stands 1.4e-8 above the rim; at 0.0046° no cap is open (`mkstat.py`, `out/stat_tilted.txt`). V2's check, in
every frame: the centred rods moved 2e-8 along their axis and read written either way, the same reading (within 1e-11 of the
area) and units; at 30° and 60°, and the pucks' 2°, both caps are then left open, one held and the other not, in 8 of 40
tests, which none of the readings has. And a case in (f): a puck r 0.1, 0.1 long against 20 disks r 0.8 + 1e-7·(k − 1) on
one centre, turned 60° and leaned 45°, 1e-6 out of the largest: each test leaves a cap open, searched and not held, 28.5
units (570 before the first facet); its largest report is 333.625 (a cap facet's tests against a disk on top of 253),
579.125 without the rule-A loop's report, and the case asks for 512 at most, as the plate ringed by Balls does
(`out/stat_rims.txt`). The tilted cases take about 0.9 s each, the new (f) case a few milliseconds.

*Mutants* (`mut6.py`: V1's 41 survivors, `mutants_v1.json`, and V2's 4, each against the cases this round changed or added;
all 45 had survived the whole quick Physics suite): 23 killed, every one of V1's 20 that change behaviour and V2's three
(the charge after the first search, the lower bound from P's Y, the loop's report, V1's 947 written another way); alive V1's
21 (equivalent, at a tie, or `along`'s) and V2's parallel cut at 0, a numeric guard (`out/mut6.txt`).

*Text.* O9 and Decision 2: within 0.29 points (all 6 read under their truth; V2's rebuilt trial gives the same log). §4.9,
§17.2 and Decision 4: no design's median run passes 0.23 ms; single runs now and then do, the clock, not the work, as the
medians hold. Reproduced on the build (`timegaps.sh`, `fix5/gaps5.luau` with a collection at every checkpoint, 15 runs, the
machine 3 → 1 % busy, no other Lune process): medians at most 0.223 ms (P1), single runs past 0.26 on 4 designs (F4 0.261,
C05 0.309, X03 0.280, P1 0.278; `out/gaps_collect_q1.txt`).

**Not done here.** No Studio timing. Nothing in `src` moved, so the fifth round's bit-for-bit compares, units, timings and
precision stand. The mutants left alive were not killed, `along`'s among them.

### E-S2.13 Difficulty as built (`m3/`)

M3 ported S2/v2's edge and factors onto the build's verdict and measure: `Physics/Edge`, `Factors` and `Difficulty`,
phases 6 and 7 of `Analyze.run`, every walk in the measure's rank order (`Sampling.measureRanked`). Its plan was
measured through `verdict/analyze_build.luau`, the emulator; the numbers below are the build's, Lune 0.8.9, each
builder's and fixer's method and load in `docs/build/M3-notes.md`, the 2 % rule's limits in `m3/limits.luau` (→
`m3/out/limits.txt`). M3's fix round 1 then changed four things (fixer A): Thinness' chords and the edge's thickness
merge across the gaps the verdict hides (≤ `HIDE_OFFSET` + `EPS_GEOM`); θ is every local axis of a polyhedron (a
Cylinder's axis and two radial directions fixed by Z, a Ball's world axes); a polyhedron's samples are walked in a
canonical order and each part's probes placed by a rank-1 lattice; the raster reads each cell 0.0013 off its centre
towards x = 0 and 0.0017 up. Then fixer B took the physics frame and the guard line from the kept parts (SPEC §4.5), and
pinned §5.1's soft OR, the frame's rank order, each loop's charges and §4.6's boundaries in tests (each failing on its
mutant). Then fixer C ran Douglas–Peucker on the outline's integer lattice (SPEC §4.6, the M3 lead's L3 option (a)), so
a Y shift keeps the edge to the bit. M3's fix round 2 (fixer D) merged a hidden gap however slantwise a chord crosses it
to the next part (Thinness' union chord and the edge's thickness: where the measure's hide test hides both faces at the crossing,
each by the part across, `Edge.hiddenGap`) and read every part but a Thinness probe's own grown by `TIE` = 1e-10, so a
probe on another part's face meets it whatever the rounding (bullet below). Fixer E then measured what the hide test's
point probe shows of a face flush on a thin part, what fix round 1 moved beyond the 70 fixtures, the X mirror's cause, a
Wedge written its other way and the timing under the machine's ordinary load (bullets below; scripts in the session's
Temp scratch `m3-fix2e`, figures in `docs/build/M3-notes.md`). M3's fix round 3 (fixer F) asked a hidden gap's probes of
every part of the set, not only of the part across, so that a flush seam beside a slanted crossing no longer reopened
the gap, each crossing point within `HIDE_OFFSET` + 2·`EPS_GEOM` of the other across (bullet below; withdrawn in fix
round 4). Fixer G then measured what stays open, a slanted slit's mouth at the blade's outline, against a scratch
closure of it, and the round's minor figures (bullets below; scripts in the session's Temp scratch `m3-fix3g`). M3's fix
round 4 (fixer H) withdrew the set, which merged visible air at a grazing slant, and measured what the part across alone
merges, on flat and round faces, and the seam it leaves open (bullet below; scripts in the session's Temp scratch
`m3-fix4h`). Fixer I then re-measured the round's minor figures and estimated what a measure that follows the solid
would move and cost (SPEC §17.1 O11 (iii); bullet below; scripts in the session's Temp scratch `m3-fix4i`).

- **The §5 table.** As M3 was first built, `Analyze.run`'s d per step equalled the emulator's in rank order on the 70
  fixtures of the repo (F, C, X, P, P1–P3 with a floating or an attached speck, A24–A27), and its factor raws on the 63
  prototype fixtures whose verdict the build shares were bit-identical to the emulator's (1,512 raws). Against each
  fixture's own part order, as §5.5 and E-S2.9 were fitted, the rank order moves one cell of §5.5: C09's Hammering
  0.3170 → 0.3186 (its Thinness on All 0.3858 → 0.3898), no tier. Fix round 1 moved, every tier of §5.5 held: C04 0.3368
  / 0.4703 → 0.3379 / 0.4769 (Hammering / Sharpening), C05 0.1363 → 0.1369, C09 0.3186 → 0.3201 (Thinness on All
  0.3935), C13 0.1133 → 0.1137 (its Thinness now C02's, its guard mirrored), F3's, C06's and C08's Thinness on the Blade
  without a step's move; X01 and X01raw 0.0756 → 0.0749, X05-0.050 0.1038 → 0.1037; and, θ reading a Wedge's taper, P3's
  Hammering 0.1804 Normal → 0.2752 Hard, P5's 0.1902 Normal → 0.2167 Hard, P3's with a speck 0.1759 → 0.2559 Hard. The
  T-DIF-06 sweeps (F5 thinned, C02 lengthened) and F5's 0.1037 are unchanged. T-DIF-12's goldens
  `tests/golden/difficulty_{calibration, regression, cost}.bv1.golden.txt` hold 42,408, 84,793 and 24,405 bytes since
  fix round 2, which fix rounds 3 and 4 left byte for byte (42,414, 84,891 and 24,409 after fix round 1, 42,266,
  84,811 and 23,900 as first built); field by field only Thinness, g, d and the tiers named here and the edge,
  EdgeLength and cutIndex below moved, then, with the kept parts' frame, A25's and P1's (with or without a speck)
  balance and bladeLength and A25's cutIndex (below), then, with the lattice, the chains' lengths and EdgeLength in
  their last bits on 55 of the 70 entries (no g, d or tier) and the chains of P1, P2, P4 and P1's and P2's specks
  (below). Against the reference prototype in rank order: PartCount, Asymmetry and MaterialMix to the bit, Volume within
  1.4e-17, SurfaceComplexity within 1.3e-15 where the measure's grid is the prototype's; X02's is not (hSurf 0.04
  against 0.06: SurfaceComplexity raw 0.0069 and Joints 0.159 off on All), its Smelting the same; Thinness and
  EdgeLength are the build's own since fix round 1; P1 keeps the build's own verdict.
- **The edge (T-EDG-01).** cutIndex: F1 = F5 0.724180, F2 0.425000, F3 1, F4 0.134375, C01 0.300000, C02 = C02s = C12 =
  C14 = C15 0.766667, C04 1, C05 0.161483 (0.158369 on centred cells), C06 0.890676, C07 0.313333, C08 0.617500, C09 1,
  C10 = C11 0.271528, C13 0.765380, A26 0.507963, P5 0.820973, P2 0 (the build's physics frame tilts −45°, bladeLength
  2.1073; the prototype's 0.0225). EdgeLength within 4.3e-5 of the plan's 4-decimal values but C04 7.1067 → 7.1487 (the
  cells `RASTER_TOL` off its blade's faces at ±0.045, which 0.045 + 0.005 < 0.05 left out by rounding, are in), C06
  6.4797 → 6.4795 and C15 5.6261 → 5.6260. Every fixture's edge was the emulator's to the bit (64 of 64); read off the
  centres, 12 of the prototype fixtures whose verdict the build shares read otherwise (C04, C05, C06, C09, C15, F4, X03,
  X07c, P2 15 → 14 chains, P3, P4 6 → 5 chains, P5; P3's mean thickness also by the merged hidden gaps, +2.6e-5), and P1
  (1 → 2 chains, 0.1897 → 0.2286), no tier; with the lattice P2 has 15 chains and P4 6 again (their rasters still the
  build's), P1 4 (0.1897), and every other prototype fixture's edge is the prototype's within 1e-12. Of the sample
  offsets tried, 0.0013 / 0.0017 towards x = 0 and up moved the fewest fixtures (19); away from x = 0, 29, A24's 0.02
  needle losing its plain cells (cutIndex 1 → 0); downward, 59. The cell-size ladder charges a unit per kept part per
  row it tries: Edge's longest median stretch at `CHECK_UNITS` 500 is then 0.080 ms (0.298 without), Edge alone 0.58 ms
  (F5) to 5.48 (a worst valid design).
- **Douglas–Peucker on the outline's integer lattice** (SPEC §4.6, the M3 lead's L3 option (a)): a vertex at (2i, 2j),
  an edge's midpoint at the sum of its ends, squared distances compared as integers (cross², \|ap\|²·\|ab\|² or
  \|bp\|²·\|ab\|² against tol²·\|ab\|², under 2^52 for a design within Canonical's bounds), the first maximum by index,
  a segment's length its lattice length × the cell. Tried first on the centred raster, it moved C15's Sharpening 0.4291
  → 0.4299 through one exact tie (cross 12 = 12), P1 1 → 4 chains and P2 15 → 16, and was not adopted. Fix round 1
  adopted it on the raster read off the centres (fixer C, from builder 1's and fixer B's ports). Against the tree before
  (`Analyze.run` with `measureInvalid`, every value to 17 digits) the physics (M2's fields, cutIndex) and the raster
  never move. Of the 136 Parity fixtures 33 are identical, 91 move only in their lengths' and points' last bits (≤
  1.8e-15; every F, C, X and A fixture is among these two), 12 for real, no tier: P1 2 → 4 chains (EdgeLength 0.2286 →
  0.1897), P1 with either speck 1 → 2 (0.2286 → 0.18), P2 14 → 15 (1.2322 → 1.2325), P2 with either speck two chains
  re-picked (0.1345 → 0.1308, 0.0728 → 0.0806), P4 5 → 6, P5 two pairs of equal chains in the other order, worst valid 3
  15 → 16, 7 2 → 4, 9 Sharpening 0.0549 → 0.0543 (EdgeLength 5.0840 → 5.0806, the only d that moves), 10 its second
  chain 3 → 2 points. Of the 200 generated designs of `PARITY_SEED` 3 move (Gen 5, 92, 176), no d; of the 33,389
  plausible designs 28 (17,504 identical, 15,857 in the last bits), 12 d values by at most 0.0012 (a plate poking 0.03
  out of C02's edge: Sharpening 0.1825 → 0.1837), no tier. Every real move is one of four exact ties that blueprint XY
  decided by rounding: a point exactly 1 cell from its segment, which it measured a hair farther (P1's
  0.060000000000000053 against 0.06) and kept, now dropped (12 of the fixtures' 20 runs that pick other points, out of
  261; 22 of the plausible designs' 28); two points tied for the farthest, where it took a later one (8; 6); a chain
  exactly `EDGE_MIN_CHAIN` cells long, whose length in blueprint XY fell short (0.17999999999999972 against 0.18: P1's
  three, worst valid 7's two), now kept; and two chains of one length, now equal to the bit and ordered by their first
  point (P2, P5). Every one of the 1,793 shifted copies of TestRng 0x5EED0001's first 300 generated designs keeps its
  edge to the bit (the build's rule in blueprint XY changed some length's last bits on 291, and #131's outline at (0,
  0.2, 0.05): 6.4133 → 6.3895), and so do the 410 shifted copies of the 71 fixtures (P1, P2 with a speck and P5 changed
  under 11 of them).
- **Ties under a shift** (§4.6, §17.2). On centred cells the raster decided by rounding where a cell centre lay on a
  face, `RASTER_TOL` from one or on a thin Wedge's edge: 11 of 370 copies of the 64 prototype fixtures moved under
  E-S2.10's offsets (C05 +0.125: 1 cell; C09 0.037 down in Z: 240 cells, bladeArea 0.620 → 0.524, mean thickness 0.0433
  → 0.0512, cutIndex 1 → 0.884; C10 / C11 +0.3317: EdgeLength −0.04 / −0.02, Sharpening's G 0.0063 / 0.0031; X03 10
  cells, X07c 2, P5 12 at +0.3317; P1 1 → 2 chains at (0, 0.2, 0.05)), the prototype the same bit for bit. Read off the
  centres, none of the 410 shifted copies of the 71 fixtures inside the hitbox changes its raster, and with the lattice
  none its edge (its chains, points' x and lengths to the bit, the points moved by Δy): in blueprint XY P1, P2 with a
  speck and P5 changed an outline's points or chains under 11 of them (G 0.0003 at most), and of 1,793 shifted copies of
  TestRng 0x5EED0001's first 300 generated designs 4 their outline (#131 at (0, 0.2, 0.05): 6.413334 → 6.389542,
  Sharpening's g 0.4523 → 0.4486; on centred cells 6.450091 over 10 points → 6.426299 over 8, 0.4580 → 0.4543), none
  now. G still moved on 44 of the 410 copies, the edge kept, no flip: on 43 through Thinness, where a probe lies exactly
  on another part's face and the shift's rounding moved it off (F1's tip, a Block turned 45° and centred on its blade's
  top face at y 3.98, has probes there: at +0.125 the union chord along z no longer met the blade, τ 0.06 → 0.055; F1,
  F5 and the X and A fixtures built on them moved 0.0006–0.0017, mostly at +0.125, a few at +0.3317 or (0, 0.2, 0.05),
  X02 and its base 0.0031, past `TOL_G_INVARIANT`; P5 0.0003; on 12 of the 500 property-stream designs moved along their
  Y draw alone, up to 0.0016, every probe whose chord moved within 3e-16 of a face), and on C09 0.037 down in Z through
  SurfaceComplexity (0.0007). Since fix round 2 (every part but a probe's own grown by `TIE`) only C09 in Z moves G: of
  the 544 copies of the 136 Parity fixtures inside the hitbox, 45 moved G along Y alone (largest X02's 0.0031) and none
  now, no step's Thinness by more than 1e-12. Every X mirror image keeps its raster.
- **Invariance (T-DIF-07, T-DIF-08).** E-S2.10's offsets on F1–F5 and C01–C15 (111 copies): Δx ≤ 0.0017, ΔG ≤ 0.0007
  (F1, F5), the edge and cutIndex as above; F5 in 2, 3 and 7 pieces and C12 against C02: Δx ≤ 8.3e-16, ΔG 0. On 500
  generated designs of the property stream (`PROP_BASE_SEED`): translated ΔG ≤ 0.0016, Δx ≤ 0.0040, no flip, and along
  their Y draw alone every edge kept to the bit and G on all but 12, each through a Thinness probe on a face (above);
  since fix round 2 translated ΔG 0 and Δx under 5e-5, and along Y alone G on all;
  re-cut flush (`Gen.segmented`, each design cut) Volume and EdgeLength 0, ΔG up to 0.0379 (#115: Asymmetry on the
  Blade), then 0.0339, 0.0294, 0.0215, 0.0195, 3 past 0.024, one tier flip (#297, seed 4102300182: Hammering 0.2011 Hard
  → 0.1978 Normal); Thinness' x up to 0.0846, Asymmetry's 0.0730 (All) and 0.1261 (Blade). Before fix round 1: ΔG up to
  0.1250, then 0.0615, 0.0448, 0.0378, 0.0325, 5 past 0.024, one flip (case seed 515583194: two tip blocks cut into
  pieces 0.0879 and 0.1066 long, but chiefly a main blade turned and cut in three, whose 3 × 48 × 3 grid a stride of 3
  took on one outer Z layer, where the Z line crosses its corners, and its pieces' 3 × 18 × 3 on the middle one:
  Thinness on All 0.3395 → 0.0269, Hammering 0.2158 Hard → 0.0908 Normal; now 0.2088 → 0.2082), Thinness' x up to
  0.3126; θ alone (every local axis, a plain stride) left it at 0.1251 with 11 past 0.024, the canonical walk with a
  plain stride at 0.0824 with 9; on TestRng 0x5EED0007's 300, the M3 plan's stream, ΔG up to 0.0236, no flip. V1's fins
  cut into pieces shorter than they are thin: ΔG 0.0104, 0.0111, 0.0185, 0.0005 (0.2229, 0.3298, 0.2962, 0.3823, each a
  tier, before). Another writing: Gen #244's blade (TestRng 0x5EED0042, turned 54° about Y) in its 24 writings plays
  Hammering 0.1032 every time, 0.1983 at 0.0475 thick (0.0734–0.1226 and 0.1893 Normal – 0.2051 Hard before; g, d and
  tier the same, every factor within 5e-15); every Block of 300 generated designs written (b, a, c) a quarter turn about
  Z: ΔG 0 (0.0298 before; 500 more in T-DIF-07 (d)); F5's blade 0.05 to 0.06 thick with a square rib or a round rod on
  its face, 28 sizes, two writings each: 0 (up to 0.0728 and 0.0604, 5 flips, before); every Wedge of the 19 fixtures
  that have one written its other way (size (x, z, y), turned the half-turn (x, y, z) → (−x, −z, −y); M3's review round
  2, V1's `wedgewrite`, re-run on fix round 2's tree): Thinness the same on every one, and only C09's bevel 15 (2.4 ×
  0.03 × 0.05) moves anything, M2's surface samples, which follow its writing: SurfaceComplexity −0.00105 on All and
  −0.00215 on the Blade, Hammering 0.3201 → 0.3196, Sharpening 0.1904 → 0.1897, mass to the bit. Round parts' grids
  follow their writing: every Ball of the 94 designs of 0x5EED0042's first 300 that have one, turned 70°: ΔG up to
  0.0093 (#201), mass up to 6.6e-4, 51 designs move, no flip; Cylinders spun 30°: ΔG up to 0.0048, no flip (both as
  before the round).
  A laminate across the verdict's gap window: F5's blade split through its thickness plays Hammering 0.1035 Normal at
  every gap up to 0.0120 (0.3981 Hard from 0.0101 before), and F5, C02, C05, C08 and F2 at 0.0099 → 0.0101 flip nothing
  (all five did); crossed slantwise since fix round 2, below. The gap's volume still leaves SurfaceComplexity's V, its faces staying out of A (V1's `gapsc`,
  re-run): C02's blade split 0.005, 0.0099 and 0.0119 apart plays Sharpening 0.1318 → 0.1535, 0.1871 and 0.2016 Hard,
  its Thinness and cutIndex the same; with that blade 0.15 longer 0.1889 Normal → 0.2173 Hard, 0.2516, 0.2664; F5 0.0989
  → 0.1109, 0.1430, 0.1567 (§17.1 O10); from 0.0121 the faces show (C02 0.3318). Swords built half and mirrored (with
  the plane's parts that are not their own image): Asymmetry 0 on 500. A whole design against its X mirror image: F1–F5
  and C01–C15 the same; 150 generated designs EdgeLength ≤ 0.37 % (the mirrored outline is traced the other way round,
  so Douglas–Peucker keeps other points: #132 6.4133 over 10 points, 6.3895 over 8), ΔD ≤ 0.0621 since fix round 1's
  Thinness (fixer A's θ, walk and pick), no flip (#24: Hammering 0.1585 → 0.0964, Thinness on All 0.394 → 0.239; 0.0081
  before the round; the lattice moves neither figure). Its cause (M3's review round 2, V1 and V2; re-measured on fix
  round 2's tree): every part's probes read the same τ in #24 and its image but the Wedge tip's (0.0894 × 0.1817 ×
  0.0628, turned 90° about Y; 8 samples, 4 probes), whose smallest local axis lies along X. The walk signs that axis up
  the world, +X, in the design and in its image alike, so the image's walk is not the mirror of the design's: the
  design's runs 2 samples at x −0.016, then 6 at +0.016, the image's 6 then 2, and the lattice, from slot 4 in steps of
  5, takes slots 4, 1, 6 and 3 of each, 2 of the image's 4 the mirrors of the design's: τ 0.0235, 0.0549, 0.0392,
  0.0392 against 0.0392, 0.0392, 0.0549, 0.0549, the one probe at the thin edge (φ 1) carrying Thinness' self-weighted
  mean. Read with every owned sample a probe, #24 and its image both give 0.3697. No sign rule from the world follows a
  mirror across x = 0 for an axis along X (signing by z before x, fixer C's try, leaves 0.0621).
- **Fix round 2: hidden gaps crossed slantwise, face ties, aimed re-cuts** (fixer D; scripts in the session's Temp
  scratch `m3-fix2d`, figures in `docs/build/M3-notes.md`). *Hidden gaps.* M3's review round 2 (V1): a chord merged a
  gap by its width along the chord, the verdict hides it by its width across, so F5's blade turned 30° about its length
  and split, its faces hidden 0.0105 apart (0.0121 along Z), played Hammering 0.4095 Expert against 0.1318 Normal at
  0.0100 (turned 15°: 0.1043 → 0.4001 at 0.0119; 45°: 0.1765 Normal → 0.3323 Hard at 0.009), and two Wedges cut along
  its X-Z diagonal 0.3028 Hard at 0.0113 against 0.1762 Normal at 0.0112. A chord past `HIDE_OFFSET` + `EPS_GEOM` now
  joins the next where the measure's hide test hides both faces at the crossing, each by the part across
  (`Edge.hiddenGap`, Thinness' union chord and the raster's thickness alike): the turned laminate reads Thinness 0.3017
  / 0.3021 / 0.3033 at 0.0100 / 0.0105 / 0.0119 (Hammering 0.1318–0.1321 Normal), the diagonal 0.1442 / 0.1433 / 0.1416,
  and both jump only at 0.0121, where SurfaceComplexity says the faces show (2.2312 → 2.8824). Laminates turned 0°, 15°,
  30°, 45°, 60° and 75° about the blade's length (F5's hilt) and across it (a short blade on a long grip) at 0.0100,
  0.0119, 0.01200005, 0.0120002, 0.0121 and 0.0125: Thinness continuous to 0.01200005 and jumping with SurfaceComplexity
  at 0.0120002, at every angle (merged along the chord alone it jumped from 15°); continuous, not flat: where a probe's
  line crosses a slit's mouth at the rims it drifts with the gap (M3's review round 3, bullet below). V1's distance rule
  (each part within the window of the other's crossing point) merged non-facing neighbours where the verdict shows them:
  of 9,600 lines through each pair, a square rod's edge over a plate 32–41 crossings (15°–30°), a roof of two plates
  ±20° edge to edge 9–44 (even 0.013 apart), none for a facing pair or a half stair, and on the plausible set 4,164 of
  its 5,207 joins crossed a face that shows (65 designs moved, 4 a tier, ribbed bars Hard → Normal; worst valid 4's
  Hammering 0.2215 Hard → 0.1994 Normal); the hide test at the crossing merged none of those. What the rule moved,
  against the tree before: no F, C, X or A value; worst valid 4, 9 and 10's mean thickness +1.1e-5 (cutIndex −2.1e-5 to
  −2.7e-5) and worst valid 8's Sharpening Thinness 0.745625 → 0.746206 (no d); 14 of the 33,389 plausible designs,
  ribbed bars whose ribs' inner faces, 1e-4 off the rod at the tangent, a chord crosses 0.0121 apart along the line
  (Hammering down by up to 0.0386, no tier). Its tests are charged (F5 on All 4,801 → 4,911 units, P5 14,656 → 14,794,
  on the Blade 8,217 → 8,273); a sorted sweep and V1's closure gave the same chords on every fixture. *Face ties* (V2):
  a probe exactly on another part's face, its chord along it, met that part by rounding, so a design's Y draw alone
  moved G on 53 of 3,000 generated designs of six property streams (up to 0.0055; T-DIF-07's asserts failed on 3 of 5
  other seeds) and every Block written (b, a, c) on 2 (0.0007). Every part but the probe's own is now read grown by
  `TIE` = 1e-10, its box test and its chord: none of those moves G, Thinness only in its last bits (up to 1.14e-14), and
  `tests/Physics` (T-PERF-01 aside) passes on all six seeds; one design of V2's 0x0C0FFFE1 stream still moves G 0.0001
  along Y through M2's owned volumes (a round part's sampled overlap), Thinness unmoved. It moved X04-5-0.006,
  X05+0.002, X05+0.006 and X05-0.020 0.1044 → 0.1037 (F5's: their tip's probes on the blade's face), Parity's Gen 17,
  19, 131, 161 and 193 (up to 0.0012) and 839 plausible designs, 53 a played tier (fullers 560, 47 a tier; wedges in
  guards 107; plate edges 57; grilles 36; cylinder ribs 29; rods 26; bevels 24, 6 a tier; with the slanted merge's 14
  ribbed bars, d on 853 for the round; V2's dumps of the trees with the tie rule alone and the slanted merge alone, M3's
  review round 3, re-counted by fixer G), \|Δd\| up to 0.3932; on 57 of them (8 a family) every one of the 1,672 probes
  whose τ moved runs a line along another part's face within 1e-11 (a fuller's groove edge on a column of samples: the
  strip's chord along its side face). A nudge of the other parts' line by (−0.491, −0.237, 0.838)·1e-9 (its least part
  along 56,808 face normals of 0.5° single-axis and 15° two-axis turns 1.57e-12) passed the same seeds and moved the
  same fixtures and generated designs, but decided each tie by its direction (a groove's two edges opposite ways,
  swapped by an X mirror) and moved 1,270 plausible designs, 82 a tier. *Aimed re-cuts* (V1, V2; `recutaim`,
  `recutdown`, `recutwedge` on the final tree): V1's plate (0.15 × 2.4 × 0.03 on the +Z face of a 0.12 blade on a
  6,096-sample hilt, overhanging −X by 0.05) plays Hammering 0.1075 Normal whole, 0.1608 / 0.1786 / 0.2141 Hard / 0.2853
  / 0.3242 / 0.3254 in 3 / 4 / 6 / 8 / 10 / 11 pieces (Thinness 0.2667 → 0.8116); overhanging +X by 0.05, 0.1253 →
  0.0008 from 6 pieces; by 0.08, 0.2158 Hard → 0.1446 Normal in 4 pieces, 0.0024 in 11; Blade Wedges cut along their
  length (450 re-cuts of F4, Parity's 200 and the property stream's 500) up to 0.0521, 16 past 0.024, a tier on Prop 425
  (0.2037 → 0.1645) and Prop 297 (0.2011 → 0.1993). A floor of 8 probes a part, stratified and weighted by its share
  (scratch, not adopted): V1's plate 0.1075 → 0.0808, the others 0.1253 → 0.0808 and 0.2158 → 0.2424, but a 0.025 plate
  overhanging 0.11, 0.1871 Normal → 0.2101 Hard in 4 pieces; probes +1.2 % on the worst valid designs and P1, C10's and
  C11's 605 → 748. *Cost* (`Analyze.run`, the tree before and this one alternating in one process, a collection before
  each run, medians of 41, the machine 17 % → 6 % busy): × 0.995–1.028 on the worst valid designs and P1, worst valid 8
  × 1.0255, so its 53.4 ms quiet projects to 54.8 (the tie rule alone × 0.985–1.045, the probe floor against the round's
  tree × 0.985–1.042, both within the noise: an identical copy measured × 0.957–1.033 at 21 rounds).
- **Fix round 3: hidden gaps asked of the set** (fixer F; withdrawn in fix round 4, next bullet; scripts in the
  session's Temp scratch `m3-fix3f`, figures in `docs/build/M3-notes.md`). *The seam* (M3's review round 3, V1):
  `Edge.hiddenGap` asked only the part the line meets next whether it holds a face's probe, where the measure's hide
  test asks every part, so a flush seam in the far plate beside a slanted crossing reopened a gap the verdict hides.
  F5's laminate turned 30° and split 0.0105 apart plays Hammering 0.1319 Normal (Thinness 0.3021); with its upper plate
  in 4 flush pieces it played 0.3095 Hard (Thinness 0.7457, the mean thickness 0.05925 → 0.05779, cutIndex 0.7349 →
  0.7586) where the same pieces 0.0100 apart (merged along Z) play 0.1734; one seam 0.2186 Hard (0.1733), both plates
  cut 0.3322 Hard (0.2102), a seam in the lower plate 0.1742 (0.1263), one seam 0.0119 apart, near the window's edge,
  0.2104 Hard (0.1337); turned 45°, 48 of 49 single seams Hard, up to 0.2513. A probe was then held by any part of the
  set but its own, the part across first, and each crossing point had to lie within `HIDE_OFFSET` + 2·`EPS_GEOM` of the
  other across, along its face's normal (V1's tried rule; its reach pre-tests, which the probes imply, dropped, the
  bound across tested first): those read 0.1734, 0.1734, 0.2102, 0.1264 and 0.1343, each within 0.0006 of its pieces at
  0.0100. At 45° 26 single seams still play Hard (up to 0.2228): the whole laminate there plays 0.1994 at 0.0105 and
  0.1765 at 0.005, and each seam's move against its own pieces at 0.005, less the whole's, lies within −0.0095 … +0.0078
  (median −0.0015): the re-cut's grids (§17.1 O11) on the gap's drift at the rims, no reopening. *The set*: Thinness
  asks its work set W (on All every kept part, the measure's own hiders), the raster the striking slot's kept parts.
  Every kept part as the hider instead moved the edge of 7 fixtures (P3 and its two specks' mean thickness +8.6e-6 and
  +9.7e-6, worst valid 3, 4, 5 and 8 +4.6e-5, +1.1e-4, +1.1e-5 and +1.1e-5, cutIndex down by up to 3.8e-4) and of 13
  plausible ribbed bars, and 2 ribbed bars' Sharpening Thinness, no d: every one of those joins, 10 on the fixtures and
  48 on the ribbed bars, runs the line through a guard, a grip or a pommel part between the two blade chords, whose
  metal it bridged into the blade's thickness; where a part of another slot only lies beside the gap (V1's 30° laminate
  cut at −0.035, the piece beside labelled Guard), the edge reads the gap open (the mean thickness 0.0413 → 0.0395 at
  0.0105; Hammering, on All, holds), a visible label (§17.1 O8). *What the verdict shows stayed open*, as far as these
  looked (an open slot crossed at a grazing slant did not: next bullet): fixer D's sweep (0–75° about the length and
  across it, 0.0100 … 0.0125, 84 designs) and his non-facing neighbours on F5's hilt (stairs, a rod's edge over a plate,
  roofs: 55 designs) read the same to the bit, and so do 1,152,000 lines through 120 two-part cases; without the bound
  across, two of P3's wedges joined across a channel 0.11 long and 0.088 across, held by a third (V1's narrower fix2).
  Of the 24 joins the rule makes on the fixtures (6 by a part other than the one across) every one crosses air within
  `MERGE_GAP` of two kept parts at each of 9 points along it; on the plausible set 40 joins on 4 ribbed bars do not (a Z
  line grazing the rod 0.0003–0.001 off its surface between two staves the rod hides; no value moves). *Moves*, against
  the tree before: none on the 136 Parity fixtures, the 200 generated designs, the goldens or the digest; d on 10 of the
  33,389 plausible designs, ribbed bars (Hammering by up to 0.0173, 7 down, 3 up), no tier. *Cost*: every normal, box
  test and sd the test makes is charged (counted on the 136 fixtures and 13 attack designs: the units returned sum to
  the queries made, design by design), at most 2 + 2·(2 + 2·22) = 94 a call with 24 parts (46 met on the fixtures, 39 on
  the attacks), at most 2 calls a pass of a union chord; Thinness' charges by caller F5 on All 4,911 → 4,921, F4 5,600 →
  5,644, P5 14,794 → 14,848 and on the Blade 8,273 → 8,351. `Analyze.run` alternating with the tree before (a collection
  before each run): × 0.978–1.013 on the worst valid designs and P1 (31 rounds, the machine 19–45 % busy) and ×
  0.973–1.023 (41 rounds, the order swapped, 23–40 %), worst valid 8 × 0.978 and × 0.991, so fix round 2's projection,
  54.8 ms, becomes 53.6–54.3 (the largest ratio, × 1.023, to 56.0); the attack designs (stacks of 4–21 plates turned
  60°, the plates of a stack of 10, 7 or 5 cut in 2–4 pieces, a 0.40 laminate's upper plate in 8–19 pieces, a laminate
  beside 19 rods turned 45°) 19.0–30.1 ms, × 0.95–1.06 of the tree before, their longest stretch 0.205–0.282 ms (21–40 %
  busy; worst valid 8 68.3 ms and 0.720 in the same runs); those attacks cross gaps 0.0105 across, where the part across
  holds every probe at once, so the set's walk never ran in them: at 0.01200015 across it walked every test (12 plates
  turned 30°, × 1.215 of the tree before; M3's review round 4, V2), and without the set the pair asks the part across
  there and stops (next bullet but one).
- **Fix round 4: the set withdrawn** (fixer H; scripts in the session's Temp scratch `m3-fix4h`, figures in
  `docs/build/M3-notes.md`). *The open slot* (M3's review round 4, V1): F5 without its tip and four Blade slabs 0.4 long
  over its blade, their faces 3° off Z, p and r 0.012 over it, r′ and q 0.0119 over p's top plane, an open slot 0.15
  long between the two hidden slits, two Blade bridges 0.025 × 0.04 × 0.24 tying r′ and q to the blade (valid, nothing
  cleaned). The raster's column x = 0.0087 leaves p's top face under r and meets q's bottom face over r′ 0.227 further,
  each probe held by the slab beside, each point 0.0119 across from the other's face. Asked of the set, it read p +
  0.227 + q ≈ 0.27 thick, past `EDGE_MAX_THICK`, and cut the edge: Sharpening 0.0720 Normal, EdgeLength 3.0433 in 2
  chains (the mean thickness 0.06686, cutIndex 0.7243); Thinness' union chord across the slot from a plate under it
  0.2905. Asked of the part across, as before fix round 3 and now: 0.2728 Hard, one chain of 6.0851 (0.06275, 0.7849),
  the chord 0.0421. *The rule*: `Edge.hiddenGap` asks each face's probe of the part across alone: the gap across from
  p's normal first ((f − e)·n_p at most REACH, an exact pre-test: p holding f's probe implies it, p lying behind its
  face's plane), e's probe of q (its box, then its sd), then f's normal and its probe of p. The bound at f went with the
  set: q holding e's probe implies it (q behind its face's plane at f: (f − e)·n_q ≥ −`HIDE_OFFSET` − `EPS_GEOM`), so
  without a third part as the holder it never fires (V2's mutant without it survived the suite, an equivalent one). *Bit
  for bit*: `dump` on the 136 Parity fixtures, the 200 generated designs and the 33,389 plausible designs equals the
  tree before fix round 3 byte for byte (the 10 ribbed bars back); goldens and digest unchanged, nothing re-blessed;
  Thinness' charges by caller unchanged (F5 on All 4,921, F4 5,644, P5 14,848 and on the Blade 8,351: on F5, F4 and P5
  the set's loop never ran). *Fixer F's checks*, against the tree before fix round 3: his sweep (84 designs), neighbours
  (55) and 1,152,000 lines read the same, P3's channel with them (its dump byte for byte); his join scan finds 17 joins
  on 5 fixtures and 725 on 32 plausible designs, every one by the pair, between faces that face each other, its air
  within `MERGE_GAP` of two parts at each of 9 points (his 40 others gone). *Why it merges nothing the verdict shows*:
  each part is convex and lies behind its face's plane, so the line between the two points runs between the two faces'
  planes, within `MERGE_GAP` of them summed, and where flat faces face each other the point the line leaves lies under
  the other part (its probe lands there), the point it meets over the first, and by convexity the line between over both
  all along. On round faces (`curved`: two parts, their nearest points g apart, a Ball's and a Cylinder's side, 0.05 and
  0.2 across, against a plate and against each other, parallel, crossed and 30° skew, a Cylinder's cap, and plates
  tilted 5–60°; g 0.001–0.0125 either side of the window; lines through a 17 × 17 grid in the gap at 12 slants of
  0.5–80° and 16 headings): 13,872,000 lines, 2,876,754 of them past `MERGE_GAP` along, 179,928 merged, and every point
  of every merged line lies within `MERGE_GAP` of the two parts summed (at most 0.0120), each part's face nearest to it
  hidden (its probe in the other); from 0.01205 across, none merged. Only a partner thinner than `HIDE_OFFSET` there
  differs (a Wedge 0.014 thick tapering to nothing, its flat face 0.002, 0.004 or 0.008 over a plate: 1,139, 1,615 and
  1,751 merged lines pass a plate face whose probe the verdict reads through the thin Wedge, the air only that gap
  across, as the plain merge along its normal reads it; §17.1 O10). *The seam, a residual* (`seam` v1 and s45,
  `seamfig`, on the tree, the tree before fix round 3 and fix round 3's): F5's laminate turned 30° and 0.0105 apart, its
  upper plate in 4 flush pieces, plays 0.3095 Hard (Thinness 0.7457, the mean thickness 0.05779, cutIndex 0.7586)
  against 0.1734 Normal (0.4051, 0.05933, 0.7338) for the same pieces 0.0100 apart; one seam 0.2186 Hard (0.1733), both
  plates cut 0.3322 Hard (0.2102), a seam in the lower plate 0.1742 (0.1263), one seam 0.0119 apart near the window's
  edge 0.2104 Hard (0.1337); turned 45°, 48 of 49 single seams Hard, up to 0.2513: the tree before fix round 3's on
  every one (SPEC §4.6, §5.2, §5.6, §17.1 O11; Invariance.spec pins it). *The sandwich checks* (V1's B and B2 on top of
  the set, scratch variants, M3's review round 4): B (each point of the line, REACH apart at most, within REACH of two
  parts) and B2 (its two least distances summed at most REACH) both keep the slot open and move no plausible design, at
  × 0.959–1.037 and × 0.945–1.070 of fix round 3's tree (31 rounds each, 35–65 % and 4–31 % busy); B still merges a
  channel up to about 2·REACH across (rails 0.002 off the line, 0.0159 across), and B2 reads the V whose middle the
  verdict shows open and moves two unit pins. Both count two flush pieces of one layer beside a point, both below the
  line, as a sandwich (`floorslot`: V1's slot over a floor cut flush at the checks' points): B merges the 0.15 slot over
  its floor in 14 pieces (the line up to 0.0094 over it), and B2 a slot 0.05 long (up to 0.0042 over its floor, within
  REACH/2) at s 0.0119 or 0.005; neither floor moves the pair. *Cost* (`timing3`, the tree, the tree before fix round 3
  and fix round 3's alternating in one process, a collection before each run, every worst valid design and P1, 31
  rounds, the machine 2–10 % busy): × 1.0003–1.0240 of the tree before fix round 3 (sum × 1.0090, worst valid 8 ×
  1.0088) and × 0.988–1.017 of fix round 3's (sum × 1.0065, × 1.0087); again with a byte copy of the tree as a null
  (2–19 % busy): the tree × 1.005 and the copy × 1.0075 of the tree before fix round 3 on the sums, so within the noise.
  T-PERF-01 alone at 9–18 % busy: worst valid 8 at 60.06 ms, 0.06 over `ANALYSIS_LUNE_MAX_MS` (fix round 3's tree, M3's
  review round 4: 61.10 ms at 3–17 %); in `scripts/verify` at 3–32 % (median 14 %) it passed, worst valid 9 at 59.31 ms:
  749 of 749, VERIFY GREEN.
- **Fix round 4: O11's structural question and the round's minors** (fixer I; scripts in the session's Temp scratch
  `m3-fix4i`, figures in `docs/build/M3-notes.md`). Re-measured on this tree, each as M3's review round 4 found it. *The
  empty sealed cavity* (V1's `hollow`: F5's blade as a sealed box, walls and end caps 0.03 wide at its full thickness,
  top and bottom plates over a cavity c thick, every part kept, the outline F5's blade's): c 0.0100 and 0.0119, the
  cavity's faces hidden, Hammering 0.1035 and 0.1051 Normal (Sharpening 0.1914 Normal and 0.2036 Hard, the cavity's
  volume out of SurfaceComplexity's V); c 0.0121, 0.013 and 0.018, its faces shown, 0.5355, 0.5368 and 0.5433 Hard
  (Thinness on All 0.2588 → 0.8702, cutIndex 0.7242 → 0.8810, 0.8948 and 0.9785, Sharpening 0.2989, EdgeLength 5.4330
  throughout). *A Block's writing* (V1's `write4` and `write4b`): every Block written (b, a, c) a quarter turn about its
  Z moves no F or C fixture's G; on F5's laminate cut in 3 flush seams its tip alone moves it, SurfaceComplexity on the
  Blade 2.442958 → 2.441603 and Sharpening 0.2008 → 0.2003 turned 30° at 0.0105 (0.1973 → 0.1969 at 0.0100), 0.1437 →
  0.1439 flat; with 5 symmetric seams, nothing. *The X mirror* (fixer C's `mirror`): F1–F5 and C01–C15 the same, 150
  generated designs ΔD up to 0.0621 (#24), EdgeLength 0.371 % (#132), no flip. *The raster's hidden-gap charges* (V2's
  `rastercharge`, T-EDG-01's three plates turned 30°): 0.0105 apart, +10,920 units over 1,300 covered cells against
  0.0100 apart, 8.40 a covered cell (the test asks 3; a merged gap's test makes 6 queries), the same on fix round 3's
  tree. *The pair at the window's edge* (V2's `advab`, alternating with fix round 3's tree, 9 rounds, 6–7 % busy): where
  the part across misses each probe by 1.5e-7 (0.01200015 across) the pair asks it and stops, 12 plates 0.02 thick
  turned 30° about Y taking 27.5 ms against 31.1 with the set (29.9 at 0.0105, the gaps merged), turned 60° 24.1 against
  26.4, 21 plates 24.7 against 25.8, zigzags of 12 plates 23.0–24.1 against 22.9–25.5, their longest stretches 0.17–0.26
  ms (worst valid 8 59.4 ms in the same runs; one zigzag's Hammering 0.5733 against the set's 0.5911). *The seam on fix
  round 3's tree* (fixer H's `seam`): the one-seam laminate read 0.1734 at 0.0105 (0.1733 its pieces at 0.0100). *What a
  measure that follows the solid would move and cost* (SPEC §17.1 O11 (iii); estimates, not a prototype): `solidgrid`
  reads Thinness at a probe in every covered cell's metal run of the edge's grid (0.02 cells, x from the plane x = 0, y
  from the set's lowest point, read 0.0013 towards x = 0 and 0.0017 up; the run's middle, weighted by its length × the
  cell's area, owned by the highest-ranked part holding it, a Ball's or a Cylinder's probe moved as Thinness moves it),
  τ along Z and the owner's θ through `Factors.unionChord` as built, then each step with that Thinness: on F1–F5 and
  C01–C15 d moves by up to 0.0425 (C09's Hammering 0.3201 → 0.3626, its Thinness on All 0.3935 → 0.4998), C13 0.1137 →
  0.1228, C07 0 → 0.0054, C02, C12 and C14 0.1137 → 0.1176, C08 0.0992 → 0.1026, F3 0.4423 → 0.4453, C06 0.2991 →
  0.3019, C15 0.2701 → 0.2725, the rest by 0.0011 or less, Smelting and Sharpening not at all, no tier; V1's aimed plate
  (fixer D's `recutaim` design), overhanging either edge by 0.05, plays 0.1271 whole and in 6 and 11 pieces, against
  0.1075, 0.2141 and 0.3254, and 0.1253, 0.0008 and 0.0008, as built. `phases` (15 rounds, a collection before each, 6–8
  % busy): `Edge.profile` as built 0.43–3.47 ms on F1–F5 and C01–C15, 0.89–3.84 on P1–P5 and 2.23–6.74 on the worst
  valid designs (1,386–6,705 cells, 19,849–28,865 cell × part tests, 451–2,707 covered), and with every kept part
  relabelled striking, All's union, 0.89–3.98, 1.67–7.55 and 2.67–11.70 (worst valid 8 9.65 against 5.49); Thinness on
  All 0.92–2.68 ms on the fixtures and 0.82–6.99 on the worst valid designs (273–400 probes), on the Blade 0.37–1.09 and
  0.78–4.74; `Analyze.run` 4.1–16.1, 7.9–32.3 and 25.2–58.5 ms in the same runs.
- **Fix round 5: a shift on the plausible set, a part flush at a slanted gap** (SPEC §4.4, §4.6, §5.6, §17.1 O11 (j) and
  (k); M3's review round 5, V1, re-measured by the minors' fixer; scripts in the session's Temp scratch `m3-fix5m`,
  figures in `docs/build/M3-notes.md`). *A shift* (V1's `dump` and `dumpshift`, every part moved, on the plausible
  designs 22,261–33,389, byte for byte V1's dumps): moved 0.037 down Z, 246 leave the hitbox and of the 10,883 still
  valid G moves on 2,081, 621 past `TOL_G_INVARIANT`, up to 0.0354, 11 a played tier, M2's volume on 73; moved 0.3317
  along Y, G on 357, 103 past it, up to 0.0363, 2 a tier (#32923's Smelting 0.1906 Normal → 0.2030 Hard), M2's volume on
  698; the raster and the edge beyond 1e-12 on none. What moves them (`rankcmp`: the kept parts' order in
  `Sampling.measureRanked`, as built and moved): along Z the measure's rank reorders on 10,174 of the 11,129 designs,
  among them 2,027 of the 2,081 (its keys −volume, y, \|x\|, x, \|z\|, z: parts of one volume, y and x change places
  where the shift changes which stands nearer the plane z = 0), and ranked by z alone (`czrank`, a scratch variant) G
  moves on 110 (47 past it, 2 tiers, up to 0.0354); along Y, which keeps the order, G moves only where an owned volume
  does (348 with M2's volume, 9 more within 1e-9 of it). The grille #32977 (1.0 × 2.8 × 0.02, 6 × 8, f0.7): its three
  Guard bars under the 7 Blade blocks, an overlap past `MAX_EXACT` that M2 samples, own 0.00728875 → 0.00245 each (a
  Pommel block 0.00588 → 0.003675), M2's volume 0.440572 → 0.423851 on this tree and on M2's own, Smelting 0.5008 →
  0.4776, Hammering 0.2509 → 0.2863. The fuller #24151 (w0.3, t0.02, its two cheeks 0.12 × 0.05 of the core's volume):
  as built the core ranks first (\|z\| 0 against 0.035), moved the upper cheek (0.002 against 0.037), so the sub-grid
  budget (`N_SUB_WORK`, spent in rank order) runs out at other patches (241 → 245 sub-sampled; `explog`): its exposed
  area 5.232951 → 5.351951 on both trees (the core's 0.245 → 0.3588), Hammering 0.2955 → 0.3261; with the budget
  unlimited (`subwork`) 878 patches both ways and nothing moves. *A part flush with the face a line leaves for a slanted
  hidden gap* (V1's `flushrib` and `flushscan`, my `flushtilt`): F5's blade turned 30° about its length and split 0.0105
  apart, five Blade ribs 0.02 wide whose tops lie in the lower plate's top face, reaching 0.01 below it: the edge's mean
  thickness 0.063386 at 22 of 31 shifts k·0.0013 along Z and 0.064654 at 9 (cutIndex 0.6740, 0.6568), 0.063386 at all 19
  valid shifts k·0.0131 along Y, steps 0.0260 / 0.1119 / 0.1362 and Thinness 0.258665 throughout (in the union chord the
  rib, grown by `TIE`, ends the line's run past the plate and is asked); the ribs' tops 0.001 lower, inside the plate,
  0.064654 at every shift, 0.0260 / 0.1121 / 0.1363, Thinness 0.259156; EdgeLength 5.449406 in one chain throughout. The
  whole design turned a further 2° about X: Y shifts one mean thickness (0.063895), Z shifts 22 between 0.063758 and
  0.064376, Hammering 0.1157 throughout. *Tests*: seven mutants of fix round 4's code that passed `--quick` (V1's R5h1,
  the box test with `EPS_GEOM` alone; R5p1, V2's `fprobereach`, the second probe `REACH` out; R5c1, R5c2, R5c6, R5c7,
  the last of a tie asked; R5c3, a join past lo skipped where a chord lies past hi) each fail their new assertion in
  T-EDG-01 or the union chord's case; `--list`: 749 cases, T-PERF-01 the 614th.
- **A slanted slit's mouth** (SPEC §4.6, §5.2, §17.1 O10; M3's review round 3, V2's `slant`, `slantfixed`, `slantedge`,
  `slantwhy2` and `slantgrid`, re-run by fixer G on fix round 3's tree, every figure the same, with a scratch closure,
  `var/close1`, and `closecmp`, `stackcmp`, `seamcmp`, `diagcmp`, `mouthline`, `rastercols`, `mouthcount` in the session's Temp
  scratch `m3-fix3g`). Where a slanted hidden slit meets the blade's outline, a chord that enters it there leaves through
  its mouth into air, with no chord beyond to join, and ends at the hidden face it left, while every face stays hidden
  (SurfaceComplexity on All 2.2155 → 2.2308 over 0.005 → 0.0119 at 45°, 2.8845 at 0.0121). F5's blade turned 45° about
  its length and split through its thickness, the outer 0.06 kept, 0.005 / 0.0100 / 0.0110 / 0.0119 apart: Thinness on
  All 0.3885 / 0.4432 / 0.4567 / 0.4695, Hammering 0.1765 / 0.1969 / 0.2020 Hard / 0.2068 Hard, where the whole blade
  plays 0.1497 and the blade split flush 0.1725 (its pieces' grids, O11); without its tip 0.1714 → 0.1964 (so not the
  tip, which fixer D's notes blamed); turned 60°, 0.1679 → 0.1896 (whole 0.1253, flush 0.1552); turned 30°, 0.1308 →
  0.1321. On one Z line (45°, 0.0119, no tip) the whole blade's chord is 0.0495 and the laminate's 0.0340, the plate's
  [−0.0212, 0.0128] and the other plate missed, 96 of the whole blade's 384 samples reading thinner through the laminate.
  *The mouth's own share*, against a scratch closure (exact on flat faces; not adopted): where a union chord ends at a
  face whose probe a part of the set holds, it goes on along the line until the face's foot point leaves the face (a
  chord of that part in the face's plane) or the probe leaves the hiders (their union along its path), then the plain
  closure again. It reads the 45° blade 0.1812 / 0.1823 / 0.1833 Normal at 0.0100 / 0.0110 / 0.0119 (Thinness 0.4106;
  73 chords continued), so the mouth adds 0.0235 at 0.0119 and the tier, the rest from 0.1497 being the pieces' grids;
  60°, 0.1758 (0.0138). At 30° it continues no chord of the design at any gap: one Z line from mid-plate at local x
  0.070 does cross a mouth (0.02777, closed 0.03389, the whole blade's chord), but no probe's line does; the laminate
  with 3 seams (Invariance's `seamedLaminate`) puts its pieces' probes there, 25 chords continued at 0.0100 and 0.0105
  alike (Thinness 0.4051 and 0.4053, closed 0.3707 and 0.3715; Hammering 0.1734, closed 0.1596), and one seam none. Two plates
  0.024 thick turned 45°: flush 0.2315 against the 0.048 solid's 0.2146; 0.0119 apart 0.2075 Hard, closed 0.1836 Normal,
  against 0.1501 for the 0.0599 solid of their outline (V2's "gap share" of about 0.04, taken against that solid, held
  the solid's own grid changing with its thickness); at 30°, 0.1325 against 0.1204, none continued: grids. Three and
  four plates turned 30° (Invariance's `slantStack`): Thinness 0.3847 → 0.3919 and 0.2955 → 0.3030 over 0.0100 →
  0.0119, the same closed: the plates' grids as they thin, not mouths. The diagonal cut: none continued, its 0.1442 /
  0.1433 / 0.1416 its outline thickening as its Wedges part (the mean thickness 0.0703 → 0.0706). *The raster* at 30°:
  the mean thickness 0.061085 whole → 0.060040 / 0.059326 / 0.059055 at 0.005 / 0.0100 / 0.0119, cutIndex 0.706898 →
  0.722693 / 0.733789 / 0.738076, EdgeLength 5.4494 throughout, 0 and 0.001 apart as the whole to the bit; a cell reads
  the mouth where its sample's line crosses it, a strip g·sin(slant) wide at each rim: at 30° F5's columns at x ±0.0687
  (0.02777 against the whole's 0.03599 at 0.0119), at 45° and 60° none, the edge the same to the bit. *The closure's
  reach and cost*: no union chord of F1–F5, C01–C15 or P1 ends at a face a part of the set holds, so no §5.5 value
  moves; worst valid 3, 4, 5, 8, 9 and 10 have 109 such ends (4: 0.2215 → 0.2244, 8: 0.6153 → 0.6143, no tier); of the
  33,389 plausible designs 203 (ribbed bars 130, wedges in guards 51, cylinder rivets 11, cages 5, cylinder ribs 3,
  bevels 2, wrap rings 1), d moving on 96 (ribbed bars 92, wedges in guards 4; 70 steps down, 26 up; at most 0.1440) and
  the played tier on 2 (ribbed bars, Hammering 0.3219 → 0.1779 and 0.2386 → 0.1584: a rib's inner face hidden by its
  rod beside the line). Its end tests alone (`var/close0`: after each union chord, the normal at each end and the probe
  asked of the parts whose box grown by `REACH` meets the line; Thinness only, nothing charged) cost `Analyze.run`
  × 1.024–1.206 on the worst valid designs and P1, worst valid 8 × 1.198, about 66 ms quiet (21 rounds alternating with
  this tree, the machine 14–24 % busy), before the lateral chords and the raster's half; written lean (V2's `close0L`:
  at each end the normal, then the probe asked of the list's boxes, then an sd), × 1.005–1.121, worst valid 8 × 1.085
  and × 1.117 (M3's review round 4, 31 rounds twice, 23–53 % busy), and × 1.012–1.091, worst valid 8 × 1.070, against ×
  1.160 for fixer G's form in the same runs (fix round 4, fixer I, 31 rounds, 6–36 %), and × 1.019–1.168, worst valid 8
  × 1.111 and × 1.164, against × 1.036–1.237, × 1.174 and × 1.216 for fixer G's form (M3's review round 5, V2, 31 rounds
  each, 1–28 % busy): a tenth to a sixth of the slowest design's time, about 59–64 ms, at or past `ANALYSIS_LUNE_MAX_MS`
  and past the 57 ms gate.
- **What the 2 % rule itself admits, through `Analyze.run`** (`m3/limits.luau`). The proud core between cheeks, 96
  families (w 0.3–1.2, l 2–3, c 0.02–0.05, k 0.02–0.04, with and without a cap; p from −0.02 to 0.03): the core crosses
  2 % 12 times, \|ΔD\| 0.2696–0.4070, 7 tier flips on 6 crossings; Hammering's jump carried by Thinness 0.1038–0.3588
  (all of it on 7 crossings) and SurfaceComplexity up to 0.3000, Smelting's fall 0.0660–0.0996 by Volume. The recessed
  cores (a core in the cheeks' 0.02 gap, a sheet over its rims that cleans it): core → core + sheet up to 0.3680
  (0.8 × 2.5 × 0.04, core 0.60: 2 flips, Thinness −0.1878, SurfaceComplexity −0.1802; LAM1 0.3111, SurfaceComplexity
  +0.2876, Thinness +0.0236), 7 flips over the 9 designs (0.3713 and 0.3235 before fix round 1).
- **The physics frame** (SPEC §4.5, fixer B). gripPoint and the axis's vote, the top of the grip and the guard line
  take the kept parts only; V4, asked before the verdict, keeps every Grip part. Against the tree before fix round 1
  (M2's physics fields to the bit, `Analyze.run` with `measureInvalid`): of the 136 Parity fixtures 15 move, each with
  a cleaned Grip or Guard part (A14, A22c, A25, P1 with and without its specks, worst valid 2 and 4–11); C10 and C11,
  whose two cleaned Dust specks of the grip sit as a mirrored pair at its height, keep their frame to the bit. Of the
  33,389 plausible designs 1,785 move, 676 of the 782 with a cleaned Grip part and 1,109 of the 2,329 with a cleaned
  Guard part (ballRivet 588, plateEdge 233, wrapRings 229, wedgeInGuard 214, rod 193, tiled 192, cylRib 75, grille 42,
  cylRivet 15, cage 4), none else. Kept flags and owned volumes are bit-identical on every design, and against fixer
  A's tree its steps and edge too; against the tree before the round, fixer A's Thinness and raster and fixer C's
  lattice moved steps and edges (next bullet).
  cutIndex moves on 705 of them by at most 0.0043, on the fixtures by at most 0.0213 (worst valid 10); guardPos by up
  to 0.178 (a C09 under 5 wrap rings, whose cleaned rings had pulled the grip point that far up); A22c, measured
  with its only Grip part cleaned, takes the no-grip frame (the origin, +Y). The 200 generated designs of
  `PARITY_SEED` clean no Grip or Guard part. A hidden part's channel, before: V2's strap in A26's rings (E-S2.7);
  a Guard block 0.1 × 0.4 × 0.04 hidden in F2's blade at y 2, 3 or 3.7, balance −0.0570 → −0.0832, −0.1308,
  −0.1641 and cutIndex 0.4250 → 0.4185, 0.4065, 0.3982; in a guardless F2, a Grip block so hidden at y 1.6, 2.4 or
  3.2 raised the grip's top: cutIndex 0.40 → 0.2875, 0.0875, 0, balance −0.047 → −0.497, −1.297, −2.097. Now each
  measures its base.
- **Fix round 1 beyond the 70 fixtures** (M3's review round 2, V2; re-measured by fixer E with V2's `dump` on fix round
  2's tree, against V2's dumps of the trees before and after fix round 1: `Analyze.run` with `measureInvalid`, every
  step's d, played tier and raw tier). Of the 33,389 plausible designs fix round 1 moved d on 14,230, by up to 0.3122 (a
  ribbed bar), and the played tier on 164: fullers 73, ribbed bars 52, ribbed blades 27, bevels 10, plate edges 2, each
  first at the gap window (4), θ on every local axis (109) or the canonical walk and its lattice pick (51), none at the
  raster's samples, the kept parts' frame or the lattice Douglas–Peucker (V2's attribution through fixer A's staged
  trees); the raw tier alone on 222 more; kept flags and owned volumes on none. Fix round 2 then moved d on 853 and the
  played tier on 53 (fullers 47, bevels 6: the face ties, bullet above), 10 of them fix round 1's flips, which now play
  their tier from before fix round 1 again (8 fullers, and C02's and F2's 0.05 × 0.05 bevels at 0.75: Hammering 0.1358
  Normal → 0.2164 Hard → 0.1358 on C02's); against the tree before fix round 1, d has moved on 14,333 and the played
  tier on 197 (fullers 104, ribbed bars 52, ribbed blades 27, bevels 12, plate edges 2), the raw tier alone on 242. Of
  Parity's 200 generated designs fix round 1 moved d on 78 and the tier on 2, both at the walk and pick: Gen 57's
  Hammering 0.1095 Normal → 0.2589 Hard (Thinness on All 0.6456 on 286 probes; every owned sample read as a probe,
  0.4669) and Gen 126's Sharpening 0.2000 Hard → 0.1938 Normal (Hammering 0.0992 → 0.0612, Thinness on All 0.1495 on 338
  probes, every sample 0.2265: the pick's sampling, either way); fix round 2 moved 5 more, by up to 0.0012, no tier. Of
  Parity's fixtures beyond the 70, fix round 1 moved worst valid 2, 3, 4, 5, 6, 8, 9 and 10, worst valid 4 a tier (24
  wedges: Hammering 0.0434 Normal → 0.2215 Hard, Thinness on All 0.4791 on 364 probes, every sample 0.4673), and fix
  round 2 none at 4 decimals.
- **A face flush on a thin part** (SPEC §4.4, §17.1 O10; M3's review round 2, V1's `diagflush` and `diagwhy`, re-run on
  fix round 2's tree; fixer E's `bevel`, `segcmp`, `timing`). The hide test's probe is the point `HIDE_OFFSET` along a
  face's normal, in the measure and in the verdict, and the coincident rule hides only the lower-ranked part's face of
  two in contact, so the higher-ranked part's face shows where its partner is thinner than `HIDE_OFFSET` along the
  normal. A fixture's main blade cut flush along its X-Z diagonal into two Wedges, the same solid: F5's blade reads
  1.1440 stud² whole and 0.5720 + 0.6826 cut (the higher Wedge's slope shows 0.1106 of its 0.4443, 24.9 %; the partner
  is under 0.012 thick along the normal over 0.0320 + 0.0045 of the 0.1709 diagonal, 21.4 %), so Sharpening plays 0.0989
  → 0.1563 (SurfaceComplexity on the Blade 2.2584 → 2.4721); F5's blade 0.05 thick 0.1440 Normal → 0.2224 Hard; C02,
  C02s, C13 and C14 0.1318 → 0.1832; C09's core 0.1904 Normal → 0.2225 Hard (Hammering 0.3201 → 0.3443,
  SurfaceComplexity on All 2.6254 → 2.6738); F3's Hammering 0.4423 → 0.5146, C04's 0.3379 / 0.4769 → 0.4047 / 0.5670,
  C08's 0.0992 / 0.2487 → 0.1328 / 0.2643, C12's Sharpening 0.1318 → 0.1381, C05's Hammering 0.1369 → 0.1391; F2, F4,
  C01 and C07 under 0.002; Thinness the same on every one. A Block 2.6 long with a Wedge bevel on its side, a 0.06
  contact: where the Block ranks higher its face shows 0.0585, 0.0390, 0.0195 and 0 stud² for a bevel 0.03, 0.05, 0.10
  and 0.20 wide (δ·a/b·L 0.0624, 0.0374, 0.0187 and 0.0094, the last under the 4 × 4 sub-grid's reach), where the Wedge
  does (a Block 0.03 × 1.0 × 0.06 against a bevel 0.30 wide) nothing. On the §5.5 fixtures, the measure's exposed area
  less what a segment probe leaves (a scratch variant of the measure, `var/segprobe`: a part grown by `EPS_GEOM` met
  anywhere from 2·`EPS_GEOM` to `HIDE_OFFSET` along the normal hides the sample, by `Shapes.chord`; the verdict
  untouched): C09 2.9259 → 2.7543 (5.86 %: its core's sides under its four bevels' thin edges 0.0690, the bevels back to
  back 0.0570 and 0.0431, a tip 0.0024; δ·a/b·L 0.069 and 0.048 a pair), C13 0.0101 (0.33 %: its tip and its guard's
  Blocks under its CornerWedges), C04 0.0042 (0.20 %), C07 0.0023, C06 0.0030, C02, C02s, C12, C14 and C15 0.0030 (0.10
  %: a tip's two Wedges back to back, the higher one's back face, 0.048 × 0.06), F4 0.0046 and C05 0.0044 (a tip on its
  blade's top), C08 0.0024; F3 (its one Wedge), F1, F2, F5, C01, C10 and C11 none. With that probe no §5.5 tier moves:
  C09's Hammering 0.3201 → 0.2432 and Sharpening 0.1904 → 0.0955 (SurfaceComplexity on All 2.6254 → 2.4715, on the Blade
  2.5846 → 2.2679), C04 0.3379 / 0.4769 → 0.3354 / 0.4731, C06 0.2991 / 0.5948 → 0.2978 / 0.5932, C08's Hammering 0.0992
  → 0.0986, every other d the same (SurfaceComplexity under 2.3 where it moves). Its cost (`Analyze.run`, this tree and
  the variant alternating in one process, a collection before each run, medians of 31, the machine 26–82 % busy): ×
  1.04–1.27 on the worst valid designs and P1, worst valid 8 × 1.19 (so 54.8 ms quiet would be about 65), the sum ×
  1.195; × 0.94–1.16 on the F and C fixtures (C09 × 1.16), the sum × 1.055; an identical copy measured × 0.970–1.035
  (sum × 1.003, 40–76 % busy), and a first form that tested the segment on every candidate × 1.05–1.40. With that probe
  a blade cut along its diagonal plays its whole blade's d (F5 at 0.06, 0.05 and 0.04 thick, F1, F3, C02, C02s, C04,
  C07, C08, C12–C14; what is left is the re-cut's own grids, O11: F4 0.1557 / 0.3401 against 0.1572 / 0.3420 as on the
  build, C05 within 0.0010, C09's core 0.0003). On the 33,389 plausible designs (V2's `dump` of the variant against this
  tree's, `segpl.py`): d moves on 5,191, by up to 0.2053 (`ribBar|r0.10 L3.0 n12 roll11.25 f0.7`), 2,212 by 0.05 or
  more, and the played tier on 197, every one Hard → Normal: 185 designs built on C09, whose own bevels' band it hides
  as on C09 (wrap rings 67, plate edges 54, bevels 28, cylinder ribs 18, plates 6, pommels in a block 6, ball rivets 4,
  a rivet and a tilted plate), 8 on C02 (its tip's band; bevels 5, plate edges 2, a laminate), bevels on F1 and F5, a
  laminated hilt and a ribbed bar (Hammering 104 steps, Sharpening 95); 24 designs rise, by up to 0.0207
  (`bevel|F3|a0.05 b0.08 height0.030`), where the variant's extra tests spend the measure's sub-grid budget
  (`N_SUB_WORK`) sooner and a later part keeps its centres' verdicts (with the budget × 100 both trees read that design
  alike, and on a C02 laminate only the band differs); kept flags and owned volumes move on none. Per §5.5 fixture, the
  build against the variant:

| §5.5 fixture | Wedges (CornerWedges counted) | Band: exposed area the segment hides, stud² (of exposedKept) | SurfaceComplexity on All | on the Blade | d: Smelting / Hammering / Sharpening | Tiers |
|---|---|---|---|---|---|---|
| F1 | 0 | 0 | 2.1996 | 2.2584 | 0.0288 / 0.1037 / 0.0989 | N/N/N |
| F2 | 0 | 0 | 2.0790 | 1.9914 | 0.0797 / 0.0176 / 0.0282 | N/N/N |
| F3 | 1 | 0 | 2.4529 | 2.9804 | 0.0000 / 0.4423 / 0.6104 | N/H/H |
| F4 | 1 | 0.0046 (0.07 %) | 2.0001 → 1.9987 | 1.7785 → 1.7768 | 0.4590 / 0.1572 / 0.3420 | H/N/H |
| F5 | 0 | 0 | 2.1996 | 2.2584 | 0.0288 / 0.1037 / 0.0989 | N/N/N |
| C01 | 0 | 0 | 2.0676 | 1.8541 | 0.1486 / 0.0000 / 0.0407 | N/N/N |
| C02 | 2 | 0.0030 (0.10 %) | 2.2599 → 2.2576 | 2.2814 → 2.2765 | 0.0355 / 0.1137 / 0.1318 | N/N/N |
| C02s | 2 | 0.0030 (0.10 %) | 2.2599 → 2.2576 | 2.2814 → 2.2765 | 0.0355 / 0.1137 / 0.1318 | N/N/N |
| C04 | 2 | 0.0042 (0.20 %) | 2.4989 → 2.4940 | 2.6298 → 2.6185 | 0.0000 / 0.3379 → 0.3354 / 0.4769 → 0.4731 | N/H/H |
| C05 | 1 | 0.0044 (0.05 %) | 2.2404 → 2.2392 | 2.0483 → 2.0469 | 0.5451 / 0.1369 / 0.3466 | H/N/H |
| C06 | 2 | 0.0030 (0.11 %) | 2.3603 → 2.3577 | 2.3971 → 2.3923 | 0.0097 / 0.2991 → 0.2978 / 0.5948 → 0.5932 | N/H/H |
| C07 | 2 | 0.0023 (0.15 %) | 1.9849 → 1.9819 | 1.8438 → 1.8375 | 0.0000 / 0.0000 / 0.0000 | N/N/N |
| C08 | 2 | 0.0024 (0.05 %) | 2.3477 → 2.3465 | 2.2170 → 2.2146 | 0.1563 / 0.0992 → 0.0986 / 0.2487 | N/N/H |
| C09 | 6 | 0.1715 (5.86 %) | 2.6254 → 2.4715 | 2.5846 → 2.2679 | 0.0001 / 0.3201 → 0.2432 / 0.1904 → 0.0955 | N/H/N |
| C10 | 0 | 0 | 2.1390 | 1.9346 | 0.1565 / 0.0000 / 0.0282 | N/N/N |
| C11 | 0 | 0 | 2.1278 | 1.9390 | 0.1562 / 0.0012 / 0.0368 | N/N/N |
| C12 | 2 | 0.0030 (0.10 %) | 2.2635 → 2.2613 | 2.2894 → 2.2845 | 0.0355 / 0.1137 / 0.1318 | N/N/N |
| C13 | 4 | 0.0101 (0.33 %) | 2.2781 → 2.2706 | 2.2814 → 2.2765 | 0.0376 / 0.1137 / 0.1318 | N/N/N |
| C14 | 2 | 0.0030 (0.10 %) | 2.2599 → 2.2576 | 2.2814 → 2.2765 | 0.0355 / 0.1137 / 0.1318 | N/N/N |
| C15 | 2 | 0.0030 (0.10 %) | 2.2615 → 2.2593 | 2.2814 → 2.2765 | 0.0353 / 0.2701 / 0.4291 | N/H/H |

- **Cost** (T-PERF-01: medians of 15, a collection before each run, run alone, the machine about 1 % busy). The F, C and X
  fixtures 2.90–12.12 ms (C05), longest stretch 0.078–0.230 (F2); P1–P5 and the specks 5.60–28.21 (P1), 0.084–0.321 (P4);
  the worst valid designs 19.24–48.95 (valid 8, `tclimb_3.json #6`), 0.123–0.242; past the cap 10.24–24.22, 0.077–0.112.
  After fix round 1, which charges and measures up to three more union chords a probe (two runs, the machine 0–4 % busy
  but for one rise to 12 % after the first): the fixtures 3.52–14.19 ms (C09), longest stretch 0.082–0.236 (F2); P1–P5
  and the specks 6.58–28.94 (P1), 0.083–0.276; the worst valid designs 20.17–53.22 (valid 8, ≈ 138 Studio at 2.6 ×),
  0.124–0.332; past the cap 10.30–24.30, 0.077–0.107. Inside the whole suite (one process, a larger heap): valid 8 53.9,
  the fixtures' stretches up to 0.236, worst valid 10 0.553 and P1 with a speck 0.399 (reported, collections). On the
  final tree, the physics frame the kept parts' (fixer B; two runs alone, the machine 1–9 % busy): the fixtures
  3.53–14.16 ms (C09, ≈ 37 Studio), longest stretch 0.079–0.239 (F2); P1–P5 and the specks 6.60–28.99 (P1, ≈ 75),
  0.085–0.302; the worst valid designs 20.35–53.44 (valid 8, ≈ 139 Studio), 0.123–0.256; past the cap 10.09–24.35,
  0.077–0.110; inside the whole suite (the machine 1 % busy at its start) valid 8 53.5, the fixtures' stretches up to
  0.241, past 0.35 P1 with an attached speck 0.360 and worst valid 9, 10 and 11 0.603, 0.474 and 0.403 (reported,
  collections). `ANALYSIS_LUNE_MAX_MS` kept 6.6 ms over valid 8 quiet after fix round 1, and about 5 after fix round 3:
  `Analyze.run` alternating with fix round 1's tree (`m3-r2-base`, fixer G's `timing`, 41 rounds each, a collection
  before every run) gives worst valid 8 × 1.0246 at 20–64 % busy (median 34 %) and × 1.0312 with the order swapped at
  9–33 % (median 13 %; × 0.996–1.049 and × 1.003–1.047 over the worst valid designs and P1), so its 53.4 ms quiet
  projects to 54.7–55.1, and through fix round 2's 54.8 and fixer F's two runs against fix round 2's tree to 53.6–54.3:
  about 55, under fix round 3's 57 ms gate in every run; M3's review measured the worst valid designs'
  medians at 61.5–76.9 ms with the machine 27–38 % busy (the tree before fix round 1, 49.4 quiet), so T-PERF-01 needs
  a quiet machine. Under the machine's ordinary load (Studio, chat and voice programs open; never quiet in M3's review
  round 2 or fix round 2): on the tree after the lattice, run alone, no other Lune process, 7–26 % busy, T-PERF-01
  passed twice with the slowest valid design at 58.9 and 59.8 ms (0.2–1.1 under the guard), C09 16.2, P1 32.4–32.6,
  `TooComplex` 11.4–28.1 and the F, C and X fixtures' stretches 0.109–0.294, and once failed on C05's stretch (0.377 ms)
  at 12–31 % with another Lune process running; one process timing fixer B's tree and that one case by case gave 59.7
  and 59.4 for the slowest (× 0.95–1.01), so the lattice costs nothing and the 6.6 ms of headroom are a quiet machine's
  only (V2); `--quick` took 30.21–30.27 s there at 15–29 % (30.14–30.20 on fixer B's tree; 25.9 quiet). After fix
  round 2: T-PERF-01 alone failed at 14–45 % busy (median 18 %), worst valid 5 at 60.25 ms, and the tree before, alone
  right after, at 9–30 %, worst valid 8 at 60.97; `scripts/verify` failed only there, worst valid 8 at 62.11 ms (14 →
  10 % busy at its start and end) and 61.47 (10–40 %, median 23 %); `--quick` 30.66 s at 7–14 % (fixer D); the last
  `scripts/verify` of the round failed only there too, on F2's longest stretch, 0.489 ms (28–74 %, median 40 %; fixer
  E). After fix round 3: `scripts/verify` failed only there, worst valid 5 at 62.14 ms (26–61 %, median 40 %), and
  T-PERF-01 alone right after on F2's longest stretch, 0.404 ms (25–62 %, median 52 %; fixer F); in fixer G's
  alternating runs above (9–64 % busy) worst valid 8's median took 61.3–66.2 ms, and his last `scripts/verify` (24–79 %,
  median 42 %) failed only there, worst valid 5 at 63.89 ms, and T-PERF-01 alone right after (24–65 %, median 34 %) on
  F4's longest stretch, 0.398 ms. In M3's review round 4, on fix round 3's tree, T-PERF-01 alone failed at 36–74 % busy
  (median 55 %, other agents' Lune processes running) on F3's longest stretch, 0.352 ms, and at 3–17 % (median 14 %) on
  worst valid 8, 61.10 ms (V1); at 29–51 % (median 42 %) on worst valid 5, 61.32 ms, and at 17–34 % beside 4 other Lune
  processes on C01's stretch, 0.374 ms; a clean copy's `scripts/verify` at 6–34 % (median 20 %) failed only there, on
  F2's stretch, 0.365 ms, and `--quick` took 33.70 s at 29–48 % (V2). After fix round 4: alone at 9–18 % busy, worst
  valid 8 at 60.06 ms and failing, and in `scripts/verify` at 3–32 % (median 14 %) passing, worst valid 9 at 59.31 ms,
  the F, C and X fixtures' longest stretch 0.274 ms (C01; fixer H), and again at 2–27 % (median 8 %), worst valid 8 at
  57.52 ms, their longest stretch 0.270 ms (C01; fixer I). In M3's review round 5 it passed at 0–20 % (median 8 %),
  worst valid 9 at 57.26 ms, the stretch 0.273 ms (F2; V1), and after its fix round 5 at 0–37 % (median 9 %), 57.55
  ms and 0.277 ms (C01; the minors' fixer). The quiet figures need a quiet machine. M3's share as first
  built (the tree before against M3's, 15 rounds; fix round 1 adds about 4 ms on the slowest): 1.61–7.10 ms on the
  fixtures, 3.17–7.95 on P1–P5, 5.23–9.03 with a speck, 4.07–14.25 on the worst valid designs; its longest stretch ends
  at Thinness' per-probe charge, 0.07–0.26 ms. Checkpoints with `measureInvalid`: F2 100 (97 before fix round 1, 41
  before M3), F5 112 (108), P5 236 (222), P1 1,252 (1,248), the same after fix round 1; P5 237 since fix round 2 charges
  its hidden-gap queries, and after fix round 3 F2 100, F5 112, P5 237 and P1 1,252 (fixer G's `ckcount`, V2's).
- **S-PAR-02's Lune digest** (`tests/Physics/Parity.spec`): the fixtures' group 136 designs (43 of the 149 Adversarial
  variants pass `Canonical.draft`), 425,675 bytes, fnv1a32 892272501 since the shift fix's round 3 (E-S2.14: X02's
  copies kept as at M3's commit again; 425,707 bytes and 262377556 after its round 2, C11's owned volumes and X02's kept
  copy; 425,673 bytes and 1001114566 after its first round, 11 fixtures' Joints and C04's owned volume; 425,658 bytes
  and 60321529 at M3's commit, `f7ac37d`); the generated group 200 designs of `PARITY_SEED` 0x5EED0002, 709,366 bytes,
  611215233; `parity.bv1.digest.txt` 131 bytes (131 after the shift fix's round 2, 132 after its first round, 130 at
  M3's commit; M3's fix round 2 moved 61 fixtures' and 19 generated designs' lines, most in Thinness' last digits, the
  `TIE` growth of a chord that ends on a slanted face; the groups were 425,752 bytes and 3014135086, 709,377 and
  410604535; fix round 1 moved 293 of the 336 designs' lines: fixer A's chords, walk and raster 185, then the kept
  parts' frame 15 fixtures' physics, 3 of them new (A14, A22c, A25), the groups at 424,595 bytes and 2087286482, 709,434
  and 2874446443 after those two, then the lattice 247, 103 fixtures and 144 generated designs, all but 15 in their
  edges' last bits; first built: 424,515 bytes, 945249129, 1.46 s; 706,909 bytes, 440098388, 0.94 s). The Studio runs
  are M3's exit (§14.10, §18).

### E-S2.14 A whole design moved: the shift fix (after M3)

M3's review round 5 found that a whole design moved along Z moves G (SPEC §17.1 O11 (j)), and its fix round 5 traced
most of it to the measure's rank by \|z\|. A whole-design move cannot be seen on a forged item, so the lead ruled it an
engineering fault, fixed apart from M3 on its tree (`f7ac37d`). The groundwork (a frame analysis and a census, the build
notes' `shift_frame.json` and `shift_census.json`) found the moves a player makes and every mechanism; fixer S built the
census's fix R, its six guards, and measured it on every corpus; fixer T measured the X move (§17.1 O12), the mirror
image (O11 (l)) and a hidden Grip part against the verdict's rank. Its review round 1 (V1, V2) failed the ranks as first
built, placed from a grip's point with the height raw, on three majors (below); in the fix's round 2 fixer U placed each
part across from the centre of the parts it ties with and keyed the height in `RANK_Q`, and fixer V measured this text's
remaining figures on that tree. Its review round 2 (V1, V2) failed the verdict's ties' centre on two majors (below); in
the fix's round 3 fixer W put the verdict's rank back on the world's centre planes, as at `f7ac37d`, the height kept in
`RANK_Q`, and fixer X measured this text's remaining figures on that tree. Its review round 3 (V1, V2) found the verdict
sound and one major in the measure, which placed a cleaned part among the cleaned parts it tied with (below); in the
fix's round 4 fixer Y placed a cleaned part from the centre of the kept parts instead, after its material, and measured
it. Its review round 4 (V1, V2) found that rule sound and two majors in what the text claimed (below); in the fix's
round 5 fixer Z left an exact copy out of a part's higher parts (Reviewer V1's repair), wrote what a hidden part still
reaches through the measuring and the turn's place in a mirror image, and measured them. Its review round 5 (V1, V2)
found that code final and five of round 5's sentences false (below); in the fix's round 6 fixer AA, writing no source,
cut the SPEC's account of what a hidden part reaches through the measuring to its rule, what it never moves and why and
one example, moved every figure here, scoped, and took V1's pin of fix A. Its review round 6 (V1, V2) found that code
and pin final and four of round 6's statements false (below); in the fix's round 7 fixer AB, writing no source and no
test, stated fix A's rule by §4.3's priority alone, in one sentence wherever it appears, its measured cases here as
examples. Its review rounds 7 and 8 (V1, V2) found that rule sound and some statements broader than what was measured,
and round 9's checker one more; in the fix's rounds 8 to 10 the lead applied the reviewers' tried words, which say
whether a statement is about kept or hidden parts or bound it to what was measured (the build notes'
`shift/shift_journal.txt`). The numbers are the build's, Lune 0.8.9, `Analyze.run` with `measureInvalid`; each step's
method, tools and load are in `docs/build/M3-notes.md` (the sections after M3's close-out), the scripts in the session's
Temp scratch (`shift-frame`, `shift-census`, `shift-fix-s`, `shift-fix-t`, the reviewers' `shift-v1-1` and `shift-v2-1`,
`shift-fix-u`, `shift-fix-v`, `shift-v1-2`, `shift-v2-2`, `shift-fix-w`, `shift-fix-x`, `shift-v1-3`, `shift-v2-3`,
`shift-fix-y`, `shift-v1-4`, `shift-v2-4`, `shift-fix-z`, `shift-v1-5`, `shift-v2-5`, `shift-fix-aa`, `shift-v1-6`,
`shift-v2-6`, `shift-fix-ab`, `shift-v1-7`, `shift-v2-7`, `shift-v1-8`, `shift-v2-8`, `shift-chk-9`), which loses
week-old files. The corpora: the 136 Parity fixtures (the Adversarial drafts `Canonical.draft` refuses dropped),
Parity's 200 generated designs, the 500 of each of the six `PROP_BASE_SEED` streams and the 33,389 plausible designs of
`tests/Physics/PlausibleDesigns`.

- **The moves a player makes.** The editor moves a whole design any distance along X, Y and Z (Ctrl+A, a drag, a nudge
  or a typed position; snapping is the player's), turns it by any angle and flips it across the fixed planes x = 0 and z
  = 0 (§11.6–§11.10); nothing re-centres a design before analysis (Canonical's C1–C7 touch a position only to turn −0
  into +0). A forged item renders from its own bounds (§13.7), so none of these moves can be seen on it; the editor
  shows them against the hitbox, its centre plane x = 0 and the grid on z = 0 (§11.2). The SPEC promised Y and Z
  invariance but for named classes, mirror invariance but for stated cases, and ids and order to the bit; an X move and
  a whole-sword turn are real changes, Asymmetry being read about x = 0 and the raster's columns standing on it.
- **On `f7ac37d`** (the census: 21 moves, ±0.0013, ±0.037, ±0.3317 where the hitbox allows and each design's room less
  0.001, along X, Y and Z alone, on every corpus): along Z, G moved on up to 5,125 plausible designs (698 past 0.002, 22
  a played tier, up to 0.0472, laminates; 0.0013 alone 3,978 and 22); along Y on up to 547 (2 a tier, 0.0363); along X,
  beyond the x = 0 reads, on up to 6,041 (15 a tier, 0.0666; P5's Hammering Hard → Normal at −0.0013); Joints on up to
  2,527. Fixer S's random Y/Z moves on every 11th plausible design (3,036): G on 272 and 265 (1 a tier, up to 0.0249).
  Among the fixtures, a Z move swapped which of X01's, X01raw's and X02's near copies is kept.
- **The mechanisms**, each switched off alone on a scratch variant: the ranks by \|x\| and \|z\| (the verdict's and the
  measure's: a move reorders parts of one volume and height, and with them who keeps a shared face, who owns an overlap
  within a slot and who spends the measure's sub-grid budget first; every Z tier and every X tier beyond x = 0; the
  verdict's, by \|x\| and \|z\| again since the fix's round 3, moves none of the plausible designs, below);
  `MassProps.ownership`'s box test at margin 0 before GJK at 1e-9, so that rounding decided whether a part that only
  touches another is above it, which sets the sampled overlap boxes and the global ladder (almost every Y move; a
  grille's Guard bars 0.00729 → 0.00245 each, exact 0.00762); the overlap cells, ceil(extent/h), at a whole number of
  cells and on a flat box (C09 at its room along Z: 11.999999999999998 → 12.000000000000002 cells); GJK's tangency on a
  round pair, about 4e-8, against `OVERLAP_TOL` 1e-9; Asymmetry's candidate box at exactly its reach (wrap rings 0.05
  out); contact at exactly `CONTACT_TOL` (Joints alone); and G's 1e-4 rounding tipped by a factor's last bits. Moving
  every design to a normal position first does not close it (rounding breaks exact ties again: 11 laminates still play
  another tier), and ranking by z alone breaks the mirror image (a key that orders two parts by z alone and is both
  shift- and mirror-invariant cannot order them).
- **The fix, six guards** (§4.2–§4.4, §5.1, §5.2; §16.18): (1) both ranks key a part's height as q(y), q(v) =
  sign(v)·floor(\|v\|/`RANK_Q` + ½), `RANK_Q` = 1e-9; the measure's keys its place as \|q(c − c̄)\| then q(c − c̄) for x
  and for z, c̄ the mean of the centres of the kept parts tied with it on volume and height (ranked after the verdicts),
  summed in blueprint order, itself among them (a cleaned part, after the kept ones, by its material, then by its place
  from the centre of every kept part: round 4), and the verdict's keys \|x\|, x, \|z\|, z from the world's centre
  planes, as on `f7ac37d` (round 3; the first round placed both from a ref, the verdict's the point of every Grip part,
  V4's, the measure's that of the kept Grip parts, and kept the height raw; the second placed both from their ties'
  centre, the verdict's over every part tied with it on volume, slot and height, hidden ones too); (2) `OVERLAP_TOL`
  1e-9 → 1e-7 and the box test at −`OVERLAP_TOL`; (3) `CELL_EPS` 1e-9: no cell on an axis 1e-9 thick or less, else
  ceil(extent/h − 1e-9); (4) Asymmetry's candidate box `MIRROR_GUARD` 1e-9 past its reach; (5) G's sum of each x on the
  1e-9 grid (`X_GRID`); (6) contact at `CONTACT_TOL` + 1e-9 (`CONTACT_REACH`) in V3 and the contact rows. All keep
  §4.1's rules: + − × ÷ and floor, numeric loops, no state, every sort a strict total order.
- **Guard 2's sign**, by measurement: where −`OVERLAP_TOL` and +`OVERLAP_TOL` own differently (10,359 designs, 22,146
  parts: C04, two generated designs and 10,356 plausible), against an exact reference (inclusion–exclusion up to 10
  higher polyhedra, 20,121 parts) or one sampled 8 × finer per axis (2,019): −`OVERLAP_TOL` closer on 9,947 designs,
  +`OVERLAP_TOL` on 271, equal on 141, the summed error 0.391 against 4.873; on the exact references −`OVERLAP_TOL` is
  exact on 19,501 parts (median error 0, +`OVERLAP_TOL`'s 1.3e-4), the fullers exact (2.90 summed the other way), the
  grilles 0.29 against 1.60. C04's Cylinder guard owns 0.0075577 (0.0075587 the other way and on `f7ac37d`; the
  reference 0.0075563). GJK on a Ball tangent to a Cylinder's side stops 1.2e-8 to 2.4e-8 above the gap over 301 moves:
  within 1e-9 never, within 1e-7 always.
- **A whole design moved on the tree** (the census's 21 moves plus 2 random Y/Z moves inside the hitbox, every design of
  every corpus; round 1, 6,205 s on 3 lanes, 3–100 % busy, median 45 %; round 2, 5,192 s on 3 and 4 lanes, 6–97 %,
  median 51 %; round 3, fixer W's, 11,732 s on 3–4 lanes, 18–100 %, median 77 %, the same on all three but where said):
  along Y, Z and the random moves no G, d, tier or validity moves on any design, nor a kept flag, and with it the
  PartCount, Joints, SurfaceComplexity and owned volumes it brings, but, on round 3's tree, X01's, X01raw's and X02's,
  whose blade copies stand about z = 0 (at ±0.037, the rooms along Z and both random moves X01's and X01raw's blade,
  between its copies, is cleaned, and at −0.0013 and the first random move X02's copy at z 0.002 is kept as well, G the
  same every time: X01's Joints 12.2682 → 8.2759 and PartCount 6.1756 → 5.1756 with its blade cleaned, X02's 8.2930 →
  12.2853 and 5.1756 → 6.1756 with the copy kept; round 3's residual, below), but where a move leaves the hitbox (8,439
  valid copies, 86 invalid ones; A01 enters it; the census's count before, 64,036 and 413, took its X moves in too) and
  A22c, which has no kept Grip part, so its reach, guard line and balanceFromHand stand on the world origin and move (no
  factor). The largest deltas, last-bit rounding: Thinness 4.35e-13 (#10341, F1 with a cylinder rib, +0.037 along Z),
  every other factor under 3.2e-14 (SurfaceComplexity 3.11e-14 on round 2), owned volumes 1.6e-15; on the fixtures,
  generated and seed designs Volume 2.13e-14, owned volumes 1.95e-14 and the mass 1.63e-13 (worst valid 7, round 2).
  Along X, with Asymmetry and EdgeLength held as built, G moves on no design, and every other factor moves by rounding
  alone: Thinness up to 1.09e-12 (#10328, F1 with a cylinder rib, at the hitbox's X edges), every other under 1.6e-14
  (fixer V on fixer U's census; the same on fixer W's, fixer X's `xdelta` run on it). Under the editor's snapped moves
  (k·0.05, each coordinate cleaned to 1e-12, §11.8, so each part moves by up to 5e-13 off the exact move; fixer W's on
  the fixtures, Parity's 200 and every 7th plausible design, and Reviewer V2's +0.15 and −0.35 along Y and +0.1 and
  −0.05 along Z on the fixtures, Parity's 200, every 4th plausible design and every 5th of the six seed streams, 27,027
  moves, run again on round 3's tree by fixer X) no G moves, every factor within 1.5e-11 (SurfaceComplexity 1.43e-11,
  plausible plateTilt\|F3\|tilt4 poke0.005 moved 0.05 along Z; Thinness 1.05e-11, worst valid 10 moved 0.1 along Z; V2's
  own sweep reads 1.19e-11 and 1.05e-11 on round 2's tree and on this one), the kept flags only X01's and X01raw's. The
  named classes a move still rounds anew are unchanged (fixer T, V1's scripts on the tree): F5's tip typed 1e-10 over
  its blade, 26 of 120 Y moves, Thinness 1.66e-3 and G 0.0007 (O11 (h)); F5's laminate turned 30° with five ribs flush
  under it, the mean thickness 0.063386 as built and 0.064654 at −0.037 along Z (O11 (k)).
- **As built against `f7ac37d`** (every corpus dumped, then each guard reverted alone on the designs that moved): the
  fixtures C04 (owned volume 0.0075587 → 0.0075577, M2's volume 0.0528178 → 0.0528168, SurfaceComplexity 2.4989453 →
  2.4989769, balance 0.2387999 → 0.2388022) and Joints on 11 (C04 6.6552 → 6.4792, C05, C07, C08, C11, C13, X03, X04b,
  X04g0.010, X06-0.01, A24: the contact rows), no g, d or tier; Parity's 200 generated designs bit for bit, the seeds'
  3,000 but DEADBEEF#297's owned volumes (no G); the plausible set G on 9,748 designs (up to 0.0371, a grille), 29 a
  played tier (25 fullers within 0.0016 of 0.2, 4 grilles) and 9 a raw tier only, Joints on 8,608, validity and the kept
  flags on none. Of the 11,232 that moved otherwise than in Joints, guard 2's sign alone moved 10,793, the cells 101
  alone and 149 with it, the measure's rank 123 alone (88 by its quantising alone, ribbed bars whose \|x\| tied within
  1e-17) and 23 with others, G's grid 3 alone and 10 with guard 2, guards 2 and 3's flat box together 24; the verdict's
  rank, the hidden-Grip rule, `OVERLAP_TOL`'s value and Asymmetry's candidates moved none alone. With +`OVERLAP_TOL`, G
  would have moved on 703 plausible designs (2 a tier) and C04 not at all.
- **The fix's round 2** (fixer U, then fixer V's measurements; the trees `shift-r1`, round 1's, and `f7ac37d`). Review
  round 1 found three majors in round 1's ranks: twins whose heights differ in the last bit (1.4 + 0.2 beside a typed
  1.6), ordered by the raw height, swapped under a Y move (857 of 20,676 plausible designs so made, 5 a tier, the same
  on `f7ac37d`); a hidden Grip speck moved the verdict's point, so chose which near copy of a grip is kept and so the
  measure's point (P5 with its grip copied 4e-8 along +X and a speck at +X: Hammering 0.2167 Hard → 0.1902 Normal; of
  every 9th plausible design so built, G on 85, 1 a tier; `f7ac37d` none); and parts whose places round to one `RANK_Q`
  step fell to the ids (P5's grip and a copy 3e-10 apart, its teeth at ±0.1400000004: 0.2167 or 0.1902 by the ids). A
  1e-9 move of the grip alone moved G on 13.4 % of every third plausible design (Z 1,274, 8 a tier; X 858, 1). Round 2's
  ranks, as built (above, (1)), close all four: the twins, 0 of the 20,676 under 4 random Y moves and none of the 24
  fixtures and 35 generated designs that have twins under 8; the speck chain, G and kept flags on none of 93 fixtures
  and every 9th plausible design (3,598), and P5 0.2167 in all 28 of fixer U's cases (copies 4e-8 to 3e-10 off, specks
  at the face or inside, a Grip block buried in the pommel, either side); the ids, P5 the same steps either way; the
  grip's 1e-9 nudge, along Z none of every third plausible design, along X 13, by Asymmetry's last step alone
  (1.3e-4–3.9e-4, G up to 0.0002; holding Asymmetry and EdgeLength restores all, O12's plane). The height is the raw
  q(y), not one placed from the grip (Reviewer V1's form): of the 20,676 designs' 64,037 twin pairs, under 200 free
  drags a design (12.8 million pair-moves) the raw keys split on 4 (3.1e-7 a pair-move) and the grip-relative on none,
  under 1.5 million snapped moves neither, and those 4 move no G or kept flag on any tree; each form fails a typed
  sub-1e-9 case of its own (raw: P5's tooth 7 at 1.4 + 0.2, the design moved a typed 0.2000000005 or 0.6000000005 along
  Y, Hammering 0.2167 → 0.2117; grip-relative: P5's grip typed at 0.7500000005, 0.2117 as built and 0.2167 at all 18
  snapped moves), and the grip-relative one keeps a point a hidden part moves. As built against round 1: the fixtures
  C11, whose guard row of six tied 0.09 cubes now ranks from its centre, x 0.3075 (cube 17 owns both its overlaps,
  0.00030375 → 0.0003645, cube 15 0.000162 → 0.00010125, no factor past 1e-12), and X02, whose 7 blades of one volume,
  slot and height rank from their centre, copy 3's z (copy 3 kept, copies 1, 2, 4 and 5 cleaned; PartCount 5.1756 →
  6.1756, SurfaceComplexity 2.1886 → 2.1580, Joints 8.2930 → 12.2853, on the Blade 2.1756 → 3.1756, 2.1409 → 2.0665,
  1.5138 → 3.7621; g, d and tiers the same); Parity's 200 and the seeds' 3,000 bit for bit; the plausible set G on 43
  designs (up to 0.0167, no tier, kept flag, owned volume or validity): 36 C09 with a Grip rod off its axis, whose bevel
  twins round 1 placed from the rod-moved grip point and now from their own centre on z = 0 (35 read `f7ac37d`'s G
  again, #9142 0.0002 from it), and 7 fullers whose core plate and two walls tie on volume and height and now rank walls
  first, the sub-grid budget spent in another order (#24143, Hammering 0.1117 → 0.1284). Against `f7ac37d`: G on 9,713
  plausible designs (round 1 9,748), 29 a played tier and 9 a raw one, as round 1. What it left, each a residual of O11
  (j) as it then stood: a part the verdict cleans that ties with visible ones on volume, slot and height still counted
  in their centre (P5 with its grip copied 4e-8 along +X and an exact copy of the copy kept the copy and cleaned the
  grip, G the same), and an exact copy of the last-ranked part of each tie group, up to three a design, which pulls that
  part forward, moved no kept flag, G, factor past 1e-12 or edge on the 17 valid fixtures with such a group and room for
  it (21 copies), 35 of Parity's 200 (35) and 19,968 plausible designs (43,014 copies; fixer V's `hidden`), but review
  round 2 built near copies that such a copy steered (the fix's round 3, below); fixer T's Grip block hidden off the
  grip's axis, tied with nothing, moves nothing on X01, X01raw and X02 (round 1: X01's and X01raw's middle copy cleaned,
  PartCount 6.1756 → 5.1756, SurfaceComplexity 2.1634 → 2.1954, Joints 12.27 → 8.28; one more of X02's kept) nor on the
  77 valid fixtures, Parity's 200 and 32,656 plausible designs that take one; heights or places that round to one step
  of `RANK_Q` tied and fell to the index (P5's grip copies 3e-10 apart: the lower id kept); a tie group's centre is
  summed in blueprint order, its last bits the order's with three or more tied parts (no id shuffle differs but A17's,
  below); and each guard's own boundary, now at a value only typing reaches (Reviewer V1's `probe10`, the same on round
  2's tree): F5's guard lowered exactly `OVERLAP_TOL` onto its grip, 2 of 82 Y and Z moves move its owned volume
  2.56e-9, the mass 2.01e-8 and the balance 5.54e-9, no G (F3's Cylinder grip so overlapped, last bits alone); F5's
  guard raised to a gap of exactly `CONTACT_TOL` + 1e-9, valid at 5 of the 82 (invalid as built), where at exactly 0.01
  it is valid at all 82 (`f7ac37d`: 6 of 82 invalid). Whole-design moves on round 2's tree: above. Snapped moves (k·0.05
  cleaned, along Y and Z; the fixtures, Parity's 200 and every 7th plausible design) and tiny ones (±1e-12 to ±0.001;
  the fixtures and Parity's 200): no G or kept flag; validity only by the hitbox. Cost: the tree / round 1 per case, 21
  rounds in each order alternating in one process, 1–12 % busy, median 1.0097 (0.980–1.033), the tree / `f7ac37d` 1.0026
  (0.982–1.013); the ranks alone 61–70 µs a run against 31–36 µs, 0.05 % of the slowest design.
- **The fix's round 3** (fixer W, then fixer X's measurements; the trees `shift-r2`, round 2's, `shift-r1` and
  `f7ac37d`). Review round 2 found two majors in round 2's verdict, each a regression against `f7ac37d`: its ties'
  centre counted cleaned parts, so an exact copy (Ctrl+D) of the near copy the verdict cleans moved the centre and chose
  the copy kept (C09 with its core typed 2.3 long and again 0.001 along +X: Sharpening 0.2110 Hard → 0.1967 Normal;
  plausible #22338, plate 6 again 0.01 along +Z: Hammering 0.1175 Normal → 0.7000 Hard, cutIndex 0.3971 → 0.6200; of
  every 25th plausible design given such a copy, 2,644 designs and 12,328 cases, G moved on 1,220 designs, up to 0.5825,
  and a played tier on 71, in 107 cases; Cover's (d), an exact copy first or last, failed on 0x0C0FFEE1, 0x2468ACE0 and
  0x600DCAFE, Reviewer V2's; the rest Reviewer V1's), and near copies, twins about their own centre, swapped under the
  mirror (#1940 with its core again 0.002 along Z: its Z image Sharpening 0.1950 Normal → 0.2099 Hard; Reviewer V2).
  Every rule for the verdict's near copies tried broke whole-design moves, mirror images or robustness to hidden parts
  (the lead's analysis, `shift_journal.txt`): the world's planes (`f7ac37d`) keep the last two; a grip's point (round 1)
  let a hidden Grip speck choose; the box of every part but Dust (Reviewer V2's `vby` and Reviewer V1's `vbox`, review
  round 1) moved with an Enclosed part poking out of it (a Guard bar 0.001 past P5's guard: P5 with its grip copied
  4e-8, Hammering 0.2167 → 0.1902) and closed neither the grip's nudge nor the ids' case; the ties' centre (round 2) let
  a hidden copy choose and the mirror swap; counting an exact copy once (Reviewer V2's `dp`, Reviewer V1's `fixc`) still
  let a copy 0.0005 beyond the near copy (#1940, 0.2099 Hard) or one halfway between them (C09, 0.1967) choose; the
  signed place alone (Reviewer V1's `fixa`), which no part moves and no move reorders, is reversed by the mirror (X01's
  and X01raw's Z images keep the other copy, G the same; Cover's sealed rod, its walls tied in its slots, wall 6
  0.301878 against its X image's 0.301881). So round 3's verdict keys \|x\|, x, \|z\|, z from the world's planes again,
  the height kept in `RANK_Q` (above, (1)); the measure keeps round 2's rank, its ties kept parts alone. On round 3's
  tree (fixer W's runs, `shift-fix-w`; fixer X's, `shift-fix-x`): C09's two constructions (that copy again exactly, or
  the core again 0.0005 along +X) read 0.2110 Hard, copies 19 and 20 cleaned, as on `f7ac37d` and round 1; #22338
  0.1175, cutIndex 0.3971, its mass and balance as without the copy; #1940 0.1950 Normal, the balance as without it;
  Reviewer V1's sweep, 2,644 designs and 13,522 cases, no copy swapped and no G (round 2: 3,307 swaps); Reviewer V2's
  in-place duplicates (`hsteer`) on the fixtures' 22 pairs, Parity's 59 and every 10th plausible design's 800, none
  (round 2: 5, 19 and 289, G on 3, 5 and 25, 2 tiers), its copy 0.0005 beyond (`hsteer2`) G on one fixture pair alone,
  where that copy is kept and so shows, as on `f7ac37d`; Reviewer V1's copy halfway (`nearcopy2`, often kept): every
  50th plausible design's 3,131 cases swap none and move G on 74 cases on 42 designs, up to 0.0820, a played tier on
  #25907 (3 cases), `f7ac37d` 75 on the same 42 (round 2: 905 on 304, up to 0.5368); Cover (the whole of
  `Physics/Cover`) passes on the six `PROP_BASE_SEED`s and 0x600DCAFE, and the whole of `tests/Physics` on the six holds
  every assertion (fixer X, 3 lanes, 1,095 s, 46–100 % busy, median 76 %), failing only on time: T-PERF-01 on all six,
  Cover (f) on four (its 'answered at once', or the 2 s a case may take) and the 2 s of Cover (a) on 0x0C0FFEE1 and of
  T-DIF-01 on 0x5EED0001; the near copies' mirror images (fixer W's `ncmirror` on V1's selection, 98 fixture, 47
  generated and 2,537 plausible cases, each across x = 0 and z = 0) keep the parts `f7ac37d` keeps in every case, and
  differ from their originals only where C09's bevels, twins about z = 0, share a face with the copies (49 Z images; C09
  with a bevel copied 0.001 along Z, Sharpening 0.2247 Hard → 0.1863 Normal), on `f7ac37d` alike; #1940's Z image 0.1950
  Normal. Review round 1's cases stay closed: P5 0.2167 in every speck and nudge case and the same steps in its id case
  (the grip and a copy 3e-10 off along X: the one at x 0 kept, whatever their ids), tooth 7 at 1.4 + 0.2 0.2167 and
  unmoved at 41 Y moves, the twins on none of the 20,676 designs, the grip's 1e-9 nudge along Z on none of every third
  plausible design and along X on 13, Asymmetry's last step alone; and the twins' typed half step (P5 moved a typed
  0.2000000005 or 0.6000000005 along Y: Hammering 0.2167 → 0.2117), fixer U's 4 free-drag splits (no G, last bits
  alone), the guards' typed boundaries (`probe10`: 2 of 82, 5 of 82, all 82) read as on round 2 (fixer X). The residual,
  round 3's and `f7ac37d`'s (O11 (j)): near copies tied on volume, slot and height whose midpoint a whole design's move
  along Z or X carries across z = 0 or x = 0 swap who keeps the faces they share, and so the copy the verdict keeps.
  Fixer W's `ncmoves` (Reviewer V1's selection, a part again 0.001 or 0.005 along X or Z where the verdict keeps one of
  the two, with room for that one part, every 25th plausible design: 7,288 cases on 1,091 designs; each moved ±0.0013
  and ±0.037 along X and along Z, on the tree and on `f7ac37d`): the kept flags move on exactly the same cases on both
  trees, down Z 392 and 482 cases (207 designs), along −X 969 and 1,734 (667), along +X 1 and 60 (1 and 16), along +Z
  none; G on the tree, along X with Asymmetry and EdgeLength held: down Z 0.0013, 316 cases on 132 designs, 296 past
  0.002, up to 0.1259 (a bevel on C09), a played tier in 147 cases on 75 designs (`f7ac37d` 1,293 on 202, 483, 0.1253,
  149 on 77); down Z 0.037, 359 on 135, 329, up to 0.5094 (a laminated hilt), 156 on 83 (1,340 on 205, 527, 0.5094, 157
  on 83); up Z, none (26 on 3 and 84 on 9: `f7ac37d`'s measure ranked by \|z\|); along −X 0.0013, 563 on 512, 182, up to
  0.4623 (a fuller), a tier played or raw in 17 cases on 16 designs (2,370 on 516, 393, 0.4626, 28 on 20); along −X
  0.037, 1,103 on 546, 408, 0.4632, 37 on 24 (3,058 on 546, 627, 0.4626, 48 on 28); along +X 0.037, 33 on 12, up to
  0.0196, 1 (1,785 on 161, 8 on 2); along +X 0.0013, 1 (1,151 on 106). The fixtures' 98 cases: down Z 0.0013 44 swap (4
  designs), G on 14 (C09 and X02), up to 0.0384, a played tier on C09 with a bevel copied 0.001 along Z (Sharpening Hard
  → Normal; `f7ac37d` G 18, 0.0383, the same tiers); along −X 0.0013 G on 4, up to 0.0143, C09's core (`f7ac37d` 10,
  0.0215). The generated designs' 47: the same on both trees, along −X 3 and 4 cases, up to 0.0052 (Gen 200), along Z
  none. No design of the census's corpora has a pair a move swaps but X01, X01raw and X02. As built against round 2: X02
  alone (copies 6–10 cleaned again, PartCount 6.1756 → 5.1756, SurfaceComplexity 2.1580 → 2.1886, Joints 12.2853 →
  8.2930; g, d and tiers the same); Parity's 200, the six seed streams and all 33,389 plausible designs bit for bit;
  against `f7ac37d`, round 1's and round 2's drift: C04's and C11's owned volumes (C04's Cylinder guard 0.007558654 →
  0.007557654, C11's cubes 15 and 17 0.000162 → 0.00010125 and 0.00030375 → 0.0003645), Joints on 11 fixtures,
  DEADBEEF#297's owned volumes, and on the plausible set G on 9,713 designs, up to 0.0371, 29 a played tier and 9 a raw
  one; no validity or kept flag anywhere. Mirror images of every corpus read as on round 2, line for line, but X02's,
  which follow its as-built change (copies 6–10 cleaned again, G the same; Reviewer V2's `mdump`); ids: none but A17
  differs (14,439 designs). Cost (fixer W, `Analyze.run` alternating in one process, the worst valid designs and P1, 21
  rounds in each order, 34–71 % busy): the tree / round 2 × 0.9976 over both orders (per case 0.961–1.033), the tree /
  `f7ac37d` × 1.0043 (0.929–1.081); the ranks alone 81–106 µs a run (round 2 94–121, `f7ac37d` 51–61). Tests: 772 cases,
  T-PERF-01 the 636th; `--quick` 730 pass and 42 skip, 48.87 and 49.57 s at 40–83 % busy, its cases about 0.1 s over
  round 2's timed one by one in the same minutes.
- **The fix's round 4** (fixer Y; the trees `shift-r3`, round 3's, and `f7ac37d`). Review round 3 (V1, V2) found the
  verdict as on `f7ac37d` and one major in the measure, a regression against `f7ac37d` since round 2: its ties' centre
  grouped cleaned parts with cleaned parts, and `MassProps.ownership` orders cleaned parts by that rank (after the kept
  ones and the slots), so a hidden part chose which of two hidden overlapping parts owns their overlap, and with it the
  mass and the balance shown (no G: cleaned parts enter no factor). Reviewer V2's sealed box on F2's blade (walls 0.02,
  0.3 across), filled by two fillers 0.18 × 0.26 × 0.26 that overlap 0.1, Iron at −x and Steel at +x, both Enclosed: a
  Ctrl+D copy of the Steel one pulled the centre to x 0.0133 and the overlap to it, owned 0.012168 / 0.005408 → 0.005408
  / 0.012168, mass 1.29371984 → 1.29358464 kg, balance 0.387402095 → 0.387165618; Reviewer V1's Dust specks 0.05 on F2's
  guard face, Iron and Steel 0.03 apart, with a third buried in the guard or the Steel one copied, mass −9.0e-7 kg, and
  his near copies 0.004 apart in a sealed cavity (`cs2`), −2.03e-4 kg, balance −5.6e-5; `f7ac37d` and round 1 none. Both
  repairs tried read round 3 byte for byte on every corpus: Reviewer V1's, a cleaned part placed from the world's
  planes, keeps `f7ac37d`'s swap under a move across a plane (his `cs4`, copies about z = 0 moved 0.01 down Z: −1.95e-4
  kg); Reviewer V2's, a cleaned part with no place, the material then the index deciding, which the lead chose, lets the
  ids choose, and that moves the mass where the twins' overlap is sampled in one box with another part's (fixer Y's
  `idtwins`: two Iron Dust Balls 0.07 on F2's guard face, 0.03 apart along Z, one 0.005 into the face, 1.08372 or
  1.08351 kg and balance −0.056862 or −0.056872 by the ids, the COM by up to 3.8e-5; 0.03 apart along X, the COM's x by
  2.4e-6, Reviewer V1's `csids`; Cylinders 4.3e-6; Blocks, clipped exactly, their owned volumes alone). V2's repair as
  given also left mirror copies to their turn, which a mirror image rewrites, before the material: two Dust Wedges or
  Blocks 0.07, Iron and Steel, the editor's mirror copies across x = 0 overlapping on F2's guard face, turned 30° about
  Z or 20° about (1, 1, 1), read their Z image's mass 1.2e-6 to 1.44e-6 kg off (fixer Y's `mirtwins`, on V2's repair and
  on fixer Y's first form, which replaced the index alone; `f7ac37d` and round 3 to the bit), and on that first form the
  plausible #8742's and #8776's two Enclosed Iron Wedges at x ±0.02 read their Z images' owned volumes 4.3e-19 apart. So
  round 4 takes V2's repair's material first and places a cleaned part, in place of its turn and the index, from the
  centre of every kept part, \|q(x − x̄)\| before q(x − x̄), then z, in `RANK_Q` (the origin with no part kept; the
  cleaned parts ranked after the kept ones, which every reader takes alone, then by material, place, half extents, turn,
  slot and index): kept parts alone set that centre and it moves with a whole design, so no hidden part, no id and no
  move chooses, and a turn decides only between parts that stand together (§4.3, §4.4). As built against round 3, every
  output of `Analyze.run` reads byte for byte on the 136 fixtures, Parity's 200, the six seed streams and two more
  (4,000) and all 33,389 plausible designs (dumped at 17 digits; fixer Y's dumps of round 3 equal Reviewer V2's). On the
  probes (fixer Y's `probes_y` on this tree, round 3, `f7ac37d` and V2's repair as given): every hidden copy and buried
  part leaves every owned volume, the mass and the balance to the bit, and the twins' ids swapped too, but for the
  balance's last bit where the swap reorders the parts it sums (2.2e-16); moves along Y and Z (free, snapped, at random)
  leave the mass to the bit, the owned volumes within 8.7e-18 and the balance within 8.9e-16, and along X the same, G
  moving by Asymmetry and the edge alone (O12); round 3 moves the owned volumes on every hidden case and the mass on
  most (up to 2.05e-4 kg), and `f7ac37d` under Z moves (V2's box 4.8e-3 kg, by its old box test; V1's `cs4` 1.95e-4).
  Mirror images: the probes whose twins differ in material, and `mirtwins`' mirror copies of either material, read their
  original's to the bit, where round 3 and `f7ac37d` move the mass by up to 2.03e-4 kg (twins about their own centre, or
  about a plane); twins of one material exactly about the kept parts' centre swap their overlap's owner, the residual
  §4.3 names (V2's box with two Iron fillers about x = 0, the owned volumes alone, as on `f7ac37d`; F2 with a stud at x
  0.12 and two Dust Balls 0.07 at x 0.004 and 0.044 about the kept parts' centre, x 0.024, one overlapping the stud:
  owned 4.45e-5, mass 1.61e-5 kg, balance 8.3e-7, round 3 the same, `f7ac37d` none). The near copies' figures (O11 (j),
  above) stand: the kept parts own first and the walks read kept parts alone, so no G or kept flag follows the cleaned
  parts' order (#7517, #7017 and #7661 read Reviewer V2's figures on this tree). Text fixed with it: the near-copy class
  at other figures, `f7ac37d`'s G "in count, not case for case", the Joints and owned volumes that X01's, X01raw's and
  X02's kept flags bring, and X02's mirror images (above). Cost, tests and goldens: below.
- **The fix's round 5** (fixer Z; the trees `shift-r4`, round 4's, and `f7ac37d`). Review round 4 (V1, V2) found round
  4's rule sound and byte for byte round 3's, and two majors in what its text claimed. (A) A hidden part still moves the
  mass and the balance shown, never G, by how another hidden part's overlap is measured: above that part it joins its
  higher set H, which takes the overlap from exact clipping to sampling (a round part, or more than `MAX_EXACT`) or
  grows its sampled box, and a sampled job of its own draws on the cleaned parts' share of `N_OVERLAP_WORK`, one spacing
  for every cleaned job. Reviewer V2's sealed box (`probe6b`: F2 with an Iron box on its blade's top, walls 0.04, the
  cavity 0.24, an Iron filler 0.258 across reaching 0.009 into every wall) and an Iron Ball 0.22 buried in F2's pommel,
  which owns nothing: the filler's owned volume 0.011797 → 0.017174 (exactly 0.013824), the mass 1.32327 → 1.36558 kg,
  the balance 0.43976 → 0.50856, G the same, on round 4, round 3 and `f7ac37d` alike, and on `probe7`'s grid (fillers
  0.242–0.280 every 0.002, Balls 0.10–0.28 every 0.01) with fillers 0.256–0.264 across alone (41.3, 42.3, 7.9, 8.1 and
  5.2 g; a filler 0.265 with a Ball 0.25, −5.3 g; between the grid's points about 0.2555–0.2655, round 6, below);
  Reviewer V1's specks in a box of his own (`hsteer2`: walls 0.02, two Guard fillers that overlap, one reaching into a
  wall; a Blade Dust Ball 0.015 buried in that wall on it, owning 8e-8, +1.18e-3 kg; two Block specks there owning
  nothing, +1.18e-3 too; with the cleaned parts' share at 39,946 of 40,000, a Dust Ball buried in F2's guard, +2.58e-3;
  specks 0.015 across, under `MIN_DIM`, which `Canonical` refuses, read the same at 0.02, and in V2's box move the mass
  by what they own alone, round 6, below). A Ctrl+D copy left in place, an exact copy, so moved it on round 4 where
  `f7ac37d` did not: plausible #8871 (`wrapRings|C09|n4 extra0.02 gap0.0010`), its guard or either Blade Cylinder again
  in place, 0.659536 → 0.665178 kg, the balance −0.005931, its fully covered Enclosed core's owned volume +0.000717 (the
  copy among the core's higher parts, 8 → 9, and the cleaned parts' spacing coarser); of every part of every 5th
  plausible design with a cleaned part copied in place (V1's `ctrld`), from #1 and from #3, 11 copies on 4 designs past
  1e-12 and 61 in the last bits (`f7ac37d`, from #1, 14 copies on 7 `pommelInBlock|C09` designs, −0.89 g at most, and
  73; from #3, 24 on 12, up to −6.9 g, and 73, round 6, below); V1's `S3`, a Pommel filler under three higher parts that
  a copy of one of them made four, sampled: −3.148e-4 kg. (B) Round 4's text said no turn a mirror image rewrites
  decides and listed the only parts a mirror image swaps, but parts of one volume, height and place tie on every place
  key, so their turn as given orders them, and the image rewrites it (V2's `probe4`: two Iron Dust Cylinders 0.07 × 0.05
  crossed at one point on F2's guard face, one along Y and its Ctrl+D copy along Z, swap their owned volumes, 6.94e-5,
  in either image, the mass 2.38e-5 kg, the balance 1.25e-6; V1's `mirturn`, two crossed at 30° and 70° about Z, the Z
  image +1.405e-5 kg; kept, an Iron and a Steel Cylinder crossed in the box's cavity, 1.41e-5 kg, and V1's `mirturnk`,
  two kept Iron Cylinders 0.4 × 0.1 crossed against F2's guard face, Hammering 0.0324 → 0.0321 in the Z image; round 3
  and `f7ac37d` the same). The lead took V1's repair for (A) and text for the rest and for (B): an exact copy
  (`Shapes.sameSolid`) of a part already in H is not added to H, since it adds nothing to their union. Checked in the
  code: kept parts never hold two exact copies (the verdict cleans the lower of any pair), so the kept parts' H, their
  spacing, their owned volumes, every factor and G cannot move; a cleaned part's H keeps its union, its box and its copy
  flag, so only its measuring can change (exact where the copy had made it more than `MAX_EXACT`, the cleaned parts'
  spacing, the units its job reports, which reach the checkpoints alone). As built against round 4, every output of
  `Analyze.run` reads byte for byte on the 136 fixtures, Parity's 200, the six seed streams and two more (4,000) and all
  33,389 plausible designs (fixer Y's dumps of round 4's source, which equal mine of `shift-r4` on the fixtures and
  Parity's 200), and so do the X and Z mirror images of the fixtures, Parity's 200 and plausible 1–11,130 and the id
  shuffles (A17 alone, as before). Every Ctrl+D copy of every part of every 5th plausible design with a cleaned part,
  from #1 (12,217 copies on 1,230 designs) and from #3 (12,004 on 1,206), now moves nothing, not even the last bits,
  wherever it is measured (a copy that takes a slot past its maximum leaves nothing measured: round 6, below); #8871 and
  the 38 other `wrapRings|C09|n4` designs under a copy of any part (V2's `ctrldone`), none; V1's `S3` and his copies of
  a wall or a speck (`S5`, `S6`, +2.56e-3 kg on round 4), none. What stays is the residual §4.3 names, an engineering
  one of M2's sampled measure, as at M3's commit, with no decision mark: V2's sealed box with the Ball in the pommel
  (+0.042 kg) and V1's specks, as above, on this tree too; on real designs none of 824 hidden exact copies of up to
  three cleaned parts a design (V2's `sweepdup`, every 10th plausible design from #3, 633 designs holding 872 cleaned
  parts) moves anything, and none of 1,011 Dust Balls 0.07 at the centre of the largest kept Block with every side over
  0.09 (`sweepspeck`, every 5th from #2) moves another part's owned volume (on 8 of them the Ball's own share moves the
  mass, round 6, below). A spacing of its own for each cleaned job (V2's `F1`) closes the Ball but moves 757 of the
  33,389 plausible masses, by up to 54 g, and X02's by 4.3e-4 kg, so it was not taken. The text now says, in §4.3–§4.5,
  §5.6 and §17.2's hidden-parts, ids and measure rows, that a hidden part moves the mass and the balance point shown
  only by what it owns and by how it has another hidden part's overlap measured, and with them the Damage and Balance
  stats (§8.2), never G, a tier, Q or rarity (stats never feed Q or rarity, and T sums kept parts only), and that a turn
  as given, which a mirror image rewrites, decides between parts at one place, as at M3's commit; and in §4.4 that the
  cleaned parts come after the kept ones of their volume and height. Cost, tests and goldens: below.
- **The fix's round 6** (fixer AA; the trees `shift-r5`, round 5's, `shift-r4` and `f7ac37d`; text and one test, no
  source). Review round 5 (V1, V2) found round 5's code final (every output of `Analyze.run` round 4's byte for byte on
  the 37,725 designs and on the X and Z images of the fixtures, Parity's 200 and plausible 1–11,130, no Ctrl+D copy of
  `ctrld`'s sweep moving anything where it was measured, each named mutant failing on the assertion aimed at it, the
  cost noise) and five of its sentences false, each scoped here. (1) Fix A does not leave every Ctrl+D copy out of the
  higher sets. Its rule, as round 7 words it (§4.3): an exact copy of a part already among another part's higher parts
  is not counted there again, so where the design stays valid, of a part and its Ctrl+D copy left in place the one that
  comes later in §4.3's priority (kept parts, then slot rank, then the measure's rank of §4.4) adds nothing: a copy that
  comes after its original changes nothing measured, and one that comes before it takes its original's place, as its
  original given the copy's slot and material would. A copy that comes after its original, measured: Reviewer V2's
  `relabel6` (review round 6), on V1's `S3`, his box below with a Pommel filler 21 under its two Guard fillers and wall
  13, a copy of filler 18 in the Grip or the Pommel slot, nothing on round 5, the mass −3.148e-4 kg, the balance
  −5.5259e-4 and filler 21's owned volume −4e-5 on round 4, on `f7ac37d` and on the mutant `fixA_sameSlot`, a copy
  deduped only in its original's slot; Reviewer V1's `material` (review round 6), a Steel copy of V2's Iron filler in
  its slot (`probe6b`, above), nothing. One that comes before it: V1's `relabel`, on his box below with the fillers 0.23
  and 0.22 long and two Dust Balls 0.02 in its wall (`S4`, the cleaned parts' share at 39,946 of 40,000): the copy of
  filler 18 relabelled Blade joins filler 17's higher set, which 18, ranked below 17, is not in, the mass 1.288801 kg
  +2.3865e-3, the balance +4.1979e-3, G the same, what 18 relabelled Blade gives (the mass to the bit, the balance
  within 5e-16), on round 5, round 4 and `f7ac37d` alike (fixer AA's run of his script; his `fixa`, with specks 0.015,
  the same); the same copy in `S3` leaves the mass on round 5 (the balance within 5e-16; −3.148e-4 kg on round 4 and
  `f7ac37d`); V1's `material`, a Ctrl+D copy of a hidden Steel part painted Iron, in its slot, takes its place, to the
  bit what the part painted Iron gives here (V2's box with its filler Steel +2.3595e-4 kg, the balance +3.9595e-4;
  `boxedF2`'s Steel filler 18 +1.0816e-4, `f7ac37d` +1.0140e-4; `S4` with filler 18 Steel +3.2542e-5; G the same; round
  4 and `f7ac37d` alike). Where §4.3's priority and the measure's rank alone differ, across slots: round 7, below. (2)
  V1's specks were measured in a box of his own (`hsteer2`, and `hsteer3` at 0.02, the smallest side `Canonical` takes:
  F2 with an Iron box on its blade's top, walls 0.02, the cavity 0.26, two Iron Guard fillers 0.258 × 0.258 × 0.19 that
  overlap, the second reaching 0.01 into wall 16): a Blade Dust Ball 0.02 buried in that wall on the filler, owning
  1.9e-7, +1.1802e-3 kg; two Block specks there, owning nothing, +1.1787e-3 (one alone, nothing); at `S4`, a Dust Ball
  0.05 buried in F2's guard, +2.5843e-3; the same on round 4 and `f7ac37d` (Reviewer V2's `hsteer2b` alike). In V2's box
  they move the mass by what they own alone and the filler's owned volume not at all (V1's `specks6b`, fillers
  0.256–0.264; V2's `probe6s`, 0.25, 0.258 and 0.27): the Dust Ball 0.02 in wall 16 on the filler's poke, owning 1.9e-7,
  +1.4858e-6 kg; two Block specks there, nothing; a Dust Ball 0.05 in F2's guard, owning 2.95e-6, +2.3215e-5. (3)
  `f7ac37d`'s Ctrl+D figure covered the sweep from #1 alone; from #3 (V1's `ctrld` on `f7ac37d`, run by both reviewers)
  it moves 24 copies on 12 designs past 1e-12, two `wedgeInGuard|C05` designs as round 4 does, six `pommelInBlock|C09`,
  two `laminate|F4` (`k0.02 wf1.5 proud-0.0200 captrue` and `wf2.0`) at −6.908 g, `lamHilt|hilt|w1.2 l3.0 c0.025 k0.02
  proud0.000 capfalse` at +5.181 g and a grille at +0.787 g, and 73 in the last bits; with #1's 14 on 7 (−0.885 g at
  most, V2's run) and 73, 38 copies on 19 designs, up to 6.9 g, G on none. (4) The band in V2's box with the Ball 0.22
  in F2's pommel is about 0.2555–0.2655: V1's `band`, at fillers between and beyond `probe7`'s points, with that Ball
  and with every Ball 0.10–0.28 owning nothing, 0.2555 +41.09 g, 0.2645 −5.24 g, 0.265 −5.27 g and 0.2655 −5.30 g, and
  0.240, 0.241, 0.255, 0.281, 0.29 and 0.30 nothing; V2's `probe7b`, fillers 0.240–0.282 every 0.001 and Balls 0.10–0.28
  every 0.01, 0.256–0.265 moving (7 Ball sizes each) and 0.240–0.255 and 0.266–0.282 not, `f7ac37d` the same over
  0.250–0.270. (5) The 1,011 buried Dust Balls move no other part's owned volume (V1's `speckall`, every part and the
  mass compared; V2's `sweepspeck2`, the mass too; G on none), but on 8, six `wrapRings|C09` designs and two cages, the
  Ball, wholly inside its Block, owns 8.094e-6 and moves the mass +6.37e-5 kg by that: at the cleaned parts' spacing
  there its box has 4 cells a side, whose 32 midpoints in the Ball undercount it (fixer AA's `ballcells`: 1.715e-4
  against 1.796e-4, and 0 at 5 and 6 cells, `H_OVERLAP`'s). Its minors: the counts (of `ctrld`'s 24,221 copies on 2,436
  designs, 1,978 make the design invalid, V1's `ctrlcount`: 1,858 take a slot past its maximum, `SlotTooMany`, so
  nothing is measured, and 120 the design past `MAX_PARTS`, which only `Canonical` asks, so `ctrld` measured them too,
  fixer AA's `ctrlcount2`; the 22,243 others keep it within those limits, 21,628 of them on valid designs and 615 on 105
  `grille` and `tiled` designs that are invalid without any copy, their Blade keeping no kept part (`SlotMissing`),
  which `ctrld` measured through `measureInvalid`, Reviewer V2's `ctrlvalid`; `sweepdup` copies the first three cleaned
  parts of each of its 633 designs, which hold 872, 871 copies tried and 824 measured, fixer AA's `dupcount`); the
  CornerWedge member of the mirror class (O11 (l); V1's `cwmirror`, run again by fixer AA: F2 with kept CornerWedges 0.3
  × 0.1 × 0.1, Iron, and 0.1 × 0.1 × 0.3, Steel, at one place against its guard's front face, whose image swaps each
  one's x and z sizes and so their order: they own their overlap the other way in the X and the Z image, 3.814e-4 /
  3.907e-4 → 5.635e-4 / 2.086e-4, the mass +3.641e-6 kg, the balance +2.5e-7, G the same; both Iron, the mass the same;
  `f7ac37d` alike); and V1's five mutants of fix A that passed the tests he ran, with his pin (below). So the SPEC
  (§4.3, §17.2's hidden-parts row) keeps the residual's mechanism, what it moves, what it never moves and why, fix A's
  rule (round 7 words it by §4.3's priority, below), V2's sealed box as its one example, and that it is rare on real
  designs; the sweep figures and every claim of none on a sweep are here (above and in the rounds before), scoped; §4.4,
  §5.6's and §17.2's ids rows and README name the CornerWedge. As built against round 5: no source changed (`src` byte
  for byte `shift-r5`'s), so nothing measured moves. Tests and goldens: below.
- **The fix's round 7** (fixer AB; the trees `shift-r6`, round 6's, and `f7ac37d`; text only, no source and no test).
  Review round 6 (V1, V2) found round 6's code and pin final (`src`, the goldens and the digest round 5's byte for byte,
  the 76 files S-PAR-02 read unchanged, the pin failing on each of the six named mutants of fix A on the case aimed at
  it, V2's `scripts/verify` from a clean copy green with 776) and four of its statements false: fix A's rule scoped by
  the slot alone, where a hidden Steel part's copy painted Iron, in its slot, takes its original's place (V1's
  `material`, item (1) above); item (1)'s "only in its original's slot", where a hidden part's copy in a slot its
  original's outranks changes nothing too (V2's `relabel6`), the tests bullet and M3-notes giving the mutant
  `fixA_sameSlot` the same words; two summaries saying no Ctrl+D copy left in place changes anything, a few lines before
  a relabelled one that does; and the 22,243 copies said to keep the design valid, 615 of them on 105 designs invalid
  without any copy (V2's `ctrlvalid`, above). The lead's ruling (the build notes' `shift_journal.txt`, 19:50): each
  round had stated fix A's consequence as a list of cases, and each list missed a case of the order, so round 7 states
  it by the order alone, in one sentence used wherever the copy rule appears (§4.3 and §17.2's hidden-parts row in full,
  §5.6's hidden-cores row and README with their parentheses dropped, item (1) above, M3-notes, and the plain words in
  plain words), its measured cases labelled as examples in item (1). The ruling's sentence named that order "the
  measure's rank (§4.4)", but overlaps go by §4.3's priority, kept parts, then slot rank (§3.7), then the measure's rank
  (`MassProps.ownership`), and across slots the measure's rank alone, whose cleaned parts go by the material's name
  first and by the slot's name late (Grip before Guard), differs from it three ways (fixer AB's `rankslot`, on V1's
  `S4`, V2's box and `boxedF2`, every build through `Canonical.draft`; round 6 and `f7ac37d` alike): a hidden Steel
  part's copy painted Iron in a slot its original's outranks changes nothing (`S4`'s filler 18 in the Grip or the
  Pommel, V2's box filler in the Guard, `boxedF2`'s filler 18 in the Guard), where the part itself so changed moves the
  mass +3.2542e-5, +2.3595e-4 and +1.0816e-4 kg (`f7ac37d` +1.0140e-4); `S4`'s Iron filler 18's copy painted Steel in
  the Blade takes its place, the mass +2.1069e-3 kg, the balance +3.7069e-3, G the same, filler 17's owned volume
  0.0153097 → 0.0032616 and the copy's 0.0139784, what 18 itself so changed gives (the mass and the owned volumes to the
  bit, the balance within 5e-16, the parts summed in another order); and a copy of `S4`'s filler 17 in the Grip changes
  nothing, where 17 itself in the Grip moves the mass +2.3865e-3 kg. So the sentence reads "the priority above (kept
  parts, then slot rank, then the measure's rank of §4.4)". Kept originals follow it too (fixer AB's `keptcopy`): each
  of F2's four parts copied into every other slot and material, in the 16 cases where the part itself so changed is
  measured (round 6 and `f7ac37d` alike), leaves the mass, the balance and G as they were where the verdict cleans the
  copy, and where it keeps it (a Guard part's copy in the Blade or the Grip, the Pommel's in any other slot, whose
  slot's name comes first) gives those of the part itself so changed. Also written: the summaries quote the sweep
  (above), V2's 22,243 split (above), §5.6's and §17.1 O11's near-copy figures replaced by a pointer to the round-3
  bullet, and README and the plain words say S-PAR-02 passed on round 5's code (3 fresh Play sessions, 2026-11-19),
  which rounds 6 and 7 leave byte for byte. As built against round 6: no source or test changed (`src` and `tests` byte
  for byte `shift-r6`'s), so nothing measured moves; `--quick` in the working tree, run once (20:10:14–20:10:42, no
  other Lune process at its start or end, the machine 12–18 % busy, median 15 %, its own Lune counted): 720 pass, 56
  skipped, 27.06 s.
- **Goldens and the digest** (re-blessed under `BALANCE_VERSION` 1, as M1–M3's rounds were, before the first release,
  §14.9): T-DIF-12's calibration golden C04's 13 leaves above and Joints on C05, C07, C08, C11 and C13; its regression
  golden Joints on X03, X04b, X04g0.010, X06-0.01 and A24; the cost golden unchanged. S-PAR-02's digest: the fixtures'
  group 136 designs, 425,658 → 425,673 bytes, fnv1a32 60321529 → 1001114566 (those 11 fixtures' lines); the generated
  group 200 designs, 709,366 bytes, 611215233, unchanged. `Factors.spec`'s units by caller (a probe or a sample charges
  a unit per higher part, and a flush part is one no more): F5 on All, Thinness 4921 → 4715 and Asymmetry 11069 → 9746;
  F4 5644 → 5564 and 19264 → 17849, on the Blade 2208 → 2178 and 10069 → 9796; P5 14848 → 14642 and 21409 → 20086.
  `Reference.spec`'s refined cells, fewer than the prototype's now that a flush part makes no job: C04 2016 → 1184, C06
  1352 → 676, C09 5320 → 4240, F1, F5 and P5 676 → 0, F3 1282 → 490. Round 2: the regression golden X02's record (84,808
  → 84,817 bytes), `parity_designs.bv1` C11's and X02's hashes, the digest's fixtures 425,673 → 425,707 bytes, fnv1a32
  1001114566 → 262377556 (`parity.bv1.digest.txt` 132 → 131 bytes), the generated group, the calibration and the cost
  goldens unchanged; `Cover.spec`'s units of the sealed rod 23687.25 → 23662.125 (its 16 walls, tied in two slots, read
  in their new order). Round 3: the regression golden `shift-r1`'s again byte for byte (84,817 → 84,808 bytes: X02's
  record, copies 6–10 cleaned), `parity_designs.bv1` X02's hash, the digest's fixtures 425,707 → 425,675 bytes, fnv1a32
  262377556 → 892272501 (`parity.bv1.digest.txt` 131 bytes), the generated group, the calibration and the cost goldens
  unchanged; `Cover.spec`'s sealed rod 23687.25 again (its walls in the world planes' order). Round 4: nothing moves,
  every golden and the digest round 3's byte for byte; round 5 neither, every golden and the digest round 4's byte for
  byte, nor round 6, which changes no source.
- **Ids and mirror images, the fix against `f7ac37d`.** Round 1 (fixer S): ids (3 shuffles a design; steps and edge by
  `Dump.canonical`, kept flags and owned volumes per original part): 0 differ on the 3,200 generated designs and on
  every 3rd plausible design (11,130) on both trees; A17 on both, whose two exact copies take the index's tie. Mirror
  images (every part through `Blueprint/Mirror.reflect` across x = 0 and z = 0, then Canonical): the fixtures as on
  `f7ac37d` but 5 whose images moved Joints there and now read their original (C05, C11, X04g0.010, X06-0.01, X06-0.05),
  the generated designs line for line; on the plausible set the X images move G on 3,066 (`f7ac37d` 3,115) and the Z
  images on 3,247 (3,219), the largest the same (0.0849, 0.1174); 16 (X) and 73 (Z) images that read their original on
  `f7ac37d` do not on the tree and 47 and 19 the other way, where the kept grip stands off a centre plane and the new
  order meets a mirrored Wedge's samples, which follow its writing (O11 (i); #9113, C09 with an off-axis Grip rod).
  Round 2 (fixer U): ids, the 109 fixtures with physics, Parity's 200, the seeds' 3,000 and every 3rd plausible design,
  none differs but A17; the images of Parity's 200 and the seeds' 3,000 read as on both trees, the valid fixtures' X 4
  and Z 6 as before; on the plausible set X 3,065 images move G (`f7ac37d` 3,115) and Z 3,220 (3,219), the played flips
  round 1's design for design (`f7ac37d`'s differ by 3 designs each way); against round 1, Joints aside, one Z image
  (#24771) newly differs from its original and 29 read theirs again; an image's \|ΔG\| grows by more than 0.002 on 2 X
  and 2 Z images, two fullers whose walls tied with the core plate are twins about their centre (#24177 0.0003 → 0.0144
  and 0.0149; #24771 0.0066 → 0.0111 and 0 → 0.0118; no tier), and shrinks by as much on 3 and 2. Fixer S's count of
  images whose \|ΔG\| shrank past 0.002 against `f7ac37d`, 8 (X) and 5 (Z), is at G's 4 decimals; in raw doubles, where
  3 and 2 shrink by exactly 0.0020, 11 and 7; the tier flips one tree has and not the other, 6 and 4, count the X and Z
  images whose played or raw tier flips (played alone, 4 step flips on 3 designs each). Round 3 (fixer W): ids, none
  differs but A17 on the same 14,439 designs; every image of every corpus reads as on round 2, line for line, but X02's
  (its as-built change, G the same), so the figures above and below stand; near copies' images keep `f7ac37d`'s parts
  (the fix's round 3, above).
- **What a mirror image still reads otherwise** (O11 (l); the tree's images, by the weighted factors that moved): under
  X, of the 3,065 plausible images whose G moves on round 2's tree (1,548 past 0.002, 22 a played tier, 43 a raw tier,
  up to 0.0849, a fuller), Thinness moves on 2,482 (alone on 1,534: 10 of the tiers), SurfaceComplexity alone on 463 and
  EdgeLength alone on 119 (up to 0.0021, Douglas–Peucker's tie on the reversed outline); under Z, of 3,220 (904 past
  0.002, 25 a played tier, up to 0.1174, a Wedge in a guard), SurfaceComplexity alone on 2,446, every tier among them
  (laminates and laminated hilts 16, fullers 6, ribbed bars 2, a rivet), Thinness alone on 704 (no tier; round 1: 3,066,
  1,549, 1,535, 464; 3,247, 2,473, 695); the X tiers fullers 16, ribbed bars 4, plate edges 2; every flip, either plane,
  within 0.033 of the tier line (\|ΔG\| up to 0.0471). The six property streams' 3,000 generated designs: X 514 images
  (15 a tier, up to 0.2552, Thinness), Z 122 (1); Parity's 200: X 30 (17 past 0.002, Gen 57's tier), Z 6 (up to 0.0053);
  the 98 valid fixtures X 4 (up to 0.0093), Z 6 (up to 0.0363, P3), no tier. The mechanisms, each measured on a scratch
  variant: Thinness' canonical walk signs a local axis up the world (+Y, else +X, else +Z), so an axis that lies across
  the plane points the same way in the image, which walks it from the other end and takes other probes (Gen 57's Wedge
  tip, turned 90° about Y: Thinness on All 0.6456 → 0.2722, Hammering 0.2589 Hard → 0.1095 Normal), and the stride's
  phase carries from part to part in the measure's rank, in which parts tied but for the sign of their place, twins
  about the grip on round 1's tree and about their ties' centre on rounds 2 and 3 (on round 3's, the measure's alone:
  the verdict's swaps only twins about the plane, as on `f7ac37d`), swap order in the image (below); the same twins
  spend the sub-grid budget `N_SUB_WORK`, in rank order, the other way round, so it runs out at other patches (plausible
  #21865, a laminate: SurfaceComplexity 2.4308 → 2.3641, Hammering 0.1689 → 0.1356, Sharpening 0.2077 Hard → 0.1606
  Normal under the Z mirror; with the budget unlimited, `subwork`, `N_SUB_WORK` × 10,000, both read Hammering 0.2113 and
  Sharpening 0.2677 Hard, and on the 4,685 plausible designs whose X or Z image moves G on round 2's tree (round 1's
  4,713 but 28), the Z images moving G 3,220 → 782, SurfaceComplexity alone 2,446 → 14 and up to 0.0006, the Z tiers 25
  → 0, the X images 3,065 → 2,559, tiers 22 → 16, Thinness's; fixer V, the same variant of round 2's tree); and
  Douglas–Peucker's ties on the reversed outline (EdgeLength, up to 0.0021). A walk signed from the design's own centre
  (a scratch variant: a local axis with no Y component pointing away from the kept Grip parts' point, equal axes ordered
  by \|x\| and \|z\|): of the same 4,685 on round 2's tree, the X images moving G 3,065 → 2,833 (tiers 22 → 20), the Z
  images 3,220 → 3,191 (25 tiers; round 1, of 4,713: 3,066 → 2,834 and 3,247 → 3,227); Parity's 200, X 30 → 21, Z 6 → 1;
  the valid fixtures, X 4 → 4, Z 6 → 4 (P3's 0.0363 closed); Gen 57 not at all, its tip centred on the grip's planes,
  where that sign ties and keeps the world's; as built it moves G on 5 valid fixtures (P5's Hammering 0.2167 Hard →
  0.1902 Normal, P3's 0.2752 → 0.3115), 5 of Parity's 200 (up to 0.0179) and 114 of the 11,043 valid designs of every
  third plausible one (no tier, up to 0.0666), the same on both trees. With every volume sample a probe (`allprobes`,
  `THICK_BUDGET` 1e6, stride 1), Thinness reads every image as its original: of every eighth plausible design whose
  image moves G with Thinness (364, the same designs on both trees), the X images moving G 311 → 76 and the Z images 198
  → 105 (106 on round 1), the rest SurfaceComplexity's (the budget) and EdgeLength's (up to 0.0006), no tier (2 before);
  Parity's 200, X 30 → 3 (EdgeLength, 0.0002), Z 6 → 0; Gen 57 Hammering 0.1874 both (as built 0.2589 and 0.1095). So
  Thinness' share is the probes' choice, the walk's sign and the stride's phase, which carries from part to part in the
  rank's order and follows twins swapped in the image.
- **A Grip part hidden off the grip's axis** (fixer T: a Block half the size of the largest kept Grip Block or Cylinder,
  inside it and off its axis, under a fresh id, where the Grip slot has room): on round 1's tree it moved the point the
  verdict's rank read from, not the measure's. Of the fixtures, X01, X01raw and X02, whose blade copies lie 0.003–0.004
  apart in z, keep the other copy (X01: part 4 kept → cleaned, SurfaceComplexity 2.1634 → 2.1954, Joints 12.27 → 8.28,
  PartCount one less; X02 the reverse; G the same, SurfaceComplexity under its range there), and worst valid 8 turns
  `BladeNotAboveGrip` (V4 counts every Grip part, §4.2); the other 89 that take the block read to the bit, C09 among
  them (T-DIF-04). Parity's 200 generated designs: none moves. Of the valid plausible designs, 32,680 take the block
  (429 have no kept Grip Block or Cylinder, or a full slot) and none moves. On round 2's tree the block ties with no
  part and moves nothing (above), nor on round 3's, whose verdict reads no point (fixer W's `hgkept` on X01, X01raw and
  X02).
- **A whole design moved along X** (O12; fixer T on round 1's tree, whose census moves rounds 2 and 3 read the same: 16
  moves on every third plausible design, the 11,043 of 11,130 valid as built, every fixture and Parity's 200 generated
  designs, as G with Asymmetry, EdgeLength or both held as built): with both held G moves on no design at any move.
  Moved 1e-6, G moves on 43 plausible designs (up to 0.0012: a plate poking exactly 0.05 out, at Asymmetry's reach,
  changes its ladder's rung); 0.0001, on 2,553 (23 %), none past 0.002; 0.0005 and 0.0007, 32 and 33 %; −0.0007, 32 %
  (one tier, by Asymmetry, a step 0.0014 over Hard); 0.0013, 4,347 (40 %, 2,548 past 0.002, 9 a played tier, up to
  0.0071: the census's 13,129 of 33,389 is no artefact of the raster's 0.0013 sample offset); 0.002, 47 % (10); ±0.005,
  72 % (39 and 40, up to 0.44 where a chain breaks: a riveted rapier's edge 1 → 4 chains, Sharpening 0.6410 → 0.2237);
  0.01, 73 % (24); 0.02, every one (76; the edge on 23 alone, its columns a whole cell over); 0.03, every one (1,557 a
  tier, 14 %); 0.05, every one (4,775, 44 %, up to 0.3079); 0.1, all 10,154 still inside the hitbox (6,865, 68 %); a
  random move inside the hitbox, 98 % (58 % a tier, up to 0.3694). Asymmetry moves G on 23 % at 0.0001 and on all from
  0.02; the edge on 1 % at 0.0001, 16 % at 0.0013, 61 % at 0.005–0.01, 0.2 % at 0.02 and 1.4 % at 0.1, whole cells over.
  The 96 valid fixtures inside the hitbox: 0.0013 moves G on 33 (1 a tier: worst valid 8's two chains are one,
  Sharpening 0.5217 → 0.7554, as at +0.002, +0.0034 and +0.005, and three at −0.005 and −0.0103); 0.05 on all 89 (55).
  Parity's 200: 0.0013 on 106 (1 a tier, Gen 98, Sharpening 0.2027 Hard → 0.1931 Normal), 0.05 on all (104).
- **O12's options as transforms of the analysed copy** (fixer T: the tree reads an X move to the bit but for those two
  reads, so a copy moved to put the option's reference on x = 0 reads as that option would; analysed with the hitbox
  widened along X, which only V2 reads): (ii) the kept Grip parts' point: on 21 of the 98 valid fixtures the point is
  off x = 0, and G moves on 20 (17 past 0.002), 2 a tier (A27: Sharpening 0.0989 Normal → 0.2391 Hard, the blade now
  read 0.04 off its plane; worst valid 11, Hammering 0.1803 → 0.4389 Hard); on the 33,109 valid plausible designs, 93
  (none a tier, up to 0.0047, rods set in the grip off its axis); Parity's 200, none; (iii) the centre of every part's
  extents: 24 valid fixtures off centre, G on 23 (19 past 0.002), 4 a tier (F4 and C05, Sharpening 0.3420 → 0.1636 and
  0.3466 → 0.1964 Normal; A07a and A27 Normal → Hard; up to 0.1784, F4); plausible 7,787 (24 %), 5,076 a tier, up to
  0.2214, every flip on a cleaver's base (F4 2,635, C05 2,441), Sharpening Hard → Normal but 8 Hammering, the sabre
  C06's 2,203 moving without a tier; Parity's 200, 8 (up to 0.0312, no tier); (iii') of the kept parts' extents: the
  same, plausible 7,779, 5,076 a tier. Each closes the move: the option on a design moved +0.0013 or at random inside
  the hitbox reads as on the design (every 3rd plausible design and every fixture and generated design tried: G the
  same, Asymmetry within 1.3e-14; on round 3's tree near copies across x = 0 still swap under (ii), the verdict's rank
  standing on the plane, O11 (j)).
- **Cost** (fixer S: `Analyze.run` alternating with `f7ac37d` in one process, a collection before each run, every worst
  valid design and P1): four runs of 31–61 rounds, 0–22 % busy (medians 4–5 %), the tree / `f7ac37d` 0.9716–1.0104 per
  round, sums 0.9931–0.9990; per case worst valid 8 × 0.9977, worst valid 5 × 1.0015 the largest: nothing measurable.
  Worst valid 8, the slowest valid design, reads 57.0–57.9 ms on `f7ac37d` in that harness and 57.1–57.4 ms in T-PERF-01
  by process, 56.8–59.4 ms on the tree: the 57 ms gate's margin (§14.11) is gone on this machine at this hour whichever
  tree runs. `--quick` 29.25 and 29.59 s quiet, 716 pass (`f7ac37d` 28.99 s, 707); `scripts/verify` green three times at
  medians 7–8 % busy (758 pass, worst valid 8 at 57.32–59.41 ms), failed on T-PERF-01's timing alone at medians 31 and
  40 % (worst valid 5 at 60.84 ms; F2's longest stretch 0.357 ms), and fixer T's two at 28–77 % and 19–82 % (medians
  57 and 56 %) on C01's and F2's longest stretch, 0.382 and 0.411 ms (no quiet half hour between them). Round 4 (fixer
  Y, Reviewer V2's `timing3`: the tree, round 3 and `f7ac37d` rotated in one process, 21 rounds in each of two orders,
  medians 7 and 8 % busy): the tree / round 3 × 1.0008 and × 1.0006 (per case 0.966–1.024), the tree / `f7ac37d` × 0.998
  and × 0.995; T-PERF-01 alone, twice, at medians 16 % (this run's Lune 8 % of it): pass, worst valid 8 at 57.70 and
  57.19 ms, the F, C and X fixtures' longest stretch 0.274 and 0.279 ms (C01); `scripts/verify` at 12–51 % (median 17
  %), green, 775 pass, worst valid 9 at 58.33 ms, F2's longest stretch 0.273 ms. Round 5 (fixer Z, the same `timing3`:
  the tree, round 4 and `f7ac37d`, 21 rounds in each of two orders, the M4 team's Lune processes not yet running,
  medians 10 and 18 % busy): the tree / round 4 × 0.995 and × 0.997 (per case 0.947–1.057), the tree / `f7ac37d` × 0.996
  and × 1.001; `scripts/verify` at 12–43 % (median 17 %), green, 776 pass, worst valid 8 at 57.78 ms, C01's longest
  stretch 0.273 ms, where twice before, at medians 20 and 23 % with the M4 team's Lune beside it, it failed on
  T-PERF-01's timing alone (60.28 and 66.41 ms). Round 6 (fixer AA) changes no source; `scripts/verify` in the working
  tree failed on T-PERF-01's timing alone at 16–89 % and 15–42 % busy (median 22 % each, with Roblox Studio open beside
  it: worst valid 8 at 62.42 ms, worst valid 9 at 60.88 ms), and was green at 16–36 % (median 22 %), 776 pass, worst
  valid 8 at 59.165 ms. Rounds 7 to 10 change no source; before the commit the lead's `scripts/verify` failed on
  T-PERF-01's timing alone at 7–30 % busy (median 16 %, agents writing notes beside it: worst valid 8 at 61.17 ms) and
  was green at 10–36 % (median 14 %), 776 pass, worst valid 8 at 57.573 ms; `--quick` 720 pass, 56 skip, 28.02 s at
  13–18 % (median 15 %).
- **Tests** (`tests/Physics/Invariance.spec` T-DIF-07 (a) to the bit, and a pin for each guard on the design it moved,
  each failing with its guard alone reverted: §14.6): the ranks, X01 0.037 along ±Z (the verdict's: the kept copy), C09
  0.0013 along ±Z (the measure's, and its places quantised: SurfaceComplexity 0.00105) and P5 0.0013 along −X (\|x\|:
  Thinness 0.0662); the hidden Grip part, C09 with a Grip block hidden off its axis (from every Grip part the measure
  moved 0.3201 → 0.3196); the flush part, C09's pommel housed in a block moved along Y (at margin 0, ten owned volumes);
  the cells, C09 at the hitbox's Z edges; G's grid, F4 with a plate on its guard moved along Y (0.4593 → 0.4592);
  contact, C07 ±0.0013 (the contact rows, Joints 0.176) and C02 with a plate on its guard moved along Y (V3, 1.58); and
  at unit level `MassProps.spec`'s flush bar, tangent Ball, 4 cells at 4 + an ulp and a box 1e-17 thick,
  `Factors.spec`'s Asymmetry estimate at exactly reach (800 against 640 at 0.111 up Y) and `Difficulty.spec`'s x an ulp
  either side of 0.45925. Round 2 (fixer U; 769 cases): the twins (P5's tooth 7 at 1.4 + 0.2 moved 0.13, tooth 6 an ulp
  up moved 0.411, F2's blade again an ulp lower), the speck chain (P5's grip copied 4e-8 and 4e-9 with a Grip speck),
  the ids (P5's grip copies 3e-10 apart), the grip's 1e-9 nudge, a hidden Blade twin and ownership, a Wedge hidden among
  P5's teeth (the walks, and the exposure's measure under a planted `N_SUB_WORK`), F2's pommel at exactly `CONTACT_TOL`
  (V3's broad phase), a Ball pommel so (the contact rows' margin), and Reviewer V1's unit pins (`Verdict.spec`'s ties'
  centre, half step and `RANK_Q`; `MassProps.spec`'s cells and overlaps; `Difficulty.spec`'s grid; `Factors.spec`'s
  candidates); 33 mutants of the ranks and guards, each failing the quick suite on an assertion, none on timing alone;
  round 1's source fails the round-2 pins aimed at it. Round 3 (fixer W; 772 cases): round 2's verdict-centre pins
  dropped and `f7ac37d`'s back (`Verdict.spec`: \|z\| before z, the image keeping two parts that differ in \|z\|, twins
  at ±z by z; F5's blade copies 0.002 apart, copies 1–5 cleaned, each reading its strip within 1e-9; X02's fixture, five
  of six copies cleaned; Cover's sealed rod 23687.25); Reviewer V1's and V2's twin-height pins; the hidden duplicates
  (C09 with its core 2.3 long and again 0.001 along +X, that copy again or the core again 0.0005 along +X; #1940's
  laminate on C02, its core again 0.002 along +Z and that copy again) and the mirror (that laminate across z = 0), each
  failing on round 2's source; X01's whole-design case pins the residual (0.037 along ±Z, the blade between its copies
  cleaned, every step as built); and from 18 mutants of the ranks (15 failing the suite first), the three survivors
  pinned (the measure's ties without the height or the volume; `RANK_Q` 5e-10), as are Reviewer V2's four guard-constant
  survivors (`OVERLAP_TOL` 2e-7, `CELL_EPS` 1e-8, `CONTACT_REACH` + 5e-9, `MIRROR_GUARD` 1e-8), `OVERLAP_TOL` within 1.5
  times its value, the other three at 5, 3 and 5 times, so that mutants at twice them passed the whole suite (review
  round 3; round 4 pins each within 1.5 times, below). The prototype's order (`Reference.spec`,
  `DifficultyHelpers.inRankOrder`, `Edge.spec`) is the verdict's rank order with the kept parts in the measure's, which
  changes its input on X02 alone. Round 4 (fixer Y; 775 cases, 3 new): the hidden parts' ownership (Reviewer V2's box
  laid along Z, an Iron and a Steel filler with a Ctrl+D copy, two Iron fillers moved 0.05 down Z), the ids (two Iron
  Dust Balls along Z) and the mirror copies (Dust Wedges turned 30° about Z, the Z image part by part), each failing on
  its mutant (round 3's measure, the world's planes for cleaned parts, V2's repair as given, fixer Y's first form, the
  turn before the place); Reviewer V2's guard pins at 1.5 times, Reviewer V1's at half the guard and his half step on
  either side, V2's x unrounded, each failing on its mutant (12 mutants, each on the assertion aimed at it); and 8 fast
  cases moved to `t.slow` for the `--quick` gate (§14.1, §14.6). Round 5 (fixer Z; 776 cases, 1 new): fix A's pin (a box
  on F2's blade with two Guard fillers and a Pommel filler under them, one Guard filler again in place: every owned
  volume, the mass and the balance) and the reviewers' round-4 pins merged (V1's Iron box with a copy and moves along
  ±Z, V2's ids pin's Z image, the mirror pin's X image, V1's measure's rank with no part kept, its kept parts before the
  cleaned ones and kept twins of two materials, `CELL_EPS` from below at half and `CLIP_EPS` either side), each failing
  on its mutant (13 mutants, each on the assertion aimed at it); and 6 fast cases moved to `t.slow` for the `--quick`
  gate (§14.1, §14.6). Round 6 (fixer AA; 776 cases, none new): fix A's pin gains Reviewer V1's cases (his
  `pins_round5.diff`: the copy relabelled Pommel or in Steel, or a wall again; a Pommel filler in the cavity's corner
  under two walls, the first again; two Guard fillers at one centre, which is no copy) and fails on each of his six
  mutants of fix A on the case aimed at it (fix A undone; a new part compared with the higher set's last member alone; a
  copy deduped only in its original's slot, the mutant `fixA_sameSlot`, or only in its material or only with a cleaned
  original; a part at a counted part's centre left out), five of which passed `--quick` and `Invariance`, `MassProps`
  and `Parity` whole before (V1's `mutrun5b`). Round 7 (fixer AB) changes no test.

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
Hard (S8 sizes the 10⁻⁵ claim at 300,000 runs); exact times flagged 100 %; σ 4 ms synthesized input 0 % of these
2 × 2,000 runs (score 1.000), about 0.04 % of 12-strike runs (Normal), 0.008 % of 15-strike ones (Hard): their errors
spread less than 1.5 ms by chance (M4's pinned 2,000 runs, the tiers alternating, flag 2, E-S3.10).
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

### E-S3.10 M4 as built

From slices 3–5, measured as `docs/build/M4-notes.md` (B2) says:

- The build reproduces E-S3.4's TimingStrike golden (N 12, W 110, core 13.2, M 200, 10971 ms, 0xE2D4F2AE, the
  worked presses' points and score 0.8084), E-S3.7's HoldZone golden (10 keys, 0x4E2677F2, the 300 ms taps' 0, the
  stroke curves) and E-S3.5's trace golden and all nine rows of its blade table exactly. On random configurations it
  matches the prototype's generate, replay and checks bit for bit (TimingStrike's judged errors; HoldZone's
  unquantized credit, n, T and F; the trace's source, path arrays, hash and unquantized accuracy, pace and coverage
  sums).
- The S3 prototype's groupings that differ from the SPEC's pseudo-code: HoldZone's `F − F·(10/fireDecayMs)` and
  `F − F·10/fireDecayMs` differ in the last bit for 0.10 % of uniformly random F at 600 (1.0 % / 1.8 % at 300 / 550),
  which the full-precision parity sees in the shipped runs; the trace's travel time is `ceil(L/pacerSpeed·1000/20)·20`.
- The trace's cross-axis clamp (`E = 0.76/(s·range c)` under 2) never binds on the nine reference blades (the widest
  0.6 stud: 2.11).

From `docs/build/M4-notes.md` (B3):

- The Recorder's stamps equal the S3 prototype bots' on random frames (12 runs at 30–240 fps: every press at
  `Bots.stamp`, every trace sample at `ptHuman`'s due rule, the first at t = 0 instead of floor(f₁)); D7's exact clocks
  give every integer ms up to 60,000, where t/1000 falls short for 372 of them.
- L6's proof: after GO's record each trace record lies in a later 20 ms slot than the one before, so a Recorder makes at
  most `floor(durationMs/20) + 1` (1,551 at 31 s) whatever its frames, hitches or focus losses; a property over frame
  times 1–100 ms with hitches up to 250 ms at the longest MVP step confirms it, and `judge` refuses more.
- The host loop (§12.5 with the horizon and the final push) finishes as `judge` on random frames, offsets −120…+120,
  focus losses and inputs after the last frame, in all three families, its live score ending at the score; advancing
  TimingStrike to the raw frame time with offset +120 turns a judged press into a whiff (E-S3.4's span 1).
- The codec: one hand-written byte golden per family; every decode reason planted and read; 2,000 garbage values and
  structured timelines per family never throw.

From `docs/build/M4-notes.md` (B4):

- Parity: `Bots.run` with the prototype's seeds reproduces the first 100 scores of each of the 48 cells of
  `S3-score-distributions.luau` exactly (4,800 of 4,800), each timeline judged Ok within the judge's caps and the
  prototype's own session ending on the build's unquantized sums; resolved params (3 families × 2 materials × 5 tiers ×
  4 x) and pattern arrays (seeds 1–20 per family, tier and material) equal the prototype's to the bit. Every fixed-seed
  L3 outcome is therefore the prototype's, precomputed before the build (D11).
- Golden (b), `minigames.bv1`: 144 pattern rows, 12 scripted results and the results of 24 frozen bot timelines
  (`MinigameTimelines`, 32,187 bytes: HoldZone 246–354 B, TimingStrike 36–44 B, the trace 2,301–4,261 B, its first
  record the cursor at GO). The libm canary on the build machine: 572967914.
- The build's per-run costs through the Recorder (44–66 % busy): HoldZone 0.88–1.35 ms (Perfect 1.94), TimingStrike
  0.12–0.28 ms (Elite@240 0.61), the trace 7.4–8.9 ms (on the pacer 1.96), about 15–30 % over the prototype's.
- T-MG-03 (1,000 runs per cell): HoldZone Perfect's means 0.9856 / 0.9880 / 0.9659 / 0.9699 (Iron N, Steel N, Iron H,
  Steel H) and lowest run 0.8828 (floor 0.85), every run flagged `HzInhumanRate`; TimingStrike@60 and the trace 1.0000
  on every run. T-MG-11 (1,000 per cell): the lowest Perfect@30 run 0.9613 (Hard Steel x = 1; floor 0.95).
- T-MG-04 (400 runs per cell; 1,000 for Average and Good): every mean within its band (the worst at 0.67 of it), no run
  flagged, Q8's fail rates inside their bands (the smallest margin 2.3 points, HoldZone Iron/Normal Average 5.3 %).
  T-MG-05: every profile order holds; Average's Normal → Hard drops 0.068–0.098, the smallest other 0.0052.
- T-MG-06 (paired): Iron − Steel 0.0153 (HoldZone, 4,000), 0.0086 (TimingStrike, 20,000), 0.0130 (PrecisionTrace,
  4,000). T-MG-12: the SD of the per-pattern means 0.046 / 0.051 (HoldZone N / H), 0.022 / 0.021 (TimingStrike), 0.025
  / 0.014 (the trace), against 0.08.
- T-MG-10 false positives, 0 flagged in every case: TimingStrike 1.2 million runs (the smallest SD of the judged errors
  2.78 ms at Elite@240 Normal, flag < 1.5; the largest exact share 0.500, flag ≥ 0.90); HoldZone 20,000 (at most 9
  presses in 1 s, flag 30); the trace's 30 fps / 360 px halves (smallest mean deviation 0.00279 / 0.00259 u, ×3.49 /
  ×3.24; 0.1 % quantile ×3.8; smallest mean jerk 0.00409 / 0.00404, ×20) and its other devices (×3.55 / ×3.70 / ×6.78).
- T-MG-10 true positives (2,000 runs each): Exact flagged `TsExactHits` and `TsLowVariance` every time, clamped to the
  pass line; the trace on the pacer `PtTooPrecise` and `PtTooSmooth` every time, every 200 ms `PtSparse` every time;
  HoldZone's exact-state Perfect 100 of 100 (up to 50 presses in 1 s) and a 30/s autoclicker 2,000 of 2,000. Accepted
  (Q17): σ 4 ms TimingStrike noise flagged 2 of 2,000, mean 0.9999; 0.004 u trace noise 0, mean 0.9856.
- T-MG-15 (1,000 runs per profile and offset): Elite@240 and Good unflagged at every offset −120…+120. The offset
  offer in the Recorder's terms (the plan's [6.3]): Average Iron/Normal TimingStrike (x = 0.10, salt 1), 2,000 runs,
  scores 0.6482 at offset 0 (its mean `meanErrMs` +33.5), 0.7124 at +35 (−0.9) and 0.4790 at −35, so the results
  card's offer `timingOffsetMs += round(meanErrMs)` moves the right way.
- T-MG-09 (1,000 bot runs per family, the four profiles and Perfect on both tiers and materials): the live session
  equals the judge on every run, and so does §12.5's host loop replaying the inputs on another device; the timelines'
  bytes min / mean / max HoldZone 189 / 363 / 1,128 (the exact-state Perfect makes the long ones), TimingStrike 30 /
  39 / 46, the trace 2,294 / 3,741 / 4,317 (its first record the cursor at GO).
- The build's L3 times (indications, the machine shared): M4's plain L3 173.33 s at 6–76 % busy; its volume cases
  573.5 s at 3–27 %.
- I5's stale lines stay where they are, noted here: `out/golden.txt`'s HoldZone `driftSpeed` 0.2625 predates the Volume
  term's +0.15 (E-S3.3's 0.2415 is right); `out/det.txt`'s HoldZone bytes 198 / 295 / 408 are another run's (E-S3.6:
  198 / 293 / 396); v2 `Bots.luau`'s comment "an 800 ms look-ahead" is 300 ms in its code (§16.23); §6.13 and the v2
  README place the distributions in a `final/` folder that does not exist (they are `v2/out/`). None moves a value M4
  asserts.

From `docs/build/M4-notes.md` ("Fix round 1"):

- The edge hand-off's Douglas–Peucker attempts share one split tree: each segment's first farthest point is found once,
  a tolerance keeps the splits whose distance exceeds it from the root down, and a segment splits only when its loop
  found a farthest point, so a NaN coordinate cannot loop. The sources are the prototype's by construction;
  `Minigames/PrecisionTrace` pins them (the saw and the zigzag turned 13° and 25 random chains at the slowest and
  fastest MVP pacer in the quick run, 200 chains at all 12 under `t.slow`), and a probe of 300 random chains (zigzags,
  walks, combs, straight runs, repeated points, closed loops, up to 300 points) at the 12 pacers gave 3,600 hand-offs,
  1,050 through Douglas–Peucker, 0 differences. `prepare` on `Cost.X08_EDGE`, E-S3.5's zigzag, takes 1.08–1.09 ms (the
  hand-off 0.81–0.82, its eight attempts; `generate` 0.24–0.26) at 3–19 % busy, against the round-1 build's 4.05–4.10 ms
  (its hand-off 3.75–3.80) in the same alternating runs. On the other eight reference blades the hand-off takes ≤ 0.03
  ms but on the saw (0.25, its six attempts; 0.56 before), and on a 256-point chain at the length bound 0.12 ms (seven E
  shrinks, no Douglas–Peucker).
- The trace's record cap bounds the count `judge` replays, not its cost: on the length-bound source, 1,479 records
  spread over travel cost × 1.017–1.043 the honest timeline's (six runs of 401–1,201 rounds at 34–68 % busy; reviewer
  V1: × 1.019–1.027 at 7–26 %).
- TimingStrike's decisions follow the Recorder's horizon, so with a negative timing offset they come early: on E-S3.4's
  span 1 (T 489, M 200, W 110, the drawn window 379–599 ms), at 60 fps with no press, the live `Miss` fires at 588.3 ms
  on the raw clock at offset −120, 100.7 ms before T + M with the needle still in the drawn window, and at 655.0 /
  705.0 / 771.7 / 821.7 ms at −60 / 0 / +60 / +120. The view's `cycle` is 1 from the countdown through cycle 1 (2 from
  847 ms), so the host plays the first `CycleStart` at GO.

From slice 10 (the lead, 20 Nov): T-PERF-02 (`tests/Minigames/Perf.spec.luau`, `t.slow`) run alone twice on the merged
tree, medians of 15 rounds in ms Lune; the load was not sampled in the two-second runs, and was 10–19 % in the half
minute after them.

- `judge` at each family's cap, against `REPLAY_BUDGET_MS` (8): HoldZone Steel/Hard x = 1 with 1,024 records
  0.376–0.428, TimingStrike Steel/Hard x = 1 with 512 presses 0.155–0.164, the trace at its record cap with 1,479
  samples spread over travel 2.406–2.448, against 2.343–2.352 on the honest timeline (× 1.027–1.041); decode alone of
  2,048 samples 0.089–0.090, which `judge` then refuses `TooMany`.
- `prepare` (the hand-off + `generate`), against `PT_GENERATE_BUDGET_MS` (5): X08a (P2) 0.123–0.128, X08b (P1)
  0.503–0.511, X08c (P5) 0.142–0.147, `Cost.X08_EDGE` 1.050–1.079 (the hand-off 0.802–0.814, `generate` 0.240–0.258),
  and the length-bound chain 1.877–1.883 at Iron/Normal x = 0 (0.108–0.109 + 1.766–1.768) and 2.471–2.473 at Steel/Hard
  x = 1 (0.089–0.090 + 2.366–2.393); HoldZone's and TimingStrike's `generate` at most 0.021. X08b's edge from
  `Analyze.run` is a 2-point main chain, which the hand-off refuses as short, so its figure is `generate`'s fallback.
- Times 2.6 against §10.5's 7 ms, the largest are `prepare` on the length-bound chain at Steel/Hard, 6.42–6.43, and the
  trace's `judge` spread over travel, 6.26–6.36: none past it.

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
| `TooComplex` | "Too complex to analyse" · "Use fewer overlapping parts, or overlap them less" (no part highlighted; SPEC §4.4's cap, E-S2.12) |
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
| A14 | F1 + 19 attached 0.05 cubes (dust) within slot maxima | valid; the cubes cleaned (Dust); D, the steps and the edge bit-identical to F1's (M3; stronger than the \|ΔG\| ≤ TOL_DUST_G once written) |
| A15, A18 | F1 + 2,000 parts; 10,000 parts, 1 MB strings, 100-deep nesting | `TooManyParts` / Guard `E_BAD_REQUEST` before per-part work |
| A16, A17 | F1 + parts inside blade and guard; F2 + 3 exact blade copies | Enclosed; D bit-identical |
| A19 | draft as string, number, array; parts as a map; wrong types; unknown fields | `Malformed`, never a throw |
| A20 | shape "Sphere", slot "Hilt", a disabled material | `UnknownId`, `SlotNotInType`, `DisabledId` |
| A21 | 13 Blade parts | `SlotTooMany` |
| A22 | only Blade part dust; only Blade part enclosed in the guard; only Grip part enclosed | `SlotMissing` (Cleaned) each |
| A23, A24 | a side exactly MIN_DIM; blade 0.02 × 3.0 × 0.02 | valid, finite; Thinness = 1, never above; A24 plays Hammering Hard (0.40) |
| A25–A27 | F1 + enclosed 20° grip core / ring grip + 40° strap / hilt shifted 0.04 in X (R3-01) | ΔD ≤ 0.01 / ≤ 0.02 / Sharpening ΔD ≤ 0.02 |
| A28 | 24 thin rods (0.02 × 1.2) in one bundle, 0.004 apart across, 0.01 deep, Blade above Guard above Grip (M2) | `TooComplex` alone: the verdicts spend 1,083,869 units, past `VERDICT_WORK_MAX` (E-S2.12) |
| X01, X02 | F5 + 2 blade copies at ±0.003; 6 copies at k·0.002 (R3-02) | \|ΔD\| ≤ 0.01 against the union-equivalent single blade (0.066 / 0.072 thick); against F5 the change is the real thickening (E-S2.5) |
| X03 | F4 + a 0.0003 stud³ fin (R3-03) | ΔThinness ≤ 0.02; the fin's two chains as measured (Sharpening 0.3420 Hard → 0.1980 Normal, E-S2.5) |
| X04 | blade from 4 strips; 5 and 10 segments with 0.004–0.009 gaps; grip nudge 0–0.02 (R4a-02) | \|ΔEdgeLength\| ≤ 2 % |
| X05 | segment gaps 0.002–0.009, overlaps 0.005–0.05 (R4a-03) | \|ΔG\| ≤ 0.01 |
| X06 | blade offset sweep 0–0.05 in X (R4a-04) | \|Asymmetry − continuous oracle\| ≤ 0.02 |
| X07 | laminated plates, overlapping segments (R4a-07) | \|ΔG\| ≤ 0.01, mass error ≤ 0.5 % |
| X08 | 24 rotated cylinders; 24 hitbox-sized blocks; sawtooth blade; 256-point zigzag edge (R3-07, R3-08) | §14.11; the first three are aliases of S2's cost fixtures, X08a = P2, X08b = P1 (its first P1 was 24 overlapping hitbox-sized blocks), X08c = P5 (`tests/fixtures/Cost.luau`); the zigzag edge is an `EdgeChain`, not a blueprint, for M4's T-PERF-02 |

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
  balance toward the hand · 08 the physics frame and the guard line from the kept Grip and Guard parts, V4's from every
  Grip part, the difficulty frame the kept ones' point (a hidden strap, Guard or Grip block steers nothing) · 09
  cleaning: Dust and
  Enclosed only, duplicates Enclosed (lowest id kept among copies of one slot and material), partial overlaps kept; the verdict's rules and its precision
  (E-S2.11) · 10 overlap mass error ≤ 0.5 % (X07).
- **T-DIF** 01 P-RANGE, caps · 02 soft OR: §5.1's formula, its identities, 101 × 101 grid, a planted term · 03
  boundary, NaN errors, `tierRaw` unclamped ·
  04 enclosed, duplicates and dust bit-identical · 05 Iron ↔ Steel · 06 monotone Thinness, PartCount, EdgeLength ·
  07 invariances · 08 mirrored Asymmetry · 09 step scoping · 10–13 as §14.6 (12 the §5 table's goldens, 13 the
  regression relations). **T-EDG** 01 `Physics/Edge` as §14.6: F5's chain, E-S2.9's edge and cutIndex columns and the
  prototype's edge, X04, P5's comb, §4.6's rules and boundaries, invariance, P1's budgets, each loop's units by caller.
- **T-RNG** 01 vectors from E-S3.1 (cross-checked against `rng_ref.py`), with the four game tags' FNV-1a values,
  `mul32` and `hashU32` cases, seeds 0 and 2^32 − 1 and one HoldZone stream's `range`, `int`, `chance` and `sign`
  (`kat/`'s xorshift32 was S8's stand-in, superseded by S3's xoshiro128\*\*) · 02 determinism, every method, 10,000
  draws · 03 `Rng.new` refuses a seed that is not a u32 integer · 04 χ² over 16 buckets < CHI2_CRIT, 20 streams
  (seeds 1, 2, 3, 0xC0FFEE × "" and the four tags) and `int(1, 16)`, n = 160,000 · 05 1,000 derived tags
  ("T-RNG-05/<i>") and the four game tags: distinct hashes, initial states and first outputs at seeds 0, 1, 2^32 − 1 ·
  06 independence, 2-D χ² on 4 × 4 cells: the game-tag pairs, seeds s and s + 1, and lag-1 pairs taken
  non-overlapping (overlapping pairs exceed 37.70 with probability 0.0049, not 0.001). With fixed seeds every χ² is
  known for an exact port (highest 30.87, 22.50 for `int`, 28.20 for 06).
- **T-MG** 01 `prepare`/`judge` deterministic, StepSpec complete · 02 `passed` ⇔ Ok ∧ score ≥ pass line · 03
  solvability (the mean and every run) · 04 bands, fail rates (L3) · 05 profile order, Normal → Hard drop · 06 Iron −
  Steel · 07 `Params` = product of modifiers, S3's clamp and quantum · 08 2,000 garbage values and structured timelines
  per family (200 in the quick run), one hand-written byte golden per family, one planted timeline per decode reason,
  first failure wins, never a throw, through `decode` and `judge` · 09 live session = `judge`: 1,000 bot timelines per
  family pushed in any order §6.4 rule 7 allows, and their inputs played again through a Recorder and §12.5's host loop
  on another device · 10 FP runs (L3V) and TP runs (L3), §14.8 · 11, 13, 14 as §14.6 · 12 fairness · 15 `timingOffsetMs`
  is TimingStrike's alone and shifts every press alike, so the unquantized Exact presses keep `TsLowVariance` at every
  offset and `TsExactHits` only at \|offset\| ≤ 1; press times floored at 0 · 16 releases always recorded (focus loss,
  menu open).
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
  (records past the family cap, bytes past it, a Trace one record past its judge cap) · Malformed (planted values per
  decode reason, each reading exactly it) · Replay (same step twice; an old timeline on a new seed, its duration
  rewritten so the hash refuses it) · Forged (extra keys, other session id). **Gen**: `validSword`, `garbage`,
  `withFiller`, `segmented`, `translated`.

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
  `GetPartsInPart` agree 100 % · 02 digest (M3: of `Analyze.run` with `measureInvalid`, on every fixture of
  `tests/fixtures/Parity`, an A variant through `Canonical.draft` and dropped when refused, then `PARITY_DESIGNS` 200
  `Gen.validSword` from `PARITY_SEED`; one line per design, its name, a tab and `Dump.canonical`; per group the
  designs, the bytes and the fnv1a32 of its lines; `tests/Physics/Parity.spec` blesses it, and `SPar02.spec` runs the
  snippet on a fake engine; M5: of `Pipeline.analyze`, 50 judged bot runs per family and T-CR-08's outcomes too), in
  both datamodels = `parity.bv<N>.digest` · 03 0.1, 1/3,
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
- `BOT_RUNS` 400: SE of a mean ≈ 0.005 (score SD ≈ 0.1); of a 10 % fail rate ≈ 0.015, inside the 3–15 % band. As
  built (M4, E-S3.10), a bot run through the Recorder, `prepare`, the replay and the checks costs 0.12–0.62 ms in
  TimingStrike (0.61 at 240 fps), 0.9–1.4 ms in HoldZone and 7.4–8.9 ms in the trace (44–66 % busy). M4's plain L3
  cases (T-MG-04 with its Q8 extension, T-MG-05, T-MG-09, 11 and 15 slow, the true positives, Reference) take about 3
  minutes; the volume cases (§14.1's L3V) 9.6 minutes more at 3–27 % busy: T-MG-10's FP runs (TimingStrike's 1.2
  million 4.9 minutes, the trace's 23,000 2.4, HoldZone's 20,000 0.3), T-MG-03, T-MG-06's paired runs and T-MG-12 1.9.
  On 20 Nov, in the main tree after the shift fix's commit, the whole plain L3 run (`lune run tests/run`) took 429.2 s,
  959 pass and 21 skip, at 9–22 % busy (median 12 %), and the whole L3V run (`scripts/verify -- --volume`, every case)
  1,062.7 s, 980 pass, at 9–23 % (median 12 %). Run alone the same night (slice 9), M4's plain L3 cases took 88.8 s
  (Statistics) and 11.4 s (FalsePositives) at 11–28 %, and its volume cases 563 s (Statistics' nine 112.6 s,
  FalsePositives' twelve 450.6 s) at 9–30 %.

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
