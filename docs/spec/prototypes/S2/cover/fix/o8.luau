--!nocheck
local L = require("./lab")
local E = require("./emulab")
local fmt = string.format
local function axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return L.Quat.hemisphere(L.Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
end
local function clone(parts)
	local out = {}
	for i, p in ipairs(parts) do out[i] = table.clone(p) end
	return out
end
local F3 = L.Blueprints.core("F3").parts
local R0 = E.run(F3)
print("F3                      ", E.dline(R0))
local relabel = clone(F3)
relabel[6].slot = "Guard"
print("F3 blade as Guard       ", E.dline(E.run(relabel)))
for _, v in ipairs({ { "exact", { 0, 0, 0, 1 }, nil, 0 }, { "180 Y", { 0, 1, 0, 0 }, nil, 0 }, { "permuted", axisAngle(0, 1, 0, 90), { 0.035, 3.4, 0.07 }, 0 }, { "1e-12 lower", { 0, 0, 0, 1 }, nil, -1e-12 } }) do
	local parts = clone(F3)
	local c = table.clone(F3[6])
	c.slot, c.rot, c.size, c.pos = "Guard", v[2], v[3] or F3[6].size, { F3[6].pos[1], F3[6].pos[2] + v[4], F3[6].pos[3] }
	table.insert(parts, c)
	local R = E.run(parts)
	local d, t = E.diff(R0, R)
	print(fmt("F3 + blade %-12s Guard %s  |dD| %.4f flip %s", v[1], E.dline(R), d, tostring(t)))
end
-- a copy of its guard in the Blade
for i, p in ipairs(F3) do print(i, p.slot, p.shape, table.concat(p.size, ","), table.concat(p.pos, ",")) end
for i, p in ipairs(F3) do
	if p.slot == "Guard" then
		local parts = clone(F3)
		local c = table.clone(p)
		c.slot = "Blade"
		table.insert(parts, c)
		print(fmt("F3 + a copy of part %d (Guard) in the Blade: %s", i, E.dline(E.run(parts))))
		local rl = clone(F3)
		rl[i].slot = "Blade"
		print(fmt("F3, part %d relabelled Blade:            %s", i, E.dline(E.run(rl))))
	end
end
for _, b in ipairs(L.Fx.calibration()) do
	if string.sub(b.name, 1, 3) == "C08" then
		local R8 = E.run(b.parts)
		print("C08                     ", E.dline(R8))
		local rl = clone(b.parts)
		rl[4].slot = "Guard"
		print("C08 blade as Guard      ", E.dline(E.run(rl)))
		local parts = clone(b.parts)
		local c = table.clone(b.parts[4])
		c.slot, c.rot = "Guard", { 0, 1, 0, 0 }
		table.insert(parts, c)
		local R = E.run(parts)
		print("C08 + blade 180 Y Guard ", E.dline(R), E.diff(R8, R))
	end
end
