# Blacksmithing Game

Roblox game: players design swords from primitive parts in a free-transform blueprint editor, forge them through
three seeded skill minigames (smelting, hammering, sharpening), and show the results in their smithy.
Everything that decides an outcome is pure Luau shared by client and server and replayed on the server.

See [`SPEC.md`](./SPEC.md) for the Phase 1 (MVP) technical specification, which implements Louis Marec's design
draft. Start with §0: its 22 decisions to confirm (§0.4) are what the build waits on.

## Layout

```
SPEC.md                    technical spec, Phase 1 MVP (v1.0, for designer review)
docs/spec/
├── SPEC-evidence.md       evidence appendix (E-Sx.y): calibration tables, simulations, proofs
├── prototypes/S1…S8/      throwaway Lune prototypes behind the spec's numbers (not game code)
└── review/                review findings, the lead's verdicts and rulings (RULINGS.md)
vendor/ProfileStore/       vendored ProfileStore (MadStudioRoblox, commit 45c9847, Apache-2.0)
```

Planned source tree (SPEC §1.2–§1.4); none of it exists yet:

```
src/
├── shared/   → ReplicatedStorage.Blacksmith.*          (pure, Lune-tested; except Net/Remotes, Net/Client, Util/Signal, ItemRender/ItemModelBuilder)
├── client/   → StarterPlayer.StarterPlayerScripts.BlacksmithClient.*
└── server/   → ServerScriptService.BlacksmithServer.*
tests/        Lune specs, fixtures, goldens, Studio bridge
```

## Toolchain

Pinned in `aftman.toml` at the start of the build (SPEC §1.4): Rojo 7.7.0-rc.1 (same plugin protocol as the other
projects), Lune 0.8.9, luau-lsp.

```bash
aftman install
rojo serve                                                         # live-sync into Studio
rojo build default.project.json -o Blacksmith.rbxlx
rojo sourcemap default.project.json --include-non-scripts -o sourcemap.json
lune run tests/run                                                 # pure-module tests
lune run scripts/verify                                            # sourcemap → luau-lsp → tests
```

Build checklist (SPEC §1.4):
1. Creator Dashboard: Max Players = 8 (one smithy plot each).
2. Data stores: add the right-to-be-forgotten deletion template for store `PlayerData`, key pattern `User_{UserId}`,
   scope `global`, and test it with a dummy account.
3. Studio API access only on the separate test experience (SPEC §14).
4. After the first `rojo serve`, check that Workspace.StreamingEnabled and StarterPlayer.EnableMouseLockOption are false.

## Status

**Spec phase.** SPEC.md v1.0 is written, reviewed and checked, and waits for the designer's sign-off. No game code yet.
Implementation follows SPEC §18 (milestones M0–M9) once the §0.4 decisions are confirmed.
