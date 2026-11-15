--!nocheck
-- fix-2: what the spread (fixC) moves. Per design, each tree's verdict (kept row, capped, units, from its SamplingV, the
-- verdict alone), and the truth (VisibleOracle, c1's) of every part whose verdict differs from the first tree's; on cages
-- also the Ball's truth wherever the first tree keeps it.
--   lune run fxc -- <set> <shard> <nshards> <out> <tree> [<tree> ...]
-- set: plausible | families:<every> | cages:<seed>:<count> | fixtures | corpus; tree: a folder of m2x-fix-2 (pre, c1, c0)
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local SCR = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad"
local W = SCR .. "/m2x-fix-2"
local fmt = string.format
local args = process.args
local set, shard, nshards, out = args[1], tonumber(args[2]), tonumber(args[3]), args[4]
local function req(p)
	return (require :: any)(p)
end
local trees = {}
for i = 5, #args do
	table.insert(trees, { name = args[i], SV = req(W .. "/" .. args[i] .. "/src/shared/Physics/SamplingV") })
end
local Shapes = req(W .. "/c1/src/shared/Physics/Shapes")
local Oracle = req(W .. "/c1/tests/Physics/VisibleOracle")
local Quat = req(W .. "/c1/src/shared/Blueprint/Quat")
local TestRng = req(W .. "/c1/tests/lib/TestRng")

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
local cages = false
local kind, a1, a2 = string.match(set, "^([^:]+):?([^:]*):?([^:]*)$")
if kind == "plausible" then
	for _, d in ipairs(req(W .. "/c1/tests/Physics/PlausibleDesigns").all()) do
		table.insert(designs, { name = d.name, parts = clean(d.parts) })
	end
elseif kind == "families" then
	local every = tonumber(a1) or 1
	local Sets = req(SCR .. "/m2x-protoB/b_sets")
	for _, fam in ipairs(Sets.families()) do
		local list = Sets.get(fam)
		for j = 1, #list, every do
			table.insert(designs, { name = "b_" .. fam .. " " .. (list[j].name or tostring(j)), parts = clean(list[j].parts) })
		end
	end
elseif kind == "cages" then
	-- V1's family (m2x-v1-2/b_cages.luau, cagelib.luau): a Ball r in 6 walls g off and 12 edge blocks past ±b, half turned
	cages = true
	local rng = TestRng.new(tonumber(a1) or 1)
	local I = { 0, 0, 0, 1 }
	for t = 1, tonumber(a2) or 300 do
		local r = rng:pick({ 0.05, 0.08, 0.1, 0.15, 0.2, 0.25 })
		local g = rng:range(-0.006, 0.02)
		local b = r * rng:range(0.1, 0.6)
		local c, wallT, wallS = { 0, 2.5, 0 }, 0.02, 2 * r + 0.1
		local parts = { { shape = "Ball", slot = "Pommel", pos = c, rot = I, size = { 2 * r, 2 * r, 2 * r } } }
		for ax = 1, 3 do
			for _, s in ipairs({ -1, 1 }) do
				local pos = { c[1], c[2], c[3] }
				pos[ax] += s * (r + g + wallT / 2)
				local size = { wallS, wallS, wallS }
				size[ax] = wallT
				table.insert(parts, { shape = "Block", slot = "Blade", pos = pos, rot = I, size = size })
			end
		end
		local E = r + 0.06
		for ax = 1, 3 do
			for bb = ax + 1, 3 do
				for _, sa in ipairs({ -1, 1 }) do
					for _, sb in ipairs({ -1, 1 }) do
						local lo, hi = { -E, -E, -E }, { E, E, E }
						if sa > 0 then lo[ax] = b else hi[ax] = -b end
						if sb > 0 then lo[bb] = b else hi[bb] = -b end
						local pos, size = {}, {}
						for k = 1, 3 do
							pos[k] = c[k] + (lo[k] + hi[k]) / 2
							size[k] = hi[k] - lo[k]
						end
						table.insert(parts, { shape = "Block", slot = "Guard", pos = pos, rot = I, size = size })
					end
				end
			end
		end
		if rng:float() < 0.5 then
			local q = Quat.hemisphere(Quat.normalize({ rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1) }))
			for k = 2, #parts do
				local p = parts[k]
				local w = Quat.rotate(q, { p.pos[1], p.pos[2] - 2.5, p.pos[3] })
				p.pos = { w[1], w[2] + 2.5, w[3] }
				local nr = Quat.hemisphere(Quat.normalize(Quat.mul(q, p.rot)))
				p.rot = { nr[1], nr[2], nr[3], nr[4] }
			end
		end
		table.insert(designs, { name = fmt("cage %d r %.2f g %.5f b %.4f", t, r, g, b), parts = clean(parts) })
	end
