# M1 build notes

Open items and deviations reported while building M1 (data contracts), verbatim from the builders, fixer and
verifiers. Read the part for your milestone before building it. The items are point-in-time, so check them against
the code and SPEC.md; strike what is done.

## B1 Definitions core

**Open issues**

- scripts/verify exits 3 only because of the 4 luau-lsp pass B errors in the fixtures/Gen builder's files (see crossRequests). Once they are fixed, verify should go green: T-META-07 passes, pass A has 0 errors, and lune run tests/run passes 238/238.
- BALANCE fingerprint timing: the golden captures B2's MinigameFamilies as of 23:20, and it still matched after B2's later term() refactor. Any later value change needs the pre-release re-bless described in crossRequests.
- T-DEF-06 'fixtures inside' is left to the fixtures owner's suite (tests/fixtures/Blueprints.luau says its FixtureSet spec checks that every part sits ≥ 0.02 inside the hitbox). T-DEF-07 (MAX_TIMELINE_BYTES, Audio cues) belongs to B2's modules and specs.
- Plan.validateDefs does not exist until M5; until then validateAll() runs only the base checks D1-D7.

**Deviations from the SPEC**

- API additions beyond SPEC signatures, none conflicting: Tiers.tierFor(d) and Tiers.tierRawFor(d) implement §2.7's mapping and return a TierId; they error on NaN, non-numbers and D outside [0,1]. Stats.qualityPoints(q) = floor(Q·100 + 0.5) (§16.9 'Quality display (rule)'). Validate adds check(bundle), current(), KNOWN_PART_MATERIALS (§16.3), FACTOR_ORDER and MODULES (the §1.2 module list D7 checks against). Manifest adds displayFields, collect(values?) and entryOf. CraftPlans exposes {Sword, ordered, get} (§2.1 CraftPlans[type], §16.11 CraftPlans.Sword).
- Validate's checks go beyond the literal D1-D7 text, as owners' columns (§2.3 'owners append theirs'): D1 also requires ascending order and boolean enabled. D4 also checks the class and every tier and rarity colour. D5 also checks min/max per slot, required ⇔ min ≥ 1, unique ranks, strikingSlot/gripSlot/guardSlot in the type and a unit thicknessAxis. D6 also requires qualityMultiplier increasing, rarityCap non-decreasing, minQuality increasing from Common 0, stat unit/decimals, and geometry.refs = the 8 factors in FactorId order. validateAll wraps each extra check in pcall and reports a raise as a problem. check() is total on garbage bundles.
- Manifest shape: hashed entries are structured {module, select = rows|keys|data, fields, ignore, exclude}. Steps.order and Stats.order are listed as `ignore` (§2.8's field lists omit them). The other Limits keys are listed by name in excluded, so T-BAL-02 can prove full coverage. CraftPlans is hashed via its `ordered` key, with the `Sword` alias ignored. T-BAL-01 hashes Dump.canonical(Manifest.collect()).
- Values the SPEC leaves open: the Phase 2 materials' difficultyTerm is 0 (placeholder; S2 fills it when enabling). allowedSlots is nil (any slot) on every row, since the SPEC gives none. The reserved stats SwingSpeed/Defense/Mobility have unit "" and decimals 0, and SwingSpeed's display name is 'Swing speed'. Sharpening's factorWeights are stored in FactorId order (Asymmetry 0.30, SurfaceComplexity 0.20, EdgeLength 0.50), as §5.1 requires arrays in FactorId order, although the §5.3 table lists EdgeLength first.
- Catalog.build also errors on malformed rows (missing or empty string id, non-finite order, non-boolean enabled, non-array or holed input), not only on duplicate id or order. It deep-freezes the rows it is given and returns a frozen catalog. get() returns nil for non-strings.

## B2 Definitions feature data

**Open issues**

- §10.4 says the client self-throttles at capacity − 1. RATE.ShowcaseTeleportHome has capacity 1, so the client bucket would be 0 and the 'My smithy' button could never send. S5 (M7) should use max(1, capacity − 1), or the SPEC should say how capacity-1 buckets throttle.
- Some §10 values have no §16.13 name and are not in Network: the action string limit (≤ 32 B), the rid range 1..2^31−1, the 60 s flood window, RateLimited telemetry once per (player, action) per minute, the client throttle factors (capacity − 1, refill × 0.9), and the two §10.4 kick texts ('Disconnected: too many requests.', 'Disconnected: unexpected client behaviour.'). S5 should decide where they live; KICK could take the two texts.
- E-S7.1 leaves plaza gaps: no lamp or tree angles (trees must sit in the 22.5° gaps between plots), no offsets for the lamp arm, lantern and flame, no material or colour for lamp parts and trunks, and no collide flag for the lamp post. These fields are nil; S7 settles them in M6 (S-VIS-01).
- 'A black UIStroke at 0.5' (E-S7.1 sign) is ambiguous. I stored it as strokeTransparency 0.5; it could mean Thickness.
- Values the SPEC does not give: the Highlight FillTransparency for Legendary and Mythic (left nil; those rarities are data only in the MVP) and the colour of the 'grey' PLACEHOLDER_SIZE block.
- World holds no tags (BS_Plot, BS_Stand, BS_Prompt, BS_Flicker, BS_RarityFx), attribute names, the BS_Characters collision group or the instance-tree names (§13.4, E-S7.1). These are names, not values. S7 may add them to World in M6 as shared server/client constants.
- PtTooSmooth's 'both dt 10–40 ms' bounds (§10.6) have no §16 constant, so they are not in the PrecisionTrace checks. S3 should decide in M4.
- Audio rows are {hook, id, volume, pitchRange} with no loop or 3D flag. UI/Sfx and StationFx have to treat FurnaceLoop and GrindLoop (3D on the active station) specially by hook name.
- scripts/verify is not green yet: luau-lsp pass B fails on 8 type errors in other builders' files (see crossRequests). My files are clean, and the full test suite passes 266/266.

**Deviations from the SPEC**

- E-S7.1, E-S7.6 and §13.7 describe data without constant names, so I named it myself: World.STATIONS, STAND_YAW, STAND_PROMPT_POS, PROMPT_SETTINGS, PROMPTS, BUILD_LIST, PART_DEFAULTS, PART_FLAGS, HOME_SPAWN, PLAZA, RESERVED_FLOOR, SIGN, LIGHTING, FORGE_GLOW, LIGHTS, SPARKS, VACANT_PLOT; Presentation.ORIENTATIONS, STAND_PRESET, VIEWPORT_PRESET, VIEWPORT_LIGHTING, WORKPIECES, RARITY_LIGHT, RARITY_SPARKLES, RARITY_HIGHLIGHT, CAM_EASING, CAM_EXIT_OFFSET, CAM_EXIT_LOOK_OFFSET, STATION_ACTIVITY; Audio.CUES. Fields are camelCase and every §16 name and value is used exactly as written.
- World.BUILD_LIST is one flat array of all 82 E-S7.1 rows in the table's order; each row's `component` decides its frame (shell components, a StationId, or Stand). Colours are PALETTE tokens plus 'PlotAccent' and 'Rarity'. The rotations rotX/Y/Z(d) are stored as Euler degrees {x, y, z}. Rows stay one per line (over 120 columns) so they can be diffed against the table; a script check found 0 mismatches over 82 rows.
- World.PALETTE is an ordered array of {token, color, materials} rows, not a token→RGB map, following the 'ordered arrays of camelCase rows' rule. Constants that other entries reuse (PLAZA_RADIUS, WORLD_WALL_RADIUS, GROUND_DISC_DIAMETER, STATION_PROMPT_DISTANCE, DISPLAY_PROMPT_DISTANCE, CLOCK_TIME) are locals referenced from those entries, so the plaza disc sizes, boundary radius, prompt distances and LIGHTING.clockTime each have one literal.
- Some plaza positions are derived from E-S7.1's prose rather than given as numbers: an 'upright' post or trunk stands on the ground, crowns sit 'at +8 / +10.5', the barrier sits 'above' the wall. The discs are marked colliding (walkable ground). Anything E-S7.1 does not give is nil.
- Audio volume and pitchRange have no value in the SPEC. They are neutral placeholders: volume 0.5 (Roblox's default) and pitchRange {1, 1}. All ids are '' as instructed.
- MinigameFamilies: the display names 'Hold Zone', 'Timing Strike' and so on are my choice. The three Phase 2 families have empty params, checks and flagLevels. Check rows use §16.12's UPPER_SNAKE constant names. The module returns the Catalog views at top level plus the wire constants, which is the shape B1's Manifest (select 'data') and Validate expect. Design terms go through a typed term() constructor, because luau-lsp widens string literals inside the optional `design` column and rejects them as FactorId.
- Presentation exports the unions Orientation ('STAND'|'FLAT'|'VIEW_H'|'VIEW_V') and Anchor ('BaseCenter'|'Center'|'Origin'). These are render presets that are never stored, not ids. M6's ItemModelBuilder and RenderPlan can alias them.
- World.RESERVED_FLOOR adds E-S7.1's Phase 2 reserved spots (QuenchTrough, AssemblyBench; both names are mine). The finishing grindstone has no position, so it appears only in a comment.
- The tests hard-code two Minigames constants that do not exist yet: PT_TRAVEL_MAX_MS 30000 (§16.22) and TS_PERFECT_CORE_MIN_MS 10 (§16.21). They can read them from Minigames/* once M4 lands.

## B3 Util and Blueprint

**Open issues**

- E-S8.4 (docs/spec/SPEC-evidence.md, which I may not edit) disagrees with the normative SPEC in three places; the code follows the SPEC. (1) A10, NaN or ±inf in a component, gives NonFinite per §3.5 C1, not 'Malformed'. (2) A19 'unknown fields → Malformed': §3.6 rebuilds the draft from known fields and never iterates a client table, so unknown fields are dropped and the draft is accepted. (3) A19 'draft as array' gives UnsupportedSchema (no schema field). The fixtures builder's tests/fixtures/Adversarial.luau already records the same readings. All 148 of its canon expectations (F1–F5 and every A-variant) match this Canonical, and tests/FixtureSet passes.
- DisabledId on `type` and MaterialNotAllowed cannot be reached with the MVP Definitions: Sword is the only type and is enabled, and Iron and Steel have allowedSlots = nil. They are covered on planted Definitions, loading Canonical's source through @lune/luau with an injected require map.
- Luau checker behaviour (luau-lsp 1.70.1) that consumers will hit. An unannotated local holding a function's singleton-union result (e.g. DT.SlotId?) is widened to string, so annotate such locals. A string literal inside a table checked against an intersection type (BlueprintRecord, BlueprintSnapshot) is widened to string, so pass ids through typed locals or casts.
- The slow T-BP-02 case (10^5 drafts, I11) takes about 17 s of the L3 budget.

**Deviations from the SPEC**

- Util/Quantize.q also errors when |x·scale| ≥ 2^51, where idempotency fails; this also catches an overflowing product. It also validates scale (a positive finite number). The spec listed only non-finite input; SPEC §9.5 is edited to match.
- Canonical check 5 ('parts an array') uses one next() call: a parts table with #parts == 0 but some key (a map or a holey list) is Malformed. This is not an iteration, and its outcome does not depend on key order. Keys beyond #parts, and unknown fields anywhere, are dropped, never read.
- The §3.6 check order is applied per check across all parts: every part passes check 6, then check 7, then C1, then C2, then C3–C6, then C7. Within a part the fields go pos, size, rot, the spec's listing order. DuplicatePartId names the later copy's client index ('parts[i].id'). Paths stop at the field ('parts[7].rot'), with no component index. Root failures have path ''.
- A non-string type, slot, shape or material gets its check's id code (UnknownId 'type', SlotNotInType, UnknownId), not Malformed, following the §3.6 table. Malformed covers the structural fields only (draft, parts, part, id, pos/size/rot tuples).
- isCanonical(core, {bounds = false}) skips only the POS_ABS_MAX, MIN_DIM and MAX_DIM tests. The QUAT_INPUT_TOL rotation check always runs. isCanonical never throws, even on garbage core or opts; unknown part fields are ignored like top-level extra keys.
- Canonical.quat errors (as a caller bug) on a quaternion outside C1–C2. Quat.normalize errors on a zero or non-finite norm.
- Quat.fromMatrix uses Shepperd's largest-of-four selection (4qw², 4qx², 4qy², 4qz²), where S2's prototype tested tr > 0 first. It always normalizes, then applies the hemisphere rule.
- Blueprint/Schema returns table.freeze({}) where §3.3 shows return {}, matching Definitions/Types' house style. The modules Quat, Names, Views, Canonical and Quantize return frozen tables too.

## B4 Fixtures, Gen, M0 carry-overs

**Open issues**

- A10 over the wire (M7): §10.3's Guard.plain accepts finite numbers only, so a Blueprint.Save of A10 gets E_BAD_REQUEST with a Hard strike, while E-S8.6's S-E2E-04 lists A10 under E_INVALID_BLUEPRINT. The fixture data says E_BAD_REQUEST with a note; M7 must settle which text changes (docs/ is not editable here). Likewise A15 (2,005 parts) is over MAX_PAYLOAD_NODES, so the wire answers E_BAD_REQUEST; A15b (25 parts) is the wire's TooManyParts case.
- MaterialNotAllowed is unreachable with MVP data: no enabled material has allowedSlots, and a disabled one hits DisabledId first. No fixture can plant it; Canonical's own tests would need injected definitions. FixtureSet/Adversarial fails as soon as an enabled material gains allowedSlots, prompting a new draft.
- For M3 (S2 owner), found by running S2's reference prototype on Gen output (scratch run, 300 validSword designs, all valid, none cleaned). (a) withFiller 'Duplicate': 34 of 300 designs change d or g (max |ΔG| 0.051; one Thinness 0.21 → 0.06), because exact copies of Cylinders, Balls, Wedges and CornerWedges are not always cleaned as Enclosed. A17's Block copies are the only measured case, so T-DIF-04's 'duplicates leave D bit-identical' will fail on general designs. (b) segmented: |ΔG| up to 0.0044 on straight blades and 0.038 (MVP |Δx| up to 0.126) on blades turned about Y or on Z45 tips, above T-DIF-07's TOL_G_INVARIANT 0.002 and TOL_FACTOR_ABS 0.02. E-S2.10 measured only F5's straight blade. translated (|ΔG| ≤ 0.0002) and Dust or Enclosed filler (|ΔG| 0) stay within bounds. The same prototype run confirmed every M2/M3 expectation in the fixture data: F1–F5 tiers including tierRaw and the F5 starter margin, every A verdict and cleaned list, A24's Hammering 0.40 and Thinness 1, and the A14/A16/A17 relations.
- §9.3 makes Persistence/Template.STARTER the one copy of F5 that tests import. Persistence is M7 and tests/fixtures cannot require src/, so F5 lives in tests/fixtures/Blueprints.luau for now. M7 should assert that Template.STARTER's parts equal Blueprints.get('F5').core.parts, or derive one from the other.
- GlobalTypes.check is structural and does not type the declarations. A file cut exactly after a complete declaration near its end, with every required global present, still passes, and luau-lsp would load it too. A SHA-256 pin (tools/README.md records the hash) would be stricter but brittle across pins.
- Gate timing: the full verify takes 27.8 s, 22.6 s of it in tests (mostly other builders' cases); --quick takes 11.9 s. My heaviest cases: the --bless child-runner proof 0.66 s, the luau-lsp facts 0.30 s, the garbage fuzz 0.15 s.

**Deviations from the SPEC**

- Spec folder tests/FixtureSet/ instead of tests/Fixtures/. On this machine NTFS is case-insensitive and git core.ignorecase=true, so tests/Fixtures is the same directory as tests/fixtures, a Rojo root. Specs placed there would sync into Studio and fail T-META-07 (tests/fixtures → tests/lib crosses a root).
- A02 built differently. E-S8.4's 'F2 guard turned 30° about Z, a corner out' cannot leave the 1.6-stud-wide hitbox: the turned 0.8 × 0.2 guard reaches only |x| = 0.396. A02 turns F2's guard 45° about Y instead, so its corners reach |z| = 0.354 > 0.30, giving OutOfHitbox#3. S2's prototype confirms it, and the variant's note records the change.
- Where E-S8.4's summary disagrees with SPEC §3.5, §3.6 or §4.2, the codes follow the SPEC: A10 → NonFinite (E-S8.4 says Malformed); A12 {0,0,0,2} → BadRotation (E-S8.4 groups it with 'renormalized'); A19 unknown fields are dropped (ok, equals F2) and an array draft → UnsupportedSchema (E-S8.4 says Malformed); A08's 'S2's full list' is the quick stage's single SlotMissing{Grip}. Each variant's note records this, and B2's Canonical agrees on every one.
- Variants added so the set holds one draft per CanonError, ValidationCode and wire code (§14.7): A08b upside-down F2 (BladeNotAboveGrip); A11 inclusive limits; A12 boundaries at QUAT_INPUT_TOL and QUAT_NORM_TOL; A13b/A13c reverse order and −0; A15b MAX_PARTS + 1 (wire TooManyParts); A18d a deep unknown field; A19 per-field type faults, DuplicatePartId, schema variants, id at MAX_PART_ID; A20 shape case, a foreign slot, an unknown material, a reserved type.
- T-META-02 bans SPEC §14.4's literal tokens tick(, wait( and task. whatever locals are in scope. It also keeps M0's stricter ban on the bare globals tick, wait and task used as values (local w = wait, pcall(wait), typeof(task)) when no local of that name is in scope. A call with a table or string argument counts as tick( or wait(. Fields, methods and table keys stay exempt for every token, as in M0.
- verify exits 4 (MISSING TOOL … is unusable) for an unusable definitions file and when luau-lsp itself refuses to read it. Before, a broken file surfaced only as exit-3 noise, and an empty one could pass.
- F1–F5's expect holds the §5.5 tiers and tierRaw (for T-DIF-11) and E-S8.3's oracle, but not §5.5's d values or E-S2.9's physics and factor tables. §14.7 has those blessed into goldens from Analyze.run in M3, with no copy kept by S8.
- Adversarial draft names are their variant keys (e.g. 'A05b'). Drafts whose canonical value must equal a fixture (A13, A13b, A13c, A18d, A19-UnknownFields) keep the base fixture's name.

## Fix round 1

- Nothing is committed (per instructions). The re-blessed tests/golden/balance_fingerprint.golden.txt must go into the M1 commit together with the MinigameFamilies change.
- README Status now says M1 is built and verify is green, as the issue asked. The independent M1 verifier has not signed off yet.
- Both Rojo projects still build (checked: rojo build of default.project.json and test.project.json into the scratchpad).

## Verifier notes with no M1 action

- A SPEC evidence mismatch for M7: E-S8.4 and E-S8.6 summarize A10–A12 and A19 as E_INVALID_BLUEPRINT, but the fixtures follow the normative §3.5, §3.6 and §10.3 (A10 and A19-IdNaN answer E_BAD_REQUEST with a Hard strike, as does A19-Array at depth 5; A12's sloppy variants are renormalized and stored). S-E2E-04 must assert each variant's `save` field, not the evidence summary.
- `Canonical.draft` throws on a table whose metatable traps `__index` or `__len`. Remotes should strip metatables (from knowledge of Roblox, not tested): confirm in M7.
- `Canonical.draft` silently drops keys past the array part of `parts` and extra tuple keys; the output is still a clean rebuilt draft.
- §3.10's "+54 B" Save envelope is S1's size of `{blueprintId}`; the exact JSON overhead is 63 B (T-BP-05 asserts it). No budget is affected.
