# S3 prototype v2 (final): minigames, player models, calibration

Lune 0.8.9: `lune run <file> [args]` from this folder. Throwaway code that backs SPEC §6 and §10.5–10.6; the SPEC
text is normative. The files one level up (v1) are the draft's prototype and are superseded.

| File | Contents |
|---|---|
| `Rng.luau` | xoshiro128** + SplitMix32 + FNV-1a tags (unchanged from v1; vectors in E-S3.1) |
| `Params.luau` | `Definitions/MinigameFamilies` stand-in: ordered params, material/tier columns, design terms; `resolve` |
| `HoldZone.luau` | stroke-based bellows (each down record is one stroke), zone path, checks |
| `TimingStrike.luau` | pattern, closed-form judging, 10 ms full-points core floor, checks (sample SD) |
| `PrecisionTrace.luau` | `sidesFromChains`, `edgeToPanel` (grip frame, +N down, E shrink, Douglas–Peucker, 256 points), generation with grid clearance, 2-stage nearest search, evaluation, checks |
| `Timeline.luau` | binary codec and decode reasons (unchanged from v1) |
| `Blades.luau` | reference edges as S2 EdgeChains (arming = S2's F1 main chain, longsword, dagger, sabre, flamberge, tilted grip, serrated, saw, zigzag) |
| `Bots.luau` | `Minigames/Bots`: Elite / Good / Average / Poor profiles, device model (fps, hitches, lag), TimingStrike, HoldZone (tap and hold policies) and PrecisionTrace humans, Perfect bots, stats |
| `Sim.luau` | one cell = (family, material, tier, design x, profile[, fps, policy, offset]) × N seeds |

| Script | Produces |
|---|---|
| `dist.luau <runs> <out.luau> <out.txt>` | **the generator of `final/S3-score-distributions.luau`** and of the E-S3.2 tables: 3 families × {Normal, Hard} × {Iron, Steel} × {Elite, Good, Average, Poor}, seeds `Sim.seedOf(i, 1)`, design x = 0.10 / 0.30, HoldZone tap policy, offset 0; then Perfect / Idle and the variants (30 fps, x = 1, calibrated offsets, hold-only). Final run: `lune run dist.luau 2000 out/S3-score-distributions.luau out/final_table.txt` (≈ 6 min), copied to `final/` |
| `out/load_final.luau` | loads the final module and checks 48 cells × ≥ 2,000 scores and their pass rates |
| `golden.luau` | resolved params, TimingStrike grade bands, golden patterns and scores, HoldZone stroke curves (E-S3.3, E-S3.4, E-S3.5, E-S3.7) |
| `det.luau` | live = replay = codec, timeline sizes, malformed reasons (E-S3.6) |
| `cost.luau`, `worst.luau`, `cost2.luau` | path derivation per blade and costs (E-S3.5) |
| `checks.luau [tsRuns ptRuns]` | false positives on humans, cheats caught (E-S3.8) |
| `perfect.luau`, `multisweep.luau`, `sweep.luau`, `hztune.luau`, `base.luau`, `nearest2.luau` | tuning tools (E-S3.9) |
| `make_appendix_table.py` | formats `out/final_table.txt` rows for the appendix |

Distribution module format (`final/S3-score-distributions.luau`): `runsPerCell`, `passThreshold = 0.5`, `refX`,
`families`, `tiers`, `materials`, `profiles`, `cells = {{family, tier, material, profile, passThreshold, mean, sd,
passRate, scores = {…2000 values…}}}` in that nested order, and `get(family, tier, material, profile) → scores`.
Scores are `math.round(x·1e4)/1e4`, as `Minigames.judge` returns them (unclamped: no bot run is flagged).
