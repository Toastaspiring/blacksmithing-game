# Blacksmithing Game

Roblox game: players design swords from primitive parts in a free-transform blueprint editor, forge them through
three seeded skill minigames (smelting, hammering, sharpening), and show the results in their smithy.
Everything that decides an outcome is pure Luau shared by client and server and replayed on the server.

See [`SPEC.md`](./SPEC.md) for the Phase 1 (MVP) technical specification, which implements Louis Marec's design
draft. The designer approved v1.0 and all 22 decisions of §0.4 on 2026-10-31; the build follows SPEC §18
(milestones M0–M9).

## Layout

```
SPEC.md                    technical spec, Phase 1 MVP (v1.0, approved)
aftman.toml                tool pins: rojo, lune, luau-lsp
default.project.json       the place (SPEC §1.4); Workspace.StreamingEnabled and StarterPlayer.EnableMouseLockOption off
test.project.json          default.project.json + the three test nodes, hand-written (T-META-08 checks it)
.luaurc                    strict mode; tests/.luaurc adds the `lune` alias for Lune's typedefs
src/
├── shared/   → ReplicatedStorage.Blacksmith.*          pure, Lune-tested; Roblox-bound only Net/Remotes, Net/Client,
│   │                                                    Util/Signal, ItemRender/ItemModelBuilder (line 2 `-- @roblox-bound`)
│   └── Remotes.model.json                               Folder "Remotes": RemoteEvents Profile, Blueprint, Craft, Showcase
├── client/   → StarterPlayer.StarterPlayerScripts.BlacksmithClient.*
└── server/   → ServerScriptService.BlacksmithServer.*
    └── Vendor/ProfileStore.project.json                 nested project → vendor/ProfileStore/ProfileStore.luau
tests/
├── run.luau               Lune test runner
├── lib/                   Test, Assert, Prop, TestRng, Dump, Golden, Tol, Gen (requires nothing in src/: specs
│                          pass Definitions in); Cheats arrives with M4 (SPEC §14.2)
├── Meta/                  T-META-01…08: source rules, require resolver (§1.3 L2 layer order included), runner
│                          self-test, project check; GlobalTypes and Tools.spec check the luau-lsp definitions file
├── Definitions/           T-DEF-00…07 (all 19 modules), T-BAL-01/02 (BalanceGuard)
├── Util/, Blueprint/      T-UTIL-01; T-BP-01…05, 12, 13 and T-UD-01 (SaveLoad)
├── fixtures/              Build (shared record helpers), Blueprints (F1–F5), Adversarial (A01–A24): a Rojo root,
│                          so Studio tests load them too
├── FixtureSet/            the fixture and Gen specs (not tests/Fixtures, which is tests/fixtures on a
│                          case-insensitive file system)
├── golden/                balance_fingerprint, definition_ids (`--bless` rewrites them: review the diff)
└── studio/                Studio bridge (test place only), e2e snippets, reference
scripts/verify.luau        the local gate: sourcemaps → T-META-07 → luau-lsp → tests
tools/                     Roblox definitions for luau-lsp, runner self-test roots (tools/README.md)
docs/spec/
├── SPEC-evidence.md       evidence appendix (E-Sx.y): calibration tables, simulations, proofs
├── prototypes/S1…S8/      throwaway Lune prototypes behind the spec's numbers (not game code)
└── review/                review findings, the lead's verdicts and rulings (RULINGS.md)
vendor/ProfileStore/       vendored ProfileStore (MadStudioRoblox, commit 45c9847, Apache-2.0, never edited)
```

The `src/` folders follow SPEC §1.2's module map. M1 filled `src/shared/Definitions/` (all 19 modules, `Manifest`
and `Validate` included), `Util/Quantize` and `Blueprint/{Schema, Canonical, Quat, Names, Views}`. `Main.server`,
`Main.client` and `Net/Remotes` are still the M0 stubs, the other folders hold `.gitkeep` files, and
`tests/studio/bridge/` holds the two bridge stubs. Later milestones fill them.

