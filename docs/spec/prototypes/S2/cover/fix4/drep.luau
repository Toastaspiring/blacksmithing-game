--!nocheck
-- fix-4: one design on named trees: valid, per part from `first` the reading and verdict on each tree and the truth
-- (the last tree's VisibleOracle), D on each tree's own verdict and on the truth's row (the last tree's measure).
--   local Drep = require("./drep"); Drep.report(name, parts, first, { "base", "cap" }) -> { reads, kept, truth, D, Dt, flips }
local V = require("./vlab")
local fmt = string.format
local Drep = {}

function Drep.report(name, parts, first, names, quiet)
	local T = {}
	for i, n in ipairs(names) do
		T[i] = V.tree(n)
	end
	local N = T[#T]
	parts = N.copy(parts)
	local ok, codes = N.valid(parts)
	if not quiet then
		print(name .. ": valid " .. tostring(ok) .. (if codes ~= "" then " " .. codes else ""))
	end
	local Pn = N.prep(parts)
	local tn, row = N.truth(Pn)
	local out = { valid = ok, reads = {}, kept = {}, truth = tn, row = row, D = {}, flips = {}, dd = {} }
	for t, L in ipairs(T) do
		local r, k = L.reads(L.prep(parts))
		out.reads[t], out.kept[t] = r, k
	end
	if not quiet then
		for i = first, #parts do
			local cells = {}
			for t = 1, #T do
				table.insert(cells, fmt("%s %s %s", names[t], V.pct(out.reads[t][i]), if out.kept[t][i] then "K" else "E"))
			end
			print(fmt("  part %2d %-8s %s; truth %s %s", i, parts[i].shape, table.concat(cells, ", "), V.pct(tn[i]), if row[i] then "K" else "E"))
		end
	end
	if ok then
		out.Dt = N.emu(parts, row)
		for t, L in ipairs(T) do
			out.D[t] = L.emu(parts)
			local w, tier = V.dDiff(out.D[t], out.Dt)
			out.dd[t], out.flips[t] = w, tier
			if not quiet then
				print(fmt("  D %-6s %s  |dD| %.4f%s", names[t], V.dline(out.D[t]), w, if tier then " TIER" else ""))
			end
		end
		if not quiet then
			print("  D truth  " .. V.dline(out.Dt))
		end
	end
	return out
end

return Drep
