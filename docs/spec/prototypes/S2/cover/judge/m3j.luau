--!nocheck
-- M3 for the judge's attack designs: D through the emulator of M3's factors (docs/spec/prototypes/S2/verdict/
-- analyze_build.luau, protoB's copy, whose BSampling is protoB's force/Sampling: FORCE.kept replaces the verdict, so the
-- kept row is whatever is passed; the measure is the build's, unchanged by either prototype).
--   rows(parts)            today's, A's (base, canon, fine), B's kept rows and the truth's (share ≥ 2 %), with shares
--   D(parts, row)          the emulator's steps {step, d, tier}
--   compare(parts, r1, r2) worst |dD| and whether a tier flips
local L = require("./jlib")
local Emu = require("../m2x-protoB/proto/analyze_build")
local Force = require("../m2x-protoB/force/Sampling")
local Analyze = require("./repo/src/shared/Physics/Analyze")
local fmt = string.format

local M = {}

function M.valid(parts)
	local core = { schema = 1, name = "attack", type = "Sword", parts = parts }
	local ok, r = pcall(Analyze.quick, core, { connectivity = true })
	if not ok then return false, tostring(r) end
	if not r.ok then
		local codes = {}
		for _, e in ipairs(r.errors or {}) do table.insert(codes, tostring(e.code or e.rule or e.id or "?")) end
		return false, table.concat(codes, ",")
	end
	return true, ""
end

function M.D(parts, row)
	Force.FORCE.kept = row
	local ok, R = pcall(Emu.run, { name = "x", parts = parts }, { measureInvalid = true, build = true })
	Force.FORCE.kept = nil
	if not ok then return nil, tostring(R) end
	return R
end

function M.compare(parts, r1, r2)
	local A, B = M.D(parts, r1), M.D(parts, r2)
	if not (A and B and A.steps and B.steps) then return nil end
	local dd, tier, line = 0, false, {}
	for k, s in ipairs(A.steps) do
		local o = B.steps[k]
		dd = math.max(dd, math.abs(s.d - o.d))
		tier = tier or s.tier ~= o.tier
		table.insert(line, fmt("%s %.4f/%.4f %s/%s", string.sub(s.step, 1, 2), s.d, o.d, string.sub(s.tier, 1, 1), string.sub(o.tier, 1, 1)))
	end
	return dd, tier, table.concat(line, ", ")
end

-- K alone (the design without part f) against K + F (with it), each on its own truth row
function M.fillerEffect(parts, f, truthRow)
	local without, rowW = {}, {}
	for i, p in ipairs(parts) do
		if i ~= f then
			table.insert(without, p)
			table.insert(rowW, truthRow[i])
		end
	end
	local A, B = M.D(without, rowW), M.D(parts, truthRow)
	if not (A and B and A.steps and B.steps) then return nil end
	local dd, tier, line = 0, false, {}
	for k, s in ipairs(A.steps) do
		local o = B.steps[k]
		dd = math.max(dd, math.abs(s.d - o.d))
		tier = tier or s.tier ~= o.tier
		table.insert(line, fmt("%s %.4f/%.4f %s/%s", string.sub(s.step, 1, 2), s.d, o.d, string.sub(s.tier, 1, 1), string.sub(o.tier, 1, 1)))
	end
	return dd, tier, table.concat(line, ", ")
end

-- every reading's row and share; truth by VisibleOracle
function M.rows(parts)
	local P = L.prep(parts)
	local flags = { L.flags(P) }
	local N = #P
	local out = { shares = {} }
	local function rowOf(read)
		local row = table.create(N, false)
		for i = 1, N do
			row[i] = read[i] ~= nil and read[i].shown >= 0.02 * read[i].area
		end
		return row
	end
	local A0 = L.readA(P, nil, flags)
	local Ac = L.readA(P, { canon = true }, flags)
	local Af = L.readA(P, { canon = true, sag = 0.002 }, flags)
	local B0 = L.readB(P, 32, 4, false, flags)
	out.A, out.Acanon, out.Afine, out.B = rowOf(A0), rowOf(Ac), rowOf(Af), rowOf(B0)
	local today = L.Sampling.exposure(P).kept
	out.today = today
	local truth = L.truthAll(P)
	out.truth = table.create(N, false)
	for i = 1, N do
		out.truth[i] = truth[i] ~= false and truth[i] >= 0.02
		out.shares[i] = { truth = truth[i], A = A0[i] and A0[i].shown / A0[i].area, Acanon = Ac[i] and Ac[i].shown / Ac[i].area,
			Afine = Af[i] and Af[i].shown / Af[i].area, B = B0[i] and B0[i].shown / B0[i].area }
	end
	return out
end

return M
