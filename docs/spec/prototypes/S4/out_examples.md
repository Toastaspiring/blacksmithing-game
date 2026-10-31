## Example physics (S2 prototype outputs) and material terms
| Sword | Mass | Reach | Balance offset b | beta = b/R | L_edge | c | F_mass | Balance | H (blade) | K | T (steel share) | S2 tiers S/H/Sh |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Minimal 4-part (Iron) | 1.472 | 3.10 | 0.108 | 0.035 | 5.04 | 0.84 | 1.189 | 98 | 0.50 | 0.50 | 1.0000 (0 %) | Hard/Normal/Normal |
| Arming sword (Iron) | 0.835 | 3.42 | 0.177 | 0.052 | 5.65 | 0.94 | 0.995 | 100 | 0.50 | 0.50 | 1.0000 (0 %) | Normal/Hard/Hard |
| Arming sword (Steel) | 0.833 | 3.42 | 0.177 | 0.052 | 5.65 | 0.94 | 0.994 | 100 | 0.70 | 0.50 | 1.1000 (100 %) | Normal/Hard/Hard |
| Rapier (Steel blade+guard, Iron hilt) | 0.417 | 4.13 | 0.242 | 0.059 | 6.68 | 1.00 | 0.820 | 100 | 0.70 | 0.50 | 1.0589 (59 %) | Normal/Hard/Hard |
| Cleaver (Iron) | 3.724 | 3.28 | 0.983 | 0.300 | 6.20 | 1.00 | 1.300 | 40 | 0.50 | 0.50 | 1.0000 (0 %) | Hard/Hard/Hard |
| Curved sabre (Steel blade+guard, Iron hilt) | 0.682 | 3.81 | 0.356 | 0.093 | 6.71 | 1.00 | 0.937 | 100 | 0.70 | 0.50 | 1.0673 (67 %) | Normal/Hard/Hard |

## Stats: Damage / Durability / Sharpness / Purity / Balance (Reach = physics)
| Sword | Player | Damage | Durability | Sharpness | Purity | Balance |
|---|---|---:|---:|---:|---:|---:|
| Minimal 4-part (Iron) | Bad (raw 0.40 / 0.40 / 0.24, all failed -> s_eff 0.30 / 0.30 / 0.18) | 24.4 | 25.7 | 16.8 | 79% | 98.3 |
| Minimal 4-part (Iron) | Average (0.60) | 31.6 | 35.2 | 31.7 | 88% | 98.3 |
| Minimal 4-part (Iron) | Good (0.78) | 36.1 | 41.6 | 39.5 | 93% | 98.3 |
| Minimal 4-part (Iron) | Excellent (0.90) | 39.4 | 46.1 | 45.1 | 97% | 98.3 |
| Minimal 4-part (Iron) | Flawless (1.00) | 42.2 | 50.0 | 50.0 | 100% | 98.3 |
| Arming sword (Iron) | Bad (raw 0.40 / 0.40 / 0.24, all failed -> s_eff 0.30 / 0.30 / 0.18) | 20.7 | 25.7 | 16.8 | 79% | 100.0 |
| Arming sword (Iron) | Average (0.60) | 27.1 | 35.2 | 31.7 | 88% | 100.0 |
| Arming sword (Iron) | Good (0.78) | 31.1 | 41.6 | 39.5 | 93% | 100.0 |
| Arming sword (Iron) | Excellent (0.90) | 34.0 | 46.1 | 45.1 | 97% | 100.0 |
| Arming sword (Iron) | Flawless (1.00) | 36.6 | 50.0 | 50.0 | 100% | 100.0 |
| Arming sword (Steel) | Bad (raw 0.40 / 0.40 / 0.24, all failed -> s_eff 0.30 / 0.30 / 0.18) | 21.9 | 25.7 | 23.6 | 79% | 100.0 |
| Arming sword (Steel) | Average (0.60) | 29.6 | 35.2 | 44.4 | 88% | 100.0 |
| Arming sword (Steel) | Good (0.78) | 34.5 | 41.6 | 55.3 | 93% | 100.0 |
| Arming sword (Steel) | Excellent (0.90) | 38.0 | 46.1 | 63.1 | 97% | 100.0 |
| Arming sword (Steel) | Flawless (1.00) | 41.2 | 50.0 | 70.0 | 100% | 100.0 |
| Rapier (Steel blade+guard, Iron hilt) | Bad (raw 0.40 / 0.40 / 0.24, all failed -> s_eff 0.30 / 0.30 / 0.18) | 18.2 | 25.7 | 23.6 | 79% | 100.0 |
| Rapier (Steel blade+guard, Iron hilt) | Average (0.60) | 24.9 | 35.2 | 44.4 | 88% | 100.0 |
| Rapier (Steel blade+guard, Iron hilt) | Good (0.78) | 29.1 | 41.6 | 55.3 | 93% | 100.0 |
| Rapier (Steel blade+guard, Iron hilt) | Excellent (0.90) | 32.1 | 46.1 | 63.1 | 97% | 100.0 |
| Rapier (Steel blade+guard, Iron hilt) | Flawless (1.00) | 34.9 | 50.0 | 70.0 | 100% | 100.0 |
| Cleaver (Iron) | Bad (raw 0.40 / 0.40 / 0.24, all failed -> s_eff 0.30 / 0.30 / 0.18) | 27.3 | 25.7 | 16.8 | 79% | 40.0 |
| Cleaver (Iron) | Average (0.60) | 35.9 | 35.2 | 31.7 | 88% | 40.0 |
| Cleaver (Iron) | Good (0.78) | 41.4 | 41.6 | 39.5 | 93% | 40.0 |
| Cleaver (Iron) | Excellent (0.90) | 45.3 | 46.1 | 45.1 | 97% | 40.0 |
| Cleaver (Iron) | Flawless (1.00) | 48.8 | 50.0 | 50.0 | 100% | 40.0 |
| Curved sabre (Steel blade+guard, Iron hilt) | Bad (raw 0.40 / 0.40 / 0.24, all failed -> s_eff 0.30 / 0.30 / 0.18) | 20.8 | 25.7 | 23.6 | 79% | 100.0 |
| Curved sabre (Steel blade+guard, Iron hilt) | Average (0.60) | 28.4 | 35.2 | 44.4 | 88% | 100.0 |
| Curved sabre (Steel blade+guard, Iron hilt) | Good (0.78) | 33.2 | 41.6 | 55.3 | 93% | 100.0 |
| Curved sabre (Steel blade+guard, Iron hilt) | Excellent (0.90) | 36.7 | 46.1 | 63.1 | 97% | 100.0 |
| Curved sabre (Steel blade+guard, Iron hilt) | Flawless (1.00) | 39.8 | 50.0 | 70.0 | 100% | 100.0 |

