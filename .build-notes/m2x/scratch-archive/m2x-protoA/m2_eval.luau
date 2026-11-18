--!nocheck
-- M2: every reading against the truth (repo tests/Physics/VisibleOracle.luau, true shapes), part by part. Readings: the old one
-- (base/, the verdict as built before), the new one on 3 models (base = the fixed baseline, canon = round models in a world frame,
-- fine = canon + sagitta <= 0.002, Ball n <= 8, Cylinder N <= 128). The oracle's coarse lattice (4,000 points) for every part;
-- Oracle.share (fine lattice under 30 %) wherever any verdict could be wrong at the bands counted. One JSON row per part.
-- args: set shard nshards out   set = fixtures | plausible | attacks | fuzz | jsonl:<path>
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local S = require("./sets")
local L = require("./lib")
local OldV = require("./v/oldV/Sampling")
local Oracle = L.Oracle
local fmt = string.format

local which, shard, nshards, outPath = process.args[1], tonumber(process.args[2] or "0"), tonumber(process.args[3] or "1"), process.args[4]

local designs = {}
local function add(list) for _, d in ipairs(list) do table.insert(designs, d) end end
if which == "fixtures" then
	add(S.repoF()); add(S.protoFixtures())
elseif which == "plausible" then
	local Plausible = require("./repo/tests/Physics/PlausibleDesigns")
	for _, d in ipairs(Plausible.all()) do table.insert(designs, { name = d.family .. " | " .. d.name, parts = S.clean(d.parts) }) end
elseif which == "attacks" then
	add(S.worstP()); add(S.climbed()); add(S.attacksJson())
	for _, f in ipairs(fs.readDir("corpus")) do
		if string.sub(f, -6) == ".jsonl" then add(S.jsonl("corpus/" .. f)) end
	end
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
		local kinds = { "Enclosed", "Dust", "Duplicate" }
		if k % 2 == 0 then
			core = Gen.withFiller(rng, ctx, core, kinds[(k / 2) % 3 + 1])
		end
		table.insert(designs, { name = "fuzz validSword " .. k, parts = S.clean(core.parts) })
	end
	for k = 1, 500 do
		local core = H.anyDesign(rng)
		table.insert(designs, { name = "fuzz anyDesign " .. k, parts = S.clean(core.parts) })
	end
elseif string.sub(which, 1, 5) == "bset:" then
	-- the v1-1 verifier's own families (atk/v11/b_sets.luau, its harness pointed at this repo), every k-th design: bset:<family>:<k>
	local fam, k = string.match(which, "^bset:([%w]+):(%d+)$")
	local Sets = require("./atk/v11/b_sets")
	for j, d in ipairs(Sets.get(fam)) do
		if (j - 1) % tonumber(k) == 0 then table.insert(designs, { name = fam .. " | " .. d.name, parts = S.clean(d.parts) }) end
	end
elseif string.sub(which, 1, 6) == "jsonl:" then
	add(S.jsonl(string.sub(which, 7)))
end

local MODELS = {
	base = function(P) return L.Cover.model(P) end,
	canon = function(P) return L.Cover.model(P, { canon = true }) end,
	fine = function(P) return L.Cover.model(P, { canon = true, sag = 0.002 }) end,
}

local lines = {}
local t0 = os.clock()
local nd, np = 0, 0
for k, d in ipairs(designs) do
	if (k - 1) % nshards == shard and #d.parts > 0 and #d.parts <= 24 then
		nd += 1
		local P = L.prep(d.parts)
		local ok, err = pcall(function()
			local oldKept = OldV.exposure(P).kept
			local reads, kept = {}, {}
			for name, mf in pairs(MODELS) do
				reads[name], kept[name] = L.newShares(P, mf)
			end
			local isCopy, isDust, hider = Oracle.flags(P)
			for i = 1, #P do
				if hider[i] then
					np += 1
					local coarse = Oracle.measure(P, i, hider, Oracle.COARSE_POINTS)
					local anyClean = not oldKept[i] or not kept.base[i] or not kept.canon[i] or not kept.fine[i]
					local anyKeep = oldKept[i] or kept.base[i] or kept.canon[i] or kept.fine[i]
					local t, fine = coarse, false
					if (anyClean and coarse >= 0.01) or (anyKeep and coarse < 0.05) or math.abs(coarse - 0.02) < 0.01 then
						t, fine = Oracle.share(P, i, hider), true
					end
					table.insert(lines, serde.encode("json", {
						d = d.name, i = i, shape = d.parts[i].shape, label = d.parts[i].label, n = #P, t = t, tc = coarse, f = fine,
						rb = reads.base[i], rc = reads.canon[i], rf = reads.fine[i],
						vo = oldKept[i], vb = kept.base[i], vc = kept.canon[i], vf = kept.fine[i],
					}))
				end
			end
		end)
		if not ok then
			table.insert(lines, serde.encode("json", { d = d.name, error = tostring(err) }))
		end
	end
end
fs.writeFile(outPath, table.concat(lines, "\n") .. "\n")
print(fmt("m2 %s shard %d/%d: %d designs, %d parts, %.1f s", which, shard, nshards, nd, np, os.clock() - t0))
