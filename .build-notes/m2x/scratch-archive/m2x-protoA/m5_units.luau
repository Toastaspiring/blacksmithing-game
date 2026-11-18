--!nocheck
-- M5: the verdict's work units (Physics/Cover, TESTS_PER_UNIT tests each) on whole sets, no clock: the distribution, the largest
-- designs, and for the worst a single timing. Shows where a work cap would fall. args: set model out [shard nshards]
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local S = require("./sets")
local Shapes = require("./repo/src/shared/Physics/Shapes")
local fmt = string.format

local which, modelName, outPath = process.args[1], process.args[2] or "base", process.args[3]
local shard, nshards = tonumber(process.args[4] or "0"), tonumber(process.args[5] or "1")
local Sv = require(({ base = "./v/newV_base/Sampling", canon = "./v/newV_canon/Sampling", fine = "./v/newV_fine/Sampling", old = "./v/oldV/Sampling" })[modelName])

local designs = {}
local function add(list) for _, d in ipairs(list) do table.insert(designs, d) end end
if which == "fixtures" then add(S.repoF()); add(S.protoFixtures())
elseif which == "plausible" then
	local Plausible = require("./repo/tests/Physics/PlausibleDesigns")
	for _, d in ipairs(Plausible.all()) do table.insert(designs, { name = d.family .. " | " .. d.name, parts = S.clean(d.parts) }) end
elseif which == "fuzz" then
	local TestRng = require("./repo/tests/lib/TestRng")
	local Gen = require("./repo/tests/lib/Gen")
	local H = require("./repo/tests/Physics/PhysicsHelpers")
	local Limits = require("./repo/src/shared/Definitions/Limits")
	local EquipmentTypes = require("./repo/src/shared/Definitions/EquipmentTypes")
	local Materials = require("./repo/src/shared/Definitions/Materials")
	local Balance = require("./repo/src/shared/Definitions/Balance")
	local Versions = require("./repo/src/shared/Definitions/Versions")
	local ctx = Gen.context(Limits, EquipmentTypes.get("Sword"), Materials.enabled, Versions.BLUEPRINT_SCHEMA, Balance.Geometry)
	local rng = TestRng.new(0xC0FFEE)
	for k = 1, 1500 do
		local core = Gen.validSword(rng, ctx)
		if k % 2 == 0 then core = Gen.withFiller(rng, ctx, core, ({ "Enclosed", "Dust", "Duplicate" })[(k / 2) % 3 + 1]) end
		table.insert(designs, { name = "fuzz validSword " .. k, parts = S.clean(core.parts) })
	end
	for k = 1, 500 do table.insert(designs, { name = "fuzz anyDesign " .. k, parts = S.clean(H.anyDesign(rng).parts) }) end
elseif which == "attacks" then
	add(S.worstP()); add(S.climbed()); add(S.attacksJson())
	for _, f in ipairs(fs.readDir("corpus")) do
		if string.sub(f, -6) == ".jsonl" then add(S.jsonl("corpus/" .. f)) end
	end
elseif string.sub(which, 1, 5) == "json:" then
	add(S.json(string.sub(which, 6)))
end

local rows = {}
local t0 = os.clock()
for k, d in ipairs(designs) do
	if (k - 1) % nshards == shard and #d.parts > 0 and #d.parts <= 24 then
		local P = {}
		for i, p in ipairs(d.parts) do P[i] = Shapes.prepare(p, i) end
		local units = 0
		local t1 = os.clock()
		Sv.exposure(P, function(n) units += n end)
		table.insert(rows, { name = d.name, n = #P, units = units, ms = (os.clock() - t1) * 1000 })
	end
end
table.sort(rows, function(a, b) return a.units > b.units end)
local n = #rows
local function pct(p) return rows[math.max(1, math.ceil(n * (1 - p)))].units end
print(fmt("%s %s: %d designs, %.0f s; units max %.0f, p99.9 %.0f, p99 %.0f, p90 %.0f, median %.0f", which, modelName, n, os.clock() - t0, rows[1].units, pct(0.999), pct(0.99), pct(0.9), pct(0.5)))
for k = 1, math.min(8, n) do print(fmt("  %10.0f units %8.2f ms (one run, under load) %2d parts  %s", rows[k].units, rows[k].ms, rows[k].n, rows[k].name)) end
if outPath then
	local top = {}
	for k = 1, math.min(200, n) do top[k] = rows[k] end
	fs.writeFile(outPath, serde.encode("json", { count = n, max = rows[1].units, p999 = pct(0.999), p99 = pct(0.99), p90 = pct(0.9), median = pct(0.5), top = top }))
end
