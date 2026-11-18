--!nocheck
-- V1 (m2x, round 3): the build against the build before the verdict took the slot's name ahead of where a part stands (m2x-fix-1/base, round 1's tree), bit for bit, on the
-- fixtures, the attack designs and every k-th plausible design: where the kept rows agree, the measure (exposedKept, contact,
-- hSurf, surfSamples, subSampled) and Analyze.run's physics (mass, volume, COM, owned volumes, ...) and budget must be the same
-- bits. lune run bc_check -- <every>
local process = require("@lune/process")
local fmt = string.format
local SCR = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad"
local function req(p)
	return (require :: any)(p)
end
local every = tonumber(process.args[1]) or 20
local A = { Shapes = req("./repo/src/shared/Physics/Shapes"), Sampling = req("./repo/src/shared/Physics/Sampling"),
	Analyze = req("./repo/src/shared/Physics/Analyze") }
local B = { Shapes = req(SCR .. "/m2x-fix-1/base/src/shared/Physics/Shapes"), Sampling = req(SCR .. "/m2x-fix-1/base/src/shared/Physics/Sampling"),
	Analyze = req(SCR .. "/m2x-fix-1/base/src/shared/Physics/Analyze") }
local function clean(parts)
	local o = {}
	for i, p in ipairs(parts) do
		o[i] = { id = i, shape = p.shape, slot = p.slot or "Blade", material = p.material or "Iron",
			pos = { p.pos[1], p.pos[2], p.pos[3] }, rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] },
			size = { p.size[1], p.size[2], p.size[3] } }
	end
	return o
end
local designs = {}
local Fx = req("./repo/docs/spec/prototypes/S2/v2/fixtures")
for _, list in ipairs({ Fx.calibration(), Fx.golden(), Fx.perf(), Fx.regression() }) do
	for _, b in ipairs(list) do
		local bb = b.parts and b or b.fixture
		if bb and bb.parts then
			table.insert(designs, { bb.name, clean(bb.parts) })
		end
	end
end
for _, d in ipairs(req("./repo/tests/Physics/CoverAttacks")) do
	table.insert(designs, { d.name, clean(d.parts) })
end
local all = req("./repo/tests/Physics/PlausibleDesigns").all()
for k = 1, #all, every do
	table.insert(designs, { all[k].name, clean(all[k].parts) })
end

local function bits(x)
	return fmt("%.17g", x)
end
local function flat(v, out)
	if type(v) == "table" then
		for i = 1, #v do
			flat(v[i], out)
		end
	elseif type(v) == "number" then
		table.insert(out, bits(v))
	else
		table.insert(out, tostring(v))
	end
	return out
end
local agree, moved, diffs = 0, 0, 0
for _, d in ipairs(designs) do
	local PA, PB = {}, {}
	for i, p in ipairs(d[2]) do
		PA[i] = A.Shapes.prepare(p, i)
		PB[i] = B.Shapes.prepare(p, i)
	end
	local ea, eb = A.Sampling.exposure(PA), B.Sampling.exposure(PB)
	local same = ea.capped == eb.capped
	for i = 1, #d[2] do
		same = same and ea.kept[i] == eb.kept[i]
	end
	if not same then
		moved += 1
	elseif not ea.capped then
		agree += 1
		local ka = table.concat(flat({ ea.exposedKept, ea.contact, ea.hSurf, ea.surfSamples, ea.subSampled }, {}), ",")
		local kb = table.concat(flat({ eb.exposedKept, eb.contact, eb.hSurf, eb.surfSamples, eb.subSampled }, {}), ",")
		local core = { schema = 1, name = "x", type = "Sword", parts = d[2] }
		local ra = A.Analyze.run(core, { measureInvalid = true })
		local rb = B.Analyze.run(core, { measureInvalid = true })
		local pa, pb = ra.physics, rb.physics
		local qa = if pa then table.concat(flat({ pa.mass, pa.volume, pa.com, pa.gripPoint, pa.gripAxis, pa.guardPos, pa.balance,
			pa.reach, pa.bladeLength, pa.totalLength, pa.comOffAxis, pa.ownedVolume, ra.budget.hVol, ra.budget.volSamples }, {}), ",") else "nil"
		local qb = if pb then table.concat(flat({ pb.mass, pb.volume, pb.com, pb.gripPoint, pb.gripAxis, pb.guardPos, pb.balance,
			pb.reach, pb.bladeLength, pb.totalLength, pb.comOffAxis, pb.ownedVolume, rb.budget.hVol, rb.budget.volSamples }, {}), ",") else "nil"
		if ka ~= kb or qa ~= qb then
			diffs += 1
			print(fmt("DIFF %s (measure %s, physics %s)", d[1], tostring(ka ~= kb), tostring(qa ~= qb)))
		end
	end
end
print(fmt("%d designs: verdicts agree on %d (measure or physics differing on %d), verdicts moved on %d", #designs, agree, diffs,
	moved))
