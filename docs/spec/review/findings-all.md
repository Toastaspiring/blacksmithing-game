# All review findings

### R1-01 [blocker/conflict] Craft.Submit guard rejects S3's buffer timelines

Sections: S3, S5, S8 | needsUserDecision: False | confidence: high

**Problem.** S3 sends each step's input timeline as one binary buffer (12-byte header, up to 14,348 B for PrecisionTrace). S5's Submit guard accepts only a flat int32 array of at most 4,096 values, and its plain() validator explicitly rejects buffers. As written, every honest Submit fails with E_BAD_REQUEST, which is a Hard strike (kick at 10), so no craft can ever complete. The decode interfaces also differ: S5 Family.decode(raw, pattern) vs S3 Timeline.decode(b, family, durationMs).

**Evidence.** S3 §6.7: 'One buffer, little endian, sent through a RemoteEvent'; S5 §10.4 Guard specs: 'inputs = G.intArr(N.MAX_INPUT_VALUES, I32[1], I32[2])' and plain() 'rejects ... functions, buffers'; S5 §10.5: E_BAD_REQUEST Hard strike = yes; S5 §10.13: 'If S3 needs denser traces it should ... switch that family to a buffer ... the Guard would then accept buffer ≤ 16 KB'.

**Proposed fix.** S3's format wins: S3 owns the timeline format for all three families. S5 adds a Guard primitive buffer(maxBytes) (typeof == 'buffer', buffer.len ≤ max). Craft.Submit args become {sessionId, stepIndex, timeline: buffer, clientScore?}. MAX_INPUT_VALUES is replaced by MAX_TIMELINE_BYTES = 14,348, derived from S3's TIMELINE_HEADER_BYTES + max(MAX_RECORDS × RECORD_BYTES) rather than restated. All structural checks stay in S3's Timeline.decode, called through Minigames.judge; S5 has no decode of its own. S5 must change §1.7 CraftService.submit, §7.P4 steps 1 and 7, §10.4, §10.10, §10.13 and §16. S8's T-MG-08 and S-E2E-10 fuzz buffers.


### R1-02 [blocker/gap] StartStep reply lacks the PrecisionTrace source and the patternHash

Sections: S3, S5, S6 | needsUserDecision: False | confidence: high

**Problem.** The client regenerates each pattern from server data. S3's StepSpec carries source (the blade edge in fixed point, computed only on the server by PrecisionTrace.edgeToPanel) and patternHash; S5's StepOpenView carries neither. Without source the client cannot generate the Sharpening pattern, so that minigame cannot be played. Without patternHash the client-side desync check of S3 §6.4.4 cannot run. S6's ViewContext already expects a StepSpec.

**Evidence.** S3 §6.2 StepSpec: 'source: { number }?, -- PrecisionTrace: flat {u1, v1, u2, v2, ...}' and 'patternHash: number'; S3 §6.10.1: 'This happens on the server only, and the client receives the decimated source.'; S5 §10.4 StepOpenView = {sessionId, index, stepId, family, tier, seed, params, countdownMs, durationMs, lateAllowanceMs, balanceVersion}; S6 §12.3.1: 'ViewContext = { spec: StepSpec, pattern, ... }'.

**Proposed fix.** Define StepOpenView as S3's StepSpec plus the session fields {sessionId, index, stepId, tier, lateAllowanceMs}. Add source ({number}?, at most 2 × PT_MAX_SOURCE_POINTS = 512 integers) and patternHash (u32). CraftService.startStep obtains both from S3's Minigames.prepare and keeps (spec, pattern) in the session (S3 §10.M1); a re-open in Playing(i) returns the same spec. S5 owns the payload and S3 its content; S6 needs no change. S5 §10.13 re-estimates the reply size (about 1.5 KB with 256 points).


### R1-03 [blocker/conflict] Blueprint and item id formats: S1's counters vs S5's GUIDs

Sections: S1, S5, S6, S7 | needsUserDecision: False | confidence: high

**Problem.** S1's ids are 'B<n>' and 'I<n>' from per-profile NextIds counters. Canonical.draft rejects any other id and reads a missing Id as 'create'. S5's guards require a GUID for blueprintId (Save/Get/Rename/Delete) and for itemId (Place/Scrap/GetItem). S5's retry safety (Save as upsert) and its at-most-one-item-per-session rule (item id = session GUID) both depend on GUIDs. S6 sends 'B<n>' and does Save-as 'without blueprintId'. As written, every blueprint and item request fails the Guard (E_BAD_REQUEST, Hard strike, kick after 10). SaveArgs also duplicates fields: args.name/args.blueprintId vs draft.Name/draft.Id.

**Evidence.** S1 §2.2 rule 3: 'Player-record ids are "B<n>" ... and "I<n>" ... taken from the per-profile monotonic counters NextIds'; S1 §3.5 check 3; S5 §10.10: 'Blueprint.Get/Rename/Delete | blueprintId | guid' and 'Showcase.Place | slotIndex, itemId | int 1…16, guid'; S5 §7.P7: 'upsert by client-minted GUID ... Assumes (S1): blueprint ids are GUID strings'; S5 §7.P1: session id 'also the id of the item it produces'; S6 §11.20: 'Save as Ctrl+Shift+S | new id | same call without blueprintId'.

**Proposed fix.** Adopt S5's scheme, since it is what makes Save and item commit idempotent without a request cache. BlueprintId is a client-minted GUID (upper-cased by the server); ItemId is the craft session GUID. S1 replaces the id patterns, deletes NextIds and Ids.newBlueprintId/newItemId, and rewrites invariants I1–I2. Canonical step 3 validates a GUID, and §9.7 is re-measured: about +30 B per id occurrence, roughly 16 KB at 40/150. S5's SaveArgs becomes {blueprintId, draft}, with the name inside the draft (drop args.name and draft.Id). S6 mints a GUID for New, Save as and Duplicate. S7's itemId check (≤ 64 bytes) already fits. Owners: S1 (id format), S5 (guards).


### R1-04 [blocker/conflict] S1's invisible storage grid contradicts the fixed free-transform decision

Sections: S1, S2, S6, S8 | needsUserDecision: False | confidence: high

**Problem.** S1's canonical form runs on client and server and rounds Pos/Size to 1e-4 stud and quaternion components to 1e-6 before validation and storage. That is server-side quantization of the design, which the user decision excludes. S2 builds on that decision: 'Continuous values only'. S1's case for quantizing is −40 % caps with raw doubles, but that was computed at the placeholder MAX_PARTS_ABS = 48. At S2's actual 24-part limit, raw doubles keep S1's caps inside S1's own ≤ 50 % target. S1 also requires every S2 tolerance to be ≥ 1e-3, but only because of the 1e-4 grid; S2 uses EPS_CONTAIN = 1e-4, and S8's A04/A05 expect an ε far below 1e-3.

**Evidence.** BRIEF §1: 'There is no server-side quantization of transforms'; S1 §3.4: 'Pos, Size component x | round(x · 10⁴) / 10⁴'; S2 §3.4: 'Continuous values only (user decision): no server-side quantization'; S1 §3.4 property 4: 'every geometric tolerance ... ≥ 1e-3 stud'; command lune run review/R1/sizes_raw24.luau (S1's sizes.luau with a worst part of 17-digit doubles): 'bp=40 items=150 parts=24 (raw doubles, MVP item shape): 1655108 B = 39.5% of 4 MiB'; Phase 2+ item shape: 44.8 %; quantized at 24 parts: 27.2 %.

**Proposed fix.** S1 drops the length and quaternion grids. Canonical keeps finiteness, −0 → 0, quaternion renormalization when |‖q‖²−1| > QUAT_NORM_TOL, the hemisphere rule (identical to S2 §3.5) and ascending-Id order. Delete LEN_SCALE, QUAT_SCALE and the ≥ 1e-3 tolerance requirement. Set MAX_PARTS_ABS = 24 (= S2's PARTS_MAX) and keep the 40/150 caps (39.5 % MVP shape, 44.8 % Phase 2+ shape); re-run the budget when a type with more parts arrives. S2 keeps EPS_CONTAIN = 1e-4, which is consistent with S8's A04/A05. S6's numeric fields display up to 4 decimals but keep and send the full double, and typed values are stored as typed. S8's S-PAR-03 confirms the double round trip through DataStore. Outcome quantization (D, Score, Q at 1e-4) is unaffected.


### R1-05 [blocker/conflict] Settings payload cannot carry EditorPrefs; UiFlags has no transport

Sections: S1, S5, S6 | needsUserDecision: False | confidence: high

**Problem.** S5's Profile.SetSettings guard accepts a flat table of at most 32 number/boolean keys, and ProfileSnapshot.settings is {[string]: number|boolean}. S1's EditorPrefs is nested: Snap.Move.On…, Presets lists of up to 12, Space as a 'Local'/'World' string, Overlays, about 46 values. S6 adds about 27 more fields (SnapAxes, SnapAbsolute, Pivot string, UiScale, …). Every honest prefs save fails the Guard, and E_BAD_REQUEST is a Hard strike: with S6's 2-s debounce, a player adjusting snapping is kicked after 10 saves. S6's UiFlags ('TipsHidden.<StepId>') have no remote at all.

**Evidence.** S5 §10.10: 'Profile.SetSettings | settings | plain, ≤ 32 keys of numbers/booleans'; S5 §10.4: 'settings: { [string]: number | boolean }'; S1 §9.3 EditorPrefs and TEMPLATE; S6 §11.10.1 EditorPrefsS6: 'saved through S5's Profile.SetSettings, debounced SETTINGS_SAVE_DEBOUNCE_S = 2'; S6 cross-section note: 'S5's current guard says ≤ 32 keys'; S5 §10.5/§10.7: Hard strike, kick at HARD_STRIKES_KICK = 10.

**Proposed fix.** S5: SetSettings args become {editorPrefs: EditorPrefs, uiFlags: {[string]: boolean}?}, guarded by plain(depth 4) with a 256-node cap. Then an S1-owned Persistence/Prefs.sanitize(raw) -> EditorPrefs clamps the values: S1 §9.3 ranges plus S6's (UiScale 0.8–1.5, OrbitSpeed 0.1–1.0, Pivot/Space enums), with unknown keys dropped. UiFlags follow S1's rules (≤ 64 keys, ≤ 32-byte keys). ProfileSnapshot carries editorPrefs and uiFlags in S1's shapes. S6 owns the field list and defaults; S1 adds the S6 fields to the template. Owners: S5 (transport), S1 (shape and sanitize), S6 (fields).


### R2-01 [blocker/fidelity] Storage grid on transforms contradicts the no-quantization decision; its cost argument is wrong at 24 parts

Sections: S1, S2, S6, S8 | needsUserDecision: False | confidence: high

**Problem.** S1 makes the canonical form (wire = storage) round Pos and Size to 1e-4 stud and quaternion components to 1e-6, on client and server, although BRIEF §1 (user decision) says there is no server-side quantization of transforms. S1's justification rests on two claims that do not hold for this spec. (1) 'Raw doubles cut caps by about 40 %' was computed at the 48-part placeholder; at S2's real Sword limit of 24 parts, raw doubles fit the same 40/150 caps inside S1's own 50 % target. (2) 'At most 1/20 pixel' assumes a 1x camera; in S6's 4x editor at max zoom, 1e-4 stud is about 0.46 px. A typed 0.12345 is also stored as a rounded value. S6 shows degrees with only 2 decimals while claiming typed values are displayed exactly. Raw doubles round-trip losslessly through Roblox JSON, so nothing requires the grid.

**Evidence.** BRIEF §1: 'There is no server-side quantization of transforms'. S1 §3.4 'Relation to BRIEF §1': 'It buys canonical uniqueness and −40 % storage ... Alternative ... at the cost of caps ≈ −40 % (§9.7)'. S1 §9.7 caps table is computed at 'MAX_PARTS_ABS = 48 (placeholder used)'; S2 §3.6 gives Total 2..24. Command `lune run review/R2/sizes_raw24.luau` (S1's own encoder, raw 17-digit part = 294 B): 'bp=40 items=150 parts=24 (RAW doubles, MVP item shape): 1655108 B = 39.5%'. Command `lune run review/R2/sizes_raw24_pess.luau` (every number at Roblox's 25-char worst): 46.3 % MVP item shape, 51.6 % Phase 2+ shape; S1 already accepted 46.6 % / 52.0 % at 48 parts. Read-only Studio probe (HttpService JSONEncode/JSONDecode): 20,000 random doubles, 0 mismatches, worst encoded length 25 chars. S6 §11.4.1 table: a 0.05-bp detail is 231.6 px at max zoom, so 1e-4 bp ≈ 0.46 px, against S1 §3.4's '≤ 1/20 pixel'. S6 §11.11.1: 'degrees with up to 2' decimals; §11.11.3: 'the field shows exactly what was typed'.

**Proposed fix.** Owner S1.
- Canonical keeps Pos, Size and Rot as the finite doubles the editor produced; no LEN_SCALE/QUAT_SCALE rounding.
- Keep the exact rules: reject non-finite values; renormalize Rot only when |‖q‖²−1| > QUAT_NORM_TOL; apply the hemisphere rule; turn −0 into 0. Canonical stays idempotent trivially, since nothing is rounded.
- Keep the 1e-4 quantization only for derived numbers (D, Score, Q, Stats, Physics).
- Redo §9.7 at the largest enabled PartLimits.Max (Sword 24): 39.5–46.3 % of 4 MiB at the unchanged 40/150 caps. The budget test computes W from enabled types; MAX_PARTS_ABS stays a placeholder for later types.
- Delete S1 open question 1 and S1 deviation 9.
- S2 §3.4 already assumes lossless doubles, so it is unchanged.
- S6 §11.7.1 drops the '1e-4 grid' text. The editor stores the exact typed value and re-shows it as typed: lengths up to 4 decimals in passive display, degrees up to 4 decimals (not 2).
- S8 keeps S-PAR-03 (DataStore float survival). S1 invariant I13 changes to 'idempotent + bit-exact JSON round trip' (no '≤ 1e-4 displacement').
- If the lead nevertheless keeps the grid, S1 must correct both claims (no cap saving at 24 parts; ≈ 0.46 px at S6's max zoom), and the user must approve it explicitly, because it contradicts BRIEF §1.


### R3-01 [blocker/exploit] Asymmetry plane is taken from Grip parts, including hidden ones: an invisible tier unlock

Sections: S2, S8 | needsUserDecision: False | confidence: high

**Problem.** Asymmetry is measured about the plane through the grip point g that contains the grip axis A. A is the volume-weighted long axis of all eligible Grip parts: enclosed (cleaned) parts count, only dust is excluded. g uses all Grip parts. Three cheap changes make a symmetric blade read as asymmetric: a fully enclosed rod inside the grip, a decorative diagonal wrap strap, or shifting the hilt about 0.04 stud sideways. Each tilts or shifts the plane and pushes Hammering and Sharpening to Hard (raw Expert). Stands display items in blueprint orientation (S7 STAND), so nothing visible changes. Hidden parts therefore change difficulty, which violates the BRIEF §1 cleaning rule ('enclosed parts ... are ignored for difficulty') and S2 §5.8's anti-gaming claim.

**Evidence.** S2 §4.5.3: 'a2 = Σ_{p in Grip, eligible} V_p·ê_p' with 'Eligible: Cylinders always ... Balls never, dust never'; §4.4 table: 'reach and grip point (analytic) | yes'; §5.2 Asymmetry: 'plane through the grip point g containing the grip axis A'. Run of review/R3/s2_exploits.luau on proto/S2, case 'Arming, ring grip + 20deg wrap strap': 'cleaned=[Strap(enclosed)] axis=(-0.342,0.940) ... Asym raw All/Blade=0.726/1.000 ... Hammering G=0.484 Hard | Sharpening G=0.479 Hard'. Same grip without the strap: 0.184 / 0.179, both Normal. review/R3/grip_offset.luau, grip and pommel shifted 0.04 in X: 'Hammering 0.230 Hard | Sharpening 0.313 Hard'. In the S4 sim with S3 curves (out_s4sim_s3model.txt), going from N/N/N to N/H/H takes S3's good bot from 0% to 67% Epic (Iron).

**Proposed fix.** S2 owns the fix. (1) For difficulty purposes, compute g and A from kept parts only (exclude dust and enclosed parts); keep the current grip frame for physics (balance, reach). (2) Define Asymmetry over the working set W_s as the minimum of two values: asymmetry about the grip plane, and asymmetry about W_s's own plane. That plane passes through W_s's owned-volume centroid, normal to W_s's principal XY axis, computed from the closed-form 2×2 covariance using sqrt only. Grip decoration and hilt offsets then cannot raise the factor, while sabres and cleavers still measure asymmetric. (3) Re-run the §5.7 calibration. S8 adds three adversarial fixtures: A25, F1 plus an enclosed 20° grip core, ΔD ≤ 0.01; A26, ring grip plus a 40° strap, ΔD ≤ 0.02; A27, hilt shifted 0.04, ΔD(Sharpening) ≤ 0.02.


### R4a-01 [blocker/fidelity] S1's server-side 1e-4 / 1e-6 transform quantization violates the fixed free-transform decision, and its numeric justification fails at S2's 24-part limit

Sections: S1, S6, S8 | needsUserDecision: False | confidence: high

**Problem.** BRIEF §1 (user decision): no server-side quantization of transforms. S1 §3.4/§3.5 quantize Pos/Size to 1e-4 stud and Rot to 1e-6 inside Canonical.draft, which the server runs on every wire draft (checks 8–10 '→ quantize'). S1 justifies this as invisible ('1/20 pixel') and as a −40 % storage saving the caps need. Both numbers are wrong for this spec. At S6's maximum zoom (k = 4, CAM_MIN_DIST 1 display stud, FOV 50°, 1080 px), 1 px is 2.16e-4 bp stud, so the quantum is about 0.46 px, not 1/20 px. With S2's PARTS_MAX = 24, the raw-double worst case still fits S1's own 50 % target at the 40/150 caps. The quantization also sets a 0.001-stud floor on snap increments ('0.001 = 10 storage quanta').

**Evidence.** S1 §3.4: 'Relation to BRIEF §1 (no server-side quantization of transforms): this is a storage precision, not a gameplay quantization — it is 1/20 pixel'. S6 §11.4.1 table: '0.05-bp detail at max zoom 231.6 px', so 1 bp stud = 4,632 px and 1e-4 bp = 0.46 px. R4a/sizes_raw_r4a.py → out_sizes_raw_r4a.txt: 'raw worst part: 294 B vs quantized worst 181 B'; 'raw doubles, 24 parts, GUID, 40/150: MVP 1686758 B = 40.2%, Phase2+ 1910198 B = 45.5%'; 60/250 gives 65.7 %. S1's canon prototype re-run reproduces its own claims (R4a/protoS1/out_canon.txt: 0 idempotency failures, max displacement 9.056e-05).

**Proposed fix.** S1 adopts its own documented alternative: store transforms as raw finite doubles (S1's probe shows Roblox JSON round-trips them exactly). Canonical keeps everything that is not quantization: finiteness and range checks, quaternion normalization when |‖q‖²−1| > 1e-5 (no rounding), the hemisphere sign rule, −0 → 0, and ascending part ids. Remove the LEN_SCALE/QUAT_SCALE rows from §3.4, §9.5 and §16, and the displacement clause of I13. Relax the lower bounds of SNAP_LEN_STEP_RANGE and SNAP_ROT_STEP_RANGE to any positive finite value (keep the upper sanity bounds). Keep the caps at 40/150 with MAX_PARTS_ABS = 24 (worst case 40.2 % / 45.5 %, see R4a-15). S2 already assumes lossless doubles (§3.4 'Assumes (S1)'). S8 drops the ≤ 1e-4 displacement property test. Owner S1; S2, S6 and S8 adjust their references.


### R4b-01 [blocker/conflict] S5's Guard rejects S3's buffer timeline: every honest Submit gets E_BAD_REQUEST + Hard strike

Sections: S5, S3, S8 | needsUserDecision: False | confidence: high

**Problem.** S3 sends each step's inputs as one buffer (12-byte header + 3/2/7-byte records; caps 1024/512/2048 records = 3,084/1,036/14,348 B). S5's normative Guard for Craft.Submit accepts only `inputs = G.intArr(4096, int32)`, and its plain() primitive explicitly rejects buffers, so a correct S3 client fails Guard -> E_BAD_REQUEST + Hard strike (10 strikes = kick) and no item can ever be forged. Even as ints, a Trace record is 4 values (t,u,v,flags): a long realistic trace (1,355 records) needs 5,420 values and the cap needs 8,192 > 4,096. S5's size numbers (Submit <= 36 KB, 'PrecisionTrace at <= 30 Hz as (t,x,y)') describe a format nobody uses, and S8's T-MG-08 garbage-timeline fuzz assumes tables ('non-table, NaN, ...').

**Evidence.** drafts/S5 §10.4 Guard spec: `inputs = G.intArr(N.MAX_INPUT_VALUES, I32[1], I32[2])`; primitives: plain() 'rejects ... functions, buffers, NaN/±inf'; §10.6 'Guard.check ... fail → E_BAD_REQUEST + Hard strike'; §16 MAX_INPUT_VALUES = 4096. drafts/S3 §6.7 'One buffer, little endian, sent through a RemoteEvent'; caps table 3,084 / 1,036 / 14,348 B. Measured: review/R4b/out/pt_cost.txt (serrated 26 s trace: max 1,355 records, 9,497 B; saw 30 s: 1,545 records, 10,827 B).

**Proposed fix.** S5 owns. Add Guard primitive `G.buf(maxBytes)` (typeof == 'buffer', length <= maxBytes, never throws); `Craft.Submit.inputs = G.buf(N.MAX_TIMELINE_BYTES)` with MAX_TIMELINE_BYTES = the largest family cap (14,348 B today; 11,212 B if R4b-07's Trace cap of 1,600 is adopted). Before S3's Timeline.decode, CraftService checks buffer.len <= 12 + MAX_RECORDS[family]·RECORD_BYTES[family] (3,084 / 1,036 / 14,348). Delete MAX_INPUT_VALUES and the intArr spec. Change §10.13 to 'Submit <= 14.4 KB (typ. 38 B–5.4 KB, long traces <= 11 KB)' and replace payload_size's Submit estimates with S3's measured sizes. S8: T-MG-08 and the Guard fuzzer generate malformed buffers covering every S3 decode reason (Short, Version, Family, TooMany, Length, Duration, NotIncreasing, PastEnd, BadKind, NotAlternating, OutOfPanel, BadFlags). Platform reviewers should confirm buffer replication through RemoteEvent (not found in the Creator Docs pages I could reach). Fallback: S3 sends buffer.tostring(b) and S5 adds `G.bytes(maxLen)` (binary string, no UTF-8/control-char check).


### R5a-01 [blocker/platform] Orthographic editor camera does nothing in Studio 0.745; the pcall fallback never fires and the fallback eye ends up outside the enclosure

Sections: S6, S8 | needsUserDecision: False | confidence: high

**Problem.** S6 uses Camera.ProjectionType/OrthographicMode/OrthographicSize for the Flat/Edge/Tip presets (AutoOrtho on by default) and for the O toggle. It detects lack of support only through an error when setting ProjectionType. In Studio 0.745 the writes are accepted without error and ignored. The editor would therefore believe it is orthographic while rendering a perspective camera placed ORTHO_EYE_DIST = 100 studs away. Zoom (which edits OrthographicSize) would do nothing, the 20-stud sword would fill only about 12% of the width, and gizmo sizes and pan speeds derived from OrthographicSize/VH would be about 5x off. The specified fallback (FOV 6°, eye at OrthographicSize/(2·tan 3°)) puts the eye 176 studs from the pivot at frame-all and 747 studs at full zoom-out. Both are outside the 240³ enclosure (half-size 120), so the camera would look at the outside of a slab. S8's Studio playtests run on exactly this build.

**Evidence.** S6 §11.5 table: '`O`, Numpad `5` | toggle orthographic | `ProjectionType = Orthographic`, `OrthographicMode = Vertical`, `OrthographicSize = 2·d·tan(FOV/2)` ... eye at `P − look·ORTHO_EYE_DIST`'. S6 §11.5 'Ortho fallback': 'If setting `ProjectionType` errors (pcall) the toggle falls back to a long lens: FOV 6°, eye distance `OrthographicSize/(2·tan 3°)`'. S6 §11.4.3: 'inner box 240³ display studs'. Probe (execute_luau, Edit, unparented Camera): ProjectionType←Orthographic gives pcall ok, reads back Perspective, and GetPropertyChangedSignal does not fire. OrthographicSize←100/50/18.46/10 always reads back 35. OrthographicMode←MaxAxis reads back Vertical. ViewStretch←1.5 reads back 1. FieldOfView←6 reads back 6, so ordinary writes work. Docs Enum.OrthographicMode: 'In the initial beta, a bug makes it apply to both axes'. Arithmetic (review/R5a/numbers.py): 18.46/(2·tan 3°) = 176.1 studs; 78.3/(2·tan 3°) = 747 studs.

**Proposed fix.** S6 owns this. (1) Detect support by write then read-back, not by pcall: at editor open set cam.ProjectionType = Orthographic, take orthoOK = (cam.ProjectionType == Enum.ProjectionType.Orthographic), then restore Perspective; re-check at every editor open. (2) If unsupported, the presets and O use a telephoto fallback: FOV 20°, eye distance d = OS/(2·tan 10°) = 2.836·OS, with OS clamped to ≤ 38.8 display studs (eye ≤ 110 < 120; frame-all OS 18.46 gives d = 52.3). Zoom changes d, and pan uses wpp = 2·d·tan(10°)/VH. Label it 'Flat view', not 'Ortho'. In §11.22/§16, set ORTHO_FALLBACK_FOV = 20 and add ORTHO_FALLBACK_MAX_OS = 38.8. (3) AutoOrtho (default on) means 'orthographic if supported, else telephoto'. (4) Never rely on ViewStretch. (5) S8 runs the editor scenarios and S-VIS-02/03 on the fallback path, and adds the true-ortho path only once a client accepts the writes.


### R5b-01 [blocker/conflict] Minigame timeline is a buffer in S3/S6 but S5's Guard only accepts an int32 array; StepOpenView lacks source and patternHash

Sections: S3, S5, S6, S8 | needsUserDecision: False | confidence: high

**Problem.** S3 and S6 encode the input timeline as one binary buffer and send it as Craft.Submit.inputs. S5's Router validates inputs with G.intArr(4096), and plain() explicitly rejects buffers. As written, every honest submission fails the Guard: E_BAD_REQUEST, a Hard strike, and no craft can ever complete. S3's client also regenerates the pattern from spec.source (the edge polyline from edgeToPanel, Sharpening only) and checks spec.patternHash. S5's StepOpenView carries neither, so the client cannot reproduce the PrecisionTrace pattern or write the header hash, and the server's judge would return HashMismatch. Buffers are a supported remote argument type (Roblox buffer docs: the target receives a copy), so S3's format is feasible. The two contracts were simply never reconciled.

**Evidence.** S3 §6.7: "One `buffer`, little endian, sent through a RemoteEvent" (PrecisionTrace max 14,348 B). S6 (line ~1062): "Minigames.encode(spec, records) → buffer" and sends "Craft.Submit{sid, i, inputs, clientScore}". S5 §10.4: `inputs = G.intArr(N.MAX_INPUT_VALUES, I32[1], I32[2])`; plain() "rejects ... buffers"; proto/S5/lib/Guard.luau intArr: `if type(v) ~= "table"` → reject; S5 §10.6 step 7: "fail → E_BAD_REQUEST + Hard strike". S3 §6.1 spec = {family, seed, params, source, durationMs, countdownMs, patternHash, balanceVersion}; S5 §10.4 StepOpenView has no source/patternHash. S3's StepStart/StepSubmit/ReportDesync remotes do not exist in S5's §10.3 catalogue.

**Proposed fix.** S5 owns the transport and adopts S3's buffer. (1) Craft.Submit args become {sessionId, stepIndex, timeline: buffer, clientScore?}. (2) New Guard primitive G.buf(maxBytes) = type(v) == "buffer" and buffer.len(v) <= maxBytes, with MAX_TIMELINE_BYTES = 16384 (≥ 12-byte header + PrecisionTrace's 14,336 B of records). Delete MAX_INPUT_VALUES and intArr from Submit. Family.decode takes the buffer (S3 Timeline.decode). (3) StepOpenView gains source: {number}? (output of S3 edgeToPanel, nil for other families) and patternHash: number (u32). (4) Map S3's names onto S5's actions: StepStart = Craft.StartStep reply, StepSubmit = Craft.Submit, StepResult = the Submit reply. Add Craft.ReportDesync{sessionId, stepIndex} with the policy of R5b-02. (5) S8's Guard fuzzer adds buffer cases (wrong length, oversize, non-buffer). Budget sizes on uncompressed bytes; compression is not documented on the buffer page.


### R5b-03 [blocker/conflict] Blueprint and item id schemes are incompatible (S1 'B<n>'/'I<n>' vs S5 client GUID / session GUID)

Sections: S1, S5, S8 | needsUserDecision: False | confidence: high

**Problem.** S1 mints server-side ids 'B<n>'/'I<n>' from NextIds. S1's Canonical rejects any other blueprint Id, and its invariants I1/I2 depend on the format. S5's Guard requires blueprintId to be a 36-character GUID, and S5's idempotency design depends on GUIDs: Save is an upsert keyed by a client-minted GUID so retries never duplicate, and the item id is the craft session GUID used as the dedupe key. S1 keeps Id inside the draft, while S5 passes blueprintId as a separate argument. As written, S5's Guard rejects every S1 id (E_BAD_REQUEST plus a Hard strike), S1 rejects every GUID (Malformed), and no Save can succeed. Switching to S1's ids without a replacement token would also break S5's retry-safe create.

**Evidence.** S1 §3.5 check 3: "`Id` is nil (create) or matches `^B[1-9]%d*$`"; S1 §9.3: "NextIds ... next n for "B<n>" / "I<n>"; never decremented"; I1. S5 §10.4: `blueprintId = GUID` (guid() = 8-4-4-4-12 hex); §7.P7: "upsert by client-minted GUID ... retries never duplicate"; §7.P5: `Crafting.Item.create({ id = s.id, ...})` with s.id = HttpService:GenerateGUID(false).

**Proposed fix.** Use GUIDs everywhere, because S5's retry and dedupe rules depend on them. Blueprint id = client-minted HttpService:GenerateGUID(false), upper-cased by the server and validated as 36 characters 8-4-4-4-12 hex. Item id = craft session GUID. S1 drops NextIds (or keeps a counter for display numbering only) and rewrites Canonical check 3: the draft carries no Id, and the id travels as Save.blueprintId. S1 also updates Ids.luau and I1/I2, and adds about +33 B per id to its size formula (≈ +12 KB at 40/150 caps). Alternative if the lead keeps 'B<n>': S5 adds a client request token (clientRef GUID, remembered for TOMBSTONE_MS) so a create retried after E_TIMEOUT is not duplicated. Either way, one rule owned by S1 (schema) with S5 (protocol) following it.


### R7-01 [blocker/testing] Lune-tested pure modules outside src/shared cannot require shared code in both Lune and Studio

Sections: S5, S6, S8 | needsUserDecision: False | confidence: high

**Problem.** S6 puts its pure editor logic (EditorState, Commands, History, Snap, Rotation, Mirror, GizmoMath, UI/Layout, UI/Expr) in src/client, and S5 puts the pure SessionMachine in src/server, in both cases so that S8 can run them under Lune. S8 says its tests/lib also runs in Studio. These modules need src/shared code (S1 Schema/Canonical/Limits, S4 PlanStep types, S3 families). Lune resolves a string require against the file tree. Roblox resolves it against the Rojo instance tree. The two trees differ across roots: src/client → StarterPlayerScripts.BlacksmithClient (at runtime Players.<name>.PlayerScripts), src/shared → ReplicatedStorage.Blacksmith, tests/lib → ReplicatedStorage.BlacksmithTests.lib. '@game/...' resolves only in Roblox. Luau has no type-only import, so even a type reference needs a runtime require. As written, these modules either fail to load in Studio or cannot load in Lune. BRIEF §3 verified requires only inside one root.

**Evidence.** S6 §11.1 item 5 ('take and return plain numbers/tables ... so S8 can test them under Lune') and §11.2 tree (src/client/Editor/*.luau (pure)). S5 §7.P8 ('src/server/Craft/SessionMachine.luau — no Roblox APIs ... S8 tests it under Lune'; signature takes plan: { S4.PlanStep }). S5 §1.4 R2 (relative string paths only). S8 §14.2 ('lib/ portable test library (runs in Lune AND Studio, except Golden)'); V-10 is still open. Creator Docs LuaGlobals.require: 'Paths with the ../ prefix begin resolution at script.Parent.Parent' and '@game/ prefix begin resolution at game'. Mini repo review/R7/tree (S5's default.project.json + an S8-style test.project.json): Lune runs tests/Editor/CrossRoot.spec.luau and prints 'Mirror.reflect(1) = 49 SessionMachine.new() = Ready Bots ok = 1'. 'lune run review/R7/checkreq.luau -- sm_test.json', which resolves every string require in the rojo sourcemap, prints 'FAIL src/client/Editor/Mirror.luau require(../../shared/Blueprint/Canonical): no instance for component shared'; it gives the same FAIL for src/server/Craft/SessionMachine.luau and tests/lib/Bots.luau. Read-only Studio probe on an unparented tree with the Rojo layout: 'Lune-style ../../shared/Blueprint/Schema from BlacksmithClient.Editor.Mirror: ok=false -> Requested module experienced an error while loading'.

**Proposed fix.** Add rule R2b to S5 §1.4: every module that runs under Lune lives in src/shared; src/client and src/server contain only Roblox-bound code; no string require crosses a Rojo root. Move S6's pure modules to src/shared/EditorCore/{EditorState, Commands, History, Snap, Rotation, GizmoMath, Expr, EditorLayout}; Mirror goes to src/shared/Blueprint/Mirror (R7-13). Move S5's SessionMachine to src/shared/Session/SessionMachine.luau; it reveals nothing beyond what Definitions/Network already replicates. In S8, tests/lib modules never require src/. Specs (Lune, relative paths) and e2e snippets (Studio, instance paths) pass game modules in, e.g. Bots.timeline(familyModule, pattern, params, profile, rng). This closes V-10. S8 adds T-META-07, run by scripts/verify before any spec loads: resolve every string require on disk and in 'rojo sourcemap --include-non-scripts' of both project files, and fail on any mismatch or require cycle. review/R7/checkreq.luau is a working resolver of about 120 lines. Owners: S5 (rule, tree), S6 (paths), S8 (lib, T-META-07).


### R7-02 [blocker/conflict] Two incompatible canonical blueprint forms and three quaternion implementations; S1's 1e-4/1e-6 grid contradicts the fixed user decision

Sections: S1, S2, S6, S7, S8 | needsUserDecision: False | confidence: high

**Problem.** Two normalizers disagree on almost every rule, and no draft says which one runs or which result is stored. S1's Canonical.draft quantizes Pos/Size to 1e-4 stud and Rot to 1e-6 and stores Quat as {qx,qy,qz,qw}. It accepts |pos| ≤ 64 and sizes from 1e-4 to 64, and rejects quaternions with |‖q‖²−1| > 1e-2. S2's Geometry.sanitizePart keeps continuous values and uses {w,x,y,z}. It accepts |pos| ≤ 100, normalizes any q with n² ≥ 1e-12 and clamps sizes to [0.05, 6.0], at analysis time only. So a 0.01-thick blade passes S1, is drawn 0.01 thick from the stored part, and is measured as 0.05 thick (5× its drawn mass). Tolerances conflict too: S1 requires every S2 tolerance ≥ 1e-3, and S2 uses EPS_CONTAIN 1e-4. Quaternion math is written three times: S1 Blueprint/Quat; S2 Geometry canonicalQuat/quatToBasis/basisToQuat (formula valid for unit quaternions only); S6 Editor/Rotation mul/normalize/toMatrix/fromMatrix. S7 asks S2 for a fourth helper (Geometry.partMatrix) only to avoid depending on component order. The part cap has three values: S1 MAX_PARTS_ABS 48, S2 PARTS_MAX 24, S7 MAX_RENDER_PARTS_HARD 64. Finally, S1's grid quantizes transforms when the server saves, which BRIEF §1 rules out, and its storage argument disappears at S2's 24-part cap.

**Evidence.** S1 §3.4 table ('round(x · 10⁴) / 10⁴', QUAT_SCALE 1e6) and §3.5 rows 8–10. S1 §3.2: 'Quat = { number } -- exactly {qx, qy, qz, qw}'. S2 §3.4: 'Continuous values only (user decision): no server-side quantization, no rotation steps'. S2 §3.5 rules S2/S3/S5 and 'Implemented once (Blueprint/Geometry.sanitizePart)'. S2 §4.8: 'Quat = { w, x, y, z }'. S7 §13.8.6: 'S1's and S2's prototypes currently differ: w-last vs w-first'. BRIEF §1.1: 'There is no server-side quantization of transforms'. Re-ran proto/S1/rawsize.luau (copy in review/R7/s1): 'raw doubles avg 183.6 chars (max 193) ... part record ~285 B raw vs ~171 B quantized'. S1 §9.7's formula is W = 3,090 + B(625 + p·P) + I(1,972 + p·P). With B = 40, I = 150, P = 24 and raw doubles (p = 294 B): 1,664,530 B = 39.7 % of the 4 MiB key, under S1's own 50 % target (quantized: 27.2 %). Only S1's placeholder P = 48 needs the grid (raw: 71.6 %).

**Proposed fix.** Keep one canonical form in one module. S1's Blueprint/Canonical.draft becomes the only sanitizer (editor commit, server Save and Begin, tests) and runs S2's rules as its per-shape hook: (a) all numbers finite; (b) |pos| ≤ POS_LIMIT 100; (c) each size in [MIN_DIM 0.05, MAX_DIM 6.0], otherwise reject with OutOfRange (the editor clamps before commit, so stored = drawn = measured); (d) Ball/Cylinder size canonicalization; (e) normalize q only when |‖q‖²−1| > 1e-12, then apply the hemisphere sign rule. A second pass is then a no-op, so the form is idempotent without a grid. Store raw doubles. Keep S1's rule that Instances are one-way views; S8's S-PAR-03 confirms the JSON round trip. Delete Geometry.sanitizePart/canonicalQuat/quatToBasis/basisToQuat. Add one src/shared/Blueprint/Quat.luau with components {qx,qy,qz,qw} (the CFrame.new order): S1's s = 2/|q|² toMatrix, Shepperd fromMatrix, normalize, canonical, mul, rotate. S2 uses it; S6's Rotation keeps only Euler ⇄ quaternion for display; S7's RenderPlan calls Quat.toMatrix (no Geometry.partMatrix). Define one MAX_PARTS = 24 (S2's value) in Definitions/Limits and derive S7's render cap from it. S2 keeps EPS_CONTAIN 1e-4; S1's ≥ 1e-3 requirement goes away with the grid. S1 recomputes the §9.7 caps for 24 parts with raw doubles. S8 rewrites T-BP-02/03 (idempotency; unit norm within 1e-12). This answers S1's open question 1 in line with the user's decision.


### R7-03 [blocker/conflict] The minigame ↔ craft-session contract is defined three incompatible ways (S3 facade, S5 SessionMachine.Family, S8 test API)

Sections: S3, S5, S8, S4, S6 | needsUserDecision: False | confidence: high

**Problem.** S5's SessionMachine calls generate(params, seed), decode(raw, pattern) and replay(pattern, inputs) → {score, pass, verdict Ok|Soft|Hard, flags}. S3's modules expose generate(seed, params, source) and newSession/push/advance/finish, and the server entry is Minigames.judge(spec, pattern, timeline, elapsedMs) → MinigameResult {status Ok|Invalid, score, rawScore, passed, flags, invalidReason, breakdown}. S8 tests generate(seed, params) and replay(pattern, params, timeline) → {ok, code?, score, pass, flags}. The wire formats also disagree. S3 sends one buffer (a 12-byte header plus records). S5's Guard requires inputs = intArr(4096), and Guard.plain rejects buffers. S3's client needs StepSpec {family, seed, params, source, durationMs, countdownMs, patternHash, balanceVersion}; S5's StepOpenView has no source (the PrecisionTrace path) and no patternHash. S3's ReportDesync (re-issue the step with a new seed) has no action in S5's 17-action catalogue. It also contradicts S5's 'seed issued ONCE ... no re-roll' and would give a cheater one free seed re-roll per step. Smaller mismatches: pass vs passed; S5 expects params inside the Begin plan while S3 resolves them in prepare; clientScore is compared with the post-clamp score (eps 1e-9 in S5, 5e-5 in S3), so every HIGH-flag clamp also raises ScoreMismatch. S6 says input quantization belongs to 'S3's input layer', but no S3 module provides it.

**Evidence.** S5 §7.P8 'Family = { generate: (params, seed) -> Pattern, decode, replay }' (proto/S5/lib/SessionMachine.luau line 13 matches). S5 §10.4: Submit Guard 'inputs = G.intArr(N.MAX_INPUT_VALUES, ...)', and plain() 'rejects ... buffers' (proto/S5/lib/Guard.luau line 209). S5 §10.4 StepOpenView fields; §10.3 catalogue; §7.P2 'seed issued ONCE'. S3 §6.2 FamilyModule, facade signatures and StepSpec; S3 §6.7 'One buffer, little endian'; S3 §6.4.4 'the server re-issues the step once with a new seed' and 'clientScore − serverScore > 0.00005'; S5 §16 SCORE_MISMATCH_EPS = 1e-9. S8 §14.6.6 heading. S6 §12.3.2 'records, quantization, encoding are S3's'. Re-ran S3 'run_all.luau -- det' (copy in review/R7/s3): 0 live/replay/codec mismatches; largest timelines 3,084 / 1,036 / 14,348 B.

**Proposed fix.** S3's facade is the contract (owner S3), and S5 adapts. At StartStep, SessionMachine calls Minigames.prepare(input), where input = {family, seed, material, tier, factors, edge} from the plan frozen at Begin; params are resolved there. It stores {spec, pattern}. At Submit it calls Minigames.judge(spec, pattern, timeline), with the wall-clock part removed from judge (R7-12). S5 owns one verdict mapping: status Invalid → abort with InvalidInput plus a Hard strike (S4 R9 / S5 rule; S3's §10.M5 'failed step' text changes); any HIGH flag → Soft (S3 has already clamped the score); otherwise Ok. Guard gains buf(maxBytes), and Craft.Submit validates timeline = G.buf(14348) (S3's largest cap: PrecisionTrace 2,048 × 7 + 12 B). Delete inputs and MAX_INPUT_VALUES. StepOpenView = {sessionId, index, stepId, tier, spec: StepSpec, countdownMs (remaining), lateAllowanceMs}. Desync: no re-issue in the MVP. A client whose Minigames.start fails sends Craft.Abandon {reason = Desync}, and S5 logs it; with pure deterministic code, a desync is a bug, not a gameplay case. S5 §7.P4 compares clientScore with MinigameResult.rawScore by exact equality of the round4 values. S3 adds a pure Minigames.record(family, raw) → Record (clamping, round(u·16384), integer ms) for S6's input capture, S8's bots and S8's autoplay hook. S8 rewrites §14.6.6 against S3's API. Use the field name passed everywhere.


### R1-06 [major/conflict] Plot assignment and spawning are specified twice, incompatibly

Sections: S5, S7, S8 | needsUserDecision: False | confidence: high

**Problem.** S5 assigns the lowest free plot on PlayerAdded, before the profile loads. It sets player.RespawnLocation = plot.spawn (one SpawnLocation per plot and none elsewhere), calls LoadCharacter in the Studio race, kicks when no plot is free, and calls World.build() -> {plots} and World.claimPlot/resetPlot. S7 builds one neutral PlazaSpawn and no plot spawns, never uses RespawnLocation, and moves the character home with PivotTo on every CharacterAdded. S7 also assigns after the profile session starts, makes a plot-less player visitor-only (NoPlot), and exposes WorldBuilder.build() and PlotWorld.claim/release/teleportHome. PLOT_COUNT is defined in both Definitions/Network (S5) and Definitions/World (S7).

**Evidence.** S5 §1.6: 'Spawn | player.RespawnLocation = plot.spawn' and 'No free plot | Kick'; S5 §1.6 Assumes (S7): 'each plot owns exactly one SpawnLocation ... and the world has no other enabled SpawnLocation'; S7 §13.2.1: 'One SpawnLocation "PlazaSpawn"'; S7 §13.3.2: 'Player.RespawnLocation is not used'; S7 §13.3.1 Assign: 'After the profile session starts ... visitor-only'.

**Proposed fix.** Spawn: S7's mechanism wins (plaza SpawnLocation plus a deferred PivotTo to Layout.homePose on CharacterAdded once the plot is claimed; no RespawnLocation, no LoadCharacter). Assignment: S5's timing wins. PlotService.assign and PlotWorld.claim run on PlayerAdded, so the home pose exists for the first CharacterAdded, and ShowcaseService renders the stands on ProfileLoaded. No free plot: S5's kick (only reachable through misconfiguration), and S7 drops its NoPlot paths. API: S5 calls S7's names (WorldBuilder.build() returns {plots: {{index, model}}}, PlotWorld.claim/release). PLOT_COUNT lives once, in Definitions/World (S7), and S5's boot check reads it. Changes: S5 §1.5, §1.6 and §16; S7 §13.3; S8's S-E2E-02 'within 10 studs of the plot spawn' becomes 'of the home pose'.


### R1-07 [major/conflict] S5's session machine is built on a minigame API that S3 does not provide

Sections: S3, S4, S5, S8 | needsUserDecision: False | confidence: high

**Problem.** S5's SessionMachine injects Family {generate(params, seed), decode(raw, pattern), replay(pattern, inputs) -> {score, pass, verdict Ok|Soft|Hard, flags}} and assumes S4's Plan.build returns PlanStep.params (p_final). S3 provides FamilyModule.generate(seed, params, source), Timeline.decode(b, family, durationMs), and a facade: Minigames.prepare(PrepareInput{family, seed, material, tier, factors, edge, balanceVersion}) and judge(spec, pattern, timeline, elapsedMs) -> MinigameResult {status Ok|Invalid, score, rawScore, passed, flags, invalidReason, breakdown}. S4's PlannedStep has no params, factors or edge. S8 assumes a third shape: replay(pattern, params, timeline) -> {ok, code?, score, pass, flags}. The pass field is 'pass' in S5 and 'passed' in S1, S3 and S4.

**Evidence.** S5 §7.P8: 'export type Family = { generate: (params, seed) -> Pattern, decode: ..., replay: ... }'; S5 §7 intro: 'PlanStep = { stepId, family, tier, difficulty, params }'; S3 §6.2 FamilyModule and the Minigames facade; S4 §8.6.1 PlannedStep {index, step, family, weight, tier, difficulty, material, workParts}; S8 §14.6.6 header.

**Proposed fix.** S3's facade is the only minigame API. CraftService.startStep calls Minigames.prepare({family = step.family, seed, material = step.material, tier = step.tier, factors = analysis.steps[i].x (R1-12), edge = analysis.edge (R1-13), balanceVersion}) and keeps (spec, pattern). Submit calls Minigames.judge and receives a MinigameResult. S5 derives its own verdict from it (status Invalid → Hard; non-empty flags → Soft; else Ok) and keeps Soft/Hard as an internal vocabulary. SessionMachine's injected interface becomes {prepare, judge}. Use 'passed' everywhere: S5's StepResult, StepResultView and ReplayResult, and S8. S8 tests judge and replay as S3 defines them. Owners: S3 (API), S5 (adapter).


### R1-08 [major/conflict] Invalid timelines: failed step (S3) or aborted craft (S4/S5)

Sections: S3, S4, S5, S6 | needsUserDecision: True | confidence: high

**Problem.** S3 treats every decode failure and HashMismatch as Invalid: score 0, a failed step, and the craft continues. S3 also assumes S4 counts Invalid as a failed step, and turns S5's timeout into Invalid('Expired'). S5 aborts the whole craft on a decode failure or a Hard verdict (E_INVALID_INPUT, Hard strike), and S4 R9 discards the session. For timeouts, S4 and S5 both score 0 with timedOut = true and continue; that is not an Invalid. S6 implements the S5 behaviour, while S3's UI text says 'Result rejected' with a FAILED step. S6 also describes the fail effect as 'half score', but S4's φ is 0.75.

**Evidence.** S3 §10.M3: 'Every reason ... plus HashMismatch, TooFast and Expired, gives status = "Invalid", score 0 and a failed step'; S3 §6.4.4: 'status == "Invalid" shows "Result rejected" and counts as a failed step'; S3 §10.M1: 'turns a missing submission ... into Invalid("Expired")'; S4 §7.4 R9: 'discards the session ... it is never scored'; S5 §7.P2: 'Submit(i) decode fail / verdict Hard → Aborted(InvalidInput)'; S5 §7.P3: 'Timed out ... step scored 0, pass = false, timedOut = true'; S6 §12.1: 'Fail continues (R5); half score'.

**Proposed fix.** Default follows S4/S5: any S3 Invalid status (a decode reason or HashMismatch) aborts the craft with AbortReason InvalidInput, E_INVALID_INPUT and no item, which S6's UI already does. HIGH flags clamp the score and the step passes (S3), which is S5's Soft. A timeout is not an Invalid reason: S3 removes 'Expired', and the step record carries TimedOut (R1-20). A single user question replaces S5 §17.5 and S3's conflicting text, with abort as the default. Update S3 §6.4.4, §10.M3 and §10.M5. S6 §12.1's 'half score' becomes 'counts at 75 %' (S4 F1).


### R1-09 [major/conflict] Wall-clock windows are defined in both S3 and S5 with different tolerances and outcomes

Sections: S3, S5, S8 | needsUserDecision: False | confidence: high

**Problem.** Both drafts measure the same interval: server os.clock from opening the step to receiving the submission, minus the 3-s countdown. S3 marks a submission Invalid TooFast below C + D − 300 ms and logs SlowClock above C + 1.25·D + 5 s. S5 returns E_TOO_EARLY (state unchanged, Hard strike) below D − 250, sets a soft LateSubmit above D + 1,500 + A, and times out above D + 5,000 + A. S5 checks first, before decode, so S3's TooFast can never fire. S3's SlowClock fires only if D < 4·A, which is unreachable except for a 7-s dagger trace with ping > 875 ms, because S5 has already timed the step out. S3's example timeout ('countdown + duration + 30 s') and S8's Cheat-Fast expectation ('TooFast') follow S3. COUNTDOWN_MS is defined in both sections.

**Evidence.** S3 §10.M1 step 3 and §10.M2; S3 §16: WALL_EARLY_TOLERANCE_MS 300, WALL_SLOW_FACTOR 1.25, WALL_LATE_GRACE_MS 5000; S5 §7.P3 table; S5 §7.P4 steps 5–6 (deadline and early bound checked before decode); S8 §14.8.1: Cheat-Fast 'TooFast (server, S5)'; reachability check (python): SlowClock is reachable only for D = 7000 with A = 2000 among D ∈ {7, 11, 15} s and A ∈ {0.2, 1, 2} s.

**Proposed fix.** S5 owns every wall-clock rule, since it owns the clocks, the sessions and the deadlines. S3's judge drops wall-clock checks: the elapsedMs parameter, the TooFast and SlowClock flags and the WALL_* constants all go, and S3 §10.M2 becomes a pointer to S5 §7.P3. COUNTDOWN_MS lives once, in Definitions/Network, and is copied into StepSpec.countdownMs. S8 expects E_TOO_EARLY and the flag TooEarly for Cheat-Fast.


### R1-10 [major/conflict] Desync re-issue with a new seed contradicts the fixed-seed rule

Sections: S3, S5, S6 | needsUserDecision: False | confidence: high

**Problem.** On a client-side pattern-hash mismatch, S3 sends ReportDesync and expects the server to re-issue the step once with a new seed. S5's catalogue has no ReportDesync, S5 fixes the seed per step (a re-open returns the same seed), S4 R4 forbids seed re-rolls, and S5's threat model lists seed re-rolls as defended. A client-triggered re-issue would be a free re-roll: a cheater could claim a desync on any pattern they dislike.

**Evidence.** S3 §6.4.4: 'It sends ReportDesync, and the server re-issues the step once with a new seed'; S5 §7.P3: 'fixed for the step (re-open returns the same seed: no re-roll)'; S4 §7.4 R4: 'no retry, no seed re-roll'; S5 §10.9: 're-roll a bad seed | seed fixed per step'; S5 §10.3 catalogue (no ReportDesync).

**Proposed fix.** No re-issue. When hash(pattern) ≠ spec.patternHash, the client does not play: it shows an error and sends Craft.Abandon {sessionId, reason = 'Desync', clientHash}, with these as new optional fields and no strike. The server aborts with AbortReason 'Desync' and logs the Desync telemetry event with S3's fields. Update S3 §6.4.4 and §10.M7; S5 §10.3, §7.P2 and the AbortReason union; S6 adds the error path to the forge flow.


### R1-11 [major/conflict] Abandon: step forfeit (S3) vs session discard (S4/S5/S6), with two contradictory user questions

Sections: S3, S4, S5, S6 | needsUserDecision: True | confidence: high

**Problem.** In S3, Esc opens 'Abandon this step?' and confirming forfeits only that step (score 0), so an item is still produced. In S4 R6, S5's Craft.Abandon and S6, abandon discards the whole session with no item. S3 §17.7 and S4 §17.4 ask the designer opposite questions.

**Evidence.** S3 §6.6: 'Esc opens "Abandon this step?" (S6). Confirming forfeits the step: score 0, failed (S4/S5)'; S3 §17.7: 'Abandoning a step forfeits it (score 0)'; S4 §7.4 R6: 'The session is discarded: no item'; S4 §17.4: 'discard with no item (default), or produce an item from the steps played'; S6 cross-section notes: 'S6 follows S4/S5: one session-level Abandon'.

**Proposed fix.** Session-level abandon (S4/S5/S6) is the rule. S3 deletes the step-forfeit text and its §17.7 clause; S4 §17.4 becomes the only user question, with the default unchanged (discard, no item).


### R1-12 [major/gap] Minigame m_design needs per-step factors that S2 does not output

Sections: S2, S3, S4, S5 | needsUserDecision: False | confidence: high

**Problem.** S3 resolves parameters from a 'Factors' map that it says is 'computed once per blueprint'. Its m_design uses Volume for HoldZone, PartCount/Thinness/Asymmetry for TimingStrike and Thinness/SurfaceComplexity/Asymmetry for PrecisionTrace. S2 computes factors per step work set W_s, and each StepDifficulty outputs only the weighted terms: Sharpening's are EdgeLength/Asymmetry/SC and Hammering's are Thinness/Asymmetry/SC. So Thinness on the Sharpening work set and PartCount for Hammering are never output. S4's PlannedStep carries no factors, and S5 has no path to pass them into S3.

**Evidence.** S3 §6.5.1: 'computed once per blueprint (the same values feed D_s)'; S3 §6.9.6: strikes 'PartCount +0.5'; S3 §6.10.7: halfWidth 'Thinness −0.15'; S2 §5.1: 'Computing factors per working set (instead of once per sword) is a deliberate extension'; S2 §4.8 StepDifficulty.terms '{ { factor, w, x, raw } }'; S2 §5.4 weights.

**Proposed fix.** S2's StepDifficulty adds x: { {factor: FactorId, x: number} }: all 8 factors evaluated on that step's W_s, as an array in the fixed FactorId order (determinism rule; little extra cost). S3 states that Params.resolve takes the factor vector of the step being played, not a per-blueprint value. CraftService passes analysis.steps[i].x into Minigames.prepare (R1-07). S4 may carry it on PlannedStep.


### R1-13 [major/conflict] Sharpenable-edge type and trace-panel mapping disagree between S2, S3 and S6

Sections: S2, S3, S6 | needsUserDecision: False | confidence: high

**Problem.** S3 expects SharpenableEdge {sides: at most 2 polylines of {x,y} arrays, each ordered from base to tip} and builds sideA ++ reverse(sideB). S2 emits EdgeProfile {chains: {points: {Vec2 {x,y}}, length}}, CCW and longest first; the main chain of a symmetric sword already runs up the right edge, over the tip and down the left edge. A single-edged blade's CCW chain can run from tip to base, and gaps produce extra chains. S3 also maps blade +X to screen up, while S6 and S7's VIEW_H put +X down (S6 asks for a flip). S3 measures blade length along blueprint +Y, while S2 uses the grip axis A, which can tilt up to 45°. S3's input mapping (GetMouseLocation with IgnoreGuiInset = true) differs from S6's (InputObject.Position − AbsolutePosition).

**Evidence.** S3 §6.2: 'SharpenableEdge = { sides: { EdgePolyline } }', 'from the blade base (guard side) to the tip'; S3 §6.10.1: 'v = 0.5 − (x − (xMin + xMax)/2)·s·E'; S2 §4.6 step 5: 'chains sorted by length descending ... Outer loops are CCW, so the main chain ... runs up the right edge, over the tip, down the left edge'; S6 §12.6: 'Assumes (S3): S3 flips to v = 0.5 + (x − xc)·sx' and 'IgnoreGuiInset = true assumption is not needed'.

**Proposed fix.** S3's edgeToPanel(edge: EdgeProfile) consumes S2's type directly, and SharpenableEdge is deleted. Take up to 2 chains in S2's order and orient each so it starts at the end with the smaller projection on the grip axis. One chain is already the complete U-turn path; two chains become A ++ reverse(B). Measure Lb along A, and map +X down (v = 0.5 + …) to match VIEW_H. S6's canvas mapping is the input contract (S6 owns the canvas), so S3 drops IgnoreGuiInset. S2 documents the chain-orientation guarantee in §4.6.


### R1-14 [major/conflict] Step plan and work sets are defined three times, with a require cycle

Sections: S1, S2, S4, S5 | needsUserDecision: False | confidence: high

**Problem.** S1's StepDef.AppliesTo claims to be the 'single source of truth', with the placeholder Hammering = Blade, Guard, Pommel (Grip excluded), a global per-step QualityWeight and a MainStat. S4 adds Definitions/CraftPlans with worksOn ('All' = all kept parts, Grip included), per-equipment-type weights and feeds. S2 has its own StepRule.workingSet (nil = all). S4 says Physics/Difficulty may require Crafting/Plan for workSet, but S5's dependency graph has Crafting depending on Physics, so both together form a cycle.

**Evidence.** S1 §2.7: 'AppliesTo is the single source of truth' and 'Hammering ... Sword → Blade, Guard, Pommel'; S4 §8.6.3 'Definitions/CraftPlans.luau (new file, S4)' with 'worksOn = "All"'; S2 §4.8: 'workingSet: { SlotId }?, -- nil = all slots (S4 decides the sets)'; S4 §8.6: 'Physics/Difficulty may require Crafting/Plan (for workSet)'; S5 §1.4: 'Definitions ◄── Blueprint ◄── Physics ◄──── Crafting'.

**Proposed fix.** S4's Definitions/CraftPlans is the single source: CraftPlans[type].steps[i] = {step, weight, worksOn = 'All' | {SlotId}, feeds = {StatId}}, where 'All' means all kept parts, and Hammering = All replaces S1's placeholder. S1 removes AppliesTo, QualityWeight and MainStat from StepDef (keeping Id, Name, Order, Enabled, Family and FactorWeights), and adds CraftPlans to its Definitions table, its V2 checks and the BALANCE manifest (R1-36). S2 drops StepRule.workingSet. The selector helper workSet(parts, kept, selector) moves to a module that both Physics and Crafting can require (e.g. src/shared/Blueprint/WorkSet.luau), so Physics never requires Crafting, and S5 §1.4 shows the edge.


### R1-15 [major/bug] A valid sword can have no kept Blade part and then crash Craft.Begin

Sections: S2, S4, S6, S8 | needsUserDecision: False | confidence: high

**Problem.** S4 assumes S2's validation guarantees at least one kept Blade part, asserts #W > 0 in Plan.build and asserts positive kept volume in Stats.inputs. But S2 counts cleaned parts for validation, slots included. The smallest legal part, a 0.05-stud cube (0.000125 stud³), is below MIN_PART_VOLUME (0.0002), so it counts as dust. A sword whose only Blade part is such a speck, or a Blade fully enclosed in the guard, is valid by S2 and then hits S4's assert at Begin, which becomes E_INTERNAL. S8's A22 assumes the opposite rule ('required-slot check runs on the cleaned set').

**Evidence.** S4 §7.2: 'Assumes (S2): ... validation guarantees at least one kept Blade part'; S4 §7.3: 'assert #W > 0'; S2 §4.4: 'Validation V1-V6 (counts, slots, containment, connectivity) | yes' (cleaned parts included) and 'Dust | V_p < MIN_PART_VOLUME = 0.0002 stud³ (... the minimum-size 0.05 cube is 0.000125)'; S8 §14.7.5 A22.

**Proposed fix.** S2 adds a rule V3b, evaluated after cleaning in both editor and server: every Required slot (Blade, Grip) must keep at least one kept part, otherwise code SlotMissing with detail 'Cleaned' (or a new SlotOnlyCleaned). Validity then implies a non-empty Sharpening work set, and S4 keeps its asserts. S8 rewrites A22 around the required slots, and S6 adds the issue text.


### R1-16 [major/conflict] Two sanitizers with different bounds: stored, rendered and analyzed parts can differ

Sections: S1, S2, S5, S6, S8 | needsUserDecision: False | confidence: high

**Problem.** S1's Canonical.draft calls itself 'the only entry point for client data'. It rejects |Pos| > 64 and Size outside 0 < v ≤ 64, accepts sizes down to 1e-4, rejects quaternions with |‖q‖²−1| > 1e-2, and caps the part count at min(PartLimits.Max, 48). S2's sanitizePart 'runs identically on client and server, before anything else': it rejects |pos| > 100, normalizes any quaternion with norm² ≥ 1e-12, clamps sizes to [0.05, 6.0] and canonicalizes Ball/Cylinder sizes. S5 calls 'S1 Sanitize.fromWire' and expects it to check 'min dimension'. S8's A11 expects sizes below MIN_DIM to be rejected (BadSize). S6 clamps only during drags. As a result, a 0.01-stud part is stored by S1, rendered at 0.01 by S7, but measured at 0.05 by S2, so mass, Thinness and edge differ from what the player sees. A quaternion (2,0,0,0) is rejected by S1 and accepted by S2. S2's V2 TooManyParts can never fire, because S1 rejects such drafts at save.

**Evidence.** S1 §3.5: check 9 'Size: 3 finite numbers, 0 < v ≤ SIZE_MAX (64 stud) → quantize → ≥ 1e-4' and check 10 'QUAT_INPUT_TOL (1e-2)'; S2 §3.5: S2 '|position.k| <= POS_LIMIT (100)', S3 'n2 >= 1e-12', S5 'each size component clamped to [MIN_DIM, MAX_DIM] = [0.05, 6.0]'; S5 §10.10: 'S1 Sanitize.fromWire (enums, finite numbers, MVP-enabled materials, min dimension, unit quaternions)'; S8 A11 'reject BadSize'; S6 §11.9.4: 'Constraints during drags: sizes clamp to [MIN_DIM, MAX_DIM]'.

**Proposed fix.** Use one pipeline: S1's Canonical.draft is the only sanitizer from wire to stored record. It enforces S2-owned constants: MIN_DIM 0.05 ≤ size ≤ MAX_DIM 6.0 (reject with OutOfRange), one position bound (keep S1's POS_ABS_MAX = 64, since Canonical runs first; S2 deletes POS_LIMIT), the quaternion tolerance, and S2's per-shape rules (Ball uniform, Cylinder sy = sz) as the S2 hook in step 11. S2's sanitizePart becomes that hook and loses its clamp; S2's analysis then assumes canonical input and drops the dead TooManyParts rule. S5 calls Canonical.draft, S6's typed size fields enforce the same bounds, and S8's A10–A12 expect S1's CanonError codes.


### R1-17 [major/conflict] Part, vector and quaternion types differ between S1, S2, S7 and S8

Sections: S1, S2, S3, S6, S7, S8 | needsUserDecision: False | confidence: high

**Problem.** S1's PartData is {Id, Slot, Shape, Material, Pos, Rot, Size}, with Pos/Size as {x,y,z} arrays and Rot as a {qx,qy,qz,qw} array. S2's API (Analyze.validate/run, Geometry.*) takes PartGeom {shape, slot, material, position {x,y,z} named, rotation {w,x,y,z} named, size} and claims 'S1's part record maps 1:1 onto this'. S7's RenderPlan reads PartView {shape, slot, material, pos, rot, size}, and S7 asks S2 for a Geometry.partMatrix helper because S1 puts w last and S2 puts it first. S6 passes S1 PartData to both S2 and RenderPlan. S8's fixtures write (x, y, z, w). S3's EdgePolyline uses arrays where S2's Vec2 uses named fields. There are two rotation-matrix definitions: S1's Quat.toMatrix (s = 2/|q|², exact for any non-zero q) and S2's quatToBasis (assumes unit q).

**Evidence.** S1 §3.2: 'export type Quat = { number } -- exactly {qx, qy, qz, qw}'; S2 §4.8: 'export type Quat = { w: number, x: number, y: number, z: number }' and 'PartGeom = { -- S1's part record maps 1:1 onto this'; S7 §13.8.6: 'Assumes (S2): a pure helper Geometry.partMatrix(part) ... (S1's and S2's prototypes currently differ: w-last vs w-first)'; S6 §11.7.3: 'RenderPlan.fromBlueprint(parts, { scale = k, anchor = origin })' called with S1 parts; S8 §14.7.1: 'Rotations are unit quaternions (x, y, z, w)'.

**Proposed fix.** S1's PartData is the only part type that crosses a module boundary: wire, storage, Analyze input, RenderPlan input and the editor document. S2's named PartGeom, Quat and Vec3 become private to Physics, converted once in Shapes.prepare. S1's Quat.toMatrix is the single rotation function: S2's quatToBasis delegates to it, and S7 uses it instead of a new Geometry.partMatrix. S7's PartView becomes PartData, and S8's fixtures are written as PartData. Owner: S1 (types); S2, S7 and S8 adapt.


### R1-18 [major/conflict] Definitions record shapes and field names: S1's catalogue rows vs S2/S3/S4 schemas

Sections: S1, S2, S3, S4, S7 | needsUserDecision: False | confidence: high

**Problem.** S1's rows use PascalCase: MaterialDef {Density, Hardness, Toughness, DifficultyTerm, QualityMultiplier, FamilyModifiers}, SlotDef {Id, Name, Required, Striking, MaxParts}, EquipmentTypeDef {Hitbox{Min,Max}, PartLimits{Min,Max}, ReferenceRanges as a map}, StepDef.FactorWeights as a map, TierDef {DMin, DMax, RarityCap, DestroysMaterialOnFail, QualityMultiplier, FamilyMultipliers}, RarityDef.QMin, FamilyDef.BaseParams. S2 defines GeometryRules (with slots {id, required, min, max, rank}, strikingSlot, gripSlot, refs as an array), StepRule.weights as an array (its determinism rule forbids iterating dictionaries), MaterialPhys.forgeDifficulty, and DifficultyDefs with tiers {tier, minD} and maxPlayableTier. S3 keeps material and tier columns inside Definitions/MinigameFamilies param records, which S1's V6 check ('a FamilyModifiers entry for every enabled family') would reject. S4 uses qualityTier, difficultyTerm, qualityMultiplier, rarityCap, failScoreFactor (absent in S1), failOutcome (S1 has the boolean DestroysMaterialOnFail) and minQuality (S1: QMin). S7 reads EquipmentTypes.Sword.maxParts. The MVP tier clamp is encoded twice: S1's Enabled flags and S2's MAX_PLAYABLE_TIER.

**Evidence.** S1 §2.4 record types and §2.3 V6; S2 §4.8 'SlotRule', 'GeometryRules', 'StepRule', 'MaterialPhys = { id, density, forgeDifficulty }', 'maxPlayableTier'; S3 §6.5.2 MinigameParamDef/MinigameFamilyDef and 'Assumes (S1) that it accepts this layout'; S4 §8.6.3 'Iron.qualityTier', 'failScoreFactor = 0.75, failOutcome = "LowerQuality"', 'minQuality'; S7 §13.8.6 'MAX_RENDER_PARTS = EquipmentTypes.Sword.maxParts'.

**Proposed fix.** S1 publishes the merged record types in BRIEF PascalCase: MaterialDef.DifficultyTerm (S2's m) and MaterialDef.QualityTier (T); TierDef.QualityMultiplier (d), FailScoreFactor, and FailOutcome as an enum replacing DestroysMaterialOnFail; RarityDef.MinQuality; SlotDef {Id, Name, Required, Min, Max, Rank, Striking}. StepDef.FactorWeights and EquipmentTypeDef.ReferenceRanges become arrays in FactorId order. S3's per-family layout stays in Definitions/MinigameFamilies (S3 wins); S1 deletes FamilyModifiers, FamilyMultipliers and BaseParams and V6's clause, and adds S3's MinigameFamilyDef as FamilyDef's tuning payload. The MVP clamp comes from Tiers.Enabled only, with S2's maxPlayableTier derived from it. S2's GeometryRules and DifficultyDefs become views built by one adapter (Physics/Defs.fromDefinitions()), not a second schema. S7 reads PartLimits.Max.


### R1-19 [major/numbers] Hardness and toughness scale and values differ (S1 0–100 vs S4 0–1)

Sections: S1, S4, S6, S8 | needsUserDecision: True | confidence: high

**Problem.** S1 stores hardness and toughness as integers 0–100 (V4 checks 'integers 0..100'): Iron 45/50, Steel 70/55. S4's formulas take 0..1 inputs (Sharp = 100·H·P·…, Dura = 100·K·P·…) and assume Iron 0.50/0.50, Steel 0.70/0.50. S4's worked examples (Arming Iron Sharpness 39.5, Durability 41.6), S6's example card and S8's golden outcomes rest on S4's values. With S1's values, Iron Sharpness drops by 10 % and Steel Durability rises by 10 %. S4 §17.6 asks the designer whether Steel should outlast Iron, while S1 §17.9 asks the designer to approve a table where it already does.

**Evidence.** S1 §2.5 rows: 'Iron | ... | 45 (Medium) | 50 (Medium)', 'Steel | ... | 70 (High) | 55 (Medium)'; S1 §2.3 V4; S4 §8.1: 'hardness, toughness | 0..1 | Assumes (S1) Iron 0.50 / 0.50, Steel 0.70 / 0.50'; S4 §8.2.4: 'Durability is equal because the draft gives both metals Medium toughness'; S4 §17.6; S1 §17.9.

**Proposed fix.** S1 owns both the values and the scale. Keep S1's integer 0–100 storage (it carries the word bands) and have S4's formulas read Hardness/100 and Toughness/100 (or switch S1 to 0–1; either works, but only one). The value set is the designer's choice: S1's Iron 45/50 and Steel 70/55 (Steel +10 % Durability) or S4's 50/50 and 70/50 (equal Durability). Merge S1 §17.9 and S4 §17.6 into one question. S4 then re-runs examples.luau and sim.luau, and S6's and S8's examples follow.


### R1-20 [major/conflict] Item record and crafting history exist in four shapes, and no section builds the item

Sections: S1, S3, S4, S5, S6, S7, S8 | needsUserDecision: False | confidence: high

**Problem.** S1's ItemRecord has a top-level Steps array of StepRecord {Step, Family, Tier, D (1e-4), Seed, Score, Passed, DurationMs, Flags}, an AtForge record and derived fields (Physics {Mass, BalancePoint, Reach}, Stats keyed by StatId, Quality, Rarity, RarityCap). S4 embeds a CraftRecord {balanceVersion, steps: CraftStepRecord {step, tier, difficulty (1e-3), material, seed, score, passed, timedOut, durationMs}, outcome: StoredOutcome {stats with lowercase keys, quality, materialTier, rarity, rarityByScore, rarityCap, capStep}} as `craft`. S3 expects per-step {family, tier, material, seed, score, passed, flags, breakdown, balanceVersion}. S5's StepResult is {index, stepId, tier, seed, score, pass, timedOut, lateSoft, flags}, and S5 calls Crafting.Item.create, which no section defines (S1 has only Recompute.applyOutcome; S4 has Outcome.record). S7's InspectView.fromItem reads Physics.BalanceOffset and Steps[].{Step, Tier, Score, Passed}. S6's results card reads CraftRecord.steps. S8's S-E2E-07 checks 'family/tier/seed/score/pass'.

**Evidence.** S1 §9.4 Items/Schema; S4 §7.6 'Assumes (S1): S1's Item record embeds this record as craft'; S3 §6.13 'Assumes (S1) that the per-step record stores {family, tier, material, seed, score, passed, flags, breakdown, balanceVersion}'; S5 §7.P8 StepResult and §7.P5 step 2 'Crafting.Item.create({ id = s.id, ... })'; S7 §13.11.3 'Assumes (S1): ... Physics.{Mass, BalanceOffset, Reach} ... Steps[].{Step, Tier, Score, Passed}'; S6 §12.2.1 'History from the item's CraftRecord.steps'.

**Proposed fix.** S1 owns the single record. StepRecord = {Step, Family, Tier, D (1e-4), Material, Seed, Score, Passed, TimedOut, DurationMs, Flags (see R1-42)}. Outcome fields stay at the item's top level as in S1, plus MaterialTier, RarityByScore and CapStep from S4. Delete S4's CraftRecord, StoredOutcome and CraftStepRecord. S1 adds the missing constructor Items/Build.create(sessionFacts, outcome, geometryFacts), which maps S4's Outcome.compute result; S5 calls it in §7.P5. Breakdown is not persisted (S6 shows it from the live result), and the per-step balanceVersion is dropped in favour of the item-level BalanceVersion. Use Passed, never pass. Stats are keyed by PascalCase StatId (S4's lowercase ItemStats keys are renamed). S5, S6, S7 and S8 read these names.


### R1-21 [major/gap] Recompute inputs: S1's GeometrySummary, S2's AnalysisSummary and S4's PhysicsInputs do not match

Sections: S1, S2, S4, S5 | needsUserDecision: False | confidence: high

**Problem.** S1's cheap recompute assumes a stored GeometrySummary {ByMaterial {Volume, Moment}, Measures} plus S2 functions Physics.analyzeGeometry and Physics.summarize. S2 provides neither (it offers AnalysisSummary {mass, volume, balance, reach, bladeLength, cutIndex, inertiaGrip, edgeLength, steps}) and never mentions GEOMETRY_VERSION. S4's recompute (Plan.fromHistory then Outcome.compute) needs PhysicsInputs {mass, reach, balanceOffset, edgeLength, kept[], partVolumes[]}. Blade hardness H is a volume-weighted mean over the kept Blade parts, which S1's per-material totals cannot give. S4 says 'physics is recomputed from the snapshot', which means S2's full pipeline (1.4–7.3 ms per sword in Lune), while S1 budgets '< 5 ms for 150 items' for the cheap path. S5 schedules neither path.

**Evidence.** S1 §9.4: GeometrySummary and 'Assumes (S2): ... Physics.analyzeGeometry(core) -> GeometrySummary (expensive) and Physics.summarize(geometry)'; S1 §9.6: 'staleCheap items synchronously after Prepare (formula evaluation, < 5 ms for 150 items)'; S2 §4.8 AnalysisSummary (grep: no GEOMETRY_VERSION in S2); S4 §8.1: 'H | volume-weighted hardness over the Sharpening work set'; S4 §7.6: 'physics is recomputed from the snapshot'; S4 §8.6.1 PhysicsInputs.

**Proposed fix.** S1, S2 and S4 agree on one stored record, GeometryFacts (S1 owns, S2 fills, S4 consumes): ByMaterial {Volume, Moment}; Parts {{Kept, OwnedVolume}} per part in ascending Id order; and Measures with fixed keys {GripPoint, GripAxis, GuardPos, Reach, EdgeLength, BladeLength, CutIndex}. S2 exports Physics.facts(analysis) -> GeometryFacts and Physics.summarize(facts, densities) -> PhysicsInputs, which needs no sampling. S4's recompute consumes that output. S2 owns GEOMETRY_VERSION bumps, and a bump makes the item staleGeometry (full re-analysis). S5 runs staleCheap at load and staleGeometry in its background queue (R1-22). Re-measure S1 §9.7, which grows by about 0.6 KB per item.


### R1-22 [major/conflict] Persistence load pipeline: S1's Prepare.run vs S5's migrate + Reconcile

Sections: S1, S5, S8 | needsUserDecision: False | confidence: high

**Problem.** S1's Prepare.run checks the version, runs migrations and its own reconcile, repairs and quarantines records, detects stale items and runs JsonSafe, with 'S5 calls it right after StartSessionAsync and never calls profile:Reconcile()'. S5 instead calls Persistence.migrate(profile.Data) and then profile:Reconcile(). It assumes S1 exports Template, SCHEMA_VERSION, migrate(data) -> (ok, why) and checkStorable(data), and treats a missing schemaVersion as 0, while S1 uses 'DataVersion or 1'. S5 never calls repair or stale detection, never schedules recomputes, and has no handling for S1's 'Corrupt' status. As specified, S1's quarantine and rebalance recompute would never run. Names also diverge: SCHEMA_VERSION, schemaVersion and Balance.VERSION (S5) vs DATA_VERSION and Versions.BALANCE_VERSION (S1); checkStorable (S5) vs JsonSafe.check (S1) vs tests/lib/ProfileSafe (S8).

**Evidence.** S1 §9.6: 'Load pipeline (src/shared/Persistence/Prepare.luau, pure; S5 calls it ... and never calls profile:Reconcile() itself)' and 'status "Corrupt" (S5: telemetry, read-only session)'; S5 §9.L2: 'local ok, why = Persistence.migrate(profile.Data)' then 'profile:Reconcile()'; S5 App. A: 'exports Template, SCHEMA_VERSION, migrate(data) ... missing schemaVersion = 0 ... checkStorable(data)'; S5 §7.P5: 'balanceVersion = Balance.VERSION'; grep of S5: no stale, recompute or Corrupt handling.

**Proposed fix.** S5's load sequence becomes: AddUserId → Prepare.run(profile.Data, {displaySlots = S7 slot keys}) → on 'Newer', EndSession and kick with NEWER_SCHEMA; on 'Corrupt', kick with LOAD_FAILED, log telemetry and never write (S1 and S5 agree on this rule); on 'Ok', run staleCheap synchronously, queue staleGeometry in the background and measure the size (R1-31). No profile:Reconcile() call. Use S1's names everywhere: DATA_VERSION/DataVersion (default 1), Template.TEMPLATE, JsonSafe.check (also used for S5's Studio OnSave check and S8's ProfileSafe tests), Versions.BALANCE_VERSION. S8's T-PER-03/04 test this order.


### R1-23 [major/conflict] Profile.Data and summary shapes: S5 assumes lowercase, dense arrays and flat settings

Sections: S1, S5, S6, S7 | needsUserDecision: False | confidence: high

**Problem.** S5 assumes d.items and d.blueprints in lowercase, .smithy.displays as a dense string array, a flat .settings, and createdAt/updatedAt fields. It caches the full S2 Analysis on the blueprint record. S1 defines PascalCase Blueprints/Items, Smithy.Displays as a map {'D1'..'D6' → ItemId} with absent keys for empty slots, EditorPrefs/UiFlags, Created/Updated/Revision, and a compact BlueprintAnalysis cache. The view types also diverge. BlueprintSummary: S1 {Id, Name, Type, Revision, Updated, PartCount, Analysis?} vs S5 {id, name, updatedAt, partCount, valid, tiers}. ItemSummary: S1 {…, Tiers, DisplaySlot: 'D3'} vs S5 {…, displayedIn: number}. Join payload: S1 {Blueprints, Items, Smithy, EditorPrefs, UiFlags}, about 61 KB at 40+150, to be paged in ≤ 32 KB messages, vs S5's ProfileSnapshot estimated at 38 KB for '30 bp + 200 items' and sent as one message. S6 reads S1's BlueprintSummary out of S5's ProfileSnapshot. Display slots appear as S1's map keys, S5's dense array plus displayedIn number, and S7's numeric SlotIndex.

**Evidence.** S5 App. A: 'Profile.Data.blueprints and .items are dictionaries ...; .smithy.displays is a dense string array'; S5 §7.P5: 'd.items[item.id]'; S5 §1.7 save step 7: 'createdAt kept, updatedAt = os.time(), analysis cached'; S5 §10.4 BlueprintSummary/ItemSummary/ProfileSnapshot; S1 §9.3 PlayerData and §3.7 join payload; S6 §11.20: 'Data: S1's BlueprintSummary { Id, Name, Type, Revision, Updated, PartCount, Analysis } from S5's ProfileSnapshot'; S7 §13.10.2 fromStore/toStore.

**Proposed fix.** S1 owns the stored shapes and the summary types, in PascalCase. S5 owns ProfileSnapshot as a wire envelope that embeds S1's BlueprintSummary, ItemSummary, EditorPrefs and UiFlags unchanged, plus its own fields (userId, plotIndex, limits, session). Displays are stored as S1's map and travel on the wire as a dense array of length DISPLAY_SLOTS ('' = empty), converted only through S7's ShowcaseRules.fromStore/toStore. ItemSummary.DisplaySlot becomes a number (0 = none). S5 caches S1's BlueprintAnalysis, built by an S1/S2 adapter, never the raw S2 Analysis. The snapshot is paged at ≤ 32 KB (S1 §3.7), and S5's estimate is redone at 40/150.


### R1-24 [major/conflict] ShowcaseService and InspectView are each owned and typed twice

Sections: S1, S5, S7 | needsUserDecision: False | confidence: high

**Problem.** S5 specifies ShowcaseService (renderAll, unrenderAll, place, clear, scrap, inspect, getItem, returning Response<{displays}> and S5 ErrorCodes) and an InspectView in Net/Protocol (ownerUserId, ownerName, name, physics {mass, balance, reach}, a stats map, history {stepId, tier, score, pass}). S7 specifies the same file, src/server/ShowcaseService.luau, with a different API (onPlotClaimed, place, clear, inspect, onItemRemoved, returning ShowcaseCode: Ok, NoChange, BadSlot, SlotLocked, BadItem, NotOwned, NoPlot, TooFar, Busy, NotLoaded, RateLimited). S7 also defines Showcase/InspectView.luau with v, displayName, equipmentType, rarityCap, capStep, crafter {userId, displayName, name}, per-slot materials, physics.balanceOffset, a stats array, history {step, tier, score, passed}, hardestTier and balanceVersion. S1 defines a third visitor view, ItemPublicView (the full ItemRecord with filtered names, about 10.5 KB). S7's place flow waits up to 5 s for name filtering before replying; S5 filters asynchronously and shows a fallback label first.

**Evidence.** S5 §1.3: 'ShowcaseService.luau, PlotService.luau (S5)'; S5 §1.7 ShowcaseService API; S5 §10.4 InspectView; S7 §13.1 module table: 'src/server/ShowcaseService.luau | server | Roblox-bound'; S7 §13.10.4 API and ShowcaseCode; S7 §13.10.3: 'name ← filtered or default (§13.3.4, may yield ≤ 5 s)'; S7 §13.11.3 InspectView; S1 §3.7: 'ItemPublicView (= ItemRecord, filtered names)'.

**Proposed fix.** S5 owns ShowcaseService (handlers, ErrorCodes, filtering, rate limits) and calls S7's pure ShowcaseRules and PlotWorld. S7 owns the InspectView type and InspectView.fromItem (the panel content); S5's Net/Protocol re-exports it and its own §10.4 copy is deleted. S1's ItemPublicView is deleted. Map ShowcaseCode to ErrorCode: BadSlot/SlotLocked → E_SLOT_INVALID, BadItem/NotOwned → E_NOT_FOUND, Busy → E_SESSION_ACTIVE, TooFar → a new E_TOO_FAR, NotLoaded → E_NOT_READY, RateLimited → E_RATE_LIMITED, NoChange → ok. Filtering stays asynchronous (S5 §10.8): handlers reply immediately and the label uses InspectView.defaultName until the cache fills; S7's in-handler 5-s wait is removed.


### R1-25 [major/gap] Plot rules and world hooks that S7 assigns to S5 are missing from S5

Sections: S5, S6, S7 | needsUserDecision: False | confidence: high

**Problem.** S7 relies on S5 for several server rules and hooks, and none of them appears in S5 (grep finds no isInsidePlot, setActivity, TeleportHome or character-death handling). (1) Craft.Begin and Showcase.Place/Clear check Layout.isInsidePlot(ownPlot, server-side HumanoidRootPart, 6) and reply TooFar. (2) Display changes are refused during a craft session (Busy). (3) CraftService calls PlotWorld.setActivity(plot, station, workpiece) at each step start and setActivity(plot, nil) at end or abort; visitors' workpiece and station effects depend on it. (4) The session aborts when the character dies or is removed. (5) A World.TeleportHome request exists (one per 3 s, rejecting NoPlot, Busy and RateLimited), but S5 has only the four channels Profile, Blueprint, Craft and Showcase. (6) S5 serializes requests per player.

**Evidence.** S7 §13.2.2: 'Assumes (S5): server checks that need "the player is at their smithy" (start craft, display changes) use isInsidePlot'; S7 §13.6.4: 'Assumes (S5): CraftService calls PlotWorld.setActivity'; S7 §13.6.3: 'S5 aborts the session on its side'; S7 §13.3.2: 'Assumes (S5) remote World.TeleportHome'; S7 §13.14: 'S5 serializes requests per player'; S5 §10.3 catalogue and the S5 AbortReason union (no character reason).

**Proposed fix.** S5 adds these rules. Begin, Place and Clear check Layout.isInsidePlot with S7's PLOT_INTERACT_MARGIN, and Place/Clear are refused while a session is live. CraftService calls PlotWorld.setActivity with the station from S7's STEP_STATION map and the workpiece built from the session snapshot. A new AbortReason 'CharacterLost' fires on Humanoid.Died or CharacterRemoving. A new action Profile.TeleportHome {} (bucket 1, refill 1/3 s) calls PlotWorld.teleportHome. On serialization, S5 documents that the Place/Clear handlers never yield (filtering is asynchronous), so no per-player queue is needed, and S7 deletes that assumption. S6 adds the HUD button and the error copy for E_TOO_FAR.


### R1-26 [major/conflict] Four telemetry catalogues with different names, signatures and sinks

Sections: S1, S2, S3, S4, S5, S8 | needsUserDecision: False | confidence: high

**Problem.** S5 defines 11 AnalyticsService events (DataLoaded, DataIssue, BlueprintSaved, CraftStarted, StepScored, CraftCompleted, CraftAborted, ItemDisplayed, AntiCheatFlag, RateLimited, FilterFailed), each with a value and 3 string fields, through Telemetry.log(player, event, value, f1, f2, f3). S8 defines 10 events (BlueprintSaved, BlueprintRejected, CraftStarted, StepCompleted, StepRejected, CraftAbandoned, ItemCreated, ItemDisplayed, ScoreMismatch, Perf) with JSON payloads and common fields v/bv/t/job/tid, through Telemetry.log(event, payload), a ring buffer, [TLM] lines and a DataStore sink. Its tid is a pseudonymous GUID 'stored in Profile.Data', which S1's template does not have. S3 defines 4 snake_case events (minigame_result, minigame_invalid, minigame_score_mismatch, minigame_desync). S4 §8.7 and S2 §5.8 ask for additional fields. Tier signatures are written 'NHH' by S5 and 'N-N-H' by S8.

**Evidence.** S5 §10.12 event table and TelemetryEvent union; S5 §1.7: 'Telemetry.log: (player, event, value, f1?, f2?, f3?)'; S8 §14.13: 'Assumes (S5): a server Telemetry.log(event, payload) with a ring buffer, [TLM] <json> output lines' and 'tid (pseudonymous telemetry id: a GUID stored in Profile.Data)'; S3 §10.M7; S4 §8.7; S2 §5.8: 'Assumes (S8/S5): craft telemetry logs terms, G, m, D, tierRaw'.

**Proposed fix.** S5 owns the Telemetry module and the event names (PascalCase); S8 owns the analysis payload fields. Merged catalogue: DataLoaded, DataIssue, BlueprintSaved, BlueprintRejected, CraftStarted, StepScored (= S8's StepCompleted = S3's minigame_result), StepRejected (= minigame_invalid), CraftAborted (= S8's CraftAbandoned plus S4's discard reasons, using S5's AbortReason), CraftCompleted (= ItemCreated), ItemDisplayed, AntiCheatFlag, ScoreMismatch, Desync, RateLimited, FilterFailed, Perf. Telemetry.log(player, event, payload) feeds two sinks: AnalyticsService with S5's value and field encodings, and S8's ring buffer and [TLM] lines. Tier signatures use one format. S1 adds TelemetryId (a GUID) to the template, or S8 drops tid.


### R1-27 [major/testing] S8's console-hygiene check matches a log prefix S5 never prints

Sections: S5, S8 | needsUserDecision: False | confidence: high

**Problem.** S5 logs in logfmt as '[blacksmith:<tag>] <event> k=v', with the level only implied by print/warn/error, so no level marker appears in the line. S8 fails a Studio session only on '[Blacksmith][E]' lines and lists '[W]' lines. Against S5's format, S8's check matches nothing, so server errors pass the gate silently. That gate is part of S8's Definition of Done ('3 consecutive fresh sessions with a clean console').

**Evidence.** S5 §1.9: '[blacksmith:<tag>] <event> key=value key=value …' and 'Levels: debug (Studio only), info, warn, ... error'; S8 §14.10.7: 'Assumes (S5): game logs are prefixed [Blacksmith], with [E] for errors and [W] for warnings. Fail on any [Blacksmith][E] line'; S8 §14.12.2 item 2.

**Proposed fix.** S5 owns the format and adds the level to the line: '[blacksmith:<tag>][<D|I|W|E>] <event> k=v …' (the tag is lowercase and fixed). S8's hygiene scan matches '%[blacksmith:%a+%]%[E%]' for failures and '[W]' for the report. S8's E2E lines ('[E2E] …') and [TLM] lines keep their own prefixes.


### R1-28 [major/numbers] Reference swords, fixtures and calibration numbers disagree; S4 tuned on stale S2 output

Sections: S1, S2, S4, S8 | needsUserDecision: True | confidence: high

**Problem.** Four different 'reference sword' definitions are in use. S1's example sword weighs '1.32 kg', but laid end to end it is 5.05 studs long, more than S2's 5.0-stud hitbox, and S1 tells the designer 'a typical sword ≈ 1.3 kg'. S2's reference arming sword (Iron) weighs 0.835 and plays N/N/N (0.036/0.182/0.179) with edge 5.604. S4 says the arming sword plays N/H/H ('the Mixed-2 rows are the common case'); its examples.luau hard-codes edge 5.651 and tiers {Normal, Hard, Hard}, the cleaver as Hard/Hard/Hard with edge 6.198 (S2: Hard/Normal/Hard, 5.968) and the minimal sword as Hard/Normal/Normal (S2: N/N/N). MassRef and EdgeRef are derived from these numbers. S8's golden F1–F4 are different designs in a different frame: F1 is the Combat System sword with a Steel blade, ≈ 0.79 mu with S1 densities. S8's intended tiers (F1 N/N/H, F4 H/H/N) contradict S2/S4's rules: a Steel blade sets m = 0.10 for Hammering too (W = All), so F1 is Normal there only if G_Hammering < 0.111.

**Evidence.** S1 §2.5: 'Mass = 1.32 mu, shown "1.32 kg"' and S1 §17.5; S2 §5.7 Arming (Iron) row, D 0.036/0.182/0.179 (proto/S2/out_final.txt: 'Hammering G=0.182 m=0.00 D=0.182 Normal'); S4 §8.2.4: 'S2's reference arming sword plays Normal/Hard/Hard'; proto/S4/examples.luau line 37: 'edge = 5.651 ... tiers = { "Normal", "Hard", "Hard" }'; S8 §14.7.2 F1 and §14.7.4 table; python check: F1 mass 0.7952 (sum of parts) / 0.7925 (union), Normal Hammering needs G < 0.1111.

**Proposed fix.** S8's F1–F4 become the single fixture set (S2's 15 swords stay as S2-internal calibration evidence, or S8 adopts S2's arming sword as F1). S2 runs its pipeline on F1–F4 and publishes the physics, factor and tier tables. S4 re-derives MassRef and EdgeRef from F1 and re-runs examples.luau and sim.luau from S2's live output instead of hard-coded copies. S1 replaces its example and its §17.5 figure with the fixture mass (≈ 0.8 kg). The designer settles one intended-tier table (S8 §14.7.4 and S2 §17.7) against S2's actual numbers.


### R1-29 [major/numbers] Three player models and three sets of targets: the acceptance bands cannot all pass

Sections: S3, S4, S8 | needsUserDecision: True | confidence: high

**Problem.** S3's bots are elite, good and poor (σ 12/25/45 ms), with the target 'typical 0.80/0.70, weak 0.60/0.50'. S4 tunes rarity on Bad/Average/Good/Excellent profiles (means 0.40/0.60/0.76/0.88; Average fails 18 % of Normal and 60 % of Hard steps), and itself maps S3's poor to its Average and S3's good to its Excellent. S8 defines Elite/Good/Average/Poor (σ 12/25/45/90 ms) with bands such as Average passing 85–97 % at Normal and 60–85 % at Hard, and live targets of 3–15 % / 15–40 % fails. S3's poor bot, which matches S8's Average by σ, passes Hard TimingStrike 51 % and PrecisionTrace 42.7 % of the time, below S8's band. The rarity targets disagree too: S4's T7 says 'Good, All-Hard: 5–45 % Epic', S4 §8.5.4 says 'Epic in 5–25 %', and S8 applies 5–25 % to F1, which has one Hard step. S4 §8.5.5 gives S3's good bot (= S8's Good) 67–76 % Epic with two or three Hard steps.

**Evidence.** S3 §6.12.1 design target and §6.12.2 tables; S4 §8.5.1 score model and fail rates; S4 §8.5.2 T7; S4 §8.5.4 conclusion; S4 §8.5.5: 'S3's "poor" bot plays like the S4 "average" profile ... S3's "good" bot like the S4 "excellent" profile'; S8 §14.8.1 profiles and §14.8.3 bands and rarity targets; S8 §14.13 'fail rate per tier | Normal 3–15 %, Hard 15–40 %'.

**Proposed fix.** S8's Bots.luau profiles (names and parameters) are the single player model. S3 measures each family under those profiles and publishes the score and pass bands, replacing S8's table as S8 itself allows. S4 re-runs its rarity simulation on those measured distributions and restates T1–T10 per S8 profile. The designer gets one consolidated question for fail rates (merging S3 §17.3, S4's §8.5.1 note and S8 §17.1) and one for rarity targets (merging S4 §17.8 and S8 §17.3).


### R1-30 [major/conflict] S5's AnalysisQueue assumes a 15-ms worst case; S2's ceiling is 75 ms and must not run in one frame

Sections: S2, S5 | needsUserDecision: False | confidence: high

**Problem.** S5 runs at most one full S2 analysis per Heartbeat, synchronously, assuming 'Analyze.run worst case ≤ 15 ms on a server (fits one 60 Hz frame)'. S2 gives ≤ 15 ms as the typical figure and ≤ 75 ms as the hard ceiling (adversarial 36 ms in Lune, about 2× on Roblox), and requires the analysis to run outside the hot frame, either through a yielding opts.checkpoint that S5 passes or through an Actor. As written, any client can trigger a frame of roughly 72 ms every 3 s (Save bucket 4, refill 1/3 s), on every player's server.

**Evidence.** S5 §1.7: 'AnalysisQueue ... at most ANALYSES_PER_HEARTBEAT (1) job per Heartbeat' and 'Assumes (S2): Analyze.run worst case ≤ 15 ms on a server for a max-size blueprint (fits one 60 Hz frame)'; S2 §4.7: 'Server, hard ceiling | ≤ 75 ms' and 'opts.checkpoint callback ... (S5 passes a yielding callback) or a Parallel Luau Actor | a 36-75 ms worst case must not freeze 6-8 players'; S5 §10.13 CPU row.

**Proposed fix.** AnalysisQueue runs each job in its own thread and passes S2's opts.checkpoint as a function that yields to the next Heartbeat once the job has used ANALYSIS_SLICE_MS (e.g. 4 ms, measured with os.clock) in the current frame; an Actor is the alternative S2 allows. ANALYSES_PER_HEARTBEAT is replaced by the slice, and the queue cap and E_BUSY are unchanged. S5 §10.13 uses S2's ceiling: 75 ms total, at most 4 ms per frame.


### R1-31 [major/platform] Save cadence and profile-size thresholds ignore the 4 MB/min per-key write limit at S1's sizes

Sections: S1, S5 | needsUserDecision: False | confidence: high

**Problem.** S5 coalesces explicit saves to one per 10 s (up to 6 per minute) on top of autosave. It assumes a profile budget of at most 1 MB and a 100 KB example, and warns at 1 MB. S1's caps allow far larger profiles: 1.96 MB worst case as published, 1.14 MB quantized or 1.66 MB with raw doubles at 24 parts (R1-04). S1 targets ≤ 2 MiB, warns at 2 MiB and blocks at 3 MiB. Roblox limits writes to 4 MB per minute per key. At 1.66 MB, 6 saves per minute is 9.96 MB/min, 2.5× the limit, so saves would be throttled or fail on exactly the largest profiles.

**Evidence.** S5 §9.L4: 'at most one per SAVE_MIN_INTERVAL_S = 10 s' and 'Assumes (S1): profile size budget ≤ 1 MB'; S5 §9.L6: 'warns above PROFILE_WARN_BYTES (S1, e.g. 1 MB)'; S1 §9.7: 'Target: W ≤ 2 MiB ... a 2 MiB profile can still be written twice a minute' and PROFILE_SIZE_WARN_BYTES 2097152 / BLOCK 3145728; Roblox 'Data store error codes and limits' (fetched): per-key write 'Write: 4 MB per minute'; python check: 1.66 MB × 6 = 9.96 MB/min.

**Proposed fix.** S5 derives the explicit-save interval from the JSON size tracked by S1's runtime guard: interval_s = max(SAVE_MIN_INTERVAL_S, ceil(60 · bytes / 2,000,000)), which keeps explicit saves at ≤ 50 % of the per-key budget (10 s at 288 KB, 50 s at 1.66 MB). S5 adopts S1's PROFILE_SIZE_WARN_BYTES and PROFILE_SIZE_BLOCK_BYTES, deletes its own 1 MB value, and implements S1's block rule (E_LIMIT_REACHED for new blueprints and items).


### R1-32 [major/conflict] Error-code vocabularies overlap and disagree across sections

Sections: S1, S2, S3, S5, S6, S8 | needsUserDecision: False | confidence: high

**Problem.** The same condition gets different strings in different sections. S1's CanonError (Malformed, UnknownId, DisabledId, TooManyParts, OutOfRange, …) overlaps S2's SanitizeError and ValidationCode (NonFinite, UnknownShape/UnknownSlot/UnknownMaterial, TooManyParts, SlotMissing, SlotTooMany, OutOfHitbox, Disconnected, BladeNotAboveGrip). S6 keys its message texts on S2's prototype strings (OUT_OF_HITBOX, SLOT_MISSING, PART_COUNT, …) and 'NameRejected'/'LimitReached'. S8's expected codes are placeholders (PartOutsideHitbox, MissingSlot, BadNumber, BadSize, MaterialNotEnabled, SlotLimit, TooFast, AlreadySubmitted, Busy, RateLimited), where S5 actually uses E_TOO_EARLY, a duplicate reply, E_SESSION_ACTIVE and E_RATE_LIMITED. S2 reports errors by part index while S6 keys them by part Id, and S5's SaveData.errors is a {string} that drops S2's part/slot locus, which S6 needs for highlighting.

**Evidence.** S1 §3.8 CanonError; S2 §4.8 SanitizeError and ValidationCode; S6 §11.18.3 table ('Code (S2 proto)'); S8 §14.7.5 'Codes are descriptive placeholders' and §14.10.4 S-E2E-10/11 ('Cheat-Replay → AlreadySubmitted', 'second StartCraft ... → Busy'); S5 §1.7 'errors: { string }'; S5 §10.5.

**Proposed fix.** Use one registry per layer, each with a single owner. S1's CanonError covers wire structure, with S2's SanitizeError folded into it. S2's ValidationCode covers geometry, in PascalCase, and is emitted as {code, partId, slot}. S3's InvalidReason covers timelines, and S5's ErrorCode, AbortReason and flags cover transport. S5's SaveData.errors carries S2's records. S6's texts are keyed by those exact strings, and S8's fixtures and scenarios expect them.


### R1-33 [major/architecture] Module tree and type ownership: S5's layout is stale and ids are declared in several modules

Sections: S1, S2, S3, S4, S5, S6, S7, S8 | needsUserDecision: False | confidence: high

**Problem.** S5 §1.3, the Rojo/architecture section, lists files the owners do not define: Blueprint/{Types, Sanitize (fromWire), Serialize, Names}, Physics/{Voxelize, Clean, Mass, …}, Minigames/Registry, Crafting/Item, Persistence/{Template, Migrate, Types} and server World/{WorldBuilder, Plot, Stations, ItemModel, Display}. It omits the owners' real modules: S1's Blueprint/{Schema, Canonical, Quat, Views}, Items/* and Persistence/{Prepare, JsonSafe, Ids, Quantize}; S2's Blueprint/Geometry and Physics/{Shapes, Gjk, Sampling, MassProps, Edge}; S3's Minigames facade, Params, Timeline and Checks; S4's Crafting/{Types, Quality, Rarity, Stats} and Definitions/CraftPlans; S7's Definitions/{World, Presentation}, World/Layout, ItemRender/*, Showcase/* and server PlotWorld. Id unions are re-declared in S2's Geometry, S3's Minigames/Types (FamilyId with only 3 values) and S4's Crafting/Types. There are three storable-data checkers (S1 JsonSafe, S5 checkStorable, S8 ProfileSafe), several quantize helpers (S1 Quantize.q, S3 round4, S4 Quality.quantize) and two Signal modules (S5's shared Util/Signal, S6's client UI/Signal). S7's ItemModelBuilder is a Roblox-bound module in src/shared, which S5's rules and S8's purity lint do not list.

**Evidence.** S5 §1.3 tree; S1 §2.3 and §3.8; S2 §4.8; S3 §6.2; S4 §8.6.2; S7 §13.1 module table; S6 §11.2 'Signal.luau, Value.luau'; S5 §1.4 R2/R3 and S8 §14.4 purity lint ('src/shared outside Net/ contains no Roblox tokens').

**Proposed fix.** Regenerate S5 §1.3 from the owners' module lists as one table (path, owner, pure or Roblox-bound), with the Physics→WorkSet edge from R1-14. Id unions live only in Definitions/Types and other modules import them. Keep one JsonSafe (S1) and one Quantize (S1), used by S2, S3 and S4 with their documented grids. S6 uses S5's Signal. Mark ItemRender/ItemModelBuilder as Roblox-bound in S5's rules and exempt it in S8's purity lint.


### R1-34 [major/conflict] Consumers assume five different shapes and names for S2's analysis output

Sections: S1, S2, S4, S5, S6, S7 | needsUserDecision: False | confidence: high

**Problem.** S2's Analysis is {balanceVersion, validation {ok, errors {code, part, slot}, contacts, mainComponent}, parts {PartReport {…, ownedVolume, cleaned?}}, mass MassProps {mass, balance, gripPoint, …}, edge, steps (an array of {step, G, m, D, tierRaw, tier, terms}), budget}, produced by Analyze.run(parts, rules, defs, balanceVersion, opts). Each consumer assumes something else. S4: {mass, reach, balanceOffset, edgeLength, kept[], partVolumes[]} plus steps keyed by StepId as {difficulty, tier}. S6: {mass, reach, balanceOffset, grip, com, kept, per-step {difficulty, tier, material, terms, m}} plus a Validate.quick entry point. S5: Analyze.run(bp) -> {valid, errors, physics?, steps?: {[StepId]: {D, tier}}}. S1: PhysicsSummary {Mass, BalancePoint, Reach}. S7: Physics.{Mass, BalanceOffset, Reach}. The same quantity is called balance, balanceOffset or BalancePoint, which is ambiguous between distance from the hand and from the guard. S4 defines it along Y, S2 along the grip axis A.

**Evidence.** S2 §4.8 Analysis/MassProps/StepDifficulty and the Analyze.run signature; S4 §8.6.1 PhysicsInputs/DifficultyInputs; S6 §11.19.2: 'Assumes (S2): report fields mass, reach, balanceOffset, grip (point), com (point), kept, per-step { difficulty, tier, material }'; S5 App. A (S2 row); S1 §3.2 PhysicsSummary; S7 §13.11.3 'Physics.{Mass, BalanceOffset, Reach}'; S4 §8.1: 'b | balance offset: centre-of-mass Y − guard line Y'.

**Proposed fix.** S2's Analysis is the single output type, and consumers adapt to its names. S2 adds per step material (the mat_s id) and the factor vector x (R1-12), and a cheap validate entry for V2–V4. One canonical name is used everywhere for the signed distance from the guard line toward the tip, measured along the grip axis A as S2 defines it: BalanceOffset (S2's balance, S1's BalancePoint and S7's field are renamed). S1's BlueprintAnalysis and S7's InspectView are built from S2's Analysis by explicit adapters.


### R1-35 [major/ux] The editor mirror plane (x = 0) is not the plane Asymmetry is measured about

Sections: S2, S6, S8 | needsUserDecision: False | confidence: medium

**Problem.** S6's mirror tool reflects across x = 0 and z = 0 (the hitbox centreline) with its own Mirror module. S2 measures Asymmetry about the sword's own plane, through the grip point and containing the grip axis, recommends that plane as the mirror default (x = 0 only before a grip exists), and provides Geometry.mirrorPart for any plane. With a grip off x = 0 (for example placed at x = 0.05 with snapping), a design mirrored about x = 0 still measures as asymmetric. Asymmetry weighs 0.30 in both Hammering and Sharpening, so a few hundredths of a stud of grip offset can flip a step to Hard, and a player who 'mirrored it' is told it is asymmetric. The two modules also emit different (equivalent) quaternions for Block/Ball/Cylinder under the z-mirror (S2 composes with q_Y(180°), S6 does not).

**Evidence.** S6 §11.14: 'Mirror across the sword's symmetry planes through the hitbox centreline: x = 0 ... and z = 0'; S2 §3.7: 'Recommendation to S6: the tool's default plane is the sword's symmetry plane (§4.5.3: through the grip point, containing the grip axis and Z); x = 0 before any grip exists'; S2 §5.2 Asymmetry plane 'through the grip point g containing the grip axis A'; S2 §5.4 weights (Asymmetry 0.30 in both steps); S2 §3.7 vs S6 §11.14 z-plane closed forms.

**Proposed fix.** S6's left/right mirror uses S2's symmetry plane (through g with normal N, falling back to x = 0 before any grip exists) via S2's Geometry.mirrorPart, the single implementation that S6's Mirror module wraps. The z-mirror plane is z = g_z, or z = 0 while S2 does not measure thickness-direction asymmetry. The UI shows the plane in use. S8's T-BP-11 and T-DIF-07 test that one module.


### R1-36 [major/gap] The BALANCE_VERSION guard misses S4's and S3's data and exists twice

Sections: S1, S2, S3, S4, S8 | needsUserDecision: False | confidence: high

**Problem.** S1's hash manifest covers Materials, EquipmentTypes, Steps, MinigameFamilies (only Enabled and BaseParams), Tiers, Rarities, Stats and Balance.{Difficulty, Minigames, Outcome}. It does not cover S4's new Definitions/CraftPlans (weights and work sets), S4's Balance.Stats and Balance.Quality (which S4 does not nest under Outcome), or S3's MinigameFamilies params (the material, tier and design columns) and checks. A change to any of these would not trip the guard, and items would keep stale stats. S2 puts UI cadence constants under Balance, so editing them would force spurious bumps. S8 implements a second guard (balance_fingerprint.golden.txt, 'every tunable') next to S1's tests/fixtures/balance_hash.luau.

**Evidence.** S1 §2.12 hashed-fields table ('MinigameFamilies | Enabled, BaseParams'; 'Balance | Difficulty, Minigames, Outcome'); S4 §8.6.3: 'Definitions/CraftPlans.luau (new file, S4)', 'Balance.Stats = {...}', 'Balance.Quality = {...}'; S3 §6.5.2 MinigameFamilyDef; S2 §16: 'live in Definitions/Balance, covered by BALANCE_VERSION' including PREVIEW_DEBOUNCE_MS; S8 §14.9.

**Proposed fix.** S1 publishes one manifest of hashed modules and fields: Materials, EquipmentTypes, Steps, Tiers, Rarities, Stats, CraftPlans (all), MinigameFamilies (all params and checks) and Balance.{Difficulty, Minigames, Stats, Quality}, minus S1's display-only fields. S8's single guard file hashes exactly that manifest. Outcome-changing code edits in Minigames/ and Crafting/ are caught by S8's pattern and outcome goldens, which require a bump to re-bless. S2's UI cadence moves to S6's client constants, and S5's Network and S7's World/Presentation are explicitly excluded.


### R2-02 [major/conflict] Transform sanity bounds differ across S1/S2/S6, and the server clamps instead of rejecting

Sections: S1, S2, S5, S6, S7, S8 | needsUserDecision: False | confidence: high

**Problem.** There are three sets of bounds, and the server path silently changes designs.
- S1 accepts |Pos| ≤ 64 and 0 < Size ≤ 64 (≥ 1e-4).
- S2 rejects |Pos| > 100 but clamps sizes to [0.05, 6.0] inside sanitizePart.
- S6 clamps drags to [MIN_DIM, MAX_DIM] and positions to an assumed '2× the hitbox', and gives no bounds for typed or relative values. The Ctrl-symmetric scale has no MIN_DIM clamp at all.
Consequences:
- A size the editor lets through by typing (for example 0.01) is stored by S1, analysed as 0.05 by S2 and rendered at 0.01 by S7, so physics, preview and display stand disagree.
- An editor bound looser than S1's turns an honest work-in-progress save into E_INVALID_BLUEPRINT plus a Hard strike (S5).
- S6 even plans a 'server adjusted N values' toast.
The user decision forbids server-side changes to the submitted design: only real rules may refuse it.

**Evidence.** S1 §3.5 rows 8–9: '|v| ≤ POS_ABS_MAX (64 stud)', 'Size: 3 finite numbers, 0 < v ≤ SIZE_MAX (64 stud) → quantize → ≥ 1e-4'. S2 §3.5: S2 '|position.k| <= POS_LIMIT (100) | reject', S5 'each size component clamped to [MIN_DIM, MAX_DIM] = [0.05, 6.0] | clamp (editor clamps identically)'. S6 §11.9.4: 'sizes clamp to [MIN_DIM, MAX_DIM], positions to S1's sanity box (Assumes (S1): e.g. 2× the hitbox)'; 'Ctrl = symmetric: s_a' = s_a + 2·snap(Δ)'. S6 §11.11.4 lists only Syntax/NotFinite/TooLong as invalid typed input. S5 §1.7: 'Sanitize.fromWire(draft) → failure = E_INVALID_BLUEPRINT + Hard strike (an unmodified client always sends sanitizable drafts)'. S6 §11.20: 'toasts "The server adjusted 2 values"'.

**Proposed fix.** S1 owns the constants (Limits); S2 owns the MIN_DIM and MAX_DIM values.
- One table is used by S1 Canonical.draft, S2 Geometry.sanitizePart and every S6 transform path: gizmo drags (including Ctrl-symmetric, uniform and group scale), typed and relative field values, scrub, nudge, Ctrl+I, mirror, shape change.
- Positions: |Pos_k| ≤ POS_ABS_MAX = 64. Delete S2's POS_LIMIT 100 and S6's '2× hitbox'.
- Sizes: MIN_DIM ≤ Size_k ≤ MAX_DIM. Delete S1's SIZE_MAX 64 and the 1e-4 floor.
- The editor enforces Ball uniform and Cylinder Y = Z at edit time.
- On the server these rules reject, never clamp. S2 rule S5 becomes 'reject SizeOutOfRange'. Ball/Cylinder canonicalization remains, but it is a no-op for editor data. The stored, analysed and rendered design is then exactly what the player built.
- The editor clamps visibly with the existing warn readout (for example 'max 64 from the origin').
- S5 keeps the Hard strike: the stock editor cannot produce such values.
- S6's 'server adjusted' path becomes a logged bug that should never fire.
- S8 adds a property test: every S6 Commands output passes Canonical.draft unchanged.


### R2-03 [major/fidelity] MIN_DIM 0.05 is a visible limit with a rationale that does not apply, and golden fixture F3 breaks it

Sections: S2, S6, S8, S1 | needsUserDecision: True | confidence: high

**Problem.** S2 sets the smallest part side to 0.05 stud in the editor and on the server; the editor readout says 'min 0.05'. That is stricter than BRIEF §1's 'minimum dimension so a part is a real Roblox Part' (Roblox allows 0.001). The stated reason is that Roblox simulates thinner parts as 0.05, so Phase 4 combat physics would not match. That reason does not apply: MVP items are anchored display models, and S7's Phase 4 hook holds items as massless, non-colliding welded parts. The limit also breaks S8's golden fixture F3, whose blade and wedge are 0.035 thick. S2's sanitizer would silently thicken them, which makes S8's §14.7.3 reference values wrong. Players who know Studio will read 0.05 as an arbitrary floor on thin blades and trim.

**Evidence.** S2 §3.5: 'MIN_DIM = 0.05: Roblox simulates anything thinner as 0.05 (verified above), so a thinner part would not match its own physics in Phase 4 combat; it also prevents invisible slivers'. S7 §13.8.7 Phase 4 hook: 'welded mode ... Massless, CanCollide = false'. S1 platform facts: 'Part size per axis 0.001–2048 studs'. S8 §14.7.2 F3 Rapier: Blade 'Block | Steel | (0, 1.78, 0) | I | 0.07 × 3.40 × 0.035', Wedge '0.035 × 0.30 × 0.07'. S6 §11.9.4: 'the readout says "min 0.05"'.

**Proposed fix.** S2 owns the value; the designer confirms it (§0 Q4).
- Replace the rationale with the real constraint, S2's measurement resolution: EDGE_CELL 0.02 raster, at least 2 samples per local axis, dust threshold 0.0002 stud³.
- Offer MIN_DIM = 0.02 (equal to EDGE_CELL; allows rapiers and fine trim) as the alternative to 0.05. Before choosing, check 0.02-thick parts with S2's prototype for Thinness saturation and raster aliasing.
- Whatever wins, S8 aligns F3 (keep 0.035 only if MIN_DIM ≤ 0.035) and re-derives §14.7.3.
- S1's wire check and S6's clamps and readout use the same constant (R2-02).


### R2-04 [major/conflict] Three incompatible readings of the draft's Low/Medium failure risk; rarity thresholds tuned on the wrong one

Sections: S3, S4, S8 | needsUserDecision: True | confidence: high

**Problem.** The draft's tier table gives failure risk 'Low' for Normal and 'Medium' for Hard. Three sections turn that into incompatible fail rates:
- S3: its typical bot almost never fails; its weak bot passes 43–89 % on Hard.
- S4: its average player fails 18 % of Normal and 60 % of Hard steps.
- S8: an average player should fail 3–15 % of Normal and 15–40 % of Hard steps.
S4 tuned the Uncommon/Rare/Epic thresholds on its own model. To make the targets hold under S3's real curves, it has to treat S3's 'good' bot as its 'excellent' player. Which player model is real decides whether Epic is rare or common.

**Evidence.** S3 §6.5.3: typical 'about 100 %' Normal / '≥ 99 %' Hard, weak '86–99 %' / '43–89 %', and 'This matches the draft's failure risk of Low on Normal and Medium on Hard'. S4 §8.5.1: 'Average 18 % / 60 %' and 'Note for S3: these fail rates are higher than the draft's Low / Medium suggest'. S4 §8.5.5 maps 'S3 good like the S4 excellent profile'; with S3's curves, good players get Epic in 67–76 % of Iron crafts with 2–3 Hard steps, against S4 target T7 'Good, All-Hard, Iron: 5 % ≤ Epic ≤ 45 %'. S8 §14.8.3: Average pass 85–97 % / 60–85 %. S8 §14.13: fail rate target 'Normal 3–15 %, Hard 15–40 %'. S8 toy check: 'the real Normal tier needs a more forgiving pass threshold than 0.5'.

**Proposed fix.** One player model and one target table, owned by S8 (§14.8.1 profiles, §14.8.3 bands): an average player fails about 1 step in 10 on Normal and 1 in 4 on Hard (bands 3–15 % / 15–40 %); a good player rarely fails.
- S3 retunes p_base and m_tier (and the pass line if needed) until S8's Average/Good/Poor bots meet the bands, and removes the 'matches Low/Medium' claim until then.
- S4 drops its private four-profile model and re-runs the §8.5 grid search on S3's measured curves for S8's profiles (the MODEL=s3 path already exists). It then republishes the thresholds and the T1–T10 targets in S8's profile names.
- The designer confirms the target in one question (§0 Q8).


### R2-05 [major/conflict] Reference-sword tier intent conflicts across S2, S4 and S8

Sections: S2, S4, S8, S6 | needsUserDecision: True | confidence: high

**Problem.** Three sections say different things about which tiers the standard swords should play.
- S2 calibrated so that a classic iron arming sword plays Normal on all three steps.
- S4's worked examples and simulation commentary use tiers from an older S2 run (arming sword Normal/Hard/Hard, minimal sword Hard on Smelting, cleaver Hard everywhere), and S4 builds the claim that two Hard steps is 'the common case' on them.
- S8's golden fixtures expect yet other tiers. Its intent for F1 (steel blade: Normal Hammering, Hard Sharpening) cannot happen under S2+S4's rules: Hammering works on all parts, so the steel blade adds m = 0.10 to Hammering.
The designer cannot judge the difficulty curve from three contradicting tables.

**Evidence.** S2 §5.3: '[Decision to confirm]: a classic iron arming sword plays Normal on all three MVP steps, just under 0.2'. proto/S2/out_final.txt: 'Arming sword (Iron) Smelting D=0.036 Normal / Hammering D=0.182 Normal / Sharpening D=0.179 Normal'; 'Cleaver (Iron) Smelting Expert->Hard, Hammering 0.188 Normal, Sharpening 0.329 Hard'. S4 §8.2.4 column 'S2 tiers S/H/Sh': Minimal 'H/N/N', Arming (Iron) 'N/H/H', Cleaver 'H/H/H', and 'Note that S2's reference arming sword plays Normal/Hard/Hard: the Mixed-2 rows of §8.5 are the common case'. proto/S4/examples.luau lines 36–41 hard-code these tiers. S8 §14.7.4: F1 'Normal | Normal | Hard', F4 'Hard | Hard | Normal'. Under S2 §5.1 and S4 §7.2, D_ham = 0.1 + 0.9·G ≥ 0.2 whenever G ≥ 0.111; S2's arming sword has G_ham = 0.182.

**Proposed fix.** - S2 runs its pipeline on S8's F1–F4 (the canonical golden fixtures) and publishes one tier table that both S2 §5.7 and S8 §14.7.4 quote.
- The designer confirms the intent sentence (§0 Q7). Default (S2's): plain iron is Normal everywhere; steel, thin or long blades, asymmetry or detail make steps Hard.
- If the designer prefers S8's F1 intent (a steel edge makes only Sharpening Hard), change the rule explicitly, not the reference ranges. Example: Hammering's m_s from the volume-weighted material of its work set instead of the hardest.
- S4 feeds examples.luau from S2's current output instead of hard-coded tiers and rewrites the §8.2.4/§8.5 commentary.
- S6's preview mock-ups follow.


### R2-06 [major/architecture] Balance recompute lowers MVP items' quality once Phase 2 adds steps (weights not renormalized)

Sections: S4, S1, S8 | needsUserDecision: False | confidence: high

**Problem.** An MVP item has 3 step records. When Phase 2 adds Quenching, Assembly and Finishing to the sword plan, S4 renormalizes the plan's weights. S4's recompute then takes the current weights of the 3 recorded steps, whose sum is now below 1. Every MVP item's Q drops by the weight of steps that did not exist when it was forged, and so do its Quality display, its 'Master craft' ranking and its rarity-by-score; the rarity floor only hides the rarity drop. S4 also contradicts itself on where weights come from: 'current data' in one sentence, 'the plan at balanceVersion' in another, though no code keeps old plans.

**Evidence.** S4 §7.6: 'Plan.fromHistory rebuilds the plan from the record (played tiers, materials, difficulties kept; weights and work sets from current data)' and 'Not stored: ... per-step weights and multipliers (derivable from the plan at balanceVersion)'. S4 §7.2 Phase 2 option 4: 'A plan's weights are re-normalized to sum to 1 when steps are added'. S4 §8.3.5: 'Q = 1.00 means a flawless all-Normal Iron item ... because Σw = 1 for every plan'. Example: in a 6-step Phase 2 plan where Smelting/Hammering/Sharpening keep 0.15/0.25/0.20, a flawless all-Normal iron MVP item recomputes to Q = 0.60.

**Proposed fix.** Owner S4 (§7.6).
- Plan.fromHistory takes, for each recorded step, its current weight and renormalizes over the recorded steps only: w'_i = w_i / Σ_recorded w. d_i and caps come from current tier data; the played tier is kept.
- CraftPlans entries become append-only: a retired step keeps its weight row with enabled = false, so every recorded step still has a weight.
- Delete 'derivable from the plan at balanceVersion'.
- S1's Recompute calls this path.
- S8 adds a golden test: a flawless all-Normal iron MVP record recomputed under a synthetic 6-step sword plan keeps Q = 1.00.


### R2-07 [major/architecture] Per-type step data lives in three places; S1's global per-step weights cannot express Phase 3 types

Sections: S1, S2, S4 | needsUserDecision: False | confidence: high

**Problem.** Three sections each define, with different shapes, which steps a weapon type uses, in which order, on which parts, with which quality weight and which stats they feed: S1 StepDef, S2 StepRule and S4 CraftPlans. S1's QualityWeight is global per step, so the same step cannot carry a different weight in an Axe or Hammer plan, yet weights must sum to 1 per plan. S4's sword-physics stat constants are global too: the balance plateau measured from the guard, MassRef and EdgeRef. The draft gives each weapon type its own physics focus, so Phase 3 types would force reshuffling Definitions and their consumers.

**Evidence.** S1 §2.4 StepDef { AppliesTo: {[EquipmentTypeId]: {SlotId}}, FactorWeights, QualityWeight, MainStat } and §2.7: 'AppliesTo is the single source of truth for both which types use this step and which slots it works on'. S2 §4.8 StepRule { step, workingSet, weights }. S4 §7.2: 'the merged spec keeps them once, in Definitions/CraftPlans'; §8.6.3 CraftPlans[EquipmentTypeId] = { steps = { { step, weight, worksOn, feeds } } }. S4 §8.2.3 'BalanceIdeal 0.08 ... Real swords balance roughly 5–15 %'. Design draft weapon table: Axe 'Weight at the head', Spear 'Reach and tip weight', Hammer 'Mass and impact force'.

**Proposed fix.** - S4's Definitions/CraftPlans[EquipmentTypeId] becomes the single source for per-type step data: step list and order, worksOn, quality weight, feeds.
- S1 removes StepDef.AppliesTo, QualityWeight and MainStat. StepDef keeps Id, Name, Order, Enabled, Family and FactorWeights. The V2 AppliesTo check moves to Plan.validateDefs.
- S2 drops StepRule.workingSet and calls Plan.workSet (as S4 already proposes).
- Factor weights stay per step, with an optional per-type override in GeometryRules (hook, empty in the MVP).
- S4 moves the sword-specific stat constants (BalanceIdeal/Tolerance/Falloff, MassRef, EdgeRef) to Balance.Stats[EquipmentTypeId], so Axe, Spear and Hammer get their own rows without code changes.


### R2-08 [major/gap] A valid blueprint whose only Blade part is ignored by cleaning crashes Plan.build

Sections: S2, S4, S8, S6 | needsUserDecision: False | confidence: high

**Problem.** Three sections assume different things about the required-slot check:
- S2's slot rule V3 ('Blade, Grip present') counts all parts, including those cleaning ignores.
- S4's plan assumes validation guarantees at least one kept Blade part, and asserts a non-empty Sharpening work set.
- S8's fixture A22 assumes a third reading: required slots checked on the cleaned set.
A blueprint whose only Blade part is dust passes validation, saves as Valid, and then fails Plan.build's assert at Craft.Begin (E_INTERNAL). Example: a 0.05 cube, 0.000125 stud³ < 0.0002. The same happens when the only Blade part is fully enclosed by another part.

**Evidence.** S2 §4.4 table: 'Validation V1-V6 (counts, slots, containment, connectivity) | yes'; §4.2 V3 'per slot min <= count <= max; Blade, Grip present'. S4 §7.2: 'Assumes (S2): Blade and Grip are required slots and validation guarantees at least one kept Blade part, so the Sharpening work set is never empty'; §7.3 'assert #W > 0'. S8 §14.7.5 A22: 'required-slot check runs on the cleaned set'. S2 §4.4: dust 'V_p < MIN_PART_VOLUME = 0.0002'.

**Proposed fix.** - S2 adds a validation rule (code StrikingSlotEmpty): at least one kept part in the striking slot (Blade). S2 decides and documents whether Grip also needs a kept part.
- S6 adds the message 'Your blade is too small or hidden inside another part to count'.
- S8 updates A22 to S2's rule. S4's 'assert #W > 0' becomes an invariant that S8 tests.
- Related, for R3 to judge: reach is measured on all Blade parts including dust (S2 §4.5.4), which lets ignored specks extend the Reach stat.


### R2-09 [major/scope] Editor scope goes beyond the user's per-transform snapping and inflates S6 and the saved settings

Sections: S6, S1, S5 | needsUserDecision: False | confidence: medium

**Problem.** The user asked for continuous transforms, with snapping as a per-transform-type setting (typed value or preset, on/off). S6 goes much further: per-axis snap steps, relative/absolute modes, user-defined presets, three pivot modes, group scale with a shear-free approximation, an editable post-drag delta badge, scrubbing, marquee modes, eyedropper, slot tint/ghost, auto-ortho, rulers, a view triad, plus eight extra saved settings. Each item is reasonable, but together they inflate the largest client module. The saved settings already conflict with S5's 32-key settings guard.

**Evidence.** BRIEF §1: 'the player chooses the increment for move / rotate / scale independently (any value they type, or presets), and can turn each off'. S6 §11.10.1 EditorPrefsS6: 'SnapAxes ... per-axis step + on/off', 'SnapAbsolute', 'Pivot', 'AutoOrtho', 'Rulers', 'UiScale', 'OrbitSpeed', 'InvertOrbitY', 'ReducedMotion'; user presets 'Add current as preset, up to 12 per channel'. §11.9.3 three pivot modes; §11.9.4 'Group scale ... shear-free approximation'; §11.9.5 editable 'Delta badge'; §11.11.4 'Scrub'; §11.8 marquee 'Shift = add, Ctrl = subtract, Alt = touching'; §11.13 'Alt+click picks the material'; §11.16 'Slot tint'. S5 §10.10 SetSettings guard: '≤ 32 keys of numbers/booleans'. S6 cross-section note: 'S1 EditorPrefs alone already holds ≈ 46 values'.

**Proposed fix.** S6 owns; S1 and S5 follow.
Keep:
- per-type snapping with typed steps, built-in presets, on/off and Shift inversion (the user decision);
- expression input in number fields (pure, small);
- undo/redo, physics overlays, Ctrl+I nudge inside;
- hotkeys resolved by key label (AZERTY etc.);
- Flat/Edge/Tip view presets with an ortho toggle;
- the unsaved-work reminder and a simple rarity reveal.
Simplify:
- snapping Relative only (drop SnapAbsolute; palette placement keeps its internal tangential snap);
- pivot = selection centre only;
- scale acts on the active part only (group move/rotate stay; group scale goes to Phase 2);
- marquee replace/add only;
- paint = click/drag plus Apply-to-selection;
- slot show/hide only;
- context menu = Delete/Duplicate/Mirror;
- static library thumbnails; items panel newest-first.
Cut to Phase 2 hooks: per-axis snapping, user presets, scrubbing, the editable delta badge, eyedropper and slot paint, auto-ortho, rulers, view triad, and the saved UiScale/OrbitSpeed/InvertOrbitY settings. UI scale stays automatic; ReducedMotion may stay as one boolean.
Result: EditorPrefs = S1's base shape + ReducedMotion, which fits S5's guard.


### R2-10 [major/gap] Consolidated decisions to confirm for SPEC §0 (78 scattered questions → 20)

Sections: S1, S2, S3, S4, S5, S6, S7, S8, lead | needsUserDecision: True | confidence: high

**Problem.** summaries.md lists 78 open questions for the designer (S1 9, S2 12, S3 9, S4 10, S5 12, S6 11, S7 9, S8 6).
- Many are duplicates: server size twice, saving invalid blueprints three times, the rarity floor twice, pause twice.
- Some conflict: S1 lets items be renamed, S5 excludes renaming.
- Roughly a fifth are engineering calls the designer should not have to make: storage precision, ProfileStore.Mock, store name, kick thresholds, streaming, overlap ownership.
- No section asks the lead's own BRIEF §2 defaults: standalone place, display-only items, free materials, tier clamp.
A 78-question review gate would bury the few choices that shape the game.

**Evidence.** summaries.md 'openQuestionsForUser' of S1–S8. Duplicates: S5-1 'Server size 8 players' = S7-1; S1-7 = S5-7 = S6-3 'save invalid blueprints'; S1-3 = S4-5 'rarity never drops'; S3-7 = S6-6 'no pause'. Conflict: S1-4 'Items can be renamed' vs S5-10 'leave item rename out'. Engineering calls: S5-8 'Studio playtests use ProfileStore.Mock', S5-12 'Store name Blacksmith_PlayerData_v1', S2-9 overlap ownership. BRIEF §2: 'state them in the spec as decisions to confirm'.

**Proposed fix.** §0 'Decisions to confirm', one line each with its default:
Q1 Scope: the MVP is Phase 1 only (one sword, Iron + Steel, three steps, Normal + Hard, any step with difficulty ≥ 0.2 plays at Hard) in a standalone PC-only place, with display-only items and free unlimited materials (default yes).
Q2 Server: 8 players per server, each with one smithy in a ring around a plaza; anyone may walk into any smithy and inspect its stands; players do not collide (default yes).
Q3 Envelope: one 1.6 × 5.0 × 0.6-stud hitbox for all parts, whose only placement rule is 'blade above the grip' (default yes; alternatives: another size, per-slot zones).
Q4 Parts: Blade and Grip required, Guard and Pommel optional, at most 24 parts (Blade 12, Guard 8, Grip 6, Pommel 4), smallest side 0.05 stud (default; alternative 0.02, since Roblox draws down to 0.001).
Q5 Editor: the sword lies horizontally on an enlarged private stage; snapping starts on at 0.05 stud / 15° / 0.05 stud, accepts any typed step, and turns off with one click or Shift; mirror works across the sword's centre planes (default; alternatives: upright view, snapping off by default).
Q6 Drafts: invalid blueprints can be saved as work in progress and only valid ones can be forged; no autosave, only a reminder after 5 minutes (default yes).
Q7 Difficulty: a plain iron sword plays Normal on all three steps, while steel, thinner or longer blades, asymmetry or surface detail push steps to Hard; the editor shows each step's difficulty with its full factor breakdown (default; alternatives: classic sword already Hard on one step, or tiers only).
Q8 Failure risk: an average player fails about 1 step in 10 on Normal and 1 in 4 on Hard, with one 50 % pass line at every tier (default).
Q9 Fail cost: a failed step counts at 75 % of its score and unlocks no rarity cap; nothing is destroyed on Normal or Hard (default; alternatives: 50 %, or cap loss only).
Q10 Rarity cap: one passed Hard step unlocks Epic (default; alternative: Hard on steps carrying at least half of the weight).
Q11 Rarity bands: Uncommon/Rare/Epic start at quality 0.50/0.72/0.92, step weights are 25/40/35 %, quality shows as 'Quality 92' on an open scale where 100 is a flawless all-Normal iron sword, aiming at Epic in 5–25 % of a good player's all-Hard crafts (default).
Q12 Materials and stats: Iron density 7.87 / hardness 45 / toughness 50, Steel 7.85 / 70 / 55 (better edge, slightly tougher, +0.10 difficulty), mass shown in kg; items show Damage, Sharpness, Durability, Purity, Balance and Reach (default).
Q13 Mixed materials: chosen per part in the editor; each step plays once at the hardest material it touches; the quality bonus is volume-weighted (default; alternatives: one round per material, blade dominates).
Q14 Minigames: Smelting = hold Space/LMB to pump the bellows for 15 s; Hammering = 12 timed strikes (15 on Hard) on a circular dial, first click counts; Sharpening = trace the blade's real edge behind a guiding spark; a blade with no usable edge gets a generic edge (default; alternatives: straight bar, skip Sharpening).
Q15 Interruptions: no pause; losing focus releases inputs; chat is hidden during minigames; a step with no input counts as failed and the craft goes on; abandoning or disconnecting discards the craft with no item (default).
Q16 Anti-cheat: impossible input aborts the craft, clearly inhuman input caps the step at the pass line, slow motion is only flagged, and a careful cheater faking human input is an accepted risk until Phase 2 because items are display-only (default).
Q17 Storage and names: 40 blueprints and 150 items per player; items can be scrapped; names are 1–32 Latin characters; an item takes its blueprint's name, with no renaming in the MVP (default).
Q18 Rebalancing: after a balance update, stats and quality follow the new numbers, but an item's rarity never drops (default; alternatives: strict recompute, frozen items).
Q19 Smithy and look: 6 display stands; forging starts from one Forge prompt with automatic walking between furnace, anvil and grindstone; visitors see forging live; results and inspect show a short forging record; the look is asset-free (golden hour, warm UI, listed fonts) with no audio in the MVP (default).
Q20 Done bar: at least 3 testers (one new) finish the loop unaided within 20 minutes, 2 of 3 start a second sword unprompted, you sign off that it is fun, and you can provide a published private test place for one real-save check (default).

Merged sources:
- Q2 ← S5-1, S7-1/2/8
- Q3 ← S2-1/4
- Q4 ← S2-2/3/5
- Q5 ← S6-1/2
- Q6 ← S1-7, S5-7, S6-3/4
- Q7 ← S2-7, S8-2, S6-9
- Q8 ← S3-1/3, S8-1
- Q9 ← S4-3
- Q10 ← S4-1
- Q11 ← S4-2/7/8, S8-3
- Q12 ← S1-5/9, S2-8, S4-6
- Q13 ← S1-6, S4-9/10
- Q14 ← S3-4/5/6, S6-10
- Q15 ← S3-7, S4-4, S5-2/3, S6-5/6
- Q16 ← S3-2/8, S5-4/5
- Q17 ← S1-2/4, S5-10
- Q18 ← S1-3, S4-5
- Q19 ← S6-8, S7-3/4/5/6/7/9
- Q20 ← S8-5/6

Removed as engineering calls (the owner decides and states the choice in its section): S1-1 (resolved by R2-01), S1-8, S2-6/9/10/11/12, S3-9, S5-6/8/9/11/12, S6-7, S6-11 (Phase 2 backlog), S8-4 (see R2-11).

Added, because no section asked them: Q1 (BRIEF §2 lead defaults), the visible stat list in Q12 (Purity and Balance are spec additions), asset-free look and no audio in Q19, the honest MIN_DIM trade-off in Q4, and one rename rule in Q17.

Resolve before asking:
- S3 §6.6 'Esc forfeits the step' follows S4/S5's session-level abandon.
- S4-6 is answered by S1's Steel toughness 55 unless the designer objects.


### R3-02 [major/exploit] Near-duplicate parts double-count exposed surface (SurfaceComplexity inflation, and deflation via mutual enclosure)

Sections: S2, S8 | needsUserDecision: False | confidence: high

**Problem.** The exposure test hides a surface sample in two cases: a probe 2·HIDE_TOL = 0.004 outside the face lands inside another part, or the face lies within HIDE_TOL = 0.002 of a lower-index part. Faces 0.002–0.004 apart meet neither rule, so both copies' faces count as exposed. Two invisible blade copies offset ±0.003 stud are enough to make a plain Iron arming sword Hard on two steps. Stacks spaced at 0.002 or less do the opposite: the copies become mutually 'enclosed' and are cleaned, yet they still hide the kept blade's faces, so cleaned parts lower difficulty.

**Evidence.** S2 §4.4: 'hidden iff ... sd_q(s + 2·HIDE_TOL·n) <= 0 ... or q.index < p.index and |sd_q(s)| <= HIDE_TOL'; S2 §5.8 claims filler moves a step by at most +0.03. review/R3/neardup.luau: arming sword plus 2 blade copies at ±0.003 gives 'SC raw All/Blade=2.463/2.757 ... vol=0.1061 | Hammering 0.263 Hard | Sharpening 0.298 Hard' (baseline 2.247/2.280, 0.182 / 0.179). 6 copies at k·0.002: 'cleaned=[Dup1..Dup6(enclosed)] SC 2.031/1.804 ... Hammering 0.126'.

**Proposed fix.** S2: (1) use one tolerance for both rules: a face counts as coincident if |sd_q(s)| ≤ HIDE_TOL_FACE = 0.004, equal to the probe offset, which closes the gap band; (2) compute exposure for difficulty factors in a second pass against kept parts only, so cleaned parts cannot hide kept surfaces. S8 fixtures: F1 plus 2 copies at ±0.003 must give |ΔD| ≤ 0.01; F1 plus 6 copies at k·0.002 must give |ΔD| ≤ 0.01.


### R3-03 [major/exploit] Thinness self-weighted mean: one tiny fin sets the whole factor

Sections: S2, S8 | needsUserDecision: False | confidence: high

**Problem.** Thinness = Σwφ²/Σwφ. Probes with φ = 0 (σ < 40) carry zero weight, so on a chunky sword the factor equals the φ of whatever thin bit exists, whatever its volume. A fin of 0.0003 stud³ (0.12% of the sword, just above the 0.0002 dust floor) flips Hammering from Normal to Hard.

**Evidence.** S2 §5.2: 'Thinness = Σ w_s·φ(s)² / Σ w_s·φ(s)'; proto/S2/analyze.luau: 'return if sw1 > 0 then sw2 / sw1 else 0'. review/R3/s2_exploits.luau: 'Brick Iron, fin=none ... Thin(All)=0.000 ... Hammering G=0.003 Normal'; adding a single 0.10×0.06×0.05 fin gives 'Thin(All)=0.611 ... Hammering G=0.250 Hard' (mass +0.002).

**Proposed fix.** S2: scale the self-weighted mean by the share of thin metal: Thinness = (Σwφ²/Σwφ) · min(1, Σ_{φ>0} w / (THIN_SHARE_MIN · Σw)), with THIN_SHARE_MIN = 0.25. Arming and rapier blades are about 30% of their sword's volume, so their values do not change; the fin case is multiplied by about 0.005. Add THIN_SHARE_MIN to the S2 §16 constants. S8 fixture: chunky sword plus fin must give ΔThinness ≤ 0.02.


### R3-04 [major/exploit] EdgeLength counts edge the trace never plays; the S2→S3 edge mapping is undefined

Sections: S2, S3, S4 | needsUserDecision: False | confidence: high

**Problem.** S2's EdgeLength, and S4's F_edge which uses it, is the sum of all sharpenable chains. S3 traces at most 2 'sides' ordered base→tip, while S2 outputs any number of CCW chains sorted by length, and no rule converts one into the other. A comb or serrated blade splits into many chains: EdgeLength saturates (Sharpening Hard, F_edge at its maximum) while the path actually played is shorter than a plain sword's.

**Evidence.** S2 §4.6: 'chains sorted by length descending'; S3 §6.2: 'SharpenableEdge = { sides: { EdgePolyline } } -- 0, 1 or 2 sides'. review/R3/edge_mismatch.luau, valid 10-tooth comb: 'chains=11 EdgeLength(all chains)=13.45 st -> x=1.00 | traced(2 longest)=1.82 st | Sharpening G=0.700 Hard | trace L=1.50 u, travel Normal 6000 ms'. Plain arming sword: '5.60 st ... G=0.179 Normal | trace L=3.38 u, travel 11260 ms'.

**Proposed fix.** S2 owns a single SharpeningPath output: at most 2 base→tip polylines, the right and left runs of the main outer loop from the guard line to the tip, with eligible runs joined in order along A by bridges. EdgeLength is defined as the length of that path. S4's L_edge and S3's trace source both consume this same object, and chains outside it count for nothing. The path is capped at 256 points (see R3-08). S8 fixture: for the comb blade, EdgeLength equals the traced length within 1%.


### R3-05 [major/exploit] One cosmetic Hard step unlocks Epic, so the cap is not 'the real protection'

Sections: S4, S2, S3, S8 | needsUserDecision: True | confidence: high

**Problem.** The cap is the highest cap over passed steps, so a single Hard step anywhere unlocks Epic, the MVP's top rarity. The cheapest Hard steps are cosmetic: kept Volume ≥ 0.224 stud³ (Iron) or ≥ 0.160 (Steel) makes Smelting Hard, for example with a bigger pommel; Steel alone does it on typical swords; so do the R3-01 to R3-04 tricks. With S3's own bot curves, any plan with one Hard step gives elite players 100% Epic, Smelting-only Hard included. Synthesized human-like timelines are undetectable (S3 §10.M6: noisyCheat 0.999, perfectNoisy 0.983 and pwm10 1.000 all unflagged), so a bot earns Epic on every craft.

**Evidence.** S4 §8.4.2: 'One passed Hard step unlocks Epic'. S8 §14.8.5: 'the payoff is bounded by the tier's rarity cap, which is the real protection'. review/R3/S4sim/sim_r3.luau is S4's sim plus a 'Smelt-H only' plan. With MODEL=s3: 'Elite | Smelt-H only | 0 / 0 / 0 / 100 | 0.97 | 0 / 0 / 0 / 100' and Good Steel Smelt-H only 32% Epic. With CAP_RULE=majority, Smelt-H only and Mixed-1 drop to 0% Epic. Thresholds from S2 §5.3: Volume norm(V, 0.08, 0.80); Steel D = 0.1 + 0.9·G.

**Proposed fix.** Engineering first: fix R3-01 to R3-04 and R3-14 so a Hard step reflects real design difficulty. Then the designer chooses: (a) keep the max rule (the draft's 'Hell on sharpening' example); (b) the weight-majority cap (S4 §8.4.5); or (c) the Epic cap requires a passed Hard step whose work set contains the striking slot (Hammering or Sharpening), and Smelting alone caps at Rare. R3 recommends (c): it keeps the draft's example and removes the Volume lever. S4 adds the Smelt-H-only row to §8.5.3. S8 replaces 'the real protection' with the accepted risk 'Epic is botable in the MVP' (S3 open question 8).


### R3-06 [major/exploit] ReportDesync gives a per-step seed re-roll

Sections: S3, S5, S4 | needsUserDecision: False | confidence: high

**Problem.** S3 re-issues a desynced step once with a new seed. The client alone decides whether to report a desync, so a modified client can look at step 3's pattern after banking steps 1 and 2 and re-roll it once. That contradicts S4 R4 and S5's 'impossible by construction' list. S5's catalogue has no desync action, so the behaviour is unowned. A genuine desync is deterministic (same code, params and seed give the same hash), so a new seed cannot fix it anyway.

**Evidence.** S3 §6.4.4: 'It sends ReportDesync, and the server re-issues the step once with a new seed'; S4 §7.4 R4: 'no retry, no seed re-roll'; S5 §10.11: 'Impossible by construction: ... re-rolling a seed'; the 17 actions in S5 §10.3 include no desync action.

**Proposed fix.** S5 owns this; there is never a new seed. On a client hash mismatch the client sends Craft.StartStep again, which is an idempotent re-open with the same seed and params (S5 §7.P7). If the mismatch persists, it sends Craft.ReportDesync {sessionId, stepIndex}. The server logs minigame_desync and aborts with reason Internal: no strike, no item. S3 §6.4.4 is updated to match. S8 test: a desync never changes a step's seed.


### R3-07 [major/platform] AnalysisQueue runs each whole analysis in one frame; the worst case is far above the 15 ms assumption

Sections: S5, S2, S8 | needsUserDecision: False | confidence: high

**Problem.** AnalysisQueue runs at most one job per Heartbeat, inside xpcall, with no checkpoint. S5 assumes S2's worst case is ≤ 15 ms, but S2 states a 75 ms ceiling and asks S5 to pass a yielding checkpoint or use an Actor. Measured: 48.8 ms in Lune (about 2× more on a server, by S2's own factor) for 24 rotated cylinders, an invalid work-in-progress draft that is still fully analyzed, with surface samples above the stated budget. One account can burst 7 jobs (4 saves and 3 begins) and then sustain 0.43 per second, each job a 50–100 ms server stall that every player feels. The queue is server-wide with a cap of 16, so three accounts can fill it and everyone else gets E_BUSY.

**Evidence.** S5 §1.7: 'at most ANALYSES_PER_HEARTBEAT (1) job per Heartbeat' and 'Assumes (S2): Analyze.run worst case ≤ 15 ms'; S2 §4.7: 'hard ceiling ≤ 75 ms' and 'S5 passes a yielding callback'. review/R3/analysis_cost.luau: '24 rotated cylinders 48.8 ms ... errors=25 ... surfSamples=9264' (N_SURF_TOTAL = 8000); '24 hitbox-sized blocks 28.8 ms'.

**Proposed fix.** S5: AnalysisQueue passes opts.checkpoint, which yields once the current slice exceeds ANALYSIS_SLICE_MS = 4, so analysis uses at most 4 ms per Heartbeat. Add a per-player quota ANALYSIS_QUEUE_PER_PLAYER = 2 (E_BUSY beyond it) and keep the existing re-check after each resume. When a saved draft fails V1–V6, store only the error list and skip measurement (previews run on the client). S2: budgets cap actual sample counts, not estimates, and the raster loops also call the checkpoint. S8: perf fixtures (24 rotated cylinders, 24 hitbox-sized blocks) must stay ≤ 60 ms total in Lune and ≤ 4 ms between checkpoints.


### R3-08 [major/platform] Trace pattern generation is O(n²) with no bound on path length

Sections: S3, S2, S8 | needsUserDecision: False | confidence: medium

**Problem.** generate() computes clearance over every pair of path points, and n = L/0.01 with no cap on L. The only limits are the 256-point source cap and the 30 s travel clamp, and the clamp speeds up the pacer rather than shortening the path. Generation runs synchronously in the StartStep handler on the server, and again on the client. A legal sawtooth blade already costs 18–21 ms in Lune, about 3× the claimed maximum; a 256-point zigzag source costs 1.41 s.

**Evidence.** S3 §6.10.2 step 5: 'clearance_i = min |p_i − p_j| ... O(n²), ≤ 8 ms at n = 577'; §6.12.4: 'Pattern generation takes ≤ 7.5 ms'. review/R3/sawtooth.luau, valid 5×2-tooth 65° blade: 'chains=1 pts=46 ... pathPts=1163 L=11.58 u generate=18.4 ms'. review/R3/trace_cost.luau, zigzag sources of 32 / 64 / 128 / 256 points: 23.1 / 86.4 / 359.2 / 1409.4 ms (pathPts 1276 ... 9714).

**Proposed fix.** S3: cap the path with PT_MAX_PATH_POINTS = 1500 (DS = max(0.01, L/1500)) and PT_MAX_PATH_LEN = 15 u (longer sources are simplified first, otherwise the fallback edge is used). Compute clearance on a uniform grid with cell = CLEAR_SKIP, which gives the same minimum in O(n). Budget: generate() ≤ 5 ms in Lune on the sawtooth fixture. S2: SharpeningPath (R3-04) is capped at 256 points. S8: perf tests with the sawtooth blade and the 256-point zigzag.


### R3-09 [major/platform] Explicit save cadence exceeds the per-key 4 MB/min write limit, and the failure turns server-wide

Sections: S5, S1 | needsUserDecision: False | confidence: high

**Problem.** S5 allows one explicit save per profile every 10 s, about 6.2 UpdateAsync per minute with autosave, and each save writes the whole profile. Any profile above about 0.65 MB therefore exceeds the per-key 4 MB/min write limit. S1's own worst cases are 1.14 MB (24-part caps) and 1.96 MB (48-part caps); S1 assumes 'twice a minute' at 2 MiB, while S5 assumes a profile of 1 MB or less. Denied writes become ProfileStore errors, and ProfileStore keeps one global issue queue: 5 errors within 120 s flips the server-wide critical state, and S5 then broadcasts SaveDegraded to every player. A heavy player, or a griefer, who saves blueprints every 10 s (S5's rate-limit sim accepts this) puts his own data at risk and alarms the whole server.

**Evidence.** Roblox docs (error-codes-and-limits), per key: 'Write: 4 MB per minute'; 'If the usage exceeds the limit, the request is denied'. Vendored ProfileStore: RegisterError does 'table.insert(IssueQueue, os.clock())', with CRITICAL_STATE_ERROR_COUNT = 5 and CRITICAL_STATE_ERROR_EXPIRE = 120. S5 §9.L4: '≤ 6 UpdateAsync/min/player' and 'Assumes (S1): profile size budget ≤ 1 MB'. S1 §9.7: 'a 2 MiB profile can still be written twice a minute'; S1's W formula gives 1,139,218 B at P = 24, 40 blueprints, 150 items.

**Proposed fix.** S5: set SAVE_MIN_INTERVAL_S = max(10, ceil(60·bytes / 2,000,000)), i.e. at most 50% of the per-key budget: 288 KB gives 10 s, 1.14 MB gives 35 s, 2 MiB gives 63 s. Take bytes from S1's running size estimate. Only ItemCrafted forces a save; BlueprintSaved only marks the profile dirty. S1 and S5 share one size guard: warn at 1 MiB, block creation at 2 MiB (S1's own target). Send SaveDegraded only to players whose own profile save failed (OnError's profile_key); the global critical toggle stays telemetry. S8: a 1.9 MB profile saving every 3 s must write ≤ 2 MB/min.


### R3-10 [major/exploit] Anti-cheat flags, and full item records, reach clients

Sections: S1, S5, S7 | needsUserDecision: False | confidence: high

**Problem.** StepRecord.Flags is persisted on items. S5's GetItem returns the full ItemRecord to the owner, and S1 defines ItemPublicView as the ItemRecord for visitors. Flag codes, including the telemetry-only ones, therefore reach the cheater, who can use them as an oracle to tune noise until nothing fires. They also reach other players, publicly showing flags that may be false positives. S5's own rule says flags are never sent to clients.

**Evidence.** S1 §9.4: 'Flags: { string }, -- replay / anti-cheat flags' and 'export type ItemPublicView = ItemRecord'; S5 §1.7: 'ShowcaseService.getItem: ... -> Response<{ item: S1.ItemRecord }>'; S5 §10.4: 'anti-cheat flags are NEVER sent to clients'.

**Proposed fix.** S1 defines whitelisted projections: OwnerItemView, without Flags; ItemPublicView is dropped in favour of S7's InspectView, which carries no parts, flags or seeds. S5's GetItem, Sync and Inspect send only these projections. Flags stay server-only: logs, telemetry and Profile.Data. S8: a payload test fails if any server-to-client payload contains a 'Flags' key or any flag id.


### R3-11 [major/gap] Persisted settings have no schema rebuild, the guard contradicts the prefs shape, and some actions have no owner

Sections: S5, S1, S6, S7 | needsUserDecision: False | confidence: medium

**Problem.** S5's SetSettings guard accepts a flat table of at most 32 number/boolean keys. S1/S6 EditorPrefs is nested: about 75 values, enum strings and preset arrays. S6 asks S5 to loosen the guard. Neither section says the server rebuilds prefs from the schema and drops unknown keys. If the guard becomes plain(4) and the sanitized table is stored, one call can persist up to 6,000 nodes of strings up to 256 B each (about 1.5 MB). The profile then heads for the 4 MB limit, every save fails, and R3-09's global critical state follows. UiFlags (S1/S6) and World.TeleportHome (S7) have no Router action at all, inviting unguarded ad-hoc remotes.

**Evidence.** S5 §10.10: 'settings | plain, ≤ 32 keys of numbers/booleans'; S6 cross-section notes: 'Profile.SetSettings guard must fit S1 EditorPrefs + S6 fields (≈ 75 values incl. 3 × 12 presets, nested)'; S1 §9.3: 'out-of-range values are clamped' (no unknown-key rule); S7 §13.3.2: 'Assumes (S5) remote World.TeleportHome'; proto/S5/lib/Guard.luau plain accepts string keys up to 64 B and values up to 256 B.

**Proposed fix.** S1 owns Persistence/Prefs.sanitize(raw) -> EditorPrefs. It rebuilds the table from the fixed schema (S1 and S6 fields), drops unknown keys, restricts strings to enums, clamps numbers, limits arrays to MAX_PRESETS, and rejects anything whose JSON exceeds 2 KB. S5: the SetSettings Guard is G.rec with the exact schema. UiFlags are set through SetSettings, with keys limited to 'TipsHidden.<enabled StepId>'. World.TeleportHome {} is either added to the catalogue (bucket {1, 1/3}, needsProfile, not mutating) or dropped.


### R3-12 [major/conflict] Submit payload: S3 sends a buffer, S5's Guard accepts only int arrays

Sections: S5, S3 | needsUserDecision: False | confidence: high

**Problem.** S3's timeline is one buffer: a 12-byte header and at most 14,348 B. S5's Submit guard is intArr(4096), and Guard.plain rejects buffers. As written, every honest Submit fails with E_BAD_REQUEST and earns a Hard strike, and ten steps get the player kicked. No buffer validator exists.

**Evidence.** S3 §6.7: 'One buffer, little endian'; S5 §10.4: 'inputs = G.intArr(N.MAX_INPUT_VALUES, I32[1], I32[2])'; proto/S5/lib/Guard.luau plain: 'Rejects userdata ..., functions, threads, buffers'; S5 §10.13 already anticipates 'the Guard would then accept buffer ≤ 16 KB'.

**Proposed fix.** S5 adds Guard.buffer(maxBytes): typeof(v) == 'buffer' and buffer.len(v) ≤ maxBytes, an O(1) check. Submit args become {sessionId, stepIndex, timeline, clientScore?}, where the handler checks timeline against the session family's cap, 12 + MAX_RECORDS[f]·RECORD_BYTES[f]: 3,084 / 1,036 / 14,348 B. Hard strikes apply only to non-buffers or oversize payloads. S3's decode stays the structural check (verified bounds-safe). MAX_INPUT_VALUES is removed.


### R3-13 [major/conflict] Two incompatible rejection models for impossible input and wall-clock bounds

Sections: S3, S5, S4 | needsUserDecision: False | confidence: high

**Problem.** S3 treats Invalid (decode errors, HashMismatch, TooFast below C + D − 300 ms, Expired) as score 0 and a failed step, with the session continuing, and lateness as telemetry only. S5 and S4 abort the craft with a Hard strike on decode failure or a Hard verdict, answer early submits with E_TOO_EARLY (state unchanged, at D − 250), and time out beyond D + 5 s + A. Under S3's model an exploiter can probe the validators for the price of one failed step and no strike. The mapping from S3's results (Invalid, HIGH flag) to S5's verdicts (Hard, Soft) is undefined, and two early tolerances (250 and 300 ms) would get implemented.

**Evidence.** S3 §10.M3: 'gives status = "Invalid", score 0 and a failed step'; S3 §10.M2: '300 ms tolerance' and 'a telemetry flag only'; S5 §7.P2: 'Submit(i) decode fail / verdict Hard ... Aborted(InvalidInput)'; S4 §7.4 R9: 'discards the session'.

**Proposed fix.** S5 owns one consequence table in §10.11. (1) E < D − EARLY_TOL_MS (250): E_TOO_EARLY, state unchanged, Hard strike. (2) Decode Invalid or HashMismatch: abort with InvalidInput and a Hard strike (S4 R9). (3) S3 HIGH flag: Soft; the score is clamped to the pass threshold, the step passes, and the flag is stored server-side. (4) Medium and low flags and LateSubmit: Soft, telemetry only. (5) E > D + LATE_HARD + A: the step times out. S3's judge takes E from S5 and drops its WALL_* constants.


### R3-14 [major/exploit] Stored and rendered sizes can differ from analyzed sizes (render ≠ measure)

Sections: S1, S2, S7, S8 | needsUserDecision: False | confidence: medium

**Problem.** S1's Canonical accepts and stores sizes from 1e-4 to 64 studs. S2 clamps sizes to [0.05, 6.0] only inside the analysis, as a silent clamp rather than an error. S7 renders the stored sizes, and Roblox renders down to 0.001. A sheet or fin stored 0.001 thick therefore looks razor-thin but is analyzed as a 0.05-thick solid. It adds Volume and mass (Smelting, Damage) and Thinness (R3-03), and it can bridge a visible gap of up to about 0.035 stud for connectivity. This breaks S2's rendering contract that the item renders exactly the measured solid.

**Evidence.** S1 §3.5 #9: 'Size: 3 finite numbers, 0 < v ≤ SIZE_MAX (64 stud) → quantize → ≥ 1e-4' and 'minimum parts and dimensions ... gate forging, not saving'; S2 §3.5 S5: 'each size component clamped to [MIN_DIM, MAX_DIM]'; S7 §13.8.2: 'Roblox renders sizes down to 0.001'; S2 §3.3 Studio probe: 'Block size (0.0001,1,1) | Size read back 0.001'.

**Proposed fix.** S1's Canonical applies S2's size rules before quantizing: reject with OutOfRange below MIN_DIM 0.05 or above MAX_DIM 6.0 (or clamp identically), and canonicalize Ball and Cylinder sizes. Stored, analyzed and rendered sizes are then the same. S1's SIZE_MAX changes from 64 to 6.0 and its size floor from 1e-4 to 0.05. New invariant I14: sanitizePart(p) == p for every stored part. S7's RenderPlan returns BadSize outside [MIN_DIM, MAX_DIM]. S8 fixture: a 0.001-thick bridge is rejected.


### R4a-02 [major/exploit] The EdgeLength raster turns part seams on cell centres into slits: a blade built from 0.05-wide strips measures 15.3 studs of edge (Sharpening at raw Expert)

Sections: S2, S3, S8 | needsUserDecision: False | confidence: high

**Problem.** §4.6 rasterizes the blade on 0.02 cells anchored at the grip point and marks a cell covered iff a Z-line chord through a kept Blade part exists at the cell centre. Points exactly on a shared face are decided by floating-point rounding (neither the AABB pre-check nor the slab tests have a tolerance), and gaps narrower than a cell that CONTACT_TOL still counts as connected are not bridged. With the grip at x = 0, cell centres sit on odd multiples of 0.01, which includes every seam at an odd multiple of 0.05 (±0.05, ±0.15), exactly where the default 0.05 move/scale snap puts seams. Effects on the iron arming sword with an unchanged look: blade built from 4 strips of 0.05 → edge 15.28 (plain 5.60), Sharpening D 0.544 (raw Expert); grip nudged 0.010 stud (tip-wedge seam on a column of centres) → edge 6.13, D 0.222 (Hard); 10 segments with 0.005–0.008 gaps → 6.26; a 0.5° rotation → +1.1 % (S2 claims ≤ 0.8 % for 0–9°). S3 builds the PrecisionTrace path from these chains, so the fake notches and slits also show up as dips in the trace.

**Evidence.** R4a/protoS2/perturb2.luau → out_perturb2.txt: 'blade as 4 strips of width 0.050 ... Sh 0.5441H ... edge 15.2836' (2 slits × 2 sides × 2.42 = +9.68). out_perturb.txt: 'grip shifted x 0.010 ... Sh 0.2223H ... edge 6.1257', 'rot Z 0.50 deg ... edge 5.6668'. out_edgechk.txt: the grip x +0.010 chain contains '(0.020,4.220) (0.010,3.910) (-0.020,4.220)', a fake notch down the tip seam, and bladeArea is 0.582 vs 0.540. out_exploit.txt: '10 segments, invisible gaps 0.005 ... edge 6.256'. S2 §4.6: 'covered iff any chord'.

**Proposed fix.** S2 §4.6: a cell is covered iff its centre's Z-line passes within RASTER_TOL = CONTACT_TOL/2 = 0.005 of a kept Blade part (dilate the slab and half-space tests and the AABB pre-check by RASTER_TOL, and quadrics by the same radius), so seams and connected gaps never open. Tested on a patched review copy (R4a/protoS2/analyze_eps.luau → out_fixcheck_eps.txt): 4 strips 5.5665, the same as the plain blade's 5.5665; 5 and 10 segments with 0.006 gaps 5.5665; grip nudge 0.010 → 5.632 (+1.2 %). Re-fit the EdgeLength reference range afterwards (the plain arming sword moves from 5.604 to 5.567). S8 adds regression fixtures: a strip-built blade, segment gaps of 0.004–0.009, and a grip-nudge sweep over 0–0.02 (|ΔEdge| ≤ 2 %). Owner S2; inform S3, whose trace path is built from the fixed chains.


### R4a-03 [major/exploit] SurfaceComplexity counts faces behind invisible 0.004–0.01 stud gaps as exposed, so a segmented blade buys Hard on both steps; overlaps skew it the other way

Sections: S2, S8 | needsUserDecision: False | confidence: high

**Problem.** §4.4 hides a surface sample only when the point pushed out by 2·HIDE_TOL = 0.004 lies inside another part, while V5 treats gaps up to CONTACT_TOL = 0.01 as connected. A blade split into segments with 0.004–0.009 gaps (invisible: ≤ 2.5 mm at 0.28 m/stud) therefore exposes every segment end face. In the other direction, the coincident-face rule hides a whole sample row whenever a row centre falls inside an overlap, so overlapping segments lose up to one row (0.04 stud) of perimeter per joint. This contradicts §5.8 ('Laminate thin plates, split blades … ≤ 0.01') and makes the tier depend on invisible construction choices.

**Evidence.** R4a/protoS2/out_perturb.txt, iron arming sword (plain: Ham 0.1815 / Sh 0.1787): '5 segments, gaps 0.004 ... Ham 0.1937N Sh 0.1980N | SC 2.2806/2.3574'; 'gaps 0.006 ... Ham 0.2065H Sh 0.2173H | SC 2.3147/2.4346'; '5 segments, overlap 0.02 ... Ham 0.1649N Sh 0.1513N'. out_exploit.txt: '10 segments, invisible gaps 0.005 ... Ham 0.239H Sh 0.321H'. Arithmetic: 4 gaps × 2 faces × 0.012 stud² = 0.096, so ΔSC_all = 0.096/(6·V^(2/3)) = 0.071 (measured +0.0675). The overlap case loses S_exp 3.022 → 2.981, i.e. 4 joints × 0.52 stud perimeter × 0.0197 stud of extra hidden row.

**Proposed fix.** S2 §4.4: set the hide offset to δ = CONTACT_TOL + HIDE_TOL = 0.012 (hidden iff sd_q(s + δ·n) ≤ 0), so any gap that validation calls connected also hides the faces across it. Weight the coincident-face rule by each sample's actual overlap fraction, or sub-sample coincident faces at h_s/4. Tested by raising the prototype's offset to 0.012 (R4a/protoS2/out_fixcheck_eps.txt): 5 and 10 segments with 0.006 gaps give Ham 0.178/0.176 and Sh 0.175/0.174 (plain blade with the same fix: 0.180/0.176). Correct the §5.8 claim. S8 adds fixtures with segment gaps of 0.002–0.009 and overlaps of 0.005–0.05 (|ΔG| ≤ 0.01). Owner S2.


### R4a-04 [major/numbers] Asymmetry steps with the volume-sample lattice: a 0.001-stud grip nudge flips Hammering and Sharpening to Hard

Sections: S2, S8 | needsUserDecision: False | confidence: high

**Problem.** §5.2 computes Asymmetry from a binary covered/uncovered test (ASYM_TOL 0.02) on owned volume samples. A 0.20–0.25 stud wide blade has only 4–5 sample columns across its width (n = ceil(w/0.05)), so the raw value moves in steps of 0.20–0.25 (x steps of 0.33–0.42). Against the continuous definition (1 − mirror-overlap fraction, same tolerance), the sampled value is off by up to ±0.10 raw (x ±0.17, G ±0.05), eight times S8's TOL_FACTOR_ABS = 0.02. The 0.02 tolerance does not stop sub-visual misalignment from counting; it only moves the cliff to about 0.023 stud.

**Evidence.** R4a/protoS2/out_perturb2.txt, arming sword with the grip moved in x: '+0.022 ... Ham 0.1961N Sh 0.1880N | asym 0.0252/0.0185', then '+0.023 ... Ham 0.2390H Sh 0.3058H | asym 0.1111/0.2500'. Simple asymmetric design (minimal sword, blade offset dx, mirror plane x = 0), independent implementation R4a/indep_s2.py → out_indep_s2.txt: 'dx=0.020 exact 0.0800 | text-sampled 0.0000'; 'dx=0.050 exact 0.3200 | text-sampled 0.4000'. S2's prototype gives the same sampled values (out_perturb2.txt 'blade offset x 0.050 ... asym 0.1283/0.4000'). S8 §14.6.3: 'TOL_FACTOR_ABS = 0.02 | a tier can then only flip for designs within 0.02 of a threshold'.

**Proposed fix.** S2 §5.2: use soft coverage c(s') = clamp((ASYM_TOL + ASYM_RAMP − d)/ASYM_RAMP, 0, 1), with d = min_q sd_q(s') and ASYM_RAMP = 0.03, and Asym = 1 − Σw·c/Σw. Use dedicated asymmetry probes with at least 10 samples across each part's in-plane extents (h_asym = min(H_VOL, w/10), within ASYM_BUDGET). R4a/asym_fix.py → out_asym_fix.txt: the maximum |sampled − continuous| error drops from 0.100 (binary, 5 columns) to 0.042 (soft, 5 columns) and 0.007 (soft, 10 columns). Re-fit the Asymmetry reference range. S8 adds an offset-blade sweep fixture (|Δx| ≤ 0.02 vs the continuous value). Owner S2.


### R4a-05 [major/bug] Asymmetry, and with it both MVP steps, changes when the whole sword is rotated about its own axis: a 5° twist makes Hammering Hard

Sections: S2, S6, S8 | needsUserDecision: False | confidence: high

**Problem.** The mirror plane passes through g and contains the grip axis A and blueprint Z (§5.2), and A is the XY projection of the grip axis (§4.5.3). Rotating the whole design about the blade axis (Y), which is one select-all rotate with free rotation, maps the guard and blade onto their −θ twins, and the 0.02 tolerance does not cover the difference. S2's anti-gaming row ('Shift / tilt the whole sword … 0 / ≤ 0.002') only covers rotations about Z, while S8 T-DIF-06 requires invariance under rotation about Y. The arming sword stays inside the hitbox for twists up to about ±19° (guard z-extent 0.55·sinθ + 0.12·cosθ ≤ 0.3).

**Evidence.** R4a/protoS2/perturb.luau → out_perturb.txt: 'rot Y (twist) 5.00 deg ... Ham 0.2042H ... asym 0.0434/0.0000'; '10.00 deg ... Ham 0.2425H ... asym 0.1158'; '15.00 deg ... Ham 0.3194H Sh 0.3047H'. Rotations about Z (0.25–12°) and X (0.5–3°) keep asym at 0.0000. S8 §14.6.4 T-DIF-06: 'abs(Δx_f) ≤ TOL_FACTOR_ABS under translations, θ about Y and q ↔ −q'.

**Proposed fix.** S2 defines a 3D sword frame. A3 = the normalized, volume-weighted grip axis in 3D (not projected). T = the volume-weighted thinnest local axis of the kept Blade parts, sign-aligned and orthogonalized against A3 (fallback: blueprint Z). N = A3 × T. The mirror plane passes through g and is spanned by A3 and T; Thinness's 'Z' chord uses T; the edge raster lies in the plane perpendicular to T. All of this needs only + − × ÷ sqrt. S8 adds fixtures that rotate the whole sword by up to ±10° about X, Y and Z (|Δx_f| ≤ 0.02). Owner S2; S6's default mirror plane follows the same frame.


### R4a-06 [major/bug] Thinness reads round parts as thin: chords through samples near a Ball or Cylinder rim are short, so a ball pommel alone adds up to +0.10 to Hammering

Sections: S2 | needsUserDecision: False | confidence: high

**Problem.** §5.2 takes the local thickness τ(s) as the union chord through each probe along Z and along the owner's thin axis. For Balls and Cylinders, probes near the rim have short chords: a 0.30 ball's sample at (0.125, 0.075, 0.025) has a Z-chord of 0.071, so σ = 55 and φ = 0.17. A chunky sword's Thinness therefore depends on its pommel's size and on whether the sample lattice puts points near the rim (n = ceil(d/0.05) jumps at multiples of 0.05). The effect is non-monotonic, has no physical meaning, and is a tier lever unrelated to the blade.

**Evidence.** R4a/protoS2/out_perturb2.txt, minimal sword with a 0.10-thick block blade: block pommel 'thin 0.0000 Ham 0.0000'; ball pommel 0.26 'thin 0.2554 ... Ham 0.1022', 0.28 '0.2088 / 0.0835', 0.30 '0.1684 / 0.0674', 0.32 '0.0000 / 0.0000'. Arming sword (out_perturb.txt): 'pommel diameter 0.3000 ... thin 0.3158' vs '0.3010 ... thin 0.3243' (one more sample per axis). In the coarse sweep the loop value 0.30000000000000004 gives 0.3241, because ceil(size/h) flips at the ulp.

**Proposed fix.** S2 §5.2: for probes owned by a Ball, evaluate the chords through the ball's centre; for probes owned by a Cylinder, through the probe's projection onto the cylinder axis, c + ((s−c)·u)u. Polyhedra keep the probe point (thin wedge edges are a legitimate signal). Tested in a patched review copy (R4a/protoS2/analyze_thin.luau → out_thinfix.txt): minimal sword with a 0.26–0.32 ball pommel → 0.0000; arming sword 0.3241 for pommels of both 0.300 and 0.301; rapier 0.567 → 0.601, ornate 0.353 → 0.330, greatsword 0.230 → 0.233, so SIGMA_LO/HI need a re-check. Owner S2.


### R4a-07 [major/numbers] Sampled overlap ownership mis-measures thin overlapping parts by a whole sample layer: a laminated blade loses 4 % of the sword's mass and turns Sharpening Hard

Sections: S2, S8 | needsUserDecision: False | confidence: high

**Problem.** §4.3 removes the volume samples of a lower-priority part that lie strictly inside a higher-priority part. With N_MIN_AXIS = 2, a 0.05-thick plate has only two z-layers, so a partial overlap is owned all-or-nothing per layer. The union volume (mass, COM, the Volume factor) and SC's denominator V^(2/3) then jump with sub-sample offsets. S2 says 'only overlap regions carry sampling error (bounded by each part's own resolution)' and 'Exact for non-overlapping parts'. Even the plain arming sword comes out 0.54 % heavy (S8's TOL_MASS_REL is 0.5 %), and raising N_MIN_AXIS to 4 does not remove the swings.

**Evidence.** Closed form for the plain arming sword (R4a/indep_s2.py → out_indep_s2.txt): exact union 0.105532 stud³, mass 0.83053, COM y 1.58013, balance 0.18013. S2 reports 0.1061 / 0.835 / 1.577 / 0.177, and my text-sampled reimplementation reproduces S2 exactly ('U=0.10610 M=0.8350 comY=1.5775 ... balance=0.1775'). Laminated blade (two 0.05 plates whose union is 0.06), R4a/protoS2/out_ownfix.txt: 'N_MIN_AXIS 2, plates offset 0.010 ... V 0.10110 vs exact 0.10553 (-4.2%) | Ham 0.1945 Sh 0.2238 SC_B 2.461' (plain: Sh 0.1787); with N_MIN_AXIS 4: 'V 0.10735 ... (+1.7%) | Ham 0.1604 Sh 0.1450'.

**Proposed fix.** S2 §4.3: compute pairwise overlaps between polyhedra (Block, Wedge, CornerWedge) exactly by convex clipping (at most 7 planes each; volume and first moment by tetrahedral decomposition; + − × ÷ only). Refine sampling only for pairs that involve a Ball or Cylinder (H_OVERLAP = H_VOL/4 inside the AABB intersection, within the budgets), and use the same refined sampling when three or more parts overlap each other. State the resulting error bound (target ≤ 0.5 % of mass on S8's fixtures) and use the same union volume in SC. S8 adds laminated-plate and overlapping-segment fixtures (|ΔG| ≤ 0.01, mass error ≤ 0.5 %). Owner S2.


### R4a-08 [major/numbers] The classic iron arming sword is calibrated inside the measurement noise: 0.018/0.021 below Hard, while constructions with the same look move G by −0.027 to +0.365

Sections: S2, S6, S8 | needsUserDecision: True | confidence: high

**Problem.** S2 §5.3 targets the classic iron sword 'just under 0.2' (Hammering 0.182, Sharpening 0.179). Small real edits flip it: a blade 0.005 thinner makes both steps Hard; +0.10 of blade length makes Sharpening Hard and +0.14 both. Representation-only changes flip it too (R4a-02 to R4a-07). By S8's own TOL_FACTOR_ABS = 0.02, 'a tier can only flip for designs within 0.02 of a threshold', and the anchor design is inside that band, so its tier depends on how the player built it. With free materials (R4a-14) the same sword in Steel is Hard anyway.

**Evidence.** Re-run R4a/protoS2/out_rerun3.txt (identical to S2's out_final.txt apart from timings): 'Hammering G=0.182 ... Normal', 'Sharpening G=0.179 ... Normal'. Real edits (out_perturb.txt): 'blade thickness 0.0550 ... Ham 0.2145H Sh 0.2004H'; 'blade length +0.100 ... Sh 0.2022H'; '+0.140 ... Ham 0.2020H Sh 0.2114H'. Same-look constructions (ΔG on Hammering / Sharpening): flush segments (2–10) ≤ +0.002; overlapping segments −0.017/−0.027; laminated plates +0.013/+0.045; 5 segments with 0.006 gaps +0.025/+0.039; 10 segments with gaps +0.057/+0.142; 0.05-wide strips, Sharpening +0.365; 5° twist, Hammering +0.023; 0.023 grip nudge +0.058/+0.127.

**Proposed fix.** Fix the factor artefacts first (R4a-02 to R4a-07), then re-run S2's calibration with a margin of at least 0.05 for the anchor design. For example, SIGMA_LO 40 → 50 and EdgeLength lo 4.0 → 4.5 give the iron arming sword Hammering ≈ 0.151 and Sharpening ≈ 0.146 by the §5.2 formulas, while the rapier, cleaver, sabre and greatsword stay Hard on their characteristic steps (re-verify). Whatever the margin, S6's preview should show D and the distance to the next tier, so players can see why a tier flips. The target itself is S2 decision #7, so the designer confirms 'just under 0.2' or a safer margin. Owner S2; S6 for the display, S8 for the goldens.


### R4a-09 [major/gap] A blueprint whose only Blade part is dust or fully enclosed passes validation, then breaks S4 (empty Sharpening work set, H = 0/0)

Sections: S2, S4, S8 | needsUserDecision: False | confidence: high

**Problem.** S2 counts cleaned parts in V1–V6 (§4.4 'Validation V1-V6 … yes'), so a Blade that is a 0.05 cube (V = 0.000125 < MIN_PART_VOLUME) or sits entirely inside the guard satisfies the Blade slot. The Sharpening work set (kept Blade parts) is then empty: S2 returns m = 0, EdgeLength 0, D_Sharpening 0 (plays Normal), and the reach is measured to the speck. S4 asserts '#W > 0' in Plan.build and 'each work set has positive kept volume' in Stats.inputs (H = Σ V·hardness / Σ V = 0/0), and it assumes 'validation guarantees at least one kept Blade part'. S8 A22 assumes required slots are checked on the cleaned set. So Craft.Begin throws on a blueprint the server called valid.

**Evidence.** R4a/protoS2/perturb.luau → out_perturb.txt, section H: 'Blade = one 0.05 cube (dust) ... Sh 0.0000N ... cleaned[Blade(dust)]' with no ERR, and 'kept Blade parts in W_Sharpening: 0 edge length 0'; 'Blade fully inside the guard (enclosed) ... cleaned[Blade(enclosed)]', also no errors. S4 §7.2: 'Assumes (S2): Blade and Grip are required slots and validation guarantees at least one *kept* Blade part'. S4 §7.3: 'assert #W > 0'.

**Proposed fix.** S2 adds a rule V7 KeptStrikingPart: the striking slot (Blade) must contain at least one kept part (not Dust or Enclosed), reported as SlotMissing{slot = Blade, reason = 'Cleaned'}. S2 also states that the Grip may be entirely cleaned, because the grip point uses all Grip parts analytically. S4 keeps its asserts as invariants. S8 A22 becomes the regression test for both Blade cases (dust and enclosed). Owner S2; S4 and S8 cross-reference.


### R4a-10 [major/platform] Analysis cost does not fit S5's one-analysis-per-Heartbeat queue: worst cases take 36–57 ms in Lune and Studio runs this code 2.6× slower, against S5's 15 ms assumption

Sections: S2, S5, S6, S8 | needsUserDecision: False | confidence: medium

**Problem.** S5 §1.7 assumes 'Analyze.run worst case ≤ 15 ms on a server for a max-size blueprint (fits one 60 Hz frame)' and runs one job per Heartbeat synchronously, with no checkpoint. S2 §4.7 gives typical ≤ 15 ms (assuming Roblox ≈ 2× Lune) and a 75 ms ceiling, and requires the checkpoint or an Actor. Measured: S2's own adversarial case takes 31.7–35.7 ms in Lune; a valid rotated adversarial blueprint 42.6 ms; an out-of-hitbox one 57.2 ms, and invalid work-in-progress saves are still fully analysed. So 'input size cannot push it further' describes the worst case tried, not a proven bound. A side-effect-free Studio probe ran the same Luau 2.6× slower than Lune (table-based kernel) and 6.5× slower (inline kernel), which puts the worst cases at roughly 110–150 ms per analysis. At the Save rate limit (about 20 per minute per player), one player can stall the server frame for about 0.1 s every 3 s. S6 also quotes stale timings ('4.8–21.7 ms'), uses a 120 ms debounce where S2 says 200 ms, and runs the preview synchronously.

**Evidence.** R4a/protoS2/adversarial.luau and adversarial2.luau → out_adversarial.txt: '24 overlapping rotated Blocks (tilt amplitude 4 deg ...) errors[] ... TOTAL 42.6 ms'; invalid rotated case 'TOTAL 57.2 ms (… edge 32.7 …)'. Re-runs of S2's adversarial case: 31.7–35.7 ms. Studio probe (Place1, Edit DataModel, execute_luau, pure loops only), R4a/out_bench_studio.txt: 'Studio Edit #2: 0.119 us/call' vs Lune 0.046 (2.6×); kernel #1 0.081 vs 0.012 (6.5×); checksums identical. S5 §1.7: 'at most ANALYSES_PER_HEARTBEAT (1) job per Heartbeat'. S6 §11.19.1: 'S2's prototype analysis takes 4.8–21.7 ms'.

**Proposed fix.** S5's AnalysisQueue calls Analyze.run(..., { checkpoint = yieldIfOver(ANALYSIS_SLICE_MS = 4) }) so a job spreads over several Heartbeats (S2 already exposes opts.checkpoint), or runs it in an Actor. On Save, run the full analysis only when V1–V6 pass; invalid work-in-progress saves store the validation result only. S2 restates its ceiling as measured in the Studio Server DataModel by S8's S-PERF-01, and lowers N_VOL_TOTAL / EDGE_MAX_CELLS if the measurement exceeds 75 ms. S6's PreviewScheduler uses the same time-sliced runner and a single debounce constant owned by S6. Owners S5 and S2, with S6 and S8.


### R4a-11 [major/platform] S5's save cadence exceeds Roblox's 4 MB/min per-key write limit for profiles above about 0.65 MB, and S1 and S5 disagree on the profile budget

Sections: S5, S1 | needsUserDecision: False | confidence: high

**Problem.** ProfileStore writes the whole profile on every save. S5 allows up to 6 coalesced explicit saves per minute (SAVE_MIN_INTERVAL_S = 10) plus the autosave, and assumes a profile of at most 1 MB. S1 targets a worst case of 2 MiB and only blocks growth at 3 MiB. With S2's 24 parts and S5's GUID ids, worst-case profiles are 1.17 MB (caps 40/150), 1.92 MB (60/250) and 2.34 MB (80/300), i.e. 7.3, 11.9 and 14.5 MB/min at S5's cadence. Throttled writes delay the 'ItemSaved' notice, and after a burst of saves they can push the final EndSession save past BindToClose's 30 s. S1's line 'a 2 MiB profile can still be written twice a minute' means 4.19 MB/min, which is also over the limit. The two sections' warn thresholds also differ (S1 PROFILE_SIZE_WARN_BYTES = 2 MiB; S5 'PROFILE_WARN_BYTES (S1, e.g. 1 MB)').

**Evidence.** Creator Docs, 'Data store error codes and limits': per-key throughput 'Write: 4 MB per minute'; value size '4,194,304 per key'. R4a/sizes_r4a.py → out_sizes_r4a.txt: '40/150 GUID: 1.17 MB per save, 7.3 MB/min at max cadence -> EXCEEDS; max saves/min under 4 MB = 3.4'; '60/250 ... 11.9 MB/min ... 2.1'; '80/300 ... 14.5 MB/min ... 1.7'. S5 §9.L4: 'a 100 KB profile × 6 saves = 0.6 MB/min. Assumes (S1): profile size budget ≤ 1 MB'. S1 §9.7: 'a 2 MiB profile can still be written twice a minute'.

**Proposed fix.** S5 makes save coalescing size-aware: SAVE_MIN_INTERVAL_S = max(10, ceil(60 · profileBytes / 2,000,000)), which keeps writes at ≤ 50 % of the per-key limit, using the profile size S1's runtime guard already tracks (§9.7). The autosave stays as is. S1 and S5 adopt one set of constants (PROFILE_SIZE_WARN_BYTES = 2,097,152, PROFILE_SIZE_BLOCK_BYTES = 3,145,728), and S5 drops its 1 MB assumption. S1 replaces 'twice a minute' with the 2 MB/min target. Owner S5, with S1.


### R4a-12 [major/conflict] S1 publishes hardness and toughness as integers 0–100 (Iron 45/50, Steel 70/55), but S4's stat formulas assume 0–1 values (Iron 0.50/0.50, Steel 0.70/0.50)

Sections: S1, S4 | needsUserDecision: False | confidence: high

**Problem.** S4 §8.1/§8.2.2 compute h = H·P and Sharp = 100·h·…, with 'Assumes (S1) Iron 0.50 / 0.50, Steel 0.70 / 0.50' on a 0..1 scale. S1 §2.5 defines integers 0..100 with different values, and its check V4 validates them as integers. Fed S1's Definitions directly, Sharpness and Durability clamp to 100 for every player and Damage no longer depends on skill. Scaled by 1/100, S1's values change S4's published stats. Either way, the clamps keep every stat inside 0–100 for all extreme legal swords, but S4's printed ranges change.

**Evidence.** R4a/stats_r4a.py → out_stats_r4a.txt, section C (S1 integers unscaled, Good player): 'Arming (Iron) 43.9 / 100.0 / 100.0 / 93% / 100.0' (Damage / Durability / Sharpness / Purity / Balance). Section B (S2 final physics, S1 values /100 vs S4 values): Iron Sharpness −1.7 (Bad) to −5.0 (Flawless), e.g. Good 39.5 → 35.6; Iron Damage −0.3 to −1.2; Steel Durability +2.5 to +5.0 (Good 41.6 → 45.7, Flawless 50.0 → 55.0); Steel Damage and Sharpness unchanged. Section E, extreme legal swords (heaviest 37.8 mu, longest reach 5.28, lightest 0.0026 mu, pommel-heavy): Damage 9.0–55.3 and all stats within 0–100. Durability's range becomes 17.5–55 and Sharpness's 9.5–70, and Reach can reach 5.28 (S4 §8.2.1 says 'hitbox length').

**Proposed fix.** S1 owns material values (BRIEF §5), so S1's integers stay. S4's Stats.inputs normalize them: H = Σ V·Hardness/100 / Σ V, and K likewise, with the literal 100 held in Definitions/Balance.Stats as MATERIAL_SCALE = 100. S4 re-publishes the §8.2.1 ranges (Durability 17.5–55, Sharpness 9.5–70, Reach ≤ 5.29) and the §8.2.4 tables with S1's values. S1's Steel toughness of 55 answers S4's open question 6 (steel durability). If the designer prefers S4's numbers, S1 changes its rows instead; either way there is one source. Owner S4, with S1.


### R4a-13 [major/numbers] S4's worked examples and calibration narrative were built from an older S2 run and show the wrong tiers for the reference swords

Sections: S4 | needsUserDecision: False | confidence: high

**Problem.** S4 §8.2.4 lists S2 tiers (Smelting/Hammering/Sharpening) of Minimal H/N/N, Arming (Iron) N/H/H and Cleaver H/H/H, and edge lengths of 5.04/5.65/6.68/6.20/6.71. S2's final prototype gives Minimal N/N/N, Arming Iron N/N/N and Cleaver H/N/H, with edges 5.020/5.604/7.067/5.968/6.480. The rapier's tips are kept (V 0.00034 > 0.0002), not 'cleaned as dust'. So three S4 statements are false for the iron reference sword: 'S2's reference arming sword plays Normal/Hard/Hard: the Mixed-2 rows of §8.5 are the common case', 'the chunky minimal sword … only one Hard step (Smelting)', and the §8.3.6 editor example 'Rarity cap: Epic · Quality ceiling 119'. The iron reference sword is all-Normal, with a Q ceiling of 1.00 and a Rare cap. The stat values themselves move very little (Damage −0.1).

**Evidence.** proto/S4/examples.luau, Arming (Iron): 'edge = 5.651, … tiers = { "Normal", "Hard", "Hard" }'. S2 final (R4a/protoS2/out_rerun3.txt = proto/S2/out_final.txt): 'Arming sword (Iron) … Hammering G=0.182 … Normal', 'Sharpening G=0.179 … Normal'; 'Minimal … Smelting G=0.149 … Normal'; 'Cleaver … Hammering G=0.188 … Normal'; edge 'total=5.604'; 'Rapier … parts= 7 … cleaned=[]'. R4a/out_stats_r4a.txt: 'Arming (Iron) Damage 31.1 (S4 copy) -> 31.0 (S2 final)'.

**Proposed fix.** S4 regenerates §8.2.4, §8.3.6 and the §8.5.1 plan labels from S2's final outputs, or from S8's golden fixture once it is frozen: Arming Iron N/N/N (Q ceiling 1.00, cap Rare); Arming Steel N/H/H (ceiling 1.306 = 1.10 × 1.1875, cap Epic); Minimal N/N/N; Cleaver H/N/H; rapier T = 1.0594 with its tips kept. examples.luau should read S2's analysis output instead of copied constants. Owner S4.


### R4a-14 [major/numbers] Steel's flat m = 0.10 is a free tier upgrade: it lowers the Hard threshold from G 0.200 to 0.111 and moves the classic sword from a Rare cap to an Epic cap

Sections: S2, S3, S4 | needsUserDecision: True | confidence: high

**Problem.** With D = 1 − (1 − m)(1 − G) and m_Steel = 0.10, any step with G ≥ 0.111 is Hard. Of S2's 10 distinct test designs, 5 have a Hard step in Iron and 9 in Steel (only the dagger stays all-Normal); the classic arming sword goes from N/N/N to N/H/H. With S4's T_Steel = 1.10 and d_Hard = 1.25, its Q ceiling rises from 1.00 to 1.306 and its cap from Rare to Epic. Materials are free in the MVP, so Steel is always the best choice for a skilled player, and 'ambitious drafts unlock higher caps' reduces to 'pick Steel'. §5.5's 'a plain sword stays Normal (minimal steel Hammering 0.10)' hides that the minimal steel sword's Smelting is 0.234 (Hard); in fact every steel sword with V ≥ 0.16 stud³ has a Hard Smelting step.

**Evidence.** S2 §5.5: 'Steel | 0.10 | … a plain sword stays Normal (minimal steel Hammering 0.10), a classic one becomes Hard (0.26)'. R4a/protoS2/out_perturb.txt: 'minimal Steel Sm 0.2337H Ham 0.1000N Sh 0.1765N'; 'arming Steel … Ham 0.2634H Sh 0.2609H'. R4a/out_indep_s2.txt: 'steel threshold in G: D >= 0.2 <=> G >= 0.1111; Smelting Hard for steel iff V >= 0.1600 stud^3'. Q ceiling by S4 §8.3.6's formula: 1.10 × (0.25 + 0.40·1.25 + 0.35·1.25) = 1.306.

**Proposed fix.** This is the designer's call (S2 decision #8). Option (a): keep it, and state in §0 that Steel is the MVP's 'hard mode' (tighter minigames, Hard tiers, Epic cap). Option (b): apply the material only to the minigame (S3's m_material) and set m_s = 0 in D_s for the MVP, so tiers reflect the design alone. Lowering m_Steel to about 0.02 keeps the classic steel sword Normal by only 0.002, so I do not recommend it. Default proposal: (b), until materials have a cost (Phase 4). Correct §5.5's example text either way. Owner S2, with S3 and S4.


### R4b-02 [major/numbers] Three incompatible player models: on S3's real score distributions S4's thresholds inflate rarity, and no threshold set meets S4's targets

Sections: S3, S4, S8 | needsUserDecision: True | confidence: high

**Problem.** S3 calls its 0.80-scoring bot the typical player and its 0.60 bot weak. S4 tunes thresholds on its own parametric model (average = 0.60) and maps S3 poor -> average and S3 good -> excellent only in a cross-check. S8's bots (Average σ 45 ms = S3 poor, Good σ 25 ms = S3 good) follow S4, but S8's rarity targets contradict S4's. Driving S4's formulas (re-implemented from the text) with S3's per-run bot scores: S3's 'typical' bot gets Rare on 100% of all-Normal Iron crafts and Epic on 74% (Iron) / 96% (Steel) of all-Hard crafts. 8 of 12 of S4's target rows fail under S3's labels, and 2 (T3, T7b) under S4's own reading. No (Uncommon, Rare, Epic) triple meets all targets under either labelling (best margins −0.123 / −0.134), because S3 has no bot for S4's 'Bad' or 'Good' profile. S4's own MODEL=s3 run prints a FAIL that §8.5.5 does not report. S4's T7 band is 5–45% in §8.5.2 but 5–25% in §8.5.4/§17. S8 targets 'Good on F2 Rare 20–50%' while S4's T4 requires >= 55% (measured: 100%).

**Evidence.** S3 §6.12.1 'Design target: a typical player scores about 0.80 at Normal'; S4 §8.5.5 'S3's poor bot plays like the S4 average profile'; S8 §14.8.3 'Good on an all-Normal sword (F2) reaches its cap (Rare) in 20–50 %'. `python review/R4b/q_indep.py` (golden cases A–G reproduced exactly; good All-Normal Iron 0/0/100/0, All-Hard Iron 0/0/26/74, Steel 0/0/4/96; poor All-Normal Iron 7/91/2/0). `python review/R4b/q_fast.py` (at 0.50/0.72/0.92: S4 reading T3 −0.632, T7b −0.294; S3 labels 8 FAIL; 0 feasible triples). `python review/R4b/q_search2.py` (dropping unrepresentable profiles: S4 reading 1,150 feasible, U 0.40–0.60, R 0.69–0.79, E 0.89–0.93; S3 labels only R = 0.93, E = 1.11, margin +0.005). `MODEL=s3 lune run sim.luau compact` → 'good H iron: E <= 45% margin -0.310 FAIL'.

**Proposed fix.** One profile table, owned by S8 §14.8.1 (Elite/Good/Average/Poor with numeric per-step bands), used verbatim by S3's tuning bots, S4's threshold tuning and S8's tests. Default: Average = S3's 'poor' curve (≈ 0.60 Normal / 0.50 Hard); Good = S3 'good' (≈ 0.80 / 0.70). S3 relabels §6.5.3, §6.12.1 and §17 Q3 accordingly. S3 adds S8's Poor bot (σ 90 ms, 30 fps) and a bot between Good and Average, so that T3/T4/T7 become testable. S4 replaces its parametric score model with S3's per-run distributions (review/R4b/protoS3/dump_dist.luau is a working dumper) and re-runs `tune` after S3's retune (R4b-03/04/05). Keep 0.50/0.72/0.92 if they stay inside the feasible box (currently U 0.40–0.60, R 0.69–0.79, E 0.89–0.93). S4 owns the rarity targets: S8 §14.8.3 deletes its own rarity targets, T-CR-09 asserts S4's T1–T10, and S4 picks one T7 band. Ask the designer: (1) the average player's per-step score (0.60 or 0.80 on Normal); (2) how often a good player gets Rare on an all-Normal Iron sword (S4: >= 55%; S8: 20–50%); (3) a good player's Epic share on all-Hard (5–25% or 5–45%).


### R4b-03 [major/numbers] One 0.50 pass line gives wildly different fail rates per family (HoldZone ≈ 0%, Hard TimingStrike/Trace 50–74%); S3's 'Low/Medium risk' claim is unsupported

Sections: S3, S8, S4 | needsUserDecision: True | confidence: high

**Problem.** For S3's weak bot (the average player under S4's and S8's mapping) with pass >= 0.50, fail rates are: HoldZone 0.3% (Normal) / 11.5% (Hard); TimingStrike 13.7% / 50.2% (Steel/Hard 63.9%); PrecisionTrace 12.0% / 53.1% (Steel/Hard 74.4%). S8's targets (fail 3–15% Normal, 15–40% Hard; pass 85–97% / 60–85%) are missed in 10 of 12 family × config cells. No single pass line can meet them. The pass lines that work are: HoldZone 0.54–0.59 (N) / 0.51–0.55 (H); TimingStrike 0.43–0.50 / 0.41–0.47 (Steel/Hard 0.37–0.43); Trace 0.45–0.51 / 0.40–0.46 (Steel/Hard 0.35–0.41). S4's model (18% / 60%) is also outside the targets. For an average player, Hard is a coin flip in two families and nearly free in the third.

**Evidence.** S3 §6.5.3 'This matches the draft's failure risk of Low on Normal and Medium on Hard'; S8 §14.8.3 Average 'Pass rate Normal 85–97 %', Hard '60–85 %'; S8 §17 Q1. `python review/R4b/q_fast.py` → out/q_fast.txt (per-family fail rates and pass-line intervals, from S3's own bots via protoS3/dump_dist.luau). `python review/R4b/ts_hard_sweep.py` (TimingStrike Hard windowMs ×0.80/0.85/0.90/0.95 → Iron/Hard average pass 50/60/69/76%, Steel/Hard 35/45/53/62%). `lune run review/R4b/protoS3/pt_sweep.luau` (Trace Hard halfWidth×pacer 0.88×1.12 → 43%, 0.94×1.06 → 75%; Steel/Hard 27% → 45%).

**Proposed fix.** S3 owns; S8 asserts. Tune each family × tier × material so that the agreed Average bot (R4b-02) passes 85–97% on Normal and 60–85% on Hard, with a Normal → Hard mean drop >= 0.05 (S8's TIER_MIN_MEAN_DROP). Measured starting points: (1) TimingStrike Hard windowMs multiplier 0.80 → 0.90 (Iron/Hard average 50% → 69% pass, mean drop 0.067). (2) PrecisionTrace Hard halfWidth 0.88 → 0.94 and pacerSpeed 1.12 → 1.06 (43% → 75%, drop 0.055). (3) Steel's TimingStrike windowMs 0.92 and Trace halfWidth 0.92 / pacerSpeed 1.05 are too steep on Hard (Steel/Hard still 45–53% after (1) and (2)): soften to about 0.96 / 0.96 / 1.02 and re-measure. (4) HoldZone must get harder (R4b-04). Alternative if S3 prefers to keep the parameters: per-(family, tier) passThreshold, which the data shape allows: HoldZone 0.56/0.52, TimingStrike 0.45/0.42, PrecisionTrace 0.45/0.40 (each inside the S8 band for both Iron and Steel on S3's current distributions). Rewrite §6.5.3 with per-family numbers. The designer confirms the 3–15% / 15–40% reading of Low/Medium.


### R4b-04 [major/numbers] HoldZone bots ignore 'pumping the bellows': human-rate tapping beats S3's bots by +0.10–0.20 and makes Hard smelting fail-free

Sections: S3, S8 | needsUserDecision: False | confidence: medium

**Problem.** S3's HoldZone bots only hold and release with hysteresis (0.7–1.1 presses/s), and the 60 ms minimum stroke only blunts tick-rate PWM. A pumping policy any player can execute scores far higher: it decides every 140–180 ms and taps for 70–90 ms (3–4 presses/s, at most 8 in any second), with exactly the perception delay and noise of S3's bots. Weak-perception tapper: 0.851 vs 0.656 (Iron/Normal), 0.751 vs 0.567 (Iron/Hard, pass 100% vs 89%), 0.689 vs 0.560 (Steel/Hard). Good-perception tapper: 0.918 vs 0.819 (Normal), 0.830 vs 0.691 (Hard), which is S3's elite level. The control text itself says 'pump the bellows', so players will find this. S3's numbers also depend on an undocumented zone-anticipation gain: a bot built from §6.12.1's text (kzone = 0) gives elite 0.860 instead of 0.930 (Normal) and 0.754 vs 0.818 (Hard). Smelting therefore becomes the easiest step by a wide margin and feeds about 0.85–0.92 into Q, compounding R4b-02/03.

**Evidence.** S3 §6.12.1 HoldZone row 'Closed loop on a delayed state ... Hysteresis ... Motor gaps 70 / 90 / 130 ms'; §6.8.3 'The minimum stroke (60 ms) ... blunts tick-rate PWM input'; §17 Q4 'hold Space or LMB to pump'. `lune run review/R4b/protoS3/hz_tapper.luau 300` → out/hz_tapper.txt (scored by S3's own HoldZone module and frame model; ≤ 146 records, max 8 presses/s). `lune run review/R4b/protoS3/hz_textbot.luau` → out/hz_textbot.txt.

**Proposed fix.** S3 owns. (1) Add a 'pumper' policy to §6.12.1 and to S8's HoldZone bot policy: tap period 140–180 ms ± 25–40 ms, hold 70–90 ms, the same delay and noise per profile. Tune HoldZone against the better of hold/release and pumping for each profile. (2) Either retune (narrower zoneWidth, faster driftSpeed/heatDecay at both tiers), or make the bellows stroke-based so pumping is the designed, bounded skill (e.g. each press adds ΔF = 0.25 with a 150 ms cooldown; holding adds nothing). (3) Document every bot parameter behind the published tables: kzone 0.5/0.3/0, minHold 60/70/90 ms, lapse length 0/400/700 ms, 60 fps frames with ±1 ms jitter and 0.3%/frame hitches of 30–120 ms, 100 ms velocity window. Re-run R4b-02's threshold check afterwards.


### R4b-05 [major/numbers] TimingStrike assumes perfect latency compensation; 20–40 ms of normal input/display latency collapses scores, and 30 fps players fail S8's own T-MG-11

Sections: S3, S6, S8 | needsUserDecision: False | confidence: medium

**Problem.** Strike error = InputBegan timestamp − target, so it includes the input wait (0–1 frame) and the display latency (>= 1 frame). S3's bot model silently subtracts half a frame and uses biases of 0/+5/+15 ms, i.e. a perfectly calibrated player. Nothing in S3 or S6 compensates for latency (S6 only bounds the game's own visual latency to 1 frame). The full-points core is ±9.6 ms (Normal) / ±7.7 ms (Hard) / ±6 ms (complex Steel/Hard), narrower than one 60 fps frame. Measured with my text-derived TimingStrike: +20 ms late → elite Normal 0.952 → 0.864, average Normal pass 85.7% → 67.4%; +40 ms → good Hard pass 99.8% → 31.4%, elite Hard 0.917 → 0.542. Perfect timing snapped to the next frame at 30 fps scores 0.908 / 0.866 / 0.846 / 0.804 (Iron/Normal, Iron/Hard, Steel/Hard, complex Steel/Hard), and 0.944 at 60 fps on the complex design, so S8's T-MG-11 (>= 0.95 at 30 fps) fails on S3's parameters. Implementing the text's bot literally (snap to next frame, lapse = no press) already lowers the average bot's pass rate from 86% / 51% (Normal / Hard) to 79% / 41%.

**Evidence.** S3 §6.6 Clock 't = floor((os.clock() − goClock)·1000) taken in the input handler'; §6.12.1 TimingStrike 'Presses snap to the next 60 fps frame' (proto/S3/BotsTS.luau also subtracts frameMs/2, which the text omits); S6 §12 'visual latency ≤ 1 frame'; S8 T-MG-11. `python review/R4b/ts_latency.py` → out/ts_latency.txt; `python review/R4b/ts_30fps.py` → out/ts_30fps.txt; `python review/R4b/ts_indep.py` → out/ts_indep.txt (text bot vs prototype bot).

**Proposed fix.** S3 (rules), S6 (UI/settings), S8 (tests). (1) S3 §6.6: TimingStrike press time = max(0, floor((os.clock() − goClock)·1000 − frameDtMs/2)), centring the input wait. Perfect timing then scores 0.983 / 0.965 at 30 fps instead of 0.908 / 0.866. (2) S6: a persisted player setting `TimingOffsetMs` (−120..+120, default 0) subtracted from recorded strike times, with a 10-tap calibration screen and the average early/late error on the results card; S5's settings sanitize clamps it. (3) S3: a full-points core of at least one 60 fps frame at every MVP tier, perfectCore = max(perfectFrac·W, 9 ms), and re-derived Perfect/Good grade bands. (4) S3 bots: add a per-player residual bias ~ N(+15 ms, 15 ms) and a 30 fps profile, and retune the windows to S8's bands with them. (5) S8's T-MG-11 uses the same timestamp rule and asserts >= 0.95 at 30 fps for every MVP tier, including the complex Steel/Hard design. Anti-cheat is unaffected, since the HIGH checks use the error SD, not its mean.


### R4b-06 [major/conflict] Wall-clock checks and step outcomes are specified twice with different tolerances, names and consequences; S3's SlowClock can never fire

Sections: S3, S5, S4, S8 | needsUserDecision: False | confidence: high

**Problem.** S3's judge computes TooFast (elapsed < C + D − 300 → Invalid, failed step) and SlowClock (elapsed > C + 1.25·D + 5000 → telemetry), and assumes S5's hard timeout is C + D + 30 s → Invalid('Expired'). S5 checks first, before decode: E < D − 250 → E_TOO_EARLY (state unchanged, Hard strike); soft late flag beyond D + 1500 + A; timeout beyond D + 5000 + A → score 0, timedOut, session continues. Consequences: (1) S5's 250 ms bound always fires first, so S3's TooFast is dead code. (2) SlowClock lies beyond S5's deadline for every D >= 8 s, and for the 7 s minimum trace only if ping > 875 ms. (3) S3's own example ('2× slow motion on a 15 s step ... gets flagged') is a timeout (score 0) under S5. Invalid outcomes conflict three ways: S3 says failed step and the session continues; S4 R9 and S5 §7.P2 abort the craft. S5 classes 'low jitter' as a Soft flag while S3's TS_LowVariance is HIGH (clamp), and S5's 'Hard verdict' path is undefined for S3's results. Names differ (TooFast / TooEarly / E_TOO_EARLY; Expired / timedOut / StepTimedOut). Separately, S5's 'honest timeouts ≈ 1e-6' comes from a spike model capped at 4 s (max simulated slack 5,114 ms ≈ LATE_HARD + A). With 0.5% of steps freezing for 4–12 s, 0.45% of honest steps time out.

**Evidence.** S3 §10.M1 step 3 and §16: WALL_EARLY_TOLERANCE_MS = 300, WALL_SLOW_FACTOR = 1.25, WALL_LATE_GRACE_MS = 5000; S3 §10.M1 'hard timeout, e.g. countdown + duration + 30 s'; S3 §10.M2 '2× slow-motion hack ... gets flagged'; S5 §7.P3 'E < D − EARLY_TOL_MS → E_TOO_EARLY, state unchanged, Hard strike', EARLY_TOL 250 / LATE_SOFT 1500 / LATE_HARD 5000; S4 §7.4 R9 'discards the session'; S5 §10.11 Soft 'S3 soft flags (near-perfect timing, low jitter)'; S8 §14.8.1 Cheat-Fast 'TooFast (server, S5)'. `python review/R4b/timing_joint.py` → out/timing_joint.txt (0 honest early hits for both bounds at D = 7–31 s; LateSoft 1.48–1.50% at every D; SlowClock reachability; 2× → TimedOut; heavy tail 0.45%). `lune run review/R4b/protoS5/timing_sim.luau` → out/s5_timing_sim.txt (p99.9 slack 3,711 ms, max 5,114 ms).

**Proposed fix.** S5 owns one 'step timing and outcome' table (§7.P3 + §10.11). S3 drops elapsedMs from judge and deletes TooFast, SlowClock and the WALL_* constants; §10.M2 becomes a pointer. Table rows: (1) TooEarly, E < D − 250: refuse, Hard strike, state unchanged. (2) On time, D − 250 <= E <= D + 1500 + A: judged. (3) LateSubmit (telemetry): up to D + LATE_HARD + A. (4) StepTimedOut beyond that: s = 0, passed = false, timedOut = true, session continues. (5) Invalid(reason) from S3 decode/hash: one consequence for all sections (S5 §17 Q5 default: abort the craft + Hard strike; S3 §10.M3/M5 and S4 R9 then agree). (6) S3 HIGH flags: clamp to passThreshold, step passes, never a Hard verdict. (7) S3 medium/low flags: telemetry. Use the ids TooEarly / StepTimedOut / LateSubmit everywhere (S8's Cheat-Fast expects TooEarly). Fix S3's 2× example (it times out). Consider LATE_HARD_MS = 10,000: slow motion is telemetry-only anyway, a 2× hack on any step >= 10 s still times out, and honest freezes of up to ~10 s no longer zero a step.


### R5a-02 [major/platform] Scriptable editor camera never sets Camera.Focus while the stage is about 1000 studs from the last focus

Sections: S6, S7 | needsUserDecision: False | confidence: high

**Problem.** The default camera scripts stop updating Camera.Focus once CameraType is Scriptable. The engine uses Focus to decide where lighting is computed in detail, and PointLights may not render far from it. The editor stage is at (0,1000,0), while Focus stays where the default camera left it: on the character standing at the drafting table, about 1000 studs below. The editor's CAD headlight (a PointLight) and the stage's lighting detail are therefore at risk on the editor's main screen. Neither S6 nor S7 mentions Focus anywhere.

**Evidence.** Docs Camera.Focus: 'dynamic lighting from objects such as PointLights may not render at distances far from the focus ... Focus will not automatically update when CameraType is set to CameraType.Scriptable ... you should update Focus every frame, using RunService:BindToRenderStep() ... at the RenderPriority.Camera priority.' S6 §11.5: 'Scriptable camera; ... Camera.CFrame = CFrame.lookAt(eye, P, Vector3.yAxis)' (no Focus). S6 §11.4.3: 'Headlight | PointLight (Range 60, Brightness 0.6 ...) on an invisible part that follows the camera'. S6 §11.3: 'The character stays standing at the table'. S7 §13.6.2 tweens only CFrame and FieldOfView. grep for 'Focus' in S6/S7 returns no camera-Focus line.

**Proposed fix.** S6 EditorCamera: in its BindToRenderStep at Enum.RenderPriority.Camera.Value, set Camera.Focus = CFrame.new(StageSpace.worldPoint(P)) every frame while the editor owns the camera (orbit, presets, transitions, placement mode). On exit, setting CameraType back to Custom lets the default scripts resume Focus. S7 StationStage: set Camera.Focus = CFrame.new(atW) during Scriptable framings and tweens. This is not critical there (framings are within 10 studs of the character), but it is free. S8 S-VIS-02 adds the check 'the headlight visibly lights the sword at frame-all'.


### R5a-03 [major/platform] Label-based hotkeys fail on AZERTY: M (mirror) is unreachable, and digit tooltips show &, É, (

Sections: S6, S8 | needsUserDecision: False | confidence: high

**Problem.** Hotkeys.resolve scans only KeyCode.A..Z for a key whose layout label matches. On AZERTY the key labelled M is at the QWERTY ';' position (KeyCode.Semicolon), so 'M' is never found. The fallback, Enum.KeyCode.M, is the key labelled ','. Mirror copy (M, Shift+M) therefore lands on ',' or on nothing, depending on what labelFor prints. This affects the designer's own keyboard and every French player; Dvorak and Colemak lose most letters. Digits are bound by position, but 'every tooltip shows the resolved label', and GetStringForKeyCode returns '&', 'É', '"', ''', '(' for 1–5 on AZERTY.

**Evidence.** S6 §12.8.7: 'Hotkeys.resolve(label) -- KeyCode whose GetStringForKeyCode == label (A–Z scan), fallback Enum.KeyCode[label]'. §11.21: '`M` · `Shift+M` | mirror copy across x = 0 · across z = 0'; 'Every tooltip shows the resolved label'. Probe on the designer's Studio (read-only GetStringForKeyCode): M→',', Semicolon→'M', Comma→';', Period→':', Q→'A', A→'Q', W→'Z', Z→'W', One→'&', Two→'É', Five→'('. Docs GetStringForKeyCode: 'key codes are mapped to equivalent QWERTY positions. For example, pressing A on an AZERTY keyboard results in KeyCode.Q'.

**Proposed fix.** S6: resolve(label) scans {A..Z, Semicolon, Quote, Comma, Period, Slash, LeftBracket, RightBracket, BackSlash, Minus, Equals, Backquote}, matches string.upper(GetStringForKeyCode(kc)) == label, prefers an A–Z position on ties, and falls back to Enum.KeyCode[label] only if nothing matches. Digits, F-keys and navigation keys display canonical labels ('1'..'5', 'F1', 'Home', 'PageUp'), not GetStringForKeyCode. Make the label function an injectable parameter so the module stays Lune-testable. S8 adds a Lune test with AZERTY and QWERTZ label tables (expected: 'M'→Semicolon on AZERTY, 'Z'→W, 'A'→Q) and an AZERTY row in the Studio checklist. Phase 2 rebinding could move to Roblox's Input Action System and InputActionLabel.


### R5a-04 [major/bug] Timing-strike needle spins about its own middle: GuiObject.Rotation ignores AnchorPoint

Sections: S6 | needsUserDecision: False | confidence: high

**Problem.** The dial needle is a 4×200 Frame anchored at (0.5, 1) on the dial centre and rotated by Rotation = θ. Roblox rotates a GuiObject about its own centre, which here is 100 px above the dial centre, never about the AnchorPoint. At θ = 90° the tip lands at (+100, −100) px from the dial centre instead of (+200, 0). At θ = 180° the tip sits on the dial centre. The marker players time their strikes against would not follow the ring.

**Evidence.** S6 §12.5 table: 'Needle | Frame 4 × 200 px from the centre (`AnchorPoint (0.5, 1)`, `Rotation = θ`), dark outline, tip dot 14 px'. Docs GuiObject.Rotation: 'Rotation is relative to the center of the object, not the AnchorPoint, meaning you cannot change the point of rotation. Additionally, this property is not compatible with ClipsDescendants.' Computed tip positions in review/R5a/numbers.py.

**Proposed fix.** S6 §12.5: the needle is a transparent square container (2r = 400 design px, AnchorPoint (0.5,0.5), Position = dial centre, Rotation = θ). It holds the visible 4×200 bar at Position (0.5,0,0,0), AnchorPoint (0.5,0) (from the container's top-centre to its centre) and the 14-px tip dot; only the container rotates. Add this 'pivot container' rule to §12.8.5 for any element that must rotate about a point other than its centre, and note that rotated frames cannot clip descendants.


### R5a-05 [major/platform] Minigame mouse input can be dropped as gameProcessed (Active frames), and releases over UI can leave holds stuck

Sections: S3, S6, S8 | needsUserDecision: False | confidence: medium

**Problem.** S3's input layer ignores every input with gameProcessedEvent = true. S6 states that panel backgrounds are Active and gives no Active rule for the minigame widgets. Mouse clicks over an Active GuiObject or a GuiButton reach UserInputService with gameProcessedEvent = true. LMB presses on the trace canvas, dial or gauge, or on a full-screen forge root frame, would then be silently discarded. PrecisionTrace's only grind binding is LMB, so the step would score 0. Separately, a hold that starts over the 3D view and is released over UI produces a gameProcessed InputEnded. If S3 drops it, the bellows or grinder stays held.

**Evidence.** S3 §6.6 table: 'Ignored input | `gameProcessedEvent == true` (chat, other UI)'. S3 §6.10.6: 'Grind | Hold LMB and drag along the path'. S6 §12.8.6: 'contains a visible Active GuiObject of our ScreenGuis (panel backgrounds are Active)'. S6 §12.6: 'Canvas (TraceCanvas): Frame with UIAspectRatioConstraint 3.0' (no Active setting). Docs GuiObject.Active: 'determines whether the GuiObject will sink input to 3D space'. DevForum reports: clicking frames with Active on gives gameProcessedEvent = true in UserInputService events. Probe: Frame.Active defaults to false, TextButton.Active to true.

**Proposed fix.** S6 §12.3.2/§12.8.6: in BS_Forge during Countdown and Playing, every GuiObject in the play area (widget roots, canvas, gauge, dial, HUD overlays, full-screen roots) has Active = false and Selectable = false. GuiButtons appear only outside the widget rect (Abandon top-left) and nowhere during Playing except Abandon. S3 §6.6: apply the gameProcessed filter to InputBegan only. An InputEnded for a key or button whose InputBegan was accepted is always recorded. Trace cursor motion comes from InputChanged regardless of gameProcessed (or from GetMouseLocation each frame). S8: Studio scenario 'hold LMB at the canvas centre through GO → first TraceRecord has grind = true; release over the Abandon button → a release record exists'.


### R5a-06 [major/bug] Rarity light and sparkles are parented to a Folder, where lights do not light and emitters do not emit

Sections: S7, S8 | needsUserDecision: False | confidence: high

**Problem.** S7 puts the rarity PointLight (Rare and above) and the sparkles ParticleEmitter (Epic and above) in an 'Fx' folder under InspectHitbox. A PointLight lights only as a direct child of a BasePart or Attachment, and a ParticleEmitter emits only when parented to a BasePart or an Attachment. The Box/Volume emission 'inside the InspectHitbox' also requires the emitter to be the part's direct child. As written, every MVP rarity light and sparkle effect would silently not render.

**Evidence.** S7 §13.4.4 tree: 'InspectHitbox (Part, only when occupied)[ClickDetector, Fx/PointLight, Fx/ParticleEmitter]'. S7 §13.9: 'Light and emitter live under the hitbox's `Fx` folder'; 'Shape = Box, ShapeStyle = Volume (emits inside the InspectHitbox)'. Docs PointLight: 'In order for a PointLight to provide illumination, it must be the direct child of a BasePart or Attachment'. Docs ParticleEmitter: 'To emit and render particles, it must be parented to a BasePart or an Attachment within such a part. When parented to a BasePart, particles spawn randomly within the part's bounding box'.

**Proposed fix.** S7 §13.4.4/§13.9: parent RarityLight (PointLight) and RaritySparkles (ParticleEmitter, Shape Box, ShapeStyle Volume) directly to InspectHitbox, so the Box volume equals the hitbox. Drop the Fx folder and identify the effects by name or by a BS_RarityFx tag for cleanup. Add a build rule in §13.12: every Light, ParticleEmitter, Fire or Smoke is a direct child of a BasePart or Attachment (coal bed, lanterns, candle and the Work attachments already comply). S8 S-VIS-06/07: a Rare item visibly lights its plinth and an Epic item sparkles.


### R5a-07 [major/conflict] Trace canvas coordinates: S3's IgnoreGuiInset assumption is wrong per the docs; S6's mapping must win

Sections: S3, S6, S8 | needsUserDecision: False | confidence: high

**Problem.** S3 says the minigame ScreenGui uses IgnoreGuiInset = true so that GetMouseLocation() and AbsolutePosition share one space. In fact AbsolutePosition always uses the CoreUISafeInsets space (origin under the top bar), the same space as InputObject.Position, whatever IgnoreGuiInset is. GetMouseLocation ignores insets. Implemented as S3 describes, the scored cursor sits one top-bar height (58 px) below the real pointer. That is 0.112 panel units at 1080p and 0.151 at 720p, three to four times the 0.037 band half-width. Every trace would be scored off-path, or the reticle drawn away from the real pointer. S6 already flags the conflict; the docs settle it.

**Evidence.** S3 §6.6 'Coordinates': 'The minigame ScreenGui uses `IgnoreGuiInset = true` so that `GetMouseLocation()` and `AbsolutePosition` share one space. Assumes (S6).' S6 §12.6: 'p = input.Position ... or equivalently GetMouseLocation() − (GuiService:GetGuiInset())' with 'u = clamp((p.X − canvas.AbsolutePosition.X) / canvas.AbsoluteSize.Y, 0, 3)'. Docs GuiBase2d.AbsolutePosition: 'If the GuiBase2d is in a ScreenGui, the AbsolutePosition property uses the CoreUISafeInsets viewport coordinate system ... the same coordinate system used by the InputObject.Position property.' Docs GetMouseLocation: 'This does not account for the ScreenInsets'. Probe: setting IgnoreGuiInset = true flips ScreenInsets to DeviceSafeInsets. Offsets computed in review/R5a/numbers.py.

**Proposed fix.** Ruling: S6 §12.6 TraceCanvas.toPanel wins. It uses InputObject.Position (or GetMouseLocation() − GetGuiInset()) relative to canvas.AbsolutePosition/AbsoluteSize.Y and is valid for any ScreenInsets value. S3 §6.6: delete the IgnoreGuiInset sentence and reference TraceCanvas.toPanel. The pixel-lattice check S3 lists as a future hardening hook (§10.M6) must use the same space. S8 keeps the reticle-at-pointer screenshot check at 1920×1080 and 1280×720.


### R5a-08 [major/conflict] StreamingEnabled contradicts itself (S5 false, S7 true); place settings can and should live in the Rojo project

Sections: S5, S7, S6 | needsUserDecision: False | confidence: high

**Problem.** S5 sets Workspace.StreamingEnabled = false as a decision to confirm. S7 writes the world around StreamingEnabled = true (Atomic models, RequestStreamAroundAsync before teleports, notes on stream-in and stream-out). S6's required StarterPlayer.EnableMouseLockOption = false (Shift is an editor modifier) appears in nobody's settings list. Its default is true, so Shift would toggle shift-lock. S5 also says these settings 'are not representable in the project file', but rojo build writes them.

**Evidence.** S5 §1.8: 'One-time place settings (not representable in the project file; README checklist)' with 'Workspace.StreamingEnabled | false [Decision to confirm]'. S7 §13.7.4: 'Workspace.StreamingEnabled | true (default of new places; not scriptable, set in Studio)', 'ModelStreamingMode | Atomic ...', 'Teleport | RequestStreamAroundAsync(homePos, 2)'. S6 §11.3: 'Assumes (S5/S7): StarterPlayer.EnableMouseLockOption = false'. Probe: this place has StreamingEnabled = true and EnableMouseLockOption = true (defaults). Rojo test (review/R5a/rojo_props): rojo 7.7.0-rc.1 build of Workspace.$properties {StreamingEnabled:false}, StarterPlayer.$properties {EnableMouseLockOption:false}, Lighting.$properties {...} produced out.rbxlx with '<bool name="StreamingEnabled">false</bool>', '<bool name="EnableMouseLockOption">false</bool>', LightingStyle, PrioritizeLightingQuality and ClockTime 17.

**Proposed fix.** Engineering ruling (S5 owns the project file): StreamingEnabled = false for the MVP, because the world is about 0.94k static plus at most 1.4k dynamic parts and S8's 'model replicated within 2 s' checks become deterministic. Set it in default.project.json as "Workspace": {"$properties": {"StreamingEnabled": false}}. Add "StarterPlayer": {"$properties": {"EnableMouseLockOption": false}}. S5 §1.8: drop the [Decision to confirm] (this is not a product choice) and the 'not representable' line. Keep a one-line README check, because live sync (rojo serve) of these properties was not verified. Max Players stays a Game Settings item. S7 §13.7.4: follow the ruling; keep the tag and attribute binding (no cost, and a later switch stays free); guard RequestStreamAroundAsync and the ModelStreamingMode writes with workspace.StreamingEnabled.


### R5a-09 [major/platform] Client preview hitch: the planned Actor fallback cannot fix a long unyielding analysis; S6 cites stale costs

Sections: S6, S2, S5, S8 | needsUserDecision: False | confidence: medium

**Problem.** S6 runs the full analysis synchronously at the end of a 120 ms debounce, with an acceptance target of p95 ≤ 33 ms on a minimum-spec PC 'with the 24-part worst-case fixture'. If that fails, it plans to move the call into a client Actor. S2's measured worst case is 36 ms in Lune (24 overlapping hitbox-sized parts), and S2 itself assumes Roblox runs at about 2x Lune. That case would hitch every commit and is predicted to fail S6's own acceptance test. Per the Parallel Luau docs, moving the same unyielding call into an Actor does not remove the hitch. S6's cost line (4.8–21.7 ms) does not match S2's current table (1.4–7.3 ms typical, 36 ms adversarial). S2's client cadence (200 ms debounce, ≤ 4 Hz, connectivity at 10 Hz during drags) also conflicts with S6's (120 ms, nothing during drags). The server side has the same misconception: S2 lists an Actor as an alternative, and S5's AnalysisQueue runs one unyielding job per Heartbeat.

**Evidence.** S6 §11.19.1: 'S2's prototype analysis takes 4.8–21.7 ms per sword in Lune ... Plan: run synchronously at the end of the debounce ... If it fails, the scheduler moves the same pure call into a client Actor worker'. S2 §4.7: 'Adversarial: 24 overlapping hitbox-sized parts | 24 | ... | 36'; 'Server, typical (Roblox ≈ 2× Lune)'; 'Client, full preview | debounced 200 ms after the last change, ≤ 4 Hz'; 'Server execution | ... `opts.checkpoint` callback ... or a Parallel Luau Actor'. S5 §1.7: 'at most ANALYSES_PER_HEARTBEAT (1) job per Heartbeat'. Parallel Luau docs: 'Avoid Long Computations — Even in parallel, long computations can block execution of other scripts and cause lag. Avoid using parallel programming to handle a large volume of long, unyielding calculations.' and 'You can't use require() in a desynchronized parallel phase.'

**Proposed fix.** S6 §11.19.1: run Physics.Analyze.run(doc, { checkpoint = frameBudget(4 ms) }) in a coroutine started when the debounce ends. The checkpoint calls task.wait() whenever os.clock() − frameStart > 4 ms. Results are tagged with the revision and stale ones are dropped. Drop the Actor fallback; if one is kept, it must yield at the same checkpoints and pre-require its modules in serial. Update the cost line to S2 §4.7's numbers. S2 §4.7: the client rows defer to S6 (S6 owns the client cadence: 120 ms debounce, no connectivity check during drags, or S6 adopts S2's 10 Hz check explicitly). Remove 'or a Parallel Luau Actor', or qualify it as 'only with the same yielding checkpoint'. S5: AnalysisQueue passes the same yielding checkpoint so a 36–75 ms job is spread over frames. S8 acceptance becomes: no client frame over 33 ms on the minimum-spec PC with S2's adversarial fixture, and the preview ready within 500 ms.


### R5b-02 [major/conflict] Two contradictory server judge contracts: timing bounds, Invalid consequences, flag handling and desync re-roll

Sections: S3, S4, S5 | needsUserDecision: False | confidence: high

**Problem.** S3 §10.M1–M5 and S5 §7.P3/§7.P4/§10.11 each define the wall-clock window and the consequences, and they disagree. Early bound: 300 ms (S3) vs 250 ms (S5). Soft-late: C + 1.25·D + 5 s (S3) vs D + 1500 + A (S5). Hard timeout: C + D + 30 s → Invalid("Expired") (S3) vs D + 5000 + A → score 0, timedOut (S5). An S3 Invalid is 'score 0, failed step, craft continues', but S5 and S4 R9 abort the craft (S5 also adds a Hard strike). S3 clamps HIGH flags to passThreshold; S5 keeps the score on Soft verdicts. On ReportDesync, S3 re-issues the step with a new seed, while S5 forbids any seed re-roll. A modified client could therefore report a desync to get one free re-roll per step.

**Evidence.** S3 §10.M1: "elapsedMs < countdownMs + durationMs − WALL_EARLY_TOLERANCE_MS → Invalid("TooFast")" (300 ms, §10.M2); §10.M5: "Invalid ... score 0, failed step"; HIGH flags "clamp the step score to passThreshold"; §6.4: "the server re-issues the step once with a new seed". S5 §7.P3: "EARLY_TOL_MS = 250 LATE_SOFT_MS = 1 500 LATE_HARD_MS = 5 000"; §7.P2: "decode fail / verdict Hard → Aborted(InvalidInput) ... Hard strike"; §7.P3: "re-open returns the same seed: no re-roll". S4 R9: "Rejected submission = discard".

**Proposed fix.** One pipeline with clear owners. S5 owns the window and its constants (E = t_recv − t_open − C, A = min(2·ping, 2000), EARLY_TOL 250, LATE_SOFT 1500, LATE_HARD 5000) and computes the window verdict: TooEarly → E_TOO_EARLY with state unchanged; LateSoft → flag; Timeout → score 0. S3's judge drops its own wall-clock stage, or receives S5's verdict as input. S3 keeps decode, hash, replay and flags. S4 R9 owns consequences: any S3 Invalid, HashMismatch included, aborts with InvalidInput. HIGH flags clamp as S3 says (it is the bound on cheating payoff); medium and low flags become S5 'Soft'. ReportDesync aborts the session with reason "Desync": no re-roll, telemetry, no strike, because a new seed cannot fix a determinism bug. Rewrite S3 §10.M1–M3/§10.M5 and S5 §7.P2/§10.11 to point at each other.


### R5b-04 [major/conflict] S5's DataService codes against a Persistence API and Profile.Data shape that S1 does not define

Sections: S1, S5, S6 | needsUserDecision: False | confidence: high

**Problem.** S5's load sequence calls Persistence.migrate(data) → (ok, why), SCHEMA_VERSION, checkStorable and then profile:Reconcile(). It reads lower-case fields: blueprints, items, smithy.displays as a dense string array with "" for empty, schemaVersion, and a flat settings table of numbers and booleans. S1 defines Prepare.run(data, ctx) → PrepareReport{status Ok|Newer|Corrupt, staleCheap, staleGeometry, ...} with ctx.displaySlots from S7, plus JsonSafe.check. S1's fields are PascalCase (DataVersion, Blueprints, Items, Smithy.Displays keyed by slot id, EditorPrefs nested with strings and arrays), and S1 states that S5 must never call profile:Reconcile(). ItemSummary is defined twice with different fields (S1 Items/Schema vs S5 Net/Protocol). S5's SetSettings guard (≤ 32 flat number/boolean keys) cannot carry S1's EditorPrefs (about 75 values, nested, Space is a string), as S6 already noticed.

**Evidence.** S5 §9.L2: `local ok, why = Persistence.migrate(profile.Data)` ... `profile:Reconcile()`; S5 App. A: ".smithy.displays is a dense string array", "profile size budget ≤ 1 MB". S1 §9.6: "S5 calls it right after StartSessionAsync and never calls profile:Reconcile() itself"; S1 §9.3 PlayerData {DataVersion, NextIds, Blueprints, Items, Smithy{Displays: {[string]: ItemId}}, EditorPrefs...}. S5 §10.10: SetSettings "≤ 32 keys of numbers/booleans"; S6 S5-row: "Profile.SetSettings guard must fit S1 EditorPrefs ... (≈ 75 values ...) — S5's current guard says ≤ 32 keys".

**Proposed fix.** S1 owns Profile.Data and wins on shapes and names. Rewrite S5 §9.L2 as: AddUserId → report = Prepare.run(work, {displaySlots = <S7 slot ids>}) → branch on report.status (see R5b-05). DataService never calls profile:Reconcile(). It recomputes report.staleCheap synchronously and queues staleGeometry (R5b-22). S5's checkWatchedItems reads LastSavedData.Items[id]. Net/Protocol re-exports S1's BlueprintSummary/ItemSummary, with no second definition. SetSettings validates with an S1-owned Persistence.Prefs.sanitize (clamping, as S1 §9.3) instead of a flat Guard. Delete S5 Appendix A rows 1–3 and point them to S1 §9.


### R5b-05 [major/platform] 'Corrupt → read-only session' cannot be built on ProfileStore, and Prepare mutates the live profile before the JSON check

Sections: S1, S5 | needsUserDecision: False | confidence: high

**Problem.** S1's load pipeline migrates, reconciles and repairs profile data in place (steps 2–4) and only then runs JsonSafe.check (step 6), which can return status 'Corrupt' with 'S5: telemetry, read-only session'. ProfileStore has no read-only mode for an active session. Every active profile sits in AutoSaveList and is written about every 300 s and again on EndSession or shutdown. SaveProfileAsync always writes whatever table profile.Data currently points to. So a 'read-only' session still saves, and saves the half-migrated data. S5 has no handling of 'Corrupt' at all.

**Evidence.** S1 §9.6: "6. JsonSafe.check(data) -- failure → status "Corrupt" (S5: telemetry, read-only session)", after steps 2–4 that mutate `data`. ProfileStore.luau: Profile methods (lines 139–166) offer no way to suspend saves; Heartbeat autosave loop (lines 2115–2153); SaveProfileAsync line 791 `latest_data.Data = profile.Data`; line 711 only requires profile.Data to be a table, so reassigning it is supported.

**Proposed fix.** Prepare.run works on a deep copy and returns it: (report, prepared) = Prepare.run(deepCopy(profile.Data), ctx). DataService assigns profile.Data = prepared only when status == 'Ok' (ProfileStore saves the table profile.Data points to at save time). On 'Newer' or 'Corrupt': leave profile.Data untouched, call profile:EndSession() (which writes back exactly what was loaded), send DataIssue telemetry and kick with KICK.DATA_ERROR ('We couldn't open your smithy, please contact support'). 'Read-only' viewing, if wanted later, uses ProfileStore:GetAsync (view mode, no lock, no autosave). S1 replaces 'read-only session' with this rule, and S5 §9.L2 and §9.L6 add the 'Corrupt' row.


### R5b-06 [major/platform] Store and key names conflict, and automated RTBF needs a deletion template that neither draft schedules

Sections: S1, S5 | needsUserDecision: False | confidence: high

**Problem.** S1 uses store 'PlayerData' with key 'User_<UserId>' (PROFILE_STORE_NAME in Definitions/Limits). S5 uses 'Blacksmith_PlayerData_v1' with key 'Player_%d' (Definitions/Network). S1 also claims the static key 'enables automated right-to-be-forgotten'. Per the Creator Docs, automated RTBF only runs once the creator defines deletion templates (Creator Hub → Configurations → Data stores manager → RTBF Deletion, or the Configs API), and the UserId must appear in the data store or key name, or the scope. A static key pattern is only the eligibility condition. The UserIds metadata written by profile:AddUserId is not what the automated deletion matches.

**Evidence.** S1 §9.1: "key "User_" .. player.UserId — Roblox's recommended static pattern (enables automated right-to-be-forgotten)". S5 §9.L1: Store name "Blacksmith_PlayerData_v1", Key `string.format("Player_%d", userId)`. Docs right-to-be-forgotten.md: "To use automated RTBF processing, you must define deletion templates"; "The user ID must be part of the Name or the Scope of the data store or key"; template example key_pattern "User_{UserId}", scope_pattern defaults to "global". ProfileStore.New calls GetDataStore(store_name, nil, options), i.e. scope "global".

**Proposed fix.** Define the pair once, in S5's Definitions/Network.luau, and delete PROFILE_STORE_NAME from S1's Limits (or make it a reference). Suggested values: STORE_NAME = "Blacksmith_PlayerData" (namespaced for a possible shared universe with the forge & mining project) and PROFILE_KEY_FORMAT = "User_%d". Add to the README launch checklist, owned by S5: create an RTBF template {Standard Key, data_store_name = STORE_NAME, key_pattern = "User_{UserId}", scope_pattern = "global"}, test it end to end with a dummy account, and give every renamed or old store holding user data its own template. Reword S1 to 'eligible for automated RTBF once the deletion template is configured'. Keep AddUserId as the GDPR association; it does not trigger automated deletion.


### R5b-07 [major/numbers] Explicit-save cadence (6 per minute) exceeds the 4 MB/min per-key write limit at S1's worst-case profile size

Sections: S5, S1, S6 | needsUserDecision: False | confidence: high

**Problem.** S5 coalesces explicit saves to one per 10 s per profile (≤ 6 UpdateAsync/min) and justifies it with a 100 KB profile. It assumes S1's budget is ≤ 1 MB, but even 1 MB × 6 = 6 MB/min is over the limit. S1's caps allow 1,956,068 B (and up to the 3 MiB block threshold), giving 11.7 MB/min, 2.9× the documented per-key write throughput of 4 MB/min. S1 itself says a 2 MiB profile can only be written twice a minute. A throttled key queues and skips requests, and ProfileStore serializes UpdateAsync calls per key. Explicit saves then pile up, the final EndSession or shutdown save can miss the 30 s BindToClose window (losing the latest changes), and repeated failures push ProfileStore into its critical state.

**Evidence.** S5 §9.L4: "at most one per SAVE_MIN_INTERVAL_S = 10 s per profile ... ≤ 6 UpdateAsync/min/player"; "Per-key write throughput is 4 MB/min: a 100 KB profile × 6 saves = 0.6 MB/min. Assumes (S1): profile size budget ≤ 1 MB". S1 §9.7: worst case "1,956,068 B"; "a 2 MiB profile can still be written twice a minute". Docs error-codes-and-limits.md: per-key Write limit "4 MB per minute" (UpdateAsync counts); "If the data store key itself is throttled, the request is placed in a queue but is temporarily skipped"; BindToClose waits 30 s. Computation (python): 1,956,068 × 6 = 11.74 MB/min.

**Proposed fix.** Make the interval size-aware: SAVE_MIN_INTERVAL_S = max(10, ceil(60 · bytes / (KEY_WRITE_SHARE · KEY_WRITE_BYTES_PER_MIN))), with KEY_WRITE_BYTES_PER_MIN = 4,000,000 and KEY_WRITE_SHARE = 0.5. That gives 10 s up to 333 KB, 30 s at 1 MB, 59 s at S1's worst case and 95 s at the 3 MiB block. Use S1's runtime size estimate (§9.7) for bytes. Skip the explicit save when nothing changed since the last successful save. Replace S5's '≤ 1 MB' assumption and its 'PROFILE_WARN_BYTES e.g. 1 MB' with S1's 2 MiB warn and 3 MiB block. S6's 'saved' tick (ItemSaved) must not promise immediacy: up to about 60 s for very large profiles.


### R5b-08 [major/platform] AnalysisQueue does not bound server frame cost: S2's analysis can take 36–75 ms and needs a yielding checkpoint

Sections: S5, S2, S3 | needsUserDecision: False | confidence: high

**Problem.** S5 runs at most one S2 analysis per Heartbeat. It assumes ≤ 15 ms and claims this bounds frame cost 'regardless of its final cost'. Luau scheduling is cooperative, so a non-yielding 36–75 ms call blocks the server frame (physics, replication, every other handler) for 2–5 frames. A per-Heartbeat FIFO limits how many analyses start, not how long each one runs. S2 states the hard ceiling (75 ms, 36 ms measured in Lune) and explicitly assumes S5 passes a yielding opts.checkpoint or uses an Actor; S5 does neither. S5's §10.13 budget also omits S3's server-side pattern generation at StartStep (≤ 7.5 ms in Lune for Trace).

**Evidence.** S5 §1.7: "AnalysisQueue — bounds server frame cost of S2's voxel pipeline regardless of its final cost"; "Assumes (S2): Analyze.run worst case ≤ 15 ms on a server". S2 §4.7: "Server, hard ceiling | ≤ 75 ms (budget-bounded; worst constructed case 36 ms in Lune)"; "Server execution | ... opts.checkpoint callback ... (S5 passes a yielding callback) or a Parallel Luau Actor". S3 §6.12.4: "Pattern generation takes ≤ 7.5 ms".

**Proposed fix.** Run one analysis at a time in its own thread and pass opts.checkpoint = function() if os.clock() − sliceStart > ANALYSIS_SLICE_MS/1000 then task.wait(); sliceStart = os.clock() end end, with ANALYSIS_SLICE_MS = 4. A 75 ms job then spans about 19 frames (≈ 0.3 s), and a full queue of 16 waits about 5 s, well under REQUEST_TIMEOUT_S = 20. S2 must call checkpoint only at top-level loop points, never inside table.sort comparators, string callbacks or metamethods, because Luau cannot yield across those (yielding inside pcall/xpcall is fine). Add S3 pattern generation (≤ 15 ms on Roblox) to §10.13. An Actor is feasible but not needed for the MVP: Rojo declares one with init.meta.json {"className": "Actor"} (verified: sourcemap shows 'AnalysisWorker (Actor)'), the pure modules are re-required inside the Actor VM, and data is copied in via SendMessage.


### R5b-09 [major/conflict] S5 and S7 define incompatible world and session models (spawn, plot assignment, no-plot behavior, streaming, TeleportHome)

Sections: S5, S7, S6 | needsUserDecision: False | confidence: high

**Problem.** The two drafts disagree on five points. (1) Spawn: S5 gives each plot one enabled SpawnLocation and sets Player.RespawnLocation, with no other spawn in the world; S7 builds one PlazaSpawn, never uses RespawnLocation and teleports with PivotTo on claim and on every CharacterAdded. (2) Plot assignment: S5 assigns on PlayerAdded before the profile loads; S7 assigns after the profile session starts. (3) No free plot: S5 kicks; S7 keeps the player as a plot-less visitor and rejects requests with NoPlot. (4) Workspace.StreamingEnabled: S5 says false, S7 says true with ModelStreamingMode Atomic and RequestStreamAroundAsync. (5) S7 assumes a World.TeleportHome remote that S5's catalogue (4 channels, 17 actions) does not have. Platform facts: RespawnLocation needs a Workspace SpawnLocation that is Neutral or matches the player's TeamColor, and 'When disabled players cannot spawn at the SpawnLocation'. So S5's per-plot spawns must stay enabled, and any player whose RespawnLocation is not yet set spawns on a random plot.

**Evidence.** S5 §1.6: "Spawn | player.RespawnLocation = plot.spawn", "No free plot | Kick", "Assignment | ... on PlayerAdded, before the profile loads"; §1.8 "Workspace.StreamingEnabled | false". S7 §13.3.2: "Player.RespawnLocation is not used"; §13.3.1: "After the profile session starts", "the player stays plot-less (visitor-only ...)"; §13.7.4: "Workspace.StreamingEnabled | true"; §13.3.2: "Assumes (S5) remote World.TeleportHome". Docs Player.RespawnLocation (criteria) and SpawnLocation.Enabled.

**Proposed fix.** The lead picks one model; engineering call. Recommended: (a) S7's single neutral PlazaSpawn plus server PivotTo home on claim and on CharacterAdded (robust to the first-spawn race; no per-plot spawns). (b) S5's timing: assign the plot on PlayerAdded, and render stands after the profile loads (ShowcaseService.renderAll already waits). (c) S5's kick when no plot is free (only reachable with a misconfigured MaxPlayers); drop S7's NoPlot visitor mode. (d) StreamingEnabled = false, set in the project file (R5b-18), with S7 keeping its streaming-tolerant lookups. (e) Add Profile.TeleportHome {} to S5 §10.3 with bucket {1, 1/3 s}, the E_SESSION_ACTIVE rule and no profile requirement, or drop the HUD button. Move S5 §17 Q11 (StreamingEnabled) out of the designer questions.


### R5b-10 [major/testing] S8's Studio E2E scenarios contradict S5's protocol: names, codes, countdown, WIP saves, strike kicks, rate-limit replies

Sections: S8, S5 | needsUserDecision: False | confidence: high

**Problem.** (1) The bridge 'call' uses InvokeServer and the scenarios use StepStarted, SubmitStep, ItemCreated, TooFast, AlreadySubmitted, Busy and Malformed. S5 has no RemoteFunctions and its codes are E_TOO_EARLY, duplicate=true replies, E_SESSION_ACTIVE, E_BAD_REQUEST and E_INVALID_INPUT. (2) S-E2E-05 submits 'step duration + 200 ms' after StepStarted, ignoring S5's 3000 ms countdown, so E = D − 2800 < D − 250: E_TOO_EARLY plus a Hard strike. (3) S-E2E-04 expects 'blueprint count unchanged' for A01, A02, A06 and A08, but S1 and S5 store geometrically invalid WIP blueprints (valid=false). (4) S-E2E-10 expects 'extra fields ignored', but S5's Guard rec rejects unknown keys with E_BAD_REQUEST and a Hard strike. (5) S-E2E-04 plus S-E2E-10 produce well over 10 Hard strikes (each Guard rejection or sanitize failure is one), so HARD_STRIKES_KICK = 10 kicks the test player mid-suite. (6) S-E2E-11's 30 Saves in 1 s: S5's client self-throttles locally, so the server bucket is never reached, and the server answers at most 5 rate-limited replies per second, so most 'call's time out after 20 s. (7) 'An idle step past S5's timeout closes the session' is wrong: a step timeout scores 0 and the session continues; only Ready-idle beyond 120 s aborts.

**Evidence.** S8 §14.10.2: "call | {remote, payload} → the remote's response (InvokeServer)"; §14.10.4 S-E2E-05: "wait the step duration + 200 ms → call(SubmitStep)"; S-E2E-04: "blueprint count unchanged"; S-E2E-10: "Cheat-Forged → extra fields ignored"; S-E2E-11: "second StartCraft while one runs → Busy". S5 §10.1 "no RemoteFunction"; §7.P3 C = 3000; §1.2.1 note "WIP blueprints are stored even when invalid"; §10.4 "rec(fields) (unknown keys rejected)"; §10.7 "HARD_STRIKES_KICK = 10", "Replies to rate-limited requests ≤ 5 per player", "Client self-throttle"; §7.P6 "Step deadline | step s = 0, session continues".

**Proposed fix.** Rewrite S8 §14.10.2/§14.10.4 against S5. 'call' = NetClient.request(channel, action, args). Add a bridge command rawFire(channel, action, rid, args) that bypasses the client throttle for server-side limit tests. Code map: TooFast → E_TOO_EARLY; AlreadySubmitted → reply with duplicate=true; Busy → E_SESSION_ACTIVE; RateLimited → E_RATE_LIMITED, expecting ≤ RATE_LIMITED_REPLIES_PER_S replies per second and silence for the rest; Malformed or Forged → E_BAD_REQUEST or E_INVALID_INPUT. Submit after countdownMs + durationMs + 200 ms from the StartStep reply. Geometrically invalid fixtures expect a stored record with valid=false; only Guard or sanitize failures leave the count unchanged. Step timeout expects the StepTimedOut push and a continuing session. Add a Studio-only Config.STRIKE_KICK (false under the test bridge) or a bridge resetStrikes command, or run each hostile scenario in its own Play session. S5 lists these test hooks in §1.7.


### R5b-11 [major/testing] simulateRejoin cannot work against S5's lifecycle guards, and its 'wait for OnSessionEnd' can hang

Sections: S8, S5 | needsUserDecision: False | confidence: high

**Problem.** S8's simulateRejoin runs S5's leave path and then its join path with the same Player object. In S5's code, onPlayerAdded returns immediately because started[player] is still true. DataService.release sets leaving[player] = true permanently, so the next loadAsync(player) loads the Mock profile (Mock drops Cancel) and then hits 'if isGone(player) then profile:EndSession(); return "PlayerLeft"'. The rejoin never loads. Separately, the vendored ProfileStore fires OnSessionEnd synchronously inside EndSession, before its first yield, and clears ActiveSessionCheck at that same moment. A bridge that connects to OnSessionEnd after calling release waits forever. The 'already loaded in this session' error cannot occur once EndSession has returned.

**Evidence.** S8 §14.10.2 simulateRejoin: "waits `OnSessionEnd` ... The wait is mandatory: the vendored ProfileStore errors "already loaded in this session"". S5 §1.5: `if started[player] then return end`; S5 §9.L2: `leaving[player] = true -- set even when the load is still in flight` (never cleared) and the post-load isGone check. ProfileStore.luau 1090–1094 (EndSession → task.spawn(SaveProfileAsync)), 720–726 (RemoveProfileFromAutoSave then OnSessionEnd:Fire before UpdateAsync yields), 1390–1392 (error only while ActiveSessionCheck holds the token), 1272–1275 (Mock drops params).

**Proposed fix.** S5 adds a Studio-only, Config-gated hook Lifecycle.simulateRejoinForTest(player). It runs onPlayerRemoving(player), asserts not profile:IsActive() (true as soon as EndSession returns), clears started[player] and leaving[player], then runs onPlayerAdded(player) and returns the load result. S8's bridge calls it and drops the OnSessionEnd wait. Any test that must observe OnSessionEnd connects before calling release. S-E2E-09 then compares snapshots as planned.


### R5b-12 [major/platform] Remotes and Vendor declared only in default.project.json: S8's verified test project lacks them, and the workspace project would need copies

Sections: S5, S8 | needsUserDecision: False | confidence: high

**Problem.** S5 declares the 4 RemoteEvents and Vendor.ProfileStore as explicit children in default.project.json and forbids them on disk. Every other project that mounts the tree must therefore copy those children: S8's test.project.json and the user's combined ROBLOX/default.project.json. S8's 'verified' test project was built from S8's own prototype default tree, and it contains neither, so S5's boot (Remotes.assertPresent, require Vendor.ProfileStore) would fail in the Studio test place. Also, Studio caps StringValue.Value at 200,000 characters, and S8 maps goldens to StringValues.

**Evidence.** Command: rojo 7.7.0-rc.1 `build` of proto/S8/repo/test.project.json → out_test_s8proto.rbxlx: 0 RemoteEvents, 0 ProfileStore (grep count). A corrected test project (S5 tree + S8 additions) → 4 RemoteEvents and ProfileStore present, golden mapped to 'parity_digest.golden (StringValue)'. A self-contained alternative in review/R5b/rojo-alt/ (src/shared/Remotes.model.json, src/server/Vendor/ProfileStore.project.json with tree.$path '../../../vendor/ProfileStore/ProfileStore.luau') builds: Blacksmith.Remotes{4 RemoteEvent}, BlacksmithServer.Vendor.ProfileStore ModuleScript with the real source ('MAD STUDIO' found). Studio probe: "Provided string length (300000) is greater than or equal to max length (200000)".

**Proposed fix.** Make the tree self-contained on disk. Add src/shared/Remotes.model.json ({"className":"Folder","children":[{"name":"Profile","className":"RemoteEvent"}, ...]}) and src/server/Vendor/ProfileStore.project.json (a nested project pointing at vendor/; vendor/ stays untouched). default.project.json, test.project.json and the combined workspace then only map $path nodes. Rewrite S5 R7 accordingly and keep the sourcemap step with --include-non-scripts. If the lead keeps the static children, S8's test.project.json must be generated from default.project.json by a script, and the README must say the combined workspace project copies both children. S8: keep goldens read in Studio under 200,000 characters, or map them as .luau ModuleScripts returning the canonical string.


### R5b-13 [major/conflict] Two incompatible telemetry and logging designs; S8's raw DataStore sink breaks the 50-character key limit and has no retention

Sections: S5, S8, S1 | needsUserDecision: False | confidence: high

**Problem.** S5 defines Telemetry.log(player, event, value, f1?, f2?, f3?) over AnalyticsService with 11 events and closed-set string fields. S8 assumes Telemetry.log(event, payload) feeding a ring buffer with '[TLM] <json>' lines and a bridge 'telemetry' command, with 10 differently named events (StepCompleted vs StepScored, ItemCreated vs CraftCompleted, CraftAbandoned vs CraftAborted). S8 also wants a 'tid' GUID in Profile.Data, which S1's template lacks. Logging: S8's console hygiene greps '[Blacksmith][E]', but S5 prints '[blacksmith:<tag>] <event> k=v' with no level marker. S8's optional raw sink uses keys 'yyyy-mm-dd/<JobId>/<seq>': 11 + 36 + 1 = 48 characters before seq, so seq ≥ 100 gives ≥ 51 > 50 and DataStore error 102. DataStore entries never expire, so '90-day retention' needs a deletion job, and the storage counts toward the experience quota. Telemetry fields must also never carry raw client strings (for example an unregistered action), or the 8,000-combination budget gets polluted.

**Evidence.** S8 §14.13: "Assumes (S5): a server Telemetry.log(event, payload) with a ring buffer, [TLM] <json> output lines"; "key yyyy-mm-dd/<JobId>/<seq>"; "tid ... a GUID stored in Profile.Data". S8 §14.10.7: "game logs are prefixed [Blacksmith], with [E]". S5 §1.7 `Telemetry.log: (player, event, value, f1?, f2?, f3?)`; §1.9 "[blacksmith:<tag>] <event> key=value". python: len('2026-10-31/'+36-char GUID+'/100') = 51. Docs: key name max 50; custom fields: after 8,000 combined values, extra values are grouped as "Other".

**Proposed fix.** S5 owns one Telemetry module. Telemetry.log(player, event, value, f1?, f2?, f3?) feeds AnalyticsService aggregates, with field values only from closed enums (an unregistered action becomes 'Where - Unknown'). Telemetry.record(event, payload) keeps a Studio/playtest ring buffer (TELEMETRY_RING = 2000), echoes '[TLM] <json>' and serves the bridge. One event catalogue in S5 §10.12, carrying S8's analysis fields as record payloads. Drop the raw DataStore sink from the MVP. If the user wants it, use key '<yyyymmdd>/<first 8 hex of JobId>/<seq>' (≤ 32 characters), count its writes in S5's DataStore budget, and add an Open Cloud deletion job for retention. tid: either S1 adds TelemetryId to the template or a per-session random id is used. Logs carry the level: '[blacksmith:<tag>] <D|I|W|E> <event> k=v', with warn() for W and E. S8 greps '^%[blacksmith:%w+%] E '.


### R6-01 [major/gap] First session has dead ends and no guidance from join to the first forge

Sections: S6, S7, S1, S5, S8 | needsUserDecision: True | confidence: high

**Problem.** A new profile has 0 blueprints. The starter is created only when the editor opens. From the home pose neither the Draft prompt (13.7 studs) nor the Forge prompt (11.8 studs) is within its 7-stud activation distance. There is no tutorial or objective, and the HUD is unspecified. A player who walks to the anvil first gets the Choose screen as an empty card grid with only Select/Edit/Close, a dead end. An empty stand's "Display an item" prompt opens an empty item picker. S8's Definition of Done requires never-seen testers to finish the loop unaided in 20 minutes, and nothing in the spec supports that. S5 and S7 also disagree on the spawn model. S5 spawns the player on their own plot at PlayerAdded (RespawnLocation). S7 uses a plaza spawn, claims the plot after the profile loads, then teleports the player with PivotTo, so a newcomer first sees a plaza and a teleport pop instead of "your smithy".

**Evidence.** S1 §9 Template: "Blueprints = {}". S6 §11.3 opening table row 6: "if the player has 0 blueprints, create one from the starter template". S6 §12.2 Choose: "card grid 3 × n … Select (→ Overview), Edit, Close" (no empty state). S6 §15: "Guided tutorial (MVP: help overlay, status-bar hints, Intro panels)". S7 §13.4.2/§13.5.1: prompts at plot-local (−13.1, 4.0, 0) and (0, 3.8, 7.8) vs home HRP (0, 3.5, −4), MaxActivationDistance 7 (computed 13.71 / 11.80 studs). S5 §1.6 "Assignment | lowest free index, on PlayerAdded, before the profile loads" vs S7 §13.3.2 "The first spawn is the plaza SpawnLocation … when the plot is claimed the server teleports the character home". S8 §14.12.2 item 4.

**Proposed fix.** (1) S1/S5: seed new profiles at first load (Blueprints empty and Counters.BlueprintsCreated = 0) with one saved, valid "Starter Sword" (the all-Normal fixture of R6-02), so both entry points work and the first forge is a minute away. (2) S6: add empty states. Choose with no valid blueprint shows "No blueprint ready — [Open the drafting table]" (calls StationStage.enter(DraftingTable) directly). The item picker with 0 items shows "Forge a sword at the anvil first". (3) S6: add a dismissible 4-step "First steps" tracker in BS_Hud: open the drafting table, forge at the anvil, place the sword on a stand, visit a neighbour. Drive it from UiFlags "Onboarding.<n>" and add a client-side Highlight/Beam on the next station; about 150 lines, no new remote. (4) S5/S7: use one spawn model. Claim the plot at PlayerAdded and spawn the character directly at S7's home pose, so the sign shows the owner at once and the stands fill when the profile loads. (5) S5 telemetry: call AnalyticsService:LogOnboardingFunnelStepEvent for joined / editor opened / blueprint saved / forge started / item forged / item displayed, so the 20-minute Definition of Done criterion is measured.


### R6-02 [major/ux] The starter sword's first forge has two Hard steps (F1 with a steel blade measures Normal/Hard/Hard)

Sections: S6, S8, S2, S4 | needsUserDecision: False | confidence: high

**Problem.** S6's starter template is S8's fixture F1 ArmingSword, whose blade and tip are Steel. Run through S2's prototype, F1 plays Normal/Hard/Hard, not S8's intended Normal/Normal/Hard. Every new player's first forge, on minigames they have never seen, therefore includes two Hard steps. In S4's model an average player fails at least one step in 84% of such crafts (44% Common). S3's poor bot fails about 50% of Hard TimingStrike and 57% of Hard Trace steps. The same sword with an Iron blade plays all Normal with a 0.04 margin.

**Evidence.** S6 §11.20: "Assumes (S1/S8): the starter sword is a fixture blueprint (S8's reference 'ArmingSword')". S8 §14.7.2 F1 rows 4–5: "Blade | Block | Steel". S8 §14.7.4: "F1 ArmingSword | Normal | Normal | Hard". Command `lune run review/R6/protoS2/r6_starter.luau` (S2 prototype) prints "S8 F1 ArmingSword (blade Steel) Smelting D=0.126 Normal | Hammering D=0.242 Hard | Sharpening D=0.244 Hard", "(blade Iron) 0.029 / 0.157 / 0.160 Normal" and "S8 F2 MinimalSword 0.080 / 0.039 / 0.082 Normal". S4 §8.5.3: "Average | Mixed-2 (Ham+Sharp H) | 44 / 49 / 7 / 0 … 84 / 90".

**Proposed fix.** S8 adds fixture F5 "Starter": F1 with an Iron blade and tip, intended Normal/Normal/Normal. T-DIF-11 asserts every step D ≤ Hard.DMin − 0.03 with S2's final numbers. S6 uses F5 for the seeded starter (R6-01) and for "New ▾ Starter sword". After the first item, a one-time S6 hint (or the Steel swatch tooltip) says: "A Steel blade makes Hammering and Sharpening Hard and unlocks the Epic cap". S8 reconciles §14.7.4 with S2's measured tiers (F1 measures N/H/H).


### R6-03 [major/numbers] At the 0.50 pass line fail rates are High, not the draft's Low/Medium, and three sections define "Medium" differently

Sections: S3, S4, S8 | needsUserDecision: True | confidence: high

**Problem.** S3 says a 0.50 pass line matches Low/Medium, yet its poor bot (which S4 shows plays like S4's average player) fails 49% of Hard TimingStrike and 57% of Hard Trace steps. S4's average profile fails 18.6% of Normal and 60.6% of Hard steps, and S4 flags this itself. S8's bands need Average pass rates of 85–97% at Normal and 60–85% at Hard, which S4's model misses at Hard. For an average player 42% of all-Normal crafts and 90% of all-Hard crafts carry a FAILED stamp. With φ = 0.75 and the lost cap, Hard feels punishing. S4 already shows that a lower pass line keeps every rarity target.

**Evidence.** S3 §6.5.3: "This matches the draft's failure risk of 'Low' on Normal and 'Medium' on Hard". S3 §6.12.2: TS Hard "poor | 0.500 [0.373–0.620] · 51.0%", PT Hard "poor | 0.483 … · 42.7%". S4 §8.5.1: "Average 18 % / 60 % … higher than the draft's 'Low' (Normal) / 'Medium' (Hard)". S8 §14.8.3 Average row: "85–97 % ('Low') | 60–85 % ('Medium')". review/R6/failrates.py: S4 average Iron fails Normal 18.6% / Hard 60.6% at 0.50 and 3.7% / 26.6% at 0.40 (Steel 6.4% / 36.0%); S3 poor TS Hard 15% and PT Hard 20% at 0.40. Re-run of S4's sim (review/R6/protoS4, PASS=0.40; out_s4_passline.txt): crafts with a fail, Average All-Normal Iron 42% → 10%, Mixed-2 84% → 45%, All-Hard 90% → 55%; Commons 21% → 12%; all 12 targets still OK.

**Proposed fix.** S3 sets passThreshold = 0.40 for Normal and Hard (data only; the per-tier shape is already allowed), marked [Decision to confirm]. The HIGH-flag clamp follows the new value. S8's bands become the single definition of Low/Medium (S8 owns it). S3 drops or re-justifies its "matches Low/Medium" claim against S8's Average profile. S4 republishes §8.5.3 at 0.40; Hard stays a gamble for average players (mean Q 0.60 → 0.56).


### R6-04 [major/fidelity] In the MVP, boldness beyond the Hard threshold is pure cost, so the best sword sits just above D = 0.2

Sections: S3, S4, S2, S6 | needsUserDecision: True | confidence: medium

**Problem.** Rewards depend only on the tier: d = 1.25 and the Epic cap apply to any D ≥ 0.2. S3's m_design, however, makes each geometric factor harder within a tier, and within Normal too. For a good player a maximally bold Steel design scores about 0.08 lower on TimingStrike, 0.05 on HoldZone and up to 0.13 on Trace than a just-Hard one. That is about 0.12 Q, more than half a rarity band (Rare 0.72 → Epic 0.92). With live D values and the factor breakdown, players will min-max to "Hard by a hair". For example, moving the iron starter's guard 0.1 stud sideways flips Hammering from 0.157 to 0.202. This contradicts the draft: "ambitious drafts unlock higher rarity caps, so players are pushed toward bold designs".

**Evidence.** S3 §6.5.1: "The design counts twice, on purpose … m_design adds continuous variation inside a tier". S3 §6.12.3, good bot: TS Steel 0.707 vs all factors 1: 0.626; HZ Steel 0.684 vs Volume 1: 0.635; Trace Steel 0.801 vs flamberge, all factors 1: 0.671. S4 §8.3.4: d per tier only. S4 §8.4.2: cap from tiers only. review/R6/out_starter.txt: "F1 Iron + guard shifted +0.1 x only … Hammering D=0.202 Hard". design-draft "Consequences for design".

**Proposed fix.** The designer picks one. (a) MVP default: neutralise m_design (every designClamp = {1, 1}, S3 data only), so a tier plays the same at any D and design is priced only through the tier until Phase 2 adds finer tiers. (b) Reward D inside the tier: d_i = d(tier_i)·(1 + γ·(D_i − DMin(tier_i))), with γ tuned in S4's sim so a good player's expected Q does not fall as D rises (S4 owns; thresholds re-checked). Either way, S6's preview tooltip states what extra difficulty buys.


### R6-05 [major/platform] TimingStrike scores depend on frame rate and hidden display latency; there is no calibration and, in the MVP, no audio cue

Sections: S3, S6, S1, S5, S8 | needsUserDecision: False | confidence: medium

**Problem.** Perfect is ±18 ms at Normal and ±15 ms at Hard, with a ±9.6 ms full-points core. Press times are os.clock() read in the input handler, so they are quantised to the frame (InputObject has no timestamp). The player times against a frame that was rendered 1–3 frames earlier. S3's bots model a 60-fps snap and a small bias, but no render latency and no 30 fps. Simulating S3's points rule (S3's 'good' σ, 25 ms): an uncompensated +20 ms costs 0.11 points per strike and +40 ms costs 0.31 at Normal. At Hard the score drops 0.79 → 0.65 → 0.42, which is a fail. Running at 30 fps costs another 0.05–0.09. With the MVP silent, the visual is the only cue.

**Evidence.** S3 §6.9.3 grade table (Perfect ±18 / ±15 ms). S3 §6.9.6: perfectFrac 0.12. S3 §6.6: "t = floor((os.clock() − goClock) · 1000) taken in the input handler". S3 §6.12.1: "bias 0 / +5 / +15. Presses snap to the next 60 fps frame". Creator Docs InputObject: no time property. S7 §13.12.5: "the MVP ships silent". review/R6/ts_latency.py → out_ts_latency.txt: "Hard good s25 | 60fps b+0: 0.793 | b+20: 0.649 | b+40: 0.416 | 30fps b+0: 0.736".

**Proposed fix.** (1) S3's input layer subtracts a per-player TimingOffsetMs (−120…+120, default 0) from TimingStrike press times before encoding, clamped at 0. The server and anti-cheat need no change: a constant shift leaves TS_LowVariance and TS_ExactHits unchanged. S1 adds the field to the settings record and S5's SetSettings guard is sized for it. (2) S3 adds a signed meanErrMs to the breakdown. S6's StepResult shows "On average 31 ms late" with a [Use −31 ms offset] button. (3) S3 re-runs its bots with +25 ms render lag at 60 and 30 fps and tunes W/perfectFrac so S8's Average band holds at 30 fps. S8 adds a 30-fps profile to the T-MG bot tests. (4) R6-06 brings back the CycleStart tick.


### R6-06 [major/scope] The MVP ships with no audio, so the minigames, forge and reveal are silent

Sections: S6, S7, S3 | needsUserDecision: True | confidence: high

**Problem.** Audio is deferred to Phase 2 because "audio needs asset ids". As a result the countdown tick, metronome, anvil clang per grade, bellows, grind loop, pass/fail sting and rarity reveal are all silent. S3's feel contract and S6's FeedbackEvent mapping are built around these cues, and the phase exit criterion is "fun in playtests". The client's built-in sounds are 11 generic avatar sounds, so the asset-free route cannot cover this. The Creator Store, however, has free-to-use audio made by Roblox and its partners: no upload is needed, and the ids are plain data.

**Evidence.** S7 §13.12.5: "Audio needs asset ids, so the MVP ships silent … Phase 2 fills them from Roblox's licensed audio library (no uploads)". S6 §12.7: "the MVP ships without uploaded assets … silent if unmapped". S3 §6.11: "a tick sound per number". `ls C:/Users/louis/AppData/Local/Roblox/Versions/*/content/sounds` lists 11 files (action_falling.ogg … oof.ogg, volume_slider.ogg). Creator Docs audio/assets: "free-to-use audio assets made by Roblox … more than 100,000 professionally-produced sound effects".

**Proposed fix.** Fill about 12 MVP cues with Roblox-published Creator Store sound-effect ids in a data module, Definitions/Audio.luau ({hook, id, volume, pitchRange}; an empty id stays legal and silent). Cues: Go, CountdownTick, CycleStart, Strike Perfect/Good/Ok, Miss, Bellows, FurnaceLoop, GrindLoop, Pass, Fail, RarityReveal, UI Click. Add one SoundGroup "SFX" with a volume slider in settings. Every cue keeps its visual counterpart (no information carried by sound alone). The game still lives in git, since only ids are stored and nothing is uploaded.


### R6-07 [major/ux] Inputs assume a 3-button mouse and long LMB drags, which penalises trackpad and one-handed PC players

Sections: S3, S6, S8 | needsUserDecision: False | confidence: high

**Problem.** Sharpening carries 35% of Q and requires holding LMB while tracing for 6–30 s (longsword 14.3 s, flamberge 19.1 s); releasing gives no credit. HoldZone and TimingStrike accept Space or LMB, but Trace accepts only LMB. The editor orbits with an RMB drag and pans with an MMB or Shift+RMB drag. On a laptop trackpad a precise 15-second click-drag is hard, so those players will score lower on Sharpening and fail its Hard step more often. S3 lists remapping as a non-goal.

**Evidence.** S3 §6.10.6: "Grind | Hold LMB and drag along the path. Releasing lifts the blade: no credit". S3 §6.10.2 table (travel 14.3 s / 19.1 s at Normal). S6 §12.3.2: "PrecisionTrace hold LMB to grind". S6 §11.5: "RMB drag | orbit", "MMB drag, or Shift+RMB drag | pan". S3 §15: "accessibility remapping beyond the two bound keys" (non-goal).

**Proposed fix.** (1) S3: Trace grinds while LMB OR Space is held (a logical OR, as in HoldZone). The grind flag is already recorded by the client, so anti-cheat is unaffected. (2) S6 setting "Grind: hold / toggle" (toggle = press once to put the blade on the stone). (3) S6 editor: dragging the view triad orbits; Space+LMB drag orbits and Space+Shift+LMB drag pans. Space is free in the editor; Alt is already taken by select-through and the marquee. (4) The Intro KeyHints show both bindings. (5) S8 adds manual check M-08 on a laptop trackpad: finish a Normal Trace at ≥ 0.5 and orbit/pan the editor.


### R6-08 [major/ux] Connectivity errors get no live feedback or quick fix, and "main component" has two definitions

Sections: S6, S2 | needsUserDecision: False | confidence: medium

**Problem.** CONTACT_TOL is 0.01 stud, and a 0.01–0.03 gap is 2–7 px at frame-all. Free transforms make such gaps easy: typing a smaller guard size, a symmetric Ctrl-scale, a relative-snap move. The editor checks connectivity only in the debounced full analysis, never during drags (S2 proposes ≤ 10 Hz while dragging). The issue row only says "Make them touch or overlap another part". S2 picks the main component by largest volume, S6 by "the component that contains the Grip". When a large blade is detached from the hilt, the server lists the hilt parts as Disconnected while the editor outlines the blade.

**Evidence.** S2 §4.2 V5: "contact iff their Euclidean distance is <= CONTACT_TOL = 0.01". S2: "Main component = the component with the largest total analytic volume". S2 §4.7: "Client, connectivity | V5 at ≤ 10 Hz while dragging". S6 §11.18.1: quick = counts, slots, containment, sizes; analyze runs in the scheduler. S6 §11.19.1: "During a drag the panel keeps the last result dimmed". S6 §11.18.3: DISCONNECTED row; "'the sword' is the component that contains the Grip (else the largest by volume)". S6 §11.4.1: 220.6 px per bp stud at frame-all.

**Proposed fix.** (1) S2 adopts one rule: the main component is the one with the most Grip volume, else the largest volume. Gjk/Analyze return, for each floating component, its closest-point pair (distance and unit direction). (2) S6 adds a "Snap to touch" quick fix on the Disconnected issue row and in the context menu. It moves the floating component along that direction by (distance − CONTACT_TOL/2) as one undoable command. (3) S6 runs V5 on the dragged parts at ≤ 10 Hz during drags (about 0.1 ms) and updates the floating outline live. (4) The message names the gap, e.g. "Pommel floats 0.02 studs from the Grip".


### R6-09 [major/ux] No autosave: a crash, disconnect or shutdown loses all editor work since the last manual save

Sections: S6, S1, S5 | needsUserDecision: True | confidence: high

**Problem.** The editor never autosaves; it only shows a reminder toast after 300 s. Building sessions of 10–30 minutes are normal, and client crashes, network drops and server restarts happen. S6 reasons that autosave would need an S1 draft slot and an S5 remote. In fact invalid work-in-progress blueprints can already be saved, and Blueprint.Save is an upsert, so periodically saving the open record needs nothing new.

**Evidence.** S6 §11.20: "Unsaved-work guard | no autosave in the MVP (neither S1 nor S5 has a draft slot …)". S6 §17 Q4. S5 key decision 14: "blueprint ids are client-minted GUIDs, so Save is an upsert". S5 rate table: Blueprint.Save bucket of 4 tokens, refilling 1 per 3 s. S5 key decision 16: explicit profile saves coalesced to ≤ 1 per 10 s.

**Proposed fix.** S6 autosaves the open blueprint every AUTOSAVE_S = 60 s while it is dirty, never during a drag and only after 2 s without edits, through the normal Blueprint.Save. Work-in-progress saves are allowed, and a never-saved document is created under its default name. The top bar shows "Saved 12 s ago". On exit, "Discard changes" re-saves the last manual version, which the client keeps in memory for the session. Cost is ≤ 1 save per minute per editing player, within S5's buckets and the AnalysisQueue. [Decision to confirm]: overwrite in place (default) or keep a separate recovery copy (would need an S1 slot).


### R7-04 [major/architecture] S5's module tree (§1.3) and dependency graph (§1.4) do not match the modules the owners define

Sections: S5, S1, S2, S3, S4, S6, S7, S8 | needsUserDecision: False | confidence: high

**Problem.** S5's tree lists modules no owner defines and leaves out most of those they do. Blueprint/{Types, Sanitize, Serialize, Names}: S1 defines Schema, Canonical, Quat, Names, Views, and S2 adds Geometry. Physics/{Voxelize, Clean, Mass, ...}: S2 defines Shapes, Gjk, Sampling, MassProps, Edge, Factors, Difficulty, Analyze, with no voxelizer. Minigames/{Rng, Registry, ...}: S3 defines Minigames, Types, Rng, Params, Timeline, Checks and the families. Crafting/{Plan, Outcome, Item}: S4 has no Item module. Persistence/{Template, Migrate, Types}: S1 defines Types, Template, Migrations, Prepare, JsonSafe, Ids, Quantize. Items/ is missing. Server World/{WorldBuilder, Plot, Stations, ItemModel, Display}: S7 defines server World/{WorldBuilder, PlotWorld} plus shared World/Layout, ItemRender/*, Showcase/* and Definitions/{World, Presentation}. Client Inventory/ and Input/, the S7 Smithy/* modules, and Definitions/{Types, Catalog, Versions, Limits, Stats, Validate, CraftPlans} are all absent. The §1.4 graph also draws Crafting → Physics, which S4 forbids. The merged §1 is the only place a developer sees the whole system, and as written most of its rows are wrong.

**Evidence.** S5 §1.3 tree rows quoted above. S1 §2.3, §3.8, §9.3–9.6. S2 §4.8: 'Physics/Analyze.luau (pure; orchestrates Shapes, Gjk, Sampling, MassProps, Edge, Factors, Difficulty)'. S3 §6.2 layout. S4 §8.6.2 module list and §8.6 'Crafting never requires Physics code'. S7 §13.1 module table. S6 §11.2 tree.

**Proposed fix.** Replace S5 §1.3 with a merged inventory (P = pure and Lune-tested, RB = Roblox-bound, owner in brackets).

src/shared → ReplicatedStorage.Blacksmith:
- Definitions/{Types, Catalog, Versions, Limits, Materials, EquipmentTypes, Steps, Tiers, Rarities, Stats, Balance, Validate} [S1 shapes; S2/S3/S4 values] P; Definitions/MinigameFamilies [S3] P; Definitions/CraftPlans [S4] P; Definitions/Network [S5] P; Definitions/{World, Presentation} [S7] P.
- Util/Quantize [S1, moved from Persistence] P; Util/Signal [S5] RB.
- Blueprint/{Schema, Canonical, Names, Views} [S1] P; Blueprint/{Quat, Mirror} [S2] P; Geometry removed.
- Physics/{Shapes, Gjk, Sampling, MassProps, Edge, Factors, Difficulty, Analyze} [S2] P.
- Minigames/{Minigames, Types, Rng, Params, Timeline, Checks, Input, HoldZone, TimingStrike, PrecisionTrace} [S3] P.
- Crafting/{Types, Plan, Quality, Rarity, Stats, Outcome} [S4] P.
- Pipeline [S2+S4] P (R7-05).
- Items/{Schema, Create, Recompute} [S1] P.
- Persistence/{Types, Template, Migrations, Prepare, JsonSafe, Prefs} [S1] P.
- Session/SessionMachine [S5] P.
- EditorCore/{EditorState, Commands, History, Snap, Rotation, GizmoMath, Expr, EditorLayout} [S6] P.
- World/Layout, ItemRender/RenderPlan, Showcase/{ShowcaseRules, InspectView} [S7] P; ItemRender/ItemModelBuilder [S7] RB.
- Net/{Protocol, Guard, RateLimit} [S5] P; Net/{Remotes, Client} [S5] RB.
- Remotes folder with 4 RemoteEvents, declared in default.project.json.

src/server → ServerScriptService.BlacksmithServer (all RB): Main.server, Lifecycle, Config, Log, Telemetry, Safe, TextFilter, Router, Handlers, DataService, BlueprintService, AnalysisQueue, CraftService, PlotService [S5]; ShowcaseService, World/{WorldBuilder, PlotWorld} [S7]; Vendor.ProfileStore (project mapping).

src/client → StarterPlayerScripts.BlacksmithClient (all RB): Main.client, UI/*, Input/*, Editor/* (controllers, stage, gizmos, panels, PreviewScheduler), Forge/*, Minigames/{MinigameHost, InputCapture, views}, Inventory/* [S6]; Smithy/{PromptController, StationStage, StationFx, InspectPanel, PlotPresence} [S7].

tests/: one folder per src/shared folder plus Meta/, lib/ (requires nothing in src/), fixtures/, golden/, studio/{bridge, e2e}; plus scripts/verify.luau and tools/.

Layers, each requiring only lower ones: Definitions → Util → Blueprint → Physics → Minigames/Crafting → Pipeline → Items/Persistence/Session/EditorCore/Showcase/ItemRender → server services and client controllers (RB). S5 owns this section; each owner confirms its rows during revision.


### R7-05 [major/architecture] No single shared pipeline function; preview and authority assemble the S1→S2→S4→S3 calls separately, and the S2→S3/S4 hand-offs are undefined

Sections: S2, S3, S4, S5, S6, S1, S8 | needsUserDecision: False | confidence: high

**Problem.** Preview equals authority only if both run one code path, but every caller composes the steps itself. S6's preview: 'Physics.analyze(doc) → Plan.build → Quality.ceiling/Rarity.planCap'. S5's Save: 'Sanitize.fromWire → AnalysisQueue(Analyze.run)'. S5's Begin: prepareForCraft, then Plan.build. S4's recompute: Plan.fromHistory plus physics from the snapshot. S2's Analyze.run needs (parts: {PartGeom}, rules: GeometryRules, defs: DifficultyDefs, balanceVersion, opts) built from Definitions, and nobody owns that construction; S5's queue job takes only (S1.Blueprint). The data hand-offs are undefined. (a) S3's m_design needs PartCount for TimingStrike and Thinness for PrecisionTrace. S2 exposes factor values only as StepDifficulty.terms, which hold only the factors weighted for that step: Hammering = Thinness/Asymmetry/SC, Sharpening = EdgeLength/Asymmetry/SC. (b) S3 wants SharpenableEdge {sides: base→tip polylines of {x,y} arrays}. S2 emits EdgeProfile.chains: one CCW loop of Vec2 records running 'up the right edge, over the tip, down the left edge'. (c) The governing material is computed twice: S2's m_s = max over W_s, and S4's mat_s = argmax with its own tie rule. (d) S4's DifficultyInputs uses {[StepId]: {difficulty, tier}} while S2 emits a steps array, and S4's PhysicsInputs {mass, reach, balanceOffset, edgeLength, kept, partVolumes} does not match S2's MassProps/EdgeProfile/PartReport names. (e) S6 assumes Validate.quick and Geometry.partExtents; S2 offers Analyze.validate (which includes V5 GJK) and partAabb. (f) S5 caches the full S2 Analysis on the blueprint record, while S1 budgets a compact BlueprintAnalysis. (g) Plan.build asserts #W > 0, so the preview errors on any work-in-progress blueprint that has no Blade.

**Evidence.** S6 §11.19.1 step 2 and §11.18.1. S5 §1.2.1–1.2.2; §1.7 'AnalysisQueue.run: <T>(job: (S1.Blueprint) -> T, ...)' and 'SaveData = { ..., analysis: S2.Analysis? }'. S2 §4.8 (Analyze.run signature, StepDifficulty.terms, Analysis fields). S3 §6.9.6 strikes 'PartCount +0.5' and §6.10.7 halfWidth 'Thinness −0.15', against S2 §5.4's weights. S3 §6.2 EdgePolyline: 'from the blade base (guard side) to the tip'; S2 §4.6 item 5. S4 §7.3 ('assert #W > 0', 'mat ← argmax ...') and §8.6.1. S1 §3.2 BlueprintAnalysis.

**Proposed fix.** Add src/shared/Pipeline.luau (pure; owner S2, co-owner S4). It is the only composition used by S6's PreviewScheduler, S5's BlueprintService and CraftService (as the AnalysisQueue job), recompute (R7-18) and S8:
- Pipeline.analyze(core, opts?) → Report. It asserts Canonical.isCanonical, runs Analyze.run with rules/defs built from Definitions (work sets from CraftPlans) and the current BALANCE_VERSION, then, only when validation is ok, runs Plan.build and the preview (rarityCap, qualityCeiling).
- Pipeline.quick(core) runs V1–V4 only, for the editor on every edit.
- Pipeline.summary(report) → S1's compact BlueprintAnalysis; Blueprint.Save stores and returns only this.
- Pipeline.stepInput(report, stepIndex, seed) → Minigames.PrepareInput.
S2's Analysis gains three things: physics: PhysicsReport = {mass, reach, balance, edgeLength, kept: {boolean}, ownedVolume: {number}}, a flat record whose names S4, S6 and S7 use; factorsByStep: {[StepId]: {FactorValue}} with all 8 factors on each working set; and a per-step material (argmax of forgeDifficulty, ties by Materials order, i.e. S4's rule, computed once and copied by Plan.build). S3 owns the edge conversion, PrecisionTrace.sidesFromChains(chains, gripPoint, axis): split the main chain at its point farthest along the axis and reverse the left side. Physics/Shapes exports aabb(part), replacing S6's Geometry.partExtents. T-DIF-10 becomes a Lune test of Pipeline.analyze, plus the Studio comparison in S-E2E-03.


### R7-06 [major/conflict] Definitions data layouts break consumers' determinism rules and define the same data twice

Sections: S1, S2, S3, S4, S8 | needsUserDecision: False | confidence: high

**Problem.** (1) S1 stores per-step factor weights and reference ranges as dictionaries keyed by FactorId. S2 requires every iterated table to be an array, and S8's T-META-04 forbids float sums over dictionary iteration, because the summation order would follow hash order, which can differ between the Lune and Roblox Luau builds. (2) Work sets are defined three times, with different values: S1's StepDef.AppliesTo ('the single source of truth'; Hammering = Blade, Guard, Pommel), S4's CraftPlans.worksOn ('kept once'; Hammering = all kept parts), and S2's StepRule.workingSet (Hammering = all). (3) Step weights are defined twice: S1's StepDef.QualityWeight and S4's CraftPlans weight. (4) Minigame modifiers are defined twice: S1's Materials.FamilyModifiers + Tiers.FamilyMultipliers + Families.BaseParams, and S3's per-family table with material/tier columns per parameter. (5) The MVP tier clamp is defined twice: S1's tierFor over the enabled tiers, and S2's maxPlayableTier. (6) S4 iterates order lists MaterialOrder/TierOrder/RarityOrder that S1 does not export (S1 exports Catalog.Ordered/Enabled), and reads fields named qualityTier, qualityMultiplier, minQuality and rarityCap, while S1's records use QualityMultiplier, QMin and RarityCap.

**Evidence.** S1 §2.4: 'FactorWeights: { [FactorId]: number }', 'ReferenceRanges: { [FactorId]: FactorRange }', FamilyModifiers, FamilyMultipliers. S2 §4.1: 'weights and tables that are iterated are arrays'. S2 §4.8: 'weights: { { factor: FactorId, w: number } }', 'refs: { RefRange }', maxPlayableTier. S8 §14.4 T-META-04. S1 §2.7 table and 'AppliesTo is the single source of truth'. S4 §7.2: 'the merged spec keeps them once, in Definitions/CraftPlans'. S3 §6.5.2: 'The material and tier columns sit inside the family table'. S4 §8.6: 'fixed order lists of Definitions (MaterialOrder, TierOrder, RarityOrder, assumed from S1)'. S4 §8.6.3 field names.

**Proposed fix.** Ruling: S1 owns the data layouts but adopts the consumer's layout wherever the consumer's algorithm depends on it.
- Weights and reference ranges become arrays, {{factor, w}} and {{factor, lo, hi}} in FactorId order (S2's layout), on EquipmentTypes.Sword.geometry (GeometryRules) and on Steps.
- Work sets, step order, quality weights and stat feeds live only in Definitions/CraftPlans (S4). S1's StepDef drops AppliesTo, QualityWeight and MainStat. Pipeline fills S2's StepRule.workingSet from CraftPlans, so Physics never requires Crafting.
- Minigame data lives only in Definitions/MinigameFamilies, as S3's MinigameFamilyDef. Remove S1's FamilyModifiers, FamilyMultipliers and BaseParams.
- The clamp is S1's enabled-prefix rule. S2 reports tierRaw over all tiers and tier over the enabled ones; maxPlayableTier is removed.
- Iteration order is Catalog.Ordered; S4 replaces MaterialOrder etc. S4's values keep their meaning under the field casing chosen in R7-07.
S8 adds P-ORDER for Definitions: rebuild them with shuffled insertion order and require bit-identical analyses and outcomes.


### R7-07 [major/conflict] Record types defined several times with different casing and vector layouts

Sections: S1, S2, S3, S4, S5, S6, S7 | needsUserDecision: False | confidence: high

**Problem.** The same entities have incompatible type definitions. A part is S1's PartData {Id, Slot, Shape, Material, Pos {x,y,z} array, Rot {qx,qy,qz,qw}, Size}, S2's PartGeom {shape, slot, material, position {x=,y=,z=}, rotation {w,x,y,z}, size}, and S7's PartView {shape, slot, material, pos, rot, size}. S4 reads blueprints as {equipmentType, parts[].slot/material} and relies on width subtyping 'without a require'. That fails against S1's {Type, Parts[].Slot}: --!strict rejects S1's records, and at runtime blueprint.equipmentType is nil. BlueprintSummary and ItemSummary are defined by S1 and again, with other fields, by S5's Net/Protocol. Id unions are redefined by S2 (ShapeId, SlotId), S3 (FamilyId with 3 values against S1's 6; TierId, MaterialId, FactorId) and S4 (as plain strings). Issue codes differ too: S6 keys its messages on S2's prototype codes (OUT_OF_HITBOX...), while S2's API uses OutOfHitbox... S1 uses PascalCase fields; S2–S7 and the user's Combat System use camelCase.

**Evidence.** S1 §3.2. S2 §4.8 PartGeom/Vec3/Quat. S7 §13.8.6 PartView. S4 §8.6.1 BlueprintInputs and §8.6 'their full types pass by width subtyping without a require'. S5 §10.4 BlueprintSummary/ItemSummary against S1 §3.2 and §9.4. S3 §6.2 Types. S6 §11.18.3 code table against S2 §4.8 ValidationCode. Combat System src/client/InputReader.luau builds intents as { type = ..., direction = ..., intensity = ..., timestamp = ... }.

**Proposed fix.** Each type has one owner, and nobody else redefines it. Ids → Definitions/Types (S1). PartData/Blueprint* → Blueprint/Schema (S1). ItemRecord/StepRecord → Items/Schema (S1). Summaries and their builders → Blueprint/Views and Items (S1). InspectView → Showcase/InspectView (S7). Analysis/PhysicsReport → Physics/Analyze (S2). StepSpec/MinigameResult → Minigames/Types (S3). CraftPlan/Outcome → Crafting/Types (S4). Wire-only types (ErrorCode, Response, SessionView, StepOpenView, StepResultView, ProfileSnapshot) → Net/Protocol (S5), which re-exports the other types instead of copying them. Casing: camelCase for every plain-data field, the user's Combat System style and already used by 6 of 8 drafts; S1 renames to id, slot, shape, material, pos, rot, size, and so on. Id values stay PascalCase strings. Vec3 = array {x, y, z} and Quat = array {qx, qy, qz, qw} everywhere (S1's measured JSON sizes assume arrays); S2's math reads arrays. Issue codes are S2's ValidationCode strings, and S6's message table is keyed by them. The lead may choose PascalCase instead; what matters is a single rule.


### R7-08 [major/gap] The item record has three shapes and no module owns its constructor

Sections: S1, S4, S5, S7, S8 | needsUserDecision: False | confidence: high

**Problem.** Three drafts each define the item record. S1's ItemRecord has Steps: {StepRecord {Step, Family, Tier, D, Seed, Score, Passed, DurationMs, Flags}}, AtForge, Geometry, Physics, Stats, Quality, Rarity, RarityCap. S4 expects its CraftRecord {balanceVersion, steps: {CraftStepRecord {step, tier, difficulty, material, seed, score, passed, timedOut, durationMs}}, outcome: StoredOutcome} to be 'embedded as craft'. S5 finalizes with Crafting.Item.create({id, name, blueprint, analysis, steps, outcome, createdAt, balanceVersion}), but S4 defines no Item module (it has Outcome.record) and S1 has only Recompute.applyOutcome. S5's session StepResult {index, stepId, tier, seed, score, pass, timedOut, lateSoft, flags} is a fourth step shape. The fields disagree: material and timedOut appear only in S4, Family only in S1, capStep and rarityByScore only in S4. S7's InspectView.fromItem reads Physics.BalanceOffset, but S1 names it BalancePoint.

**Evidence.** S1 §9.4 ItemRecord/StepRecord. S4 §7.6: 'Assumes (S1): S1's Item record embeds this record as craft'. S5 §7.P5 step 2: 'item = Crafting.Item.create({...}) -- S1/S4, pure'. S4 §8.6.2 module list. S1 §9.6 Recompute.applyOutcome. S5 §7.P8 StepResult. S7 §13.11.3 Assumes (S1) list. S1 §3.2 PhysicsSummary {Mass, BalancePoint, Reach}.

**Proposed fix.** S1 owns src/shared/Items/Create.luau (pure): Create.fromCraft({id, name, crafterUserId, createdAt, snapshot, plan, runs, outcome, physics, balanceVersion}) → ItemRecord. There is one StepRecord: {step, family, tier, difficulty, material, seed, score, passed, timedOut, durationMs, flags}. There is one stored outcome block, S4's StoredOutcome {stats, quality, materialTier, rarity, rarityByScore, rarityCap, capStep?}. Create.fromCraft replaces S4's Outcome.record. S5's session result type is S4's StepRun plus flags, and S5 §7.P5 calls Create.fromCraft. S7's InspectView.fromItem reads only these names (physics.balance). S8's T-CR-07 and S-E2E-07 assert the merged field list.


### R7-09 [major/conflict] DataService's load code bypasses S1's load pipeline and disagrees on ids, store names and data layouts

Sections: S1, S5, S6, S7 | needsUserDecision: False | confidence: high

**Problem.** S1's load pipeline is Prepare.run: migrate, then its own reconcile, repair/quarantine, stale detection and the JsonSafe check. S1 adds that S5 'never calls profile:Reconcile() itself'. S5's DataService instead calls Persistence.migrate(profile.Data), then profile:Reconcile(), then Persistence.checkStorable, which S1 names JsonSafe.check. So S1's repair and quarantine never run. Ids: S1 mints 'B<n>'/'I<n>' from NextIds counters. S5's idempotency relies on client-minted GUIDs (Save is an upsert) and uses the session GUID as the item id; its Guard validates GUIDs. Store and key: S1 uses 'PlayerData' / 'User_<UserId>', S5 'Blacksmith_PlayerData_v1' / 'Player_%d'. Displays: S1 stores a keyed map {D1..D6 → ItemId}; S5 assumes a dense string array. Settings: S5 guards Profile.SetSettings as 'plain, ≤ 32 keys of numbers/booleans', but S1's EditorPrefs is nested (Snap/Presets/Overlays) and S6 adds fields (S6 counts about 75 values).

**Evidence.** S1 §9.6: 'S5 calls it right after StartSessionAsync and never calls profile:Reconcile() itself'. S5 §9.L2 code: 'local ok, why = Persistence.migrate(profile.Data)' ... 'profile:Reconcile()'. S5 §9.L7: 'Persistence.checkStorable(data)'. S1 §2.2 rule 3. S5 §7.P7: 'upsert by client-minted GUID'. S1 §9.1 against S5 §9.L1 and §16. S1 §9.3 SmithyData against S5 Appendix A. S5 §10.10 SetSettings row. S6 cross-section notes, 'Settings size'.

**Proposed fix.** S1 owns the profile contract and S5 owns the lifecycle. DataService calls Prepare.run(profile.Data, {displaySlots = the World layout's slot ids}) right after AddUserId and never calls profile:Reconcile(). Status Newer → EndSession and kick (S5's existing path); status Corrupt → read-only session plus telemetry. Ids are GUIDs for blueprints and items, which gives S5 idempotency without a request cache (item id = session id); S1 drops NextIds, Ids.luau and the B<n> patterns (+≈ 30 B per id, under 1 % of the budget). One store/key pair lives in Definitions/Limits: S1's values ('PlayerData', 'User_<UserId>', Roblox best practice) unless the lead prefers S5's _v1 wipe switch. S5 removes STORE_NAME/PROFILE_KEY_FORMAT from Network. The stored displays keep S1's keyed layout, and ProfileSnapshot.displays is ShowcaseRules.fromStore(...). Settings: S1 adds Persistence/Prefs.sanitize(raw) → EditorPrefs (S1 §9.3 clamps plus S6's fields), which the SetSettings handler calls; the Guard only bounds depth and node count.


### R7-10 [major/architecture] Cross-section call assumptions create require cycles; Roblox errors on them and Lune 0.8.9 hangs

Sections: S4, S5, S6, S7, S8 | needsUserDecision: False | confidence: high

**Problem.** (a) PlotWorld.claim calls ShowcaseService.onPlotClaimed while ShowcaseService calls PlotWorld.setSlot, so PlotWorld and ShowcaseService require each other. (b) S7 assumes PlotService calls ShowcaseService.onPlotClaimed, while S5's graph has ShowcaseService → PlotService. (c) S8 puts tid (stored in Profile.Data) on every telemetry event, so Telemetry must read DataService, while DataService → Telemetry (S5 R5). (d) S4 allows Physics/Difficulty → Crafting/Plan, while S5's diagram draws Crafting → Physics. (e) Client side: StationStage suppresses prompts (→ PromptController); PromptController routes triggers 'to UI' (→ ForgeController, EditorController, the item picker); those controllers drive StationStage. Roblox fails such a cycle at require time. Lune 0.8.9 hangs on it, so S8's runner never returns its exit code.

**Evidence.** S7 §13.3.1 Claim row ('ShowcaseService.onPlotClaimed renders the stands') and §13.10.3 ('PlotWorld.setSlot(plot, slot, ...)'). S5 §1.4: 'ShowcaseService ──► DataService, PlotService, ...'. S7 §13.1: 'PlotService owns assignment and calls PlotWorld'. S8 §14.13: 'tid (pseudonymous telemetry id: a GUID stored in Profile.Data'. S5 §1.4 R5. S4 §8.6: 'Physics/Difficulty may require Crafting/Plan'. S7 §13.5.1 (PromptController.setSuppressed) and §13.1. S6 §11.3 and §12.1. Read-only Studio probe on unparented ModuleScripts A ⇄ B: 'ok=false -> Requested module experienced an error while loading'. Lune, review/R7/cycle: 'timeout 8 lune run main.luau' exits 124 (hang). With a task.delay watchdog calling process.exit(2), Lune panics with 'cannot mutably borrow app data container' and exits 127.

**Proposed fix.** Add composition rules to S5 §1.4. Main.server.luau and Main.client.luau are the only composition roots, and a module never requires a peer that calls back into it; callbacks go through Signals. Concretely:
- PlotWorld.claim sets world state only. Main wires PlotService.Assigned → PlotWorld.claim, and DataService.ProfileLoaded → ShowcaseService.renderAll (S7's onPlotClaimed), so ShowcaseService → PlotWorld is the only edge between them.
- Telemetry never requires DataService; DataService calls Telemetry.setTid(player, tid) on load.
- Physics never requires Crafting; work sets come from Definitions/CraftPlans through Pipeline (R7-06).
- Client Smithy/* (S7) never requires S6's Editor/Forge/Inventory. PromptController exposes Triggered: Signal<(kind, plotIndex, slotIndex)>, connected in Main.client.
S8's T-META-07 (R7-01) detects cycles statically before any spec loads (exit 2), because Lune cannot recover from a cycle at runtime.


### R7-11 [major/conflict] ShowcaseService, InspectView, the world modules and the plot/spawn lifecycle each have two owners

Sections: S5, S7, S1, S8 | needsUserDecision: False | confidence: high

**Problem.** Both S5 and S7 define ShowcaseService. S5's has renderAll, unrenderAll, place, clear, scrap, inspect and getItem, returning Response<...>; S7's has onPlotClaimed, place, clear, inspect and onItemRemoved, returning ShowcaseCode. InspectView is one type in S5's Net/Protocol and a different type plus builder in S7's Showcase/InspectView (S7 adds v, equipmentType, rarityCap, capStep, crafter, hardestTier, balanceVersion). S1 adds ItemPublicView, the full ItemRecord (about 10 KB against S7's 0.7 KB). S5 calls World.build/claimPlot/resetPlot, ItemModel.build and Display.show/setLabel/clear; S7 defines WorldBuilder.build, PlotWorld.claim/release/setSlot/setActivity/teleportHome and the shared ItemRender. The error vocabularies differ: S7 uses NoPlot/TooFar/Busy/SlotLocked..., S5 uses E_* codes. S7 needs World.TeleportHome, which is not among S5's 17 actions. Lifecycle: S5 assigns the plot on PlayerAdded before the profile loads, gives each plot a SpawnLocation used through RespawnLocation, and kicks when no plot is free. S7 assigns after the profile session starts, uses one plaza SpawnLocation plus a deferred PivotTo ('Player.RespawnLocation is not used'), and keeps players without a plot as visitors (NoPlot). S8's S-E2E-02 ('within 10 studs of the plot spawn') depends on which model wins.

**Evidence.** S5 §1.3 'ShowcaseService.luau, PlotService.luau (S5)' and §1.7. S7 §13.1 (src/server/ShowcaseService.luau) and §13.10.4. S5 §10.4 InspectView against S7 §13.11.3. S1 §9.4 ItemPublicView. S5 §1.6 table and 'Assumes (S7): World.build() returns { plots }, each plot owns exactly one SpawnLocation'. S7 §13.2.1 Spawn row, §13.3.1 Assign row, §13.3.2. S5 §10.3 catalogue.

**Proposed fix.** S7 owns the ShowcaseService logic, Showcase/{ShowcaseRules, InspectView} and server World/{WorldBuilder, PlotWorld}. S5 owns the transport (Handlers register Showcase.*), the lifecycle order in Main.server, PlotService and the rate limits. One mapping table translates S7's codes to wire codes: BadSlot/SlotLocked → E_SLOT_INVALID, BadItem/NotOwned → E_NOT_FOUND, Busy → E_SESSION_ACTIVE, NotLoaded → E_NOT_READY, TooFar → a new E_TOO_FAR, NoChange → ok. Keep one InspectView (S7's), re-exported by Net/Protocol, and delete S1's ItemPublicView. S5 switches to S7's names (PlotWorld.claim/release; ItemRender). Add World.TeleportHome {} with a {1, 1/3 s} bucket, refused during a session, or drop the button. Lifecycle: adopt S5's order. Assign the plot synchronously in PlayerAdded before any yield, so first spawns already land on the plot; use a SpawnLocation per plot with RespawnLocation and LoadCharacter in the Studio race; kick when full. This is simpler than a PivotTo on every spawn. S7 then drops PlazaSpawn and NoPlot. The reverse also works, but pick one. S8's S-E2E-02 follows the ruling.


### R7-12 [major/conflict] Wall-clock checks are implemented twice with different thresholds and consequences

Sections: S3, S5, S8 | needsUserDecision: False | confidence: high

**Problem.** S3's pure judge marks elapsedMs < countdown + duration − 300 as Invalid('TooFast'), which fails the step, and flags SlowClock above countdown + 1.25·duration + 5000. S5's SessionMachine rejects E < D − 250 with E_TOO_EARLY (state unchanged, Hard strike), flags LateSubmit above D + 1500 + A and times the step out above D + 5000 + A. S3 also assumes a separate S5 timeout of 'countdown + duration + 30 s' → Invalid('Expired'). Both run on every Submit, and S5's tighter bound comes first. S3's TooFast can therefore never fire. SlowClock can never fire either: with D = 15 s and A = 200 ms, S5 times the step out 23.2 s after it opens, while SlowClock needs 26.75 s. The consequences differ too: a failed step, a refused request, or an aborted session.

**Evidence.** S3 §10.M1 step 3 and the S5 assumption there; S3 §10.M2. S5 §7.P3 formula block and worked example ('timed out beyond 20 200; the sweep fires at t_open + 23 200'). S8 S-E2E-10: 'Cheat-Fast → TooFast'.

**Proposed fix.** S5's SessionMachine owns every wall-clock rule, since it holds t_open, the ping and the deadline sweep: TooEarly (E < D − 250; refused, Hard strike), the LateSubmit soft flag, and the timeout. S3 removes step 3 from judge (signature judge(spec, pattern, timeline)), deletes the TooFast, SlowClock and Expired ids and the WALL_* constants, and keeps only checks on input content. S8's S-E2E-10 expects E_TOO_EARLY. The telemetry flag list (R7-17) uses S5's names.


### R7-13 [major/bug] The mirror tool mirrors about x = 0, but Asymmetry is measured about the sword's own grip plane; mirror math exists twice

Sections: S2, S6, S8 | needsUserDecision: False | confidence: medium

**Problem.** S6's Mirror reflects across the hitbox centreline x = 0 (and z = 0). S2's Asymmetry mirrors about the plane through the grip point that contains the grip axis, and S2 recommends that the tool use that plane 'so a mirror-built design measures exactly 0 asymmetry'. With free transforms, a grip a few hundredths of a stud off x = 0, or tilted a few degrees (the axis may lean up to 45°), makes a mirror-built guard read as asymmetric beyond ASYM_TOL = 0.02. That raises Hammering/Sharpening difficulty with no visible cause: the player sees a contradiction. Mirroring is also implemented twice (S2's Geometry.mirrorPart with a general plane; S6's Mirror.reflectPart with closed forms that pick a different symmetry for Block/Ball/Cylinder). The shapes come out equal but the quaternions differ.

**Evidence.** S6 §11.14: 'Mirror across the sword's symmetry planes through the hitbox centreline: x = 0 ... and z = 0'. S2 §3.7: 'Recommendation to S6: the tool's default plane is the sword's symmetry plane ... a mirror-built design measures exactly 0 asymmetry (prototype: 0.000)'. S2 §5.2 Asymmetry definition. S2 §4.5.3 axis eligibility (a2_y/|a2| ≥ 0.7071).

**Proposed fix.** Keep one src/shared/Blueprint/Mirror.luau (S2's math: general plane formula plus the closed forms, canonicalized through Quat), and have S6's tool call it. The default plane for 'Mirror copy across X' is S2's symmetry plane (point g, normal N) whenever the blueprint has a Grip, otherwise x = 0. The z-mirror stays at z = 0, since Asymmetry ignores Z. The editor draws the active plane. S8 runs T-BP-11 on the shared module and adds a case: a mirror copy of any guard part about the default plane gives Asymmetry ≤ TOL_ASYM_ZERO.


### R7-14 [major/platform] Analysis execution model: S5 assumes ≤ 15 ms per Heartbeat, S2 budgets up to 75 ms with a checkpoint, S6 adds an Actor fallback

Sections: S2, S5, S6, S8 | needsUserDecision: False | confidence: high

**Problem.** S5's AnalysisQueue runs one full analysis synchronously per Heartbeat. It assumes 'Analyze.run worst case ≤ 15 ms ... (fits one 60 Hz frame)' and never passes S2's opts.checkpoint. S2 measures 36 ms for its adversarial case in Lune, sets a ≤ 75 ms server ceiling (Roblox runs about 2× slower than Lune), and requires running the analysis outside the hot frame through the checkpoint or an Actor. As written, every hostile Save (4 per player in the bucket) can freeze the 8-player server for up to 75 ms per job, and a full queue of 16 jobs gives 16 consecutive frames of up to 75 ms. The client adds a third mechanism: a synchronous run after a 120 ms debounce, with a fallback to an Actor worker if the p95 hitch exceeds 33 ms.

**Evidence.** S5 §1.7 AnalysisQueue and its assumption; S5 §16 ANALYSES_PER_HEARTBEAT = 1; S5 §10.13 '1 S2 analysis per Heartbeat (Assumes S2 ≤ 15 ms)'. S2 §4.7 rows 'Server, hard ceiling ≤ 75 ms ... worst constructed case 36 ms' and 'Server execution ... opts.checkpoint ... or a Parallel Luau Actor'. S6 §11.19.1: 'moves the same pure call into a client Actor worker'.

**Proposed fix.** Use one mechanism, S2's checkpoint. S2 calls opts.checkpoint() between phases and at least every 2,000 inner iterations, and Analyze.run keeps no module-level state, so it is re-entrant. AnalysisQueue runs one job at a time and passes checkpoint = function() if os.clock() − sliceStart > 0.004 then task.wait(); sliceStart = os.clock() end end, i.e. at most 4 ms per frame; its inputs are already deep copies. The client's PreviewScheduler uses the same checkpoint, plus 'if rev ~= state.revision then error(CANCELLED) end' to abandon stale previews. No Actors in the MVP: drop PreviewWorker from S6 and from the Rojo tree. S8's T-PERF-01/S-PERF-01 measure the longest uninterrupted slice (≤ 5 ms on the server, ≤ 8 ms on the client) as well as total latency. S5 updates its budget rows.


### R7-15 [major/testing] S8's plan has no tests for about 20 pure modules and several contracts, and some planned tests contradict the drafts

Sections: S8, S1, S2, S3, S5, S6, S7 | needsUserDecision: False | confidence: high

**Problem.** No tests are planned for:
- S5's Guard (fuzzing), RateLimit, Protocol and SessionMachine (37 scenarios); S5 says they 'become Lune specs'.
- S6's Snap, Expr, Rotation, Mirror, History/Commands, GizmoMath, EditorState and EditorLayout, which S6 §11.1 lists for S8.
- S7's Layout, RenderPlan, ShowcaseRules and InspectView, and the world-data check; S7 §13.15.1 lists the cases.
- S1's invariants I1–I13, Names accept/reject cases, Views.snapshot deep copy, Prepare repair/quarantine and the migrate-before-reconcile order. Definitions/Validate.validateAll is also untested: S8 re-implements those checks as T-DEF instead of asserting validateAll() == {}. JsonSafe too: S8 writes its own tests/lib/ProfileSafe but never tests S1's module.
- S3's Timeline codec reasons (T-MG-08 assumes table timelines), the HIGH-flag clamp rule, and Params clamping/quantum.
- The user decision itself (no step restrictions on move/rotate/scale).
Planned tests that contradict the drafts:
- T-BP-03 (unit quaternion within 1e-12, sizes ≥ MIN_DIM) against S1's grid.
- T-BP-04 serialize/deserialize: no such module exists, and S8 itself notes Lune's serde 'encodes 1e-300 as 0'.
- T-PHY-12 expects a 'duplicates' cleaning class that S2 does not have.
- T-DIF-04 expects factors bit-identical with dust filler, but S2 lets cleaned parts lengthen thickness chords, so Thinness can drop.
- T-MG-07 says 'exactly' but ignores S3's clamp and round_q.

**Evidence.** S8 §14.2 test folders (Definitions, Blueprint, Physics, Difficulty, Minigames, Crafting, Persistence, Meta). S5 §10.14 last paragraph. S6 §11.1 item 5 and the S8 row of its cross-section assumptions. S7 §13.15.1. S1 §9.8, §3.6, §9.6. S8 §14.3.2 ProfileSafe. S8 T-BP-03/04, T-PHY-12, T-DIF-04, T-MG-07/08. S2 §4.4 table row 'Hiding other parts' surfaces, thickness chords, ... | yes'. S3 §6.7 reason list.

**Proposed fix.** Add suites with S8 ids:
- T-NET-01..05: the S5 Guard fuzzer (50k hostile payloads, 0 throws, node budget, buf()), RateLimit (S5's ratelimit_sim traces), Protocol shapes, and Router's dispatch order extracted as a pure Net/Dispatch.decide.
- T-SES-01..37: SessionMachine scenarios taken from S5's prototype.
- T-ED-*: Snap (any step in range, off, typed-decimal cleanup), Expr grammar, Rotation round trip and continuity, History (merging, budget, dirty flag), Commands apply/inverse, GizmoMath, EditorState part ids.
- T-WLD, T-RND, T-SHW, T-INS: from S7 §13.15.1.
- T-PER-07..10: S1's I1–I13, the S1 §3.6 name cases, Views deep copy, Prepare (migrate-before-reconcile order, repair, quarantine, Newer).
- T-DEF-00: validateAll() == {}, plus one planted error per check.
- T-MG-13: every S3 Invalid reason, plus the encode/decode round trip.
- T-MG-14: a HIGH flag gives score = min(raw, 0.5) and passed stays true.
- T-UD-01: arbitrary non-grid transforms and any snapping step in range survive Save → load unchanged.
Fix the existing tests:
- T-BP-03/04: idempotency and a deep-copy round trip in Lune; the JSON byte round trip only in Studio (S-PAR-03).
- T-PHY-12: dust and enclosed only; exact duplicates fall under Enclosed.
- T-DIF-04: bit-identical for enclosed parts; non-increasing for dust.
- T-MG-07: include clamp and quantum.
Add a traceability table that maps every 'Assumes (S8)' line in S1–S7 to a test id.


### R7-16 [major/testing] S8's Studio harness assumes S5 interfaces that do not exist (log format, RemoteFunction, lifecycle hooks, project files)

Sections: S8, S5 | needsUserDecision: False | confidence: high

**Problem.** (1) Console hygiene fails on '[Blacksmith][E]' lines, but S5 logs '[blacksmith:<tag>] <event> k=v' with level words. Errors would never match, so the check always passes. (2) The bridge's call uses InvokeServer, but S5 has no RemoteFunction. (3) S8's names do not exist in S5. Actions: SaveBlueprint, StepStarted, SubmitStep, PlaceOnDisplay, StartCraft, ItemCreated, where S5 has Blueprint.Save, the StartStep reply, Craft.Submit, Showcase.Place, Craft.Begin and next = Completed. Codes: Busy, RateLimited, TooFast, AlreadySubmitted, where S5 has E_SESSION_ACTIVE, E_RATE_LIMITED, E_TOO_EARLY and duplicate = true. (4) S8 calls DataService.getData; S5 has DataService.read. (5) simulateRejoin needs the join/leave handlers. S5's are local functions in Main.server.luau, guarded by a 'started[player]' table that makes a second join a no-op. DataService.release also sets leaving[player] = true for good, so re-loading the same Player returns 'PlayerLeft' and ends the session at once. (6) The bridge's telemetry command needs a ring buffer and [TLM] lines that S5 does not have. (7) S8's test.project.json (prototype) declares neither S5's Remotes folder nor Vendor.ProfileStore, so the test place fails Remotes.assertPresent(). (8) S8's sourcemap command omits --include-non-scripts, which S5 requires so that luau-lsp sees the RemoteEvents. (9) S5's README says 'lune run tests/<spec>.luau'; S8's runner is 'lune run tests/run'.

**Evidence.** S8 §14.10.7, §14.10.2 table, §14.10.4 S-E2E-05/08/10/11, §14.4 commands. S5 §1.9 log format; §10.1 'no RemoteFunction'; §1.5 'local function onPlayerAdded' with the started[player] guard; §9.L2 leaving[player] = true and 'if isGone(player) then profile:EndSession() return PlayerLeft end'; §1.8 README commands. proto/S8/repo/test.project.json: grep finds no Remotes or Vendor. rojo sourcemap in review/R7/tree: 0 RemoteEvents without --include-non-scripts, 4 with it.

**Proposed fix.** S5 adds:
- Lifecycle.luau with join(player) and leave(player), used by both Main and the bridge. join resets DataService's leaving flag and the started guard.
- Log lines of the form '[blacksmith:<tag>] <LEVEL> <event> k=v', with LEVEL ∈ DEBUG/INFO/WARN/ERROR. S8 greps '^\[blacksmith:[a-z]+\] ERROR'.
- A Telemetry ring buffer of 512 events, echoed as [TLM] <json> in Studio (R7-17).
S8 changes:
- The bridge's call becomes NetClient.request(channel, action, args).
- Scenario names and codes are rewritten to S5's catalogue, and profileSnapshot uses DataService.read.
- scripts/verify generates test.project.json from default.project.json by injecting the BlacksmithTests and bridge nodes, instead of a hand copy; a T-META test checks that it is a superset.
- Sourcemap commands use --include-non-scripts.
The README uses 'lune run tests/run'.


### R7-17 [major/conflict] Telemetry has three event catalogues and two incompatible APIs; S8's raw sink goes beyond the MVP

Sections: S3, S5, S8 | needsUserDecision: False | confidence: high

**Problem.** S3 defines 4 snake_case events with structured fields (minigame_result, ...). Its pure judge also says it 'logs telemetry', which is a side effect. S5 defines 11 PascalCase AnalyticsService events, each limited to a number plus 3 string fields: Telemetry.log(player, event, value, f1?, f2?, f3?). S8 defines 10 events with JSON payloads (factor vectors, metrics, the client score) and common fields v, bv, t, job and tid, plus a ring buffer, [TLM] lines and a raw DataStore batch sink with Open Cloud export. S8's analyses (factor saturation, threshold hugging, rarity per draft per blueprint hash) need fields that S5's AnalyticsService mapping cannot carry. S3's events have no transport. And tid creates the Telemetry → DataService cycle of R7-10.

**Evidence.** S3 §10.M1 step 7 and §10.M7 table. S5 §10.12 table and the TelemetryEvent type. S8 §14.13 event table, sinks, and 'Assumes (S5): a server Telemetry.log(event, payload) with a ring buffer'.

**Proposed fix.** One API, owned by S5: Telemetry.emit(event, fields: {[string]: string | number | boolean}, player?). One catalogue, with names and fields owned by S8 and the transport by S5: BlueprintSaved, BlueprintRejected, CraftStarted, StepScored, CraftCompleted, CraftAborted, ItemDisplayed, AntiCheatFlag, RateLimited, DataLoaded, DataIssue, FilterFailed, Perf. StepScored absorbs S3's four events as fields (status, flags, rawScore, clientScore). S3's judge returns data; only S5 emits. Sinks: in Studio and private playtests, a [TLM] <json> line plus the ring buffer for the bridge, aggregated to CSV by a Lune script; on live servers, S5's per-event AnalyticsService mapping (value + 3 fields, as in S5 §10.12). The raw DataStore sink with Open Cloud export (S8's sink 3) becomes a Phase 2 hook, so the MVP needs no API key. S8's open question 4 keeps the default 'logs only'. DataService pushes tid with Telemetry.setTid.


### R7-18 [major/scope] Over-engineering: the two-tier recompute (GEOMETRY_VERSION, GeometrySummary, stale queues) is not implemented by S2 or S5 and cannot feed S4's formulas

Sections: S1, S2, S4, S5 | needsUserDecision: False | confidence: high

**Problem.** S1 splits item data into frozen facts, an expensive GeometrySummary (per-material Volume and ∫r dV plus density-independent Measures) recomputed when GEOMETRY_VERSION changes, and cheap derived values recomputed when BALANCE_VERSION changes. Recompute runs through Prepare.run's stale lists: a synchronous cheap pass, plus a background staleGeometry queue with a per-frame budget. No other section implements any of it. S2 offers no analyzeGeometry/summarize and no per-material moments. S5 never mentions Prepare, the stale lists or GEOMETRY_VERSION. S4's recompute path recomputes physics from the snapshot. The cheap path also cannot reproduce S4's outcome: T uses the kept volume per material, H the volumes inside the Sharpening work set, K the volumes inside the Hammering work set. A per-material summary of the whole item does not contain per-work-set data. Meanwhile a full analysis costs 1.4–7.3 ms per sword in Lune. The design adds a version number, 0.4–0.6 KB per item, two code paths and a background job, in an MVP whose items are display-only.

**Evidence.** S1 §9.4 GeometrySummary and 'Assumes (S2): ... Physics.analyzeGeometry(core) ... Physics.summarize(geometry)'. S1 §9.6 Prepare step 5 and 'Recompute scheduling (S5) ... background queue with a per-frame budget'. grep over S2/S4/S5/S8: no occurrence of GEOMETRY_VERSION, GeometrySummary, analyzeGeometry, staleCheap/staleGeometry or Prepare. S4 §7.6: 'physics is recomputed from the snapshot, then Outcome.compute runs'. S4 §8.1 H/K definitions. S2 §4.7 timing table.

**Proposed fix.** Keep the frozen inputs that BRIEF §2 requires (snapshot, step records, BalanceVersion) and one pure path: Items/Recompute.item(item) = Pipeline.analyze(snapshot) → Plan.fromHistory → Outcome.compute → Create (owners S1 and S4). Drop GEOMETRY_VERSION: BALANCE_VERSION covers 'outcome-affecting data or code', and S8's per-version outcome goldens catch code drift. Also drop GeometrySummary, Prepare's stale stage and the background job. A stale item is recomputed lazily through the AnalysisQueue (time-sliced, R7-14) when it is rendered, inspected or fetched, at most 6 per plot claim. The rarity floor stays a decision to confirm (S1 and S4 already ask). Remove the 13 persistent Counters, which telemetry already covers, or mark them as a Phase 2 hook.


### R7-19 [major/gap] No implementation order: proposed milestones M0–M9, each with exit tests

Sections: S8, S5, S1, S2, S3, S4, S6, S7 | needsUserDecision: False | confidence: high

**Problem.** No draft says what to build first. S8 gates L3/L4 'per milestone' without defining any milestones. The system has 60+ modules from 8 owners, and its riskiest assumptions can only be checked in Studio: the shape conventions against the engine, Lune↔Studio determinism and the ProfileStore lifecycle. A big-bang integration would hit breaks like those in R7-01 and R7-03 last.

**Evidence.** grep 'milestone|build order|implementation order' over all drafts: the only hits are S8 §14.1 ('before a milestone / playtest', 'per milestone').

**Proposed fix.** Add a build-order section to §14 (owner S8, with S5):
- M0 Toolchain: the R7-04 repo tree, aftman (rojo, lune, luau-lsp), default.project.json and a generated test.project.json, the runner and tests/lib, scripts/verify, T-META-01..07. Exit: verify is green on stubs and rojo build succeeds.
- M1 Data contracts: Definitions/*, Util/Quantize, Blueprint/{Schema, Canonical, Names, Views, Quat}, fixtures F1–F4 and A01–A24. Exit: T-DEF, T-BP-01..05, the balance guard.
- M2 Geometry core and engine parity: Physics/{Shapes, Gjk, Sampling, MassProps}, validation V1–V6, Blueprint/Mirror, a minimal RenderPlan plus ItemModelBuilder.buildPart. Exit: T-PHY, T-BP-06..11 and Studio S-PAR-01, so the shape conventions are proven before anything builds on them.
- M3 Difficulty: Edge, Factors, Difficulty, Analyze, Pipeline. Exit: T-DIF, golden tiers for F1–F4, T-PERF-01 slices, the first Studio S-PAR-02 digest.
- M4 Minigames: Rng, Params, Timeline, Input, the three families, Checks, judge, and the bots. Exit: T-RNG, T-MG including L3.
- M5 Crafting and items: Crafting/*, Items/*. Exit: T-CR and an S-PAR-02 re-run that includes outcomes.
- M6 Headless server slice: Net/*, Session/SessionMachine (Lune T-NET/T-SES), then DataService on Mock, Persistence, Router/Handlers, BlueprintService and AnalysisQueue, CraftService, PlotService, Lifecycle, Log, Telemetry and the server TestBridge. Exit: S-E2E-01/03/04/05 (craft at protocol level)/07/09/10/11, with no UI.
- M7 World and display: Definitions/World, Layout, WorldBuilder, PlotWorld, ShowcaseService, ShowcaseRules, InspectView, TextFilter. Exit: T-WLD/T-RND/T-SHW, S-E2E-02/08/13, S-VIS-01/06.
- M8 Client: UI kit, Net/Client, EditorCore (Lune T-ED first), then the Roblox-bound editor layer, the forge flow, minigame views with InputCapture, results, inventory and the inspect panel. Exit: T-DIF-10, S-E2E-06/12, S-VIS-02..05/07/08 and the preview slice test.
- M9 Telemetry sinks, polish, M-01..M-07 and the Definition of Done.
Every milestone ends with scripts/verify green and its Studio scenarios passing three times.


### R1-37 [minor/conflict] Place settings: StreamingEnabled false (S5) vs true (S7); StarterPlayer settings missing

Sections: S5, S6, S7 | needsUserDecision: False | confidence: high

**Problem.** S5 sets Workspace.StreamingEnabled = false and S7 specifies true with Atomic models and RequestStreamAroundAsync; both are 'place settings' that only S5's table can own. S6 also needs StarterPlayer.EnableMouseLockOption = false (Shift is an editor modifier) and an optional client Actor PreviewWorker, and neither appears in S5's Rojo project or place-settings table.

**Evidence.** S5 §1.8: 'Workspace.StreamingEnabled | false [Decision to confirm]'; S7 §13.7.4: 'Workspace.StreamingEnabled | true (default of new places; ...)'; S6 §11.3: 'Assumes (S5/S7): StarterPlayer.EnableMouseLockOption = false'; S6 §11.19.1: 'BlacksmithClient.PreviewWorker ... Assumes (S5): the Rojo tree can host that Actor'.

**Proposed fix.** S5 owns the one place-settings table. Set StreamingEnabled = false: nothing in the MVP needs it (about 2,331 parts worst case per S7 §13.7.1), and it removes S7's stream-out edge cases. S7 keeps its tag/attribute binding (it works either way) and deletes the 'true' row. Set EnableMouseLockOption = false through StarterPlayer $properties in default.project.json, and document PreviewWorker (Actor) as an optional child of BlacksmithClient.


### R1-38 [minor/conflict] Profile store name and key defined twice

Sections: S1, S5 | needsUserDecision: False | confidence: high

**Problem.** S1 uses ProfileStore 'PlayerData' with key 'User_<UserId>' (Limits.PROFILE_STORE_NAME). S5 uses 'Blacksmith_PlayerData_v1' with 'Player_%d' (Network.STORE_NAME and PROFILE_KEY_FORMAT). Only one can be implemented.

**Evidence.** S1 §9.1: 'ProfileStore.New("PlayerData", Template.TEMPLATE), key "User_" .. player.UserId'; S5 §9.L1: 'Store name | "Blacksmith_PlayerData_v1"', 'Key | string.format("Player_%d", userId)'; Roblox 'Best practices for data stores' (fetched): recommends static 'User_{UserId}' keys in a PlayerData store, which 'let automated right-to-be-forgotten processing identify player data'.

**Proposed fix.** One constant pair in S1's Limits with S1's documented values; S5 reads it and deletes STORE_NAME and PROFILE_KEY_FORMAT. If S5 wants a pre-launch wipe switch, use a separate Studio/test store name in Config, not the live key pattern.


### R1-39 [minor/conflict] D quantization: S1 1e-4 before tierFor, S4 1e-3 in history, S2 none

Sections: S1, S2, S4 | needsUserDecision: False | confidence: high

**Problem.** S1 requires D_s to be quantized to 1e-4 by S2 before tier mapping and stored at 1e-4. S4 stores the history D at 1e-3 (DifficultyGrid 1000). S2's draft never quantizes D or G. A D in [0.1995, 0.2) is stored by S4 as 0.200 next to tier Normal, which confuses the history card and S8's threshold-hugging analysis. Whether rounding happens before tierFor also changes the tier for D in [0.19995, 0.2).

**Evidence.** S1 §9.5: 'D (per step and in Analysis) | 1e-4, before tierFor | S2'; S4 §8.6.3: 'DifficultyGrid = 1000, -- D_s stored to 1e-3 in the history'; S2 grep: no quantization of D (only §3.4's no-quantization statement); S8 §14.13: 'density of D_s in [0.18, 0.22]'.

**Proposed fix.** S2 quantizes G, m and D_s to 1e-4 at production (S1's SCALAR_SCALE), before the tier mapping. S4 deletes DifficultyGrid and stores D as produced.


### R1-40 [minor/conflict] Preview cadence constants differ and sit in the balance data

Sections: S2, S6 | needsUserDecision: False | confidence: high

**Problem.** S2 sets PREVIEW_DEBOUNCE_MS 200, PREVIEW_MAX_HZ 4 and CONNECTIVITY_MAX_HZ 10 in Definitions/Balance, where they are covered by BALANCE_VERSION. S6 uses PREVIEW_DEBOUNCE_MS = 120 and runs connectivity only after the debounce. S6 quotes S2's analysis cost as 4.8–21.7 ms, while S2 publishes 1.4–7.3 ms typical and 36 ms adversarial. S6 needs a Validate.quick entry point (V2–V4 without GJK), but S2 exposes only Analyze.validate, which includes connectivity.

**Evidence.** S2 §16: 'PREVIEW_DEBOUNCE_MS, PREVIEW_MAX_HZ, CONNECTIVITY_MAX_HZ = 200, 4, 10'; S6 §11.22: 'PREVIEW_DEBOUNCE_MS | 120'; S6 §11.19.1: 'S2's prototype analysis takes 4.8–21.7 ms per sword'; S2 §4.7 table; S6 §11.18.1: 'Validate.quick(bp) (rules without sampling ...)'.

**Proposed fix.** S6 owns the cadence constants as client UX, outside Balance and outside the BALANCE hash, with 120 ms debounce and at most 4 Hz. S2 supplies the costs and adds Analyze.validate(parts, rules, {connectivity = false}) as S6's quick check. S6 updates its cost quote from S2 §4.7.


### R1-41 [minor/conflict] Item rename and fallback names: three rules

Sections: S1, S5, S6, S7 | needsUserDecision: True | confidence: high

**Problem.** S1 lets items be renamed ([Decision to confirm], S1 §17.4), while S5 makes 'no item rename' an MVP non-goal (S5 §17.10) and S6 has no rename UI. The fallback name, shown when filtering fails, also differs three ways: S1 uses the type name 'Sword'; S5's TextFilter.fallbackName uses '<Material> <Type>' with the majority material; S7's InspectView.defaultName uses '<blade materials> <type> No. <serial>', which needs a per-owner Serial that S1 does not define. S5 also expects Names.sanitize to turn an empty name into a default, while S1 returns an 'Empty' error.

**Evidence.** S1 §3.6: 'items can be renamed with the same rules [Decision to confirm]' and 'On failure show the type name ("Sword")'; S5 §10.3: 'Item rename is not in the MVP'; S5 §1.7: 'fallbackName ... "<Material> <Type>"'; S7 §13.3.4: '" No. <serial>" when Assumes (S1) an optional per-owner Serial exists'; S5 §10.10: 'S1.Names.sanitize (trim, collapse spaces, empty → default)'; S1 §3.8 NameError 'Empty'.

**Proposed fix.** Ask the designer one question, defaulting to no item rename in the MVP (no S5 action, no S6 UI). Use one fallback function, S7's InspectView.defaultName without Serial ('Steel Sword', 'Iron-Steel Sword'), called by S5's TextFilter and referenced by S1. An empty name is rejected (S1); the client substitutes the blueprint's name before sending.


### R1-42 [minor/bug] ScoreMismatch fires on every flag-clamped step

Sections: S3, S5, S8 | needsUserDecision: False | confidence: high

**Problem.** S3 clamps the authoritative score to passThreshold when a HIGH flag is set, keeping rawScore. The client's provisional score comes from finish() without checks, so it is the raw score. S5 compares clientScore with the clamped score (|Δ| > 1e-9 gives the Soft flag ScoreMismatch). Every HIGH-flagged step therefore also logs a ScoreMismatch, which pollutes a metric S8 expects to be exactly 0.

**Evidence.** S3 §10.M1 step 6: 'if any HIGH flag: score = min(rawScore, CLAMP_TO = passThreshold)'; S3 §6.4.4: the client sends clientScore from its own finish(); S5 §7.P4 step 9: '|clientScore − score| > SCORE_MISMATCH_EPS (1e-9) → Soft flag ScoreMismatch'; S8 §14.13: 'ScoreMismatch count | 0'.

**Proposed fix.** S5 compares clientScore with MinigameResult.rawScore. S3 documents that the clamp is server-only.


### R1-43 [minor/gap] MAX_STEP_FLAGS = 4 is smaller than the flags a step can receive

Sections: S1, S3, S5 | needsUserDecision: False | confidence: medium

**Problem.** S1 stores at most 4 flags per step record, with no rule for which to keep. A PrecisionTrace step can receive PT_TooPrecise, PT_TooSmooth, PT_Teleport and PT_Sparse from S3, plus LateSubmit and ScoreMismatch from S5 (SlowClock goes away with R1-09), up to 6 in total.

**Evidence.** S1 §16: 'MAX_STEP_FLAGS = 4 -- StepRecord.Flags entries'; S3 §10.M4 flag table; S5 §7.P4 steps 9–10.

**Proposed fix.** S1 defines a fixed priority (HIGH flags first, then S5's flags, then telemetry-only flags) and truncation at MAX_STEP_FLAGS, or raises the cap to 8. S5 applies the rule when it records the step.


### R1-44 [minor/gap] Persistent Counters have no writer

Sections: S1, S5 | needsUserDecision: False | confidence: high

**Problem.** S1's template has Counters (BlueprintsCreated, BlueprintSaves, CraftsStarted, CraftsCompleted, CraftsAbandoned, ItemsScrapped, BestQuality, PlaySeconds, StepsPlayed, StepsPassed, TierPlays, RarityCounts), but no section says who increments them; S5's handlers never mention them.

**Evidence.** S1 §9.3 Counters and TEMPLATE; grep of S5, S4, S6 and S7 for Counters/CraftsStarted: only S7 mentions ItemsScrapped, in passing.

**Proposed fix.** Either S5's handlers increment the listed counters inside the same DataService.mutate as the action (S5 adds a per-action list), or S1 drops Counters and relies on telemetry.


### R1-45 [minor/gap] Thumbnails need geometry that the summaries do not carry

Sections: S1, S5, S6 | needsUserDecision: False | confidence: medium

**Problem.** S6's Library, its Choose grid and the Items panel (up to 150 tiles) render VIEW_H thumbnails through S7's mountInViewport, which needs each record's parts. S1's and S5's BlueprintSummary and ItemSummary carry no geometry, and fetching records one by one is rate-limited (Blueprint.Get and Showcase.GetItem: 10 tokens, refill 2/s), so a full Items grid takes about 70 s to fill.

**Evidence.** S6 §11.20: 'Thumbnails use S7's ItemModelBuilder.mountInViewport ... built only for visible rows'; S6 §12.2.2: 'grid of the player's items ... VIEW_H thumbnail'; S5 §10.7: 'Showcase.GetItem | 10, 2/s'; S1 §3.2 BlueprintSummary; S1 §9.4 ItemSummary.

**Proposed fix.** S6 lazy-loads only visible tiles and caches them by (id, Revision). S5 adds a batched Showcase.GetItems {itemIds ≤ 12} and Blueprint.GetMany, or a parts-only thumbnail payload, and S5 §10.13 budgets it.


### R1-46 [minor/testing] S8's test plan uses interfaces the other sections do not provide

Sections: S5, S6, S7, S8 | needsUserDecision: False | confidence: high

**Problem.** S8's TestBridge 'call' uses InvokeServer, but S5 has no RemoteFunctions; S8 should go through Net.Client.request. S8's scenarios use names that do not exist in S5 (StepStarted, SubmitStep, ItemCreated, StartCraft, SaveBlueprint, PlaceOnDisplay, DataService.getData) instead of S5's Channel.Action names, the StartStep reply and DataService.read. S8 has no Lune plans for S6's pure modules (Snap, Expr, Rotation, Mirror, History/Commands, GizmoMath, Layout) or S7's (Layout, RenderPlan, ShowcaseRules, InspectView). It has no preview-hitch test, although S6 §11.19.1 makes one an acceptance gate. It also assumes an autoplay input-injection point that S6 never defines.

**Evidence.** S8 §14.10.2: 'call | {remote, payload} → the remote's response (InvokeServer)'; S5 §10.1: 'no RemoteFunction'; S8 §14.10.4 S-E2E-05/08/11; S8 §14.6 (module test plans cover Definitions, Blueprint, Physics, Difficulty, Rng, Minigames, Crafting, Persistence only); S6 §11.19.1: 'Acceptance (S8): p95 hitch ≤ 33 ms'; S7 §13.15.1; grep of S6 for autoplay/inject: none.

**Proposed fix.** S8 adopts S5's channel, action and error names, calls Net.Client.request from the client bridge, and adds test sections for S6's and S7's pure modules and the hitch test. S6 defines the injection hook MinigameHost.setInputSource(fn).


### R1-47 [minor/conflict] Material and rarity render values are defined twice

Sections: S1, S7 | needsUserDecision: False | confidence: high

**Problem.** S1's material rows carry Color/RobloxMaterial/Reflectance (Iron 92,96,102 Metal 0.05; Steel 168,176,186 Metal 0.15; Mithril Metal; Leather Leather). S7 proposes other values and lowercase fields: color/renderMaterial/reflectance, Iron 112,114,120; Steel 196,202,210 0.18; Mithril Foil; Leather Fabric. All 7 rarity colours also differ between S1 §2.10 and S7 §13.9.

**Evidence.** S1 §2.5 rows and §2.10 table; S7 §13.8.3: 'Assumes (S1): Definitions/Materials records carry color ..., renderMaterial ... and reflectance. Proposed values: ...'; S7 §13.9: 'Assumes (S1) Definitions/Rarities[id].color; proposed Common (170, 170, 170) ...'.

**Proposed fix.** S1's rows are the single source; S7's proposals are merged into S1's table, one set only. S7's MaterialRender reads S1's PascalCase fields.


### R1-48 [minor/clarity] S2's cutIndex is offered for S4's edge profile, but S4 uses edge length instead

Sections: S2, S4 | needsUserDecision: False | confidence: high

**Problem.** S2 computes cutIndex as the draft's 'edge or impact profile' and assumes S4's stats read it. S4's damage formula instead uses c = clamp(L_edge / EdgeRef, 0, 1) and never reads cutIndex, which is nevertheless stored in S1's and S2's summaries.

**Evidence.** S2 §4.5.5: 'cutIndex = clamp((bladeLength / bladeMeanThickness − 10) / (60 − 10), 0, 1)' and 'Assumes (S4): stats read mass, balance, reach, edge.cutIndex'; S4 §8.2.2 formulas (5) and (7).

**Proposed fix.** S4 decides: either F_edge uses cutIndex, or S2 drops cutIndex from the stored summaries and keeps it as a Phase 2 hook.


### R1-49 [minor/clarity] Open questions to the designer contradict or repeat each other

Sections: S1, S2, S3, S4, S5, S6, S7, S8 | needsUserDecision: False | confidence: high

**Problem.** The §17 rows that will be merged ask the user contradictory things. Abandon: S3 §17.7 vs S4 §17.4. Item rename: S1 §17.4 vs S5 §17.10. Steel durability: S1 §17.9 vs S4 §17.6. Fail rates: S3 §17.3 vs S8 §17.1, plus S4's §8.5.1 note. Intended tiers: S2 §17.7 ('classic iron arming sword N/N/N') vs S8 §17.2 ('Arming N/N/Hard'). Rarity targets: S4 §17.8 vs S8 §17.3. Storage precision (S1 §17.1) asks again about something the user has already decided. Mass ('≈ 1.3 kg', S1 §17.5) quotes a sword that does not fit the hitbox. Other questions repeat with the same default: WIP saves (S1, S5, S6) and server size (S5, S7).

**Evidence.** S1 §17; S2 §17-S2; S3 §17; S4 §17; S5 §17; S6 §17; S7 §17; S8 §17 (items as cited above).

**Proposed fix.** The lead merges §17 into one list with one default per question, following the rulings on R1-04, R1-08, R1-11, R1-19, R1-28, R1-29 and R1-41, and drops the storage-precision question (R1-04).


### R2-11 [minor/scope] Non-editor scope creep and duplicated subsystems

Sections: S1, S2, S3, S5, S7, S8 | needsUserDecision: False | confidence: medium

**Problem.** Several subsystems go beyond what Phase 1 needs, or exist twice:
- an expensive/cheap two-path recompute with a fourth version number;
- persistent per-player counters;
- a raw telemetry warehouse that needs an Open Cloud API key;
- three telemetry catalogs with different event names;
- an item rename feature that S5 excludes;
- three different default-name rules;
- Phase 2 step difficulties computed on every analysis.

**Evidence.** S1 §9.4: 'GeometrySummary ... derived, expensive (recomputed when GEOMETRY_VERSION changes)'; §9.6 lists four versions; §9.3 'Counters ... persistent per-player telemetry'. S8 §14.13 Sinks (3): 'Raw records batched per server into a DataStore Telemetry_bv<N> ... exported with a Lune script over Open Cloud using an API key the user creates'. Telemetry catalogs: S3 §10.M7 minigame_*, S5 §10.12 (11 events), S8 §14.13 (10 events with other names). S1 §3.6: 'items can be renamed with the same rules' vs S5 §15 'no item rename'. Default names: S1 §3.6 'item name = blueprint name', S5 §10.8 '<Material> <Type>', S7 §13.11.2 'Steel Sword No. 7'. S2 §5.7: Quenching/Assembly/Finishing difficulties computed for every sword.

**Proposed fix.** Simplify:
- S1 drops GeometrySummary and GEOMETRY_VERSION in the MVP. Recompute re-runs S2 on the stored snapshot through S5's AnalysisQueue (≤ 15 ms each, about 2.3 s of background work for 150 items). Hook: reintroduce if measured cost demands.
- One telemetry catalog in S5 §10.12 (transport); S8 §14.13 maps its analyses onto it; S3 §10.M7's fields become payload fields.
- S2 Analyze.run computes enabled steps only.
Cut:
- S1 Counters (telemetry covers them; fewer profile fields and migrations).
- S8's raw DataStore sink and Open Cloud export, to Phase 2. The MVP uses Studio/private-playtest [TLM] logs turned into CSV, plus AnalyticsService aggregates. Drop S8-4 from the designer list.
- Item rename (S5). One naming rule: item name = blueprint name; '<Material> <Type>' only as the fallback while filtering is pending; S7's numbered generator removed or used as that fallback.
Keep:
- S5 Craft.Resume (client UI restart), tombstones and Showcase.Scrap (scrap is needed by the caps).
- S7's replicated workpiece and the minimal forging record (cheap; Q19).
- Rarity effects above Epic as data only.
- A minimal strike/kick system (an engineering call).


### R2-12 [minor/fidelity] The draft's edge/impact profile is computed (cutIndex) but unused; Damage rewards wide-and-heavy twice

Sections: S2, S4 | needsUserDecision: False | confidence: medium

**Problem.** The draft derives Damage from 'mass, edge profile and the hammering and sharpening scores', where the profile runs from 'thin and long' to 'wide and heavy'. S2 computes exactly that as cutIndex (rapier 1.00, arming 0.77, cleaver 0.16) and assumes S4 reads it. S4's Damage uses only edge length, which saturates at 1 for most blades. A wide, heavy cleaver therefore gets the full cutting bonus and the maximum mass bonus at once. At the same scores it out-damages the arming sword by a third, which makes 'wide and heavy' the dominant MVP design until swing speed arrives in Phase 2.

**Evidence.** Design draft: 'Edge or impact profile from the striking part's shape (thin and long vs wide and heavy)'. S2 §4.5.5: cutIndex; §4.5.4: 'Assumes (S4): stats read mass, balance, reach, edge.cutIndex'. S4 §8.2.2 (5): 'c = clamp(L_edge / EdgeRef, 0, 1)'. S4 §8.2.4: cleaver c 1.00, F_mass 1.300 (max); Good-player Damage 41.4 vs arming sword 31.1.

**Proposed fix.** Owner S4.
- Use the profile, for example c = cutIndex · clamp(L_edge / EdgeRef, 0, 1). The cutting bonus then needs a thin, long, edged blade, while wide and heavy designs lean on F_mass. Re-tune DamageBase, EdgeGain and MassFactorMax on the §8.2.4 examples (cleaver c goes 1.00 → 0.16).
- Alternative: keep edge length, have S2 drop cutIndex from the MVP outputs, and record in §0 that Damage uses edge length instead of the edge/impact profile.
- Either way, update S2's 'Assumes (S4)' line.


### R2-13 [minor/ux] Mirror plane (hitbox centre) differs from the Asymmetry plane (grip axis), which is invisible

Sections: S6, S2, S8 | needsUserDecision: False | confidence: medium

**Problem.** With free transforms the grip easily ends up a few hundredths of a stud off the centreline after one unsnapped drag. Parts mirrored across S6's fixed x = 0 are then not symmetric about S2's grip-axis plane, which is the plane Asymmetry measures. Example: a 0.2-wide blade at x = 0 with the grip at x = 0.03 has about 20 % of its mirrored samples beyond the 0.02 tolerance. That gives Asym ≈ 0.2 and adds +0.10 to Sharpening's G. The player cannot see the plane the score uses.

**Evidence.** S6 §11.14: 'Mirror across the sword's symmetry planes through the hitbox centreline: x = 0 ... and z = 0'. S2 §3.7: 'Recommendation to S6: the tool's default plane is the sword's symmetry plane (through the grip point, containing the grip axis and Z); x = 0 before any grip exists'. S2 §5.2: Asymmetry plane 'through the grip point g containing the grip axis A and Z', ASYM_TOL 0.02. S8 F-2: a plane fixed at the hitbox centre reads 0.39 for a symmetric sword moved 0.05 stud. S6 §11.19.3 overlays show the grip but not the symmetry plane.

**Proposed fix.** Owner S6, using S2's definition.
- Mirror by default across S2's symmetry plane, with x = 0 as the fallback before a Grip exists and as an option in the toolbar dropdown.
- Draw that plane as a line in the physics overlay, and name it in the Asymmetry tooltip.
- S2 exposes Geometry.symmetryPlane(parts), pure and cheap. The general-plane mirror formula already exists in S2 §3.7.
- S8 test: a mirror copy across the default plane yields Asymmetry 0.


### R2-14 [minor/fidelity] §0 'what changed' register: verdicts on the 55 recorded deviations and six unrecorded ones

Sections: S1, S2, S3, S4, S5, S6, S7, S8, lead | needsUserDecision: False | confidence: high

**Problem.** Deviations from the design draft are scattered across the eight summaries. Most are justified; a few are not, or need the designer. Six deviations are not recorded at all, so the designer would not see them at the review gate.

**Evidence.** summaries.md deviationsFromDesignDoc: S1 10, S2 10, S3 6, S4 9, S5 6, S6 4, S7 6, S8 4. Unrecorded:
- S2 §4.5.4 'balance = (COM − g)·A − guardPos' vs the draft 'balance point relative to the grip';
- S2 §5.2 'norm(n_eff, 3, 16)' vs the draft 'Parts relative to the type's min and max' (2 and 24);
- S2 §4.4 'exposed area fraction < 0.02' vs the draft 'fully enclosed';
- S2 §5.1 / S4 §7.2 hardest material = highest forgeDifficulty, not highest Hardness;
- S4 §8.2.2 Damage from edge length, not the edge/impact profile;
- S4 §8.1 'Iron 0.50 / 0.50, Steel 0.70 / 0.50' vs S1 §2.5 Iron 45/50, Steel 70/55.

**Proposed fix.** The lead writes one §0 table. J = justified, record it; J* = justified default the designer confirms (§0 Q-number); X = not justified.
- S1: 1 J, 2 J, 3 J* (Q13), 4 J, 5 J, 6 J, 7 J* for the floor (Q18) but X for GEOMETRY_VERSION in the MVP (R2-11), 8 J* (Q17), 9 X (R2-01), 10 J* (Q12).
- S2: 1–8 J, 9 J* (Q3/Q4), 10 is a Phase 2 note.
- S3: 1 J (S3's family-table layout wins; S1 drops MaterialDef.FamilyModifiers and TierDef.FamilyMultipliers to keep one source), 2–4 J, 5 J* (Q16), 6 J.
- S4: 1, 2, 6, 7, 8 J (6: see R2-06); 3 J* (Q9); 4 J* (Q10); 5 J* (Q13); 9 J* (Q15).
- S5: 1, 4, 6 J; 2 J* (Q16); 3 J* (Q6); 5 J* (Q19).
- S6: 1 J for per-type snapping, X for per-axis (R2-09); 2 J with R2-13's plane; 3–4 J (abandon follows S4/S5).
- S7: 1, 3, 4, 5 J; 2 and 6 J* (Q19).
- S8: 1–3 J; 4 J except the raw sink (R2-11).
Add the six unrecorded deviations, all justified if recorded:
- U1 balance measured from the guard (the 'near the guard' focus);
- U2 PartCount range [3, 16];
- U3 'enclosed' = < 2 % exposed (anti-filler);
- U4 hardest = most difficult material (matters in Phase 2: Obsidian hardness 92 vs Mithril difficulty 0.45);
- U5 see R2-12;
- U6: S4 reads S1's values (H = Hardness/100 = 0.45/0.70, K = 0.50/0.55) and re-runs §8.2.4.


### R2-15 [minor/gap] Design-draft open questions and a roadmap gap are not carried into §17

Sections: lead, S4, S5 | needsUserDecision: False | confidence: high

**Problem.** Two of the draft's six open questions (few weapon types in depth vs many types; blueprint sharing) are carried nowhere. Three are answered only implicitly by BRIEF defaults. The sixth (Hell failure) stays open without noting a roadmap gap: material loss arrives in Phase 2, but materials only become obtainable in Phase 4. While materials stay free, a Phase 2 Hell failure would cost nothing.

**Evidence.** Design draft 'Open questions' (6 items) and 'MVP and roadmap'. No openQuestionsForUser list in summaries.md mentions types in depth vs breadth or blueprint sharing. S4 §7.5 F4: 'the draft's open question material, whole item, or only quality? stays open'. Design draft Phase 2: 'All tiers up to Hell, with material loss on failure' vs Phase 4: 'Material sourcing'. BRIEF §2: 'Materials are free/unlimited in the MVP'. S5 §15: 'debit materials at Begin (sourcing Phase 4)'.

**Proposed fix.** The lead adds a 'Carried from the design draft' block to §17:
1. Standalone or part of the forge & mining project: MVP default standalone, modules portable (Q1).
2. What items are used for: display-only in the MVP (Q1); Phase 4 combat or test dummy via S7's welded hook.
3. Few types in depth or many: open for Phase 3; the data model supports either (one EquipmentTypes row + one CraftPlans entry per type).
4. Hell failure (material, item or quality): open for Phase 2. Note the dependency: material loss needs a material economy that the roadmap adds only in Phase 4, so the designer decides whether Phase 2 brings a minimal inventory or Hell destroys the item instead.
5. Blueprint sharing or copying: open for Phase 3 (records are self-describing via Schema; no MVP UI).
6. Material sourcing: open for Phase 4 (MVP free; Inventory.Materials hook).
Also add a short 'Risks' table mapping each draft risk to its spec mitigation and owner: content explosion S3, stat balance S4/S8, design vs craft S2, showcase bias S7 + Phase 3, cheating S3/S5, platform PC, scope R2-09/R2-11.


### R3-15 [minor/bug] Display flow yields after the data write, so filter results can repaint stale stands

Sections: S7, S5 | needsUserDecision: False | confidence: high

**Problem.** S7's Place writes Displays, then waits up to 5 s for the name filter before building the stand. A Scrap, Place or Clear during that wait is overwritten by the late setSlot: for example, a scrapped item comes back as a ghost on its stand. S5's flow (render now with the fallback name, update the label asynchronously) is different. Nothing forbids putting the raw name into Instance.Name or other replicated fields.

**Evidence.** S7 §13.10.3: 'name ← filtered or default (§13.3.4, may yield ≤ 5 s)' then 'PlotWorld.setSlot'; S5 §1.2.3: 'label = cached filtered name or fallback' and 'async: TextFilter.forBroadcast → label text'; S7 §13.8.6 BuildOptions: 'name: string?'.

**Proposed fix.** S5's flow wins: setSlot runs immediately with the generated name, and the async filter callback writes the label only if the stand's (ItemId, Rev) still match. Use one cache key, (itemId, raw). Rule for S5 and S7: player text never goes into Instance.Name, into attributes other than the filtered ItemName, or into telemetry or logs.


### R3-16 [minor/gap] Telemetry and log fields accept attacker-controlled strings

Sections: S5, S8 | needsUserDecision: False | confidence: high

**Problem.** Three gaps. (1) AnalyticsService allows only 8,000 unique custom-field combinations per experience, and AntiCheatFlag's 'Where' field for BadAction can echo unregistered action strings, burning that budget. (2) Guard error paths embed raw client keys (up to 64 B, no control-character check), and logfmt quotes values only when they contain spaces, so a key containing a newline can forge lines such as '[blacksmith:craft] ...'. (3) The 20 lines/10 s limiter is global per (tag, event), so one client's flood suppresses every other player's lines for that event.

**Evidence.** AnalyticsService API: 'Limited to 8,000 unique combinations of values across the three custom fields per experience'; S5 §10.12: 'Where - <Channel.Action | stepId>'; proto/S5/lib/Guard.luau: 'walk(x, path .. "." .. tostring(k), budget, depth + 1)', where only '#k > 64' is checked; S5 §1.9: 'strings quoted when they contain spaces'.

**Proposed fix.** S5: custom fields come only from closed enums (an unregistered action logs 'Where - Unknown'). Log escapes C0/C1 control characters and quotes in values, and truncates client-originated strings to 64 B. Guard paths use '<key>' placeholders for unknown or oversized keys. The limiter runs per (player, tag, event) at 5 lines/10 s, plus the global 20/10 s. S8 test: a key containing a newline produces exactly one log line.


### R3-17 [minor/ux] Strike policy and input-capture rules can punish honest players

Sections: S5, S3, S6 | needsUserDecision: False | confidence: medium

**Problem.** Three paths to honest strikes or timeouts. (1) S5 strikes on any S1 sanitize failure, including semantic ones an honest client can hit: BadName for an emoji typed into the name field, DisabledId or MaterialNotAllowed after a Definitions change. (2) The 2,048-record trace cap is reachable honestly: a 31 s trace produces 1,550 samples on the 20 ms schedule, so about 500 grind toggles (roughly 8 clicks/s) push it over, giving Invalid, an aborted craft and a strike. (3) The end-of-step submit fires on 'the first frame' at or after the duration; if that is a RenderStepped frame, a minimized or hitching client can submit after LATE_HARD and time out.

**Evidence.** S5 §1.7: 'Sanitize.fromWire(draft) → failure = E_INVALID_BLUEPRINT + Hard strike'; S3 §6.7 PrecisionTrace: '2048 | 14,348 | 31 s at 50 Hz + grind transitions'; S3 §6.6: 'At the first frame with now ≥ durationMs, call finish(), encode and submit'; S6 §12.3.1: 'RunService:BindToRenderStep("MinigameView", ...)'.

**Proposed fix.** S5: Hard strikes only for Guard shape failures, BadAction/BadRid, E_TOO_EARLY and decode Invalid/HashMismatch. Semantic sanitize failures return E_INVALID_BLUEPRINT with no strike, and S6 runs Names.sanitize and Canonical.draft before sending. S3/S6: the encoder never exceeds MAX_RECORDS (merge grind toggles less than 20 ms apart; stop recording toggles at cap − 8). The submit is scheduled with task.delay to goClock + D, on Heartbeat rather than RenderStepped.


### R3-18 [minor/gap] Displaying or forging an item publishes its exact blueprint geometry

Sections: S7, S1 | needsUserDecision: True | confidence: high

**Problem.** Stand items and the live workpiece are server-built Parts replicated to every client, and S1's ItemPublicView also ships the blueprint snapshot. Any modified client can reconstruct and re-save someone else's design. The design draft still lists 'Can blueprints be shared or copied between players?' as an open question, and this architecture effectively answers it with 'yes'.

**Evidence.** S7 §13.6.5: 'the item being forged is shown on its station ... so visitors see what is being made'; S7 §13.8.1: display stand 'STAND, scale 1, BaseCenter'; design-draft Open questions: 'Can blueprints be shared or copied between players?'.

**Proposed fix.** Add to §17 as [Decision to confirm]: 'displayed and in-progress designs can be copied by modified clients; the MVP accepts this, with attribution via Forged by'. S1 removes parts from every visitor payload (R3-10). Phase 3 hook: design attribution and originality.


### R3-19 [minor/bug] Rarity-floor wording can ratchet rarity upward

Sections: S4, S1 | needsUserDecision: False | confidence: high

**Problem.** S4 writes rarity = max(stored, recomputed). If 'stored' means the current derived Rarity, a short-lived balance version that inflates rarities raises items permanently. S1's rule uses the frozen AtForge.Rarity and has no such effect.

**Evidence.** S4 §7.6: 'rarity = max(stored, recomputed)'; S1 §9.6: 'Rarity = max(recomputed, AtForge.Rarity)'.

**Proposed fix.** S1's definition wins: the floor is AtForge.Rarity only, and S4's text is updated to say so. S8 property: recomputing under an inflating v2 and then a deflating v3 gives max(v3 result, AtForge.Rarity).


### R3-20 [minor/exploit] The RTT allowance comes from one ping sample the client can inflate

Sections: S5 | needsUserDecision: False | confidence: medium

**Problem.** A = min(2·ping, 2000), with ping read once at t_open. A lag switch at that moment buys 2 s of extra soft and hard tolerance. Slow motion up to (D + 7 s)/D, about 2× on the shortest 6–7 s traces, then costs only a LateSubmit soft flag.

**Evidence.** S5 §7.P3: 'ping | player:GetNetworkPing()·1000 at t_open (round trip)' and 'Timed out E > D + LATE_HARD_MS + A'; S3 §6.10.2: travel clamp [6000, 30000] ms; docs: GetNetworkPing returns 'the round-trip, isolated network latency'.

**Proposed fix.** S5: sample GetNetworkPing at t_open and on every 250 ms sweep while the step is Playing, and set A = min(2·median(samples), RTT_ALLOW_MAX_MS). Log LateSubmit with the ping samples. LATE_HARD_MS stays unchanged, since it is what keeps honest players safe.


### R4a-15 [minor/numbers] Profile budget recomputed for S2's 24-part limit with 36-character GUID ids: caps 60/250 fit (45.7 %), 80/300 do not (55.8 %); join payload 45–134 KB

Sections: S1, S5 | needsUserDecision: False | confidence: high

**Problem.** S1 §9.7 sized its caps for the placeholder MAX_PARTS_ABS = 48 and 'B<n>' ids. S2 fixes 24 parts, and S5 uses GUID ids, which S1's id regex and '≤ 16 bytes' rule would also reject. Recomputed worst cases, as MVP item shape / Phase 2+ item shape, for part ids 1..n up to 5-digit ids: caps 40/150 → 27.6–27.9 % / 32.9–33.3 %; 60/250 → 45.1–45.7 % / 53.9–54.5 %; 80/300 → 55.1–55.8 % / 65.7–66.4 %, above S1's 50 % target. GUIDs cost +60 B per blueprint and +90 B per item (≤ 0.8 percentage points at 60/250), so the id format can be chosen on functional grounds. Join payload with GUIDs: S1's summary shape 66.9 / 107.4 / 133.9 KB; S5's ProfileSnapshot shape 44.7 / 72.3 / 88.6 KB. With raw doubles (R4a-01): 40/150 → 40.2 % / 45.5 %; 60/250 → 65.7 % / 74.6 %. S1's formula matches the measured value within 0.1 % (1,863,862 vs 1,865,048 for 24 parts at 60/250), but the table does not say that its MVP column for the 64/32/24 rows comes from the formula.

**Evidence.** R4a/sizes_r4a.py is an independent re-implementation of S1's §3.2/§9.3/§9.4 shapes and reproduces S1 exactly ('worst part (Id 65535): 181 B', 'blueprint overhead 625 per part 178.8', 'item overhead (MVP) 1972', 'profile B=40 I=150 P=48 MVP: 1956068 B = 46.6%'). out_sizes_r4a.txt: '60/250 GUID 5dig 1916618 45.7% 2287678 54.5% | 107370 72326'; '80/300 GUID 5dig 2339808 55.8% 2786688 66.4% | 133860 88556'; see also out_sizes_raw_r4a.txt. S1 §2.2 rule 3: 'Patterns: ^B[1-9]%d*$ … ≤ 16 bytes'. S5 Appendix A: 'blueprint ids are GUIDs minted by the client'.

**Proposed fix.** S1 sets MAX_PARTS_ABS = 24 (S2 owns the value) and recomputes §9.7 with whatever id format S1 and S5 settle on (size impact ≤ 0.8 percentage points) and with 5-digit part ids (ids are never compacted below 65,535). Caps: 40/150 if transforms are raw doubles (R4a-01); 60/250 only if they stay quantized; 80/300 exceeds the 50 % target in every variant. Label the formula-derived cells; S8's budget test recomputes W from Limits. Owner S1, with S5 for the id format.


### R4a-16 [minor/testing] S8's golden fixtures disagree with S2: the intended tiers for F1 and F4 differ, F3 uses parts below MIN_DIM, and no single FIXTURE_ORIGIN fits both F2 and F3 in S2's 5.0-stud hitbox

Sections: S8, S2 | needsUserDecision: False | confidence: high

**Problem.** I ran S8's fixtures through S2's pipeline with the fixture frame translated by +1.2 in y. F1 ArmingSword gives N/H/H against S8's intent N/N/H: its Steel blade makes m_s = 0.1 for the all-parts Hammering set (D 0.242). F4 Cleaver gives H/N/H against the intent H/H/N (Hammering 0.174; Sharpening 0.365, driven by blade asymmetry). F3's blade (0.035 thick) and tip wedge are below MIN_DIM, so S2's sanitizer clamps them to 0.05, and S8's §14.7.3 reference volume for F3 (0.0391 union) cannot match (S2 measures 0.0432, +11 %). In the fixture frame, F2's pommel reaches y = −1.30 and F3's tip y = +3.78, a 5.08 span, so no single translation fits both into y ∈ [0, 5] (S8 assumes 'room for 1.2 studs below O'). With +1.2, F2 fails OUT_OF_HITBOX.

**Evidence.** R4a/protoS2/s8fixtures.luau → out_s8fixtures.txt: 'F1 ArmingSword S8 intent N/N/H | S2 pipeline N/H/H | … Hammering G 0.157 m 0.10 D 0.242'; 'F2 MinimalSword … errors[OUT_OF_HITBOX:1]'; 'F4 Cleaver S8 intent H/H/N | S2 pipeline H/N/H'; 'F3 Rapier … mass 0.3395' (= 0.0432 stud³ of Steel). S8 §14.7.1: 'room for 1.2 studs below O (F3 spans y ∈ [−1.18, 3.78])'. S8 §14.7.2: F2 pommel '(0, −1.15, 0) … 0.30 × 0.30 × 0.30'; F3 blade '0.07 × 3.40 × 0.035'.

**Proposed fix.** S8: make F3's blade and tip 0.05 thick (MIN_DIM) and re-derive its §14.7.3 values. Raise F2's pommel by 0.10 (or use per-fixture origins) so that FIXTURE_ORIGIN = (0, 1.2, 0) fits all four fixtures. The §14.7.4 intents become S2's computed tiers (F1 N/H/H, F4 H/N/H) unless the designer rejects S2's calibration target (S2 decision #7), in which case S2 re-fits. Owner S8, with S2.


### R4a-17 [minor/testing] S2's 'translation is exact' and its proposed 1e-9 invariance tolerance do not hold, and dust specks change difficulty although S8 expects bit-identical results

Sections: S2, S8 | needsUserDecision: False | confidence: high

**Problem.** Surface samples that fall exactly on coincident seams (for example the blade's top face under the two tip wedges' shared face) are hidden or not depending on floating-point rounding, and that rounding changes after a translation: a 0.125-stud shift moves SC_all from 2.2472 to 2.2454. S2's own table shows the translated sword at Hammering 0.181 against 0.182. Separately, cleaned parts still hide surfaces (§4.4), so dust specks touching the blade lower SC, while S8 A14 and T-DIF-04 require bit-identical difficulty.

**Evidence.** R4a/protoS2/transchk.luau → out_transchk.txt: 'baseline SC_all 2.247196 … exposedAll 3.021914'; 'translate (0.1250,0.0000,0.0000) SC_all 2.245412 … exposedAll 3.019514'. out_perturb.txt: 'max |dD| over translations: Sm 0.0000 Ham 0.0007 Sh 0.0010'; '+6 dust specks on the blade face … Ham 0.1784N Sh 0.1742N' (plain 0.1815/0.1787). S2 §17-S2: 'tolerance 1e-9 for invariance pairs'. S2 §5.7: 'translation is exact'. S8 A14: 'all difficulty outputs bit-identical to F1'.

**Proposed fix.** S2: every boundary predicate uses a signed epsilon EPS_GEOM = 1e-7 (hidden iff sd ≤ +EPS_GEOM, inside iff sd < −EPS_GEOM, raster coverage per R4a-02). S2 states invariance as |ΔG| ≤ 0.002 for translation, segmentation and rotation, not 1e-9, and keeps 1e-9 only for the analytic mass, COM and reach of non-overlapping designs. S8 A14 / T-DIF-04: dust on surfaces → |ΔG| ≤ 0.005; fully enclosed parts and exact duplicates stay bit-identical (measured: '+2 enclosed blocks' gives identical results). Owners S2 and S8.


### R4a-18 [minor/conflict] The hitbox containment tolerance differs across S1 (≥ 1e-3), S2 (1e-4) and S8 (1e-6, with '1e-3 beyond → reject')

Sections: S2, S1, S8 | needsUserDecision: False | confidence: high

**Problem.** S1 requires that 'every geometric tolerance … ≥ 1e-3 stud = 10× the canonical bound. Recommended: ε = 1e-3'. S2 sets EPS_CONTAIN = 1e-4, while S1's canonicalization can move a corner by up to about 9.9e-5 inside S2's hitbox (5e-5 + √3·2.5e-5 + 2e-6 rad × 2.64 stud), a 1 % margin. S8 A04/A05 test 'inclusive, ε = 1e-6' and '1e-3 beyond → reject'. Three implementations of the hitbox test would disagree on parts flush with the hitbox wall.

**Evidence.** S1 §3.4, point 4 (quoted above). S2 §3.5: 'Containment tolerance EPS_CONTAIN = 1e-4 studs'. S8 §14.7.5: A04 'accept (inclusive, ε = 1e-6)'; A05 'face 1e-7 beyond → accept; 1e-3 beyond → reject'. R4a/protoS1/out_canon.txt: 'max corner displacement per axis … = 9.056e-05 stud' (measured in S1's larger placeholder hitbox).

**Proposed fix.** S2 owns EPS_CONTAIN: 1e-3 if S1 keeps quantization, 1e-4 if transforms become raw doubles (R4a-01). S8 A04/A05 reference S2's constant: flush → accept; 0.5·EPS_CONTAIN beyond → accept; 2·EPS_CONTAIN beyond → reject. Owner S2, with S1 and S8.


### R4a-19 [minor/conflict] D_s quantization is defined three ways: S1 rounds to 1e-4 before tierFor, S2 does not round, S4 stores 1e-3 in the history

Sections: S2, S1, S4 | needsUserDecision: False | confidence: high

**Problem.** S1 §2.9/§9.5: tierFor works on D 'already quantized to 1e-4', stored as k/1e4. S2 §5.1 maps the raw D to a tier. S4 §7.6's CraftStepRecord stores 'difficulty … quantized to 1e-3'. A D of 0.19996 plays Normal under S2 but is stored as 0.2000 (S1) or 0.200 (S4), which reads as Hard. Any display or recompute from the stored value then disagrees with the tier that was played.

**Evidence.** S1 §2.9: 'tierFor(D) = … (D ∈ [0, 1], already quantized to 1e-4)' and '> Assumes (S2): S2's tierFor … quantizes D to 1e-4 first'. S2 §5.1: 'tierRaw = highest tier with minD <= D_s' (no quantization). S4 §7.6: 'difficulty: number, -- D_s at open, quantized to 1e-3'. S4 §8.6.3: 'DifficultyGrid = 1000'.

**Proposed fix.** S2 §5.1: D_s ← quant(D_s, 1e-4) (Quantize.q) before tierFor and before D leaves the analysis. S4 stores that same value (DifficultyGrid = 10000). Owner S2, with S4.


### R4a-20 [minor/conflict] S2's MIN_DIM clamp exists only inside the analysis: S1 stores (and S7 renders) sizes down to 1e-4, so the stored part is not the analysed part

Sections: S2, S1, S7, S8 | needsUserDecision: False | confidence: high

**Problem.** S2 §3.5 rule S5 clamps every size component to [0.05, 6.0] before analysis ('editor clamps identically'). S1 §3.5 accepts 0 < v ≤ 64, quantizes, and stores any value ≥ 1e-4. S7 renders Size as stored. A client, or a bug, that sends 0.03 gets a 0.03 part rendered but a 0.05 part weighed and measured; in my test, two 0.03 plates analysed as 0.05 added 7 % to the sword's mass. S8 A11 expects 'reject BadSize' instead. Separately, SIGMA_HI = 130 cannot be reached by Block blades, because τ ≥ MIN_DIM gives σ ≤ 5.0/0.05 = 100 and φ ≤ 0.667; only wedge edges can saturate Thinness. That is fine, but the spec should say so.

**Evidence.** S2 §3.5 row S5: 'each size component clamped to [MIN_DIM, MAX_DIM] = [0.05, 6.0] | clamp (editor clamps identically)'. S1 §3.5 check 9: 'Size: 3 finite numbers, 0 < v ≤ SIZE_MAX (64 stud) → quantize → ≥ 1e-4'. S8 A11: 'size component 0, −0.2, or below MIN_DIM | reject BadSize'. R4a/protoS2/out_perturb.txt: 'blade as 2 laminated 0.03 plates … V 0.11360 … mass 0.8941' (plain 0.8350). out_perturb2.txt: 'blade as 5 strips of width 0.040 … V 0.11360'.

**Proposed fix.** Apply one rule in S1's Canonical.part hook for S2 (S1 §3.5 check 11) before storage, so that stored = analysed = rendered: sizes below MIN_DIM are clamped to MIN_DIM, or rejected (S2 picks; clamping matches 'editor clamps identically'). S8 A11 asserts whichever rule is chosen. S2 notes the Thinness ceiling for Block blades in §5.3. Owner S2, with S1 and S8.


### R4a-21 [minor/clarity] S2's text leaves open sampling details that change factor values, so two conforming implementations cannot share bit-exact goldens

Sections: S2, S8 | needsUserDecision: False | confidence: high

**Problem.** S8 wants exact client/server equality, and S2 offers its tables as goldens, yet several definitions allow two implementations. (1) Thinness: 'C(s, d) … over all parts of W_s (kept + cleaned)', while §5.1 defines W_s as kept parts only; the prototype uses all parts of the set's slots. (2) The Cylinder's 'radial' thin axis could be local Y or local Z, which gives different chords for off-axis probes. (3) The volume-sample loop order and cell-centre formula are unspecified, yet they decide which samples the Thinness and Asymmetry strides pick. (4) The cylinder-lateral '8/16/32 directions by circumference' rule and the ball's cube-sphere grid size are unspecified. (5) It is unclear whether ê_p is renormalized after projection onto XY. Each choice changes x_f at the 1e-3 to 1e-2 level; for example, the stride phase moved Thinness by 0.0085 in the pommel test.

**Evidence.** S2 §5.2: 'C(s, d) = length of the union chord through s along d over all parts of W_s (kept + cleaned)' vs §5.1: 'W_s = kept parts whose slot is in the step's working set'. §5.2: 'θ_owner = owner's thinnest local axis (Cylinder: axis if 2hx <= 2r else radial …)'. §4.3: 'stratified grid in the local frame: n_k = clamp(ceil(size_k / h), 2, 48)'. Prototype choices: proto/S2/analyze.luau's Thinness uses S.Wall (kept and cleaned parts of the set) and radial = local Y (p.vx, p.vy, p.vz); shapes.luau's volumeSamples loops X → Y → Z with cell centres at −h + (i + 0.5)·2h/n.

**Proposed fix.** S2 pins each choice in the text, using the prototype's choices: the chord set is all kept and cleaned parts whose slot is in the step's set; radial = local Y; loops run i (local X) outermost, then j (Y), then k (Z), with cell centres at −h_k + (i + ½)·2h_k/n_k; the cylinder-lateral and ball-grid counts are written down as the prototype computes them. Alternatively, S2 declares the prototype modules normative and names them as the reference for S8's goldens. Owner S2.


### R4a-22 [minor/ux] S1 promises swords of about 1.3 kg, but S2's reference arming sword displays as 0.84 kg

Sections: S1 | needsUserDecision: True | confidence: high

**Problem.** S1 anchors Iron at 7.87 mu/stud³ so that '1 mu reads like 1 kg', based on its own example: a 0.30 × 3.60 × 0.08 blade sword of 1.32 kg, which is 5.05 studs long and would not fit S2's 5.0 hitbox. S2's slimmer reference designs weigh 0.835 'kg' (arming sword), 0.42 (rapier), 0.34 (dagger) and 1.52 (greatsword), whereas real arming swords weigh 1.1–1.5 kg and rapiers about 1.0–1.4 kg. The designer reads one number in §2.5 and §17 and will see a different one in game.

**Evidence.** S1 §2.5: 'Mass = 1.32 mu, shown "1.32 kg" (a real arming sword weighs 1.1–1.5 kg)'. S1 §17 Q5: 'a typical sword ≈ 1.3 kg'. S2 §5.7 masses: 'Arming sword (Iron) … 0.835', 'Rapier … 0.417', 'Dagger … 0.345', 'Greatsword … 1.521'.

**Proposed fix.** This is the designer's call (S1 decision 5). Option 1: keep 'kg' and quote S2's reference masses in §2.5. Option 2: add a display-only factor MASS_DISPLAY_SCALE = 1.5 in Balance.Display (arming sword 1.25 kg, greatsword 2.3 kg), excluded from the BALANCE_VERSION hash, with physics and S4's MassRef unchanged. Option 3: show the abstract unit instead of kg. Owner S1.


### R4b-07 [minor/bug] No client-side rule keeps honest input within the timeline limits; two cases become Invalid (craft aborted, Hard strike)

Sections: S3, S6, S5 | needsUserDecision: False | confidence: medium

**Problem.** (a) PrecisionTrace writes one record per 20 ms due time plus one per grind transition. A 31 s trace (600 + 30,000 + 400 ms) already uses 1,550 records, so clicking the grind button about 10 times/s at >= 144 fps exceeds the 2,048 cap (2,061 records at 240 fps; break-even 8.0 clicks/s). Nothing says what the client does at the cap, and S5 aborts the craft on a decode failure. (b) HoldZone's 'Focus loss records up' can emit an up while the OR-state is already released (or a stale up after re-focus), which decode rejects as NotAlternating. The other caps are fine: HoldZone at 28 presses/s for 18 s = 1,006 records (< 1,024; 30/s is flagged anyway); TimingStrike mashing at 30/s over the 17.1 s MVP maximum = 511 (< 512).

**Evidence.** S3 §6.10.4 'A record is also taken at every grind (LMB) transition'; §6.8.5 'Focus loss records up'; §6.7 NotAlternating; S5 §7.P4 step 7 'Failure → abort InvalidInput, E_INVALID_INPUT, Hard strike'. `python review/R4b/caps.py` → out/caps.txt.

**Proposed fix.** S3 §6.6/§6.10.4 (S6 implements). Grind transitions do not create records; the grind flag is sampled on the 20 ms schedule. Evaluation already uses 20 ms ticks, so scoring changes by at most one tick, and Trace is bounded at durationMs/20 + 1 = 1,551 records. Set MAX_RECORDS.PrecisionTrace = 1,600 (11,212 B). HoldZone: emit a HoldRecord only when the OR-state actually changes. Focus loss forces the OR-state to released (records up only if it was down) and resets per-key state, so a key still held after re-focus does not count until a new InputBegan. State the invariant 'an unmodified client never produces a timeline that decode rejects'; S8 adds a property test with 240 fps frames and 10 clicks/s.


### R4b-08 [minor/numbers] PrecisionTrace long paths: the 30 s clamp silently speeds up the pacer, and generation/replay exceed the stated 7.5 ms / 5 ms

Sections: S3, S5, S8, S2 | needsUserDecision: False | confidence: medium

**Problem.** travelMs is clamped to 30 s but path length L is not bounded, so for L > 9 u (Normal) the pacer runs faster than pacerSpeed. Realistic serrated blades stay below that (pitch 0.10, depth 0.10 → L 7.86, 26.2 s) but already cost 9.3 ms (max 13.4) to generate and 6.0 ms (max 7.2) to decode, replay and check. S3 states '<= 7.5 ms', and S5/S8 budget 5 ms for replay. An extreme saw edge gives L 16.6 u, a pacer at 0.553 u/s (1.84× base) on Normal, 41–52 ms generation (O(n²) clearance) and 8–10 ms replay. Pattern generation runs on the server at StartStep and appears in no S5 budget. Also, S2 exposes EdgeProfile.chains (CCW outline chains sorted by length) while S3 consumes 'sides' ordered base → tip, so the path S3 builds from S2's output (and hence L) is undefined.

**Evidence.** S3 §6.10.2 step 9 'travelMs = clamp(..., 6000, 30000); speed = L / (travelMs/1000)'; §6.12.4 'Pattern generation takes ≤ 7.5 ms'; S5 §10.13 'replay ≤ 5 ms (Assumes S3)'; S8 §16 REPLAY_BUDGET_MS = 5; S2 §4.6 'chains: sharpenable edges, longest first'. `lune run review/R4b/protoS3/pt_stress.luau` → out/pt_stress.txt; `lune run review/R4b/protoS3/pt_cost.luau` → out/pt_cost.txt.

**Proposed fix.** S3: bound the path. If L > PT_TRAVEL_MAX_MS/1000 · pacerSpeed, decimate the source further (or scale the cross-axis exaggeration E down) until it fits, so the speed never exceeds pacerSpeed. Replace the O(n²) clearance with a uniform grid (cell = CLEAR_SKIP) and publish costs at the maximum duration (31 s), targeting generate <= 5 ms and decode + replay + checks <= 8 ms. S5: run StartStep pattern generation through the same per-Heartbeat work queue as S2 analyses, and set the replay budget from S3's 31 s figure; S8's REPLAY_BUDGET_MS follows. S2 and S3 agree the edge handoff: S3 consumes S2's EdgeProfile.chains[1] as the ordered path, or S2 provides base → tip sides.


### R4b-09 [minor/exploit] ReportDesync gives a free seed re-roll; S5 has no such remote and forbids re-rolls

Sections: S3, S5 | needsUserDecision: False | confidence: high

**Problem.** S3 re-issues a desynced step once with a new seed. Pattern generation is pure and identical on both sides, so a real desync can only come from a version mismatch. Any modified client can instead claim desync on a pattern it dislikes (it knows the pattern from the seed) and get a second seed for every step. S5 states that seeds are never re-rolled, and its remote catalogue has no ReportDesync.

**Evidence.** S3 §6.4.4 'sends ReportDesync, and the server re-issues the step once with a new seed'; S5 §7.P3 'fixed for the step (re-open returns the same seed: no re-roll)'; S5 §10.3 catalogue lists only Begin/StartStep/Submit/Abandon/Resume for Craft.

**Proposed fix.** S3 + S5. On ReportDesync the server re-sends the same StepStart (same seed, params and deadline) once. A second desync aborts the craft with 'version mismatch, please rejoin' and logs minigame_desync {clientHash, serverHash, balanceVersion}. Never issue a new seed. S5 adds `Craft.ReportDesync {sessionId, stepIndex, clientHash}` (bucket 3, 1/10 s) or folds it into the idempotent StartStep re-open.


### R4b-10 [minor/numbers] A Steel sword with one Hard step is a near-guaranteed Epic for skilled players; S4 only checks that target for Iron

Sections: S4, S8 | needsUserDecision: False | confidence: high

**Problem.** T9 ('one Hard step is not a guaranteed Epic', <= 60%) is evaluated only for Iron. With Steel's T = 1.10, the same cell gives 83% Epic in S4's own model and 84% for S3's good bot (Iron: 48% / 21%). A full-Steel sword with one long edge is therefore the dominant recipe for Epic.

**Evidence.** S4 §8.5.2 T9 'Excellent, Mixed-1, Iron | Epic ≤ 60 %'; review/R4b/out/s4_compact.txt 'Excellent | Mixed-1 (Sharp H) | ... | 0 / 0 / 17 / 83' (Steel); `python review/R4b/steel_epic.py` → out/steel_epic.txt (good 1×Hard Steel 84%; Epic minQuality needed for <= 60%: 0.951; Steel qualityTier 1.08 / 1.06 / 1.05 → 72 / 55 / 46%).

**Proposed fix.** S4: add a T9-Steel target (Excellent / Mixed-1 / Steel Epic <= 60%) and re-tune. Candidates: Epic.minQuality 0.92 → 0.95, or Steel qualityTier 1.10 → 1.06. Re-run `sim.luau tune` and R4b-02's distribution-driven check, then update §8.3.2/§8.4.1, S8's golden cases and S6's 'Quality ceiling' examples (the all-Hard Steel ceiling becomes 133 instead of 138 if T = 1.06).


### R4b-11 [minor/testing] S8's anti-cheat tests cannot verify S3's <= 1e-5 false-positive claim and test thresholds that differ from S3's

Sections: S8, S3 | needsUserDecision: False | confidence: high

**Problem.** S8 runs 20,000 human runs per profile (0 flags ⇒ < 1.5e-4 at 95%), 15× too few to support S3's <= 1e-5 per-step claim. S8's calibration constants also differ from S3's rules: S8 tests TS SD < 2 ms over >= 8 strikes and trace lateral SD < 0.5 px over >= 60 samples; S3 defines TS SD < 1.5 ms plus ExactHits, and trace mean cross-track distance < 0.0008 u over >= 40 samples plus TooSmooth. S3's claim itself holds. Re-running S3's fp mode with 200,000 runs gives 0 flags for elite / elite240 / good at Normal and Hard (the stored out_fp_pt.txt had only 1,000 runs per row). The analytic 1.1e-5 recomputes, and frame quantization at 30/60/240 fps only adds error variance (>= 4.8 ms SD at 60 fps).

**Evidence.** S8 §16 'FP_RUNS = 20000 ... (0 => < 1.5e-4 @95 %)', 'TS_INHUMAN_SD_MS = 2', 'TRACE_INHUMAN_SD_PX = 0.5'; S3 §10.M5 'false-positive rate ... ≤ 10⁻⁵ per step'; `lune run run_all.luau fp 300 2000 150 200000 600` → review/R4b/out/s3_fp.txt.

**Proposed fix.** S8 tests S3's constants read from Definitions/MinigameFamilies.checks (no S8 copies) and sizes the FP runs to the claim. TimingStrike: FP_RUNS_TS = 300,000 per profile (0/300k ⇒ < 1e-5 at 95%; about 10 s in Lune at ~0.03 ms per generate + replay). Trace and HoldZone keep 20,000 runs plus a margin assertion: min observed mean deviation >= 4 × PT_PRECISE_MEAN_DEV, and max presses per 1 s <= HZ_RATE_MAX_PRESSES / 3. Include a 30 fps / 360 px case and the pumping bot from R4b-04. S3 states the SD estimator (R4b-13).


### R4b-12 [minor/bug] Score-mismatch check compares the client's unclamped score with the clamped server score; thresholds and names differ

Sections: S3, S5 | needsUserDecision: False | confidence: high

**Problem.** The client's live session never runs the inhuman-input checks. Whenever a HIGH flag clamps the server score to 0.50, the client's provisional score differs, and a 'mismatch' (described as a bug or tampering) is logged for every flagged step. S3 uses |Δ| > 0.00005 and minigame_score_mismatch; S5 uses 1e-9 and ScoreMismatch, compared against `score`.

**Evidence.** S3 §6.4.4 'If |clientScore − serverScore| > 0.00005 ... A mismatch means a bug, or a tampered client'; S3 §10.M1 step 6 (clamp); MinigameResult.rawScore 'before the flag clamp'; S5 §7.P4 step 9 '|clientScore − score| > SCORE_MISMATCH_EPS (1e-9) → Soft flag ScoreMismatch'.

**Proposed fix.** S5 §7.P4 step 9 compares clientScore with S3's rawScore. Both sections use one rule: scores are round4 values, so mismatch ⇔ clientScore ≠ rawScore exactly. Use one event id: S5's ScoreMismatch Soft flag carrying S3's minigame_score_mismatch fields. The client shows the clamped server score without a 'mismatch' state.


### R4b-13 [minor/clarity] The text allows two implementations of several determinism-relevant details (matters for S8's text-derived oracles and goldens)

Sections: S3 | needsUserDecision: False | confidence: high

**Problem.** Re-implementing from the text exposed five ambiguities. (a) Score sums: Python 3.12's compensated sum() gives a different round4 result for 6 of 2,700 TimingStrike timelines (0.9588 vs 0.9587; the naive sum is 14.381249999999998). The text says 'index order' but not 'plain left-to-right IEEE double, no compensated or pairwise summation'. (b) TS_LowVariance's 'SD': the prototype uses the sample SD (n−1); the population SD raises the analytic FP at n = 8, σ = 10 ms from 1.1e-5 to ≈ 1.8e-5. (c) Rng.new(seed, nil): the prototype treats nil as ''. (d) PrecisionTrace 'normal_i = perp(...)' has no stated sign, and the speed 'primed at the first tick' is not defined; the prototype uses (−dv, du) and cursorAt(t₁ − 20). (e) The HoldZone reference curve 'T(0.5 s) = 0.245' is the state after the tick ending at 510 ms (after 500 ms it is 0.238), and the heat-then-release peak is 0.725 at ≈ 1.36 s, not 0.714 near 1.5 s. With these fixed, my independent implementations match the prototype exactly (TimingStrike 2,700/2,700, HoldZone 244/244, all PRNG vectors).

**Evidence.** `python review/R4b/ts_crosscheck.py` → out/ts_crosscheck.txt (6 different with sum()) and out/ts_crosscheck_naive.txt (0 different); proto/S3/TimingStrike.luau `sd = math.sqrt(ss / (n - 1))`; `python review/R4b/hz_indep.py` → out/hz_indep.txt; S3 §6.8.3 reference-curve table; §6.10.2 step 4 'normal_i = perp(p_{i+1} − p_{i−1})'.

**Proposed fix.** S3 adds: §6.4.2 'all accumulations are plain left-to-right IEEE-754 double additions; no compensated or pairwise summation'; §10.M4 'SD = sample standard deviation (divide by n−1)'; §6.3 'tag nil ≡ ""'; §6.10.2 'normal = (−Δv, Δu)/|Δ| (left normal)'; §6.10.4 'speed at tick 1 uses c(t₁ − 20 ms); nil gives no coverage'; §6.8.3 'T(t) = temperature after integrating every tick with 10k ≤ t', with the corrected peak values. S8's oracles follow these rules.


### R5a-10 [minor/platform] Path2D has no script-accessible transparency and no fill; S6's alpha values and blade silhouette are not implementable as written

Sections: S6 | needsUserDecision: False | confidence: high

**Problem.** S6 gives Path2D strokes alpha values (dial window arcs, trace band, core line) and draws a 'blade silhouette at 15 % opacity'. Path2D exposes only Closed, Color3, Thickness, Visible and ZIndex; it renders a stroked curve and cannot fill. It is also unverified whether an ancestor UIScale scales Path2D.Thickness. S6 computes the band thickness from AbsoluteSize, so the drawn band could differ from the scored band.

**Evidence.** S6 §12.5: 'Window arcs | Ok (111, 168, 220) α0.5 thickness 18, Good (123, 216, 143) α0.2 ... `next` window as a ghost arc α0.85'. S6 §12.6: 'band = Path2D strokes ... (159, 179, 200) α0.65', 'Core line ... α0.3', 'silhouette at 15 % opacity'. Docs Path2D: 'renders a stroked curve'; properties Closed, Color3, Thickness ('in pixels ... clamped to the range [0, 100]'), Visible, ZIndex. Probe: reading Path2D.Transparency fails with 'The current thread cannot read 'Transparency' (lacking capability RobloxScript)'; Thickness←150 reads back 100.

**Proposed fix.** S6 §12.5/§12.6: Path2D strokes are opaque. Replace every alpha with a pre-blended opaque Color3 against the widget's fixed background. Where real translucency is needed, put the strokes under one CanvasGroup per widget (GroupTransparency), or first test a child UIGradient.Transparency in Studio. Draw the blade silhouette as a ViewportFrame of the blade (ImageTransparency 0.85) or as an outline stroke. Draw the ring track as a Frame with UICorner(0.5) and UIStroke, and arcs with tangent control points (4 per full circle) instead of a 6° polyline. Keep each Path2D at ≤ 50 points with one shared point between consecutive instances. Compute the band thickness in the Path2D's pre-UIScale units, or keep the trace canvas outside any UIScale. S8 adds a screenshot check that the band width equals 2·halfWidth·H ± 1 px at UI scales 0.75 and 1.0.


### R5a-11 [minor/platform] TextSize is capped at 100: 160-px countdown numerals are impossible as specified

Sections: S6 | needsUserDecision: False | confidence: high

**Problem.** The countdown numerals are 160 design px and the display token scale includes 160. TextLabel.TextSize, UITextSizeConstraint.MaxTextSize and TextScaled all cap at 100, so the numerals would render at 100 px or less.

**Evidence.** S6 §12.2 'Countdown(i) | numerals 160 px `font.display`'; §12.8.3 'Sizes (design px): display 48 / 64 / 160'. Probe: TextLabel.TextSize←160 reads back 100; UITextSizeConstraint.MaxTextSize←160 reads back 100. Docs TextLabel: TextScaled scales 'the font size up to the maximum font size (100)'.

**Proposed fix.** S6 §12.8.3: text above 100 design px uses a local UIScale, e.g. countdown numerals at TextSize 80 under a UIScale of 2.0, with the 1.3 → 1.0 pop animated on that UIScale (2.6 → 2.0). State the rule 'TextSize ≤ 100; larger text uses a local UIScale' with the type tokens.


### R5a-12 [minor/conflict] Editor lighting profile ignores S7's Atmosphere and ColorCorrection; its FogEnd setting has no effect

Sections: S6, S7 | needsUserDecision: False | confidence: high

**Problem.** S6's EditorStudio profile sets FogEnd and turns off DepthOfField and SunRays. S7 adds an Atmosphere (Density 0.26, Haze 1.2) and a warm ColorCorrectionEffect to Lighting. While an Atmosphere exists, Fog properties are ignored, and Atmosphere has no Enabled switch. The blueprint-blue stage, 20–120 studs from the camera, would be hazed and warm-tinted, and Iron/Steel colours would read off.

**Evidence.** S6 §11.4.3: 'Lighting profile EditorStudio | ... FogEnd=1e5 ... post-effects off (DepthOfField, SunRays), Bloom ≤ 0.3'. S7 §13.12.2: 'Atmosphere | Density 0.26, Offset 0.1, Color (199, 170, 146), Decay (110, 86, 70), Glare 0.2, Haze 1.2'; 'ColorCorrectionEffect | Brightness 0.02, Contrast 0.08, Saturation 0.05, TintColor (255, 244, 232)'. Docs Atmosphere: 'Fog properties are hidden when Lighting contains an Atmosphere object'; its properties are Color, Decay, Density, Glare, Haze, Offset. Probe: 'Enabled is not a valid member of Atmosphere'.

**Proposed fix.** S6 §11.4.3 profile: locally set Atmosphere Density/Haze/Glare to 0, ColorCorrectionEffect.Enabled = false, SunRaysEffect.Enabled = false and BloomEffect.Intensity ≤ 0.3, all restored on exit; drop FogEnd. S7 §13.12.2 names its Lighting children in Definitions/World (e.g. BS_Atmosphere, BS_Grade, BS_Bloom, BS_SunRays) so S6 finds them without guessing; the 'no other client script drives Lighting while the editor is open' contract stays.


### R5a-13 [minor/platform] ItemModelBuilder sets ModelStreamingMode by default, including from client code, which the docs forbid

Sections: S7, S6 | needsUserDecision: False | confidence: high

**Problem.** ItemModelBuilder is shared and used on the client by S6 (editor parts, mountInViewport thumbnails, results card, inspect clones). BuildOptions.atomic defaults to true, which sets ModelStreamingMode.Atomic. The docs say the property must never be changed from LocalScripts (undefined behaviour).

**Evidence.** S7 §13.8.6: 'ItemRender/ItemModelBuilder.luau (Roblox-bound; server and client)', 'atomic: boolean?, -- default true: ModelStreamingMode.Atomic'; S6 §11.7.3/§12.2.1 use buildPart/mountInViewport on the client. Docs Model.ModelStreamingMode: 'This property should only be changed in Studio ... or in Scripts, but never in LocalScripts (doing so can result in undefined behavior).'

**Proposed fix.** S7 §13.8.6: the builder writes ModelStreamingMode only when RunService:IsServer() (and, per R5a-08, only when workspace.StreamingEnabled is true); BuildOptions.atomic is ignored on the client. Document it in the BuildOptions comment.


### R5a-14 [minor/platform] ViewportFrame count and turntables: Items/Choose grids are not virtualized, and turntables move the model instead of the camera

Sections: S6, S7 | needsUserDecision: False | confidence: medium

**Problem.** The Library builds thumbnails 'only for visible rows', but the Items panel (up to 150 items) and the Choose card grid specify a thumbnail per entry with no virtualization. That could mean up to 150 live ViewportFrames, each with up to 24 parts, a WorldModel and a Sky. The turntables (S6 library 20°/s, S7 inspect 24°/s) rotate the model, while the docs advise moving the camera instead.

**Evidence.** S6 §12.2.2: 'Items panel ... grid of the player's items (S1 MAX_ITEMS = 150): VIEW_H thumbnail'; S6 §11.20: 'built only for visible rows and cached per (id, Revision)'; S6 §11.20 '480×300 turntable ViewportFrame, 20°/s'; S7 §13.8.7 'slow turntable about the blade axis at 24°/s'. Docs viewport-frames guide: 'When you want to update the view of your ViewportFrame, be sure to update the camera, not the objects within the view.'

**Proposed fix.** S6 §12.2.2/§12.8.5: apply the Library rule to every item and blueprint grid. Only visible tiles get a ViewportFrame, with at most 24 live (pooled and reused on scroll); thumbnails are static. S6/S7 turntables orbit the viewport Camera around the item and leave the model fixed, which also keeps the Sky reflection consistent.


### R5a-15 [minor/numbers] The '1/20 pixel' argument for invisible storage quantization does not hold on S6's enlarged editor (≈0.46 px)

Sections: S1, S6 | needsUserDecision: False | confidence: high

**Problem.** S1 justifies its 1e-4 stud storage grid, a [Decision to confirm] close to user decision 1, as '≤ 1/20 pixel at the closest editor zoom', based on a 3-stud, 70°, 1920-px camera. S6's editor magnifies the sword ×4 with a 1-display-stud minimum distance at FOV 50°. At maximum zoom that is 4632 px per blueprint stud, so 1e-4 stud is 0.46 px and S1's measured maximum corner move (9.06e-5) is 0.42 px. The change stays sub-pixel, but the figure the designer reads is about 9x too optimistic.

**Evidence.** S1 §3.4 property 3: 'one screen pixel at the closest editor zoom (≈ 3 studs, 70° FOV, 1920 px) ≈ 2.2e-3 stud, so the change is ≤ 1/20 pixel'; 'measured max 9.06e-5'. S6 §11.4.1 table, k = 4 row: '0.05-bp detail at max zoom | 231.6 px' → 231.6/0.05 = 4632 px per bp stud.

**Proposed fix.** S1 §3.4: restate as '≤ 0.5 px at the editor's maximum zoom (S6's ×4 stage), invisible at normal zoom'. The conclusion and the default are unchanged. S6 §11.7.1's '1e-4 stud is ≤ 1/20 pixel' sentence takes the same correction.


### R5b-14 [minor/platform] luau-lsp commands: --definitions must be the named form, and the sourcemap lacks --include-non-scripts

Sections: S8, S5 | needsUserDecision: False | confidence: high

**Problem.** S8's pass A uses '--definitions=tools/luau-lsp/globalTypes.None.d.luau'. Since luau-lsp 1.56.0, definitions must be named ('--definitions:@roblox=PATH'); the plain form is kept only temporarily, with random names. S8 also generates test.sourcemap.json without --include-non-scripts, which S5 requires so Blacksmith.Remotes.* is typed. Without the flag the 4 RemoteEvents are absent from the sourcemap. strictDatamodelTypes defaults to false since 1.26.0, so this degrades typing rather than raising errors. Since 1.65.0, string requires are sourcemap-aware in Roblox mode, and 1.67.0 fixed them for analyze with a sourcemap.

**Evidence.** S8 §14.4: `rojo sourcemap test.project.json --output test.sourcemap.json` / `luau-lsp analyze --platform=roblox ... --definitions=tools/luau-lsp/globalTypes.None.d.luau ...`. luau-lsp CHANGELOG 1.56.0: "Definitions files must now provide a name ... `--definitions:@roblox=path/to/globalTypes.d.luau`"; editors/README: "--definitions:@name=PATH". rojo sourcemap without the flag: 0 RemoteEvent entries; with --include-non-scripts: present.

**Proposed fix.** Pass A becomes `rojo sourcemap test.project.json --include-non-scripts --output test.sourcemap.json` and `luau-lsp analyze --platform=roblox --sourcemap=test.sourcemap.json --definitions:@roblox=tools/luau-lsp/globalTypes.None.d.luau --ignore="vendor/**" --formatter=plain src tests/studio`. Pin luau-lsp ≥ 1.67.0 (named definitions plus sourcemap-aware string requires). Download globalTypes.None.d.luau from the pinned tag's scripts/ folder (it exists on main). V-01 still confirms --formatter.


### R5b-15 [minor/testing] S8's purity scan (T-META-02) would fail on legitimate Roblox-bound modules placed in src/shared

Sections: S8, S5, S7 | needsUserDecision: False | confidence: high

**Problem.** T-META-02 treats all of src/shared except Net/ as pure and bans task., Instance.new and similar tokens. S5 puts the Roblox-bound Util/Signal.luau (task.spawn) in src/shared, and S7 puts the Roblox-bound ItemRender/ItemModelBuilder.luau there. BRIEF §4.1 allows explicitly marked Roblox-bound modules in src/shared. As written, the L1 gate fails on day one.

**Evidence.** S8 §14.4 T-META-02: "`src/shared/**` except `Net/` is pure: no ... `Instance.new` ... `task.`". S5 §1.3: "Util/Signal.luau (S5) RB tiny pub/sub (task.spawn dispatch)". S7 §13.1 table: "src/shared/ItemRender/ItemModelBuilder.luau | shared | Roblox-bound".

**Proposed fix.** Change T-META-02 to an explicit allowlist of Roblox-bound modules kept in tests/Meta, or honor a header line '-- @roblox-bound' right after '--!strict'. Initial list: Net/Remotes, Net/Client, Util/Signal, ItemRender/ItemModelBuilder. Add a check that no pure module requires a Roblox-bound one.


### R5b-16 [minor/bug] At every server shutdown, S5's OnSessionEnd handler kicks all players with the 'opened on another server' message

Sections: S5 | needsUserDecision: False | confidence: high

**Problem.** In live servers, ProfileStore's own BindToClose releases every active profile with reason 'Shutdown', and OnSessionEnd fires for each. S5's handler kicks with SESSION_ENDED unless the player is leaving. During shutdown players are still parented to Players, so everyone sees 'Your smithy was opened on another server' at each update or shutdown, preempting the CLOSING text and notice.

**Evidence.** S5 §9.L2: `if not isGone(player) then player:Kick(KICK.SESSION_ENDED) end`. ProfileStore.luau 2208–2230 (BindToClose → SaveProfileAsync(profile, true, nil, "Shutdown") for each active profile) and 716–726 (OnLastSave(reason) fires, then OnSessionEnd).

**Proposed fix.** Record the reason with profile.OnLastSave:Connect(function(r) lastReason[player] = r end). In OnSessionEnd, return without kicking when ProfileStore.IsClosing or lastReason[player] == "Shutdown" (the engine disconnects players; S5 already pushed Notice{ServerClosing}). Kick with SESSION_ENDED only for "External" or an unannounced steal (no OnLastSave).


### R5b-17 [minor/platform] The PLOT_COUNT ≥ Players.MaxPlayers boot check logs an error in every Studio session (MaxPlayers reads 30)

Sections: S5, S8 | needsUserDecision: False | confidence: high

**Problem.** Players.MaxPlayers can only be set on the Creator Dashboard; it is read-only from scripts and not serialized in place files. On an unpublished or unconfigured place, Studio reports 30, so S5's boot logs Log.error on every Play. S8's console hygiene fails on any error line.

**Evidence.** Studio probe (Edit, read-only): "MaxPlayers=30 Preferred=30", "PlaceId=0"; assigning MaxPlayers → "Unable to assign property MaxPlayers. Property is read only". Docs Players.MaxPlayers: "can only be set through a specific place's settings on the Creator Dashboard"; serialization can_save false. S5 §1.5: "asserts PLOT_COUNT >= Players.MaxPlayers (Log.error otherwise)". S8 §14.10.7: "Fail on any [Blacksmith][E] line".

**Proposed fix.** Log.error only when not RunService:IsStudio(); use Log.warn in Studio, and S8 lists that warning as expected. Add S8 precondition: the test place's Max Players is set to 8. Keep the live-server check, since it catches dashboard misconfiguration.


### R5b-18 [minor/platform] Place settings can be carried by the Rojo project; EnableMouseLockOption has no owner

Sections: S5, S6, S7 | needsUserDecision: False | confidence: medium

**Problem.** S5 calls the place settings 'not representable in the project file' and StreamingEnabled 'not scriptable, so set once in Studio'. S7 assumes the project sets no Workspace streaming properties. In fact Workspace.StreamingEnabled is serialized (can_save true), and rojo build writes it from $properties. S6 needs StarterPlayer.EnableMouseLockOption = false and assigns it to 'S5/S7', but neither sets it. Only MaxPlayers and PreferredPlayers are truly dashboard-only.

**Evidence.** Built review/R5b/rojo-alt with "Workspace": {"$className": "Workspace", "$properties": {"StreamingEnabled": false}} and StarterPlayer.$properties {"EnableMouseLockOption": false} → out_alt.rbxlx contains `<bool name="StreamingEnabled">false</bool>` and `<bool name="EnableMouseLockOption">false</bool>`. Docs Workspace.StreamingEnabled serialization can_load/can_save true. S6 §11: "Assumes (S5/S7): StarterPlayer.EnableMouseLockOption = false".

**Proposed fix.** S5's default.project.json declares Workspace $properties {StreamingEnabled: <R5b-09 decision>} and StarterPlayer $properties {EnableMouseLockOption: false}. Nodes without $path default to ignoring unknown instances, so existing Workspace content is untouched. Keep a README line to verify both in Studio after the first rojo serve (whether the live-sync plugin applies StreamingEnabled is unverified), and leave MaxPlayers and PreferredPlayers as dashboard settings.


### R5b-19 [minor/platform] Vendored ProfileStore build-phase risks not covered by S5 §9.L7

Sections: S5, S8 | needsUserDecision: False | confidence: high

**Problem.** (1) Whenever it is required in Studio, the module writes a real DataStore key (store '____PS') if API access is on, and prints 'Roblox API services available - data will be saved' even when DataService uses store.Mock. The S5 claim that 'playtests never touch live data' is not strictly true, and the print misleads the designer. (2) DataStoreState is 'NotReady' for a moment at Studio boot, so DataService.mode() logged at boot reports nothing useful. (3) Strict-mode types: StartSessionAsync's params is non-optional, and Profile<T>.Data is T & JSONAcceptable, so access needs casts. (4) Module-level singleton state (ActiveSessionCheck, MockFlag, AutoSaveList, a Heartbeat loop): MCP snippets or Actors that require it get a second, independent copy. (5) loadAsync can exceed LOAD_TIMEOUT_S by up to about 20 s, because Cancel is checked only between retries (backoff ≤ 20 s; conflict waits 5 or 10 s).

**Evidence.** ProfileStore.luau 2072–2104 (Studio probe `GetDataStore("____PS"):SetAsync("____PS", os.time())`, prints at 2095/2098), 1386 + 668–672 (WaitForStoreReady), 1004 (`params: {Steal: boolean?}`), 973 (`Data: T & JSONAcceptable`), 312–341 and 2115 (module state, Heartbeat), 1589–1590 and 1621–1622 (waits before re-checking Cancel). S5 §1.8: "Studio uses ProfileStore.Mock anyway | playtests never touch live data"; §1.5: `dataMode = DataService.mode()` at boot.

**Proposed fix.** S5 §9.L7 adds these bullets. DataService wraps ProfileStore with typed accessors (`profile.Data :: PT.PlayerData`, params cast `:: any`). DataService logs its mode after the first WaitForStoreReady (or polls until DataStoreState ~= 'NotReady'). README note: with Studio API access on, ProfileStore writes the '____PS' probe key and prints 'available'; Mock is still used. Rule: only DataService requires Vendor.ProfileStore; MCP snippets go through the bridge (S8 already does this) and never run inside an Actor. LOAD_TIMEOUT_S is documented as 'about 75–95 s'.


### R5b-20 [minor/platform] TextFilter's timed retry goes against the docs, and the cache key ignores renames

Sections: S5, S7, S1 | needsUserDecision: False | confidence: high

**Problem.** The docs say FilterStringAsync retries internally and must not be retried when it throws. S5 schedules one retry after 30 s. S5 caches per item id, while S1 and S7 key the cache by (author or item, raw text). S1 allows item renames but S5 excludes them, so a rename would show a stale filtered name. S7 also restates the filter rules (a 5 s budget, retry at the next claim), giving two owners of one behavior.

**Evidence.** S5 §10.8: "on failure the fallback stays, one retry after FILTER_RETRY_S = 30 s". Docs TextService.FilterStringAsync: "This method may throw if there is a service error that cannot be resolved. In such cases, do not retry the request, as this method implements its own retry logic internally"; "This method currently throws if fromUserId is not online on the current server". S7 §13.3.3: "Cache (itemId, raw) → filtered"; S1 §3.6 "cached ... per (authorUserId, raw)".

**Proposed fix.** S5's TextFilter is the single owner. Remove FILTER_RETRY_S; on failure, keep the fallback until the next natural trigger (the next Showcase.Place of that item, or the next session). Cache key = (itemId, raw). S7 references S5 instead of restating the rules. S1 and S5 settle 'item rename' in one place; if renames ship, the new raw text simply misses the cache.


### R5b-21 [minor/bug] Yielding mutating handlers can be overtaken (a deleted blueprint can be resurrected by an in-flight Save)

Sections: S5 | needsUserDecision: False | confidence: medium

**Problem.** Roblox orders remote handlers by start time only; a handler that yields lets the next message run first. Blueprint.Save yields in the AnalysisQueue and then upserts. If a Blueprint.Delete (or Rename) for the same id arrives meanwhile, it runs during the yield. The resumed Save re-checks only readiness and limits, then re-creates the deleted record or overwrites the rename. S5 guards this kind of race only for Craft.Begin ('begin in flight' flag).

**Evidence.** Docs remote events: "Ordering applies to when each handler starts, not when it finishes. If a handler yields ... Roblox can start handling the next message before the earlier handler resumes." S5 §1.7 save algorithm: "(5) AnalysisQueue.run ... (yields); (6) re-check isReady and the limit after the yield; (7) mutate upsert"; §7.P7 only Begin has an in-flight flag.

**Proposed fix.** Router serializes mutating handlers per player: a per-player FIFO, so one mutating action runs at a time while non-mutating ones run freely. Alternatively, Save carries the record's expected Revision (S1 BlueprintRecord.Revision) and the post-yield mutate refuses with E_WRONG_STATE when the record was deleted or its revision changed.


### R5b-22 [minor/gap] No server job for recomputing stale items (S1 assumes S5 provides one)

Sections: S5, S1, S2 | needsUserDecision: False | confidence: high

**Problem.** S1 has S5 recompute staleCheap items synchronously after Prepare and run staleGeometry items through a background queue with a per-frame budget. S5 defines neither. Its AnalysisQueue is capped at 16 with E_BUSY, which would refuse a 150-item re-analysis. GEOMETRY_VERSION = 1 at launch, so the job is dormant, but it must exist before S2's first bump.

**Evidence.** S1 §9.6: "Recompute scheduling (S5): staleCheap items synchronously after Prepare ...; staleGeometry items in a background queue with a per-frame budget". S5 §1.7 AnalysisQueue: "queue length > ANALYSIS_QUEUE_CAP (16) → (false, "E_BUSY")"; no recompute job in §1.5/§9.

**Proposed fix.** S5 adds a RecomputeJob. staleCheap items are recomputed inside loadAsync after Prepare (pure, < 5 ms). staleGeometry items go through the same checkpointed analysis worker (R5b-08) at low priority, one item per slice and not counted against ANALYSIS_QUEUE_CAP, each result written with DataService.mutate. Items show stored values until done.


### R5b-23 [minor/testing] M-06 and S-PAR-03 (real DataStore checks) cannot run in Studio while DATA_MODE is hard-wired to Mock

Sections: S8, S5 | needsUserDecision: False | confidence: high

**Problem.** S5's Config selects Mock whenever RunService:IsStudio() is true, including Team Test on a published place. S8's M-06 and S-PAR-03 want real persistence 'on the published test place with Studio API access'. They would silently test the Mock. Running Live in Studio inside the real experience would load the developer's real profile, because DataStores are scoped per experience.

**Evidence.** S5 §1.7 Config: `DATA_MODE = if IS_STUDIO then "Mock" else "Live"`. S8 §14.12 M-06: "Published test place with API access: craft, display, leave, rejoin from a new session"; §17 Q6 "published private test place with Studio API access".

**Proposed fix.** Run M-06 from the Roblox client on a separate, private test experience (live servers, IsStudio false, real DataStores of that experience only). For S-PAR-03 in Studio, S5 adds a Studio-only override such as ServerScriptService attribute BS_DataMode = "Live", honored only when IsStudio and only documented for that test experience. S8 states the test experience is a different universe from the game.


### R5b-24 [minor/architecture] Phase 3 'likes via ProfileStore:MessageAsync' would rewrite the whole profile key for every like

Sections: S5, S1 | needsUserDecision: False | confidence: high

**Problem.** Both drafts hook Phase 3 likes onto ProfileStore:MessageAsync. MessageAsync performs an UpdateAsync on the owner's profile key and appends to its GlobalUpdates (up to 1,000 queued messages). Each like therefore rewrites the full value, up to about 2 MB, against the 4 MB/min per-key write limit: about 2 likes per minute per owner across all servers, and offline backlogs grow the stored value.

**Evidence.** S5 §15: "cross-server delivery to the owner's profile via ProfileStore:MessageAsync + profile:MessageHandler"; S1 §15: "likes via ProfileStore:MessageAsync (Phase 3)". ProfileStore.luau 1633–1690 (MessageAsync → UpdateAsync(profile key), MAX_MESSAGE_QUEUE = 1000). Docs: per-key write 4 MB per minute.

**Proposed fix.** Reword the hook: likes go to a separate small store (for example a per-item counter key or an OrderedDataStore per category). MessageAsync is reserved for rare, small messages. One line in each §15.


### R5b-25 [minor/clarity] S5's §1.3 module tree and §1.7 calls use file and API names the owning sections do not define

Sections: S5, S1, S3, S7 | needsUserDecision: False | confidence: high

**Problem.** The union of all drafts' files builds cleanly with rojo 7.7.0-rc.1 (no name clashes; the Net/Remotes ModuleScript and the Blacksmith.Remotes Folder coexist). S5's architecture tree (SPEC §1) and its code, however, cite modules that do not exist. Implementers working from §1 would create the wrong files.

**Evidence.** S5 §1.3: "Blueprint/ (S1) pure Types, Sanitize (fromWire), Serialize, Names", "Persistence/ ... Template, Migrate, Types", "Minigames/ ... Rng, Registry, ...", "World/ (S7) WorldBuilder, Plot, Stations, ItemModel, Display"; S5 code calls S1.Sanitize.fromWire, World.claimPlot, ItemModel.build. Owners define Blueprint/{Schema, Canonical, Quat, Names, Views}, Items/, Persistence/{Types, Template, Migrations, Prepare, JsonSafe, Ids, Quantize} (S1); Minigames/{Minigames, Types, Rng, Params, Timeline, Checks, ...} (S3); src/shared/{World/Layout, ItemRender/{RenderPlan, ItemModelBuilder}, Showcase/*, Definitions/{World, Presentation}} and server World/{WorldBuilder, PlotWorld} (S7). Rojo sourcemap of the union tree: review/R5b/rojo/sm_test_all.json.

**Proposed fix.** S5 regenerates §1.3 from the owners' file lists and updates §1.5/§1.7 calls to the owners' APIs: Canonical.draft, Prepare.run, WorldBuilder.build, PlotWorld.claim/release, and ItemModelBuilder.build(RenderPlan.fromBlueprint(...)). The lead freezes the final tree in SPEC §1 as the single reference.


### R6-10 [minor/gap] The smithy HUD and settings outside the editor are unspecified, "My smithy" has no remote, and chat covers the editor

Sections: S6, S5, S7 | needsUserDecision: False | confidence: high

**Problem.** S6 names a BS_Hud layer and an "Items" button only. S7 expects a "My smithy" HUD button that calls World.TeleportHome, which is not one of S5's 17 actions. Reduced motion, UI size and invert orbit (plus R6-05's timing offset and R6-06's volume) are reachable only from the editor's ⚙, although they affect the forge and the world. Help (F1) exists only in the editor. The default TextChatService window sits top-left (ChatWindowConfiguration defaults Left/Top), over the editor's 280-px left column; S6 assumes chat overlaps only when the player opens it.

**Evidence.** S6 §12.8.2: "BS_Hud | … smithy HUD, toast stack". S6 §12.2.2: "HUD button 'Items'". S7 §13.3.2: "'My smithy' (HUD button, S6): Assumes (S5) remote World.TeleportHome". S5 actions: Profile.*, Blueprint.*, Craft.*, Showcase.* only. S6 §11.3: "it only overlaps the left column while the player opens it". Creator Docs ChatWindowConfiguration: HorizontalAlignment "Default value is Left", VerticalAlignment "Default value is Top".

**Proposed fix.** S6 adds a §12 subsection, Smithy HUD: top-left buttons Items, My smithy, Settings (UI size, reduced motion, timing offset, SFX volume, invert orbit) and Help (how to play plus the hotkey sheet), with R6-01's tracker below them. S5 adds World.TeleportHome {} (1 per 3 s), or S7 drops the button. While the editor is open S6 sets ChatWindowConfiguration.VerticalAlignment = Bottom and restores it on exit.


### R6-11 [minor/platform] Roblox's own accessibility preferences (Reduce Motion, Text Size, Background Transparency) are ignored

Sections: S6, S7, S8 | needsUserDecision: False | confidence: high

**Problem.** S6 defines its own ReducedMotion setting (default false) and a UI-size multiplier, but never reads GuiService.ReducedMotionEnabled, PreferredTextSize or PreferredTransparency. When a player raises Text Size the engine enlarges text, which will clip S6's fixed-size rows (52-px top bar, 64-px list rows, number fields) unless labels use AutomaticSize or TextWrapped. Minigame widgets also have no backdrop over the busy station scene (the trace band at α0.65 over grindstone sparks). During Trace the OS cursor stays visible next to the drawn reticle, so the player sees two cursors.

**Evidence.** S6 §11.10.1 EditorPrefsS6: "ReducedMotion: boolean". S6 §12.8.4 UI scale. S6 §12.6 element table (no canvas background; "Reticle | 26-px ring at the cursor"). Creator Docs accessibility guidelines: "Player preferences … your user interface should accommodate each". GuiService.ReducedMotionEnabled "maps to the Reduce Motion toggle".

**Proposed fix.** S6: effective reduced motion = GuiService.ReducedMotionEnabled OR the in-game override (Follow Roblox / On / Off), refreshed on its change signal; S7's tweens read the same value. S6's text components use AutomaticSize + TextWrapped, or measure with TextService:GetTextSize, which honours PreferredTextSize. Panel BackgroundTransparency is multiplied by PreferredTransparency. Each minigame widget sits on a surface.3 backdrop at α0.35, and UserInputService.MouseIconEnabled = false while the trace reticle is shown. S8 adds S-VIS-09: the editor and the results card at 1280×720 with Text Size = Largest show no clipped label.


### R6-12 [minor/bug] Held inputs can stick behind the Esc menu, and LMB on the trace canvas may be swallowed as gameProcessed

Sections: S3, S6, S8 | needsUserDecision: False | confidence: medium

**Problem.** S3 ignores inputs flagged gameProcessedEvent and records a release only on InputEnded or WindowFocusReleased. Esc opens the Roblox menu, which does not release window focus. A Space or LMB release made while the menu is open may never reach the game, or may arrive flagged gameProcessed. The bellows then stays on and pins the temperature (HoldZone score near 0), or grinding continues. Separately, S6's UI kit makes panel backgrounds Active. If the gauge, dial or canvas inherits that, clicks on it count as gameProcessed and S3 discards the press.

**Evidence.** S3 §6.6: "Ignored input | gameProcessedEvent == true (chat, other UI)"; "Focus loss | WindowFocusReleased records a release". S6 §12.3.2: "Esc opens the same confirm only if the engine delivers it". S6 §12.8.6: "(panel backgrounds are Active)". Creator Docs GuiService.MenuOpened: "Fires when the user opens the Roblox CoreGui escape menu".

**Proposed fix.** S3 input layer: never ignore an InputEnded for an input it recorded as down. On GuiService.MenuOpened, record releases as for focus loss, and S6 shows a "The forge doesn't pause" banner. Each frame, reconcile the held state with UserInputService:IsKeyDown(Space) and IsMouseButtonPressed(MouseButton1), recording a transition when they differ. S6: the gauge, dial and canvas and their parents have Active = false, with no GuiButton under the play area. S8 end-to-end tests: LMB on the canvas starts grinding, and Esc during HoldZone followed by a release records the release. (Engine delivery while the menu is open was not tested in play mode.)


### R6-13 [minor/ux] Forge screen transitions: Space carries over from play into result screens, and the editor-to-furnace camera swoops down from y = 1000

Sections: S6 | needsUserDecision: False | confidence: high

**Problem.** Space is both a HoldZone/TimingStrike input and the forge screens' primary key (Begin, Start, Next step, See the result). A player still striking with Space at the end of Hammering (400 ms tail) can skip StepResult(2) unread and press Start on the next Intro. Separately, "Forge ▸" leaves the editor stage at y = 1000 without restoring the world camera, so StationStage.enter(Furnace) tweens from the sky down to the furnace in 0.8–0.9 s.

**Evidence.** S6 §12.2 screens table: "Next step / See the result (Space)", "Start (Space)", "Begin forging (Space)". S6 §12.8.6: "Forge (Space/Enter = primary button)". S3 §6.9.6: tailMs 400. S6 §11.3: "'Forge ▸' (saves if needed, then hands over to the forge flow without restoring the world camera)". S7 §13.6.2: transitions tween from the current camera.

**Proposed fix.** S6: a primary key fires only on a fresh press that begins ≥ PRIMARY_KEY_GUARD_MS = 600 after the screen appears; held or auto-repeated keys are ignored. For "Forge ▸": fade the Fx layer (FADE_MS 250), cut the camera to the drafting-table framing, then call StationStage.enter(Furnace).


### R6-14 [minor/clarity] Player-facing text points at the wrong lever, shows development jargon and hides what a fail costs

Sections: S6, S4 | needsUserDecision: False | confidence: high

**Problem.** (a) The results lock says "Locked: pass a Hard step to unlock Epic", but the player never picks a tier; Hard comes from the design. (b) The "Hard (Expert in Phase 2)" chip shows development phases to players. (c) The "Draft" chip marks invalid blueprints, while every blueprint is a draft (Drafting table, "Draft" prompt). (d) S6's flow rules say a fail gives "half score", but S4's φ is 0.75. StepResult shows only "FAILED + quality reduced", not how close the player came or what the fail costs. (e) "TOO COLD ▼ / TOO HOT ▲" reads as the action to take but points the wrong way. (f) "Keep" on the results card implies an alternative that is not offered.

**Evidence.** S6 §12.2.1: "Locked: pass a Hard step to unlock Epic". S6 §11.19.2: "above 0.4 the chip reads 'Hard (Expert in Phase 2)'". S6 §11.20: "can be saved, chip Draft". S6 §12.1: "Fail continues (R5); half score, no cap lift" vs S4 §7.5 F1 "φ = 0.75". S6 §12.4: "IN ZONE ✓ / TOO COLD ▼ / TOO HOT ▲". S6 §12.2.1 actions [Place on display] [Keep] [Forge again] [Edit blueprint].

**Proposed fix.** S6 copy: (a) "Epic needs a Hard step — make the design bolder or use Steel" + [Edit blueprint]. (b) "Hard" with a tooltip "Very hard design — plays as Hard for now". (c) Chip "Needs fixes". (d) StepResult reads "47 % — needed 50 % · counts as 35 % · Epic not unlocked", using S4's effectiveScore and φ from Definitions; S6 §12.1 cites φ instead of "half". (e) "TOO COLD — heat ▲" / "TOO HOT — release ▼". (f) [Done] plus a secondary [Scrap] (Showcase.Scrap with confirm).


### R6-15 [minor/ux] Showing off ends at a static stand: no world payoff, no announcement, no personal-best cue

Sections: S6, S7, S1 | needsUserDecision: True | confidence: medium

**Problem.** Likes are Phase 3, so in the MVP showing off is entirely passive. After "Place on display" the player is still at the grindstone and gets only a toast. The in-world forge "reveal" is a non-goal. Nothing tells the server that someone forged a Rare or Epic, and the results card never uses S1's Counters.BestQuality.

**Evidence.** S6 §12.2.1: toast "Placed on Stand 2". S7 §15: "Display turntable, 8° lean, forge 'reveal' of the finished item above the anvil | Client-side polish" (not in the MVP). S7 §13.5.4: "No likes, categories or rewards in the MVP". S1 §9 Counters: "BestQuality".

**Proposed fix.** (1) After Place, a 1.5 s camera shot of the chosen stand (S7 adds Layout.standFraming; reduced motion = cut). (2) A "New best: Quality 94" ribbon on the results card when Q > Counters.BestQuality. (3) A server-wide system message for Rare and above ("Louis forged a Rare Steel Sword") through TextChatService on each client, using the filtered name, at most 1 per player per 60 s. (4) Optional: an owner toast when a visitor inspects their item, rate-limited.


### R6-16 [minor/ux] Each minigame is first played blind and scored for good; a free rehearsal would be cheap

Sections: S6, S3 | needsUserDecision: True | confidence: medium

**Problem.** The Intro gives two lines of text, and step scores are final. A player therefore learns HoldZone's overshoot or TimingStrike's windows on an item that keeps the result forever. The shared pure simulations make an unscored local rehearsal trivial (S6 says so), yet it is deferred to Phase 2.

**Evidence.** S6 §15: "Practice mode for minigames (unscored local play with a local seed) — trivial with the shared sims … Phase 2 decision". S3 §15: "Practice mode … (not in the MVP)". S4 §7.4 R4: "A scored step is final".

**Proposed fix.** S6 adds [Try it (unscored)] to each Intro: about 8 s of the same family with the step's resolved parameters and a client-side seed (HoldZone 8 s, TimingStrike 6 cycles, Trace a 0.8-u path). No server call and nothing recorded. The button is highlighted until UiFlags "Tried.<StepId>" is set. The 120-s Ready(i) idle timer keeps running; a ≤ 15 s rehearsal fits.


### R6-17 [minor/conflict] Mirror uses x = 0, but Asymmetry is measured about the grip-axis plane

Sections: S6, S2 | needsUserDecision: False | confidence: high

**Problem.** S2 measures asymmetry about the plane through the grip point along the grip axis, and recommends that the mirror tool use that plane so mirrored designs measure 0. S6 mirrors only across x = 0 and z = 0. When the grip is off-centre or tilted, a mirrored guard measures as asymmetric and raises Hammering and Sharpening D (weight 0.30). The player then asks, "I mirrored it, why is it Hard?"

**Evidence.** S2 §3.7: "Recommendation to S6: the tool's default plane is the sword's symmetry plane … a mirror-built design measures exactly 0 asymmetry". S6 §11.14: "Mirror across the sword's symmetry planes through the hitbox centreline: x = 0 … and z = 0".

**Proposed fix.** S6 mirrors across S2's symmetry plane: grip point g with normal N, or x = 0 before a grip exists. The plane is drawn while M is held. z = 0 mirroring stays. S2 exposes a cheap Geometry.symmetryPlane(parts) returning (g, N).


### R6-18 [minor/fidelity] Snapping defaults and feedback: a 15° rotation step is the first limit a new player hits

Sections: S6, S1 | needsUserDecision: True | confidence: medium

**Problem.** All three snaps default to on (0.05 / 15° / 0.05). The user said "don't limit players on stupid things like steps for rotation scaling and moving". Shift inverts snapping and the status bar says so, but a newcomer's first ring drag jumps in 15° steps. S toggles all snapping silently, and Roblox players' WASD habit (Studio's RMB+WASD fly camera) will flip it by accident. The Euler cache lasts only for the session, so a rotation typed as (170, 0, 0) shows as (10, 180, 180) after reopening.

**Evidence.** BRIEF §1 quote. S1 §9 Template: "Rotate = { On = true, Step = 15 }". S6 §11.10.1: "[Decision to confirm] snapping on by default". S6 §11.21: "S | toggle snapping (all channels)". S6 §11.11.3: "Each part keeps a session-only Euler cache"; typed (170,0,0) vs canonical (10,180,180).

**Proposed fix.** Default Rotate snap off; Move and Scale stay on at 0.05 for tidy joints; presets unchanged. Show a one-time hint per tool on the first drag: "Snap 0.05 — hold Shift for free, change it in the snap bar". Pressing S shows a toast ("Snapping off"), and letter hotkeys are suspended while RMB is held. With no cache, display the Euler solution with the smallest Σ|angle| (picks (170,0,0)); this is display only.


### R6-19 [minor/ux] The editor shows physics numbers but not what they do to stats

Sections: S6, S4 | needsUserDecision: False | confidence: medium

**Problem.** "Physics that matters" means mass, balance and edge length feed Damage, Sharpness and Balance. The preview lists only mass, balance, reach, difficulty, cap and ceiling, plus the Balance stat. Players cannot see that a heavier or longer-edged blade hits harder until after forging.

**Evidence.** S6 §11.19.2 panel content. S4 §8.2.2 formulas (F_mass from M/MassRef; F_edge with c = L_edge/EdgeRef). S6 §11.19.2: "Assumes (S4): Plan.build, Quality.ceiling, Rarity.planCap, Stats.breakdown are pure and client-safe".

**Proposed fix.** S6 adds a preview row "Potential: Damage 33–41 · Sharpness 21–70 · Durability 25–50", computed with S4's Stats.compute at all step scores 0.5 and at 1.0 (passed). Each commit shows green/red deltas, and the tooltip comes from Stats.breakdown.


### R7-20 [minor/conflict] Quantization points and rounding functions disagree

Sections: S1, S2, S3, S4 | needsUserDecision: False | confidence: high

**Problem.** S1 §9.5 requires D, Physics and Stats to be quantized to 1e-4, and Geometry to 1e-6, 'where they are produced', with Quantize.q = math.round(x·n)/n. S2 says nothing is quantized. S4 stores D at 1e-3 (DifficultyGrid = 1000) and quantizes stats on its own per-stat grids with floor(x·n + 0.5)/n. S3 rounds scores with floor(x·10000 + 0.5)/10000. The two rounding functions differ on signed values (balance offsets can be negative). A D stored at 1e-3 can contradict the tier computed from the finer D: 0.19996 plays Normal but is stored as 0.200. Quantize also lives in Persistence/ although Physics, Minigames and Crafting call it.

**Evidence.** S1 §9.5 table and §3.4 ('round is Luau math.round (half away from zero)'). S2 §3.4. S4 §8.6.3 Balance.Quality DifficultyGrid and Balance.Stats Grid. S3 §6.4.2 rule 8. S1 §3.8: 'src/shared/Persistence/Quantize.luau (used by S2/S3/S4 ...)'. Probe review/R7/roundprobe.luau: 0 mismatches on 10⁶ random x in [0,1), but 8,855 of 10,000 negative half-points −(k+0.5)/10⁴ round differently (for example −0.00005 → −0.0001 against 0).

**Proposed fix.** Use one function, Util/Quantize.q(x, n) = math.round(x * n) / n (error on non-finite input), and have S3's round4, S4's quant and S2 call it. S1's §9.5 holds one table of quantization points, all inside the shared pipeline: D_s at 1e-4 before tierFor, and stored at that value (S2; S4's DifficultyGrid removed); scores at 1e-4 (S3); T and Q at 1e-4 (S4); stats on S4's grids (replacing S1's 'Stats 1e-4' row). Physics outputs are not quantized if R7-18 is accepted, otherwise at 1e-4. Persistence and server-only code never quantize.


### R7-21 [minor/testing] The purity and determinism lint rules do not match the module map

Sections: S8, S5, S6, S7, S2 | needsUserDecision: False | confidence: high

**Problem.** T-META-02 exempts all of Net/, so the pure Guard, RateLimit and Protocol modules are never scanned. It also fails on S5's Util/Signal (task.) and S7's ItemRender/ItemModelBuilder (Instance.new), which are Roblox-bound by design. T-META-03's list of authoritative folders (Physics, Minigames, Crafting) omits Blueprint/, even though Canonical/Quat/Mirror feed validation and S2 applies its determinism rules to Blueprint/. It also omits Pipeline, Items and Session. Signal is defined twice (S5's Util/Signal, S6's UI/Signal); the Combat System has a single shared Signal.

**Evidence.** proto/S8/repo/tests/Meta/Purity.spec.luau: 'src/shared (except Net/)', AUTHORITATIVE = Physics, Minigames, Crafting. Run on a copy with the two S5/S7 files added (review/R7/s8repo): 'FAIL Meta/Purity › src/shared is pure Luau (Net/ excepted) ... src/shared/ItemRender/ItemModelBuilder.luau:4 uses Instance.new', then 'src/shared/Util/Signal.luau:4 uses task.'. S2 §4.1: 'Determinism rules for Blueprint/ and Physics/'. S6 §11.2 UI/Signal; S5 §1.3 Util/Signal.

**Proposed fix.** Every Roblox-bound file in src/shared starts with --!strict followed by '-- @roblox-bound' (Net/Remotes, Net/Client, Util/Signal, ItemRender/ItemModelBuilder). T-META-02 scans every other src/shared file, including the pure Net modules. T-META-03 covers Blueprint/, Physics/, Minigames/, Crafting/, Pipeline, Items/ and Session/; EditorCore/Rotation is display-only and carries the allow pragma. S6 uses Util/Signal, dropping UI/Signal and keeping Value.


### R7-22 [minor/testing] S-PAR-02 compares Lune with Studio on one PC, so drift between a live server and a client is never measured

Sections: S8 | needsUserDecision: False | confidence: medium

**Problem.** The determinism rules exist because a live Roblox server and a player's client are different binaries on different machines. S-PAR-02 runs the Server and Client datamodels inside one Studio process on the developer's PC, so it can only catch drift between Lune and Studio.

**Evidence.** S8 §14.10.5 S-PAR-02: 'recomputes it in the Server and Client datamodels'. BRIEF §4.1: 'platform libm differences could flip a threshold'.

**Proposed fix.** Add S-PAR-04 to the published test place session M-06. Save F1–F4 and require the server's Blueprint.Save summary to equal the client preview exactly. Craft one item and require clientScore == the server's rawScore for each family (ScoreMismatch = 0). Keep the live ScoreMismatch target of 0 as the production monitor.


### R7-23 [minor/conflict] Two BALANCE_VERSION guards with different scopes and files

Sections: S1, S8 | needsUserDecision: False | confidence: high

**Problem.** S1 hashes an explicit list of outcome-affecting fields (display fields excluded) into tests/fixtures/balance_hash.luau. S8 hashes 'every tunable' into tests/golden/balance_fingerprint.golden.txt, and its prototype hashes only Definitions/Balance. Hashing all of Definitions forces a version bump (and item recomputes) on a colour edit. Hashing only Balance misses Materials.Density, Tiers, Rarities, MinigameFamilies and CraftPlans.

**Evidence.** S1 §2.12 hashed-fields table. S8 §14.9 first bullet. proto/S8/repo/tests/Definitions/Fingerprint.spec.luau requires only '../../src/shared/Definitions/Balance'.

**Proposed fix.** Keep one guard: S8's mechanism (golden file, --bless rules, strictly increasing version) applied to S1's field list, extended with the new outcome-affecting data (MinigameFamilies, CraftPlans, EquipmentTypes.geometry, Steps weights). Network, World, Presentation and display fields stay excluded. Drop tests/fixtures/balance_hash.luau.


### R7-24 [minor/architecture] Constants and throttling helpers are defined in more than one module

Sections: S1, S2, S3, S5, S7 | needsUserDecision: False | confidence: high

**Problem.** Several constants live in two or three Definitions modules: PLOT_COUNT (S5 Network, S7 World); COUNTDOWN_MS (S3 §16, S5 Network); the part cap (S1 Limits 48, S2 Balance 24, S7 Presentation 64); the store name (S1 Limits PROFILE_STORE_NAME, S5 Network STORE_NAME); the name length (S1 NAME_MAX_CP 32, S5 MAX_NAME_CHARS); display slots (S5 MAX_DISPLAY_SLOTS 16 in the Guard, S7 6 stands). Throttles are also implemented separately: S5's Net/RateLimit (Router, client self-throttle, telemetry bucket), S5's Log counter of 20 lines per 10 s, and S7's HOME_TELEPORT_COOLDOWN of 3 s.

**Evidence.** S5 §16 block. S7 Definitions/World PLOT_COUNT = 8 and Presentation MAX_RENDER_PARTS_HARD = 64. S3 §16 COUNTDOWN_MS 3000. S1 Limits list (summary interfaces item 5). S5 §1.9 log limit. S7 §13.3.2 cooldown.

**Proposed fix.** Each constant gets one home, the owner's module, and every other module imports it: PLOT_COUNT → Definitions/World (S5's boot check reads it); COUNTDOWN_MS → Definitions/Network, copied into S3's StepSpec; MAX_PARTS = 24, the store name/key and the name limits → Definitions/Limits; the Guard's display-slot bound = World's stand count. New check T-DEF-11: no constant name is defined in two Definitions modules. All throttles use Net/RateLimit buckets: Log {20, 2/s} per tag and event, TeleportHome {1, 1/3}.


### R7-25 [minor/platform] Place settings that Rojo can carry are left as manual README steps

Sections: S5, S6, S7 | needsUserDecision: False | confidence: medium

**Problem.** S5 lists Workspace.StreamingEnabled as 'not representable in the project file', a one-time Studio setting, and S6 needs StarterPlayer.EnableMouseLockOption = false for the place. Both can be set under $properties in default.project.json, so they stay in git and apply to every build. S5 (false) and S7 (enabled) also disagree on StreamingEnabled.

**Evidence.** S5 §1.8: 'One-time place settings (not representable in the project file; README checklist)'. S6 §11.3: 'Assumes (S5/S7): StarterPlayer.EnableMouseLockOption = false'. S7 §13.7.4: 'Streaming stays enabled (default; it cannot be set from scripts)'. review/R7/tree/props.project.json (S5's tree plus Workspace $properties StreamingEnabled false and StarterPlayer $properties EnableMouseLockOption false), built with Rojo 7.7.0-rc.1, writes '<bool name=StreamingEnabled>false</bool>' and '<bool name=EnableMouseLockOption>false</bool>' into the place. I tested rojo build, not live rojo serve.

**Proposed fix.** S5 §1.8 puts both properties under $properties in default.project.json, along with any other place property the drafts depend on. The README checklist keeps only the dashboard settings (Max/Preferred Players, API access). The lead rules once on StreamingEnabled (S5 false against S7 true). S8's S-E2E-01 asserts the value at boot. One build-phase item: confirm that rojo serve applies service $properties.