elseif kind == "corpus" then
	for line in string.gmatch(fs.readFile(SCR .. "/m2x-protoA/out/corpus_all.jsonl"), "[^\n]+") do
		local d = serde.decode("json", line)
		table.insert(designs, { name = d.name, parts = clean(d.parts) })
	end
elseif kind == "fixtures" then
	local Fx = req(W .. "/c1/docs/spec/prototypes/S2/v2/fixtures")
	local B = req(W .. "/c1/tests/fixtures/Blueprints")
	local Attacks = req(W .. "/c1/tests/Physics/CoverAttacks")
	local Worst = req(W .. "/c1/docs/spec/prototypes/S2/cover/worst_designs")
	local function add(name, parts)
		table.insert(designs, { name = name, parts = clean(parts) })
	end
	for _, b in ipairs(Fx.calibration()) do add("proto " .. b.name, b.parts) end
	for _, b in ipairs(Fx.golden()) do add("proto " .. b.name, b.parts) end
	for _, a in ipairs(Fx.adversarial()) do add("proto " .. a.fixture.name, a.fixture.parts) end
	for _, x in ipairs(Fx.regression()) do add("proto " .. x.fixture.name, x.fixture.parts) end
	for _, b in ipairs(Fx.perf()) do add("proto " .. b.name, b.parts) end
	for _, id in ipairs({ "F1", "F2", "F3", "F4", "F5" }) do add("repo " .. id, B.core(id).parts) end
	for _, d in ipairs(Attacks) do add("attack " .. d.name, d.parts) end
	for _, d in ipairs(Worst.valid) do add("worst valid " .. d.name, d.parts) end
end

local lines = {}
local t0 = os.clock()
for idx, d in ipairs(designs) do
	if (idx - 1) % nshards == shard then
		local P = table.create(#d.parts)
		for i, p in ipairs(d.parts) do
			P[i] = Shapes.prepare(p, i)
		end
		local rows, row = {}, { tostring(idx), d.name, tostring(#P) }
		for k, T in ipairs(trees) do
			local e = T.SV.exposure(P)
			local s = table.create(#P)
			for i = 1, #P do
				s[i] = if e.kept[i] then "1" else "0"
			end
			rows[k] = e
			table.insert(row, table.concat(s) .. (if e.capped then "/CAP" else ""))
			table.insert(row, fmt("%.17g", e.verdictWork))
		end
		local flips = {}
		local hider
		for i = 1, #P do
			local differs = false
			for k = 2, #trees do
				differs = differs or (rows[k].kept[i] ~= rows[1].kept[i] and not rows[k].capped and not rows[1].capped)
			end
			if differs or (cages and i == 1 and rows[1].kept[1]) then
				if hider == nil then
					_, _, hider = Oracle.flags(P)
				end
				local v = {}
				for k = 1, #trees do
					v[k] = if rows[k].kept[i] then "1" else "0"
				end
				table.insert(flips, fmt("%d:%s:%.6f:%s", i, P[i].shape, Oracle.share(P, i, hider), table.concat(v)))
			end
		end
		table.insert(row, table.concat(flips, ","))
		table.insert(lines, table.concat(row, "\t"))
	end
end
fs.writeFile(out, table.concat(lines, "\n") .. "\n")
print(fmt("%s shard %d/%d: %d designs, %.1f s", set, shard, nshards, #lines, os.clock() - t0))
