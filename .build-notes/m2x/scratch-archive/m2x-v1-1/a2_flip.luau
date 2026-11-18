--!nocheck
-- A2: a copy of a part that is the same solid but not the same frame (a Block turned 180° about one of its axes, a Cylinder
-- spun about its own axis) is no "exact copy" (Shapes.sameSolid compares frames): the rank's frame keys decide which keeps
-- the shared faces, not the slot's name. In the Guard it takes the blade out of the Blade (§17.2 / O8 say no copy can).
local L = require("./lib")
local fmt = string.format
local function report(name, parts)
	L.renumber(parts)
	local ok, why = L.canonical(L.copyParts(parts))
	local r = L.run(L.copyParts(parts), { measureInvalid = false })
	local P = L.prep(parts)
	local e = L.Sampling.exposure(P)
	local cl = {}
	for _, c in ipairs(e.cleaned) do table.insert(cl, c.partId .. ":" .. c.reason) end
	local R = L.emu(L.copyParts(parts))
	print(fmt("%-44s canonical %s valid %s cleaned {%s}  %s", name, tostring(ok), tostring(r.validation.ok), table.concat(cl, " "), L.dline(R)))
	return R
end
local base = L.repoFixture("F3")
local R0 = report("F3", L.copyParts(base))
local blade = base[6]
local function withCopy(slot, rot, what)
	local parts = L.copyParts(base)
	local c = L.copyPart(blade)
	c.slot, c.rot = slot, rot
	table.insert(parts, c)
	local R = report("F3 + " .. what, parts)
	local d, t, s = L.dDiff(R0, R)
	print(fmt("    |dD| %.4f on %s, tier flip %s", d, s, tostring(t)))
end
withCopy("Guard", { 0, 0, 0, 1 }, "an exact copy of its blade in the Guard")
withCopy("Guard", { 0, 1, 0, 0 }, "its blade turned 180° about Y, in the Guard")
withCopy("Guard", { 1, 0, 0, 0 }, "its blade turned 180° about X, in the Guard")
withCopy("Guard", { 0, 0, 1, 0 }, "its blade turned 180° about Z, in the Guard")
withCopy("Pommel", { 0, 1, 0, 0 }, "its blade turned 180° about Y, as Pommel")
withCopy("Blade", { 0, 1, 0, 0 }, "its blade turned 180° about Y, in the Blade")
-- the same on C08 (greatsword, Sharpening Hard)
local okC08, c08 = pcall(L.fixture, "C08")
if okC08 then
	base = c08
	R0 = report("C08", L.copyParts(base))
	for i, p in ipairs(base) do
		if p.slot == "Blade" and p.shape == "Block" then blade = p; print("  C08 blade part", i, table.concat(p.size, ",")); break end
	end
	withCopy("Guard", { 0, 0, 0, 1 }, "an exact copy of its blade in the Guard")
	withCopy("Guard", { 0, 1, 0, 0 }, "its blade turned 180° about Y, in the Guard")
end
