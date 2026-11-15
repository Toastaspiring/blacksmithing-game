--!nocheck
-- fix-2: D through V2's emulator (m2x-fix-2/emuV: the prototype's edge and factor formulas on the build's measure, a
-- forced kept row) for every design of a set whose verdict tree k moves against tree 1 in fxc.luau's output: |ΔD| and tiers.
--   lune run fxemu -- <set> <k> <out> <fxc tsv> [<fxc tsv> ...]     (set: plausible | families:<every> | fixtures)
local process = require("@lune/process")
local fs = require("@lune/fs")
local M = require("../mlib")
local W = M.W
local fmt = string.format
local args = process.args
local set, k, out = args[1], tonumber(args[2]), args[3]

local function req(p)
	return (require :: any)(p)
end
local list
local kind, a1 = string.match(set, "^([^:]+):?([^:]*)$")
if kind == "plausible" then
	list = req(W .. "/c1/tests/Physics/PlausibleDesigns").all()
elseif kind == "families" then
	local every = tonumber(a1) or 1
	local Sets = req(M.SCR .. "/m2x-protoB/b_sets")
	list = {}
	for _, fam in ipairs(Sets.families()) do
		local l = Sets.get(fam)
		for j = 1, #l, every do
			table.insert(list, { name = "b_" .. fam .. " " .. (l[j].name or tostring(j)), parts = l[j].parts })
		end
	end
end

local T = M.tree("V")
local lines = {}
local nd, flips, worst = 0, 0, 0
for a = 4, #args do
	for line in string.gmatch(fs.readFile(args[a]), "[^\n]+") do
		local cols = string.split(line, "\t")
		local idx = tonumber(cols[1])
		local rowA, rowB = cols[4], cols[4 + 2 * (k - 1)]
		if rowA ~= rowB and not string.find(rowA, "CAP") and not string.find(rowB, "CAP") then
			local d = list[idx]
			local parts = M.copyParts(d.parts)
			local ka, kb = {}, {}
			for i = 1, #parts do
				ka[i] = string.sub(rowA, i, i) == "1"
				kb[i] = string.sub(rowB, i, i) == "1"
			end
			local okA, RA = pcall(M.emu, T, parts, ka)
			local okB, RB = pcall(M.emu, T, parts, kb)
			nd += 1
			if okA and okB then
				local moved, tier = 0, ""
				for _, s in ipairs(RA.steps or {}) do
					local dB, tB = M.dOf(RB, s.step)
					if dB then
						moved = math.max(moved, math.abs(dB - s.d))
						if tB ~= s.tier then
							tier = tier .. fmt(" %s %.4f %s -> %.4f %s", s.step, s.d, s.tier, dB, tB)
						end
					end
				end
				if tier ~= "" then
					flips += 1
				end
				worst = math.max(worst, moved)
				table.insert(lines, fmt("%s\t|dD| %.4f\t%s\t%s\t%s", d.name, moved, if tier ~= "" then "FLIP" .. tier else "-", M.dline(RA), M.dline(RB)))
			else
				table.insert(lines, fmt("%s\tERROR %s %s", d.name, tostring(RA), tostring(RB)))
			end
		end
	end
end
table.insert(lines, fmt("%d designs, %d tier flips, |dD| at most %.4f", nd, flips, worst))
fs.writeFile(out, table.concat(lines, "\n") .. "\n")
print(lines[#lines])
