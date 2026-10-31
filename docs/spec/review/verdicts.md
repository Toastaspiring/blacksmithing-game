# Lead verdicts (findings not listed here: Accept)

R1-05 | Modified | Accept the transport and sanitize design, but the settings record is the trimmed one in RULINGS §2.8 (R2-09 cuts per-axis/absolute/presets/UI-scale/orbit fields) plus reducedMotion, timingOffsetMs, sfxVolume.
R1-06 | Modified | Assignment timing accepted (PlotService.assign + PlotWorld.claim synchronously in PlayerAdded; stands render on ProfileLoaded; kick when full). Spawn mechanism follows R7-11 instead: one SpawnLocation per plot + RespawnLocation, no plaza spawn, no PivotTo-on-spawn (RULINGS §2.24).
R1-08 | Modified | Not a separate designer question: impossible input aborts the craft (RULINGS §2.19); it is folded into §0 Q17.
R1-11 | Modified | Session-level abandon, no user question (R6 verified it is better for players); S3 deletes "Esc forfeits the step" (RULINGS §2.19).
R1-12 | Modified | Accept; the factor sets for m_design are those of RULINGS §2.12.
R1-13 | Modified | Accept; S3 owns PrecisionTrace.sidesFromChains and S6's canvas mapping wins (RULINGS §2.12).
R1-19 | User | Q13 default: S1's 0–100 integers (Iron 45/50, Steel 70/55); S4's formulas divide by 100.
R1-21 | Modified | Superseded by R7-18: one recompute path, no GeometrySummary, no GEOMETRY_VERSION (RULINGS §2.7, §2.9).
R1-28 | User | Q7: one fixture set and S2's final measured tiers (RULINGS §2.14, §2.29); S4 re-derives its examples from S2's final run.
R1-29 | Modified | S3 owns the single player-model table (Minigames/Bots), S8 implements it verbatim, S4 uses S3's distributions; targets in RULINGS §2.16 (Q8, Q12).
R1-35 | Modified | Superseded by RULINGS §2.13: Asymmetry is measured about the fixed plane x = 0, which is also the mirror tool's left/right plane.
R1-41 | Modified | No rename; fallback "<Material> <Type>"; not a separate question (folded into Q18).
R2-02 | Modified | Accept, except POS_ABS_MAX = 16 (not 64) so every part stays inside S6's ×4 editor stage (RULINGS §2.5).
R2-03 | Modified | Default MIN_DIM = 0.02 [DtC Q4]; S2 verifies with its prototype after the factor fixes and may raise it to at most 0.05 with measurements (RULINGS §2.5). F3 is aligned to the final value.
R2-04 | Modified | Player model owned by S3 (not S8); targets in RULINGS §2.16 (Q8).
R2-05 | User | Q7: the iron arming sword plays Normal on all steps with ≥ 0.05 margin; other fixtures' intended tiers follow S2's final measured run.
R2-10 | Modified | Use the 22-question list in RULINGS §3 (adapted from this finding).
R3-01 | Modified | Superseded by RULINGS §2.13 (fixed plane x = 0; difficulty-related grip uses kept parts only). Keep the three adversarial fixtures A25–A27 with their ΔD bounds.
R3-05 | User | Q10 default: keep the max rule (any passed Hard step lifts the cap to Epic; the design draft's "Normal on smelting and Hell on sharpening" example). The engineering fixes R3-01…R3-04 still apply. S4 adds the Smelting-Hard-only row to its table; S8 replaces "the cap is the real protection" with the accepted risk "Epic is botable in the MVP".
R3-18 | User | §17: designs are visible by nature in a showcase game; exact geometry reaching other clients is an accepted MVP risk. Default: accept.
R4a-05 | Reject | Superseded by RULINGS §2.13: against the fixed hitbox frame, a whole-sword rotation is a real design change. S8 updates T-DIF-06's invariances (translation along Y/Z only).
R4a-08 | User | Q7: margin ≥ 0.05 below Hard for the iron arming sword after the factor fixes; S2 picks the constants and re-verifies the other fixtures.
R4a-14 | Modified | Option (b) is the default [DtC Q13]: difficultyTerm = 0 for Iron and Steel in the MVP; governing material by (difficultyTerm, hardness) (RULINGS §2.10).
R4a-15 | Modified | Caps stay 40/150 because transforms are raw doubles; S1 re-measures with GUIDs at 24 parts (≤ 50 % of the key).
R4a-22 | Modified | Fix S1's claim in the text (typical swords weigh about 0.8–1.5 kg); not a designer question.
R4b-02 | Modified | S3 owns the profile table (not S8); targets in RULINGS §2.16; S4 re-tunes on S3's distributions.
R4b-03 | User | Q8: S3 retunes parameters per family × tier × material; single 0.50 pass line preferred; per-(family, tier) thresholds within [0.40, 0.60] only if needed.
R4b-05 | Modified | No separate calibration screen: the results card shows the mean error and offers the offset; Settings has a slider (R6-05's approach, RULINGS §2.17).
R5b-06 | Modified | Store "PlayerData", key "User_<UserId>" (Roblox's recommended pattern for automated RTBF); README/build checklist adds the deletion template; no _v1 suffix (RULINGS §2.7).
R5b-09 | Modified | Resolved by RULINGS §2.24.
R6-01 | User | Q21: starter blueprint F5 + empty states + 4-step tracker; `starterGranted` replaces Counters (RULINGS §2.28). The spawn part follows RULINGS §2.24.
R6-02 | Modified | Accept F5 (all-Iron starter). Hint copy must name design factors, because Steel no longer raises tiers in the MVP (RULINGS §2.10).
R6-03 | Modified | Superseded by R4b-03's approach (retune parameters; 0.50 line preferred), RULINGS §2.16.
R6-04 | User | Q11 default: option (b), continuous d inside a tier; S4 tunes γ (RULINGS §2.15).
R6-06 | User | Q20 default: about 12 cues in Definitions/Audio, ids chosen during the build (an empty id is silent); visual counterparts kept.
R6-09 | User | Q6 default: autosave every 60 s while dirty, overwrite in place.
R6-15 | User | §17, default: no Epic announcement in the MVP (Phase 2 candidate).
R6-16 | User | §17, default: practice mode is a Phase 2 hook.
R6-17 | Modified | Superseded by RULINGS §2.13.
R6-18 | User | Q5 default: Rotate snapping off; Move and Scale on at 0.05.
R7-11 | Modified | Accept, with TeleportHome as `Showcase.TeleportHome` on the existing Showcase channel (no fifth RemoteEvent).
R7-13 | Modified | Superseded by RULINGS §2.13 (fixed planes x = 0 / z = 0; Blueprint/Mirror single implementation).
R2-13 | Modified | Superseded by RULINGS §2.13.
