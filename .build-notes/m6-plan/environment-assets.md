# M6: the map's environment assets come from Blender (Louis, 2026-11-19)

Louis's instruction: build the MVP map's environment assets in Blender, driven through the Blender MCP server.
- Keep the models simple and game-ready for Roblox.
- Export each asset as FBX.
- Upload them automatically with Roblox's upload API (Open Cloud Assets).

## Setup, in Louis's order

1. Install uv with the PowerShell command from the official uv site (astral.sh), then open a new terminal so it is on
   PATH.
2. `uvx mcp-for-blender install-addon` copies the Blender add-on.
3. In Blender: Edit → Preferences → Add-ons, enable "Interface: MCP for Blender". If it is not listed: Install… and
   pick the copied `blender_mcp.py` or `addon.py`.
4. In the 3D viewport: N, the MCP for Blender tab, Start MCP Server. It stays running while Claude Code works.
5. `claude mcp add blender uvx mcp-for-blender`, then `claude mcp list`. If uvx is not found, use its full path from
   `where uvx`.

## What the lead checked on 2026-11-19

- `mcp-for-blender` on PyPI (2.3.1) is the renamed `blender-mcp`, by Siddharth Ahuja (github.com/ahujasid/blender-mcp).
  `blender-mcp` 2.0.0 says "Renamed to mcp-for-blender".
- Blender 5.3 is installed (`C:\Program Files\Blender Foundation\Blender 5.3`). uv and uvx are not installed yet.
- The MCP server's tools reach Claude Code only in a session started after step 5.

## What it changes in the SPEC (to settle when M6 is planned)

The SPEC builds the world from primitive parts: `WorldBuilder.build()` reads `Definitions/World`'s Build list (S7,
E-S7.1: 102 parts per plot, 57 colliding: shell 49, `HomeSpawn` 1, stations 28, stands 24), pinned by
`tests/golden/world_build_list.golden.txt` and the T-WLD tests. M6's plan decides:
- which pieces become Blender meshes (shell, stations, stands, props) and which stay parts (spawns, collision);
- how the game reaches the uploaded meshes (asset ids in `Definitions/World`; a Model asset loaded on the server, or
  MeshParts kept in a synced .rbxmx);
- triangle budgets, collision fidelity, scale in studs, and what the build-list golden and T-WLD then pin.
§15.1's "MeshParts" row ("Not in the MVP") is about the sword editor's parts (S2), not the world.

## Before acting

Louis confirms each of these at the time:
- the uv installer, which downloads and runs a script;
- `claude mcp add`, which is persistent configuration;
- the first upload batch, which publishes to Roblox.

Nobody but Louis handles the Open Cloud API key. He creates it with asset read and write scopes and puts it in an
environment variable that the upload script reads. The Roblox Studio MCP's `open_cloud_invoke` may make the key
unnecessary; check at M6.
