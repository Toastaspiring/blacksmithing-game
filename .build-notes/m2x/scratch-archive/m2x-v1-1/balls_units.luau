--!nocheck
-- ball clusters like P4, denser: their units (no timing)
local L = require("./lib")
local fmt = string.format
local SLOTS = { "Pommel", "Pommel", "Grip", "Grip", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade" }
local function cluster(d, dy, ax, y0)
	local parts = {}
	for i = 1, 24 do
		local x = ax * math.sin(i * 1.3)
		table.insert(parts, { id = i, slot = SLOTS[i], shape = "Ball", material = "Iron", pos = { x, y0 + (i - 1) * dy, 0 }, rot = { 0, 0, 0, 1 }, size = { d, d, d } })
	end
	return parts
end
for _, cfg in ipairs({ { 0.58, 0.17, 0.2 }, { 0.58, 0.12, 0.2 }, { 0.58, 0.10, 0.2 }, { 0.58, 0.08, 0.2 }, { 0.58, 0.06, 0.2 }, { 0.5, 0.07, 0.15 }, { 0.58, 0.09, 0.1 }, { 0.58, 0.07, 0.05 } }) do
	local parts = cluster(cfg[1], cfg[2], cfg[3], 0.3)
	local P = L.prep(parts)
	local e = L.Sampling.exposure(P)
	local r = L.run(L.copyParts(parts), { measureInvalid = false })
	print(fmt("d %.2f dy %.2f ax %.2f: units %.1f capped %s cleaned %d valid %s %s", cfg[1], cfg[2], cfg[3], e.verdictWork, tostring(e.capped), #e.cleaned, tostring(r.validation.ok), L.codes(r)))
end
