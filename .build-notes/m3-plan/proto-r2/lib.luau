--!nocheck
-- m3-plan-r2: what the runners share. The M3 emulator (docs/spec/prototypes/S2/verdict/analyze_build.luau, copied here
-- beside S2/v2's modules) with build = true takes the kept row, exposedKept, contact rows and ownership from the
-- snapshot's Physics (../repo/src/shared/Physics) and runs the prototype's edge and factors on them, walking the parts in
-- the order it is handed. "part" order = the prototype fixture's own list order (what §5.5 and E-S2.9 were measured on);
-- "rank" order = the measure's rank, Sampling.measureRanked, exactly as tests/Physics/Reference.spec's inRankOrder builds it.
local Emu = require("./analyze_build")
local Fx = require("./fixtures")
local BShapes = require("../repo/src/shared/Physics/Shapes")
local BSampling = require("../repo/src/shared/Physics/Sampling")

local L = {}
L.Emu, L.Fx, L.BShapes, L.BSampling = Emu, Fx, BShapes, BSampling
local fmt = string.format

-- the parts in the measure's rank order (ids kept, as Reference.spec does)
function L.inRankOrder(b)
	local list = {}
	for i, part in ipairs(b.parts) do
		list[i] = BShapes.prepare(part, i)
	end
	local _, order = BSampling.measureRanked(list)
	local parts = {}
	for r, p in ipairs(order) do
		parts[r] = b.parts[p.index]
	end
	return { name = b.name, parts = parts }
end

-- the verdict's rank order (Sampling.ranked), for comparison only
function L.inVerdictOrder(b)
	local list = {}
	for i, part in ipairs(b.parts) do
		list[i] = BShapes.prepare(part, i)
	end
	local _, order = BSampling.ranked(list)
	local parts = {}
	for r, p in ipairs(order) do
		parts[r] = b.parts[p.index]
	end
	return { name = b.name, parts = parts }
end

-- a permutation of b's parts by a Fisher–Yates on a xorshift32 stream (ids kept)
function L.shuffled(b, seed)
	local s = seed
	local function nxt()
		s = bit32.bxor(s, bit32.lshift(s, 13))
		s = bit32.bxor(s, bit32.rshift(s, 17))
		s = bit32.bxor(s, bit32.lshift(s, 5))
		return s
	end
	local parts = table.clone(b.parts)
	for i = #parts, 2, -1 do
		local j = (nxt() % i) + 1
		parts[i], parts[j] = parts[j], parts[i]
	end
	return { name = b.name, parts = parts }
end

function L.run(b, extra)
	local o = { build = true, measureInvalid = true }
	for k, v in pairs(extra or {}) do
		o[k] = v
	end
	return Emu.run({ name = b.name, parts = b.parts }, o)
end

local ABBR = { Normal = "N", Hard = "H", Expert = "Ex", Master = "Ma", Hell = "He" }
L.ABBR = ABBR

-- "d1/d2/d3" and "N/H/H(Ex)"
function L.dline(R)
	local ds, ts = {}, {}
	for _, s in ipairs(R.steps or {}) do
		table.insert(ds, fmt("%.4f", s.d))
		local t = ABBR[s.tier] or s.tier
		if s.tierRaw ~= s.tier then
			t = t .. "(" .. (ABBR[s.tierRaw] or s.tierRaw) .. ")"
		end
		table.insert(ts, t)
	end
	return table.concat(ds, " / "), table.concat(ts, " ")
end

function L.cleanedLine(R)
	local t = {}
	local c = table.clone(R.cleaned or {})
	table.sort(c, function(a, b2)
		return a.partId < b2.partId
	end)
	for _, x in ipairs(c) do
		table.insert(t, (if x.reason == "Dust" then "D" else "E") .. x.partId)
	end
	return "[" .. table.concat(t, ",") .. "]"
end

-- every fixture §5.5, E-S2.5, E-S2.7 and E-S2.8 name, with a short id
function L.fixtures()
	local out = {}
	local function add(id, b, note)
		table.insert(out, { id = id, b = b, note = note })
	end
	local g = Fx.golden()
	for k = 1, 5 do
		add("F" .. k, g[k])
	end
	for _, b in ipairs(Fx.calibration()) do
		local id = string.match(b.name, "^(C%d+)")
		if id == "C02" and string.find(b.name, "Steel") then
			id = "C02s"
		end
		add(id, b)
	end
	for _, a in ipairs(Fx.adversarial()) do
		local id = string.match(a.fixture.name, "^(A%d+)")
		if a.base.name ~= "F1 ArmingSword" then
			add(id .. "base", a.base)
		end
		add(id, a.fixture)
	end
	local seen = {}
	for _, r in ipairs(Fx.regression()) do
		-- X01's and X02's union blades are both named "x": tell bases apart by table, not by name
		if r.base.name ~= "F5 StarterSword" and not seen[r.base] then
			seen[r.base] = true
			add(r.id .. "base", r.base)
		end
		add(r.id, r.fixture)
	end
	for _, b in ipairs(Fx.perf()) do
		add(string.match(b.name, "^(P%d)"), b)
	end
	return out
end

function L.find(id)
	for _, f in ipairs(L.fixtures()) do
		if f.id == id then
			return f.b
		end
	end
	error("no fixture " .. id)
end

-- factor raw values per step at full precision, for bit comparisons
function L.factorDump(R)
	local t = {}
	for _, s in ipairs(R.steps or {}) do
		local f = {}
		for _, v in ipairs(s.factors) do
			table.insert(f, fmt("%s=%.17g", v.factor, v.raw))
		end
		table.insert(t, s.step .. "{" .. table.concat(f, ",") .. "}")
	end
	return table.concat(t, " ")
end

return L
