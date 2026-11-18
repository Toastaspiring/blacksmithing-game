--!nocheck
-- m3-plan-r2: T-DIF-04 on generated designs and T-DIF-05's material swap, through the emulator in the measure's rank
-- order, the build's verdict deciding. N Gen.validSword designs (TestRng 0x5EED0009); per design and per kind (Enclosed,
-- Duplicate, Dust) Gen.withFiller adds 1–4 parts: are they all cleaned, and are steps (g, m, d, tiers, every factor raw)
-- and edge (chains, points, bladeArea, mean thickness, grip point) bit-identical to the design without them? Then every
-- part's material swapped Iron ↔ Steel: steps and edge bit-identical but for the governing material?
--   lune run <abs>/proto/filler.luau -- <N>
local L = require("./lib")
local process = require("@lune/process")
local Gen = require("../repo/tests/lib/Gen")
local TestRng = require("../repo/tests/lib/TestRng")
local Limits = require("../repo/src/shared/Definitions/Limits")
local EquipmentTypes = require("../repo/src/shared/Definitions/EquipmentTypes")
local Materials = require("../repo/src/shared/Definitions/Materials")
local Versions = require("../repo/src/shared/Definitions/Versions")
local Balance = require("../repo/src/shared/Definitions/Balance")
local fmt = string.format

local N = tonumber(process.args[1]) or 40
local ctx = Gen.context(Limits, EquipmentTypes.get("Sword"), Materials.enabled, Versions.BLUEPRINT_SCHEMA, Balance.Geometry)
local function key(R)
	local t = {}
	for _, s in ipairs(R.steps) do
		table.insert(t, fmt("%s %.17g %.17g %.17g %s %s", s.step, s.g, s.m, s.d, s.tier, s.tierRaw))
		for _, f in ipairs(s.factors) do
			table.insert(t, fmt("%.17g", f.raw))
		end
	end
	local e = R.edge
	table.insert(t, fmt("%.17g %d %.17g %.17g %.17g %.17g %.17g", e.length, #e.chains, e.bladeArea, e.bladeMeanThickness,
		e.gripPoint[1], e.gripPoint[2], e.gripPoint[3]))
	for _, c in ipairs(e.chains) do
		for _, p in ipairs(c.points) do
			table.insert(t, fmt("%.17g,%.17g", p[1], p[2]))
		end
	end
	return table.concat(t, "\n")
end
local function run(core)
	return L.run(L.inRankOrder({ name = core.name, parts = core.parts }))
end
local rng = TestRng.new(0x5EED0009)
local stats = {}
for _, kind in ipairs({ "Enclosed", "Duplicate", "Dust" }) do
	stats[kind] = { tried = 0, same = 0, notCleaned = 0, diff = {} }
end
local swapSame, swapTried = 0, 0
for i = 1, N do
	local core = Gen.validSword(rng, ctx)
	local base = run(core)
	local kb = key(base)
	for _, kind in ipairs({ "Enclosed", "Duplicate", "Dust" }) do
		local filled, added = Gen.withFiller(rng, ctx, core, kind)
		if #added > 0 then
			local st = stats[kind]
			st.tried += 1
			local R = run(filled)
			local cleaned = {}
			for _, c in ipairs(R.cleaned) do
				cleaned[c.partId] = true
			end
			for _, id in ipairs(added) do
				if not cleaned[id] then
					st.notCleaned += 1
				end
			end
			if R.steps and key(R) == kb then
				st.same += 1
			elseif #st.diff < 4 then
				table.insert(st.diff, "#" .. i)
			end
		end
	end
	local swapped = Gen.copy(core)
	for _, p in ipairs(swapped.parts) do
		p.material = if p.material == "Iron" then "Steel" else "Iron"
	end
	local S = run(swapped)
	swapTried += 1
	if key(S) == kb then
		swapSame += 1
	end
end
for _, kind in ipairs({ "Enclosed", "Duplicate", "Dust" }) do
	local st = stats[kind]
	print(fmt("%-9s %d designs with filler: bit-identical %d, filler parts kept %d%s", kind, st.tried, st.same, st.notCleaned,
		if #st.diff > 0 then " (differ: " .. table.concat(st.diff, " ") .. ")" else ""))
end
print(fmt("Iron <-> Steel on every part: %d of %d designs bit-identical (steps but the material, and edge)", swapSame, swapTried))
