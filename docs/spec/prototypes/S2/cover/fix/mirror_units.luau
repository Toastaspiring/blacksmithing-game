--!nocheck
-- units of a design and of its mirror images across X and Z (canonical), the cap lifted; whether each image is valid
local L = require("./lab")
local fmt = string.format
local Free = L.H.plantedSampling({ VERDICT_WORK_MAX = math.huge })
local function canonical(parts)
	local r = L.Canonical.draft({ schema = 1, name = "m", type = "Sword", parts = parts })
	assert(r.ok, tostring(r.code))
	return r.value.parts
end
local function units(parts) return Free.exposure(L.prepared(parts)).verdictWork end
local function valid(parts) return L.Analyze.run({ schema = 1, name = "m", type = "Sword", parts = parts }).validation.ok end
local designs = { { "P1", L.H.p1().parts }, { "C09", L.H.ornate().parts } }
for _, b in ipairs(L.Fx.perf()) do if string.sub(b.name, 1, 2) == "P4" then table.insert(designs, { "P4", b.parts }) end end
for k, d in ipairs(L.Worst.valid) do table.insert(designs, { "worst valid " .. k .. " " .. string.sub(d.name, 1, 20), d.parts }) end
local worst = 0
for _, d in ipairs(designs) do
	local parts = canonical(d[2])
	local u0 = units(parts)
	local row = { fmt("%-36s %10.1f", d[1], u0) }
	for _, plane in ipairs({ "X", "Z" }) do
		local img = {}
		for i, p in ipairs(parts) do img[i] = L.Mirror.reflect(p, plane) end
		img = canonical(img)
		local u = units(img)
		worst = math.max(worst, math.abs(u - u0) / u0)
		table.insert(row, fmt("%s %10.1f (%+.1f %%)%s", plane, u, 100 * (u - u0) / u0, if u > L.Geo.VERDICT_WORK_MAX then " PAST THE CAP" elseif not valid(img) then " invalid" else ""))
	end
	print(table.concat(row, "   "))
end
print(fmt("largest difference %.1f %%", 100 * worst))
