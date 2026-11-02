# tools/

Build and test tooling (SPEC §1.2, §14.2). Nothing here is synced into the place.

| Path | What | Used by |
|---|---|---|
| `luau-lsp/globalTypes.None.d.luau` | Roblox type definitions, security level None (game scripts) | `scripts/verify`, luau-lsp pass A: `--definitions:@roblox=tools/luau-lsp/globalTypes.None.d.luau` |
| `runner-selftest/pass/` | specs that all pass: the runner exits 0 both plainly and with `--seed 591835543` (the first case seed drawn from `PROP_BASE_SEED`, which its two properties replay; an unshared `Prop` instance would replay nothing and exit 2, so this checks the shared instance); with `--seed 1` it exits 2, nothing replayed | T-META-05 (`tests/Meta/Runner.spec.luau`) |
| `runner-selftest/fail/` | one FAIL (assertion) and one ERROR (crash): the runner exits 1 | T-META-05 |
| `runner-selftest/broken/` | `syntax/` does not parse, `nosuite/` returns no suite, `duplicate/` repeats a suite name: the runner exits 2 | T-META-05 |
| `telemetry_csv.luau` | playtest `[TLM]` lines to CSV (SPEC §14.13, §16.34) | built in M9 |

## Roblox definitions file

| | |
|---|---|
| Source | `https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.None.d.luau` |
| Tag | `1.70.1`, the luau-lsp version pinned in `aftman.toml` |
| Git blob | `674fd4f5d95eaf5d0061ab403b1648c6fd341b80` (677,555 bytes; SHA-256 `9ad75109b8dc9197f6d1726208bfa0b12de47c3a43672a4fa43227f0cec609ee`) |
| Fetched | 2026-10-31, unmodified |

When the luau-lsp pin in `aftman.toml` changes, download the same file from the new tag's `scripts/` folder, update
this table, and run `lune run scripts/verify`.

`scripts/verify` refuses an empty, cut or foreign file with exit 4 before luau-lsp runs, because luau-lsp 1.70.1
loads an empty definitions file silently. The checks are `tests/Meta/GlobalTypes` (planted in
`tests/Meta/Tools.spec.luau`), in order: at least 100,000 bytes, a final newline, the text tokenizes, brackets
balance, at least 500 `declare extern type … with` blocks each closed by one `end`, and `declare` lines for the
globals `game`, `workspace`, `script`, `Enum`, `Instance`, `Vector3`, `CFrame`, `Color3` and `task`. Verify also exits
4 when luau-lsp prints `Failed to read definitions file`. When the pin changes, check `GlobalTypes.MIN_BLOCKS` (the
1.70.1 file has 2,238 blocks) and `GlobalTypes.REQUIRED` against the new file.

## Why luau-lsp 1.70.1 and not 1.67.0

SPEC §14.4 asks for luau-lsp ≥ 1.67.0, and the approved SPEC pinned 1.67.0 itself in §1.4. 1.67.0 cannot run here:
Microsoft Defender detects the binary of its `luau-lsp-win64.zip` as `Trojan:Win32/Malgent` (threat id 2147794830)
and deletes it, so `scripts/verify` cannot run with it. Nothing here overrides or excludes that detection. 1.70.1
runs and is not flagged. Proof, 2026-10-31, from the repo root with `luau-lsp = "JohnnyMorganz/luau-lsp@1.67.0"` in
`aftman.toml`:

```
$ aftman install
[INFO  aftman::tool_storage] Installing tool: JohnnyMorganz/luau-lsp@1.67.0
[INFO  aftman::tool_storage] Downloading JohnnyMorganz/luau-lsp v1.67.0 (luau-lsp-win64.zip)...
[INFO  aftman::tool_storage] JohnnyMorganz/luau-lsp v1.67.0 installed successfully.
$ luau-lsp --version
Aftman error: Failed to run tool JohnnyMorganz/luau-lsp@1.67.0, your installation may be corrupt.

Caused by:
    0: Could not spawn C:\Users\louis\.aftman\tool-storage\JohnnyMorganz\luau-lsp\1.67.0\luau-lsp.exe
    1: Operation did not complete successfully because the file contains a virus or potentially unwanted software. (os error 225)
```

Defender's detection history (`Get-MpThreatDetection`) lists that file at 19:19 and an earlier manual download of
1.67.0 at 19:00, both removed. The 1.67.0 tag's definitions file is fine (git blob
`1902eca3a0ef942451835248ba79f96eeb49e9a1`, 606,434 bytes); only the binary is blocked. So SPEC §1.4 and
`aftman.toml` pin 1.70.1, the version the M0 build verified green. To move the pin, follow the paragraph above and
check `luau-lsp --version` right after `aftman install`.
