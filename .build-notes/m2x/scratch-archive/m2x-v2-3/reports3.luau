--!nocheck
-- V2 round 3: the verdict's reports through spend, on the repo: the largest single report, the sum against verdictWork,
-- whether anything is reported after the report that passes VERDICT_WORK_MAX, how far past it the exposure stops, and the
-- units with the cap lifted (a planted Sampling). Sets: the F, C, X and P fixtures, the attack designs, worst_designs.luau,
-- A28, V1's saved designs (h_bundle, pastcap_32…34, h_report, cageflip_sword) and V1's caps under a Ball.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-v2-3"
local SCR = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad"
local R = W .. "/repo"
local Shapes = require(R .. "/src/shared/Physics/Shapes")
local Sampling = require(R .. "/src/shared/Physics/Sampling")
local Analyze = require(R .. "/src/shared/Physics/Analyze")
local Canonical = require(R .. "/src/shared/Blueprint/Canonical")
local H = require(R .. "/tests/Physics/PhysicsHelpers")
local Attacks = require(R .. "/tests/Physics/CoverAttacks")
local Adv = require(R .. "/tests/fixtures/Adversarial")
local Worst = require(R .. "/docs/spec/prototypes/S2/cover/worst_designs")
local Fx = require(W .. "/emuNow/proto/fixtures")
local fmt = string.format
local CAP = 700000
local Lifted = H.plantedSampling({ VERDICT_WORK_MAX = math.huge })

local designs = {}
local function add(name, parts)
	table.insert(designs, { name = name, parts = parts })
end
for _, set in ipairs({ Fx.calibration(), Fx.golden(), Fx.perf() }) do
	for _, b in ipairs(set) do
		add(b.name, b.parts)
	end
end
for _, x in ipairs(Fx.regression()) do
	add(x.fixture.name, x.fixture.parts)
end
for _, d in ipairs(Attacks) do
	add("attack " .. d.name, d.parts)
end
for _, d in ipairs(Worst.valid) do
	add("worst valid " .. d.name, d.parts)
end
for _, d in ipairs(Worst.tooComplex) do
	add("worst tooComplex " .. d.name, d.parts)
end
add("A28", Canonical.draft(Adv.variant("A28").draft()).value.parts)
for _, f in ipairs({ "h_bundle", "pastcap_32", "pastcap_33", "pastcap_34", "h_report", "cageflip_sword" }) do
	local path = SCR .. "/m2x-v1-2/out/" .. f .. ".json"
	if fs.isFile(path) then
		local d = serde.decode("json", fs.readFile(path))
		add("V1 " .. f, d.parts or d)
	end
end
-- V1's caps under a Ball: a Cylinder's cap 0.006 proud under a Ball r 0.04 (fix2/reports.luau's)
local I, Z90 = { 0, 0, 0, 1 }, { 0, 0, 0.70710678118654757, 0.70710678118654757 }
add("a cap 0.006 proud under a Ball r 0.04, alone", {
	{ id = 1, slot = "Blade", shape = "Block", material = "Iron", pos = { 0, 1, 0 }, rot = I, size = { 0.7, 0.6, 0.65 } },
	{ id = 2, slot = "Blade", shape = "Cylinder", material = "Iron", pos = { 0, 1.006, 0 }, rot = Z90, size = { 0.6, 0.4, 0.4 } },
	{ id = 3, slot = "Guard", shape = "Ball", material = "Iron", pos = { 0, 1.306, 0 }, rot = I, size = { 0.08, 0.08, 0.08 } },
})

local largest, largestWhat = 0, ""
local capped, maxPast, after = 0, -math.huge, 0
local rows = {}
for _, d in ipairs(designs) do
	local P = {}
	for i, p in ipairs(d.parts) do
		P[i] = Shapes.prepare(p, i)
	end
	local reports, sum, crossed, afterHere = {}, 0, false, 0
	local e = Sampling.exposure(P, function(n)
		if crossed then
			afterHere += 1
		end
		sum += n
		table.insert(reports, n)
		if sum > CAP and not crossed then
			crossed = true
		end
	end)
	local big = 0
	for _, n in ipairs(reports) do
		big = math.max(big, n)
	end
	if big > largest then
		largest, largestWhat = big, d.name
	end
	local line = fmt("%-70s units %12.3f reported %12.3f largest report %8.3f", string.sub(d.name, 1, 70), e.verdictWork, sum, big)
	if e.capped then
		capped += 1
		maxPast = math.max(maxPast, e.verdictWork - CAP)
		after += afterHere
		local lifted = Lifted.exposure(P)
		line ..= fmt(" CAPPED: %.3f past, %d reports after the crossing, %.0f uncapped", e.verdictWork - CAP, afterHere, lifted.verdictWork)
		if sum ~= e.verdictWork then
			line ..= " SUM≠verdictWork"
		end
	end
	table.insert(rows, line)
end
print(table.concat(rows, "\n"))
print(fmt("%d designs; the largest single report %.3f (%s); %d capped, at most %.3f past the cap, %d reports after the crossing", #designs, largest, largestWhat, capped, maxPast, after))
