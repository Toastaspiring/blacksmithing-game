--!nocheck
-- B's collinear rule, the other direction: a filler F hidden on every face, its top covered by three hiders X, Y, Z whose
-- edges near F's facet edge x = +hx lie on the facet edge itself (X reaches past it), 1.5e-8 inside it (Y) and 3e-8
-- inside it (Z), with Z ranked first, then Y, then X. B drops X's edge (Y's line is "the same"), Y's (Z's is) and Z's
-- (X covers it): the facet's own edge leaves the boundary and Green's sum loses ½·(a × b) of it, so a filler that truly
-- shows nothing reads as showing. args: [scale]
local process = require("@lune/process")
local fs = require("@lune/fs")
local L = require("./jlib")
local fmt = string.format
local I = L.I

local s = tonumber(process.args[1] or "1") or 1 -- scale of the whole construction

local function design(g, scale)
	local parts = {}
	local function add(label, pos, size)
		table.insert(parts, { id = #parts + 1, label = label, shape = "Block", slot = "Blade", material = "Iron",
			pos = { pos[1] * scale, pos[2] * scale, pos[3] * scale }, rot = I, size = { size[1] * scale, size[2] * scale, size[3] * scale } })
	end
	add("Filler", { 0, 0, 0 }, { 2, 1, 2 })
	local eps = 1e-7 / scale -- the probe piece of a lower-ranked hider reaches EPS past its face
	-- Z: x ≤ 1 − 2g − EPS (its piece edge at 1 − 2g), z ∈ [−0.95, 1.2]; the thickest: rank first among the three
	-- thicknesses in studs whatever the scale (the probe must land inside: > HIDE_OFFSET), ranks Z > Y > X by volume
	local function cover(label, x0, x1, z0, z1, thAbs)
		local th = thAbs / scale
		add(label, { (x0 + x1) / 2, 0.5 + th / 2, (z0 + z1) / 2 }, { x1 - x0, th, z1 - z0 })
	end
	cover("Z", -1.2, 1 - 2 * g / scale - eps, -0.95, 1.2, 0.03 * math.max(scale, 1))
	cover("Y", -1.2, 1 - g / scale - eps, -1.2, 0.95, 0.025 * math.max(scale, 1))
	cover("X", 0, 1.2, -0.9, 0.9, 0.02 * math.max(scale, 1))
	add("WallXp", { 1.1, -0.05, 0 }, { 0.2, 1.1, 2.4 })
	add("WallXm", { -1.1, -0.05, 0 }, { 0.2, 1.1, 2.4 })
	add("WallZp", { 0, -0.05, 1.1 }, { 2.0, 1.1, 0.2 })
	add("WallZm", { 0, -0.05, -1.1 }, { 2.0, 1.1, 0.2 })
	add("Floor", { 0, -0.6, 0 }, { 2.0, 0.2, 2.0 })
	return parts
end

for _, g in ipairs({ 1e-8, 1.5e-8, 1.9e-8, 2.5e-8 }) do
	local parts = design(g, s)
	local P = L.prep(parts)
	local flags = { L.flags(P) }
	local A = L.readA(P, nil, flags)
	local B = L.readB(P, 32, 4, false, flags)
	local Jb = L.JBrute.readAll(P, flags, L.cands, nil, nil)
	local t = L.truth(P, 1)
	print(fmt("scale %g g %.2g: filler share  A %.6f%%  B %.6f%%  brute %.6f%%  truth %.4f%%  ranks %s", s, g,
		100 * A[1].shown / A[1].area, 100 * B[1].shown / B[1].area, 100 * Jb[1].shown / Jb[1].area, 100 * t, table.concat(flags[1], ",")))
	if g == 1.5e-8 then
		fs.writeFile(fmt("out/chain2_design_s%g.json", s), "[" .. L.encodeDesign("chain2 hidden filler g=1.5e-8 scale " .. s, parts) .. "]\n")
	end
end
