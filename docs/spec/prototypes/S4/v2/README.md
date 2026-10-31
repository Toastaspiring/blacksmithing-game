# S4 prototype v2 (final): crafting rules and item outcome

Lune 0.8.9: `lune run <file> [args]` from this folder. Backs SPEC §7.1–7.5 and §8 (evidence E-S4.*); the SPEC text
is normative. The v1 files one level up are the draft's model and are superseded.

Inputs read live, never copied: S2's `../../S2/v2/analyze.luau` + `fixtures.luau` (physics, D, tiers, governing
material), S3's `../../S3/v2/Sim.luau` (bots and minigames) and `../../../final/S3-score-distributions.luau`
(2,000 runs per family × tier × material × profile). When the prototypes are copied to `docs/spec/prototypes/`, the
distribution module must sit at the same relative path (or edit the two require lines).

| File | Contents |
|---|---|
| `Crafting/Defs.luau` | the S4 values (Materials.qualityTier, Tiers, Rarities, CraftPlans, Balance.Stats.Sword, Balance.Quality) as ordered arrays; `Defs.set` lets the tuning scripts try alternatives |
| `Crafting/Core.luau` | every formula: WorkSet.select, Plan.build / fromHistory / validateDefs, Quality, Rarity (Max, plus the Majority and Striking alternatives), Stats, Outcome.compute / preview |
| `examples.luau` | E-S4.2 fixture table and step-by-step, E-S4.3 golden cases (T-CR-02), E-S4.5 R2-06 recompute check → `out/examples.txt` |
| `gamma_sweep.luau [n] [nPt]` | S3's Sim at design x = D for 9 points per tier, 4 profiles, 2 materials → `out/gamma_data.luau`, `out/gamma_sweep.txt` (≈ 6 min at 1000 / 600) |
| `gamma_fit.luau [γ…]` | slope fit and the γ needed per cell → `out/gamma_fit.txt` |
| `bold.luau [γ] [steelT]` | expected craft Q vs D with and without γ → `out/bold.txt` |
| `sim.luau table\|tune\|alt [U R E steelT γ]` | rarity table and targets (craft i = run i of each cell; `WIDE=1` → 20,000 crafts), grid search per Steel T, cap-rule / φ / weight alternatives → `out/table.txt`, `table_wide.txt`, `tune.txt`, `alt.txt` |
| `props.luau [n]` | outcome properties and the exhaustive cap grid → `out/props.txt` |

Final values: thresholds 0.55 / 0.84 / 1.04, Steel T 1.02, γ 0.15, φ 0.75, max cap rule; all §8.4 targets pass with
a 6.2-point minimum margin.
