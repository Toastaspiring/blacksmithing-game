--!nocheck
-- m2x-fix-3: the plausible designs named on the command line (substring): each part's reading on the trees, its truth, and
-- D through the emulator on each tree's verdict and on the truth's row
--   lune run moved -- <tree names comma-separated> <name substring> [...]
local Lab = require("./lab")
local process = require("@lune/process")
local fmt = string.format
local names = string.split(process.args[1], ",")
local trees = {}
for i, n in ipairs(names) do
	trees[i] = Lab.tree(if n == "base" or n == "now" then n else Lab.SCR .. "/m2x-fix-3/" .. n)
end
local N = trees[#trees]
local PD = (require :: any)(N.root .. "/tests/Physics/PlausibleDesigns")
local all = PD.all()
for a = 2, #process.args do
	local want = process.args[a]
	for _, d in ipairs(all) do
		if string.find(d.name, want, 1, true) then
			local parts = N.copyParts(d.parts)
			N.renumber(parts)
			local P = N.prep(parts)
			local reads = {}
			for t, T in ipairs(trees) do
				reads[t] = T.readAll(T.prep(parts))
			end
			local truth = N.truthAll(P)
			local kept = {}
			for t, T in ipairs(trees) do
				kept[t] = T.Sampling.exposure(T.prep(parts)).kept
			end
			print(d.name)
			for i = 1, #parts do
				local differ = false
				for t = 2, #trees do
					differ = differ or kept[t][i] ~= kept[1][i]
				end
				if differ then
					local row = {}
					for t = 1, #trees do
						table.insert(row, fmt("%s %s (%s)", names[t], N.pct(reads[t][i]), if kept[t][i] then "K" else "E"))
					end
					print(fmt("  part %d %s %s: %s; truth %s", i, parts[i].slot, parts[i].shape, table.concat(row, ", "), N.pct(truth[i])))
				end
			end
			local D = {}
			for t, T in ipairs(trees) do
				local ok, R = pcall(T.emu, T.copyParts(parts))
				D[t] = if ok then T.dline(R) else ("emu: " .. tostring(R))
				print(fmt("  D %s: %s", names[t], D[t]))
			end
			print(fmt("  D truth's row: %s", N.dline(N.emu(N.copyParts(parts), N.truthRow(truth)))))
		end
	end
end
