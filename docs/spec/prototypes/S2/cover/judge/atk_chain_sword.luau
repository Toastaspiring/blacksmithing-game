--!nocheck
-- B's collinear-rule defect in valid swords: the two chain constructions (chain.luau, chain2.luau) on C01 Minimal's blade,
-- scaled to fit the hitbox, then M3 through the emulator. hidden: a filler that truly shows nothing is read by B as
-- showing 5.6 % (kept); visible: a part that truly shows 5 % is read by B as showing 0 (cleaned).
-- args: [scale] [y]
local process = require("@lune/process")
local fs = require("@lune/fs")
local L = require("./jlib")
local M3 = require("./m3j")
local fmt = string.format
local I = L.I

local s = tonumber(process.args[1] or "0.2") or 0.2
local cy = tonumber(process.args[2] or "3.3") or 3.3
local g = 1.5e-8

local function base()
	return {
		{ id = 1, label = "Pommel", shape = "Block", slot = "Pommel", material = "Iron", pos = { 0, 0.35, 0 }, rot = I, size = { 0.3, 0.3, 0.3 } },
		{ id = 2, label = "Grip", shape = "Block", slot = "Grip", material = "Iron", pos = { 0, 1, 0 }, rot = I, size = { 0.2, 1, 0.2 } },
		{ id = 3, label = "Guard", shape = "Block", slot = "Guard", material = "Iron", pos = { 0, 1.6, 0 }, rot = I, size = { 1, 0.2, 0.3 } },
		{ id = 4, label = "Blade", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, 2.9, 0 }, rot = I, size = { 0.25, 2.4, 0.1 } },
	}
end

-- local unit coordinates (target 2 × 1 × 2 at the origin) → world: x·s + cx, y·s + cy, z·s
local function construct(kind)
	local parts = base()
	local cx = 0.125 + 1.2 * s -- the −X wall's outer face on the blade's +X face
	local function add(label, pos, size, shape)
		table.insert(parts, { id = #parts + 1, label = label, shape = shape or "Block", slot = "Blade", material = "Iron",
			pos = { cx + pos[1] * s, cy + pos[2] * s, pos[3] * s }, rot = I, size = { size[1] * s, size[2] * s, size[3] * s } })
	end
	add("Target", { 0, 0, 0 }, { 2, 1, 2 })
	local eps = 1e-7 / s
	local function cover(label, x0, x1, z0, z1, thAbs)
		local th = thAbs / s
		add(label, { (x0 + x1) / 2, 0.5 + th / 2, (z0 + z1) / 2 }, { x1 - x0, th, z1 - z0 })
	end
	if kind == "hidden" then
		cover("Z", -1.2, 1 - 2 * g / s - eps, -0.95, 1.1, 0.03)
		cover("Y", -1.2, 1 - g / s - eps, -1.1, 0.95, 0.025)
		cover("X", 0, 1.2, -0.9, 0.9, 0.02)
	else
		-- visible: a lid over x ≤ 0.5 and the chain I, M, O over x ≥ c (c = 0.9), I ranked first
		cover("Lid", -1.2, 0.5, -1.1, 1.1, 0.02)
		local c = 0.9
		cover("I", c + 2 * g / s + eps, 1.2, -1.1, 0.95, 0.03)
		cover("M", c + g / s + eps, 1.2, -0.95, 1.1, 0.025)
		cover("O", c + eps, 1.2, -0.9, 0.9, 0.02)
	end
	add("WallXp", { 1.1, -0.05, 0 }, { 0.2, 1.1, 2.4 })
	add("WallXm", { -1.1, -0.05, 0 }, { 0.2, 1.1, 2.4 })
	add("WallZp", { 0, -0.05, 1.1 }, { 2.0, 1.1, 0.2 })
	add("WallZm", { 0, -0.05, -1.1 }, { 2.0, 1.1, 0.2 })
	add("Floor", { 0, -0.6, 0 }, { 2.0, 0.2, 2.0 })
	return parts
end

local out = {}
for _, kind in ipairs({ "hidden", "visible" }) do
	local parts = construct(kind)
	local ok, why = M3.valid(parts)
	local R = M3.rows(parts)
	local t = 5 -- the target's index
	local sh = R.shares[t]
	print(fmt("%s (scale %g, y %g): valid %s %s", kind, s, cy, tostring(ok), why))
	print(fmt("  target: truth %.4f%%  today %s  A %.4f%%  A canon %.4f%%  A fine %.4f%%  B %.4f%%", 100 * sh.truth,
		if R.today[t] then "kept" else "cleaned", 100 * sh.A, 100 * sh.Acanon, 100 * sh.Afine, 100 * sh.B))
	local function rowStr(row) local t2 = {} for i = 1, #row do t2[i] = if row[i] then "1" else "0" end return table.concat(t2) end
	print("  rows: truth " .. rowStr(R.truth) .. "  A " .. rowStr(R.A) .. "  B " .. rowStr(R.B) .. "  today " .. rowStr(R.today))
	local dd, tier, line = M3.compare(parts, R.B, R.truth)
	print(fmt("  B's row against the truth's: |dD| %s%s  [%s]", if dd then fmt("%.4f", dd) else "n/a", if tier then " TIER" else "", line or ""))
	local dd2, tier2, line2 = M3.compare(parts, R.A, R.truth)
	print(fmt("  A's row against the truth's: |dD| %s%s", if dd2 then fmt("%.4f", dd2) else "n/a", if tier2 then " TIER" else ""))
	local dd3, tier3, line3 = M3.fillerEffect(parts, t, R.truth)
	print(fmt("  K alone against K + target (truth rows): |dD| %s%s  [%s]", if dd3 then fmt("%.4f", dd3) else "n/a", if tier3 then " TIER" else "", line3 or ""))
	table.insert(out, L.encodeDesign(fmt("chain %s in C01, scale %g", kind, s), parts))
end
fs.writeFile(fmt("out/atk_chain_sword_s%g.json", s), "[\n" .. table.concat(out, ",\n") .. "\n]\n")
