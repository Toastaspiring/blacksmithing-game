--!nocheck
-- m2x-fix-3: the unit counts the SPEC and E-S2.12 quote, on the base and the build, the cap lifted: P1, P4, C09, F3, the
-- worst designs (valid and past the cap), A28, V1's regular sword of 24 rods (h_bundle.json) and its honest variants past
-- the cap (pastcap_32…34.json); the mirror images across X and Z (canonical) and every Block described another way (X and Y
-- sizes swapped, a quarter turn about its Z), as fix/mirror_units.luau and V1's c_redescribe.luau
--   lune run units2 -- <base | now> [mirror]
local Lab = require("./lab")
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local fmt = string.format
local T = Lab.tree(process.args[1] or "now")
local H = (require :: any)(T.root .. "/tests/Physics/PhysicsHelpers")
local Worst = (require :: any)(T.root .. "/docs/spec/prototypes/S2/cover/worst_designs")
local Adv = (require :: any)(T.root .. "/tests/fixtures/Adversarial")
local function units(parts)
	return T.units(T.prep(T.renumber(T.copyParts(parts))))
end
local function canonical(parts)
	local r = T.Canonical.draft({ schema = 1, name = "m", type = "Sword", parts = T.renumber(T.copyParts(parts)) })
	assert(r.ok, tostring(r.code))
	return r.value.parts
end
local function json(name)
	return serde.decode("json", fs.readFile(Lab.SCR .. "/m2x-v1-2/out/" .. name))
end

local designs = { { "P1", H.p1().parts }, { "C09", H.ornate().parts }, { "F3", T.Blueprints.core("F3").parts },
	{ "F5", T.Blueprints.core("F5").parts } }
for _, b in ipairs(T.Fx.perf()) do
	if b.parts then
		table.insert(designs, { string.sub(b.name, 1, 2), b.parts })
	end
end
for _, v in ipairs(Adv.variants) do
	if v.key == "A28" or string.find(tostring(v.key), "A28", 1, true) then
		local r = T.Canonical.draft(v.draft())
		if r.ok then
			table.insert(designs, { "A28", r.value.parts })
		end
	end
end
table.insert(designs, { "h_bundle (24 rods 0.12)", json("h_bundle.json") })
for _, k in ipairs({ 32, 33, 34 }) do
	table.insert(designs, { "pastcap_" .. k, json("pastcap_" .. k .. ".json") })
end
for k, d in ipairs(Worst.valid) do
	table.insert(designs, { "valid " .. k .. " " .. d.name, d.parts })
end
for k, d in ipairs(Worst.tooComplex) do
	table.insert(designs, { "tooComplex " .. k .. " " .. d.name, d.parts })
end
for _, d in ipairs(designs) do
	print(fmt("%-60s %16.3f", string.sub(d[1], 1, 60), units(d[2])))
end

if process.args[2] == "mirror" then
	print("mirror images (canonical), the cap lifted")
	local list = { { "P1", H.p1().parts }, { "C09", H.ornate().parts } }
	for _, b in ipairs(T.Fx.perf()) do
		if b.parts and string.sub(b.name, 1, 2) == "P4" then
			table.insert(list, { "P4", b.parts })
		end
	end
	for k, d in ipairs(Worst.valid) do
		table.insert(list, { "valid " .. k .. " " .. d.name, d.parts })
	end
	for _, d in ipairs(list) do
		local parts = canonical(d[2])
		local u0 = units(parts)
		local row = { fmt("%-40s %12.3f", string.sub(d[1], 1, 40), u0) }
		for _, plane in ipairs({ "X", "Z" }) do
			local img = {}
			for i, p in ipairs(parts) do
				img[i] = T.Mirror.reflect(p, plane)
			end
			img = canonical(img)
			local u = units(img)
			table.insert(row, fmt("%s %12.3f (%+.2f %%)%s", plane, u, 100 * (u - u0) / u0, if u > T.Geo.VERDICT_WORK_MAX then " PAST THE CAP" else ""))
		end
		print(table.concat(row, "  "))
	end
	print("every Block described another way, the cap lifted")
	local redesc = {}
	for k, d in ipairs(Worst.valid) do
		table.insert(redesc, { "valid " .. k .. " " .. d.name, d.parts })
	end
	for _, pre in ipairs({ "P1", "P3", "C09", "C05" }) do
		local parts, name = T.fixture(pre)
		table.insert(redesc, { name, parts })
	end
	for _, id in ipairs({ "F1", "F5" }) do
		table.insert(redesc, { id, T.repoFixture(id) })
	end
	for _, d in ipairs(redesc) do
		local a = T.renumber(T.copyParts(d[2]))
		local b = T.copyParts(a)
		for _, p in ipairs(b) do
			if p.shape == "Block" then
				local q = T.Quat.hemisphere(T.Quat.normalize(T.Quat.mul(p.rot, T.Z90)))
				p.rot = { q[1], q[2], q[3], q[4] }
				p.size = { p.size[2], p.size[1], p.size[3] }
			end
		end
		local ua, ub = units(a), units(b)
		print(fmt("%-44s %12.3f -> %12.3f (%+.2f %%)", string.sub(d[1], 1, 44), ua, ub, 100 * (ub / ua - 1)))
	end
end
