--!nocheck
-- design sets for the timing and gap runs
local L = require("./lib")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local M = {}
local SLOTS = { "Pommel", "Pommel", "Grip", "Grip", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade" }
function M.cluster(d, dy, ax, y0)
	local parts = {}
	for i = 1, 24 do
		table.insert(parts, { id = i, slot = SLOTS[i], shape = "Ball", material = "Iron", pos = { ax * math.sin(i * 1.3), y0 + (i - 1) * dy, 0 }, rot = { 0, 0, 0, 1 }, size = { d, d, d } })
	end
	return parts
end
function M.sets(which)
	local out = {}
	local function add(name, parts) table.insert(out, { name = name, parts = L.copyParts(parts) }) end
	if which == "real" or which == "all" then
		for _, id in ipairs({ "F1", "F2", "F3", "F4", "F5" }) do add(id, L.repoFixture(id)) end
		for _, b in ipairs(L.Fx.calibration()) do if b.parts then add(b.name, b.parts) end end
		for _, b in ipairs(L.Fx.regression()) do
			local p = b.parts or (b.fixture and b.fixture.parts)
			if p then add(b.name or b.fixture.name, p) end
		end
		for _, b in ipairs(L.Fx.perf()) do add(b.name, b.parts) end
	end
	if which == "worst" or which == "all" then
		for k, d in ipairs(Worst.valid) do add("worst valid " .. k, d.parts) end
		for k, d in ipairs(Worst.tooComplex) do if k <= 6 then add("tooComplex " .. k, d.parts) end end
		add("V1 ball cluster d0.58 dy0.08", M.cluster(0.58, 0.08, 0.2, 0.3))
	end
	if which == "perf" then
		for _, b in ipairs(L.Fx.perf()) do add(b.name, b.parts) end
		for k, d in ipairs(Worst.valid) do add("worst valid " .. k, d.parts) end
		add("V1 ball cluster d0.58 dy0.08", M.cluster(0.58, 0.08, 0.2, 0.3))
	end
	return out
end
return M