## Worked example: S2 arming sword, Good player (0.78 / 0.78 / 0.78)
Arming sword (Iron): P 0.9340 h 0.4670 k 0.4670 Sharp 39.508 Dura 41.563 c 0.9418 F_mass 0.9947 F_edge 1.3721 F_forge 0.9120 Damage 31.118 beta 0.0518 Balance 100.00 | stored dmg 31.1 reach 3.42 dura 41.6 sharp 39.5 pur 0.934 bal 100.0
Arming sword (Steel): P 0.9340 h 0.6538 k 0.4670 Sharp 55.311 Dura 41.563 c 0.9418 F_mass 0.9939 F_edge 1.5209 F_forge 0.9120 Damage 34.467 beta 0.0518 Balance 100.00 | stored dmg 34.5 reach 3.42 dura 41.6 sharp 55.3 pur 0.934 bal 100.0

## Mixed material T: S2 arming sword with a Steel blade (blade + tips), Iron guard/grip/pommel
blade (steel) 0.0324 stud^3, rest (iron) 0.0745 stud^3 -> T = 1.0303

## Q / rarity worked examples (Sword plan weights 0.25 / 0.40 / 0.35)
| Case | Tiers | s (raw, pass) | s_eff | sum w*s_eff*d | T | Q | by score | cap (step) | Rarity |
|---|---|---|---|---:|---:|---:|---|---|---|
| A. Average, iron, all Normal | Normal/Normal/Normal | 0.62 / 0.58 / 0.60 | 0.620 / 0.580 / 0.600 | 0.5970 | 1.0000 | 0.5970 | Uncommon | Rare (base) | **Uncommon** |
| B. Good, steel, Smelt H / Ham N / Sharp H | Hard/Normal/Hard | 0.70 / 0.80 / 0.66 | 0.700 / 0.800 / 0.660 | 0.8275 | 1.1000 | 0.9103 | Rare | Epic (Smelting) | **Rare** |
| C. As B but Sharpening failed (raw 0.28) | Hard/Normal/Hard | 0.70 / 0.80 / 0.28 FAIL | 0.700 / 0.800 / 0.210 | 0.6306 | 1.1000 | 0.6937 | Uncommon | Epic (Smelting) | **Uncommon** |
| D. Excellent, iron, all Hard | Hard/Hard/Hard | 0.82 / 0.80 / 0.78 | 0.820 / 0.800 / 0.780 | 0.9975 | 1.0000 | 0.9975 | Epic | Epic (Smelting) | **Epic** |
| E. Excellent, steel, all Normal (cap binds) | Normal/Normal/Normal | 0.95 / 0.92 / 0.93 | 0.950 / 0.920 / 0.930 | 0.9310 | 1.1000 | 1.0241 | Epic | Rare (base) | **Rare** |
| F. Excellent, iron, only Sharpening Hard, Hard step failed (raw 0.29) | Normal/Normal/Hard | 0.95 / 0.95 / 0.29 FAIL | 0.950 / 0.950 / 0.217 | 0.7127 | 1.0000 | 0.7127 | Uncommon | Rare (base) | **Uncommon** |
| G. S2 arming, steel blade + iron rest, Good, N/H/H | Normal/Hard/Hard | 0.80 / 0.70 / 0.72 | 0.800 / 0.700 / 0.720 | 0.8650 | 1.0303 | 0.8912 | Rare | Epic (Hammering) | **Rare** |
