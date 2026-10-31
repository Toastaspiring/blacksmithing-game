## 16 Constants
| Name | Value | Unit | Module | Rationale |
|---|---|---|---|---|
| `passThreshold` (every family) | 0.50 | score | Definitions/MinigameFamilies | one pass line; parameters carry difficulty (Q8) |
| `TIMELINE_FORMAT_VERSION` / `TIMELINE_HEADER_BYTES` | 1 / 12 | –, B | Definitions/MinigameFamilies | timeline header |
| `FAMILY_CODE` | HoldZone 1, TimingStrike 2, PrecisionTrace 3 | – | Definitions/MinigameFamilies | header byte 1 |
| `RECORD_BYTES` | 3 / 2 / 7 | B | Definitions/MinigameFamilies | per family, in that order |
| `MAX_RECORDS` | 1024 / 512 / 2048 | records | Definitions/MinigameFamilies | above every honest maximum (Trace 1,551) |
| `MAX_TIMELINE_BYTES` | 14348 | B | Definitions/MinigameFamilies | 12 + 2048 × 7; the S5 Guard bound |
| `RNG_SPLITMIX_GAMMA`, `RNG_FMIX_C1`, `RNG_FMIX_C2` | 0x9E3779B9, 0x85EBCA6B, 0xC2B2AE35 | – | Minigames/Rng | SplitMix32 seeding |
| `FNV_BASIS` / `FNV_PRIME` | 0x811C9DC5 / 0x01000193 | – | Minigames/Rng | FNV-1a 32 for tags and hashes |
| `HZ_TICK_MS` | 10 | ms | Minigames/HoldZone | integer tick boundaries |
| `HoldZone.zoneWidth` | 0.090 | gauge | Definitions/MinigameFamilies | 144 °C band; Steel, Hard and design columns in §6.8 |
| `HoldZone.driftSpeed` | 0.21 | gauge/s | Definitions/MinigameFamilies | zone speed while moving |
| `HoldZone.heatDecay` | 1.0 | 1/s | Definitions/MinigameFamilies | needle responsiveness |
| `HoldZone.fullHeat` | 2.4 | gauge | Definitions/MinigameFamilies | steady T ≤ 0.96 at the refill rate |
| `HoldZone.strokeGain` | 0.25 | fire | Definitions/MinigameFamilies | one stroke from rest: +0.17 T |
| `HoldZone.refillMs` | 250 | ms | Definitions/MinigameFamilies | useful tap rate ≤ 4/s |
| `HoldZone.fireDecayMs` | 600 | ms | Definitions/MinigameFamilies | fire dies down between strokes |
| `HoldZone.targetMin` / `targetMax` | 0.40 / 0.80 | gauge | Definitions/MinigameFamilies | zone centre range; Steel needs more heat |
| `HoldZone.segMinMs` / `segMaxMs` | 900 / 2200 | ms | Definitions/MinigameFamilies | zone direction changes |
| `HoldZone.holdChance` | 0.25 | – | Definitions/MinigameFamilies | stationary breathers |
| `HoldZone.durationMs` / `rampMs` | 15000 / 3000 | ms | Definitions/MinigameFamilies | 12 s scored after a heat-up |
| `HoldZone.softFrac` | 0.5 | ×zoneWidth | Definitions/MinigameFamilies | partial credit near the zone |
| `TimingStrike.strikes` | 12 | count | Definitions/MinigameFamilies | 15 at Hard (Q15); ≥ 8 for the variance check |
| `TimingStrike.beatMs` | 900 | ms | Definitions/MinigameFamilies | rhythm speed |
| `TimingStrike.windowMs` | 110 | ms (half) | Definitions/MinigameFamilies | sized for about 25 ms of display lag |
| `TimingStrike.perfectFrac` / `edgePoints` | 0.12 / 0.20 | ×W, points | Definitions/MinigameFamilies | full-points core, edge slope |
| `TimingStrike.tempoJitter` | 0.08 | ±×P | Definitions/MinigameFamilies | irregular rhythm |
| `TimingStrike.offsetMin` / `offsetMax` | 0.40 / 0.75 | ×P | Definitions/MinigameFamilies | read each cycle; spans never overlap |
| `TimingStrike.missPadMs` / `tailMs` | 90 / 400 | ms | Definitions/MinigameFamilies | near presses are Misses; tail after the last cycle |
| `TS_PERFECT_CORE_MIN_MS` | 10 | ms | Minigames/TimingStrike | ≥ 9 ms (RULINGS 2.17); Perfect at 30 fps ≥ 0.965 per run |
| `TS_GRADE_PERFECT` / `TS_GRADE_GOOD` | 0.9 / 0.6 | points | Minigames/TimingStrike | grade labels from points |
| `TS_OFFSET_OFFER_MIN_JUDGED` | 8 | strikes | Minigames/TimingStrike | offset offered from ≥ 8 errors |
| `PrecisionTrace.halfWidth` / `coreFrac` | 0.041 / 0.10 | u, ×w | Definitions/MinigameFamilies | 21 px at 520 px; accuracy stays a gradient |
| `PrecisionTrace.pacerSpeed` | 0.30 | u/s | Definitions/MinigameFamilies | sets the duration |
| `PrecisionTrace.paceTol` / `paceFall` | 0.12 / 0.24 | arc u | Definitions/MinigameFamilies | ±0.4 s at full credit |
| `PrecisionTrace.perturbAmp` | 0.020 | u | Definitions/MinigameFamilies | grind irregularities |
| `PrecisionTrace.bumpDensity` / `bumpWidth` | 1.0 / 0.25 | /u, u | Definitions/MinigameFamilies | path complexity |
| `PrecisionTrace.leadInMs` / `tailMs` | 600 / 400 | ms | Definitions/MinigameFamilies | the spark waits at the start |
| `PrecisionTrace.wAccuracy` | 0.70 | – | Definitions/MinigameFamilies | accuracy is the skill, pace the guard |
| `PT_PANEL_ASPECT`, `PT_FIXED_POINT`, `PT_MARGIN_U`, `PT_MARGIN_V` | 3.0, 16384, 0.15, 0.12 | –, /u, u, u | Minigames/PrecisionTrace | panel and fixed point (u ≤ 49152, v ≤ 16384) |
| `PT_BLADE_REF_LEN` | 4.5 | stud | Minigames/PrecisionTrace | a 4.5-stud blade spans the panel |
| `PT_EXAG_MAX` / `PT_EXAG_SHRINK` | 2.0 / 0.9 | – | Minigames/PrecisionTrace | cross-axis exaggeration and its shrink step |
| `PT_LEN_MARGIN` | 0.95 | – | Minigames/PrecisionTrace | source ≤ 0.95 × 30 s × pacerSpeed |
| `PT_MAX_SOURCE_POINTS` | 256 | points | Minigames/PrecisionTrace | bounded source (R3-08) |
| `PT_SIMPLIFY_TOL` / `PT_SIMPLIFY_STEPS` | 0.004 / 8 | u, steps | Minigames/PrecisionTrace | Douglas–Peucker, doubling |
| `PT_MIN_SOURCE_LEN` | 0.4 | u | Minigames/PrecisionTrace | shorter edges use the fallback |
| `PT_FALLBACK_EDGE` | (±0.22, 0) → (±0.22, 2.6) → (0, 3.4) | stud | Minigames/PrecisionTrace | generic double edge (Q15) |
| `PT_CHAIKIN_ITERS`, `PT_DS`, `PT_TAPER` | 3, 0.01, 0.15 | –, u, u | Minigames/PrecisionTrace | smoothing, spacing, calm ends |
| `PT_CLEAR_SKIP`, `PT_CLEAR_FRAC`, `PT_CLEAR_CELL` | 0.30, 0.35, 0.30 | u, –, u | Minigames/PrecisionTrace | no self-crossing; O(n) grid |
| `PT_EVAL_MS`, `PT_SEARCH`, `PT_BIN` | 20, 0.5, 0.02 | ms, arc u, arc u | Minigames/PrecisionTrace | tick = sampling cadence; pacer window; coverage bin |
| `PT_VMAX_FACTOR` / `PT_VMAX_MIN` | 6 / 1.5 | ×speed, u/s | Minigames/PrecisionTrace | coverage speed gate |
| `PT_MAX_GAP_MS` | 250 | ms | Minigames/PrecisionTrace | longer gaps hold, not grinding |
| `PT_TRAVEL_MIN_MS` / `PT_TRAVEL_MAX_MS` | 6000 / 30000 | ms | Minigames/PrecisionTrace | travel clamp |
| `HZ_RATE_WINDOW_MS` / `HZ_RATE_MAX_PRESSES` | 1000 / 30 | ms, presses | Definitions/MinigameFamilies | humans ≤ 9 |
| `TS_MIN_JUDGED`, `TS_MIN_SD_MS` | 8, 1.5 | strikes, ms | Definitions/MinigameFamilies | FP ≤ 1.1e-5 at σ 10 ms |
| `TS_EXACT_MS` / `TS_EXACT_FRAC` | 1 / 0.90 | ms, – | Definitions/MinigameFamilies | exact-time macros |
| `PT_PRECISE_MIN_SAMPLES` / `PT_PRECISE_MEAN_DEV` | 40 / 0.0008 | samples, u | Definitions/MinigameFamilies | human minimum ×3.6 |
| `PT_SMOOTH_MIN_TRIPLETS`, `PT_SMOOTH_MEAN_JERK`, `PT_SMOOTH_MIN_MOVE` | 150, 0.0002, 0.002 | –, u, u | Definitions/MinigameFamilies | human minimum ×19 |
| `PT_TELEPORT_DIST`, `PT_TELEPORT_MAX_DT`, `PT_TELEPORT_COUNT` | 0.25, 40, 3 | u, ms, – | Definitions/MinigameFamilies | jump detector (telemetry) |
| `PT_SPARSE_FRAC` | 0.5 | ×travelMs/20 | Definitions/MinigameFamilies | sparse timelines (telemetry) |
| `BOT_REF_X` | Normal 0.10, Hard 0.30 | factor | Minigames/Bots | reference design for §6.13 |
| `BOT_EXTRA_LAG_MS` / `BOT_PANEL_PX` | 8 / 520 | ms, px | Minigames/Bots | latency beyond a frame; S6 canvas height |
| `BOT_HZ_PERFECT_LOOKAHEAD_MS` | 300 | ms | Minigames/Bots | Perfect HoldZone controller |
| `BOT_RUNS_PER_CELL` | 2000 | runs | Minigames/Bots | distributions for S4 |