## Toolchain

Pinned in `aftman.toml` (SPEC §1.4): Rojo 7.7.1, which must match the Studio plugin (`rojo plugin install` installs it; a 7.7.0-rc.1 server
answers in JSON while the 7.7.x plugin expects MessagePack, and the plugin fails with "attempt to index number with
'protocolVersion'"), Lune 0.8.9, luau-lsp 1.70.1 (SPEC §14.4 asks for ≥ 1.67.0; 1.67.0 itself cannot run on this machine because Windows
Security removes its binary, see [`tools/README.md`](./tools/README.md)). Once per machine, from the repo root:

```bash
aftman install          # the shims read the nearest aftman.toml, so run every tool from the repo root
lune setup              # Lune typedefs in ~/.lune/.typedefs/0.8.9/ (used by luau-lsp through tests/.luaurc);
                        # also writes .vscode/settings.json here
```

```bash
rojo serve                                                         # live-sync into Studio (Rojo plugin → Connect)
rojo build default.project.json -o Blacksmith.rbxlx
rojo sourcemap default.project.json --include-non-scripts -o sourcemap.json
rojo sourcemap test.project.json --include-non-scripts -o test.sourcemap.json
# luau-lsp passes A and B as verify runs them (SPEC §14.4); --formatter=plain always exits 0, so read its output
luau-lsp analyze --platform=roblox --sourcemap=test.sourcemap.json --definitions:@roblox=tools/luau-lsp/globalTypes.None.d.luau --ignore="vendor/**" --formatter=plain src tests/studio
luau-lsp analyze --platform=standard --ignore="tests/studio/**" --formatter=plain tests
lune run tests/run -- --quick                                      # pure-module tests without t.slow (L1)
lune run tests/run                                                 # all tests, statistical ones included (L3)
lune run scripts/verify                                            # the gate: sourcemaps → T-META-07 → luau-lsp → tests
```

Lune 0.8.9 passes script arguments only after `--`. Runner flags: `--quick`, `--filter <text>`, `--seed <n>`
(replays one property case), `--bless` (rewrites goldens: review the diff), `--list`, `--root <dir>`. The runner
exits 0, 1 (a FAIL or an ERROR) or 2 (harness, including a `--filter` that matches no case and a `--seed` that
replays none); `scripts/verify [-- --quick]` exits 0 green, 1 tests, 2 harness (a crash of verify itself included),
sourcemap or T-META-07, 3 luau-lsp, 4 missing tool, including a `tools/luau-lsp/globalTypes.None.d.luau` that is
empty, cut or foreign, or that luau-lsp cannot read (checks in [`tools/README.md`](./tools/README.md)). luau-lsp's
`--formatter=plain` always exits 0, so verify reads its diagnostics: type and syntax errors and the lints
UnknownGlobal, DeprecatedApi and ImplicitReturn fail; other lints are listed. Build outputs and the sourcemaps
verify rewrites are git-ignored.

Build checklist (SPEC §1.4):
1. Creator Dashboard: Max Players = 8 (one smithy plot each).
2. Data stores: add the right-to-be-forgotten deletion template for store `PlayerData`, key pattern `User_{UserId}`,
   scope `global`, and test it with a dummy account.
3. Studio API access only on the separate test experience (SPEC §14).
4. After the first `rojo serve`, check that Workspace.StreamingEnabled and StarterPlayer.EnableMouseLockOption are false.

## Status

**Build phase.** M0 (toolchain, project files, runner, test library, verify, T-META-01…08 on stubs) is built. M1,
the data contracts (SPEC §18), is built: `Definitions/*` with `Manifest` and `Validate`, `Util/Quantize`,
`Blueprint/{Schema, Canonical, Quat, Names, Views}`, and the fixtures F1–F5 and A01–A24. T-DEF, T-UTIL,
T-BP-01…05/12/13, T-UD-01 and T-BAL-01/02 pass, and `lune run scripts/verify` is green. Next: M2, the geometry
core and engine parity.
