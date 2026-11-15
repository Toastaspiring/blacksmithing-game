--!nocheck
-- m2r5: the verifier's C09 plates under the repo's rule, the candidate and the recommended rule, with and without hidden blocks in the core.
local Sampling = require("./tree/src/shared/Physics/Sampling")
local Repo = require("./repo/src/shared/Physics/Sampling")
local Emu = require("./proto/analyze_build")
local O = require("./oracle")
local L = require("./lib")
local V = require("./variants")
local fmt = string.format
local I = L.I
local c09 = L.byPrefix("C09")
local core
for _, p in ipairs(c09.parts) do if p.label == "Core" then core = p end end
local function fill(parts, n)
	local slots = { "Guard", "Guard", "Guard", "Blade", "Blade", "Blade" }
	for k = 1, n do
		local g = 0.8 - 0.01 * k
		table.insert(parts, { slot = slots[k], shape = "Block", material = "Iron", pos = { core.pos[1], core.pos[2], core.pos[3] }, rot = I, size = { core.size[1] * g, core.size[2] * g, core.size[3] * g } })
	end
	return parts
end
local function line(parts, xi)
	L.renumber(parts)
	local P = L.prep(parts)
	local sh = O.all(P)
	local t = { fmt("true %.2f%%", sh[xi] * 100) }
	local kr = Repo.exposure(P).kept[xi]
	table.insert(t, "repo " .. (if kr then "kept" else "CLEANED"))
	for _, v in ipairs({ "A", "D", "P" }) do
		V.apply(Sampling, v)
		local ex = Sampling.exposure(P)
		local R = Emu.run({ name = "x", parts = parts }, { measureInvalid = true, build = true })
		local d = {}
		for _, s in ipairs(R.steps) do table.insert(d, fmt("%.4f%s", s.d, string.sub(s.tier, 1, 1))) end
		table.insert(t, fmt("%s %s [%s]", v, if ex.kept[xi] then "kept" else "CLEANED", table.concat(d, " ")))
	end
	return table.concat(t, " | ")
end
print("C09 alone:", line(L.copyParts(c09.parts), 1))
for _, def in ipairs({ { 0.12, 2.0, 0.05, -0.03, 5 }, { 0.09, 2.0, 0.04, -0.05, 2 }, { 0.10, 2.0, 0.05, -0.04, 2 }, { 0.08, 2.0, 0.04, -0.05, 2 }, { 0.06, 2.0, 0.03, -0.07, 2 }, { 0.06, 1.0, 0.03, -0.07, 2 } }) do
	local base = L.copyParts(c09.parts)
	table.insert(base, { label = "X", slot = "Blade", shape = "Block", material = "Iron", pos = { def[4], 2.6, 0 }, rot = I, size = { def[1], def[2], def[3] } })
	local xi = #base
	print(fmt("plate %.2f x %.1f x %.2f at x %.2f:", def[1], def[2], def[3], def[4]), line(L.copyParts(base), xi))
	print(fmt("  + %d hidden blocks:", def[5]), line(fill(L.copyParts(base), def[5]), xi))
end
