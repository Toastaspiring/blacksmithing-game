--!nocheck
-- the emulator on the build: C09 in 300 random orders, P5 in 60 (M3's probes still go in part order); C09 + a plate that
-- shows 20 %, kept, with 5 hidden blocks, and cleaned
local L = require("./lab")
local E = require("./emulab")
local fmt = string.format
local rng = L.TestRng.new(20261113)
local function shuffled(list)
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:int(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end
local function ranges(name, parts, n)
	local lo, hi = {}, {}
	for k = 1, n do
		local R = E.run(if k == 1 then parts else shuffled(parts))
		for i, s in ipairs(R.steps) do
			lo[i] = math.min(lo[i] or math.huge, s.d)
			hi[i] = math.max(hi[i] or -math.huge, s.d)
		end
	end
	local t = {}
	for i = 1, #lo do table.insert(t, fmt("%.4f–%.4f", lo[i], hi[i])) end
	print(fmt("%s in %d orders: %s", name, n, table.concat(t, ", ")))
end
local C09 = L.H.ornate().parts
print("C09 " .. E.dline(E.run(C09)))
ranges("C09", C09, 300)
for _, b in ipairs(L.Fx.perf()) do
	if string.sub(b.name, 1, 2) == "P5" then
		print("P5 " .. E.dline(E.run(b.parts)))
		ranges("P5", b.parts, 60)
	end
end
local base = L.H.ornate()
table.insert(base.parts, L.H.part(50, "Blade", "Block", "Iron", { -0.03, 2.6, 0 }, L.H.I, { 0.12, 2, 0.05 }))
local P = L.prepared(base.parts)
local e = L.Sampling.exposure(P)
local n = #base.parts
local _, _, hider = L.Oracle.flags(P)
print(fmt("C09 + plate: kept %s, truth %.2f%%  %s", tostring(e.kept[n]), 100 * L.Oracle.share(P, n, hider), E.dline(E.run(base.parts))))
local row = table.clone(e.kept)
row[n] = false
print("C09 + plate, the plate cleaned: " .. E.dline(E.run(base.parts, row)))
local core = base.parts[12]
local filled = table.clone(base.parts)
local SLOTS = { "Guard", "Guard", "Guard", "Blade", "Blade" }
for k = 1, 5 do
	local g = 0.8 - 0.01 * k
	table.insert(filled, L.H.part(100 + k, SLOTS[k], "Block", "Iron", core.pos, core.rot, { core.size[1] * g, core.size[2] * g, core.size[3] * g }))
end
print("C09 + plate + 5 hidden blocks: " .. E.dline(E.run(filled)))
