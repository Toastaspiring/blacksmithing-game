--!nocheck
-- The designs where the near test's two clauses matter: which parts, and a reduced design that shows it, for a tried test.
local V = require("./v1")
local H = require("./tree/tests/Physics/PhysicsHelpers")
local TestRng = require("./tree/tests/lib/TestRng")
local Force = V.Force
local fmt = string.format
local rng = TestRng.new(123)
local wanted = { [902] = 4 }
local function readOf(M, P)
	M.FORCE.read, M.FORCE.fullRead = {}, true
	M.exposure(P)
	local r = M.FORCE.read
	M.FORCE.read, M.FORCE.fullRead = nil, nil
	return r
end
local mods = { m78 = require("./mdiff/m78") }
for d = 1, 2500 do
	local design = H.anyDesign(rng)
	local idx = wanted[d]
	if idx then
		local parts = V.renumber(design.parts)
		local p = parts[idx]
		print(fmt("design %d part %d %s size %.5f %.5f %.5f", d, idx, p.shape, p.size[1], p.size[2], p.size[3]))
		-- drop parts one at a time while the mutants still differ from the build on p
		local function differs(list, i)
			local P = V.prep(list)
			local b = readOf(Force, P)
			local any = {}
			for name, M in mods do
				local r = readOf(M, V.prep(list))
				if r[i] ~= b[i] then any[name] = r[i] end
			end
			return next(any) ~= nil, b[i], any
		end
		local list = V.copyParts(parts)
		local i = idx
		local changed = true
		while changed do
			changed = false
			for k = #list, 1, -1 do
				if k ~= i then
					local trial = V.copyParts(list)
					table.remove(trial, k)
					local j = if k < i then i - 1 else i
					V.renumber(trial)
					if differs(trial, j) then
						list, i = trial, j
						changed = true
						break
					end
				end
			end
		end
		local _, read, any = differs(list, i)
		print(fmt("  reduced to %d parts, part %d reads %.17g", #list, i, read))
		for name, v in any do print(fmt("    %s reads %.17g", name, v)) end
		for k, q in ipairs(list) do
			print(fmt("    H.part(%d, %q, %q, %q, { %.17g, %.17g, %.17g }, { %.17g, %.17g, %.17g, %.17g }, { %.17g, %.17g, %.17g }),", k, q.slot, q.shape, "Iron", q.pos[1], q.pos[2], q.pos[3], q.rot[1], q.rot[2], q.rot[3], q.rot[4], q.size[1], q.size[2], q.size[3]))
		end
	end
end
