--!nocheck
-- V2 round 3: §4.4 / §17.2 / O8's numbers through the M3 emulator on the repo (emuNow): F3's and C08's blade relabelled or
-- enclosed by a copy a hair larger in the Guard, F5's and F3's guards with 4 skins labelled Blade or relabelled Blade, F3 + a
-- copy of its guard in the Blade, C09 + a plate that shows 20 % (kept, then with 5 hidden blocks), and the plate cleaned.
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3"
local R = W .. "/repo"
local Emu = require(W .. "/emuNow/proto/analyze_build")
local Fx = require(W .. "/emuNow/proto/fixtures")
local B = require(R .. "/tests/fixtures/Blueprints")
local H = require(R .. "/tests/Physics/PhysicsHelpers")
local Oracle = require(R .. "/tests/Physics/VisibleOracle")
local Sampling = require(R .. "/src/shared/Physics/Sampling")
local fmt = string.format

local function copy(parts)
	local out = {}
	for i, p in ipairs(parts) do
		out[i] = { id = i, label = p.label, slot = p.slot, shape = p.shape, material = p.material or "Iron",
			pos = { p.pos[1], p.pos[2], p.pos[3] }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] },
			size = { p.size[1], p.size[2], p.size[3] } }
	end
	return out
end
local function dline(parts, force)
	local R = Emu.run({ name = "x", parts = parts }, { measureInvalid = true, build = true, forceClean = force })
	local t = {}
	for _, s in ipairs(R.steps) do
		table.insert(t, fmt("%s %.4f %s", string.sub(s.step, 1, 2), s.d, string.sub(s.tier, 1, 1)))
	end
	return table.concat(t, ", ")
end
local function keptRow(parts)
	local P = H.prepared({ parts = parts })
	local e = Sampling.exposure(P)
	local t = {}
	for i = 1, #P do
		t[i] = if e.kept[i] then "K" else "E"
	end
	return table.concat(t)
end

-- F3 and C08: the blade, relabelled Guard, or with a copy a hair larger in the Guard
local C08
for _, b in ipairs(Fx.calibration()) do
	if string.sub(b.name, 1, 3) == "C08" then
		C08 = b
	end
end
for _, case in ipairs({ { "F3", B.core("F3").parts, 6 }, { "C08", C08.parts, 4 } }) do
	local base = copy(case[2])
	local i = case[3]
	print(fmt("%s: %s", case[1], dline(base)))
	local relabelled = copy(base)
	relabelled[i].slot = "Guard"
	print(fmt("   blade relabelled Guard: %s", dline(relabelled)))
	for _, grow in ipairs({ 1e-12, 1e-6, 1e-4 }) do
		local parts = copy(base)
		local b = base[i]
		table.insert(parts, { id = #parts + 1, slot = "Guard", shape = b.shape, material = b.material, pos = table.clone(b.pos), rot = table.clone(b.rot),
			size = { b.size[1] + grow, b.size[2] + grow, b.size[3] + grow } })
		print(fmt("   + its blade %g larger in the Guard: %s  %s", grow, keptRow(parts), dline(parts)))
	end
end

-- F5 and F3: 4 skins 0.02 thick flush inside the guard, labelled Blade; the guard relabelled Blade; F3 + a guard copy in the Blade
for _, name in ipairs({ "F5", "F3" }) do
	local base = copy(B.core(name).parts)
	local gi
	for k, p in ipairs(base) do
		if p.slot == "Guard" and p.shape == "Block" then
			gi = k
		end
	end
	local h = base[gi]
	local tz, tx = math.min(0.02, h.size[3] / 3), math.min(0.02, h.size[1] / 3)
	local skins = copy(base)
	for _, s in ipairs({
		{ { h.pos[1], h.pos[2], h.pos[3] + (h.size[3] - tz) / 2 }, { h.size[1], h.size[2], tz } },
		{ { h.pos[1], h.pos[2], h.pos[3] - (h.size[3] - tz) / 2 }, { h.size[1], h.size[2], tz } },
		{ { h.pos[1] + (h.size[1] - tx) / 2, h.pos[2], h.pos[3] }, { tx, h.size[2], h.size[3] } },
		{ { h.pos[1] - (h.size[1] - tx) / 2, h.pos[2], h.pos[3] }, { tx, h.size[2], h.size[3] } },
	}) do
		table.insert(skins, { id = #skins + 1, slot = "Blade", shape = "Block", material = "Iron", pos = s[1], rot = table.clone(h.rot), size = s[2] })
	end
	local relabelled = copy(base)
	relabelled[gi].slot = "Blade"
	local guardCopy = copy(base)
	table.insert(guardCopy, { id = #guardCopy + 1, slot = "Blade", shape = h.shape, material = h.material, pos = table.clone(h.pos), rot = table.clone(h.rot), size = table.clone(h.size) })
	print(fmt("%s: %s | + 4 skins in its guard, labelled Blade: %s %s | guard relabelled Blade: %s | + a copy of its guard in the Blade: %s",
		name, dline(base), keptRow(skins), dline(skins), dline(relabelled), dline(guardCopy)))
end

-- C09 + a plate 0.12 × 2 × 0.05 in the Blade (fix/orders.luau's), its truth; with 5 hidden blocks; the plate cleaned
local c09 = H.ornate()
local plated = copy(c09.parts)
table.insert(plated, { id = 50, slot = "Blade", shape = "Block", material = "Iron", pos = { -0.03, 2.6, 0 }, rot = { 0, 0, 0, 1 }, size = { 0.12, 2, 0.05 } })
local P = H.prepared({ parts = plated })
local _, _, hider = Oracle.flags(P)
print(fmt("C09 + plate: kept %s, truth %.2f %%: %s", tostring(Sampling.exposure(P).kept[#plated]), 100 * Oracle.share(P, #plated, hider), dline(plated)))
print(fmt("   the plate cleaned (forced): %s", dline(plated, { #plated })))
