--!nocheck
-- fix-2: a1d's worst design (F3 + a tie-axis rod in the Guard + its copy spun 55° in the Blade) on cur, pre and fin
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-fix-2"
local fmt = string.format
local function req(p) return (require :: any)(p) end
local Quat = req(W .. "/fin/src/shared/Blueprint/Quat")
local B = req(W .. "/fin/tests/fixtures/Blueprints")
local function axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.hemisphere(Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
end
local q = Quat.hemisphere(Quat.normalize(Quat.mul(axisAngle(1, 0, 0, 45), axisAngle(0, 0, 1, 45))))
for _, spin in ipairs({ 35, 55 }) do
	for _, slot in ipairs({ "Guard", "Blade" }) do
		local parts = {}
		for i, p in ipairs(B.core("F3").parts) do parts[i] = p end
		table.insert(parts, { id = 0, slot = "Guard", shape = "Cylinder", material = "Iron", pos = { 0, 1.24, 0 }, rot = q, size = { 0.5, 0.08, 0.08 } })
		table.insert(parts, { id = 0, slot = slot, shape = "Cylinder", material = "Iron", pos = { 0, 1.24, 0 }, rot = Quat.hemisphere(Quat.normalize(Quat.mul(q, axisAngle(1, 0, 0, spin)))), size = { 0.5, 0.08, 0.08 } })
		for i, p in ipairs(parts) do p.id = i end
		local n = #parts
		local row = {}
		for _, t in ipairs({ "cur", "pre", "fin" }) do
			local Shapes = req(W .. "/" .. t .. "/src/shared/Physics/Shapes")
			local Sampling = req(W .. "/" .. t .. "/src/shared/Physics/Sampling")
			local Oracle = req(W .. "/" .. t .. "/tests/Physics/VisibleOracle")
			local H = req(W .. "/" .. t .. "/tests/Physics/PhysicsHelpers")
			local P = {}
			for i, p in ipairs(parts) do P[i] = Shapes.prepare(p, i) end
			local e = Sampling.exposure(P)
			local _, _, hider = Oracle.flags(P)
			table.insert(row, fmt("%s: kept %s/%s reads %.2f/%.2f %% truth %.2f/%.2f %% vol %.17g/%.17g", t, tostring(e.kept[n - 1]), tostring(e.kept[n]), 100 * H.reads(P, n - 1), 100 * H.reads(P, n),
				100 * Oracle.share(P, n - 1, hider), 100 * Oracle.share(P, n, hider), P[n - 1].volume, P[n].volume))
		end
		print(fmt("spin %d copy in %s", spin, slot))
		for _, r in ipairs(row) do print("   " .. r) end
	end
end
