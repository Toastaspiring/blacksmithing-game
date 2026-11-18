--!nocheck
-- The worst designs of the families, each spelled out, against V1's truth at a fine cell and the repo's oracle.
local V = require("./v1")
local Sets = require("./b_sets")
local Oracle = require("./tree/tests/Physics/VisibleOracle")
local fmt = string.format
local process = require("@lune/process")

local function find(family, name)
	for _, d in ipairs(Sets.get(family)) do
		if d.name == name then return d end
	end
	error("no " .. name)
end

local function show(family, name, labels)
	local d = find(family, name)
	local parts = d.parts
	V.renumber(parts)
	local real, read = V.reads(parts)
	local shares, lo, hi = V.T.all(parts, 0.0002)
	local P = V.prep(parts)
	local _, _, hider = Oracle.flags(P)
	print(fmt("%s: %s", family, name))
	for i, p in ipairs(parts) do
		print(fmt("   %2d %-7s %-11s %-6s pos %.4f %.4f %.4f size %.4f %.4f %.4f", i, tostring(p.label), p.shape, p.slot, p.pos[1], p.pos[2], p.pos[3], p.size[1], p.size[2], p.size[3]))
	end
	local row = {}
	for i = 1, #parts do row[i] = shares[i] ~= false and shares[i] >= 0.02 end
	for i, p in ipairs(parts) do
		for _, l in ipairs(labels) do
			if p.label == l then
				local o = Oracle.share(P, i, hider)
				print(fmt("   -> %s %s: true %.2f %% (repo's oracle %.2f %%), read %.2f %%, %s", tostring(p.label), p.shape, shares[i] * 100, o * 100, read[i] * 100, if real.kept[i] then "kept" else "CLEANED"))
			end
		end
	end
	local Rv, Rt = V.emu(parts), V.emu(parts, row)
	local w, tier, step = V.dDiff(Rv, Rt)
	local ok = V.valid(parts)
	print(fmt("   valid %s; build's verdict: %s | truth's verdict: %s | |dD| %.4f %s%s", tostring(ok), V.dline(Rv), V.dline(Rt), w, step, if tier then " TIER" else ""))
end

show("fuller", "w0.2 L2.5 t0.02 c0.050 g0.05 at0.5 twin", { "Core" })
show("fuller", "w0.3 L2.5 t0.04 c0.030 g0.03 at0.5 twin", { "Core" })
show("fuller", "w0.2 L2.5 t0.04 c0.030 g0.02 at0.5 twin", { "Core" })
show("fuller", "w0.4 L2.5 t0.04 c0.030 g0.03 at0.5 one", { "Core" })
show("fuller", "w0.8 L2.5 t0.08 c0.030 g0.01 at0.5 one", { "Core" })
show("comb", "1.2 x 2.5 x 0.2, centre covered, extra 0.0005", { "K" })
show("wall", "depth0.3 width1.2 L2.5 slit0.05 at0.100", { "K" })
show("bead", "d0.50 gap0.20 t1", { "Bead" })
show("oddPoke", "C02 Arming (Iron) #547 CornerWedge t0.030", { "Poke" })
