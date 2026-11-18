--!nocheck
-- Attack on B's collinear rule (LINE_TOL 2e-8 is not transitive): three hiders whose edges on a facet lie on lines
-- c, c + g, c + 2g (g = 1.5e-8 ≤ LINE_TOL, 2g > LINE_TOL), taken in the order inner < middle < outer. B's union drops
-- every copy of the shared boundary segment, so Green's sum loses that edge's ½·(a × b): an error of the order of the
-- facet, not of the gap. A, the brute force and the truth read the true area.
-- args: [gap] [c] [variant]
local process = require("@lune/process")
local fs = require("@lune/fs")
local L = require("./jlib")
local fmt = string.format

local gap = tonumber(process.args[1] or "1.5e-8") or 1.5e-8
local c = tonumber(process.args[2] or "0.9") or 0.9
local I = L.I

-- target p: Block 2 × 1 × 2 at the origin; its top face y = 0.5, x, z ∈ [−1, 1]
local function design(g, cc, withHost)
	local parts = {}
	local function add(label, shape, pos, size, slot)
		table.insert(parts, { id = #parts + 1, label = label, shape = shape, slot = slot or "Blade", material = "Iron",
			pos = pos, rot = I, size = size })
	end
	add("Target", "Block", { 0, 0, 0 }, { 2, 1, 2 })
	-- chain hiders, flush on the top face (bottom y = 0.5), lower rank than p (smaller), covering x ≥ X_k:
	-- I (inner, X = c + 2g, highest rank), M (X = c + g), O (outer, X = c, lowest rank)
	local function chainBlock(label, X, z0, z1, th)
		local x1 = 1.2
		add(label, "Block", { (X + x1) / 2, 0.5 + th / 2, (z0 + z1) / 2 }, { x1 - X, th, z1 - z0 })
	end
	chainBlock("I", cc + 2 * g, -1.2, 0.95, 0.12)
	chainBlock("M", cc + g, -0.95, 1.2, 0.11)
	chainBlock("O", cc, -0.9, 0.9, 0.10)
	if withHost then
		-- lid over x ≤ 0.5 and walls round the other faces, all lower rank, so only [0.5, c] × [−1, 1] of the top shows
		add("Lid", "Block", { -0.35, 0.55, 0 }, { 1.7, 0.1, 2.4 })
		add("WallXp", "Block", { 1.1, -0.05, 0 }, { 0.2, 1.1, 2.4 })
		add("WallXm", "Block", { -1.1, -0.05, 0 }, { 0.2, 1.1, 2.4 })
		add("WallZp", "Block", { 0, -0.05, 1.1 }, { 2.0, 1.1, 0.2 })
		add("WallZm", "Block", { 0, -0.05, -1.1 }, { 2.0, 1.1, 0.2 })
		add("Floor", "Block", { 0, -0.6, 0 }, { 2.0, 0.2, 2.0 })
	end
	return parts
end

local function run(name, parts)
	local P = L.prep(parts)
	local flags = { L.flags(P) }
	local rank = flags[1]
	local A = L.readA(P, nil, flags)
	local B = L.readB(P, 32, 4, false, flags)
	local Jb = L.JBrute.readAll(P, flags, L.cands, nil, nil)
	local t = L.truth(P, 1)
	print(fmt("%s: target share  A %.6f%%  B %.6f%%  brute %.6f%%  truth %.4f%%   (ranks: %s)", name, 100 * A[1].shown / A[1].area,
		100 * B[1].shown / B[1].area, 100 * Jb[1].shown / Jb[1].area, 100 * t, table.concat(rank, ",")))
	-- top facet alone
	local topA, topB, topJ = 0, 0, 0
	for f = 1, #B[1].per do
		if math.abs(B[1].per[f] - Jb[1].per[f]) > 1e-9 then
			print(fmt("    facet %d: B %.9f brute %.9f (diff %.3g)", f, B[1].per[f], Jb[1].per[f], B[1].per[f] - Jb[1].per[f]))
		end
	end
	return A[1].shown / A[1].area, B[1].shown / B[1].area, Jb[1].shown / Jb[1].area, t
end

print(fmt("gap %.3g, c %.3g", gap, c))
local a, b, j, t = run("chain alone", design(gap, c, false))
local a2, b2, j2, t2 = run("chain in a host", design(gap, c, true))
-- the same with the order reversed (outer highest rank): B is right then
local function swapped(g, cc)
	local parts = design(g, cc, true)
	-- make O the biggest by thickness: rank O > M > I
	parts[2].size[2], parts[4].size[2] = 0.10, 0.30
	parts[2].pos[2], parts[4].pos[2] = 0.5 + 0.05, 0.5 + 0.15
	return parts
end
run("chain in a host, order outer first", swapped(gap, c))
-- gaps: the error appears only for g in (LINE_TOL/2, LINE_TOL]
for _, g in ipairs({ 5e-9, 1e-8, 1.2e-8, 1.5e-8, 1.9e-8, 2e-8, 2.1e-8, 3e-8, 1e-7 }) do
	local parts = design(g, c, true)
	local P = L.prep(parts)
	local flags = { L.flags(P) }
	local A = L.readA(P, nil, flags)
	local B = L.readB(P, 32, 4, false, flags)
	print(fmt("  g %.2g: A %.6f%%  B %.6f%%", g, 100 * A[1].shown / A[1].area, 100 * B[1].shown / B[1].area))
end
fs.writeFile("out/chain_design.json", "[" .. L.encodeDesign("chain in a host g=" .. gap, design(gap, c, true)) .. "]\n")
