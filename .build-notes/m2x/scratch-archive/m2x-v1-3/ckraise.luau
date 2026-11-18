--!nocheck
-- V1 (m2x, round 3): a checkpoint that raises at the k-th call, for k spread over a run's checkpoints (many of them inside
-- Cover's readings), then the same design and another one run again: every result bit-identical to a clean run's.
local L = require("./lib")
local Worst = require("./repo/docs/spec/prototypes/S2/cover/worst_designs")
local fmt = string.format

local function dump(v, out)
	local t = typeof(v)
	if t == "number" then
		table.insert(out, fmt("%.17g", v))
	elseif t == "table" then
		local keys = {}
		for k in v do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		table.insert(out, "{")
		for _, k in ipairs(keys) do
			table.insert(out, tostring(k) .. "=")
			dump(v[k], out)
			table.insert(out, ",")
		end
		table.insert(out, "}")
	else
		table.insert(out, tostring(v))
	end
	return out
end
local function key(r)
	return table.concat(dump(r, {}))
end

local designs = {
	{ "P4", L.fixture("P4") },
	{ "C09", L.fixture("C09") },
	{ "cluster", L.copyParts(Worst.valid[1].parts) },
	{ "past cap", L.copyParts(Worst.tooComplex[2].parts) },
	{ "P1", L.fixture("P1") },
}
local cores, base, counts = {}, {}, {}
for i, d in ipairs(designs) do
	L.renumber(d[2])
	cores[i] = { schema = 1, name = d[1], type = "Sword", parts = d[2] }
	local n = 0
	base[i] = key(L.Analyze.run(cores[i], { checkpoint = function()
		n += 1
	end }))
	counts[i] = n
end
local bad, raised = 0, 0
for i, d in ipairs(designs) do
	local n = counts[i]
	local step = math.max(1, math.ceil(n / 60))
	local tried = 0
	for k = 1, n, step do
		local c = 0
		local ok = pcall(L.Analyze.run, cores[i], { checkpoint = function()
			c += 1
			if c == k then
				error("cancel")
			end
		end })
		if not ok then
			raised += 1
		end
		tried += 1
		-- the same design, and the next one, once more: as a clean run
		if key(L.Analyze.run(cores[i])) ~= base[i] then
			bad += 1
			print(fmt("DIFF %s after a raise at checkpoint %d", d[1], k))
		end
		local j = i % #designs + 1
		if key(L.Analyze.run(cores[j])) ~= base[j] then
			bad += 1
			print(fmt("DIFF %s after a raise in %s at %d", designs[j][1], d[1], k))
		end
	end
	print(fmt("%s: %d checkpoints, raised at %d of them", d[1], n, tried))
end
print(fmt("raised %d times; results differing from a clean run: %d", raised, bad))
