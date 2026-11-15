--!nocheck
-- D through the emulator, the build before (V1's emu: m2x-v1-1/emu, the tree before this round) against now (./emu), on the
-- fixtures, C09 and the attack designs. args: set
local process = require("@lune/process")
local L = require("./lab")
local Now = require("./emulab")
local Before = (require :: any)("C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v1-1/emu/proto/analyze_build")
local fmt = string.format
local function before(parts)
	local copy = {}
	for i, p in ipairs(parts) do
		copy[i] = { id = i, slot = p.slot or "Blade", shape = p.shape, material = p.material or "Iron", pos = { p.pos[1], p.pos[2], p.pos[3] },
			rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] }, size = { p.size[1], p.size[2], p.size[3] } }
	end
	return Before.run({ name = "x", parts = copy }, { measureInvalid = true, build = true })
end
local designs = {}
for _, id in ipairs(L.Blueprints.order) do table.insert(designs, { name = id, parts = L.Blueprints.core(id).parts }) end
table.insert(designs, { name = "C09", parts = L.H.ornate().parts })
for _, s in ipairs({ L.Fx.calibration(), L.Fx.regression(), L.Fx.perf() }) do
	for _, b in ipairs(s) do
		if b.parts then table.insert(designs, { name = b.name, parts = b.parts })
		elseif b.fixture then table.insert(designs, { name = b.fixture.name, parts = b.fixture.parts }) end
	end
end
for _, d in ipairs(L.Attacks) do table.insert(designs, { name = "atk " .. d.name, parts = d.parts }) end
local moved, worst = 0, 0
for _, d in ipairs(designs) do
	local a, b = before(d.parts), Now.run(d.parts)
	local dd, t, s = Now.diff(a, b)
	if dd ~= 0 then
		moved += 1
		worst = math.max(worst, dd)
		print(fmt("%-50s |dD| %.6f on %s, tier %s: %s -> %s", string.sub(d.name, 1, 50), dd, s, tostring(t), Now.dline(a), Now.dline(b)))
	end
end
print(fmt("%d designs, %d move, worst |dD| %.6f", #designs, moved, worst))
