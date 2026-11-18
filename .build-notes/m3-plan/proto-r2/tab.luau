--!nocheck
-- m3-plan-r2: §5.5's table (and E-S2.5/2.7/2.8/2.9's fixtures) through the M3 emulator on the snapshot, in the fixture's
-- part order and in the measure's rank order. Run from the repo copy's root:
--   lune run <abs>/proto/tab.luau -- [ids...]        (no ids: every fixture)
-- Columns: d Sm / Ha / Sh in part order, tiers, then in rank order, EdgeLength and cutIndex (part order; '=' when rank
-- order agrees to the bit), cleaned (ids), and which numbers move with the order. With "dump" as the first argument it
-- prints every factor raw at %.17g instead, both orders, for bit comparisons.
local L = require("./lib")
local process = require("@lune/process")
local fmt = string.format

local args = process.args
local dump = args[1] == "dump"
local want = {}
local any = false
for i = if dump then 2 else 1, #args do
	want[args[i]] = true
	any = true
end

local function edgeSame(a, b)
	if a.edge.length ~= b.edge.length or #a.edge.chains ~= #b.edge.chains then
		return false
	end
	if a.edge.bladeArea ~= b.edge.bladeArea or a.edge.bladeMeanThickness ~= b.edge.bladeMeanThickness then
		return false
	end
	for k = 1, 3 do
		if a.edge.gripPoint[k] ~= b.edge.gripPoint[k] then
			return false
		end
	end
	return true
end

local function moved(a, b)
	local m = {}
	for si, s in ipairs(a.steps or {}) do
		local t = b.steps[si]
		for fi, f in ipairs(s.factors) do
			local g = t.factors[fi]
			if f.raw ~= g.raw then
				local d = math.abs(f.raw - g.raw)
				local key = string.sub(s.step, 1, 2) .. "." .. f.factor
				table.insert(m, fmt("%s %.2g", key, d))
			end
		end
	end
	return m
end

for _, f in ipairs(L.fixtures()) do
	if not any or want[f.id] then
		local A = L.run(f.b)
		local B = L.run(L.inRankOrder(f.b))
		if dump then
			print(fmt("%s part %s", f.id, L.factorDump(A)))
			print(fmt("%s rank %s", f.id, L.factorDump(B)))
		elseif not A.steps then
			print(fmt("%-10s invalid %s", f.id, L.cleanedLine(A)))
		else
			local da, ta = L.dline(A)
			local db, tb = L.dline(B)
			local m = moved(A, B)
			print(fmt("%-10s %s  %-12s| %s  %-12s| EL %.4f cut %.2f %s chains %d %s | %s", f.id, da, ta, if db == da then "=" else db,
				if tb == ta then "" else tb, A.edge.length, A.edge.cutIndex, if edgeSame(A, B) then "=" else "MOVED", #A.edge.chains,
				L.cleanedLine(A), if #m == 0 then "factors bit-identical" else table.concat(m, ", ")))
		end
	end
end
