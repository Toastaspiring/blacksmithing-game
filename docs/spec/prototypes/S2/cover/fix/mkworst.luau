--!nocheck
-- worst_designs.luau under the build (the rank with the slot first): `valid`, every candidate (cands.json) valid under the
-- cap, and V1's 24-Ball cluster at a spacing just under it, slowest first by the verdict's median Lune ms (RUNS rounds,
-- every design once a round); `tooComplex`, the candidates past the cap, units with the cap lifted. args: cands.json out runs
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")
local L = require("./lab")
local V = require("./SamplingV")
local fmt = string.format
local IN, OUT, RUNS = process.args[1], process.args[2], tonumber(process.args[3]) or 15
local Free = L.H.plantedSampling({ VERDICT_WORK_MAX = math.huge })
local SLOTS = { "Pommel", "Pommel", "Grip", "Grip", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade" }
local function cluster(d, dy, ax, y0)
	local parts = {}
	for i = 1, 24 do
		table.insert(parts, { id = i, slot = SLOTS[i], shape = "Ball", material = "Iron", pos = { ax * math.sin(i * 1.3), y0 + (i - 1) * dy, 0 }, rot = { 0, 0, 0, 1 }, size = { d, d, d } })
	end
	return parts
end
local function canonical(parts)
	local r = L.Canonical.draft({ schema = 1, name = "worst", type = "Sword", parts = parts })
	assert(r.ok, tostring(r.code))
	return r.value.parts
end
local function num(x)
	if x == math.floor(x) and math.abs(x) < 1e15 then return string.format("%d", x) end
	for p = 15, 17 do
		local s = string.format("%." .. p .. "g", x)
		if tonumber(s) == x then return s end
	end
	return string.format("%.17g", x)
end
local function lit(p)
	return fmt("{ id = %d, slot = %q, shape = %q, material = %q, pos = { %s, %s, %s }, rot = { %s, %s, %s, %s }, size = { %s, %s, %s } }",
		p.id, p.slot, p.shape, p.material, num(p.pos[1]), num(p.pos[2]), num(p.pos[3]), num(p.rot[1]), num(p.rot[2]), num(p.rot[3]),
		num(p.rot[4]), num(p.size[1]), num(p.size[2]), num(p.size[3]))
end
local valid, over = {}, {}
for _, c in ipairs(serde.decode("json", fs.readFile(IN))) do
	local parts = canonical(luau.load("return { " .. c.lua .. " }")())
	local units = Free.exposure(L.prepared(parts)).verdictWork
	assert(units == c.units)
	if units <= L.Geo.VERDICT_WORK_MAX and c.valid then
		table.insert(valid, { name = c.name, units = units, parts = parts })
	elseif units > L.Geo.VERDICT_WORK_MAX and string.find(c.codes, "TooComplex") and not string.find(c.name, "tclimb") and not string.find(c.name, "V1 climb") then
		table.insert(over, { name = c.name, units = units, parts = parts })
	end
end
do
	local parts = canonical(cluster(0.54, 0.06, 0.25, 0.3))
	local units = Free.exposure(L.prepared(parts)).verdictWork
	local ok = L.Analyze.run({ schema = 1, name = "worst", type = "Sword", parts = parts }).validation.ok
	assert(ok and units <= L.Geo.VERDICT_WORK_MAX, "the cluster: " .. units)
	table.insert(valid, { name = "V1 cluster: 24 Balls d 0.54, x 0.25·sin(1.3 i), y 0.3 + 0.06 (i − 1)", units = units, parts = parts })
end
local times = {}
for k, d in ipairs(valid) do
	d.P = L.prepared(d.parts)
	times[k] = {}
	V.exposure(d.P) -- warm
end
for r = 1, RUNS do
	for k, d in ipairs(valid) do
		local t0 = os.clock()
		local e = V.exposure(d.P)
		times[k][r] = (os.clock() - t0) * 1000
		assert(e.verdictWork == d.units and not e.capped)
	end
end
for k, d in ipairs(valid) do
	table.sort(times[k])
	d.ms = times[k][(RUNS + 1) // 2]
	d.best = times[k][1]
end
table.sort(valid, function(x, y) return x.ms > y.ms end)
local out = { "--!strict", "HEADER", "", "return {", "\tvalid = {" }
local function emit(list, withMs)
	for _, d in ipairs(list) do
		table.insert(out, "\t\t{")
		table.insert(out, fmt("\t\t\tname = %q,", d.name))
		table.insert(out, fmt("\t\t\tunits = %s,", num(d.units)))
		if withMs then table.insert(out, fmt("\t\t\tverdictMs = %.2f,", d.ms)) end
		table.insert(out, "\t\t\tparts = {")
		for _, p in ipairs(d.parts) do table.insert(out, "\t\t\t\t" .. lit(p) .. ",") end
		table.insert(out, "\t\t\t},")
		table.insert(out, "\t\t},")
	end
end
emit(valid, true)
table.insert(out, "\t},")
table.insert(out, "\ttooComplex = {")
emit(over, false)
table.insert(out, "\t},")
table.insert(out, "}")
fs.writeFile(OUT, table.concat(out, "\n") .. "\n")
for _, d in ipairs(valid) do print(fmt("valid       %-40s %10.3f units %7.2f ms (best %.2f, %.1f ns a unit)", string.sub(d.name, 1, 40), d.units, d.ms, d.best, 1e6 * d.ms / d.units)) end
for _, d in ipairs(over) do print(fmt("tooComplex  %-50s %12.3f units", string.sub(d.name, 1, 50), d.units)) end
