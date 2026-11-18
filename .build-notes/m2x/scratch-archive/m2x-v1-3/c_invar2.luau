--!nocheck
-- V1 (m2x, round 3): random orders of a design's parts, with parts that are the same in every way (shape, slot, material,
-- pos, rot, size: the index decides between them, §4.4) compared as a class: kept counts, exposedKept and contact rows
-- summed per class, verdictWork, hSurf, surfSamples, subSampled; and the verdict's readings (Cover.shown, whole) per part.
-- lune run c_invar2 -- <seed> <count> <orders>
local process = require("@lune/process")
local serde = require("@lune/serde")
local L = require("./lib")
local T = require("./tangles")
local TestRng = require("./repo/tests/lib/TestRng")
local fmt = string.format
local seed, count, orders = tonumber(process.args[1]) or 1, tonumber(process.args[2]) or 100, tonumber(process.args[3]) or 4
local rng = TestRng.new(seed)

local function key(p)
	return fmt("%s|%s|%s|%.17g,%.17g,%.17g|%.17g,%.17g,%.17g,%.17g|%.17g,%.17g,%.17g", p.shape, p.slot, p.material, p.pos[1],
		p.pos[2], p.pos[3], p.rot[1], p.rot[2], p.rot[3], p.rot[4], p.size[1], p.size[2], p.size[3])
end

-- per class (by key): sorted kept values, sorted exposedKept, Σ contact rows to each class
local function summary(parts, e)
	local cls, keys = {}, {}
	for i, p in ipairs(parts) do
		keys[i] = key(p)
	end
	for i = 1, #parts do
		local k = keys[i]
		local c = cls[k] or { kept = {}, area = {}, contact = {} }
		cls[k] = c
		table.insert(c.kept, if e.kept[i] then 1 else 0)
		table.insert(c.area, e.exposedKept[i])
		for j = 1, #parts do
			c.contact[keys[j]] = (c.contact[keys[j]] or 0) + e.contact[i][j]
		end
	end
	local out = {}
	for k, c in cls do
		table.sort(c.kept)
		table.sort(c.area)
		local ct = {}
		for kk, v in c.contact do
			table.insert(ct, kk .. "=" .. fmt("%.17g", v))
		end
		table.sort(ct)
		table.insert(out, k .. "#" .. table.concat(c.kept, ",") .. "#" .. table.concat((function()
			local t = {}
			for _, a in ipairs(c.area) do
				table.insert(t, fmt("%.17g", a))
			end
			return t
		end)(), ",") .. "#" .. table.concat(ct, ";"))
	end
	table.sort(out)
	return table.concat(out, "\n") .. fmt("\nwork %.17g h %.17g n %d sub %d capped %s", e.verdictWork, e.hSurf, e.surfSamples,
		e.subSampled, tostring(e.capped))
end

local function readings(parts)
	L.renumber(parts)
	local P = L.prep(parts)
	local rs = L.readAll(P)
	local t = {}
	for i, p in ipairs(parts) do
		table.insert(t, key(p) .. "=" .. (if rs[i] then fmt("%.17g", rs[i]) else "-"))
	end
	table.sort(t)
	return table.concat(t, "\n")
end

local diffs, rdiffs, designs = 0, 0, 0
for d = 1, count do
	local parts = T.tangle(rng)
	local N = #parts
	designs += 1
	L.renumber(parts)
	local s0 = summary(parts, L.Sampling.exposure(L.prep(parts)))
	local r0 = readings(L.copyParts(parts))
	for k = 1, orders do
		local perm = {}
		for i = 1, N do
			perm[i] = i
		end
		for i = N, 2, -1 do
			local j = rng:int(1, i)
			perm[i], perm[j] = perm[j], perm[i]
		end
		local sp = {}
		for i = 1, N do
			sp[i] = L.copyPart(parts[perm[i]])
		end
		L.renumber(sp)
		local s = summary(sp, L.Sampling.exposure(L.prep(sp)))
		if s ~= s0 then
			diffs += 1
			print("ORDER DIFF " .. serde.encode("json", parts))
		end
		if readings(L.copyParts(sp)) ~= r0 then
			rdiffs += 1
			print("READING DIFF " .. serde.encode("json", parts))
		end
	end
end
print(fmt("seed %d: %d tangles x %d orders; exposure differing %d, readings differing %d", seed, designs, orders, diffs, rdiffs))
